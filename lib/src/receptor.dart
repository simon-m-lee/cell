// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell.dart';

// ─────────────────────────────────────────────────────────────────────
// Instruction
// ─────────────────────────────────────────────────────────────────────

/// A reusable unit of logic for processing and transforming [Pulse] instances.
///
/// [Instruction] is the foundational building block for [Receptor] pipelines.
/// It encapsulates a discrete transformation logic that takes an incoming
/// pulse and either evolves it into a new form or terminates the signal by
/// returning `null`. Instructions are **stateless** and **composable**,
/// allowing complex processing logic to be assembled from small, focused units.
///
/// ### When to use
/// Use [Instruction] to encapsulate reusable transformations, filters, or
/// side-effects that can be shared across multiple receptors. It is the
/// standard tool for building multi-stage processing pipelines.
///
/// - **Reusable Logic**: Defining a standard sanitization or validation rule
///   used by many cells.
/// - **Pipeline Composition**: Building complex logic by chaining simple
///   instructions with the `+` operator.
/// - **Framework Extensions**: Creating specialized signal processors that
///   hook into the core reactive fabric.
///
/// *Note: For one-off logic, you rarely need to implement [Instruction]
/// directly. Instead, pass a closure to the [Receptor] constructor.*
///
/// ### How it works
/// 1. An instruction receives the host cell, the incoming [Pulse], and
///    optional `user` metadata.
/// 2. It returns a new [Pulse] (to continue propagation) or `null` (to
///    terminate the signal).
/// 3. Instructions are chained using the `+` operator. The output of the
///    first becomes the input of the second.
/// 4. If any instruction in a chain returns `null`, the entire chain
///    short-circuits.
/// 5. Execution is **synchronous** - instructions do not return `Future`.
///    For asynchronous behavior, use the [Instruction.future] factory or
///    the [Receptor.async] execution path.
///
/// ### Non‑obvious
/// - **Composition**: The `+` operator creates an [InstructionChain], which
///   maintains strict execution order.
/// - **Resilience**: Instructions are wrapped in a safety boundary. If an
///   exception occurs, it is caught, logged to the pulse's forensic trace,
///   and the original pulse is returned as a fallback.
/// - **Flyweight Pattern**: Instructions are designed to be extremely
///   lightweight, often sharing the same underlying logic record to minimize
///   memory overhead in large graphs.
/// - **Context vs Metadata**: The `user` parameter is external metadata
///   passed during invocation; it is not persisted in the [Pulse.context].
/// - **Synchronous Only**: Instructions execute synchronously. For
///   asynchronous pulse processing, use [Instruction.future] or call
///   through [Receptor.async] which handles the asynchronous coordination.
///
/// ### Example: Validation & Sanitization Pipeline
/// ```dart
/// final trim = Instruction<Cell, String, String>((pulse, {cell, user}) {
///   return Pulse(pulse.payload.trim());
/// });
///
/// final validate = Instruction<Cell, String, String>((pulse, {cell, user}) {
///   return pulse.payload.isNotEmpty ? pulse : null;
/// });
///
/// // Create a reusable pipeline
/// final pipeline = trim + validate;
/// ```
///
/// ### Type Parameters:
/// * [C]: The type of the [Cell] that serves as the host/context.
/// * [I]: The type of the incoming [Pulse] (Input).
/// * [O]: The type of the resulting [Pulse] (Output).
///
/// See also:
/// * [Receptor] – The component that utilizes instructions to process signals.
/// * [InstructionChain] – The composite implementation for sequential execution.
/// - **Example**: See `example/instruction_pipeline_walkthrough.dart` for a
///   complete executable walkthrough of pattern matching, priority ordering, and
///   multicast routing.
/// - **HowTo**: See `guide/HowTo-Instruction.md` for a guide on implementing
///   custom instructions.
///
/// {@category Instructions}
/// {@category Pipelines & Internal}
abstract interface class Instruction<C extends Cell, I extends Pulse, O extends Pulse> {

  /// Creates an [Instruction] from a standalone transformation function.
  ///
  /// ### When to use
  /// This is the primary entry point for creating custom logic. Use it when you
  /// need a simple, single-purpose transformation or filter without the
  /// overhead of implementing the interface.
  ///
  /// ### How it works
  /// The provided closure is invoked synchronously whenever a pulse arrives.
  /// It receives the [pulse], the host [cell] (for context-aware logic), and
  /// any [user] data passed during construction. The return value determines
  /// the next state of the signal: a new [Pulse] continues propagation, while
  /// `null` drops it.
  ///
  /// ### Non‑obvious
  /// - **Safety Wrap**: The function is automatically wrapped in a resilience
  ///   layer. Exceptions are caught, logged, and the original pulse is
  ///   returned as a fallback to prevent pipeline crashes.
  /// - **Static Metadata**: The [user] parameter provided here acts as a
  ///   default configuration that is passed to every invocation of this
  ///   specific instruction instance.
  /// - **Synchronous Execution**: The instruction executes synchronously.
  ///   For asynchronous processing, use [Instruction.future] or call through
  ///   [Receptor.async].
  ///
  /// ### Parameters:
  /// - [instruction]: The function that transforms an input pulse [I] to an
  ///   output pulse [O]. Returning `null` terminates the signal.
  /// - [user]: Optional default context data passed to the rule function
  ///   during execution.
  ///
  /// ### Example: Rule with Configuration
  /// ```dart
  /// final multiplier = Instruction<Cell, int, int>((pulse, {cell, user}) {
  ///   final scale = user as int? ?? 1;
  ///   return Pulse(pulse.payload * scale);
  /// }, user: 3); // Default multiplier is 3
  /// ```
  ///
  /// ### See also:
  /// - **Example**: See `example/instruction_pipeline_walkthrough.dart` for a
  ///   complete executable walkthrough of pattern matching, priority ordering, and
  ///   multicast routing.
  /// - **HowTo**: See `guide/HowTo-Instruction.md` for a guide on implementing
  ///   custom instructions (including synchronous/asynchronous) and scheduling logic..
  const factory Instruction(
      O? Function(I pulse, {C? cell, dynamic user}) instruction, {dynamic user}) = _Instruction<C,I,O>;

