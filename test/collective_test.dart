import 'package:cell/collective.dart';
import 'package:random_string/random_string.dart';
import 'package:test/test.dart';

import 'collective_utils_test.dart';

// ignore_for_file: prefer_typing_uninitialized_variables
// ignore_for_file: avoid_function_literals_in_foreach_calls
// ignore_for_file: unused_local_variable
// ignore_for_file: iterable_contains_unrelated_type
// ignore_for_file: avoid_print

void main() {
  var actual, expected;

  var collective, source, unmodifiable, linkable, properties;

  void runTest() {
    actual = unmodifiable.toList(growable: false);
    expected = source.toList(growable: false);
    expect(unmodifiable, allOf([
      hasLength(source.length),
      isA<Unmodifiable>(),
      everyElement(isA<Unmodifiable>()),
      // containsAll(source),
    ]));
  }

  group('Collective', () {

    test('Collective', () {

      {
        final numbers = List<int>.generate(10, (_) => randomBetween(0, 100)).toSet();
        source = Collective(numbers);

        expect(source.length, numbers.length);
        expect(numbers, containsAll(source));
      }

      {
        final values = List.generate(10, (_) => CollectiveValue<int>(randomBetween(0, 100))).toSet();
        source = Collective(values);

        expect(source.length, values.length);
        expect(values, containsAll(source));
      }

    });

    test('Collective.listen', () {
      var ou;
      final values = List.generate(10, (_) => CollectiveValue<int>(randomBetween(0, 100))).toSet();

      {
        collective = Collective(values);

        Cell listenCell = Cell.listen(bind: collective, listen: (s, u) {
          ou = s;
        });

        values.first.value = 2;

        expect(ou, isA<CollectivePost>());
      }

      {
        collective = Collective.create(elements: values,
            receptor: CollectiveReceptor(
                transform: ({required Cell cell, required Signal signal, dynamic user}) {
                  return ou = signal;
                }
        ));

        values.first.value = 3;

        expect(ou, isA<CollectivePost>());
      }

    });

    test('Collective.signaling', () {
      var ou;
      
      {
 
        CollectiveReceptor receptor = CollectiveReceptor<int, Signal, Signal>(
            transform: ({required Cell cell, required Signal signal, dynamic user}) {
              if (cell is Collective) {
                return ou = Signal(cell.toList(growable: false));
              }
              return signal;
            }
        );

        collective = Collective.create<int, List<int>>(
            elements: [1,2,3,4,5,6,7,8,9,10],
            receptor: receptor
        );

        final signal = Signal<int>(1);
        receptor(cell: collective, signal: signal);

        expect(ou.body, isA<Iterable>());
        expect([1,2,3,4,5,6,7,8,9,10], equals(ou.body));
      }
      
      {
        collective = Collective([1,2,3,4,5,6,7,8,9,10]);
      }

    });

    test('CollectiveSet.signaling', () {
      var ou;

      final numbers = List<int>.generate(10, (i) => randomBetween(1, 999));
      final receptor = CollectiveReceptor<int, Signal, Signal>(
          transform: ({required Collective<int> cell, required Signal signal, dynamic user}) {
            try {
              if (signal is CollectivePost) {
                final average = (cell as Iterable<int>).reduce((c, n) => c + n) / cell.length;
                return ou = Signal<double>(average);
              }
            } catch (e) {
              return Signal(e);
            }
            return null;
          }
      );

      collective = CollectiveSet.create(elements: numbers, receptor: receptor);
      collective.add(randomBetween(1, 999));

      expect(ou.body, isA<double>());

      // actual = List<int>.of(collective).average;
      // expect(actual, equals(ou.body));

    });

    test('CollectiveSet.aide', () {

      final numbers = List<int>.generate(10, (i) => randomBetween(1, 999));

      var ou;
      collective = CollectiveSet.create(elements: numbers, receptor: CollectiveReceptor<int, Signal, Signal>(
          transform: ({required Collective<int> cell, required Signal signal, dynamic user}) {
            if (signal is CollectivePost) {
              return ou = Signal(List<int>.of(cell as Iterable<int>).average);
            }
            return null;
          }
      ));

      final aide = collective.deputy();
      aide.add(randomBetween(1, 999));

      expect(ou.body, isA<double>());
      expect(aide, containsAll(collective));

      print('ok');

    });

    test('CollectiveSet a/sync', () async {

      final numbers = List<int>.generate(10, (i) => randomBetween(1, 999));

      var ou;
      final collective = CollectiveSet.create(elements: numbers, receptor: CollectiveReceptor<int, Signal, Signal>(
          transform: ({required Collective<int> cell, required Signal signal, dynamic user}) {
            if (signal is CollectivePost) {
              return ou = Signal(List<int>.of(cell as Iterable<int>).average);
            }
            return null;
          }
      ));


      collective.add(expected = randomBetween(1, 999));
      expect(collective, contains(expected));

      final added = await collective.async.add(expected = randomBetween(1, 999));
      expect(added, isTrue);
      expect(collective, contains(expected));


      expect(ou.body, isA<double>());

      print('ok');

    });

    // test('Cell.test', () {
    //   var ou;
    //   Signal<String> signal = Signal<String>('signal received');
    //   Receptor receptor = Receptor(
    //       map: ({required Cell cell, required Signal signal, dynamic user}) => ou = signal.body
    //   );
    //   Cell cell = Cell(receptor: receptor,
    //       test: TestObject.fromRules(rules: [TestSignalRule(
    //           rule: (Signal s, {Cell? cell, Arguments? arguments, dynamic user}) => s is Signal<int>
    //       )]
    //       ));
    //
    //   receptor(cell: cell, signal: Signal<int>(1));
    //   expect(1, equals(ou));
    //
    //   receptor(cell: cell, signal: Signal<String>('String'));
    //   expect(ou, isNot(isA<String>()));
    //   expect(1, equals(ou));
    //
    // });
    //
    // test('Cell.links', () {
    //   int length = 3;
    //   final signals = List<Signal>.generate(length, (i) => Signal<int>(0));
    //   final cells = List.generate(length, (i) => Cell(
    //       receptor: Receptor(
    //           map: ({required Cell cell, required Signal signal, dynamic user}) {
    //             return signals[i] = signal;
    //           }
    //       )
    //   ));
    //
    //   OpenCell cell = Cell.open();
    //   cells.forEach(cell.link);
    //
    //   Signal s = Signal<int>(1);
    //   cell.receptor(s);
    //   expect(s.body, equals(signals[0].body));
    //   expect(s.body, equals(signals[1].body));
    //   expect(s.body, equals(signals[2].body));
    //
    // });
    //
    // test('Cell.aide', () {
    //   int length = 3;
    //   final signals = List<Signal>.generate(length, (i) => Signal<int>(0));
    //   final cells = List.generate(length, (i) => Cell(
    //       receptor: Receptor(
    //           map: ({required Cell cell, required Signal signal, dynamic user}) {
    //             return signals[i] = signal;
    //           }
    //       )
    //   ));
    //
    //   OpenCell cell = Cell.open();
    //   cells.forEach(cell.link);
    //
    //   OpenCell aide = cell.aide();
    //
    //   Signal s = Signal<int>(1);
    //   aide.receptor(s);
    //   expect(s.body, equals(signals[0].body));
    //   expect(s.body, equals(signals[1].body));
    //   expect(s.body, equals(signals[2].body));
    //
    // });
    //
    // test('Cell CollectiveValue as bind', () {
    //   var ou;
    //   final collective = CollectiveValue<int>(1);
    //   final receptor = Receptor(
    //       map: ({required Cell cell, required Signal signal, dynamic user}) {
    //         return ou = signal;
    //       }
    //   );
    //   final cell = Cell(bind: collective, receptor: receptor);
    //   collective.value = 2;
    //
    //   expect(ou, isA<CollectivePost>());
    //
    // });

  });
}

extension on List<int> {
   double get average => reduce((c,n) => c + n) / length;
}

