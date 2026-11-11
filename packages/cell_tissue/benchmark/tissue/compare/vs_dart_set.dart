// Set comparison: native Set vs TissueSet vs native Set + listener.
//
// Run: dart run benchmark/tissue/compare/vs_dart_set.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

import '../harness.dart';

class NativeSetAdd extends BenchmarkBase {
  NativeSetAdd() : super('native Set.add');

  final set = <int>{};
  var i = 0;

  @override
  void run() {
    set.add(i);
    set.remove(i);
    i++;
  }
}

class TissueSetAdd extends BenchmarkBase {
  TissueSetAdd() : super('TissueSet.add');

  final set = TissueSet<int>(<int>[]);
  var i = 0;

  @override
  void run() {
    set.add(i);
    set.remove(i);
    i++;
  }
}

class NativeSetNotify extends BenchmarkBase {
  NativeSetNotify() : super('native Set.add + listener');

  final control = PlainSet()..listeners.add(() {});
  var i = 0;

  @override
  void run() {
    control.add(i);
    i++;
  }
}

void main() {
  NativeSetAdd().report();
  TissueSetAdd().report();
  NativeSetNotify().report();
}
