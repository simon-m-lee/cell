# How to Use Causal Replay

**Causal Replay: the in-depth guide.**

This guide explains what causal replay is, how every piece of the machinery
works, and how to use it correctly. It is the companion to two shorter
documents:

- `guide/HowTo-Replay.md` — the seven-item pre-flight checklist and the
  15-minute path. Read that first if you want to get running.
- `research/Causal-Replay/Plan.md` and `Phase-1.md` … `Phase-8.md` — the
  design plan this implementation was built from.

Everything in this guide is written against the **shipped** API in
`package:cell` at the end of Phase 8 (commit series through `c85a36e0`).
Code samples are the same shapes used by the framework's own test suite
(`test/replay/`) and the executable demos in `example/replay/`.

---

## Table of contents

- [Part I — The mental model](#part-i--the-mental-model)
  - [1. What causal replay is](#1-what-causal-replay-is)
  - [2. What it is not](#2-what-it-is-not)
  - [3. The recording loop](#3-the-recording-loop)
  - [4. The replay loop](#4-the-replay-loop)
  - [5. The eight phases at a glance](#5-the-eight-phases-at-a-glance)
- [Part II — The 15-minute path](#part-ii--the-15-minute-path)
- [Part III — The machinery, in depth](#part-iii--the-machinery-in-depth)
  - [6. Stable identity: registration and `Cell.id`](#6-stable-identity-registration-and-cellid)
  - [7. Purity: the declaration boundary](#7-purity-the-declaration-boundary)
  - [8. The `EffectJournal`](#8-the-effectjournal)
  - [9. `JournalScope`: the ambient journal](#9-journalscope-the-ambient-journal)
  - [10. The five journalled operators](#10-the-five-journalled-operators)
  - [11. The ledger: hash chain, entries, receipts](#11-the-ledger-hash-chain-entries-receipts)
  - [12. `LedgerScope`: recording coordination](#12-ledgerscope-recording-coordination)
  - [13. `ReplayEngine`: replaying a history](#13-replayengine-replaying-a-history)
  - [14. Divergence reporting](#14-divergence-reporting)
  - [15. Forking: what-if branches](#15-forking-what-if-branches)
  - [16. Governance: versions, registry, translators](#16-governance-versions-registry-translators)
  - [17. Visualisation and the CLI](#17-visualisation-and-the-cli)
  - [18. The conformance suite and the determinism gate](#18-the-conformance-suite-and-the-determinism-gate)
- [Part IV — Recipes](#part-iv--recipes)
  - [R1. Record and replay a state cell](#r1-record-and-replay-a-state-cell)
  - [R2. An effectful mapper](#r2-an-effectful-mapper)
  - [R3. Debounce replay](#r3-debounce-replay)
  - [R4. A custom receptor with purity and version](#r4-a-custom-receptor-with-purity-and-version)
  - [R5. An `effectful` test rule](#r5-an-effectful-test-rule)
  - [R6. A `readOnlyExternal` test rule](#r6-a-readonlyexternal-test-rule)
  - [R7. `EphemeralPolicy` ticks (the C4 fix)](#r7-ephemeralpolicy-ticks-the-c4-fix)
  - [R8. Fork and mutate](#r8-fork-and-mutate)
  - [R9. Verify a fork](#r9-verify-a-fork)
  - [R10. A version boundary with a translator](#r10-a-version-boundary-with-a-translator)
  - [R11. The CLI workflow](#r11-the-cli-workflow)
  - [R12. Reading a divergence report](#r12-reading-a-divergence-report)
- [Part V — Failure modes and their fixes](#part-v--failure-modes-and-their-fixes)
- [Part VI — The invariants, and where they are enforced](#part-vi--the-invariants-and-where-they-are-enforced)
- [Part VII — Scope, deferred work, and migration](#part-vii--scope-deferred-work-and-migration)
- [Glossary](#glossary)

---

# Part I — The mental model

## 1. What causal replay is

**Causal replay** is the ability to take a recorded history of everything
that ever happened to a Cell graph and **re-execute it exactly**, in a
fresh process, against a freshly built copy of the graph, arriving at the
same state — or at a *deliberately different* state, when you are running
a what-if branch.

Three ideas carry the whole design:

1. **Causality over state.** The ledger records *causes* (the pulses that
   entered the graph) and *effects* (the state deltas they produced), in
   causal order. Replay re-injects the causes and checks that the effects
   re-occur.
2. **Purity is declared, not assumed.** Code that depends on the outside
   world (clocks, random numbers, network, timers) must declare itself.
   The framework refuses to replay undeclared effects *loudly* — the
   alternative is a silently wrong reconstruction.
3. **Identity is stable.** Every cell has a registered name that means the
   same thing in the recording process and the replay process. Without
   stable identity, a ledger entry cannot address the cell it happened to.

### The one-sentence contract

> If every effect that is not a function of the pulse goes through an
> `EffectJournal`, and every cell is registered, and the receptor
> implementations are versioned, then replaying a ledger into a fresh
> graph reproduces the recorded state exactly — and any deviation is
> reported with the ledger sequence number, the expected value, the
> actual value, and the reason.

## 2. What it is not

- **Not bit-exact re-execution of arbitrary user code.** User functions
  run again during replay, but their *observations* are served from the
  journal. A receptor that performs I/O without journalling is caught by
  the journal's exhaustion checks — it is not silently re-run.
- **Not a snapshot restore.** You do not restore `state == X`; you
  reconstruct *how X came to be*. This is what makes auditing possible:
  the auditor can replay and then ask "which pulse made this delta?"
- **Not a database migration tool.** Replay across a graph *shape* change
  (a rewired receptor, a renamed cell) is a **migration**, not a replay.
  The framework refuses; migration is the future Phase 9.
- **Not cross-process without registration.** An unregistered cell's id is
  a process-local hash and cannot be addressed from a ledger file.

## 3. The recording loop

```
                       ┌─────────────────────────────────────────┐
 pulse ──▶ receptor ──▶ test rule ──▶ policy ticks ──▶ state delta │
             │              │              │                 │     │
             │              │              │                 │     │
             └── JournalScope ──┴── LedgerScope ──┴── Ledger.appendInternal
                    (effects)      (deltas + effects)        │
                                                              ▼
                                                    hash-chained entry
                                                    (pulse, receipt, effects,
                                                     deltas, timestamps)
```

During recording:

1. A mutation enters the graph inside `graph.run(...)`, which pushes a
   `LedgerScope`.
2. The receptor validates the pulse through its `TestCell` rule, ticks any
   hosted `EphemeralPolicy`, and commits the state through
   `ValueCell.postProcessRule`.
3. Every *effect* (clock, UUID, I/O, timer, rule verdict, policy tick) is
   written to the ambient `RecordingJournal`.
4. Every *delta* (before value, after value, cell id) is captured by the
   `LedgerScope`.
5. `Ledger.appendInternal` hashes the pulse digest, the receipt digest, the
   effects digest and the delta digest into one chain entry. Each entry's
   `prevHash` is the previous entry's hash, so tampering with any byte
   breaks every entry after it.

## 4. The replay loop

```
 ledger entry (seq N) ──▶ _checkVersions ──▶ reconstruct pulse ──▶ dispatch
                              │                                        │
                              │                                        ▼
                              │                              fresh graph's receptor
                              │                                  (pure rules re-run,
                              │                                   effectful rules are
                              │                                   served their recorded
                              │                                   verdicts)
                              │                                        │
                              └──▶ ReplayJournal (peek/commit) ◀────────┘
                                        │
                                        ▼
                              assertExhausted + delta comparison
                                        │
                                        ▼
                              success, or DivergenceReport(seq N)
```

During replay, per ledger entry:

1. **Version check** — the recorded receptor/rule versions must match the
   target graph's live versions or an entry in the graph's
   `VersionRegistry`. Otherwise: loud divergence.
2. **Pulse reconstruction** — the input pulse is rebuilt from the entry's
   arguments (first positional argument becomes the payload) or, failing
   that, from the delta's `after` value.
3. **Dispatch** — the pulse is re-injected into the target graph with a
   fresh `ReplayJournal` in scope. Pure rules re-run. `effectful` rules
   consume their recorded `VerdictEffect` and are **not** re-called.
   `readOnlyExternal` rules re-run with their observations served from the
   journal.
4. **Exhaustion** — the journal must be fully consumed; any unused record,
   any mismatched kind, label or input is a divergence.
5. **Delta verification** — after dispatch, every recorded delta's `after`
   value is compared with the target cell's current value.

## 5. The eight phases at a glance

| Phase | Deliverable | Why it matters |
|---|---|---|
| 1 | Canonical JSON, `fingerprint`, `PulseCodec`, `CellGraphSnapshot` (schema v2) | Byte-stable serialisation; everything the chain hashes is canonical |
| 2 | `Cell.id` (principal-chain walk), `CellGraph`/builder/registry, `Purity` | Stable identity across processes; strict reachability |
| 3 | `EffectJournal` (clock/uuid/io/timer), Recording/Replay/Null journals, `JournalScope`, `Effectful`/`EffectfulReadOnly`, the five journalled operators | Every external observation becomes a replayable record |
| 4 | `StateDelta`, `HashChain`, `LedgerEntry`, `LedgerStore` (InMemory/File), `Ledger.appendInternal`, `LedgerScope` | The tamper-evident history and recording coordination |
| 5 | `ReplayEngine.replay`, `ReplayOptions`, `DivergenceReport`, `ReplayResult`, `PulseReconstructor`, `ReplayDivergenceException` | The replay loop and its diagnostics |
| 6 | `ForkRecord`, `ForkPolicy.isolated`, `ForkHandle`, `ForkLedgerStore`, `CellGraphFork.fork`, `ReplayEngineFork.replayFork`, `ForkVerify` | What-if branches bound to the parent's hash at the fork point |
| 7 | `VerdictEffect`/`PolicyTickEffect`, `DeputyContext.version`, `VersionRegistry`, `ContextTranslator`, `TestCellReplay`, `PolicyReplay`, engine `_checkVersions` | Governance replay: versions, purity dispatch, policy-tick ordering (C4) |
| 8 | `cell-replay` CLI, `CellGraphVisualise`/`LedgerVisualise`, `HowTo-Replay.md`, ledger-store conformance suite, determinism gate, three demos | Tooling that turns a ledger into evidence |

---

# Part II — The 15-minute path

The complete, annotated minimal program. (Identical in spirit to
`guide/HowTo-Replay.md`; the full checklist lives there.)

```dart
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell/replay.dart';

Future<void> main() async {
  final dir = await Directory.systemTemp.createTemp('replay_quickstart');

  // ── 1. Build a graph. Registration gives stable ids. ─────────────
  final counter = Cell.state<int>(initial: 0);
  final graph = (CellGraph.builder(graphId: 'quickstart')
        ..registerState('counter', counter))
      .build();

  // ── 2. Bind a ledger. The store's genesis must match the graph. ──
  final path = '${dir.path}/ledger.jsonl';
  final ledger = await graph.bindLedger(
    store: await FileLedgerStore.open(
      path,
      genesisHash: Ledger.genesisHashOf(graph.id),
    ),
  );

  // ── 3. Mutate inside graph.run. ──────────────────────────────────
  await graph.run(() async {
    counter.update(1);
    counter.update(2);
    counter.update(3);
  });

  // ── 4. Verify the chain. ─────────────────────────────────────────
  await ledger.verify();
  print('Recorded ${await ledger.lastSeq + 1} entries.');
  await ledger.close();

  // ── 5. Replay into a fresh graph. ────────────────────────────────
  // The live registry must be cleared before rebuilding the same
  // names (test/demo context; see Part III §6).
  CellGraphRegistry.forceReset();
  final freshCounter = Cell.state<int>(initial: 0);
  final freshGraph = (CellGraph.builder(graphId: 'quickstart')
        ..registerState('counter', freshCounter))
      .build();

  final reopened = await Ledger.open(
    graph: graph,
    store: await FileLedgerStore.open(
      path,
      genesisHash: Ledger.genesisHashOf(graph.id),
    ),
    genesisHash: Ledger.genesisHashOf(graph.id),
  );
  final result = await ReplayEngine.replay(
    ledger: reopened,
    target: freshGraph,
  );

  print('success=${result.success} '
      'entries=${result.entriesReplayed} '
      'value=${freshCounter.cell.value}');
  assert(result.success);
  assert(freshCounter.cell.value == 3); // Cell.state replaces on update

  await reopened.close();
  await dir.delete(recursive: true);
}
```

Three details that matter even in this minimal example:

- **`Cell.state` replaces, it does not accumulate.** `update(1); update(2);
  update(3)` leaves the value at `3`. If you need accumulation, write a
  custom rule or a custom receptor that does the arithmetic.
- **The genesis hash is derived, not invented.** A store whose genesis
  does not match `Ledger.genesisHashOf(graph.id)` is rejected at
  `bindLedger`/`Ledger.open` (Phase 6 enforcement). The examples in early
  drafts of the phase docs passed arbitrary strings; that no longer works.
- **`ReplayEngine.replay` refuses a ledgered target.** The target graph
  must be a *fresh* graph (no ledger bound); replay reconstructs state,
  it does not merge histories.

---

# Part III — The machinery, in depth

## 6. Stable identity: registration and `Cell.id`

### Why identity is hard

Two cells that "look the same" are only the same cell if the framework
says so. A cell created in process A and its counterpart created in
process B are different objects — replay is only meaningful if the ledger
can address them by a name that is stable across both processes.

### The principal chain

`Cell.id` is resolved by walking the cell's **principal chain**: a deputy
cell inherits the identity of its principal (the cell it was cloned or
delegated from), unless it has been registered under its own name. The
walk is not free — in debug VM futures it has been measured at ~0.5 ms
per call through dynamic record access — so the hot ledger path resolves
the id *once* at the caller's call site and threads the string through
(see `LedgerScope.recordPulse`'s comment in the source).

### Registration

```dart
final counter = Cell.state<int>(initial: 0);
final graph = (CellGraph.builder(graphId: 'g1')
      ..registerState('counter', counter))
    .build();
```

- `registerState(name, handle)` registers a `StateHandle`'s cell under
  `name`; `register(name, cell)` registers any cell.
- The builder is **strict by default**: every reachable cell (roots and
  everything reachable through `bind`/`Synapses`) must be registered, or
  `build()` throws. `CellGraph.builder(strict: false)` exists for tests
  and for the CLI's placeholder graphs; it is documented as unsafe for
  production.
- `CellGraphRegistry.forceReset()` clears the live identity registry. It
  is `@visibleForTesting` — application code should build each graph in
  its own process, or keep one graph alive. Rebuilding the *same names*
  in one process without resetting makes the new cells resolve their ids
  to the *old* cells.

### What registration buys you

- The ledger can say "cell `counter` changed from 1 to 2" and the replay
  process can find "counter" again.
- `graph['counter']` resolves a `RegisteredCell` (`.cell`, `.name`).
- `CellGraphSnapshot` (Phase 1) can serialise the registered shape; its
  `currentSchemaVersion` is **2** as of Phase 7. `fromJson` accepts
  versions `<= current`, so pre-Phase-7 snapshots still parse.

## 7. Purity: the declaration boundary

`Purity` has three values:

| Value | Meaning | Replay behaviour |
|---|---|---|
| `pure` | Output is a function of input and cell state only | Re-run exactly; no journal needed |
| `readOnlyExternal` | Reads the outside world, never mutates it | Re-run; every read served from the journal |
| `effectful` | Mutates the outside world | **Not re-called**; the recorded decision (`VerdictEffect`) is served |

Two mixins attach behaviour to a custom `ReceptorBase` or `TestCell`:

- `Effectful` — sets `purity` to `effectful`. On the recording side the
  rule runs once; its decision is journaled. With no journal in scope,
  `NullJournal` throws on the first effect — **by design** (an effectful
  receptor outside a journal scope is a bug to surface, not hide).
- `EffectfulReadOnly` — sets `purity` to `readOnlyExternal`. The rule
  re-runs during replay; its `journal.io(...)` / `journal.clock()` calls
  are consumed from the replay journal in order.

The default for every built-in rule and receptor is `pure`, and that is
the correct answer for most custom code. The test question is: *"does my
output depend on anything other than the input and the cell's state?"*

## 8. The `EffectJournal`

The journal is the single interface through which every external
observation must flow:

```dart
abstract class EffectJournal {
  static EffectJournal get current => JournalScope.current;
  int get consumed;
  DateTime clock();                    // Phase 3
  String uuid();                       // Phase 3
  Future<T> io<T>({...});              // Phase 3
  Future<void> timer({...});           // Phase 3
  Future<bool> verdict({...});         // Phase 7
  void policyTick({...});              // Phase 7
  void push(); void pop();             // journal-scope bookkeeping
  void assertExhausted();              // replay-side completeness
  List<Map<String, Object?>> toJson(); // canonical effect log
}
```

The recorded effect kinds (all round-trip through canonical JSON via
`EffectRecord.fromJson`):

| Kind | Record | Carries |
|---|---|---|
| `clock` | `ClockEffect` | `epochMillis` |
| `uuid` | `UuidEffect` | `uuid` |
| `io` | `IoEffect` | `label`, `inputDigest`, `rawOutput` |
| `stream` | `StreamEffect` | stream bookkeeping |
| `timer` | `TimerEffect` | `scheduled`, `scheduledAtMillis`, `firedAtMillis` |
| `verdict` | `VerdictEffect` | `verdict` (bool), `ruleLabel`, `inputDigest` |
| `policyTick` | `PolicyTickEffect` | `policyLabel`, `cellId`, `inputDigest` |

### The three implementations

- **`RecordingJournal`** executes and records. Its constructor accepts
  `clockSource`, `uuidSource`, and `timerScheduler` for deterministic
  tests. Helpers: `consumed`, `recordsSince(n)`, `lastRecord`, `toJson`.
- **`ReplayJournal`** serves and validates. It is constructed from a
  list of records (`ReplayJournal(entry.effects)`).
- **`NullJournal.instance`** is the "no journal in scope" sentinel. It
  throws a loud `StateError` on *every* effectful operation. It is
  deliberately not a silent no-op.

### Peek-then-commit

The replay journal never consumes a record until every field has
validated. The cursor advances only in `_commit()`. A validation failure
calls `_fail(...)`, which:

1. latches `diverged` and `divergenceReason` on the journal, then
2. throws `ReplayDivergenceException`.

The latch is what makes swallowed exceptions visible: an operator's
mapper error contract may swallow the throw, but `assertExhausted()` at
the end of the entry's replay re-throws the latched divergence.

```text
_peek(kind)            → kind mismatch?         → _fail, throw
_validate(fields)      → label/input mismatch?  → _fail, throw
_commit()              → cursor++
assertExhausted()      → diverged?  → rethrow the latched reason
                       → remaining > 0? → "journal not exhausted"
                       → ok
```

### Verdicts and policy ticks (Phase 7)

`journal.verdict(...)` wraps an `effectful` test rule:

- Recording: `run` executes once; the returned `bool` is recorded with
  the rule label and the input digest.
- Replay: `run` is ignored; the recorded verdict is served after the
  label and the input digest are validated.

`journal.policyTick(...)` journals one tick of a cell's hosted
`EphemeralPolicy`:

- Recording: the record is written; the policy callback still runs.
- Replay: the record is consumed and validated (`policyLabel`, `cellId`,
  `inputDigest` — the input is the pulse's *payload*, because a pulse
  object itself is not stable across record and replay); the policy
  callback is **not** re-invoked. The existing `CycleChecker.tickPolicy`
  guard still applies the tick on both sides, which is the Phase 7 C4
  fix: tick *order* is now part of the recorded history.

## 9. `JournalScope`: the ambient journal

`JournalScope` keeps a Zone-local stack of journals:

```dart
await JournalScope.run(recording, () => graph.run(() async { ... }));
//   pushes on entry, pops on exit (success or error)

JournalScope.current          // top of stack, or NullJournal.instance
EffectJournal.current         // the same thing
JournalScope.runSync(journal, body)
```

Design details worth knowing:

- The scope does **not** inherit into spawned tasks. A `Future` scheduled
  before the scope exits keeps the zone, but a task spawned in a *new*
  zone gets `NullJournal` — which fails loudly. This is deliberate: an
  un-journalled effect in a detached task is exactly the bug the plan
  wants surfaced.
- The ambient journal participates in ledger capture (see §12): the
  immediate append path sweeps `recordsSince(watermark)`, and the
  deferred window path relies on operators cooperatively calling
  `LedgerScope.captureEffect`.
- `JournalScope.effectiveJournal(captured)` prefers the ambient journal
  when it is not `NullJournal` — the operator-passed `journal:` argument
  is the fallback, so a replay scope always wins over a captured
  recording journal.

## 10. The five journalled operators

`Cell.asyncMap`, `Cell.fromStream`, `Cell.fromFuture`, `Cell.debounce`,
and `Cell.throttle` all take a **required** `journal:` parameter. Omitting
it is a compile error. The mapper contract for `asyncMap` is:

```dart
final mapped = Cell.asyncMap<int, int>(
  source.cell,
  (v, {required EffectJournal journal}) => journal.io(
    label: 'fetch($v)',
    input: v,
    run: () async => v * 2,        // the actual external call
  ),
  journal: journal,                // the operator's own RecordingJournal
);
```

Rules that make these replayable:

- Every observation is routed through the mapper's `journal` parameter —
  not through a captured global.
- On replay the mapper **runs again**, but `journal.io(...)` returns the
  recorded `rawOutput` and never executes `run`. This is why replay
  never touches the network.
- The operator cooperatively captures each mapper-invocation effect into
  the active `LedgerScope` (`recordsSince(before)` → `captureEffect`), so
  the entry that caused the emission carries its effects.
- `fromStream`'s host is governed with a lifecycle policy; each event
  journals one I/O record **and one policy tick** (the Phase 7 C4
  addition — existing tests updated accordingly).
- `debounce`/`throttle` timers go through `journal.timer(...)`; on replay
  the fire callbacks run in journal order without waiting for real time.

## 11. The ledger: hash chain, entries, receipts

### Genesis

Every chain starts from `Ledger.genesisHashOf(graph.id)` — the
fingerprint of `{'graphId': graph.id}`. Stores enforce their genesis:
`Ledger.open` and `bindLedger` throw if the store's genesis does not
match the chain's. `Ledger.open` accepts an explicit `genesisHash`
override for reopening a ledger whose graph is a placeholder (the CLI
does exactly this).

### What the chain hashes

For each entry:

```text
hash = nextHash(
  prevHash,        // previous entry's hash (genesis for seq 0)
  seq,
  pulseDigest,     // fingerprint(canonical(pulse materialisation))
  receiptDigest,   // fingerprint(canonical receipt JSON)
  effectsDigest,   // fingerprint(effects.toJson())
  deltaDigest,     // fingerprint(deltas.toJson())
  at,              // wall-clock time
)
```

`Ledger.verify()` recomputes every hash in one pass and compares
`prevHash` chains; any mismatch throws `LedgerIntegrityException(seq,
reason)`.

### `LedgerEntry`

| Field | Meaning |
|---|---|
| `seq`, `prevHash`, `hash` | chain position |
| `pulseDigest` | the materialised input pulse |
| `receipt` | who did what (12 fields, see below) |
| `effects` | the entry's `EffectRecord` list |
| `deltas` | `StateDelta` list (`cellId`, `before`, `after`, `at`) |
| `at` | wall-clock time (forensic; never compared by replay) |
| `receiptCellId` | the recorded cell id (Phase 5 fix: the cell *name* in the receipt, not the live object's current id) |
| `receiptDigest` / `effectsDigest` / `deltaDigest` | the digested sub-JSONs |

### The receipt (12 fields)

```dart
({
  String id,                    // apply id
  Cell cell,                    // target cell
  Function function,            // the command's function
  ApplyArguments arguments,     // positional/named
  DateTime timestamp,
  int? txSequence,
  bool vetted,
  int? ledgerSeq,               // back-filled by appendInternal
  String? pulseDigest,          // back-filled by appendInternal
  String? receptorVersion,      // Phase 7: '0.0.0' when unversioned
  String? ruleVersion,          // Phase 7
  String? contextVersion,       // Phase 7
})
```

The three Phase 7 version fields are populated by
`Ledger.appendInternal` from the live nucleus and the cell's
`DeputyContext`; `LedgerEntry.fromJson` defaults pre-Phase-7 ledgers to
`'0.0.0'` (unversioned).

### Stores

`LedgerStore` is the minimal persistence interface: `genesisHash`,
`append`, `lastSeq`, `lastHash`, `entriesSince(fromSeq)`, `close`.
Shipped implementations:

- `InMemoryLedgerStore(genesisHash: ...)` — tests and what-if demos.
- `FileLedgerStore.open(path, genesisHash: ...)` — JSONL file, each line
  one canonical entry; holds a `RandomAccessFile` until `close()`.
- `ForkLedgerStore(record:, inner:)` — wraps any store with a synthetic
  seq-0 `ForkRecord` entry (a *real* chain entry hashed with
  `HashChain.nextHash`); `materialize()` writes the synthetic entry into
  the inner store even before the first real append (the CLI's `fork`
  needs a non-empty output file).

Downstream stores must pass `test/replay/ledger_store_conformance.dart`
(§18).

## 12. `LedgerScope`: recording coordination

`graph.run(body)` pushes a `LedgerScope` zone; every mutation inside is
recorded, mutations outside are not (and are the caller's
responsibility).

The scope has three capture channels:

1. **Deltas.** `ValueCell.postProcessRule` encodes the before/after
   values *before* committing (a non-JSON-encodable payload never reaches
   the state box) and calls `LedgerScope.captureDelta`.
2. **Immediate effects.** The synchronous mutation path
   (`ValueCell.update`, `Cell.apply`) calls `LedgerScope.recordPulse`,
   which sweeps the ambient `RecordingJournal`'s records since a
   per-scope **watermark** into the entry. The watermark (a Phase 7
   fix) is load-bearing: without it, a burst of applies attributes every
   earlier pulse's records to each later entry.
3. **Deferred windows.** The ingress/emit path calls
   `LedgerScope.recordPulseDeferred`, which opens a window closed one
   event-loop turn later so detached operator continuations (asyncMap
   mappers, debounce fires) can cooperatively `LedgerScope.captureEffect`
   their records into the pending entry.

`LedgerScope.drain()` resolves when every window and the append chain
(`_tail`) have settled; `LedgerScope.run` drains in its `finally`.

## 13. `ReplayEngine`: replaying a history

```dart
final result = await ReplayEngine.replay(
  ledger: ledger,        // the recorded ledger
  target: freshGraph,    // a fresh, un-ledgered graph
  fromSeq: 0,            // start position
  options: ReplayOptions.strict,  // or .diff for diagnostics
);
```

Per entry, in order:

1. **Refuse a ledgered target** — replay reconstructs state; a bound
   target would mean merging two histories.
2. **Resolve the cell** by `receiptCellId`; unregistered → divergence.
3. **Version check** (`_checkVersions`): the recorded
   `receptorVersion`/`ruleVersion` must be satisfied by the graph's
   `VersionRegistry`, or by the live implementations matching exactly.
   Unversioned ledgers (`null` versions) replay only against unversioned
   targets — refusing to guess is the design.
4. **Reconstruct the pulse** (`PulseReconstructor`): the first positional
   receipt argument becomes the payload (`Pulse<dynamic>(args.first,
   source: cell)`); if there are no arguments, the entry's own delta's
   `after` is used. Hand-crafted entries without either diverge.
5. **Dispatch** inside `JournalScope.run(ReplayJournal(entry.effects))`;
   `settleAfterDispatch` (default true) drains the microtask queue so
   asynchronous receptor continuations finish before the checks.
6. **`assertExhausted`** — the receptor must have consumed exactly the
   recorded effects, in order, with matching labels and inputs.
7. **Delta verification** — for every recorded delta, the target cell's
   current value must equal `delta.after` (compared as canonical JSON).

`ReplayResult` carries `success`, `entriesReplayed`, and
`divergences` (a list of `DivergenceReport`).

### `ReplayOptions`

| Option | Default | Meaning |
|---|---|---|
| `failOnDivergence` | `true` | Throw on the first divergence (`strict`); `false` collects and continues (`diff`) |
| `verifyReceipts` | `true` | Verify back-filled `ledgerSeq`/`pulseDigest`; disable only for hand-built entries |
| `settleAfterDispatch` | `true` | Settle the microtask queue before journal/delta checks |
| `maxEntries` | `null` | Replay only a prefix |

`ReplayOptions.strict` is the production default; `ReplayOptions.diff`
is the diagnostic preset used by CLI-style tools.

## 14. Divergence reporting

Three layers of diagnostics:

1. `ReplayDivergenceException` — thrown synchronously by the journal or
   the engine (when `failOnDivergence`); carries `message`, `ordinal`,
   `seq`, and `report`.
2. `DivergenceReport` — `seq`, `expected`, `actual`, `lastEffect`
   (the effect consumed immediately before the divergence), `reason`.
3. `ReplayResult.divergences` — the full list when running in `diff`
   mode.

A good report reads like a mini-post-mortem:

```
DivergenceReport(seq: 2, expected: version 1.0.0 / 1.0.0,
  actual: version 2.0.0 / 2.0.0,
  reason: version boundary: the ledger recorded receptor version 1.0.0 …
```

## 15. Forking: what-if branches

A fork is a *new* ledger whose chain genesis is the fingerprint of a
`ForkRecord`, and whose history is bound to the parent's hash at the
fork point.

```dart
final fork = await graph.fork(
  parent: ledger,
  atSeq: 5,                      // parent sequence
  buildFreshGraph: () {          // fresh cells, same names
    CellGraphRegistry.forceReset();
    final fresh = Cell.state<int>(initial: 0);
    return (CellGraph.builder(graphId: 'g')
          ..registerState('counter', fresh))
        .build();
  },
  buildStore: (genesis) =>       // store factory, not a store
      InMemoryLedgerStore(genesisHash: genesis),
  policy: ForkPolicy.isolated,   // the only Phase 6 policy
);
```

Key semantics:

- **`ForkRecord`** = `forkId`, `originalLedgerId`, `divergedAt`,
  `originalSnapshotHash`, `parentHeadHash`, `at`. `genesisHash` is the
  fingerprint of everything except `at` — the fork chain is
  distinguishable from the parent's.
- **Baseline replay.** The fork does not copy state; it replays parent
  entries `0..atSeq` into the fresh graph, so the fork's working state is
  the parent's state *after* seq `atSeq`.
- **`divergedAt + 1`.** `ReplayEngineFork.replayFork(fork:, mutation:)`
  replays from the parent's `divergedAt + 1` onward. `atSeq == 0` means
  the baseline is the state after the parent's first entry.
- **Mutation.** `typedef Mutation = Pulse? Function(LedgerEntry entry,
  Pulse pulse);` — return a replacement `Pulse` to substitute, return
  `null` to *drop* the entry (the fork's ledger then has no record of
  it), return the same pulse to keep it.
- **The fork writes its own ledger.** Each replayed entry is appended to
  `fork.ledger`; deltas are *not* compared against the parent's because a
  fork is expected to diverge — the fork's ledger records what the fork
  actually did.
- **Only `ForkPolicy.isolated` ships.** `sharedTopology` and
  `dropUnreached` require Phase 5.1 snapshot reconstruction and throw
  `UnimplementedError`.

### Verifying a fork

`fork.verify()` (the `ForkVerify` extension on `ForkHandle`) checks, in
order: the **parent** chain, the **fork** chain, and the **genesis
binding** — `ForkRecord.parentHeadHash` must equal the parent's hash at
`divergedAt` (`ForkParentLookup.hashAtSeq`). A fork whose binding does
not match is stale or forged: `ForkIntegrityException`.

## 16. Governance: versions, registry, translators

### Where versions live

- `Receptor.version` and `TestCell.version` default to `'0.0.0'`
  (unversioned); custom implementations may override.
- `DeputyContext.version` defaults to `'1.0.0'`; `DeputyContext.system`
  is `'0.0.0'`. `Mandate.version` is a *static pillar* — it cannot be
  evolved by a deputy, because it declares the schema of the mandate
  itself.
- Every entry's receipt records the three versions that produced it.

### `VersionRegistry` — graph-scoped, on purpose

```dart
graph.versions.register(
  cellId: 'admin',
  version: '1.0.0',
  receptor: myV1Receptor,
  testRule: myV1Rule,           // both must report version '1.0.0'
);
graph.registerVersion('admin'); // registers the live pair at its own version
```

The registry is per-graph via an `Expando` (`CellGraphVersions.versions`)
— deliberately not process-wide: two graphs in one process may have the
same cell name with different version histories, and a process-wide table
would let one graph's versions shadow the other's. Registering the same
`(cellId, version)` twice with a different implementation throws;
identical re-registration is a no-op.

### The engine's decision

For each entry: if the graph's registry has the recorded version, replay
proceeds. Otherwise the live receptor and rule must match exactly.
Otherwise — a loud `DivergenceReport` with the recorded and live
versions. An unversioned ledger replays only against an unversioned
target.

### `ContextTranslator`

A context schema change is the caller's semantic domain; the framework
provides the boundary:

```dart
class V1ToV2 implements ContextTranslator {
  @override
  String get fromVersion => '1.0.0';
  @override
  String get toVersion => '2.0.0';
  @override
  FutureOr<DeputyContext> translate(DeputyContext source) =>
      DeputyContext(
        baseContext: Context.system,
        authority: 'UPDATE',
        version: '2.0.0',
        // …translate the v1 fields…
      );
}

graph.translators.register(V1ToV2());      // CellGraphTranslators
await graph.translators.translate(v1ctx, target: '2.0.0');
```

`ContextTranslatorRegistry.translate` returns the source unchanged when
the versions are equal, throws `UnimplementedError` when no translator
exists (the loud failure the exit criteria require), and verifies the
translator's output version. Phase 7 registers the machinery and enforces
the boundary; wiring translators *into* the engine dispatch loop is the
deferred Phase 7.1 item.

### Purity dispatch (`TestCellReplay`)

The receptor pipeline no longer calls the rule directly. It calls
`TestCellReplay.invoke(rule:, object:, host:, journal:, ruleLabel:)`:

- `pure` → `rule.call(...)` — synchronous rules stay synchronous (the
  framework's pulse contract depends on it).
- `readOnlyExternal` → `rule.call(...)` with the journal in scope, then
  a cooperative sweep hands records the rule wrote to the `LedgerScope`
  (the Phase 3 `asyncMap` pattern).
- `effectful` → `journal.verdict(...)`; the rule runs once on the
  recording side and never on the replay side.

The rule label is conventionally `${rule.runtimeType}@${rule.version}`
and is validated by the replay journal, so a changed rule diverges by
label even before the version check runs.

## 17. Visualisation and the CLI

### In-library visualisation

```dart
final graphMermaid = graph.visualise();          // CellGraphVisualise
final ledgerMermaid =
    await ledger.visualise(format: 'mermaid', mode: 'deltas');
final ledgerDot = await ledger.visualise(format: 'dot', mode: 'cells');
```

`mode: 'deltas'` is the forensic view (what changed, in order); `mode:
'cells'` is the topology view (who participated). The delta renderer
tracks the previous delta node instead of assuming every entry has one —
the fork's synthetic seq-0 entry, and hand-crafted entries, have none.

### The `cell-replay` CLI

```text
cell-replay verify    --ledger <path> [--format human|json]
cell-replay diff      --ledgerA <path> --ledgerB <path> [--format human|json] [--maxDiffs N]
cell-replay fork      --ledger <path> --at <seq> --out <path> [--format human|json]
cell-replay visualise --ledger <path> [--mode deltas|cells] [--format mermaid|dot]
cell-replay inspect   --ledger <path> [--format human|json]
```

Exit codes: `0` success · `1` verification failure / diff found ·
`2` usage error · `3` internal error. `dart run bin/cell_replay.dart
--help` prints the usage text.

Two Phase 8 scope decisions worth internalising:

- **`verify` checks the chain only.** `--graph` is rejected (Phase 8.1
  needs Phase 5.1 snapshot reconstruction). The chain guarantee is real:
  it proves no byte of history was altered after recording.
- **The genesis compromise.** A ledger file does not carry its genesis;
  the CLI reads the first entry's `prevHash` and trusts it. A ledger
  whose *first* entry was tampered would pass genesis binding — this is
  documented in the help text and fixed by the Phase 8.1 `--genesis`
  flag.
- **`fork` writes the `ForkRecord` genesis**, no entries after it.
  `--replaceSeq` (fork-with-replay) is Phase 8.1.

`inspect` prints the human summary (`entries`, `deltas`, `cells`,
`span`) or canonical JSON; `visualise` output pastes directly into
GitHub/Notion markdown.

## 18. The conformance suite and the determinism gate

### Ledger-store conformance

`test/replay/ledger_store_conformance.dart` is the acceptance criterion
for any downstream store (Postgres, S3, …):

```dart
runLedgerStoreConformance(
  'MyStore',
  () => MyStore(genesisHash: 'test-genesis'),
  isDurable: true,                    // survives reopen
  fresh: () { /* allocate a NEW resource per test */ },
);
```

It exercises append/`lastSeq`, out-of-order rejection, genesis binding,
`entriesSince` ordering, close semantics, and (durable only) reopen. The
`fresh` hook matters: the suite opens the factory once per test — a
durable store must reopen the *same* data within a test but a *fresh*
resource across tests.

### The determinism gate

```bash
dart run tool/replay_determinism_check.dart
```

Runs `test/replay` twice, normalises the JSON reporter on
`(test name, result, message)`, and fails when the two runs disagree. A
test whose output varies across runs is either non-deterministic by
design (mark it `@Skip` with a comment) or is doing real `DateTime.now()`
/ `Random()` work that would make the *ledger itself* non-reproducible.

### The three demos

```bash
dart run example/replay/record_and_replay.dart   # file ledger, reopen, replay
dart run example/replay/whatif_branch.dart       # fork + replace a pulse
dart run example/replay/audit_ledger.dart        # the auditor's workflow
```

---

# Part IV — Recipes

## R1. Record and replay a state cell

See Part II. The essential beats: register, bind with
`Ledger.genesisHashOf`, mutate inside `graph.run`, verify, rebuild
fresh, `ReplayEngine.replay`.

## R2. An effectful mapper

```dart
final source = Cell.state<int>(initial: 0);
final graph = (CellGraph.builder(graphId: 'r2')
      ..registerState('src', source))
    .build();

final journal = RecordingJournal();      // lives as long as the operator
final mapped = Cell.asyncMap<int, int>(
  source.cell,
  (v, {required EffectJournal journal}) => journal.io(
    label: 'double($v)',
    input: v,
    run: () async => v * 2,
  ),
  journal: journal,
);

final ledger = await graph.bindLedger(
  store: InMemoryLedgerStore(
    genesisHash: Ledger.genesisHashOf(graph.id),
  ),
);
// Effects are records: the recording runs inside a journal scope.
await JournalScope.run(journal, () => graph.run(() async {
  source.update(1);
  source.update(2);
}));
```

Replay into a fresh graph built the same way; the mapper re-runs but
`run` never executes — `rawOutput` is served. If the replay mapper were
changed, the entry's I/O record would diverge on `label` or `inputDigest`.

## R3. Debounce replay

```dart
final source = Cell.state<int>(initial: 0);
final debounced = Cell.debounce(
  source.cell,
  const Duration(milliseconds: 50),
  journal: RecordingJournal(),
);
// …bind, run, emit bursts…
```

On replay, `ReplayJournal.timer` validates the scheduled duration and
input, then fires `onFire` in journal order after one microtask — the
same ordering trick that lets a superseded debounce be cancelled before
its fire callback runs. No real timers are waited on.

## R4. A custom receptor with purity and version

```dart
class DoublingReceptor extends ReceptorBase<Cell> {
  @override
  String get version => '1.0.0';

  @override
  Receptor<Cell> get clone => DoublingReceptor();

  // Override call/validation to transform the pulse; the base class
  // handles the governance gates. Keep it pure: the transform is a
  // function of the pulse.
}

final cell = Cell.governed(receptor: DoublingReceptor());
```

Rules: declare `purity` (default `pure` is fine here), stamp a `version`
if the implementation may ever change, and register the graph
(`graph.registerVersion('c')` registers the live pair). The ledger then
records `receptorVersion: '1.0.0'` per entry; replay against a `2.0.0`
build fails loudly until the graph's `VersionRegistry` has the recorded
version.

## R5. An `effectful` test rule

```dart
class SendNotificationRule extends TestCell<Cell> with Effectful {
  @override
  String get version => '1.0.0';
  SendNotificationRule() : super((pulse, {host, arguments, user}) {
    // The rule runs exactly once, on the recording side only.
    return pulse.payload != null;
  });
}

final src = Cell.ingress<int>(testRule: SendNotificationRule());
final graph = (CellGraph.builder(graphId: 'r5')
      ..register('src', src.cell))
    .build();
final ledger = await graph.bindLedger(
  store: InMemoryLedgerStore(
    genesisHash: Ledger.genesisHashOf(graph.id),
  ),
);
final recording = RecordingJournal();
await JournalScope.run(recording, () => graph.run(() async {
  src.emit(1);
}));
final entry = await ledger.entriesSince(0).first;
print(entry.effects.single.runtimeType);   // VerdictEffect
```

On replay, `TestCellReplay.invoke` routes through `journal.verdict`: the
recorded decision is served, the rule body never runs. Changing the rule
body without changing its version diverges on the verdict input or the
rule label.

## R6. A `readOnlyExternal` test rule

```dart
class FeatureFlagRule extends TestCell<Cell> with EffectfulReadOnly {
  @override
  String get version => '1.0.0';
  FeatureFlagRule() : super((pulse, {host, arguments, user}) {
    return EffectJournal.current.io<bool>(
      label: 'flag(${pulse.payload})',
      input: pulse.payload,
      run: () async => true,   // the real read; replay serves it
    );
  });
}
```

The rule re-runs during replay; its read is served from the journal. The
returned value is the recorded `rawOutput`, so the replay decision
matches the recording's — provided the *order* of reads is unchanged.

## R7. `EphemeralPolicy` ticks (the C4 fix)

```dart
var ticks = 0;
final policy = EphemeralPolicy<Cell>(
  eventLimit: 100,
  onEvent: (object, {required cell, required policy, arguments, user}) {
    ticks++;
    return (events: policy.events + 1);
  },
  onInvalidate: (nucleus) => true,
);
final cell = Cell.governed(ephemeralPolicy: policy);
final graph = (CellGraph.builder(graphId: 'r7')
      ..register('c', cell))
    .build();
final ledger = await graph.bindLedger(
  store: InMemoryLedgerStore(
    genesisHash: Ledger.genesisHashOf(graph.id),
  ),
);
final recording = RecordingJournal();
await JournalScope.run(recording, () => graph.run(() async {
  await cell.apply<Pulse<int>>((
    function: (int payload) => Pulse<int>(payload),
    arguments: (
      positionalArguments: [1],      // arguments-first reconstruction
      namedArguments: null,
    ),
    compensation: null,
  ));
}));
final entry = await ledger.entriesSince(0).first;
print(entry.effects.single.runtimeType);   // PolicyTickEffect
```

Replay consumes the tick and validates `(policyLabel, cellId, input)` in
order; the policy callback is **not** re-invoked (so the tick count is
zero on replay — the recorded tick *is* the history). A tick-order
mismatch is a `ReplayDivergenceException` with the offending ordinal.
This is what closes the plan's C4 concern: a diamond graph can no longer
trip the `CycleChecker` spuriously during replay, because the tick order
is journaled.

## R8. Fork and mutate

```dart
// Parent: update(1), update(2), update(3) → value 3.
final fork = await graph.fork(
  parent: ledger,
  atSeq: 1,                        // baseline = state after seq 1 (2)
  buildFreshGraph: () {
    CellGraphRegistry.forceReset();
    final fresh = Cell.state<int>(initial: 0);
    return (CellGraph.builder(graphId: 'r8')
          ..registerState('counter', fresh))
        .build();
  },
  buildStore: (genesis) => InMemoryLedgerStore(genesisHash: genesis),
);

final result = await ReplayEngineFork.replayFork(
  fork: fork,
  mutation: (entry, pulse) {
    if (entry.seq == 2) return Pulse<int>(30, source: pulse.source);
    return pulse;                  // keep the rest; null would drop
  },
);
final forkValue =
    (fork.graph['counter']!.cell as ValueCell<int>).value; // 30
```

Remember: `Cell.state` replaces on update, so the arithmetic above gives
2 (baseline) → 30 (mutated seq 2). The fork's own ledger contains the
fork record plus the entries the fork actually replayed.

## R9. Verify a fork

```dart
await fork.verify();               // ForkVerify: parent + fork + binding
final boundHash = await ledger.hashAtSeq(fork.record.divergedAt);
print(boundHash == fork.record.parentHeadHash);   // true
```

`fork.verify()` throws `ForkIntegrityException` if the parent is
corrupt, the fork chain is corrupt, or the recorded `parentHeadHash`
does not match the parent's hash at `divergedAt`. This is the check that
separates a fork from a fabrication.

## R10. A version boundary with a translator

```dart
// Recording: a DeputyContext at mandate version 1.0.0.
final v1 = DeputyContext(
  baseContext: Context.system,
  authority: 'UPDATE',
  version: '1.0.0',
);
// …cells created under v1, ledger recorded…

// Replay target: the same graph shape, but the live context is v2.
final registry = graph.translators;         // ContextTranslatorRegistry
registry.register(V1ToV2());                // see §16
final v2 = await registry.translate(v1, target: '2.0.0');

// Without the translator, translate() throws UnimplementedError —
// the boundary is loud by design.
```

The engine's version check is about **receptor/rule** versions;
**context** versions ride in the receipt and are the translator's
domain. Keep both stories separate when diagnosing: a `version boundary`
divergence names the receptor and rule versions; a missing
`ContextTranslator` names `"from" -> "to"`.

## R11. The CLI workflow

```bash
# The auditor receives a ledger file, not the operator's state.
dart run bin/cell_replay.dart verify --ledger ledger.jsonl
#   OK: ledger is valid (3 entries).                        exit 0

dart run bin/cell_replay.dart inspect --ledger ledger.jsonl
#   Ledger summary
#     entries:       3 (seq 0 … 2)
#     deltas:        3 across 1 cell(s)
#     cells:         counter
#     span:          1 ms

dart run bin/cell_replay.dart visualise --ledger ledger.jsonl --mode deltas
#   graph LR
#     e0_0["seq 0: counter"]
#     e1_0["seq 1: counter"]
#     e0_0 --> e1_0

dart run bin/cell_replay.dart fork --ledger ledger.jsonl --at 1 --out fork.jsonl
#   Fork created: <uuid> at seq 1, written to fork.jsonl        exit 0

dart run bin/cell_replay.dart diff --ledgerA a.jsonl --ledgerB b.jsonl
#   DIFF: 1 divergence(s):
#     seq 2: hash mismatch (A=… B=…)                             exit 1
```

`verify` is chain-only in Phase 8; the auditor's *replay* comparison is
done in code (recipe R1 / `example/replay/audit_ledger.dart`) until
Phase 8.1 ships `--graph`.

## R12. Reading a divergence report

A `DivergenceReport` is read top-down: `seq` locates the entry, `reason`
names the failure class, `expected`/`actual` are the compared values, and
`lastEffect` shows the last journal record consumed before the failure.

| Reason signature | What actually happened | Where to look |
|---|---|---|
| `version boundary: …` | Recorded receptor/rule versions unsatisfied | `VersionRegistry`, live version overrides |
| `journal not exhausted: …` | Receptor consumed fewer effects than recorded | Rule/receptor changed; check purity dispatch |
| `effect kind mismatch … expected TimerEffect, recorded IoEffect` | Effect order changed | Receptor/operator refactor |
| `I/O label mismatch: expected "fetch(1)", recorded "fetch"` | Label construction changed | Operator mapper |
| `verdict rule label mismatch …` | Rule class/version string changed | TestCell rule |
| `policy tick … mismatch` | Policy tick order/policy/cell/input changed | EphemeralPolicy wiring |
| `pulse could not be reconstructed …` | Entry has no arguments and no deltas | Hand-crafted entries |
| `ledger delta refers to cell "x", which is not registered …` | Target graph shape differs | Registration |
| `cell "x" delta mismatch: expected …, actual …` | State diverged after a successful dispatch | Non-journalled side effect inside the rule |

---

# Part V — Failure modes and their fixes

| Symptom | Cause | Fix |
|---|---|---|
| `EffectJournal: operation "…" was attempted with no journal in scope` | An effectful component ran outside a journal scope | Wrap the mutation: `JournalScope.run(RecordingJournal(), () => graph.run(...))`; or the component is genuinely pure and should declare `Purity.pure` |
| `CellGraphBuilder` reachability violation | A bound/observed cell is not registered | Register every reachable cell, or use `strict: false` in tests only |
| `Ledger.open: store genesis hash … does not match graph …` | Store genesis is not `Ledger.genesisHashOf(graph.id)` | Construct the store with the derived genesis; pass the `genesisHash` override when reopening with a placeholder graph |
| `CellGraph.bindLedger` double bind | Second bind on the same graph | `unbindLedger` first, or one ledger per graph |
| `ReplayDivergenceException (seq N): journal exhausted …` | The replay receptor performed fewer effects | Restore the receptor to the recorded version or register the recorded implementation |
| `… effect kind mismatch …` | Effects happen in a different order | Same as above; check operator composition order |
| `… I/O input mismatch …` | The replay asked a different question than the recording | Check the mapper's `input:` argument — it must be a pure function of the pulse |
| `version boundary without translator` | Live versions differ from the ledger's | `graph.versions.register(...)` or replay at the recorded version |
| `ReplayDivergenceException: pulse could not be reconstructed` | Entry lacks arguments and deltas | Only hand-crafted entries hit this; use `Ledger.appendInternal` |
| Replay succeeds but state differs in your own inspection | You mutated outside `graph.run`, or the rule has an un-journalled side effect | Move mutations into the scope; route side effects through the journal |
| Windows: temp ledger files "in use by another process" | A `FileLedgerStore` was opened and never closed (e.g. a command rejected an argument *after* opening the file) | Close stores in `finally`; validate flags before opening files (fixed for `verify --graph` in Phase 8) |
| Fork `verify()` throws `ForkIntegrityException: fork genesis binding failed` | The parent changed after the fork was taken, or the record was forged | Re-fork from the current parent; audit who produced the record |
| `UnimplementedError: ForkPolicy.sharedTopology …` | Non-isolated fork policy requested | Phase 6 ships isolated only; keep the fresh-graph factory |
| Determinism check fails | A test uses real clocks/randomness without journalling | Give `RecordingJournal` a fixed `clockSource`/`uuidSource`/`timerScheduler`, or mark genuinely non-replayable tests `@Skip` |

---

# Part VI — The invariants, and where they are enforced

| # | Invariant | Enforced at |
|---|---|---|
| 1 | Serialisation is canonical and byte-stable | `canonicalJsonEncode` (Phase 1); `PulseCodec.materialise` before fingerprinting |
| 2 | Identity is registered and stable | `CellGraphBuilder.build` reachability check; `Cell.id` principal walk; `receiptCellId` |
| 3 | Every effect is declared and journaled | `Purity` + `Effectful`/`EffectfulReadOnly`; `NullJournal` loud sentinel; journal exhaustion |
| 4 | The chain is append-only and tamper-evident | `HashChain.nextHash` composition; `Ledger.verify`; store genesis + seq/prevHash checks |
| 5 | Deltas are captured before commit | `ValueCell.postProcessRule` pre-commit encoding; `LedgerScope.captureDelta` |
| 6 | Replay never trusts the live implementation blindly | `_checkVersions` before dispatch; `VersionRegistry` |
| 7 | Effects attribute to the entry that caused them | `recordPulse` watermark (immediate path); deferred windows + cooperative `captureEffect` |
| 8 | A divergence is loud, specific, and latched | `ReplayJournal._fail` latch + `assertExhausted`; `DivergenceReport` seq/expected/actual/reason |
| 9 | A fork is bound to its parent | `ForkRecord.parentHeadHash` + `ForkVerify` genesis binding |
| 10 | Tooling reads ledgers without trusting the runtime | CLI chain verify, diff by seq+hash, canonical JSON output |

---

# Part VII — Scope, deferred work, and migration

### Shipped (Phases 1–8)

Codecs and fingerprints; stable identity and graphs; the full
`EffectJournal` machinery and the five journalled operators; ledgers,
delta capture, hash chains and file persistence; the replay engine with
divergence diagnostics; isolated forks with mutations and fork
verification; governance versions, the version registry, context
translators, purity dispatch and policy-tick journaling; the `cell-replay`
CLI, visualisation, the conformance suite, the determinism gate, the
guide and the three demos.

### Deferred, with the exit that unblocks each

- **Phase 5.1 — snapshot reconstruction.** `CellGraphSnapshot` exists and
  round-trips, but rebuilding a *live* `CellGraph` from a snapshot needs
  per-cell factories. Unblocks `verify --graph` and the non-isolated fork
  policies.
- **Phase 7.1 — translator dispatch and apply-path verdicts.** Wiring
  `ContextTranslator` into the engine's dispatch loop, and journaling
  `TestActionRule` verdicts on the apply path.
- **Phase 8.1 — CLI completion.** `--genesis` (replacing the first-entry
  trust), `verify --graph`, `fork --replaceSeq`/`--replacePayloadJson`,
  `visualise --mode pulses`.
- **Release bookkeeping.** The `cell` package version remains `1.1.0`;
  the Phase 7 doc anticipates a breaking `2.0.0` bump plus a CHANGELOG
  entry when the replay surface is released (decision D6, deferred).
- **Phase 9 — migration.** Replay across graph *shape* changes is a
  migration problem: translating receptors, renaming cells, and
  re-binding identities. The version machinery (Phase 7) is the
  foundation migration will build on.

### The boundary line, one more time

> The caller knows how to rebuild the graph; the framework knows how to
> rebuild the state.

---

# Glossary

| Term | Meaning |
|---|---|
| **Causal replay** | Re-executing a recorded pulse history against a fresh graph and checking the effects re-occur |
| **Canonical JSON** | The deterministic serialisation everything is fingerprinted from |
| **Fingerprint** | SHA-256 over canonical JSON (`fingerprint(...)`) |
| **Graph** | The registered view of a cell topology (`CellGraph`) |
| **Registration** | Assigning a stable, cross-process name to a cell |
| **Purity** | `pure` · `readOnlyExternal` · `effectful` — what a component is allowed to touch |
| **Effect** | Any observation of the outside world: clock, UUID, I/O, timer, rule verdict, policy tick |
| **`EffectJournal`** | The interface all effects flow through; Recording (writes) / Replay (serves) / Null (throws) |
| **`JournalScope`** | The Zone-local stack of journals; `JournalScope.current` |
| **Peek-then-commit** | Replay journals validate a record fully before advancing the cursor |
| **Ledger** | The append-only, hash-chained history (`Ledger`) |
| **Genesis hash** | `Ledger.genesisHashOf(graph.id)` — the chain's starting point; stores enforce it |
| **Entry** | One `LedgerEntry`: pulse + receipt + effects + deltas, hashed together |
| **Delta** | `StateDelta(cellId, before, after, at)` — one state transition |
| **Receipt** | The 12-field record of who applied what, including the Phase 7 versions |
| **`LedgerScope`** | The recording coordinator: deltas, immediate-effect watermark, deferred windows |
| **`graph.run`** | Pushes the `LedgerScope`; mutations inside are recorded |
| **Replay engine** | `ReplayEngine.replay` — per-entry version check, pulse reconstruction, dispatch, journal and delta verification |
| **Divergence** | Any recorded/actual mismatch; reported with `seq`, `expected`, `actual`, `reason` |
| **Fork** | A what-if ledger seeded by a `ForkRecord`, bound to the parent's hash at `divergedAt` |
| **Baseline replay** | Replaying parent entries `0..atSeq` into the fresh fork graph |
| **Mutation** | `Pulse? Function(LedgerEntry, Pulse)` — replace, drop, or keep |
| **ForkVerify** | Parent chain + fork chain + genesis binding (`parentHeadHash` at `divergedAt`) |
| **Version boundary** | Recorded receptor/rule/context versions differing from the live ones |
| **`VersionRegistry`** | Per-graph `(cellId, version) → (receptor, testRule)` table |
| **`ContextTranslator`** | The caller's directional bridge across a mandate schema version |
| **Verdict effect** | The recorded decision of an `effectful` test rule |
| **Policy tick** | One recorded tick of a hosted `EphemeralPolicy` (the C4 fix) |
| **Conformance suite** | `runLedgerStoreConformance` — the acceptance test for any `LedgerStore` |
| **Determinism gate** | `tool/replay_determinism_check.dart` — two runs must agree |
| **CLI** | `cell-replay verify/diff/fork/visualise/inspect`; exit codes 0/1/2/3 |

---

*Generated against the shipped Phase 8 API. If a code sample in this
guide does not compile, trust `dart analyze` over the prose: the
authoritative signatures live in `packages/cell/lib`, and the
authoritative usage patterns live in `packages/cell/test/replay/` and
`packages/cell/example/replay/`.*
