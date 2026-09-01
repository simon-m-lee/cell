# Cell Framework — Architecture

**Author:** Lee Man Hoi Simon (see [`AUTHORS`](AUTHORS))

Why Cell is shaped this way, for contributors and anyone extending it.
Task-oriented usage lives in `/guide`. Status and the operator table live
in [`README.md`](README.md).

This describes **intent plus the mechanisms that exist in source**. Where
implementation lags the story, §8 says so. Do not treat a field on
`PulseContext` as a finished compliance program.

---

## 1. The core idea

Most reactive libraries treat an update as an opaque event: a value goes
in, a value comes out, and who changed it, why, and under what authority
are gone as soon as the listener runs.

Cell treats an update as a **payload that can carry causal history and
optional governance**, not only a value. A `Pulse` may record where it
came from, which steps transformed it, and which context it travelled
under. Traceability and validation are reliable only if they ride on the
signal (and on the cell’s `TestCell`), not as after-the-fact logging.

That is the design intent. It is optional at the call site. Defaults are
pass-through. Nothing is authorized or redacted unless you pass a rule.

---

## 2. Progressive disclosure

Cognitive load should match the task. `Cell.state` must not require
`Nucleus`. `Nucleus` should stay unused until something actually needs a
custom blueprint.

Moving down the tiers is a **deliberate argument you pass**, not a leak
from internals. If a Tier 1 operator *requires* Tier 3/4 knowledge to use
correctly, that is a design smell, not a reason to add more prose.

### Tier 1 — Entry (operators)

Factories on `Cell`. Usable with no awareness that `Receptor`,
`TestCell`, `Context`, or `Synapses` exist; those parameters default.

Teaching lists have said “16” and “17.” The set application code actually
hits:

| Band | Factories |
| --- | --- |
| Hold / enter / react | `state`, `ingress`, `observe`, `derive`, `open` |
| Shape | `debounce`, `distinct`, `merge`, `throttle`, `synthesis` |
| Async / route | `asyncMap`, `switchMap`, `fromFuture` / `fromStream`, `hub`, `sanitized` |
| Isolate writes | `transaction`, `txApply` |

`Cell.valve` sits beside that set as a predicate gate (`example/valve_demo.dart`).
It is not always in the advertised table. `merge`, `switchMap`, and
`fromFuture` / `fromStream` do not yet have dedicated example files.

### Tier 2 — Composition

When a factory’s built-in behaviour is not enough:

- **`Receptor` / `Instruction`** — custom transform pipelines (`null` = filter).
- **`Synapses` + `PropagationPolicy`** — *how* and *when* observers see a
  pulse: `immediate`, `async`, `debounced`, `throttled`, `batched`,
  `buffered`, `persistent`, and the other strategies in
  `HowTo-PropagationPolicy.md`.
- **`FilterRule`** — redact or drop on egress, before policy timing.

This tier extends operators; it should not replace `debounce` with a
hand-rolled synapse unless the operator cannot express the timing.

### Tier 3 — Governance

When a cell needs explicit rules about who may do what:

- **`TestCell` / `TestRule`** — compose with `+`; gate mutations, links,
  pulses, actions.
- **`Context`** — domain / constraint metadata on the node
  (`Ontology`).
- **`DeputyContext`** — mandate on a proxy (`Mandate`: authority,
  clearance, isolation, sovereignty).
- **`PulseContext`** — provenance on a signal (`Provenance`: actor,
  reason, purpose, sensitivity).

Three vocabularies on purpose: they are not one overloaded enum.

Defaults: `TestCell.allowAll`, `Context.system`.
`Context.describe('…')` fills text fields. It is not a legal basis.

### Tier 4 — Internal

`Nucleus`, `Cell.governed`, `Cell.fromNucleus`, `EphemeralPolicy`,
`PulseEphemeralPolicy`, `withCellLocks`, and the bodies of
`transaction` / `txApply`.

Application code that lives here often missed a Tier 1–3 factory. Stay
here when writing a new operator or a genuine high-integrity gate.

---

## 3. Runtime shape

```
Tier 1 operators
      allocate / link
Cell  =  live node + Box + Lock
      configured by
Nucleus  =  Receptor + TestCell + Context + Synapses + EphemeralPolicy
      carries
Pulse  =  payload + optional PulseContext + trace + optional TTL / hops
      exits through
Synapses + FilterRule + PropagationPolicy
```

| Primitive | Role |
| --- | --- |
| `Cell` / `OpenCell` / `ValueCell` | Node. `ValueCell` + `StateHandle` expose `value` / `update`. `OpenCell.perform` owns topology by hand. |
| `Nucleus` | Immutable flyweight blueprint. Shared across cells. `evolve` overrides selected fields (prototype); `clone` copies without sharing activation. |
| `Pulse<P>` | Immutable signal. May be simple, evolved (trace), or collective (`+` / `batch`). |
| `Receptor` / `Instruction` | Ingress pipeline on the cell. |
| `Synapses` | Egress registry, filters, propagation strategy. |
| `TestCell` / `TestRule` | Validation. Narrower kinds: pulse / link / action. |
| `Context` / `DeputyContext` / `PulseContext` | Metadata at node, proxy, or signal. |
| `Deputy` | Zero-copy proxy; same box and lock; narrower rules. |
| `EphemeralPolicy` / `PulseEphemeralPolicy` | Cell TTL or event budget vs pulse TTL / hop limit. Lazy timer: starts on first interaction, not construction. |

There is no separate integrity engine. A write is: optional test →
receptor → box → synapses.

### The update cycle

