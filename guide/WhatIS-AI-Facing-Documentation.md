# What Is AI-Facing Documentation?

**A developer's guide to the machine-readable documentation contract in the Mitosis framework**

| | |
|---|---|
| **Repository** | [github.com/simon-m-lee/cell](https://github.com/simon-m-lee/cell) |
| **Applies to** | `cell` 1.1.0, `cell_flow` 1.0.0, `cell_tissue` 1.0.0, umbrella `mitosis` 2.2.x |
| **Normative spec** | [`packages/cell/CONTRIBUTING-AI-DOC.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell/CONTRIBUTING-AI-DOC.md) |
| **Introduced in** | Stable 2.2.0 line (10 November 2026) |
| **Audience** | Contributors, maintainers, and developers integrating Mitosis into an AI-assisted workflow |

---

## Table of Contents

- [1. The Short Answer](#1-the-short-answer)
- [2. Why It Exists](#2-why-it-exists)
    - [2.1 The problem it solves](#21-the-problem-it-solves)
    - [2.2 The strategic context](#22-the-strategic-context)
- [3. Anatomy of an `AI Agent Guide` Block](#3-anatomy-of-an-ai-agent-guide-block)
    - [3.1 Field-by-field reference](#31-field-by-field-reference)
    - [3.2 The "Live signature" pin](#32-the-live-signature-pin)
- [4. The Verification Surface](#4-the-verification-surface)
- [5. What This Means for Contributors](#5-what-this-means-for-contributors)
    - [5.1 When you add or change a public symbol](#51-when-you-add-or-change-a-public-symbol)
    - [5.2 When you change a signature](#52-when-you-change-a-signature)
    - [5.3 When you remove a symbol](#53-when-you-remove-a-symbol)
    - [5.4 Anti-patterns](#54-anti-patterns)
- [6. What This Means for Consumers](#6-what-this-means-for-consumers)
    - [6.1 If you are a human developer](#61-if-you-are-a-human-developer)
    - [6.2 If you are building an AI-assisted workflow](#62-if-you-are-building-an-ai-assisted-workflow)
    - [6.3 If you are running the Mitose pipeline](#63-if-you-are-running-the-mitose-pipeline)
- [7. What AI-Facing Documentation Is Not](#7-what-ai-facing-documentation-is-not)
- [8. Frequently Asked Questions](#8-frequently-asked-questions)
- [9. Further Reading](#9-further-reading)
- [10. Summary](#10-summary)

---

## 1. The Short Answer

**AI-Facing Documentation is dartdoc written for a machine reader first and a human reader second.**

Every top-level public symbol in the three Mitosis packages carries a standardized `### AI Agent Guide` block inside its doc comment. The block answers, in a fixed order, the exact questions an AI coding agent must resolve before it can safely generate code against that symbol:

1. Which layer does this belong to?
2. When should I use it, and when must I *not*?
3. What is its current, live signature?
4. Which similar symbol might I confuse it with?
5. Where is the full guidance?
6. What is a minimal, compilable example?

The documentation is not aspirational. It is **verified in CI**: signatures are checked against the resolved package, examples are compiled and executed, and seam rules are enforced by tests. If the documentation drifts from the code, the build fails.

---

## 2. Why It Exists

### 2.1 The problem it solves

AI coding agents hallucinate APIs. They generate code against signatures they remember from training data, not signatures that exist in the installed package. When an API drifts—a parameter renamed, a factory removed, a type changed—the generated code either fails to compile or, worse, compiles and behaves incorrectly.

Mitosis's response is not to tell agents to "be careful." It is to **make the source itself answer the agent's questions in a form the agent can parse, and to check that the answers are true**.

### 2.2 The strategic context

The Mitose pipeline treats an AI agent as the primary operator of the framework. In autonomous mode, the agent runs from a Business Requirements Document through design, implementation, tests, ledger, and documentation without per-gate human input. That mode is only defensible if the agent can reliably select the right layer, factory, operator, and seam.

AI-Facing Documentation is the surface that makes that reliability possible. As the [repository README](https://github.com/simon-m-lee/cell) states, it exists so an agent can *"reliably architect—pick the right layer, factory, operator, and seam—and generate code that compiles against the live API instead of guessing from memory."*

---

## 3. Anatomy of an `AI Agent Guide` Block

The block sits inside the dartdoc comment of a public symbol. It follows a fixed structure so it can be parsed mechanically.

```dart
/// A cell that holds a value of type [T] and emits on change.
///
/// ### AI Agent Guide
///
/// **Layer:** Cell
///
/// **Use when:** You need a single, observable value holder with
/// provenance and optional validation. This is the primitive for
/// state that must be inspectable.
///
/// **Do NOT use when:** You need to coordinate multiple cells or
/// express a state machine. Use Flow (`cell_flow`) instead.
///
/// **Live signature:**
/// ```dart
/// Cell<T> cell<T>(T initial, {String? name})
/// ```
/// Verified against: `cell: 1.1.0`
///
/// **Sibling disambiguation:** Do NOT confuse with `Cell.state`, which
/// returns the current value without emitting. Use `Cell.value` to
/// read and `Cell.stream` to observe.
///
/// **Guide:** `guide/HowTo-Mitose-Cell.md` §3.2
///
/// **Example:**
/// ```dart
/// final counter = cell<int>(0);
/// counter.value = 1; // emits 1
/// ```
class Cell<T> { ... }
```

### 3.1 Field-by-field reference

| Field | Purpose | Enforced by |
|---|---|---|
| **Layer** | Asserts Cell / Flow / Tissue placement | [`test/seam_test.dart`](https://github.com/simon-m-lee/cell/blob/master/test/seam_test.dart) |
| **Use when** | Positive selection guidance | [`tool/ai_preflight.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_preflight.dart) (presence) |
| **Do NOT use when** | Negative guidance; often uses anti-pattern macros | [`tool/ai_preflight.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_preflight.dart) (presence) |
| **Live signature** | The exact current signature, abbreviated | [`tool/ai_preflight.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_preflight.dart) (version pin match) |
| **Verified against** | Package name and version the pin was checked against | [`tool/ai_preflight.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_preflight.dart) |
| **Sibling disambiguation** | Names the most likely confusion | [`tool/ai_preflight.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_preflight.dart) (presence) |
| **Guide** | Pointer to the full decision context | [`tool/ai_preflight.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_preflight.dart) (presence) |
| **Example** | Minimal, compilable snippet | [`test/ai_guide_examples_test.dart`](https://github.com/simon-m-lee/cell/blob/master/test/ai_guide_examples_test.dart) (compile + run) |

### 3.2 The "Live signature" pin

The pin is the single most important field. It is an abbreviated signature plus the package version it was verified against. [`tool/ai_preflight.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_preflight.dart) resolves the installed package, compares the pinned signature to the live one, and fails the build on any mismatch.

This is what makes the documentation *load-bearing*. Without the pin, the doc comment is a comment. With it, the doc comment is a contract that CI enforces.

---

## 4. The Verification Surface

AI-Facing Documentation is only as good as the checks that keep it honest. The repository ships five instruments:

| Instrument | Path | What it does |
|---|---|---|
| **Preflight** | [`tool/ai_preflight.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_preflight.dart) | Fails the build when a `Live signature:` pin drifts from the resolved package version. |
| **Example compiler** | [`tool/generate_ai_examples.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/generate_ai_examples.dart) + [`test/ai_guide_examples_test.dart`](https://github.com/simon-m-lee/cell/blob/master/test/ai_guide_examples_test.dart) | Extracts every documentation example, compiles it, and executes it in CI. |
| **Seam tests** | [`test/seam_test.dart`](https://github.com/simon-m-lee/cell/blob/master/test/seam_test.dart) | Enforces Mitose placement rules inside the package's own suite—for example, no Tissue writes inside Flow instructions. |
| **API chooser** | [`lib/doc/api_chooser.dart`](https://github.com/simon-m-lee/cell/blob/master/lib/doc/api_chooser.dart) (generated) | Maps a BRD sentence to the correct factory or operator. Generated from the guide blocks, so it drifts only when the guides drift. |
| **Failure log** | [`tool/ai_failure_log.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_failure_log.dart) + [`tool/ai_failure_log.jsonl`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_failure_log.jsonl) | Captures structured AI failure records for a stated quarterly review. |

Together these mean the documentation is a **tested API surface**, not prose. If a contributor changes a signature and forgets the pin, CI fails. If an example stops compiling, CI fails. If a placement rule is violated, CI fails.

---

## 5. What This Means for Contributors

### 5.1 When you add or change a public symbol

1. **Write the `### AI Agent Guide` block.** Follow the fixed field order in [`CONTRIBUTING-AI-DOC.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell/CONTRIBUTING-AI-DOC.md). Missing fields fail preflight.
2. **Pin the live signature.** Abbreviate the signature and record the package version you verified against.
3. **Write a minimal, compilable example.** It will be compiled and executed in CI. Keep it small and self-contained.
4. **Name the sibling.** If another symbol is a likely confusion, say so explicitly.
5. **Point to the guide section.** The pointer is not decorative; agents follow it.
6. **Run `dart run tool/ai_preflight.dart`** locally before opening a PR.
7. **Run the example test** (`dart test test/ai_guide_examples_test.dart`) to confirm your example compiles and runs.

### 5.2 When you change a signature

The pin will break. That is the point. Update the `Live signature:` field and the `Verified against:` version in the same commit as the signature change. If preflight passes locally, CI will pass.

### 5.3 When you remove a symbol

Remove the guide block with the symbol. If the symbol was referenced in the API chooser, regenerate the chooser (`dart run tool/generate_api_chooser.dart`) so the generated matrix stays consistent.

### 5.4 Anti-patterns

The spec allows `{@macro}` templates for anti-patterns so they stay consistent across symbols. If you find yourself writing a novel warning, consider whether it belongs in the guide file instead, and use a macro to reference it.

---

## 6. What This Means for Consumers

### 6.1 If you are a human developer

The guide blocks are readable by humans too. The "Use when / Do NOT use when" fields are often the fastest way to find the right entry point. The "Sibling disambiguation" field is a short, reliable answer to the question "which of these two do I want?"

### 6.2 If you are building an AI-assisted workflow

Point your agent at the source. The `### AI Agent Guide` blocks are structured for parsing, and the pins are checkable. If your agent respects the pins, it will not generate code against a stale signature. If it respects the "Do NOT use when" field, it will not reach for the wrong layer.

The [`lib/doc/api_chooser.dart`](https://github.com/simon-m-lee/cell/blob/master/lib/doc/api_chooser.dart) matrix is the fastest path from a BRD sentence to a factory or operator. It is generated, so it is consistent with the guides.

### 6.3 If you are running the Mitose pipeline

The pipeline's placement rules are the same rules encoded in [`test/seam_test.dart`](https://github.com/simon-m-lee/cell/blob/master/test/seam_test.dart). The agent consults the guide blocks to decide where each requirement lands, and the seam tests enforce the placement in the package's own suite. The documentation and the enforcement are the same contract.

---

## 7. What AI-Facing Documentation Is Not

- **It is not a replacement for the guide files.** The `### AI Agent Guide` blocks are entry points and disambiguators. The full decision context lives in [`guide/HowTo-Mitose-Cell.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Cell.md), [`guide/HowTo-Mitose-Flow.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Flow.md), and [`guide/HowTo-Mitose-Tissue.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Tissue.md). The blocks point to the guides; they do not duplicate them.
- **It is not a replacement for human review.** The pins and the compiled examples catch drift and breakage. They do not prove that an agent understood the requirement, or that the requirement was right. The ledger can show that a Demo conformed to the BRD *as the agent completed it*; it cannot show that the completed BRD is right.
- **It is not a compliance certification.** `Context` metadata is text. The README says so explicitly, and the documentation says so again.
- **It is not stable across major versions by accident.** The umbrella version tracks the pipeline version. When the pipeline bumps a major or minor, the umbrella moves with it, and the guide blocks are expected to move too. Treat the pins as the contract and the version as the coordinate.

---

## 8. Frequently Asked Questions

**Why not just write better prose documentation?**
Prose drifts silently. A pin that CI checks does not. The guide blocks exist so the drift is a build failure, not a production surprise.

**Why is the field order fixed?**
So it can be parsed mechanically. An agent that knows the order can extract the six answers without heuristics. A human reader benefits from the same consistency.

**Why pin the signature instead of linking to the API docs?**
A link requires a second fetch and can resolve to a different version. A pin is inline, versioned, and checkable in the same pass that reads the block.

**What happens if the pin is wrong?**
[`tool/ai_preflight.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_preflight.dart) fails the build. The PR cannot merge until the pin matches the resolved package.

**What happens if the example is wrong?**
[`test/ai_guide_examples_test.dart`](https://github.com/simon-m-lee/cell/blob/master/test/ai_guide_examples_test.dart) compiles and executes it in CI. If it does not compile or does not run, CI fails.

**Do I have to write a guide block for every public symbol?**
Every top-level public symbol. Private symbols and internal helpers are out of scope. If you are unsure whether a symbol is top-level public, check the package's public API surface; if it is exported, it needs a block.

**Can I use the `{@macro}` templates?**
Yes. The spec encourages them for anti-patterns and repeated guidance, so wording stays consistent across symbols.

**Where do I report a problem with a guide block?**
Open an issue on the [repository](https://github.com/simon-m-lee/cell/issues). If the problem is a drift that preflight missed, that is a bug in the tooling as well as the block.

---

## 9. Further Reading

| Document | Link |
|---|---|
| Repository | [github.com/simon-m-lee/cell](https://github.com/simon-m-lee/cell) |
| Normative specification | [`packages/cell/CONTRIBUTING-AI-DOC.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell/CONTRIBUTING-AI-DOC.md) |
| Changelog | [`CHANGELOG.md`](https://github.com/simon-m-lee/cell/blob/master/CHANGELOG.md) |
| Mitose pipeline guide | [`guide/HowTo-Mitose.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose.md) |
| Cell placement guide | [`guide/HowTo-Mitose-Cell.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Cell.md) |
| Flow placement guide | [`guide/HowTo-Mitose-Flow.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Flow.md) |
| Tissue placement guide | [`guide/HowTo-Mitose-Tissue.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Tissue.md) |
| Preflight tool | [`tool/ai_preflight.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_preflight.dart) |
| Example compiler and test | [`tool/generate_ai_examples.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/generate_ai_examples.dart), [`test/ai_guide_examples_test.dart`](https://github.com/simon-m-lee/cell/blob/master/test/ai_guide_examples_test.dart) |
| Seam tests | [`test/seam_test.dart`](https://github.com/simon-m-lee/cell/blob/master/test/seam_test.dart) |
| API chooser (generated) | [`lib/doc/api_chooser.dart`](https://github.com/simon-m-lee/cell/blob/master/lib/doc/api_chooser.dart) |
| API chooser generator | [`tool/generate_api_chooser.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/generate_api_chooser.dart) |
| Failure log | [`tool/ai_failure_log.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_failure_log.dart), [`tool/ai_failure_log.jsonl`](https://github.com/simon-m-lee/cell/blob/master/tool/ai_failure_log.jsonl) |
| Package pages (pub.dev) | [mitosis](https://pub.dev/packages/mitosis) · [cell](https://pub.dev/packages/cell) · [cell_flow](https://pub.dev/packages/cell_flow) · [cell_tissue](https://pub.dev/packages/cell_tissue) |

---

## 10. Summary

AI-Facing Documentation is the Mitosis framework's answer to a specific problem: an AI agent cannot reliably generate code against an API it only remembers. The answer is a standardized, machine-parseable guide block on every top-level public symbol, with a pinned live signature and a compilable example, enforced by CI. The documentation is not a description of the API; it is a tested contract with the API. If you change the API, you change the contract in the same commit, or the build fails.

That is the whole idea. Everything else—the preflight, the example compiler, the seam tests, the API chooser, the failure log—exists to keep the contract honest.

---

*Document version 1.1 · Prepared for the Mitosis 2.2.x stable line · See [`CONTRIBUTING-AI-DOC.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell/CONTRIBUTING-AI-DOC.md) for the normative specification.*