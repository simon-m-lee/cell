# Walkthrough requirement — card auth pipeline (Flow + Tissue)

**Demo:** `card-auth-pipeline(tissue)-Demo.dart` (executable; this file is its requirement)  
**Siblings:**  
- `card-auth-pipeline(enhanced)-WalkThrough.md` — Flow only, Dart `List` ledger  
- `ICU-alarm-pipeline(enhanced)-Demo.dart` — same gate shape, clinical payload  

**Industry:** card / e-com authorization, risk hold, available-balance ledger, compliance view  
**Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`

This is the **executable requirement** for a fintech demo that uses
**Flow for the decision** and **Tissue for the books**. Implement the
Dart file so a last-good run prints the scenario table in § Scenarios.

Do not fold Tissue into the Receptor. Do not fold Flow into the ledger.
The point of this file is the seam.

---

## Contents

1. [TestCell vs TestTissue (do not swap)](#testcell-vs-testtissue-do-not-swap)
2. [Why Flow + Tissue (not Flow alone)](#why-flow--tissue-not-flow-alone)
3. [Design](#design)
4. [Domain](#domain)
5. [Parts](#parts)
   - [Flow Cells](#flow-cells-same-as-the-enhanced-walkthrough)
   - [Tissue collections](#tissue-collections-this-demos-new-surface)
   - [Deputies](#deputies)
   - [Instruction](#instruction-flow-unchanged-contract)
   - [Receptor](#receptor)
   - [Operators the demo must actually call](#operators-the-demo-must-actually-call)
6. [Money — TissueValue + TissueMap](#money--tissuevalue--tissuemap-not-celltransaction)
7. [Implementation map](#implementation-map)
8. [Scenarios (what the last good run must show)](#scenarios-what-the-last-good-run-must-show)
9. [Executable steps (Seed + 1–13 + STEP-UP + COMPLY)](#executable-steps-seed--113--step-up--comply)
10. [Pulse path (scenario 2)](#pulse-path-scenario-2)
11. [Who owns the lock](#who-owns-the-lock)
12. [Real rail vs this file](#real-rail-vs-this-file)
13. [Acceptance](#acceptance-the-demo-is-done-when)
14. [Name plate](#name-plate)

---

## TestCell vs TestTissue (do not swap)

Collection classes in `package:cell_tissue` take **`TestTissue`**, never
`TestCell`. `TestCell` is the integrity rule on a **Cell** (ingress /
handle). `TestTissue` is the integrity rule on a **Tissue** (`add`,
`remove`, `[]=`, value write). They are not subtypes you can pass
across that seam.

| Host | Rule type | Parameter | Typical use in this demo |
|---|---|---|---|
| `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` | amount 1–250_000¢, MCC shape |
| `TissueList` / `Set` / `Map` / `Queue` / `Value` | `TestTissue<E, C>` | `testRule:` | append-only ledger, non-negative cents, 4-digit blocklist |
| `tissue.deputy(...)` | `TestTissue` | `testRule:` | `TestTissue.readOnly` for compliance |
| `TestTissue.allowAll` | `TestTissue` | default | only when the collection has no extra rule |

Illegal (will not type-check, do not write it):

```dart
TissueList<LedgerEntry>(testRule: TestCell.allowAll);        // wrong type
TissueValue<int>(250000, testRule: amountRange);            // amountRange is TestCell
ledger.deputy(testRule: TestCell.readOnly);                 // deputy wants TestTissue
```

Required shape:

```dart
final ledgerRule = TestTissue<LedgerEntry, TissueList<LedgerEntry>>(
  (e, {host, action, user}) => e.kind.isNotEmpty,
  // action hook: allow add / addAll; deny remove, clear, []=
);

final ledger = TissueList<LedgerEntry>(testRule: ledgerRule);

final centsRule = TestTissue<int, TissueValue<int>>(
  (v, {host, action, user}) => v != null && v >= 0,
);

final available = TissueValue<int>(250000, testRule: centsRule);

final mccBlock = TissueSet<String>(
  testRule: TestTissue<String, TissueSet<String>>(
    (mcc, {host, action, user}) =>
        mcc.length == 4 && int.tryParse(mcc) != null,
  ),
);

