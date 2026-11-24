// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The AI synaptic seam of the boundary layer.
///
/// In the framework's biological metaphor, this library defines the
/// **Synaptic Seam**. It provides the neutral interface and translation
/// logic required for the **Skin Membrane** to communicate with external
/// AI nervous systems via the Model Context Protocol (MCP).
///
/// ### Why this exists
/// By defining a transport-neutral seam, the framework ensures that the
/// choice of a specific MCP SDK (e.g., `dart_mcp` vs `mcp_dart`) remains a
/// deployment detail rather than an architectural constraint. This allows
/// the core somatic logic and the **Forensic Ledger** to remain decoupled
/// from the volatility of external AI protocol implementations.
///
/// ### The Synaptic Journey
/// 1.  **Discovery Impulse**: This library provides the logic to translate
///     the **Somatic Index** (manifest) into a vocabulary the AI agent
///     can understand using [mcpToolSpecs] and [mcpResourceSpecs].
/// 2.  **Synaptic Mapping**: It maps internal somatic coordinates (cell IDs)
///     into stable **Synaptic Labels** (tool names) for unambiguous routing.
/// 3.  **Command Journey**: It establishes the contract for [McpAdapter]
///     implementations to ingest **Nervous Signals** and return sanitized
///     results back through the membrane.
///
/// ### Forensic Integrity
/// While this library handles the high-level mapping for AI agents, it
/// strictly adheres to the framework's forensic standards. All interactions
/// facilitated by this seam are designed to be anchored in the
/// **Forensic Ledger**, ensuring that AI-driven **Somatic State Transitions**
/// are as traceable as those triggered by human actors.
///
/// ### See also
/// - [McpAdapter]: The interface for concrete transport implementations.
/// - [McpToolSpec]: The neutral descriptor for interactable somatic functions.
/// - [SkinMembrane]: The boundary layer this seam extends.
/// {@category Features}
library;

import '../../manifest/skin_manifest.dart';
import '../../wire/wire_schema.dart';

/// The lifecycle contract for bridging the somatic graph to an AI agent via the Model Context Protocol.
///
/// In the framework's biological metaphor, [McpAdapter] is the **AI Synaptic Bridge**.
/// It acts as a specialized **Membrane Pore** designed specifically for high-bandwidth
/// communication with external AI "nervous systems."
///
/// While [SkinMembrane] handles the general boundary logic, this adapter provides the
/// physical transport seam. It allows an AI agent to perform a **Discovery Impulse**
/// to read the **Somatic Index** (manifest) and subsequently trigger **Command Journeys**
/// via MCP tool calls.
///
/// ### Why this exists
/// This interface decouples the framework's governance from specific MCP SDK
/// implementations. By providing a neutral seam, the framework can support
/// different SDKs (like `dart_mcp` or `mcp_dart`) without altering the
/// internal somatic logic.
///
/// ### How it works
/// 1. **Sensitization**: On [start], the adapter opens a communication channel.
/// 2. **Discovery**: It exposes the [SkinManifest] as a set of MCP Tools and Resources.
/// 3. **Pulse Ingress**: External tool calls are converted into **Nervous Signals**
///    and dispatched through the membrane.
/// 4. **Forensic Return**: The results of **Somatic State Transitions** are translated
///    back into MCP-compliant tool responses.
///
/// ### Non‑obvious behavior
/// - **Neutral Translation**: The adapter must use [mcpToolSpecs] to ensure
///   that tool names and schemas are deterministic and round-trippable.
/// - **Forensic Integrity**: The adapter is responsible for ensuring that
///   transport-level MCP errors are correctly reported as **Membrane Rejections**
///   ([WireError]) to prevent gaps in the external audit trail.
///
/// ### See also
/// - [SkinMembrane]: The core boundary orchestrator.
/// - [McpToolSpec]: The neutral representation of a cell's "DNA" for AI agents.
/// - [wire_message.dart]: Definitions for the envelopes that cross this bridge.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is your primary connection point to the system.
/// **Live signature:** `abstract interface class McpAdapter { Future<void> start(); Future<void> close(); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** experimental
/// **Discovery:** This bridge provides the tool definitions you use to interact.
/// **Governance:** Every tool call you make here initiates a **Command Journey**
/// that must pass an **Integrity Gate** before being written to the **Forensic Ledger**.
abstract interface class McpAdapter {
  /// Opens the **Synaptic Bridge** and begins broadcasting the system's capabilities.
  ///
  /// In the framework's biological metaphor, this "sensitizes the pore." It
  /// registers the **Somatic Index** (manifest) as a tool catalogue and
  /// prepares the system to receive **Nervous Signals** from the AI agent.
  ///
  /// This must be called before the agent can discover or interact with cells.
  Future<void> start();

