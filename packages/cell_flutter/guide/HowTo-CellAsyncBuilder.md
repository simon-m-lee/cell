# HowTo-CellAsyncBuilder

`CellAsyncBuilder<V>` renders the asynchronous state of any `Cell` as an
`AsyncSnapshot<V>` — the same shape `FutureBuilder` produces.

## When to use / not use

Use it over `Cell.fromFuture`, `Cell.fromStream`, and `Cell.asyncMap`
outputs (all plain `Cell`s). For `ValueCell` sources, prefer
`CellBuilder` — `CellAsyncBuilder` is for the async operators.

## The `ConnectionState` contract

| State | Meaning |
|---|---|
| `none` | No pulse has arrived yet |
| `active` + data | A data pulse arrived |
| `active` + error | An error pulse arrived |

**`ConnectionState.done` is never reached.** No core operator emits a
completion pulse: `fromFuture` emits once and stays silent; `fromStream`
emits until the stream ends and stays silent. If you need completion
detection, compose with a completion cell (§7).

## The `AsyncSnapshot` decision

`AsyncSnapshot` is Flutter's own type — no vocabulary fork, and every
Flutter developer already knows `hasData` / `hasError` / `connectionState`.
(`hasData` means `data != null`, so for a nullable `V` use
`connectionState` to distinguish "no pulse yet" from "a null payload".)

## Error-pulse sources (the load-bearing table)

| Source | Emits error pulse | What the widget shows on failure |
|---|---|---|
| `Cell.fromFuture` | Yes | `hasError == true` |
| `Cell.fromStream` | No | Last successful value (or `nothing`) |
| `Cell.asyncMap` | No | Last successful value (or `nothing`) |

Only `fromFuture` emits `Pulse<Object>(type: 'error')`. `fromStream`
cancels its subscription on error and emits nothing; `asyncMap` swallows
mapper exceptions. If you need error visibility from those sources:

- Wrap the work in a `Cell.fromFuture` that re-emits the failure, or
- Make the mapper return a sealed result type (`Result<T>`), or
- Wait for the `cell` core change that emits error pulses.

## `initialSnapshot` seeding

Two use cases:

1. **Cache hydration** — pass `AsyncSnapshot.withData(ConnectionState.active, cached)`
   to render the cached value before the first pulse.
2. **Sync-emitting source** — if the source cell emitted before the widget
   subscribed (typical with `Stream.value`), the widget cannot observe
   those pulses. Pass the known value here, or construct the cell before
   the widget tree mounts.

## Concurrent `asyncMap` caveat (Gate G1.5)

When the source is `Cell.asyncMap` with `concurrency > 0` or overlapping
`latestOnly` futures, this widget inherits the framework's Gate G1.5
caveat: concurrent effect attribution is tracked separately and not yet
verified end-to-end. The widget's observation is correct; the caveat is
about the source's replay fidelity.

## Composition with completion detection

Keep a separate completion cell and flip it when the work finishes:

```dart
final done = Cell.state<bool>(initial: false);

// ...when the stream closes / future chain ends:
done.update(true);

// In the widget tree, branch on both cells:
CellBuilder<bool>(
  cell: done.cell,
  builder: (_, isDone) =>
      isDone! ? const Text('Complete') : const SizedBox.shrink(),
),
CellAsyncBuilder<List<String>>(
  cell: results,
  builder: (_, snapshot) => /* render data or spinner */,
)
```

`CellAsyncBuilder` handles the data; the completion flag handles the end.

## Known limitation: type-mismatch pulses

A `Pulse<int>` arriving at a `CellAsyncBuilder<String>` becomes an error
snapshot (a `StateError` in `snapshot.error`), not a thrown exception.

## See also

- `example/lib/async_search.dart` — live search over `asyncMap(latestOnly: true)`.
- `HowTo-DerivedCells.md` — the error-source table repeated for derived
  cells.
- `HowTo-Streams.md` — the `asStream` escape hatch.
- `package:cell` — `fromFuture`, `fromStream`, `asyncMap` and the
  framework's replay verification status.
