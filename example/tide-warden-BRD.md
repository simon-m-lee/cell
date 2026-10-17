# Business Requirements Document — Tide Warden

**Template version:** 2.0
**Stem:** `tide-warden`
**Pipeline note:** Worked sample for a Mitose 2.0 run. Fictional city desk, real operating problem. A different industry from Pantry Bridge and from Saltline Scramble. The desk listens to several live reports at once, and a flood order is not real unless the gate, the road closure, and the shelter opening are recorded together or not at all. This file says what the city needs. It does not say how the desk will be built.

---

## 1. Document control

| Field | Value |
|---|---|
| Project name | Tide Warden |
| Document title | Business Requirements Document — Tide Warden estuary flood desk |
| Version | 0.1.0 |
| Supersedes | none |
| Date | 2026-10-10 |
| Author | Mara Quinn, Duty Warden, Harbor City Flood Desk (sample) |
| Reviewer(s) | Tomas Berg, City engineer; Ruth Adeyemi, Shelter lead |
| Approver(s) | Mara Quinn, Duty Warden (sponsor); Tomas Berg, City engineer |
| Status | draft — sample for the Mitose 2.0 pipeline, not yet approved |

**Revision history**

| Version | Date | Change ID | Author | Change summary |
|---|---|---|---|---|
| 0.1.0 | 2026-10-10 | — | Mara Quinn | First draft. Sample BRD for a Mitose 2.0 pipeline run. |

---

## 2. Executive summary

Harbor City keeps the estuary out of the lower streets with two sluice gates, three storm pumps, and four church-hall shelters. Today the flood desk is a radio, a tide table, and a whiteboard. A gate can be closed while the shelter is still locked, a rain gauge can repeat until the log is useless, and a road can be marked closed after the gate order has already failed. Tide Warden is the desk the city needs: live reports are reduced to what a warden can act on, a higher flood level can replace an order that has not been issued, and an order exists only when the gate, the road closure, and the shelter opening have all been recorded, or none of them have. If the gate has already been told to close and a later leg fails, that order is withdrawn before anyone is told the road is closed.

---

## 3. Business context

### 3.1 Background

The flood desk covers two catchments, West Cut and Island Cut. Each has one sluice gate and a named gate keeper. Three pumps can be called. Four shelters can take residents if a road is closed. Last winter the desk handled 210 flood orders. Fourteen of those left a shelter marked open on the whiteboard after the gate had been reopened. Six left a road closed after a ground abort. Rain gauges report about every few seconds in a storm and are copied by hand.

### 3.2 Problem statement

On 3 November a West Cut order was being built when Island Cut rose faster. The warden closed the Island Cut gate, then found the West Cut shelter still marked open for an order that had been replaced. Residents arrived at a hall that had no warden. The same week the public notice said Quay Road was closed when the gate was still open: the notice went out at the moment the gate keeper accepted the order, and the shelter leg failed a minute later. Pump hours also run past the duty limit because the tally is on paper, one shift behind.

### 3.3 Business drivers

- The city engineer will not sign the winter plan until a flood order cannot exist without a shelter.
- The highways lead wrote on 2026-09-18 that a road closed and then not needed must be handed back within three minutes.
- Gate keepers asked for one close tap to count once. A double tap on 19 September sent two orders to one gate.
- The council wants a weekly picture of orders issued, aborted, and refused before the November resilience review.

### 3.4 Alignment with strategy

The 2026 city goal is “the right gate, the right shelter, no half order.” Tide Warden is that rule made checkable: weather and duty can stop a closure, a newer higher level can replace an unissued order, and the public hears “road closed” only after the order has stuck.

---

## 4. Scope

### 4.1 In scope

- Recording a flood watch from an approved reporter, with catchment, level, and time.
- Reducing live rain-gauge reports so repeats and chatter do not each become a notice.
- Taking a regular water-level snapshot even when reports arrive faster than that.
- Holding the latest tide, the latest rain, and the latest wind, and refusing an order when any is missing or outside the plan.
- Replacing an unissued order when a newer, higher level is accepted for the same gate.
- Ignoring a second close request for the same gate while the first request is still being issued.
- Warning the road, confirming the gate keeper, and asking the pump crew, in that order, not overlapping.
- Letting several shelter checks proceed at the same time.
- Taking the first pump crew that answers able, and releasing the others.
- Trying the radio once more if it does not answer in time, then holding.
- Recording gate-closed, road-closed, and shelter-open as one act, or not at all.
- Withdrawing a gate order if a later leg of the same issue fails, before any road-closed notice.
- Recording pump hours and the shift duty figure together.
- Delaying the public road-closed notice long enough for an abort to void it.
- Grouping open orders by catchment, and flushing gauge notices in batches for the log.
- A weekly issued / aborted / refused report.

