# Business Requirements Document (BRD) — Café Coffee Shop

**Name plate:** `Version: 0.2.0` | `Supersedes: cafe-coffee-BRD.md v0.1.0` | `Shape: Business_Requirements_Document.md v2.0` | `Source: pasted requirement + owner corrections + business-only rewrite`

## What a reader must understand

This is the Business Requirements Document for a **single-site café / coffee shop** that takes orders at the counter, captures payment, tracks stock, and handles refunds. It describes **what the business needs**, in plain business language, and does **not** describe how any of it will be built. The defining business need is **consistency**: an order, its payment, and its stock movement must succeed together or not at all; a refund and its stock restore must succeed together or not at all. If any part fails, the customer must not be charged and the stock must be unchanged. Every value marked `[AI SUGGESTED]` is a proposal; every row tied to an Open question (Q-01…Q-06) will be treated as **Blocked** until approved.

---

## 1. Document control

| Field | Value |
|---|---|
| Project name | Café Coffee Shop — Order & Stock Desk |
| Document title | Business Requirements Document — Café Coffee Shop |
| Version | 0.2.0 |
| Date | 2026-11-01 |
| Author | AI (Mitose agent) — drafted from pasted requirement + business-only rewrite |
| Reviewer(s) | `[To be confirmed from BRD]` — café owner |
| Approver(s) | `[To be confirmed from BRD]` — café owner |
| Status | draft |

**Revision history**

| Version | Date | Change ID | Author | Change summary |
|---|---|---|---|---|
| 0.1 | 2026-11-01 | — | AI | Initial draft. Named a specific technical mechanism for the order/refund commits; included design-only rules. |
| 0.2 | 2026-11-01 | — | AI | Rewritten to be purely business. Removed all software, code, design, implementation and "use" language. The "order + payment + stock succeed together" and "refund + stock restore succeed together" business outcomes are kept; the technical mechanism is no longer named in this BRD. A design-only rule about which mechanism is not permitted was retired from this BRD and moved to the executable-behaviour companion document. No acceptance criterion was retired; no parameter value used by a check changed. Q-01…Q-06 remain Open. |

---

## 2. Executive summary

A café takes orders at the counter, prepares drinks and food, and must not oversell stock or double-charge a customer. Today the till, the stock count, and the order ticket are three separate actions; when one fails, the others are wrong. This BRD requires that **an order, its payment, and its stock movement succeed together or not at all**, and that **a refund and its stock restore succeed together or not at all**. When anything fails partway, the customer is not charged, the stock is unchanged, and the café has a clear record of what happened. `[AI SUGGESTED]`

---

## 3. Business context

### 3.1 Background
`[AI SUGGESTED]` The café is a single-site, walk-in and takeaway operation. Orders are taken at a counter till; drinks are made to order; pastry and packaged food are stocked. There is no table service.

### 3.2 Problem statement
`[AI SUGGESTED]` When a card payment fails after an order is rung, the till may show the order as placed, stock may be reduced, and the customer is not charged — or the opposite: payment taken, order not placed. When a refund is issued, stock is not put back. A second failure mode: the card terminal times out after the till has recorded the order, leaving a charge with no order. The café has no single outcome it can trust for "order, payment, stock" and for "refund, stock".

### 3.3 Business drivers
- **No oversell:** stock is reduced only if the order succeeds.
- **No charge without an order:** the customer is charged only if the order succeeds; if not, any charge is undone.
- **Refund restores stock:** a refund puts stock back.
- **A clear record:** the café can see, for every order and refund, whether it succeeded or was undone.

### 3.4 Alignment with strategy
`[AI SUGGESTED]` A consistent till/stock/order outcome lets the café scale to a second site later without rebuilding the order flow.

---

## 4. Scope

### 4.1 In scope
- Counter order taking (drinks + food).
- Payment capture `[AI SUGGESTED: card terminal + cash]`.
- Stock reduction on a successful order.
- Refund + stock restore on a refund.
- Order status: `placed`, `paid`, `preparing`, `ready`, `collected`, `refunded`.
- A record of whether each order and refund succeeded or was undone.
- A daily report of orders, payments, and refunds.

