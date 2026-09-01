// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

// ─────────────────────────────────────────────────────────────────────
// Instruction Implementation (_Instruction)
// ─────────────────────────────────────────────────────────────────────

/// The concrete implementation of [Instruction].
///
/// [_Instruction] wraps a transformation function into a formal reactive
/// contract. It is the primary workhorse for all instruction-based logic
/// in the framework.
///
/// ### When to use
/// This class is instantiated by the [Instruction] factory. You rarely need
/// to reference it directly in application code.
///
/// ### How it works
/// 1. It stores the transformation function and optional user metadata in
///    an optimized internal record.
/// 2. When [call] is invoked, it executes the function synchronously with
///    the provided parameters.
/// 3. It handles both standard and delayed/future propagation modes.
///
/// ### Non‑obvious
/// - **Flyweight Storage**: It uses record-based storage to minimize memory
///    footprint.
/// - **Type Safety**: It enforces strict type checking on results.
/// - **Const Support**: It supports `const` initialization for compile-time
///    deduplication.
/// - **Synchronous Execution**: The instruction executes synchronously.
///    Asynchronous behavior is handled via the [future] callback mechanism.
///
/// ### Type Parameters:
/// - [C]: The type of the host [Cell].
/// - [I]: The type of the incoming [Pulse].
/// - [O]: The type of the resulting [Pulse].
class _Instruction<C extends Cell, I extends Pulse, O extends Pulse> extends InstructionBase<C,I,O> {

  /// Creates a standard instruction from a transformation function.
  ///
  /// ### Parameters:
  /// - [instruction]: The transformation function.
  /// - [user]: Optional user metadata.
  const _Instruction(super.instruction, {super.user}) : super();

  /// Creates a delayed instruction with future propagation support.
  ///
  /// ### Parameters:
  /// - [instruction]: The transformation function with future callback.
  /// - [user]: Optional user metadata.
  /// - [future]: Optional future callback.
  /// - [token]: Optional token for identifying the instruction.
  const _Instruction.future(super.instruction, {super.user})
      : super.future();

}

// ─────────────────────────────────────────────────────────────────────
// InstructionBase
// ─────────────────────────────────────────────────────────────────────

/// The foundational implementation and architectural base for all [Instruction]
/// variants.
///
/// [InstructionBase] provides the common infrastructure for defining,
/// composing, and executing transformation logic within the reactive graph.
/// It is engineered for **High-Performance Composition**, allowing complex
/// processing pipelines to be built from simple, discrete functional units.
///
/// ### When to use
/// Use [InstructionBase] as the foundational class when implementing custom
/// [Instruction] variants that require shared infrastructure for execution,
/// composition, and memory optimization. It serves as the architectural
/// anchor for all logic units within the reactive fabric.
///
/// ### How it works
/// 1. **Encapsulation**: It wraps transformation functions into a formal
///    reactive contract, providing the necessary signatures to interact
///    with a [Cell] and its [Pulse] stream.
/// 2. **Composition Engine**: It implements the `+` operator, enabling the
///    sequential linking of logic units into an [InstructionChain].
/// 3. **Memory Optimization**: It utilizes a **Flyweight Strategy** by
///    packing configuration data into compact, internal records to minimize
///    heap footprint.
/// 4. **Resilient Execution**: It provides a safety boundary during
///    synchronous invocation; exceptions are caught and logged, while the
///    signal recovers using a fallback strategy to prevent graph-wide failures.
/// 5. **Future Propagation**: It supports asynchronous continuation via the
///    [future] callback mechanism.
///
/// ### Non‑obvious
/// - **Sparsity-Aware Storage**: The internal record shape is automatically
///   optimized to omit unused fields (like metadata), reducing the memory
///   tax for systems with millions of reactive nodes.
/// - **Type Integrity**: It enforces strict type checking on results,
///   ensuring that incompatible payloads are discarded to maintain
///   graph-wide type safety.
/// - **Const-Ready Design**: The class is designed to support `const`
///   initialization, ensuring that identical logic units share the same
///   physical memory address across the entire application.
/// - **Synchronous Execution**: All instruction execution is synchronous.
///   The [call] method returns the result immediately without awaiting any
///   [Future]. Asynchronous coordination is handled via the [future] callback.
///
/// ### Type Parameters:
/// * [C]: The type of the host [Cell] (the transformation target).
/// * [I]: The type of the incoming [Pulse] (the input).
/// * [O]: The type of the resulting [Pulse] (the output).
abstract class InstructionBase<C extends Cell, I extends Pulse, O extends Pulse> implements Instruction<C,I,O> {

  /// The internal configuration record storing the instruction logic.
  ///
  /// This record is optimized to only contain the fields actually used by
  /// the instruction, minimizing memory overhead.
  ///
  /// ### Fields:
  /// - [instruction]: The primary transformation function.
  /// - [long]: The delayed/future propagation function.
  /// - [user]: Optional user metadata.
  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  /// Retrieves the primary instruction function from the record.
  ///
  /// Returns `null` if no instruction is stored.
  ///
  /// ### Returns:
  /// The instruction function, or `null`.
  Function? get _instruction {
    return get<Function?>(() => _record.instruction, orElse: null);
  }

  /// Retrieves the delayed/future propagation function from the record.
  ///
  /// Returns `null` if no delayed function is stored.
  ///
  /// ### Returns:
  /// The delayed propagation function, or `null`.
  Function? get _long {
    return get<Function?>(() => _record.long, orElse: null);
  }

  /// Optional user-defined data that can be accessed within the instruction.
  ///
  /// This data is passed to the instruction function during execution.
  ///
  /// ### Returns:
  /// The user metadata, or `null` if not set.
  dynamic get _user => get<dynamic>(() => _record.user, orElse: null);

