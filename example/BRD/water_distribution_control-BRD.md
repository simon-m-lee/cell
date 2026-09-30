# Business Requirements Document (BRD)

## Municipal Drinking Water Distribution

| Field | Value |
|---|---|
| Project name | Clean Water Desk |
| Document title | Business Requirements — Municipal Drinking Water Distribution Control |
| Version | 1.0 |
| Date | 2026-10-01 |
| Author | Network Operations Programme Office |
| Reviewer(s) | Head of Treated Water, Network Control Manager, Public Health Liaison |
| Approver(s) | Chief Operating Officer, Head of Safety & Compliance, Senior Information Risk Owner |
| Status | Approved |

**Revision history**

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | 2026-09-08 | Network Ops Programme Office | First draft after August burst-and-residual incident review |
| 1.0 | 2026-10-01 | Network Ops Programme Office | Approved after review with Treated Water, Control, and Public Health |

---

## 2. Executive summary

Every day our treated-water network moves drinking water from four treatment works through 18 service reservoirs and 240 district meter areas to about 1.2 million people. When a main bursts, a chlorine residual falls, or a reservoir drops faster than demand can explain, the first people who usually hear about it are customers on the phone, a hospital estates desk, or the Drinking Water Inspectorate after the fact. We need a simple tool that watches pressure, residual, and reservoir stock in real time, flags a zone before it becomes a boil-water conversation, protects sites we must never isolate without authorisation, and gives the network controller one clear view of what is happening right now plus an audit trail Public Health and the Inspectorate can read but not change. This document sets out what that tool must do, for whom, and how we will know it is working.

---

## 3. Business context

### 3.1 Background
This water-only company supplies a mixed urban and rural region. Peak summer demand is around 280 megalitres per day. Each district meter area (DMA) reports flow, pressure, and — where an online analyser is fitted — free-chlorine residual. Company operating practice treats **15 metres residual head** as the point at which a DMA is fragile for upstairs taps and dialysis machines, and **a free-chlorine residual at or below 0.20 mg/L for more than 10 minutes**, or **a reservoir falling more than 8% in 30 minutes with no planned draw-down**, as the point at which the controller must treat the zone as at risk of a water-quality or loss-of-supply event. A burst that leaves a hospital, renal unit, or school without wholesome water is a notifiable event. Isolation of a protected site without the Duty Manager and Public Health is a disciplinary and regulatory matter.

### 3.2 Problem statement
Right now the picture lives on three surfaces: the telemetry wall in the control room, the work-management system the find-and-fix gangs use, and a spreadsheet of “sensitive customers” that is updated on Fridays. The night controller learns a residual has collapsed when a customer reports chlorine taste has gone, or when a hospital estates manager calls because a dialysis loop is alarming. By then two adjacent DMAs may already have been backfed through a dirty main. We estimate that around 1 in 80 burst or residual events last year reached Public Health later than it should have, and that the average time from the first bad analyser reading to a controller action is 38 minutes — against a 10-minute internal target — with no single record of who isolated what, and whether a protected site sat on that valve.

### 3.3 Business drivers
- **Public health.** Low residual and uncontrolled isolation are how contamination and loss of supply reach people who cannot boil water or wait.
- **Regulatory pressure.** The Drinking Water Inspectorate requires a documented, auditable event timeline. Ofwat’s performance commitments on supply interruptions and contacts about drinking water quality are already in the penalty zone for two DMAs.
- **Security of supply.** Treatment works, reservoirs, and valve chambers are critical national infrastructure. An unauthorised isolation or a telemetry outage during a vandalism or cyber event must be visible as itself, not as “the screen went quiet”.
- **Staffing pressure.** Night control is two people covering the whole region. They need one screen that names the DMA, the residual, the pressure, and whether a protected site is on the affected main — not another wall.

