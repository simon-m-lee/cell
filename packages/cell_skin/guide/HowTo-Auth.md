# HowTo-Auth

Remote identity travels as provenance. `SkinAuth` checks credentials;
`ContextBridge` turns the principal into a framework `Context`;
`RestAdapter` stamps every request with it — so the domain's own
`TestCell` gates can see *who* called.

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
    return SkinPrincipal(
      id: credentials.metadata['userAgent'] ?? 'unknown',
      roles: const ['operator'],
      claims: const {'region': 'eu'},
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
the bearer string.

## Anonymous is an explicit opt-in

```dart
RestAdapter.bind(
  membrane: membrane,
  auth: const AllowAllSkinAuth(), // loopback demo / tests only
);
```

There is no unauthenticated default: `auth` is a required parameter.

## Provenance end to end

The adapter stamps every request:

```dart
PulseContext(
  baseContext: bridge.resolve(principal), // DescribeContextBridge by default
  actor: 'skin:${principal.id}',
  reason: 'rest apply home.living.thermostat.setTarget',
)
```

and the membrane emits through `Pulse.governed` — the context rides
the pulse into `target.apply`, where the domain's `TestCell` can
inspect it.

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

## In-process provenance

`SkinMembrane.request` takes a `PulseContext` directly:

```dart
await membrane.request(
  request,
  type: SkinPulseTypes.restApplyRequest,
  context: PulseContext(actor: 'alice', reason: 'evening setback'),
);
```

The response pulse carries the same context — testable with the public
`PulseContext.actor` / `reason` accessors.

## See also

- `HowTo-RestAdapter.md` — the 401/`WWW-Authenticate` contract.
- `HowTo-Membrane.md` — the default inbound context.
- `ARCHITECTURE-Skin.md` §5 (provenance), `FEATURES-Skin.md` §13.