  /// Creates an [Instruction] with asynchronous future propagation support.
  ///
  /// ### When to use
  /// Use this factory when a transformation depends on an asynchronous event
  /// (e.g., a Timer, Network I/O, or Database lookup). It is the primary
  /// mechanism for implementing scheduling operators like `debounce`,
  /// `throttle`, and `delay`.
  ///
  /// ### How it works
  /// 1. The instruction is invoked synchronously but returns `null` to
  ///    suspend the immediate signal propagation.
  /// 2. It receives a [future] callback and a [token].
  /// 3. When the asynchronous task completes, calling `future(result: ..., token: token)`
  ///    resumes the propagation chain from this specific instruction point.
  ///
  /// ### Design Note: Result Propagation
  /// The [future] callback mechanism handles **lifecycle synchronization**
  /// and graph stabilization rather than terminal result retrieval. Because
  /// instructions operate within a [Cell] graph, the resumed pulse is
  /// automatically broadcast to all downstream [Synapses]. To act on the
  /// final result, developers should attach observers to the host cell
  /// rather than attempting to await the instruction's completion.
  ///
  /// ### Non‑obvious
  /// - **Token Integrity**: The [token] is a unique identifier for the
  ///   instruction's position in a chain. Passing it back to the `future`
  ///   callback ensures the graph sequencer knows exactly where to resume.
  /// - **Suspension**: Returning `null` is mandatory to suspend propagation;
  ///   returning a [Pulse] will cause immediate synchronous propagation,
  ///   likely leading to double-emissions if `future` is also called.
  /// - **Memory Safety**: If the host [Cell] is disposed before the
  ///   asynchronous operation finishes, the [future] callback becomes a
  ///   no-op to prevent memory leaks and ghost updates.
  ///
  /// ### Example:
  /// ```dart
  /// final futureInstruction = Instruction<Cell, Pulse, Pulse>.future(
  ///   (pulse, {cell, future, token, user}) {
  ///     Timer(Duration(seconds: 1), () {
  ///       future(result: pulse, token: token);
  ///     });
  ///     return null; // Pulse is not immediately propagated
  ///   },
  /// );
  /// ```
  /// ### Parameters:
  /// - [instruction]: The transformation function. It receives the [pulse],
  ///   host [cell], the [future] continuation callback, and the [token].
  /// - [user]: Optional static metadata for the instruction instance.
  ///
  /// ### Returns:
  /// An [Instruction] that suspends synchronous execution and supports
  /// out-of-band asynchronous resumption.
  ///
  /// ### See Also:
  /// - [ReceptorAsync]: The component that orchestrates these instructions.
  /// - [Cell.txApply]: For wrapping async updates in atomic transactions.
  /// - **Example**: See `example/instruction_pipeline_walkthrough.dart` for a
  ///   complete executable walkthrough of pattern matching, priority ordering,
  ///   and multicast routing.
  /// - **HowTo**: See `guide/HowTo-Instruction.md` for a guide on implementing
  ///   custom asynchronous instructions and scheduling logic.
  const factory Instruction.future(
      O? Function(I pulse, {C? cell, dynamic user,
      void Function({required Pulse? result, required dynamic token})? future,
      dynamic token
      }) instruction, {dynamic user}) = _Instruction<C,I,O>.future;

  /// Creates an [InstructionChain] that orchestrates multiple instructions.
  ///
  /// ### When to use
  /// Use this when you need to compose several discrete processing steps into
  /// a single, reusable pipeline. It is the primary tool for building
  /// multi-stage transformations where logic is partitioned into small units.
  ///
  /// - **Sequential Processing**: The standard way to apply a series of
  ///   filters and transformations in a specific order.
  /// - **Custom Orchestration**: Use the [strategy] parameter when you need
  ///   non-linear execution, such as branching, parallel processing, or
  ///   conditional logic based on the current pulse state.
  ///
  /// ### How it works
  /// 1. By default, it iterates through the [instructions] collection in
  ///    insertion order.
  /// 2. The output of the first instruction is passed as the input to the
  ///    second, and so on.
  /// 3. If a [strategy] is provided, the default sequential loop is replaced
  ///    by your custom function, which receives the list of instructions and
  ///    the current context.
  /// 4. All executions are synchronous. For asynchronous orchestration,
  ///    use [Instruction.future] within individual instructions or use
  ///    [Receptor.async] for the overall pipeline.
  ///
  /// ### Non‑obvious
  /// - **Short-circuiting**: In the default strategy, if any instruction in
  ///   the chain returns `null`, the entire process terminates immediately
  ///   and the result is `null`.
  /// - **Error Recovery**: The chain maintains the resilience of its parts.
  ///   If an instruction fails, the chain recovers with the last "good"
  ///   pulse state rather than crashing the pipeline.
  /// - **Recursive Composition**: Since the resulting chain is itself an
  ///   [Instruction], you can nest chains within other chains to build
  ///   hierarchical processing trees.
  /// - **Synchronous Pipeline**: The chain executes synchronously. Each
  ///   instruction must complete before the next begins.
  ///
  /// ### Parameters:
  /// - [instructions]: The ordered collection of logic units to execute.
  /// - [user]: Optional metadata passed to the [strategy] or individual
  ///   instructions.
  /// - [strategy]: A function to override the default sequential execution
  ///   logic.
  ///
  /// ### Example: Pipeline with conditional skip
  /// ```dart
  /// final pipeline = Instruction.chain(
  ///   [trim, validate, log],
  ///   strategy: (pulse, {cell, user}) {
  ///     // Example: Skip validation if 'user' flag is set
  ///     var current = trim(pulse, cell: cell);
  ///     if (user != 'skip_val') {
  ///       current = validate(current!, cell: cell);
  ///     }
  ///     return current != null ? log(current, cell: cell) : null;
  ///   },
  /// );
  /// ```
  const factory Instruction.chain(Iterable<Instruction> instructions, {dynamic user,
    O? Function(I pulse, {C? cell, dynamic user})? strategy}) = InstructionChain<C,I,O>;

  /// Executes the transformation logic of this instruction synchronously.
  ///
  /// ### When to use
  /// Typically, you do not call this method directly. The framework invokes it
  /// automatically when a pulse arrives at a [Receptor]. Manual invocation is
  /// recommended primarily for:
  /// - **Testing**: Verifying instruction logic in isolation.
  /// - **Orchestration**: Building custom execution flows within an
  ///   [Instruction.chain] strategy.
  ///
  /// ### How it works
  /// 1. The instruction takes the incoming [pulse] and the host [cell] context.
  /// 2. It applies the internal transformation function or composite chain logic.
  /// 3. It returns the resulting [Pulse] (transformed or original), or `null`
  ///    to terminate the signal.
  /// 4. The [future] callback, if provided, enables asynchronous continuation
  ///    of the pipeline.
  ///
  /// ### Non‑obvious
  /// - **Resilience**: The execution is shielded by a safety boundary. Any
  ///   unhandled exception is captured, logged to the pulse's forensic
  ///   metadata, and the original [pulse] is returned to prevent graph
  ///   deadlocks or total pipeline failure.
  /// - **Synchronous Execution**: This method executes synchronously and
  ///   returns the result immediately. It does not return a [Future].
  /// - **Future Propagation**: If the instruction was created with
  ///   [Instruction.future], the [future] callback is provided to enable
  ///   asynchronous continuation of the pipeline.
  /// - **Side Effects**: While instructions should ideally be pure, manual
  ///   calls can be used to trigger side effects while preserving the
  ///   underlying signal's metadata and context.
  ///
  /// ### Parameters:
  /// - [pulse]: The incoming pulse to transform.
  /// - [cell]: The host cell context.
  /// - [future]: Optional callback for asynchronous continuation.
  /// - [token]: Optional token for identifying the instruction.
  ///
  /// ### Returns:
  /// The transformed pulse, or `null` if the signal was terminated.
  ///
  /// ### Example: Testing an Instruction
  /// ```dart
  /// final doubleValue = Instruction<Cell, int, int>((p, {cell, user}) => Pulse(p.payload * 2));
  /// final result = doubleValue.call(Pulse(10));
  /// print((result as Pulse).payload); // 20
  /// ```
  O? call(I pulse, {
    C? cell,
    void Function({required Pulse? result, required dynamic token})? future,
    dynamic token
  });