### 3.4 Alignment with strategy
The company’s 2025–2030 network strategy names “real-time treated-water visibility” as one of four pillars, alongside leakage, smart metering, and security of the control estate. This project is a first, concrete step. It does not replace the telemetry system, the work-management system, or the laboratory information system.

---

## 4. Scope

### 4.1 In scope
- Real-time monitoring of pressure, flow, reservoir level, and free-chlorine residual for every DMA and service reservoir in the region.
- A single network-controller view of open water-quality and loss-of-supply incidents.
- Automatic alerts when a DMA crosses the at-risk pressure or residual rule, or when a reservoir draw-down looks unplanned.
- A protected-site register (hospitals, renal units, schools, food premises on the current sensitive-customer list) that control maintains and that isolation decisions must honour.
- A record of every alert, every isolation, every restore, and every acknowledgement, in an append-only log.
- A daily event summary for Public Health and the Drinking Water Inspectorate liaison.

### 4.2 Out of scope
- Raw-water catchments and abstraction licensing.
- Replacing telemetry, SCADA, or the laboratory information system.
- Automatic closing of valves or automatic shutdown of a treatment works. Controllers and the Duty Manager still decide.
- Customer-facing outage maps or SMS in this phase (the existing comms team process stays).
- Wastewater / sewerage (this company is water-only).
- Other company regions or bulk-supply partners in this phase.

### 4.3 Assumptions
- Telemetry can emit a DMA / reservoir snapshot at least every 60 seconds for pressure and flow, and every 120 seconds for online residual.
- Each DMA, reservoir, and analyser has a stable asset identifier that matches the GIS and the work-management system.
- The sensitive-customer / protected-site list can be loaded at the start of each shift and updated by the Duty Manager without a software release.
- Controllers will use the tool on the existing control-room workstations and on the on-call laptop.
- Public Health England / UKHSA and the local authority already have a named out-of-hours contact for boil-water and do-not-drink conversations.

### 4.4 Constraints
- No new analysers or pressure loggers in this phase.
- Must be usable on the night desk before the 2027 summer peak.
- Must use the existing single sign-on and the existing control-room role model.
- Must not write set-points back into SCADA. This tool watches and records; it does not drive valves.
- Must not store customer names, addresses, or account numbers. Protected sites are named by site type and asset ID only.
- Budget capped at the amount approved in the Q2 board paper on operational visibility.

### 4.5 Dependencies
- Telemetry snapshot feed (OT / Telemetry team).
- Protected-site list extract without personal data (Customer / Public Health liaison).
- Work-management job numbers so an isolation can be tied to a gang (Network Maintenance).
- DWI daily-return column agreement (Regulation team).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
|---|---|---|---|---|
| Sponsor | Chief Operating Officer | Events, reputation, Inspectorate standing | H | Monthly steering |
| Primary user | Network Controllers (day and night) | One view, earlier isolation conversation | H | Weekly workshops |
| Primary user | Duty Managers | Authorise isolation of a protected site | H | Weekly workshops |
| Reviewer | Public Health / UKHSA liaison | Timely, accurate event notice | M | Bi-weekly review |
| Reviewer | Senior Information Risk Owner / Security | No extra identifiable store; OT boundary | M | Sign-off before go-live |
| Regulator | Drinking Water Inspectorate / Ofwat | Auditable event timeline | L | Quarterly update |

---

## 6. Users and personas

### 6.1 Network Controller — Anika
- **Role:** Night network controller, 19:00–07:00, covering all four works and 240 DMAs.
- **Context:** Two-person desk. Radio, telemetry wall, work-management, and the on-call Duty Manager’s mobile. A typical night has two bursts and a handful of analyser spikes.
- **Goal:** Know within two minutes when a DMA’s residual or pressure crosses the line, and know whether a hospital or renal unit sits on that main.
- **Pain today:** Learns residual has gone when a customer rings at 02:10, or when the hospital estates desk calls. Has to flip three screens to see if the adjacent DMA was already isolated.
- **Success looks like:** One screen shows residual, pressure, reservoir trend, open isolations, and every protected site on the affected DMA.