final auditor = ledger.deputy(testRule: TestTissue.readOnly);
```

`Cell.ingress(testRule: amountRange)` stays **`TestCell`**. That rule
never becomes the `testRule` on `available` / `ledger` / `mccBlock`.

Compose Tissue rules with `+` (`TestTissue.allowAll + custom`), not by
wrapping a `TestCell`.

---

## Why Flow + Tissue (not Flow alone)

The enhanced Flow walkthrough already owns:

- TestCell on amount / MCC ingress
- one `AuthAttempt` snapshot bus
- DECLINE vs STEP-UP as two Receptors
- Distinct-before-Filter and ACK that resets Distinct **on the same handle**
- `AsyncMapWithRetry` off the graph for the issuer

What it still fakes with Dart objects:

| Fake in the Flow-only demo | Real owner in this demo |
|---|---|
| `List<LedgerEntry> ledger` | `TissueList<LedgerEntry>` — append-only, observable |
| `Cell.state<int> available / holds` | `TissueValue<int>` — validated cents, `ElementUpdated` |
| open-hold table in a Map | `TissueMap<String, Hold>` — keyed by auth id |
| MCC blocklist `const` | `TissueSet<String>` — ops can add a code without redeploy |
| issuer retry buffer | `TissueQueue<IssuerJob>` — bounded outbound |
| “print the ledger for audit” | `ledger.unmodifiable` / `deputy(testRule: TestTissue.readOnly)` |

Tissue is a **Cell that is a collection**. Every `add` / `update` /
`[]=` goes through `TestTissue`, takes the tissue lock, and emits a
`TissuePulse` (`ElementAdded`, `ElementRemoved`, `ElementUpdated`).
That is the audit trail. Flow never stores money.

---

## Design

```
amountIn   TestCell 1–250_000¢  ─┐
mccIn      TestCell 4-digit MCC ─┼─ set* → publishAttempt
velocityIn                      ─┤         → AuthAttempt(...)
presentIn                       ─┘
                                      │
                                      ▼
                                 attemptIn          Flow
                        ┌─────────────┴─────────────┐
                        ▼                           ▼
                  decline gate                 stepUp gate
             MapValue + Distinct            MapValue + Distinct
                  + Filter(decline)              + Filter(stepUp)
                        │                           ▼
                        │                      stepUpHandle
                        ▼
                  declineHandle
                        │
                        ├─ observe DECLINE
                        │     ledger.add(...)              TissueList
                        │     issuerQ.addLast(job)         TissueQueue
                        └─ AsyncMapWithRetry ← issuerQ
                              issuerHandle

ackIn  3DS / analyst ── resetDistinct()
                         on approve-after-ACK:
                           holdsMap[authId] = Hold(...)    TissueMap
                           available.value -= cents        TissueValue
                           held.value     += cents         TissueValue

compliance ──────────── ledger.unmodifiable                Deputy
opsBlocklist ────────── mccBlock.add('7995')               TissueSet
```

| Requirement | Owner |
|---|---|
| Impossible amount / MCC **shape** | `TestCell` on ingress Cells |
| Blocked MCC **policy** | `TissueSet<String> mccBlock` + `riskOf` reads it |
| One attempt per tick | `publishAttempt` bus |
| DECLINE vs STEP-UP | two Flow Receptors, same `riskOf` |
| No duplicate DECLINE | Distinct **before** Filter; ACK clears last |
| Issuer I/O | `TissueQueue` + `AsyncMapWithRetry` |
| Audit log | `TissueList<LedgerEntry>` + `TestTissue` append-only |
| Available / held cents | two `TissueValue<int>` + non-negative `TestTissue` |
| Open authorizations | `TissueMap<String, Hold>` |
| Compliance screen | `ledger.unmodifiable` (live, zero-copy) |
| Do not stack graphs | ACK does **not** call `toHandle` again |

Do **not** `ledger.add` inside `MapValue`. The Receptor returns a
`Decision`. The observer writes Tissue. If you mutate Tissue inside
`+`, you hide the lock and you cannot unit-test `riskOf` with a Pulse.

Do **not** replace Distinct with “ledger already has this attempt.”
The ledger is history. Distinct is the **current alarm latch**. ACK
clears the latch; it never deletes ledger rows.

---

## Domain

```dart
enum Decision { none, approve, stepUp, decline }

enum Presentment { cardPresent, cardNotPresent }

final class AuthAttempt {
  const AuthAttempt({
    required this.authId,
    required this.mid,
    required this.amountCents,
    required this.mcc,
    required this.velocity,
    required this.presentment,
  });
  final String authId;
  final String mid;
  final int amountCents;
  final String mcc;
  final int velocity;
  final Presentment presentment;
}

final class LedgerEntry {
  const LedgerEntry({
    required this.kind, // DECLINE | STEP-UP | APPROVE | ACK | HOLD | CAPTURE | VOID | ISSUER
    required this.authId,
    required this.detail,
    required this.at,
  });
  final String kind;
  final String authId;
  final String detail;
  final DateTime at;
}

final class Hold {
  const Hold({
    required this.authId,
    required this.amountCents,
    required this.mid,
  });
  final String authId;
  final int amountCents;
  final String mid;
}

