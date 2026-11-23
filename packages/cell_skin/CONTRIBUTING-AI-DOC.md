# CONTRIBUTING-AI-DOC — AI-facing doc-comment convention for `package:cell_skin`

This file is the normative spec for the `### AI Agent Guide` blocks in
public doc comments, mirroring the `package:cell` convention
(`packages/cell/CONTRIBUTING-AI-DOC.md`).

## Why this exists

An AI agent (or a fast human) picking a `cell_skin` API needs to answer
six questions *without* leaving the symbol's dartdoc page:

1. What layer is this? (Skin — never a graph node, never a Flow
   decision, never a Tissue book)
2. When do I use it — and when must I *not*?
3. What is the live signature, verified against which package version?
4. What sibling symbol am I about to confuse it with?
5. Which document explains the full decision?
6. How do I prove my choice before generating code?

The block answers all six in a fixed order, so it can be parsed
mechanically (see `tool/generate_api_chooser.dart`).

## Format

Append — never replace existing prose — to the symbol's `///` doc
comment:

```dart
/// ### AI Agent Guide
///
/// **Layer:** Skin — the membrane between a Cell graph and remote consumers.
/// **When to use:** A BRD says "expose the graph over REST".
/// **When NOT to use:** pure graph work — use `package:cell` directly.
/// **Live signature:** `SkinMembrane.open({...})` — pinned at `cell_skin: 0.1.0`
/// **Do NOT confuse with:** `RestAdapter.bind` (opens a socket on top of the membrane).
/// **Guide:** `ARCHITECTURE-Skin.md` §2 (the four cells)
/// **Example:** `example/lib/mock/mock_home.dart`
/// **Cross-layer:** the domain's own `TestCell` remains the second gate.
///
/// **Self-verification before generating code that uses this:**
/// 1. The `Live signature:` line above matches the checked-in source.
/// 2. `dart run tool/generate_api_chooser.dart` exits 0 and
///    `test/api_chooser_up_to_date_test.dart` passes.
/// 3. The snippet below compiles under `dart analyze`.
///
/// **Minimal compilable example** (kept inside the doc comment):
/// ```dart
/// final membrane = await SkinMembrane.open(...);
/// ```
```

## Field rules

- **Layer:** always names the Skin layer and what the symbol is *not*
  (a graph node, a Flow decision, a Tissue book).
- **Live signature:** the exact checked-in declaration, ending with
  `pinned at \`cell_skin: <version>\``. Bump the pin when the signature
  changes.
- **Do NOT confuse with:** the sibling the caller is most likely to
  pick by mistake.
- **Guide / Example:** point at `ARCHITECTURE-Skin.md`,
  `FEATURES-Skin.md`, or the Echo Home example.
- **Minimal compilable example:** a self-contained snippet a doc test
  or an agent can paste and compile.

## Hard rules encoded in the blocks

- Never invent a receipt; never borrow a receipt from an earlier
  change.
- Egress is `WireStateChange` — not a reply, no correlation id.
- `RestAdapter.bind` requires explicit `auth:`; anonymous access is
  the `AllowAllSkinAuth` opt-in.
- The binding table seals at `SkinMembrane.open`; binding targets must
  be the graph's registered cells.
- Errors before `target.apply` have no receipt and travel as
  `WireError`.

## What is generated

`dart run tool/generate_api_chooser.dart` parses every
`### AI Agent Guide` block in `lib/` and regenerates:

- `lib/doc/api_chooser.dart` — the pub.dev-rendered decision matrix
  (documentation only; not exported by the barrel).
- `skills/cell-skin/references/api_chooser.md` — the Markdown twin
  inside the published skill.

`test/api_chooser_up_to_date_test.dart` fails CI if either file is
stale.
