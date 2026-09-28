# Business Requirements Document (BRD)

## Card Authorization Pipeline

| Field | Value |
|---|---|
| Project name | Card Auth Risk Gate |
| Document title | Business Requirements — Card Authorization Pipeline |
| Version | 1.0 |
| Date | 2026-09-27 |
| Author | Payments Programme Office |
| Reviewer(s) | Head of Card Operations, Fraud Risk Manager, Compliance Officer |
| Approver(s) | Chief Risk Officer, Chief Information Security Officer |
| Status | Approved |

**Revision history**

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | 2026-09-20 | Payments Programme Office | First draft |
| 1.0 | 2026-09-27 | Payments Programme Office | Approved after review with Card Ops and Fraud Risk |

---

## 2. Executive summary

Every day, tens of thousands of card authorization requests arrive at our payment gateway — from card-present terminals at merchants, from card-not-present channels on the internet, and from mobile wallets. When a request is suspicious, our current system either lets it through (and we lose the money to fraud) or blocks it (and the genuine customer is inconvenienced). We need a simple, real-time tool that watches every authorization request, decides within milliseconds whether to approve, step up for additional verification, or decline, and records every decision and every money movement so our fraud team, our settlement team, and our compliance auditors can all see exactly what happened and why. This document sets out what that tool must do, for whom, and how we will know it is working.

---

## 3. Business context

### 3.1 Background
Our payment gateway handles around 120,000 authorization requests per day across card-present (CP) and card-not-present (CNP) channels. Each request carries a merchant identifier, an amount in cents, a merchant category code (MCC), a velocity count for the card, and a presentment indicator. Authorizations fall into three outcomes: **approve** (money may be captured later), **step up** (the customer must complete 3-D Secure or an analyst must review), and **decline** (the request is refused). Approve and step-up together account for the vast majority of traffic; decline is rare but expensive when it is wrong and expensive when it is missed.

### 3.2 Problem statement
Right now, our authorization decisions and our ledger live in two different worlds. The decision rules are scattered across a risk engine, a rules engine, and a hard-coded list of blocked merchant category codes. The ledger of what happened — declines, step-ups, holds, captures, voids, and issuer acknowledgements — is assembled after the fact by a nightly batch job. When fraud risk asks "why did we decline this card at 14:32 yesterday?", the answer takes hours and three people to assemble. When compliance asks "show me every hold we placed on merchant M-4419 last quarter", we cannot answer without exporting a spreadsheet. When operations wants to add a blocked MCC, we redeploy code. We estimate that around 1 in 400 declined transactions is a false decline caused by a rule that was correct when it was written but wrong today.

### 3.3 Business drivers
- **Fraud loss.** Missed fraud costs us money directly and indirectly through chargebacks and scheme fines.
- **False declines.** Blocking a genuine customer costs us the sale, the customer's goodwill, and, in some cases, the merchant relationship.
- **Regulatory pressure.** The Payment Card Industry Data Security Standard (PCI DSS) and the Second Payment Services Directive (PSD2) require us to demonstrate real-time risk decisions and strong customer authentication for card-not-present transactions.
- **Operational pressure.** Our fraud analysts and settlement team are already stretched. They need one view, not three.

### 3.4 Alignment with strategy
Our 2025–2028 payments strategy names "real-time risk and settlement visibility" as one of four pillars. This project delivers a first, concrete step in that direction, without replacing any of the systems we already have.

---

## 4. Scope

### 4.1 In scope
- Real-time risk decisioning for every incoming authorization request (CP and CNP).
- Three decision outcomes: approve, step up, decline.
- A blocked-MCC policy that operations can update without redeploying code.
- A ledger of every decision, every step-up, every acknowledgement, and every money movement (hold, capture, void).
- Available-balance and held-balance books, per merchant and across the merchant base.
- An issuer retry mechanism for declined authorizations, with retry-once semantics.
- A read-only compliance view of the ledger.
- A daily summary report for the fraud risk and settlement teams.

### 4.2 Out of scope
- Card issuing. We authorize transactions; we do not issue cards.
- Merchant onboarding and KYC. Handled by the merchant services team.
- Chargeback handling and dispute resolution. Handled by the disputes team.
- Multi-currency settlement. Phase 1 is single-currency (GBP).
- Physical terminal fleet management. Handled by the terminal services team.
- Customer-facing 3-D Secure pages. The step-up decision is ours; the challenge page is the issuer's.

### 4.3 Assumptions
- The gateway can provide an authorization request stream with amount, MCC, velocity, and presentment at least every 200 milliseconds.
- The merchant identifier (MID) is stable across all channels and is present on every request.
- The issuer acknowledges declined authorizations within 5 seconds.
- The blocked-MCC list is expected to contain fewer than 100 entries at any time.
- The available-balance book is seeded once per merchant at the start of the trading day and updated throughout.

