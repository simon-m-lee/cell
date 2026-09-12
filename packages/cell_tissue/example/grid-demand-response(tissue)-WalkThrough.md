# Walkthrough requirement — grid demand-response (Flow + Tissue)

**Suggested demo:** `grid-demand-response(tissue)-Demo.dart`  
**Siblings (same graph, other industries):**  
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
                               sheds.remove(feeder)          TissueMap
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
    required this.kind,  // SHED | WARN | RESTORE | RTU | PROTECT
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
| `sheds` | `TissueMap<String, Shed>` | feeder id + `droppedMw > 0` | SHED observer, ACK | ops |
| `protected` | `TissueSet<String>` | `AREA-N` style uppercase | ops scenario | `actionOf` |
| `rtuQ` | `TissueQueue<RtuJob>` | `capacity: 32` | shed/warn observer | RTU pump |

Seed: `reserveMw = TissueValue<int>(800, testRule: mwRule)`,
`sheds` empty, `protected` empty, `events` empty (initial population
silent).

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

### Operators

Flow: `MapValue`, `Filter`, custom Distinct, `AsyncMapWithRetry`
(`count`), `Cell.observe`, `Cell.ingress(testRule:)` with **TestCell**.

Tissue: `TissueList`, `TissueValue`, `TissueMap`, `TissueSet`,
`TissueQueue`, `TestTissue`, `TestTissue.readOnly`, `.unmodifiable`,
`.deputy`.

---

## Reserve — TissueValue + TissueMap, not inside actionOf

A SHED that the observer accepts:

```text
sheds[feeder] = Shed(feeder, droppedMw)
reserveMw.value = reserveMw.value! - droppedMw
events.add(GridEvent(kind: 'SHED', ...))
```

If `reserveMw` TestTissue would go negative, **do not** leave a map
row. Restore ACK reverses the two numbers and appends `RESTORE`.

**Invariant** after every successful money-of-the-grid method:

```
reserveMw.value! + sum(sheds.values.droppedMw) == 800
```

Never decrement reserve inside `actionOf`. Demo `droppedMw` is a
fixed `50` per shed so the arithmetic stays talk-track simple.

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

---

## Scenarios

Seed area `NORTH`, feeder `INT-14`, Hz `50.00`, load `420`, SOC `60`,
reserve `800`, `protected` empty.

| # | Drive | Result | Demonstrates |
|---|---|---|---|
| Seed | 50.00 / INT-14 | one tick, **no** SHED | bus + Filter |
| 1 | repeat 50.00 | no SHED | Distinct on `hold` |
| 2 | `protected.add('HOSP-1')`, 49.70 on `HOSP-1` | **no** SHED | TissueSet feeds `actionOf` |
| 3 | 49.70 on `INT-14` | **SHED** + event + RTU job | Distinct `hold`→`shed` |
| 4–5 | 49.70 again, then 49.72 | **no** new SHED | Distinct holds |
| WARN | 49.85 / SOC 10 / load 600 | **WARN** | second Receptor |
| 6 | 50.00 then ACK restore `INT-14` | Distinct cleared; reserve back | ACK ≠ new `toHandle` |
| 7 | 49.70 on `INT-14` | **one** SHED | reset Distinct |
| 8 | Hz `48.0`, load `-10`, SOC `101` | TestCell lines; **no** tick | Cell ingress ≠ Tissue |
| 9 | ACK, recover, 49.70, RTU fail-once | **one** SHED; `rtuAttempts` includes retry | queue + retry |
| 10 | applyShed 50 MW already in 3/7; second feeder `INT-15` at 49.70 after ACK | two map rows or one — stay consistent with Distinct/ACK | TissueMap |
| 11 | force `reserveMw` to `30` then SHED 50 | TestTissue reject; map unchanged | non-negative reserve |
| 12 | `restore('INT-14')` | reserve += 50, map drops row, event `RESTORE` | return MW to pool |
| 13 | ACK without an open shed | Distinct reset; reserve unchanged | restore ≠ invent MW |
| COMPLY | `council.add(...)` | blocked; lengths match | live deputy |

Good-run order of magnitude: ticks ≥ 16, sheds 2–4, warns 1,
events ≥ 6 plus RESTORE. Print a trailer:

```text
ticks=… sheds=… warns=… events=… rtuAttempts=…
reserveMw=… openSheds=…
councilLength=… (same as events)
```

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
  observe SHED
    events.add(...)     → ElementAdded<GridEvent>
    rtuQ.addLast(...)   → ElementAdded<RtuJob>
    applyShed 50 MW
  AsyncMapWithRetry → RTU cell
```

Scenario 8 stops at `hzIn.emit`. Tissue is idle.

---

## Who owns the lock

| Event | Lock |
|---|---|
| `actionOf` + Distinct + Filter | Receptor lock |
| `events.add` | TissueList lock |
| `reserveMw` write | TissueValue lock |
| `sheds[id] = ...` | TissueMap lock |
| RTU Future | `AsyncMapWithRetry` |

---

## Real desk vs this file

| Still missing | Suggested next piece |
|---|---|
| Snapshot is a Dart cache | area Nucleus / `Cell.synthesis` |
| No 6–10 s “frequency still low” | `Debounce` in front of `tickIn` |
| AGC / tie-line | extra ingress + third Receptor |
| Joint commit across tissues | `Cell.transaction` when the API allows |
| Multi-area reserve table | `TissueMap<String, int>` + `TestTissue` on MW |
| Persistent historian | same Tissue API in front of a store |

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
7. Shed/restore keep
   `reserveMw + sum(droppedMw) == 800` except the forced-low beat
   of scenario 11, which must restore before 12.
8. COMPLY: read-only deputy blocked on `add`, live on `length`.
9. Header diagram matches this document.
10. No Dart `List<GridEvent>` is the system of record.
11. Every Tissue constructor / `.deputy(` passes **`TestTissue`**
    (or defaults to `TestTissue.allowAll`). Zero `testRule: TestCell`
    on those calls.

---

## Name plate

| Artifact | Name |
|---|---|
| This requirement / walkthrough | `grid-demand-response(tissue)-WalkThrough.md` |
| Demo to implement next | `grid-demand-response(tissue)-Demo.dart` |
| Mobility sibling | `ride-hail-dispatch(tissue)-WalkThrough.md` |
| Payments sibling | `card-auth-pipeline(tissue)-WalkThrough.md` |
| Clinical sibling | `ICU-alarm-pipeline(enhanced)-WalkThrough.md` |

This is the **energy / reliability-council** lesson. Do not rename
the other industry files. Optional later:
`grid-demand-response(enhanced)-WalkThrough.md` as a Flow-only
sibling with a Dart `List` event log.
