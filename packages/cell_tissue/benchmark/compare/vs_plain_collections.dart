// Comparison: reactive tissue mutation with one observer vs a plain
// collection with an equivalent hand-rolled listener callback.
//
// Run: dart run benchmark/compare/vs_plain_collections.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

import '../harness.dart';

const n = 50000;

class TissueListObserved extends BenchmarkBase {
  final list = TissueList<int>();

  TissueListObserved() : super('TissueList.add -> observer') {
    Cell.observe(source: list, effect: (_) {});
  }

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      list.add(i);
    }
  }
}

class PlainListObserved extends BenchmarkBase {
  PlainListObserved() : super('plain List + listener');

  final control = PlainList()..listeners.add(() {});

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      control.add(i);
    }
  }
}

class TissueMapObserved extends BenchmarkBase {
  final map = TissueMap<String, int>();

  TissueMapObserved() : super('TissueMap.put -> observer') {
    Cell.observe(source: map, effect: (_) {});
  }

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      map.put('k$i', i);
    }
  }
}

class PlainMapObserved extends BenchmarkBase {
  PlainMapObserved() : super('plain Map + listener');

  final control = PlainMap()..listeners.add(() {});

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      control.put('k$i', i);
    }
  }
}

class TissueValueObserved extends BenchmarkBase {
  final value = TissueValue<int>(0);

  TissueValueObserved() : super('TissueValue.value = -> observer') {
    Cell.observe(source: value, effect: (_) {});
  }

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      value.value = i;
    }
  }
}

class PlainValueObserved extends BenchmarkBase {
  PlainValueObserved() : super('plain field + listener');

  final control = PlainValue()..listeners.add(() {});

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      control.set(i);
    }
  }
}

void main() {
  TissueListObserved().report();
  PlainListObserved().report();
  TissueMapObserved().report();
  PlainMapObserved().report();
  TissueValueObserved().report();
  PlainValueObserved().report();
  print('(see benchmark/README.md for the itemized cost ladder)');
}
