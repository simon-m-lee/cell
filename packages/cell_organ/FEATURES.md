# cell_organ — Feature Catalog

**Package:** `cell_organ`  
**Version:** 1.0.0 (Alpha / Mitosis preview)  
**SDK:** Dart `>=3.5.0 <4.0.0`  
**License:** MIT or Apache-2.0  
**Author:** Lee Man Hoi Simon (see [`AUTHORS`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_organ/AUTHORS))  
**Location:** `packages/cell_organ`

Categorized inventory of the relational / entity layer. Entities and
relations are **cells** built on [cell_tissue](https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue). If
dartdoc and factories disagree, **the source is current**. Design intent:
[`ARCHITECTURE.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_organ/ARCHITECTURE.md).

---

## Table of Contents

1. [What cell_organ Is](#1-what-cell_organ-is)
2. [Status and Boundaries](#2-status-and-boundaries)
3. [Libraries](#3-libraries)
4. [Relatable](#4-relatable)
5. [One](#5-one)
6. [Model](#6-model)
7. [Fields](#7-fields)
8. [Relations](#8-relations)
9. [Many](#9-many)
10. [Blend](#10-blend)
11. [Cascade](#11-cascade)
12. [Validation](#12-validation)
13. [Receptor, Nucleus, Events](#13-receptor-nucleus-events)
14. [Reference and Hydration](#14-reference-and-hydration)
15. [Deputies](#15-deputies)
16. [Relationship to cell / tissue](#16-relationship-to-cell--tissue)
17. [Use-Case Decision Matrix](#17-use-case-decision-matrix)
18. [Known Gaps](#18-known-gaps)
19. [Quick Reference](#19-quick-reference)

---

## 1. What cell_organ Is

**cell** is a node. **cell_tissue** is a collection-as-cell. **cell_organ**
is an **entity graph**: typed objects with scalar fields and relations
that participate in the same reactive cycle.

- A **Model** is a `One`: identity (`id`), timestamps, map of named
  tissues (fields).
- A **Field** is a `TissueValue` on that map.
- A **Relation** is a tissue of other `One`s (`HasOne`, `BelongsTo`,
  `HasMany`, `ManyToMany`).
- A **Blend** projects other entities’ fields into a virtual `One`.
- A **Cascade** flattens a reachable subgraph into one observable set.

Typical apps define models as generated subclasses (`cell_ontogeny`).
This package is the runtime those classes sit on.

Depends on `cell_tissue` (and thus `cell`). `relatable.dart` re-exports
`package:cell_tissue/tissue.dart`.

---

## 2. Status and Boundaries

**Alpha.** `publish_to: none`. No `example/` or `test/` in this package.

| Claim | Reality |
|-------|---------|
| Drop-in ORM | No SQL, no migrations. Relations are reactive tissues. Persistence is `cell_memory` / generated `Reference`. |
| Bidirectional links always in sync | Design of Has/BelongsTo handshake; verify per generated pair. |
| `entity.dart` entity types | Stub: re-exports `relatable` only. |
| `Cascade.fromMap` | Throws `UnimplementedError`. |
| GDPR / HIPAA on `validate` | Context metadata you attach — not a certified control. |
| `@Relatable.model()` | Annotation for codegen; constructing it yields `RelatableNever`. |

---

## 3. Libraries

| Import | Contents |
|--------|----------|
| `package:cell_organ/relatable.dart` | Relatable, One, Many, Field, Relation, Blend, Cascade, TestRelatable (main API) |
| `package:cell_organ/model.dart` | `Model`, `ModelNucleus`, `ModelHasOne` / `HasMany` / `BelongsTo` / `ManyToMany`, `Reference` |
| `package:cell_organ/entity.dart` | Re-export of `relatable.dart` only |

---

## 4. Relatable

`Relatable` implements `Cell`. Anything in the organ graph (one, many,
relation, blend, cascade) is relatable.

**Events** (constants on `Relatable`, types in `RelatableEvent`):

| Constant / type | Meaning |
|-----------------|---------|
| `fieldChanged` / `FieldChangedEvent` | A field’s value changed |
| `fieldAdded` / `FieldAddedEvent` | Schema: field added |
| `fieldRemoved` | Schema: field removed |
| `relationAdded` / `RelationAddedEvent` | Relation slot added |
| `relationRemoved` | Relation slot removed |
| `oneChanged` / `OneChangedEvent` | Related one changed |
| (plus one-added / one-removed style events on collections) | Membership in a relation |

**API**

| Member | Role |
|--------|------|
| `validate` | `TestRelatable` |
| `fields` / relations (via nucleus) | Named tissues |
| `deputy` / `unmodifiable` | Same contract as cell, typed |
| `@Relatable.model({testRule, receptor})` | Codegen annotation only |

---

## 5. One

Identifiable organism: `Relatable` + `TissueMap<Symbol, Tissue>`.

| Member | Role |
|--------|------|
| `id` | Stable string identity (relations, JSON, de-dupe) |
| `createdAt` | Immutable genesis time |
| `lastModifiedAt` | Updated on successful mutation |
| `deputy({context, testRule, filter})` | Projection; `testRule` required |
| `unmodifiable` | Read-only `UnmodifiableOne` |

Nucleus: `OneNucleus` / `.evolve`. Test type: `TestOne<H>`.

---

## 6. Model

`Model` implements `One` and `UnmodifiableTissueMap<Symbol, Tissue>`.
Typed domain base: iterators yield `Field`.

| Member | Role |
|--------|------|
| `initNucleus` / `ModelNucleus` | Field symbols, `TestModel`, receptor |
| `deputy({context, testRule, filter})` | `TestModel` required |
| `UnmodifiableModel` | Read-only model |

Model-only relations (endpoints are `Model`): `ModelHasOne`,
`ModelHasMany`, `ModelBelongsTo`, `ModelManyToMany`.

Field helpers for generated / hand models: `ModelValueField`,
`ModelRelationField`.

Procedures (associate / deassociate / move / select / update / clear)
live in `src/model/procedures.dart` for graph edits.

---

## 7. Fields

`Field<H, V>` implements `TissueValue<V>` — a named slot on host `H`.

| Type | Role |
|------|------|
| `ValueField<H, V>` | Scalar (String, int, …) |
| `RelationField<H, E, R>` | Holds a `Relation` |
| `FieldNucleus` / `ValueFieldNucleus` / `RelationFieldNucleus` | Blueprints |
| `UnmodifiableField` | Read-only field deputy |
| `TestField` / `TestValue` | Field-level rules |
| `FieldReference` | Codegen / late binding handle |

Fields are looked up by `Symbol` (`#name`) on the host’s tissue map.

---

## 8. Relations

`Relation<H, E>` implements `Relatable` and `Tissue<E>`.

| Type | Shape | Writable from host? |
|------|--------|---------------------|
| `HasOne<H, E>` | Singular owner | Yes |
| `BelongsTo<H, E>` | Singular inverse (`UnmodifiableRelationOne`) | No (follows owner) |
| `HasMany<H, E>` | Set of children | Yes |
| `ManyToMany<H, E>` | Peer set | Yes (symmetric intent) |

`Has<H, E>` marks the owning side. Accessors: `field` (host slot), `has`
(host entity).

Nucleus: `RelationNucleus`, `RelationOneNucleus`, `RelationManyNucleus`.
Validation: `TestRelation<H, E, R>`.

---

## 9. Many

`Many<E extends Relatable>` is a `TissueSet<E>` that is itself
`Relatable` — a population with a unified schema of member fields.

Factory materializes a governed set (`identitySet` optional). Deputies:
`UnmodifiableMany`. Nucleus: `ManyNucleus`.

Use `Many` for a bag of relatables that is not a typed `HasMany` on a
host; use `HasMany` when it is a field of a `One`.

---

## 10. Blend

Virtual `One`: **no copy** of field data; live pointers.

| Factory | Role |
|---------|------|
| `Blend(name, {required fields, …})` | Keys = each field’s name |
| `Blend.from(name, {required map, …})` | Custom `Symbol → Field` (name clashes) |
| `Blend.group(name, {required map, required toValue, …})` | Nested `TissueValue` groups |
| `Blend.fromNucleus(nucleus, {required fields})` | Blueprint |

Own `name`, `id`, `testRule`, lock. Writes through the blend update
source fields. `UnmodifiableBlend` for a read-only lens.

See [`docs/guides/InDepth-Blend.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_organ/docs/guides/InDepth-Blend.md).

---

## 11. Cascade

Graph walk from a root `Relatable`.

| Factory | Role |
|---------|------|
| `Cascade(relatable, {depth, bind, context, testRule, receptor, synapses})` | Crawl to `depth` |
| `Cascade.fromMap` | **Unimplemented** |
| `CascadeNucleus` / `.evolve` | Blueprint |

Result is a `Relatable` tissue of discovered nodes. `UnmodifiableCascade`
for a frozen view of that projection.

---

## 12. Validation

| Type | Applies to |
|------|------------|
| `TestRelatable` | Any relatable (`allowAll` = allow-all singleton) |
| `TestOne` | `One` / blend |
| `TestModel` | typedef of `TestOne` for `Model` |
| `TestField` / `TestValue` | Fields |
| `TestRelation` | Relations |

Compose with `+` / chains like `TestCell`. Deputies **layer** rules.
Defaults are permissive (`TestRelatable.allowAll`, tissue `allowAll`).

---

## 13. Receptor, Nucleus, Events

**RelatableReceptor** — `RelatableReceptor(PulseRule)`, pass-through
singleton internally. Extends `TissueReceptor`.

**Nuclei:** `RelatableNucleus`, `OneNucleus`, `ModelNucleus`,
`ManyNucleus`, `BlendNucleus`, `CascadeNucleus`, field/relation nuclei,
all with `.evolve` for deputies.

**RelatableEvent** extends pulse: field/relation/one change and add
events (see §4). `UnmodifiableRelatableEvent`, composite events exist
for batching.

Observe a model or a field:

```dart
Cell.observe(source: user, effect: (p) { /* FieldChangedEvent, … */ });
Cell.observe(source: user.name, effect: (p) { /* that field only */ });
```

---

## 14. Reference and Hydration

In `model.dart`:

| Type | Role |
|------|------|
| `Reference` | Registry: `model<M>()`, `modelTypes`, `fromMap` / `fromJson`, `typeValue` |
| `RelatableReference` | Optional pointer to a live relatable |
| `ModelReference<M>` | Per-type blueprint: rules, field refs, typed `fromMap` / `fromJson` |

`fromMap` / `fromJson` take `cascade` depth and a `lookup` set for
cycles. Implementations are typically **generated**.

---

## 15. Deputies

Same as cell/tissue:

- Shared storage and lock; `deputy == principal`.
- Additive test rules only.
- `One.deputy` / `Model.deputy` require a `testRule`; optional `filter`
  hides fields.
- `.unmodifiable` on model/field/relation/blend/cascade.

---

## 16. Relationship to cell / tissue

| Need | Package |
|------|---------|
| One counter | `Cell.state` |
| List of strings | `TissueList` |
| User with posts and author inverse | **cell_organ** `Model` + `HasMany` / `BelongsTo` |
| Dashboard row from three models | `Blend` |
| All descendants of a project | `Cascade` |
| Rx operators on a field | **cell_flow** (a field is a cell) |
| SQLite persistence | **cell_memory** + generated `Reference` |
| Generate Model subclasses | **cell_ontogeny** |

---

## 17. Use-Case Decision Matrix

| Need | Feature |
|------|---------|
| Domain entity with named properties | `Model` + `ValueField` |
| Parent has many children | `HasMany` + child `BelongsTo` |
| Profile 1:1 | `HasOne` |
| Tags shared both ways | `ManyToMany` |
| UI form of mixed fields | `Blend` / `Blend.from` |
| Recursively validate a tree | `Cascade` + `TestRelatable` |
| UI cannot mutate | `model.unmodifiable` or deputy with `TestTissue.readOnly` / `TestOne` |
| Hydrate from JSON | `Reference` / `ModelReference.fromJson` |
| Bag of mixed relatables | `Many` |

---

## 18. Known Gaps

1. Alpha; unpublished; no tests or examples in-tree.
2. `entity.dart` has no entity types yet.
3. `Cascade.fromMap` unimplemented.
4. `Relatable.model()` is not instantiable as a real entity.
5. Handshake, deep unmodifiable subgraphs, and `Reference` hydration
   need verification against generated models.
6. Compliance language in comments is not a product feature.

---

## 19. Quick Reference

```dart
import 'package:cell_organ/model.dart';

class User extends Model {
  ValueField<User, String> get name => field(#name);
  HasMany<User, Post> get posts => relation(#posts);

  @override
  ModelNucleus<User> get initNucleus => ModelNucleus(
    fields: [#name, #posts],
  );
}
```

(`field` / `relation` accessors are the generated/hand-written pattern
shown in library docs; nucleus lists the symbols.)

```dart
final summary = Blend('UserSummary', fields: [
  user.name,
  stats.totalOrders,
]);

final tree = Cascade(project, depth: 2);

Cell.observe(source: user, effect: (p) { /* … */ });
```

| Import | Start here |
|--------|------------|
| `relatable.dart` | Relatable, One, Field, Relation, Blend, Cascade |
| `model.dart` | Model + typed relations + Reference |
