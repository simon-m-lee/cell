// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Developer Mode: the architecture without explanations — the live
/// `cell_flutter` DevTools registry (the four wire cells plus the
/// domain cells, each with its pulse journal) and the ledger head.
library;

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

import '../mock/mock_home.dart';
import '../state/demo_state.dart';

class GraphViewPane extends StatelessWidget {
  final DemoState state;
  final MockHome home;

  const GraphViewPane({required this.state, required this.home, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cell graph — ${home.graph.id}',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Registered cells: ${home.graph.roots.length}. The four wire '
            'cells are Cell.ingress → Cell.asyncMap → Cell.observe → '
            'Cell.observe, composed from framework primitives — no '
            'Cell subclass. The pulse journals below are the live '
            'cell_flutter DevTools registry.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListenableBuilder(
              listenable: CellFlutterDevTools.registry,
              builder: (context, _) => ListView(
                children: [
                  for (final entry
                      in CellFlutterDevTools.registry.entries.entries)
                    _RegistryRow(
                      symbol: entry.key,
                      cell: entry.value.cell,
                      pulses: entry.value.pulses,
                      pulseCount: entry.value.pulseCount,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistryRow extends StatelessWidget {
  final String symbol;
  final Cell cell;
  final List<CellPulseRecord> pulses;
  final int pulseCount;

  const _RegistryRow({
    required this.symbol,
    required this.cell,
    required this.pulses,
    required this.pulseCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2E36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  symbol,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${cell.runtimeType} · $pulseCount pulses',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (pulses.isEmpty)
            Text(
              'no pulses yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final pulse in pulses.take(3))
              Text(
                '↳ ${pulse.type}'
                '  ${pulse.payload.length > 60 ? '${pulse.payload.substring(0, 60)}…' : pulse.payload}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
        ],
      ),
    );
  }
}
