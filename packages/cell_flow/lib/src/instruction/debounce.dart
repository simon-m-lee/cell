// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flow/flow.dart';

/// Flow instructions that wait for silence or a clock (Rx `debounce` family).
///
/// | Operator | Rx analogue | Emits |
/// |---|---|---|
/// | [Debounce] | `debounceTime` | last value after [duration] of silence |
/// | [DebounceLeading] | leading + trailing debounce | first immediately, last after silence |
/// | [DebounceLeadingOnly] | leading debounce | first of a burst only |
/// | [DebounceWith] | `debounce` | last value after a per-item duration |
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef DebounceErrorHandler = void Function(Object error, StackTrace? stackTrace);

Pulse? _typedOrError<S>(
  Pulse pulse, {
  DebounceErrorHandler? onError,
}) {
  final payload = pulse.payload;
  if (payload is! S) {
    onError?.call(
      FormatException('Expected payload of type $S, got ${payload.runtimeType}'),
      StackTrace.current,
    );
    return null;
  }
  return pulse;
}

Pulse _mark(Pulse pulse, String step) => pulse.withStep(step);

Pulse<S> _fromPayload<S>(S value, Pulse sourcePulse, Cell? cell, String step) {
  return Pulse<S>(
    value,
    source: cell ?? sourcePulse.source,
    type: sourcePulse.type,
    priority: sourcePulse.priority,
    step: step,
  );
}

// ─────────────────────────────────────────────────────────────
// Debounce
// ─────────────────────────────────────────────────────────────

/// Emits the last value after [duration] of silence (Rx `debounceTime`).
///
/// ### When to use
/// - Search-as-you-type
/// - Resize / scroll end
/// - Waiting until a burst of edits settles
///
/// ### How it works
/// Every pulse resets a timer. When the timer fires with no newer pulse,
/// the latest payload is emitted.
///
/// ### Example
/// ```dart
/// final input = Cell.ingress<String>();
/// final ready = Debounce<String>(const Duration(milliseconds: 300))
///     .toHandle(source: input.cell);
/// ```
///
/// ### See Also:
/// [DebounceLeading], [DebounceLeadingOnly], [DebounceWith]
class Debounce<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  Debounce(
    Duration duration, {
    DebounceErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _GateState<S>();
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;

              state.pending = typed.payload as S;
              state.pendingPulse = typed;
              state.timer?.cancel();
              state.timer = Timer(duration, () {
                final value = state.pending;
                final src = state.pendingPulse;
                state.clearPending();
                if (value == null || src == null) return;
                future!(
                  result: _fromPayload(value, src, cell, 'Debounce'),
                  token: token,
                );
              });
              return null;
            };
          })(),
          user: user,
        );
}

/// Emits the first pulse of a burst immediately, then the last pulse after
/// [duration] of silence.
class DebounceLeading<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  DebounceLeading(
    Duration duration, {
    DebounceErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _GateState<S>();
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;

              final timerActive = state.timer?.isActive == true;
              if (!timerActive) {
                state.clearPending();
                future!(
                  result: _mark(typed, 'DebounceLeading.leading'),
                  token: token,
                );
                state.timer = Timer(duration, () {
                  state.timer = null;
                });
                return null;
              }

              state.pending = typed.payload as S;
              state.pendingPulse = typed;
              state.timer?.cancel();
              state.timer = Timer(duration, () {
                final value = state.pending;
                final src = state.pendingPulse;
                state.clearPending();
                state.timer = null;
                if (value == null || src == null) return;
                future!(
                  result: _fromPayload(
                    value,
                    src,
                    cell,
                    'DebounceLeading.trailing',
                  ),
                  token: token,
                );
              });
              return null;
            };
          })(),
          user: user,
        );
}

/// Emits only the first pulse of a burst; later pulses in the window are
/// dropped (lodash `leading: true, trailing: false`).
class DebounceLeadingOnly<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  DebounceLeadingOnly(
    Duration duration, {
    DebounceErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _GateState<S>();
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;

              if (state.timer?.isActive == true) return null;

              state.timer = Timer(duration, () {
                state.timer = null;
              });
              return _mark(typed, 'DebounceLeadingOnly');
            };
          })(),
          user: user,
        );
}