### 4.2 Out of scope

- Evacuating people house by house. The desk opens a shelter; it does not knock on doors.
- Repairing a gate or a pump. The desk records “not available.”
- Insurance claims and council tax relief.
- Predicting next week’s tide. The desk uses the latest report it has been given.
- River gauges upstream of the two cuts. Not this desk.
- Charging a resident. The order may record cost to the city, never a charge to a person sheltered.

### 4.3 Assumptions

- Each gate has one named keeper on duty, or it is not available.
- The four church halls are the only shelters in this draft.
- Travel minutes between each gate and each shelter are a standing figure agreed by the city engineer.
- The desk does not close at night. A flood does not wait for morning.
- A flood level is given by the city plan, not invented by the warden.
- Tide, rain, and wind arrive already measured. The desk does not estimate them.

### 4.4 Constraints

- A reader must never see the gate marked closed without a shelter open, or a shelter open for an order that does not exist.
- A gate order is an act that can succeed and then have to be undone. Undoing it is part of the issue, not a later courtesy.
- Volunteer shelter wardens are not employed dispatchers. A confirmation is a recorded statement by the named person.
- Duty limit, weather limits, and the road-handback limit are the city flood plan, agreed with the engineer and the highways lead. They are not guessed in this draft.

### 4.5 Dependencies

- The approved reporter list (harbour master, highways inspector, gauge warden, police duty desk) must exist before the first watch.
- The city engineer must publish the level list and the weather limits before go-live.
- Highways must accept a handback as the end of a road closure.
- Each gate must name a duty keeper at the start of the shift, or that gate is unavailable.

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence (H/M/L) | Engagement approach |
|---|---|---|---|---|
| Sponsor | Mara Quinn, Duty Warden | No half order, winter plan signed | H | Weekly one-page note |
| Primary user | Flood dispatchers | One order per gate, a clear reason when a watch is refused | H | Shift walkthrough before pilot |
| Gate keeper | Edsel Park, and the other keepers | One close tap, duty limit kept | H | Keeper briefing |
| City engineer | Tomas Berg | Higher level wins, shelter actually open | H | Sign-off on rules before pilot |
| Shelter lead | Ruth Adeyemi | A hall open only for an order that exists | H | Shelter workshop |
| Highways | Quay Road duty lead | Closure handed back within the handback limit | M | Agreed handback drill |
| Reporter | Approved reporters | A yes, a no, or a “replaced by a higher level” | M | Reporter card |
| Council | Resilience board | Weekly issued, aborted, refused | M | November resilience review |

---

## 6. Users and personas

### 6.1 Mara Quinn — duty warden

- **Role:** Duty warden and lead dispatcher
- **Context:** City desk, all shift. A second warden covers the island radio.
- **Goal:** Turn a complete watch into one order, or a clear refusal, without leaving a shelter or a road dangling.
- **Pain today:** The whiteboard can show a shelter open and the gate still up, or the reverse.
- **Success looks like:** Either the gate, the road, and the shelter all change, or none of them do. A second tap does nothing while the first issue is still running.

### 6.2 Edsel Park — gate keeper

- **Role:** Keeper at West Cut sluice
- **Context:** Gate hut, then the walkway. Rain gauges on the cut report every few seconds in a storm.
- **Goal:** Close once, inside weather and duty limits, with pump hours that match the meter.
- **Pain today:** Paper hours are a shift behind. A double radio call has put two orders on one gate.
- **Success looks like:** Duty hours move only when the order is recorded, and the same gauge reading is not shouted twice.

### 6.3 Ruth Adeyemi — shelter lead

- **Role:** Lead for the four church-hall shelters
- **Context:** Hall desk, called in when a road may close.
- **Goal:** Open a hall for an inbound closure, and stand down if that order does not issue.
- **Pain today:** A hall stays open after an abort because the radio call and the whiteboard are different acts.
- **Success looks like:** A hall is open only as part of a recorded order, and a failed order releases it.

---

## 7. Business requirements

Requirement IDs are permanent. A removed requirement is marked Retired, not deleted.

### 7.1 Functional requirements

