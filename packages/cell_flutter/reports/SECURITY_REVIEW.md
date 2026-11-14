# Security Review — 1.0 Gate

**Review date:** 2026-11-13
**Reviewer:** AI second-pass auditor (separate read-through of `lib/src`,
not the implementer pass)
**Scope:** `cell_flutter` 0.5.0 binding layer (widgets, hooks, testing
utilities) on `cell` 1.1.0

## Method

Fresh-eyes read of every `lib/src` file against the nine target areas
from the phase plan, plus a targeted re-run of the relevant tests. The
binding layer has no deputy logic of its own (deputies are cell-core
concerns); where a plan item lives below the binding, it is scoped as
documented below.

## Findings

| ID | Severity | Component | Description | Mitigation |
|---|---|---|---|---|
| S1 | low | `CellScope` | Nested scopes with the same `Symbol` warn but still shadow | Intended behavior; documented in the dartdoc and `HowTo-CellScope.md` |
| S2 | low | `CellListener` | Mid-frame deferral can reorder pulses across the frame boundary | Documented in `HowTo-CellListener.md` |
| S3 | low | `Cell.asValueCell` | The mirror leaks if the caller ignores the returned `dispose` | API contract makes the leak visible; documented in the dartdoc |
| S4 | low | `useCellAsync` | Snapshot persists across cell swaps; diverges from `CellAsyncBuilder` | Documented in the dartdoc and `HowTo-Hooks.md` §6; keying workaround provided |
| S5 | low | `CellBuilder` | Emit-during-build is a debug assert; release mode is best-effort | Documented; the framework's build-phase guard fails loudly in debug |
| S6 | low | `CellTestHarness` | `add` after `dispose` is allowed if the caller reuses a disposed harness incorrectly — the guard exists and throws | Guard tested; harness is documented as one-shot |

## Target-area walkthrough

1. **Deputy chain transitive narrowing** — out of binding scope (cell
   core). The binding consumes `unmodifiable` views; the read-only
   enforcement is tested in `cell_notifier_test.dart` (assignment
   throws).
2. **`CellScope` type safety under nested shadowing** — wrong-type
   lookups throw `StateError`; unknown ids fail an assert in debug.
   Covered by `cell_scope_test.dart` + `cell_scope_shadow_test.dart`.
3. **`CellListener` `mounted` guards** — the widget checks
   `context.mounted` before post-frame delivery and contains handler
   errors via `FlutterError.reportError`. Covered by
   `cell_listener_test.dart` (including a throwing handler).
4. **`CellAsyncBuilder` error containment** — error pulses and
   type-mismatch pulses surface as error snapshots, never as crashes.
   Covered by `cell_async_builder_test.dart`.
5. **Hook subscription discipline** — `useCell`/`useCellListener`/
   `useCellAsync` dispose their egresses in `useEffect`; stale-closure
   risk is contained by `useRef`/`useMemoized` keys. Covered by
   `hooks/*_test.dart`.
6. **`asValueCell` dispose** — stop is idempotent and releases the
   egress. Covered by `cell_as_value_test.dart`.
7. **`PulseRecorder.stop`** — idempotent, releases the egress. Covered
   by `record_pulses_test.dart`.
8. **`CellTestHarness.dispose`** — stops recorders, does not dispose
   user-owned cells. Covered by `cell_test_harness_test.dart`.
9. **`CellBuilder` emit-during-build** — debug assert verified in
   `cell_builder_test.dart` (sibling-notification setup).

## Result: PASS

No findings above "low". Gate G8 passes.
