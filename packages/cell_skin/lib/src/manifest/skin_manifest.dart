// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The tool catalogue: what the skin exposes, derived from the graph's
/// registered roots and the binding table.
/// {@category Features}
library;

import 'package:cell/cell.dart';

import '../binding/skin_binding.dart';
import '../binding/skin_whitelist.dart';
import '../wire/wire_schema.dart';

/// A technical description of a single interactable point on the membrane.
///
/// In the framework's biological metaphor, [SkinFunctionDescriptor] is a
/// **Synaptic Descriptor**. It defines the metadata for a specific
/// **Signal Label**, detailing how the environment can stimulate a cell
/// to undergo a **Somatic State Transition**.
///
/// These descriptors are the building blocks of the [SkinManifest] (the
/// **Somatic Index**), allowing external agents to understand the system's
/// "DNA" before initiating a **Command Journey**.
///
/// ### When to use
/// - **Discovery**: Provided to AI agents or dashboards so they know which
///   functions are physically exposed at the **Skin Membrane**.
/// - **Validation**: Used by clients to pre-screen payloads against the
///   advertised **Somatic Blueprint**.
///
/// ### How it works
/// 1. **Binding Extraction**: The descriptor is generated from a [SkinBinding].
/// 2. **Schema Resolution**: The [argumentSchema] is determined by prioritizing
///    explicit binding hints, then observed cell values, and finally falling
///    back to a permissive state.
/// 3. **Manifest Integration**: Multiple descriptors are grouped into a
///    [SkinCellDescriptor] to represent the full surface of a cell.
///
/// ### Non‑obvious behavior
/// - **Statelessness**: The descriptor is a static snapshot of a capability.
///   It does not represent a specific pulse or a historical ledger entry.
/// - **Immutability**: Once the membrane is open and the binding table is
///   sealed, these descriptors remain constant for the life of the connection.
///
/// ### See also
/// - [SkinCellDescriptor]: The container for these descriptors.
/// - [JsonSchema]: The structure used to define the [argumentSchema].
/// - [SkinBinding]: The source of truth for this descriptor.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is your tool definition.
/// **Live signature:** `final class SkinFunctionDescriptor { final String name; final String? description; final JsonSchema argumentSchema; final bool strictCursor; final List<String>? positionalNames; }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Causality:** Invoking the function named here initiates a command that
/// will be recorded in the **Forensic Ledger**.
/// **Constraint:** If [strictCursor] is true, you must provide a valid
/// `lastSeenSeq` to maintain **Causal Linkage**.
final class SkinFunctionDescriptor {
  /// The external **Signal Label** used to identify this function on the wire.
  ///
  /// In the framework's biological metaphor, this is the name assigned to a
  /// specific **Membrane Pore**. It maps a [WireRequest] to the correct
  /// internal application logic.
  final String name;

  /// A human and AI-readable description of the function's somatic purpose.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Context**.
  /// It explains the intended effect of the **Command Journey**, helping
  /// external agents decide when to stimulate this specific synaptic point.
  final String? description;

  /// The technical blueprint defining the valid arguments for this function.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Blueprint**.
  /// It defines the exact "nutrients" (arguments) required for a pulse to
  /// pass through the cell's **Integrity Gate**.
  final JsonSchema argumentSchema;

  /// Whether callers must provide a `lastSeenSeq` cursor to ensure
  /// **Causal Linkage**.
  ///
  /// When `true`, the **Skin Membrane** will reject any impulse that does
  /// not provide the correct sequence marker, preventing "Forensic
  /// Ambiguity" caused by out-of-order signals.
  final bool strictCursor;

  /// The schema property name for each positional wire argument (the
  /// binding's validation zipper), when the schema names properties
  /// rather than index keys. Shown to clients so `tools/list` can teach
  /// them the zipper; old manifests without the field still decode.
  final List<String>? positionalNames;

  const SkinFunctionDescriptor({
    required this.name,
    this.description,
    this.argumentSchema = JsonSchema.permissive,
    this.strictCursor = false,
    this.positionalNames,
  });

  /// Converts the descriptor into its **Skin Form** (JSON) for transport.
  Map<String, Object?> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    'argumentSchema': argumentSchema.toJson(),
    'strictCursor': strictCursor,
    if (positionalNames != null) 'positionalNames': positionalNames,
  };

  /// Decodes a **Skin Form** JSON map back into a [SkinFunctionDescriptor].
  ///
  /// This acts as a **Signal Decoder** at the membrane, reconstructing the
  /// capability metadata from the wire.
  factory SkinFunctionDescriptor.fromJson(Map<String, Object?> json) =>
      SkinFunctionDescriptor(
        name: json['name'] as String,
        description: json['description'] as String?,
        argumentSchema: json['argumentSchema'] == null
            ? JsonSchema.permissive
            : JsonSchema.fromJson(
            (json['argumentSchema'] as Map).cast<String, Object?>()),
        strictCursor: json['strictCursor'] as bool? ?? false,
        positionalNames: (json['positionalNames'] as List?)?.cast<String>(),
      );
}

