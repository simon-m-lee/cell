// Phase B tests: BRD AST types.

import 'package:mitose_flutter/src/brd/ast.dart';
import 'package:test/test.dart';

void main() {
  const requirement = BrdRequirement(
    id: 'REQ-001',
    sentence: 'User sees the email field',
    screen: 'Login',
    trigger: null,
    outcome: 'Email field rendered',
    type: RequirementType.display,
  );
  const screen = BrdScreen(name: 'Login', route: '/login', widgets: [
    'CellTextField',
  ]);
  const form = BrdForm(name: 'LoginForm', fields: ['email'], validator: '…');
  const state = BrdState(
    name: 'email',
    type: 'String',
    initial: "''",
    restorable: true,
    appLevel: false,
  );

  const brd = Brd(
    title: 'Login Flow',
    schemaVersion: 'flutter-pipeline/v1',
    requirements: [requirement],
    screens: [screen],
    forms: [form],
    state: [state],
    context: null,
  );

  test('RequirementType has exactly four values', () {
    expect(RequirementType.values, hasLength(4));
    expect(RequirementType.tryParse('display'), RequirementType.display);
    expect(
        RequirementType.tryParse('interaction'), RequirementType.interaction);
    expect(RequirementType.tryParse('recovery'), RequirementType.recovery);
    expect(RequirementType.tryParse('atomic'), RequirementType.atomic);
    expect(RequirementType.tryParse('unknown'), isNull);
  });

  test('Brd helpers find existing rows', () {
    expect(brd.screenByName('Login'), screen);
    expect(brd.screenByName('Missing'), isNull);
    expect(brd.stateByName('email'), state);
    expect(brd.stateByName('missing'), isNull);
    expect(brd.formByName('LoginForm'), form);
  });

  test('AST types compare by value', () {
    const copy = Brd(
      title: 'Login Flow',
      schemaVersion: 'flutter-pipeline/v1',
      requirements: [requirement],
      screens: [screen],
      forms: [form],
      state: [state],
      context: null,
    );
    expect(brd, copy);
    expect(brd.hashCode, copy.hashCode);

    const different = Brd(
      title: 'Other',
      schemaVersion: 'flutter-pipeline/v1',
      requirements: [requirement],
      screens: [screen],
      forms: [form],
      state: [state],
      context: null,
    );
    expect(brd, isNot(equals(different)));
  });

  test('BrdState list detection', () {
    const list = BrdState(
      name: 'todos',
      type: 'List<Todo>',
      initial: '[]',
      restorable: true,
      appLevel: true,
    );
    expect(list.isListType, isTrue);
    expect(state.isListType, isFalse);
  });

  test('toString is readable', () {
    expect(brd.toString(), contains('Login Flow'));
    expect(requirement.toString(), contains('REQ-001'));
    expect(screen.toString(), contains('/login'));
    expect(state.toString(), contains('String'));
    expect(form.toString(), contains('email'));
  });
}
