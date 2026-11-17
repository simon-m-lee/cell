// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The design — a per-screen widget tree specification (Gate 2).
library;

import '../brd/ast.dart';

/// The design of a single screen.
class ScreenDesign {
  const ScreenDesign({
    required this.name,
    required this.route,
    required this.tree,
  });

  final String name;
  final String route;
  final List<WidgetNode> tree;
}

/// A node in a screen's widget tree.
class WidgetNode {
  const WidgetNode({
    required this.type,
    this.fields = const {},
    this.children = const [],
  });

  final String type;
  final Map<String, String> fields;
  final List<WidgetNode> children;

  String toYaml([String indent = '- ']) {
    final buffer = StringBuffer();
    buffer.writeln('$indent$type:');
    for (final entry in fields.entries) {
      buffer.writeln('$indent  ${entry.key}: ${entry.value}');
    }
    for (final child in children) {
      buffer.write(child.toYaml('$indent  '));
    }
    return buffer.toString();
  }
}

/// The design of a single cell.
class CellDesign {
  const CellDesign({
    required this.name,
    required this.type,
    required this.initial,
    required this.restorable,
    required this.appLevel,
  });

  final String name;
  final String type;
  final String? initial;
  final bool restorable;
  final bool appLevel;
}

/// The design of a Flutter app — a widget tree specification.
class Design {
  const Design({
    required this.title,
    required this.screens,
    required this.cells,
    required this.routes,
    this.schemaVersion = 'flutter-pipeline/v1',
  });

  final String title;
  final List<ScreenDesign> screens;
  final List<CellDesign> cells;
  final Map<String, String> routes;
  final String schemaVersion;

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Design: $title')
      ..writeln()
      ..writeln('**Schema:** $schemaVersion')
      ..writeln('**Screens:** ${screens.length}')
      ..writeln('**Cells:** ${cells.length}')
      ..writeln();
    for (final screen in screens) {
      buffer
        ..writeln('## Screen: ${screen.name} (route: ${screen.route})')
        ..writeln()
        ..writeln('```yaml');
      for (final node in screen.tree) {
        buffer.write(node.toYaml());
      }
      buffer
        ..writeln('```')
        ..writeln();
    }
    buffer
      ..writeln('## Cells')
      ..writeln()
      ..writeln('| Name | Type | Initial | Restorable | AppLevel |')
      ..writeln('|---|---|---|---|---|');
    for (final cell in cells) {
      buffer.writeln('| ${cell.name} | ${cell.type} | ${cell.initial ?? ''} | '
          '${cell.restorable ? 'yes' : 'no'} | '
          '${cell.appLevel ? 'yes' : 'no'} |');
    }
    return buffer.toString();
  }
}

/// The list of Dart builtin types the generator does not synthesize.
const builtinTypes = {
  'String',
  'int',
  'double',
  'bool',
  'Object',
  'Object?',
};

/// Returns the bare name of a (possibly generic) type expression.
String bareTypeName(String type) =>
    type.replaceAll(RegExp(r'<.*>$'), '').trim();

/// Whether [type] is a Dart builtin.
bool isBuiltin(String type) => builtinTypes.contains(bareTypeName(type));

/// The custom type names referenced by a state row's type/initial.
List<String> referencedCustomTypes(Brd brd) {
  final names = <String>{};
  for (final state in brd.state) {
    for (final match in RegExp(r'[A-Z]\w+').allMatches(state.type)) {
      final name = match.group(0)!;
      if (!isBuiltin(name)) names.add(name);
    }
    final initial = state.initial;
    if (initial != null) {
      for (final match in RegExp(r'[A-Z]\w+').allMatches(initial)) {
        final name = match.group(0)!;
        if (!isBuiltin(name) && !['Cell', 'AsyncValue'].contains(name)) {
          names.add(name);
        }
      }
    }
  }
  // SearchResult etc. referenced via a type only.
  for (final state in brd.state) {
    final bare = bareTypeName(state.type);
    if (!isBuiltin(bare)) names.add(bare);
  }
  return names.toList()..sort();
}
