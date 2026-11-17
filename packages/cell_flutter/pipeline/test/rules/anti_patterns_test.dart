// Phase B tests: anti-pattern rules.

import 'package:mitose_flutter/src/brd/ast.dart';
import 'package:mitose_flutter/src/rules/anti_patterns.dart';
import 'package:mitose_flutter/src/rules/patterns.dart';
import 'package:test/test.dart';

const _brd = Brd(
  title: 'T',
  schemaVersion: 'flutter-pipeline/v1',
  requirements: [],
  screens: [],
  forms: [],
  state: [],
  context: null,
);

void main() {
  group('registry', () {
    test('has the five documented rules', () {
      expect(allAntiPatternRules.map((r) => r.name), [
        'checkCellInBuild',
        'checkWritableCellToChild',
        'checkRawObserveInWidget',
        'checkSetStateOnCell',
        'checkUnkeyedHookBuilder',
      ]);
    });
  });

  group('checkCellInBuild', () {
    test('fires on a Cell created inside build', () {
      const code = '''
class X extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cell = Cell.state<int>(initial: 0);
    return Text('x');
  }
}
''';
      final violation =
          checkCellInBuild.checkCode(code, 'lib/screens/x_screen.dart');
      expect(violation, isNotNull);
      expect(violation!.subtype, 'CellInBuild');
      expect(violation.fix, contains('initState'));
    });

    test('does not fire on a clean build', () {
      const code = '''
class X extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text('x');
}
''';
      expect(checkCellInBuild.checkCode(code, 'lib/screens/x_screen.dart'),
          isNull);
    });
  });

  group('checkWritableCellToChild', () {
    test('fires on a writable cell field', () {
      const template = WidgetTemplate(
        widgetType: 'CellBuilder',
        fields: {'cell': 'counter.cell'},
      );
      final violation = checkWritableCellToChild.checkTemplate(template, _brd);
      expect(violation, isNotNull);
      expect(violation!.fix, contains('unmodifiable'));
    });

    test('does not fire on an unmodifiable cell field', () {
      const template = WidgetTemplate(
        widgetType: 'CellBuilder',
        fields: {'cell': 'counter.cell.unmodifiable'},
      );
      expect(checkWritableCellToChild.checkTemplate(template, _brd), isNull);
    });
  });

  group('checkRawObserveInWidget', () {
    test('fires on Cell.observe inside a screen file', () {
      const code = 'final link = Cell.observe(source: c, effect: (_) {});';
      final violation =
          checkRawObserveInWidget.checkCode(code, 'lib/screens/x_screen.dart');
      expect(violation, isNotNull);
      expect(violation!.fix, contains('CellListener'));
    });

    test('does not fire on clean screen code', () {
      expect(
        checkRawObserveInWidget.checkCode(
            'return const SizedBox();', 'lib/screens/x_screen.dart'),
        isNull,
      );
    });
  });

  group('checkSetStateOnCell', () {
    test('fires on setState next to a cell write', () {
      const code = '''
setState(() {
  counter.cell.value = 1;
});
''';
      final violation =
          checkSetStateOnCell.checkCode(code, 'lib/screens/x_screen.dart');
      expect(violation, isNotNull);
      expect(violation!.fix, contains('cell.value'));
    });

    test('does not fire on clean code', () {
      expect(
        checkSetStateOnCell.checkCode('return const SizedBox();', 'x.dart'),
        isNull,
      );
    });
  });

  group('checkUnkeyedHookBuilder', () {
    test('fires on an unkeyed HookBuilder near a cell binding', () {
      const code = '''
HookBuilder(builder: (context) {
  return CellBuilder(cell: counter.cell, builder: (_, v) => Text('\$v'));
})
''';
      final violation =
          checkUnkeyedHookBuilder.checkCode(code, 'lib/screens/x_screen.dart');
      expect(violation, isNotNull);
      expect(violation!.subtype, 'UnkeyedHookBuilder');
      expect(violation.fix, contains('Key'));
    });

    test('does not fire on clean code', () {
      expect(
        checkUnkeyedHookBuilder.checkCode('return const SizedBox();', 'x.dart'),
        isNull,
      );
    });
  });

  group('checkAllCodeAntiPatterns', () {
    test('aggregates violations across rules', () {
      const code = '''
Widget build(BuildContext context) {
  final cell = Cell.state<int>(initial: 0);
  return CellBuilder(cell: cell.cell, builder: (_, v) => Text('\$v'));
}
''';
      final violations =
          checkAllCodeAntiPatterns(code, 'lib/screens/x_screen.dart');
      expect(violations, isNotEmpty);
      expect(violations.every((v) => v.responsibility.name.isNotEmpty), isTrue);
    });
  });
}
