# Changelog

## Mitosis (2.2.0) - Stable Release

- **Umbrella version now tracks the Mitose pipeline**: the umbrella package version matches the Mitose pipeline version — `mitosis` `2.2.0` corresponds to [`guide/HowTo-Mitose.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose.md) v2.2. Future MAJOR/MINOR pipeline bumps carry the umbrella version with them.
- **AI-facing API discovery across all three packages** (normative spec: [`packages/cell/CONTRIBUTING-AI-DOC.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell/CONTRIBUTING-AI-DOC.md)): every top public symbol in `cell`, `cell_flow`, and `cell_tissue` now carries a machine-readable `### AI Agent Guide` block in its dartdoc — layer assertion, when to use / when NOT to use (via `{@macro}` anti-pattern templates in each package's `lib/doc/ai_anti_patterns.dart`), a `Live signature:` version pin, sibling disambiguation (`Do NOT confuse with`), a `Guide:` pointer, cross-layer guidance, stability, self-verification steps, and a minimal compilable example. Known operator issues (`Distinct` custom-comparator O(n²), `ExhaustMapLatest` busy-flag race) are stated explicitly in `When NOT to use`.
- **Mitose HowTo guides** ([`guide/HowTo-Mitose-Cell.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Cell.md), [`guide/HowTo-Mitose-Flow.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Flow.md), [`guide/HowTo-Mitose-Tissue.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Tissue.md)): each file now opens with a **Verified against (version pin)** block (`cell 1.1.0`, `cell_flow 1.0.0`, `cell_tissue 1.0.0`) and carries stable `<a id="…">` anchors on every section referenced by the dartdoc `Guide:` pointers, so citations resolve to exact sections on GitHub.
- **Verification infrastructure per package**: `tool/ai_preflight.dart` makes "resolve live signatures" a one-line check — doc-comment pins and HowTo pins vs resolved versions, exits non-zero on drift, and prints a paste-ready Demo provenance block; `tool/generate_ai_examples.dart` + `test/ai_guide_examples_test.dart` compile (`dart analyze`) and execute every doc-comment example in CI; `test/seam_test.dart` ports the Mitose grep seam rules into each package's own suite; `tool/generate_api_chooser.dart` + `test/api_chooser_up_to_date_test.dart` keep the generated `lib/doc/api_chooser.dart` decision matrix drift-free.
- **AI starter surface**: each package README now opens with Install and import → "AI agents start here" → a six-row "If you have a BRD sentence that says…" elevator matrix before the existing content; the three library doc comments carry layer-contract public-surface top tables; curated `example/` files carry fixed AI-facing headers (`What it demonstrates` / `Which BRD sentence picks it`).
- **Feedback loop** ([`guide/LEDGER-AI-Generator.md`](https://github.com/simon-m-lee/cell/blob/master/guide/LEDGER-AI-Generator.md) §7.1): every Failed ledger row must cite the failing operator's `When NOT to use` line ("Did you try this?"), and uncovered gaps are appended to each package's `tool/ai_failure_log.jsonl` via `tool/ai_failure_log.dart` for quarterly review.
- **Guide validation updated for pipeline v2.2**: `tool/check_mitose_guides.dart` no longer requires the removed master generator; it now verifies end-of-file markers on every guide, that the six generators named directly by `HowTo-Mitose.md` exist, that each carries a versioned `*End of <name> vM.m.*` footer, and that Rules 24–26 are present. The umbrella README's guide-script table and repository layout were updated to match.
- **Package releases**: ships with `cell` `1.1.0`, `cell_flow` `1.0.0`, and `cell_tissue` `1.0.0` (all stable).

## Mitosis (1.0.0-rc.14) - Release Candidate

- **Master generator extended with consolidated Mitose rules** ([`guide/Document_AI_MasterGenerator.md`](https://github.com/simon-m-lee/cell/blob/master/guide/Document_AI_MasterGenerator.md)): the master script now carries the rules that previously lived only in the pipeline guide — the **density rule** for WalkThroughs (Rule 25: the fullest, densest form, even in autonomous mode; a summary or condensed table that omits a named ingress or latch transition is invalid), the **small-instructions-and-chain rule** for Demos (Rule 26: one job per instruction, joined with `+`; a single instruction that performs every check is invalid), and consolidated practice rules covering structure (one ingress per BRD feed, deferred feeds in §5.1, a Tissue book per data requirement), `txApply` commits (participants, staged applies, no early returns), failure scenarios and evidence (whole-commit undo, partial-failure compensation, executed-run-only §5.12 rows), findings and parameters, guards, UTF-8 encoding, receives-and-state, and observe-and-test requirements.
- **WalkThrough generator** ([`guide/WalkThrough-AI-Generator.md`](https://github.com/simon-m-lee/cell/blob/master/guide/WalkThrough-AI-Generator.md)): added a **Receives and state rules** section — a guard that decides on a value receives it at construction, an instruction that decides on chain state receives the accumulated guard result, shared instructions declare whether they are stateless, and a guard that reads a book states the missing-value case.
- **Generator hygiene and versioning**: end-of-file markers moved to the true end of `Document_AI_MasterGenerator.md` and `WalkThrough-AI-Generator.md`; the master generator is now v1.1, the WalkThrough generator v1.1, and all other generators carry explicit v1.0 footers (matching the new generator manifest in the master). The master also gains a **precedence rule** (on conflict the individual generator wins) and a **generator manifest** with version pinning; desk-specific wording in the practice rules and `HowTo-Mitose.md` Rule 26 was generalized so the rules apply to any BRD's own shapes.
- **Guide validation script**: new [`tool/check_mitose_guides.dart`](https://github.com/simon-m-lee/cell/blob/master/tool/check_mitose_guides.dart) verifies end-of-file markers, generator version footers against the manifest, referenced guide files, and the presence of Rules 25–26 before a release.

## Mitosis (1.0.0-rc.13) - Release Candidate

- **Docs sync**: The umbrella README and changelog now reflect the video-free `cell` `1.0.0-rc.9` release, and the umbrella's `cell` dependency is aligned to `^1.0.0-rc.9`.
- **Package releases**: Ships with `cell` `1.0.0-rc.9`, `cell_flow` `1.0.0-rc.9`, and `cell_tissue` `1.0.0-rc.9`.

## Mitosis (1.0.0-rc.12) - Release Candidate

- **New worked Mitose sample** — [`example/cafe-coffee-*`](https://github.com/simon-m-lee/cell/tree/master/example): a complete cafe-coffee pipeline run with its BRD, WalkThrough, Demo, `<stem>-test.dart`, ARCHITECTURE, FEATURES, LEDGER, and COMPREHENSION documents, following the full Mitose 2.0 path.
- **Release tooling** — [`tool/release-publish.sh`](https://github.com/simon-m-lee/cell/blob/master/tool/release-publish.sh) now accepts member packages as positional arguments (`tool/release-publish.sh packages/cell_flow packages/cell_tissue`) so a partially completed release can be resumed; the umbrella is always published last.
- **Docs** — aligned the CHANGELOG heading convention across the umbrella and member packages, and regenerated the `doc/api` API reference for `mitosis`, `cell`, `cell_flow`, and `cell_tissue` after fresh `dart doc` runs on each package.
- **Package releases**: ships with `cell` `1.0.0-rc.8` (regenerated API docs), `cell_flow` `1.0.0-rc.9` (dependency alignment, regenerated API docs), and `cell_tissue` `1.0.0-rc.9` (new HowTo-Tissue guides, nucleus KDoc overhaul, regenerated API docs).

## Mitosis (1.0.0-rc.11) - Release Candidate

- **Mitose pipeline upgraded with an autonomous mode** ([`guide/HowTo-Mitose.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose.md) §15): the pipeline now has two run modes — the interactive step-by-step mode with one human decision at each gate, and the opt-in autonomous mode in which the user says “Mitose autonomous” once after a filled BRD exists and the agent runs the rest of the pipeline to the end without interruption or further input.
  - Every later gate becomes a recorded automatic decision. Open questions, thresholds, and rule precedence are decided by the agent and tagged `[AI DECIDED — autonomous]`; residual acceptance is recorded as a delegation, never as the user’s own approval.
  - The comprehension check is skipped. The agent ensures a Dart runtime, adds `package:cell`, `package:cell_flow`, and `package:cell_tissue`, implements the WalkThrough in full, and writes and tests a Demo that covers every testable BRD requirement ID before producing the remaining documents.
  - Guardrails: autonomy starts only after the BRD exists, never applies to change mode, never overwrites an existing file, never marks a row Verified without an executed run, and stops and reports instead of asking when a required script or HowTo cannot be read. The final report lists every autonomous decision.
- **Document master generator** ([`guide/Document_AI_MasterGenerator.md`](https://github.com/simon-m-lee/cell/blob/master/guide/Document_AI_MasterGenerator.md)): every Mitose document-generation step now starts at a single master entry point. The agent consults it first, follows its document→generator map to the correct individual generator, and records in the run log that the master script was consulted. This applies in both step-by-step and autonomous mode — a document produced without going through the master script is invalid.
- **README** documents both run modes, the “Mitose autonomous” trigger, and the master-generator rule.
- **Package releases**: ships with `cell` `1.0.0-rc.7` (txApply compensation, public lock access, dual-audience guides), `cell_flow` `1.0.0-rc.8` (AI command instructions relocated to `cell_tissue`), and `cell_tissue` `1.0.0-rc.8` (`TissueMap` upsert, AI command instructions, `Cell.transaction` support).

## Mitosis (1.0.0-rc.10) - Release Candidate

- **Precision Software Engineering** — the coined term for the Mitose pipeline’s contract: a stated design requirement is carried into running behavior, recorded, explicit, bounded, checkable, traceable, and verifiable. Six components, no seventh. Documented in the README.
  - Residual ledger (`LEDGER-AI-Generator.md`) written from `<stem>-test.dart` `BRD` group `LEDGER` lines. Verified requires executed evidence; reading code is not Verified.
  - Comprehension checks and decision log (`COMPREHENSION-AI-Generator.md`) with gates C1–C3. Skipping is allowed and recorded.
  - Change mode (`CHANGE-AI-Generator.md`) for requirement, upgrade, drift, or defect changes. Writes immutable `<stem>-CHANGE-<nnn>.md`.
  - `<stem>-test.dart` is always written with the Demo. Groups align to public APIs and documented contracts. Fail-closed groups (`constraint`, `provenance`, `boundary`) fail the suite without moving a BRD row.
  - Output names drop the `(Cell)` suffix. Executable remains the Cell variant (`Cell` + `Flow` + `Tissue`).
  - Semantic versioning (`MAJOR.MINOR.PATCH`) on every generated file. Name plate carries `Version` and `Supersedes`. Later steps resolve only the latest version.
  - After Demo Assessment, the agent offers three choices for recommendations: as a Change (CHANGE path + version bump), in place (no version bump, no CHANGE file), or skip.
  - Blocked-row mitigation plan in the ledger (sequenced steps, evidence that moves the row, owner).
  - `Cell.txApply` on Tissue is the only atomic commit. `Cell.transaction` is deferred.
  - Length caps removed from generators. Documents open with a short summary when useful.
- **Layer HowTos** updated for the 2.0 seam (instruction decides, chain assembles, observer glues) and for `Cell.txApply` on Tissue.
- **Sample BRDs** remain in `example/BRD/`; worked pipeline samples (pantry-bridge, saltline-scramble, tide-warden) demonstrate the full 2.0 path including ledger and comprehension.
- **Package releases**: ships with `cell` `1.0.0-rc.6`, `cell_flow` `1.0.0-rc.7`, `cell_tissue` `1.0.0-rc.7`.

## Mitosis (1.0.0-rc.9) - Release Candidate

- **New Mitose pipeline in [`guide/`](https://github.com/simon-m-lee/cell/tree/master/guide)** — an AI-executable orchestration script set that turns a business requirement into a Cell + Flow + Tissue solution and its project documents:
  - [`HowTo-Mitose.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose.md) — the orchestration script: BRD gate → WalkThrough → Demo → WalkThrough assessment → ARCHITECTURE/FEATURES, with one human decision at each gate.
  - [`HowTo-Mitose-Cell.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Cell.md), [`HowTo-Mitose-Flow.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Flow.md), and [`HowTo-Mitose-Tissue.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Tissue.md) — layer placement guides for the Cell, Flow, and Tissue layers.
  - [`BRD-AI-Interview.md`](https://github.com/simon-m-lee/cell/blob/master/guide/BRD-AI-Interview.md) and [`Business_Requirements_Document.md`](https://github.com/simon-m-lee/cell/blob/master/guide/Business_Requirements_Document.md) — guided interview script and offline template for the required BRD.
  - [`WalkThrough-AI-Generator.md`](https://github.com/simon-m-lee/cell/blob/master/guide/WalkThrough-AI-Generator.md), [`ARCHITECTURE-AI-Generator.md`](https://github.com/simon-m-lee/cell/blob/master/guide/ARCHITECTURE-AI-Generator.md), and [`FEATURES-AI-Generator.md`](https://github.com/simon-m-lee/cell/blob/master/guide/FEATURES-AI-Generator.md) — document generators for the WalkThrough, ARCHITECTURE, and FEATURES documents.
- **New BRD samples** in [`example/BRD/`](https://github.com/simon-m-lee/cell/tree/master/example/BRD) — ready-made BRDs across industries (airport baggage handling, assembly-line downtime, freight rail intermodal, hospital ED capacity/flow) for learning the BRD format or running the Mitose pipeline right away — plus `*-BRD.md` companions for the existing `(Cell)` demos.
- **Packaging**: the new `guide/` directory is tracked in the repository and remains excluded from the published pub.dev archive via `.pubignore`.
- **README & onboarding**: documented the Mitose pipeline (with a copy-paste starter prompt) and the new `guide/` and BRD sample layout, and added [`AGENTS.md`](https://github.com/simon-m-lee/cell/blob/master/AGENTS.md) so agentic tools auto-discover the Mitose trigger.
- **Package releases**: this umbrella release ships together with `cell` `1.0.0-rc.6` (widened `Pulse.type`), `cell_flow` `1.0.0-rc.7` (Mitose pipeline docs), and `cell_tissue` `1.0.0-rc.7` (unified `TissueEvent` classification).

## Mitosis (1.0.0-rc.8) - Release Candidate

- **Removed the internal `/guide/` directory** from the repository and the published package. The guides are internal and are no longer tracked in the repo or shipped in the pub.dev archive.

## Mitosis (1.0.0-rc.7) - Release Candidate

- **Fixed dartdoc generation** for pub.dev scoring: the `Walkthroughs` category now references `DEMO_GUIDE-Mitosis.md` with the correct filename case, so `dart doc` succeeds on case-sensitive filesystems.
- **Removed** `example/grid-demand-response(Cell)-Day1.md`.
- **Docs**: regenerated the API docs and synced guides.

## Mitosis (1.0.0-rc.6) - Release Candidate

- **New `(Cell)` demo set** in [`example/`](<https://github.com/simon-m-lee/cell/tree/master/example>) — the instruction-side counterparts of the `cell_tissue` demos:
  - [`grid-demand-response(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/grid-demand-response(Cell)-Demo.dart>) with `GridDecisionInstruction extends FlowInstructionBase`, composed with a stock `MapValue` into a `FlowInstructionChain` and materialised with `toHandle`.
  - [`ride-hail-dispatch(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/ride-hail-dispatch(Cell)-Demo.dart>) with `MatchDecisionInstruction` following the same `AsyncMap`-style template.
  - Each set ships its companion `*-WalkThrough.md`, `*-ARCHITECTURE.md`, and `*-FEATURES.md`.
- **Updated** [`card-auth-pipeline(Cell)-ARCHITECTURE.md`](<https://github.com/simon-m-lee/cell/blob/master/example/card-auth-pipeline(Cell)-ARCHITECTURE.md>) with the dedicated "How the FlowInstructionChain is made" section.
- **New guides:**
  - [`DEMO_GUIDE-Mitosis.md`](<https://github.com/simon-m-lee/cell/blob/master/DEMO_GUIDE-Mitosis.md>) — the Mitosis demo guide (Cell/Flow decision-side learning path) with GitHub cross-references.
- **Docs**: Added umbrella `example/` layout and new guides to the root README.

## Mitosis (1.0.0-rc.5) - Release Candidate

- **Umbrella package**: Published the `mitosis` umbrella package, re-exporting the three public layers — `cell` (core), `cell_flow` (orchestration), and `cell_tissue` (application).
- **Dependencies**: Pinned the umbrella to `cell`, `cell_flow`, and `cell_tissue` `1.0.0-rc.5`.
- **License**: Republished with the canonical MIT and Apache-2.0 license texts.

## 1.0.0

- **Cell Framework Ecosystem Expansion**: Added `cell` and `cell_flow` projects under the `packages/` directory.
- **Release of `cell`**: The core `cell` package is now officially released as the foundation layer of the Cell Framework, featuring the Mitosis production-ready reactive fabric.
- **Introduction of `cell_flow`**: Initial version of `cell_flow` added to the ecosystem.
