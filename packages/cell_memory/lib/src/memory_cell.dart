// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell/cell.dart';

import 'codec.dart';
import 'envelope.dart';
import 'id.dart';
import 'memory_pulse.dart';
import 'policy.dart';
import 'scheduler.dart';
import 'store.dart';

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
  MemoryCell._({
    required this.memoryId,
    required this.store,
    required this.codec,
    required this.policy,
    required this.scheduler,
    required this.ownsStore,
    required this.synapses,
    required super.receptor,
    required super.context,
    T? initial,
  })  : _value = initial,
        super(synapses: synapses);

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
    late final MemoryCell<T> self;
    final receptor = Receptor((cell, pulse, {user}) {
      // The cell hosting the receptor may be a deputy proxy; the memory
      // cell instance is captured, so ingress always lands on the
      // principal's state.
      return self._receptorIngress(pulse);
    });
    final synapses = Synapses();
    final cell = MemoryCell<T>._(
      memoryId: id,
      store: store,
      codec: codec,
      policy: policy,
      scheduler: scheduler ?? TimerScheduler(),
      ownsStore: ownsStore,
      synapses: synapses,
      receptor: receptor,
      context: context,
      initial: initial,
    );
    self = cell;
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

  /// The stable memory id. Names the record; never equals a `Cell.id`
  /// unless the caller chose one that happens to match.
  final String memoryId;

  /// The durable backend.
  final MemoryStore store;

  /// The value codec.
  final MemoryCodec<T> codec;

  /// The write-through configuration.
  final MemoryWritePolicy policy;

  /// The debounce scheduler (injected for deterministic tests).
  final MemoryScheduler scheduler;

  /// Whether [close] closes [store].
  final bool ownsStore;

  /// The cell's egress registry.
  ///
  /// Link downstream listeners with
  /// `memory.synapses.link(memory, downstreamCell: listener)`.
  final Synapses synapses;

  T? _value;

  int _storedRevision = 0;

  Object? _storedPayload;

  /// The last generation known to be stored. Null until a load hits or the
  /// first create is attempted.
  String? _generation;

  /// Minted for a create that has not landed yet. Cleared on success, on
  /// remove, and on a real conflict; kept across `MemoryIoException` and
  /// `MemoryNotSerializable` so a retry of a create that might have landed
  /// sends the same generation.
  String? _pendingGeneration;

  bool _loaded = false;

  bool _dirty = false;

  bool _closed = false;

  /// Latched synchronously by [unload] / [close] before either returns its
  /// future. Ingress and scheduling stop immediately; the flush owns the
  /// last write.
  bool _closing = false;

  /// Whether [close] has asked an owned store to close.
  bool _storeReleased = false;

  /// The flush error held between `_finish` and the rethrow in the turn,
  /// so `close` after a failed `unload` still releases the store without
  /// replacing the caller's error.
  Object? _flushError;

  Object? _lastError;

  int _commitGeneration = 0;

  /// Fenced in [remove] / [unload] / [close]: a write queued before one of
  /// them must not touch the store after the delete or the final flush.
  /// `_performWrite` re-checks the epoch at execution time and after its
  /// `await`, so a late write is discarded, never resurrected.
  int _writeEpoch = 0;

  MemoryPulse<T>? _lastEmitted;

  EgressHandle? _observer;

  /// Token for the current [attach]; cleared by [detach]. An async
  /// validation in flight must not adopt after the observer is gone.
  Object? _attachToken;

  final StreamController<Object> _errors =
      StreamController<Object>.broadcast();

  Future<void> _turnChain = Future<void>.value();

  Future<void> _writeChain = Future<void>.value();

  Future<void> _ingressChain = Future<void>.value();

  /// The committed in-process value, or `null` before the first load and
  /// after [unload]. After [unload], read [loaded] before trusting [value]:
  /// the durable record, not the in-memory value, is the retained copy.
  T? get value => _value;

  /// The revision of the last successful store write; 0 when nothing has
  /// been stored. It advances only when a write succeeds, not when an
  /// ingress pulse is accepted.
  int get revision => _storedRevision;

  /// Whether a load has finished (hit or miss). `false` before the first
  /// load and after [unload].
  bool get loaded => _loaded;

  /// Whether [attach] currently wires an upstream cell.
  bool get attached => _observer != null;

  /// Whether the cell has been closed by [unload] or [close].
  bool get closed => _closed;

  /// Whether a newer in-memory value is still unwritten. This is the only
  /// way a caller can see that [save] persisted an older value and left a
  /// newer one pending.
  bool get dirty => _dirty;

  /// The last failed write or failed ingress encoding, or `null` after a
  /// success.
  Object? get lastError => _lastError;

  /// Broadcast stream of write failures and ingress encoding failures.
  /// Neither rolls back [value].
  Stream<Object> get errors => _errors.stream;

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

  /// Receptor ingress: called by the framework after the TestCell gate.
  Pulse? _receptorIngress(Pulse pulse) {
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
  /// last emission, and any [MemoryPulse] whose [MemoryPulse.source] is
  /// this cell — the latter also catches pulses a relay derived with
  /// `withStep` / `evolve`, which change identity. A chained memory cell's
  /// [MemoryEvent.removed] / [MemoryEvent.unloaded] pulses are not value
  /// updates and are ignored.
  MemoryPulse<T>? _adopt(Pulse pulse, T? Function(Pulse pulse) project) {
    if (_closed || _closing || identical(pulse, _lastEmitted)) return null;
    if (pulse is MemoryPulse) {
      if (identical(pulse.source, this)) return null;
      if (pulse.event == MemoryEvent.removed ||
          pulse.event == MemoryEvent.unloaded) {
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

  void _emit(MemoryPulse<T> pulse) {
    if (_closed) return;
    synapses.call(pulse);
  }

  // ── durability operations ────────────────────────────────────────────

  /// Reads the store. If an envelope exists, decodes it, adopts its
  /// revision, and emits one [MemoryPulse] of [MemoryEvent.loaded]. If
  /// absent, keeps [initial], emits nothing, and does not write.
  ///
  /// A corrupt envelope — bad bytes, an unknown schema, a non-`value`
  /// kind, or a codec mismatch — throws [MemoryCorrupt] and leaves the
  /// previous value untouched. [load] does not call [Cell.apply] and does
  /// not re-run the [TestCell]: the store is already the retained record.
  ///
  /// If a pulse is accepted while the read is in flight, the loaded value
  /// is dropped but the envelope's revision and payload are still adopted:
  /// the store holds them, and every later write must count from there.
  Future<T?> load() => _enqueue(() async {
        _checkOpen();
        final generation = _commitGeneration;
        final MemoryEnvelope? envelope;
        try {
          envelope = await store.read(memoryId);
        } on MemoryStoreException catch (e) {
          _reportError(e);
          rethrow;
        }
        if (_closed) return _value;
        if (envelope == null) {
          _loaded = true;
          return _value;
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
          return _value;
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
        _emit(emitted);
        return restored;
      });

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
  Future<MemoryEnvelope?> save() => _enqueue(() async {
        _checkOpen();
        if (!policy.enabled) return null;
        // Cancels a pending debounce: save() decides the write moment.
        scheduler.cancel();
        await _writeChain;
        if (!_dirty) return null;
        return _runWrite(detached: false);
      });

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
    if (_closed || _closing) {
      return _enqueue(() async {
        throw StateError('MemoryCell "$memoryId" is closed');
      });
    }
    _closing = true;
    scheduler.cancel();
    return _enqueue(() async {
      await _finish(emitUnloaded: true);
      final error = _flushError;
      if (error != null) {
        _flushError = null;
        // ignore: only_throw_errors
        throw error;
      }
    });
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
  Future<void> remove({bool detach = true}) => _enqueue(() async {
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
        _emit(emitted);
      });

  /// Flushes if loaded, detaches, closes the errors stream, and closes the
  /// store only when [ownsStore] is `true`. Idempotent, including two calls
  /// made before the first turn runs.
  ///
  /// Ingress latches the moment this method returns its future. A failed
  /// flush still closes the cell; the error is rethrown and the owned
  /// store is still asked to close. [close] after [unload] does not flush
  /// again — it releases the owned store the failed flush did not.
  Future<void> close() {
    final startFlush = !_closed && !_closing;
    if (startFlush) {
      _closing = true;
      scheduler.cancel();
    }
    return _enqueue(() async {
      if (startFlush) {
        await _finish(emitUnloaded: _loaded || _observer != null);
      }
      await _releaseOwnedStore();
      final error = _flushError;
      if (error != null) {
        _flushError = null;
        // ignore: only_throw_errors
        throw error;
      }
    });
  }

  /// The shared flush body of [unload] and [close], run inside the turn.
  ///
  /// Ingress is already latched, so the value cannot move while the flush
  /// writes: wait for the in-flight write, issue one more write if the
  /// policy allows and the cell is dirty, then fence the epoch, emit,
  /// detach, drop everything including both generation fields, and close.
  /// There is no second attempt and no path that reports success while the
  /// latched value is unwritten.
  Future<void> _finish({required bool emitUnloaded}) async {
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
    if (emitUnloaded) {
      final emitted = memoryUnloaded<T>(
        source: this,
        value: lastValue,
        revision: _storedRevision,
      );
      _lastEmitted = emitted;
      _emit(emitted);
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
  Future<void> attach(Cell upstream, {T? Function(Pulse pulse)? project}) =>
      _enqueue(() async {
        _checkOpen();
        if (_observer != null) {
          throw StateError(
              'MemoryCell "$memoryId" is already attached; detach first');
        }
        final proj = project ?? _defaultProject;
        final token = Object();
        _attachToken = token;
        final observer = Cell.observe<Pulse>(
          source: upstream,
          effect: (pulse) {
            final validation = validate(pulse, host: this);
            if (validation is Future<bool>) {
              _ingressChain = _ingressChain.then((_) async {
                // The observer may have been detached while the validation
                // was in flight: the pulse must not be adopted then.
                if (!identical(_attachToken, token) || _closed) return;
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
      });

  /// Stops the upstream wiring created by [attach]. Idempotent.
  Future<void> detach() => _enqueue(() async {
        _checkOpen();
        _detachUpstream();
      });

  void _detachUpstream() {
    _attachToken = null;
    _observer?.stop();
    _observer = null;
  }
}
