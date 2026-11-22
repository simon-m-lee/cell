// fromJson factories without overrides (strict mode): symmetry, asymmetry,
// per-collection kind rejection, resolver paths, type inference.
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('TissueXxx.fromJson (strict, no overrides)', () {
    test('fromJson(toJson(t)) reproduces t per collection', () {
      final list = TissueList<int>.of([1, 2, 3]);
      expect(TissueList<int>.fromJson(list.toJson()).toList(), [1, 2, 3]);

      final set = TissueSet<int>([1, 2]);
      expect(TissueSet<int>.fromJson(set.toJson()).toList(), [1, 2]);

      final map = TissueMap<String, int>()..['a'] = 1;
      expect(TissueMap<String, int>.fromJson(map.toJson())['a'], 1);

      final queue = TissueQueue<int>.of([1, 2], capacity: 5);
      expect(TissueQueue<int>.fromJson(queue.toJson()).toList(), [1, 2]);

      final value = TissueValue<int>(7);
      expect(TissueValue<int>.fromJson(value.toJson()).value, 7);
    });

    test('asymmetry: non-canonical JSON re-encodes canonically', () {
      final nonCanonical = {
        'kind': 'list',
        '__tissue__': '1.0.0',
        'config': {'container': 'growableTrue', 'capacity': null},
        'elements': [3, 1, 2],
        'governance': {
          'testRule': {'tag': 'readOnly'},
          'context': {'__system__': true},
          'bind': null,
        },
        'user': null,
      };
      final decoded = TissueList<int>.fromJson(nonCanonical);
      expect(decoded.toJson()['elements'], [3, 1, 2]);
      expect(decoded.toJson()['governance']['testRule'], {'tag': 'readOnly'});
    });

    test('per-collection kind rejection', () {
      final listJson = TissueList<int>.of([1]).toJson();
      expect(() => TissueSet<int>.fromJson(listJson),
          throwsA(isA<TissueDecodeError>()));
      expect(() => TissueMap<String, int>.fromJson(listJson),
          throwsA(isA<TissueDecodeError>()));
      expect(() => TissueQueue<int>.fromJson(listJson),
          throwsA(isA<TissueDecodeError>()));
      expect(() => TissueValue<int>.fromJson(listJson),
          throwsA(isA<TissueDecodeError>()));
    });

    test('type inference per collection', () {
      final json = TissueList<int>.of([1]).toJson();
      final list = TissueList<int>.fromJson(json);
      expect(list, isA<TissueList<int>>());
      final set = TissueSet<int>.fromJson(TissueSet<int>([1]).toJson());
      expect(set, isA<TissueSet<int>>());
    });

    test('registered rule tag round-trips via the governance registry', () {
      final rule = TestTissue<int, TissueList<int>>(
          (v, {host, arguments, user}) => v is int && v >= 0);
      TissueGovernanceRegistry.register('positiveInt', rule);
      addTearDown(TissueGovernanceRegistry.forceReset);
      final source = TissueList<int>.of([1], testRule: rule);
      final json = source.toJson();
      expect(json['governance']['testRule'], {'tag': 'registered:positiveInt'});

      final decoded = TissueList<int>.fromJson(json);
      expect(decoded.validate, same(rule));
    });

    test('registered tag resolves via an explicit governance resolver', () {
      final rule = TestTissue<int, TissueList<int>>(
          (v, {host, arguments, user}) => true);
      final json = TissueList<int>.of([1]).toJson();
      ((json['governance'] as Map)['testRule'] as Map)['tag'] =
          'registered:external';
      final decoded = TissueList<int>.fromJson(json,
          governanceResolver: (tag) =>
              tag == 'registered:external' ? rule : null);
      expect(decoded.validate, same(rule));
    });
  });
}
