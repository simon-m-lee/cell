// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The exposure registry defining the synaptic links between the environment and the somatic graph.
///
/// In the framework's biological metaphor, this library defines the
/// **Somatic Binding Seam**. It acts as the mapping table that tells the
/// **Skin Membrane** which **Nervous Signals** (external requests) are
/// physically allowed to stimulate which cells.
///
/// ### Why this exists
/// A cell's internal logic (its `TestCell` and `apply` logic) should remain
/// pure and unaware of the transport layer. This library provides the
/// infrastructure to map a wire-safe [WireRequest] to a specific cell's
/// **Somatic State Transition**, ensuring that the resulting **Forensic Receipt**
/// is attributed to the domain cell and not the transport adapter.
///
/// ### The Synaptic Link
/// The core of this library is the [SkinBinding]. Each binding represents
/// a single exposed "pore" on a cell:
/// 1.  **Exposure Declaration**: It names the `cellId` and `functionName`
///     visible to the outside world.
/// 2.  **Trait Definition**: It optionally carries a [JsonSchema] (the
///     **Somatic Blueprint**) to guide AI agents and external tools.
/// 3.  **Command Translation**: It handles the conversion of **Skin Payloads**
///     into internal `ApplyCommand` pulses.
///
/// ### The Binding Table
/// The [SkinBindingTable] serves as the **Somatic Registry**. It is the
/// authoritative catalog of all exposed capabilities. To prevent
/// "Forensic Ambiguity," the table is typically sealed when the
/// membrane opens, ensuring that the system's "DNA" (its manifest)
/// remains stable throughout its lifecycle.
///
/// ### Forensic Integrity
/// By separating the binding from the cell's internal state, the framework
/// ensures that:
/// -   **Attribution**: Receipts are written to the target cell's ledger.
/// -   **Pre-Somatic Rejection**: Malformed arguments are caught as
///     **Membrane Rejections** ([BadArgumentsException]) before a
///     **Command Journey** ever begins, preventing clutter in the ledger.
/// -   **Cursor Enforcement**: The binding layer can enforce `strictCursor`
///     checks to prevent race conditions at the membrane.
///
/// ### See also
/// - [SkinBinding]: The definition of a single exposed function.
/// - [SkinBindingTable]: The registry for all bindings.
/// - [SkinMembrane]: The orchestrator that uses these bindings to route signals.
/// {@category Features}
library;

import 'dart:async';

import 'package:cell/cell.dart';

import '../security/skin_call.dart';
import '../wire/wire_message.dart';
import '../wire/wire_schema.dart';

/// How a binding's user function contributes to the ledger.
enum _SkinWrite {
  /// The user function returns the next value; the binding wraps it in a
  /// pulse routed through the target receptor. The only write.
  state,

  /// The user function applies other cells itself; the outer result is
  /// not a ledger row.
  command,

  /// The legacy shape: the user function is applied unchanged.
  raw,
}

/// An exception thrown when a **Nervous Signal** contains a malformed **Skin Payload**.
///
/// In the framework's biological metaphor, [BadArgumentsException] represents a
/// **Membrane Rejection** triggered by structural inconsistencies in the
/// incoming data. It occurs at the **Skin Membrane** before a
/// **Command Journey** can be initiated.
///
/// Because this exception is caught during the transformation of the
/// [WireRequest] into an [ApplyCommand], no **Somatic State Transition**
/// is attempted, and no **Forensic Receipt** is generated in the
/// **Forensic Ledger**.
///
/// ### When to use
/// - **Structural Violations**: Automatically thrown by [SkinBinding] when
///   positional argument keys are not a contiguous `0..n-1` range.
/// - **Identifier Violations**: Thrown when named argument keys fail basic
///   Dart identifier validation (e.g., containing dots or invalid characters).
///
/// ### How it works
/// 1. **Signal Ingress**: A [WireRequest] arrives at the membrane.
/// 2. **Payload Analysis**: The [SkinBinding] attempts to decode the
///    positional and named arguments into their internal somatic forms.
/// 3. **Gate Failure**: If the keys are malformed or non-contiguous, this
///    exception is raised.
/// 4. **Rejection**: The [SkinRouter] catches the exception and returns
///    a `bad_arguments` [WireError] to the caller.
///
/// ### Non‑obvious behavior
/// - **Forensic Omission**: This failure is a membrane-level event. Since
///   the pulse never reached the target cell's `apply` logic, it leaves a
///   "Forensic Hole" where the caller sees a failure but the ledger
///   remains silent.
/// - **Pre-Gate Validation**: This check happens *before* any
///   [JsonSchema] validation or cell-specific **Integrity Gate** logic.
///
/// ### See also
/// - [WireError]: The envelope returned when this exception occurs.
/// - [SkinBinding.toApplyCommand]: The method responsible for triggering
///   this validation.
final class BadArgumentsException implements Exception {
  final String message;

