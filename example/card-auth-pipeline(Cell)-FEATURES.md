# Features — card auth pipeline (Cell)

**Companion to:** `card-auth-pipeline(Cell)-Demo.dart`  
**Variant of:** `card-auth-pipeline(tissue)-FEATURES.md`

Single-`FlowInstructionChain` variant: one `cardAuth` chain built from
five stock Rx operators — `MapValue → DistinctUntilChanged → Filter →
Tap → MapValue` — materialized with one `toHandle`. Same scenario table
and trailer as the tissue sibling, except the ACK row now says the
stock distinct latch is untouched.

---

## Contents

1. [Feature catalogue](#1-feature-catalogue)
    - [Sensor ingress (TestCell)](#11-sensor-ingress-testcell)
    - [Risk policy (Flow)](#12-risk-policy-flow)
    - [Operator chain (Flow)](#13-operator-chain-flow)
    - [Books (Tissue)](#14-books-tissue)
    - [Money protocol](#15-money-protocol)
    - [Issuer pump](#16-issuer-pump)
    - [Compliance deputy](#17-compliance-deputy)
2. [Scenario catalogue](#2-scenario-catalogue)
3. [What the demo does not do (deliberately)](#3-what-the-demo-does-not-do-deliberately)
4. [Operator cheat sheet](#4-operator-cheat-sheet)
5. [Acceptance checklist](#5-acceptance-checklist)
6. [See also](#6-see-also)

---

## 1. Feature catalogue

### 1.1 Sensor ingress (TestCell)

| Feature | Where | Behaviour |
|---|---|---|
| Amount shape validation | `_amountShape` on `amountIn` | Rejects < 1 or > 250_000. Requires `int`. |
| MCC shape validation | `_mccShapeRule` on `mccIn` | Rejects anything that is not exactly 4 digits. Requires `String`. |
| Pulse unwrapping | every `TestCell` rule | Rule reads `Pulse.payload`, not the wrapper. Without this the rule sees a `Pulse<int>` and rejects every emission. |
| Cache-on-accept | `setAmount` / `setMcc` | Rejected values do **not** overwrite the previous accepted value. |
| Pre-flight guards | `publishAttempt` | Re-checks `_amountValid` / `_mccValid` before emitting, so a scenario can *report* a rejection without publishing. |
| Zero-delay drain | `publishAttempt` / `ack` | Awaits a `Duration.zero` future so the observer chain drains before the next scenario step. |
| Free-form caches | `setVelocity` / `setPresent` | No `TestCell` — velocity and presentment are policy inputs, not shape errors. |

### 1.2 Risk policy (Flow)

| Feature | Where | Behaviour |
|---|---|---|
| Pure risk evaluation | top-level `riskOf` | No `await`, no I/O, no state, no money writes. |
| Blocked MCC + CNP | `riskOf` first clause | `a.mcc in block` and `cardNotPresent` → `decline`. |
| Velocity threshold | `riskOf` second clause | `velocity >= 5` → `decline`. |
| Large CNP | `riskOf` third clause | `amountCents >= 50_000` and `cardNotPresent` → `stepUp`. |
| Very large | `riskOf` fourth clause | `amountCents >= 100_000` → `stepUp`. |
| Default approve | `riskOf` final clause | Everything else → `approve`. |
| Ordering guarantee | clause order | A blocked MCC is declined before any velocity or amount check. |
| Unit-testable | top-level + no I/O | Can be tested with a bare `AuthAttempt` and an empty `TissueSet`. |
| Read-only Tissue access | `riskOf(a, mccBlock)` | Reads the `mccBlock` TissueSet. Never writes it. |

### 1.3 Operator chain (Flow)

| Feature | Where | Behaviour |
|---|---|---|
| Single chain | `installGate` | `cardAuth = MapValue + DistinctUntilChanged + Filter + Tap + MapValue`. |
| Rx `map` (snapshot) | first `MapValue<AuthAttempt, CardAuthRecord>` | Runs `riskOf`; carries `(attempt, decision)` so later links have both values. |
| Rx `distinctUntilChanged` | `DistinctUntilChanged<CardAuthRecord>` | Drops consecutive equal decisions via `equals: (a, b) => a.decision == b.decision`. |
| Rx `filter` | `Filter<CardAuthRecord>` | Keeps only `decline` / `stepUp`. |
| Rx `tap` / `do` | `Tap<CardAuthRecord>` | Runs the book side effect (`_onDecline` / `_onStepUp`) without changing the payload. |
| Rx `map` (emit) | final `MapValue<CardAuthRecord, Decision>` | Re-exposes `Decision` as the chain's public output. |
| Single materialization | `toHandle(source: attemptIn.cell)` | Exactly **one** call; `authHandle.cell` is the live gate. |
| Stock-only trade-off | ACK observer | ACK appends its row but cannot reset `DistinctUntilChanged` (no public reset API). |

### 1.4 Books (Tissue)

| Feature | Where | Behaviour |
|---|---|---|
| Append-only ledger | `_ledgerAppendOnly` on `ledger` | `add` / `addAll` allowed; `remove` / `clear` / `[]=` denied. |
| Non-negative cents | `_nonNegativeCents` on `available` and `held` | Any write that would go negative is rejected. |
| Hold shape validation | `_holdRule` on `holdsMap` | `amountCents > 0` and `authId.isNotEmpty`. |
| MCC blocklist shape | `_mccBlockRule` on `mccBlock` | Exactly 4 digits. |
| Bounded issuer queue | `issuerQ` with `capacity: 32` | Overflow drops oldest (circular buffer behaviour). |
| Issuer job rule | `_issuerJobRule` on `issuerQ` | Accepts every job — extension hook for future rate-limiting. |
| Initial population is silent | every Tissue | Observers only see *post-create* mutations. |
| Attempt carried by the record | `CardAuthRecord.attempt` | The `Tap` side effect correlates each decision with the original `AuthAttempt`. |
| Runtime blocklist mutation | `mccBlock.add(...)` | Ops can block a code without redeploying the graph. |

### 1.5 Money protocol

| Feature | Where | Behaviour |
|---|---|---|
| NSF pre-check | `placeHold` | Rejects *before* writing the map row, so no orphan `Hold` record. |
| Compensating write | `placeHold` | Map row removed if `available.set` rejects; `available` restored if `held.set` rejects. |
| Capture-by-authId | `capture` | Looks up by auth id; moves cents from `held` to `capturedCents`. |
| Void-by-authId | `voidHold` | Looks up by auth id; moves cents from `held` back to `available`. |
| No-op capture | `capture` returns `false` | A capture with no open hold does not invent cents. |
| No-op void | `voidHold` returns `false` | A void with no open hold does not invent cents. |
| Money invariant | trailer | `available + held + capturedCents == 250000`. |
| Ordered writes | `placeHold` / `capture` / `voidHold` | Map row first, then balances, then ledger. Order is load-bearing for compensation. |
| Caller-driven money | `main()` | The three money methods are called by the caller, not by observers. |
| Capture is terminal | `capture` | Once a hold is captured, `capturedCents` is a running total. It cannot be uncaptured. |
| Void is terminal | `voidHold` | Once a hold is voided, the cents return to `available`. It cannot be re-voided. |

### 1.6 Issuer pump

| Feature | Where | Behaviour |
|---|---|---|
| Single-shot retry | `_driveIssuer` (called from `Tap`) | Retries once on failure. |
| Retry counter | `issuerAttempts` | Counts **both** attempts (initial + retry). |
| Fail-once injection | `issuerFailOnce` | Scenario 9 flips it on; the next attempt throws once. |
| Audit-side enqueue | `issuerQ.addLast` (inside `_onDecline`) | Every job appears as `ElementAdded<IssuerJob>` on the queue. |
| Working list | `_issuerWork` | Drives the pump, because `TissueQueue.removeFirst` does not drain in this build. |
| Decline only | `_onDecline` | Only declines enqueue issuer jobs. Step-ups do not. |
| Silent terminal failure | `_driveIssuer` catch block | A second failure is swallowed — the demo does not model dead-letter handling. |

### 1.7 Compliance deputy

| Feature | Where | Behaviour |
|---|---|---|
| Live read-only view | `ledger.unmodifiable` | Zero-copy projection. Reads share storage. |
| Write block | COMPLY scenario | `auditor.add` does not grow `ledger`. |
| Length parity | COMPLY scenario | `auditor.length == ledger.length` after the attempted write. |
| Silent swallow | this build | The unmodifiable wrapper swallows writes silently, so the demo checks length before/after. |
| Live reflection | this build | Changes to `ledger` remain visible through `auditor`. |
| Read-shared storage | `.unmodifiable` contract | `auditor[i]` reads the same underlying `TissueContainer` slot as `ledger[i]`. |

---

## 2. Scenario catalogue

| Banner | Feature exercised | Acceptance line |
|---|---|---|
| Seed | Bus + chain riskOf + silent initial population | `ledger.isEmpty=true` |
| 1 | DistinctUntilChanged on `approve` | `new declines: 0` |
| 2 | Blocked MCC policy (TissueSet feeds `riskOf`) | `[mccBlock] +7995`, `[ledger] DECLINE 2`, `new declines: 1` |
| 3 | Distinct `approve`→`decline` after recover | `new declines: 1` |
| 4 | Distinct suppression (previous decision is `decline`) | `new declines: 0` |
| 5 | Distinct keys on Decision, not amount | `new declines: 0` |
| STEP-UP | Second Decision outcome through the same chain | `[ledger] STEP-UP SU-1`, `new step-ups: 1` |
| 6 | ACK appends row; stock distinct latch untouched | `[ledger] ACK 6 — ack received (stock distinct latch untouched)` |
| 7 | Fresh decline after an intervening approve | `new declines: 1` |
| 8 | TestCell rejection at ingress | `accepted=false` ×2, `ledger grew: 0` |
| 9 | Issuer retry | `[ledger] ISSUER 9b — decline (retry)`, `issuerAttempts=5` |
| 10 | TissueValue + TissueMap place hold | `[available] 250000 → 190000`, `openHolds=1` |
| 11 | Non-negative TestTissue rejects (NSF) | `placeHold ok=false`, `openHolds stayed=true` |
| 12 | Capture moves held → captured | `[held] 60000 → 0`, `captured=60000` |
| 13 | Place + void returns cents | `[available] 180000 → 190000`, `openHolds=0` |
| COMPLY | Deputy blocks write, shares storage | `blocked=true`, `auditor.length=17 ledger.length=17` |

---

## 3. What the demo does **not** do (deliberately)

| Missing feature | Why it is out of scope | Where it would live |
|---|---|---|
| Real issuer I/O (ISO 8583, VISA) | The demo is in-process; a real acquirer link is not. | A custom `Tissue` subtype wrapping the protocol stack. |
| Real 3DS challenge | The demo treats the ACK as a ledger row. | A `Cell.synthesis` over a 3DS response stream. |
| Multi-currency FX | Single-currency keeps the invariant arithmetic honest. | `TissueMap<String, int>` + per-currency `TestTissue` on the FX table. |
| Joint commit across tissues | This build's `cell_tissue` does not expose it. | `Cell.transaction` spanning Tissue writes. |
| Persistent ledger | Demo is one-shot, ephemeral. | Same Tissue API over a store. |
| Settlement batching | Not applicable to real-time auth. | `BufferTime` overnight, or drain `TissueQueue` on a timer. |
| Dead-letter handling | Retry-once is enough for the lesson. | `TissueQueue<IssuerJob>` with a second consumer. |
| Dead-letter alerting | Same. | An `observe` on the queue's `ElementAdded`. |
| Debounce in front of `attemptIn` | The demo publishes one attempt per scenario step. | `Flow.debounce<AuthAttempt>` before the chain's `toHandle`. |
| A third Decision beyond DECLINE/STEP-UP | Two outcomes are enough to show the shape. | New enum value + new `riskOf` clause + new `Filter`/`Tap` arm. |
| ACK-resettable distinct | Stock `DistinctUntilChanged` has no reset API. | A tiny custom `FlowInstruction` link swapped into the chain. |
| Async `riskOf` | Purity is the lesson; an async policy would require a different test story. | An async operator link before `MapValue`. |
| Rate limiting per card | Out of scope for v1. | `TestTissue` on `holdsMap` keyed on a sliding window. |
| Encryption / signing of ledger | Out of scope for v1. | A custom `Tissue` subtype that signs each row on `add`. |
| Partial capture | The demo captures or voids, not both. | A new decision path plus a `TissueMap` for per-auth amounts. |
| Refund path | The demo never refunds a captured hold. | A `REFUND` decision plus a new `TissueValue` for refunded cents. |
| STIP / stand-in processing | The demo never models the issuer being offline. | A new `Tap` arm + a `TissueValue` for STIP-bound authorizations. |
| Network tokenization | The demo does not model token/PAN separation. | A `TissueMap<String, String>` mapping tokens to PANs, plus a `TestTissue` on PAN shape. |
| 3DS challenge crypto | The demo does not verify a CAVV or a challenge signature. | A `TestCell` on the ACK ingress that rejects unsigned challenges. |
| Velocity window semantics | The demo caches a velocity int. | A `Cell.synthesis` over a rolling window of `AuthAttempt`s. |
| Merchant-level rules | The demo uses one merchant id. | A `TissueMap<String, TestTissue>` keyed on merchant id. |
| Card-level rules | The demo does not track per-card state. | A `TissueMap<String, CardState>` keyed on PAN or token. |

---

## 4. Operator cheat sheet

### 4.1 Common operations

| Want | Call |
|---|---|
| Publish a fresh attempt | `setAmount` / `setMcc` / `setVelocity` / `setPresent`, then `await publishAttempt()` |
| Approve an attempt (after 3DS) | `await ack(authId)` then `placeHold(authId, cents, mid)` |
| Capture a hold | `capture(authId)` |
| Release a hold | `voidHold(authId)` |
| Append an ACK row only | `await ack(authId)` |
| Block a category at runtime | `mccBlock.add('7995')` |
| Unblock a category | `mccBlock.remove('7995')` |
| Inject an issuer failure | `issuerFailOnce = true` before publishing |
| Materialize the chain | `cardAuth.toHandle(source: attemptIn.cell)` (returns `authHandle`; use `authHandle.cell`) |

### 4.2 Inspection

| Want | Read |
|---|---|
| All ledger entries | `ledger` (iterable) |
| Latest ledger entry | `ledger.last` |
| Ledger count | `ledger.length` |
| Open holds | `holdsMap` |
| Open-hold count | `openHoldsCount` |
| Available balance | `available.value` |
| Held balance | `held.value` |
| Captured total | `capturedCents` |
| Compliance view | `ledger.unmodifiable` |
| Attempt count | `attempts` |
| Decline count | `declines` |
| Step-up count | `stepUps` |
| Issuer attempt count | `issuerAttempts` |
| Issuer failure flag | `issuerFailOnce` |
| Blocked MCCs | `mccBlock` |
| Issuer queue depth | `issuerQ.length` |
| Live gate cell | `authCell` (or `authHandle.cell`) |

### 4.3 Inspecting a single ledger entry

A `LedgerEntry` has four fields:

| Field | Meaning |
|---|---|
| `kind` | `DECLINE` / `STEP-UP` / `ACK` / `ISSUER` / `HOLD` / `CAPTURE` / `VOID` |
| `authId` | the authorization the entry refers to (`'ALL'` for `ACK ALL`) |
| `detail` | a human-readable summary |
| `at` | when the entry was committed |

A common query is "find all DECLINEs for MCC 7995":

```dart
final blocked = ledger.where(
  (e) => e.kind == 'DECLINE' && e.detail.contains('mcc=7995'),
);
```

### 4.4 Diagnosing a missing decline

1. **Did the amount reach the policy?**
   Check `setAmount` return value. If `false`, the TestCell rejected it (outside 1..250_000). The cache did **not** update.
2. **Did the MCC reach the policy?**
   Check `setMcc` return value. If `false`, the TestCell rejected it (not 4 digits). The cache did **not** update.
3. **Did the policy return `decline`?**
   Call `riskOf(attempt, mccBlock)` in isolation. It is pure.
4. **Was the previous chain decision already `decline`?**
   Stock `DistinctUntilChanged` suppresses a consecutive duplicate. An intervening `approve` or `stepUp` moves it off `decline`.
5. **Was the attempt actually published?**
   Check that `publishAttempt` returned `true`. A `false` return means no pulse was emitted.

### 4.5 Diagnosing a double decline

If the same attempt declines twice for what looks like one pulse:

- Check that `installGate` was called exactly **once**. A second call constructs a second chain / second `toHandle`, doubling every effect.
- Check that `toHandle` was not called from the ACK observer. ACK must only append its row.
- Check that the same `AuthAttempt` was not published twice with an intervening approve. The chain suppresses only **consecutive** equal decisions.

### 4.6 Diagnosing a missing capture

- Check `holdsMap.containsKey(authId)`. `capture` is a no-op without an open hold.
- Check that the ACK payload was a real auth id, not empty. An empty payload appends `ACK ALL` but does **not** call `placeHold` — so there is nothing to capture.
- Check the `[held]` transition line printed. If absent, the capture did not run.

### 4.7 Diagnosing an orphan hold

If `available.value! + held.value! + capturedCents != 250000`:

- Check the trailer to see the current balances.
- Check `ledger` for the last `HOLD` / `CAPTURE` / `VOID` rows.
- If a `HOLD` is unpaired with a `CAPTURE` or `VOID`, the cents are still in `held`. That is the expected state, not a bug.
- If the invariant is broken **without** an unmatched `HOLD`, an out-of-band balance write was called (the demo does not do this, but a real system might).

### 4.8 Diagnosing a stalled issuer

- Check `issuerQ.length`. A non-zero queue with no `_driveIssuer` activity suggests the pump is stuck.
- Check `issuerAttempts`. If the last `[ledger] ISSUER` line shows a retry, the pump succeeded on the second attempt.
- If no `ISSUER` line appears at all, the `Tap` side effect never enqueued a job — check that the DECLINE passed `Filter`.

### 4.9 Priority of rules

When two clauses of `riskOf` both seem to apply, the earlier clause wins. In order:

1. Blocked MCC + CNP → `decline`.
2. `velocity >= 5` → `decline`.
3. `amountCents >= 50_000` + CNP → `stepUp`.
4. `amountCents >= 100_000` → `stepUp`.
5. Default → `approve`.

A blocked MCC at 200_000 cents and velocity 6 is `decline`, not `stepUp` — clause 1 wins. The order is load-bearing.

### 4.10 Priority of chain links

The chain executes left to right, and each link must pass for the next to run:

1. `MapValue` — always projects a typed `AuthAttempt` into `(attempt, decision)`.
2. `DistinctUntilChanged` — drops a consecutive equal decision.
3. `Filter` — drops `approve` / `none`.
4. `Tap` — side effect only; passes the record through.
5. `MapValue` — projects the record back to `Decision`.

A pulse dropped by link 2 or 3 never reaches the `Tap` book writes.

### 4.11 Priority of money writes

`placeHold` writes in this order:

1. `holdsMap[authId] = Hold(...)`
2. `available.set(before - cents)`
3. `held.set(heldBefore + cents)`
4. `ledger.add(LedgerEntry(kind: 'HOLD', ...))`

If step 2 rejects, step 1 is compensated. If step 3 rejects, steps 1 and 2 are compensated. Step 4 is never reached in either failure case.

`capture` writes in this order:

1. `holdsMap.remove(authId)`
2. `held.set(heldBefore - h.amountCents)`
3. `capturedCents += h.amountCents`
4. `ledger.add(LedgerEntry(kind: 'CAPTURE', ...))`

None of these steps can reject under the current rules.

`voidHold` writes in this order:

1. `holdsMap.remove(authId)`
2. `held.set(heldBefore - h.amountCents)`
3. `available.set(availBefore + h.amountCents)`
4. `ledger.add(LedgerEntry(kind: 'VOID', ...))`

None of these steps can reject under the current rules.

### 4.12 The ACK is not a debit

A common confusion: calling `ack('H-1')` does **not** move money. It only appends an `ACK` row. To move money, the caller must separately invoke `placeHold`, `capture`, or `voidHold`.

The demo wires this explicitly in `main()`. A real system would wire the ACK to the money method via a 3DS callback or an operator console.

### 4.13 Idempotence

`capture` and `voidHold` are idempotent on the "already done" side:

- A second `capture('H-1')` after a successful capture returns `false` and does not touch the books.
- A second `voidHold('H-1')` after a successful void returns `false` and does not touch the books.

This is safe: the method's job is not to enforce that a hold exists, but to move the cents if it does.

---

## 5. Acceptance checklist

The demo is done when **all** of the following hold:

1. `dart run card-auth-pipeline(Cell)-Demo.dart` matches the scenario **Result** column in `card-auth-pipeline(Cell)-WalkThrough.md`.
2. Exactly **one** `toHandle(` call exists for the risk gate, inside `installGate`. Zero in ACK. Zero anywhere else.
3. `riskOf` contains no `await`, no `available.set`, no `held.set`, no `ledger.add`, no `holdsMap[...] =`, no `issuerQ.addLast`.
4. Scenario 2 mutates `mccBlock` **before** the blocked CNP attempt is published.
5. Scenario 8 prints both TestCell rejections and appends zero rows to `ledger`.
6. Scenario 9 shows a retry in `issuerAttempts` while still producing exactly **one** new DECLINE pulse.
7. Scenarios 10–13 keep the invariant `available.value! + held.value! + capturedCents == 250000`.
8. COMPLY shows the read-only deputy blocked on `add` and live on `length`.
9. The Dart file's header diagram matches the architecture note.
10. No Dart `List<LedgerEntry>` is used as the system of record. The `_issuerWork` list is a pump queue, not a ledger.
11. Every `TissueList` / `TissueSet` / `TissueMap` / `TissueQueue` / `TissueValue` / `.deputy(` in the demo passes **`TestTissue`** (or omits the argument and takes `TestTissue.allowAll`). Grep must show **zero** `testRule: TestCell` on those calls.
12. The trailer's counts match `attempts=13 declines=4 stepUps=2 ledger=17 issuerAttempts=5` and `available=190000 held=0 openHolds=0 captured=60000`.
13. `auditor.length == ledger.length` in the COMPLY step.
14. Only **one** `toHandle` exists across the whole demo (`cardAuth` in `installGate`). ACK does not call `toHandle`.
15. `placeHold` / `capture` / `voidHold` are the only functions that write `available`, `held`, and `holdsMap`. No observer writes them.
16. The three money methods are called by the caller (`main()`), not by any observer.
17. `capture` and `voidHold` are idempotent on the "already done" side. A second call returns `false` without touching the books.
18. The chain is built from stock operators with `+`: `MapValue → DistinctUntilChanged → Filter → Tap → MapValue`.
19. The `Tap` link is the only chain link that writes Tissue; `MapValue` and `Filter` stay side-effect free.

---

## 6. See also

| File | Purpose |
|---|---|
| `card-auth-pipeline(Cell)-Demo.dart` | Executable implementation. |
| `card-auth-pipeline(Cell)-WalkThrough.md` | Requirement document and scenario contract. |
| `card-auth-pipeline(Cell)-ARCHITECTURE.md` | Layering, ownership, locking, failure semantics, anti-patterns. |
| `grid-demand-response(tissue)-Demo.dart` | Energy sibling — same graph shape, different domain. |
| `ride-hail-dispatch(tissue)-Demo.dart` | Mobility sibling. |
| `ICU-alarm-pipeline(enhanced)-Demo.dart` | Clinical sibling. |
