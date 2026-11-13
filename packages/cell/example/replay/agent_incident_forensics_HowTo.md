# How to use Causal Replay — AI refund agent forensics

A hands-on walkthrough of `agent_incident_forensics_demo.dart`. Every
numbered section below matches a `_section()` call in the executable.

---

## What this demo shows

A customer-support refund agent processes five requests. Request #3 is
an **incident**: the LLM hallucinated a $10,000 refund for a $100 order,
and the agent issued it. The demo:

1. **Records** all five requests into a hash-chained ledger.
2. **Verifies** the ledger's integrity.
3. **Replays** the ledger to reconstruct exactly what happened —
   including the LLM's hallucinated output, served from the effect
   journal rather than re-queried from the model.
4. **Forks** the history at seq 5 (after request #2, before the
   incident) and applies a **what-if fix**: cap the LLM's output at the
   order's actual value. The fork produces a divergent history showing
   what a fixed deployment would have done.
5. **Verifies** the fork against its parent.
6. Produces a **compliance summary** suitable for the postmortem.

The value of the demo is not the LLM. It's the workflow: *when an
agent's action is suspect, the ledger is the evidence, and the fork is
the proposed fix*.

---

## Running it

```bash
dart run example/replay/agent_incident_forensics_demo.dart
```

Expected output (abridged):

```
╔══════════════════════════════════════════════════════════════════╗
║  ACME Support — AI Refund Agent Forensics                        ║
╚══════════════════════════════════════════════════════════════════╝

▸ 1. Build agent graph and bind an in-memory ledger
  graph.id       = acme-refund-agent
  genesis hash   = 8a3f...
  initial agent  = $0 (last issued refund)
  initial status = idle
  initial total  = $0

▸ 2. Record five refund requests
  req 1 (CUST-100): decision=$100  total=$100
  req 2 (CUST-200): decision=$50   total=$150
  req 3 (CUST-300): decision=$10000 total=$10150
  req 4 (CUST-400): decision=$200  total=$10350
  req 5 (CUST-500): decision=$75   total=$10425

  entries recorded = 15 (3 per request × 5 requests)
  final agent      = $75
  final status     = processed
  final total      = $10425

▸ 3. Verify the ledger hash chain
  ✓ hash chain intact
  ✓ 15 entries verified from genesis to head

▸ 4. Replay the ledger into a fresh graph
  entries replayed = 15
  replayed agent   = $75
  replayed status  = processed
  replayed total   = $10425
  ✓ replay reproduced the recorded state exactly
  ✓ the LLM's $10,000 hallucination is now provable

▸ 5. Fork at seq 5 (after request #2) with a fix
  what-if: cap the LLM's output at the order's actual value

  forkId        = 7b1e...
  divergedAt    = 5
  parentHead    = c0a4...

  entries replayed = 9
  forked agent     = $75
  forked status    = processed
  forked total     = $525
  ✓ what-if branch produced total $525 (vs $10425 recorded)
  ✓ the fix would have prevented $9,900 of overpayment

▸ 6. Verify the fork binds to its parent
  ✓ parent ledger verified
  ✓ fork ledger chain verified
  ✓ fork genesis bound to parent at seq 5

▸ 7. Compliance summary for the postmortem
  Incident: refund for $10,000 against a $100 order.
  Cause:    LLM hallucination (confidence reported as 0.95).
  Evidence: Ledger entry seq 6, receipt.arguments[0] == 10000.
  Impact:   Overpayment of $9,900 (recorded total vs fixed total).
  Fix:      Cap LLM output at the order's amount.
  Proof:    Fork ledger demonstrates the fixed history.

╔══════════════════════════════════════════════════════════════════╗
║  Demo complete — all checks passed                               ║
╚══════════════════════════════════════════════════════════════════╝
```

Exit code `0` on success, `1` on any failed assertion. The demo uses
`InMemoryLedgerStore` throughout — no files are created, and the demo
can be run repeatedly with identical results.

---

## Understanding the demo

### Section 1 — Build the agent graph

Three cells participate in the workflow:

| Cell | Type | Purpose |
|---|---|---|
| `agent` | `_AgentCell extends ValueCell<int>` | The last refund amount issued. `issueRefund` is whitelisted so calls go through the integrity gate. |
| `status` | `Cell.state<String>` | The processing status — `'idle'` or `'processed'`. |
| `total` | `Cell.state<int>` | The cumulative amount refunded. |

