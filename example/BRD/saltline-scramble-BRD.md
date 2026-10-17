# Business Requirements Document — Saltline Scramble

**Template version:** 2.0
**Stem:** `SaltlineScramble`
**Pipeline note:** Worked sample for a Mitose 2.0 run. Fictional service, real operating problem. A different industry from Pantry Bridge. The desk listens to several live reports at once, and a scramble is not real unless the aircraft, the crew duty, and the receiving bay are recorded together or not at all. This file says what the service needs. It does not say how the desk will be built.

---

## 1. Document control

| Field | Value |
|---|---|
| Project name | Saltline Scramble |
| Document title | Business Requirements Document — Saltline Scramble coastal air-mercy desk |
| Version | 0.1 draft |
| Date | 2026-10-10 |
| Author | Capt. Ida Voss, Duty Director, Saltline Air Mercy (sample) |
| Reviewer(s) | Dr. Elena Márquez, Duty medical director; Jonah Hale, Chief pilot |
| Approver(s) | Ida Voss, Duty Director (sponsor); Dr. Elena Márquez, Duty medical director |
| Status | draft — sample for the Mitose 2.0 pipeline, not yet approved |

**Revision history**

| Version | Date | Change ID | Author | Change summary |
|---|---|---|---|---|
| 0.1 | 2026-10-10 | — | Ida Voss | First draft. Sample BRD for a Mitose 2.0 pipeline run. |

---

## 2. Executive summary

Saltline Air Mercy flies one helicopter from Harbor Pad and a second from Island Pad for cliff rescue, ferry medical calls, and transfers into Harbor General. Today the scramble is a radio, a whiteboard, and a nurse who shouts bay numbers down a corridor. A second call can steal a bay that the first call still thinks it holds, a position report can repeat until the log is useless, and a tower slot can be taken when the hospital bay was never held. Saltline Scramble is the desk the service needs: live reports are reduced to what a dispatcher can act on, a higher-severity call can replace a plan that has not launched, and a launch exists only when the aircraft, the crew duty, and the receiving bay have all been recorded, or none of them have. If the tower has already been given a slot and a later leg fails, that slot is withdrawn before anyone is told the aircraft is airborne.

---

## 3. Business context

### 3.1 Background

Saltline is a joint charity and health-service desk covering Harbor City, two island ferries, and the cliff path. Two aircraft, four pilot-paramedic crews, one shore pad and one island pad. Harbor General keeps two resuscitation bays for inbound air-mercy patients. Last summer the desk handled 640 scrambles. Nineteen of those left a bay marked held on the whiteboard after the aircraft had already returned. Four left a tower slot open after a ground abort. Position reports from the aircraft arrive about every two seconds and are copied by hand.

### 3.2 Problem statement

On 12 August a cliff fall was being planned when a ferry cardiac call came in. The dispatcher told Island Pad to launch, then found Harbor General’s bay had been held for the cliff fall and not released. The ferry patient waited six extra minutes. The same week the public notice said an aircraft was airborne when it was still on the pad: the notice went out at the moment the tower accepted the slot, and the bay hold failed a minute later. Crews also breach the duty limit because the running hours are a tally on paper, one flight behind.

### 3.3 Business drivers

- The medical director will not sign the winter roster until a launch cannot exist without a bay.
- The tower wrote on 2026-09-03 that a slot given and then not flown must be handed back within two minutes.
- Pilots asked for one scramble tap to count once. A double tap on 2 September launched two plans for one aircraft.
- The board wants a weekly picture of launched, ground-aborted, and refused missions before the November service review.

### 3.4 Alignment with strategy

The 2026 service goal is “the right aircraft, the right bay, no half launch.” Saltline Scramble is that rule made checkable: weather and duty can stop a flight, a newer severe call can replace an unlaunched plan, and the public hears “airborne” only after the launch has stuck.

---

## 4. Scope

### 4.1 In scope

- Recording an incident from an approved caller, with place, severity, and time.
- Reducing live aircraft-position reports so repeats and chatter do not each become a notice.
- Taking a regular position snapshot even when reports arrive faster than that.
- Holding the latest scene weather and the latest pad weather, and refusing a launch when either is missing or outside limits.
- Replacing an unlaunched plan when a newer, higher-severity incident is accepted.
- Ignoring a second scramble request for the same aircraft while the first request is still being issued.
- Calling crew, confirming fuel, and asking the tower for a slot, in that order, not overlapping.
- Letting several hospital bay checks proceed at the same time.
- Taking the first pad that answers a dual-pad request.
- Trying the radio once more if it does not answer in time, then holding.
- Recording aircraft-out, crew-duty open, and bay-held together, or not at all.
- Withdrawing a tower slot if a later leg of the same launch fails, before any airborne notice.
- Recording fuel uplift and the mission fuel figure together.
- Delaying the public airborne notice long enough for a ground abort to void it.
- Grouping open missions by pad, and flushing position notices in batches for the log.
- A weekly launched / ground-aborted / refused report.

