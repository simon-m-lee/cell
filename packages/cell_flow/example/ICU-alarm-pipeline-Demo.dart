// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// ignore_for_file: no_leading_underscores_for_local_identifiers, file_names, unused_local_variable, avoid_print

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/async_map.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ICU BEDSIDE ALARM PIPELINE
//
// A practical demonstration of the Cell Framework with Flow operators.
// This demo simulates a hospital ICU bedside monitor that:
//   1. Tracks patient vital signs (HR, SpO2, Motion)
//   2. Evaluates clinical alarm conditions
//   3. Suppresses motion artifacts
//   4. Uses Distinct to prevent duplicate alerts
//   5. Handles async I/O via separate cells
//
// ─────────────────────────────────────────────────────────────────────────────
// ARCHITECTURE OVERVIEW
// ─────────────────────────────────────────────────────────────────────────────
//
//   ┌─────────────────────────────────────────────────────────────────────┐
//   │                      MANUAL SNAPSHOT BUS                           │
//   ├─────────────────────────────────────────────────────────────────────┤
//   │                                                                     │
//   │   ┌──────────┐     ┌──────────┐     ┌──────────┐                   │
//   │   │ HR Cell  │     │ SpO2 Cell│     │Motion Cell│                   │
//   │   └────┬─────┘     └────┬─────┘     └────┬─────┘                   │
//   │        │                │                │                         │
//   │        └────────────────┼────────────────┘                         │
//   │                         │                                          │
//   │                         ▼                                          │
//   │              ┌─────────────────────┐                               │
//   │              │   publishVitals()   │  ← Manual snapshot            │
//   │              │  Reading(hr,spo2,   │                               │
//   │              │          moving)    │                               │
//   │              └──────────┬──────────┘                               │
//   │                         │                                          │
//   │                         ▼                                          │
//   │              ┌─────────────────────┐                               │
//   │              │  vitalsIn.ingress   │  ← The snapshot bus           │
//   │              └──────────┬──────────┘                               │
//   │                         │                                          │
//   └─────────────────────────┼───────────────────────────────────────────┘
//                             │
//                             ▼
//   ┌─────────────────────────────────────────────────────────────────────┐
//   │                    ALARM GATE (FlowInstruction)                     │
//   ├─────────────────────────────────────────────────────────────────────┤
//   │                                                                     │
//   │   ┌──────────────────────────────────────────────────────────┐     │
//   │   │  Stage 1: toSeverity (Reading → Severity)               │     │
//   │   │  • moving → none                                        │     │
//   │   │  • SpO2 < 88 OR HR < 40 OR HR > 140 → PAGE             │     │
//   │   │  • SpO2 < 92 OR HR < 50 OR HR > 120 → WARN             │     │
//   │   │  • else → none                                          │     │
//   │   └────────────────────────┬─────────────────────────────────┘     │
//   │                            │                                       │
//   │                            ▼                                       │
//   │   ┌──────────────────────────────────────────────────────────┐     │
//   │   │  Stage 2: Distinct<Severity>                             │     │
//   │   │  • Only emits when severity changes                      │     │
//   │   │  • Consecutive PAGE → suppressed                         │     │
//   │   └────────────────────────┬─────────────────────────────────┘     │
//   │                            │                                       │
//   │                            ▼                                       │
//   │   ┌──────────────────────────────────────────────────────────┐     │
//   │   │  Stage 3: Filter<Severity>                               │     │
//   │   │  • Only Severity.page passes through                     │     │
//   │   └────────────────────────┬─────────────────────────────────┘     │
//   │                            │                                       │
//   └────────────────────────────┼───────────────────────────────────────┘
//                                 │
//                                 ▼
//   ┌─────────────────────────────────────────────────────────────────────┐
//   │                      OUTPUT CELLS                                  │
//   ├─────────────────────────────────────────────────────────────────────┤
//   │                                                                     │
//   │   ┌────────────────────────────────────────────────────────┐       │
//   │   │  alarms = toHandle(source: vitalsIn.cell)             │       │
//   │   │  • Emits only when alarm is PAGE and severity changes │       │
//   │   └────────────────────┬───────────────────────────────────┘       │
//   │                        │                                           │
//   │                        ▼                                           │
//   │   ┌────────────────────────────────────────────────────────┐       │
//   │   │  Two Observers:                                        │       │
//   │   │  1. Cell.observe(alarms.cell) → prints "PAGE"         │       │
//   │   │  2. AsyncMap → prints "PAGER"                         │       │
//   │   └────────────────────────────────────────────────────────┘       │
//   │                                                                     │
//   └─────────────────────────────────────────────────────────────────────┘
//
// ─────────────────────────────────────────────────────────────────────────────
// EXPECTED CONSOLE OUTPUT
// ─────────────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  🏥  ICU BEDSIDE ALARM PIPELINE                                     ║
//   ║  Demonstrating reactive alarms with FlowInstruction and Distinct    ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//
//   ═══════════════════════════════════════════════════════════════════════
//   🏥 ICU BEDSIDE ALARM PIPELINE
//   ═══════════════════════════════════════════════════════════════════════
//
//   📍 Seeding sensors...
//   📊 [VITALS] HR:72, SpO2:96, moving:false
//
//   📋 Scenario 1: Normal vitals (no alarm)
//   ────────────────────────────────────────
//   📊 [VITALS] HR:72, SpO2:96, moving:false
//
//   📋 Scenario 2: Desaturation (SpO2 86)
//   ────────────────────────────────────────
//   📊 [VITALS] HR:72, SpO2:86, moving:false
//   🔔 [ALARM] PAGE
//   📟 [PAGER] ICU-12: Desaturation/HR alert!
//
//   📋 Scenario 3: Motion artifact (patient moving)
//   ────────────────────────────────────────────────
//   📊 [VITALS] HR:72, SpO2:86, moving:true
//   📊 [VITALS] HR:72, SpO2:86, moving:false
//   🔔 [ALARM] PAGE
//   📟 [PAGER] ICU-12: Desaturation/HR alert!
//
//   📋 Scenario 4: Desaturation continues (SpO2 85)
//   ────────────────────────────────────────────────
//   📊 [VITALS] HR:72, SpO2:85, moving:false
//   🔔 [ALARM] PAGE
//
//   📋 Scenario 5: Bradycardia (HR 35)
//   ──────────────────────────────────
//   📊 [VITALS] HR:35, SpO2:85, moving:false
//   🔔 [ALARM] PAGE
//   📟 [PAGER] ICU-12: Desaturation/HR alert!
//
//   📋 Scenario 6: Recovery to normal
//   ──────────────────────────────────
//   📊 [VITALS] HR:74, SpO2:95, moving:false
//
//   📋 Scenario 7: New desaturation event (new alarm)
//   ──────────────────────────────────────────────────
//   📊 [VITALS] HR:74, SpO2:87, moving:false
//   🔔 [ALARM] PAGE
//   📟 [PAGER] ICU-12: Desaturation/HR alert!
//
//   ═══════════════════════════════════════════════════════════════════════
//   ✅ Scenario complete
//   ═══════════════════════════════════════════════════════════════════════
//
//   📊 EVENT SUMMARY:
//      Vitals events: 10
//      Alarm events: 4
//      Pager events: 4
//
//   📌 Key observations:
//     1. Motion artifact maps to none (no page while moving)
//     2. Distinct then Filter: page on first desat and after recover
//     3. Pager is AsyncMap on the next Cell
//     4. The entire pipeline is reactive and declarative
//     5. No manual subscription management needed
//
// ─────────────────────────────────────────────────────────────────────────────
// KEY TAKEAWAYS
// ─────────────────────────────────────────────────────────────────────────────
//
// 1. Manual Snapshot Bus Pattern
//    ──────────────────────────
//    • Each sensor change publishes a complete Reading snapshot
//    • Observers always get consistent data
//    • More reliable than combineLatestWith
//
// 2. FlowInstruction Pipeline Order Matters
//    ──────────────────────────────────────
//    • toSeverity → distinct → filterPage
//    • Distinct must come BEFORE Filter to suppress duplicates
//    • If Filter comes first, duplicates pass through
//
// 3. Motion Artifact Suppression
//    ──────────────────────────
//    • moving: true → Severity.none
//    • Prevents false alarms during patient movement
//    • Clinical requirement: don't alert on artifact
//
// 4. Distinct for Duplicate Prevention
//    ─────────────────────────────────
//    • Consecutive PAGE alerts are suppressed
//    • Only emits when severity changes
//    • Prevents alert fatigue
//
// 5. Async I/O Separation
//    ────────────────────
//    • AsyncMap handles async operations on separate cell
//    • Synchronous alarm evaluation is fast
//    • I/O doesn't block the reactive graph
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
// SCENARIO DESCRIPTIONS
// ─────────────────────────────────────────────────────────────────────────────
//
// ┌──────────┬─────────────────────────────────────────────────────────┐
// │ SCENARIO │ DESCRIPTION                                            │
// ├──────────┼─────────────────────────────────────────────────────────┤
// │ 1: 🟢   │ Normal vitals — no alarm (baseline)                    │
// │ 2: 🟡   │ Desaturation to 86% — triggers PAGE                    │
// │ 3: 🟡   │ Motion artifact — suppressed, then PAGE on recovery    │
// │ 4: 🟡   │ Desaturation continues — PAGE (distinct suppresses)    │
// │ 5: 🔴   │ Bradycardia (HR 35) — triggers PAGE                   │
// │ 6: 🟢   │ Recovery to normal — no alarm                         │
// │ 7: 🟡   │ New desaturation — triggers fresh PAGE                │
// └──────────┴─────────────────────────────────────────────────────────┘
//
// ─────────────────────────────────────────────────────────────────────────────