`_AgentCell` is a **custom subclass** because the demo needs an `apply`
call whose `function` is whitelisted. A plain `ValueCell`'s `modifiable`
manifest is `{apply}`, so a named `issueRefund` method must be added
explicitly. Once it's in `modifiable`, `apply` routes through
`validate.action(...)` and produces a proper `ApplyReceipt` — which is
what the ledger stores.

The graph is bound to an in-memory ledger. Real systems use
`FileLedgerStore` with a stable genesis hash, but the demo avoids file
I/O so the run is reproducible.

### Section 2 — Record five requests

Each request produces three ledger entries (agent, status, total),
recorded in **three separate `JournalScope.run` blocks**:

```dart
await JournalScope.run(RecordingJournal(), () async {
  final decision = await EffectJournal.current.io<_LLMDecision>(
    label: 'llmDecide(request=${req.id})',
    input: req.id,
    run: () async => _simulatedLLM(req),
    serializeOutput: (d) => d.toJson(),
  );
  await agent.apply<int>((...));
});
```

**Why one `JournalScope` per apply, not one per request?**

`Ledger.appendInternal` captures effects from the *ambient* journal.
If all three applies share one journal, each entry would record *all*
effects since the request began — the `total.apply` entry would claim
to have consumed the LLM effect, which is false. A fresh `JournalScope`
per apply ensures each entry's effect list is exactly what that pulse
consumed.

This is a real workflow constraint, not a demo quirk. In production:

- **Effectful work** (LLM call, CRM lookup, email send) happens
  *before* the mutation, inside a `JournalScope`.
- **Pure mutations** (status, total) get their own `JournalScope` so
  they capture no effects.

The demo's structure mirrors what an integration test would write:
one scope per logical operation.

The **incident** happens inside `_simulatedLLM`:

```dart
_LLMDecision _simulatedLLM(_Request request) {
  if (request.id == 3) {
    return const _LLMDecision(10000, 0.95);
  }
  return _LLMDecision(request.orderAmount, 0.92);
}
```

Request #3 reports 0.95 confidence while returning 100× the correct
amount. This is the shape of the incident: the model is confident and
wrong. The demo does not try to prevent the hallucination — it records
it faithfully so it can be investigated.

### Section 3 — Verify the ledger

`ledger.verify()` walks the hash chain. Every entry's `hash` must equal
`H(prevHash, seq, pulseDigest, receiptDigest, effectsDigest,
deltaDigest, at)`. A tampered byte throws `LedgerIntegrityException`
naming the offending `seq`.

In the demo nothing is tampered with, so `verify()` returns normally.
The point of running it here is that **this is the operation an auditor
runs first**. A ledger that doesn't verify is not evidence.

### Section 4 — Replay to reconstruct the incident

`ReplayEngine.replay` re-dispatches each recorded pulse into a fresh
graph. The `ReplayJournal` for each entry serves the LLM's recorded
output as the effect's return value — **the model is not called again**.

The demo asserts:
- `replayResult.success == true`
- The replayed values match the recorded values

After the replay, the incident is *provable*: the ledger contains an
entry at seq 6 whose `receipt.arguments[0] == 10000`, and the replay
demonstrates that this input produced `agent.value == 10000` in the
live system. There is no ambiguity about what happened.

This is the difference between a log and a ledger. A log says "the
agent issued a refund of 10000". A replayable ledger says "the agent
issued a refund of 10000, and here is the exact input that caused it,
and here is a full re-execution proving the same result".

### Section 5 — Fork and apply the fix

The fork starts at **seq 5** — after request #2, before request #3.
The `buildFreshGraph` factory creates fresh cells pre-populated with
the baseline state at seq 5:

| Cell | Baseline value |
|---|---|
| `agent` | 50 (last issued refund, from request #2) |
| `status` | `'processed'` |
| `total` | 150 (from requests #1 + #2) |

These are hardcoded because the demo knows the exact history. In a
real forensic workflow, the baseline is computed by replaying the
parent ledger to `atSeq` — see the guide's "Extensions" section for
how.

The mutation closure handles three cases:

```dart
mutation: (entry, pulse) {
  final cellId = entry.receipt.cell.id;
  switch (cellId) {
    case 'agent':
      var amount = (pulse.payload as int?) ?? 0;
      if (entry.seq == 6) amount = 100;   // the fix
      currentAmount = amount;
      return Pulse<int>(amount);

    case 'total':
      runningTotal += currentAmount;
      return Pulse<int>(runningTotal);

    case 'status':
      return pulse;   // pass through
  }
  return pulse;
},
```

**The fix is one line:** `if (entry.seq == 6) amount = 100;`. Request
#3's LLM output is capped at the order's actual value. Every subsequent
entry is *recomputed* from the alternative history:

| Seq | Original | Fork | Why |
|---|---|---|---|
| 6 | agent=10000 | agent=100 | The fix |
| 8 | total=10150 | total=250 | Baseline 150 + fixed 100 |
| 11 | total=10350 | total=450 | Baseline 250 + req #4's 200 |
| 14 | total=10425 | total=525 | Baseline 450 + req #5's 75 |

The `runningTotal` closure variable tracks the fork's "should-be" total,
starting from the baseline of 150 and accumulating each request's
amount. This is how a developer investigating an incident actually
reasons: they know the baseline, they compute the alternative, they
check the fork matches.

The fork produces `forkedTotal.value == 525`. The original recording
produced `10425`. The difference is `9900` — the amount the fix would
have saved.

**Why `atSeq: 5` and not `atSeq: 6`?**

`atSeq: 5` means "the fork's baseline is the state *after* seq 5". The
fork replays from seq 6 onward. This is the correct semantics: "fork at
seq 5" means "from the state the system was in at seq 5, what happens
next?" The incident happens at seq 6, and the fix is applied there.

`atSeq: 6` would mean the fork already includes the incident — which
defeats the purpose.

### Section 6 — Verify the fork

`fork.verify()` runs three checks:

1. **Parent verification:** `await parent.verify()`. A tampered parent
   fails the fork.
2. **Fork chain verification:** `await fork.ledger.verify()`. The
   fork's own hash chain must be intact.
3. **Genesis binding:** `fork.record.parentHeadHash` must match the
   parent ledger's hash at `divergedAt`. A fork whose
   `parentHeadHash` doesn't match the parent's actual hash is either
   stale or forged.

If any check fails, `ForkIntegrityException` is thrown. In the demo,
all three pass.

**Why this matters for compliance:** an auditor who receives the fork
ledger does not need to trust the operator's self-report that "we fixed
it". They verify:

1. The parent ledger is intact.
2. The fork is a legitimate branch of the parent at the claimed
   sequence.
3. The fork's own history is intact.

Only after all three are confirmed is the fork evidence.

### Section 7 — Compliance summary

The final section turns the ledger and fork into a postmortem. Three
claims are made, and each is backed by a specific artefact:

| Claim | Backed by |
|---|---|
| "Refund was $10,000 against a $100 order" | Ledger entry seq 6, `receipt.arguments[0] == 10000` |
| "LLM hallucinated the amount" | The `IoEffect` in seq 6's entry, served by the replay to reproduce the incident |
| "Cap would have saved $9,900" | The fork's `total.value == 525` vs the recording's `10425` |

None of these claims require trusting the operator. Each one can be
verified independently by an auditor with the ledger files and the
replay engine.

---

## What the demo does not cover

### 1. Effectful `TestCell` verdicts on the `apply` path

The demo's cells have no `TestCell`. A production refund agent would
likely have one — for example, a rule that rejects refunds above a
threshold unless a manager approves. In the current framework, the
`apply` path's `TestActionRule` is not journalled (Phase 7 covers the
*pulse* path only). If you need replayable `apply` verdicts, record a
new ledger at the current receptor version.

The demo avoids `TestCell` on the `apply` path for this reason.

### 2. Snapshot reconstruction at the fork point

The demo hardcodes the baseline state at seq 5 (`agent=50`,
`status='processed'`, `total=150`). In a real workflow, you'd compute
this by replaying the parent ledger to `atSeq`:

```dart
CellGraphRegistry.forceReset();
final baseline = CellGraph.builder(...).build();
await ReplayEngine.replay(
  ledger: parent,
  target: baseline,
  options: const ReplayOptions(maxEntries: 6),  // seq 0..5
);
final baselineAgent = (baseline['agent']!.cell as ValueCell<int>).value!;
final baselineStatus = (baseline['status']!.cell as ValueCell<String>).value!;
final baselineTotal = (baseline['total']!.cell as ValueCell<int>).value!;
```

Then use those values in `buildFreshGraph`. This is the correct general
pattern. The demo skips it for brevity.

### 3. Durable storage

The demo uses `InMemoryLedgerStore`. A production system would use
`FileLedgerStore` with a stable genesis hash, so the ledger survives
process restarts. For the audit scenario, the ledger file is the
artefact that gets handed to the compliance team.

### 4. Multi-step transactions

The demo issues refund, updates status, and updates total as three
separate applies. A production system would wrap them in a
`Cell.txApply` transaction so that a failure in any step rolls back
the others. `txApply` is not fully replayable in the current build
(see the framework's `txApply` documentation), so the demo uses the
simpler pattern.

If atomicity is required for a replayable system, record the entire
transaction as a single `apply` whose function performs all three
writes and whose compensation reverses them all. That's the pattern
the framework's `txApply` saga is designed to produce, and it will
become directly replayable in a future phase.

---

## Extensions

Three exercises for a developer who wants to explore further.

### Exercise 1 — Add a sixth request after the fork

The fork replays seq 6 onward. What happens if you add a sixth request
to the fork's ledger? The new entry goes at seq 6+3 (the fork's seq 6
after the baseline, since the fork's own ledger starts at seq 0 with
the ForkRecord).

What does `fork.ledger.lastSeq` become? What does `fork.verify()` say?

### Exercise 2 — Introduce a `TestCell` that would have caught the incident

Add a `TestCell` on `agent` that rejects any amount above $500. Re-run
§2 and observe: the incident doesn't happen (the apply is rejected by
the test rule). But does the ledger record the *rejection*, or the
*attempt*?

