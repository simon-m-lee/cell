// Feature-fair comparisons vs plain Dart collections (with listener
// callbacks on the control side).
//
// Run: dart run benchmark/tissue/compare/vs_dart_list.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

import '../harness.dart';

class NativeListAdd extends BenchmarkBase {
  NativeListAdd() : super('native List.add');

  final list = <int>[];

  @override
  void run() {
    list.add(1);
    list.removeAt(0);
  }
}

class TissueListAdd extends BenchmarkBase {
  TissueListAdd() : super('TissueList.add');

  final list = TissueList<int>();

  @override
  void run() {
    list.add(1);
    list.remove(1);
  }
}

class NativeListNotify extends BenchmarkBase {
  NativeListNotify() : super('native List.add + listener');

  final control = PlainList()..listeners.add(() {});

  @override
  void run() {
    control.add(1);
  }
}

void main() {
  NativeListAdd().report();
  TissueListAdd().report();
  NativeListNotify().report();
  print('(see benchmark/tissue/README.md for the itemized cost ladder)');
}
