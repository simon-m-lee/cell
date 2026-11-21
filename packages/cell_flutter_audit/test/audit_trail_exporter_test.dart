// AuditTrailExporter JSON/CSV/file tests.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cell_flutter_audit/cell_flutter_audit.dart';
import 'package:cell_flutter_audit/io.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final receipts = [
    testReceipt(addCounter, positional: [5]),
    testReceipt(toggleTodo, positional: ['done, "quoted"\nnext'], txSequence: 4),
  ];

  group('toJson', () {
    test('produces a valid JSON array with the documented shape', () {
      final json = AuditTrailExporter.toJson(receipts);
      final decoded = jsonDecode(json) as List<dynamic>;
      expect(decoded, hasLength(2));
      final first = decoded.first as Map<String, dynamic>;
      expect(first.keys.toSet(), {
        'id',
        'function',
        'arguments',
        'timestamp',
        'vetted',
        'txSequence',
      });
      expect(first['function'], 'addCounter');
      expect((first['arguments'] as Map<String, dynamic>)['positional'], [5]);
      expect((first['arguments'] as Map<String, dynamic>)['named'], isNull);
      expect(first['vetted'], isTrue);
      expect(first['txSequence'], isNull);

      final second = decoded.last as Map<String, dynamic>;
      expect(second['txSequence'], 4);
      expect(second['timestamp'], receipts.last.timestamp.toIso8601String());
    });

    test('serializes named arguments with symbol keys as strings', () {
      final json = AuditTrailExporter.toJson([
        testReceipt(addCounter, named: {#delta: 7}),
      ]);
      final decoded = jsonDecode(json) as List<dynamic>;
      final named =
          (decoded.first as Map<String, dynamic>)['arguments']
              as Map<String, dynamic>;
      expect(named['named'], {'delta': 7});
    });
  });

  group('toCsv', () {
    test('starts with the header and has one row per receipt', () {
      final csv = AuditTrailExporter.toCsv(receipts);
      final lines = csv.trim().split('\n');
      expect(lines.first, 'id,function,arguments,timestamp,vetted,txSequence');
      expect(lines, hasLength(3));
    });

    test('escapes commas, quotes, and newlines in arguments', () {
      final csv = AuditTrailExporter.toCsv(receipts);
      final row = csv.trim().split('\n').last;
      // The arguments cell is quoted and inner quotes are doubled.
      expect(row, contains('""done, '));
      expect(row, contains('quoted'));
      expect(row, contains(r'\nnext'));
      // txSequence appears at the row's end.
      expect(row, endsWith(',4'));
    });
  });

  group('AuditTrailFileExporter', () {
    test('exportToFile writes JSON and CSV files', () async {
      final dir = await Directory.systemTemp.createTemp('cell_audit_test');
      addTearDown(() => dir.delete(recursive: true));

      final jsonFile = await AuditTrailFileExporter.exportToFile(
        receipts,
        path: '${dir.path}/audit.json',
      );
      expect(jsonFile.existsSync(), isTrue);
      expect(
        (jsonDecode(await jsonFile.readAsString()) as List<dynamic>),
        hasLength(2),
      );

      final csvFile = await AuditTrailFileExporter.exportToFile(
        receipts,
        path: '${dir.path}/audit.csv',
        format: ExportFormat.csv,
      );
      expect(csvFile.existsSync(), isTrue);
      expect((await csvFile.readAsString()).trim().split('\n'), hasLength(3));
    });
  });
}
