# How to use Causal Replay — clinical monitoring forensics

A hands-on walkthrough of `clinical_monitoring_forensics_demo.dart`.
Every numbered section below matches a `_section()` call in the
executable.

---

## What this demo shows

A bedside monitor reads a patient's heart rate every minute, calls a
clinical risk scorer, and escalates to a "critical" alert when the
score crosses a threshold. On 2025-11-13, a patient deteriorated over
four minutes; the alert that should have fired at reading #7 did not,
and the nurse only noticed at reading #8. The demo walks through the
postmortem:

1. **Records** ten readings into a hash-chained ledger.
2. **Verifies** the ledger's integrity.
3. **Replays** the ledger to reconstruct exactly what happened —
   including the risk scorer's recorded output, served from the effect
   journal, not re-queried from the model.
4. **Forks** the history at seq 18 (after reading #6, before the
   incident) and applies a **what-if threshold**: 90 instead of 95.
   The fork shows reading #7 would have fired under the lower
   threshold — one extra minute of response time.
5. **Verifies** the fork against its parent.
6. Emits a **compliance summary** in the shape a 21 CFR Part 11 /
   EU MDR reviewer would accept.

This is a **different** domain from the treasury and refund-agent
demos, but the workflow is the same. That's the point: causal replay
isn't a financial-tool or an AI-tool; it's a general pattern for
safety-critical and regulated state transitions.

---

## Running it

```bash
dart run example/replay/clinical_monitoring_forensics_demo.dart
```

Expected output (abridged):

```
╔═══════════════════════════════════════════════════════════════════╗
║  ACME Health — Bedside Monitoring Forensics                      ║
╚═══════════════════════════════════════════════════════════════════╝

▸ 1. Build monitoring graph and bind an in-memory ledger
  graph.id         = acme-bedside-monitor
  genesis hash     = 8a3f...
  initial HR       = 0 bpm
  initial alert    = none
  initial fired    = 0

▸ 2. Record ten minute-by-minute readings
  min  1: HR= 70 score= 20 alert=none     fired=0
  min  2: HR= 72 score= 25 alert=none     fired=0
  min  3: HR= 75 score= 30 alert=none     fired=0
  min  4: HR= 80 score= 40 alert=none     fired=0
  min  5: HR= 85 score= 55 alert=none     fired=0
  min  6: HR= 90 score= 70 alert=none     fired=0
  min  7: HR= 95 score= 92 alert=none     fired=0
  min  8: HR=100 score= 96 alert=critical fired=1  ⚠ CRITICAL
  min  9: HR=105 score= 98 alert=critical fired=2
  min 10: HR=110 score=100 alert=critical fired=3

  entries recorded = 26
  final alert      = critical
  final fired      = 3 (readings #8, #9, #10)

▸ 3. Verify the ledger hash chain
  ✓ hash chain intact
  ✓ 26 entries verified from genesis to head

▸ 4. Replay the ledger into a fresh graph
  entries replayed = 26
  replayed HR      = 110 bpm
  replayed alert   = critical
  replayed fired   = 3
  ✓ replay reproduced the recorded state exactly
  ✓ the missed alert at reading #7 is now provable:
    score = 92, threshold = 95, no alert fired.

▸ 5. Fork at seq 18 (after reading #6) with threshold 90
  what-if: the critical threshold had been 90 instead of 95

  forkId        = 7b1e...
  divergedAt    = 18
  parentHead    = c0a4...

  entries replayed = 8
  forked alert     = critical
  forked fired     = 4
  ✓ what-if threshold fired 4 alerts (vs 3 recorded)
  ✓ reading #7 would have escalated under threshold 90 —
    the nurse would have had one extra minute to respond.

▸ 6. Verify the fork and emit the compliance summary
  ✓ parent ledger verified
  ✓ fork ledger chain verified
  ✓ fork genesis bound to parent at seq 18

  ── Postmortem summary ──
  Incident:  Patient deterioration detected at reading #8, not #7.
  Cause:     Risk score 92 at reading #7 was below threshold 95.
  Evidence:  Ledger seq 18 (alertLevel), seq 19 (alertsFired);
             the recorded score 92 is in the entry's IoEffect.
  Impact:    One-minute delay in escalation.
  Fix:       Lower the critical threshold from 95 to 90.
  Proof:     Fork ledger demonstrates reading #7 fires under 90.

╔═══════════════════════════════════════════════════════════════════╗
║  Demo complete — all checks passed                               ║
╚═══════════════════════════════════════════════════════════════════╝
```

