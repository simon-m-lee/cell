# cell_memory

Durable memory cells for the Cell framework.

Memory retains the latest value; the ledger retains causality. The
framework's `Ledger` records *why* a change happened and can replay it.
`cell_memory` records *what the value is right now* so the next process can
restore it. A `MemoryCell` is itself a `Cell` — it loads stored data,
receives pulses through the framework, and emits `MemoryPulse`s downstream.

## Install

```console
dart pub add cell_memory
```

The core library (`package:cell_memory/cell_memory.dart`) is pure Dart and
web-safe. The `dart:io` file store lives in `cell_memory_io.dart`, so a web
build never pulls `dart:io`. Neither library depends on Flutter, `sqflite`,
or Firebase.

## File example

A `Cell.state<int>` whose value survives process restarts through a JSON
file:

```dart
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_memory/cell_memory.dart';
import 'package:cell_memory/cell_memory_io.dart';

Future<void> main() async {
  final store = FileMemoryStore.directory(Directory('memory'));

  // The domain starts at 0; remember's seed pushes the loaded value into
  // it before the observer is installed.
  final counter = Cell.state<int>(initial: 0);
  final memory = await remember<int>(
    counter.cell,
    id: 'counter',
    store: store,
    codec: JsonMemoryCodec<int>.identity(),
    project: (pulse) => pulse.payload as int? ?? 0,
    seed: (loaded) => counter.update(loaded ?? 0),
    policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
  );

  final start = memory.value ?? 0;
  counter.update(start + 1); // accepted pulse -> write-through
  await memory.save();       // settle the scheduled write
  await memory.unload();     // detach, keep memory/counter.json
  await store.close();
}
```

`example/file_counter.dart` is this program; run it twice and the second run
prints the counter restored from the previous process. `load` is public and
works without an upstream cell: open with `loadOnOpen: false` and call
`load()` explicitly to hydrate before wiring the graph.

`remember` is sugar for `open` + `load` + `attach`. `attach` wires the
domain cell through the framework's public observer binding (see
"Verified against" for why a `Cell.state` cannot be linked from directly at
cell 2.1.0), and `detach` / `unload` undo it. `remember`'s `seed` callback
is the supported way to push the loaded value into the domain cell: it
runs after `open` returns and before `attach` installs the observer, so a
domain update inside it is not echoed back into memory. Skipping `seed`
leaves the domain at its own initial value; the next domain pulse
overwrites memory.

## Write modes

| Mode | When a write is scheduled |
|---|---|
| `immediate` | End of the accepted pulse |
| `debounced` | After a 300 ms quiet period (a newer pulse resets the timer). This is **not** the 1 s default used by `cell_flutter_persistence`; the two packages are not confused. |
| `explicit` | Only `save()` and `unload()` |

`revision` advances only when a store write succeeds. While a debounced or
explicit write is pending, `value` is the accepted in-process value and the
store still holds the previous revision. `save()` returns `null` when the
value is unchanged since the last successful write. A failed write leaves
the value in place, sets `lastError`, reports on `errors`, and never rolls
back the domain cell — persistence failure is an effect failure, not a
validation failure.

Concurrency rules (locked by tests):

- `save()` issues **one** write, no loop: it awaits the in-flight chain,
  then writes the value that is current when that write starts. If a newer
  pulse arrived during the `await`, `save()` returns the envelope of the
  value it captured and leaves the public `dirty` flag `true` — a later
  `save()` (or the next policy write) persists the newer value. There is
  no convergence `StateError`.
- `unload()` and `close()` latch ingress **synchronously**, the moment
  they return their future. A pulse that arrives after the call is not a
  value: it is dropped before projection or encoding, silently. The flush
  then waits for the in-flight write and issues at most one more write of
  the latched value; it never reports success while that value is
  unwritten (a leftover dirty cell fails the flush with a `StateError`).
- A write queued behind a newer one re-checks the dirty flag at execution
  time, so identical values cannot inflate revisions.
