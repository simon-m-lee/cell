# Determinism — replay, versions, journals

*How cell_mind preserves the framework's replay guarantees.*

---

## §1 — Context versioning

Every `Decision` records `contextVersion`, resolved at decision time from
`cell.context.version` (defaulting to `'0.0.0'` — "unversioned"). This
field is **load-bearing**:

- A decision made under version 2 was made against version 2's
  `Ontology.constraints['cell_mind.policy']`.
- Replaying it against version 3's constraints would silently change the
  verdict — the classic learning-on-learning instability.
- The trainer (Phase 3) joins by version: a decision recorded under
  version 2 is trained against version 2's context vector, not
  version 3's.

**The unversioned trap:** contexts built without an explicit version
stamp every decision `'0.0.0'`. Such logs are not replayable across
implementation changes. Teams that train must stamp their contexts:

```dart
final context = Context.fromEntries([
  Ontology.domains.entry('finance'),
  Ontology.version.entry('1.0.0'),
]);
```

**The rule: editing constraints without bumping `context.version` breaks
replay.** Each training run emits an evolved context with a bumped
version; rules inside the block carry their `trainedIn` version so the
trainer can skip rules produced by the current version (the
feedback-loop guard).

---

## §2 — Replaying a decision log

Replay is **re-evaluation with the recorded context**, not a table scan.
Three layers, exactly as the substrate defines them:

| Layer | Mechanism | Guarantee |
|---|---|---|
| Pure policy evaluation | plain re-execution | exact (`Purity.pure`) |
| Clock/network-reading policy | `EffectJournal.clock()` / `.io()` | exact via recorded observations |
| Recording itself | `readOnlyExternal` log write | observational, does not alter replay |

Phase 2's fitness baseline (F8) pins layer 2: a `RecordingJournal`
replayed through a `ReplayJournal` reproduces recorded clock/uuid/io
observations byte-for-byte, and the replay side **does not run** the
live closure.

```dart
final recording = RecordingJournal(
  clockSource: () => DateTime.fromMillisecondsSinceEpoch(1000),
);
// ... run the effectful path under JournalScope.run(recording, ...)
final replay = ReplayJournal(
  recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
);
// ... run the same path under JournalScope.run(replay, ...)
```

### Replaying a decision

```dart
final restored = Decision.fromMap(decision.toMap());
// The record shell restores exactly: id, at, contextVersion, verdict,
// policyVersion, evaluationTime. Live Context/Pulse/ApplyCommand objects
// are not reconstructible (documented lossy serialization).
```

The verdict — including its reason and annotations — is the replayable
unit. Policy re-evaluation under the *same* recorded context version
must produce the same verdict; that is the property Phase 3's
determinism tests assert for the trainer.

---

## §3 — EffectJournal semantics

`cell_mind`'s relationship with journals, per purity:

- **Policies (`pure`)** need no journal. The one exception is
  `notOlderThan` (`readOnlyExternal`) — its *clock* must be
  journal-backed in a replayable graph:
  `clock: () => EffectJournal.current.clock()`.
- **The recorder (`readOnlyExternal`)** writes the decision log — an
  observation, not a mutation. It needs no journal entry of its own; the
  log is the record.
- **The trainer (Phase 3, `effectful`)** takes `required EffectJournal
  journal` — a training run is an effect (external state = the new
  `Context`), and replaying it re-reads the decision log from the
  journal, not the live tissue.

`NullJournal` fails loudly by design. `cell_mind` never defaults a
journal and never catches the sentinel's failure.

---

## §4 — When replay breaks

The failure modes, each with its guard:

1. **Constraints edited without a version bump.** The log claims
   `1.0.0` but the current context behaves differently. Guard: stamp
   contexts (§1); Phase 3's `trainedIn` rule tagging.
2. **Clock read directly.** A policy calling `DateTime.now()` is
   non-deterministic by construction. Guard: injected clocks;
   `readOnlyExternal` declarations.
3. **Non-pure policy with side effects.** A `TestCell` that writes to
   user state during evaluation cannot be replayed. Guard: the
   framework's purity contract — `cell_mind` policies are documented
   pure, and the recording layer adds nothing to evaluation.
4. **Serialization lossiness mistaken for replay.** `Decision.fromMap`
   restores the record shell, not the live objects. Guard: the guide
   says so; Phase 3's codec narrows the gap where training requires it.
5. **The unversioned trap.** A log full of `'0.0.0'` stamps cannot be
   replayed across implementation changes. Guard: documentation + the
   examples stamp their contexts.

---

## §5 — Testing determinism

Phase 2 pins the substrate guarantees cell_mind leans on:

- **F8 (fitness):** journal recording → replay reproduces recorded
  observations, and replay never invokes the live closure.
- **F3 (fitness):** `Pulse.context` inherits through `evolve` — the
  decision log's context provenance.
- **F1 (fitness):** `Context.evolve` semantics (replace on non-null) —
  the trainer's merge contract.
- **Serialization suite:** verdict/id/timestamp/version round-trips.

Phase 3 adds the trainer-level determinism suite: identical decision
logs under a `ReplayJournal` must produce identical `TrainedPolicy`
maps.

---

## §6 — Versioning the policy

The recorder stamps `policyVersion` from the policy's `version`
(TestRule default `'0.0.0'` — unversioned). `notOlderThan` ships as
`'1.0.0'` — a stable implementation identity for the replay engine. The
same convention applies to user policies: bump the version when the
implementation changes while the semantics stay stable, so the replay
engine can dispatch by version instead of silently diverging.

---

## §7 — The cognitive loop, deterministic

