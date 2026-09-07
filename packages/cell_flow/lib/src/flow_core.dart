// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell_flow.dart';

/// Synthesizes a **Composite Logic Blueprint**—a specialized instruction
/// wrapper designed for fluent orchestration and pipeline assembly.
///
/// [FlowInstruction] serves as the primary unit of transformation within
/// the Cell-Flow ecosystem. It extends the foundational [Instruction]
/// interface to provide ergonomic "Composition-First" mechanics, allowing
/// developers to build complex reactive topologies through simple operator
/// overloading and method chaining.
///
/// Unlike a [Cell], which is a live, stateful node in a graph, a
/// `FlowInstruction` is a stateless description of how a pulse should be
/// evolved, filtered, or routed.
///
/// ### When to use
/// - **Pipeline Assembly**: Defining a sequence of transformations
///   (e.g., Filter -> Map -> Scan) as a single unit.
/// - **Reusable Logic**: Creating domain-specific processing blocks that
///   can be shared across different graph branches without being bound to a source.
/// - **DSL Authoring**: Building fluent interfaces for custom reactive
///   operators where readability and composition are paramount.
///
/// ### Core Mechanics
/// 1. **Stateless Logic**: Describes the *evolution* of a pulse without
///    holding the pulse data itself.
/// 2. **Composition**: Instructions are chainable using the `+` operator.
///    `MapValue(...) + Filter(...)` creates a new instruction link that
///    applies both transformations serially.
/// 3. **Materialization**: To activate an instruction, it must be bound to
///    a source cell using [toHandle]. This materializes the blueprint into
///    a live [FlowHandle].
/// 4. **Flyweight Receptors**: Internally, these instructions are compiled
///    into highly efficient [Receptor] objects to minimize memory overhead.
///
/// ### Non‑obvious
/// - **Flyweight Preservation**: Configuration metadata (via [user]) is
///   carried through the chain, ensuring pipelines maintain context.
/// - **Lazy Linkage**: Combining instructions builds a metadata map;
///   execution is deferred until a pulse enters the materialized graph.
/// - **Covariant Safety**: The `+` operator ensures specific instruction
///   subtypes can be mixed while maintaining proper type inference.
///
/// ### Type Parameters
/// * [C]: **Anchor Cell Type.** The type of cell hosting the instruction.
/// * [I]: **Input Pulse Type.** The stimulus type entering the gate.
/// * [O]: **Output Pulse Type.** The evolved stimulus type exiting the gate.
///
/// ### Example: Reusable Logic Gate
/// ```dart
/// // Define a reusable validation gate
/// const validateEmail = FlowInstruction<Cell, Pulse<String>, Pulse<String>>(
///   (pulse, {cell, user}) => pulse.payload.contains('@') ? pulse : null
/// );
///
/// // Apply the blueprint to different live sources
/// final loginHandle = validateEmail.toHandle(source: loginField);
/// final signupHandle = validateEmail.toHandle(source: signupField);
/// ```
///
/// ### See Also
/// * [FlowHandle]: The live instance of an instruction bound to a source.
/// * [FlowInstructionBase]: The standard base implementation for custom logic.
/// * [Instruction]: The underlying core interface from `package:cell`.
/// {@category ICU Alarm Pipeline}
/// {@category Pharmacy Dispense}
abstract interface class FlowInstruction<C extends Cell, I extends Pulse, O extends Pulse> implements Instruction<C,I,O> {

  /// Synthesizes a synchronous **Logic Gate**—the primary mechanism for
  /// defining pulse evolution within the reactive topography.
  ///
  /// This factory creates a stateless blueprint that describes how an
  /// incoming stimulus [I] should be transformed or filtered before
  /// reaching the next node in the graph.
  ///
  /// ### How it works
  /// 1. **Stimulus Reception**: The [instruction] closure is invoked every
  ///    time a pulse enters this gate.
  /// 2. **Evolution**: The closure receives the current [pulse], the
  ///    anchor [cell], and any associated [user] metadata.
  /// 3. **Propagation**:
  ///    - If the closure returns an evolved pulse [O], it is propagated
  ///      downstream.
  ///    - If the closure returns `null`, the pulse is dropped, effectively
  ///      performing a **Filter** operation.
  ///
  /// ### Parameters
  /// - [instruction]: The synchronous transformation logic. It defines the
  ///   behavior of the pulse as it traverses the gate.
  /// - [user]: Optional flyweight metadata for debugging, tracing, or
  ///   auditing. This object is preserved across composition boundaries.
  ///
  /// ### Example: A Simple Filter-Map Gate
  /// ```dart
  /// final upperCaseValid = FlowInstruction<Cell, Pulse<String>, Pulse<String>>(
  ///   (pulse, {cell, user}) {
  ///     // Filter: Drop empty strings
  ///     if (pulse.payload.isEmpty) return null;
  ///
  ///     // Map: Transform to uppercase
  ///     return pulse.copy(payload: pulse.payload.toUpperCase());
  ///   },
  ///   user: 'Uppercase-Validator'
  /// );
  /// ```
  const factory FlowInstruction(
      O? Function(I pulse, {C? cell, dynamic user}) instruction, {dynamic user}) = _FlowInstruction<C,I,O>;

