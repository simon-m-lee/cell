# WalkThrough — Tide Warden estuary flood desk (Cell variant)

*What a reader must understand*

Tide Warden is the Harbor City flood desk that turns live watches, rain gauges, and weather reports into one flood order or a clear refusal. An order is real only when the gate closed, the road closed, and the shelter opened are recorded as one act, or not at all. If the gate has already been told to close and a later leg fails, that order is withdrawn before any public road-closed notice is sent. Weather outside the plan, crew duty at the limit, or a newer higher level on an unissued order can stop or replace work. Gauge reports that repeat or chatter are reduced so the log stays readable. Pump hours and the shift duty figure move together or not at all. Work enters at named ingresses, a decision instruction applies the precedence rules, and the observer is the only glue that writes the books. Done means a reader never sees a half order, a second close tap does nothing while the first issue is running, a silent radio leaves the gate open, and the weekly report of issued, aborted, and refused orders sums exactly to the orders decided.

| Artifact | Name |
|---|---|
| Project / desk | Tide Warden estuary flood desk |
| BRD | `tide-warden-BRD.md` (0.1.0) |
| This WalkThrough | `tide-warden-WalkThrough.md` |
| Version | 0.1.0 |
| Supersedes | none |
| Demo to implement next | `tide-warden-Demo.dart` (0.1.0) |
| Ledger / comprehension (later) | `tide-warden-LEDGER.md`, `tide-warden-COMPREHENSION.md` |
| Later (do not write now) | `tide-warden-ARCHITECTURE.md`, `tide-warden-FEATURES.md` |
| Layer HowTos | HowTo-Mitose-Cell / Flow / Tissue (this directory) |

## Seam sentence and grep rule

> The instruction decides, the chain assembles, the observer glues.

> Zero `testRule: TestCell` on Tissue constructors. TestTissue on books and deputies only.

Policy lives in the Flow instruction. A book write lives in the observer. One is not the other.

## 5.1 Inputs / ingress list

Every external fact named in the BRD has an ingress or is explicitly deferred. `tickIn` is the assembled snapshot. `ackIn` is separate so restore never re-enters the decision chain.

| Ingress handle | Payload | Range / shape | TestCell | BRD |
|---|---|---|---|---|
| `watchIn` | Watch (reporter, catchment, level, time, description) | approved reporter on list, level in P-19, all DR-01 fields present | yes | FR-01, DR-01, DR-03, BR-04 |
| `gaugeIn` | GaugeReport (cut, reading, time) | named cut, numeric reading | yes (shape) | FR-02, FR-03, FR-04 |
| `tideIn` | double | metres above chart datum | optional | FR-07, BR-01, P-03 |
| `rainIn` | double | millimetres per hour | optional | FR-07, BR-01, P-02 |
| `windIn` | double | knots | optional | FR-07, BR-01, P-01 |
| `pumpHourIn` | PumpHour (pump, delta) | non-negative | yes | FR-05, DR-03 |
| `shelterCheckIn` | ShelterReply (hall, able) | hall on the four-hall list | yes | FR-11, DR-04 |
| `keeperConfirmIn` | String (gate) | available gate | yes | FR-10, DR-04 |
| `crewAnswerIn` | CrewReply (crew, able) | — | optional | FR-12 |
| `radioIn` | RadioReply or silence marker | — | optional | FR-13 |
| `abortIn` | Abort (orderKey, reason) | reason from P-18 list | yes | FR-20 |
| `tickIn` | assembled FloodTick | latest weather, open watches, hours, in-progress flags | usually none | — |
| `ackIn` | String (order key or ALL) | non-empty | optional | — |

Dead ingresses that `publishTick` never calls are listed above as deviations if they appear; none are hidden.

## 5.2 Policy clauses → `riskOf` order

Clause order is load-bearing. The first matching row wins. Every matching reason is still recorded. Stock `Filter` is not enough: the BRD needs a resettable latch, precedence, replace-only-unissued, ignore-while-issuing, and sequential legs.

1. Type-check / ignore unknown tick.
2. Weather or duty refuse (BR-01, BR-02). Wind strictly above P-01 (40 knots), rain strictly below P-02 (8 mm/h), tide strictly below P-03 (4.2 m), or duty at or above P-04 (600 minutes) → refused. The limit value itself does not fire except for duty.
3. Reporter, gate, or shelter not allowed (BR-04, DR-04) → refused.
4. Second close request for the same gate while the first issue is still being issued (FR-09) → ignored (none). The first issue is unchanged.
5. Newer watch of strictly higher level replaces an unissued order on the same gate (BR-06, FR-08). Shelter hold is released. An already-issued order does not yield.
6. Sequential road warning, then gate-keeper confirm, then pump-crew call (FR-10). A later step does not start until the earlier step has succeeded.
7. All-or-nothing recording of gate-closed, road-closed, and shelter-open (FR-14). If any leg cannot be recorded, none of them are. If the gate order has already been given and a later leg fails, withdraw within P-07 (180 seconds) before any road-closed notice (FR-15, BR-05).
8. Pump hours and the shift duty figure are recorded together or neither is (FR-16).
9. Public road-closed notice is delayed by P-09 (60 seconds) after a stuck order and is not sent if an abort is recorded in that delay (FR-17).
10. Else hold or none.

