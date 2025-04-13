
// import 'package:random_string/random_string.dart';


import 'collective_utils_test.dart';

// ignore_for_file: prefer_typing_uninitialized_variables
// ignore_for_file: avoid_function_literals_in_foreach_calls
// ignore_for_file: unused_local_variable
// ignore_for_file: iterable_contains_unrelated_type
// ignore_for_file: unused_element
// ignore_for_file: avoid_print

/*
var eventNum = 0;

void onPost(Cell? collective, CollectiveReceptor post) {
  if (post is CollectivePost) {
    print('Event: $eventNum');
    print('Post: ${post.runtimeType} ${identityHashCode(post)}');
    print('From: ${post.from.runtimeType} ${identityHashCode(post.from)}');
    print('To: ${collective.runtimeType}');
    for (var en in post.entries) {
      if (en.key == Collective.elementAdded) {
        en.value.forEach((e) => print('elementAdded: ${e.runtimeType} value: ${e.value}'));
      }
      else if (en.key == Collective.elementRemoved) {
        en.value.forEach((e) => print('elementRemoved: ${e.runtimeType} value: ${e.value}'));
      }
      else if (en.key == Collective.elementUpdated) {
        en.value.forEach((e) => print('elementUpdated: ${e.runtimeType} before: ${e.before}, after: ${e.after}'));
      }
    }

    print('\n');
  }
}

void main() {
  var actual, expected;

  var source, collectiveWhere, unmodifiable, parents, where, linkable;

  // final testObj = TestObject<CollectiveValue<int>, dynamic>((v, {on, args, user, others}) => (v as CollectiveValue) >= 10 ? TestMatch.matched : TestMatch.unmatched);

  void runTest() {
    // actual = unmodifiable.toList(growable: false);
    // expected = collective.toList(growable: false);
    expect(unmodifiable, allOf([
      hasLength(source.length),
      isA<Unmodifiable>(),
      everyElement(isA<Unmodifiable>()),
      containsAll(source),
    ]));
  }

  group('CollectiveWhere', () {
    var where;

*/
/*
    test('parents', () {
      final numbers = [0, 1, 2, 3, 4, 5, 10, 20, 30, 40, 50, 60];
      final values = List<CollectiveValue<int>>.generate(numbers.length, (i) => CollectiveValue<int>(numbers[i]));
      final unmodifiableValues = values.map<CollectiveValue<int>>((v) => v.toUnmodifiable).toList(growable: false);

      source = CollectiveSet<CollectiveValue<int>>(values, onPost: OnPost((c, post) => onPost(c, post)));
      unmodifiable = Collective<CollectiveValue<int>>.unmodifiable(source, onPost: OnPost((c, post) => onPost(c, post)));

      expect(Element.linkable(source), allOf([
        hasLength(1),
        contains(unmodifiable),
      ]));

      values.forEach((v) => expect(Element.linkable(v), allOf([
        parents = Element.linkable(v)!.toList(growable: false),
        hasLength(2),
        contains(source),
      ])));

      unmodifiableValues.forEach((v) => expect(Element.linkable(v), allOf([
        parents = Element.linkable(v)!.toList(growable: false),
        hasLength(1),
      ])));

    });
*//*


*/
/*
    test('CollectiveWhere(..., {unmodifiableElement: false})', () {
      final numbers = [0, 1, 2, 3, 4, 5, 10, 20, 30, 40, 50, 60];
      final values = List<CollectiveValue<int>>.generate(numbers.length, (i) => CollectiveValue<int>(numbers[i]));
      source = CollectiveSet<CollectiveValue<int>>(values, onPost: OnPost((c, post) => onPost(c, post)));

      expect(source.containsAll(numbers), isTrue);

      { // CollectiveWhere (Unmodifiable)
        where = Collective<CollectiveValue<int>>(source, test: testObj, onPost: OnPost((c, post) => onPost(c, post)));
        actual = where.toList(growable: false);
        expect(where, allOf([
          isA<Unmodifiable>(),
          everyElement(allOf([
            isNot(isA<Unmodifiable>()),
            // isA<CollectiveValueWhere>()
          ])),
        ]));

        { // value
          eventNum++;
          { // elementUpdated
            expect(() => values.firstWhere((e) => testObj(e, on: where)).value = 100, returnsNormally);
          }

          eventNum++;
          { // elementAdded
            expect(() => values.firstWhere((e) => testObj(e, on: where) == false).value = 100, returnsNormally);
          }

          eventNum++;
          { // elementRemoved
            expect(() => values.firstWhere((e) => testObj(e, on: where)).value = 6, returnsNormally);
          }

        }

        { // where
          eventNum++;
          {
            expect(() => where.firstWhere((e) => testObj(e, on: where)).value = 6, returnsNormally);
          }

          eventNum++;
          { // elementUpdated
            expect(() => where.firstWhere((e) => testObj(e, on: where)).value = 200, returnsNormally);
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
      source = CollectiveSet<CollectiveValue<int>>(values, onPost: OnPost((c, post) => onPost(c, post)));

      expect(source.containsAll(numbers), isTrue);

      { // CollectiveWhere (Unmodifiable)
        where = Collective<CollectiveValue<int>>(source, test: testObj, onPost: OnPost((c, post) => onPost(c, post)));
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
            expect(() => values.firstWhere((e) => testObj(e, on: where)).value = 100, returnsNormally);
          }

          eventNum++;
          { // elementAdded
            expect(() => values.firstWhere((e) => testObj(e, on: where) == false).value = 100, returnsNormally);
          }

          eventNum++;
          { // elementRemoved
            expect(() => values.firstWhere((e) => testObj(e, on: where)).value = 6, returnsNormally);
          }

        }

        { // where
          eventNum++;
          {
            expect(() => where.firstWhere((e) => testObj(e, on: where)).value = 6, returnsNormally);
          }

          eventNum++;
          { // elementUpdated
            expect(() => where.firstWhere((e) => testObj(e, on: where)).value = 2, returnsNormally);
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
      source = CollectiveSet<CollectiveValue<int>>(values, onPost: OnPost((c, post) => onPost(c, post)));

      expect(source.containsAll(numbers), isTrue);

      { // CollectiveSetWhere {syncCollective: false}
        where = CollectiveSet<CollectiveValue<int>>(source, test: testObj, onPost: OnPost((c, post) => onPost(c, post)));
        expect(where, allOf([
          hasLength(values.where((e) => testObj(e, on: where)).length),
          // everyElement(isA<CollectiveValueWhere>()),
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
            expect(() => values.firstWhere((e) => testObj(e, on: where)).value = 100, returnsNormally);
          }

          eventNum++;
          {
            expect(() => values.firstWhere((e) => testObj(e, on: where)).value = 6, returnsNormally);
          }

        }

        { // where
          eventNum++;
          {
            expect(() => where.firstWhere((e) => testObj(e, on: where)).value = 6, returnsNormally);
          }

          eventNum++;
          {
            expect(() => where.firstWhere((e) => testObj(e, on: where)).value = 200, returnsNormally);
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
    test('CollectiveSetWhere(..., {syncCollective: true})', () {
      final numbers = [0, 1, 2, 3, 4, 5, 10, 20, 30, 40, 50, 60];
      final values = List<CollectiveValue<int>>.generate(numbers.length, (i) => CollectiveValue<int>(numbers[i]));
      source = CollectiveSet<CollectiveValue<int>>(values, onPost: OnPost((c, post) => onPost(c, post)));

      { // CollectiveSetWhere {syncCollective: true}
        where = CollectiveSet<CollectiveValue<int>>(source, test: testObj, onPost: OnPost((c, post) => onPost(c, post)));

        // Unmodifiable {unmodifiableElement: true}
        unmodifiable = Collective<CollectiveValue<int>>.unmodifiable(where, unmodifiableElement: true, onPost: OnPost((c, post) => onPost(c, post)));
        expect(unmodifiable, allOf([
          containsAll(where),
          isA<Unmodifiable>(),
          everyElement(isA<Unmodifiable>()),
        ]));

        { // value
          eventNum++;
          {
            expect(() => values.firstWhere((e) => testObj(e, on: where)).value = 100, returnsNormally);
          }

          eventNum++;
          {
            expect(() => values.firstWhere((e) => testObj(e, on: where)).value = 6, returnsNormally);
          }

        }

        { // where
          eventNum++;
          {
            expect(() => where.firstWhere((e) => testObj(e, on: where)).value = 6, returnsNormally);
          }

          eventNum++;
          {
            expect(() => where.firstWhere((e) => testObj(e, on: where)).value = 200, returnsNormally);
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

  });


}
*/
