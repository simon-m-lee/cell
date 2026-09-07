// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// ignore_for_file: camel_case_types, file_names, avoid_print, unused_local_variable

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_flow/src/instruction/filter.dart';

// ignore_for_file: unused_element, unused_field

// ─────────────────────────────────────────────────────────────────────────────
// PHARMACY DISPENSE SYSTEM — Production-Ready Demo
//
// This is a production-shaped pharmacy dispensing system that demonstrates:
//
//   1. TestCell on ingress (security boundary for NDC and stock)
//   2. FlowInstruction with MapValue + Filter + Take(1) (count-limited gate)
//   3. Cell.transaction with repeatable-read isolation
//   4. Manual compensation for hardware failures
//   5. Commit-time locking for race condition prevention
//   6. Ledger for audit trail
//   7. Armable Take(1) for single-use gates (reset = same Receptor)
//
// ─────────────────────────────────────────────────────────────────────────────
// ARCHITECTURE DIAGRAM
// ─────────────────────────────────────────────────────────────────────────────
//
//   ┌─────────────────────────────────────────────────────────────────────────┐
//   │                         INGRESS LAYER                                 │
//   │                      (TestCell Boundary)                             │
//   ├─────────────────────────────────────────────────────────────────────────┤
//   │                                                                         │
//   │   ┌──────────────────┐         ┌──────────────────┐                    │
//   │   │     gun          │         │    stockIn       │                    │
//   │   │  ingress<String> │         │   ingress<int>   │                    │
//   │   │  TestCell:       │         │   TestCell:      │                    │
//   │   │  ndcLike         │         │   stockIntegrity │                    │
//   │   │  (non-empty)     │         │   (non-negative) │                    │
//   │   └────────┬─────────┘         └────────┬─────────┘                    │
//   │            │                             │                             │
//   │            ▼                             ▼                             │
//   │   ┌──────────────────────────────────────────────────────────────┐     │
//   │   │              buildConfirmGate()                              │     │
//   │   │  ┌────────────────────────────────────────────────────────┐  │     │
//   │   │  │ MapValue → normalize (trim + uppercase)                │  │     │
//   │   │  │ Filter → only NDC*                                    │  │     │
//   │   │  │ Take(1) → single-use gate (reset via armNextPack)     │  │     │
//   │   │  └────────────────────────────────────────────────────────┘  │     │
//   │   └────────────────────────┬─────────────────────────────────────┘     │
//   │                            │                                           │
//   │                            ▼                                           │
//   │   ┌──────────────────────────────────────────────────────────────┐     │
//   │   │                      rx.cell                                 │     │
//   │   │  Valid NDC codes that pass the gate (one per pack)          │     │
//   │   └────────────────────────┬─────────────────────────────────────┘     │
//   │                            │                                           │
//   └────────────────────────────┼───────────────────────────────────────────┘
//                                 │
//                                 ▼
//   ┌─────────────────────────────────────────────────────────────────────────┐
//   │                      TRANSACTION LAYER                                │
//   │                   (Cell.transaction with isolation)                   │
//   ├─────────────────────────────────────────────────────────────────────────┤
//   │                                                                         │
//   │   ┌──────────────────────────────────────────────────────────────┐     │
//   │   │                  fullDispense()                              │     │
//   │   │  ┌────────────────────────────────────────────────────────┐  │     │
//   │   │  │ 1. confirmPatient() → Set wristband                   │  │     │
//   │   │  │ 2. dispenseMemory() → Transaction (repeatable-read)   │  │     │
//   │   │  │    ├─ Read stock, label, patient                     │  │     │
//   │   │  │    ├─ Validate stock > 0                            │  │     │
//   │   │  │    ├─ Update stock--, label=true                   │  │     │
//   │   │  │    └─ Commit or rollback                           │  │     │
//   │   │  │ 3. openDrawer() → Hardware with compensation       │  │     │
//   │   │  │ 4. printLabel() → Hardware (can jam)              │  │     │
//   │   │  │ 5. If hardware fails → restorePack() compensation │  │     │
//   │   │  │ 6. closeDrawer() → Hardware cleanup              │  │     │
//   │   │  └────────────────────────────────────────────────────────┘  │     │
//   │   └──────────────────────────────────────────────────────────────┘     │
//   │                                                                         │
//   └─────────────────────────────────────────────────────────────────────────┘
//
// ─────────────────────────────────────────────────────────────────────────────
// EXPECTED CONSOLE OUTPUT
// ─────────────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  Pharmacy enhanced — Take(1) + tx + TestCell + ledger                ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//
//   ┌──────────────────────────────────────────────────────────────────────┐
//   │ 📊 SYSTEM STATUS                                                   │
//   ├──────────────────────────────────────────────────────────────────────┤
//   │  Patient  │  P-4419                    │
//   │  Stock    │  5                        │
//   │  Drawer   │  closed                  │
//   │  Label    │  false                   │
//   └──────────────────────────────────────────────────────────────────────┘
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  📋 SCENARIO 1: Happy NDC-12345                                    ║
//   ║  ─────────────────────────────────────────────────────────────────  ║
//   ║  Expected: Complete workflow — stock 5→4, drawer opens, label true║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//   🔫   ndc-12345
//   📨 [RX] NDC-12345  station=WARD-4-TILL-1 tech=RPh-lee
//
//   🏥 [DISPENSE] NDC-12345
//   ───────────────────────────────────────────────────────────────────────
//   ┌──────────────────────────────────────────────────────────────────────┐
//   │ 📦 [TRANSACTION] Dispensing NDC-12345                             │
//   ├──────────────────────────────────────────────────────────────────────┤
//   │ 📊  Stock: 5  |  Label: false                                     │
//   │ 📝  Staged → Stock: 4  |  Label: true                             │
//   │ ✅  COMMITTED → Stock: 4  |  Label: true                          │
//   └──────────────────────────────────────────────────────────────────────┘
//   📒 TX NDC-12345 stock=4 patient=P-4419
//     🤖 open NDC-12345
//     🖨️  print
//   📒 OK NDC-12345
//   │ ✅  DISPENSE COMPLETE!
//     🤖 close NDC-12345
//   ───────────────────────────────────────────────────────────────────────
//   🔄 [GATE] armed next pack (Take reset, same Receptor)
//   ✅ [SCENARIO 1] COMPLETE — Dispense successful
//   ───────────────────────────────────────────────────────────────────────
//
//   ... (additional scenarios as shown)
//
//   ─────────────────────────────────────────────────────────────────────────────
//   KEY TAKEAWAYS
//   ─────────────────────────────────────────────────────────────────────────────
//
//   1. TestCell on Ingress (Security Boundary)
//      ──────────────────────────────────────
//      • ndcLike: ensures non-empty NDC codes
//      • stockIntegrity: blocks negative stock values
//      • Invalid values are rejected BEFORE entering the system
//
//   2. Armable Take(1) Gate
//      ─────────────────────
//      • Take(1) creates a single-use gate
//      • Reset via armNextPack() — same Receptor, no rebuild
//      • Counts one dispense per pack
//
//   3. Cell.transaction with Repeatable-Read Isolation
//      ────────────────────────────────────────────────
//      • Locks are held ONLY during commit
//      • repeatable-read: snapshot at begin, conflict on changed participant
//      • TransactionConflictException thrown if stock changed since snapshot
//
//   4. Manual Compensation for Hardware Failures
//      ─────────────────────────────────────────
//      • restorePack() compensates when hardware fails after commit
//      • Uses Cell.transaction to restore atomically
//      • Keeps memory state consistent with hardware
//
//   5. Commit-Time Locking Prevents Race Conditions
//      ─────────────────────────────────────────────
//      • Two transactions can BEGIN with same snapshot (stock=1)
//      • First COMMIT succeeds (stock=0)
//      • Second COMMIT throws TransactionConflictException
//      • Prevents "last pack" double-dispensing
//
//   6. Ledger for Audit Trail
//      ──────────────────────
//      • All events logged for compliance
//      • TX: transaction commits
//      • OK: successful dispense
//      • FAIL: failed dispense
//      • COMPENSATE: state restoration
//      • CONFLICT: isolation violation
//
// ─────────────────────────────────────────────────────────────────────────────

