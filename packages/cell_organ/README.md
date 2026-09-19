# cell_organ

Relational entities for the Cell Framework. A **model** is a cell whose
members are **fields**; a **relation** is a cell whose members are other
models. Built on [cell_tissue](https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue) (and [cell](https://github.com/simon-m-lee/cell/tree/master/packages/cell)).

[![Dart](https://img.shields.io/badge/Dart-3.5%2B-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT%20%2F%20Apache--2.0-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Alpha-orange.svg)](#status)

You work in named properties (`user.name`) and links (`user.posts`), not
a separate ORM session. Validation, locking, and pulses are the same
cycle as any cell. Defaults are allow-all.

Production models are usually **generated** by cell_ontogeny.
This package is the runtime those classes use.

---

## When it fits

Use cell_organ when:

- Domain objects have **typed fields and relations** (User / Post /
  author), not just a `TissueMap`
- Inverse links should stay in sync (`HasMany` ↔ `BelongsTo`)
- You need a **virtual view** of fields from several entities (`Blend`)
- You need a **flattened subgraph** for UI or validation (`Cascade`)

Stay on **cell** / **cell_tissue** if you only need atoms or collections
without a typed graph. Persistence is **cell_memory**, not this package.

---

## Install

Not on pub.dev (`publish_to: none`). From this monorepo:

```yaml
dependencies:
  cell:
    path: packages/cell
  cell_tissue:
    path: packages/cell_tissue
  cell_organ:
    path: packages/cell_organ
```

```dart
import 'package:cell_organ/relatable.dart'; // graph + tissue + cell
import 'package:cell_organ/model.dart';     // Model, typed relations, Reference
```

Requires Dart `>=3.5.0 <4.0.0`.

---

## Quick example

Hand-written sketch of the generated pattern (library docs):

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

void bindUi(User user) {
  Cell.observe(
    source: user.name,
    effect: (pulse) => print('name: ${pulse.payload}'),
  );
}

void dashboard(User user, Stats stats) {
  final row = Blend('UserSummary', fields: [
    user.name,
    stats.totalOrders,
  ]);
}
```

Zero-copy blend: writes through `row` update the source fields. See
[`docs/guides/InDepth-Blend.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_organ/docs/guides/InDepth-Blend.md).

---

## Building blocks

| Type | Role |
|------|------|
| `Relatable` | Cell with fields/relations and `TestRelatable` |
| `One` | Identity (`id`, timestamps) + field map |
| `Model` | Typed `One` (usually generated) |
| `ValueField` / `RelationField` | Scalar vs relation slot |
| `HasOne` / `BelongsTo` | Singular owner / inverse |
| `HasMany` / `ManyToMany` | Collections of related `One`s |
| `Blend` | Virtual `One` from borrowed fields |
| `Cascade` | Walk relations to a `depth` |
| `Many` | Relatable `TissueSet` of relatables |
| `Reference` / `ModelReference` | Hydration registry (`fromMap` / `fromJson`) |

Observe the whole model or a single field with `Cell.observe`. Deputies
and `.unmodifiable` work as on cell/tissue (`testRule` required on
`One.deputy`).

---

## How much you need to know

1. **Generated `Model` + fields/relations** — intended default.
2. **`TestOne` / `TestRelation` and deputies** — when the graph has rules
   or UI must be read-only.
3. **`Blend` / `Cascade`** — projections and subtree walks.
4. **Nuclei, `RelatableReceptor`, `Reference`** — blueprints and
   persistence hooks.

See [ARCHITECTURE.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_organ/ARCHITECTURE.md).

---

## Documentation

| Document | What it is |
|----------|------------|
| [FEATURES.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_organ/FEATURES.md) | Catalog of types, relations, Blend, Cascade |
| [ARCHITECTURE.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_organ/ARCHITECTURE.md) | Why entities and links are cells |
| [docs/guides/InDepth-Blend.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_organ/docs/guides/InDepth-Blend.md) | Blend in depth |
| [../cell_tissue/README.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/README.md) | Collections |
| [../cell/README.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/README.md) | Core graph |

---

## Status

**Alpha** (Mitosis preview, `1.0.0`). APIs may change. No example suite
or tests in this package. `lib/entity.dart` only re-exports relatable.
`Cascade.fromMap` is unimplemented. `Relatable.model()` is an annotation
for codegen, not a live instance.

Bidirectional handshake and JSON hydration should be checked against
**cell_ontogeny** output and current source.

Not published to pub.dev. No independent audit. Context/compliance
fields are metadata, not a certification.

---

## License

MIT or Apache-2.0. See [LICENSE](https://github.com/simon-m-lee/cell/blob/master/packages/cell_organ/LICENSE).

## Authors

Lee Man Hoi Simon. See [AUTHORS](https://github.com/simon-m-lee/cell/blob/master/packages/cell_organ/AUTHORS) for copyright holders.
