# Business Requirements Document (BRD)

## Grid Demand Response

| Field | Value |
|---|---|
| Project name | Grid Demand Response Watch |
| Document title | Business Requirements — Grid Demand Response |
| Version | 1.0 |
| Date | 2026-09-27 |
| Author | Transmission Operations Programme Office |
| Reviewer(s) | Head of System Operations, Demand Response Manager, Reliability Council Liaison |
| Approver(s) | Chief Operating Officer, Head of Safety & Compliance |
| Status | Approved |

**Revision history**

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | 2026-09-20 | Transmission Ops Programme Office | First draft |
| 1.0 | 2026-09-27 | Transmission Ops Programme Office | Approved after review with System Ops and Demand Response |

---

## 2. Executive summary

Every day, our transmission control room watches system frequency, area load, and the state of charge of our reserve resources. When system frequency sags — because a generator has tripped, a large load has come online, or an interconnector has lost capacity — we must act within seconds to protect the grid. The tool our operators use today is a set of screens that each show a different slice of the picture: frequency on one, load on another, reserve on a third. There is no single view, and there is no single record of what we decided and why. We need a simple tool that watches demand response in real time, decides when to shed interruptible load and when to warn, protects the feeders we must never drop (hospitals, water treatment, transport), and gives the shift lead one clear view of what is happening right now and one audit trail the reliability council can read but not modify. This document sets out what that tool must do, for whom, and how we will know it is working.

---

## 3. Business context

### 3.1 Background
Our transmission control area serves around 800 MW of firm demand and 200 MW of interruptible demand across four zones. The transmission desk watches system frequency against a 50 Hz nominal, with a normal band of 49.90–50.10 Hz. When frequency falls below 49.90 Hz, we enter a warning band; below 49.80 Hz, we enter the shed band and must open interruptible load to protect the grid. Every feeder we shed moves megawatts from the live reserve into a shed register, and every shed must be restored — deliberately, with an operator acknowledgement — once the event is over. Protected feeders (hospitals, water treatment, transport) must never be shed, regardless of frequency, unless the shift lead authorises it explicitly.

### 3.2 Problem statement
Right now, we have no single view of demand response. The SCADA system reports frequency, the energy management system reports area load, and the reserve register reports state of charge. The shift lead learns about a frequency event when the alarms sound, or when a generator calls to ask what is happening. The decision to shed — and the decision about which feeders to shed — is made in the operator's head, then typed into a control screen. There is no record of why a feeder was shed or who authorised it. We estimate that around 1 in 50 shed events involves a feeder that should have been protected, and that the average time from frequency event to shed action is 45 seconds — well short of our 30-second target, but with no audit trail to prove it.

### 3.3 Business drivers
- **Grid reliability.** A slow shed response risks a wider disturbance and, in the worst case, a cascading outage.
- **Regulatory pressure.** The reliability council requires all transmission operators to demonstrate real-time demand response decisions and to keep an unmodifiable record of every shed and restore.
- **Renewable integration.** As inverter-based generation grows, system inertia falls, and frequency events become faster and more frequent.
- **Staffing pressure.** Our shift leads are already stretched. They need fewer screens, not more, and they need the audit trail to be a by-product of the decision rather than a separate chore.

### 3.4 Alignment with strategy
Our 2025–2028 transmission strategy names "real-time operational visibility" as one of four pillars. This project delivers a first, concrete step in that direction, without replacing SCADA or the energy management system.

---

## 4. Scope

### 4.1 In scope
- Real-time monitoring of system frequency, area load, and state of charge for every zone in the control area.
- A single shift-lead view of current demand response across all zones.
- Automatic decisions when frequency enters the warning or shed band: warn the operator, or shed interruptible load.
- A protected-feeder register that the shift lead maintains and that the decision logic honours.
- A record of every shed, every restore, and every acknowledgement, in an append-only log.
- A daily report for the reliability council liaison team.

### 4.2 Out of scope
- Generation dispatch. We shed load; we do not dispatch generation.
- Interconnector scheduling. Handled by the interconnector desk.
- Behind-the-meter demand response. Handled by the aggregator relationships team.
- Smart-thermostat or customer-facing control. This is a transmission-desk tool.
- Distribution network automation. Handled by the distribution operator.
- Automatic restoration. Restoration is always an operator decision.