- `remove` / `unload` / `close` fence the write epoch: a write queued
  before them is discarded after them. `remove` cannot be resurrected by a
  late write; it is not a flush and never latches ingress.
- A `MemoryConflict` that turns out to be this writer's own payload already
  stored (the lost-response shape) is recovered: the stored revision is
  adopted, `lastError` clears, and — only when that row is still the
  current value — a `stored` pulse is emitted. A real conflict stays
  failed: the cell does not reschedule on its own (no hot loop); the
  caller re-reads, re-applies, or retries `save()`.
- `close()` is idempotent, including two calls made before the first turn
  runs; `unload()` after `close()` throws. `close()` releases an owned
  store exactly once, even when the cell was already unloaded or the flush
  threw; `unload()` never closes the store.
- `open(initial:)` on an empty store keeps `initial` in memory and does
  **not** persist it; `save()` returns `null` and the store stays empty
  until a pulse arrives (v1, locked by a test).

## Null and the codec

`null` is the durable *absence* of a value, not a value: `encode` is never
called for `null`, and a codec that maps absence to a sentinel cannot
observe it. Envelopes may carry a `null` payload, and it round-trips
verbatim. `initial` and the first accepted value are encoded the same way
as every later value — through the codec — but see the `open(initial:)`
rule above.

## Replay

Pass `MemoryWritePolicy.replay` (and `loadOnOpen: false`) during Causal
Replay. The package does not detect a replay on its own: cell 2.1.0 exposes
no public replay flag, and this package reads no private framework state.
With the replay policy, no write is ever scheduled — not even by `save` or
`unload` — and the tests use a store that fails if `write` is invoked.
Replay rebuilds state from the ledger; hydrating from memory would mix two
histories.

## Versioning policy

The envelope is strict: unknown keys, unknown schemas, and wrong kinds are
`MemoryCorrupt`, fail-closed, and never delete or repair data on their own.
Schema 1's keys are `schema`, `id`, `kind`, `revision`, `generation`,
`updatedAt`, optional `codec` and `sourceCellId`, and `payload`.
`sourceCellId` is an optional frozen annotation — the cell does not set
it, and it is not a writer id. A missing
or malformed `generation` (32 lowercase hex characters) is `MemoryCorrupt`
— a 0.1.0 document without one does not decode, in either direction. `kind`
is `value` only; the pulse / tissue / snapshot kinds were never published.
A writer must not add an optional field to schema 1 — that breaks every
older reader by design. New fields ship as schema 2 with a migration, not
as schema-1 extras.

`generation` is the life of a record: minted once on the create
(`MemoryEnvelope.mintGeneration()`, 16 bytes from `Random.secure`) and
copied on every later revision. `remove` ends the life; the next create
mints a new one. Every store rejects a write whose generation differs from
the stored row's, closing the revision-number ABA hole: a stale writer
that still carries the previous life's generation can never install a
revision into the recreated history.

## Other backends

`cell_memory_firebase` ships in a separate package (`FirebaseMemoryStore`,
Firestore rules included). The envelope, the codec, and the synapse attach
stay the same; only the `store` argument changes. `cell_memory_sqlite` is
not in this release.

## Verified against

cell 2.1.0 (resolved from the monorepo path `packages/cell`)
cell_tissue 1.2.0 (resolved from the monorepo path `packages/cell_tissue`)
date: 2026-11-23

The probe package is `tool/seams` (`cell_memory_seams`, never published). Its
`pubspec.yaml` pins `cell: 2.1.0` and `cell_tissue: 1.2.0` exactly and resolves
them through `dependency_overrides` to the local `packages/` sources, per the
repository convention. `dart pub deps` reports `cell 2.1.0`,
`cell_tissue 1.2.0`.

The compiler and the probe tests are the record; the published docs were not
used as an authority.

### Phase 0 decision (2026-11-23)

