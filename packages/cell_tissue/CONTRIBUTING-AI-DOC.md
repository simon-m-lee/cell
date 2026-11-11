# CONTRIBUTING-AI-DOC — AI-facing doc-comment convention for `package:cell_tissue`

Implements Phase 1 of the AI-facing documentation enhancement. The normative format is the
`### AI Agent Guide` block appended to public doc comments; see
`packages/cell/CONTRIBUTING-AI-DOC.md` for the canonical spec (same rules,
Tissue-specific content below).

## Tissue-specific rules

1. **Layer assertion is line 1:** `**Layer:** Tissue — ...`. A Tissue type is a
   governed book. It is never a Cell factory and never a Flow operator.
2. **When NOT to use** pulls from `lib/doc/ai_anti_patterns.dart` macros
   (`{@macro ai-do-not-testcell-on-tissue}`, etc.).
3. **Live signature pins against `cell_tissue:`** — e.g.
   `` `TissueList<E>({testRule, ...})` — pinned at `cell_tissue: 1.0.0` ``.
4. **Guide pointers** use `HowTo-Mitose-Tissue.md` §2.x with the stable anchor
   added in Phase 2 (`#tissue-list`, `#tissue-set`, `#tissue-map`,
   `#tissue-queue`, `#tissue-value`, `#tissue-testtissue`, `#tissue-deputies`).
5. **Cross-layer** states when to leave Tissue: entry is `Cell.ingress`, the
   decision is a `cell_flow` instruction, and `Cell.observe` is the only glue
   that may write the books.
6. **Minimal compilable examples** are synchronous. The generated example file
   imports `package:cell_tissue/cell_tissue.dart` (which re-exports `cell`).

## Machinery

| Tool / test | Phase | What it enforces |
|---|---|---|
| `tool/generate_ai_examples.dart` + `test/ai_guide_examples_test.dart` | 3.1 | Every `Minimal compilable example` compiles and runs, exit 0. |
| `test/seam_test.dart` | 3.2 | No `testRule: TestCell` on any Tissue constructor in `example/`. |
| `dart run tool/ai_preflight.dart` | 3.3 | Pins vs resolved versions; exits non-zero on drift. Also checks HowTo pins. |
| `tool/ai_failure_log.dart` + `tool/ai_failure_log.jsonl` | 6.1 | Structured log of real AI failures; reviewed quarterly. |
| `tool/generate_api_chooser.dart` + `test/api_chooser_up_to_date_test.dart` | 6.2 | `lib/doc/api_chooser.dart` generated from the guide blocks. |
| `guide/LEDGER-AI-Generator.md` §7.1 | 6.3 | Every Failed ledger row cites the block's `When NOT to use` line ("Did you try this?"). |

## Coverage

Phase 1 covers the five collection types, `TestTissue`, and the deputy /
`.unmodifiable` surface (the whole public Tissue layer — it is small).
