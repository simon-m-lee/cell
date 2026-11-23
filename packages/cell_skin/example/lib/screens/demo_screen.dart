// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The demo screen: app bar, three panes (or Developer Mode), the
/// status strip, and the replay overlay — all control state driven by
/// `CellBuilder` over the demo's UI cells.
library;

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

import '../mock/mock_scenario.dart';
import '../state/demo_state.dart';
import '../theme/app_theme.dart';
import '../widgets/agent_pane.dart';
import '../widgets/graph_view_pane.dart';
import '../widgets/home_pane.dart';
import '../widgets/ledger_pane.dart';
import '../widgets/replay_overlay.dart';

class DemoScreen extends StatefulWidget {
  final MockScenario scenario;

  /// Rebuilds the whole scenario from scratch (graph, ledger, agent).
  final VoidCallback onRestart;

  const DemoScreen({
    required this.scenario,
    required this.onRestart,
    super.key,
  });

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  late final DemoState state = widget.scenario.state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          // Non-positioned: this Column *sizes* the Stack. A Stack that
          // only contains Positioned/SizedBox children collapses to
          // 0×0, which silently zero-sizes every pane viewport.
          Column(
            children: [
              Expanded(
                child: CellBuilder<bool>(
                  cell: state.devMode.cell,
                  builder: (context, devMode) => (devMode ?? false)
                      ? GraphViewPane(
                          key: const ValueKey('dev'),
                          state: state,
                          home: widget.scenario.home,
                        )
                      : Row(
                          key: const ValueKey('standard'),
                          children: [
                            Expanded(
                                flex: 4,
                                child: _Pane(
                                    title: 'Home',
                                    child: HomePane(
                                      home: widget.scenario.home,
                                      state: state,
                                    ))),
                            const VerticalDivider(width: 1),
                            Expanded(
                                flex: 4,
                                child: _Pane(
                                    title: 'Agent',
                                    child: AgentPane(state: state))),
                            const VerticalDivider(width: 1),
                            Expanded(
                                flex: 4,
                                child: _Pane(
                                    title: 'Ledger',
                                    child: LedgerPane(
                                      state: state,
                                      onVerify: _verify,
                                    ))),
                          ],
                        ),
                ),
              ),
              _StatusStrip(state: state, scenario: widget.scenario),
            ],
          ),
          CellBuilder<bool>(
            cell: state.showReplay.cell,
            builder: (context, show) => (show ?? false)
                ? Positioned.fill(
                    child: ReplayOverlay(
                      state: state,
                      onClose: () => state.showReplay.update(false),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.bolt, color: AppTheme.energy),
          const SizedBox(width: 8),
          Text('Echo Home', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accepted.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'live · cell_skin demo',
              style: TextStyle(fontSize: 11, color: AppTheme.accepted),
            ),
          ),
        ],
      ),
      actions: [
        CellBuilder<bool>(
          cell: state.devMode.cell,
          builder: (context, devMode) => IconButton(
            tooltip: 'Developer Mode',
            icon: Icon((devMode ?? false)
                ? Icons.bug_report
                : Icons.bug_report_outlined),
            color: (devMode ?? false) ? AppTheme.amber : null,
            onPressed: () => state.devMode.update(!(devMode ?? false)),
          ),
        ),
        CellBuilder<bool>(
          cell: state.paused.cell,
          builder: (context, paused) => IconButton(
            tooltip: (paused ?? false) ? 'Resume' : 'Pause',
            icon: Icon((paused ?? false) ? Icons.play_arrow : Icons.pause),
            onPressed: () => widget.scenario.setPaused(!(paused ?? false)),
          ),
        ),
        IconButton(
          tooltip: 'Restart',
          icon: const Icon(Icons.restart_alt),
          onPressed: _restart,
        ),
        CellBuilder<double>(
          cell: state.speed.cell,
          builder: (context, speed) => PopupMenuButton<double>(
            tooltip: 'Playback speed',
            icon: Text(
                '${(speed ?? 4.0).toStringAsFixed((speed ?? 4.0) == (speed ?? 4.0).roundToDouble() ? 0 : 1)}×',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            onSelected: (value) => widget.scenario.setSpeed(value),
            itemBuilder: (context) => [
              for (final s in const [0.5, 1.0, 2.0, 4.0])
                PopupMenuItem(value: s, child: Text('$s×')),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Future<void> _verify() async {
    await widget.scenario.verifyAndReplay();
  }

  void _restart() => widget.onRestart();
}

/// A titled pane with a thin header.
class _Pane extends StatelessWidget {
  final String title;
  final Widget child;

  const _Pane({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          height: 36,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            border: const Border(bottom: BorderSide(color: Color(0xFF2A2E36))),
          ),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.4),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  final DemoState state;
  final MockScenario scenario;

  const _StatusStrip({required this.state, required this.scenario});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: const Border(top: BorderSide(color: Color(0xFF2A2E36))),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: AppTheme.accepted),
          const SizedBox(width: 6),
          const Text('MCP: connected',
              style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(width: 16),
          const Icon(Icons.circle, size: 8, color: AppTheme.accepted),
          const SizedBox(width: 6),
          Text(
            scenario.home.rest == null
                ? 'REST: unavailable on web'
                : 'REST: /skin/manifest '
                    '(${scenario.home.graph.roots.length} cells, '
                    '${scenario.home.membrane.manifest.toolCount} tools)',
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          const Spacer(),
          CellBuilder<int>(
            cell: state.ledgerSeq.cell,
            builder: (context, seq) => Text(
              'seq: ${(seq ?? -1) < 0 ? '—' : seq}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          if (kDemoRecordingMode) ...[
            const SizedBox(width: 16),
            CellBuilder<String>(
              cell: state.frameLabel.cell,
              builder: (context, label) => Text(
                label ?? '',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
