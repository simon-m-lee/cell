# CONTRIBUTING-AI-DOC — AI-facing doc-comment convention for `package:cell_flow`

Implements Phase 1 of the AI-facing documentation enhancement. The normative format is the
`### AI Agent Guide` block appended to public doc comments; see
`packages/cell/CONTRIBUTING-AI-DOC.md` for the canonical spec (same rules,
Flow-specific content below).

## Flow-specific rules

1. **Layer assertion is line 1:** `**Layer:** Flow — ...`. A Flow symbol is an
   operator / instruction. It is never a Cell factory and never a Tissue book.
2. **When NOT to use** pulls from `lib/doc/ai_anti_patterns.dart` macros
   (`{@macro ai-do-not-put-time-op-as-policy}`, etc.). Known behavioral issues
   (e.g. `ExhaustMap` busy-flag race, `Distinct` custom-comparator O(n²)) must
   be stated explicitly in the `When NOT to use` line until the code fix lands.
3. **Live signature pins against `cell_flow:`** — e.g.
   `` `Flow.map<S, T>(...)` — pinned at `cell_flow: 1.0.0` ``.
4. **Guide pointers** use `HowTo-Mitose-Flow.md` §3.x with the stable anchor
   added in Phase 2 (`#flow-create`, `#flow-transform`, `#flow-filter-take-skip`,
   `#flow-flatten`, `#flow-combine`, `#flow-time`, `#flow-collect-control`).
5. **Cross-layer** states when to leave Flow and open the Cell or Tissue HowTo
   (ingress/observe are Cell; `events.add` is Tissue via `Cell.observe`).
6. **Minimal compilable examples** are synchronous (or microtask-only) so the
   Phase 3 test stays fast. They use the public `package:cell_flow/cell_flow.dart`
   surface; instruction classes are exercised via their own doc blocks with a
   `src/instruction/` import in the generated example file.

## Machinery

| Tool / test | Phase | What it enforces |
|---|---|---|
| `tool/generate_ai_examples.dart` + `test/ai_guide_examples_test.dart` | 3.1 | Every `Minimal compilable example` compiles and runs, exit 0. |
| `test/seam_test.dart` | 3.2 | No Tissue write inside a `FlowInstructionBase` subclass in `example/`. |
| `dart run tool/ai_preflight.dart` | 3.3 | Pins vs resolved versions; exits non-zero on drift. Also checks HowTo pins. |
| `tool/ai_failure_log.dart` + `tool/ai_failure_log.jsonl` | 6.1 | Structured log of real AI failures; reviewed quarterly. |
| `tool/generate_api_chooser.dart` + `test/api_chooser_up_to_date_test.dart` | 6.2 | `lib/doc/api_chooser.dart` generated from the guide blocks. |
| `guide/LEDGER-AI-Generator.md` §7.1 | 6.3 | Every Failed ledger row cites the block's `When NOT to use` line ("Did you try this?"). |

## Coverage policy

Phase 1 covers the HowTo §3 catalog families and the `FlowInstruction` family
(PR B scope). The remaining ~50 operators are covered by `FEATURES-Flow.md`;
they receive guide blocks incrementally in later passes.
