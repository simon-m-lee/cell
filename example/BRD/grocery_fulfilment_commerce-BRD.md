# Business Requirements Document (BRD)

## Grocery Commerce Fulfilment

| Field | Value |
|---|---|
| Project name | Wave Desk |
| Document title | Business Requirements — Grocery Commerce Fulfilment |
| Version | 1.0 |
| Date | 2026-10-01 |
| Author | Fulfilment Operations Programme Office |
| Reviewer(s) | Head of Dark Stores, Cold-Chain Manager, Customer Promise Lead |
| Approver(s) | Chief Operating Officer, Head of Food Safety, Senior Information Risk Owner |
| Status | Approved |

**Revision history**

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | 2026-09-14 | Fulfilment Ops Programme Office | First draft after summer cut-off miss review |
| 1.0 | 2026-10-01 | Fulfilment Ops Programme Office | Approved after review with Dark Stores, Food Safety, and Promise |

---

## 2. Executive summary

Every day this urban grocery commerce network picks about 38,000 customer orders from six dark stores and two spoke chillers. An order is not a single tote: it is ambient, chill, and frozen lines that must meet a cut-off, a temperature band, and an allergen rule. When a wave runs late, a freezer door stays open, or a substitute lands on a “no pork / no nut” order, the customer either misses dinner or we ship a food-safety incident. Today the shift lead learns a wave is dying from a handheld that only shows the picker’s own list, a temperature logger that is read the next morning, and a complaints queue that opens after the van has left. We need a simple tool that watches every wave in real time, flags an order before it becomes a missed cut-off or a recall, protects baskets we must never substitute without a rule, and gives the shift lead one view of what is happening right now plus an audit trail Food Safety and Trading Standards can read but not change. This document sets out what that tool must do, for whom, and how we will know it is working.

---

## 3. Business context

### 3.1 Background
Each dark store holds roughly 14,000 SKUs across ambient, chill (0–5 °C), and frozen (at or below −18 °C). Customer slots are 1-hour windows. Company practice treats **25 minutes to cut-off with more than 15% of the wave still unpicked**, or **any chill tote above 5 °C for more than 8 minutes**, or **any frozen tote above −15 °C**, as at risk. A known-allergen substitute on an order that declared that allergen is a notifiable food-safety event. Alcohol and age-restricted lines must not leave the store without a recorded challenge at handover. High-value and infant-formula lines sit on a protected-pick list and must not be shorted into another customer’s tote.

### 3.2 Problem statement
Right now the wave lives on three surfaces: the warehouse management handheld, a separate temperature portal, and the customer-app promise board in a city office. The shift lead finds out a freezer aisle drifted when a driver refuses a soft tote at the dock, or when a customer photographs melted ice cream. Substitutes are applied by pickers against a “nearest SKU” list that does not see the household allergen flag. We estimate that around 1 in 220 orders last quarter missed the slot for a reason visible 12 minutes earlier if pick progress, tote temperature, and allergen flags had sat on one screen. Average time from “wave slipping” to “lead looking at the right aisle” is 9 minutes, against a 3-minute target. Trading Standards asked for a reconstructable substitute-and-temperature file after two complaints; it took three people a day.

### 3.3 Business drivers
- **Food safety.** Chill and frozen abuse, and allergen mistakes, are how people get hurt and how a brand is closed for a weekend.
- **Promise.** Missed cut-offs are the top reason customers cancel the next shop.
- **Regulatory pressure.** UK food-hygiene ratings, Natasha’s Law labelling on packed substitutes, Trading Standards, and the Food Standards Agency expect a timeline, not a story.
- **Shrink and security.** Infant formula, spirits, and razor blades walk if a short-pick can be dumped into an open tote without a name.
- **Staffing pressure.** A Friday peak has one lead covering 40 pickers. They need one screen.

### 3.4 Alignment with strategy
The 2026–2028 commerce plan names “on-time, in-temperature, honest substitutes” as the promise pillar. This project is a first step. It does not replace the warehouse system, the van-routing engine, or the customer app.

---

## 4. Scope

