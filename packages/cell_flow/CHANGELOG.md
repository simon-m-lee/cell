# Changelog

All notable changes to **cell_flow** are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Version numbers follow [SemVer](https://semver.org/). **Mitosis** is the
release codename; it is not part of the SemVer string.

## [Mitosis (1.0.0-rc.2.0.1)] - Release Candidate

Patch on the RC2 line. This release focuses on architectural documentation,
topographical terminology alignment, and library hygiene.

### Changed

- **Pedagogical Alignment**: Regenerated all public API documentation across `flow_core.dart`, `fluent_operator.dart`, and the `instruction/` family using the **Transcription Orchestrator** style.
- **Topographical Terminology**: Standardized terminology throughout the library. Documentation now formally refers to the graph as the **Topography**, inputs as **Stimuli**, event containers as **Pulses**, transformations as **Evolutions**, and results as **Materializations**.
- **Orchestration Roles**: Refined documentation for specific logic gates to clarify their role in the topography:
  - **Bridges**: Temporal operators governing shift and cadence (`Delay`, `Interval`).
  - **Gates**: Integrity and control operators (`Filter`, `Debounce`, `Timeout`).
  - **Flatteners**: Structural transformation operators (`Map`, `ConcatMap`, `SwitchMap`).
  - **Anchors**: Foundational graph nodes (`Cell`).

### Added

- **Quick Start Guide**: Introduced [`HowTo-Start.md`](HowTo-Start.md), providing a comprehensive entry point for developers to grasp the **Mitosis** mental model.
- **Topographical Walkthroughs**: Formally linked clinical and reactive search demos in the `README.md` and `dartdoc_options.yaml` as **Blueprint Templates**.
- `fluent_operator_test.dart`: Exhaustive test coverage for `CellFlowOperators` and `FlowOperators` ensuring chains correctly anchor to the `IngressHandle.cell`.
- **Topographical Auditing Tools**: Enhanced PowerShell-native auditing scripts for identifying files missing provenance metadata (Copyright headers).

### Fixed

- **Documentation Hygiene**: Resolved all `dartdoc` warnings regarding unresolved references including `[result]`, `[FlowHandle.cell]`, and generic type parameters.
- **Receptor Integrity**: Fixed an issue where `FlowInstructionBase.future` evolution logic failed to correctly gate unhandled `Future.error` events.
- **Pulse Emission Logic**: Corrected the `AsyncFold` orchestrator to prevent triple-emit inflation during high-frequency ingress.
- **Error Propagation**: Refined `ConcatAll` to ensure synchronous inner-throwing iterables correctly route `StateError` to the appropriate `onError` orchestrator.

### Tests

- **1022** unit tests in **42** files, **440** groups (+77 tests, +1 file since RC2).
- Last full run: **+1022, exit 0**.
- Line coverage (`lib/`): **96.3%** (5557 / 5768).
  - `fluent_operator.dart`: **94.2%** (+2.5% coverage).
  - `flow_core.dart`: **100%** materialization coverage.

### Legal

- Copyright headers and authorship metadata aligned with the Mitosis topography standards.
- LICENSE coverage confirmed for MIT OR Apache-2.0.
## [Mitosis (1.0.0-rc.2)] - Release Candidate

### Added

- Async map variants: `AsyncMapConcurrent`, `AsyncMapLatest`,
  `AsyncMapSequential`, `AsyncMapWithRetry`, `AsyncMapWithTimeout`,
  `AsyncMapWithFallback`, `AsyncMapWithIndex`.
- Async fold variants: `AsyncFoldLatest`, `AsyncFoldExhaust`,
  `AsyncReduce`. `Flow.asyncFoldLatest` / `Flow.asyncFoldExhaust` on the
  static facade.
- Enhanced demos and walkthroughs:
  - `ICU-alarm-pipeline(enhanced)-Demo.dart` + WalkThrough
  - `domain-cells-txApply(enhanced)-Demo.dart` + WalkThrough
- `DEMO_GUIDE.md`, expanded `FEATURES-Flow.md`.

### Changed

- Receptor scrutiny and PulseShell defensive proxies on async paths.
- Dartdoc: `### When to use` / `### How it works` / `### Non-obvious`
  on `Flow` and `FlowInstruction`. Unresolved `[ref]` warnings cleared
  (qualified names, backtick generics).
- `analysis_options.yaml`: `public_member_api_docs`, stricter inference.
- `dartdoc_options.yaml` links walkthroughs into the API reference.

## [Mitosis (1.0.0-rc.1)] - Release Candidate

First public release candidate. Operators are `FlowInstruction`s on the
same graph as `package:cell` `1.0.0-rc.1`.

### Added

- `Flow` facade: static factories return `FlowHandle`.
- Fluent extensions on `Cell` and `FlowHandle` (`fluent_operator.dart`,
  `part of` `flow.dart`).
- `FlowInstruction` + `operator +` → `InstructionChain` → one `Receptor`
  via `toHandle`.

#### Create

- `Of`, `FromIterable`, `Range`, `Repeat`
- `FromFuture`, `DeferFuture`, `FromFutureOr`, concat/merge/switch/exhaust
  from-future, `FromFutures`, `FromFuturesInOrder`, `ForkJoinFutures`,
  `RaceFutures`, retry / timeout / fallback, `MapToFuture`
- `FromStream`, `DeferStream`, `ConcatFromStream`, `MergeFromStream`,
  `SwitchFromStream`, `MapToStream`

#### Transform

- `MapValue`, `MapTo`, `MapWithIndex`, `MapNotNull`, `MapWhen`
- `Pluck`, `PluckOr`, `PluckAll`, `PluckPath`
- `Scan`, `Reduce`, `Pairwise`

#### Async transform

- `AsyncMap` and concurrent / latest / index / retry / timeout / fallback
- `AsyncExpand` and concurrent / latest / exhaust
- `AsyncFold`, `AsyncFoldLatest`, `AsyncFoldExhaust`, `AsyncReduce`

#### Filter / take / skip / distinct

- `Filter`, async filter family, `FilterNotNull`, `FilterType`,
  `FilterAllowed`, `FilterBlocked`, `FilterByTime`
- `Take`, `TakeWhile`, `TakeUntil`
- `Skip`, `SkipWhile`, `SkipUntil`, `SkipFirst`, `SkipLast`,
  `SkipRepeated`, `SkipWhen`
- `Distinct` and variants in `distinct.dart`

#### Flatten

- `ConcatMap`, `Concat`, `ConcatAll`, `ConcatFirst`, `ConcatLatest`
- `MergeMap`, `SwitchMap`, `ExhaustMap`

#### Combine

- `MergeWith`, `Merge`, `MergeAll`
- `ZipWith`, `Zip`, `ZipAll`
- `CombineLatestWith`, `CombineLatest`, `WithLatestFrom`
- `Race`

#### Time

- `Delay`, `DelayWithSelector`, `DelayWhen`, `DelayLatest`,
  `DelayWithTrailing`, `DelayWithTimeout`
- `Debounce` family
- `Throttle`, `ThrottleLeading`, `ThrottleTrailing`
- `Sample`, `SampleTime`, `Audit`, `AuditTime`
- `Timeout` family
- `Interval`, `IntervalWithValue`, `IntervalWithState`, `TimerPulse`

#### Collect / route / control

- `BufferCount`, `BufferTime`, `BufferWhen`, `BufferWithPredicate`,
  `BufferWithTimeAndCount`
- `WindowCount`, `WindowTime`
- `GroupBy`, `GroupCollect`, `GroupByCount`
- `Partition`, `PartitionMap`, `PartitionOnly`, `Iif`
- `StartWith`, `Share`, `ShareReplay`, `Retry`, `Tap` / `TapAll` /
  `TapWithIndex`

### Notes

- Cells do not complete. Concatenate **inners**, not Cell-then-Cell.
- `reduce` / `scan` are running folds, not terminal Rx `reduce`.
- `MapValue` is used instead of `Map` so it does not clash with
  `dart:core`.
- `filter.dart` no longer owns `Debounce`, `Throttle`, `Take`, `Skip`,
  or `Distinct`.
- Application import is `package:cell_flow/flow.dart` only.

### Docs

- `README.md`, `ARCHITECTURE-Flow.md`, `FEATURES-Flow.md`
- `HowTo-Fluent_Operator.md`, `HowTo-FlowInstruction-Receptor.md`
- Example gates: `example_*.dart`

[Mitosis (1.0.0-rc.2.0.1)]: https://github.com/simon-m-lee/cell/tree/master/packages/cell_flow
[Mitosis (1.0.0-rc.2)]: https://github.com/simon-m-lee/cell/tree/master/packages/cell_flow
[Mitosis (1.0.0-rc.1)]: https://github.com/simon-m-lee/cell/tree/master/packages/cell_flow
