# HowTo-CellListener

`CellListener<V>` runs a callback for every pulse a cell emits — without
rebuilding anything.

## When to use / not use

Use it for one-shot side effects: navigation, snackbars, haptics,
analytics, logging.

Do **not** use it for state display — that is `CellBuilder` (see
`HowTo-CellBuilder.md`). Do not use it for batch/broadcast work — use
`Cell.observe` directly there.

## `CellListener` vs `CellBuilder`

| | `CellBuilder` | `CellListener` |
|---|---|---|
| Rebuilds on pulse | Yes | No |
| Receives the current value | Yes (synchronous read) | No (only pulses) |
| Use for | "What to show" | "What to do in the world" |
| Common sources | `Cell.state`, `ValueCell` | Any `Cell` (ingress, derive, asyncMap) |

## Basic snackbar / analytics example

```dart
CellListener<AuthState>(
  cell: authCell,
  onPulse: (context, pulse) {
    if (pulse.payload is SignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed in')),
      );
    }
  },
  child: CellBuilder<AuthState>(...), // drives the UI, not the listener
)
```

The listener sits **above** the child in the tree, so its `BuildContext`
can resolve `Navigator.of`, `Theme.of`, `ScaffoldMessenger.of`, and
`MediaQuery.of`.

## Mid-frame deferral

A pulse fired during Flutter's build phase would normally throw
"setState() or markNeedsBuild() called during build" if the handler calls
`setState`, pushes a route, or shows a snackbar. `CellListener` defers
those pulses to the end of the frame:

| `SchedulerPhase` | Deferred? | Why |
|---|---|---|
| `idle` | No | No frame in progress; `setState` is safe |
| `transientCallbacks` | No | Animation tickers; `setState` here is legal |
| `midFrameMicrotasks` | **Yes** | Between animations and build; defer to avoid any risk |
| `persistentCallbacks` | **Yes** | Build/layout/paint; `setState` throws |
| `postFrameCallbacks` | No | After frame; `setState` schedules next frame |

Multiple pulses arriving in one frame are delivered **in order** in a
single post-frame callback. Pulses from event handlers, timers, and
microtasks outside a frame are delivered synchronously — no frame of
latency is added.

## Error pulses from `asyncMap` / `fromFuture` / `fromStream`

Error pulses arrive as `Pulse<Object>(type: 'error')`; the payload is the
error, **not** a `V`. Branch on the type before casting:

```dart
onPulse: (context, pulse) {
  if (pulse.type == 'error') {
    showErrorDialog(context, pulse.payload);
    return;
  }
  final value = pulse.payload as V?; // safe on the data path
  handleValue(value);
},
```

Listeners over `Cell.asyncMap` sources with `concurrency > 0` inherit the
framework's Gate G1.5 caveat: concurrent effect attribution is tracked
separately by the `cell` core package and is not yet verified end-to-end.

## Async `onPulse` + `mounted` pattern

`onPulse` may be `async`; the returned `Future` is ignored. Check
`context.mounted` after every `await` — the listener may have been
unmounted while you were waiting:

```dart
onPulse: (context, pulse) async {
  await showDialog(context: context, ...);
  if (!context.mounted) return;
  Navigator.of(context).push(...);
},
```

## Error containment

If `onPulse` throws, the error is reported via `FlutterError.reportError`
and the listener keeps receiving subsequent pulses. One bad handler does
not kill the listener.

## Cell swaps and the pending-queue semantics

Swapping the `cell` widget parameter rebinds the listener to the new cell.
Any pulses that were queued for a deferred (post-frame) delivery at the
moment of the swap are **discarded** — they were emitted at a listener
bound to the old cell, and delivering them now would misattribute them.

The same holds for unmounting: pending pulses are cleared on dispose.

## Multiple listeners over one cell

Each `CellListener` is an independent observer. Two listeners over the
same cell each receive every pulse; ordering is per-listener.

## See also

- `example/lib/auth_flow.dart` — sign-in flow using `CellListener` for
  effects and `CellBuilder` for display.
- `HowTo-CellBuilder.md` — the state-display primitive.
- `HowTo-CellScope.md` — registering app-level cells.
- `package:cell` — `Cell.observe`, `Pulse`, and the framework's replay
  verification status.
