// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The executable placement rules.
///
/// Each rule matches a BRD sentence, checks its context, and produces
/// a [WidgetChoice] (widget + pattern + bound states). A rule returns
/// `null` when it does not match; it throws [UnplaceableSentence] with
/// `ContextCheckFailed` when it matches but the BRD's context is
/// incomplete. The dispatcher throws `NoRuleMatches` / `AmbiguousMatch`
/// for zero / several matches — the pipeline never guesses.
library;

import '../brd/ast.dart';
import '../failures.dart';
import 'patterns.dart';

/// The result of placing one requirement.
class WidgetChoice {
  const WidgetChoice({
    required this.widget,
    required this.pattern,
    required this.requirement,
    this.boundStates = const [],
    this.extra = const {},
  });

  /// The widget type (`CellTextField`, `CellListener`, …).
  final String widget;

  /// The pattern that renders/verifies the choice.
  final WidgetPattern pattern;

  /// The requirement this choice satisfies.
  final BrdRequirement requirement;

  /// The cells this choice binds.
  final List<BrdState> boundStates;

  /// Rule-specific extras (labels, error text, target screen…).
  final Map<String, Object> extra;
}

/// A placement rule descriptor, for the guide-sync check and the
/// dispatcher.
class PlacementRule {
  const PlacementRule(this.name, this.apply);

  final String name;
  final WidgetChoice? Function(BrdRequirement req, Brd brd) apply;
}

///
/// The built-in rules are guarded against overlaps, so the ambiguity
/// path can only be reached by registering an overlapping rule.
final extraPlacementRules = <PlacementRule>[];

/// Places [req] by applying every rule.
///
/// Throws [UnplaceableSentence] (`NoRuleMatches` / `AmbiguousMatch`)
/// when zero or several rules match; propagates `ContextCheckFailed`
/// from a matching rule.
WidgetChoice place(BrdRequirement req, Brd brd) {
  final matches = <PlacementRule>[];
  for (final rule in [...allPlacementRules, ...extraPlacementRules]) {
    if (rule.apply(req, brd) != null) matches.add(rule);
  }
  if (matches.isEmpty) {
    throw UnplaceableSentence(
      subtype: 'NoRuleMatches',
      requirementId: req.id,
      sentence: req.sentence,
      reason: 'no rule matches this sentence.',
      fix: 'Report this to the pipeline maintainer; the rule library needs '
          'a new rule for this sentence shape.',
      responsibility: FailureResponsibility.pipelineMaintainer,
    );
  }
  if (matches.length > 1) {
    throw UnplaceableSentence(
      subtype: 'AmbiguousMatch',
      requirementId: req.id,
      sentence: req.sentence,
      reason: 'two rules match: ${matches.map((r) => r.name).join(' and ')}.',
      fix: 'Report this to the pipeline maintainer; the rule library has an '
          'ambiguity between these two rules.',
      responsibility: FailureResponsibility.pipelineMaintainer,
    );
  }
  return matches.single.apply(req, brd)!;
}

/// Finds the state a sentence names, tolerating the common BRD
/// spellings (`search` → `searchQuery`, `todos` → `todos`).
BrdState? findNamedState(String word, Brd brd) {
  final candidates = [
    word,
    '${word}Query',
    '${word}Field',
    '${word}List',
  ];
  for (final candidate in candidates) {
    final state = brd.stateByName(candidate);
    if (state != null) return state;
  }
  return null;
}

/// The unique list-typed state, when exactly one exists.
BrdState? uniqueListState(Brd brd) {
  final lists = brd.state.where((s) => s.isListType).toList();
  return lists.length == 1 ? lists.single : null;
}

/// The unique async-shaped state (initial mentions Async/loading).
BrdState? uniqueAsyncState(Brd brd) {
  final async = brd.state
      .where((s) =>
          (s.initial ?? '').contains('AsyncValue') ||
          (s.initial ?? '').contains('loading'))
      .toList();
  return async.length == 1 ? async.single : null;
}

String titleCase(String word) =>
    word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';

