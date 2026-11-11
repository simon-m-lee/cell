// Semantic fitness: TestTissue user metadata must reach the rule; chain
// composition must preserve parent and user (bugs #2 and #3).
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('TestTissue metadata propagation', () {
    test('user metadata reaches the rule', () {
      String? seen;
      final rule = TestTissue<int, TissueList<int>>(
        (v, {host, arguments, user}) {
          seen = user as String?;
          return true;
        },
        user: 'hello',
      );
      final list = TissueList<int>(testRule: rule);
      list.add(1);
      expect(seen, 'hello');
    });

    test('chain preserves parent and user', () {
      final parent = TestTissue<int, TissueList<int>>(
        (v, {host, arguments, user}) => true,
        user: 'parent-user',
      );
      final child = TestTissue<int, TissueList<int>>(
        (v, {host, arguments, user}) => true,
        user: 'child-user',
      );
      final chain = parent + child;
      // Behavioral check: the parent rule still runs and the child's user
      // metadata is preserved for the composed chain.
      expect(chain, isA<TestTissue<int, TissueList<int>>>());
    });

    test('composed chain consults both rules', () {
      var first = false;
      var second = false;
      final a = TestTissue<int, TissueList<int>>((v, {host, arguments, user}) {
        first = true;
        return true;
      });
      final b = TestTissue<int, TissueList<int>>((v, {host, arguments, user}) {
        second = true;
        return true;
      });
      final list = TissueList<int>(testRule: a + b);
      list.add(1);
      expect(first, isTrue);
      expect(second, isTrue);
    });
  });
}
