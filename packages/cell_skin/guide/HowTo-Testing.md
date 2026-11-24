# HowTo-Testing

The suite is contract-first: wire round-trips, the two code-review
regression suites, cursor semantics, egress receipt pairing, REST
conformance over real sockets, SSE cleanup, idempotent retry, and one
in-process acceptance test that replays membrane-driven applies into a
fresh graph with zero divergences.

## The fixture

`test/skin_fixture.dart` builds the whole stack — graph, ledger,
binding table, membrane, client — in one call:

```dart
final f = await SkinFixture.build(
  whitelist: SkinWhitelist({
    'home.living.thermostat': {'setTarget'},
  }),
  extraBindings: (targets) => [
    SkinBinding(
      cellId: 'home.living.thermostat',
      functionName: 'countOnce',
      target: targets.thermostat.cell,
      function: () { calls++; return true; },
    ),
  ],
  onPolicyWarning: warnings.add,
);

final outcome = await f.run(() => f.client.apply(...));
await f.settle(); // let the router and ledger tail drain
```

`f.run` (the graph's `graph.run`) is the right wrapper for **in-process
multi-apply tests**: several applies share one ledger scope, and the
router will not open a second one. **REST ledger tests must not wrap the
HTTP handler in `f.run`** — that would pass for the wrong reason. With a
bound ledger the router opens the scope around each target apply itself,
which is exactly what those tests assert (`test/ledger_scope_test.dart`).

Remember: the binding table **seals at open** — custom bindings must
be registered through `extraBindings`, never after `build()` returns.

## What each suite locks in

| File | Contract |
| :--- | :--- |
| `wire_message_test.dart` | Wire taxonomy, JSON round-trips, `FormatException` on malformed input. |
| `wire_schema_test.dart` | Widening schema rules (type-only, required intersection, number union, all-element arrays). |
| `binding_table_test.dart` | Duplicate rejection, sealing. |
| `egress_cell_test.dart` | **The receipt contract**: ledgered changes pair with their own receipt; unledgered ones are `pendingReceipt`. |
| `cursor_test.dart` | missing / ahead / stale / fresh cursors. |
| `code_review_test.dart`, `code_review_grok_test.dart` | The findings of both external reviews, as regressions. |
| `rest_conformance_test.dart` | Real-socket REST: auth, methods, content-type, origin, bodies, error statuses. |
| `replay_integration_test.dart` | Membrane-driven applies replay into a fresh graph — zero divergences. |
| `api_chooser_up_to_date_test.dart` | The generated AI decision matrix cannot drift. |

## Testing egress receipts

The H1 pattern — never borrow an earlier receipt:

```dart
final changes = <WireStateChange>[];
final subscription = f.membrane.responses.listen((pulse) {
  if (pulse.payload is WireStateChange) {
    changes.add(pulse.payload as WireStateChange);
  }
});
await f.run(() => f.client.apply(
    'home.living.thermostat', 'setTarget', positional: [20]));
await f.settle();
await f.run(() => f.client.apply(
    'home.living.thermostat', 'setTarget', positional: [21]));
await f.settle();

expect(changes.last.receipt!.id,
    isNot(changes[changes.length - 2].receipt!.id));
```

## Testing REST over real sockets

```dart
final adapter = await RestAdapter.bind(
  membrane: f.membrane,
  auth: const AllowAllSkinAuth(),
  keepAliveInterval: const Duration(milliseconds: 50), // fast SSE cleanup
);
final http = HttpClient();
final request = await http.postUrl(
    Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
request.headers.contentType = ContentType.json;
request.write(jsonEncode({...}));
final response = await request.close();
// assert status codes and bodies; http.close(force: true) to drop SSE
```

The SSE test asserts a live frame arrives and
`adapter.activeSubscriptions` returns to 0 after the client drops.

## The replay acceptance test

The strongest test in the suite: run commands through the membrane,
then replay the ledger into a fresh graph and assert **zero
divergences**. That is the whole point of the framework — the skin
must not break it.

## Keeping the generated files fresh

```bash
python tool/generate_test_verification.py --run-tests  # TEST_VERIFICATION.md
dart run tool/generate_api_chooser.dart                # lib/doc/api_chooser.dart + skill matrix
```

## See also

- `TEST_VERIFICATION.md` — the generated inventory.
- `HowTo-Start.md` — the five-minute path the fixture reproduces.
- `DEMO_GUIDE.md` — the living demo's own widget tests
  (`example/test/`).