  const BadArgumentsException(this.message);

  @override
  String toString() => 'BadArgumentsException: $message';
}

/// ### AI Agent Guide
/// **Layer:** Skin — this is the exposure declaration, not the command itself.
/// **When to use:** a requirement says "expose X on cell Y", "tools/list should show Z", "this command must be serialisable", or "positional calls must map to schema property names" (pass `positionalNames`).
/// **When NOT to use:** declaring graph behaviour — gates belong to the cell's `TestCell`, not the binding.
/// **Live signature:** `const SkinBinding({required String cellId, required String functionName, required Cell target, required Function function, String? description, JsonSchema? argumentSchema, bool strictCursor = false, Function? compensation, List<String>? positionalNames})` — plus `SkinBinding.state(...)` and `SkinBinding.command(...)` with the same extra parameters — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
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

  /// How the user function contributes to the ledger.
  final _SkinWrite _write;

  /// The schema property name for each positional wire argument, when
  /// the argument schema names properties (`target`) rather than index
  /// keys (`"0"`).
  ///
  /// This is a **validation zipper only**: position `i` is validated
  /// against the schema property `positionalNames[i]`, and
  /// `toApplyCommand` still passes the positional list to
  /// `Function.apply` unchanged. A positional call against a non-index
  /// schema without this list is `bad_arguments`.
  final List<String>? positionalNames;

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
    this.positionalNames,
  }) : _write = _SkinWrite.raw;

  SkinBinding._({
    required this.cellId,
    required this.functionName,
    required this.target,
    required this.function,
    this.description,
    this.argumentSchema,
    this.strictCursor = false,
    this.compensation,
    this.compensationCell,
    this.positionalNames,
    required _SkinWrite write,
  }) : _write = write;

  /// A state binding: the user function returns the **next value** (or a
  /// `Future` of it, or a `Pulse`) and must not call `update` itself.
  ///
  /// The binding wraps the returned value in a `Pulse` and routes it
  /// through the target receptor, so the only ledger row is the one
  /// `Cell.apply` records from that pulse — the wire receipt id and the
  /// ledger row's receipt id are the same. This is the shape the quick
  /// start should use for ledgered state changes.
  ///
  /// [nextValue] stays the stored [function]; the wrapper exists only
  /// inside the `ApplyCommand`, so a debugger still shows the real
  /// closure. [compensation] is wrapped the same way, so an undo that
  /// returns the restored value becomes one pulse on
  /// [compensationCell] (or [target]).
  factory SkinBinding.state({
    required String cellId,
    required String functionName,
    required Cell target,
    required Function nextValue,
    String? description,
    JsonSchema? argumentSchema,
    bool strictCursor = false,
    Function? compensation,
    Cell? compensationCell,
    List<String>? positionalNames,
  }) =>
      SkinBinding._(
        cellId: cellId,
        functionName: functionName,
        target: target,
        function: nextValue,
        description: description,
        argumentSchema: argumentSchema,
        strictCursor: strictCursor,
        compensation: compensation,
        compensationCell: compensationCell,
        positionalNames: positionalNames,
        write: _SkinWrite.state,
      );

  /// A command binding: the user function applies other cells itself
  /// (e.g. a `Cell.txApply` batch) and returns a JSON-safe result such as
  /// `true` or a report.
  ///
  /// The outer result is **not** a ledger row; the inner applies write
  /// their own rows. The router reports the half-open sequence range the
  /// command covered as `ledgerSeqs` on the response instead of pairing
  /// the outer receipt with one row.
  factory SkinBinding.command({
    required String cellId,
    required String functionName,
    required Cell target,
    required Function function,
    String? description,
    JsonSchema? argumentSchema,
    bool strictCursor = false,
    Function? compensation,
    Cell? compensationCell,
    List<String>? positionalNames,
  }) =>
      SkinBinding._(
        cellId: cellId,
        functionName: functionName,
        target: target,
        function: function,
        description: description,
        argumentSchema: argumentSchema,
        strictCursor: strictCursor,
        compensation: compensation,
        compensationCell: compensationCell,
        positionalNames: positionalNames,
        write: _SkinWrite.command,
      );

  /// Builds the framework [ApplyCommand] for a decoded [WireRequest].
  ///
  /// Positional wire arguments arrive as a JSON object whose keys must
  /// be a contiguous `0..n-1` integer range — order is taken from the
  /// keys, never from JSON object insertion order (JSON objects are
  /// unordered by spec). Named wire arguments are decoded into the
  /// framework's `Map<Symbol, Object?>` convention.
  ///
  /// For a [SkinBinding.state] binding the command function is a wrapper
  /// that `Function.apply`s the stored user function and returns the
  /// result as a `Pulse` stamped with the ambient [SkinCall]'s context
  /// (an existing `Pulse` passes through — re-stamped only when it
  /// carries no actor; a `Future` is unwrapped first). A `command`
  /// binding's positional calls get a return-value wrapper that stamps a
  /// returned pulse the same way; anything else (the `true` from a
  /// `txApply` batch) is unchanged. Raw bindings keep the user function
  /// itself on the command — authors who want the actor on the row
  /// return `SkinPulses.payload(...)`.
  ///
  /// Dart has no variadic closures, so the wrappers accept positional
  /// wire arguments through optional positional parameters (up to 12)
  /// and forward the collected prefix. A `state` or `command` binding
  /// called with **named** wire arguments is refused with
  /// `bad_arguments` — there is no generic named wrapper, so letting it
  /// through would silently drop the return-value wrapping (and, on a
  /// ledgered membrane, fail the strict-receipt check after the row was
  /// written). An empty `named: {}` is treated as absent.
  ApplyCommand toApplyCommand(WireRequest request) {
    final positional = _orderedPositional(request.positional);
    final named = _namedSymbols(request.named);
    final positionalOnly = named == null;
    if (!positionalOnly &&
        (_write == _SkinWrite.state || _write == _SkinWrite.command)) {
      throw BadArgumentsException(
          'named arguments are not supported for this binding; '
          'pass positional arguments');
    }
    final wrapsState = _write == _SkinWrite.state && positionalOnly;
    final wrapsCommand = _write == _SkinWrite.command && positionalOnly;
    return (
      function: wrapsState
          ? _stateWrapper(function, null)
          : wrapsCommand
              ? _commandWrapper(function, null)
              : function,
      arguments: (
        positionalArguments: positional,
        namedArguments: named,
      ),
      compensation: compensation == null
          ? null
          : (
              function: wrapsState
                  ? _stateWrapper(compensation!, null)
                  : compensation!,
              arguments: (
                positionalArguments: positional,
                namedArguments: named,
              ),
              cell: compensationCell ?? target,
            ),
    );
  }

  /// A positional-argument-tolerant wrapper around a state binding's
  /// user function: every passed value is collected and forwarded with
  /// `Function.apply`, and the result is returned as a `Pulse` stamped
  /// with the ambient [SkinCall]'s context.
  static Function _stateWrapper(Function user, Map<Symbol, Object?>? named) =>
      _argumentTolerant((positional) async {
        final result = Function.apply(user, positional, named);
        final value = result is Future ? await result : result;
        if (value is Pulse) return SkinPulses.stamp(value);
        return SkinPulses.payload<Object?>(value);
      });

  /// A positional-argument-tolerant wrapper around a command binding's
  /// user function: a `Future` is unwrapped, a returned `Pulse` with no
  /// actor is re-stamped with the ambient [SkinCall]'s context, and
  /// anything else is returned unchanged.
  static Function _commandWrapper(Function user, Map<Symbol, Object?>? named) =>
      _argumentTolerant((positional) async {
        final result = Function.apply(user, positional, named);
        final value = result is Future ? await result : result;
        if (value is Pulse) return SkinPulses.stamp(value);
        return value;
      });

  static Function _argumentTolerant(
    FutureOr<Object?> Function(List<Object?>) run,
  ) =>
      ([Object? a0 = _noArg,
        Object? a1 = _noArg,
        Object? a2 = _noArg,
        Object? a3 = _noArg,
        Object? a4 = _noArg,
        Object? a5 = _noArg,
        Object? a6 = _noArg,
        Object? a7 = _noArg,
        Object? a8 = _noArg,
        Object? a9 = _noArg,
        Object? a10 = _noArg,
        Object? a11 = _noArg]) async {
        final collected = <Object?>[
          a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, //
        ];
        while (collected.isNotEmpty && identical(collected.last, _noArg)) {
          collected.removeLast();
        }
        return run(collected);
      };

  /// The sentinel marking "this optional positional parameter was not
  /// passed". Private, so no caller can collide with it.
  static const Object _noArg = _NoArg();

  /// The strict-receipts verdict for a successful apply, or `null` when
  /// the write shape is the one this binding promises.
  ///
  /// A `state` binding must have written exactly one row whose receipt id
  /// is the apply receipt (an `update()` inside the function produces a
  /// synthetic `_emit` row and fails). A `raw` binding may write zero
  /// rows, but every row it writes must carry the apply receipt. A
  /// `command` binding is exempt: its inner applies own the rows.
  String? strictReceiptViolation(
    List<LedgerEntry> written,
    ApplyOutcome<Object?> outcome,
  ) {
    switch (_write) {
      case _SkinWrite.command:
        return null;
      case _SkinWrite.state:
        if (written.length == 1 &&
            written.single.receipt.id == outcome.receipt.id) {
          return null;
        }
        if (written.isEmpty) {
          return 'ledgered binding "$cellId.$functionName" did not append '
              'its apply receipt';
        }
        return 'ledgered binding "$cellId.$functionName" appended a receipt '
            'that is not the apply receipt';
      case _SkinWrite.raw:
        if (written.isEmpty ||
            written.every((entry) => entry.receipt.id == outcome.receipt.id)) {
          return null;
        }
        return 'ledgered binding "$cellId.$functionName" appended a receipt '
            'that is not the apply receipt';
    }
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
    if (wire == null || wire.isEmpty) return null;
    final valid = RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$');
    for (final key in wire.keys) {
      if (!valid.hasMatch(key)) {
        throw BadArgumentsException('"$key" is not a valid argument name');
      }
    }
    return wire.map((name, value) => MapEntry(Symbol(name), value));
  }
}

