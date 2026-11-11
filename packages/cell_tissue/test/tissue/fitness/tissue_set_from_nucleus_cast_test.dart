// Semantic fitness: fromNucleus must accept nuclei built through the public
// create factories (the abstract base type), not require the private
// concrete classes (bug #7).
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('fromNucleus accepts public nucleus types', () {
    test('TissueSet.fromNucleus accepts a created nucleus', () {
      final nucleus = TissueSetNucleus.create<int, TissueSet<int>>();
      final set = TissueSet.fromNucleus(nucleus, elements: [1, 2]);
      expect(set, {1, 2});
      set.add(3);
      expect(set.length, 3);
    });

    test('TissueMap.fromNucleus accepts a created nucleus', () {
      final nucleus =
          TissueMapNucleus.create<String, int, TissueMap<String, int>>();
      final map = TissueMap.fromNucleus(nucleus, entries: [MapEntry('a', 1)]);
      expect(map['a'], 1);
      map.put('b', 2);
      expect(map['b'], 2);
    });

    test('TissueList.fromNucleus accepts a created nucleus', () {
      final nucleus = TissueListNucleus.create<int, TissueList<int>>();
      final list = TissueList.fromNucleus(nucleus, elements: [1]);
      list.add(2);
      expect(list, [1, 2]);
    });

    test('TissueValue.fromNucleus accepts a created nucleus', () {
      final nucleus = TissueValueNucleus.create<int, TissueValue<int>>();
      final value = TissueValue.fromNucleus(nucleus, value: 7);
      expect(value.value, 7);
    });
  });
}
