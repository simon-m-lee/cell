# HowTo-Membrane

`SkinMembrane.open` assembles the four cells — inbound, router, egress,
outbound — over your graph. This guide covers the assembly, the
request/response API, and the lifecycle.

## When to use

- Every transport shares this one pipeline: REST, MCP, and Dart clients
  all sit behind the same membrane.
- You want the router's serialised dispatch (`concurrency: 1`), the
  sealed binding table, and ledger-driven egress without assembling
  them by hand.

## Basic usage

```dart
final membrane = await SkinMembrane.open(
  graph: graph,
  bindings: bindings,
  whitelist: whitelist,        // optional exposure policy
  ledger: ledger,              // optional — enables cursors + receipt pairing
  journal: RecordingJournal(),
  send: (pulse) => transport.write(pulse),
  descriptions: {'home.living.thermostat': 'Living-room thermostat'},
  onPolicyWarning: print,
);
```

What `open` does, in order: validates every binding's target against
the graph, builds the inbound ingress and the router (`Cell.asyncMap`,
`concurrency: 1`), builds egress (ledger-tail driven with a ledger,
target observers without one), **seals the binding table**, fans
everything into the mux, and starts the outbound observer.

## request — the correlated command

```dart
final message = await membrane.request(
  WireRequest(
    cellId: 'home.living.thermostat',
    function: 'setTarget',
    positional: {'0': 21},
    correlationId: 'srv-1',
  ),
  type: SkinPulseTypes.restApplyRequest,
  timeout: const Duration(seconds: 30),
);

switch (message) {
  case WireResponse response:
    print(response.outcome);
  case WireError error:
    print('${error.code}: ${error.message}');
}
```

Matching is on `WireRequest.correlationId` — a server-side id. A
`WireStateChange` can never complete the future (egress is not a
reply), and a `WireNotification` passed to `request` throws
`ArgumentError` immediately.

## Provenance

```dart
await membrane.request(
  request,
  type: SkinPulseTypes.restApplyRequest,
  context: PulseContext(actor: 'alice', reason: 'evening setback'),
);
```

The pulse travels through `Pulse.governed`. The router installs a
`SkinCall` zone around the target apply, so the domain's `TestCell`
reads the caller through `SkinCall.current` — the request context is
not visible inside `TestCell.action`. The recorded pulse carries the
actor when the binding returns a stamped pulse (`SkinBinding.state` or
`SkinPulses.payload`). The membrane's default inbound context is
least privilege (`skin:untrusted`) — never `Context.system`.

## responses — the broadcast

```dart
membrane.responses.listen((pulse) {
  // WireResponse (router replies), WireStateChange (egress),
  // WireLedgerEntry (audit), WireError (transport).
});
```

The in-process stream is the full stream (same trust domain); REST
endpoints apply the whitelist on top.

## close — the lifecycle

```dart
await membrane.close();
```

Idempotent and total: stops the outbound cell, every egress handle, the
ledger-tail subscription, and the event stream, and fails every pending
`request()` with `SkinError('closed')`. The graph and ledger remain
yours — the membrane never closes them.

## See also

- `HowTo-Bindings.md` — what `open` validates and seals.
- `HowTo-Egress.md` — the two egress modes.
- `HowTo-Auth.md` — provenance end to end.
- `ARCHITECTURE-Skin.md` §2 (the pipeline diagram).
