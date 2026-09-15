# Architecture — card auth pipeline (Cell)

**Companion to:** `card-auth-pipeline(Cell)-Demo.dart`  
**Variant of:** `card-auth-pipeline(tissue)-ARCHITECTURE.md`  
**Audience:** engineers extending the demo, teaching the seam, or porting the pattern to another industry.

This file is the **single-`FlowInstructionChain`** variant. The tissue
sibling uses two gates (`declineCell` / `stepUpCell`) and three
observers. This variant composes **stock Rx operators** — `MapValue →
DistinctUntilChanged → Filter → Tap → MapValue` — into **one**
`FlowInstructionChain` (`cardAuth`) materialized with **one**
`toHandle`. ACK stays an observer on `ackIn`. Money stays
caller-driven.

The chain is built with the `+` operator, which is the idiomatic
`cell_flow` way to assemble several `FlowInstruction` links into a
single composable pipeline. `riskOf` remains a plain pure function; the
book writes live in the `Tap` side effect.

**Documented trade-off.** `DistinctUntilChanged` is a stock operator
with no public reset API, so the ACK observer appends its row but does
**not** reset the chain's distinct latch. The scenario order (every
repeated DECLINE is separated by an approve) keeps the visible output
identical. If a real ACK reset is required, swap the distinct link for
a tiny hand-rolled resettable `FlowInstruction`.

---

## Contents

