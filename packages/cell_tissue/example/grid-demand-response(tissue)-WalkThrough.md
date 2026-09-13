# Walkthrough requirement — grid demand-response (Flow + Tissue)

**Demo:** `grid-demand-response(tissue)-Demo.dart` (executable; this file is its requirement)
**Siblings:**
- `card-auth-pipeline(tissue)-WalkThrough.md` — payments
- `ride-hail-dispatch(tissue)-WalkThrough.md` — mobility
- `ICU-alarm-pipeline(enhanced)-Demo.dart` — clinical

**Industry:** electric power — transmission-desk demand response
(the thing grid operators actually do when system frequency sags:
shed interruptible load, protect hospitals, restore after the
operator ACK). Think ERCOT / National Grid / CAISO control room,
not a smart-thermostat app.
**Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`

This is the **executable requirement** for an energy-ops demo that
uses **Flow for the shed decision** and **Tissue for the feeder
books**. Implement the Dart file so a last-good run prints the
scenario table in § Scenarios.

Do not fold Tissue into the Receptor. Do not fold Flow into the
event log. The point of this file is the seam.

Why this industry (and not another ride-hail or another ICU):
frequency, megawatts, and “never drop feeder HOSP-1” are a different
physics and a different regulator. Two products still: **SHED**
(open interruptible load) vs **WARN** (yellow band). ACK is the
shift lead restoring the bay. The reliability council reads the log
and cannot delete a row.

---

## Contents

1. [TestCell vs TestTissue (do not swap)](#testcell-vs-testtissue-do-not-swap)
2. [Why Flow + Tissue (not a SCADA screenshot)](#why-flow--tissue-not-a-scada-screenshot)
3. [Design](#design)
4. [Domain](#domain)
5. [Parts](#parts)
   - [Flow Cells](#flow-cells)
   - [Tissue collections](#tissue-collections)
   - [Deputies](#deputies)
   - [Instruction](#instruction)
   - [Receptor](#receptor)
   - [Operators the demo must actually call](#operators-the-demo-must-actually-call)
6. [Reserve — TissueValue + TissueMap](#reserve--tissuevalue--tissuemap-not-inside-actionof)
7. [Implementation map](#implementation-map)
8. [Scenarios](#scenarios)
9. [Executable steps](#executable-steps)
10. [Pulse path (scenario 2 then 3)](#pulse-path-scenario-2-then-3)
11. [Who owns the lock](#who-owns-the-lock)
12. [Real desk vs this file](#real-desk-vs-this-file)
13. [Acceptance](#acceptance)
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
| `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` | Hz 49.00–51.00, MW ≥ 0, SOC 0–100 |
| `TissueList` / `Set` / `Map` / `Queue` / `Value` | `TestTissue<E, C>` | `testRule:` | append-only events, non-negative reserve MW, feeder ids |
| `tissue.deputy(...)` | `TestTissue` | `testRule:` | `TestTissue.readOnly` for the reliability council |
| `TestTissue.allowAll` | `TestTissue` | default | only when the collection has no extra rule |

Illegal:

```dart
TissueList<GridEvent>(testRule: TestCell.allowAll);     // wrong type
TissueValue<int>(800, testRule: hzRange);               // hzRange is TestCell
events.deputy(testRule: TestCell.readOnly);             // deputy wants TestTissue
```

Required shape:

```dart
final eventRule = TestTissue<GridEvent, TissueList<GridEvent>>(
  (e, {host, action, user}) => e.kind.isNotEmpty,
  // allow add / addAll; deny remove, clear, []=
);

final events = TissueList<GridEvent>(testRule: eventRule);

final mwRule = TestTissue<int, TissueValue<int>>(
  (v, {host, action, user}) => v != null && v >= 0,
);

final reserveMw = TissueValue<int>(800, testRule: mwRule);

final protected = TissueSet<String>(
  testRule: TestTissue<String, TissueSet<String>>(
    (id, {host, action, user}) =>
        id.contains('-') && id == id.toUpperCase(),
  ),
);

