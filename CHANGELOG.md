# Changelog

## Mitosis (1.0.0-rc.9)

- **New Mitose pipeline in [`guide/`](https://github.com/simon-m-lee/cell/tree/master/guide)** — an AI-executable orchestration script set that turns a business requirement into a Cell + Flow + Tissue solution and its project documents:
  - [`HowTo-Mitose.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose.md) — the orchestration script: BRD gate → WalkThrough → Demo → WalkThrough assessment → ARCHITECTURE/FEATURES, with one human decision at each gate.
  - [`HowTo-Mitose-Cell.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Cell.md), [`HowTo-Mitose-Flow.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Flow.md), and [`HowTo-Mitose-Tissue.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Tissue.md) — layer placement guides for the Cell, Flow, and Tissue layers.
  - [`BRD-AI-Interview.md`](https://github.com/simon-m-lee/cell/blob/master/guide/BRD-AI-Interview.md) and [`Business_Requirements_Document(BRD).md`](https://github.com/simon-m-lee/cell/blob/master/guide/Business_Requirements_Document(BRD).md) — guided interview script and offline template for the required BRD.
  - [`WalkThrough-AI-Generator.md`](https://github.com/simon-m-lee/cell/blob/master/guide/WalkThrough-AI-Generator.md), [`ARCHITECTURE-AI-Generator.md`](https://github.com/simon-m-lee/cell/blob/master/guide/ARCHITECTURE-AI-Generator.md), and [`FEATURES-AI-Generator.md`](https://github.com/simon-m-lee/cell/blob/master/guide/FEATURES-AI-Generator.md) — document generators for the WalkThrough, ARCHITECTURE, and FEATURES documents.
- **New BRD samples** in [`example/BRD/`](https://github.com/simon-m-lee/cell/tree/master/example/BRD) — ready-made BRDs across industries (airport baggage handling, assembly-line downtime, freight rail intermodal, hospital ED capacity/flow) for learning the BRD format or running the Mitose pipeline right away — plus `*-BRD.md` companions for the existing `(Cell)` demos.
- **Packaging**: the new `guide/` directory is tracked in the repository and remains excluded from the published pub.dev archive via `.pubignore`.
- **README & onboarding**: documented the Mitose pipeline (with a copy-paste starter prompt) and the new `guide/` and BRD sample layout, and added [`AGENTS.md`](https://github.com/simon-m-lee/cell/blob/master/AGENTS.md) so agentic tools auto-discover the Mitose trigger.
- **Package releases**: this umbrella release ships together with `cell` `1.0.0-rc.6` (widened `Pulse.type`), `cell_flow` `1.0.0-rc.7` (Mitose pipeline docs), and `cell_tissue` `1.0.0-rc.7` (unified `TissueEvent` classification).

## Mitosis (1.0.0-rc.8)

- **Removed the internal `/guide/` directory** from the repository and the published package. The guides are internal and are no longer tracked in the repo or shipped in the pub.dev archive.

## Mitosis (1.0.0-rc.7)

- **Fixed dartdoc generation** for pub.dev scoring: the `Walkthroughs` category now references `DEMO_GUIDE-Mitosis.md` with the correct filename case, so `dart doc` succeeds on case-sensitive filesystems.
- **Removed** `example/grid-demand-response(Cell)-Day1.md`.
- **Docs**: regenerated the API docs and synced guides.

## Mitosis (1.0.0-rc.6)

- **New `(Cell)` demo set** in [`example/`](<https://github.com/simon-m-lee/cell/tree/master/example>) — the instruction-side counterparts of the `cell_tissue` demos:
  - [`grid-demand-response(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/grid-demand-response(Cell)-Demo.dart>) with `GridDecisionInstruction extends FlowInstructionBase`, composed with a stock `MapValue` into a `FlowInstructionChain` and materialised with `toHandle`.
  - [`ride-hail-dispatch(Cell)-Demo.dart`](<https://github.com/simon-m-lee/cell/blob/master/example/ride-hail-dispatch(Cell)-Demo.dart>) with `MatchDecisionInstruction` following the same `AsyncMap`-style template.
  - Each set ships its companion `*-WalkThrough.md`, `*-ARCHITECTURE.md`, and `*-FEATURES.md`.
- **Updated** [`card-auth-pipeline(Cell)-ARCHITECTURE.md`](<https://github.com/simon-m-lee/cell/blob/master/example/card-auth-pipeline(Cell)-ARCHITECTURE.md>) with the dedicated "How the FlowInstructionChain is made" section.
- **New guides:**
  - [`DEMO_GUIDE-Mitosis.md`](<https://github.com/simon-m-lee/cell/blob/master/DEMO_GUIDE-Mitosis.md>) — the Mitosis demo guide (Cell/Flow decision-side learning path) with GitHub cross-references.
- **Docs**: Added umbrella `example/` layout and new guides to the root README.

## Mitosis (1.0.0-rc.5)

- **Umbrella package**: Published the `mitosis` umbrella package, re-exporting the three public layers — `cell` (core), `cell_flow` (orchestration), and `cell_tissue` (application).
- **Dependencies**: Pinned the umbrella to `cell`, `cell_flow`, and `cell_tissue` `1.0.0-rc.5`.
- **License**: Republished with the canonical MIT and Apache-2.0 license texts.

## 1.0.0

- **Cell Framework Ecosystem Expansion**: Added `cell` and `cell_flow` projects under the `packages/` directory.
- **Release of `cell`**: The core `cell` package is now officially released as the foundation layer of the Cell Framework, featuring the Mitosis production-ready reactive fabric.
- **Introduction of `cell_flow`**: Initial version of `cell_flow` added to the ecosystem.
