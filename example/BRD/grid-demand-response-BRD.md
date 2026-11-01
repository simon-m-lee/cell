# Business Requirements Document (BRD) — Grid Demand Response

**Template version:** 2.0 (upgraded from template 1.0)
**Supersedes:** `grid-demand-response_Cell_-BRD.md` (version 1.0, approved 2026-09-27)
**Mitose stem:** `grid-demand-response`

**How to read the tags.** Text copied from version 1.0 is unchanged. Everything the upgrade added is tagged. `[AI SUGGESTED]` marks a drafted acceptance criterion, class or mapping. `[AI SUGGESTED — needs confirmation]` marks a draft that depends on a decision no one has made. `[To be confirmed]` marks a value, owner or date nobody has given. Every tagged item has a matching row in section 14.

---

## 1. Document control

| Field | Value |
|---|---|
| Project name | Grid Demand Response Watch |
| Document title | Business Requirements — Grid Demand Response |
| Version | 1.1.0 |
| Date | 2026-10-28 |
| Author | Transmission Operations Programme Office (v1.0); AI-assisted template 2.0 upgrade (v1.1.0) |
| Reviewer(s) | Head of System Operations, Demand Response Manager, Reliability Council Liaison |
| Approver(s) | Chief Operating Officer, Head of Safety & Compliance |
| Status | In review — v1.0 was approved; the template 2.0 additions in v1.1.0 are not yet approved |

**Revision history**

| Version | Date | Change ID | Author | Change summary |
|---|---|---|---|---|
| 0.1 | 2026-09-20 | — | Transmission Ops Programme Office | First draft |
| 1.0 | 2026-09-27 | — | Transmission Ops Programme Office | Approved after review with System Ops and Demand Response |
| 1.1.0 | 2026-10-28 | — | AI-assisted upgrade (reviewer to confirm) | Upgraded to BRD template 2.0 for Mitose pipeline 2.0. Added a priority, acceptance criterion and class to every requirement (all drafted, tagged); parameter register (7.5); decision precedence draft (7.6); measure basis for each non-functional requirement; covers and class for each acceptance criterion; new acceptance criteria AC-09 to AC-14; requirement IDs on journeys and success measures; findings F-01 to F-17 and questions Q-05 to Q-23 (reported, not fixed); consistency checks; residual acceptance; appendices. No requirement ID, requirement text, priority or number from v1.0 was changed, reused or renumbered. Awaiting re-approval. |

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

| Role | Name / Group | Interest | Influence (H/M/L) | Engagement approach |
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

*Every acceptance criterion and class in this section was drafted during the template 2.0 upgrade and is tagged `[AI SUGGESTED]`. Numbers in a criterion point to the parameter register (7.5); a number is never repeated here where the register holds it. Where several rules can match one tick, 7.6 decides.*

### 7.1 Functional requirements

