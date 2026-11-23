# HowTo-McpSeam

cell_skin deliberately does **not** speak the MCP transport. It ships
an honest seam: `mcpToolSpecs(manifest)` translates the tool catalogue
into neutral, transport-agnostic specs, and `McpAdapter` is the
lifecycle contract your SDK adapter implements.

## When to use

- Wiring the skin's tools into an MCP SDK (`dart_mcp`, `mcp_dart`, or
  a custom host).
- Keeping `tools/list` output in sync with the binding table for free.

## When not to use

- Expecting `cell_skin` to serve MCP over stdio/SSE itself — it does
  not; that is the SDK adapter's job.

## Tool specs

```dart
import 'package:cell_skin/cell_skin.dart';

final specs = mcpToolSpecs(membrane.manifest);
for (final spec in specs) {
  print('${spec.name}: ${spec.description}');
}
```

Each `McpToolSpec` maps 1:1 onto an SDK's tool descriptor:

```dart
final tool = Tool(
  name: spec.name,              // '<cellId>.<functionName>'
  description: spec.description, // function.description ?? cell description
  inputSchema: spec.inputSchema.toJson(), // explicit hint → observed → {}
);
```

## Naming guarantees

Tool names are `<cellId>.<functionName>` with hard validation:

- Cell ids and function names must be **dot-free** — the separator
  cannot be ambiguous.
- The combined names are checked for collisions
  (`a.b` + `c` vs `a` + `b.c` cannot silently alias).

Violations throw `StateError` at translation time — a collision can
never reach an MCP host.

## The adapter lifecycle

```dart
final class MyMcpServer implements McpAdapter {
  @override
  Future<void> start() async {
    // register tools from mcpToolSpecs(membrane.manifest),
    // subscribe membrane.responses for notifications, start transport
  }

  @override
  Future<void> close() async {
    // stop transport, release subscriptions
  }
}
```

Inbound MCP tool calls become `WireRequest`s (one per
`<cellId>.<functionName>`); outbound state changes and ledger entries
become MCP notifications. Egress `WireStateChange` pulses are the
natural notification payload — observations, never replies.

## See also

- `HowTo-Bindings.md` — descriptions and schemas that feed the specs.
- `HowTo-WireMessages.md` — the messages an SDK adapter maps.
- `FEATURES-Skin.md` §11.
