# Business Requirements Document (BRD)

## Aerospace Line Maintenance and Gate Turnaround

| Field | Value |
|---|---|
| Project name | Turn Watch |
| Document title | Business Requirements — Aerospace Line Maintenance and Gate Turnaround |
| Version | 1.0 |
| Date | 2026-10-01 |
| Author | Airside Operations Programme Office |
| Reviewer(s) | Head of Line Maintenance, Duty Station Manager, Continuing Airworthiness Manager |
| Approver(s) | Accountable Manager, Head of Safety & Compliance, Security Manager (Airside) |
| Status | Approved |

**Revision history**

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | 2026-09-12 | Airside Ops Programme Office | First draft after summer on-time-departure review |
| 1.0 | 2026-10-01 | Airside Ops Programme Office | Approved after review with Line Maintenance, Station, and CAMO |

---

## 2. Executive summary

Every day this station turns around 86 narrow-body and 12 wide-body movements. A turn is not just a stand: it is fuel, catering, cleaning, loading, a walk-around, and any open defect the crew wrote up on the inbound sector. When a defect is still open, a part is still in quarantine, or a dual-inspection sign-off is missing, the aircraft either leaves late or — worse — leaves with an airworthiness hole nobody can later reconstruct. Today the duty engineer learns the turn is in trouble from a radio call, a paper tech log, and a parts desk that sits in another building. We need a simple tool that watches every aircraft on stand in real time, flags a turn before it becomes an Aircraft-On-Ground or an airworthiness finding, protects items we must never release without a second signature, and gives the duty engineer one view of what is happening right now plus an audit trail Quality and the CAA can read but not change. This document sets out what that tool must do, for whom, and how we will know it is working.

---

## 3. Business context

### 3.1 Background
The station is a UK Part-145 line-maintenance base supporting one home carrier and two handling customers. A typical narrow-body turn is **45 minutes** chocks-on to chocks-off; a wide-body is **75 minutes**. Company practice treats **20 minutes remaining with an open Category A defect, a missing dual inspection, or a quarantined part still allocated to the tail** as at risk of a missed slot. A Category A or MEL item that is closed without the second authorised signature is a mandatory occurrence report. Release of an aircraft that still has a locked-out flight-control or fuel-panel task is forbidden, regardless of the slot.

### 3.2 Problem statement
Right now the turn lives on three surfaces: the station operations screen (stand and ETD), the electronic tech log, and a parts spreadsheet on a warehouse PC. The duty engineer finds out a pin is still in a landing-gear lock when the crew refuse the aircraft, or when operations call because the slot is gone. Quarantine parts are sometimes scanned to a tail and then used on a different tail. We estimate that around 1 in 60 turns last summer lost more than 15 minutes for a reason that would have been visible 10 minutes after chocks-on if open defects, dual-inspect holds, and quarantine allocations had sat on one screen. The average time from “defect raised” to “duty engineer looking at the right stand” is 11 minutes, against a 3-minute target, and the second-signature record is often a stamp on paper that Quality cannot find after the aircraft has left.

### 3.3 Business drivers
- **Airworthiness.** An aircraft must not be released with an open dual-inspect item or a part that is still in quarantine.
- **On-time performance.** Missed slots cascade through the afternoon bank and cost the home carrier compensation and crew legalities.
- **Regulatory pressure.** UK CAA Part-145 and Part-CAMO require a reconstructable record of who deferred, who inspected, and who released. EASA findings on the last two audits named “turn documentation assembled after departure”.
- **Security.** Airside access, tool control, and parts custody are already a DfT / aviation-security concern. A part or a task that cannot be tied to a named authorised person is a security event as well as a quality event.
- **Staffing pressure.** Peak banks have one duty engineer covering 14 stands. They need one screen, not three.

### 3.4 Alignment with strategy
The 2026–2029 station plan names “visible, signed turns” as a reliability pillar. This project is a first step. It does not replace the tech log, the MRO system, or the airport stand-allocation system.

---

## 4. Scope

### 4.1 In scope
- Real-time monitoring of every aircraft on a served stand from chocks-on to chocks-off.
- A single duty-engineer view of open defects, dual-inspect holds, quarantine allocations, and minutes to ETD.
- Automatic alerts when a turn crosses the at-risk rule, or when a quarantined part is allocated to a tail.
- A protected-task register (flight controls, fuel panels, ETOPS items, locked-out tasks) that Quality maintains and that release must honour.
- A record of every alert, every deferral, every dual sign-off, and every release decision, in an append-only log.
- A daily station reliability and airworthiness summary for the CAMO and Quality.

