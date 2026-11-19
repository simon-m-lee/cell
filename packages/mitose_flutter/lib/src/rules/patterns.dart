// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The eight composition patterns.
///
/// Each pattern produces a [WidgetTemplate] (what the code generator
/// emits) and a [TestTemplate] (what the test generator emits). The
/// templates carry data, not code; Phase C serializes them.
library;

import '../brd/ast.dart';

/// The widget-side template for one placed requirement.
class WidgetTemplate {
  const WidgetTemplate({
    required this.widgetType,
    this.generics = '',
    this.fields = const {},
    this.children = const [],
    this.comment,
  });

  final String widgetType;
  final String generics;
  final Map<String, String> fields;
  final List<WidgetTemplate> children;
  final String? comment;
}

/// The test-side template for one placed requirement.
class TestTemplate {
  const TestTemplate({
    this.setup = '',
    this.pump = '',
    this.interaction = '',
    required this.assertion,
    required this.ledger,
  });

  final String setup;
  final String pump;
  final String interaction;
  final String assertion;
  final String ledger;
}

/// A composition pattern: the seam between a placement rule and the
/// generated code/tests.
abstract class WidgetPattern {
  const WidgetPattern();

  /// The pattern name, matching `docs/placement-guide.md` sections.
  String get name;

  /// The widget template the code generator serializes.
  WidgetTemplate toWidgetTemplate();

  /// The test template the test generator serializes.
  TestTemplate toTestTemplate(BrdRequirement req);

  /// The human-readable binding description for the walkthrough.
  String widgetDetails();
}

/// `CellBuilder<T>` / `CellValueBuilder<T>` — display a cell's value.
class DisplayPattern extends WidgetPattern {
  const DisplayPattern(this.state,
      {required this.displayText, this.list = false});

  final BrdState state;
  final String displayText;
  final bool list;

  @override
  String get name => 'DisplayPattern';

  @override
  WidgetTemplate toWidgetTemplate() {
    if (list) {
      return WidgetTemplate(
        widgetType: 'CellListView',
        generics: '<${_listItemType(state.type)}>',
        fields: {
          'cell': '${state.name}.cell',
          'itemBuilder': '(context, item, index) => Text(item.toString())',
        },
      );
    }
    return WidgetTemplate(
      widgetType: 'CellBuilder',
      generics: '<${state.type}>',
      fields: {
        'cell': '${state.name}.cell',
        'builder': "(_, v) => Text('$displayText')",
      },
    );
  }

  @override
  TestTemplate toTestTemplate(BrdRequirement req) => TestTemplate(
        setup: 'final ${state.name} = '
            'Cell.state<${state.type}>(initial: ${state.initial ?? 'null'});',
        pump: 'await tester.pumpWithCells(\n'
            '  cells: {#${state.name}: ${state.name}.cell},\n'
            '  child: const ${req.screen}Screen(),\n'
            ');',
        assertion: "expect(find.text('$displayText'), findsOneWidget);",
        ledger:
            "LEDGER('${req.id}', 'rendered via ${toWidgetTemplate().widgetType}');",
      );

  @override
  String widgetDetails() => 'bound to #${state.name}';

  static String _listItemType(String listType) {
    final match = RegExp(r'^List<(.+)>$').firstMatch(listType);
    return match?.group(1) ?? 'Object';
  }
}

/// `CellSelector<T, S>` — render a selected slice of a cell.
class SelectorPattern extends WidgetPattern {
  const SelectorPattern(this.state, {required this.selectExpression});

  final BrdState state;
  final String selectExpression;

  @override
  String get name => 'SelectorPattern';

  @override
  WidgetTemplate toWidgetTemplate() => WidgetTemplate(
        widgetType: 'CellSelector',
        generics: '<${state.type}, String>',
        fields: {
          'cell': '${state.name}.cell',
          'select': selectExpression,
          'builder': '(context, selected) => Text(selected)',
        },
      );

  @override
  TestTemplate toTestTemplate(BrdRequirement req) => TestTemplate(
        setup: 'final ${state.name} = '
            'Cell.state<${state.type}>(initial: ${state.initial ?? 'null'});',
        pump: 'await tester.pumpWithCells(\n'
            '  cells: {#${state.name}: ${state.name}.cell},\n'
            '  child: const ${req.screen}Screen(),\n'
            ');',
        assertion: 'expect(find.byType(CellSelector), findsOneWidget);',
        ledger: "LEDGER('${req.id}', 'rendered via CellSelector');",
      );

