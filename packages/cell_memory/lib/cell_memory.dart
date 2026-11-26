// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The **Durable Memory Surface** of the Cell framework — the
/// **Hippocampus** where a reactive signal becomes a stable, replayable
/// record.
///
/// Memory retains the latest value; the ledger retains causality. A
/// [MemoryCell] is itself a `Cell` — it loads stored data, receives pulses
/// through the framework, and emits [MemoryPulse]s downstream. Backends
/// implement [MemoryStore]; this library ships the pure-Dart surface plus
/// [InMemoryMemoryStore]. The `dart:io`-based [FileMemoryStore] lives in
/// `package:cell_memory/cell_memory_io.dart`, so importing this library
/// never pulls `dart:io` into a web build.
///
/// In the framework's biological metaphor, this is the **Hippocampus**:
/// where short-lived signal activity is consolidated into a long-lived
/// engram that survives the process. The `cell` package is the nervous
/// system; this package is the durable trace it leaves.
///
/// ### When to use
/// Import `package:cell_memory/cell_memory.dart` when the app needs a
/// reactive value to survive a process restart: remembered settings, a
/// last-known selection, a persisted counter, an offline-tolerant cache of
/// the latest read from a remote source.
///
/// Use [remember] for the one-call open + seed + attach shape; use
/// [MemoryCell.open] followed by [MemoryCell.attach] when the seed step
/// needs to run between open and attach, or when the cell is bound to an
/// already-running domain.
///
/// For a pure-in-memory test double, [InMemoryMemoryStore] from this
/// library is enough. For disk, add `cell_memory_io.dart` and use
/// `FileMemoryStore`. For cloud, add the Firestore backend package; the
/// [MemoryStore] contract is the same.
///
/// ### How it works
/// 1. **Open** — [MemoryCell.open] takes a stable id, a store, a codec,
///    and a write policy. It reads the last envelope (unless
///    `loadOnOpen: false`), decodes the payload, and emits one
///    [MemoryPulse] of [MemoryEvent.loaded].
/// 2. **Ingest** — Accepted pulses from an attached upstream cell, from
///    `remember`'s domain binding, or from direct ingress are encoded,
///    adopted as the in-memory value, and a write is scheduled according
///    to the policy. Every value movement is broadcast as a
///    [MemoryPulse] — [MemoryEvent.applied] for an update,
///    [MemoryEvent.stored] for a successful write.
/// 3. **Commit** — A write goes through [MemoryStore.write] under
///    compare-and-swap. The record's `revision` advances; its
///    `generation` is preserved (replaced only on delete-and-recreate).
/// 4. **Replay** — [MemoryWritePolicy.replay] (a policy with
///    `enabled: false`) together with `loadOnOpen: false` lets a Causal
///    Replay host run historical pulses through the cell without writing
///    them back to the store.
///
/// ### Non-obvious
/// - **Stable ids, not `Cell.id`.** The memory id is a durable name chosen
///   by the caller. `Cell.id` is assigned per process and would rename the
///   record on every restart. The two namespaces are unrelated; the id
///   passed to [MemoryCell.open] is what names the record.
/// - **Revision vs. generation.** `revision` is monotonic per id and
///   advances on every successful write. `generation` is minted once per
///   record life and copied on every revision, so a delete-and-recreate
///   cannot be masqueraded by a stale writer as a normal update. See
///   [MemoryStoreCas].
/// - **Codec-owned equality.** A cell is dirty when the codec's encoded
///   payload differs from what is stored — not when `T.==` says so. Two
///   domain objects that compare equal as Dart values can still differ
///   once encoded, and vice versa.
/// - **Shutdown is a barrier.** A store call that was admitted finishes
///   even if `close()` is called while it is queued; a call that arrives
///   after `close()` throws. `list()` returns a settled snapshot. See
///   [MemoryStore.close] for the per-backend semantics.
///
/// ### See also:
/// - [MemoryCell] — the durable cell this library exists to provide.
/// - [MemoryStore] — the backend contract every store implements.
/// - [MemoryEnvelope] — the JSON document a backend persists.
/// - [MemoryIdGrammar] — the stable-id law shared by every backend.
/// - [MemoryWritePolicy] — when a write is scheduled (immediate,
///   debounced, explicit, replay).
/// - [remember] — one-call sugar for open + attach + seed.
///
/// ### AI Agent Guide
/// **Layer:** Memory — this is the persistence seam. Not a `Cell` factory,
/// not a `Flow` operator, not a `Tissue` book. Memory retains the **latest**
/// value; the ledger retains the **causality**; this library durably
/// persists that latest value.
/// **When to use:** a BRD says "remember this across restarts", "persist
/// this setting", or "load the last known value on boot".
/// **When NOT to use:**
///   - for causal history (that is the ledger);
///   - for optimistic concurrency across many records (that is a Firestore
///     transaction, not a per-id CAS);
///   - when the value is genuinely ephemeral — a `Cell.state` with no
///     durability requirement is simpler;
///   - as a substitute for a `cell_tissue` book — memory stores one value
///     per id, not a collection.
/// **Live signature:** `library cell_memory;` — pinned at
/// `cell_memory: 0.1.0`.
/// **Do NOT confuse with:** the core `cell` library (reactive graph, no
/// persistence), `cell_memory_io` (the `dart:io` backend split), or
/// `cell_tissue` (collection history, not single-value durability).
/// **Guide:** see the memory HowTo for "choosing a store backend" and
/// "when to use `remember` vs. `MemoryCell.open` + `attach`".
/// **Example:** `example/memory_example.dart`.
/// **Cross-layer:** a `Cell.observe` side effect that writes into a
/// [MemoryCell] is the Flow → Memory glue for persistence; the *decision*
/// about what to persist stays in a `cell_flow` instruction.
/// **Minimal compilable example**
/// ```dart
/// final store = InMemoryMemoryStore();
/// final counter = await MemoryCell.open<int>(
///   id: 'counter',
///   store: store,
///   codec: JsonMemoryCodec<int>.identity(),
///   initial: 0,
/// );
/// print(counter.loaded); // true
/// await counter.close();
/// await store.close();
/// ```
library;

export 'src/codec.dart'
    show MemoryCodec, MemoryNotSerializable, JsonMemoryCodec;
export 'src/envelope.dart' show JsonPayloadKey, MemoryEnvelope;
export 'src/id.dart' show MemoryIdGrammar;
export 'src/memory_cell.dart'
    show MemoryAction, MemoryCell, MemoryCellNucleus;
export 'src/memory_pulse.dart'
    show
    CollectiveMemoryPulse,
    MemoryEvent,
    MemoryPulse,
    memoryApplied,
    memoryLoaded,
    memoryRemoved,
    memoryStored,
    memoryUnloaded;
export 'src/policy.dart' show MemoryWriteMode, MemoryWritePolicy;
export 'src/remember.dart' show remember;
export 'src/scheduler.dart'
    show ManualScheduler, MemoryScheduler, TimerScheduler;
export 'src/store.dart'
    show
    MemoryConflict,
    MemoryCorrupt,
    MemoryIoException,
    MemoryStore,
    MemoryStoreCas,
    MemoryStoreException;
export 'src/stores/in_memory_store.dart' show InMemoryMemoryStore;

// ci: memory workflow trigger marker (remove in a later cleanup).