  /// Combines this instruction with another to create an [InstructionChain].
  ///
  /// ### When to use
  /// This is the most idiomatic and readable way to compose multiple
  /// instructions. Use it to fluently build a sequential processing pipeline
  /// without the verbosity of the [Instruction.chain] factory.
  ///
  /// ### How it works
  /// 1. It creates an [InstructionChain] where `this` instruction is executed
  ///    first.
  /// 2. The output of `this` is passed as the input to the [other] instruction.
  /// 3. The resulting chain is itself an [Instruction], allowing for
  ///    continuous, multi-stage composition.
  ///
  /// ### Non‑obvious
  /// - **Short-circuiting**: If `this` instruction returns `null`, the [other]
  ///   instruction is skipped entirely, and the chain terminates with `null`.
  /// - **Left-Associativity**: The operator is left-associative.
  ///   `a + b + c` creates a logical sequence that preserves the `a -> b -> c`
  ///   data flow.
  /// - **Synchronous Composition**: Both instructions execute synchronously
  ///   in sequence. The result of the first is immediately passed to the second.
  ///
  /// ### Parameters:
  /// - [other]: The instruction to append to the processing chain.
  ///
  /// ### Returns:
  /// A new [InstructionChain] containing both instructions.
  ///
  /// ### Example
  /// ```dart
  /// final pipeline = trim + validate + persist;
  /// ```
  Instruction<C,I,O> operator +(covariant Instruction other);

}

// ─────────────────────────────────────────────────────────────────────
// InstructionChain
// ─────────────────────────────────────────────────────────────────────

/// A composite [Instruction] that orchestrates a sequence of processing units.
///
/// [InstructionChain] is the implementation behind the `+` operator and the
/// [Instruction.chain] factory. It enables the creation of complex processing
/// pipelines by linking discrete [Instruction]s together, where the output
/// of one stage serves as the input to the next.
///
/// ### When to use
/// Use a chain when you need to perform multiple, sequential operations on a
/// signal, such as:
/// - **Pipeline Processing**: Building a `Trim` -> `Sanitize` -> `Validate` sequence.
/// - **Signal Branching**: Using a custom strategy to choose which instruction
///   to run next based on the pulse's payload.
/// - **Reusable Middleware**: Grouping common logging and validation rules
///   into a single, shareable instruction.
///
/// *Note: You rarely need to instantiate this class directly. Use the `+`
/// operator for standard sequences.*
///
/// ### How it works
/// 1. **Sequential Execution**: By default, it iterates through its internal
///    collection of instructions in order.
/// 2. **Data Flow**: Each instruction's result becomes the input for the next
///    in the chain.
/// 3. **Synchronous Processing**: All instructions execute synchronously in
///    sequence. Each must complete before the next begins.
/// 4. **Strategic Control**: If a custom strategy is provided, it replaces
///    the default loop, giving you full control over how instructions are
///    invoked.
/// 5. **Future Propagation**: The chain supports asynchronous continuation
///    via the [future] callback mechanism.
///
/// ### Non‑obvious
/// - **Short-circuiting**: If any instruction returns `null`, the remaining
///   stages are skipped, and the entire chain returns `null`.
/// - **Resilience**: The chain is designed to be "non-breaking." If an
///   instruction fails (throws an exception), the chain captures the error
///   and attempts to continue using the last valid pulse state.
/// - **Compositionality**: Because it implements the [Instruction] interface,
///   chains can be nested inside other chains, allowing for complex,
///   hierarchical processing trees.
/// - **Memory Efficiency**: It uses a flyweight-like record system to store
///   its configuration, making even deeply nested chains lightweight.
/// - **Synchronous Pipeline**: The entire chain executes synchronously. For
///   asynchronous processing within a chain, use [Instruction.future] at the
///   individual instruction level.
///
/// ### Type Parameters:
/// * [C]: The type of the host [Cell].
/// * [I]: The type of the incoming [Pulse].
/// * [O]: The type of the resulting [Pulse].
///
/// ### Example: Sequential Pipeline
/// ```dart
/// final pipeline = trimInstruction + validateInstruction + logInstruction;
/// ```
///
/// See also:
/// * [Instruction] – The individual building blocks.
/// * [Instruction.chain] – The factory for creating chains with custom logic.
class InstructionChain<C extends Cell, I extends Pulse, O extends Pulse> extends InstructionBase<C,I,O> with InstructionChainMixin<C,I,O> {

  /// Internal constructor for creating an [InstructionChain].
  ///
  /// ### When to use
  /// This constructor is typically called by the [Instruction.chain] factory
  /// or the `+` operator. It is not intended for general use.
  ///
  /// ### Parameters:
  /// - [instructions]: The ordered collection of instructions to be orchestrated.
  /// - [user]: Optional metadata passed to the [strategy] or individual instructions.
  /// - [strategy]: An optional function to override the default sequential
  ///   execution.
  ///
  /// ### Example: Custom Strategy
  /// ```dart
  /// final customChain = Instruction.chain(
  ///   [rule1, rule2],
  ///   strategy: (pulse, {cell, user}) {
  ///     // custom orchestration logic here
  ///     final r1 = rule1(pulse, cell: cell);
  ///     return r1 != null ? rule2(r1, cell: cell) : null;
  ///   },
  /// );
  /// ```
  const InstructionChain(Iterable<Instruction> instructions, {dynamic user,
    O? Function(I pulse, {C? cell, dynamic user})? strategy})
      : super.fromRecord(
      user != null ? strategy != null
          ? (instructions: instructions, user: user, instruction: strategy)
          : (instructions: instructions, user: user)
          : (instructions: instructions)
  );

}

