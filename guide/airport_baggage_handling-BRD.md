# Business Requirements Document (BRD)

## Airport Baggage Handling — Day 1 Requirements

| Field | Value |
|---|---|
| Project name | Baggage Flow Watch |
| Document title | Business Requirements — Airport Baggage Handling |
| Version | 1.0 |
| Date | 2026-09-16 |
| Author | Operations Programme Office |
| Reviewer(s) | Head of Terminal Ops, Baggage Services Manager, Duty Manager |
| Approver(s) | COO, Head of Safety & Compliance |
| Status | Approved |

**Revision history**

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | 2026-08-20 | Ops Programme Office | First draft |
| 1.0 | 2026-09-16 | Ops Programme Office | Approved after review with Terminal Ops and Baggage Services |

---

## 2. Executive summary

Every day, tens of thousands of bags move through our airport's belts, sorters, and make-up carousels. When a bag misses its flight, the passenger is delayed, the airline is fined, and our reputation takes a hit. Today, our teams find out about a missed bag only when the airline calls — often hours later. We need a simple tool that watches baggage flow in real time, spots problems before they become missed bags, and gives the duty manager one clear view of what is happening right now. This document sets out what that tool must do, for whom, and how we will know it is working.

---

## 3. Business context

### 3.1 Background
Our airport handles around 45,000 departing bags and 40,000 arriving bags per day. Bags travel from check-in to a sorter, then to a make-up carousel, then onto a cart and finally the aircraft hold. A bag has roughly 35 minutes to make this journey for a short-haul flight. When a bag is delayed — because a belt jammed, a tag was unreadable, or a carousel was overloaded — the bag is flagged as "at risk" and the airline has to decide whether to hold the flight or offload the bag. Both choices cost money.

### 3.2 Problem statement
Right now, we have no single view of baggage flow. The belt control system, the sorters, and the carousel systems each report their own status to their own screen. The duty manager learns about a problem when the airline calls, or when a passenger complains at the gate. By then, the bag is often already missing its flight. We estimate that around 1 in 900 bags is delayed in a way that could have been prevented if we had known 10 minutes earlier.

### 3.3 Business drivers
- **Airline penalties.** Missed bags cost us money in airline charges and, in some cases, contractual penalties.
- **Passenger experience.** Baggage delay is one of the top three complaints at the airport.
- **Regulatory pressure.** The Civil Aviation Authority has asked all UK airports to demonstrate real-time baggage performance reporting from 2027.
- **Staffing pressure.** Our duty managers are already stretched. They need fewer screens, not more.

### 3.4 Alignment with strategy
Our 2025–2028 airport strategy names "operational visibility" as one of four pillars. This project delivers a first, concrete step in that direction, without replacing any of the systems we already have.

---

## 4. Scope

### 4.1 In scope
- Real-time monitoring of bag movement from check-in to aircraft hold for departing bags.
- A single duty-manager view of current baggage flow across all terminals.
- Automatic alerts when a bag or a group of bags is at risk of missing its flight.
- A record of every alert and every action taken by staff.
- A daily report for the airline liaison team.

### 4.2 Out of scope
- Arriving bags and transfer bags. These will be covered in a later phase.
- Replacing the belt control system, sorters, or carousel systems.
- Automatic re-routing of bags. Staff will still make the decisions.
- Passenger-facing apps or notifications.
- Bag tracking beyond the aircraft door.
- Anything outside the four terminals at this airport.

### 4.3 Assumptions
- The belt control system can provide bag position updates at least every 15 seconds.
- Each bag's tag is scanned at every handover point (check-in, sorter entry, sorter exit, carousel induction, aircraft side).
- The airline systems provide flight departure times through the existing AODB (Airport Operational Database).
- The airport has enough Wi-Fi coverage for tablets on the apron.
- Duty managers will use the tool on the existing tablet devices.

### 4.4 Constraints
- No new hardware on the belts in this phase.
- Must go live before the 2027 summer schedule.
- Must use the existing single sign-on for staff login.
- Must not disrupt the live baggage operation during rollout.
- Budget capped at the amount approved in the Q3 board paper.

### 4.5 Dependencies
- Belt control system must expose a real-time feed (Baggage Services team).
- AODB must expose flight departure times (IT team, already available).
- Apron Wi-Fi coverage confirmed for Terminals 1 and 4 (Infrastructure team).
- Airline liaison team must agree the daily report format (Commercial team).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
|---|---|---|---|---|
| Sponsor | Chief Operating Officer | Cost, reputation, regulatory readiness | H | Monthly steering |
| Primary user | Duty Managers (4 terminals) | One clear view, fewer calls | H | Weekly workshops |
| Primary user | Baggage Services Supervisors | Faster response to jams | H | Weekly workshops |
| Reviewer | Airline Liaison Team | Reporting accuracy | M | Bi-weekly review |
| Reviewer | Safety & Compliance | No impact on safety rules | M | Sign-off before go-live |
| Regulator | Civil Aviation Authority | Reporting from 2027 | L | Quarterly update |

