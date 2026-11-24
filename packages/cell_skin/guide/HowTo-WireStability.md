# HowTo-WireStability

This page is the wire contract. `test/goldens/wire/` is its machine
twin: the golden test fails when an encoded body gains or loses a key,
and the error directory and `skinErrorStatus` must name the same codes
and statuses.

## Frozen at 1.0

| Surface | Rule |
|---|---|
| Wire version | Every encoded body carries `wire: "1"`. Any other value is `bad_json`. A missing field decodes as version 1, so a 0.2 peer still parses. 1.0 servers always send the field. |
| Error table | Code, HTTP status, and whether a receipt exists. New codes may be added. Old codes do not move. |
| Idempotency fingerprint | Canonical JSON of `cellId`, `function`, `positional`, `named`, `lastSeenSeq`. A 1.x server replays a 1.0 record. |
| MCP escape | `[^A-Za-z0-9_-]` becomes `_`, no collapsing, length at most 64. |
| SSE | `id` is the decimal seq. Query `since` is inclusive. `Last-Event-ID` is exclusive and used only when `since` is absent. Chunked framing stays on. |
| Required constructor parameters | New parameters are optional and default to v0.2 behavior. |

## The error table

| Code | HTTP | Receipt |
|---|---|---|
| `unknown_tool` | 404 | no |
| `bad_arguments` | 422 | no |
| `cursor_required` | 428 | no |
| `conflict` | 409 | no |
| `idempotency_conflict` | 409 | no |
| `forbidden` | 403 | no |
| `queue_timeout` | 504 | no |
| `outcome_unknown` | 504 | no |
| `queue_full` | 429 | no |
| `verify_failed` | 500 | no |
| `host_not_allowed` | 403 | no |
| `origin_not_allowed` | 403 | no |
| `transport_error` | 500 | no |

Every row means "no receipt exists": these are pre-apply or
adapter-local codes, never `WireResponse`s.

Unknown JSON fields are ignored. An unknown `kind` is
`transport_error`.

The adapter-local parser codes are deliberately **not** in the table —
they are REST projection errors, not wire errors:
`bad_json`, `content_type_required`, `body_too_large`, `missing_body`,
`bad_correlation_id`, `missing_cellId`, `missing_function`,
`invalid_positional`, `invalid_lastSeenSeq`, `missing_cell`,
`unexpected_response`, `no_ledger`.

REST command envelopes (`POST /skin/apply` bodies and REST error
bodies) are projections, not wire messages: they do not gain `wire`.
SSE `data` lines are wire messages and do.
