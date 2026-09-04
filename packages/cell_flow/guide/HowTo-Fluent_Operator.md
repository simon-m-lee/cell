# How to use Fluent Operators

`fluent_operator.dart` is a **part** of `package:cell_flow/flow.dart`. One import is enough:

```dart
import 'package:cell_flow/flow.dart';
```

You do **not** import the extension file yourself.

The extensions wrap the same `Flow.*` static factories. Behaviour does not live in two places.

| Extension | On | Use it to |
|---|---|---|
| `CellFlowOperators` | `Cell` | start a pipeline |
| `FlowOperators` | `FlowHandle` | keep chaining via `.cell` |

---

## Nested vs fluent

```dart
// Nested factories
final out = Flow.map<int, String>(
  Flow.filter<int>(clicks.cell, test: (n) => n > 0).cell,
  project: (n) => '$n',
);

// Same pipeline, chained
final out = clicks.cell
    .filter<int>(test: (n) => n > 0)
    .map<int, String>(project: (n) => '$n');
```

Observe the last handle’s cell:

```dart
Cell.observe(
  source: out.cell,
  effect: (Pulse p) => print(p.payload),
);
await clicks.emitAsync(3);
```

---

## Start from a Cell

`CellFlowOperators` is the on-ramp. Typical sources:

```dart
final ingress = Cell.ingress<int>();

ingress.cell.filter<int>(test: (n) => n.isEven);
ingress.cell.map<int, String>(project: (n) => '#$n');
ingress.cell.tap<int>(onValue: print);

// One-shot sequences (first pulse on this cell arms them)
arm.cell.of<String>(values: ['a', 'b']);
arm.cell.fromIterable<int>(iterable: [1, 2, 3]);
arm.cell.range(start: 1, count: 5);
arm.cell.fromFuture<User>(future: api.me());
arm.cell.fromStream<int>(stream: ticker);
```

Anything not on `Cell` can start with a factory, then chain:

```dart
Flow.debounce<String>(query.cell, duration: const Duration(milliseconds: 300))
    .asyncMapLatest<String, List<Hit>>(mapper: api.search);
```

---

## Practical pipelines

### Search-as-you-type

```dart
final query = Cell.ingress<String>();

final results = query.cell
    .map<String, String>(project: (q) => q.trim())
    .filter<String>(test: (q) => q.length >= 2)
    .debounce<String>(duration: const Duration(milliseconds: 300))
    .asyncMapLatest<String, List<Hit>>(mapper: (q) => api.search(q))
    .tap<List<Hit>>(onValue: (hits) => analytics.track('search', hits.length));
```

`asyncMapLatest` drops a stale in-flight request when the user types again.

### Form field → validated model

```dart
final raw = Cell.ingress<String>();

final email = raw.cell
    .map<String, String>(project: (s) => s.trim().toLowerCase())
    .filter<String>(test: (s) => s.contains('@'))
    .distinct<String>()
    .asyncMap<String, User>(
      mapper: (e) => api.lookup(e),
      onError: (e, _) => log.warn(e),
    );
```

### Scroll / pointer rate limit

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

### Button → HTTP, ignore double-taps

```dart
final taps = Cell.ingress<void>();

final saved = taps.cell.exhaustMap<void, Receipt>(
  project: (_) => api.checkout(cart),
);
```

While checkout is running, extra taps are ignored.

### Latest of two Cells when the source moves

```dart
final price = Cell.ingress<int>();
final currency = Cell.ingress<String>();

final line = price.cell.withLatestFrom<int, String>(
  others: [currency.cell],
  combine: (p, latest) => '${latest.single} $p',
);
```

`1` then `'EUR'` then `2` → `"EUR 2"` (currency must already have a value).

### Pair by index (not latest)

```dart
final ids = Cell.ingress<int>();
final names = Cell.ingress<String>();

final rows = ids.cell.zipWith<List<Object?>>(
  others: [names.cell],
);
// 1, then 'Ada', then 2, then 'Bob' → [1, Ada], [2, Bob]
```

