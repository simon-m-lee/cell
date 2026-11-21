// AuditEntry display-model extraction tests.
library;

import 'package:cell_flutter_audit/cell_flutter_audit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('AuditEntry.fromReceipt', () {
    test('extracts the command name from a named function', () {
      final entry = AuditEntry.fromReceipt(testReceipt(addCounter, positional: [5]));
      expect(entry.commandName, 'addCounter');
    });

    test('truncates the id to 8 characters and keeps the full id', () {
      final entry = AuditEntry.fromReceipt(testReceipt(addCounter));
      expect(entry.displayId.length, 8);
      expect(entry.fullId, entry.receipt.id);
      expect(entry.fullId.length, greaterThan(8));
    });

    test('formats positional, named, and combined arguments', () {
      final positional =
          AuditEntry.fromReceipt(testReceipt(addCounter, positional: [5, 'x']));
      expect(positional.formattedArgs, '[5, "x"]');

      final named = AuditEntry.fromReceipt(
        testReceipt(addCounter, named: {#delta: 5}),
      );
      expect(named.formattedArgs, '{delta: 5}');

      final both = AuditEntry.fromReceipt(testReceipt(
        addCounter,
        positional: [1],
        named: {#delta: 2},
      ));
      expect(both.formattedArgs, '[1] {delta: 2}');

      final none = AuditEntry.fromReceipt(testReceipt(toggleTodo));
      expect(none.formattedArgs, isNull);
    });

    test('copies vetted, timestamp, and txSequence from the receipt', () {
      final at = DateTime.utc(2026, 4, 15, 10, 30, 15, 234);
      final vetted = AuditEntry.fromReceipt(
        testReceipt(addCounter, positional: [1], txSequence: 7, timestamp: at),
      );
      expect(vetted.isVetted, isTrue);
      expect(vetted.timestamp, at);
      expect(vetted.txSequence, 7);

      final unvetted = AuditEntry.fromReceipt(
        testReceipt(addCounter, vetted: false),
      );
      expect(unvetted.isVetted, isFalse);
    });
  });

  group('formatAuditTimestamp', () {
    test('renders HH:mm:ss.SSS in local time', () {
      final local = DateTime(2026, 4, 15, 10, 30, 15, 234);
      expect(formatAuditTimestamp(local), '10:30:15.234');
    });

    test('zero-pads short fields', () {
      final local = DateTime(2026, 4, 15, 1, 2, 3, 4);
      expect(formatAuditTimestamp(local), '01:02:03.004');
    });
  });

  test('functionDisplayName falls back for anonymous closures', () {
    int anon(int x) => x;
    final name = functionDisplayName(anon);
    expect(name, isNotEmpty);
  });
}