  /// Closes the **Synaptic Bridge** and releases the physical transport.
  ///
  /// In the framework's biological metaphor, this "seals the pore." It
  /// terminates the connection to the external AI nervous system and
  /// ensures no further impulses can cross the membrane via this channel.
  Future<void> close();
}

/// A transport-neutral definition of an interactable somatic function, formatted for AI consumption.
///
/// In the framework's biological metaphor, [McpToolSpec] is a **Synaptic Tool Descriptor**.
/// It represents a specific segment of the system's "DNA" ([SkinFunctionDescriptor])
/// that has been physically exposed at the **Skin Membrane** for external AI stimulation.
///
/// This class acts as the bridge between the framework's internal [JsonSchema]
/// and the tool definitions required by Model Context Protocol (MCP) clients.
///
/// ### When to use
/// - **Discovery**: Generated during a **Discovery Impulse** to populate
///   the `tools/list` response for an AI agent.
/// - **Schema Mapping**: Used by the [McpAdapter] to ensure that external
///   tool calls are validated against the correct **Somatic Blueprint**.
///
/// ### How it works
/// 1. **Extraction**: The system reads a [SkinFunctionDescriptor] from the
///    **Somatic Index** (manifest).
/// 2. **Translation**: The descriptor is converted into this neutral spec,
///    mapping the cell and function names into a stable **Synaptic Label**.
/// 3. **Broadcasting**: The [McpAdapter] serializes this spec into the
///    specific format required by the AI agent's transport (e.g., JSON-RPC).
///
/// ### Non‑obvious behavior
/// - **Atomicity**: A tool spec represents exactly one `apply` target. It
///   cannot bridge multiple cells; each cell/function pair is a distinct
///   synaptic point.
/// - **Two names, one tool**: [name] is the escaped MCP wire name —
///   characters outside `[A-Za-z0-9_-]` become `_` — and is the **only**
///   name registered; [dottedName] is the raw `<cellId>.<functionName>`.
///   An adapter that maps `toJson()` onto an SDK tool must not also
///   register `dottedName`, or the model sees two tools for one binding.
///
/// ### See also
/// - [McpAdapter]: The bridge that broadcasts these specs.
/// - [SkinFunctionDescriptor]: The internal metadata this spec represents.
/// - [JsonSchema]: The blueprint defining valid inputs for this tool.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is your primary tool definition.
/// **When to use:** a BRD says "register the tool with an MCP host" —
/// register [name] once and pass `toJson()` to the SDK's tool.
/// **When NOT to use:** dispatching a call — use `resolveMcpToolCall`,
/// which accepts [name] and [dottedName].
/// **Live signature:** `final class McpToolSpec { final String name; final String dottedName; final String cellId; final String functionName; final String? description; final JsonSchema inputSchema; const McpToolSpec({required String name, required String dottedName, required String cellId, required String functionName, String? description, JsonSchema inputSchema = JsonSchema.permissive}); Map<String, Object?> toJson(); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** experimental
/// **Do NOT confuse with:** `McpResourceSpec` (observational URI) or a
/// registered SDK tool object.
/// **Guide:** `HowTo-McpSeam.md` (naming and dispatch).
/// **Causality:** Invoking a tool defined by this spec initiates a
/// **Command Journey** that will be recorded in the **Forensic Ledger**.
/// **Constraint:** The `inputSchema` is authoritative; pulses that do not
/// match this DNA will be rejected at the membrane.
final class McpToolSpec {
  /// The escaped MCP tool name — the only name a host registers.
  ///
  /// Characters outside `[A-Za-z0-9_-]` are replaced with `_` (a dot
  /// becomes `_`, and so does `/`, a space, and anything else).
  /// Repeated underscores are not collapsed, no prefix is added, and
  /// the name is never truncated.
  final String name;

