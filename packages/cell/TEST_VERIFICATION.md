# cell package - Test Verification Report

**Generated:** 2026-09-13
**Package:** cell (v1.0.0-rc.3)
**Test Files Analyzed:** 20
**Total Tests:** 1115 (0 skipped)

---

## Table of contents

- [Executive Summary](#executive-summary)
  - [Snapshot](#snapshot)
  - [Quick Stats](#quick-stats)
- [Test File Inventory](#test-file-inventory)
- [Detailed Test Coverage](#detailed-test-coverage)
  - [test_cell.dart](#file-1-test_cell.dart-72-tests)
  - [test_cell_policy.dart](#file-2-test_cell_policy.dart-38-tests)
  - [test_commons.dart](#file-3-test_commons.dart-43-tests)
  - [test_context.dart](#file-4-test_context.dart-117-tests)
  - [test_deputy.dart](#file-5-test_deputy.dart-21-tests)
  - [test_instruction.dart](#file-6-test_instruction.dart-23-tests)
  - [test_nucleus.dart](#file-7-test_nucleus.dart-39-tests)
  - [test_operators_phase1_foundation.dart](#file-8-test_operators_phase1_foundation.dart-64-tests)
  - [test_operators_phase2_flow_control.dart](#file-9-test_operators_phase2_flow_control.dart-43-tests)
  - [test_operators_phase3_async_routing.dart](#file-10-test_operators_phase3_async_routing.dart-60-tests)
  - [test_operators_phase4_advanced_transactions.dart](#file-11-test_operators_phase4_advanced_transactions.dart-39-tests)
  - [test_propagation_policy.dart](#file-12-test_propagation_policy.dart-41-tests)
  - [test_pulse.dart](#file-13-test_pulse.dart-157-tests)
  - [test_receptor.dart](#file-14-test_receptor.dart-50-tests)
  - [test_synapses.dart](#file-15-test_synapses.dart-82-tests)
  - [test_synthesis_cell.dart](#file-16-test_synthesis_cell.dart-37-tests)
  - [test_test_cell.dart](#file-17-test_test_cell.dart-41-tests)
  - [test_test_rule_meta.dart](#file-18-test_test_rule_meta.dart-48-tests)
  - [test_transaction.dart](#file-19-test_transaction.dart-54-tests)
  - [test_tx_apply.dart](#file-20-test_tx_apply.dart-46-tests)
- [Runtime Verification Status](#runtime-verification-status)
  - [Last `dart test`](#last-dart-test)
  - [Line Coverage (`lib/`)](#line-coverage-lib)
- [Recommendations](#recommendations)
- [Appendix: File Locations](#appendix-file-locations)

---

## Executive Summary

The cell test suite contains **1115 unit tests** across **20 files** in `test/`. Counts are `test(` declarations.

This file is **generated**. Edit the script flags or the stub sections at the bottom; do not hand-count `test(`.

### Snapshot

Last `dart test` is **green**: **1115 passed**, 0 failed (exit 0).

`lib/` line coverage is **95.1%** (3411 / 3587).

Below 70%: `lib/src/receptor.dart`.

### Quick Stats

| Metric | Value |
|--------|-------|
| **Total Test Files** | 20 |
| **Total Tests** | 1115 |
| **Skipped** | 0 |
| **Last full run** | 1115 passed, 0 failed, 0 skipped (exit 0) |
| **Test Groups** | 251 (`group(` declarations) |
| **Async-ish tests** | ~349 (heuristic) |
| **Line coverage (`lib/`)** | **95.1%** (3411 / 3587) |

---

## Test File Inventory

| # | File | Lines | Tests | Size | Focus |
|---|------|------:|------:|------:|-------|
| 1 | test_cell.dart | 1,098 | 72 | 38.6 KB | cell; groups: Cell, Factory Constructors, Identity & Equality, Apply, Modifiable, Terminal & State… |
| 2 | test_cell_policy.dart | 598 | 38 | 20.4 KB | cell policy; groups: EphemeralPolicy, Construction, call / events, eventLimit, TTL, combined TTL and eventLimit… |
| 3 | test_commons.dart | 449 | 43 | 13.6 KB | commons; groups: mapMerge, SyncSet, QueueList, AsyncQueueList, PriorityQueue, AsyncPriorityQueue… |
| 4 | test_context.dart | 1,628 | 117 | 60.7 KB | context; groups: GovernanceEntry, Ontology, Context, system, describe, primary constructor… |
| 5 | test_deputy.dart | 255 | 21 | 8.3 KB | deputy; groups: Cell.deputy, identity, testRule layering, apply forwarding, unmodifiable, causal integrity… |
| 6 | test_instruction.dart | 354 | 23 | 12.3 KB | instruction; groups: Instruction, Construction, Composition, Instruction.future, Custom Instruction, Receptor integration |
| 7 | test_nucleus.dart | 352 | 39 | 12.2 KB | nucleus; groups: Nucleus, empty / Nucleolus, Construction & defaults, Nucleus.create, Activation, evolve… |
| 8 | test_operators_phase1_foundation.dart | 1,045 | 64 | 36.5 KB | operators phase1 foundation; groups: Cell.state, Basic State, State with evolve, Ingest, Edge Cases, Cell.ingress… |
| 9 | test_operators_phase2_flow_control.dart | 766 | 43 | 22.3 KB | operators phase2 flow control; groups: Phase 2: Flow Control Operators, Cell.debounce, Cell.throttle, Cell.distinct, Cell.synthesis, Combined Operators… |
| 10 | test_operators_phase3_async_routing.dart | 1,042 | 60 | 30.2 KB | operators phase3 async routing; groups: Phase 3: Async & Routing Operators, Cell.asyncMap, Cell.hub, Cell.switchMap, Cell.fromFuture, Cell.fromStream… |
| 11 | test_operators_phase4_advanced_transactions.dart | 779 | 39 | 23.7 KB | operators phase4 advanced transactions; groups: Phase 4: Advanced & Transactions, Cell.sanitized, Cell.open, Combined Operators, Edge Cases & Error Handling, toString |
| 12 | test_propagation_policy.dart | 748 | 41 | 28.0 KB | propagation policy; groups: PropagationPolicy, Construction & Defaults, Strategy: immediate, Strategy: debounced, Strategy: throttled, Strategy: batched… |
| 13 | test_pulse.dart | 1,828 | 157 | 70.8 KB | pulse; groups: Pulse, Construction, withStep vs evolve distinction, Evolution, Composition, Shell… |
| 14 | test_receptor.dart | 680 | 50 | 23.6 KB | receptor; groups: Receptor, passThrough, Construction, Activation & clone, Pipeline, Instruction composition… |
| 15 | test_synapses.dart | 1,148 | 82 | 37.5 KB | synapses; groups: Synapses, disabled, enabled, Construction & broadcast, link / unlink, FilterRule… |
| 16 | test_synthesis_cell.dart | 625 | 37 | 21.0 KB | synthesis cell; groups: SynthesisCell, Construction, Aggregation, Source Management, Stop/Start, Edge Cases & Error Handling… |
| 17 | test_test_cell.dart | 579 | 41 | 19.1 KB | cell; groups: TestCell, allowAll, readOnly, Construction, Composition, Exceptions… |
| 18 | test_test_rule_meta.dart | 351 | 48 | 11.8 KB | rule meta; groups: DefaultValue, MaxLength, direct field limit, hostLength, composite field + container, host-only… |
| 19 | test_transaction.dart | 1,193 | 54 | 35.8 KB | transaction; groups: Cell.transaction, Basic Transaction, Isolation Levels, Lock Ordering, Validation, Custom Apply… |
| 20 | test_tx_apply.dart | 1,103 | 46 | 32.3 KB | tx apply; groups: Cell.txApply, Basic Operations, Compensation, Error Handling, Stop On First Failure, Savepoint… |
| **Total** | | **16,621** | **1115** | **558.6 KB** | |

---

## Detailed Test Coverage

Generated from `group(` / `test(` names. Tighten the prose by hand if needed.

### File 1: test_cell.dart (72 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 72 |
| Cell | |
| Factory Constructors | |
| Identity & Equality | |
| Apply | |
| Modifiable | |
| Terminal & State | |
| Deputy | |
| Async | |
| Unmodifiable | |
| Validation | |
| Context | |
| Ephemeral Policy | |
| Cell.valve | |
| OpenCell.perform | |
| toString | |

**Tests**

- Cell() creates a basic cell with defaults
- Cell() with custom receptor
- Cell.governed creates a governed cell
- Cell.governed with ephemeral policy
- Cell.fromNucleus creates a cell from a nucleus
- two distinct cells are not equal
- cell is equal to its deputy
- hashCode walks nested deputy principals
- cell identity preserved in sets
- apply executes a whitelisted function
- apply with positional arguments
- apply awaits an async testRule and runs when allowed
- apply awaits an async testRule and returns null when denied
- apply with named arguments
- apply returns function result
- apply with testRule blocks unauthorized actions
- modifiable returns list of whitelisted functions
- read-only cell has modifiable list
- isTerminal returns true for cells with disabled synapses
- isTerminal returns false for cells with enabled synapses
- isInvalidated returns false for active cells
- isGoverned returns true for cells with custom context
- isGoverned returns false for cells with system context
- deputy returns itself when no changes requested
- deputy creates a new instance with custom testRule
- deputy with custom context
- deputy with ephemeral policy
- deputy equality with principal
- deputy of a deputy
- async.apply executes function asynchronously
- async.apply with positional arguments
- async.apply with named arguments
- async.apply returns function result
- async.apply without a lock still completes
- async.apply with lock serialization
- Modifiable is a const marker
- unmodifiable returns the same cell instance for CustomCell
- unmodifiable for value cell is read-only
- unmodifiable for deputy returns principal unmodifiable
- validate allows all by default
- validate blocks with custom rule
- validate with pulse and custom rule
- validate with link rule
- validate with action rule
- cell with system context
- cell with module context
- cell with core context
- cell with secure enclave context
- cell with public interface context
- cell with custom context evolves
- policy with TTL invalidates after duration
- policy with event limit invalidates after threshold
- policy with both TTL and event limit
- policy events can be reset
- creates a valve bound to the source
- forwards pulses that pass the gate
- drops pulses that fail the gate
- pass and fail can be interleaved
- forwards the original payload unchanged
- dynamic gate can open and close
- gate can inspect pulse type
- disabled synapses is terminal and does not broadcast
- returns an OpenCell bound to the source
- emit runs perform and observers see the result
- perform receives the host OpenCell
- user metadata is forwarded to perform
- returning null drops the pulse
- testRule can reject emit
- bound source emissions also run perform
- can drive a state cell as a command handler
- cell returns string representation
- value cell returns string with value

### File 2: test_cell_policy.dart (38 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 38 |
| EphemeralPolicy | |
| Construction | |
| call / events | |
| eventLimit | |
| TTL | |
| combined TTL and eventLimit | |
| mask | |
| cell integration | |

**Tests**

- stores duration and leaves eventLimit unset
- stores eventLimit and leaves duration unset
- stores duration and eventLimit together
- allows a tracking-only policy with no TTL or quota
- stores user metadata for onEvent
- omitted user is null in onEvent
- forwards the interaction object to onEvent
- forwards the host cell to onEvent
- forwards call arguments to onEvent
- updates the events counter from onEvent
- ignores an event when onEvent returns a negative count
- returning zero is a counted event and stores 0
- does not invoke onEvent after the cell is reclaimed
- does not reclaim below the threshold
- reclaims when the counter reaches the limit
- reclaims on the first counted event when eventLimit is 1
- resetting the counter avoids the quota
- failed onInvalidate leaves the cell alive for a later retry
- without an eventLimit the counter never reclaims
- does not start the timer until the first interaction
- reclaims after duration from the first interaction
- does not restart the TTL on later interactions
- dispose cancels a pending TTL
- TTL is a no-op if the cell was already reclaimed
- event quota can reclaim before the TTL
- TTL can reclaim before the event quota
- bit 0: callbacks only
- bit 1: eventLimit
- bit 2: duration
- bit 3: eventLimit and duration
- bit 4: user
- bit 5: eventLimit and user
- bit 6: duration and user
- bit 7: eventLimit, duration, and user
- an unused hosted policy does not invalidate the cell
- Cell and Nucleus follow a hosted policy after reclamation
- a deputy without its own policy follows the principal
- two policies keep independent event counters

### File 3: test_commons.dart (43 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 43 |
| mapMerge | |
| SyncSet | |
| QueueList | |
| AsyncQueueList | |
| PriorityQueue | |
| AsyncPriorityQueue | |
| SyncQueue | |
| Box / SyncBox / FinalBox | |
| TypeObject / FunctionObject / get | |
| marker types | |

**Tests**

- copies keys that only exist in other
- concatenates when both values are iterables
- wraps an existing non-iterable when other is iterable
- appends a scalar onto an existing iterable
- wraps both scalars into a list when keys collide
- does not mutate the original maps
- add, contains, length, and lookup
- remove, isEmpty, and isNotEmpty
- addAll, toSet, toList, replicate, and iterator
- containsAll, intersection, union, and difference
- removeAll, retainAll, removeWhere, retainWhere, clear
- map, forEach, and where
- reduce combines elements
- constructors and FIFO operations
- removeWhere, retainWhere, and clear
- cast and async wrapper
- mirrors queue mutations under the lock
- toListAndClear, clearAndAdd, removeWhere, retainWhere, clear
- iterator and cast
- extracts the smallest element first with a comparator
- uses Comparable when no comparator is provided
- addFirst and addLast still rank by priority
- remove, removeWhere, retainWhere, and clear
- empty buffer throws on extract
- removeLast pops a leaf and iterator walks the heap
- add, peek, and ranked extract
- addAll, map, toList, toSet, reduce, forEach, replicate
- orders by comparison and reports emptiness
- of constructor seeds the heap
- capacity rejects overflow on add and addAll
- addFirst, addLast, remove, map, clear
- Box starts null and accepts mutation
- SyncBox serializes get and set
- FinalBox is write-once
- FinalBox.async is a SyncBox
- TypeObject wraps a value
- FunctionTypeObject evaluates lazily
- FunctionObject stores a record
- get returns the primary value
- get uses fallback when primary throws
- get uses orElse when primary and fallback throw
- get rethrows the original error when orElse cannot satisfy T
- Async and Unmodifiable are usable as type checks

### File 4: test_context.dart (117 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 117 |
| GovernanceEntry | |
| Ontology | |
| Context | |
| system | |
| describe | |
| primary constructor | |
| fromEntries | |
| named factories | |
| Context.deputy and Context.pulse | |
| evolve | |
| lineage | |
| equality | |
| Mandate | |
| DeputyContext | |
| system | |
| constructor | |
| named factories | |
| fromEntries | |
| evolve | |
| equality | |
| Clearance | |
| Isolation | |
| Sovereignty | |
| AuditLevel | |
| Provenance | |
| PulseContext | |
| system | |
| constructor | |
| named factories | |
| evolve | |
| lineage and index | |
| equality | |
| Identity | |
| ReasoningStrategy | |
| Sensitivity | |
| PriorityTier | |

**Tests**

- binds a typed value to a governance dimension
- constructor is equivalent to Governance.entry
- toEntry produces a MapEntry with the same key and value
- supports collection and enum value types
- static pillars are not evolvable
- fluid boundaries are evolvable
- isType validates the dimension value type
- compose includes every resolved dimension and omits nulls
- evolve yields only fluid boundaries
- is a reusable singleton with empty ontology
- evolve produces a specialized context without mutating system
- returns a Context whose ontology getters are unset
- evolve materializes ontology from the description context
- stores every named ontological dimension
- omitted dimensions remain null
- index operator returns local dimension values
- builds a context from governance entries
- inherits unset dimensions from an explicit parent
- local values shadow parent values
- core is a system-space infrastructure blueprint
- module is a user-space application blueprint
- secureEnclave is a privileged security environment
- publicInterface is a sanitized ingress boundary
- shieldedCortex isolates high-reasoning logic
- receptor hydrates inbound sensory sources
- integrityGate is a judicial validation barrier
- homeostasis is a metabolic stability loop
- sandbox is a speculative simulation workspace
- auditLog is a forensic compliance ledger
- transientTask is a leased ephemeral worker
- deputy factory returns a DeputyContext
- pulse factory returns a PulseContext
- refines fluid boundaries and preserves the original
- ignores attempts to change static pillars
- can tighten constraints and compliance
- is empty when the dimension was never set
- returns the local value for a root context
- walks the parent chain from root to leaf
- identical instances are equal
- independently constructed contexts are distinct records
- different dimensions are not equal
- an evolved child is not equal to its parent
- system is not equal to an empty constructed context
- role is a static pillar; remaining dimensions are fluid
- isType validates mandate value types
- compose and evolve filter dimensions correctly
- exposes safe mandate defaults
- evolve from system creates a specialized deputy
- requires authority and links ontology from the base context
- defaults isolation, clearance, sovereignty, and auditLevel
- stores standard clearance when it is the default
- observer is a read-oriented monitoring mandate
- delegate is an operational mutating mandate
- sandbox virtualizes mutations
- sandbox default role is Reasoning_Sandbox
- intervention is an emergency sentinel mandate
- janitor is a structural hygiene mandate
- architect is an infrastructure orchestration mandate
- auditor is a read-only compliance witness
- ambassador is a cross-domain negotiator
- shielded is a privileged enclave mandate
- gatekeeper is a policy enforcement mandate
- homeostasis is a background maintenance mandate
- can assemble a mandate from mixed ontology and mandate entries
- refines fluid mandate dimensions and keeps role immutable
- inherits unset mandate fields from the parent deputy
- independently constructed deputies are distinct records
- different authority values are not equal
- levels are ranked from observational to unrestricted
- authorizes is inclusive of the required rank
- virtualization starts at sandboxed
- only restricted is guarded
- supervised requires approval; preemptive can override
- deep reasoning starts at detailed; none is silent
- static pillars are not evolvable
- fluid boundaries are evolvable
- isType validates provenance value types
- compose includes resolved dimensions
- evolve excludes static pillars
- is an empty telemetric fallback
- evolve from system creates a specialized pulse context
- stores every named provenance dimension
- auto-generates a unique traceId when omitted
- does not auto-link parentTraceId from a generic base context
- inherits ontology from a ContextBase parent
- inherits provenance from a PulseContext parent
- stores others even without a parent
- stores others when a parent is also provided
- userAction captures explicit human intent
- userAction defaults purpose, priority, and sensitivity
- aiInference captures probabilistic autonomous intent
- inference matches the aiInference blueprint
- regulated forces forensic compliance markers
- regulated default reason mentions the framework
- homeostasis is a low-priority maintenance signal
- systemInternal uses a fixed system_daemon actor
- complianceAudit is a forensic witness signal
- selfCorrection prefixes the target field in reason
- infrastructureChange uses formal strategy
- securityIntervention is an emergency shield
- telemetry is unaudited background observation
- collaboration records a delegation handoff
- hypothesis is a non-committal simulation
- instruction is a critical manual override
- factories link parentTraceId when baseContext is a PulseContext
- refines fluid provenance and preserves static pillars
- can evolve ontology identity alongside provenance
- others passed to evolve are stored on the child
- index operator walks parent provenance
- lineage traces evolved ontology identity through a pulse parent
- independently constructed pulse contexts are distinct records
- auto-generated traceIds make otherwise identical contexts unequal
- next generates unique UUID-shaped identifiers
- classifies stochastic, mandated, and agentic strategies
- masking and high-risk thresholds follow classification rank
- fromValue maps numeric urgency onto semantic tiers
- urgent tiers start at critical

### File 5: test_deputy.dart (21 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 21 |
| Cell.deputy | |
| identity | |
| testRule layering | |
| apply forwarding | |
| unmodifiable | |
| causal integrity | |
| OpenCell.deputy | |

**Tests**

- returns this when no attenuation is requested
- creates a distinct proxy when a testRule is supplied
- creates a distinct proxy when a DeputyContext is supplied
- creates a distinct proxy when an ephemeral policy is supplied
- creates a distinct proxy when synapses are overridden
- deputies of the same principal compare equal and share hashCode
- a nested deputy remains equal to the root principal
- unrelated cells are not equal to a deputy
- the deputy rule is additive on top of the principal
- readOnly deputy still exposes apply on the principal via forwarding
- deputy.apply executes on the principal
- deputy.unmodifiable is the principal unmodifiable view
- ValueCell deputy unmodifiable is an UnmodifiableValueCell
- a nested deputy may use DeputyContext.system
- a nested deputy may use an evolved descendant context
- a nested deputy rejects an unrelated DeputyContext
- returns this when no attenuation is requested
- creates an OpenCell proxy that can emit
- nested OpenCell deputy with defaults returns this
- OpenCell deputy exposes async handle
- OpenCell deputy can link a downstream observer

### File 6: test_instruction.dart (23 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 23 |
| Instruction | |
| Construction | |
| Composition | |
| Instruction.future | |
| Custom Instruction | |
| Receptor integration | |

**Tests**

- transforms the payload
- returning null drops the pulse
- user metadata is passed to the instruction
- host cell is passed through
- exception terminates with null
- can return the same pulse instance
- + runs left then right
- Instruction.chain matches +
- null short-circuits later stages
- chains nest and stay Instruction
- exception in a stage terminates the chain
- custom strategy replaces sequential execution
- strategy receives chain user metadata
- a throwing strategy terminates the chain with null
- chain.call accepts a future continuation
- returns null immediately and resumes via future
- user metadata is available on a future instruction
- returning a pulse still emits synchronously
- null future callback drops the continuation without printing
- future instruction in a chain resumes through the chain callback
- a Function resume token is walked without matching a stage
- a throwing custom stage in a chain terminates with null
- Receptor.instruction runs the instruction

### File 7: test_nucleus.dart (39 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 39 |
| Nucleus | |
| empty / Nucleolus | |
| Construction & defaults | |
| Nucleus.create | |
| Activation | |
| evolve | |
| clone | |
| Equality | |
| inheritable | |
| Cell hydration | |

**Tests**

- Nucleus.empty is a reusable singleton
- empty nucleus uses framework defaults
- empty nucleus is activation-resistant
- empty nucleus timestamp is a DateTime
- default Nucleus uses system context and allowAll
- default Nucleus allocates a lock
- forceLock: false omits a dedicated lock
- default synapses are an enabled registry, not the flyweight
- Synapses.disabled is stored as a terminal egress
- custom context is stored
- custom receptor is stored
- custom testRule is stored
- bind is stored
- user record is stored
- isGoverned follows the receptor, not a custom context
- timestamp is a DateTime
- create without principal uses defaults
- create with principal inherits from it
- unactivated cell getter throws
- activate returns false for a cell that does not own this nucleus
- Cell.fromNucleus binds and activates the nucleus
- fromNucleus of an already activated nucleus uses a clone
- fromNucleus with bind links the upstream synapses
- inherits context, receptor, and testRule from principal
- local testRule overrides the principal
- local context overrides the principal
- bind is not inherited
- user is inherited
- local user overrides the principal
- walks a chain of principals
- lock falls back to the principal
- clone is a distinct unactivated blueprint
- clone can hydrate an independent cell
- two distinct root nuclei are not equal
- identity equality holds
- evolved nuclei that share a root principal compare equal
- inheritable handle exposes the resolved pillars
- hydrated cell uses the nucleus testRule
- hydrated cell with disabled synapses is terminal

### File 8: test_operators_phase1_foundation.dart (64 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 64 |
| Cell.state | |
| Basic State | |
| State with evolve | |
| Ingest | |
| Edge Cases | |
| Cell.ingress | |
| Basic Ingress | |
| Ingress with Governance | |
| Ingress with Source Binding | |
| Ingest | |
| Edge Cases | |
| Cell.observe | |
| Cell.derive | |
| Basic Derive | |
| Derive with Filtering | |
| Edge Cases | |
| Combined Operators | |

**Tests**

- creates a state cell with initial value
- creates a state cell with null initial value
- creates a state cell with no initial value
- update changes the state value
- update multiple times
- updateAsync changes the state value
- updateAsync with multiple concurrent updates
- cell.async.state reads through the cell lock
- unlocked ValueNucleus still supports async state and updateAsync
- ValueNucleus.from with instruction transforms updates
- ValueNucleus.evolve hydrates a cell from a principal
- ValueNucleus.evolve with instruction transforms updates
- ValueNucleus.evolve with passThrough still commits via postProcess
- ValueNucleus.evolve with a custom receptor commits via postProcess
- ValueNucleus.evolve with override uses the override local record
- ValueCell.terminal holds state without broadcasting
- ValueCell.receptor persists transformed pulses
- unmodifiable projects a nested Cell and is already the view
- evolve modifies incoming pulses
- evolve can filter updates by returning null
- evolve with type conversion
- evolve with complex objects
- evolve with validation
- ingest with pulse
- ingest with serialized completion
- state cell with null update
- creates an ingress cell
- emit sends a pulse through the ingress
- emit with refine transforms the input
- emit with refine can filter input
- emitAsync sends a pulse asynchronously
- emitAsync with multiple concurrent emissions
- ingress with custom context
- ingress with test rule
- ingress with forceLock
- ingress with source bind
- ingest with pulse
- ingest with serialized completion
- ingress with null payload
- ingress with empty string after refine
- ingress with disabled synapses
- creates an observer
- observer receives pulses when started
- observer can be stopped
- observer with initiallyStarted false
- observer with multiple pulses
- observer with String pulses
- observer with complex object pulses
- observer with governed pulse
- observer with null payload
- observer stop called multiple times
- observer start called multiple times
- creates a derived cell
- derive transforms the source value
- derive with type conversion
- derive with multiple transformations
- derive can filter by returning null
- derive filter with complex condition
- derive with null source value
- derive with project that throws
- derive with source changes multiple times
- state + derive + observe
- ingress + derive + observe
- state + derive + state

### File 9: test_operators_phase2_flow_control.dart (43 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 43 |
| Phase 2: Flow Control Operators | |
| Cell.debounce | |
| Cell.throttle | |
| Cell.distinct | |
| Cell.synthesis | |
| Combined Operators | |
| Edge Cases & Error Handling | |
| toString | |

**Tests**

- creates a debounce cell with default leading false
- debounce delays delivery until silence
- debounce resets timer on each pulse
- debounce with leading true emits first immediately
- debounce with zero duration delivers immediately
- debounce cancels a pending timer when the output is invalidated
- debounce with leading true and zero duration emits immediately
- debounce with leading true and burst of three
- creates a throttle cell with defaults
- throttle with leading true emits first immediately
- throttle suppresses pulses during window
- throttle with trailing true emits last during window
- throttle with leading false only emits trailing
- throttle with zero duration delivers the leading pulse
- throttle with leading false and trailing false emits nothing
- creates a distinct cell with default equality
- distinct filters consecutive duplicates
- distinct allows non-consecutive duplicates
- distinct with custom equals function
- distinct with custom equals on objects
- distinct handles null values
- creates a synthesis cell with sources
- synthesis aggregates values from sources
- synthesis receives the triggering pulse
- synthesis with null suppression
- synthesis with complex object types
- synthesis with multiple source types
- synthesis with empty sources does not throw
- synthesis with single source
- debounce then distinct
- throttle then distinct
- synthesis then observe (debounce of synthesis is source-gated)
- synthesis consecutive equal sums still fire (no distinct)
- synthesis for form validation
- debounce with negative duration throws
- throttle with negative duration throws
- distinct with null values and custom equals
- synthesis with sources that are not ValueCell
- synthesis with aggregator throwing exception
- debounce cell toString
- throttle cell toString
- distinct cell toString
- synthesis cell toString

### File 10: test_operators_phase3_async_routing.dart (60 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 60 |
| Phase 3: Async & Routing Operators | |
| Cell.asyncMap | |
| Cell.hub | |
| Cell.switchMap | |
| Cell.fromFuture | |
| Cell.fromStream | |
| Combined Operators | |
| Edge Cases & Error Handling | |
| toString | |

**Tests**

- asyncMap transforms values from a state cell
- asyncMap transforms values from an ingress cell
- asyncMap with concurrency 1 processes sequentially
- asyncMap with latestOnly drops older results
- asyncMap with exhaust ignores while busy
- asyncMap with observe receives results
- asyncMap handles errors gracefully (no emission)
- hub routes pulses to spokes based on type
- hub with prefix routing uses longest prefix match
- hub with pattern routing uses glob matching
- hub with multicast delivers to all matching spokes
- hub multicast with custom match delivers to every interested spoke
- hub with fallback routes unmatched pulses
- hub with priority ordering processes higher priority first
- hub emits async with lock protection
- hub ingest with serialized completion
- hub with governed spokes uses DeputyContext
- hub spoke handler can drive a state cell
- switchMap switches to new cell on source change
- switchMap with observe receives switched values
- switchMap with multiple source changes
- switchMap with null payload does not switch
- fromFuture emits future result
- fromFuture with observe receives value
- fromFuture with state cell receives value
- fromFuture with derived cell transforms value
- fromFuture with delayed Future
- fromFuture emits an error pulse when the Future fails
- fromFuture with complex type
- fromFuture with null value
- fromStream emits stream values
- fromStream with observe receives values
- fromStream with state cell accumulates values
- fromStream with delayed stream
- fromStream with periodic stream
- fromStream with cancelOnError handles errors
- fromStream with distinct filters duplicates
- fromStream with derived transforms values
- fromStream with complex types
- fromStream with null values
- fromStream with empty stream emits nothing
- fromStream cancels the subscription when the cell is invalidated
- ingress + asyncMap + observe
- fromFuture + derive + state
- fromStream + distinct + observe
- ingress + asyncMap + state
- fromFuture + asyncMap + observe
- fromStream + asyncMap + observe
- hub + state for routing
- asyncMap with empty source emits nothing
- hub with no spokes uses fallback
- fromFuture with already completed future
- fromStream with error after values (no cancelOnError)
- hub with multicast and priority
- switchMap with source emitting multiple values
- asyncMap cell toString
- hub toString
- switchMap cell toString
- fromFuture cell toString
- fromStream cell toString

### File 11: test_operators_phase4_advanced_transactions.dart (39 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 39 |
| Phase 4: Advanced & Transactions | |
| Cell.sanitized | |
| Cell.open | |
| Combined Operators | |
| Edge Cases & Error Handling | |
| toString | |

**Tests**

- sanitized redacts sensitive data
- sanitized passes through non-sensitive data
- sanitized with different sensitivity threshold
- sanitized with ingress and observe
- sanitized with state and observe
- sanitized with complex object type
- sanitized with multiple sensitivity levels
- open creates a manually controllable cell
- open with emit sends pulses
- open with ingest and serialized completion
- open with link and unlink observers
- open with observe receives pulses
- open with test rule filters pulses
- open with state receives updates
- open with forceLock serializes emissions
- open with ephemeral policy auto-invalidates
- open with governed context
- async emit and ingest deliver the pulse
- async emit with forceLock still delivers
- modifiable includes emit, ingest, link, and apply
- emit awaits an async testRule
- link awaits an async testRule
- ingress + sanitized + observe
- state + sanitized + observe
- open + state + observe
- ingress + open + observe
- state + transaction + state
- txApply with state and compensation
- sanitized with missing sensitivity passes through
- open with disabled synapses
- transaction with empty participants throws
- txApply with empty participants throws
- transaction with non-existent savepoint throws
- sanitized with null redact result
- sanitized cell toString
- open cell toString
- TransactionValidationException toString
- TransactionConflictException toString
- TxApplyException toString

### File 12: test_propagation_policy.dart (41 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 41 |
| PropagationPolicy | |
| Construction & Defaults | |
| Strategy: immediate | |
| Strategy: debounced | |
| Strategy: throttled | |
| Strategy: batched | |
| Strategy: buffered | |
| Strategy: audit | |
| Strategy: debounceLeading | |
| Strategy: sample | |
| Strategy: exhaust | |
| Strategy: resilient | |
| Strategy: retry | |
| Policy Composition & Equality | |
| Edge Cases | |
| Integration with Synapses | |
| toString | |

**Tests**

- default constructor uses immediate strategy
- constructor sets strategy
- constructor sets debounceTime
- constructor sets throttleTime
- constructor sets batchSize
- constructor with all parameters
- immediate delivers pulses synchronously
- immediate delivers all pulses in order
- debounced delays delivery until silence
- debounced resets timer on each pulse
- debounced with zero duration delivers immediately
- throttled delivers first pulse immediately
- throttled suppresses subsequent pulses during window
- throttled with zero duration delivers all pulses
- batched accumulates pulses until batchSize
- batched with batchSize 1 delivers immediately
- batched with large batch size buffers until threshold
- buffered accumulates pulses and flushes after throttleTime
- buffered flushes when batchSize is reached
- audit delivers the latest pulse at intervals
- audit with zero throttleTime delivers immediately
- debounceLeading delivers first pulse immediately
- sample heartbeats the first pulse then stops when unlinked
- exhaust delivers pulses to downstreams
- resilient delivers when the observer accepts the pulse
- retry delivers when the observer accepts the pulse
- two identical policies are equal
- two different policies are not equal
- policies with different debounce times are not equal
- policies with different throttle times are not equal
- policies with different batch sizes are not equal
- zero duration works
- batchSize of 0 works
- all strategies can be instantiated
- policy with no parameters uses defaults
- policy can be used with synapses
- multiple policies can be used with different synapses
- policy with filter preserves payload
- policy with filter can drop pulses
- policy returns string representation
- policy with immediate strategy toString

### File 13: test_pulse.dart (157 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 157 |
| Pulse | |
| Construction | |
| withStep vs evolve distinction | |
| Evolution | |
| Composition | |
| Shell | |
| Unmodifiable | |
| Comparison | |
| Iterable | |
| Governance | |
| Provenance | |
| Policy | |
| Context Factories | |
| PulseExtension | |
| PulseIterableExtension | |
| Causal Chain Distinction | |
| toString | |
| Callbacks and mask variants | |
| Lineage extras | |
| Unmodifiable collective | |
| Shell extras | |
| Composition extras | |

**Tests**

- creates a simple pulse with payload
- creates a pulse with type
- creates a pulse with priority
- creates a pulse with source
- creates a pulse with step
- creates a governed pulse with context
- creates a governed pulse with policy
- creates a governed pulse with context and callbacks
- Pulse.governed without context or policy is NOT governed
- Pulse.governed with only callbacks is NOT governed
- withStep does NOT create an EvolvedPulse
- evolve with ONLY step does NOT create an EvolvedPulse
- evolve with ONLY context does NOT create an EvolvedPulse
- evolve with pulse creates an EvolvedPulse (causal branch)
- evolve with pulse but no step creates EvolvedPulse
- withStep vs evolve(step) are semantically similar
- withStep lengthens lineage without causal branching
- evolve(step) lengthens lineage without causal branching
- withStep preserves identity, context, and payload
- evolve(step) preserves identity, context, and payload
- evolve with pulse creates parent-child relationship
- withStep adds a trace step
- withStep chains multiple steps
- evolve(step) adds trace step without EvolvedPulse
- evolve(step) chains multiple steps without EvolvedPulse
- evolve with context and step adds trace without EvolvedPulse
- evolve with pulse appends and creates EvolvedPulse
- evolve requires at least one parameter
- lineage tracks payload history with evolve(pulse)
- lineage tracks type history with evolve(pulse)
- lineage tracks priority history with evolve(pulse)
- lineage tracks source history with evolve(pulse)
- withStep does NOT affect lineage history
- evolve(step) does NOT affect lineage history
- evolve with pulse creates causal chain, evolve(step) does not
- + operator creates collective pulse
- + operator with multiple pulses
- Pulse.batch creates collective pulse
- Pulse.batch with governed pulses
- Pulse.batch with callback
- shell hides payload
- shell scrutinizes receptor
- shell with governed pulse
- unmodifiable locks payload of this specific instance
- unmodifiable prevents mutation of the instance
- unmodifiable does NOT block withStep - creates new modifiable instance
- unmodifiable does NOT block evolve(step) - creates new modifiable instance
- unmodifiable protects the payload cell from mutation
- unmodifiable recursively protects parent chain for EvolvedPulse
- unmodifiable with evolve(step) does NOT create recursive parent chain
- unmodifiable recursively protects root and source
- unmodifiable preserves reactivity of payload cell
- unmodifiable is recursive for nested iterables
- unmodifiable allows reading payload but blocks modifications
- evolve with pulse from unmodifiable preserves protected instance as parent
- withStep from unmodifiable creates new modifiable instance
- unmodifiable does not prevent withStep chain
- unmodifiable blocks modifications but not observations
- compareTo orders by timestamp
- compareTo orders by priority when timestamps equal
- compareTo orders by trace depth when timestamps and priority equal
- equality uses record comparison
- identity equality works
- hashCode is stable
- iterating over single pulse yields itself
- iterating over withStep pulse yields itself (not EvolvedPulse)
- iterating over evolve(step) pulse yields itself (not EvolvedPulse)
- iterating over evolve(pulse) yields EvolvedPulse
- iterating over collective pulse yields itself
- collective payload iteration yields individual pulses
- isGoverned returns true when context provided
- isGoverned returns true when policy provided
- isGoverned returns false when no context or policy
- isGoverned returns false when only callbacks provided
- isGoverned returns true when context is inherited via evolve(step)
- isGoverned returns true when context is inherited via evolve(pulse)
- withStep does NOT inherit governance differently
- isInvalidated returns false initially
- isInvalidated returns true after policy expires
- context stores actor
- context stores reason
- context stores purpose
- context stores strategy
- context stores confidence
- context stores priority
- context stores sensitivity
- context stores auditLevel
- context stores traceId
- context auto-generates traceId
- context stores parentTraceId
- context stores compliance
- policy tracks hops
- policy invalidates on hop limit
- policy invalidates on TTL
- userAction factory creates correct context
- aiInference factory creates correct context
- regulated factory creates correct context
- securityIntervention factory creates correct context
- systemInternal factory creates correct context
- homeostasis factory creates correct context
- telemetry factory creates correct context
- instruction factory creates correct context
- selfCorrection factory creates correct context
- collaboration factory creates correct context
- hypothesis factory creates correct context
- infrastructureChange factory creates correct context
- Iterable.map on a Pulse is not PulseExtension.map
- Iterable.cast on a Pulse is not PulseExtension.cast
- map transforms payload and preserves causality
- map does not mutate the original pulse
- map keeps ancestor withStep entries via parent walk
- map keeps the original context and governance on the evolved child
- chained maps nest EvolvedPulse parents
- same-type map lineage includes parent and child payloads
- mixed-type map lineage skips payloads that fail the cast
- attach adds context metadata
- tap executes side-effect without modifying pulse
- cast re-types payload via evolve(pulse:)
- cast of a typed pulse still creates an EvolvedPulse child
- incompatible PulseExtension.cast throws
- batch creates collective from iterable
- flatten converts nested collective to flat sequence
- withStep adds step to all pulses (not EvolvedPulse)
- attach adds context to all pulses
- mapEach transforms payload of each pulse
- withStep does NOT create parent-child relationship
- evolve(step) does NOT create parent-child relationship
- evolve(pulse) creates parent-child relationship
- withStep is for documentation, evolve(pulse) is for causal branching
- withStep does NOT affect root.trace
- evolve(pulse) affects parent chain but root remains oblivious
- withStep and evolve(pulse) can be combined
- formats a payload-only pulse
- formats a null payload
- includes source, type, and trace when present
- collective toString names CollectivePulse
- evolved pulse toString names EvolvedPulse
- onError-only governed pulse is constructible
- onProgress-only governed pulse is constructible
- onComplete and onProgress together
- all three callbacks plus policy and source
- lineage of policy and context walks the chain
- equality with a non-Pulse is false
- batch.unmodifiable is a composite with unmodifiable members
- unmodifiable compareTo and equality delegate to the source
- unmodifiable wraps a Cell payload
- unmodifiable wraps a Map payload containing a Cell
- shell compareTo follows timestamp then priority
- shell + / evolve / withStep are unsupported
- shell exposes kernel priority and source
- shell compareTo uses priority then trace when timestamps match
- shell scrutinize catch returns null when the kernel rejects
- + of mixed payload types still builds a collective
- a withStep child of a governed pulse stays governed
- CollectivePulse.governed stores type, context, step, and scrutinize
- evolved unmodifiable exposes parent, iterator, and toString
- Pulse.evolve(pulse:) with step, context, and a completing parent

### File 14: test_receptor.dart (50 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 50 |
| Receptor | |
| passThrough | |
| Construction | |
| Activation & clone | |
| Pipeline | |
| Instruction composition | |
| Instruction.future | |
| Receptor.async | |
| Graph integration | |
| call contract extras | |
| Receptor.pipeline mask | |

**Tests**

- is a reusable singleton
- forwards the pulse unchanged without activation
- cannot be activated
- clone is the same instance
- async is unsupported
- cell getter is unsupported
- is never governed
- passThroughRule is an identity instruction
- passThroughRule + other yields the other instruction
- hashCode is stable on the singleton
- passThrough == a ReceptorBase is true; the reverse is not
- closure receptor transforms payload
- closure receptor returning null drops the pulse
- closure receptor exception terminates the pulse
- Receptor.instruction wraps a reusable instruction
- Instruction user metadata is available during execution
- Receptor.instruction stores a user factory on the receptor
- Receptor.typed transforms between pulse payload types
- empty pipeline is a pass-through
- template is not activated until bound
- Cell construction activates an unbound template in place
- activate binds the host cell
- clone is an independent unactivated copy
- unactivated call fails the activation assertion
- runs preProcess then instruction then postProcess
- a throwing custom instruction in the pipeline returns null
- null from a stage short-circuits later stages
- postProcess can drop after a successful core stage
- omitted stages are skipped
- preProcess and postProcess run without a core instruction
- instruction exception terminates the pipeline
- + chains two instructions in order
- Instruction.chain is equivalent to +
- chain short-circuits on null
- chains nest
- instruction exception returns null
- returns null immediately and resumes via future callback
- hook captures the transformed result
- hook sees null when the receptor drops the pulse
- serializedCompletion false still processes via the hook
- Cell(bind:) delivers transformed pulses to observers
- testRule on the host can drop pulses before transformation
- null from the bound receptor suppresses observers
- async testRule Future is awaited before transformation
- a PulseShell is scrutinized instead of run through the pipeline
- async call scrutinizes a PulseShell
- governed pulse on a deputy host records the mandate role
- stores reaction and isGoverned flyweight combinations
- a reaction receptor transforms without an instruction chain
- a governed receptor ticks a hosted EphemeralPolicy

### File 15: test_synapses.dart (82 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 82 |
| Synapses | |
| disabled | |
| enabled | |
| Construction & broadcast | |
| link / unlink | |
| FilterRule | |
| relay | |
| PropagationPolicy | |
| async view | |
| remaining strategies | |
| mask combinations and equality | |
| Graph integration | |

**Tests**

- is a reusable singleton
- call is a no-op
- link and unlink return false
- is an empty iterable
- async is unsupported
- Cell with disabled synapses is terminal
- is a reusable singleton flyweight
- link and unlink return false on the flyweight
- is an empty iterable
- async is unsupported on the flyweight
- Cell with default synapses is not terminal
- empty synapses complete a pulse without observers
- constructor registers initial downstreams
- call delivers to every downstream in order
- call delivers successive pulses in order
- cycle checker skips a downstream already visited by the pulse
- empty synapses still complete a governed pulse with onComplete
- link adds an observer when the synapses belong to the host
- link returns false when the synapses are not the host\
- duplicate link returns false
- unlink removes an observer
- unlink of a missing observer returns false
- link is rejected when the host testRule denies the observer
- async testRule Future is awaited on link
- filter transforms the outgoing payload
- filter returning null drops the pulse
- + chains filters sequentially
- FilterRule.chain stops when a stage returns null
- FilterRule.base is an identity
- a throwing filter leaves the original pulse
- FilterRule.user is passed to the rule
- parent runs after the primary rule
- chain parent runs after the collected rules
- chain strategy overrides sequential rules and still calls parent
- fromRecord reconstitutes a callable rule
- equality and hashCode follow the flyweight record
- relay replaces sequential broadcast
- relay is skipped when every downstream already saw the pulse
- default strategy delivers immediately
- async strategy delivers on a later event-loop turn
- persistent replays the last pulse to a newly linked observer
- persistent with an existing observer stores and delivers
- async.call delivers to downstreams
- async.call on empty synapses completes without observers
- async.call on empty synapses completes a governed onComplete pulse
- async.call applies the source filter
- async.call respects a zero-duration debounce policy
- async.call respects a zero-duration throttle policy
- async.call batches until batchSize
- async.call with audit zero throttle delivers immediately
- async.call with exhaust delivers
- async.call with resilient delivers
- async.call with retry delivers
- async.call with debounceLeading zero throttle delivers
- async.call uses a custom relay
- async.call with async strategy delivers
- async.call with non-zero debounce delivers after the window
- async.call with non-zero throttle delivers the leading pulse
- async.call with audit non-zero window delivers the latest
- async.call buffered flushes on batchSize
- async.call buffered flushes after throttleTime
- async.call debounceLeading non-zero throttle delivers the first pulse
- async.call persistent delivers to current observers
- async.call on a revisited pulse does not re-notify
- async relay is skipped when every downstream already saw the pulse
- async resilient swallows a throwing relay
- async retry retries a throwing relay then gives up
- async.call sample heartbeats the first pulse then stops when unlinked
- async debounce completes after observers are unlinked
- exhaust delivers the pulse
- resilient delivers when downstreams succeed
- retry delivers when downstreams succeed
- debounceLeading with zero throttle delivers every pulse
- buffered Duration.zero flushes on the first pulse
- resilient swallows a throwing relay
- retry retries a throwing relay then gives up
- sample heartbeats then stops when unlinked
- debounced pulse completes after observers are unlinked
- filter plus relay plus policy is a valid synapses
- two synapses instances are not identical
- host synapses broadcast a bound source emission
- filter on the host synapses redacts before observers

### File 16: test_synthesis_cell.dart (37 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 37 |
| SynthesisCell | |
| Construction | |
| Aggregation | |
| Source Management | |
| Stop/Start | |
| Edge Cases & Error Handling | |
| Context & Governance | |
| Real-World Scenarios | |
| toString | |

**Tests**

- creates a synthesis cell with sources
- creates a synthesis cell with custom context
- creates a synthesis cell with custom test rule
- creates a synthesis cell with disabled synapses (terminal)
- creates a synthesis cell with forceLock
- empty sources does not throw
- aggregator combines values from multiple sources
- aggregator receives the emitting pulse
- aggregator can access all source values
- aggregator returning null suppresses emission
- aggregator with complex object types
- does not emit an initial aggregate
- synthesis cell is iterable over sources
- synthesis handle can add sources dynamically
- added source participates in aggregation
- synthesis handle can remove sources dynamically
- synthesis handle can add multiple sources
- synthesis handle can remove multiple sources
- synthesis handle can clear all sources
- synthesis handle reports isEmpty correctly
- synthesis handle toList returns current sources
- stop prevents aggregation from sources
- stop disconnects all sources but keeps membership
- handles null values from sources
- handles sources that are not ValueCell
- handles aggregator throwing exception gracefully
- handles removing non-existent source
- handles adding duplicate source
- synthesis cell does not inherit context from sources
- synthesis cell with custom context overrides
- synthesis cell validation rule applies to incoming pulses
- synthesis for form validation - all fields valid
- synthesis for price calculation with tax and discount
- synthesis for user profile - derived full name
- synthesis for counter - sum of multiple counters
- synthesis cell returns string representation
- synthesis cell shows sources in string representation

### File 17: test_test_cell.dart (41 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 41 |
| TestCell | |
| allowAll | |
| readOnly | |
| Construction | |
| Composition | |
| Exceptions | |
| Async | |
| TestPulseRule | |
| TestLinkRule | |
| TestActionRule | |
| Graph integration | |
| TestRule | |

**Tests**

- is a reusable TestPasses singleton
- allows every object
- allows links, pulses, and actions
- allowAll + customRule behaves like the custom rule
- is a reusable singleton
- allows observation of values and pulses
- blocks apply when the action is on the modifiable whitelist
- call on a Function consults action
- readOnly + customRule delegates to the custom rule
- TestPasses is the allowAll implementation
- readOnly action with arguments still allows non-modifiable tear-offs
- custom rule allows matching values
- custom rule can inspect a Pulse payload
- user metadata is passed to the rule
- parent is evaluated after this rule passes
- + evaluates left to right and short-circuits
- TestCell.chain is fail-fast like +
- chains nest
- a throwing rule passes when the host is ungoverned
- a throwing rule with no host passes
- an async rule is awaited
- accepts pulses that match the predicate
- non-pulse objects pass the wrapped call
- TestCell.pulse consults chained TestPulseRules
- TestCell.pulse awaits chained async TestPulseRules
- accepts links that match the predicate
- TestCell.link consults chained TestLinkRules
- TestCell.link awaits chained async TestLinkRules
- accepts actions that match the predicate
- TestCell.action validates positional arguments via call
- TestCell.action validates named arguments via call
- TestCell.action awaits chained async TestActionRules
- cell.validate uses the TestCell rule
- pulse validation on a cell drops odd payloads
- link is rejected when the host TestCell denies the observer
- an async rule still consults parent
- chain awaits an async rule and continues
- chain short-circuits later rules when an async rule fails
- chain rethrows an Exception from a child rule
- equality and hashCode follow the flyweight record
- fromRecord reconstitutes a callable rule

### File 18: test_test_rule_meta.dart (48 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 48 |
| DefaultValue | |
| MaxLength | |
| direct field limit | |
| hostLength | |
| composite field + container | |
| host-only | |
| ValueRange | |
| EntryPattern | |
| Values | |
| EmailPattern | |
| WebsiteUrlPattern | |
| TestRule composition | |

**Tests**

- stores a primitive constant
- stores a string, bool, list, and map
- is a const annotation, not a TestRule
- allows a string at or under the limit
- rejects a string over the limit
- allows an iterable at or under the limit
- rejects an iterable over the limit
- passes non-string, non-iterable objects
- rejects when the host iterable exceeds hostLength
- allows a host iterable at the hostLength
- ignores a non-iterable host and still checks the object
- rejects an over-long element even when the host is in quota
- rejects an over-long host even when the element is in quota
- allows when both the element and the host are in quota
- checks a list object against length when no host is passed
- stores the sentinel direct length and the host limit
- does not limit the annotated object
- rejects an over-long host container
- passes when the host is absent
- stores inclusive bounds
- allows integers on the inclusive bounds
- rejects integers outside the range
- allows doubles on a unit interval
- passes null and non-numeric values
- always fails numbers when min is greater than max
- stores pattern flags with documented defaults
- matches a non-empty string against the pattern
- is case-insensitive by default
- honors caseSensitive: true
- rejects null unless allowNull is true
- rejects empty strings unless allowEmpty is true
- passes non-string objects
- allows members of the whitelist
- rejects values not in the whitelist
- rejects null unless null is listed
- matches numeric option sets by ==
- uses the documented default flags
- accepts typical email addresses
- rejects malformed addresses and empty strings
- allows null by default and can reject it
- accepts a custom corporate pattern
- uses the documented default flags
- accepts typical web addresses
- rejects empty strings and non-urls
- allows null by default and can reject it
- accepts a custom pattern
- MaxLength is a TestRule
- MaxLength + ValueRange short-circuits on the first failure

### File 19: test_transaction.dart (54 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 54 |
| Cell.transaction | |
| Basic Transaction | |
| Isolation Levels | |
| Lock Ordering | |
| Validation | |
| Custom Apply | |
| Savepoint | |
| Timeout | |
| Events | |
| Cell Types | |
| Real-World Scenarios | |
| Edge Cases & Error Handling | |
| Exception toString | |

**Tests**

- commits multiple updates atomically
- rollback discards all changes
- commit after rollback works
- cannot begin while transaction is active
- cannot update cell not in transaction
- cannot read cell not in transaction
- transaction with single cell
- empty cells list throws
- readCommitted reads current live values
- repeatableRead reads snapshot from begin
- repeatableRead detects conflict on changed cell
- serializable tracks read set
- serializable ignores unread, unwritten participant changes
- serializable commits globally serialized
- byHashCode orders locks by hash code
- insertion orders locks by insertion order
- explicit uses custom comparator
- explicit without comparator throws
- validation fails on invalid value
- custom validate callback can override
- multiple cells validation
- cell testRule rejects negatives at commit
- custom apply callback overrides default
- custom apply with side effects
- custom apply with multiple cells
- savepoint captures state for rollback
- multiple savepoint
- rollback to unknown savepoint throws
- savepoint after rollback
- transaction times out
- timeout triggers rollback
- timeout event emitted
- TransactionBegun event emitted
- TransactionUpdated event emitted
- TransactionCommitted event emitted
- TransactionRolledBack event emitted
- TransactionRolledBack with savepoint event emitted
- transaction with ValueCell
- transaction with non-ValueCell (CellBase)
- pending reads see buffered writes
- pending falls back to read
- bank transfer with validation to prevent negative
- bank transfer commits when balances stay non-negative
- multi-step operation with savepoint
- concurrent transactions isolation
- updating same cell multiple times uses last value
- rollback when no transaction active is no-op
- commit when no transaction active throws
- transaction with options and all callbacks
- transaction with null values
- transaction with non-int values
- TransactionValidationException toString
- TransactionConflictException toString
- TransactionTimeoutException toString

### File 20: test_tx_apply.dart (46 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 46 |
| Cell.txApply | |
| Basic Operations | |
| Compensation | |
| Error Handling | |
| Stop On First Failure | |
| Savepoint | |
| Real-World Scenarios | |
| Events | |
| Edge Cases & Error Handling | |
| Custom Comparator | |
| Exception toString | |

**Tests**

- executes a single apply with txApply
- executes multiple applies with txApply
- txApply with multiple participants
- txApply with custom apply options
- apply without tx runs immediately
- compensation is called when a later apply fails
- compensation with custom cell
- compensation with multiple retries
- rollback before commit skips compensation by default
- compensateIfNotExecuted runs undo on rollback of staged calls
- txApply throws when participant not included
- enqueue of a non-modifiable function is rejected
- txApply with compensation error policy
- txApply with failFast compensation policy
- txApply with collectThenThrow compensation policy
- stopOnFirstFailure stops execution on first failure
- stopOnFirstFailure false continues execution
- txApply savepoint captures state
- txApply rollback to savepoint
- txApply rollback all
- txApply for bank transfer with compensation
- oversized transfer rolls back via compensation
- txApply for multi-step data migration
- txApply for inventory adjustment
- TxApplyBegun event emitted
- TxApplyStaged event emitted
- TxApplyCommitted event emitted
- TxApplyRolledBack event emitted
- TxApplyRejected event emitted on rejection
- txApply with empty participants throws
- txApply commit without begin throws
- txApply with null compensation
- txApply with compensation cell different from operation cell
- txApply with compensation named arguments
- begin while already begun throws
- txApply with custom comparator
- TxApplyException toString
- TxApplyCompensationException toString
- enqueue rejects a compensate cell that is not a participant
- enqueue rejects a compensate function not in modifiable
- commit rejects a function removed from modifiable
- commit rejects compensate removed from modifiable
- default compensation backoff retries a transient undo
- compensation ApplyRejected is not retryable by default
- ApplyRejected during commit rethrows failFast compensation
- CompensationFailure toString

---

## Runtime Verification Status

Working directory: `packages/cell` (package-relative; host paths omitted).

If tests are named `test_*.dart` instead of `*_test.dart`, `dart test` with
no path finds nothing. Pass explicit files:

```bash
dart pub get
dart test \
  test/test_cell.dart \
  test/test_cell_policy.dart \
  test/test_commons.dart \
  test/test_context.dart \
  test/test_deputy.dart \
  test/test_instruction.dart \
  test/test_nucleus.dart \
  test/test_operators_phase1_foundation.dart \
  test/test_operators_phase2_flow_control.dart \
  test/test_operators_phase3_async_routing.dart \
  test/test_operators_phase4_advanced_transactions.dart \
  test/test_propagation_policy.dart \
  test/test_pulse.dart \
  test/test_receptor.dart \
  test/test_synapses.dart \
  test/test_synthesis_cell.dart \
  test/test_test_cell.dart \
  test/test_test_rule_meta.dart \
  test/test_transaction.dart \
  test/test_tx_apply.dart
```

### Last `dart test`

| Passed | Failed | Skipped | Exit |
|-------:|-------:|--------:|-----:|
| 1115 | 0 | 0 | 0 |

Status: **green**.

<details><summary>tail of test log</summary>

```
0:04 +1106: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators Edge Cases & Error Handling fromStream with error after values (no cancelOnError)                       
00:04 +1107: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators Edge Cases & Error Handling fromStream with error after values (no cancelOnError)                       
00:04 +1108: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators Edge Cases & Error Handling fromStream with error after values (no cancelOnError)                       
00:04 +1108: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators Edge Cases & Error Handling hub with multicast and priority                                             
00:04 +1109: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators Edge Cases & Error Handling hub with multicast and priority                                             
00:04 +1109: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators Edge Cases & Error Handling switchMap with source emitting multiple values                              
00:05 +1109: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators Edge Cases & Error Handling switchMap with source emitting multiple values                              
00:05 +1110: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators Edge Cases & Error Handling switchMap with source emitting multiple values                              
00:05 +1110: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators toString asyncMap cell toString                                                                         
00:05 +1111: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators toString asyncMap cell toString                                                                         
00:05 +1111: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators toString hub toString                                                                                   
00:05 +1112: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators toString hub toString                                                                                   
00:05 +1112: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators toString switchMap cell toString                                                                        
00:05 +1113: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators toString switchMap cell toString                                                                        
00:05 +1113: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators toString fromFuture cell toString                                                                       
00:05 +1114: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators toString fromFuture cell toString                                                                       
00:05 +1114: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators toString fromStream cell toString                                                                       
00:05 +1115: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators toString fromStream cell toString                                                                       
00:06 +1115: test/test_operators_phase3_async_routing.dart: Phase 3: Async & Routing Operators toString fromStream cell toString                                                                       
00:06 +1115: All tests passed!
```

</details>

### Line Coverage (`lib/`)

**Overall: 3411 / 3587 lines = 95.1%**

| File | Hit | Found | Line % |
|------|----:|------:|-------:|
| `lib/src/deputy.dart` | 10 | 10 | 100.0 |
| `lib/src/internal/cell.dart` | 120 | 120 | 100.0 |
| `lib/src/internal/operator/operator_debounce.dart` | 35 | 35 | 100.0 |
| `lib/src/internal/pulse_extensions.dart` | 19 | 19 | 100.0 |
| `lib/src/internal/test_cell.dart` | 33 | 33 | 100.0 |
| `lib/src/internal/value.dart` | 12 | 12 | 100.0 |
| `lib/src/nucleus.dart` | 5 | 5 | 100.0 |
| `lib/src/pulse.dart` | 4 | 4 | 100.0 |
| `lib/src/synapses.dart` | 25 | 25 | 100.0 |
| `lib/src/test_cell.dart` | 75 | 75 | 100.0 |
| `lib/src/test_rule.dart` | 40 | 40 | 100.0 |
| `lib/src/test_rule_meta.dart` | 29 | 29 | 100.0 |
| `lib/src/value.dart` | 71 | 71 | 100.0 |
| `lib/src/internal/operator/operator_transaction.dart` | 172 | 173 | 99.4 |
| `lib/src/internal/deputy_context.dart` | 112 | 113 | 99.1 |
| `lib/src/internal/synapses.dart` | 455 | 460 | 98.9 |
| `lib/src/internal/operator/operator_tx_apply.dart` | 174 | 178 | 97.8 |
| `lib/src/internal/cell_policy.dart` | 41 | 42 | 97.6 |
| `lib/src/internal/operator/operator_async_map.dart` | 41 | 42 | 97.6 |
| `lib/src/internal/commons.dart` | 283 | 290 | 97.6 |
| `lib/src/internal/receptor.dart` | 192 | 197 | 97.5 |
| `lib/src/internal/operator/operators.dart` | 94 | 98 | 95.9 |
| `lib/src/cell.dart` | 51 | 54 | 94.4 |
| `lib/src/internal/deputy.dart` | 17 | 18 | 94.4 |
| `lib/src/internal/nucleus.dart` | 181 | 192 | 94.3 |
| `lib/src/internal/operator/operator_hub.dart` | 94 | 100 | 94.0 |
| `lib/src/internal/pulse_policy.dart` | 30 | 32 | 93.8 |
| `lib/src/internal/context.dart` | 111 | 119 | 93.3 |
| `lib/src/internal/operator/operator_throttle.dart` | 37 | 40 | 92.5 |
| `lib/src/internal/pulse_context.dart` | 237 | 258 | 91.9 |
| `lib/src/internal/pulse.dart` | 424 | 469 | 90.4 |
| `lib/src/context.dart` | 149 | 165 | 90.3 |
| `lib/src/receptor.dart` | 38 | 69 | 55.1 |

---

## Recommendations

1. Keep this report generated — do not hand-count `test(`.
2. CI should pass the explicit file list below (or a `dart_test.yaml`) because `cell` uses `test_*.dart` naming.
3. The operator phase files (`test_operators_phase*.dart`) exercise the instruction pipeline; keep them in sync with `lib/src/internal/operator/`.
4. Cross-package dependents (`cell_tissue`, `cell_flow`) rely on these contracts — add integration tests when the core APIs change.
5. Track coverage per public/internal pair (`lib/src/*.dart` vs `lib/src/internal/*.dart`), not just the whole `lib/` average.

---

## Appendix: File Locations

```
test/
├── test_cell.dart  (72 tests, 38.6 KB, 1,098 lines)
├── test_cell_policy.dart  (38 tests, 20.4 KB, 598 lines)
├── test_commons.dart  (43 tests, 13.6 KB, 449 lines)
├── test_context.dart  (117 tests, 60.7 KB, 1,628 lines)
├── test_deputy.dart  (21 tests, 8.3 KB, 255 lines)
├── test_instruction.dart  (23 tests, 12.3 KB, 354 lines)
├── test_nucleus.dart  (39 tests, 12.2 KB, 352 lines)
├── test_operators_phase1_foundation.dart  (64 tests, 36.5 KB, 1,045 lines)
├── test_operators_phase2_flow_control.dart  (43 tests, 22.3 KB, 766 lines)
├── test_operators_phase3_async_routing.dart  (60 tests, 30.2 KB, 1,042 lines)
├── test_operators_phase4_advanced_transactions.dart  (39 tests, 23.7 KB, 779 lines)
├── test_propagation_policy.dart  (41 tests, 28.0 KB, 748 lines)
├── test_pulse.dart  (157 tests, 70.8 KB, 1,828 lines)
├── test_receptor.dart  (50 tests, 23.6 KB, 680 lines)
├── test_synapses.dart  (82 tests, 37.5 KB, 1,148 lines)
├── test_synthesis_cell.dart  (37 tests, 21.0 KB, 625 lines)
├── test_test_cell.dart  (41 tests, 19.1 KB, 579 lines)
├── test_test_rule_meta.dart  (48 tests, 11.8 KB, 351 lines)
├── test_transaction.dart  (54 tests, 35.8 KB, 1,193 lines)
├── test_tx_apply.dart  (46 tests, 32.3 KB, 1,103 lines)
```

**Total lines of test code:** 16,621

*Generated 2026-09-13 by generate_test_verification.py*