final class IssuerJob {
  const IssuerJob({required this.authId, required this.decision});
  final String authId;
  final Decision decision;
}
```

Suggested `riskOf(AuthAttempt a, Set<String> blocked) → Decision`:

| Condition | Decision |
|---|---|
| `a.mcc` in `mccBlock` and CNP | `decline` |
| `a.velocity >= 5` | `decline` |
| `a.amountCents >= 50_000` and CNP | `stepUp` |
| `a.amountCents >= 100_000` | `stepUp` |
| else | `approve` (both gates Filter this away; Distinct sees it as reset fuel) |

`mccBlock` is a TissueSet the demo **mutates in scenario 2** so the
talk track can say “ops listed 7995; the next CNP grocery-looking
attempt is still grocery until the set contains 7995.” Seed the set
empty. Scenario 2 does `mccBlock.add('7995')` then republishes.

Amount bounds (1…250_000) stay on **TestCell**. Blocklist membership
stays on **TissueSet**. Do not merge them into one predicate.

---

## Parts

### Flow Cells (same as the enhanced walkthrough)

| Cell | Kind | Role |
|---|---|---|
| `amountIn` | ingress + TestCell | reject `0`, `-1`, `1_000_000_000` |
| `mccIn` | ingress + TestCell | reject `"99"`, `"ABCD"` |
| `velocityIn` / `presentIn` | ingress | cache fields |
| `attemptIn` | ingress `<AuthAttempt>` | snapshot bus |
| `ackIn` | ingress `<String>` | who cleared 3DS / analyst (`authId` or `"ALL"`) |
| `declineHandle.cell` | `toHandle` | DECLINE only |
| `stepUpHandle.cell` | `toHandle` | STEP-UP only |
| `issuerHandle.cell` | `AsyncMapWithRetry` | I/O with `count: 2` |

`_amount` / `_mcc` / `_velocity` / `_present` remain a Dart cache.
`setAmount` returns false and does **not** call `publishAttempt` when
TestCell rejects.

### Tissue collections (this demo’s new surface)

| Tissue | Type | `TestTissue` | Who writes | Who reads |
|---|---|---|---|---|
| `ledger` | `TissueList<LedgerEntry>` | append-only: allow `add` / `addAll`; deny `remove`, `clear`, `[]=` | gate observers, hold/capture | compliance deputy |
| `available` | `TissueValue<int>` | `v != null && v >= 0` | hold / capture / void | till, risk talk-track |
| `held` | `TissueValue<int>` | `v != null && v >= 0` | hold / capture / void | till |
| `holdsMap` | `TissueMap<String, Hold>` | value cents `> 0`; key non-empty | ACK-approve, capture, void | settlement |
| `mccBlock` | `TissueSet<String>` | 4-digit MCC string | ops scenario | `riskOf` |
| `issuerQ` | `TissueQueue<IssuerJob>` | `capacity: 32` | decline/step-up observer | issuer pump |

Seed with **TestTissue on every collection** (see constructors above).
`available = TissueValue<int>(250000, testRule: centsRule)`,
`held = TissueValue<int>(0, testRule: centsRule)`,
`holdsMap` / `mccBlock` / `ledger` / `issuerQ` each constructed with
their `TestTissue`, not `TestCell`. Initial population is silent —
observers only see **post-create** mutations.

### Deputies

```dart
final books = ledger.unmodifiable;           // live, zero-copy
final auditor = ledger.deputy(
  testRule: TestTissue.readOnly,
);
```

Scenario “compliance” must show:

1. `auditor.add(...)` throws / is blocked.
2. After a DECLINE, `auditor.length` is already `ledger.length`.
3. No copy was taken — `identical` storage is the lesson, not a
   `List.from`.

Do **not** pass the writable `ledger` to the “UI” printer. Print from
`books` / `auditor` so the talk track has a reason to mention Deputy.

### Instruction (Flow, unchanged contract)

| Stage | Type |
|---|---|
| `MapValue<AuthAttempt, Decision>` | `riskOf(attempt, mccBlock.toSet())` |
| `_distinctDecline` / `_distinctStepUp` | closured last; ACK zeroes it |
| `Filter<Decision>(decline)` / `stepUp` | drop the other decisions |

`riskOf` may **read** `mccBlock`. It must not `add` to it.

Order is mandatory: `riskOf → Distinct → Filter`.

Library `DistinctUntilChanged` is not used: ACK cannot reset it
without a new handle.

### Receptor

`buildDeclineGate().toHandle(source: attemptIn.cell)` once at
`installGates()`. Same for STEP-UP. One lock per gate.

Tissue has its **own** lock on each collection. Do not assume the
Receptor lock covers `ledger.add`. That is why the observer does the
write: two locks, two owners, two talk-track sentences.

### Operators the demo must actually call

Flow: `MapValue`, `Filter`, custom Distinct `FlowInstruction`,
`AsyncMapWithRetry` (`count`, not `retries`), `Cell.observe`,
`Cell.ingress(testRule:)`.

Tissue: `TissueList.of` / `TissueList()`, `TissueValue`, `TissueMap`,
`TissueSet`, `TissueQueue`, `TestTissue(...)`, `TestTissue.readOnly`,
`.unmodifiable`, `.deputy(...)`, `.listen` / `Cell.observe` on the
tissue (tissues **are** Cells).

Prefer observing Tissue with:

```dart
ledger.listen((TissuePulse e) {
  if (e is ElementAdded<LedgerEntry>) {
    print('[ledger] ${e.payload.kind} ${e.payload.authId}');
  }
});
```

and values with `ElementUpdated` (payload is `ElementUpdatedRecord`).
If the demo harness only has `Cell.observe`, that is acceptable —
print `pulse.payload` and tag `[available]` / `[held]`.

---

## Money — TissueValue + TissueMap, not Cell.transaction

The Flow-only doc used `Cell.transaction` because `Cell.state` has no
collection pulse. Here the books **are** tissues. A hold is three
mutations that must stay consistent:

```text
holdsMap[authId] = Hold(...)
available.value = available.value! - cents
held.value      = held.value! + cents
ledger.add(LedgerEntry(kind: 'HOLD', ...))
```

**v1 requirement (must implement):** perform the three writes in one
dart `Future` on the ACK/approve observer. If `available` TestTissue
rejects (would go negative), **do not** leave a map row behind —
remove the map entry and do not append HOLD.

**v1 invariant after every successful money method:**

```
available.value! + held.value! + capturedCents == 250000
```

`capturedCents` is a running int in the harness (consumed sales).
After a void, `capturedCents` is unchanged and the cents return
`held → available`.

**v2 (optional, do not block the demo):** wrap the three writes in
`Cell.transaction` **and** Tissue updates if the running cell_tissue
build exposes a joint commit. If it does not, stay on the v1
try/compensate in the observer and say so in the file header.

Never debit inside `riskOf`.

---

## Implementation map

| Block in the dart file | What |
|---|---|
| Architecture / expected output comments | talk track |
| `AuthAttempt` / `Decision` / `LedgerEntry` / `Hold` / `IssuerJob` | domain |
| `amountRange` / `mccShape` | TestCell on Cells |
| `mccBlock` TissueSet + `ledger` TestTissue append-only | Tissue policy |
| `publishAttempt` / `set*` | bus |
| `riskOf(attempt, mccBlock)` | Flow policy, reads TissueSet |
| `_distinctDecline` + `resetDistinct` | ACK / 3DS |
| `installGates` | two Receptors + issuer + observes |
| `placeHold` / `capture` / `voidHold` | TissueValue + TissueMap |
| `main` | seed + scenarios 1–13 |

`installGates` runs **once**. ACK only touches Distinct fields and
then calls `placeHold` when the talk track says “approve after 3DS.”

---

## Scenarios (what the last good run must show)

Seed merchant `M-4419`, `available=250000`, `held=0`, card-present,
amount `7200`, MCC `5411`, velocity `0`, `mccBlock` empty.

| # | Drive | Result | Demonstrates |
|---|---|---|---|
| Seed | 7200 / 5411 / present / vel 0 | one attempt, **no** DECLINE, ledger still empty | bus + Filter; initial Tissue is silent |
| 1 | repeat 7200 / 5411 | no DECLINE | Distinct on `approve` |
| 2 | `mccBlock.add('7995')`, then MCC 7995 CNP 7200 | **DECLINE** + `ElementAdded` on ledger + `issuerQ.addLast` | TissueSet feeds `riskOf`; list pulse is the audit |
| 3 | grocery+present then 7995 CNP again | **DECLINE** after recover | Distinct `none`→`decline` |
| 4–5 | 7995 again, then 200000 on 7995 | **no** new DECLINE | Distinct holds; ledger does **not** grow |
| STEP-UP | 60000 CNP 5411 | **STEP-UP** + ledger row | second Receptor; blocklist does not apply to 5411 |
| 6 | 7200 / 5411 present then ACK | Distinct cleared; no money yet | ACK ≠ new `toHandle` |
| 7 | 7995 CNP 7200 | **one** DECLINE | reset Distinct |
| 8 | amount `-1`, MCC `"99"` | TestCell lines; **no** attempt; ledger unchanged | Cell ingress ≠ Tissue |
| 9 | ACK, recover, 7995, issuer fail-once | **one** DECLINE; `issuerAttempts` includes retry | queue + `AsyncMapWithRetry` |
| 10 | STEP-UP 60000, ACK as approve, `placeHold` | `available=190000`, `held=60000`, `holdsMap` has one row, ledger `HOLD` | TissueValue + TissueMap |
| 11 | `placeHold(200000)` while 10 is open | NSF / TestTissue reject; map row count stays 1 | non-negative rule |
| 12 | `capture` the 60000 hold | `held=0`, `available=190000`, map empty, ledger `CAPTURE` | capture ≠ second debit |
| 13 | new 10000 hold then `voidHold` | available back to `190000`, ledger `VOID` | compensate on Tissue |
| COMPLY | `auditor.add(...)` | blocked; `auditor.length == ledger.length` | Deputy / `unmodifiable` is live |

Good-run counts from the executable trailer:

```text
attempts=13 declines=4 stepUps=2 ledger=17 issuerAttempts=5
available=190000 held=0 openHolds=0 captured=60000
auditorLength=17 (same as ledger)
invariant available+held+captured = 250000 (expected 250000)
```

Four DECLINE pulses: scenarios **2**, **3b**, **7**, **9b**.
Two STEP-UP pulses: **SU-1** and **H-1**. Ledger 17 is
DECLINE/ISSUER/ACK/HOLD/CAPTURE/VOID rows only — Seed and approve
attempts never append. `issuerAttempts=5` because scenario 9
fails the first issuer call and retries.

Print that trailer. Numbers in § Executable steps must match it.

---

## Executable steps (Seed + 1–13 + STEP-UP + COMPLY)

These are the steps `card-auth-pipeline(tissue)-Demo.dart` actually
runs. Numbers match the `── N ──` banners in the console. Seed is
unnumbered but required: without it Distinct has no first
`approve`, and “repeat does not decline” in step 1 is meaningless.

**Seam reminder at every step.** Flow answers “may this attempt
become a DECLINE or STEP-UP pulse?” Tissue answers “what did the
books just record, and did money move?” The observer is the only
glue. `riskOf` never writes `available`. `placeHold` never runs
inside the Receptor.

**Documented deviations the executable takes** (header of the demo):

- Tissue constructors: `TissueSet` / `TissueValue` take the initial
  value as the **first positional** argument; `TissueMap` puts
  `testRule` on the nucleus via `properties:`.
- Each `TestCell` unwraps `Pulse.payload` before the shape check.
- Issuer pump: `issuerQ.addLast` is the audit enqueue;
  `_issuerWork` + `_driveIssuer` is the retry list (this build’s
  `TissueQueue` does not drain via `removeFirst`).
- Trace prints come from the writers themselves. Tissue-cell
  `Cell.observe` is silent in this build.

Money invariant after every successful money method:

```
available.value + held.value + capturedCents == 250000
```

---

### Seed — 7200 / 5411 / present / vel 0

**Lesson:** snapshot bus + Filter. Initial Tissue population is
silent.

**Drive**

```dart
h.setAmount(7200);
h.setMcc('5411');
h.setVelocity(0);
h.setPresent(Presentment.cardPresent);
await h.publishAttempt(authId: 'SEED');
```

**What fires**

- `amountIn` TestCell accepts `7200` (1..250_000¢).
- `mccIn` TestCell accepts `'5411'` (exactly 4 digits).
- `publishAttempt` emits `AuthAttempt(SEED, 7200¢, 5411, present)`.
- Both gates run `riskOf` → `approve`. Distinct records `approve`.
  Filter(decline) and Filter(stepUp) both drop.
- Ledger is still empty: Seed does not append, and the initial
  `available=250000` / `held=0` writes were constructor-time
  (observers never saw them).

**Must print**

```text
── Seed ── 7200 / 5411 / present / vel 0
  ledger.isEmpty=true