  /// The raw binding name: `<cellId>.<functionName>`, dots included.
  final String dottedName;

  /// The binding's cell id, as the manifest exposed it.
  final String cellId;

  /// The binding's function name, as the manifest exposed it.
  final String functionName;

  /// A human and AI-readable description of the tool's somatic purpose.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Context**.
  /// It explains the intended effect of the **Command Journey**, helping
  /// the AI agent decide when to stimulate this specific synaptic point.
  final String? description;

  /// The technical blueprint defining the valid arguments for the tool.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Blueprint**.
  /// It defines the exact "nutrients" (arguments) required for a pulse to
  /// pass through the cell's **Integrity Gate**.
  final JsonSchema inputSchema;

  /// Creates a new [McpToolSpec] to describe an exposed somatic function.
  ///
  /// Assembles the **Synaptic Tool Descriptor** for transport. By default,
  /// it uses a [JsonSchema.permissive] blueprint if no specific DNA
  /// constraints are provided.
  const McpToolSpec({
    required this.name,
    required this.dottedName,
    required this.cellId,
    required this.functionName,
    this.description,
    this.inputSchema = JsonSchema.permissive,
  });

  /// Converts the spec into its **Skin Form** (JSON) for transport.
  ///
  /// This produces the wire-safe representation of the tool, ensuring
  /// compatibility with MCP-compliant AI agents and debuggers. `name` is
  /// the registered tool; `dottedName` travels as metadata, not as a
  /// second registration.
  Map<String, Object?> toJson() => {
    'name': name,
    'dottedName': dottedName,
    if (description != null) 'description': description,
    'inputSchema': inputSchema.toJson(),
  };
}

/// A tool call decoded from an MCP tool name.
final class McpToolCall {
  final String cellId;
  final String functionName;
  final String name;
  final String dottedName;

  const McpToolCall({
    required this.cellId,
    required this.functionName,
    required this.name,
    required this.dottedName,
  });
}

/// The characters MCP tool names must not contain: anything outside
/// letters, digits, `_`, and `-`.
final RegExp _unsafeToolNameChar = RegExp(r'[^A-Za-z0-9_-]');

/// The escaped MCP wire name for a binding.
///
/// `.` becomes `_`, and so does `/`, a space, and anything else outside
/// `[A-Za-z0-9_-]`. Repeated underscores are not collapsed (`a..b` stays
/// `a__b`), no prefix is added, and nothing is truncated.
String mcpEscapedToolName(String cellId, String functionName) =>
    '$cellId.$functionName'.replaceAll(_unsafeToolNameChar, '_');