### Batch telemetry

```dart
final events = Cell.ingress<Metric>();

final batches = events.cell
    .bufferWithTimeAndCount<Metric>(
      duration: const Duration(seconds: 5),
      count: 50,
    )
    .asyncMap<List<Metric>, void>(mapper: (batch) => api.flush(batch));
```

Flush when 50 events arrive **or** 5 seconds pass, whichever first.

### Paginated list from a stream of pages

```dart
final pages = Cell.ingress<List<Row>>();

final rows = pages.cell.concatAll<Row>();
// [a, b] then [c] → a, b, c in that order
```

### Group a live feed

```dart
final orders = Cell.ingress<Order>();

final byStatus = orders.cell.groupBy<Order, String>(
  keyOf: (o) => o.status,
);
// payload is Grouped('paid', order)
```

---

## Method catalogue

Payload type parameters (`S`, `T`, …) are the same as on `Flow.*`.

### Start (`Cell`)

| Method | Rx analogue |
|---|---|
| `of` / `fromIterable` / `range` / `repeat` | `of` / `from` / `range` |
| `fromFuture` / `fromStream` | `from(Future)` / `from(Stream)` |
| `map` / `filter` / `tap` | start a transform |

### Transform (`FlowHandle`)

| Method | Role |
|---|---|
| `map` / `mapTo` / `mapWithIndex` / `mapNotNull` / `mapWhen` | project |
| `pluck` / `pluckOr` / `pluckPath` | field access |
| `scan` / `reduce` / `pairwise` | running state |

### Async

| Method | Concurrency |
|---|---|
| `asyncMap` | queue (one result each) |
| `asyncMapConcurrent` | overlap |
| `asyncMapLatest` | drop in-flight |
| `asyncExpand` | flatten inners, queued |
| `asyncFold` | async running fold |

### Filter / take / skip

`filter`, `take` / `takeWhile` / `takeUntil`, `skip` / `skipWhile` / `skipUntil` / `skipRepeated`, `distinct`.

### Flatten

`concatMap`, `concatAll`, `mergeMap`, `switchMap`, `exhaustMap`.

### Combine

`mergeWith`, `mergeAll`, `zipWith`, `combineLatestWith`, `withLatestFrom`.

### Time

`delay` / `delayWhen`, `debounce`, `throttle`, `sample` / `sampleTime`, `auditTime`, `timeout`, `interval`.

### Collect / route / control

`bufferCount` / `bufferTime`, `windowCount`, `groupBy`, `partition`, `startWith`, `share` / `shareReplay`, `retry`, `tap` / `tapAll` / `tapWithIndex`.

Factories that exist on `Flow` but not on the handle (for example `Flow.race`, `Flow.audit`, `Flow.windowTime`) can still be inserted mid-pipeline:

```dart
Flow.race<int>(gate.cell, competitors: [a.future, b.future])
    .tap<int>(onValue: print);
```

---

## Rules that bite in real apps

1. **Inject with `IngressHandle.emitAsync`**, not a raw `Cell.emitAsync`.
2. **A Cell does not complete.** `concat` of two Cells is not “A then B”. Concatenate **inners** (lists / futures / streams) instead.
3. **`combineLatest` / `withLatestFrom` wait until every other Cell has a value.** Zip waits for the same *index* on every lane.
4. **Time operators use real `Timer`s.** Tests must `await` past the duration.
5. **Type arguments are required** on most methods (`filter<int>`, `map<int, String>`). The handle itself is not generic in the facade.
6. **Errors** go to the `onError:` you pass through. They are not rethrown into the chain unless that instruction emits an error pulse.

---

## When to stay with `Flow.*`

Use the static factory when:

- you are arming a one-shot (`Flow.of`, `Flow.range`) from a dedicated gate Cell
- the operator is not on the extension yet
- you want the call site to name the operator for logs / codegen

Fluent and static can mix in the same pipeline. Both call the same instruction classes.