  /// Creates a synchronous logic unit that establishes the primary **Causal
  /// Contract** for a signal transformation.
  ///
  /// The default [InstructionBase] constructor is the architectural anchor for
  /// standard, discrete processing steps within the reactive fabric.
  ///
  /// ### When to use
  /// Use this constructor for standard signal processing tasks that can be
  /// completed immediately without awaiting asynchronous results.
  /// - **Data Mapping**: Transforming payloads (e.g., `pulse.map((v) => v + 1)`).
  /// - **Integrity Checks**: Validating signal metadata before propagation.
  /// - **Contextual Tagging**: Attaching or modifying forensic metadata.
  ///
  /// ### How it works
  /// 1. **Encapsulation**: It wraps the provided [instruction] function into
  ///    a formal [Instruction] interface.
  /// 2. **Context Injection**: During execution, the host [Cell] and optional
  ///    [user] metadata are automatically passed to the logic block.
  /// 3. **Record Optimization**: The logic and metadata are stored in a
  ///    compact record to minimize memory footprint.
  ///
  /// ### Non‑obvious
  /// - **Atomic Execution**: The logic defined here is strictly synchronous.
  ///   If your transformation requires a [Future], use [InstructionBase.future].
  /// - **Deduplication**: As a `const` constructor, it supports the framework's
  ///   **Flyweight Strategy**, allowing identical logic units to share memory
  ///   addresses.
  /// - **Metadata Isolation**: The [user] parameter allows logic to be
  ///   parameterized by "Mandate" or "Role" data without needing access to
  ///   external variables.
  ///
  /// ### Example
  /// ```dart
  /// final increment = InstructionBase<CounterCell, Pulse<int>, Pulse<int>>(
  ///   (pulse, {cell, user}) => pulse.map((v) => v + 1)
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// * [instruction]: **The Logic Gateway.** A synchronous function that
  ///   defines how the input [Pulse] is transformed. Returning `null`
  ///   effectively terminates the signal path.
  /// * [user]: **Operational Context.** Optional metadata passed to the
  ///   instruction at runtime to guide its behavior.
  ///
  /// ### Returns:
  /// An [Instruction] instance representing a **Synchronous Transformation Gate**.
  ///
  /// ### See Also:
  /// * [InstructionBase.future]: For logic units requiring asynchronous deferral.
  /// * [InstructionChain]: For linking multiple logic gates into a pipeline.
  const InstructionBase(
      O? Function(I pulse, {C? cell, dynamic user}) instruction, {dynamic user})
      : _record = user != null
        ? (instruction: instruction, user: user)
        : (instruction: instruction);

  /// Creates a base rule with future propagation support.
  ///
  /// ### When to use
  /// Use this constructor when the instruction needs to control when
  /// propagation continues after an asynchronous operation, such as for
  /// implementing delays, debouncing, or conditional propagation.
  ///
  /// ### How it works
  /// 1. The [instruction] function receives a [future] callback.
  /// 2. The [token] parameter identifies which instruction is being processed.
  /// 3. The callback must be called to continue propagation.
  /// 4. The instruction itself returns `null` immediately, deferring the
  ///    actual propagation to the callback.
  ///
  /// ### Parameters:
  /// - [instruction]: The function with access to the [future] callback.
  /// - [user]: Optional user metadata.
  const InstructionBase.future(
      O? Function(I pulse, {C? cell, dynamic user,
      void Function({required Pulse? result, required dynamic token})? future,
      dynamic token
      }) instruction, {dynamic user})
      : _record = user != null ? (long: instruction, user: user) : (long: instruction);

  /// Creates a base rule directly from a property record.
  ///
  /// This constructor is intended for internal use and advanced extension patterns,
  /// allowing for direct assignment of the configuration record.
  ///
  /// ### Parameters:
  /// - [record]: The pre-configured record containing instruction logic.
  const InstructionBase.fromRecord(dynamic record) : _record = record;

  /// Executes the transformation logic of this instruction with built-in
  /// resilience.
  ///
  /// ### When to use
  /// This is the primary internal execution engine for instructions. It is
  /// typically invoked by a host receptor or a parent chain. Manual
  /// invocation is primarily useful for:
  /// - **Unit Testing**: Verifying transformation logic in isolation.
  /// - **Logic Integration**: Manually processing a signal within a
  ///   specialized reactive context.
  ///
  /// ### How it works
  /// 1. It resolves the logic and metadata from the internal optimized
  ///    configuration.
  /// 2. It invokes the instruction function synchronously with the provided
  ///    pulse, cell context, and user metadata.
  /// 3. It enforces **Type Integrity** by validating that the result matches
  ///    the expected output type.
  /// 4. If the instruction was created with [Instruction.future], the
  ///    [future] callback is provided to enable asynchronous continuation.
  ///
  /// ### Non‑obvious
  /// - **Safety Boundary**: The execution is protected. Any exception is
  ///   caught and logged to the pulse's forensic trace. In the event of a
  ///   failure, the method returns `null` to safely terminate the signal
  ///   and protect the stability of the graph.
  /// - **Synchronous Execution**: This method executes synchronously and
  ///   returns immediately. It does not await any [Future].
  /// - **Execution Order**: The optional [future] callback is provided only
  ///   to instructions created with [Instruction.future].
  /// - **Efficiency**: It uses a linear execution path to minimize overhead
  ///   in high-frequency signal graphs.
  ///
  /// ### Parameters:
  /// - [pulse]: The incoming pulse to transform.
  /// - [cell]: The host cell context.
  /// - [future]: Optional callback for asynchronous continuation.
  /// - [token]: Optional token for identifying the instruction.
  /// - [user]: Optional user metadata (overrides the stored user).
  ///
  /// ### Returns:
  /// The transformed pulse, or `null` if the signal was terminated.
  @override
  O? call(I pulse, {
    C? cell,
    void Function({required Pulse? result, required dynamic token})? future,
    dynamic token
  }) {
    void future_({required Pulse? result, required dynamic token}) {
      future?.call(result: result, token: token);
    }

    try {
      Pulse? result;
      final instruction = _instruction;
      if (instruction != null) {
        result = instruction(pulse, cell: cell, user: _user);
      } else {
        final long = _long;
        if (long != null) {
          result = long(pulse, cell: cell, user: _user, future: future_, token: null);
        }
      }

      if (result == null) return null;
      return result as dynamic;
    } catch(e, stackTrace) {
      (pulse as PulseBase)._fail(e, stackTrace: stackTrace);
    }
    return null;
  }

