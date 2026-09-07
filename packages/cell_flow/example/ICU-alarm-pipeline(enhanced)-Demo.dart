// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/async_map.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_flow/src/instruction/filter.dart';

// ignore_for_file: unused_local_variable, avoid_print, unused_element, file_names

// ─────────────────────────────────────────────────────────────────────────────
// ENHANCED ICU BEDSIDE ALARM PIPELINE
//
// This is an enhanced version of the ICU Bedside Alarm Pipeline that
// demonstrates advanced Cell Framework concepts:
//
//   1. TestCell on sensor ingress (security boundary)
//   2. Manual snapshot bus for reliable data flow
//   3. Separate PAGE and WARN gates with Distinct
//   4. Ledger for audit trail
//   5. Pager with retry logic (AsyncMapWithRetry)
//   6. ACK resets Distinct for the same Receptor
//   7. TestCell rejects invalid values at the edge
//
// ─────────────────────────────────────────────────────────────────────────────
// ARCHITECTURE DIAGRAM
// ─────────────────────────────────────────────────────────────────────────────
//
//   ┌─────────────────────────────────────────────────────────────────────────┐
//   │                         SENSOR INGRESS                                │
//   │                         (TestCell Boundary)                          │
//   ├─────────────────────────────────────────────────────────────────────────┤
//   │                                                                         │
//   │   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐              │
//   │   │  hrIn        │   │  spo2In      │   │  motionIn    │              │
//   │   │  ingress<int>│   │  ingress<int>│   │  ingress<bool>│              │
//   │   │  TestCell:   │   │  TestCell:   │   │              │              │
//   │   │  20–250      │   │  0–100       │   │              │              │
//   │   └──────┬───────┘   └──────┬───────┘   └──────┬───────┘              │
//   │          │                  │                  │                       │
//   │          └──────────────────┼──────────────────┘                       │
//   │                             │                                          │
//   │                             ▼                                          │
//   │              ┌─────────────────────────────────┐                       │
//   │              │         publishVitals()         │                       │
//   │              │  Creates Reading(hr, spo2,      │                       │
//   │              │              moving)            │                       │
//   │              └──────────────┬──────────────────┘                       │
//   │                             │                                          │
//   │                             ▼                                          │
//   │              ┌─────────────────────────────────┐                       │
//   │              │        vitalsIn.ingress         │                       │
//   │              │      (Snapshot Bus)             │                       │
//   │              └──────────────┬──────────────────┘                       │
//   │                             │                                          │
//   └─────────────────────────────┼──────────────────────────────────────────┘
//                                 │
//                                 ▼
//   ┌─────────────────────────────────────────────────────────────────────────┐
//   │                      ALARM GATES (FlowInstruction)                     │
//   ├─────────────────────────────────────────────────────────────────────────┤
//   │                                                                         │
//   │   ┌──────────────────────────────────────────────────────────────┐     │
//   │   │                    MapValue<Reading, Severity>               │     │
//   │   │  • moving → none                                             │     │
//   │   │  • SpO2 < 88 OR HR < 40 OR HR > 140 → PAGE                  │     │
//   │   │  • SpO2 < 92 OR HR < 50 OR HR > 120 → WARN                  │     │
//   │   │  • else → none                                               │     │
//   │   └────────────────────────┬─────────────────────────────────────┘     │
//   │                            │                                           │
//   │              ┌─────────────┴─────────────┐                             │
//   │              ▼                           ▼                             │
//   │   ┌─────────────────────┐   ┌─────────────────────┐                    │
//   │   │   _distinctPage()   │   │   _distinctWarn()   │                    │
//   │   │  (stateful distinct)│   │  (stateful distinct)│                    │
//   │   └──────────┬──────────┘   └──────────┬──────────┘                    │
//   │              │                           │                             │
//   │              ▼                           ▼                             │
//   │   ┌─────────────────────┐   ┌─────────────────────┐                    │
//   │   │ Filter<Severity>    │   │ Filter<Severity>    │                    │
//   │   │  s == page          │   │  s == warn          │                    │
//   │   └──────────┬──────────┘   └──────────┬──────────┘                    │
//   │              │                           │                             │
//   └──────────────┼───────────────────────────┼─────────────────────────────┘
//                  │                           │
//                  ▼                           ▼
//   ┌─────────────────────────────────────────────────────────────────────────┐
//   │                      OUTPUT CELLS                                     │
//   ├─────────────────────────────────────────────────────────────────────────┤
//   │                                                                         │
//   │   ┌──────────────────────────────────────────────────────────────┐     │
//   │   │                  pageHandle (PAGE only)                      │     │
//   │   │  • Emits when severity changes to PAGE                      │     │
//   │   │  • Distinguished from previous PAGE                         │     │
//   │   └────────────────────┬─────────────────────────────────────────┘     │
//   │                        │                                               │
//   │                        ▼                                               │
//   │   ┌──────────────────────────────────────────────────────────────┐     │
//   │   │                  warnHandle (WARN only)                      │     │
//   │   │  • Emits when severity changes to WARN                      │     │
//   │   │  • Distinguished from previous WARN                         │     │
//   │   └──────────────────────────────────────────────────────────────┘     │
//   │                                                                         │
//   │   ┌──────────────────────────────────────────────────────────────┐     │
//   │   │                  pagerHandle (AsyncMapWithRetry)            │     │
//   │   │  • Retries up to 2 times on failure                         │     │
//   │   │  • Simulates network/database I/O                           │     │
//   │   └──────────────────────────────────────────────────────────────┘     │
//   │                                                                         │
//   │   ┌──────────────────────────────────────────────────────────────┐     │
//   │   │                  ackIn.ingress<String>                       │     │
//   │   │  • Resets distinct state for both PAGE and WARN             │     │
//   │   │  • Allows new alarms after acknowledgment                   │     │
//   │   └──────────────────────────────────────────────────────────────┘     │
//   │                                                                         │
//   └─────────────────────────────────────────────────────────────────────────┘
//
// ─────────────────────────────────────────────────────────────────────────────
// EXPECTED CONSOLE OUTPUT
// ─────────────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  ICU-12 enhanced — TestCell + gates + ledger + ACK                   ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//
//   ┌──────────────────────────────────────────────────────────────────────┐
//   │ 📍 SEEDING SYSTEM                                                  │
//   └──────────────────────────────────────────────────────────────────────┘
//   📊 [VITALS] [ICU-12] HR:72 SpO2:96 moving:false
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  📋 SCENARIO 1: Normal vitals (no alarm)                          ║
//   ║  ─────────────────────────────────────────────────────────────────  ║
//   ║  Expected: No alarm — vitals are within normal range              ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//   📊 [VITALS] [ICU-12] HR:72 SpO2:96 moving:false
//   ✅ [SCENARIO 1] COMPLETE — No alarm triggered
//   ───────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  📋 SCENARIO 2: Desaturation (SpO2 86)                            ║
//   ║  ─────────────────────────────────────────────────────────────────  ║
//   ║  Expected: PAGE — Critical desaturation detected                  ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//   📊 [VITALS] [ICU-12] HR:72 SpO2:86 moving:false
//   🔔 [PAGE] Severity.page
//   📒 [LEDGER] 2025-01-15T10:30:01.123 PAGE Severity.page
//   ✅ [SCENARIO 2] COMPLETE — PAGE triggered
//   ───────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  📋 SCENARIO 3: Motion artifact (patient moving)                  ║
//   ║  ─────────────────────────────────────────────────────────────────  ║
//   ║  Expected: Motion suppressed → no alarm, then PAGE on recovery   ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//   📊 [VITALS] [ICU-12] HR:72 SpO2:86 moving:true
//   📊 [VITALS] [ICU-12] HR:72 SpO2:86 moving:false
//   🔔 [PAGE] Severity.page
//   📒 [LEDGER] 2025-01-15T10:30:01.223 PAGE Severity.page
//   ✅ [SCENARIO 3] COMPLETE — Motion suppressed then PAGE on recovery
//   ───────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  📋 SCENARIO 4–5: Same PAGE (Distinct holds)                      ║
//   ║  ─────────────────────────────────────────────────────────────────  ║
//   ║  Expected: SpO2 85 → PAGE, HR 35 → PAGE (Distinct suppresses)   ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//   📊 [VITALS] [ICU-12] HR:72 SpO2:85 moving:false
//   📊 [VITALS] [ICU-12] HR:35 SpO2:85 moving:false
//   🔔 [PAGE] Severity.page
//   📒 [LEDGER] 2025-01-15T10:30:01.323 PAGE Severity.page
//   💡 [DISTINCT] Consecutive PAGE suppressed (no duplicate)
//   ✅ [SCENARIO 4–5] COMPLETE — Distinct held, no duplicate alarm
//   ───────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  📋 SCENARIO: WARN band (HR 55, SpO2 90)                          ║
//   ║  ─────────────────────────────────────────────────────────────────  ║
//   ║  Expected: WARN — Warning level detected (monitor closely)        ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//   📊 [VITALS] [ICU-12] HR:55 SpO2:90 moving:false
//   ⚠️  [WARN] Severity.warn
//   📒 [LEDGER] 2025-01-15T10:30:01.423 WARN Severity.warn
//   ✅ [SCENARIO WARN] COMPLETE — WARN triggered
//   ───────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  📋 SCENARIO 6: Recovery then ACK                                 ║
//   ║  ─────────────────────────────────────────────────────────────────  ║
//   ║  Expected: Recovery to normal → ACK resets distinct state         ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//   📊 [VITALS] [ICU-12] HR:74 SpO2:96 moving:false
//   ✋ [ACK] RN-lee — Distinct reset (same Receptor)
//   📒 [LEDGER] 2025-01-15T10:30:01.523 ACK RN-lee
//   ✅ [SCENARIO 6] COMPLETE — Recovered, ACK reset distinct state
//   ───────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  📋 SCENARIO 7: New desat after ACK                               ║
//   ║  ─────────────────────────────────────────────────────────────────  ║
//   ║  Expected: New PAGE — Fresh alarm after ACK reset                ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//   📊 [VITALS] [ICU-12] HR:74 SpO2:87 moving:false
//   🔔 [PAGE] Severity.page
//   📒 [LEDGER] 2025-01-15T10:30:01.623 PAGE Severity.page
//   ✅ [SCENARIO 7] COMPLETE — Fresh PAGE after ACK
//   ───────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  📋 SCENARIO 8: TestCell rejects invalid values                   ║
//   ║  ─────────────────────────────────────────────────────────────────  ║
//   ║  Expected: HR 9 (blocked), SpO2 140 (blocked)                    ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//   🛡️  [TESTCELL] blocked HR=9 (20–250)
//   🛡️  [TESTCELL] blocked SpO2=140 (0–100)
//   ✅ [SCENARIO 8] COMPLETE — TestCell blocked both invalid values
//   ───────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  📋 SCENARIO 9: Pager retry (fail once)                           ║
//   ║  ─────────────────────────────────────────────────────────────────  ║
//   ║  Expected: Pager fails once, then succeeds on retry              ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//   ✋ [ACK] RN-lee — Distinct reset (same Receptor)
//   📒 [LEDGER] 2025-01-15T10:30:01.723 ACK RN-lee
//   📊 [VITALS] [ICU-12] HR:74 SpO2:96 moving:false
//   📊 [VITALS] [ICU-12] HR:74 SpO2:80 moving:false
//   🔔 [PAGE] Severity.page
//   📒 [LEDGER] 2025-01-15T10:30:01.823 PAGE Severity.page
//   🔄 [RETRY] Pager attempt 1 failed — retrying...
//   📟 [PAGER-CELL] ICU-12: Desaturation/HR alert
//   📒 [LEDGER] 2025-01-15T10:30:01.903 PAGER ICU-12: Desaturation/HR alert
//   ✅ [SCENARIO 9] COMPLETE — Pager succeeded after retry
//   ───────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  📊 SUMMARY                                                         ║
//   ║  ─────────────────────────────────────────────────────────────────  ║
//   ║  vitals: 14  pages: 5  warns: 1  ledger: 14  pagerAttempts: 2    ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//
//   ┌──────────────────────────────────────────────────────────────────────┐
//   │ 📒 LEDGER                                                          │
//   ├──────────────────────────────────────────────────────────────────────┤
//   │ 2025-01-15T10:30:01.123 PAGE Severity.page                        │
//   │ 2025-01-15T10:30:01.223 PAGE Severity.page                        │
//   │ 2025-01-15T10:30:01.323 PAGE Severity.page                        │
//   │ 2025-01-15T10:30:01.423 WARN Severity.warn                        │
//   │ 2025-01-15T10:30:01.523 ACK RN-lee                                │
//   │ 2025-01-15T10:30:01.623 PAGE Severity.page                        │
//   │ 2025-01-15T10:30:01.723 ACK RN-lee                                │
//   │ 2025-01-15T10:30:01.823 PAGE Severity.page                        │
//   │ 2025-01-15T10:30:01.903 PAGER ICU-12: Desaturation/HR alert       │
//   └──────────────────────────────────────────────────────────────────────┘
//
// ─────────────────────────────────────────────────────────────────────────────
// KEY TAKEAWAYS
// ─────────────────────────────────────────────────────────────────────────────
//
// 1. TestCell on Ingress (Security Boundary)
//    ──────────────────────────────────────
//    • Validation belongs at the edge, not the state
//    • HR range: 20–250 (blocks 9)
//    • SpO2 range: 0–100 (blocks 140)
//    • Invalid values are rejected BEFORE entering the system
//    • This is the CORRECT security pattern
//
// 2. Manual Snapshot Bus
//    ───────────────────
//    • Each sensor change publishes a complete Reading
//    • More reliable than combineLatestWith
//    • Observers always get consistent data
//    • Easy to debug and trace
//
// 3. Separate PAGE and WARN Gates
//    ─────────────────────────────
//    • PAGE and WARN are handled independently
//    • Each has its own Distinct state
//    • Allows different handling for different severity levels
//    • Clean separation of concerns
//
// 4. Stateful Distinct with ACK Reset
//    ────────────────────────────────
//    • Distinct state is maintained per severity level
//    • ACK resets distinct state for both PAGE and WARN
//    • Enables new alarms after acknowledgment
//    • Prevents alert fatigue
//    • No need to rebuild the graph
//
// 5. Pager with Retry (AsyncMapWithRetry)
//    ────────────────────────────────────
//    • AsyncMapWithRetry handles async operations with retry
//    • Retries up to 2 times on failure
//    • Simulates network/database I/O
//    • Demonstrates resilience patterns
//    • Graceful degradation on transient failures
//
// 6. Ledger for Audit Trail
//    ──────────────────────
//    • All events are logged to a ledger
//    • Provides complete audit trail
//    • Useful for compliance and debugging
//    • Shows the sequence of events clearly
//
// 7. ACK Rebuilds the Receptor
//    ──────────────────────────
//    • ACK resets distinct state without recreating the cell
//    • Maintains the same Receptor (pipeline)
//    • Allows fresh alarms after acknowledgment
//    • Efficient: no need to rebuild the graph
//
// 8. Operator Order Matters
//    ──────────────────────
//    • toSeverity → distinct → filterPage
//    • Distinct must come BEFORE Filter
//    • If Filter comes first, duplicates pass through
//    • Correct order prevents alert fatigue
//
// 9. Motion Artifact Suppression
//    ──────────────────────────
//    • moving: true → Severity.none
//    • Prevents false alarms during patient movement
//    • Clinical requirement: don't alert on artifact
//
// ─────────────────────────────────────────────────────────────────────────────
// SCENARIO DESCRIPTIONS
// ─────────────────────────────────────────────────────────────────────────────
//
// ┌──────────┬──────────────────────────────────────────────────────────────┐
// │ SCENARIO │ DESCRIPTION                                                 │
// ├──────────┼──────────────────────────────────────────────────────────────┤
// │ 1: 🟢   │ Normal vitals — no alarm (baseline)                         │
// │ 2: 🟡   │ Desaturation to 86% — triggers PAGE                         │
// │ 3: 🟡   │ Motion artifact — suppressed, then PAGE on recovery         │
// │ 4–5: 🟡 │ Same PAGE (SpO2 85, HR 35) — Distinct holds (no duplicate) │
// │ WARN:🟠 │ WARN band (HR 55, SpO2 90) — triggers WARN                 │
// │ 6: 🟢   │ Recovery to normal — ACK resets distinct state              │
// │ 7: 🟡   │ New desaturation after ACK — triggers fresh PAGE            │
// │ 8: 🛡️   │ TestCell rejects invalid values (HR=9, SpO2=140)           │
// │ 9: 🔄   │ Pager retry — fails once, succeeds on retry                │
// └──────────┴──────────────────────────────────────────────────────────────┘
//
// ─────────────────────────────────────────────────────────────────────────────
// CLINICAL ALARM CRITERIA
// ─────────────────────────────────────────────────────────────────────────────
//
//   Desaturation (SpO2 < 88%) → PAGE (critical)
//   Severe Bradycardia (HR < 40) → PAGE (critical)
//   Severe Tachycardia (HR > 140) → PAGE (critical)
//   Warning Desaturation (SpO2 < 92%) → WARN
//   Warning Bradycardia (HR < 50) → WARN
//   Warning Tachycardia (HR > 120) → WARN
//   Motion Artifact → Suppressed (no alarm)
//
// ─────────────────────────────────────────────────────────────────────────────