| ID | Requirement | Priority (Must / Should / Could) | Acceptance criterion (Given / When / Then, with tolerance) | Class | Rationale |
|---|---|---|---|---|---|
| FR-01 | The system shall record a flood watch from an approved reporter with catchment, level, time, and reporter name. | Must | **Given** an approved reporter and a complete watch, **when** it is submitted, **then** it is open and carries every field in DR-01. A reporter not on the list is not recorded. | T | No order without a watch. |
| FR-02 | The system shall treat a run of gauge reports for the same cut that repeat the same reading as one notice, not one notice each. | Must | **Given** three reports for West Cut at the same reading inside the repeat window, **when** they arrive, **then** one notice is raised. A later report at a different reading raises a new notice. | T | The log must be readable. |
| FR-03 | The system shall collapse gauge reports for one cut that arrive inside the chatter window into a single notice at the end of that quiet gap. | Must | **Given** reports at 1 second, 2 seconds, and 3 seconds, and then silence for the chatter window, **when** the window elapses, **then** one notice is raised, carrying the last reading. | T | Storm reports must not each page the desk. |
| FR-04 | The system shall take a water-level snapshot for each cut on the snapshot interval even if reports arrive faster. | Must | **Given** reports every 2 seconds, **when** one snapshot interval elapses, **then** exactly one snapshot is kept for that interval, the latest reading in it. | T | The wall picture is regular. |
| FR-05 | The system shall keep a running pump-hours figure for each pump from start and stop reports, and shall refuse an order whose crew would pass the duty limit. | Must | **Given** hours 4 and a further 1 hour confirmed, **when** the hour is accepted, **then** the figure is 5. **Given** a figure at P-04, **when** an order is requested, **then** it is refused under BR-02. | T | Paper hours are a shift behind. |
| FR-06 | The system shall compare each level snapshot with the previous one and shall say whether the cut is rising or falling. | Must | **Given** two snapshots with the second higher, **when** the second arrives, **then** the cut is marked rising. **Given** the second lower, **then** it is marked falling. | T | A falling cut after an order is an abort clue. |
| FR-07 | The system shall hold the latest tide, the latest rain, and the latest wind, and shall not issue an order until all three have been received and all three are inside the plan for that level. | Must | **Given** tide and rain inside the plan and no wind yet, **when** an order is requested, **then** it is not issued. **Given** all three inside the plan, **then** weather does not block. **Given** any outside the plan, **then** BR-01 fires. | T | All three reports matter. |
| FR-08 | The system shall replace an unissued order when a newer watch of strictly higher level is accepted for the same gate, and shall release every hold the old order took. | Must | **Given** an unissued order for level 2, **when** a level 1 watch is accepted, **then** the old order is replaced, its shelter hold is gone, and only the new order is open. An issued order is not replaced. | T | The November island case. |
| FR-09 | The system shall ignore a second close request for the same gate while the first request is still being issued. | Must | **Given** a close issue in progress for West Cut, **when** a second request for West Cut arrives, **then** the second request is not issued and the first issue is unchanged. | T | The 19 September double tap. |
| FR-10 | The system shall issue the road warning, then the gate-keeper confirm, then the pump-crew call, in that order, for one order. A later step shall not start until the earlier step has succeeded. | Must | **Given** an order being issued, **when** the road warning has not succeeded, **then** the keeper confirm and the pump call do not start. **When** the road warning succeeds, **then** the keeper confirm starts, and not before. | T | Order is the safety brief. |
| FR-11 | The system shall check availability at more than one shelter at the same time. | Must | **Given** two halls both eligible, **when** an order is built, **then** both checks are in progress together, and a slow answer from one does not wait on the other to start. | T | Minutes matter. |
| FR-12 | The system shall award a multi-pump request to the first crew that answers able, and shall release the other crews. | Must | **Given** two crews asked, **when** crew B answers able and crew A has not, **then** crew B is the one reserved and crew A is released. | T | First able crew wins. |
| FR-13 | The system shall try the radio once more if no answer arrives within the radio limit, and shall hold the order if the second try also fails. | Must | **Given** no answer at P-06, **when** the limit elapses, **then** one further try is made. **Given** no answer at the second limit, **then** the order is held and no issue is recorded. | T | A silent radio is not an order. |
| FR-14 | The system shall record gate-closed, road-closed, and shelter-open as one act. If any leg cannot be recorded, none of them are. | Must | **Given** a legal order, **when** all three legs succeed, **then** a reader sees all three. **When** the shelter leg fails, **then** a reader sees the gate still open, the road open, and the shelter free. | T | No half order. |
| FR-15 | The system shall withdraw a gate order if a later leg of that same issue fails, and shall do so before any road-closed notice. The gate shall not be left closed. | Must | **Given** a gate order already given and a shelter leg that then fails, **when** the failure is known, **then** the gate order is withdrawn, the road-closed notice is not sent, and the gate is open. Withdrawal is recorded within P-07 of the failure. | T | The highways letter of 2026-09-18. |
| FR-16 | The system shall record pump hours and the shift duty figure together. If either leg fails, neither is recorded. | Must | **Given** one further hour, **when** both legs succeed, **then** the meter figure and the shift figure both rise by 1. **When** the shift leg fails, **then** both stay at the previous figure. | T | The two hour numbers must match. |
| FR-17 | The system shall delay the public road-closed notice by the notice delay after an order has stuck, and shall not send it if an abort is recorded in that delay. | Must | **Given** a stuck order, **when** P-09 elapses with no abort, **then** the notice is sent. **When** an abort is recorded inside the delay, **then** the notice is not sent and the gate order is withdrawn. | T | An abort must be able to void the notice. |
| FR-18 | The system shall group open orders by catchment, and shall flush gauge notices for the log in batches of the batch size or at the batch interval, whichever comes first. | Should | **Given** 10 gauge notices, **when** the tenth arrives, **then** one batch is written. **Given** 3 notices and silence for the batch interval, **then** one batch of 3 is written. Open orders are listed under their catchment. | T | The log is a batch, not a drip. |
| FR-19 | The system shall narrow each flood decision to a single level — refused, planned, issued, held, aborted — for the wall picture. | Must | **Given** a recorded decision, **when** the wall picture is read, **then** it shows exactly one of those five levels, and the full reason remains on the order. | T | The wall is a level. The record keeps the reason. |
| FR-20 | The warden shall be able to abort an issued order by choosing a reason from the published list. Abort releases the shelter and withdraws the gate order. | Must | **Given** an issued order, **when** the warden aborts with a list reason, **then** the order is aborted, the shelter is free, and the gate order is withdrawn. **When** the reason is not on the list, **then** the order stays issued. | T | Abort without a reason cannot be audited. |
| FR-21 | The system shall page every household in the cut. | Retired | Retired 2026-10-10. Door-to-door alerting is out of scope. ID is not reused. | — | Removed before approval. Not deleted. |

