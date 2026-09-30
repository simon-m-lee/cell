# Business Requirements Document (BRD)

## Air Traffic Control Tower Runway Desk

| Field | Value |
|---|---|
| Project name | Tower Desk |
| Document title | Business Requirements — Air Traffic Control Tower Runway and Crossing Picture |
| Version | 1.0 |
| Date | 2026-10-01 |
| Author | Tower Operations Programme Office |
| Reviewer(s) | Tower Watch Manager, Ground Watch Manager, Safety Manager (ATS) |
| Approver(s) | Air Navigation Service Unit Manager, Head of Safety & Compliance, Security Manager (ATS) |
| Status | Approved |

**Revision history**

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | 2026-09-20 | Tower Ops Programme Office | First draft after runway-occupancy and crossing review |
| 1.0 | 2026-10-01 | Tower Ops Programme Office | Approved after review with Tower, Ground, and ATS Safety |

---

## 2. Executive summary

Every day this tower handles about 680 landings and 680 departures on two runways, plus the vehicles and towed aircraft that have to cross or inspect those runways. A tower watch is not only “cleared to land”: it is who is on the runway now, who is lined up, who is on a two-mile final, which crossing is still open, and whether an inspection party is still on the pavement. When those four facts live in three heads, the first warning is often a go-around or a rejected take-off. Today the watch manager builds the picture from the window, the stop-bar panel, ground’s frequency, and a phone to approach. We need a simple tool that watches runway occupancy in real time, flags a conflict before it becomes a go-around or an incursion report, protects parties we must never leave on a live runway without a named acknowledgement, and gives the tower watch manager one view of what is happening right now plus an audit trail ATS Safety and the CAA can read but not change. This document sets out what that tool must do, for whom, and how we will know it is working.

This tool does **not** clear an aircraft to land or take off, switch a stop bar, or replace the licensed controller. Every clearance stays on the operational voice circuit and the certified aerodrome display. It is the companion desk to `air_traffic_inbound_landing` (approach order). Approach consumes the runway-available flag this desk owns.

---

## 3. Business context

### 3.1 Background
The unit provides aerodrome control (tower and ground) for one major civil aerodrome. In the usual mode one runway is landing, the other is departing; mixed mode is used in declared weather or inspection periods. Unit practice treats **an arrival inside the unit’s published short-final distance with the landing runway still occupied by an aircraft, a vehicle, or an inspection party**, or **a departure lined up with a crossing still showing “not vacated”**, or **a runway that has been in “occupied” for more than 90 seconds with no landing roll or take-off roll started**, as at risk. A work party, bird-dispersal team, or inspection vehicle on the runway is a protected occupant: the runway shall not be offered as available until that party is acknowledged vacated by tower. A go-around, a rejected take-off, or a stop-bar that does not match the occupancy picture is a safety event until the watch manager records why.

### 3.2 Problem statement
Right now runway truth lives on three surfaces: what the tower controller can see from the cab, what ground knows about crossings, and what approach believes about “runway free”. The watch manager learns a vehicle is still on the far end when an arrival is already on short final, or when ground calls that a crossing has not vacated. Line-up versus landing is coordinated by ear. We estimate that around 1 in 90 arrivals last summer flew a go-around, or a departure rejected, for a reason that would have been visible 20 seconds earlier if occupancy, lined-up state, short-final, and open crossings had sat on one supervisor screen. Average time from “runway still occupied” to “tower and ground looking at the same occupant” is 40 seconds, against a 10-second target. After two incursion-category events in one season, the CAA asked who was on the runway and who had acknowledged vacated; the unit reconstructed it from voice tapes and memory.

### 3.3 Business drivers
- **Runway safety.** The licensed controller remains responsible for every clearance. The desk still needs one shared occupancy picture so a short-final versus occupant clash is seen before it becomes a go-around.
- **Capacity.** False “runway free” calls waste slots; late “runway occupied” calls create go-arounds that recycle the inbound order.
- **Regulatory pressure.** UK CAA ATS and aerodrome oversight expect a reconstructable picture of occupancy, crossings, and who released the runway. Incursion files are still assembled after the fact.
- **Security of the manoeuvring area.** Who is allowed on a live runway is a controlled list. The tool must not be reachable from public networks and must not publish live occupancy to airline apps.
- **Staffing pressure.** A peak bank has one tower watch manager covering two runways and a liaison line to ground and approach. They need one extra picture, not another control position.

