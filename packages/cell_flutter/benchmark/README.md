# Microbenchmarks

Compares `cell_flutter` against the Flutter-native
`ValueListenableBuilder` and the popular `flutter_riverpod` /
`flutter_bloc` packages on the same scenarios:

- **single** — one cell, one subscriber, 1000 updates;
- **fanout** — one cell, ten subscribers;
- **list100** — a 100-item list where each row subscribes to one cell;
- **selector** — a multi-field cell where subscribers select one slice
  (cell_flutter only; the scenario also proves the selector does not
  rebuild on unrelated writes).

Each scenario measures wall-clock frame time per update (p50/p99)
inside `testWidgets` — one update per `tester.pump()`. The harness cost
is identical across implementations, so ratios are meaningful even
though absolute numbers are microbenchmark artifacts.

## Running

```bash
# From packages/cell_flutter:
dart run tool/benchmark.dart            # run + compare against the baseline
dart run tool/benchmark.dart --update   # run + write a new baseline
```

## The 15% gate

`tool/benchmark.dart` fails when any scenario in
`benchmark/baseline.json` regresses by more than 15% (p50 or p99),
**and** the absolute increase exceeds a 300µs noise floor. The floor
matters: a 15% relative gate on a 300µs p99 leaves only ~45µs of
budget, which is smaller than OS scheduling noise on shared runners.
Regressions must therefore exceed *both* thresholds.

The gate runs in CI (`tool/benchmark.dart --update` is only for
deliberate re-baselining after an intentional change, with a review of
the diff).
