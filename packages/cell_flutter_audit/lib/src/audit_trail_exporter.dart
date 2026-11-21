// JSON and CSV exporters for `ApplyReceipt` lists.
//
// Pure string utilities — no `dart:io` — so they work on every Flutter
// platform. File export lives in `package:cell_flutter_audit/io.dart`
// ([AuditTrailFileExporter]).
library;

import 'dart:convert';

import 'package:cell/cell.dart';

import 'audit_entry.dart';

/// The formats [AuditTrailFileExporter] can write.
enum ExportFormat { json, csv }

/// Exports receipts to JSON or CSV text.
class AuditTrailExporter {
  /// Serializes [receipts] to an indented JSON array, one object per
  /// receipt:
  ///
  /// ```json
  /// [
  ///   {
  ///     "id": "a1b2c3d4-0",
  ///     "function": "addCounter",
  ///     "arguments": {"positional": [5], "named": null},
  ///     "timestamp": "2026-04-15T10:30:15.234Z",
  ///     "vetted": true,
  ///     "txSequence": null
  ///   }
  /// ]
  /// ```
  static String toJson(List<ApplyReceipt> receipts) {
    final list = receipts.map((r) => {
          'id': r.id,
          'function': functionDisplayName(r.function),
          'arguments': {
            'positional': r.arguments.positionalArguments,
            'named': r.arguments.namedArguments == null
                ? null
                : {
                    for (final e in r.arguments.namedArguments!.entries)
                      _symbolName(e.key): e.value,
                  },
          },
          'timestamp': r.timestamp.toIso8601String(),
          'vetted': r.vetted,
          'txSequence': r.txSequence,
        }).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// Serializes [receipts] to CSV: a header row plus one row per receipt.
  /// Arguments are JSON-encoded into a single column, and commas, quotes,
  /// and newlines are escaped per RFC 4180.
  static String toCsv(List<ApplyReceipt> receipts) {
    final buffer = StringBuffer();
    buffer.writeln('id,function,arguments,timestamp,vetted,txSequence');
    for (final r in receipts) {
      final args = jsonEncode({
        'positional': r.arguments.positionalArguments,
        'named': r.arguments.namedArguments == null
            ? null
            : {
                for (final e in r.arguments.namedArguments!.entries)
                  _symbolName(e.key): e.value,
              },
      });
      buffer.writeln([
        _csvCell(r.id),
        _csvCell(functionDisplayName(r.function)),
        _csvCell(args),
        _csvCell(r.timestamp.toIso8601String()),
        _csvCell('${r.vetted}'),
        _csvCell(r.txSequence?.toString() ?? ''),
      ].join(','));
    }
    return buffer.toString();
  }

  static String _csvCell(String value) {
    if (!value.contains(RegExp(r'[",\n\r]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  static String _symbolName(Symbol symbol) {
    final text = symbol.toString();
    return text.startsWith('Symbol("')
        ? text.substring(8, text.length - 2)
        : text;
  }
}
