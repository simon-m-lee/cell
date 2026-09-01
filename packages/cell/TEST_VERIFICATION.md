# Cell Framework - Test Verification Report

**Generated:** 2026-09-01  
**Package:** cell (v1.0.0-rc.1)  
**Test Files Analyzed:** 20  
**Total Tests:** 1115 (0 skipped)

---

## Executive Summary

The Cell framework test suite contains **1115 unit tests** across **20 files** in `packages/cell/test/`. Coverage spans core types (`Cell`, `Pulse`, `Nucleus`, `Receptor`, `Instruction`, `Synapses`, `TestCell` / `TestRule`), **`Context` / `DeputyContext` / `PulseContext`** (`test_context.dart`), **`EphemeralPolicy`** (`test_cell_policy.dart`), **annotation `TestRule`s** (`test_test_rule_meta.dart`), **`commons.dart` collections** (`test_commons.dart`), **Cell / OpenCell deputy** (`test_deputy.dart`), **`PulseExtension.map` / `cast`** against `evolve(pulse:)`, **`FilterRule` parent / `fromRecord` / equality**, **async synapses policies**, **`PropagationStrategy.sample`**, **`ValueNucleus` / `ValueCell` constructors**, synthesis, `Cell.transaction` / `Cell.txApply`, the Core 16 operators, **`Cell.valve`**, and **`OpenCell.perform`**. Counts are `test(` declarations. None are skipped.

Suites follow **public APIs and documented contracts** (for example `Cell.ingress` / `Cell.observe` to drive operators, aggregators that return `Pulse`, `synapses.call` for policy, `activate` / `fromNucleus` for receptors and nuclei).

Line coverage of `lib/` was **re-measured** on 2026-09-01 with `dart test --coverage=coverage`: **95.9%** of instrumented lines (3397 / 3541). This is not a production-readiness claim. Operator coverage lives in `test_operators_phase1_foundation.dart` … `phase4_advanced_transactions.dart`, plus `Cell.valve` / `OpenCell.perform` in `test_cell.dart`. Context, EphemeralPolicy, `test_rule_meta`, commons, deputy, `ValueCell.async`, synapses strategies including sample/async debounce/throttle/audit/buffered/retry/resilient, Pulse `toString`/shell/unmodifiable, TestCell readOnly composition, `PulseExtension.map` / `cast`, `FilterRule` parent/`fromRecord`, `ValueNucleus.from` / `evolve`, `ValueCell.terminal` / `receptor`, standalone `TestRule` async parent/chain, `OpenCell.async` emit/ingest, `Receptor.pipeline` reaction/`isGoverned`/`init` mask combinations, `PulseShell` scrutinize, and `Cell.debounce` `ephemeralPolicy` now have dedicated cases. `Nucleus.isInvalidated` / `Cell.isInvalidated` follow a hosted `EphemeralPolicy`. `_DebounceState.cancel` runs on re-arm, zero duration, timer fire, and output invalidation.

### Quick Stats

| Metric | Value |
|--------|-------|
| **Total Test Files** | 20 |
| **Total Tests** | 1115 |
| **Skipped** | 0 |
| **Last full run** | 1115 passed, 0 failed, 0 skipped (~7 s wall clock with coverage, 2026-09-01) |
| **Test Groups** | 251 (`group(` declarations, including nested groups) |
| **Async Tests** | 350 (`test(..., () async`) |
| **Sync Tests** | 765 |
| **Line coverage (`lib/`)** | **95.9%** (3397 / 3541 instrumented lines; VM coverage → lcov; measured 2026-09-01) |
| **API Compatibility** | Public APIs exercised by the suite match current contracts, including `Cell.valve`, `OpenCell.perform` (there is no `Cell.perform` static), Context / DeputyContext / PulseContext, EphemeralPolicy, annotation TestRules, commons collections, Cell / OpenCell deputy, and `PulseExtension.map` / `cast` |

---

## Test File Inventory

| # | File | Lines | Tests | Size | Focus |
|---|------|------:|------:|------:|-------|
| 1 | test_cell.dart | 1,096 | 72 | 38.6 KB | Core Cell factories, deputy, apply, validate, `Cell.valve`, `OpenCell.perform` |
| 2 | test_pulse.dart | 1,826 | 157 | 70.8 KB | Pulse, evolve/withStep, batch, shell, unmodifiable, PulseContext, `compareTo`, `PulseExtension.map` / `cast` |
| 3 | test_nucleus.dart | 350 | 39 | 12.2 KB | Nucleus / Nucleolus, evolve, clone, `Cell.fromNucleus` |
| 4 | test_receptor.dart | 678 | 50 | 23.5 KB | Receptor factories, pipeline reaction/`isGoverned` mask, clone, async hook, PulseShell, graph bind |
| 5 | test_instruction.dart | 350 | 23 | 12.3 KB | Instruction, `+` / chain / strategy, `Instruction.future`, custom throwing stage |
| 6 | test_synapses.dart | 1,146 | 82 | 37.4 KB | Synapses enabled/disabled, link/unlink, FilterRule, relay cycle, async policies, persistent, retry/resilient, sample |
| 7 | test_propagation_policy.dart | 746 | 41 | 27.9 KB | PropagationPolicy strategies including sample, equality |
| 8 | test_test_cell.dart | 577 | 41 | 19.1 KB | TestCell allowAll/readOnly, chain, pulse/link/action rules; standalone TestRule |
| 9 | test_synthesis_cell.dart | 623 | 37 | 21.0 KB | SynthesisCell, handle add/remove/stop, aggregation |
| 10 | test_transaction.dart | 1,191 | 54 | 35.7 KB | `Cell.transaction` isolation, locks, savepoints, events |
| 11 | test_tx_apply.dart | 1,101 | 46 | 32.2 KB | `Cell.txApply` staging, compensation, events |
| 12 | test_operators_phase1_foundation.dart | 1,043 | 64 | 36.5 KB | `state`, `ingress`, `observe`, `derive`; ValueNucleus.from/evolve, ValueCell.terminal/receptor |
| 13 | test_operators_phase2_flow_control.dart | 764 | 43 | 22.3 KB | `debounce` (including `ephemeralPolicy` cancel), `throttle`, `distinct`, `synthesis` |
| 14 | test_operators_phase3_async_routing.dart | 1,040 | 60 | 30.2 KB | `asyncMap`, `hub`, `switchMap`, `fromFuture`, `fromStream` |
| 15 | test_operators_phase4_advanced_transactions.dart | 777 | 39 | 23.6 KB | `sanitized`, `open` including `async` emit/ingest, combined tx / txApply |
| 16 | test_context.dart | 1,626 | 117 | 60.7 KB | Context, DeputyContext, PulseContext, Ontology / Mandate / Provenance |
| 17 | test_cell_policy.dart | 596 | 38 | 20.4 KB | `EphemeralPolicy` TTL, eventLimit, `call`, `mask`, dispose; Cell/Nucleus follow hosted policy |
| 18 | test_test_rule_meta.dart | 349 | 48 | 11.7 KB | `DefaultValue`, `MaxLength`, `ValueRange`, `EntryPattern`, `Values`, email/URL patterns |
| 19 | test_commons.dart | 447 | 43 | 13.6 KB | `mapMerge`, SyncSet, QueueList, PriorityQueue, SyncQueue, Box / `get` |
| 20 | test_deputy.dart | 253 | 21 | 8.3 KB | Cell / OpenCell deputy identity, rule layering, apply forwarding, causal integrity |
| **Total** | | **16,581** | **1115** | **558.0 KB** | |

---

## Detailed Test Coverage

