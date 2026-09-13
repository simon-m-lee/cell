# cell_tissue package - Test Verification Report

**Generated:** 2026-09-13
**Package:** cell_tissue (v1.0.0-rc.3)
**Test Files Analyzed:** 10
**Total Tests:** 316 (0 skipped)

---

## Table of contents

- [Executive Summary](#executive-summary)
  - [Snapshot](#snapshot)
  - [Quick Stats](#quick-stats)
- [Test File Inventory](#test-file-inventory)
- [Detailed Test Coverage](#detailed-test-coverage)
  - [test_tissue_test.dart](#file-1-test_tissue_test.dart-15-tests)
  - [tissue_container_test.dart](#file-2-tissue_container_test.dart-5-tests)
  - [tissue_list_test.dart](#file-3-tissue_list_test.dart-49-tests)
  - [tissue_map_test.dart](#file-4-tissue_map_test.dart-53-tests)
  - [tissue_pulse_test.dart](#file-5-tissue_pulse_test.dart-26-tests)
  - [tissue_queue_test.dart](#file-6-tissue_queue_test.dart-40-tests)
  - [tissue_receptor_test.dart](#file-7-tissue_receptor_test.dart-17-tests)
  - [tissue_set_test.dart](#file-8-tissue_set_test.dart-51-tests)
  - [tissue_test.dart](#file-9-tissue_test.dart-35-tests)
  - [tissue_value_test.dart](#file-10-tissue_value_test.dart-25-tests)
- [Runtime Verification Status](#runtime-verification-status)
  - [Last `dart test`](#last-dart-test)
  - [Line Coverage (`lib/`)](#line-coverage-lib)
- [Recommendations](#recommendations)
- [Appendix: File Locations](#appendix-file-locations)

---

## Executive Summary

The cell_tissue test suite contains **316 unit tests** across **10 files** in `test/`. Counts are `test(` declarations.

This file is **generated**. Edit the script flags or the stub sections at the bottom; do not hand-count `test(`.

### Snapshot

Last `dart test` is **red**: 314 passed, **2 failed** (exit 1).

`lib/` line coverage is **93.7%** (2067 / 2205).

No `lib/` file is below 70% in this lcov.

### Quick Stats

| Metric | Value |
|--------|-------|
| **Total Test Files** | 10 |
| **Total Tests** | 316 |
| **Skipped** | 0 |
| **Last full run** | 314 passed, 2 failed, 0 skipped (exit 1) |
| **Test Groups** | 62 (`group(` declarations) |
| **Async-ish tests** | ~82 (heuristic) |
| **Line coverage (`lib/`)** | **93.7%** (2067 / 2205) |

---

## Test File Inventory

| # | File | Lines | Tests | Size | Focus |
|---|------|------:|------:|------:|-------|
| 1 | test_tissue_test.dart | 226 | 15 | 8.5 KB | test test; groups: TestTissue sentinel policies, TestTissue rule policies, TestTissue.chain pipelines, TestElementRule |
| 2 | tissue_container_test.dart | 50 | 5 | 1.7 KB | container test; groups: Container strategies |
| 3 | tissue_list_test.dart | 543 | 49 | 16.4 KB | list test; groups: TissueList factories, TissueList read operations, TissueList mutations, TissueListNucleus factories, TissueList.unmodifiable, TissueList.deputy… |
| 4 | tissue_map_test.dart | 583 | 53 | 19.4 KB | map test; groups: TissueMap factories, TissueMap read operations, TissueMap mutations, TissueMapNucleus factories, TissueMap.unmodifiable, TissueMap.deputy… |
| 5 | tissue_pulse_test.dart | 335 | 26 | 10.6 KB | pulse test; groups: TissuePulse.batch and CollectiveTissuePulse, TissuePulse evolution, TissuePulse shell, TissuePulse unmodifiable, ElementAdded, ElementRemoved and ElementUpdated, groupBy utility |
| 6 | tissue_queue_test.dart | 447 | 40 | 13.7 KB | queue test; groups: TissueQueue factories, TissueQueue read operations, TissueQueue mutations, TissueQueueNucleus factories, TissueQueue.unmodifiable, TissueQueue.deputy… |
| 7 | tissue_receptor_test.dart | 265 | 17 | 8.8 KB | receptor test; groups: TissueReceptor.passThrough, TissueReceptor factory, TissueReceptorBase.call |
| 8 | tissue_set_test.dart | 557 | 51 | 17.1 KB | set test; groups: TissueSet factories, TissueSet read operations, TissueSet mutations, TissueSetNucleus factories, TissueSet.unmodifiable, TissueSet.deputy… |
| 9 | tissue_test.dart | 413 | 35 | 12.9 KB | test; groups: Tissue primary factory, Tissue.governed, Tissue.empty, TissueNever sentinel, Tissue.fromNucleus and Tissue.create, Tissue.deputy… |
| 10 | tissue_value_test.dart | 260 | 25 | 8.0 KB | value test; groups: TissueValue factories, TissueValue reads and writes, TissueValueNucleus factories, TissueValue.unmodifiable, TissueValue.deputy, TissueValue async |
| **Total** | | **3,679** | **316** | **117.0 KB** | |

---

## Detailed Test Coverage

Generated from `group(` / `test(` names. Tighten the prose by hand if needed.

### File 1: test_tissue_test.dart (15 tests)

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

### File 2: tissue_container_test.dart (5 tests)

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

### File 3: tissue_list_test.dart (49 tests)

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

### File 4: tissue_map_test.dart (53 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 53 |
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
- base deputy member is exercised
- async add and addAll
- async addEntries and putIfAbsent
- async remove and removeWhere
- async update and updateAll
- async clear
- unmodifiable async facade rejects every mutation
- stages map.add through apply and commits atomically
- apply with tx returns null and does not mutate before commit
- body failure rolls back staged mutations
- compensates unexecuted stages with compensateIfNotExecuted
- rejects functions outside the modifiable whitelist at enqueue
- enqueued compensation commits when the staged apply succeeds

### File 5: tissue_pulse_test.dart (26 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 26 |
| TissuePulse.batch and CollectiveTissuePulse | |
| TissuePulse evolution | |
| TissuePulse shell | |
| TissuePulse unmodifiable | |
| ElementAdded, ElementRemoved and ElementUpdated | |
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
- list add emits ElementAdded with payload
- list remove emits ElementRemoved with payload
- value set emits ElementUpdated record
- groups elements by key
- handles empty iterable

### File 6: tissue_queue_test.dart (40 tests)

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
- rejects functions outside the modifiable whitelist at enqueue
- enqueued compensation commits when the staged apply succeeds

### File 7: tissue_receptor_test.dart (17 tests)

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
- synchronises ElementAdded from another tissue
- synchronises ElementRemoved from another tissue
- synchronises collective batches
- partial sync returns single applied event
- partial sync returns batch of applied events
- synchronises ElementUpdated into a list of cells
- partial sync returns applied events only

### File 8: tissue_set_test.dart (51 tests)

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

### File 9: tissue_test.dart (35 tests)

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

### File 10: tissue_value_test.dart (25 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 25 |
| TissueValue factories | |
| TissueValue reads and writes | |
| TissueValueNucleus factories | |
| TissueValue.unmodifiable | |
| TissueValue.deputy | |
| TissueValue async | |

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

---

## Runtime Verification Status

Working directory: `packages/cell_tissue` (package-relative; host paths omitted).

If tests are named `test_*.dart` instead of `*_test.dart`, `dart test` with
no path finds nothing. Pass explicit files:

```bash
dart pub get
dart test \
  test/test_tissue_test.dart \
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
| 314 | 2 | 0 | 1 |

Status: **red**.

<details><summary>tail of test log</summary>

```
                                                                   
00:02 +302 -2: test/tissue_value_test.dart: TissueValue.unmodifiable standalone UnmodifiableTissueValue factory                                                                                        
00:02 +303 -2: test/tissue_test.dart: UnmodifiableTissue factories fromNucleus links cells when elements are identical to the bind                                                                     
00:02 +304 -2: test/tissue_test.dart: UnmodifiableTissue factories fromNucleus links cells when elements are identical to the bind                                                                     
00:02 +305 -2: test/tissue_test.dart: UnmodifiableTissue factories fromNucleus links cells when elements are identical to the bind                                                                     
00:02 +306 -2: test/tissue_value_test.dart: TissueValue.unmodifiable create factory                                                                                                                    
00:02 +307 -2: test/tissue_test.dart: TissueBase members (direct subclass) base equality, hashCode, iterator and toString                                                                              
00:02 +308 -2: test/tissue_value_test.dart: TissueValue.deputy deputy shares principal storage and equality                                                                                            
00:02 +309 -2: test/tissue_value_test.dart: TissueValue.deputy deputy shares principal storage and equality                                                                                            
00:02 +310 -2: test/tissue_value_test.dart: TissueValue.deputy deputy shares principal storage and equality                                                                                            
00:02 +310 -2: test/tissue_value_test.dart: TissueValue.deputy deputy of an unmodifiable view works                                                                                                    
00:02 +311 -2: test/tissue_value_test.dart: TissueValue.deputy deputy of an unmodifiable view works                                                                                                    
00:02 +311 -2: test/tissue_value_test.dart: TissueValue.deputy nested deputies                                                                                                                         
00:02 +312 -2: test/tissue_value_test.dart: TissueValue.deputy nested deputies                                                                                                                         
00:02 +312 -2: test/tissue_value_test.dart: TissueValue async async set updates the value                                                                                                              
00:02 +313 -2: test/tissue_value_test.dart: TissueValue async async set updates the value                                                                                                              
00:02 +313 -2: test/tissue_value_test.dart: TissueValue async unmodifiable async set returns false and value is readable                                                                               
00:02 +314 -2: test/tissue_value_test.dart: TissueValue async unmodifiable async set returns false and value is readable                                                                               
00:03 +314 -2: test/tissue_value_test.dart: TissueValue async unmodifiable async set returns false and value is readable                                                                               
00:03 +314 -2: Some tests failed.                                                                                                                                                                      

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

</details>

### Line Coverage (`lib/`)

**Overall: 2067 / 2205 lines = 93.7%**

| File | Hit | Found | Line % |
|------|----:|------:|-------:|
| `lib/src/internal/test_tissue.dart` | 19 | 19 | 100.0 |
| `lib/src/internal/tissue.dart` | 109 | 109 | 100.0 |
| `lib/src/internal/tissue_container.dart` | 10 | 10 | 100.0 |
| `lib/src/test_tissue.dart` | 31 | 31 | 100.0 |
| `lib/src/tissue.dart` | 6 | 6 | 100.0 |
| `lib/src/tissue_list.dart` | 11 | 11 | 100.0 |
| `lib/src/tissue_map.dart` | 11 | 11 | 100.0 |
| `lib/src/tissue_nucleus.dart` | 3 | 3 | 100.0 |
| `lib/src/tissue_pulse.dart` | 24 | 24 | 100.0 |
| `lib/src/tissue_queue.dart` | 10 | 10 | 100.0 |
| `lib/src/tissue_receptor.dart` | 7 | 7 | 100.0 |
| `lib/src/tissue_set.dart` | 20 | 20 | 100.0 |
| `lib/src/tissue_value.dart` | 11 | 11 | 100.0 |
| `lib/src/internal/tissue_list.dart` | 389 | 393 | 99.0 |
| `lib/src/internal/tissue_set.dart` | 242 | 246 | 98.4 |
| `lib/src/internal/tissue_map.dart` | 361 | 367 | 98.4 |
| `lib/src/internal/tissue_receptor.dart` | 48 | 49 | 98.0 |
| `lib/src/internal/tissue_queue.dart` | 257 | 270 | 95.2 |
| `lib/src/internal/tissue_pulse.dart` | 92 | 98 | 93.9 |
| `lib/src/internal/tissue_value.dart` | 164 | 197 | 83.2 |
| `lib/src/internal/tissue_nucleus.dart` | 155 | 198 | 78.3 |
| `lib/src/tissue_container.dart` | 87 | 115 | 75.7 |

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
├── test_tissue_test.dart  (15 tests, 8.5 KB, 226 lines)
├── tissue_container_test.dart  (5 tests, 1.7 KB, 50 lines)
├── tissue_list_test.dart  (49 tests, 16.4 KB, 543 lines)
├── tissue_map_test.dart  (53 tests, 19.4 KB, 583 lines)
├── tissue_pulse_test.dart  (26 tests, 10.6 KB, 335 lines)
├── tissue_queue_test.dart  (40 tests, 13.7 KB, 447 lines)
├── tissue_receptor_test.dart  (17 tests, 8.8 KB, 265 lines)
├── tissue_set_test.dart  (51 tests, 17.1 KB, 557 lines)
├── tissue_test.dart  (35 tests, 12.9 KB, 413 lines)
├── tissue_value_test.dart  (25 tests, 8.0 KB, 260 lines)
```

**Total lines of test code:** 3,679

*Generated 2026-09-13 by generate_test_verification.py*
