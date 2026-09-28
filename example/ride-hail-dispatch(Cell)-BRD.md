# Business Requirements Document (BRD)

## Ride-Hail Dispatch

| Field | Value |
|---|---|
| Project name | Ride-Hail Dispatch Watch |
| Document title | Business Requirements — Ride-Hail Dispatch |
| Version | 1.0 |
| Date | 2026-09-27 |
| Author | Mobility Operations Programme Office |
| Reviewer(s) | Head of City Operations, Driver Supply Manager, City Transport Authority Liaison |
| Approver(s) | Chief Operating Officer, Head of Safety & Compliance |
| Status | Approved |

**Revision history**

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | 2026-09-20 | Mobility Ops Programme Office | First draft |
| 1.0 | 2026-09-27 | Mobility Ops Programme Office | Approved after review with City Ops and Driver Supply |

---

## 2. Executive summary

Every day, tens of thousands of riders open our app, drop a pin, and wait for a driver. When supply is tight — a stadium event lets out, a rainstorm hits, a train line closes — the wait grows, riders cancel, and drivers get stuck in a queue with no work. Our dispatch today is a black box to the operations team: a rider ping goes in, a match comes out, but nobody can see why a match was made, why a zone was closed, or how many drivers were actually idle at the moment a rider gave up. We need a simple tool that watches rider demand and driver supply in real time, decides when to dispatch, when to hold a surge banner, and when to leave a zone idle, and records every match and every acceptance in a ledger the city transport authority can audit without being able to change a row. This document sets out what that tool must do, for whom, and how we will know it is working.

---

## 3. Business context

### 3.1 Background
Our platform handles around 80,000 ride requests per day across one metro area, divided into 12 dispatch zones. Each request carries a rider ID, a pickup zone, a latitude and longitude, a rider wait time in seconds, a nearby-driver count, and a current surge multiplier. Dispatch outcomes fall into three categories: **dispatch** (a driver is matched immediately), **surge** (the rider is shown a surge banner and waits), and **idle** (no driver is available in the zone; the rider is held or told to wait). Surge pricing is regulated by the city; every surge event must be justified by the supply-demand picture at the time it was raised.

### 3.2 Problem statement
Right now, we have no single view of dispatch. The rider app, the driver app, and the dispatch engine each report their own status to their own dashboard. The city transport authority asks us quarterly for evidence that surge pricing was justified; we assemble that evidence by hand from three systems, and we cannot prove the ledger was not changed after the fact. Operations learns about a supply shortage when riders start cancelling, or when the city calls. We estimate that around 1 in 60 dispatch attempts is delayed by a zone closure that should have been lifted, and that the average time from a supply shortage to an operations response is 12 minutes — well short of our 5-minute target, but with no audit trail to prove it.

### 3.3 Business drivers
- **Rider experience.** A delayed match is one of the top three reasons riders churn.
- **Driver experience.** Idle drivers in a zone with no requests is one of the top three reasons drivers churn.
- **Regulatory pressure.** The city transport authority requires all ride-hailing operators to demonstrate real-time dispatch decisions and to retain an unmodifiable ledger of surge events from 2027.
- **Operational pressure.** Our city operations team is already stretched. They need one view, not three, and they need the audit trail to be a by-product of the decision.

### 3.4 Alignment with strategy
Our 2025–2028 mobility strategy names "real-time operational visibility" as one of four pillars. This project delivers a first, concrete step in that direction, without replacing the dispatch engine or the driver app.

---

## 4. Scope

### 4.1 In scope
- Real-time monitoring of rider demand and driver supply across all 12 dispatch zones.
- A single city-operations view of current dispatch activity across all zones.
- Automatic decisions: dispatch a rider to a driver, hold a surge banner, or leave the zone idle.
- A no-go register of closed stands and stadium-curb zones that operations maintains and that the decision logic honours.
- A record of every dispatch, every surge, every acceptance, and every completion, in an append-only ledger.
- An outbound push to the driver app, with retry-once semantics.
- A daily dispatch and surge report for the city transport authority liaison.

### 4.2 Out of scope
- Pricing algorithm. Surge multipliers are supplied by the pricing team; we decide when to display them, not what they are.
- Driver onboarding and background checks. Handled by the driver supply team.
- Payments and receipts. Handled by the payments team.
- Multi-city rollout. Phase 1 is one metro area.
- Rider-facing app UI. The dispatch decision is ours; the display is the app team's.
- Autonomous vehicle dispatch. Not in scope for this phase.