### 4.2 Out of scope

- Clinical treatment on scene or in the cabin.
- Maintenance planning beyond “aircraft not available.”
- Public fundraising and roster recruitment.
- Predicting tomorrow’s weather. The desk uses the latest report it has been given.
- Fixed-wing transfers and drone search. Not this desk.
- Billing the patient. The mission folio records cost to the service, never a charge to the person flown.

### 4.3 Assumptions

- Each aircraft has one named pilot-in-command on duty, or it is not available.
- Harbor General and Island Cottage are the only receiving hospitals in this draft.
- Drive is not the point. Flight minutes between each pad and each named place are a standing figure agreed by the chief pilot.
- “Operating window” is all day, seven days. The desk does not close at night.
- A severity rank is given by the duty medical director’s list, not invented by the dispatcher.
- Weather reports and position reports arrive already measured. The desk does not estimate them.

### 4.4 Constraints

- A reader must never see the aircraft marked out without a bay held, or a bay held for a mission that does not exist.
- A tower slot is an act that can succeed and then have to be undone. Undoing it is part of the launch, not a later courtesy.
- Volunteer shore crew are not employed dispatchers. A confirmation is a recorded statement by the named person.
- Duty limit, weather limits, and the slot-handback limit are the service operations manual, agreed with the medical director and the tower. They are not guessed in this draft.

### 4.5 Dependencies

- The approved caller list (coastguard, ferry master, cliff warden, hospital transfer desk) must exist before the first incident.
- The medical director must publish the severity list and the weather limits before go-live.
- The tower must accept a handback as the end of a slot.
- Each pad must name a duty pilot at the start of the shift, or that pad is unavailable.

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence (H/M/L) | Engagement approach |
|---|---|---|---|---|
| Sponsor | Capt. Ida Voss, Duty Director | No half launch, winter roster signed | H | Weekly one-page note |
| Primary user | Scramble dispatchers | One plan per aircraft, a clear reason when a call is refused | H | Shift walkthrough before pilot |
| Pilot | Jonah Hale, Chief pilot, and duty pilots | Duty limit kept, one launch tap, fuel figure that matches the bowser | H | Pilot briefing |
| Medical director | Dr. Elena Márquez | Higher severity wins, bay actually held | H | Sign-off on rules before pilot |
| Receiving nurse | Priya Shah, Harbor General charge nurse | A bay held only for a mission that exists | H | Hospital workshop |
| Tower | Harbor Tower duty officer | Slot handed back within the handback limit | M | Agreed handback drill |
| Coastguard caller | Approved callers | A yes, a no, or a “replaced by a higher call” | M | Caller card |
| Board | Saltline trustees | Weekly launched, aborted, refused | M | November service review |

---

## 6. Users and personas

### 6.1 Ida Voss — scramble dispatcher

- **Role:** Duty director and lead dispatcher
- **Context:** Shore desk, all shift. A second dispatcher covers the island radio.
- **Goal:** Turn a complete incident into one plan, or a clear refusal, without leaving a bay or a slot dangling.
- **Pain today:** The whiteboard can show a bay held and the aircraft still on the pad, or the reverse.
- **Success looks like:** Either the aircraft, the crew duty, and the bay all change, or none of them do. A second tap does nothing while the first issue is still running.

### 6.2 Jonah Hale — pilot-in-command

- **Role:** Chief pilot, often the Harbor Pad captain
- **Context:** Pad hut, then the aircraft. Position reports leave the aircraft about every two seconds.
- **Goal:** Launch once, inside weather and duty limits, with a fuel figure that matches what was uplifted.
- **Pain today:** Paper hours are a flight behind. A double radio call has put two plans on one aircraft.
- **Success looks like:** Duty hours move only when the mission is recorded, and the same position is not shouted twice.

### 6.3 Priya Shah — receiving charge nurse

- **Role:** Charge nurse for the two resuscitation bays
- **Context:** Harbor General, bay desk.
- **Goal:** Hold a bay for an inbound aircraft, and get it back if that aircraft does not launch.
- **Pain today:** A bay stays held after a ground abort because the radio call and the whiteboard are different acts.
- **Success looks like:** A bay is held only as part of a recorded launch, and a failed launch releases it.

---

## 7. Business requirements

Requirement IDs are permanent. A removed requirement is marked Retired, not deleted.

### 7.1 Functional requirements