Exit code 0 on success, 1 on any failed assertion. Uses
`InMemoryLedgerStore` throughout — no files are created, the demo is
repeatable.

---

## Understanding the demo

### Section 1 — Build the monitoring graph

Three cells participate in the workflow:

| Cell | Type | Purpose |
|---|---|---|
| `heartRate` | `ValueCell<int>` | The latest HR reading |
| `alertLevel` | `ValueCell<String>` | `'none'` or `'critical'` |
| `alertsFired` | `ValueCell<int>` | Cumulative count of critical readings |

All three use the default `apply`-based mutation. The demo deliberately
**avoids `StateHandle.update`**, because the framework's
`_reconstructEmit` has a known issue (it uses `delta.before` instead of
`delta.after` as the reconstructed pulse payload), which would make
`update`-based recording non-replayable. `apply`-based recording uses
`_reconstructApply`, which reads the original arguments — correct.

The graph is bound to an in-memory ledger. Real deployments use
`FileLedgerStore` with a stable genesis hash; a regulatory audit needs
the ledger file, not just the in-memory state.

### Section 2 — Record ten readings

Every reading's processing is wrapped in a **fresh `JournalScope`**:

```dart
await JournalScope.run(RecordingJournal(), () async {
  final result = await EffectJournal.current.io<Map<String, Object?>>(
    label: 'clinicalRisk',
    input: reading.heartRate,
    run: () async => {
      'heartRate': reading.heartRate,
      'score': _simulatedRiskScore(reading.heartRate),
    },
  );
  score = (result['score'] as int?) ?? 0;
});
```

The scope closes **before** any `apply`. The score is what the
recording needs; the alert-level decision is made from the score and
is a pure mutation.

**Why one scope per reading, not one per cell mutation?** If the scope
wrapped all three `apply` calls, each entry's `effects` list would
include the `IoEffect`, and the engine's replay would try to serve the
score effect *three times per reading*, which the `ReplayJournal`'s
strict consumption check would refuse. Each `apply` has its own scope
in the refund-agent demo and should have its own here. This demo
structures it the same way.

The reading table encodes the incident:

| Reading | HR | Score | Alert? |
|---|---|---|---|
| 1–6 | 70–90 | 20–70 | no |
| **7** | **95** | **92** | **no** ← incident |
| 8 | 100 | 96 | yes |
| 9 | 105 | 98 | yes |
| 10 | 110 | 100 | yes |

At reading #7, the score (92) is just below the production threshold
(95), so no alert fires. At reading #8, it crosses, and the alert
fires — but the patient has already been deteriorating for a minute.

`_simulatedRiskScore` is deliberately non-linear: it rises steeply
between HR 90 and 95, which is the clinical concern. A linear mapping
would have produced a score of 78 at HR 95 (below the threshold) but a
score of 84 at HR 100 (also below), and no alert would have fired at
all — which isn't the incident we want to demo.

### Section 3 — Verify the ledger

`ledger.verify()` walks the hash chain. In the demo nothing is
tampered with, so `verify()` returns normally.

The point of running it in the demo: **this is the operation an
auditor runs first.** A regulatory reviewer who receives the ledger
file will run `cell-replay verify --ledger path` before anything else.
If it fails, the ledger is not evidence.

### Section 4 — Replay to reconstruct the incident

`ReplayEngine.replay` re-dispatches each recorded pulse into a fresh
graph. The `ReplayJournal` serves the recorded `IoEffect` (the risk
score) rather than calling the model again.

The replay reconstructs the exact state:
- `replayed HR = 110`, `replayed alert = critical`, `replayed fired = 3`

The incident is now **provable**:

1. The ledger entry at seq 18 (`alertLevel` for reading #7) has
   `receipt.arguments[0] == 'none'`.
2. That same entry's `effects` contains an `IoEffect` with
   `rawOutput['score'] == 92`.
3. The replay re-executed the pulse and arrived at `alertLevel = 'none'`,
   confirming the recording.

None of this requires trusting the operator's self-report. An auditor
with the ledger file and the framework can reproduce the conclusion.

### Section 5 — Fork and apply the what-if

The fork starts at **seq 18** — after reading #6 (whose alertLevel
apply is seq 15, alertsFired doesn't fire, and heartRate is seq 14;
the numbering depends on how many entries each reading produces).
The baseline cells at the fork point:

