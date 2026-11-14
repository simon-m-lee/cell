# HowTo-CellSelector

`CellSelector<V, S>` rebuilds only when a selected slice of a cell changes.

## When to use / not use

Use it when `CellBuilder` rebuilds too often: a `Cell<User>` that changes
many fields while a widget only reads `user.name`. Don't use it when the
widget genuinely renders the whole value — that's `CellBuilder`.

## `CellBuilder` vs `CellSelector`

| | `CellBuilder<V>` | `CellSelector<V, S>` |
|---|---|---|
| Rebuild trigger | Value `V` changes | Selected `S` changes |
| Source type | `ValueCell<V>` | `ValueCell<V>` |
| Extra cost | None | `select` runs on every emission |

## Custom `equals`

`equals` defaults to `==`. For collections, pass
`listEquals` / `setEquals` / `mapEquals` from `flutter/foundation`:

```dart
CellSelector<User, List<String>>(
  cell: user.cell,
  select: (u) => u!.roles,
  equals: listEquals,
  builder: (_, roles) => RolesList(roles),
)
```

Without it, a fresh list with identical content triggers a rebuild on
every emission.

## Selector-change semantics

If the parent rebuilds `CellSelector` with the same cell but a new
`select` closure, the widget **recomputes the slice immediately** in
`didUpdateWidget` — it never renders a stale slice while waiting for the
next pulse.

## `ValueCell` requirement and the bridge

`CellSelector` needs a synchronous current value, so it requires a
`ValueCell<V>`. Derived cells (`Cell.derive`, `Cell.synthesis`,
`Cell.switchMap`) return plain `Cell` — bridge them with
`CellValueBuilder` (widget layer) or `asValueCell` (service layer) and
pass the mirror.

## Performance comparison (rebuild counts)

| Scenario (`Cell<User>`, 10 emissions) | `CellBuilder` | `CellSelector` |
|---|---|---|
| `name` changes 3 times | 10 rebuilds | 3 rebuilds |
| `name` unchanged | 10 rebuilds | 0 rebuilds |
| Selector is identity | 10 rebuilds | 10 rebuilds |

## Anti-pattern: selector over the whole value

```dart
CellSelector<User, User>(
  select: (u) => u!,   // ❌ same granularity as CellBuilder + select cost
  ...
)
```

If the slice is the whole value, use `CellBuilder`.

## See also

- `HowTo-CellBuilder.md` — the whole-value primitive.
- `HowTo-DerivedCells.md` — bridging derived cells for selectors.
- `example/lib/derived_cells.dart` — the bridge in action.
