// Per-shape round-trip tests (strict mode) — List.
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('TissueList codec (strict round-trip)', () {
    test('plain TissueList<int> round-trips', () {
      final source = TissueList<int>.of([1, 2, 3]);
      final json = source.toJson();
      expect(json['__tissue__'], '1.0.0');
      expect(json['kind'], 'list');
      final decoded = TissueList<int>.fromJson(json);
      expect(decoded.toList(), [1, 2, 3]);
      expect(decoded, isA<TissueList<int>>());
    });

    test('growableFalse container tag round-trips', () {
      final source = TissueList<int>.of([1, 2], growable: false);
      final json = source.toJson();
      expect(json['config']['container'], 'growableFalse');
      final decoded = TissueList<int>.fromJson(json);
      expect(decoded.toList(), [1, 2]);
      expect(decoded.toJson()['config']['container'], 'growableFalse');
    });

    test('synapses disabled round-trips', () {
      final source = TissueList<int>.of([1], synapses: Synapses.disabled);
      final json = source.toJson();
      expect(json['config']['synapses'], 'disabled');
      final decoded = TissueList<int>.fromJson(json);
      expect(decoded.toJson()['config']['synapses'], 'disabled');
    });

    test('Cell elements encode as references and resolve via resolver', () {
      final cell = ValueCell<int>(initial: 42);
      final source = TissueList<Cell>.of([cell]);
      final json = source.toJson();
      expect(json['elements'], [
        {'__cell__': cell.id}
      ]);

      final decoded = TissueList<Cell?>.fromJson(json,
          cellResolver: (id) => id == cell.id ? cell : null);
      expect(decoded.single, same(cell));
    });

    test('Cell element without a resolver becomes null (both modes)', () {
      final cell = ValueCell<int>(initial: 42);
      final json = TissueList<Cell>.of([cell]).toJson();
      final decoded = TissueList<Cell?>.fromJson(json);
      expect(decoded.single, isNull);
    });

    test('context round-trips through the context codec', () {
      final nucleus = TissueListNucleus.create<int, TissueList<int>>(
          context: Context.module('Ledger'));
      final source = TissueList.fromNucleus(nucleus, elements: [1]);
      final json = source.toJson();
      final decoded = TissueList<int>.fromJson(json);
      expect(decoded.context[Ontology.type], 'Ledger');
    });

    test('bind id round-trips through the resolver', () {
      final upstream = ValueCell<int>(initial: 1);
      final source = TissueList<int>.of([1], bind: upstream);
      final json = source.toJson();
      expect(json['governance']['bind'], upstream.id);
      final decoded = TissueList<int>.fromJson(json,
          cellResolver: (id) => id == upstream.id ? upstream : null);
      expect(decoded.toJson()['governance']['bind'], upstream.id);
    });

    test('JSON-encodable user round-trips', () {
      final source = TissueList.create<int, TissueList<int>>(
          elements: [1], user: ('audit',));
      final json = source.toJson();
      expect(json['user'], ['audit']);
      final decoded = TissueList<int>.fromJson(json);
      expect(decoded.toJson()['user'], ['audit']);
    });

    test('re-encode of a decoded tissue is byte-identical', () {
      final source = TissueList<int>.of([1, 2, 3]);
      final json = source.toJson();
      final decoded = TissueList<int>.fromJson(json);
      expect(canonicalJsonEncode(decoded.toJson()), canonicalJsonEncode(json));
    });
  });
}
