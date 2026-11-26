# Changelog

## Memory (1.1.0)

`MemoryCell` becomes a full `CellBase` citizen: one nucleus
(`MemoryCellNucleus`, exported), one mutable runtime per `open`, and every
durability operation routed through the same `apply`, `validate`, and
receptor chain as the rest of the framework. The durability methods keep
their signatures and their error behavior (`MemoryCorrupt`,
`MemoryConflict`, `StateError`); a non-default `TestCell` can now refuse
them, and `deputy()` / `unmodifiable` return memory-typed views of the
same runtime.

- **nucleus:** `MemoryCellNucleus<T>` (exported) holds the immutable
  per-open slots (id, store, codec, policy, scheduler, store ownership)
  and the one `MemoryRuntime<T>` that owns every mutable field (value,
  revision, generation, epoch, dirty/closed/closing flags, the turn,
  write, and ingress chains, the error stream, and the attach wiring).
  `clone` and `evolve` share the principal's runtime; two `open` calls
  never do. `Cell.id` and `memoryId` remain separate namespaces.
- **receptor chain:** the receptor closure is replaced by a one-stage
  dispatcher `Instruction.chain` — the Phase 1 spike's measured
  **Fork Dispatcher** (a custom `strategy` never receives the receptor
  continuation). `MemoryAction` (exported) names the eight actions
  (`apply`, `load`, `save`, `unload`, `attach`, `detach`, `close`,
  `remove`); each public method submits a `MemoryCommand` (a `Pulse`
  carrying the action and the reply completer — never broadcast to
  observers) through `Cell.apply` and awaits its own completer. Exactly
  one broadcast per action: the receptor continuation delivers the
  resumed `MemoryPulse`; no instruction calls `synapses` itself.
- **apply gate:** `load`, `save`, `unload`, `attach`, `detach`, `close`,
  and `remove` now pass the `TestCell` integrity gate — previously they
  bypassed `validate`, so a read-only view could not refuse them. A
  rejected tear-off surfaces as `StateError('<action> rejected')` and
  performs no I/O. Default constructors are unchanged
  (`TestCell.allowAll`).
- **wrapper-safe echo:** the framework hands instructions a step wrapper,
  so echo suppression now reads the delegating `Pulse.type` / `source`
  surface: this cell's own memory pulses and `removed` / `unloaded`
  events are dropped without a write, including relayed or evolved
  pulses. `Cell.transaction` commits (`Pulse.governed`) select the
  `apply` action.
- **deputy:** `deputy()` returns a memory-typed `MemoryCell<T>` sharing
  the principal's runtime, store, and codec; default arguments return
  `this`. The deputy nucleus has no `bind` (a bind would re-adopt every
  principal pulse) and installs its own cloned receptor and synapse
  registry. `MemoryCell.allow({MemoryAction...})` narrows by action set
  and chains additively — permissions can only shrink. A load-only
  deputy loads the principal's value and rejects `save`; governed
  transaction commits are refused. `==`, `hashCode`, and `Cell.id` stay
  root-based while `memoryId` stays the store key.
- **unmodifiable:** `unmodifiable` returns a cached read-only `MemoryCell`
  whose `validate` chains the principal's rule, `TestCell.readOnly`, and
  a drop-all-adopts rule; `load`, `save`, `unload`, `attach`, `detach`,
  `close`, and `remove` throw `UnsupportedError` before `apply`, and
  `deputy(...)` / `unmodifiable` return the view itself. `value` still
  reads the shared runtime.
