// Complex operation costs: sort / shuffle / replaceRange / setRange.
//
// Run: dart run benchmark/tissue/operators/complex_ops.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class ListSort extends BenchmarkBase {
  ListSort() : super('TissueList.sort (100, descending)');

  final list = TissueList<int>();

  @override
  void setup() {
    list.addAll(List.generate(100, (i) => i));
  }

  @override
  void run() {
    list.sort((a, b) => b.compareTo(a));
  }
}

class ListReplaceRange extends BenchmarkBase {
  ListReplaceRange() : super('TissueList.replaceRange (10 of 100)');

  final list = TissueList<int>();

  @override
  void setup() {
    list.addAll(List.generate(100, (i) => i));
  }

  @override
  void run() {
    list.replaceRange(0, 10, List.generate(10, (i) => i + 1));
  }
}

class ListShuffle extends BenchmarkBase {
  ListShuffle() : super('TissueList.shuffle (100)');

  final list = TissueList<int>();

  @override
  void setup() {
    list.addAll(List.generate(100, (i) => i));
  }

  @override
  void run() {
    list.shuffle();
  }
}

void main() {
  ListSort().report();
  ListReplaceRange().report();
  ListShuffle().report();
}