### 7.2 Data requirements

| ID | Requirement | Priority | Acceptance criterion | Class | Rationale |
|---|---|---|---|---|---|
| DR-01 | The system shall capture, on every watch, reporter, catchment, level, time of watch, and a short description. | Must | **Given** a submission missing any of those fields, **when** it is submitted, **then** it is not a watch. | T | Level and catchment decide the order. |
| DR-02 | The system shall retain the order, every decision, the rule that won, the road handback, and both pump-hour figures for the retention period. | Must | **Given** an order from today, **when** a reader asks for it on the day before P-10 years have elapsed, **then** it is still present. | I | The engineer and highways both ask after the fact. |
| DR-03 | The system shall prevent a level outside the published list, a pump-hour figure below zero, and a shelter identifier not on the hall list from being recorded. | Must | **Given** level 0, or hours −1, or hall “X9”, **when** it is submitted, **then** it is not recorded. **Given** level 1 and hours 0, **then** the value is recorded and the order rule may still refuse. | T | Bad input stops at the door. |
| DR-04 | The system shall prevent an order for a gate that is not available, and a shelter hold at a hall that is not approved. | Must | **Given** a gate marked not available, **when** an order names it, **then** the order is not recorded. | T | Only the agreed gates and halls. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority | Acceptance criterion | Class |
|---|---|---|---|---|---|
| BR-01 | An order shall not proceed when tide, rain, or wind is outside the published limits, or when any of the three reports is missing. | City flood plan, agreed with the engineer | Must | **Given** wind strictly above P-01, or rain strictly below P-02, or tide strictly below P-03, **when** an order is requested, **then** it is refused under BR-01. The limit value itself does not fire. | T |
| BR-02 | An order shall not proceed when crew duty would pass the duty limit. | City flood plan, city engineer | Must | **Given** duty equal to P-04, **when** an order is requested, **then** BR-02 fires. **Given** duty one minute under, **then** it does not. | T |
| BR-03 | A person sheltered by this desk shall not be charged. The order may record cost to the city. | Council rules | Must | **Given** an order, **when** it is recorded, **then** the record states zero charge to the person. An order that states a resident charge is not recorded. | T |
| BR-04 | Only an approved reporter may open a watch. Only an available gate and an approved shelter may be named in an order. | City flood plan | Must | **Given** a reporter not on the list, **when** a watch is submitted, **then** it is refused under BR-04. Enforced by FR-01 and DR-04. | T |
| BR-05 | A road closure that will not be kept shall be handed back within the handback limit. | Highways letter of 2026-09-18 | Must | **Given** a closure that the order will not use, **when** the failure or abort is known, **then** the handback is recorded within P-07. | T |
| BR-06 | An unissued order yields to a newer watch of strictly higher level on the same gate. An issued order does not yield. | City flood plan level list | Must | **Given** an unissued level 3 and a new level 2, **when** the new watch is accepted, **then** the old order is replaced. **Given** the first order already issued, **then** it stays issued. | T |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention | Priority | Acceptance criterion | Class |
|---|---|---|---|---|---|---|---|
| AR-01 | The daily flood log shall show each watch, the level, the rule or reason that won, the catchment, and whether a road was handed back. | City engineer, highways liaison | Daily, on demand | P-10 years | Must | **Given** a day with one refusal and one issued order, **when** the log is opened, **then** both rows are present with the winning rule. | T |
| AR-02 | The weekly resilience report shall show orders issued, aborted, and refused, by reason, for the Monday–Sunday week. | Sponsor, council | Weekly, Monday 08:00 local | P-10 years | Must | **Given** a week with 4 issued, 1 aborted, and 2 refused, **when** the report is opened, **then** those three figures appear and sum to orders decided, within 0. | T |
| AR-03 | The road handback list shall show every closure given and every closure withdrawn, with times. | Highways liaison | On demand | P-10 years | Must | **Given** one closure given and then withdrawn, **when** the list is opened, **then** both times are present and the gap is at or under P-07. | T |

