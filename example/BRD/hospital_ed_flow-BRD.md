# Business Requirements Document (BRD)

## Hospital Emergency Department — Patient Flow & Capacity Management

| Field | Value |
| --- | --- |
| Project name | FlowCare ED |
| Document title | Business Requirements — Emergency Department Patient Flow |
| Version | 1.0 |
| Date | 2026-09-22 |
| Author | Clinical Operations Programme Office |
| Reviewer(s) | ED Clinical Director, Head of Nursing, Bed Manager, Patient Safety Lead |
| Approver(s) | Medical Director, Chief Nurse, Chief Information Officer |
| Status | Approved |

### Revision history

| Version | Date | Author | Change summary |
| --- | --- | --- | --- |
| 0.1 | 2026-08-25 | Clinical Ops Programme Office | First draft |
| 1.0 | 2026-09-22 | Clinical Ops Programme Office | Approved after review with ED Clinical Director and Head of Nursing |

---

## 2. Executive summary

Every day, our Emergency Department (ED) sees around 520 patients. Each patient arrives, is triaged, assessed, investigated, treated, and either discharged or admitted. When this flow breaks down — because beds are unavailable, results are delayed, or a patient deteriorates unnoticed — people wait longer on trolleys in corridors, ambulance handovers are delayed, and clinical outcomes suffer.

Today, the ED consultant learns about a bottleneck when a nurse pages them. The Bed Manager learns about a capacity crisis when the hospital switchboard calls. The Medical Director learns about a 4-hour target breach after the daily report — 24 hours too late to act.

We need a single, real-time view of patient flow that spots risks before they become breaches, gives each role the information they need, and creates a forensic audit trail of every clinical and operational decision. This document sets out what that system must do, for whom, and how we will know it is working.

---

## 3. Business context

### 3.1 Background

Our hospital is a 650-bed district general hospital serving a population of 380,000. The ED has 42 cubicles, 8 resuscitation bays, and a 20-chair major injuries area. Patients arrive by ambulance (35%), self-referral (55%), and GP urgent referral (10%). The national target is that 95% of patients are admitted, transferred, or discharged within 4 hours. Our current performance is 82%.

### 3.2 Problem statement

We have no single view of patient flow. The patient tracking system (PTS), the bed management system, the laboratory system, and the radiology system each report their own status. A patient who has been waiting 3 hours for a medical bed is invisible to the ED consultant until a nurse manually flags it. A patient whose NEWS2 score has risen silently over 2 hours is not escalated unless someone happens to re-check. We estimate that around 1 in 12 patients experiences a preventable delay of more than 30 minutes.

### 3.3 Business drivers

- **Clinical safety.** Delayed recognition of deterioration is a top contributor to serious incidents.
- **Regulatory targets.** The NHS 4-hour ED standard and the 30-minute ambulance handover target are CQC-inspected.
- **Financial pressure.** Each 4-hour breach costs the trust approximately £450 in tariff deductions. At current performance, this is £4.2M per year.
- **Staff morale.** ED nursing vacancy rate is 22%, partly driven by unsafe working conditions during flow crises.
- **Patient experience.** The Friends and Family Test shows ED as the lowest-scoring department (68% "excellent").

### 3.4 Alignment with strategy

The trust's 2025–2028 strategy names "safe, timely care" as pillar one. This project delivers the operational visibility needed to make that pillar real, without replacing any existing clinical system.

---

## 4. Scope

### 4.1 In scope

- Real-time tracking of every ED patient from arrival to discharge/admission.
- A single view of ED capacity and flow for the ED Consultant, Bed Manager, and Nursing Coordinator.
- Automatic alerts when a patient's clinical risk score (NEWS2) rises, or when a patient approaches a time-critical threshold (e.g., 3 hours in ED, 60 minutes awaiting a bed).
- A forensic record of every alert, escalation, and clinical decision.
- A daily performance report for the hospital executive team and CQC.

### 4.2 Out of scope

- Inpatient ward flow (covered in Phase 2).
- Replacement of the Patient Tracking System (PTS), Electronic Patient Record (EPR), or laboratory/radiology systems.
- Automated clinical decision-making (staff retain all clinical authority).
- Ambulance crew-facing functionality.
- Paediatric or maternity-specific pathways (these require separate clinical rules).
- Any site other than the main acute hospital.