// ─────────────────────────────────────────────────────────────────────
// InstructionChainMixin
// ─────────────────────────────────────────────────────────────────────

/// A mixin that provides the core execution engine for composite instructions.
///
/// [InstructionChainMixin] encapsulates the logic required to orchestrate a
/// sequence of instructions, managing the data flow between stages and
/// providing automated error resilience.
///
/// ### When to use
/// This mixin is intended for use by composite instruction implementations
/// that need to execute multiple logic units. It handles both default
/// sequential execution and custom orchestration strategies.
///
/// ### How it works
/// 1. **Entry Point**: The [call] method resolves the execution logic from
///    the underlying configuration.
/// 2. **Sequential Evaluation**: It iterates through the instruction set,
///    passing the output of one stage as the input to the next.
/// 3. **Synchronous Processing**: All instructions execute synchronously.
///    Each instruction's result is immediately passed to the next.
/// 4. **Result Normalization**: It performs dynamic type checking to ensure
///    the signal conforms to the expected output type.
/// 5. **Future Propagation**: It manages the [future] callback chain for
///    asynchronous continuation.
///
/// ### Non‑obvious
/// - **Resilience**: The internal evaluator is "fault-tolerant." If a
///   specific instruction fails, the mixin captures the error and attempts
///   to continue the pipeline using the last valid signal state.
/// - **Execution Efficiency**: Standard synchronous pipelines are processed
///   using an optimized path to minimize overhead.
/// - **Short-circuiting**: The default behavior is to treat `null` as a
///   terminal signal. If any stage returns `null`, the entire chain
///   terminates immediately.
/// - **Metadata Integrity**: The mixin ensures that user context and cell
///   references are correctly propagated through every stage of the chain.
/// - **Synchronous Only**: This mixin executes instructions synchronously.
///   It does not handle [Future] results. For asynchronous processing,
///   individual instructions should use [Instruction.future].
///
/// ### Type Parameters:
/// * [C]: The type of the host [Cell].
/// * [I]: The type of the incoming [Pulse].
/// * [O]: The type of the resulting [Pulse].
mixin InstructionChainMixin<C extends Cell, I extends Pulse, O extends Pulse> on InstructionBase<C,I,O> {

  /// Retrieves the custom strategy or default chain rule.
  ///
  /// ### Returns:
  /// The instruction function to execute, or the default chain rule if no
  /// custom strategy is provided.
  @override
  Function? get _instruction {
    return get<Function?>(() => _record.instruction, orElse: _chainRule);
  }

  /// Retrieves the list of instructions in the chain.
  ///
  /// ### Returns:
  /// An iterable of [Instruction] objects in execution order, or `null`
  /// if no instructions are stored.
  Iterable<Instruction>? get _instructions => get<Iterable<Instruction>?>(() => _record.instructions, orElse: null);

  /// Executes the transformation chain synchronously with future propagation support.
  ///
  /// ### When to use
  /// This is the primary implementation of the [Instruction.call] contract
  /// for composite instructions. It is invoked automatically when a pulse
  /// enters a receptor or a nested chain.
  ///
  /// ### How it works
  /// 1. **Strategy Resolution**: It first checks for a custom orchestration
  ///    strategy provided during construction.
  /// 2. **Execution**:
  ///    - If a strategy exists, it is executed synchronously with the
  ///      current pulse and context.
  ///    - Otherwise, it falls back to the default sequential evaluation.
  /// 3. **Safety Boundary**: The entire call is wrapped in a safety
  ///    boundary. Orchestration errors are caught, logged to the pulse's
  ///    trace, and the signal is terminated to protect the graph.
  /// 4. **Normalization**: The result is validated to ensure type
  ///    consistency.
  /// 5. **Future Propagation**: The [future] callback is passed through
  ///    to enable asynchronous continuation.
  ///
  /// ### Non‑obvious
  /// - **Terminal Failures**: If an error occurs during orchestration itself,
  ///   this implementation returns `null` to ensure that corrupted logic
  ///   does not propagate invalid states.
  /// - **Monitoring**: It supports optional callbacks for external
  ///   monitoring of the chain's final output.
  /// - **Dynamic Resolution**: It retrieves execution logic dynamically,
  ///   maintaining high memory efficiency even for complex graphs.
  /// - **Synchronous Execution**: The chain executes synchronously and
  ///   returns the result immediately.
  ///
  /// ### Parameters:
  /// - [pulse]: The incoming pulse to transform.
  /// - [cell]: The host cell context.
  /// - [future]: Optional callback for asynchronous continuation.
  /// - [token]: Optional token for identifying the instruction.
  /// - [user]: Optional user metadata.
  ///
  /// ### Returns:
  /// The final transformed pulse, or `null` if terminated.
  @override
  O? call(I pulse, {
    C? cell,
    void Function({required Pulse? result, required dynamic token})? future,
    dynamic token,
  }) {

    void future_({required Pulse? result, required dynamic token}) {
      if (future != null) {
        future(result: result, token: token);
      } else {
        print(UnimplementedError('[future] is null to forward (result: $result, token: $token)'));
      }
    }

    try {
      Pulse? result;
      final strategy = _instruction;
      result = strategy != null
          ? strategy(pulse, cell: cell, user: _user, future: future_)
          : _chainRule(pulse, cell: cell, user: _user);

      return result is O? ? result : null;
    } catch (e, stackTrace) {
      (pulse as PulseBase)._fail(e, stackTrace: stackTrace);
    }
    return null;
  }

  /// Executes the transformation chain synchronously.
  ///
  /// ### How it works
  /// 1. It iterates through the instruction list in order.
  /// 2. Each instruction's result becomes the input for the next.
  /// 3. If an instruction supports future propagation, it handles the
  ///    callback chain.
  /// 4. If any instruction returns `null`, the chain short-circuits.
  ///
  /// ### Parameters:
  /// - [pulse]: The incoming pulse to transform.
  /// - [cell]: The host cell context.
  /// - [user]: Optional user metadata.
  /// - [future]: Optional callback for asynchronous continuation.
  ///
  /// ### Returns:
  /// The final transformed pulse, or `null` if terminated.
  O? _chainRule(I pulse, {C? cell, dynamic user, void Function({required Pulse? result, required dynamic token})? future}) {
    final instructions = _instructions;
    if (instructions != null) {

      void future_({required  Pulse? result, required dynamic token}) {
        if (token is Function) {
          Instruction instruction;
          for (int i=0; i<instructions.length; i++) {
            instruction = instructions.elementAt(i);

            if (!identical(token, instruction)) {
              continue;
            }

            try {
              result = instruction.call(result as Pulse, cell: cell,
                  future: future_,
                  token: (i + 1) < instructions.length ? instructions.elementAt(i+1) : null
              );
            } catch(_) {
              result = instruction.call(result as Pulse, cell: cell);
            }

            if (result == null) {
              return;
            }
          }
        } else if (future != null) {
          future(result: result, token: token);
        } else {
          print(UnimplementedError('[future] is null to forward (result: $result, token: $token)'));
        }
      }

      Pulse? result = pulse;
      Instruction instruction;

      for (int i=0; i<instructions.length; i++) {
        instruction = instructions.elementAt(i);
        try {
          result = instruction.call(result as Pulse, cell: cell,
              future: future_,
              token: (i + 1) < instructions.length ? instructions.elementAt(i+1) : null
          );
        } catch (e, stackTrace) {
          try {
            result = instruction.call(result as Pulse, cell: cell);
          } catch (_) {
            (pulse as PulseBase)._fail(e, stackTrace: stackTrace);
            result = null;
          }
        }
      }

      return result is O? ? pulse as O? : null;
    }
    return pulse is O? ? pulse as O? : null;
  }

}