### 4.1 In scope
- Real-time monitoring of every open wave and tote in the six dark stores and two spoke chillers.
- A single shift-lead view of pick progress, tote temperature, cut-off risk, allergen flags, and protected lines.
- Automatic alerts when a wave or tote crosses the at-risk rule.
- A protected-line and allergen register that Food Safety maintains and that substitute decisions must honour.
- A record of every alert, every substitute, every short, every temperature excursion, and every acknowledgement, in an append-only log.
- A daily promise and food-safety summary for the city office and Food Safety.

### 4.2 Out of scope
- Van routing and driver tracking after the tote is sealed (existing transport desk).
- Replacing the warehouse management system or the customer app.
- Automatic substitution without the picker’s confirmation on the handheld.
- Supplier backhaul and depot wholesale.
- Other cities in this phase.
- Payment capture (already handled at checkout).

### 4.3 Assumptions
- The warehouse system can emit pick-progress and tote events at least every 15 seconds.
- Each order has a promise slot, a store, and a declared household-allergen list at release to pick.
- Chill and frozen totes carry a logger that reports at least every 60 seconds while the tote is open.
- Shift leads will use the tool on the existing lead tablet.
- Age-challenge at the door remains on the existing handover app; this tool only needs the pass/fail flag.

### 4.4 Constraints
- No new freezers in this phase.
- Must be live before the 2027 Christmas peak.
- Must use existing single sign-on and store roles.
- Must not send a price or a card number to the lead screen.
- Must not store customer addresses on the lead tablet; postcode sector is enough for the wave.
- Must not stop the pick if the tool is down — handheld WMS remains the pick path.

### 4.5 Dependencies
- WMS pick and tote feed (Fulfilment IT).
- Logger feed (Cold-Chain).
- Allergen and protected-line list (Food Safety).
- Slot / cut-off feed (Promise team).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
|---|---|---|---|---|
| Sponsor | Chief Operating Officer | Promise, complaints, rating | H | Monthly steering |
| Primary user | Dark-store shift leads | One view, earlier recover | H | Weekly workshops |
| Primary user | Cold-chain leads | Temperature excursions | H | Weekly workshops |
| Reviewer | Food Safety | Allergen and hygiene file | M | Sign-off before go-live |
| Reviewer | Customer Promise | Cut-off accuracy | M | Bi-weekly review |
| Regulator | FSA / Trading Standards / local EHO | Reconstructable file | L | Quarterly update |

---

## 6. Users and personas

### 6.1 Shift Lead — Noah
- **Role:** Friday-peak lead, Store 3, 40 pickers.
- **Context:** Walks ambient and the freezer. Radio and tablet.
- **Goal:** Know within two minutes which wave will miss cut-off and which tote is warm.
- **Pain today:** Learns from a driver at the dock.
- **Success looks like:** An alert names the wave, the aisle, the minutes to cut-off, and whether an allergen rule is in play.

### 6.2 Cold-Chain Lead — Farah
- **Role:** Responsible for chill and frozen integrity across two stores that day.
- **Context:** Shares time between plant alarms and the floor.
- **Goal:** See every tote above band before it is sealed.
- **Pain today:** Logger portal is yesterday.
- **Success looks like:** Live tote list with minutes out of band and the action taken.

