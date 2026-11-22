// Lenient decode: reference-gap substitutions, onSkipped, user['skipped'],
// and the structural-corruption boundary that still throws.
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> listJson() => TissueList<int>.of([1]).toJson();

  group('lenient decode — reference gaps', () {
    test('unresolved registered tag falls back to readOnly + onSkipped', () {
      final json = listJson();
      ((json['governance'] as Map)['testRule'] as Map)['tag'] =
          'registered:positiveInt';
      final skipped = <String>[];
      final decoded = decodeTissue(json,
          lenient: true, onSkipped: (list) => skipped.addAll(list));
      expect(decoded.validate, same(TestTissue.readOnly));
      expect(skipped, ['testRule']);
    });

    test('governance resolver wins over the lenient fallback', () {
      final rule = TestTissue<int, TissueList<int>>(
          (v, {host, arguments, user}) => true);
      final json = listJson();
      ((json['governance'] as Map)['testRule'] as Map)['tag'] =
          'registered:positiveInt';
      final decoded = decodeTissue(json,
          lenient: true,
          governanceResolver: (tag) =>
              tag == 'registered:positiveInt' ? rule : null);
      expect(decoded.validate, same(rule));
    });

    test('unresolved Cell map key drops the entry with onSkipped(elements)',
        () {
      final key = ValueCell<int>(initial: 1);
      final json = TissueMap<Cell, int>()..[key] = 7;
      final skipped = <String>[];
      final decoded = decodeTissue(json.toJson(),
          lenient: true, onSkipped: (list) => skipped.addAll(list));
      expect(decoded, isA<TissueBase<dynamic, dynamic, dynamic>>());
      expect((decoded as TissueMap<dynamic, dynamic>).isEmpty, isTrue);
      expect(skipped, ['elements']);
    });

    test('onSkipped includes wire entries from a lenient encode', () {
      final tissue = TissueList<Object>.of([1, Object()]);
      final wire = tissue.toJson(lenient: true);
      final skipped = <String>[];
      decodeTissue(wire, lenient: true, onSkipped: (l) => skipped.addAll(l));
      expect(skipped, contains('elements'));
    });

    test('skippedReport records wire and decode entries', () {
      final key = ValueCell<int>(initial: 1);
      final json = TissueMap<Cell, int>()..[key] = 7;
      final decoded = decodeTissue(json.toJson(), lenient: true);
      final skipped = decoded.skippedReport!;
      expect(skipped['wire'], isEmpty);
      expect(skipped['decode'], hasLength(1));
      expect((skipped['decode'] as List).single['field'], 'elements');
    });

    test('lenient decode → lenient re-encode round-trips byte-identically', () {
      // The decode adds no new skips here (the substitution happened on the
      // encode side), so the round-trip is byte-identical.
      final source = TissueList<Object>.of([1, Object()]);
      final wire = source.toJson(lenient: true);
      final decoded = decodeTissue(wire, lenient: true);
      expect(canonicalJsonEncode(encodeTissue(decoded, lenient: true)),
          canonicalJsonEncode(wire));
    });

    test('lenient encode → strict decode does not throw and preserves skips',
        () {
      final tissue = TissueList<Object>.of([1, Object()]);
      final wire = tissue.toJson(lenient: true);
      final decoded = decodeTissue(wire);
      expect(decoded.length, 1);
      expect(decoded.skippedReport!['wire'], ['elements']);
    });
  });

  group('lenient decode — structural corruption still throws', () {
    test('missing __tissue__', () {
      final json = listJson()..remove('__tissue__');
      expect(() => decodeTissue(json, lenient: true),
          throwsA(isA<TissueDecodeError>()));
    });

    test('unsupported version', () {
      final json = listJson()..['__tissue__'] = '2.0.0';
      expect(() => decodeTissue(json, lenient: true),
          throwsA(isA<TissueDecodeError>()));
    });

    test('unknown kind', () {
      final json = listJson()..['kind'] = 'deque';
      expect(() => decodeTissue(json, lenient: true),
          throwsA(isA<TissueDecodeError>()));
    });

    test('malformed elements', () {
      final json = listJson()..['elements'] = 'not-a-list';
      expect(() => decodeTissue(json, lenient: true),
          throwsA(isA<TissueDecodeError>()));
    });

    test('malformed __skipped__', () {
      final json = listJson()..['__skipped__'] = 'not-a-list';
      expect(() => decodeTissue(json, lenient: true),
          throwsA(isA<TissueDecodeError>()));
    });
  });
}