### 7.5 Parameter register

| ID | Parameter | Used by (requirement IDs) | Value | Unit | Owner | Status (set / TBD) | Open question |
|---|---|---|---|---|---|---|---|
| P-01 | Wind limit (value does not fire; strictly above fires) | BR-01 | 40 | knots | Tomas Berg | set | — |
| P-02 | Rain-rate floor for a level-1 order (value does not fire; strictly below fires) | BR-01 | 8 | millimetres per hour | Tomas Berg | set | — |
| P-03 | Tide floor for a level-1 order (value does not fire; strictly below fires) | BR-01 | 4.2 | metres above chart datum | Tomas Berg | set | — |
| P-04 | Duty limit (value fires) | BR-02 | 600 | minutes | Tomas Berg | set | — |
| P-05 | Chatter window | FR-03 | 5 | seconds | Mara Quinn | set | — |
| P-06 | Radio answer limit, per try | FR-13 | 90 | seconds | Mara Quinn | set | — |
| P-07 | Road handback limit | FR-15, BR-05, AR-03 | 180 | seconds | Mara Quinn | set | — |
| P-08 | Pump reserve (strictly below fires a pump call) | FR-05 | 30 | minutes remaining before P-04 | Tomas Berg | set | — |
| P-09 | Public road-closed notice delay | FR-17 | 60 | seconds | Mara Quinn | set | — |
| P-10 | Order-record retention | DR-02, AR-01, AR-02, AR-03 | 7 | years | Mara Quinn | set | — |
| P-11 | Level snapshot interval | FR-04 | 15 | seconds | Mara Quinn | set | — |
| P-12 | Same-reading repeat window | FR-02 | 60 | seconds | Mara Quinn | set | — |
| P-13 | Notice batch size | FR-18 | 10 | notices | Mara Quinn | set | — |
| P-14 | Notice batch interval | FR-18 | 30 | seconds | Mara Quinn | set | — |
| P-15 | Radio retries after the first silence | FR-13 | 1 | try | Mara Quinn | set | — |
| P-16 | Order decision window | NFR-01 | 180 | seconds | Mara Quinn | set | — |
| P-17 | Desk recovery time | NFR-08 | 5 | minutes | Mara Quinn | set | — |
| P-18 | Abort and refuse reason list | FR-20, FR-08 | weather, duty, no shelter, no answer, replaced by higher level, gate not available, reporter withdrew | list | Tomas Berg | set | — |
| P-19 | Level list, 1 highest | FR-01, FR-08, BR-06 | 1 severe, 2 warning, 3 watch, 4 drill | list | Tomas Berg | set | — |
| P-20 | Peak open orders | NFR-03 | 8 | orders | Mara Quinn | set | — |
| P-21 | Availability target | NFR-02 | 99.5 | percent of the calendar month | Mara Quinn | set | — |

### 7.6 Decision precedence

More than one rule can match one watch. The first matching row wins. Every matching rule is still recorded.

| Order | Rule (requirement ID) | Wins over | All matching reasons recorded? |
|---|---|---|---|
| 1 | BR-01, BR-02 (weather, duty — refuse) | FR-08, FR-10, FR-12, FR-14, BR-06 | yes |
| 2 | BR-04, DR-04 (reporter, gate, or shelter not allowed) | FR-01, FR-14 | yes |
| 3 | FR-09 (second request while issue in progress — ignore) | A second FR-10 / FR-14 for that gate | yes |
| 4 | BR-06, FR-08 (higher level replaces an unissued order only) | The older unissued order | yes |
| 5 | FR-12 (first crew that answers able) | The other crews | yes |
| 6 | FR-14, FR-15, FR-16 (all-or-nothing legs) | Any partial record of those legs | yes |
| 7 | FR-17 (notice delay) | A road-closed notice inside the delay | yes |

