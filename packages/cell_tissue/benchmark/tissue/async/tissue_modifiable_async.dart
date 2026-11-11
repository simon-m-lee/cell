// Async mutation facade: .async.add() vs synchronous .add().
//
// Run: dart run benchmark/tissue/async/tissue_modifiable_async.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class SyncAdd extends BenchmarkBase {
  SyncAdd() : super('TissueList.add (sync)');

  final list = TissueList<int>();

  @override
  void run() {
    list.add(1);
    list.remove(1);
  }
}

class AsyncAdd extends AsyncBenchmarkBase {
  AsyncAdd() : super('TissueList.async.add (serialized)');

  final list = TissueList<int>();

  @override
  Future<void> run() async {
    await list.async.add(1);
    list.remove(1);
  }
}

void main() {
  SyncAdd().report();
  AsyncAdd().report();
}
