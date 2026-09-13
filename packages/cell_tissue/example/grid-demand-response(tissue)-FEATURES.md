# Features — grid demand-response (Flow + Tissue)

**Companion to:** `grid-demand-response(tissue)-Demo.dart`
**Audience:** operators and reviewers evaluating what the demo
demonstrates and what it deliberately leaves out.

---

## Contents

1. [Feature catalogue](#1-feature-catalogue)
    - [Sensor ingress (TestCell)](#11-sensor-ingress-testcell)
    - [Decision policy (Flow)](#12-decision-policy-flow)
    - [Distinct latches (Flow)](#13-distinct-latches-flow)
    - [Books (Tissue)](#14-books-tissue)
    - [Reserve protocol](#15-reserve-protocol)
    - [RTU pump](#16-rtu-pump)
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
| Hz shape validation | `_hzRange` on `hzIn` | Rejects < 49.00 or > 51.00. Accepts any `num`; coerces to double. |
| Load shape validation | `_loadRange` on `loadIn` | Rejects negative MW. Requires `int`. |
| SOC shape validation | `_socRange` on `socIn` | Rejects < 0 or > 100. Requires `int`. |
| Pulse unwrapping | every `TestCell` rule | Rule reads `Pulse.payload`, not the wrapper. Without this the rule sees a `Pulse<double>` and rejects every emission. |
| Cache-on-accept | `setHz` / `setLoad` / `setSoc` | Rejected values do **not** overwrite the previous accepted value. |
| Pre-flight guards | `publishTick` | Re-checks `_hzValid` / `_loadValid` / `_socValid` before emitting, so a scenario can *report* a rejection without publishing. |
| Zero-delay drain | `publishTick` / `ack` | Awaits a `Duration.zero` future so the observer chain drains before the next scenario step. |
| Hz formatting | `_fmtHz` | Pins Hz output to two decimals (`49.70`, not `49.7`) so console output is stable. |

### 1.2 Decision policy (Flow)

| Feature | Where | Behaviour |
|---|---|---|
| Pure action evaluation | `actionOf` (static) | No `await`, no I/O, no state, no MW writes. |
| Protected feeder hold | `actionOf` first clause | `t.feeder in protectedSet` → `hold`, **before** any frequency check. |
| Shed band | `actionOf` second clause | `Hz < 49.80` → `shed`. |
| Warn band (frequency) | `actionOf` third clause | `49.80 ≤ Hz < 49.90` → `warn`. |
| Warn band (SOC/load) | `actionOf` fourth clause | `SOC < 15` **and** `load > 500 MW` → `warn`. |
| Default hold | `actionOf` final clause | Everything else → `hold`. |
| Ordering guarantee | clause order | A protected feeder is never shed, even in the shed band. |
| Purity enforcement | `static` | A static method cannot reach `this`, so it cannot accidentally call `reserveMw.set` or `events.add`. |

### 1.3 Distinct latches (Flow)

| Feature | Where | Behaviour |
|---|---|---|
| Per-gate latches | `_lastShed`, `_lastWarn` | Independent suppression: a WARN does not clear the SHED latch and vice versa. |
| Distinct-before-Filter | `installGates` order | `hold → shed → hold → shed` fires **twice**. |
| Latch captures `hold` | Distinct instruction | The latch records the decision the pipeline *made*, including `hold`. |
| ACK reset | `resetDistinct` | Clears both latches; no graph rebuild, no new `toHandle`. |
| Single handle per gate | `installGates` | Exactly **two** `toHandle` calls in the whole demo, both in `installGates`. |
| Closure-captured latch | `_distinctShed` / `_distinctWarn` | Plain `Action?` fields, not `Box` or `Cell`, so ACK can reset without rebuilding. |

### 1.4 Books (Tissue)

| Feature | Where | Behaviour |
|---|---|---|
| Append-only event log | `_eventAppendOnly` on `events` | `add` / `addAll` allowed; `remove` / `clear` / `[]=` denied. |
| Non-negative reserve | `_nonNegativeMw` on `reserveMw` | Any write that would go negative is rejected. |
| Shed shape validation | `_shedRule` on `shedMap` | `droppedMw > 0` and non-empty feeder id. |
| Protected feeder shape | `_protectedRule` on `protected` | Uppercase `AREA-N` string (must contain `-` and already be uppercase). |
| Bounded RTU queue | `rtuQ` with `capacity: 32` | Overflow drops oldest (circular buffer behaviour). |
| RTU job rule | `_rtuJobRule` on `rtuQ` | Accepts every job — extension hook for future rate-limiting. |
| Initial population is silent | every Tissue | Observers only see *post-create* mutations. Seed does not append to `events`. |
| Cache of last tick | `_currentTick` | Lets the SHED / WARN observers correlate the decision with the correct feeder and Hz. |

### 1.5 Reserve protocol

| Feature | Where | Behaviour |
|---|---|---|
| NSF pre-check | `applyShed` | Rejects *before* writing the map row, so no orphan `Shed` record. |
| Compensating write | `applyShed` | Map row removed if the reserve write rejects (belt-and-braces). |
| Restore-by-feeder | `restore` | Looks up by feeder id; returns MW to the pool. |
| No-op restore | `restore` returns `false` | ACK `'ALL'` does not invent MW. |
| Reserve invariant | trailer | `reserveMw + sum(droppedMw) == 800` — documented break in §11, restored in §12. |
| Fixed shed MW | `shedMw = 50` | Keeps arithmetic simple for the talk track. |
| Out-of-band override | `reserveMw.set(30)` | Scenario 11 fixture to prove the non-negative guard. |

### 1.6 RTU pump

| Feature | Where | Behaviour |
|---|---|---|
| Single-shot retry | `_driveRtu` | Retries once on failure. |
| Retry counter | `rtuAttempts` | Counts **both** attempts (initial + retry). |
| Fail-once injection | `rtuFailOnce` | Scenario 9 flips it on; the next attempt throws once. |
| Audit-side enqueue | `rtuQ.addLast` | Every job appears as `ElementAdded<RtuJob>` on the queue. |
| Working list | `_rtuWork` | Drives the pump, because `TissueQueue.removeFirst` does not drain in this build. |
| Both gates enqueue | SHED and WARN observers | Every SHED **and** every WARN enqueues an RTU job. |

### 1.7 Compliance deputy

| Feature | Where | Behaviour |
|---|---|---|
| Live read-only view | `events.unmodifiable` | Zero-copy projection. Reads share storage. |
| Write block | COMPLY scenario | `council.add` does not grow `events`. |
| Length parity | COMPLY scenario | `council.length == events.length` after the attempted write. |
| Silent swallow | this build | The unmodifiable wrapper swallows writes silently, so the demo checks length before/after. |
| Live reflection | this build | Changes to `events` remain visible through `council`. |

---

## 2. Scenario catalogue

| Banner | Feature exercised | Acceptance line |
|---|---|---|
| Seed | Bus + Filter + silent initial population | `events.isEmpty=true` |
| 1 | Distinct on `hold` | `new sheds: 0` |
| 2 | Protected feeder hold (TissueSet feeds `actionOf`) | `[protected] +HOSP-1`, `new sheds: 0` |
| 3 | Shed band + observer writes + `applyShed` | `[events] SHED INT-14 — 49.70Hz …`, `[reserveMw] 800 → 750` |
| 4 | Distinct suppression (latch holds `shed`) | `new sheds: 0` |
| 5 | Distinct keys on `Action`, not Hz | `new sheds: 0` |
| WARN | Second Receptor, independent latch | `[events] WARN INT-14 — 49.85Hz SOC=10`, `new warns: 1` |
| 6 | ACK + restore | `[reserveMw] 750 → 800`, `reserveMw=800 openSheds=0` |
| 7 | Fresh shed after ACK reset | `new sheds: 1` |
| 8 | TestCell rejection at ingress | `accepted=false` ×3, `events grew: 0` |
| 9 | RTU retry | `[events] RTU INT-14 — shed (retry)`, `rtuAttempts=5` |
| 10 | TissueMap second feeder | `[shedMap] INT-15 +50MW`, `openSheds=1` |
| 11 | Non-negative TestTissue rejects | `applyShed ok=false`, `reserveMw=30 openSheds=1` |
| 12 | Restore returns MW to pool | `[reserveMw] 30 → 80`, `openSheds=0` |
| 13 | ACK without shed invents no MW | `unchanged=true` |
| COMPLY | Deputy blocks write, shares storage | `blocked=true`, `council.length=19 events.length=19` |

---

## 3. What the demo does **not** do (deliberately)

| Missing feature | Why it is out of scope | Where it would live |
|---|---|---|
| Real DNP3 / IEC 61850 I/O | The demo is in-process; a real RTU is not. | A custom `Tissue` subtype wrapping the protocol stack. |
| AGC / tie-line control | Different control loop; would double the policy surface. | A third gate + ingress. |
| Multi-area reserve table | Single-area keeps the invariant arithmetic honest. | `TissueMap<String, int>` + per-area rules. |
| Joint commit across tissues | This build's `cell_tissue` does not expose it. | `Cell.transaction` spanning Tissue writes. |
| Persistent historian | Demo is one-shot, ephemeral. | Same Tissue API over a store. |
| Settlement batching | Not applicable to real-time demand-response. | `BufferTime` if needed. |
| Dead-letter handling | Retry-once is enough for the lesson. | `TissueQueue<RtuJob>` with a second consumer. |
| Dead-letter alerting | Same. | An `observe` on the queue's `ElementAdded`. |
| Debounce in front of `tickIn` | The demo publishes one tick per scenario step. | `Flow.debounce<BayTick>` between `tickIn` and the gates. |
| Multi-product gates beyond SHED/WARN | Two products are enough to show the shape. | Third gate + third `TestTissue` + third observer. |
| Async `actionOf` | Purity is the lesson; an async policy would require a different test story. | Would need a `FutureOr<Action>` variant of `MapValue`. |
| Rate limiting per feeder | Out of scope for v1. | `TestTissue` on `shedMap` keyed on a sliding window. |
| Encryption / signing of events | Out of scope for v1. | A custom `Tissue` subtype that signs each row on `add`. |

---

## 4. Operator cheat sheet

### 4.1 Common operations

| Want | Call |
|---|---|
| Publish a fresh tick | `setArea` / `setFeeder` / `setHz` / `setLoad` / `setSoc`, then `await publishTick()` |
| Force a shed (operator override) | `applyShed('INT-15', 50)` |
| Clear a shed by feeder | `await ack('INT-14')` |
| Clear the Distinct latches only | `await ack('ALL')` |
| Protect a feeder at runtime | `protected.add('HOSP-1')` |

### 4.2 Inspection

| Want | Read |
|---|---|
| All events | `events` (iterable) |
| Latest event | `events.last` |
| Event count | `events.length` |
| Open sheds | `shedMap` |
| Open-shed count | `openShedsCount` |
| Reserve | `reserveMw.value` |
| Council view | `events.unmodifiable` |
| Tick count | `ticks` |
| Shed count | `shedCount` |
| Warn count | `warnCount` |
| RTU attempt count | `rtuAttempts` |

### 4.3 Diagnosing a missing shed

1. **Did the Hz reach the policy?**
   Check `setHz` return value. If `false`, the TestCell rejected it
   (out of 49.00–51.00). The cache did **not** update.
2. **Was the feeder protected?**
   Check `protected.contains(tick.feeder)`. A protected feeder
   returns `hold` unconditionally.
3. **Did the policy return `shed`?**
   Call `actionOf(tick, protected)` in isolation. It is pure.
4. **Was the Distinct latch already at `shed`?**
   Check `_lastShed`. ACK with `'ALL'` or the feeder id resets it.
5. **Was the reserve insufficient?**
   Check `reserveMw.value`. `applyShed` requires
   `reserveMw.value ≥ droppedMw`.

### 4.4 Diagnosing a double shed

If the same feeder sheds twice for what looks like one tick:

- Check that `installGates` was called exactly **once**. A second
  call attaches a second observer to the same gate, doubling every
  effect.
- Check that `toHandle` was not called from the ACK observer. ACK
  must only call `resetDistinct` (and optionally `restore`).

### 4.5 Diagnosing a missing restore

- Check `shedMap.containsKey(feeder)`. `restore` is a no-op without
  an open shed.
- Check that the ACK payload was the feeder id, not `'ALL'`.
  `'ALL'` clears the latches only.
- Check the `[reserveMw]` transition line printed. If absent, the
  restore did not run.

### 4.6 Priority of rules

When two clauses of `actionOf` both seem to apply, the earlier clause
wins. In order:

1. Protected feeder → `hold`.
2. `Hz < 49.80` → `shed`.
3. `49.80 ≤ Hz < 49.90` → `warn`.
4. `SOC < 15` and `load > 500` → `warn`.
5. Default → `hold`.

A protected feeder at 49.70 Hz is `hold`, not `shed`. The order is
load-bearing.

---

## 5. Acceptance checklist

The demo is done when **all** of the following hold:

1. `dart run grid-demand-response(tissue)-Demo.dart` matches the
   scenario **Result** column in `grid-demand-response(tissue)-WalkThrough.md`.
2. Exactly **two** `toHandle(` calls exist for the action gates, both
   inside `installGates`. Zero in ACK. Zero anywhere else.
3. `actionOf` contains no `await`, no `reserveMw.set`, no
   `events.add`, no `shedMap[...] =`, no `rtuQ.addLast`.
4. Scenario 2 mutates `protected` **before** the HOSP-1 tick is
   published.
5. Scenario 8 prints all three TestCell rejections and appends zero
   rows to `events`.
6. Scenario 9 shows a retry in `rtuAttempts` while still producing
   exactly **one** new SHED pulse after the ACK reset.
7. Shed / restore keep the invariant
   `reserveMw + sum(droppedMw) == 800` except during the forced-low
   beat of scenario 11, and restore a self-consistent value in §12.
8. COMPLY shows the read-only deputy blocked on `add` and live on
   `length`.
9. The Dart file's header diagram matches this document's diagrams.
10. No Dart `List<GridEvent>` is used as the system of record. A
    local `List` used only for formatting is allowed.
11. Every `TissueList` / `TissueSet` / `TissueMap` / `TissueQueue` /
    `TissueValue` / `.deputy(` in the demo passes **`TestTissue`**
    (or omits the argument and takes `TestTissue.allowAll`). Grep
    must show **zero** `testRule: TestCell` on those calls.
12. The trailer's counts match
    `ticks=12 sheds=4 warns=1 events=19 rtuAttempts=6` and
    `reserveMw=80 openSheds=0`.
13. `council.length == events.length` in the COMPLY step.

---

## 6. See also

| File | Purpose |
|---|---|
| `grid-demand-response(tissue)-Demo.dart` | Executable implementation. |
| `grid-demand-response(tissue)-WalkThrough.md` | Requirement document and scenario contract. |
| `grid-demand-response(tissue)-ARCHITECTURE.md` | Layering, ownership, locking, failure semantics, anti-patterns. |
| `card-auth-pipeline(tissue)-Demo.dart` | Payments sibling — same graph shape, different domain. |
| `ride-hail-dispatch(tissue)-WalkThrough.md` | Mobility sibling. |
| `ICU-alarm-pipeline(enhanced)-Demo.dart` | Clinical sibling. |