String pluralize(String word) {
  if (word.endsWith('s')) return word;
  if (word.endsWith('y')) return '${word.substring(0, word.length - 1)}ies';
  return '${word}s';
}

Never _contextFailure(
  BrdRequirement req, {
  required String reason,
  required String fix,
}) {
  throw UnplaceableSentence(
    subtype: 'ContextCheckFailed',
    requirementId: req.id,
    sentence: req.sentence,
    reason: reason,
    fix: fix,
    responsibility: FailureResponsibility.brdAuthor,
  );
}

// --- Display rules ---

WidgetChoice? placeDisplayField(BrdRequirement req, Brd brd) {
  final match = RegExp(r'^User sees the (\w+) field$').firstMatch(req.sentence);
  if (match == null) return null;
  final field = match.group(1)!.toLowerCase();
  final state = findNamedState(field, brd);
  if (state == null) {
    _contextFailure(
      req,
      reason: 'the requirement names the "$field" field, but `## State` '
          'has no entry named "$field".',
      fix: 'Add a row to `## State` for "$field", or reword the requirement '
          'to name an existing field.',
    );
  }
  if (state.type != 'String') {
    _contextFailure(
      req,
      reason: 'the "$field" field has type "${state.type}", but '
          'CellTextField requires a String.',
      fix: 'Change the state type to String, or use a different widget.',
    );
  }
  return WidgetChoice(
    widget: 'CellTextField',
    pattern: FormPattern(state, labelText: titleCase(field)),
    requirement: req,
    boundStates: [state],
  );
}

WidgetChoice? placeDisplayList(BrdRequirement req, Brd brd) {
  final match =
      RegExp(r'^User sees the list of (\w+)$').firstMatch(req.sentence);
  if (match == null) return null;
  final word = match.group(1)!.toLowerCase();
  final state = findNamedState(word, brd) ?? uniqueListState(brd);
  if (state == null) {
    _contextFailure(
      req,
      reason: 'the requirement names the "$word" list, but `## State` '
          'has no List-typed entry for it.',
      fix: 'Add a `List<T>` row to `## State` for "$word", or reword the '
          'requirement.',
    );
  }
  if (!state.isListType) {
    _contextFailure(
      req,
      reason: '"${state.name}" has type "${state.type}", but CellListView '
          'requires a List type.',
      fix: 'Change the state type to `List<T>`, or use a different widget.',
    );
  }
  return WidgetChoice(
    widget: 'CellListView',
    pattern:
        DisplayPattern(state, displayText: titleCase(state.name), list: true),
    requirement: req,
    boundStates: [state],
  );
}

WidgetChoice? placeDisplayText(BrdRequirement req, Brd brd) {
  final match = RegExp(r'^User sees the (.+)$').firstMatch(req.sentence);
  if (match == null) return null;
  // The more specific display rules own these sentence shapes; the
  // fallback must stay silent on them to avoid ambiguous matches.
  if (req.sentence.endsWith(' field')) return null;
  if (req.sentence.startsWith('User sees the list of ')) return null;
  final words = match.group(1)!.split(' ');
  final state = findNamedState(words.last.toLowerCase(), brd);
  if (state == null) {
    _contextFailure(
      req,
      reason: 'the requirement names "${match.group(1)}", but `## State` '
          'has no matching entry.',
      fix: 'Add the named state to `## State`, or reword the requirement '
          'to name an existing state.',
    );
  }
  return WidgetChoice(
    widget: 'CellBuilder',
    pattern: DisplayPattern(state, displayText: titleCase(state.name)),
    requirement: req,
    boundStates: [state],
  );
}

WidgetChoice? placeDisplayLoading(BrdRequirement req, Brd brd) {
  final match = RegExp(
          r'^While the (.+) is in flight, the user sees a loading indicator$')
      .firstMatch(req.sentence);
  if (match == null) return null;
  final state = uniqueAsyncState(brd) ??
      findNamedState(match.group(1)!.split(' ').last.toLowerCase(), brd);
  if (state == null) {
    _contextFailure(
      req,
      reason: 'the requirement needs an async state, but `## State` has '
          'no async-shaped entry.',
      fix: 'Add an async state (initial like `AsyncValue.loading`) to '
          '`## State`.',
    );
  }
  return WidgetChoice(
    widget: 'CellAsyncBuilder',
    pattern: AsyncPattern(state, loadingText: 'Loading...'),
    requirement: req,
    boundStates: [state],
    extra: {
      'testAssertion': "expect(find.text('Loading...'), findsOneWidget);"
    },
  );
}

