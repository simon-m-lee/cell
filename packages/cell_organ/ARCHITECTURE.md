# cell_organ — Architecture

**Author:** Lee Man Hoi Simon (see [`AUTHORS`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_organ/AUTHORS))

This document explains the design intent behind **cell_organ**: why
entities and relationships are cells, how bidirectional links stay
consistent, and where Blend and Cascade sit. For a feature catalog, see
[`FEATURES.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_organ/FEATURES.md). Lower layers: [cell](https://github.com/simon-m-lee/cell/tree/master/packages/cell),
[cell_tissue](https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue).

---

## 1. The core idea

Most domain models treat a relationship as a foreign key or a list of
IDs: a pointer you keep in sync by hand. Observers see “the user
changed,” not that a *post was attached*, and the inverse `HasMany` on
the other side is someone else’s problem.

cell_organ treats an **entity as a cell whose members are fields**, and
a **relationship as a cell whose members are other entities**. Updating
`user.posts` is the same kind of mutation as `TissueSet.add`: validate,
commit under a lock, emit a pulse. The inverse `post.author` is meant to
follow via a **mirror handshake**, not a second manual write.

A **Blend** is a zero-copy projection: live pointers to other entities’
fields under a new identity. A **Cascade** walks the graph from a root
and exposes the reachable set as one observable tissue.

That is a design *intent*. Code generation (`cell_ontogeny`) is expected
for real models. Some factories are unfinished (`Cascade.fromMap`).
[`lib/entity.dart`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_organ/lib/entity.dart) currently only re-exports
`relatable.dart`. See [§6](#6-current-status-and-known-gaps).

---

## 2. Progressive disclosure

| Tier | What you use | When |
|------|----------------|------|
| **1. Model + fields** | Subclass `Model`, `ValueField` / `RelationField`, `HasMany` / `BelongsTo` | Typical domain object. Often generated. |
| **2. Validation and deputies** | `TestRelatable` / `TestOne` / `TestRelation`, `.deputy()`, `.unmodifiable` | Field rules, graph invariants, UI vs system views. |
| **3. Projections** | `Blend`, `Cascade` | Dashboards, flattened trees, cross-entity views. |
| **4. Nucleus / receptor** | `OneNucleus`, `ModelNucleus`, `RelatableReceptor`, `Reference` | Blueprints, hydration, custom transduction. |

Defining `User` with a name field should not require understanding
`RelatableNucleus`. Reaching for `Blend.group` or a custom receptor is a
deliberate choice.

---

## 3. Layering on cell and tissue

```
Model / One / Blend     cell_organ   entity + relations
    │
TissueList / TissueSet  cell_tissue  collections
    │
Cell / Pulse / TestCell cell         graph
```

| Primitive | Role |
|-----------|------|
| **`Relatable`** | Cell that has fields, relations, and `TestRelatable`. |
| **`One`** | Identifiable organism: `id`, timestamps, map of `Symbol → Tissue` (fields). |
| **`Model`** | `One` specialized for typed, usually generated, domain types. |
| **`Many`** | `TissueSet` of `Relatable` that is itself relatable. |
| **`Field`** | `TissueValue` owned by a `One` (`ValueField` or `RelationField`). |
| **`Relation`** | Tissue of related `One`s; `HasOne` / `BelongsTo` / `HasMany` / `ManyToMany`. |
| **`Blend`** | Virtual `One` assembled from borrowed fields (no copy). |
| **`Cascade`** | Relatable that crawls a graph to a given depth. |
| **`RelatableReceptor`** | Tissue receptor for relatable pulses. |
| **`TestRelatable`** | Tissue-level validation for fields and relations. |

A field change is still a tissue/cell update. Observers can bind the
model (coarse) or a single field (fine).

### Mutation cycle (same as tissue, named)

```
model.field = x  /  hasMany.add(child)
    │
    ▼
TestField / TestRelation / TestOne
    │
    ▼
RelatableReceptor
    │
    ▼
Field / relation Tissue  (under host Lock)
    │
    ▼
RelatableEvent (FieldChanged, OneAdded, …)  → Synapses
    │
    ▼
Mirror handshake (inverse BelongsTo / HasMany, when implemented)
```

---

## 4. Relations and mirror synchronization

Relations are not ORM annotations. They are tissues on the host:

| Type | Cardinality | Who writes |
|------|-------------|------------|
| **`HasOne`** | 1:1 owner | Host assigns the related `One`. |
| **`BelongsTo`** | 1:1 / N:1 inverse | **Unmodifiable from the child**; follows the owner. |
| **`HasMany`** | 1:N owner | Host’s set of children. |
| **`ManyToMany`** | N:N peers | Both sides may hold membership. |

`Has` marks the owning side. `ModelHasOne` / `ModelHasMany` /
`ModelBelongsTo` / `ModelManyToMany` restrict endpoints to `Model`.

**Handshake (intent):** constructing or mutating `HasMany`/`HasOne` looks
for a reciprocal `BelongsTo` (or `ManyToMany`) on the other entity and
updates it under the same lock so the graph does not fork. If you rely
on that for a given pair of types, verify it against current source and
generated code.

`Relation.field` and `Relation.has` keep the link anchored on the host’s
field slot and identity.

---

## 5. Blend, Cascade, deputies

**Blend** does not own data. It holds pointers to existing `Field`s,
optionally remapped (`Blend.from`) or grouped (`Blend.group`). Mutations
through the blend write the source fields. The blend has its own `name`,
`id`, `testRule`, and lock for multi-field commits.

**Cascade** starts at a `Relatable` and walks relations up to `depth`,
exposing the discovered set as one tissue. Use it to bind a UI to a
subtree or to validate a graph. `Cascade.fromMap` is unimplemented.

**Deputies** are the same as on cell/tissue: shared storage, additive
`TestOne`/`TestModel`, optional `FilterRule` over visible fields.
`deputy == principal` remains true. Deep unmodifiable is intended to
project reachable relations as read-only; treat that as intent until
you confirm for your model graph.

**Identity:** `One.id` is the stable key for relations, serialization,
and de-duplication. Deputies share it.

---

## 6. Current status and known gaps

- **Alpha.** `publish_to: none`. Depends on `cell_tissue` (path). No
  `example/` or `test/` in this package.
- **`lib/entity.dart`** is a stub: it only re-exports `relatable.dart`
  (entity parts are commented out).
- **`Relatable.model()`** is an annotation marker (`RelatableNever`), not
  a live entity.
- **`Cascade.fromMap`** throws `UnimplementedError`.
- Typical models are expected to be **generated** by `cell_ontogeny`;
  hand-written `Model` subclasses must still supply a `ModelNucleus`
  (fields list, test rules).
- Dartdoc mentions GDPR/HIPAA on `validate`. That is metadata you attach
  via `Context`; it is not a compliance implementation.
- Bidirectional handshake, deep unmodifiable of whole subgraphs, and
  persistence via `Reference.fromMap` should be verified against current
  generated code and `cell_memory` / `cell_ontogeny`.

If you rely on a guarantee here, check the source. Gaps and issues are
useful at this stage.
