# Phase 6 — Day-1 precursor verdict

Recorded: 2026-11-15, against the live workspace substrate
(`cell` 1.1.0, `cell_tissue` 1.0.0).

## 1. The "Phase 2 fix" is already satisfied

The plan's D1 targets the rc.9-era implementation
(`Nucleus.evolve(testRule:)` + shared receptor). The live
implementation uses `cell.deputy(testRule: recorder)` — a deputy view
whose own validation chain IS the recorder:

- Pulses through `handle.cognitive` ARE recorded (pinned by
  `receptor_fix_test.dart` and ~250 runtime/learning/approval tests).
- `handle.cell` (the principal) is not recorded — correct.
- `apply` through `handle.cognitive` is recorded — correct.

`Nucleus`/`Receptor` are library-private in `cell` 1.1.0 — the
plan's `receptor: cell._nucleus.receptor.clone` is impossible
cross-package, and unnecessary. **No runtime.dart change shipped.**

## 2. Live primitives verified

| Check | Result |
|---|---|
| `Cell.deputy({context, testRule})` | present; returns `FutureOr<Cell>` |
| Deputy views implement `OpenCell` (emittable) | **NO** for plain-cell principals — `_Cell` without `emit` |
| `Cell.id` | present |
| `PulseContext.parentTraceId` / `traceId` | present |
| `DeputyContext({baseContext, authority, role, …})` | present |
| `IngressHandle.ingest(Pulse<I>)` | present — the debate routing channel |

## 3. Findings discovered during implementation

### C1 — Plain-cell deputies are not emittable

`agent.agentView` is not an `OpenCell`; questions cannot be injected
through it. `AgentSpec.routeIn` (user-provided, usually
`source.ingest`) is the debate channel. Documented in
`guide/08-Agents.md` §2.

### C2 — The plain-cell deputy path accepts unrelated mandates

The causal-integrity throw in `deputy.dart` did not fire for an
unrelated `DeputyContext` in practice. Documented leniency; spawn
succeeds and the agent carries the mandate it was given.

### C3 — A pulse is completed at its first terminal

Debates ingest the question once per shared source (identity-set
dedup) and never re-route; a second round cannot change stateless
votes — the loop breaks after round 1 without consensus.

### C4 — `Verdict.type` added

`accept`/`reject`/`defer` discriminants on the sealed verdict
classes — needed by narratives and span status.

### C5 — Training base contexts must be plain `Context`s

`TrainedPolicy.applyTo` writes `Ontology.constraints`, which deputy
contexts do not expose. Agent training uses
`agent.sourceCell.context`.

## 4. Verdict

PROCEED: XAI and agent modules ship on the live substrate with the
adaptations above; the Phase 2 recording claim was already true and
is now pinned by `receptor_fix_test.dart`.
