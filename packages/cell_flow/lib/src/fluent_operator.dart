// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../flow.dart';

/// Fluent wrappers around the authoritative [Flow] static factories.
///
/// Instead of nesting:
/// ```dart
/// Flow.map<int, String>(
///   Flow.filter<int>(source, test: (n) => n > 0).cell,
///   project: (n) => '$n',
/// );
/// ```
/// chain:
/// ```dart
/// source
///     .filter<int>(test: (n) => n > 0)
///     .map<int, String>(project: (n) => '$n');
/// ```
///
/// [CellFlowOperators] starts a pipeline from a [Cell].
/// [FlowOperators] continues from a [FlowHandle] using its `.cell`.
/// Each method delegates to the matching [Flow] factory — behaviour
/// stays in one place.

extension CellFlowOperators on Cell {

  FlowHandle of<T>({required Iterable<T> values}) =>
      Flow.of<T>(this, values: values);

  FlowHandle fromIterable<T>({required Iterable<T> iterable}) =>
      Flow.fromIterable<T>(this, iterable: iterable);

  FlowHandle range({required int start, required int count, int step = 1}) =>
      Flow.range(this, start: start, count: count, step: step);

  FlowHandle repeat<T>({required T value, int count = 1}) =>
      Flow.repeat<T>(this, value: value, count: count);

  FlowHandle fromFuture<S>({
    required Future<S> future,
    Duration? timeout,
    FutureErrorHandler? onError,
    bool emitErrorPulse = true,
  }) =>
      Flow.fromFuture<S>(
        this,
        future: future,
        timeout: timeout,
        onError: onError,
        emitErrorPulse: emitErrorPulse,
      );

  FlowHandle fromStream<S>({
    required Stream<S> stream,
    StreamErrorHandler? onError,
    bool emitErrorPulse = true,
  }) =>
      Flow.fromStream<S>(
        this,
        stream: stream,
        onError: onError,
        emitErrorPulse: emitErrorPulse,
      );

  FlowHandle map<S, T>({
    required T Function(S value) project,
    MapErrorHandler? onError,
  }) =>
      Flow.map<S, T>(this, project: project, onError: onError);

  FlowHandle filter<S>({required bool Function(S value) test}) =>
      Flow.filter<S>(this, test: test);

  FlowHandle tap<S>({
    required void Function(S value) onValue,
    TapErrorHandler? onError,
  }) =>
      Flow.tap<S>(this, onValue: onValue, onError: onError);
}

/// Pipeline continuation on a bound [FlowHandle].
extension FlowOperators on FlowHandle {
  Cell get _src => cell;

  // ── transform ──────────────────────────────────────────────

  FlowHandle map<S, T>({
    required T Function(S value) project,
    MapErrorHandler? onError,
  }) =>
      Flow.map<S, T>(_src, project: project, onError: onError);

  FlowHandle mapTo<S, T>({
    required T value,
    MapErrorHandler? onError,
  }) =>
      Flow.mapTo<S, T>(_src, value: value, onError: onError);

  FlowHandle mapWithIndex<S, T>({
    required T Function(S value, int index) project,
    MapErrorHandler? onError,
  }) =>
      Flow.mapWithIndex<S, T>(_src, project: project, onError: onError);

  FlowHandle mapNotNull<S, T>({
    required T? Function(S value) project,
    MapErrorHandler? onError,
  }) =>
      Flow.mapNotNull<S, T>(_src, project: project, onError: onError);

  FlowHandle mapWhen<S, T>({
    required bool Function(S value) test,
    required T Function(S value) project,
    MapErrorHandler? onError,
  }) =>
      Flow.mapWhen<S, T>(_src, test: test, project: project, onError: onError);

  FlowHandle pluck<T>({required Object key, PluckErrorHandler? onError}) =>
      Flow.pluck<T>(_src, key: key, onError: onError);

  FlowHandle pluckOr<T>({
    required Object key,
    required T orElse,
    PluckErrorHandler? onError,
  }) =>
      Flow.pluckOr<T>(_src, key: key, orElse: orElse, onError: onError);

  FlowHandle pluckPath<T>({
    required Iterable<Object> path,
    T? orElse,
    bool useOrElse = false,
    PluckErrorHandler? onError,
  }) =>
      Flow.pluckPath<T>(
        _src,
        path: path,
        orElse: orElse,
        useOrElse: useOrElse,
        onError: onError,
      );

  FlowHandle scan<S, A>({required A Function(A acc, S value) accumulate}) =>
      Flow.scan<S, A>(_src, accumulate: accumulate);

