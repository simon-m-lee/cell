// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Flutter >=3.47 deprecates the material library in favour of
// material_ui; kept for compatibility with the stable SDK used here.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'cell_flutter_devtools.dart';

/// A floating in-app Cell Inspector panel.
///
/// Wrap the part of the app to inspect:
///
/// ```dart
/// runApp(MaterialApp(
///   home: CellInspectorOverlay(child: MyHomePage()),
/// ));
/// ```
///
/// A small floating button appears in the bottom-right corner. Tapping it
/// opens a panel listing every cell registered with
/// [CellFlutterDevTools.register]; tapping a row expands the cell's pulse
/// journal (newest first, up to [CellRegistryEntry.maxRecordedPulses]
/// entries); `clear` empties the registry and `close` hides the panel.
/// Pulse journals update live — the panel listens to the registry.
///
/// ### Behavior contract
/// - **Nothing happens without [CellFlutterDevTools.enable].** The overlay
///   renders its [child] unchanged; the floating button appears only
///   while the registry is enabled.
/// - **The overlay never disposes cells.** Closing the panel and clearing
///   the registry only release observation links; registered cells belong
///   to the app.
///
/// ### See Also:
/// - [CellFlutterDevTools] — the registry and the opt-in contract.
class CellInspectorOverlay extends StatelessWidget {
  /// Wraps [child] with the inspector.
  const CellInspectorOverlay({required this.child, super.key});

  /// The app subtree to inspect.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!CellFlutterDevTools.enabled) {
      return child;
    }
    return _OverlayHost(child: child);
  }
}

class _OverlayHost extends StatefulWidget {
  const _OverlayHost({required this.child});

  final Widget child;

  @override
  State<_OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<_OverlayHost> {
  bool _open = false;
  Widget _stack = const SizedBox.shrink();
  OverlayEntry? _fallbackEntry;

  @override
  Widget build(BuildContext context) {
    final panel = _open ? _InspectorPanel(onClose: _close) : null;
    final stack = Stack(
      children: [
        widget.child,
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            // No heroTag: a fixed global tag would collide with a second
            // overlay or an app FAB that uses the same tag (Hero asserts).
            tooltip: 'Cell Inspector',
            onPressed: () => setState(() => _open = !_open),
            child: Icon(_open ? Icons.close : Icons.insights),
          ),
        ),
        if (panel != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 72,
            height: 360,
            child: panel,
          ),
      ],
    );
    // The overlay may wrap a whole MaterialApp (no Directionality,
    // Material, or Overlay above it); provide fallbacks so the Stack,
    // the FloatingActionButton, and its tooltip can build. The fallback
    // Overlay keeps ONE entry whose builder reads the current stack, so
    // panel toggles re-render instead of showing a stale first build.
    if (Directionality.maybeOf(context) != null) {
      return stack;
    }
    _stack = stack;
    _fallbackEntry ??= OverlayEntry(builder: (context) => _stack);
    // Defer: markNeedsBuild asserts when the entry has not been inserted
    // into an Overlay yet, and this build is what creates the Overlay.
    // The entry's first build already read _stack above; this callback
    // refreshes it on later toggles.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fallbackEntry?.markNeedsBuild();
    });
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Overlay(initialEntries: [_fallbackEntry!]),
    );
  }

  void _close() => setState(() => _open = false);
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Cell Inspector',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const TextButton(
                  onPressed: CellFlutterDevTools.clear,
                  child: Text('clear'),
                ),
                TextButton(onPressed: onClose, child: const Text('close')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _RegistryView(
              registry: CellFlutterDevTools.registry,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live list of registry entries, rebuilt on every registry change.
class _RegistryView extends StatelessWidget {
  const _RegistryView({required this.registry});

  final CellRegistry registry;

  @override
  Widget build(BuildContext context) {
    // The registry is a ChangeNotifier; ListenableBuilder gives the panel
    // its liveness without a cell round-trip.
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final entries = registry.entries.values.toList()
          ..sort((a, b) => a.symbol.compareTo(b.symbol));
        if (entries.isEmpty) {
          return const Center(
            child: Text('No cells registered.\n'
                'Call CellFlutterDevTools.register("name", cell).'),
          );
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, i) => _EntryTile(entry: entries[i]),
        );
      },
    );
  }
}

class _EntryTile extends StatefulWidget {
  const _EntryTile({required this.entry});

  final CellRegistryEntry entry;

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Column(
      children: [
        ListTile(
          dense: true,
          title: Text(entry.symbol),
          subtitle: Text(
            '${entry.cell.runtimeType} — ${entry.value}\n'
            'pulses: ${entry.pulseCount}',
          ),
          trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pulse history (newest first):',
                      style: TextStyle(fontSize: 12)),
                  if (entry.pulses.isEmpty)
                    const Text('— no pulses yet —',
                        style: TextStyle(fontSize: 12))
                  else
                    for (final pulse in entry.pulses)
                      Text('[${pulse.type}] ${pulse.payload}',
                          style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
