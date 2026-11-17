# cell_flutter_lints

Custom lint rules that guard the anti-patterns the `cell_flutter`
documentation warns about. Powered by `custom_lint`; 0.1.0.

## Usage

```yaml
# pubspec.yaml
dev_dependencies:
  cell_flutter_lints: ^0.1.0
  custom_lint: ^0.8.0
```

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

## The four rules

### `cell_avoid_creation_in_build`

Do not create a cell inside `build` — move it to `initState`, a `State`
field, or a top-level `final`. Creating a cell in `build` resets its
state on every rebuild and breaks hot reload.

**Before:**

```dart
Widget build(BuildContext context) {
  final counter = Cell.state<int>(initial: 0); // lint
  return CellBuilder<int>(
    cell: counter.cell,
    builder: (_, v) => Text('$v'),
  );
}
```

**After:**

```dart
final counter = Cell.state<int>(initial: 0); // State field

Widget build(BuildContext context) {
  return CellBuilder<int>(
    cell: counter.cell,
    builder: (_, v) => Text('$v'),
  );
}
```

Covers `Cell.state`, `Cell.ingress`, `Cell.derive`, `Cell.governed`,
`fromFuture`, `fromStream`, `asyncMap`, `switchMap` — in `build`
methods and in `HookBuilder` / `CellBuilder` `builder:` closures.

### `cell_unkeyed_hook_builder`

A `HookBuilder` that observes a swappable cell (a widget field) through
a `useCell*` hook must be keyed on the cell, or hook state flashes the
previous cell's value for one frame.

**Before:**

```dart
HookBuilder(
  builder: (context) {          // lint
    final value = useCell<int, int>(cell: widget.cell, select: (v) => v ?? 0);
    ...
  },
)
```

**After:**

```dart
HookBuilder(
  key: ValueKey(widget.cell),
  builder: (context) {
    final value = useCell<int, int>(cell: widget.cell, select: (v) => v ?? 0);
    ...
  },
)
```

Restricted by design to the widget-field case; locals are not flagged.

### `cell_forgotten_dispose`

`asValueCell()` / `recordPulses()` return observation links that must be
released. Fields holding them need a `dispose` / `stop` call in the
enclosing class's `dispose` method.

**Before:**

```dart
late final mirror = source.asValueCell<int>(); // lint — never released
```

**After:**

```dart
late final mirror = source.asValueCell<int>();

@override
void dispose() {
  mirror.dispose();
  super.dispose();
}
```

Structural check: false negatives are acceptable, false positives are
not. `HookWidget` `useEffect` cleanups are not analyzed (documented
limitation).

### `cell_collection_selector_without_equals`

`CellSelector<T, S>` / `useCell<T, S>` whose slice `S` is a collection
and which has no `equals` rebuilds on every emission even when the
content is equal.

**Before:**

```dart
CellSelector<String, List<String>>(        // lint
  cell: source,
  select: (v) => (v ?? '').split(' '),
  builder: (context, parts) => Text('$parts'),
)
```

**After:**

```dart
CellSelector<String, List<String>>(
  cell: source,
  select: (v) => (v ?? '').split(' '),
  equals: listEquals,
  builder: (context, parts) => Text('$parts'),
)
```

Covers `List`, `Set`, `Map`, `Iterable`, and `Collection` slices.

## Testing

`dart test` runs the custom_lint CLI over `example/lib`; every
`// expect_lint:` comment in the fixtures is verified by the client
(an unmet expectation is an ERROR). The fixture matrix covers, per
rule: fires on the anti-pattern, does not fire on the correct pattern,
does not fire on unrelated code, honors `// ignore:`, generics, nested
widgets, async closures, and null-safe types.