### 4.3 Assumptions
- The rider app provides a ping stream with pickup, wait, and surge at least every 2 seconds.
- The driver app provides a location and status stream at least every 5 seconds.
- Each zone's no-go status is agreed with city operations and reviewed weekly.
- The driver app acknowledges a push within 3 seconds.
- The idle-driver count is seeded once per zone at the start of the trading day and updated throughout.

### 4.4 Constraints
- No new hardware. This runs on the existing dispatch infrastructure.
- Must go live before the 2027 summer events season (May).
- Must use the existing single sign-on for operations staff.
- Must not disturb the live rider or driver apps during rollout.
- Budget capped at the amount approved in the Q3 board paper.

### 4.5 Dependencies
- Rider app must expose the ping stream (Rider Engineering team).
- Driver app must expose the location and status stream (Driver Engineering team).
- City transport authority must agree the daily report format (Regulatory Affairs team).
- Pricing team must supply the current surge multiplier (Pricing team, already available).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
|---|---|---|---|---|
| Sponsor | Chief Operating Officer | Rider and driver retention, regulatory readiness, cost | H | Monthly steering |
| Primary user | City Operations Managers (12 zones) | One clear view, fast response, clean audit | H | Weekly workshops |
| Primary user | Driver Supply Leads (12 zones) | Fewer idle drivers, faster matches | H | Weekly workshops |
| Reviewer | Regulatory Affairs Manager | Reporting accuracy, audit trail | M | Bi-weekly review |
| Reviewer | Safety & Compliance | No impact on driver or rider safety | M | Sign-off before go-live |
| Regulator | City Transport Authority | Real-time dispatch and surge reporting from 2027 | L | Quarterly update |

---

## 6. Users and personas

### 6.1 City Operations Manager — Aisha
- **Role:** Shift city operations manager, Downtown zone.
- **Context:** In the operations centre, watching the dispatch stream in real time, from 06:00 to 18:00. Handles 40–80 dispatch alerts a shift.
- **Goal:** Know within a minute when a supply shortage starts, and know exactly which zones are closed, which drivers are idle, and which surges are live.
- **Pain today:** Learns about a shortage when riders cancel. Has to check three dashboards to understand a single incident.
- **Success looks like:** One screen shows the whole city's dispatch activity, with red flags for shortages and a green register for open zones.

### 6.2 Driver Supply Lead — Diego
- **Role:** Driver supply lead, Stadium zone.
- **Context:** In the field, at events, on the phone with drivers. Handles 5–15 supply events a shift during the events season.
- **Goal:** Know where the idle drivers are, how many riders are waiting, and whether a surge should be raised to attract more drivers.
- **Pain today:** Walks to a stand to see what is happening. Wastes 5–10 minutes per event.
- **Success looks like:** An alert tells him the zone, the number of idle drivers, the number of waiting riders, and the surge in force.

