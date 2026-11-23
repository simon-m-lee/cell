# HowTo-Start

`cell_skin` puts a membrane between a [Cell](https://pub.dev/packages/cell)
graph and remote consumers — REST clients, MCP hosts, and Dart clients.
This guide gets you from a bare graph to your first apply in five steps.

## When to use

- A requirement says "expose the graph over REST", "stream ledger
  entries", "bind a tool for MCP", or "let remote callers apply
  commands".
- You already have a working `Cell` graph (gates, ledger, replay) and
  want a wire surface without touching it.

## When not to use

- Pure graph work — use `package:cell` directly.
- The decision layer — that is `cell_flow`.
- The books — that is `cell_tissue`.

## Step 1 — a graph

```dart
import 'package:cell/cell.dart';

final thermostat = Cell.state<int>(initial: 20);
final graph = (CellGraph.builder(graphId: 'home')
      ..register('home.living.thermostat', thermostat.cell))
    .build();
```

## Step 2 — a binding table

```dart
import 'package:cell_skin/cell_skin.dart';

final bindings = SkinBindingTable()
  ..register(SkinBinding(
    cellId: 'home.living.thermostat',
    functionName: 'setTarget',
    target: thermostat.cell,
    function: (int target) => thermostat.update(target),
  ));
```

The table is the whole exposure registry. Register everything
**before** opening the membrane — the table seals at `open()`.

## Step 3 — open the membrane

```dart
final membrane = await SkinMembrane.open(
  graph: graph,
  bindings: bindings,
  journal: RecordingJournal(),
  send: (_) {}, // your transport's writer (or a no-op for in-process use)
);
```

## Step 4 — drive it with a client

```dart
final client = SkinClient(membrane: membrane);

final outcome = await client.apply(
  'home.living.thermostat',
  'setTarget',
  positional: [21],
);
// ApplyAccepted(result: <the function's return value>)
print('${outcome.runtimeType} -> ${thermostat.cell.value}'); // 21
```

`SkinClient` is the in-process caller — the same one the Echo Home demo
uses for its scripted agent. No mocks.

## Step 5 — observe the state change

```dart
client.observe().listen((change) {
  print('${change.cellId} -> ${change.payload}');
});
await client.apply('home.living.thermostat', 'setTarget', positional: [22]);
// home.living.thermostat -> 22
```

Egress is `WireStateChange` — an observation, not a reply. With a bound
ledger it carries the ledger entry's own receipt.

## Where to go next

- `HowTo-Bindings.md` — descriptions, schemas, compensation, cursors.
- `HowTo-RestAdapter.md` — the HTTP surface (`cell_skin_rest.dart`).
- `HowTo-Auth.md` — principals and per-request provenance.
- `example/lib/mock/mock_home.dart` — the Echo Home membrane end to end.

## See also

- `ARCHITECTURE-Skin.md` — the four-cell pipeline and its invariants.
- `FEATURES-Skin.md` — the feature catalog.
- `DEMO_GUIDE.md` — the scripted demo walkthrough.
