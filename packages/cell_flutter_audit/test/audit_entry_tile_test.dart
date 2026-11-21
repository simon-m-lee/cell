// AuditEntryTile widget tests.
library;

import 'package:cell_flutter_audit/cell_flutter_audit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('renders the compact row with command, timestamp, and status',
      (tester) async {
    final entry = AuditEntry.fromReceipt(
      testReceipt(addCounter,
          positional: [5], timestamp: DateTime(2026, 4, 15, 9, 5, 7, 89)),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AuditEntryTile(entry: entry)),
    ));

    expect(find.text('addCounter'), findsOneWidget);
    expect(find.text('09:05:07.089'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  testWidgets('tapping expands the argument payload', (tester) async {
    final entry = AuditEntry.fromReceipt(
      testReceipt(addCounter, positional: [5]),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AuditEntryTile(entry: entry)),
    ));

    expect(find.text('[5]'), findsNothing);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('[5]'), findsOneWidget);
  });

  testWidgets('an onTap callback replaces the expand behavior', (tester) async {
    final entry = AuditEntry.fromReceipt(testReceipt(addCounter, positional: [5]));
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AuditEntryTile(entry: entry, onTap: () => tapped++),
      ),
    ));

    await tester.tap(find.byType(ListTile));
    await tester.pump();
    expect(tapped, 1);
    expect(find.text('[5]'), findsNothing);
  });

  testWidgets('unvetted tiles render the unvetted icon', (tester) async {
    final entry = AuditEntry.fromReceipt(testReceipt(addCounter, vetted: false));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AuditEntryTile(entry: entry)),
    ));

    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
  });
}