### 4.2 Out of scope
- Base maintenance / hangar C-checks (a later phase).
- Replacing the electronic tech log, the MRO inventory system, or stand allocation.
- Automatic release of an aircraft. The authorised certifier still signs.
- Crew rostering, fuel order, and catering content.
- Other stations in the network in this phase.
- Passenger-facing delay messages.

### 4.3 Assumptions
- Stand allocation and ETD are available from the existing station system at least every 30 seconds.
- Each aircraft has a tail number and a flight number at chocks-on.
- The tech log can emit open-defect and inspection-status changes within 15 seconds of a sign-off.
- Parts quarantine status is available from the MRO store system.
- Duty engineers will use the tool on the existing airside tablet and the office workstation.
- Authorised-certifier identity comes from the existing Part-145 authorisation list.

### 4.4 Constraints
- No new sensors on the aircraft in this phase.
- Must be live before the 2027 summer schedule.
- Must use existing single sign-on and airside-pass roles.
- Must not write a release into the tech log. This tool watches and records; it does not certify.
- Must not store passenger names or passport numbers. Crew and certifier are staff IDs only.
- Work on stand must not be delayed by a tablet outage — paper tech log remains the legal record if the tool is down.

### 4.5 Dependencies
- Station ETD / stand feed (Station Control).
- Tech-log defect and sign-off feed (CAMO / IT).
- Quarantine and issue feed (Stores).
- Authorisation list (Quality).
- CAA / internal MOR column agreement (Safety).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
|---|---|---|---|---|
| Sponsor | Accountable Manager | Airworthiness, OTP, findings | H | Monthly steering |
| Primary user | Duty Engineers | One view, earlier hold | H | Weekly workshops |
| Primary user | Duty Station Managers | Slot and stand pressure | H | Weekly workshops |
| Reviewer | Continuing Airworthiness / CAMO | Reconstructable release | M | Bi-weekly review |
| Reviewer | Quality / Safety | Dual inspect, MORs | M | Sign-off before go-live |
| Regulator | UK CAA / DfT aviation security | Record and airside custody | L | Quarterly update |

---

## 6. Users and personas

### 6.1 Duty Engineer — Samira
- **Role:** Line duty engineer, morning bank, 14 stands.
- **Context:** On the apron with a tablet, a radio, and two mechanics. A typical bank has three walk-arounds and one inbound write-up.
- **Goal:** Know within two minutes of chocks-on whether this tail has an open Category A, a dual-inspect hold, or a quarantined part.
- **Pain today:** Walks to the aircraft to read the tech log, then phones stores. Loses the slot while waiting.
- **Success looks like:** An alert names the tail, the stand, the open item, and whether a second signature is still owed.

### 6.2 Duty Station Manager — Tomas
- **Role:** Station lead for the bank.
- **Context:** Ops room. Protects the slot and the next inbound.
- **Goal:** Know which turns are airworthiness-blocked versus merely late on catering, so he does not push a release.
- **Pain today:** Hears “engineering are on it” with no time or item.
- **Success looks like:** One screen separates airworthiness holds from handling delays.

