---
name: mitosis-mitose
description: >-
  Run the Mitose pipeline in the Mitosis (cell) monorepo: turn a business
  requirement into a BRD, WalkThrough, and Demo using Cell, Flow, and Tissue
  parts. Use when the user says "Mitose" or asks to build a solution from a
  business requirement in this repository.
---

# Mitose pipeline (repository-internal)

## Rules

1. Read `guide/HowTo-Mitose.md` and execute the Mitose pipeline exactly
   as written.
2. Honor the pipeline gates: no WalkThrough before a BRD exists, no Demo
   before the user accepts the WalkThrough.
3. Place Cell / Flow / Tissue parts with `guide/HowTo-Mitose-Cell.md`,
   `guide/HowTo-Mitose-Flow.md`, and `guide/HowTo-Mitose-Tissue.md`.
4. Never overwrite an existing file in the output set without asking.
5. Spelling: "Mitose" is intentional (the German verb *to undergo
   mitosis*). Do not correct it to "Mitosis".
6. Before trusting a symbol's doc block, run
   `dart run tool/ai_preflight.dart` from the owning package and fix any
   STALE pins.
7. When `### AI Agent Guide` blocks change, regenerate
   `lib/doc/api_chooser.dart` and the skill matrix
   `skills/<skill>/references/api_chooser.md` with
   `dart run tool/generate_api_chooser.dart` from the owning package.
