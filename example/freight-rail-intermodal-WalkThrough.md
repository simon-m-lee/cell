
# WalkThrough — Rail Yard Flow Watch (Cell variant)

## Summary

*What a reader must understand* — This WalkThrough turns the freight-rail-intermodal BRD into an executable contract. One desk watches outbound container flow across four intermodal yards. A flow tick carries a container's identity, train, yard, position, remaining minutes to cut-off, protected tag, asset-stop seconds and whether the train has departed. A custom Flow instruction applies the policy in clause order: protected tags and departed trains produce no product; an asset stopped more than 60 seconds raises a `warn` for the supervisor; time remaining below the minimum connection time raises `atRisk` for the yard master. The observer is the only glue that writes the books. The minimum connection time and the commercial-sensitive field list are Blocking findings carried from gate B1; FR-03 and BR-04 stay Blocked until the BRD names them.

## Name plate

| Artifact | Name |
|---|---|
| Project / desk | Rail Yard Flow Watch (freight rail intermodal yard operations) |
| BRD | `example/BRD/freight-rail-intermodal-BRD.md` v0.1.0 |
| This WalkThrough | `freight-rail-intermodal-WalkThrough.md` |
| Version | `0.1.0` |
| Supersedes | `none` |
| Demo to implement next | `freight-rail-intermodal-Demo.dart` |
| Ledger / comprehension (later) | `freight-rail-intermodal-LEDGER.md`, `freight-rail-intermodal-COMPREHENSION.md` |
| Later (do not write now) | `freight-rail-intermodal-ARCHITECTURE.md`, `freight-rail-intermodal-FEATURES.md` |
| Layer HowTos | HowTo-Mitose-Cell / Flow / Tissue (workspace `guide/`) |

## Requirement block (plain English)

1. **Domain and desk.** Thousands of containers move through four intermodal rail yards each day — gate-in by truck, grounded in a stack block, lifted onto railcars, dispatched on freight trains. The desk watches that flow in real time.
2. **What is going wrong today.** The yard master learns about a problem when the train dispatcher calls, or the customer escalates — often after the train has departed. Around 1 in 750 containers is delayed in a way that could have been prevented with 10 minutes more notice.
3. **Why this industry, why now.** Missed connections cost demurrage and penalties; on-time rail performance is a top-three customer metric; the Office of Rail and Road expects real-time service reporting from 2027; yard masters need fewer screens, not more.
4. **Stack in one sentence.** Work enters at the desk, a decision is made against the yard's rules, books record every alert and action, and the observer is the only glue between the decision and the books.
5. **Products.** Two severities the staff actually see: a supervisor advisory when a crane, sorter or block has stopped more than 60 seconds, and a yard-master "at risk" flag when a container's remaining time falls below the train's minimum connection time.
6. **What "done" looks like.** An alert is raised and recorded, an acknowledgement clears the latch and restores the picture, Safety & Compliance can read the full log and cannot delete it, and the daily customer report can be rolled up from the same books.

## Seam + grep rule

> The instruction decides, the chain assembles, the observer glues.

> Zero `testRule: TestCell` on Tissue constructors. TestTissue on books and deputies only.

Policy is not a book write; a book write is not a policy.

## 5.1 Ingress list

| Ingress handle | Payload | Range / shape | TestCell | BRD |
|---|---|---|---|---|
| `containerIn` | `String` container ID | non-empty (e.g. `MSCU1234567`) | yes `_containerShape` | DR-01, DR-06 |
| `trainIn` | `String` train ID | non-empty | yes `_trainShape` | DR-02, DR-06 |
| `yardIn` | `String` yard id | non-empty (`Yard 1`…`Yard 4`) | no (shape not named) | DR-01, FR-04 |
| `positionIn` | `String` scan point | gate-in / stack block / crane lift / railcar load | no | FR-01, DR-01 |
| `cutoffMinIn` | `int` train cut-off, minutes-of-day | `0…1439` | no (shape not named) | DR-02, FR-02 |
| `nowMinIn` | `int` simulated clock, minutes-of-day | `0…1439` | no | FR-02 |
| `tagIn` | `String` container tag | `normal` / `hazardous` / `temperature-controlled` | no | BR-01 |
| `assetStopSecIn` | `int` seconds the crane/sorter/block at this yard has been stopped | `>= 0` | no | FR-05, P-01 |
| `trainDepartedIn` | `bool` whether the train has departed | true / false | no | BR-02 |
| `tickIn` | `RailTick` assembled snapshot | fields above | none (assembled) | — |
| `ackIn` | `String` incident key or `ALL` | non-empty optional | no | FR-07 |

