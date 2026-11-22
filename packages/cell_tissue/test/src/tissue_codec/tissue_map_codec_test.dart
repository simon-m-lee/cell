// Per-shape round-trip tests (strict mode) — Map.
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('TissueMap codec (strict round-trip)', () {
    test('string-keyed map uses the object form and round-trips', () {
      final source = TissueMap<String, int>()
        ..['a'] = 1
        ..['b'] = 2;
      final json = source.toJson();
      expect(json['kind'], 'map');
      expect(json['elements'], {'a': 1, 'b': 2});
      final decoded = TissueMap<String, int>.fromJson(json);
      expect(decoded['a'], 1);
      expect(decoded['b'], 2);
      expect(decoded, isA<TissueMap<String, int>>());
    });

    test('identityMap container tag round-trips with resolved Cell keys', () {
      final key = ValueCell<int>(initial: 1);
      final source = TissueMap<Cell, int>.identity()..[key] = 1;
      final json = source.toJson();
      expect(json['config']['container'], 'identityMap');
      final decoded = TissueMap<Cell, int>.fromJson(json,
          cellResolver: (id) => id == key.id ? key : null);
      expect(decoded.toJson()['config']['container'], 'identityMap');
      expect(decoded[key], 1);
    });

    test('Cell keys use the array form and resolve via resolver', () {
      final key = ValueCell<int>(initial: 1);
      final source = TissueMap<Cell, int>()..[key] = 7;
      final json = source.toJson();
      expect(json['elements'], [
        [
          {'__cell__': key.id},
          7,
        ],
      ]);
      final decoded = TissueMap<Cell, int>.fromJson(json,
          cellResolver: (id) => id == key.id ? key : null);
      expect(decoded[key], 7);
    });

    test('unresolved Cell key throws in strict mode', () {
      final key = ValueCell<int>(initial: 1);
      final json = TissueMap<Cell, int>()..[key] = 7;
      expect(() => TissueMap<Cell, int>.fromJson(json.toJson()),
          throwsA(isA<TissueDecodeError>()));
    });

    test('non-string JSON-encodable keys use the array form', () {
      final source = TissueMap<int, String>()..[1] = 'one';
      final json = source.toJson();
      expect(json['elements'], [
        [1, 'one'],
      ]);
      final decoded = TissueMap<int, String>.fromJson(json);
      expect(decoded[1], 'one');
    });
  });
}
