// Unmodifiable view: live-check contract + deep-projection iteration cost.
//
// Run: dart run benchmark/tissue/deputy/unmodifiable_view.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class UnmodifiableIsLive extends BenchmarkBase {
  UnmodifiableIsLive() : super('unmodifiable is live');

  late final TissueList<int> source;
  late final TissueList<int> readOnly;
  bool live = false;

  @override
  void setup() {
    source = TissueList<int>.of([1, 2, 3]);
    readOnly = source.unmodifiable;
  }

  @override
  void run() {
    source.add(4);
    // The stale-copy bug makes this false on the first iteration.
    live = readOnly.length == 4;
    source.remove(4);
  }

  @override
  void teardown() {
    if (!live) {
      throw StateError(
          'UnmodifiableTissue.view is not live — the historical copy bug. '
          'readOnly.length=${readOnly.length}, expected 4');
    }
  }
}

class UnmodifiableProjection extends BenchmarkBase {
  UnmodifiableProjection()
      : super('unmodifiable iteration (unmodifiableElement: true)');

  late final TissueList<Cell> source;
  late final TissueList<Cell> readOnly;

  @override
  void setup() {
    source = TissueList<Cell>.of(List.generate(100, (_) => Cell()));
    readOnly = source.unmodifiable;
  }

  @override
  void run() {
    var n = 0;
    for (final _ in readOnly) {
      n++;
    }
    if (n != 100) throw StateError('length changed');
  }
}

void main() {
  UnmodifiableIsLive().report();
  UnmodifiableProjection().report();
}