Per-pulse order the Demo must copy into the class comment:

> type-check → `riskOf` → distinct latch → product filter → emit `Pulse<FloodDecision>`.

## 5.3 Products and `pass`

| Product | `pass` level | Who sees it | Why a separate `toHandle` |
|---|---|---|---|
| issued / held / refused / aborted / planned | `Level.issued` (single product) | warden wall, city engineer, highways liaison | Wall picture shows exactly one of the five levels (FR-19). One chain is enough. |

One product, one chain, one `toHandle`. The full reason remains on the order record.

## 5.4 Chain shape

```dart
final floodGate = FloodRiskInstruction(
  approved: approved.rawOrSet,
  pass: Level.issued,
);
final toLevel = MapValue<FloodDecision, Level>((d) => d.level);

final floodChain = floodGate + toLevel;

handleFlood = floodChain.toHandle(source: tickIn.cell); // once, installGates only
```

- `toHandle` is not called from ACK or abort. Abort and ACK call `instruction.reset()`.
- `MapValue` projects the rich `FloodDecision` to the narrow seam type. The instruction must not already emit that enum.
- Adjacent Time operators (debounce for chatter window P-05, sample for snapshot interval P-11, delay for notice P-09 and radio P-06) live outside `riskOf`. They feed before `publishTick` or pump after observe. Named or deferred in §5.10.

## 5.5 Pulse path

ASCII matches `install()` / `installGates()`. ARCHITECTURE and FEATURES cite this block as §5.5.

```text
watchIn / gaugeIn / tideIn / rainIn / windIn / pumpHourIn /
shelterCheckIn / keeperConfirmIn / crewAnswerIn / radioIn / abortIn          ackIn
                              \                                                |
                            publishTick                                        |
                                 |                                             |
                               tickIn                                          |
                                 |                                             |
                   FloodRiskInstruction + MapValue                             |
                                 | toHandle × 1                                |
                            gate Cell                                          |
                                 |                                             |
                           Cell.observe                                   Cell.observe
                                 |                                             |
                    Cell.txApply (command cells)                         reset() / withdraw
                    gateCmd / hoursCmd
                                 |                                             |
     openOrders / events / pumpHours / noticeQ / holds                   (no toHandle)
```

Payload types: `Pulse<FloodTick>`, `Pulse<FloodDecision>`, `Pulse<Level>`, `Pulse<String>`.

All-or-nothing commits are `Cell.txApply` on command cells (`gateCmd`, `hoursCmd`). The body writes the Tissue books (issued/aborted: events, openOrders, noticeQ; hours: pumpHours). The catch path supplies the compensate. `Cell.transaction` is not used. The instruction never writes Tissue.

## 5.6 Tissue books

All five types are considered. Unused rows stay with the reason.

| Book | Type | TestTissue | Written from | Read by | BRD |
|---|---|---|---|---|---|
| `events` | `TissueList<FloodEvent>` | append-only | observe / raise / close / handback / abort | trailer, council `.unmodifiable` | AR-01, AR-02, AR-03, DR-02 |
| `pumpHours` | `TissueValue<int>` | `>= 0` | observe (txApply with shift figure) | BR-02 check | FR-05, FR-16, BR-02 |
| `openOrders` | `TissueMap<String, Order>` | key non-empty, level in P-19 | observe | riskOf, wall picture | FR-08, FR-14, FR-18, FR-19 |
| `approved` | `TissueSet<String>` | key shape | boot / ops | riskOf (same object) | BR-04, DR-04 |
| `noticeQ` | `TissueQueue<Notice>` | accept-all | observe enqueue | audit; harness flushes batches of P-13 or at P-14 | FR-17, FR-18 |

Grep rule restated under the table: zero `testRule: TestCell` on Tissue constructors. TestTissue on books and deputies only.

Council and engineer see a `.unmodifiable` view of `events`. No role may record an order that failed a safety rule (NFR-04).

## 5.7 Reserve protocol / raise-close

There is no classic spare-parts pool. Conservation is on pump hours versus the shift figure, and on open-order count versus shelter holds.

```text
pumpHours + pendingDeltas == shiftFigure
```

