// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asserts that [cell]'s current value matches [matcher].
///
/// Sugar over `expect(cell.value, matcher)`, with a diagnostic message
/// that names the cell.
///
/// ```dart
/// tester.expectCellValue(counter.cell, 5);
/// tester.expectCellValue(auth.cell, isA<SignedIn>(),
///   reason: 'after sign-in');
/// ```
extension CellExpectValue on WidgetTester {
  void expectCellValue<V>(
    ValueCell<V> cell,
    Object? matcher, {
    String? reason,
  }) {
    expect(
      cell.value,
      matcher,
      reason: reason ?? 'for cell ${cell.runtimeType}',
    );
  }
}
