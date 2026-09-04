# cell_flow — Feature catalog

**Author:** Lee Man Hoi Simon (see `AUTHORS`)

Catalog of **cell_flow** operators and entry points. Design intent lives
in [`ARCHITECTURE-Flow.md`](ARCHITECTURE-Flow.md). Fluent usage:
[`HowTo-Fluent_Operator.md`](HowTo-Fluent_Operator.md). One-Receptor
pipelines: [`HowTo-FlowInstruction-Receptor.md`](HowTo-FlowInstruction-Receptor.md).

Import once:

```dart
import 'package:cell_flow/flow.dart';
```

Every `Flow.*` factory is `SomeInstruction(...).toHandle(source: source)`.
Fluent methods on `Cell` / `FlowHandle` call those factories.

Cells do not complete. “Terminal” Rx names here mean a **running** or
**inner-sequence** adaptation, not stream completion.

---

## 1. Entry points

| Feature | API | Notes |
|---|---|---|
| Static facade | `Flow.map`, `Flow.debounce`, … | Application default |
| Fluent on `Cell` | `cell.filter()`, `cell.map()`, `cell.fromFuture()` | Start a pipeline |
| Fluent on `FlowHandle` | `handle.debounce().asyncMapLatest()` | Continue a pipeline |
| Instruction class | `Filter<int>((n) => n > 0).toHandle(source: …)` | Custom Receptor |
| Instruction chain | `Filter + MapValue + Tap` | One Receptor, one lock |
| Handle | `{ cell, emit, emitAsync, ingest }` | Same idea as `IngressHandle` |

---

## 2. Create

| Feature | Class / `Flow.` | Rx analogue | Behaviour |
|---|---|---|---|
| Values | `Of` / `of` | `of` | Play values on first arming pulse |
| Iterable | `FromIterable` / `fromIterable` | `from` | Same, from an iterable |
| Range | `Range` / `range` | `range` | `start` + `count` + `step` |
| Repeat | `Repeat` / `repeat` | value `repeat` | Same value `count` times |
| Future | `FromFuture` / `fromFuture` | `from(Future)` | One Future, first pulse |
| Defer future | `DeferFuture` / `deferFuture` | `defer` | New Future every pulse |
| Stream | `FromStream` / `fromStream` | `from(Stream)` | One subscription, first pulse |
| Defer stream | `DeferStream` / `deferStream` | `defer` + stream | New Stream every pulse |
| Many futures | `FromFutures`, `FromFuturesInOrder`, `ForkJoinFutures`, `RaceFutures` | merge / concat / forkJoin / race | See `from_future.dart` |
| Future helpers | `FromFutureWithRetry`, `WithTimeout`, `WithFallback`, `MapToFuture` | retry / timeout / catch | Per trigger |

Also: `ConcatFromFuture`, `MergeFromFuture`, `SwitchFromFuture`,
`ExhaustFromFuture`; `ConcatFromStream`, `MergeFromStream`,
`SwitchFromStream`, `MapToStream`.

---

## 3. Transform

| Feature | Class / `Flow.` | Rx analogue |
|---|---|---|
| Map | `MapValue` / `map` | `map` (`MapValue` avoids `dart:core` `Map`) |
| Map to constant | `MapTo` / `mapTo` | `mapTo` |
| Indexed map | `MapWithIndex` / `mapWithIndex` | `map` + index |
| Drop nulls | `MapNotNull` / `mapNotNull` | `mapNotNull` |
| Conditional map | `MapWhen` / `mapWhen` | map if predicate |
| Pluck field | `Pluck` / `pluck` | `pluck` |
| Pluck or default | `PluckOr` / `pluckOr` | |
| Several keys | `PluckAll` / `pluckAll` | |
| Nested path | `PluckPath` / `pluckPath` | |
| Running fold | `Scan` / `scan` | `scan` (first value seeds) |
| Named running fold | `Reduce` / `reduce` | running, not terminal |
| Pairs | `Pairwise` / `pairwise` | `pairwise` |

---

## 4. Async transform

| Feature | Class / `Flow.` | Concurrency |
|---|---|---|
| Async map | `AsyncMap` / `asyncMap` | queued |
| Concurrent map | `AsyncMapConcurrent` / `asyncMapConcurrent` | overlap |
| Latest map | `AsyncMapLatest` / `asyncMapLatest` | drop in-flight |
| Indexed async map | `AsyncMapWithIndex` | queued + index |
| Retry / timeout / fallback | `AsyncMapWithRetry`, `WithTimeout`, `WithFallback` | per item |
| Async expand | `AsyncExpand` / `asyncExpand` | queued flatten |
| Concurrent / latest / exhaust expand | `AsyncExpandConcurrent`, `Latest`, `Exhaust` | |
| Async fold | `AsyncFold` / `asyncFold` | queued accumulate |
| Latest / exhaust fold | `AsyncFoldLatest`, `AsyncFoldExhaust` | |
| Async reduce | `AsyncReduce` / `asyncReduce` | first value is seed |

---

## 5. Filter, take, skip, distinct

| Feature | Class / `Flow.` | Rx analogue |
|---|---|---|
| Predicate | `Filter` / `filter` | `filter` |
| Async filter | `AsyncFilter` + concurrent / latest / retry / timeout / fallback | |
| Not null | `FilterNotNull` | |
| Type narrow | `FilterType` | |
| Allow / block set | `FilterAllowed`, `FilterBlocked` | |
| Min gap | `FilterByTime` | spacing, first immediate |
| Take n / while / until | `Take`, `TakeWhile`, `TakeUntil` | `take*` |
| Skip n / while / until / when / repeated / last | `Skip*` | `skip*` |
| Distinct | `Distinct` / `distinct` | consecutive (see `distinct.dart` for variants) |

