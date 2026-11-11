# cell_flow benchmark suite

Mirrors the `cell` package's suite: every benchmark runs **outside** the
`cell_flow` library (public API only), under `dart run` (never `dart test`),
and ships `baseline.json` plus a 15% regression gate.

## Layout

| Path | What it measures |
|---|---|
| `micro/instruction_construction.dart` | `FlowInstruction` / `Receptor` construction vs a raw closure (flyweight claim) |
| `micro/pipeline_construction.dart` | `toHandle` materialization cost (Nucleus + Receptor + Cell per activation), 1/3/10-stage scaling |
| `micro/map_chain.dart` | Per-pulse cost of a 1/3/10-stage map chain |
| `micro/filter_chain.dart` | Filter chains + the 50%/100% rejection paths |
| `micro/scan_reduce.dart` | Scan vs reduce (seed slot) vs stateless map control |
| `micro/distinct.dart` | Global dedup by cardinality (10/100/1000 uniques) + consecutive dedup |
| `micro/take_skip.dart` | Pass vs drop gate paths |
| `micro/pairwise.dart` | O(1) pairwise state |
| `micro/pluck.dart` | Pluck family vs raw map lookup |
| `async/*` | asyncMap family, asyncExpand family, asyncFold family, FromFuture/DeferFuture, FromStream/DeferStream |
| `flatten/*` | concatMap / mergeMap (burst load) / switchMap (supersession) / exhaustMap (busy gate) |
| `time/*` | debounce / throttle / delay / timeout — `Duration.zero` anchors per-pulse cost |
| `combine/*` | mergeWith / combineLatestWith / zipWith / race / groupBy scaling |
| `collect/*` | bufferCount (tumbling vs sliding) / bufferTime / windowCount |
| `stress/high_frequency.dart` | 50k pulses through a 3-stage pipeline (nightly) |
| `memory/*` | Per-instruction and per-handle heap footprint via VM service (nightly) |
| `compare/*` | Flow vs RxDart (map/filter, asyncMap, switchMap) and vs raw `StreamController` (nightly) |

## Running

```bash
# PR suite (~30 files)
dart run benchmark/runner.dart --out current.json

# Nightly additions (rxdart comparisons + 50k stress)
dart run benchmark/runner.dart --nightly --out current.json

# Regression gate (15% budget)
dart run benchmark/compare.dart \
  --baseline benchmark/baseline.json \
  --current current.json

# Memory (requires the VM service)
dart run --observe benchmark/memory/instruction_footprint.dart
dart run --observe benchmark/memory/flow_handle_footprint.dart
```

## Pass criteria

| Doc claim | Benchmark | Criterion |
|---|---|---|
| "Flow adds no translation overhead" | `compare/vs_raw_stream_map.dart` | Flow map ≤ 150× raw `StreamController.map` (features itemized) |
| "Flyweight receptors / minimal memory" | `micro/pipeline_construction.dart` | `toHandle 1-stage` ≤ 10× `Cell` construction; 10-stage ≤ 12× 1-stage |
| "Stateless blueprints" | `micro/instruction_construction.dart` | `FlowInstruction` construction ≤ 2× raw closure |
| "Zero-latency propagation" | `micro/map_chain.dart` | single map per pulse ≤ 2 µs |
| Per-pulse operator cost | all `micro/*` | each operator ≤ 10× `MapIdentityControl` |
| Sequential ordering is cheap | `async/async_map.dart` | `asyncMap c=1` within 2× of `c=0` |
| SwitchMap cancellation is real | `flatten/switch_map.dart` | `switchMap superseded` ≤ `switchMap` |
| ExhaustMap drops while busy | `flatten/exhaust_map.dart` | `exhaustMap busy` ≤ `exhaustMap` |
| MergeMap queue integrity | `flatten/merge_map.dart` | `mergeMap c=1` ≤ 2× `asyncMap` per pulse |
| Memory per instruction | `memory/instruction_footprint.dart` | < 500 B stateless; < 2 KB stateful |
| Memory per handle | `memory/flow_handle_footprint.dart` | < 2 KB/handle; < 6 KB/3-stage pipeline |

## Itemized cost ladder (honest framing)

A Flow pulse carries provenance, step lineage, the cycle checker, and
lifecycle hooks on every hop; an RxDart or raw-stream value carries none.
The `compare/*` ratios are therefore expected to be large — that is the
price of governance, not a parity target. Each hop pays roughly:

- one `Pulse` allocation with trace metadata
- one `Receptor` invocation (validation + instruction + postProcess)
- one synapse broadcast with lifecycle accounting

## Known issues the suite is designed to expose

- **`distinct` scaling** (`micro/distinct.dart`): the current implementation
  was O(n²) in the seen-set; the 1.0.0 release switched the default path to
  a `Set`, so `unique=1000` should now scale roughly linearly. The three
  cardinality pins record the before/after shape.
- **Public-surface adaptations**: operators that exist only as internal
  classes (`scanSeeded`, `debounceLeading*`, `exhaustMapLatest`, …) are
  benchmarked through their public `Flow.*` factory equivalents; the entry
  names reflect the public factory used.

Regenerate `baseline.json` with the **rebaseline-benchmarks** workflow
(`.github/workflows/rebaseline-benchmarks.yml`) so the reference scores
are measured on the same `ubuntu-latest` machine class that runs the
regression gate, then commit the downloaded artifact. Re-run whenever the
CI image or the Dart SDK changes. For local experiments only,
`dart run benchmark/runner.dart --out benchmark/baseline.json` produces a
local baseline (numbers will differ from CI).

The runner kills any benchmark file that exceeds its per-file timeout
(default 2 minutes, `--file-timeout <seconds>` to override), so a hanging
benchmark fails the suite fast instead of stalling the CI job.
