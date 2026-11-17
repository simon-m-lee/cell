# HowTo-CellScope

`CellScope` registers cells for a subtree, addressed by `Symbol` — app-level
dependency injection for the few cells that are genuinely global.

## When `CellScope` is appropriate (and when it is not)

Use it for `auth`, `theme`, `featureFlags`, `currentUser` — cells that
almost every screen reads. Everything else should be passed as a
constructor argument: cells flowing through the tree explicitly is the
Mitosis way, and `CellScope` must not become a general-purpose locator.

## `of` vs `maybeOf` vs `valueOf`

| Accessor | Unknown id | Type mismatch | Returns |
|---|---|---|---|
| `of<V>` | throws | throws (`StateError`) | `Cell` |
| `maybeOf<V>` | returns `null` | throws (`StateError`) | `Cell?` |
| `valueOf<V>` | throws | throws (`StateError`) | `ValueCell<V>` |

`Cell` itself carries no value-type parameter, so `of`/`maybeOf` verify the
value type for `ValueCell` registrations (the common `Cell.state` case) and
return other cells (`Cell.ingress`, `Cell.derive`, `Cell.asyncMap`) as-is.
`valueOf` requires a `ValueCell<V>` — the `CellBuilder`-ready form.

## `CellBuilder` + `valueOf` composition

```dart
final authCell = CellScope.valueOf<AuthState?>(context, #auth);
CellBuilder<AuthState?>(
  cell: authCell.unmodifiable,
  builder: (_, state) => Text(state?.name ?? 'Signed out'),
)
```

Register the principal at the root, look up the read-only view at the
leaf — the least-privilege story keeps working through the scope.

## Nested scopes and shadowing

A `CellScope` nested inside another shadows the outer registration for
the same `Symbol` — lookup returns the nearest one. This is
`InheritedWidget`'s own contract.

## `updateShouldNotify` behavior

`CellScope` notifies dependents only when the **effective** registration
changes: a cell replaced at a key, or a key added/removed. Rebuilding with
an equal-but-distinct map — a fresh `{...}` or `Map.from` each build —
does **not** rebuild dependents, because the comparison is cell identity
per key, not map equality. Hold the map in a `final` field for the
`identical` fast path.

## Testing

For widget tests, wrap the widget under test in a `CellScope` with the
cells your test needs. `pumpWithCells` will make this
boilerplate-free; this guide links to `HowTo-Testing.md` when it lands.

## Migration from `Provider` / `InheritedWidget`

- `ProviderScope`/`MultiProvider` → `CellScope` at the app root.
- `context.watch<T>()` → `CellScope.valueOf<T>(context, #id)` +
  `CellBuilder` (or `CellScope.of` + `CellListener` for effects).
- Riverpod's `override` mechanism has **no equivalent here by design**:
  create a fresh cell in `setUp` and register it in the test's scope.

## What's coming next

`CellAsyncBuilder` takes any `Cell` — including one found via
`CellScope.of` — and `CellSelector` works over `valueOf` results. Scoped
async cells become first-class citizens.

## See also

- `example/lib/auth_flow.dart` — `CellScope` + `CellListener` +
  `CellBuilder` together.
- `HowTo-CellBuilder.md` — the state-display primitive.
- `HowTo-CellListener.md` — the side-effect primitive.
- `package:cell` — the underlying framework and its replay verification
  status.