```

**Must not happen**

- No `[ledger] DECLINE` / `STEP-UP`.
- No issuer enqueue.
- No money movement.

---

### Step 1 — repeat 7200 / 5411

**Lesson:** Distinct on `approve`. The DECLINE gate never sees
`approve` as a fireable decision, and Distinct would drop a
repeat anyway.

**Drive**

```dart
await h.publishAttempt(authId: '1');
```

**What fires**

- Same snapshot as Seed. `riskOf` → `approve` again.
- `_distinctDecline` / `_distinctStepUp` already hold `approve`
  → both return `null`.
- `h.declines` does not increment.

**Must print**

```text
── 1 ── repeat 7200 / 5411
  new declines: 0
```

---

### Step 2 — ops adds 7995, then MCC 7995 CNP 7200

**Lesson:** TissueSet feeds `riskOf`. The DECLINE observer is the
audit trail. Two locks: Receptor then TissueList / TissueQueue.

**Drive**

```dart
h.mccBlock.add('7995');
h.setAmount(7200);
h.setMcc('7995');
h.setVelocity(0);
h.setPresent(Presentment.cardNotPresent);
await h.publishAttempt(authId: '2');
```

**What fires**

1. `mccBlock.add('7995')` — `TestTissue` on the set accepts a
   4-digit MCC. This is **not** a Flow pulse.
2. `publishAttempt('2')` — CNP + blocked MCC → `riskOf` =
   `decline`.
3. DECLINE Distinct was `approve` → emits `decline`. Filter
   passes. STEP-UP Filter drops.
4. DECLINE observer: `ledger.add(DECLINE 2)`,
   `issuerQ.addLast(IssuerJob(2, decline))`, `_driveIssuer`.
5. Issuer pump succeeds on the first try → `ledger.add(ISSUER 2)`.

**Must print**

```text
── 2 ── mccBlock.add('7995'), then MCC 7995 CNP 7200
[mccBlock] +7995
[ledger] DECLINE 2 — mcc=7995 amount=7200¢
[issuerQ] enqueued IssuerJob(2, decline)
[ledger] ISSUER 2 — decline
  new declines: 1
  issuerQ.length=1
