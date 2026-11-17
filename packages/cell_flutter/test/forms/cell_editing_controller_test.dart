// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Forms: the two-way CellEditingController binding — the spike-2
// guard conditions and cursor preservation, locked in.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CellEditingController', () {
    test('initializes from the cell current value', () {
      final counter = Cell.state<String>(initial: 'hello');
      final controller = cellEditingController(counter.cell);
      addTearDown(controller.dispose);

      expect(controller.text, 'hello');
      expect(controller.cell, same(counter.cell));
    });

    test('typing in the controller updates the cell', () {
      final counter = Cell.state<String>(initial: '');
      final controller = cellEditingController(counter.cell);
      addTearDown(controller.dispose);

      controller.text = 'hello';
      expect(counter.cell.value, 'hello');
    });

    test('cell update updates the controller text', () {
      final counter = Cell.state<String>(initial: '');
      final controller = cellEditingController(counter.cell);
      addTearDown(controller.dispose);

      counter.update('goodbye');
      expect(controller.text, 'goodbye');
    });

    test('same-value cell write does not touch the controller', () {
      final counter = Cell.state<String>(initial: 'abc');
      final controller = cellEditingController(counter.cell);
      addTearDown(controller.dispose);

      controller.selection = const TextSelection.collapsed(offset: 1);
      counter.update('abc'); // No text change.
      expect(controller.selection.baseOffset, 1,
          reason: 'an equal value must not reset the cursor');
    });

    test('disposal stops the cell sync direction', () {
      final counter = Cell.state<String>(initial: 'x');
      final controller = cellEditingController(counter.cell);
      controller.dispose();

      counter.update('z');
      expect(controller.text, 'x',
          reason: 'cell write after dispose must not reach the controller');

      // Flutter's own contract: writing a disposed TextEditingController
      // throws; the binding cannot (and should not) resurrect it.
      expect(() => controller.text = 'y', throwsFlutterError);
    });

    test('selection preserved across a same-length replacement', () {
      final counter = Cell.state<String>(initial: 'aaaa');
      final controller = cellEditingController(counter.cell);
      addTearDown(controller.dispose);

      controller.selection = const TextSelection.collapsed(offset: 2);
      counter.update('bbbb');

      expect(controller.text, 'bbbb');
      expect(controller.selection.baseOffset, 2);
    });

    test('selection moves to the end across a length-changing replacement', () {
      final counter = Cell.state<String>(initial: 'abc');
      final controller = cellEditingController(counter.cell);
      addTearDown(controller.dispose);

      controller.selection = const TextSelection.collapsed(offset: 1);
      counter.update('abcdefgh');

      // Offset-from-end: end(3) - 1 = 2 from end of the new text (len 8).
      expect(controller.selection.baseOffset, 6);
    });

    test('repeated alternating writes converge (no loop)', () {
      final counter = Cell.state<String>(initial: '');
      final controller = cellEditingController(counter.cell);
      addTearDown(controller.dispose);

      for (var i = 0; i < 50; i++) {
        final fromController = i.isEven;
        if (fromController) {
          controller.text = 'v$i';
        } else {
          counter.update('v$i');
        }
      }
      expect(controller.text, 'v49');
      expect(counter.cell.value, 'v49');
    });
  });
}
