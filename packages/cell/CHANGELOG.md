## Mitosis (1.0.0-rc.1) - Release Candidate

This release promotes the **cell** core from **Beta (Public Preview)** to **Release Candidate**. The Switching Fabric, Core 16 operators, `Cell.valve`, `OpenCell.perform`, context / deputy / commons, and both transaction APIs are covered by a passing public-API unit-test suite with measured `lib/` coverage. Breaking changes remain possible before a versioned 1.0 stable, but they should follow documented contracts rather than silent private-API drift.

### Developmental Status
- **Code Stage:** RC (Release Candidate).
- **Stability:** Public APIs for cells, pulses, operators, transactions, integrity gates, context, deputy, and commons utilities are exercised end-to-end. This is not a production-readiness certificate: the package is unpublished and has no independent security or correctness audit.
- **Goal:** Freeze the Mitosis public surface for 1.0 feedback; gather remaining issues on operator ergonomics, ingest/observe pipelines, transaction/`txApply` orchestration, and deputy attenuation.

### Hardening
- **Unit tests:** 1115 tests in 20 files under `packages/cell/test/`; last full run **1115 passed / 0 failed / 0 skipped** (~7 s with coverage).
- **Line coverage:** **95.9%** of instrumented `lib/` lines (3397 / 3541), collected with `dart test --coverage=coverage` and merged to lcov. See `TEST_VERIFICATION.md`.
- **Dedicated suites:** `test_context.dart`, `test_cell_policy.dart`, `test_test_rule_meta.dart`, `test_commons.dart`, `test_deputy.dart`, plus operator phases 1–4 and core type suites.
- **High-coverage surfaces:** `internal/cell.dart` 100%, `internal/receptor.dart` 100%, `operator_debounce.dart` 100%, `internal/test_cell.dart` 100%, `value.dart` 100%, `test_cell.dart` 100%, `test_rule.dart` 100%, `internal/value.dart` 100%, `internal/pulse_extensions.dart` 100%, `synapses.dart` 100%, `internal/deputy_context.dart` 99.1%, `internal/synapses.dart` 98.9%, `operator_tx_apply.dart` 97.8%, `commons.dart` 97.6%, `deputy.dart` 100%, `internal/deputy.dart` 94.4%, `cell_policy.dart` 97.6%, `test_rule_meta.dart` 100%, `internal/nucleus.dart` 94.1%, `internal/pulse.dart` 90.4%, `receptor.dart` 90.5%.
- **Contract alignment:** Suites drive operators through `Cell.ingress` / `Cell.observe`, synthesis aggregators return `Pulse`, receptors activate before `call`, `Synapses.link` requires host identity, and `Cell.txApply` enqueues only `modifiable` tear-offs. Test files are `test_*.dart` (bare `dart test` finds nothing).

### Fixes
- `TestCell.readOnly` is no longer equal to `TestCell.allowAll` (empty-record collision); deputy attenuation uses `identical` against default sentinels.
- `Nucleus.evolve` forwards `override`; deputies store context, bind, synapses, and composed `testRule` instead of falling back to the principal.
- Deputy `testRule` layering uses `TestCell.chain` so `host` stays `Cell?` (not `Never?` from `TestPasses.+`).
- `MaxLength` host quota and object length are independent checks (no else-if skip).
- `EphemeralPolicy.call` forwards arguments; `SyncSet` / `SyncQueue` / `AsyncPriorityQueue` mutations return the lock `Future`.
- `SyncQueue.addFirst` / `addLast` alias `add` without fire-and-forget; `AsyncPriorityQueue.addLast` no longer recurses infinitely.
- Context `fromEntries` preserves taxonomy/topology/version; `ContextBase` parent lookup and `[]` walk the parent chain; `DeputyContext.auditLevel` reads `Mandate.auditLevel`.
- `AsyncSynapses` shares the source filter, policy, buffer, timer, and relay (as documented); relay cycle-check uses `_source.every` rather than the empty async iterable.
- `FilterRule` parent lookup reads `_record.parent` (the field the constructors store), so a chained parent actually runs.
- A pulse with `onComplete` now seeds its branch counter at `1`, so empty synapses can complete it instead of throwing on a null box.
- `PropagationStrategy.sample` cancels its `Timer.periodic` heartbeat when the last observer is unlinked, so the timer does not leak for the isolate lifetime.
- `NucleusBase` stores a hosted `ephemeralPolicy` on the inheritable flyweight (bit 8); `_Nucleus.clone` copies it. `Nucleus.isInvalidated` / `Cell.isInvalidated` then follow the policy, including a deputy that inherits via the principal.
- `fromFuture` failures emit a pulse with `type: 'error'` and the error as payload (they are not swallowed).
- `_DebounceState.cancel` now runs on re-arm, `Duration.zero`, timer fire, and output invalidation (it was previously unused).
- `TestPasses` / `TestCell.readOnly` `action` consult `_checkArguments` / `_checkActionRules`; `readOnly.link` accepts a `Cell` host.