| ID | Requirement | Priority (Must / Should / Could) | Acceptance criterion (Given / When / Then, with tolerance) | Class | Rationale |
|---|---|---|---|---|---|
| FR-01 | The system shall record an incident from an approved caller with place, severity rank, time, and caller name. | Must | **Given** an approved caller and a complete incident, **when** it is submitted, **then** it is open and carries every field in DR-01. A caller not on the list is not recorded. | T | No plan without an incident. |
| FR-02 | The system shall treat a run of position reports for the same aircraft that repeat the same fix as one notice, not one notice each. | Must | **Given** three reports for aircraft A at the same fix inside the repeat window, **when** they arrive, **then** one notice is raised. A later report at a different fix raises a new notice. | T | The log must be readable. |
| FR-03 | The system shall collapse position reports for one aircraft that arrive inside the chatter window into a single notice at the end of that quiet gap. | Must | **Given** reports at 1 second, 2 seconds, and 3 seconds, and then silence for the chatter window, **when** the window elapses, **then** one notice is raised, carrying the last fix. | T | Two-second reports must not each page the desk. |
| FR-04 | The system shall take a position snapshot for each aircraft on the snapshot interval even if reports arrive faster. | Must | **Given** reports every 2 seconds, **when** one snapshot interval elapses, **then** exactly one snapshot is kept for that interval, the latest fix in it. | T | The wall picture is regular. |
| FR-05 | The system shall keep a running fuel-on-board figure for each aircraft from uplift and burn reports, and shall refuse a launch whose figure is below the reserve. | Must | **Given** fuel 400 litres and an uplift of 50, **when** the uplift is accepted, **then** the figure is 450. **Given** a figure below P-08, **when** a launch is requested, **then** it is refused under BR-02. | T | Paper hours and paper fuel are a flight behind. |
| FR-06 | The system shall compare each position snapshot with the previous one and shall say whether the aircraft is moving or still. | Must | **Given** two snapshots at different fixes, **when** the second arrives, **then** the aircraft is marked moving. **Given** the same fix twice, **then** it is marked still. | T | A still aircraft after launch is a ground-abort clue. |
| FR-07 | The system shall hold the latest scene weather and the latest pad weather, and shall not launch until both have been received and both are inside limits. | Must | **Given** pad weather inside limits and no scene weather yet, **when** a launch is requested, **then** it is not launched. **Given** both inside limits, **then** weather does not block. **Given** either outside limits, **then** BR-01 fires. | T | Both ends of the flight matter. |
| FR-08 | The system shall replace an unlaunched plan when a newer incident of strictly higher severity is accepted for the same aircraft, and shall release every hold the old plan took. | Must | **Given** an unlaunched plan for severity 2, **when** a severity 1 incident is accepted, **then** the old plan is replaced, its bay hold is gone, and only the new plan is open. A launched plan is not replaced. | T | The August ferry case. |
| FR-09 | The system shall ignore a second scramble request for the same aircraft while the first request is still being issued. | Must | **Given** a scramble issue in progress for aircraft A, **when** a second request for A arrives, **then** the second request is not issued and the first issue is unchanged. | T | The 2 September double tap. |
| FR-10 | The system shall issue crew call, then fuel confirm, then tower slot request, in that order, for one launch. A later step shall not start until the earlier step has succeeded. | Must | **Given** a launch being issued, **when** the crew call has not succeeded, **then** fuel confirm and the slot request do not start. **When** the crew call succeeds, **then** fuel confirm starts, and not before. | T | Order is the safety brief. |
| FR-11 | The system shall check bay availability at more than one receiving hospital at the same time. | Must | **Given** Harbor General and Island Cottage both eligible, **when** a plan is built, **then** both checks are in progress together, and a slow answer from one does not wait on the other to start. | T | Minutes matter. |
| FR-12 | The system shall award a dual-pad request to the first pad that answers able, and shall release the other pad. | Must | **Given** both pads asked, **when** Island Pad answers able and Harbor Pad has not, **then** Island Pad is the one reserved and Harbor Pad is released. | T | First able pad wins. |
| FR-13 | The system shall try the radio once more if no answer arrives within the radio limit, and shall hold the plan if the second try also fails. | Must | **Given** no answer at P-06, **when** the limit elapses, **then** one further try is made. **Given** no answer at the second limit, **then** the plan is held and no launch is recorded. | T | A silent radio is not a launch. |
| FR-14 | The system shall record aircraft-out, crew-duty opened, and bay-held as one act. If any leg cannot be recorded, none of them are. | Must | **Given** a legal launch, **when** all three legs succeed, **then** a reader sees all three. **When** the bay leg fails, **then** a reader sees the aircraft still in, the duty unopened, and the bay free. | T | No half launch. |
| FR-15 | The system shall withdraw a tower slot if a later leg of that same launch fails, and shall do so before any airborne notice. The aircraft shall not be left out. | Must | **Given** a slot already given and a bay leg that then fails, **when** the failure is known, **then** the slot is withdrawn, the airborne notice is not sent, and the aircraft is in. Withdrawal is recorded within P-07 of the failure. | T | The tower letter of 2026-09-03. |
| FR-16 | The system shall record a fuel uplift and the mission fuel figure together. If either leg fails, neither is recorded. | Must | **Given** an uplift of 50 litres, **when** both legs succeed, **then** the bowser figure and the mission figure both rise by 50. **When** the mission leg fails, **then** both stay at the previous figure. | T | The two fuel numbers must match. |
| FR-17 | The system shall delay the public airborne notice by the notice delay after a launch has stuck, and shall not send it if a ground abort is recorded in that delay. | Must | **Given** a stuck launch, **when** P-09 elapses with no ground abort, **then** the notice is sent. **When** a ground abort is recorded inside the delay, **then** the notice is not sent and the slot is withdrawn. | T | A ground abort must be able to void the notice. |
| FR-18 | The system shall group open missions by pad, and shall flush position notices for the log in batches of the batch size or at the batch interval, whichever comes first. | Should | **Given** 10 position notices, **when** the tenth arrives, **then** one batch is written. **Given** 3 notices and silence for the batch interval, **then** one batch of 3 is written. Open missions are listed under their pad. | T | The log is a batch, not a drip. |
| FR-19 | The system shall narrow each scramble decision to a single level — refused, planned, launched, held, aborted — for the wall picture. | Must | **Given** a recorded decision, **when** the wall picture is read, **then** it shows exactly one of those five levels, and the full reason remains on the mission. | T | The wall is a level. The record keeps the reason. |
| FR-20 | The dispatcher shall be able to ground-abort a launched mission by choosing a reason from the published list. Abort releases the bay and withdraws the slot. | Must | **Given** a launched mission, **when** the dispatcher aborts with a list reason, **then** the mission is aborted, the bay is free, and the slot is withdrawn. **When** the reason is not on the list, **then** the mission stays launched. | T | Abort without a reason cannot be audited. |
| FR-21 | The system shall page every household near the cliff. | Retired | Retired 2026-10-10. Public alerting is out of scope. ID is not reused. | — | Removed before approval. Not deleted. |

