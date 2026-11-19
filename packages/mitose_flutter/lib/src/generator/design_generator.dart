// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The design generator — assembles the per-screen widget trees
/// (Gate 2).
library;

import '../brd/ast.dart';
import '../brd/design.dart';
import '../brd/walkthrough.dart';
import '../rules/placement_rules.dart';

/// Generates the [Design] for [brd].
Design generateDesign(Brd brd, Walkthrough walkthrough) {
  final stepsByScreen = <String, List<WalkthroughStep>>{};
  for (final step in walkthrough.steps) {
    stepsByScreen.putIfAbsent(step.screen, () => []).add(step);
  }

  final choicesByScreen = <String, List<WidgetChoice>>{};
  for (final req in brd.requirements) {
    choicesByScreen.putIfAbsent(req.screen, () => []).add(place(req, brd));
  }

  final screens = <ScreenDesign>[];
  for (final screen in brd.screens) {
    final choices = choicesByScreen[screen.name] ?? const [];
    screens.add(ScreenDesign(
      name: screen.name,
      route: screen.route,
      tree: _composeScreenTree(screen, choices, brd),
    ));
  }

  final cells = [
    for (final state in brd.state)
      CellDesign(
        name: state.name,
        type: state.type,
        initial: state.initial,
        restorable: state.restorable,
        appLevel: state.appLevel,
      ),
  ];

  return Design(
    title: brd.title,
    screens: screens,
    cells: cells,
    routes: {for (final s in brd.screens) s.name: s.route},
  );
}

List<WidgetNode> _composeScreenTree(
  BrdScreen screen,
  List<WidgetChoice> choices,
  Brd brd,
) {
  final children = <WidgetNode>[];
  for (final choice in choices) {
    switch (choice.widget) {
      case 'CellTextField':
        final state = choice.boundStates.first;
        children.add(WidgetNode(
          type: 'CellTextField',
          fields: {
            'cell': '${state.name}.cell',
            'label': choice.extra['label'] as String? ?? state.name,
          },
        ));
      case 'CellListView':
        final state = choice.boundStates.first;
        children.add(WidgetNode(
          type: 'CellListView',
          fields: {'cell': '${state.name}.cell'},
        ));
      case 'CellAsyncBuilder':
        final state = choice.boundStates.first;
        children.add(WidgetNode(
          type: 'CellAsyncBuilder',
          fields: {'cell': '${state.name}.cell'},
        ));
      case 'CellErrorBoundary':
        children.add(const WidgetNode(
          type: 'CellErrorBoundary',
          fields: {'fallback': "(error) => Text('\$error')"},
        ));
      case 'CellListener':
        children.add(WidgetNode(
          type: 'CellListener',
          fields: {
            'cell': '${choice.boundStates.first.name}.cell',
            'action': choice.extra.toString(),
          },
        ));
      case 'Cell':
        children.add(WidgetNode(
          type: 'Cell',
          fields: {
            'declaration': 'restorableState (${choice.boundStates.first.name})',
          },
        ));
      default:
        children.add(WidgetNode(type: choice.widget));
    }
  }

  final body = WidgetNode(
    type: 'Column',
    children: children,
  );
  final scaffold = WidgetNode(
    type: 'Scaffold',
    fields: {'appBar': "AppBar(title: Text('${screen.name}'))"},
    children: [body],
  );
  return [
    WidgetNode(type: 'CellErrorBoundary', children: [scaffold]),
  ];
}