  @override
  String widgetDetails() => 'bound to #${state.name} (selected slice)';
}

/// `CellAsyncBuilder<T>` — render loading / data / error / empty.
class AsyncPattern extends WidgetPattern {
  const AsyncPattern(
    this.state, {
    this.loadingText = 'Loading...',
    this.errorText,
    this.emptyText,
  });

  final BrdState state;
  final String loadingText;
  final String? errorText;
  final String? emptyText;

  @override
  String get name => 'AsyncPattern';

  @override
  WidgetTemplate toWidgetTemplate() {
    final branches = <String>[
      'if (snapshot.connectionState == ConnectionState.waiting) {',
      "  return const Text('$loadingText');",
      '}',
    ];
    if (errorText != null) {
      branches.addAll([
        'if (snapshot.hasError) {',
        "  return const Text('$errorText');",
        '}',
      ]);
    }
    if (emptyText != null) {
      branches.addAll([
        'if (!snapshot.hasData || snapshot.data.toString().isEmpty) {',
        "  return const Text('$emptyText');",
        '}',
      ]);
    }
    branches.addAll(["return Text('\${snapshot.data}');"]);
    return WidgetTemplate(
      widgetType: 'CellAsyncBuilder',
      generics: '<${state.type}>',
      fields: {
        'cell': '${state.name}.cell',
        'builder': "(context, snapshot) {\n${branches.join('\n')}\n}",
      },
    );
  }

  @override
  TestTemplate toTestTemplate(BrdRequirement req) => TestTemplate(
        setup: 'final ${state.name} = '
            'Cell.state<${state.type}>(initial: ${state.initial ?? 'null'});',
        pump: 'await tester.pumpWithCells(\n'
            '  cells: {#${state.name}: ${state.name}.cell},\n'
            '  child: const ${req.screen}Screen(),\n'
            ');',
        assertion: 'expect(find.byType(CellAsyncBuilder), findsOneWidget);',
        ledger: "LEDGER('${req.id}', 'rendered via CellAsyncBuilder');",
      );

  @override
  String widgetDetails() => 'bound to #${state.name} (async branches)';
}

/// `CellTextField` / `CellFormField<T>` — bind a form field two-way.
class FormPattern extends WidgetPattern {
  const FormPattern(this.state, {required this.labelText});

  final BrdState state;
  final String labelText;

  @override
  String get name => 'FormPattern';

  @override
  WidgetTemplate toWidgetTemplate() => WidgetTemplate(
        widgetType: 'CellTextField',
        fields: {
          'cell': '${state.name}.cell',
          'decoration': "const InputDecoration(labelText: '$labelText')",
        },
      );

  @override
  TestTemplate toTestTemplate(BrdRequirement req) => TestTemplate(
        setup: 'final ${state.name} = '
            'Cell.state<${state.type}>(initial: ${state.initial ?? "''"});',
        pump: 'await tester.pumpWithCells(\n'
            '  cells: {#${state.name}: ${state.name}.cell},\n'
            '  child: const ${req.screen}Screen(),\n'
            ');',
        assertion: "expect(find.text('$labelText'), findsOneWidget);",
        ledger: "LEDGER('${req.id}', 'rendered via CellTextField');",
      );

  @override
  String widgetDetails() => 'bound to #${state.name}';
}

/// `Cell.restorableState<T>` + `CellRestorationScope` — process-kill
/// survival for atomic requirements.
class RestorePattern extends WidgetPattern {
  const RestorePattern(this.state);

  final BrdState state;

  @override
  String get name => 'RestorePattern';

  @override
  WidgetTemplate toWidgetTemplate() => WidgetTemplate(
        widgetType: 'Cell',
        fields: {
          'restorable': state.name,
          'restorationId': "'${state.name}'",
          'initial': state.initial ?? 'null',
        },
        comment: '// Restorable cell declaration; see lib/cells/.',
      );