### 3.4 Alignment with strategy
The unit’s 2026–2029 ATS plan names “shared inbound picture” and “shared runway picture” as paired pillars. This project is the tower half. It does not replace the certified surface-movement display, stop bars, voice, or lighting.

---

## 4. Scope

### 4.1 In scope
- Real-time monitoring of each declared runway: occupied / vacant, occupant type (landing roll, lined up, vacated crossing, inspection party, vehicle, blockage).
- A single tower watch-manager view of short-final inbounds, lined-up departures, open crossings, inspection parties, and runway-available state.
- Automatic alerts when occupancy versus short-final or line-up versus crossing crosses the at-risk rule.
- A protected-occupant register (inspection, bird-dispersal, works, rescue-and-fire vehicles already on unit task) that the watch manager maintains and that “runway available” must honour.
- Publication of the runway-available / blocked flag that the inbound-approach desk already assumes.
- A record of every alert, every occupancy change, every go-around seen from tower, every rejected take-off, and every acknowledgement, in an append-only log.
- A daily tower-safety summary for ATS Safety and the unit manager.

### 4.2 Out of scope
- Issuing landing, take-off, line-up, or crossing clearances. Controllers do that on the operational position.
- Replacing surface-movement radar, stop bars, voice recording, or electronic strips.
- Full taxiway routing and stand allocation (ground planning remains on the existing ground position).
- Approach landing *order* (covered by `air_traffic_inbound_landing-BRD.md`).
- Other aerodromes in the FIR in this phase.
- Passenger-facing boards and airline apps.
- Military intercept or air-defence tasks.
- Automatic switching of stop bars or runway lights.

### 4.3 Assumptions
- The existing surface-movement / aerodrome display can provide occupancy and identity for correlated aircraft and known vehicles at least every 2 seconds.
- Approach can provide “inside short-final distance” for the next landing without this tool issuing any instruction.
- Ground can mark a crossing as entered / vacated within 5 seconds of the local decision.
- Inspection and works parties already radio tower before entering a runway; the tool records that state, it does not authorise entry.
- Watch managers will use the tool on the existing cab supervisor workstation.
- Staff identity comes from the existing unit single sign-on and watch roster.

### 4.4 Constraints
- No new radar head, camera system, or radio in this phase.
- Must be usable on the watch before the 2027 summer schedule.
- Must use existing unit roles. No shared generic login.
- Must not send an instruction to an aircraft, a vehicle, a pilot app, or a datalink. Must not command a stop bar.
- Must not store passenger names or crew personal details. Identity is callsign or vehicle / party callsign.
- If the tool fails, the window, certified displays, stop bars, and voice remain the only control path. The tool must fail silent, not fail noisy.

### 4.5 Dependencies
- Surface-movement / aerodrome-display feed (ATS engineering).
- Short-final flag from the inbound tracker (shared with the approach desk).
- Crossing entered / vacated (Ground).
- Protected-occupant task list (Airfield operations).
- CAA investigation column agreement (ATS Safety).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
|---|---|---|---|---|
| Sponsor | ANS Unit Manager | Runway safety, delays, oversight | H | Monthly steering |
| Primary user | Tower watch managers | One occupancy picture | H | Weekly workshops |
| Primary user | Ground watch managers | Crossing vacated truth | H | Weekly workshops |
| Reviewer | Approach watch managers | Runway-available flag they already consume | M | Joint workshop |
| Reviewer | ATS Safety | Reconstructable incursion / go-around file | M | Sign-off before go-live |
| Reviewer | Security Manager (ATS) | No public leak of live occupancy | M | Sign-off before go-live |
| Regulator | UK CAA ATS / aerodrome inspectorate | Oversight sample | L | Quarterly update |

---

## 6. Users and personas