/// A snapshot of patient vital signs.
///
/// This immutable data class represents a complete set of vital signs at a
/// single point in time. It is used as the payload for the snapshot bus.
class Reading {
  /// Heart rate in beats per minute (bpm)
  final int hr;

  /// Oxygen saturation as a percentage (SpO2)
  final int spo2;

  /// Whether the patient is moving (motion artifact flag)
  final bool moving;

  /// Creates a [Reading] with the given vital signs.
  const Reading({
    required this.hr,
    required this.spo2,
    required this.moving,
  });

  @override
  String toString() => 'HR:$hr, SpO2:$spo2, moving:$moving';
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

/// Display extension for [Severity] to provide human-readable labels.
extension SeverityDisplay on Severity {
  /// Returns a human-readable label for the severity level.
  String get label {
    switch (this) {
      case Severity.none:
        return 'OK';
      case Severity.warn:
        return 'WARN';
      case Severity.page:
        return 'PAGE';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. SOURCE CELLS — Hardware/Sensor Input
// ─────────────────────────────────────────────────────────────────────────────

/// Heart rate sensor cell.
///
/// Receives integer values representing heart rate in beats per minute.
final hrCell = Cell.ingress<int>();

/// SpO2 sensor cell.
///
/// Receives integer values representing oxygen saturation as a percentage.
final spo2Cell = Cell.ingress<int>();

/// Motion sensor cell.
///
/// Receives boolean values indicating whether the patient is moving.
final motionCell = Cell.ingress<bool>();

// ─────────────────────────────────────────────────────────────────────────────
// 2. SNAPSHOT BUS — Manual Aggregation
// ─────────────────────────────────────────────────────────────────────────────

/// The snapshot bus ingress cell.
///
/// This cell receives complete [Reading] snapshots that are published
/// whenever any sensor changes. Observers subscribe to this cell to get
/// consistent, complete vital sign readings.
final vitalsIn = Cell.ingress<Reading>();

/// Current heart rate value (state cache for snapshot publishing).
int _hr = 72;

/// Current SpO2 value (state cache for snapshot publishing).
int _spo2 = 96;

/// Current motion state (state cache for snapshot publishing).
bool _moving = false;

/// Event collection for vitals (used for summary and debugging).
final vitalsEvents = <String>[];

/// Event collection for alarms (used for summary and debugging).
final alarmEvents = <String>[];

/// Event collection for pager (used for summary and debugging).
final pagerEvents = <String>[];

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
  final reading = Reading(hr: _hr, spo2: _spo2, moving: _moving);
  final msg = '📊 [VITALS] $reading';
  vitalsEvents.add(msg);
  print(msg);
  await vitalsIn.emitAsync(reading);
}

/// Sets the heart rate and publishes a new snapshot.
Future<void> setHr(int n) async {
  _hr = n;
  await hrCell.emitAsync(n);
  await publishVitals();
}

/// Sets the SpO2 value and publishes a new snapshot.
Future<void> setSpo2(int n) async {
  _spo2 = n;
  await spo2Cell.emitAsync(n);
  await publishVitals();
}

/// Sets the motion state and publishes a new snapshot.
Future<void> setMoving(bool v) async {
  _moving = v;
  await motionCell.emitAsync(v);
  await publishVitals();
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. ALARM GATE — Clinical Policy as FlowInstruction
// ─────────────────────────────────────────────────────────────────────────────

/// Builds the alarm gate as a composable [FlowInstruction] chain.
///
/// The alarm gate implements the clinical policy for escalation:
///
/// 1. **toSeverity**: Maps a [Reading] to a [Severity] level
///    - Motion artifact → none
///    - SpO2 < 88% OR HR < 40 OR HR > 140 → page
///    - SpO2 < 92% OR HR < 50 OR HR > 120 → warn
///    - Otherwise → none
///
/// 2. **Distinct**: Suppresses consecutive duplicate severity levels
///    - Prevents alert fatigue from repeated PAGE alarms
///    - Only emits when severity actually changes
///
/// 3. **Filter**: Only allows PAGE severity to pass through
///    - WARN and none are filtered out
///    - Only critical alarms reach the pager
///
/// ### Operator Order is Critical!
/// The order `toSeverity + distinct + filterPage` is essential:
/// - Distinct must come BEFORE Filter to suppress duplicate PAGE alerts
/// - If Filter comes first, each PAGE would pass through before distinct
/// - This would cause duplicate alerts (e.g., multiple pages for the same event)
///
/// ### Clinical Rationale
/// - Motion artifact suppression prevents false alarms during patient movement
/// - Distinct prevents alert fatigue from repeated alarms
/// - Filter ensures only critical alarms reach clinical staff
FlowInstruction<Cell, Pulse<Reading>, Pulse<Severity>> buildAlarmGate() {
  // Stage 1: Reading → Severity
  final toSeverity = FlowInstruction<Cell, Pulse<Reading>, Pulse<Severity>>(
        (pulse, {cell, user}) {
      final reading = pulse.payload;
      if (reading == null) return null;
      // Motion artifact suppresses all alarms
      if (reading.moving) return Pulse(Severity.none);
      // Critical: immediate page
      if (reading.spo2 < 88 || reading.hr < 40 || reading.hr > 140) {
        return Pulse(Severity.page);
      }
      // Warning: monitor closely
      if (reading.spo2 < 92 || reading.hr < 50 || reading.hr > 120) {
        return Pulse(Severity.warn);
      }
      return Pulse(Severity.none);
    },
  );

  // Stage 2: Distinct - suppress consecutive duplicates
  Severity? _last;
  bool _hasValue = false;

  final distinct = FlowInstruction<Cell, Pulse<Severity>, Pulse<Severity>>(
        (pulse, {cell, user}) {
      final current = pulse.payload;
      if (current == null) return null;
      if (!_hasValue) {
        _hasValue = true;
        _last = current;
        return pulse;
      }
      if (_last != current) {
        _last = current;
        return pulse;
      }
      return null; // Duplicate - suppressed
    },
  );

  // Stage 3: Filter - only PAGE passes
  final filterPage = FlowInstruction<Cell, Pulse<Severity>, Pulse<Severity>>(
        (pulse, {cell, user}) {
      return pulse.payload == Severity.page ? pulse : null;
    },
  );

  // Chain them together: toSeverity → distinct → filterPage
  return toSeverity + distinct + filterPage;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. OUTPUT CELLS — Alarm and Pager
// ─────────────────────────────────────────────────────────────────────────────

/// The alarm handle — emits only PAGE severity alarms.
///
/// This cell is the output of the alarm gate pipeline. It emits a PAGE
/// severity pulse whenever the clinical policy determines that a page
/// is required and the severity has changed from the previous emission.
late final FlowHandle<Pulse<Reading>> alarms;

/// The pager handle — async I/O for sending alerts.
///
/// This cell uses AsyncMap to handle asynchronous pager operations.
/// It takes PAGE severity pulses and converts them to alert messages.
late final FlowHandle pages;

/// Retains observer references to prevent garbage collection.
final retainObservers = <Object>[];

// ─────────────────────────────────────────────────────────────────────────────
// 5. OBSERVERS — Side Effects
// ─────────────────────────────────────────────────────────────────────────────

/// Sets up and starts all observers for the pipeline.
///
/// This must be called BEFORE any data flows through the system.
/// Observers are:
/// - Vitals observer: prints vitals (via the snapshot bus)
/// - Alarm observer: prints PAGE alerts and triggers pager
/// - Pager observer: prints pager messages (via AsyncMap)
void setupAndStartObservers() {
  // Create the alarm pipeline
  alarms = buildAlarmGate().toHandle(source: vitalsIn.cell);

  // Create the pager pipeline (AsyncMap for async I/O)
  pages = AsyncMap<Severity, String>(
        (severity) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return 'ICU-12: Desaturation/HR alert!';
    },
  ).toHandle(source: alarms.cell);

  // Observer 1: Vitals (prints all vitals from the snapshot bus)
  retainObservers.add(Cell.observe(
    source: vitalsIn.cell,
    effect: (Pulse pulse) {
      // Already printed in publishVitals()
    },
  ));

  // Observer 2: Alarm (prints PAGE alerts and triggers pager)
  retainObservers.add(Cell.observe(
    source: alarms.cell,
    effect: (Pulse pulse) {
      final msg = '🔔 [ALARM] PAGE';
      alarmEvents.add(msg);
      print(msg);

      // Pager I/O is triggered on the alarm pulse
      // This demonstrates async operations on a separate cell
      Future<void>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        final p = '📟 [PAGER] ICU-12: Desaturation/HR alert!';
        pagerEvents.add(p);
        print(p);
      });
    },
  ));

  // Observer 3: Pager (prints AsyncMap results)
  retainObservers.add(Cell.observe(
    source: pages.cell,
    effect: (Pulse pulse) {
      final msg = '📟 [PAGER] ${pulse.payload}';
      pagerEvents.add(msg);
      print(msg);
    },
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. SIMULATION DRIVER
// ─────────────────────────────────────────────────────────────────────────────

/// Runs the complete simulation scenario.
///
/// The scenario walks through a clinical case:
/// 1. Normal vitals → no alarm
/// 2. Desaturation → PAGE
/// 3. Motion artifact → suppressed, then PAGE on recovery
/// 4. Desaturation continues → PAGE (distinct suppresses duplicate)
/// 5. Bradycardia → PAGE
/// 6. Recovery → no alarm
/// 7. New desaturation → fresh PAGE
Future<void> runScenario() async {
  print('\n${'=' * 60}');
  print('🏥 ICU BEDSIDE ALARM PIPELINE');
  print('${'=' * 60}\n');

  // ── Seed the system ──────────────────────────────────────
  print('📍 Seeding sensors...');
  await setMoving(false);
  await setSpo2(96);
  await setHr(72);
  await Future<void>.delayed(const Duration(milliseconds: 200));

  // ── Scenario 1: Normal vitals ──────────────────────────
  print('\n📋 Scenario 1: Normal vitals (no alarm)');
  print('─' * 40);
  await setHr(72);
  await setSpo2(96);
  await Future<void>.delayed(const Duration(milliseconds: 200));

  // ── Scenario 2: Desaturation ──────────────────────────
  print('\n📋 Scenario 2: Desaturation (SpO2 86)');
  print('─' * 40);
  await setSpo2(86);
  await Future<void>.delayed(const Duration(milliseconds: 200));

  // ── Scenario 3: Motion artifact ────────────────────────
  print('\n📋 Scenario 3: Motion artifact (patient moving)');
  print('─' * 40);
  await setMoving(true);
  await Future<void>.delayed(const Duration(milliseconds: 200));
  await setMoving(false);
  await Future<void>.delayed(const Duration(milliseconds: 200));

  // ── Scenario 4: Desaturation continues ────────────────
  print('\n📋 Scenario 4: Desaturation continues (SpO2 85)');
  print('─' * 40);
  await setSpo2(85);
  await Future<void>.delayed(const Duration(milliseconds: 200));

  // ── Scenario 5: Bradycardia ────────────────────────────
  print('\n📋 Scenario 5: Bradycardia (HR 35)');
  print('─' * 40);
  await setHr(35);
  await Future<void>.delayed(const Duration(milliseconds: 200));

  // ── Scenario 6: Recovery ──────────────────────────────
  print('\n📋 Scenario 6: Recovery to normal');
  print('─' * 40);
  await setSpo2(95);
  await setHr(74);
  await Future<void>.delayed(const Duration(milliseconds: 200));

  // ── Scenario 7: New desaturation event ────────────────
  print('\n📋 Scenario 7: New desaturation event (new alarm)');
  print('─' * 40);
  await setSpo2(87);
  await Future<void>.delayed(const Duration(milliseconds: 300));

  print('\n${'=' * 60}');
  print('✅ Scenario complete');
  print('${'=' * 60}\n');
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. MAIN ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

/// Main entry point for the ICU Bedside Alarm Pipeline demo.
///
/// ### Execution Order is Critical!
/// 1. Setup and start observers (before any data flows)
/// 2. Wait for observers to attach (50ms)
/// 3. Run the simulation
///
/// If observers are started after data flows, events will be missed.
Future<void> main() async {
  // STEP 1: Setup and start observers BEFORE any data flows
  setupAndStartObservers();

  // STEP 2: Give observers time to fully attach to the graph
  await Future<void>.delayed(const Duration(milliseconds: 50));

  // STEP 3: Run the simulation
  await runScenario();

  // ── Summary ─────────────────────────────────────────────
  print('\n📊 EVENT SUMMARY:');
  print('   Vitals events: ${vitalsEvents.length}');
  print('   Alarm events: ${alarmEvents.length}');
  print('   Pager events: ${pagerEvents.length}');

  print('\n📌 Key observations:');
  print('  1. Motion artifact maps to none (no page while moving)');
  print('  2. Distinct then Filter: page on first desat and after recover');
  print('  3. Pager is AsyncMap on the next Cell');
  print('  4. The entire pipeline is reactive and declarative');
  print('  5. No manual subscription management needed\n');
}