`MemoryCell` is built on **`extends CellBase`**, the framework's own public
extension point, not on `implements Cell`. The `implements Cell` seam is a
compile-time pass but a runtime stop at cell 2.1.0 (private `_nucleus` /
`_stepString`); `CellBase` is public, has a public constructor, receives
synapse delivery, can be a link source when constructed with an explicit
`Synapses` object, can be `bind`-ed, and joins `Cell.transaction` through its
receptor. This decision is the Phase 0 resolution and is not reopened by
Phase 1.

### Seam results

| Seam | Result | Consequence for Phase 1 |
|---|---|---|
| implements Cell | **stop at runtime, resolved by decision** | The declaration compiles with 11 public members, but the framework reads library-private `Cell._nucleus` / `Cell._stepString` on every cell it touches. A foreign implementer cannot provide those members, so every framework interaction throws `NoSuchMethodError`. **Decision:** build on `extends CellBase` instead. |
| extends Cell | illegal | `no_generative_constructors_in_superclass`: `Cell` has only factory constructors. |
| extends CellBase | **pass — the chosen seam** | `CellBase` is public, has a public constructor, and is what the framework's own test fixtures (`RecordingCell`, `UnlinkingCell`) extend. Delivery into a `CellBase` subclass works; a `CellBase` subclass constructed with an explicit `Synapses` object is a working link source; `Cell(bind: subclass)` works; `Cell.transaction` commits staged values into its receptor. |
| Cell members | 11 | Full analyzer list below. The private members are not on it: the analyzer does not demand `_nucleus` or `_stepString` from a foreign implementer — which is exactly the trap. |
| Cell.id | framework-assigned | `Cell.state<int>(initial: 0)` yields `nucleus:<hex>` ids that differ per cell; there is no `id` parameter. The memory id is an explicit `open` argument. Never derive it from `Cell.id`. |
| link delivers | **stop, resolved by decision** | `link` returns `true`, then delivery throws `NoSuchMethodError: Class 'StubCell' has no instance getter '_nucleus'` at `SynapsesBase._broadcast` (`lib/src/internal/synapses.dart:869`). The OpenCell path fails the same way. A `CellBase` subclass receives the same delivery correctly. |
| link from a Cell | only via the cell's own synapses object | `synapses.link(source, downstreamCell: …)` requires the source's synapses instance (`identical` check against the private nucleus). A `Cell.state` exposes no public synapses accessor, so a caller cannot link FROM a `Cell.state` directly. Phase 1's `attach(Cell upstream)` therefore uses the public `Cell.observe(source: upstream, …)` binding (verified: payloads arrive, `stop()` detaches). A caller-constructed `Cell(synapses: shared)` or `OpenCell` can still link into the memory cell's receptor. |
| bind a Cell | framework cells only | `Cell(bind: stub)` constructs but first use throws `NoSuchMethodError` reading `bind._nucleus.testRule` (`lib/src/internal/nucleus.dart:517`). `Cell(bind: CellBaseSubclass)` works. |
| link rejection | returns false | `Synapses.disabled.link` → false. A rejecting `TestCell` on the source → false. Linking the same downstream twice → true then false; one delivery path (length stays 1). The observer-based attach does not use `link` at all. |
| detach | `Synapses.unlink(cell, {required downstreamCell}) → bool` | Verified: after unlink, the next update does not arrive. For observer-based attach, `EgressHandle.stop()` is the detach. |
| apply when | **never, on the transaction path** | `Cell.transaction` does not call `Cell.apply` on participants. Commit applies `ValueCell`s through the public `value` setter and every other cell through private `cell._nucleus.receptor`. For a `CellBase` subclass that path works and delivers the staged value into the receptor (verified: payload 42). Phase 1's transaction support is therefore receptor-based, not `apply`-based. |
| apply semantics | command runner, not value path | A direct `apply` outside a transaction receives `tx == null`. On a `Cell.state`, `apply(command)` runs `command.function` and returns `ApplyAccepted(result)`; the cell **value is unchanged**. `apply` is the forensic command gateway; `update` / synapse delivery is the value path. |
| deputy | pass | A read-only deputy rejects `apply` while the principal still updates. Deputy and principal share one value. A deputy context not based on the principal's context throws `StateError: Causal Integrity Violation: The new DeputyContext must be a direct descendant of the current context`. No-narrowing `deputy()` returns the identical principal. |
| replay flag | none | No public `isReplaying` / `replaying` / `inReplay` on `Cell`, `CellGraph`, or `ReplayEngine`. Callers pass `MemoryWritePolicy.replay`; the package must not sniff a flag. `ReplayEngine.replay({ledger, target, …})` is the entry. |
| Pulse members | 50 | Full analyzer list below: Iterable (30) + Comparable (1) + Pulse's own (19). |
| Pulse payload / source | `P?` / `Cell?` | A narrower `source` override is legal Dart (covariant getter), so `MemoryPulse.source` is typed `MemoryCell<T>?`. A real emitted pulse payload is the retained value itself (runtime type `int` for `Cell.state<int>`), not a wrapper. |
| tissue snapshot | present, non-blocking | `Map<String, dynamic> encodeTissue(Tissue<dynamic>, {bool lenient = false, TestTissue<dynamic, Tissue<dynamic>> lenientFallbackTestRule = TestTissue.readOnly})` and `TissueBase<dynamic, dynamic, dynamic> decodeTissue(Map<String, dynamic> json, {cellResolver, governanceResolver, lenient, lenientFallbackTestRule, onSkipped})`. `decodeTissue` returns a new tissue; it does not fill an existing one. `TissueList` implements `List<E>` (`clear` + `addAll` are public). Not in this release. |