Rules:

- `remainingMin` is computed by the harness as `cutoffMinIn - nowMinIn` (FR-02); it is a field on the assembled `RailTick`, not a policy decision.
- ACK is its own ingress. `tickIn` is not reused for restore.
- Dead ingresses that `publishTick` never calls would be listed here as deviations; v1 calls all of them.

## 5.2 Policy clauses → `riskOf` order

Per-pulse order the Demo class comment must copy:

> type-check → `riskOf` → distinct latch → product filter → emit `Pulse<RailDecision>`.

Clause order is load-bearing (HowTo-Mitose-Flow §4):

1. **Type-check.** Ignore a tick that is not a `RailTick`, or whose `containerId` / `trainId` is empty → `none` (DR-06 also guards the ingress).
2. **Protected / guarded membership.** `tag ∈ protected` (`hazardous`, `temperature-controlled`) → `none` (BR-01; decision precedence §7.6 order 1 wins over ordinary at-risk handling). Prints `PROTECTED`.
3. **Already closed / not in service.** `trainDeparted == true` → `none` (BR-02; precedence order 2). Prints `CLOSED`.
4. **Warn clause.** `assetStopSec > 60` → `warn` (FR-05, P-01). At exactly 60 seconds: no alert (boundary).
5. **Hard / at-risk clause.** `remainingMin < minConnectionTime` → `atRisk` (FR-03). Threshold `[To be confirmed from BRD]` — journey §9.2 implies 10 minutes but no parameter states it (finding F-01 carried from gate B1).
6. **Else** `none`.

Precedence note (F-10): clause 2 runs before clause 3, so a hazardous container on a departed train resolves to `PROTECTED`. The BRD's §7.6 does not order BR-01 vs BR-02; this is open question Q6.

## 5.3 Products and `pass`

| Product | `pass` level | Who sees it | Why a separate `toHandle` |
|---|---|---|---|
| at-risk / hard | `Level.atRisk` | Yard master single at-risk screen (FR-04) | yard-master lane owns the ACK latch and the attention reserve |
| warn | `Level.warn` | Supervisor advisory lane (FR-05, FR-06) | advisory lane must not consume the attention reserve |

Two products ⇒ two instruction instances, same live guard set, two chains, two `toHandle`s.

## 5.4 Chain shape

```dart
final atRiskGate = RailRiskInstruction(guarded: protected.rawOrSet, pass: Level.atRisk);
final warnGate   = RailRiskInstruction(guarded: protected.rawOrSet, pass: Level.warn);
final toLevel    = MapValue<RailDecision, Level>((d) => d.level);

final atRiskChain = atRiskGate + toLevel;
final warnChain   = warnGate + toLevel;

handleAtRisk = atRiskChain.toHandle(source: tickIn.cell); // once, installGates only
handleWarn   = warnChain.toHandle(source: tickIn.cell);   // once
```

- `toHandle` is **not** called from ACK. ACK calls `instruction.reset()`.
- `MapValue` projects the rich `RailDecision` to the narrow seam type. The instruction must not already emit that enum.
- Adjacent Time / Flatten / Combine / Collect operators live **outside** `riskOf` (feed before `publishTick`, or pump after observe). Named or deferred in §5.10.

## 5.5 Pulse path

