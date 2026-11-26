// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of 'memory_cell.dart';

/// The immutable per-open configuration of a [MemoryCell], plus the single
/// mutable holder.
///
/// Dart records are immutable and [NucleusBase.record] is `final`, so
/// mutable state cannot be a record field. [MemoryCellSlots] mirrors
/// [ValueNucleus]'s `others: (value: Box<V>())` split: the immutable
/// constructor arguments stay record fields, while the one [MemoryRuntime]
/// they point at holds everything that moves.
typedef MemoryCellSlots<T> = ({
  String memoryId,
  MemoryStore store,
  MemoryCodec<T> codec,
  MemoryWritePolicy policy,
  MemoryScheduler scheduler,
  bool ownsStore,
  MemoryRuntime<T> runtime,
});

/// The one mutable holder of a [MemoryCell]'s durability state.
///
/// One instance per [MemoryCell.open]. The chains are created here, in the
/// constructor — a getter that did `..` would build a new queue on every
/// read and serialize nothing. A [MemoryCellNucleus.clone] or
/// [MemoryCellNucleus.evolve] has no local runtime: it walks the principal
/// chain to this holder, so two opens never share one and a deputy always
/// does.
class MemoryRuntime<T> {
  /// Creates the holder and seeds [value] with the cell's initial value.
  MemoryRuntime(T? initial) : value = initial;

  /// The committed in-process value.
  T? value;

  /// The revision of the last successful store write.
  int storedRevision = 0;

  /// The encoded payload last known to be stored.
  Object? storedPayload;

  /// The last generation known to be stored.
  String? generation;

  /// Minted for a create that has not landed yet.
  String? pendingGeneration;

  /// Whether a load has finished (hit or miss).
  bool loaded = false;

  /// Whether a newer in-memory value is still unwritten.
  bool dirty = false;

  /// Whether the cell has been closed by `unload` or `close`.
  bool closed = false;

  /// Latched synchronously by `unload` / `close` before either returns.
  bool closing = false;

  /// Whether `close` has asked an owned store to close.
  bool storeReleased = false;

  /// The flush error held between `_finish` and the rethrow in the turn.
  Object? flushError;

  /// The last failed write or failed ingress encoding.
  Object? lastError;

  /// Advances on every accepted commit; used to detect stale writes.
  int commitGeneration = 0;

  /// Fenced in `remove` / `unload` / `close` so a late write never lands.
  int writeEpoch = 0;

  /// The last pulse this cell emitted, for echo suppression.
  MemoryPulse<T>? lastEmitted;

  /// The current `attach` observer handle; cleared by `detach`.
  EgressHandle? observer;

  /// Token for the current `attach`; cleared by `detach`.
  Object? attachToken;

  /// Broadcast stream of write failures and ingress encoding failures.
  final StreamController<Object> errors = StreamController<Object>.broadcast();

  /// Serializes turns (load, save, unload, attach, detach, close, remove).
  Future<void> turnChain = Future<void>.value();

  /// Serializes store writes.
  Future<void> writeChain = Future<void>.value();

  /// Serializes asynchronous ingress validations in arrival order.
  Future<void> ingressChain = Future<void>.value();
}

/// The [Nucleus] blueprint of a [MemoryCell].
///
/// Constructed like [ValueNucleus]: the immutable slots live in the `others`
/// overflow slot and are inherited by walking [principal]. [clone] and
/// [evolve] allocate no runtime — [runtime] resolves through the principal
/// chain, which is what Phase 4's deputy needs.
class MemoryCellNucleus<T> extends NucleusBase {
  MemoryCellNucleus._(super.record) : super.fromRecord();

  /// Creates the blueprint of one opened memory cell.
  ///
  /// The defaults mirror what `MemoryCell` passes to `CellBase` today:
  /// [NucleusBase]'s `forceLock: true`, `Context.system`, `TestCell.allowAll`,
  /// no [bind], and no [EphemeralPolicy]. Do not change them here.
  MemoryCellNucleus({
    required MemoryCellSlots<T> slots,
    Cell? bind,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
    EphemeralPolicy? ephemeralPolicy,
    Record? user,
    bool forceLock = true,
  }) : this._((
          local: NucleusBase.mask(
            bind: bind,
            context: context,
            receptor: receptor,
            testRule: testRule,
            synapses: synapses,
            ephemeralPolicy: ephemeralPolicy,
            user: user,
            forceLock: forceLock,
            others: (slots: slots),
          ),
        ));

  /// Default-enabled records store the [Synapses.enabled] flyweight; the
  /// real set is materialized once on first access. Copied from
  /// [ValueNucleus] so repeated reads never rebuild a registry.
  @override
  late final Synapses synapses = _resolveSynapses();

  Synapses _resolveSynapses() {
    final stored =
        get<Synapses>(() => record.local.synapses, orElse: Synapses.disabled);
    if (stored != Synapses.enabled) return stored;
    return Synapses();
  }

  /// The mutable holder. Walks to [principal] when the local record has no
  /// slots — the exact [ValueNucleus.state] split, with a runtime instead of
  /// a box.
  MemoryRuntime<T> get runtime => get<MemoryRuntime<T>>(
        () => record.local.others.slots.runtime,
        fallback: () => principal!.runtime,
      );

  /// The immutable per-open configuration. Same principal walk as [runtime].
  MemoryCellSlots<T> get slots => get<MemoryCellSlots<T>>(
        () => record.local.others.slots,
        fallback: () => principal!.slots,
      );

  @override
  MemoryCellNucleus<T>? get principal =>
      super.principal as MemoryCellNucleus<T>?;

  /// A peer blueprint sharing this nucleus's runtime: new local record,
  /// cloned receptor, a real registry unless the principal is disabled, and
  /// no local `others` (a local `others` would allocate a second runtime).
  /// Follows [ValueNucleus.clone].
  @override
  MemoryCellNucleus<T> get clone {
    final handle = inheritable;
    return MemoryCellNucleus<T>._((
      local: NucleusBase.mask(
        bind: handle.bind,
        context: handle.context,
        receptor: handle.receptor.clone,
        testRule: handle.testRule,
        ephemeralPolicy: handle.ephemeralPolicy,
        synapses:
            synapses != Synapses.disabled ? Synapses() : Synapses.disabled,
        user: user,
        forceLock: lock != null,
      ),
      principal: this,
    ));
  }

  /// A derivative blueprint sharing [principal]'s runtime and slots. Same
  /// shape as [ValueNucleus.evolve] — a named constructor, not a method —
  /// and also omits `others`. `synapses` defaults to the enabled flyweight
  /// so the derivative keeps a working egress registry instead of falling
  /// through the mask to [Synapses.disabled].
  MemoryCellNucleus.evolve({
    Cell? bind,
    Context? context,
    Receptor? receptor,
    TestCell? testRule,
    Synapses? synapses,
    EphemeralPolicy? ephemeralPolicy,
    Record? user,
    MemoryCellNucleus<T>? overrideNucleus,
    required MemoryCellNucleus<T> principal,
  }) : this._((
          local: overrideNucleus?.record.local ??
              NucleusBase.mask(
                bind: bind,
                context: context,
                receptor: receptor,
                testRule: testRule,
                synapses: synapses ?? Synapses.enabled,
                user: user,
                ephemeralPolicy: ephemeralPolicy,
              ),
          principal: principal,
        ));
}