  /// Combines this rule with another to create a [InstructionChain].
  ///
  /// This operator returns a new [InstructionChain] where `this` rule will be
  /// executed first, followed by the [other] rule, creating a sequential
  /// synchronous pipeline.
  ///
  /// ### Parameters:
  /// - [other]: The `Instruction` to append to the processing chain.
  ///
  /// ### Returns:
  /// A new [InstructionChain] containing both rules.
  @override
  Instruction<C,I,O> operator +(covariant Instruction other) {
    return InstructionChain<C,I,O>([this, other]);
  }

}

// ─────────────────────────────────────────────────────────────────────
// _PassThroughReceptor
// ─────────────────────────────────────────────────────────────────────

/// A singleton receptor that performs identity transformation.
///
/// [_PassThroughReceptor] implements the pass-through behavior for the
/// [Receptor.passThrough] constant. It returns pulses unchanged and
/// cannot be activated.
///
/// ### When to use
/// This is an internal implementation detail. Use [Receptor.passThrough].
///
/// ### How it works
/// - [call] returns the input pulse unchanged.
/// - [activate] always returns `false`.
/// - [clone] returns the same instance (singleton).
///
/// ### Non‑obvious
/// - **Singleton**: Only one instance exists, shared across all cells.
/// - **Immutable**: The receptor has no state and cannot be modified.
/// - **Unactivatable**: This receptor cannot be activated and is always
///   in a stateless template state.
/// - **Type Parameter**: Uses [Never] as the cell type since it can never
///   be activated and thus never has a valid cell reference.
class _PassThroughReceptor implements Receptor<Never> {

  /// The singleton instance.
  static const _singleton = _PassThroughReceptor();

  /// Creates the singleton pass-through receptor.
  ///
  /// This constructor is private and only used to create the singleton.
  const _PassThroughReceptor();

  /// The host cell for this receptor.
  ///
  /// Since this is a pass-through receptor, accessing this property throws
  /// an [UnsupportedError].
  ///
  /// ### Throws:
  /// [UnsupportedError] always.
  @override
  Never get cell => throw UnsupportedError('PassThroughReceptor');

  /// Activates the receptor by binding it to a cell.
  ///
  /// Since this is a pass-through receptor, activation is not supported.
  ///
  /// ### Parameters:
  /// - [cell]: The cell to bind to (ignored).
  ///
  /// ### Returns:
  /// Always `false`.
  @override
  bool activate(Cell cell) => false;

  /// Returns an asynchronous adapter for this receptor.
  ///
  /// Since this is a pass-through receptor, async operations are not supported.
  ///
  /// ### Throws:
  /// [UnsupportedError] always.
  @override
  ReceptorAsync<Never> get async => throw UnsupportedError('PassthroughSyncReceptor');

  /// Executes the pass-through transformation.
  ///
  /// This method returns the input pulse unchanged.
  ///
  /// ### Parameters:
  /// - [pulse]: The incoming pulse to forward.
  ///
  /// ### Returns:
  /// The input pulse unchanged.
  @override
  Pulse? call(Pulse pulse) => pulse;

  /// Returns a clone of this receptor.
  ///
  /// Since this is a singleton, the clone returns the same instance.
  ///
  /// ### Returns:
  /// This same instance.
  @override
  Receptor<Never> get clone => this;

  /// Indicates whether this receptor is activated.
  ///
  /// Since this is a pass-through receptor, it is never activated.
  ///
  /// ### Returns:
  /// Always `false`.
  @override
  bool get isActivated => false;

  /// Equality operator for pass-through receptors.
  ///
  /// All pass-through receptors are considered equal.
  ///
  /// ### Parameters:
  /// - [other]: The object to compare with.
  ///
  /// ### Returns:
  /// `true` if the other object is also a pass-through receptor.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is _PassThroughReceptor) return true;
    if (other is ReceptorBase) {
      try {
        if (other._record.$2 != null) {
          return false;
        }
      } catch(_) {
        return true;
      }
    }
    return false;
  }

  /// Hash code for this receptor.
  ///
  /// Returns the identity hash code of the singleton instance.
  @override
  int get hashCode => identityHashCode(_singleton);

  /// Indicates whether this receptor is governed.
  ///
  /// Since this is a pass-through receptor, it is never governed.
  ///
  /// ### Returns:
  /// Always `false`.
  @override
  bool get isGoverned => false;

}

// ─────────────────────────────────────────────────────────────────────
// _Receptor
// ─────────────────────────────────────────────────────────────────────

/// The concrete implementation of [Receptor].
///
/// [_Receptor] wraps one or more instructions into a complete transformation
/// pipeline. It manages the three stages (preProcess, instruction, postProcess)
/// and handles activation and cloning.
///
/// ### When to use
/// This class is instantiated by the [Receptor] factories. You rarely need
/// to reference it directly in application code.
///
/// ### How it works
/// 1. It stores the pipeline instructions in an optimized record.
/// 2. When [call] is invoked, it executes the pipeline synchronously in order.
/// 3. Activation binds the receptor to a specific cell.
/// 4. Cloning creates a new unactivated instance.
///
/// ### Non‑obvious
/// - **Flyweight Storage**: It uses record-based storage for efficiency.
/// - **Stateless Template**: It only becomes active when bound to a cell.
/// - **Clone Isolation**: Clones are independent instances.
///
/// ### Type Parameters:
/// - [C]: The type of the host [Cell].
class _Receptor<C extends Cell> extends ReceptorBase<C>{

  /// Creates a receptor with the specified pipeline instructions.
  ///
  /// ### Parameters:
  /// - [instruction]: The core transformation instruction.
  /// - [preProcess]: Sanitization stage.
  /// - [postProcess]: Commitment/validation stage.
  /// - [reaction]: Simplified reaction function.
  /// - [user]: Optional user metadata.
  /// - [isGoverned]: Whether this receptor is governed.
  _Receptor({super.instruction, super.preProcess, super.postProcess, super.reaction, super.init, super.user, super.isGoverned}) : super();

  /// Creates a receptor from a pre-configured record.
  ///
  /// ### Parameters:
  /// - [record]: The configuration record containing pipeline logic.
  _Receptor.fromRecord({super.record}) : super.fromRecord();

  /// Returns a clone of this receptor.
  ///
  /// The clone is a new unactivated instance with the same configuration.
  ///
  /// ### Returns:
  /// A new [Receptor] instance with the same logic.
  @override
  Receptor<C> get clone => _Receptor.fromRecord(record: _record);

}


