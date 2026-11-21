// Example smoke test: the README quick-start works.
library;

import 'package:cell_flutter_audit_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('adding mints a receipt the view renders', (tester) async {
    await tester.pumpWidget(const AuditApp());

    expect(find.textContaining('cell.apply'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-button')));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('add'), findsOneWidget);
  });
}