```

**Must not happen**

- No `available` / `held` write. Decline does not move money.
- No second `toHandle`.

---

### Step 3 — grocery+present then 7995 CNP again

**Lesson:** Distinct `approve` → `decline`. Recovering to grocery
present is what lets the next blocked CNP fire again.

**Drive**

```dart
h.setAmount(7200);
h.setMcc('5411');
h.setPresent(Presentment.cardPresent);
await h.publishAttempt(authId: '3a');
h.setMcc('7995');
h.setPresent(Presentment.cardNotPresent);
await h.publishAttempt(authId: '3b');
```

**What fires**

- `3a` grocery present → `approve`. DECLINE Distinct moves off
  `decline` to `approve` (Filter still drops approve).
- `3b` 7995 CNP → `decline`. Distinct `approve` → `decline` →
  emit. Observer appends DECLINE 3b + ISSUER 3b.

**Must print**

```text
── 3 ── grocery+present then 7995 CNP again
[ledger] DECLINE 3b — mcc=7995 amount=7200¢
[issuerQ] enqueued IssuerJob(3b, decline)
[ledger] ISSUER 3b — decline
  new declines: 1
```

`3a` itself must not print a DECLINE row.

---

### Step 4 — 7995 again (should not re-decline)

**Lesson:** Distinct holds `decline`. Same decision, same latch.

**Drive**

```dart
await h.publishAttempt(authId: '4');
```

**Must print**

```text
── 4 ── 7995 again (should not re-decline)
  new declines: 0