### 6.3 Food Safety Officer — Gita
- **Role:** Builds the file after a complaint or an EHO visit.
- **Context:** Office. Needs substitute, temperature, and who acknowledged.
- **Goal:** A pack with no customer address and no deleted rows.
- **Pain today:** Three systems and a WhatsApp photo of a logger.
- **Success looks like:** Opens the log, exports, files.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-01 | The system shall show, in real time, every open wave: store, slot, lines remaining, tote count by temperature band. | Must | Core purpose. |
| FR-02 | The system shall calculate minutes to cut-off for every open wave. | Must | Promise. |
| FR-03 | The system shall flag a wave as “at risk” when minutes to cut-off are at or below 25 and more than 15% of lines are unpicked. | Must | Consistent rule. |
| FR-04 | The system shall flag a tote as “at risk” when chill is above 5 °C for more than 8 minutes, or frozen is above −15 °C at any sample. | Must | Food safety. |
| FR-05 | The shift lead shall see all at-risk waves and totes on one screen. | Must | One view. |
| FR-06 | The system shall refuse a substitute that matches a declared household allergen, and shall raise an alert if a picker attempts it. | Must | Allergen rule. |
| FR-07 | The system shall raise an alert when a protected line (infant formula, spirits, listed high-shrink) is shorted or moved to another tote. | Must | Security and shrink. |
| FR-08 | Each alert shall name store, wave or tote, minutes to cut-off or minutes out of band, and allergen or protected-line flags. | Must | Enough to act. |
| FR-09 | The lead shall acknowledge with recover-pick, dump-tote, hold-van, substitute-allowed, or escalate-to-food-safety. | Must | Audit trail. |
| FR-10 | Food Safety shall add or remove an allergen or protected SKU while the system is running. | Must | Live policy. |
| FR-11 | No second at-risk alert for the same wave or tote and same cause until the first is acknowledged or closed. | Must | Fatigue. |
| FR-12 | Daily promise and food-safety summary for the city office. | Must | Reporting. |
| FR-13 | Notes shall not contain customer names, addresses, or card numbers. | Must | Data protection. |
| FR-14 | Escalate when an at-risk alert is unacknowledged for 5 minutes. | Must | Peak pace. |
| FR-15 | Dumping a warm tote shall not put those units back into saleable stock unless Cold Chain acknowledges. | Must | Stock integrity. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | Capture for every tick: store, wave, slot, % picked, tote ID, band, temperature, allergen flags, protected-line flags. | Must | Minimum dataset. |
| DR-02 | Capture for every incident: start, end, action, who acknowledged, substitute SKUs if any. | Must | File. |
| DR-03 | Retain incidents for 24 months. | Must | Complaint and EHO. |
| DR-04 | Retain tote temperatures for 14 days. | Must | Excursion reconstruction. |
| DR-05 | Reject a tick with a missing store, wave, or tote ID. | Must | Data quality. |
| DR-06 | Do not persist full address, email, or payment token. Postcode sector only. | Must | GDPR. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | No substitute onto a declared allergen. | Food Safety | Must |
| BR-02 | Protected lines shall not move tote without lead acknowledgement. | Shrink / security | Must |
| BR-03 | No new alert for the same tote and cause while open. | Practice | Must |
| BR-04 | Food Safety and EHO views are read-only and cannot delete a row. | Regulatory | Must |
| BR-05 | A warm frozen tote shall not be sealed for dispatch. | Hygiene | Must |
| BR-06 | Age-restricted failure at handover shall close the line as undelivered, not as picked. | Licensing | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|---|
| AR-01 | Daily summary: orders, missed slots, temperature incidents, allergen blocks, protected-line alerts, median time to acknowledge. | Promise, Food Safety | Daily | 24 months |
| AR-02 | Incident log with timings and actions. | Leads, Food Safety, EHO | On demand | 24 months |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | Screen updates within 5 seconds of a pick or logger sample. | 5 s |
| NFR-02 | Availability | 99.9% between 05:00 and 23:00. | 99.9% |
| NFR-03 | Capacity | 250,000 pick and temperature events per day across eight sites. | 250k/day |
| NFR-04 | Security | Only “Store Lead” or “Cold Chain” see tote-level live data. Food Safety is read-only plus register admin. | Role-based |
| NFR-05 | Security | No payment data on this screen. | PCI stay-out |
| NFR-06 | Auditability | Every acknowledgement records who, when, what. | Full trace |
| NFR-07 | Usability | Lead answers “which wave dies in the next 20 minutes?” in under 10 seconds. | ≤10 s |
| NFR-08 | Compliance | Supports UK GDPR, food-hygiene record-keeping, Natasha’s Law on packed substitutes. | Full |
| NFR-09 | Recoverability | Live view back within 15 minutes; log intact. WMS handheld remains pick path. | ≤15 min |

---

## 9. User journeys

