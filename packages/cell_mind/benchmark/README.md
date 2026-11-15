# cell_mind benchmarks

Micro-benchmarks measuring the cost of the cognitive layer. Each benchmark
is filled in by its owning phase and runs standalone:

```bash
dart run benchmark/micro/policy_cost.dart
```

## Methodology

1. Each benchmark measures **one** primitive in isolation.
2. Baselines are recorded on `ubuntu-latest` CI with a pinned Dart SDK and
   compared with `--max-regression 0.15`.
3. A benchmark that has not been filled in yet prints its owning phase and
   exits 0 — staleness is caught by the Phase 7 `dart run benchmark/...`
   gate, not by failure.

## Benchmarks

| File | Question | Filled in |
|---|---|---|
| `micro/policy_cost.dart` | Cost of N-deep policy composition vs. depth | Phase 1 |
| `micro/recording_cost.dart` | Decision-log overhead per pulse | Phase 2 |
| `micro/training_cost.dart` | Bandit throughput per 1000 decisions | Phase 3 |
| `compare/vs_manual_checks.dart` | Cognitive gate vs. if/else baseline | Phase 1 |