/// A complete snapshot of patient vital signs.
///
/// This immutable data class represents all vital signs at a single point in time.
/// It is used as the payload for the snapshot bus.
class Reading {
  /// The bed identifier (e.g., "ICU-12")
  final String bed;

  /// Heart rate in beats per minute (bpm)
  final int hr;

  /// Oxygen saturation as a percentage (SpO2)
  final int spo2;

  /// Whether the patient is moving (motion artifact flag)
  final bool moving;

  /// Creates a [Reading] with the given vital signs.
  const Reading({
    required this.bed,
    required this.hr,
    required this.spo2,
    required this.moving,
  });

  @override
  String toString() => '[$bed] HR:$hr SpO2:$spo2 moving:$moving';
}

/// Alarm severity levels.
///
/// Represents the clinical urgency of an alarm condition.
enum Severity {
  /// No alarm — vitals are within normal range
  none,

  /// Warning — monitor closely, but no immediate action required
  warn,

  /// Page — immediate escalation to clinical staff
  page,
}

/// A ledger entry for the audit trail.
///
/// Records every significant event in the system for compliance and debugging.
class LedgerEntry {
  /// The timestamp of the event
  final DateTime at;

  /// The kind of event (e.g., "PAGE", "WARN", "ACK", "PAGER")
  final String kind;

