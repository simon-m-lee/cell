// Semantic fitness: an unmodifiable view must reject unknown functions via
// apply instead of executing them (bug #6).
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('Unmodifiable dispatch rejects unknown functions', () {
    test('unmodifiable value apply with an unknown function does not run it',
        () async {
      final source = TissueValue<int>(42);
      final readOnly = source.unmodifiable;

      void malicious() => source.value = 999;

      await readOnly.apply<Object?>((
        function: malicious,
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      ));

      expect(source.value, 42,
          reason: 'Unmodifiable apply must not execute unknown functions');
    });

    test('unmodifiable list apply with an unknown function does not run it',
        () async {
      final source = TissueList<int>.of([1]);
      final readOnly = source.unmodifiable;

      void malicious() => source.add(99);

      await readOnly.apply<Object?>((
        function: malicious,
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      ));

      expect(source, [1]);
    });
  });
}
