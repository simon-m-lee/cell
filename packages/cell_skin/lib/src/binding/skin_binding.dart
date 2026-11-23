// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The binding table: the only non-Cell configuration the skin needs.
///
/// A [SkinBinding] is a closed-over Dart closure — it cannot serialise —
/// registered once at app startup, exactly as `Cell.hub` requires a
/// spokes map and `Cell.observe` requires an effect. The router Cell
/// looks bindings up here and hands the resulting `ApplyCommand` to the
/// **target's own** `apply`, so every receipt stays attributable to the
/// domain cell, never to the transport.
/// {@category Features}
library;

import 'package:cell/cell.dart';

import '../wire/wire_message.dart';
import '../wire/wire_schema.dart';

/// Thrown for a malformed wire argument envelope (positional keys that
/// are not a contiguous `0..n-1` range, or invalid named argument
/// identifiers). The router maps it to a `bad_arguments` [WireError]
/// before the target's apply ever runs.
final class BadArgumentsException implements Exception {
  final String message;

  const BadArgumentsException(this.message);

  @override
  String toString() => 'BadArgumentsException: $message';
}

/// One exposed function on one target cell.
///
/// ### When to use
/// * Declaring what may cross the skin: every [WireRequest] targets a
///   registered `(cellId, functionName)` pair, never a raw method.
///
/// ### How it works
/// The binding holds the live target cell and the closure the router
/// runs; [SkinBinding.toApplyCommand] validates the wire argument
/// envelope and declared [argumentSchema] before `target.apply` — a
/// `bad_arguments` [WireError] is produced without a receipt.
///
/// ### Non-obvious
/// The compensation closure receives the **same wire arguments** as the
/// command, so it knows what to undo; `strictCursor` bindings require
/// `lastSeenSeq == ledger.head` exactly.
///
/// ### See also
/// [SkinBindingTable] (the registry), [SkinWhitelist] (the policy),
/// [SkinRouter].
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is the exposure declaration, not the command itself.
/// **When to use:** a requirement says "expose X on cell Y", "tools/list should show Z", or "this command must be serialisable".
/// **When NOT to use:** declaring graph behaviour — gates belong to the cell's `TestCell`, not the binding.
/// **Live signature:** `const SkinBinding({required String cellId, required String functionName, required Cell target, required Function function, String? description, JsonSchema? argumentSchema, bool strictCursor = false, Function? compensation})` — pinned at `cell_skin: 0.1.0`
/// **Do NOT confuse with:** `SkinWhitelist` (policy over bindings) or `SkinBindingTable` (the sealed registry).
/// **Guide:** `FEATURES-Skin.md` §4 (binding table and whitelist).
/// **Example:** `example/lib/mock/mock_home.dart` (every Echo Home tool is one binding).
/// **Cross-layer:** `binding.target.apply` runs the cell's own `TestCell` gate — the second gate.
/// **Minimal compilable example**
/// ```dart
/// final target = Cell.state<int>(initial: 20);
/// final binding = SkinBinding(
///   cellId: 'thermostat',
///   functionName: 'setTarget',
///   target: target.cell,
///   function: (int value) => target.update(value),
/// );
/// ```
/// {@category Bindings}
/// {@category Cursors}
final class SkinBinding {
  /// The registered graph name of the target cell.
  final String cellId;

  /// The wire-facing function name.
  final String functionName;

  /// The live target cell, resolved at registration.
  final Cell target;

  /// The live Dart closure the command runs.
  final Function function;

  /// Human-readable description for MCP `tools/list`; falls back to the
  /// cell's description.
  final String? description;

  /// Hand-written JSON Schema hint for MCP `tools/list`. Wins over
  /// ledger-observed shapes; `null` falls back to observation then to
  /// the permissive `{}` schema.
  final JsonSchema? argumentSchema;

  /// Honour `WireRequest.lastSeenSeq`? Opt-in per binding: a cursor
  /// conflict rejects with `conflict` before the target's apply runs.
  /// A strict binding also rejects a request that omits the cursor
  /// entirely (`cursor_required`).
  final bool strictCursor;

  /// Optional compensation closure for `ApplyCompensation`. The
  /// compensation receives the same wire arguments as the command, so
  /// it knows what to undo.
  final Function? compensation;

  /// The cell the compensation targets; defaults to [target].
  final Cell? compensationCell;

  const SkinBinding({
    required this.cellId,
    required this.functionName,
    required this.target,
    required this.function,
    this.description,
    this.argumentSchema,
    this.strictCursor = false,
    this.compensation,
    this.compensationCell,
  });