// ─────────────────────────────────────────────────────────────────────
// Receptor
// ─────────────────────────────────────────────────────────────────────

/// The transformation pipeline that decides how a [Cell] responds to an
/// incoming [Pulse].
///
/// [Receptor] is a functional wrapper around one or more instructions that
/// defines the behavior of a cell when it receives a signal. When a pulse
/// arrives, the receptor executes its pipeline and returns the resulting
/// pulse or `null`.
///
/// ### When to use
/// Use a custom receptor when you need to transform, filter, or react to
/// pulses arriving at a cell. While most cells use the default pass-through
/// behavior, you define a receptor for any custom logic such as validation,
/// mapping, or state updates.
///
/// - **Identity Relay**: Use [Receptor.passThrough] (the default) to forward
///   pulses unchanged.
/// - **Single Transformation**: Use the primary constructor for simple
///   logic steps.
/// - **Multi-Stage Pipelines**: Use [Receptor.pipeline] to separate
///   pre-processing (sanitization), core logic, and post-processing
///   (validation).
/// - **Reusable Logic**: Use [Receptor.instruction] to apply pre-defined
///   [Instruction] objects.
///
/// ### How it works
/// 1. **Pipeline Order**: Sanitization → Core Logic → Commitment/Validation.
/// 2. **Filtering**: If any stage returns `null`, the pipeline stops
///    immediately.
/// 3. **Synchronous Pipeline**: Instructions execute synchronously. For
///    asynchronous processing, use [Receptor.async].
/// 4. **Resilience**: Exceptions are caught and reported via the pulse's
///    forensic metadata.
/// 5. **Activation**: A receptor is a stateless template until bound to a
///    specific cell via [activate].
///
/// ### Non‑obvious
/// - **Activation**: A receptor is a stateless template until bound to a
///   specific cell. Once activated, it is pinned to that cell's context.
///   To use the same logic on a different cell, use the [clone] method.
/// - **Pass‑through Efficiency**: The default behavior uses a singleton
///   instance, allowing millions of cells to share the same logic without
///   memory overhead.
/// - **Filtering vs. Errors**: Returning `null` is the standard way to
///   filter signals (e.g., ignoring out-of-range values). It is not treated
///   as an error path.
/// - **Synchronous vs Asynchronous**: The [call] method executes
///   synchronously. Use [Receptor.async] for asynchronous pulse injection.
/// - **Governance**: When [isGoverned] is `true`, the receptor applies
///   architectural policies and appends forensic trace information.
///
/// ### Type Parameters:
/// * [C]: The type of the host [Cell] that this receptor serves.
///
/// ### Example: Validated Pipeline
/// ```dart
/// final doubleAndCap = Receptor.pipeline(
///   preProcess: Instruction((pulse, {cell, user}) => Pulse(pulse.payload.trim())),
///   instruction: Instruction((pulse, {cell, user}) => Pulse(pulse.payload * 2)),
///   postProcess: Instruction((pulse, {cell, user}) => pulse.payload < 100 ? pulse : null),
/// );
/// ```
///
/// See also:
/// * [Instruction] – The individual logic units.
/// * [InstructionChain] – For composing multiple instructions.
/// * [ReceptorAsync] – For asynchronous pulse injection.
/// - **HowTo**: See `guide/HowTo-Receptor.md` for a guide on designing
///   and implementing custom receptors.
///
/// {@category Pipelines & Internal}
abstract interface class Receptor<C extends Cell> {

  /// A canonical, stateless [Receptor] that performs an **Identity
  /// Transformation** on all incoming signals.
  ///
  /// This is the framework's default "Open Gate." It implements the simplest
  /// reactive behavior: every pulse received is immediately and
  /// transparently broadcast downstream.
  ///
  /// ### When to use
  /// You typically don't need to specify this – it's the default if no
  /// custom receptor is provided. Use it explicitly for relay nodes that
  /// just forward signals without modification.
  ///
  /// ### How it works
  /// The receptor returns the input pulse unchanged. It performs no
  /// validation or transformation.
  ///
  /// ### Non‑obvious
  /// - **Memory**: This is a singleton shared across the entire project.
  /// - **Security**: It provides no protection against invalid data. Use a
  ///   custom receptor if you need to sanitize or validate inputs.
  static const passThrough = _PassThroughReceptor._singleton;

  /// The primary factory for creating a functional pulse processor for a [Cell].
  ///
  /// ### When to use
  /// This is the most common way to define custom cell behavior. Use it when
  /// you need a single, concise logic step to transform or filter incoming
  /// signals.
  ///
  /// - **One-off Logic**: Best for anonymous functions that don't need
  ///   to be reused elsewhere.
  /// - **Simple Mapping**: Ideal for basic data transformations (e.g.,
  ///   scaling a number or formatting a string).
  /// - **Basic Filtering**: Perfect for dropping invalid inputs by
  ///   returning `null`.
  ///
  /// ### How it works
  /// 1. You provide an [instruction] function that receives the host [cell],
  ///    the incoming [pulse], and optional `user` metadata.
  /// 2. The function is automatically wrapped into an internal logic unit.
  /// 3. If the function returns a [Pulse], the signal continues downstream.
  /// 4. If the function returns `null`, the signal is dropped.
  /// 5. The function executes synchronously.
  ///
  /// ### Non‑obvious
  /// - **Resilience**: The provided function is executed within a safety
  ///   boundary. If it throws an exception, the error is logged to the
  ///   pulse's forensic metadata, and the signal is terminated (`null`)
  ///   to prevent graph instability.
  /// - **Stateless Template**: The receptor created is a blueprint. It
  ///   does not hold state and only becomes "active" when bound to a
  ///   specific cell context.
  /// - **Type Safety**: While the factory takes a generic [Pulse], the
  ///   internal logic maintains the type integrity of the payload
  ///   during transformation.
  /// - **Synchronous Execution**: The instruction executes synchronously.
  ///   For asynchronous processing, use [Receptor.async].
  ///
  /// ### Parameters:
  /// - [instruction]: The transformation or filtering function. Returning
  ///   `null` stops the pulse from propagating further.
  ///
  /// ### Example: Input Doubler
  /// ```dart
  /// final doubleReceptor = Receptor((cell, pulse, {user}) {
  ///   final value = pulse.payload as int;
  ///   return Pulse(value * 2);
  /// });
  /// ```
  factory Receptor(Pulse? Function(C cell, Pulse pulse, {dynamic user}) instruction) {
    return _Receptor<C>(instruction: Instruction<C,Pulse,Pulse>((pulse, {C? cell, future, token, dynamic user}) {
      return instruction.call(cell!, pulse, user: user);
    }));
  }