| ID | Requirement | Priority (Must / Should / Could) | Acceptance criterion (Given / When / Then, with tolerance) | Class | Rationale |
|---|---|---|---|---|---|
| FR-01 | The system shall show, in real time, the system frequency, area load, and state of charge for every zone in the control area. | Must | `[AI SUGGESTED]` **Given** a tick for Zone 2 carrying frequency, area load and state of charge, **when** it is received, **then** the shift-lead view for Zone 2 shows all three values within P-13 of receipt. | T | Core purpose of the tool. |
| FR-02 | The system shall flag a frequency event as a warning when frequency falls below 49.90 Hz. | Must | `[AI SUGGESTED]` **Given** an interruptible feeder that is not shed, **when** a tick is one step of P-03 below P-01, **then** a warning is flagged; **when** a tick is exactly at P-01, **then** no warning is flagged. Where P-02 also applies, 7.6 decides. | T | Consistent warning band across all zones. |
| FR-03 | The system shall flag a frequency event as a shed when frequency falls below 49.80 Hz. | Must | `[AI SUGGESTED]` **Given** an interruptible feeder that is not shed and has reserve available, **when** a tick is one step of P-03 below P-02, **then** a shed is flagged; **when** a tick is exactly at P-02, **then** no shed is flagged. | T | Consistent shed band across all zones. |
| FR-04 | The system shall warn the operator, rather than shed, when the affected feeder is on the protected register. | Must | `[AI SUGGESTED]` **Given** a feeder on the protected register, **when** a tick shows a frequency below P-02 (journey 9.2 uses 49.65 Hz), **then** a warning is raised, no shed is raised, the reserve is unchanged, and a WARN row is appended to the event log. | T | Protect hospitals, water, transport. |
| FR-05 | The shift lead shall be able to add or remove a feeder from the protected register while the system is running. | Must | `[AI SUGGESTED]` **Given** the system is running and feeder X is interruptible, **when** the shift lead adds X to the protected register, **then** the next tick for X below P-02 raises a warning and no shed, with no restart; **when** the shift lead removes X, **then** the next such tick raises a shed. | T | Live policy. |
| FR-06 | The system shall not shed the same feeder twice in a row for the same event. | Must | `[AI SUGGESTED]` **Given** a shed raised for feeder F during an event, **when** a further tick for F in the same event arrives before acknowledgement, **then** no second shed is raised and the event log gains no second SHED row for F. ("Same event" is not defined — F-03.) | T | Prevent alert fatigue and control chatter. |
| FR-07 | The shift lead shall be able to acknowledge an event and record the action taken. | Must | `[AI SUGGESTED]` **Given** an open shed, **when** the shift lead acknowledges it and records the action taken, **then** the event log shows the acknowledgement with who, when, and the action. | T | Audit trail of operator response. |
| FR-08 | The system shall raise an alert when a feeder has been shed for more than 15 minutes without acknowledgement. | Should | `[AI SUGGESTED]` **Given** a shed with no acknowledgement, **when** P-07 elapses (tolerance `[To be confirmed]`), **then** one alert is raised for that shed; **given** an acknowledgement before P-07 elapses, **then** no alert is raised. | T | Escalation. |
| FR-09 | The shift lead shall be able to see all open shed events across all zones. | Should | `[AI SUGGESTED]` **Given** open sheds in more than one zone, **when** the shift lead opens the open-sheds view, **then** every open shed in every zone is listed and no closed shed is listed. | T | Cross-zone awareness. |
| FR-10 | The system shall produce a daily frequency-event and shed report for the reliability council. | Must | `[AI SUGGESTED]` **Given** a day whose events are known, **when** the daily report is produced, **then** each per-zone figure equals the count taken from the event log for that day. Format: P-23. | T | Regulatory requirement. |
| FR-11 | The shift lead shall be able to add a free-text note to any event. | Should | `[AI SUGGESTED]` **Given** any event, **when** the shift lead adds a free-text note, **then** the note is retained against that event with who and when. | T | Context for later review. |
| FR-12 | The system shall automatically restore a shed feeder to the reserve register when the shift lead acknowledges the restore. | Must | `[AI SUGGESTED]` **Given** a shed feeder with quantity M (P-06), **when** the shift lead acknowledges the restore, **then** the reserve rises by M, the shed register falls by M, a restore row records feeder, megawatts, end time and shift lead, and reserve plus shed equals P-05. (Wording against 4.2 — F-15.) | T | Return reserve MW. |
| FR-13 | The system shall retry a shed command once if the RTU does not acknowledge. | Must | `[AI SUGGESTED]` **Given** a shed command sent to a feeder's RTU, **when** no acknowledgement arrives within P-09, **then** the command is sent once more (P-10); **when** the retry is also unacknowledged, **then** the shed stays visible to the shift lead and is escalated to P-08. | T | Recover transient RTU failures. |
| FR-14 | The system shall reject a shed command that would take the reserve below zero. | Must | `[AI SUGGESTED]` **Given** a reserve of R MW, **when** a shed of M MW is requested, **then** M equal to R is accepted and leaves the reserve at zero, and M greater than R is rejected with the reserve unchanged and no shed row added. | T | Grid safety. |

### 7.2 Data requirements

| ID | Requirement | Priority | Acceptance criterion | Class | Rationale |
|---|---|---|---|---|---|
| DR-01 | The system shall capture for every tick: area, feeder, frequency, area load, and state of charge. | Must | `[AI SUGGESTED]` **Given** a valid tick, **when** it is received, **then** all five fields are retained exactly as received. | T | Minimum dataset for demand response. |
| DR-02 | The system shall capture for every shed event: feeder, dropped megawatts, start time, and the shift lead who acknowledged. | Must | `[AI SUGGESTED]` **Given** a shed that has been acknowledged, **when** its record is read, **then** it holds feeder, dropped megawatts, start time, and the acknowledging shift lead. | T | Audit trail. |
| DR-03 | The system shall capture for every restore: feeder, restored megawatts, end time, and the shift lead who acknowledged. | Must | `[AI SUGGESTED]` **Given** a restore that has been acknowledged, **when** its record is read, **then** it holds feeder, restored megawatts, end time, and the acknowledging shift lead. | T | Audit trail. |
| DR-04 | The system shall retain the event log for 24 months. | Must | `[AI SUGGESTED]` **Given** an event log row created on day D, **when** it is read at D plus P-11, **then** it is still present and unchanged. | I | Reliability council requirement. |
| DR-05 | The system shall retain the reserve register for 7 days. | Must | `[AI SUGGESTED]` **Given** a reserve register entry made on day D, **when** it is read at D plus P-12, **then** it is still present. | I | Enough for a full shift review. |
| DR-06 | The system shall reject tick records with a missing area or feeder. | Must | `[AI SUGGESTED]` **Given** a tick with the area missing, **when** it is received, **then** it is rejected and nothing is recorded; the same holds for a tick with the feeder missing; a tick with both present is accepted. | T | Data quality at the source. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority | Acceptance criterion | Class |
|---|---|---|---|---|---|
| BR-01 | A feeder on the protected register shall never be shed, regardless of frequency, without explicit shift-lead authorisation. | Company policy / safety | Must | `[AI SUGGESTED]` **Given** a protected feeder and a reading below P-02, **when** no explicit shift-lead authorisation exists, **then** the feeder is not shed. The authorised case has no requirement yet — F-02. | T |
| BR-02 | No shed may be raised for a feeder that is already shed. | Operational practice | Must | `[AI SUGGESTED]` **Given** feeder F is already shed, **when** any tick for F is below P-02, **then** no new shed is raised. | T |
| BR-03 | Every shed must be acknowledged or restored within 15 minutes. | Service level | Must | `[AI SUGGESTED]` **Given** a shed at time t0, **when** P-07 elapses with neither an acknowledgement nor a restore, **then** the rule is breached and the alert in FR-08 is raised. | T |
| BR-04 | The reliability council's view of the event log shall be read-only and shall not permit deletion of any row. | Regulatory | Must | `[AI SUGGESTED]` **Given** the council's view of the event log, **when** a change or deletion of any row is attempted, **then** it is refused and the row count is unchanged. | T |
| BR-05 | The reserve register shall not be driven below zero under any circumstances. | Grid safety | Must | `[AI SUGGESTED]` **Given** any generated sequence of sheds and restores (number of sequences P-24), **when** each step is applied, **then** the reserve is never below zero. | P |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention | Priority | Acceptance criterion | Class |
|---|---|---|---|---|---|---|---|
| AR-01 | The daily frequency-event report shall show, per zone: events, sheds, restores, total MW shed, total MW restored, and average response time. | Reliability Council Liaison | Daily | 24 months | Must `[AI SUGGESTED — needs confirmation]` | `[AI SUGGESTED]` **Given** a day whose events are known, **when** the report is produced, **then** each of the six figures per zone equals the value computed from the event log. "Average response time" has no definition yet — F-13. | T |
| AR-02 | The event log shall show every event with timings, actions, and acknowledgements. | Shift Leads, Safety & Compliance, Reliability Council | On demand | 24 months | Must `[AI SUGGESTED — needs confirmation]` | `[AI SUGGESTED]` **Given** an event with an action and an acknowledgement, **when** the event log is shown, **then** the event appears with its timings, action, and acknowledgement. | T |