```text
containerIn:Pulse<String>   trainIn:Pulse<String>              ackIn:Pulse<String>
yardIn / positionIn / cutoffMinIn / nowMinIn /                      |
tagIn:Pulse<String>  assetStopSecIn:Pulse<int>                      |
trainDepartedIn:Pulse<bool>                                         |
            \                                                       |
             \______ assembleRailTick() → tickIn.emit ______        |
                                       |                           |
                                  tickIn.cell                       |
                                  Pulse<RailTick>                   |
                                       |                           |
                    RailRiskInstruction + MapValue                 |
                     (pass=atRisk, pass=warn)                      |
                                       | toHandle ×2               |
                     atRiskCell:Pulse<Level>                       |
                     warnCell:Pulse<Level>                         |
                                       |                           |
             Cell.observe (raiseAlert)             Cell.observe (ackIn)
                                       |                           |
      events.add / incidentMap[k]= /              instruction.reset()
      reserve.set / alertQ.addLast                closeIncident: map remove,
                                                  reserve restore, events CLOSE
```

- Warn lane: `events.add` + `alertQ.addLast` only; reserve unchanged.
- atRisk lane: `events.add` + `incidentMap[k]=` + `reserve.set` + `alertQ.addLast`.

## 5.6 Tissue books

All five types considered.

| Book | Type | TestTissue | Written from | Read by | BRD |
|---|---|---|---|---|---|
| `events` | `TissueList<RailEvent>` | append-only: allow `add`/`addAll`, deny `remove`/`clear`/`[]=` | observe raise / close | trailer, COMPLY, daily roll-up | FR-07, DR-03, AR-02 |
| `incidentMap` | `TissueMap<String, Incident>` | key non-empty; `affectedQty > 0` | raise / close | close, trailer, FR-09 query | FR-08, FR-09, DR-03 |
| `protected` | `TissueSet<String>` | key shape: non-empty tag | boot / ops | `riskOf` (**same object**) | BR-01 |
| `reserve` | `TissueValue<int>` | `>= 0` | raise / close | invariant, trailer | illustration — BRD names no pool |
| `alertQ` | `TissueQueue<RailAlertJob>` | accept-all | observe enqueue | audit; pump uses a Dart working list | FR-05, FR-06 |

> Zero `testRule: TestCell` on Tissue constructors. TestTissue on books and deputies only.

`events` serves both the alert log (FR-07 / DR-03) and the compliance view (AR-02): **one** `TissueList` + `.unmodifiable` — not two lists. `incidentMap` is the v1 answer to FR-08 grouping (keyed by cause; key format TBD, F-06).

## 5.7 Reserve protocol / raise-close

Harness methods called from `Cell.observe`, never from the instruction. The reserve is an illustration — the BRD names no countable pool — but it lets raise/close and overdraw still print. Baseline `6` is marked as illustration.

```text
reserve.value! + sum(incidentMap.values.affectedQty) == baseline
```

1. Gate pulse arrives (`atRisk` lane only).
2. If no open key: decrement `reserve` by `affectedQty`, insert Map row, `events.add`, `alertQ.addLast`.
3. If `reserve` would go negative: `ok=false`, no Map write, do not invent qty (OVERDRAW).
4. ACK: `instruction.reset()`, remove Map row, add qty back, log CLOSE.
5. ACK of unknown key invents no qty (UNKNOWN ACK).

The warn lane never reads or writes the reserve. The instruction never reads or writes any book.

## 5.8 TestCell vs TestTissue map

| Rule symbol | Applies to | Allows | Denies | Scenario that prints failure |
|---|---|---|---|---|
| `_containerShape` | `containerIn` | non-empty | empty / missing container ID | REJECT |
| `_trainShape` | `trainIn` | non-empty | empty / missing train ID | REJECT |
| `_eventAppendOnly` | `events` | `add` / `addAll` | `remove` / `clear` / `[]=` | COMPLY |
| `_nonNegative` | `reserve` | `>= 0` | negative set | OVERDRAW |
| `_incidentShape` | `incidentMap` values | key non-empty, `affectedQty > 0` | empty key, qty ≤ 0 | UNKNOWN ACK |
| deputy / `.unmodifiable` | `events.unmodifiable` (Safety & Compliance) | reads | `add` | COMPLY |