---

## 6. Users and personas

### 6.1 Duty Manager — Priya
- **Role:** Shift duty manager for Terminal 2.
- **Context:** On her feet, on the apron and in the ops room, from 06:00 to 14:00. Carries a tablet. Handles 40–60 calls a shift.
- **Goal:** Know within a minute when a bag flow problem starts, and know who to call.
- **Pain today:** Learns about a problem when the airline calls. Has to check three screens to understand a single delay.
- **Success looks like:** One screen shows her the whole terminal's baggage flow, with red flags for anything at risk.

### 6.2 Baggage Services Supervisor — Marco
- **Role:** Runs the baggage hall crew for Terminal 4.
- **Context:** On the floor with the crew, hands-on, deals with jams and misreads.
- **Goal:** Know where the jam is and how many bags it is affecting before the crew walks over.
- **Pain today:** Walks to a belt to find out what is wrong. Wastes 5–10 minutes per incident.
- **Success looks like:** An alert tells him the belt, the number of bags affected, and the flight at risk.

### 6.3 Airline Liaison Officer — Chen
- **Role:** Daily contact for airline operations teams.
- **Context:** In an office, reviews yesterday's performance every morning.
- **Goal:** A one-page report showing yesterday's baggage performance by airline, so he can answer airline queries without digging.
- **Pain today:** Builds the report by hand from three systems every morning. Takes 90 minutes.
- **Success looks like:** Opens a report, sends it, done.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-01 | The system shall show, in real time, the position of every departing bag from check-in to aircraft side. | Must | Core purpose of the tool. |
| FR-02 | The system shall calculate, for every bag, the time remaining until its flight's baggage close-out. | Must | Needed to know which bags are at risk. |
| FR-03 | The system shall flag a bag as "at risk" when the time remaining falls below the flight's minimum connection time. | Must | Consistent rule across all terminals. |
| FR-04 | The duty manager shall be able to see all at-risk bags in their terminal on a single screen. | Must | One screen, one view. |
| FR-05 | The system shall raise an alert to the relevant supervisor when a belt, sorter, or carousel stops for more than 60 seconds. | Must | Fast reaction to jams. |
| FR-06 | The system shall show, for each alert, the affected belt or carousel, the number of bags affected, and the flights at risk. | Must | Give the supervisor enough to act. |
| FR-07 | The supervisor shall be able to acknowledge an alert and record the action taken. | Must | Audit trail of staff response. |
| FR-08 | The system shall group individual bag alerts into a single incident when they share the same cause. | Should | Prevent alert fatigue. |
| FR-09 | The duty manager shall be able to see all open incidents across all terminals. | Should | Cross-terminal awareness. |
| FR-10 | The system shall produce a daily baggage performance report by airline. | Must | Airline liaison requirement. |
| FR-11 | The system shall allow the duty manager to add a free-text note to any incident. | Should | Context for later review. |
| FR-12 | The system shall allow the duty manager to export the day's incidents as a spreadsheet. | Could | Ad-hoc requests from airlines. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | The system shall capture for every bag: bag tag number, flight number, terminal, current position, time at each scan point, and current status. | Must | Minimum dataset for flow monitoring. |
| DR-02 | The system shall capture for every flight: airline code, flight number, scheduled departure, baggage close-out time, and terminal. | Must | Needed to compute time remaining. |
| DR-03 | The system shall capture for every incident: start time, end time, affected belt or carousel, affected bags, flights at risk, actions taken, and the supervisor who acknowledged. | Must | Audit and reporting. |
| DR-04 | The system shall retain incident records for 24 months. | Must | Airline contractual requirement. |
| DR-05 | The system shall retain bag position history for 7 days. | Must | Enough for a full shift review. |
| DR-06 | The system shall reject bag records with a missing tag number or flight number. | Must | Data quality at the source. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | Bags tagged as "diplomatic" or "hazardous" must never be re-routed without authorisation from the Duty Manager. | Company policy | Must |
| BR-02 | No alert may be raised for a bag on a flight that has already closed. | Operational practice | Must |
| BR-03 | Every alert must be acknowledged or dismissed within 15 minutes. | Service level | Must |
| BR-04 | Baggage performance data shared with airlines must exclude passenger personal data. | Data protection | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|---|
| AR-01 | The daily baggage performance report shall show, per airline: bags handled, bags delayed, bags missed, and average processing time. | Airline liaison | Daily | 24 months |
| AR-02 | The incident log shall show every incident with timings and actions. | Duty managers, Safety & Compliance | On demand | 24 months |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | The screen shall update within 5 seconds of a bag moving. | 5 s |
| NFR-02 | Availability | The system shall be available 99.9% of the time between 04:00 and 24:00. | 99.9% |
| NFR-03 | Capacity | The system shall handle 120,000 bag events per day across all terminals. | 120k/day |
| NFR-04 | Security | Only authenticated staff with a "Baggage Ops" role shall see bag-level data. | Role-based |
| NFR-05 | Auditability | Every alert acknowledgement shall record who, when, and what action was taken. | Full trace |
| NFR-06 | Usability | A duty manager shall be able to answer "is my terminal healthy right now?" in under 10 seconds. | ≤10 s |
| NFR-07 | Compliance | The system shall comply with UK GDPR and the CAA's 2027 reporting requirement. | Full |
| NFR-08 | Recoverability | The system shall restore service within 30 minutes of a failure. | ≤30 min |

