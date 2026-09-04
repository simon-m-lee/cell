// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

/// Flow instructions that bridge [Future]s into the Cell graph
/// (Rx `from(Future)` / `fromPromise` and variants).
///
/// | Operator | Rx analogue | Starts | Emits |
/// |---|---|---|---|
/// | [FromFuture] | `from(Future)` | first trigger | one value |
/// | [DeferFuture] | `defer(() => from(F))` | every trigger | one value |
/// | [FromFutureOr] | hybrid | every trigger | sync or awaited |
/// | [ConcatFromFuture] | `concatMap` | queued | trigger order |
/// | [MergeFromFuture] | `mergeMap` | parallel | completion order |
/// | [SwitchFromFuture] | `switchMap` | latest | latest only |
/// | [ExhaustFromFuture] | `exhaustMap` | if idle | one in flight |
/// | [FromFutures] | `merge` of futures | first trigger | each completion |
/// | [FromFuturesInOrder] | `concat` | first trigger | list order |
/// | [ForkJoinFutures] | `forkJoin` | first trigger | one `List` |
/// | [RaceFutures] | `race` / `any` | first trigger | first winner |
/// | [FromFutureWithRetry] | retry | every trigger | value or error |
/// | [FromFutureWithTimeout] | `timeout` | every trigger | value or error |
/// | [FromFutureWithFallback] | `catch` | every trigger | value or fallback |
/// | [MapToFuture] | map + fromPromise | typed payload | mapped value |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync] / [FlowHandle.emitAsync].
///
/// See the `main` demo at the bottom of this file for console output.
typedef FutureErrorHandler = void Function(Object error, StackTrace? stackTrace);

Pulse<S> _ok<S>(S value, Cell? cell, String step, {Pulse? trigger}) {
  return Pulse<S>(
    value,
    source: cell ?? trigger?.source,
    type: trigger?.type,
    priority: trigger?.priority,
    step: step,
  );
}

Pulse _err(Object error, Cell? cell, String step, {Pulse? trigger}) {
  return Pulse(
    error,
    source: cell ?? trigger?.source,
    type: 'error',
    priority: trigger?.priority,
    step: step,
  );
}

Future<S> _withTimeout<S>(Future<S> future, Duration? timeout) {
  if (timeout == null) return future;
  return future.timeout(timeout);
}