WidgetChoice? placeDisplaySuccess(BrdRequirement req, Brd brd) {
  final match =
      RegExp(r'^A successful (.+) shows the (.+)$').firstMatch(req.sentence);
  if (match == null) return null;
  final state = uniqueAsyncState(brd);
  if (state == null) {
    _contextFailure(
      req,
      reason: 'the requirement needs an async state, but `## State` has '
          'no async-shaped entry.',
      fix: 'Add an async state (initial like `AsyncValue.loading`) to '
          '`## State`.',
    );
  }
  final field = brd.state.where((s) => s.type == 'String').firstOrNull;
  return WidgetChoice(
    widget: 'CellAsyncBuilder',
    pattern: AsyncPattern(state),
    requirement: req,
    boundStates: [state, if (field != null) field],
    extra: {
      'testSetup': _asyncTestSetup(field, state),
      'testInteraction': _typeAndSettle,
      'testAssertion': "expect(find.text('result one'), findsOneWidget);",
    },
  );
}

// --- Interaction rules ---

WidgetChoice? placeInteractionForm(BrdRequirement req, Brd brd) {
  final match = RegExp(r'^Submitting (.+) navigates to the (.+) screen$')
      .firstMatch(req.sentence);
  if (match == null) return null;
  final target = brd.screenByName(titleCase(match.group(2)!));
  if (target == null) {
    _contextFailure(
      req,
      reason: 'the requirement navigates to "${match.group(2)}", but '
          '`## Screens` has no such screen.',
      fix: 'Add "${match.group(2)}" to `## Screens`, or change the '
          'destination.',
    );
  }
  BrdForm? form;
  if (brd.forms.isNotEmpty) {
    if (brd.forms.length == 1) {
      form = brd.forms.single;
    } else {
      for (final candidate in brd.forms) {
        if (candidate.fields
            .every((field) => match.group(1)!.contains(field))) {
          form = candidate;
          break;
        }
      }
    }
  }
  if (form == null) {
    _contextFailure(
      req,
      reason: 'the requirement submits a form, but `## Forms` has no '
          'matching form.',
      fix: 'Add a `## Forms` row whose fields appear in the requirement, '
          'or reword the requirement.',
    );
  }
  final submit = brd.stateByName('submit');
  if (submit == null) {
    _contextFailure(
      req,
      reason: 'the requirement needs a submission flag, but `## State` '
          'has no entry named "submit".',
      fix: 'Add a `submit` row (bool) to `## State`.',
    );
  }
  final fieldStates = [
    for (final field in form.fields)
      if (brd.stateByName(field) case final state?) state,
  ];
  final auth = brd.stateByName('auth');
  return WidgetChoice(
    widget: 'CellListener',
    pattern: AuditPattern([submit, ...fieldStates],
        action: '_signIn(auth, email, password)'),
    requirement: req,
    boundStates: [submit, ...fieldStates, if (auth != null) auth],
    extra: {
      'targetScreen': target.name,
      'form': form.name,
      // Test-generation data: valid credentials drive the navigation.
      'testSetup': '''
final auth = Cell.state<AuthState>(initial: AuthState.signedOut);
final email = Cell.state<String>(initial: 'user@example.com');
final password = Cell.state<String>(initial: 'password123');
final submit = Cell.state<bool>(initial: false);''',
      'testInteraction': '''
await tester.enterText(find.byType(TextField).first, 'user@example.com');
await tester.enterText(find.byType(TextField).last, 'password123');
await tester.tap(find.text('Sign in'));
await tester.pumpAndSettle();''',
      'testAssertion': "expect(find.text('${target.name}'), findsOneWidget);",
    },
  );
}

