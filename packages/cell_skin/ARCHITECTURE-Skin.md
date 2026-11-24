# cell_skin — Architecture

## 1. The membrane idea

`cell_skin` puts a **membrane** between a [Cell](https://pub.dev/packages/cell)
graph and remote consumers — MCP hosts, REST clients, and Dart clients —
without touching the graph itself. The graph keeps its own gates, ledger,
and replay; the skin only translates between the graph's pulse world and a
small, sealed wire vocabulary.

Two rules drive every design decision:

1. **Never invent a receipt.** The skin may forward the domain's receipts,
   mark one as pending, or withhold one. It never synthesises an
   `ApplyAccepted` that the graph did not produce.
2. **Never forge authority.** A remote caller's identity travels as a
   `PulseContext` that the domain's own `TestCell` gates can see; the
   default is least privilege, never `Context.system`.

```text
 MCP host ──┐                              ┌── REST (cell_skin_rest.dart)
 Dart client┘   wire: Pulse<WireMessage>   │
        ───────►  ┌────────────────────┐ ◄─┘
                  │     SkinMembrane   │
                  │  four Cells + fan-in│
                  └────────┬───────────┘
                           │ target.apply (the plug)
                  ┌────────▼───────────┐
                  │     CellGraph      │  (unchanged)
                  │  TestCell gates    │
                  │  Ledger · Replay   │
                  └────────────────────┘
```

## 2. The four-cell pipeline

The membrane is exactly four Cells composed from framework primitives
(`Cell.ingress`, `Cell.asyncMap`, `Cell.observe`, `Cell.synthesis`), plus
their supporting fan-in:

```text
Cell.ingress → Cell.asyncMap → target.apply → Cell.observe → Cell.observe
(inbound)      (router)          (the plug)     (egress)        (outbound)
```

| Cell | Primitive | Job |
| :--- | :--- | :--- |
| 1 — inbound | `Cell.ingress` | Accept transport pulses; the only logic is the wire-pulse integrity gate (`WirePulseGate`). |
| 2 — router | `Cell.asyncMap`, `concurrency: 1` | Look up the binding, validate the argument schema, check the stateless cursor, call `target.apply` inside the graph's ledger scope, package the **target's real receipt**. |
| 3 — egress | ledger tail, or `Cell.observe` per target | Emit `skin.egress.<cellId>` **state changes** — never replies. |
| fan-in — mux | `Cell.synthesis` | Merge router responses, egress observations, and the ledger tail (`skin.ledger.entry`). |
| 4 — outbound | `Cell.observe` | Write surviving pulses to the transport and the `responses` broadcast. |

The only non-Cell logic between graph and wire is the binding table — a
closure map that cannot serialise and therefore stays where the closures
live. An explicit `argumentSchema` is enforced before apply
(`bad_arguments`, HTTP 422); observed schemas are hints for `tools/list`
and are never enforced.

## 3. Wire taxonomy

`WireMessage` is a sealed hierarchy with exactly one variant per intent:

| Variant | Meaning |
| :--- | :--- |
| `WireRequest` | A command. `correlationId` is **server-assigned**; `clientCorrelationId` is the caller's echo-only id. |
| `WireResponse` | The target's real `ApplyOutcome` (or a `pendingReceipt` flag for an accepted pulse whose entry has not landed). |
| `WireStateChange` | A state observation (`cellId`, JSON-safe payload, optional receipt). **No correlation id** — egress is not a reply and can never complete a pending `request()`. |
| `WireError` | Pre-apply rejections (`unknown_tool`, `bad_arguments`, `cursor_required`, `conflict`, `transport_error`) — an error with no receipt must not masquerade as a response. |
| `WireNotification` | Fire-and-forget; the router suppresses it. |
| `WireManifestRequest`/`WireManifestResponse` | Tool catalogue. |
| `WireLedgerEntry` | One audit entry, encoded by `LedgerEntry.toJson` — the framework's own codec, never a fork. |

Every encoded message carries `wire: "1"` (see
`HowTo-WireStability.md`); a missing field decodes as version 1.

The pulse codec is the framework's own `PulseCodec`; `WireOutcome`,
`wireReceiptJson`, and the `JsonSchema` subset are sanitising translators:
unencodable values become labelled placeholders (`resultOmitted`,
`reasonOmitted`, `argumentsOmitted`) instead of a post-apply 500.

## 4. Receipt provenance

The invariant that shaped the egress design: **every receipt on the wire
belongs to the change it accompanies.**

* **Apply path** — the router hands a `WireRequest` to
  `binding.target.apply` and packages *that call's* `ApplyOutcome`.
  The router never performs its own apply, so receipts stay attributable
  to the domain cell.
* **One receipt (ledgered state changes)** — the ledgered contract is
  `SkinBinding.state`: the binding wraps the user function's next value
  in a `Pulse` and routes it through the target receptor, so the only
  row is the one `Cell.apply` records from that pulse. The response
  receipt id and the row's receipt id are the same object id, and the
  wire receipt carries the row's `ledgerSeq`/`pulseDigest` (copied from
  the store's receipt, whose `function` label is then restored to the
  binding name — `Function.toString()` never reaches the wire). A
  `SkinBinding.command` reports its inner rows as `ledgerSeqs` and never
  pretends its outer receipt is a row. The live `ApplyReceipt` keeps
  `ledgerSeq == null`; the framework back-fills the store's copy.