### 4.2 Out of scope
- Table service / waiter service `[AI SUGGESTED]`.
- Loyalty / points `[AI SUGGESTED]`.
- Multi-site inventory `[AI SUGGESTED]`.
- Delivery `[AI SUGGESTED]`.
- Payroll / rostering `[AI SUGGESTED]`.

### 4.3 Assumptions
- Single site `[AI SUGGESTED]`.
- `[AI SUGGESTED: 200 orders/day peak]`.
- Card terminal supports capture and void `[AI SUGGESTED]`.
- Stock is counted per item, not per ingredient `[AI SUGGESTED]`.

### 4.4 Constraints
- The café must keep order, payment, and stock consistent — no partial outcome.
- The café must keep refund and stock restore consistent — no partial outcome.
- `[AI SUGGESTED: the till must work offline for cash orders]`.

### 4.5 Dependencies
- Card terminal / payment provider `[AI SUGGESTED]`.
- Stock count at open and close `[AI SUGGESTED]`.
- Receipt printer `[AI SUGGESTED]`.

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence | Engagement |
|---|---|---|---|---|
| Owner | `[To be confirmed from BRD]` | No oversell, no charge without an order | H | direct |
| Barista / till operator | `[To be confirmed from BRD]` | Fast order entry, clear refunds | H | direct |
| Customer | walk-in | Correct charge, correct refund | H | on-site |
| Accountant | `[To be confirmed from BRD]` | Daily reconciliation | M | report |

---

## 6. Users and personas

### 6.1 Till operator (barista)
- **Role:** takes orders, takes payment, hands receipt.
- **Goal:** order, payment, and stock succeed together; if not, nothing changes.
- **Pain today:** payment fails and order/stock disagree.
- **Success looks like:** order succeeds with payment and stock, or nothing changes and the customer is not charged.

### 6.2 Café owner
- **Role:** reconciles daily.
- **Goal:** no oversell, no charge without an order, refunds restore stock.
- **Success looks like:** day-end report matches stock and card terminal.

---

## 7. Business requirements

### 7.1 Functional requirements

| ID | Requirement | Priority | Acceptance criterion (Given/When/Then, tolerance) | Class | Rationale |
|---|---|---|---|---|---|
| FR-01 | The café shall take a counter order with drinks and food. | Must | **Given** a till operator, **when** items are added, **then** an order with at least one item is created. `[AI SUGGESTED]` | T | core flow |
| FR-02 | The café shall take payment for an order. | Must | **Given** an order, **when** payment is taken, **then** payment is `captured` or `rejected`. `[AI SUGGESTED]` | T | core flow |
| FR-03 | The café shall reduce stock for each ordered item when the order succeeds. | Must | **Given** an order with N items, **when** the order succeeds, **then** each item's stock decreases by N. `[AI SUGGESTED]` | T | no oversell |
| FR-04 | **The café shall treat order, payment, and stock as one outcome:** they succeed together, or none of them takes effect. | Must | **Given** an order being placed, **when** any part fails, **then** the customer is not charged, stock is unchanged, and no order is recorded; **when** all parts succeed, **then** the order, payment, and stock are all recorded. | T | **the consistency requirement** |
| FR-05 | **The café shall treat refund and stock restore as one outcome:** they succeed together, or neither takes effect. | Must | **Given** a paid order being refunded, **when** any part fails, **then** neither the refund nor the stock restore takes effect; **when** both succeed, **then** both are recorded. | T | undo path |
| FR-06 | The café shall reject an order if stock is insufficient. | Must | **Given** stock = 0, **when** an item is ordered, **then** the order is rejected and stock is unchanged. `[AI SUGGESTED]` | T | no oversell |
| FR-07 | The café shall record the status of each order. | Should | **Given** an order, **when** its status changes, **then** the new status is recorded. `[AI SUGGESTED]` | T | till clarity |

### 7.2 Data requirements

| ID | Requirement | Priority | Acceptance criterion | Class | Rationale |
|---|---|---|---|---|---|
| DR-01 | The café shall record order lines (item, quantity, price). | Must | **Given** an order, **when** it succeeds, **then** its lines are recorded. `[AI SUGGESTED]` | T | audit |
| DR-02 | The café shall record payment (method, amount, status). | Must | **Given** payment, **when** taken, **then** method, amount, and status are recorded. `[AI SUGGESTED]` | T | reconciliation |
| DR-03 | The café shall reject an order line with quantity 0 or less. | Must | **Given** quantity 0, **when** added, **then** rejected. `[AI SUGGESTED]` | T | data shape |

