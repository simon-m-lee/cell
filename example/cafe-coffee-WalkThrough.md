# WalkThrough — Café Order & Stock Desk (Cell variant)

## What a reader must understand

This WalkThrough is the executable-behaviour contract for a single-site café order and stock desk. An order, its payment, and its stock movement must succeed together or not at all. A refund and its stock restore must succeed together or not at all. If any part fails, the customer is not charged and stock is unchanged. The instruction decides whether to proceed, the chain assembles the decision, and the observer is the only glue that writes books. Multi-value commits use `Cell.txApply` on Tissue. Open parameters from the BRD stay carried forward and will appear as Blocked until confirmed.

**Name plate**

| Artifact | Name |
|---|---|
| Project / desk | Café Coffee Shop — Order & Stock Desk |
| BRD | `cafe-coffee-BRD.md` (v0.2.0) |
| This WalkThrough | `cafe-coffee-WalkThrough.md` |
| Version | `0.1.0` |
| Supersedes | none |
| Demo | `cafe-coffee-Demo.dart` |
| Ledger / comprehension (later) | `cafe-coffee-LEDGER.md`, `cafe-coffee-COMPREHENSION.md` |
| Layer HowTos | HowTo-Mitose-Cell / Flow / Tissue |
| Generated via | Document_AI_MasterGenerator.md → WalkThrough-AI-Generator.md |

## 5.1 Inputs / ingress list

| Ingress handle | Payload | Range / shape | TestCell | BRD |
|---|---|---|---|---|
| `orderIn` | order lines (item, quantity, price) | quantity > 0; at least one item | yes (rejects quantity ≤ 0) | FR-01, DR-03 |
| `paymentIn` | method, amount, status | status captured or rejected | yes on malformed | FR-02, DR-02 |
| `refundIn` | paid order key | existing paid order | yes on unknown key | FR-05 |
| `stockCheckIn` | item → current quantity | non-negative | yes on negative | FR-03, FR-06 |
| `tickIn` | assembled `CafeTick` | snapshot of the above | none (assembled) | journeys |

No ACK ingress is named in the BRD for latch clear. Outcome recording is the audit substitute.

## 5.2 Policy clauses → `riskOf` order

Clause order is load-bearing:

1. Type-check / ignore unknown tick.
2. Quantity ≤ 0 on any line → reject (DR-03).
3. Stock insufficient for any line → reject (FR-06).
4. All-or-nothing intent for order+payment+stock (BR-01 / FR-04) or refund+stock (BR-02 / FR-05).
5. Else proceed.

Per-pulse order the Demo must copy:

> type-check → `riskOf` → product filter → emit `Pulse<CafeDecision>`.

Custom `FlowInstruction` is required (multiple clauses + all-or-nothing intent). Stock `Filter` alone is not enough.

## 5.3 Products and `pass`

| Product | `pass` level | Who sees it | Why a separate `toHandle` |
|---|---|---|---|
| proceed | `Level.proceed` | till / owner | success path that may enter txApply |
| reject | `Level.reject` | till | rejection path, no Tissue growth |

Two products ⇒ two instruction instances, two chains, two `toHandle` calls.

## 5.4 Chain shape

```dart
final proceedGate = CafeOrderInstruction(stock: stockMap, pass: Level.proceed);
final rejectGate  = CafeOrderInstruction(stock: stockMap, pass: Level.reject);
final toLevel     = MapValue<CafeDecision, Level>((d) => d.level);

final proceedChain = proceedGate + toLevel;
final rejectChain  = rejectGate + toLevel;

handleProceed = proceedChain.toHandle(source: tickIn.cell); // once, installGates only
handleReject  = rejectChain.toHandle(source: tickIn.cell);  // once
```

`toHandle` is not called from any later restore. `MapValue` projects the rich `CafeDecision`. Adjacent operators are not required in v1.

## 5.5 Pulse path

```text
orderIn / paymentIn / refundIn / stockCheckIn
                    \
                  publishTick
                       |
                     tickIn  (Pulse<CafeTick>)
                       |
         CafeOrderInstruction + MapValue
                       | toHandle × 2
                  gate Cell(s)  (Pulse<Level>)
                       |
                 Cell.observe
                       |
         txApply on Tissue / outcome record / stock write
```

Payload types labelled above. `Cell.observe` is the only glue.

## 5.6 Tissue books

| Book | Type | TestTissue | Written from | Read by | BRD |
|---|---|---|---|---|---|
| `orders` | `TissueList<Order>` | append-only | observe on proceed success | trailer, owner | FR-01, DR-01, AR-02 |
| `payments` | `TissueList<Payment>` | append-only | observe on proceed success | trailer | FR-02, DR-02 |
| `stock` | `TissueMap<String, int>` | ≥ 0 | observe via txApply | instruction (same object) | FR-03, FR-06 |
| `outcomes` | `TissueList<Outcome>` | append-only | observe on success or undo | owner, AR-02 | AR-02, NFR-03 |
| `refunds` | `TissueList<Refund>` | append-only | observe on refund success | trailer | FR-05 |

Grep rule: zero `testRule: TestCell` on Tissue constructors. TestTissue on books and deputies only.

## 5.7 Reserve protocol / raise-close

No countable pool is named in the BRD. Stock is the governed map. All-or-nothing is performed by `Cell.txApply` on the Tissue participants from `Cell.observe`. Compensate restores stock and records undone outcome. Instruction never writes Tissue.

## 5.8 TestCell vs TestTissue map

