# Walkthrough requirement — airport baggage flow watch (Cell)

**Suggested demo:** `baggage-flow-watch(Cell)-Demo.dart`  
**Siblings:**  
- `aircraft-gate-turnaround-WalkThrough.md` — ramp / gate turnaround (Cell core only)  
- `ride-hail-dispatch(Cell)-WalkThrough.md` — mobility match + Tissue books  
- `card-auth-pipeline(Cell)-WalkThrough.md` — risk gate + ledger  

**Industry:** airport baggage handling (departing bags: check-in → sorter → make-up carousel → aircraft side)  
**Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`

This is the **executable requirement** for a real-time baggage operations demo that uses:

- **Cell** for state, ingress, derivation, observation, and governance  
- **Flow** for the “at-risk” decision pipeline and belt-stop alert pipeline  
- **Tissue** for the operational books (bags, incidents, alerts, daily performance)

Do not fold Tissue into a Receptor. Do not fold Flow into the incident log.  
The point of this file is the seam: Flow decides *what is at risk / what is jammed*; Tissue owns the books the duty manager and airline liaison read.

---

## Contents

1. [TestCell vs TestTissue (do not swap)](#testcell-vs-testtissue-do-not-swap)
2. [Why Flow + Tissue (not Cell alone)](#why-flow--tissue-not-cell-alone)
3. [Design](#design)
4. [Domain](#domain)
5. [Parts](#parts)
   - [Flow Cells / ingress](#flow-cells--ingress)
   - [Custom / stock instructions](#custom--stock-instructions)
   - [Tissue collections](#tissue-collections)
   - [Deputies](#deputies)
   - [Operators the demo must actually call](#operators-the-demo-must-actually-call)
6. [At-risk decision & belt-stop decision](#at-risk-decision--belt-stop-decision)
7. [Implementation map](#implementation-map)
8. [Scenarios](#scenarios)
9. [Executable steps](#executable-steps)
10. [Pulse path (jam + at-risk bag)](#pulse-path-jam--at-risk-bag)
11. [Who owns the lock](#who-owns-the-lock)
12. [Real airport vs this file](#real-airport-vs-this-file)
13. [Acceptance](#acceptance)
14. [Name plate](#name-plate)

---

## TestCell vs TestTissue (do not swap)

| Host | Rule type | Parameter | Typical use in this demo |
|---|---|---|---|
| `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` | bag tag non-empty, flight shape, position in allowed set, stop duration ≥ 0 |
| `TissueList` / `Set` / `Map` / `Queue` / `Value` | `TestTissue<E, C>` | `testRule:` | append-only incident log, non-empty bag tag, status transitions, capacity |
| `tissue.deputy(...)` | `TestTissue` | `testRule:` | `TestTissue.readOnly` for airline liaison / compliance view |
| `TestTissue.allowAll` | `TestTissue` | default | only when the collection has no extra rule |

Illegal (will not type-check):

```dart
TissueList<Incident>(testRule: TestCell.allowAll);          // wrong type
TissueMap<String, Bag>(..., testRule: bagTagRule);         // bagTagRule is TestCell
incidents.deputy(testRule: TestCell.readOnly);             // deputy wants TestTissue
```

Required shape:

```dart
final incidentRule = TestTissue<Incident, TissueList<Incident>>(
  (e, {host, action, user}) {
    // allow add / addAll; deny remove / clear / []=
    if (action == TissueAction.remove || action == TissueAction.clear) return false;
    return e.id.isNotEmpty && e.start != null;
  },
);

final incidents = TissueList<Incident>(testRule: incidentRule);

final bagRule = TestTissue<Bag, TissueMap<String, Bag>>(
  (b, {host, action, user}) =>
      b != null && b.tag.isNotEmpty && b.flight.isNotEmpty,
);

