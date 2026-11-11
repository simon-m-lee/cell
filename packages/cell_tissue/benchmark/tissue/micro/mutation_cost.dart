// The anchor benchmark: per-mutation cost of each tissue shape on the hot
// path (add + remove keeps the collection at constant size).
//
// Run: dart run benchmark/tissue/micro/mutation_cost.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class ListAddRemove extends BenchmarkBase {
  ListAddRemove() : super('TissueList.add+remove');

  final list = TissueList<int>();

  @override
  void run() {
    list.add(1);
    list.remove(1);
  }
}

class MapPutRemove extends BenchmarkBase {
  MapPutRemove() : super('TissueMap.put+remove');

  final map = TissueMap<int, int>();

  @override
  void run() {
    map.put(0, 1);
    map.remove(0);
  }
}

class SetAddRemove extends BenchmarkBase {
  SetAddRemove() : super('TissueSet.add+remove');

  final set = TissueSet<int>(<int>[]);
  var i = 0;

  @override
  void run() {
    set.add(i);
    set.remove(i);
    i++;
  }
}

class QueueAddRemove extends BenchmarkBase {
  QueueAddRemove() : super('TissueQueue.add+removeFirst');

  final queue = TissueQueue<int>();

  @override
  void run() {
    queue.add(1);
    queue.removeFirst();
  }
}

class ValueSet extends BenchmarkBase {
  ValueSet() : super('TissueValue.set (alternating)');

  final value = TissueValue<int>(0);

  @override
  void run() {
    // Alternate so the identical short-circuit never fires — measure the
    // full commit path.
    value.value = value.value == 0 ? 1 : 0;
  }
}

void main() {
  ListAddRemove().report();
  MapPutRemove().report();
  SetAddRemove().report();
  QueueAddRemove().report();
  ValueSet().report();
}
