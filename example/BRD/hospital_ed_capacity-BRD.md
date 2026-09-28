# Business Requirements Document (BRD)

## Hospital Emergency Department Capacity

| Field | Value |
|---|---|
| Project name | ED Board Watch |
| Document title | Business Requirements — Hospital Emergency Department Capacity |
| Version | 1.0 |
| Date | 2026-09-26 |
| Author | Unscheduled Care Programme Office |
| Reviewer(s) | Chief Nurse, ED Clinical Director, Site Operations Manager |
| Approver(s) | Chief Operating Officer, Chief Medical Officer, Caldicott Guardian |
| Status | Approved |

**Revision history**

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | 2026-08-28 | Unscheduled Care Programme Office | First draft after winter-pressures debrief |
| 1.0 | 2026-09-26 | Unscheduled Care Programme Office | Approved after review with ED, Site Ops, and Safeguarding |

---

## 2. Executive summary

Every winter, and increasingly all year, our emergency department fills faster than beds on the wards can be freed. When the department is boarded — patients who have a decision to admit but no ward bed — ambulances queue on the ramp, time-critical patients wait in corridors, and neighbouring trusts have to take our diverted crews. Today the site team learns the department is in trouble from a phone call, a whiteboard photo, or a 12-hour trolley breach already in the national return. We need a simple tool that watches ED capacity in real time, flags a bay or stream before it becomes a diversion, and gives the site operations manager one clear view of what is happening right now. This document sets out what that tool must do, for whom, and how we will know it is working.

---

## 3. Business context

### 3.1 Background
This trust runs one type-1 emergency department serving a catchment of about 420,000 people. On a typical weekday the department sees around 280 attendances; a winter Saturday can exceed 360. The department has 42 trolley / cubicle spaces plus 8 resuscitation bays and a 12-chair minors stream. National operating guidance treats **85% occupancy of trolley spaces** as the point at which flow is fragile, and **95% occupancy or 8 or more patients waiting for a ward bed for more than 60 minutes** as the point at which ambulance diversion must be considered. A crew handed over after 15 minutes is a reportable delay; a 12-hour trolley wait is a serious incident.

### 3.2 Problem statement
Right now capacity lives on three surfaces: the ED whiteboard, the bed-management system, and the ambulance stack on the radio. The site operations manager is often in a different building. By the time diversion is declared, three crews are already on the ramp and two neighbouring EDs have not been warned. We estimate that around 1 in 40 winter attendances spends more than four hours in the department for a reason that would have been visible 30 minutes earlier if occupancy, boarded minutes, and inbound ambulances had sat on one screen.

### 3.3 Business drivers
- **Patient safety.** Corridor care and delayed handover increase the risk of missed deterioration.
- **Regulatory pressure.** NHS England and the integrated care board require a documented, auditable diversion decision and a daily unscheduled-care return.
- **System courtesy.** Neighbouring trusts and the ambulance service need earlier notice, not a cold call at the moment of diversion.
- **Staffing pressure.** The nurse in charge already carries a radio, a whiteboard, and a queue of relatives. They need fewer screens, not more.

### 3.4 Alignment with strategy
The trust’s 2025–2028 urgent and emergency care plan names “real-time site visibility” as a winter-resilience pillar. This project is a first, concrete step. It does not replace the electronic patient record, the bed-management system, or the ambulance computer-aided dispatch feed.

---

## 4. Scope

### 4.1 In scope
- Real-time monitoring of ED occupancy by stream (resus, majors, minors, paediatrics, same-day emergency care).
- A single site-operations view of boarded patients, inbound ambulances, and open capacity incidents.
- Automatic alerts when a stream crosses the at-risk occupancy rule or when ambulance handover delay exceeds the warn threshold.
- A record of every alert and every action taken by the nurse in charge or site team.
- A daily unscheduled-care summary for the integrated care board liaison.

### 4.2 Out of scope
- Inpatient ward bed planning beyond the “ready to leave ED” flag.
- Replacing the electronic patient record or the ambulance CAD system.
- Automatic declaration of ambulance diversion. Clinicians and the site director still decide.
- Patient-facing waiting-time apps or SMS.
- Tracking a patient after they leave the ED footprint.
- Other trust sites (community hospitals, urgent treatment centres) in this phase.

