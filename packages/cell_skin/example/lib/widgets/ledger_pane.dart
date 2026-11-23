// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The Ledger pane: a Datadog-style forensic audit log with
/// expandable entries. Every row is a real [LedgerEntry]; the list is
/// a cell rendered by `CellListView.keyed` (stable keys per seq).
library;

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

import '../state/demo_state.dart';
import '../theme/app_theme.dart';

class LedgerPane extends StatelessWidget {
  final DemoState state;
  final VoidCallback onVerify;

  const LedgerPane({required this.state, required this.onVerify, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            'The ledger records mutations. A denial writes no entry.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: CellListView<LedgerEntry>.keyed(
            cell: state.ledgerRows.cell,
            itemKey: (entry) => entry.seq,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, entry, index) => _LedgerEntryCard(
              key: ValueKey(entry.seq),
              entry: entry,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Verify & Replay'),
            onPressed: onVerify,
          ),
        ),
      ],
    );
  }
}

class _LedgerEntryCard extends StatefulWidget {
  final LedgerEntry entry;

  const _LedgerEntryCard({required this.entry, super.key});

  @override
  State<_LedgerEntryCard> createState() => _LedgerEntryCardState();
}

class _LedgerEntryCardState extends State<_LedgerEntryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final receipt = entry.receipt;
    const statusColor = AppTheme.accepted;
    const statusLabel = 'accepted';
    final functionLabel =
        receipt.function.toString().replaceAll(RegExp(r"'"), '');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -16),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Color.lerp(
            theme.colorScheme.surfaceContainerHigh,
            statusColor.withValues(alpha: 0.08),
            0.5,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2E36)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#${entry.seq} $statusLabel',
                        style: const TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      receipt.timestamp.toIso8601String().substring(11, 23),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  functionLabel,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'cell: ${entry.receiptCellId} · receipt: '
                  '${entry.pulseDigest.length >= 8 ? entry.pulseDigest.substring(0, 8) : entry.pulseDigest}…',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    _prettyJson(entry.toJson()),
                    style:
                        const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _prettyJson(Map<String, Object?> json) {
    final buffer = StringBuffer();
    for (final entry in json.entries) {
      buffer.writeln('"${entry.key}": ${entry.value}');
    }
    return buffer.toString();
  }
}
