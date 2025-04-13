
import 'package:random_string/random_string.dart';

import 'collective_utils_test.dart';

// ignore_for_file: prefer_typing_uninitialized_variables
// ignore_for_file: avoid_function_literals_in_foreach_calls
// ignore_for_file: unused_local_variable
// ignore_for_file: iterable_contains_unrelated_type
// ignore_for_file: avoid_print


/*
void main() {
  var actual, expected;

  var collective, collectiveWhere, unmodifiable, parents, where, properties;

  // final testObj = TestObject<CollectiveValue<int>, dynamic>((v, {on, args, user, others}) => (v as CollectiveValue) >= 10 ? TestMatch.matched : TestMatch.unmatched);

  void runTest() {
    // actual = unmodifiable.toList(growable: false);
    // expected = collective.toList(growable: false);
    expect(unmodifiable, allOf([
      hasLength(collective.length),
      isA<Unmodifiable>(),
      everyElement(isA<Unmodifiable>()),
      containsAll(collective),
    ]));
  }

  group('CollectiveSet - Set interfaces', () {
    test(
        'Collective.set - add, remove, addAll, clear, removeAll, removeWhere, retainAll, retainWhere, updateAll, updateWhere', () {
      final elements = List<String>.generate(10, (_) => randomString(8));
      final collective = CollectiveSet<String>.of(elements);

      expect(collective.length, elements.length);
      expect(collective, containsAll(elements));
    });
  });

  group('CollectiveSet', () {
    Properties properties;

    test('parents', () {
      final numbers = [0, 1, 2, 3, 4, 5, 10, 20, 30, 40, 50, 60];
      final props = List<CollectiveValueProperties<int>>.generate(
          numbers.length, (i) => CollectiveValueProperties<int>());
      final values = List<CollectiveValue<int>>.generate(
          numbers.length, (i) =>
      CollectiveValue<int>.fromProperties(
          props[i], value: numbers[i]));

      final uProps = List<CollectiveValueProperties<int>>.generate(
          numbers.length, (i) => CollectiveValueProperties<int>());
      final unmodifiableValues = values.map<CollectiveValue<int>>((v) =>
      v.unmodifiable);


      collective = CollectiveSet<CollectiveValue<int>>.fromProperties(
          properties = CollectiveSetProperties<CollectiveValue<int>>(
              onPost: Receptor((c, post) => onPost(c, post))), elements: values);
      unmodifiable = Collective<CollectiveValue<int>>.unmodifiable(
          collective, onPost: Receptor((c, post) => onPost(c, post)));

      expect(collective, equals(unmodifiable));

      for (int i = 0; i < values.length; i++) {
        expect(props[i].linkable, allOf([
          parents = props[i].linkable.toList(growable: false),
          hasLength(2),
          contains(collective),
        ]));
      }

      for (int i = 0; i < values.length; i++) {
        expect(uProps[i].linkable, allOf([
          parents = uProps[i].linkable.toList(growable: false),
          hasLength(1),
          contains(unmodifiable)
        ]));
      }
    });

    test('Collective<int>.set', () {
      final numbers = List<int>.generate(10, (i) => i);

      final collective = CollectiveSet<int>.of(numbers);
      expect(collective, containsAll(numbers));
    });

    test('Collective<String>.set', () {
      final elements = List<String>.generate(10, (_) => randomString(8));

      final collective = Collective.set<String>(elements);
      expect(collective.length, elements.length);
      expect(collective, containsAll(elements));
    });

    test('Collective.set', () {
      final elements = [
        randomAlpha(8),
        randomAlphaNumeric(8),
        randomBetween(10, 20),
        randomMerge(randomString(8), randomString(8)),
        randomString(8),
        randomNumeric(8)
      ];

      final collective = CollectiveSet.of(elements);
      expect(collective, containsAll(elements));
    });

    test('Collective<CollectiveElement>.set', () {
      final values = List<CollectiveValue>.generate(
          10, (_) => CollectiveValue<String>(randomString(8)));

      final collective = CollectiveSet<CollectiveValue>.of(values);
      expect(collective.length, values.length);
      expect(collective, containsAll(values));
    });

    test('Collective - add', () {
      final numbers = List<int>.generate(10, (i) => i);
      final collective = CollectiveSet<int>.of(numbers);

      {
        final unmodifiable = Collective<int>.unmodifiable(collective);

        final num = randomBetween(0, 9);
        collective.add(num);

        expect(collective, contains(num));
        expect(unmodifiable, contains(num));
      }

      {
        final unmodifiable = CollectiveSet<int>.unmodifiable(collective);

        final num = randomBetween(0, 9);
        collective.add(num);

        expect(collective, contains(num));
        expect(unmodifiable, contains(num));
        expect(() => unmodifiable.add(num), throwsUnsupportedError);
      }
    });

    var where;

*/
/*
    test('CollectiveWhere(..., {unmodifiableElement: false})', () {
      final numbers = [0, 1, 2, 3, 4, 5, 10, 20, 30, 40, 50, 60];
      final values = List<CollectiveValue<int>>.generate(numbers.length, (i) => CollectiveValue<int>(numbers[i]));
      collective = CollectiveSet<CollectiveValue<int>>(values, onPost: OnPost((c, post) => onPost(c, post)));

      expect(collective.containsAll(numbers), isTrue);

      { // CollectiveWhere (Unmodifiable)
        where = Collective<CollectiveValue<int>>(collective, test: testObj, onPost: OnPost((c, post) => onPost(c, post)));
        expect(where, allOf([
          isA<Unmodifiable>(),
          everyElement(allOf([
            isNot(isA<Unmodifiable>()),
          ])),
        ]));

        { // value
          eventNum++;
          { // elementUpdated
            expect(() => values.firstWhere((e) => testObj(e, on: collective)).value = 100, returnsNormally);
          }

          eventNum++;
          { // elementAdded
            expect(() => values.firstWhere((e) => testObj(e, on: collective) == false).value = 100, returnsNormally);
          }

          eventNum++;
          { // elementRemoved
            expect(() => values.firstWhere((e) => testObj(e, on: collective)).value = 6, returnsNormally);
          }

        }

        { // where
          eventNum++;
          {
            expect(() => where.firstWhere((e) => testObj(e, on: collective)).value = 6, returnsNormally);
          }

          eventNum++;
          { // elementUpdated
            expect(() => where.firstWhere((e) => testObj(e, on: collective)).value = 200, returnsNormally);
          }

        }

      }

      print('end');

    });
*//*


*/
/*
    test('CollectiveWhere(..., {unmodifiableElement: true})', () {
      final numbers = [0, 1, 2, 3, 4, 5, 10, 20, 30, 40, 50, 60];
      final values = List<CollectiveValue<int>>.generate(numbers.length, (i) => CollectiveValue<int>(numbers[i]));
      collective = CollectiveSet<CollectiveValue<int>>(values, onPost: OnPost((c, post) => onPost(c, post)));

      expect(collective.containsAll(numbers), isTrue);

      { // CollectiveWhere (Unmodifiable)
        where = Collective<CollectiveValue<int>>(collective, test: testObj, onPost: OnPost((c, post) => onPost(c, post)));
        actual = where.toList(growable: false);
        expect(where, allOf([
          isA<Unmodifiable>(),
          everyElement(allOf([
            isA<CollectiveValue>()
          ])),
        ]));

        { // value
          eventNum++;
          { // elementUpdated
            expect(() => values.firstWhere((e) => testObj(e, on: collective)).value = 100, returnsNormally);
          }

          eventNum++;
          { // elementAdded
            expect(() => values.firstWhere((e) => testObj(e, on: collective) == false).value = 100, returnsNormally);
          }

          eventNum++;
          { // elementRemoved
            expect(() => values.firstWhere((e) => testObj(e, on: collective)).value = 6, returnsNormally);
          }

        }

        { // where
          eventNum++;
          {
            expect(() => where.firstWhere((e) => testObj(e, on: collective)).value = 6, returnsNormally);
          }

          eventNum++;
          { // elementUpdated
            expect(() => where.firstWhere((e) => testObj(e, on: collective)).value = 200, returnsNormally);
          }

        }

      }

      print('end');

    });
*//*


*/
/*
    test('CollectiveSetWhere(..., {syncCollective: false})', () {
      final numbers = [0, 1, 2, 3, 4, 5, 10, 20, 30, 40, 50, 60];
      final values = List<CollectiveValue<int>>.generate(numbers.length, (i) => CollectiveValue<int>(numbers[i]));
      collective = CollectiveSet<CollectiveValue<int>>(values, onPost: OnPost((c, post) => onPost(c, post)));

      expect(collective.containsAll(numbers), isTrue);

      { // CollectiveSetWhere {syncCollective: false}
        where = CollectiveSet<CollectiveValue<int>>(collective, test: testObj, onPost: OnPost((c, post) => onPost(c, post)));
        actual = values.where((e) => testObj(e, on: collective));
        expect(where, allOf([
          hasLength(actual.length),
          isNot(isA<Unmodifiable>()),
        ]));

        unmodifiable = Collective<CollectiveValue<int>>.unmodifiable(where, onPost: OnPost((c, post) => onPost(c, post)));
        expect(unmodifiable, allOf([
          containsAll(where),
          isA<Unmodifiable>(),
          everyElement(isA<Unmodifiable>()),
        ]));

        { // value
          eventNum++;
          {
            expect(() => values.firstWhere((e) => testObj(e, on: collective)).value = 100, returnsNormally);
          }

          eventNum++;
          {
            expect(() => values.firstWhere((e) => testObj(e, on: collective)).value = 6, returnsNormally);
          }

        }

        { // where
          eventNum++;
          {
            expect(() =>
            where
                .firstWhere((e) => testObj(e, on: collective))
                .value = 6, returnsNormally);
          }

          eventNum++;
          {
            expect(() =>
            where
                .firstWhere((e) => testObj(e, on: collective))
                .value = 200, returnsNormally);
          }

          eventNum++;
          {
            expect(where.add(CollectiveValue<int>(2)), false);
          }


          final a = where.add(CollectiveValue<int>(70));
          eventNum++;
          {
            expect(where.add(CollectiveValue<int>(70)), true);
          }

          eventNum++;
          {
            expect(where.remove(70), true);
          }
        }
      }

      print('end');

    });
*//*


*/
/*
    test('CollectiveSetWhere(..., {syncCollective: true})', () {
      final numbers = [0, 1, 2, 3, 4, 5, 10, 20, 30, 40, 50, 60];
      final values = List<CollectiveValue<int>>.generate(numbers.length, (i) => CollectiveValue<int>(numbers[i]));
      collective = CollectiveSet<CollectiveValue<int>>(values, onPost: OnPost((c, post) => onPost(c, post)));

      { // CollectiveSetWhere {syncCollective: true}
        where = CollectiveSet<CollectiveValue<int>>(collective, test: testObj, onPost: OnPost((c, post) => onPost(c, post)));
        where.forEach((e) => expect(values, contains(e)));
        where.forEach((e) => expect(collective, contains(e)));

        // Unmodifiable {unmodifiableElement: true}
        unmodifiable = Collective<CollectiveValue<int>>.unmodifiable(where, unmodifiableElement: true, onPost: OnPost((c, post) => onPost(c, post)));
        unmodifiable.forEach((e) => expect(collective, contains(e)));

        expect(unmodifiable, allOf([
          isA<Unmodifiable>(),
          everyElement(isA<Unmodifiable>()),
        ]));

        { // value
          eventNum++;
          {
            expect(() => values.firstWhere((e) => testObj(e, on: collective)).value = 100, returnsNormally);
          }

          eventNum++;
          {
            expect(() => values.firstWhere((e) => testObj(e, on: collective)).value = 6, returnsNormally);
          }

        }

        { // where
          eventNum++;
          {
            expect(() => where.firstWhere((e) => testObj(e, on: collective)).value = 6, returnsNormally);
          }

          eventNum++;
          {
            expect(() => where.firstWhere((e) => testObj(e, on: collective)).value = 200, returnsNormally);
          }

          eventNum++;
          {
            expect(where.add(CollectiveValue<int>(2)), false);
          }

          eventNum++;
          {
            expect(where.add(CollectiveValue<int>(70)), true);
          }

          eventNum++;
          {
            expect(where.remove(70), true);
          }
        }

      }

      print('end');

    });
*//*


*/
/*
    test('CollectiveValue', () {
      final numbers = [0, 1, 2, 3, 4, 5];

      { // CollectiveBase
        final values = List<CollectiveValue<int>>.generate(numbers.length, (i) => CollectiveValue<int>(numbers[i]));
        numbers.forEach((n) => expect(values, contains(n)));

        collective = Collective<CollectiveValue<int>>(values, onPost: OnPost((c, post) => onPost(c, post)));
        numbers.forEach((n) => expect(collective, contains(n)));
        values.forEach((v) => expect(Element.linkable(v), contains(collective)));

        unmodifiable = Collective<CollectiveValue<int>>.unmodifiable(collective, onPost: OnPost((c, post) => onPost(c, post)));
        numbers.forEach((n) => expect(unmodifiable, contains(n)));
        collective.forEach((e) => expect(unmodifiable, contains(e)));

        runTest();

        values.first.value = 6;

      }

      { // CollectiveSet
        final values = List<CollectiveValue<int>>.generate(numbers.length, (i) => CollectiveValue<int>(numbers[i]));
        numbers.forEach((n) => expect(values, contains(n)));

        collective = CollectiveSet<CollectiveValue<int>>(values, onPost: OnPost((c, post) => onPost(c, post)));
        numbers.forEach((n) => expect(collective, contains(n)));
        values.forEach((v) => expect(Element.linkable(v), contains(collective)));

        unmodifiable = Collective<CollectiveValue<int>>.unmodifiable(collective, onPost: OnPost((c, post) => onPost(c, post)));
        numbers.forEach((n) => expect(unmodifiable, contains(n)));
        expect(numbers, containsAll(unmodifiable));
        collective.forEach((e) => expect(unmodifiable, contains(e)));

        runTest();

        final v = values.first;

        values.first.value = 6;
        collective.remove(6);
        expect(collective, allOf([
          isNot(contains(v)),
        ]));
        expect(unmodifiable, allOf([
          isNot(contains(v)),
        ]));
        collective.remove(v);

      }

      print('end');

    });
*//*


*/
/*
    test('Collective<Model>', () {

      { // Collective
        print('\n*** Collective Test ***\n');

        collective = Collective<CollectiveValue<String>>(List<CollectiveValue<String>>.generate(6, (i) => CollectiveValue<String>('$i$i$i$i')), onPost: OnPost((c, post) => onPost(c, post)));
        unmodifiable = Collective<CollectiveValue<String>>.unmodifiable(collective, onPost: OnPost((c, post) => onPost(c, post)));

        runTest();

        // elementUpdated
        collective.first.value = 'aaa';
      }

      { // CollectiveSet
        print('\n*** CollectiveSet Test ***\n');

        collective = CollectiveSet<CollectiveValue<String>>(List<CollectiveValue<String>>.generate(6, (i) => CollectiveValue<String>('$i$i$i$i')), onPost: OnPost((c, post) => onPost(c, post)));
        unmodifiable = Collective.unmodifiable(collective, onPost: OnPost((c, post) => onPost(c, post)));

        runTest();

        // elementUpdated
        collective.first.value = 'aaa';

        final value = CollectiveValue<String>('bbb');

        // elementAdded
        collective.add(value);

        // elementUpdated
        collective.remove(value);
      }

      { // CollectiveCollection
        print('\n*** CollectiveCollection Test ***\n');

        final collective1 = Collective<CollectiveValue<String>>(List<CollectiveValue<String>>.generate(6, (i) => CollectiveValue<String>('c1-$i$i$i$i')), onPost: OnPost((c, post) => onPost(c, post)));
        final collective2 = CollectiveSet<CollectiveValue<String>>(List<CollectiveValue<String>>.generate(6, (i) => CollectiveValue<String>('c2-$i$i$i$i')), onPost: OnPost((c, post) => onPost(c, post)));

        collective = CollectiveCollection.set<CollectiveValue<String>>(Collective([collective1, collective2]), onPost: OnPost((c, post) => onPost(c, post)));
        unmodifiable = Collective.unmodifiable(collective, onPost: OnPost((c, post) => onPost(c, post)));

        runTest();

        // elementUpdated
        collective.first.value = 'c-aaa';

        final collective3 = Collective<CollectiveValue<String>>(List<CollectiveValue<String>>.generate(6, (i) => CollectiveValue<String>('c3-$i$i$i$i')), onPost: OnPost((c, post) => onPost(c, post)));
        {
          print('\n--- Collection addAll and removeAll collective ---\n');

          // elementAdded
          collective.addAll(collective3);

          // elementUpdated
          collective.remove(collective3);
        }

        var value;
        {
          print('\n--- Collection add and remove value ---\n');

          value = CollectiveValue<String>('c-bbb');

          // elementAdded
          collective.add(value);

          // elementUpdated
          collective.remove(value);
        }

        {
          print('\n--- collective2 add and remove value ---\n');

          value = CollectiveValue<String>('c2-ccc');

          // elementAdded
          collective2.add(value);

          // elementUpdated
          collective2.remove(value);
        }

        {
          print('\n--- collective1 update value ---\n');

          // elementUpdate
          collective1.last.value = 'c1-ddd';

        }

      }

      { // CollectiveWhere
        print('\n*** CollectiveWhere Test ***\n');

        final testObj = TestObject<CollectiveValue<int>, dynamic>((v, {on, args, user, others}) => (v as CollectiveValue).value %2 == 0 ? TestMatch.matched : TestMatch.unmatched);

        final values = Collective<CollectiveValue<int>>(List<CollectiveValue<int>>.generate(6, (i) => CollectiveValue<int>(i)), onPost: OnPost((c, post) => onPost(c, post)));
        collective = Collective<CollectiveValue<int>>(values, test: testObj);
        unmodifiable = Collective<CollectiveValue<int>>.unmodifiable(collective, onPost: OnPost((c, post) => onPost(c, post)));
        actual = unmodifiable.toList(growable: false);

        runTest();

        // elementUpdated
        values.first.value = 4;
      }

      { // CollectiveWhere
        print('\n*** CollectiveSetWhere Test ***\n');

        final testObj = TestObject<CollectiveValue<int>, dynamic>((v, {on, args, user, others}) => (v as CollectiveValue).value %2 == 0 ? TestMatch.matched : TestMatch.unmatched);

        final values = CollectiveSet<CollectiveValue<int>>(List<CollectiveValue<int>>.generate(6, (i) => CollectiveValue<int>(i)), onPost: OnPost((c, post) => onPost(c, post)));
        collective = Collective<CollectiveValue<int>>(values, test: testObj);
        unmodifiable = Collective<CollectiveValue<int>>.unmodifiable(collective, onPost: OnPost((c, post) => onPost(c, post)));
        actual = unmodifiable.toList(growable: false);

        runTest();

        // elementUpdated
        values.first.value = 4;

      }

      print('end');

    });



  });
*//*


    group('Collective.element', () {
      setUp(() {
        // Additional setup goes here.
      });

      test('Collective<int>.element - int', () {
        final num = randomBetween(10, 20);

        final value = CollectiveValue<int>(num);
        expect(num, allOf([
          value,
          value.value
        ]));
      });

      test('Collective<String>.element', () {
        final str = randomString(8);

        final value = CollectiveValue<String>(str);
        expect(str, allOf([
          value,
          value.value
        ]));
      });
    });

    group('Collective', () {
      test('Collective<int>', () {
        final elements = List<int>.generate(10, (_) => randomBetween(10, 20))
            .toSet();

        final collective = Collective<int>(elements);
        expect(collective, containsAll(elements));
      });

      test('Collective<String>', () {
        final elements = List<String>.generate(10, (_) => randomString(8));

        final collective = Collective<String>(elements);
        expect(collective.length, elements.length);
        expect(collective, containsAll(elements));
      });

      test('Collective', () {
        final elements = [
          randomAlpha(8),
          randomAlphaNumeric(8),
          randomBetween(10, 20),
          randomMerge(randomString(8), randomString(8)),
          randomString(8),
          randomNumeric(8)
        ];

        final collective = Collective(elements);
        expect(collective, containsAll(elements));
      });

      test('Collective<CollectiveElement>', () {
        final values = List<CollectiveValue>.generate(
            10, (_) => CollectiveValue<String>(randomString(8)));

        final collective = Collective<CollectiveValue>(values);
        expect(collective.length, values.length);
        expect(collective, containsAll(values));
      });
    });
  });

}*/
