# HowTo-Debugging

`cell_flutter` ships three debug-mode diagnostics. All are `kDebugMode`
-gated; release builds carry zero overhead.

## The three debug diagnostics

### 1. `CellBuilder` hot-reload warning

> CellBuilder: the cell identity changed N times in a row. This usually
> means the cell is created in build() …

**Fix:** move `Cell.state` / `Cell.ingress` to `initState`, a `State`
field, or a top-level `final`. See `HowTo-HotReload.md`.

### 2. `CellScope` nested-scope shadow warning

> CellScope: #counter is registered in a nested scope and shadows the
> outer registration. This is usually a bug. …

**Fix:** rename one of the symbols, or make the shadowing intentional and
ignore the (one-time) message. It is emitted once per symbol per debug
session.

### 3. `CellSelector` collection-without-`equals` assert

> CellSelector: select returned a collection (…) but equals is null. …

**Fix:** pass `equals: listEquals` / `setEquals` / `mapEquals`. The rare
intentional case (identity equality is meaningful) uses
`equals: (_, _) => false`.

## How to see them

The warnings print through `debugPrint` — the Flutter debug console and
DevTools logging view. The `CellSelector` assert surfaces through the
Flutter error widget in debug builds.

## How to silence them

Fix the pattern — don't suppress the diagnostic. The warnings describe
real problems (hot-reload breakage, accidental shadowing, guaranteed
over-rebuilds). Suppressing them leaves the problem in the code.

## What is *not* a debug diagnostic

`cell_flutter` deliberately ships no "state-transition assert" for
`CellAsyncBuilder` or similar placeholder checks. A debug assert that
cannot fail is worse than no assert. The three diagnostics above can all
fail on real code; if you expected a diagnostic that is not listed here,
the behavior it would have caught is either documented elsewhere (see the
per-source error table in `HowTo-CellAsyncBuilder.md`) or belongs to
`cell` core.

## See also

- `HowTo-HotReload.md` — the cell lifecycle contract.
- `HowTo-CellSelector.md` — the collection `equals` pattern.
- `HowTo-CellScope.md` — nested scope semantics.
