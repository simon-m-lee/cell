// LedgerView widget tests: loading/error/empty states, rows, filters,
// summary, expansion, and live polling.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cell_flutter_devtools_extension/src/ledger_model.dart';
import 'package:cell_flutter_devtools_extension/src/ledger_view.dart';

class _FakeLedgerClient {
  final List<Future<DevtoolsLedgerSnapshot?> Function()> calls = [];
  final List<DevtoolsLedgerSnapshot> snapshots = [];

  Future<DevtoolsLedgerSnapshot?> fetch() {
    final index = calls.length < snapshots.length
        ? calls.length
        : snapshots.length - 1;
    calls.add(() => Future.value(snapshots[index]));
    return calls.last();
  }
}

DevtoolsLedgerEntry entry({
  String id = 'a1b2c3d4-000000000000',
  required String functionName,
  DateTime? timestamp,
  bool vetted = true,
  int? txSequence,
  Map<String, dynamic>? arguments,
}) =>
    DevtoolsLedgerEntry(
      id: id,
      functionName: functionName,
      timestamp: timestamp ?? DateTime.now(),
      vetted: vetted,
      txSequence: txSequence,
      arguments: arguments,
      raw: {
        'id': id,
        'function': functionName,
        'arguments': {'positional': [5]},
        'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
        'vetted': vetted,
        'txSequence': txSequence,
      },
    );

Widget wrap(Future<DevtoolsLedgerSnapshot?> Function() fetch) => MaterialApp(
      home: Scaffold(body: LedgerView(fetch: fetch)),
    );

