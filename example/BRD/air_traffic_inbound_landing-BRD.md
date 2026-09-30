# Business Requirements Document (BRD)

## Air Traffic Inbound Landing Sequence

| Field | Value |
|---|---|
| Project name | Inbound Desk |
| Document title | Business Requirements — Air Traffic Control Inbound Landing Sequence |
| Version | 1.0 |
| Date | 2026-10-01 |
| Author | Approach Operations Programme Office |
| Reviewer(s) | Watch Manager (Approach), Tower Watch Manager, Safety Manager (ATS) |
| Approver(s) | Air Navigation Service Unit Manager, Head of Safety & Compliance, Security Manager (ATS) |
| Status | Approved |

**Revision history**

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | 2026-09-18 | Approach Ops Programme Office | First draft after summer holding-and-go-around review |
| 1.0 | 2026-10-01 | Approach Ops Programme Office | Approved after review with Approach, Tower, and ATS Safety |

---

## 2. Executive summary

Every day this unit sequences about 680 arriving flights onto two runways. An arrival is not a dot on one screen: it is a place in a landing order, a hold when the order is full, a wake-category gap, a declared priority, and a runway that can close under the weather. When two heavies sit too close in the order, a stack ages past the fuel the crew planned, or a priority flight is still number twelve, the first people who usually feel it are the executive controller on the frequency and the airline operations desk after a go-around. Today the watch manager builds that picture from the surveillance display, a paper strip board, and a phone to tower. We need a simple tool that watches the inbound order in real time, flags a sequence before it becomes a go-around or a fuel emergency conversation, protects flights we must never bury in the stack without a watch-manager acknowledgement, and gives the watch manager one view of what is happening right now plus an audit trail ATS Safety and the CAA can read but not change. This document sets out what that tool must do, for whom, and how we will know it is working.

This tool does **not** clear an aircraft to land, issue a heading, or replace the licensed controller. Every clearance stays on the operational voice circuit and the certified surveillance display.

---

## 3. Business context

### 3.1 Background
The unit provides approach radar and tower for one major civil aerodrome. Arrivals come from four standard routes into two holding stacks and then onto one active landing runway (the second runway is used for departure in the usual mode). Company and unit practice treats **a pair in the landing order whose planned time-over-threshold gap is below the unit’s published spacing for that wake pair**, or **a flight in the stack for more than 12 minutes without an assigned number in the next twenty landings**, or **a declared emergency / medical / minimum-fuel flight that is not in the first four of the order**, as at risk. A runway inspection, a blockage, or low-visibility procedures that close the landing runway must freeze new “next to land” flags until tower acknowledges the runway is again available. A go-around is a safety event until the watch manager records the reason and the new place in the order.

### 3.2 Problem statement
Right now the inbound order lives on three surfaces: the surveillance display each controller already uses to separate traffic, the electronic or paper strips, and tower’s runway picture on another frequency. The watch manager learns a stack is ageing when a crew reports minimum fuel, or when tower calls a go-around the approach sector did not expect. Priority flights are sometimes left mid-sequence because the only “list” is in one controller’s head during a handover. We estimate that around 1 in 70 arrivals last summer flew an extra hold or a go-around for a reason that would have been visible 8 minutes earlier if order, stack time, wake pair, and declared priority had sat on one supervisor screen. Average time from “spacing looking short” to “watch manager looking at the same pair” is 3 minutes, against a 30-second target. After two go-arounds in one weather band, the CAA asked who changed the order and why; the unit reconstructed it from recordings and memory.

### 3.3 Business drivers
- **Separation and spacing.** The licensed controller remains responsible for separation. The desk still needs one shared order so a short wake gap is seen before it becomes a go-around.
- **Fuel and passenger welfare.** Long unplanned holds turn into diversions and into minimum-fuel calls that compress the whole sequence.
- **Regulatory pressure.** UK CAA ATS oversight expects a reconstructable picture of who was number one to land, who was in the stack, and who authorised a priority change. Unit investigation files are still assembled after the fact.
- **Security of the service.** The landing order and the identity of priority flights are operationally sensitive. The tool must not be reachable from public networks and must not publish live callsigns to anyone outside the unit role model.
- **Staffing pressure.** A peak bank has one watch manager covering approach and a liaison line to tower. They need one extra picture, not another control position.

