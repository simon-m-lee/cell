// AuditTrailController filter/search/sort/pagination tests.
library;

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:cell_flutter_audit/cell_flutter_audit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  DateTime at(int minute) => DateTime.utc(2026, 4, 15, 10, minute);

  AuditTrailController seeded() => AuditTrailController(receipts: [
        testReceipt(addCounter, positional: [5], timestamp: at(1)),
        testReceipt(toggleTodo, positional: ['write guide'], timestamp: at(2)),
        testReceipt(addCounter, positional: [9], vetted: false, timestamp: at(3)),
      ]);

  group('filterBy', () {
    test('matches command names by substring', () {
      final c = seeded();
      c.filterBy(commandName: 'add');
      expect(c.filteredEntries.map((e) => e.commandName), everyElement('addCounter'));
      expect(c.totalMatches, 2);
    });

    test('matches command names exactly when exact is set', () {
      final c = seeded();
      c.filterBy(commandName: 'add', exact: true);
      expect(c.totalMatches, 0);
      c.filterBy(commandName: 'addCounter', exact: true);
      expect(c.totalMatches, 2);
    });

    test('filters by vetted status', () {
      final c = seeded();
      c.filterBy(vetted: false);
      expect(c.totalMatches, 1);
      expect(c.filteredEntries.single.isVetted, isFalse);
    });

    test('filters by inclusive time range', () {
      final c = seeded();
      c.filterBy(after: at(2), before: at(2));
      expect(c.totalMatches, 1);
      expect(c.filteredEntries.single.commandName, 'toggleTodo');

      c.filterBy(after: at(3));
      expect(c.totalMatches, 1);
      c.clearFilters();
      expect(c.totalMatches, 3);
    });
  });

  group('search', () {
    test('matches the command name case-insensitively', () {
      final c = seeded();
      c.search('ADDC');
      expect(c.totalMatches, 2);
    });

    test('matches the formatted arguments', () {
      final c = seeded();
      c.search('write guide');
      expect(c.totalMatches, 1);
      expect(c.filteredEntries.single.commandName, 'toggleTodo');
    });

    test('an empty query clears the search', () {
      final c = seeded();
      c.search('add');
      expect(c.totalMatches, 2);
      c.search('');
      expect(c.totalMatches, 3);
    });
  });

  group('sortBy', () {
    test('timestamp descends by default and ascends on request', () {
      final c = seeded();
      c.sortBy(SortField.timestamp);
      expect(c.filteredEntries.map((e) => e.commandName).toList(),
          ['addCounter', 'toggleTodo', 'addCounter']);

      c.sortBy(SortField.timestamp, ascending: true);
      expect(c.filteredEntries.map((e) => e.commandName).toList(),
          ['addCounter', 'toggleTodo', 'addCounter']);
    });

    test('commandName orders case-insensitively', () {
      final c = seeded();
      c.sortBy(SortField.commandName, ascending: true);
      final names = c.filteredEntries.map((e) => e.commandName).toList();
      expect(names.first, 'addCounter');
      expect(names.last, 'toggleTodo');
    });

    test('vetted orders unvetted first when ascending', () {
      final c = seeded();
      c.sortBy(SortField.vetted, ascending: true);
      expect(c.filteredEntries.first.isVetted, isFalse);
      c.sortBy(SortField.vetted, ascending: false);
      expect(c.filteredEntries.first.isVetted, isTrue);
    });
  });

  group('pagination', () {
    test('loadMore grows the visible window by pageSize', () {
      final c = AuditTrailController(receipts: [
        for (var i = 0; i < 120; i++)
          testReceipt(addCounter, positional: [i], timestamp: at(0)),
      ]);
      expect(c.visibleLimit, 50);
      expect(c.filteredEntries.length, 50);
      expect(c.totalMatches, 120);
      expect(c.hasMore, isTrue);

      c.loadMore(pageSize: 50);
      expect(c.filteredEntries.length, 100);
      c.loadMore(pageSize: 50);
      expect(c.filteredEntries.length, 120);
      expect(c.hasMore, isFalse);
    });
  });

  group('ingestion', () {
    test('a receipt stream appends live receipts', () async {
      final stream = StreamController<ApplyReceipt>();
      final c = AuditTrailController(stream: stream.stream);
      stream.add(testReceipt(addCounter, positional: [1]));
      await Future<void>.delayed(Duration.zero);
      expect(c.entries.length, 1);
      await stream.close();
      c.dispose();
    });

    test('addOutcome routes accepted, staged, and rejected outcomes', () {
      final c = AuditTrailController();
      final accepted = ApplyAccepted<Object?>(
        0,
        testReceipt(addCounter, positional: [5]),
      );
      c.addOutcome(accepted);
      expect(c.entries.length, 1);
      expect(c.rejections, isEmpty);

      final stagedReceipt =
          testReceipt(toggleTodo, positional: ['x'], txSequence: 3);
      c.addOutcome(ApplyStaged(stagedReceipt));
      expect(c.entries.length, 2);
      expect(c.entries.last.txSequence, 3);

      final rejectedReceipt = testReceipt(addCounter, positional: [-20]);
      c.addOutcome(
        ApplyRejected<Object?>(rejectedReceipt, reason: 'governed'),
      );
      expect(c.entries.length, 2, reason: 'rejections never join the ledger');
      expect(c.rejections, hasLength(1));
      expect(c.rejections.single.commandName, 'addCounter');
      expect(c.rejections.single.reason, 'governed');
    });

    test('clear resets receipts, rejections, and filters', () {
      final c = seeded();
      c.addOutcome(
        ApplyRejected<Object?>(testReceipt(addCounter), reason: 'no'),
      );
      c.filterBy(vetted: false);
      c.clear();
      expect(c.entries, isEmpty);
      expect(c.rejections, isEmpty);
      expect(c.totalMatches, 0);
    });
  });
}