```

Ledger does not grow. Issuer does not enqueue.

---

### Step 5 — 200000 on 7995

**Lesson:** Distinct keys on **Decision**, not amount. Raising
cents does not create a new decline while the latch is still
`decline`.

**Drive**

```dart
h.setAmount(200000);
await h.publishAttempt(authId: '5');
```

**Must print**

```text
── 5 ── 200000 on 7995
  new declines: 0
```

Even though 200000 CNP would also be `stepUp` on an unblocked MCC,
7995 + CNP is still `decline` first in `riskOf`. The STEP-UP gate
never sees it.

---

### STEP-UP — 60000 CNP 5411

**Lesson:** second Receptor, independent Distinct. Blocklist does
not apply to 5411.

**Drive**

```dart
h.setAmount(60000);
h.setMcc('5411');
h.setVelocity(0);
h.setPresent(Presentment.cardNotPresent);
await h.publishAttempt(authId: 'SU-1');
```

**What fires**

- `riskOf`: 5411 not in `mccBlock`; amount ≥ 50_000 and CNP →
  `stepUp`.
- STEP-UP Distinct was `approve` (from earlier grocery) → emit.
  Filter(stepUp) passes. DECLINE Filter drops.
- STEP-UP observer appends `STEP-UP SU-1`. No issuer job (this
  demo only enqueues on DECLINE).

**Must print**

```text
── STEP-UP ── 60000 CNP 5411
[ledger] STEP-UP SU-1 — amount=60000¢ CNP
  new step-ups: 1
```

**Must not happen**

- No `placeHold` here. STEP-UP is a decision, not a debit.
- `available` stays 250000.

---

### Step 6 — 7200 / 5411 present then ACK

**Lesson:** ACK clears both Distinct latches on the **same**
Receptors. No money yet.

**Drive**

```dart
h.setAmount(7200);
h.setMcc('5411');
h.setPresent(Presentment.cardPresent);
await h.publishAttempt(authId: '6');
await h.ack('6');
```

**What fires**

- Attempt 6 is `approve` — both Filters drop.
- `ackIn` observer: `resetDistinct()` zeroes `_lastDecline` and
  `_lastStepUp`, then appends `ACK 6`.

**Must print**

```text
── 6 ── 7200 / 5411 present then ACK
[ledger] ACK 6 — distinct cleared
  available=250000 held=0
```

ACK is **not** `toHandle` again. A second handle would double
every later DECLINE.

---

### Step 7 — 7995 CNP 7200

**Lesson:** after ACK the same decline is a **new** pulse.

**Drive**

```dart
h.setMcc('7995');
h.setPresent(Presentment.cardNotPresent);
await h.publishAttempt(authId: '7');
```

**Must print**

```text
── 7 ── 7995 CNP 7200
[ledger] DECLINE 7 — mcc=7995 amount=7200¢
[issuerQ] enqueued IssuerJob(7, decline)
[ledger] ISSUER 7 — decline
  new declines: 1
```

This is DECLINE pulse #3 (2, 3b, 7).

---

### Step 8 — amount -1, MCC `"99"` (TestCell)

**Lesson:** Cell ingress ≠ Tissue. Shape dies at the edge. The
ledger never hears about a pulse that was not published.

**Drive**

```dart
final rejectedAmount = h.setAmount(-1);
final rejectedMcc = h.setMcc('99');
```

**What fires**

- `_amountShape` unwraps `Pulse.payload`, sees `-1`, returns
  `false`. `_amount` cache is **not** overwritten.
- `_mccShapeRule` rejects `"99"` (not 4 digits). `_mcc` stays
  `'7995'`.
- `publishAttempt` is **not** called. Tissue idle.

**Must print**

```text
── 8 ── amount -1, MCC "99"
  amount -1 accepted=false
  mcc "99" accepted=false
  ledger grew: 0
```

**Must not happen**

- No `TestTissue` involvement.
- No `[ingress]` lines required if `setAmount` / `setMcc` swallow
  the rejection (the executable reports via the accepted flags).

---

### Step 9 — ACK, recover, 7995, issuer fail-once

**Lesson:** queue + retry. One DECLINE pulse, two issuer attempts.

**Drive**

```dart
await h.ack('9-pre');
h.setMcc('5411');
h.setPresent(Presentment.cardPresent);
h.setAmount(7200);
await h.publishAttempt(authId: '9a');
h.setMcc('7995');
h.setPresent(Presentment.cardNotPresent);
h.issuerFailOnce = true;
await h.publishAttempt(authId: '9b');
```

**What fires**

- ACK 9-pre clears Distinct again.
- `9a` grocery present → approve (resets latch to approve).
- `9b` 7995 CNP → DECLINE 9b + enqueue. `_driveIssuer` throws
  once (`issuerFailOnce`), then retries and appends
  `ISSUER 9b — decline (retry)`.
- `issuerAttempts` ends at 5: prior successful issuer calls
  (2, 3b, 7) plus fail + retry on 9b.

**Must print**

```text
── 9 ── ACK, recover, 7995, issuer fail-once
[ledger] ACK 9-pre — distinct cleared
[ledger] DECLINE 9b — mcc=7995 amount=7200¢
[issuerQ] enqueued IssuerJob(9b, decline)
[ledger] ISSUER 9b — decline (retry)
  new declines: 1
  issuerAttempts=5
