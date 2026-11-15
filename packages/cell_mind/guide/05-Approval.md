# Approval — human-in-the-loop as a `Defer` resolver

*The third verdict semantics: `Accept` and `Reject` shipped in Phase
1/2; `Defer` ships here — atomic, auditable, journaled.*

---

## §1 — What `Defer` means

A `Defer` is a policy saying **"I don't know; ask someone who does."**
It is not a rejection — it is a hand-off. Phase 4 gives the hand-off a
home:

- `VerdictPolicy` — a policy type whose `call` returns `Accept`,
  `Reject`, or `Defer`.
- `onDeferred` — the runtime hook that receives deferred decisions.
- `ApprovalQueue<T>` — the HITL primitive: pending tissue, committed
  state, TTL sweeper, journaled decisions.
- `approvalResolver()` — the bridge from a `Defer('approval')` verdict
  to the queue.
- `learnedVerdictPolicy()` — learned rules with `action: 'defer'`.

---

## §2 — `VerdictPolicy` vs `Policy`

### §2.1 — Why two types

`Policy` is `TestCell<Cell>` — it returns `bool`. Folding `Defer` into
`bool` would create the "bool loses Defer" bug: `false` can mean
"rejected" or "deferred", and composition would collapse the two.

`VerdictPolicy` is a separate type:

```dart
abstract interface class VerdictPolicy {
  Verdict call(dynamic object, {required Cell host, dynamic arguments});
  VerdictPolicy operator +(VerdictPolicy other);
}
```

### §2.2 — The two-slot model

`cognitive()` takes both:

```dart
final handle = cognitive(
  cell: cell,
  policy: contextAware() + learnedPolicy(),       // bool slot
  verdictPolicy: myRule() + learnedVerdictPolicy(), // verdict slot
  onDeferred: approvalResolver(queue),
);
```

Evaluation order: principal rule → bool policy → verdict policy. A
rejection in an earlier slot never reaches a later one.

### §2.3 — Composition rules

`VerdictPolicy.+` short-circuits on the first `Accept` or `Reject`;
only `Defer` propagates to the next policy in the chain:

```dart
manualRule() + learnedVerdictPolicy()
// manualRule Accept/Reject wins; its Defer falls through to learned rules.
```

`Policy` and `VerdictPolicy` do **not** compose with each other — that
is the point.

---

## §3 — Wiring `onDeferred`

### §3.1 — The resolver contract

```dart
Future<bool> Function(Decision, Verdict)? onDeferred
```

Receives the deferred decision (full pulse/command + `Defer` verdict).
Returns `true` for "resolved in favour", `false` for "resolved
against", or throws (fail closed).

### §3.2 — Wave-honest semantics (0.4.0 substrate contract)

The live substrate evaluates an async rule twice per pulse (base entry
+ async drain) with **distinct pulse objects**. Waiting for human
latency inside a pulse wave is therefore impossible to do safely: the
recorder cannot reliably resume a wave it deferred.

Phase 4 ships **wave-honest Defer**:

1. The `Defer` decision is recorded immediately.
2. The pulse is **dropped from the current wave** — fail closed by
   construction; a gate that defers never passes the pulse through
   until a human says yes *and* delivery is arranged.
3. The resolver runs **out-of-band**; its result is recorded as a
   follow-up decision linked by `decisionId`:
   - `true` → `Accept({'deferredBy', 'decisionId', ...annotations})`
   - `false` → `Reject('defer-rejected', ...)`
   - throw → `Reject('defer-resolver-failed', {'error', ...})`
4. Delivery after approval is the resolver's job: the `ApprovalQueue`
   commits approved values to `committed`; applications observe that
   stream and re-ingest when re-delivery is required.

The audit trail therefore shows **two decisions per deferral** — the
request and the resolution, linked by id. This is deliberate: "who
asked" and "who answered" are different audit facts.

### §3.3 — Fail-closed matrix

| Situation | Recorded | Pulse |
|---|---|---|
| `Defer`, no resolver | `Reject('defer-no-resolver')` | dropped |
| `Defer`, resolver true | `Defer` + `Accept(deferredBy)` | dropped (deliver via `committed`) |
| `Defer`, resolver false | `Defer` + `Reject('defer-rejected')` | dropped |
| resolver throws | `Defer` + `Reject('defer-resolver-failed')` | dropped |
| `Defer` on an argument | `Reject('defer-in-argument-validation')` | action dropped |
| `Defer` on a link | `Accept()` (links are structural) | link established |