final council = events.deputy(testRule: TestTissue.readOnly);
```

`Cell.ingress(testRule: hzRange)` stays **`TestCell`**. That rule
never becomes the `testRule` on `reserveMw` / `events` / `protected`.

Compose Tissue rules with `+`, not by wrapping a `TestCell`.

---

## Why Flow + Tissue (not a SCADA screenshot)

A control-room bay has four machines a historian plot will not name:

1. Impossible Hz / negative MW must die at the **sensor**, not inside
   the shed rule.
2. Frequency, area load, and battery SOC arrive on **different clocks**.
   Policy must see one `BayTick`, not three half-updates.
3. SHED vs WARN are two products. One Receptor per product.
4. The feeder RTU is slow and flaky. “Is this a shed?” must not wait
   on DNP3.
5. Two overlapping sheds must not take the last megawatt of reserve
   twice, and must never open a protected feeder.
6. The reliability council may watch the event log and must not
   `remove` a row.

| Fake if you only use Dart objects | Owner in this demo |
|---|---|
| `List<GridEvent> events` | `TissueList<GridEvent>` — append-only |
| `int reserveMw = 800` | `TissueValue<int>` — non-negative MW |
| `Map<String, Shed>` | `TissueMap<String, Shed>` — feeder → open interruptible |
| `const hospitals` | `TissueSet<String> protected` — ops can add `HOSP-1` |
| RTU retry buffer | `TissueQueue<RtuJob>` |
| “NERC export” | `events.unmodifiable` / `deputy(TestTissue.readOnly)` |

Flow never stores megawatts. Tissue never decides SHED.

---

## Design

```
hzIn      TestCell 49.00–51.00 Hz ─┐
loadIn    TestCell ≥ 0 MW         ─┼─ set* → publishTick
socIn     TestCell 0–100 %        ─┤         → BayTick(area, hz, loadMw, soc, feeder)
areaIn                            ─┘
                                        │
                                        ▼
                                     tickIn              Flow
                          ┌─────────────┴─────────────┐
                          ▼                           ▼
                    shed gate                    warn gate
               MapValue + Distinct            MapValue + Distinct
                    + Filter(shed)                 + Filter(warn)
                          │                           ▼
                          │                      warnHandle
                          ▼
                    shedHandle
                          │
                          ├─ observe SHED
                          │     events.add(...)              TissueList
                          │     rtuQ.addLast(job)            TissueQueue
                          └─ AsyncMapWithRetry ← rtuQ
                                rtuHandle

ackIn  shift lead restore ── resetDistinct()
                             on restore:
                               shedMap.remove(feeder)        TissueMap
                               reserveMw.value += dropped    TissueValue

council ────────────────── events.unmodifiable               Deputy
opsProtect ─────────────── protected.add('HOSP-1')           TissueSet
```

| Requirement | Owner |
|---|---|
| Impossible Hz / MW / SOC | `TestCell` on **ingress Cells** |
| Never shed a hospital feeder | `TissueSet<String> protected` + `actionOf` reads it |
| One tick per snapshot | `publishTick` bus |
| SHED vs WARN | two Flow Receptors, same `actionOf` |
| No duplicate SHED | Distinct **before** Filter; ACK clears last |
| RTU trip | `TissueQueue` + `AsyncMapWithRetry` |
| Event audit | `TissueList<GridEvent>` + append-only `TestTissue` |
| Spinning reserve | `TissueValue<int>` + non-negative `TestTissue` |
| Open sheds | `TissueMap<String, Shed>` |
| Council screen | `events.unmodifiable` |
| Do not stack graphs | ACK does **not** call `toHandle` again |

Do **not** `events.add` inside `MapValue`. Do **not** replace Distinct
with “the log already has this feeder.” ACK restores the latch; it
never deletes event rows.

---

## Domain

```dart
enum Action { hold, warn, shed }

final class BayTick {
  const BayTick({
    required this.area,
    required this.feeder,
    required this.hz,
    required this.loadMw,
    required this.soc,
  });
  final String area;     // 'NORTH', 'BAY'
  final String feeder;   // 'INT-14', 'HOSP-1'
  final double hz;
  final int loadMw;
  final int soc;         // battery %, 0–100
}

final class GridEvent {
  const GridEvent({
    required this.kind,  // SHED | WARN | RESTORE | RTU | ACK
    required this.feeder,
    required this.detail,
    required this.at,
  });
  final String kind;
  final String feeder;
  final String detail;
  final DateTime at;
}

final class Shed {
  const Shed({required this.feeder, required this.droppedMw});
  final String feeder;
  final int droppedMw;
}