```

DECLINE pulse count for this step is **1**. The retry is issuer
I/O, not a second Receptor fire.

---

### Step 10 — STEP-UP 60000, ACK as approve, placeHold

**Lesson:** TissueValue + TissueMap. Decision and debit are
separate moments.

**Drive**

```dart
h.setAmount(60000);
h.setMcc('5411');
h.setVelocity(0);
h.setPresent(Presentment.cardNotPresent);
await h.publishAttempt(authId: 'H-1');
await h.ack('H-1');
final ok10 = h.placeHold('H-1', 60000, 'M-4419');
```

**What fires**

- `riskOf` → `stepUp` (60000 CNP 5411). STEP-UP observer appends
  `STEP-UP H-1`.
- ACK clears Distinct and appends `ACK H-1`.
- `placeHold` v1 protocol:
  1. NSF check: 250000 ≥ 60000.
  2. `holdsMap['H-1'] = Hold(...)`.
  3. `available.set(190000)` — print `[available]`.
  4. `held.set(60000)` — print `[held]`.
  5. `ledger.add(HOLD H-1)`.

**Must print**

```text
── 10 ── STEP-UP 60000, ACK as approve, placeHold
[ledger] STEP-UP H-1 — amount=60000¢ CNP
[ledger] ACK H-1 — distinct cleared
[available] 250000 → 190000
[held] 0 → 60000
[ledger] HOLD H-1 — 60000¢
  placeHold ok=true
  available=190000 held=60000 openHolds=1
```

Invariant: 190000 + 60000 + 0 = 250000.

**Must not happen**

- `riskOf` must not call `placeHold`.
- `available` must not move during the STEP-UP pulse itself —
  only inside `placeHold` after ACK.

---

### Step 11 — placeHold(200000) while 10 is open (NSF)

**Lesson:** non-negative / NSF guard. No orphan map row.

**Drive**

```dart
final ok11 = h.placeHold('H-2', 200000, 'M-4419');
```

**What fires**

- `available` is 190000 < 200000 → `placeHold` returns `false`
  **before** writing the map.
- `openHolds` stays 1 (`H-1` only).

**Must print**

```text
── 11 ── placeHold(200000) while 10 is open
  placeHold ok=false openHolds stayed=true
```

No `[available]`, no `[held]`, no `HOLD H-2` row.

---

### Step 12 — capture the 60000 hold

**Lesson:** capture ≠ second debit. Cents leave `held` into
`capturedCents`. `available` does not move.

**Drive**

```dart
final ok12 = h.capture('H-1');
```

**What fires**

1. Look up `holdsMap['H-1']`.
2. Remove the map row.
3. `held.set(0)` — print `[held] 60000 → 0`.
4. `capturedCents += 60000`.
5. `ledger.add(CAPTURE H-1)`.

**Must print**

```text
── 12 ── capture the 60000 hold
[held] 60000 → 0
[ledger] CAPTURE H-1 — 60000¢
  capture ok=true
  available=190000 held=0 openHolds=0 captured=60000
```

Invariant: 190000 + 0 + 60000 = 250000.

---

### Step 13 — new 10000 hold then voidHold

**Lesson:** compensate on Tissue. Void returns cents from `held`
to `available`. Sale was never captured.

**Drive**

```dart
final ok13a = h.placeHold('H-3', 10000, 'M-4419');
final ok13b = h.voidHold('H-3');
```

**What fires**

- `placeHold('H-3', 10000)`:
  - `[available] 190000 → 180000`
  - `[held] 0 → 10000`
  - `[ledger] HOLD H-3 — 10000¢`
- `voidHold('H-3')`:
  - remove map row
  - `[held] 10000 → 0`
  - `[available] 180000 → 190000`
  - `[ledger] VOID H-3 — 10000¢`
  - `capturedCents` unchanged at 60000

**Must print**

```text
── 13 ── new 10000 hold then voidHold
[available] 190000 → 180000
[held] 0 → 10000
[ledger] HOLD H-3 — 10000¢
[held] 10000 → 0
[available] 180000 → 190000
[ledger] VOID H-3 — 10000¢
  placeHold ok=true voidHold ok=true
  available=190000 held=0 openHolds=0
```

Invariant: 190000 + 0 + 60000 = 250000.

---

### COMPLY — auditor.add blocked; length == ledger.length

**Lesson:** `ledger.unmodifiable` is a live, zero-copy deputy.
Writes are blocked (throw **or** silent swallow). Reads share
storage.

**Drive**

```dart
final auditor = h.ledger.unmodifiable;
final ledgerBefore = h.ledger.length;
auditor.add(LedgerEntry(kind: 'HACK', ...));
blocked = h.ledger.length == ledgerBefore; // or catch
```

**What fires**

- `auditor.add` must not grow `ledger`.
- `auditor.length == ledger.length` after the attempt (17).

**Must print**

```text
── COMPLY ── auditor.add(...) blocked; length == ledger.length
  auditor.add blocked=true
  auditor.length=17 ledger.length=17
