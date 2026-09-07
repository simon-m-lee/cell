# How to Start with cell_flow

**Quick-start guide for developers** · `cell_flow` v1.0.0-rc.2

Get up and running with **cell_flow** in 15 minutes. Learn the three ways to build reactive pipelines, understand when to use each approach, and copy-paste ready examples for common scenarios.

---

## Table of Contents

1. [What is cell_flow?](#what-is-cell_flow)
2. [Installation](#installation)
3. [Core Concepts in 5 Minutes](#core-concepts-in-5-minutes)
4. [Three Ways to Build Pipelines](#three-ways-to-build-pipelines)
5. [Your First Pipeline (5 Examples)](#your-first-pipeline-5-examples)
6. [Operator Cheat Sheet](#operator-cheat-sheet)
7. [Common Patterns](#common-patterns)
8. [Testing Your Pipelines](#testing-your-pipelines)
9. [Next Steps](#next-steps)

---

## What is cell_flow?

**cell_flow** brings Rx-shaped stream operators to the [Cell](https://github.com/simon-m-lee/cell) framework. Think debounce, switchMap, zip, retry, buffer — but as `FlowInstruction`s on the **same graph** as `package:cell`.

| You want to… | cell_flow provides |
|---|---|
| Debounce user input | `Flow.debounce` or `.debounce()` |
| Cancel stale HTTP requests | `Flow.switchMap` or `.switchMap()` |
| Pair values by index | `Flow.zip` or `.zipWith()` |
| Retry failed operations | `Flow.retry` or `.retry()` |
| Batch events | `Flow.bufferCount` or `.bufferCount()` |

**Key insight:** The graph, locks, validation, and provenance stay in **cell**. Flow only decides *which* pulses leave and *when*.

---

## Installation

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

> ⚠️ **Status:** Release Candidate (RC2). APIs may change. Not yet on pub.dev — use path or git dependencies.

---

## Core Concepts in 5 Minutes

### 1. Cell + Pulse = Graph Node + Signal

```dart
final box = Cell.ingress<String>();  // A node you can emit to
await box.emitAsync('Hello');        // Sends a pulse through the graph
```

### 2. FlowInstruction = Named Policy

Each operator (`Filter`, `Debounce`, `SwitchMap`) is a `FlowInstruction` that:
1. Reads pulses from a source `Cell`
2. Applies its policy (drop, delay, map, buffer)
3. Emits downstream via a `FlowHandle`

### 3. FlowHandle = { cell, emit, emitAsync, ingest }

```dart
final handle = Flow.filter<String>(box.cell, test: (s) => s.length > 2);
handle.cell;        // Observe this
await handle.emit('test');  // Or emit directly
```

### 4. Progressive Disclosure

| Tier | Use When | Example |
|---|---|---|
| **1. `Flow.*` factories** | App code, default | `Flow.debounce(...)` |
| **2. Fluent extensions** | Unary pipelines | `cell.filter().map()` |
| **3. Instruction classes** | Custom Receptor | `Filter<T>(...)` |
| **4. InstructionChain** | One Receptor, many sync ops | `Filter + MapValue + Tap` |

---

## Three Ways to Build Pipelines

### Way 1: Static Factories (Recommended for beginners)

```dart
import 'package:cell_flow/flow.dart';

final query = Cell.ingress<String>();

final results = Flow.debounce<String>(
  Flow.filter<String>(query.cell, test: (q) => q.length >= 2).cell,
  duration: const Duration(milliseconds: 300),
);

Cell.observe(source: results.cell, effect: (p) => print(p.payload));
await query.emitAsync('Dart');
```

**Best for:** Multi-source operators (`merge`, `zip`, `combineLatest`), naming nodes for logs.

---

### Way 2: Fluent Chaining (Most readable)

```dart
import 'package:cell_flow/flow.dart';

final query = Cell.ingress<String>();

final results = query.cell
    .filter<String>(test: (q) => q.length >= 2)
    .debounce<String>(duration: const Duration(milliseconds: 300))
    .asyncMapLatest<String, List<String>>(mapper: (q) => api.search(q));

Cell.observe(source: results.cell, effect: (p) => print(p.payload));
await query.emitAsync('Flutter');
```

**Best for:** Linear pipelines, readability, quick prototyping.

> 💡 **Note:** Each fluent step creates a **new Cell/Receptor**. `filter().map()` = 2 cells.

---

### Way 3: InstructionChain (One Receptor, many ops)

```dart
import 'package:cell_flow/flow.dart';

// Build a reusable policy
final sanitize = MapValue<String, String>((s) => s.trim()) +
    Filter<String>((s) => s.isNotEmpty) +
    Distinct<String>();

final query = Cell.ingress<String>();
final handle = sanitize.toHandle(source: query.cell);

Cell.observe(source: handle.cell, effect: (p) => print(p.payload));
await query.emitAsync('  Dart  ');  // → 'Dart'
await query.emitAsync('   ');       // → dropped
```

**Best for:** Sync policies (trim, filter, tap), shared locks, unit testing gates.

> 💡 **Key difference:** `+` chains run in **one Receptor** under **one lock**. Fluent chains create multiple cells.

---

## Your First Pipeline (5 Examples)

### Example 1: Search Box (Debounce + Async)

```dart
import 'package:cell_flow/flow.dart';

final query = Cell.ingress<String>();

final results = query.cell
    .map<String, String>(project: (q) => q.trim().toLowerCase())
    .filter<String>(test: (q) => q.length >= 2)
    .debounce<String>(duration: const Duration(milliseconds: 300))
    .asyncMapLatest<String, List<Hit>>(mapper: (q) => api.search(q))
    .tap<List<Hit>>(onValue: (hits) => analytics.track('search', hits.length));

Cell.observe(source: results.cell, effect: (p) {
  print('Found ${p.payload.length} hits');
});

await query.emitAsync('Dart packages');
```

**Operators used:** `map` → `filter` → `debounce` → `asyncMapLatest` → `tap`

**Why it works:** `asyncMapLatest` cancels stale requests when the user types again.

---

### Example 2: Form Validation (Sync Chain)

```dart
import 'package:cell_flow/flow.dart';

final raw = Cell.ingress<String>();

// One Receptor, one lock
final emailGate = MapValue<String, String>((s) => s.trim().toLowerCase()) +
    Filter<String>((s) => s.contains('@')) +
    Distinct<String>();

final validated = emailGate.toHandle(source: raw.cell);

Cell.observe(source: validated.cell, effect: (p) {
  print('Valid email: ${p.payload}');
});

await raw.emitAsync('  USER@example.com  ');  // → 'user@example.com'
await raw.emitAsync('invalid');               // → dropped
```

**Operators used:** `MapValue` + `Filter` + `Distinct` (chained with `+`)

---

### Example 3: Button Double-Tap Prevention (Exhaust Map)

```dart
import 'package:cell_flow/flow.dart';

final taps = Cell.ingress<void>();

final receipts = taps.cell.exhaustMap<void, Receipt>(
  project: (_) => api.checkout(cart),
);

Cell.observe(source: receipts.cell, effect: (p) {
  print('Checkout complete: ${p.payload.id}');
});

await taps.emitAsync(null);  // First tap starts checkout
await taps.emitAsync(null);  // Ignored while checkout runs
```

**Operators used:** `exhaustMap`

**Why it works:** While the inner Future runs, additional taps are ignored.

---

### Example 4: Combine Two Streams (CombineLatest)

```dart
import 'package:cell_flow/flow.dart';

final price = Cell.ingress<int>();
final currency = Cell.ingress<String>();

final display = price.cell.withLatestFrom<int, String>(
  others: [currency.cell],
  combine: (p, latest) => '${latest.single} $p',
);

Cell.observe(source: display.cell, effect: (p) {
  print(p.payload);  // → 'EUR 25'
});

await price.emitAsync(20);      // Waits for currency
await currency.emitAsync('EUR'); // Now both have values
await price.emitAsync(25);       // → 'EUR 25'
```

**Operators used:** `withLatestFrom`

> ⚠️ **Gotcha:** `withLatestFrom` waits until **every** other Cell has at least one value.

---

### Example 5: Batch Telemetry (Buffer + Time)

```dart
import 'package:cell_flow/flow.dart';

final events = Cell.ingress<Metric>();

final batches = events.cell
    .bufferWithTimeAndCount<Metric>(
      duration: const Duration(seconds: 5),
      count: 50,
    )
    .asyncMap<List<Metric>, void>(mapper: (batch) => api.flush(batch));

Cell.observe(source: batches.cell, effect: (p) {
  print('Flushed ${p.payload.length} metrics');
});

// Emit 60 events → flushes at 50, then at 5 seconds for remaining 10
for (int i = 0; i < 60; i++) {
  await events.emitAsync(Metric(value: i));
}
```

**Operators used:** `bufferWithTimeAndCount` → `asyncMap`

**Why it works:** Flushes when **either** 50 events arrive **or** 5 seconds pass.

---

## Operator Cheat Sheet

### Create

| Operator | Description | Example |
|---|---|---|
| `of` | Play values on first pulse | `Flow.of(values: [1, 2, 3])` |
| `fromIterable` | Same, from iterable | `cell.fromIterable(iterable: list)` |
| `fromFuture` | One Future, first pulse | `cell.fromFuture(future: api.me())` |
| `fromStream` | One subscription, first pulse | `cell.fromStream(stream: ticker)` |
| `range` | start + count + step | `cell.range(start: 1, count: 5)` |

### Transform

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

### Flatten (Inner Sequences)

| Operator | Policy | Use When |
|---|---|---|
| `concatMap` | Queue inners | Order matters |
| `mergeMap` | Overlap inners | Parallel OK |
| `switchMap` | Latest only | Cancel stale |
| `exhaustMap` | Ignore while busy | Prevent double-taps |

### Combine

| Operator | Pairing Rule | Example |
|---|---|---|
| `mergeWith` | Interleave | `cell.mergeWith(sources: [a, b])` |
| `zipWith` | Same index | `cell.zipWith(others: [a, b])` |
| `combineLatestWith` | Latest of all | `cell.combineLatestWith(others: [a])` |
| `withLatestFrom` | Source + latest others | `cell.withLatestFrom(others: [a], combine: ...)` |
| `race` | First to emit | `Flow.race(cell, competitors: [a, b])` |

### Time

| Operator | When It Emits | Example |
|---|---|---|
| `delay` | After fixed duration | `cell.delay(duration: 1s)` |
| `debounce` | Last after silence | `cell.debounce(duration: 300ms)` |
| `throttle` | Leading/trailing window | `cell.throttle(duration: 1s, leading: true)` |
| `sample` | Notifier or period | `cell.sampleTime(period: 1s)` |
| `timeout` | Idle too long | `cell.timeout(duration: 5s)` |

### Collect / Control

| Operator | Payload | Example |
|---|---|---|
| `bufferCount` | List | `cell.bufferCount(count: 10)` |
| `bufferTime` | List | `cell.bufferTime(duration: 5s)` |
| `groupBy` | Grouped | `cell.groupBy(keyOf: (x) => x.type)` |
| `startWith` | Prefix | `cell.startWith(value: 0)` |
| `retry` | Retry count | `cell.retry(count: 3)` |
| `tap` | Side effect | `cell.tap(onValue: print)` |

---

## Common Patterns

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

---

### Pattern 2: Form Field → Validated Model

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

### Pattern 3: Rate-Limited Scroll/Pointer

```dart
final offsets = Cell.ingress<double>();

final sampled = offsets.cell
    .throttle<double>(
      duration: const Duration(milliseconds: 16),
      leading: true,
      trailing: true,
    )
    .map<double, int>(project: (y) => y.round());
```

---

### Pattern 4: Paginated List from Stream of Pages

```dart
final pages = Cell.ingress<List<Row>>();

final rows = pages.cell.concatAll<Row>();
// [a, b] then [c] → a, b, c in order
```

---

### Pattern 5: Group Live Feed

```dart
final orders = Cell.ingress<Order>();

final byStatus = orders.cell.groupBy<Order, String>(
  keyOf: (o) => o.status,
);
// payload is Grouped('paid', order)
```

---

## Testing Your Pipelines

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

---

### Test an Async Pipeline (With Timer)

```dart
import 'package:cell_flow/flow.dart';
import 'package:test/test.dart';

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

### Test with Mock API

```dart
class MockApi {
  Future<List<Hit>> search(String q) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return [Hit(title: 'Result for $q')];
  }
}

void main() {
  test('search pipeline cancels stale requests', () async {
    final api = MockApi();
    final query = Cell.ingress<String>();
    
    final results = query.cell
        .debounce<String>(duration: const Duration(milliseconds: 100))
        .asyncMapLatest<String, List<Hit>>(mapper: api.search);
    
    final emitted = <List<Hit>>[];
    Cell.observe(source: results.cell, effect: (p) {
      emitted.add(p.payload);
    });
    
    // Type fast
    await query.emitAsync('D');
    await query.emitAsync('Da');
    await query.emitAsync('Dart');
    
    // Wait for debounce + API
    await Future.delayed(const Duration(milliseconds: 250));
    
    expect(emitted.length, equals(1));  // Only last request completed
    expect(emitted.single.first.title, contains('Dart'));
  });
}
```

---

## Next Steps

### 📚 Deepen Your Knowledge

| Document | What You'll Learn |
|---|---|
| [`FEATURES-Flow.md`](FEATURES-Flow.md) | Full operator catalog (176+ operators) |
| [`ARCHITECTURE-Flow.md`](ARCHITECTURE-Flow.md) | Why Flow is shaped this way |
| [`HowTo-Fluent_Operator.md`](guide/HowTo-Fluent_Operator.md) | Method chaining deep dive |
| [`HowTo-FlowInstruction-Receptor.md`](guide/HowTo-FlowInstruction-Receptor.md) | Purpose-built Receptors |
| [`DEMO_GUIDE.md`](DEMO_GUIDE.md) | High-fidelity walkthroughs |

---

### 🛠️ Explore Examples

Runnable demos in `example/`:

| File | Scenario |
|---|---|
| `filter_data_quality_demo.dart` | Data quality gates |
| `debounce_search_query_demo.dart` | Search box |
| `exhaust_map_submit_checkout_demo.dart` | Prevent double-checkout |
| `combine_latest_sync_demo.dart` | Sync multiple sources |
| `buffer_batch_processing_demo.dart` | Batch telemetry |
| `retry_timeout_flaky_network_demo.dart` | Resilient HTTP |
| `ICU-alarm-pipeline-Demo.dart` | Complex event processing |

Run any example:

```bash
cd packages/cell_flow
dart run example/filter_data_quality_demo.dart
```

---

### 🔍 Key Rules to Remember

1. **A Cell does not complete.** Use `concat` on **inners** (lists/futures/streams), not Cell-then-Cell.
2. **`combineLatest` / `withLatestFrom` wait** until every other Cell has a value.
3. **Time operators use real Timers.** Tests must `await` past the duration.
4. **Type arguments are required** on most methods (`filter<int>`, `map<int, String>`).
5. **Errors go to `onError:`**, not rethrown into the chain.
6. **Inject with `IngressHandle.emitAsync`**, not raw `Cell.emitAsync`.
7. **Use `+` for sync policy**, keep timers/HTTP on the next node.

---

### 🆘 Troubleshooting

| Problem | Likely Cause | Fix |
|---|---|---|
| No output from `combineLatest` | Other Cells haven't emitted | Ensure all sources emit at least once |
| Timer tests fail immediately | Didn't wait past duration | `await Future.delayed(...)` |
| Type error on `map` | Missing type args | `map<int, String>(project: ...)` |
| Stale HTTP requests not cancelled | Used `asyncMap` instead of `asyncMapLatest` | Switch to `asyncMapLatest` |
| Double-taps still go through | Used `mergeMap` instead of `exhaustMap` | Switch to `exhaustMap` |

---

### 📞 Get Help

- **Issues:** [github.com/simon-m-lee/cell/issues](https://github.com/simon-m-lee/cell/issues)
- **Repo:** [github.com/simon-m-lee/cell](https://github.com/simon-m-lee/cell)
- **Package:** [packages/cell_flow](https://github.com/simon-m-lee/cell/tree/master/packages/cell_flow)

---

**Happy piping!** 🚰

If you've made it this far, you now know enough to build production-ready reactive pipelines with `cell_flow`. Start with the fluent syntax, refactor to InstructionChains when you need shared locks, and always test your time-based operators with proper delays.