### Documentation
- `TEST_VERIFICATION.md` inventories all 20 suites, measured 95.9% `lib/` coverage, and run commands (`test_*.dart` files must be passed explicitly).
- `Receptor.pipeline` accepts `reaction`, `init`, `user`, and `isGoverned` so flyweight mask combinations are reachable from the public factory.
- `Cell.debounce` accepts `ephemeralPolicy`; a hosted policy uses a governed output receptor so TTL / event-limit reclaim cancels a pending timer.
- `FEATURES.md` catalogs the public surface at RC `1.0.0-rc.1` (no longer labeled Alpha / Beta preview).
- `PropagationStrategy.sample` has dedicated sync and async cases: the first pulse is heartbeated after `throttleTime`; later ticks of that same pulse are dropped by the cycle checker; unlink stops the timer.
- `PulseExtension.map` / `cast` are restored: call through `PulseExtension(pulse)` because `Pulse` is an `Iterable`; results are `EvolvedPulse` from `evolve(pulse:)`.
- `Nucleus.isInvalidated` / `Cell.isInvalidated` follow a hosted `EphemeralPolicy` stored on the nucleus inheritable record.
- `ValueNucleus.from` / `evolve`, `ValueCell.terminal` / `receptor`, nested `unmodifiable`, standalone `TestRule` async parent/chain, and `OpenCell.async` emit/ingest are covered.

### Still RC
- Not published to pub.dev; no independent security or correctness audit.
- Remaining lower-coverage files include `context.dart` (90.3%), `internal/pulse.dart` (90.4%), and `receptor.dart` (90.5%).
- HowTo examples may still mention private APIs (`_nucleus`); the unit tests do not.
- Transaction / compensation internals have not been independently reviewed end-to-end.

---

## Mitosis (1.0.0-preview.4) - Public Preview

This release further hardens the **cell** core with more vigorous unit tests. Dedicated suites now cover Context / DeputyContext / PulseContext, `EphemeralPolicy`, annotation `TestRule`s, `commons.dart` collections, Cell / OpenCell deputy, `ValueCell.async`, remaining synapses strategies including sample/async debounce/throttle/audit/buffered/retry/resilient, `PulseExtension.map` / `cast` against the current `evolve(pulse:)` contract, `FilterRule` parent / `fromRecord` / equality, `ValueNucleus` / `ValueCell` constructors, and standalone `TestRule` async parent/chain. Overall instrumented **`lib/` line coverage has reached 95.0%**.

### Developmental Status
- **Code Stage:** Beta (Public Preview).
- **Stability:** Public APIs for cells, pulses, operators, transactions, integrity gates, context, deputy, and commons utilities are exercised end-to-end. Breaking changes remain possible before a versioned 1.0 stable, but they should follow documented contracts rather than silent private-API drift.
- **Goal:** Wider preview use of the core package; gather feedback on operator ergonomics, ingest/observe pipelines, transaction/`txApply` orchestration, and deputy attenuation.