An issued order is not replaced by a newer watch. The newer watch waits for a gate that is still open.

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target | Priority | How measured (percentile / window / sample / start and end) | Class |
|---|---|---|---|---|---|---|
| NFR-01 | Performance | The system shall record an order, a refusal, or a replace within the order decision window. | P-16 (180 seconds) | Must | 95th percentile of complete watches in a calendar day, from time of watch to decision recorded, sample of one day with at least 12 watches. | M |
| NFR-02 | Availability | The system shall be available to record a watch at any hour. | P-21 (99.5 percent) | Must | Minutes the desk can record a watch, divided by minutes in the calendar month. | M |
| NFR-03 | Capacity | The system shall hold the peak open orders, and the gauge reports of both cuts, without dropping a well-formed watch. | P-20 (8 orders); 2 cuts at a report every 2 seconds | Must | A counted load of 8 open orders and a two-hour gauge run. Start: empty desk. End: 8th order decided and both cuts still snapping. | M |
| NFR-04 | Security | A gate shall see only its own orders. A shelter shall see only its own holds. A warden and the city engineer shall see the whole desk. No role shall record an order that failed a safety rule. | As stated | Must | One trial per role: allowed action recorded, cross-read not recorded, safety refusal stays refused. | T |
| NFR-05 | Auditability | Every order, refusal, replace, issue, handback, abort, and pump-hour record shall record who acted, when, and which rule or reason won. | As stated | Must | Inspection of one of each action: actor, time to the second, rule or reason present. | T |
| NFR-06 | Usability | A warden shall accept or refuse a complete watch in five steps or fewer. | 5 steps | Should | Five wardens, one complete West Cut watch each, steps counted by the city engineer. Pass: at least four of five finish in five steps. | H |
| NFR-07 | Compliance | The desk shall be run so that an order inside the flood plan is a city decision the engineer can stand over. | City flood plan | Must | Judgment of the city engineer at the pilot review. Class J. Never verified by a check alone. | J |
| NFR-08 | Recoverability | After a desk failure, every issued order and every shelter hold shall still be present, and the desk shall take a new watch within the recovery time. | P-17 (5 minutes) | Must | One simulated failure. Start: failure declared. End: new watch recorded. Issued orders and shelter holds present, count unchanged. | M |

---

## 9. User journeys

### 9.1 Journey: West Cut warning, order sticks

- **Trigger:** Harbour master calls a level 2 warning at West Cut, 14:02. West Cut gate is open, duty 240 minutes. Tide, rain, and wind are all inside the plan.
- **Steps:** Watch recorded (FR-01) → gauge chatter from the last storm collapses to one notice (FR-02, FR-03) → all three weather reports are already held (FR-07) → shelter checks at two halls run together (FR-11) → road warning, then keeper confirm, then pump call, in that order (FR-10) → gate-closed, road-closed, and shelter-open are recorded together (FR-14) → public notice waits 60 seconds (FR-17) → no abort → notice sent.
- **Outcome:** One issued order. A reader never saw the gate closed without the shelter open.
- **Failure path:** If the shelter leg fails after the keeper has accepted the close, the gate order is withdrawn within 180 seconds, the three legs are absent, and no road-closed notice is sent (FR-15).
- **Requirement IDs exercised:** FR-01, FR-02, FR-03, FR-07, FR-10, FR-11, FR-14, FR-15, FR-17, BR-01, BR-05

### 9.2 Journey: Island Cut severe replaces an unissued West Cut order

- **Trigger:** A level 2 West Cut order is open, not issued. The same gate cannot take both, and the only free gate is named on the West Cut order. Police call a level 1 severe on that gate’s other face. For this journey the newer watch is on the same gate.
- **Steps:** New watch recorded → BR-06 and FR-08 replace the level 2 order → shelter hold is released → the level 1 order is the only open order for that gate → weather and duty are checked again (BR-01, BR-02) → issue proceeds only if they pass.
- **Outcome:** One open order, the severe. The first reporter is told the order was replaced.
- **Failure path:** If the first order had already been issued, it stays issued and the new watch waits for a gate that is still open (section 7.6 row 4).
- **Requirement IDs exercised:** FR-08, BR-06, BR-01, BR-02, FR-14

