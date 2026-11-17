# Code Review Resolution

**Reviewed document:** `research/Flutter-Binding/code_review.md` (a review of the
`cell_flutter` **0.1.0** snapshot).

**Verified against:** `cell_flutter` **0.6.0** (hardening, unreleased) at
`packages/cell_flutter/`, with the in-repo `cell` core that the package
dev-resolves via `dependency_overrides`, and with published `cell` 1.1.0 as
the consumer floor (`cell: '>=1.1.0 <2.0.0'`).

**Date:** 2026-11-16

> The review document was removed from the repository during verification
> (the user reorganized `research/Flutter-Binding/`), so this file is the
> canonical record of the claim-by-claim outcome.

---

## Core facts established before judging the claims

1. **Published `cell` 1.1.0 has no `Cell.latestPulse`.** Only the in-repo
   `cell` core (with the replay round-trip, commit `05b4895d`) retains the
   latest pulse. The binding's published constraint range therefore cannot
   call or document that API — the review's proposed C1 fix (delegate to
   `Cell.latestPulse`) is not possible for consumers today.
2. **Only `Cell.fromFuture` emits `type: 'error'` pulses.** Verified in
   both the published and the in-repo core: `Cell.fromStream` cancels or
   ignores stream errors, and `Cell.asyncMap` drops mapper failures
   (source-pulse `_fail` + empty `onError`). The "all three emit" wording
   found in several 0.6.0 doc comments was wrong.
3. **`Cell.operator ==` is nucleus-based.** Deputies equal their
   principal and share its `hashCode`. `CellScope.updateShouldNotify`'s
   `identical` comparison therefore notified dependents for equal deputy
   swaps — a real (if minor) rebuild-storm bug.
4. **The binding's widgets open one `Cell.observe` per subscription and
   stop it on dispose.** The seed window (`!_ready` branch between
   `_bind()` and the end of `initState`) is unreachable through public
   core APIs — probed with persistent-synapse rehydration, which does not
   deliver on link in this core.

---

## Critical findings

| Claim | Verdict | Resolution |
|---|---|---|
| **C1.** Late subscribers to plain async cells never see the retained value | Valid as a behavior; the docs also referenced `Cell.latestPulse`, which does not exist for consumers | The review's option (b) was taken: the constraint is documented uniformly. All `Cell.latestPulse` references were removed from lib docs, `README.md`, and `ARCHITECTURE-flutter.md`. The duplicated per-file seed logic was consolidated into one shared `seedFromRetained` in `pulse_delivery.dart`. Behavior is unchanged: `retainedPulseOf` serves `ValueCell` sources only; plain cells wait for the next live pulse or take an explicit `initial` / `initialSnapshot`. A future `cell` release with a public retained-pulse accessor is the upstream fix. |
| **C2.** Contradictory per-source error-pulse claims | Valid — three files still claimed `fromFuture` / `fromStream` / `asyncMap` all emit error pulses | Every doc comment now states the single truth: only `Cell.fromFuture` emits `type: 'error'` pulses. Fixed in `cell_async_builder.dart`, `cell_listener.dart`, `cell_stream.dart` (including the misleading `asyncMap` → `ErrorView` example, now `fromFuture`-based). `record_pulses.dart`, `use_cell_async.dart`, `testing.dart`, and `hooks.dart` already agreed. `ARCHITECTURE-flutter.md` §7 marks the divergence **resolved**; §8 rule 8 updated. |
| **C3.** `CellNotifier`'s build-phase throw is contagious across unrelated widgets | Valid; the synchronous-notification design is kept | The review's required actions (documentation) are done. `CellBuilder`, `CellSelector`, and `CellNotifier` now carry explicit *Build-phase pulses* sections: the error is attributed to the `CellBuilder` element, not the emitter, and no widget may mutate a cell from inside `build`. `ARCHITECTURE-flutter.md` §5 now states the two load-bearing consequences (error attribution, burden on every cell with a `CellBuilder` in the tree). The optional `DeferredCellNotifier` variant was declined — a deferring `ValueNotifier` would break non-widget consumers of the `Listenable` contract. |

---

## Significant findings

| Claim | Verdict | Resolution |
|---|---|---|
| **S1.** `CellValueBuilder._store` silently drops errors during seeding | Valid, but the seed window is unreachable through public core APIs | Fixed structurally rather than per-branch: the separate initState seeding path was removed from `CellValueBuilder` **and** `CellAsyncBuilder`. Every pulse now takes one code path (build-phase deferral included), so the `emitErrors` contract applies uniformly. New tests cover build-phase deferral and the disposed-before-flush case. |
| **S2.** `useCell` shows one stale frame on cell swap | Valid; hooks cannot reset `useState` synchronously during build | Documented as *Design Note: one-frame flash on cell swap* in `use_cell.dart`, with the key-the-widget remedy. `ARCHITECTURE-flutter.md` §8 rule 7 now lists it alongside the `useCellAsync` cell-swap exception. |
| **S3.** `useCellAsync` does not seed from `snapshotForCell` | Valid | One-line fix: the `useState` initializer now seeds via `snapshotForCell<V>(cell)`, matching `CellAsyncBuilder` for `ValueCell` sources. Docs updated; regression test added. |
| **S4.** `useCell` lacks the collection-equality assertion | Valid | Shared `isCollectionLike` helper added to `pulse_delivery.dart`; `useCell` asserts in debug on the initial and recomputed selection (message mirrors `CellSelector`). `CellSelector` now uses the same helper, which also removes the review's redundant `is! String` guard. Tests cover assert / no-assert / changed-select cases. |
| **S5.** `expectCellGolden` docs teach the misleading `emitAndSettle` re-pump | Valid | Example rewritten to mutate the cell directly; new *every call starts from a fresh pump* note added. |
| **S6.** `PulseRecorder.pulses` copies on every access | Valid | Documented as a **snapshot copy** (O(n) per access) on the getter and in the class docs. The copy contract is kept — no behavioral change. |
| **S7.** `CellScope.updateShouldNotify` uses `identical`, but `Cell ==` is logical identity | Valid | Comparison switched to `==`; docs updated. Regression test: swapping a registered cell for a non-identical, equal deputy does **not** rebuild dependents. |
| **S8.** `CellScope.maybeOf` throws on type mismatch | Already documented in current code | Added the explicit first-line note "**`maybeOf` does not swallow type mismatches.**" |