### 4.3 Assumptions
- SCADA provides frequency updates at least every 1 second.
- The energy management system provides area load every 5 seconds.
- The reserve register provides state of charge every 10 seconds.
- Each feeder's protection status (protected or interruptible) is agreed with the network operations team and reviewed monthly.
- The RTU (remote terminal unit) at each feeder acknowledges a shed command within 2 seconds.

### 4.4 Constraints
- No new hardware in the substations in this phase.
- Must go live before the 2027 summer peak.
- Must use the existing operator console for display.
- Must not disturb the live control room during rollout.
- Budget capped at the amount approved in the Q3 board paper.

### 4.5 Dependencies
- SCADA must expose a real-time frequency feed (SCADA team).
- Energy management system must expose area load (EMS team, already available).
- Reserve register must expose state of charge (Reserve team).
- Reliability council must agree the daily report format (Council liaison).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
|---|---|---|---|---|
| Sponsor | Chief Operating Officer | Reliability, regulatory readiness, cost | H | Monthly steering |
| Primary user | Shift Leads (4 zones) | One clear view, fast decisions, clean audit | H | Weekly workshops |
| Primary user | Transmission Desk Operators | Fewer screens, faster shed, safer restore | H | Weekly workshops |
| Reviewer | Reliability Council Liaison | Reporting accuracy, audit trail | M | Bi-weekly review |
| Reviewer | Safety & Compliance | Protected feeder integrity, no impact on safety | M | Sign-off before go-live |
| Regulator | Reliability Council | Real-time demand response from 2027 | L | Quarterly update |

---

## 6. Users and personas

### 6.1 Shift Lead — Amara
- **Role:** Shift lead for Zone 2, transmission control room.
- **Context:** In the control room, at the desk, from 06:00 to 18:00. Watches frequency continuously. Handles 5–20 frequency events a shift during the summer peak.
- **Goal:** Know within seconds when a frequency event starts, and know exactly which feeders she has shed and which she has restored.
- **Pain today:** Learns about an event when the alarms sound. Has to type feeder IDs into a separate control screen. Cannot prove after the event which feeders she chose to shed and why.
- **Success looks like:** One screen shows the whole control area's demand response, with red flags for anything shed and a green register for protected feeders.

### 6.2 Transmission Desk Operator — Diego
- **Role:** Desk operator for Zone 4.
- **Context:** At the console, on shift, dealing with the second-by-second picture.
- **Goal:** Know where the frequency event is worst and how many megawatts he can shed before the reserve runs out.
- **Pain today:** Has to check three screens to understand a single event. Wastes 10–20 seconds per event on coordination.
- **Success looks like:** A single display shows frequency, reserve, and shed status for his zone, with the shed band clearly marked.