  FlowHandle reduce<S, A>({
    required A seed,
    required A Function(A acc, S value) accumulate,
  }) =>
      Flow.reduce<S, A>(_src, seed: seed, accumulate: accumulate);

  FlowHandle pairwise<S>() => Flow.pairwise<S>(_src);

  // ── async ──────────────────────────────────────────────────

  FlowHandle asyncMap<S, T>({
    required FutureOr<T> Function(S value) mapper,
    AsyncMapErrorHandler? onError,
  }) =>
      Flow.asyncMap<S, T>(_src, mapper: mapper, onError: onError);

  FlowHandle asyncMapConcurrent<S, T>({
    required FutureOr<T> Function(S value) mapper,
    AsyncMapErrorHandler? onError,
  }) =>
      Flow.asyncMapConcurrent<S, T>(_src, mapper: mapper, onError: onError);

  FlowHandle asyncMapLatest<S, T>({
    required FutureOr<T> Function(S value) mapper,
    AsyncMapErrorHandler? onError,
  }) =>
      Flow.asyncMapLatest<S, T>(_src, mapper: mapper, onError: onError);

  FlowHandle asyncExpand<S, T>({
    required FutureOr<Object?> Function(S value) expand,
    ExpandErrorHandler? onError,
  }) =>
      Flow.asyncExpand<S, T>(_src, expand: expand, onError: onError);

  FlowHandle asyncFold<S, A>({
    required A seed,
    required FutureOr<A> Function(A acc, S value) accumulate,
    FoldSnapshot<A>? snapshot,
    FoldErrorHandler? onError,
  }) =>
      Flow.asyncFold<S, A>(
        _src,
        seed: seed,
        accumulate: accumulate,
        snapshot: snapshot,
        onError: onError,
      );

  // ── filter ─────────────────────────────────────────────────

  FlowHandle filter<S>({required bool Function(S value) test}) =>
      Flow.filter<S>(_src, test: test);

  FlowHandle take<S>({required int count}) => Flow.take<S>(_src, count: count);

  FlowHandle takeWhile<S>({required bool Function(S value) test}) =>
      Flow.takeWhile<S>(_src, test: test);

  FlowHandle takeUntil<S>({required Cell notifier}) =>
      Flow.takeUntil<S>(_src, notifier: notifier);

  FlowHandle skip<S>({required int count}) => Flow.skip<S>(_src, count: count);

  FlowHandle skipWhile<S>({required bool Function(S value) test}) =>
      Flow.skipWhile<S>(_src, test: test);

  FlowHandle skipUntil<S>({required Cell notifier}) =>
      Flow.skipUntil<S>(_src, notifier: notifier);

  FlowHandle skipRepeated<S>() => Flow.skipRepeated<S>(_src);

  FlowHandle distinct<S>() => Flow.distinct<S>(_src);

  // ── flatten ────────────────────────────────────────────────

  FlowHandle concatMap<S, T>({
    required FutureOr<Object?> Function(S value) project,
  }) =>
      Flow.concatMap<S, T>(_src, project: project);

  FlowHandle concatAll<T>() => Flow.concatAll<T>(_src);

  FlowHandle mergeMap<S, T>({
    required FutureOr<Object?> Function(S value) project,
  }) =>
      Flow.mergeMap<S, T>(_src, project: project);

  FlowHandle switchMap<S, T>({
    required FutureOr<Object?> Function(S value) project,
  }) =>
      Flow.switchMap<S, T>(_src, project: project);

  FlowHandle exhaustMap<S, T>({
    required FutureOr<Object?> Function(S value) project,
  }) =>
      Flow.exhaustMap<S, T>(_src, project: project);

  // ── combine ────────────────────────────────────────────────

  FlowHandle mergeWith<T>({required List<Cell> others}) =>
      Flow.mergeWith<T>(_src, others: others);

  FlowHandle mergeAll<T>({MergeErrorHandler? onError}) =>
      Flow.mergeAll<T>(_src, onError: onError);

  FlowHandle zipWith<R>({
    required List<Cell> others,
    R Function(List<Object?> row)? project,
    ZipErrorHandler? onError,
  }) =>
      Flow.zipWith<R>(_src, others: others, project: project, onError: onError);

  FlowHandle combineLatestWith<S, R>({
    required List<Cell> others,
    required R Function(S sourceValue, List<Object?> latest) combine,
    CombineErrorHandler? onError,
  }) =>
      Flow.combineLatestWith<S, R>(
        _src,
        others: others,
        combine: combine,
        onError: onError,
      );

