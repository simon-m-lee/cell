// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/foundation.dart';

/// The in-app Cell Inspector.
///
/// `CellFlutterDevTools` is the **opt-in** entry point for the in-app
/// inspector. Calling [CellFlutterDevTools.enable] once in `main()` turns
/// on a global [CellRegistry]; cells registered through
/// [CellFlutterDevTools.register] are then visible in
/// [CellInspectorOverlay] and (in the future DevTools extension) the
/// `ext.cellFlutter.*` service extensions.
///
/// ### Registration contract (read this)
/// Registration is **explicit**. The registry does not magically discover
/// cells — the developer names each cell:
///
/// ```dart
/// void main() {
///   CellFlutterDevTools.enable();
///   runApp(const MyApp());
/// }
///
/// class CounterScreenState extends State<CounterScreen> {
///   late final counter = Cell.state<int>(initial: 0);
///
///   @override
///   void initState() {
///     super.initState();
///     CellFlutterDevTools.register('counter', counter.cell);
///   }
/// }
/// ```
///
/// This is deliberate: an automatic registry would silently miss cells
/// created before `enable()` ran, and the developer is the only one who
/// knows which cells matter. (A future `cell` release may add an
/// automatic registration hook; until then the explicit contract stands.)
///
/// ### Lifecycle
/// - [enable] is idempotent and a no-op in release builds.
/// - [register] opens exactly one `Cell.observe` link per cell and
///   records every pulse it receives; [unregister] and [clear] release
///   those links. **Registered cells are never disposed** — the registry
///   only observes them.
/// - The registry notifies listeners (the overlay) on register,
///   unregister, clear, and every recorded pulse.
///
/// ### See Also:
/// - [CellInspectorOverlay] — the floating inspector panel.
/// - [CellRegistry] / [CellRegistryEntry] — the data model.
abstract final class CellFlutterDevTools {
  static bool _enabled = false;
  static CellRegistry? _registry;

  /// Whether [enable] has been called in this isolate.
  static bool get enabled => _enabled;

  /// The live cell registry; null until [enable] is called.
  ///
  /// Exposed for the DevTools extension and for tests; most code should
  /// go through [register] / [unregister] / [clear].
  static CellRegistry get registry {
    if (!_enabled) {
      throw StateError(
        'CellFlutterDevTools is not enabled. Call '
        'CellFlutterDevTools.enable() in main() first.',
      );
    }
    return _registry!;
  }

  /// Enables the inspector. Call once in `main()`.
  ///
  /// Idempotent: repeated calls are no-ops. In release builds this is a
  /// no-op by design — the inspector is developer tooling, not
  /// production instrumentation.
  static void enable() {
    if (kReleaseMode) {
      return; // coverage:ignore-line — kReleaseMode is false in tests.
    }
    if (_enabled) {
      return;
    }
    _enabled = true;
    _registry = CellRegistry._();
  }

  /// Registers [cell] under [symbol] in the live registry.
  ///
  /// Throws [StateError] when [enable] has not been called, and when
  /// [symbol] is already registered. A cell may be registered under
  /// several symbols (each registration is an independent observation).
  static CellRegistryEntry register(String symbol, Cell cell) =>
      registry.register(symbol, cell);

  /// Removes the entry registered under [symbol] and releases its
  /// observation link. No-op when [symbol] is not registered and when
  /// the devtools are disabled (cleanup is always safe).
  static void unregister(String symbol) {
    if (!_enabled) {
      return;
    }
    registry.unregister(symbol);
  }

  /// Removes every registered entry and releases all observation links.
  /// No-op when the devtools are disabled (cleanup is always safe).
  static void clear() {
    if (!_enabled) {
      return;
    }
    registry.clear();
  }

  /// Resets the global state: releases every observation link and returns
  /// to the disabled state. For tests and tooling only.
  @visibleForTesting
  static void resetForTesting() {
    _registry?.clear();
    _registry?.dispose();
    _registry = null;
    _enabled = false;
  }
}

/// The live registry behind [CellFlutterDevTools].
///
/// A side table of explicitly registered cells: per entry it records the
/// cell's current value, its runtime type, and the pulse journal (the
/// last [CellRegistryEntry.maxRecordedPulses] pulses). It notifies
/// listeners whenever the table or a journal changes, which is how
/// [CellInspectorOverlay] stays live.
class CellRegistry extends ChangeNotifier {
  CellRegistry._();

