# Cell Framework Benchmarks

The goal isn't "prove the framework is fast." It's three things:

1. **Validate the specific performance claims** the docs make.
2. **Catch regressions** before they ship.
3. **Give adopters a fair comparison** against RxDart and plain streams.

## Layout

```
benchmark/
├── harness.dart                  # shared fixtures (cell factories, shapes)
├── runner.dart                   # PR-suite runner -> current.json
├── compare.dart                  # regression gate vs baseline.json
├── baseline.json                 # reference scores from the maintainer machine
├── micro/                        # construction + write-path claims
├── propagation/                  # chain/fan-out/diamond scaling
├── operators/                    # distinct, debounce, asyncMap, switchMap
├── synapses/                     # strategy dispatch + 50k-pulse stress
├── transaction/                  # isolation levels + txApply saga
├── async/                        # receptor.async serialized vs fire-and-forget
├── memory/                       # per-cell heap footprint (VM service)
└── compare/                      # Cell vs RxDart vs raw Stream
```

## How to run

All commands run from `packages/cell` with `dart run` (NOT `dart test` — the
test runner enables debug asserts, which doubles the cost of every `mask()`
allocation and invalidates the numbers).

```bash
# A single benchmark
dart run benchmark/propagation/chain_depth.dart

# The full PR suite -> current.json
dart run benchmark/runner.dart --out current.json

# CI-style: median of 3 runs per file, one retry on a per-file timeout
dart run benchmark/runner.dart --out current.json --runs 3 --retries 1

# Regression gate (fails on regressions beyond the two-tier budget; see
# compare.dart for the tiers)
dart run benchmark/compare.dart \
  --baseline benchmark/baseline.json \
  --current current.json \
  --max-regression 0.15

# Memory benchmarks need the VM service
dart run --observe benchmark/memory/per_cell_footprint.dart
dart run --observe benchmark/memory/evolution_chain.dart
```

## What the numbers mean

- **micro/\*** — µs per 10k constructions (per iteration). The `[control]`
  benchmarks anchor the comparison: if `Cell()` isn't at least as fast as a
  plain class with four nullable fields, the flyweight claim is not holding.
- **propagation/\*** — µs per pulse through the given shape. Chain-depth
  numbers show whether propagation is O(depth) or O(depth²); the depth-50
  case is where the `CycleChecker` cost shows up.
- **operators/async_map.dart** — µs per batch of `n` pulses (divide by `n`
  for per-pulse cost). `concurrency: 1` must show strict serialization,
  `exhaust` must drop to roughly the throughput of a single item.
- **synapses/high_frequency.dart** — sustained pulses/sec through a
  three-cell graph with two observers.
- **memory/\*** — heap delta per retained unit, sampled via the VM service
  after a garbage-collection settle. The per-cell number is the single
  strongest differentiator for the flyweight story.

## Pass criteria (deliberately pessimistic)

| Doc claim | Benchmark | Pass criterion |
|---|---|---|
| "mask eliminates the Nullable Field Tax" | `micro/nucleus_construction.dart` | Nucleus with defaults is not slower than the plain-class control (still fails: ~235×) |
| "zero-latency propagation" | `propagation/chain_depth.dart` | Single-hop pass-through < 10 µs mean (currently ~5-6 µs after Phase 6) |
| "Flyweight … minimize heap footprint" | `memory/per_cell_footprint.dart` | < 1.5 KB per Cell (passes: ~1.1 KB after lazy-synapses fix); stretch: < 500 B |
| "zero-overhead when no policy" | `propagation/governed_vs_ungoverned.dart` | Governed < 2× ungoverned |
| "PriorityQueue … O(log n)" | `synapses/propagation_strategies.dart` | Batched dispatch scales sub-linearly with fan-out |
| "AsyncSynapses preserves causal order" | `async/receptor_async.dart` | Fire-and-forget ≥ 5× serialized throughput |
| "Locks held only during commit" | `transaction/value_transaction.dart` | Isolation levels don't change single-cell commit cost materially |
| Per-pulse primitive costs | `micro/pulse_primitives.dart` | Pulse construction < 1 µs; single hop < 10 µs; exception-miss control pins the shape-tag gain |

Phase 1 (exception-free shape-tagged pulse reads + cached nucleus/receptor
accessor resolution) took the single-hop emit from ~170 µs to ~14 µs.
Phase 2 (cached per-cell step string, lazily-materialized CycleChecker
sets, copy-on-write broadcast sets with deferred mid-broadcast link/unlink)
took it to ~9.7 µs, `Cell.distinct` duplicate-heavy input to ~7 µs per value,
and turned the depth-50 chain from ~8.3 s/pulse (exponential) into ~9.2 ms
(linear). Phase 3 (lightweight `_StepPulse` lineage node instead of a full
mask per hop, unrolled pipeline stage sequence, O(1) `last` on every pulse
shape) cut `withStep` from ~0.25 µs to ~0.06 µs and removed the remaining
per-stage allocations; the end-to-end number now hovers around ~10 µs with
no single dominant cost left. The remaining gap to a raw
`StreamController.add` (~0.04 µs) is diffuse: pulse-record allocation,
broadcast machinery, and observer hops.