---

## 9. User journeys

### 9.1 Journey: Morning peak — spotting a jam
- **Trigger:** A belt in Terminal 2 stops at 07:42 during the morning bank.
- **Steps:** The system detects the stop after 60 seconds → raises an alert → Marco (Terminal 2 supervisor) sees the alert on his tablet → he walks to the belt with the exact location, the 34 bags affected, and the 3 flights at risk → he clears the jam in 4 minutes → he acknowledges the alert with a note "tag reader fault, cleared".
- **Outcome:** Bags recovered, no missed flights, alert closed with a full record.
- **Failure path:** If Marco does not acknowledge within 15 minutes, the system escalates to the duty manager.

### 9.2 Journey: A bag at risk on a closing flight
- **Trigger:** A transfer bag arrives at the sorter 8 minutes before close-out, 2 minutes short of the minimum.
- **Steps:** The system flags the bag → the duty manager sees a red flag on the "at risk" screen → she calls the airline desk → the airline decides to hold the flight for 3 minutes → the bag is loaded → the system marks it as "recovered" with the airline decision recorded.
- **Outcome:** Flight held by 3 minutes, bag loaded, decision recorded.
- **Failure path:** If the airline refuses to hold, the bag is offloaded and marked "missed". The reason is recorded.

### 9.3 Journey: Morning airline report
- **Trigger:** 08:00, Chen opens his laptop.
- **Steps:** He opens the daily report → sees yesterday's numbers per airline → exports it as a PDF → sends it to the four main airlines before 09:00.
- **Outcome:** Report delivered on time, no manual work.
- **Failure path:** If the report fails, he falls back to the old manual process for one day.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | Every bag is visible from check-in to aircraft side within 5 seconds of each scan. | Live test during a peak hour |
| AC-02 | At-risk bags are correctly identified for 100% of test cases. | Scripted test with 50 known bags |
| AC-03 | Alerts for belt stops are raised within 90 seconds. | Timed test with a controlled stop |
| AC-04 | Every alert can be acknowledged and recorded. | Demo with duty managers |
| AC-05 | Daily report matches a manual count for a full day. | Side-by-side comparison |
| AC-06 | No personal data appears in airline reports. | Inspection by Data Protection Officer |
| AC-07 | The system runs for 30 days with 99.9% availability. | Monthly service report |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Belt control system feed is slower than promised. | M | H | Early technical trial with Baggage Services before full build. |
| R-02 | Duty managers find the screen too crowded. | M | M | Co-design workshops with four duty managers from week 1. |
| R-03 | Airline data is incomplete for some carriers. | M | M | Report incomplete data as "unknown" rather than excluding it. |
| R-04 | Wi-Fi blackspots on the apron. | L | M | Coverage survey before go-live, tablets cached for short outages. |
| R-05 | Staff see the tool as extra work. | M | H | Involve supervisors in design; keep the "acknowledge" step to one tap. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| Preventable missed bags per 1,000 | 1.1 | 0.7 | 3 months after go-live |
| Time from belt stop to supervisor arrival | 12 min | 6 min | 3 months after go-live |
| Daily airline report preparation time | 90 min | 5 min | 1 month after go-live |
| Duty manager satisfaction with visibility | 2.5 / 5 | 4.0 / 5 | 3 months after go-live |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| AODB | Airport Operational Database — the system of record for flights. |
| Bag tag | The barcode label attached to a bag at check-in. |
| Baggage close-out | The deadline by which a bag must be loaded onto its flight. |
| Belt | The conveyor that moves bags between zones. |
| Carousel | The rotating make-up area where bags are sorted into carts. |
| Duty manager | The senior operational staff member on shift for a terminal. |
| Incident | A group of related alerts treated as one problem. |
| Make-up | The area where bags are loaded into carts for the aircraft. |
| Missed bag | A bag that does not travel on its ticketed flight. |
| Sorter | The automated system that reads bag tags and routes bags. |
| Supervisor | The hands-on leader of the baggage hall crew. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | Will Terminal 3's older sorters provide the same feed as Terminals 1, 2, and 4? | Baggage Services | 2026-10-01 | Open |
| Q-02 | Which four airlines will receive the daily report in phase 1? | Commercial | 2026-10-15 | Open |
| Q-03 | What is the approved escalation policy when no one acknowledges an alert? | Ops Programme Office | 2026-10-20 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (COO) | `[name]` | | |
| Product owner (Head of Terminal Ops) | `[name]` | | |
| Technical lead (IT) | `[name]` | | |
| Compliance / risk | `[name]` | | |

---

*End of document.*