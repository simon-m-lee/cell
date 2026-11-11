// Transaction commit cost across isolation levels: a 20-update commit on
// one ValueCell for readCommitted / repeatableRead / serializable.
//
// Run: dart run benchmark/transaction/value_transaction.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

class TransactionBenchmark extends AsyncBenchmarkBase {
  TransactionBenchmark(this.isolation, this.updates)
      : super('transaction ${isolation.name}, $updates updates');

  final IsolationLevel isolation;
  final int updates;
  late final ValueCell<int> cell;

  @override
  Future<void> setup() async {
    cell = Cell.state<int>(initial: 0).cell;
  }

  @override
  Future<void> run() async {
    final tx = Cell.transaction(TransactionOptions(isolation: isolation));
    await tx.begin([cell]);
    for (var i = 0; i < updates; i++) {
      tx.update(cell, i);
    }
    await tx.commit();
  }
}

void main() async {
  for (final level in [
    IsolationLevel.readCommitted,
    IsolationLevel.repeatableRead,
    IsolationLevel.serializable,
  ]) {
    await TransactionBenchmark(level, 20).report();
  }
}