* **Strict receipts** — `SkinMembrane.open(strictReceipts: true)` is the
  default (ignored without a ledger). A `state` binding must write
  exactly one row carrying the apply receipt; a `raw` binding may write
  zero rows but every row must carry it. A binding that still calls
  `update()` writes a synthetic `_emit` row and the router answers
  `transport_error` — it never swaps the synthetic receipt in to hide
  the bug.
* **Ledger scope** — with a bound ledger, the router enters the graph's
  `LedgerScope` around the target apply (`graph.run`) **only when no
  scope is already active**. That is what makes `POST /skin/apply`
  ledgered even though the HTTP zone never entered the scope. The
  four-row rule:

  | Membrane ledger | `LedgerScope.current` | Action |
  | :--- | :--- | :--- |
  | null | anything | `target.apply` only — unledgered membranes stay unledgered. |
  | non-null | null | `graph.run(() => target.apply)` — REST, bare `SkinClient.apply`. |
  | non-null | same ledger | `target.apply` only — the caller already did `graph.run`. |
  | non-null | different ledger | `StateError` → `transport_error`; no second append. |

  `graph.run` drains queued appends before it returns, so the row is
  committed before the response is encoded. `graph.run` around several
  in-process applies is still the right way to put them in one scope;
  the router will not open a second one.
* **Egress path (ledgered)** — driven by `Ledger.tail` itself. Each
  entry carries its own receipt and its own pulse payload, so
  `WireStateChange` pairs the entry's receipt with the entry's payload.
  The receipt is taken from the entry's canonical stored JSON — the same
  encoding the audit trail uses.
* **Egress path (unledgered)** — every observation is
  `pendingReceipt: true`. Without a ledger there is no receipt to attach;
  nothing is fabricated and nothing is borrowed from an earlier change.

## 5. The two gates, plus authorization and provenance

| Gate | Location | Rejection |
| :--- | :--- | :--- |
| Exposure | Router binding lookup (+ optional `SkinWhitelist`) | `WireError{code: 'unknown_tool'}` — no receipt produced. The whitelist also covers egress, `/skin/observe/:cellId`, and `/skin/ledger`. |
| Authorization | The application's `SkinAuthorizer` hook, after exposure and before `apply` | `WireError{code: 'forbidden'}` (HTTP 403) — the binding does not run, no receipt, not cached. `null` means allow. The same hook also filters the read routes: manifest omits a cell whose bindings are all denied, observe answers 403, and ledger skips the cell's rows (`SkinMembrane.mayRead`; not cached either). |
| Domain | The target's `TestCell.action`, inside `target.apply` | `ApplyRejected` — the framework's real denial. It still runs after the hook says `true`. |

Provenance has two real paths:

* **The live gate** — the router installs a `SkinCall` zone around the
  target apply (inside the ledger scope when it opens one).
  `TestCell.action` reads `SkinCall.current` — the principal and the
  request `PulseContext` (`actor: skin:<id>`). The request context on
  the wire pulse is **not** visible inside `TestCell.action` by itself;
  gates that do not look at the zone do not become actor-aware by magic.
* **The stored pulse** — `recordPulse` stores the pulse the binding
  returns. `SkinBinding.state` and `SkinPulses.payload` stamp it with
  the call's context, so the row's lineage carries `actor: skin:<id>`
  and a JSON principal snapshot; replay restores the value and does not
  restore the zone. `update()` rows carry no remote actor.

`SkinMembrane.request` accepts a `PulseContext` and emits through
`Pulse.governed`; the REST adapter builds it per request from
`ContextBridge.resolve(principal)`. The membrane's default inbound
context is `Context.describe('skin:untrusted')` — system authority is
an explicit opt-in (`SystemContextBridge`), and it still does not skip
the domain gate.