WidgetChoice? placeInteractionList(BrdRequirement req, Brd brd) {
  final match =
      RegExp(r'^User can (add|delete|reorder) (.+)$').firstMatch(req.sentence);
  if (match == null) return null;
  final action = match.group(1)!;
  final words = match.group(2)!.split(' ');
  final state =
      findNamedState(words.last.toLowerCase(), brd) ?? uniqueListState(brd);
  if (state == null || !state.isListType) {
    _contextFailure(
      req,
      reason: 'the requirement ${action}s "${match.group(2)}", but '
          '`## State` has no List-typed entry for it.',
      fix: 'Add a `List<T>` row to `## State`, or reword the requirement.',
    );
  }
  return WidgetChoice(
    widget: 'CellListener',
    pattern: AuditPattern([state], action: '_${action}Todo(${state.name})'),
    requirement: req,
    boundStates: [state],
    extra: _listTestExtras(action, state.name),
  );
}

Map<String, String> _listTestExtras(String action, String listName) {
  switch (action) {
    case 'add':
      return {
        'listAction': action,
        'testInteraction':
            "await tester.tap(find.text('Add'));\nawait tester.pump();",
        'testAssertion': 'expect($listName.value, hasLength(1));',
      };
    case 'delete':
      return {
        'listAction': action,
        'testSetup':
            "final $listName = Cell.state<List<Todo>>(initial: [const Todo('First')]);",
        'testInteraction':
            "await tester.drag(find.text('First'), const Offset(-500, 0));\n"
                'await tester.pumpAndSettle();',
        'testAssertion': 'expect($listName.value, isEmpty);',
      };
    case 'reorder':
      return {
        'listAction': action,
        'testSetup': 'final $listName = Cell.state<List<Todo>>(initial: '
            "[const Todo('First'), const Todo('Second')]);",
        'testInteraction':
            "await tester.tap(find.byTooltip('Reorder'));\nawait tester.pump();",
        'testAssertion': "expect($listName.value!.first.title, 'Second');",
      };
    default:
      return {'listAction': action};
  }
}

WidgetChoice? placeInteractionRetry(BrdRequirement req, Brd brd) {
  final match = RegExp(r'^The user can retry (.+)$').firstMatch(req.sentence);
  if (match == null) return null;
  final state = uniqueAsyncState(brd);
  if (state == null) {
    _contextFailure(
      req,
      reason: 'the requirement retries "${match.group(1)}", but `## State` '
          'has no async entry to retry.',
      fix: 'Add an async state to `## State`, or reword the requirement.',
    );
  }
  return WidgetChoice(
    widget: 'CellListener',
    pattern: AuditPattern([state], action: '_retry(${state.name})'),
    requirement: req,
    boundStates: [state],
    extra: {
      'retry': true,
      'testSetup': 'final ${state.name} = Cell.state<${state.type}>(initial: '
          "${_errorInitial(state, 'Search failed')});",
      'testInteraction':
          "await tester.tap(find.text('Retry'));\nawait tester.pump();",
      'testAssertion': "expect(find.text('Loading...'), findsOneWidget);",
    },
  );
}

WidgetChoice? placeInteractionDebounce(BrdRequirement req, Brd brd) {
  final match = RegExp(r'^Typing in the (.+) triggers a debounced (.+)$')
      .firstMatch(req.sentence);
  if (match == null) return null;
  // Try each word of the phrase (e.g. "the search field" → `search`),
  // so `search` can resolve to the `searchQuery` state.
  BrdState? fieldState;
  for (final word in match.group(1)!.split(' ')) {
    final candidate = findNamedState(word.toLowerCase(), brd);
    if (candidate != null && candidate.type == 'String') {
      fieldState = candidate;
      break;
    }
  }
  if (fieldState == null) {
    _contextFailure(
      req,
      reason: 'the requirement debounces input in "${match.group(1)}", but '
          '`## State` has no String field for it.',
      fix: 'Add a String state for the field, or reword the requirement.',
    );
  }
  final target = uniqueAsyncState(brd);
  return WidgetChoice(
    widget: 'CellListener',
    pattern: AuditPattern([fieldState, if (target != null) target],
        action: '_debouncedSearch(${fieldState.name}, '
            '${target?.name ?? 'null'})'),
    requirement: req,
    boundStates: [fieldState, if (target != null) target],
    extra: {
      'debounce': true,
      'testSetup': _asyncTestSetup(fieldState, target),
      'testInteraction': _typeAndSettle,
      'testAssertion': "expect(find.text('result one'), findsOneWidget);",
    },
  );
}