Steps called from `Cell.observe`, never from the instruction:

1. Gate pulse arrives.
2. If the order is legal and all three legs can be recorded: `Cell.txApply` writes gate-closed, road-closed, and shelter-open together; `events.add`; delayed enqueue to `noticeQ`.
3. If any leg would fail: `ok=false`, no partial write. If a gate order was already given, withdraw it within P-07 and do not send the road-closed notice.
4. Abort or ACK: `instruction.reset()`, release the shelter hold, withdraw the gate order, log ABORT or CLOSE.
5. An unknown key invents no hours and no order.

`Cell.transaction` is not used. Every all-or-nothing commit is `Cell.txApply` on Tissue.

## 5.8 TestCell vs TestTissue map

| Rule symbol | Applies to | Allows | Denies | Scenario that prints failure |
|---|---|---|---|---|
| `_watchShape` | watchIn | complete approved reporter, level in list | missing field, bad reporter, level 0 | REJECT |
| `_gaugeShape` | gaugeIn | named cut, numeric reading | empty cut | — |
| `_eventAppendOnly` | events | add / addAll | remove / clear / []= | COMPLY |
| `_nonNegative` | pumpHours | >= 0 | negative set | HOURS fail path |
| `_orderShape` | openOrders values | level in P-19 | bad level | — |
| deputy / `.unmodifiable` | council view of events | reads | add | COMPLY |

## 5.9 Scenarios (must-print)

Each banner is a line `main()` must print, plus the Result. BRD wording is kept inside the Drive column.

| # | Banner | Drive | Must print / Result |
|---|---|---|---|
| 1 | `HAPPY` | West Cut level 2 warning, tide/rain/wind inside plan, duty 240, all three legs succeed, P-09 elapses with no abort | events +1, order issued, notice sent, lastDecision=issued. A reader never saw the gate closed without the shelter open. |
| 2 | `REPLACE` | Unissued level 2 order on a gate + new level 1 watch accepted for the same gate | old shelter hold gone, only the new order open. Issued order is not replaced. |
| 3 | `IGNORE` | Second close request for West Cut while the first issue is running | second request not issued, first issue unchanged. |
| 4 | `HOLD` | No radio answer at P-06 (90 s), one further try also silent | order held, no issue recorded, gate still open, reason “no answer”. |
| 5 | `ATOMIC` | Shelter leg fails after the keeper has accepted the close | gate-closed, road-closed, and shelter-open all absent; handback recorded within 180 s; no road-closed notice sent. |
| 6 | `HOURS` | One further pump hour whose shift leg fails | both hour figures remain at the previous value. |
| 7 | `ABORT` | Issued order + reason from P-18 list | order aborted, shelter free, gate order withdrawn. Reason not on the list leaves the order issued. |
| 8 | `REJECT` | Watch missing a DR-01 field, or reporter not on the list, or level 0 | accepted=false; Tissue unchanged. |
| 9 | `COMPLY` | council `.unmodifiable.add` on events | blocked; length equals source. |
| 10 | `WEATHER` | Wind 41 knots, or rain 7 mm/h, or tide 4.1 m, or duty 600 minutes | refused under BR-01 or BR-02, rule named. Limit value itself does not fire (except duty). |

## 5.10 Real desk / Wave A

| BRD need | In this Demo | Lands in later | Must not land in |
|---|---|---|---|
| Wall-clock chatter window (P-05), snapshot interval (P-11), radio limit (P-06), notice delay (P-09) | field on the tick or harness timer | timer ingress / Time operator | riskOf I/O |
| Multi-book all-or-nothing (gate/road/shelter, hours+shift, withdraw) | `Cell.txApply` on Tissue, with compensate | — | `Cell.transaction`, riskOf |
| Device / radio / keeper / pump crew | `Cell.txApply` on Tissue, with compensate | — | instruction |
| Weekly resilience report and daily flood log | trailer print | batch operator / export job | second write path |
| Retention purge after P-10 (7 years) | append-only list | Wave B on a copy | clear() on events |
| Night-specific wind limit or island-hall eligibility | open questions carried | change request | guessed limits |
| Parallel shelter checks and first-able crew | harness or adjacent flatten | — | inside riskOf |

`txApply`: present (`gateCmd`, `hoursCmd`). `transaction`: not used.

## 5.11 Open questions

| # | Question | Why it blocks | Default if unanswered |
|---|---|---|---|
| Q-01 | Should a night order use a lower wind limit, or stay at 40 knots all day? | None. P-01 stays 40 until a change request. | 40 knots all day |
| Q-02 | Will the island hall take a level 1 at night, or only the two shore halls? | None. All four halls stay eligible until a change request. | All four eligible |

No Blocking findings were carried from gate B1. No other fields are marked `[To be confirmed from BRD]`.