// ─────────────────────────────────────────────────────────────────────
// ReceptorBase
// ─────────────────────────────────────────────────────────────────────

/// The foundational base implementation of [Receptor] that provides the
/// core synchronization and pulse propagation engine.
///
/// [ReceptorBase] manages the multi-stage pipeline, error handling, and
/// coordination of signal propagation. It serves as the bridge between
/// incoming stimuli and the cell's internal state.
///
/// ### When to use
/// Use [ReceptorBase] as the base class for specialized receptor
/// implementations. You typically don't construct this directly; instead,
/// use the [Receptor] factory or predefined singletons.
///
/// ### How it works
/// 1. **Pipeline Management**: It stores and coordinates the three stages
///    (Sanitization, Core Logic, and Commitment).
/// 2. **Context Binding**: It manages the transition from a stateless
///    template to an activated, cell-bound instance.
/// 3. **Resilient Propagation**: The `call` method validates the signal,
///    runs the pipeline synchronously, and safely broadcasts results to
///    synapses.
/// 4. **Lifecycle Control**: It handles the activation and cloning of
///    logic blueprints across different cell instances.
/// 5. **Governance**: When governed, it applies architectural policies and
///    forensic trace information.
///
/// ### Non‑obvious
/// - **Flyweight Architecture**: It utilizes a record-based storage
///   strategy to pack all pipeline instructions into a single memory block.
/// - **Traceability**: Every propagation step is logged to the pulse's
///   metadata, providing full forensic visibility for debugging.
/// - **Thread-Safe Context**: Activation pins the receptor to a specific
///   operational perimeter, ensuring state access is always consistent.
/// - **Synchronous Pipeline**: The pipeline executes synchronously. For
///   asynchronous execution, use [ReceptorAsync].
/// - **Validation Async Support**: While the pipeline is synchronous,
///   validation can return a [Future<bool>] for asynchronous validation
///   checks. This is the only async operation in the call path.
///
/// ### Type Parameters:
/// * [C]: The type of the host [Cell].
abstract class ReceptorBase<C extends Cell> implements Receptor<C> {

  /// The internal configuration record storing the pipeline instructions.
  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  /// The host cell this receptor is bound to.
  ///
  /// This field is set when [activate] is called.
  /// Accessing it before activation throws a [StateError].
  @override
  late final C cell;

  /// Initializes the foundational engine for pulse transformation and
  /// state governance.
  ///
  /// ### When to use
  /// This is the primary constructor for building specialized receptors. Use
  /// it to assemble a structured processing pipeline where sanitization,
  /// core logic, and commitment are explicitly separated.
  ///
  /// - **Complex Validations**: When you need to guard a cell with multi-stage
  ///   checks (pre-processing).
  /// - **Functional Mapping**: When using a simple [reaction] function instead
  ///   of a full instruction object.
  /// - **Governance Nodes**: When creating cells that must adhere to strict
  ///   architectural invariants ([isGoverned]).
  ///
  /// ### How it works
  /// 1. **Pipeline Assembly**: It organizes optional logic units into a
  ///    hierarchical sequence: `preProcess` → `instruction`/`reaction` → `postProcess`.
  /// 2. **Input Gating**: The [preProcess] stage acts as a "Sanitizer." If it
  ///    returns `null`, the receptor terminates propagation immediately.
  /// 3. **Core Transformation**: The [instruction] (or [reaction] closure)
  ///    executes the primary mapping of the stimulus to the cell's value type.
  /// 4. **Commitment**: The [postProcess] stage handles final integrity
  ///    checks and persistence logic before the pulse is broadcast downstream.
  /// 5. **Metadata Injection**: The [user] factory generates dynamic
  ///    metadata passed to every stage.
  /// 6. **Synchronous Pipeline**: All stages execute synchronously in sequence.
  ///
  /// ### Non‑obvious
  /// - **Memory Efficiency**: It utilizes a **Flyweight Record Strategy**. The
  ///   internal storage shape is optimized at construction to only allocate
  ///   memory for the logic units actually provided.
  /// - **Safety Shield**: Each stage of the pipeline is independently wrapped
  ///   in a resilience boundary. Exceptions are caught and logged to the
  ///   pulse's trace, ensuring a logic failure doesn't crash the entire graph.
  /// - **Stateless Template**: Like all receptors, this constructor creates
  ///   a blueprint. It only acquires a concrete execution context once
  ///   bound to a specific cell.
  /// - **Initialization Hook**: The [init] parameter allows for setup logic
  ///   that runs exactly once when the receptor is first activated by a cell.
  /// - **Synchronous Execution**: The [call] method executes synchronously.
  ///   Use [ReceptorAsync] for asynchronous pulse injection.
  ///
  /// ### Parameters:
  /// - [instruction]: The core [Instruction] defining the primary transformation.
  /// - [preProcess]: Logic for early-stage filtering or sanitization.
  /// - [postProcess]: Logic for late-stage persistence and commitment.
  /// - [reaction]: A simplified functional interface for basic transformations.
  /// - [init]: A one-time setup hook triggered during cell activation.
  /// - [user]: A factory for dynamic metadata passed to the pipeline.
  /// - [isGoverned]: Flags this receptor as subject to architectural governance.
  ReceptorBase({
    Instruction? instruction,
    Instruction? preProcess,
    Instruction? postProcess,
    Pulse? Function(Pulse pulse, C host, {dynamic user})? reaction,
    void Function()? init,
    dynamic Function()? user,
    bool isGoverned = false,
  }) : this.fromRecord(record: mask(instruction: instruction, preProcess: preProcess, postProcess: postProcess, reaction: reaction, user: user, init: init, isGoverned: isGoverned)
  );

