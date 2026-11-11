// Deputy chain depth: principal -> deputy -> deputy-of-deputy.
//
// Run: dart run benchmark/tissue/deputy/chain_depth.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class ChainDepth extends BenchmarkBase {
  ChainDepth(this.depth, this.head, this.tail)
      : super('deputy chain depth $depth');

  final int depth;
  final TissueList<int> head;
  final TissueList<int> tail;

  @override
  void run() {
    head.add(1);
    // Read through the full deputy chain: length is inherited.
    if (tail.isEmpty) throw StateError('chain broken');
    head.remove(1);
  }
}

Future<void> main() async {
  for (final n in [1, 3, 10]) {
    var current = TissueList<int>();
    final head = current;
    for (var i = 0; i < n; i++) {
      current = await current.deputy(testRule: TestTissue.allowAll);
    }
    ChainDepth(n, head, current).report();
  }
}