### Stop record — `implements Cell` cannot be the seam at cell 2.1.0

`Cell` declares two library-private instance members on the interface:

```dart
Nucleus get _nucleus;
String get _stepString;
```

Dart lets a foreign library write `final class C implements Cell {}` and only
demands the 11 public members — the private members cannot be referenced,
let alone implemented, outside `package:cell`. Every framework path then
reaches into them:

| Framework path | Private access | Observed on a foreign implementer |
|---|---|---|
| `Synapses.link(host, downstreamCell: stub)` | accepted, returns true | — |
| broadcast into the stub | `c._nucleus.receptor` (`internal/synapses.dart:869`) | `NoSuchMethodError` on first delivery |
| `OpenCell.link(stub)` + `emit` | same broadcast path | `NoSuchMethodError` on first delivery |
| `synapses.link(stub, downstreamCell: …)` | `cell._nucleus.synapses` (`internal/synapses.dart:1267`) | `NoSuchMethodError` before any linking |
| `Cell(bind: stub)` then first use | `bind._nucleus.testRule` (`internal/nucleus.dart:517`) | `NoSuchMethodError` on `validate` / first pulse |
| `Cell.transaction` commit with the stub as participant | `cell._nucleus.receptor` (`operator_transaction.dart:884`) | `NoSuchMethodError`; `Cell.apply` is never called |
| propagation step label | `cell._stepString` (`internal/receptor.dart:838`) | `NoSuchMethodError` |

The decision resolved the stop: the seam package now records the failure
modes as passing tests and asserts the `CellBase` alternatives; `tool/seams`
is green (39 tests, `dart analyze` clean).

### The chosen `CellBase` seam (probed, all pass)

| Framework path | With `extends CellBase` |
|---|---|
| `synapses.link(host, downstreamCell: cellBaseSubclass)` then `call` | delivers; payload retains its runtime type |
| `OpenCell.link(cellBaseSubclass)` then `emit` | delivers |
| `cellBaseSynapses.link(subclass, downstreamCell: listener)` | the subclass is a working link source |
| `Cell(bind: cellBaseSubclass)` then first use | no throw |
| `Cell.transaction` commit with the subclass as participant | delivers the staged value into its receptor |
| `Cell.observe(source: anyCell)` then `state.update` | payloads arrive; `stop()` detaches |