---

## §4 — `ApprovalQueue` — the HITL primitive

### §4.1 — Construction

```dart
final queue = ApprovalQueue<int>(
  journal: RecordingJournal(),      // required — approval is effectful
  ttl: const Duration(minutes: 5),  // auto-reject after 5 minutes
  maxPending: 100,                  // hard capacity
);
```

Storage: `pending` is a `TissueMap<String, ApprovalRequest<T>>`
(observable, serializable); `committed` is a `ValueCell<T?>` — a
`ValueCell`, not an ingress, because `Cell.txApply` must stage and roll
back the commit.

### §4.2 — submit, approve, reject

```dart
final decision = queue.submit(deferredDecision); // Future<bool>
// ... human reviews ...
await queue.approve(requestId);   // commits request.value to `committed`
await queue.reject(requestId, 'reason'); // no commit
final approved = await decision;  // true / false / expired
```

**Do not `await queue.submit(...)` before deciding** — the future
resolves only when the request is decided (or expired/disposed).

### §4.3 — Completer lifecycle

Every submission registers a completer. It resolves exactly once —
approve, reject, TTL expiry, or `dispose()`. A submission racing with
`dispose()` fails closed without a leak.

---

## §5 — Atomicity guarantees

### §5.1 — What `Cell.txApply` stages (verified on the live substrate)

The Day-1 precursor verified:

```dart
await tx.execute(
  participants: [pending, committed],
  body: (scope) {
    pending.apply((function: pending.remove, ...), tx: scope);
    committed.apply((function: (v) { committed.value = v; }, ...), tx: scope);
  },
);
```

- Success: both mutations land.
- Failure in the commit stage: **both roll back** — the request stays
  pending, `committed` is untouched, the completer is unresolved.

`atomicity_test.dart` pins the rollback with a hostile `committed` rule
that rejects every mutation.

### §5.2 — Rollback behavior

A failed `approve` returns `false` and changes nothing observable.
There is no partial state: no removed-but-uncommitted request, no
committed-but-still-pending request.

### §5.3 — Concurrency

Concurrent `approve`/`reject` calls on the same id serialize through
the transaction: exactly one wins; the losers return `false`.

---

## §6 — TTL expiry

### §6.1 — The sweeper

A cancellable `Timer` fires every `ttl ~/ 4` (expirations are never
delayed more than 25% of the TTL). Expired requests are removed from
`pending`, their completers resolve `false`, and the expiry is
journaled.

**Deviation from the plan, documented:** `EffectJournal.timer` returns
an un-cancellable future; a long-TTL queue would keep the isolate alive
forever. The sweeper therefore uses a `dart:async` `Timer` (cancelled
by `dispose()`) while expirations remain journaled explicitly —
the ledger still reconstructs the timeline.

### §6.2 — Journaling expirations

Each expiry records `mind.approval.expired` with the request id.
Combined with `mind.approval.submitted`, the ledger answers "was this
request human-decided or TTL-decided?" without re-running the sweeper.

---

## §7 — Audit trail

### §7.1 — The decision pair

```text
decision 25304ce6: Defer (resolver: approval, annotations: {reason})
decision e8a821e0: Accept (annotations: {deferredBy: approval,
                    decisionId: 25304ce6, reason})
```

The second decision's `decisionId` annotation links it to the first.
`ApprovalRequest` carries the full deferred decision (pulse + verdict)
so the pending queue itself is a complete audit record.

### §7.2 — Journal effects

| Label | Emitted on |
|---|---|
| `mind.approval.submitted` | request enters `pending` |
| `mind.approval.decided` | human approves/rejects (with the decision) |
| `mind.approval.expired` | TTL sweeper removes a request |
| `mind.approval.disposed` | queue disposal (pending count) |

---

## §8 — `learnedVerdictPolicy()`

### §8.1 — Defer rules in the policy block

Phase 3's block already allowed `action: 'defer'`; Phase 3's
`learnedPolicy()` passes it through. `learnedVerdictPolicy()` honours
it:

| `action` | Verdict |
|---|---|
| `'accept'` | `Accept(annotations)` |
| `'reject'` | `Reject(reason ?? 'learned-reject', annotations)` |
| `'defer'` | `Defer(resolver ?? 'approval', annotations)` |

Matching is the same as Phase 3: canonical context vector, subset
matching, first-match-wins by confidence, `Accept` when silent.

### §8.2 — Training defer rules

