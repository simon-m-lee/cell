# cell_skin package - Test Verification Report

**Generated:** 2026-11-23
**Package:** cell_skin (v0.1.0)
**Test Files Analyzed:** 13
**Total Tests:** 52 (0 skipped)

---

## Table of contents

- [Executive Summary](#executive-summary)
  - [Snapshot](#snapshot)
  - [Quick Stats](#quick-stats)
- [Test File Inventory](#test-file-inventory)
- [Source Under Test (`lib/`)](#source-under-test-lib)
- [Detailed Test Coverage](#detailed-test-coverage)
  - [api_chooser_up_to_date_test.dart](#file-1-api_chooser_up_to_date_test.dart-2-tests)
  - [binding_table_test.dart](#file-2-binding_table_test.dart-3-tests)
  - [code_review_grok_test.dart](#file-3-code_review_grok_test.dart-11-tests)
  - [code_review_test.dart](#file-4-code_review_test.dart-7-tests)
  - [cursor_test.dart](#file-5-cursor_test.dart-1-tests)
  - [egress_cell_test.dart](#file-6-egress_cell_test.dart-3-tests)
  - [exposure_gate_test.dart](#file-7-exposure_gate_test.dart-1-tests)
  - [replay_integration_test.dart](#file-8-replay_integration_test.dart-1-tests)
  - [rest_conformance_test.dart](#file-9-rest_conformance_test.dart-1-tests)
  - [router_cell_test.dart](#file-10-router_cell_test.dart-4-tests)
  - [skin_client_test.dart](#file-11-skin_client_test.dart-3-tests)
  - [wire_message_test.dart](#file-12-wire_message_test.dart-6-tests)
  - [wire_schema_test.dart](#file-13-wire_schema_test.dart-9-tests)
- [Runtime Verification Status](#runtime-verification-status)
  - [Last `dart test`](#last-dart-test)
- [Recommendations](#recommendations)
- [Appendix: File Locations](#appendix-file-locations)

---

## Executive Summary

The cell_skin test suite contains **52 unit tests** across **13 files** in `test/`. Counts are `test(` declarations.

The library under test is **23 source files** in `lib/`: **3** in top-level barrels (`cell_skin.dart`, `cell_skin_rest.dart`); **5** in `lib/src/wire/` — wire vocabulary and JSON codecs; **5** in `lib/src/cells/` — the four-cell membrane; **2** in `lib/src/binding/` — binding table and whitelist; **1** in `lib/src/manifest/` — tool catalogue and schemas; **2** in `lib/src/adapters/` — REST and MCP seams; **3** in `lib/src/client/` — in-process and remote clients; **2** in `lib/src/security/` — auth SPI and context bridges.

This file is **generated**. Edit the script flags or the stub sections at the bottom; do not hand-count `test(`.

### Snapshot

Last `dart test` is **green**: **52 passed**, 0 failed (exit 0).

### Quick Stats

| Metric | Value |
|--------|-------|
| **Total Test Files** | 13 |
| **Total Tests** | 52 |
| **Skipped** | 0 |
| **Last full run** | 52 passed, 0 failed, 0 skipped (exit 0) |
| **Test Groups** | 0 (`group(` declarations) |
| **Async-ish tests** | ~31 (heuristic) |
| **Line coverage (`lib/`)** | *(pass `--coverage` or provide lcov.info)* |

---

## Test File Inventory

| # | File | Lines | Tests | Size | Focus |
|---|------|------:|------:|------:|-------|
| 1 | api_chooser_up_to_date_test.dart | 36 | 2 | 1.4 KB | api chooser up to date |
| 2 | binding_table_test.dart | 60 | 3 | 2.0 KB | binding table |
| 3 | code_review_grok_test.dart | 333 | 11 | 10.7 KB | code review grok |
| 4 | code_review_test.dart | 282 | 7 | 9.6 KB | code review |
| 5 | cursor_test.dart | 97 | 1 | 3.3 KB | cursor |
| 6 | egress_cell_test.dart | 109 | 3 | 3.9 KB | egress cell |
| 7 | exposure_gate_test.dart | 51 | 1 | 1.7 KB | exposure gate |
| 8 | replay_integration_test.dart | 58 | 1 | 2.0 KB | replay integration |
| 9 | rest_conformance_test.dart | 101 | 1 | 3.2 KB | rest conformance |
| 10 | router_cell_test.dart | 109 | 4 | 3.9 KB | router cell |
| 11 | skin_client_test.dart | 65 | 3 | 2.1 KB | skin client |
| 12 | wire_message_test.dart | 109 | 6 | 3.9 KB | wire message |
| 13 | wire_schema_test.dart | 108 | 9 | 4.3 KB | wire schema |
| **Total** | | **1,518** | **52** | **51.9 KB** | |

---

## Source Under Test (`lib/`)

The whole membrane is inventoried: the top-level barrels, the wire vocabulary, the four cells, the binding/manifest layer, the adapters, the clients, and the security SPI.

| Area | Files | Lines | Size |
|------|------:|------:|-----:|
| top-level barrels (`cell_skin.dart`, `cell_skin_rest.dart`) | 3 | 140 | 8.9 KB |
| `lib/src/wire/` — wire vocabulary and JSON codecs | 5 | 1,223 | 43.8 KB |
| `lib/src/cells/` — the four-cell membrane | 5 | 965 | 34.8 KB |
| `lib/src/binding/` — binding table and whitelist | 2 | 319 | 11.6 KB |
| `lib/src/manifest/` — tool catalogue and schemas | 1 | 206 | 6.9 KB |
| `lib/src/adapters/` — REST and MCP seams | 2 | 862 | 29.9 KB |
| `lib/src/client/` — in-process and remote clients | 3 | 264 | 9.9 KB |
| `lib/src/security/` — auth SPI and context bridges | 2 | 170 | 6.1 KB |

| File | Lines | Size |
|------|------:|-----:|
| `lib/cell_skin.dart` | 78 | 2.5 KB |
| `lib/cell_skin_rest.dart` | 28 | 1.0 KB |
| `lib/doc/api_chooser.dart` | 34 | 5.4 KB |
| `lib/src/adapters/mcp/mcp_adapter.dart` | 106 | 3.5 KB |
| `lib/src/adapters/rest/rest_adapter.dart` | 756 | 26.4 KB |
| `lib/src/binding/skin_binding.dart` | 258 | 9.4 KB |
| `lib/src/binding/skin_whitelist.dart` | 61 | 2.2 KB |
| `lib/src/cells/egress_cell.dart` | 76 | 2.7 KB |
| `lib/src/cells/inbound_cell.dart` | 60 | 2.1 KB |
| `lib/src/cells/mux_cell.dart` | 47 | 1.8 KB |
| `lib/src/cells/router_cell.dart` | 336 | 11.5 KB |
| `lib/src/cells/skin_membrane.dart` | 446 | 16.7 KB |
| `lib/src/client/remote_cell.dart` | 90 | 3.3 KB |
| `lib/src/client/skin_client.dart` | 146 | 5.7 KB |
| `lib/src/client/skin_error.dart` | 28 | 0.9 KB |
| `lib/src/manifest/skin_manifest.dart` | 206 | 6.9 KB |
| `lib/src/security/context_bridge.dart` | 62 | 2.1 KB |
| `lib/src/security/skin_auth.dart` | 108 | 4.1 KB |
| `lib/src/wire/wire_ledger.dart` | 26 | 1.1 KB |
| `lib/src/wire/wire_message.dart` | 546 | 20.2 KB |
| `lib/src/wire/wire_outcome.dart` | 196 | 6.6 KB |
| `lib/src/wire/wire_receipt.dart` | 182 | 6.3 KB |
| `lib/src/wire/wire_schema.dart` | 273 | 9.6 KB |

---

## Detailed Test Coverage

Generated from `group(` / `test(` names. Tighten the prose by hand if needed.

### File 1: api_chooser_up_to_date_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- lib/doc/api_chooser.dart is generated and up to date
- skill references/api_chooser.md is generated and up to date

### File 2: binding_table_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |

**Tests**

- SkinBindingTable registers and looks up bindings
- toApplyCommand decodes positional and named wire arguments
- whitelist gates exposure declaratively

### File 3: code_review_grok_test.dart (11 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 11 |

**Tests**

- a rejected apply never masquerades as an accepted egress
- concurrent requests with distinct ids never cross-complete
- a WireResponse JSON round-trip preserves the outcome
- WireMessage.fromJson throws FormatException on malformed fields
- REST accepts a positional JSON array
- a timeout surfaces 504 and a same-id retry does not double-apply
- SSE streams a frame and releases the subscription on disconnect
- a request carries its own PulseContext, not system
- the inbound gate rejects non-wire pulses
- SkinMembrane.request rejects notifications instead of timing out
- a binding whose target is not the registered cell is rejected

### File 4: code_review_test.dart (7 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 7 |

**Tests**

- H1: each egress state change pairs with its own receipt
- H1: egress carries no correlation id
- H6: a duplicate server correlation id never re-applies
- H6: a non-JSON result is omitted, never a transport 500
- H3/H4: the REST surface enforces exposure, methods, content 
- H9: close() stops observers and fails pending requests
- H3: whitelist entries with no binding produce a policy warning

### File 5: cursor_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- a stale lastSeenSeq conflicts before the target apply runs

### File 6: egress_cell_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |

**Tests**

- ledgered egress pairs each change with its own receipt
- unledgered egress marks every change pendingReceipt
- the ledger stream appears as skin.ledger.entry pulses

### File 7: exposure_gate_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- a whitelisted set hides bound functions from the wire

### File 8: replay_integration_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- membrane-driven applies replay with zero divergences

### File 9: rest_conformance_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- REST adapter shares the same four cells as MCP

### File 10: router_cell_test.dart (4 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 4 |

**Tests**

- accepted dispatch carries the target receipt
- rejected dispatch carries the real ApplyRejected
- unknown tool produces a WireError with no receipt
- manifest request returns the tool catalogue

### File 11: skin_client_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |

**Tests**

- SkinClient applies through the membrane and reads the manifest
- SkinClient throws SkinError for exposure misses
- RemoteCellClient calls and observes a remote cell in-process

### File 12: wire_message_test.dart (6 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 6 |

**Tests**

- WireRequest round-trips through JSON
- WireNotification and WireError round-trip
- manifest messages round-trip
- ledger entry message round-trips through the canonical JSON
- unknown kind throws FormatException
- result pulse types follow the taxonomy

### File 13: wire_schema_test.dart (9 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 9 |

**Tests**

- schema derivation widens to types, never narrows to one value
- merging widens instead of narrows
- merging same-key objects intersects required keys
- merging different types falls back to permissive
- integer merged with number widens to number
- an absent bound is unconstrained, never inherited
- SchemaObserver accumulates shapes per argument
- JsonSchema JSON round-trip preserves keywords
- JsonSchema.fromJson tolerates array types and schema objects

---

## Runtime Verification Status

Working directory: `packages/cell_skin` (package-relative; host paths omitted).

`dart test` discovers `*_test.dart` automatically; the explicit list is kept for the report and for CI (it excludes shared helpers such as `test/skin_fixture.dart` that have no `main()`).

```bash
dart pub get
dart test \
  test/api_chooser_up_to_date_test.dart \
  test/binding_table_test.dart \
  test/code_review_grok_test.dart \
  test/code_review_test.dart \
  test/cursor_test.dart \
  test/egress_cell_test.dart \
  test/exposure_gate_test.dart \
  test/replay_integration_test.dart \
  test/rest_conformance_test.dart \
  test/router_cell_test.dart \
  test/skin_client_test.dart \
  test/wire_message_test.dart \
  test/wire_schema_test.dart
```

### Last `dart test`

| Passed | Failed | Skipped | Exit |
|-------:|-------:|--------:|-----:|
| 52 | 0 | 0 | 0 |

Status: **green**.

<details><summary>tail of test log</summary>

```
0:00 +40: test/code_review_grok_test.dart: a timeout surfaces 504 and a same-id retry does not double-apply                                                                                           
00:00 +41: test/code_review_grok_test.dart: a timeout surfaces 504 and a same-id retry does not double-apply                                                                                           
00:00 +42: test/code_review_grok_test.dart: a timeout surfaces 504 and a same-id retry does not double-apply                                                                                           
00:00 +43: test/code_review_grok_test.dart: a timeout surfaces 504 and a same-id retry does not double-apply                                                                                           
00:00 +44: test/code_review_grok_test.dart: a timeout surfaces 504 and a same-id retry does not double-apply                                                                                           
00:00 +45: test/code_review_grok_test.dart: a timeout surfaces 504 and a same-id retry does not double-apply                                                                                           
00:00 +46: test/code_review_grok_test.dart: a timeout surfaces 504 and a same-id retry does not double-apply                                                                                           
00:01 +46: test/code_review_grok_test.dart: a timeout surfaces 504 and a same-id retry does not double-apply                                                                                           
00:01 +47: test/code_review_grok_test.dart: a timeout surfaces 504 and a same-id retry does not double-apply                                                                                           
00:01 +47: test/code_review_grok_test.dart: SSE streams a frame and releases the subscription on disconnect                                                                                            
00:01 +48: test/code_review_grok_test.dart: SSE streams a frame and releases the subscription on disconnect                                                                                            
00:01 +48: test/code_review_grok_test.dart: a request carries its own PulseContext, not system                                                                                                         
00:01 +49: test/code_review_grok_test.dart: a request carries its own PulseContext, not system                                                                                                         
00:01 +49: test/code_review_grok_test.dart: the inbound gate rejects non-wire pulses                                                                                                                   
00:01 +50: test/code_review_grok_test.dart: the inbound gate rejects non-wire pulses                                                                                                                   
00:01 +50: test/code_review_grok_test.dart: SkinMembrane.request rejects notifications instead of timing out                                                                                           
00:01 +51: test/code_review_grok_test.dart: SkinMembrane.request rejects notifications instead of timing out                                                                                           
00:01 +51: test/code_review_grok_test.dart: a binding whose target is not the registered cell is rejected                                                                                              
00:01 +52: test/code_review_grok_test.dart: a binding whose target is not the registered cell is rejected                                                                                              
00:01 +52: All tests passed!
```

</details>

---

## Recommendations

1. Keep this report generated — do not hand-count `test(`.
2. CI should run `dart test` from the package root (the explicit file list above excludes shared helpers without a `main()`).
3. The egress pairing tests (`egress_cell_test.dart`) are the receipt-provenance contract: every state change must pair with its own ledger entry's receipt — never a borrowed one.
4. The REST conformance tests run over real sockets; keep the security posture assertions (auth, method, content-type, origin, body cap) in sync with `lib/src/adapters/rest/rest_adapter.dart`.
5. The in-process acceptance test (`replay_integration_test.dart`) is the membrane/replay contract: membrane-driven applies must replay into a fresh graph with zero divergences.
6. The two review-regression suites (`code_review_test.dart`, `code_review_grok_test.dart`) encode the findings of the external reviews — extend them when a new review lands.
7. The example's widget tests are Flutter tests in `example/test/` and are tracked separately from this report (`cd example && flutter test`).

---

## Appendix: File Locations

```
test/
├── api_chooser_up_to_date_test.dart  (2 tests, 1.4 KB, 36 lines)
├── binding_table_test.dart  (3 tests, 2.0 KB, 60 lines)
├── code_review_grok_test.dart  (11 tests, 10.7 KB, 333 lines)
├── code_review_test.dart  (7 tests, 9.6 KB, 282 lines)
├── cursor_test.dart  (1 tests, 3.3 KB, 97 lines)
├── egress_cell_test.dart  (3 tests, 3.9 KB, 109 lines)
├── exposure_gate_test.dart  (1 tests, 1.7 KB, 51 lines)
├── replay_integration_test.dart  (1 tests, 2.0 KB, 58 lines)
├── rest_conformance_test.dart  (1 tests, 3.2 KB, 101 lines)
├── router_cell_test.dart  (4 tests, 3.9 KB, 109 lines)
├── skin_client_test.dart  (3 tests, 2.1 KB, 65 lines)
├── wire_message_test.dart  (6 tests, 3.9 KB, 109 lines)
├── wire_schema_test.dart  (9 tests, 4.3 KB, 108 lines)
```

**Total lines of test code:** 1,518

*Generated 2026-11-23 by generate_test_verification.py*