  final Map<String, CellRegistryEntry> _entries = {};

  /// The registered entries, keyed by symbol.
  ///
  /// Returns an unmodifiable copy; the registry itself is never mutated
  /// through this view.
  Map<String, CellRegistryEntry> get entries => Map.unmodifiable(_entries);

  /// Registers [cell] under [symbol].
  CellRegistryEntry register(String symbol, Cell cell) {
    if (_entries.containsKey(symbol)) {
      throw StateError(
        'CellFlutterDevTools: symbol "$symbol" is already registered.',
      );
    }
    final entry = CellRegistryEntry._(symbol, cell, this);
    _entries[symbol] = entry;
    notifyListeners();
    return entry;
  }

  /// Removes and disposes the entry registered under [symbol].
  void unregister(String symbol) {
    final entry = _entries.remove(symbol);
    if (entry == null) {
      return;
    }
    entry.dispose();
    notifyListeners();
  }

  /// Removes and disposes every entry.
  void clear() {
    if (_entries.isEmpty) {
      return;
    }
    final entries = _entries.values.toList();
    _entries.clear();
    for (final entry in entries) {
      entry.dispose();
    }
    notifyListeners();
  }

  // Bridge for entries (which cannot call the protected member directly).
  void _notify() => notifyListeners();
}

/// One registered cell and its journal.
class CellRegistryEntry {
  CellRegistryEntry._(this.symbol, this.cell, this._registry) {
    _egress = Cell.observe<Pulse<Object?>>(
      source: cell,
      effect: _record,
      initiallyStarted: true,
    );
  }

  /// The maximum number of pulses kept per entry.
  static const int maxRecordedPulses = 10;

  /// The developer-chosen name for this cell.
  final String symbol;

  /// The registered cell. The registry observes it; it never disposes it.
  final Cell cell;

  final CellRegistry _registry;
  final List<CellPulseRecord> _pulses = [];
  late final EgressHandle<Pulse<Object?>> _egress;
  int _totalPulses = 0;
  bool _disposed = false;

  /// The recorded pulses, newest first.
  ///
  /// Holds at most [maxRecordedPulses] entries. Returns a snapshot copy.
  List<CellPulseRecord> get pulses => List.unmodifiable(_pulses.reversed);

  /// How many pulses the cell has emitted since registration.
  ///
  /// Counts every emission; [pulses] keeps only the newest
  /// [maxRecordedPulses] of them.
  int get pulseCount => _totalPulses;

  /// The cell's current value (or null for a non-value cell), formatted
  /// for display. Never throws — broken `toString`s degrade to a label.
  String get value => _safeStringify(_valueOf(cell));

  /// Whether [dispose] has released the observation link.
  bool get disposed => _disposed;

  static Object? _valueOf(Cell cell) =>
      cell is ValueCell<dynamic> ? cell.value : null;

  void _record(Pulse<Object?> pulse) {
    if (_disposed) {
      return;
    }
    _totalPulses++;
    _pulses.add(
      CellPulseRecord(
        // Untyped pulses are plain data emissions; display them as such.
        type: pulse.type == null ? 'data' : _safeStringify(pulse.type),
        payload: _safeStringify(pulse.payload),
      ),
    );
    if (_pulses.length > maxRecordedPulses) {
      _pulses.removeAt(0);
    }
    _registry._notify();
  }

  /// Releases the observation link. Idempotent; the cell itself is never
  /// disposed.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _egress.stop();
  }
}

/// One recorded pulse, display-formatted.
class CellPulseRecord {
  const CellPulseRecord({required this.type, required this.payload});

  /// The pulse type tag, stringified (commonly `'data'`, `'error'`, or
  /// a custom tag).
  final String type;

  /// The pulse payload, stringified and truncated.
  final String payload;
}

String _safeStringify(Object? value) {
  String text;
  try {
    text = value.toString();
  } catch (e) {
    return '<unprintable ${e.runtimeType}>';
  }
  if (text.length > 120) {
    text = '${text.substring(0, 120)}…';
  }
  return text;
}
