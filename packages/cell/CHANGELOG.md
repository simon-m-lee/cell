## Cell (1.1.0) - Stable

### AI-facing documentation and verification

- **`### AI Agent Guide` doc blocks**: `Cell` and ~24 top public symbols (`Cell.ingress`, `Cell.state`, `Cell.observe`, `Cell.derive`, `Cell.synthesis`, `Cell.sanitized`, `Cell.hub`, `Cell.open`, `Cell.valve`, `Cell.debounce`, `Cell.throttle`, `Cell.distinct`, `Cell.asyncMap`, `Cell.fromFuture`, `Cell.fromStream`, `Cell.switchMap`, `Cell.transaction`, `Cell.txApply`, `Cell.governed`, `Cell.fromNucleus`, `Cell.deputy`, `Cell.unmodifiable`, `Pulse`, `TestCell`) now answer the seven AI questions in fixed order — layer assertion, when to use, when NOT to use, a `Live signature:` pin, sibling disambiguation, a `Guide:` pointer with a stable HowTo anchor, cross-layer guidance, stability — plus self-verification steps and a minimal compilable example.
- **Anti-pattern templates**: new `lib/doc/ai_anti_patterns.dart` holds dartdoc `{@template}` / `{@macro}` definitions (`ai-do-not-create-cell-as-policy`, `ai-do-not-observe-to-decide`, `ai-do-not-use-cell-transaction-for-tissue`, …) so shared warnings stay compile-time-checkable instead of duplicated prose.
- **API chooser**: new generated `lib/doc/api_chooser.dart` — the full BRD-sentence → factory decision matrix, rendered on pub.dev and generated from the guide blocks.
- **AI preflight**: new `tool/ai_preflight.dart` verifies every `Live signature:` pin and the HowTo version pins against the resolved versions; exits non-zero on drift and prints a paste-ready Demo-header provenance block.
- **Executable doc examples**: new `tool/generate_ai_examples.dart` + `test/ai_guide_examples_test.dart` — every `Minimal compilable example` is generated, compiled with `dart analyze`, executed, and asserted to exit 0 in CI.
- **Seam rules in-package**: new `test/seam_test.dart` ports the Mitose grep rules (no `testRule: TestCell` on Tissue constructors; no `TestTissue` on Cell factories) into this package's own suite.
- **Matrix freshness**: new `tool/generate_api_chooser.dart` + `test/api_chooser_up_to_date_test.dart` keep the checked-in chooser generated and drift-free.
- **Failure feedback loop**: new `tool/ai_failure_log.dart` + `tool/ai_failure_log.jsonl` for structured, quarterly-reviewed AI failure records.
- **Docs**: new `CONTRIBUTING-AI-DOC.md` (normative block spec) and `CONTRIBUTING.md`; the README opens with an AI-starter preamble (Install and import → "AI agents start here" → a six-row BRD elevator table); the `cell` library doc gains a public-surface top table; curated `example/` demos (`ingress_demo.dart`, `observe_demo.dart`, `state_demo.dart`, `transaction_demo.dart`) carry fixed AI-facing headers.

### Cell.apply

The apply gateway is now a **forensic command model**: every mutation request
is a first-class, auditable record, and an accepted apply propagates to the
reactive graph like a direct emission.