  FlowHandle withLatestFrom<S, R>({
    required List<Cell> others,
    required R Function(S sourceValue, List<Object?> latest) combine,
    CombineErrorHandler? onError,
  }) =>
      Flow.withLatestFrom<S, R>(
        _src,
        others: others,
        combine: combine,
        onError: onError,
      );

  // ── time ───────────────────────────────────────────────────

  FlowHandle delay<S>({
    required Duration duration,
    DelayErrorHandler? onError,
  }) =>
      Flow.delay<S>(_src, duration: duration, onError: onError);

  FlowHandle delayWhen<S>({
    required FutureOr<Object?> Function(S value) when,
    DelayErrorHandler? onError,
  }) =>
      Flow.delayWhen<S>(_src, when: when, onError: onError);

  FlowHandle debounce<S>({required Duration duration}) =>
      Flow.debounce<S>(_src, duration: duration);

  FlowHandle throttle<S>({
    required Duration duration,
    bool leading = true,
    bool trailing = false,
  }) =>
      Flow.throttle<S>(
        _src,
        duration: duration,
        leading: leading,
        trailing: trailing,
      );

  FlowHandle sample<S>({
    required Cell notifier,
    SampleErrorHandler? onError,
  }) =>
      Flow.sample<S>(_src, notifier: notifier, onError: onError);

  FlowHandle sampleTime<S>({
    required Duration period,
    SampleErrorHandler? onError,
  }) =>
      Flow.sampleTime<S>(_src, period: period, onError: onError);

  FlowHandle auditTime<S>({
    required Duration duration,
    SampleErrorHandler? onError,
  }) =>
      Flow.auditTime<S>(_src, duration: duration, onError: onError);

  FlowHandle timeout<S>({
    required Duration duration,
    TimeoutErrorHandler? onError,
    bool emitErrorPulse = true,
  }) =>
      Flow.timeout<S>(
        _src,
        duration: duration,
        onError: onError,
        emitErrorPulse: emitErrorPulse,
      );

  FlowHandle interval({required Duration period}) =>
      Flow.interval(_src, period: period);

  // ── collect ────────────────────────────────────────────────

  FlowHandle bufferCount<S>({
    required int size,
    int? skip,
    BufferErrorHandler? onError,
  }) =>
      Flow.bufferCount<S>(_src, size: size, skip: skip, onError: onError);

  FlowHandle bufferTime<S>({
    required Duration duration,
    bool emitEmpty = false,
    BufferErrorHandler? onError,
  }) =>
      Flow.bufferTime<S>(
        _src,
        duration: duration,
        emitEmpty: emitEmpty,
        onError: onError,
      );

  FlowHandle windowCount<S>({required int size, int? skip}) =>
      Flow.windowCount<S>(_src, size: size, skip: skip);

  FlowHandle groupBy<S, K>({
    required K Function(S value) keyOf,
    GroupErrorHandler? onError,
  }) =>
      Flow.groupBy<S, K>(_src, keyOf: keyOf, onError: onError);

  FlowHandle partition<S>({
    required bool Function(S value) test,
    PartitionErrorHandler? onError,
  }) =>
      Flow.partition<S>(_src, test: test, onError: onError);

  // ── control ────────────────────────────────────────────────

  FlowHandle startWith<S>({required S value, bool replaceFirst = false}) =>
      Flow.startWith<S>(_src, value: value, replaceFirst: replaceFirst);

  FlowHandle share<S>() => Flow.share<S>(_src);

  FlowHandle shareReplay<S>({int size = 1}) =>
      Flow.shareReplay<S>(_src, size: size);

  FlowHandle retry<S, T>({
    required RetryTask<S, T> task,
    int count = 3,
    RetryErrorHandler? onError,
    bool emitErrorPulse = true,
  }) =>
      Flow.retry<S, T>(
        _src,
        task: task,
        count: count,
        onError: onError,
        emitErrorPulse: emitErrorPulse,
      );

  FlowHandle tap<S>({
    required void Function(S value) onValue,
    TapErrorHandler? onError,
  }) =>
      Flow.tap<S>(_src, onValue: onValue, onError: onError);

  FlowHandle tapAll({
    required void Function(Pulse pulse) onPulse,
    TapErrorHandler? onError,
  }) =>
      Flow.tapAll(_src, onPulse: onPulse, onError: onError);

  FlowHandle tapWithIndex<S>({
    required void Function(S value, int index) onValue,
    TapErrorHandler? onError,
  }) =>
      Flow.tapWithIndex<S>(_src, onValue: onValue, onError: onError);
}
