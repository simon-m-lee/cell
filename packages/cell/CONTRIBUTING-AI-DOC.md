# CONTRIBUTING-AI-DOC — AI-facing doc-comment convention for `package:cell`

This file is the normative spec for the `### AI Agent Guide` blocks in public
doc comments. It implements Phase 1 of the AI-facing documentation enhancement (the doc-comment convention below).

## Why this exists

An AI agent (or a fast human) picking a `Cell.*` factory needs to answer six
questions *without* leaving the symbol's dartdoc page:

1. What layer is this? (Cell / Flow / Tissue)
2. When do I use it — and when must I *not*?
3. What is the live signature, verified against which package version?
4. What sibling symbol am I about to confuse it with?
5. Which HowTo section explains the full decision?
6. How do I prove my choice before generating code?

The block answers all six in a fixed order, so it can be parsed mechanically
(see `tool/generate_ai_examples.dart`, `tool/generate_api_chooser.dart`,
`tool/ai_preflight.dart`).

## Format

Append — never replace existing prose — to the symbol's `///` doc comment:

```dart
/// ### AI Agent Guide
///
/// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
/// **When to use:** A BRD says "capture X" (an external fact enters the system).
/// **When NOT to use:**
///   {@macro ai-do-not-create-cell-as-policy}
/// **Live signature:** `Cell.ingress<I>({refine, testRule, ...})` — pinned at `cell: 1.1.0`
/// **Do NOT confuse with:** `Cell.state` (retained value, not stateless entry).
/// **Guide:** `HowTo-Mitose-Cell.md` §3.1 "Cell.ingress — how the desk enters the graph" (#cell-ingress)
/// **Example:** `example/ingress_demo.dart`
/// **Cross-layer:** moves to `cell_flow` if the BRD says "wait for silence" or "rate-limit".
/// **Stability:** stable
///
/// **Self-verification before generating code that uses this:**
/// 1. The `Live signature:` line above matches `pubspec.yaml` (`dart pub deps | grep cell`).
/// 2. `dart run tool/ai_preflight.dart` exits 0.
/// 3. `test/ai_guide_examples_test.dart` group `<Symbol>` passes.
/// 4. The snippet below compiles under `dart analyze`.
///
/// **Minimal compilable example** (compiled as part of Phase 3's doc-example test):
/// ```dart
/// final IngressHandle<String> gate = Cell.ingress<String>();
/// Cell.observe(source: gate.cell, effect: (Pulse p) => print(p.payload));
/// gate.emit('hello');
/// ```
```

## Rules

1. **Layer assertion is line 1** of the block. It is the single biggest
   hallucination preventer. A `Cell.*` factory can never be described as Flow
   or Tissue.
2. **When to use / When NOT to use** — one sentence each. `When NOT to use`
   must use a `{@macro}` from `lib/doc/ai_anti_patterns.dart` where one fits;
   free prose is allowed only for a symbol-specific known issue (e.g. a
   documented O(n²) behavior). State known issues explicitly — do not hide
   them.
3. **Live signature pin** — a literal, abbreviated signature plus the package
   version it was verified against (`pinned at \`cell: <version>\``).
   `tool/ai_preflight.dart` asserts this pin matches the resolved version.
   Updating the pin is a conscious act: run preflight after any version bump.
4. **Do NOT confuse with** — name the sibling and the one-line difference.
   Both sides of a confusing pair carry the line.
5. **Guide pointer with section number** — `HowTo-Mitose-Cell.md §3.1 "…"
   (#cell-ingress)`. The section number is a stable anchor added by Phase 2.
   Point at the HowTo; never restate it (restating drifts).
6. **Cross-layer** — when to abandon this factory and open a different layer
   HowTo.
7. **Stability** — `stable`, or `reviewed` / `known-issue` with the issue
   named in `When NOT to use`.
8. **Minimal compilable example** — a synchronous snippet that
   `test/ai_guide_examples_test.dart` compiles with `dart analyze` and runs
   with `dart run`, asserting exit 0. Keep it timer-free so CI stays fast.
9. **No deletion.** Existing prose is never removed; the block is appended.

## Machinery that consumes this file

| Tool / test | Phase | What it enforces |
|---|---|---|
| `tool/generate_ai_examples.dart` + `test/ai_guide_examples_test.dart` | 3.1 | Every `Minimal compilable example` compiles and runs, exit 0. |
| `test/seam_test.dart` | 3.2 | Grep seam rules (no `TestCell` on Tissue; no Tissue writes in instructions) fail the package's own CI, not just a Mitose run. |
| `dart run tool/ai_preflight.dart` | 3.3 | Every `Live signature:` pin matches the resolved version; exits non-zero on drift. Also checks the HowTo version pins. |
| `tool/ai_failure_log.dart` + `tool/ai_failure_log.jsonl` | 6.1 | Structured log of real AI failures; reviewed quarterly. |
| `tool/generate_api_chooser.dart` + `test/api_chooser_up_to_date_test.dart` | 6.2 | `lib/doc/api_chooser.dart` is generated from these blocks and cannot drift. |
| `guide/LEDGER-AI-Generator.md` §7.1 | 6.3 | Every Failed ledger row cites the block's `When NOT to use` line ("Did you try this?"). |

## Anti-pattern templates

`lib/doc/ai_anti_patterns.dart` holds the `{@template}` definitions. If an
anti-pattern repeats in two or more blocks, promote it to a template there
instead of duplicating prose.
