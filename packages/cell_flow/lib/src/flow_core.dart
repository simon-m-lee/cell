// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../flow.dart';

/// Synthesizes a **Composite Logic Blueprint**—a specialized instruction
/// wrapper designed for fluent orchestration and pipeline assembly.
///
/// [FlowInstruction] serves as the primary unit of transformation within
/// the Cell-Flow ecosystem. It extends the foundational [InstructionBase]
/// to provide ergonomic "Composition-First" mechanics, allowing developers
/// to build complex reactive topologies through simple operator overloading
/// and method chaining.
///
/// ### When to use
/// - **Pipeline Assembly**: When you need to define a sequence of
///   transformations (e.g., Filter -> Map -> Scan) as a single unit.
/// - **Reusable Logic**: Creating domain-specific processing blocks that
///   can be shared across different graph branches.
/// - **DSL Authoring**: Building fluent interfaces for custom reactive
///   operators where readability and composition are paramount.
///
/// ### How it works
/// 1. It wraps a standard `Instruction` closure that defines the
///    pulse-to-pulse transformation.
/// 2. It maintains an internal `_user` record, preserving configuration
///    data (Flyweight state) across the composition lifecycle.
/// 3. The [chain] and [+] operators leverage [_FlowInstructionChain] to
///    lazily aggregate multiple instructions into a serial execution lane.
/// 4. During execution, pulses flow through the composed chain, where
///    each link in the sequence refines the stimulus before passing it
///    to the next.
///
/// ### Choosing Between Composition Patterns
/// - **Use `operator +`** for **Concise Linear Flow**: Best for quick
///   assembly of filters and maps in a single line.
/// - **Use `.chain()`** for **Explicit Sequencing**: Helpful when
///   integrating external instruction instances into a local flow.
/// - **Use [InstructionBase]** for **Low-Level Receptors**: When you
///   are building a standalone nucleus and don't require fluent
///   composition capabilities.
///
/// ### Non‑obvious
/// - **Flyweight Preservation**: The `user` data passed during construction
///   is carried through the chain, ensuring that even complex pipelines
///   maintain their specialized configuration context.
/// - **Covariant Safety**: The chaining methods use `covariant` to ensure
///   that specific instruction subtypes can be mixed while maintaining
///   proper type inference for the final [_FlowInstructionChain].
/// - **Lazy Linkage**: Combining instructions doesn't execute them; it
///   builds a metadata map that the [Nucleus] later uses to optimize
///   the reactive cycle.
///
/// ### Example: Composed Sanitization
/// ```dart
/// // Define a flow that trims strings and then filters out empty ones
/// final sanitizeFlow = FlowInstruction<Cell, Pulse<String>, Pulse<String>>(
///   (pulse, {cell, user}) => Pulse(pulse.payload.trim())
/// ) + FlowInstruction(
///   (pulse, {cell, user}) => pulse.payload.isEmpty ? null : pulse
/// );
/// ```
///
/// ### Type Parameters:
/// * [C]: **The Anchor Cell.** The type of cell that hosts this instruction.
/// * [I]: **Input Pulse Type.** The stimulus type entering the instruction.
/// * [O]: **Output Pulse Type.** The evolved stimulus type exiting the instruction.
///
/// ### See Also:
/// * [_FlowInstructionChain]: The internal implementation for serial composition.
/// * [InstructionBase]: The foundational interface for reactive logic.
/// * [Flow]: The orchestrator that materializes these instructions into live cells.
abstract interface class FlowInstruction<C extends Cell, I extends Pulse, O extends Pulse> implements Instruction<C,I,O> {

/*
  const factory FlowInstruction(
      O? Function(I pulse, {C? cell, dynamic user}) instruction, {dynamic user}) = _FlowInstruction<C,I,O>;

  const factory FlowInstruction.future(
      O? Function(I pulse, {C? cell, dynamic user,
      void Function({required Pulse? result, required dynamic token})? future,
      dynamic token
      }) instruction, {dynamic user}) = _FlowInstruction<C,I,O>.future;
*/

  dynamic get user;

  FlowHandle<I> toHandle({Cell? source, TestCell testRule = TestCell.allowAll, Synapses synapses = Synapses.enabled});

  @override
  FlowInstruction<C,I,O> operator +(covariant FlowInstruction other);

}

/*
class _FlowInstruction<C extends Cell, I extends Pulse, O extends Pulse> extends FlowInstructionBase<C,I,O> {

  const _FlowInstruction(super.instruction, {super.user}) : super();

  const _FlowInstruction.future(super.future, {dynamic user})
      : super.future();

  @override
  FlowInstruction<C,I,O> operator +(covariant FlowInstruction other) {
    return _FlowInstructionChain<C,I,O>([this, other]);
  }

}
*/

class _FlowInstructionChain<C extends Cell, I extends Pulse, O extends Pulse> extends InstructionChain<C,I,O> with FlowInstructionMixin<C,I,O> implements FlowInstruction<C,I,O> {

  final dynamic _user;

  const _FlowInstructionChain(super.instructions, {super.user,
    super.strategy}) : _user = user, super();

  @override
  get user => _user;

}

abstract class FlowInstructionBase<C extends Cell, I extends Pulse, O extends Pulse> extends InstructionBase<C,I,O> with FlowInstructionMixin<C,I,O> implements FlowInstruction<C,I,O> {

  final dynamic _user;

  const FlowInstructionBase(super.instruction, {super.user}) : _user = user, super();

  const FlowInstructionBase.future(super.future, {super.user})
      : _user = user, super.future();

  @override
  get user => _user;

}

mixin FlowInstructionMixin<C extends Cell, I extends Pulse, O extends Pulse> on Instruction<C,I,O> {

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
      return await receptor.async.call(pulse as PulseBase<I>, serializedCompletion: serializedCompletion);
    }

    return (cell: cell, emit: emit, emitAsync: emitAsync, ingest: ingest);

  }

  @override
  FlowInstruction<C,I,O> operator +(covariant FlowInstruction other) {
    return _FlowInstructionChain<C,I,O>([this, other]);
  }

}

typedef FlowHandle<I> = ({

  /// The source node ("cell") that anchors this entry point to the graph.
  Cell cell,

  /// Emits a raw stimulus into the reactive graph at **Native Speed**.
  ///
  /// This is the most common way to bridge imperative code (like UI events)
  /// into the reactive fabric. The handle automatically wraps the [input]
  /// in a [Pulse] and initiates the **Ingress Phase**.
  ///
  /// Returns `true` if the signal successfully passed the **Integrity Gate**.
  bool Function(I input) emit,

  /// Asynchronously emits a stimulus, ensuring **Serialized Transformation**
  /// through the node's **Conactive Lock**.
  ///
  /// Use this when you need to ensure that the update respects the system's
  /// atomic boundaries, preventing race conditions in high-concurrency scenes.
  Future<bool> Function(I input) emitAsync,

  /// The **Primary Ingress Handle** for direct **Signal Orchestration**.
  ///
  /// Unlike [emit], which takes raw data, [ingest] accepts a fully-formed
  /// [Pulse]. Use this when you need to provide specific **Provenance**
  /// (like a custom `justification` or `traceId`).
  Future<void> Function(Pulse<I> pulse, {bool serializedCompletion}) ingest

});
