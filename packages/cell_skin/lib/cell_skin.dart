// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The physical boundary layer between the internal somatic graph and the external environment.
/// MCP-native, audit-ready, replay-verifiable.
///
/// In the framework's biological metaphor, **cell_skin** is the **Skin Membrane**.
/// It acts as a specialized organ responsible for translating **Nervous Signals**
/// (external requests) into **Somatic State Transitions** (internal logic) while
/// ensuring absolute **Forensic Integrity**.
///
/// ```text
/// Cell.ingress → Cell.asyncMap → target.apply → Cell.observe → Cell.observe
/// (inbound)      (router)          (the plug)     (egress)        (outbound)
/// ```
///
/// Quick start:
///
/// ```dart
/// final graph = (CellGraph.builder(graphId: 'demo')
///       ..register('thermostat', thermostatCell))
///     .build();
/// final ledger = await graph.bindLedger(
///   store: InMemoryLedgerStore(genesisHash: Ledger.genesisHashOf(graph.id)),
/// );
/// final bindings = SkinBindingTable()
///   ..register(SkinBinding.state(
///     cellId: 'thermostat',
///     functionName: 'setTarget',
///     target: thermostatCell,
///     nextValue: (int target) => target,
///   ));
/// final membrane = await SkinMembrane.open(
///   graph: graph,
///   bindings: bindings,
///   ledger: ledger,
///   journal: RecordingJournal(),
///   send: (_) {}, // the transport's writer
/// );
/// final client = SkinClient(membrane: membrane);
/// final outcome = await client.apply('thermostat', 'setTarget',
///     positional: [19]);
/// ```
///
/// ### The Command Journey
/// Every impulse arriving at the membrane follows a strictly governed path:
/// 1.  **Ingress ([InboundCell])**: The signal enters the membrane as a raw **Skin Payload**.
/// 2.  **Integrity Gate ([SkinAuth] & [ContextBridge])**: The signal's identity DNA
///     is verified and translated into internal authority.
/// 3.  **Routing ([RouterCell])**: The **Nervous Signal** is dispatched to the correct
///     cell address within the somatic graph.
/// 4.  **Application**: The target cell processes the pulse. If accepted, it creates
///     a **Forensic Receipt** anchored in the **Forensic Ledger**.
/// 5.  **Egress ([EgressCell] & [MuxCell])**: The result is sanitized into its **Skin Form**
///     and broadcast back through the membrane to the environment.
///
/// ### Forensic Integrity
/// This package is designed for high-stakes environments where every change must
/// be auditable. By leveraging the **Forensic Ledger**, `cell_skin` ensures that:
/// - Every successful transition is replay-verifiable.
/// - Failures at the membrane (rejections) are reported as **Membrane Rejections**
///   ([WireError]) to prevent "Forensic Holes."
/// - The system's "DNA" (capabilities) is discoverable via the **Somatic Index**
///   ([SkinManifest]).
///
/// ### AI-Native Governance
/// `cell_skin` is native to the Model Context Protocol (MCP). It uses [JsonSchema]
/// to describe its exposed surface, allowing AI agents to interact with somatic
/// cells with high precision and safety.
///
/// ### Components
/// - **Adapters**: Connect the membrane to physical transports (MCP, SSE, REST).
/// - **Security**: Defines the gatekeepers ([SkinAuth]) and translators ([ContextBridge])
///   that govern signal entry.
/// - **Bindings**: Maps internal Dart functions to external **Signal Labels**.
/// - **Client**: Provides a high-level API ([SkinClient]) for external systems to
///   trigger journeys.
/// {@category Getting Started}
/// {@category Features}
/// {@category Architecture}
/// {@category Demo}
/// {@category Test Verification}
/// {@category Testing}
library;

export 'src/wire/correlation_id.dart';
export 'src/wire/wire_message.dart';
export 'src/wire/wire_outcome.dart';
export 'src/wire/wire_receipt.dart';
export 'src/wire/wire_version.dart';
export 'src/wire/wire_ledger.dart';
export 'src/wire/wire_schema.dart';
export 'src/wire/idempotency_store.dart';

export 'src/binding/skin_binding.dart';
export 'src/binding/skin_whitelist.dart';

export 'src/manifest/skin_manifest.dart';

export 'src/cells/inbound_cell.dart';
export 'src/cells/router_cell.dart';
export 'src/cells/egress_cell.dart';
export 'src/cells/mux_cell.dart';
export 'src/cells/skin_membrane.dart';

export 'src/adapters/mcp/mcp_adapter.dart';
// The REST adapter lives in `cell_skin_rest.dart` — it imports
// `dart:io`, which must not leak into this barrel (web consumers).

export 'src/client/skin_client.dart';
export 'src/client/skin_error.dart';
export 'src/client/remote_cell.dart';

export 'src/security/skin_auth.dart';
export 'src/security/context_bridge.dart';
export 'src/security/skin_call.dart';
export 'src/security/skin_policy.dart';
