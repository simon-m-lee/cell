# Business Requirements Document (BRD)

## Warehouse AMR Fleet Control

| Field | Value |
|---|---|
| Project name | Fleet Watch |
| Document title | Business Requirements — Warehouse Autonomous Mobile Robot Fleet Control |
| Version | 1.0 |
| Date | 2026-10-01 |
| Author | Robotics Operations Programme Office |
| Reviewer(s) | Head of Warehouse Robotics, Site Safety Manager, Fulfilment Shift Managers |
| Approver(s) | VP Fulfilment, Head of Health & Safety, Senior Information Risk Owner |
| Status | Approved |

**Revision history**

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | 2026-09-16 | Robotics Ops Programme Office | First draft after aisle-pinch near-miss review |
| 1.0 | 2026-10-01 | Robotics Ops Programme Office | Approved after review with Robotics, H&S, and Shift |

---

## 2. Executive summary

Every day this fulfilment campus runs about 220 autonomous mobile robots across three halls, moving totes between reserve racks, pick stations, and outbound docks. A robot is not a toy on a demo floor: it shares aisles with people, carries 30 kg totes, and can close a pinch point faster than a marshal can shout. When a robot loses localisation, a charger aisle blocks, or a person walks into a keep-out cell, the first signal today is often a pile-up of waiting stations or a pulled e-stop that nobody can later place on a map. We need a simple tool that watches the fleet in real time, flags a zone before it becomes a jam or an injury, protects cells we must never send a robot into while a person is present, and gives the robotics controller one view of what is happening right now plus an audit trail Safety and the insurer can read but not change. This document sets out what that tool must do, for whom, and how we will know it is working.

---

## 3. Business context

### 3.1 Background
Hall A is goods-to-person, Hall B is mixed case, Hall C is outbound staging. Robots report pose, battery, mission, and safety state several times a second to the vendor fleet manager. Company practice treats **a zone with 8 or more robots stopped for more than 45 seconds**, or **any robot in e-stop or localisation-lost for more than 20 seconds inside an aisle that still has a live mission**, or **a person badge in a keep-out cell**, as at risk. A keep-out cell (charge farm, inbound dock plate, maintenance cage) must never receive a new mission while a person is badged inside. A robot that has dropped a tote in a travel lane is a safety event until a marshal acknowledges clear.

### 3.2 Problem statement
Right now the fleet lives on three surfaces: the vendor’s colourful map, the warehouse management work-queue, and a radio channel the marshals use. The robotics controller learns a pinch has formed when pick stations starve, or when a marshal walks into a cluster of robots waiting on a blocked node. Near-misses are written in a book at end of shift. We estimate that around 1 in 90 robot-hours last quarter included a stop longer than two minutes that would have been visible 30 seconds after the first blockage if pose, e-stop, and people-in-cell had sat on one screen. Average time from “zone frozen” to “controller looking at the right aisle” is 4 minutes, against a 45-second target. After the last aisle-pinch near-miss, the insurer asked who sent a robot into a cell with a person; we could not answer from one file.

### 3.3 Business drivers
- **People safety.** Shared aisles are how a 30 kg tote and a person occupy the same metre.
- **Throughput.** A frozen zone starves 20 pick stations in under two minutes.
- **Regulatory pressure.** UK PUWER, the robotics code of practice the site adopted, and the insurer’s condition after the near-miss all require a reconstructable safety-state log.
- **Security.** A robot that leaves the geofence, or a laptop that can send a mission from the public warehouse Wi-Fi, is a security event. Mission rights must follow role, not a shared vendor password.
- **Staffing pressure.** Nights have one robotics controller for 220 robots. They need one screen, not the vendor map plus a radio.

### 3.4 Alignment with strategy
The 2026–2028 fulfilment plan names “robots and people on one picture” as the safety-and-flow pillar. This project is a first step. It does not replace the vendor fleet manager, the WMS, or the physical e-stop circuit.

---

## 4. Scope

