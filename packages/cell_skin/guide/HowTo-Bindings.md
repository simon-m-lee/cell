# HowTo-Bindings

A `SkinBinding` is one exposed function on one target cell: the
`(cellId, functionName)` pair a `WireRequest` may address. The
`SkinBindingTable` is the whole exposure registry.

## When to use

- Declaring what may cross the skin — the table is the only exposure
  mechanism; an unbound function simply does not exist on the wire.
- Giving tools descriptions and argument schemas for MCP `tools/list`
  and REST discovery.

## When not to use

- Declaring graph behaviour. Gates belong to the cell's `TestCell`;
  the binding only routes the command.

## Basic usage

```dart
final bindings = SkinBindingTable()
  ..register(SkinBinding(
    cellId: 'home.living.thermostat',
    functionName: 'setTarget',
    target: thermostat.cell,
    function: (int target) => thermostat.update(target),
  ));
```

## Target identity

At `SkinMembrane.open`, every binding's `target` must be `identical` to
the graph's registered cell:

```dart
final graph = (CellGraph.builder(graphId: 'home')
      ..register('home.living.thermostat', thermostat.cell))
    .build();
// ✓ binding.target is graph['home.living.thermostat']
// ✗ a different StateHandle's cell throws StateError at open()
```

## Descriptions

```dart
SkinBinding(
  cellId: 'home.living.thermostat',
  functionName: 'setTarget',
  description: 'Sets the target temperature in degrees Celsius.',
  target: thermostat.cell,
  function: (int target) => thermostat.update(target),
)
```

The manifest uses `function.description`, falling back to the cell's
description — so two tools on one cell stay distinguishable in
`tools/list`.

## Argument schemas

An explicit hint wins; observation of the live cell value fills in the
rest; the permissive `{}` schema is the last resort:

```dart
SkinBinding(
  cellId: 'home.living.thermostat',
  functionName: 'setTarget',
  argumentSchema: const JsonSchema(type: 'object', properties: {
    '0': JsonSchema(type: 'integer'),
  }, required: ['0']),
  target: thermostat.cell,
  function: (int target) => thermostat.update(target),
)
```

Malformed envelopes and schema violations are rejected **before**
`target.apply` runs, as `WireError{code: 'bad_arguments'}` — no receipt,
no ledger entry. See `HowTo-WireMessages.md` for the argument envelope
rules.

## Compensation

The compensation closure receives the **same wire arguments** as the
command, so it knows what to undo:

```dart
SkinBinding(
  cellId: 'home.living.thermostat',
  functionName: 'setTarget',
  target: thermostat.cell,
  function: (int target) => thermostat.update(target),
  compensation: (int target) =>
      thermostat.update((thermostat.cell.value ?? 20) - 1),
)
```

## Sealing and duplicates

- Duplicate `(cellId, functionName)` registrations throw `StateError`.
- `SkinMembrane.open` **seals** the table: any later registration
  throws, and the manifest/egress set can never diverge from what was
  registered.

```dart
final bindings = SkinBindingTable()
  ..register(...);

final membrane = await SkinMembrane.open(
  graph: graph,
  bindings: bindings,
  journal: RecordingJournal(),
  send: (_) {},
);

bindings.register(...); // throws StateError — the table is sealed
```

## See also

- `HowTo-Whitelist.md` — policy over the table.
- `HowTo-Cursors.md` — `strictCursor` bindings.
- `HowTo-WireMessages.md` — the request envelope and error codes.
- `ARCHITECTURE-Skin.md` §2 and §5.
