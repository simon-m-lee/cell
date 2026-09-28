# Business Requirements Document (BRD)

## Freight Rail Intermodal

| Field | Value |
|---|---|
| Project name | Rail Yard Flow Watch |
| Document title | Business Requirements — Freight Rail Intermodal Yard Operations |
| Version | 1.0 |
| Date | 2026-09-27 |
| Author | Network Operations Programme Office |
| Reviewer(s) | Head of Terminal Operations, Yard Master, Intermodal Planning Manager |
| Approver(s) | Chief Operating Officer, Head of Safety & Compliance |
| Status | Approved |

**Revision history**

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | 2026-08-25 | Network Ops Programme Office | First draft |
| 1.0 | 2026-09-27 | Network Ops Programme Office | Approved after review with Terminal Ops and Intermodal Planning |

---

## 2. Executive summary

Every day, thousands of containers move through our intermodal rail yards — arriving by road on drayage trucks, lifted onto railcars by gantry cranes, and dispatched on freight trains to inland terminals and ports. When a container misses its train, the box sits idle, the rail slot goes unused, the customer's supply chain slips, and we pay demurrage. Today, our yard teams find out about a missed connection only when the train has already departed — often hours later. We need a simple tool that watches container flow in real time, spots problems before they become missed connections, and gives the yard master one clear view of what is happening right now. This document sets out what that tool must do, for whom, and how we will know it is working.

---

## 3. Business context

### 3.1 Background
Our network handles around 12,000 container lifts per day across four intermodal yards. A container arrives by drayage truck, is grounded in a stack block, then lifted onto a railcar for a scheduled train. A container has roughly 45 minutes from gate-in to rail cut-off for a short-haul intermodal service. When a container is delayed — because a crane went down, a chassis was unavailable, or a block was congested — the container is flagged as "at risk" and the yard master must decide whether to hold the train or roll the container to the next service. Both choices cost money.

### 3.2 Problem statement
Right now, we have no single view of container flow. The gate system, the crane control system, and the terminal operating system (TOS) each report their own status to their own screen. The yard master learns about a problem when the train dispatcher calls, or when the customer escalates. By then, the container is often already missing its train. We estimate that around 1 in 750 containers is delayed in a way that could have been prevented if we had known 10 minutes earlier.

### 3.3 Business drivers
- **Demurrage and per diem.** Missed connections cost us money in demurrage charges and, in some cases, contractual penalties.
- **Customer experience.** On-time rail performance is one of the top three service metrics our customers track.
- **Regulatory pressure.** The Office of Rail and Road has asked all major intermodal operators to demonstrate real-time service performance reporting from 2027.
- **Staffing pressure.** Our yard masters are already stretched. They need fewer screens, not more.

### 3.4 Alignment with strategy
Our 2025–2028 network strategy names "operational visibility" as one of four pillars. This project delivers a first, concrete step in that direction, without replacing any of the systems we already have.

---

## 4. Scope

### 4.1 In scope
- Real-time monitoring of container movement from gate-in to rail dispatch for outbound containers.
- A single yard-master view of current container flow across all yards.
- Automatic alerts when a container or a group of containers is at risk of missing its train.
- A record of every alert and every action taken by staff.
- A daily report for the customer service team.

### 4.2 Out of scope
- Inbound containers and transhipment containers. These will be covered in a later phase.
- Replacing the gate system, crane control system, or TOS.
- Automatic re-routing of containers. Staff will still make the decisions.
- Customer-facing apps or notifications.
- Container tracking beyond the rail departure.
- Anything outside the four intermodal yards at this terminal.

### 4.3 Assumptions
- The gate system can provide container position updates at least every 20 seconds.
- Each container's ID is scanned at every handover point (gate-in, stack block, crane lift, railcar load).
- The rail systems provide train departure times through the existing TOS.
- The yard has enough Wi-Fi coverage for tablets on the ground.
- Yard masters will use the tool on the existing tablet devices.

### 4.4 Constraints
- No new hardware on the cranes in this phase.
- Must go live before the 2027 peak season.
- Must use the existing single sign-on for staff login.
- Must not disrupt the live yard operation during rollout.
- Budget capped at the amount approved in the Q3 board paper.

### 4.5 Dependencies
- Gate system must expose a real-time feed (Terminal Ops team).
- TOS must expose train departure times (IT team, already available).
- Yard Wi-Fi coverage confirmed for Yards 1 and 4 (Infrastructure team).
- Customer service team must agree the daily report format (Commercial team).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
|---|---|---|---|---|
| Sponsor | Chief Operating Officer | Cost, reputation, regulatory readiness | H | Monthly steering |
| Primary user | Yard Masters (4 yards) | One clear view, fewer calls | H | Weekly workshops |
| Primary user | Intermodal Supervisors | Faster response to crane jams | H | Weekly workshops |
| Reviewer | Customer Service Team | Reporting accuracy | M | Bi-weekly review |
| Reviewer | Safety & Compliance | No impact on safety rules | M | Sign-off before go-live |
| Regulator | Office of Rail and Road | Reporting from 2027 | L | Quarterly update |