  /// Builds the framework [ApplyCommand] for a decoded [WireRequest].
  ///
  /// Positional wire arguments arrive as a JSON object whose keys must
  /// be a contiguous `0..n-1` integer range — order is taken from the
  /// keys, never from JSON object insertion order (JSON objects are
  /// unordered by spec). Named wire arguments are decoded into the
  /// framework's `Map<Symbol, Object?>` convention.
  ApplyCommand toApplyCommand(WireRequest request) {
    final positional = _orderedPositional(request.positional);
    final named = _namedSymbols(request.named);
    return (
      function: function,
      arguments: (
        positionalArguments: positional,
        namedArguments: named,
      ),
      compensation: compensation == null
          ? null
          : (
              function: compensation!,
              arguments: (
                positionalArguments: positional,
                namedArguments: named,
              ),
              cell: compensationCell ?? target,
            ),
    );
  }

  static List<Object?>? _orderedPositional(Map<String, Object?>? wire) {
    if (wire == null) return null;
    if (wire.isEmpty) return const [];
    final indices = <int>[];
    for (final key in wire.keys) {
      final index = int.tryParse(key);
      if (index == null) {
        throw BadArgumentsException(
            'positional key "$key" is not an integer index');
      }
      indices.add(index);
    }
    indices.sort();
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] != i) {
        throw BadArgumentsException(
            'positional keys must be a contiguous 0..n-1 range, got '
            '${indices.join(',')}');
      }
    }
    return [for (final i in indices) wire['$i']];
  }

  static Map<Symbol, Object?>? _namedSymbols(Map<String, Object?>? wire) {
    if (wire == null) return null;
    if (wire.isEmpty) return const {};
    final valid = RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$');
    for (final key in wire.keys) {
      if (!valid.hasMatch(key)) {
        throw BadArgumentsException('"$key" is not a valid argument name');
      }
    }
    return wire.map((name, value) => MapEntry(Symbol(name), value));
  }
}

/// The `(cellId, functionName)` → closure lookup table.
///
/// The table can be [seal]ed: a sealed table rejects further
/// registrations, so a membrane that froze its egress cells at `open()`
/// can never diverge from the manifest.
///
/// ### When to use
/// * Registering every exposed tool before [SkinMembrane.open] — the
///   table is the whole exposure registry.
///
/// ### How it works
/// `register` rejects duplicates and, once sealed, any further
/// registration; [SkinBindingTable.lookup] is the router's exposure
/// gate.
///
/// ### Non-obvious
/// The membrane seals the table at `open()`: everything registered
/// later throws — design registration order deliberately.
///
/// ### See also
/// [SkinBinding], [SkinWhitelist], [SkinMembrane.open].
/// {@category Bindings}
final class SkinBindingTable {
  final Map<String, Map<String, SkinBinding>> _byCell = {};
  bool _sealed = false;

  /// Registers [binding].
  ///
  /// Throws [StateError] for a duplicate `(cellId, functionName)` and
  /// for registrations after [seal].
  void register(SkinBinding binding) {
    if (_sealed) {
      throw StateError('SkinBindingTable is sealed: no registrations after the '
          'membrane opened');
    }
    final byFunction = _byCell.putIfAbsent(binding.cellId, () => {});
    if (byFunction.containsKey(binding.functionName)) {
      throw StateError(
          'duplicate binding "${binding.cellId}.${binding.functionName}"');
    }
    byFunction[binding.functionName] = binding;
  }

  /// Freezes the table. Registrations after this throw [StateError].
  void seal() => _sealed = true;

  /// Whether [seal] has been called.
  bool get isSealed => _sealed;

  /// The binding for `(cellId, functionName)`, or `null` when the
  /// function was never exposed.
  SkinBinding? lookup(String cellId, String functionName) =>
      _byCell[cellId]?[functionName];

  /// All exposed cell ids, in first-registration order.
  List<String> get exposedCellIds => List.unmodifiable(_byCell.keys);

  /// All bindings for [cellId], in first-registration order.
  List<SkinBinding> bindingsFor(String cellId) =>
      List.unmodifiable(_byCell[cellId]?.values ?? const []);

  /// Whether any function is exposed for [cellId].
  bool exposesCell(String cellId) => _byCell.containsKey(cellId);

  /// The number of registered bindings.
  int get length => _byCell.values.fold(0, (sum, m) => sum + m.length);

  /// Every binding, flattened.
  List<SkinBinding> get all =>
      List.unmodifiable(_byCell.values.expand((m) => m.values));
}