### 6.2 Duty Manager — Owen
- **Role:** On-call Duty Manager for treated water, seven-day rota.
- **Context:** At home after 20:00 with a laptop and a phone. Authorises isolation of a protected site and the call to Public Health.
- **Goal:** See the same incident the controller sees, with the valve, the megalitres at risk, and the protected-site count, before he takes the Public Health call.
- **Pain today:** Receives a verbal briefing. Reconstructs the timeline the next morning from radio logs.
- **Success looks like:** An alert names the DMA, the residual, the minutes below threshold, and whether a protected site is involved. He acknowledges with the authorisation decision recorded.

### 6.3 Regulation Liaison — Mei
- **Role:** Daily contact for the Drinking Water Inspectorate and the local Public Health team.
- **Context:** Office-based. Builds yesterday’s event pack every morning when anything notifiable happened.
- **Goal:** A one-page summary: events, isolations, restores, minutes below residual, protected sites touched, time to first acknowledgement — no customer names.
- **Pain today:** Pulls telemetry screenshots, a work-management export, and a voicemail from night control. Takes 80 minutes and still misses who authorised the valve.
- **Success looks like:** Opens a report, sends it, done. The Inspectorate view cannot delete a row.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-01 | The system shall show, in real time, pressure, flow, reservoir level, and free-chlorine residual for every DMA and service reservoir. | Must | Core purpose of the tool. |
| FR-02 | The system shall calculate, for every DMA, minutes spent below the pressure or residual threshold. | Must | Needed to know which zones are at risk. |
| FR-03 | The system shall flag a DMA as “at risk” when residual head is at or below 15 m, or when free chlorine is at or below 0.20 mg/L for more than 10 minutes. | Must | Consistent rule across shifts. |
| FR-04 | The system shall flag a reservoir as “at risk” when level falls more than 8% in 30 minutes with no planned draw-down recorded. | Must | Unplanned emptying is a burst or a wrong valve. |
| FR-05 | The network controller shall be able to see all at-risk DMAs and reservoirs on a single screen. | Must | One screen, one view. |
| FR-06 | The system shall raise a warning when three or more adjacent DMAs are at risk at the same time. | Must | That pattern is how a dirty backfeed starts. |
| FR-07 | The system shall show, for each alert, the DMA or reservoir, the residual and pressure, minutes below threshold, and the count of protected sites on that asset. | Must | Give the controller enough to act. |
| FR-08 | The controller or Duty Manager shall be able to acknowledge an alert and record the action taken, including isolate, flush, sample, restore, or escalate to Public Health. | Must | Audit trail of the event. |
| FR-09 | The system shall refuse to record an isolation against a protected site unless the Duty Manager has acknowledged that isolation. | Must | Protected-site rule. |
| FR-10 | The Duty Manager shall be able to add or remove a site from the protected register while the system is running. | Must | Live policy — a new renal unit cannot wait for a release. |
| FR-11 | The system shall not raise a second at-risk alert for the same DMA and same cause until the first alert is acknowledged or closed. | Must | Prevent alert fatigue on a noisy analyser. |
| FR-12 | The controller shall be able to see all open water-quality and loss-of-supply incidents across the region. | Should | Whole-network awareness. |
| FR-13 | The system shall group individual analyser spikes into a single incident when they share the same DMA and cause. | Should | Prevent alert fatigue. |
| FR-14 | The system shall produce a daily event summary for Public Health and the Inspectorate liaison. | Must | External reporting requirement. |
| FR-15 | The system shall allow the Duty Manager to add a free-text operational note to any incident. Notes shall not contain customer names or addresses. | Should | Context for the notifiable-event pack. |
| FR-16 | The system shall allow the Duty Manager to export the day’s incidents as a spreadsheet without personal data. | Could | Ad-hoc Inspectorate or Ofwat requests. |
| FR-17 | The system shall raise an escalation when an at-risk alert has not been acknowledged within 10 minutes. | Must | Night-desk service level. |
| FR-18 | The system shall record restore of an isolation only when the controller acknowledges restore, and shall put the megalitres back against the reservoir stock picture. | Must | Close the loop. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | The system shall capture for every tick: asset ID, DMA or reservoir, pressure (m head), flow (L/s), free chlorine (mg/L) where fitted, reservoir % full, planned-draw-down flag. | Must | Minimum dataset for the desk. |
| DR-02 | The system shall capture for every incident: start time, end time, asset, cause code, residual and pressure at raise, protected-site count, actions, who acknowledged, who authorised if a protected site was involved. | Must | Audit and reporting. |
| DR-03 | The system shall capture for every isolation and restore: valve or job number, megalitres affected, start and end, acknowledger. | Must | Event timeline. |
| DR-04 | The system shall retain incident records for 5 years. | Must | Drinking Water Inspectorate event files. |
| DR-05 | The system shall retain high-frequency tick history for 14 days. | Must | Enough for a burst reconstruction. |
| DR-06 | The system shall reject a tick with a missing asset ID or a residual value outside 0.00–5.00 mg/L. | Must | Data quality at the source. |
| DR-07 | The system shall not persist customer names, addresses, account numbers, or occupier telephone numbers. Protected sites are site type plus asset ID only. | Must | Data protection and security of the sensitive-customer list. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | A protected site (hospital, renal unit, school, listed food premises) shall never be recorded as isolated without explicit Duty Manager acknowledgement. | Company policy / public health | Must |
| BR-02 | No new at-risk alert may be raised for a DMA that is already in an open incident for the same cause. | Operational practice | Must |
| BR-03 | Every at-risk alert must be acknowledged or escalated within 10 minutes. | Service level | Must |
| BR-04 | The Inspectorate and Public Health view of the event log shall be read-only and shall not permit deletion of any row. | Regulatory | Must |
| BR-05 | Reservoir stock shown on the desk shall not be driven below zero by an isolation record. | Network safety | Must |
| BR-06 | Event packs shared outside the company shall exclude customer personal data and the full sensitive-customer list. | Data protection / security | Must |
| BR-07 | A telemetry silence longer than 3 minutes on a DMA that was reporting shall itself raise a warning. Quiet is not “healthy”. | Security of supply | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|---|
| AR-01 | The daily event summary shall show, per works / zone: events, isolations, restores, minutes below residual, minutes below pressure, protected sites touched, median time to acknowledgement. | Public Health, DWI liaison | Daily | 5 years |
| AR-02 | The incident log shall show every incident with timings, actions, and acknowledgements. | Controllers, Duty Managers, Safety & Compliance, Inspectorate | On demand | 5 years |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | The screen shall update within 5 seconds of a telemetry snapshot. | 5 s |
| NFR-02 | Availability | The system shall be available 99.9% of the time, all hours. Water does not keep office hours. | 99.9% |
| NFR-03 | Capacity | The system shall handle 400,000 ticks per day across DMAs, reservoirs, and analysers. | 400k/day |
| NFR-04 | Security | Only authenticated staff with a “Treated Water Control” role shall see DMA-level live data. The Inspectorate role is read-only. | Role-based |
| NFR-05 | Security | The tool shall not sit on the OT network and shall not be able to send a valve command. | One-way watch |
| NFR-06 | Auditability | Every alert acknowledgement, isolation, restore, and protected-site change shall record who, when, and what action was taken. | Full trace |
| NFR-07 | Usability | A controller shall be able to answer “is my region wholesome right now?” in under 10 seconds. | ≤10 s |
| NFR-08 | Compliance | The system shall support UK GDPR, the Security and Emergency Measures Direction, and DWI notifiable-event record-keeping. | Full |
| NFR-09 | Recoverability | The system shall restore the live view within 15 minutes of a failure, with the incident log intact. | ≤15 min |
| NFR-10 | Integrity | A read-only Inspectorate session shall be technically unable to add, edit, or delete an incident row. | Proven in test |

