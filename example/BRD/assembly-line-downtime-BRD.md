# Business Requirements Document (BRD)

## Assembly Line Downtime & Defect Monitoring

| Field | Value |
|---|---|
| Project name | Line Pulse |
| Document title | Business Requirements — Assembly Line Downtime & Defect Monitoring |
| Version | 1.0 |
| Date | 2026-09-27 |
| Author | Plant Operations Programme Office |
| Reviewer(s) | Plant Manager, Quality Manager, Production Supervisors (Lines 1–3) |
| Approver(s) | VP Manufacturing, Head of Quality |
| Status | Approved |

**Revision history**

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | 2026-08-30 | Plant Operations Programme Office | First draft |
| 1.0 | 2026-09-27 | Plant Operations Programme Office | Approved after review with Production and Quality |

---

## 2. Executive summary

Our plant runs three brake-caliper assembly lines, three shifts a day, producing roughly 9,000 units daily. When a line stops — a robot faults, a part starves upstream, a torque tool fails calibration — nobody outside that line knows until the shift-end report, by which point the plant has already lost the output. When a defect rate creeps up on a station, we usually catch it during the next audit, not while it is happening. We need a tool that watches every line in real time, tells the shift supervisor the moment something is wrong and how bad it is, and gives quality a live view of defect trends by station. This document sets out what that tool must do, for whom, and how we will know it is working.

---

## 3. Business context

### 3.1 Background

Each line has 14 stations: manual and robotic assembly, torque verification, leak testing, and final inspection. A unit takes about 90 seconds to move through the line at rated speed. Every station reports its own cycle time and pass/fail result to its own local HMI screen; none of that data reaches a shared view. Downtime causes fall into a known set — starved (no part available), blocked (downstream full), tooling fault, robot fault, changeover, planned maintenance — and are currently written on a paper board at the end of each shift, from memory.

### 3.2 Problem statement

Right now, we have no single view of line health. Each station's PLC reports status to its own HMI; the andon light tells the floor something is wrong but not what, how long, or how many units are affected. The shift supervisor finds out about a slow bleed of defects only at the next quality audit, often a full shift after it started. We estimate that around 1 in 400 units built in the last quarter carried a defect that could have been caught within 10 minutes if a station's fail rate had been visible in real time, instead of at end-of-shift review.

### 3.3 Business drivers

- **Scrap and rework cost.** Late-caught defects mean full batches sometimes get scrapped or reworked instead of a handful of units.
- **OEE targets.** Corporate has set an 85% Overall Equipment Effectiveness target for all lines by the 2027 model-year changeover; we do not currently know our real-time OEE at all.
- **Customer quality audits.** Our largest OEM customer audits defect-escape data quarterly and has flagged "reactive, not real-time" quality monitoring as a finding twice.
- **Supervisor workload.** Shift supervisors already walk the floor constantly; they need one screen that tells them where to walk, not more screens to check.

### 3.4 Alignment with strategy

Our 2026–2029 manufacturing strategy names "real-time visibility" as one of three pillars, alongside automation and workforce development. This project delivers the visibility pillar's first concrete step, without replacing the PLCs or the MES already installed on each line.

---

## 4. Scope

### 4.1 In scope

- Real-time monitoring of line and station status (running, starved, blocked, faulted, changeover, planned maintenance) for all three assembly lines.
- A single shift-supervisor view of current line health across all three lines.
- Automatic alerts when a line or station is down longer than a threshold, or when a station's defect rate crosses a threshold.
- A record of every alert and every action taken by staff.
- A shift-end OEE and defect summary for the quality team.

### 4.2 Out of scope

- Lines at the company's second plant (a later phase).
- Replacing the station PLCs, the MES, or the torque/leak-test tooling.
- Automatic line stoppage or automatic rework routing. Staff will still make the decision to stop a line.
- Supplier-facing defect notifications.
- Root-cause analysis tooling beyond the recorded downtime cause code.
- Anything outside the three brake-caliper lines at this plant.

### 4.3 Assumptions

