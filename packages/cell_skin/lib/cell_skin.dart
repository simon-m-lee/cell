// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// **cell_skin** — the membrane between a Cell graph and the outside
/// world. MCP-native, audit-ready, replay-verifiable.
///
/// The wire is a `Pulse<WireMessage>` stream; the membrane is four
/// Cells composed from framework primitives:
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
///   ..register(SkinBinding(
///     cellId: 'thermostat',
///     functionName: 'setTarget',
///     target: thermostatCell,
///     function: (int target) => thermostatHandle.update(target),
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
/// {@category Getting Started}
/// {@category Features}
/// {@category Architecture}
/// {@category Demo}
/// {@category Test Verification}
/// {@category Testing}
library;

export 'src/wire/wire_message.dart';
export 'src/wire/wire_outcome.dart';
export 'src/wire/wire_receipt.dart';
export 'src/wire/wire_ledger.dart';
export 'src/wire/wire_schema.dart';

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