### 4.3 Assumptions
- The ED information system can emit a cubicle / stream occupancy snapshot at least every 60 seconds.
- Each attendance has a unique ED encounter number at booking-in.
- The bed-management system can flag “decision to admit, no bed” with a timestamp.
- The ambulance service feed can provide inbound crew count and minutes-since-arrival on the ramp.
- Site operations already carry a trust-issued tablet on the existing Wi-Fi.

### 4.4 Constraints
- No new hardware in cubicles in this phase.
- Must be usable before the 2026/27 winter declaration window.
- Must use the existing single sign-on and smartcard role.
- Must not write clinical notes into a second record of care.
- Budget capped at the amount approved in the Q2 urgent-care paper.
- Patient-identifiable fields must not appear on the ICB daily extract (UK GDPR / Caldicott).

### 4.5 Dependencies
- ED information system occupancy feed (Digital / ED admin).
- Bed-management “decision to admit” flag (Site operations / digital).
- Ambulance inbound / handover feed (Ambulance service liaison).
- ICB daily-return column agreement (Performance team).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
|---|---|---|---|
| Sponsor | Chief Operating Officer | Flow, reputation, winter assurance | H | Monthly steering |
| Primary user | Site Operations Managers | One view, earlier diversion conversation | H | Weekly workshops |
| Primary user | ED Nurse in Charge | Faster response to a boarding stream | H | Weekly workshops |
| Reviewer | ICB Unscheduled Care Liaison | Reporting accuracy | M | Bi-weekly review |
| Reviewer | Safeguarding / Caldicott | No extra identifiable store | M | Sign-off before go-live |
| Regulator | NHS England regional ops / CQC inspection pack | Auditable diversion decisions | L | Quarterly update |

---

## 6. Users and personas

### 6.1 Site Operations Manager — Helen
- **Role:** On-call site manager covering the acute floor, 08:00–20:00.
- **Context:** Walks between ED, AMU, and the bed meeting. Carries a tablet and a radio. Joins two tactical calls a shift in winter.
- **Goal:** Know within two minutes when majors occupancy or boarded minutes cross the line, and know whether diversion is even discussable.
- **Pain today:** Learns the department is boarded when the nurse in charge phones, or when the ambulance stack appears on the radio.
- **Success looks like:** One screen shows occupancy by stream, boarded count, inbound crews, and every open capacity incident.

### 6.2 ED Nurse in Charge — Jamal
- **Role:** Nurse in charge of the type-1 department for a 12.5-hour shift.
- **Context:** On the floor, allocating cubicles, taking ambulance handovers, protecting resus.
- **Goal:** Know which stream is about to tip, and how many boarded patients sit on it, before the next two crews arrive.
- **Pain today:** Walks the department to count chairs. Loses five minutes per count.
- **Success looks like:** An alert names the stream, the boarded count, and the inbound ambulances.

