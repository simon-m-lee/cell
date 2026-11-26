// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import 'codec.dart';
import 'envelope.dart';
import 'id.dart';
import 'memory_pulse.dart';
import 'policy.dart';
import 'scheduler.dart';
import 'store.dart';

part 'memory_cell_nucleus.dart';
part 'memory_cell_chain.dart';
part 'memory_cell_deputy.dart';

/// A [Cell] that retains its value in a [MemoryStore].
///
/// [MemoryCell] extends the framework's public `CellBase` extension seam —
/// see the README "Verified against" block: at cell 2.1.0 `implements Cell`
/// compiles but cannot receive synapse delivery because the framework reads
/// library-private members. `CellBase` receives delivery, can be `bind`-ed,
/// can be a link source through its [synapses], and joins `Cell.transaction`
/// through its receptor.
///
/// Accepted ingress (synapse delivery, a transaction commit, or an attached
/// upstream via [attach]) adopts the pulse payload as the retained value,
/// emits a [MemoryPulse] of [MemoryEvent.applied], and schedules a store
/// write per [policy]. [load] and [unload] are the public durability
/// surface. A rejected pulse emits nothing and writes nothing.
final class MemoryCell<T> extends CellBase {

  MemoryCell._(MemoryCellNucleus<T> super.nucleus)
      : _nucleus = nucleus,
        super.fromNucleus();

  /// The typed view of the cell's nucleus.
  ///
  /// `CellBase._nucleus` is private to the framework library, so this is a
  /// *shadow*, not an override: both fields point at the same nucleus, each
  /// under its own library-private name. It is initialized in the
  /// initializer list — before `CellBase.fromNucleus` runs its body — which
  /// is exactly what avoids the `late` shadow trap `cell_tissue` hit. Do not
  /// turn this into a `late` field set in a constructor body.
  final MemoryCellNucleus<T> _nucleus;

