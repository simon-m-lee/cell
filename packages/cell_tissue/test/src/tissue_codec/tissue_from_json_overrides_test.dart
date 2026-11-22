// fromJson factory overrides and sentinels (strict mode).
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('fromJson overrides', () {
    test('testRule override wins over the JSON rule', () {
      final json = TissueList<int>.of([1]).toJson(); // allowAll in the JSON.
      final readOnly =
          TissueList<int>.fromJson(json, testRule: TestTissue.readOnly);
      expect(readOnly.validate, same(TestTissue.readOnly));
    });

    test('tissueNullTestRule explicitly widens to allowAll', () {
      final json = TissueList<int>.of([1]).toJson();
      final widened =
          TissueList<int>.fromJson(json, testRule: tissueNullTestRule);
      expect(widened.validate, same(TestTissue.allowAll));
      expect(widened.toJson()['governance']['testRule'], {'tag': 'allowAll'});
    });

    test('context override wins', () {
      final json = TissueList<int>.of([1]).toJson();
      final decoded =
          TissueList<int>.fromJson(json, context: Context.module('UI'));
      expect(decoded.context[Ontology.type], 'UI');
    });

    test('bind override wins; tissueNullBind strips the bind', () {
      final upstream = ValueCell<int>(initial: 1);
      final json = TissueList<int>.of([1], bind: upstream).toJson();
      final decoded = TissueList<int>.fromJson(json,
          bind: upstream, cellResolver: (id) => null);
      expect(decoded.toJson()['governance']['bind'], upstream.id);

      final stripped = TissueList<int>.fromJson(json, bind: tissueNullBind);
      expect(stripped.toJson()['governance']['bind'], isNull);
    });

    test('container override wins; tissueNullContainer uses the default', () {
      final json = TissueList<int>.of([1]).toJson(); // growableTrue in JSON.
      final fixed =
          TissueList<int>.fromJson(json, container: Container.growableFalse);
      expect(fixed.toJson()['config']['container'], 'growableFalse');

      final backToDefault =
          TissueList<int>.fromJson(json, container: tissueNullContainer);
      expect(backToDefault.toJson()['config']['container'], 'growableTrue');
    });

    test('elements override wins', () {
      final json = TissueList<int>.of([1, 2, 3]).toJson();
      final decoded = TissueList<int>.fromJson(json, elements: []);
      expect(decoded.toList(), isEmpty);
    });

    test('identity override forces the identity container', () {
      final json = TissueSet<int>([1]).toJson();
      final byIdentity = TissueSet<int>.fromJson(json, identity: true);
      expect(byIdentity.toJson()['config']['container'], 'identitySet');
      final byValue = TissueSet<int>.fromJson(json, identity: false);
      expect(byValue.toJson()['config']['container'], 'set');
    });

    test('queue capacity override and tissueNullCapacity sentinel', () {
      final json = TissueQueue<int>.of([1], capacity: 3).toJson();
      final bounded = TissueQueue<int>.fromJson(json, capacity: 10);
      expect(bounded.toJson()['config']['capacity'], 10);
      final unlimited =
          TissueQueue<int>.fromJson(json, capacity: tissueNullCapacity);
      expect(unlimited.toJson()['config']['capacity'], isNull);
      final zero = TissueQueue<int>.fromJson(json, capacity: 0);
      expect(zero.toJson()['config']['capacity'], 0);
    });

    test('value override and tissueNullValue sentinel', () {
      final json = TissueValue<int>(42).toJson();
      expect(TissueValue<int>.fromJson(json, value: 7).value, 7);
      expect(TissueValue<int>.fromJson(json, value: tissueNullValue).value,
          isNull);
    });

    test('map entries override accepts a Map or entries iterable', () {
      final json = TissueMap<String, int>()..['a'] = 1;
      final fromMap =
          TissueMap<String, int>.fromJson(json.toJson(), entries: {'b': 2});
      expect(fromMap['b'], 2);
      expect(fromMap['a'], isNull);

      final fromEntries = TissueMap<String, int>.fromJson(json.toJson(),
          entries: [MapEntry('c', 3)]);
      expect(fromEntries['c'], 3);
    });

    test('user override and tissueNullUser sentinel', () {
      final json =
          TissueList.create<int, TissueList<int>>(elements: [1], user: ('a',))
              .toJson();
      final replaced = TissueList<int>.fromJson(json, user: ('b',));
      expect(replaced.toJson()['user'], ['b']);
      final stripped = TissueList<int>.fromJson(json, user: tissueNullUser);
      expect(stripped.toJson()['user'], isNull);
    });

    test('override asymmetry: re-encode reflects the override', () {
      final json = TissueList<int>.of([1]).toJson();
      expect(TissueList<int>.fromJson(json, elements: []).toJson()['elements'],
          isEmpty);
      expect(
          TissueList<int>.fromJson(json, testRule: tissueNullTestRule)
              .toJson()['governance']['testRule'],
          {'tag': 'allowAll'});
    });
  });
}
