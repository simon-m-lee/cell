# HowTo-Cursors

Opt-in `strictCursor` bindings turn the skin into an optimistic
concurrency surface: a caller must prove it has seen the current state
before its command runs.

## When to use

- Commands that must not run against stale state: configuration
  changes, approvals, anything where "read, then write" needs a
  guarantee.
- Per-binding opt-in — cursors are **off** by default, so ordinary
  tools keep their simple signature.

## When not to use

- Fire-and-forget commands (no `lastSeenSeq` is fine on non-strict
  bindings).
- Read-heavy tools where a conflict is more harmful than a stale
  write.

## Opt in

```dart
SkinBinding(
  cellId: 'home.living.thermostat',
  functionName: 'setTargetStrict',
  target: thermostat.cell,
  function: (int target) => thermostat.update(target),
  strictCursor: true,
)
```

## Semantics — exact equality

A strict binding requires `lastSeenSeq == ledger.head` **exactly**:

| Condition | Result |
| :--- | :--- |
| cursor missing | `WireError{code: 'cursor_required'}` (428 on REST) |
| cursor behind head | `WireError{code: 'conflict'}` (409) — stale caller state |
| cursor ahead of head | `WireError{code: 'conflict'}` (409) — cannot have seen current state |
| cursor == head | proceeds |

The cursor is the **global** ledger head — a deliberate, stateless
design. The router's `concurrency: 1` removes intra-skin races; the
check-then-apply window against *external* writers is documented and
narrow.

## Client side

```dart
final client = SkinClient(membrane: membrane);

// Read the current head from the ledger stream or the manifest context…
final outcome = await client.apply(
  'home.living.thermostat',
  'setTargetStrict',
  positional: [21],
  lastSeenSeq: 4, // the head the caller last observed
);
```

On `conflict`, the caller refreshes its view (the ledger SSE stream is
the natural source) and retries.

## Requirements

- A strict binding needs a **bound ledger** — without one every
  request conflicts.
- Rejections happen before `target.apply`: no receipt, no ledger
  entry.

## See also

- `HowTo-Bindings.md` — where the flag lives.
- `HowTo-Idempotency.md` — the retry story.
- `ARCHITECTURE-Skin.md` §8.