### Hardening
- **Unit tests:** 1107 tests in 20 files under `packages/cell/test/`; last full run **1107 passed / 0 failed / 0 skipped** (~8 s with coverage).
- **Line coverage:** **95.0%** of instrumented `lib/` lines (3353 / 3529), collected with `dart test --coverage=coverage` and merged to lcov. See `TEST_VERIFICATION.md`.
- **New dedicated suites:** `test_context.dart`, `test_cell_policy.dart`, `test_test_rule_meta.dart`, `test_commons.dart`, `test_deputy.dart`.
- **High-coverage surfaces:** `internal/cell.dart` 100%, `value.dart` 100%, `test_cell.dart` 100%, `test_rule.dart` 100%, `internal/value.dart` 100%, `internal/pulse_extensions.dart` 100%, `synapses.dart` 100%, `internal/deputy_context.dart` 99.1%, `internal/synapses.dart` 98.9%, `operator_tx_apply.dart` 97.8%, `commons.dart` 97.6%, `deputy.dart` 100%, `internal/deputy.dart` 94.4%, `cell_policy.dart` 97.6%, `test_rule_meta.dart` 100%, `internal/nucleus.dart` 94.1%, `internal/pulse.dart` 90.4%, `receptor.dart` 90.0%, `internal/receptor.dart` 87.4%, `internal/test_cell.dart` 78.3%.
- **Contract alignment:** Suites drive operators through `Cell.ingress` / `Cell.observe`, synthesis aggregators return `Pulse`, receptors activate before `call`, `Synapses.link` requires host identity, and `Cell.txApply` enqueues only `modifiable` tear-offs.

### Fixes
- `TestCell.readOnly` is no longer equal to `TestCell.allowAll` (empty-record collision); deputy attenuation uses `identical` against default sentinels.
- `Nucleus.evolve` forwards `override`; deputies store context, bind, synapses, and composed `testRule` instead of falling back to the principal.
- Deputy `testRule` layering uses `TestCell.chain` so `host` stays `Cell?` (not `Never?` from `TestPasses.+`).
- `MaxLength` host quota and object length are independent checks (no else-if skip).
- `EphemeralPolicy.call` forwards arguments; `SyncSet` / `SyncQueue` / `AsyncPriorityQueue` mutations return the lock `Future`.
- `SyncQueue.addFirst` / `addLast` alias `add` without fire-and-forget; `AsyncPriorityQueue.addLast` no longer recurses infinitely.
- Context `fromEntries` preserves taxonomy/topology/version; `ContextBase` parent lookup and `[]` walk the parent chain; `DeputyContext.auditLevel` reads `Mandate.auditLevel`.
- `AsyncSynapses` shares the source filter, policy, buffer, timer, and relay (as documented); relay cycle-check uses `_source.every` rather than the empty async iterable.
- `FilterRule` parent lookup reads `_record.parent` (the field the constructors store), so a chained parent actually runs.
- A pulse with `onComplete` now seeds its branch counter at `1`, so empty synapses can complete it instead of throwing on a null box.
- `PropagationStrategy.sample` cancels its `Timer.periodic` heartbeat when the last observer is unlinked, so the timer does not leak for the isolate lifetime.
- `NucleusBase` stores a hosted `ephemeralPolicy` on the inheritable flyweight (bit 8); `_Nucleus.clone` copies it. `Nucleus.isInvalidated` / `Cell.isInvalidated` then follow the policy, including a deputy that inherits via the principal.

### Documentation
- `TEST_VERIFICATION.md` inventories all 20 suites, measured 95.0% `lib/` coverage, and run commands (`test_*.dart` files must be passed explicitly; bare `dart test` finds nothing).
- `PropagationStrategy.sample` has dedicated sync and async cases: the first pulse is heartbeated after `throttleTime`; later ticks of that same pulse are dropped by the cycle checker; unlink stops the timer.
- `PulseExtension.map` / `cast` are restored: call through `PulseExtension(pulse)` because `Pulse` is an `Iterable`; results are `EvolvedPulse` from `evolve(pulse:)`.
- `Nucleus.isInvalidated` / `Cell.isInvalidated` follow a hosted `EphemeralPolicy` stored on the nucleus inheritable record.
- `ValueNucleus.from` / `evolve`, `ValueCell.terminal` / `receptor`, nested `unmodifiable`, standalone `TestRule` async parent/chain, and `OpenCell.async` emit/ingest are covered.

### Still Beta
- Not published to pub.dev; no independent security or correctness audit.
- Remaining lower-coverage files include `internal/test_cell.dart`, `internal/receptor.dart`, and `operator_debounce.dart`.
- HowTo examples may still mention private APIs (`_nucleus`); the unit tests do not.

---

## Mitosis (1.0.0-preview.3) - Public Preview