### 9.3 Journey: Double tap and a silent radio

- **Trigger:** Warden requests a close for West Cut. A second request arrives while the first issue is running. The radio does not answer.
- **Steps:** First issue starts (FR-10) → second request ignored (FR-09) → no answer at 90 seconds → one further try (FR-13) → no answer → order held, no issue recorded, no road left closed.
- **Outcome:** One order, held, with reason “no answer.” The gate is still open.
- **Failure path:** If the second try is answered, the issue continues and FR-14 still requires all three legs.
- **Requirement IDs exercised:** FR-09, FR-10, FR-13, FR-14, BR-05

### 9.4 Journey: Pump hours that must match

- **Trigger:** Pump meter confirms one further hour on pump 2 for an open order.
- **Steps:** Meter hours and shift duty figure are recorded together (FR-16) → running figure moves by 1 (FR-05) → a reader sees both figures, or neither.
- **Outcome:** The two hour numbers match.
- **Failure path:** If the shift figure cannot be written, the meter figure is not written either, and the previous total stands.
- **Requirement IDs exercised:** FR-05, FR-16, BR-02

---

## 10. Acceptance criteria

| ID | Criterion (Given / When / Then, with tolerance) | Covers (requirement IDs) | Method of verification (class) |
|---|---|---|---|
| AC-01 | **Given** wind 40 and 41 knots, rain 8 and 7 millimetres per hour, tide 4.2 and 4.1 metres, duty 599 and 600 minutes, **when** an order is requested, **then** the limit that does not fire stays eligible and the one-step breach is refused under BR-01 or BR-02, rule named. | BR-01, BR-02, FR-05 | Test (T) |
| AC-02 | **Given** three same-reading reports inside 60 seconds, then a new reading, **when** they arrive, **then** two notices exist, not four. **Given** reports at 1, 2, and 3 seconds and a 5-second quiet, **then** one chatter notice carries the last reading. | FR-02, FR-03, FR-04 | Test (T) |
| AC-03 | **Given** an unissued level 2 order and a new level 1, **when** the new watch is accepted, **then** the old shelter hold is gone and only the new order is open. **Given** the first order already issued, **then** it is unchanged. | FR-08, BR-06 | Test (T) |
| AC-04 | **Given** an order whose shelter leg fails after the keeper has accepted the close, **when** the failure is known, **then** gate-closed, road-closed, and shelter-open are all absent, the handback is recorded within 180 seconds, and no road-closed notice is sent. | FR-14, FR-15, FR-17, BR-05 | Test (T) |
| AC-05 | **Given** a second close request while the first issue for that gate is running, **when** it arrives, **then** it is not issued. **Given** no radio answer at 90 seconds and none on the second try, **then** the order is held and no issue exists. | FR-09, FR-13 | Test (T) |
| AC-06 | **Given** one further pump hour whose shift leg fails, **when** the failure is known, **then** both hour figures remain at the previous value. | FR-16, FR-05 | Test (T) |
| AC-07 | **Given** a day of at least 12 complete watches, **when** decision times are measured from watch to decision, **then** the 95th percentile is at or under 180 seconds. | NFR-01 | Measurement (M) |
| AC-08 | **Given** the pilot week’s log, **when** the city engineer reviews weather, duty, and zero resident charge, **then** he accepts or rejects NFR-07 in writing. A check cannot close this row. | NFR-07, BR-03 | Judgment (J) |
| AC-09 | **Given** the weekly report for a known week, **when** it is opened, **then** issued, aborted, and refused sum to orders decided, within 0. | AR-02 | Test (T) |

### 10.1 Verification classes

| Class | Meaning | Counts as verified when |
|---|---|---|
| **T** | Check with a fixed expected result (a truth table, a boundary case) | The check ran and passed; the run is recorded |
| **P** | Property or invariant over many generated inputs | The property held over the stated number of cases |
| **M** | Measured against a target (load, availability, recovery) | Measured under stated conditions and met the target |
| **I** | Inspection of design, configuration, or records | A named reviewer recorded the result |
| **H** | Human trial or walkthrough | The trial ran with the stated participants and met the target |
| **J** | Judgment; cannot be reduced to a check | Never “verified”. A named person accepts it, with a review date |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood (H/M/L) | Impact (H/M/L) | Mitigation |
|---|---|---|---|---|
| R-01 | Wind is missing, so every order waits. | M | H | FR-07 refuses rather than guessing. Harbour master is on the reporter card to send a reading with the watch. |
| R-02 | A road handback is spoken on the radio and not recorded. | M | H | FR-15 and BR-05 require the handback on the order. The highways list is the check. |
| R-03 | Standing travel minutes are stale, so the first-crew rule feels wrong. | L | M | City engineer reviews the travel-minute table on the first Monday of each month. The rule itself is “first able answer,” not the standing minutes. |
| R-04 | A double tap is treated as two cuts. | M | H | FR-09 ignores the second request while the first issue runs. |
| R-05 | Pump hours are written on the meter sheet and not on the shift. | M | H | FR-16 records both or neither. |