---

## Minor findings

| Item | Resolution |
|---|---|
| Duplicated `_seeded` / `_seed` seed logic | Consolidated into `seedFromRetained` (see C1). |
| Redundant `o is! String` guard in `CellSelector._isCollection` | Removed via the shared `isCollectionLike` helper (Dart `String` is not `Iterable`). |
| `useCellListener` captured `BuildContext` goes stale on reparenting | Documented in the hook's *How it works* with the key-the-widget remedy. |
| `CellTestHarness.emitAndSettle` lacks the `_disposed` guard | Guard added with a regression test; the corresponding `ARCHITECTURE-flutter.md` §7 gap item removed. |
| `expectCellGolden` requires `name` even with `goldenPath` | `name` is now optional when `goldenPath` is supplied (debug assert requires one of them); docs updated. |
| `snapshotForPulse` / `snapshotForCell` are public exports of helpers | `cell_flutter.dart` barrel marks them "for advanced use — not the primary widget surface". |
| `CellNotifier` invalidated-cell message lacks widget context | Left as-is: the message names `CellNotifier`, which is accurate for direct users; the per-widget build-phase docs cover the widget path. |
| `!_ready`-adjacent dead `!mounted` check in `CellValueBuilder._onPulse` | Removed with the seed path (S1). |
| `CellListener` context-after-await enforcement | Already documented (`context.mounted` after `await`); no change. |
| `pumpWithCells` does not `pumpAndSettle` | Already documented; no change. |
| `CellScope.shadowWarned` mutable `@visibleForTesting` set | Already documented as mutable for tests; no change. |
| `useCellAsync` wrong-typed `initialSnapshot` | Reviewer judged it "not a real concern"; no change. |
| README core test counts (1174/1174 etc.) | Not present in the current README; already resolved. |

---

## Additional documentation-drift fixes made in the same pass

- `README.md` was still the 0.1.0-era document (version badges, "What's
  new in 0.1", links to deleted `ARCHITECTURE.md` / `FEATURES.md` /
  `TEST_VERIFICATION.md`, and a "production-grade" Status claim). It now
  carries the honest 0.6.0 status (G3 benchmark failure, G6 CI-carried
  fuzz, G10 blocked), fixed links, hooks cell-swap caveats, and the
  plain-cell retained-seeding non-claim.
- `lib/cell_flutter.dart` and `lib/hooks.dart` library docs said
  "Experimental (0.1.0) / production-grade" — replaced with the honest
  0.6.0 hardening status.
- `pubspec.yaml`'s `cell` constraint comment claimed published 1.1.0
  "includes the replay round-trip fix" — it does not; the comment now
  states the published floor and where the replay round-trip lives.
- `guide/MigratingFrom-Riverpod.md`'s `fromFuture` / `fromStream` snippets
  lacked the `journal:` parameter required by the in-repo core, which made
  a fresh snippet extraction fail to compile. The snippets now pass
  `journal: RecordingJournal()` with an explanatory note, keeping the
  generated `test/migration/_extracted_test.dart` faithful to the guides.
- `CHANGELOG.md` 0.6.0 gains a "Code-review resolution" block summarizing
  all of the above.

---

## Deliberate non-changes

- **No binding-side retained-pulse side table** (C1 option a): the binding
  cannot reconstruct an emission that occurred before *any* subscription;
  only an upstream `cell` release with a public retained-pulse accessor
  can fix that.
- **`CellNotifier` stays synchronous** (C3 optional variant): a deferring
  `ValueNotifier` would silently break every non-widget `Listenable`
  consumer; the review's required documentation actions were completed.
- **`useCell`'s one-frame flash** (S2): genuinely unfixable inside a hook;
  documented per the review's accepted alternative.
- **`CellScope`'s debug-assert contract** (`AssertionError` in debug,
  `StateError` in release) is preserved; the release-only fallback lines
  are `coverage:ignore`-marked because debug asserts make them unreachable
  in debug coverage runs.
- **The `cell` core package is untouched.**

---

## Verification gates (all green)

| Gate | Result |
|---|---|
| `flutter test` (full suite) | **235 passed + 1 skipped** (macOS-only golden) |
| Line coverage, `lib/src/**` (21 files) | **21/21 at 100%** via `tool/check_coverage.py` |
| `flutter analyze` | clean (package, `example/`, `benchmark/`) |
| Snippet extraction | `--check` passed; 22 blocks (7 skipped, 15 extracted); extracted tests `+15` pass |
| Link checker | `LINK CHECK PASSED` (44 local references) |
| Example suite | 19 tests pass |

Coverage annotations: two `CellScope._lookup` release fallbacks are
`coverage:ignore`-marked (unreachable in debug), and one `null is V` line
in `seedFromRetained` is block-marked with a comment because the VM does
not attribute that line even though `test/pulse_delivery_test.dart`
executes it — the direct unit tests for `seedFromRetained`,
`retainedPulseOf`, and `isCollectionLike` are the behavioral evidence.