/// Translates a [SkinManifest] into neutral tool specs for AI discovery.
///
/// In the framework's biological metaphor, this function performs **Synaptic Mapping**.
/// It converts the **Somatic Index** (the manifest) into a catalog of **Synaptic Tool
/// Descriptors** ([McpToolSpec]) that an external AI agent can stimuate via
/// a **Discovery Impulse** (e.g., an MCP `tools/list` request).
///
/// ### When to use
/// - **Discovery**: The primary logic used by an [McpAdapter] to tell an AI
///   agent which cells and functions are physically exposed at the
///   **Skin Membrane**.
///
/// ### How it works
/// 1. **Index Iteration**: It walks through every cell and function recorded
///    in the manifest's "DNA."
/// 2. **Label Construction**: It generates the escaped wire [McpToolSpec.name]
///    for each pair, keeping the raw pair on [McpToolSpec.dottedName].
/// 3. **Integrity Check**: Every accepted alias (`name` and `dottedName`)
///    must map to exactly one binding, and a name must fit 64 characters.
///    A collision throws [StateError] before a list is returned.
///
/// ### Non‑obvious behavior
/// - **Forensic Integrity**: A collision is a `StateError` that names both
///   bindings; the lookup is a map, never a split of the dotted string
///   (that split is ambiguous by construction).
/// - **Description Inheritance**: If a specific function lacks a description,
///   it inherits the description of its parent cell to provide the AI agent
///   with maximum **Somatic Context**.
///
/// ### See also
/// - [McpToolSpec]: The descriptor being generated.
/// - [SkinManifest]: The somatic index being translated.
List<McpToolSpec> mcpToolSpecs(SkinManifest manifest) {
  final specs = <McpToolSpec>[];
  final owners = <String, (String, String)>{};

  void claim(String alias, String cellId, String functionName) {
    final previous = owners[alias];
    if (previous != null &&
        (previous.$1 != cellId || previous.$2 != functionName)) {
      throw StateError(
        'mcpToolSpecs: "$alias" is both '
        '${previous.$1}.${previous.$2} and $cellId.$functionName',
      );
    }
    owners[alias] = (cellId, functionName);
  }

  for (final cell in manifest.cells) {
    for (final function in cell.functions) {
      if (cell.cellId.isEmpty || function.name.isEmpty) {
        throw StateError(
          'mcpToolSpecs: empty cellId or functionName produces no valid '
          'tool name',
        );
      }
      final dottedName = '${cell.cellId}.${function.name}';
      final name = mcpEscapedToolName(cell.cellId, function.name);
      if (name.length > 64) {
        throw StateError(
          'mcpToolSpecs: tool name "$name" for $dottedName is '
          '${name.length} characters; MCP hosts allow at most 64',
        );
      }
      claim(name, cell.cellId, function.name);
      claim(dottedName, cell.cellId, function.name);
      specs.add(McpToolSpec(
        name: name,
        dottedName: dottedName,
        cellId: cell.cellId,
        functionName: function.name,
        description: function.description ?? cell.description,
        inputSchema: function.argumentSchema,
      ));
    }
  }
  return specs;
}

/// Resolves an MCP tool name to a binding.
///
/// Walks [mcpToolSpecs] and returns the spec whose [McpToolSpec.name] or
/// [McpToolSpec.dottedName] equals [toolName]. Anything else — including
/// `''` and a name with a newline — returns `null`; an unknown name never
/// throws. A colliding manifest still throws, because [mcpToolSpecs]
/// throws.
McpToolCall? resolveMcpToolCall(SkinManifest manifest, String toolName) {
  for (final spec in mcpToolSpecs(manifest)) {
    if (spec.name == toolName || spec.dottedName == toolName) {
      return McpToolCall(
        cellId: spec.cellId,
        functionName: spec.functionName,
        name: spec.name,
        dottedName: spec.dottedName,
      );
    }
  }
  return null;
}

/// The tool result an SDK adapter returns for an unknown tool call.
///
/// It is a normal tool result with `isError: true` — not a JSON-RPC
/// error — and the text is the code only. The caller's string is never
/// echoed, and `membrane.request` is not called.
Map<String, Object?> mcpUnknownToolResult() => {
  'isError': true,
  'content': [
    {'type': 'text', 'text': 'unknown_tool'},
  ],
};

