// fromJson(lenient: true) with each override absent and present; the
// sentinel-vs-lenient-fallback distinction.
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('fromJson lenient factories', () {
    test('unresolved registered tag: absent override falls back readOnly', () {
      final json = TissueList<int>.of([1]).toJson();
      ((json['governance'] as Map)['testRule'] as Map)['tag'] =
          'registered:positiveInt';
      final decoded = TissueList<int>.fromJson(json, lenient: true);
      expect(decoded.validate, same(TestTissue.readOnly));
    });

    test('tissueNullTestRule is distinct from the lenient fallback', () {
      final json = TissueList<int>.of([1]).toJson();
      ((json['governance'] as Map)['testRule'] as Map)['tag'] =
          'registered:positiveInt';

      // Sentinel: explicit "I want no validation".
      final widened =
          TissueList<int>.fromJson(json, testRule: tissueNullTestRule);
      expect(widened.validate, same(TestTissue.allowAll));

      // Lenient fallback: "I lost my rule, fall back safely".
      final fallback = TissueList<int>.fromJson(json, lenient: true);
      expect(fallback.validate, same(TestTissue.readOnly));
    });

    test('overrides always win in lenient mode and are never skipped', () {
      final json = TissueList<int>.of([1]).toJson();
      ((json['governance'] as Map)['testRule'] as Map)['tag'] =
          'registered:positiveInt';
      final skipped = <String>[];
      final decoded = TissueList<int>.fromJson(json,
          lenient: true,
          testRule: TestTissue.allowAll,
          onSkipped: (l) => skipped.addAll(l));
      expect(decoded.validate, same(TestTissue.allowAll));
      expect(skipped, isEmpty);
    });

    test('elements override wins in lenient mode', () {
      final json = TissueList<Object>.of([Object()]).toJson(lenient: true);
      final decoded = TissueList<Object>.fromJson(json,
          lenient: true, elements: <Object>[1]);
      expect(decoded.toList(), [1]);
    });

    test('type inference in lenient mode', () {
      final json = TissueList<int>.of([1]).toJson();
      final decoded = TissueList<int>.fromJson(json, lenient: true);
      expect(decoded, isA<TissueList<int>>());
      final set =
          TissueSet<int>.fromJson(TissueSet<int>([1]).toJson(), lenient: true);
      expect(set, isA<TissueSet<int>>());
    });

    test('map entries override wins in lenient mode', () {
      final key = ValueCell<int>(initial: 1);
      final json = TissueMap<Cell, int>()..[key] = 7;
      final decoded = TissueMap<Cell, int>.fromJson(json.toJson(),
          lenient: true, entries: {});
      expect(decoded.isEmpty, isTrue);
    });
  });
}
