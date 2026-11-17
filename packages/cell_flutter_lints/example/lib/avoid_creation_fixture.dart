// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// expect_lint fixtures for cell_avoid_creation_in_build.

// ignore_for_file: unused_local_variable, avoid_print

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

// NOT a lint: top-level final.
final topLevelCounter = Cell.state<int>(initial: 0);

class GoodScreen extends StatefulWidget {
  const GoodScreen({super.key});

  @override
  State<GoodScreen> createState() => _GoodScreenState();
}

class _GoodScreenState extends State<GoodScreen> {
  // NOT a lint: State field.
  final counter = Cell.state<int>(initial: 0);

  // NOT a lint: created in initState.
  late final fromInit = Cell.state<int>(initial: 0);

  @override
  void initState() {
    super.initState();
    fromInit.update(1);
  }

  @override
  Widget build(BuildContext context) {
    // expect_lint: cell_avoid_creation_in_build
    final bad = Cell.state<int>(initial: 0);
    // expect_lint: cell_avoid_creation_in_build
    final badIngress = Cell.ingress<int>();
    // expect_lint: cell_avoid_creation_in_build
    final badDerive = Cell.derive<Pulse<Object?>, Pulse<Object?>>(
      source: counter.cell,
      project: (p) => p,
    );
    // NOT a lint: unrelated code in build.
    final text = 'hello $bad $badIngress $badDerive';
    return Text(text);
  }
}

class AsyncScreen extends StatefulWidget {
  const AsyncScreen({super.key});

  @override
  State<AsyncScreen> createState() => _AsyncScreenState();
}

class _AsyncScreenState extends State<AsyncScreen> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        // expect_lint: cell_avoid_creation_in_build
        final inAsyncClosure = Cell.state<int>(initial: 0);
        print(inAsyncClosure.cell.value);
      },
      child: const Text('tap'),
    );
  }
}

class NestedScreen extends StatelessWidget {
  const NestedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _NestedWidget();
  }
}

class _NestedWidget extends StatelessWidget {
  const _NestedWidget();

  @override
  Widget build(BuildContext context) {
    // expect_lint: cell_avoid_creation_in_build
    final nested = Cell.state<int>(initial: 0);
    return Text('${nested.cell.value}');
  }
}

class BuilderScopeScreen extends StatelessWidget {
  const BuilderScopeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: cell_avoid_creation_in_build
    final source = Cell.state<int>(initial: 0);
    return CellBuilder<int>(
      cell: source.cell,
      builder: (context, value) {
        // expect_lint: cell_avoid_creation_in_build
        final bad = Cell.state<int>(initial: 0);
        return Text('${bad.cell.value ?? value}');
      },
    );
  }
}