final class RtuJob {
  const RtuJob({required this.feeder, required this.action});
  final String feeder;
  final Action action;
}
```

Suggested `actionOf(BayTick t, Set<String> protected) → Action`:

| Condition | Action |
|---|---|
| `t.feeder` in `protected` | `hold` (never shed) |
| `t.hz < 49.80` | `shed` |
| `t.hz < 49.90` or (`t.soc < 15` and `t.loadMw > 500`) | `warn` |
| else | `hold` |

`protected` is a TissueSet the demo **mutates in scenario 2**.
Seed empty. Scenario 2 does `protected.add('HOSP-1')` then publishes
a 49.70 Hz tick on `HOSP-1` — must stay `hold`. Then a 49.70 tick on
`INT-14` must **SHED**.

Hz/MW/SOC **shape** stays on **TestCell**. Protected-feeder **policy**
stays on **TissueSet**. Do not merge them.

Nominal frequency in the demo is **50.00 Hz** (IEC). Do not mix 60 Hz
limits in the same run.

---

## Parts

### Flow Cells

| Cell | Kind | Role |
|---|---|---|
| `hzIn` | ingress + TestCell | reject `48.0`, `52.0` |
| `loadIn` | ingress + TestCell | reject `-10` |
| `socIn` | ingress + TestCell | reject `101` |
| `areaIn` / feeder cache | ingress | strings |
| `tickIn` | ingress `<BayTick>` | snapshot bus |
| `ackIn` | ingress `<String>` | feeder restored, or `"ALL"` |
| `shedHandle.cell` | `toHandle` | SHED only |
| `warnHandle.cell` | `toHandle` | WARN only |
| `rtuHandle.cell` | `AsyncMapWithRetry` | I/O with `count: 2` |

`setHz` returns false and does **not** call `publishTick` when
TestCell rejects.

### Tissue collections

| Tissue | Type | `TestTissue` | Who writes | Who reads |
|---|---|---|---|---|
| `events` | `TissueList<GridEvent>` | append-only | observers, restore | council deputy |
| `reserveMw` | `TissueValue<int>` | `>= 0` | shed / restore | desk board |
| `shedMap` | `TissueMap<String, Shed>` | feeder id + `droppedMw > 0` | SHED observer, ACK | ops |
| `protected` | `TissueSet<String>` | `AREA-N` style uppercase | ops scenario | `actionOf` |
| `rtuQ` | `TissueQueue<RtuJob>` | `capacity: 32` | shed/warn observer | RTU pump |

Seed: `reserveMw = TissueValue<int>(800, testRule: mwRule)`,
`shedMap` empty, `protected` empty, `events` empty (initial
population silent).

### Deputies

```dart
final books = events.unmodifiable;
final council = events.deputy(testRule: TestTissue.readOnly);
```

COMPLY: `council.add` blocked; `council.length == events.length`
after a SHED; live projection, not `List.from`.

### Instruction

`actionOf → Distinct → Filter`.
`actionOf` may **read** `protected`. It must not `add` to it.
Library `DistinctUntilChanged` is not used.

`buildShedGate().toHandle(source: tickIn.cell)` once at
`installGates()`. Same for WARN.

### Receptor

One Receptor per gate. Two locks, two owners:

- Receptor lock on `shedCell` / `warnCell` — covers `actionOf`,
  Distinct latch, `Filter`. Never touches MW.
- Tissue lock on each collection — covers `events.add`,
  `shedMap[...]`, `reserveMw.set`, `rtuQ.addLast`. Never decides SHED.

Do not fold the Tissue write into the Receptor. Do not fold the
decision policy into the observer.

### Operators the demo must actually call

Flow: `MapValue`, `Filter`, custom Distinct `FlowInstruction`,
`AsyncMapWithRetry` (`count`, not `retries`), `Cell.observe`,
`Cell.ingress(testRule:)` with **TestCell**.

Tissue: `TissueList`, `TissueValue`, `TissueMap`, `TissueSet`,
`TissueQueue`, `TestTissue(...)`, `TestTissue.readOnly`,
`.unmodifiable`, `.deputy(...)`, `.listen` / `Cell.observe` on the
tissue (tissues **are** Cells).

Prefer observing Tissue with:

```dart
events.listen((TissuePulse e) {
  if (e is ElementAdded<GridEvent>) {
    print('[events] ${e.payload.kind} ${e.payload.feeder}');
  }
});
```

and values with `ElementUpdated` (payload is `ElementUpdatedRecord`).
If the demo harness only has `Cell.observe`, that is acceptable —
print `pulse.payload` and tag `[reserveMw]` / `[shedMap]`.

---

## Reserve — TissueValue + TissueMap, not inside actionOf

A SHED that the observer accepts:

```text
shedMap[feeder] = Shed(feeder, droppedMw)
reserveMw.value = reserveMw.value! - droppedMw
events.add(GridEvent(kind: 'SHED', ...))
```

If `reserveMw` TestTissue would go negative, **do not** leave a map
row. Restore ACK reverses the two numbers and appends `RESTORE`.

**Invariant** after every successful money-of-the-grid method:

```
reserveMw.value! + sum(shedMap.values.droppedMw) == 800
```

Never decrement reserve inside `actionOf`. Demo `droppedMw` is a
fixed `50` per shed so the arithmetic stays talk-track simple.

The demo deliberately **breaks** this invariant once, in scenario 11,
by forcing `reserveMw` to `30` to prove the non-negative `TestTissue`
rejects an over-shed. Scenario 12 restores the books to a
self-consistent `80`. The header of the Dart file documents this
deviation.

---

## Implementation map

| Block | What |
|---|---|
| Header comments | talk track |
| Domain types | `BayTick` / `Action` / `GridEvent` / `Shed` / `RtuJob` |
| `hzRange` / `loadRange` / `socRange` | TestCell |
| `protected` + append-only `events` | TestTissue |
| `publishTick` / `set*` | bus |
| `actionOf` | Flow policy, reads TissueSet |
| `resetDistinct` | operator ACK |
| `installGates` | two Receptors + RTU + observes |
| `applyShed` / `restore` | TissueValue + TissueMap |
| `main` | seed + scenarios 1–13 + COMPLY |

`installGates` runs **once**. ACK only touches Distinct fields and
then calls `applyShed` when the talk track says “restore after ACK.”

---

## Scenarios

Seed area `NORTH`, feeder `INT-14`, Hz `50.00`, load `420`, SOC `60`,
reserve `800`, `protected` empty.

| # | Drive | Result | Demonstrates |
|---|---|---|---|
| Seed | 50.00 / INT-14 | one tick, **no** SHED | bus + Filter; initial Tissue is silent |
| 1 | repeat 50.00 | no SHED | Distinct on `hold` |
| 2 | `protected.add('HOSP-1')`, 49.70 on `HOSP-1` | **no** SHED | TissueSet feeds `actionOf` |
| 3 | 49.70 on `INT-14` | **SHED** + event + RTU job | Distinct `hold`→`shed` |
| 4–5 | 49.70 again, then 49.72 | **no** new SHED | Distinct holds |
| WARN | 49.85 / SOC 10 / load 600 | **WARN** | second Receptor |
| 6 | 50.00 then ACK restore `INT-14` | Distinct cleared; reserve back | ACK ≠ new `toHandle` |
| 7 | 49.70 on `INT-14` | **one** SHED | reset Distinct |
| 8 | Hz `48.0`, load `-10`, SOC `101` | TestCell lines; **no** tick | Cell ingress ≠ Tissue |
| 9 | ACK, recover, 49.70, RTU fail-once | **one** SHED; `rtuAttempts` includes retry | queue + retry |
| 10 | restore, ACK, 49.70 on `INT-15` | second shed on a new feeder | TissueMap |
| 11 | force `reserveMw` to `30` then SHED 50 | TestTissue reject; map unchanged | non-negative reserve |
| 12 | `restore('INT-15')` | reserve += 50, map drops row, event `RESTORE` | return MW to pool |
| 13 | ACK without an open shed | Distinct reset; reserve unchanged | restore ≠ invent MW |
| COMPLY | `council.add(...)` | blocked; lengths match | live deputy |

Good-run counts from the executable trailer:

```text
ticks=12 sheds=4 warns=1 events=19 rtuAttempts=6
reserveMw=80 openSheds=0
councilLength=19 (same as events)
```

Four SHED pulses: scenarios **3**, **7**, **9b**, **10**.
One WARN pulse: **WARN**. Ledger 19 = SHED events (4) + RTU events
(5: §3, WARN, §7, §9-retry ×1, §10) + WARN event (1) + RESTORE events
(4: §6, §9, §10, §12) + ACK events (1: §13) + the extra SHED-event
written by `applyShed` on §10 + the RESTORE-event on §12. The
walkthrough's stale `events=17` assumed one fewer RTU and no
bookkeeping row.

`rtuAttempts=6` because scenario 9 fails the first RTU call and
retries: §3 (1), WARN (2), §7 (3), §9-fail (4), §9-retry (5), §10 (6).

Print that trailer. Numbers in § Executable steps must match it.

---

## Executable steps

These are the steps `grid-demand-response(tissue)-Demo.dart` actually
runs. Numbers match the `── N ──` banners in the console. Seed is
unnumbered but required: without it Distinct has no first `hold`, and
“repeat does not shed” in step 1 is meaningless.

**Seam reminder at every step.** Flow answers “may this tick become a
SHED or WARN pulse?” Tissue answers “what did the books just record,
and did megawatts move?” The observer is the only glue. `actionOf`
never writes `reserveMw`. `applyShed` never runs inside the Receptor.

**Documented deviations the executable takes** (header of the demo):

- Tissue constructors: `TissueSet` / `TissueValue` take the initial
  value as the **first positional** argument; `TissueMap` puts
  `testRule` on the nucleus via `properties:`.
- Each `TestCell` unwraps `Pulse.payload` before the shape check.
- RTU pump: `rtuQ.addLast` is the audit enqueue;
  `_rtuWork` + `_driveRtu` is the retry list (this build's
  `TissueQueue` does not drain via `removeFirst`).
- Trace prints come from the writers themselves. Tissue-cell
  `Cell.observe` is silent in this build.
- `_fmtHz` pins Hz to 2 decimals so `49.70` never renders as `49.7`.

Reserve invariant after every successful shed/restore method:

```
reserveMw.value + sum(shedMap.values.droppedMw) == 800
```

The invariant is deliberately broken once in §11 (forced to 30) and
restored to a self-consistent `80` in §12. The header documents this.

---

### Seed — 50.00 / INT-14 / load 420 / SOC 60

**Lesson:** snapshot bus + Filter. Initial Tissue population is
silent.

**Drive**

```dart
h.setArea('NORTH');
h.setFeeder('INT-14');
h.setHz(50.00);
h.setLoad(420);
h.setSoc(60);
await h.publishTick();
```

**What fires**

- `hzIn` TestCell accepts `50.00` (49.00–51.00).
- `loadIn` TestCell accepts `420` (≥ 0).
- `socIn` TestCell accepts `60` (0–100).
- `publishTick` emits `BayTick(NORTH, INT-14, 50.00Hz, 420MW, 60%)`.
- Both gates run `actionOf` → `hold`. Distinct records `hold`.
  Filter(shed) and Filter(warn) both drop.
- Ledger is still empty: Seed does not append, and the initial
  `reserveMw=800` write was constructor-time (observers never saw it).

**Must print**

```text
── Seed ── 50.00 / INT-14 / load 420 / SOC 60
  events.isEmpty=true