  /// Creates a mask record for the receptor configuration.
  ///
  /// This internal method optimizes the storage of pipeline instructions
  /// by only including fields that are actually used.
  ///
  /// ### Parameters:
  /// - [instruction]: The core transformation instruction.
  /// - [preProcess]: Sanitization stage.
  /// - [postProcess]: Commitment stage.
  /// - [reaction]: Simplified reaction function.
  /// - [user]: User metadata factory.
  /// - [init]: Initialization function.
  /// - [isGoverned]: Governance flag.
  ///
  /// ### Returns:
  /// A record containing only the provided fields, optimized for memory.
  static Record mask({
    Instruction? instruction,
    Instruction? preProcess,
    Instruction? postProcess,
    Function? reaction,
    Function? user,
    Function? init,
    bool isGoverned = false,
  }) {

    final instructionMask = (
        (instruction != null ? 1 : 0) |
        (preProcess != null ? 2 : 0 ) |
        (postProcess != null ? 4 : 0) |
        (reaction != null ? 8 : 0)
    );

    final instructionRecord = switch (instructionMask) {
      0 => (),
      1 => (instruction: instruction),
      2 => (preProcess: preProcess),
      3 => (instruction: instruction, preProcess: preProcess),
      4 => (postProcess: postProcess),
      5 => (instruction: instruction, postProcess: postProcess),
      6 => (preProcess: preProcess, postProcess: postProcess),
      7 => (instruction: instruction, preProcess: preProcess, postProcess: postProcess),
      8 => (reaction: reaction),
      9 => (instruction: instruction, reaction: reaction),
      10 => (preProcess: preProcess, reaction: reaction),
      11 => (instruction: instruction, preProcess: preProcess, reaction: reaction),
      12 => (postProcess: postProcess, reaction: reaction),
      13 => (instruction: instruction, postProcess: postProcess, reaction: reaction),
      14 => (preProcess: preProcess, postProcess: postProcess, reaction: reaction),
      15 => (instruction: instruction, preProcess: preProcess, postProcess: postProcess, reaction: reaction),
      _ => ()
    };

    final mask = (
        (instructionMask != 0 ? 1 : 0) |
        (init != null ? 2 : 0) |
        (user != null ? 4 : 0) |
        (isGoverned ? 8 : 0)
    );

    final userBox = user != null ? (FinalBox()..value = user()) : null;

    return switch (mask) {
      0 => (),
      1 => (instruction: instructionRecord),
      2 => (init: init),
      3 => (instruction: instructionRecord, init: init),
      4 => (user: user, userBox: userBox),
      5 => (instruction: instructionRecord, user: user, userBox: userBox),
      6 => (init: init, user: user, userBox: userBox),
      7 => (instruction: instructionRecord, init: init, user: user, userBox: userBox),
      8 => (isGoverned: isGoverned),
      9 => (instruction: instructionRecord, isGoverned: isGoverned),
      10 => (init: init, isGoverned: isGoverned),
      11 => (instruction: instructionRecord, init: init, isGoverned: isGoverned),
      12 => (user: user, userBox: userBox, isGoverned: isGoverned),
      13 => (instruction: instructionRecord, user: user, userBox: userBox, isGoverned: isGoverned),
      14 => (init: init, user: user, userBox: userBox, isGoverned: isGoverned),
      15 => (instruction: instructionRecord, init: init, user: user, userBox: userBox, isGoverned: isGoverned),
      _ => ()
    };
  }

  /// A foundational constructor that initializes a [ReceptorBase] from a
  /// pre-compiled [Record] of configuration properties.
  ///
  /// ### When to use
  /// This constructor serves as the primary initialization anchor for the entire
  /// receptor hierarchy. You typically don't use it directly; it is designed
  /// to be invoked by public factories to efficiently store the operational
  /// strategy gathered during the construction phase.
  ///
  /// ### How it works
  /// 1. **Configuration Anchoring**: It receives a compact [Record] containing
  ///    the transformation logic, validation rules, and metadata.
  /// 2. **Property Resolution**: During signal propagation, the receptor
  ///    resolves its operational logic from this unified bundle.
  /// 3. **Architectural Decoupling**: It separates the public-facing API from
  ///    the internal storage mechanism, ensuring the framework can optimize
  ///    memory usage without impacting user code.
  ///
  /// ### Non‑obvious
  /// - **Flyweight Strategy**: Unlike standard field-based architectures,
  ///   Record-based storage ensures that instances only allocate memory for
  ///   the properties they actually use. This significantly reduces the
  ///   heap footprint in graphs with millions of reactive nodes.
  /// - **Const Support**: This initialization pattern allows receptors to be
  ///   defined as `const`, enabling the compiler to deduplicate identical
  ///   logic units across the entire application.
  /// - **Immutability**: By anchoring a pre-compiled record, the receptor
  ///   guarantees that its behavior is fixed at construction, preserving
  ///   the deterministic consistency of the reactive pulse chain.
  ///
  /// ### Parameters:
  /// - [record]: The optimized configuration bundle for the receptor.
  ReceptorBase.fromRecord({Record record = ()}) : _record = record;

