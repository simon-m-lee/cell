// Semantic fitness: TissueListNucleus.create defaults must produce growable
// lists, and Container.list must behave as the standard growable alias
// (bug #5).
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('TissueList growable contracts', () {
    test('TissueListNucleus.create defaults to growable', () {
      final nucleus = TissueListNucleus.create<int, TissueList<int>>();
      final list = TissueList.fromNucleus(nucleus);
      expect(() => list.add(1), returnsNormally);
      expect(list.length, 1);
    });

    test('Container.list is treated as the growable alias', () {
      final nucleus = TissueListNucleus.create<int, TissueList<int>>(
        container: Container.list,
      );
      final list = TissueList.fromNucleus(nucleus);
      expect(() => list.add(1), returnsNormally,
          reason: 'Container.list must produce a resizable list');
      list.add(2);
      expect(list, [1, 2]);
    });

    test('growable: false produces a fixed-length list', () {
      final nucleus = TissueListNucleus.create<int, TissueList<int>>(
        container: Container.growableFalse,
      );
      final list = TissueList.fromNucleus(nucleus, elements: [1]);
      expect(list.length, 1);
      // Fixed-length growth is unsupported; the framework must not crash.
      expect(() => list.add(2), returnsNormally);
    });
  });
}