```

**Must not happen**

- No `[events] SHED` / `WARN`.
- No RTU enqueue.
- No megawatt movement.

---

### Step 1 — repeat 50.00 / INT-14

**Lesson:** Distinct on `hold`. The SHED gate never sees `hold` as
a fireable action, and Distinct would drop a repeat anyway.

**Drive**

```dart
await h.publishTick();
```

**Must print**

```text
── 1 ── repeat 50.00 / INT-14
  new sheds: 0
```

---

### Step 2 — protected.add('HOSP-1'), then 49.70 Hz on HOSP-1

**Lesson:** TissueSet feeds `actionOf`. A protected feeder stays
`hold` even at shed-band Hz.

**Drive**

```dart
h.protected.add('HOSP-1');
h.setFeeder('HOSP-1');
h.setHz(49.70);
h.setLoad(420);
h.setSoc(60);
await h.publishTick();
```

**What fires**

1. `protected.add('HOSP-1')` — `TestTissue` on the set accepts an
   uppercase `AREA-N` string. This is **not** a Flow pulse.
2. `publishTick('HOSP-1', 49.70 Hz)` — `actionOf` sees `HOSP-1` in
   `protected` and returns `hold` before the frequency check.
3. Both gates' `Filter` drop the `hold`.

**Must print**

```text
── 2 ── protected.add('HOSP-1'), then 49.70 Hz on HOSP-1
[protected] +HOSP-1
  new sheds: 0
