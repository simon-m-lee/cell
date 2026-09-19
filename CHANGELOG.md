# Changelog

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
