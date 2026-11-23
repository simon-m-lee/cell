# Changelog

## 1.0.0

The first public release; the `Unreleased` notes from the protocol,
lifecycle, and store workstreams become this section. The breaking list:
required `generation`, `kind == 'value'` only, `MemoryNotFound`
removed, one-write `save` with the public `dirty` flag, the synchronous
ingress latch on `unload`/`close`, the shared `StoreLifecycle`
shutdown barrier, fail-closed `list`, case-collision refusal and
directory id-mismatch checks, and the recovered lost response emitting
`stored`. The `0.1.0` section below is history, kept for reference.


- **Breaking (protocol):** `MemoryEnvelope` requires `generation` — 32
  lowercase hex characters, minted once per record life with
  `MemoryEnvelope.mintGeneration()` and copied on every update. A 0.1.0
  document without `generation` is `MemoryCorrupt`, and 0.1.0 readers
  cannot open documents written by this change. `MemoryEnvelope.kinds` is
  `{value}` only; `pulse` / `tissue` / `snapshot` no longer decode.
  `sameContent` compares `generation`; `toJson` stores the canonical
  payload (`JsonPayloadKey.canonical`, nested map keys sorted) in the
  stable key order `schema, id, kind, revision, generation, updatedAt,
  codec, sourceCellId, payload`.
- **Breaking (CAS):** every store runs retry → `checkRevision` →
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
- **Breaking (lifecycle):** `close()` and `unload()` latch ingress
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
- **Breaking (stores):** all three backends share one admission and
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

## 0.1.0

- Initial release.
- `MemoryEnvelope` schema 1: `schema`, `id`, `kind`, `revision`, `updatedAt`,
  `codec`, `sourceCellId`, `payload`; unknown schema and unknown keys fail
  closed.
- `MemoryStore` contract with compare-and-swap `write(expectedRevision:)`,
  `read`, `remove`, `list`, and `close`. `InMemoryMemoryStore` and
  `FileMemoryStore` (directory and single-file modes). Both stores implement
  the same idempotent retry: a repeated envelope at the expected revision,
  or this writer's own payload at `expected + 1` (the lost-response case),
  is a successful no-op. A shared contract suite runs against both.
- `MemoryCodec` and `JsonMemoryCodec` (`identity` / `mapped`). `encode`
  returns a JSON-decoded deep copy, so stored payloads never alias the
  retained value and backends cannot drift. Non-JSON values throw
  `MemoryNotSerializable` before any store write.
- `MemoryWriteMode` (`immediate`, `debounced` 300 ms, `explicit`) and
  `MemoryWritePolicy`, including `MemoryWritePolicy.replay` which performs
  zero writes.
- `MemoryPulse` / `MemoryEvent` (`loaded`, `applied`, `stored`, `unloaded`,
  `removed`). A `MemoryPulse` implements `Pulse`.
- `MemoryCell<T>` extends the framework's public `CellBase` extension seam
  (see README "Verified against" — `implements Cell` is a runtime stop at
  cell 2.1.0). Public `load`, `save`, `unload`, `remove`, `attach`, `detach`,
  and `close`. `remember` wires a domain cell through `Cell.observe`.
- Write pipeline hardening (code review remediation): queued writes re-check
  the dirty flag so identical values cannot inflate revisions; a `load` that
  loses a race to an accepted pulse still adopts the store's revision and
  payload (no more permanent `MemoryConflict` wedge); `remove` drains
  in-flight writes so a late write cannot resurrect a deleted record;
  `unload`/`close` always finish their cleanup even when the final flush
  fails, and every failure lands on `errors` and `lastError`; `save` loops
  until the latest value is persisted. Ingress encodes before committing
  (a non-serialisable pulse is rejected and reported, never half-adopted);
  chained `removed`/`unloaded` pulses are not value updates; pulses whose
  source is this cell are echoes even after `withStep`/`evolve`; async
  validators in `attach` are serialised in arrival order.
- File store hardening: `File.rename` replaces existing records on Windows
  as well as POSIX (verified by test), so the risky delete-then-rename
  fallback is gone; the tmp file is written and flushed through a
  `RandomAccessFile`; a stale lone `.tmp` no longer bricks an id on write
  (reads still fail closed); single-file mode enforces its one record id
  and serialises all access through one chain; ids are lowercased for lock
  chaining and Windows reserved device names are rejected; `list` returns a
  settled snapshot.
- Export surface: `MemoryScheduler`, `ManualScheduler`, `TimerScheduler`,
  `MemoryStoreCas`, `JsonPayloadKey`, the five pulse builders, and
  `CollectiveMemoryPulse` are exported. `FileMemoryStore` moved to
  `package:cell_memory/cell_memory_io.dart`, keeping the core library
  web-safe. `MemoryAttachRejected` was removed (nothing threw it; the
  observer-based attach has no link-return to reject).
- Second review remediation (Grok): a write epoch fenced by
  `remove`/`unload`/`close` — a write queued before them is discarded
  after them, so remove cannot be resurrected and close persists the value
  accepted during its flush and nothing later; `MemoryConflict` recovery
  adopts the stored revision when the store holds this writer's own
  payload (the lost-response shape) and real conflicts stay failed without
  rescheduling; an async attach validation in flight is dropped after
  `detach` (observer token guard); `InMemoryMemoryStore` deep-copies on
  `read` and `write` so callers can never mutate history without a
  revision bump; `AUTHORS` added. Locked by tests: `open(initial:)` on an
  empty store does not persist until a pulse arrives; `null` is the
  durable absence of a value and bypasses `encode`; a schema-1 writer must
  not add optional fields (versioning policy: schema bumps, never
  schema-1 extras). `MemoryNotFound` remains a reserved exception — the
  shipped stores' `remove` is idempotent and never throws it.
- Firebase review remediation: the shared id grammar moved to an exported
  `MemoryIdGrammar` used by both stores; `JsonMemoryCodec<double>.identity`
  decodes an `int` payload as a `double` (the web encodes `1.0` as `1`)
  while `int` cells still reject fractional payloads.