/// The authoritative registry for every exposed function on the membrane surface.
///
/// In the framework's biological metaphor, [SkinBindingTable] is the
/// **Somatic Registry**. It acts as the technical map of the **Skin Membrane**,
/// storing every **Membrane Pore** ([SkinBinding]) that has been declared
/// as physically open to the environment.
///
/// ### When to use
/// - **System Initialization**: Use this to register every cell and tool
///   intended for external exposure before calling [SkinMembrane.open].
/// - **Routing**: Used by the [SkinRouter] to resolve incoming **Nervous Signals**
///   to their target somatic addresses.
///
/// ### How it works
/// 1. **Exposure Declaration**: Developers [register] individual bindings.
/// 2. **DNA Freezing**: The table is typically [seal]ed when the membrane opens.
/// 3. **Synaptic Lookup**: The router uses [lookup] to check if a request
///    targets a legitimate pore.
///
/// ### Non‑obvious behavior
/// - **Sealing Protocol**: The membrane seals the table at `open()`. Any
///   attempt to [register] a new binding after the system is live will
///   throw a [StateError], preventing "Forensic Ambiguity."
/// - **Deduplication**: The table strictly enforces unique `(cellId, functionName)`
///   pairs. If two cells attempt to occupy the same synaptic point,
///   registration fails immediately.
/// - **Determinism**: The order of [exposedCellIds] and [all] reflects the
///   physical registration order, ensuring the **Somatic Index** (manifest)
///   remains stable across discovery impulses.
///
/// ### See also
/// - [SkinBinding]: The descriptor for a single pore.
/// - [SkinMembrane]: The organ that uses this table to govern its boundary.
/// - [SkinManifest]: The external view of this registry.
/// {@category Bindings}
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is the master list of what is exposed.
/// **Live signature:** `final class SkinBindingTable { void register(SkinBinding binding); void seal(); bool get isSealed; SkinBinding? lookup(String cellId, String functionName); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Traceability:** Once sealed, the system's "DNA" cannot be mutated.
/// **Constraint:** Register all tools *before* opening the membrane.
final class SkinBindingTable {
  final Map<String, Map<String, SkinBinding>> _byCell = {};
  bool _sealed = false;