### 7.2 Data requirements

| ID | Requirement | Priority | Acceptance criterion | Class | Rationale |
|---|---|---|---|---|---|
| DR-01 | The system shall capture, on every incident, caller, place, severity rank, time of call, and a short description. | Must | **Given** a submission missing any of those fields, **when** it is submitted, **then** it is not an incident. | T | Severity and place decide the plan. |
| DR-02 | The system shall retain the mission, every decision, the rule that won, the slot handback, and both fuel figures for the retention period. | Must | **Given** a mission from today, **when** a reader asks for it on the day before P-10 years have elapsed, **then** it is still present. | I | The medical director and the tower both ask after the fact. |
| DR-03 | The system shall prevent a severity outside the published list, a fuel figure below zero, and a bay identifier not on the hospital list from being recorded. | Must | **Given** severity 0, or fuel −1, or bay “X9”, **when** it is submitted, **then** it is not recorded. **Given** severity 1 and fuel 0, **then** the value is recorded and the launch rule may still refuse. | T | Bad input stops at the door. |
| DR-04 | The system shall prevent a plan for an aircraft that is not available, and a bay hold at a hospital that is not approved. | Must | **Given** an aircraft marked not available, **when** a plan names it, **then** the plan is not recorded. | T | Only the agreed fleet and hospitals. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority | Acceptance criterion | Class |
|---|---|---|---|---|---|
| BR-01 | A launch shall not proceed when scene or pad weather is outside the published limits, or when either report is missing. | Service operations manual, agreed with the medical director | Must | **Given** wind strictly above P-01, or visibility strictly below P-02, or ceiling strictly below P-03, **when** a launch is requested, **then** it is refused under BR-01. The limit value itself does not fire. | T |
| BR-02 | A launch shall not proceed when crew duty would pass the duty limit, or when fuel on board is below the reserve. | Service operations manual, chief pilot | Must | **Given** duty equal to P-04, **when** a launch is requested, **then** BR-02 fires. **Given** duty one minute under, **then** it does not. **Given** fuel strictly below P-08, **then** it fires. | T |
| BR-03 | A patient flown by this desk shall not be charged. The mission may record cost to the service. | Charity rules | Must | **Given** a mission, **when** it is recorded, **then** the record states zero charge to the person. A mission that states a patient charge is not recorded. | T |
| BR-04 | Only an approved caller may open an incident. Only an available aircraft and an approved hospital bay may be named in a plan. | Service operations manual | Must | **Given** a caller not on the list, **when** an incident is submitted, **then** it is refused under BR-04. Enforced by FR-01 and DR-04. | T |
| BR-05 | A tower slot that will not be flown shall be handed back within the handback limit. | Tower letter of 2026-09-03 | Must | **Given** a slot that the launch will not use, **when** the failure or abort is known, **then** the handback is recorded within P-07. | T |
| BR-06 | An unlaunched plan yields to a newer incident of strictly higher severity on the same aircraft. A launched mission does not yield. | Medical director severity list | Must | **Given** an unlaunched severity 3 and a new severity 2, **when** the new incident is accepted, **then** the old plan is replaced. **Given** the first mission already launched, **then** it stays launched. | T |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention | Priority | Acceptance criterion | Class |
|---|---|---|---|---|---|---|---|
| AR-01 | The daily scramble log shall show each incident, the level, the rule or reason that won, the pad, and whether a slot was handed back. | Medical director, tower liaison | Daily, on demand | P-10 years | Must | **Given** a day with one refusal and one launch, **when** the log is opened, **then** both rows are present with the winning rule. | T |
| AR-02 | The weekly service report shall show missions launched, ground-aborted, and refused, by reason, for the Monday–Sunday week. | Sponsor, board | Weekly, Monday 08:00 local | P-10 years | Must | **Given** a week with 4 launched, 1 aborted, and 2 refused, **when** the report is opened, **then** those three figures appear and sum to missions decided, within 0. | T |
| AR-03 | The slot handback list shall show every slot given and every slot withdrawn, with times. | Tower liaison | On demand | P-10 years | Must | **Given** one slot given and then withdrawn, **when** the list is opened, **then** both times are present and the gap is at or under P-07. | T |

