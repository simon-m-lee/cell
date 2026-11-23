// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The Agent pane: a ChatGPT-style transcript of the scripted agent.
/// The transcript is a cell (newest first), rendered by
/// `CellListView.builder` in the new `reverse` orientation so the live
/// edge stays pinned to the bottom; the typing indicator is a separate
/// `CellBuilder` row.
library;

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

import '../models/agent_event.dart';
import '../state/demo_state.dart';
import '../theme/app_theme.dart';

class AgentPane extends StatelessWidget {
  final DemoState state;

  const AgentPane({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CellListView<AgentMessage>.builder(
            cell: state.transcript.cell,
            reverse: true,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, message, index) => _MessageEntry(
              key: ValueKey(message.id),
              message: message,
            ),
          ),
        ),
        CellBuilder<bool>(
          cell: state.agentTyping.cell,
          builder: (context, typing) => AnimatedSize(
            duration: const Duration(milliseconds: 150),
            child: (typing ?? false)
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(0xFF2196F3),
                          child: Icon(Icons.smart_toy_outlined,
                              size: 16, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        _TypingDots(),
                      ],
                    ),
                  )
                : const SizedBox(height: 0, width: double.infinity),
          ),
        ),
      ],
    );
  }
}

class _MessageEntry extends StatelessWidget {
  final AgentMessage message;

  const _MessageEntry({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: switch (message) {
        AgentThinking(:final text) => _AvatarRow(
            child: Text(text,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant))),
        AgentCalling(:final signature) => _AvatarRow(
              child: Text(
            signature,
            style: const TextStyle(
                fontFamily: 'monospace', fontWeight: FontWeight.w600),
          )),
        AgentToolsDiscovered(:final tools) => _ToolsCard(tools: tools),
        AgentCallResult(:final label, :final kind) =>
          _OutcomeBadge(label: label, kind: kind),
        AgentTaskComplete(:final text) => _TaskCompleteCard(text: text),
      },
    );
  }
}

class _AvatarRow extends StatelessWidget {
  final Widget child;

  const _AvatarRow({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFF2196F3),
            child:
                Icon(Icons.smart_toy_outlined, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: _opacity(i),
                child:
                    const CircleAvatar(radius: 3, backgroundColor: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  double _opacity(int dot) {
    final t = _controller.value;
    return ((t + dot / 3) % 1.0) < 0.5 ? 1.0 : 0.3;
  }
}

class _ToolsCard extends StatelessWidget {
  final List<ToolDescriptor> tools;

  const _ToolsCard({required this.tools});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2E36)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'tools/list — ${tools.length} tools discovered',
                style: theme.textTheme.labelLarge,
              ),
            ),
            for (final tool in tools)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.construction, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tool.name,
                              style: const TextStyle(fontFamily: 'monospace')),
                          Text(
                            tool.argumentSummary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified_outlined,
                        size: 14, color: AppTheme.accepted),
                  ],
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _OutcomeBadge extends StatelessWidget {
  final String label;
  final OutcomeKind kind;

  const _OutcomeBadge({required this.label, required this.kind});

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      OutcomeKind.accepted || OutcomeKind.committed => AppTheme.accepted,
      OutcomeKind.rejected => AppTheme.rejected,
      OutcomeKind.staged => AppTheme.staged,
    };
    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 4, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCompleteCard extends StatelessWidget {
  final String text;

  const _TaskCompleteCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accepted.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accepted.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.trending_down, color: AppTheme.accepted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