  /// Registers a [binding] at the **Skin Membrane**.
  ///
  /// In the framework's biological metaphor, this performs an
  /// **Exposure Declaration**. It adds a new pore to the system's
  /// available vocabulary.
  ///
  /// Throws [StateError] if a duplicate `(cellId, functionName)` is
  /// detected or if the table is already [isSealed].
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

  /// Freezes the **Somatic Registry**.
  ///
  /// In the framework's biological metaphor, this "sets the DNA" for
  /// the membrane. After this call, no further pores can be opened,
  /// ensuring that the **Somatic Index** remains immutable throughout
  /// the membrane's lifecycle.
  void seal() => _sealed = true;

  /// Freezes the **Somatic Registry**.
  ///
  /// In the framework's biological metaphor, this "sets the DNA" for
  /// the membrane. After this call, no further pores can be opened,
  /// ensuring that the **Somatic Index** remains immutable throughout
  /// the membrane's lifecycle.
  bool get isSealed => _sealed;

  /// Finds the [SkinBinding] at the specified somatic coordinates.
  ///
  /// In the framework's biological metaphor, this is a **Synaptic Lookup**.
  /// It is the primary mechanism for the [SkinRouter] to determine
  /// if a **Nervous Signal** should be allowed to cross the membrane
  /// or be rejected as an unknown impulse.
  ///
  /// Returns `null` if the function was never physically exposed.
  SkinBinding? lookup(String cellId, String functionName) =>
      _byCell[cellId]?[functionName];

