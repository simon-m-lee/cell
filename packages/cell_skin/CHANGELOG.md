# Changelog

## 0.1.0 - The Four-Cell Membrane

First release of **cell_skin**:
the membrane between a Cell graph and remote consumers, where the wire is a
`Pulse<WireMessage>` stream and the membrane is four Cells composed from
framework primitives.

### Added

- **Wire taxonomy** (`lib/src/wire/`): the sealed `WireMessage` hierarchy
  (`WireRequest`, `WireResponse`, `WireStateChange`,
  `WireNotification`, `WireManifestRequest`, `WireManifestResponse`,
  `WireLedgerEntry`, `WireError`), pulse-type naming
  (`SkinPulseTypes`), `ApplyOutcome` / `ApplyReceipt` / `LedgerEntry`
  wire JSON, and the `JsonSchema` subset with observed-shape derivation
  (`SchemaObserver`, `schemaForValue`, `mergeSchemas`).
- **The four cells** (`lib/src/cells/`): `buildInboundCell`
  (`Cell.ingress`), `SkinRouter` (`Cell.asyncMap`, `concurrency: 1`),
  egress (ledger-driven with a bound ledger, `Cell.observe` per exposed
  target otherwise), `buildMuxCell` (`Cell.synthesis`), and
  `buildOutboundCell` (`Cell.observe`), assembled by `SkinMembrane.open`
  with a `request`/response correlation API.
- **Receipt provenance**: the router packages `WireRequest` into
  `ApplyCommand` and hands it to `target.apply` — never its own apply —
  so every wire receipt stays attributable to the domain cell. Egress
  state changes are paired with the ledger entry's own receipt (or
  `pendingReceipt` without one) — a receipt is never fabricated and
  never borrowed from an earlier change.
- **Two gates**: exposure (binding lookup + optional `SkinWhitelist`,
  `unknown_tool` with no receipt) and the domain's own
  `TestCell.action`. The whitelist covers egress, observe, and the
  ledger endpoints, not just applies.
- **Security**: per-request provenance (`PulseContext` from the
  `ContextBridge`) flows through `SkinMembrane.request`; the default
  inbound context is least privilege, never `Context.system`.
- **Binding table + manifest**: `SkinBinding`, `SkinBindingTable`
  (sealed at membrane open; duplicates throw), `SkinWhitelist`, and
  `SkinManifest.describe(graph, bindings)` for MCP `tools/list` and
  REST discovery.
- **Stateless cursors**: opt-in `strictCursor` bindings require
  `WireRequest.lastSeenSeq` **exactly equal** to the global ledger head
  — missing → `cursor_required` (428), behind or ahead → `conflict` —
  before the target apply runs.
- **Adapters**: the `McpAdapter` seam + neutral `McpToolSpec` /
  `McpResourceSpec` translation, and the hardened `RestAdapter`
  (exported from `cell_skin_rest.dart` — no `dart:io` in the main
  barrel): `/skin/apply`, `/skin/manifest`, `/skin/observe/:cellId`
  SSE, `/skin/ledger` SSE (backlog replay + `id:` events),
  `/skin/verify`, `/health`. Closed by default: required auth, method
  enforcement, JSON-only POSTs, Host/Origin validation, bounded
  bodies. SSE runs over a detached raw socket (real streaming with
  flush, keep-alive pings, silent-disconnect detection, slow-client
  drop); positional arguments accept a plain JSON array or the
  index-keyed object.
- **Correlation**: ids are server-assigned (`clientCorrelationId` is
  an echo-only field) and the router dedupes by client id — a timed-out
  retry replays the stored outcome (rebuilt with the retry's ids)
  instead of double-applying.
- **Clients**: in-process `SkinClient` and the cell-shaped
  `RemoteCellClient`.
- **Security**: the `SkinAuth` SPI (`SkinPrincipal`, `SkinCredentials`,
  `AllowAllSkinAuth`) and `ContextBridge` (remote identity → framework
  `Context`), wired through per-request `PulseContext` provenance.
- **Consistency**: a binding whose target is not the graph's registered
  cell is rejected at `SkinMembrane.open`; `request()` on a
  `WireNotification` throws immediately; `WireMessage.fromJson` throws
  `FormatException` (never a raw `TypeError`) on malformed input.
- **Tests** (50): wire round-trips (incl. outcome survival and
  malformed-input contract), schema translation (incl. all-element
  array merging), binding table, receipt provenance, ledger-driven
  egress, exposure gate, cursors (missing/ahead/stale/fresh),
  idempotency (incl. timeout-then-retry), non-JSON result omission,
  concurrent requests, gate admission, provenance, REST conformance
  over real sockets (auth/method/content-type/origin posture,
  positional arrays), SSE live frames + disconnect cleanup, close
  semantics, and the in-process acceptance test — membrane-driven
  applies replay into a fresh graph with zero divergences.
- **Live demo** (`example/`): Echo Home — a Flutter smart-home app in
  which a scripted agent drives the real membrane, a real `TestCell`
  door gate, a real `Cell.txApply` batch, and the real `ReplayEngine`
  (0 divergences). Every piece of UI state is a cell, bound through
  `cell_flutter` (`CellBuilder`, `CellValueBuilder`, `CellListener`,
  `CellListView` — including the new `reverse` orientation — and the
  DevTools registry for Developer Mode), with recording-mode frame
  markers for GIF production and the scenario/drift tests.
- **Documentation**: `ARCHITECTURE-Skin.md` (membrane design),
  `FEATURES-Skin.md` (feature catalog), `DEMO_GUIDE.md` (Echo Home
  walkthrough), a generated `TEST_VERIFICATION.md`
  (`tool/generate_test_verification.py`), and `dart doc` topics for
  all four (`doc/api`). Public API doc comments follow the Cell
  framework standard (`### When to use`, `### How it works`,
  `### Non-obvious`, `### See also`).
- **HowTo guides** (`guide/`): Start, Bindings, Whitelist, Membrane,
  WireMessages, Egress, Cursors, Idempotency, RestAdapter, McpSeam,
  Auth, Testing — the `cell_flutter`-style per-topic HowTos, **all
  integrated as dartdoc topics** (each guide is a `Topics` category
  with annotated API elements; `HowTo-Start.md` is the `Getting
  Started` topic).
- **AI-facing docs + skill**: `### AI Agent Guide` blocks on the key
  APIs (convention: `CONTRIBUTING-AI-DOC.md`); the generated decision
  matrix `lib/doc/api_chooser.dart` and the official package skill
  `skills/cell-skin/` (with `references/api_chooser.md`), regenerated
  by `dart run tool/generate_api_chooser.dart` and guarded by
  `test/api_chooser_up_to_date_test.dart`.
