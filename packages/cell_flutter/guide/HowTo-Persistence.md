# HowTo: Persistence with `cell_flutter_persistence`

`cell_flutter_persistence` makes a `cell_flutter` state cell **durable**
across explicit app quits, on top of the restoration (process-kill)
support that `RestorableCell` already provides.

## Setup

```yaml
dependencies:
  cell_flutter: ^1.0.0
  cell_flutter_persistence: ^0.1.0
```

```dart
import 'package:cell_flutter_persistence/cell_flutter_persistence.dart';
```

## The pieces

- **`CellPersistenceAdapter<T>`** — the interface (`read` / `write` /
  `delete`); implement it for any backend.
- **`SharedPreferencesAdapter<T>`** — the common backend. Primitives
  (`String`, `int`, `bool`, `double`, `List<String>`) work natively;
  custom types pass `fromJson` / `toJson` codecs.
- **`InMemoryAdapter<T>`** — the test double.
- **`PersistedCell<T>`** / **`persistedState<T>(...)`** — a restorable
  cell plus an observation link that writes through per `WriteMode`.

## The worked example

```dart
final prefs = SharedPreferencesAsync();
final nickname = persistedState<String>(
  restorationId: 'nickname',
  initial: 'simon',
  adapter: SharedPreferencesAdapter.string(prefs),
);

// In initState (see guide/HowTo-Restoration.md for the scope rules):
CellRestorationScope.maybeOf(context)?.register(nickname.cell);
nickname.start();  // observe + write per WriteMode
nickname.load();   // read the durable value (async, never throws)

// Everywhere else:
nickname.cell.value = 'simon-l';
```

## Write modes

| Mode | Behavior |
|---|---|
| `WriteMode.immediate` | Writes on every change (most durable, most I/O). |
| `WriteMode.debounced` (default, 1s) | Writes after a quiet period; bursts coalesce into one write. |
| `WriteMode.onAppPause` | Writes when `handleAppPaused()` is called — wire it to a `WidgetsBindingObserver` for `AppLifecycleState.paused`. |

## Failure behavior

- `load()` never throws: a failing read returns `false` and leaves the
  cell at its current value.
- `persistNow()` propagates adapter errors to the caller.

## Restoration vs persistence

- **Restoration** (`RestorableCell` + `CellRestorationScope`) survives
  the OS killing the app in the background.
- **Persistence** (`PersistedCell`) survives the user swiping the app
  away.

`persistedState` composes both: the inner cell is a `RestorableCell` —
register it with a scope, and the value survives *both* mechanisms.
