// Unmodifiable-view comparison: native List.unmodifiable vs
// UnmodifiableTissueList (both read paths).
//
// Run: dart run benchmark/tissue/compare/vs_dart_unmodifiable_view.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class NativeUnmodifiableRead extends BenchmarkBase {
  NativeUnmodifiableRead() : super('native List.unmodifiable iteration');

  late final List<int> view;

  @override
  void setup() {
    view = List.unmodifiable(List.generate(100, (i) => i));
  }

  @override
  void run() {
    var n = 0;
    for (final _ in view) {
      n++;
    }
    if (n != 100) throw StateError('length changed');
  }
}

class TissueUnmodifiableRead extends BenchmarkBase {
  TissueUnmodifiableRead() : super('UnmodifiableTissueList iteration');

  late final TissueList<int> view;

  @override
  void setup() {
    view = TissueList<int>.of(List.generate(100, (i) => i)).unmodifiable;
  }

  @override
  void run() {
    var n = 0;
    for (final _ in view) {
      n++;
    }
    if (n != 100) throw StateError('length changed');
  }
}

void main() {
  NativeUnmodifiableRead().report();
  TissueUnmodifiableRead().report();
}
