// Container variants: growable vs fixed-length lists, value vs identity
// sets/maps.
//
// Run: dart run benchmark/tissue/container/list_variants.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class GrowableAdd extends BenchmarkBase {
  GrowableAdd() : super('growable list add+remove');

  final list = TissueList<int>(growable: true);

  @override
  void run() {
    list.add(1);
    list.remove(1);
  }
}

class FixedAdd extends BenchmarkBase {
  FixedAdd() : super('fixed-length list add+remove');

  late final TissueList<int> list;

  @override
  void setup() {
    list = TissueList<int>.of([1], growable: false);
  }

  @override
  void run() {
    // Growth on a fixed list is rejected by the container; measure the
    // rejection cost.
    list.add(1);
  }
}

void main() {
  GrowableAdd().report();
  FixedAdd().report();
}