1. [One-paragraph summary](#1-one-paragraph-summary)
2. [Layering](#2-layering)
3. [Ownership matrix](#3-ownership-matrix)
4. [Locking](#4-locking)
5. [Failure semantics](#5-failure-semantics)
6. [How the FlowInstructionChain is made](#6-how-the-flowinstructionchain-is-made)
7. [Extending the demo](#7-extending-the-demo)
8. [Anti-patterns](#8-anti-patterns)
9. [Reading order for newcomers](#9-reading-order-for-newcomers)
10. [See also](#10-see-also)

---

## 1. One-paragraph summary

The demo wires two independent reactive subsystems together:

- **Flow** — the decision subsystem. Turns an `AuthAttempt` into a `Decision` (`none` / `approve` / `stepUp` / `decline`) inside **one** `FlowInstructionChain` composed of five stock operators. `MapValue` runs `riskOf` and carries `(attempt, decision)`; `DistinctUntilChanged` drops consecutive equal decisions; `Filter` keeps `decline` / `stepUp`; `Tap` writes the DECLINE / STEP-UP book rows; the final `MapValue` re-exposes the `Decision`. No money writes.
- **Tissue** — the books subsystem. Records decisions, moves cents, tracks open holds, exports a read-only view for compliance. Every write is validated by a `TestTissue` and takes that collection's lock.

The two subsystems share two channels: (1) the `Tap` side effect calling `_onDecline` / `_onStepUp`, which write `ledger` / `issuerQ`, and (2) `Cell.observe` on `ackIn.cell`, which appends an `ACK` row. `riskOf` *reads* the `mccBlock` TissueSet (one-way, non-mutating). Money never crosses from the chain — `placeHold` is called by `main()`.

---

## 2. Layering

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  FLOW (decision)                                                │
│  ─────────────────                                              │
│  • Cells:  amountIn, mccIn, velocityIn, presentIn, attemptIn,   │
│            ackIn, authCell (one toHandle)                       │
│  • Chain:  cardAuth = MapValue → DistinctUntilChanged           │
│                       → Filter → Tap → MapValue                 │
│    - riskOf: pure top-level function                            │
│    - distinct state: inside the stock DistinctUntilChanged      │
│    - book writes: Tap side effect (calls harness methods)       │
│  • Rules:  TestCell — shape only                                │
│                                                                 │
│  Produces:  Decision  (none | approve | stepUp | decline)       │
│                                                                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │  Cell.observe on ackIn  +  Tap book writes
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                                                                 │
│  TISSUE (books)                                                 │
│  ─────────────                                                  │
│  • Collections:                                                 │
│      ledger    TissueList<LedgerEntry>                          │
│      available TissueValue<int>                                 │
│      held      TissueValue<int>                                 │
│      holdsMap  TissueMap<String, Hold>                          │
│      mccBlock  TissueSet<String>                                │
│      issuerQ   TissueQueue<IssuerJob>                           │
│  • Rules:  TestTissue — mutation validity                       │
│  • Deputy: ledger.unmodifiable (read-only, live)                │
│                                                                 │
│  Produces:  durable state + audit trail                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1 What "the seam" means here

A **seam** is a boundary where two subsystems with different responsibilities, locks, and failure modes meet. In this demo the seam is one-directional for control (Flow → Tissue) and one-directional for policy input (Tissue → Flow via a read). The seam is not bidirectional for writes.

### 2.2 What the seam is **not**

- Not a shared mutable object.
- Not a callback registry.
- Not a shared lock.
- Not a shared enum-comparison pattern inside `riskOf` — the comparison reads the TissueSet, but does not mutate it.

The observer is a one-way delivery channel. If you ever find yourself wanting to write back from the observer to the decision pipeline, you have collapsed the seam and lost the lesson.

### 2.3 The four coupling points in this demo

There are exactly four places where the two subsystems touch:

| Coupling | Direction | Type | Notes |
|---|---|---|---|
| `Tap` side effect → `_onDecline` | Flow → Tissue | write-only | `ledger.add`, `issuerQ.addLast` |
| `Tap` side effect → `_onStepUp` | Flow → Tissue | write-only | `ledger.add` |
| `ackIn.cell` observer | Flow → Tissue | write-only | `ledger.add(ACK)` |
| `riskOf` reads `mccBlock` | Tissue → Flow | read-only | one-way policy input |

The read of `mccBlock` is the only non-write coupling, and it is explicitly part of the policy input, not a control channel.

### 2.4 The money method is called by the caller, not the observer

A subtle point: the ACK observer does **not** call `placeHold`. The ACK observer only appends an `ACK` row. The **caller** — `main()` in the demo — then calls `placeHold` directly when the talk track says "approve after 3DS."

This is a deliberate design choice. It means:

- The ACK observer stays a pure audit append. No money moves inside it.
- `placeHold` is a public method on the harness that can be called from any orchestration layer (a form handler, a 3DS callback, an operator console).
- The three money methods (`placeHold`, `capture`, `voidHold`) are the *only* methods that move cents. They are not observers; they are imperative APIs.

A real card network would wire the 3DS response to `placeHold` via a callback. The demo makes the wire explicit by putting the call directly in `main()`.

---

## 3. Ownership matrix

| Concern | Flow | Tissue |
|---|---|---|
| Parse amount / MCC | ✅ `TestCell` on ingress | — |
| Decide `none` / `approve` / `stepUp` / `decline` | ✅ chain (`riskOf` + `Filter`) | — |
| Dedupe consecutive decisions | ✅ stock `DistinctUntilChanged` | — |
| Read `mccBlock` | ✅ (read-only, one-way) | ✅ (owns the set) |
| Write `ledger` | ✅ (initiates from `Tap`) | ✅ (append-only rule, owns storage) |
| Write `available` / `held` | — | ✅ (non-negative rule) |
| Write `holdsMap` | — | ✅ (shape rule) |
| Write `issuerQ` | ✅ (initiates from `Tap`) | ✅ (bounded queue) |
| Enforce append-only log | — | ✅ `_ledgerAppendOnly` |
| Enforce non-negative cents | — | ✅ `_nonNegativeCents` |
| Enforce hold shape | — | ✅ `_holdRule` |
| Enforce MCC blocklist shape | — | ✅ `_mccBlockRule` |
| Export to compliance | — | ✅ `.unmodifiable` |
| React to `IssuerJob` | ✅ (`_driveIssuer`, called from `Tap`) | ✅ (`issuerQ`) |
| Move cents | — | ✅ `placeHold` / `capture` / `voidHold` |
| Reset Distinct latch | — (stock operator has no reset API) | — |
| Rebuild graph | — | — (nobody does this after `install`) |

**Rule.** If a concern appears in both columns, it is a layering violation. The intentional exceptions are: (a) `riskOf` reads `mccBlock` one-way and non-mutating; (b) the `Tap` side effect *initiates* ledger / issuerQ writes, but each collection still owns and validates its own storage.

### 3.1 Which subsystem owns which lock

Every reactive node in this graph has its own lock. The demo deliberately keeps two disjoint lock domains (see §4). No operation in the demo holds both locks at the same time. That is a design choice, not a coincidence: it makes each subsystem independently testable.

### 3.2 Which subsystem owns which latch

Distinct state is Flow state. With the stock-operator build it lives inside `DistinctUntilChanged` and is **not externally addressable**: there is no public field to read and no reset API. ACK therefore cannot clear it. The scenario sequence is designed around that constraint — every repeated DECLINE is separated by an approve.

| Latch | Lives in | Set by | Reset by |
|---|---|---|---|
| Previous decision | stock `DistinctUntilChanged` internal state | every attempt that passes `MapValue` | — (no public reset) |

One latch value is enough: `decline` and `stepUp` are different enum values, so a STEP-UP after a held DECLINE still fires (scenario STEP-UP after 4–5). If you need an ACK-resettable latch, replace the distinct link with a tiny custom `FlowInstruction`.

### 3.3 Which subsystem owns which money method

The three money methods are Tissue-only imperative APIs:

| Method | Writes | Reversible by |
|---|---|---|
| `placeHold` | `holdsMap[authId]`, `available`, `held`, `ledger` | `capture` (settles) or `voidHold` (releases) |
| `capture` | `holdsMap[authId]` (remove), `held`, `capturedCents`, `ledger` | — (terminal) |
| `voidHold` | `holdsMap[authId]` (remove), `held`, `available`, `ledger` | — (terminal) |

None of the three is called from an observer. All three are called by the harness's owner (the caller).

---

## 4. Locking

Two lock domains:

| Domain | Primitive | Held during |
|---|---|---|
| Decision | `authCell` Receptor path | the five chain links: `riskOf`, distinct, filter, `Tap` book writes, final map |
| Books | Tissue lock on each collection | one `add` / `set` / `[key]=` |

A DECLINE pulse crosses the two domains **sequentially**, never simultaneously:

```
attemptIn.emit(a)
  ─► authCell Receptor path (the FlowInstructionChain)
       ─► MapValue:  AuthAttempt → (attempt, decision)
       ─► DistinctUntilChanged: drop repeat decision?
       ─► Filter:   keep decline / stepUp?
       ─► Tap:      _onDecline / _onStepUp
            ─► ledger.add          (TissueList lock)
            ─► issuerQ.addLast     (TissueQueue lock)
       ─► MapValue: (attempt, decision) → Decision
  ─► release
```

The ACK path is different: the ACK is not an attempt. It does not pass through the chain. It goes straight to the ACK observer, which appends an `ACK` row.

```
ackIn.emit('H-1')
  ─► ackIn.cell observer
       ─► ledger.add(ACK)            (TissueList lock)
```

The `placeHold` path is also different: `placeHold` is called by the caller, not by an observer. It takes the Tissue locks in sequence:

```
h.placeHold('H-1', 60000, 'M-4419')
  ─► holdsMap['H-1'] = Hold(...)   (TissueMap lock released)
  ─► available.set(190000)         (TissueValue lock released)
  ─► held.set(60000)               (TissueValue lock released)
  ─► ledger.add(HOLD)              (TissueList lock released)
```

### 4.1 Consequences

- Because the domains are disjoint, `riskOf` cannot deadlock against `available.set`.
- Because they are sequential, `riskOf` cannot observe a half-written balance.
- Because each Tissue write takes its own lock, the `Tap` side effect takes the Tissue locks one `add` at a time.
- The ACK path holds no Receptor lock; ACK is a direct imperative call, not a pulse through the gate.
- The money path holds no Receptor lock; `placeHold` is called directly by the harness owner.

### 4.2 Why the demo does not use a joint lock

A joint commit across `holdsMap` + `available` + `held` + `ledger` would require a single lock spanning all four. That is a legitimate pattern (see §7.4), but this build of `cell_tissue` does not expose it. The v1 protocol in `placeHold` compensates on failure instead, and the header documents the trade-off.

### 4.3 The `placeHold` compensation ladder

`placeHold` writes four things in order:

```
1. holdsMap[authId] = Hold(...)     (TissueMap lock released)
2. available.set(before - cents)    (TissueValue lock)
3. held.set(heldBefore + cents)     (TissueValue lock)
4. ledger.add(LedgerEntry(kind: 'HOLD', ...))  (TissueList lock)
```

If step 2 rejects (the non-negative rule fires), step 1 is compensated by `holdsMap.remove(authId)`. The method returns `false` without leaving a partial state. Steps 3 and 4 are never reached.

If step 3 rejects, steps 1 and 2 are compensated: `available.set(before)` restores the balance, `holdsMap.remove` removes the map row. Step 4 is never reached.

If step 4 were to reject (it cannot — `_ledgerAppendOnly` accepts all `add` calls), the demo does not currently compensate steps 1–3. That is a known limitation of the v1 protocol; §7.4 discusses the joint-commit alternative.

`capture` and `voidHold` have simpler ladders because fewer writes can reject:

- **`capture`**: remove map row, set `held`, add `capturedCents`, append `CAPTURE`. Only `held.set` can reject, and it can only reject if the subtraction goes negative — which is impossible given the invariant. So `capture` has no compensation ladder.
- **`voidHold`**: remove map row, set `held`, set `available`, append `VOID`. Neither `held.set` nor `available.set` can reject given the invariant. So `voidHold` has no compensation ladder.

### 4.4 Why the compensation ladder matters

In a real acquirer, the three money writes must be atomic. If `holdsMap` is written but `available` is not, the books are inconsistent: a hold exists in the map but the cents are still in `available`. The next `placeHold` could double-count those cents.

The v1 ladder prevents that by explicitly undoing the map row if the balance write fails. A joint-commit transaction (§7.4) would replace the ladder with a single atomic operation.

---

## 5. Failure semantics

### 5.1 Shape failure (TestCell)

A bad amount / MCC dies at ingress. `setAmount` / `setMcc` return `false` and do **not** update the cache. `publishAttempt` is not called. No Tissue is touched. The rejected value never appears in `ledger`, `available`, `held`, `holdsMap`, or `issuerQ`.

**Why at the sensor, not inside the policy.** A shape error is a terminal / gateway problem, not a policy problem. Folding it into `riskOf` would make the policy conditional on transport quality and would let a malformed reading produce a decision.

### 5.2 Policy approve (riskOf)

`riskOf` returning `approve` — the attempt passes all risk checks — produces a `CardAuthRecord` that `Filter` drops. The **stock distinct latch still updates** to `approve`.

**Why that matters.** This is what makes `decline → approve → decline` fire twice. Because the sequence inserts an approve between repeated declines, the stock `DistinctUntilChanged` moves off `decline` and lets the next decline through — no ACK reset needed.

The rule in one sentence: **DistinctUntilChanged records every decision the chain made, including `approve`.**

### 5.3 Book rejection (TestTissue)

`placeHold` pre-checks `available`. If the pre-check fails, no map row is written. If the pre-check passes but `available.set` rejects (belt-and-braces), the map row is compensated. If `held.set` rejects, both `available` and `holdsMap` are compensated.

**Invariant.** After a successful call, `available.value! + held.value! + capturedCents == 250000`.

### 5.4 Issuer retry

`_driveIssuer` (called from the `Tap` side effect) catches the first failure and retries once. The retry is counted in `issuerAttempts`. A second failure is swallowed — the demo does not model dead-letter handling.

**Off-graph note.** The walkthrough specifies `AsyncMapWithRetry` with `count: 2`. This build's `TissueQueue` does not expose a Stream adapter and its `removeFirst` / `remove` do not drain. The demo therefore keeps `issuerQ` as the **audit-side enqueue** and uses a plain Dart `_issuerWork` list for the pump. The header documents this.

**Why the audit-side enqueue still matters.** Every `addLast` on `issuerQ` emits an `ElementAdded<IssuerJob>` on the Tissue. A downstream observer could subscribe to that queue and reconstruct exactly which issuer messages were attempted, when, and for which authorization. The queue is the durable record of the issuer channel's activity, even though the actual pump runs on a plain list.

**Where a real system would go next.** A production acquirer would replace `_issuerWork` with a proper outbound queue that persists across restarts, with backoff, dead-letter handling, and terminal-failure alerting. The demo stops at the retry-once boundary because the lesson is the seam, not the retry ladder.

### 5.5 NSF rejection (scenario 11)

Scenario 11 attempts `placeHold('H-2', 200000, 'M-4419')` while `available` is only 190000. The pre-check rejects it before any write. The invariant is preserved throughout — this is the pure demonstration of the non-negative `TestTissue` guard.

**Production note.** A real NSF attempt would be logged (as a `HOLD-REJECTED` or similar ledger row) to satisfy regulatory requirements. The demo does not do this because the demo's scenario table does not list such a row. In a real system, the `placeHold` method would append a rejection row before returning `false`.

### 5.6 Missing hold

`capture('UNKNOWN')` returns `false` and touches nothing. `voidHold('UNKNOWN')` returns `false` and touches nothing. Neither is an error.

**Why this is safe.** A missing hold means either (a) the hold was never opened, or (b) the hold was already captured or voided. Both are legitimate states; the method's job is to be idempotent on the "already done" side. The demo does not track which of the two cases applies.

### 5.7 Cascade failure

If `_driveIssuer` fails twice, the issuer job is dropped silently. The ledger records nothing about the second failure (it records the retry attempt, but not the terminal failure). A production system would emit an `ISSUER_FAILED` entry with the retry count.

### 5.8 ACK miss

An ACK with no matching pending state is not an error. It appends an `ACK` row. The caller may then call `placeHold` — but if the ACK is spurious (no 3DS challenge was actually pending), the hold is still legitimate: an operator has decided to approve the attempt.

**Why this is intentional.** The ACK is not a permission slip; it is a signal. It says "an analyst looked at this; proceed." The framework does not verify that a 3DS challenge was actually outstanding, because in a real system the analyst console and the framework are the same authority.

### 5.9 Stock DistinctUntilChanged has no reset

The ACK observer does not (and cannot) reset the chain's distinct state. This is a documented deviation, not a bug. If the scenario sequence ever needs a repeated DECLINE without an intervening approve, swap the distinct link for a custom resettable `FlowInstruction` — the rest of the chain is unchanged.

---

## 6. How the FlowInstructionChain is made

This section is the construction manual for the one object that turns a
stream of `AuthAttempt` pulses into DECLINE / STEP-UP book writes: the
`FlowInstructionChain` built in `installGate`.

### The glue type

Before the chain, the demo defines a record payload so later links can
see both the original attempt and the policy decision:

```dart
typedef CardAuthRecord = ({AuthAttempt attempt, Decision decision});
```

Without it, `Filter` could only see the `Decision`, and `Tap` would have
no auth id / MCC / amount to write the ledger row. The record is the
chain's internal contract.

### The five links, one by one

All five links are stock `cell_flow` operators. Each is a
`FlowInstruction`; `installGate` constructs them as local variables and
then composes them with `+`.

**Link 1 — `MapValue` runs the pure policy**

```dart
final snapshot = MapValue<AuthAttempt, CardAuthRecord>(
  (a) => (attempt: a, decision: riskOf(a, mccBlock)),
  user: 'riskOf',
);
```

Rx analogue: `map`. Input `AuthAttempt`, output `CardAuthRecord`.
`riskOf` reads `mccBlock` but never writes it (see §2.3); the policy
stays pure and unit-testable.

**Link 2 — `DistinctUntilChanged` drops repeat decisions**

```dart
final dedupe = DistinctUntilChanged<CardAuthRecord>(
  equals: (previous, next) => previous.decision == next.decision,
  user: 'distinctUntilChanged',
);
```

Rx analogue: `distinctUntilChanged`. It suppresses a DECLINE when the
previous pulse was also a DECLINE, but lets a DECLINE through after an
approve or stepUp. This is what makes scenarios 4 and 5 print
`new declines: 0`.

**Link 3 — `Filter` keeps only the actionable outcomes**

```dart
final actionable = Filter<CardAuthRecord>(
  (r) => r.decision == Decision.decline || r.decision == Decision.stepUp,
  user: 'decline-or-stepUp',
);
```

Rx analogue: `filter`. `approve` and `none` never reach the books. This
is what keeps the ledger empty in Seed and scenario 1.

**Link 4 — `Tap` writes the books without changing the payload**

```dart
final writeBooks = Tap<CardAuthRecord>((r) {
  switch (r.decision) {
    case Decision.decline:
      _onDecline(r.attempt);
    case Decision.stepUp:
      _onStepUp(r.attempt);
    case Decision.approve:
    case Decision.none:
      break;
  }
});
```

Rx analogue: `tap` / `do`. This is the only link with side effects. It
delegates to harness methods (`_onDecline` / `_onStepUp`) that own the
counters and the issuer pump, and those methods take the Tissue locks
one write at a time (see §4). The record passes through unchanged.

**Link 5 — `MapValue` re-exposes the public Decision**

```dart
final emitDecision = MapValue<CardAuthRecord, Decision>(
  (r) => r.decision,
  user: 'emitDecision',
);
```

Rx analogue: `map`. The chain's public output returns to
`Pulse<Decision>`, so any downstream observer of `authCell` sees the same
shape it would from any other decision gate.

### The `+` operator makes it ONE chain

```dart
cardAuth = snapshot + dedupe + actionable + writeBooks + emitDecision;
```

- `+` is `FlowInstruction.operator +`; each call returns a new
  `FlowInstruction` that runs the left link first and the right link
  second.
- The expression is left-associative, so it builds
  `((((snapshot + dedupe) + actionable) + writeBooks) + emitDecision)`.
- The final object is an instance of the private `_FlowInstructionChain`,
  but the demo holds it through the public type
  `FlowInstruction<Cell, Pulse, Pulse>`.

### `toHandle` turns the blueprint into a live cell

```dart
authHandle = cardAuth.toHandle(source: attemptIn.cell);
authCell = authHandle!.cell;
```

The chain is a **blueprint** until this call. `toHandle` compiles the
five links into one Receptor, binds that receptor to `attemptIn.cell`,
and returns a `FlowHandle` record. `authHandle.cell` is the live gate
cell shown in §2. The demo calls `toHandle` exactly once, inside
`installGate`.

### Type flow through the chain

| Link | Input payload | Output payload | Effect |
|---|---|---|---|
| `snapshot` | `AuthAttempt` | `CardAuthRecord` | policy + record |
| `dedupe` | `CardAuthRecord` | `CardAuthRecord` | drop consecutive repeat decisions |
| `actionable` | `CardAuthRecord` | `CardAuthRecord` | keep decline / stepUp |
| `writeBooks` | `CardAuthRecord` | `CardAuthRecord` | side effect, pass-through |
| `emitDecision` | `CardAuthRecord` | `Decision` | public output |

### One pulse through the finished chain (scenario 2)

1. `attemptIn` emits `Pulse<AuthAttempt>` for auth id `2`.
2. `snapshot` produces `(attempt 2, Decision.decline)`.
3. `dedupe` sees the previous decision was `approve` → passes.
4. `actionable` keeps `decline`.
5. `writeBooks` calls `_onDecline(attempt 2)` → DECLINE row,
   `issuerQ` enqueue, issuer pump.
6. `emitDecision` emits `Pulse<Decision>(decline)` from `authCell`.

Every scenario in the WalkThrough's executable-steps section is a
different path through these same five links.

### Why the chain is shaped this way

- **Pure policy in a map, side effects in a tap** — keeps `riskOf`
  testable and keeps the seam visible.
- **A record in the middle** — lets the dedupe key and the book write
  see different data without a custom operator.
- **One materialization** — all five links share one cell, one receptor,
  one lock domain. ACK never rebuilds the chain.
- **Stock-only** — the chain reads as five well-known Rx concepts; the
  trade-off is that `DistinctUntilChanged` has no external reset
  (documented in §5.9).

---

## 7. Extending the demo

### 7.1 Adding a third decision (e.g. `review`)

1. Add `Decision.review` to the enum.
2. Add the clause to `riskOf`.
3. Widen the `Filter` predicate to keep `review`.
4. Add a `case Decision.review:` arm to the `Tap` side effect.
5. Add the corresponding `TestTissue` and counter.
6. Extend the trailer.

The pattern is mechanical: one enum value, one clause, one filter predicate, one tap arm, one counter. The chain shape stays the same.

### 7.2 Multi-currency routing

Currently `AuthAttempt.amountCents` is implicitly in USD (or the demo's base currency). To support ISO-4217 routing:

1. Add a `currency` field to `AuthAttempt`.
2. Add a `TestCell` on the new `currencyIn` that rejects anything not matching the ISO-4217 pattern (`^[A-Z]{3}$`).
3. Add a `TissueMap<String, int>` for the FX table, keyed on currency code.
4. Convert in `riskOf` before the risk checks, or add a `MapValue` conversion link before the existing chain.

### 7.3 Persistent ledger

Replace `TissueList<LedgerEntry>` with a custom `Tissue` subtype that writes each `ElementAdded` to a database. The `TestTissue` and the `Tap` side effect do not change; only the storage strategy changes.

**What this buys.** The compliance deputy's `ledger.unmodifiable` view still works — the view reads from the new storage strategy. The `_ledgerAppendOnly` rule still fires on every `add`. The `Tap` side effect still calls `ledger.add(...)`. The only code that changes is the storage layer underneath the `TissueList`.

**What this costs.** A persistent store introduces I/O latency. The `placeHold` ladder would need to await the write, or accept that the ledger entry lands asynchronously. The v1 protocol currently assumes synchronous Tissue writes.

### 7.4 `Cell.transaction` across the money writes

When the running `cell_tissue` build exposes a joint commit across `TissueValue` + `TissueMap` + `TissueList`, replace the v1 try/compensate in `placeHold` / `capture` / `voidHold` with a single `Cell.transaction` block. Until then, stay on v1.

**The joint-commit shape.** A hypothetical joint commit would look like:

```dart
await Cell.transaction((tx) async {
  tx.update(holdsMap, {'H-1': Hold(...)});
  tx.update(available, 190000);
  tx.update(held, 60000);
  tx.update(ledger, LedgerEntry(kind: 'HOLD', ...));
  await tx.commit();
});
```

If any of the four writes reject, the whole transaction rolls back. This eliminates the need for `placeHold`'s try/compensate ladder.

### 7.5 Adding a debounce in front of `attemptIn`

A 10–15 second "finger on glass" window is a `Debounce` in front of `attemptIn`:

```dart
final debounced = Flow.debounce<AuthAttempt>(
  attemptIn.cell,
  duration: Duration(seconds: 12),
);
```

Materialize the chain against the debounced cell instead of `attemptIn.cell`:

```dart
authHandle = cardAuth.toHandle(source: debounced.cell);
```

The seam does not move; only the input cadence changes.

**What this changes.** The distinct operator now sees one attempt per debounce window instead of one attempt per publish. If a merchant sends five identical attempts in three seconds, only the last reaches the chain. This is the desired behaviour for a real acquirer.

### 7.6 Settlement batch

A nightly settlement run can drain `issuerQ` on a timer:

```dart
Flow.interval(tick.cell, period: Duration(hours: 24))
  .flatMap((_) => Flow.fromIterable(issuerQ.toList()))
  // … map each job to a settlement call
```

The tissue queue stays the audit record; the batch is the process that reads from it. The `AsyncMapWithRetry` pattern that was specified for the issuer pump would be the natural fit for the settlement call itself.

### 7.7 Scheme STIP / partial auth

A stand-in processing (STIP) path requires the framework to handle the case where the issuer is unreachable. That would be:

1. A third decision `Decision.stip`.
2. A `TestTissue` on `issuerQ` that allows STIP-bound jobs to outlive the pump.
3. A `TissueValue<int>` tracking the number of STIP-bound authorizations.
4. A new `Tap` switch arm that routes STIP jobs differently.

The pattern is the same: one chain, one filter predicate per product, one `Tap` arm per product, one `TestTissue` per collection.

### 7.8 Multi-currency routing with FX

A multi-currency version would split `amountCents` into `(amountMinor, currency)`. The risk checks would need a converted amount in the base currency. That means either:

1. A `TissueMap<String, int>` of FX rates, read by `riskOf`.
2. An extra `MapValue` link before the chain that converts the amount.

Option 1 keeps the chain unchanged; option 2 adds one more stock operator. The choice depends on whether FX conversion is a policy input (option 1) or a policy output (option 2).

### 7.9 Migration to a new industry

The pattern is domain-agnostic. To reuse it for, say, mobility:

1. Rename the domain types (`AuthAttempt` → `MatchTick`, `Hold` → `Assignment`, etc.).
2. Rewrite `riskOf` for the new policy.
3. Keep the chain shape: `MapValue → DistinctUntilChanged → Filter → Tap → MapValue`, one `toHandle`, one `TestTissue` per collection.
4. Keep the two-lock discipline.

The `grid-demand-response(tissue)-Demo.dart` and `ride-hail-dispatch(tissue)-Demo.dart` files are worked examples of the same pattern in different domains.

---

## 8. Anti-patterns

| Anti-pattern | Why it breaks the lesson |
|---|---|
| `ledger.add(...)` inside `riskOf` | Folds Tissue into the policy; makes the policy untestable. |
| `ledger.add(...)` inside a `MapValue` link | Side effects belong in `Tap`; a map should stay pure. |
| `available.set(...)` inside `riskOf` | Folds Tissue into the decision; makes the policy untestable. |
| Replacing Distinct with "ledger has this auth id" | The log is history; Distinct is the *current* latch. |
| `toHandle` called from the ACK observer | Doubles every downstream effect on the next attempt. |
| Passing `TestCell.allowAll` to a Tissue constructor | Type error at best; silent looseness at worst. |
| Wrapping a `TestCell` in `TestTissue` to "compose" | They are not subtypes; compose with `+` on the correct side. |
| Using a Dart `List<LedgerEntry>` as the source of truth | The books are the `TissueList`; a local list is only for the pump's working queue. |
| Batching issuer jobs without a `TestTissue` | The queue would accept malformed jobs; the rule is the shape gate. |
| Using `mccBlock` as a shared mutable global | `riskOf` must read it, not own it; ownership stays with the Tissue. |
| Adding a second `toHandle` for the same chain on every ACK | Classic "stacked graph" bug; ACK must only append its row. |
| Trying to make `riskOf` async so it can await a Tissue read | `riskOf` must stay synchronous; async reads belong at ingress. |
| Encoding the DECLINE/STEP-UP distinction in a single boolean | Two products need two `Decision` arms; a boolean cannot express the 3DS challenge. |
| Emitting a `Decision` directly from `riskOf` | `riskOf` returns a value; the chain emits the pulse. |
| Bundling `placeHold` into the `Tap` side effect | The `Tap` book write must not touch `available` or `held`. Money moves on ACK, not on decision. |
| Decrementing `available` inside `riskOf` | `riskOf` is pure. The balance is Tissue state. |
| Writing `available` inside the ACK observer | ACK appends a row. The caller decides whether to move money. |
| Calling `placeHold` from the STEP-UP `Tap` arm | STEP-UP is a decision, not a debit. The caller calls `placeHold` after the 3DS callback. |
| Bypassing `placeHold` to write `available` / `held` directly | The three money methods are the only writers of the money tables. Any other path breaks the invariant. |
| Ignoring the compensation ladder in `placeHold` | A partial write leaves an orphan hold or a lost balance. The ladder prevents both. |
| Hard-coding the base currency in `riskOf` | Currency is policy input; it belongs in the `AuthAttempt` or a `TissueMap`. |
| Putting the chain's counters on the instruction object | The chain is built from stock operators; counters are harness-side fields read by the trailer. |

---

## 9. Reading order for newcomers

1. **This file** — the architecture in five minutes.
2. **`card-auth-pipeline(Cell)-Demo.dart`** — skim the class doc, then read `installGate` (the `+` chain), `riskOf`, `_onDecline` / `_onStepUp`, `placeHold`.
3. **`card-auth-pipeline(Cell)-WalkThrough.md`** — the requirement and the scenario contract.
4. **`card-auth-pipeline(Cell)-FEATURES.md`** — the operator catalogue.

For a second domain, read `grid-demand-response(tissue)-Demo.dart` or `ride-hail-dispatch(tissue)-Demo.dart` in the same order. The seam is identical; only the policy, the domain types, and the `TestTissue` rules differ.

---

## 10. See also

| File | Purpose |
|---|---|
| `card-auth-pipeline(Cell)-Demo.dart` | Executable — one FlowInstructionChain (MapValue → DistinctUntilChanged → Filter → Tap → MapValue). |
| `card-auth-pipeline(Cell)-WalkThrough.md` | Requirement and scenario contract. |
| `card-auth-pipeline(Cell)-FEATURES.md` | Operator catalogue. |
| `card-auth-pipeline(tissue)-Demo.dart` | Two-gate sibling. |
| `grid-demand-response(tissue)-Demo.dart` | Energy sibling — same graph shape, different domain. |
| `ride-hail-dispatch(tissue)-Demo.dart` | Mobility sibling. |
| `ICU-alarm-pipeline(enhanced)-Demo.dart` | Clinical sibling. |