### 7.5 Parameter register

| ID | Parameter | Used by (requirement IDs) | Value | Unit | Owner | Status (set / TBD) | Open question |
|---|---|---|---|---|---|---|---|
| P-01 | Wind limit (value does not fire; strictly above fires) | BR-01 | 35 | knots | Dr. Elena Márquez | set | — |
| P-02 | Visibility limit (value does not fire; strictly below fires) | BR-01 | 1.5 | kilometres | Dr. Elena Márquez | set | — |
| P-03 | Ceiling limit (value does not fire; strictly below fires) | BR-01 | 500 | feet | Dr. Elena Márquez | set | — |
| P-04 | Duty limit (value fires) | BR-02 | 600 | minutes | Jonah Hale | set | — |
| P-05 | Chatter window | FR-03 | 5 | seconds | Ida Voss | set | — |
| P-06 | Radio answer limit, per try | FR-13 | 90 | seconds | Ida Voss | set | — |
| P-07 | Slot handback limit | FR-15, BR-05, AR-03 | 120 | seconds | Ida Voss | set | — |
| P-08 | Fuel reserve (strictly below fires) | FR-05, BR-02 | 80 | litres | Jonah Hale | set | — |
| P-09 | Public airborne notice delay | FR-17 | 60 | seconds | Ida Voss | set | — |
| P-10 | Mission-record retention | DR-02, AR-01, AR-02, AR-03 | 7 | years | Ida Voss | set | — |
| P-11 | Position snapshot interval | FR-04 | 15 | seconds | Ida Voss | set | — |
| P-12 | Same-fix repeat window | FR-02 | 60 | seconds | Ida Voss | set | — |
| P-13 | Notice batch size | FR-18 | 10 | notices | Ida Voss | set | — |
| P-14 | Notice batch interval | FR-18 | 30 | seconds | Ida Voss | set | — |
| P-15 | Radio retries after the first silence | FR-13 | 1 | try | Ida Voss | set | — |
| P-16 | Plan decision window | NFR-01 | 180 | seconds | Ida Voss | set | — |
| P-17 | Desk recovery time | NFR-08 | 5 | minutes | Ida Voss | set | — |
| P-18 | Abort and refuse reason list | FR-20, FR-08 | weather, duty, fuel, no bay, no answer, replaced by higher severity, aircraft not available, caller withdrew | list | Dr. Elena Márquez | set | — |
| P-19 | Severity list, 1 highest | FR-01, FR-08, BR-06 | 1 cardiac or not breathing, 2 major trauma, 3 other injury, 4 transfer | list | Dr. Elena Márquez | set | — |
| P-20 | Peak open plans | NFR-03 | 8 | plans | Ida Voss | set | — |
| P-21 | Availability target | NFR-02 | 99.5 | percent of the calendar month | Ida Voss | set | — |