## 6. Correlation and idempotency

* REST assigns `correlationId` server-side; the caller's id is carried as
  `clientCorrelationId` and echoed on the response/error — matched by
  nobody except the caller.
* The router consults an `IdempotencyStore` (default: `MemoryIdempotencyStore`,
  1024 completed records, 24 hour TTL). The key is **the request actor plus**
  `clientCorrelationId ?? correlationId`; the fingerprint covers `cellId`,
  function, positional/named arguments, and `lastSeenSeq`. A duplicate
  key with the same fingerprint returns the **stored outcome re-wrapped
  with the current request's ids** — a retry after a 504 never
  double-applies, and the replay always matches the retry's waiter. A
  duplicate key with a different fingerprint is
  `WireError{code: 'idempotency_conflict'}` (HTTP 409, distinct from the
  cursor `conflict`) and never calls apply. An in-flight key makes later
  claimers wait for that attempt.

  | Exit | Store |
  | :--- | :--- |
  | `ApplyAccepted`, `ApplyStaged` | `complete` |
  | `ApplyRejected`, `unknown_tool`, `bad_arguments`, `cursor_required`, `conflict`, thrown | `abort` — never cached, so a retry after the situation changes runs. |
  | `transport_error` after rows were appended (a strict-receipt violation) | `complete` with `errorCode`/`errorMessage` — the row is committed, so a retry replays the same error and never applies again. |

  The HTTP timeout path never aborts: the mapper keeps running and
  completes. Records are process-local unless the membrane was given a
  durable `IdempotencyStore` — a replay never survives a restart without
  one, and never moves `lastSeq`. `FileIdempotencyStore`
  (`package:cell_skin/cell_skin_io.dart`) is the restart implementation
  of the same interface: one canonical-JSON line per record in
  `directory/log`, rewritten under an exclusive lock on
  `directory/lock`, with a two-minute in-flight lease. A crash after the
  domain commit and before `complete` can still double-apply; `complete`
  is what makes the retry safe.
* `SkinMembrane.request` completes only on a `WireResponse`/`WireError`
  with the request's id (or a `WireManifestResponse`); a
  `WireStateChange` can never complete it. `WireNotification` requests
  throw `ArgumentError` immediately.
* The router is still serial (`concurrency: 1`). `maxQueueWait` (default
  30 seconds; `Duration.zero` disables it) stamps a deadline on every
  request; a request that is still queued when its deadline passes is
  `queue_timeout` (HTTP 504) and does not apply. A handler timeout while
  `apply` is running is still `outcome_unknown` (HTTP 504) — the command
  keeps running and is never cancelled.
* `maxQueued` (default `null`, unlimited) caps how many accepted
  requests have not finished their dispatch — the apply in progress
  occupies a slot. Over the cap `request()` returns
  `WireError('queue_full')` immediately (HTTP 429): the function is not
  called, nothing is cached, `lastSeq` does not move, and the in-flight
  apply still finishes.

## 7. Adapters

### REST (`cell_skin_rest.dart`)

`RestAdapter.bind` is **closed by default** — `auth` is a required
parameter and anonymous access is the explicit `AllowAllSkinAuth`
opt-in. Per request it enforces:

1. `/health` before authentication; everything else after.
2. A non-loopback `bind` without `allowedHosts` throws `ArgumentError`
   (the socket is closed). Every route except `/health` requires an
   allowed `Host` (403 `host_not_allowed` otherwise) — comparison is
   case-insensitive, no port stripping, and the header is never treated
   as proof of the peer address. An `Origin` header that is not an exact
   `allowedOrigins` member is 403 `origin_not_allowed` with no CORS
   headers; a listed origin is echoed (never `*`) with `Vary: Origin`,
   and `OPTIONS` preflights are answered before auth.
3. Method checks per route; JSON-only POST bodies capped at 1 MiB.
4. Input validation returns stable 400 codes (`missing_cellId`,
   `bad_correlation_id`, `invalid_lastSeenSeq`, …) with no raw error
   text.

