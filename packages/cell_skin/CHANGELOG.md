# Changelog

## Cell Skin (1.0.0) - Stable wire

The wire is version `"1"` — every encoded message and SSE `data` line
carries `wire: "1"`, and the frozen error table lives in
`test/goldens/wire/`. The Dart surface in FEATURES-Skin.md is stable
except the MCP seam and the file-store line format. `SECURITY.md` is
the threat page.

- **Added:** a non-null `SkinAuthorizer` now filters the read routes
  through `SkinMembrane.mayRead` — manifest omits fully denied cells,
  observe answers 403 `forbidden` (hidden cells stay 404
  `unknown_tool`), and ledger skips denied rows. Read checks are not
  cached. `test/security_pass_test.dart` locks every security row.
- **Changed:** an oversized request body is drained before the 413
  `body_too_large` is answered, so the status always reaches the
  client.

## 1.0.0-rc.1 - Frozen surface

The freeze release: no behavior changes.

- **Added:** FEATURES-Skin.md §2 catalog — the human stability table
  plus two machine lists (`<!-- public-api:stable -->` and
  `<!-- public-api:experimental -->`) covering every exported name of
  the three barrels; §3 now names the golden error set.
- **Added:** every `### AI Agent Guide` block pins
  `cell_skin: 1.0.0` and declares `**Stability:**`; new blocks for
  `skinWireVersion`, `FileIdempotencyStore`, `SkinRequestSample`,
  `SkinRequestLog`, and the previously unguided wire types.
- **Added:** `test/public_api_test.dart` (analyzer namespaces,
  guide-block pins, stability, golden codes), the chooser pin
  assertion, and `test/error_table_produced_test.dart` (one producer
  per golden error code).
- **Added:** `tool/check_coverage.dart` — line coverage of `lib/src`
  must stay at or above 90%.
- **Changed:** the migration guide gains the three 0.5+ sentences and
  the rc rule: a commit that changes `test/goldens/wire/` also changes
  `guide/HowTo-Migrate-0.2.md`; after the rc tag, such a commit means
  the release is not 1.0.

## 0.5.0 - Operable

- **Added:** `SkinMembrane.open(maxQueued:)` — `null` is the v0.2
  unlimited default; over the cap `request()` returns `queue_full` (HTTP
  429) immediately. The function is not called, nothing is cached,
  `lastSeq` does not move, and the in-flight apply still finishes.
- **Added:** `SkinRequestSample` and `onRequestLog` on `RestAdapter.bind`
  — the metrics hook, one sample per finished request: bare route,
  server correlation id, status, stable error code, duration,
  `ledgerSeq`. No headers, no body, no token.
- **Added:** `benchmark/run.dart` with three regression budgets
  (apply round-trip, schema rejection, 32 ledger SSE clients); the
  first run records the ceilings, later runs fail past
  ceiling * allowance (1.0).

## 0.4.0 - Restart survivable

- **Added:** `FileIdempotencyStore` in a new
  `package:cell_skin/cell_skin_io.dart` barrel (the main barrel stays
  `dart:io`-free). One canonical-JSON line per record in
  `directory/log`, rewritten under an exclusive lock on
  `directory/lock`, with a two-minute in-flight lease. A crash after
  the domain commit and before `complete` can still double-apply;
  `complete` is what makes the retry safe.
- **Added:** strict-receipt failures persist `errorCode`/`errorMessage`
  on the file line, so the restart replay is the same
  `transport_error`, never a fake success.
- **Added:** `GET /ready` — authenticated readiness (membrane open,
  ledger verifies, file store present) beside the unchanged
  unauthenticated `/health`. Not ready is 503
  `{ok: false, code: "not_ready"}` with no exception text.
- **Added:** `SkinMembrane.isClosed` and `SkinMembrane.idempotency`
  getters for the readiness probe.

## 0.3.0 - Wire version 1

- **Added:** every encoded `WireMessage` body and every SSE `data` line
  carries `wire: "1"`. A missing field decodes as version 1; any other
  value is `bad_json`.
- **Added:** `skinErrorStatus` — the shared code-to-HTTP table, the
  twin of `test/goldens/wire/errors/`. `queue_full` (429) is reserved
  in the table; nothing emits it yet.
- **Added:** `test/goldens/wire/` — canonical JSON per message subtype
  and per error code. `test/wire_golden_test.dart` locks the contract;
  a key the golden does not have fails CI.
- **Added:** optional `correlationId` on
  `WireManifestRequest`/`WireManifestResponse`, omitted when null.

## 0.2.0 - The Hardened Membrane

- **Fixed:** correlation ids are minted by one isolate-wide sequence
  with a random suffix; two clients or adapters on one membrane can no
  longer mint the same id in the same microsecond, and an empty
  correlation id is replaced on emission instead of shared.
- **Fixed:** `POST /skin/apply` on a ledgered membrane appends, verifies,
  and replays. The HTTP zone never installed `LedgerScope`.
