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

/// One exposed function in the catalogue.
final class SkinFunctionDescriptor {
  /// The wire-facing function name.
  final String name;

  /// Human-readable description, when the binding supplied one.
  final String? description;

  /// The advertised JSON Schema (binding hint, observed shape, or
  /// permissive).
  final JsonSchema argumentSchema;

  /// Whether callers must send a `lastSeenSeq` cursor.
  final bool strictCursor;

  const SkinFunctionDescriptor({
    required this.name,
    this.description,
    this.argumentSchema = JsonSchema.permissive,
    this.strictCursor = false,
  });

  Map<String, Object?> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'argumentSchema': argumentSchema.toJson(),
        'strictCursor': strictCursor,
      };

  factory SkinFunctionDescriptor.fromJson(Map<String, Object?> json) =>
      SkinFunctionDescriptor(
        name: json['name'] as String,
        description: json['description'] as String?,
        argumentSchema: json['argumentSchema'] == null
            ? JsonSchema.permissive
            : JsonSchema.fromJson(
                (json['argumentSchema'] as Map).cast<String, Object?>()),
        strictCursor: json['strictCursor'] as bool? ?? false,
      );
}

/// One exposed cell in the catalogue.
final class SkinCellDescriptor {
  /// The registered graph name.
  final String cellId;

  /// Human-readable description, when supplied.
  final String? description;

  /// The exposed functions, in binding-registration order.
  final List<SkinFunctionDescriptor> functions;

  const SkinCellDescriptor({
    required this.cellId,
    this.description,
    this.functions = const [],
  });

  Map<String, Object?> toJson() => {
        'cellId': cellId,
        if (description != null) 'description': description,
        'functions': functions.map((f) => f.toJson()).toList(growable: false),
      };

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

/// The skin's discovery document: every exposed cell and function.
///
/// ### When to use
/// * Serving `GET /skin/manifest`, MCP `tools/list`, and the demo's
/// tool-discovery beat.
///
/// ### How it works
/// [SkinManifest.describe] walks the binding table (and optional
/// whitelist): per-function descriptions fall back to the cell's
/// description, and argument schemas resolve as explicit hint →
/// observed live cell value → permissive.
///
/// ### Non-obvious
/// The manifest is immutable because the binding table seals at
/// `open()` — any manifest response can complete any manifest waiter.
///
/// ### See also
/// [SkinBinding], [schemaForValue], [McpAdapter].
final class SkinManifest {
  /// Exposed cells, in graph-registration order (roots first).
  final List<SkinCellDescriptor> cells;

  const SkinManifest({required this.cells});

  /// The total number of exposed functions.
  int get toolCount => cells.fold(0, (sum, c) => sum + c.functions.length);

  /// Builds the manifest from [graph] and [bindings].
  ///
  /// [whitelist] restricts the catalogue to whitelisted entries; when
  /// `null`, every registered binding is advertised. Only cells that
  /// are registered in [graph] appear — a binding to an unregistered
  /// cell is a programming error and is reported (via [onUnregistered])
  /// rather than silently advertised.
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

  Map<String, Object?> toJson() => {
        'cells': cells.map((c) => c.toJson()).toList(growable: false),
      };

  factory SkinManifest.fromJson(Map<String, Object?> json) => SkinManifest(
        cells: (json['cells'] as List? ?? const [])
            .map((c) =>
                SkinCellDescriptor.fromJson((c as Map).cast<String, Object?>()))
            .toList(growable: false),
      );
}
