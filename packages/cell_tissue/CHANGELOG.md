# Changelog
All notable changes to **cell_tissue** are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Version numbers follow [SemVer](https://semver.org/). **Tissue** is the
release codename; it is not part of the SemVer string.

## Tissue (1.0.0) - Stable Release

Stable release formalizing the **Forensic Application Layer** for reactive collections. This version establishes the audit-ready command model, finalizes factory signatures, and completes reactive engine hardening.

### Added

- **`### AI Agent Guide` doc blocks**: `Tissue`, `TissueList`, `TissueSet`, `TissueMap`, `TissueQueue`, `TissueValue`, `TestTissue`, `UnmodifiableTissue`, and `TissuePulse` now carry the standardized AI-facing doc block: layer assertion, when to use / when NOT to use (with `{@macro}` anti-patterns), a `Live signature:` pin, sibling disambiguation, a `Guide:` pointer with a stable HowTo anchor, cross-layer guidance, stability, self-verification steps, and a minimal compilable example.
- **Anti-pattern templates**: new `lib/doc/ai_anti_patterns.dart` (`ai-do-not-testcell-on-tissue`, `ai-do-not-dart-list-as-system-of-record`, `ai-do-not-drain-tissuequeue`, …).
- **API chooser**: new generated `lib/doc/api_chooser.dart` — the full BRD-sentence → book decision matrix, rendered on pub.dev and generated from the guide blocks.
- **AI preflight**: new `tool/ai_preflight.dart` — a one-line check for every `Live signature:` pin and the HowTo version pins; prints a paste-ready Demo-header provenance block; exits non-zero on drift.
- **Executable doc examples**: new `tool/generate_ai_examples.dart` + `test/ai_guide_examples_test.dart` — every `Minimal compilable example` is generated, compiled with `dart analyze`, executed, and asserted to exit 0 in CI.
- **Seam rules in-package**: new `test/seam_test.dart` — no `testRule: TestCell` on any Tissue constructor in `example/`; no `TestTissue` on Cell factories.
- **Matrix freshness + failure log**: new `tool/generate_api_chooser.dart` + `test/api_chooser_up_to_date_test.dart`, and `tool/ai_failure_log.dart` + `tool/ai_failure_log.jsonl` for structured, quarterly-reviewed AI failure records.
- **Forensic command model bridge**: `TissueBase.apply<R>` routes `ApplyCommand` records through the tissue mutation dispatch engine and returns auditable `ApplyOutcome`s (`ApplyAccepted` / `ApplyRejected` / `ApplyStaged`), with transaction staging via `ApplyTransactionScope.enqueueCommand`. Read-only async projections reject commands.
- **`tissue_apply_command_test.dart`**: New coverage for the command model on collections: dispatch routing, atomic staging, compensation rollback, and unmodifiable rejection.

- **Semantic fitness suite** (`test/tissue/fitness/`): seven contract tests asserting the documented tissue contracts the benchmarks depend on — live unmodifiable views, deep element projection, batch metadata preservation, `TestTissue` user propagation, growable defaults, unknown-dispatch rejection, and public-nucleus casts.

- **Benchmark suite**: New `benchmark/` directory mirroring the `cell` package's suite — per-shape construction and mutation micro benchmarks with plain-collection controls, end-to-end observer-delivery benchmarks with listener-callback controls, a VM-service per-tissue footprint benchmark, a feature-fair `vs_plain_collections` comparison, a PR-suite runner (`benchmark/runner.dart`), a 15% regression gate (`benchmark/compare.dart`), and a checked-in `baseline.json` (30 tracked results).

### Changed

- **Library docs**: the `cell_tissue` library doc now opens with the layer-contract public-surface top table (the five collection types and their Demo roles) and an explicit "Do NOT use this package for" list.
- **README**: opens with the AI-starter preamble (Install and import → "AI agents start here" → a six-row BRD elevator table) before the existing content.
- **Curated examples**: `cell_tissue_example.dart` carries a fixed AI-facing header (`What it demonstrates` / `Which BRD sentence picks it`).
- **Docs**: new `CONTRIBUTING-AI-DOC.md` (normative block spec) and `CONTRIBUTING.md`.
- **`evolve` factory signatures**: The `principal` parameter of `TissueNucleus.evolve`, `TissueListNucleus.evolve`, `TissueMapNucleus.evolve`, `TissueQueueNucleus.evolve`, `TissueSetNucleus.evolve`, and `TissueValueNucleus.evolve` is now a positional argument instead of a named parameter - e.g., `TissueListNucleus.evolve(principal, ...)`. All other overrides remain named parameters.
- **`Tissue.apply` retired**: The loosely typed dynamic `apply` gateway has been removed from the public surface. Mutation routing now lives in an internal `dispatch` engine invoked by `apply<R>(ApplyCommand)`.
- **Dependency alignment**: Tightened constraints to `cell` `^1.1.0` and `cell_flow` `^1.0.0`.

- **Unmodifiable map seeding**: `UnmodifiableTissueMapBase` now seeds its container from the `entries` parameter and links cell-valued entries — the factory, `fromNucleus`, and `create` entry points previously returned empty maps.

### Fixed

- **`TissueQueue` hardening**: Corrected `capacity: 0` handling in `_queueAdd` to return `false` (reject) instead of throwing `StateError` on empty-queue eviction. Implemented `>=` defensive checks for overflow prevention.
- **Sentinel link hooks**: `TestTissue.allowAll` and the `never` sentinel now return `true` from their `link` hooks, matching the documented "every hook returns true" contract (the previous `false` reversed allow-all semantics for direct `validate.link` callers).
- **Deputy sync validation**: `_tissueStack` now honors the deputy's own `validate.element` rules during principal sync (partial sync applies only the accepted subset, per the documented contract) and no longer drops legitimate `null` elements for nullable element types.
- **Structural equality for tissue events**: `TissueEvent` implements `==`/`hashCode` on its event bitmask, so composite events compare equal when their flags match.
- **Safe event source casts**: `TissueEventShell.source` and `TissuePulseBase.source` return `null` for non-tissue kernel sources instead of throwing a `TypeError`.
- **List resize goes through dispatch**: `TissueList.length =` now routes through the dispatch engine (validation + unmodifiable enforcement) instead of mutating the store directly; resizes are structural and emit no per-element pulses (documented).
- **TissuePulse type slot**: The `TissueEvent` classification is now stored in the pulse's `type` slot directly (`PulseBase.mask` accepts dynamic type tags); the `user` slot is no longer overloaded, so user metadata survives and is inherited cleanly.
- **Container/queue hardening**: `TissueNucleusBase.container` resolves via an explicit type test and principal walk instead of an exception-driven fallback; `_queueAdd` no longer downcasts to `TissueQueueBase` (custom implementations are treated as unbounded).
- **Deputy sync diagnostics**: `_tissueStack` asserts in debug builds when a pulse's element type does not line up with the deputy's type parameter, and documents that `container.remove` tears down linked element egress.
- **API contract documentation**: `TissueList.operator +` documents the left-operand-wins asymmetry; `sort`/shuffle document sync-validation-only semantics; `TissueValue.set` documents that `false` covers both rejection and no-op updates; `TissueValueMixin.dispatch` documents the trusted non-whitelisted execution path; `_TestTissueAllowAll._run` drops the `dynamic` dispatch casts.
- **Nucleus downcast**: `_TissueSet.fromNucleus` casts to the abstract `TissueSetNucleusBase` instead of the private concrete class, so custom nucleus implementations no longer crash at construction.
- **Live unmodifiable views**: The list/set/map/queue/value view factories no longer pass a container strategy (which materialized a fresh store and seeded a stale snapshot) — views inherit the bind's store through the principal chain, and `_tissueStack` skips re-applying deltas into a shared store. Views are now truly zero-copy and live (the historical copy bug).
- **Deep immutability projection**: Unmodifiable views project child `Cell`s as their `.unmodifiable` deputies in `elementAt`, `operator []`, `iterator`, and `toSet` (the projection was documented but not implemented in most read paths).
- **`TissuePulse.batch` metadata**: The batch factory now forwards `policy`/`context`/`type`/`source`/`step`/`priority`/`onComplete`/`onError`/`onProgress`/`scrutinize` to the collective (all were silently dropped), and collectives report `isComposite: true` per their docstring.
- **`TestTissue` user metadata**: The constructor now stores `user` even when no `parent` is supplied (previously dropped); user metadata reaches rules as documented.
- **`TissueValueMixin.dispatch`**: Non-whitelisted functions are rejected (return `null`) instead of executing unvetted — unmodifiable values can no longer be mutated through `apply` with an unknown function.

### Tests

- Updated the nucleus factory tests (`tissue_list_test.dart`, `tissue_map_test.dart`, `tissue_queue_test.dart`, `tissue_set_test.dart`, `tissue_value_test.dart`) to the new positional `principal` signature.
- Migrated the collection, pulse, receptor, and txApply integration tests from the retired dynamic gateway to `apply<R>(ApplyCommand)` / `enqueueCommand`.


## Tissue (1.0.0-rc.9) - Release Candidate

Docs and dependency-alignment release. No public API changes.

### Changed

- **Dependency alignment**: `cell` tightened to `^1.0.0-rc.8` and `cell_flow` raised to `^1.0.0-rc.9`.

### Docs

- **New guides**: Added `guide/HowTo-Tissue.md` and `guide/HowTo-Tissue-Advanced.md` covering the reactive collection surface and advanced tissue patterns.
- **Nucleus KDoc overhaul**: Rewrote the `_TissueNucleus` documentation with the standard `### When to use` / `### How it works` / `### Non-obvious` pedagogical structure (internal, docs only).
- **Changelog convention**: Aligned the CHANGELOG heading convention with the umbrella repository.
- **API reference**: Regenerated `doc/api` after a fresh `dart doc .` run.


## Tissue (1.0.0-rc.8) - Release Candidate

### Added

- **AI command instruction family relocated from `cell_flow`**: `AiTissueCommand`, `AiTissueCommandBatch`, `AiTissueCommandWithRetry`, and the interpreter domain (`Interpreter`, `HttpInterpreter`, `StubInterpreter`, `TrafficLog`, `AiConfig`) now ship in `cell_tissue` under `src/instruction/ai_tissue_command*.dart` and are exported from `cell_tissue.dart`. `cell_flow` becomes a regular dependency of this package.
- **`TissueMap.put`**: New explicit upsert operation. `put(key, value)` replaces the value of an existing key (emitting `TissueEvent.entryUpdated` with an `EntryUpdatedRecord<K, V>` payload) or inserts a new entry (emitting `TissueEvent.elementAdded`). It is the named counterpart of the `[]=` operator and is whitelisted in `modifiable`, the `apply` gateway, and `ModifiableMapAsync`.

### Changed

- **`TissueMap.[]=` is now a true upsert**: `map[key] = value` replaces an existing value instead of silently ignoring the assignment. Insertions still emit `TissueEvent.elementAdded`; replacements emit `TissueEvent.entryUpdated` with `(key, before, after)`. `add` remains the strict append-only operation and still returns `false` when the key already exists. Code that relied on the previous set-if-absent behaviour of `[]=` should switch to `add`.
- **Element validation action vectors**: `update` and `updateAll` now validate new values with their own action identity (`update`/`updateAll`) instead of `add`, so action-aware `TestTissue` rules can distinguish insert and replace vectors.
- **`update` insert events**: `update` on a missing key with `ifAbsent` now emits `TissueEvent.elementAdded` (previously `entryUpdated`) to match the insert/replace event contract.

### Fixed

- **`TissueValue` joins `Cell.transaction`**: `begin`, buffered `update`, commit, validation failures, and unmodifiable projections now behave like `Cell.state`. Tissue nuclei allocate their synchronisation lock again (`TissueNucleusBase.mask` carries a `Lock` for every `forceLock == false` branch), `TissueBase` and `TissueNever` expose it through the public `CellBase.lock` accessor, and the transaction commit path writes through the public `ValueCell.value` setter so cross-package `ValueCell` implementations no longer hit the private `_nucleus` / `_emit` members (three new `tissue_value_test.dart` cases).
- **Reactive link lifecycle on replacement**: `put`, `update`, and `updateAll` now unlink a replaced `Cell` value (when it no longer occurs in the store) and link the new `Cell` value. `remove`, `removeWhere`, and `clear` now unlink removed `Cell` values.
- **Deputy mutation gateway**: Composing `TestTissue.allowAll` with another rule via `+` previously produced a `TestTissue<Never, Never>` whose `action` gate rejected every real host, silently swallowing all mutations performed through deputies. `allowAll + allowAll` now returns `allowAll` itself, and other compositions use a host-widened wrapper so deputies remain mutable when their rules permit it (read-only deputies still block).
- **Bound map mirroring**: The receptor sync engine now mirrors `TissueEvent.entryUpdated` pulses into a bound `TissueMap`'s store, so maps created with `bind:` reflect value replacements from their source.

### Tests

- **Upsert coverage**: Added `tissue_map_test.dart` cases for `[]=`/`put` replacement, insert-vs-replace pulse payloads, append-only `add`, test-rule rejection of replacements, `Cell` value swaps, `modifiable`/`apply` routing, unmodifiable and async `put` rejection, transaction staging of `put`, and deputy shared-storage replacement (including read-only deputy blocking).


## Tissue (1.0.0-rc.7) - Release Candidate

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


## Tissue (1.0.0-rc.6) - Release Candidate

Pub.dev hygiene release. No public API changes.

### Changed

- **TestTissue constructor formatting**: Reformatted the `TestTissue` and `TestTissue.chain` constructor signatures for consistency and analyzer hygiene.


## Tissue (1.0.0-rc.5) - Release Candidate

Pub.dev score remediation release. No public API changes.

### Fixed

- **Dependency alignment**: Tightened `cell` constraint to `^1.0.0-rc.4` so the package analyzes against the current core release line (previously `^1.0.0-rc.2` could resolve to `cell` `1.0.0-rc.3`, whose stricter `Receptor` interface broke static analysis on pub.dev).
- **Static analysis hygiene**: Resolved remaining `unrelated_type_equality_checks` lints in `tissue_value_test.dart` and reformatted the package with `dart format`.
- **License detection**: Replaced the custom dual-license notice with the canonical MIT and Apache-2.0 texts so pub.dev recognizes the OSI-approved license.
- **Example detection**: Added `example/cell_tissue_example.dart` — a runnable quick start matching pub.dev's example file conventions.
- **Dev dependency**: Replaced the local `cell_flow` path dev-dependency with a version constraint (`^1.0.0-rc.4`).


## Tissue (1.0.0-rc.4) - Release Candidate

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
