// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../../cell.dart';

// ─────────────────────────────────────────────────────────────
// factory - debounce
// ─────────────────────────────────────────────────────────────

/// Emits only after [source] has been quiet for [duration].
///
/// Classic Rx `debounceTime`.
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
    receptor: Receptor.passThrough,
    testRule: testRule,
    synapses: synapses,
    forceLock: forceLock,
  );

  void emitOut(Pulse pulse) {
    if (outputCell.isInvalidated) return;
    outputCell._nucleus.receptor.call(
      Pulse.governed(
        payload: pulse.payload,
        type: pulse.type,
        source: outputCell,
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
        if (outputCell.isInvalidated) return null;
        if (pulse.source != source) return null;

        final wasIdle = state.timer == null;

        if (leading && wasIdle) {
          emitOut(pulse);
        }

        state.pending = pulse;
        state.timer?.cancel();

        if (duration == Duration.zero) {
          if (!leading || !wasIdle) emitOut(pulse);
          state
            ..timer = null
            ..pending = null;
          return null;
        }

        state.timer = Timer(duration, () {
          final pending = state.pending;
          state
            ..timer = null
            ..pending = null;
          // If leading already emitted this pulse as the start of the burst,
          // still emit trailing latest (may be same or newer).
          if (pending != null) {
            emitOut(pending);
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
  Object? _pin;

  void retain(Object pin) => _pin = pin;

  void cancel() {
    timer?.cancel();
    timer = null;
    pending = null;
  }
}