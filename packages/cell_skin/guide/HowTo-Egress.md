# HowTo-Egress

Egress is how state changes leave the skin: `skin.egress.<cellId>`
pulses carrying `WireStateChange`. It is an observation — **not a
reply** — with no correlation id, so it can never complete a pending
`request()`.

## When to use

- Streaming target state to observers: SSE
  `/skin/observe/:cellId`, MCP notifications, `SkinClient.observe`.
- Pairing a state change with its own ledger receipt for audit-grade
  clients.

## Ledgered membranes — the entry's own receipt

With a bound ledger, egress is driven by `Ledger.tail` itself:

```dart
final ledger = await graph.bindLedger(
  store: InMemoryLedgerStore(
    genesisHash: Ledger.genesisHashOf(graph.id),
  ),
);
final membrane = await SkinMembrane.open(
  graph: graph,
  bindings: bindings,
  ledger: ledger,
  journal: RecordingJournal(),
  send: (_) {},
);

final client = SkinClient(membrane: membrane);
await client.apply('home.living.thermostat', 'setTarget', positional: [21]);

client.observe().listen((change) {
  change.cellId;        // 'home.living.thermostat'
  change.payload;       // 21
  change.pendingReceipt; // false — the entry landed with its receipt
  change.receipt;       // that entry's own receipt, never an earlier one
});
```

Each `WireStateChange` is built from one ledger entry: the entry's own
receipt pairs with the entry's own pulse payload (from its canonical
stored JSON). Two sequential changes carry **different** receipt ids.

## Unledgered membranes — honest pending

Without a ledger, targets are observed directly and every change is
`pendingReceipt: true` — there is no receipt to attach, so none is
fabricated:

```dart
final membrane = await SkinMembrane.open(
  graph: graph,
  bindings: bindings,   // no ledger
  journal: RecordingJournal(),
  send: (_) {},
);
```

## Exposure

Egress is only emitted for exposed cells — binding table plus
whitelist. A bound-but-not-whitelisted cell changes state silently on
the wire (and `/skin/observe/:cellId` answers 404).

## Ledger entries are a separate stream

`skin.ledger.entry` (`WireLedgerEntry`) carries the audit rows
themselves — every mutation, in order, with the framework's own
`LedgerEntry.toJson` encoding. Denials write no entry; the rejection
travels as the apply outcome instead.

## See also

- `HowTo-RestAdapter.md` — SSE observe/ledger endpoints.
- `HowTo-Whitelist.md` — which cells emit egress.
- `ARCHITECTURE-Skin.md` §4 (receipt provenance).