### 6.1 Tower Watch Manager — Pat
- **Role:** Tower watch manager, evening bank, two runways.
- **Context:** Cab. Window, lighting panel, monitor frequency, phone to ground and approach.
- **Goal:** Know within 10 seconds who is on the landing runway, who is on short final, who is lined up, and whether a crossing has vacated.
- **Pain today:** Hears “crossing still moving” after the arrival has been turned onto final.
- **Success looks like:** One screen shows occupancy, short-final, line-up, open crossings, and protected parties.

### 6.2 Ground Watch Manager — Alex
- **Role:** Ground watch manager, same bank.
- **Context:** Crossings, tows, works vehicles.
- **Goal:** Tower must not see a runway as free while a crossing Alex still marks “not vacated”.
- **Pain today:** A second call after the vehicle is already past the hold point — or still on it.
- **Success looks like:** Entered / vacated is the same flag Pat sees.

### 6.3 ATS Safety Investigator — Jordan
- **Role:** Builds the file after a go-around, rejected take-off, or incursion-category event.
- **Context:** Office the next morning.
- **Goal:** Who was on the runway, who acknowledged vacated, who had short-final. No passenger names. No deleted rows.
- **Pain today:** Voice tapes plus memory.
- **Success looks like:** Opens the log, exports, files.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-01 | The system shall show, in real time, each declared runway: vacant or occupied, occupant type, occupant identity, seconds occupied. | Must | Core purpose of the supervisor picture. |
| FR-02 | The system shall show the next landing inside the unit’s published short-final distance, and the next departure that is lined up, for each landing / departure runway. | Must | Pair the occupancy with the pressure on it. |
| FR-03 | The system shall flag a runway as “at risk” when an arrival is inside short-final distance and the landing runway is still occupied. | Must | Go-around precursor. |
| FR-04 | The system shall flag a runway as “at risk” when a departure is lined up and a crossing on that runway still shows not vacated. | Must | Take-off precursor. |
| FR-05 | The system shall flag a runway as “stale occupied” when occupied for more than 90 seconds with no landing roll or take-off roll started. | Must | Forgotten occupant or missed vacated call. |
| FR-06 | The system shall flag the runway as “blocked” while a protected occupant (inspection, works, bird-dispersal, rescue-and-fire on task) is present, and shall publish that blocked state to the inbound-approach desk. | Must | Shared runway-available truth. |
| FR-07 | The watch manager shall see all at-risk runways, protected occupants, open crossings, and short-final / lined-up pairs on one screen. | Must | One view. |
| FR-08 | Each alert shall name the runway, occupant, short-final or lined-up flight, crossing identity if any, and seconds occupied. | Must | Enough to talk to the executive controller. |
| FR-09 | The watch manager shall acknowledge with hold-landing-talk, hold-departure-talk, confirm-vacated, keep-blocked, record-go-around, record-rejected-take-off, or coordinate-ground. | Must | Audit trail. The acknowledgement is not a clearance. |
| FR-10 | Only tower may mark a runway available after a protected occupant. Ground marks crossings; it does not clear the runway-available flag. | Must | Two-position truth. |
| FR-11 | The system shall not raise a second at-risk alert for the same runway and same cause until the first is acknowledged or closed. | Must | Fatigue. |
| FR-12 | A go-around or rejected take-off seen from tower shall open an incident and keep the flight on the picture until occupancy is consistent again. | Must | Event stays visible. |
| FR-13 | Daily tower-safety summary for ATS Safety. | Must | Reporting. |
| FR-14 | Notes shall not contain passenger names or blame language. Occupant identity is callsign or vehicle / party callsign. | Must | Privacy and professionalism. |
| FR-15 | Escalate when an at-risk occupancy alert is unacknowledged for 15 seconds. | Must | Cab pace. |
| FR-16 | Approach shall not be able to clear this desk’s runway-blocked flag. | Must | Matches inbound BRD FR-16. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | Capture for every tick: runway ID, occupancy state, occupant type, occupant identity, short-final flight if any, lined-up flight if any, open crossing IDs. | Must | Minimum dataset. |
| DR-02 | Capture for every incident: start, end, runway, occupants, action, who acknowledged. | Must | File. |
| DR-03 | Retain incidents for 5 years. | Must | ATS investigation and CAA sample. |
| DR-04 | Retain high-rate occupancy snapshots for 14 days. | Must | Watch reconstruction. |
| DR-05 | Reject a tick with a missing runway identifier. | Must | Data quality. |
| DR-06 | Do not persist passenger names, crew personal lists, or vehicle driver home addresses. | Must | Need-to-know. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | A protected occupant shall keep the runway blocked until tower acknowledges vacated. | Unit MATS Part 2 / airfield | Must |
| BR-02 | This tool shall never issue or simulate a clearance, and shall never command a stop bar. | Licensing | Must |
| BR-03 | No new alert for the same runway and cause while the incident is open. | Practice | Must |
| BR-04 | ATS Safety and CAA views are read-only and cannot delete a row. | Regulatory | Must |
| BR-05 | Ground’s “not vacated” on a crossing shall prevent a clean “runway free for departure” picture. | Unit agreement | Must |
| BR-06 | Live occupancy and callsigns shall not leave the unit role model or the unit network. | Security | Must |
| BR-07 | Only parties on the current works / inspection / RFFS task list may be marked protected occupants. The tool does not invent a works party. | Security / airfield | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|---|
| AR-01 | Daily summary: movements, at-risk occupancy flags, stale-occupied flags, protected-occupant minutes, go-arounds, rejected take-offs, median time to acknowledge. | ATS Safety, unit manager | Daily | 5 years |
| AR-02 | Incident log with timings and acknowledgements. | Watch managers, Safety, CAA | On demand | 5 years |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | Screen updates within 1 second of a surface-movement sample. | 1 s |
| NFR-02 | Availability | 99.95% while the aerodrome is open. Failure must be obvious (dead screen), never a stale “runway free” presented as live. | 99.95% |
| NFR-03 | Capacity | 30,000 occupancy samples per hour at peak. | Peak hour |
| NFR-04 | Security | Only “Tower WM”, “Ground WM”, or “ATS Safety” roles see live occupancy. Safety is read-only plus register admin for the works list. | Role-based |
| NFR-05 | Security | No path from public internet, airline portals, or passenger apps. No datalink. No stop-bar command. | Air-gapped from public |
| NFR-06 | Auditability | Every acknowledgement records who, when, what. | Full trace |
| NFR-07 | Usability | Watch manager answers “is the landing runway empty, and is anyone on short final?” in under 5 seconds. | ≤5 s |
| NFR-08 | Compliance | Supports UK ATS and aerodrome record-keeping and UK GDPR. | Full |
| NFR-09 | Recoverability | If the tool dies, cab window, certified displays, stop bars, and voice continue with no extra alert noise. Restore the supervisor view within 10 minutes; log intact. | Fail silent; ≤10 min |

