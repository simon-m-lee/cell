// Deputy and unmodifiable serialisation: standalone semantics.
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('deputy codec', () {
    test('serialising a deputy flattens to a standalone tissue', () async {
      final source = TissueList<int>.of([1, 2, 3]);
      final deputy = await source.deputy(testRule: TestTissue.readOnly);
      final json = deputy.toJson();
      expect(json['governance']['testRule'], {'tag': 'readOnly'});
      final decoded = TissueList<int>.fromJson(json);
      expect(decoded.toList(), [1, 2, 3]);
      expect(decoded.validate, same(TestTissue.readOnly));
      // Standalone: the decoded tissue does not share the source's state.
      source.add(4);
      expect(decoded.length, 3);
    });

    test('serialising an unmodifiable view produces a readOnly tissue',
        () async {
      final source = TissueList<int>.of([1, 2]);
      final view = source.unmodifiable;
      final json = view.toJson();
      expect(json['governance']['testRule'], {'tag': 'readOnly'});
      final decoded = TissueList<int>.fromJson(json);
      expect(decoded.validate, same(TestTissue.readOnly));
      expect(decoded.toList(), [1, 2]);
      // The decoded tissue is a standalone read-only tissue, not a live view.
      source.add(3);
      expect(decoded.length, 2);
    });

    test('unmodifiable queue round-trips as a standalone readOnly queue', () {
      final source = TissueQueue<int>.of([1, 2], capacity: 4);
      final json = source.unmodifiable.toJson();
      expect(json['config']['capacity'], 4);
      final decoded = TissueQueue<int>.fromJson(json);
      expect(decoded.validate, same(TestTissue.readOnly));
      expect(decoded.toList(), [1, 2]);
      expect(decoded.toJson()['config']['capacity'], 4);
    });
  });
}
