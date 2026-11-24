# cell_skin — Feature Catalog

## Table of Contents

1. [What cell_skin Is](#1-what-cell_skin-is)
2. [Status and Boundaries](#2-status-and-boundaries)
3. [Wire Vocabulary](#3-wire-vocabulary)
4. [Binding Table and Whitelist](#4-binding-table-and-whitelist)
5. [The Four-Cell Membrane](#5-the-four-cell-membrane)
6. [Receipt Provenance and Egress](#6-receipt-provenance-and-egress)
7. [Stateless Cursors](#7-stateless-cursors)
8. [Idempotency and Correlation](#8-idempotency-and-correlation)
9. [Manifest and Schemas](#9-manifest-and-schemas)
10. [REST Adapter](#10-rest-adapter)
11. [MCP Seam](#11-mcp-seam)
12. [Clients](#12-clients)
13. [Security SPI](#13-security-spi)
14. [Consistency and Lifecycle](#14-consistency-and-lifecycle)

## 1. What cell_skin Is

A transport membrane over a [Cell](https://pub.dev/packages/cell) graph:
a sealed wire vocabulary, a four-cell pipeline, a binding table, a
closed-by-default REST adapter, an MCP seam, and two Dart clients. The
graph keeps its own gates, ledger, and replay; the skin only translates
and enforces exposure.

## 2. Status and Boundaries

| | |
| :--- | :--- |
| **In scope** | Commands over REST/MCP/Dart; state observation; audit streaming; exposure policy; remote identity. |
| **Out of scope** | The decision layer (`cell_flow`), the books (`cell_tissue`), an MCP transport (the `McpAdapter` is a seam for SDKs like `dart_mcp`), and inventing receipts the graph never produced. |
| **Version** | 1.0.0-rc.1 — the wire is frozen, and the Dart surface below is frozen for the rc. |

| Surface | Stability |
| :--- | :--- |
| Wire messages, error table, SSE cursors, MCP escape, fingerprint | `stable` |
| `SkinMembrane`, `SkinBinding`, `SkinClient`, `RestAdapter`, `SkinAuthorizer`, `SkinWhitelist` | `stable` |
| `IdempotencyStore`, `MemoryIdempotencyStore` | `stable` |
| `FileIdempotencyStore` | `stable` — it is an `IdempotencyStore` |
| `FileIdempotencyStore` line format | `experimental` — lines may gain fields |
| `McpAdapter` and the rest of that library | `experimental` — a seam, not a transport |
| `/ready`, `maxQueued`, `onRequestLog`, `SkinRequestSample` | `stable` |

The line format is not a symbol. The class goes in the stable list. The
experimental list is every public symbol whose declaring library is
`mcp_adapter.dart`. One name per line, sorted; every exported name from
the three barrels is in exactly one list.

<!-- public-api:stable -->
```text
AllowAllSkinAuth
BadArgumentsException
ContextBridge
DescribeContextBridge
FileIdempotencyStore
IdempotencyClaim
IdempotencyOwned
IdempotencyRecord
IdempotencyReplay
IdempotencyStore
IdempotencyWait
JsonSchema
MemoryIdempotencyStore
RemoteCellClient
RestAdapter
SchemaObserver
SkinAuth
SkinAuthorizer
SkinBinding
SkinBindingTable
SkinCall
SkinCellDescriptor
SkinClient
SkinCredentials
SkinError
SkinFunctionDescriptor
SkinManifest
SkinMembrane
SkinPrincipal
SkinPulseTypes
SkinPulses
SkinRequestLog
SkinRequestSample
SkinRouter
SkinUnlisted
SkinWhitelist
SystemContextBridge
WireError
WireLedgerEntry
WireManifestRequest
WireManifestResponse
WireMessage
WireNotification
WireOutcome
WirePulseGate
WireReceipt
WireRequest
WireResponse
WireStateChange
buildEgressCells
buildInboundCell
buildMuxCell
buildOutboundCell
idempotencyFingerprint
idempotencyStoreKey
kDefaultMaxBodyBytes
mergeSchemas
nextCorrelationId
principalFrom
requireSkinWireVersion
requiredForMissingObject
schemaForValue
skinErrorStatus
skinPrincipalSnapshot
skinPulseContext
skinWireVersion
validateBindingArguments
validateJsonSchema
wireLedgerEntryCellId
wireLedgerEntryFromJson
wireLedgerEntryJson
wireOutcomeFromJson
wireOutcomeJson
wireOutcomeKind
wireReceiptJson
wireStateChangeForEntry
withWire
```
<!-- public-api:experimental -->
```text
McpAdapter
McpResourceSpec
McpToolCall
McpToolSpec
mcpEscapedToolName
mcpResourceSpecs
mcpToolSpecs
mcpUnknownToolResult
resolveMcpToolCall
```

## 3. Wire Vocabulary

One sealed hierarchy, one intent per variant:

* **`WireRequest`** — a command. `correlationId` is server-assigned;
  `clientCorrelationId` is the caller's echo-only id. Positional
  arguments accept a JSON array or an index-keyed object; named
  arguments are validated identifiers.
* **`WireResponse`** — the target's real `ApplyOutcome`, or
  `pendingReceipt` for an accepted pulse whose entry has not landed.
  Decoded responses carry `outcomeJson` (`WireOutcome`) so the result
  survives JSON.
* **`WireStateChange`** — a state observation with an optional receipt.
  No correlation id: egress is not a reply.
* **`WireError`** — pre-apply rejections with stable codes:
  `unknown_tool`, `bad_arguments`, `cursor_required`, `conflict`,
  `idempotency_conflict`, `forbidden`, `queue_timeout`,
  `outcome_unknown`, `queue_full`, `verify_failed`,
  `host_not_allowed`, `origin_not_allowed`, `transport_error`.
* **`WireNotification`** — fire-and-forget; `request()` on one throws
  `ArgumentError`.
* **`WireManifestRequest`/`WireManifestResponse`** — tool catalogue.
* **`WireLedgerEntry`** — one audit entry via `LedgerEntry.toJson`.

Sanitising codecs (`WireOutcome`, `wireReceiptJson`, `JsonSchema`)
guarantee the wire is always JSON-encodable: unencodable results,
reasons, and arguments become labelled placeholders with
`resultOmitted`/`reasonOmitted`/`argumentsOmitted` flags. `fromJson`
throws `FormatException` on malformed input, never a raw `TypeError`.

## 4. Binding Table and Whitelist

* **`SkinBinding`** binds `(cellId, functionName)` to a graph cell and
  its closure — with an optional description, declared argument schema,
  strict cursor, and compensation (which receives the same wire
  arguments as the command).
* **`SkinBindingTable`** rejects duplicate registrations and **seals at
  `SkinMembrane.open`** — the manifest, egress set, and wire can never
  diverge.
* **`SkinWhitelist`** is the declarative exposure policy. It covers
  applies, egress, `/skin/observe/:cellId`, and `/skin/ledger`.
  Entries with no matching binding produce startup policy warnings.
* A binding's target must be `identical` to the graph's registered
  cell — anything else throws at `open()`.

## 5. The Four-Cell Membrane

`SkinMembrane.open` assembles `Cell.ingress` → `Cell.asyncMap`
(`concurrency: 1`) → `target.apply` → egress → mux → outbound over a
graph, an optional ledger, and a transport writer. The API surface:

* `membrane.request(message, {type, context, timeout})` — emits one
  wire message and awaits its correlated `WireResponse`/`WireError`
  (or a `WireManifestResponse`).
* `membrane.responses` — the broadcast of everything that survives the
  mux (responses, state changes, ledger entries).
* `membrane.manifest` — the live tool catalogue.
* `membrane.isExposed(cellId)` — binding + whitelist policy combined.
* `membrane.close()` — idempotent; stops everything and fails pending
  requests with `SkinError('closed')`.

Inbound pulses are governed (`Pulse.governed`) with per-request
`PulseContext`; the default inbound context is least privilege
(`Context.describe('skin:untrusted')`).

## 6. Receipt Provenance and Egress

* The router packages `WireRequest` into `ApplyCommand` and hands it to
  `target.apply` — never its own apply — so every receipt stays
  attributable to the domain cell.
* **Ledgered membranes** drive egress from `Ledger.tail`: the entry's
  own receipt pairs with the entry's own pulse payload (from the
  entry's canonical stored JSON).
* **Unledgered membranes** observe targets with `pendingReceipt: true`
  always — a receipt is never fabricated, never borrowed from an
  earlier change.

## 7. Stateless Cursors

Opt-in `strictCursor` bindings require `lastSeenSeq == ledger.head`
**exactly**:

| Condition | Result |
| :--- | :--- |
| cursor missing | `cursor_required` (428 on REST) |
| cursor behind head | `conflict` (409) — stale caller state |
| cursor ahead of head | `conflict` (409) — cannot have seen current state |
| cursor == head | proceeds |

The cursor is the global ledger head by design (stateless server); the
check-then-apply window is documented and intra-skin races are removed
by the router's `concurrency: 1`.

## 8. Idempotency and Correlation

* Server-assigned `correlationId`; the caller's `clientCorrelationId`
  is echoed, never matched by other waiters.
* The router's bounded store is keyed by
  `clientCorrelationId ?? correlationId`. A duplicate key replays the
  **stored outcome re-wrapped with the current request's ids** — so a
  retry after a timeout returns the original result without
  double-applying.
* `RemoteCellClient` ids include a monotonically increasing counter;
  `SkinClient` ids likewise.

## 9. Manifest and Schemas

`SkinManifest.describe` builds the tool catalogue from the binding
table and optional whitelist:

* Per-function descriptions (`function.description` → cell
  description), with cell ids and function names.
* **Argument schemas**: explicit binding hint → observed current cell
  value (`schemaForValue`) → permissive. Observation widens correctly:
  type-only inference (no single-value `enum`/`minimum == maximum`),
  `required` is the intersection across objects, absent bounds mean
  unconstrained, `int` ∪ `double` → `number`, and array items merge
  every element's schema. An **explicit** schema is a gate (`required`,
  `enum`, closed objects, typed `null`, `positionalNames`); an observed
  schema is a hint for `tools/list`, never enforced.
* `JsonSchema` JSON round-trips are lenient on the way in (array
  `type`, schema-object `additionalProperties`) and never let stored
  extras re-spread over modelled keys.

## 10. REST Adapter

`RestAdapter` lives in `cell_skin_rest.dart` (the main barrel stays
`dart:io`-free). `bind()` is **closed by default** — `auth` is
required; anonymous access is the explicit `AllowAllSkinAuth`.

| Route | Behaviour |
| :--- | :--- |
| `GET /health` | Liveness before auth. |
| `POST /skin/apply` | Command → sanitised outcome; error map: `unknown_tool` 404, `conflict` 409, `bad_arguments` 422, `cursor_required` 428, timeout 504 `outcome_unknown`. |
| `GET /skin/manifest` | Tool catalogue. |
| `GET /skin/observe/:cellId` | SSE state changes; 404 for unexposed cells. |
| `GET /skin/ledger?since=N` | SSE audit: backlog replay from the store, then the live tail, `id:` events, exposure filtering. |
| `POST /skin/verify` | Structured verification; tamper failure → `{ok: false, code: "verify_failed"}` — the exception goes to `onServerError`, never into the body. |

Transport hardening: `Host` loopback check, `Origin` rejection unless
listed, method enforcement per route, JSON-only capped bodies, 401 with
`WWW-Authenticate`, case-insensitive `Bearer`, per-request provenance
from the `ContextBridge`. SSE runs over a detached raw socket with
flush, keep-alive pings, silent-disconnect detection
(`activeSubscriptions` returns to zero), and slow-client drop.

## 11. MCP Seam

`mcpToolSpecs(manifest)` → neutral `McpToolSpec` /
`McpResourceSpec` values: `name` is the escaped MCP wire name (unsafe
characters become `_`, at most 64 characters, registered once),
`dottedName` is the raw `<cellId>.<functionName>`,
`resolveMcpToolCall` accepts both forms, collisions throw at catalogue
build, and an unknown name returns the `unknown_tool` tool result.
`cell_skin` deliberately does not speak the MCP transport itself.

## 12. Clients

* **`SkinClient`** — in-process: `apply(...)` (returns the outcome or
  `null` for `pendingReceipt`), `observe(...)` filtered to
  `WireStateChange`, `manifest()`, `ledgerEntries()`.
* **`RemoteCellClient`** — a cell-shaped facade over a remote membrane
  (counter-based correlation ids, private constructor + factory).
* **`SkinError`** — one error type for the whole package.

## 13. Security SPI

* **`SkinAuth`** — `authenticate(SkinCredentials)` →
  `SkinPrincipal?`; credentials carry the token plus transport
  metadata (peer, host, user agent).
* **`AllowAllSkinAuth`** — the explicit anonymous opt-in.
* **`ContextBridge`** — remote identity → framework `Context`;
  `DescribeContextBridge` (default), `SystemContextBridge` (the loud
  opt-in to system authority).
* Per-request `PulseContext(baseContext: bridge.resolve(principal),
  actor: 'skin:<id>', reason: ..., others: {'skin.principal': {...}})`.
  The router installs a `SkinCall` zone around the apply — the domain's
  `TestCell` gates read `SkinCall.current`, not the wire pulse — and
  stamped pulse-returning applies (`SkinBinding.state`,
  `SkinPulses.payload`) store the actor on the ledger row.

## 14. Consistency and Lifecycle

* Bindings seal at `open()`; egress/manifest/wire cannot diverge.
* Binding targets must be the graph's registered cells.
* `close()` is idempotent and total: no further pulses, no leaked
  observers, pending requests fail fast with `SkinError('closed')`.
* `WireMessage.fromJson` throws `FormatException` on malformed input.

See [ARCHITECTURE-Skin.md](ARCHITECTURE-Skin.md) for the design rationale,
[TEST_VERIFICATION.md](TEST_VERIFICATION.md) for the generated test
report, and [DEMO_GUIDE.md](DEMO_GUIDE.md) for the Echo Home demo.