### 7.5 Parameter register

*A missing value is `TBD`. Rows marked "set — conflict" carry the value the BRD states, but another part of the BRD disagrees; the finding is named in the last column.*

| ID | Parameter | Used by (requirement IDs) | Value | Unit | Owner | Status (set / TBD) | Open question |
|---|---|---|---|---|---|---|---|
| P-01 | Warning threshold: frequency below this value is a warning (comparison is "below", not "at or below") | FR-02, AC-02 | 49.90 | Hz | `[To be confirmed]` | set | — |
| P-02 | Shed threshold: frequency below this value is a shed | FR-03, FR-04, BR-01, BR-02, FR-05, AC-02 | 49.80 | Hz | `[To be confirmed]` | set | — |
| P-03 | Frequency reading step (smallest difference between two readings, needed for just-below boundary cases) | FR-02, FR-03 | TBD | Hz | SCADA team | TBD | Q-21 |
| P-04 | Protected register contents at go-live | FR-04, FR-05, BR-01, AC-02 | TBD | list of feeder IDs | Network Operations | TBD | Q-02, Q-04 |
| P-05 | Reserve baseline: reserve plus shed always equals this (AC-07) | FR-12, FR-14, BR-05, AC-07 | 800 | MW | `[To be confirmed]` | set — conflict (3.1 gives 200 MW interruptible) | Q-10 |
| P-06 | Quantity shed per feeder | FR-12, FR-14, DR-02, DR-03 | TBD | MW per feeder | `[To be confirmed]` | TBD | Q-09 |
| P-07 | Acknowledgement window for a shed | BR-03, FR-08, AC-13 | 15 | min | `[To be confirmed]` | set | Q-01, Q-08 |
| P-08 | Escalation recipient(s) for an unacknowledged shed or warning, and for a failed RTU retry | FR-08, FR-13 | TBD | role(s) | System Ops | TBD | Q-01, Q-08 |
| P-09 | RTU acknowledgement time limit | FR-13, AC-10 | 2 | s | `[To be confirmed]` | set | — |
| P-10 | RTU retry count | FR-13, AC-10 | 1 | retry | `[To be confirmed]` | set | — |
| P-11 | Event log retention | DR-04, AR-01, AR-02, AC-12 | 24 | months | `[To be confirmed]` | set | Q-14 |
| P-12 | Reserve register retention | DR-05, AC-12 | 7 | days | `[To be confirmed]` | set | — |
| P-13 | Display update limit after a frequency change | FR-01, NFR-01, AC-01 | 1 | s | `[To be confirmed]` | set | Q-12 |
| P-14 | Availability target, window and period | NFR-02, AC-08 | 99.9 between 04:00 and 24:00, over 30 days (from AC-08) | % | `[To be confirmed]` | set | Q-12 |
| P-15 | Tick volume per day | NFR-03 | 2,000 | ticks/day | `[To be confirmed]` | set — conflict (4.3 gives a feed at least every 1 s) | Q-11 |
| P-16 | Recovery time limit and event log loss allowed | NFR-08, AC-08 | 15 min; zero rows lost | min | `[To be confirmed]` | set | Q-12 |
| P-17 | Time to answer "is my zone healthy right now?" | NFR-06 | 5 | s | `[To be confirmed]` | set | Q-12 |
| P-18 | Scripted test events for sheds, warnings and holds | AC-02 | 50 | events | `[To be confirmed]` | set | — |
| P-19 | Shed-action response target (event to shed action) | — (stated in 3.2 and section 12; no requirement uses it) | 30 | s | `[To be confirmed]` | set | Q-18 |
| P-20 | SCADA frequency update interval | FR-01, NFR-01, NFR-03 | at least every 1 | s | SCADA team | set (assumption 4.3) | Q-11 |
| P-21 | Area load update interval | FR-01 | 5 | s | EMS team | set (assumption 4.3) | — |
| P-22 | State-of-charge update interval | FR-01 | 10 | s | Reserve team | set (assumption 4.3) | — |
| P-23 | Daily report format | FR-10, AR-01, NFR-07 | TBD | — | Council Liaison | TBD | Q-03 |
| P-24 | Number of generated shed and restore sequences for the reserve property check | BR-05, AC-07 | TBD | sequences | `[To be confirmed]` | TBD | Q-23 |

