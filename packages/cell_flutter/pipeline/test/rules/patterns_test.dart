// Phase B tests: pattern templates.

import 'package:mitose_flutter/src/brd/ast.dart';
import 'package:mitose_flutter/src/rules/patterns.dart';
import 'package:test/test.dart';

const _email = BrdState(
  name: 'email',
  type: 'String',
  initial: "''",
  restorable: true,
  appLevel: false,
);
const _todos = BrdState(
  name: 'todos',
  type: 'List<Todo>',
  initial: '[]',
  restorable: true,
  appLevel: true,
);
const _results = BrdState(
  name: 'searchResults',
  type: 'SearchResult',
  initial: 'AsyncValue.loading',
  restorable: false,
  appLevel: true,
);
const _req = BrdRequirement(
  id: 'REQ-001',
  sentence: 'User sees the email field',
  screen: 'Login',
  trigger: null,
  outcome: 'Rendered',
  type: RequirementType.display,
);

void main() {
  test('DisplayPattern produces a CellBuilder template and RENDER ledger', () {
    const pattern = DisplayPattern(_email, displayText: 'Email');
    final widget = pattern.toWidgetTemplate();
    expect(widget.widgetType, 'CellBuilder');
    expect(widget.generics, '<String>');
    expect(widget.fields['cell'], 'email.cell');
    expect(widget.fields['builder'], contains("Text('Email')"));

    final test = pattern.toTestTemplate(_req);
    expect(test.setup, contains('Cell.state<String>'));
    expect(test.pump, contains('pumpWithCells'));
    expect(test.assertion, contains("find.text('Email')"));
    expect(test.ledger, contains("LEDGER('REQ-001'"));
    expect(test.ledger, contains('rendered via CellBuilder'));
  });

  test('DisplayPattern with list produces a CellListView template', () {
    const pattern = DisplayPattern(_todos, displayText: 'Todos', list: true);
    final widget = pattern.toWidgetTemplate();
    expect(widget.widgetType, 'CellListView');
    expect(widget.generics, '<Todo>');
    expect(widget.fields['itemBuilder'], contains('item.toString()'));
  });

  test('FormPattern produces a CellTextField template', () {
    const pattern = FormPattern(_email, labelText: 'Email');
    final widget = pattern.toWidgetTemplate();
    expect(widget.widgetType, 'CellTextField');
    expect(widget.fields['cell'], 'email.cell');
    expect(widget.fields['decoration'], contains("labelText: 'Email'"));
    final test = pattern.toTestTemplate(_req);
    expect(test.ledger, contains('rendered via CellTextField'));
  });

  test('AsyncPattern produces all three branches', () {
    const pattern = AsyncPattern(
      _results,
      loadingText: 'Loading...',
      errorText: 'Search failed',
      emptyText: 'No results',
    );
    final widget = pattern.toWidgetTemplate();
    expect(widget.widgetType, 'CellAsyncBuilder');
    expect(widget.fields['builder'], contains("Text('Loading...')"));
    expect(widget.fields['builder'], contains("Text('Search failed')"));
    expect(widget.fields['builder'], contains("Text('No results')"));
    expect(widget.fields['builder'], contains('snapshot.data'));
  });

  test('RestorePattern produces a restorable declaration template', () {
    const pattern = RestorePattern(_todos);
    final widget = pattern.toWidgetTemplate();
    expect(widget.fields['restorable'], 'todos');
    expect(widget.fields['restorationId'], "'todos'");
    final test = pattern.toTestTemplate(_req);
    expect(test.setup, contains('restorableState<List<Todo>>'));
    expect(test.ledger, contains('persisted via Cell.restorableState'));
  });

  test('RoutePattern is a Phase C placeholder with the route', () {
    const screen = BrdScreen(name: 'Home', route: '/home', widgets: ['Text']);
    const pattern = RoutePattern(screen);
    final widget = pattern.toWidgetTemplate();
    expect(widget.widgetType, 'Route');
    expect(widget.fields['route'], '/home');
    expect(widget.comment, contains('TODO(Phase C)'));
    final test = pattern.toTestTemplate(_req);
    expect(test.ledger, contains('navigated via RoutePattern'));
  });

  test('AuditPattern produces a CellListener template with INTERACT ledger',
      () {
    const pattern = AuditPattern([_results], action: '_retry(searchResults)');
    final widget = pattern.toWidgetTemplate();
    expect(widget.widgetType, 'CellListener');
    expect(widget.fields['cell'], 'searchResults.cell');
    expect(widget.fields['onPulse'], contains('_retry(searchResults)'));
    final test = pattern.toTestTemplate(_req);
    expect(test.ledger, contains('interacted via CellListener'));
  });

  test('IsolationPattern passes unmodifiable', () {
    const pattern = IsolationPattern(_email);
    final widget = pattern.toWidgetTemplate();
    expect(widget.fields['cell'], 'email.cell.unmodifiable');
    final test = pattern.toTestTemplate(_req);
    expect(test.ledger, contains('unmodifiable'));
  });

  test('SelectorPattern produces a CellSelector template', () {
    const pattern = SelectorPattern(_email, selectExpression: '(v) => v ?? ""');
    final widget = pattern.toWidgetTemplate();
    expect(widget.widgetType, 'CellSelector');
    expect(widget.fields['cell'], 'email.cell');
    expect(widget.fields['select'], '(v) => v ?? ""');
  });
}
