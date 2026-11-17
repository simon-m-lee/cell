# HowTo: Routing with `cell_flutter_router`

`cell_flutter_router` is a thin bridge over `go_router`: your existing
`GoRouter` configuration keeps working unchanged, and the current route
becomes a reactive cell.

## Setup

```yaml
dependencies:
  cell_flutter: ^1.0.0
  cell_flutter_router: ^0.1.0
```

```dart
import 'package:cell_flutter_router/cell_flutter_router.dart';
// For the hook + routerState factory:
import 'package:cell_flutter_router/hooks.dart';
```

## The three pieces

```dart
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
    GoRoute(path: '/detail/:id', builder: (c, s) => DetailScreen(id: s.pathParameters['id']!)),
  ],
);

// 1. A restorable cell that holds the current route.
final routerState = routerState(restorationId: 'router');

runApp(
  CellRouterStateMirror(
    router: router,
    stateCell: routerState,
    child: CellRouterScope(
      router: router,
      stateCell: routerState,
      child: MaterialApp.router(routerConfig: router),
    ),
  ),
);
```

- **`CellRouterStateMirror`** listens to the router (information
  provider + delegate) and writes the current `CellRouterState`
  (location, query parameters, extra) into `stateCell` on every route
  change — including `go`, `push`, `replace`, `pop`, and deep links.
  Imperative navigations use the top match's location, because
  `go_router` keeps the base uri in the configuration for pushes.
- **`CellRouterScope`** provides the router and the state cell to
  descendants.
- **`useCellRouter()`** returns a reactive `CellRouterController`
  (`go` / `push` / `replace` / `pop`) that rebuilds the calling hook
  whenever the route changes:

```dart
class DetailButton extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final router = useCellRouter();
    return TextButton(
      onPressed: () => router.go('/detail/42'),
      child: const Text('Open detail'),
    );
  }
}
```

## Reacting to route changes without hooks

The state cell is an ordinary cell — `CellBuilder`,
`CellSelector`, and `CellListener` all work:

```dart
CellBuilder<CellRouterState>(
  cell: routerState,
  builder: (context, state) => Text(state?.location ?? '/'),
)
```

## Restoration

`routerState(...)` is a `RestorableCell` with JSON codecs (location +
query parameters; `extra` is deliberately **not** persisted — extras
are live objects). Register it with a `CellRestorationScope` (see
`guide/HowTo-Restoration.md`) and the route survives process kill.

## Caveats

- `useCellRouter` throws `StateError` without a `CellRouterScope`.
- The mirror updates the cell on the frame after the navigation
  notification (it defers a second read past the provider-before-
  delegate ordering).
- Deep-link helpers (`go_router`'s named-route conveniences) are not
  wrapped; use the controller's `go`/`push`/`replace`/`pop`, which
  delegate one-to-one.
