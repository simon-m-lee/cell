// Map variants: short vs long keys.
//
// Run: dart run benchmark/tissue/container/map_variants.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class ValueMapPut extends BenchmarkBase {
  ValueMapPut() : super('value map put+remove');

  final map = TissueMap<String, int>();

  @override
  void run() {
    map.put('k', 1);
    map.remove('k');
  }
}

class LargeKeyMapPut extends BenchmarkBase {
  LargeKeyMapPut() : super('value map put+remove (long key)');

  final map = TissueMap<String, int>();
  static const key = 'a-reasonably-long-string-key-for-hashing-overhead';

  @override
  void run() {
    map.put(key, 1);
    map.remove(key);
  }
}

void main() {
  ValueMapPut().report();
  LargeKeyMapPut().report();
}