final bags = TissueMap<String, Bag>(testRule: bagRule);
```

`Cell.ingress(testRule: tagShape)` stays **TestCell**. That rule never becomes the `testRule` on a Tissue.

---

## Why Flow + Tissue (not Cell alone)

Cell alone is enough for a single stand (see aircraft-gate-turnaround).  
Baggage Flow Watch needs:

| Concern | Why Flow / Tissue |
|---|---|
| Continuous bag position stream | `Cell.ingress` + Flow operators (`distinct`, `debounce`, `map`) |
| “At risk” calculation (time remaining vs MCT) | pure policy inside a Flow instruction / chain |
| Belt / sorter / carousel stop > 60 s | debounce / filter on stop events → alert |
| Group related bag alerts into one incident | TissueMap / TissueList of open incidents |
| Acknowledge + free-text note + audit trail | Tissue writes with full causal Pulse |
| Daily airline performance report | TissueList of bag outcomes + deputy read-only view |
| Role-based visibility (no PII to airlines) | `Cell.sanitized` + Tissue deputy |

Flow owns the *decision* (at-risk flag, jam alert).  
Tissue owns the *books* (live bag map, open incidents, closed incident log, daily aggregates).  
Observers are the only glue.

---

## Design

```text
                          ┌──────────────────────────────────────────────────────────┐
                          │              BaggageFlowWatchHarness                      │
                          │                                                          │
  scan events ──────────► bagScanIn (ingress + TestCell)                             │
  flight updates ───────► flightIn  (ingress + TestCell)                             │
  belt status ──────────► beltStatusIn (ingress)                                     │
  ack / note ───────────► ackIn                                                      │
                          │      │                                                   │
                          │      ▼                                                   │
                          │  publishScan() / publishBelt()                           │
                          │      │                                                   │
                          │      ├──► AtRiskDecisionInstruction + MapValue           │
                          │      │        └─► toHandle ──► atRiskCell                │
                          │      │                                                   │
                          │      └──► BeltStopDecisionInstruction + MapValue         │
                          │               └─► toHandle ──► jamCell                   │
                          │                                                          │
                          │  Cell.observe(atRiskCell / jamCell / ackIn)              │
                          │      │                                                   │
                          │      ▼                                                   │
                          │  bags / openIncidents / incidentLog / dailyStats         │
                          │  (TissueMap / TissueList / TissueValue)                  │
                          └──────────────────────────────────────────────────────────┘
```

| Requirement (from BRD) | Owner |
|---|---|
| FR-01 real-time bag position | `TissueMap<String, Bag>` updated by scan observer |
| FR-02 time remaining to close-out | derived inside `AtRiskDecisionInstruction` |
| FR-03 flag “at risk” when remaining < MCT | same instruction |
| FR-04 single screen of at-risk bags | derived view / deputy of `bags` filtered by status |
| FR-05 alert on belt stop > 60 s | `BeltStopDecisionInstruction` + debounce |
| FR-06 alert payload (belt, #bags, flights) | instruction emits rich `JamAlert` |
| FR-07 acknowledge + action taken | `ackIn` → Tissue write on open incident |
| FR-08 group alerts into one incident | harness groups by cause / belt before Tissue write |
| FR-09 open incidents across terminals | `TissueMap` keyed by incident id, terminal field |
| FR-10 daily report by airline | `TissueList` of closed outcomes + aggregate |
| FR-11 free-text note | stored on `Incident` |
| FR-12 export incidents | deputy / unmodifiable view → CSV/PDF outside the graph |
| DR-01…DR-06 data shape & retention | enforced by TestTissue + retention policy outside demo |
| BR-01 diplomatic / hazardous never auto-reroute | TestCell / policy gate (no re-route path in v1) |
| BR-02 no alert after close-out | instruction checks flight status |
| BR-03 acknowledge within 15 min | escalation timer outside / observe side-effect |
| NFR-01 update ≤ 5 s | ingress cadence + distinct |
| NFR-04 role-based | deputies + Context |
| NFR-05 full audit of ack | every Tissue write carries Pulse provenance |

---

## Domain

```dart
enum BagStatus { inSystem, atRisk, recovered, missed, closed }

enum BeltStatus { running, stopped, unknown }

enum IncidentStatus { open, acknowledged, resolved, escalated }

