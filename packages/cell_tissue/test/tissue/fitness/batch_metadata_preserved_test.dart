// Semantic fitness: batch metadata must survive TissuePulse.batch (bug #4).
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('TissuePulse.batch metadata', () {
    test('priority survives batching', () async {
      final list = TissueList<int>();
      final o1 = await list.apply<Object?>((
        function: list.add,
        arguments: (positionalArguments: [1], namedArguments: null),
        compensation: null
      )) as ApplyAccepted<Object?>;
      final o2 = await list.apply<Object?>((
        function: list.add,
        arguments: (positionalArguments: [2], namedArguments: null),
        compensation: null
      )) as ApplyAccepted<Object?>;
      final a = o1.result as TissuePulse<int>;
      final b = o2.result as TissuePulse<int>;
      final batch = TissuePulse.batch<int>([a, b], priority: 90);
      expect(batch.priority, 90);
    });

    test('a batch is a composite of its events', () async {
      final list = TissueList<int>();
      final o1 = await list.apply<Object?>((
        function: list.add,
        arguments: (positionalArguments: [1], namedArguments: null),
        compensation: null
      )) as ApplyAccepted<Object?>;
      final o2 = await list.apply<Object?>((
        function: list.add,
        arguments: (positionalArguments: [2], namedArguments: null),
        compensation: null
      )) as ApplyAccepted<Object?>;
      final a = o1.result as TissuePulse<int>;
      final b = o2.result as TissuePulse<int>;
      final batch = TissuePulse.batch<int>([a, b]);
      expect(batch.isComposite, isTrue);
      expect(batch, hasLength(2));
    });
  });
}