### 3.4 Alignment with strategy
The unit’s 2026–2029 ATS plan names “shared inbound picture” as a safety-and-resilience pillar. This project is a first step. It does not replace the certified surveillance system, the voice system, or the aerodrome lighting and runway-incursion tools.

---

## 4. Scope

### 4.1 In scope
- Real-time monitoring of every inbound flight from first identification on the approach sector to landing roll or missed-approach rejoin.
- A single watch-manager view of landing order, stack time, planned threshold gap, declared priority, and runway-available state.
- Automatic alerts when a pair, a stack, or a priority flight crosses the at-risk rule, or when the landing runway is marked unavailable.
- A priority register (emergency, medical, minimum fuel already declared on frequency, and the unit’s standing official-flight list) that the watch manager maintains and that order changes must honour.
- A record of every alert, every order change, every go-around, every diversion recommendation conversation, and every acknowledgement, in an append-only log.
- A daily inbound-safety summary for ATS Safety and the unit manager.

### 4.2 Out of scope
- Issuing clearances, headings, levels, or landing permissions. Controllers do that on the operational position.
- Replacing radar / surveillance, voice recording, or electronic strips.
- Departure sequence and ground movement (a later phase).
- Other aerodromes in the FIR in this phase.
- Passenger-facing delay boards and airline apps.
- Military intercept, air-defence identification, or restricted-area policing. Those remain with the published civil–military arrangements, not this desk tool.
- Automatic re-ordering of the landing list. The watch manager and the executive controller still decide.

### 4.3 Assumptions
- The existing flight-data / surveillance tracker can provide identity, wake category, and an estimated time at the final-approach fix at least every 5 seconds for every correlated inbound.
- Tower can provide a runway-available / inspection / blockage flag within 10 seconds of the local decision.
- Declared emergency, medical, or minimum-fuel status is entered by the controller or assistant from what was said on frequency — the tool does not infer distress from radar alone.
- Watch managers will use the tool on the existing supervisor workstation inside the ops room.
- Staff identity comes from the existing unit single sign-on and watch roster.

### 4.4 Constraints
- No new radar head or radio in this phase.
- Must be usable on the watch before the 2027 summer schedule.
- Must use existing unit roles. No shared generic login on this screen.
- Must not send an instruction to an aircraft, a pilot app, or a datalink. Watch and record only.
- Must not store passenger names, passport numbers, or cargo manifests. Flight identity is callsign, wake category, and operator code.
- If the tool fails, the certified surveillance display and voice circuit remain the only control path. The tool must fail silent, not fail noisy.

### 4.5 Dependencies
- Tracker / flight-data feed (ATS engineering).
- Runway-state flag (Tower).
- Standing official-flight list without personal names (Unit management).
- CAA investigation column agreement (ATS Safety).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
|---|---|---|---|---|
| Sponsor | ANS Unit Manager | Safety, delays, oversight findings | H | Monthly steering |
| Primary user | Approach watch managers | One order, earlier flag | H | Weekly workshops |
| Primary user | Tower watch managers | Runway-available truth | H | Weekly workshops |
| Reviewer | ATS Safety | Reconstructable go-around file | M | Sign-off before go-live |
| Reviewer | Security Manager (ATS) | No public leak of live order | M | Sign-off before go-live |
| Regulator | UK CAA ATS inspectorate | Oversight sample | L | Quarterly update |

---

## 6. Users and personas

### 6.1 Approach Watch Manager — Chris
- **Role:** Watch manager for approach during the evening bank.
- **Context:** Stands behind two executive controllers. Headset monitor, phone to tower, weather sheet.
- **Goal:** Know within 30 seconds which pair is short on spacing, which stack is ageing, and whether a declared priority flight is still buried.
- **Pain today:** Builds the order by listening in and reading strips. Misses a wake pair when both sectors talk at once.
- **Success looks like:** One screen shows the next twenty to land, stack minutes, short pairs, and priority flags.

