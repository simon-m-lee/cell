// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// expect_lint fixtures for cell_forgotten_dispose.

import 'package:cell_flutter/testing.dart';
import 'package:flutter/material.dart';

class MissingDisposeScreen extends StatefulWidget {
  const MissingDisposeScreen({super.key});

  @override
  State<MissingDisposeScreen> createState() => _MissingDisposeScreenState();
}

class _MissingDisposeScreenState extends State<MissingDisposeScreen> {
  final source = Cell.state<int>(initial: 0);

  // expect_lint: cell_forgotten_dispose
  late final mirror = source.cell.asValueCell<int>();

  @override
  Widget build(BuildContext context) => Text('${mirror.cell.value}');
}

class NoDisposeMethodScreen extends StatefulWidget {
  const NoDisposeMethodScreen({super.key});

  @override
  State<NoDisposeMethodScreen> createState() => _NoDisposeMethodScreenState();
}

class _NoDisposeMethodScreenState extends State<NoDisposeMethodScreen> {
  final source = Cell.state<int>(initial: 0);

  // expect_lint: cell_forgotten_dispose
  late final mirror = source.cell.asValueCell<int>();

  @override
  Widget build(BuildContext context) => Text('${mirror.cell.value}');
}

class DisposedScreen extends StatefulWidget {
  const DisposedScreen({super.key});

  @override
  State<DisposedScreen> createState() => _DisposedScreenState();
}

class _DisposedScreenState extends State<DisposedScreen> {
  final source = Cell.state<int>(initial: 0);

  // NOT a lint: released in dispose.
  late final mirror = source.cell.asValueCell<int>();

  @override
  void dispose() {
    mirror.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('${mirror.cell.value}');
}

class StoppedScreen extends StatefulWidget {
  const StoppedScreen({super.key});

  @override
  State<StoppedScreen> createState() => _StoppedScreenState();
}

class _StoppedScreenState extends State<StoppedScreen> {
  final source = Cell.state<int>(initial: 0);

  // NOT a lint: released via stop.
  late final recorder = source.cell.recordPulses();

  @override
  void dispose() {
    recorder.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('${recorder.pulses.length}');
}

class ForgottenRecorderScreen extends StatefulWidget {
  const ForgottenRecorderScreen({super.key});

  @override
  State<ForgottenRecorderScreen> createState() =>
      _ForgottenRecorderScreenState();
}

class _ForgottenRecorderScreenState extends State<ForgottenRecorderScreen> {
  final source = Cell.state<int>(initial: 0);

  // expect_lint: cell_forgotten_dispose
  late final recorder = source.cell.recordPulses();

  @override
  Widget build(BuildContext context) => Text('${recorder.pulses.length}');
}

class LocalVariableScreen extends StatefulWidget {
  const LocalVariableScreen({super.key});

  @override
  State<LocalVariableScreen> createState() => _LocalVariableScreenState();
}

class _LocalVariableScreenState extends State<LocalVariableScreen> {
  final source = Cell.state<int>(initial: 0);

  @override
  Widget build(BuildContext context) {
    // NOT a lint: a local, not a field.
    final mirror = source.cell.asValueCell<int>();
    return Text('${mirror.cell.value}');
  }
}

class UnrelatedScreen extends StatefulWidget {
  const UnrelatedScreen({super.key});

  @override
  State<UnrelatedScreen> createState() => _UnrelatedScreenState();
}

class _UnrelatedScreenState extends State<UnrelatedScreen> {
  // NOT a lint: a plain ValueCell field, no observation link.
  final counter = Cell.state<int>(initial: 0);

  @override
  Widget build(BuildContext context) => Text('${counter.cell.value}');
}

class IgnoredScreen extends StatefulWidget {
  const IgnoredScreen({super.key});

  @override
  State<IgnoredScreen> createState() => _IgnoredScreenState();
}

class _IgnoredScreenState extends State<IgnoredScreen> {
  final source = Cell.state<int>(initial: 0);

  // ignore: cell_forgotten_dispose
  late final mirror = source.cell.asValueCell<int>();

  @override
  Widget build(BuildContext context) => Text('${mirror.cell.value}');
}
