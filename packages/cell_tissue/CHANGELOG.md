## [Mitosis (1.0.0-rc.7)] - Release Candidate

### Changed

- **Unified tissue event classification**: Replaced the specialised `ElementAdded`, `ElementRemoved`, and `ElementUpdated` event classes with the `TissueEvent` enum carried on `TissuePulse.type`.
  - `TissueEvent.elementAdded` — elements appended or inserted into a collection.
  - `TissueEvent.elementRemoved` — elements purged or popped from a collection.
  - `TissueEvent.elementUpdated` — a scalar value or property change.
  - `TissueEvent.entryUpdated` — a key-value pair within a `TissueMap` mutates.
- **Collection mutation signals**: `TissueList`, `TissueSet`, and `TissueQueue` mutations now emit `TissuePulse<T>` instances classified with the relevant `TissueEvent` instead of specialised event subclasses.
- **Value mutation signals**: `TissueValue` changes now emit `TissuePulse<ElementUpdatedRecord<V, TissueValue<V>>>` classified as `TissueEvent.elementUpdated`.
- **Map mutation signals**: `TissueMap` additions and removals now emit `MapEntry<K, V>` payloads, and map updates emit `EntryUpdatedRecord<K, V>` payloads classified as `TissueEvent.entryUpdated`.

### Fixed

- **Event classification storage**: Resolved a regression where `TissueEvent` enum values could not be stored through the underlying pulse record machinery, which caused silent mutation failures across all collection types.
- **Map mutation casts**: Restored `TissueMap` add/update/remove operations against identity-keyed stores by using the store's map-like interface instead of an incompatible `Map<K, V>` cast.
- **Queue removals**: Corrected `removeFirst`/`removeLast` to return the removed element again, and fixed `removeLast` validating the wrong element.
- **Set batch removals**: Materialized lazy removal iterables in `clear`, `removeAll`, `removeWhere`, `retainAll`, and `retainWhere` so elements are no longer skipped during iteration.

### Tests

- **Event API coverage**: Updated `tissue_pulse_test.dart` and `tissue_receptor_test.dart` to assert the new `TissueEvent` classification API and record payloads.
- **Full suite**: All `cell_tissue` tests pass against the unified event model.

### Docs

- **Mitose pipeline**: Added a prominent README callout for the umbrella **Mitose pipeline** — the AI-executable orchestration in the root [`guide/`](https://github.com/simon-m-lee/cell/tree/master/guide) that turns a business requirement into a Cell + Flow + Tissue solution with its BRD, WalkThrough, Demo, ARCHITECTURE, and FEATURES documents. This package contributes the **Tissue-layer** rules via [`guide/HowTo-Mitose-Tissue.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Tissue.md).

[Mitosis (1.0.0-rc.7)]: https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue

## [Mitosis (1.0.0-rc.6)] - Release Candidate

Pub.dev hygiene release. No public API changes.

### Changed

- **TestTissue constructor formatting**: Reformatted the `TestTissue` and `TestTissue.chain` constructor signatures for consistency and analyzer hygiene.

[Mitosis (1.0.0-rc.6)]: https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue

## [Mitosis (1.0.0-rc.5)] - Release Candidate

Pub.dev score remediation release. No public API changes.

### Fixed

- **Dependency alignment**: Tightened `cell` constraint to `^1.0.0-rc.4` so the package analyzes against the current core release line (previously `^1.0.0-rc.2` could resolve to `cell` `1.0.0-rc.3`, whose stricter `Receptor` interface broke static analysis on pub.dev).
- **Static analysis hygiene**: Resolved remaining `unrelated_type_equality_checks` lints in `tissue_value_test.dart` and reformatted the package with `dart format`.
- **License detection**: Replaced the custom dual-license notice with the canonical MIT and Apache-2.0 texts so pub.dev recognizes the OSI-approved license.
- **Example detection**: Added `example/cell_tissue_example.dart` — a runnable quick start matching pub.dev's example file conventions.
- **Dev dependency**: Replaced the local `cell_flow` path dev-dependency with a version constraint (`^1.0.0-rc.4`).

[Mitosis (1.0.0-rc.5)]: https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue

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