/// Station identifier for this pharmacy terminal.
const stationId = 'WARD-4-TILL-1';

/// Technician identifier for audit trail.
const techId = 'RPh-lee';

// ─────────────────────────────────────────────────────────────────────────────
// LEDGER SYSTEM
// ─────────────────────────────────────────────────────────────────────────────

/// A ledger entry for the audit trail.
///
/// Records every significant event in the system for compliance and debugging.
/// Each entry includes a timestamp, event kind, and detailed information.
class DispenseRecord {
  /// The timestamp of the event.
  final DateTime at;

  /// The kind of event (e.g., "TX", "OK", "FAIL", "COMPENSATE", "CONFLICT").
  final String kind;

  /// Detailed information about the event.
  final String detail;

  /// Creates a [DispenseRecord] with the current timestamp.
  DispenseRecord(this.kind, this.detail) : at = DateTime.now();

  @override
  String toString() => '${at.toIso8601String()} $kind $detail';
}

/// The audit trail ledger.
final ledger = <DispenseRecord>[];

/// Logs an entry to the ledger.
///
/// [kind] - The kind of event (e.g., "TX", "OK", "FAIL")
/// [detail] - Detailed information about the event
void log(String kind, String detail) {
  final e = DispenseRecord(kind, detail);
  ledger.add(e);
  print('  📒 $e');
}