### `Cell` members (11, from the analyzer, cell 2.1.0)

One member per line, in the order `dart analyze` reported them while the
empty implementer was completed:

```text
FutureOr<ApplyOutcome<R>> apply<R>(ApplyCommand command, {ApplyTransactionScope? tx})
FutureOr<Cell> deputy({DeputyContext context = DeputyContext.system, TestCell testRule = TestCell.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled})
ModifiableAsync<Cell> get async
Context get context
String get id
bool get isGoverned
bool get isInvalidated
bool get isTerminal
Iterable<Function> get modifiable
Cell get unmodifiable
TestCell get validate
```

`ApplyCommand` is the record
`({Function function, ApplyArguments arguments, ApplyCompensation? compensation})`
with `ApplyArguments = ({List<Object?>? positionalArguments, Map<Symbol, Object?>? namedArguments})`.

### `Pulse` members (50, from the analyzer, cell 2.1.0)

`abstract interface class Pulse<P> implements Iterable<Pulse>, Comparable<Pulse<P>>`.

Iterable (30):

```text
bool any(bool Function(Pulse) test)
Iterable<R> cast<R>()
bool contains(Object? element)
Pulse elementAt(int index)
bool every(bool Function(Pulse) test)
Iterable<R> expand<R>(Iterable<R> Function(Pulse) toElements)
Pulse get first
Pulse firstWhere(bool Function(Pulse) test, {Pulse Function()? orElse})
R fold<R>(R initialValue, R Function(R, Pulse) combine)
Iterable<Pulse> followedBy(Iterable<Pulse> other)
void forEach(void Function(Pulse) action)
bool get isEmpty
bool get isNotEmpty
Iterator<Pulse> get iterator
String join([String separator = ''])
Pulse get last
Pulse lastWhere(bool Function(Pulse) test, {Pulse Function()? orElse})
int get length
Iterable<R> map<R>(R Function(Pulse) toElement)
Pulse reduce(Pulse Function(Pulse, Pulse) combine)
Pulse get single
Pulse singleWhere(bool Function(Pulse) test, {Pulse Function()? orElse})
Iterable<Pulse> skip(int count)
Iterable<Pulse> skipWhile(bool Function(Pulse) test)
Iterable<Pulse> take(int count)
Iterable<Pulse> takeWhile(bool Function(Pulse) test)
List<Pulse> toList({bool growable = true})
Set<Pulse> toSet()
Iterable<Pulse> where(bool Function(Pulse) test)
Iterable<R> whereType<R>()
```

Comparable (1):

```text
int compareTo(Pulse other)
```

Pulse's own (19):

```text
P? get payload
dynamic scrutinize(covariant Receptor receptor, List? positionalArguments, [Map<Symbol, dynamic>? namedArguments])
Pulse evolve({Pulse? pulse, String? step, covariant PulseContext? context})
Pulse<P> withStep(String step)
PulseShell<P, Receptor> get shell
DateTime get timestamp
dynamic get type
int get priority
PulseEphemeralPolicy? get policy
PulseContext get context
Cell? get source
List<String> get trace
Pulse<P> get root
bool get isComposite
bool get isInvalidated
bool get isGoverned
Pulse operator +(covariant Pulse other)
Pulse<P> get unmodifiable
List<T> lineage<T>(LineageArgument arg)
```

The raw probe output (SEAM|… transcript and the NoSuchMethodError record) moved to [doc/seams.md](doc/seams.md).

## Non-goals

- No replacement for `Ledger`, `ReplayEngine`, `FileLedgerStore`, or
  `cell-replay`. Memory stores the latest retained value; the ledger stores
  the causal chain.
- No replacement for `cell_flutter_persistence`. That package stays the
  SharedPreferences / restoration adapter for Flutter widgets.