- Each station's PLC can publish a status change at least every 5 seconds.
- Each unit is tracked by a serial/VIN-style build tag scanned at the first station and read at every subsequent station.
- The plant's MES provides the shift schedule and the day's build plan (line, part number, target rate).
- Wi-Fi/Ethernet coverage exists across the floor for supervisor tablets.
- Supervisors will use the tool on existing floor tablets; station operators keep their local HMI unchanged.

### 4.4 Constraints

- No new PLC hardware or firmware changes on the stations in this phase.
- Must go live before the 2027 model-year changeover.
- Must use the existing plant single sign-on for staff login.
- Must not interrupt production during rollout.
- Budget capped at the amount approved in the FY27 capital plan.

### 4.5 Dependencies

- Station PLCs must expose a real-time status feed (Controls Engineering team).
- MES must expose the shift schedule and build plan (IT team, already available).
- Floor network coverage confirmed for all three lines (Infrastructure team).
- Quality team must agree the shift-end report format (Quality team).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
|---|---|---|---|---|
| Sponsor | VP Manufacturing | Cost, OEE target, customer audit standing | H | Monthly steering |
| Primary user | Shift Supervisors (Lines 1–3) | One clear view, fewer floor walks to find problems | H | Weekly workshops |
| Primary user | Quality Engineers | Real-time defect visibility by station | H | Weekly workshops |
| Reviewer | Controls Engineering | Feed reliability, no PLC changes | M | Bi-weekly review |
| Reviewer | Plant Safety | No impact on line safety interlocks | M | Sign-off before go-live |
| Customer | Largest OEM's quality auditor | Real-time quality monitoring evidence | L | Quarterly update |

---

## 6. Users and personas

### 6.1 Shift Supervisor — Dana

- **Role:** Shift supervisor for Line 2, all three shifts rotate through her.
- **Context:** On the floor most of the shift, tablet in hand. Manages 12–15 operators.
- **Goal:** Know within a minute when a station goes down or a defect rate spikes, and know which station to walk to first.
- **Pain today:** Learns about a slow defect creep only at the next quality audit. Checks three HMIs to understand one stoppage.
- **Success looks like:** One screen shows her all three lines' health, with a red flag on any station in trouble.

### 6.2 Quality Engineer — Raj

- **Role:** Covers all three lines for in-process quality.
- **Context:** Splits time between the floor and the quality office; reviews defect trends daily.
- **Goal:** See a station's defect rate creeping up before it becomes a batch of scrap.
- **Pain today:** Finds out during the next scheduled audit, sometimes a full shift late.
- **Success looks like:** An alert tells him the station, the defect rate, and the units affected, while the trend is still small.

### 6.3 Production Manager — Elena