// ─────────────────────────────────────────────────────────────────────────────
// VISUAL OUTPUT HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Prints a visual separator for scenarios.
void printSeparator() {
  print('─' * 70);
}

/// Prints a scenario header with visual formatting.
///
/// [number] - The scenario number (e.g., "1", "4", "8")
/// [title] - The scenario title
/// [expected] - The expected outcome description
void printScenarioHeader(String number, String title, String expected) {
  print('');
  print('═' * 70);
  print('${'║  📋 SCENARIO $number: $title'.padRight(71)}║');
  print('║  ${'─' * 68}║');
  print('${'║  Expected: $expected'.padRight(71)}║');
  print('═' * 70);
}

/// Prints a scenario completion marker.
///
/// [message] - The completion message describing what happened.
void printScenarioComplete(String message) {
  print('  ✅ [SCENARIO COMPLETE] $message');
  printSeparator();
}

// ─────────────────────────────────────────────────────────────────────────────
// HARDWARE SIMULATION
// ─────────────────────────────────────────────────────────────────────────────

/// Simulated pharmacy hardware with side effects.
///
/// This class simulates the physical hardware in a pharmacy:
/// - Drawer mechanism (open/close)
/// - Label printer (with on-demand jam simulation)
abstract final class _robot {
  /// The currently open drawer (null if none).
  static String? openDrawer;

  /// Simulate a printer jam on the next print.
  static bool jamNextPrint = false;

  /// Opens a drawer with the given bin identifier.
  static Future<void> open(String bin) async {
    print('    🤖 open $bin');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    openDrawer = bin;
  }

  /// Closes the currently open drawer.
  static Future<void> close() async {
    if (openDrawer == null) return;
    print('    🤖 close $openDrawer');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    openDrawer = null;
  }

  /// Prints a label with simulated hardware behavior.
  ///
  /// Throws [StateError] if [jamNextPrint] is true.
  static Future<void> printLabel() async {
    print('    🖨️  print');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (jamNextPrint) {
      jamNextPrint = false;
      throw StateError('Printer jammed');
    }
  }

  /// Resets the hardware to its initial state.
  static void reset() => openDrawer = null;
}

// ─────────────────────────────────────────────────────────────────────────────
// TESTCELL POLICIES (Security Boundary)
// ─────────────────────────────────────────────────────────────────────────────

/// TestCell that validates NDC-like codes (non-empty).
///
/// This TestCell is applied at the ingress level, creating a security boundary
/// that prevents empty or whitespace-only values from entering the system.
///
/// ### Security Pattern
/// This is the CORRECT pattern for validation:
/// - Validation happens at the edge (ingress), not the state
/// - Invalid values are rejected BEFORE entering the system
/// - Creates a clean security boundary
final TestCell ndcLike = TestCell<Cell>(
      (value, {host, arguments, user}) {
    final s = value is Pulse ? value.payload : value;
    if (s is! String) return true;
    final trimmed = s.trim();
    final ok = trimmed.isNotEmpty;
    if (!ok) print('  🛡️  [TESTCELL] blocked empty input');
    return ok;
  },
);

