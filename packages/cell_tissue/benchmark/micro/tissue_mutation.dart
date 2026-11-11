// Pure mutation cost of each tissue shape (no observers attached): the
// validation + atomic-commit machinery without broadcast. Controls are
// bare collection mutations.
//
// Run: dart run benchmark/micro/tissue_mutation.dart
import 'dart:collection';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

const n = 10000;

class TissueListAdd extends BenchmarkBase {
  TissueListAdd() : super('TissueList.add');

  final list = TissueList<int>();

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      list.add(i);
      if (list.length >= 20000) list.clear();
    }
  }
}

class TissueMapPut extends BenchmarkBase {
  TissueMapPut() : super('TissueMap.put');

  final map = TissueMap<String, int>();

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      map.put('k$i', i);
      if (map.length >= 20000) map.clear();
    }
  }
}

class TissueSetAdd extends BenchmarkBase {
  TissueSetAdd() : super('TissueSet.add');

  final set = TissueSet<int>(<int>[]);

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      set.add(i);
      if (set.length >= 20000) set.clear();
    }
  }
}

class TissueQueueAddLast extends BenchmarkBase {
  TissueQueueAddLast() : super('TissueQueue.addLast');

  final queue = TissueQueue<int>();

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      queue.addLast(i);
      if (queue.length >= 20000) queue.clear();
    }
  }
}

class TissueValueSet extends BenchmarkBase {
  TissueValueSet() : super('TissueValue.value =');

  final value = TissueValue<int>(0);

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      value.value = i;
    }
  }
}

class PlainListAdd extends BenchmarkBase {
  PlainListAdd() : super('[control] plain List.add');

  final list = <int>[];

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      list.add(i);
      if (list.length >= 20000) list.clear();
    }
  }
}

class PlainMapPut extends BenchmarkBase {
  PlainMapPut() : super('[control] plain Map[]=');

  final map = <String, int>{};

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      map['k$i'] = i;
      if (map.length >= 20000) map.clear();
    }
  }
}

class PlainSetAdd extends BenchmarkBase {
  PlainSetAdd() : super('[control] plain Set.add');

  final set = <int>{};

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      set.add(i);
      if (set.length >= 20000) set.clear();
    }
  }
}

class PlainQueueAddLast extends BenchmarkBase {
  PlainQueueAddLast() : super('[control] plain Queue.addLast');

  final queue = Queue<int>();

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      queue.addLast(i);
      if (queue.length >= 20000) queue.clear();
    }
  }
}

class PlainFieldSet extends BenchmarkBase {
  PlainFieldSet() : super('[control] plain field write');

  var value = 0;

  @override
  void run() {
    for (var i = 0; i < n; i++) {
      value = i;
    }
  }
}

void main() {
  TissueListAdd().report();
  TissueMapPut().report();
  TissueSetAdd().report();
  TissueQueueAddLast().report();
  TissueValueSet().report();
  PlainListAdd().report();
  PlainMapPut().report();
  PlainSetAdd().report();
  PlainQueueAddLast().report();
  PlainFieldSet().report();
}
