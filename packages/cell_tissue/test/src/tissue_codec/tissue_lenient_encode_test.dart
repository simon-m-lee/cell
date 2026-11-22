// Lenient encode: the substitution table, __skipped__ presence/sorting,
// and canonicality.
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

class EmptyIdCell extends ValueCell<int> {
  EmptyIdCell() : super(initial: 1);

  @override
  String get id => '';
}

EphemeralPolicy policy() => EphemeralPolicy(
    onEvent: (object, {required cell, arguments, required policy, user}) =>
        (events: 0),
    onInvalidate: (nucleus) => false,
    duration: const Duration(minutes: 5));

void main() {
  group('lenient encode — substitution table', () {
    test('custom receptor → passThrough, __skipped__: [receptor]', () {
      final tissue = TissueList<int>.of([1],
          receptor: TissueReceptor<int, TissueList<int>>(
              (tissue, pulse, {user}) => pulse));
      final json = tissue.toJson(lenient: true);
      expect(json['__skipped__'], ['receptor']);
      // No receptor field on the wire — decode restores passThrough.
      expect(json['governance'].containsKey('receptor'), isFalse);
      final decoded = decodeTissue(json);
      expect(decoded.validate, isNotNull);
    });

    test('anonymous testRule → readOnly, __skipped__: [testRule]', () {
      final tissue = TissueList<int>.of([1],
          testRule: TestTissue<int, TissueList<int>>(
              (v, {host, arguments, user}) => v > 0));
      final json = tissue.toJson(lenient: true);
      expect(json['__skipped__'], contains('testRule'));
      expect(json['governance']['testRule'], {'tag': 'readOnly'});
    });

    test('lenientFallbackTestRule: allowAll is an explicit opt-in', () {
      final tissue = TissueList<int>.of([1],
          testRule: TestTissue<int, TissueList<int>>(
              (v, {host, arguments, user}) => v > 0));
      final json = tissue.toJson(
          lenient: true, lenientFallbackTestRule: TestTissue.allowAll);
      expect(json['__skipped__'], contains('testRule'));
      expect(json['governance']['testRule'], {'tag': 'allowAll'});
    });

    test('ephemeralPolicy → dropped, __skipped__: [policy]', () {
      final nucleus = TissueListNucleus.create<int, TissueList<int>>(
          ephemeralPolicy: policy());
      final tissue = TissueList.fromNucleus(nucleus, elements: [1]);
      final json = tissue.toJson(lenient: true);
      expect(json['__skipped__'], ['policy']);
      final decoded = decodeTissue(json);
      expect(decoded.isGoverned, isFalse);
    });

    test('custom container → default, __skipped__: [container]', () {
      final custom = Container.create<int, List<int>>(
          add: (tissue, list, e) {
            list.add(e);
            return true;
          },
          remove: (tissue, list, e) => list.remove(e));
      final tissue = Tissue.create<int, List<int>, Tissue<int>>(
          container: custom, elements: [1]);
      final json = encodeTissue(tissue, lenient: true);
      expect(json['__skipped__'], contains('container'));
      expect(json['config']['container'], 'growableTrue');
    });

    test('Cell element with empty id → dropped, __skipped__: [elements]', () {
      final tissue =
          TissueList<Cell>.of([EmptyIdCell(), ValueCell<int>(initial: 2)]);
      final json = tissue.toJson(lenient: true);
      expect(json['__skipped__'], ['elements']);
      expect(json['elements'], [
        {'__cell__': isNotEmpty},
      ]);
    });

    test('non-JSON element → dropped, __skipped__: [elements]', () {
      final tissue = TissueList<Object>.of([1, Object(), 3]);
      final json = tissue.toJson(lenient: true);
      expect(json['__skipped__'], ['elements']);
      expect(json['elements'], [1, 3]);
    });

    test('bind with empty id → null, __skipped__: [bind]', () {
      final tissue = TissueList<int>.of([1], bind: EmptyIdCell());
      final json = tissue.toJson(lenient: true);
      expect(json['__skipped__'], ['bind']);
      expect(json['governance']['bind'], isNull);
    });

    test('non-JSON user → null, __skipped__: [user]', () {
      final tissue = TissueList.create<int, TissueList<int>>(
          elements: [1], user: (Object(),));
      final json = tissue.toJson(lenient: true);
      expect(json['__skipped__'], ['user']);
      expect(json['user'], isNull);
    });

    test('multiple non-serialisable fields → all substituted, sorted', () {
      final tissue = TissueList.create<Object, TissueList<Object>>(
        elements: [1, Object()],
        receptor: TissueReceptor<Object, TissueList<Object>>(
            (tissue, pulse, {user}) => pulse),
        testRule: TestTissue<Object, TissueList<Object>>(
            (v, {host, arguments, user}) => true),
        user: (Object(),),
      );
      final json = tissue.toJson(lenient: true);
      expect(json['__skipped__'], ['elements', 'receptor', 'testRule', 'user']);
    });

    test('nothing to skip → byte-identical to strict, no __skipped__', () {
      final tissue = TissueList<int>.of([1, 2, 3]);
      expect(canonicalJsonEncode(tissue.toJson(lenient: true)),
          canonicalJsonEncode(tissue.toJson()));
      expect(tissue.toJson(lenient: true).containsKey('__skipped__'), isFalse);
    });
  });
}