- No second mutation path. Writes enter through a pulse the domain cell
  already accepted; the memory cell never calls `update` on the domain cell
  except when loading.
- No persistence during Causal Replay (`MemoryWritePolicy.replay` performs
  zero writes).
- No Flutter, `sqflite`, or Firebase dependency in the core package.
- No ORM, no query planner, no sync-conflict CRDTs in v1. A concurrent
  write is a `MemoryConflict`, and the store leaves the winner unchanged.

## Platform notes

`File.rename` replaces an existing record on Windows as well as POSIX
(pinned by a test); there is no delete-then-rename window. The tmp file is
written with `writeFrom` and flushed through a `RandomAccessFile` before
the rename — the bytes reach the OS before the rename is attempted, but v1
does not fsync the parent directory, so the strongest power-loss guarantee
is not claimed. A failed write leaves `<id>.json.tmp` for the next open
to delete, and the last good record is never deleted on a failed rename. A
stale lone `.tmp` still fails reads closed (`MemoryCorrupt`) — a partial
file is never promoted — but no longer bricks the id: the next `write`
discards it, because no record was ever committed and the write would
overwrite the tmp anyway. A corrupt `.json` file is left in place and
`read` throws `MemoryCorrupt` — the caller can inspect the bad file.

Directory reads fail closed on an envelope whose `id` does not match the
filename (the file stays in place, including a sibling `.tmp`).
Case-distinct names that collapse on a case-insensitive filesystem are
refused with `MemoryCorrupt` on read, write, and `list` — neither file
is deleted. `list` throws rather than skipping a bad id: one bad name
fails the whole call, and nothing is deleted. (`*.json.tmp` is not an id
and stays ignored.)

The per-id lock is in-process. Two isolates or two processes sharing a
directory can both pass the read-compare-rename, and the last rename wins.
v1 therefore guarantees revision-linearised writes for one writer process
per id; cross-process writers to one id should use the Firestore backend,
where the transaction is the lock.

Single-file mode (`FileMemoryStore.file`) holds exactly one record:
`write` requires the envelope id to match the stored record's id, and
`read(id)` returns the record only for its own id (any other id reads as
absent). All access is serialised through one chain. Ids are lowercased
for lock chaining so `Cart` and `cart` cannot race each other on
case-insensitive filesystems, and Windows reserved device names (`CON`,
`NUL`, `COM1`, …) are rejected before any IO.

## Consequences for Phase 1 (from Phase 0)

- `MemoryCell<T>` extends `CellBase`; it is a `Cell` at every call site and
  the object passed to `synapses.link` / `Cell.observe` / `Cell.transaction`.
- Egress: the cell's `synapses` object is public;
  `memory.synapses.link(memory, downstreamCell: listener)` works (probed).
- Ingress from a `Cell.state`: `Cell.observe(source: upstream, …)` is the
  public seam; `attach` uses it, `detach` calls `stop()`. No `.cell` getter,
  no wrapper. Removed/unloaded pulses from a chained memory cell are not
  value updates, and any pulse whose `source` is this cell (even an evolved
  one) is treated as an echo.
- Transaction participation is receptor-based (the framework never calls
  `Cell.apply`); `MemoryCell.apply` remains the CellBase command gateway and
  is documented as such.
- `MemoryPulse` narrows `source`, `withStep`, `evolve`, and `unmodifiable`.
  `operator +` stays inherited from `Pulse`: at cell 2.1.0 a cross-library
  interface cannot narrow `+` while also implementing `CollectivePulse` —
  the two inherited `+` signatures form an unsatisfiable diamond, so
  `memoryPulse1 + memoryPulse2` yields a framework `CollectivePulse`.
- A tissue helper (`package:cell_memory/tissue.dart`) — the snapshot shape
  is recorded; core must not depend on `cell_tissue`.
- Reading any private replay state. No public replay flag exists; callers
  pass `MemoryWritePolicy.replay`.
