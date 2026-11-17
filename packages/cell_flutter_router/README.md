# cell_flutter_router

A `go_router` bridge for [`cell_flutter`](https://pub.dev/packages/cell_flutter):
route state exposed as a reactive cell.

## What it provides

- `CellRouterState` — the mirrored route state (`location`, `queryParams`,
  `extra`) with JSON-safe `toJson` / `fromJson`.
- `CellRouterStateMirror` — a widget that listens to a `GoRouter`'s
  delegate and writes the current route into a state cell on every
  navigation (go, push, replace, pop, deep links). It does not replace
  `go_router`'s delegate — your router configuration keeps working.
- `CellRouterScope` — an `InheritedWidget` that publishes the router and
  its state cell to the widget tree.
- `CellRouterController` / `useCellRouter` — reactive navigation
  (`go`, `push`, `replace`, `pop`) plus the current route state.
- `routerState(restorationId: …)` — a `RestorableCell` for the route
  state; pair it with a `CellRestorationScope` for process-kill
  restoration.

## Install

```yaml
dependencies:
  cell: ^2.0.0
  cell_flutter: ^1.0.0
  cell_flutter_router: ^0.1.0
```

## Quick start

```dart
import 'package:cell_flutter/cell_flutter.dart';
import 'package:cell_flutter_router/cell_flutter_router.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(routes: [
  GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
  GoRoute(path: '/user/:id', builder: (context, state) => const UserScreen()),
]);

final routerStateCell = routerState(restorationId: 'router');

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return CellRouterStateMirror(
      router: router,
      stateCell: routerStateCell,
      child: MaterialApp.router(routerConfig: router),
    );
  }
}

class LocationBar extends StatelessWidget {
  const LocationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return CellSelector<CellRouterState, String>(
      cell: routerStateCell,
      selector: (state) => state.location,
      builder: (context, location) => Text(location),
    );
  }
}
```

For hooks-based apps, wrap the subtree in a `CellRouterScope` (with the
same router and state cell) and call `useCellRouter()` to read the state
and navigate.

See `test/` for the full contract coverage and the package
[CHANGELOG.md](https://github.com/simon-m-lee/cell/tree/master/packages/cell_flutter_router/CHANGELOG.md)
for release history.