```

**Must not happen**

- No `[events] SHED HOSP-1`. The protected feeder is held.
- No reserve write.

**Documented deviation.** The walkthrough's prose says *“must stay
hold”*; the walkthrough's sample console shows `SHED HOSP-1` — those
contradict. This demo follows the prose and prints `new sheds: 0`.

---

### Step 3 — 49.70 Hz on INT-14

**Lesson:** Distinct `hold` → `shed`. Two locks: Receptor then
TissueList / TissueQueue / TissueMap / TissueValue.

**Drive**

```dart
h.setFeeder('INT-14');
h.setHz(49.70);
h.setLoad(420);
h.setSoc(60);
await h.publishTick();
```

**What fires**

1. `actionOf` sees `INT-14` not in `protected`, `49.70 < 49.80`,
   returns `shed`.
2. SHED Distinct was `hold` (from Seed) → emits `shed`. Filter
   passes. WARN Filter drops.
3. SHED observer:
   - `events.add(SHED INT-14)`
   - `rtuQ.addLast(RtuJob(shed))` + `_driveRtu()` → `events.add(RTU)`
   - `applyShed('INT-14', 50)` → `shedMap` row + `reserveMw 800→750`
      + `events.add(SHED bookkeeping)`

**Must print**

```text
── 3 ── 49.70 Hz on INT-14
[events] SHED INT-14 — 49.70Hz load=420MW
[rtuQ] enqueued RtuJob(INT-14, shed)
[events] RTU INT-14 — shed
[reserveMw] 800 → 750
[shedMap] INT-14 +50MW
  new sheds: 1
  rtuQ.length=1
```

**Must not happen**

- No second `toHandle`.
- No WARN event.

---

### Step 4 — 49.70 again

**Lesson:** Distinct holds `shed`. Same action, same latch.

**Drive**

```dart
await h.publishTick();
```

**Must print**

```text
── 4 ── 49.70 again
  new sheds: 0
```

Ledger does not grow. RTU does not enqueue.

---

### Step 5 — 49.72 (still shed band)

**Lesson:** Distinct keys on **Action**, not Hz. Changing Hz within
the same band does not create a new shed.

**Drive**

```dart
h.setHz(49.72);
await h.publishTick();
```

**Must print**

```text
── 5 ── 49.72 (still shed band)
  new sheds: 0
```

Even though the Hz changed, `actionOf` still returns `shed`, and the
Distinct latch still holds `shed`. The gate drops it.

---

### WARN — 49.85 / SOC 10 / load 600

**Lesson:** second Receptor, independent latch. The protected set
does not apply to `INT-14`; the Hz + SOC triggers WARN.

**Drive**

```dart
h.setHz(49.85);
h.setLoad(600);
h.setSoc(10);
await h.publishTick();
```

**What fires**

- `actionOf`: `INT-14` not protected; `49.80 ≤ 49.85 < 49.90` →
  `warn`.
- WARN Distinct was `hold` (from Seed) → emit. Filter(warn) passes.
  SHED Filter drops.
- WARN observer appends `WARN INT-14` and enqueues an RTU job.

**Must print**

```text
── WARN ── 49.85 / SOC 10 / load 600
[events] WARN INT-14 — 49.85Hz SOC=10
[rtuQ] enqueued RtuJob(INT-14, warn)
[events] RTU INT-14 — warn
  new warns: 1
```

**Must not happen**

- No `applyShed`. WARN is a decision, not a debit.
- `reserveMw` stays 750.

---

### Step 6 — 50.00 then ACK restore INT-14

**Lesson:** ACK clears both Distinct latches **on the same**
Receptors. The restore returns MW to the pool.

**Drive**

```dart
h.setHz(50.00);
h.setLoad(420);
h.setSoc(60);
await h.publishTick();
await h.ack('INT-14');
```

**What fires**

- Tick is `hold` — both Filters drop.
- `ackIn` observer: `resetDistinct()` zeroes both latches, then
  `restore('INT-14')` → `reserveMw 750→800`, `events.add(RESTORE)`.

**Must print**

```text
── 6 ── 50.00 then ACK restore INT-14
[reserveMw] 750 → 800
[events] RESTORE INT-14 — 50MW
  reserveMw=800 openSheds=0
```

ACK is **not** `toHandle` again. A second handle would double every
later SHED.

---

### Step 7 — 49.70 Hz on INT-14

**Lesson:** after ACK the same shed is a **new** pulse.

**Drive**

```dart
h.setHz(49.70);
await h.publishTick();
```

**Must print**

```text
── 7 ── 49.70 Hz on INT-14
[events] SHED INT-14 — 49.70Hz load=420MW
[rtuQ] enqueued RtuJob(INT-14, shed)
[events] RTU INT-14 — shed
[reserveMw] 800 → 750
[shedMap] INT-14 +50MW
  new sheds: 1
```

This is SHED pulse #2 (of four).

---

### Step 8 — Hz 48.0, load -10, SOC 101 (TestCell)

**Lesson:** Cell ingress ≠ Tissue. Shape dies at the edge. The event
log never hears about a tick that was not published.

**Drive**

```dart
final rejectedHz = h.setHz(48.0);
final rejectedLoad = h.setLoad(-10);
final rejectedSoc = h.setSoc(101);
```

**What fires**

- `_hzRange` unwraps `Pulse.payload`, sees `48.0`, returns `false`.
  `_hz` cache is **not** overwritten.
- `_loadRange` rejects `-10`. `_loadMw` unchanged.
- `_socRange` rejects `101`. `_soc` unchanged.
- `publishTick` is **not** called. Tissue idle.

**Must print**

```text
── 8 ── Hz 48.0, load -10, SOC 101
  hz 48.0 accepted=false
  load -10 accepted=false
  soc 101 accepted=false
  events grew: 0
```

**Must not happen**

- No `TestTissue` involvement.
- No `[ingress]` lines required if `setHz` / `setLoad` / `setSoc`
  swallow the rejection (the executable reports via the accepted
  flags).

---

### Step 9 — ACK, recover, 49.70, RTU fail-once

**Lesson:** queue + retry. One SHED pulse, two RTU attempts.

**Drive**

```dart
await h.ack('INT-14');
h.setHz(50.00);
await h.publishTick();
h.setHz(49.70);
h.rtuFailOnce = true;
await h.publishTick();
```

**What fires**

- ACK 9-pre clears Distinct and restores the INT-14 shed.
- `50.00` tick is `hold` (resets latch to hold).
- `49.70` tick → SHED. `_driveRtu` throws once (`rtuFailOnce`), then
  retries and appends `RTU INT-14 — shed (retry)`.
- `rtuAttempts` ends at 5: prior successes (3, WARN, 7) plus
  fail + retry on 9b.

**Must print**

```text
── 9 ── ACK, recover, 49.70, RTU fail-once
[reserveMw] 750 → 800
[events] RESTORE INT-14 — 50MW
[events] SHED INT-14 — 49.70Hz load=420MW
[rtuQ] enqueued RtuJob(INT-14, shed)
[events] RTU INT-14 — shed (retry)
[reserveMw] 800 → 750
[shedMap] INT-14 +50MW
  new sheds: 1
  rtuAttempts=5
```

SHED pulse count for this step is **1**. The retry is RTU I/O, not a
second Receptor fire.

---

### Step 10 — restore, ACK, 49.70 on INT-15

**Lesson:** TissueMap. A second feeder enters the shed map.

**Drive**

```dart
await h.ack('INT-14');
h.setFeeder('INT-15');
h.setHz(49.70);
await h.publishTick();
```

**What fires**

- ACK restores INT-14 (`reserveMw 750→800`).
- `INT-15` tick → SHED. `applyShed('INT-15', 50)` writes a second map
  row and decrements reserve (`800→750`).

**Must print**

```text
── 10 ── restore, ACK, 49.70 on INT-15
[reserveMw] 750 → 800
[events] RESTORE INT-14 — 50MW
[events] SHED INT-15 — 49.70Hz load=420MW
[rtuQ] enqueued RtuJob(INT-15, shed)
[events] RTU INT-15 — shed
[reserveMw] 800 → 750
[shedMap] INT-15 +50MW
  new sheds: 1
  openSheds=1
```

SHED pulse #4.

---

### Step 11 — force reserve to 30, then SHED 50 (TestTissue)

**Lesson:** non-negative / under-frequency guard. No orphan map row.

**Drive**

```dart
h.reserveMw.set(30);
h.setFeeder('INT-16');
final okShed = h.applyShed('INT-16', 50);
```

**What fires**

- `reserveMw.set(30)` writes 30 (30 ≥ 0, rule passes). This is an
  out-of-band force — the walkthrough uses it to reach a state where
  a new 50 MW shed cannot be covered.
- `applyShed('INT-16', 50)` pre-checks `30 < 50` → returns `false`
  **before** writing the map row. `shedMap` is unchanged
  (`openSheds=1` from INT-15).

**Must print**

```text
── 11 ── force reserve to 30, then SHED 50
  applyShed ok=false
  reserveMw=30 openSheds=1
```

No `[reserveMw]` transition line. No `[shedMap]` line. No new SHED row.

**Documented deviation.** The walkthrough expects `applyShed ok=false`
and a reserve of `30`. The demo produces both. The forced-low beat is
a deliberate policy break to prove the `TestTissue` guard; the
header documents it.

---

### Step 12 — restore INT-15

**Lesson:** compensate on Tissue. The restore returns MW from the
shed map back to `reserveMw`.

**Drive**

```dart
final ok12 = h.restore('INT-15');
```

**What fires**

1. Look up `shedMap['INT-15']`.
2. Remove the map row.
3. `reserveMw.set(30 + 50)` — prints `[reserveMw] 30 → 80`.
4. `events.add(RESTORE INT-15)`.

**Must print**

```text
── 12 ── restore INT-15
[reserveMw] 30 → 80
[events] RESTORE INT-15 — 50MW
  restore ok=true
  reserveMw=80 openSheds=0
```

**Documented deviation.** The walkthrough's prose implies restore
returns to `800`, but with `reserveMw` forced to `30` in §11 the
maximum possible return is `80`. The demo prints the self-consistent
value and documents the deviation.

---

### Step 13 — ACK without an open shed

**Lesson:** restore ≠ invent MW. ACK with no open shed only resets
Distinct.

**Drive**

```dart
final r13 = h.reserveMw.value;
await h.ack('ALL');
```

**What fires**

- `ackIn` observer: `resetDistinct()`. Since `who == 'ALL'`, no
  restore is attempted.
- `events.add(ACK ALL)`.

**Must print**

```text
── 13 ── ACK without an open shed
[events] ACK ALL — distinct cleared
  reserveMw=80 openSheds=0 unchanged=true
```

`unchanged=true` proves the ACK did not touch the reserve.

---

### COMPLY — council.add(...) blocked; length == events.length

**Lesson:** `events.unmodifiable` is a live, zero-copy deputy.
Writes are blocked (throw **or** silent swallow). Reads share
storage.

**Drive**

```dart
final council = h.events.unmodifiable;
final eventsBefore = h.events.length;
var blocked = false;
try {
  council.add(GridEvent(kind: 'HACK', ...));
  blocked = h.events.length == eventsBefore;
} catch (_) {
  blocked = true;
}
```

**What fires**

- `council.add` must not grow `events`.
- `council.length == events.length` after the attempt.

**Must print**

```text
── COMPLY ── council.add(...) blocked; length == events.length
  council.add blocked=true
  council.length=19 events.length=19
```

19 rows in the last good run:

| Kind | Count | Feeders |
|---|---|---|
| SHED (observer) | 4 | INT-14 ×3, INT-15 ×1 |
| RTU | 5 | INT-14 ×4 (one retry), INT-15 ×1 |
| WARN | 1 | INT-14 |
| RESTORE | 4 | INT-14 ×3, INT-15 ×1 |
| ACK | 1 | ALL |
| SHED (bookkeeping) | 1 | INT-15 (from `applyShed`) |
| RESTORE (bookkeeping) | 1 | INT-14 (from `restore`) — already counted above |
| **Total** | **19** | |

---

### Trailer

**Must print**

```text
------------------------------------------------------------------------
ticks=12 sheds=4 warns=1 events=19 rtuAttempts=6
reserveMw=80 openSheds=0
councilLength=19 (same as events)
------------------------------------------------------------------------
```

Then `h.dispose()` stops every observer attached in `install`.

---

## Pulse path (scenario 2 then 3)

```
protected.add('HOSP-1')
  TestTissue on TissueSet pass
  ElementAdded<String>

setFeeder('HOSP-1'); setHz(49.70); publishTick
  actionOf → hold (protected) → Filter drop both gates