### 6.3 Quality Investigator — Elena
- **Role:** Builds the file after a delay or a MOR.
- **Context:** Office. Needs who deferred, who inspected, who released.
- **Goal:** A pack with no missing second signature and no passenger data.
- **Pain today:** Stamps, WhatsApp screenshots, and a stores print-out.
- **Success looks like:** Opens the log, exports, files. Cannot delete a row.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-01 | The system shall show, in real time, every served stand: tail, flight, chocks-on, ETD, open defect count, dual-inspect holds, quarantine allocations. | Must | Core purpose of the tool. |
| FR-02 | The system shall calculate minutes remaining to ETD for every aircraft on stand. | Must | Needed to know which turns are at risk. |
| FR-03 | The system shall flag a turn as “at risk” when minutes to ETD are at or below 20 and any Category A defect, dual-inspect hold, or quarantined part is still open. | Must | Consistent rule across banks. |
| FR-04 | The system shall flag a turn as “blocked” when a protected task (flight control, fuel panel, ETOPS, locked-out) is open, regardless of minutes remaining. | Must | Airworthiness over the slot. |
| FR-05 | The duty engineer shall see all at-risk and blocked turns on a single screen. | Must | One screen, one view. |
| FR-06 | The system shall raise an alert when a quarantined part is allocated to a tail. | Must | Custody and airworthiness. |
| FR-07 | The system shall show, for each alert, tail, stand, item, minutes to ETD, and whether a second signature is owed. | Must | Enough to act. |
| FR-08 | The duty engineer or certifier shall be able to acknowledge an alert and record defer, inspect, reject part, or release-not-yet. | Must | Audit trail. |
| FR-09 | The system shall refuse to record a release against a protected task unless a second authorised signature has been acknowledged. | Must | Dual-inspect rule. |
| FR-10 | Quality shall be able to add or remove a task type from the protected-task register while the system is running. | Must | Live policy. |
| FR-11 | The system shall not raise a second at-risk alert for the same tail and same item until the first is acknowledged or closed. | Must | Alert fatigue. |
| FR-12 | The station manager shall see all open holds across stands. | Should | Bank awareness. |
| FR-13 | The system shall produce a daily reliability and airworthiness summary for CAMO and Quality. | Must | External and internal reporting. |
| FR-14 | Notes shall not contain passenger names or medical details. | Must | Data protection. |
| FR-15 | The system shall escalate when an at-risk alert is unacknowledged for 5 minutes. | Must | Bank pace. |
| FR-16 | Closing a quarantine allocation shall return the part to the quarantine count, not to “fit for service”, unless Quality acknowledges release from quarantine. | Must | Parts custody. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | Capture for every tick: tail, flight, stand, minutes to ETD, open defect IDs, inspect-hold flag, quarantine part numbers. | Must | Minimum dataset. |
| DR-02 | Capture for every incident: start, end, tail, item, action, first signature, second signature if required. | Must | Reconstructable release. |
| DR-03 | Retain incident records for 36 months. | Must | CAA / CAMO file. |
| DR-04 | Retain stand ticks for 14 days. | Must | Bank reconstruction. |
| DR-05 | Reject a tick with a missing tail or stand. | Must | Data quality. |
| DR-06 | Do not persist passenger names, PNRs, or passport numbers. | Must | Security and GDPR. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | A protected task shall never be recorded as released without a second authorised acknowledgement. | Part-145 | Must |
| BR-02 | A quarantined part shall never be treated as fitted-serviceable without Quality acknowledgement. | Stores / airworthiness | Must |
| BR-03 | No new at-risk alert for the same tail and item while an incident is open. | Practice | Must |
| BR-04 | Quality and CAA views of the log are read-only and cannot delete a row. | Regulatory | Must |
| BR-05 | Slot pressure shall not override a blocked turn. | Safety | Must |
| BR-06 | Staff identity on the log is authorisation number, not a photocopy of an airside pass. | Security | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|---|
| AR-01 | Daily summary: turns, at-risk, blocked, dual-inspect closures, quarantine events, median time to acknowledge. | CAMO, Quality | Daily | 36 months |
| AR-02 | Incident log with timings and signatures. | Duty engineers, Quality, CAA | On demand | 36 months |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | Screen updates within 5 seconds of a tech-log or stand change. | 5 s |
| NFR-02 | Availability | 99.9% between 04:00 and 00:00. | 99.9% |
| NFR-03 | Capacity | 8,000 ticks per day across served stands. | 8k/day |
| NFR-04 | Security | Only “Line Maintenance” or “Station Ops” roles see tail-level live data. Quality is read-only plus register admin. | Role-based |
| NFR-05 | Security | No write path into the tech log or aircraft systems. | Watch only |
| NFR-06 | Auditability | Every acknowledgement and second signature records who, when, what. | Full trace |
| NFR-07 | Usability | Duty engineer answers “which tail is blocked right now?” in under 10 seconds. | ≤10 s |
| NFR-08 | Compliance | Supports Part-145 record-keeping and UK GDPR. | Full |
| NFR-09 | Recoverability | Live view back within 15 minutes; log intact. Paper tech log remains legal fallback. | ≤15 min |

---

## 9. User journeys

