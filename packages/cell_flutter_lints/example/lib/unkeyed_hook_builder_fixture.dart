// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// expect_lint fixtures for cell_unkeyed_hook_builder.
// ignore_for_file: dead_null_aware_expression

import 'package:cell_flutter/hooks.dart';
import 'package:flutter/material.dart';

class SwapScreen extends HookWidget {
  const SwapScreen({super.key, required this.cell});

  final ValueCell<int> cell;

  @override
  Widget build(BuildContext context) {
    // expect_lint: cell_unkeyed_hook_builder
    return HookBuilder(
      builder: (context) {
        final value = useCell<int, int>(cell: cell, select: (v) => v ?? 0);
        return Text('${value ?? 0}');
      },
    );
  }
}

class KeyedSwapScreen extends HookWidget {
  const KeyedSwapScreen({super.key, required this.cell});

  final ValueCell<int> cell;

  @override
  Widget build(BuildContext context) {
    // NOT a lint: keyed on the cell.
    return HookBuilder(
      key: ValueKey(cell),
      builder: (context) {
        final value = useCell<int, int>(cell: cell, select: (v) => v ?? 0);
        return Text('${value ?? 0}');
      },
    );
  }
}

class LocalCellScreen extends HookWidget {
  const LocalCellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // NOT a lint: the observed cell is local, not a swappable field.
    return HookBuilder(
      builder: (context) {
        // ignore: cell_avoid_creation_in_build
        final local = Cell.state<int>(initial: 0);
        final value =
            useCell<int, int>(cell: local.cell, select: (v) => v ?? 0);
        return Text('${value ?? 0}');
      },
    );
  }
}

class AsyncSwapScreen extends HookWidget {
  const AsyncSwapScreen({super.key, required this.cell});

  final ValueCell<int>? cell; // Null-safe field still counts.

  @override
  Widget build(BuildContext context) {
    // expect_lint: cell_unkeyed_hook_builder
    return HookBuilder(
      builder: (context) {
        final value = useCellValue(cell ??
            // ignore: cell_avoid_creation_in_build
            Cell.state<int>(initial: 0).cell);
        return Text('$value');
      },
    );
  }
}

class IgnoredSwapScreen extends HookWidget {
  const IgnoredSwapScreen({super.key, required this.cell});

  final ValueCell<int> cell;

  @override
  Widget build(BuildContext context) {
    // ignore: cell_unkeyed_hook_builder
    return HookBuilder(
      builder: (context) {
        final value = useCell<int, int>(cell: cell, select: (v) => v ?? 0);
        return Text('${value ?? 0}');
      },
    );
  }
}

class UnrelatedHookScreen extends HookWidget {
  const UnrelatedHookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // NOT a lint: no useCell* call at all.
    return HookBuilder(
      builder: (context) {
        final count = useState(0);
        return Text('${count.value}');
      },
    );
  }
}
