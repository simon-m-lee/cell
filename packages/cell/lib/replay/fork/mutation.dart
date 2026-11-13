// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A what-if mutation hook.
///
/// The engine calls `mutation(entry, pulse)` for each entry it is about
/// to replay. The return value controls what happens to that entry in
/// the fork:
///
/// * **`null`** — drop the entry. The fork ledger will not contain a
///   record of this pulse. Used for "what if this command had never
///   been sent".
/// * **A different pulse** — replace the entry. The fork replays the
///   new pulse instead of the recorded one. Used for "what if the user
///   had picked plan B".
/// * **The same pulse** (identical payload and metadata) — replay
///   unchanged. The common case; a mutation that only cares about
///   `seq == 150` returns `pulse` for every other seq.
///
/// ### Non-obvious: the hook sees the *reconstructed* pulse, not the
/// recorded payload
///
/// The engine reconstructs the input pulse from the entry (the replay
/// `PulseReconstructor`), then calls the hook. This means the hook has
/// access to the pulse's `source`, `timestamp`, and `priority` — not
/// just the payload. A mutation that wants to inject a different
/// priority can do so; a mutation that wants to change the source
/// would break the reconstruction's cell resolution, so the hook is
/// documented as "payload and metadata, not identity".
///
/// ### Non-obvious: dropping an entry does *not* drop its effects
///
/// The effects belong to the entry's `ReplayJournal`. If the entry is
/// dropped, the journal is not consumed, which means subsequent entries
/// would see the wrong effects. The fork engine handles this by **also**
/// dropping the entry's effects from the fork ledger — the fork's
/// entries have their own effects, recorded during the fork's replay,
/// not inherited from the parent. This is why the fork ledger
/// re-appends each replayed pulse even when the mutation returns
/// `pulse` unchanged: the effects have to be re-recorded.
typedef Mutation = Pulse? Function(LedgerEntry entry, Pulse pulse);
