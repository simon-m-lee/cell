# cell_skin security

One page: the threat table is the page. The attacker is a remote HTTP
client. The ledger file and the idempotency directory are trusted local
state. The skin does not vouch for a domain `TestCell`. MCP is a seam,
not a transport, and it is outside this pass.

| Threat | Locked by | Already enforced in |
|---|---|---|
| Unauthenticated apply | `auth` is required. Anonymous is the explicit `AllowAllSkinAuth`. | `_authenticate` before `/skin/*`. `bind` has no default auth. |
| DNS rebinding | Host allow-list. A missing, empty, or broken `Host` is 403 `host_not_allowed`, except `GET /health`. | `_hostAllowed`. A non-loopback bind without `allowedHosts` throws and closes the socket. |
| Cross-origin browser call | Exact origin echo, `Vary: Origin`, preflight before auth, never `*`. A rejected origin gets no `Access-Control-Allow-Origin`. | `_handle`, before `_authenticate`. |
| Oversized or non-JSON body | 1 MiB (`kDefaultMaxBodyBytes`). Over the cap is 413 `body_too_large`. A body that is not a JSON object is 400 `bad_json`. Wrong content type is 422 `content_type_required`. | `_readJsonBody`. |
| Hidden tool probe | `unknown_tool` before the authorizer, on apply and on observe. The hook is not called. | `router_cell.dart` exposure gate, then the hook. Observe checks `isExposed` before `principalMayRead`. |
| Forged caller inside the gate | The domain reads `SkinCall.current`. REST builds that from `SkinAuth`, not from the JSON body. The bearer token is not copied into the snapshot. | `skinPulseContext`, `principalFrom`. |
| Token in logs or verify errors | The request sample has no headers and no body. Verify returns `{"ok": false, "code": "verify_failed"}` and nothing else. | `onRequestLog`. `_verify` sends the exception to `onServerError` only. |
| Retry with a different body | Fingerprint of `cellId`, function, positional, named, `lastSeenSeq`. HTTP 409 `idempotency_conflict`. | `idempotencyFingerprint`. |
| Retry after restart | `FileIdempotencyStore` replays a completed line. A crash after commit and before `complete` can still double-apply. | `file_idempotency_store.dart`. |
| Queue flood | `maxQueued`, HTTP 429 `queue_full`. The in-flight apply is not cancelled. | `skin_membrane.dart` cap, `router_cell.dart` decrement. |
| Read of a denied cell | A non-null `SkinAuthorizer` filters manifest, observe, and ledger. `null` does not. Read checks are not cached. | `SkinMembrane.mayRead`; the router's manifest filter; `_observe` and `_ledger`. |

The tests that lock each row: `rest_host_cors_test.dart` (host, origin,
preflight, verify body), `authorization_test.dart` (hidden tool skips
the hook), `idempotency_test.dart` (same id, different body, is 409),
`router_queue_test.dart` (`queue_timeout` is not `outcome_unknown`),
`request_log_test.dart` (the log sample has no token),
`security_pass_test.dart` (the remaining rows), and
`error_table_produced_test.dart` (every frozen code has a producer).

Residuals. They are accepted for 1.0, not tickets.

- `403 forbidden` on an exposed cell tells the client the cell exists.
  `404 unknown_tool` means it is not on the wire. Do not collapse those.
- A completed record replays without calling the hook again. The store
  key is the actor plus the client id, not the roles. A role change
  under the same actor id still replays. A different actor is a new
  apply, and the hook runs.
- Replay does not enter a `SkinCall` zone. A gate that decides only by
  `SkinCall.current` sees `null` on replay.
- `/health` is unauthenticated and exempt from the host check. `/ready`
  is not. `DescribeContextBridge` is the default. `SystemContextBridge`
  and `AllowAllSkinAuth` are opt-ins.

Out of scope for this tag: a SQL store, a lock across machines, an MCP
stdio server, a role language, cancelling an apply that has started,
`concurrency` above 1, and encrypting the local ledger or the
idempotency directory.

`dart pub outdated` is not clean for `test` (constraint `^1.25.0`) and
`lints` (constraint `^4.0.0`): the 1.0.0 tag keeps the pre-1.0 dev
constraints rather than bumping majors in the tag commit, and `cell`
is a local path override that stays `^2.1.0` for published consumers.
