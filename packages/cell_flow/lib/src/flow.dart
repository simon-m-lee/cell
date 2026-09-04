// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../flow.dart';

/// The Transcription Orchestrator for the Cell framework, responsible for
/// converting (transcribing) external stimuli, persistent state, and logic
/// into reactive [Cell] topographies.
///
/// [Flow] is the administrative facade over [FlowInstruction] operators.
/// Each static method constructs the matching instruction and binds it
/// with `.toHandle(source:)`.
///
/// Categories:
/// * **Create** — [of], [fromIterable], [range], [fromFuture], [fromStream]
/// * **Transform** — [map], [pluck], [scan], [reduce], [asyncMap]
/// * **Filter** — [filter], [take], [skip], [distinct]
/// * **Flatten** — [concatMap], [mergeMap], [switchMap], [exhaustMap], [asyncExpand]
/// * **Combine** — [merge], [zip], [combineLatest], [race]
/// * **Time** — [delay], [debounce], [throttle], [sample], [interval], [timeout]
/// * **Collect** — [buffer], [window], [groupBy], [pairwise]
/// * **Control** — [retry], [share], [startWith], [tap], [route]
abstract class Flow extends CellBase {

  // ─────────────────────────────────────────────────────────────
  // Create
  // ─────────────────────────────────────────────────────────────

  /// Emit [values] once when [source] is first pulsed (Rx `of`).
  static FlowHandle of<T>(
    Cell source, {
    required Iterable<T> values,
  }) {
    return Of<T>(values).toHandle(source: source);
  }

  /// Emit each element of [iterable] on the first pulse (Rx `from`).
  static FlowHandle fromIterable<T>(
    Cell source, {
    required Iterable<T> iterable,
  }) {
    return FromIterable<T>(iterable).toHandle(source: source);
  }

  /// Emit [count] integers from [start] (Rx `range`).
  static FlowHandle range(
    Cell source, {
    required int start,
    required int count,
    int step = 1,
  }) {
    return Range(start, count, step: step).toHandle(source: source);
  }

  /// Repeat [value] [count] times on the first pulse.
  static FlowHandle repeat<T>(
    Cell source, {
    required T value,
    int count = 1,
  }) {
    return Repeat<T>(value, count: count).toHandle(source: source);
  }

  /// Bridge a [Future] on the first pulse (Rx `from(Future)`).
  static FlowHandle fromFuture<S>(
    Cell source, {
    required Future<S> future,
    Duration? timeout,
    FutureErrorHandler? onError,
    bool emitErrorPulse = true,
  }) {
    return FromFuture<S>(
      future,
      timeout: timeout,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    ).toHandle(source: source);
  }

  /// Start a new future on every pulse (Rx `defer`).
  static FlowHandle deferFuture<S>(
    Cell source, {
    required Future<S> Function(Pulse trigger) create,
    FutureErrorHandler? onError,
    bool emitErrorPulse = true,
  }) {
    return DeferFuture<S>(
      create,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    ).toHandle(source: source);
  }

  /// Subscribe to [stream] on the first pulse (Rx `from(Stream)`).
  static FlowHandle fromStream<S>(
    Cell source, {
    required Stream<S> stream,
    StreamErrorHandler? onError,
    bool emitErrorPulse = true,
  }) {
    return FromStream<S>(
      stream,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    ).toHandle(source: source);
  }