- **Forensic Apply Command model**: New `ApplyCommand`, `ApplyArguments`, `ApplyCompensation`, and `ApplyReceipt` flyweight records, plus the sealed `ApplyOutcome<R>` hierarchy (`ApplyAccepted`, `ApplyRejected`, `ApplyStaged`) and the `Cell.apply<R>(command, {tx})` gateway. Every submission now carries an auditable receipt with a correlation id, timestamp, optional transaction sequence, and a `vetted` flag.
- **Builder DSL**: `cell.command(fn).args(...).undo(...).run<R>()` assembles and submits commands fluently on top of the raw record shape.
- **Integrity Gate awareness**: `TestCell.action` and `TestActionRule.action` now receive the complete `ApplyCommand` - including its compensation blueprint - through a new optional `command` parameter.
- **`ApplyTransactionScope.enqueueCommand`**: transactions stage first-class `ApplyCommand` records; the method returns the staged sequence index for forensic receipts.
- **`ApplyVeto`**: The explicit soft-reject return convention for whitelisted functions (previously the internal `ApplyRejected.instance` sentinel) is now a public type.
- **Apply completion contract**: `CellBase.apply` now completes the `ApplyAccepted` contract by routing the command function's `Pulse` result through the cell's receptor (`_acceptExecuted`), so an accepted apply propagates to the reactive graph exactly like a direct emission.
- **txApply savepoint scoping**: Staged savepoints carry their owning scope's id, so rollback can distinguish local savepoints from foreign ones instead of treating any unknown savepoint as a full rollback.
- **`Cell.apply` retired**: The eight-parameter, loosely typed dynamic `apply` gateway has been removed entirely. `apply<R>(ApplyCommand command, {ApplyTransactionScope? tx})` is now the only command gateway; the legacy `null`-based result semantics are replaced by the sealed [ApplyOutcome].
- **Legacy async wrapper removed**: `ModifiableAsync` now exposes only the command-model `apply<R>`; the parameter-dropping legacy async `apply` was removed.
- **txApply commit detection**: Commit now treats gate-level `ApplyRejected` outcomes as a soft integrity failure in addition to `ApplyVeto`-returning functions; with `stopOnFirstFailure` (default) such transactions now fail instead of silently continuing.
- **Apply gateway validation**: Every `apply` — manifest member or not — is vetted through the public `validate` seam (`TestCell.action`), so deputies evaluate the full chained `testRule` (deputies no longer bypass their own rule) and `TestCell.readOnly` rejects every Function action. A throwing rule fails closed; a function returning `ApplyVeto` is reported as `ApplyRejected`. `modifiable` remains a capability declaration consumed by rules, not a bypass switch.
- **Unmodifiable projections**: `UnmodifiableValueCell` layers `TestCell.readOnly`, throws from the `value` setter, and is wired into the graph (its observers receive the principal's mutations); read-only deputies seal both `apply` actions and direct value writes; `ValueNucleus.evolve` derivatives share the principal's Box and materialize a working egress registry.
- **Composed generic rules**: Nested `TestCell`s in a chain are consulted for action/link/pulse validation through `call` (their generic rule sees the action/link/pulse object) instead of being dispatched through the specialized-rule interfaces, which silently skipped them - including during `Cell.apply` action validation.
- **Transaction validation shape**: Commit-time `_defaultValidate` validates the same `Pulse` shape the receptor would see, so `TestPulseRule`s gate transactional commits exactly like direct updates.
- **Async validation failures**: `TestRule.call` re-throws async rule errors (no longer resolves `Future<bool>` with the error object), and `TestCell.call` applies the same governed/ungoverned exception convention to async failures as to sync ones.
- **`txApply.rollback` savepoints**: Rolling back an unknown savepoint (or a savepoint from another scope) now throws `ArgumentError` instead of silently rolling back the whole transaction.

### Optimization

Six optimization phases, tracked by a committed benchmark suite with a
regression gate. Headline results: single-hop emit ~170 µs to ~5-6 µs (~30x),
`Cell.distinct` ~1.7 ms to ~8 µs (~210x), chain depth 50 from ~8.3 s
(exponential) to ~12.7 ms (linear), `Cell()` construction ~3.7 µs to ~2.1 µs,
and `Cell()` heap footprint ~2.7 KB to ~1.1 KB.

- **Benchmark suite**: New `benchmark/` directory with shared fixtures, per-shape micro/macro benchmarks (construction, propagation, operators, synapses strategies, transactions, async receptors), VM-service memory benchmarks (per-cell footprint, evolution chains), RxDart/raw-Stream comparison benchmarks, a PR-suite runner (`benchmark/runner.dart`), a regression gate (`benchmark/compare.dart`), a checked-in `baseline.json`, and a CI workflow (`.github/workflows/benchmark.yml`) that fails PRs on >15% benchmark regressions.
- **Pulse hot path**: Pulse records are now stamped with a `shape` field-presence tag and all hot `PulseBase` accessors read the record directly - no caught `NoSuchMethodError`/`LateInitializationError` per read. `FinalBox.value` returns `null` before the first write instead of throwing. `PulseBase.withStep` returns a lightweight `_StepPulse` lineage node instead of building a full mask record per cell. The receptor pipeline stage sequence is unrolled and allocation-free, and `last` is O(1) on every pulse shape (collectives return themselves).
- **Cell hot path**: Nucleus records carry the same `shape` tag with exception-free `bind`/`lock`/`user` reads; default synapses materialize lazily on first access; nucleus timestamps compute lazily; `_Receptor.isActivated` uses a flag instead of a caught late-init error; the ingress emit path uses a flat-field `_FastPulse` and a guarded source-side fast path; `CycleChecker` holds the first visited cell in a plain field and materializes its identity set only on the second distinct cell.
- **Observer hot path**: `_StepPulse` is now fully flat (plain parent/step fields, zero records per hop); the sync broadcast fast-paths the common `Cell.observe` observer (ungoverned, allow-all, reaction-only, disabled synapses) by invoking the reaction directly with inline terminal accounting; `SynapsesBase.isEmpty`/`isNotEmpty` are O(1) instead of iterator-based. Single-hop harness cost dropped ~1.5x (vs raw stream ~202x to ~121x); the remaining ratio is published feature-accounted — a per-emit cost ladder (provenance record ~0.3 µs, broadcast machinery ~1.7 µs, observer pipeline ~2.4 µs vs a bare `StreamController.add` at ~0.04 µs) in `benchmark/README.md`.
- **Broadcast mutation safety**: The synchronous broadcast no longer allocates a per-broadcast snapshot; `link`/`unlink` during a broadcast are deferred and applied after the loop (fixes `ConcurrentModificationError` when a `switchMap` mapper links a source-bound inner cell mid-broadcast).

### Other fixes

- **Branch completion counter**: Composite/evolved constructors no longer double-increment `_branches`; `NucleusBase._propagate`'s empty-synapse fast path decrements and completes only at zero; null-result receptors are accounted as terminals; the counter resolves through the lineage root. A governed pulse with `onComplete` now fires exactly once across multi-branch waves instead of once per terminal (or never). **Fan-out accounting**: the sync and async broadcasts now credit the root branch box with `(eligible - 1)` before delivering, so N fan-out terminals drive the counter to zero exactly once — the completion callback fires after the *last* terminal, not the first.
- **`txApply` rejected commands**: `call.executed` is cleared on *any* gate rejection, not only when `stopOnFirstFailure` throws — with `stopOnFirstFailure: false`, a rejected (never-executed) command is no longer compensated when a later command throws.
- **`EphemeralPolicy` TTL**: A declined `eventLimit` reclamation (the `onInvalidate` hook returns false) no longer disposes the TTL timer — the node stays live and keeps its TTL guarantee; only an accepted reclamation cancels the timer.
- **`updateAsync` with async validation**: `ValueCellAsync._emit` now awaits the receptor's `Future` and resolves `false` when async validation rejects, instead of reporting the premature `Future != null` as success; the synchronous `update` contract remains "accepted" (a bool cannot express a pending outcome).
- **`DeputyContext.evolve` attenuation**: Downward-only enforcement now covers every safety dimension, not just authority — `isolation` and `auditLevel` may only increase their index (tighten), `sovereignty` and `clearance` may only decrease theirs; escalation attempts throw `ArgumentError`.
- **`TestCell.chain` / `TestRule.chain`**: `parent` and `user` are preserved when no `strategy` is supplied; `_evaluateChain` no longer invokes the parent twice.
- **`_Receptor.==`**: Equality now follows the configuration record, restoring the `==`/`hashCode` contract.
- **`PriorityQueue`**: `removeLast` and `last` now return the true lowest-precedence element (a leaf-scan of the min-heap) instead of the arbitrary array tail; `SyncQueue.addAll` checks capacity up front and no longer partially adds before throwing.
- **`Cell.fromStream` policy ticks**: The listener no longer double-ticks the lifecycle policy (the receptor tick is the single source); the caller's `onEvent`/`onInvalidate` hooks are preserved through the wrapper policy, exposed as the new public `EphemeralPolicy.invalidate` hook.
- **`Instruction.future` + postProcess**: The async continuation forwards the host cell to postProcess and propagates its output through the cell's synapses (previously the host was `null` and the output was dropped).
- **`_switchMap` invalidation unlink**: The output's lifecycle policy is wrapped with an invalidation hook that unlinks the current inner cell — without it the inner's synapse keeps a strong reference to the invalidated output (and its closure) forever. The caller's policy hooks and reclamation decision are preserved; `Cell.switchMap` now exposes the `ephemeralPolicy`/`context`/`testRule`/`synapses`/`forceLock` options the internal operator already supported.
- **`ReceptorAsync` queue starvation**: Fire-and-forget submissions now always schedule a drain (the unawaited lock serializes them; an idle drain exits immediately). The previous `canLock` gate could strand a pulse enqueued while another drain was finishing its final emptiness check.
- **`PriorityQueue.remove`**: Removing a value of an incompatible type now returns `false` (matching `Set.remove`/`List.remove`) instead of throwing a `TypeError` from the internal cast.
- **`get<T>` narrowed to genuine absence**: The property-resolution helper now treats only a missing record field (`NoSuchMethodError`) or an uninitialized lazy field (recognized by its class-name prefix, since the class has no public type) as absence. Everything else — wrong-typed record fields, failed casts, argument errors, parsing failures — propagates instead of silently resolving to `orElse`. The fallback stage uses an explicit `is T` test (a `null` or mismatched fallback result resolves to `orElse` for non-nullable `T`). This surfaced and fixed real masked bugs: `EphemeralPolicy.events`/`isInvalidated` and `PulseEphemeralPolicy.hops`/`isInvalidated` reading unset boxes, `DeputyContext`'s dimension getters returning `null` for non-nullable types, and the tissue `container` getter's wrong-typed deputy record cast (now resolved through the principal fallback explicitly).
- **Guarded operator links**: The fire-and-forget  results in the operator pipelines ('s inner and source links, 's source link, and the -based bridge links in //) are now driven to completion: a rejected async  gate is routed to the originating pulse's fail path (in-pulse links) or contained (construction-time links) instead of becoming an unhandled zone error. Operator pipelines assume synchronous  rules; an explicitly async gate still materializes its connection when it resolves .
- ** deduplication documented**: A no-op update — a value  to or  the current state — is deliberately skipped and resolves  (nothing is emitted and it is not a commit); the typedef and  field docs now state this explicitly.
- **Cached step string on the receptor hot path**: `_proceed` now uses each cell's cached `_stepString` instead of computing `cell.toString()` per pulse. For a tissue (whose `toString` enumerates the whole collection) this was O(n) per event — a sequence of mutations was O(n^2); 1000 `TissueList.add`s dropped from ~3.2 s to ~56 ms.
- **Guarded timer emissions**: Every timer callback that emits a pulse (`Cell.debounce`'s trailing timer, `Cell.throttle`'s trailing window, and the debounced/buffered/audit strategy timers in both sync and async synapses) now wraps the emission in a guard that routes a throwing downstream receptor to `pulse._fail` instead of leaking it as an unhandled zone error — matching the synchronous path's containment.

### Removed

- **`PropagationStrategy.exhaust`, `.sample`, `.resilient`, `.retry`**: These four strategies were silently non-functional — `exhaust` gated only the sync path and no-op'd async, `sample`'s heartbeat never sampled fresh state and leaked unless the last observer unlinked, `resilient` swallowed every failure without a circuit state, and `retry` misused `batchSize` as a retry count. Non-functional strategies are worse than absent ones, so the enum members, their dispatch cases, the heartbeat timer machinery, the policy parameter docs, and their tests are all removed. Every functional strategy (`immediate`, `async`, `batched`, `buffered`, `debounced`, `throttled`, `audit`, `debounceLeading`, `persistent`) is unchanged.

### Docs

- **API reference**: Regenerated `doc/api` after a fresh `dart doc .` run with zero warnings, including pages for the new command model types (`ApplyCommand`, `ApplyArguments`, `ApplyCompensation`, `ApplyReceipt`, `ApplyOutcome`, `ApplyVeto`, and the `ApplyCommandDSL` extension).
- **`TestCell.readOnly`**: Now states precisely what the rule blocks — every Function action (`apply`) — while pulses (non-Function objects) still propagate; `unmodifiable` remains the sealed projection, and read-only value deputies also seal the direct `value` setter.
- **`TransactionOptions.timeout`**: Documented that an in-flight commit cannot be pre-empted by the timeout - the rollback surfaces on the next interaction.
- **`ReceptorAsync`**: Documented the priority-ordered internal queue and the timestamp-granularity causal-order guarantee.
- **`Cell.debounce`**: Documented the deliberate `leading`-mode deviation from classic Rx `debounceTime` (lone pulses emit both immediately and on the trailing timer).
- **`TestActionRule`**: Documented that user rules receive the action `Function` and arguments - not the surrounding `ApplyCommand` (its compensation blueprint stays in the framework's ledger machinery).
- **Benchmark README**: Documents the layout, pass criteria, measured Phase 1-5 results, and baseline maintenance.
- **Package README**: Added a feature-first Overview — a governance tagline, a capability comparison against plain Dart state (`setState` / `ValueNotifier` / `Stream`), a "transaction ready" snippet (`command(...).run()`, `Cell.txApply`, `Cell.transaction`), and a table of contents.

### Tests

- **`nucleus_test.dart`**: Updated all `Nucleus.evolve` call sites to the new positional `principal` signature.
- **`apply_command_test.dart`**: Coverage for the command model: typed outcomes, receipts, gate command propagation, staging, builder DSL, and async execution.
- Migrated `cell_test.dart`, `deputy_test.dart`, `tx_apply_test.dart`, `operators_phase4_advanced_transactions_test.dart`, and `example/atomic_multi_update.dart` from the retired dynamic gateway to `apply<R>(ApplyCommand)`.
- New regression tests: txApply unknown/foreign savepoint rejection, rejected-command non-compensation under `stopOnFirstFailure: false`, declined-reclamation TTL survival, fan-out completion ordering (callback only after the last terminal), async-rejected `updateAsync`, DeputyContext per-dimension attenuation, unmodifiable and read-only deputy apply semantics, composed generic action validation (including `Cell.apply`), async throwing rules, pulse-shape transaction validation, `Instruction.future` postProcess commit + propagation, batch/`onComplete` multi-terminal completion, fromStream policy single-tick + caller hooks, asyncMap latest-only drain, chain parent/user preservation, priority-queue lowest-precedence extraction, atomic `addAll`, receptor record equality, switchMap mid-broadcast link/unlink, and the benchmark suite itself (60 tracked results).

## Cell (1.0.0-rc.9) - Release Candidate

Docs release. No public API changes.

### Docs

- **Guides**: The framework intro video (`guide/cell-framework-intro.mp4`) is no longer part of the package guides or the published archive.
- **API reference**: Regenerated `doc/api` after a fresh `dart doc .` run.

---

## Cell (1.0.0-rc.8) - Release Candidate

Docs release. No public API changes.

### Docs

- **Changelog convention**: Aligned the CHANGELOG heading convention with the umbrella repository.
- **API reference**: Regenerated `doc/api` after a fresh `dart doc .` run.

---

## Cell (1.0.0-rc.7) - Release Candidate

### Changed

- **`receptor.dart` dead branches removed**: Removed the unreachable null-strategy fallback in `InstructionChain.call` (`_instruction` now returns a non-null `Function`) and the unreachable Function-token resume walk in both `InstructionChain` and `InstructionChainMixin`. A `Function` token can never be `identical` to an `Instruction` stage because Dart's `Function` type is final, so those branches could never execute; non-Function tokens still forward to the caller's continuation.

### Fixed

- **Empty receptor mask `NoSuchMethodError`**: `ReceptorBase.mask` no longer stores sparse/`()` flyweight records. Empty and partial pipelines use a stable named-record shape so reading `_instruction` / `_preProcess` / `_postProcess` / `_reaction` returns `null` instead of throwing `NoSuchMethodError: Class '()' has no instance getter 'instruction'` (commonly hit via `Cell.ingress` + `Flow.bufferTime` under a debugger that breaks on caught exceptions).
- **`txApply` compensates actions that throw after mutating state**: Staged calls are now marked as attempted *before* they are invoked, so an action that partially mutates its cell and then throws is included in the rollback compensation instead of being skipped. Previously the `executed` flag was only set after a successful `apply`, so a throwing call left its partial side effects uncompensated.
  - When an integrity gate rejects an action (`ApplyRejected`) with `stopOnFirstFailure`, the call is explicitly marked not executed (nothing ran), so the rejection path still skips compensation for that call.
- **Lock access**: Added a `CellBase.lock` getter that exposes the cell's nucleus lock; `withCellLocks` now reads it for `CellBase` instances instead of reaching into the private `_nucleus` member.
- **`Cell.transaction` supports cross-package `ValueCell`s**: The default commit path now writes through a public `ValueCell.value` setter (which routes through the same validated emission pipeline as the private `_emit`) instead of calling `_emit` directly, because cross-package implementations such as `TissueValue` do not inherit the private member. Unmodifiable views reject the write silently, matching the previous behaviour.
- **`TestCell.call` override soundness**: The `host` parameter is now declared `covariant C? host` so subclasses that narrow `C` remain type-sound.

### Tests

- Added a `partialThenFail` action and a regression test proving that an action which mutates balance and then throws is compensated back to its original value.
- Updated existing `txApply` expectations: throwing debits are now compensated with a credit, so the affected balances reflect the compensation.
- Expanded `instruction_test.dart` with an `InstructionChainMixin` suite (strategy resolution, null-strategy fallback, Function/non-Function resume tokens, and error recovery), bringing `lib/src/receptor.dart` to 100% line coverage.

### Docs

- **Dual-audience `guide/HowTo-*.md` guides**: `HowTo-Context.md`, `HowTo-Instruction.md`, `HowTo-Pulse.md`, and `HowTo-PulseContext.md` now serve both human developers and AI coding agents. Each guide keeps its human narrative as Part I and adds a procedural **Part II — AI Coding Agent Decision Tree** with agent-only rules and a verification checklist, so an agent can consume Part II directly without reading Part I first.
- Regenerated `TEST_VERIFICATION.md`: 1125 tests in 20 files, all passing; overall `lib/` line coverage **93.5%** (3586 / 3836); `lib/src/receptor.dart` now at **100%** (62 / 62).

---

## Cell (1.0.0-rc.6) - Release Candidate

### Changed

- **`Pulse.type` is now `dynamic`**: Widened the pulse's semantic classification from `String?` to `dynamic` so pulses can carry richer classifiers — such as domain enums — alongside the traditional `String` routing tags.
  - The `Pulse` factory now accepts `dynamic type`.
  - The `Pulse.type` interface getter and `PulseBase.type` implementation now return `dynamic`.
  - `PulseBase.toString` renders the classification via `type.toString()` so non-`String` classifiers print safely.

### Docs

- **Mitose pipeline**: Added a prominent README callout for the umbrella **Mitose pipeline** — the AI-executable orchestration in the root [`guide/`](https://github.com/simon-m-lee/cell/tree/master/guide) that turns a business requirement into a Cell + Flow + Tissue solution with its BRD, WalkThrough, Demo, ARCHITECTURE, and FEATURES documents. This package contributes the **Cell-layer** rules via [`guide/HowTo-Mitose-Cell.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Cell.md).

---

## Cell (1.0.0-rc.5) - Release Candidate

Pub.dev score remediation release. No public API changes.

### Fixed

- **Package identity**: Restored the published package name to `cell` (the internal rename is handled outside the public package line).
- **License detection**: Replaced the custom dual-license notice with the canonical MIT and Apache-2.0 texts so pub.dev recognizes the OSI-approved license.
- **Example detection**: Added `example/cell_example.dart` — a runnable quick start matching pub.dev's example file conventions.

---

## Cell (1.0.0-rc.4) - Release Candidate

This release centers on **Lifecycle Governance** and **Pedagogical Standardization**. It formalizes the structural "DNA" of the core layer by refining how nodes handle administrative oversight, programmed expiration, and forensic documentation.

### Lifecycle & Governance
- **Administrative Oversight**: Refined `isGoverned` to reflect a node's structural mandate. It now accurately reports based on a **Causal Aggregation Strategy**, ensuring that projections of a governed cell inherit their parent's administrative status.
- **Programmed Cell Death**: Hardened `isInvalidated` to serve as the authoritative indicator for a node's functional lifecycle (Apoptosis). It ensures that once a node or its causal source is invalidated, it is logically severed from the reactive graph to preserve system integrity.
- **Ephemeral Policy**: Improved the integration between `EphemeralPolicy` and `NucleusBase`, allowing for more robust lifecycle monitoring and stale state detection.

### Fixes & Maintenance
- **Monorepo Integrity**: Verified monorepo-wide stability using `melos bootstrap` and aligned all package metadata for consistent workspace resolution.
- **Trace Stamping**: Refined internal `Pulse.trace` milestones to ensure that "Rejection Milestones" provide clearer forensic data when an integrity gate denies a mutation.

---

## Cell (1.0.0-rc.3) - Release Candidate

This release formalizes the **Forensic Identity** and **Causal Anchor** logic within the core layer. It introduces tiered resolution for integrity gates and synchronizes the monorepo governance to support high-integrity, multi-package development.

### Workspace & Monorepo Governance
- **Workspace Resolution**: Migrated the package to `resolution: workspace`. Removed manual `dependency_overrides` in favor of Dart's native workspace resolution, ensuring a unified lockfile and consistent dependency trees.
- **Metadata Standardization**: Updated `pubspec.yaml` to include precise `repository` and `issue_tracker` links for better package discovery and forensic traceability of the source code.
- **Platform Alignment**: Explicitly declared support for Android, iOS, Linux, macOS, Windows, and Web platforms in the package manifest.

### Forensic Identity & Integrity Gates
- **Context as Causal Anchor**: Refined the `Context` logic. It now serves as a persistent **Forensic Anchor**, defining identity and administrative authority that travels with the `Pulse` across asynchronous boundaries.
- **Tiered Resolution Strategy**: Implemented a tiered lookup for `Context` and `TestCell` (Integrity Gates). Handles now resolve their identity and rules through a hierarchy: **Local Override > Prototype Inheritance > Causal Binding > Global Default**.
- **Instruction DNA**: Reconceptualized `Instruction` as the core **DNA** of the nucleus. Refined the internal logic to ensure stateless transformations are correctly recorded in the forensic `Pulse.trace`.

### High-Integrity Domain Demos
Introduced comprehensive, real-world applications of the framework's forensic capabilities across two high-stakes scenarios:
- **Aircraft Gate Turnaround**:
  - `aircraft-gate-turnaround-Demo.dart`: A live executable simulating the orchestration between "Ground Crew," "Refueling," and "Flight Deck." Demonstrates atomic state evolution where multiple systems must synchronize under strict timing and safety constraints.
  - `aircraft-gate-turnaround-WalkThrough.md`: A deep-dive guide explaining how the framework handles concurrent causal paths and maintains a single source of truth for aircraft readiness.
- **Hotel Front Desk Check-in**:
  - `hotel-front-desk-checkin-Demo.dart`: A live executable demonstrating reactive synchronization between "Front Desk" (Guest-tier) and "Security" (System-tier).
  - `hotel-front-desk-checkin-WalkThrough.md`: A deep-dive guide detailing how `Context` anchors and `TestCell` gates prevent unauthorized state transitions in multi-tier environments.

### Documentation & Pedagogical Overhaul
- **Interactive Walkthroughs**:
  - Introduced `WALKTHROUGH.md`, a comprehensive guide detailing the forensic lifecycle of a Pulse, from Receptor ingress to terminal evolution.
- **Pedagogical KDocs**: Applied a standardized documentation format across the public API, including `### When to use`, `### How it works`, and `### Non‑obvious` sections for core classes like `Context`, `Instruction`, and `TestCell`.
- **Architecture Visualization**: Standardized terminal-friendly architecture diagrams (67-character width) to ensure visual consistency in IDEs and documentation viewers.

### Fixes & Maintenance
- **Map Type Invariance**: Fixed a potential `CastMap` runtime error by utilizing `Map.of` and `updateAll` during unmodifiable payload cloning.
- **Synapse Reliability**: Improved the reliability of tiered rule resolution when cells are bound via `Synapses`, ensuring inheritance logic correctly identifies the source gate.
- **Library Entry Points**: Reorganized `lib/cell.dart` using categorical headers to separate public interfaces, core implementations, and internal logic.
---

## Cell (1.0.0-rc.2) - Release Candidate

This release introduces **PulseShell** defensive proxies and advanced **Receptor scrutiny**, providing high-integrity reactive orchestration for the Cell layer. It also hardens transactional state propagation and resolves edge cases in asynchronous operators.

### Core Enhancements
- **PulseShell & Scrutiny**:
  - Introduced `PulseShell` as a defensive proxy for pulses, ensuring that untrusted receptors must pass a `scrutinize` check before accessing the underlying kernel.
  - Refined `Receptor.pipeline` to support governed execution masks, allowing for more granular control over side effects and state mutations.
- **Polymorphic Deputies**:
  - Refined `deputy()` and `unmodifiable()` to return more specific types (e.g., `OpenCell`), eliminating the need for manual type-casting when working with ingress-capable proxies.
- **Transactional Stability**:
  - Enhanced `txApply` resilience when dealing with complex multi-cell dependency graphs and asynchronous observers.
  - Improved internal cycle detection and trace propagation for deep reactive topographies.
- **Operator Hardening**:
  - Resolved type inference ambiguities in asynchronous closures (fixing the `FutureOr` return type issue).
  - Fixed re-arming edge cases in `debounce` and `throttle` timers to prevent leaks and incorrect firing intervals.

### Documentation & Verification
- **Test Coverage**: Added dedicated test cases for `PulseShell` scrutiny and async closure type safety.
- **Verification**: Updated `TEST_VERIFICATION.md` to reflect the latest RC2 coverage metrics and scrutiny protocols.
- **High-Integrity Documentation Overhaul**: Regenerated library and core class KDocs with pedagogical sections (`### When to use`, `### How it works`, `### Non‑obvious`) for better developer onboarding and technical accuracy.

### Fixes & Maintenance
- **Internal Timer Reliability**: Fixed re-arming edge cases in `debounce` and `throttle` where timers could leak or fire at incorrect intervals during rapid state transitions.
- **Type Inference**: Resolved `FutureOr` return type ambiguities in asynchronous operators, ensuring smoother integration with the Cell orchestration layer.
- **Proxy Identity**: Ensured `PulseShell` proxies correctly propagate causal metadata while masking sensitive kernel internals during scrutiny phases.
- **Project Structure**: Updated `analysis_options.yaml` and `dartdoc_options.yaml` to maintain consistent quality standards across the monorepo.

## Cell (1.0.0-rc.1) - Release Candidate

This release promotes the **cell** core from **Beta (Public Preview)** to **Release Candidate**. The Switching Fabric, Core 16 operators, `Cell.valve`, `OpenCell.perform`, context / deputy / commons, and both transaction APIs are covered by a passing public-API unit-test suite with measured `lib/` coverage. Breaking changes remain possible before a versioned 1.0 stable, but they should follow documented contracts rather than silent private-API drift.

### Developmental Status
- **Code Stage:** RC (Release Candidate).
- **Stability:** Public APIs for cells, pulses, operators, transactions, integrity gates, context, deputy, and commons utilities are exercised end-to-end. This is not a production-readiness certificate: the package is unpublished and has no independent security or correctness audit.
- **Goal:** Freeze the Cell public surface for 1.0 feedback; gather remaining issues on operator ergonomics, ingest/observe pipelines, transaction/`txApply` orchestration, and deputy attenuation.

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

## Cell (1.0.0-preview.4) - Public Preview

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

## Cell (1.0.0-preview.3) - Public Preview

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

## Cell (1.0.0-preview.2) - Public Preview

This marks the latest pre-release of the Cell framework. "Cell" has reached functional stability, transitioning from a reactive fabric prototype to a comprehensive, high-performance state management solution for Dart.

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

## Cell (1.0.0-preview.1) - Public Preview

This is the initial "Cell" release of the Cell Framework, currently in a **Preview** stage for public preview. This release marks the first stable division of the framework's core concepts into a functional reactive fabric.

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
- **Naming Convention**: Major architectural milestones will follow biological nomenclature. "Cell" represents the birth and initial division of the framework.

## 1.0.0-beta.1 (2025)

- Initial Commit
