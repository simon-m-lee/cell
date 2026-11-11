// Bulk mutation costs: addAll / removeWhere / retainWhere / updateAll.
//
// Run: dart run benchmark/tissue/operators/bulk_mutations.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class ListAddAll extends BenchmarkBase {
  ListAddAll() : super('TissueList.addAll (100) + clear');

  final list = TissueList<int>();

  @override
  void run() {
    list.addAll(List.generate(100, (i) => i));
    list.clear();
  }
}

class ListRemoveWhere extends BenchmarkBase {
  ListRemoveWhere() : super('TissueList.removeWhere (half of 100)');

  final list = TissueList<int>();

  @override
  void setup() {
    list.addAll(List.generate(100, (i) => i));
  }

  @override
  void run() {
    list.removeWhere((e) => e.isEven);
    list.addAll(List.generate(50, (i) => i * 2));
  }
}

class MapUpdateAll extends BenchmarkBase {
  MapUpdateAll() : super('TissueMap.updateAll (100)');

  final map = TissueMap<int, int>();

  @override
  void setup() {
    for (var i = 0; i < 100; i++) {
      map.put(i, i);
    }
  }

  @override
  void run() {
    map.updateAll((k, v) => v + 1);
  }
}

void main() {
  ListAddAll().report();
  ListRemoveWhere().report();
  MapUpdateAll().report();
}