/// The interaction sequence for debounced / success tests.
///
/// `pumpAndSettle` alone would stop before the debounce `Timer` fires
/// (timers do not schedule frames), so we advance fake time explicitly.
const String _typeAndSettle = '''
await tester.enterText(find.byType(TextField).first, 'a');
await tester.pump();
await tester.pump(const Duration(milliseconds: 400));''';

/// Setup for async tests (field + async target cells).
String _asyncTestSetup(BrdState? field, BrdState? target) {
  final buffer = StringBuffer();
  if (field != null) {
    buffer.writeln(
        "final ${field.name} = Cell.state<${field.type}>(initial: ${field.initial ?? "''"});");
  }
  if (target != null) {
    buffer.writeln('final ${target.name} = '
        'Cell.state<${target.type}>(initial: ${normalizedInitial(target)});');
  }
  return buffer.toString();
}

/// Wraps a BRD initial like `AsyncValue.loading` into the cell's type
/// when the type differs (`SearchResult(AsyncValue.loading())`).
String normalizedInitial(BrdState state) {
  final initial = state.initial ?? 'null';
  final typeName = RegExp(r'^[A-Za-z_]\w*').firstMatch(state.type)?.group(0);
  final initialRoot = RegExp(r'^[A-Za-z_]\w*').firstMatch(initial)?.group(0);
  if (typeName != null &&
      initialRoot != null &&
      typeName != initialRoot &&
      RegExp(r'^[A-Z]').hasMatch(typeName)) {
    final parens = initial.endsWith(')') ? initial : '$initial()';
    return '$typeName($parens)';
  }
  return initial;
}

/// An async error-state initial for a test (`SearchResult(AsyncValue.error('X'))`).
String _errorInitial(BrdState state, String errorText) {
  final typeName =
      RegExp(r'^[A-Za-z_]\w*').firstMatch(state.type)?.group(0) ?? state.type;
  return "$typeName(AsyncValue.error('$errorText'))";
}

/// An async empty-state initial for a test.
String _emptyInitial(BrdState state) {
  final typeName =
      RegExp(r'^[A-Za-z_]\w*').firstMatch(state.type)?.group(0) ?? state.type;
  return '$typeName(AsyncValue.data(null))';
}

// --- Recovery rules ---

WidgetChoice? placeRecoveryValidation(BrdRequirement req, Brd brd) {
  final match = RegExp(r'^Submitting (.+) shows the error "(.+)"$')
      .firstMatch(req.sentence);
  if (match == null) return null;
  final errorText = match.group(2)!;
  final form = brd.forms.isEmpty ? null : brd.forms.first;
  if (form == null) {
    _contextFailure(
      req,
      reason: 'the requirement validates a form, but `## Forms` is empty.',
      fix: 'Add a `## Forms` row, or reword the requirement.',
    );
  }
  final fieldStates = [
    for (final field in form.fields)
      if (brd.stateByName(field) case final state?) state,
  ];
  final isEmptyError = errorText == 'Email is required';
  return WidgetChoice(
    widget: 'CellErrorBoundary',
    pattern: _ValidationBoundaryPattern(errorText, fieldStates),
    requirement: req,
    boundStates: fieldStates,
    extra: {
      'errorText': errorText,
      'form': form.name,
      'testSetup': isEmptyError
          ? ''
          : "final email = Cell.state<String>(initial: 'invalid');\n"
              "final password = Cell.state<String>(initial: '');",
      'testInteraction':
          "await tester.tap(find.text('Sign in'));\nawait tester.pump();",
      'testAssertion':
          "expect(find.textContaining('$errorText'), findsOneWidget);",
    },
  );
}