### 6.2 Tower Watch Manager — Pat
- **Role:** Tower watch manager, same bank.
- **Context:** Runway, lighting, inspections, the occasional blockage.
- **Goal:** The inbound tool must freeze “next to land” the moment the runway is not available, so approach does not keep offering number one.
- **Pain today:** A phone call that arrives after approach has already turned someone onto final.
- **Success looks like:** Runway-unavailable is a hard flag on the same order Chris sees.

### 6.3 ATS Safety Investigator — Jordan
- **Role:** Builds the file after a go-around cluster or a CAA request.
- **Context:** Office the next morning. Needs who was number one, who changed the order, who acknowledged the priority.
- **Goal:** A pack with no passenger names and no deleted rows.
- **Pain today:** Voice tapes plus memory.
- **Success looks like:** Opens the log, exports, files. Cannot delete a row.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-01 | The system shall show, in real time, every correlated inbound: callsign, wake category, stack or downwind or final, estimated time at the final-approach fix, place in the landing order. | Must | Core purpose of the supervisor picture. |
| FR-02 | The system shall calculate planned time-over-threshold gap for each consecutive pair in the order, using the unit’s published spacing table for that wake pair. | Must | Shared spacing picture. |
| FR-03 | The system shall flag a pair as “at risk” when the planned gap is below the published spacing for that wake pair. | Must | Consistent rule across watches. |
| FR-04 | The system shall flag a flight as “at risk” when stack time exceeds 12 minutes and the flight is not in the next twenty of the order. | Must | Ageing hold. |
| FR-05 | The system shall flag the order as “blocked” when tower marks the landing runway unavailable. | Must | Do not keep selling number one. |
| FR-06 | The system shall flag a declared priority flight as “buried” when it is not in the first four of the order. | Must | Emergency / medical / minimum fuel / standing official list. |
| FR-07 | The watch manager shall see all at-risk pairs, ageing stacks, buried priority flights, and runway-blocked state on one screen. | Must | One view. |
| FR-08 | Each alert shall name the flights, the gap or stack minutes, the runway state, and whether a priority flag is set. | Must | Enough to talk to the executive controller. |
| FR-09 | The watch manager shall acknowledge with inspect-order, offer-priority, coordinate-tower, record-go-around, record-diversion-talk, or hold-order. | Must | Audit trail. The acknowledgement is not a clearance. |
| FR-10 | The watch manager shall add or remove a flight from the priority register only after the state has been declared on frequency or appears on the standing official list. | Must | Live policy, no silent inference. |
| FR-11 | The system shall not raise a second at-risk alert for the same pair and same cause until the first is acknowledged or closed. | Must | Fatigue. |
| FR-12 | A go-around shall open an incident and shall not drop the flight from the picture until a new place in the order is recorded. | Must | Missed approach stays visible. |
| FR-13 | Daily inbound-safety summary for ATS Safety. | Must | Reporting. |
| FR-14 | Notes shall not contain passenger names, political commentary, or medical details beyond “medical priority declared”. | Must | Privacy and professionalism. |
| FR-15 | Escalate when an at-risk pair or buried-priority alert is unacknowledged for 60 seconds. | Must | Bank pace. |
| FR-16 | The system shall refuse to mark a landing runway “available” unless tower has acknowledged that state. Approach cannot self-clear the runway flag. | Must | Two-unit truth. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | Capture for every tick: callsign, wake category, state (stack / downwind / final / land / go-around), estimate at final-approach fix, order number, runway identifier. | Must | Minimum dataset. |
| DR-02 | Capture for every incident: start, end, flights, gap or stack minutes, action, who acknowledged. | Must | File. |
| DR-03 | Retain incidents for 5 years. | Must | ATS investigation and CAA sample. |
| DR-04 | Retain high-rate order snapshots for 14 days. | Must | Watch reconstruction. |
| DR-05 | Reject a tick with a missing callsign or runway identifier. | Must | Data quality. |
| DR-06 | Do not persist passenger names, seat counts as personal lists, or cargo contents. | Must | Need-to-know. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | A declared emergency, medical, or minimum-fuel flight shall not sit outside the first four of the order without watch-manager acknowledgement. | Unit MATS Part 2 / safety | Must |
| BR-02 | This tool shall never issue or simulate a clearance. | Licensing | Must |
| BR-03 | No new alert for the same pair and cause while the incident is open. | Practice | Must |
| BR-04 | ATS Safety and CAA views are read-only and cannot delete a row. | Regulatory | Must |
| BR-05 | Approach shall not mark the landing runway available. Only tower’s acknowledgement clears the blocked flag. | Unit agreement | Must |
| BR-06 | Live order and callsigns shall not leave the unit role model or the unit network. | Security | Must |
| BR-07 | A flight on the standing official-priority list is treated as priority only while that list says so; the tool does not invent new official flights. | Security / protocol | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|---|
| AR-01 | Daily summary: arrivals, at-risk pairs, stack-time flags, buried-priority flags, go-arounds, runway-blocked minutes, median time to acknowledge. | ATS Safety, unit manager | Daily | 5 years |
| AR-02 | Incident log with timings and acknowledgements. | Watch managers, Safety, CAA | On demand | 5 years |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | Screen updates within 2 seconds of a tracker sample. | 2 s |
| NFR-02 | Availability | 99.95% while the aerodrome is open for IFR arrivals. Failure must be obvious (dead screen), never a stale order presented as live. | 99.95% |
| NFR-03 | Capacity | 20,000 inbound samples per hour at peak. | Peak hour |
| NFR-04 | Security | Only “Approach WM”, “Tower WM”, or “ATS Safety” roles see live callsigns. Safety is read-only plus register admin for the standing official list. | Role-based |
| NFR-05 | Security | No path from public internet, airline portals, or passenger apps. No datalink uplink. | Air-gapped from public |
| NFR-06 | Auditability | Every acknowledgement records who, when, what. | Full trace |
| NFR-07 | Usability | Watch manager answers “who is number one, and is any pair short?” in under 5 seconds. | ≤5 s |
| NFR-08 | Compliance | Supports UK ATS record-keeping and UK GDPR. | Full |
| NFR-09 | Recoverability | If the tool dies, controllers continue on certified displays with no extra alert noise. Restore the supervisor view within 10 minutes; log intact. | Fail silent; ≤10 min |