- **Changed:** with a ledger bound, every membrane `apply` is recorded.
  An already-active scope on that same ledger is reused.
  `graph.run(() => client.apply(...))` still appends one row.
- **Added:** `SkinBinding.state` and `SkinBinding.command`. For a
  ledgered `state` apply, the response receipt id is the ledger row's
  receipt id, the wire receipt carries the row's `ledgerSeq` and
  `pulseDigest` under the binding's function name, and the JSON result
  is the pulse payload. A `command` binding reports its inner rows as
  `ledgerSeqs`.
- **Changed:** `SkinMembrane.open(strictReceipts: true)` is the default.
  A ledgered binding that appends a receipt other than the apply receipt
  (e.g. one that still calls `update()`) is answered with
  `transport_error` instead of silently splitting the ids. Strict-mode
  errors are cached as a terminal failure record — the row is already
  committed, so a retry echoes the error and never applies again.
- **Added:** `SkinCall` and `SkinPulses`. The router runs every target
  apply inside a `SkinCall` zone, so a domain `TestCell.action` reads
  `SkinCall.current` (principal and request context) before the body
  runs — including after an `await`. Ledgered pulse-returning applies
  store `skin:<principal id>` as the actor on the row.
- **Changed:** `RestAdapter` puts a JSON principal snapshot on the
  request `PulseContext` (`others['skin.principal']`). `SystemContextBridge`
  still does not skip `TestCell`.
- **Fixed:** a reused client id with a different body is
  `idempotency_conflict` (409) and does not apply. Domain rejections and
  cursor conflicts are not cached.
- **Added:** `IdempotencyStore`. The default store is in-memory, 1024
  completed records, 24 hours. In-flight keys are not evicted.
- **Fixed:** explicit `argumentSchema` keywords are enforced (`required`,
  `enum`, `additionalProperties`, nested objects, `null`).
- **Changed:** a positional call against a non-index schema requires
  `positionalNames`. Bindings that omit it now get `bad_arguments`.
- **Fixed:** `/skin/ledger` subscribes before reading the store, so a
  row committed during the snapshot is not lost. `Last-Event-ID`
  resumes without a query.
- **Changed:** SSE responses are `Transfer-Encoding: chunked`.
  `?since=` stays inclusive. The header is exclusive.
- **Fixed:** binding a non-loopback address without `allowedHosts`
  throws. `Host` is required on every route except `/health`. CORS
  preflight is answered before auth, and a listed origin is echoed.
- **Changed:** verify failure is `{"ok": false, "code": "verify_failed"}`.
  The exception is passed to `onServerError` and is not written to the
  response.
- **Fixed:** `mcpToolSpecs` accepts the dotted cell ids the rest of the
  skin uses.
- **Changed:** `McpToolSpec.name` is the escaped MCP name. `dottedName`
  is `<cellId>.<functionName>`. A collision or a name longer than 64
  characters throws at catalogue build.
- **Fixed:** a request that is still queued when its deadline passes
  does not call `apply`.
- **Added:** `SkinMembrane.open(maxQueueWait:)`, default 30 seconds.
  `Duration.zero` disables it. REST passes its request timeout as the
  same deadline.
- **Added:** `SkinAuthorizer`. Default `null`. `false` is `forbidden`
  and does not call the binding.
- **Added:** `SkinWhitelist(..., unlisted: SkinUnlisted.expose)`. The
  default `hide` does not warn about bindings it intentionally omits.
- **Fixed:** the demo and fixture `setColor` binding targets
  `home.living.light.color`.
- **Official package skill:** `skills/cell-skin/SKILL.md` carries the
  factory-picking workflow, the hard rules, and the BRD elevator
  matrix. Installed with `dart run skills@ get cell_skin`.
- **Skill matrix:** `tool/generate_api_chooser.dart` emits
  `skills/cell-skin/references/api_chooser.md` as well as
  `lib/doc/api_chooser.dart`. `test/api_chooser_up_to_date_test.dart`
  asserts both outputs fresh, and asserts the skill still names the
  install command and the elevator matrix.
- **Fixed:** a strict-receipt violation is post-commit: the retry now
  replays the same `transport_error` instead of applying the command a
  second time.
- **Changed:** a `state` or `command` binding called with non-empty
  named arguments is `bad_arguments`; `named: {}` is treated as absent.
- **Fixed:** `SkinMembrane.close` gates the router, so a queued request
  no longer applies after the close.
- **Changed:** expired idempotency records are swept before eviction;
  replay is documented as at-least-once past the TTL or the cap.
- **Changed:** `SkinClient.apply` and `RemoteCellClient.call` throw
  `outcome_json_only` when a durable-store replay has no live outcome,
  instead of returning a `null` that looks like `pendingReceipt`.
- **Fixed:** a malformed principal snapshot with non-string claim keys
  no longer throws on the router; the keys are filtered.
- **Changed:** REST 405 responses carry the `Allow` header.

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
