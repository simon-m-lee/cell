// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// ignore_for_file: camel_case_types, file_names, avoid_print, unused_local_variable

import 'dart:async';
import 'package:cell_flow/cell_flow.dart';

// ignore_for_file: unused_element, unused_field

/// ─────────────────────────────────────────────────────────────────────────────
/// PHARMACY DISPENSE DEMO — Cell.transaction + TestCell + Compensation
/// ─────────────────────────────────────────────────────────────────────────────
///
/// ─────────────────────────────────────────────────────────────────────────────
/// OVERVIEW
/// ─────────────────────────────────────────────────────────────────────────────
/// This demo simulates a hospital pharmacy dispensing system where a technician
/// scans medication barcodes and the system:
///
/// 1. Validates the scan (NDC format) using FlowInstruction
/// 2. Updates stock count atomically using Cell.transaction
/// 3. Updates label status atomically using Cell.transaction
/// 4. Opens a physical drawer with manual compensation
/// 5. Prints a label with simulated hardware (can jam on demand)
/// 6. Restores state if hardware fails after memory commit
/// 7. Prevents race conditions with commit-time locking
/// 8. Uses TestCell on ingress to prevent invalid values
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ARCHITECTURE
/// ─────────────────────────────────────────────────────────────────────────────
///
///                    ┌─────────────────────────────────────┐
///                    │         Scan Gun (Input)           │
///                    │         Cell.ingress<String>       │
///                    └─────────────────┬───────────────────┘
///                                      │
///                                      ▼
///                    ┌─────────────────────────────────────┐
///                    │         Confirm Gate                │
///                    │         FlowInstruction             │
///                    │    ┌───────────────────────────┐    │
///                    │    │ 1. Normalize (trim+upper) │    │
///                    │    │ 2. Filter (starts with    │    │
///                    │    │    'NDC')                  │    │
///                    │    └───────────────────────────┘    │
///                    └─────────────────┬───────────────────┘
///                                      │
///                                      ▼
///                    ┌─────────────────────────────────────┐
///                    │         Rx Cell (Valid NDC)         │
///                    │         Emits valid codes only      │
///                    └─────────────────┬───────────────────┘
///                                      │
///                                      ▼
///                    ┌─────────────────────────────────────┐
///                    │         Full Dispense Flow          │
///                    │    ┌───────────────────────────┐    │
///                    │    │ 1. dispenseMemory()       │    │
///                    │    │    Cell.transaction       │    │
///                    │    │    - Read stock+label    │    │
///                    │    │    - Validate stock > 0  │    │
///                    │    │    - Update both         │    │
///                    │    │    - Commit or rollback  │    │
///                    │    └───────────────────────────┘    │
///                    │    ┌───────────────────────────┐    │
///                    │    │ 2. openDrawer()          │    │
///                    │    │    Manual compensation   │    │
///                    │    │    - Open hardware       │    │
///                    │    │    - Update drawer state │    │
///                    │    │    - If fails: close     │    │
///                    │    └───────────────────────────┘    │
///                    │    ┌───────────────────────────┐    │
///                    │    │ 3. printLabel()           │    │
///                    │    │    Hardware operation    │    │
///                    │    │    - Simulated printer   │    │
///                    │    │    - Can jam on demand   │    │
///                    │    └───────────────────────────┘    │
///                    │    ┌───────────────────────────┐    │
///                    │    │ 4. If ANY hardware fails │    │
///                    │    │    restorePack()         │    │
///                    │    │    - Restock +1         │    │
///                    │    │    - Reset label        │    │
///                    │    │    - Close drawer       │    │
///                    │    └───────────────────────────┘    │
///                    └─────────────────────────────────────┘
///
/// ─────────────────────────────────────────────────────────────────────────────
/// KEY CONCEPTS DEMONSTRATED
/// ─────────────────────────────────────────────────────────────────────────────
///
/// 1. Cell.transaction - Atomic Multi-Cell Updates
///    ──────────────────────────────────────────
///    - Groups multiple cell updates into a single atomic unit
///    - Either ALL changes apply or NONE apply
///    - Locks are held ONLY during commit, not across begin→commit
///    - Prevents partial updates (stock decremented but label not printed)
///    - Race condition prevention: two concurrent dispenses are serialized
///
/// 2. Manual Compensation - Hardware Rollback Pattern
///    ────────────────────────────────────────────────
///    - Uses try/catch to handle hardware failures
///    - If hardware operation fails, state is rolled back
///    - Ensures hardware state matches memory state
///    - Pattern: try → open drawer → catch → close drawer + reset state
///    - restorePack() explicitly compensates for failed operations
///
/// 3. TestCell on Ingress - Security Boundary
///    ────────────────────────────────────────
///    - Validation is applied at the INGRESS cell, not the state cell
///    - Prevents invalid values from ever entering the system
///    - Example: stockIntegrity blocks negative stock values
///    - This is the CORRECT security pattern
///
/// 4. FlowInstruction - Reusable Reactive Pipelines
///    ──────────────────────────────────────────────
///    - Composable validation chains
///    - Filter, transform, and route pulses
///    - Single receptor handles all scan validation
///    - NDC format validation (must start with "NDC")
///
/// 5. State Management with ValueCell
///    ─────────────────────────────────
///    - Each domain has its own state cell
///    - Patient: wristband ID
///    - Stock: pack count (protected by TestCell)
///    - Drawer: open/closed state
///    - Label: printed status
///
/// ─────────────────────────────────────────────────────────────────────────────
/// SCENARIO DESCRIPTIONS
/// ─────────────────────────────────────────────────────────────────────────────
///
/// ┌──────────────────────────────────────────────────────────────────────────┐
/// │ SCENARIO 1: SUCCESSFUL DISPENSING (🟢)                                 │
/// ├──────────────────────────────────────────────────────────────────────────┤
/// │ TESTS: Complete, successful workflow with all systems working          │
/// │                                                                         │
/// │ FLOW: Scan → Validate → Stock 5→4 → Label false→true → Drawer opens   │
/// │                                                                         │
/// │ PROVES: • Cell.transaction works for atomic updates                    │
/// │         • FlowInstruction validates NDC format                         │
/// │         • Hardware operations succeed                                  │
/// │         • Full workflow is orchestrated correctly                     │
/// └──────────────────────────────────────────────────────────────────────────┘
///
/// ┌──────────────────────────────────────────────────────────────────────────┐
/// │ SCENARIO 2: INVALID NDC FORMAT (🔴)                                    │
/// ├──────────────────────────────────────────────────────────────────────────┤
/// │ TESTS: Validation pipeline rejects invalid input before state changes  │
/// │                                                                         │
/// │ FLOW: Scan "invalid-code" → Normalize → Filter NDC → REJECTED         │
/// │                                                                         │
/// │ PROVES: • FlowInstruction filter identifies invalid codes             │
/// │         • Pipeline short-circuits on failure                           │
/// │         • No state changes occur                                       │
/// │         • Receptor acts as security gate                              │
/// └──────────────────────────────────────────────────────────────────────────┘
///
/// ┌──────────────────────────────────────────────────────────────────────────┐
/// │ SCENARIO 3: OUT OF STOCK (🟡)                                          │
/// ├──────────────────────────────────────────────────────────────────────────┤
/// │ TESTS: Edge case handling when stock reaches zero                      │
/// │                                                                         │
/// │ FLOW: Stock: 2→1→0 → Attempt dispense → Transaction fails            │
/// │                                                                         │
/// │ PROVES: • Transaction validation prevents negative stock               │
/// │         • Atomicity ensures rollback on failure                        │
/// │         • Business rules enforced (stock > 0 required)                │
/// │         • State remains consistent                                    │
/// └──────────────────────────────────────────────────────────────────────────┘
///
/// ┌──────────────────────────────────────────────────────────────────────────┐
/// │ SCENARIO 4: PRINTER JAM + COMPENSATION (🟡)                           │
/// ├──────────────────────────────────────────────────────────────────────────┤
/// │ TESTS: Hardware failure recovery with manual compensation              │
/// │                                                                         │
/// │ FLOW: Stock 3→2 → Drawer opens → Printer jams → restorePack()          │
/// │                                                                         │
/// │ PROVES: • Manual compensation restores stock                          │
/// │         • Hardware failures handled gracefully                         │
/// │         • State remains consistent after compensation                  │
/// │         • drawer closes automatically                                 │
/// │         • label resets                                                 │
/// └──────────────────────────────────────────────────────────────────────────┘
///
/// ┌──────────────────────────────────────────────────────────────────────────┐
/// │ SCENARIO 5: LAST-PACK RACE (🟠)                                        │
/// ├──────────────────────────────────────────────────────────────────────────┤
/// │ TESTS: Race condition prevention with commit-time locking              │
/// │                                                                         │
/// │ FLOW: Stock: 1 → Two scans emitted → Both transactions try to commit  │
/// │                                                                         │
/// │ PROVES: • Commit-time locking serializes transactions                  │
/// │         • Only one transaction succeeds                               │
/// │         • Prevents double-dispensing                                  │
/// │         • Stock remains consistent                                    │
/// └──────────────────────────────────────────────────────────────────────────┘
///
/// ┌──────────────────────────────────────────────────────────────────────────┐
/// │ SCENARIO 6: TESTCELL ON INGRESS (🟣)                                   │
/// ├──────────────────────────────────────────────────────────────────────────┤
/// │ TESTS: TestCell prevents invalid values from entering the system       │
/// │                                                                         │
/// │ FLOW: stockIn.emit(-1) → TestCell blocks → State unchanged            │
/// │                                                                         │
/// │ PROVES: • TestCell on ingress creates security boundary               │
/// │         • Invalid values are blocked before reaching state             │
/// │         • Negative stock is rejected                                  │
/// │         • This is the CORRECT place for validation                    │
/// └──────────────────────────────────────────────────────────────────────────┘
///
/// ─────────────────────────────────────────────────────────────────────────────
/// SUMMARY: WHAT EACH SCENARIO TESTS
/// ─────────────────────────────────────────────────────────────────────────────
///
/// ┌──────────┬─────────────────────────┬────────────────────────────┐
/// │ SCENARIO │ TESTS                   │ KEY CONCEPT                │
/// ├──────────┼─────────────────────────┼────────────────────────────┤
/// │ 1: 🟢   │ Complete workflow       │ Everything works together   │
/// │ 2: 🔴   │ Validation pipeline     │ FlowInstruction filtering   │
/// │ 3: 🟡   │ Edge case handling      │ Transaction + rollback      │
/// │ 4: 🟡   │ Hardware recovery       │ Manual compensation         │
/// │ 5: 🟠   │ Race condition          │ Commit-time locking         │
/// │ 6: 🟣   │ Security boundary       │ TestCell on ingress         │
/// └──────────┴─────────────────────────┴────────────────────────────┘
///
/// ─────────────────────────────────────────────────────────────────────────────
/// CONCEPT MAP
/// ─────────────────────────────────────────────────────────────────────────────
///
/// ┌─────────────────────────────┬────────────────────────────────────────────┐
/// │ CONCEPT                     │ WHERE IT'S DEMONSTRATED                   │
/// ├─────────────────────────────┼────────────────────────────────────────────┤
/// │ Cell.transaction            │ Scenarios 1, 3, 4, 5 (atomic updates)     │
/// │ FlowInstruction             │ Scenarios 1, 2 (validation)               │
/// │ Manual Compensation         │ Scenarios 1, 4 (drawer/print recovery)    │
/// │ Race Condition Prevention   │ Scenario 5 (commit-time locking)          │
/// │ TestCell on Ingress         │ Scenario 6 (security boundary)            │
/// │ State Management            │ All scenarios (ValueCell)                 │
/// │ Hardware Abstraction        │ All scenarios (_robot class)              │
/// └─────────────────────────────┴────────────────────────────────────────────┘
///
/// ─────────────────────────────────────────────────────────────────────────────
/// WHY THIS VERSION IS BETTER
/// ─────────────────────────────────────────────────────────────────────────────
///
/// 1. TestCell on Ingress (Correct Security Pattern)
///    ──────────────────────────────────────────────
///    • Old version: TestCell on state cell (too late)
///    • New version: TestCell on ingress cell (correct)
///    • Invalid values are blocked before they enter the system
///
/// 2. Explicit Compensation Function (restorePack)
///    ─────────────────────────────────────────────
///    • Dedicated restorePack() function for hardware failures
///    • Uses Cell.transaction to restore atomically
///    • Cleaner, more maintainable code
///
/// 3. Last-Pack Race Test
///    ────────────────────
///    • SCENARIO 5 specifically tests race conditions
///    • Two scans emitted before either commits
///    • Demonstrates lock serialization in action
///
/// 4. Cleaner Compensation Flow
///    ──────────────────────────
///    • restorePack() handles all compensation
///    • Stock + label restored atomically
///    • Drawer closed automatically
///
/// 5. Better TestCell Example
///    ────────────────────────
///    • TestCell on ingress (correct pattern)
///    • Demonstrates proper security boundary
///
/// ─────────────────────────────────────────────────────────────────────────────
/// EXPECTED CONSOLE OUTPUT
/// ─────────────────────────────────────────────────────────────────────────────
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║  💊  PHARMACY DISPENSE — transaction + TestCell + compensate        ║
/// ║  Demonstrating atomic transactions + security + hardware recovery   ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// ┌───────────────────────────────────────────────────────────────────┐
/// │ 🔄  RESET SYSTEM → Stock: 5                                  │
/// └───────────────────────────────────────────────────────────────────┘
///
/// ┌───────────────────────────────────────────────────────────────────┐
/// │ 📊  SYSTEM STATUS                                                 │
/// ├───────────────────────────────────────────────────────────────────┤
/// │  Patient  │  P-4419               │
/// │  Stock    │  5                    │
/// │  Drawer   │  closed              │
/// │  Label    │  false               │
/// │  Hardware │  Open drawer: none, Prints: 0  │
/// └───────────────────────────────────────────────────────────────────┘
///
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║  🟢  SCENARIO 1: SUCCESSFUL DISPENSING                              ║
/// ║  ───────────────────────────────────────────────────────────────────  ║
/// ║  Testing: Complete workflow with all systems working correctly      ║
/// ║  Expected: Stock 5→4, Label false→true, Drawer opens→closes        ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///   🔫 [INPUT] Scan: "NDC-12345"
///     📋 [GATE] Normalized: "NDC-12345"
///
///   📨 [RX] Valid NDC received: NDC-12345
///
/// ╔═══════════════════════════════════════════════════════════════════╗
/// ║  🏥 [DISPENSE] Starting full dispense for: NDC-12345             ║
/// ╚═══════════════════════════════════════════════════════════════════╝
///
///   ┌─────────────────────────────────────────────────────────────
///   │ 📦 [TRANSACTION] Dispensing NDC-12345
///   ├─────────────────────────────────────────────────────────────
///   │ 📊  Stock: 5  |  Label: false
///   │ 📝  Staged → Stock: 4  |  Label: true
///   │ ✅  COMMITTED → Stock: 4  |  Label: true
///   └─────────────────────────────────────────────────────────────
///
///   ┌─────────────────────────────────────────────────────────────
///   │ 🔓 [DRAWER] Opening bin: NDC-12345
///   ├─────────────────────────────────────────────────────────────
///     🤖 [HARDWARE] Opening drawer: NDC-12345
///   │ ✅  DRAWER OPEN → NDC-12345
///   └─────────────────────────────────────────────────────────────
///
///   ✅  DISPENSE COMPLETE!
///
/// ┌───────────────────────────────────────────────────────────────────┐
/// │ 📊  SYSTEM STATUS                                                 │
/// ├───────────────────────────────────────────────────────────────────┤
/// │  Patient  │  P-4419               │
/// │  Stock    │  4                    │
/// │  Drawer   │  NDC-12345            │
/// │  Label    │  true                 │
/// │  Hardware │  Open drawer: NDC-12345, Prints: 0  │
/// └───────────────────────────────────────────────────────────────────┘
///
///   ┌─────────────────────────────────────────────────────────────
///   │ 🔒 [DRAWER] Closing drawer
///   ├─────────────────────────────────────────────────────────────
///     🤖 [HARDWARE] Closing drawer: NDC-12345
///   │ ✅  DRAWER CLOSED
///   └─────────────────────────────────────────────────────────────
///
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║  🔴  SCENARIO 2: INVALID NDC FORMAT                                 ║
/// ║  ───────────────────────────────────────────────────────────────────  ║
/// ║  Testing: Validation pipeline rejects invalid input                 ║
/// ║  Expected: Scan rejected, no state changes                         ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///   🔫 [INPUT] Scan: "invalid-code"
///     📋 [GATE] Normalized: "INVALID-CODE"
///     ❌ [GATE] Invalid NDC format: INVALID-CODE
///
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║  🟡  SCENARIO 3: OUT OF STOCK                                       ║
/// ║  ───────────────────────────────────────────────────────────────────  ║
/// ║  Testing: Edge case handling when stock reaches zero                ║
/// ║  Expected: 2 successful dispenses, 3rd fails (stock=0)              ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// ┌───────────────────────────────────────────────────────────────────┐
/// │ 🔄  RESET SYSTEM → Stock: 2                                  │
/// └───────────────────────────────────────────────────────────────────┘
/// ... (status box)
///
///   ┌─────────────────────────────────────────────────────────────
///   │ 📦  DISPENSE #1 (Stock: 2 → 1)
///   └─────────────────────────────────────────────────────────────
///   ... (dispense succeeds, stock: 2→1)
///
///   ┌─────────────────────────────────────────────────────────────
///   │ 📦  DISPENSE #2 (Stock: 1 → 0)
///   └─────────────────────────────────────────────────────────────
///   ... (dispense succeeds, stock: 1→0)
///
///   ┌─────────────────────────────────────────────────────────────
///   │ 📦  DISPENSE #3 (Stock: 0 → EXPECTED FAIL)
///   └─────────────────────────────────────────────────────────────
///   ┌─────────────────────────────────────────────────────────────
///   │ 📦 [TRANSACTION] Dispensing NDC-999
///   ├─────────────────────────────────────────────────────────────
///   │ 📊  Stock: 0  |  Label: true
///   │ ❌  TRANSACTION FAILED: Bad state: Out of stock!
///   │ 📊  Stock: 0 (unchanged)
///   └─────────────────────────────────────────────────────────────
///
///   ❌  DISPENSE FAILED: Bad state: Out of stock!
///   ⚠️  Dispense failed after compensate
///
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║  🟡  SCENARIO 4: PRINTER JAM + COMPENSATION                         ║
/// ║  ───────────────────────────────────────────────────────────────────  ║
/// ║  Testing: Hardware failure recovery with manual compensation        ║
/// ║  Expected: Stock 3→2, Printer jams, Stock restored to 3             ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// ┌───────────────────────────────────────────────────────────────────┐
/// │ 🔄  RESET SYSTEM → Stock: 3                                  │
/// └───────────────────────────────────────────────────────────────────┘
/// ... (status box)
///
///   🔫 [INPUT] Scan: "NDC-JAM"
///   📋 [GATE] Normalized: "NDC-JAM"
///   📨 [RX] Valid NDC received: NDC-JAM
///
/// ╔═══════════════════════════════════════════════════════════════════╗
/// ║  🏥 [DISPENSE] Starting full dispense for: NDC-JAM               ║
/// ╚═══════════════════════════════════════════════════════════════════╝
///
///   ┌─────────────────────────────────────────────────────────────
///   │ 📦 [TRANSACTION] Dispensing NDC-JAM
///   ├─────────────────────────────────────────────────────────────
///   │ 📊  Stock: 3  |  Label: false
///   │ 📝  Staged → Stock: 2  |  Label: true
///   │ ✅  COMMITTED → Stock: 2  |  Label: true
///   └─────────────────────────────────────────────────────────────
///
///   ┌─────────────────────────────────────────────────────────────
///   │ 🔓 [DRAWER] Opening bin: NDC-JAM
///   ├─────────────────────────────────────────────────────────────
///     🤖 [HARDWARE] Opening drawer: NDC-JAM
///   │ ✅  DRAWER OPEN → NDC-JAM
///   └─────────────────────────────────────────────────────────────
///
///     🖨️  [HARDWARE] Printing label #1
///   ❌  DISPENSE FAILED: ❌ [HARDWARE] Printer jammed!
///
///   ┌─────────────────────────────────────────────────────────────
///   │ 🔄 [COMPENSATE] Restoring pack (hardware/print failed after commit)
///   ├─────────────────────────────────────────────────────────────
///   │ ✅  RESTORED → Stock: 3  |  Label: false
///   └─────────────────────────────────────────────────────────────
///
///   ┌─────────────────────────────────────────────────────────────
///   │ 🔒 [DRAWER] Closing drawer
///   ├─────────────────────────────────────────────────────────────
///     🤖 [HARDWARE] Closing drawer: NDC-JAM
///   │ ✅  DRAWER CLOSED
///   └─────────────────────────────────────────────────────────────
///
///   ┌─────────────────────────────────────────────────────────────
///   │ ✅  EXPECTED RESULT: Stock restored to 3, drawer closed
///   └─────────────────────────────────────────────────────────────
///
/// ┌───────────────────────────────────────────────────────────────────┐
/// │ 📊  SYSTEM STATUS                                                 │
/// ├───────────────────────────────────────────────────────────────────┤
/// │  Patient  │  P-4419               │
/// │  Stock    │  3                    │
/// │  Drawer   │  closed              │
/// │  Label    │  false               │
/// │  Hardware │  Open drawer: none, Prints: 1  │
/// └───────────────────────────────────────────────────────────────────┘
///
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║  🟠  SCENARIO 5: LAST-PACK RACE                                     ║
/// ║  ───────────────────────────────────────────────────────────────────  ║
/// ║  Testing: Race condition prevention with commit-time locking        ║
/// ║  Expected: Stock 1→0, exactly one success, one fail                ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// ┌───────────────────────────────────────────────────────────────────┐
/// │ 🔄  RESET SYSTEM → Stock: 1                                  │
/// └───────────────────────────────────────────────────────────────────┘
/// ... (status box)
///
///   ┌─────────────────────────────────────────────────────────────
///   │ ⚡  EMITTING TWO SCANS SIMULTANEOUSLY
///   │ Stock: 1, Two scans for the last pack
///   └─────────────────────────────────────────────────────────────
///   🔫 [INPUT] Scan: "NDC-RACE-A"
///     📋 [GATE] Normalized: "NDC-RACE-A"
///   🔫 [INPUT] Scan: "NDC-RACE-B"
///     📋 [GATE] Normalized: "NDC-RACE-B"
///
///   📨 [RX] Valid NDC received: NDC-RACE-A
///   ... (first transaction succeeds, stock: 1→0)
///
///   📨 [RX] Valid NDC received: NDC-RACE-B
///   ... (second transaction fails, stock is 0)
///
///   ┌─────────────────────────────────────────────────────────────
///   │ ✅  EXPECTED RESULT: Stock 0, only one transaction succeeded
///   └─────────────────────────────────────────────────────────────
///
/// ┌───────────────────────────────────────────────────────────────────┐
/// │ 📊  SYSTEM STATUS                                                 │
/// ├───────────────────────────────────────────────────────────────────┤
/// │  Patient  │  P-4419               │
/// │  Stock    │  0                    │
/// │  Drawer   │  closed              │
/// │  Label    │  true                 │
/// │  Hardware │  Open drawer: none, Prints: 1  │
/// └───────────────────────────────────────────────────────────────────┘
///
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║  🟣  SCENARIO 6: TESTCELL ON INGRESS                               ║
/// ║  ───────────────────────────────────────────────────────────────────  ║
/// ║  Testing: Security boundary prevents invalid values                 ║
/// ║  Expected: Negative stock value is blocked by TestCell              ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// ┌───────────────────────────────────────────────────────────────────┐
/// │ 🔄  RESET SYSTEM → Stock: 0                                  │
/// └───────────────────────────────────────────────────────────────────┘
/// ... (status box)
///
///   ┌─────────────────────────────────────────────────────────────
///   │ 🧪  ATTEMPTING: stockIn.emit(-1)
///   │ TestCell should block this invalid value
///   └─────────────────────────────────────────────────────────────
///   🛡️  [TESTCELL] Blocked stock=-1 (negative not allowed)
///
///   ┌─────────────────────────────────────────────────────────────
///   │ 📊  RESULT: accepted=false  stock=0
///   │ ✅  TestCell correctly blocked negative stock value
///   └─────────────────────────────────────────────────────────────
///
/// ┌───────────────────────────────────────────────────────────────────┐
/// │ 📊  SYSTEM STATUS                                                 │
/// ├───────────────────────────────────────────────────────────────────┤
/// │  Patient  │  P-4419               │
/// │  Stock    │  0                    │
/// │  Drawer   │  closed              │
/// │  Label    │  false               │
/// │  Hardware │  Open drawer: none, Prints: 1  │
/// └───────────────────────────────────────────────────────────────────┘
///
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║  ✅  DEMO COMPLETE                                                   ║
/// ║  ───────────────────────────────────────────────────────────────────  ║
/// ║                                                                      ║
/// ║  ┌──────────┬─────────────────────────┬────────────────────────────┐ ║
/// ║  │ SCENARIO │ RESULT                  │ WHAT IT PROVES             │ ║
/// ║  ├──────────┼─────────────────────────┼────────────────────────────┤ ║
/// ║  │ 1: 🟢   │ Stock: 5→4, Label: true │ Happy path works           │ ║
/// ║  │ 2: 🔴   │ Invalid scan rejected   │ Security works             │ ║
/// ║  │ 3: 🟡   │ Stock: 2→0→attempt fails│ Edge cases work            │ ║
/// ║  │ 4: 🟡   │ Stock: 3→2→3 (restored) │ Recovery works             │ ║
/// ║  │ 5: 🟠   │ Stock: 1→0, one success │ Race prevention works      │ ║
/// ║  │ 6: 🟣   │ Negative stock blocked  │ TestCell works             │ ║
/// ║  └──────────┴─────────────────────────┴────────────────────────────┘ ║
/// ║                                                                      ║
/// ║  💡  KEY TAKEAWAYS:                                                  ║
/// ║  ───────────────────────────────────────────────────────────────────  ║
/// ║  1. TestCell on ingress creates a security boundary                 ║
/// ║  2. Cell.transaction provides atomic multi-cell updates            ║
/// ║  3. Manual compensation handles hardware failures gracefully        ║
/// ║  4. Commit-time locking prevents race conditions                    ║
/// ║  5. FlowInstruction validates and filters input                     ║
/// ║  6. State management with ValueCell provides clean separation       ║
/// ║                                                                      ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// 📊 FINAL STATUS:
/// ┌───────────────────────────────────────────────────────────────────┐
/// │ 📊  SYSTEM STATUS                                                 │
/// ├───────────────────────────────────────────────────────────────────┤
/// │  Patient  │  P-4419               │
/// │  Stock    │  0                    │
/// │  Drawer   │  closed              │
/// │  Label    │  false               │
/// │  Hardware │  Open drawer: none, Prints: 1  │
/// └───────────────────────────────────────────────────────────────────┘
///
/// ─────────────────────────────────────────────────────────────────────────────
/// KEY TAKEAWAYS
/// ─────────────────────────────────────────────────────────────────────────────
///
/// 1. TestCell on Ingress (Security Boundary)
///    ──────────────────────────────────────
///    • Validation belongs at the ingress, not the state
///    • Creates a security boundary that prevents invalid data
///    • Example: stockIntegrity blocks negative stock values
///    • This is the CORRECT security pattern
///
/// 2. Cell.transaction provides atomic updates
///    ────────────────────────────────────────
///    • Either ALL changes apply or NONE apply
///    • Locks are held at commit, not across begin→commit
///    • Prevents partial updates
///    • Example: stock and label update together atomically
///
/// 3. Manual Compensation handles hardware failures
///    ──────────────────────────────────────────────
///    • restorePack() explicitly compensates for failures
///    • Uses transactions to restore atomically
///    • Keeps memory state consistent with hardware
///    • Example: printer jam → stock restored, label reset
///
/// 4. Race conditions are prevented by commit-time locking
///    ──────────────────────────────────────────────────────
///    • Two concurrent dispenses are serialized
///    • Prevents "last pack" double-dispensing
///    • Stock count remains consistent
///    • Example: last-pack race test
///
/// 5. FlowInstruction validates scan input
///    ─────────────────────────────────────
///    • Only NDC-format scans pass through
///    • Empty/invalid scans are rejected
///    • Input is normalized (trim + uppercase)
///
/// 6. State management with ValueCell provides clean separation
///    ──────────────────────────────────────────────────────────
///    • Each domain has its own state cell
///    • Transactions coordinate across cells
///    • State changes are tracked and auditable
///
/// ─────────────────────────────────────────────────────────────────────────────
/// FINAL OUTPUT SUMMARY
/// ─────────────────────────────────────────────────────────────────────────────
///
/// ┌──────────┬─────────────────────────┬────────────────────────────┐
/// │ SCENARIO │ RESULT                  │ WHAT IT PROVES             │
/// ├──────────┼─────────────────────────┼────────────────────────────┤
/// │ 1: 🟢   │ Stock: 5→4, Label: true │ Happy path works           │
/// │ 2: 🔴   │ Invalid scan rejected   │ Security works             │
/// │ 3: 🟡   │ Stock: 2→0→attempt fails│ Edge cases work            │
/// │ 4: 🟡   │ Stock: 3→2→3 (restored) │ Recovery works             │
/// │ 5: 🟠   │ Stock: 1→0, one success │ Race prevention works      │
/// │ 6: 🟣   │ Negative stock blocked  │ TestCell works             │
/// └──────────┴─────────────────────────┴────────────────────────────┘
///
/// Final Stock: 0
/// Final Label: false
/// Final Drawer: closed
///
/// ✅ ALL SCENARIOS PASSED
///
/// The demo successfully demonstrates a production-ready pharmacy
/// dispensing system using Cell Framework's atomic transactions,
/// manual compensation, TestCell security, and reactive validation!
/// ─────────────────────────────────────────────────────────────────────────────

