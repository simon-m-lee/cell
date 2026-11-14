# HowTo-DerivedCells

`Cell.derive`, `Cell.synthesis`, and `Cell.switchMap` return plain `Cell` —
not `ValueCell`. This guide is the bridge between them and the widgets.

## Why derived cells return `Cell`

State operators (`Cell.state`) hold a current value and return
`ValueCell`. Derivation operators transform pulses and hold no
synchronous current value of their own, so they return `Cell`. Widgets
that need a synchronous value (`CellBuilder`, `CellSelector`) cannot
take them directly.

## `CellValueBuilder` — the recommended bridge

Wrap the derived cell; the widget mirrors it and renders through a
`CellBuilder`:

```dart
final total = Cell.synthesis<Pulse<int>>(
  [price.cell, tax.cell],
  aggregator: (cells, _) {
    final sum = cells.fold<int>(0, (acc, c) {
      final v = c is ValueCell<int> ? c.value ?? 0 : 0;
      return acc + v;
    });
    return Pulse<int>(sum);
  },
);

CellValueBuilder<int>(
  cell: total,
  builder: (_, v) => Text('Total: $v'),
)
```

The mirror's lifecycle is the widget's lifecycle — nothing to dispose.

## `asValueCell` — the advanced, explicit-lifecycle bridge

For a mirror that must outlive a widget (a service layer):

```dart
final mirror = total.asValueCell<int>(initial: 0);
// ...pass mirror.cell to CellBuilder / CellSelector...
mirror.dispose(); // ← required, or the egress leaks
```

The record return makes the lifecycle explicit; a plain `ValueCell`
return would hide the leak.

## When to use `CellBuilder` vs `CellValueBuilder`

| Source | Widget |
|---|---|
| `Cell.state(...).cell` (a `ValueCell`) | `CellBuilder` |
| `Cell.derive` / `synthesis` / `switchMap` / tissue collections | `CellValueBuilder` |
| Derived cell + slice rendering | `CellValueBuilder` wrapping `CellSelector`, or `asValueCell` + `CellSelector` |

## Errors in derived cells (mostly silent)

Derived cells inherit the per-source error behavior of the operators they
compose:

| Source | Emits error pulse |
|---|---|
| `Cell.fromFuture` | Yes |
| `Cell.fromStream` | No |
| `Cell.asyncMap` | No |

An `asyncMap`-based derivation shows the last successful value on
failure. `CellValueBuilder(emitErrors: true)` reports error pulses that
do arrive.

## Concurrent `asyncMap` caveat (inheritance)

Derivations over `Cell.asyncMap` with `concurrency > 0` inherit Gate
G1.5: concurrent effect attribution is tracked separately by the `cell`
core package. The observation is correct; the caveat is about the
source's replay fidelity.

## See also

- `example/lib/derived_cells.dart` — `CellBuilder` vs `CellValueBuilder`
  side by side.
- `HowTo-CellAsyncBuilder.md` — the full error-source table.
- `HowTo-CellSelector.md` — selectors over bridged cells.
- `package:cell` — the derivation operators.