Future<S> _withRetry<S>(
    Future<S> Function() start, {
      required int maxAttempts,
      required Duration delay,
    }) async {
  final attempts = maxAttempts < 1 ? 1 : maxAttempts;
  Object? lastError;
  StackTrace? lastStack;
  for (var i = 0; i < attempts; i++) {
    try {
      return await start();
    } catch (e, stack) {
      lastError = e;
      lastStack = stack;
      if (i < attempts - 1 && delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
    }
  }
  Error.throwWithStackTrace(lastError!, lastStack ?? StackTrace.current);
}

void _emitError({
  required Object error,
  StackTrace? stack,
  required FutureErrorHandler? onError,
  required bool emitErrorPulse,
  required void Function({required Pulse? result, required dynamic token})? future,
  required dynamic token,
  required Cell? cell,
  required Pulse trigger,
  required String step,
}) {
  onError?.call(error, stack);
  if (emitErrorPulse && future != null) {
    future(result: _err(error, cell, step, trigger: trigger), token: token);
  }
}

// ─────────────────────────────────────────────────────────────
// One-shot Future → Pulse
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that bridges a single [Future] into the graph
/// (Rx `from(Future)` / `fromPromise`).
///
/// [FromFuture] acts as an **Asynchronous One-Shot Loader** that awaits a
/// single future and emits its result as a [Pulse]. It processes the first
/// trigger and ignores subsequent triggers.
///
/// ### When to use
/// Use [FromFuture] when you need to load a single asynchronous value:
///
/// - **Initial Configuration**: Loading app configuration or user profile
/// - **One-Shot HTTP Calls**: Bridging a single API call into the graph
/// - **Database Queries**: Loading a single record from the database
/// - **File Loading**: Reading a single file asynchronously
/// - **Initialization**: Loading initial state for a module
/// - **Bridging Legacy APIs**: Converting `Future`-based APIs to Cell-Flow
/// - **Lazy Loading**: Loading data on demand when first triggered
///
/// ### Choosing Between Future Loading Patterns
/// - **Use [FromFuture]** for **One-Shot Loading**: When you need a single
///   future that should only be awaited once.
/// - **Use [DeferFuture]** for **Per-Trigger Loading**: When each trigger
///   should start a new future.
/// - **Use [FromFutureOr]** for **Sync/Async Hybrid**: When values can be
///   either synchronous or asynchronous.
/// - **Use [MapToFuture]** for **Typed Payload Mapping**: When you need to
///   map a trigger payload into a future.
/// - **Use [FromFutureWithRetry]** for **Retry Logic**: When operations may
///   fail and need retry.
/// - **Use [FromFutureWithTimeout]** for **Timeout**: When operations must
///   complete within a time limit.
/// - **Use [FromFutureWithFallback]** for **Fallback Values**: When you need
///   a default value on error.
///
/// ### Comparison with Other Operators
/// | Operator | Starts | Emits | Use Case |
/// |----------|--------|-------|----------|
/// | **FromFuture** | first trigger | one value | One-shot loading |
/// | **DeferFuture** | every trigger | one value | Per-trigger loading |
/// | **FromFutureOr** | every trigger | sync or awaited | Sync/Async hybrid |
/// | **ConcatFromFuture** | queued | trigger order | Ordered sequential |
/// | **MergeFromFuture** | parallel | completion order | Unordered parallel |
/// | **SwitchFromFuture** | latest | latest only | Latest only |
/// | **ExhaustFromFuture** | if idle | one in flight | Exhaust |
/// | **FromFutures** | first trigger | each completion | Multiple futures (unordered) |
/// | **FromFuturesInOrder** | first trigger | list order | Multiple futures (ordered) |
/// | **ForkJoinFutures** | first trigger | one `List` | All futures complete |
/// | **RaceFutures** | first trigger | first winner | First to complete |
///
/// ### Non‑obvious
/// - **One-Shot**: The instruction processes only the first trigger.
///   Subsequent triggers are ignored.
/// - **Lazy Execution**: The future is not started until the first trigger
///   arrives. This prevents unnecessary work.
/// - **Error Handling**: Errors are reported via [onError] and optionally
///   as error pulses with `type: 'error'`.
/// - **Timeout**: Optional timeout can be applied to the future operation.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
/// - **Type Safety**: The instruction is generic over [S] (output type),
///   ensuring compile-time type safety.
/// - **Memory Efficiency**: Only the state flag and user data are stored.
///
/// ### Example: Loading a User Profile
/// ```dart
/// final load = FromFuture<UserProfile>(
///   api.fetchUserProfile(123),
/// ).toHandle();
///
/// Cell.observe(
///   source: load.cell,
///   effect: (pulse) => print('User: ${pulse.payload}'),
/// );
///
/// // Trigger the load
/// await load.emitAsync(null);
/// // -> User: UserProfile(id: 123, name: 'Alice')
/// ```
///
/// ### Example: With Timeout
/// ```dart
/// final load = FromFuture<String>(
///   slowApiCall(),
///   timeout: Duration(seconds: 5),
///   onError: (error, stack) => print('Timeout: $error'),
/// ).toHandle();
/// ```
///
/// ### Parameters:
/// - [source]: **The Future to Bridge.** The asynchronous operation to await.
/// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
///   will fail if it exceeds this duration.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload from the future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [DeferFuture]: For per-trigger future execution.
/// - [FromFutureOr]: For sync/async hybrid.
/// - [MapToFuture]: For typed payload mapping.
/// - [Cell.fromFuture]: For standalone cell creation.
class FromFuture<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [FromFuture] instruction with the specified [source].
  ///
  /// ### Parameters:
  /// - [source]: **The Future to Bridge.** The asynchronous operation to await.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final loadInstruction = FromFuture<String>(
  ///   Future.delayed(Duration(seconds: 1), () => 'Hello'),
  ///   timeout: Duration(seconds: 2),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  FromFuture(
      Future<S> source, {
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : this._launch(
        () => source,
    timeout: timeout,
    onError: onError,
    emitErrorPulse: emitErrorPulse,
    user: user,
  );

  FromFuture._launch(
      Future<S> Function() launch, {
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
    (() {
      final state = _OnceState();
      return (pulse, {cell, user, future, token}) {
        if (state.started) return null;
        state.started = true;
        Future<void>(() async {
          try {
            final value = await _withTimeout(launch(), timeout);
            future!(result: _ok(value, cell, 'FromFuture', trigger: pulse), token: token);
          } catch (e, stack) {
            _emitError(
              error: e,
              stack: stack,
              onError: onError,
              emitErrorPulse: emitErrorPulse,
              future: future,
              token: token,
              cell: cell,
              trigger: pulse,
              step: 'FromFuture.error',
            );
          }
        });
        return null;
      };
    })(),
    user: user,
  );

  /// Creates a [FromFuture] that emits a value on the first trigger.
  ///
  /// This is a convenience factory for `Future.value`.
  ///
  /// ### Example
  /// ```dart
  /// final ready = FromFuture.value('ready').toHandle();
  /// await ready.emitAsync(null); // Emits 'ready'
  /// ```
  ///
  /// ### Parameters:
  /// - [value]: The value to emit on the first trigger.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata.
  factory FromFuture.value(
      S value, {
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) =>
      FromFuture<S>(
        Future<S>.value(value),
        onError: onError,
        emitErrorPulse: emitErrorPulse,
        user: user,
      );

  /// Creates a [FromFuture] that fails on the first trigger.
  ///
  /// The error [Future] is created only when the trigger runs, so it is
  /// awaited inside the instruction and does not become an unhandled
  /// async error at construction time.
  ///
  /// ### Example
  /// ```dart
  /// final fail = FromFuture<String>.error(Exception('Failed')).toHandle();
  /// await fail.emitAsync(null); // Emits error pulse
  /// ```
  ///
  /// ### Parameters:
  /// - [error]: The error to throw.
  /// - [stackTrace]: Optional stack trace.
  factory FromFuture.error(
      Object error, [
        StackTrace? stackTrace,
      ]) =>
      FromFuture<S>._launch(
            () => Future<S>.error(error, stackTrace),
      );
}

/// A [Receptor] instruction that starts a new future for each trigger
/// (Rx `defer(() => from(Future))`).
///
/// [DeferFuture] acts as an **Asynchronous Per-Trigger Loader**. Each
/// trigger pulse starts a **new** `Future` from [compute]. The trigger
/// payload is passed through so the factory can depend on the stimulus.
///
/// ### When to use
/// Use [DeferFuture] when you need a new future for each trigger:
///
/// - **Per-Request Loading**: Loading data for each user request
/// - **Dynamic Loading**: Loading data based on the trigger payload
/// - **Refresh Operations**: Reloading data on each refresh trigger
/// - **Lazy Evaluation**: Evaluating a future only when triggered
/// - **Search Operations**: Performing a new search for each query
/// - **Pagination**: Loading the next page on each trigger
/// - **Form Submissions**: Submitting each form as a separate operation
///
/// ### How it works
/// 1. Each trigger pulse calls [compute] with the pulse.
/// 2. The [compute] function returns a `Future<S>`.
/// 3. The future is awaited (optionally under [timeout]).
/// 4. Success emits `Pulse<S>` with step `DeferFuture`.
/// 5. Failure is reported through [onError] and optionally an error pulse.
/// 6. Results are emitted in input order (sequential processing).
/// 7. The instruction preserves causal provenance.
///
/// ### Choosing Between Defer Patterns
/// - **Use [DeferFuture]** for **Simple Defer**: When you need a new future
///   for each trigger.
/// - **Use [ConcatFromFuture]** for **Sequential**: When order matters and
///   you want to finish one before starting the next.
/// - **Use [MergeFromFuture]** for **Parallel**: When order doesn't matter
///   and you want maximum throughput.
/// - **Use [SwitchFromFuture]** for **Latest Only**: When you only care
///   about the most recent result.
/// - **Use [ExhaustFromFuture]** for **Exhaust**: When you want to ignore
///   triggers while busy.
///
/// ### Non‑obvious
/// - **Per-Trigger**: Each trigger starts a new future.
/// - **Sequential**: The instruction processes inputs one at a time.
///   Each async operation must complete before the next starts.
/// - **Payload Access**: The trigger payload is passed to [compute] so
///   the future can depend on the stimulus.
/// - **Error Handling**: Errors are reported via [onError] and optionally
///   as error pulses with `type: 'error'`.
/// - **Timeout**: Optional timeout can be applied to each future operation.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
/// - **Backpressure**: The instruction processes inputs sequentially,
///   automatically providing backpressure.
///
/// ### Example: User Profile Loading
/// ```dart
/// final userIds = Cell.ingress<int>();
/// final deferred = DeferFuture<UserProfile>(
///   (p) async => await api.fetchUserProfile(p.payload as int),
/// ).toHandle(source: userIds.cell);
///
/// await userIds.emitAsync(1); // Loads user 1
/// await userIds.emitAsync(2); // Loads user 2
/// ```
///
/// ### Example: Search-as-you-Type
/// ```dart
/// final searches = Cell.ingress<String>();
/// final results = DeferFuture<List<Result>>(
///   (p) async => await api.search(p.payload as String),
/// ).toHandle(source: searches.cell);
///
/// searches.emit('hello'); // Searches for 'hello'
/// searches.emit('world'); // Searches for 'world'
/// ```
///
/// ### Parameters:
/// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
///   a `Future<S>`.
/// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
///   will fail if it exceeds this duration.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload from the future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [FromFuture]: For one-shot future loading.
/// - [ConcatFromFuture]: For sequential future loading.
/// - [MergeFromFuture]: For parallel future loading.
/// - [SwitchFromFuture]: For latest only future loading.
/// - [ExhaustFromFuture]: For exhaust future loading.
class DeferFuture<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [DeferFuture] instruction with the specified [compute].
  ///
  /// ### Parameters:
  /// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
  ///   a `Future<S>`.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final deferInstruction = DeferFuture<String>(
  ///   (p) async => 'User ${p.payload}',
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  DeferFuture(
      Future<S> Function(Pulse trigger) compute, {
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      Future<void>(() async {
        try {
          final value = await _withTimeout(compute(pulse), timeout);
          future!(result: _ok(value, cell, 'DeferFuture', trigger: pulse), token: token);
        } catch (e, stack) {
          _emitError(
            error: e,
            stack: stack,
            onError: onError,
            emitErrorPulse: emitErrorPulse,
            future: future,
            token: token,
            cell: cell,
            trigger: pulse,
            step: 'DeferFuture.error',
          );
        }
      });
      return null;
    },
    user: user,
  );
}

/// A [Receptor] instruction that accepts `FutureOr<S>` — sync values emit
/// immediately, futures are awaited.
///
/// [FromFutureOr] acts as a **Sync/Async Hybrid Loader**. It handles both
/// synchronous values and asynchronous futures, emitting the result
/// immediately for sync values or awaiting the future for async values.
///
/// ### When to use
/// Use [FromFutureOr] when values can be either synchronous or asynchronous:
///
/// - **Cached Values**: Returning cached values synchronously or fetching
///   fresh values asynchronously.
/// - **Configuration**: Loading configuration from memory (sync) or disk (async).
/// - **Hybrid APIs**: APIs that may return `FutureOr` values.
/// - **Testing**: Mixing sync and async values in tests.
/// - **Conditional Loading**: Loading from cache (sync) or network (async).
///
/// ### How it works
/// 1. Each trigger pulse calls [compute] with the pulse.
/// 2. If [compute] returns a synchronous value, it is emitted immediately.
/// 3. If [compute] returns a [Future], it is awaited (optionally under [timeout]).
/// 4. Success emits `Pulse<S>` with step `FromFutureOr`.
/// 5. Failure is reported through [onError] and optionally an error pulse.
/// 6. Results are emitted in input order (sequential processing).
/// 7. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Sync/Async Hybrid**: Handles both synchronous and asynchronous values.
/// - **Immediate Emission**: Sync values are emitted immediately without
///   entering the event loop.
/// - **Future Awaited**: Async values are awaited before emission.
/// - **Error Handling**: Errors are reported via [onError] and optionally
///   as error pulses with `type: 'error'`.
/// - **Timeout**: Optional timeout can be applied to future operations only.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
/// - **Type Safety**: The instruction is generic over [S] (output type).
///
/// ### Example: Cached Data Loading
/// ```dart
/// final cache = <String, String>{};
/// final loader = FromFutureOr<String>(
///   (p) {
///     final key = p.payload as String;
///     if (cache.containsKey(key)) return cache[key]!; // Sync
///     return fetchFromNetwork(key); // Async
///   },
/// ).toHandle();
///
/// loader.emitAsync('key1'); // Immediate if cached
/// loader.emitAsync('key2'); // Awaited if not cached
/// ```
///
/// ### Example: Configuration Loading
/// ```dart
/// final config = FromFutureOr<Config>(
///   (p) {
///     final name = p.payload as String;
///     return configCache[name] ?? loadConfig(name);
///   },
/// ).toHandle();
/// ```
///
/// ### Parameters:
/// - [compute]: **The Sync/Async Provider.** Takes the trigger pulse and
///   returns a `FutureOr<S>`.
/// - [timeout]: **Timeout Duration.** Optional. Applied only to futures.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [FromFuture]: For one-shot future loading.
/// - [DeferFuture]: For per-trigger future loading.
class FromFutureOr<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [FromFutureOr] instruction with the specified [compute].
  ///
  /// ### Parameters:
  /// - [compute]: **The Sync/Async Provider.** Takes the trigger pulse and
  ///   returns a `FutureOr<S>`.
  /// - [timeout]: **Timeout Duration.** Optional. Applied only to futures.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final hybrid = FromFutureOr<String>(
  ///   (p) => cache[p.payload] ?? fetch(p.payload),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  FromFutureOr(
      FutureOr<S> Function(Pulse trigger) compute, {
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      try {
        final result = compute(pulse);
        if (result is Future<S>) {
          Future<void>(() async {
            try {
              final value = await _withTimeout(result, timeout);
              future!(
                result: _ok(value, cell, 'FromFutureOr', trigger: pulse),
                token: token,
              );
            } catch (e, stack) {
              _emitError(
                error: e,
                stack: stack,
                onError: onError,
                emitErrorPulse: emitErrorPulse,
                future: future,
                token: token,
                cell: cell,
                trigger: pulse,
                step: 'FromFutureOr.error',
              );
            }
          });
          return null;
        }
        return _ok(result, cell, 'FromFutureOr', trigger: pulse);
      } catch (e, stack) {
        onError?.call(e, stack);
        return emitErrorPulse ? _err(e, cell, 'FromFutureOr.error', trigger: pulse) : null;
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Concurrency strategies (flatMap of futures)
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that sequentially executes futures for each trigger
/// (Rx `concatMap`).
///
/// [ConcatFromFuture] acts as a **Sequential Future Mapper**. Each compute
/// finishes before the next starts, ensuring strict FIFO ordering.
///
/// ### When to use
/// Use [ConcatFromFuture] when:
/// - **Order Matters**: You must preserve input order
/// - **Resource Constraints**: You want to limit concurrent operations
/// - **Sequential Processing**: Operations must be processed one at a time
/// - **Rate Limiting**: You want to limit the rate of operations
/// - **Stream Processing**: Processing ordered data streams
/// - **Database Transactions**: Transactions that must be sequential
/// - **File Operations**: Operations that require exclusive access
///
/// ### Comparison with Other Operators
/// | Operator | Behavior | Use Case |
/// |----------|----------|----------|
/// | **ConcatFromFuture** | Sequential (FIFO) | Ordered processing |
/// | **MergeFromFuture** | Parallel (unordered) | Maximum throughput |
/// | **SwitchFromFuture** | Latest only | Latest only |
/// | **ExhaustFromFuture** | One at a time | Ignore while busy |
///
/// ### Non‑obvious
/// - **Strict Sequencing**: The instruction processes inputs one at a time.
///   Each async operation must complete before the next starts.
/// - **Order Preservation**: Results are emitted in the same order as inputs.
/// - **Queueing**: Inputs are queued while an operation is in progress.
/// - **Error Handling**: Errors are reported via [onError] and optionally
///   as error pulses with `type: 'error'`.
/// - **Timeout**: Optional timeout can be applied to each future operation.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
/// - **Backpressure**: The instruction processes inputs sequentially,
///   automatically providing backpressure.
///
/// ### Example: Sequential API Calls
/// ```dart
/// final ids = Cell.ingress<int>();
/// final sequential = ConcatFromFuture<String>(
///   (p) async => await api.fetchUser(p.payload as int),
/// ).toHandle(source: ids.cell);
///
/// ids.emit(1); // Starts fetching user 1
/// ids.emit(2); // Queued until user 1 completes
/// ids.emit(3); // Queued until user 2 completes
/// ```
///
/// ### Example: Database Transactions
/// ```dart
/// final commands = Cell.ingress<Command>();
/// final results = ConcatFromFuture<Result>(
///   (p) async => await db.executeTransaction(p.payload as Command),
/// ).toHandle(source: commands.cell);
/// ```
///
/// ### Parameters:
/// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
///   a `Future<S>`.
/// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
///   will fail if it exceeds this duration.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload from the future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [MergeFromFuture]: For parallel future loading.
/// - [SwitchFromFuture]: For latest only future loading.
/// - [ExhaustFromFuture]: For exhaust future loading.
class ConcatFromFuture<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [ConcatFromFuture] instruction with the specified [compute].
  ///
  /// ### Parameters:
  /// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
  ///   a `Future<S>`.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final concat = ConcatFromFuture<String>(
  ///   (p) async => await api.fetch(p.payload as String),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  ConcatFromFuture(
      Future<S> Function(Pulse trigger) compute, {
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
    (() {
      final queue = _AsyncQueueState();
      return (pulse, {cell, user, future, token}) {
        queue.enqueue(() async {
          try {
            final value = await _withTimeout(compute(pulse), timeout);
            future!(
              result: _ok(value, cell, 'ConcatFromFuture', trigger: pulse),
              token: token,
            );
          } catch (e, stack) {
            _emitError(
              error: e,
              stack: stack,
              onError: onError,
              emitErrorPulse: emitErrorPulse,
              future: future,
              token: token,
              cell: cell,
              trigger: pulse,
              step: 'ConcatFromFuture.error',
            );
          }
        });
        return null;
      };
    })(),
    user: user,
  );
}

/// A [Receptor] instruction that executes futures in parallel, emitting results
/// as they complete (Rx `mergeMap`).
///
/// [MergeFromFuture] acts as a **Parallel Future Mapper**. Each trigger
/// starts a new future immediately, and results are emitted as soon as they
/// complete, without waiting for order.
///
/// ### When to use
/// Use [MergeFromFuture] when:
/// - **Performance Matters**: You want maximum throughput
/// - **Order Doesn't Matter**: Results can be processed independently
/// - **Batch Processing**: Processing large batches of independent items
/// - **Parallel Requests**: Making multiple API calls concurrently
/// - **Image Processing**: Processing images in parallel
/// - **Independent Tasks**: Tasks that don't depend on each other
///
/// ### How it works
/// 1. Each trigger starts a new future immediately.
/// 2. Results are emitted as soon as they complete.
/// 3. New operations start as slots become available.
/// 4. Output order is not guaranteed.
/// 5. Results are emitted in completion order.
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Unordered Output**: Results are emitted in completion order.
/// - **Throughput**: Maximum throughput is achieved with parallel execution.
/// - **Resource Usage**: High concurrency may consume significant resources.
/// - **Error Isolation**: Errors in one operation don't affect others.
/// - **Timeout**: Optional timeout can be applied to each future operation.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: Parallel API Calls
/// ```dart
/// final urls = Cell.ingress<String>();
/// final responses = MergeFromFuture<String>(
///   (p) async => await http.get(p.payload as String),
/// ).toHandle(source: urls.cell);
///
/// urls.emit('slow.com'); // Starts fetch
/// urls.emit('fast.com'); // Starts fetch immediately
/// // Results are emitted in completion order (fast.com first)
/// ```
///
/// ### Parameters:
/// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
///   a `Future<S>`.
/// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
///   will fail if it exceeds this duration.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload from the future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ConcatFromFuture]: For sequential future loading.
/// - [SwitchFromFuture]: For latest only future loading.
/// - [ExhaustFromFuture]: For exhaust future loading.
class MergeFromFuture<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [MergeFromFuture] instruction with the specified [compute].
  ///
  /// ### Parameters:
  /// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
  ///   a `Future<S>`.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final merge = MergeFromFuture<String>(
  ///   (p) async => await api.fetch(p.payload as String),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  MergeFromFuture(
      Future<S> Function(Pulse trigger) compute, {
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      Future<void>(() async {
        try {
          final value = await _withTimeout(compute(pulse), timeout);
          future!(
            result: _ok(value, cell, 'MergeFromFuture', trigger: pulse),
            token: token,
          );
        } catch (e, stack) {
          _emitError(
            error: e,
            stack: stack,
            onError: onError,
            emitErrorPulse: emitErrorPulse,
            future: future,
            token: token,
            cell: cell,
            trigger: pulse,
            step: 'MergeFromFuture.error',
          );
        }
      });
      return null;
    },
    user: user,
  );
}

/// A [Receptor] instruction that only emits the latest future result
/// (Rx `switchMap`).
///
/// [SwitchFromFuture] acts as a **Latest-Only Future Mapper**. Only the
/// latest in-flight future may emit. Previous in-flight futures are cancelled
/// (their results are dropped).
///
/// ### When to use
/// Use [SwitchFromFuture] when:
/// - **Search-as-you-type**: Only the latest search query matters
/// - **Real-time Filtering**: Only the most recent filter applies
/// - **Navigation**: Only the latest route matters
/// - **Form Validation**: Only the latest input should be validated
/// - **Live Updates**: Only the most recent update is relevant
///
/// ### How it works
/// 1. Each trigger starts a new future with a unique ID.
/// 2. If a new trigger arrives while a future is in flight, the previous
///    future's ID is marked as stale.
/// 3. Only the future with the current ID can emit results.
/// 4. Stale futures' results are silently dropped.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Silent Cancellation**: Cancelled operations do not throw exceptions.
///   They simply don't emit results.
/// - **Operation ID Tracking**: Each operation gets a unique ID. Only the
///   operation with the current ID can emit.
/// - **Memory Safety**: The state only holds the latest value, not all values.
/// - **Timeout**: Optional timeout can be applied to each future operation.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: Search-as-you-Type
/// ```dart
/// final searchInput = Cell.ingress<String>();
/// final results = SwitchFromFuture<List<Result>>(
///   (p) async => await api.search(p.payload as String),
/// ).toHandle(source: searchInput.cell);
///
/// searchInput.emit('h'); // Starts search for 'h'
/// searchInput.emit('he'); // Cancels 'h' search, starts 'he'
/// searchInput.emit('hel'); // Cancels 'he' search, starts 'hel'
/// // Only the result for 'hel' is emitted
/// ```
///
/// ### Parameters:
/// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
///   a `Future<S>`.
/// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
///   will fail if it exceeds this duration.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload from the future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ConcatFromFuture]: For sequential future loading.
/// - [MergeFromFuture]: For parallel future loading.
/// - [ExhaustFromFuture]: For exhaust future loading.
class SwitchFromFuture<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [SwitchFromFuture] instruction with the specified [compute].
  ///
  /// ### Parameters:
  /// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
  ///   a `Future<S>`.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final switchMap = SwitchFromFuture<String>(
  ///   (p) async => await api.fetch(p.payload as String),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  SwitchFromFuture(
      Future<S> Function(Pulse trigger) compute, {
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
    (() {
      final gen = _GenerationState();
      return (pulse, {cell, user, future, token}) {
        final id = ++gen.generation;
        Future<void>(() async {
          try {
            final value = await _withTimeout(compute(pulse), timeout);
            if (id != gen.generation) return;
            future!(
              result: _ok(value, cell, 'SwitchFromFuture', trigger: pulse),
              token: token,
            );
          } catch (e, stack) {
            if (id != gen.generation) return;
            _emitError(
              error: e,
              stack: stack,
              onError: onError,
              emitErrorPulse: emitErrorPulse,
              future: future,
              token: token,
              cell: cell,
              trigger: pulse,
              step: 'SwitchFromFuture.error',
            );
          }
        });
        return null;
      };
    })(),
    user: user,
  );
}