### 4.3 Assumptions

- The existing PTS emits a patient movement event at least every 5 minutes per patient.
- NEWS2 scores are entered into the EPR within 15 minutes of measurement.
- The bed management system reflects real bed status within 10 minutes of a change.
- All clinical staff have trust-issued smartcards for single sign-on.
- Wi-Fi coverage is adequate in all ED clinical areas and the Bed Management office.

### 4.4 Constraints

- No new clinical hardware at the bedside in this phase.
- Must go live before the winter pressures period (October 2027).
- Must integrate with the existing NHS Smartcard authentication.
- Must not add more than 30 seconds of workflow per patient encounter.
- Must comply with NHS Digital's DCB0129 clinical safety standard.
- Budget capped at the amount approved in the Q3 trust board paper (£680k).

### 4.5 Dependencies

- PTS must expose a real-time event feed (Health Informatics team).
- EPR must expose NEWS2 scores via HL7 FHIR (EPR vendor, contract in place).
- Bed management system must expose bed status via API (Estates & Informatics).
- Clinical Safety Case must be signed off before go-live (Patient Safety Lead).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
| --- | --- | --- | --- | --- |
| Sponsor | Medical Director | Clinical safety, regulatory, financial | H | Monthly steering |
| Primary user | ED Consultants (rotating) | One screen, early warning of sick patients | H | Weekly co-design |
| Primary user | ED Nursing Coordinator | Staff allocation, patient flow | H | Weekly co-design |
| Primary user | Bed Manager | Hospital-wide capacity | H | Bi-weekly review |
| Reviewer | Head of Nursing | Staff workload, safety | M | Monthly review |
| Reviewer | Patient Safety Lead | Clinical safety case | M | Sign-off before go-live |
| Reviewer | Caldicott Guardian | Patient data governance | M | Sign-off before go-live |
| Regulator | Care Quality Commission (CQC) | 4-hour target, safety | L | Quarterly update |
| Regulator | NHS England (Regional Team) | Performance targets | L | Monthly return |

---

## 6. Users and personas

### 6.1 ED Consultant — Dr. Aisha

- **Role:** Senior doctor on shift, clinically responsible for all ED patients for 10 hours.
- **Context:** Moving between resus, the major injuries area, and the clinical decision unit. Carries a bleep and a shared tablet. Makes 80–120 clinical decisions per shift.
- **Goal:** Know within 60 seconds if any patient is deteriorating or has been waiting dangerously long.
- **Pain today:** Learns about a deteriorating patient when the nurse pages. Learns about a 4-hour breach when the target board flashes red — often too late.
- **Success looks like:** One screen shows every patient, colour-coded by clinical risk and time-waiting, with proactive alerts before things go wrong.

### 6.2 ED Nursing Coordinator — Sarah

- **Role:** Allocates nurses to patients and manages the "flow" of the department hour-by-hour.
- **Context:** Based at the nursing coordination desk, on the phone and radio constantly.
- **Goal:** Know which patients need a nurse now, which can wait, and where the bottlenecks are.
- **Pain today:** Walks the department every 30 minutes to get a mental picture. Misses slow deterioration.
- **Success looks like:** A live board showing nurse-to-patient ratios, patients awaiting action, and predicted bottlenecks for the next 2 hours.

### 6.3 Bed Manager — David

- **Role:** Manages the allocation of medical beds across the whole hospital.
- **Context:** Based in the bed management office, on the phone to ward sisters and the ED.
- **Goal:** Know which ED patients are waiting for a bed, how long they've waited, and which wards have capacity.
- **Pain today:** Builds the picture from three spreadsheets and phone calls. Breaches happen before he knows.
- **Success looks like:** One screen showing every ED patient awaiting a bed, ranked by wait time and clinical urgency, with ward capacity visible.

### 6.4 Medical Director — Prof. James

