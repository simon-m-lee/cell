# cell_flutter_devtools_extension package - Test Verification Report

**Generated:** 2026-11-21
**Package:** cell_flutter_devtools_extension (v0.1.0)
**Test Files Analyzed:** 2
**Total Tests:** 12 (0 skipped)

---

## Table of contents

- [Executive Summary](#executive-summary)
  - [Snapshot](#snapshot)
  - [Quick Stats](#quick-stats)
- [Test File Inventory](#test-file-inventory)
- [Source Under Test (`lib/`)](#source-under-test-lib)
- [Detailed Test Coverage](#detailed-test-coverage)
  - [contract_test.dart](#file-1-contract_test.dart-1-tests)
  - [ledger_view_test.dart](#file-2-ledger_view_test.dart-11-tests)
- [Runtime Verification Status](#runtime-verification-status)
  - [Last `flutter test`](#last-flutter-test)
- [Recommendations](#recommendations)
- [Appendix: File Locations](#appendix-file-locations)

---

## Executive Summary

The cell_flutter_devtools_extension test suite contains **12 unit tests** across **2 files** in `test/`. Counts are `test(` / `testWidgets(` declarations.

The library under test is **4 source files** in `lib/`: **1** in top-level entry points; **3** in `lib/src/` — implementation.

This file is **generated**. Edit the script flags or the stub sections at the bottom; do not hand-count `test(` / `testWidgets(`.

### Snapshot

Last `flutter test` is **green**: **12 passed**, 0 failed (exit 0).

### Quick Stats

| Metric | Value |
|--------|-------|
| **Total Test Files** | 2 |
| **Total Tests** | 12 |
| **Skipped** | 0 |
| **Last full run** | 12 passed, 0 failed, 0 skipped (exit 0) |
| **Test Groups** | 0 (`group(` declarations) |
| **Async-ish tests** | ~1 (heuristic) |
| **Line coverage (`lib/`)** | *(pass `--coverage` or provide lcov.info)* |

---

## Test File Inventory

| # | File | Lines | Tests | Size | Focus |
|---|------|------:|------:|------:|-------|
| 1 | contract_test.dart | 62 | 1 | 1.9 KB | contract |
| 2 | ledger_view_test.dart | 252 | 11 | 8.2 KB | ledger view |
| **Total** | | **314** | **12** | **10.0 KB** | |

---

## Source Under Test (`lib/`)

The extension UI surface is inventoried: `lib/main.dart` (DevToolsExtension root) and `lib/src/`.

| Area | Files | Lines | Size |
|------|------:|------:|-----:|
| top-level entry points | 1 | 23 | 0.7 KB |
| `lib/src/` — implementation | 3 | 572 | 17.3 KB |

| File | Lines | Size |
|------|------:|-----:|
| `lib/main.dart` | 23 | 0.7 KB |
| `lib/src/ledger_client.dart` | 55 | 2.1 KB |
| `lib/src/ledger_model.dart` | 98 | 3.1 KB |
| `lib/src/ledger_view.dart` | 419 | 12.1 KB |

---

## Detailed Test Coverage

Generated from `group(` / `test(` names. Tighten the prose by hand if needed.

### File 1: contract_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- the provider wire contract parses in the extension UI

### File 2: ledger_view_test.dart (11 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 11 |

**Tests**

- shows a spinner while the first request is in flight
- shows the actionable error state when the fetch fails
- shows the helpful empty state
- renders rows with timestamp, command, id, vetted, tx seq
- tapping a row expands the full receipt JSON
- the command filter narrows the list
- the vetted filter narrows the list
- the time-range filter narrows the list
- clear resets every filter
- the summary panel reports total, last-minute, and rejected
- polling picks up new receipts without a manual refresh

---

## Runtime Verification Status

Working directory: `packages/cell_flutter_devtools_extension` (package-relative; host paths omitted).

`flutter test` discovers `*_test.dart` automatically; the explicit list is kept for the report and for CI (it excludes shared helpers such as `test/fuzz/fuzz_harness.dart` that have no `main()`).

```bash
flutter pub get
flutter test \
  test/contract_test.dart \
  test/ledger_view_test.dart
```

### Last `flutter test`

| Passed | Failed | Skipped | Exit |
|-------:|-------:|--------:|-----:|
| 12 | 0 | 0 | 0 |

Status: **green**.

<details><summary>tail of test log</summary>

```
0:01 +3: ./test/ledger_view_test.dart: shows the helpful empty state                                                            
00:01 +4: ./test/ledger_view_test.dart: shows the helpful empty state                                                            
00:01 +4: ./test/ledger_view_test.dart: renders rows with timestamp, command, id, vetted, tx seq                                 
00:02 +4: ./test/ledger_view_test.dart: renders rows with timestamp, command, id, vetted, tx seq                                 
00:02 +5: ./test/ledger_view_test.dart: renders rows with timestamp, command, id, vetted, tx seq                                 
00:02 +5: ./test/ledger_view_test.dart: tapping a row expands the full receipt JSON                                              
00:02 +6: ./test/ledger_view_test.dart: tapping a row expands the full receipt JSON                                              
00:02 +6: ./test/ledger_view_test.dart: the command filter narrows the list                                                      
00:02 +7: ./test/ledger_view_test.dart: the command filter narrows the list                                                      
00:02 +7: ./test/ledger_view_test.dart: the vetted filter narrows the list                                                       
00:02 +8: ./test/ledger_view_test.dart: the vetted filter narrows the list                                                       
00:02 +8: ./test/ledger_view_test.dart: the time-range filter narrows the list                                                   
00:02 +9: ./test/ledger_view_test.dart: the time-range filter narrows the list                                                   
00:02 +9: ./test/ledger_view_test.dart: clear resets every filter                                                                
00:02 +10: ./test/ledger_view_test.dart: clear resets every filter                                                               
00:02 +10: ./test/ledger_view_test.dart: the summary panel reports total, last-minute, and rejected                              
00:02 +11: ./test/ledger_view_test.dart: the summary panel reports total, last-minute, and rejected                              
00:02 +11: ./test/ledger_view_test.dart: polling picks up new receipts without a manual refresh                                  
00:02 +12: ./test/ledger_view_test.dart: polling picks up new receipts without a manual refresh                                  
00:02 +12: All tests passed!
```

</details>

---

## Recommendations

1. Keep this report generated — do not hand-count `test(` / `testWidgets(`.
2. CI should run `{tc}` from the package root; widget tests inject fake
   fetch functions so the web-only service client stays out of the VM
   test path.
3. `contract_test.dart` pins the wire contract against
   `cell_flutter_devtools` — update both sides together.
4. Rebuild into the provider package with `build_and_copy` and run the
   DevTools `validate` command whenever the UI changes.

---

## Appendix: File Locations

```
test/
├── contract_test.dart  (1 tests, 1.9 KB, 62 lines)
├── ledger_view_test.dart  (11 tests, 8.2 KB, 252 lines)
```

**Total lines of test code:** 314

*Generated 2026-11-21 by generate_test_verification.py*
