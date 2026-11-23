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
   the pin in the row (cell_skin 0.1.x). When working inside the
   repository itself, regenerate the chooser with
   `dart run tool/generate_api_chooser.dart` from `packages/cell_skin`
   and keep `test/api_chooser_up_to_date_test.dart` green.

## Hard rules

- Never invent a receipt. The skin forwards the domain's receipts,
  marks them pending, or withholds them — it never synthesises an
  `ApplyAccepted` the graph did not produce.
- Never forge authority. Remote identity travels as a `PulseContext`;
  the default inbound context is least privilege
  (`skin:untrusted`), never `Context.system`.
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
  `cursor_required`, `conflict`) are `WireError` without a receipt;
  domain denials are `ApplyRejected` inside a `WireResponse`.
- The decision (cell_flow) and the books (cell_tissue) stay outside
  the skin; the skin only transports and enforces exposure.
