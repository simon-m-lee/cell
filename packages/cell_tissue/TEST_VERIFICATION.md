# cell_tissue package - Test Verification Report

**Generated:** 2026-11-11
**Package:** cell_tissue (v1.0.0)
**Test Files Analyzed:** 15
**Total Tests:** 340 (0 skipped)

---

## Table of contents

- [Executive Summary](#executive-summary)
  - [Snapshot](#snapshot)
  - [Quick Stats](#quick-stats)
- [Test File Inventory](#test-file-inventory)
- [Detailed Test Coverage](#detailed-test-coverage)
  - [ai_guide_examples_test.dart](#file-1-ai_guide_examples_test.dart-3-tests)
  - [ai_preflight_test.dart](#file-2-ai_preflight_test.dart-1-tests)
  - [api_chooser_up_to_date_test.dart](#file-3-api_chooser_up_to_date_test.dart-1-tests)
  - [seam_test.dart](#file-4-seam_test.dart-2-tests)
  - [test_tissue_test.dart](#file-5-test_tissue_test.dart-15-tests)
  - [tissue_apply_command_test.dart](#file-6-tissue_apply_command_test.dart-4-tests)
  - [tissue_container_test.dart](#file-7-tissue_container_test.dart-5-tests)
  - [tissue_list_test.dart](#file-8-tissue_list_test.dart-49-tests)
  - [tissue_map_test.dart](#file-9-tissue_map_test.dart-63-tests)
  - [tissue_pulse_test.dart](#file-10-tissue_pulse_test.dart-26-tests)
  - [tissue_queue_test.dart](#file-11-tissue_queue_test.dart-40-tests)
  - [tissue_receptor_test.dart](#file-12-tissue_receptor_test.dart-17-tests)
  - [tissue_set_test.dart](#file-13-tissue_set_test.dart-51-tests)
  - [tissue_test.dart](#file-14-tissue_test.dart-35-tests)
  - [tissue_value_test.dart](#file-15-tissue_value_test.dart-28-tests)
- [Runtime Verification Status](#runtime-verification-status)
  - [Last `dart test`](#last-dart-test)
  - [Line Coverage (`lib/`)](#line-coverage-lib)
- [Recommendations](#recommendations)
- [Appendix: File Locations](#appendix-file-locations)

---

## Executive Summary

The cell_tissue test suite contains **340 unit tests** across **15 files** in `test/`. Counts are `test(` declarations.

This file is **generated**. Edit the script flags or the stub sections at the bottom; do not hand-count `test(`.

### Snapshot

Last `dart test` is **green**: **340 passed**, 0 failed (exit 0).

`lib/` line coverage is **72.8%** (2395 / 3289).

Below 70%: `lib/src/instruction/ai_tissue_command.dart`, `lib/src/instruction/ai_tissue_command_domain_io.dart`, `lib/src/instruction/ai_tissue_command_domain.dart`, `lib/src/tissue_pulse.dart`…

### Quick Stats

| Metric | Value |
|--------|-------|
| **Total Test Files** | 15 |
| **Total Tests** | 340 |
| **Skipped** | 0 |
| **Last full run** | 340 passed, 0 failed, 0 skipped (exit 0) |
| **Test Groups** | 64 (`group(` declarations) |
| **Async-ish tests** | ~96 (heuristic) |
| **Line coverage (`lib/`)** | **72.8%** (2395 / 3289) |

---

## Test File Inventory

| # | File | Lines | Tests | Size | Focus |
|---|------|------:|------:|------:|-------|
| 1 | ai_guide_examples_test.dart | 43 | 3 | 1.7 KB | ai guide examples test |
| 2 | ai_preflight_test.dart | 22 | 1 | 0.8 KB | ai preflight test |
| 3 | api_chooser_up_to_date_test.dart | 27 | 1 | 1.0 KB | api chooser up to date test |
| 4 | seam_test.dart | 52 | 2 | 1.9 KB | seam test |
| 5 | test_tissue_test.dart | 228 | 15 | 8.3 KB | test test; groups: TestTissue sentinel policies, TestTissue rule policies, TestTissue.chain pipelines, TestElementRule |
| 6 | tissue_apply_command_test.dart | 89 | 4 | 2.7 KB | apply command test; groups: Tissue Apply command model |
| 7 | tissue_container_test.dart | 50 | 5 | 1.7 KB | container test; groups: Container strategies |
| 8 | tissue_list_test.dart | 577 | 49 | 17.0 KB | list test; groups: TissueList factories, TissueList read operations, TissueList mutations, TissueListNucleus factories, TissueList.unmodifiable, TissueList.deputy… |
| 9 | tissue_map_test.dart | 773 | 63 | 24.5 KB | map test; groups: TissueMap factories, TissueMap read operations, TissueMap mutations, TissueMapNucleus factories, TissueMap.unmodifiable, TissueMap.deputy… |
| 10 | tissue_pulse_test.dart | 366 | 26 | 11.1 KB | pulse test; groups: TissuePulse.batch and CollectiveTissuePulse, TissuePulse evolution, TissuePulse shell, TissuePulse unmodifiable, TissueEvent classification, groupBy utility |
| 11 | tissue_queue_test.dart | 481 | 40 | 14.0 KB | queue test; groups: TissueQueue factories, TissueQueue read operations, TissueQueue mutations, TissueQueueNucleus factories, TissueQueue.unmodifiable, TissueQueue.deputy… |
| 12 | tissue_receptor_test.dart | 290 | 17 | 9.3 KB | receptor test; groups: TissueReceptor.passThrough, TissueReceptor factory, TissueReceptorBase.call |
| 13 | tissue_set_test.dart | 594 | 51 | 17.4 KB | set test; groups: TissueSet factories, TissueSet read operations, TissueSet mutations, TissueSetNucleus factories, TissueSet.unmodifiable, TissueSet.deputy… |
| 14 | tissue_test.dart | 464 | 35 | 14.3 KB | test; groups: Tissue primary factory, Tissue.governed, Tissue.empty, TissueNever sentinel, Tissue.fromNucleus and Tissue.create, Tissue.deputy… |
| 15 | tissue_value_test.dart | 355 | 28 | 10.2 KB | value test; groups: TissueValue factories, TissueValue reads and writes, TissueValueNucleus factories, TissueValue.unmodifiable, TissueValue.deputy, TissueValue async… |
| **Total** | | **4,411** | **340** | **135.8 KB** | |

---

## Detailed Test Coverage

Generated from `group(` / `test(` names. Tighten the prose by hand if needed.

### File 1: ai_guide_examples_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |

**Tests**

- generated AI guide example file is up to date
- every minimal example compiles under dart analyze
- every minimal example runs and exits 0

### File 2: ai_preflight_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- all doc-comment and HowTo pins match resolved versions

### File 3: api_chooser_up_to_date_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- lib/doc/api_chooser.dart is generated and up to date

### File 4: seam_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- no testRule: TestCell on any Tissue constructor in example/
- no testRule: TestTissue on a Cell factory in example/

### File 5: test_tissue_test.dart (15 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 15 |
| TestTissue sentinel policies | |
| TestTissue rule policies | |
| TestTissue.chain pipelines | |
| TestElementRule | |

**Tests**

- allowAll authorises every vector
- allowAll + other delegates to the other rule
- readOnly blocks modifiable actions but allows reads
- readOnly + other delegates to the other rule
- call routes element objects with function arguments to element()
- call falls back to super when arguments are not a Function
- single-rule policy evaluates through element()
- operator + composes policies with short-circuit order
- sync chain evaluates in order and short-circuits
- async chain resumes the remaining rules
- chain strategy overrides sequential evaluation
- evaluates elements with a function action
- bypasses the predicate for non-element objects
- element() delegates to call()
- action-aware element rule receives the mutation function

### File 6: tissue_apply_command_test.dart (4 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 4 |
| Tissue Apply command model | |

**Tests**

- execute routes through the dispatch engine and returns accepted
- execute stages into a transaction and commits atomically
- execute with compensation rolls back through the command model
- execute on an unmodifiable view returns rejected

### File 7: tissue_container_test.dart (5 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 5 |
| Container strategies | |

**Tests**

- create without elements builds an empty persistent store
- create with elements initialises the persistent store
- init delegates to the strategy create function
- add operates on a transient store
- remove operates on a transient store

### File 8: tissue_list_test.dart (49 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 49 |
| TissueList factories | |
| TissueList read operations | |
| TissueList mutations | |
| TissueListNucleus factories | |
| TissueList.unmodifiable | |
| TissueList.deputy | |
| ModifiableListAsync | |
| TissueList.apply + Cell.txApply integration | |

**Tests**

- primary factory creates an empty reactive list
- of factory populates from an iterable
- fromNucleus populates elements
- create builds a list from explicit parameters
- growable false creates a fixed-length list
- operator [] and length
- elementAt, contains and indexOf
- first, last and toList
- structural equality, hashCode and toString
- cell metadata
- operator []= and setValueAt update elements
- add and addAll append elements
- remove returns true only when present
- removeWhere and retainWhere filter elements
- clear empties the list
- fillRange overwrites a range
- insert and insertAll shift elements
- removeAt and removeLast return removed elements
- removeRange deletes a range
- replaceRange substitutes elements
- setAll and setRange overwrite positions
- sort orders elements
- shuffle keeps elements
- length setter truncates or expands
- apply gateway dispatches whitelisted functions
- apply rejects non-whitelisted functions
- operator + concatenates two lists
- adding Cell values establishes reactive links
- create returns a reusable blueprint
- clone produces an independent nucleus
- evolve produces a deputy nucleus
- unmodifiable getter returns a read-only view
- unmodifiable view rejects mutations
- standalone UnmodifiableTissueList factory
- view factory with unmodifiableElement false
- fromNucleus populates elements
- create factory
- deputy shares principal storage and equality
- nested deputies
- deputy of an unmodifiable view works
- async setValueAt updates the list
- async mutations mirror the synchronous API
- unmodifiable async facade rejects every mutation
- stages list.add through apply and commits atomically
- apply with tx returns null and does not mutate before commit
- body failure rolls back staged mutations
- compensates unexecuted stages with compensateIfNotExecuted
- rejects functions outside the modifiable whitelist at enqueue
- enqueued compensation commits when the staged apply succeeds

### File 9: tissue_map_test.dart (63 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 63 |
| TissueMap factories | |
| TissueMap read operations | |
| TissueMap mutations | |
| TissueMapNucleus factories | |
| TissueMap.unmodifiable | |
| TissueMap.deputy | |
| TissueMapBase direct subclass | |
| ModifiableMapAsync | |
| TissueMap.apply + Cell.txApply integration | |

**Tests**

- primary factory creates an empty reactive map
- from factory copies a Dart map
- fromEntries factory ingests entries
- identity factory creates an identity-keyed map
- fromNucleus populates entries
- create builds a map from explicit parameters
- operator [] and containsKey
- containsValue
- keys, values and entries
- structural equality, hashCode and toString
- cell metadata
- operator []= and add associate keys
- operator []= and put replace existing keys
- add remains strict append-only after put
- put and []= emit elementAdded on insert and entryUpdated on replace
- put validates replacements through the test rule
- put replaces Cell values and reports the swap
- put is whitelisted and routable through apply
- addAll adds entries from a map
- addEntries adds entries from an iterable
- putIfAbsent returns existing or inserts missing
- update mutates existing values
- update with ifAbsent inserts missing keys
- updateAll applies a function to every entry
- remove returns the removed value or null
- removeWhere removes matching entries
- clear empties the map
- adding Cell values establishes reactive links
- update on a missing key without ifAbsent throws StateError
- fromNucleus links initial Cell values
- add and remove can be invoked through the apply gateway
- apply rejects functions outside the modifiable whitelist
- create returns a reusable blueprint
- clone produces an independent nucleus
- evolve produces a deputy nucleus
- unmodifiable getter returns a read-only view
- unmodifiable view rejects every mutation
- standalone UnmodifiableTissueMap factory
- view factory with unmodifiableElement false
- fromNucleus populates entries
- fromNucleus with unmodifiableElement false
- create factory
- projects child cells as unmodifiable elements
- deputy shares principal storage and equality
- nested deputies
- deputy of an unmodifiable view works
- deputy put and []= replace through shared storage
- readOnly deputy still rejects mutations
- base deputy member is exercised
- async add and addAll
- async put inserts and replaces
- async addEntries and putIfAbsent
- async remove and removeWhere
- async update and updateAll
- async clear
- unmodifiable async facade rejects every mutation
- stages map.add through apply and commits atomically
- apply with tx returns null and does not mutate before commit
- put stages through apply and commits atomically
- body failure rolls back staged mutations
- compensates unexecuted stages with compensateIfNotExecuted
- rejects functions outside the modifiable whitelist at enqueue
- enqueued compensation commits when the staged apply succeeds

### File 10: tissue_pulse_test.dart (26 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 26 |
| TissuePulse.batch and CollectiveTissuePulse | |
| TissuePulse evolution | |
| TissuePulse shell | |
| TissuePulse unmodifiable | |
| TissueEvent classification | |
| groupBy utility | |

**Tests**

- batch creates a collective from events
- empty batch remains a collective
- CollectiveTissuePulse.from wraps events
- CollectiveTissuePulse.governed overrides metadata
- plus operator flattens collectives
- plus branches with collective and foreign types
- collective exposes shell, evolution, source, root and unmodifiable
- withStep creates a chain
- evolve creates an evolved event
- evolved plus builds a collective
- chained steps accumulate trace
- evolved events exercise the tissue event mixin
- shell getter returns a TissueEventShell
- shell iterator yields itself
- shell rejects addition, evolution and steps
- shell scrutinize returns the underlying event
- unmodifiable getter returns a read-only projection
- UnmodifiableTissuePulse factory
- unmodifiable derives new events without mutating
- unmodifiable plus builds a collective
- unmodifiable forwards shell and root
- list add emits elementAdded with payload
- list remove emits elementRemoved with payload
- value set emits elementUpdated record
- groups elements by key
- handles empty iterable

### File 11: tissue_queue_test.dart (40 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 40 |
| TissueQueue factories | |
| TissueQueue read operations | |
| TissueQueue mutations | |
| TissueQueueNucleus factories | |
| TissueQueue.unmodifiable | |
| TissueQueue.deputy | |
| ModifiableQueueAsync | |
| TissueQueue.apply + Cell.txApply integration | |

**Tests**

- primary factory creates an empty reactive queue
- of factory populates from an iterable
- capacity bounds the queue
- fromNucleus populates elements
- create builds a queue from explicit parameters
- first, last, length and contains
- toList preserves FIFO order
- cast converts element type
- structural equality and toString
- cell metadata
- add, addFirst and addLast insert elements
- addAll appends elements
- remove returns true only when present
- removeFirst and removeLast return removed elements
- removeWhere and retainWhere filter elements
- clear empties the queue
- apply gateway dispatches whitelisted functions
- single-element batch mutations notify
- adding Cell values establishes reactive links
- create returns a reusable blueprint
- clone produces an independent nucleus
- evolve produces a deputy nucleus
- unmodifiable getter returns a read-only view
- unmodifiable view cast preserves elements
- unmodifiable view rejects mutations
- standalone UnmodifiableTissueQueue factory
- fromNucleus populates elements
- create factory
- deputy shares principal storage and equality
- nested deputies
- deputy of an unmodifiable view works
- async add and addAll
- async remove and clear
- unmodifiable async facade rejects mutations
- stages queue.add through apply and commits atomically
- apply with tx returns null and does not mutate before commit
- body failure rolls back staged mutations
- compensates unexecuted stages with compensateIfNotExecuted
- accepts functions outside the modifiable whitelist; gate decides
- enqueued compensation commits when the staged apply succeeds

### File 12: tissue_receptor_test.dart (17 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 17 |
| TissueReceptor.passThrough | |
| TissueReceptor factory | |
| TissueReceptorBase.call | |

**Tests**

- is a const singleton with terminal behaviour
- call forwards the pulse unchanged
- primary factory wraps an instruction
- instruction factory stores user metadata
- pipeline factory wires all stages
- pipeline reaction and error boundaries
- clone produces an unactivated copy
- async getter returns a ReceptorAsync adapter
- returns null when not activated
- forwards non-tissue pulses to the pipeline
- synchronises elementAdded from another tissue
- synchronises elementRemoved from another tissue
- synchronises collective batches
- partial sync returns single applied event
- partial sync returns batch of applied events
- synchronises elementUpdated into a list of cells
- partial sync returns applied events only

### File 13: tissue_set_test.dart (51 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 51 |
| TissueSet factories | |
| TissueSet read operations | |
| TissueSet mutations | |
| TissueSetNucleus factories | |
| TissueSet.unmodifiable | |
| TissueSet.deputy | |
| ModifiableSetAsync | |
| TissueSet.apply + Cell.txApply integration | |

**Tests**

- primary factory deduplicates initial elements
- empty factory creates an empty reactive set
- of factory builds from an iterable
- from factory casts dynamic elements
- identity factory creates an identity-based set
- governed testRule is preserved and enforced
- fromNucleus populates elements
- create builds a set from explicit parameters
- create with identity container
- contains and lookup
- containsAll
- toSet returns a plain Set copy
- structural equality, hashCode and toString
- cell metadata
- add returns true for new elements and false for duplicates
- addAll adds valid elements
- remove returns true when present and false otherwise
- removeAll removes contained elements
- removeWhere removes matching elements
- retainAll keeps only contained elements
- retainWhere keeps matching elements
- clear empties the set
- mutations on empty set are safe
- add and remove can be invoked through apply gateway
- apply rejects functions outside the modifiable whitelist
- create returns a reusable blueprint
- clone produces an independent nucleus
- evolve produces a deputy nucleus
- unmodifiable getter returns a live read-only view
- unmodifiable view rejects mutations silently
- standalone UnmodifiableTissueSet factory
- standalone with unmodifiableElement false
- view factory with unmodifiableElement false
- fromNucleus populates elements
- fromNucleus with unmodifiableElement false
- create factory
- projects child cells as unmodifiable elements
- deputy shares principal storage and equality
- nested deputies
- deputy of an unmodifiable view works
- async add and addAll
- async remove and removeAll
- async retain and removeWhere
- async clear
- unmodifiable async facade rejects every mutation
- stages set.add through apply and commits atomically
- apply with tx returns null and does not mutate before commit
- body failure rolls back staged mutations
- compensates unexecuted stages with compensateIfNotExecuted
- rejects functions outside the modifiable whitelist at enqueue
- enqueued compensation commits when the staged apply succeeds

### File 14: tissue_test.dart (35 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 35 |
| Tissue primary factory | |
| Tissue.governed | |
| Tissue.empty | |
| TissueNever sentinel | |
| Tissue.fromNucleus and Tissue.create | |
| Tissue.deputy | |
| Tissue.unmodifiable (view) | |
| UnmodifiableTissue factories | |
| TissueBase members (direct subclass) | |

**Tests**

- creates a populated iterable tissue
- delegates iterable operations to the container
- exposes cell governance metadata
- unmodifiable of a mutable _Tissue returns itself
- modifiable manifest is empty and async handle is available
- structural equality, hashCode and toString
- auto-links initial elements that are cells
- creates a governed tissue with a custom validation rule
- accepts a custom receptor and synapses
- default empty returns a mutable empty _Tissue
- empty with a bind creates an empty bound tissue
- empty with disabled synapses returns the TissueNever sentinel
- reports terminal and invalidated state
- modifiable is empty and unmodifiable returns itself
- apply is a no-op returning null
- deputy returns itself
- async handle is available
- iterator yields nothing
- operator + returns the other operand
- fromNucleus populates initial elements
- create builds a tissue from explicit parameters
- create without elements builds an empty tissue
- creates a deputy sharing the principal storage
- creates nested deputies
- creates a live read-only projection sharing storage
- projects child cells as unmodifiable elements
- view with unmodifiableElement false still shares storage
- deputy of an unmodifiable view works
- standalone unmodifiable tissue holds fixed elements
- standalone unmodifiable tissue with unmodifiableElement false
- fromNucleus populates elements
- fromNucleus with unmodifiableElement false
- fromNucleus links cells when elements are identical to the bind
- base equality, hashCode, iterator and toString
- unmodifiable branch of base equality is exercised

### File 15: tissue_value_test.dart (28 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 28 |
| TissueValue factories | |
| TissueValue reads and writes | |
| TissueValueNucleus factories | |
| TissueValue.unmodifiable | |
| TissueValue.deputy | |
| TissueValue async | |
| TissueValue transaction | |

**Tests**

- primary factory creates a reactive value
- empty factory creates a null value
- fromNucleus populates value
- create builds a value from explicit parameters
- value setter and getter
- set returns false for identical value
- equality compares underlying value
- numeric comparison operators
- comparisons accept TissueValue operands
- Cell values are linked and unlinked
- cell metadata and apply
- create returns a reusable blueprint
- clone produces an independent nucleus
- evolve produces a deputy nucleus
- unmodifiable getter returns a read-only view
- unmodifiable view rejects mutations
- standalone UnmodifiableTissueValue factory
- view factory
- fromNucleus populates value
- create factory
- deputy shares principal storage and equality
- deputy of an unmodifiable view works
- nested deputies
- async set updates the value
- unmodifiable async set returns false and value is readable
- Cell.transaction commits a TissueValue like a Cell.state
- commit validation failure leaves the TissueValue unchanged
- unmodifiable TissueValue rejects transaction commits

---

## Runtime Verification Status

Working directory: `packages/cell_tissue` (package-relative; host paths omitted).

If tests are named `test_*.dart` instead of `*_test.dart`, `dart test` with
no path finds nothing. Pass explicit files:

```bash
dart pub get
dart test \
  test/ai_guide_examples_test.dart \
  test/ai_preflight_test.dart \
  test/api_chooser_up_to_date_test.dart \
  test/seam_test.dart \
  test/test_tissue_test.dart \
  test/tissue_apply_command_test.dart \
  test/tissue_container_test.dart \
  test/tissue_list_test.dart \
  test/tissue_map_test.dart \
  test/tissue_pulse_test.dart \
  test/tissue_queue_test.dart \
  test/tissue_receptor_test.dart \
  test/tissue_set_test.dart \
  test/tissue_test.dart \
  test/tissue_value_test.dart
```

### Last `dart test`

| Passed | Failed | Skipped | Exit |
|-------:|-------:|--------:|-----:|
| 340 | 0 | 0 | 0 |

Status: **green**.

<details><summary>tail of test log</summary>

```
0:02 +324: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +325: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +326: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +327: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +328: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +329: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +330: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +331: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +332: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +333: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +334: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +335: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +336: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +337: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +338: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:02 +339: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:03 +339: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:03 +340: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:04 +340: test/ai_guide_examples_test.dart: every minimal example runs and exits 0                                                                                                                   
00:04 +340: All tests passed!
```

</details>

### Line Coverage (`lib/`)

**Overall: 2395 / 3289 lines = 72.8%**

| File | Hit | Found | Line % |
|------|----:|------:|-------:|
| `lib/src/internal/tissue_container.dart` | 10 | 10 | 100.0 |
| `lib/src/test_tissue.dart` | 33 | 33 | 100.0 |
| `lib/src/tissue.dart` | 8 | 8 | 100.0 |
| `lib/src/tissue_receptor.dart` | 8 | 8 | 100.0 |
| `lib/src/internal/tissue_list.dart` | 440 | 445 | 98.9 |
| `lib/src/internal/tissue_set.dart` | 275 | 279 | 98.6 |
| `lib/src/internal/tissue_map.dart` | 428 | 442 | 96.8 |
| `lib/src/tissue_set.dart` | 22 | 23 | 95.7 |
| `lib/src/internal/tissue_queue.dart` | 313 | 328 | 95.4 |
| `lib/src/internal/tissue_pulse.dart` | 96 | 102 | 94.1 |
| `lib/src/tissue_map.dart` | 14 | 15 | 93.3 |
| `lib/src/tissue_value.dart` | 14 | 15 | 93.3 |
| `lib/src/tissue_queue.dart` | 13 | 14 | 92.9 |
| `lib/src/internal/tissue_receptor.dart` | 59 | 65 | 90.8 |
| `lib/src/tissue_list.dart` | 14 | 16 | 87.5 |
| `lib/src/tissue_nucleus.dart` | 6 | 7 | 85.7 |
| `lib/src/internal/tissue_value.dart` | 172 | 205 | 83.9 |
| `lib/src/internal/tissue.dart` | 132 | 161 | 82.0 |
| `lib/src/internal/test_tissue.dart` | 31 | 40 | 77.5 |
| `lib/src/tissue_container.dart` | 94 | 130 | 72.3 |
| `lib/src/internal/tissue_nucleus.dart` | 189 | 289 | 65.4 |
| `lib/src/tissue_pulse.dart` | 22 | 39 | 56.4 |
| `lib/src/instruction/ai_tissue_command_domain.dart` | 2 | 262 | 0.8 |
| `lib/src/instruction/ai_tissue_command.dart` | 0 | 282 | 0.0 |
| `lib/src/instruction/ai_tissue_command_domain_io.dart` | 0 | 71 | 0.0 |

---

## Recommendations

1. Keep this report generated — do not hand-count `test(`.
2. CI should run the explicit file list below (or `dart test` from the package root) so all reactive collections are exercised.
3. Each reactive collection has a public interface file plus an internal implementation file; the internal files carry most of the `apply`/`modifiable`/deputy logic.
4. Keep the `Tissue*.apply + Cell.txApply integration` groups in sync with `Cell.txApply` changes in `package:cell`.
5. Coverage targets should be tracked per public/internal pair, not just the whole `lib/` average.

---

## Appendix: File Locations

```
test/
├── ai_guide_examples_test.dart  (3 tests, 1.7 KB, 43 lines)
├── ai_preflight_test.dart  (1 tests, 0.8 KB, 22 lines)
├── api_chooser_up_to_date_test.dart  (1 tests, 1.0 KB, 27 lines)
├── seam_test.dart  (2 tests, 1.9 KB, 52 lines)
├── test_tissue_test.dart  (15 tests, 8.3 KB, 228 lines)
├── tissue_apply_command_test.dart  (4 tests, 2.7 KB, 89 lines)
├── tissue_container_test.dart  (5 tests, 1.7 KB, 50 lines)
├── tissue_list_test.dart  (49 tests, 17.0 KB, 577 lines)
├── tissue_map_test.dart  (63 tests, 24.5 KB, 773 lines)
├── tissue_pulse_test.dart  (26 tests, 11.1 KB, 366 lines)
├── tissue_queue_test.dart  (40 tests, 14.0 KB, 481 lines)
├── tissue_receptor_test.dart  (17 tests, 9.3 KB, 290 lines)
├── tissue_set_test.dart  (51 tests, 17.4 KB, 594 lines)
├── tissue_test.dart  (35 tests, 14.3 KB, 464 lines)
├── tissue_value_test.dart  (28 tests, 10.2 KB, 355 lines)
```

**Total lines of test code:** 4,411

*Generated 2026-11-11 by generate_test_verification.py*
