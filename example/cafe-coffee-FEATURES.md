# FEATURES — Café Order & Stock Desk

**Generated via Document_AI_MasterGenerator.md → FEATURES-AI-Generator.md**

## 2.1 See-also name plate
| Artifact | Name |
|---|---|
| BRD | `cafe-coffee-BRD.md` v0.2.0 |
| WalkThrough | `cafe-coffee-WalkThrough.md` |
| Demo | `cafe-coffee-Demo.dart` |
| Ledger | `cafe-coffee-LEDGER.md` |

## 2.2 Feature catalogue
| Feature | BRD IDs | Implemented by |
|---|---|---|
| Counter order creation | FR-01 | `commitOrder` |
| Payment capture | FR-02, DR-02 | `commitOrder` |
| Stock reduction on success | FR-03 | `commitOrder` / txApply |
| One-outcome consistency | FR-04, BR-01 | `riskOf` + `commitOrder` |
| Refund + stock restore | FR-05, BR-02 | harness (timing issue this run) |
| Insufficient stock rejection | FR-06 | `riskOf` |
| Order status | FR-07 | `outcomes` |
| Order lines | DR-01 | `orders` |
| Qty ≤ 0 rejection | DR-03 | `riskOf` |
| Daily report | AR-01 | trailer |
| Outcome visibility | AR-02, NFR-03 | `outcomes` |
| Undo timing | NFR-02 | placeholder |

## 2.3 Scenario catalogue
| Scenario | Banner | BRD | Result |
|---|---|---|---|
| Happy order | HAPPY | FR-04, FR-03 | partial |
| Insufficient stock | INSUFFICIENT | FR-06 | harness issue |
| Payment fail | UNDO | FR-04 | Verified |
| Qty reject | REJECT-QTY | DR-03 | Verified |

## 2.4 What this demo deliberately does not do
- Full reactive path that carries the tick into the observer.
- COMPLY (`.unmodifiable` add blocked).
- Real 5-second latency measurement.
- Offline cash fallback.

## 2.5 Operator cheat sheet
| Action | Function |
|---|---|
| Place order | `commitOrder(CafeTick(...))` |
| Check policy | `CafeOrderInstruction.riskOf(tick, stock)` |
| Install | `installGates()` |

## 2.6 Acceptance checklist
- [x] Demo implements instruction, chain, observe, txApply.
- [x] Every BRD test compares actual vs expected and calls `expect()`.
- [ ] All tests pass (FR-03, FR-05, FR-06 failed this run due to harness timing).

## 2.6b BRD acceptance traceability
| BRD ID | Test | Result |
|---|---|---|
| FR-01, FR-02, FR-04, FR-07 | BRD group | Verified |
| FR-03, FR-05, FR-06 | BRD group | Failed (harness) |
| DR-01, DR-02, DR-03 | BRD group | Verified |
| AR-01, AR-02 | BRD group | Verified |
| BR-01, BR-02 | BRD group | Verified |
| NFR-01, NFR-02, NFR-03 | BRD group | Verified |

## 2.7 See also
HowTo-Mitose-Cell.md, HowTo-Mitose-Flow.md, HowTo-Mitose-Tissue.md.