WidgetChoice? placeRecoveryNetwork(BrdRequirement req, Brd brd) {
  final match = RegExp(r'^A failed (.+) shows the error "(.+)"$')
      .firstMatch(req.sentence);
  if (match == null) return null;
  final errorText = match.group(2)!;
  final state = uniqueAsyncState(brd);
  if (state == null) {
    _contextFailure(
      req,
      reason: 'the requirement needs an async state for the failure, but '
          '`## State` has no async-shaped entry.',
      fix: 'Add an async state to `## State`, or reword the requirement.',
    );
  }
  return WidgetChoice(
    widget: 'CellAsyncBuilder',
    pattern: AsyncPattern(state, errorText: errorText),
    requirement: req,
    boundStates: [state],
    extra: {
      'errorText': errorText,
      'ledger':
          "LEDGER('${req.id}', 'recovered via CellAsyncBuilder (error branch)');",
      'testSetup': 'final ${state.name} = Cell.state<${state.type}>(initial: '
          '${_errorInitial(state, errorText)});',
      'testAssertion':
          "expect(find.textContaining('$errorText'), findsOneWidget);",
    },
  );
}

WidgetChoice? placeRecoveryEmpty(BrdRequirement req, Brd brd) {
  final match =
      RegExp(r'^An empty (.+) shows the text "(.+)"$').firstMatch(req.sentence);
  if (match == null) return null;
  final emptyText = match.group(2)!;
  final state = uniqueAsyncState(brd);
  if (state == null) {
    _contextFailure(
      req,
      reason: 'the requirement needs an async state for the empty state, '
          'but `## State` has no async-shaped entry.',
      fix: 'Add an async state to `## State`, or reword the requirement.',
    );
  }
  return WidgetChoice(
    widget: 'CellAsyncBuilder',
    pattern: AsyncPattern(state, emptyText: emptyText),
    requirement: req,
    boundStates: [state],
    extra: {
      'emptyText': emptyText,
      'testSetup': 'final ${state.name} = Cell.state<${state.type}>(initial: '
          '${_emptyInitial(state)});',
      'testAssertion': "expect(find.text('$emptyText'), findsOneWidget);",
    },
  );
}

// --- Atomic rules ---

WidgetChoice? placeAtomicTransaction(BrdRequirement req, Brd brd) {
  final match =
      RegExp(r'^(.+) persists? across app restart$').firstMatch(req.sentence);
  if (match == null) return null;
  final words = match.group(1)!.split(' ');
  final state = findNamedState(words.last.toLowerCase(), brd);
  if (state == null) {
    _contextFailure(
      req,
      reason: 'the requirement persists "${match.group(1)}", but `## State` '
          'has no entry for it.',
      fix: 'Add the state to `## State`, or reword the requirement.',
    );
  }
  if (!state.restorable) {
    _contextFailure(
      req,
      reason: '"${state.name}" has Restorable: no, but the requirement '
          'persists it across restarts.',
      fix: 'Set `Restorable: yes` on "${state.name}".',
    );
  }
  return WidgetChoice(
    widget: 'CellListener',
    pattern: AuditPattern([state], action: '_txApply(${state.name})'),
    requirement: req,
    boundStates: [state],
    extra: {
      'ledger': "LEDGER('${req.id}', 'interacted via Cell.txApply');",
      'testInteraction': '',
      'testAssertion': 'expect(${state.name}.value, isNotNull);',
    },
  );
}

WidgetChoice? placeAtomicMultiCell(BrdRequirement req, Brd brd) {
  final match =
      RegExp(r'^(.+) updates (.+) and (.+) together$').firstMatch(req.sentence);
  if (match == null) return null;
  final a = findNamedState(match.group(2)!.split(' ').last.toLowerCase(), brd);
  final b = findNamedState(match.group(3)!.split(' ').last.toLowerCase(), brd);
  if (a == null || b == null) {
    _contextFailure(
      req,
      reason: 'the requirement updates two cells together, but one of them '
          'is missing from `## State`.',
      fix: 'Add both states to `## State`, or reword the requirement.',
    );
  }
  return WidgetChoice(
    widget: 'CellListener',
    pattern: AuditPattern([a, b], action: '_txApplyBoth(${a.name}, ${b.name})'),
    requirement: req,
    boundStates: [a, b],
    extra: {'atomic': true},
  );
}