  /// Creates a [Receptor] from a pre-defined [Instruction].
  ///
  /// ### When to use
  /// Use this factory when you have reusable logic already encapsulated in
  /// an [Instruction] object. It is the best choice for:
  /// - **Shared Logic**: Applying the same transformation (e.g., sanitization)
  ///   across multiple cells.
  /// - **Rule Composition**: Using complex pipelines built with the `+`
  ///   operator.
  /// - **Modular Design**: Separating the definition of business rules from
  ///   the cell architecture.
  ///
  /// ### How it works
  /// 1. It wraps the provided [instruction] into the receptor's execution
  ///    path.
  /// 2. If [user] metadata is provided, it is stored at the receptor level
  ///    and passed to the instruction during every invocation.
  /// 3. The receptor inherits the transformation, filtering, and error
  ///    handling behavior defined in the instruction.
  ///
  /// ### Non‑obvious
  /// - **Metadata Precedence**: The [user] data passed to this factory is
  ///   passed to the instruction's call method. If the instruction already
  ///   has internal metadata, this [user] parameter acts as the execution-time
  ///   context.
  /// - **Template State**: Like all receptor factories, this returns a
  ///   stateless blueprint. It only acquires a concrete execution context
  ///   when bound to a cell.
  /// - **Short-circuiting**: If the instruction is a chain, the receptor
  ///   respects the chain's terminal logic (returning `null` stops the
  ///   signal).
  /// - **Synchronous Execution**: The instruction executes synchronously.
  ///
  /// ### Parameters:
  /// - [instruction]: The logic unit to use for pulse processing.
  /// - [user]: Optional metadata to be passed to the instruction during
  ///   execution.
  ///
  /// ### Example: Reusable Auditor
  /// ```dart
  /// // Define a reusable instruction
  /// final auditor = Instruction<Cell, Pulse, Pulse>((p, {cell, user}) {
  ///   print('Audit [${user}]: ${p.payload}');
  ///   return p;
  /// });
  ///
  /// // Bind it to a receptor
  /// final receptor = Receptor.instruction(auditor, user: 'SecurityLog');
  /// ```
  factory Receptor.instruction(Instruction<C,Pulse,Pulse> instruction, {dynamic user}) {
    return _Receptor<C>(instruction: instruction, user: user);
  }

  /// The advanced compositional factory for [Receptor], enabling the creation
  /// of structured, three-stage pulse processing pipelines.
  ///
  /// ### When to use
  /// Use this factory when you need to enforce a clear separation of concerns
  /// within a cell's transformation logic. It is the standard tool for
  /// building robust signal processing chains that require:
  ///
  /// - **Sanitization**: Cleaning or normalizing data in [preProcess] before
  ///   it reaches core logic.
  /// - **Business Logic**: Performing the primary transformation in the
  ///   central [instruction].
  /// - **Validation**: Enforcing invariants or "Test Rules" in [postProcess]
  ///   before the state is committed.
  ///
  /// ### How it works
  /// 1. The receptor executes the stages in strict sequential order:
  ///    `preProcess` → `instruction` → `postProcess`.
  /// 2. **Data Flow**: The output of one stage becomes the input of the next.
  /// 3. **Filtering**: If any stage returns `null`, the pipeline
  ///    short-circuits immediately and the pulse is dropped.
  /// 4. **Resilience**: Each stage is independently shielded; an error in one
  ///    stage is logged, and the pipeline recovers to the last valid state.
  /// 5. **Synchronous Pipeline**: All stages execute synchronously.
  ///
  /// ### Non‑obvious
  /// - **Optionality**: All stages are optional. If a stage is omitted, the
  ///   pulse passes through that layer unchanged.
  /// - **Identity Logic**: If no parameters are provided, this factory
  ///   effectively creates a [passThrough] receptor.
  /// - **Synchronous Execution**: The pipeline executes synchronously. For
  ///   asynchronous processing, use [Instruction.future] within stages or
  ///   use [Receptor.async] for the overall execution.
  ///
  /// ### Parameters:
  /// - [instruction]: The core transformation logic (the "Reasoning" phase).
  /// - [preProcess]: Logic executed before the core (e.g., sanitization).
  /// - [postProcess]: Logic executed after the core (e.g., final validation).
  ///
  /// ### Example: Secure Multi-Stage Processor
  /// ```dart
  /// final secureReceptor = Receptor.pipeline(
  ///   preProcess: Instruction((p, {cell, user}) => Pulse(p.payload.trim())),
  ///   instruction: Instruction((p, {cell, user}) => Pulse(p.payload.toUpperCase())),
  ///   postProcess: Instruction((p, {cell, user}) => p.payload.length > 5 ? p : null),
  /// );
  /// ```
  factory Receptor.pipeline({Instruction? instruction, Instruction? preProcess, Instruction? postProcess})
  = _Receptor<C>;

  /// Returns a shallow, unactivated copy of the current [Receptor].
  ///
  /// ### When to use
  /// Use this when you need to duplicate a receptor's transformation logic for
  /// a different cell. While the framework handles this automatically during
  /// cell creation, manual cloning is useful for:
  ///
  /// - **Graph Prototyping**: Creating variations of a signal path from a
  ///   common base template.
  /// - **Dynamic Receptors**: Replicating a complex pipeline to be bound to
  ///   multiple ephemeral cells.
  ///
  /// ### How it works
  /// 1. It creates a new receptor instance that shares the same underlying
  ///    instruction set and user metadata.
  /// 2. The resulting object is a **Stateless Template** – it is not bound
  ///    to any cell, and [isActivated] returns `false`.
  /// 3. Activating the clone binds it to a specific [Cell] instance without
  ///    affecting the original receptor's state.
  ///
  /// ### Non‑obvious
  /// - **Isolation**: The clone is a distinct object. Activating the original
  ///   or changing its configuration will not impact the cloned instance.
  /// - **Shallow Efficiency**: It copies references to the instructions.
  ///   Because instructions are flyweights, this operation is extremely fast
  ///    and memory-efficient.
  /// - **Nucleus Integrity**: This method is the mechanical key to how a
  ///   single nucleus can spawn multiple independent cell instances, each
  ///   maintaining its own private operational perimeter.
  ///
  /// ### Returns:
  /// A new unactivated [Receptor] instance with the same logic.
  Receptor<C> get clone;