```

17 rows in the last good run:

| Kind | Count | Auth ids |
|---|---|---|
| DECLINE | 4 | 2, 3b, 7, 9b |
| ISSUER | 4 | same four |
| STEP-UP | 2 | SU-1, H-1 |
| ACK | 3 | 6, 9-pre, H-1 |
| HOLD | 2 | H-1, H-3 |
| CAPTURE | 1 | H-1 |
| VOID | 1 | H-3 |

---

### Trailer

**Must print**

```text
------------------------------------------------------------------------
attempts=13 declines=4 stepUps=2 ledger=17 issuerAttempts=5
available=190000 held=0 openHolds=0 captured=60000
auditorLength=17 (same as ledger)
invariant available+held+captured = 250000 (expected 250000)
------------------------------------------------------------------------
```

Then `h.dispose()` stops every observer attached in `install`.

---

## Pulse path (scenario 2)

```
mccBlock.add('7995')
  TestTissue on TissueSet pass
  ElementAdded<String> on mccBlock

setMcc('7995'); setPresent(cardNotPresent); setAmount(7200)
  mccIn.emit — TestCell pass
  publishAttempt → attemptIn
    decline Receptor: MapValue decline → Distinct emit → Filter pass
    stepUp Receptor: Filter drop
    observe DECLINE
      ledger.add(...)           → ElementAdded<LedgerEntry>
      issuerQ.addLast(...)      → ElementAdded<IssuerJob>
    AsyncMapWithRetry → issuer cell
```

Scenario 8 stops at `amountIn.emit` / `mccIn.emit`. Tissue is idle.

Scenario 10 never enters `riskOf` for the debit. The ACK observer
calls `placeHold`. If you debit inside `riskOf`, two STEP-UPs before
ACK will steal the balance twice.

---

## Who owns the lock

| Event | Lock |
|---|---|
| `riskOf` + Distinct + Filter | Receptor lock on `declineHandle` / `stepUpHandle` |
| `ledger.add` | TissueList lock |
| `available` / `held` write | that TissueValue lock |
| `holdsMap[id] = ...` | TissueMap lock |
| issuer Future | none of the above — `AsyncMapWithRetry` |

Do not “fix” a race by putting `ledger.add` inside the Instruction.
Teach the two locks.

---

## Real rail vs this file

| Still missing | Suggested next piece |
|---|---|
| Snapshot is a Dart cache | merchant Nucleus / `Cell.synthesis` |
| No 10–15 s “finger on glass” | `Debounce` / `Throttle` in front of `attemptIn` |
| Joint commit across tissues | `Cell.transaction` spanning TissueValues when the API allows |
| Settlement batch | `BufferTime` overnight **or** drain `TissueQueue` on a timer |
| Multi-currency | `TestCell` on ISO-4217 **ingress**; `TestTissue` on the FX `TissueMap` |
| Scheme STIP / partial auth | third Receptor + extra Decision |
| Persistent books | same Tissue API in front of a store; demo stays in-process |

Flow stays on “is this DECLINE / STEP-UP?”  
TestCell stays on the **amount / MCC ingress**.  
TestTissue stays on **collection mutations**.  
ACK stays a flag on Distinct.  
Tissue stays the **books and the blocklist**.  
Deputy stays the **compliance screen**.

---

## Acceptance (the demo is done when)

1. `dart run card-auth-pipeline(tissue)-Demo.dart` prints every row
   in the scenario table with the **Result** column matched.
2. Grep shows exactly **two** `toHandle(` calls for the risk gates,
   both inside `installGates`, none inside ACK.
3. `riskOf` has no `await`, no `available` write, no `ledger.add`.
4. Scenario 2 mutates `mccBlock` (TissueSet) **before** the decline.
5. Scenario 8 prints TestCell rejection and does not append ledger.
6. Scenario 9 shows a retry in `issuerAttempts` and still **one**
   DECLINE pulse.
7. Scenarios 10–13 keep
   `available + held + capturedCents == 250000`.
8. COMPLY shows the read-only deputy blocked on `add` and live on
   `length`.
9. File header diagram matches this document.
10. No Dart `List<LedgerEntry>` is the system of record. A local
    `List` used only to format the trailer is allowed.
11. Every `TissueList` / `TissueSet` / `TissueMap` / `TissueQueue` /
    `TissueValue` / `.deputy(` constructed in the demo passes
    `TestTissue` (or omits the argument and takes `TestTissue.allowAll`).
    Grep must show **zero** `testRule: TestCell` on those calls.

---

## Name plate

| Artifact | Name |
|---|---|
| This requirement / walkthrough | `card-auth-pipeline(tissue)-WalkThrough.md` |
| Working demo | `card-auth-pipeline(tissue)-Demo.dart` |
| Flow-only sibling (already written) | `card-auth-pipeline(enhanced)-WalkThrough.md` |

Same pairing style as `ICU-alarm-pipeline(enhanced)-*`.
Keep the Flow-only filename. This file is the Tissue lesson, not a
rename of the Receptor lesson.