---

## 6. Users and personas

### 6.1 Yard Master — Amara
- **Role:** Shift yard master for Yard 2.
- **Context:** On her feet, on the ground and in the yard office, from 06:00 to 14:00. Carries a tablet. Handles 50–70 calls a shift.
- **Goal:** Know within a minute when a container flow problem starts, and know who to call.
- **Pain today:** Learns about a problem when the train dispatcher calls. Has to check three screens to understand a single delay.
- **Success looks like:** One screen shows her the whole yard's container flow, with red flags for anything at risk.

### 6.2 Intermodal Supervisor — Diego
- **Role:** Runs the yard crew for Yard 4.
- **Context:** On the ground with the crew, hands-on, deals with crane jams and misreads.
- **Goal:** Know where the jam is and how many containers it is affecting before the crew walks over.
- **Pain today:** Walks to a crane to find out what is wrong. Wastes 5–10 minutes per incident.
- **Success looks like:** An alert tells him the crane, the number of containers affected, and the train at risk.

### 6.3 Customer Service Officer — Lena
- **Role:** Daily contact for customer operations teams.
- **Context:** In an office, reviews yesterday's performance every morning.
- **Goal:** A one-page report showing yesterday's intermodal performance by customer, so she can answer customer queries without digging.
- **Pain today:** Builds the report by hand from three systems every morning. Takes 90 minutes.
- **Success looks like:** Opens a report, sends it, done.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-01 | The system shall show, in real time, the position of every outbound container from gate-in to rail dispatch. | Must | Core purpose of the tool. |
| FR-02 | The system shall calculate, for every container, the time remaining until its train's cut-off. | Must | Needed to know which containers are at risk. |
| FR-03 | The system shall flag a container as "at risk" when the time remaining falls below the train's minimum connection time. | Must | Consistent rule across all yards. |
| FR-04 | The yard master shall be able to see all at-risk containers in their yard on a single screen. | Must | One screen, one view. |
| FR-05 | The system shall raise an alert to the relevant supervisor when a crane, sorter, or block stops for more than 60 seconds. | Must | Fast reaction to jams. |
| FR-06 | The system shall show, for each alert, the affected crane or block, the number of containers affected, and the trains at risk. | Must | Give the supervisor enough to act. |
| FR-07 | The supervisor shall be able to acknowledge an alert and record the action taken. | Must | Audit trail of staff response. |
| FR-08 | The system shall group individual container alerts into a single incident when they share the same cause. | Should | Prevent alert fatigue. |
| FR-09 | The yard master shall be able to see all open incidents across all yards. | Should | Cross-yard awareness. |
| FR-10 | The system shall produce a daily intermodal performance report by customer. | Must | Customer service requirement. |
| FR-11 | The yard master shall be able to add a free-text note to any incident. | Should | Context for later review. |
| FR-12 | The yard master shall be able to export the day's incidents as a spreadsheet. | Could | Ad-hoc requests from customers. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | The system shall capture for every container: container ID, train ID, yard, current position, time at each scan point, and current status. | Must | Minimum dataset for flow monitoring. |
| DR-02 | The system shall capture for every train: operator code, train ID, scheduled departure, cut-off time, and yard. | Must | Needed to compute time remaining. |
| DR-03 | The system shall capture for every incident: start time, end time, affected crane or block, affected containers, trains at risk, actions taken, and the supervisor who acknowledged. | Must | Audit and reporting. |
| DR-04 | The system shall retain incident records for 24 months. | Must | Customer contractual requirement. |
| DR-05 | The system shall retain container position history for 7 days. | Must | Enough for a full shift review. |
| DR-06 | The system shall reject container records with a missing container ID or train ID. | Must | Data quality at the source. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | Containers tagged as "hazardous" or "temperature-controlled" must never be re-routed without authorisation from the Yard Master. | Company policy | Must |
| BR-02 | No alert may be raised for a container on a train that has already departed. | Operational practice | Must |
| BR-03 | Every alert must be acknowledged or dismissed within 15 minutes. | Service level | Must |
| BR-04 | Intermodal performance data shared with customers must exclude commercial-sensitive data. | Data protection | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|---|
| AR-01 | The daily intermodal performance report shall show, per customer: containers handled, containers delayed, containers rolled, and average processing time. | Customer service | Daily | 24 months |
| AR-02 | The incident log shall show every incident with timings and actions. | Yard masters, Safety & Compliance | On demand | 24 months |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | The screen shall update within 5 seconds of a container moving. | 5 s |
| NFR-02 | Availability | The system shall be available 99.9% of the time between 04:00 and 24:00. | 99.9% |
| NFR-03 | Capacity | The system shall handle 30,000 container events per day across all yards. | 30k/day |
| NFR-04 | Security | Only authenticated staff with a "Yard Ops" role shall see container-level data. | Role-based |
| NFR-05 | Auditability | Every alert acknowledgement shall record who, when, and what action was taken. | Full trace |
| NFR-06 | Usability | A yard master shall be able to answer "is my yard healthy right now?" in under 10 seconds. | ≤10 s |
| NFR-07 | Compliance | The system shall comply with UK GDPR and the ORR's 2027 reporting requirement. | Full |
| NFR-08 | Recoverability | The system shall restore service within 30 minutes of a failure. | ≤30 min |