/// TestCell that validates stock values (non-negative).
///
/// This TestCell is applied at the ingress level, creating a security boundary
/// that prevents negative stock values from corrupting the system.
///
/// ### Clinical Rationale
/// - Stock cannot be negative in a real pharmacy
/// - Negative values would indicate a data corruption or system error
/// - Blocking these prevents cascading failures
final TestCell stockIntegrity = TestCell<Cell>(
      (value, {host, arguments, user}) {
    final n = value is Pulse ? value.payload : value;
    if (n is! int) return true;
    if (n < 0) {
      print('  🛡️  [TESTCELL] stockIn blocked $n');
      return false;
    }
    return true;
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// SOURCE CELLS (with TestCell protection)
// ─────────────────────────────────────────────────────────────────────────────

/// Gun scanner ingress with TestCell protection.
///
/// Accepts string inputs that are non-empty after trimming.
final gun = Cell.ingress<String>(testRule: ndcLike, refine: (h, i) => i);

/// Stock ingress with TestCell protection.
///
/// Accepts integer inputs that are >= 0.
final stockIn = Cell.ingress<int>(testRule: stockIntegrity, refine: (h, i) => i);

/// Patient state cell.
///
/// Holds the current patient wristband ID.
final patient = Cell.state<String>(
  initial: '',
  evolve: (h, i) => Pulse(i.payload as String? ?? ''),
);

/// Stock state cell.
///
/// Holds the current pack count on the shelf.
final stock = Cell.state<int>(
  initial: 5,
  evolve: (h, i) => Pulse(i.payload as int? ?? 0),
);

/// Drawer state cell.
///
/// Holds the currently open drawer identifier (null = closed).
final drawer = Cell.state<String?>(
  initial: null,
  evolve: (h, i) => Pulse(i.payload as String?),
);

/// Label state cell.
///
/// Indicates whether a label has been printed for the current item.
final label = Cell.state<bool>(
  initial: false,
  evolve: (h, i) => Pulse(i.payload as bool? ?? false),
);

// ─────────────────────────────────────────────────────────────────────────────
// TAKE(1) GATE STATE
// ─────────────────────────────────────────────────────────────────────────────

/// The current state of the Take(1) gate.
///
/// 1 = armed (can dispense), 0 = spent (needs reset).
int _armed = 1;

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM GATE (FlowInstruction)
// ─────────────────────────────────────────────────────────────────────────────

/// Builds the confirmation gate using FlowInstruction.
///
/// The confirmation gate is a reusable pipeline that:
/// 1. Normalize: trim whitespace and convert to uppercase
/// 2. Filter: only allow codes that start with "NDC"
/// 3. Take(1): single-use gate (reset via armNextPack)
///
/// ### Why Take(1) is Important
/// - Prevents multiple dispenses from a single scan
/// - Ensures one pack per scan
/// - Reset via armNextPack() without rebuilding the graph
///
/// Returns a [FlowInstruction] that validates NDC codes.
FlowInstruction buildConfirmGate() {
  // Step 1: Normalize the input
  final normalize = MapValue<String, String>((s) => s.trim().toUpperCase());

  // Step 2: Filter - only allow NDC format
  final ndc = Filter<String>((s) {
    final ok = s.startsWith('NDC');
    if (!ok) print('  ❌ [GATE] Invalid NDC format: $s');
    return ok;
  });

  // Step 3: Take(1) - single-use gate
  final takeOne = FlowInstruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
    if (_armed <= 0) {
      print('  ⛔ [GATE] Take(1) spent — arm next pack');
      return null;
    }
    _armed--;
    return pulse;
  });

  // Chain them together
  return normalize + ndc + takeOne;
}

