import 'package:cell/cell.dart';
import 'package:test/test.dart';

/// A store wrapper that returns tampered entries from [entriesSince].
///
/// This is the attack the exit criterion models: `InMemoryLedgerStore`'s
/// entries are private, so tampering must go through a store — exactly
/// what `Ledger.verify` reads from.
class _TamperedStore implements LedgerStore {
  final LedgerStore inner;
  final int tamperSeq;
  final LedgerEntry Function(LedgerEntry) tamper;

  _TamperedStore(this.inner, this.tamperSeq, this.tamper);

  @override
  String get genesisHash => inner.genesisHash;

  @override
  Future<void> append(LedgerEntry entry) => inner.append(entry);

  @override
  Future<int> get lastSeq => inner.lastSeq;

  @override
  Future<String?> get lastHash => inner.lastHash;

  @override
  Stream<LedgerEntry> entriesSince(int fromSeq) async* {
    await for (final entry in inner.entriesSince(fromSeq)) {
      if (entry.seq == tamperSeq) {
        yield tamper(entry);
      } else {
        yield entry;
      }
    }
  }

  @override
  Future<void> close() => inner.close();
}

/// A store wrapper that drops one entry, producing a sequence gap.
class _GapStore implements LedgerStore {
  final LedgerStore inner;
  final int skipSeq;

  _GapStore(this.inner, {required this.skipSeq});

  @override
  String get genesisHash => inner.genesisHash;

  @override
  Future<void> append(LedgerEntry entry) => inner.append(entry);

  @override
  Future<int> get lastSeq => inner.lastSeq;

  @override
  Future<String?> get lastHash => inner.lastHash;

  @override
  Stream<LedgerEntry> entriesSince(int fromSeq) async* {
    await for (final entry in inner.entriesSince(fromSeq)) {
      if (entry.seq == skipSeq) continue;
      yield entry;
    }
  }

  @override
  Future<void> close() => inner.close();
}

/// Rebuilds an entry with one JSON field changed — the tamper surface a
/// file or network store exposes.
LedgerEntry _tamper(LedgerEntry original, void Function(Map json) mutate) {
  final json = original.toJson();
  mutate(json);
  return LedgerEntry.fromJson(json.cast<String, Object?>());
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  Future<(Ledger, InMemoryLedgerStore)> buildFiveEntryLedger() async {
    final counter = Cell.state<int>(initial: 0);
    final graph = (CellGraph.builder()..registerState('c', counter)).build();
    final store = InMemoryLedgerStore(
      genesisHash: Ledger.genesisHashOf(graph.id),
    );
    final ledger = await graph.bindLedger(store: store);
    await graph.run(() async {
      for (var i = 1; i <= 5; i++) {
        counter.update(i);
      }
    });
    return (ledger, store);
  }

  test('tampering one delta fails verify with the offending seq', () async {
    final (ledger, store) = await buildFiveEntryLedger();
    final original = await store.entriesSince(3).first;
    final tampered = _tamper(original, (json) {
      final deltas = (json['deltas'] as List).cast<Map>();
      (deltas.single)['after'] = 99999;
    });

    final probe = await Ledger.open(
      graph: ledger.graph,
      store: _TamperedStore(store, 3, (_) => tampered),
    );

    try {
      await probe.verify();
      fail('verify() should have thrown');
    } on LedgerIntegrityException catch (e) {
      expect(e.seq, 3);
      expect(e.reason, contains('hash mismatch'));
    }
    await ledger.close();
  });

  test('tampering a prevHash breaks the chain at that seq', () async {
    final (ledger, store) = await buildFiveEntryLedger();
    final original = await store.entriesSince(2).first;
    final tampered = _tamper(original, (json) {
      json['prevHash'] = 'deadbeef';
    });

    final probe = await Ledger.open(
      graph: ledger.graph,
      store: _TamperedStore(store, 2, (_) => tampered),
    );

    try {
      await probe.verify();
      fail('verify() should have thrown');
    } on LedgerIntegrityException catch (e) {
      expect(e.seq, 2);
      expect(e.reason, contains('prevHash mismatch'));
    }
    await ledger.close();
  });

  test('a sequence gap fails verify at the offending seq', () async {
    final (ledger, store) = await buildFiveEntryLedger();
    // Drop entry 3: entries 0..2 then 4.. → gap detected at 4.
    final probe = await Ledger.open(
      graph: ledger.graph,
      store: _GapStore(store, skipSeq: 3),
    );

    try {
      await probe.verify();
      fail('verify() should have thrown');
    } on LedgerIntegrityException catch (e) {
      expect(e.seq, 4);
      expect(e.reason, contains('sequence gap'));
    }
    await ledger.close();
  });
}