`Debounce` / `Throttle` / `Take` / `Skip` / `Distinct` are **not** defined
in `filter.dart`; they have their own files.

---

## 6. Flatten

| Feature | Class / `Flow.` | Policy |
|---|---|---|
| Concat map | `ConcatMap` / `concatMap` | queue inners |
| Concat static / all / first / latest | `Concat`, `ConcatAll`, `ConcatFirst`, `ConcatLatest` | inners, not Cell-then-Cell |
| Merge map | `MergeMap` / `mergeMap` | overlap inners |
| Switch map | `SwitchMap` / `switchMap` | latest inner |
| Exhaust map | `ExhaustMap` / `exhaustMap` | ignore while busy |

---

## 7. Combine

| Feature | Class / `Flow.` | Pairing |
|---|---|---|
| Merge with / merge / merge all | `MergeWith`, `Merge`, `MergeAll` | interleave |
| Zip with / zip / zip all | `ZipWith`, `Zip`, `ZipAll` | same index |
| Combine latest | `CombineLatestWith`, `CombineLatest` | latest of every source |
| With latest from | `WithLatestFrom` / `withLatestFrom` | source pulse + latest others |
| Race | `Race` / `race` | first inner to emit |

---

## 8. Time

| Feature | Class / `Flow.` | When it emits |
|---|---|---|
| Delay | `Delay` / `delay` | after fixed duration (keeps all values) |
| Delay selector / when | `DelayWithSelector`, `DelayWhen` | per value / notifier |
| Delay latest / trailing | `DelayLatest`, `DelayWithTrailing` | only last after wait |
| Delay + timeout cap | `DelayWithTimeout` | drop if wait > timeout |
| Debounce | `Debounce` / `debounce` | last after silence |
| Throttle | `Throttle` / `throttle` | leading / trailing window |
| Sample / sample time | `Sample`, `SampleTime` | notifier or period, latest pending |
| Audit / audit time | `Audit`, `AuditTime` | after source, then notifier / duration |
| Timeout | `Timeout`, `TimeoutWithFallback`, … | idle too long |
| Interval | `Interval`, `IntervalWithValue`, `IntervalWithState`, `TimerPulse` | ticks after first pulse |

---

## 9. Collect and route

| Feature | Class / `Flow.` | Payload |
|---|---|---|
| Buffer count / time / when / predicate | `BufferCount`, `BufferTime`, `BufferWhen`, `BufferWithPredicate` | `List` |
| Buffer time and count | `BufferWithTimeAndCount` | count **or** duration |
| Window count / time | `WindowCount`, `WindowTime` | window lists |
| Group by / collect / count | `GroupBy`, `GroupCollect`, `GroupByCount` | `Grouped` or `Map` |
| Partition / map / only | `Partition`, `PartitionMap`, `PartitionOnly` | match vs rest |
| Boolean branch | `Iif` / `iif` | then / else projectors |

---

## 10. Control, multicast, side effect

| Feature | Class / `Flow.` | Role |
|---|---|---|
| Start with | `StartWith` / `startWith` | prefix on first pulse |
| Share / share replay | `Share`, `ShareReplay` | multicast |
| Retry | `Retry` / `retry` | `RetryTask` + count |
| Tap / tap all / tap index | `Tap`, `TapAll`, `TapWithIndex` | side effect, same value |

---

## 11. What Flow is not

| Need | Use instead |
|---|---|
| Persistent app state, undo, transactions | **cell** `Cell.state`, `Cell.transaction` |
| Integrity / authority metadata | **cell** `TestCell`, `Context` |
| A completing stream | Dart `Stream` / `Cell.fromStream` as a source, not “complete this Cell” |
| `concat(cellA, cellB)` | concat **inners**; Cells do not complete |
| Terminal `reduce` / `last` / `toList` | running `scan` / `reduce`, or `buffer` / `take` |

---

## 12. Examples in this tree

| File | Intent |
|---|---|
| `example_sanitize_text.dart` | trim + drop blanks (`+` chain) |
| `example_search_query_gate.dart` | search box policy |
| `example_checkout_quote.dart` | cart → total |
| `example_moderation_gate.dart` | comment blocklist |
| `example_sensor_threshold.dart` | °C → °F |
| `example_form_email.dart` | email field |
| `example_order_status_tap.dart` | paid/shipped + audit |
| `example_price_cents.dart` | cents → dollars |
| `example_feature_flag_iif.dart` | beta preview |
| `example_take_first_valid_pin.dart` | PIN take 3 |

Each instruction file also has a `main` demo and a `*_test.dart` where
tests were requested.

---

## 13. Naming clashes

| Name | Collision | How Flow spells it |
|---|---|---|
| `Map` | `dart:core` | `MapValue` / `Flow.map` |
| `Skip`, `Take`, `Retry`, `Timeout` | `package:test` | hide in tests: `import 'package:test/test.dart' hide Timeout;` |
| `Partition` | routing vs group-by | standalone `partition.dart` |
| `state` | persistent cell state | running fold is `reduce` / `scan`, not `Flow.state` |
