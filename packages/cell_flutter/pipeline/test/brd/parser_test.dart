// Phase B tests: BRD parser.

import 'dart:io';

import 'package:mitose_flutter/src/brd/ast.dart';
import 'package:mitose_flutter/src/brd/parser.dart';
import 'package:test/test.dart';

String _example(String stem) =>
    File('example/brds/$stem.bfd.md').readAsStringSync();

void main() {
  test('form_heavy parses into the expected AST', () {
    final brd = parseBrd(_example('form_heavy'));
    expect(brd.title, 'Login Flow');
    expect(brd.schemaVersion, 'flutter-pipeline/v1');
    expect(brd.requirements, hasLength(5));
    expect(brd.screens, hasLength(2));
    expect(brd.forms, hasLength(1));
    expect(brd.state, hasLength(4));

    final first = brd.requirements.first;
    expect(first.id, 'REQ-001');
    expect(first.sentence, 'User sees the email field');
    expect(first.screen, 'Login');
    expect(first.trigger, isNull);
    expect(first.type, RequirementType.display);

    final submit = brd.requirements[2];
    expect(submit.trigger, 'tap Sign in');
    expect(submit.type, RequirementType.interaction);

    final auth = brd.state.first;
    expect(auth.name, 'auth');
    expect(auth.type, 'AuthState');
    expect(auth.initial, 'AuthState.signedOut');
    expect(auth.restorable, isTrue);
    expect(auth.appLevel, isTrue);
  });

  test('list_heavy parses', () {
    final brd = parseBrd(_example('list_heavy'));
    expect(brd.title, 'Todo List');
    expect(brd.requirements, hasLength(5));
    expect(brd.forms, isEmpty);
    expect(brd.context, contains('todo list'));
    final todos = brd.state.first;
    expect(todos.type, 'List<Todo>');
    expect(todos.isListType, isTrue);
  });

  test('async_heavy parses (triggers on display rows are preserved)', () {
    final brd = parseBrd(_example('async_heavy'));
    expect(brd.requirements, hasLength(7));
    final loading = brd.requirements[2]; // REQ-003 display w/ trigger
    expect(loading.type, RequirementType.display);
    expect(loading.trigger, 'type in search field');
  });

  test('parse is deterministic (round-trip of source)', () {
    for (final stem in ['form_heavy', 'list_heavy', 'async_heavy']) {
      final source = _example(stem);
      final once = parseBrd(source);
      final twice = parseBrd(source);
      expect(once, twice, reason: '$stem parses identically twice');
    }
  });

  test('a BRD without Forms/Context parses with empty values', () {
    const minimal = '''
---
schema: flutter-pipeline/v1
title: Hello
version: 1
---

## Requirements

| ID | Sentence | Screen | Trigger | Outcome | Type |
|---|---|---|---|---|---|
| REQ-001 | User sees the greeting | Home | | Rendered | display |

## Screens

| Name | Route | Widgets |
|---|---|---|
| Home | / | CellBuilder |

## State

| Name | Type | Initial | Restorable | AppLevel |
|---|---|---|---|---|
| greeting | String | 'Hi' | no | yes |
''';
    final brd = parseBrd(minimal);
    expect(brd.forms, isEmpty);
    expect(brd.context, isNull);
    expect(brd.stateByName('greeting')?.initial, "'Hi'");
  });
}
