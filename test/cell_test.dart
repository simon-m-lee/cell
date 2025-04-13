import 'package:cell/collective.dart';
import 'package:test/test.dart';

import 'collective_utils_test.dart';

// ignore_for_file: prefer_typing_uninitialized_variables

void main() {
  var actual, expected;

  var source, unmodifiable, linkable, properties;

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

  group('Cell', () {

    test('Cell', () {
      Signal ou = Signal();
      Signal signal = Signal('signal received');
      Receptor receptor = Receptor(
          transform: ({required Cell cell, required Signal signal, dynamic user}) {
            return ou = signal;
          }
      );
      Cell cell = Cell(receptor: receptor);
      receptor(cell: cell, signal: signal);

      expect(signal.body, equals(ou.body));
    });

    test('Cell.listen', () {
      var ou;
      Signal<String> signal = Signal<String>('signal received');
      Receptor receptor = Receptor(
          transform: ({required Cell cell, required Signal signal, dynamic user}) => ou = signal
      );
      Cell cell = Cell(receptor: receptor);
      receptor(cell: cell, signal: signal);

      Cell listenCell = Cell.listen(bind: cell, listen: (s, u) => ou = s);
      receptor(cell: cell, signal: signal);

      expect(signal.body, equals(ou.body));
    });

    test('Cell.open', () {
      var openCell = Cell.open();

      var ou;
      final cell = Cell.listen(bind: openCell, listen: (s, u) {
        ou = s;
      });

      var signal = Signal('signal');
      openCell.receptor(signal);

      expect(true, identical(signal, ou));
    });

    test('Cell.test', () async {
      var ou;
      Signal<String> signal = Signal<String>('signal received');
      Receptor receptor = Receptor(
          transform: ({required Cell cell, required Signal signal, dynamic user}) {
            return ou = signal.body;
          }
      );
      Cell cell = Cell(receptor: receptor,
          test: TestObject.fromRules(rules: [TestSignalRule(
              rule: (Signal s, {Cell? cell, Arguments? arguments, dynamic user}) {
                return s is Signal<int>;
              }
          )]
      ));

      receptor(cell: cell, signal: Signal<int>(1));
      expect(1, equals(ou));

      final actual = await receptor.async(cell: cell, signal: Signal<String>('String'));
      expect(1, equals(ou));

      receptor(cell: cell, signal: Signal<String>('String'));
      expect(ou, isNot(isA<String>()));
      expect(1, equals(ou));

    });

    test('Cell.links', () {
      int length = 3;
      final signals = List<Signal>.generate(length, (i) => Signal<int>(0));
      final cells = List.generate(length, (i) => Cell(
          receptor: Receptor(
              transform: ({required Cell cell, required Signal signal, dynamic user}) {
                return signals[i] = signal;
              }
          )
      ));

      OpenCell cell = Cell.open();
      cells.forEach(cell.link);

      Signal s = Signal<int>(1);
      cell.receptor(s);
      expect(s.body, equals(signals[0].body));
      expect(s.body, equals(signals[1].body));
      expect(s.body, equals(signals[2].body));

    });

    test('Cell.aide', () {
      int length = 3;
      final signals = List<Signal>.generate(length, (i) => Signal<int>(0));
      final cells = List.generate(length, (i) => Cell(
          receptor: Receptor(
              transform: ({required Cell cell, required Signal signal, dynamic user}) {
                return signals[i] = signal;
              }
          )
      ));

      OpenCell cell = Cell.open();
      cells.forEach(cell.link);

      OpenCell aide = cell.deputy();

      Signal s = Signal<int>(1);
      aide.receptor(s);
      expect(s.body, equals(signals[0].body));
      expect(s.body, equals(signals[1].body));
      expect(s.body, equals(signals[2].body));

    });


    test('Cell CollectiveValue as bind', () {
      var ou;
      final collective = CollectiveValue<int>(1);
      final receptor = Receptor(
          transform: ({required Cell cell, required Signal signal, dynamic user}) {
            return ou = signal;
          }
      );
      final cell = Cell(bind: collective, receptor: receptor);
      collective.value = 2;

      expect(ou, isA<CollectivePost>());

    });

  });

}