- **Role:** Owns OEE performance across all three lines, reports weekly to the VP.
- **Context:** In the office most of the day, reviews yesterday's numbers every morning.
- **Goal:** A one-page OEE and downtime-cause summary per line, without building it by hand.
- **Pain today:** Builds the report from three paper boards and the MES export every morning. Takes about 70 minutes.
- **Success looks like:** Opens a report, reviews it, done.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-01 | The system shall show, in real time, the status of every station on all three lines (running, starved, blocked, faulted, changeover, planned maintenance). | Must | Core purpose of the tool. |
| FR-02 | The system shall calculate, for every station, the rolling defect rate over the current shift. | Must | Needed to know which stations are trending out of control. |
| FR-03 | The system shall flag a station as "at risk" when its rolling defect rate exceeds the station's configured threshold. | Must | Consistent rule across all lines. |
| FR-04 | The shift supervisor shall be able to see all at-risk stations across their line on a single screen. | Must | One screen, one view. |
| FR-05 | The system shall raise an alert to the relevant supervisor when a station is down (starved, blocked, or faulted) for more than 3 minutes. | Must | Fast reaction to stoppages. |
| FR-06 | The system shall show, for each alert, the affected station, the downtime cause code if known, and the units affected since the stop began. | Must | Give the supervisor enough to act. |
| FR-07 | The supervisor shall be able to acknowledge an alert and record the action taken and the downtime cause code. | Must | Audit trail of staff response. |
| FR-08 | The system shall group individual station alerts into a single incident when they share the same line and overlap in time. | Should | Prevent alert fatigue. |
| FR-09 | The production manager shall be able to see all open incidents across all three lines. | Should | Cross-line awareness. |
| FR-10 | The system shall produce a shift-end OEE and downtime-cause summary per line. | Must | Production manager and quality requirement. |
| FR-11 | The system shall allow the supervisor to add a free-text note to any incident. | Should | Context for later review. |
| FR-12 | The system shall allow the quality engineer to export a shift's defect data as a spreadsheet. | Could | Ad-hoc requests from the OEM auditor. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | The system shall capture for every station event: station id, line id, status, timestamp, and unit build tag if applicable. | Must | Minimum dataset for line-health monitoring. |
| DR-02 | The system shall capture for every unit: build tag, part number, line id, and pass/fail result at each inspection or test station. | Must | Needed to compute defect rate. |
| DR-03 | The system shall capture for every incident: start time, end time, affected station(s), units affected, downtime cause code, actions taken, and the supervisor who acknowledged. | Must | Audit and reporting. |
| DR-04 | The system shall retain incident records for 24 months. | Must | Customer audit requirement. |
| DR-05 | The system shall retain station status history for 14 days. | Must | Enough for a full shift-cycle review. |
| DR-06 | The system shall reject station events with a missing station id or line id. | Must | Data quality at the source. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | A line may not be stopped automatically by the system under any condition; only an operator or supervisor stops a line. | Plant safety policy | Must |
| BR-02 | No alert may be raised for a station that is in a scheduled changeover or planned-maintenance window. | Operational practice | Must |
| BR-03 | Every alert must be acknowledged or dismissed within 10 minutes. | Service level | Must |
| BR-04 | Defect data shared with the customer auditor must exclude operator identity. | Company privacy policy | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|---|
| AR-01 | The shift-end summary shall show, per line: units built, defect rate by station, total downtime by cause code, and calculated OEE. | Production manager, Quality | Per shift | 24 months |
| AR-02 | The incident log shall show every incident with timings and actions. | Supervisors, Quality, Plant Safety | On demand | 24 months |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | The screen shall update within 5 seconds of a station status change. | 5 s |
| NFR-02 | Availability | The system shall be available 99.9% of the time during all scheduled production shifts. | 99.9% |
| NFR-03 | Capacity | The system shall handle 45,000 station events per day across all three lines. | 45k/day |
| NFR-04 | Security | Only authenticated staff with a "Production Ops" role shall see station-level defect data. | Role-based |
| NFR-05 | Auditability | Every alert acknowledgement shall record who, when, and what action was taken. | Full trace |
| NFR-06 | Usability | A supervisor shall be able to answer "is my line healthy right now?" in under 10 seconds. | ≤10 s |
| NFR-07 | Compliance | The system shall exclude operator identity from any data shared outside the plant. | Full |
| NFR-08 | Recoverability | The system shall restore service within 30 minutes of a failure. | ≤30 min |

---

## 9. User journeys

### 9.1 Journey: Morning shift — spotting a stall

- **Trigger:** The torque-verification station on Line 2 faults at 07:15 during the morning shift.
- **Steps:** The system detects the fault after 3 minutes → raises an alert → Dana (Line 2 supervisor) sees the alert on her tablet → she walks to the station with the exact fault code and the 18 units affected since the stop began → maintenance clears the fault in 6 minutes → she acknowledges the alert with cause code "TOOL-CAL" and a note "torque tool recalibrated."
- **Outcome:** Line resumes, units re-routed for inspection, alert closed with a full record.
- **Failure path:** If Dana does not acknowledge within 10 minutes, the system escalates to the production manager.

### 9.2 Journey: A defect rate creeping up

