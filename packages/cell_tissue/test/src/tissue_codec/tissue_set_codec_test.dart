// Per-shape round-trip tests (strict mode) — Set.
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('TissueSet codec (strict round-trip)', () {
    test('TissueSet round-trips with insertion order and uniqueness', () {
      final source = TissueSet<int>([3, 1, 2, 1]);
      final json = source.toJson();
      expect(json['kind'], 'set');
      expect(json['elements'], [3, 1, 2]);
      final decoded = TissueSet<int>.fromJson(json);
      expect(decoded.toList(), [3, 1, 2]);
      expect(decoded, isA<TissueSet<int>>());
    });

    test('identitySet container tag round-trips', () {
      final source = TissueSet.fromNucleus(
          TissueSetNucleus.create<int, TissueSet<int>>(
              container: Container.identitySet),
          elements: [1, 2]);
      final json = source.toJson();
      expect(json['config']['container'], 'identitySet');
      final decoded = TissueSet<int>.fromJson(json);
      expect(decoded.toJson()['config']['container'], 'identitySet');
      expect(decoded.contains(1), isTrue);
    });

    test('identity uniqueness survives the round-trip', () {
      final a = ValueCell<int>(initial: 1);
      final b = ValueCell<int>(initial: 1);
      final source = TissueSet.fromNucleus(
          TissueSetNucleus.create<Cell, TissueSet<Cell>>(
              container: Container.identitySet),
          elements: [a, b]);
      expect(source.length, 2); // identity — equal values are distinct.
      final decoded = TissueSet<Cell?>.fromJson(source.toJson(),
          cellResolver: (id) => id == a.id
              ? a
              : id == b.id
                  ? b
                  : null);
      expect(decoded.length, 2);
      expect(decoded, containsAll([a, b]));
    });

    test('unresolved Cell element becomes null', () {
      final cell = ValueCell<int>(initial: 1);
      final json = TissueSet<Cell>([cell]).toJson();
      final decoded = TissueSet<Cell?>.fromJson(json);
      expect(decoded, contains(null));
    });
  });
}