Same cycle whether `Cell.state`, `Cell.derive`, or `Cell.governed`
triggered it:

1. Build or accept a `Pulse`.
2. `TestCell` may reject. Default allow.
3. `Receptor` may map or drop (`null`).
4. Commit into the box under the cell’s `Lock`.
5. `Synapses` deliver, subject to filter + policy.
6. Ephemeral policies may tick TTL / hops.

`Pulse.withStep` appends an in-process name. That is not a sealed,
retained audit log.

### Operator construction (Tier 1 implementation pattern)

Internal factories under `lib/src/internal/operator/` usually:

1. Allocate an **output** cell (`Cell.governed` or equivalent).
2. Allocate a **bridge** with synapses disabled, or `source.link`.
3. `retain` the bridge on the output so the subscription outlives locals.

Dropping the returned cell drops the retain graph; the operator stops.
That is lifetime, not GC magic.

---

## 4. Deputies — narrow, do not copy

`Cell.deputy()` returns a proxy that shares the principal’s box and lock
and stacks a narrower `TestCell` / `DeputyContext`.

- **Zero-copy.** Identity is the principal (`deputy == principal`) so
  deputies work in `Set`s / `Map`s as the same node.
- **Narrow only.** Extra rules layer on; a deputy must not widen what the
  principal already forbids, however many `.deputy()` calls you stack.

`Cell.unmodifiable` is the read-only case of the same idea. A deputy
without a denying `TestCell` is metadata, not a security boundary.

---

## 5. Two transaction APIs

Not aliases.

### `Cell.transaction` — value protocol

Coordinate **cell state**.

- `begin(participants)` registers cells; may snapshot.
- `read` / `update` hit a buffer, not the live box.
- `commit` acquires locks in deterministic order (`byHashCode`,
  insertion, or explicit comparator), checks isolation, validates,
  applies, releases.
- Locks are held **at commit**, not across the whole `begin`…`commit`
  window. Long work between begin and commit does not hold the graph.
- Isolation:
  - `readCommitted` (default) — live reads, no snapshot.
  - `repeatableRead` — snapshot at begin; a dirty participant aborts commit.
  - `serializable` — snapshot + read-set + a process-wide gate so commits
    serialize.
- Savepoints rewind the buffer. They do not un-apply a finished commit.

Conflicts throw (`TransactionConflictException`, validation, timeout).
Retry is the caller’s loop.

### `Cell.txApply` — command protocol

Coordinate **side-effecting `apply(fn)`** with an inverse.

- `apply(fn, tx: tx, compensate: undo)` **enqueues** when `tx != null`.
- Commit runs staged functions; failure runs compensations LIFO, with
  retry/backoff and `bestEffort` / `failFast` / `collectThenThrow`.
- `ApplyRejected` is a soft reject, distinct from a thrown error.

Use `transaction` when the state *is* the value. Use `txApply` when the
state changes through named methods (`debit` / `credit`) that need an
undo path. See `example/transaction_demo.dart` and
`example/atomic_multi_update.dart`.

---

## 6. Concurrency

- Each cell has a `Lock` from `package:synchronized`.
- The update cycle runs inside that lock.
- `withLocks` / `withCellLocks` sort participants, then acquire in order,
  so two multi-cell operations do not deadlock on the same pair.
- Serializable isolation adds a process-wide gate.
- Async twins (`ReceptorAsync`, `ValueCellAsync`, …) exist so async
  callers are not a weaker path.

This is **isolate-local** mutual exclusion, not distributed consensus.
Several isolates do not share one Cell graph.

---

## 7. Package shape

```
lib/cell.dart                     barrel + library dartdoc
lib/src/*.dart                    public interfaces (parts)
lib/src/internal/                 implementations (parts)
lib/src/internal/operator/        factories
example/                          17 runnable main() walks
guide/                            HowTo-*.md
ARCHITECTURE.md                   this file
dartdoc_options.yaml              topics; keys must match {@category}
```

One library, many `part`s. Dartdoc topics appear only when a type is
tagged `{@category …}` with the **same string** as the YAML map key.
Advanced HowTos are listed after the entry topics; see
`guide/HowTo-Advanced.md`.

The 17 example files do not map 1:1 onto the factory list (pipelines and
valve extra; some operators have no demo). That mismatch is a release
checklist item, not a secret extra product.

---

## 8. Status and known gaps

Public preview / RC — not a frozen beta. Verify guarantees against
current source.

Known gaps:

- Transaction and compensation internals have not had an independent
  end-to-end review.
- Guides, examples, and barrel factories have drifted (names, 16 vs 17,
  trace markers demos expect, factories shown in examples before they
  landed in the last operator drop).
- Governance **types** are richer than default **gates**. A
  `compliance:` string and a pulse trace are not GDPR/HIPAA/PCI or an
  AI-Act dossier.
- Performance claims (flyweight, zero-copy) are structural; there is no
  published cost model for collective pulses or the serializable gate
  under load.

If a guarantee in this document does not match the code, the code wins.
An issue report is useful.

---

## 9. Design rules

1. **Opt-in depth.** Defaults do not check, redact, or trace beyond what
   the operator needs.
2. **Immutable messages and blueprints.** Mutate the box, not the pulse
   or the nucleus.
3. **Commit is the dangerous moment.** Do not assume exclusive access
   between `begin` and `commit`.
4. **Narrow, don’t widen.** Deputies are views.
5. **Lifetime follows retain/link.** No retained bridge, no operator.
6. **Two consistency tools.** Values → `transaction`. Inversible
   functions → `txApply`. Do not merge the APIs in docs.
