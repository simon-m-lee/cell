// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of 'memory_cell.dart';

/// The memory-typed deputy of a [MemoryCell].
///
/// Shares the principal's runtime, store, and codec through the principal
/// walk ([MemoryCellNucleus.runtime] / [slots]). Unlike a `ValueCell`
/// deputy, the nucleus has `bind: null`: a pulse delivered to a memory
/// receptor is an adopt, and linking the deputy to the principal would
/// re-deliver every [MemoryPulse] into `apply` — the echo guard would miss
/// it because the source is the principal. The deputy's own registry
/// therefore only hears actions run *through* the deputy; the dispatcher
/// mirrors those pulses to the principal's registry instead.
final class _MemoryCellDeputy<T> extends MemoryCell<T> with Deputy<MemoryCell<T>> {
  _MemoryCellDeputy(
    MemoryCell<T> bind, {
    DeputyContext context = DeputyContext.system,
    TestCell testRule = TestCell.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  })  : _principal = bind,
        super._(MemoryCellNucleus.evolve(
          principal: bind._nucleus,
          // No bind: `CellBase.fromNucleus` must not link the deputy to the
          // principal's synapses (see the class doc).
          bind: null,
          // The deputy's own receptor clone, unactivated: `fromNucleus`
          // activates it on the deputy. Never reuse the principal's
          // activated receptor.
          receptor: bind._nucleus.receptor.clone,
          testRule: identical(testRule, TestCell.allowAll)
              ? null
              : TestCell<Cell>.chain([bind._nucleus.testRule, testRule]),
          context: identical(context, DeputyContext.system) ? null : context,
          synapses: synapses,
          ephemeralPolicy: ephemeralPolicy,
        ));

  final MemoryCell<T> _principal;

  /// The `Deputy` mixin's `unmodifiable` casts `_nucleus.bind` — null here —
  /// so it resolves the principal's cached view instead.
  @override
  MemoryCell<T> get unmodifiable => _principal.unmodifiable;

  /// The principal's manifest plus this deputy's own `apply` and tear-offs.
  /// Membership only sets the vetted bit; `CellBase.apply` always runs
  /// `validate.action`, and the deputy's chained rule is what narrows.
  @override
  Iterable<Function> get modifiable => {
        ..._principal.modifiable,
        apply<dynamic>,
        _load,
        _save,
        _unload,
        _attach,
        _detach,
        _close,
        _remove,
      };
}

/// Drops every pulse that is not a [MemoryCommand].
///
/// `TestCell.readOnly.call` returns `true` for pulses, so it does not stop
/// an adopt on its own; this rule is the adopt half of the unmodifiable
/// view's gate.
final TestCell<Cell> _dropAdopts = TestCell<Cell>(
  (object, {host, arguments, user}) {
    if (object is MemoryCommand) return true;
    return object is! Pulse;
  },
);

/// The read-only view of a [MemoryCell].
///
/// A [MemoryCell] deputy sharing the principal's runtime, with `validate`
/// chained to reject every function action and every adopt pulse. The
/// public durability methods are sealed with [UnsupportedError] *before*
/// `apply`, exactly the way `UnmodifiableValueCell` seals `value`:
/// `TestCell.readOnly` alone cannot stop a method that forgot to call
/// `apply`.
final class UnmodifiableMemoryCell<T> extends _MemoryCellDeputy<T> {
  UnmodifiableMemoryCell._(super.bind) : super(testRule: TestCell.readOnly);

  /// The principal's rule, read-only action gating, and adopt dropping.
  @override
  late final TestCell validate = TestCell<Cell>.chain([
    _principal._nucleus.testRule,
    TestCell.readOnly,
    _dropAdopts,
  ]);

  @override
  Future<T?> load() => throw UnsupportedError(
      'MemoryCell: cannot call load() on the read-only view. '
      'Use the principal cell instead.');

  @override
  Future<MemoryEnvelope?> save() => throw UnsupportedError(
      'MemoryCell: cannot call save() on the read-only view. '
      'Use the principal cell instead.');

  @override
  Future<void> unload() => throw UnsupportedError(
      'MemoryCell: cannot call unload() on the read-only view. '
      'Use the principal cell instead.');

  @override
  Future<void> attach(Cell upstream, {T? Function(Pulse pulse)? project}) =>
      throw UnsupportedError(
          'MemoryCell: cannot call attach() on the read-only view. '
          'Use the principal cell instead.');

  @override
  Future<void> detach() => throw UnsupportedError(
      'MemoryCell: cannot call detach() on the read-only view. '
      'Use the principal cell instead.');

  @override
  Future<void> close() => throw UnsupportedError(
      'MemoryCell: cannot call close() on the read-only view. '
      'Use the principal cell instead.');

  @override
  Future<void> remove({bool detach = true}) => throw UnsupportedError(
      'MemoryCell: cannot call remove() on the read-only view. '
      'Use the principal cell instead.');

  @override
  MemoryCell<T> get unmodifiable => this;

  /// Returns itself for every parameter set: the inherited [MemoryCell.deputy]
  /// would build a mutable escape hatch around the read-only view.
  @override
  FutureOr<MemoryCell<T>> deputy({
    EphemeralPolicy? ephemeralPolicy,
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
  }) =>
      this;
}
