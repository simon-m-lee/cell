// The VM-service extension that exposes the Cell ledger to DevTools.
library;

import 'dart:convert';
import 'dart:developer';

import 'package:cell/cell.dart';

/// The service extension method name the DevTools UI calls.
const String cellGetLedgerExtension = 'ext.cell.getLedger';

/// A denied command, reported alongside the ledger when the app records
/// rejections separately.
class CellDevtoolsRejection {
  /// Wraps a denial receipt and an optional gate reason.
  const CellDevtoolsRejection({required this.receipt, this.reason});

  /// The receipt the framework minted for the denied attempt.
  final ApplyReceipt receipt;

  /// The gate's reason, if one was supplied.
  final Object? reason;
}

/// Serializes one [ApplyReceipt] for the DevTools UI.
///
/// The shape is the extension's wire contract — the extension web app's
/// `LedgerEntry.fromJson` parses exactly these fields.
Map<String, Object?> serializeReceipt(ApplyReceipt receipt) => {
      'id': receipt.id,
      'function': _functionName(receipt.function),
      'arguments': {
        'positional': receipt.arguments.positionalArguments,
        'named': receipt.arguments.namedArguments?.map(
          (k, v) => MapEntry(_symbolName(k), v),
        ),
      },
      'timestamp': receipt.timestamp.toIso8601String(),
      'vetted': receipt.vetted,
      'txSequence': receipt.txSequence,
    };

/// Serializes one [CellDevtoolsRejection] for the DevTools UI.
Map<String, Object?> serializeRejection(CellDevtoolsRejection rejection) => {
      'id': rejection.receipt.id,
      'function': _functionName(rejection.receipt.function),
      'arguments': {
        'positional': rejection.receipt.arguments.positionalArguments,
        'named': rejection.receipt.arguments.namedArguments?.map(
          (k, v) => MapEntry(_symbolName(k), v),
        ),
      },
      'timestamp': rejection.receipt.timestamp.toIso8601String(),
      'vetted': rejection.receipt.vetted,
      'txSequence': rejection.receipt.txSequence,
      'reason': rejection.reason?.toString(),
    };

/// Builds the payload returned by `ext.cell.getLedger`.
///
/// A thrown provider is converted into an `{'error': …}` payload, which
/// the registration turns into a `ServiceExtensionResponse.error`.
Map<String, Object?> buildCellLedgerResponse({
  required List<ApplyReceipt> Function() receipts,
  List<CellDevtoolsRejection> Function()? rejections,
}) {
  try {
    final serializedReceipts = receipts().map(serializeReceipt).toList();
    final serializedRejections =
        (rejections?.call() ?? const <CellDevtoolsRejection>[])
            .map(serializeRejection)
            .toList();
    return {
      'receipts': serializedReceipts,
      'rejections': serializedRejections,
    };
  } catch (error, stackTrace) {
    return {
      'error': '$error',
      'stackTrace': '$stackTrace',
    };
  }
}

/// Registers `ext.cell.getLedger` on the VM service (debug/profile only).
///
/// The registration is wrapped in `assert`, so the tree shaker removes it
/// — and the [receipts] closure — from release builds. Safe to call
/// unconditionally in `main()`.
void registerCellDevTools({
  required List<ApplyReceipt> Function() receipts,
  List<CellDevtoolsRejection> Function()? rejections,
}) {
  assert(() {
    registerExtension(cellGetLedgerExtension, (method, parameters) async {
      final payload = buildCellLedgerResponse(
        receipts: receipts,
        rejections: rejections,
      );
      if (payload.containsKey('error')) {
        return ServiceExtensionResponse.error(
          ServiceExtensionResponse.extensionError,
          payload['error']! as String,
        );
      }
      return ServiceExtensionResponse.result(jsonEncode(payload));
    });
    return true;
  }());
}

/// A best-effort, reflection-free display name for a command function
/// (leading `_` and any VM identity suffix such as `@20510797` stripped).
String _functionName(Function function) {
  final text = function.toString();
  final fromFunction = RegExp(r"from Function '([^']+)'").firstMatch(text);
  if (fromFunction != null) return _cleanName(fromFunction.group(1)!);
  final namedClosure = RegExp(r"Closure '([^']+)'").firstMatch(text);
  if (namedClosure != null) return _cleanName(namedClosure.group(1)!);
  return function.runtimeType.toString();
}

String _cleanName(String name) =>
    name.replaceFirst(RegExp(r'^_+'), '').replaceFirst(RegExp(r'@\d+$'), '');

String _symbolName(Symbol symbol) {
  final text = symbol.toString();
  return text.startsWith('Symbol("')
      ? text.substring(8, text.length - 2)
      : text;
}