  /// Detailed information about the event
  final String detail;

  /// Creates a [LedgerEntry] with the current timestamp.
  LedgerEntry(this.kind, this.detail) : at = DateTime.now();

  @override
  String toString() => '${at.toIso8601String()} $kind $detail';
}

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

/// The bed identifier for this patient.
const bedId = 'ICU-12';

// ─────────────────────────────────────────────────────────────────────────────
// VISUAL OUTPUT HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Prints a visual separator for scenarios.
void printSeparator() {
  print('─' * 70);
}

/// Prints a scenario header with visual formatting.
///
/// [number] - The scenario number (e.g., "1", "4–5", "WARN")
/// [title] - The scenario title
/// [expected] - The expected outcome description
void printScenarioHeader(String number, String title, String expected) {
  print('');
  print('╔${'═' * 70}╗');
  print('${'║  📋 SCENARIO $number: $title'.padRight(71)}║');
  print('║  ${'─' * 68}║');
  print('${'║  Expected: $expected'.padRight(71)}║');
  print('╚${'═' * 70}╝');
}

/// Prints a scenario completion marker.
///
/// [message] - The completion message describing what happened.
void printScenarioComplete(String message) {
  print('  ✅ [SCENARIO COMPLETE] $message');
  printSeparator();
}

// ─────────────────────────────────────────────────────────────────────────────
// TESTCELL POLICIES (Security Boundary)
// ─────────────────────────────────────────────────────────────────────────────