### 4.1 In scope
- Real-time monitoring of every robot on the campus: pose zone, mission, battery, safety state.
- A single robotics-controller view of frozen zones, e-stops, localisation-lost, dropped totes, and people in keep-out cells.
- Automatic alerts when a zone or robot crosses the at-risk rule.
- A keep-out register that Safety maintains and that new missions must honour.
- A record of every alert, every e-stop, every clear, every keep-out change, and every acknowledgement, in an append-only log.
- A daily safety and availability summary for H&S and the site director.

### 4.2 Out of scope
- Replacing the vendor fleet manager or rewriting path planning.
- Automatic motion after an e-stop. A person still resets hardware.
- Changing pick algorithms or slotting.
- Other campuses in this phase.
- Collaborative arms on the pack benches (a later phase).
- Customer-order content on the robotics screen.

### 4.3 Assumptions
- The vendor fleet manager can emit robot state at least every 1 second.
- Each robot has a stable asset ID that matches maintenance.
- People entering keep-out cells badge at the gate already used for lock-out.
- Controllers will use the tool on the existing control-room workstation and a floor tablet.
- Hardware e-stops remain the last safety layer even if this tool is down.

### 4.4 Constraints
- No new robot firmware in this phase unless the vendor already exposes the fields.
- Must be live before the 2027 peak season.
- Must use existing single sign-on. Shared vendor passwords are retired for daily use.
- Must not command motion. This tool watches, records, and may request a mission-cancel through the existing approved API only when a controller acknowledges.
- Must not show customer names or order lines — robot, zone, tote ID only.
- Must not sit on a network path that can be reached from guest Wi-Fi.

### 4.5 Dependencies
- Fleet-manager state feed (Robotics vendor / OT).
- Keep-out badge feed (Site access control).
- WMS station-starvation flag (Fulfilment IT) — optional for context, not for safety.
- Insurer log column agreement (H&S).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
|---|---|---|---|---|
| Sponsor | VP Fulfilment | Flow, claims, peak readiness | H | Monthly steering |
| Primary user | Robotics controllers | One view, earlier freeze | H | Weekly workshops |
| Primary user | Floor marshals | Where to walk | H | Weekly workshops |
| Reviewer | Health & Safety | Near-miss file | M | Sign-off before go-live |
| Reviewer | SIRO / Security | Mission rights, network path | M | Sign-off before go-live |
| External | Insurer / HSE if asked | Reconstructable state | L | After incidents |

---

## 6. Users and personas

### 6.1 Robotics Controller — Lev
- **Role:** Night controller, 220 robots, three halls.
- **Context:** Desk with the vendor map and a radio. One marshal per hall.
- **Goal:** Know within 45 seconds which zone is frozen and whether a person is in a keep-out cell.
- **Pain today:** Sees stations starve, then pans the vendor map.
- **Success looks like:** An alert names the zone, robot count stopped, e-stop or lost-localisation count, and people in cell.

### 6.2 Floor Marshal — Io
- **Role:** Hall B marshal.
- **Context:** On foot with a tablet and an e-stop lanyard.
- **Goal:** Walk to the right node with the robot ID and the reason, not a guess.
- **Pain today:** Radio says “somewhere in B-aisle 7”.
- **Success looks like:** Alert with node, robot, and “person in cage” or “tote down”.