---

## 9. User journeys

### 9.1 Journey: Arrival on short final, crossing not vacated
- **Trigger:** Next landing is inside short-final distance. A follow-me crossing on the landing runway is still marked not vacated.
- **Steps:** System flags the runway at risk → Pat sees occupant + arrival → talks to the executive controller and to Alex (who still own the frequencies) → crossing holds or the arrival is sent around → Pat acknowledges hold-landing-talk or record-go-around.
- **Outcome:** Shared picture before the window alone has to save it. The tool did not talk to the aircraft.
- **Failure path:** Unacknowledged at 15 seconds, escalate to the unit duty supervisor.

### 9.2 Journey: Inspection party still on the pavement
- **Trigger:** Airfield inspection enters the departure runway.
- **Steps:** Protected occupant → runway blocked → inbound desk receives blocked → line-up is not pictured as “free to go” → party calls vacated → only Pat can acknowledge available.
- **Outcome:** Approach cannot self-clear the runway. Works party is named on the log.
- **Failure path:** If vacated is missed, stale-occupied fires at 90 seconds.

### 9.3 Journey: Lined up, crossing still moving
- **Trigger:** Departure lined up. Tow still showing not vacated on that runway.
- **Steps:** At-risk flag → Alex confirms the tow → Pat acknowledges hold-departure-talk → vacated → picture clears.
- **Outcome:** Rejected take-off avoided or, if it happens, recorded.

