// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The "Verify & Replay" overlay: the real ReplayEngine's result,
/// rendered from the replay cells with `CellBuilder`.
library;

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

import '../state/demo_state.dart';
import '../theme/app_theme.dart';

class ReplayOverlay extends StatelessWidget {
  final DemoState state;
  final VoidCallback onClose;

  const ReplayOverlay({required this.state, required this.onClose, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CellBuilder<int?>(
      cell: state.replayDivergences.cell,
      builder: (context, divergences) {
        final done = divergences != null;
        final ok = done && divergences == 0;
        return Container(
          color: Colors.black.withValues(alpha: 0.75),
          alignment: Alignment.center,
          child: Card(
            margin: const EdgeInsets.all(48),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    done
                        ? (ok ? Icons.verified : Icons.error_outline)
                        : Icons.sync,
                    size: 48,
                    color: done
                        ? (ok ? AppTheme.accepted : AppTheme.rejected)
                        : AppTheme.staged,
                  ),
                  const SizedBox(height: 12),
                  CellBuilder<int>(
                    cell: state.replayEntries.cell,
                    builder: (context, entries) => Text(
                      done
                          ? (ok
                              ? '✓ 0 divergences · ${entries ?? 0}/${entries ?? 0} entries match'
                              : '✗ $divergences divergence(s) · replay mismatch')
                          : 'Replaying ${entries ?? 0} ledger entries into a fresh graph…',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CellBuilder<double>(
                    cell: state.replayProgress.cell,
                    builder: (context, progress) => SizedBox(
                      width: 320,
                      child: LinearProgressIndicator(value: progress ?? 0),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ledger verified. The fresh graph started at initial '
                    'values; the real ReplayEngine re-applied every '
                    'entry.\n\nA rejection writes no delta — the door '
                    'stayed UNLOCKED in both worlds.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    label: const Text('Back to live'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