### 6.3 Regulatory Affairs Officer — Chen
- **Role:** Daily contact for the city transport authority.
- **Context:** In an office, reviews yesterday's dispatch and surge events every morning.
- **Goal:** A one-page report showing yesterday's dispatch activity and surge events per zone, so he can answer city queries without digging.
- **Pain today:** Builds the report by hand from three systems every morning. Takes 90 minutes and often misses a surge.
- **Success looks like:** Opens a report, sends it, done, with an unmodifiable audit trail behind it.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-01 | The system shall show, in real time, the rider demand and driver supply for every dispatch zone. | Must | Core purpose of the tool. |
| FR-02 | The system shall dispatch a rider to a driver when the zone is open, the rider has waited, and at least one driver is nearby. | Must | Primary dispatch rule. |
| FR-03 | The system shall hold a surge banner when the zone is open and the surge multiplier is above 1.5, and the nearby driver count is zero. | Must | Surge policy. |
| FR-04 | The system shall leave the zone idle when the zone is on the no-go register. | Must | Operations policy. |
| FR-05 | The city operations manager shall be able to add or remove a zone from the no-go register while the system is running. | Must | Live policy. |
| FR-06 | The system shall not dispatch the same rider twice in a row for the same zone. | Must | Prevent double dispatch. |
| FR-07 | The driver shall be able to accept a dispatch and record the acceptance. | Must | Audit trail of driver response. |
| FR-08 | The system shall raise an alert when a rider has been waiting more than 3 minutes without a dispatch. | Should | Escalation. |
| FR-09 | The city operations manager shall be able to see all open surges across all zones. | Should | Cross-zone awareness. |
| FR-10 | The system shall produce a daily dispatch and surge report for the city transport authority. | Must | Regulatory requirement. |
| FR-11 | The city operations manager shall be able to add a free-text note to any surge. | Should | Context for later review. |
| FR-12 | The system shall automatically return a driver to the idle pool when the trip is complete. | Must | Return driver to supply. |
| FR-13 | The system shall retry a driver push once if the driver app does not acknowledge. | Must | Recover transient push failures. |
| FR-14 | The system shall reject a dispatch command that would take the idle-driver count below zero. | Must | Driver supply invariant. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | The system shall capture for every tick: rider ID, zone, latitude, longitude, wait time, nearby-driver count, surge multiplier. | Must | Minimum dataset for dispatch. |
| DR-02 | The system shall capture for every dispatch: driver ID, rider ID, zone, match time, and the driver who accepted. | Must | Audit trail. |
| DR-03 | The system shall capture for every surge: zone, multiplier, start time, end time, and the operations manager who acknowledged. | Must | Regulatory requirement. |
| DR-04 | The system shall retain the trip ledger for 24 months. | Must | City transport authority requirement. |
| DR-05 | The system shall retain the idle-driver counts for 7 days. | Must | Enough for a full shift review. |
| DR-06 | The system shall reject tick records with a missing rider ID or a missing zone. | Must | Data quality at the source. |
| DR-07 | The system shall reject a latitude outside −90…90 or a longitude outside −180…180. | Must | Data quality at the source. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | A zone on the no-go register shall never be dispatched into, regardless of rider demand, without explicit city-operations authorisation. | Operations policy | Must |
| BR-02 | No dispatch may be raised for a rider who has already been dispatched in the same zone within the same minute. | Operational practice | Must |
| BR-03 | Every surge must be acknowledged or dismissed within 5 minutes. | Service level | Must |
| BR-04 | The city transport authority's view of the trip ledger shall be read-only and shall not permit deletion of any row. | Regulatory | Must |
| BR-05 | The idle-driver count shall not be driven below zero under any circumstances. | Driver supply policy | Must |
| BR-06 | A surge multiplier displayed to riders shall be justified by the supply-demand picture at the time it was raised. | City regulation | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|---|
| AR-01 | The daily dispatch report shall show, per zone: requests, dispatches, surges, average rider wait, and average driver idle time. | Regulatory Affairs, City Operations | Daily | 24 months |
| AR-02 | The trip ledger view shall show every dispatch, surge, acceptance, and completion with timestamps, in the order written. | City Operations, Regulatory Affairs, City Transport Authority | On demand | 24 months |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | The system shall dispatch within 5 seconds of receiving a rider ping. | 5 s |
| NFR-02 | Availability | The system shall be available 99.9% of the time between 04:00 and 02:00. | 99.9% |
| NFR-03 | Capacity | The system shall handle 80,000 ride requests per day with peaks of 200 per second. | 80k/day, 200/s peak |
| NFR-04 | Security | Only authenticated staff with a "City Ops" role shall see rider- or driver-level data. | Role-based |
| NFR-05 | Auditability | Every dispatch, surge, acceptance, and completion shall record who, when, and what action was taken. | Full trace |
| NFR-06 | Usability | A city operations manager shall be able to answer "is my zone healthy right now?" in under 10 seconds. | ≤10 s |
| NFR-07 | Compliance | The system shall comply with the city transport authority's 2027 reporting requirement and with UK GDPR. | Full |
| NFR-08 | Recoverability | The system shall restore service within 15 minutes of a failure, with no loss of trip ledger rows. | ≤15 min, zero loss |

---

## 9. User journeys

### 9.1 Journey: Evening peak — a stadium lets out
- **Trigger:** At 22:15, a stadium event ends. 4,000 riders open the app in the Stadium zone within 5 minutes.
- **Steps:** The system sees the surge in requests → checks the nearby-driver count → sees that it is zero → raises a surge banner at 2.1× → the city operations manager sees the surge on her screen → she calls the driver supply lead → more drivers move into the zone → matches begin → she records her action.
- **Outcome:** Riders see an honest surge, drivers respond, matches resume, and the event is recorded.
- **Failure path:** If the surge is not acknowledged within 5 minutes, it escalates to the duty manager. Surge pricing is regulated; the escalation must be visible.