  /// Creates an asynchronous [FlowInstruction].
  ///
  /// The [instruction] closure is used for operations that involve [Future]s or
  /// deferred execution. It receives a `future` callback to register async results
  /// and a `token` to track specific stimuli.
  const factory FlowInstruction.future(
      O? Function(I pulse, {C? cell, dynamic user,
      void Function({required Pulse? result, required dynamic token})? future,
      dynamic token
      }) instruction, {dynamic user}) = _FlowInstruction<C,I,O>.future;

  /// Creates a composite instruction by chaining multiple [instructions] serially.
  ///
  /// This is the internal constructor used by the `+` operator.
  const factory FlowInstruction.chain(Iterable<Instruction> instructions, {dynamic user,
    O? Function(I pulse, {C? cell, dynamic user})? strategy}) = _FlowInstructionChain<C,I,O>;

  /// Custom metadata associated with this instruction for auditing, logging, or tracing.
  dynamic get user;

  /// Materializes this instruction into a live [FlowHandle] bound to a [source] cell.
  ///
  /// * [source]: The input cell providing pulses to this instruction.
  /// * [testRule]: An integrity gate (e.g., [TestCell.readOnly]) applied to the output cell.
  /// * [synapses]: The propagation strategy (e.g., [Synapses.enabled], [Synapses.disabled]).
  FlowHandle<I> toHandle({Cell? source, TestCell testRule = TestCell.allowAll, Synapses synapses = Synapses.enabled});

  /// Chains this instruction with [other] to create a new serial composition.
  ///
  /// The resulting instruction will pass pulses through this one first, then through [other].
  @override
  FlowInstruction<C,I,O> operator +(covariant FlowInstruction other);

}

class _FlowInstruction<C extends Cell, I extends Pulse, O extends Pulse> extends FlowInstructionBase<C,I,O> {

  const _FlowInstruction(super.instruction, {super.user}) : super();

  const _FlowInstruction.future(super.future, {dynamic user})
      : super.future();

  @override
  FlowInstruction<C,I,O> operator +(covariant FlowInstruction other) {
    return _FlowInstructionChain<C,I,O>([this, other]);
  }

}

class _FlowInstructionChain<C extends Cell, I extends Pulse, O extends Pulse> extends InstructionChain<C,I,O> with FlowInstructionMixin<C,I,O> implements FlowInstruction<C,I,O> {

  final dynamic _user;

  const _FlowInstructionChain(super.instructions, {super.user,
    super.strategy}) : _user = user, super();

  @override
  get user => _user;

}