### 6.3 Reliability Council Liaison — Chen
- **Role:** Daily contact for the reliability council.
- **Context:** In an office, reviews yesterday's events every morning.
- **Goal:** A one-page report showing yesterday's frequency events, shed actions, restores, and acknowledgements, so he can answer council queries without digging.
- **Pain today:** Builds the report by hand from three systems every morning. Takes 90 minutes and often misses a restore.
- **Success looks like:** Opens a report, sends it, done, with an unmodifiable audit trail behind it.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-01 | The system shall show, in real time, the system frequency, area load, and state of charge for every zone in the control area. | Must | Core purpose of the tool. |
| FR-02 | The system shall flag a frequency event as a warning when frequency falls below 49.90 Hz. | Must | Consistent warning band across all zones. |
| FR-03 | The system shall flag a frequency event as a shed when frequency falls below 49.80 Hz. | Must | Consistent shed band across all zones. |
| FR-04 | The system shall warn the operator, rather than shed, when the affected feeder is on the protected register. | Must | Protect hospitals, water, transport. |
| FR-05 | The shift lead shall be able to add or remove a feeder from the protected register while the system is running. | Must | Live policy. |
| FR-06 | The system shall not shed the same feeder twice in a row for the same event. | Must | Prevent alert fatigue and control chatter. |
| FR-07 | The shift lead shall be able to acknowledge an event and record the action taken. | Must | Audit trail of operator response. |
| FR-08 | The system shall raise an alert when a feeder has been shed for more than 15 minutes without acknowledgement. | Should | Escalation. |
| FR-09 | The shift lead shall be able to see all open shed events across all zones. | Should | Cross-zone awareness. |
| FR-10 | The system shall produce a daily frequency-event and shed report for the reliability council. | Must | Regulatory requirement. |
| FR-11 | The shift lead shall be able to add a free-text note to any event. | Should | Context for later review. |
| FR-12 | The system shall automatically restore a shed feeder to the reserve register when the shift lead acknowledges the restore. | Must | Return reserve MW. |
| FR-13 | The system shall retry a shed command once if the RTU does not acknowledge. | Must | Recover transient RTU failures. |
| FR-14 | The system shall reject a shed command that would take the reserve below zero. | Must | Grid safety. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | The system shall capture for every tick: area, feeder, frequency, area load, and state of charge. | Must | Minimum dataset for demand response. |
| DR-02 | The system shall capture for every shed event: feeder, dropped megawatts, start time, and the shift lead who acknowledged. | Must | Audit trail. |
| DR-03 | The system shall capture for every restore: feeder, restored megawatts, end time, and the shift lead who acknowledged. | Must | Audit trail. |
| DR-04 | The system shall retain the event log for 24 months. | Must | Reliability council requirement. |
| DR-05 | The system shall retain the reserve register for 7 days. | Must | Enough for a full shift review. |
| DR-06 | The system shall reject tick records with a missing area or feeder. | Must | Data quality at the source. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | A feeder on the protected register shall never be shed, regardless of frequency, without explicit shift-lead authorisation. | Company policy / safety | Must |
| BR-02 | No shed may be raised for a feeder that is already shed. | Operational practice | Must |
| BR-03 | Every shed must be acknowledged or restored within 15 minutes. | Service level | Must |
| BR-04 | The reliability council's view of the event log shall be read-only and shall not permit deletion of any row. | Regulatory | Must |
| BR-05 | The reserve register shall not be driven below zero under any circumstances. | Grid safety | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|---|
| AR-01 | The daily frequency-event report shall show, per zone: events, sheds, restores, total MW shed, total MW restored, and average response time. | Reliability Council Liaison | Daily | 24 months |
| AR-02 | The event log shall show every event with timings, actions, and acknowledgements. | Shift Leads, Safety & Compliance, Reliability Council | On demand | 24 months |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | The system shall update the display within 1 second of a frequency change. | 1 s |
| NFR-02 | Availability | The system shall be available 99.9% of the time between 04:00 and 24:00. | 99.9% |
| NFR-03 | Capacity | The system shall handle 2,000 frequency ticks per day across all zones. | 2k/day |
| NFR-04 | Security | Only authenticated staff with a "Transmission Ops" role shall see feeder-level data. | Role-based |
| NFR-05 | Auditability | Every shed, restore, and acknowledgement shall record who, when, and what action was taken. | Full trace |
| NFR-06 | Usability | A shift lead shall be able to answer "is my zone healthy right now?" in under 5 seconds. | ≤5 s |
| NFR-07 | Compliance | The system shall comply with the reliability council's 2027 reporting requirement. | Full |
| NFR-08 | Recoverability | The system shall restore service within 15 minutes of a failure, with no loss of event log rows. | ≤15 min, zero loss |

---

## 9. User journeys

### 9.1 Journey: Morning peak — spotting a frequency event
- **Trigger:** At 07:42 during the morning bank, system frequency falls to 49.70 Hz on Zone 2.
- **Steps:** The system detects the drop → sees that Zone 2's feeder INT-14 is interruptible → raises a shed → opens the feeder → appends a SHED row to the event log → enqueues an RTU command → the RTU acknowledges → the shift lead sees the shed on her screen → she records her action.
- **Outcome:** Reserve MW moved to the shed register, the RTU confirmed, and the shift lead has a full record.
- **Failure path:** If the RTU does not acknowledge within 2 seconds, the system retries once. If the retry also fails, the shed stays on the shift lead's screen and is escalated.

