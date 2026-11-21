// The client-side data model for the ledger.
//
// Parses the wire contract produced by `cell_flutter_devtools`
// (`serializeReceipt` / `serializeRejection`).
library;

/// One receipt row as received from `ext.cell.getLedger`.
class DevtoolsLedgerEntry {
  DevtoolsLedgerEntry({
    required this.id,
    required this.functionName,
    required this.timestamp,
    required this.vetted,
    this.txSequence,
    this.arguments,
    Map<String, dynamic>? raw,
  }) : raw = raw ?? {};

  /// Parses one serialized receipt.
  factory DevtoolsLedgerEntry.fromJson(Map<String, dynamic> json) =>
      DevtoolsLedgerEntry(
        id: json['id'] as String,
        functionName: json['function'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        vetted: json['vetted'] as bool,
        txSequence: json['txSequence'] as int?,
        arguments:
            (json['arguments'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
        raw: json,
      );

  final String id;
  final String functionName;
  final DateTime timestamp;
  final bool vetted;
  final int? txSequence;
  final Map<String, dynamic>? arguments;

  /// The unmodified wire JSON, shown when a row is expanded.
  final Map<String, dynamic> raw;

  /// The receipt id truncated to its first 8 characters.
  String get displayId => id.length <= 8 ? id : id.substring(0, 8);
}

/// One denial row as received from `ext.cell.getLedger`.
class DevtoolsRejectionEntry {
  DevtoolsRejectionEntry({
    required this.id,
    required this.functionName,
    required this.timestamp,
    this.reason,
  });

  /// Parses one serialized rejection.
  factory DevtoolsRejectionEntry.fromJson(Map<String, dynamic> json) =>
      DevtoolsRejectionEntry(
        id: json['id'] as String,
        functionName: json['function'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        reason: json['reason'] as String?,
      );

  final String id;
  final String functionName;
  final DateTime timestamp;
  final String? reason;
}

/// One poll response.
class DevtoolsLedgerSnapshot {
  DevtoolsLedgerSnapshot({required this.entries, required this.rejections});

  final List<DevtoolsLedgerEntry> entries;
  final List<DevtoolsRejectionEntry> rejections;
}

/// Formats a timestamp as `HH:mm:ss.SSS` in local time.
String formatTimestamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  String three(int n) => n.toString().padLeft(3, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}'
      '.${three(local.millisecond)}';
}

/// A compact rendering of the argument payload.
String formatArguments(Map<String, dynamic>? arguments) {
  if (arguments == null) return '';
  final positional = arguments['positional'];
  final named = arguments['named'];
  final parts = <String>[];
  if (positional is List && positional.isNotEmpty) parts.add('$positional');
  if (named is Map && named.isNotEmpty) {
    parts.add(named.entries.map((e) => '${e.key}: ${e.value}').join(', '));
  }
  return parts.join(' ');
}
