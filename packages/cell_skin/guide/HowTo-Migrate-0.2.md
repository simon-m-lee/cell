# HowTo-Migrate-0.2

The breaks v0.2 already shipped from 0.1, so they are not rediscovered
at 1.0:

- `McpToolSpec.name` is the escaped form — unsafe characters become
  `_`, at most 64 characters. `dottedName` is the raw
  `<cellId>.<functionName>`.
- `POST /skin/verify` failure returns `{"ok": false, "code":
  "verify_failed"}` — it no longer returns `message`.
- The 504 is split: `queue_timeout` means the request was still queued
  when its deadline passed and did not run; `outcome_unknown` means the
  handler gave up while `apply` may already be running.
- A different body with the same client id is `idempotency_conflict`
  (409), not a replay.

0.3 adds one break:

- Encoded `WireMessage` bodies and SSE `data` lines gain `wire: "1"`.
  A 0.2 decoder already ignores unknown keys, so it still parses. A
  missing `wire` is version 1; any other value is `bad_json`.

Migration to 0.5 and later:

- Open a `FileIdempotencyStore` when a retry must survive a restart.
- Point readiness probes at `GET /ready`. `/health` stays liveness.
- Set `maxQueued` when a client can flood the process.

The rc rule: a commit that changes `test/goldens/wire/` also changes
this guide. After the rc tag, such a commit means the release is not
1.0.
