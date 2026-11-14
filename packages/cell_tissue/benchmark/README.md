# cell_tissue benchmark suite

Mirrors the `cell` package's suite: every benchmark runs outside the
`cell_tissue` library, exercising only the public API surface.

## Layout

| Path | What it measures |
|---|---|
| `benchmark/micro/tissue_construction.dart` | Per-shape construction: `TissueList`, `TissueMap`, `TissueSet`, `TissueQueue`, `TissueValue` vs plain `List`/`Map`/`Set`/`Queue`/field controls |
| `benchmark/micro/tissue_mutation.dart` | Pure mutation cost (`add`/`put`/`addLast`/`value =`) with no observers vs bare collection mutations |
| `benchmark/propagation/observer_delivery.dart` | End-to-end delivery: mutation → validation → commit → broadcast → observer, vs plain collection + listener callback |
| `benchmark/memory/per_tissue_footprint.dart` | VM-service heap delta per tissue instance (run with `dart run --observe`) |
| `benchmark/compare/vs_plain_collections.dart` | Feature-fair comparison: reactive tissue + observer vs plain collection + hand-rolled listener |
| `benchmark/runner.dart` | PR suite: runs the three cheap files and writes JSON results |
| `benchmark/compare.dart` | Regression gate: three-tier budget — 15% for benchmarks >= 10 ms baseline, 50% for 200 us - 10 ms, 200% below 200 us (see `compare.dart`) |

## Run

```bash
# From packages/cell_tissue
dart run benchmark/runner.dart --out current.json   # full PR suite

# CI-style: median of 3 runs per file, one retry on a per-file timeout
dart run benchmark/runner.dart --out current.json --runs 3 --retries 1

dart run benchmark/compare.dart \
  --baseline benchmark/baseline.json --current current.json
dart run benchmark/compare/vs_plain_collections.dart
dart run --observe benchmark/memory/per_tissue_footprint.dart
```

## Baseline maintenance

Regenerate `baseline.json` with the **rebaseline-benchmarks** workflow
(`.github/workflows/rebaseline-benchmarks.yml`) so the reference scores
are measured on the same `ubuntu-latest` machine class that runs the
regression gate, then commit the downloaded artifact (this also covers
the research sub-suite baseline under `benchmark/tissue/`). CI and the
rebaseline workflow both run each file `--runs 3` and compare the
**median**, and both pin the Dart SDK to the version the baselines were
recorded with. Re-run whenever the CI image or the Dart SDK changes.
Local numbers will differ from CI; the runner kills any benchmark file
that exceeds its per-file timeout (default 2 minutes) so a hang fails
fast, and CI passes `--retries 1` so a single timeout on a busy shared
runner is re-run once before the job fails.

## Pass criteria

| Claim | Benchmark | Criterion |
|---|---|---|
| Tissue construction is "cheap enough" for app code | `micro/tissue_construction.dart` | Each shape constructs in the low microsecond range; the suite gates regressions, the plain-collection ratio is reported honestly |
| Mutations stay bounded | `micro/tissue_mutation.dart` | Per-op mutation remains in the microsecond range and scales linearly with graph size |
| Observer delivery preserves the cell pipeline's characteristics | `propagation/observer_delivery.dart` | Delivery within ~2× of the equivalent `cell` single-hop cost |
| Flyweight footprint | `memory/per_tissue_footprint.dart` | Per-tissue heap footprint reported per shape; gate keeps it bounded across releases |

## Research sub-suite

The expanded `benchmark/tissue/` sub-suite implements
the tissue benchmark proposal: per-op mutation anchors, fan-out scaling,
deputy/unmodifiable live-view checks, batch metadata fitness, container
variants, bulk/complex operators, async mutation, memory footprint, and
feature-fair plain-collection comparisons — see
[`benchmark/tissue/README.md`](tissue/README.md) for the layout and how to run
the PR suite and the three-tier regression gate.

The sub-suite's semantic fitness tests live in `test/tissue/fitness/` and run
in normal CI; they assert the docstring contracts (live unmodifiable views,
deep projection, batch metadata, `TestTissue` user propagation, growable
defaults, unknown-dispatch rejection, `fromNucleus` casts) that the timing
numbers depend on.

The honest framing: a tissue is a `Cell` + `Nucleus` + container, so
construction and per-mutation costs are dominated by the `cell` layer's
pipeline. The suite's job is to catch regressions in that layering — the
plain-collection ratios are published for context, not as parity targets.

If a benchmark never fails on the current codebase, it's probably not
testing enough — tighten the workload before tuning the criterion.
