// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// A smoke test for the live demo: the app boots, the three panes
/// render, the scripted timeline finishes, and the door tile shows the
/// real rejection.
library;

import 'package:echo_home/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Echo Home boots and completes the scripted scenario',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const EchoHomeApp());
      // Let the scenario start (graph, ledger, REST adapter).
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump();

    expect(find.text('Echo Home'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('AGENT'), findsOneWidget);
    expect(find.text('LEDGER'), findsOneWidget);
    expect(find.text('MCP: connected'), findsOneWidget);

    // Let the scripted agent finish at 4× speed, pumping frames so the
    // ValueListenableBuilder panes rebuild during the run.
    await tester.runAsync(() async {
      for (var i = 0; i < 150; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (tester.any(find.textContaining('Task complete'))) break;
      }
    });
    await tester.pump();

    expect(find.textContaining('Task complete'), findsOneWidget);
    expect(find.text('✗ occupant home — lock refused'), findsOneWidget);
    expect(find.textContaining('COMMITTED'), findsOneWidget);

    // Dispose the scenario so no timers are pending at test end.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
