// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The task-local stack of active journals.
///
/// The stack, not a single slot, because nested operations are real:
/// a transaction inside a recording may run a what-if branch, which
/// pushes a `ReplayJournal` on top. The inner branch sees its replay
/// journal; when it pops, the outer recording resumes.
///
/// The stack lives in a `Zone` — this is the *only* place in the plan
/// where a Zone is used, and it is used because Dart has no task-local
/// storage primitive. Unlike a general "put the journal in the zone"
/// pattern, the stack is drained on scope exit, so a spawned task that
/// outlives the scope sees an empty stack and `EffectJournal.current`
/// returns `NullJournal`. That is the correct behaviour: a leaked task
/// has no journal, so its effects fail loudly.
abstract final class JournalScope {
  static final Object _key = Object();

  static final Zone _root = Zone.root;

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
  /// (or letting `ReplayEngine` do it).
  static Future<T> run<T>(
    EffectJournal journal,
    FutureOr<T> Function() body,
  ) async {
    final existing = Zone.current[_key] as List<EffectJournal>?;
    final stack = existing ?? <EffectJournal>[];
    final zoned =
        existing == null ? _root.fork(zoneValues: {_key: stack}) : Zone.current;
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
  static T runSync<T>(EffectJournal journal, T Function() body) {
    final existing = Zone.current[_key] as List<EffectJournal>?;
    final stack = existing ?? <EffectJournal>[];
    final zoned =
        existing == null ? _root.fork(zoneValues: {_key: stack}) : Zone.current;
    stack.add(journal);
    journal.push();
    try {
      return zoned.run(body);
    } finally {
      stack.removeLast();
      journal.pop();
    }
  }
}