/// One departing bag as seen by the system.
final class Bag {
  const Bag({
    required this.tag,           // bag tag number (unique)
    required this.flight,        // e.g. BA482
    required this.airline,       // BA
    required this.terminal,      // 1..4
    required this.position,      // check-in | sorter-in | sorter-out | carousel | aircraft-side
    required this.lastScan,      // DateTime
    required this.status,
    this.closeOut,               // baggage close-out time
    this.mctMinutes = 35,        // minimum connection / processing time
  });
  final String tag;
  final String flight;
  final String airline;
  final int terminal;
  final String position;
  final DateTime lastScan;
  final BagStatus status;
  final DateTime? closeOut;
  final int mctMinutes;
}

/// Snapshot of a flight’s baggage close-out window.
final class FlightWindow {
  const FlightWindow({
    required this.flight,
    required this.airline,
    required this.terminal,
    required this.scheduledDeparture,
    required this.closeOut,
  });
  final String flight;
  final String airline;
  final int terminal;
  final DateTime scheduledDeparture;
  final DateTime closeOut;
}

/// One scan event from the belt / sorter / carousel system.
final class BagScan {
  const BagScan({
    required this.tag,
    required this.flight,
    required this.position,
    required this.at,
    this.terminal = 2,
  });
  final String tag;
  final String flight;
  final String position;
  final DateTime at;
  final int terminal;
}

/// Belt / sorter / carousel status pulse.
final class BeltEvent {
  const BeltEvent({
    required this.deviceId,      // e.g. T2-BELT-07
    required this.status,
    required this.at,
    this.terminal = 2,
  });
  final String deviceId;
  final BeltStatus status;
  final DateTime at;
  final int terminal;
}

/// Decision emitted by the at-risk pipeline.
final class AtRiskDecision {
  const AtRiskDecision({
    required this.bag,
    required this.remainingMinutes,
    required this.isAtRisk,
  });
  final Bag bag;
  final int remainingMinutes;
  final bool isAtRisk;
}

/// Decision emitted by the jam pipeline.
final class JamAlert {
  const JamAlert({
    required this.deviceId,
    required this.terminal,
    required this.stoppedSince,
    required this.affectedBags,
    required this.flightsAtRisk,
  });
  final String deviceId;
  final int terminal;
  final DateTime stoppedSince;
  final int affectedBags;
  final List<String> flightsAtRisk;
}

/// Grouped operational incident (one cause, many bags).
final class Incident {
  const Incident({
    required this.id,
    required this.terminal,
    required this.deviceId,
    required this.start,
    this.end,
    required this.status,
    required this.affectedTags,
    required this.flightsAtRisk,
    this.ackBy,
    this.ackAt,
    this.actionTaken,
    this.note,
  });
  final String id;
  final int terminal;
  final String deviceId;
  final DateTime start;
  final DateTime? end;
  final IncidentStatus status;
  final List<String> affectedTags;
  final List<String> flightsAtRisk;
  final String? ackBy;
  final DateTime? ackAt;
  final String? actionTaken;
  final String? note;
}

