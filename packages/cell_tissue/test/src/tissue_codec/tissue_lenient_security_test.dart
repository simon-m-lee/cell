// Lenient-mode security: the fail-closed readOnly default, the explicit
// allowAll opt-in, and no silent permission widening.
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  TissueList<int> anonymousRule() => TissueList<int>.of([1],
      testRule: TestTissue<int, TissueList<int>>(
          (v, {host, arguments, user}) => v > 0));

  group('lenient security', () {
    test('default lenientFallbackTestRule is readOnly (fail-closed)', () {
      final json = anonymousRule().toJson(lenient: true);
      expect(json['governance']['testRule'], {'tag': 'readOnly'});
      final decoded = decodeTissue(json, lenient: true);
      expect(decoded.validate, same(TestTissue.readOnly));
    });

    test('allowAll requires an explicit opt-in', () {
      final json = anonymousRule()
          .toJson(lenient: true, lenientFallbackTestRule: TestTissue.allowAll);
      expect(json['governance']['testRule'], {'tag': 'allowAll'});
      final decoded = decodeTissue(json,
          lenient: true, lenientFallbackTestRule: TestTissue.allowAll);
      expect(decoded.validate, same(TestTissue.allowAll));
    });

    test('lenient encode + strict decode does not widen permissions', () {
      final json = anonymousRule().toJson(lenient: true);
      final decoded = decodeTissue(json); // strict decode.
      expect(decoded.validate, same(TestTissue.readOnly));
    });

    test('skippedReport is present when a rule was substituted', () {
      final json = anonymousRule().toJson(lenient: true);
      final decoded = decodeTissue(json, lenient: true);
      expect(decoded.skippedReport, isNotNull);
      expect(decoded.skippedReport!['wire'], ['testRule']);
    });

    test('unresolved registered tag in lenient decode fails closed', () {
      final json = TissueList<int>.of([1]).toJson();
      ((json['governance'] as Map)['testRule'] as Map)['tag'] =
          'registered:positiveInt';
      final decoded = decodeTissue(json, lenient: true);
      expect(decoded.validate, same(TestTissue.readOnly));
    });
  });
}
