// File export for audit receipts (dart:io platforms only).
//
// Import `package:cell_flutter_audit/io.dart` explicitly — the main
// library stays web-compatible.
library;

import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_flutter_audit/cell_flutter_audit.dart';

/// Writes receipts to a file as JSON or CSV.
class AuditTrailFileExporter {
  /// Serializes [receipts] in [format] and writes them to [path].
  ///
  /// The path is the caller's responsibility — this package never chooses
  /// a directory. Returns the written [File].
  static Future<File> exportToFile(
    List<ApplyReceipt> receipts, {
    required String path,
    ExportFormat format = ExportFormat.json,
  }) async {
    final content = switch (format) {
      ExportFormat.json => AuditTrailExporter.toJson(receipts),
      ExportFormat.csv => AuditTrailExporter.toCsv(receipts),
    };
    return File(path).writeAsString(content);
  }
}