### 9.1 Journey: Friday wave slipping against cut-off
- **Trigger:** Store 3 Wave W-184 still has 22% unpicked at 17:05 for a 17:30 slot.
- **Steps:** System flags at risk → Noah sees aisle 12 frozen as the bottleneck → moves two pickers → acknowledges recover-pick → wave seals at 17:24.
- **Outcome:** Slot held. Action on the log.
- **Failure path:** If unacknowledged at 17:10, escalate to the city duty manager.

### 9.2 Journey: Allergen substitute attempt
- **Trigger:** Picker offers a pesto that contains pine nut on an order that declared tree nut.
- **Steps:** System blocks the substitute and alerts → Noah confirms dump of the wrong jar → correct line picked or shorted with customer message from the existing app.
- **Outcome:** Allergen not shipped. Attempt remains in the log.
- **Failure path:** If the handheld is in offline mode, the tote cannot be sealed until the block is resolved.

### 9.3 Journey: Warm frozen tote at the dock
- **Trigger:** Tote F-903 reads −12 °C for two samples.
- **Steps:** At-risk flag → Farah dumps the tote → stock does not return to saleable without her acknowledgement → van leaves without those lines.
- **Outcome:** Melted product never reaches the doorstep.

### 9.4 Journey: Morning Food Safety pack
- **Trigger:** 08:00 after a complaint.
- **Steps:** Gita opens the summary, exports without addresses, files.
- **Outcome:** Pack in 10 minutes. She cannot delete a row.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | Every open wave visible within 5 seconds of release to pick. | Peak-hour test |
| AC-02 | At-risk flags match the 25-minute / 15% and temperature rules on 40 scripted waves. | Scripted test |
| AC-03 | Allergen substitute is blocked and logged. | Floor test |
| AC-04 | Protected-line move without acknowledgement is refused. | Floor test |
| AC-05 | Food Safety role cannot delete a row. | Role test |
| AC-06 | Daily summary matches WMS counts for one day and has no full address. | Side-by-side plus DPO |
| AC-07 | 30 days at 99.9% availability. | Service report |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Logger feed gaps in the freezer. | M | H | Trial on Store 3 freezer before network roll-out. |
| R-02 | Pickers work around the allergen block with a free-text SKU. | M | H | Only listed SKUs; free-text substitute disabled on flagged orders. |
| R-03 | Lead tablet treated as the legal hygiene record. | L | M | WMS and logger remain systems of record; this tool is the desk view and the file. |
| R-04 | Christmas volume exceeds 250k events. | M | M | Load test at 2× before peak. |
| R-05 | Address leaks into a note. | M | H | Note prompt forbids it; DPO spot-checks. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| Time from wave slip to lead on the right aisle | 9 min | 3 min | 3 months |
| Orders missing slot for a reason visible 12 minutes earlier | 1 in 220 | 1 in 500 | 6 months |
| Allergen substitutes that still leave the store | Occurs | Zero | Every month |
| Food Safety pack time after a complaint | 1 day | 15 min | 1 month |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| At risk | Wave or tote that has crossed a cut-off or temperature rule. |
| Cut-off | Last moment a tote may leave the store for the promised slot. |
| Dark store | Closed store used only for commerce picking. |
| Protected line | Infant formula, spirits, or listed high-shrink SKU. |
| Substitute | Replacement SKU when the ordered line is short. |
| Tote | Physical container for one temperature band of an order. |
| Wave | Batch of orders released to pick for a slot window. |
| WMS | Warehouse management system — the pick path. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | Are spoke chillers in phase 1 or phase 1b? | Head of Dark Stores | 2026-10-20 | Open |
| Q-02 | Which 20 SKUs sit on the protected-line register on day one besides infant formula and spirits? | Food Safety / Shrink | 2026-10-15 | Open |
| Q-03 | What customer message is approved when a warm tote is dumped after cut-off? | Promise | 2026-10-22 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (COO) | `[name]` | | |
| Product owner (Head of Dark Stores) | `[name]` | | |
| Technical lead (IT) | `[name]` | | |
| Food Safety | `[name]` | | |
| SIRO | `[name]` | | |

---

*End of document.*