---

## 9. User journeys

### 9.1 Journey: Short wake pair on the evening bank
- **Trigger:** A heavy is number two behind another heavy with a planned gap below the unit’s published spacing.
- **Steps:** System flags the pair at risk → Chris sees both callsigns and the gap → speaks to the executive controller (who still owns the frequency) → order is stretched or a hold is used → Chris acknowledges inspect-order.
- **Outcome:** Gap restored before final. The tool did not talk to the aircraft.
- **Failure path:** Unacknowledged at 60 seconds, escalate to the unit duty supervisor.

### 9.2 Journey: Declared minimum fuel still number eleven
- **Trigger:** Crew declares minimum fuel on frequency. Assistant marks the flight priority.
- **Steps:** Buried-priority flag if the flight is not in the first four → Chris coordinates with the executive controller and tower → new place in the order is recorded → acknowledgement offer-priority.
- **Outcome:** Priority is visible to both watches. Not a silent jump with no name on the log.
- **Failure path:** If the mark was a mis-hear, Chris removes the priority only after confirming on frequency.

### 9.3 Journey: Runway inspection
- **Trigger:** Tower closes the landing runway for a 4-minute inspection.
- **Steps:** Runway-blocked flag → “next to land” freezes on the inbound picture → approach stops offering number one against a closed runway → tower acknowledges available → flag clears.
- **Outcome:** Approach cannot self-clear the runway state.
- **Failure path:** If the flag fails, tower phone remains the fallback; the tool must show stale-or-dead, not “runway free”.

