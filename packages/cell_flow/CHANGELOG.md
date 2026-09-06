## Mitosis (1.0.0-rc.2.0.1) - Release Candidate

- **Legal & Compliance**:
  - Updated `LICENSE` file to ensure proper legal coverage.
  - Standardized copyright headers across the `cell_flow` package.
  - Updated authorship and repository metadata.
  
## Mitosis (1.0.0-rc.2) - Release Candidate

- **Expanded Async Topography**:
  - Introduced specialized `asyncMap` variants: `AsyncMapConcurrent`, `AsyncMapLatest`, `AsyncMapSequential`.
  - Added robust async utilities: `AsyncMapWithRetry`, `WithTimeout`, `WithFallback`, and `AsyncMapWithIndex`.
  - Expanded `asyncFold` suite with `AsyncFoldLatest`, `AsyncFoldExhaust`, and `AsyncReduce`.
- **Enhanced Orchestration Demos**:
  - Added `ICU-alarm-pipeline(enhanced)-Demo.dart`, simulating a complex medical alarm pipeline with noise reduction and escalation logic.
  - Added `domain-cells-txApply(enhanced)-Demo.dart`, demonstrating advanced transactional multi-cell state updates.
  - Included detailed walkthroughs for all enhanced demos to assist in architectural onboarding.
- **Reactive Core Hardening**:
  - Leveraged new `Receptor` scrutiny and `PulseShell` defensive proxies for higher integrity in complex flow pipelines.
  - Improved type inference and error handling in asynchronous pulse transformations.
- **Documentation & Ergonomics**:
  - Consolidated documentation into a new `DEMO_GUIDE.md`.
  - Updated `FEATURES-Flow.md` with a complete catalog of RC2 instructions and operators.
  - **High-Integrity KDocs**: Regenerated documentation for `Flow` and `FlowInstruction` with structured `### When to use`, `### How it works`, and `### Non‑obvious` sections.
  - **API Completeness**: Added `asyncFoldLatest` and `asyncFoldExhaust` to the `Flow` static facade for symmetry with the instruction set.
  - **Doc-Link Hardening**: Resolved hundreds of "unresolved doc reference" warnings by sanitizing list literals and using fully-qualified names in library-level documentation.
  - **Strict Analysis**: Introduced `analysis_options.yaml` with mandatory API documentation rules (`public_member_api_docs`) and strict type inference settings.
  - **Enhanced DartDoc**: Refined `dartdoc_options.yaml` to categorize and link high-fidelity walkthroughs directly into the API reference.

## Mitosis (1.0.0-rc.1) - Release Candidate

- Initial Release Candidate for the Mitosis orchestration layer.
- Implementation of core reactive operators (map, filter, scan).
- Added asynchronous orchestration support via `asyncMap`.
- Introduction of `FlowHandle` and `FlowInstruction` composition patterns.
- Comprehensive documentation for the reactive topography.
