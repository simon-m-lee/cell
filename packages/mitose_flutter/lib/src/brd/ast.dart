// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The BRD AST — the in-memory form of a parsed, validated BRD.
///
/// Mirrors `docs/brd-schema.json` (`flutter-pipeline/v1`).
library;

/// The parsed form of a BRD.
class Brd {
  const Brd({
    required this.title,
    required this.schemaVersion,
    required this.requirements,
    required this.screens,
    required this.forms,
    required this.state,
    required this.context,
  });

  final String title;
  final String schemaVersion;
  final List<BrdRequirement> requirements;
  final List<BrdScreen> screens;
  final List<BrdForm> forms;
  final List<BrdState> state;
  final String? context;

  BrdScreen? screenByName(String name) =>
      screens.where((s) => s.name == name).firstOrNull;

  BrdState? stateByName(String name) =>
      state.where((s) => s.name == name).firstOrNull;

  BrdForm? formByName(String name) =>
      forms.where((f) => f.name == name).firstOrNull;

  @override
  bool operator ==(Object other) =>
      other is Brd &&
      other.title == title &&
      other.schemaVersion == schemaVersion &&
      listEquals(other.requirements, requirements) &&
      listEquals(other.screens, screens) &&
      listEquals(other.forms, forms) &&
      listEquals(other.state, state) &&
      other.context == context;

  @override
  int get hashCode => Object.hash(
      title, schemaVersion, requirements, screens, forms, state, context);

  @override
  String toString() => 'Brd($title, ${requirements.length} requirements, '
      '${screens.length} screens, ${state.length} state)';
}

/// A single requirement row from `## Requirements`.
class BrdRequirement {
  const BrdRequirement({
    required this.id,
    required this.sentence,
    required this.screen,
    required this.trigger,
    required this.outcome,
    required this.type,
  });

  final String id;
  final String sentence;
  final String screen;
  final String? trigger;
  final String outcome;
  final RequirementType type;

  @override
  bool operator ==(Object other) =>
      other is BrdRequirement &&
      other.id == id &&
      other.sentence == sentence &&
      other.screen == screen &&
      other.trigger == trigger &&
      other.outcome == outcome &&
      other.type == type;

  @override
  int get hashCode => Object.hash(id, sentence, screen, trigger, outcome, type);

  @override
  String toString() => 'BrdRequirement($id, $type, "$sentence")';
}

/// The requirement kind; drives placement and LEDGER kinds.
enum RequirementType {
  display,
  interaction,
  recovery,
  atomic;

  static RequirementType? tryParse(String value) => switch (value.trim()) {
        'display' => display,
        'interaction' => interaction,
        'recovery' => recovery,
        'atomic' => atomic,
        _ => null,
      };
}

/// A single row from `## Screens`.
class BrdScreen {
  const BrdScreen({
    required this.name,
    required this.route,
    required this.widgets,
  });

  final String name;
  final String route;
  final List<String> widgets;

  @override
  bool operator ==(Object other) =>
      other is BrdScreen &&
      other.name == name &&
      other.route == route &&
      listEquals(other.widgets, widgets);

  @override
  int get hashCode => Object.hash(name, route, widgets);

  @override
  String toString() => 'BrdScreen($name, $route)';
}

/// A single row from the optional `## Forms` table.
class BrdForm {
  const BrdForm({required this.name, required this.fields, this.validator});

  final String name;
  final List<String> fields;
  final String? validator;

  @override
  bool operator ==(Object other) =>
      other is BrdForm &&
      other.name == name &&
      listEquals(other.fields, fields) &&
      other.validator == validator;

  @override
  int get hashCode => Object.hash(name, fields, validator);

  @override
  String toString() => 'BrdForm($name, fields: $fields)';
}

/// A single row from `## State`.
class BrdState {
  const BrdState({
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

  bool get isListType => RegExp(r'^List<').hasMatch(type);

  @override
  bool operator ==(Object other) =>
      other is BrdState &&
      other.name == name &&
      other.type == type &&
      other.initial == initial &&
      other.restorable == restorable &&
      other.appLevel == appLevel;

  @override
  int get hashCode => Object.hash(name, type, initial, restorable, appLevel);

  @override
  String toString() => 'BrdState($name: $type)';
}

bool listEquals(List<Object> a, List<Object> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