/// The foundational implementation for creating custom reactive logic gates
/// within the **Mitosis** topography.
///
/// [FlowInstructionBase] provides the concrete machinery required to bridge
/// low-level [InstructionBase] logic with the fluent, composable API of the
/// Cell-Flow ecosystem. It acts as a stateless blueprint for pulse evolution,
/// allowing developers to encapsulate transformation logic that remains
/// independent of specific source cells until materialized.
///
/// ### When to use
/// - **Custom Operators**: When building new reactive operators (e.g., `distinct`,
///   `debounce`) that require standard [FlowInstruction] composition capabilities.
/// - **Subclassing**: When you need to maintain specialized internal state
///   or metadata within a logic gate.
/// - **Encapsulation**: To hide complex transformation logic behind a reusable,
///   type-safe class structure.
///
/// ### Core Mechanics
/// 1. **Stateless Logic**: Like all instructions, this class describes *how*
///    to transform data without holding the data itself.
/// 2. **Metadata Integration**: It explicitly manages the [_user] property,
///    ensuring that flyweight configuration data is preserved during
///    composition and auditing.
/// 3. **Mixin Orchestration**: By utilizing [FlowInstructionMixin], it
///    automatically gains the ability to materialize into [FlowHandle]s and
///    participate in `+` operator chaining.
///
/// ### Type Parameters
/// * [C]: **Anchor Cell Type.** The type of cell hosting the instruction (typically [Cell]).
/// * [I]: **Input Pulse Type.** The stimulus type entering the gate.
/// * [O]: **Output Pulse Type.** The evolved stimulus type exiting the gate.
///
/// ### See Also
/// * [FlowInstruction]: The public interface for logic gates.
/// * [InstructionBase]: The core framework implementation from `package:cell`.
abstract class FlowInstructionBase<C extends Cell, I extends Pulse, O extends Pulse>
    extends InstructionBase<C,I,O>
    with FlowInstructionMixin<C,I,O>
    implements FlowInstruction<C,I,O> {

  final dynamic _user;

  /// Synthesizes a **Logic Gate Blueprint**—the foundational mechanism for
  /// establishing synchronous pulse evolution within the reactive topography.
  ///
  /// This constructor initializes the concrete machinery required to transform
  /// a raw [instruction] closure into a composable, stateless unit of logic.
  ///
  /// ### Parameters:
  /// - [instruction]: The **Evolution Orchestrator**—a synchronous closure
  ///   defining how an incoming stimulus [I] is transformed or filtered.
  /// - [user]: Optional flyweight metadata preserved across the topography
  ///   for **Topographical Auditing** and provenance tracing.
  ///
  /// ### Returns:
  /// A new [FlowInstructionBase] instance representing the stateless logic gate.
  const FlowInstructionBase(super.instruction, {super.user}) : _user = user, super();

  /// Synthesizes an **Asynchronous Logic Gate Blueprint**—the foundational
  /// mechanism for establishing deferred pulse evolution.
  ///
  /// This constructor initializes the concrete machinery required to transform
  /// a multi-stage [instruction] closure into a composable, stateless unit
  /// of async logic. It is the primary building block for temporal operators
  /// (like `Delay` or `Debounce`) and external resource bridges.
  ///
  /// ### How it works
  /// 1. **Stimulus Interception**: The orchestrator intercepts an incoming
  ///    pulse and immediately provides a `future` callback.
  /// 2. **Deferred Materialization**: The logic within the [instruction]
  ///    triggers a background evolution (e.g., a Timer or API call).
  /// 3. **Pulse Materialization**: Once the background work completes, the
  ///    logic invokes the callback to propagate the **Evolved Pulse**
  ///    into the downstream topography.
  ///
  /// ### Parameters:
  /// - [instruction]: The **Async Evolution Orchestrator**—a closure
  ///   defining how an incoming stimulus [I] is transformed over time.
  /// - [user]: Optional flyweight metadata preserved across the topography
  ///   for **Topographical Auditing** and provenance tracing.
  ///
  /// ### Returns:
  /// A new [FlowInstructionBase] instance representing the asynchronous gate.
  const FlowInstructionBase.future(super.future, {super.user})
      : _user = user, super.future();

  @override
  get user => _user;

}

/// Synthesizes a **Materialization Engine**—a specialized mixin designed to
/// bridge stateless instructions with live reactive topographies.
///
/// [FlowInstructionMixin] provides the essential machinery required to
/// transform a [FlowInstruction] blueprint into a functional [FlowHandle].
/// It orchestrates the creation of the underlying [Nucleus] and [Receptor],
/// anchoring the instruction's logic to a concrete [Cell] within the graph.
///
/// ### When to use
/// - **Custom Orchestrators**: When defining new instruction subtypes that
///   must support fluent composition via the `+` operator.
/// - **Materialization Logic**: When the standard behavior for binding an
///   instruction to a source cell needs to be inherited by a specialized gate.
///
/// ### How it works
/// 1. **Receptor Synthesis**: The mixin wraps the instruction logic in a
///    high-efficiency [Receptor].
/// 2. **Nucleus Anchoring**: It initializes a [Nucleus] to manage the
///    lifecycle, synapses, and integrity rules of the new node.
/// 3. **Handle Generation**: It produces a [FlowHandle] record, exposing
///    methods for both synchronous and asynchronous stimulus ingress.
///
/// ### Non‑obvious
/// - **Composition Logic**: This mixin provides the concrete implementation
///   for the `+` operator, enabling the serial chaining of instructions
///   into a single evolution pipeline.
/// - **Lock Integration**: It automatically detects if the underlying
///   nucleus requires a **Conactive Lock** for serialized execution.
///
/// ### See Also
/// * [FlowInstruction]: The abstract blueprint for reactive logic.
/// * [FlowHandle]: The materialized interface for topographical ingress.
mixin FlowInstructionMixin<C extends Cell, I extends Pulse, O extends Pulse> on Instruction<C,I,O> {

  /// Materializes the blueprint into a live **Topographical Gateway**.
  ///
  /// This method performs the transition from a stateless instruction to
  /// a live graph node, returning a handle for stimulus ingress.
  ///
  /// ### Parameters:
  /// - [source]: The **Upstream Anchor** cell providing pulses to this gate.
  /// - [testRule]: An **Integrity Gate** defining read/write permissions.
  /// - [synapses]: The **Propagation Strategy** for downstream evolution.
  ///
  /// ### Returns:
  /// A [FlowHandle] providing entry points into the reactive topography.
  FlowHandle toHandle({
    Cell? source,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
  }) {
    final receptor = Receptor.instruction(this);
    final nucleus = Nucleus(bind: source, testRule: testRule, synapses: synapses, receptor: receptor);
    final cell = Cell.fromNucleus(nucleus);

    bool emit(dynamic input) => receptor.call(Pulse(input, source: cell)) != null;

    Future<bool> emitAsync(dynamic input)  async {
      final lock = nucleus.lock;
      if (lock != null) {
        return lock.synchronized(() => emit(input)).then((value) => value);
      }
      return Future<bool>(() => emit(input)).then((value) => value);
    }

    Future<void> ingest(Pulse pulse, {bool serializedCompletion = true}) async {
      return await receptor.async.call(pulse as PulseBase, serializedCompletion: serializedCompletion);
    }

    return (cell: cell, emit: emit, emitAsync: emitAsync, ingest: ingest);
  }

  @override
  FlowInstruction<C,I,O> operator +(covariant FlowInstruction other) {
    return _FlowInstructionChain<C,I,O>([this, other]);
  }
}

