// The display model for a single `ApplyReceipt`.
//
// [AuditEntry] decouples the widgets from the core `cell` types: if the
// receipt shape ever changes, only [AuditEntry.fromReceipt] (and the
// exporter) need updating.
library;

import 'package:cell/cell.dart';

/// A display-friendly view of one [ApplyReceipt].
class AuditEntry {
  /// Extracts the display fields from [receipt].
  AuditEntry.fromReceipt(this.receipt)
      : commandName = functionDisplayName(receipt.function),
        displayId = truncateId(receipt.id),
        formattedArgs = formatArguments(receipt.arguments);

  /// The original forensic receipt.
  final ApplyReceipt receipt;

  /// The command's function name (e.g. `addTodo`), derived from
  /// [ApplyReceipt.function].
  final String commandName;

  /// The receipt id truncated to its first 8 characters. The full id is
  /// available through [fullId].
  final String displayId;

  /// A compact, human-readable rendering of the arguments, or `null`
  /// when the command carried no arguments.
  final String? formattedArgs;

  /// Whether the receipt passed the capability-manifest check.
  bool get isVetted => receipt.vetted;

  /// When the command was executed.
  DateTime get timestamp => receipt.timestamp;

  /// The transaction sequence number, if the command was staged through
  /// `Cell.txApply`.
  int? get txSequence => receipt.txSequence;

  /// The untruncated receipt id.
  String get fullId => receipt.id;

  /// The full receipt id, shown in expanded payload views.
  String get fullIdLine => 'id: ${receipt.id}';

  @override
  String toString() =>
      'AuditEntry($commandName, $displayId, vetted: $isVetted)';
}

/// Formats [timestamp] as `HH:mm:ss.SSS` (local time).
String formatAuditTimestamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  String three(int n) => n.toString().padLeft(3, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}'
      '.${three(local.millisecond)}';
}

/// A best-effort, reflection-free display name for a command function.
///
/// Tear-offs of named methods/functions are reported by `toString()` as
/// `Closure: (...) => … from Function 'name': …`; the name is extracted
/// from that (and a leading `_` plus any VM identity suffix such as
/// `@20510797` are stripped). Anonymous closures fall back to the runtime
/// type.
String functionDisplayName(Function function) {
  final text = function.toString();
  final fromFunction = RegExp(r"from Function '([^']+)'").firstMatch(text);
  if (fromFunction != null) {
    return _cleanName(fromFunction.group(1)!);
  }
  final namedClosure = RegExp(r"Closure '([^']+)'").firstMatch(text);
  if (namedClosure != null) {
    return _cleanName(namedClosure.group(1)!);
  }
  return function.runtimeType.toString();
}

String _cleanName(String name) =>
    name.replaceFirst(RegExp(r'^_+'), '').replaceFirst(RegExp(r'@\d+$'), '');

/// Truncates a receipt id to its first [length] characters.
String truncateId(String id, {int length = 8}) =>
    id.length <= length ? id : id.substring(0, length);

/// Renders [arguments] as a compact string:
///
/// * positional only → `[1, "two"]`
/// * named only → `{delta: 5}`
/// * both → `pos [1] named {a: 2}`
/// * neither → `null`
String? formatArguments(ApplyArguments arguments) {
  final positional = arguments.positionalArguments;
  final named = arguments.namedArguments;
  final parts = <String>[];
  if (positional != null) {
    parts.add(positional.map(_display).toList().toString());
  }
  if (named != null) {
    final pairs = named.entries
        .map((e) => '${_symbolName(e.key)}: ${_display(e.value)}')
        .join(', ');
    parts.add('{$pairs}');
  }
  if (parts.isEmpty) return null;
  return parts.join(' ');
}

/// A short human-readable form of one argument value (strings are quoted,
/// symbols are named, everything else uses `toString()`).
String _display(Object? value) {
  if (value is String) return '"$value"';
  if (value is Symbol) return _symbolName(value);
  return '$value';
}

String _symbolName(Symbol symbol) {
  final text = symbol.toString();
  return text.startsWith('Symbol("')
      ? text.substring(8, text.length - 2)
      : text;
}
