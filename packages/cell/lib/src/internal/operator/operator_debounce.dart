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
/// the journal (D6 breaking change): the wait is the non-determinism, so
/// `journal:` is required — the timer runs through the journal's `timer`
/// primitive. On replay, the fire callback is invoked in journal order
/// instead of after a real wait.
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
  required EffectJournal journal,
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
    receptor: _ReadOnlyExternalPassThroughReceptor(),
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
      // the replay engine: prefer an outer ambient journal (ReplayEngine) over the
      // construction-time journal.
      (cell, pulse, {user}) =>
          JournalScope.runSync(JournalScope.effectiveJournal(journal), () {
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

        // The debounce timer is the non-determinism. It is journalled via
        // `journal.timer`. On the replay side, the journal invokes the
        // timer's callback in journal order, not after a real wait. This
        // is what makes debounce replayable.
        state.timer = _JournalTimer(
          journal: JournalScope.effectiveJournal(journal),
          duration: duration,
          input: pulse.payload,
          onFire: () {
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
          },
        );

        return null;
      }),
    ),
  );

  state.retain(bridge);
  return outputCell;
}

class _DebounceState {
  _JournalTimer? timer;
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