---

## 9. User journeys

### 9.1 Journey: Night burst with a falling residual
- **Trigger:** A 400 mm trunk main fails at 01:14 on the edge of DMA-118. Pressure drops to 11 m; the online analyser in the next DMA reads 0.16 mg/L at 01:21.
- **Steps:** The system flags DMA-118 at risk on pressure at 01:15 → flags the adjacent DMA on residual at 01:31 (10 minutes below 0.20 mg/L) → Anika sees both on one screen with two protected sites on DMA-118 (a district hospital and a renal unit) → she raises a find-and-fix job and does **not** isolate the hospital main → she calls Owen → Owen acknowledges the protected-site constraint and authorises an isolation downstream of the hospital take-off → Anika records isolate + sample + “Public Health informed” → residual recovers after flush.
- **Outcome:** Hospital supply held, dirty backfeed avoided, full timeline for the notifiable-event pack.
- **Failure path:** If nobody acknowledges within 10 minutes, the system escalates to the Duty Manager’s on-call phone. If someone tries to record an isolation on the hospital asset without Owen’s acknowledgement, the system refuses and writes a rejected-action row.

### 9.2 Journey: Unplanned reservoir draw-down
- **Trigger:** Service reservoir SR-07 falls 9% in 22 minutes at 16:40 with no planned draw-down on the shift sheet.
- **Steps:** The system flags SR-07 → the day controller sees the drop and the DMAs fed by that tank → a valve left open after a planned shutdown is found → restore is acknowledged → stock picture returns.
- **Outcome:** Emptying stopped before the tank hit the low-level alarm. Cause recorded as “valve left open”, not “burst”.
- **Failure path:** If the fall continues and three downstream DMAs go at-risk together, FR-06 raises the multi-DMA warning and the Duty Manager is brought in.