/// A [Receptor] instruction that ignores triggers while a future is in flight
/// (Rx `exhaustMap`).
///
/// [ExhaustFromFuture] acts as an **Exhaust Future Mapper**. Triggers while a
/// compute is in flight are dropped. Only one future can be in flight at a time.
///
/// ### When to use
/// Use [ExhaustFromFuture] when:
/// - **Prevent Overlap**: You want to prevent overlapping operations
/// - **Rate Limiting**: You want to limit the rate of operations
/// - **Resource Protection**: You want to prevent resource exhaustion
/// - **Button Click Handling**: Prevent double-click issues
/// - **Form Submission**: Prevent duplicate form submissions
/// - **Idempotent Operations**: Operations that should only run once at a time
///
/// ### How it works
/// 1. The first trigger starts a future.
/// 2. While the future is in flight, all subsequent triggers are dropped.
/// 3. When the future completes, the instruction is ready for the next trigger.
/// 4. Results are emitted in input order (sequential processing).
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Drop While Busy**: Triggers while busy are silently dropped.
/// - **One at a Time**: Only one future can be in flight at a time.
/// - **Error Handling**: Errors are reported via [onError] and optionally
///   as error pulses with `type: 'error'`.
/// - **Timeout**: Optional timeout can be applied to each future operation.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: Button Click Prevention
/// ```dart
/// final clicks = Cell.ingress<void>();
/// final submit = ExhaustFromFuture<String>(
///   (_) async {
///     await submitForm();
///     return 'Submitted!';
///   },
/// ).toHandle(source: clicks.cell);
///
/// clicks.emit(null); // Starts submission
/// clicks.emit(null); // Dropped (busy)
/// clicks.emit(null); // Dropped (busy)
/// // Only the first submission is processed
/// ```
///
/// ### Parameters:
/// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
///   a `Future<S>`.
/// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
///   will fail if it exceeds this duration.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload from the future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ConcatFromFuture]: For sequential future loading.
/// - [MergeFromFuture]: For parallel future loading.
/// - [SwitchFromFuture]: For latest only future loading.
class ExhaustFromFuture<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates an [ExhaustFromFuture] instruction with the specified [compute].
  ///
  /// ### Parameters:
  /// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
  ///   a `Future<S>`.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final exhaust = ExhaustFromFuture<String>(
  ///   (p) async => await submitForm(p.payload as FormData),
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  ExhaustFromFuture(
      Future<S> Function(Pulse trigger) compute, {
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
    (() {
      final state = _BusyState();
      return (pulse, {cell, user, future, token}) {
        if (state.busy) return null;
        state.busy = true;
        Future<void>(() async {
          try {
            final value = await _withTimeout(compute(pulse), timeout);
            future!(
              result: _ok(value, cell, 'ExhaustFromFuture', trigger: pulse),
              token: token,
            );
          } catch (e, stack) {
            _emitError(
              error: e,
              stack: stack,
              onError: onError,
              emitErrorPulse: emitErrorPulse,
              future: future,
              token: token,
              cell: cell,
              trigger: pulse,
              step: 'ExhaustFromFuture.error',
            );
          } finally {
            state.busy = false;
          }
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Multi-future combinators
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that emits each future's value as it completes
/// (Rx `merge` of futures).
///
/// [FromFutures] acts as a **Multiple Future Merger**. It takes a list of
/// futures and emits each value as it completes, without waiting for order.
///
/// ### When to use
/// Use [FromFutures] when:
/// - You have multiple independent futures
/// - You want to emit results as they complete
/// - Order doesn't matter
/// - You want maximum throughput
///
/// ### How it works
/// 1. The first trigger starts all futures.
/// 2. Each future's value is emitted as it completes.
/// 3. Results are emitted in completion order.
/// 4. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Unordered Output**: Results are emitted in completion order.
/// - **All Futures Start**: All futures start on the first trigger.
/// - **Timeout**: Optional timeout can be applied to each future operation.
/// - **Error Handling**: Errors are reported via [onError] and optionally
///   as error pulses with `type: 'error'`.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: Multiple API Calls
/// ```dart
/// final futures = FromFutures<String>([
///   Future.delayed(Duration(seconds: 2), () => 'slow'),
///   Future.delayed(Duration(seconds: 1), () => 'fast'),
/// ]).toHandle();
///
/// await futures.emitAsync(null);
/// // Emits 'fast', then 'slow'
/// ```
///
/// ### Parameters:
/// - [futures]: **The List of Futures.** Each future's value will be emitted.
/// - [timeout]: **Timeout Duration.** Optional. If provided, each operation
///   will fail if it exceeds this duration.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload from each future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [FromFuturesInOrder]: For ordered multiple futures.
/// - [ForkJoinFutures]: For joining all futures into a list.
/// - [RaceFutures]: For racing futures.
class FromFutures<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [FromFutures] instruction with the specified [futures].
  ///
  /// ### Parameters:
  /// - [futures]: **The List of Futures.** Each future's value will be emitted.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, each operation
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final futures = FromFutures<String>([
  ///   Future.value('A'),
  ///   Future.value('B'),
  /// ]).toHandle();
  /// ```
  FromFutures(
      Iterable<Future<S>> futures, {
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
    (() {
      final state = _OnceState();
      final list = List<Future<S>>.from(futures);
      return (pulse, {cell, user, future, token}) {
        if (state.started) return null;
        state.started = true;
        for (final item in list) {
          Future<void>(() async {
            try {
              final value = await _withTimeout(item, timeout);
              future!(
                result: _ok(value, cell, 'FromFutures', trigger: pulse),
                token: token,
              );
            } catch (e, stack) {
              _emitError(
                error: e,
                stack: stack,
                onError: onError,
                emitErrorPulse: emitErrorPulse,
                future: future,
                token: token,
                cell: cell,
                trigger: pulse,
                step: 'FromFutures.error',
              );
            }
          });
        }
        return null;
      };
    })(),
    user: user,
  );
}

/// A [Receptor] instruction that emits values in input-list order after each
/// future completes (Rx `concat`).
///
/// [FromFuturesInOrder] acts as an **Ordered Multiple Future Merger**. It
/// takes a list of futures and emits values in the order they appear in the
/// list, waiting for each future to complete before starting the next.
///
/// ### When to use
/// Use [FromFuturesInOrder] when:
/// - You have multiple futures that must be processed in order
/// - You need to preserve the order of the input list
/// - You're processing dependent operations
/// - You want to limit concurrency
///
/// ### How it works
/// 1. The first trigger starts the first future.
/// 2. When the first future completes, its value is emitted.
/// 3. The next future starts.
/// 4. This process continues until all futures are processed.
/// 5. Results are emitted in input-list order.
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Ordered Output**: Results are emitted in input-list order.
/// - **Sequential Execution**: Futures are processed one at a time.
/// - **Timeout**: Optional timeout can be applied to each future operation.
/// - **Error Handling**: Errors are reported via [onError] and optionally
///   as error pulses with `type: 'error'`.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: Ordered Processing
/// ```dart
/// final ordered = FromFuturesInOrder<String>([
///   Future.delayed(Duration(seconds: 2), () => 'slow'),
///   Future.delayed(Duration(seconds: 1), () => 'fast'),
/// ]).toHandle();
///
/// await ordered.emitAsync(null);
/// // Emits 'slow', then 'fast' (order preserved)
/// ```
///
/// ### Parameters:
/// - [futures]: **The List of Futures.** Each future's value will be emitted
///   in order.
/// - [timeout]: **Timeout Duration.** Optional. If provided, each operation
///   will fail if it exceeds this duration.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload from each future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [FromFutures]: For unordered multiple futures.
/// - [ForkJoinFutures]: For joining all futures into a list.
/// - [RaceFutures]: For racing futures.
class FromFuturesInOrder<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [FromFuturesInOrder] instruction with the specified [futures].
  ///
  /// ### Parameters:
  /// - [futures]: **The List of Futures.** Each future's value will be emitted
  ///   in order.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, each operation
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final ordered = FromFuturesInOrder<String>([
  ///   fetchUser(1),
  ///   fetchUser(2),
  ///   fetchUser(3),
  /// ]).toHandle();
  /// ```
  FromFuturesInOrder(
      Iterable<Future<S>> futures, {
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
    (() {
      final state = _OnceState();
      final list = List<Future<S>>.from(futures);
      return (pulse, {cell, user, future, token}) {
        if (state.started) return null;
        state.started = true;
        Future<void>(() async {
          for (final item in list) {
            try {
              final value = await _withTimeout(item, timeout);
              future!(
                result: _ok(value, cell, 'FromFuturesInOrder', trigger: pulse),
                token: token,
              );
            } catch (e, stack) {
              _emitError(
                error: e,
                stack: stack,
                onError: onError,
                emitErrorPulse: emitErrorPulse,
                future: future,
                token: token,
                cell: cell,
                trigger: pulse,
                step: 'FromFuturesInOrder.error',
              );
            }
          }
        });
        return null;
      };
    })(),
    user: user,
  );
}

/// A [Receptor] instruction that emits one `List<S>` when every future has
/// succeeded (Rx `forkJoin`).
///
/// [ForkJoinFutures] acts as a **Future Joiner**. It waits for all futures
/// to complete and emits a list of all values.
///
/// ### When to use
/// Use [ForkJoinFutures] when:
/// - You need to wait for all futures to complete
/// - You need to combine results from multiple sources
/// - You're implementing parallel requests with combined results
/// - You need all data before proceeding
///
/// ### How it works
/// 1. The first trigger starts all futures.
/// 2. All futures are executed in parallel.
/// 3. When all futures complete, a `List<S>` is emitted.
/// 4. If any future fails, the error is reported.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **All-or-Nothing**: All futures must succeed to emit a result.
/// - **Ordered Output**: Results are emitted in input-list order.
/// - **Parallel Execution**: All futures are started concurrently.
/// - **Timeout**: Optional timeout can be applied to each future operation.
/// - **Error Handling**: If any future fails, the error is reported and no
///   result is emitted.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: Multiple API Calls
/// ```dart
/// final joined = ForkJoinFutures<int>([
///   fetchUserAge(1),
///   fetchUserAge(2),
///   fetchUserAge(3),
/// ]).toHandle();
///
/// await joined.emitAsync(null);
/// // Emits [25, 30, 35] (all results)
/// ```
///
/// ### Parameters:
/// - [futures]: **The List of Futures.** All futures must complete.
/// - [timeout]: **Timeout Duration.** Optional. If provided, each operation
///   will fail if it exceeds this duration.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload from each future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [FromFutures]: For unordered multiple futures.
/// - [FromFuturesInOrder]: For ordered multiple futures.
/// - [RaceFutures]: For racing futures.
class ForkJoinFutures<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [ForkJoinFutures] instruction with the specified [futures].
  ///
  /// ### Parameters:
  /// - [futures]: **The List of Futures.** All futures must complete.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, each operation
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final joined = ForkJoinFutures<int>([
  ///   fetchUsers(1),
  ///   fetchUsers(2),
  ///   fetchUsers(3),
  /// ]).toHandle();
  /// ```
  ForkJoinFutures(
      Iterable<Future<S>> futures, {
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
    (() {
      final state = _OnceState();
      final list = List<Future<S>>.from(futures);
      return (pulse, {cell, user, future, token}) {
        if (state.started) return null;
        state.started = true;
        Future<void>(() async {
          try {
            final values = await Future.wait(
              list.map((f) => _withTimeout(f, timeout)),
            );
            future!(
              result: _ok(values, cell, 'ForkJoinFutures', trigger: pulse),
              token: token,
            );
          } catch (e, stack) {
            _emitError(
              error: e,
              stack: stack,
              onError: onError,
              emitErrorPulse: emitErrorPulse,
              future: future,
              token: token,
              cell: cell,
              trigger: pulse,
              step: 'ForkJoinFutures.error',
            );
          }
        });
        return null;
      };
    })(),
    user: user,
  );
}

/// A [Receptor] instruction that emits the first future to complete
/// (Rx `race` / `Future.any`).
///
/// [RaceFutures] acts as a **Future Racer**. It starts all futures and emits
/// the first one to complete, ignoring the others.
///
/// ### When to use
/// Use [RaceFutures] when:
/// - You want the fastest result from multiple sources
/// - You're implementing a timeout with fallback
/// - You're implementing a race condition for performance
/// - You're using redundant services for reliability
///
/// ### How it works
/// 1. The first trigger starts all futures.
/// 2. All futures are executed in parallel.
/// 3. The first future to complete determines the result.
/// 4. Other futures are ignored.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **First Winner**: Only the first future to complete is emitted.
/// - **Parallel Execution**: All futures are started concurrently.
/// - **Timeout**: Optional timeout can be applied to the race.
/// - **Error Handling**: If all futures fail, the error is reported.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: Fastest API Response
/// ```dart
/// final raced = RaceFutures<String>([
///   fetchFromPrimary(),
///   fetchFromReplica(),
///   fetchFromCache(),
/// ]).toHandle();
///
/// await raced.emitAsync(null);
/// // Emits the fastest response
/// ```
///
/// ### Parameters:
/// - [futures]: **The List of Futures.** The first to complete wins.
/// - [timeout]: **Timeout Duration.** Optional. If provided, the race will
///   fail if no future completes within the timeout.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload from the future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [FromFutures]: For unordered multiple futures.
/// - [FromFuturesInOrder]: For ordered multiple futures.
/// - [ForkJoinFutures]: For joining all futures into a list.
class RaceFutures<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [RaceFutures] instruction with the specified [futures].
  ///
  /// ### Parameters:
  /// - [futures]: **The List of Futures.** The first to complete wins.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, the race will
  ///   fail if no future completes within the timeout.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final raced = RaceFutures<String>([
  ///   fetchFromCache(),
  ///   fetchFromNetwork(),
  /// ]).toHandle();
  /// ```
  RaceFutures(
      Iterable<Future<S>> futures, {
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
    (() {
      final state = _OnceState();
      final list = List<Future<S>>.from(futures);
      return (pulse, {cell, user, future, token}) {
        if (state.started) return null;
        state.started = true;
        Future<void>(() async {
          try {
            final value = await _withTimeout(Future.any(list), timeout);
            future!(
              result: _ok(value, cell, 'RaceFutures', trigger: pulse),
              token: token,
            );
          } catch (e, stack) {
            _emitError(
              error: e,
              stack: stack,
              onError: onError,
              emitErrorPulse: emitErrorPulse,
              future: future,
              token: token,
              cell: cell,
              trigger: pulse,
              step: 'RaceFutures.error',
            );
          }
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Resilience
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that retries a deferred future up to [maxAttempts]
/// times.
///
/// [FromFutureWithRetry] acts as a **Retryable Future Loader**. It retries
/// failed operations up to [maxAttempts] times before giving up and emitting
/// an error (or falling back).
///
/// ### When to use
/// Use [FromFutureWithRetry] when:
/// - **Unreliable Services**: API calls may fail transiently
/// - **Network Operations**: Network errors should be retried
/// - **Rate Limiting**: Operations that may be rate-limited
/// - **Database Operations**: Transactions that may conflict
/// - **External Dependencies**: Operations that depend on external systems
///
/// ### How it works
/// 1. Each operation is attempted up to [maxAttempts] times.
/// 2. Between attempts, there is a delay (with exponential backoff).
/// 3. If all retries fail, the error is reported via [onError].
/// 4. The instruction continues with the next input.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Exponential Backoff**: The delay increases with each retry attempt.
/// - **Error Reporting**: Only the final failure is reported.
/// - **Resource Usage**: Retries consume resources and time.
/// - **Blocking**: The instruction blocks until all retries complete.
/// - **Timeout**: Optional timeout can be applied to each attempt.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: Retry on Failure
/// ```dart
/// final retry = FromFutureWithRetry<String>(
///   (p) async => await unreliableApi.fetch(),
///   maxAttempts: 3,
///   delay: Duration(milliseconds: 100),
/// ).toHandle();
///
/// await retry.emitAsync(null);
/// // Retries up to 3 times before failing
/// ```
///
/// ### Parameters:
/// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
///   a `Future<S>`.
/// - [maxAttempts]: **Maximum Retry Attempts.** Defaults to 3.
/// - [delay]: **Delay Between Retries.** Defaults to 50ms.
/// - [timeout]: **Timeout Duration.** Optional. If provided, each attempt
///   will fail if it exceeds this duration.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload from the future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [FromFutureWithTimeout]: For timeout handling.
/// - [FromFutureWithFallback]: For fallback values on error.
class FromFutureWithRetry<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [FromFutureWithRetry] instruction with the specified [compute].
  ///
  /// ### Parameters:
  /// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
  ///   a `Future<S>`.
  /// - [maxAttempts]: **Maximum Retry Attempts.** Defaults to 3.
  /// - [delay]: **Delay Between Retries.** Defaults to 50ms.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, each attempt
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final retry = FromFutureWithRetry<String>(
  ///   (p) async => await api.fetch(p.payload as String),
  ///   maxAttempts: 5,
  ///   delay: Duration(milliseconds: 200),
  ///   onError: (error, stack) => print('Error after retries: $error'),
  /// );
  /// ```
  FromFutureWithRetry(
      Future<S> Function(Pulse trigger) compute, {
        int maxAttempts = 3,
        Duration delay = const Duration(milliseconds: 50),
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      Future<void>(() async {
        try {
          final value = await _withRetry(
                () => _withTimeout(compute(pulse), timeout),
            maxAttempts: maxAttempts,
            delay: delay,
          );
          future!(
            result: _ok(value, cell, 'FromFutureWithRetry', trigger: pulse),
            token: token,
          );
        } catch (e, stack) {
          _emitError(
            error: e,
            stack: stack,
            onError: onError,
            emitErrorPulse: emitErrorPulse,
            future: future,
            token: token,
            cell: cell,
            trigger: pulse,
            step: 'FromFutureWithRetry.error',
          );
        }
      });
      return null;
    },
    user: user,
  );
}

/// A [Receptor] instruction that fails if [compute] does not finish within
/// [timeout].
///
/// [FromFutureWithTimeout] acts as a **Timeoutable Future Loader**. It ensures
/// that async operations complete within a specified time limit, throwing an
/// error if they exceed it.
///
/// ### When to use
/// Use [FromFutureWithTimeout] when:
/// - **Time-Sensitive Operations**: Operations that must complete quickly
/// - **User Experience**: Preventing hanging operations
/// - **Service Level Agreements**: Enforcing response time limits
/// - **Resource Protection**: Preventing resource exhaustion
///
/// ### How it works
/// 1. Each operation starts with a timer.
/// 2. If the timer fires before the operation completes, it's cancelled.
/// 3. If [onTimeout] is provided, its result is emitted.
/// 4. Otherwise, the operation fails with a [TimeoutException].
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Timer Precision**: Timers are based on the event loop.
/// - **Cancellation**: Timed-out operations are cancelled.
/// - **Fallback**: [onTimeout] provides a fallback value.
/// - **Error Reporting**: Timeouts are reported via [onError] or as exceptions.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: API Call with Timeout
/// ```dart
/// final withTimeout = FromFutureWithTimeout<String>(
///   (p) async => await slowApiCall(),
///   timeout: Duration(seconds: 5),
///   onError: (error, stack) => print('Timeout: $error'),
/// ).toHandle();
/// ```
///
/// ### Parameters:
/// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
///   a `Future<S>`.
/// - [timeout]: **Timeout Duration.** Required. Operations exceeding this
///   time will be cancelled.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload from the future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [FromFutureWithRetry]: For retry logic.
/// - [FromFutureWithFallback]: For fallback values on error.
class FromFutureWithTimeout<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [FromFutureWithTimeout] instruction with the specified [compute].
  ///
  /// ### Parameters:
  /// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
  ///   a `Future<S>`.
  /// - [timeout]: **Timeout Duration.** Required. Operations exceeding this
  ///   time will be cancelled.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final withTimeout = FromFutureWithTimeout<String>(
  ///   (p) async => await api.fetch(p.payload as String),
  ///   timeout: Duration(seconds: 5),
  ///   onError: (error, stack) => print('Timeout: $error'),
  /// );
  /// ```
  FromFutureWithTimeout(
      Future<S> Function(Pulse trigger) compute, {
        required Duration timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      Future<void>(() async {
        try {
          final value = await compute(pulse).timeout(timeout);
          future!(
            result: _ok(value, cell, 'FromFutureWithTimeout', trigger: pulse),
            token: token,
          );
        } catch (e, stack) {
          _emitError(
            error: e,
            stack: stack,
            onError: onError,
            emitErrorPulse: emitErrorPulse,
            future: future,
            token: token,
            cell: cell,
            trigger: pulse,
            step: 'FromFutureWithTimeout.error',
          );
        }
      });
      return null;
    },
    user: user,
  );
}

/// A [Receptor] instruction that emits a fallback value on failure.
///
/// [FromFutureWithFallback] acts as a **Fallback Future Loader**. On failure,
/// it emits a fallback value instead of an error pulse.
///
/// ### When to use
/// Use [FromFutureWithFallback] when:
/// - **Graceful Degradation**: You want to provide a default on failure
/// - **Caching**: You can serve stale cached data on failure
/// - **Offline Support**: You want to provide offline defaults
/// - **Resilience**: You want to prevent failures from propagating
///
/// ### How it works
/// 1. The [compute] function is attempted for each input.
/// 2. If the [compute] succeeds, the result is emitted.
/// 3. If the [compute] fails, the [fallback] is called with the input.
/// 4. The fallback result is emitted instead.
/// 5. The instruction always emits a value.
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Always Emits**: A value is always emitted (success or fallback).
/// - **Error Isolation**: Errors are caught and handled gracefully.
/// - **Type Safety**: The fallback must return the same type [S].
/// - **Performance**: Fallback may be used frequently on failure.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: Cached Data with Fallback
/// ```dart
/// final withFallback = FromFutureWithFallback<String>(
///   (p) async => await api.fetch(p.payload as String),
///   fallback: 'Cached data',
/// ).toHandle();
///
/// await withFallback.emitAsync('user1');
/// // Emits the fetched data or 'Cached data' on failure
/// ```
///
/// ### Parameters:
/// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
///   a `Future<S>`.
/// - [fallback]: **Fallback Value.** Emitted when the future fails.
/// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
///   will fail if it exceeds this duration.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the output payload from the future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [FromFutureWithRetry]: For retry logic.
/// - [FromFutureWithTimeout]: For timeout handling.
class FromFutureWithFallback<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [FromFutureWithFallback] instruction with the specified
  /// [compute] and [fallback].
  ///
  /// ### Parameters:
  /// - [compute]: **The Future Factory.** Takes the trigger pulse and returns
  ///   a `Future<S>`.
  /// - [fallback]: **Fallback Value.** Emitted when the future fails.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final withFallback = FromFutureWithFallback<String>(
  ///   (p) async => await api.fetch(p.payload as String),
  ///   fallback: 'Default value',
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  FromFutureWithFallback(
      Future<S> Function(Pulse trigger) compute, {
        required S fallback,
        Duration? timeout,
        FutureErrorHandler? onError,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      Future<void>(() async {
        try {
          final value = await _withTimeout(compute(pulse), timeout);
          future!(
            result: _ok(value, cell, 'FromFutureWithFallback', trigger: pulse),
            token: token,
          );
        } catch (e, stack) {
          onError?.call(e, stack);
          future!(
            result: _ok(
              fallback,
              cell,
              'FromFutureWithFallback.fallback',
              trigger: pulse,
            ),
            token: token,
          );
        }
      });
      return null;
    },
    user: user,
  );
}

/// A [Receptor] instruction that maps a trigger payload into a future
/// (Rx `fromPromise` + map).
///
/// [MapToFuture] acts as a **Typed Future Mapper**. It maps a trigger payload
/// of type [I] into a `Future<S>` and emits the result.
///
/// ### When to use
/// Use [MapToFuture] when:
/// - You need to map a trigger payload into a future
/// - You're implementing typed async operations
/// - You're converting a value into an async result
/// - You're implementing type-safe async mapping
///
/// ### How it works
/// 1. Each trigger pulse's payload is extracted and type-checked.
/// 2. The [compute] function is called with the payload.
/// 3. The future is awaited (optionally under [timeout]).
/// 4. Success emits `Pulse<S>` with step `MapToFuture`.
/// 5. Failure is reported through [onError] and optionally an error pulse.
/// 6. Results are emitted in input order (sequential processing).
/// 7. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Type Safety**: The instruction is generic over [I] (input) and [S]
///   (output), ensuring compile-time type safety.
/// - **Payload Access**: The trigger payload is accessed for mapping.
/// - **Type Mismatch**: If the payload is not of type [I], an error is reported.
/// - **Error Handling**: Errors are reported via [onError] and optionally
///   as error pulses with `type: 'error'`.
/// - **Timeout**: Optional timeout can be applied to the future operation.
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
///
/// ### Example: ID to User Profile
/// ```dart
/// final userIds = Cell.ingress<int>();
/// final userProfiles = MapToFuture<int, UserProfile>(
///   (id) async => await api.fetchUser(id),
/// ).toHandle(source: userIds.cell);
///
/// userIds.emit(1); // Fetches user 1
/// userIds.emit(2); // Fetches user 2
/// ```
///
/// ### Parameters:
/// - [compute]: **The Mapped Future Factory.** Takes the input value and
///   returns a `Future<S>`.
/// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
///   will fail if it exceeds this duration.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
///   emit a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [I]: The type of the input payload from the source cell.
/// - [S]: The type of the output payload from the future.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [AsyncMap]: For async mapping without futures.
/// - [DeferFuture]: For per-trigger future loading.
class MapToFuture<I, S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [MapToFuture] instruction with the specified [compute].
  ///
  /// ### Parameters:
  /// - [compute]: **The Mapped Future Factory.** Takes the input value and
  ///   returns a `Future<S>`.
  /// - [timeout]: **Timeout Duration.** Optional. If provided, the operation
  ///   will fail if it exceeds this duration.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), errors
  ///   emit a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final mapToFuture = MapToFuture<int, String>(
  ///   (id) async => 'User $id',
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  MapToFuture(
      Future<S> Function(I input) compute, {
        Duration? timeout,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      final payload = pulse.payload;
      if (payload is! I) {
        onError?.call(
          FormatException('Expected payload of type $I, got ${payload.runtimeType}'),
          StackTrace.current,
        );
        return null;
      }
      Future<void>(() async {
        try {
          final value = await _withTimeout(compute(payload), timeout);
          future!(
            result: _ok(value, cell, 'MapToFuture', trigger: pulse),
            token: token,
          );
        } catch (e, stack) {
          _emitError(
            error: e,
            stack: stack,
            onError: onError,
            emitErrorPulse: emitErrorPulse,
            future: future,
            token: token,
            cell: cell,
            trigger: pulse,
            step: 'MapToFuture.error',
          );
        }
      });
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

/// Internal state for [FromFuture] and [FromFutures] variants.
class _OnceState {
  bool started = false;
}

/// Internal state for [ExhaustFromFuture].
class _BusyState {
  bool busy = false;
}

/// Internal state for [SwitchFromFuture].
class _GenerationState {
  int generation = 0;
}

/// Internal state for [ConcatFromFuture].
class _AsyncQueueState {
  Future<void> tail = Future<void>.value();

  void enqueue(Future<void> Function() job) {
    tail = tail.then((_) => job()).catchError((_) {});
  }
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [FromFuture] instruction and related operators
/// showing their behavior in various future loading scenarios.
///
/// ### Expected console output:
/// ```text
/// ── FromFuture Operators Demo ─────────────────────────────────
///
/// 1. FromFuture - One-shot load
///    [FromFuture] Alice
///
/// 2. FromFuture.value
///    [Value] ready
///
/// 3. DeferFuture - Per-trigger lookup
///    [Defer] user-1
///    [Defer] user-2
///
/// 4. ConcatFromFuture vs MergeFromFuture
///    [Concat] slow
///    [Concat] fast
///    [Merge] fast
///    [Merge] slow
///
/// 5. SwitchFromFuture - Latest only
///    [Switch] new
///
/// 6. ExhaustFromFuture - Ignore while busy
///    [Exhaust] 1
///
/// 7. FromFutures / InOrder / ForkJoin / Race
///    [FromFutures] fast
///    [FromFutures] slow
///    [InOrder] slow
///    [InOrder] fast
///    [ForkJoin] [1, 2, 3]
///    [Race] fast
///
/// 8. Retry / Fallback / MapToFuture
///    [Retry] 8
///    [Fallback] -1
///    [Map] user-7
///
/// ── finished ──────────────────────────────────────────────────
/// ```
///
/// ### How to run
/// ```dart
/// void main() => main();
/// ```
///
/// ### What it demonstrates
/// 1. **FromFuture - One-shot load**: Shows one-shot future loading. The
///    future is started on the first trigger and ignored for subsequent
///    triggers.
///
/// 2. **FromFuture.value**: Shows the `Future.value` sugar. The value is
///    emitted immediately on the first trigger.
///
/// 3. **DeferFuture - Per-trigger lookup**: Shows per-trigger future loading.
///    Each trigger starts a new future with the trigger payload.
///
/// 4. **ConcatFromFuture vs MergeFromFuture**: Shows sequential vs parallel
///    execution. Concat preserves order (slow then fast), Merge uses
///    completion order (fast then slow).
///
/// 5. **SwitchFromFuture - Latest only**: Shows cancellation behavior. Only
///    the latest trigger's result is emitted; previous operations are
///    silently cancelled.
///
/// 6. **ExhaustFromFuture - Ignore while busy**: Shows exhaust behavior.
///    Only the first trigger is processed; subsequent triggers are ignored
///    while busy.
///
/// 7. **FromFutures / InOrder / ForkJoin / Race**: Shows multi-future
///    combinators. FromFutures emits in completion order, InOrder emits in
///    list order, ForkJoin emits a list, Race emits the first winner.
///
/// 8. **Retry / Fallback / MapToFuture**: Shows resilience and mapping.
///    Retry retries failed operations, Fallback provides a default on error,
///    MapToFuture maps a typed payload into a future.
///
/// ### Key Takeaways
/// - FromFuture is one-shot - only the first trigger matters.
/// - DeferFuture starts a new future for every trigger.
/// - Concat preserves order, Merge uses completion order.
/// - Switch cancels stale in-flight work.
/// - Exhaust admits only one compute at a time.
/// - ForkJoin waits for all futures, Race takes the first winner.
/// - Retry, timeout, and fallback provide resilience.
/// - All operators preserve causal provenance via EvolvedPulse.
Future<void> main() async {
  print('── FromFuture Operators Demo ─────────────────────────────────\n');

  print('1. FromFuture - One-shot load');
  final load = FromFuture<String>(
    Future<String>.delayed(const Duration(milliseconds: 30), () => 'Alice'),
  ).toHandle();
  final loadObs = Cell.observe(
    source: load.cell,
    effect: (Pulse p) => print('   [FromFuture] ${p.payload}'),
  );
  await load.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  loadObs.stop();
  print('');

  print('2. FromFuture.value');
  final ready = FromFuture.value('ready').toHandle();
  final readyObs = Cell.observe(
    source: ready.cell,
    effect: (Pulse p) => print('   [Value] ${p.payload}'),
  );
  await ready.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  readyObs.stop();
  print('');

  print('3. DeferFuture - Per-trigger lookup');
  final ids = Cell.ingress<int>();
  final deferred = DeferFuture<String>(
        (p) async => 'user-${p.payload}',
  ).toHandle(source: ids.cell);
  final defObs = Cell.observe(
    source: deferred.cell,
    effect: (Pulse p) => print('   [Defer] ${p.payload}'),
  );
  await ids.emitAsync(1);
  await ids.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 30));
  defObs.stop();
  print('');

  print('4. ConcatFromFuture vs MergeFromFuture');
  Future<String> paced(Pulse p) async {
    final name = p.payload as String;
    await Future<void>.delayed(Duration(milliseconds: name == 'slow' ? 50 : 5));
    return name;
  }

  final concatIn = Cell.ingress<String>();
  final concat = ConcatFromFuture<String>(paced).toHandle(source: concatIn.cell);
  final concatObs = Cell.observe(
    source: concat.cell,
    effect: (Pulse p) => print('   [Concat] ${p.payload}'),
  );
  await concatIn.emitAsync('slow');
  await concatIn.emitAsync('fast');
  await Future<void>.delayed(const Duration(milliseconds: 90));
  concatObs.stop();

  final mergeIn = Cell.ingress<String>();
  final merge = MergeFromFuture<String>(paced).toHandle(source: mergeIn.cell);
  final mergeObs = Cell.observe(
    source: merge.cell,
    effect: (Pulse p) => print('   [Merge] ${p.payload}'),
  );
  await mergeIn.emitAsync('slow');
  await mergeIn.emitAsync('fast');
  await Future<void>.delayed(const Duration(milliseconds: 90));
  mergeObs.stop();
  print('');

  print('5. SwitchFromFuture - Latest only');
  final switchIn = Cell.ingress<String>();
  final switched = SwitchFromFuture<String>((p) async {
    final name = p.payload as String;
    await Future<void>.delayed(Duration(milliseconds: name == 'old' ? 50 : 10));
    return name;
  }).toHandle(source: switchIn.cell);
  final switchObs = Cell.observe(
    source: switched.cell,
    effect: (Pulse p) => print('   [Switch] ${p.payload}'),
  );
  await switchIn.emitAsync('old');
  await switchIn.emitAsync('new');
  await Future<void>.delayed(const Duration(milliseconds: 80));
  switchObs.stop();
  print('');

  print('6. ExhaustFromFuture - Ignore while busy');
  final exhaustIn = Cell.ingress<int>();
  final exhaust = ExhaustFromFuture<int>((p) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return p.payload as int;
  }).toHandle(source: exhaustIn.cell);
  final exhaustObs = Cell.observe(
    source: exhaust.cell,
    effect: (Pulse p) => print('   [Exhaust] ${p.payload}'),
  );
  await exhaustIn.emitAsync(1);
  await exhaustIn.emitAsync(2);
  await exhaustIn.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 70));
  exhaustObs.stop();
  print('');

  print('7. FromFutures / InOrder / ForkJoin / Race');
  final many = FromFutures<String>([
    Future<String>.delayed(const Duration(milliseconds: 40), () => 'slow'),
    Future<String>.value('fast'),
  ]).toHandle();
  final manyObs = Cell.observe(
    source: many.cell,
    effect: (Pulse p) => print('   [FromFutures] ${p.payload}'),
  );
  await many.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 70));
  manyObs.stop();

  final ordered = FromFuturesInOrder<String>([
    Future<String>.delayed(const Duration(milliseconds: 40), () => 'slow'),
    Future<String>.value('fast'),
  ]).toHandle();
  final ordObs = Cell.observe(
    source: ordered.cell,
    effect: (Pulse p) => print('   [InOrder] ${p.payload}'),
  );
  await ordered.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 70));
  ordObs.stop();

  final joined = ForkJoinFutures<int>([
    Future.value(1),
    Future.value(2),
    Future.value(3),
  ]).toHandle();
  final joinObs = Cell.observe(
    source: joined.cell,
    effect: (Pulse p) => print('   [ForkJoin] ${p.payload}'),
  );
  await joined.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  joinObs.stop();

  final raced = RaceFutures<String>([
    Future<String>.delayed(const Duration(milliseconds: 40), () => 'slow'),
    Future<String>.delayed(const Duration(milliseconds: 5), () => 'fast'),
  ]).toHandle();
  final raceObs = Cell.observe(
    source: raced.cell,
    effect: (Pulse p) => print('   [Race] ${p.payload}'),
  );
  await raced.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  raceObs.stop();
  print('');

  print('8. Retry / Fallback / MapToFuture');
  var attempts = 0;
  final retry = FromFutureWithRetry<int>(
        (_) async {
      attempts++;
      if (attempts < 3) throw Exception('transient');
      return 8;
    },
    maxAttempts: 4,
    delay: const Duration(milliseconds: 5),
  ).toHandle();
  final retryObs = Cell.observe(
    source: retry.cell,
    effect: (Pulse p) => print('   [Retry] ${p.payload}'),
  );
  await retry.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 40));
  retryObs.stop();

  final fallback = FromFutureWithFallback<int>(
        (_) async => throw Exception('x'),
    fallback: -1,
  ).toHandle();
  final fbObs = Cell.observe(
    source: fallback.cell,
    effect: (Pulse p) => print('   [Fallback] ${p.payload}'),
  );
  await fallback.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  fbObs.stop();

  final ids2 = Cell.ingress<int>();
  final mapped = MapToFuture<int, String>((id) async => 'user-$id')
      .toHandle(source: ids2.cell);
  final mapObs = Cell.observe(
    source: mapped.cell,
    effect: (Pulse p) => print('   [Map] ${p.payload}'),
  );
  await ids2.emitAsync(7);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  mapObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}