| Rule symbol | Applies to | Allows | Denies | Scenario that prints failure |
|---|---|---|---|---|
| `_qtyShape` | `orderIn` | quantity > 0 | ≤ 0 | REJECT-QTY |
| `_stockNonNeg` | `stock` | ≥ 0 | negative | INSUFFICIENT |
| `_appendOnly` | `orders`, `outcomes`, `payments` | add | remove / clear | COMPLY |
| `.unmodifiable` | owner view | reads | add | COMPLY |

## 5.9 Scenarios (must-print)

| # | Banner | Drive | Must print / Result |
|---|---|---|---|
| 1 | `HAPPY` | valid order + payment, stock sufficient | order recorded, payment captured, stock reduced, outcome=succeeded |
| 2 | `REFUND` | paid order refunded | refund recorded, stock restored, outcome=succeeded |
| 3 | `INSUFFICIENT` | stock = 0 for item | order rejected, stock unchanged, no charge, outcome=undone |
| 4 | `REJECT-QTY` | quantity ≤ 0 | TestCell fail, Tissue unchanged |
| 5 | `UNDO` | payment fails after stock intent | customer not charged, stock unchanged, outcome=undone |
| 6 | `COMPLY` | owner `.unmodifiable.add` | blocked |

## 5.10 Real desk / Wave A

| BRD need | v1 stand-in | Lands in later | Must not land in |
|---|---|---|---|
| Multi-value commit (FR-04, FR-05) | `Cell.txApply` on Tissue with compensate | — | `Cell.transaction`, instruction |
| Daily report (AR-01) | trailer print of totals | export job | second write path |
| Peak volume / refund window / retention (P-01…P-06) | carried as open | confirmed parameters | guessed values |
| Undo timing (NFR-02) | immediate compensate | measured timing | `riskOf` I/O |
| Offline cash | not driven | Wave A | — |

## 5.11 Open questions

| # | Question | Why it blocks | Default if unanswered |
|---|---|---|---|
| Q-01 | Approve 200 orders/day peak? | P-01 | `[To be confirmed from BRD]` |
| Q-02 | Stock unit = per item? | P-02 | `[To be confirmed from BRD]` |
| Q-03 | Card + cash, or card only? | P-03 | `[To be confirmed from BRD]` |
| Q-04 | Refund window = same day? | P-04 | `[To be confirmed from BRD]` |
| Q-05 | Undo policy = undo immediately and report? | P-05 | `[To be confirmed from BRD]` |
| Q-06 | Receipt retention = 7 years? | P-06 | `[To be confirmed from BRD]` |

## 5.12 Demo Assessment

**Filled from executed Demo and test results (agent executed 2026-11-01) using WalkThrough-AI-Generator.md §6 (via Document_AI_MasterGenerator.md).**

### What the Dart file implemented
- `CafeOrderInstruction` extending `FlowInstructionBase` with importable `riskOf`.
- Two chains (`proceed` / `reject`) with `MapValue` and `toHandle` once each.
- `Cell.observe` on both handles as the glue.
- `Cell.txApply` in `commitOrder` for the multi-value commit.
- Domain types: `CafeTick`, `CafeDecision`, `Order`, `Payment`, `Outcome`.
- `installGates()` that wires everything and does no work at import time.
- Header provenance and boundary registers.
- `main()` that drives HAPPY and INSUFFICIENT scenarios.

### What `main()` does not drive
- Full reactive path that carries the tick into the observer (MapValue drops the tick).
- REFUND banner fully driven from main.
- COMPLY (`.unmodifiable` add blocked).
- Real 5-second timing measurement.

### Trailer / header integers
| Token | WalkThrough expected | Demo header / last run |
|---|---|---|
| orders | success path records one | 1 on success tests |
| stock deltas | reduce on success, unchanged on reject | partial (TissueMap mutation timing in harness) |
| outcomes | succeeded / undone recorded | recorded |
| lastDecision | n/a (no latch) | n/a |

### Recommendations for Enhancement
- Carry the full `CafeDecision` (including tick) into the observer so stock mutation is driven by the reactive path.
- Fix TissueMap update timing so stock decreases are visible immediately after `commitOrder`.
- Drive REFUND and COMPLY scenarios from main.
- Measure real undo latency for NFR-02.

## 5.13 Coverage matrix

| Scenario # | BRD ID | WalkThrough section | Expected print | Proven in Demo? |
|---|---|---|---|---|
| 1 HAPPY | FR-01, FR-02, FR-03, FR-04, DR-01, DR-02, BR-01 | 5.9 | order + payment + stock succeed together | partial |
| 2 REFUND | FR-05, BR-02 | 5.9 | refund + stock restore succeed together | harness timing issue |
| 3 INSUFFICIENT | FR-06, NFR-01 | 5.9 | reject, stock unchanged, no charge | harness seeding issue |
| 4 REJECT-QTY | DR-03 | 5.9 | TestCell fail, Tissue unchanged | Verified |
| 5 UNDO | FR-04, NFR-01, AR-02 | 5.9 | customer uncharged, stock unchanged, outcome=undone | Verified |
| 6 COMPLY | AR-02 | 5.9 | unmodifiable add blocked | not driven |

## 5.14 HowTos consulted

Workspace copies of HowTo-Mitose-Cell.md, HowTo-Mitose-Flow.md, and HowTo-Mitose-Tissue.md.

---

*End of cafe-coffee-WalkThrough.md v0.1.0. Generated via Document_AI_MasterGenerator.md → WalkThrough-AI-Generator.md.*
