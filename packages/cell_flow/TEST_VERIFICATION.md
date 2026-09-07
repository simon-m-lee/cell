# cell_flow package - Test Verification Report

**Generated:** 2026-09-06
**Package:** cell_flow (v1.0.0-rc.2.0.1)
**Test Files Analyzed:** 42
**Total Tests:** 1022 (0 skipped)

---

## Table of contents

- [Executive Summary](#executive-summary)
  - [Snapshot](#snapshot)
  - [Quick Stats](#quick-stats)
- [Test File Inventory](#test-file-inventory)
- [Detailed Test Coverage](#detailed-test-coverage)
  - [async_expand_test.dart](#file-1-async_expand_test.dart-24-tests)
  - [async_fold_test.dart](#file-2-async_fold_test.dart-20-tests)
  - [async_map_test.dart](#file-3-async_map_test.dart-30-tests)
  - [buffer_test.dart](#file-4-buffer_test.dart-24-tests)
  - [combine_latest_test.dart](#file-5-combine_latest_test.dart-13-tests)
  - [concat_map_test.dart](#file-6-concat_map_test.dart-25-tests)
  - [concat_test.dart](#file-7-concat_test.dart-21-tests)
  - [debounce_test.dart](#file-8-debounce_test.dart-21-tests)
  - [delay_test.dart](#file-9-delay_test.dart-26-tests)
  - [distinct_test.dart](#file-10-distinct_test.dart-23-tests)
  - [exhaust_map_test.dart](#file-11-exhaust_map_test.dart-24-tests)
  - [filter_test.dart](#file-12-filter_test.dart-31-tests)
  - [flow_test.dart](#file-13-flow_test.dart-81-tests)
  - [fluent_operator_test.dart](#file-14-fluent_operator_test.dart-37-tests)
  - [from_future_test.dart](#file-15-from_future_test.dart-37-tests)
  - [from_stream_test.dart](#file-16-from_stream_test.dart-25-tests)
  - [group_by_test.dart](#file-17-group_by_test.dart-23-tests)
  - [instruction_demo_test.dart](#file-18-instruction_demo_test.dart-39-tests)
  - [interval_test.dart](#file-19-interval_test.dart-19-tests)
  - [map_test.dart](#file-20-map_test.dart-35-tests)
  - [merge_map_test.dart](#file-21-merge_map_test.dart-20-tests)
  - [merge_test.dart](#file-22-merge_test.dart-19-tests)
  - [of_test.dart](#file-23-of_test.dart-23-tests)
  - [pairwise_test.dart](#file-24-pairwise_test.dart-13-tests)
  - [partition_test.dart](#file-25-partition_test.dart-22-tests)
  - [pluck_test.dart](#file-26-pluck_test.dart-24-tests)
  - [race_test.dart](#file-27-race_test.dart-22-tests)
  - [reduce_test.dart](#file-28-reduce_test.dart-19-tests)
  - [retry_test.dart](#file-29-retry_test.dart-26-tests)
  - [routing_test.dart](#file-30-routing_test.dart-29-tests)
  - [sample_test.dart](#file-31-sample_test.dart-16-tests)
  - [scan_test.dart](#file-32-scan_test.dart-16-tests)
  - [share_test.dart](#file-33-share_test.dart-19-tests)
  - [skip_test.dart](#file-34-skip_test.dart-26-tests)
  - [start_with_test.dart](#file-35-start_with_test.dart-21-tests)
  - [switch_map_test.dart](#file-36-switch_map_test.dart-21-tests)
  - [take_test.dart](#file-37-take_test.dart-21-tests)
  - [tap_test.dart](#file-38-tap_test.dart-23-tests)
  - [throttle_test.dart](#file-39-throttle_test.dart-14-tests)
  - [timeout_test.dart](#file-40-timeout_test.dart-19-tests)
  - [window_test.dart](#file-41-window_test.dart-17-tests)
  - [zip_test.dart](#file-42-zip_test.dart-14-tests)
- [Runtime Verification Status](#runtime-verification-status)
  - [Line Coverage (`lib/`)](#line-coverage-lib)
- [Recommendations](#recommendations)
- [Appendix: File Locations](#appendix-file-locations)

---

## Executive Summary

The cell_flow test suite contains **1022 unit tests** across **42 files** in `test/`. Counts are `test(` declarations.

This file is **generated**. Edit the script flags or the stub sections at the bottom; do not hand-count `test(`.

### Snapshot

`lib/` line coverage is **96.3%** (5557 / 5768).

No `lib/` file is below 70% in this lcov.

### Quick Stats

| Metric | Value |
|--------|-------|
| **Total Test Files** | 42 |
| **Total Tests** | 1022 |
| **Skipped** | 0 |
| **Last full run** | *(pass `--run-tests` to fill)* |
| **Test Groups** | 440 (`group(` declarations) |
| **Async-ish tests** | ~980 (heuristic) |
| **Line coverage (`lib/`)** | **96.3%** (5557 / 5768) |

---

## Test File Inventory

| # | File | Lines | Tests | Size | Focus |
|---|------|------:|------:|------:|-------|
| 1 | async_expand_test.dart | 365 | 24 | 11.7 KB | async expand test; groups: AsyncExpand, AsyncExpandConcurrent, AsyncExpandLatest, AsyncExpandExhaust, edges, performance… |
| 2 | async_fold_test.dart | 360 | 20 | 11.3 KB | async fold test; groups: AsyncFold snapshot, AsyncFoldLatest snapshot, AsyncFoldExhaust snapshot, edges, performance, AsyncFold extra… |
| 3 | async_map_test.dart | 488 | 30 | 15.1 KB | async map test; groups: AsyncMap, AsyncMapSequential, AsyncMapConcurrent, AsyncMapLatest, AsyncMapWithIndex, AsyncMapWithRetry… |
| 4 | buffer_test.dart | 398 | 24 | 11.5 KB | buffer test; groups: BufferCount, BufferWithCount, BufferTime, BufferWhen, BufferWithPredicate, BufferWithTimeAndCount… |
| 5 | combine_latest_test.dart | 273 | 13 | 8.2 KB | combine latest; groups: CombineLatestWith, CombineLatest, WithLatestFrom, CombineLatest2, CombineLatestWith extra, CombineLatest extra… |
| 6 | concat_map_test.dart | 375 | 25 | 11.7 KB | concat map test; groups: ConcatMap, ConcatMapTo, ConcatMapLatest, ConcatMapFirst, ConcatMap extra, ConcatMapTo extra… |
| 7 | concat_test.dart | 285 | 21 | 8.2 KB | concat test; groups: Concat, ConcatAll, ConcatFirst, ConcatLatest, edges, performance… |
| 8 | debounce_test.dart | 310 | 21 | 10.7 KB | debounce test; groups: Debounce, DebounceLeading, DebounceLeadingOnly, DebounceWith, Debounce extra, DebounceLeading extra… |
| 9 | delay_test.dart | 368 | 26 | 12.0 KB | delay test; groups: Delay, DelayWithSelector, DelayWhen, DelayLatest, DelayWithTrailing, DelayWithTimeout… |
| 10 | distinct_test.dart | 356 | 23 | 11.1 KB | distinct test; groups: DistinctUntilChanged, DistinctUntilKeyChanged, Distinct, DistinctKey, DistinctUntilChanged extra, DistinctUntilKeyChanged extra… |
| 11 | exhaust_map_test.dart | 368 | 24 | 11.8 KB | exhaust map test; groups: ExhaustMap, ExhaustMapTo, ExhaustAll, ExhaustMapFirst, ExhaustMapLatest, ExhaustMap extra… |
| 12 | filter_test.dart | 474 | 31 | 15.1 KB | filter test; groups: Filter, FilterNotNull, FilterType, FilterAllowed / FilterBlocked, FilterByTime, AsyncFilter… |
| 13 | flow_test.dart | 1,193 | 81 | 37.4 KB | flow test; groups: FlowHandle / toHandle, Flow create, Flow transform, Flow filter family, Flow flatten / combine, Flow time… |
| 14 | fluent_operator_test.dart | 520 | 37 | 17.0 KB | fluent operator test; groups: CellFlowOperators, FlowOperators transform, FlowOperators async, FlowOperators filter family, FlowOperators flatten / combine, FlowOperators time / collect / control… |
| 15 | from_future_test.dart | 573 | 37 | 18.1 KB | from future test; groups: FromFuture, DeferFuture, FromFutureOr, ConcatFromFuture, MergeFromFuture, SwitchFromFuture… |
| 16 | from_stream_test.dart | 369 | 25 | 11.4 KB | from stream test; groups: FromStream, DeferStream, ConcatFromStream, MergeFromStream, SwitchFromStream, MapToStream… |
| 17 | group_by_test.dart | 384 | 23 | 12.3 KB | group by test; groups: Grouped, GroupBy, GroupCollect, GroupByCount, GroupBy extra, GroupCollect extra… |
| 18 | instruction_demo_test.dart | 102 | 39 | 5.5 KB | instruction demo test; groups: instruction demo mains emit through bodies |
| 19 | interval_test.dart | 309 | 19 | 9.6 KB | interval test; groups: Interval, IntervalWithValue, IntervalWithState, TimerPulse, Interval extra, IntervalWithValue extra… |
| 20 | map_test.dart | 503 | 35 | 15.2 KB | map test; groups: MapValue, MapTo, MapWithIndex, MapNotNull, MapWhen, MapValueIf… |
| 21 | merge_map_test.dart | 320 | 20 | 9.7 KB | merge map test; groups: MergeMap, MergeMapTo, MergeScan, MergeMap extra, MergeMapTo extra, MergeScan extra… |
| 22 | merge_test.dart | 297 | 19 | 9.2 KB | merge test; groups: MergeWith, Merge, MergeAll, MergeWith extra, Merge extra, MergeAll extra… |
| 23 | of_test.dart | 274 | 23 | 7.6 KB | of test; groups: Of, FromIterable, Range, Repeat, edges, performance… |
| 24 | pairwise_test.dart | 214 | 13 | 6.4 KB | pairwise test; groups: Pairwise, PairwiseWith, Pairwise extra, PairwiseWith extra, composition / performance |
| 25 | partition_test.dart | 340 | 22 | 10.2 KB | partition test; groups: Partition, PartitionMap, PartitionCollect, PartitionOnly, Partition extra, PartitionMap extra… |
| 26 | pluck_test.dart | 310 | 24 | 8.9 KB | pluck test; groups: Pluck, PluckOr, PluckAll, PluckPath, Pluck extra, PluckOr extra… |
| 27 | race_test.dart | 347 | 22 | 10.7 KB | race test; groups: Race, RaceFirst, RaceMap, RaceWith, RaceUntil, Race extra… |
| 28 | reduce_test.dart | 315 | 19 | 9.5 KB | reduce test; groups: Reduce, ReduceSelect, ReduceMachine, Reduce extra, ReduceSelect extra, ReduceMachine extra… |
| 29 | retry_test.dart | 486 | 26 | 14.5 KB | retry test; groups: Retry, RetryWhen, RetryWithDelay, RetryWithBackoff, RetryUntil, Retry extra… |
| 30 | routing_test.dart | 451 | 29 | 13.8 KB | routing test; groups: Iif, RouteWhen, RouteByKey, PartitionTag, Iif extra, RouteWhen extra… |
| 31 | sample_test.dart | 264 | 16 | 8.3 KB | sample test; groups: Sample, SampleTime, Audit, AuditTime, edges, performance… |
| 32 | scan_test.dart | 279 | 16 | 8.3 KB | scan test; groups: Scan, ScanSeeded, ScanIndexed, Scan extra, ScanSeeded extra, ScanIndexed extra… |
| 33 | share_test.dart | 294 | 19 | 9.0 KB | share test; groups: Share, ShareLatest, ShareReplay, ShareReplayStart, Share extra, ShareLatest extra… |
| 34 | skip_test.dart | 394 | 26 | 11.7 KB | skip test; groups: Skip, SkipWhile, SkipUntil, SkipUntilTime, SkipFirst, SkipLast… |
| 35 | start_with_test.dart | 291 | 21 | 9.2 KB | start with test; groups: StartWith, StartWithValue, StartWithMany, StartWithFactory, StartWith extra, StartWithMany extra… |
| 36 | switch_map_test.dart | 345 | 21 | 10.9 KB | switch map test; groups: SwitchMap, SwitchMapTo, SwitchLatest, SwitchMapState, SwitchMap extra, SwitchMapTo extra… |
| 37 | take_test.dart | 305 | 21 | 9.2 KB | take test; groups: Take, TakeWhile, TakeUntil, TakeUntilTime, Take extra, TakeWhile extra… |
| 38 | tap_test.dart | 376 | 23 | 11.1 KB | tap test; groups: Tap, TapAll, TapWithIndex, TapState, Tap extra, TapAll extra… |
| 39 | throttle_test.dart | 222 | 14 | 7.2 KB | throttle test; groups: Throttle, ThrottleLeading, ThrottleTrailing, Throttle extra, ThrottleLeading extra, ThrottleTrailing extra… |
| 40 | timeout_test.dart | 325 | 19 | 10.6 KB | timeout test; groups: Timeout, TimeoutWithError, TimeoutWithFallback, TimeoutFirst, TimeoutLast, Timeout extra… |
| 41 | window_test.dart | 296 | 17 | 8.7 KB | window test; groups: WindowCount, WindowSize, WindowTime, WindowWhen, WindowCount extra, WindowTime extra… |
| 42 | zip_test.dart | 250 | 14 | 7.1 KB | zip test; groups: ZipWith, Zip, ZipAll, edges, performance, ZipWith extra… |
| **Total** | | **15,368** | **1022** | **476.6 KB** | |

---

## Detailed Test Coverage

Generated from `group(` / `test(` names. Tighten the prose by hand if needed.

### File 1: async_expand_test.dart (24 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 24 |
| AsyncExpand | |
| AsyncExpandConcurrent | |
| AsyncExpandLatest | |
| AsyncExpandExhaust | |
| edges | |
| performance | |
| AsyncExpand extra | |
| AsyncExpandConcurrent extra | |
| AsyncExpandLatest extra | |
| AsyncExpandExhaust extra | |
| composition | |

**Tests**

- flattens inners in source order
- queues a second inner until the first finishes
- null inner is a no-op
- expand exceptions call onError and keep the queue moving
- wrong types call onError and do not enqueue
- emits in completion order
- inner future errors call onError
- drops a stale inner
- stale inner errors are not reported
- ignores a trigger while busy
- accepts a trigger after the inner completes
- empty iterable emits nothing
- string is not flattened as an iterable
- nested list is flattened recursively
- stream events are flattened
- AsyncExpand handles a burst of 200 items
- AsyncExpandConcurrent overlaps 50 delayed inners
- onError is optional when expand throws
- null expand is a no-op
- Future inner is flattened
- wrong types call onError
- wrong types call onError
- wrong types call onError and do not occupy the slot
- AsyncExpand + AsyncExpandExhaust is a chain

### File 2: async_fold_test.dart (20 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 20 |
| AsyncFold snapshot | |
| AsyncFoldLatest snapshot | |
| AsyncFoldExhaust snapshot | |
| edges | |
| performance | |
| AsyncFold extra | |
| AsyncReduce extra | |
| AsyncFoldLatest extra | |
| AsyncFoldExhaust extra | |
| composition | |

**Tests**

- running fold updates snapshot
- queued steps run in order
- errors keep previous acc
- wrong type does not fold
- sync accumulate updates snapshot
- latest committed acc is 20 when 2 cancels 1
- stale errors are not required on onError
- busy drop leaves snapshot at first value
- after idle a second value is accepted
- unused seed stays 7 generation 0
- shared snapshot identity
- 200 sync accumulates stay under 2s
- empty source leaves the seed
- wrong types call onError and skip the queue
- onError is optional when accumulate throws
- uses the first value as the seed
- wrong types call onError
- wrong types call onError
- wrong types call onError
- AsyncFold handle is bindable

### File 3: async_map_test.dart (30 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 30 |
| AsyncMap | |
| AsyncMapSequential | |
| AsyncMapConcurrent | |
| AsyncMapLatest | |
| AsyncMapWithIndex | |
| AsyncMapWithRetry | |
| AsyncMapWithTimeout | |
| AsyncMapWithFallback | |
| edges | |
| performance | |
| AsyncMap extra | |
| AsyncMapSequential extra | |
| AsyncMapConcurrent extra | |
| AsyncMapLatest extra | |
| AsyncMapWithIndex extra | |
| AsyncMapWithRetry extra | |
| AsyncMapWithTimeout extra | |
| AsyncMapWithFallback extra | |
| composition | |

**Tests**

- maps each value in source order
- queues the second map until the first finishes
- map exceptions drop that pulse and continue
- wrong types call onError
- is an alias of AsyncMap
- emits in completion order
- inner errors call onError
- drops a stale projection
- stale errors are not reported
- passes a 0-based index that skips failures
- succeeds after transient failures
- gives up after count retries
- emits when the map finishes in time
- timeout calls onError and drops the value
- emits fallback when the map throws
- does not flatten a list result
- sync mapper still emits through the future path
- AsyncMap handles 200 items
- AsyncMapConcurrent overlaps 50 delayed maps
- onError is optional when mapper throws
- sync mapper still uses the future path
- empty source emits nothing
- is bindable and queues
- wrong types call onError
- wrong types call onError
- wrong types call onError and do not advance index
- wrong types do not run the mapper
- wrong types call onError
- wrong types call onError
- AsyncMap + AsyncMapSequential is a chain

### File 4: buffer_test.dart (24 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 24 |
| BufferCount | |
| BufferWithCount | |
| BufferTime | |
| BufferWhen | |
| BufferWithPredicate | |
| BufferWithTimeAndCount | |
| edges | |
| performance | |
| BufferCount extra | |
| BufferTime extra | |
| BufferWhen extra | |
| BufferWithPredicate extra | |
| composition / performance | |

**Tests**

- emits tumbling lists of size n
- skip slides the window
- wrong types do not fill the buffer
- is an alias of BufferCount
- flushes after the duration
- skips empty windows
- flushes on closer
- skips an empty flush
- closes when test is true and includes the trigger
- includeTrigger false leaves the trigger out
- test exceptions drop that pulse and keep the buffer
- count wins before the timer
- timer wins when count is not reached
- timer restarts after a count flush
- a leftover item is not emitted without a closer
- predicate close on the first item emits a singleton
- BufferCount batches 300 items
- size 1 emits singleton buffers
- wrong types call onError and do not fill the buffer
- wrong types call onError
- wrong types call onError
- predicate throw calls onError
- BufferCount + BufferWithCount is a chain
- BufferCount(1) emits 200 buffers

### File 5: combine_latest_test.dart (13 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 13 |
| CombineLatestWith | |
| CombineLatest | |
| WithLatestFrom | |
| CombineLatest2 | |
| CombineLatestWith extra | |
| CombineLatest extra | |
| WithLatestFrom extra | |
| CombineLatest2 extra | |
| composition | |

**Tests**

- waits until every Cell has a value
- re-emits when the source or an other Cell updates
- combine exceptions call onError
- arms on the gate and combines extra Cells only
- ignores other-Cell updates and pairs only source pulses
- drops source pulses before others have a value
- types the pair as (A, B)
- wrong source type calls onError
- empty others never combines
- combine throw calls onError
- wrong source type calls onError
- combine throw calls onError
- handles stay bindable when chained conceptually

### File 6: concat_map_test.dart (25 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 25 |
| ConcatMap | |
| ConcatMapTo | |
| ConcatMapLatest | |
| ConcatMapFirst | |
| ConcatMap extra | |
| ConcatMapTo extra | |
| ConcatMapLatest extra | |
| ConcatMapFirst extra | |
| composition / performance | |

**Tests**

- expands each trigger in FIFO order
- flattens an Iterable synchronously
- awaits a Future and emits the single value
- null mapper result emits nothing
- wrong payload type is dropped and reported
- mapper exceptions call onError and continue
- marks lineage with ConcatMap
- ignores the trigger payload and repeats the same inner
- queues inners so they do not interleave
- factory exceptions call onError
- ignores stale in-flight inners
- emits the full inner when it is the only trigger
- wrong types are reported
- drops triggers while an inner is running
- accepts a new trigger after the previous inner finishes
- mapper exceptions release the busy latch
- onError is optional when mapper throws
- null inner is a no-op
- wrong types call onError
- inner throw calls onError
- empty list inner emits nothing
- wrong types call onError
- wrong types call onError and do not occupy the slot
- ConcatMap + ConcatMapTo is a chain
- ConcatMap flattens 50 singleton lists

### File 7: concat_test.dart (21 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 21 |
| Concat | |
| ConcatAll | |
| ConcatFirst | |
| ConcatLatest | |
| edges | |
| performance | |
| Concat extra | |
| ConcatAll extra | |
| ConcatFirst extra | |
| ConcatLatest extra | |
| composition | |

**Tests**

- plays static inners in order after the arming pulse
- a second arming pulse is ignored
- inner errors call onError and continue
- queues inners in arrival order
- a slow first inner delays the second
- inner errors call onError and keep the queue moving
- emits only the first item of each inner
- empty inner emits nothing
- emits only the last item of each inner
- empty inner emits nothing
- null inner is a no-op
- a string is not flattened as an iterable
- stream events are concatenated
- ConcatAll flattens 100 short lists
- empty inners are silent
- second arming pulse is ignored
- empty list payload is a no-op
- inner throw calls onError
- takes only the first item of a list
- empty list is a no-op
- ConcatAll + ConcatFirst is a chain

### File 8: debounce_test.dart (21 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 21 |
| Debounce | |
| DebounceLeading | |
| DebounceLeadingOnly | |
| DebounceWith | |
| Debounce extra | |
| DebounceLeading extra | |
| DebounceLeadingOnly extra | |
| DebounceWith extra | |
| composition / performance | |

**Tests**

- emits only the last value after silence
- separate bursts each emit
- emits nothing if silence never arrives before teardown wait is short
- marks lineage with Debounce
- wrong payload types call onError and emit nothing
- emits first immediately then last after silence
- a lone pulse emits only the leading value
- a new burst after silence leads again
- emits only the first value of a burst
- admits a new leading value after the window closes
- uses the latest value duration and cancels the previous timer
- emits the long-wait value when it is left alone
- durationOf exceptions call onError and drop the pulse
- wrong types call onError and do not arm a timer
- onError is optional
- wrong types call onError
- wrong types call onError
- durationOf throw drops the pulse
- wrong types call onError
- Debounce + DebounceLeadingOnly is a chain
- DebounceLeadingOnly keeps first of a burst

### File 9: delay_test.dart (26 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 26 |
| Delay | |
| DelayWithSelector | |
| DelayWhen | |
| DelayLatest | |
| DelayWithTrailing | |
| DelayWithTimeout | |
| edges | |
| performance | |
| Delay extra | |
| DelayWithSelector extra | |
| DelayWhen extra | |
| DelayLatest extra | |
| DelayWithTimeout extra | |
| composition | |
| coverage extras | |

**Tests**

- emits after the duration
- does not drop earlier values
- wrong types call onError and do not schedule
- uses a per-value duration
- selector exceptions drop the pulse
- waits for the notifier future
- notifier errors call onError
- cancels a pending pulse
- is an alias of DelayLatest
- emits when duration is within timeout
- duration longer than timeout calls onError
- zero duration emits on the next microtask-ish tick
- DelayWhen accepts a Duration notifier
- Delay schedules 100 pulses
- Duration.zero still goes through the timer path
- onError is optional on wrong types
- marks lineage with Delay
- zero selector duration emits promptly
- wrong types call onError
- Duration notifier is accepted
- wrong types call onError
- wrong types call onError
- wrong types call onError
- Delay + DelayLatest is a chain
- DelayWithTrailing binds
- DelayWhen Duration notifier

### File 10: distinct_test.dart (23 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 23 |
| DistinctUntilChanged | |
| DistinctUntilKeyChanged | |
| Distinct | |
| DistinctKey | |
| DistinctUntilChanged extra | |
| DistinctUntilKeyChanged extra | |
| Distinct extra | |
| DistinctKey extra | |
| composition / performance | |

**Tests**

- suppresses only consecutive duplicates
- the first value always passes
- uses a custom equals comparator
- equals exceptions call onError and drop the pulse
- wrong types are dropped and do not poison memory
- marks lineage with DistinctUntilChanged
- compares keys and forwards the original payload
- a later return to a previous key still passes
- keyOf exceptions call onError
- drops any previously seen value
- custom equals treats different instances as the same
- first value always passes
- keeps the first payload for each key
- keyOf exceptions drop the pulse
- wrong types call onError and do not set previous
- onError is optional
- wrong types call onError
- keyOf throw drops that pulse
- custom equals treats case as the same
- wrong types call onError
- wrong types call onError
- DistinctUntilChanged + Distinct is a chain
- DistinctUntilChanged handles 200 ints

### File 11: exhaust_map_test.dart (24 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 24 |
| ExhaustMap | |
| ExhaustMapTo | |
| ExhaustAll | |
| ExhaustMapFirst | |
| ExhaustMapLatest | |
| ExhaustMap extra | |
| ExhaustMapTo extra | |
| ExhaustAll extra | |
| ExhaustMapFirst extra | |
| ExhaustMapLatest extra | |
| composition | |

**Tests**

- drops triggers while an inner is running
- admits a new trigger after the previous inner finishes
- flattens an Iterable when admitted
- wrong types call onError and do not occupy the slot
- mapper exceptions release the busy latch
- marks lineage with ExhaustMap
- ignores the payload and drops a second click while running
- runs again after the inner completes
- flattens a synchronous list before the next emitAsync
- ignores a payload that arrives while a Stream is still draining
- flattens a Future payload
- emits only the first inner item of the admitted trigger
- still holds the busy latch until the inner finishes
- runs the last skipped trigger after the current inner ends
- with a single trigger behaves like ExhaustMap
- wrong types do not replace a pending latest value
- onError is optional when mapper throws
- wrong types call onError and do not occupy the slot
- null inner is a no-op
- inner throw calls onError
- empty list is a no-op
- wrong types call onError
- wrong types call onError
- ExhaustMap + ExhaustMapTo is a chain

### File 12: filter_test.dart (31 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 31 |
| Filter | |
| FilterNotNull | |
| FilterType | |
| FilterAllowed / FilterBlocked | |
| FilterByTime | |
| AsyncFilter | |
| AsyncFilterConcurrent | |
| AsyncFilterLatest | |
| AsyncFilterWithRetry | |
| AsyncFilterWithTimeout | |
| AsyncFilterWithFallback | |
| composition | |
| type mismatches | |
| Filter extra | |
| FilterNotNull extra | |
| FilterByTime extra | |
| AsyncFilter extra | |
| AsyncFilterWithTimeout extra | |
| performance extra | |

**Tests**

- keeps values that satisfy the predicate, in order
- drops wrong payload types and reports onError
- predicate exceptions are swallowed and reported
- marks lineage with Filter
- drops null and keeps typed values
- rejects non-S non-null payloads
- narrows heterogeneous streams
- whitelist keeps only listed values
- blacklist drops listed values
- first value is immediate; early follow-ups wait
- Duration.zero is a pass-through
- keeps values whose predicate resolves true, in input order
- predicate errors drop the pulse and call onError
- may emit in completion order rather than input order
- ignores stale in-flight results
- retries until the predicate succeeds
- reports onError after exhausting attempts
- drops pulses that exceed the timeout
- default fallback drops on error
- fallback: true keeps the pulse after an error
- successful true still passes
- Filter + FilterNotNull can be chained with +
- time operators report onError for wrong types
- onError is optional when predicate throws
- empty source is silent
- all-null source is silent
- wrong types call onError
- false predicate drops the pulse
- wrong types call onError
- wrong types call onError
- Filter pass-through handles 200 ints

### File 13: flow_test.dart (81 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 81 |
| FlowHandle / toHandle | |
| Flow create | |
| Flow transform | |
| Flow filter family | |
| Flow flatten / combine | |
| Flow time | |
| Flow collect / control | |
| Flow async map / fold | |
| CellFlowOperators | |
| FlowOperators on FlowHandle | |
| errors | |
| coverage extras Flow facade | |
| flow_core FlowInstruction | |
| Flow facade unused factories emit through | |

**Tests**

- emit wraps a raw value and returns bool
- emitAsync completes
- ingest accepts a Pulse
- Flow.filter handle can be chained further
- of emits the sequence on the first trigger
- fromIterable emits list elements
- range builds a numeric sequence
- repeat emits the same value count times
- fromFuture binds a Future
- deferFuture creates a new future per trigger
- fromStream binds a Stream
- filter keeps matching values
- map projects values
- mapTo emits a constant
- mapWithIndex includes a 0-based index
- mapNotNull drops null projections
- mapWhen projects only when test is true
- pluck reads a map field
- pluckOr uses orElse
- scan folds without a seed
- reduce folds from a seed
- pairwise emits adjacent pairs
- take forwards the first n
- takeWhile stops at the first failure
- skip drops a prefix
- skipWhile opens after the first failure
- skipRepeated drops consecutive duplicates
- distinct suppresses consecutive duplicates
- concatMap expands inners in order
- mergeAll flattens list payloads
- switchMap drops a stale inner
- exhaustMap drops while busy
- mergeWith accepts extra cells
- zipWith pairs by index
- combineLatestWith waits for every side
- withLatestFrom ignores other-only updates
- delay schedules a pulse
- debounce emits after silence
- throttle leading emits first of a burst
- sampleTime ticks the last value
- timeout arms an idle clock
- interval ticks after a trigger
- bufferCount emits tumbling lists
- windowCount emits windows
- groupBy keys values
- partition tags values
- startWith prefixes a seed
- share is a pass-through
- shareReplay keeps a buffer
- retry runs the task
- tap sees each value
- tapAll sees every pulse
- tapWithIndex passes a 0-based index
- iif branches then / else
- asyncMap projects asynchronously
- asyncMapLatest drops stale work
- asyncExpand flattens an iterable
- asyncFold updates a running acc
- cell.filter then handle.map chains
- cell.of starts a sequence
- cell.tap records values
- cell.fromFuture binds a future
- filter + take + tap
- mapTo + startWith
- delay + debounce + throttle stay bindable
- skip + skipWhile + distinct
- concatMap + mergeMap stay bindable
- bufferCount + windowCount + share
- pluckPath + partition
- Flow.filter onError is optional and type mismatches drop
- Flow.map onError swallows projector throws
- Flow tap / distinct / skipRepeated / shareReplay bind
- Flow delayWhen / sampleTime / auditTime / interval bind
- Flow groupBy / partition / bufferTime / windowCount bind
- factory + chain materializes emit / emitAsync / ingest
- FlowInstruction.future factory emits via future callback
- FlowInstruction.chain factory binds
- mapValue / mapValueIf / mapValueOr / mapValues / mapKeys
- asyncFoldLatest / asyncFoldExhaust / asyncReduce / asyncMapConcurrent
- concat / concatAll / concatLatest / merge / zip / race
- takeUntil / skipUntil / skipWhen / sample / audit / timeoutWithFallback

### File 14: fluent_operator_test.dart (37 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 37 |
| CellFlowOperators | |
| FlowOperators transform | |
| FlowOperators async | |
| FlowOperators filter family | |
| FlowOperators flatten / combine | |
| FlowOperators time / collect / control | |
| fluent chain smoke | |

**Tests**

- filter then map via Cell extensions
- of emits on first trigger
- fromIterable binds
- range binds
- repeat binds
- fromFuture binds
- fromStream binds
- tap is side-effect only
- mapTo emits a constant
- mapWithIndex binds
- mapNotNull drops nulls
- mapWhen projects matching values
- pluck reads a map key
- pluckOr uses orElse
- pluckPath binds
- scan binds
- reduce binds
- pairwise binds
- asyncMap binds
- asyncMapLatest binds
- asyncExpand binds
- asyncFold binds
- take / skip / distinct chain
- takeWhile / skipWhile bind
- takeUntil / skipUntil bind
- skipRepeated binds
- concatMap / mergeMap / switchMap / exhaustMap bind
- concatAll / mergeAll bind
- mergeWith / zipWith bind
- combineLatestWith / withLatestFrom bind
- delay / debounce / throttle bind
- sample / sampleTime / auditTime / timeout / interval bind
- bufferCount / bufferTime / windowCount bind
- groupBy / partition bind
- startWith / share / shareReplay bind
- tapAll / tapWithIndex bind
- filter + map + tap + take is one pipeline

### File 15: from_future_test.dart (37 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 37 |
| FromFuture | |
| DeferFuture | |
| FromFutureOr | |
| ConcatFromFuture | |
| MergeFromFuture | |
| SwitchFromFuture | |
| ExhaustFromFuture | |
| FromFutures | |
| FromFuturesInOrder | |
| ForkJoinFutures | |
| RaceFutures | |
| FromFutureWithRetry | |
| FromFutureWithTimeout | |
| FromFutureWithFallback | |
| MapToFuture | |
| emitErrorPulse: false | |
| FromFuture extra | |
| DeferFuture extra | |
| FromFutures extra | |
| FromFutureWithRetry extra | |
| FromFutureWithTimeout extra | |
| MapToFuture extra | |
| composition | |

**Tests**

- emits the future value once after a trigger
- ignores a second trigger
- .value emits the constant
- .error emits type error when emitErrorPulse is true
- timeout produces an error pulse
- starts a new future per trigger
- reports compute errors
- emits a synchronous value immediately
- awaits a Future value
- sync throw becomes an error pulse
- emits in trigger order even if later work is faster
- may emit in completion order
- ignores stale in-flight work
- drops triggers while a compute is in flight
- accepts a new trigger after the previous compute finishes
- emits each future as it completes
- starts only once
- emits in list order, not completion order
- emits a single list when all succeed
- errors if any future fails
- emits the first future to complete
- retries until the compute succeeds
- emits an error pulse after exhausting attempts
- drops a slow compute and reports TimeoutException
- emits fallback when compute throws
- emits the successful value when compute works
- maps a typed payload through a future
- drops a mismatched payload and reports onError
- FromFuture swallows the error pulse
- completed future still emits after arming
- timeout reports TimeoutException
- wrong types do not run create when payload is unused
- empty list is silent
- maxAttempts 1 is a single try
- compute errors call onError
- wrong types call onError
- FromFuture handle is bindable

### File 16: from_stream_test.dart (25 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 25 |
| FromStream | |
| DeferStream | |
| ConcatFromStream | |
| MergeFromStream | |
| SwitchFromStream | |
| MapToStream | |
| edges | |
| performance | |
| FromStream extra | |
| DeferStream extra | |
| ConcatFromStream extra | |
| MergeFromStream extra | |
| SwitchFromStream extra | |
| MapToStream extra | |
| composition | |

**Tests**

- emits every event after the arming pulse
- a second arming pulse does not resubscribe
- stream errors call onError and emit an error pulse
- emitErrorPulse false only calls onError
- creates a new stream on every trigger
- plays streams in trigger order
- a slow first stream delays the second
- wrong payload types call onError
- interleaves overlapping streams
- drops events from the previous stream
- projects each value to a stream and concatenates
- project exceptions call onError
- an empty stream emits nothing
- single-subscription stream can only be armed once
- FromStream emits 200 events
- empty stream is silent after arming
- emitErrorPulse false swallows stream errors
- second arming pulse is ignored
- create exceptions call onError
- non-stream payload is reported
- empty inner is a no-op
- wrong payload types call onError
- wrong types call onError
- project throw is reported
- FromStream handle is bindable

### File 17: group_by_test.dart (23 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 23 |
| Grouped | |
| GroupBy | |
| GroupCollect | |
| GroupByCount | |
| GroupBy extra | |
| GroupCollect extra | |
| GroupByCount extra | |
| composition / performance | |

**Tests**

- equality is by key and value
- tags each value with its key
- keyOf exceptions drop the pulse and keep going
- wrong types call onError and do not emit
- builds a running map after every pulse
- emitted maps are copies so later pulses do not mutate them
- reuses a caller-supplied groups map
- keyOf exceptions do not insert a group
- wrong types call onError and leave groups empty
- emits a group only when it reaches size
- clears a group after it is emitted
- independent keys fill in parallel
- keyOf exceptions drop the pulse and do not fill a bucket
- wrong types call onError
- wrong types call onError
- onError is optional
- empty source leaves groups empty
- wrong types do not mutate groups
- shared map is updated in place
- size 1 emits every value as a singleton window
- wrong types call onError
- GroupBy + GroupCollect is a chain
- GroupBy tags 200 ints

### File 18: instruction_demo_test.dart (39 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 39 |
| instruction demo mains emit through bodies | |

**Tests**

- tap
- routing
- of
- delay
- partition
- map
- merge
- skip
- start_with
- reduce
- take
- retry
- timeout
- sample
- throttle
- share
- pluck
- group_by
- scan
- filter
- distinct
- buffer
- window
- zip
- pairwise
- concat
- concat_map
- merge_map
- switch_map
- exhaust_map
- async_map
- async_expand
- async_fold
- combine_latest
- debounce
- interval
- from_stream
- race
- from_future

### File 19: interval_test.dart (19 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 19 |
| Interval | |
| IntervalWithValue | |
| IntervalWithState | |
| TimerPulse | |
| Interval extra | |
| IntervalWithValue extra | |
| IntervalWithState extra | |
| TimerPulse extra | |
| composition | |

**Tests**

- emits 0, 1, 2 after the first period, then stops
- a second source pulse does not restart by default
- resetOnSource restarts the counter
- maxTicks 0 emits nothing
- emits a constant value
- maps the tick index
- valueOf exceptions call onError and stop the clock
- threads state across ticks
- next exceptions call onError and stop the clock
- emits once after the delay
- a second source pulse does not fire again
- valueOf exceptions call onError
- maxTicks 0 never ticks
- second pulse is ignored unless resetOnSource
- maxTicks 1 emits a single value
- next throw stops the clock
- valueOf throw calls onError
- second pulse is ignored
- Interval handle is bindable

### File 20: map_test.dart (35 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 35 |
| MapValue | |
| MapTo | |
| MapWithIndex | |
| MapNotNull | |
| MapWhen | |
| MapValueIf | |
| MapValueOr | |
| MapValues | |
| MapKeys | |
| composition / performance | |
| coverage extras | |

**Tests**

- projects each typed payload
- project exceptions drop the pulse
- wrong types call onError
- empty source emits nothing
- zero and negative values still project
- can change the payload type
- onError is optional when project throws
- emits the constant for every typed pulse
- wrong types do not emit the constant
- includes a 0-based index that skips bad types
- project exceptions drop the pulse and do not advance index
- drops null projections
- project exceptions drop the pulse
- projects only matching values
- test exceptions drop the pulse
- project exceptions drop only that pulse
- wrong types call onError
- is MapWhen under the MapValue name
- emits the projection when it succeeds
- uses orElse when project throws
- orElse throw drops the pulse
- orElse receives the original value and error
- projects each map value
- wrong payload types call onError
- project throw drops the map
- empty map stays empty
- projects each map key
- project throw drops the map
- wrong type calls onError
- MapValue + MapTo is a chain
- MapValue handles 200 ints
- MapValueOr uses orElse on throw
- MapValues projects map values
- MapKeys projects map keys
- MapValues wrong type calls onError

### File 21: merge_map_test.dart (20 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 20 |
| MergeMap | |
| MergeMapTo | |
| MergeScan | |
| MergeMap extra | |
| MergeMapTo extra | |
| MergeScan extra | |
| composition / performance | |

**Tests**

- emits in completion order
- concurrency 1 serializes inners
- flattens an Iterable
- mapper exceptions call onError and keep going
- wrong types call onError and do not enqueue
- inner future errors call onError
- starts the same inner on every trigger
- factory exceptions call onError
- emits a running total
- flattens an inner list and uses the last A as the next seed
- accumulate exceptions call onError and keep the previous seed
- wrong types call onError and do not touch the seed
- onError is optional when mapper throws
- wrong types call onError
- concurrency 1 serializes inners
- inner throw calls onError
- wrong types call onError
- accumulate throw calls onError
- MergeMap + MergeMapTo is a chain
- MergeMap flattens 50 singleton lists

### File 22: merge_test.dart (19 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 19 |
| MergeWith | |
| Merge | |
| MergeAll | |
| MergeWith extra | |
| Merge extra | |
| MergeAll extra | |
| composition / performance | |
| coverage extras | |

**Tests**

- forwards the source and pulses from others after arming
- pulses on others before arming are not forwarded
- wrong types on the source call onError
- does not forward the arming pulse
- forwardSource keeps the arming pulse when it matches S
- flattens list payloads concurrently
- overlapping delayed streams can interleave
- inner exceptions call onError
- forwardSource false keeps only others
- wrong type on the source calls onError
- empty others still forwards the source
- default does not forward the arming pulse
- flattens a list payload
- skips non-T items
- Future payload is flattened
- empty list emits nothing
- MergeAll handles 50 short lists
- Merge two static sources binds
- MergeAll Future inner

### File 23: of_test.dart (23 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 23 |
| Of | |
| FromIterable | |
| Range | |
| Repeat | |
| edges | |
| performance | |
| Of extra | |
| FromIterable extra | |
| Range extra | |
| Repeat extra | |
| coverage extras | |

**Tests**

- emits the values once
- ignores a second arming pulse
- emits each element
- iterator exceptions call onError
- emits start for count steps
- honours step
- count 0 emits nothing
- emits the value count times
- Of of an empty list is silent
- Range emits 300 values
- empty list is silent
- marks lineage with Of
- Set emits each element once
- second trigger is ignored
- negative step walks down
- count 0 emits nothing
- second trigger is ignored
- count 0 emits nothing
- default count is one
- second trigger is ignored
- Range step 2
- Repeat count 0 is silent
- FromIterable empty

### File 24: pairwise_test.dart (13 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 13 |
| Pairwise | |
| PairwiseWith | |
| Pairwise extra | |
| PairwiseWith extra | |
| composition / performance | |

**Tests**

- emits adjacent pairs from the second value
- a single value produces no emission
- wrong types do not become previous
- marks lineage with Pairwise
- emits the combined delta
- combine exceptions call onError and still advance previous
- single value never pairs
- wrong types call onError and do not become previous
- onError is optional
- combine throw drops that pair
- wrong types call onError
- Pairwise + PairwiseWith is a chain
- Pairwise emits 199 pairs from 200 ints

### File 25: partition_test.dart (22 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 22 |
| Partition | |
| PartitionMap | |
| PartitionCollect | |
| PartitionOnly | |
| Partition extra | |
| PartitionMap extra | |
| PartitionCollect extra | |
| PartitionOnly extra | |
| composition / performance | |
| coverage extras | |

**Tests**

- tags each value
- test exceptions drop the pulse
- wrong types call onError
- maps each side
- mapper exceptions drop the pulse
- fills both buckets
- test exceptions leave the buckets alone
- keeps the matching side
- matched false keeps the other side
- wrong types call onError
- marks lineage with Partition
- wrong types call onError
- thenMap throw drops the pulse
- wrong types do not fill buckets
- empty source leaves buckets empty
- wrong types call onError
- predicate throw drops the pulse
- marks lineage with PartitionOnly
- Partition + PartitionOnly is a chain
- Partition handles 200 ints
- PartitionCollect fills both lists
- PartitionOnly matched false drops

### File 26: pluck_test.dart (24 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 24 |
| Pluck | |
| PluckOr | |
| PluckAll | |
| PluckPath | |
| Pluck extra | |
| PluckOr extra | |
| PluckAll extra | |
| PluckPath extra | |
| composition / performance | |

**Tests**

- reads a map field
- reads a list index
- wrong field type calls onError
- unsupported source type calls onError
- out of range list index calls onError
- uses orElse when the key is missing
- uses orElse when the source cannot be plucked
- collects the requested keys
- useOrElse fills holes
- walks a nested map
- broken path calls onError
- useOrElse returns the default on a broken path
- reads a list index
- out of range list index calls onError
- onError is optional
- marks lineage with Pluck
- uses orElse when the source cannot be plucked
- wrong plucked type uses orElse
- omits missing keys when useOrElse is false
- unsupported source type calls onError
- empty path returns the payload when typed
- onError is optional on a broken path
- Pluck + PluckOr is a chain
- Pluck handles 200 maps

### File 27: race_test.dart (22 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 22 |
| Race | |
| RaceFirst | |
| RaceMap | |
| RaceWith | |
| RaceUntil | |
| Race extra | |
| RaceFirst extra | |
| RaceMap extra | |
| RaceWith extra | |
| RaceUntil extra | |
| composition | |

**Tests**

- emits the first future to complete
- a raw value beats a delayed future
- starts only on the first trigger
- marks lineage with Race
- emits only the first value of the winning stream
- a completed future beats a delayed stream
- races competitors derived from the payload
- a later trigger invalidates an in-flight race
- wrong payload types call onError
- mapper exceptions call onError
- side competitor can win
- mapped source can win
- emits the value when it beats the timeout
- emits a TimeoutException error pulse when the timer wins
- swallows the error pulse when emitErrorPulse is false
- empty competitors are silent
- second arming pulse is ignored
- empty competitors are silent
- wrong types call onError
- wrong types call onError
- wrong types call onError
- Race handle is bindable

### File 28: reduce_test.dart (19 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 19 |
| Reduce | |
| ReduceSelect | |
| ReduceMachine | |
| Reduce extra | |
| ReduceSelect extra | |
| ReduceMachine extra | |
| composition / performance | |
| coverage extras | |

**Tests**

- folds from the seed and exposes the snapshot
- reduce exceptions call onError and keep the previous acc
- wrong types do not touch the snapshot
- projects a field
- select exceptions call onError
- applies transitions
- emitIfUnchanged false drops no-op transitions
- transition exceptions call onError and keep the previous acc
- empty source leaves the seed
- shared snapshot is updated in place
- onError is optional when reduce throws
- wrong types call onError
- marks lineage with ReduceSelect
- wrong types call onError and keep the acc
- emitIfUnchanged false drops a no-op transition
- Reduce + ReduceSelect is a chain
- Reduce folds 200 ints
- ReduceSelect projects then folds
- ReduceMachine applies events

### File 29: retry_test.dart (26 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 26 |
| Retry | |
| RetryWhen | |
| RetryWithDelay | |
| RetryWithBackoff | |
| RetryUntil | |
| Retry extra | |
| RetryWhen extra | |
| RetryWithDelay extra | |
| RetryWithBackoff extra | |
| RetryUntil extra | |
| performance | |

**Tests**

- succeeds after transient failures
- emits an error pulse when retries are exhausted
- swallows the error pulse when emitErrorPulse is false
- wrong types call onError and do not run the task
- retries while shouldRetry is true
- stops when shouldRetry is false
- shouldRetry exceptions stop retrying
- succeeds after the pause
- succeeds after backoff
- gives up after count retries
- stops when until returns true
- retries while until is false then succeeds
- until exceptions stop retrying
- count 0 is a single attempt
- async task is awaited
- marks lineage with Retry
- uses the trigger payload
- wrong types do not run the task
- async shouldRetry can delay the next attempt
- wrong types call onError
- exhausts and can swallow the error pulse
- wrong types call onError
- maxDelay caps the wait
- wrong types call onError
- maxAttempts stops a never-until loop
- Retry first-try success on 50 triggers

### File 30: routing_test.dart (29 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 29 |
| Iif | |
| RouteWhen | |
| RouteByKey | |
| PartitionTag | |
| Iif extra | |
| RouteWhen extra | |
| RouteByKey extra | |
| PartitionTag extra | |
| composition / performance | |
| coverage extras | |

**Tests**

- uses thenMap when the predicate is true
- uses elseMap when the predicate is false
- predicate exceptions call onError
- wrong types are dropped
- uses the first matching case
- drops the pulse when nothing matches and orElse is omitted
- case exceptions call onError
- dispatches through the handler table
- orElse handles an unknown key
- unknown keys are dropped when orElse is omitted
- keyOf exceptions call onError
- tags each value with the predicate result
- predicate exceptions call onError
- thenMap exceptions drop the pulse
- elseMap exceptions drop the pulse
- wrong types call onError
- onError is optional
- orElse handles no match
- first matching case wins over a later match
- empty cases with no orElse drop
- wrong types call onError
- handler throw drops the pulse
- wrong types call onError
- wrong types call onError
- Iif + PartitionTag is a chain
- Iif handles 200 ints
- RouteByKey orElse when key missing
- PartitionTag tags both sides
- Iif false branch

### File 31: sample_test.dart (16 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 16 |
| Sample | |
| SampleTime | |
| Audit | |
| AuditTime | |
| edges | |
| performance | |
| Sample extra | |
| SampleTime extra | |
| Audit extra | |
| AuditTime extra | |
| composition | |

**Tests**

- emits the latest pending value on notifier
- a notifier with nothing pending is ignored
- wrong types do not become pending
- emits the latest value on the period
- skips empty periods
- emits after the next notifier
- notifier without a pending source is ignored
- emits the latest value after the quiet window
- Sample does not emit before the first source value
- SampleTime handles a burst of 100 values
- wrong types do not become the pending sample
- notifier with no pending source is silent
- wrong types call onError
- wrong types call onError
- wrong types call onError
- SampleTime + AuditTime is a chain

### File 32: scan_test.dart (16 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 16 |
| Scan | |
| ScanSeeded | |
| ScanIndexed | |
| Scan extra | |
| ScanSeeded extra | |
| ScanIndexed extra | |
| composition / performance | |

**Tests**

- uses the first value as seed and starts emitting on the second
- a single value produces no emission
- accumulate exceptions call onError and keep the previous acc
- wrong types do not become the seed
- marks lineage with Scan
- emits from the first value using the seed
- can accumulate into a different type than the source
- passes a zero-based index
- wrong types do not advance the index
- onError is optional when accumulate throws
- empty source emits nothing
- wrong types call onError and keep the seed
- accumulate throw drops that pulse
- wrong types do not advance the index
- ScanSeeded + ScanIndexed is a chain
- ScanSeeded folds 200 ints

### File 33: share_test.dart (19 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 19 |
| Share | |
| ShareLatest | |
| ShareReplay | |
| ShareReplayStart | |
| Share extra | |
| ShareLatest extra | |
| ShareReplay extra | |
| ShareReplayStart extra | |
| composition / performance | |

**Tests**

- passes values through and counts them
- wrong types call onError and do not increment seen
- keeps the last value
- wrong types do not overwrite latest
- keeps a sliding window
- shares a buffer instance
- replays the buffer then the live value
- includeCurrent false replays only the buffer
- wrong types call onError and do not replay
- seen stays 0 with no pulses
- onError is optional
- shared buffer is updated in place
- wrong types do not overwrite latest
- size below 1 is clamped
- wrong types do not enter the buffer
- empty buffer just forwards the first pulse
- wrong types call onError
- Share + ShareLatest is a chain
- Share counts 200 ints

### File 34: skip_test.dart (26 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 26 |
| Skip | |
| SkipWhile | |
| SkipUntil | |
| SkipUntilTime | |
| SkipFirst | |
| SkipLast | |
| SkipRepeated | |
| SkipWhen | |
| Skip extra | |
| SkipWhile extra | |
| SkipUntil extra | |
| SkipUntilTime extra | |
| SkipFirst extra | |
| SkipLast extra | |
| SkipRepeated extra | |
| composition / performance | |
| coverage extras | |

**Tests**

- drops the first n values
- wrong types do not consume the quota
- drops a prefix then forwards the rest
- stays closed after the first failure even if later values match
- opens when the notifier emits
- drops until the window opens
- drops only the first value
- emits values that have left the trailing buffer
- SkipLast(0) is a pass-through
- drops consecutive duplicates
- uses a custom equals
- drops every matching value, not only a prefix
- predicate exceptions drop the pulse
- Skip(0) is a pass-through
- marks lineage with Skip
- onError is optional on wrong types
- wrong types call onError and do not open the gate
- wrong types do not pass while closed
- wrong types call onError
- wrong types do not consume the first slot
- wrong types do not enter the trailing buffer
- wrong types call onError
- Skip + SkipWhen is a chain
- Skip(0) forwards 200 ints
- SkipUntilTime opens after window
- SkipWhen drops matches

### File 35: start_with_test.dart (21 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 21 |
| StartWith | |
| StartWithValue | |
| StartWithMany | |
| StartWithFactory | |
| StartWith extra | |
| StartWithMany extra | |
| StartWithFactory extra | |
| composition / performance | |
| coverage extras | |

**Tests**

- emits the seed then the source payloads
- replaceFirst swaps the first payload for the seed
- wrong types call onError and do not consume first
- is an alias of StartWith
- emits every seed then the source
- replaceFirst drops the first source payload
- an empty prefix is a pass-through after first pulse
- wrong types call onError and do not emit the prefix
- builds the prefix from the first payload
- seedOf exceptions call onError and drop the first pulse
- replaceFirst drops the first source payload
- wrong types call onError and do not consume first
- onError is optional
- empty prefix is a pass-through after first pulse
- wrong types call onError and do not emit the prefix
- seedOf exceptions drop the first pulse
- wrong types call onError
- StartWith + StartWithValue is a chain
- StartWith prefixes 200 follow-up values
- StartWithFactory builds prefix
- StartWithMany empty prefix

### File 36: switch_map_test.dart (21 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 21 |
| SwitchMap | |
| SwitchMapTo | |
| SwitchLatest | |
| SwitchMapState | |
| SwitchMap extra | |
| SwitchMapTo extra | |
| SwitchLatest extra | |
| SwitchMapState extra | |
| composition | |

**Tests**

- drops a stale inner when a new trigger arrives
- emits the full inner when it is the only trigger
- wrong types call onError
- mapper exceptions call onError only for the current generation
- inner future errors call onError
- stale inner errors are not reported
- cancels the previous inner of the same factory
- factory exceptions call onError
- switches away from a slow inner payload
- inner stream errors call onError
- records generation and last trigger on the snapshot
- mapper exceptions call onError
- wrong types do not bump generation
- onError is optional when mapper throws
- wrong types call onError
- null inner is a no-op
- inner throw calls onError
- empty list is a no-op
- wrong types call onError
- shared snapshot is updated
- SwitchMap + SwitchMapTo is a chain

### File 37: take_test.dart (21 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 21 |
| Take | |
| TakeWhile | |
| TakeUntil | |
| TakeUntilTime | |
| Take extra | |
| TakeWhile extra | |
| TakeUntil extra | |
| TakeUntilTime extra | |
| composition / performance | |
| coverage extras | |

**Tests**

- forwards only the first n values
- Take(0) emits nothing
- wrong types do not consume the quota
- marks lineage with Take
- stops before the first failing value
- inclusive emits the failing value then closes
- predicate exceptions close the gate
- closes when the notifier emits
- a notifier that already fired keeps the gate closed
- forwards until the window closes
- Take(0) emits nothing
- negative count is treated as zero
- onError is optional on wrong types
- inclusive emits the failing value then closes
- wrong types call onError
- wrong types call onError while open
- wrong types call onError
- Take + TakeWhile is a chain
- Take forwards 200 then drops
- TakeUntilTime closes after window
- TakeWhile inclusive

### File 38: tap_test.dart (23 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 23 |
| Tap | |
| TapAll | |
| TapWithIndex | |
| TapState | |
| Tap extra | |
| TapAll extra | |
| TapWithIndex extra | |
| TapState extra | |
| composition / performance | |
| coverage extras | |

**Tests**

- forwards values after the side effect
- side-effect exceptions drop the pulse
- wrong types call onError and skip the tap
- sees every pulse including wrong types
- onPulse exceptions drop the pulse
- passes a 0-based index that skips bad types
- callback exceptions drop the pulse and do not advance index
- folds a snapshot without changing payloads
- next exceptions drop the pulse and keep the snapshot
- empty source taps nothing
- onError is optional when the tap throws
- null payload of a nullable type still taps
- marks lineage with TapAll
- forwards after a successful onPulse
- marks lineage with TapWithIndex
- index restarts per operator instance
- shared snapshot is updated in place
- wrong types do not change the snapshot
- zero values leave the seed
- Tap + TapAll stays a chain
- Tap handles 200 ints
- TapState next throw calls onError
- TapAll onPulse throw is dropped

### File 39: throttle_test.dart (14 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 14 |
| Throttle | |
| ThrottleLeading | |
| ThrottleTrailing | |
| Throttle extra | |
| ThrottleLeading extra | |
| ThrottleTrailing extra | |
| composition / performance | |

**Tests**

- emits leading immediately and trailing at window close
- a lone pulse emits only the leading value
- a new window opens after the duration
- wrong types call onError and do not open a window
- emits only the first value of a burst
- emits only the last value when the window closes
- a lone pulse still emits as trailing
- wrong types call onError and do not open a window
- onError is optional
- Duration.zero still binds
- wrong types call onError
- wrong types call onError
- Throttle + ThrottleLeading is a chain
- ThrottleLeading keeps first of 200 in one window

### File 40: timeout_test.dart (19 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 19 |
| Timeout | |
| TimeoutWithError | |
| TimeoutWithFallback | |
| TimeoutFirst | |
| TimeoutLast | |
| Timeout extra | |
| TimeoutWithError extra | |
| TimeoutWithFallback extra | |
| TimeoutFirst extra | |
| composition | |
| coverage extras | |

**Tests**

- forwards values and errors after idle
- a later pulse resets the idle timer
- emitErrorPulse false only calls onError
- wrong types call onError and do not start the clock
- emits the custom error payload
- errorOf exceptions call onError and skip the pulse
- emits the fallback after idle
- once true emits fallback only one time
- does not reset the deadline on later pulses
- is an idle timeout alias
- resetOnPulse false is a first-gap deadline
- wrong types call onError and do not start the clock
- errorOf exceptions skip the pulse
- wrong types call onError
- wrong types call onError
- wrong types call onError
- Timeout + TimeoutLast is a chain
- TimeoutWithFallback once
- TimeoutFirst does not reset

### File 41: window_test.dart (17 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 17 |
| WindowCount | |
| WindowSize | |
| WindowTime | |
| WindowWhen | |
| WindowCount extra | |
| WindowTime extra | |
| WindowWhen extra | |
| composition / performance | |

**Tests**

- emits tumbling windows of size n
- overlapping skip emits sliding windows
- wrong types do not count toward the window
- is an alias of WindowCount
- flushes the buffer when the duration elapses
- skips empty windows by default
- wrong types are not buffered
- flushes when the closer emits
- skips an empty flush
- wrong types are not buffered
- size 1 emits singleton windows
- wrong types call onError and do not fill the buffer
- wrong types call onError
- wrong types call onError
- closer with empty buffer is silent unless emitEmpty
- WindowCount + WindowSize is a chain
- WindowCount(1) emits 200 windows

### File 42: zip_test.dart (14 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 14 |
| ZipWith | |
| Zip | |
| ZipAll | |
| edges | |
| performance | |
| ZipWith extra | |
| Zip extra | |
| ZipAll extra | |
| composition | |

**Tests**

- pairs by index, not by latest
- queues extra values on one side
- project exceptions drop that pair
- arms then zips extra cells
- packs width items from one source
- wrong types call onError
- an unmatched leftover is not emitted
- ZipAll packs 200 items
- empty others zips the source alone
- project throw calls onError
- empty sources never emit
- wrong types call onError
- width 1 emits each value as a singleton row
- ZipAll handle is bindable

---

## Runtime Verification Status

Working directory: `packages/cell_flow` (package-relative; host paths omitted).

If tests are named `test_*.dart` instead of `*_test.dart`, `dart test` with
no path finds nothing. Pass explicit files:

```bash
dart pub get
dart test \
  test/async_expand_test.dart \
  test/async_fold_test.dart \
  test/async_map_test.dart \
  test/buffer_test.dart \
  test/combine_latest_test.dart \
  test/concat_map_test.dart \
  test/concat_test.dart \
  test/debounce_test.dart \
  test/delay_test.dart \
  test/distinct_test.dart \
  test/exhaust_map_test.dart \
  test/filter_test.dart \
  test/flow_test.dart \
  test/fluent_operator_test.dart \
  test/from_future_test.dart \
  test/from_stream_test.dart \
  test/group_by_test.dart \
  test/instruction_demo_test.dart \
  test/interval_test.dart \
  test/map_test.dart \
  test/merge_map_test.dart \
  test/merge_test.dart \
  test/of_test.dart \
  test/pairwise_test.dart \
  test/partition_test.dart \
  test/pluck_test.dart \
  test/race_test.dart \
  test/reduce_test.dart \
  test/retry_test.dart \
  test/routing_test.dart \
  test/sample_test.dart \
  test/scan_test.dart \
  test/share_test.dart \
  test/skip_test.dart \
  test/start_with_test.dart \
  test/switch_map_test.dart \
  test/take_test.dart \
  test/tap_test.dart \
  test/throttle_test.dart \
  test/timeout_test.dart \
  test/window_test.dart \
  test/zip_test.dart
```

### Line Coverage (`lib/`)

**Overall: 5557 / 5768 lines = 96.3%**

| File | Hit | Found | Line % |
|------|----:|------:|-------:|
| `lib/src/instruction/sample.dart` | 106 | 106 | 100.0 |
| `lib/src/instruction/take.dart` | 95 | 95 | 100.0 |
| `lib/src/instruction/tap.dart` | 90 | 90 | 100.0 |
| `lib/src/instruction/map.dart` | 164 | 165 | 99.4 |
| `lib/src/instruction/debounce.dart` | 141 | 142 | 99.3 |
| `lib/src/instruction/window.dart` | 113 | 114 | 99.1 |
| `lib/src/instruction/share.dart` | 106 | 107 | 99.1 |
| `lib/src/instruction/routing.dart` | 103 | 104 | 99.0 |
| `lib/src/instruction/reduce.dart` | 83 | 84 | 98.8 |
| `lib/src/instruction/start_with.dart` | 80 | 81 | 98.8 |
| `lib/src/instruction/skip.dart` | 157 | 159 | 98.7 |
| `lib/src/instruction/retry.dart` | 156 | 158 | 98.7 |
| `lib/src/instruction/pairwise.dart` | 64 | 65 | 98.5 |
| `lib/src/instruction/async_map.dart` | 240 | 244 | 98.4 |
| `lib/src/instruction/buffer.dart` | 167 | 170 | 98.2 |
| `lib/src/instruction/zip.dart` | 107 | 109 | 98.2 |
| `lib/src/instruction/concat_map.dart` | 152 | 155 | 98.1 |
| `lib/src/instruction/interval.dart` | 152 | 155 | 98.1 |
| `lib/src/instruction/async_fold.dart` | 151 | 154 | 98.1 |
| `lib/src/instruction/combine_latest.dart` | 149 | 152 | 98.0 |
| `lib/src/instruction/throttle.dart` | 92 | 94 | 97.9 |
| `lib/src/instruction/scan.dart` | 81 | 83 | 97.6 |
| `lib/src/instruction/switch_map.dart` | 162 | 166 | 97.6 |
| `lib/src/instruction/delay.dart` | 116 | 119 | 97.5 |
| `lib/src/instruction/exhaust_map.dart` | 189 | 194 | 97.4 |
| `lib/src/instruction/timeout.dart` | 151 | 155 | 97.4 |
| `lib/src/instruction/distinct.dart` | 110 | 113 | 97.3 |
| `lib/src/instruction/partition.dart` | 106 | 109 | 97.2 |
| `lib/src/instruction/concat.dart` | 126 | 130 | 96.9 |
| `lib/src/instruction/group_by.dart` | 92 | 95 | 96.8 |
| `lib/src/instruction/from_future.dart` | 347 | 359 | 96.7 |
| `lib/src/instruction/filter.dart` | 206 | 214 | 96.3 |
| `lib/src/instruction/async_expand.dart` | 153 | 159 | 96.2 |
| `lib/src/instruction/pluck.dart` | 89 | 93 | 95.7 |
| `lib/src/instruction/of.dart` | 73 | 77 | 94.8 |
| `lib/src/instruction/from_stream.dart` | 153 | 162 | 94.4 |
| `lib/src/instruction/merge_map.dart` | 120 | 128 | 93.8 |
| `lib/src/instruction/race.dart` | 197 | 211 | 93.4 |
| `lib/src/fluent_operator.dart` | 121 | 132 | 91.7 |
| `lib/src/flow_core.dart` | 24 | 27 | 88.9 |
| `lib/src/instruction/merge.dart` | 81 | 97 | 83.5 |
| `lib/src/flow.dart` | 192 | 242 | 79.3 |

---

## Recommendations

1. Keep this report generated — do not hand-count `test(`.
2. CI should pass the explicit file list below (includes `instruction_demo_test.dart`) or a `dart_test.yaml`.
3. Demo `main()` tests in `instruction_demo_test.dart` exist for `lib/` line coverage; contract behaviour lives in the per-operator `*_test.dart` files.
4. Remaining coverage holes are the `Flow` / `flow_core` facades, not the instruction bodies.
5. Add cross-package tests when dependents rely on these contracts.

---

## Appendix: File Locations

```
test/
├── async_expand_test.dart  (24 tests, 11.7 KB, 365 lines)
├── async_fold_test.dart  (20 tests, 11.3 KB, 360 lines)
├── async_map_test.dart  (30 tests, 15.1 KB, 488 lines)
├── buffer_test.dart  (24 tests, 11.5 KB, 398 lines)
├── combine_latest_test.dart  (13 tests, 8.2 KB, 273 lines)
├── concat_map_test.dart  (25 tests, 11.7 KB, 375 lines)
├── concat_test.dart  (21 tests, 8.2 KB, 285 lines)
├── debounce_test.dart  (21 tests, 10.7 KB, 310 lines)
├── delay_test.dart  (26 tests, 12.0 KB, 368 lines)
├── distinct_test.dart  (23 tests, 11.1 KB, 356 lines)
├── exhaust_map_test.dart  (24 tests, 11.8 KB, 368 lines)
├── filter_test.dart  (31 tests, 15.1 KB, 474 lines)
├── flow_test.dart  (81 tests, 37.4 KB, 1,193 lines)
├── fluent_operator_test.dart  (37 tests, 17.0 KB, 520 lines)
├── from_future_test.dart  (37 tests, 18.1 KB, 573 lines)
├── from_stream_test.dart  (25 tests, 11.4 KB, 369 lines)
├── group_by_test.dart  (23 tests, 12.3 KB, 384 lines)
├── instruction_demo_test.dart  (39 tests, 5.5 KB, 102 lines)
├── interval_test.dart  (19 tests, 9.6 KB, 309 lines)
├── map_test.dart  (35 tests, 15.2 KB, 503 lines)
├── merge_map_test.dart  (20 tests, 9.7 KB, 320 lines)
├── merge_test.dart  (19 tests, 9.2 KB, 297 lines)
├── of_test.dart  (23 tests, 7.6 KB, 274 lines)
├── pairwise_test.dart  (13 tests, 6.4 KB, 214 lines)
├── partition_test.dart  (22 tests, 10.2 KB, 340 lines)
├── pluck_test.dart  (24 tests, 8.9 KB, 310 lines)
├── race_test.dart  (22 tests, 10.7 KB, 347 lines)
├── reduce_test.dart  (19 tests, 9.5 KB, 315 lines)
├── retry_test.dart  (26 tests, 14.5 KB, 486 lines)
├── routing_test.dart  (29 tests, 13.8 KB, 451 lines)
├── sample_test.dart  (16 tests, 8.3 KB, 264 lines)
├── scan_test.dart  (16 tests, 8.3 KB, 279 lines)
├── share_test.dart  (19 tests, 9.0 KB, 294 lines)
├── skip_test.dart  (26 tests, 11.7 KB, 394 lines)
├── start_with_test.dart  (21 tests, 9.2 KB, 291 lines)
├── switch_map_test.dart  (21 tests, 10.9 KB, 345 lines)
├── take_test.dart  (21 tests, 9.2 KB, 305 lines)
├── tap_test.dart  (23 tests, 11.1 KB, 376 lines)
├── throttle_test.dart  (14 tests, 7.2 KB, 222 lines)
├── timeout_test.dart  (19 tests, 10.6 KB, 325 lines)
├── window_test.dart  (17 tests, 8.7 KB, 296 lines)
├── zip_test.dart  (14 tests, 7.1 KB, 250 lines)
```

**Total lines of test code:** 15,368

*Generated 2026-09-06 by generate_test_verification.py*
