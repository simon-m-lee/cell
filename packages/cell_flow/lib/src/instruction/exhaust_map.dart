// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_flow/flow.dart';

/// Flow instructions that admit one inner sequence at a time
/// (Rx `exhaustMap` family).
///
/// These operators implement the **exhaust** strategy: while an inner sequence
/// is running, incoming triggers are either dropped or remembered for later
/// execution. This is useful for preventing overlapping operations and
/// protecting against duplicate submissions.
///
/// | Operator | Rx analogue | Busy policy |
/// |---|---|---|
/// | [ExhaustMap] | `exhaustMap` | drop every trigger until the inner ends |
/// | [ExhaustMapTo] | `exhaustMapTo` | same inner; drop while busy |
/// | [ExhaustAll] | — | payload *is* the inner; drop while busy |
/// | [ExhaustMapFirst] | exhaust + `take(1)` | drop while busy; emit only the first inner item |
/// | [ExhaustMapLatest] | exhaust + trailing | remember the last skipped trigger; run it next |
///
/// Inners may be a [Stream], [Future], [Iterable], raw value, or `null`.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef ExhaustErrorHandler = void Function(Object error, StackTrace? stackTrace);
typedef ExhaustMapper<S> = FutureOr<Object?> Function(S value);

Pulse<T> _out<T>(T value, Cell? cell, Pulse trigger, String step) {
  return Pulse<T>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

Future<void> _drain(
    Object? inner,
    void Function(dynamic value) onData, {
      bool Function()? stillLive,
    }) async {
  if (inner == null) return;
  if (stillLive != null && !stillLive()) return;

  if (inner is Stream) {
    await for (final event in inner) {
      if (stillLive != null && !stillLive()) return;
      await _drain(event, onData, stillLive: stillLive);
    }
    return;
  }

  if (inner is Future) {
    final value = await inner;
    await _drain(value, onData, stillLive: stillLive);
    return;
  }

  if (inner is Iterable && inner is! String) {
    for (final event in inner) {
      if (stillLive != null && !stillLive()) return;
      await _drain(event, onData, stillLive: stillLive);
    }
    return;
  }

  onData(inner);
}

// ─────────────────────────────────────────────────────────────
// ExhaustMap
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that admits one inner sequence at a time,
/// dropping every trigger that arrives while busy (Rx `exhaustMap`).
///
/// [ExhaustMap] acts as a **First-Wins Flattener**. Triggers that arrive
/// while an inner sequence is running are dropped. Only the first sequence
/// is processed until it completes.
///
/// ### When to use
/// Use [ExhaustMap] when you need to prevent overlapping operations:
///
/// - **Submit/Save Buttons**: Prevent double-submission
/// - **Login or Checkout**: Ignore extra clicks
/// - **Form Submission**: Prevent duplicate form submissions
/// - **Idempotent Operations**: Operations that should only run once at a time
/// - **Rate Limiting**: You want to limit the rate of operations
/// - **Resource Protection**: You want to prevent resource exhaustion
/// - **Button Click Prevention**: Prevent double-click issues
/// - **Throttling User Actions**: Only process the first action
/// - **API Calls**: Prevent concurrent API calls
/// - **File Uploads**: Prevent overlapping uploads
///
/// ### Choosing Between Exhaust Patterns
/// - **Use [ExhaustMap]** for **Drop While Busy**: When you want to drop
///   all triggers that arrive while busy.
/// - **Use [ExhaustMapTo]** for **Same Inner**: When you want to flatten
///   the same inner sequence for every trigger, dropping while busy.
/// - **Use [ExhaustAll]** for **Payload as Inner**: When the payload itself
///   is the sequence to flatten, dropping while busy.
/// - **Use [ExhaustMapFirst]** for **First Item Only**: When you only want
///   the first item of each admitted inner sequence.
/// - **Use [ExhaustMapLatest]** for **Latest Trailing**: When you want to
///   remember the last skipped trigger and run it after the current one.
///
/// ### Comparison with Other Operators
/// | Operator | Busy Policy | Order | Use Case |
/// |----------|-------------|-------|----------|
/// | **ExhaustMap** | Drop all | First | Basic exhaust |
/// | **ExhaustMapTo** | Drop all | First | Same inner |
/// | **ExhaustAll** | Drop all | First | Payload as inner |
/// | **ExhaustMapFirst** | Drop all | First | First item only |
/// | **ExhaustMapLatest** | Remember latest | First then latest | Exhaust + trailing |
/// | **ConcatMap** | Queue | FIFO | Sequential |
/// | **ConcatMapLatest** | Cancel previous | Latest | Switch |
///
/// ### How it works
/// 1. The first trigger starts an inner sequence.
/// 2. While the sequence is in flight, all subsequent triggers are dropped.
/// 3. When the sequence completes, the instruction is ready for the next trigger.
/// 4. Results are emitted from the first sequence.
/// 5. The instruction preserves causal provenance.
///
/// ### Supported Inner Types
/// The [mapper] can return any of the following:
/// - **[Stream\<T\>]**: Each event in the stream is emitted sequentially.
/// - **[Future\<T\>]**: The single value is emitted when the future completes.
/// - **[Iterable\<T\>]**: Each element is emitted in order.
/// - **[T]**: The value itself is emitted directly.
/// - **`null`**: No emission (the pulse is dropped).
/// - **Nested combinations**: `Future<Iterable<T>>`, `Stream<Future<T>>`,
///   etc., are recursively expanded.
///
/// ### Non‑obvious
/// - **Drop While Busy**: Triggers while busy are silently dropped.
/// - **One at a Time**: Only one sequence can be in flight at a time.
/// - **Error Handling**: Errors are reported via [onError].
/// - **Causal Provenance**: Every emitted result is wrapped as an
///   [EvolvedPulse], preserving the forensic history.
/// - **Type Safety**: The instruction is generic over [S] (input type) and
///   [T] (output type), ensuring compile-time type safety.
/// - **Recursive Draining**: The instruction recursively drains nested
///   async types.
///
/// ### Example: Button Click Protection
/// ```dart
/// final clicks = Cell.ingress<void>();
/// final submit = ExhaustMap<void, String>((_) async* {
///   await submitForm();
///   yield 'Submitted!';
/// }).toHandle(source: clicks.cell);
///
/// clicks.emit(null); // Starts submission
/// clicks.emit(null); // Dropped (busy)
/// clicks.emit(null); // Dropped (busy)
/// // Only the first submission is processed
/// ```
///
/// ### Example: File Upload
/// ```dart
/// final uploads = Cell.ingress<File>();
/// final uploadStatus = ExhaustMap<File, String>((file) async* {
///   yield 'Uploading ${file.name}...';
///   await uploadFile(file);
///   yield 'Upload complete!';
/// }).toHandle(source: uploads.cell);
/// ```
///
/// ### Parameters:
/// - [mapper]: **The Flattening Logic.** Takes an input value of type [S]
///   and returns an inner sequence (Stream, Future, Iterable, or value).
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload from the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ExhaustMapTo]: For flattening the same inner sequence.
/// - [ExhaustAll]: For when the payload itself is the inner sequence.
/// - [ExhaustMapFirst]: For only the first item of each inner.
/// - [ExhaustMapLatest]: For trailing exhaust with latest remembered.
class ExhaustMap<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates an [ExhaustMap] instruction with the specified [mapper].
  ///
  /// ### Parameters:
  /// - [mapper]: **The Flattening Logic.** Takes an input value of type [S]
  ///   and returns an inner sequence.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final exhaustMap = ExhaustMap<int, String>(
  ///   (n) async* { yield '$n processed'; },
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  ExhaustMap(
      ExhaustMapper<S> mapper, {
        ExhaustErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _BusyState();
      return (pulse, {cell, user, future, token}) {
        if (state.busy) return null;
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
        state.busy = true;
        Future<void>(() async {
          try {
            final inner = await Future.sync(() => mapper(payload));
            await _drain(inner, (item) {
              if (item is T) {
                future!(
                  result: _out<T>(item, cell, pulse, 'ExhaustMap'),
                  token: token,
                );
              }
            });
          } catch (e, stack) {
            onError?.call(e, stack);
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
// ExhaustMapTo
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that flattens the same inner sequence, dropping
/// triggers while it is running (Rx `exhaustMapTo`).
///
/// [ExhaustMapTo] acts as a **Reusable Exhaust Flattener**. Unlike
/// [ExhaustMap], it ignores the trigger payload and flattens the same inner
/// sequence for every trigger. Triggers while busy are dropped.
///
/// ### When to use
/// Use [ExhaustMapTo] when:
/// - You want to flatten the same sequence while dropping busy triggers
/// - The trigger payload is irrelevant to the flattening
/// - You're implementing a repeated workflow with exhaust behavior
/// - You're polling the same data source with exhaust
/// - You're implementing a heartbeat with exhaust
/// - You're preventing overlapping of the same operation
///
/// ### How it works
/// 1. Each trigger pulse (regardless of payload) starts the same inner sequence.
/// 2. While the sequence is running, all subsequent triggers are dropped.
/// 3. When the sequence completes, the instruction is ready for the next trigger.
/// 4. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Payload Ignored**: The trigger payload is ignored. Only the trigger
///   count matters.
/// - **Same Sequence**: The same inner sequence is flattened for every trigger.
/// - **Drop While Busy**: Triggers while busy are silently dropped.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Repeated Workflow with Exhaust
/// ```dart
/// final clicks = Cell.ingress<void>();
/// val workflow = ExhaustMapTo<void, String>(() async* {
///   yield 'Step 1';
///   yield 'Step 2';
/// }).toHandle(source: clicks.cell);
///
/// clicks.emit(null); // Starts workflow
/// clicks.emit(null); // Dropped (busy)
/// clicks.emit(null); // Dropped (busy)
/// // Only the first trigger is processed
/// ```
///
/// ### Parameters:
/// - [inner]: **The Sequence Factory.** Returns the inner sequence to flatten.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload (ignored).
/// - [T]: The type of the output payload from the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ExhaustMap]: For per-trigger sequences.
/// - [ExhaustAll]: For when the payload itself is the inner sequence.
class ExhaustMapTo<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates an [ExhaustMapTo] instruction with the specified [inner].
  ///
  /// ### Parameters:
  /// - [inner]: **The Sequence Factory.** Returns the inner sequence to flatten.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final exhaustMapTo = ExhaustMapTo<void, String>(
  ///   () async* { yield 'ping'; yield 'pong'; },
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  ExhaustMapTo(
      FutureOr<Object?> Function() inner, {
        ExhaustErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _BusyState();
      return (pulse, {cell, user, future, token}) {
        if (state.busy) return null;
        state.busy = true;
        Future<void>(() async {
          try {
            final seq = await Future.sync(inner);
            await _drain(seq, (item) {
              if (item is T) {
                future!(
                  result: _out<T>(item, cell, pulse, 'ExhaustMapTo'),
                  token: token,
                );
              }
            });
          } catch (e, stack) {
            onError?.call(e, stack);
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
// ExhaustAll
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that treats the payload as the inner sequence,
/// dropping new payloads while draining (Rx `exhaustAll`).
///
/// [ExhaustAll] acts as a **Payload Exhaust Flattener**. The payload itself
/// is treated as the inner sequence (Stream, Future, Iterable, or value)
/// and flattened. New payloads while busy are dropped.
///
/// ### When to use
/// Use [ExhaustAll] when:
/// - The payload itself is the sequence to flatten
/// - You're receiving lists or streams as payloads
/// - You're implementing batch processing with exhaust
/// - You're unrolling nested structures with exhaust
/// - You're processing paginated results with exhaust
/// - You want to prevent overlapping batch processing
///
/// ### How it works
/// 1. Each trigger pulse's payload is extracted.
/// 2. The payload is treated as an inner sequence.
/// 3. While the sequence is running, all subsequent payloads are dropped.
/// 4. When the sequence completes, the instruction is ready for the next payload.
/// 5. The instruction preserves causal provenance.
///
/// ### Supported Payload Types
/// The payload can be any of the following:
/// - **[Stream\<T\>]**: Each event in the stream is emitted sequentially.
/// - **[Future\<T\>]**: The single value is emitted when the future completes.
/// - **[Iterable\<T\>]**: Each element is emitted in order.
/// - **[T]**: The value itself is emitted directly.
/// - **`null`**: No emission (the pulse is dropped).
///
/// ### Non‑obvious
/// - **Payload as Source**: The payload itself is the source of the emissions.
/// - **Drop While Busy**: New payloads are dropped while draining.
/// - **Type Safety**: The instruction is generic over [T] (output type).
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Batch Processing with Exhaust
/// ```dart
/// final batches = Cell.ingress<List<String>>();
/// val flat = ExhaustAll<String>().toHandle(source: batches.cell);
///
/// batches.emit(['a', 'b']); // -> a, b
/// batches.emit(['c']);     // Dropped (busy)
/// ```
///
/// ### Parameters:
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [T]: The type of the output payload from the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ExhaustMap]: For mapping payloads to sequences.
/// - [ExhaustMapTo]: For the same sequence every trigger.
class ExhaustAll<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates an [ExhaustAll] instruction.
  ///
  /// ### Parameters:
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final exhaustAll = ExhaustAll<String>(
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  ExhaustAll({
    ExhaustErrorHandler? onError,
    dynamic user,
  }) : super.future(
    (() {
      final state = _BusyState();
      return (pulse, {cell, user, future, token}) {
        if (state.busy) return null;
        state.busy = true;
        Future<void>(() async {
          try {
            await _drain(pulse.payload, (item) {
              if (item is T) {
                future!(
                  result: _out<T>(item, cell, pulse, 'ExhaustAll'),
                  token: token,
                );
              }
            });
          } catch (e, stack) {
            onError?.call(e, stack);
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
// ExhaustMapFirst
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that emits only the first item of each admitted
/// inner sequence (exhaust + `take(1)`).
///
/// [ExhaustMapFirst] acts as a **First-Item Exhaust Flattener**. It drops
/// triggers while busy and emits only the first item of each admitted inner
/// sequence.
///
/// ### When to use
/// Use [ExhaustMapFirst] when:
/// - You only care about the first result of each operation
/// - You're implementing a "first success" pattern
/// - You're tracking the initial state of each process
/// - You're preventing duplicate operations but only need the first result
/// - You're implementing a loading indicator that only needs the start
/// - You're tracking the initiation of each task
///
/// ### How it works
/// 1. The first trigger starts an inner sequence.
/// 2. While the sequence is running, all subsequent triggers are dropped.
/// 3. Only the first item of the inner sequence is emitted.
/// 4. Remaining items in the sequence are ignored.
/// 5. When the sequence completes, the instruction is ready for the next trigger.
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **First Item Only**: Only the first item of each inner sequence is emitted.
/// - **Drop While Busy**: Triggers while busy are silently dropped.
/// - **Early Termination**: After the first item, the rest of the sequence
///   is ignored but still drains in the background.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: First Response Only
/// ```dart
/// final requests = Cell.ingress<String>();
/// val firstResponse = ExhaustMapFirst<String, String>((query) async* {
///   yield 'Loading...';
///   final result = await api.search(query);
///   yield result;
/// }).toHandle(source: requests.cell);
///
/// requests.emit('hello'); // -> 'Loading...' only
/// requests.emit('world'); // Dropped (busy)
/// ```
///
/// ### Parameters:
/// - [mapper]: **The Flattening Logic.** Takes an input value of type [S]
///   and returns an inner sequence.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload from the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ExhaustMap]: For all items of each inner sequence.
/// - [ExhaustMapLatest]: For trailing exhaust with latest remembered.
class ExhaustMapFirst<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates an [ExhaustMapFirst] instruction with the specified [mapper].
  ///
  /// ### Parameters:
  /// - [mapper]: **The Flattening Logic.** Takes an input value of type [S]
  ///   and returns an inner sequence.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final exhaustMapFirst = ExhaustMapFirst<int, String>(
  ///   (n) async* { yield '$n started'; yield '$n done'; },
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  ExhaustMapFirst(
      ExhaustMapper<S> mapper, {
        ExhaustErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _BusyState();
      return (pulse, {cell, user, future, token}) {
        if (state.busy) return null;
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
        state.busy = true;
        Future<void>(() async {
          var emitted = false;
          try {
            final inner = await Future.sync(() => mapper(payload));
            await _drain(
              inner,
                  (item) {
                if (emitted || item is! T) return;
                emitted = true;
                future!(
                  result: _out<T>(item, cell, pulse, 'ExhaustMapFirst'),
                  token: token,
                );
              },
              stillLive: () => !emitted,
            );
          } catch (e, stack) {
            onError?.call(e, stack);
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
// ExhaustMapLatest
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that remembers the last skipped trigger and runs
/// it when the current inner finishes (leading + trailing exhaust).
///
/// [ExhaustMapLatest] acts as a **Trailing Exhaust Flattener**. It drops
/// all triggers while busy except the last one, which is remembered and
/// executed after the current sequence completes.
///
/// ### When to use
/// Use [ExhaustMapLatest] when:
/// - You want to process the latest request even if it arrives while busy
/// - You're implementing a "last request wins" with exhaust behavior
/// - You're handling user input where the final state matters
/// - You're implementing a queue with only the latest item kept
/// - You're processing requests where only the last one matters
/// - You're implementing a debounced exhaust pattern
///
/// ### How it works
/// 1. The first trigger starts an inner sequence.
/// 2. While the sequence is running, all subsequent triggers are dropped
///    except the last one, which is remembered.
/// 3. When the sequence completes, the remembered trigger is executed.
/// 4. This process repeats until no more triggers are remembered.
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Latest Remembered**: Only the last skipped trigger is remembered.
/// - **Sequential Execution**: The remembered trigger runs after the current
///   sequence completes.
/// - **Chain Effect**: This can create a chain of executions if triggers
///   arrive while processing the remembered one.
/// - **Causal Provenance**: Every emitted result preserves forensic history.
///
/// ### Example: Last Request Wins
/// ```dart
/// final requests = Cell.ingress<int>();
/// val latest = ExhaustMapLatest<int, String>((n) async* {
///   yield '$n-start';
///   await Future.delayed(Duration(milliseconds: 50));
///   yield '$n-end';
/// }).toHandle(source: requests.cell);
///
/// requests.emit(1); // Starts processing 1
/// requests.emit(2); // Remembered (will run after 1)
/// requests.emit(3); // Replaces 2 (latest)
/// // After 1 completes, 3 runs
/// ```
///
/// ### Parameters:
/// - [mapper]: **The Flattening Logic.** Takes an input value of type [S]
///   and returns an inner sequence.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload from the inner sequence.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [ExhaustMap]: For dropping all triggers while busy.
/// - [ExhaustMapFirst]: For only the first item of each inner.
/// - [Debounce]: For trailing-only debounce.
class ExhaustMapLatest<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates an [ExhaustMapLatest] instruction with the specified [mapper].
  ///
  /// ### Parameters:
  /// - [mapper]: **The Flattening Logic.** Takes an input value of type [S]
  ///   and returns an inner sequence.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// final exhaustMapLatest = ExhaustMapLatest<int, String>(
  ///   (n) async* { yield '$n processed'; },
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  ExhaustMapLatest(
      ExhaustMapper<S> mapper, {
        ExhaustErrorHandler? onError,
        dynamic user,
      }) : super.future(
    (() {
      final state = _LatestState<S>();
      Future<void> run(
          S value,
          Pulse pulse,
          Cell? cell,
          void Function({required Pulse? result, required dynamic token})?
          future,
          dynamic token,
          ) async {
        state.busy = true;
        try {
          final inner = await Future.sync(() => mapper(value));
          await _drain(inner, (item) {
            if (item is T) {
              future!(
                result: _out<T>(item, cell, pulse, 'ExhaustMapLatest'),
                token: token,
              );
            }
          });
        } catch (e, stack) {
          onError?.call(e, stack);
        } finally {
          state.busy = false;
          final next = state.takePending();
          if (next != null) {
            await run(next.$1, next.$2, cell, future, token);
          }
        }
      }

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
        if (state.busy) {
          state.pendingValue = payload;
          state.pendingPulse = pulse;
          return null;
        }
        Future<void>(() => run(payload, pulse, cell, future, token));
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

/// Internal state for [ExhaustMap], [ExhaustMapTo], [ExhaustAll], and
/// [ExhaustMapFirst].
class _BusyState {
  bool busy = false;
}

/// Internal state for [ExhaustMapLatest].
class _LatestState<S> {
  bool busy = false;
  S? pendingValue;
  Pulse? pendingPulse;

  (S, Pulse)? takePending() {
    final value = pendingValue;
    final pulse = pendingPulse;
    pendingValue = null;
    pendingPulse = null;
    if (value == null || pulse == null) return null;
    return (value, pulse);
  }
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [ExhaustMap] instruction and related operators
/// showing their behavior in various exhaust scenarios.
///
/// ### Expected console output:
/// ```text
/// ── ExhaustMap Operators Demo ─────────────────────────────────
///
/// 1. ExhaustMap - drop while busy
///    [ExhaustMap] 1-a
///    [ExhaustMap] 1-b
///
/// 2. ExhaustMapTo - same inner
///    [ExhaustMapTo] ping
///    [ExhaustMapTo] pong
///
/// 3. ExhaustAll - payload is the list
///    [ExhaustAll] a
///    [ExhaustAll] b
///
/// 4. ExhaustMapFirst - first inner item only
///    [ExhaustMapFirst] 1-a
///
/// 5. ExhaustMapLatest - run the last skipped trigger
///    [ExhaustMapLatest] 1-a
///    [ExhaustMapLatest] 1-b
///    [ExhaustMapLatest] 3-a
///    [ExhaustMapLatest] 3-b
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
/// 1. **ExhaustMap - drop while busy**: Shows basic exhaust behavior.
///    Only the first trigger is processed; subsequent triggers are dropped
///    while busy. `1, 2, 3` becomes `1-a, 1-b`.
///
/// 2. **ExhaustMapTo - same inner**: Shows the same sequence being
///    flattened for every trigger with exhaust behavior. The trigger payload
///    is ignored. Only the first trigger is processed.
///
/// 3. **ExhaustAll - payload is the list**: Shows the payload itself
///    being treated as the inner sequence with exhaust behavior.
///    Lists are flattened into individual items. Subsequent lists are dropped
///    while busy.
///
/// 4. **ExhaustMapFirst - first inner item only**: Shows first-item-only
///    exhaust. Only the first item of each admitted inner sequence is emitted.
///    `1-a, 1-b` becomes `1-a`.
///
/// 5. **ExhaustMapLatest - run the last skipped trigger**: Shows trailing
///    exhaust behavior. The last skipped trigger is remembered and executed
///    after the current sequence completes. `1, 2, 3` becomes `1-a, 1-b, 3-a, 3-b`.
///
/// ### Key Takeaways
/// - All exhaust operators admit only one inner sequence at a time.
/// - ExhaustMap drops all triggers while busy.
/// - ExhaustMapTo ignores the trigger payload.
/// - ExhaustAll treats the payload as the sequence.
/// - ExhaustMapFirst emits only the first item of each inner.
/// - ExhaustMapLatest remembers and runs the last skipped trigger.
/// - All operators preserve causal provenance via EvolvedPulse.
Future<void> main() async {
  print('── ExhaustMap Operators Demo ─────────────────────────────────\n');

  print('1. ExhaustMap - drop while busy');
  final taps = Cell.ingress<int>();
  final exhaust = ExhaustMap<int, String>((n) async* {
    yield '$n-a';
    await Future<void>.delayed(const Duration(milliseconds: 40));
    yield '$n-b';
  }).toHandle(source: taps.cell);
  final eObs = Cell.observe(
    source: exhaust.cell,
    effect: (Pulse p) => print('   [ExhaustMap] ${p.payload}'),
  );
  await taps.emitAsync(1);
  await taps.emitAsync(2);
  await taps.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  eObs.stop();
  print('');

  print('2. ExhaustMapTo - same inner');
  final clicks = Cell.ingress<void>();
  final echo = ExhaustMapTo<void, String>(() async* {
    yield 'ping';
    yield 'pong';
  }).toHandle(source: clicks.cell);
  final tObs = Cell.observe(
    source: echo.cell,
    effect: (Pulse p) => print('   [ExhaustMapTo] ${p.payload}'),
  );
  await clicks.emitAsync(null);
  await clicks.emitAsync(null);
  await Future<void>.delayed(const Duration(milliseconds: 30));
  tObs.stop();
  print('');

  print('3. ExhaustAll - payload is the list');
  final batches = Cell.ingress<List<String>>();
  final all = ExhaustAll<String>().toHandle(source: batches.cell);
  final aObs = Cell.observe(
    source: all.cell,
    effect: (Pulse p) => print('   [ExhaustAll] ${p.payload}'),
  );
  await batches.emitAsync(['a', 'b']);
  await batches.emitAsync(['c']);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  aObs.stop();
  print('');

  print('4. ExhaustMapFirst - first inner item only');
  final firstIn = Cell.ingress<int>();
  final first = ExhaustMapFirst<int, String>((n) async* {
    yield '$n-a';
    yield '$n-b';
  }).toHandle(source: firstIn.cell);
  final fObs = Cell.observe(
    source: first.cell,
    effect: (Pulse p) => print('   [ExhaustMapFirst] ${p.payload}'),
  );
  await firstIn.emitAsync(1);
  await firstIn.emitAsync(2);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  fObs.stop();
  print('');

  print('5. ExhaustMapLatest - run the last skipped trigger');
  final latestIn = Cell.ingress<int>();
  final latest = ExhaustMapLatest<int, String>((n) async* {
    yield '$n-a';
    await Future<void>.delayed(const Duration(milliseconds: 30));
    yield '$n-b';
  }).toHandle(source: latestIn.cell);
  final lObs = Cell.observe(
    source: latest.cell,
    effect: (Pulse p) => print('   [ExhaustMapLatest] ${p.payload}'),
  );
  await latestIn.emitAsync(1);
  await latestIn.emitAsync(2);
  await latestIn.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 100));
  lObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}