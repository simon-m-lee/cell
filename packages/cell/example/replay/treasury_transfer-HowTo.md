# How to use Causal Replay — treasury transfer walkthrough

A hands-on guide to the `treasury_transfer_demo.dart` example. Read this
alongside the source; every numbered section below maps to a numbered
`_section()` call in the executable.

---

## What you'll learn

By the end of this walkthrough you will have seen, in a runnable program:

1. **Recording** three treasury transfers into a hash-chained ledger.
2. **Verifying** that the ledger has not been tampered with.
3. **Replaying** the ledger into a fresh graph and asserting that the
   reconstructed state matches the recording exactly.
4. **Forking** the history at a specific sequence to ask "what if
   transfer #2 had been $50,000 instead of $25,000?"
5. **Verifying** the fork against its parent — the fork is only as
   trustworthy as the history it branches from.
6. **Catching** a divergence when the graph's behaviour has changed
   since the recording.

The program exits `0` if every assertion passes and `1` otherwise. It is
safe to run repeatedly; it uses a fresh temporary directory for the
ledger file and cleans up on exit.

---

## Running the demo

From the repository root:

```bash
dart run example/replay/treasury_transfer_demo.dart
```

Expected output (abridged — the demo prints the ledger's file path,
which will differ on every run):

```
╔══════════════════════════════════════════════════════════════╗
║  ACME Treasury — Causal Replay Demo                          ║
╚══════════════════════════════════════════════════════════════╝

Ledger directory: /tmp/treasury_demo_abc123

▸ 1. Build graph and bind ledger
  graph.id       = acme-treasury
  ledger path    = /tmp/treasury_demo_abc123/ledger.jsonl
  genesis hash   = 8a3f...
  source balance = $100000
  target balance = $0
  transfers done = 0

▸ 2. Record three wire transfers
  Wired $25000  (Invoice #2025-11-001)
  Wired $25000  (Invoice #2025-11-002)
  Wired $25000  (Invoice #2025-11-003)

  entries recorded = 9
  source balance   = $25000
  target balance   = $75000
  transfers done   = 3

▸ 3. Verify ledger integrity
  ✓ hash chain intact
  ✓ 9 entries verified from genesis to head

▸ 4. Replay into a fresh graph
  entries replayed = 9
  replayed source  = $25000
  replayed target  = $75000
  replayed count   = 3
  ✓ replay reproduced the recorded state exactly

▸ 5. Fork at seq 2 (after transfer #1)
  what-if: transfer #2 was $50,000 instead of $25,000

  forkId              = 7b1e...
  divergedAt          = 2
  parentHeadHash      = c0a4...
  originalSnapshotHash= 3f8d...

  entries replayed = 6
  forked source    = $0
  forked target    = $100000
  forked count     = 3
  ✓ what-if branch produced (source=0, target=100000, count=3)

▸ 6. Verify the fork
  ✓ parent ledger verified
  ✓ fork chain verified
  ✓ fork genesis bound to parent at seq 2

▸ 7. Divergence detection (receptor change)
  ✓ divergence caught at seq 6
    reason:   delta.after mismatch for cell "source" ...
    expected: 25000
    actual:   50000

  The replay refused to silently produce a state that the
  recorded ledger does not explain.

╔══════════════════════════════════════════════════════════════╗
║  Demo complete — all checks passed                           ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Understanding the demo

### Section 1 — Build graph and bind ledger

The three cells (`source`, `target`, `count`) are created with
`Cell.state<int>(…)`, which returns a `StateHandle<int>`. Each handle
wraps a `ValueCell<int>` whose initial value is passed in.

The graph is built with `CellGraph.builder()`:

```dart
final graph = (CellGraph.builder(graphId: 'acme-treasury')
      ..registerState('source', source)
      ..registerState('target', target)
      ..registerState('count', count))
    .build();