The per-cell footprint story: the largest single item was eager
`Synapses()` materialization in the cell constructors (~800 B/cell) — now
lazy, taking `Cell()` from ~2.7 KB to ~1.1 KB. What remains is the
Cell → Nucleus → Receptor object graph (four object headers) plus the
cached accessor fields on `_Nucleus` and `_Receptor`. The original
<128 B criterion is not reachable without a fused single-object redesign,
so the gate is now <1.5 KB/cell with a <500 B stretch.

Phase 6 (observer hot path) made `_StepPulse` fully flat (plain
parent/step fields, zero records per hop), fast-pathed the common
`Cell.observe` observer inside the sync broadcast (direct reaction call
with inline terminal accounting), and made `SynapsesBase.isEmpty`/`isNotEmpty`
O(1). Single-hop emit is now ~5-6 µs (~30x over the original); the
vs-raw-stream harness ratio dropped from ~202x to ~121x.

### Feature-accounted comparison (the cost ladder)

The vs-RxDart/vs-raw-stream ratios are deliberate: they compare a governed
pulse delivery against a bare value handoff. The per-emit cost itemizes as
follows (warmed, maintainer machine):

| Layer | Per-emit cost | What it buys |
|---|---|---|
| `Pulse` construction | ~0.3 µs | per-pulse provenance: source, type, priority, causal `trace` |
| broadcast machinery | ~1.7 µs | cycle/diamond safety, deferred-link mutation guard, policy hook (idle when no policy) |
| observer pipeline | ~2.4 µs | allow-all gate validation, per-cell step lineage, terminal branch accounting (`onComplete` correctness) |
| **Cell total (ingress → observer)** | **~4.8 µs** | the full feature stack |
| raw `StreamController.add` | ~0.04 µs | a pointer into a FIFO + microtask — none of the above |

The published comparison story is therefore the ~110-121x ratio **with the
features itemized**: RxDart or raw streams would have to layer the same
provenance, cycle detection, validation gates, lineage, and lifecycle
accounting on top before the comparison becomes feature-for-feature. The
suite keeps both sides of that statement honest: the comparison benchmarks
track the bare ratio, and the micro benchmarks pin each ladder layer.

If a benchmark never fails on the current codebase, it's probably not
testing enough — tighten the workload before tuning the criterion.

## Baseline maintenance

`baseline.json` is the reference score set. Because the regression gate
runs on GitHub-hosted `ubuntu-latest` runners, the baseline must be
measured on that same machine class — a maintainer-machine baseline and a
CI run on different CPU/OS never line up for noisy microbenchmarks. CI and
the rebaseline workflow both run each benchmark file `--runs 3` and compare
the **median**, so a single noisy measurement cannot trip the gate; the
workflow also pins the Dart SDK (`3.14.0`, recorded in the rebaseline
artifact) to keep gate runs and baselines on the same toolchain.

To re-baseline (also required whenever the CI image or Dart SDK changes):

1. Bump the pinned SDK in `.github/workflows/benchmark.yml` and
   `.github/workflows/rebaseline-benchmarks.yml` together.
2. Run the **rebaseline-benchmarks** workflow from the Actions tab
   (`.github/workflows/rebaseline-benchmarks.yml`).
3. Download the `benchmark-baselines` artifact.
4. Copy the three `baseline.json` files back into
   `packages/{cell,cell_tissue,cell_flow}/benchmark/` (and the research
   suite baseline into `packages/cell_tissue/benchmark/tissue/`), then
   commit them. The artifact also records the Dart SDK version used.

For local experiments only (numbers will differ from CI):

```bash
dart run benchmark/runner.dart --out benchmark/baseline.json
```

The runner kills any benchmark file that exceeds its per-file timeout
(default 2 minutes, `--file-timeout <seconds>` to override), so a hanging
benchmark fails the suite in seconds instead of stalling the CI job.
CI passes `--retries 1` so a single timeout on a busy shared runner is
re-run once before the job fails; a benchmark that times out twice (or
exits non-zero) still fails the suite immediately.

## What not to do

- Don't run these under `dart test` — debug asserts distort every number.
- Don't publish a single number — publish per-shape numbers (chain 1/10/50,
  fan-out 10, duplicate-heavy vs all-unique).
- Don't benchmark cold — `benchmark_harness` warms up; any hand-rolled
  `Stopwatch` code must warm up first.
- Don't compare against Flutter/web builds yet — get the VM numbers solid
  first; dart2js object-shape optimization is a separate story.
