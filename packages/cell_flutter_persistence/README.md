# cell_flutter_persistence

Persistence adapters for [`cell_flutter`](https://pub.dev/packages/cell_flutter):
durable state backed by SharedPreferences or custom backends.

## What it provides

- `CellPersistenceAdapter<T>` — the adapter contract (read / write / remove).
- `SharedPreferencesAdapter<T>` — SharedPreferences-backed adapter with
  primitive and JSON codecs (`SharedPreferencesAdapter.string`,
  `.integer`, `.json`, …).
- `InMemoryAdapter<T>` — deterministic, test-friendly adapter.
- `PersistedCell<T>` / `persistedState` — a restorable state cell that
  hydrates from the adapter on `load()` and writes changes back in
  immediate, debounced, or on-app-pause modes.

## Install

```yaml
dependencies:
  cell: ^2.0.0
  cell_flutter: ^1.0.0
  cell_flutter_persistence: ^0.1.0
```

## Quick start

```dart
import 'package:cell_flutter_persistence/cell_flutter_persistence.dart';

final counter = persistedState<int>(
  restorationId: 'counter',
  initial: 0,
  adapter: SharedPreferencesAdapter.integer(prefs),
);

// In initState:
CellRestorationScope.maybeOf(context)?.register(counter.cell);
counter.load(); // async; the cell updates when the read completes.

// Everywhere else:
counter.cell.value = 5; // restored + persisted (per writeMode)
```

`WriteMode.immediate` writes every change; `WriteMode.debounced` (default,
1s) writes after a quiet period and coalesces bursts;
`WriteMode.onAppPause` writes when `handleAppPaused` is called from a
`WidgetsBindingObserver`.

See `test/` for the full contract coverage and the package
[CHANGELOG.md](https://github.com/simon-m-lee/cell/tree/master/packages/cell_flutter_persistence/CHANGELOG.md)
for release history.