| Cell | Baseline value |
|---|---|
| `heartRate` | 90 (last HR before the incident) |
| `alertLevel` | `'none'` |
| `alertsFired` | 0 |

The mutation closure:

```dart
var forkAlertsFired = 0;
var lastScore = 0;

mutation: (entry, pulse) {
  final cellId = entry.receipt.cell.id;

  for (final effect in entry.effects) {
    if (effect is IoEffect && effect.label == 'clinicalRisk') {
      final raw = effect.rawOutput;
      if (raw is Map) {
        final s = raw['score'];
        if (s is int) lastScore = s;
      }
    }
  }

  switch (cellId) {
    case 'heartRate':
      return pulse;                       // factual
    case 'alertLevel':
      return Pulse<String>(
        lastScore > forkThreshold ? 'critical' : 'none');
    case 'alertsFired':
      if (lastScore > forkThreshold) forkAlertsFired++;
      return Pulse<int>(forkAlertsFired);
  }
  return pulse;
}
```

Three things are worth noticing:

1. **The score comes from `entry.effects`.** The recording captured the
   model's output as an `IoEffect`; the mutation reads it back rather
   than re-querying the model. The model is not called during the
   what-if.

2. **`heartRate` passes through unchanged.** The HR reading was
   factual at the time; the what-if is about the *threshold*, not about
   what the sensor measured.

3. **`forkAlertsFired` is stateful.** The closure variable tracks the
   fork's count as it replays. Under the lower threshold, reading #7
   fires (count → 1), then #8, #9, #10 fire (count → 4).

The fork's final state:

| Cell | Fork value | Recording value |
|---|---|---|
| `alertLevel` | `'critical'` | `'critical'` |
| `alertsFired` | **4** | 3 |

The comparison is the value of the demo: **one more alert would have
fired under the lower threshold**, and that alert would have come one
minute earlier.

### Section 6 — Verify the fork and emit the compliance summary

`fork.verify()` runs three checks:

1. The parent ledger is intact (`await parent.verify()`).
2. The fork's chain is intact (`await fork.ledger.verify()`).
3. The fork's `ForkRecord.parentHeadHash` matches the parent's actual
   hash at `divergedAt`.

If any check fails, `ForkIntegrityException` is thrown. In the demo,
all three pass.

The compliance summary answers four questions a 21 CFR Part 11
reviewer will ask:

| Question | Where it's answered |
|---|---|
| **What happened?** | The replay reproduces the exact state the live system had. |
| **Why did it happen?** | The ledger entry's `IoEffect` records the score of 92; the entry's `receipt.arguments` records the threshold of 95. |
| **What was the impact?** | The fork shows one extra alert would have fired under threshold 90 — a one-minute escalation delay. |
| **What is the fix?** | Lower the critical threshold from 95 to 90, and the fork ledger proves the effect of that change. |

None of these answers rely on the operator's self-report. Each is
backed by a specific artefact that a reviewer can independently verify.

---

## What the demo does not cover

### 1. Effectful `TestCell` verdicts

The demo's cells have no `TestCell`. A production monitor would likely
have one — for example, a rule that rejects any alert escalation unless
a supervisor has approved the current threshold. `TestCell` verdicts on
the `apply` path are not journalled in the current build (the governance layer
covers the *pulse* path). The demo avoids `TestCell` for this reason.

If your application needs effectful `TestCell` verdicts on `apply`,
record a new ledger at the current receptor version.

### 2. Snapshot reconstruction

The demo hardcodes the baseline at the fork point
(`heartRate=90`, `alertLevel='none'`, `alertsFired=0`). In production
you'd compute it:

```dart
CellGraphRegistry.forceReset();
final baseline = (CellGraph.builder(...)..registerState(...)).build();
await ReplayEngine.replay(
  ledger: ledger,
  target: baseline,
  options: const ReplayOptions(maxEntries: 19),  // seq 0..18
);
final baselineHR = (baseline['heartRate']!.cell as ValueCell<int>).value!;
// etc.
```

This is the correct general pattern. The demo skips it for clarity.

### 3. Durable storage

The demo uses `InMemoryLedgerStore`. Production uses
`FileLedgerStore` with a stable genesis hash so the ledger survives
restarts, process migration, and the compliance team's request for the
file.

### 4. Multi-cell atomic transactions