  /// The list of all cell IDs currently exposed at the membrane.
  ///
  /// This forms the backbone of the **Somatic Index**, representing
  /// every cell that has at least one open pore.
  List<String> get exposedCellIds => List.unmodifiable(_byCell.keys);

  /// Returns every [SkinBinding] associated with a specific [cellId].
  ///
  /// Used to generate the detailed capability map for a single cell
  /// within the **Somatic Index**.
  List<SkinBinding> bindingsFor(String cellId) =>
      List.unmodifiable(_byCell[cellId]?.values ?? const []);

  /// Whether the cell at [cellId] has any physical exposure at the membrane.
  bool exposesCell(String cellId) => _byCell.containsKey(cellId);

  /// The total number of exposed synaptic points (functions) in the registry.
  int get length => _byCell.values.fold(0, (sum, m) => sum + m.length);

  /// A flattened list of every [SkinBinding] registered in the table.
  ///
  /// Provides a comprehensive view of the membrane's surface, usually
  /// for system audits or full manifest generation.
  List<SkinBinding> get all =>
      List.unmodifiable(_byCell.values.expand((m) => m.values));
}

/// The private sentinel type for a state binding wrapper's optional
/// positional parameters: a const value no outside code can construct.
class _NoArg {
  const _NoArg();
}

/// Validates a wire request's arguments against a binding's explicit
/// [SkinBinding.argumentSchema], or returns `null` when nothing is
/// enforced.
///
/// `argumentSchema == null` returns immediately — manifest observation
/// is never consulted. One object is built from the **wire request**
/// (not the `ApplyCommand`) and handed to `validateJsonSchema`:
///
/// * Named arguments (and no positional) validate the named map.
/// * Neither validates `{}`, so `required` still fails.
/// * Both, with a schema, is `bad_arguments` (both, without a schema,
///   still reaches `Function.apply` unchanged).
/// * Positional against a schema whose properties are exactly the
///   contiguous index keys `"0".."n-1"` validates the positional map
///   itself — the `"0"` style needs no `positionalNames`.
/// * Positional against any other property keys zips position `i` to
///   `positionalNames[i]`; missing names is `bad_arguments`, more values
///   than names is `bad_arguments`, fewer is fine (a missing required
///   name fails `required`).
/// * Positional against a schema with no `properties` demands nothing
///   further — the domain gate still runs.
String? validateBindingArguments(SkinBinding binding, WireRequest request) {
  final schema = binding.argumentSchema;
  if (schema == null) return null;

  final positional = request.positional;
  final named = request.named;
  final hasPositional = positional != null && positional.isNotEmpty;
  final hasNamed = named != null && named.isNotEmpty;

  if (hasPositional && hasNamed) {
    return 'send positional or named arguments, not both';
  }
  if (hasNamed) return validateJsonSchema(schema, named);
  if (!hasPositional) return validateJsonSchema(schema, const {});

  final properties = schema.properties;
  if (properties == null) return null;

  // Index form: the schema names `"0".."n-1"` — the positional map is
  // validated as-is.
  final schemaKeys = properties.keys.toList()..sort();
  var indexForm = schemaKeys.length == properties.length;
  for (var i = 0; i < schemaKeys.length; i++) {
    if (schemaKeys[i] != '$i') {
      indexForm = false;
      break;
    }
  }
  if (indexForm) return validateJsonSchema(schema, positional);

  final names = binding.positionalNames;
  if (names == null) {
    return 'positional arguments require positionalNames when schema '
        'properties are not index keys';
  }
  final orderedKeys = positional.keys.toList()
    ..sort((a, b) => int.tryParse(a)!.compareTo(int.tryParse(b)!));
  if (orderedKeys.length > names.length) {
    return 'too many positional arguments';
  }
  final zipped = <String, Object?>{
    for (var i = 0; i < orderedKeys.length; i++)
      names[i]: positional[orderedKeys[i]],
  };
  return validateJsonSchema(schema, zipped);
}