### 6.3 ICB Liaison Officer — Priya C.
- **Role:** Daily contact for the integrated care board’s urgent-care cell.
- **Context:** Office-based; builds yesterday’s unscheduled-care return every morning.
- **Goal:** A one-page summary: attendances, four-hour performance, 12-hour trolley waits, hours on diversion, by site.
- **Pain today:** Pulls three systems and a voicemail from site ops. Takes 70 minutes.
- **Success looks like:** Opens a report, sends it, done.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-01 | The system shall show, in real time, occupancy of every ED stream from booking-in to “left department”. | Must | Core purpose of the tool. |
| FR-02 | The system shall calculate, for every boarded patient, minutes since decision to admit. | Must | Needed to know which streams are at risk. |
| FR-03 | The system shall flag a stream as “at risk” when trolley occupancy is at or above 95%, or when 8 or more patients have been boarded for more than 60 minutes. | Must | Consistent rule across shifts. |
| FR-04 | The site operations manager shall be able to see all at-risk streams on a single screen. | Must | One screen, one view. |
| FR-05 | The system shall raise a warning when any ambulance handover has waited more than 15 minutes, or when three or more crews are on the ramp. | Must | Fast reaction before diversion talk. |
| FR-06 | The system shall show, for each alert, the stream or ramp, the boarded or waiting count, and the inbound ambulance count. | Must | Give the nurse in charge enough to act. |
| FR-07 | The nurse in charge or site manager shall be able to acknowledge an alert and record the action taken. | Must | Audit trail of the diversion conversation. |
| FR-08 | The system shall group individual attendance flags into a single incident when they share the same stream and cause. | Should | Prevent alert fatigue. |
| FR-09 | The site manager shall be able to see all open capacity incidents across streams. | Should | Whole-floor awareness. |
| FR-10 | The system shall produce a daily unscheduled-care summary for the ICB liaison. | Must | External reporting requirement. |
| FR-11 | The system shall allow the site manager to add a free-text note to any incident. | Should | Context for the serious-incident pack. |
| FR-12 | The system shall allow the site manager to export the day’s incidents as a spreadsheet. | Could | Ad-hoc ICB or CQC requests. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | The system shall capture for every occupancy tick: encounter number, stream, cubicle or chair, terminal (ED zone), current stage, minutes boarded, inbound ambulance count. | Must | Minimum dataset for flow monitoring. |
| DR-02 | The system shall capture for every stream: name, funded spaces, current occupancy, occupancy percent, longest boarded minutes. | Must | Needed to compute at-risk. |
| DR-03 | The system shall capture for every incident: start time, end time, stream or ramp, boarded count, inbound crews, actions taken, and who acknowledged. | Must | Audit and reporting. |
| DR-04 | The system shall retain incident records for 24 months. | Must | Serious-incident and ICB requirement. |
| DR-05 | The system shall retain occupancy snapshots for 14 days. | Must | Enough for a full winter week review. |
| DR-06 | The system shall reject occupancy records with a missing encounter number or missing stream. | Must | Data quality at the source. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | Resuscitation bays and declared major-incident protected spaces must never be counted as spare capacity, and must never be proposed for boarding, without authorisation from the ED consultant in charge. | Clinical policy | Must |
| BR-02 | No at-risk alert may be raised for a stream that has already been closed or stood down (for example after a fire evacuation or a declared hospital full divert that is already in force). | Operational practice | Must |
| BR-03 | Every alert must be acknowledged or dismissed within 10 minutes. | Site service level | Must |
| BR-04 | Occupancy extracts shared with the ICB must exclude patient names, addresses, NHS numbers, and free-text clinical notes. | UK GDPR / Caldicott | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|
| AR-01 | The daily unscheduled-care summary shall show: attendances, four-hour performance, 12-hour trolley waits, peak occupancy, hours on diversion warning, hours on at-risk. | ICB liaison | Daily | 24 months |
| AR-02 | The incident log shall show every capacity incident with timings and actions. | Site ops, Chief Nurse, CQC pack | On demand | 24 months |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | The screen shall update within 10 seconds of an occupancy snapshot. | 10 s |
| NFR-02 | Availability | The system shall be available 99.5% of the time between 00:00 and 24:00. | 99.5% |
| NFR-03 | Capacity | The system shall handle 8,000 occupancy snapshots per day across all streams. | 8k/day |
| NFR-04 | Security | Only authenticated staff with an “Unscheduled Care Ops” or “ED Nurse in Charge” role shall see encounter-level rows. | Role-based |
| NFR-05 | Auditability | Every alert acknowledgement shall record who, when, and what action was taken. | Full trace |
| NFR-06 | Usability | A site manager shall be able to answer “is the ED safe to take the next three crews?” in under 15 seconds. | ≤15 s |
| NFR-07 | Compliance | The system shall comply with UK GDPR, the Caldicott principles, and the NHS England diversion-reporting expectation. | Full |
| NFR-08 | Recoverability | The system shall restore service within 30 minutes of a failure. | ≤30 min |

---

## 9. User journeys

### 9.1 Journey: Saturday peak — majors boards
- **Trigger:** Majors hits 40 of 42 spaces at 18:40; 9 patients have been boarded more than 60 minutes; 4 crews are on the ramp.
- **Steps:** The system flags the stream at-risk → Jamal sees the alert on the floor tablet → he walks the stream with the boarded count and the inbound figure → he opens two escalation beds on AMU with Helen → he acknowledges with the note “AMU surge 2, surgical outlier review”.
- **Outcome:** Occupancy falls below 95% in 25 minutes, no formal diversion, incident closed with a full record.
- **Failure path:** If nobody acknowledges within 10 minutes, the system escalates to the on-call site director.