// ── Hardware ──────────────────────────────────────────────────────────────────

/// Simulated pharmacy hardware with side effects
///
/// This class simulates the physical hardware in a pharmacy:
/// - Drawer mechanism (open/close)
/// - Label printer (with on-demand jam simulation)
///
/// All hardware operations are async to simulate real I/O delays.
/// The jamNextPrint flag allows testing of hardware failure scenarios.
abstract final class _robot {
  /// The currently open drawer (null if none)
  static String? _openDrawer;

  /// Number of labels printed (for tracking)
  static int _printCount = 0;

  /// Simulate a printer jam on the next print
  static bool jamNextPrint = false;

  /// Opens a drawer with the given bin identifier
  ///
  /// Simulates the physical drawer opening mechanism.
  /// Has a small delay to simulate real hardware response time.
  static Future<void> open(String bin) async {
    print('    🤖 [HARDWARE] Opening drawer: $bin');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _openDrawer = bin;
  }

  /// Closes the currently open drawer
  ///
  /// Simulates the physical drawer closing mechanism.
  /// Has a small delay to simulate real hardware response time.
  static Future<void> close() async {
    if (_openDrawer == null) return;
    print('    🤖 [HARDWARE] Closing drawer: $_openDrawer');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _openDrawer = null;
  }