/// Arms the next pack (resets Take(1) gate).
///
/// This resets the gate state without rebuilding the Receptor.
/// The same Receptor is used for all dispenses.
///
/// ### Why This Matters
/// - No need to recreate the cell graph
/// - Efficient: same Receptor reused
/// - Clean: reset without rebuilding
void armNextPack() {
  _armed = 1;
  print('  🔄 [GATE] armed next pack (Take reset, same Receptor)');
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTPUT CELLS
// ─────────────────────────────────────────────────────────────────────────────

/// The confirmed RX handle — emits valid NDC codes.
FlowHandle<Pulse<dynamic>>? rx;

/// Retains observer references to prevent garbage collection.
final retain = <Object>[];

/// In-flight dispense futures (for waiting).
final inFlight = <Future<void>>[];

// ─────────────────────────────────────────────────────────────────────────────
// INSTALL GATE & OBSERVERS
// ─────────────────────────────────────────────────────────────────────────────

/// Installs the confirmation gate and observer.
///
/// This must be called BEFORE any data flows through the system.
///
/// ### Observer Behavior
/// When a valid NDC code passes the gate:
/// 1. The code is printed with station and tech info
/// 2. fullDispense() is called asynchronously
/// 3. The future is tracked for completion
void installGate() {
  rx = buildConfirmGate().toHandle(
    source: gun.cell,
    testRule: TestCell.allowAll,
  );

  retain.add(Cell.observe(
    source: rx!.cell,
    effect: (Pulse p) {
      final code = p.payload as String;
      print('  📨 [RX] $code  station=$stationId tech=$techId');
      inFlight.add(fullDispense(code));
    },
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSACTION FUNCTIONS
// ─────────────────────────────────────────────────────────────────────────────

/// Confirms the patient by setting the wristband ID.
///
/// [id] - The patient wristband identifier
///
/// This uses a simple Cell.transaction to set the patient ID atomically.
Future<void> confirmPatient(String id) async {
  final tx = Cell.transaction();
  await tx.begin([patient.cell]);
  tx.update(patient.cell, id);
  await tx.commit();
}

/// Dispenses a medication using Cell.transaction.
///
/// This function demonstrates atomic multi-cell updates with repeatable-read
/// isolation to prevent race conditions.
///
/// ### Transaction Flow
/// 1. Begins transaction with repeatable-read isolation
/// 2. Reads stock, label, and patient values (snapshot)
/// 3. Validates stock > 0 and patient is set
/// 4. Stages updates (decrement stock, set label true)
/// 5. Commits atomically — either all apply or none
///
/// ### Isolation Guarantees
/// - repeatable-read: snapshot at begin
/// - Conflict detection: if stock changed since snapshot, commit fails
/// - Locks held ONLY during commit, not across begin→commit
///
/// [code] - The medication code being dispensed
///
/// Throws [StateError] if stock is 0 or patient is not set.
/// Throws [TransactionConflictException] if stock changed since snapshot.
Future<void> dispenseMemory(String code) async {
  final tx = Cell.transaction(TransactionOptions(
    isolation: IsolationLevel.repeatableRead,
    onEvent: (e) => print('  🔒 $e'),
  ));

  print('  ${'─' * 70}');
  print('${'  │ 📦 [TRANSACTION] Dispensing $code'.padRight(71)}│');
  print('  ${'─' * 70}');

  try {
    await tx.begin([stock.cell, label.cell, patient.cell]);

    final onHand = tx.read(stock.cell) as int;
    final patientId = tx.read(patient.cell) as String;

    if (patientId.isEmpty) {
      throw StateError('No wristband — patient not confirmed');
    }

    if (onHand < 1) {
      throw StateError('Out of stock! No packs for $code');
    }

    print('  │ 📊  Stock: $onHand  |  Label: ${tx.read(label.cell)}');
    tx.update(stock.cell, onHand - 1);
    tx.update(label.cell, true);
    print('  │ 📝  Staged → Stock: ${onHand - 1}  |  Label: true');

    await tx.commit();
    print('  │ ✅  COMMITTED → Stock: ${stock.cell.value}  |  Label: ${label.cell.value}');
    print('  ${'─' * 70}');

    log('TX', '$code stock=${stock.cell.value} patient=${patient.cell.value}');

  } on TransactionConflictException catch (e) {
    print('  │ ❌  CONFLICT: $e');
    print('  ${'─' * 70}');
    log('CONFLICT', '$code $e');
    throw StateError('Shelf conflict — another transaction changed stock');

  } catch (e) {
    print('  │ ❌  TRANSACTION FAILED: $e');
    print('  ${'─' * 70}');
    rethrow;
  }
}

/// Restores a pack when hardware fails after memory commit.
///
/// This is the COMPENSATION function. It restores the state when
/// hardware operations fail after the memory transaction committed.
///
/// ### Compensation Pattern
/// 1. Hardware operation fails after memory commit
/// 2. restorePack() increments stock back by 1
/// 3. label is reset to false
/// 4. State is restored to pre-dispense values
/// 5. All changes are atomic using Cell.transaction
///
/// [reason] - The reason for the restore (for logging)
Future<void> restorePack(String reason) async {
  print('  ${'─' * 70}');
  print('${'  │ 🔄 [COMPENSATE] Restoring pack ($reason)'.padRight(71)}│');
  print('  ${'─' * 70}');

  final tx = Cell.transaction();
  await tx.begin([stock.cell, label.cell]);

  final onHand = tx.read(stock.cell) as int;
  tx.update(stock.cell, onHand + 1);
  tx.update(label.cell, false);

  await tx.commit();
  print('  │ ✅  RESTORED → Stock: ${stock.cell.value}  |  Label: ${label.cell.value}');
  print('  ${'─' * 70}');

  log('COMPENSATE', reason);
}

/// Opens a drawer with manual compensation.
///
/// This function demonstrates manual compensation for hardware operations:
/// 1. Checks if drawer is already open
/// 2. Opens the drawer (hardware operation)
/// 3. Updates the drawer state
/// 4. If any step fails, compensates by closing the drawer
///
/// [bin] - The drawer bin identifier to open
Future<void> openDrawer(String bin) async {
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

  } catch (e) {
    if (motorOpened) {
      print('  🔄 Compensating: Closing drawer...');
      await _robot.close();

      final tx = Cell.transaction();
      await tx.begin([drawer.cell]);
      tx.update(drawer.cell, null);
      await tx.commit();
    }
    rethrow;
  }
}

/// Closes the currently open drawer.
Future<void> closeDrawer() async {
  if (drawer.cell.value == null) return;
  await _robot.close();

  final tx = Cell.transaction();
  await tx.begin([drawer.cell]);
  tx.update(drawer.cell, null);
  await tx.commit();
}

// ─────────────────────────────────────────────────────────────────────────────
// FULL DISPENSE ORCHESTRATION
// ─────────────────────────────────────────────────────────────────────────────

/// Full dispensing operation with compensation.
///
/// Orchestrates the complete dispensing workflow:
/// 1. Confirm patient wristband
/// 2. Atomic stock + label update (Cell.transaction)
/// 3. Drawer opening with manual compensation
/// 4. Label printing (hardware)
/// 5. If ANY hardware fails, restorePack() compensates
/// 6. Close drawer
/// 7. Arm next pack (reset Take(1) gate)
///
/// [code] - The medication code being dispensed
///
/// ### Compensation Flow
/// 1. dispenseMemory() commits stock and label (atomic)
/// 2. openDrawer() opens the drawer (hardware)
/// 3. printLabel() prints the label (hardware)
/// 4. If ANY of steps 2-3 fail:
///    a. restorePack() restores stock + label (atomic)
///    b. closeDrawer() closes the drawer
///    c. Transaction fails (propagates error)
Future<void> fullDispense(String code) async {
  print('\n🏥 [DISPENSE] $code');
  print('─' * 70);

  var committed = false;
  try {
    await confirmPatient('P-4419');
    await dispenseMemory(code);
    committed = true;

    await openDrawer(code);
    await _robot.printLabel();

    log('OK', code);
    print('│ ✅  DISPENSE COMPLETE!');
    await closeDrawer();

  } catch (e) {
    print('│ ❌  DISPENSE FAILED: $e');
    log('FAIL', '$code $e');

    if (committed) {
      await restorePack('hw after commit');
    }

    try {
      await closeDrawer();
    } catch (_) {}

  } finally {
    print('─' * 70);
    armNextPack();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS DISPLAY
// ─────────────────────────────────────────────────────────────────────────────

/// Prints a compact status line.
void status() {
  print('  📊 patient=${patient.cell.value} stock=${stock.cell.value} '
      'drawer=${drawer.cell.value ?? 'closed'} label=${label.cell.value}');
}

/// Prints a formatted status box with borders.
void statusBox() {
  print('');
  print('─' * 70);
  print('${'│ 📊 SYSTEM STATUS'.padRight(71)}│');
  print('─' * 70);
  print('│  Patient  │  ${patient.cell.value ?? 'N/A'.padRight(20)}  │');
  print('│  Stock    │  ${stock.cell.value.toString().padRight(20)}  │');
  print('│  Drawer   │  ${(drawer.cell.value ?? 'closed').padRight(20)}  │');
  print('│  Label    │  ${label.cell.value.toString().padRight(20)}  │');
  print('─' * 70);
}

// ─────────────────────────────────────────────────────────────────────────────
// SCAN FUNCTION
// ─────────────────────────────────────────────────────────────────────────────

/// Emits a scan from the gun.
///
/// [raw] - The raw barcode string
void scan(String raw) {
  print('  🔫 $raw');
  gun.emit(raw);
}

// ─────────────────────────────────────────────────────────────────────────────
// SCENARIO 8: LAST-PACK SAME SNAPSHOT
// ─────────────────────────────────────────────────────────────────────────────

/// Demonstrates repeatable-read isolation with same-snapshot transactions.
///
/// This test demonstrates commit-time locking:
/// 1. Both transactions BEGIN with the same snapshot (stock=1)
/// 2. First COMMIT succeeds (stock=0)
/// 3. Second COMMIT throws TransactionConflictException
/// 4. Prevents "last pack" double-dispensing
///
/// ### Why This Is Important
/// Without repeatable-read isolation, two concurrent transactions could
/// both read stock=1 and both decrement to 0, resulting in stock=-1.
/// This is the "lost update" problem that isolation prevents.
Future<void> lastPackSameSnapshot() async {
  print('');
  print('═' * 70);
  print('║  📋 SCENARIO 8: Same-snapshot last pack (repeatable-read conflict)║');
  print('║  ${'─' * 68}║');
  print('║  Expected: First commit succeeds, second throws conflict         ║');
  print('═' * 70);

  stock.update(1);

  final opts = TransactionOptions(
    isolation: IsolationLevel.repeatableRead,
    onEvent: (e) => print('  🔒 $e'),
  );

  final a = Cell.transaction(opts);
  final b = Cell.transaction(opts);

  await a.begin([stock.cell, label.cell]);
  await b.begin([stock.cell, label.cell]);

  final ra = a.read(stock.cell);
  final rb = b.read(stock.cell);
  print('  📸 snapshot A=$ra B=$rb (both should be 1)');

  a.update(stock.cell, 0);
  a.update(label.cell, true);
  await a.commit();
  log('TX', 'SNAP-A stock=${stock.cell.value}');
  print('  ✅ A committed stock=${stock.cell.value}');

  b.update(stock.cell, 0);
  b.update(label.cell, true);

  try {
    await b.commit();
    log('NO-CONFLICT', 'B committed the same snapshot — isolation did not reject');
    print('  ⚠️  B committed too — Cell did not throw TransactionConflictException');
  } on TransactionConflictException catch (e) {
    log('CONFLICT', '$e');
    print('  ✅ B TransactionConflictException — commit-time isolation works!');
  } catch (e) {
    log('CONFLICT?', '$e');
    print('  B threw $e');
  }

  statusBox();
  printSeparator();
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

/// Main entry point for the Pharmacy Dispense Demo.
///
/// This demo demonstrates:
/// - TestCell on ingress (security boundary)
/// - FlowInstruction with MapValue + Filter + Take(1)
/// - Cell.transaction with repeatable-read isolation
/// - Manual compensation for hardware failures
/// - Commit-time locking for race condition prevention
/// - Ledger for audit trail
///
/// ### Execution Order is Critical!
/// 1. Install gate and observers (before any data flows)
/// 2. Wait for observers to attach
/// 3. Run the simulation scenarios
Future<void> main() async {
  print('═' * 70);
  print('║  Pharmacy enhanced — Take(1) + tx + TestCell + ledger        ║');
  print('═' * 70);

  installGate();
  await confirmPatient('P-4419');
  stock.update(5);
  statusBox();

  // ── SCENARIO 1 ──────────────────────────────────────────────────
  printScenarioHeader('1', 'Happy NDC-12345',
      'Complete workflow — stock 5→4, drawer opens, label true');
  scan('  ndc-12345 ');
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await Future.wait(inFlight);
  inFlight.clear();
  statusBox();
  printScenarioComplete('Dispense successful');

  // ── SCENARIO 2 ──────────────────────────────────────────────────
  printScenarioHeader('2', 'Invalid code',
      'Code rejected by Filter (doesn\'t start with NDC)');
  scan('invalid-code');
  await Future<void>.delayed(const Duration(milliseconds: 150));
  printScenarioComplete('Invalid code rejected');

  // ── SCENARIO 3 ──────────────────────────────────────────────────
  printScenarioHeader('3', 'Empty gun (TestCell / filter)',
      'Empty input rejected by TestCell or Filter');
  scan('   ');
  await Future<void>.delayed(const Duration(milliseconds: 150));
  printScenarioComplete('Empty input rejected');

  // ── SCENARIO 4 ──────────────────────────────────────────────────
  printScenarioHeader('4', 'Jam + compensate',
      'Printer jams → compensate → stock restored');
  _robot.jamNextPrint = true;
  scan('NDC-JAM');
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await Future.wait(inFlight);
  inFlight.clear();
  statusBox();
  printScenarioComplete('Compensation restored stock');

  // ── SCENARIO 5 ──────────────────────────────────────────────────
  printScenarioHeader('5', 'Drain to 0 then NDC-999',
      'Stock 1→0 (success), then 0→attempt (fails)');
  stock.update(1);
  scan('NDC-LAST');
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await Future.wait(inFlight);
  inFlight.clear();
  scan('NDC-999');
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await Future.wait(inFlight);
  inFlight.clear();
  statusBox();
  printScenarioComplete('Stock drained, out-of-stock handled');

  // ── SCENARIO 6 ──────────────────────────────────────────────────
  printScenarioHeader('6', 'stockIn.emit(-1)',
      'TestCell blocks negative stock value');
  final ok = stockIn.emit(-1);
  print('  emit(-1) accepted=$ok stock=${stock.cell.value}');
  printScenarioComplete('TestCell blocked negative value');

  // ── SCENARIO 7 ──────────────────────────────────────────────────
  printScenarioHeader('7', 'Last-pack overlap (stock=1, two scans)',
      'First scan succeeds (1→0), second fails (out of stock)');
  stock.update(1);
  armNextPack();
  scan('NDC-RACE-A');
  armNextPack();
  scan('NDC-RACE-B');
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await Future.wait(inFlight);
  inFlight.clear();
  statusBox();
  printScenarioComplete('Only one transaction succeeded');

  // ── SCENARIO 8 ──────────────────────────────────────────────────
  await lastPackSameSnapshot();

  // ── LEDGER ──────────────────────────────────────────────────
  print('\n${'─' * 70}');
  print('${'│ 📒 LEDGER'.padRight(71)}│');
  print('─' * 70);
  for (final e in ledger) {
    print('${'│ $e'.padRight(71)}│');
  }
  print('─' * 70);

  // ── FINAL TAKEAWAYS ──────────────────────────────────────────────
  print('\n${'═' * 70}');
  print('${'║  📌 KEY TAKEAWAYS'.padRight(71)}║');
  print('║  ${'─' * 68}║');
  print('║  1. TestCell on ingress creates a security boundary     ║');
  print('║  2. Armable Take(1) gate — reset without rebuilding      ║');
  print('║  3. Cell.transaction with repeatable-read isolation      ║');
  print('║  4. Manual compensation for hardware failures            ║');
  print('║  5. Commit-time locking prevents race conditions         ║');
  print('║  6. Ledger provides complete audit trail                 ║');
  print('║  7. FlowInstruction composition for reusable gates       ║');
  print('═' * 70);
}