## 5.9 Scenarios (must-print)

Each scenario is a banner the Demo `main()` must print, plus Result.

| # | Banner | Drive | Must print / Result |
|---|---|---|---|
| 1 | `HAPPY` | container tick: remaining 8 < MCT placeholder 10, tag `normal`, train not departed, qty 2 | `atRisk`; events +1; reserve 6 → 4; alertQ enqueue; `lastDecision=atRisk` |
| 2 | `WARN` | asset stop 61 s (> 60), remaining 30 ≥ MCT | `warn` only; reserve unchanged (6); events +1; alertQ enqueue |
| 3 | `PROTECTED` | tag `hazardous`, remaining 8 < MCT | `none`; no Tissue growth |
| 4 | `CLOSED` | `trainDeparted=true`, remaining 8 < MCT | `none`; no Tissue growth |
| 5 | `LATCH` | same container at-risk again before ACK | no second raise; reserve and map unchanged |
| 6 | `ACK` | `ackIn.emit(key)` | `reset()`; map remove; reserve 4 → 6; CLOSE row in events |
| 7 | `ACK ALL` | `ackIn.emit('ALL')` | `lastDecision=null` |
| 8 | `REJECT` | `containerIn.emit('')` | `accepted=false`; Tissue unchanged |
| 9 | `OVERDRAW` | affectedQty 7 > reserve 6 | `ok=false`; no map row |
| 10 | `COMPLY` | `council.add(...)` on `events.unmodifiable` | blocked; `length` equals source |
| 11 | `UNKNOWN ACK` | `ackIn.emit('nope')` | no invented qty; reserve unchanged |
| 12 | `PUMP FAIL-ONCE` | first `_driveAlert` fails | retry once / compensate per Real desk |

BRD wording is kept in the Drive column ("more than 60 seconds", "8 minutes before cut-off, 2 minutes short of the minimum").

## 5.10 Real desk / Wave A

| BRD need | v1 stand-in | Lands in later | Must not land in |
|---|---|---|---|
| Wall-clock 15 min ACK window (BR-03) | field on tick / harness | timer ingress / Time operator | `riskOf` I/O |
| Multi-book commit (raise/close) | `Cell.txApply` on Tissue with compensate — **yes in v1** | — | `Cell.transaction`, `riskOf` |
| Alert delivery retry (pump) | harness `_driveAlert` retry-once | `retry` / `exhaustMap` on the outbound pump | instruction |
| Daily report (FR-10 / AR-01) | trailer print / harness roll-up read of `events` | batch operator / export job | second write path |
| Spreadsheet export (FR-12) | not in Demo | export job | second write path |
| Purge after 24 months (DR-04) | append-only list | Wave B on a **copy** | `clear()` on `events` |
| Real-time 5 s update (NFR-01) | harness prints, simulated | real feed + Time operators | `riskOf` |
| 60 s stop detection (FR-05) | field-on-tick `assetStopSec` | timer ingress | `riskOf` |
| Role access (NFR-04) | not in Demo | SSO integration | Demo |
| Entity graph (containers → trains → incidents) | `incidentMap` keys; no graph | `HowTo-Mitose-Organ.md` when written | `cell_organ` from memory |
| Same-cause grouping (FR-08) | `incidentMap` keyed by cause (key TBD, F-06) | `groupBy` vs Map decision | second List |

`transaction` / `txApply` decisions:

- `Cell.transaction`: **deferred** — Mitose 2.0 commits on Tissue with `Cell.txApply` only.
- `Cell.txApply`: **yes in v1** — raise/close commits `events` + `incidentMap` + `reserve` + `alertQ` together, with compensate.

## 5.11 Open questions

