// End-to-end observer delivery: mutation → validation → commit → broadcast
// → observer dispatch. Controls are plain collections with a listener
// callback invoked per mutation, so the comparison is feature-fair
// (both sides notify one downstream).
//
// Each `run()` performs exactly one mutation and lets benchmark_harness
// scale the iteration count, so the reported score is microseconds per
// single delivered mutation. (A fixed 10k-mutation loop per run forced
// the harness to run multi-minute phases because it always executes a
// minimum of two iterations per phase.)
//
// Run: dart run benchmark/propagation/observer_delivery.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

import '../harness.dart';

class TissueListDelivery extends BenchmarkBase {
  final list = TissueList<int>();
  var i = 0;

  TissueListDelivery() : super('TissueList.add -> observer') {
    Cell.observe(source: list, effect: (_) {});
  }

  @override
  void run() {
    list.add(i++);
    if (list.length >= 20000) list.clear();
  }
}

class TissueMapDelivery extends BenchmarkBase {
  final map = TissueMap<String, int>();
  var i = 0;

  TissueMapDelivery() : super('TissueMap.put -> observer') {
    Cell.observe(source: map, effect: (_) {});
  }

  @override
  void run() {
    map.put('k${i++}', i);
    if (map.length >= 20000) map.clear();
  }
}

class TissueSetDelivery extends BenchmarkBase {
  final set = TissueSet<int>(<int>[]);
  var i = 0;

  TissueSetDelivery() : super('TissueSet.add -> observer') {
    Cell.observe(source: set, effect: (_) {});
  }

  @override
  void run() {
    set.add(i++);
    if (set.length >= 20000) set.clear();
  }
}

class TissueQueueDelivery extends BenchmarkBase {
  final queue = TissueQueue<int>();
  var i = 0;

  TissueQueueDelivery() : super('TissueQueue.addLast -> observer') {
    Cell.observe(source: queue, effect: (_) {});
  }

  @override
  void run() {
    queue.addLast(i++);
    if (queue.length >= 20000) queue.clear();
  }
}

class TissueValueDelivery extends BenchmarkBase {
  final value = TissueValue<int>(0);
  var i = 0;

  TissueValueDelivery() : super('TissueValue.value = -> observer') {
    Cell.observe(source: value, effect: (_) {});
  }

  @override
  void run() {
    value.value = i++;
  }
}

class PlainListDelivery extends BenchmarkBase {
  PlainListDelivery() : super('[control] plain List + listener');

  final control = PlainList()..listeners.add(() {});
  var i = 0;

  @override
  void run() {
    control.add(i++);
    if (control.values.length >= 20000) control.values.clear();
  }
}

class PlainMapDelivery extends BenchmarkBase {
  PlainMapDelivery() : super('[control] plain Map + listener');

  final control = PlainMap()..listeners.add(() {});
  var i = 0;

  @override
  void run() {
    control.put('k${i++}', i);
    if (control.values.length >= 20000) control.values.clear();
  }
}

class PlainSetDelivery extends BenchmarkBase {
  PlainSetDelivery() : super('[control] plain Set + listener');

  final control = PlainSet()..listeners.add(() {});
  var i = 0;

  @override
  void run() {
    control.add(i++);
    if (control.values.length >= 20000) control.values.clear();
  }
}

class PlainQueueDelivery extends BenchmarkBase {
  PlainQueueDelivery() : super('[control] plain Queue + listener');

  final control = PlainQueue()..listeners.add(() {});
  var i = 0;

  @override
  void run() {
    control.addLast(i++);
    if (control.values.length >= 20000) control.values.clear();
  }
}

class PlainValueDelivery extends BenchmarkBase {
  PlainValueDelivery() : super('[control] plain field + listener');

  final control = PlainValue()..listeners.add(() {});
  var i = 0;

  @override
  void run() {
    control.set(i++);
  }
}

void main() {
  TissueListDelivery().report();
  TissueMapDelivery().report();
  TissueSetDelivery().report();
  TissueQueueDelivery().report();
  TissueValueDelivery().report();
  PlainListDelivery().report();
  PlainMapDelivery().report();
  PlainSetDelivery().report();
  PlainQueueDelivery().report();
  PlainValueDelivery().report();
}