### 7.6 Decision precedence

*`[AI SUGGESTED — needs confirmation]` The BRD does not say which rule wins when one tick matches several. This draft is built only from journeys 9.1 and 9.2 and from the rule wording. The relative order of rows 1 to 3 is not settled by the BRD (F-01, Q-05).*

| Order | Rule (requirement ID) | Wins over | All matching reasons recorded? |
|---|---|---|---|
| 1 | FR-04 / BR-01 — protected feeder: warn, do not shed | FR-03 | `[To be confirmed]` |
| 2 | BR-02 / FR-06 — feeder already shed: no new shed | FR-03 | `[To be confirmed]` |
| 3 | FR-14 / BR-05 — shed would take reserve below zero: reject | FR-03 | `[To be confirmed]` |
| 4 | FR-03 — shed band (a reading below P-02 is also below P-01) | FR-02 | `[To be confirmed]` |
| 5 | FR-02 — warning band | — | `[To be confirmed]` |

---

## 8. Non-functional requirements

*Targets and wording are from version 1.0. The priority, "how measured" and class columns were added in the upgrade. Priorities are `[To be confirmed]` because version 1.0 gave none. Percentiles, sample sizes and loads are `[To be confirmed]` because they were never stated.*

| ID | Category | Requirement | Target | Priority | How measured (percentile / window / sample / start and end) | Class |
|---|---|---|---|---|---|---|
| NFR-01 | Performance | The system shall update the display within 1 second of a frequency change. | 1 s | `[To be confirmed]` | `[AI SUGGESTED — needs confirmation]` Percentile `[To be confirmed]`, from receipt of the frequency reading to the display updated, at peak load `[To be confirmed]`. | M |
| NFR-02 | Availability | The system shall be available 99.9% of the time between 04:00 and 24:00. | 99.9% | `[To be confirmed]` | `[AI SUGGESTED — needs confirmation]` Time unavailable within 04:00–24:00 over 30 days (period from AC-08); the definition of "available" is `[To be confirmed]`. | M |
| NFR-03 | Capacity | The system shall handle 2,000 frequency ticks per day across all zones. | 2k/day | `[To be confirmed]` | `[To be confirmed]` Peak rate, how long it is held, and what counts as one tick (per update, zone or feeder). See F-07. | M |
| NFR-04 | Security | Only authenticated staff with a "Transmission Ops" role shall see feeder-level data. | Role-based | `[To be confirmed]` | `[AI SUGGESTED]` Role allowed: "Transmission Ops". Role refused: every other role and any unauthenticated user. See F-11. | T |
| NFR-05 | Auditability | Every shed, restore, and acknowledgement shall record who, when, and what action was taken. | Full trace | `[To be confirmed]` | Fields recorded: who, when, what action (from the requirement). | T |
| NFR-06 | Usability | A shift lead shall be able to answer "is my zone healthy right now?" in under 5 seconds. | ≤5 s | `[To be confirmed]` | `[To be confirmed]` Number of shift-lead participants; task is the question quoted; time limit P-17. | H |
| NFR-07 | Compliance | The system shall comply with the reliability council's 2027 reporting requirement. | Full | `[To be confirmed]` | Sign-off by `[To be confirmed]`; the reporting format is Q-03. | J |
| NFR-08 | Recoverability | The system shall restore service within 15 minutes of a failure, with no loss of event log rows. | ≤15 min, zero loss | `[To be confirmed]` | `[AI SUGGESTED — needs confirmation]` Failure simulated by `[To be confirmed]`; measured from failure to service restored; no event log row may be lost. | M |

---

## 9. User journeys

*Journey text is from version 1.0. The "Requirement IDs exercised" lines are `[AI SUGGESTED]`.*

### 9.1 Journey: Morning peak — spotting a frequency event
- **Trigger:** At 07:42 during the morning bank, system frequency falls to 49.70 Hz on Zone 2.
- **Steps:** The system detects the drop → sees that Zone 2's feeder INT-14 is interruptible → raises a shed → opens the feeder → appends a SHED row to the event log → enqueues an RTU command → the RTU acknowledges → the shift lead sees the shed on her screen → she records her action.
- **Outcome:** Reserve MW moved to the shed register, the RTU confirmed, and the shift lead has a full record.
- **Failure path:** If the RTU does not acknowledge within 2 seconds, the system retries once. If the retry also fails, the shed stays on the shift lead's screen and is escalated.
- **Requirement IDs exercised:** `[AI SUGGESTED]` FR-01, FR-03, FR-06, FR-07, FR-13, FR-14, DR-01, DR-02, BR-02, BR-05, AR-02, NFR-05.