/// A description of a single cell's physical surface at the membrane.
///
/// In the framework's biological metaphor, [SkinCellDescriptor] is a
/// **Somatic Address Record**. It groups all **Synaptic Points** (functions)
/// belonging to a specific cell, representing that cell's total "DNA"
/// exposure to the external environment.
///
/// ### When to use
/// - **Discovery**: Part of the [SkinManifest] used by AI agents to
///   understand the structure of a cell before stimulating it.
/// - **Routing**: Used by the membrane to identify which cell a specific
///   **Nervous Signal** is intended to reach.
///
/// ### How it works
/// 1. **Index Assembly**: The system identifies an exposed cell in the graph.
/// 2. **Capability Mapping**: It gathers all [SkinFunctionDescriptor]s
///    associated with that cell.
/// 3. **Descriptor Bundling**: These descriptors are packaged into this
///    structure for transport across the **Skin Membrane**.
///
/// ### Non‑obvious behavior
/// - **Authoritative Address**: The [cellId] is the permanent **Somatic Address**.
///   If a cell is renamed or moved within the graph without updating the
///   binding, the descriptor will fail to route signals.
/// - **Filtering**: Only functions that are whitelisted and correctly
///   bound appear in the [functions] list.
///
/// ### See also
/// - [SkinManifest]: The full index containing these records.
/// - [SkinFunctionDescriptor]: The descriptors for individual functions.
/// - [Cell.id]: The core framework's internal address for this cell.
final class SkinCellDescriptor {
  /// The unique identifier for the cell in the reactive graph.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Address**.
  /// It is the precise coordinate needed to route a **Nervous Signal** to
  /// the correct reactive unit.
  final String cellId;

  /// A human and AI-readable description of the cell's somatic role.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Context**.
  /// It explains the high-level purpose of the cell, providing metadata for
  /// external agents to determine if this cell is relevant to their objective.
  final String? description;

  /// The list of functions physically exposed for this cell.
  ///
  /// In the framework's biological metaphor, these are the **Synaptic Points**.
  /// They define the specific "pores" where external impulses can trigger
  /// a **Somatic State Transition**.
  final List<SkinFunctionDescriptor> functions;

  /// Creates a new [SkinCellDescriptor] for a somatic address.
  ///
  /// Assembles the **Somatic Address Record** for transport.
  const SkinCellDescriptor({
    required this.cellId,
    this.description,
    this.functions = const [],
  });

  /// Converts the descriptor into its **Skin Form** (JSON) for transport.
  ///
  /// Stays true to the forensic standard by preserving the [cellId] and
  /// all associated capability metadata.
  Map<String, Object?> toJson() => {
    'cellId': cellId,
    if (description != null) 'description': description,
    'functions': functions.map((f) => f.toJson()).toList(growable: false),
  };

  /// Decodes a **Skin Form** JSON map back into a [SkinCellDescriptor].
  ///
  /// Acts as a **Signal Decoder** at the membrane, reconstructing the
  /// address record from the wire.
  factory SkinCellDescriptor.fromJson(Map<String, Object?> json) =>
      SkinCellDescriptor(
        cellId: json['cellId'] as String,
        description: json['description'] as String?,
        functions: (json['functions'] as List? ?? const [])
            .map((f) => SkinFunctionDescriptor.fromJson(
            (f as Map).cast<String, Object?>()))
            .toList(growable: false),
      );
}

/// The system's discovery document, representing the complete external "DNA."
///
/// In the framework's biological metaphor, [SkinManifest] is the
/// **Somatic Index**. It is a comprehensive catalog of every
/// **Somatic Address Record** ([SkinCellDescriptor]) physically exposed
/// at the **Skin Membrane**.
///
/// ### When to use
/// - **Discovery Impulse**: Served in response to a `manifestRequest` to
///   inform AI agents, dashboards, and remote axons of the system's
///   available capabilities.
/// - **Initialization**: Used by [RemoteCellClient] to understand the
///   **Somatic Blueprints** (schemas) of a distant target.
///
/// ### How it works
/// 1. **Index Assembly**: The [describe] method walks the reactive graph.
/// 2. **Pore Mapping**: It correlates cells in the graph with the
///    [SkinBindingTable] to identify open pores.
/// 3. **Blueprint Resolution**: It extracts or induces the [JsonSchema]
///    for every function to build a complete capability map.
///
/// ### Non‑obvious behavior
/// - **DNA Stability**: The manifest is immutable once the membrane
///   is open. The [SkinBindingTable] seals at `open()`, ensuring the
///   **Somatic Index** remains a stable source of truth.
/// - **Root Prioritization**: The manifest orders cells based on their
///   registration in the [CellGraph], ensuring "Root Cells" appear first
///   in discovery.
///
/// ### See also
/// - [SkinCellDescriptor]: The per-cell records contained in the index.
/// - [SkinBinding]: The source of truth for exposure and blueprints.
/// - [SkinRouter]: The junction that handles the `manifestRequest`.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is your primary discovery tool.
/// **Live signature:** `final class SkinManifest { final List<SkinCellDescriptor> cells; const SkinManifest({required List<SkinCellDescriptor> cells}); static SkinManifest describe({required CellGraph graph, required SkinBindingTable bindings, SkinWhitelist? whitelist, Map<String, String>? descriptions, void Function(String cellId)? onUnregistered}); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Traceability:** Every function listed here initiates a
/// **Command Journey** that results in a **Forensic Ledger** entry.
final class SkinManifest {
  /// The collection of exposed cells, representing the **Somatic Address Records**.
  ///
  /// The list is ordered according to graph-registration (roots first) to
  /// prioritize primary somatic entry points.
  final List<SkinCellDescriptor> cells;

