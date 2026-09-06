# Walkthrough — ICU alarm pipeline (enhanced)

**Demo:** `example\ICU-alarm-pipeline(enhanced)-Demo.dart`  
**Sibling:** `ICU-alarm-pipeline-Demo.dart` (bus + one gate only)

Adds TestCell on sensor ingress, a WARN Receptor, a ledger, ACK that
**resets Distinct on the same Receptor**, and `AsyncMapWithRetry`.

---

## Design

```
hrIn    TestCell 20–250  ─┐
spo2In  TestCell 0–100   ─┼─ set* → publishVitals → Reading(bed, hr, spo2, moving)
motionIn                 ─┘
                              │
                              ▼
                         vitalsIn
                    ┌─────────┴─────────┐
                    ▼                   ▼
              page gate            warn gate
         MapValue + Distinct     MapValue + Distinct
              + Filter(page)          + Filter(warn)
                    │                   │
                    ▼                   ▼
              pageHandle            warnHandle
                    │
                    ├─ observe → ledger PAGE + console pager
                    └─ AsyncMapWithRetry → pagerHandle
ackIn ─────────────────────────────────► resetDistinct()
```

| Requirement | Owner |
|---|---|
| Impossible HR / SpO2 | `TestCell` on **ingress**, not on state |
| One Reading per tick | `publishVitals` bus |
| PAGE vs WARN | two Receptors, same `severityOf` |
| No duplicate PAGE | Distinct **before** Filter; ACK clears `_pageLast` |
| Nurse text | `AsyncMapWithRetry` + observer print |
| Audit | `ledger` list (in-process) |

Do **not** call `toHandle` again on ACK. A second handle stays subscribed
to `vitalsIn` and doubles every later PAGE (`Concurrent modification` if
you mutate synapses in the same effect).

---

## Parts

### Cell

| Cell | Kind | Role |
|---|---|---|
| `hrIn` / `spo2In` | ingress + TestCell | reject 9 / 140 |
| `motionIn` | ingress | bool |
| `vitalsIn` | ingress `<Reading>` | snapshot bus |
| `ackIn` | ingress `<String>` | who acknowledged |
| `pageHandle.cell` | `toHandle` | PAGE only |
| `warnHandle.cell` | `toHandle` | WARN only |
| `pagerHandle.cell` | `AsyncMapWithRetry` | I/O with `count: 2` |

`_hr` / `_spo2` / `_moving` are a Dart cache. `setHr` returns false and
does **not** call `publishVitals` when TestCell rejects.

### Instruction

| Stage | Type |
|---|---|
| `MapValue<Reading, Severity>` | `severityOf` |
| `_distinctPage` / `_distinctWarn` | closured last-value; ACK zeroes it |
| `Filter<Severity>(page)` / `warn` | drop the other severities |

Library `DistinctUntilChanged` is not used: it cannot be reset without a
new handle.

### Receptor

`buildPageGate().toHandle(source: vitalsIn.cell)` once at
`installGates()`. Same for WARN. One lock per gate.

### Flow operators

`MapValue`, `Filter`, `FlowInstruction` (custom Distinct),
`AsyncMapWithRetry` (`count`, not `retries`), `Cell.observe`,
`Cell.ingress(testRule:)`.

---

## Implementation map

| Block in the dart file | What |
|---|---|
| Architecture / expected output comments | talk track |
| `Reading` / `Severity` / `LedgerEntry` | domain |
| `hrRange` / `spo2Range` | TestCell |
| `publishVitals` / `set*` | bus |
| `severityOf` | clinical map |
| `_distinctPage` + `resetDistinct` | ACK |
| `installGates` | two Receptors + pager + observes |
| `main` | seed + scenarios 1–9 |

`installGates` runs **once**. ACK only touches Distinct fields.

---

## Scenarios (what the last good run showed)

| # | Drive | Result | Demonstrates |
|---|---|---|---|
| Seed | still, 96, 72 | three vitals, no PAGE | bus + Filter |
| 1 | repeat 72/96 | no PAGE | Distinct on `none` |
| 2 | SpO2 86 | **PAGE** + ledger + pager | first critical |
| 3 | moving then still | no page while moving; **PAGE** when still | artifact then Distinct `none`→`page` |
| 4–5 | SpO2 85, HR 35 | **no** PAGE | Distinct holds `page` (header text that says PAGE here is wrong) |
| WARN | HR 55, SpO2 90 | **WARN** | second Receptor |
| 6 | 96 / 74 then ACK | recover; Distinct cleared | ACK ≠ new `toHandle` |
| 7 | SpO2 87 | **one** PAGE | reset Distinct |
| 8 | HR 9, SpO2 140 | TestCell lines; **no** vitals | ingress boundary |
| 9 | ACK, recover, SpO2 80, fail-once | **one** PAGE; pagerAttempts includes retry | `AsyncMapWithRetry` |

Good-run counts: vitals 18, pages 4, warns 1, ledger 7 (4 PAGE + 1 WARN
+ 2 ACK). `pagerAttempts` can be 5 if the first nurse-app call throws.

---

## Pulse path (scenario 2)

```
setSpo2(86)
  spo2In.emit — TestCell pass
  _spo2 = 86
  publishVitals → vitalsIn
    page Receptor: MapValue page → Distinct emit → Filter pass
    warn Receptor: Filter drop
    observe PAGE → ledger
    AsyncMapWithRetry → pager cell
```

Scenario 8 stops at `hrIn.emit` / `spo2In.emit`.

---

## Real bay vs this file

| Still missing | Suggested next Cell/Flow piece |
|---|---|
| Snapshot is a Dart cache | bed `Nucleus` / trusted `Cell.synthesis` |
| No 10–15 s hold | `Debounce` / `BufferTime` **in front of** the gate |
| Ledger is a `List` | append-only ledger Cell |
| Two pager printers | keep `pagerHandle` **or** the observer Future, not both |
| ACK does not dispose I/O | fine; do not stack `toHandle` |
| No `Context` | bed/ward on Pulse |
| WARN unused by pager | charge-nurse Cell from `warnHandle` |

Flow stays on “is this PAGE / WARN?”  
TestCell stays on the **sensor ingress**.  
ACK stays a flag on Distinct, not a second graph.
