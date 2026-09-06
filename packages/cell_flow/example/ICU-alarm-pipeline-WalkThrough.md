# Walkthrough — ICU bedside alarm

**Demo:** `example\ICU-alarm-pipeline-Demo.dart`

How **Instruction**, **Receptor**, and **Cells** turn three noisy sensors
into one page, without putting HTTP on the policy chain.

---

## 1. Design requirement

A bed emits heart rate, SpO2, and motion many times per second.

| Reading | Required behaviour |
|---|---|
| HR 72, SpO2 96, still | no page |
| SpO2 86 while the patient turns | artifact — no page |
| SpO2 86, still | **one** page |
| SpO2 85 a second later, still page-level | same alarm — do not page again |
| HR 35 while still desat | still the same PAGE — no second text |
| Recover to 95, then desat again | **new** page |

Also: the nurse app is slow. Evaluating “is this a page?” must not wait
on it.

That is four machines:

| Requirement | Owner |
|---|---|
| One Reading from three clocks | snapshot bus (`vitalsIn`) |
| Clinical mapping + de-dupe | Instruction `+` / one Receptor |
| Text / radio | next Cell (`AsyncMap` or observer Future) |
| “Silence this alarm” | **new** Receptor, not another operator |

---

## 2. Instruction (in depth)

An Instruction is `(Pulse) → Pulse | null`. No lock, no I/O.

```dart
toSeverity + distinct + filterPage
```

### 2.1 `toSeverity`

Pure function of one `Reading`:

- `moving` → `none` (artifact wins)
- SpO2 &lt; 88 or HR &lt; 40 or HR &gt; 140 → `page`
- SpO2 &lt; 92 or HR &lt; 50 or HR &gt; 120 → `warn`
- else → `none`

You can unit-test this with `Pulse(Reading(...))` and no graph.

### 2.2 `distinct`

Closure state: last `Severity`. Emits only when the value **changes**
(or on the first pulse).

It must see **all three** severities. If `Filter(page)` runs first,
`none` never arrives, last stays `page`, and a new desat after recover
will **not** page. That is why the chain is Distinct **then** Filter.

### 2.3 `filterPage`

`payload == page ? pulse : null`. `null` stops the Receptor. WARN is
deliberately unused in this demo (a second gate could tick a banner).

### 2.4 `+`

`InstructionChain`. First `null` wins. One object you pass to
`Receptor.instruction`. Do not `await` inside these three stages.

---

## 3. Receptor (in depth)

```dart
alarms = buildAlarmGate().toHandle(source: vitalsIn.cell);
```

`toHandle` builds `Receptor.instruction(chain)` + Nucleus + output Cell.

| Pulse on `vitalsIn` | Receptor | `alarms.cell` |
|---|---|---|
| 72 / 96 / still | `none` → Distinct maybe emit → Filter drop | nothing |
| 72 / 86 / still | `page` → Distinct emit → Filter pass | PAGE |
| 72 / 86 / moving | `none` → Distinct emit → Filter drop | nothing |
| 72 / 86 / still again | `page` → Distinct emit → Filter pass | PAGE |
| 72 / 85 / still | `page` → Distinct **drop** | nothing |

The Receptor answers only “may the nurse be paged **now**?” It does not
open a radio. Sticky Distinct is **this** handle’s memory. Ack / silence
on the bay is `buildAlarmGate().toHandle(...)` again (new `_last`).

`TestCell.allowAll` on the handle means “no second integrity policy.”
Range checks belong on the **sensor ingresses**, not here.

---

## 4. Cells (in depth)

| Cell | Kind | Writes | Reads |
|---|---|---|---|
| `hrCell` / `spo2Cell` / `motionCell` | ingress | `set*` | unused by the gate |
| `_hr` `_spo2` `_moving` | Dart fields | `set*` | `publishVitals` |
| `vitalsIn` | ingress `<Reading>` | `publishVitals` | gate + vitals print |
| `alarms.cell` | Flow output | Receptor | alarm observe, AsyncMap |
| `pages.cell` | Flow output | AsyncMap | optional observe |

Why a manual bus instead of `combineLatest` / `synthesis` in this
binary: those aggregators did not emit in the first runs (empty
summaries). `publishVitals` after every `set*` is an explicit
`Reading` so the Receptor always sees a full snapshot.

`Cell.observe` handles are kept in `retainObservers` so they are not
collected. Setup runs **before** seed.

Pager: `AsyncMap<Severity,String>.toHandle(source: alarms.cell)` is the
Flow part. The demo **also** prints from the alarm observer after 80 ms
because `pages.cell` was silent in an earlier build. Production should
pick **one** I/O path.

---

## 5. End-to-end pulse (scenario 2)

```
1. setSpo2(86)
2. _spo2 = 86; spo2Cell.emitAsync(86)
3. publishVitals
     print [VITALS] HR:72, SpO2:86, moving:false
     vitalsIn.emitAsync(Reading)
4. Receptor
     toSeverity → page
     Distinct   → last was none → emit page
     Filter     → page
5. alarms.cell observers
     print [ALARM] PAGE
     schedule pager print
     AsyncMap starts 80 ms Future
6. [PAGER] ICU-12: Desaturation/HR alert!
```