### 9.4 Journey: Go-around cluster file
- **Trigger:** Two go-arounds in twenty minutes in weather.
- **Steps:** Each go-around opens an incident and keeps the flight on the picture until a new order place is recorded → next morning Jordan exports the log without passenger names.
- **Outcome:** File in 15 minutes. Jordan cannot delete a row.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | Every correlated inbound visible within 2 seconds of the tracker sample. | Live bank test on a recorded feed in the ops room |
| AC-02 | At-risk pair flags match the unit published spacing table on 30 scripted pairs. | Scripted test |
| AC-03 | Buried-priority flag fires when a declared priority flight sits outside the first four. | Desk test |
| AC-04 | Approach cannot clear a runway-blocked flag; only tower acknowledgement does. | Two-position test |
| AC-05 | Tool has no control to send a voice or datalink instruction. | Engineering and Safety test |
| AC-06 | ATS Safety role cannot delete a row. Live callsigns are invisible outside unit roles. | Role and network test |
| AC-07 | Killing the tool leaves certified displays and voice untouched (fail silent). | Planned fail-over |
| AC-08 | Daily summary matches strip-board counts for one full watch and has no passenger names. | Side-by-side |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Staff treat the tool as a second control position. | M | H | Training and a written rule: no clearance from this screen. AC-05. |
| R-02 | Tracker estimates lag in weather. | M | H | Trial on a recorded poor-weather watch before live use. Stale-data banner. |
| R-03 | Priority mark entered in error. | M | H | Only from a frequency declaration or the standing list; easy remove after confirm. |
| R-04 | Live order leaks to an airline portal. | L | H | No external interface in phase 1. SIRO sign-off. |
| R-05 | Alert flood when the whole bank is tight. | M | M | One open incident per pair; watch manager can silence repeats until close. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| Time from short-gap appearing to watch manager and executive looking at the same pair | 3 min | 30 s | 3 months |
| Extra holds or go-arounds later judged visible on a shared order 8 minutes earlier | 1 in 70 arrivals | 1 in 150 | 6 months |
| Priority flights left outside the first four with no acknowledgement | Occurs | Zero | Every month |
| Safety pack time after a go-around cluster | Half a day | 15 min | 1 month |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| At risk | Pair, stack, or priority flight that has crossed a unit rule on this desk. |
| Buried priority | Declared emergency, medical, minimum fuel, or standing official flight not in the first four of the order. |
| Clearance | Instruction to an aircraft. This tool never issues one. |
| Executive controller | Licensed controller on the frequency. |
| Final-approach fix | The published point used here only as a shared time reference for the order. |
| Go-around | Missed approach; flight stays in the picture until re-sequenced. |
| Landing order | Supervisor list of who is planned to land next. Not a clearance. |
| Published spacing | The unit’s already-approved wake and runway spacing table. This project does not invent new minima. |
| Stack | Holding pattern used when the order is full. |
| Surveillance display | Certified radar / tracker screen used to separate traffic. |
| Watch manager | Supervisor for that watch, not a second executive controller. |
| Wake category | Aircraft grouping the unit already uses for spacing. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | Is the standing official-priority list held by unit management already free of personal names? | Security Manager (ATS) | 2026-10-20 | Open |
| Q-02 | Which of the two runways can be landing runway in mixed mode, and does tower’s flag name the runway? | Tower WM | 2026-10-15 | Open |
| Q-03 | What exact banner wording is approved when the tool is dead so nobody treats a frozen order as live? | ATS Safety | 2026-10-22 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (ANS Unit Manager) | `[name]` | | |
| Product owner (Watch Manager Approach) | `[name]` | | |
| Technical lead (ATS engineering) | `[name]` | | |
| ATS Safety | `[name]` | | |
| Security Manager (ATS) | `[name]` | | |

---

*End of document.*