### 9.3 Journey: Telemetry goes quiet
- **Trigger:** DMA-044 stops sending snapshots at 03:02 after a cabinet door alarm at the district meter.
- **Steps:** BR-07 raises a silence warning at 03:05 → Anika treats quiet as a security and operations event, not as “all fine” → a gang is sent → a forced cabinet is found → incident closed as “interference, no water-quality impact”.
- **Outcome:** The gap is in the log. Nobody can later claim the zone was healthy because the screen was blank.
- **Failure path:** If the silence is a known analyser fault already on an open incident, no second alert is raised (BR-02).

### 9.4 Journey: Morning Inspectorate pack
- **Trigger:** 08:00, Mei opens her laptop after a notifiable night.
- **Steps:** She opens the daily summary → sees events, isolations, restores, minutes below residual, protected sites touched, time to acknowledgement → exports a PDF with no customer names → sends it to Public Health and files it for DWI.
- **Outcome:** Pack delivered before 09:00, no reconstruction from radio.
- **Failure path:** If the report fails, she falls back to the old manual pack for one day and logs the failure as an incident against the tool.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | Every live DMA and reservoir is visible within 5 seconds of a telemetry snapshot. | Live test on a weekday peak and a Sunday night |
| AC-02 | At-risk flags match the 15 m / 0.20 mg/L / 10-minute and 8%-in-30-minute rules for 100% of scripted cases. | Scripted test with 40 known ticks |
| AC-03 | A protected-site isolation without Duty Manager acknowledgement is refused and recorded. | Controlled desk test |
| AC-04 | Every alert can be acknowledged with an action code and an optional note. | Demo with night controllers |
| AC-05 | Inspectorate / Public Health role cannot add, edit, or delete a row. | Role test signed by SIRO |
| AC-06 | Daily summary matches a manual count for a full day and contains no customer personal data. | Side-by-side comparison plus DPO inspection |
| AC-07 | A 3-minute telemetry silence on a previously live DMA raises a warning. | Timed test |
| AC-08 | The system runs for 30 days with 99.9% availability and an intact incident log after one planned fail-over. | Monthly service report |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Telemetry snapshot is slower or patchier than 60 seconds in rural DMAs. | M | H | Early trial on the 20 worst-communicating DMAs before full build. |
| R-02 | Protected-site list is stale or still carries addresses. | M | H | Shift-start load from a stripped extract; DPO checks the file shape. |
| R-03 | Controllers treat the tool as a second wall and ignore it when busy. | M | H | Co-design with night desk from week 1; acknowledge is one action, not a form. |
| R-04 | Someone assumes the tool can close a valve. | L | H | Written constraint, no write path to SCADA, acceptance test AC-05-equivalent for commands. |
| R-05 | Analyser drift creates a night of false residual alerts. | M | M | Latch until acknowledge (FR-11); cause code “analyser suspect” without closing the DMA. |
| R-06 | A report pack leaks the sensitive-customer list. | L | H | Site type + asset ID only; export reviewed by Regulation before first live send. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| Time from first bad residual / pressure tick to controller action | 38 min | 10 min | 3 months after go-live |
| Notifiable events where Public Health was told late | 1 in 80 events | 1 in 200 | 6 months after go-live |
| Daily event-pack preparation time after a notifiable night | 80 min | 10 min | 1 month after go-live |
| Protected-site isolations recorded without Duty Manager name | Occurs | Zero | Every month |
| Controller confidence in “is the region wholesome?” | 2.4 / 5 | 4.0 / 5 | 3 months after go-live |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| Analyser | Online instrument that reports free-chlorine residual. |
| At risk | DMA or reservoir that has crossed a pressure, residual, or draw-down rule. |
| DMA | District meter area — a metered pocket of the distribution network. |
| Duty Manager | Senior treated-water manager on call; only role that may authorise isolation of a protected site. |
| DWI | Drinking Water Inspectorate. |
| Free chlorine | Residual disinfectant measured in mg/L. |
| Isolation | Planned or emergency closing of a valve that takes a main or site off supply. |
| Megalitre (Ml) | One thousand cubic metres of water. |
| Network controller | Control-room operator watching treated-water telemetry. |
| Notifiable event | An event that must be reported to the Inspectorate / Public Health under company and DWI rules. |
| Protected site | Hospital, renal unit, school, or listed food premises that must not be isolated without Duty Manager acknowledgement. |
| Residual head | Pressure expressed as metres of water column. |
| Restore | Putting an isolated main or site back on supply and recording it. |
| SCADA / telemetry | The existing operational-technology system that measures the network. This tool does not replace it and does not drive it. |
| Sensitive-customer list | Internal list of sites and people who need extra notice. This project stores site type and asset ID only. |
| Service reservoir | Treated-water storage tank feeding one or more DMAs. |
| SIRO | Senior Information Risk Owner. |
| Wholesome | Water that is safe and legal to drink. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | Which 20 DMAs have no online residual analyser, and what proxy will night control accept for those zones? | Treated Water | 2026-10-20 | Open |
| Q-02 | Is the 8% / 30-minute reservoir rule acceptable to the works managers for tanks that routinely hunt during peak? | Head of Treated Water | 2026-10-15 | Open |
| Q-03 | Which four site types belong on the protected register in phase 1 besides hospitals and renal units? | Public Health liaison | 2026-10-22 | Open |
| Q-04 | What is the approved wording when an isolation is refused because the Duty Manager has not acknowledged? | Ops Programme Office | 2026-10-20 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (COO) | `[name]` | | |
| Product owner (Head of Treated Water) | `[name]` | | |
| Technical lead (IT / OT boundary) | `[name]` | | |
| Compliance / risk (SIRO) | `[name]` | | |
| Public Health liaison | `[name]` | | |

---

*End of document.*