| # | Question | Why it blocks | Default if unanswered |
|---|---|---|---|
| Q1 | Minimum connection time value for FR-03 (F-01, Blocking) | hard-clause boundary has no BRD value | `[To be confirmed from BRD]`; FR-03 Blocked |
| Q2 | Commercial-sensitive field list for BR-04 (F-02, Blocking) | no exclusion check can be written | `[To be confirmed from BRD]`; BR-04 Blocked |
| Q3 | Approved escalation policy when no ACK within 15 min (BRD Q-03, F-03) | BR-03 violation action | journey §9.1: escalate to yard master |
| Q4 | FR-08 "same cause" grouping key (F-06) | `incidentMap` key undefined | `[To be confirmed from BRD]` |
| Q5 | FR-12 spreadsheet export format (F-09) | export shape undefined | `[To be confirmed from BRD]` |
| Q6 | BR-01 vs BR-02 precedence when both match (F-10) | hazardous container on a departed train | protected clause wins (current order) |
| Q7 | Diego yard mismatch §6.2 (Yard 4) vs §9.1 (Yard 2) (F-05) | journey actor naming | `[To be confirmed from BRD]` |
| Q8 | BRD Q-01: Yard 3 crane feed parity | FR-01 / NFR-03 coverage | `[To be confirmed from BRD]` |
| Q9 | BRD Q-02: which four customers receive the daily report | FR-10 / AR-01 recipients | `[To be confirmed from BRD]` |
| Q10 | Measure basis: NFR-06 sample size, NFR-08 failure scenario, §12 window (F-07) | M / H checks | `[To be confirmed from BRD]` |
| Q11 | AC-01…AC-07 cite no requirement IDs (F-08) | criterion trace | `[AI SUGGESTED]` criteria from gate B1 |
| Q12 | BR-01 orphan: no FR implements re-route authorization (F-04) | re-route is out of scope (§4.2) | BR-01 enforced as protected-tag clause; re-route deferred |

## 5.12 Demo Assessment

*Filled from `freight-rail-intermodal-Demo.dart` symbols and the last-good run. No invented run.*

### What the Demo implemented
- Custom `RailRiskInstruction` extends `FlowInstructionBase<Cell, Pulse, Pulse>`: static `riskOf` with the §5.2 clause order (protected BR-01 → departed BR-02 → warn FR-05/P-01 → atRisk FR-03 placeholder → else null), per-lane distinct latch, product filter. Two instances (`pass: Level.atRisk`, `pass: Level.warn`) share the live `protected` TissueSet.
- Chains per §5.4: `RailRiskInstruction + MapValue<RailDecision, Level>` → `toHandle(source: tickIn.cell)` once per product, only in `installGates()`.
- Ingress: `containerIn` / `trainIn` with TestCell (DR-06 non-empty); `tickIn` assembled; `ackIn` separate; other field ingresses without TestCell.
- Books: all five Tissue types — `events` append-only, `incidentMap` (key non-empty, qty > 0), `protected` (seeded `hazardous` / `temperature-controlled`), `reserve` (>= 0, illustration baseline 6), `alertQ` (accept-all, capacity 32). Council view via `events.unmodifiable`.
- Glue: `Cell.observe` ×3 (atRisk lane, warn lane, ackIn). No Tissue write in the instruction; ACK observer calls `reset()` only — never `toHandle`.
- Atomic commit: `Cell.txApply` on raise/close through command cells `raiseCmd` / `closeCmd`; body writes Tissue books; catch compensates. `Cell.transaction` deferred.
- Header carries the provenance/boundary registers, Cell I/O table, expected console, deviations, and IDs covered / not covered. Decision logic is top-level and importable; `main()` is the only entry that drives scenarios.
- `main()` drives all 12 §5.9 banners, compares actual against expected, prints PASS/FAIL and exits non-zero on FAIL. Last-good run: all 12 PASS (`dart run example/freight-rail-intermodal-Demo.dart`).

