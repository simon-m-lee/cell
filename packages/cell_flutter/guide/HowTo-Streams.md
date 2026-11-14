# HowTo-Streams

`Cell.asStream()` bridges any cell to a Dart `Stream<V?>` — the escape
hatch for `Bloc`, `StreamBuilder`, and stream-shaped interop.

## `asStream` — the escape hatch

```dart
final counter = Cell.state<int>(initial: 0);
await for (final v in counter.cell.asStream<int>()) {
  print(v); // 1, 2, ... (pulses only — the initial value is not emitted)
  if (v! >= 3) break;
}
```

Use it for `StreamBuilder`, `rxdart` pipelines, or any API that takes a
`Stream`. Inside the widget tree, prefer the cell widgets.

## Sync vs async streams

`sync: true` (default) delivers values in the same microtask as the
pulse — convenient for tests. Some consumers dislike synchronous
delivery; pass `sync: false` for those.

## Cancellation and egress cleanup

The stream is single-subscription and backed by a `Cell.observe` egress.
Cancelling the subscription stops the egress and closes the controller —
no leak.

## Single-subscription semantics

Listening twice throws. For broadcast use:

```dart
final broadcast = cell.asStream<int>().asBroadcastStream();
```

## Error-pulse sources

`emitErrors: true` (default) converts arriving error pulses into
`Stream.addError`. Which pulses arrive depends on the source:

| Source | Emits error pulse |
|---|---|
| `Cell.fromFuture` | Yes |
| `Cell.fromStream` | No |
| `Cell.asyncMap` | No |

For silent sources, catch failures inside the mapper / stream and re-emit
them through a `Cell.fromFuture` if you need them on the stream.

## See also

- `HowTo-CellAsyncBuilder.md` — the widget-layer equivalent.
- `HowTo-DerivedCells.md` — bridging derived cells.
- `package:cell` — `fromFuture` / `fromStream` / `asyncMap` and the
  framework's replay verification status.
