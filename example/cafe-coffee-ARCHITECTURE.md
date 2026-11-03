# ARCHITECTURE — Café Order & Stock Desk

**Generated via Document_AI_MasterGenerator.md → ARCHITECTURE-AI-Generator.md**

## 2.1 One-paragraph summary
The Café Order & Stock Desk is a Cell-variant reactive pipeline. External events enter through `Cell.ingress`. A custom `CafeOrderInstruction` (extending `FlowInstructionBase`) decides whether an order proceeds or is rejected. Two chains (`proceed` / `reject`) are assembled with `MapValue` and `toHandle`. The only place that writes Tissue books is a `Cell.observe` glue. Multi-value commits use `Cell.txApply`.

## 2.2 See-also name plate
| Artifact | Name |
|---|---|
| BRD | `cafe-coffee-BRD.md` v0.2.0 |
| WalkThrough | `cafe-coffee-WalkThrough.md` |
| Demo | `cafe-coffee-Demo.dart` |
| Ledger | `cafe-coffee-LEDGER.md` |

## 2.3 Layering
| Layer | Component | Role |
|---|---|---|
| Ingress | `tickIn` (`Cell.ingress`) | Receives `CafeTick` |
| Decision | `CafeOrderInstruction.riskOf` | Pure policy |
| Chain | `proceedGate + toLevel`, `rejectGate + toLevel` | Assembly |
| Glue | `Cell.observe` | Only writer to Tissue books |
| Commit | `Cell.txApply` | Multi-value commit |
| Books | `stock`, `orders`, `payments`, `outcomes` | TissueMap / TissueList |

## 2.4 Ownership matrix
| Book | Written by | Read by |
|---|---|---|
| stock | observe / txApply | instruction, tests |
| outcomes | observe / txApply | tests, report |
| orders | txApply | tests |
| payments | txApply | tests |

## 2.5 Locking
No explicit locks. Tissue mutations are serialized by the Cell runtime.

## 2.6 Failure semantics
- Payment rejected → outcome `undone`.
- Insufficient stock → `riskOf` returns reject.
- qty ≤ 0 → `riskOf` returns reject.
- Success → stock reduced, outcome `succeeded`.

## 2.7 Extending the demo
- Carry the full `CafeDecision` into the observer.
- Drive REFUND and COMPLY from main.
- Replace the simplified payment stand-in with a real terminal adapter.

## 2.8 Anti-patterns
- Writing Tissue books inside the instruction.
- Using `testRule: TestCell` on Tissue constructors.
- Printing LEDGER PASS without an `expect()` that compared actual vs expected.

## 2.9 Reading order
1. BRD
2. WalkThrough (especially §5.12)
3. Demo
4. Ledger

## 2.10 See also
HowTo-Mitose-Cell.md, HowTo-Mitose-Flow.md, HowTo-Mitose-Tissue.md.