The demo performs three separate `apply` calls per reading. A
production system might want the HR, alertLevel, and alertsFired to
commit atomically (a failure in the middle would leave the alertLevel
inconsistent with the count). `txApply` provides the saga for this, but
`txApply` is not fully replayable in the current build (see the
framework's `txApply` documentation). The demo uses the simpler
non-atomic pattern.

If atomicity is required for a replayable system, record the entire
per-reading decision as a single `apply` whose function updates all
three cells (via a custom subclass that has a whitelisted
`processReading` method) and whose compensation reverses them all.
That's the pattern the framework's `txApply` saga is designed to
produce.

### 5. Clock and identity metadata

The demo uses the default `RecordingJournal`, whose clock is
`DateTime.now()`. That's fine because the recording's `at` timestamps
are only used for forensics — the replay's delta comparison doesn't
compare them.

For a truly reproducible test (see §18 of the main guide), pass a
fixed clock:

```dart
RecordingJournal(clockSource: () => DateTime(2025, 11, 13, 10, 0))
```

The demo omits this for brevity.

---

## Extensions

Three exercises for a developer who wants to explore further.

### Exercise 1 — Add a sixth reading after the fork

The fork replays readings #7 through #10 (8 entries: 4 readings × 2
applies each, since `heartRate` is unchanged by the fork's alert logic
and is only re-recorded, not re-decided). What happens if you append a
fifth reading to the fork's ledger?

The fork's next entry goes at seq 9 (ForkRecord at 0, then 8 replayed
entries at 1–8). Verify the fork still passes `fork.verify()`.

### Exercise 2 — Change the risk scorer

Suppose the clinical team deploys a v2 risk model whose output at
HR=95 is 96 (not 92). Under the production threshold 95, the alert
would fire at reading #7, not #8.

Re-record with the new model, then replay the *old* ledger (which has
the v1 model's output of 92) against a graph whose receptor declares
`version: '2.0.0'`. What happens?

This exercise exposes the framework's version-boundary handling: the
framework refuses to replay across a version boundary without a
registered translator, because it cannot tell whether the receptor's
behaviour matches.

### Exercise 3 — Per-reading atomicity via `apply`

Rewrite the demo to use a single `apply` per reading. Define a custom
subclass of `ValueCell<Map<String, int>>` with a whitelisted
`processReading` method. The function takes `(int score)`, computes
`alertLevel` and `alertsFired`, and returns a `Pulse<Map<String, int>>`.

The fork mutation then operates on the composite payload rather than
on three separate cells. Does the fork still produce the correct
state? What changes about the mutation closure's state management?

This exercise exposes the trade-off between cell-granular and
composite-payload models: cell-granular makes mutations simpler
(one cell, one value, one decision) but commits are non-atomic;
composite-payload makes commits atomic but requires the mutation to
recompute more state.

---

## Common issues

**`ReplayDivergenceException` at §4 with `expected: 3, actual: 0`.**
The recorded `alertsFired` value was 3, but the replay produced 0.
Check that the ledger's `alertLevel` entries for readings #8–10 have
`receipt.arguments[0] == 'critical'`. If they do and the replay still
fails, the `alertLevel` cell's `postProcessRule` may not be firing; the
`Cell.state` factory wires it up automatically, but a custom
`ValueCell` subclass might not.

**`fork produced unexpected alert count` at §5.** The mutation's
`forkAlertsFired` closure drifted from what the fork actually produced.
The closure must start at the baseline (0) and increment once per
critical reading under `forkThreshold`. If you add or reorder readings,
the starting value changes.

**`IoEffect.rawOutput` is null.** The recording's effect serialisation
failed. For `FileLedgerStore`, check the JSON; for
`InMemoryLedgerStore`, check that the closure passed to
`EffectJournal.io` returns a JSON-encodable value (the demo returns
`Map<String, Object?>`).

**`StateError: CellGraph reachability violation` at §1.** The demo's
cells don't use `bind`, so this would only occur if you modified the
source. For production code, register upstream cells explicitly.

---

## See also

- `example/replay/treasury_transfer_demo.dart` — the same workflow
  applied to a financial-transfer domain.
- `example/replay/agent_incident_forensics_demo.dart` — the same
  workflow applied to an AI agent incident.
- `example/replay/record_and_replay.dart` — minimal recording and
  replay.
- `example/replay/whatif_branch.dart` — minimal fork and mutation.
- `guide/HowTo-Causal-Replay.md` — the seven-item checklist and
  pre-flight guide.
- `test/replay/` — the framework's own test suite, one
  directory per phase.