- **Role:** Executive responsible for ED performance and clinical safety.
- **Context:** Receives the daily performance report at 08:00. Chairs the weekly operational meeting.
- **Goal:** A single, trustworthy daily report showing performance against targets, with trends and root causes.
- **Pain today:** Receives a report built by hand from four systems. Doesn't trust it. Asks for re-runs.
- **Success looks like:** Opens a report, trusts it, acts on it.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
| --- | --- | --- | --- |
| FR-01 | The system shall show, in real time, every ED patient's current state (triaged, assessed, awaiting results, awaiting bed, ready for discharge, etc.). | Must | Core purpose. |
| FR-02 | The system shall display each patient's most recent NEWS2 score and the time it was recorded. | Must | Clinical safety. |
| FR-03 | The system shall flag a patient as "clinically deteriorating" when their NEWS2 score rises by ≥2 points within 2 hours, or reaches ≥5. | Must | Early Warning Score protocol. |
| FR-04 | The system shall flag a patient as "time-critical" when they have been in ED for ≥3 hours without a disposition decision. | Must | 4-hour target protection. |
| FR-05 | The system shall raise an alert to the ED Consultant when a patient meets FR-03 or FR-04. | Must | Proactive escalation. |
| FR-06 | The system shall raise an alert to the Bed Manager when a patient has awaited a medical bed for ≥60 minutes. | Must | Capacity management. |
| FR-07 | The ED Consultant shall be able to acknowledge an alert and record the clinical action taken. | Must | Audit trail. |
| FR-08 | The system shall group related alerts into a single incident when they share a common cause (e.g., "lab system delay affecting 8 patients"). | Should | Prevent alert fatigue. |
| FR-09 | The Bed Manager shall see a ranked list of all ED patients awaiting a bed, with wait time and clinical urgency. | Must | Prioritisation. |
| FR-10 | The system shall produce a daily performance report showing: total attendances, 4-hour performance, breach count, mean time to initial assessment, mean time to treatment, and top 5 delay reasons. | Must | Executive and CQC reporting. |
| FR-11 | The ED Consultant shall be able to add a free-text clinical note to any alert or incident. | Should | Clinical context. |
| FR-12 | The system shall allow the Medical Director to export the daily report as a PDF and CSV. | Could | Ad-hoc requests. |
| FR-13 | The system shall display, for each patient, the time since their last vital signs were recorded. | Must | Safety monitoring. |
| FR-14 | The system shall escalate an unacknowledged clinical deterioration alert to the Clinical Director after 10 minutes. | Must | Safety net. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
| --- | --- | --- | --- |
| DR-01 | The system shall capture for every patient: NHS number (hashed), arrival time, triage category, current state, current location, assigned clinician, and disposition. | Must | Minimum dataset. |
| DR-02 | The system shall capture for every vital signs set: timestamp, NEWS2 score, individual parameters (RR, SpO2, SBP, HR, consciousness, temperature), and the recorder's staff ID. | Must | Clinical audit. |
| DR-03 | The system shall capture for every incident: start time, end time, affected patients, clinical trigger, actions taken, and the staff member who acknowledged. | Must | Audit and CQC reporting. |
| DR-04 | The system shall retain incident records for 8 years (adult) or until the patient's 25th birthday (paediatric), per NHS Records Management Code of Practice. | Must | Legal requirement. |
| DR-05 | The system shall retain patient flow snapshots (state every 5 minutes) for 90 days. | Must | Operational review. |
| DR-06 | The system shall reject patient records with a missing NHS number (or valid temporary identifier) or missing arrival time. | Must | Data quality. |
| DR-07 | The system shall store NHS numbers only in hashed form; the hash key must be held separately by the Caldicott Guardian. | Must | GDPR and NHS Data Security. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
| --- | --- | --- | --- |
| BR-01 | No patient may be discharged from the ED without a recorded disposition decision by a clinician with appropriate authority (consultant or SAS doctor). | CQC Regulation 12 | Must |
| BR-02 | A NEWS2 score of ≥7 must trigger an immediate critical care review; the system must alert the ED Consultant and the Critical Care Outreach team simultaneously. | RCP NEWS2 protocol | Must |
| BR-03 | Every clinical deterioration alert must be acknowledged within 10 minutes. | Trust clinical policy | Must |
| BR-04 | Patient data shared in executive reports must be fully anonymised; no NHS number, date of birth, or identifiable combination of attributes. | UK GDPR / Caldicott Principles | Must |
| BR-05 | A patient flagged as "safeguarding concern" (e.g., child protection, domestic abuse) must have their record access restricted to named clinicians only. | Safeguarding policy | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
| --- | --- | --- | --- | --- |
| AR-01 | Daily ED performance report: attendances, 4-hour performance, breaches, mean times, top delay reasons. | Medical Director, NHS England | Daily | 8 years |
| AR-02 | Incident log: every alert, acknowledgement, and clinical action. | ED Clinical Director, Patient Safety | On demand | 8 years |
| AR-03 | Weekly trend report: deterioration alerts, response times, missed escalations. | Clinical Governance Committee | Weekly | 8 years |
| AR-04 | Monthly CQC return: 4-hour performance, ambulance handover times, corridor waits. | CQC, NHS England | Monthly | 8 years |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
| --- | --- | --- | --- |
| NFR-01 | Performance | The clinical view shall update within 10 seconds of a vital signs entry or patient movement. | ≤10 s |
| NFR-02 | Availability | The system shall be available 99.95% of the time, 24/7/365. | 99.95% |
| NFR-03 | Capacity | The system shall handle 600 concurrent patients and 15,000 vital signs entries per day. | 600 patients / 15k VS |
| NFR-04 | Security | Access to patient-level data shall be restricted to authenticated staff with a role-based clinical or operational permission. | Role-based |
| NFR-05 | Auditability | Every alert acknowledgement, clinical note, and data access shall record who, when, what, and from where. | Full trace |
| NFR-06 | Usability | An ED Consultant shall be able to answer "do I have any deteriorating patients right now?" in under 5 seconds. | ≤5 s |
| NFR-07 | Compliance | The system shall comply with UK GDPR, NHS Data Security and Protection Toolkit, and DCB0129 clinical safety. | Full |
| NFR-08 | Recoverability | The system shall restore service within 15 minutes of a failure, with no loss of clinical data. | ≤15 min |
| NFR-09 | Interoperability | The system shall integrate via HL7 FHIR R4 with the EPR, PTS, and bed management system. | FHIR R4 |

