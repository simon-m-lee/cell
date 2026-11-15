# Phase 7 — Day-1 pre-flight verdict

Recorded: 2026-11-15, against the live workspace substrate
(`cell` 1.1.0, `cell_tissue` 1.0.0, `cell_organ` 1.0.0).

## 1. Pre-flight checks

| Check | Result |
|---|---|
| Phase 0–6 tests | 393/393 green |
| `@Deprecated` in `lib/` | none |
| `TODO:` / `FIXME:` in `lib/` | none |
| Phase 2 pulse recording (`receptor_fix_test.dart`) | green |
| `cell_organ` available | 1.0.0, in the root workspace |
| `cell_organ` public surface | `Blend(name, fields:)`, `ValueField`, `Many`, `TestStem` verified from source |

## 2. `TrainedPolicy.applyTo` context matrix

| Base context | Result |
|---|---|
| Plain `Context` | writes `cell_mind.policy` into `Ontology.constraints` (Phase 3 tests) |
| `DeputyContext` | does not expose the `Ontology.constraints` pillar — use the source cell's plain context (documented, Phase 6 C5) |
| `Context.system` | evolve accepted; trained block lands in the returned context |

## 3. Live-API adaptations for the acceptance pipeline

The plan's sketch references APIs that do not exist on the live
substrate and are adapted:

- `DeputyContext.observer/delegate/gatekeeper` → `DeputyContext(
  baseContext:, authority:, role:)`.
- `PulseContext.userAction` → `PulseContext.fromEntries([...Provenance])`.
- `Context.module` / `Mandate.authority` on plain `Context` →
  `Context.fromEntries([Ontology...])`.
- Agent `spawn` requires `routeIn` for debates (Phase 6 C1).
- Deployed training applies via a rebuilt gate
  (`contextAware() + learnedPolicy()` on the evolved context).

## 4. Verdict

PROCEED to the acceptance pipeline, cross-library tests, API freeze,
and documentation gates.

## 5. Phase 7 execution findings

### F7.1 — 0.6.1 hotfix (organ host-rule cast)

`cognitive()` cast `cell.validate as TestCell<C>`; organ stems expose a
`TestStem` object (same call contract) and crashed the cast. Fixed in
0.6.1 with an adaptive closure dispatch. `1.0.0` is a pure version
bump on top of 0.6.1 per D1.

### F7.2 — Organ stems cannot host recorders (API-level)

Organ's `deputy` accepts only `TestStem` gates; a `TestCell` recorder
cannot sit in that chain. `cognitive(cell: blend)` is unsupported in
v1.0 — documented limitation; composition goes through a bound
ingress (recipes 10/11, `cross_library_test.dart`).

### F7.3 — Bound organ blends reject async ingest

The pass-through relatable receptor throws `UnimplementedError` on
the async synapse path. Cross-library tests therefore keep handles on
the ingress.

### F7.4 — Coverage toolchain

Dart VM coverage emits line/function data only (no branch metric).
The CI gate applies the plan's 88% threshold to lines via
`tool/coverage_report.dart`. Measured: **97.3%** (1215/1249).

### F7.5 — Cookbook discovery

`dart test` auto-discovers only `*_test.dart`; the plan's numbered
cookbook names require explicit invocation (CI lists all 15).

### F7.6 — Publish dry-run

`cell_mind`'s own dry-run reports 0 warnings when run through
`tool/release-publish.sh --dry-run packages/cell_mind` (the root
`.pubignore` `/packages/**` rule must be neutralised). A package-level
`LICENSE` was added and `.pubignore` updated.

### F7.7 — Acceptance checks are hard checks

`dart run` does not enable asserts, so `example/09_acceptance.dart`
uses throwing `_check` calls — the pipeline self-verifies in CI.

## 6. Final verdict

PROCEED to 1.0.0: all Phase 7 gates green.
