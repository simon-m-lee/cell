# HowTo-Hooks

`package:cell_flutter/hooks.dart` adds `flutter_hooks`-based equivalents of
the widget primitives. Import it instead of (or alongside) the main barrel.

## When to use hooks vs widgets

| You want | Widget | Hook |
|---|---|---|
| Declarative subtree rendering | `CellBuilder` | — |
| Rebuild on selected slice | `CellSelector` | `useCell` |
| Rebuild on every change | `CellBuilder` (identity select) | `useCellValue` |
| Compose with `flutter_hooks` primitives | — | `useCellNotifier` |
| Side effects without rebuild | `CellListener` | `useCellListener` |
| Async `AsyncSnapshot` | `CellAsyncBuilder` | `useCellAsync` |

## `useCell` — selector semantics

```dart
final name = useCell<User, String>(
  cell: user,
  select: (u) => u?.name ?? '',
);
```

Rebuilds only when the slice changes. It requires a `ValueCell<V>` — the
hook needs a synchronous current value. For derived cells
(`Cell.derive` / `synthesis` / `switchMap`), bridge with
`CellValueBuilder` or `asValueCell` first. `equals` defaults to `==`;
pass `listEquals` / `setEquals` / `mapEquals` for collections.

## `useCellValue` — every-change convenience

```dart
final value = useCellValue(counter.cell); // V?
```

`useCell` with `select: (v) => v`. Use only when every change matters.

## `useCellNotifier` — compose with `flutter_hooks`

```dart
final notifier = useCellNotifier(counter.cell);
useValueListenable(notifier); // or pass to ValueListenableBuilder
```

The notifier is disposed automatically on unmount (or cell swap).

## `useCellListener` — effects without rebuild

```dart
useCellListener<AuthState>(
  cell: authCell,
  onPulse: (context, pulse) {
    if (pulse.type == 'error') { showErrorDialog(context, pulse.payload); return; }
    ScaffoldMessenger.of(context).showSnackBar(...);
  },
);
```

Same mid-frame deferral contract as `CellListener`: pulses from build /
mid-frame phases are delivered at frame end (safe for `Navigator.push`);
pulses elsewhere are synchronous. Check `context.mounted` after any
`await`. On cell swap, queued pulses from the old cell are discarded.

## `useCellAsync` — `AsyncSnapshot` semantics

```dart
final snapshot = useCellAsync<List<String>>(results);
```

`ConnectionState.done` is **never reached** (no core operator emits a
completion pulse). The per-source error table is inherited from
`CellAsyncBuilder`:

| Source | Emits error pulse | What `useCellAsync` shows on failure |
|---|---|---|
| `Cell.fromFuture` | **Yes** (`type: 'error'`) | `hasError == true` |
| `Cell.fromStream` | **No** | Last successful value (or `nothing`) |
| `Cell.asyncMap` | **No** | Last successful value (or `nothing`) |

**Cell-swap divergence:** unlike `CellAsyncBuilder`, the hook's snapshot
persists across cell swaps until the new cell emits. To reset, key the
`HookWidget` on the cell (`key: ValueKey(cell)`).

Over `asyncMap` with `concurrency > 0`, the hook inherits the caveat:
concurrent effect attribution is tracked separately by the `cell` core
package; the observation itself is correct.

## `flutter_hooks` rules

Hooks must be called unconditionally, at the top of `build`, in the same
order every build. `flutter_hooks` itself asserts violations.

## See also

- `example/lib/hooks_counter.dart` — the minimal hook-based app.
- `HowTo-CellAsyncBuilder.md` — the widget-layer async contract.
- `HowTo-HotReload.md` — cell lifecycle across hot reload.
- `HowTo-Debugging.md` — the debug diagnostics.
