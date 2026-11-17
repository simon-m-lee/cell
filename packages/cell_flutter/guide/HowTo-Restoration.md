# HowTo: State restoration with `cell_flutter`

State restoration makes a `cell_flutter` app survive process kill, hot
restart, and backgrounding: every value you mark restorable is persisted
through Flutter's `RestorationManager` and written back into its cell
before the first frame that depends on it.

## The three pieces

1. **`restorableState<V>(...)`** (or `CellRestoration.restorableState<V>`)
   creates a `RestorableCell<V>` — a `ValueCell` whose value is
   additionally serialized into a `RestorationBucket`.
2. **`CellRestorationScope`** claims the bucket and provides
   `register` / `unregister`.
3. **Your `State`** registers the cell in `initState` /
   `didChangeDependencies`.

## Minimal counter

```dart
class CounterApp extends StatefulWidget {
  const CounterApp({super.key});
  @override
  State<CounterApp> createState() => _CounterAppState();
}

class _CounterAppState extends State<CounterApp> {
  late final RestorableCell<int> counter;

  @override
  void initState() {
    super.initState();
    counter = restorableState<int>(restorationId: 'counter', initial: 0);
    // The scope above us has already claimed its bucket by the time this
    // initState runs, so registration is safe here.
    CellRestorationScope.maybeOf(context)?.register(counter);
  }

  @override
  Widget build(BuildContext context) {
    return CellBuilder<int>(
      cell: counter,
      builder: (_, v) => TextButton(
        onPressed: () => counter.value = (counter.value ?? 0) + 1,
        child: Text('$v'),
      ),
    );
  }
}

void main() {
  runApp(RootRestorationScope(
    restorationId: 'root',
    child: CellRestorationScope(
      restorationScopeId: 'app',
      child: const MaterialApp(home: CounterApp()),
    ),
  ));
}
```

## Serialization contract

By default only `bool`, `int`, `double`, `String`, and `null` persist —
the types Flutter's `StandardMessageCodec` represents without a codec.
Any other `V` throws `UnsupportedError` on serialization. Pass a codec
pair for custom types:

```dart
final user = restorableState<User>(
  restorationId: 'user',
  initial: User.anonymous(),
  toPrimitives: (u) => u?.name,
  fromPrimitives: (data) => data == null ? null : User(data as String),
);
```

## Rules

- **Register before build.** Registration writes the restored value into
  the cell (an emission); doing it from `build` can trip
  `setState`-during-build in observing widgets. `initState` and
  `didChangeDependencies` are safe.
- **Unique ids within a scope.** A duplicate `restorationId` throws
  `StateError` at registration.
- **Nested scopes restore independently.** Each `CellRestorationScope`
  claims its own child bucket; the nearest scope wins for registration.
- **Unregistering removes the persisted value** from the bucket;
  registering again works (e.g., for conditionally-relevant state).

## Testing restoration

Widget tests inject a `RestorationBucket` directly:

```dart
final bucket = RestorationBucket.root(
  manager: TestWidgetsFlutterBinding.instance.restorationManager,
  rawData: {
    'v': <Object?, Object?>{},
    'c': {
      'app': {
        'v': {'counter': 5},
        'c': <Object?, Object?>{},
      },
    },
  },
);
```

See `test/restoration/restorable_cell_test.dart` for the full matrix,
including the process-kill simulation (the restart pump uses a fresh key
so the tree remounts exactly as a real restart would).

## One placement rule that matters

Pushed routes are **siblings** of `home`, not children. A
`CellRestorationScope` placed around a single screen only covers that
screen's subtree — cells on pushed routes will not find it. Place the
scope above the `Navigator` (e.g. via `MaterialApp.builder`) so every
route registers against it:

```dart
MaterialApp(
  // The builder wraps the Navigator: every route is a descendant.
  builder: (context, child) => CellRestorationScope(
    restorationScopeId: 'app',
    child: child ?? const SizedBox.shrink(),
  ),
  home: const LoginScreen(),
);
```