### File 1: test_cell.dart (72 tests)

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| Factory Constructors | 5 | `Cell()`, `Cell.governed`, `Cell.fromNucleus` |
| Identity & Equality | 4 | Distinct cells, deputy identity, nested-deputy `hashCode`, set membership |
| Apply | 7 | Whitelisted functions, positional/named args, testRule block, async allow/deny |
| Modifiable | 2 | Whitelist contents, read-only cell |
| Terminal & State | 5 | `isTerminal`, `isInvalidated`, `isGoverned` |
| Deputy | 6 | No-op, testRule, context, ephemeral, nested deputy |
| Async | 6 | `async.apply` args, result, no lock, lock serialization |
| Unmodifiable | 4 | `Modifiable` marker, CustomCell, value cell, deputy principal |
| Validation | 5 | Default allow, custom value/pulse/link/action rules |
| Context | 6 | system, module, core, secure enclave, public interface, evolve |
| Ephemeral Policy | 4 | TTL, eventLimit, combined, reset |
| Cell.valve | 8 | Gate pass/fail, payload unchanged, dynamic gate, type, disabled synapses |
| OpenCell.perform | 8 | Emit, host cell, user metadata, null drop, testRule, bound source, commands |
| toString | 2 | Cell and `ValueCell<int>(42)` |

✅ **Factory Constructors**
- `Cell()` creates a basic cell with defaults
- `Cell()` with custom receptor
- `Cell.governed` creates a governed cell
- `Cell.governed` with ephemeral policy
- `Cell.fromNucleus` creates a cell from a nucleus

✅ **Identity & Equality**
- Two distinct cells are not equal
- Cell is equal to its deputy (`cell == deputy`)
- Nested deputy `hashCode` walks to the root principal
- Cell identity preserved in sets

✅ **Apply / Modifiable / Terminal**
- `apply` executes a whitelisted function (positional, named, return value)
- `apply` with testRule blocks unauthorized actions
- `apply` awaits an async testRule (allow runs the function; deny returns null)
- `modifiable` returns the whitelist; read-only cells still expose a list
- `isTerminal` follows disabled vs enabled synapses
- `isGoverned` is true for a custom context and false for `Context.system`

✅ **Deputy / Async / Unmodifiable / Validation**
- Deputy is a no-op when nothing changes; custom testRule / context / ephemeral policy create a new instance
- Deputy of a deputy; `async.apply` with and without a lock
- Unmodifiable for CustomCell, value cell, and deputy principal; `const Modifiable()`
- `validate` allows all by default; blocks with custom value, pulse, link, and action rules

✅ **Context / Ephemeral / toString**
- system, module, core, secure enclave, public interface, custom context evolve
- TTL invalidates after duration; eventLimit after threshold; both; events can be reset
- Value cell `toString` is `ValueCell<int>(42)`, not the subclass name

✅ **Cell.valve (8 tests)**
- Creates a non-terminal cell bound to the source
- Forwards pulses that pass the gate; drops the rest; interleaved pass/fail
- Payload is unchanged (trim-empty filter)
- Dynamic open/close; gate can inspect `pulse.type`
- `Synapses.disabled` → terminal, observers see nothing

✅ **OpenCell.perform (8 tests)**
- Returns an `OpenCell` (there is no `Cell.perform` static)
- `emit` runs `perform`; observers see the transformed pulse; host cell and `user` are forwarded
- Returning `null` drops; `testRule` can reject `emit`
- Bound source emissions also run `perform`
- Command-handler credit/debit against a state cell (100 → 125 → 115)

---

### File 2: test_pulse.dart (149 tests)

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| Construction | 10 | Payload, type, priority, source, step, `Pulse.governed` |
| withStep vs evolve distinction | 11 | When `EvolvedPulse` is created vs lineage-only |
| Evolution | 14 | Trace steps, lineage history, required parameters |
| Composition | 5 | `+` and `Pulse.batch` |
| Shell | 3 | Hide payload, scrutinize receptor, governed shell |
| Unmodifiable | 15 | Payload lock, parent chain, observations still allowed |
| Comparison | 6 | `compareTo` (timestamp, priority, trace), equality, hashCode |
| Iterable | 6 | Single, withStep, evolve, collective payload |
| Governance | 9 | `isGoverned` / `isInvalidated` inheritance |
| Provenance | 12 | PulseContext fields (actor, reason, purpose, …) |
| Policy | 3 | Hops, hop limit, TTL |
| Context Factories | 12 | All `PulseContext.*` factories |
| PulseExtension | 14 | `map` / `cast` via `PulseExtension(pulse)` (`evolve(pulse:)`), `attach`, `tap`; Iterable `map`/`cast` are not the extension |
| PulseIterableExtension | 5 | batch, flatten, withStep, attach, mapEach (results are EvolvedPulse) |
| Causal Chain Distinction | 7 | withStep vs evolve(pulse) parent/root/trace |

✅ **Construction & governed**
- Simple pulse; type; priority; source; step
- Governed with context, policy, context+callbacks
- `Pulse.governed` without context/policy, or with only callbacks, is not governed

✅ **withStep vs evolve**
- `withStep` and `evolve(step)` / `evolve(context)` do not create `EvolvedPulse`
- `evolve(pulse)` creates `EvolvedPulse` (causal branch) and a parent-child relationship
- `withStep` lengthens lineage without branching; preserves identity, context, payload

✅ **Evolution / Composition / Shell**
- Trace chaining; lineage tracks payload/type/priority/source only with `evolve(pulse)`
- `evolve` requires at least one parameter
- `+` and `Pulse.batch` (including governed pulses and callback)
- Shell hides payload, scrutinizes receptor, works on governed pulses

✅ **Unmodifiable / Comparison / Iterable**
- Unmodifiable locks this instance’s payload; `withStep` / `evolve(step)` create new modifiable instances
- Recursive protection for parent chain, root, source, nested iterables
- `compareTo` by timestamp waits until the clock advances, then asserts older < newer, reverse, and identity 0 (payload is ignored)
- `compareTo` by priority and trace depth; equality is not value-based; hashCode is stable