```

`registerState` pairs each `StateHandle` with a stable name. From this
point on, `source.cell.id == 'source'` — a **cross-process-stable**
identity (see the guide's §5.1).

The ledger is bound with `FileLedgerStore.open(...)`. The `genesisHash`
argument is the seed of the ledger's hash chain. It must be stable
across restarts; if it changes, an existing ledger will not verify
against the new chain.

`bindLedger` calls `Ledger.openVerified` internally, which runs
`verify()` before returning. A corrupt file fails at bind time, not on
first append.

### Section 2 — Record three wire transfers

Every state transition happens inside `graph.run(...)`:

```dart
await graph.run(() async {
  source.update(source.cell.value! - 25000);
  target.update(target.cell.value! + 25000);
  count.update(count.cell.value! + 1);
  // …
});
```

`graph.run` pushes a `LedgerScope`. Each `update` inside the scope
captures its `(before, after)` delta and appends a `LedgerEntry`.
Three updates per transfer × three transfers = **9 entries**.

Outside `graph.run`, updates would be silently unrecorded. That is
checklist item 3 in the main guide: *if it changes state, it goes in
`graph.run`.*

### Section 3 — Verify ledger integrity

`ledger.verify()` walks the hash chain from `seq 0` to the head. Every
entry's `hash` must equal `H(prevHash, seq, pulseDigest, receiptDigest,
effectsDigest, deltaDigest, at)`. If any byte has been altered —
including `seq`, `delta.after`, or the receipt — `verify()` throws
`LedgerIntegrityException` naming the offending sequence number.

In the demo there is no tampering, so `verify()` returns normally. The
point of showing it here is that **this is the operation an auditor
runs first**. A ledger that does not verify is not evidence.

### Section 4 — Replay into a fresh graph

`ReplayEngine.replay` takes the ledger and a **fresh target graph** —
a graph with the same shape but no prior history.

```dart
final replayResult = await ReplayEngine.replay(
  ledger: ledger,
  target: replayGraph,
);
```

The engine:

1. Iterates the ledger's entries in `seq` order.
2. For each entry, reconstructs the input pulse from the receipt's
   arguments (or, for `update`-based entries, from `delta.after`).
3. Pushes a `ReplayJournal` with the entry's recorded effects.
4. Dispatches the pulse through the target graph's corresponding cell.
5. Verifies that the resulting state matches `delta.after`.
6. Asserts the journal is fully consumed (no extra or missing effects).

The demo asserts three things: `replayResult.success == true`,
`entriesReplayed == 9`, and each cell's value equals the original
recording's value. If any of these fail, the program exits `1`.

**This is the value proposition in one function call**: a corpus of
recorded mutations becomes a reproducible, verifiable state
transition, without trusting the recording process.

### Section 5 — Fork at seq 2

A fork takes the parent ledger, a sequence number, and a fresh-graph
factory:

```dart
final fork = await graph.fork(
  parent: ledger,
  atSeq: 2,
  buildFreshGraph: () { … },
  store: InMemoryLedgerStore(genesisHash: 'fork-genesis'),
);
```

The fork's baseline is the parent's state after `seq 2` (i.e. after
transfer #1 completes). `fork.record` records the provenance: a UUID,
the parent's `graphId`, the `divergedAt` sequence, the parent's head
hash at that sequence, and the parent's snapshot hash. These are what
`fork.verify()` will check (§6).

The fork's ledger is independent: `seq 0` is the `ForkRecord`, and
subsequent entries are produced by the fork's own replay.

### Section 5 (continued) — Apply the what-if

```dart
final forkResult = await ReplayEngine.replayFork(
  fork: fork,
  mutation: (entry, pulse) {
    switch (entry.seq) {
      case 3: return Pulse<int>(25000, source: pulse.source);
      case 4: return Pulse<int>(75000, source: pulse.source);
      case 6: return Pulse<int>(0,     source: pulse.source);
      case 7: return Pulse<int>(100000, source: pulse.source);
    }
    return pulse;
  },
);
```

The `mutation` callback receives `(entry, pulse)` for every replayed
entry. Returning `null` **drops** the entry; returning a different
pulse **replaces** it; returning the same pulse **passes it through**.

The four cases in this demo are the sequence numbers of the transfer
#2 and #3 balance updates. Each replaces the original `delta.after`
with an alternative one computed from the alternative history:

| Seq | Original | Alternative | Why |
|---|---|---|---|
| 3 | source: 50000 | source: 25000 | transfer #2 debits $50,000 instead of $25,000 |
| 4 | target: 50000 | target: 75000 | transfer #2 credits $50,000 instead of $25,000 |
| 6 | source: 25000 | source: 0 | transfer #3 debits $25,000 from a smaller balance |
| 7 | target: 75000 | target: 100000 | transfer #3 credits $25,000 to a larger balance |

The `count` entries (seq 5 and 8) pass through unchanged: both
histories process three transfers.

After the replay, the fork's graph reflects the alternative
outcome: `source = 0, target = 100000, count = 3`.

**Non-obvious**: the mutation sees the *reconstructed* pulse, whose
`payload` is the recorded `delta.after` (for `update`-based entries).
For an `apply`-based entry, it would be `receipt.arguments.first`. In
both cases the mutation has the full `Pulse` — including `source`,
`timestamp`, and `priority` — so it can modify metadata as well as
payload.

### Section 6 — Verify the fork

```dart
await fork.verify();
```

`fork.verify()` runs three checks:

1. `parent.verify()` — the parent ledger is intact.
2. `fork.ledger.verify()` — the fork's chain is intact, from the
   `ForkRecord` onward.
3. **Genesis binding**: `fork.record.parentHeadHash` matches the
   parent ledger's hash at `divergedAt`.

If any check fails, `ForkIntegrityException` is thrown with the
`forkId` and the reason. A fork without a verified parent is not a
fork — it is a separate ledger pretending to branch.

### Section 7 — Divergence detection

This is the most important section for understanding what replay is
*for*. The demo builds a third graph that looks like the recording
graph but has a subtle difference: `source`'s `TestCell` rejects any
balance below $50,000.

```dart
final strictSource = Cell.state<int>(
  initial: 100000,
  testRule: TestCell<Cell>((object, {host, arguments, user}) {
    return (object as int) >= 50000;
  }),
);
```

During replay:

- `seq 0` (`source` → $75,000): accepted, state = 75,000. ✓
- `seq 3` (`source` → $50,000): accepted, state = 50,000. ✓
- `seq 6` (`source` → $25,000): **rejected** by the test rule.
  State stays at 50,000.

The recorded entry at `seq 6` has `delta.after == 25000`. The replay's
`source.value` after that pulse is `50000`. `ReplayEngine` compares
them and throws:

```
ReplayDivergenceException (seq 6):
  delta.after mismatch for cell "source"
  expected: 25000
  actual:   50000
