// Collective emission: batch metadata preservation + branch completion.
//
// Run: dart run benchmark/tissue/batch/collective_emit.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class BatchMetadataPreserved extends BenchmarkBase {
  BatchMetadataPreserved() : super('batch metadata preserved');

  late TissueList<int> list;

  @override
  void setup() {
    list = TissueList<int>();
  }

  @override
  void run() {
    final o1 = list.apply<Object?>((
      function: list.add,
      arguments: (positionalArguments: [1], namedArguments: null),
      compensation: null
    ));
    final o2 = list.apply<Object?>((
      function: list.add,
      arguments: (positionalArguments: [2], namedArguments: null),
      compensation: null
    ));
    final a = (o1 as ApplyAccepted<Object?>).result as TissuePulse<int>;
    final b = (o2 as ApplyAccepted<Object?>).result as TissuePulse<int>;
    final batch = TissuePulse.batch<int>([a, b], priority: 90);
    if (batch.priority != 90) {
      throw StateError('Batch priority lost: ${batch.priority} (expected 90)');
    }
    if (!batch.isComposite) {
      throw StateError('Batch is not composite (bug #4)');
    }
  }
}

void main() {
  BatchMetadataPreserved().report();
}
