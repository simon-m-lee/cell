# Walkthrough requirement — card auth pipeline (Flow + Tissue)

**Suggested demo:** `card-auth-pipeline(tissue)-Demo.dart`  
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

Seed: `available = TissueValue<int>(250000)`, `held = TissueValue<int>(0)`,
`holdsMap` empty, `mccBlock` empty, `ledger` empty (initial population
is silent — observers only see **post-create** mutations).

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

Good-run counts (risk half): attempts ≥ 18, declines 4, step-ups ≥ 1,
ledger rows ≥ 7 from risk+ACK plus HOLD/CAPTURE/VOID. `issuerAttempts`
can be 5 if the first network call throws.

Print a trailer:

```text
attempts=… declines=… stepUps=… ledger=… issuerAttempts=…
available=190000 held=0 openHolds=0
auditorLength=… (same as ledger)
```

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
| Multi-currency | TestCell on ISO-4217 + FX `TissueMap` |
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

---

## Name plate

| Artifact | Name |
|---|---|
| This requirement / walkthrough | `card-auth-pipeline(tissue)-WalkThrough.md` |
| Demo to implement next | `card-auth-pipeline(tissue)-Demo.dart` |
| Flow-only sibling (already written) | `card-auth-pipeline(enhanced)-WalkThrough.md` |

Same pairing style as `ICU-alarm-pipeline(enhanced)-*`.
Keep the Flow-only filename. This file is the Tissue lesson, not a
rename of the Receptor lesson.