  /// Opens a memory cell.
  ///
  /// [id] is the stable memory id — the file name or document id. It is
  /// never derived from `Cell.id`, which the framework assigns per process.
  /// [loadOnOpen] defaults to `true`; pass `false` together with
  /// [MemoryWritePolicy.replay] during Causal Replay.
  ///
  /// [ownsStore] is `false` by default: [close] only closes [store] when
  /// this cell opened it (for example a single-cell [FileMemoryStore.file]).
  static Future<MemoryCell<T>> open<T>({
    required String id,
    required MemoryStore store,
    required MemoryCodec<T> codec,
    T? initial,
    Context context = Context.system,
    MemoryWritePolicy policy = const MemoryWritePolicy(),
    bool loadOnOpen = true,
    MemoryScheduler? scheduler,
    bool ownsStore = false,
  }) async {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'memory id must not be empty');
    }
    // The shared grammar, without the Windows device-name rule: `CON`
    // stays a legal Firestore id and an illegal file id.
    MemoryIdGrammar.check(id);
    // One runtime per open: two opens must never share one, and a clone or
    // deputy must always walk back to exactly this holder.
    final runtime = MemoryRuntime<T>(initial);
    final MemoryCellSlots<T> slots = (
      memoryId: id,
      store: store,
      codec: codec,
      policy: policy,
      scheduler: scheduler ?? TimerScheduler(),
      ownsStore: ownsStore,
      runtime: runtime,
    );
    // The receptor is the one-stage dispatcher chain (Fork Dispatcher, the
    // Phase 1 spike's verdict): one `Instruction.future` stage, no strategy.
    // The chain is built once, unactivated, stored on the nucleus, and
    // activated by `CellBase.fromNucleus`. Every instruction resolves its
    // host through the framework's `cell` argument — never a captured
    // runtime local — so a clone or deputy runs the action on its own
    // nucleus.
    //
    // The receptor's host type is `Cell`, not `MemoryCell<T>`: the
    // inherited `_CellDeputy` (Phase 2/3) inherits this receptor, and a
    // `MemoryCell<T>`-hosted receptor clone would fail activation there
    // (the deputy is not a `MemoryCell`). Instruction dispatch is dynamic,
    // so a real memory host still reaches the action bodies; a non-memory
    // host fails inside the framework's contained instruction boundary.
    final receptor = Receptor<Cell>.instruction(
        _memoryDispatcherChain<T>(_memoryCatalog<T>()));
    final synapses = Synapses();
    final nucleus = MemoryCellNucleus<T>(
      slots: slots,
      receptor: receptor,
      context: context,
      synapses: synapses,
    );
    final cell = MemoryCell<T>._(nucleus);
    if (loadOnOpen) {
      try {
        await cell.load();
      } catch (_) {
        // The cell never reaches the caller: release its stream so a
        // failed open does not leak listeners.
        cell._disposeAfterFailedOpen();
        rethrow;
      }
    }
    return cell;
  }

  // ── capability manifest ───────────────────────────────────────────────
  //
  // Stable tear-offs, one per action. Each tear-off only builds a
  // [MemoryCommand] and returns it — no I/O. `CellBase.apply` runs the
  // gate, invokes the tear-off, and hands the returned command to the
  // receptor chain, whose instruction does the I/O exactly once.

  late final Pulse Function({required Completer<T?> reply}) _load =
      _loadCommand;

  Pulse _loadCommand({required Completer<T?> reply}) =>
      MemoryCommand<T>(MemoryAction.load, reply: reply);

  late final Pulse Function({required Completer<MemoryEnvelope?> reply}) _save =
      _saveCommand;

  Pulse _saveCommand({required Completer<MemoryEnvelope?> reply}) =>
      MemoryCommand<T>(MemoryAction.save, reply: reply);

  late final Pulse Function({required Completer<void> reply}) _unload =
      _unloadCommand;

  Pulse _unloadCommand({required Completer<void> reply}) =>
      MemoryCommand<T>(MemoryAction.unload, reply: reply);

  late final Pulse Function({
    required Completer<void> reply,
    required Cell source,
    T? Function(Pulse pulse)? project,
  }) _attach = _attachCommand;

  Pulse _attachCommand({
    required Completer<void> reply,
    required Cell source,
    T? Function(Pulse pulse)? project,
  }) =>
      MemoryCommand<T>(
        MemoryAction.attach,
        reply: reply,
        source: source,
        project: project,
      );

  late final Pulse Function({required Completer<void> reply}) _detach =
      _detachCommand;

  Pulse _detachCommand({required Completer<void> reply}) =>
      MemoryCommand<T>(MemoryAction.detach, reply: reply);

  late final Pulse Function({required Completer<void> reply}) _close =
      _closeCommand;

  Pulse _closeCommand({required Completer<void> reply}) =>
      MemoryCommand<T>(MemoryAction.close, reply: reply);

  late final Pulse Function({required Completer<void> reply, bool detach})
      _remove = _removeCommand;

  Pulse _removeCommand({required Completer<void> reply, bool detach = true}) =>
      MemoryCommand<T>(MemoryAction.remove, reply: reply, detach: detach);

  @override
  Iterable<Function> get modifiable =>
      {apply<dynamic>, _load, _save, _unload, _attach, _detach, _close, _remove};

  /// Submits [command] through `CellBase.apply` and returns the reply
  /// channel of the public method that built it.
  ///
  /// [ApplyRejected] is the integrity gate: the tear-off never entered the
  /// instruction. It surfaces as a [StateError]; the instruction's own
  /// failures (`MemoryCorrupt`, `MemoryConflict`, `StateError`) travel on
  /// the reply completer untouched. These methods never pass `tx`, so
  /// `ApplyStaged` cannot occur.
  Future<R> _submit<R>(ApplyCommand command, Completer<R> reply, String name) {
    final outcome = apply(command);
    if (outcome is ApplyRejected) {
      return Future.error(StateError('$name rejected'));
    }
    if (outcome is Future<ApplyOutcome>) {
      return outcome.then((next) {
        if (next is ApplyRejected) throw StateError('$name rejected');
        return reply.future;
      });
    }
    return reply.future;
  }

  // ── deputies ───────────────────────────────────────────────────────────

  /// The durability action [fn] tears off, or `null` when [fn] is not one
  /// of this cell's action tear-offs (including `Cell.apply`).
  ///
  /// Tear-offs are per instance, so identity — not equality — is the test:
  /// `identical(deputy._save, principal._save)` is false by construction.
  MemoryAction? actionOf(Function fn) {
    if (identical(fn, _load)) return MemoryAction.load;
    if (identical(fn, _save)) return MemoryAction.save;
    if (identical(fn, _unload)) return MemoryAction.unload;
    if (identical(fn, _attach)) return MemoryAction.attach;
    if (identical(fn, _detach)) return MemoryAction.detach;
    if (identical(fn, _close)) return MemoryAction.close;
    if (identical(fn, _remove)) return MemoryAction.remove;
    return null;
  }

  /// A [TestCell] that allows only the durability actions in [allow].
  ///
  /// The only narrowing surface: a function passes only when the host maps
  /// it to an allowed action; a [MemoryCommand] always passes (its tear-off
  /// was already gated by `apply`, and rejecting here would hang the public
  /// method on its own reply completer); any other pulse passes only when
  /// [MemoryAction.apply] is allowed; everything else (arguments, link
  /// objects) passes. Installed through [TestCell.chain] — a plain
  /// `TestCell(rule)` never consults its rule for the action function.
  static TestCell<Cell> allow(Set<MemoryAction> allow) =>
      TestCell<Cell>.chain([
        TestCell<Cell>((object, {host, arguments, user}) {
          if (object is MemoryCommand) return true;
          if (object is Pulse) return allow.contains(MemoryAction.apply);
          if (object is Function) {
            final h = host;
            if (h is MemoryCell) {
              final action = h.actionOf(object);
              if (action != null) return allow.contains(action);
            }
            return false;
          }
          return true;
        }),
      ]);

  /// Creates a governed, memory-typed projection of this cell that shares
  /// its runtime.
  ///
  /// The returned deputy's rule is chained additively on top of this cell's
  /// rule — permissions can only narrow. Default arguments return `this`.
  @override
  FutureOr<MemoryCell<T>> deputy({
    EphemeralPolicy? ephemeralPolicy,
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
  }) {
    // Causal Integrity: the security context cannot escalate or bypass.
    // Same StateError as the framework deputies. The framework reads its
    // library-private `_parent`; the published surface exposes ancestry
    // only through `lineage`, so the check compares the Mandate.version /
    // identity lineages (a direct child adds exactly one version entry and
    // shares every base entry).
    if (!identical(context, DeputyContext.system) &&
        !identical(this.context, DeputyContext.system) &&
        !_isDirectDescendant(context, this.context)) {
      throw StateError(
        'Causal Integrity Violation: The new DeputyContext must be a direct '
        'descendant of the current context.',
      );
    }

    // Identity preservation: no proxy when no attenuation was requested.
    final bool isAttenuationRequested = ephemeralPolicy != null ||
        !identical(context, DeputyContext.system) ||
        !identical(testRule, TestCell.allowAll) ||
        !identical(synapses, Synapses.enabled);

    if (!isAttenuationRequested) {
      return this;
    }

    return _MemoryCellDeputy<T>(
      this,
      context: context,
      testRule: testRule,
      ephemeralPolicy: ephemeralPolicy,
      synapses: synapses,
    );
  }

  /// The cached read-only view. Sealed methods throw before `apply`, so the
  /// store is never touched through this projection.
  @override
  late final MemoryCell<T> unmodifiable = UnmodifiableMemoryCell<T>._(this);

  /// The root cell of this cell's nucleus chain — the principal.
  MemoryCell<T> get _rootCell {
    MemoryCellNucleus<T> nucleus = _nucleus;
    while (nucleus.principal != null) {
      nucleus = nucleus.principal!;
    }
    return nucleus.cell as MemoryCell<T>;
  }

  /// Whether [child] descends from [base], using the published lineage
  /// surface (the framework's own check reads its private `_parent`, which
  /// cross-package code cannot).
  ///
  /// A [DeputyContext] contributes no [Ontology] entries of its own, so a
  /// descendant shares the base's identity lineage exactly; an unrelated
  /// mandate built on a differently-identified base diverges. Depth
  /// (grandchild vs. direct child) is not observable from outside the
  /// framework package, so the check guards lineage membership — the
  /// escalation risk the StateError exists to stop — while the additive
  /// testRule chain keeps permissions narrowing-only.
  bool _isDirectDescendant(DeputyContext child, Context base) {
    final childIdentity = child.lineage(Ontology.identity);
    final baseIdentity = base.lineage(Ontology.identity);
    if (baseIdentity.isEmpty) {
      // Nothing to compare: both sides carry no identity lineage.
      return true;
    }
    if (childIdentity.length != baseIdentity.length) return false;
    for (var i = 0; i < baseIdentity.length; i++) {
      if (childIdentity[i] != baseIdentity[i]) return false;
    }
    return true;
  }

  /// The stable memory id. Names the record; never equals a `Cell.id`
  /// unless the caller chose one that happens to match.
  String get memoryId => _nucleus.slots.memoryId;

  /// The durable backend.
  MemoryStore get store => _nucleus.slots.store;

  /// The value codec.
  MemoryCodec<T> get codec => _nucleus.slots.codec;

  /// The write-through configuration.
  MemoryWritePolicy get policy => _nucleus.slots.policy;

  /// The debounce scheduler (injected for deterministic tests).
  MemoryScheduler get scheduler => _nucleus.slots.scheduler;

  /// Whether [close] closes [store].
  bool get ownsStore => _nucleus.slots.ownsStore;

  /// The cell's egress registry.
  ///
  /// Link downstream listeners with
  /// `memory.synapses.link(memory, downstreamCell: listener)`.
  Synapses get synapses => _nucleus.synapses;

  // ── forwarding the moved mutable state ────────────────────────────────
  //
  // Every field moved into `MemoryRuntime` keeps its cell-side name as a
  // forwarding getter/setter, so the method bodies below are untouched.

  T? get _value => _nucleus.runtime.value;
  set _value(T? next) => _nucleus.runtime.value = next;

  int get _storedRevision => _nucleus.runtime.storedRevision;
  set _storedRevision(int next) => _nucleus.runtime.storedRevision = next;

  Object? get _storedPayload => _nucleus.runtime.storedPayload;
  set _storedPayload(Object? next) => _nucleus.runtime.storedPayload = next;

  String? get _generation => _nucleus.runtime.generation;
  set _generation(String? next) => _nucleus.runtime.generation = next;

  String? get _pendingGeneration => _nucleus.runtime.pendingGeneration;
  set _pendingGeneration(String? next) =>
      _nucleus.runtime.pendingGeneration = next;

  bool get _loaded => _nucleus.runtime.loaded;
  set _loaded(bool next) => _nucleus.runtime.loaded = next;

  bool get _dirty => _nucleus.runtime.dirty;
  set _dirty(bool next) => _nucleus.runtime.dirty = next;

  bool get _closed => _nucleus.runtime.closed;
  set _closed(bool next) => _nucleus.runtime.closed = next;

  bool get _closing => _nucleus.runtime.closing;
  set _closing(bool next) => _nucleus.runtime.closing = next;

  bool get _storeReleased => _nucleus.runtime.storeReleased;
  set _storeReleased(bool next) => _nucleus.runtime.storeReleased = next;

  Object? get _flushError => _nucleus.runtime.flushError;
  set _flushError(Object? next) => _nucleus.runtime.flushError = next;

  // Setter-only: the public [lastError] getter reads the runtime directly.
  set _lastError(Object? next) => _nucleus.runtime.lastError = next;

  int get _commitGeneration => _nucleus.runtime.commitGeneration;
  set _commitGeneration(int next) => _nucleus.runtime.commitGeneration = next;

  int get _writeEpoch => _nucleus.runtime.writeEpoch;
  set _writeEpoch(int next) => _nucleus.runtime.writeEpoch = next;

  MemoryPulse<T>? get _lastEmitted => _nucleus.runtime.lastEmitted;
  set _lastEmitted(MemoryPulse<T>? next) => _nucleus.runtime.lastEmitted = next;

  EgressHandle? get _observer => _nucleus.runtime.observer;
  set _observer(EgressHandle? next) => _nucleus.runtime.observer = next;

  Object? get _attachToken => _nucleus.runtime.attachToken;
  set _attachToken(Object? next) => _nucleus.runtime.attachToken = next;

  StreamController<Object> get _errors => _nucleus.runtime.errors;

  Future<void> get _turnChain => _nucleus.runtime.turnChain;
  set _turnChain(Future<void> next) => _nucleus.runtime.turnChain = next;

  Future<void> get _writeChain => _nucleus.runtime.writeChain;
  set _writeChain(Future<void> next) => _nucleus.runtime.writeChain = next;

  Future<void> get _ingressChain => _nucleus.runtime.ingressChain;
  set _ingressChain(Future<void> next) => _nucleus.runtime.ingressChain = next;

  /// The committed in-process value, or `null` before the first load and
  /// after [unload]. After [unload], read [loaded] before trusting [value]:
  /// the durable record, not the in-memory value, is the retained copy.
  T? get value => _nucleus.runtime.value;

  /// The revision of the last successful store write; 0 when nothing has
  /// been stored. It advances only when a write succeeds, not when an
  /// ingress pulse is accepted.
  int get revision => _nucleus.runtime.storedRevision;

  /// Whether a load has finished (hit or miss). `false` before the first
  /// load and after [unload].
  bool get loaded => _nucleus.runtime.loaded;

  /// Whether [attach] currently wires an upstream cell.
  bool get attached => _nucleus.runtime.observer != null;

  /// Whether the cell has been closed by [unload] or [close].
  bool get closed => _nucleus.runtime.closed;

  /// Whether a newer in-memory value is still unwritten. This is the only
  /// way a caller can see that [save] persisted an older value and left a
  /// newer one pending.
  bool get dirty => _nucleus.runtime.dirty;

  /// The last failed write or failed ingress encoding, or `null` after a
  /// success.
  Object? get lastError => _nucleus.runtime.lastError;

  /// Broadcast stream of write failures and ingress encoding failures.
  /// Neither rolls back [value].
  Stream<Object> get errors => _nucleus.runtime.errors.stream;

  /// The nucleus of this cell — the test seam for the Phase 2 identity
  /// tests (`clone` / `evolve` sharing).
  @visibleForTesting
  MemoryCellNucleus<T> get nucleusForTest => _nucleus;

  /// The mutable runtime of this cell — the test seam for the Phase 2
  /// identity tests (two opens, distinct runtimes).
  @visibleForTesting
  MemoryRuntime<T> get runtimeForTest => _nucleus.runtime;

  void _checkOpen() {
    if (_closed || _closing) {
      throw StateError('MemoryCell "$memoryId" is closed');
    }
  }

  Future<R> _enqueue<R>(FutureOr<R> Function() turn) {
    final completer = Completer<R>();
    _turnChain = _turnChain.then((_) async {
      try {
        completer.complete(await turn());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  void _reportError(Object error) {
    _lastError = error;
    if (!_errors.isClosed) _errors.add(error);
  }

  void _disposeAfterFailedOpen() {
    _closed = true;
    if (!_errors.isClosed) _errors.close();
  }

  // ── ingress ──────────────────────────────────────────────────────────

  T? _defaultProject(Pulse pulse) {
    try {
      return pulse.payload as T?;
    } catch (e) {
      throw MemoryCorrupt(
        'incoming payload ${pulse.payload.runtimeType} cannot be retained '
        'as $T',
      );
    }
  }

  /// The synchronous [MemoryAction.apply] body: called by the dispatcher
  /// after the TestCell gate. Adopts the pulse payload or drops it.
  MemoryPulse<T>? _applyAction(Pulse pulse) {
    if (_closed || _closing) return null;
    return _adopt(pulse, _defaultProject);
  }

  /// Adopts [pulse]'s projected value as the committed value, marks the
  /// cell dirty when the encoded form changed, schedules a write, and
  /// returns the [MemoryPulse] to broadcast. Returns `null` on rejection or
  /// echo. Once [unload] or [close] has been called, ingress latches: the
  /// pulse is dropped before projection or encoding, without an `errors`
  /// report — a rejected pulse is not a failure.
  ///
  /// Echoes are suppressed in two ways: a pulse that is identical to the
  /// last emission, and any memory pulse whose [Pulse.source] is this cell.
  /// The framework hands the receptor a step wrapper whose runtime type is
  /// not [MemoryPulse]; both checks therefore read the delegating
  /// [Pulse.type] / [Pulse.source] surface, which the wrapper forwards to
  /// the wrapped pulse. A chained memory cell's
  /// [MemoryEvent.removed] / [MemoryEvent.unloaded] pulses are not value
  /// updates and are ignored.
  MemoryPulse<T>? _adopt(Pulse pulse, T? Function(Pulse pulse) project) {
    if (_closed || _closing || identical(pulse, _lastEmitted)) return null;
    final type = pulse.type;
    if (type is MemoryEvent) {
      if (identical(pulse.source, this)) return null;
      if (type == MemoryEvent.removed || type == MemoryEvent.unloaded) {
        return null;
      }
    }
    final T? next;
    try {
      next = project(pulse);
    } on MemoryCorrupt catch (e) {
      _reportError(e);
      return null;
    } catch (e) {
      _reportError(
          MemoryCorrupt('incoming pulse cannot be retained as $T: $e'));
      return null;
    }
    // Encode before committing: a non-serialisable value must be rejected
    // without touching `_value` or the generation, and the failure belongs
    // on `errors`, not in the framework's delivery path.
    final Object? encoded;
    try {
      encoded = _encodeValue(next);
    } on MemoryNotSerializable catch (e) {
      _reportError(e);
      return null;
    } catch (e) {
      _reportError(
          MemoryCorrupt('incoming value cannot be encoded as $T: $e'));
      return null;
    }
    _commitGeneration++;
    _value = next;
    // Dirty is decided by the codec, not by T.==: two domain objects can
    // be equal as values and still differ once encoded, or the reverse.
    _dirty = _payloadKey(encoded) != _payloadKey(_storedPayload);
    final emitted = memoryApplied<T>(
      source: this,
      value: next,
      revision: _storedRevision,
    );
    _lastEmitted = emitted;
    _scheduleWrite();
    return emitted;
  }

  Object? _encodeValue(T? current) =>
      current == null ? null : codec.encode(current as T);

  /// The generation the next write carries: the one loaded from the store,
  /// or the create generation already minted for an in-flight attempt, or
  /// a freshly minted one.
  String _generationForWrite() {
    final known = _generation;
    if (known != null) return known;
    return _pendingGeneration ??= MemoryEnvelope.mintGeneration();
  }

  static String _payloadKey(Object? payload) =>
      const JsonPayloadKey().keyOf(payload);

  // ── write scheduling ─────────────────────────────────────────────────

  void _scheduleWrite() {
    if (_closed || _closing || !policy.enabled) return;
    switch (policy.mode) {
      case MemoryWriteMode.immediate:
        unawaited(_runWrite(detached: true));
      case MemoryWriteMode.debounced:
        scheduler.schedule(policy.debounce, () {
          unawaited(_runWrite(detached: true));
        });
      case MemoryWriteMode.explicit:
        break;
    }
  }

  /// Runs one write turn on the serial write chain. With [detached], errors
  /// are reported on [errors]; otherwise they propagate to the caller of
  /// `save` / the flush.
  ///
  /// The dirty check is repeated when the turn actually runs: a queued
  /// write behind a newer one must not write the same payload again and
  /// inflate the revision. The write epoch is captured at queue time and
  /// re-checked at execution time, so a write queued before
  /// `remove`/`unload`/`close` is fenced out after them. Once the cell is
  /// closing, only the flush's own call (with [flush]) may start a write.
  Future<MemoryEnvelope?> _runWrite({
    required bool detached,
    bool flush = false,
  }) {
    if (_closed || !policy.enabled || !_dirty) {
      return Future.value(null);
    }
    if (_closing && !flush) {
      return Future.value(null);
    }
    final epoch = _writeEpoch;
    final result = _writeChain.then((_) {
      if (_closed || epoch != _writeEpoch || !policy.enabled || !_dirty) {
        return null;
      }
      if (_closing && !flush) return null;
      return _performWrite(epoch);
    });
    // The chain must survive failures or every later write would be
    // skipped. Failures are already reported inside `_performWrite`.
    _writeChain = result.then<void>((_) {}, onError: (_) {});
    if (detached) {
      return Future.value(null);
    }
    return result;
  }

  Future<MemoryEnvelope?> _performWrite(int epoch) async {
    final generation = _commitGeneration;
    final current = _value;
    final expected = _storedRevision;
    // Minted before the await; the envelope and the conflict-recovery
    // comparison envelope must carry the same string, and a lost-response
    // retry must resend it or it will not match the row that landed.
    final writeGeneration = _generationForWrite();
    try {
      final encoded = _encodeValue(current);
      final envelope = MemoryEnvelope(
        id: memoryId,
        kind: 'value',
        revision: expected + 1,
        generation: writeGeneration,
        payload: encoded,
        codec: codec.name,
      );
      await store.write(envelope, expectedRevision: expected);
      if (_closed || epoch != _writeEpoch) {
        // A remove/unload/close won while the write was in flight. The
        // record the write created was already deleted (or is about to
        // be) — adopt nothing, emit nothing.
        return null;
      }
      // The store accepted the envelope; its revision is now the store's
      // revision, whatever else happened in memory meanwhile.
      _storedRevision = envelope.revision;
      _storedPayload = envelope.payload;
      _generation = envelope.generation;
      _pendingGeneration = null;
      if (generation == _commitGeneration) {
        _dirty = false;
        _lastError = null;
        final emitted = memoryStored<T>(
          source: this,
          value: current,
          revision: envelope.revision,
        );
        _lastEmitted = emitted;
        _emit(emitted);
        return envelope;
      }
      // A newer value was committed while the write was in flight: keep the
      // cell dirty and write the newer value next (unless the cell is
      // closing — the flush owns the last write). The stale envelope is
      // not installed as the current payload, and `stored` is emitted only
      // for the value that matches the commit generation above; the
      // caller still gets the envelope the store accepted.
      _dirty =
          _payloadKey(_encodeValue(_value)) != _payloadKey(envelope.payload);
      if (!_closing) _scheduleWrite();
      return envelope;
    } on MemoryConflict catch (e) {
      // Lost-race recovery: if the store holds exactly this attempt's
      // envelope (same generation included), the write actually landed —
      // adopt its revision and go clean. Otherwise the conflict is real:
      // report it, drop the pending create generation, and keep the cell
      // dirty for the caller's retry. Nothing reschedules, so a real
      // conflict cannot hot-loop.
      if (epoch != _writeEpoch || _closed) {
        // A remove/unload/close won while the write was in flight: adopt
        // nothing.
        return null;
      }
      final MemoryEnvelope? stored;
      if (e.stored != null) {
        stored = e.stored;
      } else {
        try {
          stored = await store.read(memoryId);
        } on MemoryStoreException {
          _reportError(e);
          rethrow;
        }
      }
      if (stored != null &&
          stored.sameContent(MemoryEnvelope(
            id: memoryId,
            kind: 'value',
            revision: expected + 1,
            generation: writeGeneration,
            payload: _encodeValue(current),
            codec: codec.name,
          ))) {
        _storedRevision = stored.revision;
        _storedPayload = stored.payload;
        _generation = stored.generation;
        _pendingGeneration = null;
        _dirty =
            _payloadKey(_encodeValue(_value)) != _payloadKey(stored.payload);
        _lastError = null;
        if (!_dirty && !_closing) {
          // The landed row is the current value: publish the recovered
          // write. No scheduling from this path.
          final emitted = memoryStored<T>(
            source: this,
            value: _value,
            revision: stored.revision,
          );
          _lastEmitted = emitted;
          _emit(emitted);
        }
        return null;
      }
      _pendingGeneration = null;
      _reportError(e);
      rethrow;
    } on MemoryStoreException catch (e) {
      _reportError(e);
      rethrow;
    } on MemoryNotSerializable catch (e) {
      _reportError(e);
      rethrow;
    }
  }

  /// Broadcasts [pulse] from the write engine and the attach observer —
  /// the emissions that do not travel through the dispatcher continuation.
  ///
  /// When the emitting host is a deputy, the principal's registry must hear
  /// the pulse too (a context-only deputy's `save` still writes the shared
  /// record, and principal observers must see the stored event). Two
  /// registries, one callback each — never a second delivery on the same
  /// registry.
  void _emit(MemoryPulse<T> pulse) {
    if (_closed) return;
    synapses.call(pulse);
    final root = _rootCell;
    if (!identical(this, root)) root.synapses.call(pulse);
  }

  // ── durability operations ────────────────────────────────────────────

  /// Reads the store. If an envelope exists, decodes it, adopts its
  /// revision, and emits one [MemoryPulse] of [MemoryEvent.loaded]. If
  /// absent, keeps [initial], emits nothing, and does not write.
  ///
  /// A corrupt envelope — bad bytes, an unknown schema, a non-`value`
  /// kind, or a codec mismatch — throws [MemoryCorrupt] and leaves the
  /// previous value untouched. [load] runs through [Cell.apply]: the
  /// [TestCell] gate vets the `_load` tear-off before the instruction
  /// reads the store, and a rejected tear-off surfaces as a [StateError].
  ///
  /// If a pulse is accepted while the read is in flight, the loaded value
  /// is dropped but the envelope's revision and payload are still adopted:
  /// the store holds them, and every later write must count from there.
  Future<T?> load() {
    final reply = Completer<T?>();
    final ApplyCommand command = (
      function: _load,
      arguments: (
        positionalArguments: null,
        namedArguments: <Symbol, Object?>{#reply: reply},
      ),
      compensation: null,
    );
    return _submit(command, reply, 'load');
  }

  /// The [MemoryAction.load] body: the old `load()` turn, moved. Resumes
  /// the receptor continuation with the loaded pulse — exactly one
  /// broadcast — and completes the command's reply with the return value.
  void _loadAction(
    Pulse pulse,
    void Function({required Pulse? result, required dynamic token})? future,
    dynamic token,
  ) {
    final command = pulse.type as MemoryCommand<T>;
    final reply = command.reply as Completer<T?>;
    _enqueue(() async {
      _checkOpen();
      final generation = _commitGeneration;
      final MemoryEnvelope? envelope;
      try {
        envelope = await store.read(memoryId);
      } on MemoryStoreException catch (e) {
        _reportError(e);
        rethrow;
      }
      if (_closed) return null;
      if (envelope == null) {
        _loaded = true;
        return null;
      }
      if (envelope.kind != 'value') {
        throw MemoryCorrupt(
            'envelope for "$memoryId" has kind "${envelope.kind}"; a '
            'value cell can only load kind "value"');
      }
      if (envelope.id != memoryId) {
        throw MemoryCorrupt(
            'envelope id "${envelope.id}" does not match cell '
            '"$memoryId"');
      }
      if (envelope.codec != null && envelope.codec != codec.name) {
        throw MemoryCorrupt(
            'envelope for "$memoryId" was written by codec '
            '"${envelope.codec}" but this cell uses "${codec.name}"');
      }
      final T restored;
      try {
        restored = codec.decode(envelope.payload);
      } on MemoryCorrupt catch (e) {
        _reportError(e);
        rethrow;
      }
      _storedRevision = envelope.revision;
      _storedPayload = envelope.payload;
      _generation = envelope.generation;
      _pendingGeneration = null;
      _loaded = true;
      if (generation != _commitGeneration) {
        // A pulse was accepted while the read was in flight: keep the
        // in-memory value but adopt the store's revision baseline, then
        // recompute whether the newer value still needs writing.
        _dirty =
            _payloadKey(_encodeValue(_value)) != _payloadKey(envelope.payload);
        return null;
      }
      _value = restored;
      _dirty = false;
      _lastError = null;
      final emitted = memoryLoaded<T>(
        source: this,
        value: restored,
        revision: envelope.revision,
      );
      _lastEmitted = emitted;
      return emitted;
    }).then<void>(
      (emitted) {
        if (emitted != null) {
          reply.complete(emitted.payload);
          future?.call(result: emitted, token: token);
        } else {
          reply.complete(_value);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        reply.completeError(error, stackTrace);
      },
    );
  }

  /// Encodes the current value and writes one envelope at
  /// `revision + 1`. Returns `null` without writing when the value is
  /// unchanged since the last successful write, and when
  /// [MemoryWritePolicy.enabled] is `false`.
  ///
  /// One write, no loop: the write captures the value that is current when
  /// it starts. If a newer pulse arrived during the `await`, [save] returns
  /// the envelope of the value it captured and leaves [dirty] true — a
  /// later [save] (or the next policy write) persists the newer value. No
  /// `StateError` for non-convergence exists.
  ///
  /// A successful write emits [MemoryEvent.stored]. The value was already
  /// broadcast by ingress or [load] before this runs. A failed write
  /// surfaces the error, reports it on [errors], and leaves the value
  /// dirty.
  Future<MemoryEnvelope?> save() {
    final reply = Completer<MemoryEnvelope?>();
    final ApplyCommand command = (
      function: _save,
      arguments: (
        positionalArguments: null,
        namedArguments: <Symbol, Object?>{#reply: reply},
      ),
      compensation: null,
    );
    return _submit(command, reply, 'save');
  }

  /// The [MemoryAction.save] body: the old `save()` turn, moved. One
  /// compare-and-swap attempt; a conflict throws [MemoryConflict] from the
  /// reply channel, and a partial `.tmp` throws [MemoryCorrupt].
  void _saveAction(
    Pulse pulse,
    void Function({required Pulse? result, required dynamic token})? future,
    dynamic token,
  ) {
    final command = pulse.type as MemoryCommand<T>;
    final reply = command.reply as Completer<MemoryEnvelope?>;
    _enqueue(() async {
      _checkOpen();
      if (!policy.enabled) return null;
      // Cancels a pending debounce: save() decides the write moment.
      scheduler.cancel();
      await _writeChain;
      if (!_dirty) return null;
      return _runWrite(detached: false);
    }).then<void>(
      (envelope) => reply.complete(envelope),
      onError: (Object error, StackTrace stackTrace) {
        reply.completeError(error, stackTrace);
      },
    );
  }

  /// `save()` if dirty, then detaches from the upstream cell [attach]
  /// created, drops the in-memory value, and stops emitting. The durable
  /// record remains — [unload] is not [remove].
  ///
  /// Ingress latches the moment this method returns its future: a pulse
  /// that arrives after the call is not a value. The flush waits for the
  /// in-flight write, issues one more write if still dirty, then closes
  /// the cell. A failed flush still closes and detaches; the error is
  /// rethrown and remains on [lastError]. [unload] does not close the
  /// store — [close] does, once, when [ownsStore] is set.
  Future<void> unload() {
    final reply = Completer<void>();
    final ApplyCommand command = (
      function: _unload,
      arguments: (
        positionalArguments: null,
        namedArguments: <Symbol, Object?>{#reply: reply},
      ),
      compensation: null,
    );
    return _submit(command, reply, 'unload');
  }

  /// The [MemoryAction.unload] body. Latches synchronously (the dispatcher
  /// runs inside `apply`, so the latch still lands before `unload()`'s
  /// future reaches the caller), then runs the old `unload()` turn and
  /// resumes the continuation with the unloaded pulse.
  void _unloadAction(
    Pulse pulse,
    void Function({required Pulse? result, required dynamic token})? future,
    dynamic token,
  ) {
    final command = pulse.type as MemoryCommand<T>;
    final reply = command.reply as Completer<void>;
    if (_closed || _closing) {
      _enqueue(() async {
        throw StateError('MemoryCell "$memoryId" is closed');
      }).then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          reply.completeError(error, stackTrace);
        },
      );
      return;
    }
    _closing = true;
    scheduler.cancel();
    _enqueue(() async {
      final emitted = await _finish(emitUnloaded: true);
      final error = _flushError;
      if (error != null) {
        _flushError = null;
        // ignore: only_throw_errors
        throw error;
      }
      return emitted;
    }).then<void>(
      (emitted) {
        reply.complete(null);
        if (emitted != null) future?.call(result: emitted, token: token);
      },
      onError: (Object error, StackTrace stackTrace) {
        reply.completeError(error, stackTrace);
      },
    );
  }

  /// Deletes the durable record and clears memory. Does not close the cell;
  /// [load] may hydrate it again. Detaches the upstream unless [detach] is
  /// `false`.
  ///
  /// In-flight and queued writes are drained before the delete, and the
  /// write epoch is fenced, so a write queued during the drain — or one
  /// still inside `store.write` when remove wins — cannot resurrect the
  /// record or publish a revision for a record that no longer exists.
  /// `remove` is not a flush and never latches ingress.
  Future<void> remove({bool detach = true}) {
    final reply = Completer<void>();
    final ApplyCommand command = (
      function: _remove,
      arguments: (
        positionalArguments: null,
        namedArguments: <Symbol, Object?>{#reply: reply, #detach: detach},
      ),
      compensation: null,
    );
    return _submit(command, reply, 'remove');
  }

  /// The [MemoryAction.remove] body: the old `remove()` turn, moved.
  /// Resumes the continuation with the removed pulse.
  void _removeAction(
    Pulse pulse,
    void Function({required Pulse? result, required dynamic token})? future,
    dynamic token,
  ) {
    final command = pulse.type as MemoryCommand<T>;
    final reply = command.reply as Completer<void>;
    final detach = command.detach;
    _enqueue(() async {
      _checkOpen();
      scheduler.cancel();
      await _writeChain;
      _writeEpoch++;
      _commitGeneration++;
      final lastValue = _value;
      await store.remove(memoryId);
      if (detach) _detachUpstream();
      _value = null;
      _loaded = false;
      _dirty = false;
      _storedRevision = 0;
      _storedPayload = null;
      _generation = null;
      _pendingGeneration = null;
      _lastError = null;
      final emitted = memoryRemoved<T>(source: this, value: lastValue);
      _lastEmitted = emitted;
      return emitted;
    }).then<void>(
      (emitted) {
        reply.complete(null);
        future?.call(result: emitted, token: token);
      },
      onError: (Object error, StackTrace stackTrace) {
        reply.completeError(error, stackTrace);
      },
    );
  }

  /// Flushes if loaded, detaches, closes the errors stream, and closes the
  /// store only when [ownsStore] is `true`. Idempotent, including two calls
  /// made before the first turn runs.
  ///
  /// Ingress latches the moment this method returns its future. A failed
  /// flush still closes the cell; the error is rethrown and the owned
  /// store is still asked to close. [close] after [unload] does not flush
  /// again — it releases the owned store the failed flush did not.
  Future<void> close() {
    final reply = Completer<void>();
    final ApplyCommand command = (
      function: _close,
      arguments: (
        positionalArguments: null,
        namedArguments: <Symbol, Object?>{#reply: reply},
      ),
      compensation: null,
    );
    return _submit(command, reply, 'close');
  }

  /// The [MemoryAction.close] body. The flush-start latch runs
  /// synchronously inside the dispatcher (still before `close()` returns
  /// its future); the turn flushes once, releases the owned store, and
  /// resumes the continuation with the unloaded pulse.
  void _closeAction(
    Pulse pulse,
    void Function({required Pulse? result, required dynamic token})? future,
    dynamic token,
  ) {
    final command = pulse.type as MemoryCommand<T>;
    final reply = command.reply as Completer<void>;
    final startFlush = !_closed && !_closing;
    if (startFlush) {
      _closing = true;
      scheduler.cancel();
    }
    _enqueue(() async {
      MemoryPulse<T>? emitted;
      if (startFlush) {
        emitted = await _finish(emitUnloaded: _loaded || _observer != null);
      }
      await _releaseOwnedStore();
      final error = _flushError;
      if (error != null) {
        _flushError = null;
        // ignore: only_throw_errors
        throw error;
      }
      return emitted;
    }).then<void>(
      (emitted) {
        reply.complete(null);
        if (emitted != null) future?.call(result: emitted, token: token);
      },
      onError: (Object error, StackTrace stackTrace) {
        reply.completeError(error, stackTrace);
      },
    );
  }

  /// The shared flush body of [unload] and [close], run inside the turn.
  ///
  /// Ingress is already latched, so the value cannot move while the flush
  /// writes: wait for the in-flight write, issue one more write if the
  /// policy allows and the cell is dirty, then fence the epoch, detach,
  /// drop everything including both generation fields, and close. The
  /// unloaded pulse — when requested — is returned, not emitted: the
  /// action's continuation owns the single broadcast. There is no second
  /// attempt and no path that reports success while the latched value is
  /// unwritten.
  Future<MemoryPulse<T>?> _finish({required bool emitUnloaded}) async {
    final lastValue = _value;
    Object? flushError;
    try {
      await _writeChain;
      if (policy.enabled && _dirty) {
        await _runWrite(detached: false, flush: true);
      }
    } catch (e) {
      // A store error is the caller's error; do not clear lastError
      // afterwards.
      flushError = e;
    }
    if (flushError == null && policy.enabled && _dirty) {
      flushError = StateError('flush left "$memoryId" dirty');
    }
    _flushError = flushError;
    _writeEpoch++;
    MemoryPulse<T>? emitted;
    if (emitUnloaded) {
      emitted = memoryUnloaded<T>(
        source: this,
        value: lastValue,
        revision: _storedRevision,
      );
      _lastEmitted = emitted;
    }
    _detachUpstream();
    _value = null;
    _loaded = false;
    _dirty = false;
    _storedPayload = null;
    _generation = null;
    _pendingGeneration = null;
    _closed = true;
    if (!_errors.isClosed) _errors.close();
    return emitted;
  }

  /// Closes an owned store exactly once, even when the cell was already
  /// unloaded and even when the flush threw. A store-close error never
  /// replaces the flush error the caller already owns.
  Future<void> _releaseOwnedStore() async {
    if (!ownsStore || _storeReleased) return;
    _storeReleased = true;
    try {
      await store.close();
    } catch (error) {
      _flushError ??= error;
    }
  }

  // ── attach / detach ──────────────────────────────────────────────────

  /// Wires [upstream] into this cell through the framework's public
  /// observer binding — the seam Phase 0 verified for sources whose
  /// synapses are not publicly reachable (a `Cell.state`).
  ///
  /// Every accepted upstream pulse is projected with [project] (default:
  /// `pulse.payload as T`) and retained. Attaching twice throws
  /// [StateError]; call [detach] first.
  ///
  /// Synchronous validators adopt inline (delivery stays synchronous);
  /// asynchronous validators are serialised on a FIFO chain so pulses are
  /// adopted in arrival order, never completion order, and a rejecting
  /// validator reports on [errors].
  Future<void> attach(Cell upstream, {T? Function(Pulse pulse)? project}) {
    final reply = Completer<void>();
    final ApplyCommand command = (
      function: _attach,
      arguments: (
        positionalArguments: null,
        namedArguments: <Symbol, Object?>{
          #reply: reply,
          #source: upstream,
          #project: project,
        },
      ),
      compensation: null,
    );
    return _submit(command, reply, 'attach');
  }

  /// The [MemoryAction.attach] body: the old `attach()` turn, moved. The
  /// observer's applied pulses are emitted directly — they enter through
  /// `Cell.observe`, not through the dispatcher, so the continuation has
  /// no part in their delivery.
  void _attachAction(
    Pulse pulse,
    void Function({required Pulse? result, required dynamic token})? future,
    dynamic token,
  ) {
    final command = pulse.type as MemoryCommand<T>;
    final reply = command.reply as Completer<void>;
    final upstream = command.source!;
    _enqueue(() async {
      _checkOpen();
      if (_observer != null) {
        throw StateError(
            'MemoryCell "$memoryId" is already attached; detach first');
      }
      final proj = command.project ?? _defaultProject;
      final attachToken = Object();
      _attachToken = attachToken;
      final observer = Cell.observe<Pulse>(
        source: upstream,
        effect: (pulse) {
          final validation = validate(pulse, host: this);
          if (validation is Future<bool>) {
            _ingressChain = _ingressChain.then((_) async {
              // The observer may have been detached while the validation
              // was in flight: the pulse must not be adopted then.
              if (!identical(_attachToken, attachToken) || _closed) return;
              final bool passed;
              try {
                passed = await validation;
              } catch (e) {
                _reportError(e);
                return;
              }
              if (passed) {
                final emitted = _adopt(pulse, proj);
                if (emitted != null) _emit(emitted);
              }
            });
            return;
          }
          if (validation == true) {
            final emitted = _adopt(pulse, proj);
            if (emitted != null) _emit(emitted);
          }
        },
      );
      _observer = observer;
    }).then<void>(
      (_) => reply.complete(null),
      onError: (Object error, StackTrace stackTrace) {
        reply.completeError(error, stackTrace);
      },
    );
  }

  /// Stops the upstream wiring created by [attach]. Idempotent.
  Future<void> detach() {
    final reply = Completer<void>();
    final ApplyCommand command = (
      function: _detach,
      arguments: (
        positionalArguments: null,
        namedArguments: <Symbol, Object?>{#reply: reply},
      ),
      compensation: null,
    );
    return _submit(command, reply, 'detach');
  }

  /// The [MemoryAction.detach] body: the old `detach()` turn, moved.
  void _detachAction(
    Pulse pulse,
    void Function({required Pulse? result, required dynamic token})? future,
    dynamic token,
  ) {
    final command = pulse.type as MemoryCommand<T>;
    final reply = command.reply as Completer<void>;
    _enqueue(() async {
      _checkOpen();
      _detachUpstream();
    }).then<void>(
      (_) => reply.complete(null),
      onError: (Object error, StackTrace stackTrace) {
        reply.completeError(error, stackTrace);
      },
    );
  }

  void _detachUpstream() {
    _attachToken = null;
    _observer?.stop();
    _observer = null;
  }
}