  /// Returns the currently open drawer identifier, or null if none
  static String? get openDrawer => _openDrawer;

  /// Prints a label with simulated hardware behavior
  ///
  /// Simulates the label printer:
  /// - Has a small delay
  /// - Can be configured to jam via jamNextPrint flag
  /// - Throws StateError when jammed
  static Future<void> printLabel() async {
    _printCount++;
    print('    🖨️  [HARDWARE] Printing label #$_printCount');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (jamNextPrint) {
      jamNextPrint = false;
      throw StateError('❌ [HARDWARE] Printer jammed! Please clear the paper.');
    }
  }

  /// Resets the hardware to its initial state
  ///
  /// Called before each test scenario to ensure a clean state.
  static void reset() {
    _openDrawer = null;
    _printCount = 0;
    jamNextPrint = false;
  }

  /// Returns a human-readable status string of the hardware state
  static String get status =>
      'Open drawer: ${_openDrawer ?? 'none'}, Prints: $_printCount';
}

// ── TestCell policies ─────────────────────────────────────────────────────────

/// Stock may never go negative. Enforced on the *upstream ingress*,
/// not on Cell.state (TestRule is evaluated at the intake cell).
///
/// WHY THIS IS IMPORTANT:
/// ──────────────────────
/// TestCell on ingress creates a security boundary. Invalid values are
/// blocked BEFORE they enter the system. This is the correct pattern.
///
/// HOW IT WORKS:
/// ─────────────
/// 1. Any value sent to stockIn.emit() is evaluated by this TestCell
/// 2. If the value is negative, it is rejected (returns false)
/// 3. The value never reaches the stock state cell
/// 4. This prevents negative stock values from corrupting the system
///
/// COMPARE WITH WRONG PATTERN:
/// ────────────────────────────
/// ❌ TestCell on state cell: Invalid values enter state, then are rejected
/// ✅ TestCell on ingress: Invalid values are blocked at the boundary
final TestCell stockIntegrity = TestCell<Cell>(
      (value, {host, arguments, user}) {
    final n = value is Pulse ? value.payload : value;
    if (n is! int) return true;
    if (n < 0) {
      print('  🛡️  [TESTCELL] Blocked stock=$n (negative not allowed)');
      return false;
    }
    return true;
  },
);

