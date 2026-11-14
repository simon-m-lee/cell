# Documentation Accuracy Audit — 1.0 Gate

**Audit date:** 2026-11-13
**Auditor:** AI second-pass auditor (manual checklist read of every
document)

## Checklist results

| # | Document | Verified replay probes named | Concurrency case named | Per-source error behavior named | Pass |
|---|---|---|---|---|---|
| 1 | `README.md` | ✅ | ✅ | ✅ | ✅ |
| 2 | `doc/CHOOSING.md` | ✅ | ✅ | ✅ | ✅ |
| 3 | `guide/MigratingFrom-Riverpod.md` | ✅ (Step 5 + "what doesn't migrate") | ✅ | ✅ (per-source table) | ✅ |
| 4 | `guide/MigratingFrom-Bloc.md` | ✅ (Step 3 + live-API caveat) | ✅ | ✅ (per-source table) | ✅ |
| 5 | `guide/HowTo-CellAsyncBuilder.md` | N/A | ✅ | ✅ | ✅ |
| 6 | `guide/HowTo-CellSelector.md` | N/A | N/A | N/A (ValueCell requirement + bridge named) | ✅ |
| 7 | `guide/HowTo-DerivedCells.md` | N/A | ✅ | ✅ | ✅ |
| 8 | `guide/HowTo-Hooks.md` | N/A | ✅ | ✅ (incl. `useCellAsync` swap divergence) | ✅ |
| 9 | `guide/HowTo-Streams.md` | N/A | N/A | ✅ | ✅ |
| 10 | `guide/HowTo-Testing.md` | N/A | N/A | ✅ (timer caveat + `recordPulses` error behavior) | ✅ |
| 11 | Other guides (grep audit for "replay", "error pulse", "experimental", "stable") | — | — | — | ✅ |

Grep audit of all `guide/*.md` and `doc/*.md` for "replay", "error
pulse", "experimental", and "stable" found no mention that contradicts
the verified scope: replay claims are always scoped to the six probes
(pure state, debounce, throttle, `fromFuture`, `fromStream`), the
concurrency case is always marked as tracked separately (Gate G1.5),
and the per-source error behavior is always stated as "only
`Cell.fromFuture` emits error pulses today".

## Findings

None.

## Result: PASS

The documentation accurately reflects the verified replay scope, the
tracked-separately concurrency case, and the per-source error behavior.
**Gate G1 passes.**
