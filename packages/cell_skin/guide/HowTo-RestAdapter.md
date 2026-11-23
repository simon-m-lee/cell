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
| `POST /skin/apply` | A command → sanitised outcome. |
| `GET /skin/manifest` | The tool catalogue. |
| `GET /skin/observe/:cellId` | SSE `skin.egress.<cellId>` state changes; 404 for unexposed cells. |
| `GET /skin/ledger?since=N` | SSE audit: backlog replay from the store, then the live tail, with `id:` events and whitelist filtering. |
| `POST /skin/verify` | Structured verification — tamper failure returns `{ok: false, message}`. |

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
| `bad_arguments` | 422 |
| `cursor_required` | 428 |
| timeout | 504 `outcome_unknown` — check the ledger, retry the same id |
| `transport_error` | 500 (no raw exception text) |

## Closed by default

The adapter enforces, per request:

1. `Host` must be a loopback name — browser DNS-rebinding defence.
2. Any `Origin` header is rejected unless listed in `allowedOrigins`.
3. Methods are enforced per route; POSTs must be
   `application/json` with bodies capped at `maxBodyBytes` (1 MiB).
4. Malformed input returns stable 400 codes
   (`missing_cellId`, `bad_correlation_id`, `invalid_lastSeenSeq`,
   `bad_json`, …) — never a raw `TypeError` echo.
5. 401 carries `WWW-Authenticate`; `Bearer` matching is
   case-insensitive.

## SSE under the hood

SSE runs over a detached raw socket: frames flush per write,
`Socket.done` releases the subscription on silent disconnects,
`keepAliveInterval` pings bound the detection window (and keep
intermediaries from dropping idle streams), and slow clients are
dropped instead of buffered forever. `adapter.activeSubscriptions`
reports live connections.

## Tune the knobs

```dart
RestAdapter.bind(
  membrane: membrane,
  auth: auth,
  allowedOrigins: {'https://app.example'},
  maxBodyBytes: 4 * 1024 * 1024,
  requestTimeout: const Duration(seconds: 10),
  keepAliveInterval: const Duration(seconds: 5),
);
```

## See also

- `HowTo-Auth.md` — principals, credentials, context bridges.
- `HowTo-Egress.md` — what the SSE observe route streams.
- `HowTo-Idempotency.md` — the 504 retry contract.
- `example/lib/mock/rest_io.dart` — the demo's binding (and its web
  stub in `rest_stub.dart`).