## 5.12 Demo Assessment

*Filled from `tide-warden-Demo.dart` symbols and `main()`. No invented run.*

### What the Demo implemented
- Custom `FloodRiskInstruction` extending `FlowInstructionBase` with static `riskOf`, latch, and product filter. Chain built with `FlowInstruction.chain([floodGate, toLevel])` and materialised by `toHandle` once in `installGates`. Compile-time error free.
- Ingress: `watchIn` with `TestCell` (callback signature `(p, {host, arguments, user})`), `tickIn`, `ackIn`.
- Books: all five Tissue types (`events`, `pumpHours`, `openOrders`, `approved`, `noticeQ`). `TissueMap` constructed without explicit testRule. Council view via `events.unmodifiable`.
- Glue: `Cell.observe` on the gate Cell and on `ackIn` (calls `reset()`). No Tissue writes in the instruction.
- Header provenance and boundary registers present. Real `Cell.txApply` stages issued/aborted (gate + notice) and hours updates through command cells (`gateCmd`, `hoursCmd`). Body writes the Tissue books; catch path supplies the compensate. `Cell.transaction` deferred.
- `main()` drives banners for HAPPY, REPLACE, IGNORE, HOLD, ATOMIC, HOURS, ABORT, REJECT, COMPLY, WEATHER and prints PASS/FAIL against expected.

### What this WalkThrough asked for that `main()` does not drive
- Full live gauge chatter/repeat/snapshot reduction (FR-02, FR-03, FR-04) — harness fields only.
- Sequential road-warning → keeper → pump (FR-10) and parallel shelter checks (FR-11) — not exercised.
- First-able crew race (FR-12) — simplified.
- Real `Cell.txApply` body commits issued/aborted (gate + notice) and hours together or neither. Observer calls `Cell.txApply`; body writes Tissue; catch compensates. Policy remains pure.
- Notice delay voidable by abort (FR-17) — notice enqueued immediately.
- Weekly/daily report content (AR-01, AR-02) — trailer only.
- Wall picture single-level guarantee under load (FR-19), full role isolation (NFR-04), measurement NFRs.
- Clauses exist in `riskOf` for weather, duty, ignore, hold, abort; many are unproven by a full journey.

### Trailer / header integers
| Token | WalkThrough expected | Demo header / last run |
|---|---|---|
| ticks | (driven) | header lists expected banners; no numeric trailer |
| events | +1 on issued | `events.add` on issued/held/withdrawn |
| pumpHours | unchanged on fail | `TissueValue` present; HOURS banner checks equality |
| openOrders | issued or absent | Map written/removed in observe |
| lastDecision after ACK ALL | `null` | `reset()` clears latch; ACK ALL not driven |

### Recommendations for Enhancement
- Drive sequential FR-10 and parallel FR-11 from the harness or adjacent Flow operators, not inside `riskOf` (Flow / harness).
- Drive sequential FR-10 and parallel FR-11 from the harness or adjacent Flow operators, not inside `riskOf` (Flow / harness).
- Add a timer ingress or Time operator for P-05/P-06/P-09/P-11 instead of harness fields (Flow).
- Expand `main()` to cover the remaining Must FRs that are currently BLOCKED in the test (harness).
- Keep policy pure; do not add Tissue writes to the instruction.

## 5.13 Coverage matrix

| Scenario # | BRD ID | WalkThrough section | Expected print | Proven in Demo? |
|---|---|---|---|---|
| 1 | FR-01, FR-07, FR-10, FR-14, FR-17 | 5.9 | issued, notice sent | banner present; issued path is `Cell.txApply` |
| 2 | FR-08, BR-06 | 5.9 | replaced, hold released | banner present (placeholder) |
| 3 | FR-09 | 5.9 | ignored | banner present |
| 4 | FR-13 | 5.9 | held, no issue | banner present |
| 5 | FR-14, FR-15, BR-05, FR-17 | 5.9 | all legs absent, handback ≤180 s, no notice | banner present; withdraw path is `Cell.txApply` |
| 6 | FR-16, FR-05 | 5.9 | both figures unchanged | banner present |
| 7 | FR-20 | 5.9 | aborted, shelter free, gate withdrawn | banner present |
| 8 | DR-01, DR-03, BR-04 | 5.9 | accepted=false | banner present |
| 9 | NFR-04 | 5.9 | blocked | banner present |
| 10 | BR-01, BR-02, AC-01 | 5.9 | refused, rule named | banner present |

## 5.14 HowTos consulted

Workspace copies of HowTo-Mitose-Cell.md, HowTo-Mitose-Flow.md, and HowTo-Mitose-Tissue.md (this directory). HowTo-Mitose.md was not required for this write.