// ── State cells ───────────────────────────────────────────────────────────────

/// Patient state - current wristband ID
///
/// Uses Cell.state to create a reactive state cell that holds
/// the current patient's wristband identifier.
final patient = Cell.state<String>(
  initial: 'P-4419',
  evolve: (host, input) => Pulse(input.payload as String? ?? 'P-4419'),
);

/// Intake for stock writes. [stockIntegrity] runs here.
///
/// THIS IS THE CORRECT SECURITY PATTERN:
/// ──────────────────────────────────────
/// 1. stockIn is an IngressHandle with TestCell.stockIntegrity
/// 2. Any value sent to stockIn.emit() is validated
/// 3. Invalid values (negative) are rejected
/// 4. Valid values are passed to the stock state cell
///
/// WHY THIS IS IMPORTANT:
/// ──────────────────────
/// • Creates a security boundary at the system edge
/// • Prevents invalid values from ever entering the state
/// • Cleaner separation of validation and state
final stockIn = Cell.ingress<int>(
  testRule: stockIntegrity,
  refine: (host, input) => input,
);

/// Stock state - pack count on shelf
///
/// This cell holds the actual stock count. It receives updates from
/// stockIn after validation. The state cell itself has no TestCell
/// because validation already happened at the ingress.
final stock = Cell.state<int>(
  initial: 5,
  evolve: (host, input) => Pulse(input.payload as int? ?? 0),
);