/// One row in the daily airline performance report.
final class AirlineDayStat {
  const AirlineDayStat({
    required this.airline,
    required this.bagsHandled,
    required this.bagsDelayed,
    required this.bagsMissed,
    required this.avgProcessingMinutes,
  });
  final String airline;
  final int bagsHandled;
  final int bagsDelayed;
  final int bagsMissed;
  final double avgProcessingMinutes;
}
```

Pulse **types** useful for a hub (optional):

| Type | Payload | Goes to |
|---|---|---|
| `SCAN` | `BagScan` | bag position update |
| `BELT` | `BeltEvent` | jam detection |
| `ACK` | `String` (incident id + action) | acknowledge path |
| `FLIGHT` | `FlightWindow` | close-out window cache |

---

## Parts

### Flow Cells / ingress

| Cell | Input | TestCell / notes | Output |
|---|---|---|---|
| `bagScanIn` | `BagScan` | tag non-empty, flight shape, position in allowed set | `Pulse<BagScan>` |
| `flightIn` | `FlightWindow` | flight shape, closeOut after scheduled | `Pulse<FlightWindow>` |
| `beltStatusIn` | `BeltEvent` | deviceId non-empty | `Pulse<BeltEvent>` |
| `ackIn` | `String` (or structured Ack) | non-empty | `Pulse<String>` |
| `atRiskCell` | materialised chain | — | `Pulse<AtRiskDecision>` (or narrowed) |
| `jamCell` | materialised chain | — | `Pulse<JamAlert>` |

Allowed positions (TestCell):  
`{'check-in', 'sorter-in', 'sorter-out', 'carousel', 'aircraft-side'}`.

Flight shape (same as aircraft demo):  
`^[A-Z][A-Z0-9][0-9]{1,4}$` (BA482 and U2871 both accepted).

### Custom / stock instructions

Two decision paths, each composed as a small chain:

1. **At-risk path**  
   `AtRiskDecisionInstruction` (custom, extends `FlowInstructionBase`)  
   + stock `MapValue` / `Filter` / `DistinctUntilChanged` as needed  
   → `toHandle` → `atRiskCell`

2. **Belt-stop path**  
   `BeltStopDecisionInstruction` (custom)  
   - internal: keep last “stopped” timestamp per device  
   - emit `JamAlert` only when stop duration ≥ 60 s and flight not closed  
   + stock projection  
   → `toHandle` → `jamCell`

Suggested pure policy (unit-testable without graph):

```dart
static AtRiskDecision decide(Bag bag, DateTime now) {
  if (bag.closeOut == null) {
    return AtRiskDecision(bag: bag, remainingMinutes: 999, isAtRisk: false);
  }
  final remaining = bag.closeOut!.difference(now).inMinutes;
  final atRisk = remaining < bag.mctMinutes && bag.status != BagStatus.missed;
  return AtRiskDecision(bag: bag, remainingMinutes: remaining, isAtRisk: atRisk);
}
```

Belt-stop policy:

```dart
static JamAlert? decide(BeltEvent e, DateTime? stoppedSince, Iterable<Bag> onDevice, DateTime now) {
  if (e.status != BeltStatus.stopped) return null;
  final since = stoppedSince ?? e.at;
  if (now.difference(since).inSeconds < 60) return null;
  final bags = onDevice.where((b) => b.status == BagStatus.inSystem || b.status == BagStatus.atRisk);
  final flights = bags.map((b) => b.flight).toSet().toList();
  return JamAlert(
    deviceId: e.deviceId,
    terminal: e.terminal,
    stoppedSince: since,
    affectedBags: bags.length,
    flightsAtRisk: flights,
  );
}
```

### Tissue collections

| Tissue | Type | TestTissue rule | Who writes | Who reads |
|---|---|---|---|---|
| `bags` | `TissueMap<String, Bag>` | key = tag, tag & flight non-empty | scan / at-risk observers | duty manager view |
| `openIncidents` | `TissueMap<String, Incident>` | status == open \| acknowledged | jam / ack observers | duty manager, supervisor |
| `incidentLog` | `TissueList<Incident>` | append-only | resolve path | Safety & Compliance, daily report |
| `dailyStats` | `TissueMap<String, AirlineDayStat>` | airline code non-empty | end-of-day aggregator | airline liaison |
| `deviceLastStop` | `TissueMap<String, DateTime>` | — | belt observer | jam instruction (via harness) |

Seed every collection with an explicit `TestTissue`.  
Use `TissueList` for the immutable history (`incidentLog`); use `TissueMap` for live lookups.

### Deputies

```dart
final bagsView = bags.unmodifiable;                    // live zero-copy
final auditor = incidentLog.deputy(
  testRule: TestTissue.readOnly,
);
final airlineReport = dailyStats.unmodifiable;         // no PII
```

Airline reports must never contain passenger personal data (BR-04).  
The demo keeps only tag, flight, airline, timings — no passenger name.

### Operators the demo must actually call

| Operator / API | Where | Purpose |
|---|---|---|
| `Cell.ingress` | `install()` | bagScanIn, flightIn, beltStatusIn, ackIn |
| `TestCell` | on ingress | shape / range validation |
| custom `FlowInstruction` + `+` / `toHandle` | `installGates()` | at-risk and jam decisions |
| `Cell.observe` | `install()` | the only glue → Tissue writes |
| `TissueMap[]=` / `TissueList.add` / `TissueValue.set` | observers | books |
| `Cell.debounce` / `Cell.distinct` | optional on belt stream | suppress chatter |
| `Cell.sanitized` | optional | redact before any external export Cell |
| `deputy` / `unmodifiable` | compliance path | read-only views |

Do **not** write Tissue inside the pure `decide` functions.  
Do **not** put acknowledge logic inside the jam instruction; ACK is a separate ingress + observer.

---

## At-risk decision & belt-stop decision

### At-risk

1. Scan arrives → `bagScanIn`  
2. Harness upserts a `Bag` into a transient cache (or reads current Tissue)  
3. Publishes a tick into the at-risk chain  
4. `AtRiskDecisionInstruction` computes remaining time vs MCT  
5. If `isAtRisk` and flight not closed → emit  
6. Observer writes/updates `bags[tag]` with `BagStatus.atRisk`  
7. Optionally opens or attaches to an incident if the same cause already exists

### Belt-stop

1. `BeltEvent(stopped)` → `beltStatusIn`  
2. Harness records `deviceLastStop[deviceId] = now` if first stop  
3. After 60 s of continuous stop (debounce or instruction latch) → emit `JamAlert`  
4. Observer creates or updates an `Incident` in `openIncidents`  
5. Supervisor acknowledges via `ackIn` → status → acknowledged, note stored  
6. On resolve → move to `incidentLog`, clear from `openIncidents`

Escalation (BR-03): if no ACK within 15 minutes, a side-effect timer (outside the pure graph) can emit an escalation pulse that the duty-manager observer handles.

---

## Implementation map

| WalkThrough part | Demo location |
|---|---|
| Domain types | `Bag`, `FlightWindow`, `BagScan`, `BeltEvent`, `AtRiskDecision`, `JamAlert`, `Incident`, `AirlineDayStat` |
| Custom instructions | `AtRiskDecisionInstruction`, `BeltStopDecisionInstruction` |
| Chain composition | `BaggageFlowWatchHarness.installGates` (`+`, `toHandle`) |
| Ingress + TestCell | `install()` |
| Tissue + TestTissue | `install()` — bags, openIncidents, incidentLog, dailyStats, deviceLastStop |
| Observers | scan → bags; at-risk → bags; jam → openIncidents; ack → openIncidents / incidentLog |
| Daily report | end-of-day or on-demand aggregator over incidentLog + bags |
| Scenarios | `main()` seed + numbered scenarios |
| Acceptance console | trailer printing key counts |

---

## Scenarios

| # | Drive | Expected result | Demonstrates |
|---|---|---|---|
| Seed | 3 bags scanned into T2 sorter, 1 flight window | bags.length == 3, no at-risk | baseline |
| 1 | Advance clock so one bag remaining < MCT | that bag status → atRisk | FR-02, FR-03 |
| 2 | Same bag scanned again (same position) | no duplicate at-risk pulse (distinct) | alert hygiene |
| 3 | Belt T2-BELT-07 stops for 70 s | one JamAlert, one open Incident | FR-05, FR-06 |
| 4 | Supervisor ACK with note “tag reader fault, cleared” | Incident status → acknowledged | FR-07, FR-11 |
| 5 | Belt resumes; bags move; resolve incident | Incident moves to incidentLog | audit trail |
| 6 | Bag reaches aircraft-side before close-out | status → recovered | happy path |
| 7 | Bag still short after close-out | status → missed, recorded | failure path |
| 8 | Second terminal (T4) jam | openIncidents shows both terminals | FR-09 |
| 9 | Attempt scan with empty tag | rejected by TestCell | DR-06 |
| 10 | Attempt alert on already-closed flight | instruction suppresses | BR-02 |
| 11 | Daily aggregate | AirlineDayStat for BA / U2 | FR-10, AR-01 |
| 12 | Compliance deputy | read-only view of incidentLog | NFR-05, BR-04 |
| 13 | Diplomatic bag flag (optional) | never auto-rerouted | BR-01 |

---

## Executable steps

### Seed

- Bind the graph.  
- Insert three bags for BA482 (T2) at sorter-in.  
- Publish one FlightWindow for BA482 with close-out 40 min from “now”.  
- Assert `bags.length == 3`, `openIncidents.isEmpty`.

### Step 1 — at-risk appears

- Advance simulated clock so remaining < MCT for one bag.  
- Publish a scan (or a pure tick) for that bag.  
- Assert that bag’s status is `atRisk` and an at-risk decision was observed.

### Step 2 — distinct

- Re-publish identical at-risk condition.  
- Assert no second at-risk emission (or no second Tissue status flip).

### Step 3 — jam

- Emit `BeltEvent(T2-BELT-07, stopped)`.  
- Advance 70 s.  
- Assert one `JamAlert` and one entry in `openIncidents`.

### Step 4 — acknowledge

- Emit ACK for that incident id with action “tag reader fault, cleared”.  
- Assert status `acknowledged`, `ackBy` / `ackAt` / `actionTaken` set.

### Step 5 — resolve

- Emit belt running + resolve.  
- Assert incident moved to `incidentLog`, removed from `openIncidents`.

### Steps 6–13

Follow the table above; each step should leave a clear console line that the acceptance trailer can check.

---

## Pulse path (jam + at-risk bag)

```text
BeltEvent(stopped) ──► beltStatusIn
                         │
                         ▼
              BeltStopDecisionInstruction
              (latch stop time, wait ≥ 60 s, count bags on device)
                         │
                         ▼
                    Pulse<JamAlert>
                         │
              Cell.observe ──► openIncidents[id] = Incident(...)

