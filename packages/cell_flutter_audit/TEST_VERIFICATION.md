# cell_flutter_audit package - Test Verification Report

**Generated:** 2026-11-21
**Package:** cell_flutter_audit (v0.1.0)
**Test Files Analyzed:** 6
**Total Tests:** 42 (0 skipped)

---

## Table of contents

- [Executive Summary](#executive-summary)
  - [Snapshot](#snapshot)
  - [Quick Stats](#quick-stats)
- [Test File Inventory](#test-file-inventory)
- [Source Under Test (`lib/`)](#source-under-test-lib)
- [Detailed Test Coverage](#detailed-test-coverage)
  - [audit_entry_test.dart](#file-1-audit_entry_test.dart-7-tests)
  - [audit_entry_tile_test.dart](#file-2-audit_entry_tile_test.dart-4-tests)
  - [audit_trail_controller_test.dart](#file-3-audit_trail_controller_test.dart-14-tests)
  - [audit_trail_exporter_test.dart](#file-4-audit_trail_exporter_test.dart-5-tests)
  - [audit_trail_view_test.dart](#file-5-audit_trail_view_test.dart-11-tests)
  - [audit_demo_ledger_test.dart](#file-6-audit_demo_ledger_test.dart-1-tests)
- [Runtime Verification Status](#runtime-verification-status)
  - [Last `flutter test`](#last-flutter-test)
- [Recommendations](#recommendations)
- [Appendix: File Locations](#appendix-file-locations)

---

## Executive Summary

The cell_flutter_audit test suite contains **42 unit tests** across **6 files** in `test/`. Counts are `test(` / `testWidgets(` declarations.

The library under test is **10 source files** in `lib/`: **2** in top-level barrels (`cell_flutter_audit.dart`, `io.dart`); **8** in `lib/src/` — widgets, controller, exporter.

This file is **generated**. Edit the script flags or the stub sections at the bottom; do not hand-count `test(` / `testWidgets(`.

### Snapshot

Last `flutter test` is **green**: **42 passed**, 0 failed (exit 0).

### Quick Stats

| Metric | Value |
|--------|-------|
| **Total Test Files** | 6 |
| **Total Tests** | 42 |
| **Skipped** | 0 |
| **Last full run** | 42 passed, 0 failed, 0 skipped (exit 0) |
| **Test Groups** | 10 (`group(` declarations) |
| **Async-ish tests** | ~2 (heuristic) |
| **Line coverage (`lib/`)** | *(pass `--coverage` or provide lcov.info)* |

---

## Test File Inventory

| # | File | Lines | Tests | Size | Focus |
|---|------|------:|------:|------:|-------|
| 1 | audit_entry_test.dart | 77 | 7 | 2.6 KB | audit entry; groups: AuditEntry.fromReceipt, formatAuditTimestamp |
| 2 | audit_entry_tile_test.dart | 63 | 4 | 2.0 KB | audit entry tile |
| 3 | audit_trail_controller_test.dart | 177 | 14 | 5.8 KB | audit trail controller; groups: filterBy, search, sortBy, pagination, ingestion |
| 4 | audit_trail_exporter_test.dart | 100 | 5 | 3.4 KB | audit trail exporter; groups: toJson, toCsv, AuditTrailFileExporter |
| 5 | audit_trail_view_test.dart | 166 | 11 | 5.7 KB | audit trail view |
| 6 | audit_demo_ledger_test.dart | 131 | 1 | 5.0 KB | audit demo ledger |
| **Total** | | **714** | **42** | **24.6 KB** | |

---

## Source Under Test (`lib/`)

The whole audit surface is inventoried: the top-level barrels (`cell_flutter_audit.dart`, `io.dart`) and the `lib/src/` implementation files.

| Area | Files | Lines | Size |
|------|------:|------:|-----:|
| top-level barrels (`cell_flutter_audit.dart`, `io.dart`) | 2 | 27 | 1.3 KB |
| `lib/src/` — widgets, controller, exporter | 8 | 1,065 | 34.5 KB |

| File | Lines | Size |
|------|------:|-----:|
| `lib/cell_flutter_audit.dart` | 23 | 1.1 KB |
| `lib/io.dart` | 4 | 0.1 KB |
| `lib/src/audit_entry.dart` | 126 | 4.3 KB |
| `lib/src/audit_entry_tile.dart` | 97 | 3.1 KB |
| `lib/src/audit_file_exporter.dart` | 29 | 0.9 KB |
| `lib/src/audit_rejection_event.dart` | 38 | 1.3 KB |
| `lib/src/audit_trail_controller.dart` | 238 | 7.7 KB |
| `lib/src/audit_trail_exporter.dart` | 93 | 3.0 KB |
| `lib/src/audit_trail_theme.dart` | 62 | 1.8 KB |
| `lib/src/audit_trail_view.dart` | 382 | 12.4 KB |

---

## Detailed Test Coverage

Generated from `group(` / `test(` names. Tighten the prose by hand if needed.

### File 1: audit_entry_test.dart (7 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 7 |
| AuditEntry.fromReceipt | |
| formatAuditTimestamp | |

**Tests**

- extracts the command name from a named function
- truncates the id to 8 characters and keeps the full id
- formats positional, named, and combined arguments
- copies vetted, timestamp, and txSequence from the receipt
- renders HH:mm:ss.SSS in local time
- zero-pads short fields
- functionDisplayName falls back for anonymous closures

### File 2: audit_entry_tile_test.dart (4 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 4 |

**Tests**

- renders the compact row with command, timestamp, and status
- tapping expands the argument payload
- an onTap callback replaces the expand behavior
- unvetted tiles render the unvetted icon

### File 3: audit_trail_controller_test.dart (14 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 14 |
| filterBy | |
| search | |
| sortBy | |
| pagination | |
| ingestion | |

**Tests**

- matches command names by substring
- matches command names exactly when exact is set
- filters by vetted status
- filters by inclusive time range
- matches the command name case-insensitively
- matches the formatted arguments
- an empty query clears the search
- timestamp descends by default and ascends on request
- commandName orders case-insensitively
- vetted orders unvetted first when ascending
- loadMore grows the visible window by pageSize
- a receipt stream appends live receipts
- addOutcome routes accepted, staged, and rejected outcomes
- clear resets receipts, rejections, and filters

### File 4: audit_trail_exporter_test.dart (5 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 5 |
| toJson | |
| toCsv | |
| AuditTrailFileExporter | |

**Tests**

- produces a valid JSON array with the documented shape
- serializes named arguments with symbol keys as strings
- starts with the header and has one row per receipt
- escapes commas, quotes, and newlines in arguments
- exportToFile writes JSON and CSV files

### File 5: audit_trail_view_test.dart (11 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 11 |

**Tests**

- renders one card per receipt
- a card shows the command, HH:mm:ss.SSS timestamp, and vetted icon
- unvetted receipts render with the unvetted icon and no vetted icon
- rejection events render as red-bordered cards with the reason
- showRejections: false hides rejection events
- tapping a payload expands the arguments
- a receipt with no arguments shows the empty payload label
- an empty ledger shows the helpful cell.apply message
- theme overrides the empty message and hides the timestamp
- the timeline lays out without overflow on a 320px screen
- a txSequence receipt shows its transaction chip

### File 6: audit_demo_ledger_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- renders the demo ledger: add, rejection, txApply undo

---

## Runtime Verification Status

Working directory: `packages/cell_flutter_audit` (package-relative; host paths omitted).

`flutter test` discovers `*_test.dart` automatically; the explicit list is kept for the report and for CI (it excludes shared helpers such as `test/fuzz/fuzz_harness.dart` that have no `main()`).

```bash
flutter pub get
flutter test \
  test/audit_entry_test.dart \
  test/audit_entry_tile_test.dart \
  test/audit_trail_controller_test.dart \
  test/audit_trail_exporter_test.dart \
  test/audit_trail_view_test.dart \
  test/integration/audit_demo_ledger_test.dart
```

### Last `flutter test`

| Passed | Failed | Skipped | Exit |
|-------:|-------:|--------:|-----:|
| 42 | 0 | 0 | 0 |

Status: **green**.

<details><summary>tail of test log</summary>

```
0:01 +30: ./test/audit_trail_view_test.dart: renders one card per receipt                                                                    
00:02 +30: ./test/audit_trail_view_test.dart: renders one card per receipt                                                                    
00:02 +31: ./test/integration/audit_demo_ledger_test.dart: renders the demo ledger: add, rejection, txApply undo                              
00:02 +32: ./test/integration/audit_demo_ledger_test.dart: renders the demo ledger: add, rejection, txApply undo                              
00:02 +33: ./test/integration/audit_demo_ledger_test.dart: renders the demo ledger: add, rejection, txApply undo                              
00:02 +34: ./test/integration/audit_demo_ledger_test.dart: renders the demo ledger: add, rejection, txApply undo                              
00:02 +35: ./test/integration/audit_demo_ledger_test.dart: renders the demo ledger: add, rejection, txApply undo                              
00:02 +36: ./test/audit_trail_view_test.dart: tapping a payload expands the arguments                                                         
00:02 +37: ./test/audit_trail_view_test.dart: tapping a payload expands the arguments                                                         
00:02 +37: ./test/audit_trail_view_test.dart: a receipt with no arguments shows the empty payload label                                       
00:02 +38: ./test/audit_trail_view_test.dart: a receipt with no arguments shows the empty payload label                                       
00:02 +38: ./test/audit_trail_view_test.dart: an empty ledger shows the helpful cell.apply message                                            
00:02 +39: ./test/audit_trail_view_test.dart: an empty ledger shows the helpful cell.apply message                                            
00:02 +39: ./test/audit_trail_view_test.dart: theme overrides the empty message and hides the timestamp                                       
00:02 +40: ./test/audit_trail_view_test.dart: theme overrides the empty message and hides the timestamp                                       
00:02 +40: ./test/audit_trail_view_test.dart: the timeline lays out without overflow on a 320px screen                                        
00:02 +41: ./test/audit_trail_view_test.dart: the timeline lays out without overflow on a 320px screen                                        
00:02 +41: ./test/audit_trail_view_test.dart: a txSequence receipt shows its transaction chip                                                 
00:02 +42: ./test/audit_trail_view_test.dart: a txSequence receipt shows its transaction chip                                                 
00:02 +42: All tests passed!
```

</details>

---

## Recommendations

1. Keep this report generated — do not hand-count `test(` / `testWidgets(`.
2. CI should run `{tc}` from the package root so widget tests and the
   demo-ledger integration test all run.
3. The integration suite (`test/integration/`) replays the live audit
   demo's ledger mechanics — update it when the demo's gate or undo
   flow changes.
4. Export tests pin the JSON/CSV wire shape; extend them whenever a
   receipt field is added to `ApplyReceipt`.
5. Keep `io.dart` (file export) separate from the web-safe main
   library; do not import `dart:io` from `lib/src/`.

---

## Appendix: File Locations

```
test/
├── audit_entry_test.dart  (7 tests, 2.6 KB, 77 lines)
├── audit_entry_tile_test.dart  (4 tests, 2.0 KB, 63 lines)
├── audit_trail_controller_test.dart  (14 tests, 5.8 KB, 177 lines)
├── audit_trail_exporter_test.dart  (5 tests, 3.4 KB, 100 lines)
├── audit_trail_view_test.dart  (11 tests, 5.7 KB, 166 lines)
├── integration/audit_demo_ledger_test.dart  (1 tests, 5.0 KB, 131 lines)
```

**Total lines of test code:** 714

*Generated 2026-11-21 by generate_test_verification.py*