### 7.6 Decision precedence

More than one rule can match one incident. The first matching row wins. Every matching rule is still recorded.

| Order | Rule (requirement ID) | Wins over | All matching reasons recorded? |
|---|---|---|---|
| 1 | BR-01, BR-02 (weather, duty, fuel — refuse) | FR-08, FR-10, FR-12, FR-14, BR-06 | yes |
| 2 | BR-04, DR-04 (caller, aircraft, or hospital not allowed) | FR-01, FR-14 | yes |
| 3 | FR-09 (second request while issue in progress — ignore) | A second FR-10 / FR-14 for that aircraft | yes |
| 4 | BR-06, FR-08 (higher severity replaces an unlaunched plan only) | The older unlaunched plan | yes |
| 5 | FR-12 (first pad that answers able) | The other pad | yes |
| 6 | FR-14, FR-15, FR-16 (all-or-nothing legs) | Any partial record of those legs | yes |
| 7 | FR-17 (notice delay) | An airborne notice inside the delay | yes |

A launched mission is not replaced by a newer call. The newer call waits for an aircraft that is still in.

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target | Priority | How measured (percentile / window / sample / start and end) | Class |
|---|---|---|---|---|---|---|
| NFR-01 | Performance | The system shall record a plan, a refusal, or a replace within the plan decision window. | P-16 (180 seconds) | Must | 95th percentile of complete incidents in a calendar day, from time of incident to decision recorded, sample of one day with at least 12 incidents. | M |
| NFR-02 | Availability | The system shall be available to record an incident at any hour. | P-21 (99.5 percent) | Must | Minutes the desk can record an incident, divided by minutes in the calendar month. | M |
| NFR-03 | Capacity | The system shall hold the peak open plans, and the position reports of both aircraft, without dropping a well-formed incident. | P-20 (8 plans); 2 aircraft at a report every 2 seconds | Must | A counted load of 8 open plans and a two-hour position run. Start: empty desk. End: 8th plan decided and both aircraft still snapping. | M |
| NFR-04 | Security | A pad shall see only its own plans. A hospital shall see only its own bay holds. A dispatcher and the medical director shall see the whole desk. No role shall record a launch that failed a safety rule. | As stated | Must | One trial per role: allowed action recorded, cross-read not recorded, safety refusal stays refused. | T |
| NFR-05 | Auditability | Every plan, refusal, replace, launch, handback, abort, and fuel uplift shall record who acted, when, and which rule or reason won. | As stated | Must | Inspection of one of each action: actor, time to the second, rule or reason present. | T |
| NFR-06 | Usability | A dispatcher shall accept or refuse a complete incident in five steps or fewer. | 5 steps | Should | Five dispatchers, one complete cliff incident each, steps counted by the medical director. Pass: at least four of five finish in five steps. | H |
| NFR-07 | Compliance | The desk shall be run so that a launch inside weather and duty limits is a service decision the medical director can stand over. | Operations manual | Must | Judgment of the medical director at the pilot review. Class J. Never verified by a check alone. | J |
| NFR-08 | Recoverability | After a desk failure, every launched mission and every bay hold shall still be present, and the desk shall take a new incident within the recovery time. | P-17 (5 minutes) | Must | One simulated failure. Start: failure declared. End: new incident recorded. Launched missions and bay holds present, count unchanged. | M |

---

## 9. User journeys

### 9.1 Journey: Cliff fall, launch sticks

- **Trigger:** Cliff warden calls a severity 2 fall at North Head, 14:02. Harbor Pad aircraft is in, duty 240 minutes, fuel 200 litres. Pad weather and scene weather are both inside limits.
- **Steps:** Incident recorded (FR-01) → position chatter from the last flight collapses to one notice (FR-02, FR-03) → both weather reports are already held (FR-07) → bay checks at Harbor General and Island Cottage run together (FR-11) → crew call, then fuel confirm, then tower slot, in that order (FR-10) → aircraft-out, duty opened, and bay-held are recorded together (FR-14) → public notice waits 60 seconds (FR-17) → no ground abort → notice sent.
- **Outcome:** One launched mission. A reader never saw the aircraft out without the bay held.
- **Failure path:** If the bay leg fails after the tower has taken the slot, the slot is withdrawn within 120 seconds, the three legs are absent, and no airborne notice is sent (FR-15).
- **Requirement IDs exercised:** FR-01, FR-02, FR-03, FR-07, FR-10, FR-11, FR-14, FR-15, FR-17, BR-01, BR-05

### 9.2 Journey: Ferry cardiac replaces an unlaunched cliff plan