/// A specialized record representing a **Topographical Ingress Handle**.
///
/// [FlowHandle] is the materialized manifestation of an instruction. It
/// serves as the primary interface for external systems to inject
/// stimuli into the reactive graph, providing multiple tiers of
/// execution speed and provenance control.
///
/// ### Fields:
///
/// - **cell**: The **Anchor Node** within the topography. This cell
///   represents the live location of the instruction and can be used
///   to observe the evolved output or bind further instructions.
///
/// - **emit**: Performs **Native Speed Ingress**. This method wraps a
///   raw payload into a pulse and initiates immediate evolution. It is
///   the standard entry point for UI events and imperative triggers.
///
/// - **emitAsync**: Performs **Serialized Ingress**. It ensures the
///   stimulus respects the topography's atomic boundaries by routing
///   evolution through the node's **Conactive Lock**, preventing
///   race conditions during concurrent updates.
///
/// - **ingest**: Performs **Direct Signal Orchestration**. Unlike `emit`,
///   this method accepts a fully-formed [Pulse], allowing for the
///   preservation of complex **Provenance** data, such as trace IDs,
///   priorities, and justification metadata.
typedef FlowHandle<I> = ({

  /// The **Anchor Node** within the topography.
  ///
  /// This cell represents the live location of the materialized instruction
  /// and serves as the observable point for evolved output. It acts as the
  /// bridge between the stateless blueprint and the stateful reactive graph.
  ///
  /// ### When to use
  /// - **Downstream Binding**: Connecting subsequent instructions to the
  ///   output of this gate to form a pipeline.
  /// - **Pulse Observation**: Monitoring the current result of the evolution
  ///   logic through standard cell listeners.
  /// - **Topographical Queries**: Accessing the cell's metadata or
  ///   checking its status within the reactive engine.
  ///
  /// ### How it works
  /// 1. **Materialization**: The cell is generated during the [toHandle]
  ///    call, encapsulating a new [Nucleus] and [Receptor].
  /// 2. **Signal Origin**: Every pulse evolved by the handle's `emit` or
  ///    `ingest` methods originates from this specific node.
  /// 3. **Synaptic Connectivity**: Maintains the link to the upstream
  ///    source and manages propagation to downstream synapses.
  ///
  /// ### See Also
  /// * [Cell]: The foundational reactive primitive.
  /// * [FlowInstructionMixin.toHandle]: The materialization process that
  ///   creates this anchor.
  Cell cell,

  /// Performs **Native Speed Ingress**—the primary mechanism for injecting
  /// raw stimuli into the reactive topography for immediate evolution.
  ///
  /// This method wraps a raw payload [input] into a pulse and initiates
  /// synchronous propagation through the anchored gate. It is optimized
  /// for high-frequency updates where the overhead of asynchronous
  /// serialization is not required.
  ///
  /// ### When to use
  /// - **UI Interaction**: Injecting stimuli from button clicks, text
  ///   input changes, or gesture offsets.
  /// - **High-Frequency Ingress**: Scenarios requiring low-latency
  ///   propagation where pulses arrive in rapid succession.
  /// - **Imperative Bridging**: Connecting standard imperative logic or
  ///   third-party callbacks to the reactive graph.
  ///
  /// ### How it works
  /// 1. **Pulse Synthesis**: The raw [input] is automatically encapsulated
  ///    into a `Pulse` object, inheriting the source metadata of the
  ///    [cell].
  /// 2. **Topographical Ingress**: The stimulus is delivered to the
  ///    anchored node's [Receptor] for immediate processing.
  /// 3. **Synchronous Evolution**: The evolution logic defined in the
  ///    instruction blueprint is executed within the current call stack.
  ///
  /// ### Returns
  /// `true` if the stimulus successfully traverses the node's
  /// **Integrity Gate** (e.g., passing access control and type checks).
  bool Function(I input) emit,

  /// Performs **Serialized Ingress**—a specialized mechanism for injecting
  /// stimuli that require atomic evolution boundaries.
  ///
  /// This method ensures that the stimulus [input] respects the topography's
  /// concurrency constraints by routing its evolution through the node's
  /// **Conactive Lock**. It is designed to prevent race conditions in
  /// multi-actor or asynchronous environments.
  ///
  /// ### When to use
  /// - **State Integrity**: When multiple concurrent stimuli might lead to
  ///   inconsistent materializations if processed simultaneously.
  /// - **Atomic Updates**: Scenarios where a single evolution must complete
  ///   before the next stimulus is admitted to the gate.
  /// - **External Coordination**: Bridging asynchronous events that are
  ///   emitted from background isolates or concurrent logic loops.
  ///
  /// ### How it works
  /// 1. **Lock Acquisition**: The orchestrator attempts to acquire the
  ///    **Conactive Lock** associated with the anchored [cell].
  /// 2. **Serialized Execution**: Once the lock is secured, the pulse is
  ///    materialized and evolved using the [emit] logic.
  /// 3. **Future Resolution**: The returned [Future] completes only after
  ///     the synchronous evolution has been gated and processed.
  ///
  /// ### Returns
  /// A [Future] resolving to `true` if the stimulus successfully traverses
  /// the **Integrity Gate** and completes its evolution cycle.
  Future<bool> Function(I input) emitAsync,

  /// Performs **Forensic Signal Orchestration**—the specialized ingress tier
  /// designed for direct pulse injection with full provenance control.
  ///
  /// Unlike the `emit` family, [ingest] accepts a pre-constructed [Pulse]
  /// rather than a raw payload. This allows external orchestrators to
  /// preserve complex metadata, trace IDs, and priority levels as the
  /// stimulus enters the topography.
  ///
  /// ### When to use
  /// - **Topographical Relaying**: Passing pulses from one autonomous
  ///   graph to another while maintaining their original **Provenance**.
  /// - **Forensic Auditing**: Injecting stimuli with specific trace IDs or
  ///   justification metadata for logging and debugging.
  /// - **Priority Signaling**: Manually defining the evolution priority
  ///   to influence how the reactive engine schedules the pulse.
  ///
  /// ### How it works
  /// 1. **Pulse Validation**: The pre-formed [pulse] is checked against the
  ///    anchored node's type integrity rules [I].
  /// 2. **Bypassing Synthesis**: The orchestrator skips internal pulse
  ///    creation, delivering the stimulus directly to the [Receptor].
  /// 3. **Lifecycle Synchronization**: If [serializedCompletion] is enabled,
  ///    the resulting [Future] awaits the resolution of the node's
  ///    **Conactive Lock**.
  ///
  /// ### Non‑obvious
  /// - **Source Authority**: While you can define the pulse source, the
  ///   topography may append evolution steps to the metadata to track
  ///   the signal's path through the gate.
  /// - **Concurrency Control**: Setting [serializedCompletion] to `false`
  ///   allows the call to return immediately, even if the evolution is
  ///   still queued behind a busy lock.
  ///
  /// ### Parameters:
  /// - [pulse]: The **Stimulus Pulse** containing the payload and provenance.
  /// - [serializedCompletion]: If `true`, the future resolves only after
  ///   the evolution logic has fully settled.
  ///
  /// ### Returns:
  /// A [Future] that completes once the signal has been successfully admitted
  /// to the topography.
  ///
  /// ### See Also
  /// * [Pulse]: The container for payload and topographical metadata.
  /// * [emit]: For standard, low-overhead payload injection.
  Future<void> Function(Pulse<I> pulse, {bool serializedCompletion}) ingest

});