BagScan ──► bagScanIn
               │
               ▼
    (upsert Bag in harness / Tissue)
               │
               ▼
    AtRiskDecisionInstruction(decide)
               │
               ▼
    Pulse<AtRiskDecision> (isAtRisk == true)
               │
    Cell.observe ──► bags[tag] = bag.copyWith(status: atRisk)
```

Causal chain is preserved by every Pulse; the incident record stores who acknowledged and what action was taken (NFR-05).

---

## Who owns the lock

- **Ingress TestCell** — rejects malformed scans / flights before they enter the graph.  
- **Flow instruction** — decides at-risk / jam; pure policy + latch.  
- **Tissue TestTissue** — validates every book write (append-only log, non-empty keys, legal status).  
- **Observer** — the only place that mutates Tissue; never inside `map` / `decide`.  
- **Deputy** — read-only for airline liaison and compliance; cannot write.

There is no single global lock. Each Tissue owns its lock; Flow instructions do not hold Tissue locks.

---

## Real airport vs this file

| Real system | This demo |
|---|---|
| Belt control system feed every ≤ 15 s | Simulated `BagScan` / `BeltEvent` ingress |
| AODB flight times | `flightIn` + `FlightWindow` |
| Multiple terminals, thousands of bags | Small in-memory TissueMaps |
| 15-minute escalation to duty manager | Console message or simple timer |
| Daily PDF to airlines | Aggregate into `AirlineDayStat`; export left to host |
| Wi-Fi tablets, SSO | Out of scope (NFR / constraints) |
| Arriving / transfer bags | Explicitly out of scope (BRD 4.2) |
| Automatic re-routing | Forbidden; staff decide (BRD) |

The demo proves the **reactive decision + audited books** shape.  
It does not replace the belt PLC or the sorter.

---

## Acceptance

The demo is done when a last-good run:

1. Prints the scenario table with pass/fail for steps 1–13.  
2. Shows at least one at-risk bag correctly flagged.  
3. Shows one jam alert raised after ≥ 60 s stop.  
4. Shows that alert acknowledged and later moved to the incident log.  
5. Shows a daily stat row for at least one airline.  
6. Shows that a read-only deputy cannot mutate the incident log.  
7. Rejects an empty bag tag at ingress.  
8. Does not raise an alert for a flight already past close-out.

Optional but recommended:

- Console line proving Pulse provenance (who / when) on the ACK write.  
- Distinct suppresses a repeated at-risk pulse.

---

## Name plate

| Field | Value |
|---|---|
| Project | Baggage Flow Watch |
| Document | `baggage-flow-watch(Cell)-WalkThrough.md` |
| Framework | Mitosis — cell + cell_flow + cell_tissue |
| BRD | Airport Baggage Handling — Day 1 Requirements (v1.0, 2026-09-16) |
| Style | Matches ride-hail / card-auth / aircraft-gate-turnaround WalkThroughs |
| Scope | Departing bags only; real-time visibility, alerts, incidents, daily report |

---

*End of WalkThrough requirement.*