- **broadcast:** pulses produced through a deputy (e.g. a context-only
  deputy's `save`) are mirrored to the principal's registry once, so
  principal observers hear them, and each registry receives exactly one
  callback. Principal emissions stay on the principal registry —
  observers of the `unmodifiable` view do not hear principal saves.
- **lifecycle:** `close()` does not set `isInvalidated`. A deputy built
  with an already-invalidated `EphemeralPolicy` rejects its next command
  at `_proceed` before any store read or write — the framework's drop
  semantics, not a `close()`.
- **tests:** `memory_cell_nucleus_test`, `memory_cell_chain_test`, and
  `memory_cell_deputy_test` pin the runtime sharing, the one-broadcast
  rule, the CAS / seed-before-attach / single-flush preservation, and the
  deputy narrowing rules.

## Memory (1.0.0)

The first public release; the `Unreleased` notes from the protocol,
lifecycle, and store workstreams become this section. The breaking list:
required `generation`, `kind == 'value'` only, `MemoryNotFound`
removed, one-write `save` with the public `dirty` flag, the synchronous
ingress latch on `unload`/`close`, the shared `StoreLifecycle`
shutdown barrier, fail-closed `list`, case-collision refusal and
directory id-mismatch checks, and the recovered lost response emitting
`stored`.


- **Protocol:** `MemoryEnvelope` requires `generation` — 32
  lowercase hex characters, minted once per record life with
  `MemoryEnvelope.mintGeneration()` and copied on every update. A 0.1.0
  document without `generation` is `MemoryCorrupt`, and 0.1.0 readers
  cannot open documents written by this change. `MemoryEnvelope.kinds` is
  `{value}` only; `pulse` / `tissue` / `snapshot` no longer decode.
  `sameContent` compares `generation`; `toJson` stores the canonical
  payload (`JsonPayloadKey.canonical`, nested map keys sorted) in the
  stable key order `schema, id, kind, revision, generation, updatedAt,
  codec, sourceCellId, payload`.
- **CAS:** every store runs retry → `checkRevision` →
  `checkGeneration` → `checkNumbering`. A write whose generation differs
  from the stored row's is `MemoryConflict` — a stale generation after
  delete-and-recreate can no longer win a revision (the ABA hole is
  closed). `MemoryConflict` carries `stored` (the winning row, when the
  backend has it). `MemoryNotFound` is removed.
- `MemoryCell` remembers the generation it loaded, mints one for a create,
  resends it across a lost-response retry, and drops it on remove and on a
  real conflict. `open` validates the id with the shared
  `MemoryIdGrammar`. `load` rejects an envelope whose id differs from the
  cell's.
- `FirebaseMemoryStore` writes `generation`, stores the canonical payload,
  requires a generation match on the set branch, and returns conflicts
  carrying the stored row. `firestore.rules` enforces `generation`
  (pattern, frozen on update), `kind == 'value'`, and the id grammar; the
  rules harness gained the generation and id-grammar group.
- The shared store contract suite gained the generation table (create,
  wrong-generation update, ABA recreation, both retry shapes) and the
  hostile-id case, run against in-memory and file stores plus the
  scripted Firebase double.
- **lifecycle:** `close()` and `unload()` latch ingress
  synchronously when they return their future — a pulse that arrives
  after the call is not a value. The flush waits for the in-flight write
  and issues at most one more write; `close()` no longer persists a pulse
  that arrives after it was called. `save()` performs one write, no loop:
  it can return while a newer value is still pending, and the public
  `dirty` flag reports that. Lost-response recovery now emits `stored`
  when the recovered row is still the current value. `close()` releases an
  owned store exactly once, even after a failed `unload`; `unload()` never
  closes the store. `remember` gains `seed`, called after load and before
  attach; `withStep` / `evolve` keep `source` (asserted), so relayed
  self-pulses stay echoes.
- **stores:** all three backends share one admission and
  shutdown barrier (`StoreLifecycle`): an operation that entered finishes
  even if `close` flips the flag while it is queued, a call that has not
  entered throws `StateError`, and a second `close` throws. Firestore
  transaction callbacks return `MemoryCorrupt` and `MemoryConflict`
  rather than throwing them (`FirebaseException` remains the only
  exception mapped to `MemoryIoException`). `list` fails closed on both
  backends: one id that fails the grammar (or a case collision, for files)
  fails the whole call and deletes nothing. Directory reads reject an
  envelope whose id is not the filename; case-distinct file names are
  refused on read, write, and list; the file tmp is written with
  `writeFrom` + `flush`.