### 4.4 Constraints
- No new hardware. This runs on the existing gateway infrastructure.
- Must go live before the 2027 peak season (November).
- Must not change the existing issuer communication protocol.
- Must use the existing single sign-on for staff access.
- Budget capped at the amount approved in the Q3 board paper.

### 4.5 Dependencies
- Gateway must expose the authorization request feed (Gateway Engineering team).
- Issuer connectivity must support the retry mechanism (Scheme Relations team).
- Fraud Risk team must agree the decline and step-up rules (Fraud Risk team).
- Compliance must agree the audit-trail retention policy (Compliance team).

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement approach |
|---|---|---|---|---|
| Sponsor | Chief Risk Officer | Fraud loss, false-decline rate, regulatory readiness | H | Monthly steering |
| Primary user | Fraud Analysts (Fraud Risk team) | Fast, accurate decisions; one view | H | Weekly workshops |
| Primary user | Settlement Analysts (Settlement team) | Clean books; no orphan holds | H | Weekly workshops |
| Reviewer | Card Operations Manager | Fewer escalations; consistent rules | M | Bi-weekly review |
| Reviewer | Compliance Officer | Audit trail; PCI DSS and PSD2 readiness | M | Sign-off before go-live |
| Regulator | Financial Conduct Authority | PSD2 strong customer authentication | L | Quarterly update |

---

## 6. Users and personas

### 6.1 Fraud Analyst — Aisha
- **Role:** Shift fraud analyst, Fraud Risk team.
- **Context:** In the risk operations centre, reviewing alerts from the authorization stream in real time, from 06:00 to 14:00. Handles 80–120 alerts a shift.
- **Goal:** Know within seconds whether a suspicious authorization is genuinely fraudulent, and record her decision in one place.
- **Pain today:** Has to check three systems — the risk engine, the rules engine, and the ledger — to understand a single decline. Cannot see the step-up queue and the decline queue on the same screen.
- **Success looks like:** One screen shows every decline, every step-up, and every acknowledgement, with the amount, the MCC, the merchant, and the decision reason.

### 6.2 Settlement Analyst — Daniel
- **Role:** Settlement analyst, Settlement team.
- **Context:** In the back office, reconciling the day's holds, captures, and voids against the scheme reports.
- **Goal:** Know that every hold placed has a matching capture or void by end of day, and that the available-balance book agrees with the scheme.
- **Pain today:** Builds the reconciliation by hand from three exports every morning. Takes 90 minutes and misses orphan holds.
- **Success looks like:** Opens the books, sees available, held, and captured in one view, with every hold accounted for.

### 6.3 Compliance Officer — Priya
- **Role:** Compliance officer, Compliance team.
- **Context:** In the compliance office, reviewing the audit trail on demand for PCI DSS and PSD2 evidence.
- **Goal:** A read-only view of the full ledger, with no risk of accidental modification, that she can export for an audit.
- **Pain today:** Cannot prove the ledger was not modified after the fact. Has to request exports from three teams.
- **Success looks like:** Opens a read-only view, sees every row in the order it was written, and cannot delete or change a single row.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| FR-01 | The system shall decide, for every authorization request, one of three outcomes: approve, step up, or decline. | Must | Core purpose of the tool. |
| FR-02 | The system shall decline an authorization when the merchant category code is on the operations-managed blocked list and the channel is card-not-present. | Must | Fraud policy. |
| FR-03 | The system shall decline an authorization when the card velocity is at or above the velocity threshold. | Must | Fraud policy. |
| FR-04 | The system shall step up an authorization when the amount is at or above the step-up threshold and the channel is card-not-present. | Must | PSD2 strong customer authentication. |
| FR-05 | The system shall step up an authorization when the amount is at or above the high-value threshold. | Must | Fraud policy. |
| FR-06 | The system shall not raise the same decline or step-up twice in a row for the same merchant and decision. | Must | Prevent alert fatigue. |
| FR-07 | The fraud analyst shall be able to acknowledge a decline or step-up and record the action taken. | Must | Audit trail of staff response. |
| FR-08 | The system shall place a hold on the available balance when a step-up is acknowledged as approved by the customer. | Must | Money must be reserved before capture. |
| FR-09 | The system shall capture a hold when the merchant presents the captured amount for settlement. | Must | Settlement. |
| FR-10 | The system shall void a hold when the merchant or the customer cancels the transaction. | Must | Compensate on cancellation. |
| FR-11 | The system shall retry a declined authorization with the issuer once before giving up. | Must | Recover transient issuer failures. |
| FR-12 | The operations team shall be able to add or remove a merchant category code from the blocked list without redeploying code. | Must | Live policy. |
| FR-13 | The system shall produce a daily summary report of declines, step-ups, captures, and voids by merchant. | Must | Fraud risk and settlement requirement. |
| FR-14 | The compliance officer shall be able to view the full ledger in read-only mode. | Must | PCI DSS and PSD2 audit evidence. |
| FR-15 | The system shall record every decision, acknowledgement, hold, capture, and void in an append-only ledger. | Must | Audit trail. |
| FR-16 | The fraud analyst shall be able to add a free-text note to any decline or step-up. | Should | Context for later review. |
| FR-17 | The settlement analyst shall be able to export the day's ledger as a spreadsheet. | Could | Ad-hoc reconciliation. |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | The system shall capture for every authorization request: authorization ID, merchant identifier, amount in cents, merchant category code, velocity, presentment indicator, and channel. | Must | Minimum dataset for risk decisioning. |
| DR-02 | The system shall capture for every decision: decision outcome, decision reason, authorization ID, timestamp. | Must | Audit trail. |
| DR-03 | The system shall capture for every hold: authorization ID, merchant identifier, held amount in cents, timestamp. | Must | Settlement. |
| DR-04 | The system shall capture for every acknowledgement: who acknowledged, when, what action was taken. | Must | Audit trail. |
| DR-05 | The system shall retain the ledger for 24 months. | Must | PCI DSS and PSD2 retention. |
| DR-06 | The system shall reject authorization requests with a missing merchant identifier or a malformed merchant category code. | Must | Data quality at the source. |
| DR-07 | The system shall reject an amount that is zero, negative, or above the per-transaction maximum. | Must | Data quality at the source. |
| DR-08 | The system shall maintain a running available balance and a running held balance per merchant, in cents, that never go negative. | Must | Money invariant. |

