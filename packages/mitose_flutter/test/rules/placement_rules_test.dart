// Phase B tests: placement rules.

import 'dart:io';

import 'package:mitose_flutter/src/brd/ast.dart';
import 'package:mitose_flutter/src/brd/parser.dart';
import 'package:mitose_flutter/src/failures.dart';
import 'package:mitose_flutter/src/rules/placement_rules.dart';
import 'package:test/test.dart';

Brd _load(String stem) =>
    parseBrd(File('example/brds/$stem.bfd.md').readAsStringSync());

Matcher contextFailure({String? reasonContains, String? fixContains}) {
  TypeMatcher<UnplaceableSentence> m = isA<UnplaceableSentence>()
      .having((e) => e.subtype, 'subtype', 'ContextCheckFailed');
  if (reasonContains != null) {
    m = m.having((e) => e.reason, 'reason', contains(reasonContains));
  }
  if (fixContains != null) {
    m = m.having((e) => e.fix, 'fix', contains(fixContains));
  }
  return throwsA(m);
}

void main() {
  group('per-rule behavior', () {
    test('placeDisplayField matches the field sentence', () {
      final brd = _load('form_heavy');
      final choice = placeDisplayField(brd.requirements[0], brd);
      expect(choice, isNotNull);
      expect(choice!.widget, 'CellTextField');
      expect(choice.boundStates.single.name, 'email');
    });

    test('placeDisplayField returns null on unrelated sentences', () {
      final brd = _load('form_heavy');
      expect(placeDisplayField(brd.requirements[2], brd), isNull);
      expect(placeDisplayField(brd.requirements[4], brd), isNull);
    });

    test('placeDisplayField throws when the field is missing', () {
      const mutated = '''
---
schema: flutter-pipeline/v1
title: X
version: 1
---

## Requirements

| ID | Sentence | Screen | Trigger | Outcome | Type |
|---|---|---|---|---|---|
| REQ-001 | User sees the email field | Login | | Rendered | display |

## Screens

| Name | Route | Widgets |
|---|---|---|
| Login | /login | CellTextField |

## State

| Name | Type | Initial | Restorable | AppLevel |
|---|---|---|---|---|
| other | String | '' | no | no |
''';
      final req = parseBrd(mutated).requirements.single;
      expect(
        () => placeDisplayField(req, parseBrd(mutated)),
        contextFailure(reasonContains: 'email', fixContains: '## State'),
      );
    });

    test('placeDisplayList matches and binds the list state', () {
      final brd = _load('list_heavy');
      final choice = placeDisplayList(brd.requirements[0], brd);
      expect(choice, isNotNull);
      expect(choice!.widget, 'CellListView');
      expect(choice.boundStates.single.name, 'todos');
    });

    test('placeDisplayText matches the generic display sentence', () {
      const brdText = '''
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
      final brd = parseBrd(brdText);
      final choice = placeDisplayText(brd.requirements.single, brd);
      expect(choice, isNotNull);
      expect(choice!.widget, 'CellBuilder');
    });

    test('placeInteractionForm binds submit + fields and the target screen',
        () {
      final brd = _load('form_heavy');
      final choice = placeInteractionForm(brd.requirements[2], brd);
      expect(choice, isNotNull);
      expect(choice!.widget, 'CellListener');
      expect(choice.extra['targetScreen'], 'Home');
      expect(choice.boundStates.map((s) => s.name), contains('submit'));
    });

    test('placeInteractionList matches add/delete/reorder', () {
      final brd = _load('list_heavy');
      for (final index in [1, 2, 3]) {
        final choice = placeInteractionList(brd.requirements[index], brd);
        expect(choice, isNotNull, reason: 'REQ-${index + 1}');
        expect(choice!.widget, 'CellListener');
        expect(choice.boundStates.single.name, 'todos');
      }
    });

    test('placeInteractionRetry binds the async state', () {
      final brd = _load('async_heavy');
      final choice = placeInteractionRetry(brd.requirements[6], brd);
      expect(choice, isNotNull);
      expect(choice!.boundStates.single.name, 'searchResults');
    });

    test('placeInteractionDebounce binds the query field and async state', () {
      final brd = _load('async_heavy');
      final choice = placeInteractionDebounce(brd.requirements[1], brd);
      expect(choice, isNotNull);
      expect(choice!.boundStates.map((s) => s.name),
          containsAll(['searchQuery', 'searchResults']));
    });

    test('placeRecoveryValidation captures the error text', () {
      final brd = _load('form_heavy');
      final choice = placeRecoveryValidation(brd.requirements[3], brd);
      expect(choice, isNotNull);
      expect(choice!.widget, 'CellErrorBoundary');
      expect(choice.extra['errorText'], 'Email is required');
    });

    test('placeRecoveryNetwork captures the error text', () {
      final brd = _load('async_heavy');
      final choice = placeRecoveryNetwork(brd.requirements[4], brd);
      expect(choice, isNotNull);
      expect(choice!.widget, 'CellAsyncBuilder');
      expect(choice.extra['errorText'], 'Search failed');
    });

    test('placeRecoveryEmpty captures the empty text', () {
      final brd = _load('async_heavy');
      final choice = placeRecoveryEmpty(brd.requirements[5], brd);
      expect(choice, isNotNull);
      expect(choice!.extra['emptyText'], 'No results');
    });

    test('placeAtomicTransaction requires a restorable state', () {
      final brd = _load('list_heavy');
      final choice = placeAtomicTransaction(brd.requirements[4], brd);
      expect(choice, isNotNull);
      expect(choice!.widget, 'CellListener');
      expect(choice.boundStates.single.name, 'todos');
    });

    test('placeAtomicTransaction fails when the state is not restorable', () {
      final text = File('example/brds/list_heavy.bfd.md')
          .readAsStringSync()
          .replaceFirst('| todos | List<Todo> | [] | yes | yes |',
              '| todos | List<Todo> | [] | no | yes |');
      final mutated = parseBrd(text);
      expect(
        () => placeAtomicTransaction(mutated.requirements[4], mutated),
        contextFailure(fixContains: 'Restorable: yes'),
      );
    });

    test('placeDisplayLoading and placeDisplaySuccess bind the async state',
        () {
      final brd = _load('async_heavy');
      final loading = placeDisplayLoading(brd.requirements[2], brd);
      final success = placeDisplaySuccess(brd.requirements[3], brd);
      expect(loading, isNotNull);
      expect(success, isNotNull);
      expect(loading!.widget, 'CellAsyncBuilder');
      expect(success!.widget, 'CellAsyncBuilder');
      expect(loading.boundStates.single.name, 'searchResults');
    });
  });

  group('dispatcher', () {
    test('NoRuleMatches fires for an unplaceable sentence', () {
      final brd = _load('form_heavy');
      final req = brd.requirements[0];
      const unknown = BrdRequirement(
        id: 'REQ-999',
        sentence: 'User can export the results as CSV',
        screen: 'Login',
        trigger: null,
        outcome: 'CSV downloaded',
        type: RequirementType.interaction,
      );
      // The sentence names nothing in State; also ensure no matcher:
      expect(
        () => place(unknown, brd),
        throwsA(isA<UnplaceableSentence>()
            .having((e) => e.subtype, 'subtype', 'NoRuleMatches')
            .having((e) => e.responsibility, 'responsibility',
                FailureResponsibility.pipelineMaintainer)),
      );
      expect(req, isNotNull);
    });
  });

  group('end-to-end placement (the three acceptance BRDs)', () {
    test('form_heavy — every requirement places with the right widget', () {
      final brd = _load('form_heavy');
      final widgets = [
        for (final req in brd.requirements) place(req, brd).widget,
      ];
      expect(widgets, [
        'CellTextField', // REQ-001
        'CellTextField', // REQ-002
        'CellListener', // REQ-003
        'CellErrorBoundary', // REQ-004
        'CellErrorBoundary', // REQ-005
      ]);
    });

    test('list_heavy — every requirement places with the right widget', () {
      final brd = _load('list_heavy');
      final widgets = [
        for (final req in brd.requirements) place(req, brd).widget,
      ];
      expect(widgets, [
        'CellListView', // REQ-001
        'CellListener', // REQ-002
        'CellListener', // REQ-003
        'CellListener', // REQ-004
        'CellListener', // REQ-005 (txApply audit)
      ]);
    });

    test('async_heavy — every requirement places with the right widget', () {
      final brd = _load('async_heavy');
      final widgets = [
        for (final req in brd.requirements) place(req, brd).widget,
      ];
      expect(widgets, [
        'CellTextField', // REQ-001
        'CellListener', // REQ-002
        'CellAsyncBuilder', // REQ-003
        'CellAsyncBuilder', // REQ-004
        'CellAsyncBuilder', // REQ-005
        'CellAsyncBuilder', // REQ-006
        'CellListener', // REQ-007
      ]);
    });
  });
}
