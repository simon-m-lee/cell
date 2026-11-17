# Migrating from setState

## What this guide covers

The smallest possible first step: moving one screen's local state out
of `setState` and into a `Cell.state`. Five minutes of work, no
architecture, and a working base to grow into the full binding.

## The mental model shift

| setState | cell_flutter |
|---|---|
| `int _count = 0;` | `final _count = Cell.state<int>(initial: 0);` |
| `setState(() => _count++);` | `_count.update((v) => (v ?? 0) + 1);` |
| `Text('count: $_count')` | `CellBuilder<int>(cell: _count.cell, builder: (_, v) => Text('count: ${v ?? 0}'))` |

## The worked migration

**Before:**

```dart
class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});
  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => setState(() => _count++),
          child: Text('count: $_count'),
        ),
      ),
    );
  }
}
```

**After:**

```dart
class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});
  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  final _count = Cell.state<int>(initial: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CellBuilder<int>(
          cell: _count.cell,
          builder: (context, value) => TextButton(
            onPressed: () => _count.update((value ?? 0) + 1),
            child: Text('count: ${value ?? 0}'),
          ),
        ),
      ),
    );
  }
}
```

## Why this is already better

- Only the parts of the tree that read `_count` rebuild — no
  whole-screen `setState`.
- The state is a first-class object: it can be passed down as a
  read-only `Cell` (`_count.cell`), derived from, listened to, and
  asserted on with `recordPulses`.
- The cell outlives this screen if you move it — the migration to the
  other guides' patterns is now mechanical.

## What you can keep

- `StatefulWidget`/`State` — cells are fields on the state, exactly
  where `setState` fields lived.
- One `Cell.state` per mutable value; `late final` keeps the pattern
  readable.

## What you must replace

- `setState` calls that mutate a value → `handle.update(...)`.
- Reads inside `build` → `CellBuilder` (or `CellSelector` for derived
  slices).
- Field access from callbacks → read the builder's `value` parameter.

## Migration checklist

- [ ] Replace each mutable field with a `Cell.state` handle.
- [ ] Replace each `setState(() => ...)` with `handle.update(...)`.
- [ ] Wrap each read with `CellBuilder`.
- [ ] Delete now-empty `setState` calls.
- [ ] Run the existing widget test — behavior must be unchanged.

## What comes next

- [Migrating from Provider](Migrating-From-Provider.md) — the next step
  up: containers and consumers.
- `guide/HowTo-Start.md` — the full tour of the widget surface.