### 9.2 Journey: Protected feeder — hospital
- **Trigger:** At 14:12, frequency falls to 49.65 Hz. The worst-affected feeder is HOSP-1, a hospital supply.
- **Steps:** The system reads the feeder → sees that HOSP-1 is on the protected register → raises a warning, not a shed → appends a WARN row → the shift lead sees the warning and decides whether to authorise a shed explicitly.
- **Outcome:** The hospital feeder is protected by default; the shift lead has the authority to override.
- **Failure path:** If the shift lead does not acknowledge within 15 minutes, the warning escalates to the duty manager. The hospital feeder is never auto-shed.
- **Requirement IDs exercised:** `[AI SUGGESTED]` FR-02, FR-04, FR-05, BR-01, BR-03, AR-02. The authorisation step and the duty manager escalation have no requirement (F-02, F-04).

### 9.3 Journey: Morning reliability council report
- **Trigger:** 08:00, Chen opens his laptop.
- **Steps:** He opens the daily report → sees yesterday's events, sheds, restores, and acknowledgements per zone → exports it as a PDF → sends it to the reliability council before 09:00.
- **Outcome:** Report delivered on time, no manual work, with an unmodifiable audit trail behind it.
- **Failure path:** If the report fails, he falls back to the old manual process for one day.
- **Requirement IDs exercised:** `[AI SUGGESTED]` FR-10, AR-01, AR-02, BR-04, NFR-07. The PDF export and the 08:00 and 09:00 times have no requirement (F-13).

---

## 10. Acceptance criteria

*AC-01 to AC-08 are the version 1.0 criteria, wording unchanged. Their "Covers" and class are `[AI SUGGESTED]`. AC-09 to AC-14 are new, `[AI SUGGESTED]`, and exist so that every Must requirement is covered by at least one criterion.*

| ID | Criterion (Given / When / Then, with tolerance) | Covers (requirement IDs) | Method of verification (class) |
|---|---|---|---|
| AC-01 | Every frequency tick is visible within 1 second of the SCADA update. | FR-01, NFR-01 | Live test during a peak hour — M |
| AC-02 | Sheds, warnings, and holds are correct for 100% of scripted test cases. | FR-02, FR-03, FR-04, BR-01 | Scripted test with 50 known events — T |
| AC-03 | No shed is raised twice in a row for the same feeder and event. | FR-06, BR-02 | Scripted test with repeated identical ticks — T |
| AC-04 | Every shed can be acknowledged and restored. | FR-07, FR-12 | Demo with shift leads — H |
| AC-05 | The daily report matches a manual count for a full day. | FR-10, AR-01 | Side-by-side comparison — H |
| AC-06 | The event log cannot be modified after the fact, by any user. | BR-04, AR-02 | Inspection by Safety & Compliance — I |
| AC-07 | The reserve invariant `reserve + shed == 800` holds after every shed and restore. | BR-05, FR-14, FR-12 | Scripted test across shed and restore — P |
| AC-08 | The system runs for 30 days with 99.9% availability and zero event log loss. | NFR-02, NFR-08 | Monthly service report — M |
| AC-09 | `[AI SUGGESTED]` **Given** the system is running, **when** the shift lead adds a feeder to, then removes it from, the protected register, **then** the next qualifying tick is a warning, then a shed, with no restart. | FR-05 | Scripted test — T |
| AC-10 | `[AI SUGGESTED]` **Given** an RTU that does not acknowledge, **when** a shed command is sent, **then** it is retried once after P-09, and after a second failure the shed remains visible and escalated. | FR-13 | Scripted test with a first-attempt failure and a double failure — T |
| AC-11 | `[AI SUGGESTED]` **Given** valid and invalid ticks, sheds and restores, **when** they are recorded, **then** the fields named in DR-01, DR-02 and DR-03 are held, and ticks missing area or feeder are rejected and not recorded. | DR-01, DR-02, DR-03, DR-06 | Scripted test — T |
| AC-12 | `[AI SUGGESTED]` **Given** the retention settings, **when** they are inspected, **then** the event log is kept for P-11 and the reserve register for P-12. | DR-04, DR-05 | Inspection of configuration by a named reviewer `[To be confirmed]` — I |
| AC-13 | `[AI SUGGESTED]` **Given** a shed with no acknowledgement or restore, **when** P-07 elapses, **then** the FR-08 alert is raised once; **given** an acknowledgement or restore before P-07, **then** no alert is raised. | BR-03, FR-08 | Scripted test with controlled time — T |
| AC-14 | `[AI SUGGESTED]` **Given** open sheds in several zones, a note added to an event, and users with and without the "Transmission Ops" role, **when** each acts, **then** all open sheds are listed, the note is retained with who and when, and only the "Transmission Ops" role sees feeder-level data. | FR-09, FR-11, NFR-04, NFR-05 | Scripted test — T |