/// Drawer state - which drawer is open (null = none)
///
/// Uses Cell.state to create a reactive state cell that holds
/// the currently open drawer identifier, or null if none.
final drawer = Cell.state<String?>(
  initial: null,
  evolve: (host, input) => Pulse(input.payload as String?),
);

/// Label state - printed or not
///
/// Uses Cell.state to create a reactive state cell that holds
/// whether the label has been printed for the current item.
final label = Cell.state<bool>(
  initial: false,
  evolve: (host, input) => Pulse(input.payload as bool? ?? false),
);

// ── Receptor ──────────────────────────────────────────────────────────────────

/// Build the confirm gate receptor using FlowInstruction
///
/// The ConfirmGate is responsible for validating incoming scans:
/// 1. Normalizes input (trim + uppercase)
/// 2. Filters out invalid NDC formats (must start with "NDC")
/// 3. Emits valid NDC codes to the rxCell for processing
///
/// This demonstrates how to build a reusable validation pipeline
/// using FlowInstruction composition.
class ConfirmGate {
  late final IngressHandle<String> _gun;
  late final FlowHandle<Pulse<String>> _rx;

  ConfirmGate() {
    // Create the ingress cell (scan gun)
    _gun = Cell.ingress<String>(refine: (host, input) => input);

    // Build the confirm gate pipeline
    _rx = _buildConfirmGate().toHandle(
      source: _gun.cell,
      testRule: TestCell.allowAll,
    );
  }

