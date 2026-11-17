# Benchmarks

**Hardware:** Windows 11, x64, 32 GB RAM (this development machine)
**Flutter:** 3.41.9 stable
**Dart:** 3.11.5
**Riverpod pin:** flutter_riverpod 3.x (resolved 2026-11-13)
**Bloc pin:** flutter_bloc 9.x (resolved 2026-11-13)
**Date:** 2026-11-13

## What we measure

- **Frame time** (p50, p99): wall-clock time per `tester.pump()`
  iteration, in microseconds. Median of 3 runs.
- **Rebuild count**: how many times the builder function is invoked.

## Scenarios

### 1. Single cell, single builder — 1000 updates

| Implementation | p50 (µs) | p99 (µs) | Rebuilds |
|---|---|---|---|
| `ValueListenableBuilder` (baseline) | 628 | 1801 | 1000 |
| `cell_flutter` `CellBuilder` | 786 | 2064 | 1000 |
| `riverpod` `ConsumerWidget` | 742 | 2445 | 1000 |
| `bloc` `BlocBuilder` | 456 | 1712 | 501* |

### 2. Ten cells, ten builders — 1000 updates (10 updates per iteration)

| Implementation | p50 (µs) | p99 (µs) | Rebuilds |
|---|---|---|---|
| `ValueListenableBuilder` (baseline) | 786 | 2841 | 10000 |
| `cell_flutter` `CellBuilder` | 1815 | 4050 | 10000 |
| `riverpod` `ConsumerWidget` | 949 | 3107 | 10000 |
| `bloc` `BlocBuilder` | 691 | 2755 | 5010* |

### 3. One hundred cells, one hundred builders — 100 updates

| Implementation | p50 (µs) | p99 (µs) | Rebuilds |
|---|---|---|---|
| `ValueListenableBuilder` (baseline) | 3782 | 6543 | 10000 |
| `cell_flutter` `CellBuilder` | 11072 | 19887 | 10000 |

### 4. `CellSelector` rebuild reduction

| Scenario | Rebuilds |
|---|---|
| `CellSelector` over a 3-field record, 1000 updates of irrelevant fields | 1 (initial) |
| Same workload on `CellBuilder` | 1000 |

## Benchmark verdict: FAIL on burst scenarios

The 1.5× gate passes on the primary display path (single builder:
1.25× p50 / 1.15× p99) but **fails on multi-builder bursts** (ten
builders: 2.31× p50; one hundred builders: 2.93× p50). The extra
per-update cost lives in the cell core's pulse machinery
(pulse construction, receptor traversal, egress delivery), which the
binding's per-pulse work (one notifier write) cannot remove without
changing `CellNotifier`'s documented synchronous contract. Optimizing
this is a `cell`-core concern, tracked for the 0.6.0 hardening cycle.

## Honest caveats

- Microbenchmarks on one machine; real apps have different
  distributions.
- \*Bloc rebuild counts are lower because `emit` deduplicates states in
  this workload; the wall-time comparison is still apples-to-apples.
- Riverpod's `ConsumerWidget` includes `ref.watch` overhead; the cell
  comparison is direct cell reference vs direct provider watch.
- Numbers are from a specific Flutter version and will shift with
  future releases. Re-run with `flutter test` in `benchmark/` and
  re-pin Riverpod/Bloc if either major-bumps.

## Conclusion

`cell_flutter` is within 1.5× of native `ValueListenableBuilder` on the
single-builder display path, and `CellSelector` eliminates rebuilds for
irrelevant updates entirely. Multi-builder burst scenarios exceed the
gate; the honest verdict is recorded above and blocks the 1.0 gate
(FAIL).