```
recorded context vN ──► policy (pure) ──► Decision(contextVersion: vN)
                                               │
                             ┌─────────────────┴────────────────┐
                             ▼                                  ▼
                    TissueList<Decision>              IngressHandle<Pulse>
                             │                                  │
                             └────────── Trainer (Phase 3) ◄─────┘
                                        journaled effect
                                             │
                                             ▼
                              evolved Context vN+1
                                             │
                                             ▼
                              next runtime (static or dynamic)
```

Every arrow preserves determinism: pure policies re-evaluate, the log
records the version, outcomes join by decision id, and the trainer runs
offline under a journal. Nothing in the loop mutates the live policy.

---

## §8 — The determinism checklist for effectful primitives

Any primitive added in later phases must answer all five questions
before merge:

1. **What does it read from the outside world?** Every read goes
   through `journal.clock()`, `journal.io(...)`, or an injected clock —
   never a direct call.
2. **What does it write?** Training writes a `Context`; bridges write to
   transports. Both are journaled effects, not silent mutations.
3. **Is the verdict reproducible?** Given the same recorded inputs, the
   same output must emerge. Pure policies guarantee this by
   construction; `notOlderThan` guarantees it via the injected clock.
4. **What version stamps the artifact?** Trained contexts bump
   `context.version`; policy implementations carry `version` strings;
   decisions carry both.
5. **Where does replay get its data?** The `ReplayJournal`, not the
   live tissue — the trainer re-reads the decision log from the journal
   on replay.

---

## §9 — Worked example: a deterministic freshness gate

```dart
final gate = Cell.ingress<int>(
  testRule: notOlderThan(
    Duration(minutes: 5),
    clock: () => EffectJournal.current.clock(),
  ),
);

// Production: inside a journal scope, every clock read is recorded.
await JournalScope.run(RecordingJournal(), () async {
  // pulses flow; each evaluation reads journal.clock()
});

// Replay: the same scope with a ReplayJournal serves the recorded
// clock values; the policy makes byte-identical decisions.
final replay = ReplayJournal(
  recording.toJson().map(EffectRecord.fromJson).toList(growable: false),
);
await JournalScope.run(replay, () async {
  // the identical pulse sequence reproduces the identical log
});
```

Two rules make this work: the policy never calls `DateTime.now()`, and
the recording journal is the only source of time. Violate either and the
gate is non-deterministic — no amount of post-hoc tooling fixes it.

---

## §10 — Determinism in the decision log itself

The log's own determinism contract:

- **Id generation** (`Identity.next()`) is unique but not replayable —
  replay assigns fresh ids. Correlation across replays therefore uses
  the *recorded* id in the serialized map, not the runtime id.
- **Timestamps** (`Decision.at`) are wall-clock observations. A replay
  produces new timestamps; ordering is preserved by the log sequence,
  not the clock.
- **`evaluationTime`** is a measurement, not an input — it varies
  between runs and must never feed a policy decision.
- **Order** of entries in the `TissueList` is the causal order of
  evaluations; replay preserves it because the pulse sequence and rule
  evaluations are deterministic.

What replay *guarantees* is the sequence of **verdicts** under each
recorded context version. What it does *not* guarantee is id equality,
wall-clock equality, or timing equality — and no cell_mind primitive
may depend on those.

---

## §11 — Determinism tests, now and later

| Test | Phase | Asserts |
|---|---|---|
| F8 — journal round-trip | 0 | recorded observations replay byte-for-byte; live closures don't run |
| F1 — evolve semantics | 0 | constraints replace on non-null (the trainer's merge contract) |
| F3 — pulse context inheritance | 0 | context flows through `evolve` |
| decision serialization | 2 | verdict/id/timestamp/version round-trip |
| trainer determinism | 3 | identical logs + `ReplayJournal` → identical `TrainedPolicy` |
| approval compensation | 4 | transactional approve/reject leaves no partial state |
| bridge replay | 5 | completion/tool outcomes replay from journaled transports |

Each later phase's definition of done includes its row; a phase may not
ship with a red determinism test.

---

## §12 — FAQ

**Q: Are decision ids replayable?**
No. `Identity.next()` is unique per generation; replays assign fresh
ids. Correlate replays by the *recorded* id in the serialized map.

**Q: Is the decision log itself an effect?**
It is an observation (`readOnlyExternal`), not a mutation — the log is
the record, not a side effect that needs journaling.

**Q: Does `evaluationTime` affect policies?**
It must never. It is a measurement, varies between runs, and no policy
may read it.

**Q: Can a `paranoid()` gate be replayed without a journal?**
Yes — every policy in the composite is `pure`. Only
`notOlderThan`-style rules need journaled clocks.

**Q: What happens when a policy throws during replay?**
`Exception`s fail closed with a recorded `composite-rejected`;
`Error`s propagate. Replay divergences surface loudly, never silently.

---

## §13 — What Phase 3 inherits

The trainer's determinism contract, written in advance:

1. **Merge, then evolve.** F1 proved `Context.evolve` replaces the
   constraints map on a non-null resolver. The trainer merges the
   `cell_mind.policy` block *before* evolving — one evolve call, one
   new version.
2. **Join by decision id.** Outcomes carry `decisionId`; unresolved
   ids are skipped — no reward signal, no rule.
3. **Bucket by context vector.** The vector
   `(domains, compliance, authority, actor, strategy)` must be a pure
   function of the decision — no wall clock, no hash order.
4. **Version-tag rules.** Each rule carries `trainedIn`; the current
   version's rules are skipped when configured (learning-on-learning
   guard).
5. **Journal the run.** `required EffectJournal journal` — the run is
   an effect; replay re-reads the log from the journal.