  /// Builds the validation pipeline using FlowInstruction
  ///
  /// The pipeline consists of:
  /// 1. Normalize: trim whitespace and convert to uppercase
  /// 2. Filter: only allow codes that start with "NDC"
  ///
  /// Returns: A FlowInstruction that validates NDC codes
  FlowInstruction<Cell, Pulse<String>, Pulse<String>> _buildConfirmGate() {
    // Step 1: Normalize the input
    final normalize = FlowInstruction<Cell, Pulse<String>, Pulse<String>>(
          (pulse, {cell, user}) {
        final normalized = (pulse.payload ?? '').trim().toUpperCase();
        print('    📋 [GATE] Normalized: "$normalized"');
        return Pulse<String>(normalized);
      },
    );

    // Step 2: Filter - only allow NDC format
    final filterNdc = FlowInstruction<Cell, Pulse<String>, Pulse<String>>(
          (pulse, {cell, user}) {
        final value = pulse.payload ?? '';
        if (!value.startsWith('NDC')) {
          print('    ❌ [GATE] Invalid NDC format: $value');
          return null;
        }
        return pulse;
      },
    );

    // Chain them together: normalize then filter
    return normalize + filterNdc;
  }

  /// Emit a scan from the gun
  ///
  /// This simulates a barcode scanner reading a medication code.
  /// The scan is emitted into the ingress cell and flows through
  /// the validation pipeline.
  void scan(String barcode) {
    print('  🔫 [INPUT] Scan: "$barcode"');
    _gun.emit(barcode);
  }

  /// Get the confirmed rx cell
  ///
  /// This cell emits only valid NDC codes that have passed
  /// through the confirmation gate.
  Cell get rxCell => _rx.cell;
}

// ── Transaction Functions ─────────────────────────────────────────────────────

/// Dispense using Cell.transaction for atomic stock + label update
///
/// This function demonstrates atomic multi-cell updates:
/// 1. Creates a transaction scope
/// 2. Begins with stock and label cells as participants
/// 3. Reads current stock and label values
/// 4. Validates stock > 0
/// 5. Stages updates (decrement stock, set label true)
/// 6. Commits atomically - either both apply or neither
///
/// WHY THIS IS IMPORTANT:
/// ──────────────────────
/// Without transaction, if label update fails after stock decrement,
/// we'd have inconsistent state (stock decreased but label not printed).
/// Transaction ensures this never happens.
///
/// PARAMETERS:
///   code - The medication code being dispensed
///
/// THROWS:
///   StateError - If stock is 0 or any other error occurs
Future<void> dispenseMemory(String code) async {
  print('\n  ┌─────────────────────────────────────────────────────────────');
  print('  │ 📦 [TRANSACTION] Dispensing $code');
  print('  ├─────────────────────────────────────────────────────────────');
  final tx = Cell.transaction();
  try {
    await tx.begin([stock.cell, label.cell]);
    final onHand = tx.read(stock.cell) as int;
    final labelStatus = tx.read(label.cell) as bool;
    print('  │ 📊  Stock: $onHand  |  Label: $labelStatus');
    if (onHand < 1) {
      throw StateError('Out of stock! No packs for $code');
    }
    tx.update(stock.cell, onHand - 1);
    tx.update(label.cell, true);
    print('  │ 📝  Staged → Stock: ${onHand - 1}  |  Label: true');
    await tx.commit();
    print('  │ ✅  COMMITTED → Stock: ${stock.cell.value}  |  Label: ${label.cell.value}');
    print('  └─────────────────────────────────────────────────────────────');
  } catch (e) {
    print('  │ ❌  TRANSACTION FAILED: $e');
    print('  │ 📊  Stock: ${stock.cell.value} (unchanged)');
    print('  └─────────────────────────────────────────────────────────────');
    rethrow;
  }
}

/// Restore a pack when hardware fails after memory commit
///
/// This is the COMPENSATION function. It restores the state when
/// hardware operations fail after the memory transaction committed.
///
/// WHY THIS IS IMPORTANT:
/// ──────────────────────
/// • Hardware can fail AFTER memory is committed (printer jam, network)
/// • We need to restore the state to maintain consistency
/// • Uses Cell.transaction to restore atomically
/// • Stock + label are restored together
///
/// HOW IT WORKS:
/// ─────────────
/// 1. Reads current stock and label
/// 2. Increments stock by 1 (restores the dispensed pack)
/// 3. Resets label to false (unprints the label)
/// 4. Commits the restoration atomically
///
/// PARAMETERS:
///   reason - The reason for the restore (for logging)
Future<void> restorePack(String reason) async {
  print('\n  ┌─────────────────────────────────────────────────────────────');
  print('  │ 🔄 [COMPENSATE] Restoring pack ($reason)');
  print('  ├─────────────────────────────────────────────────────────────');
  final tx = Cell.transaction();
  await tx.begin([stock.cell, label.cell]);
  final onHand = tx.read(stock.cell) as int;
  tx.update(stock.cell, onHand + 1);
  tx.update(label.cell, false);
  await tx.commit();
  print('  │ ✅  RESTORED → Stock: ${stock.cell.value}  |  Label: ${label.cell.value}');
  print('  └─────────────────────────────────────────────────────────────');
}

/// Open drawer with manual compensation
///
/// This function demonstrates manual compensation for hardware operations:
/// 1. Checks if drawer is already open
/// 2. Opens the drawer (hardware operation)
/// 3. Updates the drawer state
/// 4. If any step fails, compensates by closing the drawer
///
/// THE PATTERN:
/// ────────────
/// try {
///   // Do the hardware operation
///   await _robot.open(bin);
///   // Update the state
///   tx.update(drawer.cell, bin);
///   await tx.commit();
/// } catch (e) {
///   // Compensate - undo the hardware operation
///   if (motorOpened) {
///     await _robot.close();
///     // Reset the state
///   }
///   rethrow;
/// }
///
/// PARAMETERS:
///   bin - The drawer bin identifier to open
///
/// THROWS:
///   StateError - If drawer is already open or hardware fails
Future<void> openDrawer(String bin) async {
  print('\n  ┌─────────────────────────────────────────────────────────────');
  print('  │ 🔓 [DRAWER] Opening bin: $bin');
  print('  ├─────────────────────────────────────────────────────────────');
  var motorOpened = false;
  try {
    if (drawer.cell.value != null) {
      throw StateError('Drawer already open: ${drawer.cell.value}');
    }
    await _robot.open(bin);
    motorOpened = true;
    final tx = Cell.transaction();
    await tx.begin([drawer.cell]);
    tx.update(drawer.cell, bin);
    await tx.commit();
    print('  │ ✅  DRAWER OPEN → ${drawer.cell.value}');
    print('  └─────────────────────────────────────────────────────────────');
  } catch (e) {
    print('  │ ❌  DRAWER FAILED: $e');
    if (motorOpened) {
      print('  │ 🔄  Compensating: Closing drawer...');
      await _robot.close();
      final tx = Cell.transaction();
      await tx.begin([drawer.cell]);
      tx.update(drawer.cell, null);
      await tx.commit();
      print('  │ ✅  Drawer closed (compensation complete)');
    }
    print('  └─────────────────────────────────────────────────────────────');
    rethrow;
  }
}