### 6.3 Site Safety Manager — Ruth
- **Role:** Builds the near-miss and insurer file.
- **Context:** Office. Needs who sent a mission, who cleared, who was in the cell.
- **Goal:** A pack with no customer data and no deleted rows.
- **Pain today:** Vendor export plus a paper book.
- **Success looks like:** Opens the log, exports, files. Cannot delete a row.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-01 | The system shall show, in real time, every robot: ID, hall, zone, mission state, battery, safety state. | Must | Core purpose. |
| FR-02 | The system shall flag a zone as “at risk” when 8 or more robots have been stopped there for more than 45 seconds. | Must | Pinch rule. |
| FR-03 | The system shall flag a robot as “at risk” when e-stop or localisation-lost lasts more than 20 seconds on a live mission. | Must | Individual fail. |
| FR-04 | The system shall flag a keep-out cell as “blocked” when a person badge is present, and shall treat a new mission into that cell as forbidden. | Must | People first. |
| FR-05 | The controller shall see all at-risk zones, at-risk robots, and blocked cells on one screen. | Must | One view. |
| FR-06 | The system shall raise an alert when a tote is reported down in a travel lane. | Must | Trip and crush risk. |
| FR-07 | Each alert shall name hall, zone or node, robot IDs, people-in-cell count, and seconds stopped. | Must | Enough to act. |
| FR-08 | The controller or marshal shall acknowledge with clear-aisle, recover-robot, cancel-mission, lock-cell, or escalate-to-safety. | Must | Audit trail. |
| FR-09 | The system shall refuse to record a mission-cancel into a keep-out cell as “complete” unless a marshal has acknowledged the cell empty. | Must | Do not restart blind. |
| FR-10 | Safety shall add or remove a keep-out cell while the system is running. | Must | Live policy. |
| FR-11 | No second at-risk alert for the same zone and same cause until the first is acknowledged or closed. | Must | Fatigue. |
| FR-12 | Daily safety and availability summary. | Must | Reporting. |
| FR-13 | Notes shall not contain colleague medical details or customer order lines. | Must | Privacy. |
| FR-14 | Escalate when an at-risk alert is unacknowledged for 60 seconds. | Must | Night pace. |
| FR-15 | A cancelled mission shall not be silently re-queued into the same blocked cell. | Must | Repeat pinch. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | Capture for every tick: robot ID, zone, pose-grid, mission ID, safety state, battery, people-in-cell for keep-out cells. | Must | Minimum dataset. |
| DR-02 | Capture for every incident: start, end, action, who acknowledged, robot IDs involved. | Must | File. |
| DR-03 | Retain incidents for 36 months. | Must | Insurer / HSE. |
| DR-04 | Retain high-rate ticks for 7 days. | Must | Pinch reconstruction. |
| DR-05 | Reject a tick with a missing robot ID or zone. | Must | Data quality. |
| DR-06 | Do not persist customer names or order SKUs. | Must | Need-to-know. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | No new mission into a keep-out cell while a person is badged inside. | H&S | Must |
| BR-02 | Hardware e-stop always wins. This tool never clears an e-stop. | PUWER / vendor | Must |
| BR-03 | No new alert for the same zone and cause while open. | Practice | Must |
| BR-04 | Safety and insurer views are read-only and cannot delete a row. | Regulatory / insurance | Must |
| BR-05 | Shared vendor passwords shall not be used to acknowledge an alert. | Security | Must |
| BR-06 | A robot reported outside the geofence is a security incident, not only a navigation fault. | Security | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|---|
| AR-01 | Daily summary: robot-hours, frozen zones, e-stops, localisation-lost, people-in-cell events, tote-down, median time to acknowledge. | H&S, site director | Daily | 36 months |
| AR-02 | Incident log with timings and actions. | Controllers, Safety, insurer | On demand | 36 months |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | Screen updates within 2 seconds of a fleet-manager sample. | 2 s |
| NFR-02 | Availability | 99.9% whenever the halls are open. | 99.9% |
| NFR-03 | Capacity | 20 million state samples per day across 220 robots. | 20M/day |
| NFR-04 | Security | Only “Robotics Control” or “Marshal” see live poses. Safety is read-only plus register admin. | Role-based |
| NFR-05 | Security | No path from guest Wi-Fi. No motion command except acknowledged cancel on the approved API. | Network + watch |
| NFR-06 | Auditability | Every acknowledgement records who, when, what. | Full trace |
| NFR-07 | Usability | Controller answers “where is the freeze?” in under 5 seconds. | ≤5 s |
| NFR-08 | Compliance | Supports PUWER record-keeping and UK GDPR. | Full |
| NFR-09 | Recoverability | Live view back within 10 minutes; log intact. Hardware e-stops remain live throughout. | ≤10 min |

---

## 9. User journeys

### 9.1 Journey: Night pinch in Hall B
- **Trigger:** Node B-7-14 blocks at 02:11. Twelve robots stop behind it.
- **Steps:** Zone at-risk at 02:12 → Lev sees B-7 and 12 stopped robots → Io walks to B-7-14 → dropped tote found → Io acknowledges clear-aisle → missions resume. No second alert while open.
- **Outcome:** Stations recover. File shows who cleared.
- **Failure path:** Unacknowledged at 02:13, escalate to the site duty phone.

