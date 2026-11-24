// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The idempotency store.
///
/// A repeated client id replays the same attempt and nothing else. The
/// record lives in an [IdempotencyStore] — never in the domain ledger —
/// keyed by the actor plus the caller's id and fingerprinted over the
/// exact request. The default is an in-memory store (1024 completed
/// records, 24 hour TTL); a file or SQL store can implement the same
/// interface later without another router change.
/// {@category Features}
/// {@category Idempotency}
library;

import 'dart:async';

import 'package:cell/cell.dart';

import 'wire_message.dart';

/// What a `claim` means for one key.
sealed class IdempotencyClaim {
  const IdempotencyClaim();
}

/// This caller owns the attempt: nothing is stored for the key yet.
final class IdempotencyOwned extends IdempotencyClaim {
  const IdempotencyOwned();
}

/// A completed attempt exists for the key. The caller must replay
/// [record] (or refuse it, when the fingerprint differs) — never apply
/// again.
final class IdempotencyReplay extends IdempotencyClaim {
  final IdempotencyRecord record;

  const IdempotencyReplay(this.record);
}

/// Another attempt with the same key is still in flight. Await [settled]
/// and replay the record — or, when it completes with `null` (the owner
/// aborted), claim once more and become the owner.
final class IdempotencyWait extends IdempotencyClaim {
  final Future<IdempotencyRecord?> settled;

  const IdempotencyWait(this.settled);
}

/// One stored attempt.
final class IdempotencyRecord {
  /// The SHA-256 fingerprint of the request (`cellId`, function,
  /// positional, named, `lastSeenSeq`). A different body on the same key
  /// is `idempotency_conflict`.
  final String fingerprint;

  /// The pulse type the stored outcome was first sent under.
  final String responseType;

  /// The wire-safe outcome JSON. [liveOutcome] is same-process only;
  /// this map is what a later file or SQL store is allowed to persist.
  final Map<String, Object?> outcomeJson;

  /// When the attempt completed (the store's clock at `complete` time).
  final DateTime storedAt;

  /// The live outcome, for `SkinClient.apply` callers in this process.
  final ApplyOutcome<Object?>? liveOutcome;

  /// When non-null, the stored attempt **failed after the state was
  /// committed** (a strict-receipt violation): replays echo this
  /// [WireError] code and message instead of an outcome, and never
  /// re-apply. A failed record still has the original request's
  /// fingerprint — a different body on the same key is still
  /// `idempotency_conflict`.
  final String? failureCode;

  /// The wire error message for [failureCode].
  final String? failureMessage;

  const IdempotencyRecord({
    required this.fingerprint,
    required this.responseType,
    required this.outcomeJson,
    required this.storedAt,
    this.liveOutcome,
    this.failureCode,
    this.failureMessage,
  });
}

/// The idempotency seam the router consults once per apply.
///
/// ### When to use
/// Implement a durable store (file, SQL) when a retry must survive a
/// process restart. The default [MemoryIdempotencyStore] replays only
/// within this process and its TTL.
///
/// ### How it works
/// [claim] is atomic per implementation: it either hands the key to the
/// caller ([IdempotencyOwned]), replays a completed record
/// ([IdempotencyReplay]), or makes the caller wait for an in-flight
/// owner ([IdempotencyWait]). [complete] stores a record and releases
/// waiters; [abort] releases waiters with `null` so one of them can
/// claim again.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is retry memory, not the audit ledger.
/// **When to use:** a requirement says "retry the same attempt" across
/// restarts, or "one logical call must never run twice".
/// **When NOT to use:** storing domain history — records belong to the
/// domain ledger, never here.
/// **Live signature:** `abstract interface class IdempotencyStore { Future<IdempotencyClaim> claim(String key); Future<void> complete(String key, IdempotencyRecord record); Future<void> abort(String key); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
abstract interface class IdempotencyStore {
  Future<IdempotencyClaim> claim(String key);

  Future<void> complete(String key, IdempotencyRecord record);

  Future<void> abort(String key);
}

