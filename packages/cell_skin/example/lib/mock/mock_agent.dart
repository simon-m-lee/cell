// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The scripted agent.
///
/// The decisions, the wording, and the pacing are scripted. Every call
/// goes through the real [SkinClient] — the real four-cell membrane,
/// the real `target.apply`, the real gates. Every transcript entry is
/// written to the demo's transcript **cell**, so the Agent pane
/// consumes it with the same `cell_flutter` bindings as the domain
/// values.
library;

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';

import '../models/agent_event.dart';
import '../state/demo_state.dart';
import 'mock_home.dart';

final class MockAgent {
  final MockHome home;
  final DemoState state;

  /// Base pause unit at 1× speed; the demo runs at 4× by default.
  static const Duration pauseUnit = Duration(milliseconds: 500);

  int _messageId = 0;

  MockAgent({required this.home, required this.state});

  Future<void> _pause([int units = 1]) async {
    final microseconds =
        (pauseUnit.inMicroseconds * units / (state.speed.cell.value ?? 4.0))
            .round();
    await Future<void>.delayed(Duration(microseconds: microseconds));
  }

  void _emit(AgentMessage message) {
    // Newest first: the reversed transcript list pins the live edge
    // to the bottom of the pane.
    state.transcript.update([message, ...?state.transcript.cell.value]);
  }

  Future<void> _think(String text) async {
    state.agentTyping.update(true);
    await _pause();
    state.agentTyping.update(false);
    _emit(AgentThinking(id: _messageId++, text: text));
  }

  Future<void> _call(
    String signature,
    Future<ApplyOutcome<Object?>?> Function() invoke,
  ) async {
    _emit(AgentCalling(id: _messageId++, signature: signature));
    state.agentTyping.update(true);
    await _pause();
    state.agentTyping.update(false);

    final outcome = await invoke();
    switch (outcome) {
      case ApplyAccepted<Object?>():
        _emit(AgentCallResult(
          id: _messageId++,
          label: '✓ ACCEPTED',
          kind: OutcomeKind.accepted,
        ));
        return;
      case ApplyRejected<Object?>(:final reason):
        final label = reason?.toString() ?? 'integrity gate';
        _emit(AgentCallResult(
          id: _messageId++,
          label: '✗ REJECTED · $label',
          kind: OutcomeKind.rejected,
          reason: label,
        ));
        if (signature.contains('door.lock')) {
          state.doorDenials.update((state.doorDenials.cell.value ?? 0) + 1);
        }
        return;
      case ApplyStaged():
        _emit(AgentCallResult(
          id: _messageId++,
          label: '⏳ STAGED',
          kind: OutcomeKind.staged,
        ));
        return;
      case null:
        _emit(AgentCallResult(
          id: _messageId++,
          label: '✗ REJECTED · pending',
          kind: OutcomeKind.rejected,
          reason: 'pending',
        ));
    }
  }

  /// Runs the scripted scenario to completion.
  Future<void> run() async {
    await _think('Analyzing: reduce tomorrow\'s energy bill by 15%…');
    await _pause();

    // Discovery — the manifest is the real wire catalogue.
    final manifest = await home.graph.run(() => home.client.manifest());
    final tools = [
      for (final cell in manifest.cells)
        for (final function in cell.functions)
          ToolDescriptor(
            name: '${cell.cellId}.${function.name}',
            argumentSummary: _argumentSummary(function.argumentSchema),
          ),
    ];
    _emit(AgentToolsDiscovered(id: _messageId++, tools: tools));
    state.discoveredTools.update(tools);
    await _pause(2);

    await _think('Plan: set thermostat 22.4→19, dim lights, lock door.');
    await _pause();

    // 1. Accepted — real target.apply through the membrane.
    await _call(
        'thermostat.setTarget(target: 19)',
        () => home.graph.run(() => home.client
            .apply('home.living.thermostat', 'setTarget', positional: [19.0])));
    await _pause(2);

    // 2. Rejected — the real TestCell.action on the door.
    await _call(
        'door.lock()',
        () =>
            home.graph.run(() => home.client.apply('home.front.door', 'lock')));
    await _think('Lock rejected: someone is home. I will not override '
        'a safety rule.');
    await _pause(2);

    // 3. Batched — one wire call wrapping Cell.txApply; the ledger
    //    records two entries from one wire call (both or neither).
    await _call(
        'light.optimize(brightness: 0.5, hex: #FDB813)',
        () => home.graph
            .run(() => home.client.apply('home.living.light', 'optimize')));
    _emit(AgentCallResult(
      id: _messageId++,
      label: '⏳ BATCHED · 2 writes',
      kind: OutcomeKind.staged,
    ));
    // Wait for the committed pair to land in the ledger.
    final targetSeq = (state.ledgerSeq.cell.value ?? -1) + 2;
    for (var i = 0; i < 200; i++) {
      if ((state.ledgerSeq.cell.value ?? -1) >= targetSeq) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    _emit(AgentCallResult(
      id: _messageId++,
      label: '✓ COMMITTED · 2 ledger entries',
      kind: OutcomeKind.committed,
    ));
    await _pause(2);

    // 4. The bill — read from the live domain cells; the Home pane's
    //    number itself comes from the real synthesis cell.
    const before = 4.20;
    final after = home.currentBill;
    final pct = ((before - after) / before * 100).round();
    _emit(AgentTaskComplete(
      id: _messageId++,
      text: 'Task complete. Energy bill reduced ~$pct%, occupant safety '
          'preserved.',
    ));
  }

  static String _argumentSummary(JsonSchema schema) {
    final properties = schema.properties;
    if (properties == null || properties.isEmpty) return 'no arguments';
    return properties.entries.map((entry) {
      final s = entry.value;
      final bounds = [
        if (s.minimum != null) '${s.minimum}',
        if (s.maximum != null) '${s.maximum}',
      ];
      return '${entry.key}: ${s.type ?? 'any'}'
          '${bounds.isEmpty ? '' : ' [${bounds.join('..')}]'}';
    }).join(', ');
  }
}