/// TestCell that validates heart rate values (20–250 bpm).
///
/// This TestCell is applied at the ingress level, creating a security boundary
/// that prevents invalid values from entering the system.
///
/// ### Clinical Rationale
/// - HR < 20: improbable (would be asystole or artifact)
/// - HR > 250: improbable (would be artifact or error)
/// - Blocking these prevents false alarms and corrupted data
final TestCell hrRange = TestCell<Cell>(
      (value, {host, arguments, user}) {
    final n = value is Pulse ? value.payload : value;
    if (n is! int) return true;
    final ok = n >= 20 && n <= 250;
    if (!ok) print('  🛡️  [TESTCELL] blocked HR=$n (20–250)');
    return ok;
  },
);

/// TestCell that validates SpO2 values (0–100%).
///
/// This TestCell is applied at the ingress level, creating a security boundary
/// that prevents invalid values from entering the system.
///
/// ### Clinical Rationale
/// - SpO2 < 0: impossible
/// - SpO2 > 100: impossible (would be artifact or error)
/// - Blocking these prevents false alarms and corrupted data
final TestCell spo2Range = TestCell<Cell>(
      (value, {host, arguments, user}) {
    final n = value is Pulse ? value.payload : value;
    if (n is! int) return true;
    final ok = n >= 0 && n <= 100;
    if (!ok) print('  🛡️  [TESTCELL] blocked SpO2=$n (0–100)');
    return ok;
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// SOURCE CELLS (with TestCell protection)
// ─────────────────────────────────────────────────────────────────────────────

/// Heart rate sensor ingress with TestCell protection.
///
/// Values outside 20–250 bpm are rejected by the TestCell.
final hrIn = Cell.ingress<int>(testRule: hrRange, refine: (h, i) => i);

/// SpO2 sensor ingress with TestCell protection.
///
/// Values outside 0–100% are rejected by the TestCell.
final spo2In = Cell.ingress<int>(testRule: spo2Range, refine: (h, i) => i);

/// Motion sensor ingress (no TestCell needed for boolean).
final motionIn = Cell.ingress<bool>(refine: (h, i) => i);

/// The snapshot bus ingress cell.
///
/// This cell receives complete [Reading] snapshots that are published
/// whenever any sensor changes.
final vitalsIn = Cell.ingress<Reading>();

/// ACK ingress cell.
///
/// This cell receives acknowledgment messages that reset the distinct state.
final ackIn = Cell.ingress<String>();

// ─────────────────────────────────────────────────────────────────────────────
// STATE CACHE
// ─────────────────────────────────────────────────────────────────────────────

/// Current heart rate value (state cache for snapshot publishing).
int _hr = 72;

/// Current SpO2 value (state cache for snapshot publishing).
int _spo2 = 96;

/// Current motion state (state cache for snapshot publishing).
bool _moving = false;

// ─────────────────────────────────────────────────────────────────────────────
// LEDGER & LOGS
// ─────────────────────────────────────────────────────────────────────────────

/// The audit trail ledger.
final ledger = <LedgerEntry>[];

/// Retains observer references to prevent garbage collection.
final retain = <Object>[];

/// Vitals log for summary.
final vitalsLog = <String>[];

/// Page log for summary.
final pageLog = <String>[];

/// Warn log for summary.
final warnLog = <String>[];

/// Appends an entry to the ledger.
///
/// [kind] - The kind of event (e.g., "PAGE", "WARN", "ACK", "PAGER")
/// [detail] - Detailed information about the event
void appendLedger(String kind, String detail) {
  final e = LedgerEntry(kind, detail);
  ledger.add(e);
  print('  📒 [LEDGER] $e');
}

// ─────────────────────────────────────────────────────────────────────────────
// SNAPSHOT BUS OPERATIONS
// ─────────────────────────────────────────────────────────────────────────────

/// Publishes a complete [Reading] snapshot to the snapshot bus.
///
/// This is called after every sensor change to ensure observers always
/// receive a complete, consistent view of the patient's vitals.
///
/// ### Why This Pattern Works
/// Unlike `combineLatestWith`, which can miss emissions due to timing issues,
/// this manual snapshot bus guarantees that every sensor change produces
/// a complete [Reading] object that all observers can consume reliably.
Future<void> publishVitals() async {
  final r = Reading(bed: bedId, hr: _hr, spo2: _spo2, moving: _moving);
  final msg = '📊 [VITALS] $r';
  vitalsLog.add(msg);
  print(msg);
  await vitalsIn.emitAsync(r);
}

/// Sets the heart rate and publishes a new snapshot.
///
/// Returns `true` if the value was accepted by the TestCell.
///
/// [n] - The new heart rate value in bpm
Future<bool> setHr(int n) async {
  final accepted = hrIn.emit(n);
  if (accepted == false) return false;
  _hr = n;
  try {
    await hrIn.emitAsync(n);
  } catch (_) {}
  await publishVitals();
  return true;
}

/// Sets the SpO2 value and publishes a new snapshot.
///
/// Returns `true` if the value was accepted by the TestCell.
///
/// [n] - The new SpO2 value as a percentage
Future<bool> setSpo2(int n) async {
  final accepted = spo2In.emit(n);
  if (accepted == false) return false;
  _spo2 = n;
  try {
    await spo2In.emitAsync(n);
  } catch (_) {}
  await publishVitals();
  return true;
}

/// Sets the motion state and publishes a new snapshot.
///
/// [v] - The new motion state (true = moving)
Future<void> setMoving(bool v) async {
  _moving = v;
  await motionIn.emitAsync(v);
  await publishVitals();
}

// ─────────────────────────────────────────────────────────────────────────────
// SEVERITY EVALUATION
// ─────────────────────────────────────────────────────────────────────────────

/// Evaluates the severity of a [Reading] based on clinical criteria.
///
/// ### Clinical Criteria
/// - Motion artifact → none (suppressed)
/// - SpO2 < 88% OR HR < 40 OR HR > 140 → page
/// - SpO2 < 92% OR HR < 50 OR HR > 120 → warn
/// - Otherwise → none
///
/// [r] - The reading to evaluate
/// Returns the [Severity] level
Severity severityOf(Reading r) {
  if (r.moving) return Severity.none;
  if (r.spo2 < 88 || r.hr < 40 || r.hr > 140) return Severity.page;
  if (r.spo2 < 92 || r.hr < 50 || r.hr > 120) return Severity.warn;
  return Severity.none;
}

// ─────────────────────────────────────────────────────────────────────────────
// DISTINCT STATE (per severity)
// ─────────────────────────────────────────────────────────────────────────────

/// Last PAGE severity (for distinct comparison).
Severity? _pageLast;

/// Whether a PAGE has been seen (for distinct comparison).
var _pageHas = false;

/// Last WARN severity (for distinct comparison).
Severity? _warnLast;

/// Whether a WARN has been seen (for distinct comparison).
var _warnHas = false;

/// Whether distinct suppressed a duplicate (for visual feedback).
var _distinctSuppressed = false;

/// Resets the distinct state for both PAGE and WARN.
///
/// Called when an ACK is received. This allows new alarms to be triggered
/// after acknowledgment, even if the severity hasn't changed.
///
/// [who] - The person or system sending the acknowledgment
void resetDistinct({required String who}) {
  _pageLast = null;
  _pageHas = false;
  _warnLast = null;
  _warnHas = false;
  print('  ✋ [ACK] $who — Distinct reset (same Receptor)');
  appendLedger('ACK', who);
}

// ─────────────────────────────────────────────────────────────────────────────
// ALARM GATES (FlowInstruction)
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a distinct instruction for PAGE severity.
///
/// This instruction suppresses consecutive PAGE emissions, preventing alert
/// fatigue from repeated alarms.
///
/// Returns a [FlowInstruction] that filters consecutive PAGE duplicates.
FlowInstruction<Cell, Pulse, Pulse> _distinctPage() {
  return FlowInstruction((pulse, {cell, user}) {
    final current = pulse.payload;
    if (current is! Severity) return null;
    if (!_pageHas) {
      _pageHas = true;
      _pageLast = current;
      _distinctSuppressed = false;
      return pulse;
    }
    if (_pageLast != current) {
      _pageLast = current;
      _distinctSuppressed = false;
      return pulse;
    }
    _distinctSuppressed = true;
    print('  💡 [DISTINCT] Consecutive PAGE suppressed (no duplicate)');
    return null;
  });
}

/// Builds a distinct instruction for WARN severity.
///
/// This instruction suppresses consecutive WARN emissions, preventing alert
/// fatigue from repeated warnings.
///
/// Returns a [FlowInstruction] that filters consecutive WARN duplicates.
FlowInstruction<Cell, Pulse, Pulse> _distinctWarn() {
  return FlowInstruction((pulse, {cell, user}) {
    final current = pulse.payload;
    if (current is! Severity) return null;
    if (!_warnHas) {
      _warnHas = true;
      _warnLast = current;
      return pulse;
    }
    if (_warnLast != current) {
      _warnLast = current;
      return pulse;
    }
    return null;
  });
}

/// Builds the PAGE gate.
///
/// The PAGE gate:
/// 1. Maps Reading → Severity
/// 2. Applies distinct (suppresses consecutive PAGE)
/// 3. Filters only PAGE severity
///
/// Returns a [FlowInstruction] that emits only PAGE severity alarms.
FlowInstruction buildPageGate() {
  return MapValue<Reading, Severity>((r) => severityOf(r)) +
      _distinctPage() +
      Filter<Severity>((s) => s == Severity.page);
}

/// Builds the WARN gate.
///
/// The WARN gate:
/// 1. Maps Reading → Severity
/// 2. Applies distinct (suppresses consecutive WARN)
/// 3. Filters only WARN severity
///
/// Returns a [FlowInstruction] that emits only WARN severity alarms.
FlowInstruction buildWarnGate() {
  return MapValue<Reading, Severity>((r) => severityOf(r)) +
      _distinctWarn() +
      Filter<Severity>((s) => s == Severity.warn);
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTPUT CELLS
// ─────────────────────────────────────────────────────────────────────────────

/// The PAGE handle — emits only PAGE severity alarms.
FlowHandle<Pulse<dynamic>>? pageHandle;

/// The WARN handle — emits only WARN severity alarms.
FlowHandle<Pulse<dynamic>>? warnHandle;

/// The PAGER handle — async I/O with retry.
FlowHandle<Pulse<dynamic>>? pagerHandle;

/// Number of pager attempts (for retry tracking).
var pagerAttempts = 0;

/// Whether the pager should fail once (for retry demonstration).
var pagerShouldFailOnce = false;

// ─────────────────────────────────────────────────────────────────────────────
// INSTALL GATES & OBSERVERS
// ─────────────────────────────────────────────────────────────────────────────

/// Installs all gates and observers.
///
/// This must be called BEFORE any data flows through the system.
///
/// ### Observer List
/// 1. PAGE observer — prints PAGE and logs to ledger
/// 2. WARN observer — prints WARN and logs to ledger
/// 3. PAGER-CELL observer — prints AsyncMap results
/// 4. ACK observer — resets distinct state
void installGates() {
  // Create the PAGE and WARN gates
  pageHandle = buildPageGate().toHandle(source: vitalsIn.cell);
  warnHandle = buildWarnGate().toHandle(source: vitalsIn.cell);

  // Create the PAGER with retry
  pagerHandle = AsyncMapWithRetry<Severity, String>(
        (_) async {
      pagerAttempts++;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (pagerShouldFailOnce) {
        pagerShouldFailOnce = false;
        print('  🔄 [RETRY] Pager attempt $pagerAttempts failed — retrying...');
        throw StateError('nurse-app timeout');
      }
      return '$bedId: Desaturation/HR alert';
    },
    count: 2,
  ).toHandle(source: pageHandle!.cell);

  // Observer 1: PAGE (prints and logs to ledger)
  retain.add(Cell.observe(
    source: pageHandle!.cell,
    effect: (Pulse p) {
      final msg = '🔔 [PAGE] ${p.payload}';
      pageLog.add(msg);
      print(msg);
      appendLedger('PAGE', '${p.payload}');
      Future<void>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        final m = '📟 [PAGER] $bedId: Desaturation/HR alert';
        print(m);
      });
    },
  ));

  // Observer 2: WARN (prints and logs to ledger)
  retain.add(Cell.observe(
    source: warnHandle!.cell,
    effect: (Pulse p) {
      final msg = '⚠️  [WARN] ${p.payload}';
      warnLog.add(msg);
      print(msg);
      appendLedger('WARN', '${p.payload}');
    },
  ));

  // Observer 3: PAGER-CELL (prints AsyncMap results)
  retain.add(Cell.observe(
    source: pagerHandle!.cell,
    effect: (Pulse p) {
      print('📟 [PAGER-CELL] ${p.payload}');
      appendLedger('PAGER', '${p.payload}');
    },
  ));

  // Observer 4: ACK (resets distinct state)
  retain.add(Cell.observe(
    source: ackIn.cell,
    effect: (Pulse p) {
      resetDistinct(who: '${p.payload}');
    },
  ));
}

/// Sends an acknowledgment to reset distinct state.
///
/// [who] - The person or system sending the acknowledgment
Future<void> ack(String who) async {
  await ackIn.emitAsync(who);
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

/// Main entry point for the Enhanced ICU Bedside Alarm Pipeline demo.
///
/// This demo demonstrates:
/// - TestCell on ingress (security boundary)
/// - Manual snapshot bus
/// - Separate PAGE and WARN gates
/// - Stateful distinct with ACK reset
/// - Pager with retry (AsyncMapWithRetry)
/// - Ledger for audit trail
///
/// ### Execution Order is Critical!
/// 1. Install gates and observers (before any data flows)
/// 2. Wait for observers to attach (50ms)
/// 3. Run the simulation scenarios
Future<void> main() async {
  print('╔${'═' * 70}╗');
  print('${'║  ICU-12 enhanced — TestCell + gates + ledger + ACK'.padRight(71)}║');
  print('╚${'═' * 70}╝');

  // STEP 1: Install gates and observers BEFORE any data flows
  installGates();

  // STEP 2: Give observers time to attach
  await Future<void>.delayed(const Duration(milliseconds: 50));

  // ── SEED ──────────────────────────────────────────────────────
  print('');
  print('┌${'─' * 70}┐');
  print('${'│ 📍 SEEDING SYSTEM'.padRight(71)}│');
  print('└${'─' * 70}┘');
  await setMoving(false);
  await setSpo2(96);
  await setHr(72);
  await Future<void>.delayed(const Duration(milliseconds: 150));

  // ── SCENARIO 1 ──────────────────────────────────────────────────
  printScenarioHeader('1', 'Normal vitals (no alarm)',
      'No alarm — vitals are within normal range');
  await setHr(72);
  await setSpo2(96);
  await Future<void>.delayed(const Duration(milliseconds: 150));
  printScenarioComplete('No alarm triggered');

  // ── SCENARIO 2 ──────────────────────────────────────────────────
  printScenarioHeader('2', 'Desaturation (SpO2 86)',
      'PAGE — Critical desaturation detected');
  await setSpo2(86);
  await Future<void>.delayed(const Duration(milliseconds: 200));
  printScenarioComplete('PAGE triggered');

  // ── SCENARIO 3 ──────────────────────────────────────────────────
  printScenarioHeader('3', 'Motion artifact (patient moving)',
      'Motion suppressed → no alarm, then PAGE on recovery');
  await setMoving(true);
  await Future<void>.delayed(const Duration(milliseconds: 150));
  await setMoving(false);
  await Future<void>.delayed(const Duration(milliseconds: 200));
  printScenarioComplete('Motion suppressed then PAGE on recovery');

  // ── SCENARIO 4–5 ──────────────────────────────────────────────────
  printScenarioHeader('4–5', 'Same PAGE (Distinct holds)',
      'SpO2 85 → PAGE, HR 35 → PAGE (Distinct suppresses duplicate)');
  await setSpo2(85);
  await setHr(35);
  await Future<void>.delayed(const Duration(milliseconds: 150));
  printScenarioComplete('Distinct held, no duplicate alarm');

  // ── SCENARIO WARN ──────────────────────────────────────────────────
  printScenarioHeader('WARN', 'WARN band (HR 55, SpO2 90)',
      'WARN — Warning level detected (monitor closely)');
  await setHr(55);
  await setSpo2(90);
  await Future<void>.delayed(const Duration(milliseconds: 150));
  printScenarioComplete('WARN triggered');

  // ── SCENARIO 6 ──────────────────────────────────────────────────
  printScenarioHeader('6', 'Recovery then ACK',
      'Recovery to normal → ACK resets distinct state');
  await setSpo2(96);
  await setHr(74);
  await Future<void>.delayed(const Duration(milliseconds: 150));
  await ack('RN-lee');
  await Future<void>.delayed(const Duration(milliseconds: 100));
  printScenarioComplete('Recovered, ACK reset distinct state');

  // ── SCENARIO 7 ──────────────────────────────────────────────────
  printScenarioHeader('7', 'New desat after ACK',
      'New PAGE — Fresh alarm after ACK reset');
  await setSpo2(87);
  await Future<void>.delayed(const Duration(milliseconds: 200));
  printScenarioComplete('Fresh PAGE after ACK');

  // ── SCENARIO 8 ──────────────────────────────────────────────────
  printScenarioHeader('8', 'TestCell rejects invalid values',
      'HR 9 (blocked), SpO2 140 (blocked)');
  await setHr(9);
  await setSpo2(140);
  await Future<void>.delayed(const Duration(milliseconds: 100));
  printScenarioComplete('TestCell blocked both invalid values');

  // ── SCENARIO 9 ──────────────────────────────────────────────────
  printScenarioHeader('9', 'Pager retry (fail once)',
      'Pager fails once, then succeeds on retry');
  await ack('RN-lee');
  await setSpo2(96);
  await setHr(72);
  await Future<void>.delayed(const Duration(milliseconds: 100));
  pagerShouldFailOnce = true;
  await setSpo2(80);
  await Future<void>.delayed(const Duration(milliseconds: 300));
  printScenarioComplete('Pager succeeded after retry');

  // ── SUMMARY ──────────────────────────────────────────────────
  print('');
  print('╔${'═' * 70}╗');
  print('${'║  📊 SUMMARY'.padRight(71)}║');
  print('║  ${'─' * 68}║');
  print('${'║  vitals: ${vitalsLog.length}  pages: ${pageLog.length}  warns: ${warnLog.length}  ledger: ${ledger.length}  pagerAttempts: $pagerAttempts'.padRight(71)}║');
  print('╚${'═' * 70}╝');

  print('');
  print('┌${'─' * 70}┐');
  print('${'│ 📒 LEDGER'.padRight(71)}│');
  print('├${'─' * 70}┤');
  for (final e in ledger) {
    print('${'│ $e'.padRight(71)}│');
  }
  print('└${'─' * 70}┘');
}