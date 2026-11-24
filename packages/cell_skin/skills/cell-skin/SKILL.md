---
name: cell-skin
description: >-
  Choose the correct package:cell_skin API for exposing a Cell graph to
  remote consumers (REST, MCP, Dart clients) and generate code that
  compiles against the live API. Use when a requirement mentions
  exposing, binding, observing, streaming ledger entries, or
  authenticating remote callers over the skin membrane, or when deciding
  between SkinMembrane.open, SkinBinding, SkinClient, RestAdapter.bind,
  WireRequest, WireStateChange, and SkinAuth.
---

# Skin API chooser — package:cell_skin (Mitosis Skin layer)

Install: `dart run skills@ get cell_skin`

## Workflow

1. Map the requirement sentence to a first API with the table in
   `references/api_chooser.md`.
2. Read that row — the **When to use**, **When NOT to use**, and
   **Live signature** columns are generated from the
   `### AI Agent Guide` doc blocks in the package source and cannot
   drift from the code.
3. Copy the example named in the row and adapt it. Compile-check under
   `dart analyze` before finishing.
4. Verify the package version in the consumer's `pubspec.lock` matches
   the pin in the row (cell_skin 0.2.x). When working inside the
   repository itself, regenerate the chooser with
   `dart run tool/generate_api_chooser.dart` from `packages/cell_skin`
   and keep `test/api_chooser_up_to_date_test.dart` green.

## Hard rules

- Never invent a receipt. The skin forwards the domain's receipts,
  marks them pending, or withholds them — it never synthesises an
  `ApplyAccepted` the graph did not produce.
- Never forge authority. A domain gate that must see the caller reads
  `SkinCall.current` — the request `PulseContext` is not visible inside
  `TestCell.action`, and `SystemContextBridge` does not skip the gate.
- Egress is `WireStateChange`, never a reply: it carries no
  correlation id and can never complete a pending `request()`.
- `RestAdapter.bind` requires an explicit `auth:` — anonymous access
  is the deliberate `AllowAllSkinAuth` opt-in.
- Import `RestAdapter` from `package:cell_skin/cell_skin_rest.dart`;
  the main barrel stays `dart:io`-free for Flutter web.
- A binding's target must be the graph's registered cell; the binding
  table seals at `SkinMembrane.open` — register everything before
  opening.
- Rejections before `target.apply` (`unknown_tool`, `bad_arguments`,
  `cursor_required`, `conflict`, `forbidden`) are `WireError` without a
  receipt; `unknown_tool` is never `ApplyRejected`, and domain denials
  are `ApplyRejected` inside a `WireResponse`.
- The decision (cell_flow) and the books (cell_tissue) stay outside
  the skin; the skin only transports and enforces exposure.

## BRD sentence → first API

| BRD sentence | First API | Do NOT |
|---|---|---|
| "expose the graph over HTTP" | `RestAdapter.bind` | `SkinClient` for a cross-process caller |
| "call a binding from Dart" | `SkinClient.apply` | stand up `RestAdapter` |
| "the domain gate must see who called" | `SkinCall.current` | read the wire pulse inside `TestCell` |
| "retry the same attempt" | the caller's `correlationId` | a fresh server id, or a different body |
| "reject a bad argument before apply" | an explicit `argumentSchema` | an observed schema |
| "resume the audit stream" | `Last-Event-ID`, or `?since=` | subscribe after reading the store |
| "forbid this principal" | `SkinAuthorizer` | a role check inside `cell_skin` |
| "register the tool with an MCP host" | `McpToolSpec.name` | splitting the dotted id on `.` |

## Layer contract

The skin owns the membrane between a Cell graph and remote consumers:
binding exposure, the wire taxonomy, REST/SSE transport, the MCP seam,
authentication plumbing, and the authorizer hook. It does **not** own
graph nodes (cell), the decision (cell_flow), or the books (cell_tissue).

The seam sentence: *The graph decides, the membrane gates, the ledger
proves.*

## Minimal example

```dart
import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';

Future<void> main() async {
  final graph = CellGraph.builder(graphId: 'demo').build();
  final bindings = SkinBindingTable()
    ..register(SkinBinding.state(
      cellId: 'clock.now',
      functionName: 'read',
      target: Cell.state<DateTime>(initial: DateTime.now()).cell,
      nextValue: () => DateTime.now(),
    ));
  final membrane = await SkinMembrane.open(
    graph: graph,
    bindings: bindings,
    journal: RecordingJournal(),
    send: (_) {},
  );
  final client = SkinClient(membrane: membrane);
  print(await client.apply('clock.now', 'read'));
}
```

## References

- `references/api_chooser.md` — the full generated decision matrix
  (the same rows as `lib/doc/api_chooser.dart`).
