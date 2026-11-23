// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The MCP adapter seam.
///
/// `cell_skin` does **not** implement MCP — that is `dart_mcp`'s job.
/// This library defines the seam every MCP SDK adapter implements and
/// the neutral tool-spec translation from a [SkinManifest], so choosing
/// `dart_mcp` vs `mcp_dart` stays a pubspec decision, not an
/// architecture decision. The concrete `DartMcpAdapter` ships once the
/// SDK dependency is promoted into this package's pubspec.
/// {@category Features}
library;

import '../../manifest/skin_manifest.dart';
import '../../wire/wire_schema.dart';

/// The adapter lifecycle contract every MCP SDK adapter implements.
/// {@category MCP Seam}
abstract interface class McpAdapter {
  /// Registers the tool catalogue and subscriptions, then starts the
  /// server.
  Future<void> start();

  /// Closes the server and releases the transport.
  Future<void> close();
}

/// A transport-neutral MCP tool definition, translated from a
/// [SkinFunctionDescriptor]. An SDK adapter maps these 1:1 onto
/// `dart_mcp`'s `Tool`, `mcp_dart`'s tool descriptors, or any other
/// SDK's equivalent.
final class McpToolSpec {
  /// `<cellId>.<functionName>`.
  final String name;

  final String? description;

  final JsonSchema inputSchema;

  const McpToolSpec({
    required this.name,
    this.description,
    this.inputSchema = JsonSchema.permissive,
  });

  Map<String, Object?> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'inputSchema': inputSchema.toJson(),
      };
}

/// Translates a [SkinManifest] into neutral tool specs for MCP
/// `tools/list`.
///
/// The name is `<cellId>.<functionName>`. Both parts are validated to
/// be dot-free and the combined names are checked for collisions, so a
/// spec name always round-trips back to exactly one binding.
/// {@category MCP Seam}
List<McpToolSpec> mcpToolSpecs(SkinManifest manifest) {
  final specs = <McpToolSpec>[
    for (final cell in manifest.cells)
      for (final function in cell.functions)
        McpToolSpec(
          name: _toolName(cell.cellId, function.name),
          description: function.description ?? cell.description,
          inputSchema: function.argumentSchema,
        ),
  ];
  final seen = <String>{};
  for (final spec in specs) {
    if (!seen.add(spec.name)) {
      throw StateError(
          'mcpToolSpecs: ambiguous tool name "${spec.name}" — cell ids '
          'and function names must be dot-free and their combinations '
          'unique');
    }
  }
  return specs;
}

String _toolName(String cellId, String functionName) {
  if (cellId.contains('.') || functionName.contains('.')) {
    throw StateError('mcpToolSpecs: cell id "$cellId" and function name '
        '"$functionName" must not contain "." — the MCP tool name is '
        '<cellId>.<functionName> and must round-trip');
  }
  return '$cellId.$functionName';
}

/// A transport-neutral MCP resource definition for the graph topology
/// (`cell://graph/<cellId>`) and the ledger stream.
final class McpResourceSpec {
  final String name;
  final String uri;

  const McpResourceSpec({required this.name, required this.uri});
}

/// Resource specs for every exposed cell.
List<McpResourceSpec> mcpResourceSpecs(SkinManifest manifest) => [
      for (final cell in manifest.cells)
        McpResourceSpec(name: cell.cellId, uri: 'cell://graph/${cell.cellId}'),
    ];
