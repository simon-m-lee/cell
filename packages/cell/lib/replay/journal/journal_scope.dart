// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The task-local stack of active journals.
///
/// ### How it works
/// The stack, not a single slot, because nested operations are real:
/// a transaction inside a recording may run a what-if branch, which
/// pushes a `ReplayJournal` on top. The inner branch sees its replay
/// journal; when it pops, the outer recording resumes.
///
/// The stack lives in a `Zone` — the only place in the replay module
/// where a Zone is used, and it is used because Dart has no task-local
/// storage primitive. Unlike a general "put the journal in the zone"
/// pattern, the stack is drained on scope exit, so a spawned task that
/// outlives the scope sees an empty stack and [EffectJournal.current]
/// returns `NullJournal`. That is the correct behaviour: a leaked task
/// has no journal, so its effects fail loudly.
///
/// See also:
/// * [EffectJournal.current] — reads the top of this stack.
/// * [run], [runSync] — push a journal for the duration of a body.
/// {@category Replay}
abstract final class JournalScope {
  static final Object _key = Object();

  /// The top of the current journal stack, or [NullJournal.instance] if
  /// empty. **Never returns a no-op journal that silently swallows
  /// effects** — the sentinel fails loudly, by design.
  static EffectJournal get current {
    final stack = Zone.current[_key] as List<EffectJournal>?;
    if (stack == null || stack.isEmpty) return NullJournal.instance;
    return stack.last;
  }

  /// Runs [body] with [journal] pushed on the stack. The journal is
  /// popped when [body] completes, whether normally or with an error.
  ///
  /// The caller is responsible for calling `assertExhausted` afterwards
  /// (or letting [ReplayEngine] do it).
  ///
  /// ### Parameters:
  /// - [journal]: The journal to push.
  /// - [body]: The work to run with the journal in scope.
  ///
  /// ### Non-obvious: nested scopes share the stack
  ///
  /// The outermost scope forks the current zone and owns the stack;
  /// nested scopes deliberately skip the fork and push/pop the SAME
  /// list. The ambient journal at any instant is therefore the
  /// *innermost active* scope. Two consequences:
  ///
  /// * A continuation created inside a nested scope resumes after that
  ///   scope pops: it observes the outer journal, not `NullJournal`.
  ///   Only when the **outermost** scope pops does the ambient become
  ///   the loud `NullJournal` sentinel — the fail-loud-after-pop
  ///   contract applies at the outermost boundary.
  /// * [ReplayEngine] relies on this: operators push their own scopes
  ///   with the same effective journal, so the per-entry [ReplayJournal]
  ///   stays ambient throughout, including detached continuations.
  static Future<T> run<T>(
    EffectJournal journal,
    FutureOr<T> Function() body,
  ) async {
    final existing = Zone.current[_key] as List<EffectJournal>?;
    final stack = existing ?? <EffectJournal>[];
    // The outermost scope forks from the *current* zone — not the root —
    // so error handlers and zone values of the surrounding context (e.g.
    // the test runner's guarded zone) are inherited. Nested scopes reuse
    // the existing stack and skip the fork.
    final zoned = existing == null
        ? Zone.current.fork(zoneValues: {_key: stack})
        : Zone.current;
    stack.add(journal);
    journal.push();
    try {
      return await zoned.run(body);
    } finally {
      stack.removeLast();
      journal.pop();
    }
  }

  /// The synchronous variant, for callers that know [body] is
  /// synchronous. Pop is still guaranteed on throw.
  ///
  /// ### Parameters:
  /// - [journal]: The journal to push.
  /// - [body]: The synchronous work to run.
  ///
  /// ### Returns:
  /// The body's result.
  static T runSync<T>(EffectJournal journal, T Function() body) {
    final existing = Zone.current[_key] as List<EffectJournal>?;
    final stack = existing ?? <EffectJournal>[];
    final zoned = existing == null
        ? Zone.current.fork(zoneValues: {_key: stack})
        : Zone.current;
    stack.add(journal);
    journal.push();
    try {
      return zoned.run(body);
    } finally {
      stack.removeLast();
      journal.pop();
    }
  }

  /// The journal an effectful operator should actually use: the ambient
  /// journal when an outer scope has pushed one (the [ReplayEngine]
  /// pushes a per-entry [ReplayJournal] around the dispatch), otherwise
  /// the journal the operator captured at construction.
  ///
  /// ### How it works
  /// The ambient can only be observed *before* the operator pushes its
  /// own scope; the operator then pushes `effectiveJournal` so the
  /// mapper sees the same journal through both channels.
  ///
  /// ### Parameters:
  /// - [captured]: The journal the operator captured at construction.
  ///
  /// ### Returns:
  /// The ambient journal when one is in scope, otherwise [captured].
  static EffectJournal effectiveJournal(EffectJournal captured) {
    final ambient = current;
    return identical(ambient, NullJournal.instance) ? captured : ambient;
  }
}