  /// Create a new stream on every pulse.
  static FlowHandle deferStream<S>(
    Cell source, {
    required Stream<S> Function() create,
    StreamErrorHandler? onError,
    bool emitErrorPulse = true,
  }) {
    return DeferStream<S>(
      create,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    ).toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Transform
  // ─────────────────────────────────────────────────────────────

  /// Project each typed payload (Rx `map`). Named apart from `dart:core` Map.
  static FlowHandle map<S, T>(
    Cell source, {
    required T Function(S value) project,
    MapErrorHandler? onError,
  }) {
    return MapValue<S, T>(project, onError: onError).toHandle(source: source);
  }

  /// Emit the same [value] for every typed pulse (Rx `mapTo`).
  static FlowHandle mapTo<S, T>(
    Cell source, {
    required T value,
    MapErrorHandler? onError,
  }) {
    return MapTo<S, T>(value, onError: onError).toHandle(source: source);
  }

  /// Project with a 0-based index.
  static FlowHandle mapWithIndex<S, T>(
    Cell source, {
    required T Function(S value, int index) project,
    MapErrorHandler? onError,
  }) {
    return MapWithIndex<S, T>(project, onError: onError).toHandle(source: source);
  }

  /// Project and drop null results.
  static FlowHandle mapNotNull<S, T>(
    Cell source, {
    required T? Function(S value) project,
    MapErrorHandler? onError,
  }) {
    return MapNotNull<S, T>(project, onError: onError).toHandle(source: source);
  }

  /// Project only when [test] is true.
  static FlowHandle mapWhen<S, T>(
    Cell source, {
    required bool Function(S value) test,
    required T Function(S value) project,
    MapErrorHandler? onError,
  }) {
    return MapWhen<S, T>(test, project, onError: onError).toHandle(source: source);
  }

  /// Pick `payload[key]` as [T] (Rx `pluck`).
  static FlowHandle pluck<T>(
    Cell source, {
    required Object key,
    PluckErrorHandler? onError,
  }) {
    return Pluck<T>(key, onError: onError).toHandle(source: source);
  }

  /// Pluck with [orElse] when the field is missing.
  static FlowHandle pluckOr<T>(
    Cell source, {
    required Object key,
    required T orElse,
    PluckErrorHandler? onError,
  }) {
    return PluckOr<T>(key, orElse: orElse, onError: onError)
        .toHandle(source: source);
  }

  /// Pluck several keys into a [Map].
  static FlowHandle pluckAll(
    Cell source, {
    required Iterable<Object> keys,
    Object? orElse,
    bool useOrElse = false,
    PluckErrorHandler? onError,
  }) {
    return PluckAll(
      keys,
      orElse: orElse,
      useOrElse: useOrElse,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Walk a nested [path].
  static FlowHandle pluckPath<T>(
    Cell source, {
    required Iterable<Object> path,
    T? orElse,
    bool useOrElse = false,
    PluckErrorHandler? onError,
  }) {
    return PluckPath<T>(
      path,
      orElse: orElse,
      useOrElse: useOrElse,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Running accumulate (Rx `scan`).
  static FlowHandle scan<S, A>(
    Cell source, {
    required A Function(A acc, S value) accumulate,
  }) {
    return Scan<S, A>(accumulate).toHandle(source: source);
  }

  /// Readable running fold (in-memory, not persistent state).
  static FlowHandle reduce<S, A>(
    Cell source, {
    required A seed,
    required A Function(A acc, S value) accumulate,
  }) {
    return Reduce<S, A>(seed, accumulate).toHandle(source: source);
  }

  /// Consecutive pairs `(previous, current)`.
  static FlowHandle pairwise<S>(Cell source) {
    return Pairwise<S>().toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Async transform
  // ─────────────────────────────────────────────────────────────

  /// Map each payload through an async function (queued).
  ///
  /// Use for API calls, DB reads, or heavy work that returns one value.
  static FlowHandle asyncMap<S, T>(
    Cell source, {
    required FutureOr<T> Function(S value) mapper,
    AsyncMapErrorHandler? onError,
  }) {
    return AsyncMap<S, T>(mapper, onError: onError).toHandle(source: source);
  }

  /// Overlapping [asyncMap].
  static FlowHandle asyncMapConcurrent<S, T>(
    Cell source, {
    required FutureOr<T> Function(S value) mapper,
    AsyncMapErrorHandler? onError,
  }) {
    return AsyncMapConcurrent<S, T>(mapper, onError: onError)
        .toHandle(source: source);
  }

  /// Drop in-flight maps when a new pulse arrives.
  static FlowHandle asyncMapLatest<S, T>(
    Cell source, {
    required FutureOr<T> Function(S value) mapper,
    AsyncMapErrorHandler? onError,
  }) {
    return AsyncMapLatest<S, T>(mapper, onError: onError)
        .toHandle(source: source);
  }

  /// Async map with a 0-based index.
  static FlowHandle asyncMapWithIndex<S, T>(
    Cell source, {
    required FutureOr<T> Function(S value, int index) mapper,
    AsyncMapErrorHandler? onError,
  }) {
    return AsyncMapWithIndex<S, T>(mapper, onError: onError)
        .toHandle(source: source);
  }

  /// Retry the mapper up to [count] extra times.
  static FlowHandle asyncMapWithRetry<S, T>(
    Cell source, {
    required FutureOr<T> Function(S value) mapper,
    int count = 3,
    AsyncMapErrorHandler? onError,
  }) {
    return AsyncMapWithRetry<S, T>(mapper, count: count, onError: onError)
        .toHandle(source: source);
  }

  /// Time-box one projection.
  static FlowHandle asyncMapWithTimeout<S, T>(
    Cell source, {
    required FutureOr<T> Function(S value) mapper,
    required Duration duration,
    AsyncMapErrorHandler? onError,
  }) {
    return AsyncMapWithTimeout<S, T>(
      mapper,
      duration: duration,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Emit [fallback] when the mapper throws.
  static FlowHandle asyncMapWithFallback<S, T>(
    Cell source, {
    required FutureOr<T> Function(S value) mapper,
    required T fallback,
    AsyncMapErrorHandler? onError,
  }) {
    return AsyncMapWithFallback<S, T>(
      mapper,
      fallback: fallback,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Flatten an inner sequence per payload (Dart `asyncExpand`).
  static FlowHandle asyncExpand<S, T>(
    Cell source, {
    required FutureOr<Object?> Function(S value) expand,
    ExpandErrorHandler? onError,
  }) {
    return AsyncExpand<S, T>(expand, onError: onError).toHandle(source: source);
  }

  /// Concurrent flatten.
  static FlowHandle asyncExpandConcurrent<S, T>(
    Cell source, {
    required FutureOr<Object?> Function(S value) expand,
    ExpandErrorHandler? onError,
  }) {
    return AsyncExpandConcurrent<S, T>(expand, onError: onError)
        .toHandle(source: source);
  }

  /// Switch flatten — drop the previous inner.
  static FlowHandle asyncExpandLatest<S, T>(
    Cell source, {
    required FutureOr<Object?> Function(S value) expand,
    ExpandErrorHandler? onError,
  }) {
    return AsyncExpandLatest<S, T>(expand, onError: onError)
        .toHandle(source: source);
  }

  /// Exhaust flatten — ignore while busy.
  static FlowHandle asyncExpandExhaust<S, T>(
    Cell source, {
    required FutureOr<Object?> Function(S value) expand,
    ExpandErrorHandler? onError,
  }) {
    return AsyncExpandExhaust<S, T>(expand, onError: onError)
        .toHandle(source: source);
  }

  /// Async running fold (queued).
  static FlowHandle asyncFold<S, A>(
    Cell source, {
    required A seed,
    required FutureOr<A> Function(A acc, S value) accumulate,
    FoldSnapshot<A>? snapshot,
    FoldErrorHandler? onError,
  }) {
    return AsyncFold<S, A>(
      seed,
      accumulate,
      snapshot: snapshot,
      onError: onError,
    ).toHandle(source: source);
  }

  /// First value is the seed; later values accumulate.
  static FlowHandle asyncReduce<S>(
    Cell source, {
    required FutureOr<S> Function(S acc, S value) accumulate,
    FoldErrorHandler? onError,
  }) {
    return AsyncReduce<S>(accumulate, onError: onError).toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Filter
  // ─────────────────────────────────────────────────────────────

  /// Keep typed payloads that pass [test] (Rx `filter`).
  static FlowHandle filter<S>(
    Cell source, {
    required bool Function(S value) test,
  }) {
    return Filter<S>(test).toHandle(source: source);
  }

  /// Take the first [count] values.
  static FlowHandle take<S>(
    Cell source, {
    required int count,
  }) {
    return Take<S>(count).toHandle(source: source);
  }

  /// Take while [test] is true.
  static FlowHandle takeWhile<S>(
    Cell source, {
    required bool Function(S value) test,
  }) {
    return TakeWhile<S>(test).toHandle(source: source);
  }

  /// Take until [notifier] pulses.
  static FlowHandle takeUntil<S>(
    Cell source, {
    required Cell notifier,
  }) {
    return TakeUntil<S>(notifier).toHandle(source: source);
  }

  /// Skip the first [count] values.
  static FlowHandle skip<S>(
    Cell source, {
    required int count,
  }) {
    return Skip<S>(count).toHandle(source: source);
  }

  /// Skip while [test] is true.
  static FlowHandle skipWhile<S>(
    Cell source, {
    required bool Function(S value) test,
  }) {
    return SkipWhile<S>(test).toHandle(source: source);
  }

  /// Skip until [notifier] pulses.
  static FlowHandle skipUntil<S>(
    Cell source, {
    required Cell notifier,
  }) {
    return SkipUntil<S>(notifier).toHandle(source: source);
  }

  /// Skip consecutive duplicates.
  static FlowHandle skipRepeated<S>(Cell source) {
    return SkipRepeated<S>().toHandle(source: source);
  }

  /// Drop values while [test] is true.
  static FlowHandle skipWhen<S>(
    Cell source, {
    required bool Function(S value) test,
  }) {
    return SkipWhen<S>(test).toHandle(source: source);
  }

  /// Distinct consecutive (or global) values.
  static FlowHandle distinct<S>(Cell source) {
    return Distinct<S>().toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Flatten
  // ─────────────────────────────────────────────────────────────

  /// Sequential inner flatten (Rx `concatMap`).
  static FlowHandle concatMap<S, T>(
    Cell source, {
    required FutureOr<Object?> Function(S value) project,
  }) {
    return ConcatMap<S, T>(project).toHandle(source: source);
  }

  /// Play static inners after the first pulse (Rx `concat`).
  static FlowHandle concat<T>(
    Cell source, {
    required Iterable<Object?> inners,
    ConcatErrorHandler? onError,
  }) {
    return Concat<T>(inners, onError: onError).toHandle(source: source);
  }

  /// Each payload is an inner, queued (Rx `concatAll`).
  static FlowHandle concatAll<T>(Cell source) {
    return ConcatAll<T>().toHandle(source: source);
  }

  /// Last item of each inner.
  static FlowHandle concatLatest<T>(Cell source) {
    return ConcatLatest<T>().toHandle(source: source);
  }

  /// Concurrent inner flatten (Rx `mergeMap` / `flatMap`).
  static FlowHandle mergeMap<S, T>(
    Cell source, {
    required FutureOr<Object?> Function(S value) project,
  }) {
    return MergeMap<S, T>(project).toHandle(source: source);
  }

  /// Switch inner flatten (Rx `switchMap`).
  static FlowHandle switchMap<S, T>(
    Cell source, {
    required FutureOr<Object?> Function(S value) project,
  }) {
    return SwitchMap<S, T>(project).toHandle(source: source);
  }

  /// Ignore new inners while one is running (Rx `exhaustMap`).
  static FlowHandle exhaustMap<S, T>(
    Cell source, {
    required FutureOr<Object?> Function(S value) project,
  }) {
    return ExhaustMap<S, T>(project).toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Combine
  // ─────────────────────────────────────────────────────────────

  /// Forward source and [others] (Rx `mergeWith`).
  static FlowHandle mergeWith<T>(
    Cell source, {
    required List<Cell> others,
  }) {
    return MergeWith<T>(others).toHandle(source: source);
  }

  /// Merge extra [sources]; [source] only arms `future`.
  static FlowHandle merge<T>(
    Cell source, {
    required List<Cell> sources,
  }) {
    return Merge<T>(sources).toHandle(source: source);
  }

  /// Payload is an inner to merge (Rx `mergeAll`).
  static FlowHandle mergeAll<T>(
    Cell source, {
    MergeErrorHandler? onError,
  }) {
    return MergeAll<T>(onError: onError).toHandle(source: source);
  }

  /// Zip [source] with [others] by index (Rx `zipWith`).
  static FlowHandle zipWith<R>(
    Cell source, {
    required List<Cell> others,
    R Function(List<Object?> row)? project,
    ZipErrorHandler? onError,
  }) {
    return ZipWith<R>(
      others,
      project: project,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Zip extra [sources]; [source] arms `future`.
  static FlowHandle zip<R>(
    Cell source, {
    required List<Cell> sources,
    R Function(List<Object?> row)? project,
    ZipErrorHandler? onError,
  }) {
    return Zip<R>(
      sources,
      project: project,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Pack [width] source values into a list.
  static FlowHandle zipAll<T>(
    Cell source, {
    required int width,
    ZipErrorHandler? onError,
  }) {
    return ZipAll<T>(width, onError: onError).toHandle(source: source);
  }

  /// Combine latest of [source] and [others].
  static FlowHandle combineLatestWith<S, R>(
    Cell source, {
    required List<Cell> others,
    required R Function(S sourceValue, List<Object?> latest) combine,
    CombineErrorHandler? onError,
  }) {
    return CombineLatestWith<S, R>(
      others,
      combine,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Source pulses carry latest [others] (Rx `withLatestFrom`).
  static FlowHandle withLatestFrom<S, R>(
    Cell source, {
    required List<Cell> others,
    required R Function(S sourceValue, List<Object?> latest) combine,
    CombineErrorHandler? onError,
  }) {
    return WithLatestFrom<S, R>(
      others,
      combine,
      onError: onError,
    ).toHandle(source: source);
  }

  /// First inner to emit wins (Rx `race`).
  static FlowHandle race<T>(
    Cell source, {
    required List<Object?> competitors,
  }) {
    return Race<T>(competitors).toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Time
  // ─────────────────────────────────────────────────────────────

  /// Shift every value by [duration] (Rx `delay`).
  static FlowHandle delay<S>(
    Cell source, {
    required Duration duration,
    DelayErrorHandler? onError,
  }) {
    return Delay<S>(duration, onError: onError).toHandle(source: source);
  }

  /// Per-value delay.
  static FlowHandle delayWithSelector<S>(
    Cell source, {
    required Duration Function(S value) durationOf,
    DelayErrorHandler? onError,
  }) {
    return DelayWithSelector<S>(durationOf, onError: onError)
        .toHandle(source: source);
  }

  /// Wait for [when] before forwarding (Rx `delayWhen`).
  static FlowHandle delayWhen<S>(
    Cell source, {
    required FutureOr<Object?> Function(S value) when,
    DelayErrorHandler? onError,
  }) {
    return DelayWhen<S>(when, onError: onError).toHandle(source: source);
  }

  /// Only the latest value after [duration] (trailing delay).
  static FlowHandle delayLatest<S>(
    Cell source, {
    required Duration duration,
    DelayErrorHandler? onError,
  }) {
    return DelayLatest<S>(duration, onError: onError).toHandle(source: source);
  }

  /// Debounce trailing.
  static FlowHandle debounce<S>(
    Cell source, {
    required Duration duration,
  }) {
    return Debounce<S>(duration).toHandle(source: source);
  }

  /// Throttle with leading / trailing flags.
  static FlowHandle throttle<S>(
    Cell source, {
    required Duration duration,
    bool leading = true,
    bool trailing = false,
  }) {
    return Throttle<S>(
      duration,
      leading: leading,
      trailing: trailing,
    ).toHandle(source: source);
  }

  /// Latest source value when [notifier] pulses.
  static FlowHandle sample<S>(
    Cell source, {
    required Cell notifier,
    SampleErrorHandler? onError,
  }) {
    return Sample<S>(notifier, onError: onError).toHandle(source: source);
  }

  /// Latest source value every [period].
  static FlowHandle sampleTime<S>(
    Cell source, {
    required Duration period,
    SampleErrorHandler? onError,
  }) {
    return SampleTime<S>(period, onError: onError).toHandle(source: source);
  }

  /// After a source value, emit it on the next [notifier] pulse.
  static FlowHandle audit<S>(
    Cell source, {
    required Cell notifier,
    SampleErrorHandler? onError,
  }) {
    return Audit<S>(notifier, onError: onError).toHandle(source: source);
  }

  /// Emit the latest value [duration] after a source move.
  static FlowHandle auditTime<S>(
    Cell source, {
    required Duration duration,
    SampleErrorHandler? onError,
  }) {
    return AuditTime<S>(duration, onError: onError).toHandle(source: source);
  }

  /// Idle timeout after the last pulse.
  static FlowHandle timeout<S>(
    Cell source, {
    required Duration duration,
    TimeoutErrorHandler? onError,
    bool emitErrorPulse = true,
  }) {
    return Timeout<S>(
      duration,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    ).toHandle(source: source);
  }

  /// Timeout with a fallback value.
  static FlowHandle timeoutWithFallback<S>(
    Cell source, {
    required Duration duration,
    required S fallback,
    bool once = false,
  }) {
    return TimeoutWithFallback<S>(
      duration,
      fallback: fallback,
      once: once,
    ).toHandle(source: source);
  }

  /// Periodic ticks after the first pulse.
  static FlowHandle interval(
    Cell source, {
    required Duration period,
  }) {
    return Interval(period).toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Collect
  // ─────────────────────────────────────────────────────────────

  /// Emit a list every [size] items (Rx `bufferCount`).
  static FlowHandle bufferCount<S>(
    Cell source, {
    required int size,
    int? skip,
    BufferErrorHandler? onError,
  }) {
    return BufferCount<S>(size, skip: skip, onError: onError)
        .toHandle(source: source);
  }

  /// Flush every [duration] (Rx `bufferTime`).
  static FlowHandle bufferTime<S>(
    Cell source, {
    required Duration duration,
    bool emitEmpty = false,
    BufferErrorHandler? onError,
  }) {
    return BufferTime<S>(
      duration,
      emitEmpty: emitEmpty,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Flush when [closer] pulses.
  static FlowHandle bufferWhen<S>(
    Cell source, {
    required Cell closer,
    bool emitEmpty = false,
    BufferErrorHandler? onError,
  }) {
    return BufferWhen<S>(
      closer,
      emitEmpty: emitEmpty,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Close the buffer when [test] is true.
  static FlowHandle bufferWithPredicate<S>(
    Cell source, {
    required bool Function(S value) test,
    bool includeTrigger = true,
    BufferErrorHandler? onError,
  }) {
    return BufferWithPredicate<S>(
      test,
      includeTrigger: includeTrigger,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Flush on count **or** duration.
  static FlowHandle bufferWithTimeAndCount<S>(
    Cell source, {
    required Duration duration,
    required int count,
    bool emitEmpty = false,
    BufferErrorHandler? onError,
  }) {
    return BufferWithTimeAndCount<S>(
      duration: duration,
      count: count,
      emitEmpty: emitEmpty,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Window by count (list payload).
  static FlowHandle windowCount<S>(
    Cell source, {
    required int size,
    int? skip,
  }) {
    return WindowCount<S>(size, skip: skip).toHandle(source: source);
  }

  /// Window by time.
  static FlowHandle windowTime<S>(
    Cell source, {
    required Duration duration,
  }) {
    return WindowTime<S>(duration).toHandle(source: source);
  }

  /// Tag each value with [keyOf] (Rx `groupBy` flattened).
  static FlowHandle groupBy<S, K>(
    Cell source, {
    required K Function(S value) keyOf,
    GroupErrorHandler? onError,
  }) {
    return GroupBy<S, K>(keyOf, onError: onError).toHandle(source: source);
  }

  /// Running `Map<K, List<S>>`.
  static FlowHandle groupCollect<S, K>(
    Cell source, {
    required K Function(S value) keyOf,
    Map<K, List<S>>? groups,
    GroupErrorHandler? onError,
  }) {
    return GroupCollect<S, K>(
      keyOf,
      groups: groups,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Emit a group's list when it hits [size].
  static FlowHandle groupByCount<S, K>(
    Cell source, {
    required K Function(S value) keyOf,
    required int size,
    GroupErrorHandler? onError,
  }) {
    return GroupByCount<S, K>(keyOf, size, onError: onError)
        .toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Partition / route
  // ─────────────────────────────────────────────────────────────

  /// Tag each value with whether [test] matched.
  static FlowHandle partition<S>(
    Cell source, {
    required bool Function(S value) test,
    PartitionErrorHandler? onError,
  }) {
    return Partition<S>(test, onError: onError).toHandle(source: source);
  }

  /// Map matched / unmatched with different projectors.
  static FlowHandle partitionMap<S, T>(
    Cell source, {
    required bool Function(S value) test,
    required T Function(S value) thenMap,
    required T Function(S value) elseMap,
    PartitionErrorHandler? onError,
  }) {
    return PartitionMap<S, T>(
      test,
      thenMap: thenMap,
      elseMap: elseMap,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Keep only the matching side.
  static FlowHandle partitionOnly<S>(
    Cell source, {
    required bool Function(S value) test,
    bool matched = true,
    PartitionErrorHandler? onError,
  }) {
    return PartitionOnly<S>(
      test,
      matched: matched,
      onError: onError,
    ).toHandle(source: source);
  }

  /// Boolean dispatch (Rx `iif`).
  static FlowHandle iif<S, T>(
    Cell source, {
    required bool Function(S value) test,
    required T Function(S value) thenMap,
    required T Function(S value) elseMap,
  }) {
    return Iif<S, T>(
      test,
      thenMap: thenMap,
      elseMap: elseMap,
    ).toHandle(source: source);
  }

  // ─────────────────────────────────────────────────────────────
  // Control / multicast / side effect
  // ─────────────────────────────────────────────────────────────

  /// Prefix values on the first pulse (Rx `startWith`).
  static FlowHandle startWith<S>(
    Cell source, {
    required S value,
    bool replaceFirst = false,
  }) {
    return StartWith<S>(value, replaceFirst: replaceFirst)
        .toHandle(source: source);
  }

  /// Share one subscription (Rx `share`).
  static FlowHandle share<S>(Cell source) {
    return Share<S>().toHandle(source: source);
  }

  /// Share with a replay buffer.
  static FlowHandle shareReplay<S>(
    Cell source, {
    int size = 1,
  }) {
    return ShareReplay<S>(size: size).toHandle(source: source);
  }

  /// Retry a failing inner.
  static FlowHandle retry<S, T>(
    Cell source, {
    required RetryTask<S, T> task,
    int count = 3,
    RetryErrorHandler? onError,
    bool emitErrorPulse = true,
  }) {
    return Retry<S, T>(
      task,
      count: count,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    ).toHandle(source: source);
  }

  /// Side effect without changing the value (Rx `tap`).
  static FlowHandle tap<S>(
    Cell source, {
    required void Function(S value) onValue,
    TapErrorHandler? onError,
  }) {
    return Tap<S>(onValue, onError: onError).toHandle(source: source);
  }

  /// Tap every pulse, including wrong types.
  static FlowHandle tapAll(
    Cell source, {
    required void Function(Pulse pulse) onPulse,
    TapErrorHandler? onError,
  }) {
    return TapAll(onPulse, onError: onError).toHandle(source: source);
  }

  /// Tap with a 0-based index.
  static FlowHandle tapWithIndex<S>(
    Cell source, {
    required void Function(S value, int index) onValue,
    TapErrorHandler? onError,
  }) {
    return TapWithIndex<S>(onValue, onError: onError).toHandle(source: source);
  }
}
