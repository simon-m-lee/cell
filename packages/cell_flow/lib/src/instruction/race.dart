// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

/// Flow instructions that forward the first inner to emit (Rx `race` family).
///
/// These operators implement the **race** strategy: multiple competitors
/// are started concurrently, and the first one to produce a value wins.
/// All other competitors are cancelled or ignored.
///
/// | Operator | Rx analogue | Winner |
/// |---|---|---|
/// | [Race] | `race` / `amb` | first competitor to produce a value |
/// | [RaceFirst] | `race` + `take(1)` | first value only; later winners ignored |
/// | [RaceMap] | map + `race` | payload → competitors; first inner wins |
/// | [RaceWith] | `raceWith` | source inner vs a side competitor |
/// | [RaceUntil] | `race` vs timer | value or timeout error |
///
/// A competitor may be a [Stream], [Future], [Iterable], raw value, or
/// `null`. After a winner is chosen, remaining competitors are ignored
/// (streams are cancelled when we hold a subscription).
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef RaceErrorHandler = void Function(Object error, StackTrace? stackTrace);

Pulse<T> _out<T>(T value, Cell? cell, Pulse trigger, String step) {
  return Pulse<T>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

Pulse _err(Object error, Cell? cell, Pulse trigger, String step) {
  return Pulse(
    error,
    source: cell ?? trigger.source,
    type: 'error',
    priority: trigger.priority,
    step: step,
  );
}

/// Drain [inner] until the first matching [T], then stop.
Future<T?> _firstOf<T>(
    Object? inner, {
      bool Function()? stillLive,
    }) async {
  if (inner == null) return null;
  if (stillLive != null && !stillLive()) return null;

  if (inner is Stream) {
    await for (final event in inner) {
      if (stillLive != null && !stillLive()) return null;
      final nested = await _firstOf<T>(event, stillLive: stillLive);
      if (nested != null) return nested;
    }
    return null;
  }

  if (inner is Future) {
    final value = await inner;
    return _firstOf<T>(value, stillLive: stillLive);
  }

  if (inner is Iterable && inner is! String) {
    for (final event in inner) {
      if (stillLive != null && !stillLive()) return null;
      final nested = await _firstOf<T>(event, stillLive: stillLive);
      if (nested != null) return nested;
    }
    return null;
  }

  if (inner is T) return inner as T;
  return null;
}

Future<void> _raceList<T>({
  required Iterable<Object?> competitors,
  required void Function(T value) onWin,
  required void Function(Object error, StackTrace stack)? onError,
  required bool Function() stillLive,
  required void Function() markWon,
}) async {
  final list = competitors.toList();
  if (list.isEmpty) return;

  await Future.any(list.map((inner) async {
    try {
      final value = await _firstOf<T>(inner, stillLive: stillLive);
      if (value == null || !stillLive()) return;
      markWon();
      onWin(value);
    } catch (e, stack) {
      if (!stillLive()) return;
      onError?.call(e, stack);
    }
  }));
}

// ─────────────────────────────────────────────────────────────
// Race
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that forwards the first competitor to produce
/// a value (Rx `race` / `amb`).
///
/// [Race] acts as a **Competitive Selector**. Multiple competitors are
/// started concurrently, and the first one to produce a value of type [T]
/// wins. All other competitors are ignored.
///
/// ### When to use
/// Use [Race] when you have multiple sources of the same data and you want
/// the fastest one:
///
/// - **Fastest Response**: You want the fastest response from multiple sources
/// - **Redundant Services**: You have redundant services for reliability
/// - **Cache vs Network**: You want to race cache against network
/// - **Multiple APIs**: You want to try multiple APIs in parallel
/// - **Fallback Sources**: You want to try primary then fallback
/// - **Load Balancing**: You want to pick the fastest replica
/// - **Performance Optimization**: You want to minimize latency
/// - **Reliability**: You want to tolerate failures from individual sources
///
/// ### Choosing Between Race Patterns
/// - **Use [Race]** for **Full Race**: When you want the first value from
///   any competitor.
/// - **Use [RaceFirst]** for **First Value Only**: When you only want the
///   very first value and ignore subsequent emissions.
/// - **Use [RaceMap]** for **Dynamic Competitors**: When competitors depend
///   on the trigger payload.
/// - **Use [RaceWith]** for **Side Competition**: When you want to race
///   the source against a side competitor.
/// - **Use [RaceUntil]** for **Timeout**: When you want to race against a
///   timeout.
///
/// ### Comparison with Other Operators
/// | Operator | Competitors | Trigger | Winner |
/// |----------|-------------|---------|--------|
/// | **Race** | Static | First trigger | First value |
/// | **RaceFirst** | Static | First trigger | First value only |
/// | **RaceMap** | Dynamic | Each trigger | First value |
/// | **RaceWith** | Side | Each trigger | First value |
/// | **RaceUntil** | Timeout | Each trigger | Value or timeout |
/// | **MergeMap** | Multiple | Each trigger | All values |
///
/// ### How it works
/// 1. The first trigger starts all competitors concurrently.
/// 2. Each competitor is drained until it produces a value of type [T].
/// 3. The first competitor to produce a value wins.
/// 4. The winning value is emitted as a [Pulse].
/// 5. All other competitors are ignored.
/// 6. Later triggers are ignored (race is one-shot).
/// 7. The instruction preserves causal provenance.
///
/// ### Supported Competitor Types
/// Each competitor can be any of the following:
/// - **[Stream\<T\>]**: The first event in the stream wins.
/// - **[Future\<T\>]**: The future's value wins.
/// - **[Iterable\<T\>]**: The first element wins.
/// - **[T]**: The value itself wins immediately.
/// - **`null`**: The competitor is ignored (no emission).
/// - **Nested combinations**: `Future<Iterable<T>>`, `Stream<Future<T>>`,
///   etc., are recursively expanded.
///
/// ### Non‑obvious
/// - **One-Shot**: The race is started on the first trigger only.
/// - **Concurrent**: All competitors are started concurrently.
/// - **First Value Wins**: Only the first value from any competitor is emitted.
/// - **Streams are Cancelled**: Streams that lose are cancelled.
/// - **Error Handling**: Errors are reported via [onError].
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
/// - **Type Safety**: The instruction is generic over [T] (output type).
///
/// ### Example: Fastest API Response
/// ```dart
/// final start = Cell.ingress<void>();
/// final raced = Race<String>([
///   Future.delayed(Duration(milliseconds: 40), () => 'slow'),
///   Future.delayed(Duration(milliseconds: 5), () => 'fast'),
/// ]).toHandle(source: start.cell);
///
/// await start.emitAsync(null); // Emits 'fast'
/// ```
///
/// ### Example: Cache vs Network
/// ```dart
/// final request = Cell.ingress<String>();
/// val data = Race<String>([
///   cache.get(request.payload), // Fast, may miss
///   network.fetch(request.payload), // Slow, always available
/// ]).toHandle(source: request.cell);
/// ```
///
/// ### Parameters:
/// - [competitors]: **The Competitors.** An iterable of sources to race.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [T]: The type of the output payload from the winner.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [RaceFirst]: For only the first value.
/// - [RaceMap]: For dynamic competitors.
/// - [RaceWith]: For side competition.
/// - [RaceUntil]: For timeout-based racing.
class Race<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [Race] instruction with the specified [competitors].
  ///
  /// ### Parameters:
  /// - [competitors]: **The Competitors.** An iterable of sources to race.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final race = Race<String>([
  ///   Future.value('fast'),
  ///   Future.delayed(Duration(seconds: 1), () => 'slow'),
  /// ]).toHandle();
  /// ```
  Race(
      Iterable<Object?> competitors, {
        RaceErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final started = _OnceState();
      final gen = _GenerationState();
      final snapshot = List<Object?>.from(competitors);
      return (pulse, {cell, user, future, token}) {
        if (started.done) return null;
        started.done = true;
        final id = ++gen.generation;
        Future<void>(() async {
          await _raceList<T>(
            competitors: snapshot,
            stillLive: () => id == gen.generation,
            markWon: () => gen.generation++,
            onWin: (value) {
              future!(
                result: _out<T>(value, cell, pulse, 'Race'),
                token: token,
              );
            },
            onError: onError,
          );
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// RaceFirst
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that forwards only the first winning value
/// (Rx `race` + `take(1)`).
///
/// [RaceFirst] acts as a **First-Value Race**. It is similar to [Race] but
/// only the very first winning value is forwarded. Extra emissions from a
/// winning stream are ignored.
///
/// ### When to use
/// Use [RaceFirst] when:
/// - You only care about the first value from any competitor
/// - You want to ignore subsequent emissions from the winner
/// - You're implementing a "first success" pattern
/// - You're tracking the initial response
/// - You're implementing a timeout with only the first response
/// - You're reducing multiple sources to a single initial value
///
/// ### How it works
/// 1. The first trigger starts all competitors concurrently.
/// 2. Each competitor is drained until it produces a value of type [T].
/// 3. The first competitor to produce a value wins.
/// 4. Only the very first winning value is emitted.
/// 5. All other competitors are ignored.
/// 6. All subsequent emissions from the winner are ignored.
/// 7. Later triggers are ignored.
/// 8. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **First Value Only**: Only the very first winning value is emitted.
/// - **Streams are Cancelled**: Streams that lose are cancelled.
/// - **Winner's Emissions are Ignored**: Only the first value from the
///   winner is emitted; subsequent values are ignored.
/// - **One-Shot**: The race is started on the first trigger only.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: First Response Only
/// ```dart
/// val first = RaceFirst<String>([
///   Stream.fromIterable(['a', 'b', 'c']),
///   Future.delayed(Duration(milliseconds: 20), () => 'd'),
/// ]).toHandle();
///
/// await start.emitAsync(null); // Emits 'a' only
/// // 'b' and 'c' are ignored
/// ```
///
/// ### Parameters:
/// - [competitors]: **The Competitors.** An iterable of sources to race.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [T]: The type of the output payload from the winner.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [Race]: For all values from the winner.
/// - [RaceMap]: For dynamic competitors.
class RaceFirst<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [RaceFirst] instruction with the specified [competitors].
  ///
  /// ### Parameters:
  /// - [competitors]: **The Competitors.** An iterable of sources to race.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final raceFirst = RaceFirst<String>([
  ///   Stream.fromIterable(['first', 'second']),
  ///   Future.value('fast'),
  /// ]).toHandle();
  /// ```
  RaceFirst(
      Iterable<Object?> competitors, {
        RaceErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final started = _OnceState();
      var won = false;
      return (pulse, {cell, user, future, token}) {
        if (started.done) return null;
        started.done = true;
        Future<void>(() async {
          await _raceList<T>(
            competitors: List<Object?>.from(competitors),
            stillLive: () => !won,
            markWon: () => won = true,
            onWin: (value) {
              future!(
                result: _out<T>(value, cell, pulse, 'RaceFirst'),
                token: token,
              );
            },
            onError: onError,
          );
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// RaceMap
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that maps a trigger payload to a set of
/// competitors and races them.
///
/// [RaceMap] acts as a **Dynamic Race**. Each trigger starts a new race
/// with competitors generated from the payload. In-flight races are
/// invalidated (latest-race-wins).
///
/// ### When to use
/// Use [RaceMap] when:
/// - Competitors depend on the trigger payload
/// - You want to race different sources for different inputs
/// - You're implementing dynamic source selection
/// - You're racing based on user input
/// - You're implementing a cache with key-based fallbacks
/// - You're selecting the fastest source for each query
///
/// ### How it works
/// 1. Each trigger payload is extracted and type-checked.
/// 2. The [mapper] function is called with the payload to generate competitors.
/// 3. The competitors are started concurrently.
/// 4. The first competitor to produce a value wins.
/// 5. Any in-flight race is invalidated (latest-race-wins).
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Dynamic Competitors**: Competitors are generated from the payload.
/// - **Latest-Race-Wins**: Each new trigger invalidates the previous race.
/// - **Type Safety**: The instruction is generic over [S] (input) and [T] (output).
/// - **Error Handling**: Errors are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Key-Based Racing
/// ```dart
/// final ids = Cell.ingress<int>();
/// final raced = RaceMap<int, String>((id) => [
///   Future.delayed(Duration(milliseconds: 30), () => 'net-$id'),
///   Future.value('cache'),
/// ]).toHandle(source: ids.cell);
///
/// ids.emit(1); // Races 'cache' vs 'net-1'
/// ids.emit(2); // Invalidates previous race, starts new
/// ```
///
/// ### Parameters:
/// - [mapper]: **The Competitor Factory.** Takes the input value and returns
///   an iterable of competitors.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload from the winner.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [Race]: For static competitors.
/// - [RaceWith]: For side competition.
class RaceMap<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [RaceMap] instruction with the specified [mapper].
  ///
  /// ### Parameters:
  /// - [mapper]: **The Competitor Factory.** Takes the input value and returns
  ///   an iterable of competitors.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final raceMap = RaceMap<int, String>(
  ///   (id) => [fetchFromCache(id), fetchFromNetwork(id)],
  /// ).toHandle();
  /// ```
  RaceMap(
      FutureOr<Iterable<Object?>> Function(S value) mapper, {
        RaceErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final gen = _GenerationState();
      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! S) {
          onError?.call(
            FormatException(
              'Expected payload of type $S, got ${payload.runtimeType}',
            ),
            StackTrace.current,
          );
          return null;
        }
        final id = ++gen.generation;
        Future<void>(() async {
          try {
            final competitors = await mapper(payload);
            if (id != gen.generation) return;
            var won = false;
            await _raceList<T>(
              competitors: competitors,
              stillLive: () => id == gen.generation && !won,
              markWon: () => won = true,
              onWin: (value) {
                future!(
                  result: _out<T>(value, cell, pulse, 'RaceMap'),
                  token: token,
                );
              },
              onError: (e, stack) {
                if (id == gen.generation) onError?.call(e, stack);
              },
            );
          } catch (e, stack) {
            if (id == gen.generation) onError?.call(e, stack);
          }
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// RaceWith
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that races the mapped source inner against a
/// side competitor (Rx `raceWith`).
///
/// [RaceWith] acts as a **Side-by-Side Race**. It races the source inner
/// (derived from the payload) against a fixed side competitor.
///
/// ### When to use
/// Use [RaceWith] when:
/// - You want to race the source against a fixed competitor
/// - You're implementing a timeout with a side timer
/// - You're racing a dynamic source against a static fallback
/// - You're implementing a cache with a fixed fallback
/// - You're racing a network request against a local cache
/// - You're implementing a primary-secondary pattern
///
/// ### How it works
/// 1. Each trigger payload is extracted and type-checked.
/// 2. The [mapper] function is called with the payload to generate the source inner.
/// 3. The [other] function is called to generate the side competitor.
/// 4. Both competitors are started concurrently.
/// 5. The first to produce a value wins.
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Side-by-Side**: The source inner races against a fixed side competitor.
/// - **Dynamic Source**: The source inner is derived from the payload.
/// - **Fixed Other**: The side competitor is fixed (same for all triggers).
/// - **Error Handling**: Errors are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Cache vs Network
/// ```dart
/// final requests = Cell.ingress<String>();
/// val raced = RaceWith<String, String>(
///   (query) => network.fetch(query),
///   other: () => cache.get('default'),
/// ).toHandle(source: requests.cell);
///
/// requests.emit('hello'); // Races network vs cache
/// ```
///
/// ### Parameters:
/// - [mapper]: **The Source Inner Factory.** Takes the input value and
///   returns the source competitor.
/// - [other]: **The Side Competitor Factory.** Returns the fixed side competitor.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload from the winner.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [Race]: For static competitors.
/// - [RaceMap]: For dynamic competitors.
class RaceWith<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [RaceWith] instruction with the specified [mapper] and [other].
  ///
  /// ### Parameters:
  /// - [mapper]: **The Source Inner Factory.** Takes the input value and
  ///   returns the source competitor.
  /// - [other]: **The Side Competitor Factory.** Returns the fixed side competitor.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final raceWith = RaceWith<int, String>(
  ///   (id) => fetchFromNetwork(id),
  ///   other: () => Future.value('fallback'),
  /// ).toHandle();
  /// ```
  RaceWith(
      FutureOr<Object?> Function(S value) mapper, {
        required FutureOr<Object?> Function() other,
        RaceErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final gen = _GenerationState();
      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! S) {
          onError?.call(
            FormatException(
              'Expected payload of type $S, got ${payload.runtimeType}',
            ),
            StackTrace.current,
          );
          return null;
        }
        final id = ++gen.generation;
        Future<void>(() async {
          try {
            // Do not await here — _raceList/_firstOf await in parallel.
            final left = mapper(payload);
            final right = other();
            if (id != gen.generation) return;
            var won = false;
            await _raceList<T>(
              competitors: [left, right],
              stillLive: () => id == gen.generation && !won,
              markWon: () => won = true,
              onWin: (value) {
                future!(
                  result: _out<T>(value, cell, pulse, 'RaceWith'),
                  token: token,
                );
              },
              onError: (e, stack) {
                if (id == gen.generation) onError?.call(e, stack);
              },
            );
          } catch (e, stack) {
            if (id == gen.generation) onError?.call(e, stack);
          }
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// RaceUntil
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that races [mapper] against a timeout
/// (Rx `race` vs timer).
///
/// [RaceUntil] acts as a **Timeout Race**. If the timer wins, an error pulse
/// is emitted. This is useful for implementing timeouts on asynchronous
/// operations.
///
/// ### When to use
/// Use [RaceUntil] when:
/// - You want to implement a timeout on an async operation
/// - You want to fail fast if an operation takes too long
/// - You're implementing a timeout for user experience
/// - You're enforcing service level agreements
/// - You're preventing hanging operations
/// - You're implementing a circuit breaker
/// - You're protecting resources from long-running operations
///
/// ### How it works
/// 1. Each trigger payload is extracted and type-checked.
/// 2. The [mapper] function is called with the payload to generate the source inner.
/// 3. The source inner races against a timer of the specified [timeout].
/// 4. If the source inner produces a value first, the value is emitted.
/// 5. If the timer fires first, a [TimeoutException] error pulse is emitted.
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Timeout**: The source inner races against a timer.
/// - **Error Pulse**: If the timer wins, a [TimeoutException] error pulse is emitted.
/// - **Silent Timeout**: If [emitErrorPulse] is false, the error is not emitted.
/// - **Error Handling**: Errors are reported via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: API Call with Timeout
/// ```dart
/// final requests = Cell.ingress<String>();
/// val timed = RaceUntil<String, String>(
///   (query) => api.fetch(query),
///   timeout: Duration(seconds: 5),
/// ).toHandle(source: requests.cell);
///
/// requests.emit('hello'); // Emits result or TimeoutException
/// ```
///
/// ### Example: Database Query with Timeout
/// ```dart
/// final queries = Cell.ingress<String>();
/// val dbQuery = RaceUntil<String, List<Result>>(
///   (sql) => database.query(sql),
///   timeout: Duration(seconds: 10),
///   onError: (e, stack) => print('Query timed out: $e'),
/// ).toHandle(source: queries.cell);
/// ```
///
/// ### Parameters:
/// - [mapper]: **The Source Inner Factory.** Takes the input value and
///   returns the source competitor.
/// - [timeout]: **The Timeout Duration.** The maximum time to wait for the
///   source inner to produce a value.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), a timeout
///   emits a pulse with `type: 'error'`.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload from the winner.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [Race]: For racing multiple competitors.
/// - [RaceWith]: For side competition.
/// - [FromFutureWithTimeout]: For a simpler timeout pattern.
class RaceUntil<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [RaceUntil] instruction with the specified [mapper] and [timeout].
  ///
  /// ### Parameters:
  /// - [mapper]: **The Source Inner Factory.** Takes the input value and
  ///   returns the source competitor.
  /// - [timeout]: **The Timeout Duration.** The maximum time to wait.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [emitErrorPulse]: **Emit Error Pulse.** If `true` (default), a timeout
  ///   emits a pulse with `type: 'error'`.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val raceUntil = RaceUntil<String, String>(
  ///   (query) => api.fetch(query),
  ///   timeout: Duration(seconds: 5),
  ///   onError: (e, stack) => print('Timeout: $e'),
  /// );
  /// ```
  RaceUntil(
      FutureOr<Object?> Function(S value) mapper, {
        required Duration timeout,
        RaceErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      }) : super.future(
    (() {
      final gen = _GenerationState();
      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! S) {
          onError?.call(
            FormatException(
              'Expected payload of type $S, got ${payload.runtimeType}',
            ),
            StackTrace.current,
          );
          return null;
        }
        final id = ++gen.generation;
        Future<void>(() async {
          try {
            final inner = mapper(payload);
            final winner = await Future.any<Object>([
                  () async {
                final first = await _firstOf<T>(
                  inner,
                  stillLive: () => id == gen.generation,
                );
                return first ?? Object();
              }(),
              Future<Object>.delayed(timeout, () => TimeoutException('RaceUntil', timeout)),
            ]);
            if (id != gen.generation) return;
            if (winner is TimeoutException) {
              onError?.call(winner, StackTrace.current);
              if (emitErrorPulse) {
                future!(
                  result: _err(winner, cell, pulse, 'RaceUntil.error'),
                  token: token,
                );
              }
              return;
            }
            if (winner is T) {
              future!(
                result: _out<T>(winner as T, cell, pulse, 'RaceUntil'),
                token: token,
              );
            }
          } catch (e, stack) {
            if (id == gen.generation) onError?.call(e, stack);
          }
        });
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

/// Internal state for one-shot operators.
class _OnceState {
  bool done = false;
}

/// Internal state for generation-based operators.
class _GenerationState {
  int generation = 0;
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Race] instruction and related operators
/// showing their behavior in various racing scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Race Operators Demo ───────────────────────────────────────
///
/// 1. Race - fastest future
///    [Race] fast
///
/// 2. RaceFirst - first value only
///    [RaceFirst] a
///
/// 3. RaceMap - payload picks the field
///    [RaceMap] cache
///
/// 4. RaceWith - source vs other
///    [RaceWith] side
///
/// 5. RaceUntil - timeout
///    [RaceUntil] TimeoutException
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
/// 1. **Race - fastest future**: Shows basic racing behavior. Multiple
///    futures are started concurrently, and the fastest one wins.
///    `slow` vs `fast` → `fast`.
///
/// 2. **RaceFirst - first value only**: Shows first-value-only racing.
///    Only the very first winning value is emitted; subsequent emissions
///    from the winner are ignored. `['a', 'b']` vs `'c'` → `'a'`.
///
/// 3. **RaceMap - payload picks the field**: Shows dynamic racing with
///    competitors generated from the payload. The payload determines
///    which competitors are raced.
///
/// 4. **RaceWith - source vs other**: Shows side-by-side racing. The
///    source inner races against a fixed side competitor.
///    `src` vs `side` → `side` (faster).
///
/// 5. **RaceUntil - timeout**: Shows timeout racing. If the source inner
///    takes too long, a timeout error pulse is emitted.
///    `late` (80ms) vs `timeout` (15ms) → `TimeoutException`.
///
/// ### Key Takeaways
/// - All race operators start competitors concurrently.
/// - The first competitor to produce a value wins.
/// - Race is one-shot on the first trigger.
/// - RaceFirst emits only the very first winning value.
/// - RaceMap generates competitors dynamically from the payload.
/// - RaceWith races against a fixed side competitor.
/// - RaceUntil implements timeout-based racing.
/// - All operators preserve causal provenance via EvolvedPulse.
Future<void> main() async {
  print('── Race Operators Demo ───────────────────────────────────────\n');

  print('1. Race - fastest future');
  final start = Cell.ingress<void>();
  final raced = Race<String>([
    Future<String>.delayed(const Duration(milliseconds: 40), () => 'slow'),
    Future<String>.delayed(const Duration(milliseconds: 5), () => 'fast'),
  ]).toHandle(source: start.cell);
  final rObs = Cell.observe(
    source: raced.cell,
    effect: (Pulse p) => print('   [Race] ${p.payload}'),
  );
  await start.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  rObs.stop();
  print('');

  print('2. RaceFirst - first value only');
  final go = Cell.ingress<void>();
  final first = RaceFirst<String>([
    Stream.fromIterable(['a', 'b']),
    Future<String>.delayed(const Duration(milliseconds: 20), () => 'c'),
  ]).toHandle(source: go.cell);
  final fObs = Cell.observe(
    source: first.cell,
    effect: (Pulse p) => print('   [RaceFirst] ${p.payload}'),
  );
  await go.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 40));
  fObs.stop();
  print('');

  print('3. RaceMap - payload picks the field');
  final ids = Cell.ingress<int>();
  final mapped = RaceMap<int, String>((id) => [
    Future<String>.delayed(const Duration(milliseconds: 30), () => 'net-$id'),
    Future.value('cache'),
  ]).toHandle(source: ids.cell);
  final mObs = Cell.observe(
    source: mapped.cell,
    effect: (Pulse p) => print('   [RaceMap] ${p.payload}'),
  );
  await ids.emitAsync(1);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  mObs.stop();
  print('');

  print('4. RaceWith - source vs other');
  final src = Cell.ingress<int>();
  final withOther = RaceWith<int, String>(
        (n) => Future<String>.delayed(const Duration(milliseconds: 40), () => 'src-$n'),
    other: () => Future.value('side'),
  ).toHandle(source: src.cell);
  final wObs = Cell.observe(
    source: withOther.cell,
    effect: (Pulse p) => print('   [RaceWith] ${p.payload}'),
  );
  await src.emitAsync(1);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  wObs.stop();
  print('');

  print('5. RaceUntil - timeout');
  final slow = Cell.ingress<void>();
  final timed = RaceUntil<void, String>(
        (_) => Future<String>.delayed(const Duration(milliseconds: 80), () => 'late'),
    timeout: const Duration(milliseconds: 15),
  ).toHandle(source: slow.cell);
  final tObs = Cell.observe(
    source: timed.cell,
    effect: (Pulse p) => print('   [RaceUntil] ${p.payload.runtimeType}'),
  );
  await slow.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 40));
  tObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}