### 7.3 Rules and policy

| ID | Rule | Source | Priority | Acceptance criterion | Class |
|---|---|---|---|---|---|
| BR-01 | Order, payment, and stock succeed together or none takes effect. | café owner | Must | As FR-04 | T |
| BR-02 | Refund and stock restore succeed together or neither takes effect. | café owner | Must | As FR-05 | T |
| ~~BR-03~~ | ~~A named technical mechanism is not used.~~ **Retired in v0.2.0** — this was a design rule, not a business outcome. The business outcome is preserved as BR-01/BR-02. Moved to the executable-behaviour companion document. | — | — | — | — |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention | Priority | Acceptance criterion | Class |
|---|---|---|---|---|---|---|---|
| AR-01 | The café shall produce a daily report of orders, payments, and refunds. | owner | daily | `[AI SUGGESTED: 7 years]` | Must | **Given** a day, **when** reported, **then** totals match till and stock. | T |
| AR-02 | The café shall record, for every order and refund, whether it succeeded or was undone. | owner + accountant | on demand | event | Must | **Given** an order or refund, **when** queried, **then** its outcome (succeeded / undone) is visible. | T |

### 7.5 Parameter register

| ID | Parameter | Used by | Value | Unit | Owner | Status | Open question |
|---|---|---|---|---|---|---|---|
| P-01 | Peak orders/day | FR-01 | `[AI SUGGESTED: 200]` | orders | owner | TBD | Q-01 |
| P-02 | Stock unit | FR-03 | per item `[AI SUGGESTED]` | — | owner | TBD | Q-02 |
| P-03 | Payment methods | FR-02 | card + cash `[AI SUGGESTED]` | — | owner | TBD | Q-03 |
| P-04 | Refund window | FR-05 | `[AI SUGGESTED: same day]` | — | owner | TBD | Q-04 |
| P-05 | Undo policy when part of an order or refund fails | FR-04, FR-05 | `[AI SUGGESTED: undo immediately and report]` | — | owner | TBD | Q-05 |
| P-06 | Receipt retention | AR-01 | `[AI SUGGESTED: 7 years]` | — | owner | TBD | Q-06 |

### 7.6 Decision precedence

| Order | Rule (ID) | Wins over | All matching reasons recorded? |
|---|---|---|---|
| 1 | BR-01 (order+payment+stock one outcome) | any rule that would allow a partial outcome | yes |
| 2 | BR-02 (refund+stock restore one outcome) | any rule that would allow a partial refund | yes |

---

## 8. Non-functional requirements

| ID | Category | Requirement | Target | Priority | How measured | Class |
|---|---|---|---|---|---|---|
| NFR-01 | Consistency | No order, payment, or stock takes effect partially. | 100% | Must | every failed order or refund leaves customer uncharged and stock unchanged | M |
| NFR-02 | Recovery | When an order or refund is undone, it is completed within `[AI SUGGESTED: 5 s]`. | 5 s | Must | measured from the failure to the end of the undo | M |
| NFR-03 | Audit | Every order and refund outcome (succeeded / undone) is recorded. | 100% | Must | count of records vs count of orders + refunds | T |

---

## 9. User journeys

### 9.1 Journey: counter order (happy path)
- **Trigger:** customer orders.
- **Steps:** add items → take payment → order, payment, and stock move together → order succeeds.
- **Outcome:** order paid, stock reduced, receipt.
- **Failure path:** any part fails → nothing changes: customer not charged, stock unchanged, no order recorded; the café records that the attempt was undone.
- **Requirement IDs:** FR-01, FR-02, FR-03, FR-04, DR-01, DR-02, BR-01, NFR-01.

### 9.2 Journey: refund
- **Trigger:** customer returns item.
- **Steps:** refund and stock restore move together → refund succeeds.
- **Outcome:** refund issued, stock restored.
- **Failure path:** neither refund nor stock restore takes effect; the café records the undone attempt.
- **Requirement IDs:** FR-05, BR-02, NFR-01.

### 9.3 Journey: insufficient stock
- **Trigger:** item quantity is 0.
- **Steps:** the order is rejected before anything moves.
- **Outcome:** order rejected, stock unchanged, customer not charged.
- **Requirement IDs:** FR-06, NFR-01.

