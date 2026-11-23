# HowTo-Whitelist

A `SkinWhitelist` shrinks the wire surface below "every registered
binding". It is the declarative exposure policy over the binding table.

## When to use

- The graph has more bindings than the wire may show: apply, egress,
  `/skin/observe/:cellId`, and `/skin/ledger` all respect the
  whitelist.
- You want one policy object that the membrane and both adapters read,
  instead of scattered checks.

## When not to use

- Creating exposure. The whitelist can only narrow; a function that is
  not bound does not exist on the wire no matter what the whitelist
  says.

## Basic usage

```dart
final whitelist = SkinWhitelist({
  'home.living.thermostat': {'setTarget'},
  'home.living.light': {'optimize'},
});

final membrane = await SkinMembrane.open(
  graph: graph,
  bindings: bindings,
  whitelist: whitelist,
  journal: RecordingJournal(),
  send: (_) {},
);

membrane.isExposed('home.living.thermostat'); // true
membrane.isExposed('home.front.door');       // false — bound but not whitelisted
```

## What the whitelist covers

| Surface | Behaviour without whitelist entry |
| :--- | :--- |
| `POST /skin/apply` | `WireError{code: 'unknown_tool'}` — the tool does not exist. |
| `skin.egress.<cellId>` | Not emitted for the cell. |
| `GET /skin/observe/:cellId` | 404 `unknown_tool`. |
| `GET /skin/ledger` | Entries for the cell are omitted. |

## Policy warnings

Entries with no matching binding are likely typos. The membrane reports
them at open time:

```dart
final membrane = await SkinMembrane.open(
  graph: graph,
  bindings: bindings,
  whitelist: whitelist,
  journal: RecordingJournal(),
  send: (_) {},
  onPolicyWarning: print,
);
// whitelist entry "home.front.door.explodeTypo" has no registered binding
```

## In-process vs transport

The in-process `membrane.responses` stream keeps the **full** stream —
callers in the same process are in the same trust domain. The REST
endpoints are the hostile boundary and enforce the whitelist there.
Keep anything unexposed out of the whitelist, and it never reaches a
remote caller.

## See also

- `HowTo-Bindings.md` — the registry the policy narrows.
- `HowTo-Egress.md` — what whitelisted-off cells do (and don't) emit.
- `ARCHITECTURE-Skin.md` §5 (the two gates).
