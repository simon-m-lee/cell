# `cell_tissue` research benchmark suite

This sub-suite implements the tissue benchmark proposal:
timing benchmarks that anchor the performance story, plus **semantic fitness
tests** that assert the docstring contracts the benchmarks depend on. The
fitness tests live in `test/tissue/fitness/` and run in normal CI — several of
them were written to fail on the historical P0 bugs (stale unmodifiable
copies, dropped batch metadata, dropped `TestTissue` user, unvetted unknown
`apply` functions, growable/fixed-length confusion, and `fromNucleus` casts).
They now pass because those bugs are fixed.

## Layout

```
benchmark/tissue/
├── harness.dart                  # fixtures + feature-fair plain controls
├── runner.dart                   # pr-suite + --full runner (writes JSON)
├── compare.dart                  # 15% regression gate
├── baseline.json                 # checked-in baseline
├── micro/
│   ├── mutation_cost.dart        # anchor: per-op add/remove/put/set cost
│   ├── mutation_fanout.dart      # 1/10/100/1000 observers
│   └── mutation_validation.dart  # allowAll vs sync rule vs async rule
├── deputy/
│   ├── sync_overhead.dart        # principal vs read-only deputy
│   ├── unmodifiable_view.dart    # live-check + deep-projection read
│   └── chain_depth.dart          # principal -> deputy -> deputy-of-deputy
├── container/
│   ├── list_variants.dart        # growable vs fixed-length
│   ├── set_variants.dart         # value vs identity set
│   └── map_variants.dart         # short vs long keys
├── operators/
│   ├── bulk_mutations.dart       # addAll / removeWhere / updateAll
│   └── complex_ops.dart          # sort / shuffle / replaceRange
├── batch/
│   └── collective_emit.dart      # batch metadata + composite contract
├── async/
│   └── tissue_modifiable_async.dart  # .async.add vs .add
├── memory/
│   └── per_tissue_footprint.dart # heap delta + shared-nucleus flyweight
└── compare/
    ├── vs_dart_list.dart
    ├── vs_dart_set.dart
    ├── vs_dart_map.dart
    └── vs_dart_unmodifiable_view.dart
```

## Running

```bash
# PR suite (fast): 5 files, ~13 metrics
dart run benchmark/tissue/runner.dart --out benchmark/tissue/current.json

# Full research suite: +13 more files
dart run benchmark/tissue/runner.dart --full --out benchmark/tissue/current.json

# Regression gate (15% budget)
dart run benchmark/tissue/compare.dart \
  --baseline benchmark/tissue/baseline.json \
  --current benchmark/tissue/current.json

# Memory (requires the VM service)
dart run --observe benchmark/tissue/memory/per_tissue_footprint.dart
```

## Reading the numbers

The anchor file, `micro/mutation_cost.dart`, reports **µs per mutation** for
each tissue shape. Published honestly, a `TissueList.add+remove` lands in the
hundreds-of-nanoseconds to low-microseconds range on a warmed VM, versus
20–40 ns for a native `List.add` — the ~20–100× gap is the price of the
reactivity + governance stack (`validate` → pulse → receptor → broadcast).
The `compare/` files include **feature-fair controls** (plain collection +
manual listener callback), which is the honest comparison for adopters who
are already shipping hand-rolled change notification.

The fitness tests under `test/tissue/fitness/` are the acceptance criteria:
if `unmodifiable_is_live_test.dart` or `batch_metadata_preserved_test.dart`
fails, the corresponding benchmark number is meaningless no matter how fast
it is.