  @override
  TestTemplate toTestTemplate(BrdRequirement req) => TestTemplate(
        setup: 'final ${state.name} = '
            'restorableState<${state.type}>(\n'
            "  restorationId: '${state.name}',\n"
            '  initial: ${state.initial ?? 'null'},\n'
            ');',
        pump: 'await tester.pumpWithCells(\n'
            '  cells: {#${state.name}: ${state.name}},\n'
            '  child: const ${req.screen}Screen(),\n'
            ');',
        assertion: 'expect(${state.name}.value, isNotNull);',
        ledger: "LEDGER('${req.id}', 'persisted via Cell.restorableState');",
      );

  @override
  String widgetDetails() => 'restorable state #${state.name}';
}

/// `CellRouterStateMirror` / `useCellRouter` — reactive navigation.
///
/// Phase B declares the pattern; the implementation is filled in
/// during Phase C against `cell_flutter_router`'s API (with the
/// documented `Navigator.push` fallback).
class RoutePattern extends WidgetPattern {
  const RoutePattern(this.targetScreen);

  final BrdScreen targetScreen;

  @override
  String get name => 'RoutePattern';

  @override
  WidgetTemplate toWidgetTemplate() => WidgetTemplate(
        widgetType: 'Route',
        fields: {
          'route': targetScreen.route,
        },
        comment: '// TODO(Phase C): RoutePattern implementation.',
      );

  @override
  TestTemplate toTestTemplate(BrdRequirement req) => TestTemplate(
        assertion: "expect(find.text('${targetScreen.name}'), findsOneWidget);",
        ledger: "LEDGER('${req.id}', 'navigated via RoutePattern');",
      );

  @override
  String widgetDetails() => 'navigates to ${targetScreen.name}';
}

/// `Cell.txApply` with compensations — atomic multi-cell updates.
class AuditPattern extends WidgetPattern {
  const AuditPattern(this.states, {required this.action});

  final List<BrdState> states;
  final String action;

  @override
  String get name => 'AuditPattern';

  @override
  WidgetTemplate toWidgetTemplate() => WidgetTemplate(
        widgetType: 'CellListener',
        fields: {
          'cell': '${states.first.name}.cell',
          'onPulse': '(context, pulse) => $action',
        },
      );

  @override
  TestTemplate toTestTemplate(BrdRequirement req) => TestTemplate(
        setup: [
          for (final s in states)
            'final ${s.name} = '
                'Cell.state<${s.type}>(initial: ${s.initial ?? 'null'});',
        ].join('\n'),
        pump: 'await tester.pumpWithCells(\n'
            "  cells: {${states.map((s) => '#${s.name}: ${s.name}.cell').join(', ')}},\n"
            '  child: const ${req.screen}Screen(),\n'
            ');',
        interaction: req.trigger == null
            ? ''
            : "await tester.tap(find.text('${_buttonText(req.trigger!)}'));\n"
                'await tester.pumpAndSettle();',
        assertion: 'expect(tester.takeException(), isNull);',
        ledger: "LEDGER('${req.id}', 'interacted via CellListener');",
      );

  @override
  String widgetDetails() => 'listens to #${states.first.name}';

  static String _buttonText(String trigger) {
    final match = RegExp(r'^(?:tap|press) (.+)$').firstMatch(trigger);
    return match?.group(1) ?? trigger;
  }
}

/// `cell.unmodifiable` passed to a child — isolation.
class IsolationPattern extends WidgetPattern {
  const IsolationPattern(this.state);

  final BrdState state;

  @override
  String get name => 'IsolationPattern';

  @override
  WidgetTemplate toWidgetTemplate() => WidgetTemplate(
        widgetType: 'CellBuilder',
        generics: '<${state.type}>',
        fields: {
          'cell': '${state.name}.cell.unmodifiable',
          'builder': "(_, v) => Text('\$v')",
        },
      );

  @override
  TestTemplate toTestTemplate(BrdRequirement req) => TestTemplate(
        setup: 'final ${state.name} = '
            'Cell.state<${state.type}>(initial: ${state.initial ?? 'null'});',
        pump: 'await tester.pumpWithCells(\n'
            '  cells: {#${state.name}: ${state.name}.cell},\n'
            '  child: const ${req.screen}Screen(),\n'
            ');',
        assertion: 'expect(find.byType(CellBuilder), findsOneWidget);',
        ledger:
            "LEDGER('${req.id}', 'rendered via CellBuilder (unmodifiable)');",
      );

  @override
  String widgetDetails() => 'bound to #${state.name} (unmodifiable)';
}