```

This is the guarantee that makes replay useful: **it refuses to
silently produce a state that the recorded ledger does not explain**.
A log would happily report both the recording and the changed replay
as "successful". A replayable ledger catches the difference.

---

## What the demo does not cover (honest scope)

The demo is deliberately small so it fits in one file. Production
usage would add three things that are not shown here:

### 1. Effect journaling

The demo's cells are pure — no clock, no network, no UUID. A real
treasury service would do a fraud check per transfer, which is an
external I/O. That check would be wrapped:

```dart
final ok = await EffectJournal.current.io(
  label: 'fraudCheck($amount)',
  input: amount,
  run: () => fraudApi.check(amount),
);
```

The journal records the response during recording and serves it during
replay. See the main guide's §6 for the pattern.

### 2. Version stamping

The demo's cells are all at `version: '0.0.0'` (the default). Once the
graph's behaviour is stable, stamp every receptor:

```dart
graph.registerVersion('source');
graph.registerVersion('target');
graph.registerVersion('count');
```

This is what makes the divergence test in §7 meaningful *for a
versioned receptor*: replay against a version-2 receptor with a
version-1 ledger fails **loudly**, and you can register a version-1
translator to bridge the boundary. Without versions, the framework
fails loudly too, but the fix is less obvious.

### 3. Atomic multi-cell transactions

The demo uses `update` calls in sequence. A production transfer would
use `Cell.txApply` to make the debit-and-credit pair atomic: either
both happen, or neither does. `txApply` is not fully replayable today
(see the main guide's §21, "known gaps"), which is why the demo uses
the simpler primitive. If you need atomicity *and* replayability, the
current design requires you to record the whole transaction as a single
`apply` with a compensation blueprint — see the framework's `txApply`
documentation.

---

## Extending the demo

Three exercises, ordered by difficulty, that a developer can use to
explore the framework:

### Exercise 1 — Add a fourth transfer after the fork

After §5's replay, append a new mutation to the fork's ledger:

```dart
await fork.graph.run(() async {
  final source = fork.graph['source']!.cell as ValueCell<int>;
  // source is 0 after the what-if; a 4th transfer would fail, so
  // first simulate a top-up.
  source.update(100000);
});
```

Then verify the fork still passes `fork.verify()`. The fork's chain
now has entries 0..9 (the ForkRecord + 6 replayed + 1 new). What
`seq` does the new entry have?

### Exercise 2 — Introduce a `TestCell` on the target

The demo only puts a `TestCell` on `source`. Add a rule to `target`
that rejects any credit above $150,000, and re-run §4 and §7. Which
section produces the divergence, and at what `seq`? (Hint: the
divergence test in §7 uses a different target that does *not* have
this rule, so §7 still diverges at seq 6 — but the *recording's* target
does have it, so the recording at §2 would need to change.)

### Exercise 3 — Replace the divergence test with a version boundary

Instead of changing the `TestCell`, stamp `source`'s receptor with
`version: '1.0.0'` at recording time, then rebuild the replay graph
with `version: '2.0.0'` and no registry entry. What does the
framework report? What happens if you register a `v1 → v2` translator
that preserves the receptor's behaviour?

These three exercises cover the three most useful extensions:
post-fork appends, test-rule sensitivity, and version dispatch.

---

## Common issues

**The demo prints a divergence at §4 with `expected: 75000, actual:
100000`.** The framework's `_reconstructEmit` uses `delta.before`
instead of `delta.after` as the pulse payload. This is a known issue;
the fix is one line in `lib/replay/engine/reconstruct_pulse.dart`.
Until fixed, `update`-based recording is not replayable end-to-end.

**The demo fails at §5's fork replay with `parent verification
failed`.** The parent ledger was tampered with between §3 and §5. In
the demo that can't happen (nothing writes to the file); in production
it means someone modified `ledger.jsonl` out from under you. Investigate
the file before retrying.

**The demo fails at §7 with `expected divergence but replay
succeeded`.** The `TestCell` added in §7 was not actually attached to
the replay graph. Check that `strictSource` was registered as
`'source'` and that the replay was given `strictGraph` (not
`replayGraph` from §4).

**`Unhandled exception: StateError: CellGraph reachability violation`
at §1.** A cell is registered but its `bind` chain reaches an
unregistered cell. The demo doesn't use `bind`, so this would only
occur if you modified the source. For production code, either register
the upstream cell or use `CellGraph.unrestricted()` in tests only.

---

## See also

- `example/replay/record_and_replay.dart` — the minimal recording +
  replay example.
- `example/replay/whatif_branch.dart` — the minimal fork + mutation
  example.
- `example/replay/audit_ledger.dart` — the auditor's workflow, without
  the framework's own testing helpers.
- `guide/HowTo-Causal-Replay.md` — the in-depth guide, including the
  seven-item pre-flight checklist.
- `test/replay/` — the framework's own test suite, one
  directory per phase.
```