## [Mitosis (1.0.0-rc.4)] - Release Candidate

This release formalizes the **Application Layer Governance** and introduces the **AI Command Infrastructure**, establishing a forensic gateway for machine-orchestrated state mutations within reactive collections.

### Added

- **AI Command Infrastructure**: Materialized the foundational gateway for AI-driven state evolution:
    - `ai_tissue_command.dart`: The command gateway implementation. It handles the execution of AI-generated instructions through governed `apply` and `dispatch` mechanics, ensuring transactions remain isolated and compensable.
    - `ai_tissue_command_domain.dart`: Formalized the forensic domain for machine commands, defining interfaces for command schemas, authority tiers, and administrative mandates.
- **AI Command Verification**:
    - `ai_tissue_command_test.dart`: Exhaustive test suite verifying that machine-initiated pulses correctly inherit `Context` anchors and that the forensic `Pulse.trace` captures mutation provenance.
- **High-Integrity Domain Demos**: Materialized four real-world application scenarios demonstrating collection integrity, atomic transactions, and AI-orchestrated commands:
    - **Card Auth Pipeline**:
        - `card-auth-pipeline(tissue)-Demo.dart`: Shows `cell_tissue` collections acting as forensic sinks for auth-request pulses routed via `cell_flow`.
        - `card-auth-pipeline(tissue)-WalkThrough.md`: Pedagogical guide on mapping stream-based pulses into persistent reactive lists.
    - **Hotel Front Desk**:
        - `hotel-front-desk-checkin-Demo.dart`: Demonstrates multi-tier reactive synchronization and authority-based check-in logic using `TissueMap`.
        - `hotel-front-desk-checkin-WalkThrough.md`: Analysis of how `Context` anchors protect asynchronous state boundaries.
    - **Aircraft Gate Turnaround**:
        - `aircraft-gate-turnaround-Demo.dart`: Simulates complex orchestration of ground crew, refueling, and flight deck state transitions.
        - `aircraft-gate-turnaround-WalkThrough.md`: Analytical walkthrough of atomic state evolution under strict timing and safety constraints.
    - **Warehouse Inventory Integrity**:
        - `warehouse-inventory-Demo.dart`: Showcases `Tissue` collection resilience during high-frequency stock updates and AI-driven restocking commands.
        - `warehouse-inventory-WalkThrough.md`: Explains the use of `isGoverned` and `testRule` to prevent inventory glitches.

### Changed

- **Async Facade Documentation**: Batch-documented 18+ asynchronous collection methods (e.g., `ModifiableListAsync`) to ensure `Future` lifecycles are explicitly linked to the forensic causal chain.
- **Biological Metaphor Alignment**: Updated the `README.md` and public API documentation to position **Tissue** as the "Connective Fabric" that binds granular Cell state into usable application models.
- **Workspace Governance**: Migrated to `resolution: workspace`. Added `cell_flow` to `dev_dependencies` to support high-integrity examples while maintaining monorepo governance.
- **Instruction DNA**: Integrated the `instruction/` layer into the public library, re-exporting stateless transformation logic for forensic-grade mutation blueprints.

### Fixed

- **Linter Hygiene**: Resolved `public_member_api_docs` and `depend_on_referenced_packages` warnings across the internal implementation files.
- **Documentation Reference Resolution**: Fixed unresolved doc references to `[Tissue]`, `[C]`, and `[principal]` by adopting standardized architectural language.

### Tests

- **Integrity Verified**: Confirmed that `TissueCommand` evolution preserves `Pulse.trace` metadata from the core layer across asynchronous boundaries.
- **Coverage**: Maintained 95%+ coverage on reactive collection mutation logic and the new AI command infrastructure.

[Mitosis (1.0.0-rc.4)]: https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue