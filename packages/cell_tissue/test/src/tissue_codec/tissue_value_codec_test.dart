// Per-shape round-trip tests (strict mode) — Value.
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('TissueValue codec (strict round-trip)', () {
    test('TissueValue<int> round-trips', () {
      final source = TissueValue<int>(42);
      final json = source.toJson();
      expect(json['kind'], 'value');
      expect(json['elements'], 42);
      final decoded = TissueValue<int>.fromJson(json);
      expect(decoded.value, 42);
      expect(decoded, isA<TissueValue<int>>());
    });

    test('null value round-trips', () {
      final source = TissueValue<int?>(null);
      final json = source.toJson();
      expect(json['elements'], isNull);
      final decoded = TissueValue<int?>.fromJson(json);
      expect(decoded.value, isNull);
    });

    test('finalValue container tag round-trips', () {
      final source = TissueValue<int>(7, finalValue: true);
      final json = source.toJson();
      expect(json['config']['container'], 'finalValue');
      final decoded = TissueValue<int>.fromJson(json);
      expect(decoded.toJson()['config']['container'], 'finalValue');
      expect(decoded.value, 7);
    });

    test('Cell value resolves via resolver, null without one', () {
      final cell = ValueCell<int>(initial: 3);
      final json = TissueValue<Cell>(cell).toJson();
      expect(json['elements'], {'__cell__': cell.id});

      final resolved = TissueValue<Cell?>.fromJson(json,
          cellResolver: (id) => id == cell.id ? cell : null);
      expect(resolved.value, same(cell));

      final unresolved = TissueValue<Cell?>.fromJson(json);
      expect(unresolved.value, isNull);
    });
  });
}