A custom `Trainer` can emit `defer` rules (the bandit emits only
accept/reject). When it does, `learnedVerdictPolicy()` routes them —
`learnedPolicy()` still ignores them, so Phase 3 deployments are
unaffected.

---

## §9 — Common patterns

### §9.1 — Financial approval

```dart
final queue = ApprovalQueue<int>(journal: journal);
final handle = cognitive(
  cell: gate.cell,
  verdictPolicy: verdictPolicy((object, {required host, arguments}) {
    if (object is! Pulse) return const Accept();
    return object.payload > 10000
        ? const Defer('approval', {'reason': 'large'})
        : const Accept();
  }),
  onDeferred: approvalResolver(queue),
);
// A UI observes queue.pending; a reviewer calls approve/reject.
// Approved values flow through queue.committed.
```

### §9.2 — Compliance review

Learned rules defer an entire domain:

```dart
verdictPolicy: learnedVerdictPolicy(),
onDeferred: approvalResolver(queue),
```

with a block rule
`{when: {domains: 'audit'}, action: 'defer', resolver: 'approval'}`.

### §9.3 — Emergency override

An operator who needs to let one pulse through immediately can observe
`queue.pending`, approve the request, and re-ingest the value through
the gate — a fresh, fully-governed decision.

---

## §10 — Testing approval flows

Patterns pinned by the suite (59 tests):

- **Never await `submit` before deciding.** Capture the future;
  decide; then await.
- **Deferral is two decisions.** Filter `d.pulse != null` and expect
  `[Defer, resolution]` pairs.
- **Atomicity tests use a hostile `committed`** —
  `Cell.state<T?>(initial: null, testRule: rejectAll).cell` — to force
  a commit failure and observe the rollback.
- **TTL tests inject a mutable clock** —
  `RecordingJournal(clockSource: () => now)` — and advance `now` past
  the TTL; the real sweeper timer does the rest.
- **Gate the pending map with a `TestTissue`** (not `TestCell`):
  `TissueMap(properties: TissueMapNucleus(testRule: ...))`.

---

## §11 — What Phase 4 does not cover

| Concern | Where it lives |
|---|---|
| Multi-approver chains | Phase 6 (agent orchestration) |
| Dashboards / UIs | User code — observe `queue.pending` |
| Webhooks / email | Phase 5+ (bridges) |
| Retry logic | Phase 6 (`attempts` field reserved) |
| Cross-process queues | Out of scope (in-memory) |
| Auto-training defer rules | Custom `Trainer` — the bandit stays accept/reject |

---

## §12 — Phase 4 findings (recorded)

- **`StateError` is an `Error`, not an `Exception`.** Resolver failures
  catch everything, not `is Exception`.
- **Async rule double evaluation.** The substrate validates async rules
  twice per pulse with distinct pulse objects; awaiting human latency
  inside the wave is unsafe — hence wave-honest Defer (§3.2).
- **`TissueMap` gating uses `TestTissue`/`TissueMapNucleus`**, not
  `TestCell`.
- **Static generic methods call as `Class.fromMap<T>(...)`** —
  `Class<T>.fromMap(...)` does not resolve.
- **`completes(...)` does not exist in the pinned matcher** — use
  `completion(...)`.
- **`ApprovalRequest.fromMap` returns a shell** — the decision's live
  objects are lossy by `Decision.fromMap` design.

---

## §13 — Reference table

| Type | Kind | Key members |
|---|---|---|
| `VerdictPolicy` | interface | `call`, `operator +` |
| `verdictPolicy(fn)` | factory | wraps a verdict rule |
| `learnedVerdictPolicy()` | factory | learned accept/reject/defer rules |
| `ApprovalRequest<T>` | record | `id`, `decision`, `verdict`, `requestedAt`, `attempts`, `value` |
| `ApprovalQueue<T>` | class | `pending`, `committed`, `journal`, `ttl`, `maxPending`, `submit`, `approve`, `reject`, `dispose` |
| `approvalResolver(queue)` | factory | `Future<bool> Function(Decision, Verdict)` |
| `cognitive({..., verdictPolicy, onDeferred})` | factory | the two new slots |

---

## §14 — AI Agent Guide notes

1. **Capture, don't await.** `final f = queue.submit(decision);` —
   decide, then `await f`.
2. **Expect decision pairs.** Deferral produces `Defer` + resolution;
   filters that assume one-decision-per-pulse must account for both.
3. **Deliver through `committed`.** Approved values are not
   re-injected automatically; observe `queue.committed` and act.