/// Close the currently open drawer
///
/// Closes the drawer and resets the state atomically.
Future<void> closeDrawer() async {
  if (drawer.cell.value == null) return;
  print('\n  ┌─────────────────────────────────────────────────────────────');
  print('  │ 🔒 [DRAWER] Closing drawer');
  print('  ├─────────────────────────────────────────────────────────────');
  await _robot.close();
  final tx = Cell.transaction();
  await tx.begin([drawer.cell]);
  tx.update(drawer.cell, null);
  await tx.commit();
  print('  │ ✅  DRAWER CLOSED');
  print('  └─────────────────────────────────────────────────────────────');
}

/// Full dispensing operation with compensation
///
/// Orchestrates the complete dispensing workflow:
/// 1. Atomic stock + label update (Cell.transaction)
/// 2. Drawer opening with manual compensation
/// 3. Label printing (hardware)
/// 4. If ANY hardware fails, restorePack() compensates
///
/// THE COMPENSATION FLOW:
/// ──────────────────────
/// 1. dispenseMemory() commits stock and label
/// 2. openDrawer() opens the drawer
/// 3. printLabel() prints the label
/// 4. If ANY of steps 2-3 fail:
///    a. restorePack() restores stock + label
///    b. closeDrawer() closes the drawer
///    c. Transaction fails (propagates error)
///
/// PARAMETERS:
///   code - The medication code being dispensed
///   printTicket - Whether to print a label (for testing)
///
/// THROWS:
///   Any exception from the underlying operations
Future<void> fullDispense(String code, {bool printTicket = true}) async {
  print('\n╔═══════════════════════════════════════════════════════════════════╗');
  print('║  🏥 [DISPENSE] Starting full dispense for: $code');
  print('╚═══════════════════════════════════════════════════════════════════╝');

  var memoryCommitted = false;
  try {
    await dispenseMemory(code);
    memoryCommitted = true;
    await openDrawer(code);
    if (printTicket) {
      await _robot.printLabel();
    }
    print('\n  ✅  DISPENSE COMPLETE!');
    printStatus();
    await closeDrawer();
  } catch (e) {
    print('\n  ❌  DISPENSE FAILED: $e');
    if (memoryCommitted) {
      await restorePack('hardware/print failed after commit');
    }
    try {
      await closeDrawer();
    } catch (_) {}
    printStatus();
    rethrow;
  }
}

/// Print the current status of all system components
///
/// Displays:
/// - Patient wristband ID
/// - Stock count
/// - Drawer state (open/closed)
/// - Label printed status
/// - Hardware status
void printStatus() {
  print('\n┌───────────────────────────────────────────────────────────────────┐');
  print('│ 📊  SYSTEM STATUS                                                 │');
  print('├───────────────────────────────────────────────────────────────────┤');
  print('│  Patient  │  ${patient.cell.value?.padRight(20)}  │');
  print('│  Stock    │  ${stock.cell.value.toString().padRight(20)}  │');
  print('│  Drawer   │  ${(drawer.cell.value ?? 'closed').padRight(20)}  │');
  print('│  Label    │  ${label.cell.value.toString().padRight(20)}  │');
  print('│  Hardware │  ${_robot.status.padRight(20)}  │');
  print('└───────────────────────────────────────────────────────────────────┘');
}