---

## 9. User journeys

### 9.1 Journey: Silent deterioration

**Trigger:** A 68-year-old patient admitted with pneumonia has a NEWS2 rise from 3 to 6 over 90 minutes, but no one has re-assessed them.

**Steps:** The system detects the NEWS2 rise at 14:22 → raises a "clinical deterioration" alert to Dr. Aisha's tablet → she acknowledges at 14:25 with the note "reviewing now, calling CCOT" → she reviews the patient, escalates to Critical Care Outreach → the patient is transferred to HDU at 15:10 → the alert is closed with the outcome recorded.

**Outcome:** Deterioration caught early, patient safely escalated, full audit trail.

**Failure path:** If Dr. Aisha does not acknowledge within 10 minutes, the system escalates to the Clinical Director and the Nursing Coordinator simultaneously.

### 9.2 Journey: 4-hour breach prevention

**Trigger:** A patient has been in ED for 2 hours 45 minutes and is still awaiting a medical bed.

**Steps:** The system flags the patient as "time-critical" at 15:15 → raises an alert to Dr. Aisha and David (Bed Manager) → David sees the patient is ranked #2 on the bed wait list → he calls the Medical Assessment Unit and secures a bed by 15:28 → he records the action → the patient is transferred at 15:42, 18 minutes before the 4-hour breach.

**Outcome:** Breach prevented, action recorded.

**Failure path:** If no bed is found within 15 minutes of the alert, the system escalates to the Head of Nursing and the hospital on-call manager.

### 9.3 Journey: Morning executive report

**Trigger:** 08:00, Prof. James opens his laptop.

**Steps:** He opens the daily report → sees yesterday's 4-hour performance was 86% (up from 82%) → sees the top delay reason was "awaiting resuscitation room clearance" → he emails the ED Clinical Director asking for a root cause review → done in 4 minutes.

**Outcome:** Data-driven decision in minutes, not hours.