- **Trigger:** A severity 2 cliff plan is open, not launched. Ferry master calls a severity 1 cardiac.
- **Steps:** New incident recorded → BR-06 and FR-08 replace the cliff plan → cliff bay hold is released → the cardiac plan is the only open plan for that aircraft → weather and duty are checked again (BR-01, BR-02) → issue proceeds only if they pass.
- **Outcome:** One open plan, the cardiac. The cliff caller is told the plan was replaced.
- **Failure path:** If the cliff mission had already launched, it stays launched and the cardiac call waits for the other aircraft (section 7.6 row 4).
- **Requirement IDs exercised:** FR-08, BR-06, BR-01, BR-02, FR-14

### 9.3 Journey: Double tap and a silent radio

- **Trigger:** Dispatcher requests a scramble for Harbor aircraft. A second request arrives while the first issue is running. The radio does not answer.
- **Steps:** First issue starts (FR-10) → second request ignored (FR-09) → no answer at 90 seconds → one further try (FR-13) → no answer → plan held, no launch recorded, no slot left open.
- **Outcome:** One plan, held, with reason “no answer.” The aircraft is still in.
- **Failure path:** If the second try is answered, the issue continues and FR-14 still requires all three legs.
- **Requirement IDs exercised:** FR-09, FR-10, FR-13, FR-14, BR-05

### 9.4 Journey: Fuel uplift that must match

- **Trigger:** Bowser confirms 50 litres onto the Harbor aircraft for an open mission.
- **Steps:** Uplift and mission fuel figure are recorded together (FR-16) → running figure moves by 50 (FR-05) → a reader sees both figures, or neither.
- **Outcome:** The two fuel numbers match.
- **Failure path:** If the mission figure cannot be written, the bowser figure is not written either, and the previous total stands.
- **Requirement IDs exercised:** FR-05, FR-16, BR-02

---

## 10. Acceptance criteria

| ID | Criterion (Given / When / Then, with tolerance) | Covers (requirement IDs) | Method of verification (class) |
|---|---|---|---|
| AC-01 | **Given** wind 35 and 36 knots, visibility 1.5 and 1.4 kilometres, duty 599 and 600 minutes, fuel 80 and 79 litres, **when** a launch is requested, **then** the limit that does not fire stays eligible and the one-step breach is refused under BR-01 or BR-02, rule named. | BR-01, BR-02, FR-05 | Test (T) |
| AC-02 | **Given** three same-fix reports inside 60 seconds, then a new fix, **when** they arrive, **then** two notices exist, not four. **Given** reports at 1, 2, and 3 seconds and a 5-second quiet, **then** one chatter notice carries the last fix. | FR-02, FR-03, FR-04 | Test (T) |
| AC-03 | **Given** an unlaunched severity 2 plan and a new severity 1, **when** the new incident is accepted, **then** the old bay hold is gone and only the new plan is open. **Given** the first mission already launched, **then** it is unchanged. | FR-08, BR-06 | Test (T) |
| AC-04 | **Given** a launch whose bay leg fails after the tower has taken the slot, **when** the failure is known, **then** aircraft-out, duty-open, and bay-held are all absent, the slot handback is recorded within 120 seconds, and no airborne notice is sent. | FR-14, FR-15, FR-17, BR-05 | Test (T) |
| AC-05 | **Given** a second scramble request while the first issue for that aircraft is running, **when** it arrives, **then** it is not issued. **Given** no radio answer at 90 seconds and none on the second try, **then** the plan is held and no launch exists. | FR-09, FR-13 | Test (T) |
| AC-06 | **Given** an uplift of 50 litres whose mission leg fails, **when** the failure is known, **then** both fuel figures remain at the previous value. | FR-16, FR-05 | Test (T) |
| AC-07 | **Given** a day of at least 12 complete incidents, **when** decision times are measured from incident to decision, **then** the 95th percentile is at or under 180 seconds. | NFR-01 | Measurement (M) |
| AC-08 | **Given** the pilot week’s log, **when** the medical director reviews weather, duty, and zero patient charge, **then** she accepts or rejects NFR-07 in writing. A check cannot close this row. | NFR-07, BR-03 | Judgment (J) |
| AC-09 | **Given** the weekly report for a known week, **when** it is opened, **then** launched, aborted, and refused sum to missions decided, within 0. | AR-02 | Test (T) |

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
| R-01 | Scene weather is missing, so every launch waits. | M | H | FR-07 refuses rather than guessing. Coastguard is on the caller card to send a reading with the incident. |
| R-02 | A slot handback is spoken on the radio and not recorded. | M | H | FR-15 and BR-05 require the handback on the mission. The tower list is the check. |
| R-03 | Standing flight minutes are stale, so the first-pad rule feels wrong. | L | M | Chief pilot reviews the flight-minute table on the first Monday of each month. The rule itself is “first able answer,” not the standing minutes. |
| R-04 | A double tap is treated as two patients. | M | H | FR-09 ignores the second request while the first issue runs. |
| R-05 | Fuel uplift is written on the bowser sheet and not on the mission. | M | H | FR-16 records both or neither. |