### What this WalkThrough asked for that `main()` does not drive
- FR-01 real-time position feed and NFR-01 5 s update — simulated tick bus; real feed and Time operators are Wave A.
- FR-04 single at-risk screen and FR-09 cross-yard open-incident view — trailer prints the open count only; the human trial (class H) is not driven.
- FR-08 same-cause grouping — `incidentMap` is keyed by container ID; the grouping key is still open (F-06, Q4).
- FR-10 / AR-01 daily report by customer — events roll-up not implemented (trailer only); FR-12 export out of Demo.
- BR-03 15-minute ACK window and escalation — no wall clock; Q-03 open.
- BR-04 commercial-sensitive fields — no exclusion list; row Blocked (F-02).
- FR-11 free-text note, NFR-04 role access, NFR-05..08 measurement/trial classes — not driven.
- Wall-clock dwell and stop detection are harness fields (`assetStopSec`, `remainingMin`), not Time operators.

### Trailer / header integers

| Token | WalkThrough expected | Demo header / last run |
|---|---|---|
| ticks | driven | 7 |
| events | +1 per raise / warn / ACK / alert-sent | 9 at trailer (7 at COMPLY) |
| reserve | 6 → 4 on HAPPY, restored to 6 on ACK | 6 at trailer, open=0 |
| lastDecision after ACK ALL | `null` | `null` at the ACK ALL banner (PASS); trailer ends `Level.warn` after the later WARN tick |

### Recommendations for Enhancement
- Resolve F-01 (minimum connection time) so FR-03 moves from the placeholder to a BRD-sourced expected value (BRD).
- Resolve F-02 (commercial-sensitive field list) and add an exclusion check on the report roll-up (BRD / Tissue).
- Drive FR-10 / AR-01 daily report as a harness roll-up read of `events` per customer — not a second write path (harness / Tissue).
- Add a timer ingress or Time operator for the 15-minute ACK window and the 60-second stop detection instead of tick fields (Flow).
- Decide the FR-08 grouping key, then key `incidentMap` by cause rather than container ID (Tissue).
- Drive the remaining Must T rows in the BRD group so they can leave Blocked (harness).
- Keep policy pure: no Tissue writes in the instruction (guard).

## 5.13 Coverage matrix

| Scenario # | BRD ID | WalkThrough section | Expected print | Proven in Demo? |
|---|---|---|---|---|
| 1 | FR-03, FR-02, FR-06 | 5.9 | `atRisk`; events +1; reserve 6→4; queue enqueue. FR-03 expected value `[To be confirmed from BRD]` | PASS (banner) |
| 2 | FR-05, FR-06 | 5.9 | `warn`; reserve unchanged | PASS (banner) |
| 3 | BR-01 | 5.9 | `none`; no Tissue growth | PASS (banner) |
| 4 | BR-02 | 5.9 | `none`; no Tissue growth | PASS (banner) |
| 5 | FR-08 | 5.9 | no second raise | PASS (banner) |
| 6 | FR-07, DR-03 | 5.9 | `reset()`; map remove; reserve restored; CLOSE row | PASS (banner) |
| 7 | FR-07 | 5.9 | `lastDecision=null` | PASS (banner) |
| 8 | DR-06 | 5.9 | `accepted=false`; Tissue unchanged | PASS (banner) |
| 9 | illustration (no BRD ID) | 5.9 | `ok=false`; no map row | PASS (illustration) |
| 10 | AR-02, BR-04 | 5.9 | blocked; `length` equals source | PASS (banner) |
| 11 | FR-07 | 5.9 | no invented qty | PASS (banner) |
| 12 | FR-05 (delivery) | 5.9 | retry once / compensate | PASS (banner) |

## 5.14 HowTos consulted

Workspace `guide/` copies: `HowTo-Mitose-Cell.md`, `HowTo-Mitose-Flow.md`, `HowTo-Mitose-Tissue.md`. `HowTo-Mitose.md` was not required to write this file.