WidgetChoice? placeAtomicRollback(BrdRequirement req, Brd brd) {
  final match =
      RegExp(r'^If (.+) fails, (.+) is reverted$').firstMatch(req.sentence);
  if (match == null) return null;
  final target =
      findNamedState(match.group(1)!.split(' ').last.toLowerCase(), brd);
  final compensation =
      findNamedState(match.group(2)!.split(' ').last.toLowerCase(), brd);
  if (target == null || compensation == null) {
    _contextFailure(
      req,
      reason: 'the requirement needs two states (target + compensation), '
          'but one is missing from `## State`.',
      fix: 'Add both states to `## State`, or reword the requirement.',
    );
  }
  return WidgetChoice(
    widget: 'CellListener',
    pattern: AuditPattern([target, compensation],
        action:
            '_txApplyWithCompensation(${target.name}, ${compensation.name})'),
    requirement: req,
    boundStates: [target, compensation],
    extra: {'atomic': true, 'rollback': true},
  );
}

/// A recovery pattern that renders the form inside a
/// `CellErrorBoundary` whose fallback shows the validation error.
class _ValidationBoundaryPattern extends WidgetPattern {
  _ValidationBoundaryPattern(this.errorText, this.fieldStates);

  final String errorText;
  final List<BrdState> fieldStates;

  @override
  String get name => 'FormPattern';

  @override
  WidgetTemplate toWidgetTemplate() => WidgetTemplate(
        widgetType: 'CellErrorBoundary',
        fields: {
          'onError': "(error, stack) => Text('$errorText')",
        },
        children: [
          for (final s in fieldStates)
            FormPattern(s, labelText: titleCase(s.name)).toWidgetTemplate(),
        ],
      );

  @override
  TestTemplate toTestTemplate(BrdRequirement req) => TestTemplate(
        setup: [
          for (final s in fieldStates)
            'final ${s.name} = Cell.state<${s.type}>(initial: ${s.initial ?? "''"});',
        ].join('\n'),
        pump: 'await tester.pumpWithCells(\n'
            "  cells: {${fieldStates.map((s) => '#${s.name}: ${s.name}.cell').join(', ')}},\n"
            '  child: const ${req.screen}Screen(),\n'
            ');',
        interaction: "await tester.tap(find.text('Sign in'));\n"
            'await tester.pump();',
        assertion: "expect(find.text('$errorText'), findsOneWidget);",
        ledger: "LEDGER('${req.id}', 'recovered via CellErrorBoundary');",
      );

  @override
  String widgetDetails() =>
      'error boundary around #${fieldStates.map((s) => s.name).join(', ')}';
}

/// The rule registry — the guide-sync check reads this list.
const allPlacementRules = [
  // Display
  PlacementRule('placeDisplayField', placeDisplayField),
  PlacementRule('placeDisplayList', placeDisplayList),
  PlacementRule('placeDisplayText', placeDisplayText),
  PlacementRule('placeDisplayLoading', placeDisplayLoading),
  PlacementRule('placeDisplaySuccess', placeDisplaySuccess),
  // Interaction
  PlacementRule('placeInteractionForm', placeInteractionForm),
  PlacementRule('placeInteractionList', placeInteractionList),
  PlacementRule('placeInteractionRetry', placeInteractionRetry),
  PlacementRule('placeInteractionDebounce', placeInteractionDebounce),
  // Recovery
  PlacementRule('placeRecoveryValidation', placeRecoveryValidation),
  PlacementRule('placeRecoveryNetwork', placeRecoveryNetwork),
  PlacementRule('placeRecoveryEmpty', placeRecoveryEmpty),
  // Atomic
  PlacementRule('placeAtomicTransaction', placeAtomicTransaction),
  PlacementRule('placeAtomicMultiCell', placeAtomicMultiCell),
  PlacementRule('placeAtomicRollback', placeAtomicRollback),
];