This release hardens the **cell** core and advances the project from **Alpha** to **Beta**. The Switching Fabric, Core 16 operators, `Cell.valve`, and `OpenCell.perform` are covered by a passing unit-test suite aligned to public APIs. The architecture is no longer a prototype inventory; it is a Beta public preview with measured coverage and documented contracts.

### Developmental Status
- **Code Stage:** Beta (Public Preview).
- **Stability:** Public APIs for cells, pulses, operators, transactions, and integrity gates are exercised end-to-end. Breaking changes remain possible before a versioned 1.0 stable, but they should follow documented contracts rather than silent private-API drift.
- **Goal:** Wider preview use of the core package; gather feedback on operator ergonomics, ingest/observe pipelines, and transaction/`txApply` orchestration.

### Hardening
- **Unit tests:** 695 tests in 15 files under `packages/cell/test/`; last full run **695 passed / 0 failed / 0 skipped** (~4 s).
- **Line coverage:** **62.7%** of instrumented `lib/` lines (2187 / 3486), collected with `dart test --coverage=coverage` and merged to lcov. See `TEST_VERIFICATION.md`.
- **Contract alignment:** Suites drive operators through `Cell.ingress` / `Cell.observe`, synthesis aggregators return `Pulse`, receptors activate before `call`, `Synapses.link` requires host identity, and `Cell.txApply` enqueues only `modifiable` tear-offs.
- **`ingest` completion:** `serializedCompletion: true` (the default on `StateHandle` / `IngressHandle`) now waits until the pulse is processed, not merely queued.
- **Operators under test:** `state`, `ingress`, `observe`, `derive`, `debounce`, `throttle`, `distinct`, `synthesis`, `asyncMap`, `hub`, `switchMap`, `fromFuture`, `fromStream`, `sanitized`, `open`, `transaction`, `txApply`, plus **`Cell.valve`** and **`OpenCell.perform`**.
- **Core types under test:** `Cell`, `Pulse` (including `compareTo` by timestamp), `Nucleus` / `Nucleolus`, `Receptor`, `Instruction`, `Synapses`, `TestCell`, `PropagationPolicy`, `SynthesisCell`.

### Fixes
- Deputy identity: `cell == deputy` and `hashCode` walk to the principal; `Cell.deputy` forwards `DeputyContext`.
- `Pulse.compareTo` by timestamp is deterministic (waits for the clock to advance); hops `0` is no longer treated as TTL-invalid.
- Nucleus activation/`fromNucleus` clone-on-second-hydrate; nucleus timestamps are `DateTime`.
- Instruction `+` / `chain` short-circuit on null and return the transformed pulse; custom `strategy` is stored and invoked.
- Receptor templates activate on `Cell` construction; `Receptor.async` hooks see drops.
- `TestPasses` / `TestCell.readOnly` participate in `TestCell` identity; `TestCell.call` returns `FutureOr`.
- PropagationPolicy value equality; leading throttle; `Duration.zero` means no delay / no lockout; buffered flush on size and timer.
- `ValueCell.toString` is `ValueCell<$V>($value)`.

### Documentation
- `TEST_VERIFICATION.md` inventories all 15 suites, measured coverage, and run commands (`test_*.dart` files must be passed explicitly; bare `dart test` finds nothing).
- `FEATURES.md`, `ARCHITECTURE.md`, `README.md`, and `KNOWN_ISSUES.md` describe the public surface, Alpha-era gaps that remain (unpublished, no audit, low-coverage Context/deputy/commons), and HowTo vs unit-test contracts.

### Still Beta
- Not published to pub.dev; no independent security or correctness audit.
- Context / DeputyContext / commons / `test_rule_meta` remain low line-coverage.
- `PulseExtension.map` / `cast` tests are commented out; several `PropagationPolicy` strategies have no dedicated cases.
- HowTo examples may still mention private APIs (`_nucleus`); the unit tests do not.

---

## Mitosis (1.0.0-preview.2) - Public Preview

This marks the latest pre-release of the Cell framework. "Mitosis" has reached functional stability, transitioning from a reactive fabric prototype to a comprehensive, high-performance state management solution for Dart.