/// Rx `debounce` — each value chooses its own silence window via [durationOf].
class DebounceWith<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  DebounceWith(
    Duration Function(S value) durationOf, {
    DebounceErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            final state = _GateState<S>();
            var generation = 0;
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;
              final payload = typed.payload as S;

              Duration wait;
              try {
                wait = durationOf(payload);
              } catch (e, stack) {
                onError?.call(e, stack);
                return null;
              }

              state.pending = payload;
              state.pendingPulse = typed;
              state.timer?.cancel();
              final id = ++generation;
              state.timer = Timer(wait, () {
                if (id != generation) return;
                final value = state.pending;
                final src = state.pendingPulse;
                state.clearPending();
                if (value == null || src == null) return;
                future!(
                  result: _fromPayload(value, src, cell, 'DebounceWith'),
                  token: token,
                );
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

class _GateState<S> {
  S? pending;
  Pulse? pendingPulse;
  Timer? timer;

  void clearPending() {
    pending = null;
    pendingPulse = null;
    timer?.cancel();
    timer = null;
  }
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// Demonstration of the debounce family.
///
/// ### Expected console output:
/// ```text
/// ── Debounce Operators Demo ───────────────────────────────────
///
/// 1. Debounce - last after silence
///    [Debounce] hello
///
/// 2. DebounceLeading - first then last
///    [DebounceLeading] 1
///    [DebounceLeading] 3
///
/// 3. DebounceLeadingOnly - first of burst
///    [DebounceLeadingOnly] 1
///
/// 4. DebounceWith - per-value wait
///    [DebounceWith] go
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Debounce Operators Demo ───────────────────────────────────\n');

  print('1. Debounce - last after silence');
  final search = Cell.ingress<String>();
  final debounced = Debounce<String>(const Duration(milliseconds: 60))
      .toHandle(source: search.cell);
  final dObs = Cell.observe(
    source: debounced.cell,
    effect: (Pulse p) => print('   [Debounce] ${p.payload}'),
  );
  await search.emitAsync('h');
  await Future<void>.delayed(const Duration(milliseconds: 15));
  await search.emitAsync('he');
  await Future<void>.delayed(const Duration(milliseconds: 15));
  await search.emitAsync('hello');
  await Future<void>.delayed(const Duration(milliseconds: 90));
  dObs.stop();
  print('');

  print('2. DebounceLeading - first then last');
  final burst = Cell.ingress<int>();
  final lead = DebounceLeading<int>(const Duration(milliseconds: 50))
      .toHandle(source: burst.cell);
  final lObs = Cell.observe(
    source: lead.cell,
    effect: (Pulse p) => print('   [DebounceLeading] ${p.payload}'),
  );
  await burst.emitAsync(1);
  await burst.emitAsync(2);
  await burst.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  lObs.stop();
  print('');

  print('3. DebounceLeadingOnly - first of burst');
  final taps = Cell.ingress<int>();
  final only = DebounceLeadingOnly<int>(const Duration(milliseconds: 50))
      .toHandle(source: taps.cell);
  final oObs = Cell.observe(
    source: only.cell,
    effect: (Pulse p) => print('   [DebounceLeadingOnly] ${p.payload}'),
  );
  await taps.emitAsync(1);
  await taps.emitAsync(2);
  await taps.emitAsync(3);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  oObs.stop();
  print('');

  print('4. DebounceWith - per-value wait');
  final words = Cell.ingress<String>();
  final keyed = DebounceWith<String>(
    (s) => Duration(milliseconds: s == 'wait' ? 80 : 20),
  ).toHandle(source: words.cell);
  final wObs = Cell.observe(
    source: keyed.cell,
    effect: (Pulse p) => print('   [DebounceWith] ${p.payload}'),
  );
  await words.emitAsync('wait');
  await Future<void>.delayed(const Duration(milliseconds: 25));
  await words.emitAsync('go');
  await Future<void>.delayed(const Duration(milliseconds: 50));
  wObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}