### 10.1 Verification classes

| Class | Meaning | Counts as verified when |
|---|---|---|
| **T** | Check with a fixed expected result (a truth table, a boundary case) | The check ran and passed; the run is recorded |
| **P** | Property or invariant over many generated inputs | The property held over the stated number of cases |
| **M** | Measured against a target (load, availability, recovery) | Measured under stated conditions and met the target |
| **I** | Inspection of design, configuration, or code | A named reviewer recorded the result |
| **H** | Human trial or walkthrough | The trial ran with the stated participants and met the target |
| **J** | Judgment; cannot be reduced to a check | Never "verified". A named person accepts it, with a review date |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood (H/M/L) | Impact (H/M/L) | Mitigation |
|---|---|---|---|---|
| R-01 | SCADA feed is slower than promised. | M | H | Early technical trial with SCADA team before full build. |
| R-02 | Shift leads find the screen too crowded. | M | M | Co-design workshops with shift leads from week 1. |
| R-03 | Protected register is out of date for some feeders. | M | H | Monthly review with network operations; register is live and editable. |
| R-04 | RTU connectivity is unreliable at some substations. | M | M | Retry-once built in; escalate on second failure. |
| R-05 | Reliability council rejects the audit trail as insufficient. | L | H | Early review with council liaison before build. |

---

## 12. Success measures

*"Matching requirement (ID)" was added in the upgrade and is `[AI SUGGESTED]`. A dash means no requirement carries the target (F-14).*