### New Features & Improvements
- **16 Core Operators**: The framework now features a stabilized "Standard Entry Tier" of 16 static operators that cover the vast majority of reactive programming needs:
    - **Entry Points**: `state`, `ingress`, `observe`, `derive`
    - **Shape & Flow**: `debounce`, `distinct`, `throttle`
    - **Async & Bridges**: `asyncMap`, `fromFuture`, `fromStream`
    - **Combination & Routing**: `synthesis`, `hub`, `switchMap`, `sanitized`
    - **Orchestration**: `transaction`, `txApply`
- **Extended Flow Control**: Added specialized operators for fine-grained signal pressure control, including `valve`. `throttle` is now part of the core 16.
- **Comprehensive Example Suite**: Added a wealth of examples in `/example` to demonstrate common patterns, architectural walkthroughs, and advanced usage, including:
    - **Walkthroughs**: `receptor_pipeline_walkthrough.dart`, `instruction_pipeline_walkthrough.dart`
    - **Real-world Scenarios**: `stability_search_demo.dart` (debounced search), `atomic_multi_update.dart` (consistent multi-cell updates), `transaction_demo.dart`.
    - **Feature Demos**: `hub_demo`, `async_map_demo`, `sanitized_demo`, `synthesis_demo`, `valve_demo`, `throttle_demo`, `distinct_demo`, and more.
- **Production Hardening**: Verified thread-safety and atomic consistency for complex multi-cell updates, and optimized the Switching Fabric for high-performance signal propagation.
- **Forensic Traceability**: Enhanced `traceId` and provenance metadata across asynchronous boundaries and complex transformations.
- **New "How-To" Learning Suite**: Added a comprehensive set of guides in `/guide` to help developers master the framework, including:
    - `HowTo-Start.md`: A complete quick-start path.
    - `HowTo-16_Essential_Operators.md`: Deep dive into the core entry tier.
    - `HowTo-Receptor.md`, `HowTo-Synapses.md`, `HowTo-TestCell.md`, `HowTo-Instruction.md`: Specialized pipeline guides.
    - `HowTo-Pulse.md`, `HowTo-Context.md`, `HowTo-Nucleus.md`: Core architectural components.
    - `HowTo-Transaction.md`, `HowTo-TransactionOnApply.md`: Atomic updates and orchestration.
    - `HowTo-PulseContext.md`, `HowTo-DeputyContext.md`: Advanced metadata and attenuation.
    - `HowTo-EphemeralPolicy.md`, `HowTo-PulseEphemeralPolicy.md`, `HowTo-PropagationPolicy.md`: Fine-grained lifecycle and propagation control.
    - `HowTo-Advanced.md`: Complex patterns and edge cases.

---

## Mitosis (1.0.0-preview.1) - Public Preview

This is the initial "Mitosis" release of the Cell Framework, currently in a **Preview** stage for public preview. This release marks the first stable division of the framework's core concepts into a functional reactive fabric.

### Architectural Foundation
- **The Switching Fabric**: A decentralized reactive network where signals propagate based on semantic relevance.
- **Managed Nodes (Cells)**: Autonomous units of state and logic that govern their own internal invariants.
- **Causal Signals (Pulses)**: High-integrity data carriers with built-in traceability (`traceId`) and justification.
- **Reactive Update Cycle**: A strict three-phase pipeline (Ingress, Transformation, Egress) for every state mutation.

### Core Features
- **The Ergonomic Entry Tier**: Nine core static constructors (`ingress`, `value`, `hub`, `observe`, `valve`, `tissue`, `derive`, `sanitized`, `open`) for simplified developer experience.
- **Capability-Based Access Control (CBAC)**: Integrated security model using **Reciprocal Handshakes** for bidirectional mutual authorization.
- **Integrity Gates**: Policy Enforcement Points (via `TestCell`) that decouple validation law from business logic.
- **The Deputy Pattern**: Support for privilege attenuation and logical isolation through defensive proxies.
- **Forensic Traceability**: Mitigation of comprehension debt via `ReasoningStrategy` and `justification` metadata.

### Developmental Status
- **Code Stage**: Preview (Public Preview).
- **Goal**: Gathering feedback on the ergonomics of the **Switching Fabric** and the effectiveness of **Scene-Driven Governance**.
- **Naming Convention**: Major architectural milestones will follow biological nomenclature. "Mitosis" represents the birth and initial division of the framework.