---

## 9. User journeys

### 9.1 Journey: Morning peak — spotting a crane jam
- **Trigger:** A gantry crane in Yard 2 stops at 07:42 during the morning bank.
- **Steps:** The system detects the stop after 60 seconds → raises an alert → Diego (Yard 2 supervisor) sees the alert on his tablet → he walks to the crane with the exact location, the 28 containers affected, and the 3 trains at risk → he clears the jam in 4 minutes → he acknowledges the alert with a note "spreader fault, cleared".
- **Outcome:** Containers recovered, no missed trains, alert closed with a full record.
- **Failure path:** If Diego does not acknowledge within 15 minutes, the system escalates to the yard master.

### 9.2 Journey: A container at risk on a closing train
- **Trigger:** A container arrives at the stack block 8 minutes before cut-off, 2 minutes short of the minimum.
- **Steps:** The system flags the container → the yard master sees a red flag on the "at risk" screen → she calls the train dispatcher → the dispatcher decides to hold the train for 3 minutes → the container is loaded → the system marks it as "recovered" with the dispatcher decision recorded.
- **Outcome:** Train held by 3 minutes, container loaded, decision recorded.
- **Failure path:** If the dispatcher refuses to hold, the container is rolled to the next service and marked "rolled". The reason is recorded.

### 9.3 Journey: Morning customer report
- **Trigger:** 08:00, Lena opens her laptop.
- **Steps:** She opens the daily report → sees yesterday's numbers per customer → exports it as a PDF → sends it to the four main customers before 09:00.
- **Outcome:** Report delivered on time, no manual work.
- **Failure path:** If the report fails, she falls back to the old manual process for one day.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | Every container is visible from gate-in to rail dispatch within 5 seconds of each scan. | Live test during a peak hour |
| AC-02 | At-risk containers are correctly identified for 100% of test cases. | Scripted test with 50 known containers |
| AC-03 | Alerts for crane stops are raised within 90 seconds. | Timed test with a controlled stop |
| AC-04 | Every alert can be acknowledged and recorded. | Demo with yard masters |
| AC-05 | Daily report matches a manual count for a full day. | Side-by-side comparison |
| AC-06 | No commercial-sensitive data appears in customer reports. | Inspection by Data Protection Officer |
| AC-07 | The system runs for 30 days with 99.9% availability. | Monthly service report |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Gate system feed is slower than promised. | M | H | Early technical trial with Terminal Ops before full build. |
| R-02 | Yard masters find the screen too crowded. | M | M | Co-design workshops with four yard masters from week 1. |
| R-03 | Customer data is incomplete for some carriers. | M | M | Report incomplete data as "unknown" rather than excluding it. |
| R-04 | Wi-Fi blackspots on the yard. | L | M | Coverage survey before go-live, tablets cached for short outages. |
| R-05 | Staff see the tool as extra work. | M | H | Involve supervisors in design; keep the "acknowledge" step to one tap. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| Preventable rolled containers per 1,000 | 1.3 | 0.8 | 3 months after go-live |
| Time from crane stop to supervisor arrival | 14 min | 7 min | 3 months after go-live |
| Daily customer report preparation time | 90 min | 5 min | 1 month after go-live |
| Yard master satisfaction with visibility | 2.4 / 5 | 4.0 / 5 | 3 months after go-live |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| Block | A stack area in the yard where containers are grounded. |
| Container ID | The unique identifier on a container (e.g. MSCU1234567). |
| Crane | The gantry crane that lifts containers between truck, stack, and railcar. |
| Cut-off | The deadline by which a container must be loaded onto its train. |
| Demurrage | A charge for keeping a container beyond its free time. |
| Gate-in | The point at which a drayage truck enters the yard. |
| Incident | A group of related alerts treated as one problem. |
| Intermodal | The movement of freight by more than one mode (road + rail). |
| Rolled | A container that does not travel on its booked train. |
| TOS | Terminal Operating System — the system of record for yard moves. |
| Yard Master | The senior operational staff member on shift for a yard. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | Will Yard 3's older cranes provide the same feed as Yards 1, 2, and 4? | Terminal Ops | 2026-10-01 | Open |
| Q-02 | Which four customers will receive the daily report in phase 1? | Commercial | 2026-10-15 | Open |
| Q-03 | What is the approved escalation policy when no one acknowledges an alert? | Network Ops Programme Office | 2026-10-20 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (COO) | `[name]` | | |
| Product owner (Head of Terminal Ops) | `[name]` | | |
| Technical lead (IT) | `[name]` | | |
| Compliance / risk | `[name]` | | |

---
