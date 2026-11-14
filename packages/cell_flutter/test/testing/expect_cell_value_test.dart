// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('expectCellValue', () {
    testWidgets('matches with matcher', (tester) async {
      final counter = Cell.state<int>(initial: 42);
      tester.expectCellValue(counter.cell, 42);
      tester.expectCellValue(counter.cell, greaterThan(0));
    });

    testWidgets('failure throws TestFailure with reason', (tester) async {
      final counter = Cell.state<int>(initial: 0);
      expect(
        () => tester.expectCellValue(counter.cell, 99, reason: 'custom'),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}