| Route | Behaviour |
| :--- | :--- |
| `POST /skin/apply` | Command → 200 with the sanitised outcome, 404/409/422/428/504 `WireError` map. Cursor misses are `conflict`; a reused client id with a different body is `idempotency_conflict` — both 409. Timeouts surface `outcome_unknown` (504) — retry with the same `correlationId`, which replays only in this process until the idempotency record expires, unless the membrane was given a durable `IdempotencyStore`. |
| `GET /skin/manifest` | `WireManifestResponse` with descriptions and observed schemas. |
| `GET /skin/observe/:cellId` | SSE of `skin.egress.<cellId>` state changes (ids may contain `/`, clients percent-encode); 404 for unexposed cells. `Last-Event-ID` skips changes whose `ledgerSeq` is at or below it. |
| `GET /skin/ledger[?since=N]` | SSE of audit entries: the live listener is attached first, then the backlog replays from the store, then buffered live rows are flushed once. `?since=N` is inclusive; `Last-Event-ID: N` is exclusive and only used without the query; omitted means live-only. `id:` events and exposure filtering everywhere. |
| `POST /skin/verify` | Structural verification; tamper-detected failure returns `{ok: false, code: "verify_failed"}` — the exception goes to `onServerError`, never into the body. |
| `GET /ready` | Authenticated readiness: 200 `{ok: true}` when the membrane is open, the ledger (when bound) verifies, and a configured file idempotency store still has its directory; otherwise 503 `{ok: false, code: "not_ready"}`. `/health` stays liveness: unauthenticated and host-exempt. |
| `onRequestLog` | One `SkinRequestSample` per finished request, from a `finally`: the bare route (no query), the server correlation id, the status, the stable error code, the duration, and the apply's `ledgerSeq`. No headers, no body, no token. |

SSE runs over a detached raw socket: `chunkedTransferEncoding` is
enabled before `detachSocket()` and every event is one real HTTP chunk
(size in hex, bytes, CRLF), `Socket.done` releases the subscription on
silent disconnects, a configurable keep-alive ping bounds the detection
window, and a bounded queue drops slow clients. A frame that fails to
encode is logged through `onServerError` and replaced with
`skin.error.transport` — the subscription stays up.

### MCP (`McpAdapter`)

An honest seam, not a transport: `mcpToolSpecs(manifest)` produces
neutral `McpToolSpec`/`McpResourceSpec` values. `McpToolSpec.name` is
the escaped wire name (unsafe characters become `_`, at most 64
characters) — the only name a host registers; `dottedName` is the raw
`<cellId>.<functionName>`. `resolveMcpToolCall` accepts both, a
collision throws at catalogue build, and an unknown name is the
`unknown_tool` tool result — not a JSON-RPC error.

## 8. Consistency rules

* The binding table **seals at `open()`** — the egress set, the
  manifest, and the wire can never diverge. Duplicate
  `(cellId, function)` registrations throw `StateError`.
* A binding's target must be `identical` to the graph's registered cell;
  anything else throws at `open()`.
* `strictCursor` bindings require `lastSeenSeq == ledger.head` exactly:
  missing → `cursor_required`; behind or ahead → `conflict`. The cursor
  is the **global** head — a deliberate, stateless design; the router's
  `concurrency: 1` removes intra-skin races, and the check-then-apply
  window is documented.
* `close()` is idempotent: it stops the outbound cell, every egress
  handle, the ledger tail, and the event stream, and fails all pending
  `request()` futures with `SkinError('closed')`.

## 9. Layout

```text
lib/
├── cell_skin.dart        # web-safe barrel: wire, membrane, clients, security
├── cell_skin_rest.dart   # dart:io surface: RestAdapter + auth + bridges
└── src/
    ├── wire/             # sealed WireMessage, WireOutcome, WireReceipt, JsonSchema
    ├── binding/          # SkinBinding, SkinBindingTable, SkinWhitelist
    ├── manifest/         # SkinManifest, schema observation
    ├── cells/            # the four Cells + SkinMembrane + SkinRouter
    ├── adapters/rest/    # RestAdapter
    ├── adapters/mcp/     # McpAdapter seam
    ├── client/           # SkinClient, RemoteCellClient, SkinError
    └── security/         # SkinAuth, SkinPrincipal, ContextBridge
```

The main barrel never imports `dart:io`; the REST surface lives behind
`cell_skin_rest.dart` so Flutter web consumers stay buildable.

## 10. Testing strategy

The suite is contract-first: wire round-trips, the two code-review
regression suites, cursor semantics, egress receipt pairing, REST
conformance over real sockets, SSE live-frame and disconnect cleanup,
idempotent retry, and one **in-process acceptance test** — membrane-driven
applies replay into a fresh graph with zero divergences. See
[TEST_VERIFICATION.md](TEST_VERIFICATION.md) (generated) for the full
inventory, and [DEMO_GUIDE.md](DEMO_GUIDE.md) for the living demo.