### 7.3 Rules and policy

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | The available balance plus the held balance plus the captured amount shall at all times equal the merchant's opening balance for the day. | Internal finance policy | Must |
| BR-02 | No decline or step-up may be raised for a merchant category code that is not on the blocked list. | Fraud policy | Must |
| BR-03 | No decision may be raised for an authorization request that has already been decided for the same authorization ID. | Internal policy | Must |
| BR-04 | Card-not-present transactions above the step-up threshold must be stepped up for strong customer authentication. | PSD2 | Must |
| BR-05 | Every decline and step-up must be acknowledged or dismissed within 15 minutes. | Service level | Must |
| BR-06 | The ledger must be append-only. No row may be modified or deleted, by any user, for any reason, during the retention period. | PCI DSS | Must |
| BR-07 | The compliance read-only view must share storage with the live ledger and must not be a copy that can drift. | Internal audit policy | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|---|
| AR-01 | The daily summary report shall show, per merchant: declines, step-ups, holds placed, captures, voids, and net movement in cents. | Fraud Risk, Settlement | Daily | 24 months |
| AR-02 | The ledger view shall show every decision, acknowledgement, hold, capture, and void with timestamps, in the order written. | Fraud Analysts, Compliance | On demand | 24 months |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | The system shall decide within 200 milliseconds of receiving an authorization request. | 200 ms |
| NFR-02 | Availability | The system shall be available 99.95% of the time between 05:00 and 23:00. | 99.95% |
| NFR-03 | Capacity | The system shall handle 120,000 authorization requests per day with peaks of 300 per second. | 120k/day, 300/s peak |
| NFR-04 | Security | Only authenticated staff with a "Fraud Ops" or "Settlement" role shall see transaction-level data. | Role-based |
| NFR-05 | Auditability | Every decision, acknowledgement, and money movement shall record who, when, and what action was taken. | Full trace |
| NFR-06 | Usability | A fraud analyst shall be able to answer "why was this declined?" in under 10 seconds. | ≤10 s |
| NFR-07 | Compliance | The system shall comply with PCI DSS and PSD2. | Full |
| NFR-08 | Recoverability | The system shall restore service within 15 minutes of a failure, with no loss of ledger rows. | ≤15 min, zero loss |

---

## 9. User journeys

### 9.1 Journey: Morning peak — a suspicious CNP authorization
- **Trigger:** At 09:42, a card-not-present authorization arrives for £72.00 at merchant M-4419 with MCC 7995 (gambling).
- **Steps:** The system reads the MCC → checks it against the blocked list → sees that operations added 7995 overnight → raises a decline → appends a DECLINE row to the ledger → enqueues an issuer job → the issuer acknowledges → the fraud analyst sees the decline on her screen → she records her action.
- **Outcome:** The decline is recorded, the issuer is informed, and the analyst has a full record.
- **Failure path:** If the issuer does not acknowledge within 5 seconds, the system retries once. If the retry also fails, the decline stays on the analyst's screen and is escalated.