  /// The internal execution entry point for signal propagation and
  /// transformation.
  ///
  /// ### When to use
  /// This method is the primary driver of the receptor's operational logic.
  /// It is invoked automatically by the framework when a [Pulse] arrives
  /// at the cell boundary. Manual invocation is recommended only for:
  /// - **Testing**: Verifying the integration of validation and transformation
  ///   logic.
  /// - **Custom Propagation**: Building specialized reactive engines that
  ///   orchestrate their own pulse timing.
  ///
  /// ### How it works
  /// 1. **Proxy Scrutiny**: Performs a security handshake if the incoming
  ///    pulse is a defensive proxy ([Shell]).
  /// 2. **Cycle Prevention**: Verifies that the pulse hasn't already been
  ///    processed by this cell to prevent infinite recursive loops.
  /// 3. **Governance**: If the cell is governed, it applies architectural
  ///    policies and appends forensic trace information to the pulse.
  /// 4. **Validation**: Invokes the host cell's internal validation logic
  ///    to ensure the pulse complies with all operational invariants.
  /// 5. **Transformation Pipeline**: Executes the sequential logic stages
  ///    (sanitization, core logic, commitment) synchronously.
  /// 6. **Broadcast**: If successful, the resulting pulse is automatically
  ///    propagated to all downstream synapses.
  ///
  /// ### Non‑obvious
  /// - **Safety Shield**: The entire call stack is protected by a resilience
  ///   boundary. Exceptions are caught and logged to the pulse's forensic
  ///   trace, and the signal is safely terminated (`null`) to protect graph
  ///   stability.
  /// - **Synchronous Execution**: The method executes synchronously and
  ///   returns the result immediately. For asynchronous execution, use
  ///   [ReceptorAsync].
  /// - **Auditability**: In governed mode, every execution step is recorded,
  ///   providing a complete audit trail of how data flowed through the graph.
  /// - **Short-circuiting**: Signal propagation is aborted immediately if
  ///   the cell is invalidated, validation fails, or a transformation
  ///   stage returns `null`.
  /// - **Validation Async Support**: While the pipeline is synchronous,
  ///   validation can return a [Future<bool>] for asynchronous validation
  ///   checks. This is the only async operation in the call path.
  ///
  /// ### Parameters:
  /// - [incoming]: The incoming pulse to process.
  ///
  /// ### Returns:
  /// The transformed pulse, or `null` if the signal was terminated.
  @override
  FutureOr<Pulse?> call(covariant Pulse incoming) {
    assert(isActivated,
    'Receptor call failed: The receptor must be activated before it can process pulses. '
        'Verify that the host cell has been properly initialized and is not in a disposed state.');

    if (incoming is Shell) {
      return incoming.scrutinize(this, null);
    }

    var pulse = incoming as PulseBase;
    if (!isActivated || !pulse._checker.add(cell)) return null;

    FutureOr<Pulse?> proceed() {

      if (isGoverned) {
        if (cell.isInvalidated || pulse.isInvalidated) return null;

        final ephemeralPolicy = (cell._nucleus as NucleusBase)._ephemeralPolicy;
        if (ephemeralPolicy != null) {
          ephemeralPolicy(pulse, cell: cell);
          if (pulse.isInvalidated) return null;
        }
      }
      if (cell.isInvalidated) {
        return null;
      }

      if (pulse.isGoverned) {

        if (pulse.isInvalidated) return null;

        final pulseEphemeralPolicy = pulse.policy;
        if (pulseEphemeralPolicy != null) {
          pulseEphemeralPolicy._onPulseComplete(pulse, cell: cell);
          if (pulse.isInvalidated) return null;
        }

        final step = cell.context is DeputyContext
            ? (cell.context as DeputyContext).role ?? cell.toString()
            : cell.toString();

        pulse = pulse.withStep(step) as PulseBase;
      }
      if (pulse.isInvalidated) {
        return null;
      }

      final result = _onPulseReceived(pulse);
      if (result != null) {
        _propagate(pulse, result: result);
      }
      return result;
    }

    final validation = cell.validate(pulse, host: cell);
    if (validation is Future<bool>) {
      return validation.then((isValid) => isValid ? proceed() : null);
    } else if (!validation) {
      return null;
    }

    return proceed();
  }

  /// Propagates a pulse to downstream synapses.
  ///
  /// This method forwards the result pulse to the cell's nucleus for
  /// broadcast to all registered synapses.
  ///
  /// ### Parameters:
  /// - [input]: The original input pulse.
  /// - [result]: The result pulse to propagate.
  void _propagate(PulseBase input, {PulseBase? result}) {
    if (result != null) {
      final nucleus = cell._nucleus as NucleusBase;
      nucleus._propagate(result);
    }
  }

