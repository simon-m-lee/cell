// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert';

import '../envelope.dart';
import '../id.dart';
import '../store.dart';
import '../store_lifecycle.dart';

/// A [MemoryStore] over a [Map] with one serialisation chain per id.
///
/// No disk. This is the test double the cell-behaviour tests use, and the
/// shape a replay host would use so backends cannot drift: it implements
/// the full [MemoryStore] interface, including compare-and-swap and the
/// idempotent retry.
///
/// Admission and shutdown go through the shared [StoreLifecycle]: a call
/// that entered `run` finishes even if [close] flips the flag while it is
/// queued on a per-id chain; a call that has not entered throws.
final class InMemoryMemoryStore implements MemoryStore {
  final Map<String, MemoryEnvelope> _entries = {};

  final Map<String, Future<void>> _chains = {};

  final StoreLifecycle _lifecycle = StoreLifecycle('InMemoryMemoryStore is closed');

  Future<T> _perId<T>(String id, Future<T> Function() run) {
    final previous = _chains[id] ?? Future<void>.value();
    final completer = previous.then((_) => run());
    // The chain itself must never reject or later work on the id would be
    // skipped; the returned future carries the error to the caller.
    final chain = completer.then<void>((_) {}, onError: (_) {});
    _chains[id] = chain;
    // Drop the entry once this link is the tail, so long-lived stores do
    // not grow a map entry per id touched.
    chain.whenComplete(() {
      if (identical(_chains[id], chain)) _chains.remove(id);
    });
    return completer;
  }

  /// A defensive JSON deep copy: the store must never alias caller state.
  /// Mutating the envelope a caller passed to [write], or the envelope
  /// [read] returned, cannot change history without a revision bump.
  static MemoryEnvelope _copyOf(MemoryEnvelope envelope) =>
      MemoryEnvelope.fromJson(
          jsonDecode(jsonEncode(envelope.toJson())) as Map<String, Object?>);

  @override
  Future<MemoryEnvelope?> read(String id) async {
    MemoryIdGrammar.check(id);
    return _lifecycle.run(() => _perId(id, () async {
          final stored = _entries[id];
          return stored == null ? null : _copyOf(stored);
        }));
  }

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    MemoryIdGrammar.check(envelope.id);
    return _lifecycle.run(() => _perId(envelope.id, () async {
          final existing = _entries[envelope.id];
          if (MemoryStoreCas.isIdempotentRetry(
              existing, envelope, expectedRevision)) {
            return;
          }
          final storedRevision = existing?.revision ?? 0;
          MemoryStoreCas.checkRevision(storedRevision, expectedRevision,
              stored: existing);
          MemoryStoreCas.checkGeneration(existing, envelope, expectedRevision);
          MemoryStoreCas.checkNumbering(envelope, expectedRevision);
          _entries[envelope.id] = _copyOf(envelope);
        }));
  }

  @override
  Future<void> remove(String id) async {
    MemoryIdGrammar.check(id);
    return _lifecycle.run(() => _perId(id, () async {
          _entries.remove(id);
        }));
  }

  @override
  Future<List<String>> list() async {
    final prior = _lifecycle.inflight;
    return _lifecycle.run(() async {
      // A settled snapshot: operations that entered before list() finish
      // first, so records are included or excluded as whole writes.
      await Future.wait(prior);
      return _entries.keys.toList(growable: false);
    });
  }

  @override
  Future<void> close() async => _lifecycle.close();
}
