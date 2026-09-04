# cell_flow

**Codename: Mitosis** · `1.0.0-rc.1`

Rx-shaped operators for the [Cell](https://github.com/simon-m-lee/cell) framework. Debounce, switchMap, zip, retry and the rest of the usual stream vocabulary — as `FlowInstruction`s on the **same graph** as `package:cell`.

[![Dart](https://img.shields.io/badge/Dart-3.5%2B-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT%20%2F%20Apache--2.0-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Alpha-orange.svg)](#status)

```yaml
dependencies:
  cell: 1.0.0-rc.1
  cell_flow: 1.0.0-rc.1
```

```dart
import 'package:cell_flow/flow.dart'; // re-exports package:cell
```

Status: **release candidate**. Not a completeness claim. Verify behaviour against source.

---

## Why Flow exists

**cell** already gives you nodes (`Cell`), signals (`Pulse`), integrity (`TestCell`), and gates (`Receptor`). Everyday stream work would otherwise be custom `Timer`s and one-off receptors.

**cell_flow** names those policies:

| You write | Flow runs |
|---|---|
| `Flow.debounce` | last value after silence |
| `Flow.switchMap` | drop the previous inner |
| `Flow.zip` | pair by index, not by latest |
| `Filter + MapValue + Tap` | one Receptor, one lock |

The graph, locks, and provenance stay in **cell**. Flow only decides *which* pulses leave and *when*.

---

## Three ways in

```dart
final box = Cell.ingress<String>();

// 1. Static factory
final a = Flow.filter<String>(box.cell, test: (q) => q.length >= 2);

// 2. Fluent (same factories)
final b = box.cell
    .filter<String>(test: (q) => q.length >= 2)
    .debounce<String>(duration: const Duration(milliseconds: 300))
    .asyncMapLatest<String, List<String>>(mapper: api.search);

// 3. Instruction chain → one purpose-built Receptor
final gate = MapValue<String, String>((s) => s.trim()) +
    Filter<String>((s) => s.isNotEmpty) +
    Distinct<String>();
final c = gate.toHandle(source: box.cell);
```

Drive ingress with `emitAsync`, observe the handle’s cell:

```dart
Cell.observe(source: c.cell, effect: (Pulse p) => print(p.payload));
await box.emitAsync('  Ada  ');
```

Fluent `filter().map()` is **two cells**. `Filter + MapValue` is **one** Receptor. Use `+` for sync policy; keep timers and HTTP on the next node.

---

## Operator map

| Family | Examples |
|---|---|
| Create | `of`, `fromIterable`, `range`, `fromFuture`, `fromStream` |
| Transform | `map`, `mapTo`, `pluck`, `scan`, `reduce`, `pairwise` |
| Async | `asyncMap` / `Latest` / `Concurrent`, `asyncExpand`, `asyncFold` |
| Filter | `filter`, `take` / `skip`, `distinct` |
| Flatten | `concatMap`, `mergeMap`, `switchMap`, `exhaustMap` |
| Combine | `merge`, `zip`, `combineLatest`, `withLatestFrom`, `race` |
| Time | `delay`, `debounce`, `throttle`, `sample`, `auditTime`, `timeout`, `interval` |
| Collect | `bufferCount`, `bufferTime`, `window`, `groupBy`, `partition` |
| Control | `startWith`, `share`, `retry`, `tap`, `iif` |

Full tables: [`FEATURES-Flow.md`](FEATURES-Flow.md).  
Design: [`ARCHITECTURE-Flow.md`](ARCHITECTURE-Flow.md).

Cells **do not complete**. Concatenate **inners** (list / `Future` / `Stream`), not “Cell A then Cell B”. `reduce` / `scan` are running folds, not a terminal value.

---

## Example: search box

```dart
final query = Cell.ingress<String>();

final results = query.cell
    .map<String, String>(project: (q) => q.trim().toLowerCase())
    .filter<String>(test: (q) => q.length >= 2)
    .distinct<String>()
    .debounce<String>(duration: const Duration(milliseconds: 300))
    .asyncMapLatest<String, List<Hit>>(mapper: (q) => api.search(q));
```

Runnable gates in this package: `example_sanitize_text.dart`, `example_search_query_gate.dart`, `example_checkout_quote.dart`, and the other `example_*.dart` files.

---

## Package layout

```text
package:cell_flow/flow.dart
  part  src/flow.dart               Flow.* facade
  part  src/flow_core.dart          FlowInstruction, toHandle, operator +
  part  src/fluent_operator.dart    Cell / FlowHandle extensions
  import src/instruction/*.dart     operator classes
```

Application code should import **only** `package:cell_flow/flow.dart`.

---

## Docs

| Doc | Contents |
|---|---|
| [ARCHITECTURE-Flow.md](ARCHITECTURE-Flow.md) | Why Flow is shaped this way |
| [FEATURES-Flow.md](FEATURES-Flow.md) | Feature catalog |
| [HowTo-Fluent_Operator.md](HowTo-Fluent_Operator.md) | Method chaining |
| [HowTo-FlowInstruction-Receptor.md](HowTo-FlowInstruction-Receptor.md) | Purpose-built Receptors |

---

## Versioning

| Package | Version |
|---|---|
| `cell` | `1.0.0-rc.1` |
| `cell_flow` | `1.0.0-rc.1` |

**Mitosis** is the release codename (like an Android Studio animal). It is not part of the SemVer string. Stable on pub.dev will be `1.0.0`.

Keep the two packages on the same numeric line.

---

## License

MIT or Apache-2.0 — see `LICENSE` and the file headers.

Copyright (c) 2025-Present Lee Man Hoi Simon. See `AUTHORS`.

Operator *names* follow ReactiveX vocabulary. Implementations are original Cell Flow; using `switchMap` as a name does not require an RxJS copyright header.

---

## Links

- Repo: [github.com/simon-m-lee/cell](https://github.com/simon-m-lee/cell)
- This package: [packages/cell_flow](https://github.com/simon-m-lee/cell/tree/master/packages/cell_flow)
- Issues: [github.com/simon-m-lee/cell/issues](https://github.com/simon-m-lee/cell/issues)