  /// Handles a received pulse by executing the transformation pipeline
  /// synchronously.
  ///
  /// ### How it works
  /// 1. Marks the pulse as in-progress.
  /// 2. If a [reaction] is provided, executes it directly.
  /// 3. Otherwise, executes the chain: `preProcess` → `instruction` → `postProcess`.
  /// 4. Returns the transformed pulse or `null` if terminated.
  ///
  /// ### Parameters:
  /// - [pulse]: The incoming pulse to process.
  ///
  /// ### Returns:
  /// The transformed pulse, or `null` if terminated.
  PulseBase? _onPulseReceived(PulseBase pulse) {
    try {
      pulse._progress(cell);

      final reaction= _reaction;
      if (reaction != null) {
        final result = reaction(pulse, cell, user: _user);
        return identical(result, pulse) ? pulse : pulse.isGoverned ? pulse.evolve(pulse: result) as PulseBase : result;
      }

      // Chain logic: preProcess -> instruction -> postProcess
      return _executeChain(pulse, cell);
    } catch (e, stackTrace) {
      pulse._fail(e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Executes the pre → instruction → post chain synchronously.
  ///
  /// ### How it works
  /// 1. Iterates through the chain in order.
  /// 2. Each instruction's result becomes the input for the next.
  /// 3. If any instruction returns `null`, the chain short-circuits.
  /// 4. The final result is returned or `null` if terminated.
  ///
  /// ### Parameters:
  /// - [pulse]: The incoming pulse to transform.
  /// - [cell]: The host cell context.
  ///
  /// ### Returns:
  /// The final transformed pulse, or `null` if terminated.
  PulseBase? _executeChain(PulseBase pulse, C cell) {
    final chain = [_preProcess, _instruction, _postProcess];

    PulseBase? currentPulse = pulse;
    for (final instruction in chain) {
      if (instruction == null) continue;
      if (currentPulse == null) break;
      try {
        currentPulse = instruction.call(currentPulse.last, cell: cell) as PulseBase?;
      } catch (e, stackTrace) {
        pulse._fail(e, stackTrace: stackTrace);
        return null;
      }

    }

    if (currentPulse is! Future) {
      return identical(currentPulse, pulse) ? pulse : pulse.isGoverned ? pulse.evolve(pulse: currentPulse) as PulseBase : currentPulse;
    }
    return currentPulse;
  }

  /// Retrieves the reaction function from the configuration.
  ///
  /// ### Returns:
  /// The reaction function, or `null` if not set.
  Function? get _reaction => get<Function?>(() => _record.instruction.reaction, orElse: null);

  /// Retrieves the user metadata from the configuration.
  ///
  /// ### Returns:
  /// The user metadata as a [FinalBox], or `null` if not set.
  dynamic get _user => get<FinalBox?>(() => _record.userBox, orElse: null);

  /// Retrieves the initialization function from the configuration.
  ///
  /// ### Returns:
  /// The initialization function, or `null` if not set.
  Function? get _init => get<Function?>(() => _record.init, orElse: null);

  /// Retrieves the core instruction from the configuration.
  ///
  /// ### Returns:
  /// The core [Instruction], or `null` if not set.
  Instruction? get _instruction => get<Instruction?>(() => _record.instruction.instruction, orElse: null);

  /// Retrieves the pre-process instruction from the configuration.
  ///
  /// ### Returns:
  /// The pre-process [Instruction], or `null` if not set.
  Instruction? get _preProcess => get<Instruction?>(() => _record.instruction.preProcess, orElse: null);

  /// Retrieves the post-process instruction from the configuration.
  ///
  /// ### Returns:
  /// The post-process [Instruction], or `null` if not set.
  Instruction? get _postProcess => get<Instruction?>(() => _record.instruction.postProcess, orElse: null);

  /// Returns an asynchronous adapter for this receptor.
  ///
  /// This implementation wraps the current [ReceptorBase] instance in a [ReceptorAsync].
  /// When called, the [ReceptorAsync] will delegate execution to this receptor's
  /// synchronous logic within a [Future], allowing for non-blocking execution.
  ///
  /// ### Returns:
  /// A [ReceptorAsync] handle for asynchronous pulse injection.
  @override
  ReceptorAsync<C> get async => ReceptorAsync<C>(this);

  /// Equality operator for receptors.
  ///
  /// Two receptors are considered equal if they have the same configuration
  /// record. Pass-through receptors are considered equal to each other.
  ///
  /// ### Parameters:
  /// - [other]: The object to compare with.
  ///
  /// ### Returns:
  /// `true` if the receptors are equal, `false` otherwise.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Receptor) {
      if (other == Receptor.passThrough) {
        try {
          if ([_instruction, _preProcess, _postProcess, _reaction].every((r) {
            return r == null;
          })) {
            return false;
          }
        } catch(_) {
          return true;
        }
      }
    }
    return false;
  }

  /// Hash code for this receptor.
  ///
  /// Returns the hash code of the configuration record.
  @override
  int get hashCode => _record.hashCode;

  /// Activates the receptor by binding it to a cell.
  ///
  /// ### How it works
  /// 1. Stores the cell reference.
  /// 2. Executes the initialization function if provided.
  /// 3. Marks the receptor as activated.
  ///
  /// ### Parameters:
  /// - [cell]: The cell to bind to.
  ///
  /// ### Returns:
  /// `true` if activation was successful, `false` otherwise.
  @override
  bool activate(C cell) {
    try {
      this.cell = cell;
      _init?.call();
      return true;
    } catch(_) {}
    return false;
  }

  /// Indicates whether this receptor is activated.
  ///
  /// A receptor is activated when it has been successfully bound to a cell
  /// via [activate].
  ///
  /// ### Returns:
  /// `true` if the receptor is activated and bound to a cell.
  @override
  bool get isActivated {
    try {
      // ignore: unnecessary_null_comparison
      return cell != null;
    } catch (_) {}
    return false;
  }

  /// Indicates whether this receptor is governed.
  ///
  /// A governed receptor applies architectural policies and forensic
  /// trace information during pulse processing.
  ///
  /// ### Returns:
  /// `true` if the receptor is governed, `false` otherwise.
  @override
  bool get isGoverned {
    try {
      return _record.isGoverned;
    } catch (_) {}
    return false;
  }

}

// ─────────────────────────────────────────────────────────────────────
// ReceptorAsync
// ─────────────────────────────────────────────────────────────────────

/// An asynchronous execution handle for a [Receptor] that facilitates
/// non‑blocking pulse processing and lifecycle synchronization.
///
/// [ReceptorAsync] provides a `Future`-based API for interacting with cells,
/// ensuring that reactive signals can be injected from asynchronous contexts
/// while maintaining strict causal order and transactional integrity.
///
/// ### When to use
/// Use the async view when you need to bridge asynchronous events into the
/// reactive graph.
///
/// - **Event Integration**: Injecting pulses from timers, network responses,
///   or user interactions.
/// - **Deterministic Testing**: Waiting for a reactive wave to fully settle
///   before asserting results.
/// - **Backpressure Management**: Coordinating sequential updates in high-
///   throughput scenarios.
///
/// ### How it works
/// 1. **Queueing**: Pulses are added to a thread-safe internal queue to
///    preserve the order of arrival.
/// 2. **Sequential Processing**: A worker drains the queue, executing each
///    pulse within the cell's atomic perimeter using the synchronous pipeline.
/// 3. **Future Mapping**: It converts the receptor's synchronous logic into
///    a guaranteed [Future]-based API.
/// 4. **Synchronized Completion**: It can optionally wait for every
///    downstream synapse to finish propagation before resolving.
///
/// ### Non‑obvious
/// - **Memory Awareness**: The internal buffer is unbounded; high-frequency
///   bursts without proper awaiting can lead to memory pressure.
/// - **Causal Consistency**: By default, it preserves the order of signals
///   even if the underlying transformations are asynchronous.
/// - **Atomicity**: Even when called asynchronously, the actual state transition
///   is protected by the cell's lock, preventing race conditions.
/// - **Identity Integrity**: The async handle is a stateless proxy; it
///   shares the same operational context and metadata as the primary receptor.
/// - **Synchronous Pipeline**: The underlying pipeline executes synchronously.
///   The async adapter only manages the execution timing and completion.
///
/// ### Type Parameters:
/// * [C]: The type of the host [Cell].
///
/// ### Example: Fire-and-Forget
/// ```dart
/// receptor.async.call(Pulse('Update'));
/// ```
///
/// ### Example: Await Full Propagation
/// ```dart
/// await receptor.async.call(Pulse('Critical'), serializedCompletion: true);
/// // At this point, the entire downstream graph has settled.
/// ```
///
/// See also:
/// * [Receptor.async] – The getter that provides this handle.
class ReceptorAsync<C extends Cell> implements Async {

  /// The underlying receptor that processes pulses synchronously.
  final ReceptorBase<C> _receptor;

  /// The internal buffer for pending stimuli and their completion mandates.
  ///
  /// This queue ensures that pulses are processed in FIFO order,
  /// preserving causal consistency even when multiple pulses are injected
  /// asynchronously.
  final SyncQueue<PulseBase> _queue = SyncQueue();