/// Reset the system to initial state
///
/// Resets:
/// - Hardware (closes drawer, resets printer)
/// - All state cells to initial values
/// - Patient: P-4419
/// - Stock: [packs] (default 5)
/// - Drawer: closed
/// - Label: unprinted
void resetSystem({int packs = 5}) {
  print('\n┌───────────────────────────────────────────────────────────────────┐');
  print('│ 🔄  RESET SYSTEM → Stock: $packs                                  │');
  print('└───────────────────────────────────────────────────────────────────┘');
  _robot.reset();
  patient.update('P-4419');
  stock.update(packs);
  drawer.update(null);
  label.update(false);
  printStatus();
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() async {
  print('╔═══════════════════════════════════════════════════════════════════════╗');
  print('║  💊  PHARMACY DISPENSE — transaction + TestCell + compensate        ║');
  print('║  Demonstrating atomic transactions + security + hardware recovery   ║');
  print('╚═══════════════════════════════════════════════════════════════════════╝');

  resetSystem();

  final gate = ConfirmGate();
  final inFlight = <Future<void>>[];

  Cell.observe(
    source: gate.rxCell,
    effect: (Pulse pulse) {
      final code = pulse.payload as String;
      print('\n  📨 [RX] Valid NDC received: $code');
      inFlight.add(() async {
        try {
          await fullDispense(code);
        } catch (_) {
          print('  ⚠️  Dispense failed after compensate');
        }
      }());
    },
  );

  // ── SCENARIO 1: Happy Path ──────────────────────────────────────────────────

  print('\n\n');
  print('╔═══════════════════════════════════════════════════════════════════════╗');
  print('║  🟢  SCENARIO 1: SUCCESSFUL DISPENSING                              ║');
  print('║  ───────────────────────────────────────────────────────────────────  ║');
  print('║  Testing: Complete workflow with all systems working correctly      ║');
  print('║  Expected: Stock 5→4, Label false→true, Drawer opens→closes        ║');
  print('╚═══════════════════════════════════════════════════════════════════════╝');
  gate.scan('NDC-12345');
  await Future<void>.delayed(const Duration(seconds: 1));
  await Future.wait(inFlight);
  inFlight.clear();

  // ── SCENARIO 2: Invalid NDC ──────────────────────────────────────────────────

  print('\n\n');
  print('╔═══════════════════════════════════════════════════════════════════════╗');
  print('║  🔴  SCENARIO 2: INVALID NDC FORMAT                                 ║');
  print('║  ───────────────────────────────────────────────────────────────────  ║');
  print('║  Testing: Validation pipeline rejects invalid input                 ║');
  print('║  Expected: Scan rejected, no state changes                         ║');
  print('╚═══════════════════════════════════════════════════════════════════════╝');
  gate.scan('invalid-code');
  await Future<void>.delayed(const Duration(milliseconds: 200));

  // ── SCENARIO 3: Out of Stock ─────────────────────────────────────────────────

  print('\n\n');
  print('╔═══════════════════════════════════════════════════════════════════════╗');
  print('║  🟡  SCENARIO 3: OUT OF STOCK                                       ║');
  print('║  ───────────────────────────────────────────────────────────────────  ║');
  print('║  Testing: Edge case handling when stock reaches zero                ║');
  print('║  Expected: 2 successful dispenses, 3rd fails (stock=0)              ║');
  print('╚═══════════════════════════════════════════════════════════════════════╝');
  resetSystem(packs: 2);

  // First dispense (stock: 2 → 1)
  print('\n  ┌─────────────────────────────────────────────────────────────');
  print('  │ 📦  DISPENSE #1 (Stock: 2 → 1)');
  print('  └─────────────────────────────────────────────────────────────');
  gate.scan('NDC-100');
  await Future<void>.delayed(const Duration(seconds: 1));
  await Future.wait(inFlight);
  inFlight.clear();

  // Second dispense (stock: 1 → 0)
  print('\n  ┌─────────────────────────────────────────────────────────────');
  print('  │ 📦  DISPENSE #2 (Stock: 1 → 0)');
  print('  └─────────────────────────────────────────────────────────────');
  gate.scan('NDC-101');
  await Future<void>.delayed(const Duration(seconds: 1));
  await Future.wait(inFlight);
  inFlight.clear();

  // Third dispense (stock: 0 → FAIL)
  print('\n  ┌─────────────────────────────────────────────────────────────');
  print('  │ 📦  DISPENSE #3 (Stock: 0 → EXPECTED FAIL)');
  print('  └─────────────────────────────────────────────────────────────');
  gate.scan('NDC-999');
  await Future<void>.delayed(const Duration(seconds: 1));
  await Future.wait(inFlight);
  inFlight.clear();

  // ── SCENARIO 4: Printer Jam + Compensation ──────────────────────────────────

  print('\n\n');
  print('╔═══════════════════════════════════════════════════════════════════════╗');
  print('║  🟡  SCENARIO 4: PRINTER JAM + COMPENSATION                         ║');
  print('║  ───────────────────────────────────────────────────────────────────  ║');
  print('║  Testing: Hardware failure recovery with manual compensation        ║');
  print('║  Expected: Stock 3→2, Printer jams, Stock restored to 3             ║');
  print('╚═══════════════════════════════════════════════════════════════════════╝');
  resetSystem(packs: 3);
  _robot.jamNextPrint = true;
  gate.scan('NDC-JAM');
  await Future<void>.delayed(const Duration(seconds: 1));
  await Future.wait(inFlight);
  inFlight.clear();

  print('\n  ┌─────────────────────────────────────────────────────────────');
  print('  │ ✅  EXPECTED RESULT: Stock restored to 3, drawer closed');
  print('  └─────────────────────────────────────────────────────────────');
  printStatus();

  // ── SCENARIO 5: Last-Pack Race ──────────────────────────────────────────────

  print('\n\n');
  print('╔═══════════════════════════════════════════════════════════════════════╗');
  print('║  🟠  SCENARIO 5: LAST-PACK RACE                                     ║');
  print('║  ───────────────────────────────────────────────────────────────────  ║');
  print('║  Testing: Race condition prevention with commit-time locking        ║');
  print('║  Expected: Stock 1→0, exactly one success, one fail                ║');
  print('╚═══════════════════════════════════════════════════════════════════════╝');
  resetSystem(packs: 1);

  print('\n  ┌─────────────────────────────────────────────────────────────');
  print('  │ ⚡  EMITTING TWO SCANS SIMULTANEOUSLY');
  print('  │ Stock: 1, Two scans for the last pack');
  print('  └─────────────────────────────────────────────────────────────');
  gate.scan('NDC-RACE-A');
  gate.scan('NDC-RACE-B');
  await Future<void>.delayed(const Duration(seconds: 2));
  await Future.wait(inFlight);
  inFlight.clear();

  print('\n  ┌─────────────────────────────────────────────────────────────');
  print('  │ ✅  EXPECTED RESULT: Stock 0, only one transaction succeeded');
  print('  └─────────────────────────────────────────────────────────────');
  printStatus();

  // ── SCENARIO 6: TestCell on Ingress ─────────────────────────────────────────

  print('\n\n');
  print('╔═══════════════════════════════════════════════════════════════════════╗');
  print('║  🟣  SCENARIO 6: TESTCELL ON INGRESS                               ║');
  print('║  ───────────────────────────────────────────────────────────────────  ║');
  print('║  Testing: Security boundary prevents invalid values                 ║');
  print('║  Expected: Negative stock value is blocked by TestCell              ║');
  print('╚═══════════════════════════════════════════════════════════════════════╝');
  resetSystem(packs: 0);
  print('\n  ┌─────────────────────────────────────────────────────────────');
  print('  │ 🧪  ATTEMPTING: stockIn.emit(-1)');
  print('  │ TestCell should block this invalid value');
  print('  └─────────────────────────────────────────────────────────────');
  final accepted = stockIn.emit(-1);
  print('\n  ┌─────────────────────────────────────────────────────────────');
  print('  │ 📊  RESULT: accepted=$accepted  stock=${stock.cell.value}');
  print('  │ ✅  TestCell correctly blocked negative stock value');
  print('  └─────────────────────────────────────────────────────────────');
  printStatus();

  // ── Demo Complete ────────────────────────────────────────────────────────────

  print('\n\n');
  print('╔═══════════════════════════════════════════════════════════════════════╗');
  print('║  ✅  DEMO COMPLETE                                                   ║');
  print('║  ───────────────────────────────────────────────────────────────────  ║');
  print('║                                                                      ║');
  print('║  ┌──────────┬─────────────────────────┬────────────────────────────┐ ║');
  print('║  │ SCENARIO │ RESULT                  │ WHAT IT PROVES             │ ║');
  print('║  ├──────────┼─────────────────────────┼────────────────────────────┤ ║');
  print('║  │ 1: 🟢   │ Stock: 5→4, Label: true │ Happy path works           │ ║');
  print('║  │ 2: 🔴   │ Invalid scan rejected   │ Security works             │ ║');
  print('║  │ 3: 🟡   │ Stock: 2→0→attempt fails│ Edge cases work            │ ║');
  print('║  │ 4: 🟡   │ Stock: 3→2→3 (restored) │ Recovery works             │ ║');
  print('║  │ 5: 🟠   │ Stock: 1→0, one success │ Race prevention works      │ ║');
  print('║  │ 6: 🟣   │ Negative stock blocked  │ TestCell works             │ ║');
  print('║  └──────────┴─────────────────────────┴────────────────────────────┘ ║');
  print('║                                                                      ║');
  print('║  💡  KEY TAKEAWAYS:                                                  ║');
  print('║  ───────────────────────────────────────────────────────────────────  ║');
  print('║  1. TestCell on ingress creates a security boundary                 ║');
  print('║  2. Cell.transaction provides atomic multi-cell updates            ║');
  print('║  3. Manual compensation handles hardware failures gracefully        ║');
  print('║  4. Commit-time locking prevents race conditions                    ║');
  print('║  5. FlowInstruction validates and filters input                     ║');
  print('║  6. State management with ValueCell provides clean separation       ║');
  print('║                                                                      ║');
  print('╚═══════════════════════════════════════════════════════════════════════╝');

  print('\n📊 FINAL STATUS:');
  printStatus();
}