// Shared test helpers: mint realistic receipts through the public API.
library;

import 'package:cell/cell.dart';

/// A host cell for the receipt minting utility.
final ValueCell<int> testHost = Cell.state<int>(initial: 0).cell;

/// Command functions with stable, extractable names.
void addCounter(int delta) {}

void toggleTodo() {}

/// Builds an [ApplyCommand] for tests.
ApplyCommand testCommand(
  Function function, {
  List<Object?>? positional,
  Map<Symbol, Object?>? named,
}) =>
    (
      function: function,
      arguments: (
        positionalArguments: positional,
        namedArguments: named,
      ),
      compensation: null,
    );

/// Mints an [ApplyReceipt] with a controllable timestamp.
ApplyReceipt testReceipt(
  Function function, {
  List<Object?>? positional,
  Map<Symbol, Object?>? named,
  bool vetted = true,
  int? txSequence,
  DateTime? timestamp,
}) {
  final r = ApplyLedger.receipt(
    cell: testHost,
    command: testCommand(function, positional: positional, named: named),
    txSequence: txSequence,
    vetted: vetted,
  );
  if (timestamp == null) return r;
  return (
    id: r.id,
    cell: r.cell,
    function: r.function,
    arguments: r.arguments,
    timestamp: timestamp,
    txSequence: r.txSequence,
    vetted: r.vetted,
    ledgerSeq: r.ledgerSeq,
    pulseDigest: r.pulseDigest,
    receptorVersion: r.receptorVersion,
    ruleVersion: r.ruleVersion,
    contextVersion: r.contextVersion,
  );
}