---

## 12. Success measures

| Measure | Baseline today | Target | Matching requirement (ID) | Reviewed when |
|---|---|---|---|---|
| Launches recorded without a bay hold | 19 of 640 last summer | 0 | FR-14 | Weekly |
| Tower slots still open after a ground abort | 4 last summer | 0 past P-07 | FR-15, BR-05 | Weekly |
| Double plans from one tap | 1 on 2 September | 0 | FR-09 | Weekly |
| Share of complete incidents decided inside 180 seconds | Not measured | 95th percentile at or under 180 seconds on a day of at least 12 incidents | NFR-01 | End of pilot week |
| Desk availability | Not measured | 99.5 percent of the calendar month | NFR-02 | Monthly |
| Missions launched, aborted, refused | Not totaled | Report present every Monday, figures sum to missions decided within 0 | AR-02 | Weekly, November service review |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| Incident | One call from one approved caller, for one place and one severity. |
| Plan | A chosen aircraft, pad, and bay for an incident that has not launched. |
| Launch | The act that marks the aircraft out, opens crew duty, and holds the bay, together. |
| Stuck launch | A launch whose three legs have all been recorded. Only then does the notice delay start. |
| Ground abort | A launch that is cancelled before the aircraft is committed to the flight, with a reason from the list. |
| Hold | A plan that cannot proceed, usually because the radio did not answer. Not a launch. |
| Slot | Permission from the tower to use the pad path. It can be given and must be handed back if not flown. |
| Chatter window | The quiet gap after which a burst of position reports becomes one notice. |
| Snapshot | The single position kept for an aircraft on each snapshot interval. |
| Severity | A rank from the medical director’s list. 1 is the highest. |
| Zero charge | The person flown pays nothing. Cost to the service may still be recorded. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Blocks (IDs) | Status |
|---|---|---|---|---|---|
| Q-01 | Should a night flight use a lower wind limit, or stay at 35 knots all day? | Jonah Hale | 2026-10-24 | None. P-01 stays 35 until a change request. | Open |
| Q-02 | Will Island Cottage take severity 1 at night, or only Harbor General? | Dr. Elena Márquez | 2026-10-31 | None. Both hospitals stay eligible until a change request. | Open |

### 14.1 Consistency checks (complete before approval)

- [x] No two requirements or rules contradict each other. A launched mission is not replaced. A failed leg leaves no partial launch. The notice waits until the launch has stuck.
- [x] Where several rules can apply to one case, section 7.6 says which wins.
- [x] Every number a requirement relies on is in the parameter register (7.5), with a value and an owner. No TBD values.
- [x] Every rule that must hold has a stated behavior for when it would be broken: refuse, ignore, replace, withdraw, or do not record.
- [x] Every rule in 7.3 is enforced by at least one requirement in 7.1. BR-01 and BR-02 by FR-07 and FR-05; BR-03 by the mission record; BR-04 by FR-01 and DR-04; BR-05 by FR-15; BR-06 by FR-08.
- [x] Every journey step agrees with the requirements it exercises, including who acts.
- [x] The same measure does not have two different targets. The 180-second figure is P-16 in NFR-01 and in section 12. The 99.5 percent figure is P-21 in NFR-02 and in section 12. The 120-second handback is P-07 throughout.
- [x] Every target in section 8 says how it is measured.
- [x] Every requirement table has a priority, an acceptance criterion, and a class on every live row. FR-21 is Retired and has no class.

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor | Capt. Ida Voss | | |
| Product owner | Capt. Ida Voss | | |
| Technical lead | | | |
| Compliance / risk | Dr. Elena Márquez | | |

### 15.1 Residual acceptance (completed after the build)

| Requirement ID | Why it remains | Accepted by | Date | Review by |
|---|---|---|---|---|
| | | | | |

---

## Appendix A. Residual ledger

`SaltlineScramble-LEDGER.md` — not yet written. Gate B1 may extract the register from this file. The ledger itself is written after the Demo and the `<stem>-test.dart` report.

## Appendix B. Orphan behavior register

| Behavior | Where | Serves requirement? | Disposition (add / remove / accept) | Decided by |
|---|---|---|---|---|
| | | | | |

---

*End of sample BRD. Organisation and people are fictional. Weather, duty, and handback figures are service policy for this sample, not a claim about aviation law.*