  /// Creates an asynchronous adapter for a synchronous [Receptor].
  ///
  /// ### When to use
  /// This constructor is intended for internal framework use. Application
  /// code should always access the async adapter via the [Receptor.async]
  /// getter.
  ///
  /// ### How it works
  /// It establishes a proxy relationship with the source receptor, gaining
  /// access to its transformation pipeline and cell context while
  /// initializing the internal asynchronous coordination engine.
  ///
  /// ### Non‑obvious
  /// - **Lazy Initialization**: The internal processing worker is not
  ///   started until the first pulse is injected via the [call] method.
  /// - **Reference Stability**: The adapter maintains a stable reference
  ///   to its source, ensuring that activation status is always synchronized.
  ///
  /// ### Parameters:
  /// - [receptor]: The underlying receptor to adapt for asynchronous
  ///   execution.
  ReceptorAsync(ReceptorBase<C> receptor) : _receptor = receptor;

  /// Injects a pulse into the receptor's transformation pipeline
  /// asynchronously.
  ///
  /// ### When to use:
  /// - **Event Integration**: The primary method for triggering cell updates
  ///   from asynchronous code blocks, network responses, or timers.
  /// - **Causal Sequencing**: When you need to ensure multiple updates are
  ///   processed in the exact order they were triggered.
  /// - **Testing**: Using the [hook] to intercept transformation results
  ///   without affecting the production graph.
  ///
  /// ### How it works:
  /// 1. **Handshake**: Resolves reciprocal authorization if the pulse is a
  ///    defensive proxy ([Shell]).
  /// 2. **Validation**: Checks for cycles and cell validity before queueing.
  /// 3. **Queueing**: Places the pulse into a FIFO execution queue.
  /// 4. **Sequential Processing**: A worker drains the queue one-by-one,
  ///    ensuring atomic execution within the cell's perimeter.
  ///    If [serializedCompletion] is `true` (the default), the returned
  ///    [Future] completes after this pulse has been processed. If `false`,
  ///    it completes once the pulse is queued.
  ///
  /// ### Design Note: Result Propagation
  /// The [Future] returned by this method handles **lifecycle synchronization**
  /// (ensuring the pulse has been accepted into the queue) rather than
  /// **result retrieval**.
  /// Because a [Receptor] is an internal component of a [Cell] within a
  /// reactive network, the transformed result is automatically propagated
  /// to the cell's [Synapses] for broadcast. To capture the result, attach
  /// an observer, bind a downstream cell, or use the [hook] parameter.
  ///
  /// ### Non‑obvious:
  /// - **Lock Acquisition**: The method respects the host cell's
  ///   synchronization lock; if the cell is busy with a transaction, the
  ///   async worker will wait until the lock is released.
  /// - **Serialized vs fire-and-forget**: With [serializedCompletion] `true`,
  ///   `await call(...)` waits until this pulse has been processed. With
  ///   `false`, it only waits for the queue entry.
  /// - **Testing Hook**: The [hook] callback is invoked *immediately* after
  ///   transformation but *before* the pulse is passed to [Synapses].
  /// - **Error Handling**: Exceptions within the transformation pipeline are
  ///   captured and logged; the background worker continues to the next
  ///   pulse in the queue to prevent graph deadlocks.
  ///
  /// ### Parameters:
  /// - [incoming]: The data signal to be processed.
  /// - [serializedCompletion]: If `true`, the internal worker waits for
  ///   downstream propagation to finish before processing the next pulse
  ///   in the queue.
  /// - [hook]: **Testing Hook.** An optional callback invoked after
  ///   transformation. It provides access to the original `input` pulse
  ///   and the resulting `result` pulse (which may be `null` if filtered).
  ///
  /// ### Returns:
  /// A [Future] that completes once the pulse has been processed when
  /// [serializedCompletion] is `true`, or once it has been queued otherwise.
  ///
  /// ### See Also:
  /// - [Receptor.async]: The standard way to obtain this handle.
  /// - [Cell.txApply]: For wrapping multiple async updates in a transaction.
  Future<void> call(Pulse incoming, {bool serializedCompletion = true, void Function({Pulse? result, required Pulse input})? hook}) async {

    if (incoming is Shell) {
      incoming.scrutinize(_receptor, null, {#serializedCompletion: serializedCompletion});
      return;
    }

    var pulse = incoming as PulseBase;
    final cell = _receptor.cell;

    if (await pulse._checker.async.add(cell) == false) {
      return;
    }

    if (serializedCompletion == false || hook != null) {
      final user = {
        if (hook != null) #hook: hook,
        if (serializedCompletion) #serializedCompletion: serializedCompletion,
      };
      pulse = _Pulse(parent: pulse, user: user);
    }

    await _queue.add(pulse);

    Future<void> drain() => _unawaitedLock.synchronized(() async {
      PulseBase? out;

      while (await _queue.isNotEmpty) {
        final p = await _queue.removeFirst();

        bool wait = true;
        Function? hook;
        final user = p._user;
        if (user != null) {
          if (user.containsKey(#serializedCompletion)) {
            wait = false;
          }
          if (user.containsKey(#hook)) {
            hook = user[#hook] as Function?;
          }
        }

        final lock = cell._nucleus.lock;
        if (lock != null) {
          out = await lock.synchronized(() async {
            final result = _receptor._onPulseReceived(p);
            return result;
          });
        } else {
          final result = _receptor._onPulseReceived(p);
          out = result;
        }

        final hookFn = hook as void Function({Pulse? result, required Pulse input})?;
        hookFn?.call(result: out, input: p);

        if (out != null) {
          final synapses = cell._nucleus.synapses;
          if (synapses != Synapses.disabled) {
            if (wait) {
              await synapses.async.call(out);
            } else {
              unawaited(synapses.async.call(out));
            }
          }
        } else {
          p._complete();
        }
      }
    });

    // StateHandle / IngressHandle document that serializedCompletion waits
    // until this pulse has been processed, not merely queued.
    if (serializedCompletion) {
      await drain();
    } else if (_unawaitedLock.canLock) {
      unawaited(drain());
    }
  }

  /// Lock for synchronizing async operations.
  ///
  /// This lock ensures that only one async worker loop is active at a time,
  /// preventing concurrent processing that could violate causal order.
  final Lock _unawaitedLock = Lock();

}