| Measure | Baseline today | Target | Matching requirement (ID) | Reviewed when |
|---|---|---|---|---|
| Time from frequency event to shed action | 45 s | 30 s | — (P-19 has no requirement; F-14) | 3 months after go-live |
| Sheds involving a protected feeder per 1,000 events | 20 | 0 | BR-01, FR-04 (target 0 against BR-01's authorised case — F-02) | 3 months after go-live |
| Daily reliability council report preparation time | 90 min | 5 min | FR-10, AR-01 (no time target in either — F-14) | 1 month after go-live |
| Shift lead satisfaction with visibility | 2.6 / 5 | 4.0 / 5 | — (judgment; F-14) | 3 months after go-live |

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

*Q-01 to Q-04 are from version 1.0; their "Blocks" column is `[AI SUGGESTED]`. Q-05 to Q-23 were raised by the upgrade review. Owners and due dates for those are `[To be confirmed]` because nobody has been named.*

| ID | Question | Owner | Due date | Blocks (IDs) | Status |
|---|---|---|---|---|---|
| Q-01 | What is the exact escalation path when a shed is not acknowledged within 15 minutes? | System Ops | 2026-10-15 | FR-08, BR-03, FR-13, P-08 | Open |
| Q-02 | Should the protected register be per-zone or per-feeder across the whole control area? | Network Operations | 2026-10-20 | FR-04, FR-05, BR-01, P-04 | Open |
| Q-03 | What is the reliability council's exact reporting format for phase 1? | Council Liaison | 2026-10-25 | FR-10, AR-01, NFR-07, P-23 | Open |
| Q-04 | Which feeders are on the protected register at go-live? | Network Operations | 2026-11-01 | P-04, FR-04, AC-02 | Open |
| Q-05 | F-01: Confirm the precedence draft in 7.6, the relative order of rows 1 to 3, and whether every matching reason is recorded. | `[To be confirmed]` | `[To be confirmed]` | FR-02, FR-03, FR-04, FR-06, FR-14, BR-01, BR-02, BR-05 | Open |
| Q-06 | F-02: When the shift lead explicitly authorises a shed of a protected feeder, what must the system do and record, and is that shed excluded from the "protected feeder sheds" success measure? | `[To be confirmed]` | `[To be confirmed]` | BR-01, FR-04, DR-02 | Open |
| Q-07 | F-03: What is "the same event" (a time window, a continuous excursion, a counter)? Does BR-02 apply across events while a feeder is still shed? | `[To be confirmed]` | `[To be confirmed]` | FR-06, BR-02, AC-03 | Open |
| Q-08 | F-04: Does the 15-minute rule apply to a warning as well as a shed? Is BR-03 (Must) meant to be enforced by FR-08 (Should)? Who is the duty manager, and is that role a stakeholder? | `[To be confirmed]` | `[To be confirmed]` | BR-03, FR-08, journey 9.2 | Open |
| Q-09 | F-05: How many megawatts does each feeder shed, and where does that figure come from? | `[To be confirmed]` | `[To be confirmed]` | FR-12, FR-14, DR-02, DR-03, P-06 | Open |
| Q-10 | F-06: Is the reserve baseline 800 MW (AC-07) or 200 MW (interruptible, 3.1)? Which figure does the reserve register hold? | `[To be confirmed]` | `[To be confirmed]` | BR-05, FR-14, AC-07, P-05 | Open |
| Q-11 | F-07: Is 2,000 ticks per day right when SCADA reports at least every second? What counts as one tick, and what are the peak rate and how long it is held? | `[To be confirmed]` | `[To be confirmed]` | NFR-03, P-15 | Open |
| Q-12 | F-08: For NFR-01, NFR-02, NFR-06 and NFR-08, what are the percentile, window, sample, participants and start and end points? Should the 00:00–04:00 gap in NFR-02 stand? | `[To be confirmed]` | `[To be confirmed]` | NFR-01, NFR-02, NFR-06, NFR-08, AC-01, AC-08 | Open |
| Q-13 | F-09: Which requirement makes the council's view read-only and the log unmodifiable? Is "by any user" (AC-06) intended, given BR-04 covers only the council's view? | `[To be confirmed]` | `[To be confirmed]` | BR-04, AC-06 | Open |
| Q-14 | F-10: What happens to event log rows after 24 months, given the log must not be modified? | `[To be confirmed]` | `[To be confirmed]` | DR-04, BR-04, AC-06, P-11 | Open |
| Q-15 | F-11: May the Reliability Council, Safety & Compliance and the Council Liaison see feeder-level data in the event log despite NFR-04? | `[To be confirmed]` | `[To be confirmed]` | NFR-04, AR-02, BR-04 | Open |
| Q-16 | F-12: What must happen when a shed is rejected under FR-14, when both RTU attempts fail (is the megawatt count kept in the shed register), and when a restore is requested for a feeder that is not shed? | `[To be confirmed]` | `[To be confirmed]` | FR-12, FR-13, FR-14, AC-07 | Open |
| Q-17 | F-13: Is PDF export, availability by 08:00 and the 09:00 send a requirement? How is "average response time" measured, and where does the report day begin and end? | `[To be confirmed]` | `[To be confirmed]` | FR-10, AR-01, AC-05 | Open |
| Q-18 | F-14: Which requirement carries the 30-second shed-action target, the 5-minute report preparation target and the satisfaction target? | `[To be confirmed]` | `[To be confirmed]` | section 12, P-19 | Open |
| Q-19 | F-15: Does FR-12 mean the system returns megawatts when the operator confirms the restore, so that restoration stays an operator decision (4.2)? | `[To be confirmed]` | `[To be confirmed]` | FR-12 | Open |
| Q-20 | F-16: When frequency is below P-02 for a whole zone, which interruptible feeders are shed, how many, and in what order? What does "worst-affected feeder" mean? | `[To be confirmed]` | `[To be confirmed]` | FR-03, DR-01, journeys 9.1, 9.2 | Open |
| Q-21 | F-17: What is the smallest step between two frequency readings? | SCADA team | `[To be confirmed]` | P-03, FR-02, FR-03 | Open |
| Q-22 | Confirm the priorities proposed for AR-01 and AR-02, and give a priority for NFR-01 to NFR-08. | `[To be confirmed]` | `[To be confirmed]` | AR-01, AR-02, NFR-01 to NFR-08 | Open |
| Q-23 | Confirm every `[AI SUGGESTED]` acceptance criterion, class and covers entry in sections 7, 9, 10 and 12, the new AC-09 to AC-14, and give P-24. | `[To be confirmed]` | `[To be confirmed]` | all requirement rows, P-24 | Open |

### 14.1 Consistency checks (complete before approval)

*Left unticked. Each line names the findings that stop it being ticked. A finding is **Blocking** when no check can be written, and **Clarify** when a check can be written but might test the wrong thing.*

- [ ] No two requirements or rules contradict each other. — F-10, F-11, F-15
- [ ] Where several rules can apply to one case, section 7.6 says which wins. — F-01
- [ ] Every number a requirement relies on is in the parameter register (7.5), with a value or an owner. — F-05, F-17; owners still `[To be confirmed]` on most rows
- [ ] Every rule that must hold has a stated behavior for when it would be broken. — F-04, F-12
- [ ] Every rule in 7.3 is enforced by at least one requirement in 7.1. — F-02 (BR-01 authorised case), F-04 (BR-03 and FR-08 priorities differ), F-09 (BR-04)
- [ ] Every journey step agrees with the requirements it exercises, including who acts. — F-02, F-04, F-13, F-16
- [ ] The same measure does not have two different targets in two sections. — F-06, F-07, F-14
- [ ] Every target in section 8 says how it is measured. — F-07, F-08
- [ ] Every requirement table has a priority, an acceptance criterion, and a class on every row. — Q-22 (NFR priorities), Q-23 (criteria are drafts)

### 14.2 Findings from the template 2.0 upgrade review (reported, not fixed)

| ID | Check | IDs involved | Finding | Severity | Question |
|---|---|---|---|---|---|
| F-01 | Precedence | FR-02, FR-03, FR-04, FR-06, FR-14, BR-01, BR-02, BR-05 | One tick can match several rules (a reading of 49.75 Hz is below both thresholds; a protected feeder can also be already shed or have no reserve). No winner is stated. A draft is in 7.6. | Clarify | Q-05 |
| F-02 | Orphan rule | BR-01, FR-04, FR-05, DR-02, journey 9.2, section 12 | BR-01 allows a shed of a protected feeder with explicit shift-lead authorisation, and 9.2 describes the step, but no requirement covers the authorisation or what is recorded. The success target of 0 protected-feeder sheds sits against that allowance. The default behavior (never shed without authorisation) can be checked. | Clarify | Q-06 |
| F-03 | Contradiction | BR-02, FR-06, AC-03 | BR-02 forbids any shed for a feeder already shed. FR-06 and AC-03 forbid a second shed only "for the same event". "Event" has no definition, so the two can disagree when a new event starts while a feeder is still shed. | Clarify | Q-07 |
| F-04 | Journey mismatch | BR-03, FR-08, journeys 9.1, 9.2, Q-01 | BR-03 is Must and covers a shed that is "acknowledged or restored"; FR-08 is Should and covers a shed "without acknowledgement". Journey 9.2 applies 15 minutes to a warning and escalates to a "duty manager", who is not in section 5 or 6. Journey 9.1 escalates a failed retry to an unnamed party. | Clarify | Q-01, Q-08 |
| F-05 | Missing value | FR-12, FR-14, DR-02, DR-03 | No requirement or parameter says how many megawatts a feeder sheds or where the figure comes from. A check cannot state the expected reserve after a shed. | **Blocking** | Q-09 |
| F-06 | Target mismatch | AC-07, 3.1, glossary | AC-07 holds `reserve + shed == 800`. Section 3.1 gives 800 MW as firm demand and 200 MW as interruptible, and the glossary defines the reserve register as megawatts that can be shed. | Clarify | Q-10 |
| F-07 | Target mismatch / measure basis | NFR-03, 4.3 | 2,000 ticks per day conflicts with a SCADA feed at least every 1 second (86,400 or more per day for one feed). "Tick" is not counted per zone or feeder, and no peak rate or hold time is given. | **Blocking** | Q-11 |
| F-08 | Measure basis | NFR-01, NFR-02, NFR-06, NFR-08 | No percentile, sample or start and end point for NFR-01; no definition of "available" or period in NFR-02 (AC-08 gives 30 days); no participants in NFR-06; no failure method in NFR-08. NFR-02 leaves 00:00–04:00 without a target. | Clarify | Q-12 |
| F-09 | Orphan rule | BR-04, AC-06 | No requirement in 7.1 or 7.2 makes the council's view read-only or the log unmodifiable. AC-06 says "by any user", which is wider than BR-04. | Clarify | Q-13 |
| F-10 | Contradiction | DR-04, BR-04, AC-06 | A 24-month retention implies rows end at some point; the log must also never be modified or deleted. What happens at 24 months is not stated. | Clarify | Q-14 |
| F-11 | Contradiction | NFR-04, AR-02, BR-04, 6.3 | NFR-04 lets only the "Transmission Ops" role see feeder-level data. AR-02 and BR-04 give the council, Safety & Compliance and the liaison a view of the event log, which holds feeders. | Clarify | Q-15 |
| F-12 | Missing behavior | FR-12, FR-13, FR-14, BR-05, AC-07 | Not stated: what the operator sees and what is logged when FR-14 rejects a shed; whether megawatts stay in the shed register after both RTU attempts fail (this decides if AC-07 holds); what a restore of a feeder that is not shed does. | Clarify | Q-16 |
| F-13 | Journey mismatch | FR-10, AR-01, journey 9.3 | Journey 9.3 has a PDF export, a report ready by 08:00 and a send before 09:00; no requirement says so. "Average response time" in AR-01 has no start or end point, and the report day has no boundary. | Clarify | Q-17 |
| F-14 | Target mismatch | section 12, 3.2, FR-10, AR-01 | The 30-second response target (3.2, section 12), the 5-minute report preparation target and the satisfaction target have no matching requirement or NFR. | Clarify | Q-18 |
| F-15 | Contradiction | FR-12, 4.2, 3.1 | FR-12 says the system "automatically" restores; 4.2 says restoration is always an operator decision; 3.1 says restore is deliberate. They agree if the operator's acknowledgement is the trigger. | Clarify | Q-19 |
| F-16 | Missing rule | FR-03, DR-01, journeys 9.1, 9.2 | Frequency is a whole-area measurement, but a shed is per feeder. Nothing says which interruptible feeders are shed, how many, or in what order; 9.2 refers to a "worst-affected feeder". | Clarify | Q-20 |
| F-17 | Missing value | FR-02, FR-03, P-03 | The step between two frequency readings is not given, so "just below the threshold" cannot be given a value. | Clarify | Q-21 |

Totals: 17 findings — 2 Blocking (F-05, F-07), 15 Clarify.

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (COO) | `[name]` | | |
| Product owner (Head of System Ops) | `[name]` | | |
| Technical lead (SCADA / EMS) | `[name]` | | |
| Compliance / risk | `[name]` | | |

### 15.1 Residual acceptance (completed after the build)

*Class J requirements always appear. No acceptance has been given; none is recorded here on anyone's behalf.*

| Requirement ID | Why it remains | Accepted by | Date | Review by |
|---|---|---|---|---|
| NFR-07 | Class J (judgment); never verified, only accepted | | | |

---

## Appendix A. Residual ledger

`grid-demand-response-LEDGER.md` — not yet written. It is produced after the build from the `grid-demand-response-test.dart` report.

## Appendix B. Orphan behavior register

| Behavior | Where | Serves requirement? | Disposition (add / remove / accept) | Decided by |
|---|---|---|---|---|
| | | | | |

---

*End of document.*
