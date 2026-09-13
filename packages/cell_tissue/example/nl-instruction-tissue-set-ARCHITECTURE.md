# Architecture — NL instruction → TissueSet (Flow + Tissue)

**Companion to:** `nl-instruction-tissue-set-Demo.dart`
**Audience:** engineers extending the demo, teaching the seam, or porting the pattern to another industry.

---

## Contents

1. [One-paragraph summary](#1-one-paragraph-summary)
2. [Layering](#2-layering)
3. [Ownership matrix](#3-ownership-matrix)
4. [Locking](#4-locking)
5. [Failure semantics](#5-failure-semantics)
6. [Extending the demo](#6-extending-the-demo)
7. [Anti-patterns](#7-anti-patterns)
8. [Reading order for newcomers](#8-reading-order-for-newcomers)
9. [See also](#9-see-also)

---

## 1. One-paragraph summary

The demo wires two independent reactive subsystems together:

- **Flow** — the natural-language interpretation subsystem. Turns
  a `Pulse<String>` (an operator's sentence) into a
  `TissueCommand` (`add` / `addAll` / `remove` / …) or a `Reject`.
  Runs one I/O round trip against an interpreter port (a live AI
  chatbot over HTTP, or a deterministic offline stub). No state
  mutation, no set writes.
- **Tissue** — the membership books subsystem. Records every
  mutation against a `TissueSet<int>` (add, remove, clear,
  retainAll). Every write is validated by a `TestTissue` and takes
  that collection's lock.

The two subsystems share exactly **one** communication channel: a
`Flow.map` instruction (`_runDispatch`) that consumes
`TissueCommand` pulses from the interpreter and issues the
matching tear-off against the current host. Nothing else crosses
the seam. The host swap (`_dispatchHost.value = auditor` in
scenario 8) is a Flow-side change, not a Tissue-side change.

---

## 2. Layering

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  FLOW (interpretation + dispatch)                               │
│  ────────────────────────────────                               │
│  • Cells:  commandIn, interpreted.cell, filtered.cell,          │
│            dispatchedCell                                       │
│  • Rules:  TestCell — sentence shape only                       │
│  • State:  counters, _dispatchHost (Box<TissueSet<int>>)        │
│                                                                 │
│  Produces:  Pulse<TissueCommand>  |  Pulse<Reject>              │
│                                                                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │  Flow.map  (the only glue)
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                                                                 │
│  TISSUE (books)                                                 │
│  ─────────────                                                  │
│  • Collections:                                                 │
│      tags     TissueSet<int>                                    │
│      auditor  tags.unmodifiable                                 │
│  • Rules:  TestTissue — element shape (>= 0)                    │
│                                                                 │
│  Produces:  durable membership + audit trail                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1 What "the seam" means here

A **seam** is a boundary where two subsystems with different
responsibilities, locks, and failure modes meet. In this demo the
seam is one-directional: the interpreter produces a
`TissueCommand`; the dispatch instruction consumes it and mutates
the set. Nothing writes back from Tissue to Flow.

### 2.2 What the seam is **not**

- Not a shared mutable object.
- Not a callback registry.
- Not a shared lock.
- Not a shared verb whitelist — the collection's `modifiable` is
  the whitelist, and the dispatch instruction consults it.

The dispatch instruction is a one-way delivery channel. If you
ever find yourself wanting to write back from `_runDispatch` to
the interpreter, you have collapsed the seam and lost the lesson.

### 2.3 The three coupling points in this demo

There are exactly three places where the two subsystems touch:

| Coupling | Direction | Type | Notes |
|---|---|---|---|
| `interpreted.cell` → `filtered.cell` | Flow → Flow | pulse pass | classification, no Tissue |
| `filtered.cell` → `dispatchedCell` | Flow → Tissue | mutation | `_runDispatch` |
| `auditor.modifiable` read | Tissue → Flow | read-only | `modifiable.contains(tearOff)` |

The read of `auditor.modifiable` is the only non-write coupling,
and it is explicitly part of the dispatch's policy input.

---

## 3. Ownership matrix

| Concern | Flow | Tissue |
|---|---|---|
| Sentence shape (non-empty, ≤ 200) | ✅ `_commandShape` on `commandIn` | — |
| Interpreter I/O | ✅ `AiTissueCommand` + port | — |
| Reply parsing | ✅ `HttpInterpreter._parse` / `StubInterpreter._parseEnvelope` | — |
| Classification (`TissueCommand` vs `Reject`) | ✅ `Flow.filter<Object>` | — |
| Verb → tear-off lookup | ✅ `_registry(host)` | — |
| Whitelist gate | ✅ `_runDispatch` | ✅ owns the manifest |
| Element shape (`>= 0`) | — | ✅ `_elementRule` on `tags` |
| Container mutation | — | ✅ `tags.add` / `remove` / `clear` / etc. |
| Event emission | — | ✅ `TissuePulse` per mutation |
| Read-only projection | — | ✅ `tags.unmodifiable` |
| Host swap | ✅ `_dispatchHost.value` | — (Tissue is passive) |
| Counters (interpret / dispatch / reject) | ✅ harness fields | — |
| Traffic log | ✅ interpreter port | — |
| Mode selection | ✅ `_selectHarness` | — |

**Rule.** If a concern appears in both columns, it is a layering
violation. The only intentional exception is that `_runDispatch`
reads `host.modifiable`: the read is one-way, non-mutating, and
part of the policy input.

### 3.1 Which subsystem owns which lock

Every reactive node in this graph has its own lock. The demo
deliberately keeps two disjoint lock domains (see §4). No operation
in the demo holds both locks at the same time. That is a design
choice, not a coincidence: it makes each subsystem independently
testable.

### 3.2 Which subsystem owns which counter

Counters are Flow state. They are not stored in any Tissue and
they do not appear in the trip log.

| Counter | Field | Incremented by | Meaning |
|---|---|---|---|
| Commands | `commands` | `say(...)` after `emit` accepted | ingress accepted the sentence |
| Interpreted | `interpretedCount` | `Flow.filter<Object>` test | a `TissueCommand` crossed the filter |
| Dispatched | `dispatchedCount` | `_runDispatch` success | a tear-off ran without throwing |
| Rejected | `rejectedCount` | `Flow.filter<Object>` test | a `Reject` was dropped |

`interpretedCount` and `dispatchedCount` differ whenever the
`modifiable` gate denies a verb (scenario 8). `interpretedCount`
increments at the filter; `dispatchedCount` increments only after
a successful tear-off.

---

## 4. Locking

Two lock domains:

| Domain | Primitive | Held during |
|---|---|---|
| Interpretation | none of the Tissue locks | `AiTissueCommand.complete`, `Flow.filter`, `Flow.map` |
| Books | Tissue lock on `tags` | one `add` / `remove` / `clear` / `retainAll` |

A `TissueCommand` pulse crosses the two domains **sequentially**,
never simultaneously:

```
commandIn.emit('add 1')
  ─► commandIn ingress lock
       ─► _commandShape
  ─► unlock
  ─► AiTissueCommand
       ─► interpreter.complete (I/O)
       ─► future!(Pulse<TissueCommand>)
  ─► Flow.filter
       ─► interpretedCount++
  ─► Flow.map
       ─► _runDispatch
            ─► _registry(host)
            ─► host.modifiable.contains(tearOff)   (no lock)
            ─► host.add(1)                        (TissueSet lock)
```

The `AiTissueCommand` interpreter's `complete(...)` call does no
Tissue work. The dispatch instruction takes no Tissue lock; the
tear-off does.

### 4.1 Consequences

- Because the domains are disjoint, the interpreter cannot deadlock
  against `tags.add`.
- Because they are sequential, the interpreter cannot observe a
  half-written set.
- Because each Tissue write takes its own lock, two dispatch
  instructions on different hosts do not contend on a shared
  Tissue lock unless they happen to target the same collection.
- The interpreter holds no Tissue lock during its HTTP round trip.
- The dispatch instruction holds no interpreter lock.

### 4.2 Why the demo does not use a joint lock

A joint commit across `tags` and a hypothetical audit log would
require a single lock spanning both. That is a legitimate pattern
(see §6.5), but this build of `cell_tissue` does not expose it.
The v1 protocol compensates on failure instead, and the header
documents the trade-off.

### 4.3 The v1 dispatch protocol

`_runDispatch` does three things and nothing else:

```
1. Look up the tear-off in _registry(host)[cmd.verb].
2. Check host.modifiable.contains(tearOff).
3. Call the tear-off.
```

If step 1 returns `null` (unknown verb), `_runDispatch` prints
`denied (no tear-off)` and returns.

If step 2 returns `false`, `_runDispatch` prints
`denied (not in modifiable)` and returns.

If step 3 throws, `_runDispatch` catches, prints
`threw ${e}`, and returns. `dispatchedCount` is not incremented.

`_runDispatch` never compensates. It also never partially
commits: each tear-off is a single atomic mutation on the set.

---

## 5. Failure semantics

### 5.1 Sentence-shape failure (TestCell)

A bad sentence (empty, > 200 chars, non-String) dies at ingress.
`commandIn.emit(...)` returns `false`; `say(...)` returns `false`
without incrementing `commands`. The interpreter is not called.
Tissue is not touched.

**Why at the ingress, not inside the instruction.** A shape error
is a client / keyboard problem, not a policy problem. Folding it
into the interpreter would make the interpretation conditional on
transport quality and would let a malformed sentence produce a
`TissueCommand`.

### 5.2 Refusal (Reject)

The interpreter returns `Reject`. The instruction fires
`future!(Pulse<Reject>)`. The filter sees a `Reject`, increments
`rejectedCount`, and drops the pulse. The set is unchanged.

**Why a `Reject` is a value, not an exception.** A refusal is a
successful interaction with the model, not a failure of the
pipeline. Modelling it as a value lets the filter count it and
drop it, and lets a downstream consumer (if one existed) attach a
policy to it.

**Reject reasons the demo exercises:**

| Reason | Source |
|---|---|
| `no-permitted-verb` | `StubInterpreter` classifier (scenario 6) |
| `empty-command` | `StubInterpreter` classifier (empty input) |
| `unknown-verb` | parser, when the model returns an unrecognised verb string |
| `empty-reply` | instruction, when the port returns neither |
| `parse-error: ...` | parser, on malformed JSON |
| `interpreter-error` | instruction's `onError` handler (scenario 10) |

### 5.3 Transport failure (interpreter-error)

The interpreter's `complete(...)` throws (network error, timeout,
parse failure). The instruction's `onError` handler runs — it
routes the error to the port's `TrafficLog` — and the instruction
emits no pulse.

**Why no pulse on error.** The instruction's contract is "success
→ `TissueCommand`, refusal → `Reject`, error → nothing". An error
is not a refusal; the pipeline should not see one.

The demo's scenario 10 injects the error via
`injectTimeoutOnce()`, which throws before the HTTP request is
made in live mode. That keeps the scenario deterministic and fast.

### 5.4 Element rule rejection (TestTissue)

The sentence is valid, the model returns a valid `TissueCommand`
(e.g. `add -1`), the dispatch gate passes (`add` is in
`modifiable`), and the tear-off runs. The `TestTissue` rejects the
element (`-1 < 0`). The container is unchanged; no `ElementAdded`
is emitted. `dispatchedCount` is not incremented.

**The gate order.** `_runDispatch` checks `modifiable` before
calling the tear-off. The element rule runs *inside* the tear-off.
A `denied (not in modifiable)` line therefore means the element
rule was never reached; a `[tags] reject ...` line means the
`modifiable` gate passed and the element rule failed.

### 5.5 Tear-off exception

A tear-off that throws is caught by `_runDispatch`'s try/catch.
The message is printed; `dispatchedCount` is not incremented; the
pipeline continues. In practice the demo's tear-offs do not throw:
`TissueSet.add` silently ignores a rejected element, and
`TissueSet.remove` returns a `bool`.

### 5.6 Host-swap failure

`useAuditorHost()` swaps `_dispatchHost.value` to the read-only
view. `useMutableHost()` swaps it back. Neither swap touches the
graph.

**The failure mode this prevents.** If the dispatch gate did not
check `modifiable`, an auditor host would receive a write attempt
that mutates the underlying container. The `modifiable` check is
the guard.

**The failure mode this does not prevent.** A future implementation
that wraps `TissueSet` in a plain `Set` would lose the guard. The
demo's `Box<TissueSet<int>>` typing keeps the guard intact.

### 5.7 `.unmodifiable` snapshot behaviour

In this build, `.unmodifiable` captures the set at install time.
The trailer prints `auditorLength=0`, and scenario 8 still verifies
the dispatch seam via `auditor.modifiable` (which is empty
regardless of the captured snapshot).

**Production note.** A live deputy is the intended contract. This
build's snapshot behaviour is a documented deviation (see the demo
header's § Documented deviations). Any production code that
depends on `auditor.length` reflecting post-install mutations
should migrate to a live `.deputy(TestTissue.readOnly)`.

---

## 6. Extending the demo

### 6.1 Adding a fourth verb (e.g. `toggle`)

1. Add `toggle` to `TissueVerb` in `ai_tissue_command_domain.dart`.
2. Add `'toggle'` to `verbByName`.
3. Add the tear-off to `_registry`.
4. Add the case to `_runDispatch`'s switch.
5. Update the system prompt's arg-shape rules.
6. Extend the trailer.

The pattern is mechanical: one enum value, one map entry, one
registry entry, one switch case, one prompt line.

### 6.2 Adding a batch interpreter (`AiTissueCommandBatch`)

Replace the single `interpretedInstruction` with
`AiTissueCommandBatch<String>`. The input becomes
`Iterable<String>` instead of `String`. The reply becomes
`Pulse<List<Object>>`. Downstream, iterate and dispatch each
element.

**The seam does not move.** `AiTissueCommandBatch` still owns the
I/O; the dispatch instruction still takes no Tissue lock. Only the
input and output shapes change.

### 6.3 Adding retry (`AiTissueCommandWithRetry`)

Replace the single `interpretedInstruction` with
`AiTissueCommandWithRetry<String>`. The port is invoked up to
`count + 1` times on transport failures. Model refusals do not
consume the retry budget.

**Scenario 10's change.** Instead of `injectTimeoutOnce()`, call
`injectTimeoutOnce()` `count + 1` times to exercise the exhausted
path.

### 6.4 Adding a persistent command audit

Introduce a second TissueList alongside `tags`:

```dart
final commandLog = TissueList<TissueCommand>(
  testRule: TestTissue<TissueCommand, TissueList<TissueCommand>>(
    (cmd, {host, arguments, user}) =>
        cmd is TissueCommand && cmd.source.isNotEmpty,
  ),
);
```

In `_runDispatch`, after a successful tear-off, append to
`commandLog`. The audit log is a Tissue, so it is observable and
append-only.

**What this buys.** Every accepted verb is reconstructible after
the fact, keyed on the sentence the operator wrote.

**What this costs.** `_runDispatch` now writes two Tissues. The
two writes are not atomic; a crash between them leaves a member in
`tags` without an audit row (or vice versa). See §6.5 for the
joint-commit alternative.

### 6.5 Joint commit across tissues

When the running `cell_tissue` build exposes a joint commit across
`TissueSet` + `TissueList`, replace `_runDispatch`'s sequence with
a single `Cell.transaction` block. Until then, stay on the v1
protocol.

**The joint-commit shape.**

```dart
await Cell.transaction((tx) async {
  tx.update(tags, {1});
  tx.update(commandLog, TissueCommand(add, [1]));
  await tx.commit();
});
```

If either write rejects, the whole transaction rolls back. This
eliminates the need for the v1 sequence's implicit ordering.

### 6.6 Rate limiting per operator

Introduce a `TissueMap<String, int>` keyed on the operator's
identifier, and a `TestTissue` that decrements the count on each
dispatch.

```dart
final quotas = TissueMap<String, int>(
  properties: TissueMapNucleus<String, int>(
    testRule: TestTissue<int, TissueMap<String, int>>(
      (v, {host, arguments, user}) => v is int && v >= 0,
    ),
  ),
);
```

`_runDispatch` consults `quotas[operatorId]` before the tear-off
and decrements after. The rate limit is Flow-side policy; the
quota state is Tissue.

### 6.7 Approval queue for high-risk verbs

Introduce a `TissueQueue<TissueCommand>` for verbs requiring
approval (say `clear`). `_runDispatch` enqueues instead of
executing. A second consumer (an operator UI) drains the queue and
executes approved verbs.

**The seam does not move.** The interpreter still produces a
`TissueCommand`; the dispatch instruction still consults
`modifiable`. Only the execution timing changes.

### 6.8 Multi-model fallback

Introduce a `Cell.synthesis` over two `AiTissueCommand` handles.
The synthesis fires on whichever interpreter responds first and
succeeds. The dispatch instruction sees only one `TissueCommand`
per sentence.

### 6.9 Signature on `TissueCommand`

Attach a `Provenance.integrity` field to the pulse's context in
the interpreter port. `_runDispatch` verifies the signature before
the tear-off. The signature is Flow-side policy; the verification
is a Flow-side check.

### 6.10 Migration to another industry

The pattern is domain-agnostic. To reuse it for, say, a smart-home
command surface:

1. Rename the domain types (`TissueCommand` → `DeviceCommand`,
   `TissueVerb` → `DeviceVerb`).
2. Rewrite the tear-off registry for the new verb set.
3. Keep the seam: `AiTissueCommand → Filter → MapValue` per
   product, one interpreter port, one `TestTissue` per collection.
4. Keep the two-lock discipline.

The `ride-hail-dispatch(tissue)-Demo.dart`,
`card-auth-pipeline(tissue)-Demo.dart`, and
`grid-demand-response(tissue)-Demo.dart` files are worked examples
of the same pattern in different domains.

---

## 7. Anti-patterns

| Anti-pattern | Why it breaks the lesson |
|---|---|
| `tags.add(...)` inside `AiTissueCommand` | Folds Tissue into Flow; destroys the two-lock discipline. |
| `interpreter.complete(...)` inside `_runDispatch` | Folds Flow into the dispatch instruction; makes the pipeline async and untestable. |
| Hand-rolled verb whitelist instead of `modifiable` | Duplicates the collection's contract; a new verb added to `modifiable` is silently ignored by the interpreter. |
| Skipping the `modifiable` check in `_runDispatch` | The auditor host receives a write attempt. |
| Passing a `TestCell` to `TissueSet`'s `testRule:` | Type error at best; silent looseness at worst. |
| Wrapping a `TestTissue` in `TestCell` to “compose” | They are not subtypes; compose with `+` on the correct side. |
| Catching the interpreter's exception inside the filter | The filter sees pulses, not exceptions. `onError` belongs on the instruction. |
| Emitting a `Reject` **and** a `TissueCommand` on the same sentence | The filter counts both; the counters diverge from the console. |
| Building a second `toHandle` for the interpreter on every `say(...)` | Classic "stacked graph" bug; doubles every downstream effect. |
| Swapping `_dispatchHost.value` inside a scenario without restoring it | Subsequent scenarios dispatch against the auditor host and are denied for the wrong reason. |
| Reading `tags` from inside the filter to “check duplicates” | Duplicates are the `Set<int>` container's job. Reading `tags` adds a Tissue-lock round trip and couples the filter to the container's storage strategy. |
| Making `_runDispatch` async | `MapValue` projects synchronously. An async `_runDispatch` would need a different operator (e.g. `AsyncMap`), which changes the lock profile. |
| Encoding `removeWhere` / `retainWhere` as a string and `eval`-ing it | The model must not produce code. The demo refuses these verbs. |
| Bundling `_runDispatch` into the interpreter's `future!` callback | The interpreter's contract is "produce a pulse"; the dispatch instruction's contract is "mutate the set". Merging them collapses the seam. |
| Using a Dart `List<int>` as the source of truth | The set is the `TissueSet<int>`; a local list is only for formatting. |
| Fetching `tags.length` in `main` from a hand-rolled tracker | Read the Tissue. It is the source of truth. |

---

## 8. Reading order for newcomers

1. **This file** — the architecture in five minutes.
2. **`nl-instruction-tissue-set-Demo.dart`** — skim the class doc,
   then read `_runDispatch`, `install`, `say`.
3. **`nl-instruction-tissue-set-WalkThrough.md`** — the requirement
   and the scenario contract.
4. **`nl-instruction-tissue-set-FEATURES.md`** — the operator
   catalogue.
5. **`ai_tissue_command.dart`** — the three instructions that
   wrap the interpreter port.
6. **`ai_tissue_command_domain.dart`** — the `Interpreter` port,
   `HttpInterpreter`, `StubInterpreter`, `TrafficLog`, `AiConfig`.

For a second domain, read `ride-hail-dispatch(tissue)-Demo.dart`
or `card-auth-pipeline(tissue)-Demo.dart` in the same order. The
seam is identical; only the policy, the domain types, and the
`TestTissue` rules differ.

---

## 9. See also

| File | Purpose |
|---|---|
| `nl-instruction-tissue-set-Demo.dart` | Executable implementation. |
| `nl-instruction-tissue-set-WalkThrough.md` | Requirement document and scenario contract. |
| `nl-instruction-tissue-set-FEATURES.md` | Operator catalogue and feature index. |
| `ai_tissue_command.dart` | `AiTissueCommand`, `AiTissueCommandBatch`, `AiTissueCommandWithRetry`. |
| `ai_tissue_command_domain.dart` | `Interpreter`, `HttpInterpreter`, `StubInterpreter`, `TrafficLog`, `AiConfig`. |
| `ride-hail-dispatch(tissue)-ARCHITECTURE.md` | Mobility sibling — same seam, different domain. |
| `card-auth-pipeline(tissue)-ARCHITECTURE.md` | Payments sibling. |
| `grid-demand-response(tissue)-ARCHITECTURE.md` | Energy sibling. |
| `ICU-alarm-pipeline(enhanced)-ARCHITECTURE.md` | Clinical sibling. |