---

## 12. Success measures

| Measure | Baseline today | Target | Matching requirement (ID) | Reviewed when |
|---|---|---|---|---|
| Orders recorded without a shelter open | 14 of 210 last winter | 0 | FR-14 | Weekly |
| Roads still closed after an abort | 6 last winter | 0 past P-07 | FR-15, BR-05 | Weekly |
| Double orders from one tap | 1 on 19 September | 0 | FR-09 | Weekly |
| Share of complete watches decided inside 180 seconds | Not measured | 95th percentile at or under 180 seconds on a day of at least 12 watches | NFR-01 | End of pilot week |
| Desk availability | Not measured | 99.5 percent of the calendar month | NFR-02 | Monthly |
| Orders issued, aborted, refused | Not totaled | Report present every Monday, figures sum to orders decided within 0 | AR-02 | Weekly, November resilience review |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| Watch | One report from one approved reporter, for one catchment and one level. |
| Order | A chosen gate, road, and shelter for a watch that has not been issued. |
| Issue | The act that marks the gate closed, the road closed, and the shelter open, together. |
| Stuck order | An order whose three legs have all been recorded. Only then does the notice delay start. |
| Abort | An issued order that is cancelled before the closure is kept, with a reason from the list. |
| Hold | An order that cannot proceed, usually because the radio did not answer. Not an issue. |
| Handback | The end of a road closure that will not be kept. It must be recorded within the handback limit. |
| Chatter window | The quiet gap after which a burst of gauge reports becomes one notice. |
| Snapshot | The single water level kept for a cut on each snapshot interval. |
| Level | A rank from the city flood plan. 1 is the highest. |
| Zero charge | The person sheltered pays nothing. Cost to the city may still be recorded. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Blocks (IDs) | Status |
|---|---|---|---|---|---|
| Q-01 | Should a night order use a lower wind limit, or stay at 40 knots all day? | Tomas Berg | 2026-10-24 | None. P-01 stays 40 until a change request. | Open |
| Q-02 | Will the island hall take a level 1 at night, or only the two shore halls? | Ruth Adeyemi | 2026-10-31 | None. All four halls stay eligible until a change request. | Open |

### 14.1 Consistency checks (complete before approval)

- [x] No two requirements or rules contradict each other. An issued order is not replaced. A failed leg leaves no partial order. The notice waits until the order has stuck.
- [x] Where several rules can apply to one case, section 7.6 says which wins.
- [x] Every number a requirement relies on is in the parameter register (7.5), with a value and an owner. No TBD values.
- [x] Every rule that must hold has a stated behavior for when it would be broken: refuse, ignore, replace, withdraw, or do not record.
- [x] Every rule in 7.3 is enforced by at least one requirement in 7.1. BR-01 and BR-02 by FR-07 and FR-05; BR-03 by the order record; BR-04 by FR-01 and DR-04; BR-05 by FR-15; BR-06 by FR-08.
- [x] Every journey step agrees with the requirements it exercises, including who acts.
- [x] The same measure does not have two different targets. The 180-second decision figure is P-16 in NFR-01 and in section 12. The 99.5 percent figure is P-21 in NFR-02 and in section 12. The 180-second handback is P-07 throughout.
- [x] Every target in section 8 says how it is measured.
- [x] Every requirement table has a priority, an acceptance criterion, and a class on every live row. FR-21 is Retired and has no class.

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor | Mara Quinn | | |
| Product owner | Mara Quinn | | |
| Technical lead | | | |
| Compliance / risk | Tomas Berg | | |

### 15.1 Residual acceptance (completed after the build)

| Requirement ID | Why it remains | Accepted by | Date | Review by |
|---|---|---|---|---|
| | | | | |

---

## Appendix A. Residual ledger

`tide-warden-LEDGER.md` — not yet written. Gate B1 may extract the register from this file. The ledger itself is written after the Demo and the `<stem>-test.dart` report.

## Appendix B. Orphan behavior register

| Behavior | Where | Serves requirement? | Disposition (add / remove / accept) | Decided by |
|---|---|---|---|---|
| | | | | |

---

*End of sample BRD. Organisation and people are fictional. Wind, rain, tide, and handback figures are city flood-plan policy for this sample, not a claim about statute.*