/// A transport-neutral definition of an observational somatic resource.
///
/// In the framework's biological metaphor, [McpResourceSpec] is a
/// **Somatic Map Segment**. It describes a read-only observational point
/// physically exposed at the **Skin Membrane**, such as the topology of
/// a specific cell or a live stream of the **Forensic Ledger**.
///
/// Unlike [McpToolSpec], which represents an entry point for a **Command Journey**,
/// a resource spec represents a passive probe into the system's current
/// state or history.
///
/// ### When to use
/// - **Discovery**: Generated during a **Discovery Impulse** to populate
///   the `resources/list` response for an AI agent.
/// - **State Inspection**: Used by agents to locate the **Somatic Address**
///   of a cell's data without triggering a mutation.
///
/// ### How it works
/// 1. **Index Resolution**: The system identifies a cell or ledger stream
///    marked for public observation.
/// 2. **Address Mapping**: It constructs a URI (typically `cell://graph/<id>`)
///    representing the physical location of the data.
/// 3. **Broadcasting**: The [McpAdapter] serializes this spec to inform
///    the AI agent where it can "listen" to the somatic pulse.
///
/// ### Non‑obvious behavior
/// - **ReadOnly**: Resources are strictly observational. They never
///   trigger a **Somatic State Transition**.
/// - **URI Stability**: The `uri` is the authoritative **Somatic Address**.
///   Agents should treat this URI as a stable pointer to the cell's
///   phenotype or history.
///
/// ### See also
/// - [McpAdapter]: The bridge that broadcasts these resources.
/// - [McpToolSpec]: For interactable functions that change state.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this provides your observational context.
/// **Live signature:** `final class McpResourceSpec { final String name; final String uri; const McpResourceSpec({required String name, required String uri}); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** experimental
/// **Traceability:** Reading a resource is not ledgered as a state change.
/// **Protocol:** Use the provided `uri` to fetch the current state of a cell.
final class McpResourceSpec {
  /// The human-readable name of the somatic resource.
  ///
  /// In the framework's biological metaphor, this is the **Trait Label**.
  /// It identifies the segment of the graph or ledger being exposed,
  /// usually matching the [Cell.id].
  final String name;

  /// The authoritative URI for the resource.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Address**.
  /// It provides the precise location (e.g., `cell://graph/my_cell`) needed
  /// for an agent to pull state information through the **Skin Membrane**.
  final String uri;

  /// Creates a new [McpResourceSpec] to describe an observational point.
  ///
  /// Assembles the **Somatic Map Segment** for transport, allowing external
  /// systems to locate and inspect parts of the somatic graph.
  const McpResourceSpec({required this.name, required this.uri});
}

/// Translates a [SkinManifest] into neutral resource specs for AI observation.
///
/// In the framework's biological metaphor, this function performs **Somatic
/// Map Assembly**. It converts the **Somatic Index** (the manifest) into a
/// catalog of **Somatic Map Segments** ([McpResourceSpec]) that an external
/// AI agent can use to locate and inspect the state of the graph.
///
/// ### When to use
/// - **Discovery**: The primary logic used by an [McpAdapter] to fulfill a
///   **Discovery Impulse** (e.g., an MCP `resources/list` request), telling
///   the agent where it can find observational data.
///
/// ### How it works
/// 1. **Index Resolution**: It iterates through every cell recorded in the
///    manifest's "DNA."
/// 2. **Address Generation**: It constructs a stable **Somatic Address**
///    (URI) for each cell, typically using the `cell://graph/<cellId>` scheme.
/// 3. **Segment Creation**: It bundles the cell ID and URI into a
///    [McpResourceSpec] for transport across the **Skin Membrane**.
///
/// ### Non‑obvious behavior
/// - **Passive Observation**: Unlike tool specs, which trigger **Command
///   Journeys**, the resources generated here are strictly for observation.
///   Reading these URIs does not trigger a **Somatic State Transition** and
///   leaves no entry in the **Forensic Ledger**.
/// - **Granularity**: This function currently generates one resource per
///   cell. It does not yet map internal cell sub-paths or specific
///   historical ledger ranges unless they are explicitly defined as
///   exposed cells in the manifest.
///
/// ### See also
/// - [McpResourceSpec]: The descriptor being generated.
/// - [SkinManifest]: The somatic index being translated.
/// - [mcpToolSpecs]: The counterpart for mapping interactable functions.
List<McpResourceSpec> mcpResourceSpecs(SkinManifest manifest) => [
  for (final cell in manifest.cells)
    McpResourceSpec(name: cell.cellId, uri: 'cell://graph/${cell.cellId}'),
];