void main() {
  testWidgets('shows a spinner while the first request is in flight',
      (tester) async {
    final completer = Completer<DevtoolsLedgerSnapshot?>();
    await tester.pumpWidget(wrap(() => completer.future));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(
        DevtoolsLedgerSnapshot(entries: [], rejections: []));
    await tester.pump();
  });

  testWidgets('shows the actionable error state when the fetch fails',
      (tester) async {
    await tester.pumpWidget(wrap(() async => throw StateError('no app')));
    await tester.pump();
    expect(find.textContaining('registerCellDevTools'), findsOneWidget);
  });

  testWidgets('shows the helpful empty state', (tester) async {
    final fake = _FakeLedgerClient()
      ..snapshots.add(DevtoolsLedgerSnapshot(entries: [], rejections: []));
    await tester.pumpWidget(wrap(fake.fetch));
    await tester.pump();
    expect(find.textContaining("No receipts yet"), findsOneWidget);
  });

  testWidgets('renders rows with timestamp, command, id, vetted, tx seq',
      (tester) async {
    final at = DateTime(2026, 4, 15, 9, 5, 7, 89);
    final fake = _FakeLedgerClient()
      ..snapshots.add(DevtoolsLedgerSnapshot(
        entries: [
          entry(functionName: 'add', timestamp: at, txSequence: 2),
          entry(functionName: 'subtract', vetted: false),
        ],
        rejections: [],
      ));
    await tester.pumpWidget(wrap(fake.fetch));
    await tester.pump();

    expect(find.text('09:05:07.089'), findsOneWidget);
    expect(find.text('add'), findsOneWidget);
    expect(find.text('subtract'), findsOneWidget);
    expect(find.text('a1b2c3d4'), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
  });

  testWidgets('tapping a row expands the full receipt JSON', (tester) async {
    final fake = _FakeLedgerClient()
      ..snapshots.add(DevtoolsLedgerSnapshot(
        entries: [entry(functionName: 'add')],
        rejections: [],
      ));
    await tester.pumpWidget(wrap(fake.fetch));
    await tester.pump();

    expect(find.textContaining('"function"'), findsNothing);
    await tester.tap(find.byKey(const Key('ledger-row-a1b2c3d4-000000000000')));
    await tester.pump();
    expect(find.textContaining('"function"'), findsOneWidget);
  });

  testWidgets('the command filter narrows the list', (tester) async {
    final fake = _FakeLedgerClient()
      ..snapshots.add(DevtoolsLedgerSnapshot(
        entries: [
          entry(id: 'id-add', functionName: 'add'),
          entry(id: 'id-subtract', functionName: 'subtract'),
        ],
        rejections: [],
      ));
    await tester.pumpWidget(wrap(fake.fetch));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('command-filter')), 'add');
    await tester.pump();
    expect(find.byKey(const Key('ledger-row-id-add')), findsOneWidget);
    expect(find.byKey(const Key('ledger-row-id-subtract')), findsNothing);
  });

  testWidgets('the vetted filter narrows the list', (tester) async {
    final fake = _FakeLedgerClient()
      ..snapshots.add(DevtoolsLedgerSnapshot(
        entries: [
          entry(functionName: 'add'),
          entry(functionName: 'internalTick', vetted: false),
        ],
        rejections: [],
      ));
    await tester.pumpWidget(wrap(fake.fetch));
    await tester.pump();

    await tester.tap(find.byKey(const Key('vetted-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unvetted').last);
    await tester.pump();

    expect(find.text('add'), findsNothing);
    expect(find.text('internalTick'), findsOneWidget);
  });

  testWidgets('the time-range filter narrows the list', (tester) async {
    final fake = _FakeLedgerClient()
      ..snapshots.add(DevtoolsLedgerSnapshot(
        entries: [
          entry(functionName: 'recent'),
          entry(
            functionName: 'old',
            timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          ),
        ],
        rejections: [],
      ));
    await tester.pumpWidget(wrap(fake.fetch));
    await tester.pump();

    await tester.tap(find.byKey(const Key('time-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 1 min').last);
    await tester.pump();

    expect(find.text('recent'), findsOneWidget);
    expect(find.text('old'), findsNothing);
  });

  testWidgets('clear resets every filter', (tester) async {
    final fake = _FakeLedgerClient()
      ..snapshots.add(DevtoolsLedgerSnapshot(
        entries: [
          entry(functionName: 'add'),
          entry(functionName: 'subtract'),
        ],
        rejections: [],
      ));
    await tester.pumpWidget(wrap(fake.fetch));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('command-filter')), 'add');
    await tester.pump();
    await tester.tap(find.byKey(const Key('clear-filters')));
    await tester.pump();

    expect(find.text('add'), findsOneWidget);
    expect(find.text('subtract'), findsOneWidget);
  });

  testWidgets('the summary panel reports total, last-minute, and rejected',
      (tester) async {
    final fake = _FakeLedgerClient()
      ..snapshots.add(DevtoolsLedgerSnapshot(
        entries: [
          entry(functionName: 'add'),
          entry(
            functionName: 'old',
            timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          ),
        ],
        rejections: [
          DevtoolsRejectionEntry(
            id: 'r1',
            functionName: 'negative',
            timestamp: DateTime.now(),
            reason: 'governed',
          ),
        ],
      ));
    await tester.pumpWidget(wrap(fake.fetch));
    await tester.pump();

    expect(find.text('Total: 2'), findsOneWidget);
    expect(find.text('Last 1 min: 1'), findsOneWidget);
    expect(find.text('Rejected: 1'), findsOneWidget);
    expect(find.text('live'), findsOneWidget);
  });

  testWidgets('polling picks up new receipts without a manual refresh',
      (tester) async {
    final fake = _FakeLedgerClient()
      ..snapshots.add(DevtoolsLedgerSnapshot(
        entries: [entry(functionName: 'add')],
        rejections: [],
      ))
      ..snapshots.add(DevtoolsLedgerSnapshot(
        entries: [entry(functionName: 'add'), entry(functionName: 'subtract')],
        rejections: [],
      ));
    await tester.pumpWidget(wrap(fake.fetch));
    await tester.pump();
    expect(find.text('Total: 1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Total: 2'), findsOneWidget);
    expect(find.text('subtract'), findsOneWidget);
  });
}