  /// A specialized static factory that creates a type-safe [Receptor] for
  /// explicit signal transformations between specific [Pulse] types.
  ///
  /// ### When to use
  /// Use this when you need to bridge two distinct pulse types (e.g., converting
  /// a `Pulse<String>` into a `Pulse<int>`) with full static analysis support.
  /// It is the preferred tool for:
  ///
  /// - **Type Bridging**: Explicitly mapping data from one domain type to
  ///   another.
  /// - **Strongly-Typed Boundaries**: Ensuring that a receptor only accepts
  ///   and produces specific pulse payloads.
  /// - **Library Development**: Providing clear, type-safe APIs for custom
  ///   signal processors.
  ///
  /// *Note: While [Receptor.instruction] handles generic pulses, this method
  /// enforces the [I] and [O] types at compile time.*
  ///
  /// ### How it works
  /// 1. It takes an [Instruction] that is strictly typed for the input [I]
  ///    and output [O].
  /// 2. It wraps this logic into a [Receptor] instance bound to cell type [C].
  /// 3. The resulting receptor performs the transformation while maintaining
  ///    the internal type integrity of the signal.
  ///
  /// ### Non‑obvious
  /// - **Generics**: This is a static method rather than a factory because
  ///   Dart factories cannot introduce new generic parameters ([I] and [O])
  ///   independent of the class.
  /// - **Downstream Consistency**: Even though the resulting receptor is
  ///   typed as `Receptor<C>`, the internal logic ensures that pulses produced
  ///   will conform to the [O] payload type.
  /// - **Resilience**: The transformation is protected by the same safety
  ///   boundaries as all other receptors; exceptions are caught and
  ///   trace-logged.
  /// - **Synchronous Execution**: The instruction executes synchronously.
  ///
  /// ### Type Parameters:
  /// - [C]: The concrete [Cell] type that will host this receptor.
  /// - [I]: The expected type of the incoming [Pulse] (Input).
  /// - [O]: The type of the resulting [Pulse] (Output).
  ///
  /// ### Parameters:
  /// - [instruction]: The type-safe logic unit to use for the transformation.
  ///
  /// ### Example: String to Length Transformer
  /// ```dart
  /// final lengthReceptor = Receptor.typed<MyCell, Pulse<String>, Pulse<int>>(
  ///   Instruction((p, {cell, user}) => Pulse(p.payload.length))
  /// );
  /// ```
  static Receptor<C> typed<C extends Cell, I extends Pulse, O extends Pulse>(Instruction<C,I,O> instruction) {
    return _Receptor<C>(instruction: instruction);
  }

  /// Orchestrates the formal transition of a signal from **Perception** to
  /// **Reasoning** by executing the transformation pipeline.
  ///
  /// ### When to use
  /// This is the central execution entry point for receptor logic. You rarely
  /// call this method directly in application code, as the framework invokes
  /// it automatically when a [Pulse] arrives at the cell's boundary.
  ///
  /// Manual invocation is primarily used for:
  /// - **Testing**: Verifying a receptor's transformation or filtering logic
  ///   in isolation.
  /// - **Middleware**: Manually triggering cell updates from specialized
  ///   event sources.
  ///
  /// ### How it works
  /// 1. **Handshake**: It performs an authorization handshake if the incoming
  ///    pulse is a defensive proxy (shell).
  /// 2. **Validation**: It validates the pulse against the host cell's
  ///    governance policies and invariants.
  /// 3. **Pipeline Execution**: It sequentially executes the internal stages
  ///    (e.g., `preProcess` → `instruction` → `postProcess`).
  /// 4. **Result**: It returns the final transformed [Pulse] to be committed
  ///    to state, or `null` if the signal was dropped/filtered.
  ///
  /// ### Non‑obvious
  /// - **Operational Perimeter**: The execution is bound to the host cell's
  ///   context. Accessing state or context during the call is guaranteed to
  ///   be consistent with the cell's current operational phase.
  /// - **Resilience**: The entire execution is shielded. Exceptions are
  ///   caught, logged to the pulse's forensic metadata, and the signal is
  ///   terminated (`null`) to protect graph stability.
  /// - **Synchronous Execution**: The method executes synchronously and
  ///   returns the result immediately. For asynchronous execution, use
  ///   [Receptor.async].
  /// - **Short-circuiting**: If the host cell is invalidated or the signal
  ///   fails a security check, the method returns `null` immediately without
  ///   running the transformation logic.
  /// - **Validation Async Support**: While the pipeline is synchronous,
  ///   validation can return a [Future<bool>] for asynchronous validation
  ///   checks. This is the only async operation in the call path.
  ///
  /// ### Parameters:
  /// - [pulse]: The incoming pulse to process.
  ///
  /// ### Returns:
  /// The transformed pulse, or `null` if the signal was terminated.
  FutureOr<Pulse?> call(Pulse pulse);

  /// Returns an asynchronous execution adapter for this receptor.
  ///
  /// ### When to use
  /// Use this when you need to interact with the receptor from an
  /// asynchronous context or require precise control over the signal's
  /// propagation lifecycle.
  ///
  /// - **Asynchronous Entry**: Triggering pulses from `Future`-returning
  ///   functions, network responses, or stream listeners.
  /// - **Deterministic Completion**: When you need to ensure that the
  ///   entire reactive wave is finished before proceeding (e.g., in tests
  ///   or complex multi-step updates).
  ///
  /// ### How it works
  /// 1. The getter provides a [ReceptorAsync] proxy that wraps the receptor's
  ///    core transformation logic.
  /// 2. It converts the synchronous pipeline execution into an asynchronous
  ///    [Future]-based API.
  /// 3. It exposes advanced synchronization options, such as waiting for
  ///    serialized completion across the entire downstream graph.
  ///
  /// ### Non‑obvious
  /// - **Lightweight View**: The async adapter is a stateless view of the
  ///   primary receptor; it consumes negligible memory and shares all
  ///   underlying instruction metadata.
  /// - **Full Propagation**: While a standard `await call()` only waits for
  ///    the immediate transformation, `async.call(..., serializedCompletion: true)`
  ///   waits for every downstream side-effect to settle.
  /// - **Atomic Integrity**: It maintains the integrity of the cell's
  ///   transaction boundary even when invoked from an asynchronous loop.
  /// - **Queueing**: Pulses are queued and processed sequentially to preserve
  ///   causal order.
  ///
  /// ### Returns:
  /// A [ReceptorAsync] handle for asynchronous pulse injection.
  ///
  /// ### Example: Waiting for Full Propagation
  /// ```dart
  /// // Trigger a pulse and wait for the entire graph to settle
  /// await receptor.async.call(myPulse, serializedCompletion: true);
  /// ```
  ReceptorAsync<C> get async;