---

## 6. Scenarios, step by step

### Seed

`setMoving(false)`, `setSpo2(96)`, `setHr(72)` → three Readings.
Severity `none`. Filter drops. Distinct last = `none`.

**Shows:** observers attached; bus works; no page on a live patient.

### 1 — Normal

Same 72 / 96. Distinct already `none` → drop.

**Shows:** repeats are not events.

### 2 — Desat 86

`toSeverity` → `page`. Distinct `none` → `page` → emit. Filter pass.
Pager runs.

**Shows:** first critical reading becomes exactly one PAGE.

### 3 — Motion then still

Moving: `none`. Distinct updates to `none`. Filter drops (no page
while turning).

Still + SpO2 86: `page` again. Distinct `none` → `page` → **page**.

**Shows:** artifact is policy (`moving` → `none`), not a missing
sensor. Ending the artifact is a **new** PAGE because Distinct saw
`none`. That is clinically arguable (same desat) but it is what this
chain specifies.

### 4 — SpO2 85

Still `page`. Distinct drop. **No** PAGE.

**Shows:** deepening desat is not a second text. (Ignore dart-header
text that says scenario 4 pages.)

### 5 — HR 35

Still `page`. Distinct drop. **No** PAGE.

**Shows:** a second criterion on the same PAGE does not re-page.
Brady **would** page if it were the first critical event.

### 6 — Recover 95 / HR 74

`none` (and a brief `warn` if 95 is set while HR is still 35:
HR 35 + SpO2 95 → still PAGE until HR rises). Distinct moves off
`page`. Filter drops.

**Shows:** recover is visible to Distinct only because Filter is
**after** Distinct.

### 7 — SpO2 87

`page`. Distinct `none` → `page`. PAGE + pager.

**Shows:** a new episode after recover is a new page.

**Counts from the last good run:** 13 vitals, 3 alarms, 3 pagers
(scenarios 2, 3b, 7).

---

## 7. Real-life gaps

| Gap | Why it hurts |
|---|---|
| Snapshot is a Dart cache | Process restart loses “current” vitals; two writers race `_hr` |
| Sensor ingress unused by the gate | TestCell on HR never runs if you only `publishVitals` |
| Distinct in a closure | Cannot inspect or persist “last severity” |
| No nurse ack | Cannot reset Distinct without a new handle |
| WARN unused | Charge nurse has no ticker |
| Two pager paths | Double SMS if `pages.cell` starts working |
| No `Context` / bed id | Pulse has no bay |
| No ledger | Night audit is stdout |
| No hysteresis / time | Single sample at 87 pages; real monitors delay 10–15 s |
| No alarm fatigue budget | Three pages in one demo minute would be many on a ward |
| Motion is a bool | Real motion is a score / impedance |

---

## 8. Proposed production shape (Cell + Flow)

```
                    Context (bed, ward, shift)

hrIn   TestCell(20–250)  ─┐
spo2In TestCell(0–100)   ─┼─ Cell.synthesis / bed Nucleus → Reading
motionIn                 ─┘

Reading → alarmGate Receptor
            MapValue toSeverity
          + DistinctUntilChanged
          + Filter(page)
          toHandle  (new handle on ACK)

PAGE ─┬─ ledger Cell.append (sync, in-process)
      ├─ Partition / second gate for WARN banner
      └─ AsyncMap / FromFuture  nurse-app Cell
              retry + timeout on that Cell only
```

| Piece | Demo | Production |
|---|---|---|
| Snapshot | `publishVitals` cache | `Cell.synthesis` or one Nucleus `evolve` that reads three values under a lock |
| Policy | three raw Instructions | `MapValue + Distinct + Filter`; unit-test the chain with `Pulse`s |
| Ack | new `toHandle` | same, triggered by an ack ingress |
| Sensors | untested ingress | `TestCell` ranges on **each** `Cell.ingress` |
| Pager | observer `Future` + AsyncMap | **one** `AsyncMap`/`FromFuture` + `Retry` |
| Time | none | `Debounce` / `BufferTime` **in front of** the gate for 10 s hold, not inside Distinct |
| Audit | print | append-only ledger Cell |
| Identity | none | `Context` on Pulse / Cell |

Suggested sequence on the bay:

1. Sensors pass TestCell and update the bed Nucleus.  
2. Nucleus emits `Reading`.  
3. Receptor (`MapValue + Distinct + Filter`) decides PAGE.  
4. Ledger append (same isolate, no await).  
5. Pager Cell does I/O with timeout/retry.  
6. Nurse ACK ingress → dispose handle, `toHandle` again.  

Flow stays on “is this a page?”  
Cells stay on “what is the bed now?” and “did the text leave?”  
Do not `txApply` stock-style transactions on vitals. Do not put
`AsyncMap` inside `+`.
