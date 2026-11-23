// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Echo Home — the cell_skin live demo shell.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'mock/mock_scenario.dart';
import 'screens/demo_screen.dart';
import 'state/demo_state.dart';
import 'theme/app_theme.dart';

/// Owns the scenario lifecycle: start on launch, rebuild on restart,
/// and drive the recording-mode frame marker.
class EchoHomeApp extends StatefulWidget {
  const EchoHomeApp({super.key});

  @override
  State<EchoHomeApp> createState() => _EchoHomeAppState();
}

class _EchoHomeAppState extends State<EchoHomeApp> {
  MockScenario? _scenario;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _start();
    if (kDemoRecordingMode) {
      // 15fps frame marker for the recording pipeline.
      unawaited(_runFrameMarker());
    }
  }

  Future<void> _runFrameMarker() async {
    while (mounted) {
      await Future<void>.delayed(
          const Duration(milliseconds: 1000 ~/ DemoTimeline.frameRate));
      if (!mounted) return;
      setState(() => _frame = (_frame + 1) % DemoTimeline.totalFrames);
      _scenario?.state.frameLabel.update(MockScenario.frameLabel(_frame));
    }
  }

  Future<void> _start() async {
    final scenario = MockScenario();
    await scenario.start();
    // Publish only after the graph, ledger, and membrane are live —
    // the screen reads `home.membrane` in its status strip.
    _scenario = scenario;
    if (mounted) setState(() {});
  }

  Future<void> _restart() async {
    final old = _scenario;
    setState(() => _scenario = null);
    if (old != null) await old.dispose();
    await _start();
  }

  @override
  void dispose() {
    unawaited(_scenario?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _scenario;
    return MaterialApp(
      title: 'Echo Home — cell_skin demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: scenario == null
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : DemoScreen(
              key: ValueKey(scenario),
              scenario: scenario,
              onRestart: _restart,
            ),
    );
  }
}