### 9.2 Journey: Closed stand — operations decision
- **Trigger:** At 14:12, a road traffic accident closes the STADIUM-CURB stand.
- **Steps:** City operations adds STADIUM-CURB to the no-go register → the system stops dispatching into the stand → any riders pinned there are held → the dispatch ledger records the zone as idle → the operations manager acknowledges.
- **Outcome:** No rider is sent to a closed stand; the register is live and auditable.
- **Failure path:** If a rider was already en route when the zone closed, the system notifies the driver directly. The trip is allowed to complete.

### 9.3 Journey: Morning city transport authority report
- **Trigger:** 08:00, Chen opens his laptop.
- **Steps:** He opens the daily report → sees yesterday's requests, dispatches, surges, and waits per zone → exports it as a PDF → sends it to the city transport authority before 09:00.
- **Outcome:** Report delivered on time, no manual work, with an unmodifiable audit trail behind it.
- **Failure path:** If the report fails, he falls back to the old manual process for one day.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | Every rider ping is decided within 5 seconds. | Live test during peak hour |
| AC-02 | Dispatches, surges, and idles are correct for 100% of scripted test cases. | Scripted test with 50 known cases |
| AC-03 | No dispatch is raised twice in a row for the same rider and zone. | Scripted test with repeated identical pings |
| AC-04 | Every dispatch can be accepted and completed. | Demo with city operations managers |
| AC-05 | The daily dispatch report matches a manual count for a full day. | Side-by-side comparison |
| AC-06 | The trip ledger cannot be modified after the fact, by any user. | Inspection by the city transport authority |
| AC-07 | The idle-driver invariant `idle + assignments == 12` holds after every accept and complete. | Scripted test across accept and complete |
| AC-08 | The system runs for 30 days with 99.9% availability and zero trip ledger loss. | Monthly service report |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Rider app ping stream is slower than promised. | M | H | Early technical trial with Rider Engineering before full build. |
| R-02 | City operations managers find the screen too crowded. | M | M | Co-design workshops with operations managers from week 1. |
| R-03 | No-go register is out of date for some stands. | M | H | Weekly review with city operations; register is live and editable. |
| R-04 | Driver app push is unreliable on some devices. | M | M | Retry-once built in; escalate on second failure. |
| R-05 | City transport authority rejects the audit trail as insufficient. | L | H | Early review with Regulatory Affairs before build. |
| R-06 | Surge pricing decisions are challenged by the city. | M | H | Justify every surge with the supply-demand picture at the time. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| Average rider wait time | 4 min 30 s | 3 min | 3 months after go-live |
| Dispatches into a closed zone per 1,000 dispatches | 15 | 0 | 3 months after go-live |
| Time from supply shortage to operations response | 12 min | 5 min | 3 months after go-live |
| Daily city transport authority report preparation time | 90 min | 5 min | 1 month after go-live |
| City operations manager satisfaction with visibility | 2.4 / 5 | 4.0 / 5 | 3 months after go-live |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| Dispatch | The match of a rider to a driver. |
| Driver supply | The count of drivers available to take trips. |
| Idle driver | A driver who is online but not on a trip. |
| No-go register | The list of zones and stands where dispatch is currently prohibited. |
| Rider demand | The count of riders requesting trips. |
| Surge multiplier | The price multiplier applied when demand exceeds supply. |
| Zone | A geographic division of the metro area used for dispatch. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | What is the exact escalation path when a surge is not acknowledged within 5 minutes? | City Ops | 2026-10-15 | Open |
| Q-02 | Which zones are on the no-go register at go-live, and who owns the weekly review? | City Operations | 2026-10-20 | Open |
| Q-03 | What is the city transport authority's exact reporting format for phase 1? | Regulatory Affairs | 2026-10-25 | Open |
| Q-04 | Should surge multipliers above 3× require a second approval? | City Ops / Regulatory Affairs | 2026-11-01 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (COO) | `[name]` | | |
| Product owner (Head of City Ops) | `[name]` | | |
| Technical lead (Dispatch Engineering) | `[name]` | | |
| Compliance / risk | `[name]` | | |

---
