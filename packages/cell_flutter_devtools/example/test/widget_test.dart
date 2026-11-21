// Example smoke test: buttons mint receipts the extension would expose.
library;

import 'package:cell_flutter_devtools_example/cell_flutter_devtools_example.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => devtoolsReceipts.clear());

  testWidgets('adding mints a receipt and updates the count', (tester) async {
    await tester.pumpWidget(const DevtoolsExampleApp());

    expect(find.text('0 receipts'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-button')));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('1 receipts'), findsOneWidget);
    expect(devtoolsReceipts, hasLength(1));
  });
}
