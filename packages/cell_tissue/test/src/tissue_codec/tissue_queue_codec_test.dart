// Per-shape round-trip tests (strict mode) — Queue.
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('TissueQueue codec (strict round-trip)', () {
    test('TissueQueue round-trips head-to-tail', () {
      final source = TissueQueue<int>.of([1, 2, 3]);
      final json = source.toJson();
      expect(json['kind'], 'queue');
      expect(json['elements'], [1, 2, 3]);
      final decoded = TissueQueue<int>.fromJson(json);
      expect(decoded.toList(), [1, 2, 3]);
      expect(decoded, isA<TissueQueue<int>>());
    });

    test('capacity round-trips', () {
      final source = TissueQueue<int>.of([1, 2], capacity: 10);
      final json = source.toJson();
      expect(json['config']['capacity'], 10);
      final decoded = TissueQueue<int>.fromJson(json);
      expect(decoded.toJson()['config']['capacity'], 10);
    });

    test('unlimited capacity omits -1 from the wire', () {
      final source = TissueQueue<int>.of([1, 2]);
      final json = source.toJson();
      expect(json['config']['capacity'], isNull);
      final decoded = TissueQueue<int>.fromJson(json);
      expect(decoded.toJson()['config']['capacity'], isNull);
    });

    test('capacity 0 is explicit on the wire', () {
      final source = TissueQueue<int>.of([], capacity: 0);
      final json = source.toJson();
      expect(json['config']['capacity'], 0);
      final decoded = TissueQueue<int>.fromJson(json);
      expect(decoded.toJson()['config']['capacity'], 0);
    });
  });
}