---

## 10. Acceptance criteria

| ID | Criterion (Given/When/Then) | Covers | Method |
|---|---|---|---|
| AC-01 | Order, payment, and stock succeed together. | FR-04, BR-01 | observation |
| AC-02 | Refund and stock restore succeed together. | FR-05, BR-02 | observation |
| AC-03 | Any failure leaves customer uncharged and stock unchanged. | FR-04, NFR-01 | observation |
| AC-04 | Undone outcomes are recorded. | AR-02, NFR-03 | inspection |
| AC-05 | Insufficient stock rejects the order. | FR-06 | observation |

### 10.1 Verification classes

| Class | Meaning | Verified when |
|---|---|---|
| T | Check with fixed expected result | Ran and passed; run recorded |
| P | Property/invariant | Held over stated cases |
| M | Measured against target | Measured and met target |
| I | Inspection | Named reviewer recorded |
| H | Human trial | Ran with stated participants |
| J | Judgment | Never Verified; named person accepts |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Customer charged but order not placed | M | H | FR-04 — no partial outcome; charge undone. |
| R-02 | Refund issued but stock not restored | M | M | FR-05 — no partial refund. |
| R-03 | Undo itself fails | L | H | Record the failure and raise it to the owner. |
| R-04 | Till offline | M | M | `[AI SUGGESTED: cash-only fallback]`. |

---

## 12. Success measures

| Measure | Baseline | Target | Matching requirement | Reviewed |
|---|---|---|---|---|
| Partial outcomes | `[To be confirmed]` | 0 | NFR-01 | weekly |
| Refund stock mismatches | `[To be confirmed]` | 0 | FR-05 | weekly |
| Undone outcomes recorded | — | 100% | AR-02 | daily |

---

## 13. Glossary

| Term | Meaning |
|---|---|
| Order | One customer's set of items, taken at the counter. |
| Stock | The count of each item available to sell. |
| Partial outcome | An order or refund where only some of its effects took place. |
| Undone | An order or refund whose effects did not take place and are cleared away. |
| Outcome record | The café's record of whether an order or refund succeeded or was undone. |

---

## 14. Open questions

| ID | Question | Owner | Due date | Blocks | Status |
|---|---|---|---|---|---|
| Q-01 | Approve 200 orders/day peak? | owner | `[To be confirmed]` | P-01 | Open |
| Q-02 | Stock unit = per item? | owner | `[To be confirmed]` | P-02 | Open |
| Q-03 | Card + cash, or card only? | owner | `[To be confirmed]` | P-03 | Open |
| Q-04 | Refund window = same day? | owner | `[To be confirmed]` | P-04 | Open |
| Q-05 | Undo policy when part of an order or refund fails = undo immediately and report? | owner | `[To be confirmed]` | P-05 | Open |
| Q-06 | Receipt retention = 7 years? | owner | `[To be confirmed]` | P-06 | Open |

### 14.1 Consistency checks

- [x] No two business rules contradict each other.
- [x] §7.6 precedence stated.
- [ ] Every number has a value or owner — **partly open**: P-01…P-06 are TBD.
- [x] Every business rule is enforced by a requirement.
- [x] Every journey agrees with the requirements, including actor.
- [x] Same measure does not have two different targets.
- [x] Every target in §8 says how it is measured (NFR-02 basis `[AI SUGGESTED]`).
- [x] Every requirement table has priority, criterion, class per row.

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Owner | `[To be confirmed from BRD]` | | |
| Accountant | `[To be confirmed from BRD]` | | |

### 15.1 Residual acceptance (completed after the build)

*Empty until the outcome record exists. A named person accepts each row, with date and review-by date. Class J rows always appear.*

| Requirement ID | Why it remains | Accepted by | Date | Review by |
|---|---|---|---|---|
| | | | | |

---

## Appendix A. Outcome record

`[Link to cafe-coffee-OUTCOME-RECORD.md — not written in this pass]`

## Appendix B. Behaviour not covered by a requirement

*Empty until the café runs.*

| Behaviour | Where | Serves requirement? | Disposition | Decided by |
|---|---|---|---|---|
| | | | | |

---

*End of Business Requirements Document — Café Coffee Shop v0.2.0.*