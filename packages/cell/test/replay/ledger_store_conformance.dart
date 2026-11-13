// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:test/test.dart';

/// The conformance suite for [LedgerStore] implementations.
///
/// A new store is "correct" iff it passes every test below. The suite
/// exercises every method, every error path, and every edge case the
/// framework's own stores are known to handle. It is deliberately
/// strict: a store that "works in most cases" does not pass, because
/// the ledger's guarantees are the whole point.
///
/// ### How to use
///
/// ```dart
/// void main() {
///   runLedgerStoreConformance(
///     'InMemoryLedgerStore',
///     () => InMemoryLedgerStore(genesisHash: 'test-genesis'),
///   );
/// }
/// ```
///
/// Pass `isDurable: true` for stores that survive a reopen (files,
/// databases, buckets). `InMemoryLedgerStore` cannot pass the reopen
/// test because there is nothing to reopen.
///
/// ### Non-obvious: [open] is called once per test, plus once more for
/// the durable reopen test
///
/// A durable store's factory must return a store for the *same*
/// underlying data on every call within one test (a fixed file path, a
/// fixed table). Pass [fresh] to allocate a *new* underlying resource
/// at the start of each test; the conformance suite calls it before
/// every test body. For file stores, [fresh] typically points the
/// shared path at a fresh per-test file name.
void runLedgerStoreConformance(
  String suiteName,
  FutureOr<LedgerStore> Function() open, {
  bool isDurable = false,
  void Function()? fresh,
}) {
  group('$suiteName conformance', () {
    test('append and lastSeq', () async {
      fresh?.call();
      final store = await open();
      expect(await store.lastSeq, -1);
      expect(await store.lastHash, isNull);
      await store.append(_makeEntry(seq: 0, prevHash: 'test-genesis'));
      expect(await store.lastSeq, 0);
      expect(await store.lastHash, isNotNull);
      await store.append(
        _makeEntry(seq: 1, prevHash: (await store.lastHash)!),
      );
      expect(await store.lastSeq, 1);
      await store.close();
    });

    test('rejects out-of-order seq', () async {
      fresh?.call();
      final store = await open();
      await store.append(_makeEntry(seq: 0, prevHash: 'test-genesis'));
      try {
        await expectLater(
          store.append(_makeEntry(seq: 2, prevHash: 'wrong')),
          throwsA(isA<StateError>()),
        );
      } finally {
        await store.close();
      }
    });

    test('rejects genesis prevHash mismatch', () async {
      fresh?.call();
      final store = await open();
      try {
        await expectLater(
          store.append(_makeEntry(seq: 0, prevHash: 'wrong')),
          throwsA(isA<StateError>()),
        );
      } finally {
        await store.close();
      }
    });

    test('entriesSince yields in seq order', () async {
      fresh?.call();
      final store = await open();
      var prevHash = 'test-genesis';
      for (var i = 0; i < 5; i++) {
        final e = _makeEntry(seq: i, prevHash: prevHash);
        await store.append(e);
        prevHash = e.hash;
      }
      final entries = await store.entriesSince(0).toList();
      expect(entries.map((e) => e.seq), [0, 1, 2, 3, 4]);
      final sub = await store.entriesSince(2).toList();
      expect(sub.map((e) => e.seq), [2, 3, 4]);
      await store.close();
    });

    test('close prevents further append', () async {
      fresh?.call();
      final store = await open();
      await store.close();
      await expectLater(
        store.append(_makeEntry(seq: 0, prevHash: 'test-genesis')),
        throwsA(isA<StateError>()),
      );
    });

    if (isDurable) {
      test('survives reopen (durable only)', () async {
        fresh?.call();
        final store1 = await open();
        await store1.append(_makeEntry(seq: 0, prevHash: 'test-genesis'));
        await store1.close();

        final store2 = await open();
        expect(await store2.lastSeq, 0);
        await store2.close();
      });
    }
  });
}

LedgerEntry _makeEntry({required int seq, required String prevHash}) {
  final receipt = (
    id: 'receipt-$seq',
    cell: _StubCell('c'),
    function: _stubFunction,
    arguments: (positionalArguments: <Object?>[seq], namedArguments: null),
    timestamp: DateTime.fromMillisecondsSinceEpoch(1000000 + seq),
    txSequence: null,
    vetted: true,
    ledgerSeq: seq,
    pulseDigest: 'digest-$seq',
    receptorVersion: '1.0.0',
    ruleVersion: '1.0.0',
    contextVersion: '1.0.0',
  );
  final at = DateTime.fromMillisecondsSinceEpoch(1000000 + seq);
  final effectsDigest = fingerprint(const <Object?>[]);
  final deltaDigest = fingerprint(const <Object?>[]);
  final hash = HashChain('test-genesis').nextHash(
    prevHash: prevHash,
    seq: seq,
    pulseDigest: 'digest-$seq',
    receiptDigest: fingerprint({
      'id': receipt.id,
      'cell': 'c',
      'function': 'Stub',
      'timestamp': receipt.timestamp.toUtc().toIso8601String(),
      'vetted': true,
    }),
    effectsDigest: effectsDigest,
    deltaDigest: deltaDigest,
    at: at,
  );
  return LedgerEntry(
    seq: seq,
    prevHash: prevHash,
    hash: hash,
    pulseDigest: 'digest-$seq',
    receipt: receipt,
    effects: const [],
    deltas: const [],
    at: at,
  );
}

class _StubCell extends CellBase {
  final String _id;
  _StubCell(this._id) : super.fromNucleus(Nucleus.empty());
  @override
  String get id => _id;
}

/// Dart forbids implementing `Function`, so a top-level tear-off is the
/// only honest stub (the same marker trick `ForkLedgerStore` uses for
/// its synthetic entry).
Object? _stubFunction(Object? _) => null;