### 9.2 Journey: A high-value step-up
- **Trigger:** At 14:12, a card-not-present authorization arrives for £600.00 at merchant M-5521 with MCC 5411 (grocery).
- **Steps:** The system reads the amount → sees it is above the step-up threshold and the channel is card-not-present → raises a step-up → appends a STEP-UP row → the customer completes 3-D Secure → the analyst acknowledges as approved → the system places a hold for £600.00 on the available balance → the merchant captures → the system moves £600.00 from held to captured.
- **Outcome:** Money moves exactly once, and the ledger records every step.
- **Failure path:** If the customer abandons the 3-D Secure challenge, the analyst records "abandoned" and the step-up is dismissed. No hold is placed.

### 9.3 Journey: Settlement reconciliation
- **Trigger:** At 08:00, Daniel opens his laptop.
- **Steps:** He opens the daily summary report → sees the previous day's declines, step-ups, holds, captures, and voids by merchant → checks that every hold has a matching capture or void → exports the ledger as a spreadsheet → sends it to the scheme reconciliation team.
- **Outcome:** The reconciliation is complete before 09:00, with no orphan holds.
- **Failure path:** If the report is unavailable, he falls back to the manual export for one day.

---

## 10. Acceptance criteria

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | Every authorization request is decided within 200 milliseconds. | Live test during peak hour |
| AC-02 | Declines, step-ups, and approvals are correct for 100% of scripted test cases. | Scripted test with 50 known cases |
| AC-03 | No decline or step-up is raised twice in a row for the same merchant and decision. | Scripted test with repeated identical requests |
| AC-04 | Every decision can be acknowledged and recorded. | Demo with fraud analysts |
| AC-05 | The daily summary report matches a manual count for a full day. | Side-by-side comparison |
| AC-06 | The ledger cannot be modified after the fact, by any user. | Inspection by Compliance Officer |
| AC-07 | The available plus held plus captured invariant holds after every money movement. | Scripted test across hold, capture, and void |
| AC-08 | The system runs for 30 days with 99.95% availability and zero ledger loss. | Monthly service report |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Gateway feed is slower than promised. | M | H | Early technical trial with Gateway Engineering before full build. |
| R-02 | Fraud analysts find the screen too crowded. | M | M | Co-design workshops with analysts from week 1. |
| R-03 | Issuer connectivity does not support retry. | M | M | Confirm with Scheme Relations before build. |
| R-04 | The step-up threshold is wrong for some merchant categories. | M | H | Make the threshold part of the blocked-list policy that operations can tune. |
| R-05 | Compliance rejects the audit trail as insufficient for PCI DSS. | L | H | Early review with Compliance before build. |

---

## 12. Success measures

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| False-decline rate per 1,000 declined transactions | 2.5 | 1.5 | 3 months after go-live |
| Time to answer "why was this declined?" | 45 min | 30 s | 1 month after go-live |
| Settlement reconciliation time | 90 min | 10 min | 1 month after go-live |
| Fraud analyst satisfaction with visibility | 2.4 / 5 | 4.0 / 5 | 3 months after go-live |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| Authorization | A request to reserve funds on a card for a future capture. |
| Capture | The movement of reserved funds from held to captured. |
| Card-not-present (CNP) | A transaction where the card is not physically presented (e.g. online). |
| Card-present (CP) | A transaction where the card is physically presented (e.g. at a terminal). |
| Decline | A decision to refuse an authorization. |
| Hold | A reservation of funds on the merchant's available balance. |
| MCC | Merchant Category Code — a four-digit code describing the merchant's business. |
| MID | Merchant Identifier — a stable identifier for a merchant. |
| PCI DSS | Payment Card Industry Data Security Standard. |
| PSD2 | Second Payment Services Directive (EU/UK). |
| Step up | A decision to require additional verification before approving. |
| 3-D Secure | The protocol used by issuers for strong customer authentication. |
| Velocity | The count of recent transactions on a card within a window. |
| Void | The cancellation of a hold before capture. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | What is the exact velocity window (1 hour, 24 hours, 7 days)? | Fraud Risk | 2026-10-15 | Open |
| Q-02 | Should the step-up threshold vary by merchant category? | Fraud Risk | 2026-10-20 | Open |
| Q-03 | Which merchants are in the phase-1 daily report? | Commercial | 2026-10-25 | Open |
| Q-04 | What is the approved retention policy for issuer job records? | Compliance | 2026-10-30 | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor (CRO) | `[name]` | | |
| Product owner (Head of Card Ops) | `[name]` | | |
| Technical lead (Gateway Engineering) | `[name]` | | |
| Compliance / risk | `[name]` | | |

---
