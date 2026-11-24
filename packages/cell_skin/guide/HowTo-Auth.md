# HowTo-Auth

Remote identity travels as provenance. `SkinAuth` checks credentials;
`ContextBridge` turns the principal into a framework `Context`;
`RestAdapter` stamps every request with the principal's actor and a
JSON snapshot. The domain gate reads the caller through the `SkinCall`
zone during `apply`, and the recorded pulse carries the actor into the
ledger.

## When to use

- A requirement says "authenticate REST callers", "per-principal
  context", or "bearer tokens".
- The domain gate must distinguish actors (the skin's default is the
  least-privileged `skin:untrusted`).

## When not to use

- Authorisation decisions. Authenticate, return a principal, and let
  the graph's gates decide — the skin never decides policy.

## Implement an auth

```dart
import 'package:cell_skin/cell_skin_rest.dart';

final class TokenAuth implements SkinAuth {
  @override
  Future<SkinPrincipal?> authenticate(SkinCredentials credentials) async {
    if (credentials.token != 'secret') return null; // → 401 + WWW-Authenticate
    // The principal id comes from the token lookup — never from a
    // client-controlled header like User-Agent.
    return const SkinPrincipal(
      id: 'tester',
      roles: ['operator'],
      claims: {'region': 'eu'},
    );
  }
}

final adapter = await RestAdapter.bind(
  membrane: membrane,
  auth: TokenAuth(),
);
```

`SkinCredentials` carries the token **plus transport metadata** —
peer address, host, user agent — so identity checks can use more than
the bearer string. Do not use that metadata as the principal id.

## Anonymous is an explicit opt-in

```dart
RestAdapter.bind(
  membrane: membrane,
  auth: const AllowAllSkinAuth(), // loopback demo / tests only
);
```

There is no unauthenticated default: `auth` is a required parameter.
Anonymous callers are stamped `actor: skin:anonymous`.

## The two real provenance paths

The request context on the wire pulse is **not** what a domain gate sees.
There are two separate paths:

### 1. The live gate — the `SkinCall` zone

The router installs a `SkinCall` zone around the target apply (inside
the ledger scope when it opens one). `TestCell.action` runs on the same
call stack as `apply`, so the gate reads the caller there — including
after an `await` inside the function body:

```dart
final class OwnerGate extends TestCell<Cell> {
  OwnerGate() : super((object, {host, arguments, user}) => true);

  @override
  FutureOr<bool> action(
    Function action, {
    required Cell host,
    Arguments? arguments,
    ApplyCommand? command,
  }) {
    final call = SkinCall.current;
    return call?.principal?.id == 'tester';
  }
}
```

`SkinCall.current?.principal` is the authenticated
`SkinPrincipal` (`id`, `roles`, `claims`); `SkinCall.current?.pulseContext`
is the request's `PulseContext` (`actor: skin:<id>`). Gates that do not
look at the zone do not become actor-aware by magic.

### 2. The stored pulse — the ledger row

`recordPulse` stores the pulse the binding returns. `SkinBinding.state`
and `SkinPulses.payload` stamp that pulse with the call's context, so the
row's `pulseJson['context']['lineage']` contains `actor: skin:<id>` and a
JSON snapshot of the principal (`others['skin.principal']` — id, roles,
and the claims JSON can encode; the bearer token is never copied).
Replay restores the thermostat value **and does not restore the zone**:
a gate that decides only by reading `SkinCall.current` sees `null` on
replay. Gates that must keep refusing on replay keep checking the value
(a `ValueGate`, a door gate on the pulse payload). The stored actor is
the audit record.

`update()` inside a raw binding still writes a row with no remote actor
— provenance for `update()` rows is not supported.

## Choose your bridge

| Bridge | Context |
| :--- | :--- |
| `DescribeContextBridge` (default) | `Context.describe('skin:<id> …')` — least privilege. |
| `SystemContextBridge` | `Context.system` — the **loud** opt-in to system authority. |

```dart
RestAdapter.bind(
  membrane: membrane,
  auth: auth,
  contextBridge: const SystemContextBridge(), // opt-in, deliberate
);
```

`SystemContextBridge` does not skip the domain gate: a refusing
`TestCell` still rejects the apply.

## Authorize with one hook

Authentication answered *who is calling*. `SkinAuthorizer` is the
application's one hook for *may this principal apply this binding* — it
is optional and default-allow:

```dart
Future<bool> operatorOnly(SkinPrincipal principal, SkinBinding binding) async {
  // Your rule. The skin never reads roles itself.
  return principal.roles.contains('operator');
}

await SkinMembrane.open(
  graph: graph,
  bindings: bindings,
  journal: RecordingJournal(),
  send: (_) {},
  authorizer: operatorOnly,
);
```

The hook runs after the binding was found and the whitelist allows it
(a hidden tool stays `unknown_tool` and never reaches the hook), and
before the domain gate. `false` is `forbidden` — HTTP 403 — the binding
does not run, the ledger does not move, and the denial is not cached,
so a later call by an allowed principal is a new apply. `true` does
**not** skip the domain gate: a refusing `TestCell` still rejects the
apply. A throw is `transport_error` with the runtime type only.

The hook receives the `SkinPrincipal` the transport authenticated — on
REST, the adapter stamps the token's principal onto the request
context; in-process, `SkinMembrane.request` and `SkinClient.apply` take
a `principal` and stamp the same snapshot. With no snapshot, the hook
still runs and may refuse `SkinPrincipal.anonymous()`.

A non-null hook also filters the read routes through
`SkinMembrane.mayRead`: `/skin/manifest` omits a cell whose bindings
are all denied, `/skin/observe/<cellId>` answers 403 `forbidden` for an
exposed but denied cell (a hidden cell stays 404 `unknown_tool`), and
`/skin/ledger` skips that cell's rows. A `null` hook reads everything
exposure allows. Read checks are not cached, so a role change takes
effect on the next read.

`/skin/verify` is gated by authentication and the whitelist's exposure
alone — the hook is not consulted for verify. An idempotency hit (same
actor, same body, within the store's TTL) replays the stored outcome
without running the hook again.

## In-process provenance

`SkinMembrane.request` takes a `PulseContext` directly:

```dart
await membrane.request(
  request,
  type: SkinPulseTypes.restApplyRequest,
  context: PulseContext(actor: 'alice', reason: 'evening setback'),
);
```

`SkinClient.apply` takes an optional `principal` and builds the same
request context through `skinPulseContext` when no context is supplied.

## See also

- `HowTo-RestAdapter.md` — the 401/`WWW-Authenticate` contract.
- `HowTo-Membrane.md` — the default inbound context.
- `ARCHITECTURE-Skin.md` §5 (provenance), `FEATURES-Skin.md` §13.
