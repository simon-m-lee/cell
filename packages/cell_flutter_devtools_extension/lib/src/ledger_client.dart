// The fetch path from the extension UI to the connected app (web only).
//
// [ServiceLedgerClient] calls `ext.cell.getLedger` through the VM service
// on the main isolate. This library imports `package:devtools_extensions`
// (and therefore web-only APIs), so it is only imported from `main.dart`;
// [LedgerView] receives a plain fetch closure instead.
library;

import 'dart:convert';

import 'package:cell_flutter_devtools/cell_flutter_devtools.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:vm_service/vm_service.dart' show Response;

import 'ledger_model.dart';

/// Fetches one ledger snapshot over the VM service.
class ServiceLedgerClient {
  /// Calls the `ext.cell.getLedger` service extension on the connected
  /// app's main isolate and parses the response.
  Future<DevtoolsLedgerSnapshot?> fetch() async {
    final response = await serviceManager.callServiceExtensionOnMainIsolate(
      cellGetLedgerExtension,
    );
    final data = _decode(response);
    if (data == null) return null;
    final receipts = (data['receipts'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(DevtoolsLedgerEntry.fromJson)
        .toList();
    final rejections = (data['rejections'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(DevtoolsRejectionEntry.fromJson)
        .toList();
    return DevtoolsLedgerSnapshot(entries: receipts, rejections: rejections);
  }

  Map<String, dynamic>? _decode(Response response) {
    final json = response.json;
    if (json == null) return null;
    final error = json['error'];
    if (error != null) {
      throw StateError('$error');
    }
    // The extension returns the payload JSON-encoded in `result`; the VM
    // service usually decodes it into the response json directly. Handle
    // both shapes.
    final result = json['result'];
    if (result is String) {
      return jsonDecode(result) as Map<String, dynamic>;
    }
    if (json['receipts'] is List) return json;
    return null;
  }
}
