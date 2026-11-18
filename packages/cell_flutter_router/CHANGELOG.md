# Changelog

## 0.1.1

pub.dev scoring pass — no public API changes.

- **Example** — added `example/` with a runnable `lib/main.dart`
  (location mirror + go_router navigation), so pub.dev's "package has
  an example" check passes.
- **`go_router` constraint** widened to `'>=14.0.0 <19.0.0'` so the
  latest `18.x` release is supported; the full suite passes against
  `go_router` `18.1.4`.

## 0.1.0

- Initial release: CellRouterState, CellRouterStateMirror,
  CellRouterScope, CellRouterController / useCellRouter, and the
  restorable routerState() factory over go_router.
