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
  print('${spec.name}  (${spec.dottedName}): ${spec.description}');
}
```

Each `McpToolSpec` maps 1:1 onto an SDK's tool descriptor:

```dart
final tool = Tool(
  name: spec.name,               // the escaped MCP name — register this
  description: spec.description, // function.description ?? cell description
  inputSchema: spec.inputSchema.toJson(), // explicit hint → observed → {}
);
```

Register `spec.name` **once**. `spec.dottedName` travels as metadata
(`toJson()` includes it) — do not register it as a second tool, or the
model sees two tools for one binding.

## Naming

`spec.name` is the escaped wire name: every character outside
`[A-Za-z0-9_-]` becomes `_`. `home.living.thermostat` + `setTarget`
becomes `home_living_thermostat_setTarget`; `home/living room` +
`set target` becomes `home_living_room_set_target`. Underscores are
never collapsed, nothing is prefixed or truncated.

`spec.dottedName` is the raw binding name
(`home.living.thermostat.setTarget`). `resolveMcpToolCall(manifest,
toolName)` accepts **both** forms and returns the `cellId` +
`functionName` pair; any other string — including `''` — returns
`null`, and an unknown name never throws. A hidden binding is not a
spec and resolves to `null`.

The name table is collision-checked: two bindings whose `name` or
`dottedName` aliases collide (`a.b` + `c` vs `a` + `b.c`; `set.target`
vs `set target`) throw `StateError` at catalogue build, naming both
bindings. A name longer than 64 characters also throws — strict MCP
hosts drop longer names, and truncating would hide a collision.

## Unknown tool calls

When `resolveMcpToolCall` returns `null`, the SDK adapter returns a
**tool result** — not a JSON-RPC error — and does not call
`membrane.request`:

```dart
final call = resolveMcpToolCall(membrane.manifest, toolName);
if (call == null) {
  return mcpUnknownToolResult();
  // {isError: true, content: [{type: 'text', text: 'unknown_tool'}]}
}
```

The text is the code only; the caller's string is never echoed.

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

Inbound MCP tool calls become `WireRequest`s (one per resolved
`<cellId>.<functionName>`); outbound state changes and ledger entries
become MCP notifications. Egress `WireStateChange` pulses are the
natural notification payload — observations, never replies. Resource
URIs stay `cell://graph/<cellId>` with the raw id, dots included —
those are not tool names.

## See also

- `HowTo-Bindings.md` — descriptions and schemas that feed the specs.
- `HowTo-WireMessages.md` — the messages an SDK adapter maps.
- `FEATURES-Skin.md` §11.
