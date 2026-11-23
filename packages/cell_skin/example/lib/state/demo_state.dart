// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The demo's view-model: every piece of UI state is a **cell**.
///
/// Full `cell_flutter` adoption — the plan's `ValueNotifier` layer is
/// replaced by the framework's own widget bindings. The domain values
/// (thermostat, door, lights, energy) are read straight from the
/// registered graph cells; these view-model cells are deliberately
/// **not registered in the domain graph**, so the scripted transcript,
/// demo controls, and replay progress can never pollute the ledger or
/// the replay.
library;

import 'package:cell/cell.dart';

import '../models/agent_event.dart';

/// The `DEMO_RECORDING` compile-time flag from the plan: drives the
/// 15fps frame marker for capture tooling.
const bool kDemoRecordingMode =
    bool.fromEnvironment('DEMO_RECORDING', defaultValue: false);

/// The static timeline model the drift test pins.
final class DemoBeat {
  final String name;
  final int frames;

  const DemoBeat(this.name, this.frames);
}

/// The 300-frame / 15fps storyboard of the plan, as data.
final class DemoTimeline {
  static const int frameRate = 15;
  static const int totalFrames = 300;

  static const List<DemoBeat> beats = [
    DemoBeat('establish', 30),
    DemoBeat('discovery', 45),
    DemoBeat('accepted', 60),
    DemoBeat('rejected', 65),
    DemoBeat('batch', 55),
    DemoBeat('result', 25),
    DemoBeat('replay', 20),
  ];

  /// The beat a frame belongs to (for the recording-mode semantics
  /// label).
  static String beatForFrame(int frame) {
    var cursor = 0;
    for (final beat in beats) {
      cursor += beat.frames;
      if (frame < cursor) return beat.name;
    }
    return 'loop';
  }
}

/// All view-model state for the demo, as unregistered UI cells.
final class DemoState {
  // Bound to the agent — the transcript is stored newest-first so the
  // reversed CellListView pins the live edge to the bottom.
  final StateHandle<List<AgentMessage>> transcript =
      Cell.state<List<AgentMessage>>(initial: const []);
  final StateHandle<bool> agentTyping = Cell.state<bool>(initial: false);
  final StateHandle<List<ToolDescriptor>> discoveredTools =
      Cell.state<List<ToolDescriptor>>(initial: const []);

  // Bound to the ledger tail — newest first, top-pinned.
  final StateHandle<List<LedgerEntry>> ledgerRows =
      Cell.state<List<LedgerEntry>>(initial: const []);
  final StateHandle<int> ledgerSeq = Cell.state<int>(initial: -1);

  // The door's emotional beat: incremented on a real rejection.
  final StateHandle<int> doorDenials = Cell.state<int>(initial: 0);

  // Demo control.
  final StateHandle<double> speed = Cell.state<double>(initial: 4.0);
  final StateHandle<bool> paused = Cell.state<bool>(initial: false);
  final StateHandle<bool> devMode = Cell.state<bool>(initial: false);
  final StateHandle<bool> showReplay = Cell.state<bool>(initial: false);
  final StateHandle<double> replayProgress = Cell.state<double>(initial: 0.0);
  final StateHandle<int?> replayDivergences = Cell.state<int?>(initial: null);
  final StateHandle<int> replayEntries = Cell.state<int>(initial: 0);

  // Recording mode frame marker.
  final StateHandle<String> frameLabel = Cell.state<String>(initial: '');
}
