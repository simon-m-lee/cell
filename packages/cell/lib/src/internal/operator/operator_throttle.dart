// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell.dart';

// ─────────────────────────────────────────────────────────────
// factory - throttle
// ─────────────────────────────────────────────────────────────

/// Rate-limits [source] to at most one leading emission per [duration].
///
/// Classic Rx `throttleTime`.
///
/// * [leading] – emit the first pulse in a window (default `true`).
/// * [trailing] – when the window ends, emit the last pulse seen while muted
///   (default `false`).
/// * Clearer than relying only on [PropagationStrategy.throttled] when you
///   want an explicit node in the graph.
Cell _throttle(
    Cell source,
    Duration duration, {
      bool leading = true,
      bool trailing = false,
      EphemeralPolicy? ephemeralPolicy,
      Context context = Context.system,
      TestCell testRule = TestCell.allowAll,
      Synapses synapses = Synapses.enabled,
      bool forceLock = false,
    }) {
  if (duration < Duration.zero) {
    throw ArgumentError.value(duration, 'duration', 'must be >= 0');
  }

  final state = _ThrottleState();

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

  void openWindow() {
    state.muted = true;
    state.timer?.cancel();
    state.timer = Timer(duration, () {
      state.muted = false;
      state.timer = null;
      if (trailing && state.hasTrailing) {
        final pending = state.trailingPulse;
        state.hasTrailing = false;
        state.trailingPulse = null;
        if (pending != null) {
          emitOut(pending);
          // After trailing emit, start a new mute window (Rx-like)
          openWindow();
        }
      }
    });
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

        if (!state.muted) {
          if (leading) {
            emitOut(pulse);
          } else if (trailing) {
            state
              ..hasTrailing = true
              ..trailingPulse = pulse;
          }
          openWindow();
          return null;
        }

        // Inside mute window
        if (trailing) {
          state
            ..hasTrailing = true
            ..trailingPulse = pulse;
        }
        return null;
      },
    ),
  );

  state.retain(bridge);
  return outputCell;
}

class _ThrottleState {
  bool muted = false;
  Timer? timer;
  bool hasTrailing = false;
  Pulse? trailingPulse;
  // ignore: unused_field
  Object? _pin;

  void retain(Object pin) => _pin = pin;

  void cancel() {
    timer?.cancel();
    timer = null;
  }
}