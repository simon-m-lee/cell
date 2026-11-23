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
| 2 — router | `Cell.asyncMap`, `concurrency: 1` | Look up the binding, validate the argument schema, check the stateless cursor, call `target.apply`, package the **target's real receipt**. |
| 3 — egress | ledger tail, or `Cell.observe` per target | Emit `skin.egress.<cellId>` **state changes** — never replies. |
| fan-in — mux | `Cell.synthesis` | Merge router responses, egress observations, and the ledger tail (`skin.ledger.entry`). |
| 4 — outbound | `Cell.observe` | Write surviving pulses to the transport and the `responses` broadcast. |

The only non-Cell logic between graph and wire is the binding table — a
closure map that cannot serialise and therefore stays where the closures
live.

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
* **Egress path (ledgered)** — driven by `Ledger.tail` itself. Each
  entry carries its own receipt and its own pulse payload, so
  `WireStateChange` pairs the entry's receipt with the entry's payload.
  The receipt is taken from the entry's canonical stored JSON — the same
  encoding the audit trail uses.
* **Egress path (unledgered)** — every observation is
  `pendingReceipt: true`. Without a ledger there is no receipt to attach;
  nothing is fabricated and nothing is borrowed from an earlier change.

## 5. The two gates, plus provenance

| Gate | Location | Rejection |
| :--- | :--- | :--- |
| Exposure | Router binding lookup (+ optional `SkinWhitelist`) | `WireError{code: 'unknown_tool'}` — no receipt produced. The whitelist also covers egress, `/skin/observe/:cellId`, and `/skin/ledger`. |
| Domain | The target's `TestCell.action`, inside `target.apply` | `ApplyRejected` — the framework's real denial. |

Provenance rides on every pulse. `SkinMembrane.request` accepts a
`PulseContext` and emits through `Pulse.governed`; the REST adapter builds
it per request from `ContextBridge.resolve(principal)` with an
`actor: skin:<id>` stamp. The membrane's default inbound context is
`Context.describe('skin:untrusted')` — system authority is an explicit
opt-in (`SystemContextBridge`).

## 6. Correlation and idempotency

* REST assigns `correlationId` server-side; the caller's id is carried as
  `clientCorrelationId` and echoed on the response/error — matched by
  nobody except the caller.
* The router keeps a bounded idempotency store keyed by
  `clientCorrelationId ?? correlationId`. A duplicate key returns the
  **stored outcome re-wrapped with the current request's ids** — so a
  retry after a 504 never double-applies, and the replay always matches
  the retry's waiter.
* `SkinMembrane.request` completes only on a `WireResponse`/`WireError`
  with the request's id (or a `WireManifestResponse`); a
  `WireStateChange` can never complete it. `WireNotification` requests
  throw `ArgumentError` immediately.

## 7. Adapters

### REST (`cell_skin_rest.dart`)

`RestAdapter.bind` is **closed by default** — `auth` is a required
parameter and anonymous access is the explicit `AllowAllSkinAuth`
opt-in. Per request it enforces:

1. `/health` before authentication; everything else after.
2. `Host` must be a loopback name (browser DNS-rebinding defence); any
   `Origin` header is rejected unless explicitly listed.
3. Method checks per route; JSON-only POST bodies capped at 1 MiB.
4. Input validation returns stable 400 codes (`missing_cellId`,
   `bad_correlation_id`, `invalid_lastSeenSeq`, …) with no raw error
   text.

| Route | Behaviour |
| :--- | :--- |
| `POST /skin/apply` | Command → 200 with the sanitised outcome, 404/409/422/428/504 `WireError` map. Timeouts surface `outcome_unknown` (504) — retry with the same `correlationId`. |
| `GET /skin/manifest` | `WireManifestResponse` with descriptions and observed schemas. |
| `GET /skin/observe/:cellId` | SSE of `skin.egress.<cellId>` state changes; 404 for unexposed cells. |
| `GET /skin/ledger[?since=N]` | SSE of audit entries: backlog replay from the store, then the live tail, with `id:` events and exposure filtering. |
| `POST /skin/verify` | Structural verification; tamper-detected failure returns a structured `{ok: false, message}`. |

SSE runs over a detached raw socket: `chunkedTransferEncoding` is
disabled before `detachSocket()`, frames are written with `flush`,
`Socket.done` releases the subscription on silent disconnects, a
configurable keep-alive ping bounds the detection window, and a bounded
queue drops slow clients.

### MCP (`McpAdapter`)

An honest seam, not a transport: `mcpToolSpecs(manifest)` produces
neutral `McpToolSpec`/`McpResourceSpec` values with dot-free, collision-
checked tool names and per-function descriptions, ready for any MCP SDK.

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