This exercise exposes the difference between "the mutation failed" and
"the mutation was never attempted". The demo's current structure
records the attempt (with `ApplyRejected`); a different structure would
record the failure. Both are legitimate; the choice depends on your
audit requirements.

### Exercise 3 — Cross-version replay

The demo's cells are all at `version: '0.0.0'` (the default). Suppose
you want to deploy a fixed version of `_simulatedLLM` that caps at the
order amount, and stamp `_AgentCell` at `version: '2.0.0'`. What
happens when `ReplayEngine.replay` is called against the original
ledger? What if you register `graph.registerVersion('agent')` before
and after the fix?

This exercise exposes the version-boundary handling: the framework
refuses to replay across a version boundary without a translator, and
the failure tells you exactly which versions are incompatible.

---

## Common issues

**`CellGraph reachability violation` at §1.** The demo's cells don't
use `bind`, so this would only occur if you modified the source. For
production code, register upstream cells explicitly.

**`ReplayDivergenceException (seq 0): parentDigest present but no
parent provided`.** The `PulseCodec.fromJson` is refusing to
reconstruct a pulse with a parent. In the current build, replay
handles parent resolution through the ledger's `pulseDigest`; if you
see this exception, the ledger entry may be corrupted.

**`ForkIntegrityException: parent verification failed` at §6.** The
parent ledger was tampered with between §3 and §6. In the demo this
can't happen (the ledger is in-memory). In production, it means
someone modified the ledger file — investigate before retrying.

**`fork produced unexpected total` at §5.** The mutation's
`runningTotal` closure drifted from what the fork actually produced.
The `runningTotal` variable must start at the baseline (150) and
accumulate each request's amount in the order the fork replays them
(seq 6, 8, 11, 14 for this demo). If you reorder or add requests, the
starting value changes.

**`inconsistent replication of `_reconstructEmit`**. The demo uses
`apply`-based mutations throughout. If you switch to `update`-based
mutations (via `.update(...)` on a `StateHandle`), replay may fail
because the current build's `_reconstructEmit` uses `delta.before`
as the pulse payload rather than `delta.after`. Use `apply` for
replayable mutations.

---

## See also

- `example/replay/treasury_transfer_demo.dart` — the same workflow
  applied to a financial transfer domain.
- `example/replay/record_and_replay.dart` — minimal recording and
  replay.
- `example/replay/whatif_branch.dart` — minimal fork and mutation.
- `guide/HowTo-Causal-Replay.md` — the seven-item checklist and
  pre-flight guide.
- `test/replay/phase*/` — the framework's own test suite, one
  directory per phase.