4. **Never block the wave.** Resolvers must return quickly; anything
   slow belongs behind the queue's completer.
5. **Dispose queues.** Pending completers and sweeper timers are
   released by `dispose()`; leaking a queue leaks both.
6. **Journal everything.** Construct the queue with a real
   `RecordingJournal` — approval is effectful by contract.

---

## §15 — Decision procedures

### 15.1 — "Should this be a `Defer` or a `Reject`?"

- The policy **knows the answer is no** → `Reject`.
- The policy **needs information it does not have** (a human's
  judgement, an external check) → `Defer`.
- The policy **is not confident enough to say yes** and the cost of a
  wrong yes is high → `Defer` with a low-confidence annotation.

### 15.2 — "Should I use `learnedPolicy` or `learnedVerdictPolicy`?"

- No defer rules, bool-only gates → `learnedPolicy()` (Phase 3).
- Learned `defer` rules must route to `onDeferred` →
  `learnedVerdictPolicy()`.
- Never both — they read the same block and double-composing adds
  nothing.

### 15.3 — "Approve, reject, or let it expire?"

- Approve: the value commits to `queue.committed`; delivery code
  observes and acts.
- Reject: the resolution is recorded with the reason; nothing commits.
- Expire: identical to reject, except the reason is time — the
  journal distinguishes them (`mind.approval.expired`).

---

## §16 — Tuning the queue

| Knob | Default | Tune when |
|---|---|---|
| `ttl` | 5 min | SLAs for human turnaround; shorter for rapid experiments |
| `maxPending` | 100 | expected concurrent deferrals; throws beyond |
| `sweepInterval` | `ttl ~/ 4` | derived — do not override; expiry latency ≤ 25% of TTL |

Capacity is fail-fast: a full queue throws `StateError` at submission,
so callers can shed load explicitly instead of queueing without bound.

---

## §17 — FAQ

**Q: Why is the deferred pulse dropped from the wave?**
The live substrate evaluates async rules twice per pulse with distinct
pulse objects; human latency cannot safely resume a wave. Wave-honest
Defer keeps gates non-blocking and the audit trail complete: `Defer`
now, resolution later, linked by `decisionId`.

**Q: How does an approved value reach the application?**
Observe `queue.committed` — a `ValueCell<T?>` emitting approved values.
Re-ingest through the gate when a fully-governed re-delivery is
needed.

**Q: Is approve/reject atomic?**
Yes — `Cell.txApply` stages the pending removal and the commit as one
unit; a commit failure rolls both back (`atomicity_test.dart`).

**Q: What happens to pending requests on dispose?**
Their futures resolve `false`; the sweeper is cancelled; the disposal
is journaled. Submissions after disposal throw.

**Q: Why is `committed` a `ValueCell`, not an ingress?**
`txApply` stages `apply` commands; an ingress handle cannot roll back.
The Day-1 precursor verified both `TissueMap.apply(tx:)` and
`ValueCell.apply(tx:)` stage correctly.

**Q: Can two policies defer to different resolvers?**
Yes — compose `onDeferred` manually:
```dart
onDeferred: (decision, verdict) async {
  if (verdict is! Defer) return false;
  if (verdict.resolver == 'approval') {
    return approvalResolver(queue)(decision, verdict);
  }
  if (verdict.resolver == 'supervisor') {
    return supervisorFlow(decision, verdict);
  }
  return false; // fail closed
}
```
A multiplexer helper is Phase 6.

---

## §18 — What Phase 5 inherits

- `ApprovalQueue` — LLM bridge outputs can defer to approval before
  committing tool effects.
- `verdictPolicy` / `onDeferred` — the bridge's router gates are
  verdict-shaped where humans are in the loop.
- The journaled effect set — replay machinery for bridge actions
  builds on the same `mind.*` labels discipline.
- The decision-pair audit pattern — bridge completions that defer will
  produce the same `Defer` → resolution chain.

---

## §19 — Summary

Phase 4 completes the verdict space. The three architectural wins:

1. **Two slots, two types.** `Policy` stays bool; `VerdictPolicy` adds
   `Defer` without breaking any Phase 1–3 composition.
2. **Wave-honest deferral.** The gate never blocks on a human; the
   deferral and the resolution are separate, linked audit facts.
3. **Atomic HITL.** `ApprovalQueue` decides in one `txApply` unit,
   expires with a cancellable sweeper, and journals every state
   transition — a compliance-grade answer to "who approved this?"