### 9.2 Journey: Ambulance handover warning
- **Trigger:** A single crew has been on the ramp for 16 minutes; two further crews are 8 minutes out.
- **Steps:** The system raises a warn → Helen sees the ramp row → she phones the nurse in charge → a resus-capable cubicle is freed → handover completes at 19 minutes → the system records the warn as recovered.
- **Outcome:** No third crew joins a queue. Action recorded.
- **Failure path:** If the ramp reaches 3 crews and majors is already at-risk, site discusses formal diversion. The decision itself stays a human act; the tool only records it.

### 9.3 Journey: Morning ICB return
- **Trigger:** 07:30, Priya C. opens her laptop.
- **Steps:** She opens yesterday’s summary → sees attendances, four-hour performance, 12-hour waits, hours on warn / at-risk → exports it → sends it to the ICB cell before 08:30.
- **Outcome:** Return delivered on time, no manual count from the whiteboard photo.
- **Failure path:** If the summary fails, she falls back to the bed-management extract for one day.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | Every stream occupancy is visible within 10 seconds of a snapshot. | Live test on a Saturday peak |
| AC-02 | At-risk streams are correctly identified for 100% of scripted cases. | Scripted test with 40 known snapshots |
| AC-03 | Ramp / handover warnings are raised within 60 seconds of crossing the 15-minute or 3-crew rule. | Timed test with a controlled stack |
| AC-04 | Every alert can be acknowledged and recorded. | Demo with nurse in charge and site ops |
| AC-05 | Daily summary matches a manual count for a full day. | Side-by-side comparison |
| AC-06 | No patient name, NHS number, or address appears in the ICB extract. | Inspection by Caldicott Guardian |
| AC-07 | The system runs for 30 days with 99.5% availability. | Monthly service report |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Occupancy feed is slower than 60 seconds or drops during EPR downtime. | M | H | Early technical trial with Digital before winter; last-good snapshot age shown on screen. |
| R-02 | Site managers find the screen too crowded on a Saturday night. | M | M | Co-design with three site managers and two nurses in charge from week 1. |
| R-03 | Ambulance inbound feed is incomplete for some crews. | M | M | Show “unknown inbound” rather than a blank ramp. |
| R-04 | Wi-Fi blackspots in the ambulance bay. | L | M | Coverage survey; tablet cached for short outages. |
| R-05 | Staff see acknowledgement as extra work during a surge. | M | H | Keep ACK to one tap plus an optional note; design with the nurse in charge. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| Hours per month on formal ambulance diversion | 14 | 8 | 3 months after go-live |
| Median minutes from 95% occupancy to first site action | 22 min | 10 min | 3 months after go-live |
| Daily ICB return preparation time | 70 min | 5 min | 1 month after go-live |
| Site manager confidence in “can we take the next three crews?” | 2.4 / 5 | 4.0 / 5 | 3 months after go-live |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| Boarded patient | A patient with a decision to admit who remains in the ED because no ward bed is ready. |
| Cubicle / trolley space | A funded majors or resus space that can take a trolley. |
| Decision to admit | The timestamp when the ED clinician requests a ward bed. |
| Diversion | A declared period when inbound ambulances are asked to attend another ED. Still a human decision. |
| Encounter number | The unique ED attendance identifier issued at booking-in. |
| Handover delay | Minutes from ambulance arrival on the ramp to clinical handover. |
| ICB | Integrated Care Board — the regional commissioner that receives the daily return. |
| Majors | The main trolley stream for undifferentiated acute illness and injury. |
| Minors | The walking-wounded / chair stream. |
| Nurse in charge | The senior ED nurse responsible for cubicle allocation on the shift. |
| Occupancy | Current patients in a stream divided by funded spaces. |
| Site operations manager | The trust manager who owns same-day flow across ED and the acute wards. |
| Stream | A clinically defined zone: resus, majors, minors, paediatrics, SDEC. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | Will the paediatric area’s separate EPR module emit the same 60-second occupancy feed as majors? | Digital / Paediatrics | 2026-10-10 | Open |
| Q-02 | Which neighbouring EDs must be named on a diversion-discussion note in phase 1? | Site operations | 2026-10-20 | Open |
| Q-03 | What is the approved escalation policy when no one acknowledges an at-risk alert within 10 minutes at night? | Unscheduled Care Programme Office | 2026-10-25 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (COO) | `[name]` | | |
| Product owner (Chief Nurse) | `[name]` | | |
| Technical lead (Digital) | `[name]` | | |
| Caldicott / compliance | `[name]` | | |

---

*End of document.*