  /// Creates a new [SkinManifest] from a list of cell descriptors.
  const SkinManifest({required this.cells});

  /// The total number of **Synaptic Points** (functions) exposed across all cells.
  int get toolCount => cells.fold(0, (sum, c) => sum + c.functions.length);

  /// Assembles the **Somatic Index** from the current graph and binding state.
  ///
  /// This process performs **Index Assembly**:
  /// 1. It walks the [graph] roots to establish the primary hierarchy.
  /// 2. It consults the [bindings] to determine which cells have open pores.
  /// 3. It applies the [whitelist] to filter the final advertised surface.
  ///
  /// If a binding exists for a cell not present in the [graph], it is
  /// considered a "Forensic Orphan" and is reported via [onUnregistered]
  /// rather than being indexed.
  static SkinManifest describe({
    required CellGraph graph,
    required SkinBindingTable bindings,
    SkinWhitelist? whitelist,
    Map<String, String>? descriptions,
    void Function(String cellId)? onUnregistered,
  }) {
    final descriptors = <SkinCellDescriptor>[];
    final advertised = <String>{};
    for (final root in graph.roots) {
      final cellId = root.name;
      if (!bindings.exposesCell(cellId)) continue;
      advertised.add(cellId);
      final functions = _functionsFor(cellId, bindings, whitelist);
      if (functions.isNotEmpty) {
        descriptors.add(SkinCellDescriptor(
          cellId: cellId,
          description: descriptions?[cellId],
          functions: functions,
        ));
      }
    }
    // Bindings whose cell is not a graph root (or not registered).
    for (final cellId in bindings.exposedCellIds) {
      if (advertised.contains(cellId)) continue;
      if (!graph.containsName(cellId)) {
        onUnregistered?.call(cellId);
        continue;
      }
      final functions = _functionsFor(cellId, bindings, whitelist);
      if (functions.isNotEmpty) {
        descriptors.add(SkinCellDescriptor(
          cellId: cellId,
          description: descriptions?[cellId],
          functions: functions,
        ));
      }
    }
    return SkinManifest(cells: List.unmodifiable(descriptors));
  }

  static List<SkinFunctionDescriptor> _functionsFor(
    String cellId,
    SkinBindingTable bindings,
    SkinWhitelist? whitelist,
  ) =>
      [
        for (final binding in bindings.bindingsFor(cellId))
          if (whitelist == null ||
              whitelist.allows(cellId, binding.functionName))
            SkinFunctionDescriptor(
              name: binding.functionName,
              description: binding.description,
              argumentSchema: _schemaFor(binding),
              strictCursor: binding.strictCursor,
              positionalNames: binding.positionalNames,
            ),
      ];

  /// The advertised schema: the binding's explicit hint wins; otherwise
  /// the target's current value is observed (`Cell.state` targets);
  /// otherwise the permissive `{}` schema.
  static JsonSchema _schemaFor(SkinBinding binding) {
    final explicit = binding.argumentSchema;
    if (explicit != null) return explicit;
    final target = binding.target;
    if (target is ValueCell<dynamic>) return schemaForValue(target.value);
    return JsonSchema.permissive;
  }

  /// Converts the manifest into its **Skin Form** (JSON) for transport.
  ///
  /// Encodes the complete **Somatic Index** for delivery across the membrane.
  Map<String, Object?> toJson() => {
    'cells': cells.map((c) => c.toJson()).toList(growable: false),
  };

  /// Decodes a **Skin Form** JSON map back into a [SkinManifest].
  ///
  /// Acts as a **Signal Decoder** for discovery responses.
  factory SkinManifest.fromJson(Map<String, Object?> json) => SkinManifest(
    cells: (json['cells'] as List? ?? const [])
        .map((c) =>
        SkinCellDescriptor.fromJson((c as Map).cast<String, Object?>()))
        .toList(growable: false),
  );
}
