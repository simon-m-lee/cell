// A rejected command, wrapped for display.
//
// `ApplyLedger` only records accepted receipts; a denied command produces
// an [ApplyRejected] outcome instead. Wrap that outcome in a
// [RejectionEvent] (or let [AuditTrailController.addOutcome] do it) and
// [AuditTrailView] renders it as a red-bordered card alongside the
// accepted timeline.
library;

import 'package:cell/cell.dart';

import 'audit_entry.dart';

/// The display model for one denied command.
class RejectionEvent {
  /// Wraps [receipt] and an optional [reason].
  RejectionEvent({required this.receipt, this.reason, DateTime? timestamp})
      : timestamp = timestamp ?? receipt.timestamp;

  /// Builds the wrapper from an [ApplyRejected] outcome.
  factory RejectionEvent.fromOutcome(ApplyRejected<Object?> outcome) =>
      RejectionEvent(receipt: outcome.receipt, reason: outcome.reason);

  /// The denial receipt the framework minted for the attempt.
  final ApplyReceipt receipt;

  /// The gate's reason, if one was supplied.
  final Object? reason;

  /// When the denial happened.
  final DateTime timestamp;

  /// The display name of the denied command.
  String get commandName => functionDisplayName(receipt.function);

  @override
  String toString() => 'RejectionEvent($commandName, reason: $reason)';
}
