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
  ..register(SkinBinding.state(
    cellId: 'home.living.thermostat',
    functionName: 'setTarget',
    target: thermostat.cell,
    nextValue: (int target) => target,
  ));
```

## The three binding kinds

| Constructor | The user function returns | Ledger rows |
| :--- | :--- | :--- |
| `SkinBinding.state` | the next value (`int`, `String`, …) — or a `Future` of it, or a `Pulse` | One row. The binding wraps the value in a `Pulse` and routes it through the target receptor; the wire receipt id is the row's receipt id. |
| `SkinBinding.command` | a JSON-safe result (`true`, a report) | Whatever the body applies itself (`Cell.txApply`, inner `apply`). The outer result is not a row; the response lists `ledgerSeqs`. |
| `SkinBinding(...)` | whatever it returns | Unchanged. A ledgered raw binding should return a `Pulse`; a binding that still calls `update()` writes a synthetic `_emit` row whose receipt id does not match the response, and strict receipts (`SkinMembrane.open(strictReceipts: true)`, the default) reports that contract break as `transport_error`. |

**For a ledgered state change, use `SkinBinding.state`.** The only write
is the pulse `apply` routes through the target receptor — the response
receipt and the ledger row share one id, and the wire receipt carries the
row's `ledgerSeq`/`pulseDigest`. `update()` inside the function would
write a second, synthetic receipt; do not call it there.

A state binding with **named** wire arguments is refused with
`bad_arguments` — there is no generic named wrapper (Dart has no
variadic closures), and letting it through would silently drop the
return-value wrapping. An empty `named: {}` is treated as absent.
Positional wire calls are wrapped for up to 12 arguments.

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
SkinBinding.state(
  cellId: 'home.living.thermostat',
  functionName: 'setTarget',
  description: 'Sets the target temperature in degrees Celsius.',
  target: thermostat.cell,
  nextValue: (int target) => target,
)
```

The manifest uses `function.description`, falling back to the cell's
description — so two tools on one cell stay distinguishable in
`tools/list`.

## Argument schemas

An explicit hint wins; observation of the live cell value fills in the
rest; the permissive `{}` schema is the last resort. An **explicit**
schema is enforced before `apply`: `required`, `enum`,
`additionalProperties` (a schema with `properties` is closed by default
— `additionalProperties: true` opens it), nested objects, `items`, and
typed `null` (a typed property never accepts `null`). Observed schemas
are hints and are never enforced.

The `"0"` index style needs no zipper:

```dart
SkinBinding.state(
  cellId: 'home.living.thermostat',
  functionName: 'setTarget',
  argumentSchema: const JsonSchema(type: 'object', properties: {
    '0': JsonSchema(type: 'integer'),
  }, required: ['0']),
  target: thermostat.cell,
  nextValue: (int target) => target,
)
```

A schema that names real properties (`target`) is matched against named
arguments directly; a **positional** call against it needs
`positionalNames` — the zipper maps position `i` to that property:

```dart
SkinBinding.state(
  cellId: 'home.living.thermostat',
  functionName: 'setTarget',
  argumentSchema: const JsonSchema(
    type: 'object',
    properties: {'target': JsonSchema(type: 'integer')},
    required: ['target'],
  ),
  positionalNames: ['target'], // validates positional [19] as target: 19
  target: thermostat.cell,
  nextValue: (int target) => target,
)
```

`positionalNames` is validation only: the Dart call still receives the
positional list. A positional call against a non-index schema without
the list is `bad_arguments`; a missing name that is `required` fails
`required`; more values than names is `bad_arguments`.

Malformed envelopes and schema violations are rejected **before**
`target.apply` runs, as `WireError{code: 'bad_arguments'}` — no receipt,
no ledger entry, and the domain gate is not reached. A wrong arity
(no schema) is `bad_arguments` too; a throw from inside the function
stays `transport_error`. See `HowTo-WireMessages.md` for the argument
envelope rules.

## Compensation

The compensation closure receives the **same wire arguments** as the
command, so it knows what to undo:

```dart
SkinBinding.state(
  cellId: 'home.living.thermostat',
  functionName: 'setTarget',
  target: thermostat.cell,
  nextValue: (int target) => target,
  compensation: (int target) => thermostat.cell.value ?? 20,
)
```

A state binding's compensation is wrapped the same way: an undo that
returns the restored value becomes one pulse on `compensationCell` (or
the target).

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