✅ **Governance / Policy / Context / Extensions**
- `isGoverned` follows context or policy; inherited via evolve
- Hop tracking and hop-limit invalidation; TTL invalidation
- All listed `PulseContext` factories (userAction through infrastructureChange)
- `PulseExtension.map` / `cast` via `PulseExtension(pulse)` because `Pulse` is an `Iterable` (instance `map`/`cast` are Iterable's). Result is `EvolvedPulse` from `evolve(pulse:)`; mixed-type `root` throws; use `EvolvedPulse.parent`
- `attach` / `tap`; iterable `batch` / `flatten` / `mapEach`
- Causal chain: `withStep` is documentation; `evolve(pulse)` is branching

---

### File 3: test_nucleus.dart (39 tests)

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| empty / Nucleolus | 4 | Singleton, defaults, activation-resistant, timestamp |
| Construction & defaults | 12 | Context, lock, synapses, receptor, testRule, bind, user, `isGoverned` |
| Nucleus.create | 2 | Defaults vs inherit from principal |
| Activation | 5 | cell getter, activate identity, `fromNucleus`, clone-on-second-hydrate, bind link |
| evolve | 8 | Inherit/override pillars; bind is not inherited |
| clone | 2 | Distinct unactivated blueprint; independent hydration |
| Equality | 3 | Distinct roots, identity, shared-root evolved nuclei |
| inheritable | 1 | Resolved pillars |
| Cell hydration | 2 | testRule on hydrated cell; disabled synapses → terminal |

✅ Nucleolus is a reusable singleton and cannot be activated  
✅ Default Nucleus uses system context and `allowAll`; allocates a lock unless `forceLock: false`  
✅ Default synapses are an enabled registry, not the flyweight; `Synapses.disabled` is terminal egress  
✅ `isGoverned` follows the receptor, not a custom context  
✅ `Cell.fromNucleus` binds and activates; a second hydration of an activated nucleus uses a clone  
✅ Evolve inherits context/receptor/testRule/user/lock; **bind is not inherited**  
✅ Evolved nuclei that share a root principal compare equal  

---

### File 4: test_receptor.dart (50 tests)

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| passThrough | 11 | Singleton, forward without activation, cannot activate, clone, async/cell unsupported, `passThroughRule`, hashCode, `==` vs ReceptorBase |
| Construction | 8 | Closure, instruction, typed, empty pipeline, `Receptor.instruction` user factory |
| Activation & clone | 5 | Template until bound; `Cell(receptor:)` activates in place |
| Pipeline | 7 | pre/instruction/post order, throwing stage, short-circuit, omitted stages, pre+post without core |
| Instruction composition | 5 | `+`, `chain`, nest, exception → null |
| Instruction.future | 1 | Null immediately, resume via callback |
| Receptor.async | 3 | Hook sees result and drop; `serializedCompletion: false` |
| Graph integration | 3 | `Cell(bind:)`, testRule drop, null suppresses observers |
| call contract extras | 4 | Async `TestCell` Future; PulseShell scrutinize (sync + async); governed pulse records DeputyContext role |
| Receptor.pipeline mask | 3 | reaction / `isGoverned` / `init` / `user` flyweight combinations; reaction transform; governed EphemeralPolicy |

✅ `Receptor.passThrough` is a singleton that cannot be activated  
✅ `Receptor.passThroughRule` is an identity instruction; `+` yields the other side  
✅ Template is not activated until bound; unactivated `call` asserts  
✅ `Cell` construction activates an unbound template in place  
✅ Pipeline: preProcess → instruction → postProcess; null short-circuits; pre+post without a core instruction  
✅ `Receptor.async` hook captures transformed result and sees null on drop; `serializedCompletion: false` still drains via the hook  
✅ Async `TestCell` `Future<bool>` is awaited; a governed pulse on a deputy host records `DeputyContext.role` in `trace`  
✅ `Pulse.shell` is scrutinized on sync and async `call` instead of running the pipeline  
✅ `Receptor.pipeline` stores reaction / `isGoverned` / `init` / `user` flyweight combinations; a governed receptor ticks a hosted `EphemeralPolicy`  

---

### File 5: test_instruction.dart (23 tests)

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| Construction | 6 | Transform, drop, user, host, exception → null, same instance |
| Composition | 9 | `+`, `chain`, short-circuit, nest, custom strategy, throwing strategy, future continuation |
| Instruction.future | 6 | Suspend/resume, user metadata, sync return, null callback drop, chain resume, Function token |
| Custom Instruction | 1 | Throwing public `Instruction` in a chain returns null |
| Receptor integration | 1 | `Receptor.instruction` runs the instruction |

✅ Transform payload; returning null drops; exception terminates with null  
✅ `+` runs left then right; `Instruction.chain` matches `+`; null short-circuits later stages  
✅ Custom strategy replaces sequential execution and receives chain user metadata  
✅ `Instruction.future` returns null immediately and resumes via `future(result:, token:)`  

---

### File 6: test_synapses.dart (82 tests)

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| disabled | 6 | Singleton, no-op call, link false, empty iterable, async unsupported, terminal cell |
| enabled | 5 | Flyweight, link false, empty iterable, async unsupported, non-terminal cell |
| Construction & broadcast | 6 | Empty complete, onComplete empty, initial downstreams, order, successive pulses, cycle checker |
| link / unlink | 7 | Host identity required; duplicate false; testRule deny; async `Future<bool>` |
| FilterRule | 12 | Transform, drop, `+`/chain, base, throw keeps original, user, parent, chain parent/strategy, `fromRecord`, equality |
| relay | 2 | Replaces sequential broadcast; skipped when the checker already contains every downstream |
| PropagationPolicy | 4 | Immediate, async, persistent replay, persistent with an existing observer |
| async view | 27 | `async.call`, empty, filter, zero and non-zero debounce/throttle/audit/buffered, exhaust/resilient/retry/debounceLeading/sample, relay, persistent, cycle |
| remaining strategies | 9 | Sync exhaust, resilient, retry, debounceLeading, buffered zero, throwing relay, sample, debounce-after-unlink |
| mask / equality | 2 | Filter+policy+relay; distinct instances |
| Graph integration | 2 | Bound source emission; filter redacts before observers |

✅ `Synapses.disabled` / `Synapses.enabled` flyweights do not accept `link`  
✅ `link` succeeds only when `identical(host.synapses, this)`  
✅ Duplicate `link` returns false; unlink of a missing observer returns false  
✅ FilterRule transform/drop/`+`/chain/parent/`fromRecord`; throwing filter leaves the original pulse; `==` follows the flyweight record  
✅ Persistent policy replays the last pulse to a newly linked observer (including when initially empty)  
✅ `synapses.async` shares the source filter, policy, buffer, and relay  
✅ Exhaust / resilient / retry / debounceLeading are covered on both sync `call` and `async.call`  
✅ Throwing `relay` is swallowed by resilient and retried then given up by retry  
✅ `link` awaits an async `TestCell`; a governed `onComplete` pulse completes on empty synapses  
✅ `PropagationStrategy.sample` starts a `throttleTime` heartbeat of the first pulse; the cycle checker drops later ticks of that same pulse; unlinking the last observer cancels the timer  

---

### File 7: test_propagation_policy.dart (41 tests)

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| Construction & Defaults | 6 | Strategy, debounceTime, throttleTime, batchSize, all parameters |
| Strategy: immediate | 2 | Synchronous ordered delivery |
| Strategy: debounced | 3 | Silence delay, reset, `Duration.zero` |
| Strategy: throttled | 3 | Leading edge, suppress window, `Duration.zero` |
| Strategy: batched | 3 | Accumulate, `batchSize: 1` still composite, large size |
| Strategy: buffered | 2 | Flush on timer and on size |
| Strategy: audit | 2 | Latest at intervals; zero throttleTime |
| Strategy: debounceLeading | 1 | First pulse immediately |
| Strategy: sample | 1 | Heartbeat of the first pulse; unlink cancels `Timer.periodic` |
| Strategy: exhaust | 1 | Delivers to downstreams |
| Strategy: resilient | 1 | Delivers when the observer accepts |
| Strategy: retry | 1 | Delivers when the observer accepts |
| Policy Composition & Equality | 5 | `==` / inequality on each field |
| Edge Cases | 4 | Zero duration, batchSize 0, all strategies instantiate, defaults |
| Integration with Synapses | 4 | Policy on synapses, multiple policies, filter preserve/drop |
| toString | 2 | Default and immediate |

✅ Default constructor uses immediate strategy  
✅ `Duration.zero` means no delay / no lockout for debounce and throttle  
✅ Batched `batchSize: 1` is still a composite (not a no-op identity)  
✅ Policy value equality and `hashCode`  
✅ `sample` does not deliver on the calling turn; later arrivals do not replace the sampled pulse; unlink stops the heartbeat  
✅ `persistent` is smoked in `test_synapses.dart`

---

### File 8: test_test_cell.dart (41 tests)

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| allowAll | 4 | TestPasses singleton; allows values/links/pulses/actions; `+` custom |
| readOnly | 7 | Singleton; values/pulses pass; `apply` blocked; Function `call`; `+` custom; TestPasses; non-modifiable action with arguments |
| Construction | 4 | Matching values, Pulse payload, user metadata, parent after pass |
| Composition | 3 | `+`, `chain`, nest |
| Exceptions | 2 | Throwing rule passes if ungoverned or no host |
| Async | 1 | `Future<bool>` awaited |
| TestPulseRule | 3 | Predicate, non-pulse objects, chained consult |
| TestLinkRule | 2 | Predicate, chained consult |
| TestActionRule | 2 | Predicate, positional args via `call` |
| Graph integration | 3 | `cell.validate`, odd-payload drop, denied link |
| TestRule | 6 | Async parent, async chain continue/short-circuit, Exception rethrow, equality/`hashCode`, `fromRecord` |

✅ `TestCell.allowAll` is `TestPasses()`; `TestCell.readOnly` is a distinct singleton and blocks `apply` on the modifiable whitelist  
✅ `TestCell.call` is the framework gate for pulses/values; specialized `pulse`/`link`/`action` need those rule types in a chain  
✅ A throwing rule passes when the host is ungoverned  
✅ Standalone `TestRule` awaits an async parent/chain, rethrows `Exception` from a child, and follows record equality / `fromRecord`  

---

### File 9: test_synthesis_cell.dart (37 tests)

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| Construction | 6 | Sources, context, testRule, disabled synapses, forceLock, empty sources |
| Aggregation | 6 | Combine values, emitting pulse, all sources, null suppress, complex types, no initial aggregate |
| Source Management | 9 | Iterable, add/remove/clear, `isEmpty()`, `toList` |
| Stop/Start | 2 | Stop prevents aggregation; membership kept |
| Edge Cases & Error Handling | 5 | Null values, non-ValueCell, aggregator throw, missing remove, duplicate add |
| Context & Governance | 3 | Context not inherited from sources; custom override; validation |
| Real-World Scenarios | 4 | Form validation, price, full name, counter sum |
| toString | 2 | Representation includes sources |

✅ Aggregator must return a `Pulse` (or null to drop)  
✅ No initial aggregate on construction  
✅ Handle `isEmpty` is `bool Function()` (`isEmpty()`), not a getter  
✅ Empty sources do not throw  
✅ Synthesis context is the synthesis cell’s, not inherited from sources  

---

### File 10: test_transaction.dart (54 tests)

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| Basic Transaction | 8 | Commit, rollback, re-begin, outsider read/write, single cell, empty list |
| Isolation Levels | 6 | readCommitted, repeatableRead, serializable |
| Lock Ordering | 4 | byHashCode, insertion, explicit comparator, explicit without comparator throws |
| Validation | 4 | Invalid value, custom validate, multiple cells, testRule at commit |
| Custom Apply | 3 | Override default, side effects, multiple cells |
| Savepoint | 4 | Capture, multiple, unknown name throws, after rollback |
| Timeout | 3 | Times out, rollback, timeout event |
| Events | 5 | Begun, Updated, Committed, RolledBack, RolledBack with savepoint |
| Cell Types | 4 | ValueCell, CellBase, pending reads, pending fallback |
| Real-World Scenarios | 4 | Bank transfer, savepoint multi-step, concurrent isolation |
| Edge Cases & Error Handling | 6 | Last write wins, rollback no-op, commit throws, options, null/non-int |
| Exception toString | 3 | Validation, conflict, timeout |

✅ Empty participant list throws  
✅ `LockOrdering.explicit` without a comparator throws `ArgumentError`  
✅ Isolation: readCommitted sees live values; repeatableRead snapshots; serializable tracks read set  
✅ Bank-transfer-style commit/rollback with non-negative validation  

---

### File 11: test_tx_apply.dart (39 tests)

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| Basic Operations | 5 | Single/multiple apply, participants, options, apply without tx |
| Compensation | 5 | Later failure, custom cell, retries, rollback skip, `compensateIfNotExecuted` |
| Error Handling | 5 | Participant missing, non-modifiable enqueue, compensation policies |
| Stop On First Failure | 2 | true stops; false continues |
| Savepoint | 3 | Capture, rollback to savepoint, rollback all |
| Real-World Scenarios | 4 | Bank transfer, oversized rollback, migration, inventory |
| Events | 5 | Begun, Staged, Committed, RolledBack, Rejected |
| Edge Cases & Error Handling | 6 | Empty participants, commit without begin, null compensation, named args, re-begin |
| Custom Comparator | 1 | Custom lock comparator |
| Exception toString | 3 | TxApplyException, compensation exception, CompensationFailure |

✅ Enqueue only functions on `cell.modifiable` (default `{apply}`); tear-offs on `AccountCell` / `LedgerCell`  
✅ Compensation on commit failure; `compensateIfNotExecuted` on rollback of staged calls  
✅ Empty participants throw; enqueue of a non-modifiable function is rejected  

---

### File 12: test_operators_phase1_foundation.dart (64 tests)

#### Test Breakdown by Operator

| Operator | Tests | Sub-categories |
|----------|------:|----------------|
| **Cell.state** | 26 | Basic State (18), Evolve (5), Ingest (2), Edge Cases (1) |
| **Cell.ingress** | 15 | Basic Ingress (6), Governance (3), Source Binding (1), Ingest (2), Edge Cases (3) |
| **Cell.observe** | 11 | Lifecycle, start/stop, payload variants |
| **Cell.derive** | 12 | Basic (4), Filtering (2), Edge Cases (3), Combined (3) |

✅ **Basic State (18 tests)**
- Creates state cell with initial value / null / no initial
- Update changes state; update multiple times
- `updateAsync` and concurrent updates
- `cell.async.state` through the lock; unlocked `ValueNucleus.from` + `updateAsync`
- `ValueNucleus.from` with instruction; `ValueNucleus.evolve` (principal, instruction, passThrough, custom receptor, override)
- `ValueCell.terminal` holds state without broadcasting; `ValueCell.receptor` persists; nested `unmodifiable`

✅ **State with evolve (5 tests)**
- Evolve modifies incoming pulses; filters by returning null
- Type conversion; complex objects (append incoming `List<int>`); validation

✅ **Ingest / Edge (3 tests)**
- Ingest with pulse; serialized completion (await completes after processing)
- State cell with null update

✅ **Basic Ingress (6 tests)**
- Creates ingress; emit; refine transform/filter; `emitAsync`; concurrent emissions
- Observers receive emitted / refined payloads

✅ **Governance / Binding / Ingest / Edge (9 tests)**
- Custom context, testRule (Pulse payload unwrapped), forceLock
- Source bind
- Ingest pulse / serialized completion
- Null payload, empty string after refine, disabled synapses

✅ **Cell.observe (11 tests)**
- Creates; receives when started; stop/restart; `initiallyStarted: false`
- Multiple pulses; String; complex objects; governed pulse (`ingest` with `PulseContext.actor`); null payload
- Stop and start are idempotent

✅ **Cell.derive (12 tests)**
- Creates; transforms; type conversion; chained transformations
- Filter even numbers; complex string-length condition
- Null source; project that throws; rapid source changes
- Combined: state+derive+observe, ingress+derive+observe, state+derive+state

---

### File 13: test_operators_phase2_flow_control.dart (43 tests)

#### Test Breakdown by Operator

| Operator / group | Tests | Description |
|------------------|------:|-------------|
| **Cell.debounce** | 8 | Default leading false, silence delay, reset, leading, zero duration, `ephemeralPolicy` cancel, leading+zero, burst |
| **Cell.throttle** | 7 | Defaults, leading, suppress window, trailing, leading false, zero duration, both false |
| **Cell.distinct** | 6 | Default equality, consecutive dups, non-consecutive, custom equals, objects, null |
| **Cell.synthesis** | 8 | Sources, aggregate, triggering pulse, null suppress, types, empty, single source |
| Combined Operators | 5 | debounce/throttle then distinct; synthesis+observe; form validation |
| Edge Cases | 5 | Negative duration throws; custom equals null; non-ValueCell; aggregator throw |
| toString | 4 | debounce, throttle, distinct, synthesis |

✅ Debounce/throttle/distinct drop pulses unless `pulse.source` is the bound cell — tests drive via `Cell.ingress`  
✅ Debounce then distinct works (debounce rewrites source); distinct then debounce does not (not asserted as a pass of the reverse)  
✅ Empty synthesis does not throw; negative duration throws  
✅ Throttle `leading: false, trailing: false` emits nothing  
✅ Throttle trailing uses a 100 ms window so the muted interval is wider than the inner delays  

---

### File 14: test_operators_phase3_async_routing.dart (60 tests)

#### Test Breakdown by Operator

| Operator / group | Tests | Description |
|------------------|------:|-------------|
| **Cell.asyncMap** | 7 | State/ingress, concurrency 1, latestOnly, exhaust, observe, error → no emission |
| **Cell.hub** | 11 | Type, prefix, glob, multicast, fallback, priority, async emit, ingest, governed spokes, state |
| **Cell.switchMap** | 4 | Switch, observe, multiple changes, null payload does not switch |
| **Cell.fromFuture** | 8 | Result, observe, state, derive, delayed, error, complex type, null |
| **Cell.fromStream** | 12 | Values, observe, state, delayed, periodic, cancelOnError, distinct, derive, types, null, empty, cancel on invalidate |
| Combined Operators | 7 | ingress/asyncMap/observe/state; fromFuture/fromStream pipelines; hub routing |
| Edge Cases | 6 | Empty asyncMap source, hub no spokes, completed future, stream error without cancel, multicast+priority, switchMap multi |
| toString | 5 | asyncMap, hub, switchMap, fromFuture, fromStream |

✅ Hub observe on the root does not see routed spoke pulses; tests assert spoke/state effects  
✅ Duplicate spoke keys overwrite; multicast still key-matches unless custom `match`  
✅ `fromStream` continues after error when `cancelOnError: false`  

---

### File 15: test_operators_phase4_advanced_transactions.dart (39 tests)

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| **Cell.sanitized** | 7 | Redact, non-sensitive pass-through, threshold, ingress/state/observe, objects, multi-level |
| **Cell.open** | 15 | Create, emit, ingest, link/unlink, observe, testRule, state, forceLock, ephemeral, governed, `async` emit/ingest, modifiable, async testRule emit/link |
| Combined Operators | 6 | ingress/state/open + sanitized/observe; transaction; txApply compensation |
| Edge Cases | 6 | Missing sensitivity, disabled synapses, empty tx/txApply, unknown savepoint, null redact |
| toString | 5 | sanitized, open, transaction/txApply exception strings |

✅ `Cell.sanitized` redacts only when `PulseContext.sensitivity != null` and `index >= minSensitivity`  
✅ Email redact in the library is `.(?=@)` (`alic*@example.com`), not a full local-part mask  
✅ Empty transaction / txApply participants throw  
⚠️ OpenCell `EphemeralPolicy.eventLimit` / `onEvent` are not fully exercised on `emit` (the suite asserts emit still works)

`Cell.valve` and `OpenCell.perform` are covered in `test_cell.dart`, not in this phase-4 file.

---

### File 16: test_context.dart (117 tests)

Standalone suite for the authority / provenance stack. `test_cell.dart` still smokes a few Context factories on a cell; `test_pulse.dart` still smokes PulseContext fields and factories on a pulse. This file is the contract for `Context`, `DeputyContext`, and `PulseContext` themselves.

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| GovernanceEntry | 4 | `.entry()`, constructor, `toEntry()`, collection/enum values |
| Ontology | 5 | Static vs fluid `evolvable`, `isType`, `compose`, `evolve` |
| Context.system / describe | 4 | Empty singleton; `describe` getters unset; both can `evolve` |
| Constructor / fromEntries | 6 | All named ontology fields; parent inherit; local shadow |
| Named factories | 11 | `core`, `module`, `secureEnclave`, `publicInterface`, `shieldedCortex`, `receptor`, `integrityGate`, `homeostasis`, `sandbox`, `auditLog`, `transientTask` |
| Context.deputy / Context.pulse | 2 | Redirecting factories return `DeputyContext` / `PulseContext` |
| evolve / lineage / equality | 11 | Fluid refine; static pillars ignored; parent-chain lineage; record identity |
| Mandate | 3 | `role` static; other dimensions fluid; `compose` / `evolve` |
| DeputyContext system / constructor | 5 | Safe defaults; authority + ontology from base; clearance default |
| DeputyContext named factories | 12 | observer, delegate, sandbox (+ default role), intervention, janitor, architect, auditor, ambassador, shielded, gatekeeper, homeostasis |
| fromEntries / evolve / equality | 5 | Mixed Ontology+Mandate entries; role immutable; mandate inherit |
| Clearance / Isolation / Sovereignty / AuditLevel | 6 | Rank, `authorizes`, `isVirtual` / `isGuarded`, approval / preemptive, deep reasoning / silent |
| Provenance | 5 | Static vs fluid, `isType`, `compose`, `evolve` |
| PulseContext system / constructor | 9 | Empty fallback; all provenance fields; auto `traceId`; `others`; parent inherit |
| PulseContext named factories | 17 | userAction (2), aiInference, inference, regulated (2), homeostasis, systemInternal, complianceAudit, selfCorrection, infrastructureChange, securityIntervention, telemetry, collaboration, hypothesis, instruction, parentTraceId link |
| evolve / lineage / equality | 7 | Fluid refine; static actor/traceId preserved; `[]` walks parent |
| Identity / ReasoningStrategy / Sensitivity / PriorityTier | 5 | UUID shape; strategy flags; masking / high-risk; `fromValue` |

✅ **Context**
- `Context.system` is a reusable empty singleton; `evolve` does not mutate it
- `Context.describe` returns a Context whose ontology getters are unset (no NLP hydration)
- Primary constructor stores type, identity, domains, dataSources, **taxonomy, topology, version**, subDomains, stakeholders, constraints, isNot, compliance, partOf
- `fromEntries` inherits unset dimensions from `parent`; local values shadow
- Named factories set the documented taxonomy / domains / subDomains / isNot / compliance pillars
- `evolve` refines fluid boundaries (`type`, `identity`, `subDomains`, `constraints`, `compliance`) and ignores static pillars (`taxonomy`, `domains`, `version`)
- `lineage` walks root → leaf; independently constructed contexts are distinct records (map identity)

✅ **DeputyContext**
- `DeputyContext.system` defaults: `Clearance.standard`, `Isolation.scoped`, `Sovereignty.sovereign`, `AuditLevel.standard`
- Constructor required `authority`; ontology is inherited from a `Context.module` (or other ContextBase) parent
- All 11 named factories plus sandbox default role
- `evolve` can tighten clearance / authority / justification / auditLevel; **role is not evolvable**
- Mandate inherit from a parent deputy when a child omits the field

✅ **PulseContext**
- Auto-generated `traceId` is unique; constructor does not auto-link `parentTraceId` from a generic `Context`
- `others` is stored with or without a parent
- Ontology inherit from a ContextBase parent; provenance inherit from a PulseContext parent
- All listed factories, including `inference`, `complianceAudit`, and `parentTraceId` linking when `baseContext` is a PulseContext
- `evolve` changes reason/priority; actor, traceId, compliance, sensitivity stay put

---

### File 17: test_cell_policy.dart (38 tests)

Standalone suite for [`EphemeralPolicy`](lib/src/internal/cell_policy.dart) (cell TTL / event quota). Pulse hop/TTL policy remains in `test_pulse.dart`. Tests drive the public `policy(object, cell:)` entry point.

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| Construction | 6 | duration, eventLimit, both, tracking-only, user metadata |
| call / events | 7 | object/cell/arguments forwarding, counter, negative ignore, reset-to-zero, no-op after reclaim |
| eventLimit | 6 | below threshold, at limit, limit 1, reset avoids quota, failed onInvalidate retry, no limit |
| TTL | 5 | lazy start, fire after duration, no restart, dispose cancels, already-reclaimed no-op |
| Combined | 2 | quota before TTL; TTL before quota |
| mask | 8 | All flyweight bit combinations (0–7) |
| Cell integration | 4 | unused hosted policy stays live; Cell/Nucleus follow reclaim; deputy follows principal; independent counters |

✅ `onEvent` receives object, host cell, `user`, and `arguments`  
✅ Negative `events` are ignored; `events: 0` stores zero and does not reclaim unless `eventLimit` is 0  
✅ Reclamation runs `onInvalidate(nucleus)` and sets `policy.isInvalidated` only when it returns `true`  
✅ TTL timer starts on the first `call`, not at construction; later calls do not restart it  
✅ `dispose` cancels a pending TTL  

✅ `Cell.isInvalidated` / `Nucleus.isInvalidated` follow a hosted `EphemeralPolicy` (stored on the nucleus inheritable record). A deputy without its own policy follows the principal.

---

### File 18: test_test_rule_meta.dart (48 tests)

Standalone suite for annotation [TestRule]s in `lib/src/test_rule_meta.dart` (`DefaultValue`, `MaxLength`, `ValueRange`, `EntryPattern`, `Values`, `EmailPattern`, `WebsiteUrlPattern`).

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| DefaultValue | 3 | Primitive/collection constants; not a TestRule |
| MaxLength direct | 5 | String/iterable limit; non-string/iterable pass |
| MaxLength hostLength | 3 | Host iterable quota; non-iterable host still checks object |
| MaxLength composite | 4 | Field **and** container both enforced |
| MaxLength.host | 4 | Object unlimited; host quota; missing host passes |
| ValueRange | 6 | Inclusive int/double bounds; non-numeric pass; inverted min/max |
| EntryPattern | 7 | Match, case flags, null/empty, non-string pass |
| Values | 4 | Whitelist, null membership, numeric `==` |
| EmailPattern | 5 | Defaults, typical addresses, reject malformed, custom pattern |
| WebsiteUrlPattern | 5 | Defaults, typical URLs, reject empty, custom pattern |
| Composition | 2 | Types are TestRule; `MaxLength + ValueRange` short-circuits |

✅ `MaxLength(n, hostLength: h)` checks the object **and** the host (else-if host-only path was a bug; both checks now run)  
✅ `MaxLength.host` ignores the annotated object’s length  
✅ `ValueRange` / `EntryPattern` pass non-applicable types; `Values` does not  
✅ `EmailPattern` / `WebsiteUrlPattern` default `allowNull: true`, `allowEmpty: false`, case-insensitive  

---

### File 19: test_commons.dart (43 tests)

Standalone suite for `lib/src/internal/commons.dart` (public via `package:cell/cell.dart`): `mapMerge`, synchronized collections, boxes, and `get`.

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| mapMerge | 6 | Copy, concatenate iterables, wrap scalars, no mutation of inputs |
| SyncSet | 7 | add/contains/lookup, bulk set algebra, where/map/reduce, clear |
| QueueList | 3 | FIFO constructors, removeWhere/retainWhere, `cast` / `async` |
| AsyncQueueList | 3 | Locked mutations, toListAndClear / clearAndAdd, iterator |
| PriorityQueue | 6 | Comparator and Comparable, addFirst/addLast, rebuild, empty extract |
| AsyncPriorityQueue | 2 | Ranked extract, map/toList/toSet/reduce/replicate |
| SyncQueue | 4 | Custom comparison, `of`, capacity overflow, addFirst/addLast |
| Box / SyncBox / FinalBox | 4 | Mutable box, locked SyncBox, write-once FinalBox |
| TypeObject / get | 7 | TypeObject, FunctionTypeObject, FunctionObject, get fallbacks |
| Markers | 1 | `async` / `unmodifiable` type checks |

✅ `SyncSet` / `SyncQueue` / `AsyncPriorityQueue` mutation methods return the lock `Future` so `await` observes the change  
✅ `SyncQueue.addFirst` / `addLast` alias `add` (they must not fire-and-forget the inner Future)  
✅ `FinalBox` is write-once; a second assignment throws  

---

### File 20: test_deputy.dart (21 tests)

Standalone suite for `Cell.deputy` / `OpenCell.deputy` forwarding, identity, additive `testRule`, and the nested-deputy causal-integrity assert. Mandate profile remains in `test_context.dart`.

#### Test Breakdown by Category

| Category | Tests | Description |
|----------|------:|-------------|
| Cell.deputy | 5 | No-op returns `this`; testRule / context / ephemeral / synapses create a proxy |
| Identity | 3 | Equal to principal, nested deputy, unrelated cells |
| testRule layering | 2 | Additive short-circuit; readOnly still forwards `apply` to the principal |
| apply forwarding | 1 | `deputy.apply` executes on the bound principal |
| unmodifiable | 2 | Deputy unmodifiable is the principal view; ValueCell read-only view |
| Causal integrity | 3 | `DeputyContext.system`, evolved descendant, reject unrelated context |
| OpenCell.deputy | 5 | No-op, emit, nested defaults, `async` handle, `link` |

✅ `TestCell.readOnly` is not `==` `TestCell.allowAll`; attenuation uses `identical` against the default sentinels  
✅ Deputy `testRule` is `TestCell.chain([principal, extra])` so `host` stays `Cell?` (not `Never?`)  
✅ Nested `DeputyContext.evolve` is accepted when `_parent` is the current deputy context  

---

## Test Quality Assessment

### Strengths

✅ **Breadth**
- 20 files / 1115 tests covering Cell, Pulse (including `PulseExtension.map` / `cast`), Nucleus, Receptor, Instruction, Synapses (`FilterRule` parent/`fromRecord`, async policies, sample), TestCell / TestRule, **Context / DeputyContext / PulseContext**, **EphemeralPolicy**, **annotation TestRules**, **commons collections**, **Cell / OpenCell deputy**, **ValueNucleus / ValueCell**, synthesis, transaction, txApply, `Cell.valve`, and `OpenCell.perform`

✅ **Aligned to public contracts**
- Observe via `Cell.observe`, not `listen`
- Operators driven with `Cell.ingress` / `Cell.state` handles
- Synthesis aggregators return `Pulse`
- Receptor templates activated before `call`
- `Synapses.link` requires host identity
- `Cell.txApply` enqueues only `modifiable` tear-offs
- Ingress/derive tests assert observed payloads
- `ingest` with `serializedCompletion: true` waits until the pulse is processed

✅ **Structure**
- Hierarchical `group(` organization by type or operator
- Named tests describe the contract under assertion
- Mix of sync construction tests and async timer/transaction tests

✅ **Scenario coverage where it exists**
- Concurrent `updateAsync` / `emitAsync`
- Isolation levels and lock ordering
- Compensation and savepoints
- Form / price / bank-transfer style examples in synthesis and transactions

### Areas for Improvement

⚠️ **PropagationPolicy strategies**
- `exhaust` / `resilient` / `retry` / `sample` are in `test_propagation_policy.dart`; `persistent` is smoked in `test_synapses.dart`

⚠️ **Low line-coverage areas** (lcov 2026-09-01)
- Remaining `internal/synapses.dart` gaps are `AsyncSynapses._rehydrate` (public `link` is identity-checked against the sync instance) and `Synapses.enabled.call` (`Never`)
- Remaining `receptor.dart` InstructionChainMixin gaps are a strategy catch-without-`future` line and a Function-token resume that is identical to a chain stage (`token` is an `Instruction`, not a `Function`)
- Remaining `internal/pulse.dart` / `context.dart` gaps are combinatorial flyweight mask arms not reached from public factories

⚠️ **Integration tests**
- No cross-package tests (`cell_flow`, `cell_tissue`, …)
- No Flutter / widget tests
- HowTo examples still mention some private APIs (`_nucleus`); the unit tests do not

---

## Runtime Verification Status

### Current Environment

Dart SDK **3.11.5** (stable), Windows. Full suite and `lib/` line coverage collected 2026-09-01 after raising coverage on `operator_debounce.dart`, `internal/receptor.dart`, and `internal/test_cell.dart`.

Test files are named `test_*.dart`, not the package:test default `*_test.dart`. Therefore:

- `dart test` with **no path** finds **no tests**
- `dart test test` is a **name filter** (substring `test`), not a directory
- Pass **explicit files**: `dart test test/test_cell.dart …`

### Commands to Run Tests

From `packages/cell`:

```bash
dart pub get

# All 20 files (required — dart test with no path finds nothing)
dart test test/test_cell.dart test/test_pulse.dart test/test_nucleus.dart \
  test/test_receptor.dart test/test_instruction.dart test/test_synapses.dart \
  test/test_propagation_policy.dart test/test_test_cell.dart \
  test/test_synthesis_cell.dart test/test_transaction.dart test/test_tx_apply.dart \
  test/test_operators_phase1_foundation.dart \
  test/test_operators_phase2_flow_control.dart \
  test/test_operators_phase3_async_routing.dart \
  test/test_operators_phase4_advanced_transactions.dart \
  test/test_context.dart test/test_cell_policy.dart test/test_test_rule_meta.dart \
  test/test_commons.dart test/test_deputy.dart

# Single file
dart test test/test_cell.dart

# Coverage
dart test test/test_*.dart --coverage=coverage
# PowerShell: dart test @(Get-ChildItem test/*.dart | ForEach-Object { "test/$($_.Name)" }) --coverage=coverage
dart pub global activate coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib --packages=.dart_tool/package_config.json
```

Do **not** combine `--coverage` and `--coverage-path`. Dart 3.11 also accepts `--coverage-path=coverage/lcov.info` as an alternative that writes lcov directly.

### Measured Results (2026-09-01)

Full suite, relative `test/*.dart` paths (20 files), compact reporter, with `--coverage=coverage`:

| Result | Count |
|--------|------:|
| Passed | 1115 |
| Failed | 0 |
| Skipped | 0 |
| Declared | 1115 |
| Wall clock | ~7 s (coverage on); tests themselves ~5 s |

### Line Coverage (`lib/`)

Instrumented lines only (VM hit maps merged to lcov, `--report-on=lib`). `lib/cell.dart` is a barrel/`part` file with no executable lines, so it does not appear.

**Overall: 3397 / 3541 lines = 95.9%** across 33 files. Collected **2026-09-01**.

| File | Hit | Found | Line % |
|------|----:|------:|-------:|
| `lib/src/internal/cell.dart` | 120 | 120 | 100.0 |
| `lib/src/internal/receptor.dart` | 182 | 182 | 100.0 |
| `lib/src/value.dart` | 71 | 71 | 100.0 |
| `lib/src/test_cell.dart` | 75 | 75 | 100.0 |
| `lib/src/test_rule.dart` | 40 | 40 | 100.0 |
| `lib/src/internal/operator/operator_debounce.dart` | 35 | 35 | 100.0 |
| `lib/src/internal/test_cell.dart` | 33 | 33 | 100.0 |
| `lib/src/test_rule_meta.dart` | 29 | 29 | 100.0 |
| `lib/src/synapses.dart` | 25 | 25 | 100.0 |
| `lib/src/internal/pulse_extensions.dart` | 19 | 19 | 100.0 |
| `lib/src/internal/value.dart` | 12 | 12 | 100.0 |
| `lib/src/deputy.dart` | 10 | 10 | 100.0 |
| `lib/src/nucleus.dart` | 5 | 5 | 100.0 |
| `lib/src/pulse.dart` | 4 | 4 | 100.0 |
| `lib/src/internal/operator/operator_transaction.dart` | 172 | 173 | 99.4 |
| `lib/src/internal/deputy_context.dart` | 112 | 113 | 99.1 |
| `lib/src/internal/synapses.dart` | 455 | 460 | 98.9 |
| `lib/src/internal/operator/operator_tx_apply.dart` | 174 | 178 | 97.8 |
| `lib/src/internal/cell_policy.dart` | 41 | 42 | 97.6 |
| `lib/src/internal/operator/operator_async_map.dart` | 41 | 42 | 97.6 |
| `lib/src/internal/commons.dart` | 283 | 290 | 97.6 |
| `lib/src/internal/operator/operators.dart` | 94 | 98 | 95.9 |
| `lib/src/cell.dart` | 51 | 54 | 94.4 |
| `lib/src/internal/deputy.dart` | 17 | 18 | 94.4 |
| `lib/src/internal/nucleus.dart` | 177 | 188 | 94.1 |
| `lib/src/internal/operator/operator_hub.dart` | 94 | 100 | 94.0 |
| `lib/src/internal/pulse_policy.dart` | 30 | 32 | 93.8 |
| `lib/src/internal/context.dart` | 111 | 119 | 93.3 |
| `lib/src/internal/operator/operator_throttle.dart` | 37 | 40 | 92.5 |
| `lib/src/internal/pulse_context.dart` | 237 | 258 | 91.9 |
| `lib/src/receptor.dart` | 38 | 42 | 90.5 |
| `lib/src/internal/pulse.dart` | 424 | 469 | 90.4 |
| `lib/src/context.dart` | 149 | 165 | 90.3 |

Branch coverage was **not** collected (`--branch-coverage` was not passed). Artifacts: `coverage/test/*.vm.json` and `coverage/lcov.info` (gitignored).

---

## API Compatibility Checklist

Checked items are **exercised by at least one test**. Unchecked items are public and have no dedicated coverage in `/test`.

### Core Cell Class
- [x] `Cell()` / `Cell.governed` / `Cell.fromNucleus` (bind, receptor, context, testRule, synapses)
- [x] Value cell `value` / `toString`
- [x] `Cell.context`
- [x] `Cell.apply()`
- [x] `async.apply` (not `applyAsync`)
- [x] `isTerminal` (disabled synapses)
- [x] `deputy`
- [x] `unmodifiable`
- [x] `validate` (value, pulse, link, action)
- [x] `modifiable`
- [x] `EphemeralPolicy` TTL / eventLimit / `call` / `mask` (`test_cell_policy.dart`; OpenCell emit path is incomplete)
- [x] `Cell.valve`
- [x] `OpenCell.perform` (no `Cell.perform` static)

### Cell.state Operator
- [x] `Cell.state<V>(initial, evolve)`
- [x] `StateHandle.update()` / `updateAsync()`
- [x] `ValueCell.async.state` (locked and unlocked nucleus)
- [x] `StateHandle.ingest()`

### Cell.ingress Operator
- [x] `Cell.ingress<I>(refine, context, testRule, forceLock, source)`
- [x] `IngressHandle.emit()` / `emitAsync()`
- [x] `IngressHandle.ingest()`

### Cell.observe Operator
- [x] `Cell.observe(source:, effect:, initiallyStarted:)`
- [x] `ObserveHandle.start()` / `stop()`

### Cell.derive Operator
- [x] `Cell.derive(source:, project:)`

### Other operators
- [x] `Cell.hub` (type, prefix, glob, multicast, fallback)
- [x] `Cell.synthesis` (aggregator returns `Pulse`)
- [x] `Cell.debounce` (`leading`, `ephemeralPolicy`) / `Cell.throttle` / `Cell.distinct`
- [x] `Cell.asyncMap` / `Cell.switchMap` / `Cell.fromFuture` / `Cell.fromStream`
- [x] `Cell.sanitized` / `Cell.open`
- [x] `Cell.transaction` / `Cell.txApply`
- [x] `Cell.valve`
- [x] `OpenCell.perform`

### Supporting types
- [x] `Pulse<T>` / `Pulse.governed` / `EvolvedPulse` / shell / unmodifiable
- [x] `PulseExtension.map` / `cast` via `PulseExtension(pulse)` (`evolve(pulse:)` → `EvolvedPulse`)
- [x] `PulseContext` factories (`test_pulse.dart` and `test_context.dart`)
- [x] `Receptor` / `Receptor.passThrough` / `Receptor.async` / `Receptor.pipeline` (`reaction`, `init`, `isGoverned`, PulseShell)
- [x] `Instruction` / `Instruction.chain` / `Instruction.future`
- [x] `Nucleus` / `Nucleolus` / `ValueNucleus` / `Cell.fromNucleus`
- [x] `Synapses` / `FilterRule` (parent, `fromRecord`, equality, strategy) / `PropagationPolicy` (subset of strategies)
- [x] `TestCell` / `TestPasses` / `TestPulseRule` / `TestLinkRule` / `TestActionRule`
- [x] `DefaultValue` / `MaxLength` / `ValueRange` / `EntryPattern` / `Values` / `EmailPattern` / `WebsiteUrlPattern`
- [x] `Context` / `DeputyContext` / `PulseContext` (via `test_context.dart`; factories also smoked in `test_cell.dart` / `test_pulse.dart`)
- [x] `Ontology` / `Mandate` / `Provenance` / `GovernanceEntry`
- [x] `Clearance` / `Isolation` / `Sovereignty` / `AuditLevel` / `Sensitivity` / `ReasoningStrategy` / `PriorityTier` / `Identity`
- [x] `ValueCell` / `ValueNucleus.from` / `evolve` / `ValueCell.terminal` / `ValueCell.receptor` / nested `unmodifiable`
- [x] `TestRule` async parent/chain, Exception rethrow, equality/`hashCode`, `fromRecord`
- [x] `mapMerge` / `SyncSet` / `QueueList` / `PriorityQueue` / `SyncQueue` / `Box` / `get` (`test_commons.dart`)
- [x] `Cell.deputy` / `OpenCell.deputy` identity, additive `testRule`, apply forwarding, causal integrity (`test_deputy.dart`)

---

## Performance Estimates

The 2026-09-01 full run of all 1115 tests finished in **~7 seconds** wall clock with coverage enabled (tests themselves ~5 s; timer delays in debounce/throttle/asyncMap/sample are short). Memory was not measured. `test_context.dart` and `test_test_rule_meta.dart` are entirely synchronous.

| Test File | Tests | Notes |
|-----------|------:|-------|
| test_cell.dart | 72 | TTL sleeps; async apply allow/deny |
| test_pulse.dart | 157 | TTL / hop policy, toString, shell extras, PulseExtension.map / cast |
| test_nucleus.dart | 39 | Sync |
| test_receptor.dart | 50 | Async hook, PulseShell, pipeline mask, Future testRule |
| test_instruction.dart | 23 | Future resume / throwing custom stage |
| test_synapses.dart | 82 | Async view + remaining strategies + FilterRule parent + sample |
| test_propagation_policy.dart | 41 | Debounce/throttle/audit/exhaust/retry/sample |
| test_test_cell.dart | 41 | TestCell plus standalone TestRule async parent/chain |
| test_synthesis_cell.dart | 37 | Mostly sync observe |
| test_transaction.dart | 54 | Timeout + isolation |
| test_tx_apply.dart | 46 | Compensation / events |
| test_operators_phase1_foundation.dart | 64 | Some `updateAsync` / `emitAsync` / `async.state`; ValueNucleus / ValueCell |
| test_operators_phase2_flow_control.dart | 43 | Debounce/throttle windows; debounce `ephemeralPolicy` cancel |
| test_operators_phase3_async_routing.dart | 60 | `delay(20–80)` |
| test_operators_phase4_advanced_transactions.dart | 39 | Sanitized + open including `async` emit/ingest + tx |
| test_context.dart | 117 | Sync; Context / DeputyContext / PulseContext |
| test_cell_policy.dart | 38 | TTL sleeps; EphemeralPolicy; Cell/Nucleus follow hosted policy |
| test_test_rule_meta.dart | 48 | Sync; annotation TestRules |
| test_commons.dart | 43 | Mixed; SyncSet / queues / boxes |
| test_deputy.dart | 21 | Mostly async deputy / OpenCell |
| **Total** | **1115** | **~7 s with coverage** |

---

## Recommendations

### Immediate Actions
1. Leftover `receptor.dart` InstructionChainMixin lines are a strategy catch-without-`future` path and a Function-token resume identical to a chain stage
2. Leftover `internal/pulse.dart` / `context.dart` lines are combinatorial flyweight mask arms
3. Leftover `internal/synapses.dart` lines are `AsyncSynapses._rehydrate` and `Synapses.enabled.call` (`Never`)
4. Leftover `operator_tx_apply.dart` lines are defensive compensation / fail-fast arms

### Medium-Term
5. OpenCell `EphemeralPolicy.eventLimit` / `onEvent` are not fully exercised on `emit`

### Long-Term
6. CI job that runs the **explicit file list** (or a `dart_test.yaml` that includes `test_*.dart`), not `dart test` / `dart test test`
7. Cross-package tests when other packages depend on these contracts
8. Keep HowTo examples on public APIs so they cannot drift from this suite

---

## Conclusion

**Overall Assessment: RC test inventory with measured 95.9% lib line coverage, not a production-readiness certificate.**

The `cell` package has **1115** declared tests in **20** files. The suites exercise core types including standalone **Context / DeputyContext / PulseContext**, **EphemeralPolicy**, **annotation TestRule**, **commons**, **deputy**, **`PulseExtension.map` / `cast`**, **`FilterRule` parent/`fromRecord`**, async synapses policies, **`PropagationStrategy.sample`**, **`ValueNucleus` / `ValueCell`**, and standalone **`TestRule`**, the Core 16 operators including `Cell.valve`, `OpenCell.perform`, and both transaction APIs. They follow public contracts rather than private `_nucleus` HowTo snippets.

A full run on 2026-09-01 was **1115 passed / 0 failed / 0 skipped** (~7 s with coverage). Line coverage of `lib/` is **95.9%** (3397 / 3541). `Nucleus.isInvalidated` / `Cell.isInvalidated` follow a hosted `EphemeralPolicy`. `operator_debounce.dart`, `internal/receptor.dart`, and `internal/test_cell.dart` are 100%.

---

## Appendix: File Locations

```
packages/cell/test/
├── test_cell.dart                                      (72 tests, 38.6 KB, 1,096 lines)
├── test_pulse.dart                                     (157 tests, 70.8 KB, 1,826 lines)
├── test_nucleus.dart                                   (39 tests, 12.2 KB, 350 lines)
├── test_receptor.dart                                  (50 tests, 23.5 KB, 678 lines)
├── test_instruction.dart                               (23 tests, 12.3 KB, 350 lines)
├── test_synapses.dart                                  (82 tests, 37.4 KB, 1,146 lines)
├── test_propagation_policy.dart                        (41 tests, 27.9 KB, 746 lines)
├── test_test_cell.dart                                 (41 tests, 19.1 KB, 577 lines)
├── test_synthesis_cell.dart                            (37 tests, 21.0 KB, 623 lines)
├── test_transaction.dart                               (54 tests, 35.7 KB, 1,191 lines)
├── test_tx_apply.dart                                  (46 tests, 32.2 KB, 1,101 lines)
├── test_operators_phase1_foundation.dart               (64 tests, 36.5 KB, 1,043 lines)
├── test_operators_phase2_flow_control.dart             (43 tests, 22.3 KB, 764 lines)
├── test_operators_phase3_async_routing.dart            (60 tests, 30.2 KB, 1,040 lines)
├── test_operators_phase4_advanced_transactions.dart    (39 tests, 23.6 KB, 777 lines)
├── test_context.dart                                   (117 tests, 60.7 KB, 1,626 lines)
├── test_cell_policy.dart                               (38 tests, 20.4 KB, 596 lines)
├── test_test_rule_meta.dart                            (48 tests, 11.7 KB, 349 lines)
├── test_commons.dart                                   (43 tests, 13.6 KB, 447 lines)
├── test_deputy.dart                                    (21 tests, 8.3 KB, 253 lines)
└── ../TEST_VERIFICATION.md                             (This report)

packages/cell/coverage/                                 (gitignored)
├── test/*.vm.json                                      (20 VM hit maps, 2026-09-01)
└── lcov.info                                           (merged lib/ report)
```

**Total lines of test code:** 16,581  
**Lib Dart files:** 34 (28,096 physical lines; 33 files have instrumented lines in lcov)  
**Test-to-source ratio:** ~0.57:1 (physical lines)  
**Measured line coverage:** 95.9% of instrumented `lib/` lines (3397 / 3541, 2026-09-01)

---

*Test counts, the 2026-09-01 full run, and lcov are from the current `packages/cell/test/` tree.*
