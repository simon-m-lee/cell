// Semantic fitness: "Unmodifiable is live" — the docstring contract that
// the benchmarks depend on. Catches a stale-copy regression (bug #1).
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('UnmodifiableTissue is live', () {
    test('base .unmodifiable reflects source mutations', () {
      final source = TissueList<int>.of([1, 2, 3]);
      final readOnly = source.unmodifiable;
      source.add(4);
      expect(readOnly.length, 4);
      expect(readOnly, contains(4));
    });

    test('.view with unmodifiableElement: true reflects source mutations', () {
      final source = TissueList<int>.of([1, 2, 3]);
      final readOnly =
          UnmodifiableTissueList.view(source, unmodifiableElement: true);
      source.add(4);
      expect(readOnly.length, 4);
    });

    test('deep projection: unmodifiableElement projects child cells', () {
      final source = TissueList<Cell>.of([Cell()]);
      final readOnly = source.unmodifiable;
      final projected = readOnly.first;
      // The projection must not be the original cell, and projecting again
      // must be idempotent (already-unmodifiable deputies return themselves).
      expect(identical(projected, source.first), isFalse);
      expect(identical(projected.unmodifiable, projected), isTrue);
    });

    test('map view reflects source mutations', () {
      final source = TissueMap<String, int>(entries: [MapEntry('a', 1)]);
      final readOnly = source.unmodifiable;
      source.put('b', 2);
      expect(readOnly.length, 2);
      expect(readOnly['b'], 2);
    });

    test('set view reflects source mutations', () {
      final source = TissueSet<int>([1]);
      final readOnly = source.unmodifiable;
      source.add(2);
      expect(readOnly.length, 2);
      expect(readOnly, contains(2));
    });

    test('queue view reflects source mutations', () {
      final source = TissueQueue<int>(capacity: 10);
      final readOnly = source.unmodifiable;
      source.addLast(1);
      expect(readOnly.length, 1);
      expect(readOnly.first, 1);
    });

    test('value view reflects source mutations', () {
      final source = TissueValue<int>(1);
      final readOnly = source.unmodifiable;
      source.value = 2;
      expect(readOnly.value, 2);
    });

    test('a read-only deputy reflects source mutations', () async {
      final source = TissueList<int>.of([1]);
      final deputy = await source.deputy(testRule: TestTissue.readOnly);
      source.add(2);
      expect(deputy.length, 2);
    });
  });
}