### 9.2 Journey: Protected feeder — hospital
- **Trigger:** At 14:12, frequency falls to 49.65 Hz. The worst-affected feeder is HOSP-1, a hospital supply.
- **Steps:** The system reads the feeder → sees that HOSP-1 is on the protected register → raises a warning, not a shed → appends a WARN row → the shift lead sees the warning and decides whether to authorise a shed explicitly.
- **Outcome:** The hospital feeder is protected by default; the shift lead has the authority to override.
- **Failure path:** If the shift lead does not acknowledge within 15 minutes, the warning escalates to the duty manager. The hospital feeder is never auto-shed.

### 9.3 Journey: Morning reliability council report
- **Trigger:** 08:00, Chen opens his laptop.
- **Steps:** He opens the daily report → sees yesterday's events, sheds, restores, and acknowledgements per zone → exports it as a PDF → sends it to the reliability council before 09:00.
- **Outcome:** Report delivered on time, no manual work, with an unmodifiable audit trail behind it.
- **Failure path:** If the report fails, he falls back to the old manual process for one day.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | Every frequency tick is visible within 1 second of the SCADA update. | Live test during a peak hour |
| AC-02 | Sheds, warnings, and holds are correct for 100% of scripted test cases. | Scripted test with 50 known events |
| AC-03 | No shed is raised twice in a row for the same feeder and event. | Scripted test with repeated identical ticks |
| AC-04 | Every shed can be acknowledged and restored. | Demo with shift leads |
| AC-05 | The daily report matches a manual count for a full day. | Side-by-side comparison |
| AC-06 | The event log cannot be modified after the fact, by any user. | Inspection by Safety & Compliance |
| AC-07 | The reserve invariant `reserve + shed == 800` holds after every shed and restore. | Scripted test across shed and restore |
| AC-08 | The system runs for 30 days with 99.9% availability and zero event log loss. | Monthly service report |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | SCADA feed is slower than promised. | M | H | Early technical trial with SCADA team before full build. |
| R-02 | Shift leads find the screen too crowded. | M | M | Co-design workshops with shift leads from week 1. |
| R-03 | Protected register is out of date for some feeders. | M | H | Monthly review with network operations; register is live and editable. |
| R-04 | RTU connectivity is unreliable at some substations. | M | M | Retry-once built in; escalate on second failure. |
| R-05 | Reliability council rejects the audit trail as insufficient. | L | H | Early review with council liaison before build. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| Time from frequency event to shed action | 45 s | 30 s | 3 months after go-live |
| Sheds involving a protected feeder per 1,000 events | 20 | 0 | 3 months after go-live |
| Daily reliability council report preparation time | 90 min | 5 min | 1 month after go-live |
| Shift lead satisfaction with visibility | 2.6 / 5 | 4.0 / 5 | 3 months after go-live |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| Control area | The portion of the transmission network for which we are responsible. |
| Demand response | Reducing load in response to a system event. |
| Feeder | A distribution circuit supplying a zone or a set of customers. |
| Frequency | The alternating-current frequency of the grid, nominally 50 Hz. |
| Interruptible load | Load that may be shed under contract or policy. |
| Protected feeder | A feeder that must never be shed without explicit authorisation (e.g. hospital, water, transport). |
| Reliability council | The body that oversees transmission reliability and reporting. |
| Reserve register | The record of available megawatts that can be shed. |
| RTU | Remote Terminal Unit — the substation device that executes a shed command. |
| SCADA | Supervisory Control and Data Acquisition — the system that reports real-time grid state. |
| Shed | The act of opening an interruptible feeder. |
| SOC | State of charge — the available energy in a reserve resource. |
| Zone | A geographic division of the control area. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | What is the exact escalation path when a shed is not acknowledged within 15 minutes? | System Ops | 2026-10-15 | Open |
| Q-02 | Should the protected register be per-zone or per-feeder across the whole control area? | Network Operations | 2026-10-20 | Open |
| Q-03 | What is the reliability council's exact reporting format for phase 1? | Council Liaison | 2026-10-25 | Open |
| Q-04 | Which feeders are on the protected register at go-live? | Network Operations | 2026-11-01 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (COO) | `[name]` | | |
| Product owner (Head of System Ops) | `[name]` | | |
| Technical lead (SCADA / EMS) | `[name]` | | |
| Compliance / risk | `[name]` | | |

---

*End of document.*