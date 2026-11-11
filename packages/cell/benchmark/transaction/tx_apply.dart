// txApply saga overhead: commit-only vs commit-then-compensate.
// The delta between the two is the compensation machinery cost.
//
// Run: dart run benchmark/transaction/tx_apply.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

/// A cell whose apply whitelist contains the staged command functions.
/// txApply enqueues commands through `Cell.apply`, which vets the function
/// against the cell's `modifiable` manifest.
class BenchCell extends CellBase {
  BenchCell({this.failAt});

  /// When the value reaches this level, `bump` throws to force a rollback.
  final int? failAt;
  int value = 0;

  int bump(int _) {
    if (failAt != null && value == failAt) throw StateError('injected');
    value += 1;
    return value;
  }

  void undo(int _) {
    value -= 1;
  }

  @override
  Iterable<Function> get modifiable => {bump, undo, apply};
}

class TxApplyBenchmark extends AsyncBenchmarkBase {
  TxApplyBenchmark({required this.commands, required this.failAt})
      : super('txApply n=$commands failAt=$failAt');

  final int commands;
  final int? failAt;
  late final BenchCell cell;
  var rolledBack = false;

  @override
  Future<void> setup() async {
    cell = BenchCell(failAt: failAt);
    rolledBack = false;
  }

  @override
  Future<void> run() async {
    final tx = Cell.txApply(TxApplyOptions(
      compensationErrorPolicy: CompensationErrorPolicy.bestEffort,
      compensationMaxAttempts: 1, // no retries — isolates framework overhead
      onEvent: (e) {
        if (e is TxApplyRolledBack) rolledBack = true;
      },
    ));
    await tx.begin([cell]);
    for (var i = 0; i < commands; i++) {
      cell.apply<Object?>(
        (
          function: cell.bump,
          arguments: (positionalArguments: [1], namedArguments: null),
          compensation: (
            function: cell.undo,
            arguments: (positionalArguments: [1], namedArguments: null),
            cell: null,
          ),
        ),
        tx: tx,
      );
    }
    try {
      await tx.commit();
    } on TxApplyException {
      // Expected when failAt != null.
    }
  }
}

Future<void> main() async {
  await TxApplyBenchmark(commands: 10, failAt: null).report();
  await TxApplyBenchmark(commands: 10, failAt: 5).report();
  await TxApplyBenchmark(commands: 100, failAt: null).report();
  await TxApplyBenchmark(commands: 100, failAt: 50).report();
}
