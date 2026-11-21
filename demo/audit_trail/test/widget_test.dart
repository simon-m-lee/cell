// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Widget tests for the Audit Trail demo.
//
// These are the demo's acceptance tests: the three buttons must produce
// the three visible outcomes — an accepted receipt, a rejected receipt,
// and an undo receipt — all driven by the real `cell` apply machinery.

import 'package:cell_audit_demo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpDemo(WidgetTester tester) async {
    await tester.pumpWidget(const AuditTrailApp());
  }

  testWidgets('starts at 10 with an empty ledger', (tester) async {
    await pumpDemo(tester);
    expect(find.byKey(const Key('counter-value')), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.textContaining('REQ:'), findsNothing);
    expect(
      find.textContaining('every state change is a record you can audit'),
      findsOneWidget,
    );
  });

  testWidgets('Add +5 mints an accepted receipt and updates the value',
      (tester) async {
    await pumpDemo(tester);
    await tester.tap(find.byKey(const Key('add-button')));
    await tester.pumpAndSettle();

    expect(find.text('15'), findsOneWidget);
    expect(find.textContaining('REQ: add (+5)'), findsOneWidget);
    expect(find.textContaining('10 → 15'), findsOneWidget);
    expect(find.textContaining('Vetted: ✓'), findsOneWidget);
    // The reversible mutation displays its compensation blueprint.
    expect(find.textContaining('compensation:'), findsOneWidget);
  });

  testWidgets('Try invalid mutation is rejected by the gate', (tester) async {
    await pumpDemo(tester);
    await tester.tap(find.byKey(const Key('invalid-button')));
    await tester.pumpAndSettle();

    // The value did not change.
    expect(find.text('10'), findsOneWidget);
    // A rejected card appears with the gate's reason.
    expect(find.textContaining('REQ: negative (−20)'), findsOneWidget);
    expect(find.textContaining('10 — unchanged'), findsOneWidget);
    expect(
      find.textContaining('Rejected by the integrity gate'),
      findsOneWidget,
    );
  });

  testWidgets('Undo last change reverts through a txApply transaction',
      (tester) async {
    await pumpDemo(tester);
    await tester.tap(find.byKey(const Key('add-button')));
    await tester.pumpAndSettle();
    expect(find.text('15'), findsOneWidget);

    await tester.tap(find.byKey(const Key('undo-button')));
    await tester.pumpAndSettle();

    expect(find.text('10'), findsOneWidget);
    // The ledger holds both the action and its reversal.
    expect(find.textContaining('REQ: add (+5)'), findsOneWidget);
    expect(find.textContaining('REQ: undo: subtract (−5)'), findsOneWidget);
    expect(find.textContaining('15 → 10'), findsOneWidget);
  });

  testWidgets('undo without a compensation is a no-op', (tester) async {
    await pumpDemo(tester);
    await tester.tap(find.byKey(const Key('undo-button')));
    await tester.pumpAndSettle();
    expect(find.text('10'), findsOneWidget);
    expect(find.textContaining('REQ:'), findsNothing);
  });
}
