// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';

import 'codec.dart';
import 'memory_cell.dart';
import 'policy.dart';
import 'scheduler.dart';
import 'store.dart';

/// Opens a memory cell for [domain], loads it, and attaches it.
///
/// Sugar for `MemoryCell.open` + [MemoryCell.attach]. [project] pulls the
/// value to store out of the domain pulse. For a `Cell.state<T>` the
/// projection is typically `(pulse) => pulse.payload as T? ?? initial`;
/// for other shapes the caller supplies the mapping. A failed projection
/// throws [MemoryCorrupt] inside the cell and does not write.
///
/// The returned cell retains the domain's accepted pulses through the
/// framework's public observer binding (see the README "Verified against"
/// block for why at cell 2.1.0 a `Cell.state` cannot be linked from
/// directly).
///
/// [seed] is the supported way to push a loaded value into the domain
/// cell: it is called with `memory.value` after [MemoryCell.open] returns
/// and **before** [MemoryCell.attach] installs the observer, so a domain
/// update inside it is not echoed back into the memory cell. Skipping
/// [seed] leaves the domain at its own initial value; the next domain
/// pulse then overwrites memory. If [seed] or [MemoryCell.attach] throws,
/// the opened cell is closed (releasing an owned store) before the error
/// propagates, so a failed remember leaks nothing.
///
/// ### When to use
/// Use [remember] when an existing cell is the source of truth and the
/// memory cell should follow its accepted pulses. The typical call is
/// inside the composition root: a `Cell.state` (or any cell) has already
/// been created; [remember] opens a memory cell bound to it, seeds it from
/// the loaded value on the first run, and attaches the observer so every
/// later pulse is persisted.
///
/// Use [MemoryCell.open] followed by [MemoryCell.attach] instead when the
/// caller needs to run code between open and attach that [seed] does not
/// cover — for example, wiring downstream listeners on the memory cell, or
/// inspecting [MemoryCell.lastError] before the observer can add traffic.
///
/// Use [MemoryCell.open] alone when the domain cell is not created yet, or
/// when persistence is driven by direct ingress rather than an upstream
/// cell. [remember] is only the two-cell shape.
///
/// ### How it works
/// 1. **[MemoryCell.open]** runs with the caller-supplied [id], [store],
///    [codec], [initial], [context], [policy], [loadOnOpen], [scheduler],
///    and [ownsStore]. The cell loads the last envelope (unless
///    `loadOnOpen: false`) and emits [MemoryEvent.loaded] if a record was
///    found.
/// 2. **[seed] (optional)** runs synchronously with the loaded value. The
///    domain cell may update inside it; that update is not echoed back
///    into the memory cell because the observer is not installed yet.
/// 3. **[MemoryCell.attach]** installs the observer. Every accepted domain
///    pulse is projected with [project] and adopted as the retained value,
///    subject to the memory cell's write policy.
/// 4. **Return** — the returned [MemoryCell] is the same one opened in
///    step 1, now wired to the domain. Its [MemoryCell.loaded],
///    [MemoryCell.value], [MemoryCell.dirty], and other public state are
///    already correct.
/// 5. **Failure path** — if [seed] or [MemoryCell.attach] throws, the
///    opened cell is closed before the error propagates, so a failed
///    [remember] does not leak a store or an open cell.
///
/// ### Non-obvious
/// - **[seed] runs before attach, deliberately.** The domain must not be
///   observed while it is being seeded, or the seed itself would be
///   re-recorded as a fresh update. Installing the observer after [seed]
///   is what makes the "load once, follow after" contract work.
/// - **A failed [project] is [MemoryCorrupt], not an exception through
///   [remember].** The projection runs inside the cell on the observer
///   path, so a projection error is reported on [MemoryCell.errors] and
///   the pulse is dropped. A caller that wants to react should subscribe
///   to [MemoryCell.errors] after the returned cell is in hand.
/// - **`project` fires once per accepted domain pulse.** If the domain
///   cell does not emit on its own initial value, the memory cell starts
///   with [initial] (or the loaded value when [loadOnOpen] is true), and
///   stays there until the domain changes.
/// - **`seed` sees the loaded value, not [initial].** On the first run,
///   [seed] is called with whatever the store returned — the loaded value
///   on a hit, [initial] on a miss. After a hit, [initial] is unused; on a
///   miss, [initial] is what [seed] sees.
/// - **Failure after open closes the cell.** Closing releases an owned
///   store (when [ownsStore] is true) and detaches the observer, so a
///   caught [remember] failure can be retried after fixing the cause
///   without leaking the previous attempt.
///
/// ### Parameters:
/// * [domain]: The upstream cell to observe. Every accepted pulse from
///   this cell is projected with [project] and persisted.
/// * [id]: The stable memory id — the file name or document id. Never
///   derived from `Cell.id`; see [MemoryIdGrammar].
/// * [store]: The durable backend. Use [InMemoryMemoryStore] for tests and
///   replay hosts, `FileMemoryStore` for local disk, or a cloud backend.
/// * [codec]: How a value of type [T] is encoded and decoded. Use
///   [JsonMemoryCodec.identity] when [T] is already JSON-shaped, or
///   [JsonMemoryCodec.mapped] with a `toJson` / `fromJson` pair.
/// * [project]: Pulls a [T] out of a domain [Pulse]. For a
///   `Cell.state<T>`, the typical form is
///   `(pulse) => pulse.payload as T? ?? initial`.
/// * [initial]: The value used when the store is empty. Ignored on a hit;
///   [seed] sees the loaded value, not this.
/// * [context]: The [Context] the memory cell runs under. Defaults to
///   [Context.system].
/// * [policy]: The write-through configuration. Defaults to
///   [MemoryWriteMode.debounced] with a 300 ms quiet period. Pass
///   [MemoryWritePolicy.replay] for Causal Replay (no writes).
/// * [loadOnOpen]: Whether to load the stored value on open. Defaults to
///   `true`; pass `false` with [MemoryWritePolicy.replay] during replay.
/// * [scheduler]: The debounce scheduler. Defaults to [TimerScheduler];
///   tests pass [ManualScheduler] for determinism.
/// * [ownsStore]: Whether closing the returned cell closes [store]. Pass
///   `true` only when the store was opened for this cell alone.
/// * [seed]: Optional callback invoked with the loaded value before the
///   domain observer is installed. Use it to push the loaded value back
///   into the domain cell.
///
/// ### Returns:
/// The opened [MemoryCell] attached to [domain]. Its loaded value (if
/// any) has already been applied and, when [seed] was provided, also
/// pushed into [domain]. Future domain pulses are persisted according to
/// [policy].
///
/// ### Example: Persist a `Cell.state` across restarts
/// ```dart
/// final counter = Cell.state<int>(initial: 0);
///
/// final memory = await remember<int>(
///   counter.cell,
///   id: 'counter',
///   store: InMemoryMemoryStore(),
///   codec: JsonMemoryCodec<int>.identity(),
///   project: (pulse) => pulse.payload as int? ?? 0,
///   seed: (loaded) {
///     if (loaded != null) counter.update(loaded);
///   },
/// );
///
/// counter.update(41);      // persisted on the next write
/// await memory.save();     // forced write; emits MemoryEvent.stored
/// await memory.close();
/// ```
///
/// ### See also
/// - [MemoryCell] — the durable cell [remember] returns.
/// - [MemoryCell.open] — the lower-level entry point [remember] wraps.
/// - [MemoryCell.attach] — the observer binding [remember] installs.
/// - [MemoryWritePolicy] — the write policy [remember] forwards.
/// - [MemoryIdGrammar] — the stable-id law every id must satisfy.
///
/// ### AI Agent Guide
/// **Layer:** Memory — one-call sugar over [MemoryCell.open] and
/// [MemoryCell.attach]. Not a Cell factory, not a Flow operator.
/// **When to use:** a domain cell already exists and the memory cell
/// should follow its accepted pulses. Persist a `Cell.state`, a
/// `Cell.derive` projection, or any single-upstream value.
/// **When NOT to use:**
///   - when persistence is driven by direct ingress rather than an
///     upstream cell — use [MemoryCell.open] alone;
///   - when the memory cell is not a follower but the source of truth —
///     open it and bind downstream cells to it instead;
///   - when a collection needs row history — that is `cell_tissue`, not
///     `cell_memory`.
/// **Live signature:** `Future<MemoryCell<T>> remember<T>(Cell domain,
/// {required String id, required MemoryStore store, required
/// MemoryCodec<T> codec, required T? Function(Pulse) project, T? initial,
/// Context context = Context.system, MemoryWritePolicy policy =
/// const MemoryWritePolicy(), bool loadOnOpen = true, MemoryScheduler?
/// scheduler, bool ownsStore = false, void Function(T?)? seed})` — pinned
/// at `cell_memory: 0.1.0`.
/// **Do NOT confuse with:** [MemoryCell.open] (opens without attaching)
/// or [MemoryCell.attach] (attaches without opening). [remember] is the
/// two together, plus the optional [seed] step between them.
/// **Guide:** see the memory HowTo for "remembering a `Cell.state`" and
/// "why seed runs before attach".
/// **Example:** `example/memory_example.dart`.
/// **Cross-layer:** [remember] is the Flow → Memory glue for persistence;
/// the *decision* about what to persist stays in a `cell_flow` instruction
/// that feeds [domain].
/// **Minimal compilable example**
/// ```dart
/// final counter = Cell.state<int>(initial: 0);
/// final store = InMemoryMemoryStore();
/// final memory = await remember<int>(
///   counter.cell,
///   id: 'counter',
///   store: store,
///   codec: JsonMemoryCodec<int>.identity(),
///   project: (pulse) => pulse.payload as int? ?? 0,
///   seed: (loaded) {
///     if (loaded != null) counter.update(loaded);
///   },
/// );
/// print(memory.value); // 0
/// await memory.close();
/// await store.close();
/// ```
Future<MemoryCell<T>> remember<T>(
    Cell domain, {
      required String id,
      required MemoryStore store,
      required MemoryCodec<T> codec,
      required T? Function(Pulse pulse) project,
      T? initial,
      Context context = Context.system,
      MemoryWritePolicy policy = const MemoryWritePolicy(),
      bool loadOnOpen = true,
      MemoryScheduler? scheduler,
      bool ownsStore = false,
      void Function(T? loaded)? seed,
    }) async {
  final memory = await MemoryCell.open<T>(
    id: id,
    store: store,
    codec: codec,
    initial: initial,
    context: context,
    policy: policy,
    loadOnOpen: loadOnOpen,
    scheduler: scheduler,
    ownsStore: ownsStore,
  );
  try {
    if (seed != null) seed(memory.value);
    await memory.attach(domain, project: project);
  } catch (_) {
    await memory.close();
    rethrow;
  }
  return memory;
}