### 9.2 Journey: Person in the charge farm
- **Trigger:** Maintenance badges into charge cage C-02 at 10:40. A robot still has a “go charge” mission.
- **Steps:** Cell blocked → new mission refused → Lev cancels the pending charge mission after Io confirms the person is inside → robot waits outside the geofence of the cage.
- **Outcome:** No robot enters a cell with a person. Attempt is in the log.
- **Failure path:** If the badge feed is down, the cage is treated as blocked until Safety acknowledges otherwise.

### 9.3 Journey: Robot outside the geofence
- **Trigger:** Robot R-188 reports a pose in the public corridor.
- **Steps:** Security incident + at-risk → missions cancelled → marshal recovers → SIRO notified from the same log.
- **Outcome:** Treated as security, not only navigation.

### 9.4 Journey: Morning Safety pack
- **Trigger:** 08:00 after the near-miss-worthy pinch.
- **Steps:** Ruth exports the log without order lines, files for the insurer.
- **Outcome:** Pack in 15 minutes. She cannot delete a row.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | Every robot visible within 2 seconds of a fleet-manager sample. | Live hall test |
| AC-02 | Zone and robot at-risk flags match the 8-robots / 45 s and 20 s rules on 25 scripted freezes. | Scripted test |
| AC-03 | New mission into a badged keep-out cell is refused and logged. | Floor test |
| AC-04 | Tool cannot clear a hardware e-stop. | Safety test |
| AC-05 | Safety role cannot delete a row. Acknowledgements require named SSO, not the vendor shared login. | Role test |
| AC-06 | Daily summary matches vendor counts for one day and has no order lines. | Side-by-side |
| AC-07 | 30 days at 99.9% availability with e-stops independent of the tool. | Service report |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Vendor feed drops samples at peak. | M | H | Trial on Hall B peak before campus roll-out. |
| R-02 | Controllers think the tool resets e-stops. | M | H | Written constraint; hardware test AC-04. |
| R-03 | Badge feed misses a person who tailgates. | M | H | Marshal still walks; camera procedure unchanged. |
| R-04 | Guest Wi-Fi can see the map. | L | H | Network segregation signed by SIRO. |
| R-05 | Alert flood during a hall-wide e-stop. | M | M | One incident per zone until clear. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| Time from zone freeze to controller on the right aisle | 4 min | 45 s | 3 months |
| Robot-hours with an unexplained stop >2 minutes | 1 in 90 | 1 in 250 | 6 months |
| Missions into a cell while a person is badged | Occurs | Zero | Every month |
| Safety pack time after a near-miss | Half a day | 15 min | 1 month |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| AMR | Autonomous mobile robot. |
| At risk | Zone or robot that has crossed a stop or safety-state rule. |
| Blocked cell | Keep-out cell with a person badge present. |
| E-stop | Emergency stop — hardware circuit this tool cannot clear. |
| Geofence | Permitted travel polygon. |
| Keep-out | Charge farm, dock plate, maintenance cage, or other cell people occupy. |
| Localisation-lost | Robot no longer knows its pose well enough to travel. |
| Marshal | Trained person who walks the floor and resets hardware. |
| Mission | Task the fleet manager assigned to a robot. |
| Pinch | Queue of robots behind a blocked node. |
| PUWER | Provision and Use of Work Equipment Regulations. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | Does Hall C outbound staging use the same keep-out badge gates as A and B? | Site access | 2026-10-20 | Open |
| Q-02 | Which mission-cancel API is already approved by the vendor and OT security? | Robotics OT | 2026-10-15 | Open |
| Q-03 | What wording is approved on the marshal tablet when a cell is blocked? | H&S | 2026-10-22 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (VP Fulfilment) | `[name]` | | |
| Product owner (Head of Warehouse Robotics) | `[name]` | | |
| Technical lead (OT / IT) | `[name]` | | |
| Health & Safety | `[name]` | | |
| SIRO | `[name]` | | |

---

*End of document.*
