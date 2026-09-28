# AGENTS.md

Guidance for AI agents working in this repository.

## Repository

This is the **Mitosis** umbrella monorepo (Dart): `packages/cell` (core), `packages/cell_flow` (orchestration), and `packages/cell_tissue` (application).

## Mitose pipeline trigger

When the user says **"Mitose"**, **"run Mitose"**, or asks to build a solution from a business requirement:

1. Read [`guide/HowTo-Mitose.md`](guide/HowTo-Mitose.md) and execute the Mitose pipeline exactly as written.
2. Honor the pipeline gates: no WalkThrough before a BRD exists, no Demo before the user accepts the WalkThrough.
3. Use [`guide/HowTo-Mitose-Cell.md`](guide/HowTo-Mitose-Cell.md), [`guide/HowTo-Mitose-Flow.md`](guide/HowTo-Mitose-Flow.md), and [`guide/HowTo-Mitose-Tissue.md`](guide/HowTo-Mitose-Tissue.md) when placing Cell / Flow / Tissue parts.
4. Never overwrite an existing file in the output set without asking.

## Spelling

"Mitose" is intentional (the German verb *to undergo mitosis*). Do not "correct" it to "Mitosis".

## API sources

The framework is published as `cell`, `cell_flow`, and `cell_tissue` on pub.dev. Never invent an API from memory; resolve live signatures from the package sources in this repository or from pub.dev.
