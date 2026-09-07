# cell_flow

**Codename: Mitosis** · `1.0.0-rc.2`

[![Dart](https://img.shields.io/badge/Dart-3.5%2B-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT%20%2F%20Apache--2.0-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-RC2-green.svg)](#status)

**Rx-shaped operators for the [Cell](https://github.com/simon-m-lee/cell) framework.** Debounce, switchMap, zip, retry, buffer, and the complete reactive stream vocabulary — implemented as `FlowInstruction`s on the **same graph** as `package:cell`.

---

## 🚀 Quick Start

### Installation

Add both packages to your `pubspec.yaml`:

```yaml
dependencies:
  cell: 1.0.0-rc.2
  cell_flow: 1.0.0-rc.2
```

Import once in your Dart file:

```dart
import 'package:cell_flow/flow.dart'; // re-exports package:cell
```

### Your First Pipeline (30 seconds)

```dart
import 'package:cell_flow/flow.dart';

final query = Cell.ingress<String>();

// Build a reactive search pipeline
final results = query.cell
    .map<String, String>(project: (q) => q.trim().toLowerCase())
    .filter<String>(test: (q) => q.length >= 2)
    .debounce<String>(duration: const Duration(milliseconds: 300))
    .asyncMapLatest<String, List<Hit>>(mapper: (q) => api.search(q));

// Observe results
Cell.observe(source: results.cell, effect: (p) {
  print('Found ${p.payload.length} hits');
});

// Emit user input
await query.emitAsync('Dart packages');
```

> 💡 **New to cell_flow?** Read the **[How to Start Guide](guide/HowTo-Start.md)** for a complete 15-minute tutorial with 5 copy-paste examples.

---

## 🎯 What Problem Does Flow Solve?

**cell** already gives you nodes (`Cell`), signals (`Pulse`), integrity (`TestCell`), and gates (`Receptor`). But everyday stream work — debouncing input, cancelling stale requests, batching events — would otherwise require custom `Timer`s and one-off receptors.

**cell_flow** names those policies:

| You want to… | cell_flow provides | Performance |
|---|---|---|
| Debounce user input | `Flow.debounce` or `.debounce()` | Last value after silence |
| Cancel stale HTTP requests | `Flow.switchMap` or `.switchMap()` | Drop previous inner |
| Pair values by index | `Flow.zip` or `.zipWith()` | Index-based pairing |
| Retry failed operations | `Flow.retry` or `.retry()` | Configurable retry count |
| Batch events | `Flow.bufferCount` or `.bufferCount()` | Collect N values |
| Prevent double-taps | `Flow.exhaustMap` or `.exhaustMap()` | Ignore while busy |
| Combine multiple streams | `Flow.combineLatest` | Latest from all sources |

**Key insight:** The graph, locks, validation, and provenance stay in **cell**. Flow only decides *which* pulses leave and *when*.

---

## 🔧 Three Ways to Build Pipelines

### Way 1: Static Factories (Recommended for beginners)

```dart
final box = Cell.ingress<String>();

final filtered = Flow.filter<String>(
  box.cell, 
  test: (q) => q.length >= 2,
);

final debounced = Flow.debounce<String>(
  filtered.cell,
  duration: const Duration(milliseconds: 300),
);
```

**Best for:** Multi-source operators (`merge`, `zip`, `combineLatest`), naming nodes for logs.

---

### Way 2: Fluent Chaining (Most readable)

```dart
final box = Cell.ingress<String>();

final results = box.cell
    .filter<String>(test: (q) => q.length >= 2)
    .debounce<String>(duration: const Duration(milliseconds: 300))
    .asyncMapLatest<String, List<String>>(mapper: api.search);
```

**Best for:** Linear pipelines, readability, quick prototyping.

> ⚠️ **Note:** Each fluent step creates a **new Cell/Receptor**. `filter().map()` = 2 cells.

---

### Way 3: InstructionChain (One Receptor, many ops)

```dart
final box = Cell.ingress<String>();

// Build a reusable policy - runs in ONE Receptor under ONE lock
final gate = MapValue<String, String>((s) => s.trim()) +
    Filter<String>((s) => s.isNotEmpty) +
    Distinct<String>();

final handle = gate.toHandle(source: box.cell);
```

**Best for:** Sync policies (trim, filter, tap), shared locks, unit testing gates.

> 💡 **Key difference:** `+` chains run in **one Receptor** under **one lock**. Fluent chains create multiple cells.

---

## 📊 Complete Operator Catalog (79+ Operators)

### Create Operators

| Operator | Description | Example |
|---|---|---|
| `of` | Play values on first pulse | `Flow.of(values: [1, 2, 3])` |
| `fromIterable` | Same, from iterable | `cell.fromIterable(iterable: list)` |
| `fromFuture` | One Future, first pulse | `cell.fromFuture(future: api.me())` |
| `fromStream` | One subscription, first pulse | `cell.fromStream(stream: ticker)` |
| `range` | start + count + step | `cell.range(start: 1, count: 5)` |

### Transform Operators

| Operator | Description | Example |
|---|---|---|
| `map` | Project value | `cell.map(project: (x) => x * 2)` |
| `mapTo` | Map to constant | `cell.mapTo(value: 'done')` |
| `pluck` | Extract field | `cell.pluck(field: 'name')` |
| `scan` | Running fold | `cell.scan(seed: 0, accumulate: (a, b) => a + b)` |
| `pairwise` | Emit pairs | `cell.pairwise()` |

### Filter / Take / Skip

| Operator | Description | Example |
|---|---|---|
| `filter` | Predicate gate | `cell.filter(test: (x) => x > 0)` |
| `distinct` | Consecutive unique | `cell.distinct()` |
| `take` | First N values | `cell.take(count: 3)` |
| `skip` | Skip first N | `cell.skip(count: 2)` |

### Flatten Operators (Inner Sequences)

| Operator | Policy | Use When |
|---|---|---|
| `concatMap` | Queue inners | Order matters |
| `mergeMap` | Overlap inners | Parallel OK |
| `switchMap` | Latest only | Cancel stale |
| `exhaustMap` | Ignore while busy | Prevent double-taps |

### Combine Operators

| Operator | Pairing Rule | Example |
|---|---|---|
| `mergeWith` | Interleave | `cell.mergeWith(sources: [a, b])` |
| `zipWith` | Same index | `cell.zipWith(others: [a, b])` |
| `combineLatestWith` | Latest of all | `cell.combineLatestWith(others: [a])` |
| `withLatestFrom` | Source + latest others | `cell.withLatestFrom(others: [a], combine: ...)` |
| `race` | First to emit | `Flow.race(cell, competitors: [a, b])` |

### Time Operators

| Operator | When It Emits | Example |
|---|---|---|
| `delay` | After fixed duration | `cell.delay(duration: 1s)` |
| `debounce` | Last after silence | `cell.debounce(duration: 300ms)` |
| `throttle` | Leading/trailing window | `cell.throttle(duration: 1s, leading: true)` |
| `sample` | Notifier or period | `cell.sampleTime(period: 1s)` |
| `timeout` | Idle too long | `cell.timeout(duration: 5s)` |

### Collect / Control Operators

| Operator | Payload | Example |
|---|---|---|
| `bufferCount` | List | `cell.bufferCount(count: 10)` |
| `bufferTime` | List | `cell.bufferTime(duration: 5s)` |
| `groupBy` | Grouped | `cell.groupBy(keyOf: (x) => x.type)` |
| `startWith` | Prefix | `cell.startWith(value: 0)` |
| `retry` | Retry count | `cell.retry(count: 3)` |
| `tap` | Side effect | `cell.tap(onValue: print)` |

📖 **Full documentation:** [`FEATURES-Flow.md`](FEATURES-Flow.md)

---

## 🎓 Common Patterns

### Pattern 1: Search-as-You-Type

```dart
final query = Cell.ingress<String>();

final results = query.cell
    .map<String, String>(project: (q) => q.trim().toLowerCase())
    .filter<String>(test: (q) => q.length >= 2)
    .distinct<String>()
    .debounce<String>(duration: const Duration(milliseconds: 300))
    .asyncMapLatest<String, List<Hit>>(mapper: api.search);
```

**Why it works:** `asyncMapLatest` cancels stale requests when the user types again.

---

### Pattern 2: Form Validation

```dart
final raw = Cell.ingress<String>();

final email = raw.cell
    .map<String, String>(project: (s) => s.trim().toLowerCase())
    .filter<String>(test: (s) => s.contains('@'))
    .distinct<String>()
    .asyncMap<String, User>(
      mapper: api.lookup,
      onError: (e, _) => log.warn(e),
    );
```

---

### Pattern 3: Prevent Double-Checkout

```dart
final taps = Cell.ingress<void>();

final receipts = taps.cell.exhaustMap<void, Receipt>(
  project: (_) => api.checkout(cart),
);

// While checkout runs, additional taps are ignored
await taps.emitAsync(null);  // Starts checkout
await taps.emitAsync(null);  // Ignored
```

---

### Pattern 4: Batch Telemetry

```dart
final events = Cell.ingress<Metric>();

final batches = events.cell
    .bufferWithTimeAndCount<Metric>(
      duration: const Duration(seconds: 5),
      count: 50,
    )
    .asyncMap<List<Metric>, void>(mapper: (batch) => api.flush(batch));

// Flushes when either 50 events arrive OR 5 seconds pass
```

---

### Pattern 5: Combine Multiple Sources

```dart
final price = Cell.ingress<int>();
final currency = Cell.ingress<String>();

final display = price.cell.withLatestFrom<int, String>(
  others: [currency.cell],
  combine: (p, latest) => '${latest.single} $p',
);

await price.emitAsync(20);       // Waits for currency
await currency.emitAsync('EUR'); // Now both have values
await price.emitAsync(25);       // → 'EUR 25'
```

> ⚠️ **Gotcha:** `withLatestFrom` waits until **every** other Cell has at least one value.

---

## 🧪 Testing Your Pipelines

### Test a Sync Chain (No Timer)

```dart
import 'package:cell_flow/flow.dart';
import 'package:test/test.dart';

void main() {
  test('sanitize drops blanks', () {
    final gate = MapValue<String, String>((s) => s.trim()) +
        Filter<String>((s) => s.isNotEmpty);
    
    final receptor = Receptor.instruction(gate);
    
    expect(receptor.call(Pulse('  x  '))?.payload, equals('x'));
    expect(receptor.call(Pulse('   ')), isNull);
  });
}
```

### Test an Async Pipeline (With Timer)

```dart
void main() {
  test('debounce emits last after silence', () async {
    final ingress = Cell.ingress<String>();
    
    final debounced = ingress.cell
        .debounce<String>(duration: const Duration(milliseconds: 100));
    
    final results = <String>[];
    Cell.observe(source: debounced.cell, effect: (p) {
      results.add(p.payload);
    });
    
    await ingress.emitAsync('a');
    await ingress.emitAsync('b');
    await ingress.emitAsync('c');
    
    // Wait past debounce duration
    await Future.delayed(const Duration(milliseconds: 150));
    
    expect(results, equals(['c']));
  });
}
```

---

## 📦 Package Layout

```text
package:cell_flow/flow.dart
  part  src/flow.dart               Flow.* facade
  part  src/flow_core.dart          FlowInstruction, toHandle, operator +
  part  src/fluent_operator.dart    Cell / FlowHandle extensions
  import src/instruction/*.dart     operator classes
```

> ✅ **Best practice:** Application code should import **only** `package:cell_flow/flow.dart`.

---

## 📚 Documentation

| Document | Contents |
|---|---|
| 📘 **[How to Start](guide/HowTo-Start.md)** | **Quick-start tutorial (15 min)** with 5 examples |
| 🏗️ [ARCHITECTURE-Flow.md](ARCHITECTURE-Flow.md) | Why Flow is shaped this way |
| 📋 [FEATURES-Flow.md](FEATURES-Flow.md) | Complete operator catalog (79+ operators) |
| 🎬 [DEMO_GUIDE.md](DEMO_GUIDE.md) | High-fidelity walkthroughs |
| 🔗 [HowTo-Fluent_Operator.md](guide/HowTo-Fluent_Operator.md) | Method chaining deep dive |
| 🎯 [HowTo-FlowInstruction-Receptor.md](guide/HowTo-FlowInstruction-Receptor.md) | Purpose-built Receptors |

---

## 🛠️ Runnable Examples

Explore the `example/` directory for complete, runnable demos:

| File | Scenario |
|---|---|
| `filter_data_quality_demo.dart` | Data quality gates |
| `stability_search_demo.dart` | Search box with debounce |
| `exhaust_map_submit_checkout_demo.dart` | Prevent double-checkout |
| `combine_latest_sync_demo.dart` | Sync multiple sources |
| `buffer_batch_processing_demo.dart` | Batch telemetry |
| `retry_timeout_flaky_network_demo.dart` | Resilient HTTP |
| `ICU-alarm-pipeline-Demo.dart` | Complex event processing |
| `switch_map_dynamic_dependency_demo.dart` | Dynamic dependencies |

Run any example:

```bash
cd packages/cell_flow
dart run example/filter_data_quality_demo.dart
```

---

## ⚙️ Important Rules

1. **A Cell does not complete.** Use `concat` on **inners** (lists/futures/streams), not Cell-then-Cell.
2. **`reduce` / `scan` are running folds**, not terminal values.
3. **Fluent `filter().map()` = 2 cells.** Use `Filter + MapValue` for **one Receptor**.
4. **Use `+` for sync policies.** Keep timers and HTTP on the next node.
5. **Keep `cell` and `cell_flow` on the same version line.**

---

## 📌 Versioning

| Package | Version | Status |
|---|---|---|
| `cell` | `1.0.0-rc.2` | Release Candidate |
| `cell_flow` | `1.0.0-rc.2` | Release Candidate |

**Mitosis** is the release codename (like an Android Studio animal). It is not part of the SemVer string. Stable on pub.dev will be `1.0.0`.

> ⚠️ **Status:** Release Candidate (RC2). APIs may change. Not yet on pub.dev — use path or git dependencies. Verify behaviour against source.

---

## 📄 License

**Dual-licensed:** MIT or Apache-2.0 — see [`LICENSE`](LICENSE) and file headers.

Copyright (c) 2025-Present Lee Man Hoi Simon. See [`AUTHORS`](AUTHORS).

> ℹ️ Operator *names* follow ReactiveX vocabulary. Implementations are original Cell Flow; using `switchMap` as a name does not require an RxJS copyright header.

---

## 🔗 Links

- 🏠 **Repo:** [github.com/simon-m-lee/cell](https://github.com/simon-m-lee/cell)
- 📦 **This package:** [packages/cell_flow](https://github.com/simon-m-lee/cell/tree/master/packages/cell_flow)
- 🐛 **Issues:** [github.com/simon-m-lee/cell/issues](https://github.com/simon-m-lee/cell/issues)
- 📖 **Cell framework:** [packages/cell](https://github.com/simon-m-lee/cell/tree/master/packages/cell)

---

**Ready to build reactive pipelines?** Start with the **[How to Start Guide](guide/HowTo-Start.md)** →