/// The default in-memory store.
///
/// * [maxEntries] — the cap on **completed** records (default 1024).
///   Values below 1 throw [ArgumentError]. Eviction drops the oldest
///   completed entry only; an in-flight key is never the eviction
///   victim, and expired records are swept first so they do not occupy
///   the cap.
/// * [ttl] — how long a completed record replays (default 24 hours).
///   Expiry is checked inside `claim` and `complete`; there is no timer.
/// * [clock] — the time source (default `DateTime.now`), injectable so
///   tests can move it.
///
/// Replay is **at-least-once at the edges**: past the TTL, or once the
/// oldest record is evicted from a full store, a retry with the same
/// id is a new apply. Treat the TTL and the cap as a replay window, not
/// an exactly-once guarantee.
///
/// Mutations happen synchronously inside each method, which then returns
/// `Future.value` — one isolate does not interleave halfway through
/// `claim`. The store is single-isolate; a shared multi-isolate
/// implementation has to make `claim` atomic itself.
final class MemoryIdempotencyStore implements IdempotencyStore {
  final int maxEntries;
  final Duration ttl;
  final DateTime Function() clock;

  final Map<String, IdempotencyRecord> _completed = {};
  final Map<String, Completer<IdempotencyRecord?>> _inflight = {};

  MemoryIdempotencyStore({
    this.maxEntries = 1024,
    this.ttl = const Duration(hours: 24),
    this.clock = DateTime.now,
  }) {
    if (maxEntries < 1) {
      throw ArgumentError.value(
          maxEntries, 'maxEntries', 'must be at least 1');
    }
  }

  @override
  Future<IdempotencyClaim> claim(String key) {
    _sweepExpired();
    final pending = _inflight[key];
    if (pending != null) return Future.value(IdempotencyWait(pending.future));
    final completed = _completed[key];
    if (completed != null) return Future.value(IdempotencyReplay(completed));
    _inflight[key] = Completer<IdempotencyRecord?>();
    return Future.value(const IdempotencyOwned());
  }

  @override
  Future<void> complete(String key, IdempotencyRecord record) {
    _sweepExpired();
    final pending = _inflight.remove(key);
    if (_completed.length >= maxEntries && !_completed.containsKey(key)) {
      _evictOldestCompleted();
    }
    _completed[key] = record;
    if (pending != null && !pending.isCompleted) {
      pending.complete(record);
    }
    return Future.value();
  }

  @override
  Future<void> abort(String key) {
    final pending = _inflight.remove(key);
    if (pending != null && !pending.isCompleted) {
      pending.complete(null);
    }
    return Future.value();
  }

  void _sweepExpired() {
    final now = clock();
    _completed.removeWhere(
        (key, record) => !now.isBefore(record.storedAt.add(ttl)));
  }

  void _evictOldestCompleted() {
    String? oldestKey;
    DateTime? oldestAt;
    _completed.forEach((key, record) {
      if (oldestAt == null || record.storedAt.isBefore(oldestAt!)) {
        oldestAt = record.storedAt;
        oldestKey = key;
      }
    });
    if (oldestKey != null) _completed.remove(oldestKey);
  }
}

/// The store key for a caller id: actor-scoped, so `alice` and `bob` do
/// not share keys even when they reuse the same client id.
///
/// [actor] is the request pulse's `actor` when it is non-empty, `null`
/// otherwise (scope `''`). Scope by actor only — never by roles; a role
/// change between retries is still the same attempt.
String idempotencyStoreKey({required String? actor, required String id}) =>
    fingerprint([actor ?? '', id]);

/// The SHA-256 fingerprint of the exact request. Canonical JSON sorts
/// keys, so argument order does not matter; `null` and an omitted
/// argument map hash the same (both become `{}`), and `lastSeenSeq` is
/// part of the object so a missing cursor and an explicit null match
/// while a different cursor does not.
///
/// Throws when an argument is not JSON-encodable; the router turns that
/// into `bad_arguments` before any claim.
String idempotencyFingerprint(WireRequest request) => fingerprint({
      'cellId': request.cellId,
      'function': request.function,
      'positional': request.positional ?? const <String, Object?>{},
      'named': request.named ?? const <String, Object?>{},
      'lastSeenSeq': request.lastSeenSeq,
    });