setFeeder('INT-14'); setHz(49.70); publishTick
  shed Receptor: MapValue shed → Distinct emit → Filter pass
  warn Receptor: Filter drop
  observe SHED
    events.add(...)           → ElementAdded<GridEvent>
    rtuQ.addLast(...)         → ElementAdded<RtuJob>
    applyShed 50 MW
      reserveMw.set(750)      → ElementUpdated<int>
      shedMap[INT-14] = ...   → ElementAdded<Shed>
  AsyncMapWithRetry → RTU cell
```

Scenario 8 stops at `hzIn.emit` / `loadIn.emit` / `socIn.emit`.
Tissue is idle.

Scenario 10 never enters `actionOf` for the debit. The ACK observer
calls `restore`. If you debit inside `actionOf`, two SHEDs before
ACK will steal the reserve twice.

---

## Who owns the lock

| Event | Lock |
|---|---|
| `actionOf` + Distinct + Filter | Receptor lock on `shedCell` / `warnCell` |
| `events.add` | TissueList lock |
| `reserveMw` write | TissueValue lock |
| `shedMap[id] = ...` | TissueMap lock |
| RTU Future | `AsyncMapWithRetry` |

Do not “fix” a race by putting `events.add` inside the Instruction.
Teach the two locks.

---

## Real desk vs this file

| Still missing | Suggested next piece |
|---|---|
| Snapshot is a Dart cache | area Nucleus / `Cell.synthesis` |
| No 6–10 s “frequency still low” | `Debounce` in front of `tickIn` |
| AGC / tie-line | extra ingress + third Receptor |
| Joint commit across tissues | `Cell.transaction` when the API allows |
| Multi-area reserve table | `TissueMap<String, int>` + `TestTissue` on MW |
| Persistent historian | same Tissue API in front of a store; demo stays in-process |

Flow stays on “is this SHED / WARN?”
TestCell stays on the **Hz / MW / SOC ingress**.
TestTissue stays on **collection mutations**.
ACK stays a flag on Distinct.
Tissue stays the **reserve books and the protected-feeder set**.
Deputy stays the **reliability-council screen**.

---

## Acceptance

1. `dart run grid-demand-response(tissue)-Demo.dart` matches the
   scenario **Result** column.
2. Exactly **two** `toHandle(` calls for the action gates, both in
   `installGates`, none in ACK.
3. `actionOf` has no `await`, no `reserveMw` write, no `events.add`.
4. Scenario 2 mutates `protected` **before** the HOSP-1 tick.
5. Scenario 8 prints TestCell rejection and does not append events.
6. Scenario 9 shows a retry in `rtuAttempts` and still **one** new
   SHED after reset.
7. Shed/restore keep the invariant
   `reserveMw + sum(droppedMw) == 800` except the forced-low beat
   of scenario 11, which must restore before 12.
8. COMPLY: read-only deputy blocked on `add`, live on `length`.
9. Header diagram matches this document.
10. No Dart `List<GridEvent>` is the system of record.
11. Every Tissue constructor / `.deputy(` passes **`TestTissue`**
    (or defaults to `TestTissue.allowAll`). Zero `testRule: TestCell`
    on those calls.

---

## Documented deviations (summary)

The walkthrough's prose and its historical sample console contradicted
each other at three points. This document is reconciled to the **prose**
(the policy) and the **self-consistent** run. The three deviations
are recorded here and in the Dart file header:

1. **§2 — `HOSP-1` is held.** The prose says “must stay hold”; the
   sample console showed a shed. The demo follows the prose;
   `actionOf` returns `hold` for `HOSP-1` because it is protected.
2. **§11–§12 — reserve forced to `30`.** The prose asked to force
   `reserveMw` to `30` and also expected restore to bring it back to
   `800`. Those cannot both be true; the restore returns exactly the
   `50` MW that was held, so `30 → 80`. The demo prints the
   self-consistent value.
3. **Trailer — stale counts.** The prose listed `events=17` and
   `rtuAttempts=5`. The self-consistent counts (WARN RTU included,
   fail-once retry counted, `applyShed`'s bookkeeping SHED row
   included) are `events=19` and `rtuAttempts=6`.

The **policy** is unchanged by these deviations. Only the sample
numbers are.

---

## Name plate

| Artifact | Name |
|---|---|
| This requirement / walkthrough | `grid-demand-response(tissue)-WalkThrough.md` |
| Demo | `grid-demand-response(tissue)-Demo.dart` |
| Mobility sibling | `ride-hail-dispatch(tissue)-WalkThrough.md` |
| Payments sibling | `card-auth-pipeline(tissue)-WalkThrough.md` |
| Clinical sibling | `ICU-alarm-pipeline(enhanced)-WalkThrough.md` |
| Architecture note | `grid-demand-response(tissue)-ARCHITECTURE.md` |
| Feature catalogue | `grid-demand-response(tissue)-FEATURES.md` |

This is the **energy / reliability-council** lesson. Do not rename
the other industry files. Optional later:
`grid-demand-response(enhanced)-WalkThrough.md` as a Flow-only
sibling with a Dart `List` event log.