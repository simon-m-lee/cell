
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

  var collective, source, unmodifiable, liankable;

  void runTest() {
    actual = unmodifiable.toList(growable: false);
    expected = source.toList(growable: false);
    expect(unmodifiable, allOf([
      hasLength(source.length),
      isA<Unmodifiable>(),
      everyElement(isA<Unmodifiable>()),
      containsAll(source),
    ]));
  }

*/
/*
  test('value', () {
    final value = CollectiveValue<int>(100);
    final unmodifiable = value.toUnmodifiable;

    final uplinks = Element.linkable(value)!.toList();

    expect(value, unmodifiable);
    expect(Element.linkable(value), allOf([
      isNotEmpty,
      hasLength(1),
      contains(unmodifiable),
    ]));

  });
*//*



*/
/*
  test('linkable', () {
    final numbers = [0, 1, 2, 3, 4, 5, 10, 20, 30, 40, 50, 60];
    final values = List<CollectiveValue<int>>.generate(numbers.length, (i) => CollectiveValue<int>(numbers[i]));

    var v,umValue;

    for (int i=0; i<values.length; i++) {
      v = values.elementAt(i);
      expect(Element.linkable(v), allOf([
        liankable = Element.linkable(v)!.toList(growable: false),
        isEmpty,
      ]));
    }

    final unmodifiableValues = values.map<CollectiveValue<int>>((v) {
      return v.toUnmodifiable;
    }).toList(growable: false);

    for (int i=0; i<values.length; i++) {

      v = values.elementAt(i);
      umValue = unmodifiableValues.elementAt(i);

      expect(Element.linkable(v), allOf([
        liankable = Element.linkable(v)!.toList(growable: false),
        isNotEmpty,
        hasLength(1),
        contains(umValue),
      ]));


      expect(Element.linkable(umValue), allOf([
        liankable = Element.linkable(umValue)!.toList(growable: false),
        isEmpty,
      ]));
    }


    { // Collective
      source = Collective<CollectiveValue<int>>(values);
      for (int i=0; i<values.length; i++) {
        v = values.elementAt(i);
        umValue = unmodifiableValues.elementAt(i);

        expect(Element.linkable(v), allOf([
          liankable = Element.linkable(v)!.toList(growable: false),
          isNotEmpty,
          hasLength(2),
          contains(source),
        ]));

        expect(Element.linkable(umValue), allOf([
          liankable = Element.linkable(umValue)!.toList(growable: false),
          isEmpty,
        ]));
      }

      unmodifiable = Collective<CollectiveValue<int>>.unmodifiable(source, onPost: OnPost((c, post) => onPost(c, post)), unmodifiableElement: true);
      expect(Element.linkable(source), allOf([
        hasLength(1),
        contains(unmodifiable),
      ]));

      for (int i=0; i<values.length; i++) {

        v = values.elementAt(i);
        expect(Element.linkable(v), allOf([
          liankable = Element.linkable(v)!.toList(growable: false),
          isNotEmpty,
          hasLength(2),
          contains(source),
          isNot(contains(unmodifiable)),
        ]));

        umValue = unmodifiableValues.elementAt(i);
        expect(Element.linkable(umValue), allOf([
          liankable = Element.linkable(umValue)!.toList(growable: false),
          // isNotEmpty,
          hasLength(1),
          // contains(unmodifiable),
          // isNot(contains(source)),
        ]));
      }

      source = Collective<CollectiveValue<int>>(unmodifiableValues);
      for (int i=0; i<values.length; i++) {

        v = values.elementAt(i);
        expect(Element.linkable(v), allOf([
          liankable = Element.linkable(v)!.toList(growable: false),
          isNotEmpty,
          hasLength(2),
        ]));

        umValue = unmodifiableValues.elementAt(i);
        expect(Element.linkable(umValue), allOf([
          liankable = Element.linkable(umValue)!.toList(growable: false),
          isNotEmpty,
          hasLength(2),
          contains(source),
        ]));
      }

    }


    { // CollectiveSet
      source = CollectiveSet<CollectiveValue<int>>(values, onPost: OnPost((c, post) => onPost(c, post)));
      for (int i=0; i<values.length; i++) {
        v = values.elementAt(i);
        umValue = unmodifiableValues.elementAt(i);

        expect(Element.linkable(v), allOf([
          liankable = Element.linkable(v)!.toList(growable: false),
          isNotEmpty,
          hasLength(3),
          contains(source),
        ]));

        expect(Element.linkable(umValue), allOf([
          liankable = Element.linkable(umValue)!.toList(growable: false),
          isNotEmpty,
          hasLength(2),
        ]));
      }

      unmodifiable = Collective<CollectiveValue<int>>.unmodifiable(source, onPost: OnPost((c, post) => onPost(c, post)), unmodifiableElement: true);
      expect(Element.linkable(source), allOf([
        hasLength(1),
        contains(unmodifiable),
      ]));

      for (int i=0; i<values.length; i++) {

        v = values.elementAt(i);
        expect(Element.linkable(v), allOf([
          liankable = Element.linkable(v)!.toList(growable: false),
          isNotEmpty,
          hasLength(3),
          contains(source),
        ]));

        umValue = unmodifiableValues.elementAt(i);
        expect(Element.linkable(umValue), allOf([
          liankable = Element.linkable(umValue)!.toList(growable: false),
          isNotEmpty,
          hasLength(3),
        ]));
      }
    }

  });
*//*


*/
/*
  group('Collective Iterable', () {

    test('Collective<Model>', () {

      { // Collective
        print('\n*** Collective Test ***\n');

        source = Collective<CollectiveValue<String>>(List<CollectiveValue<String>>.generate(6, (i) => CollectiveValue<String>('$i$i$i$i')), onPost: OnPost((c, post) => onPost(c, post)));
        unmodifiable = Collective<CollectiveValue<String>>.unmodifiable(source, onPost: OnPost((c, post) => onPost(c, post)));

        runTest();

        // elementUpdated
        source.first.value = 'aaa';
      }

      { // CollectiveSet
        print('\n*** CollectiveSet Test ***\n');

        source = CollectiveSet<CollectiveValue<String>>(List<CollectiveValue<String>>.generate(6, (i) => CollectiveValue<String>('$i$i$i$i')), onPost: OnPost((c, post) => onPost(c, post)));
        unmodifiable = Collective.unmodifiable(source, onPost: OnPost((c, post) => onPost(c, post)));

        runTest();

        // elementUpdated
        source.first.value = 'aaa';

        final value = CollectiveValue<String>('bbb');

        // elementAdded
        source.add(value);

        // elementUpdated
        source.remove(value);
      }

      { // CollectiveCollection
        print('\n*** CollectiveCollection Test ***\n');

        final collective1 = Collective<CollectiveValue<String>>(List<CollectiveValue<String>>.generate(6, (i) => CollectiveValue<String>('c1-$i$i$i$i')), onPost: OnPost((c, post) => onPost(c, post)));
        final collective2 = CollectiveSet<CollectiveValue<String>>(List<CollectiveValue<String>>.generate(6, (i) => CollectiveValue<String>('c2-$i$i$i$i')), onPost: OnPost((c, post) => onPost(c, post)));

        source = CollectiveCollection.set<CollectiveValue<String>>({collective1, collective2}, onPost: OnPost((c, post) => onPost(c, post)));
        unmodifiable = Collective.unmodifiable(source, onPost: OnPost((c, post) => onPost(c, post)));

        runTest();

        // elementUpdated
        source.first.value = 'c-aaa';

        final collective3 = Collective<CollectiveValue<String>>(List<CollectiveValue<String>>.generate(6, (i) => CollectiveValue<String>('c3-$i$i$i$i')), onPost: OnPost((c, post) => onPost(c, post)));
        {
          print('\n--- Collection addAll and removeAll source ---\n');

          // elementAdded
          source.addAll(collective3);

          // elementUpdated
          source.removeAll(collective3);
        }

        var value;
        {
          print('\n--- Collection add and remove value ---\n');

          value = CollectiveValue<String>('c-bbb');

          // elementAdded
          source.add(value);

          // elementUpdated
          source.remove(value);
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
        source = Collective<CollectiveValue<int>>(values, test: testObj);
        unmodifiable = Collective<CollectiveValue<int>>.unmodifiable(source, onPost: OnPost((c, post) => onPost(c, post)));
        actual = unmodifiable.toList(growable: false);

        runTest();

        // elementUpdated
        values.first.value = 4;
      }

      { // CollectiveWhere
        print('\n*** CollectiveSetWhere Test ***\n');

        final testObj = TestObject<CollectiveValue<int>, dynamic>((v, {on, args, user, others}) => (v as CollectiveValue).value %2 == 0 ? TestMatch.matched : TestMatch.unmatched);

        final values = CollectiveSet<CollectiveValue<int>>(List<CollectiveValue<int>>.generate(6, (i) => CollectiveValue<int>(i)), onPost: OnPost((c, post) => onPost(c, post)));
        source = Collective<CollectiveValue<int>>(values, test: testObj);
        unmodifiable = Collective<CollectiveValue<int>>.unmodifiable(source, onPost: OnPost((c, post) => onPost(c, post)));
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

    passed('Collective<int>.element - int', () {

      final num = randomBetween(10, 20);

      final value = CollectiveValue<int>(num);
      expect(num, allOf([
        value,
        value.value
      ]));
    });

    passed('Collective<String>.element', () {

      final str = randomString(8);

      final value = CollectiveValue<String>(str);
      expect(str, allOf([
        value,
        value.value
      ]));

    });

  });

  group('Collective', () {


    passed('Collective<int>', () {

      final elements = List<int>.generate(10, (_) => randomBetween(10, 20)).toSet();

      final collective = Collective<int>(elements);
      expect(collective, containsAll(elements));
    });

    passed('Collective<String>', () {

      final elements = List<String>.generate(10, (_) => randomString(8));

      final collective = Collective<String>(elements);
      expect(collective.length, elements.length);
      expect(collective, containsAll(elements));
    });

    passed('Collective', () {

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

    passed('Collective<CollectiveElement>', () {

      final values = List<CollectiveValue>.generate(10, (_) => CollectiveValue<String>(randomString(8)));

      final collective = Collective<CollectiveValue>(values);
      expect(collective.length, values.length);
      expect(collective, containsAll(values));
    });

  });

  group('CollectiveSet', () {

    passed('Collective<int>.set', () {

      final numbers = List<int>.generate(10, (i) => i);

      final collective = Collective.set<int>(numbers);
      expect(collective, containsAll(numbers));
    });

    passed('Collective<String>.set', () {

      final elements = List<String>.generate(10, (_) => randomString(8));

      final collective = Collective.set<String>(elements);
      expect(collective.length, elements.length);
      expect(collective, containsAll(elements));
    });

    passed('Collective.set', () {

      final elements = [
        randomAlpha(8),
        randomAlphaNumeric(8),
        randomBetween(10, 20),
        randomMerge(randomString(8), randomString(8)),
        randomString(8),
        randomNumeric(8)
      ];

      final collective = Collective.set(elements);
      expect(collective, containsAll(elements));
    });

    passed('Collective<CollectiveElement>.set', () {

      final values = List<CollectiveValue>.generate(10, (_) => CollectiveValue<String>(randomString(8)));

      final collective = Collective.set<CollectiveValue>(values);
      expect(collective.length, values.length);
      expect(collective, containsAll(values));
    });

    passed('Collective - add', () {

      final numbers = List<int>.generate(10, (i) => i);
      final collective = Collective.set<int>(numbers) as CollectiveSet<int>;
      
      {
        final unmodifiable = Collective<int>.unmodifiable(collective);

        final num = randomBetween(0,9);
        collective.add(num);

        if (collective.contains(num)) {
          print('ok');
        }

        expect(collective, contains(num));
        expect(unmodifiable, contains(num));
      }
      
      {
        final unmodifiable = CollectiveSet<int>.unmodifiable(collective);

        final num = randomBetween(0,9);
        collective.add(num);

        expect(collective, contains(num));
        expect(unmodifiable, contains(num));
        expect(() => unmodifiable.add(num), throwsUnsupportedError);
      }


    });


    passed('Collective.set - add, remove, addAll, clear, removeAll, removeWhere, retainAll, retainWhere, updateAll, updateWhere', () {

      final elements = List<String>.generate(10, (_) => randomString(8));
      final collective = Collective.set<String>(elements);

      expect(collective.length, elements.length);
      expect(collective, containsAll(elements));
    });


  });

  */
/*group('CollectiveCollection', () {

    test_object('Collective<String>.collection', () {
      final source = Collective<String>(List<String>.generate(10, (_) => randomString(8)));
      final set = Collective<String>.set(List<String>.generate(10, (_) => randomString(8)));

      final collection = Collective<String>.collection([
        source, set
      ]);

      expect(collection, allOf([
        containsAll(source),
        containsAll(set)
      ]));

    });

  });*//*



}
*/