**Failure path:** If the report fails, the Medical Director falls back to the manual spreadsheet for one day and logs an incident.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
| --- | --- | --- |
| AC-01 | Every patient is visible within 10 seconds of a state change or vital signs entry. | Live test during a peak hour |
| AC-02 | Deteriorating patients (NEWS2 rise ≥2 in 2h, or ≥5) are flagged for 100% of test cases. | Scripted test with 30 simulated patients |
| AC-03 | Alerts for deterioration are raised within 30 seconds of the triggering vital signs entry. | Timed test with controlled data |
| AC-04 | Every alert can be acknowledged with a clinical note and outcome. | Demo with ED Consultants |
| AC-05 | Daily report matches a manual count for a full day (within 1% tolerance). | Side-by-side comparison |
| AC-06 | No patient-identifiable data appears in executive reports. | Inspection by Caldicott Guardian |
| AC-07 | The system runs for 30 days with 99.95% availability. | Monthly service report |
| AC-08 | Clinical Safety Case is signed off by the Patient Safety Lead. | Formal sign-off |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| R-01 | EPR vendor delays FHIR NEWS2 feed. | M | H | Early integration sprint; fallback to manual NEWS2 entry. |
| R-02 | ED Consultants find the screen distracting during resus. | M | H | Co-design from week 1; "quiet mode" during active resus. |
| R-03 | Alert fatigue from false-positive deterioration flags. | M | H | Calibrate NEWS2 thresholds with 3 months of retrospective data before go-live. |
| R-04 | Wi-Fi dead zones in the resuscitation room. | L | H | Pre-go-live site survey; tablet caching for short outages. |
| R-05 | Staff see the tool as another screen to check. | M | M | Involve Nursing Coordinators in design; keep acknowledgements to one tap. |
| R-06 | Caldicott Guardian blocks the design over data concerns. | L | H | Early engagement; privacy impact assessment done in week 1. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
| --- | --- | --- | --- |
| 4-hour ED performance | 82% | 92% | 6 months after go-live |
| Mean time to recognise NEWS2 deterioration | 95 min | 30 min | 6 months after go-live |
| Mean time ED patient awaits a medical bed | 142 min | 75 min | 6 months after go-live |
| ED Friends and Family Test ("excellent") | 68% | 80% | 6 months after go-live |
| ED nursing vacancy rate | 22% | 15% | 12 months after go-live |
| Time to prepare daily executive report | 90 min | 5 min | 1 month after go-live |

---

## 13. Glossary

| Term | Meaning |
| --- | --- |
| CQC | Care Quality Commission — the independent regulator of health and social care in England. |
| DCB0129 | NHS Digital clinical risk management standard for health IT. |
| ED | Emergency Department. |
| EPR | Electronic Patient Record — the system of record for clinical documentation. |
| FHIR | Fast Healthcare Interoperability Resources — HL7 standard for health data exchange. |
| HDU | High Dependency Unit — step-up care between ward and ICU. |
| NEWS2 | National Early Warning Score 2 — a standardised physiological track-and-trigger system. |
| NHS number | The unique patient identifier for the English NHS. |
| PTS | Patient Tracking System — the operational system for ED patient movements. |
| SAS doctor | Specialty and Associate Specialist doctor — a senior non-consultant grade. |
| Triage | The initial assessment that assigns a patient a urgency category (1 = immediate, 5 = non-urgent). |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
| --- | --- | --- | --- | --- |
| Q-01 | Will the EPR vendor deliver the FHIR NEWS2 feed by the integration sprint start (2026-11-01)? | EPR Vendor / Health Informatics | 2026-10-15 | Open |
| Q-02 | What is the approved escalation path when a NEWS2 ≥7 alert is unacknowledged for 10 minutes? | Clinical Safety Lead | 2026-10-20 | Open |
| Q-03 | Should paediatric patients (under 16) use the PEWS score instead of NEWS2, and if so, is PEWS available in the EPR feed? | ED Clinical Director (Paeds) | 2026-10-25 | Open |
| Q-04 | Which four wards will be included in the Day 1 bed management view? | Bed Manager / Matrons | 2026-11-01 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
| --- | --- | --- | --- |
| Business sponsor (Medical Director) | [name] |  |  |
| Product owner (ED Clinical Director) | [name] |  |  |
| Technical lead (Health Informatics) | [name] |  |  |
| Clinical Safety Lead | [name] |  |  |
| Caldicott Guardian | [name] |  |  |