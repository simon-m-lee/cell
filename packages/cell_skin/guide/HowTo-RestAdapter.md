# HowTo-RestAdapter

`RestAdapter` is the HTTP surface on top of the membrane — commands,
discovery, SSE observation, audit streaming, verification, and health.
It lives in `package:cell_skin/cell_skin_rest.dart` (the main barrel
stays `dart:io`-free for Flutter web).

## When to use

- A requirement says "REST endpoint for the graph", "SSE stream of
  changes", or "curl-able manifest".
- Cross-process clients (browsers, other services, curl).

## When not to use

- In-process calls — use `SkinClient`.
- Speaking MCP — `RestAdapter` is not an MCP transport; see
  `HowTo-McpSeam.md`.

## Bind

```dart
import 'package:cell_skin/cell_skin_rest.dart';

final adapter = await RestAdapter.bind(
  membrane: membrane,
  auth: const AllowAllSkinAuth(), // anonymous is an explicit opt-in
);
print(adapter.port); // the ephemeral port
```

`auth` is **required** — there is no unauthenticated default.

## The routes

| Route | Behaviour |
| :--- | :--- |
| `GET /health` | Liveness, before authentication. |
| `GET /ready` | Authenticated readiness: 200 `{ok: true}` when the membrane is open, the ledger (when bound) verifies, and a configured file idempotency store still has its directory; otherwise 503 `{ok: false, code: "not_ready"}` with no exception text. |
| `POST /skin/apply` | A command → sanitised outcome. |
| `GET /skin/manifest` | The tool catalogue. |
| `GET /skin/observe/:cellId` | SSE `skin.egress.<cellId>` state changes; 404 for unexposed cells. |
| `GET /skin/ledger?since=N` | SSE audit: backlog replay from the store, then the live tail, with `id:` events and whitelist filtering. |
| `POST /skin/verify` | Structured verification — tamper failure returns `{ok: false, code: "verify_failed"}`; the exception goes to `onServerError` only. |

## curl

```bash
curl http://127.0.0.1:<port>/skin/manifest

curl -X POST http://127.0.0.1:<port>/skin/apply \
  -H 'Content-Type: application/json' \
  -d '{"cellId":"home.living.thermostat","function":"setTarget",
       "positional":[21],"correlationId":"my-retry-key"}'

curl -N http://127.0.0.1:<port>/skin/observe/home.living.thermostat
```

Positional arguments accept a plain JSON array or the index-keyed
object.

## Error status map

| Wire code | HTTP |
| :--- | ---: |
| `unknown_tool` | 404 |
| `conflict` | 409 |
| `idempotency_conflict` | 409 — a reused client id with a different body |
| `bad_arguments` | 422 |
| `cursor_required` | 428 |
| `queue_timeout` | 504 — still queued when the deadline passed; the function did not run |
| `queue_full` | 429 — the `maxQueued` cap is full; the function did not run and nothing was cached. Distinct from both 504s. |
| timeout | 504 `outcome_unknown` — the command may already be running; check the ledger, retry the same id |
| `transport_error` | 500 (no raw exception text) |

## Closed by default

The adapter enforces, per request:

1. A non-loopback `bind` requires `allowedHosts` — it throws
   `ArgumentError` otherwise (and the socket is closed). Missing, empty,
   or foreign `Host` is 403 `host_not_allowed` on every route except
   `/health`; the default loopback allowlist is the six loopback names
   with and without the bound port, and an explicit `allowedHosts`
   replaces it.
2. An `Origin` header that is not an exact `allowedOrigins` member is
   403 `origin_not_allowed` with no CORS headers. A listed origin is
   echoed on the response (never `*`) with `Vary: Origin`, and
   `OPTIONS /skin/<route>` is answered **before auth** with a 204
   preflight: per-route allow-methods, allow-headers `authorization,
   content-type, last-event-id`, and `Access-Control-Max-Age: 600`.
3. Methods are enforced per route; POSTs must be
   `application/json` with bodies capped at `maxBodyBytes` (1 MiB).
4. Malformed input returns stable 400 codes
   (`missing_cellId`, `bad_correlation_id`, `invalid_lastSeenSeq`,
   `bad_json`, …) — never a raw `TypeError` echo.
5. 401 carries `WWW-Authenticate`; `Bearer` matching is
   case-insensitive.

## SSE under the hood

SSE runs over a detached raw socket. After `detachSocket` the response
is real HTTP/1.1: `Transfer-Encoding: chunked` is on and every event is
one chunk. `Socket.done` releases the subscription on silent
disconnects, `keepAliveInterval` pings bound the detection window (and
keep intermediaries from dropping idle streams), and slow clients are
dropped instead of buffered forever. `adapter.activeSubscriptions`
reports live connections.

The ledger stream is resumable with three cursors:

| Cursor | Behaviour |
| :--- | :--- |
| none | Live tail only. History already in the store is not sent. |
| `?since=N` (N >= 0) | Entries with `seq >= N`, then live — **inclusive**. |
| `Last-Event-ID: N` | Entries with `seq > N`, then live — **exclusive**, and only when the query is absent. |

A bad `?since=` is 400 `invalid_since`; a garbage `Last-Event-ID` is
ignored (EventSource would reconnect forever on a 400). The live
listener is attached before the store is read, so a row committed while
the backlog is loading is delivered exactly once. Observe cell ids may
contain a slash: `/skin/observe/home/living` and
`/skin/observe/home%2Fliving` address `home/living` — clients
percent-encode slashes inside an id.

## Tune the knobs

```dart
RestAdapter.bind(
  membrane: membrane,
  auth: auth,
  allowedOrigins: {'https://app.example'},
  maxBodyBytes: 4 * 1024 * 1024,
  requestTimeout: const Duration(seconds: 10),
  keepAliveInterval: const Duration(seconds: 5),
  onRequestLog: (sample) => print(sample),
);
```

`onRequestLog` is the metrics hook — there is no metrics library. It
fires once per finished request with a `SkinRequestSample`: the bare
route (no query, which can carry a token), the server correlation id,
the status, the stable error code, the duration, and the apply's
`ledgerSeq`. No headers, no body, no token. An application that wants
a counter wraps the callback.

`SkinMembrane.open(maxQueued: n)` caps the number of accepted requests
whose dispatch has not finished; over the cap the caller gets
`queue_full` (429) immediately and the in-flight apply still finishes.

## See also

- `HowTo-Auth.md` — principals, credentials, context bridges.
- `HowTo-Egress.md` — what the SSE observe route streams.
- `HowTo-Idempotency.md` — the 504 retry contract.
- `example/lib/mock/rest_io.dart` — the demo's binding (and its web
  stub in `rest_stub.dart`).