- **Trigger:** The leak-test station on Line 1 starts failing 3 of every 20 units, above its configured 5% threshold.
- **Steps:** The system flags the station → Raj (quality engineer) sees the red flag on the "at-risk stations" screen → he walks the line and finds a worn gasket-seating fixture → he has it swapped → the defect rate drops back under threshold within the hour, and the incident is closed with the fixture swap recorded.
- **Outcome:** A handful of units re-inspected instead of a full pallet scrapped, root cause recorded.
- **Failure path:** If the defect rate keeps climbing past a second, higher threshold, the incident escalates to the production manager.

### 9.3 Journey: Morning OEE report

- **Trigger:** 06:30, Elena opens her laptop before the daily production meeting.
- **Steps:** She opens the shift-end summary → sees yesterday's OEE and downtime causes per line → exports it as a PDF → brings it to the production meeting.
- **Outcome:** Report ready on time, no manual board-transcription needed.
- **Failure path:** If the report fails, she falls back to reading the paper boards for one day.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | Every station status change is visible within 5 seconds of the PLC event. | Live test during a production hour |
| AC-02 | At-risk stations are correctly identified for 100% of test cases. | Scripted test with 50 known defect sequences |
| AC-03 | Alerts for station downtime are raised within 3 minutes 30 seconds. | Timed test with a controlled stop |
| AC-04 | Every alert can be acknowledged and recorded with a cause code. | Demo with shift supervisors |
| AC-05 | Shift-end summary matches a manual count for a full shift. | Side-by-side comparison |
| AC-06 | No operator identity appears in data exported for the customer auditor. | Inspection by Quality and Legal |
| AC-07 | The system runs for 30 days with 99.9% availability during scheduled shifts. | Monthly service report |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Station PLC feed is slower or less reliable than promised. | M | H | Early technical trial with Controls Engineering before full build. |
| R-02 | Supervisors find the screen too crowded during a busy shift. | M | M | Co-design workshops with supervisors from all three lines from week 1. |
| R-03 | Defect-rate thresholds are wrong for some stations at launch. | M | M | Start with Quality's current audit thresholds; review after 4 weeks of data. |
| R-04 | Floor network blackspots near Line 3's far end. | L | M | Coverage survey before go-live, tablets cached for short outages. |
| R-05 | Operators see the tool as extra scrutiny rather than a helping hand. | M | H | Involve supervisors and operators in design; keep the "acknowledge" step to one tap. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| Preventable defect escapes per 1,000 units | 2.5 | 1.5 | 3 months after go-live |
| Time from station fault to maintenance arrival | 14 min | 7 min | 3 months after go-live |
| Shift-end report preparation time | 70 min | 5 min | 1 month after go-live |
| Real-time OEE visibility (lines with live OEE) | 0 of 3 | 3 of 3 | 1 month after go-live |
| Supervisor satisfaction with visibility | 2.8 / 5 | 4.0 / 5 | 3 months after go-live |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| Andon | The visual/audible signal a station raises when it needs attention. |
| Build tag | The unique identifier scanned onto a unit at the first station. |
| Changeover | The scheduled window where a line switches to a different part number. |
| Defect rate | The share of units failing an inspection or test station. |
| Downtime cause code | A short code (e.g. "TOOL-CAL", "STARVED") recorded when a station stops. |
| MES | Manufacturing Execution System — the system of record for the build plan and shift schedule. |
| OEE | Overall Equipment Effectiveness — a combined measure of availability, performance, and quality. |
| PLC | Programmable Logic Controller — the station-level control hardware. |
| Station | One step in the assembly line (e.g. torque verification, leak test). |
| Starved | A station idle because no part is available from upstream. |
| Blocked | A station unable to release a finished unit because downstream is full. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | Will Line 3's older PLCs provide the same status feed as Lines 1 and 2? | Controls Engineering | 2026-10-10 | Open |
| Q-02 | What defect-rate threshold should each station start with, and who owns changing it later? | Quality | 2026-10-15 | Open |
| Q-03 | What is the approved escalation policy when no one acknowledges an alert? | Plant Operations Programme Office | 2026-10-20 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (VP Manufacturing) | `[name]` | | |
| Product owner (Plant Manager) | `[name]` | | |
| Technical lead (Controls Engineering) | `[name]` | | |
| Quality / compliance | `[name]` | | |

---

*End of document.*
