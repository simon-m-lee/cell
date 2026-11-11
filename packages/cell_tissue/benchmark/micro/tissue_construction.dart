// Construction cost of each tissue shape vs the equivalent plain Dart
// collection. The plain controls pin the "zero-overhead" claim: every
// tissue allocates a Cell + Nucleus + container, so expect a large but
// bounded multiplier.
//
// Run: dart run benchmark/micro/tissue_construction.dart
import 'dart:collection';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

const n = 10000;

class TissueListConstruction extends BenchmarkBase {
  TissueListConstruction() : super('TissueList()');

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      TissueList<int>();
    }
  }
}

class TissueMapConstruction extends BenchmarkBase {
  TissueMapConstruction() : super('TissueMap()');

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      TissueMap<String, int>();
    }
  }
}

class TissueSetConstruction extends BenchmarkBase {
  TissueSetConstruction() : super('TissueSet()');

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      TissueSet<int>(<int>[]);
    }
  }
}

class TissueQueueConstruction extends BenchmarkBase {
  TissueQueueConstruction() : super('TissueQueue()');

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      TissueQueue<int>();
    }
  }
}

class TissueValueConstruction extends BenchmarkBase {
  TissueValueConstruction() : super('TissueValue()');

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      TissueValue<int>(0);
    }
  }
}

class PlainListConstruction extends BenchmarkBase {
  PlainListConstruction() : super('[control] plain List()');

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      <int>[];
    }
  }
}

class PlainMapConstruction extends BenchmarkBase {
  PlainMapConstruction() : super('[control] plain Map()');

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      <String, int>{};
    }
  }
}

class PlainSetConstruction extends BenchmarkBase {
  PlainSetConstruction() : super('[control] plain Set()');

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      <int>{};
    }
  }
}

class PlainQueueConstruction extends BenchmarkBase {
  PlainQueueConstruction() : super('[control] plain Queue()');

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      Queue<int>();
    }
  }
}

class PlainValueConstruction extends BenchmarkBase {
  PlainValueConstruction() : super('[control] plain field');

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      _PlainBox(0);
    }
  }
}

class _PlainBox {
  _PlainBox(this.value);
  final int value;
}

void main() {
  TissueListConstruction().report();
  TissueMapConstruction().report();
  TissueSetConstruction().report();
  TissueQueueConstruction().report();
  TissueValueConstruction().report();
  PlainListConstruction().report();
  PlainMapConstruction().report();
  PlainSetConstruction().report();
  PlainQueueConstruction().report();
  PlainValueConstruction().report();
}