  /// Formally activates the receptor by binding its transformation logic to
  /// a concrete [cell] instance.
  ///
  /// ### When to use
  /// You never call this method directly in application code. The framework
  /// invokes it automatically during the cell construction process (e.g.,
  /// via [Cell.fromNucleus]).
  ///
  /// ### How it works
  /// 1. It links the receptor to its host [cell], providing the necessary
  ///    operational context.
  /// 2. It enables the [cell] getter, allowing instructions to access the
  ///    host's state.
  /// 3. It transitions the receptor's state so that [isActivated] returns `true`.
  ///
  /// ### Non‑obvious
  /// - **One-Way Transition**: Once activated, a receptor is permanently
  ///   pinned to its cell. It cannot be re-activated or moved to a different
  ///   cell; use [clone] if you need a fresh template.
  /// - **Safety Checks**: Returns `true` on successful binding. It returns
  ///   `false` if the receptor was already activated or if the provided
  ///   cell instance is incompatible.
  ///
  /// ### Parameters:
  /// - [cell]: The cell to bind this receptor to.
  ///
  /// ### Returns:
  /// `true` if activation was successful, `false` otherwise.
  bool activate(C cell);

  /// Indicates whether this receptor has transitioned from a stateless template
  /// to a functional, cell-bound instance.
  ///
  /// ### When to use
  /// This is primarily used for **Internal Diagnostics** and **Lifecycle
  /// Management**. It allows framework extensions or custom monitoring tools
  /// to verify if a receptor is ready to process signals.
  ///
  /// ### How it works
  /// A receptor starts its life as a stateless template (blueprint). This
  /// getter returns `true` only after the [activate] method has been
  /// successfully invoked by the host [Cell] during its initialization.
  ///
  /// ### Non‑obvious
  /// - **Immutable State**: Once a receptor is activated, it remains
  ///   activated for its entire lifetime.
  /// - **Prerequisite**: Many other members, such as the [cell] getter,
  ///   require this to be `true` before they can be safely accessed.
  ///
  /// ### Returns:
  /// `true` if the receptor is activated and bound to a cell.
  bool get isActivated;

  /// Indicates whether the receptor's host [Cell] is currently operating
  /// under a **Governance Policy**.
  ///
  /// ### When to use
  /// Use this for **Conditional Logic** in custom receptors. You might
  /// choose to apply stricter validation or additional logging if you
  /// know the cell is subject to specific architectural governance.
  ///
  /// ### How it works
  /// It checks if the bound host [Cell] has a non-default operational
  /// context or specific governance metadata attached.
  ///
  /// ### Non‑obvious
  /// - **Activation Requirement**: This property is only meaningful when
  ///   [isActivated] is `true`. Accessing it on a template receptor will
  ///   return a default value or throw an error depending on the binding state.
  ///
  /// ### Returns:
  /// `true` if the host cell is governed.
  bool get isGoverned;

  /// The host [Cell] instance that this receptor is currently serving.
  ///
  /// ### When to use
  /// This is the primary way for transformation logic to access **Host
  /// Context**. Use it inside custom instructions to read the current
  /// state of the cell or to access its metadata.
  ///
  /// ### How it works
  /// It returns a reference to the [Cell] that successfully called
  /// [activate] on this receptor.
  ///
  /// ### Non‑obvious
  /// - **Late-Bound Property**: Accessing this getter before [isActivated]
  ///   is `true` will throw a [StateError].
  /// - **Type Integrity**: The returned cell is guaranteed to match the
  ///   generic type [C] specified during the receptor's construction,
  ///   ensuring compile-time safety for host-specific logic.
  ///
  /// ### Returns:
  /// The host cell instance.
  C get cell;

  /// The underlying [Instruction] used for pass-through transformations.
  ///
  /// This is an internal constant used by the framework to optimize
  /// pass-through behavior. Human developers should use [Receptor.passThrough]
  /// directly.
  ///
  /// ### Returns:
  /// A pass-through instruction that forwards pulses unchanged.
  static Instruction<Cell, Pulse, Pulse> get passThroughRule => const _PulseRulePassThrough();

}

// ─────────────────────────────────────────────────────────────────────
// _PulseRulePassThrough
// ─────────────────────────────────────────────────────────────────────

/// A pass-through instruction that forwards pulses unchanged.
///
/// [_PulseRulePassThrough] performs an identity transformation, returning the
/// input pulse unchanged. It is used internally for the default
/// [Receptor.passThrough] behavior.
///
/// ### When to use
/// This is an internal implementation detail. Use [Receptor.passThrough]
/// for pass-through behavior in application code.
///
/// ### How it works
/// The [call] method returns the input pulse unchanged.
///
/// ### Non‑obvious
/// - **Singleton Pattern**: This is typically used as a singleton instance
///   to minimize memory overhead.
/// - **Identity Transformation**: The operation is O(1) and has no side effects.
class _PulseRulePassThrough implements Instruction<Cell,Pulse,Pulse> {

  /// Creates a pass-through instruction.
  ///
  /// This constructor is typically used to create a singleton instance.
  const _PulseRulePassThrough();

  /// Combines this instruction with another.
  ///
  /// Since this is a pass-through instruction, combining it with another
  /// instruction returns the other instruction (the pass-through is a no-op).
  ///
  /// ### Parameters:
  /// - [other]: The instruction to combine with.
  ///
  /// ### Returns:
  /// The [other] instruction, as the pass-through has no effect.
  @override
  Instruction<Cell,Pulse,Pulse> operator +(covariant Instruction<Cell, Pulse<dynamic>, Pulse<dynamic>> other) {
    return other;
  }

  /// Executes the pass-through transformation.
  ///
  /// This method returns the input pulse unchanged.
  ///
  /// ### Parameters:
  /// - [pulse]: The incoming pulse to forward.
  /// - [cell]: The host cell context (ignored for pass-through).
  /// - [future]: Optional callback for asynchronous continuation (ignored).
  /// - [token]: Optional token (ignored).
  ///
  /// ### Returns:
  /// The input pulse unchanged.
  @override
  Pulse<dynamic>? call(Pulse<dynamic> pulse, {Cell? cell, void Function({required Pulse<dynamic>? result, required dynamic token})? future, dynamic token}) {
    return pulse;
  }

}
