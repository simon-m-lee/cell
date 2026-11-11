// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell.dart';

// ─────────────────────────────────────────────────────────────
// factory - debounce
// ─────────────────────────────────────────────────────────────

/// Emits only after [source] has been quiet for [duration].
///
/// Modeled on Rx `debounceTime`, with one deliberate deviation in
/// `leading` mode: a lone pulse is emitted immediately **and** again by the
/// trailing timer, whereas classic Rx would suppress the trailing emit when
/// nothing new has arrived.
///
/// * Each pulse resets the timer; only the latest pulse is kept.
/// * [leading] – when `true`, also emit the first pulse of a burst immediately.
/// * Clearer than [PropagationStrategy.debounced] when you want an explicit
///   node in the graph.
Cell _debounce(
  Cell source,
  Duration duration, {
  bool leading = false,
  EphemeralPolicy? ephemeralPolicy,
  Context context = Context.system,
  TestCell testRule = TestCell.allowAll,
  Synapses synapses = Synapses.enabled,
  bool forceLock = false,
}) {
  if (duration < Duration.zero) {
    throw ArgumentError.value(duration, 'duration', 'must be >= 0');
  }

  final state = _DebounceState();

  final outputCell = Cell.governed(
    ephemeralPolicy: ephemeralPolicy,
    context: context,
    receptor: ephemeralPolicy != null ? _Receptor() : Receptor.passThrough,
    testRule: testRule,
    synapses: synapses,
    forceLock: forceLock,
  );

  void emitOut(Pulse pulse) {
    if (outputCell.isInvalidated) return;
    // Preserve the originating pulse's provenance: regulated pulses keep
    // their compliance context and priority across the timing operator.
    // `pulse.type` is dynamic — an enum-typed pulse must not throw a
    // TypeError at the `type:` boundary, so only string types are kept.
    outputCell._nucleus.receptor.call(
      Pulse.governed(
        context: (pulse as PulseBase).context,
        payload: pulse.payload,
        type: pulse.type is String ? pulse.type : null,
        source: outputCell,
        priority: pulse.priority,
      ),
    );
  }

  final bridge = Cell.governed(
    bind: source,
    context: context,
    testRule: TestCell.allowAll,
    synapses: Synapses.disabled,
    receptor: Receptor(
      (cell, pulse, {user}) {
        if (outputCell.isInvalidated) {
          state.cancel();
          return null;
        }
        // This bridge is bound to exactly one source, so every pulse that
        // arrives here came from it. A `pulse.source == source` guard is
        // wrong: state cells and derived cells emit pulses without a source
        // stamp, which the guard silently dropped.

        final wasIdle = state.timer == null;

        if (leading && wasIdle) {
          emitOut(pulse);
        }

        state.cancel();
        state.pending = pulse;

        if (duration == Duration.zero) {
          if (!leading || !wasIdle) emitOut(pulse);
          state.cancel();
          return null;
        }

        state.timer = Timer(duration, () {
          final pending = state.pending;
          state.cancel();
          // If leading already emitted this pulse as the start of the burst,
          // still emit trailing latest (may be same or newer).
          if (pending != null) {
            try {
              emitOut(pending);
            } catch (e, st) {
              // A throwing downstream receptor must not become an
              // unhandled zone error: fail the originating pulse cleanly.
              (pending as PulseBase)._fail(e, stackTrace: st);
            }
          }
        });

        return null;
      },
    ),
  );

  state.retain(bridge);
  return outputCell;
}

class _DebounceState {
  Timer? timer;
  Pulse? pending;
  // ignore: unused_field
  Object? _pin;

  void retain(Object pin) => _pin = pin;

  void cancel() {
    timer?.cancel();
    timer = null;
    pending = null;
  }
}
