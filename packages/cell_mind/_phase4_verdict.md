# Phase 4 — Day-1 precursor verdict

Recorded: 2026-11-15, against the live workspace substrate
(`cell` 1.1.0, `cell_tissue` 1.0.0).

## 1. `TissueMap.apply(tx:)` staging

Probe: `Cell.txApply()` with `participants: [TissueMap, ValueCell]`,
staging `map.remove` and `committed.value = ...` inside the body.

Result: **stages correctly.**

- Commit path: map shrank, committed value landed.
- Rollback path (throw inside body): map entry restored, committed
  unchanged.

**Decision:** use the primary D3 pattern (`txApply` across both
participants). No fallback needed.

## 2. `ValueCell.apply(tx:)` staging

Probe above covers it — the `ValueCell` (from `Cell.state`) stages and
rolls back correctly as a transaction participant.

## 3. Findings discovered during implementation

### A1 — Async rules are evaluated twice per pulse with distinct objects

The substrate's receptor validates an async rule once in the base
entry and once in the async drain, with **different pulse objects**.
Returning a per-evaluation future (e.g. `resolver(...).then(...)`)
diverges: two submissions, and the wave never resumes on resolution.
Cache-key attempts (identity, lineage root via `Iterable`) all miss.

**Adaptation:** wave-honest Defer — record the `Defer` decision, drop
the pulse from the wave, run the resolver out-of-band, record the
resolution as a follow-up decision linked by `decisionId`. Delivery of
approved values flows through `ApprovalQueue.committed`.

### A2 — `EffectJournal.timer` cannot be cancelled

Its returned future completes when the timer fires; no cancel handle.
A long-TTL queue would keep the isolate alive forever.

**Adaptation:** the sweeper uses a cancellable `dart:async` `Timer`
(cancelled by `dispose()`); expirations remain journaled explicitly
(`mind.approval.expired`), so the ledger timeline is reconstructible.

### A3 — `StateError` is an `Error`, not an `Exception`

The original resolver `catchError` rethrew `StateError` loudly.
Resolvers now fail closed on **any** throwable, with the error text in
the `defer-resolver-failed` annotations.

### A4 — Static generic methods need `Class.fromMap<T>(...)` syntax

`Class<T>.fromMap(...)` does not resolve for a static method with its
own type parameter (compiler: "Couldn't find constructor"). Verified
in isolation; tests use `ApprovalRequest.fromMap<int>(...)`.

### A5 — `TissueMap` gating uses `TestTissue`, not `TestCell`

`TissueMap(properties: TissueMapNucleus(testRule: TestTissue(...)))`
is the live spelling.

### A6 — `completes(...)` does not exist in the pinned matcher

Use `completion(...)` (matcher 0.12.x).

### A7 — Deferral audit is a decision PAIR

`Defer` request + resolution decision, linked via
`annotations['decisionId']`. Tests and guides pin the pair; filters
that assume one-decision-per-pulse must account for it.

## 4. Verdict

PROCEED with the primary atomicity pattern and the wave-honest Defer
semantics documented in `guide/05-Approval.md` §3.2.
