// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Purity-aware invocation of a [TestCell].
///
/// the replay engine called `cell.validate(...)` unconditionally. the governance layer checks
/// the rule's purity and routes accordingly:
///
/// * **[Purity.pure]** — call the rule. Its decision is a function of
///   its input; replay re-computes it exactly.
/// * **[Purity.readOnlyExternal]** — call the rule inside a journal
///   scope. Its decision is re-computed, but its *observations* are
///   served from the journal (the journal).
/// * **[Purity.effectful]** — do **not** call the rule on replay;
///   consume its recorded `VerdictEffect`. On the recording side the
///   rule runs once inside `journal.verdict` and its decision is
///   journaled. If the replay journal has no verdict for the current
///   input, the journal throws [ReplayDivergenceException] — the rule
///   changed since the recording.
///
/// ### Where the *version* dispatch lives
///
/// This class dispatches on **purity only**. The
/// receptor/rule **version** boundary is enforced one level up, by
/// `ReplayEngine._checkVersions` before any dispatch happens: the
/// recorded versions must be satisfied by the graph's `VersionRegistry`
/// or by the live implementations matching exactly — otherwise the
/// engine reports a divergence without calling the rule at all.
abstract final class TestCellReplay {
  /// Invokes [rule] on [object] with the current journal, honouring its
  /// purity. Returns the rule's decision.
  ///
  /// [ruleLabel] is a stable string identifying the rule in the
  /// journal's `VerdictEffect`. It is conventionally
  /// `${rule.runtimeType}@${rule.version}`.
  static FutureOr<bool> invoke({
    required TestCell rule,
    required Object? object,
    required Cell host,
    required EffectJournal journal,
    required String ruleLabel,
  }) {
    switch (rule.purity) {
      case Purity.pure:
        // Synchronous rules stay synchronous — the framework's pulse
        // contract depends on it.
        return rule.call(object, host: host);

      case Purity.readOnlyExternal: {
        // The rule runs; its external reads go through the journal.
        // The journal is already in scope (the journal), so the rule's
        // `journal.io(...)` calls will be served from it. Records
        // written while the rule runs are swept cooperatively into the
        // active LedgerScope (the the journal asyncMap pattern).
        final before = journal.consumed;
        final result = rule.call(object, host: host);
        if (result is Future<bool>) {
          return result.then((decision) {
            _sweepCaptured(journal, before);
            return decision;
          });
        }
        _sweepCaptured(journal, before);
        return result;
      }

      case Purity.effectful:
        // The rule's decision is a recorded effect. On the recording
        // side `run` executes the rule exactly once; on the replay
        // side ReplayJournal.verdict serves the recorded verdict and
        // ignores `run`.
        final before = journal.consumed;
        return journal
            .verdict(
              ruleLabel: ruleLabel,
              input: _encodeForVerdict(object),
              run: () => rule.call(object, host: host),
            )
            .then((decision) {
          _sweepCaptured(journal, before);
          return decision;
        });
    }
  }

  /// Cooperatively hands records written by the rule to the active
  /// [LedgerScope] (the journal pattern). No-op without a ledger scope or
  /// on the replay side, where the journal is consumed rather than
  /// written.
  static void _sweepCaptured(EffectJournal journal, int before) {
    if (journal is! RecordingJournal) return;
    for (final record in journal.recordsSince(before)) {
      LedgerScope.captureEffect(record);
    }
  }

  static Object? _encodeForVerdict(Object? v) {
    if (v == null || v is num || v is bool || v is String) return v;
    if (v is Pulse) {
      // Encode the pulse's payload and type; that is what a rule
      // typically inspects.
      return {
        'payload': _encodeForVerdict(v.payload),
        'type': v.type,
      };
    }
    return v.toString();
  }
}
