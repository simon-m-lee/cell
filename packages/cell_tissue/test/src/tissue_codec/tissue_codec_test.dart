// Strict-mode gates, decode errors, canonicality, and the toString contract.
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

/// A cell whose id is the empty string — exercises the `Cell.id.isEmpty`
/// serialisation gate.
class EmptyIdCell extends ValueCell<int> {
  EmptyIdCell() : super(initial: 1);

  @override
  String get id => '';
}

void main() {
  EphemeralPolicy policy() => EphemeralPolicy(
      onEvent: (object, {required cell, arguments, required policy, user}) =>
          (events: 0),
      onInvalidate: (nucleus) => false,
      duration: const Duration(minutes: 5));

  group('encodeTissue strict gates', () {
    test('custom TissueReceptor throws TissueNotSerializable("receptor")', () {
      final tissue = TissueList<int>.of([1],
          receptor: TissueReceptor<int, TissueList<int>>(
              (tissue, pulse, {user}) => pulse));
      expect(
          () => encodeTissue(tissue),
          throwsA(isA<TissueNotSerializable>()
              .having((e) => e.field, 'field', 'receptor')));
    });

    test('anonymous TestTissue throws TissueNotSerializable("testRule")', () {
      final tissue = TissueList<int>.of([1],
          testRule: TestTissue<int, TissueList<int>>(
              (v, {host, arguments, user}) => v > 0));
      expect(
          () => encodeTissue(tissue),
          throwsA(isA<TissueNotSerializable>()
              .having((e) => e.field, 'field', 'testRule')));
    });

    test('EphemeralPolicy throws TissueNotSerializable("policy")', () {
      final nucleus = TissueListNucleus.create<int, TissueList<int>>(
          ephemeralPolicy: policy());
      final tissue = TissueList.fromNucleus(nucleus, elements: [1]);
      expect(
          () => encodeTissue(tissue),
          throwsA(isA<TissueNotSerializable>()
              .having((e) => e.field, 'field', 'policy')));
    });

    test('custom Container throws TissueNotSerializable("container")', () {
      final custom = Container.create<int, List<int>>(
          add: (tissue, list, e) {
            list.add(e);
            return true;
          },
          remove: (tissue, list, e) => list.remove(e));
      final tissue = Tissue.create<int, List<int>, Tissue<int>>(
          container: custom, elements: [1]);
      expect(
          () => encodeTissue(tissue),
          throwsA(isA<TissueNotSerializable>()
              .having((e) => e.field, 'field', 'container')));
    });

    test('Cell element with empty id throws TissueNotSerializable("elements")',
        () {
      final tissue = TissueList<Cell>.of([EmptyIdCell()]);
      expect(
          () => encodeTissue(tissue),
          throwsA(isA<TissueNotSerializable>()
              .having((e) => e.field, 'field', 'elements')));
    });

    test('non-JSON element throws TissueNotSerializable("elements")', () {
      final tissue = TissueList<Object>.of([Object()]);
      expect(
          () => encodeTissue(tissue),
          throwsA(isA<TissueNotSerializable>()
              .having((e) => e.field, 'field', 'elements')));
    });

    test('bind with empty id throws TissueNotSerializable("bind")', () {
      final tissue = TissueList<int>.of([1], bind: EmptyIdCell());
      expect(
          () => encodeTissue(tissue),
          throwsA(isA<TissueNotSerializable>()
              .having((e) => e.field, 'field', 'bind')));
    });

    test('non-JSON user throws TissueNotSerializable("user")', () {
      final tissue = TissueList.create<int, TissueList<int>>(
          elements: [1], user: (Object(),));
      expect(
          () => encodeTissue(tissue),
          throwsA(isA<TissueNotSerializable>()
              .having((e) => e.field, 'field', 'user')));
    });

    test('strict encoding has no __skipped__ field', () {
      final json = TissueList<int>.of([1, 2, 3]).toJson();
      expect(json.containsKey('__skipped__'), isFalse);
    });

    test('TissueNotSerializable.toString() names the lenient escape hatch', () {
      final tissue = TissueList<int>.of([1],
          receptor: TissueReceptor<int, TissueList<int>>(
              (tissue, pulse, {user}) => pulse));
      final error = TissueNotSerializable('receptor', tissue);
      expect(error.toString(), contains('lenient: true'));
    });
  });

  group('decodeTissue strict gates', () {
    Map<String, dynamic> listJson() => TissueList<int>.of([1]).toJson();

    test('missing __tissue__ throws TissueDecodeError', () {
      final json = listJson()..remove('__tissue__');
      expect(() => decodeTissue(json), throwsA(isA<TissueDecodeError>()));
    });

    test('unsupported version throws TissueDecodeError', () {
      final json = listJson()..['__tissue__'] = '2.0.0';
      expect(() => decodeTissue(json), throwsA(isA<TissueDecodeError>()));
    });

    test('unknown kind throws TissueDecodeError', () {
      final json = listJson()..['kind'] = 'deque';
      expect(() => decodeTissue(json), throwsA(isA<TissueDecodeError>()));
    });

    test('malformed elements throw TissueDecodeError', () {
      final json = listJson()..['elements'] = 'not-a-list';
      expect(() => decodeTissue(json), throwsA(isA<TissueDecodeError>()));
    });

    test('unknown container tag throws TissueDecodeError', () {
      final json = listJson();
      (json['config'] as Map)['container'] = 'deque';
      expect(() => decodeTissue(json), throwsA(isA<TissueDecodeError>()));
    });

    test('container tag mismatched with kind throws TissueDecodeError', () {
      final json = listJson();
      (json['config'] as Map)['container'] = 'queue';
      expect(() => decodeTissue(json), throwsA(isA<TissueDecodeError>()));
    });

    test('unresolved registered tag throws in strict mode', () {
      final json = listJson();
      ((json['governance'] as Map)['testRule'] as Map)['tag'] =
          'registered:positiveInt';
      expect(() => decodeTissue(json), throwsA(isA<TissueDecodeError>()));
    });

    test('malformed capacity throws TissueDecodeError', () {
      final json = TissueQueue<int>.of([1]).toJson();
      (json['config'] as Map)['capacity'] = 'ten';
      expect(() => decodeTissue(json), throwsA(isA<TissueDecodeError>()));
    });

    test('malformed map entry throws TissueDecodeError', () {
      final wire = (TissueMap<String, int>()..['a'] = 1).toJson();
      wire['elements'] = [
        [1, 2, 3],
      ];
      expect(() => decodeTissue(wire), throwsA(isA<TissueDecodeError>()));
    });
  });

  group('canonicality', () {
    test('logically-equal tissues produce the same bytes', () {
      final a = TissueList<int>.of([1, 2, 3]);
      final b = TissueList<int>.of([1, 2, 3]);
      expect(canonicalJsonEncode(a.toJson()), canonicalJsonEncode(b.toJson()));
    });

    test('lenient encode with nothing to skip is byte-identical to strict', () {
      final tissue = TissueList<int>.of([1, 2, 3]);
      expect(canonicalJsonEncode(tissue.toJson()),
          canonicalJsonEncode(tissue.toJson(lenient: true)));
    });

    test('strict decode of a lenient encoding does not throw', () {
      final cell = ValueCell<int>(initial: 1);
      final source = TissueList<Object>.of([cell, Object()]);
      final wire = source.toJson(lenient: true);
      final decoded = decodeTissue(wire);
      expect(decoded, isA<TissueBase<dynamic, dynamic, dynamic>>());
    });
  });
}