### 9.1 Journey: Inbound write-up on a 45-minute turn
- **Trigger:** Tail G-EXMP arrives 07:12 with a Category A flap-indication defect. ETD 07:57. Dual inspect required after rectification.
- **Steps:** System flags the turn at risk at 07:13 → Samira sees stand, item, 44 minutes remaining → mechanic rectifies → first signature at 07:31 → system still blocked on second signature → supervisor inspects → second acknowledgement at 07:38 → at-risk clears.
- **Outcome:** Aircraft released with both names on the log. Slot held.
- **Failure path:** If Tomas tries to mark the turn “ready” without the second signature, the system refuses and writes a rejected-action row.

### 9.2 Journey: Quarantine part scanned to the wrong tail
- **Trigger:** A flight-control actuator in quarantine is allocated to G-EXMP instead of G-HOLD.
- **Steps:** FR-06 raises an alert → Samira rejects the allocation → part count returns to quarantine, not to serviceable stock.
- **Outcome:** Wrong-tail fit prevented. Quality can see the attempt.
- **Failure path:** If stores ignore the alert for 5 minutes, escalate to the duty engineer’s radio group.

### 9.3 Journey: Morning CAMO pack
- **Trigger:** 08:30 after a bank with two holds.
- **Steps:** Elena opens the daily summary → exports without passenger data → files for CAMO.
- **Outcome:** Pack in 10 minutes. She cannot delete a row.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | Every served stand visible within 5 seconds of chocks-on. | Live bank test |
| AC-02 | At-risk and blocked flags match the 20-minute / protected-task rules on 30 scripted turns. | Scripted test |
| AC-03 | Release of a protected task without second signature is refused and logged. | Desk test |
| AC-04 | Quarantine allocation to a tail raises an alert; reject returns the part to quarantine. | Stores test |
| AC-05 | Quality role cannot delete a row. | Role test |
| AC-06 | Daily summary matches the tech-log count for one full day and has no passenger data. | Side-by-side plus DPO |
| AC-07 | 30 days at 99.9% availability with one planned fail-over. | Service report |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Tech-log feed lags during a bank. | M | H | Trial on the busiest morning bank before full build. |
| R-02 | Staff treat the tool as the legal release. | M | H | Written constraint; paper / official tech log remains the certificate. |
| R-03 | Authorisation list is stale. | M | H | Nightly load from Quality’s live list. |
| R-04 | Airside tablet Wi-Fi holes. | M | M | Coverage survey; paper fallback. |
| R-05 | Customer airline refuses a shared log. | L | M | Home-carrier tails first; handling customers in phase 1b. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| Time from defect raised to duty engineer on the right stand | 11 min | 3 min | 3 months |
| Turns lost >15 min for a reason visible at chocks-on | 1 in 60 | 1 in 150 | 6 months |
| Releases with a missing second signature in the file | Occurs | Zero | Every month |
| Quality pack time after a MOR bank | 90 min | 15 min | 1 month |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| At risk | Turn with ≤20 minutes to ETD and an open airworthiness item. |
| Blocked | Protected task still open; slot does not override. |
| CAMO | Continuing Airworthiness Management Organisation. |
| Category A | Defect that must be rectified before further flight unless deferred under MEL. |
| Dual inspect | Second authorised look at a specified task. |
| ETD | Estimated time of departure. |
| MEL | Minimum Equipment List — approved deferral framework. |
| MOR | Mandatory Occurrence Report. |
| Part-145 | Approved maintenance organisation regulation. |
| Protected task | Flight control, fuel panel, ETOPS, or locked-out task. |
| Quarantine | Part not fit for service until Quality releases it. |
| Tail | Aircraft registration. |
| Turn | Period from chocks-on to chocks-off. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | Are handling-customer tails in phase 1 or phase 1b? | Station Manager | 2026-10-20 | Open |
| Q-02 | Which ETOPS items belong on the protected register on day one? | Quality | 2026-10-15 | Open |
| Q-03 | What wording is approved when a release is refused for a missing second signature? | Safety | 2026-10-20 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (Accountable Manager) | `[name]` | | |
| Product owner (Head of Line Maintenance) | `[name]` | | |
| Technical lead (IT) | `[name]` | | |
| Quality / Safety | `[name]` | | |
| Security Manager (Airside) | `[name]` | | |

---

*End of document.*
