// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The demo controller: owns the home (graph + membrane), feeds the
/// ledger tail into the demo's ledger cell, registers the wire cells
/// with `cell_flutter` DevTools for Developer Mode, and drives the
/// real [ReplayEngine] for the "Verify & Replay" overlay.
///
/// The domain values are NOT copied into view-model cells — the panes
/// bind to the domain cells directly with `CellBuilder` /
/// `CellValueBuilder`.
library;

import 'dart:async';

import 'package:cell_flutter/cell_flutter.dart';

import '../state/demo_state.dart';
import 'mock_agent.dart';
import 'mock_home.dart';

final class MockScenario {
  final DemoState state = DemoState();
  late final MockHome home;
  late final MockAgent agent;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<String> _devToolsSymbols = [];

  bool _running = false;

  /// Starts the scenario: builds the graph, wires the ledger tail and
  /// the DevTools registry, and launches the agent.
  Future<void> start() async {
    home = MockHome();
    await home.build();

    _subscriptions.add(home.ledger.tail.listen((entry) {
      // Newest first: the ledger pane renders top-pinned.
      state.ledgerRows.update([entry, ...?state.ledgerRows.cell.value]);
      state.ledgerSeq.update(entry.seq);
    }));

    _registerDevTools();

    agent = MockAgent(home: home, state: state);
    _running = true;
    unawaited(agent.run().whenComplete(() => _running = false));
  }

  /// Registers the four wire cells and the domain cells in the
  /// `cell_flutter` DevTools registry — Developer Mode renders the
  /// live graph from this data. The registry is process-global, so a
  /// restart unregisters the previous scenario's symbols first.
  void _registerDevTools() {
    CellFlutterDevTools.enable();
    final registry = CellFlutterDevTools.registry;
    registry.clear();

    void register(String symbol, Cell cell) {
      registry.register(symbol, cell);
      _devToolsSymbols.add(symbol);
    }

    register('inbound (Cell.ingress)', home.membrane.inbound.cell);
    register('router (Cell.asyncMap)', home.membrane.router);
    register('mux (Cell.synthesis)', home.membrane.mux);
    register('outbound (Cell.observe)', home.membrane.outbound.cell);
    register('thermostat', home.thermostat.cell);
    register('door', home.door.cell);
    register('light', home.light.cell);
    register('light.color', home.lightColor.cell);
    register('energy.price', home.energyPrice);
    register('energy.bill', home.estimatedBill);
  }

  /// Whether the scripted timeline is still running.
  bool get isRunning => _running;

  /// Pauses/resumes the agent's pacing. The framework keeps running —
  /// only the scripted timeline pauses.
  void setPaused(bool paused) => state.paused.update(paused);

  void setSpeed(double speed) => state.speed.update(speed);

  /// The real replay: verify the ledger, rebuild the same graph fresh,
  /// and run [ReplayEngine] into it.
  Future<void> verifyAndReplay() async {
    state.showReplay.update(true);
    state.replayProgress.update(0.0);
    state.replayDivergences.update(null);

    await home.ledger.verify();

    // The replay twin registers the *same* graph id, so the demo
    // deliberately clears the global registry first — the one
    // test-only call the plan's replay overlay requires. The live
    // membrane keeps running on its already-materialised cells; only
    // fresh registrations are affected.
    // ignore: invalid_use_of_visible_for_testing_member
    CellGraphRegistry.forceReset();
    final targetHome = MockHome(graphId: home.graphId);
    await targetHome.buildGraphOnly();

    final entries = await home.ledger.entriesSince(0).toList();
    state.replayEntries.update(entries.length);

    final result = await ReplayEngine.replay(
      ledger: home.ledger,
      target: targetHome.graph,
      options: const ReplayOptions(failOnDivergence: false),
    );

    state.replayProgress.update(entries.isEmpty
        ? 1.0
        : (result.entriesReplayed / entries.length).clamp(0.0, 1.0));
    state.replayDivergences.update(result.divergences.length);

    await targetHome.closeGraphOnly();
  }

  /// The static storyboard model for the drift test.
  static DemoTimeline timeline() => DemoTimeline();

  /// The recording-mode frame label: `Frame N/300 · <beat>`.
  static String frameLabel(int frame) =>
      'Frame $frame/${DemoTimeline.totalFrames} · '
      '${DemoTimeline.beatForFrame(frame)}';

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    // Unregister this scenario's DevTools entries (process-global).
    if (CellFlutterDevTools.enabled) {
      for (final symbol in _devToolsSymbols) {
        CellFlutterDevTools.registry.unregister(symbol);
      }
      _devToolsSymbols.clear();
    }
    await home.close();
  }
}
