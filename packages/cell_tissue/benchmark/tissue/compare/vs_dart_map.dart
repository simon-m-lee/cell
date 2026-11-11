// Map comparison: native Map vs TissueMap vs native Map + listener.
//
// Run: dart run benchmark/tissue/compare/vs_dart_map.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

import '../harness.dart';

class NativeMapPut extends BenchmarkBase {
  NativeMapPut() : super('native Map.put');

  final map = <String, int>{};

  @override
  void run() {
    map['k'] = 1;
    map.remove('k');
  }
}

class TissueMapPut extends BenchmarkBase {
  TissueMapPut() : super('TissueMap.put');

  final map = TissueMap<String, int>();

  @override
  void run() {
    map.put('k', 1);
    map.remove('k');
  }
}

class NativeMapNotify extends BenchmarkBase {
  NativeMapNotify() : super('native Map.put + listener');

  final control = PlainMap()..listeners.add(() {});

  @override
  void run() {
    control.put('k', 1);
  }
}

void main() {
  NativeMapPut().report();
  TissueMapPut().report();
  NativeMapNotify().report();
}
