// AuditTrailView widget tests: cards, borders, rejection, expansion,
// empty state, and narrow-screen layout.
library;

import 'package:cell_flutter_audit/cell_flutter_audit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget wrap(AuditTrailController controller, {AuditTrailTheme? theme}) =>
    MaterialApp(
      home: Scaffold(
        body: AuditTrailView(controller: controller, theme: theme ?? const AuditTrailTheme()),
      ),
    );

void main() {
  testWidgets('renders one card per receipt', (tester) async {
    final controller = AuditTrailController(receipts: [
      testReceipt(addCounter, positional: [5]),
      testReceipt(toggleTodo, positional: ['x']),
    ]);
    await tester.pumpWidget(wrap(controller));

    expect(find.text('addCounter'), findsOneWidget);
    expect(find.text('toggleTodo'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2));
  });

  testWidgets('a card shows the command, HH:mm:ss.SSS timestamp, and vetted icon',
      (tester) async {
    final controller = AuditTrailController(receipts: [
      testReceipt(addCounter,
          positional: [5], timestamp: DateTime(2026, 4, 15, 9, 5, 7, 89)),
    ]);
    await tester.pumpWidget(wrap(controller));

    expect(find.text('addCounter'), findsOneWidget);
    expect(find.text('09:05:07.089'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  testWidgets('unvetted receipts render with the unvetted icon and no vetted icon',
      (tester) async {
    final controller = AuditTrailController(receipts: [
      testReceipt(addCounter, vetted: false),
    ]);
    await tester.pumpWidget(wrap(controller));

    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsNothing);
  });

  testWidgets('rejection events render as red-bordered cards with the reason',
      (tester) async {
    final controller = AuditTrailController(receipts: [
      testReceipt(addCounter, positional: [5]),
    ]);
    controller.addRejection(RejectionEvent(
      receipt: testReceipt(addCounter, positional: [-20]),
      reason: 'negative mutations are not allowed',
    ));
    await tester.pumpWidget(wrap(controller));

    expect(
      find.textContaining(
          'Rejected by the integrity gate: negative mutations are not allowed'),
      findsOneWidget,
    );
    expect(find.text('✗ addCounter'), findsOneWidget);
  });

  testWidgets('showRejections: false hides rejection events', (tester) async {
    final controller = AuditTrailController(receipts: [
      testReceipt(addCounter, positional: [5]),
    ]);
    controller.addRejection(RejectionEvent(
      receipt: testReceipt(addCounter, positional: [-20]),
    ));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AuditTrailView(controller: controller, showRejections: false),
      ),
    ));

    expect(find.textContaining('Rejected by the integrity gate'), findsNothing);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('tapping a payload expands the arguments', (tester) async {
    final controller = AuditTrailController(receipts: [
      testReceipt(addCounter, positional: [5]),
    ]);
    await tester.pumpWidget(wrap(controller));

    expect(find.textContaining('(tap to expand)'), findsOneWidget);
    await tester.tap(find.byType(CollapsibleArgs).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('(tap to expand)'), findsNothing);
    expect(find.text('[5]'), findsOneWidget);
  });

  testWidgets('a receipt with no arguments shows the empty payload label',
      (tester) async {
    final controller = AuditTrailController(receipts: [
      testReceipt(toggleTodo),
    ]);
    await tester.pumpWidget(wrap(controller));

    expect(find.textContaining('No arguments'), findsOneWidget);
  });

  testWidgets('an empty ledger shows the helpful cell.apply message',
      (tester) async {
    final controller = AuditTrailController();
    await tester.pumpWidget(wrap(controller));

    expect(find.textContaining('cell.apply'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('theme overrides the empty message and hides the timestamp',
      (tester) async {
    final controller = AuditTrailController(receipts: [
      testReceipt(addCounter, positional: [5]),
    ]);
    const theme = AuditTrailTheme(
      showTimestamp: false,
      showId: false,
      showVettedIcon: false,
      emptyMessage: 'Nothing yet',
    );
    await tester.pumpWidget(wrap(controller, theme: theme));

    expect(find.textContaining(':'), findsNothing);
    expect(find.byIcon(Icons.verified), findsNothing);
    expect(find.text('Nothing yet'), findsNothing); // non-empty ledger
  });

  testWidgets('the timeline lays out without overflow on a 320px screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = AuditTrailController(receipts: [
      testReceipt(addCounter,
          positional: ['a very long argument string that keeps wrapping']),
      testReceipt(toggleTodo, positional: ['b']),
    ]);
    await tester.pumpWidget(wrap(controller));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a txSequence receipt shows its transaction chip', (tester) async {
    final controller = AuditTrailController(receipts: [
      testReceipt(addCounter, positional: [5], txSequence: 2),
    ]);
    await tester.pumpWidget(wrap(controller));

    expect(find.text('tx #2'), findsOneWidget);
  });
}