### 9.4 Journey: Morning Safety pack
- **Trigger:** Next morning after a go-around and a rejected take-off.
- **Steps:** Jordan exports the log without passenger names.
- **Outcome:** File in 15 minutes. Cannot delete a row.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | Occupancy visible within 1 second of the surface-movement sample. | Live bank test on a recorded feed in the cab |
| AC-02 | Short-final + occupied and lined-up + crossing-not-vacated flags match unit rules on 30 scripted cases. | Scripted test |
| AC-03 | Protected occupant keeps runway blocked until tower acknowledges vacated. | Desk test with airfield ops |
| AC-04 | Approach role cannot clear the blocked flag. | Two-unit test with the inbound desk |
| AC-05 | Tool has no control to send a voice instruction or move a stop bar. | Engineering and Safety test |
| AC-06 | ATS Safety role cannot delete a row. Live occupancy is invisible outside unit roles. | Role and network test |
| AC-07 | Killing the tool leaves window, certified displays, stop bars, and voice untouched (fail silent). Stale “runway free” is not shown. | Planned fail-over |
| AC-08 | Daily summary matches strip-board occupancy events for one full watch and has no passenger names. | Side-by-side |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Staff treat the tool as a second control position or as a stop-bar panel. | M | H | Training and written rule: no clearance, no lighting command. AC-05. |
| R-02 | Surface-movement identity lags in rain or at the far end. | M | H | Trial on a recorded poor-weather watch. Window remains primary. Stale-data banner. |
| R-03 | Ground and tower disagree on vacated. | M | H | Ground owns crossing vacated; tower owns runway available. Both visible. |
| R-04 | Live occupancy leaks to an airline portal. | L | H | No external interface in phase 1. SIRO sign-off. |
| R-05 | Alert flood in mixed mode. | M | M | One open incident per runway and cause. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| Time from occupied-versus-short-final appearing to tower and ground looking at the same occupant | 40 s | 10 s | 3 months |
| Go-arounds or rejected take-offs later judged visible on a shared occupancy picture 20 seconds earlier | 1 in 90 arrivals or departures | 1 in 200 | 6 months |
| Runway marked available while a protected occupant is still on the pavement | Occurs | Zero | Every month |
| Safety pack time after an incursion-category or go-around file | Half a day | 15 min | 1 month |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| At risk | Occupancy versus short-final, or line-up versus an open crossing, that has crossed a unit rule on this desk. |
| Blocked | Runway not available because a protected occupant is present, or tower has declared it so. |
| Clearance | Instruction to an aircraft or vehicle. This tool never issues one. |
| Crossing | Taxi or tow that must enter or cross a declared runway. |
| Ground | Aerodrome ground control position. |
| Lined up | Departure in position on the runway, not yet rolling. |
| Occupied | Aircraft, vehicle, or party on the declared runway. |
| Protected occupant | Inspection, works, bird-dispersal, or rescue-and-fire party on an agreed task. |
| Short final | Inside the unit’s already-published distance from threshold. This project does not invent a new minimum. |
| Stop bar | Lighted hold point. This tool does not switch it. |
| Tower | Aerodrome control position for runway and circuit. |
| Vacated | Occupant reported and accepted as clear of the runway or crossing. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | What exact distance is already published as “short final” for each landing runway in this mode? | Tower WM / ATS Safety | 2026-10-15 | Open |
| Q-02 | Does mixed-mode use the same protected-occupant list as segregated mode? | Airfield operations | 2026-10-20 | Open |
| Q-03 | What banner wording is approved when the tool is dead so nobody treats a frozen “runway free” as live? | ATS Safety | 2026-10-22 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (ANS Unit Manager) | `[name]` | | |
| Product owner (Tower Watch Manager) | `[name]` | | |
| Technical lead (ATS engineering) | `[name]` | | |
| ATS Safety | `[name]` | | |
| Security Manager (ATS) | `[name]` | | |

---

*End of document.*
