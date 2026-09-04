# Cell Flow — Demo Guide

Central index for the **examples/** directory. Each entry is a runnable Dart program that demonstrates one or more Cell factories, fluent operators, or architectural patterns.

**Convention:** `examples/<file_name>.dart`

Run any demo with:

```bash
dart run examples/<file_name>.dart
```

---

## How to use this guide

| Need | Start here |
|------|------------|
| Create inputs / hold state / side effects | [1. Core Primitives](#1-core-primitives) |
| Drop noise, preamble, or invalid values | [2. Filtering & Noise Reduction](#2-filtering--noise-reduction) |
| Finite sequences (splash, first login, N steps) | [3. Finite Lifecycle & Termination](#3-finite-lifecycle--termination) |
| Debounce, throttle, delay, sample | [4. Timing & Rate Control](#4-timing--rate-control) |
| Running totals, combine, zip, merge | [5. Aggregation & Accumulation](#5-aggregation--accumulation) |
| Batch by count or time | [6. Windowing & Batching](#6-windowing--batching) |
| Background I/O, streams, futures | [7. Async & Concurrency](#7-async--concurrency) |
| Race providers, switch sources | [8. Higher-Order Switching & Racing](#8-higher-order-switching--racing) |
| One upstream, many views | [9. Sharing & Multicasting](#9-sharing--multicasting) |
| Recover from failures, redact PII | [10. Error Resilience & Privacy](#10-error-resilience--privacy) |
| Append-only ledger, reconstruct state | [11. Event Sourcing & Forensics](#11-event-sourcing--forensics) |
| Route by type, atomic multi-cell updates | [12. Routing & Transactions](#12-routing--transactions) |
| Long fluent chains & combinator overview | [13. Fluent Pipelines](#13-fluent-pipelines) |
| UI seed / hydrate / observe patterns | [14. UI Hydration & Side Effects](#14-ui-hydration--side-effects) |

---

## 1. Core Primitives

Ingress ports, persistent state, observation terminals, and open cells for manual topology.

| File | Focus |
|------|--------|
| [`ingress_demo.dart`](examples/ingress_demo.dart) | `Cell.ingress` — emit, emitAsync, ingest, refine |
| [`state_demo.dart`](examples/state_demo.dart) | `Cell.value` — counter, list accumulator, async status |
| [`observe_demo.dart`](examples/observe_demo.dart) | `Cell.observe` — UI setState, start/stop, forensic audit |
| [`open_cell_demo.dart`](examples/open_cell_demo.dart) | `Cell.open` — manual inject, link/unlink, hybrid bind + emit |
| [`derive_demo.dart`](examples/derive_demo.dart) | `Cell.derive` — projections, chained maps, causal parent/root |

---

## 2. Filtering & Noise Reduction

Suppress duplicates, gate content, and drop preamble.

| File | Focus |
|------|--------|
| [`distinct_demo.dart`](examples/distinct_demo.dart) | `Cell.distinct` — consecutive dedupe, custom equals |
| [`valve_demo.dart`](examples/valve_demo.dart) | `Cell.state` — content gate + throttle/debounce policies |
| [`stream_offset_demo.dart`](examples/stream_offset_demo.dart) | `Cell.skip` / `skipWhile` / `skipUntil` — preamble management |
| [`state_offset_demo.dart`](examples/state_offset_demo.dart) | `Cell.skipWhile` — adaptive headers, calibration, auth gate |

---

## 3. Finite Lifecycle & Termination

One-shot and bounded sequences: splash, first success, safety cut-off.

| File | Focus |
|------|--------|
| [`stream_limiting_demo.dart`](examples/stream_limiting_demo.dart) | `Cell.take` / `takeWhile` / `takeUntil` — finite pipelines |
| [`finite_lifecycle_logic(take_n_delay)_demo.dart`](examples/finite_lifecycle_logic(take_n_delay)_demo.dart) | Fluent **take + delay** — splash, first login, wizard, promo |
| [`conditional_gate_demo.dart`](examples/conditional_gate_demo.dart) | `Cell.takeWhile` — temperature/pressure interlocks, estop |
| [`event_gate_demo.dart`](examples/event_gate_demo.dart) | `Cell.takeUntil` — logout, cancel search, abort upload |

---

## 4. Timing & Rate Control

Stabilize input, regulate egress, shift time, and sample on demand or on a clock.

| File | Focus |
|------|--------|
| [`stability_search_demo.dart`](examples/stability_search_demo.dart) | `Cell.debounce` — search, validation, resize, autosave |
| [`stabilized_search(debounce_n_filter)_demo.dart`](examples/stabilized_search(debounce_n_filter)_demo.dart) | Fluent **debounce → distinct → asyncMap(latestOnly)** |
| [`rate_limiting_gate_demo.dart`](examples/rate_limiting_gate_demo.dart) | `Cell.throttle` — scroll, button spam, leading/trailing |
| [`high_frequency_ui_regulation(throttle)_demo.dart`](examples/high_frequency_ui_regulation(throttle)_demo.dart) | Fluent throttle @ ~60fps — scroll, resize, pointer |
| [`trailing_gate_finalization.dart`](examples/trailing_gate_finalization.dart) | `Cell.throttleTrailing` — layout pass, persist final value |
| [`temporal_shift_demo.dart`](examples/temporal_shift_demo.dart) | `Cell.delay` / `delayWhen` — toast, splash, stagger |
| [`adaptive_timing_demo.dart`](examples/adaptive_timing_demo.dart) | `Cell.delayWhen` — priority lanes, backoff, size-based delay |
| [`forensic_sampling_demo.dart`](examples/forensic_sampling_demo.dart) | `Cell.sample` — capture button, checkpoint, frame tick |
| [`periodic_observability_demo.dart`](examples/periodic_observability_demo.dart) | `Cell.sampleTime` — GPS trail, periodic audit, heartbeat |
| [`snapshot_demo.dart`](examples/snapshot_demo.dart) | `Cell.withLatestFrom` — form submit, save, refresh gauges |
| [`multi_snapshot_demo.dart`](examples/multi_snapshot_demo.dart) | `Cell.withLatestFromList` — composite snapshots |

---

## 5. Aggregation & Accumulation

Running state, multi-source synthesis, and synchronized pairing.

| File | Focus |
|------|--------|
| [`scan_demo.dart`](examples/scan_demo.dart) | `Cell.scan` — totals, average, cart, min/max, state machine |
| [`running_totals(scan)_demo.dart`](examples/running_totals(scan)_demo.dart) | Fluent scan — steps, cart, wallet, peak score |
| [`combine_demo.dart`](examples/combine_demo.dart) | `Cell.combineLatest` — price+tax+shipping, form validity |
| [`merge_demo.dart`](examples/merge_demo.dart) | `Flow.merge` — multi-source fan-in, forensic origin tags |
| [`zip_demo.dart`](examples/zip_demo.dart) | `Cell.zip` — left/right lock-step, request/response |
| [`transition_detection(pairwise)_demo.dart`](examples/transition_detection(pairwise)_demo.dart) | Fluent **pairwise** — temp trend, scroll delta, edges |
| [`pairwise_demo.dart`](examples/pairwise_demo.dart) | `Cell.pairwise` — status edges, rising stock, auth machine |

---

## 6. Windowing & Batching

Chunk streams by boundary signal, count, or wall-clock time.

| File | Focus |
|------|--------|
| [`temporal_batching_demo.dart`](examples/temporal_batching_demo.dart) | `Cell.window` / `windowCount` / `windowTime` overview |
| [`volume_batching_demo.dart`](examples/volume_batching_demo.dart) | `Cell.windowCount` — job quotas, forensic pages, sliding |
| [`temporal_heartbeat_demo.dart`](examples/temporal_heartbeat_demo.dart) | `Cell.windowTime` — metrics flush, empty windows, alerts |
| [`batch_processing(windowTime)_demo.dart`](examples/batch_processing(windowTime)_demo.dart) | Fluent **windowTime** — analytics, logs, sync chunks |

---

## 7. Async & Concurrency

Background work, sequential expand/fold, and bridges from Dart streams/futures.

| File | Focus |
|------|--------|
| [`async_map_demo.dart`](examples/async_map_demo.dart) | `Cell.asyncMap` — parallel, latestOnly, concurrency pool |
| [`async_expand_demo.dart`](examples/async_expand_demo.dart) | `Cell.asyncExpand` — order lifecycle, subtasks, pages |
| [`async_fold_demo.dart`](examples/async_fold_demo.dart) | `Cell.asyncFold` — sequential balance, cart, ordered resolve |
| [`stream_bridge_demo.dart`](examples/stream_bridge_demo.dart) | `Cell.fromStream` — periodic, controller, live feed |
| [`async_bridge_demo.dart`](examples/async_bridge_demo.dart) | `Cell.fromFuture` — one-shot load, recover, merge futures |

---

## 8. Higher-Order Switching & Racing

Dynamic provider selection and first-wins / sticky / re-election races.

| File | Focus |
|------|--------|
| [`dynamic_source_switching.dart`](examples/dynamic_source_switching.dart) | `Cell.switchLatest` — local ↔ remote provider swap |
| [`race_demo.dart`](examples/race_demo.dart) | `Cell.race` — sticky, onSignal, onTimeout, onLoser |
| [`redundant_api_race.dart`](examples/redundant_api_race.dart) | Race primary vs fallback — offline-first, latency |
| [`advanced_race_patterns.dart`](examples/advanced_race_patterns.dart) | Race + error re-election + timeout + UI model |
| [`one_shot_discovery.dart`](examples/one_shot_discovery.dart) | `Cell.raceFirst` — boot, flags, region health |

---

## 9. Sharing & Multicasting

Single upstream subscription shared by many observers; late hydration.

| File | Focus |
|------|--------|
| [`resource_sharing_demo.dart`](examples/resource_sharing_demo.dart) | `Cell.share` — one network bridge, many views |
| [`warm_start_ui_demo.dart`](examples/warm_start_ui_demo.dart) | `Cell.shareReplay` — late widgets, buffer, last theme |

---

## 10. Error Resilience & Privacy

Recover, map errors to domain shapes, and redact sensitive payloads.

| File | Focus |
|------|--------|
| [`error_recovery_demo.dart`](examples/error_recovery_demo.dart) | `Cell.onError` — fallback, typed recover, swallow |
| [`dynamic_recovery_demo.dart`](examples/dynamic_recovery_demo.dart) | `Cell.onErrorMap` — uniform envelope, metrics, UI toast |
| [`sanitized_demo.dart`](examples/sanitized_demo.dart) | `Cell.sanitized` — PII redaction by sensitivity tier |

---

## 11. Event Sourcing & Forensics

Append-only ledgers, drafts, subject streams, and state reconstruction.

| File | Focus |
|------|--------|
| [`event_ledger_demo.dart`](examples/event_ledger_demo.dart) | `Cell.eventStore` — append, read, live, allLive |
| [`event_sourcing_demo.dart`](examples/event_sourcing_demo.dart) | `Cell.eventDraft` — prepare, commit, causation chain |
| [`event_stream_demo.dart`](examples/event_stream_demo.dart) | `Cell.event` — subject narratives (user / ticket) |
| [`event_fold_demo.dart`](examples/event_fold_demo.dart) | `Cell.eventFold` — wallet ledger → balance reconstruction |

---

## 12. Routing & Transactions

Pattern/prefix buses and atomic multi-cell updates.

| File | Focus |
|------|--------|
| [`routing_bus_demo.dart`](examples/routing_bus_demo.dart) | `Cell.routing` — multicast, exclusive, prefix, fallback |
| [`transaction_demo.dart`](examples/transaction_demo.dart) | `Cell.transaction` — transfer, savepoint, validate, isolation |

---

## 13. Fluent Pipelines

End-to-end chains and the operators/combinators surface.

| File | Focus |
|------|--------|
| [`long_fluent_chain_demo.dart`](examples/long_fluent_chain_demo.dart) | Production-style chain: skip → debounce → distinct → throttle → asyncMap → delay → windowTime → take (+ bridges) |
| [`pipelines_combinators_demo.dart`](examples/pipelines_combinators_demo.dart) | Fluent unary + iterable race/merge/zip/withLatestFromList |

---

## 14. UI Hydration & Side Effects

Seed placeholders before live data; replay local cache before sync.

| File | Focus |
|------|--------|
| [`initialization_patterns.dart`](examples/initialization_patterns.dart) | `Cell.startWith` — idle/loading, empty list, profile placeholder |
| [`hydration_replay_demo.dart`](examples/hydration_replay_demo.dart) | `Cell.startWithMany` — session cache, cart, outbox replay |
| [`observe_demo.dart`](examples/observe_demo.dart) | Terminal lifecycle for widgets and audit loggers |

---

## Quick map: operator → primary demo

| Operator / factory | Primary example |
|--------------------|-----------------|
| `ingress` | `ingress_demo.dart` |
| `value` | `state_demo.dart` |
| `observe` | `observe_demo.dart` |
| `open` | `open_cell_demo.dart` |
| `derive` | `derive_demo.dart` |
| `distinct` | `distinct_demo.dart` |
| `valve` | `valve_demo.dart` |
| `skip` / `skipWhile` / `skipUntil` | `stream_offset_demo.dart` |
| `take` / `takeWhile` / `takeUntil` | `stream_limiting_demo.dart` |
| `debounce` | `stability_search_demo.dart` |
| `throttle` / `throttleTrailing` | `rate_limiting_gate_demo.dart` / `trailing_gate_finalization.dart` |
| `delay` / `delayWhen` | `temporal_shift_demo.dart` / `adaptive_timing_demo.dart` |
| `sample` / `sampleTime` | `forensic_sampling_demo.dart` / `periodic_observability_demo.dart` |
| `withLatestFrom` / `withLatestFromList` | `snapshot_demo.dart` / `multi_snapshot_demo.dart` |
| `scan` | `scan_demo.dart` |
| `combineLatest` | `combine_demo.dart` |
| `merge` | `merge_demo.dart` |
| `zip` | `zip_demo.dart` |
| `pairwise` | `pairwise_demo.dart` |
| `window` / `windowCount` / `windowTime` | `temporal_batching_demo.dart` |
| `asyncMap` | `async_map_demo.dart` |
| `asyncExpand` | `async_expand_demo.dart` |
| `asyncFold` | `async_fold_demo.dart` |
| `fromStream` / `fromFuture` | `stream_bridge_demo.dart` / `async_bridge_demo.dart` |
| `switchLatest` | `dynamic_source_switching.dart` |
| `race` / `raceFirst` | `race_demo.dart` / `one_shot_discovery.dart` |
| `share` / `shareReplay` | `resource_sharing_demo.dart` / `warm_start_ui_demo.dart` |
| `onError` / `onErrorMap` | `error_recovery_demo.dart` / `dynamic_recovery_demo.dart` |
| `sanitized` | `sanitized_demo.dart` |
| `eventStore` / `eventDraft` / `event` / `eventFold` | `event_ledger_demo.dart` … `event_fold_demo.dart` |
| `routing` | `routing_bus_demo.dart` |
| `transaction` | `transaction_demo.dart` |
| `startWith` / `startWithMany` | `initialization_patterns.dart` / `hydration_replay_demo.dart` |

---

## Notes for implementers

1. **Source gating** — Many combinators require `Pulse.governed(..., source: cell)`. Pulses without a matching `source` are dropped. Long fluent chains may need intermediate **re-source bridges** until every unary operator re-tags `source: outputCell` (see `long_fluent_chain_demo.dart`).

2. **Fluent API** — Demos under the “Fluent” naming style import `package:cell/fluent_operator.dart` (or `cell_extensions.dart`). Prefer fluent form for product pipelines; static `Cell.*` form remains valid.

3. **Expected output** — Most files document approximate console output in a top-of-file comment. Timings are approximate; batch/window counts depend on host scheduling.

4. **File naming** — Parentheses in some names (e.g. `batch_processing(windowTime)_demo.dart`) encode the primary operator for quick scanning in the filesystem.

---

*Index covers 60 runnable demos across core primitives, Rx-style operators, event sourcing, routing, and UI hydration patterns.*
```
