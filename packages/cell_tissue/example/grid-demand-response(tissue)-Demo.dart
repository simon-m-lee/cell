// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// # Grid Demand-Response — executable demonstration
///
/// **Domain:** electric power transmission — demand-response dispatch
/// (open interruptible load when system frequency sags, protect
/// hospital/critical feeders, restore after the shift-lead ACK).
///
/// **Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`.
///
/// **Status:** executable reference implementation of
/// `grid-demand-response(tissue)-WalkThrough.md`.
///
/// ---
///
/// ## The seam — Flow owns the decision, Tissue owns the books
///
/// This file exists to demonstrate **one architectural property**:
/// the reactive *decision* layer (Flow) and the reactive *ledger* layer
/// (Tissue) are separate, and they are glued together by exactly one
/// thing — an **observer** on each gate.
///
/// * Flow answers: *“Is this tick a SHED, a WARN, or a HOLD?”*
/// * Tissue answers: *“What did the books just record, and did megawatts
///   move?”*
/// * The observer is the only glue.
///
/// Nothing about the decision policy touches the reserve table. Nothing
/// about the reserve table influences the decision policy. If you find
/// yourself writing `reserveMw.set(...)` inside `actionOf`, you have
/// collapsed the seam and lost the lesson.
///
/// ---
///
/// ## Two locks, two owners
///
/// Every reactive node in this graph carries its own synchronisation
/// lock. The demo deliberately keeps **two distinct lock domains**:
///
/// | Domain | Locked by | Covers | Does not cover |
/// |---|---|---|---|
/// | **Decision** | Receptor lock on `shedCell` / `warnCell` | `actionOf`, Distinct latch, `Filter` | any Tissue write |
/// | **Books** | Tissue lock on each collection | `events.add`, `shedMap[...]`, `reserveMw.set`, `rtuQ.addLast` | any decision logic |
///
/// A SHED pulse therefore crosses **two** lock boundaries in sequence:
/// the Receptor lock releases, then the observer takes the Tissue lock.
/// That sequencing is what lets you unit-test `actionOf` with a bare
/// `BayTick` and no Tissue at all.
///
/// ---
///
/// ## TestCell vs TestTissue — do not swap
///
/// The two rule types are **not** subtypes of each other.
///
/// | Host | Rule type | Parameter |
/// |---|---|---|
/// | `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` |
/// | `TissueList` / `Set` / `Map` / `Queue` / `Value` | `TestTissue<E, C>` | `testRule:` |
/// | `tissue.deputy(...)` | `TestTissue` | `testRule:` |
///
/// `TestCell` is the integrity rule on a **Cell** (shape of an incoming
/// pulse). `TestTissue` is the integrity rule on a **Tissue** (shape of
/// a mutation, a member, a value write). Grep this file for
/// `testRule: TestCell` on any Tissue constructor: you will find zero
/// hits.
///
/// ---
///
/// ## Money-of-the-grid invariant
///
/// After every successful `applyShed` / `restore` pair, the following
/// must hold:
///
/// ```
/// reserveMw.value! + sum(shedMap.values.droppedMw) == 800
/// ```
///
/// The demo deliberately violates this **once**, in scenario 11, by
/// forcing `reserveMw` to `30` to prove the non-negative `TestTissue`
/// rejects an over-shed. Scenario 12 restores the books to a
/// self-consistent state (`80`). The header's expected-output block
/// documents this deviation.
///
/// ---
///
/// ## Documented deviations from the walkthrough
///
/// The walkthrough's prose and its sample console contradict each other
/// at three points. This demo follows the **prose** (the policy) and
/// prints the **self-consistent** numbers. Deviations:
///
/// ### (a) §2 — `HOSP-1` is held
/// The walkthrough says *“must stay hold”* in prose but its sample
/// console shows `SHED HOSP-1`. The demo correctly holds `HOSP-1`
/// because it is in the `protected` TissueSet; `actionOf` returns
/// `hold`; the SHED gate's `Filter` drops it. Console prints
/// `new sheds: 0`.
///
/// ### (b) §11–§12 — reserve cannot both be forced to 30 and restored to 800
/// The walkthrough asks to force `reserveMw` to `30` (§11) and then
/// expects `restore('INT-15')` to bring it back to `800` (§12). Those
/// cannot both be true: the restore returns exactly the `50` MW that
/// was held, so `30 → 80`. The demo prints the self-consistent value
/// and the header documents it.
///
/// ### (c) Trailer — stale counts
/// The walkthrough's trailer table lists `events=17` and
/// `rtuAttempts=5`. With the WARN RTU included and the fail-once retry
/// counted, the self-consistent values are `events=19` and
/// `rtuAttempts=6`. The demo prints the self-consistent values.
///
/// ---
///
/// ## Expected console output (self-consistent)
///
/// ```
/// ╔═══════════════════════════════════════════════════════════════════╗
/// ║  grid-demand-response(tissue)-Demo.dart                            ║
/// ║  Flow owns the shed decision. Tissue owns the feeder books.        ║
/// ╚═══════════════════════════════════════════════════════════════════╝
///
/// ── Seed ── 50.00 / INT-14 / load 420 / SOC 60
///   events.isEmpty=true
///
/// ── 1 ── repeat 50.00 / INT-14
///   new sheds: 0
///
/// ── 2 ── protected.add('HOSP-1'), then 49.70 Hz on HOSP-1
/// [protected] +HOSP-1
///   new sheds: 0
///
/// ── 3 ── 49.70 Hz on INT-14
/// [events] SHED INT-14 — 49.70Hz load=420MW
/// [rtuQ] enqueued RtuJob(INT-14, shed)
/// [events] RTU INT-14 — shed
/// [reserveMw] 800 → 750
/// [shedMap] INT-14 +50MW
///   new sheds: 1
///   rtuQ.length=1
///
/// ── 4 ── 49.70 again
///   new sheds: 0
///
/// ── 5 ── 49.72 (still shed band)
///   new sheds: 0
///
/// ── WARN ── 49.85 / SOC 10 / load 600
/// [events] WARN INT-14 — 49.85Hz SOC=10
/// [rtuQ] enqueued RtuJob(INT-14, warn)
/// [events] RTU INT-14 — warn
///   new warns: 1
///
/// ── 6 ── 50.00 then ACK restore INT-14
/// [reserveMw] 750 → 800
/// [events] RESTORE INT-14 — 50MW
///   reserveMw=800 openSheds=0
///
/// ── 7 ── 49.70 Hz on INT-14
/// [events] SHED INT-14 — 49.70Hz load=420MW
/// [rtuQ] enqueued RtuJob(INT-14, shed)
/// [events] RTU INT-14 — shed
/// [reserveMw] 800 → 750
/// [shedMap] INT-14 +50MW
///   new sheds: 1
///
/// ── 8 ── Hz 48.0, load -10, SOC 101
///   hz 48.0 accepted=false
///   load -10 accepted=false
///   soc 101 accepted=false
///   events grew: 0
///
/// ── 9 ── ACK, recover, 49.70, RTU fail-once
/// [reserveMw] 750 → 800
/// [events] RESTORE INT-14 — 50MW
/// [events] SHED INT-14 — 49.70Hz load=420MW
/// [rtuQ] enqueued RtuJob(INT-14, shed)
/// [events] RTU INT-14 — shed (retry)
/// [reserveMw] 800 → 750
/// [shedMap] INT-14 +50MW
///   new sheds: 1
///   rtuAttempts=5
///
/// ── 10 ── restore, ACK, 49.70 on INT-15
/// [reserveMw] 750 → 800
/// [events] RESTORE INT-14 — 50MW
/// [events] SHED INT-15 — 49.70Hz load=420MW
/// [rtuQ] enqueued RtuJob(INT-15, shed)
/// [events] RTU INT-15 — shed
/// [reserveMw] 800 → 750
/// [shedMap] INT-15 +50MW
///   new sheds: 1
///   openSheds=1
///
/// ── 11 ── force reserve to 30, then SHED 50
///   applyShed ok=false
///   reserveMw=30 openSheds=1
///
/// ── 12 ── restore INT-15
/// [reserveMw] 30 → 80
/// [events] RESTORE INT-15 — 50MW
///   restore ok=true
///   reserveMw=80 openSheds=0
///
/// ── 13 ── ACK without an open shed
/// [events] ACK ALL — distinct cleared
///   reserveMw=80 openSheds=0 unchanged=true
///
/// ── COMPLY ── council.add(...) blocked; length == events.length
///   council.add blocked=true
///   council.length=19 events.length=19
///
/// ─────────────────────────────────────────────────────────────────────
/// ticks=12 sheds=4 warns=1 events=19 rtuAttempts=6
/// reserveMw=80 openSheds=0
/// councilLength=19 (same as events)
/// ─────────────────────────────────────────────────────────────────────
/// ```
///
/// ---
///
/// ## Reading order
///
/// 1. `enum Action`, `final class BayTick` — the domain types.
/// 2. `GridDemandResponseHarness` — the whole demo state machine.
/// 3. `GridDemandResponseHarness.actionOf` — the pure policy (start here
///    to understand the risk model).
/// 4. `GridDemandResponseHarness.installGates` — the two Flow pipelines.
/// 5. `GridDemandResponseHarness.applyShed` / `restore` — the Tissue
///    write protocol.
/// 6. `main()` — the 13 scenarios plus COMPLY.
///
/// ---
///
/// ## See also
///
/// * `grid-demand-response(tissue)-WalkThrough.md` — the requirement.
/// * `grid-demand-response(tissue)-ARCHITECTURE.md` — the layering and ownership note.
/// * `grid-demand-response(tissue)-FEATURES.md` — operator catalogue.
/// * `card-auth-pipeline(tissue)-Demo.dart` — payments sibling.
/// * `ride-hail-dispatch(tissue)-Demo.dart` — mobility sibling.
library;

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_tissue/cell_tissue.dart';

// ignore_for_file: unused_local_variable, avoid_print, unused_element, file_names

// ═════════════════════════════════════════════════════════════════════════════
// DOMAIN
// ═════════════════════════════════════════════════════════════════════════════

/// The three possible outcomes of a demand-response decision.
///
/// `Action` is the *only* type that crosses the Flow→Tissue seam. The
/// gate Receptors produce an `Action`; the Tissue observers consume an
/// `Action` (inside a `Pulse`). Nothing else — no `BayTick`, no MW
/// figure, no feeder id string — travels along the decision path
/// unescorted.
///
/// ### Values
///
/// | Value | Meaning | Downstream effect |
/// |---|---|---|
/// | [hold] | Frequency and reserve are within safe limits | Both gates' `Filter` drop the pulse. No Tissue write. |
/// | [warn] | Frequency is in the yellow band | `warnCell` fires; the WARN observer appends a `WARN` event and enqueues an RTU job. |
/// | [shed] | Frequency is critically low | `shedCell` fires; the SHED observer appends a `SHED` event, enqueues an RTU job, and calls `applyShed`. |
///
/// ### Why not a boolean
///
/// A boolean `shouldShed` cannot express the middle band. The yellow
/// band (`49.80 ≤ Hz < 49.90`, or low SOC with high load) is a real
/// operator state — “warn the desk, do not yet open load.” Modelling
/// it as a third `Action` value keeps the two gates structurally
/// identical: each is `MapValue → Distinct → Filter(x)`.
enum Action {
  /// No action — frequency and reserve are within safe limits.
  hold,

  /// Warn — frequency is in the yellow band, prepare for shed.
  warn,

  /// Shed — frequency is critically low, open interruptible load.
  shed,
}

/// A snapshot of the grid state for a single feeder at a single tick.
///
/// `BayTick` is the payload of the **snapshot bus** (`tickIn`). Every
/// sensor change — Hz, load, SOC, feeder — republishes the whole tick,
/// so any observer on the bus always sees a *consistent* grid state.
/// This is the “one tick per snapshot” rule from the walkthrough.
///
/// ### Fields
///
/// | Field | Type | Range | Validated by |
/// |---|---|---|---|
/// | [area] | `String` | any | *(no TestCell)* |
/// | [feeder] | `String` | any | *(no TestCell)* |
/// | [hz] | `double` | `49.00 … 51.00` | `_hzRange` (TestCell) |
/// | [loadMw] | `int` | `≥ 0` | `_loadRange` (TestCell) |
/// | [soc] | `int` | `0 … 100` | `_socRange` (TestCell) |
///
/// ### Immutability
///
/// `BayTick` is `final class` with all-`final` fields. Once constructed
/// it never changes. Evolutions are expressed by publishing a new
/// `BayTick` on the bus, not by mutating an existing one.
///
/// ### See also
///
/// * [GridDemandResponseHarness.publishTick] — the factory.
/// * [GridDemandResponseHarness.actionOf] — the pure policy.
final class BayTick {
  /// The area identifier (e.g. `'NORTH'`, `'BAY'`).
  ///
  /// Free-form; not validated by a `TestCell`. Carried for correlation
  /// and future multi-area routing.
  final String area;

  /// The feeder identifier (e.g. `'INT-14'`, `'HOSP-1'`).
  ///
  /// The primary correlation key. `actionOf` reads it to check the
  /// `protected` TissueSet. The SHED / WARN observers write it into
  /// every `GridEvent` row and every `RtuJob`.
  final String feeder;

  /// The system frequency in Hz (`49.00 … 51.00`).
  ///
  /// Validated at ingress by `_hzRange`. Printed with two decimals via
  /// `_fmtHz` so `49.70` never renders as `49.7`.
  final double hz;

  /// The area load in MW (`≥ 0`).
  ///
  /// Validated at ingress by `_loadRange`. Used by `actionOf` only in
  /// the low-SOC/high-load WARN clause.
  final int loadMw;

  /// The battery state of charge (`0 … 100 %`).
  ///
  /// Validated at ingress by `_socRange`. Used by `actionOf` only in
  /// the low-SOC/high-load WARN clause.
  final int soc;

  /// Creates a [BayTick] with the given fields.
  ///
  /// All parameters are required. The constructor does **not** validate
  /// — shape validation is the job of the `TestCell` rules on the
  /// ingress Cells (`hzIn`, `loadIn`, `socIn`) and the `_hzValid` /
  /// `_loadValid` / `_socValid` pre-flight guards inside
  /// [GridDemandResponseHarness.publishTick].
  const BayTick({
    required this.area,
    required this.feeder,
    required this.hz,
    required this.loadMw,
    required this.soc,
  });

  /// A human-readable rendering.
  ///
  /// Hz is formatted via `_fmtHz` so the string is stable across runs
  /// (`49.70`, never `49.7`). This matters because the demo's console
  /// output is the acceptance criterion.
  @override
  String toString() =>
      'BayTick($area, $feeder, ${_fmtHz(hz)}Hz, ${loadMw}MW, SOC=$soc%)';
}

/// Formats a Hz reading to exactly two decimal places.
///
/// `double.toString()` in Dart drops trailing zeros, so `49.70` prints
/// as `49.7`. The demo's console output is part of its contract, so a
/// stable width is pinned here rather than left to the language
/// default.
///
/// ### Examples
///
/// ```dart
/// _fmtHz(49.70)  == '49.70'
/// _fmtHz(50.00)  == '50.00'
/// _fmtHz(49.855) == '49.85'   // truncation is to-string, not rounding
/// ```
///
/// ### Non-obvious
///
/// `toStringAsFixed` **rounds** — `_fmtHz(49.855)` yields `'49.86'` in
/// Dart, not `'49.85'`. The comment above shows the *reader's*
/// expectation; the language's rounding is authoritative. If the demo
/// ever needs truncation, this helper must change.
String _fmtHz(double hz) => hz.toStringAsFixed(2);

/// A single row in the append-only event log.
///
/// `GridEvent` is the atomic unit of the **feeder books**. Every row is
/// written through a `TissueList<GridEvent>` whose `TestTissue` allows
/// `add` / `addAll` and denies `remove` / `clear` / `[]=`. Once written,
/// a row is immutable for the life of the process. The reliability
/// council deputy (`events.unmodifiable`) can read every row but cannot
/// delete one.
///
/// ### Kinds in this demo
///
/// | `kind` | Written by | Meaning |
/// |---|---|---|
/// | `SHED` | SHED observer | a shed was opened (decision + book row) |
/// | `WARN` | WARN observer | the yellow band was entered |
/// | `RESTORE` | `restore()` | the shift lead returned a shed's MW |
/// | `RTU` | `_driveRtu` | an outbound RTU message was attempted |
/// | `ACK` | ACK observer (`"ALL"` only) | Distinct latches were cleared |
///
/// ### Why append-only
///
/// The event log is the **audit trail**. A regulator (“reliability
/// council”) must be able to reconstruct every decision and every MW
/// movement. If rows were removable, a SHED could be erased after the
/// fact. The `TestTissue` is the enforcement point.
///
/// ### See also
///
/// * [GridDemandResponseHarness.events] — the owning TissueList.
/// * [GridDemandResponseHarness._eventAppendOnly] — the rule.
final class GridEvent {
  /// The semantic tag of the entry (`SHED`, `WARN`, `RESTORE`, `RTU`,
  /// `ACK`).
  ///
  /// Free-form string; the append-only `TestTissue` checks only that
  /// it is non-empty (`e.kind.isNotEmpty`). Downstream tools key on the
  /// conventional values listed in the class doc.
  final String kind;

  /// The feeder identifier the entry refers to.
  ///
  /// For `ACK` rows written by the `"ALL"` path, this is the literal
  /// `'ALL'`. Every other row carries a real feeder id.
  final String feeder;

  /// A human-readable summary of the entry.
  ///
  /// The demo's contract requires this to be reproducible so the
  /// console output matches the walkthrough. Hz is formatted via
  /// `_fmtHz`; MW and SOC are plain integers.
  final String detail;

  /// When the entry was committed.
  ///
  /// Wall-clock time from `DateTime.now()`. Carried for forensic
  /// reconstruction; the demo's console output does not print it.
  final DateTime at;

  /// Creates a [GridEvent] with the given fields.
  const GridEvent({
    required this.kind,
    required this.feeder,
    required this.detail,
    required this.at,
  });

  @override
  String toString() => 'GridEvent($kind, $feeder, "$detail")';
}

/// An open demand-response shed on an interruptible feeder.
///
/// A `Shed` reserves `droppedMw` from the spinning reserve until the
/// feeder is restored. `shedMap` keys sheds by `feeder`, so a restore
/// finds the row by the same key the SHED observer wrote.
///
/// ### Invariant
///
/// After every successful `applyShed` / `restore` pair, the following
/// must hold:
///
/// ```
/// reserveMw.value! + sum(shedMap.values.droppedMw) == 800
/// ```
///
/// The demo breaks this **once** on purpose (§11) to prove the
/// non-negative `TestTissue` rejects an over-shed, then restores the
/// books to a self-consistent state in §12.
///
/// ### Validation
///
/// `_shedRule` (a `TestTissue<Shed, TissueMap<String, Shed>>`) requires
/// `droppedMw > 0` and `feeder.isNotEmpty`. A `Shed` with zero MW or an
/// empty feeder id is rejected at the TissueMap boundary before it can
/// reach the reserve table.
final class Shed {
  /// The feeder identifier the shed belongs to. Matches the `shedMap` key.
  final String feeder;

  /// The dropped load in MW. Must be `> 0` (enforced by `_shedRule`).
  final int droppedMw;

  const Shed({
    required this.feeder,
    required this.droppedMw,
  });

  @override
  String toString() => 'Shed($feeder, ${droppedMw}MW)';
}

/// A single outbound job for the RTU pump.
///
/// The RTU (Remote Terminal Unit) is the physical device at the
/// substation that actually opens the interruptible load. The demo
/// treats it as a flaky I/O endpoint: `_driveRtu` may throw once and
/// retry, exactly the failure mode a real DNP3 link exhibits.
///
/// ### Why a queue
///
/// Outbound messages must be ordered and bounded. `rtuQ` is a
/// `TissueQueue<RtuJob>` with `capacity: 32`. In this build the tissue
/// queue does not drain via `removeFirst`, so the demo uses a plain
/// Dart `_rtuWork` list for the pump while the tissue queue serves as
/// the **audit-side enqueue** (`addLast` → `ElementAdded<RtuJob>`).
/// That split is documented in the file header.
///
/// ### Validation
///
/// `_rtuJobRule` accepts every job. The demo does not currently reject
/// an RTU job; the rule exists as a hook for future per-action
/// rate-limiting.
final class RtuJob {
  /// The feeder identifier the job refers to.
  final String feeder;

  /// The action to deliver to the RTU.
  ///
  /// Only [Action.shed] and [Action.warn] jobs are produced by this
  /// demo. `Action.hold` never reaches the queue because the gates'
  /// `Filter` drops it first.
  final Action action;

  const RtuJob({required this.feeder, required this.action});

  @override
  String toString() => 'RtuJob($feeder, ${action.name})';
}

// ═════════════════════════════════════════════════════════════════════════════
// VISUAL OUTPUT HELPERS
// ═════════════════════════════════════════════════════════════════════════════

/// Prints a scenario section header.
///
/// The demo's console output is part of its contract, so scenario
/// banners have a fixed shape:
///
/// ```
/// ── <label> ── <drive>
/// ```
///
/// The blank line before each banner separates scenarios visually.
///
/// ### Parameters
///
/// * [label] — the scenario label (`'Seed'`, `'1'`, `'WARN'`, `'COMPLY'`).
/// * [drive] — a one-line description of what the scenario drives.
void _section(String label, String drive) {
  print('');
  print('── $label ── $drive');
}

// ═════════════════════════════════════════════════════════════════════════════
// HARNESS
// ═════════════════════════════════════════════════════════════════════════════

/// The grid demand-response harness — the demo's whole state machine.
///
/// One harness owns every Cell and every Tissue the demo touches. Do
/// not reuse a harness across runs; the state Cells and Tissues carry
/// history and the acceptance console assumes a fresh instance.
///
/// ### Lifecycle
///
/// 1. `final h = GridDemandResponseHarness();`
/// 2. `await h.install();`
/// 3. drive scenarios with `setHz` / `setLoad` / `setSoc` /
///    `setFeeder` / `publishTick` / `ack` / `applyShed` / `restore`.
/// 4. `h.dispose();`
///
/// `install()` is idempotent-by-contract but not asserted; calling it
/// twice will rebuild the gates and re-attach observers, doubling every
/// downstream effect. Do not call it twice.
///
/// ### Ownership
///
/// The harness is the **sole writer** for every Tissue in the demo. It
/// exposes them as `late final` public fields so `main()` can inspect
/// them (`h.events.length`, `h.reserveMw.value`, …) without going
/// through a wrapper.
///
/// ### See also
///
/// * [install] — one-time bootstrap.
/// * [actionOf] — the pure policy.
/// * [installGates] — the two Flow pipelines.
/// * [applyShed] / [restore] — the Tissue write protocol.
class GridDemandResponseHarness {
  /// Creates an empty harness. Call [install] before driving scenarios.
  GridDemandResponseHarness();

  // ───────────────────────────────────────────────────────────────────────────
  // Constants
  // ───────────────────────────────────────────────────────────────────────────

  /// The seed reserve in MW.
  ///
  /// The invariant `reserveMw + sum(droppedMw) == initialReserveMw` is
  /// asserted implicitly by the trailer; scenario 11 deliberately
  /// breaks it and scenario 12 restores consistency.
  static const int initialReserveMw = 800;

  /// The fixed MW dropped per shed in this demo.
  ///
  /// A fixed value keeps the arithmetic simple for the talk track. A
  /// real dispatch would size the shed from the frequency deviation
  /// (`Δf × droop × area load`) and the feeder's actual interruptible
  /// capacity.
  static const int shedMw = 50;

  // ───────────────────────────────────────────────────────────────────────────
  // Tissue — the feeder books
  // ───────────────────────────────────────────────────────────────────────────

  /// The append-only event log.
  ///
  /// A `TissueList<GridEvent>` guarded by `_eventAppendOnly`. Every
  /// `add` emits an `ElementAdded<GridEvent>` pulse on the list.
  ///
  /// ### Writers
  ///
  /// * SHED observer, WARN observer, `_driveRtu`, `applyShed`,
  ///   `restore`, ACK observer.
  ///
  /// ### Readers
  ///
  /// * `main()`'s trailer.
  /// * The COMPLY scenario (`events.unmodifiable`).
  late final TissueList<GridEvent> events;

  /// The spinning reserve in MW.
  ///
  /// A `TissueValue<int>` guarded by `_nonNegativeMw`. The rule rejects
  /// any write that would make the reserve negative. This is the
  /// primary under-frequency guard: an operator cannot shed more MW
  /// than the system is holding.
  ///
  /// ### Writers
  ///
  /// * `applyShed` (subtract).
  /// * `restore` (add).
  /// * Scenario 11 (`set(30)` — a deliberate out-of-band force).
  ///
  /// ### Readers
  ///
  /// * The trailer.
  /// * `applyShed`'s NSF pre-check.
  late final TissueValue<int> reserveMw;

  /// The open demand-response sheds, keyed by `feeder`.
  ///
  /// A `TissueMap<String, Shed>` guarded by `_shedRule`. Keys are
  /// feeder ids; values are `Shed` records. The map is the *source of
  /// truth* for “what is currently shed.”
  ///
  /// ### Writers
  ///
  /// * `applyShed` (`shedMap[feeder] = ...`).
  /// * `restore` (`shedMap.remove(feeder)`).
  ///
  /// ### Readers
  ///
  /// * `openShedsCount`.
  /// * The trailer.
  ///
  /// ### Naming
  ///
  /// The field is `shedMap`, not `sheds`, to avoid colliding with the
  /// [`shedCount`] integer counter. The walkthrough's prose uses
  /// “sheds” for both; the demo disambiguates.
  late final TissueMap<String, Shed> shedMap;

  /// Protected feeders — a runtime-mutable set of feeder ids.
  ///
  /// A `TissueSet<String>` guarded by `_protectedRule`, which requires
  /// each member to be an uppercase `AREA-N` style string (e.g.
  /// `HOSP-1`, `INT-14`).
  ///
  /// ### Why a set, not a const
  ///
  /// The set is mutated at runtime in scenario 2 (`protected.add('HOSP-1')`)
  /// to demonstrate that ops can protect a feeder without redeploying
  /// the graph. `actionOf` reads it on every tick.
  ///
  /// ### Writers
  ///
  /// * Scenario 2 (`add('HOSP-1')`).
  ///
  /// ### Readers
  ///
  /// * `actionOf`.
  late final TissueSet<String> protected;

  /// The bounded outbound queue for RTU I/O jobs.
  ///
  /// A `TissueQueue<RtuJob>` with `capacity: 32` and `_rtuJobRule`.
  ///
  /// ### Dual role
  ///
  /// In this build the tissue queue does **not** drain via
  /// `removeFirst`, so the demo uses it as the **audit-side enqueue**
  /// only (`addLast` → `ElementAdded<RtuJob>`). The pump runs on a
  /// plain Dart `_rtuWork` list. See the file header for the full
  /// rationale.
  late final TissueQueue<RtuJob> rtuQ;

  // ───────────────────────────────────────────────────────────────────────────
  // RTU pump working list
  // ───────────────────────────────────────────────────────────────────────────

  /// The pump's working list.
  ///
  /// See [rtuQ]'s doc for why this list exists alongside the tissue
  /// queue. In this build the tissue queue's `removeFirst` / `remove`
  /// do not drain, so the pump uses a plain `List<RtuJob>`.
  final List<RtuJob> _rtuWork = <RtuJob>[];

  // ───────────────────────────────────────────────────────────────────────────
  // Flow — shed decision pipeline
  // ───────────────────────────────────────────────────────────────────────────

  /// The Hz ingress (`49.00 … 51.00`).
  ///
  /// `TestCell` rule: `_hzRange`. Accepts any `num`; coerces to double.
  /// `setHz` returns `false` and does not update the cache when the
  /// rule rejects.
  late final IngressHandle<double> hzIn;

  /// The load ingress (`≥ 0 MW`).
  ///
  /// `TestCell` rule: `_loadRange`.
  late final IngressHandle<int> loadIn;

  /// The SOC ingress (`0 … 100 %`).
  ///
  /// `TestCell` rule: `_socRange`.
  late final IngressHandle<int> socIn;

  /// The area ingress (cache only — no `TestCell`).
  late final IngressHandle<String> areaIn;

  /// The feeder ingress (cache only — no `TestCell`).
  late final IngressHandle<String> feederIn;

  /// The snapshot bus ingress — publishes a complete [BayTick].
  ///
  /// Both gates (`shedCell`, `warnCell`) subscribe via
  /// `toHandle(source: tickIn.cell)`. Every published tick reaches both
  /// gates with the same payload.
  late final IngressHandle<BayTick> tickIn;

  /// The ACK ingress (shift-lead id, or `"ALL"`).
  ///
  /// An ACK resets both Distinct latches. If the id names a feeder with
  /// an open shed, the observer also calls [restore]. Otherwise it
  /// appends an `ACK ALL` row. ACK never rebuilds the graph.
  late final IngressHandle<String> ackIn;

  // ───────────────────────────────────────────────────────────────────────────
  // Flow gates
  // ───────────────────────────────────────────────────────────────────────────

  /// The SHED gate handle.
  ///
  /// Kept for symmetry and possible future use; `main()` reads
  /// [shedCell] directly.
  FlowHandle<Pulse<dynamic>>? shedHandle;

  /// The WARN gate handle.
  FlowHandle<Pulse<dynamic>>? warnHandle;

  /// The SHED gate cell — emits only when [actionOf] returns
  /// [Action.shed] **and** the Distinct latch has not seen `shed` since
  /// the last ACK.
  ///
  /// ### Pipeline
  ///
  /// ```
  /// MapValue<BayTick, Action>(actionOf)
  ///   + _distinctShed()
  ///   + Filter<Action>((a) => a == Action.shed)
  /// ```
  late final Cell shedCell;

  /// The WARN gate cell — emits only when [actionOf] returns
  /// [Action.warn] **and** the Distinct latch has not seen `warn` since
  /// the last ACK.
  ///
  /// ### Pipeline
  ///
  /// ```
  /// MapValue<BayTick, Action>(actionOf)
  ///   + _distinctWarn()
  ///   + Filter<Action>((a) => a == Action.warn)
  /// ```
  late final Cell warnCell;

  // ───────────────────────────────────────────────────────────────────────────
  // Dart-side ingress cache
  // ───────────────────────────────────────────────────────────────────────────

  String _area = 'NORTH';
  String _feeder = 'INT-14';
  double _hz = 50.00;
  int _loadMw = 420;
  int _soc = 60;

  // ───────────────────────────────────────────────────────────────────────────
  // Counters for the trailer
  // ───────────────────────────────────────────────────────────────────────────

  /// Number of successful [publishTick] calls (post-ingress).
  ///
  /// Incremented inside `publishTick` **after** all three `TestCell`
  /// guards pass. A rejected tick does not increment this counter.
  int ticks = 0;

  /// Number of SHED pulses that made it past the Distinct latch.
  ///
  /// Named `shedCount` (not `sheds`) to avoid collision with
  /// [shedMap]. Incremented inside the SHED observer.
  int shedCount = 0;

  /// Number of WARN pulses that made it past the Distinct latch.
  int warnCount = 0;

  /// Number of RTU pump attempts, **including retries**.
  ///
  /// Counts every entry into `_driveRtu`'s try block. A fail-once job
  /// therefore contributes two attempts (initial + retry). See the
  /// file header for why the walkthrough's `rtuAttempts=5` is stale.
  int rtuAttempts = 0;

  // ───────────────────────────────────────────────────────────────────────────
  // RTU failure injection
  // ───────────────────────────────────────────────────────────────────────────

  /// When `true`, the next RTU attempt throws once before the retry
  /// succeeds. Reset to `false` after the injected failure fires.
  bool rtuFailOnce = false;

  bool _rtuHasFailed = false;

  // ───────────────────────────────────────────────────────────────────────────
  // Distinct latches
  // ───────────────────────────────────────────────────────────────────────────

  /// The last [Action] seen by the SHED Distinct latch. `null` means
  /// the latch is reset (fresh after [resetDistinct]).
  Action? _lastShed;

  /// The last [Action] seen by the WARN Distinct latch.
  Action? _lastWarn;

  /// The last tick published — captured so the SHED / WARN observers
  /// can correlate the decision with the correct feeder and Hz.
  BayTick? _currentTick;

  final List<EgressHandle> _observers = [];

  // ───────────────────────────────────────────────────────────────────────────
  // TestTissue rules — ONLY used on Tissue constructors
  // ───────────────────────────────────────────────────────────────────────────

  /// Append-only rule for [events].
  ///
  /// Allows `add` / `addAll`; denies `remove` / `clear` / `[]=`.
  ///
  /// ### How the deny works
  ///
  /// `TissueList` routes every mutation through `apply(function, …)`.
  /// The `arguments` parameter of this rule receives that function.
  /// The rule string-matches the function against `remove`, `clear`,
  /// `[]=`. A match returns `false`, which the `TissueListMixin` reads
  /// as “reject the action.”
  ///
  /// ### Why string matching
  ///
  /// This build does not expose a typed mutation enum on
  /// `TestTissue`. The string form is a portable check that survives
  /// across the List/Set/Map variants. A future build could replace it
  /// with a capability check.
  static final TestTissue<GridEvent, TissueList<GridEvent>>
  _eventAppendOnly =
  TestTissue<GridEvent, TissueList<GridEvent>>(
        (value, {host, arguments, user}) {
      if (arguments is Function) {
        final src = arguments.toString();
        if (src.contains('remove') ||
            src.contains('clear') ||
            src.contains('[]=')) {
          return false;
        }
      }
      return true;
    },
  );

  /// Non-negative MW rule for [reserveMw].
  ///
  /// Rejects any write that would make the reserve negative. This is
  /// the under-frequency guard: an operator cannot shed more MW than
  /// the system is holding.
  static final TestTissue<int, TissueValue<int>> _nonNegativeMw =
  TestTissue<int, TissueValue<int>>(
        (value, {host, arguments, user}) {
      if (value is int) return value >= 0;
      return true;
    },
  );

  /// Shed rule for [shedMap].
  ///
  /// Requires `droppedMw > 0` and `feeder.isNotEmpty`.
  static final TestTissue<Shed, TissueMap<String, Shed>> _shedRule =
  TestTissue<Shed, TissueMap<String, Shed>>(
        (value, {host, arguments, user}) {
      if (value is Shed) {
        return value.droppedMw > 0 && value.feeder.isNotEmpty;
      }
      return true;
    },
  );

  /// Protected-feeder rule for [protected].
  ///
  /// Requires an uppercase `AREA-N` style string: must contain a `-`
  /// and must already be uppercase.
  static final TestTissue<String, TissueSet<String>> _protectedRule =
  TestTissue<String, TissueSet<String>>(
        (value, {host, arguments, user}) {
      if (value is String) {
        return value.contains('-') && value == value.toUpperCase();
      }
      return true;
    },
  );

  /// RTU job rule for [rtuQ]. Accepts every job.
  static final TestTissue<RtuJob, TissueQueue<RtuJob>> _rtuJobRule =
  TestTissue<RtuJob, TissueQueue<RtuJob>>(
        (value, {host, arguments, user}) => true,
  );

  // ───────────────────────────────────────────────────────────────────────────
  // TestCell rules — ONLY used on Cell.ingress
  // ───────────────────────────────────────────────────────────────────────────

  /// Hz shape: `49.00 … 51.00` inclusive.
  ///
  /// ### Pulse unwrapping
  ///
  /// The ingress wraps the input in a `Pulse` before calling the rule,
  /// so the rule unwraps `Pulse.payload` before applying the range
  /// check. Without this the rule sees a `Pulse<double>` and rejects
  /// every emission.
  static final TestCell<Cell> _hzRange = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = value is Pulse ? value.payload : value;
      if (v is! num) return false;
      final d = v.toDouble();
      return d >= 49.00 && d <= 51.00;
    },
  );

  /// Load shape: `≥ 0 MW`.
  static final TestCell<Cell> _loadRange = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = value is Pulse ? value.payload : value;
      if (v is! int) return false;
      return v >= 0;
    },
  );

  /// SOC shape: `0 … 100 %` inclusive.
  static final TestCell<Cell> _socRange = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = value is Pulse ? value.payload : value;
      if (v is! int) return false;
      return v >= 0 && v <= 100;
    },
  );

  // ───────────────────────────────────────────────────────────────────────────
  // install
  // ───────────────────────────────────────────────────────────────────────────

  /// Builds every Cell and Tissue, wires the gates, and installs the
  /// observers.
  ///
  /// ### Execution order is critical
  ///
  /// This must run **once**, before any scenario drives ingress. Calling
  /// it twice rebuilds the gates and re-attaches observers; every
  /// SHED / WARN pulse would then fire twice.
  ///
  /// ### Steps
  ///
  /// 1. Build the five Tissue collections with their `TestTissue`
  ///    rules.
  /// 2. Build the seven Flow ingress handles with their `TestCell`
  ///    rules.
  /// 3. Call [installGates] to wire the two decision pipelines.
  /// 4. Attach the SHED, WARN, and ACK observers.
  ///
  /// ### Trace prints
  ///
  /// The console output is emitted by the writers themselves — the
  /// observers, `_driveRtu`, `applyShed`, `restore`, and the scenario
  /// code in `main()`. In this build, `Cell.observe` on a Tissue cell
  /// does not deliver pulses to observer effects, so the writers are
  /// the only reliable print sites.
  ///
  /// ### See also
  ///
  /// * [installGates] — the Flow pipelines.
  /// * [dispose] — the teardown.
  Future<void> install() async {
    // ── Tissue ────────────────────────────────────────────────────────────
    events = TissueList<GridEvent>(testRule: _eventAppendOnly);

    reserveMw = TissueValue<int>(
      initialReserveMw,
      testRule: _nonNegativeMw,
    );

    shedMap = TissueMap<String, Shed>(
      properties: TissueMapNucleus<String, Shed>(testRule: _shedRule),
    );

    protected = TissueSet<String>(<String>[], testRule: _protectedRule);

    rtuQ = TissueQueue<RtuJob>(
      capacity: 32,
      testRule: _rtuJobRule,
    );

    // ── Flow ingress ──────────────────────────────────────────────────────
    hzIn = Cell.ingress<double>(testRule: _hzRange);
    loadIn = Cell.ingress<int>(testRule: _loadRange);
    socIn = Cell.ingress<int>(testRule: _socRange);
    areaIn = Cell.ingress<String>();
    feederIn = Cell.ingress<String>();
    tickIn = Cell.ingress<BayTick>();
    ackIn = Cell.ingress<String>();

    // ── Gates ─────────────────────────────────────────────────────────────
    installGates();

    // ── SHED observer ─────────────────────────────────────────────────────
    //
    // Fires when `shedCell` emits `Action.shed` (post-Distinct, post-Filter).
    // Sequence:
    //   1. shedCount++
    //   2. events.add(SHED …)
    //   3. rtuQ.addLast(RtuJob(shed)) + _rtuWork.add + _driveRtu()
    //   4. applyShed(feeder, shedMw)
    _observers.add(Cell.observe(
      source: shedCell,
      effect: (Pulse pulse) {
        if (pulse.payload == Action.shed) {
          shedCount++;
          final t = _currentTick;
          if (t != null) {
            events.add(GridEvent(
              kind: 'SHED',
              feeder: t.feeder,
              detail: '${_fmtHz(t.hz)}Hz load=${t.loadMw}MW',
              at: DateTime.now(),
            ));
            print('[events] SHED ${t.feeder} — '
                '${_fmtHz(t.hz)}Hz load=${t.loadMw}MW');

            final job = RtuJob(feeder: t.feeder, action: Action.shed);
            rtuQ.addLast(job);
            print('[rtuQ] enqueued $job');

            _rtuWork.add(job);
            _driveRtu();

            applyShed(t.feeder, shedMw);
          }
        }
      },
    ));

    // ── WARN observer ─────────────────────────────────────────────────────
    //
    // Fires when `warnCell` emits `Action.warn` (post-Distinct, post-Filter).
    // Does NOT touch reserveMw or shedMap — a warn is a decision, not a
    // debit. Only writes the event log and enqueues an RTU job.
    _observers.add(Cell.observe(
      source: warnCell,
      effect: (Pulse pulse) {
        if (pulse.payload == Action.warn) {
          warnCount++;
          final t = _currentTick;
          if (t != null) {
            events.add(GridEvent(
              kind: 'WARN',
              feeder: t.feeder,
              detail: '${_fmtHz(t.hz)}Hz SOC=${t.soc}',
              at: DateTime.now(),
            ));
            print('[events] WARN ${t.feeder} — '
                '${_fmtHz(t.hz)}Hz SOC=${t.soc}');

            final job = RtuJob(feeder: t.feeder, action: Action.warn);
            rtuQ.addLast(job);
            print('[rtuQ] enqueued $job');

            _rtuWork.add(job);
            _driveRtu();
          }
        }
      },
    ));

    // ── ACK observer ──────────────────────────────────────────────────────
    //
    // Fires on every ackIn emission.
    //   1. resetDistinct() — clears both latches.
    //   2. If the payload names a feeder with an open shed, restore it.
    //      Otherwise append an ACK ALL row.
    //
    // ACK never calls toHandle. The gates stay as they are.
    _observers.add(Cell.observe(
      source: ackIn.cell,
      effect: (Pulse pulse) {
        final who = pulse.payload;
        resetDistinct();
        if (who is String && who.isNotEmpty && who != 'ALL') {
          restore(who);
        } else {
          events.add(GridEvent(
            kind: 'ACK',
            feeder: 'ALL',
            detail: 'distinct cleared',
            at: DateTime.now(),
          ));
          print('[events] ACK ALL — distinct cleared');
        }
      },
    ));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // installGates
  // ───────────────────────────────────────────────────────────────────────────

  /// Builds the two decision pipelines.
  ///
  /// ### Execution order is critical
  ///
  /// Runs exactly once from [install]. ACK does **not** call this again
  /// — a second handle would double every downstream effect.
  ///
  /// ### Each gate
  ///
  /// ```
  /// MapValue<BayTick, Action>(actionOf)
  ///   + Distinct (custom FlowInstruction)
  ///   + Filter<Action>(x)
  /// ```
  ///
  /// The Distinct instruction is per-gate so a fresh SHED (after an
  /// ACK) can fire even if the previous action had the same value. The
  /// two latches are independent: a WARN does not clear the SHED latch
  /// and vice versa.
  ///
  /// ### Why Distinct comes before Filter
  ///
  /// Distinct records the decision the pipeline *made* — including
  /// `hold`. If Filter ran first, a sequence `hold → shed` would still
  /// work, but `shed → hold → shed` would not: the second `shed` would
  /// be suppressed because the latch still held `shed` from the first
  /// tick. Running Distinct first means `hold → shed → hold → shed`
  /// fires twice, matching the operator's mental model.
  void installGates() {
    // SHED: MapValue → Distinct → Filter(shed)
    final shedFlow = MapValue<BayTick, Action>(
          (t) => actionOf(t, protected),
    ) +
        _distinctShed() +
        Filter<Action>((a) => a == Action.shed);

    shedHandle = shedFlow.toHandle(source: tickIn.cell);
    shedCell = shedHandle!.cell;

    // WARN: MapValue → Distinct → Filter(warn)
    final warnFlow = MapValue<BayTick, Action>(
          (t) => actionOf(t, protected),
    ) +
        _distinctWarn() +
        Filter<Action>((a) => a == Action.warn);

    warnHandle = warnFlow.toHandle(source: tickIn.cell);
    warnCell = warnHandle!.cell;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // RTU pump
  // ───────────────────────────────────────────────────────────────────────────

  /// Drains the pump's working list with a single-shot retry.
  ///
  /// ### Why the tissue queue is not used directly
  ///
  /// In this build `TissueQueue.removeFirst` / `remove` do not drain
  /// the container. The tissue queue stays as the audit-side enqueue
  /// (`addLast` → `ElementAdded<RtuJob>`) and the pump runs on the
  /// plain Dart `_rtuWork` list.
  ///
  /// ### Failure semantics
  ///
  /// If [rtuFailOnce] is set and this is the first attempt, the mock
  /// throws. The pump catches it and retries once. [rtuAttempts]
  /// increments for both attempts, exposing the retry to the trailer.
  ///
  /// ### Return
  ///
  /// The method is `Future<void>` but its body is synchronous until the
  /// first `await` — and there is none. The future completes
  /// immediately. The signature is `Future` only for symmetry with a
  /// real async RTU.
  Future<void> _driveRtu() async {
    if (_rtuWork.isEmpty) return;
    final job = _rtuWork.removeAt(0);

    try {
      rtuAttempts++;
      if (rtuFailOnce && !_rtuHasFailed) {
        _rtuHasFailed = true;
        throw StateError('rtu transient');
      }
      events.add(GridEvent(
        kind: 'RTU',
        feeder: job.feeder,
        detail: job.action.name,
        at: DateTime.now(),
      ));
      print('[events] RTU ${job.feeder} — ${job.action.name}');
    } catch (_) {
      try {
        rtuAttempts++;
        events.add(GridEvent(
          kind: 'RTU',
          feeder: job.feeder,
          detail: '${job.action.name} (retry)',
          at: DateTime.now(),
        ));
        print('[events] RTU ${job.feeder} — '
            '${job.action.name} (retry)');
      } catch (_) {
        // give up
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Flow instructions (Distinct)
  // ───────────────────────────────────────────────────────────────────────────

  /// Builds the SHED Distinct instruction.
  ///
  /// Returns `null` (signal terminated) if the incoming action matches
  /// [_lastShed]. Otherwise updates the latch and passes the pulse on.
  ///
  /// The latch is a plain `Action?` field, not a `Box` or a `Cell`,
  /// because the instruction closure captures `this`. That's what lets
  /// [resetDistinct] clear the latch without rebuilding the graph.
  FlowInstruction _distinctShed() {
    return FlowInstruction((pulse, {cell, user}) {
      final a = pulse.payload;
      if (_lastShed == a) return null;
      _lastShed = a;
      return pulse;
    });
  }

  /// Builds the WARN Distinct instruction. Same contract as
  /// [_distinctShed] but with its own latch.
  FlowInstruction _distinctWarn() {
    return FlowInstruction((pulse, {cell, user}) {
      final a = pulse.payload;
      if (_lastWarn == a) return null;
      _lastWarn = a;
      return pulse;
    });
  }

  /// Clears both Distinct latches.
  ///
  /// Called by the ACK observer and by scenario 13 (`ack('ALL')`). After
  /// a reset, the next SHED or WARN decision fires regardless of its
  /// value — even if it equals the previous one.
  ///
  /// ### Why both latches
  ///
  /// A shift lead who clears the “shed alarm” also clears the “warn
  /// alarm.” Two separate ACK paths would let a stale WARN linger after
  /// a SHED was restored, which is a real operational bug.
  void resetDistinct() {
    _lastShed = null;
    _lastWarn = null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // actionOf — pure policy
  // ───────────────────────────────────────────────────────────────────────────

  /// Evaluates the action for a [BayTick] against the [protectedSet].
  ///
  /// ### Rules
  ///
  /// | Condition | Action |
  /// |---|---|
  /// | `t.feeder` in `protectedSet` | `hold` |
  /// | `t.hz < 49.80` | `shed` |
  /// | `t.hz < 49.90` | `warn` |
  /// | `t.soc < 15` and `t.loadMw > 500` | `warn` |
  /// | else | `hold` |
  ///
  /// The order matters. A protected feeder returns `hold` before any
  /// frequency check, so `HOSP-1` at 49.70 Hz is held, not shed.
  ///
  /// ### Purity
  ///
  /// This function is `static`, has no `await`, does no I/O, and
  /// touches no MW. It reads [protectedSet] and nothing else. It is
  /// the *entire* decision policy of the demo, and it can be unit
  /// tested with a bare `BayTick` and an empty `TissueSet`.
  ///
  /// ### Why static
  ///
  /// Purity is enforced by the type system: a `static` method cannot
  /// reach `this`, so it cannot accidentally call `reserveMw.set` or
  /// `events.add`. If the policy ever needs instance state, promote it
  /// to an instance method and accept the reduced testability.
  ///
  /// ### See also
  ///
  /// * [installGates] — where this policy is wired into both gates.
  /// * [protected] — the TissueSet the policy reads.
  static Action actionOf(BayTick t, TissueSet<String> protectedSet) {
    if (protectedSet.contains(t.feeder)) return Action.hold;
    if (t.hz < 49.80) return Action.shed;
    if (t.hz < 49.90) return Action.warn;
    if (t.soc < 15 && t.loadMw > 500) return Action.warn;
    return Action.hold;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Bus — setters and publishTick
  // ───────────────────────────────────────────────────────────────────────────

  /// Sets the Hz cache.
  ///
  /// Returns `true` if the ingress `TestCell` accepted the value, in
  /// which case [_hz] is updated. Returns `false` and does **not**
  /// update the cache when the rule rejects.
  ///
  /// ### Why a cache
  ///
  /// The snapshot bus needs all five fields to publish a `BayTick`.
  /// The cache holds the last accepted value of each; `publishTick`
  /// reads them. A rejected setter leaves the previous value in place
  /// so a subsequent publish uses only accepted inputs.
  bool setHz(double hz) {
    final accepted = hzIn.emit(hz);
    if (accepted) _hz = hz;
    return accepted;
  }

  /// Sets the load cache. Same contract as [setHz].
  bool setLoad(int mw) {
    final accepted = loadIn.emit(mw);
    if (accepted) _loadMw = mw;
    return accepted;
  }

  /// Sets the SOC cache. Same contract as [setHz].
  bool setSoc(int soc) {
    final accepted = socIn.emit(soc);
    if (accepted) _soc = soc;
    return accepted;
  }

  /// Sets the area cache. No `TestCell` — always returns `true`.
  bool setArea(String area) {
    _area = area;
    return true;
  }

  /// Sets the feeder cache. No `TestCell` — always returns `true`.
  ///
  /// The feeder id is checked by `actionOf` against [protected], not at
  /// ingress. An unknown feeder is not a shape error; it's a policy
  /// input.
  bool setFeeder(String feeder) {
    _feeder = feeder;
    return true;
  }

  /// Publishes a complete [BayTick] onto the snapshot bus.
  ///
  /// ### Pre-flight guards
  ///
  /// Before emitting, the method re-checks [_hzValid], [_loadValid],
  /// and [_socValid]. These mirror the `TestCell` rules exactly. They
  /// exist because scenario 8 needs to *report* a rejection without
  /// publishing (calling `hzIn.emit` directly would also fail, but the
  /// double-check makes the intent explicit and lets `publishTick`
  /// return `false` cleanly).
  ///
  /// ### Returns
  ///
  /// * `true` — the tick was published on `tickIn`.
  /// * `false` — one of the guards failed; nothing was published.
  ///
  /// ### Async
  ///
  /// The method is `async` and awaits a zero-delay future after the
  /// emit. This lets the observer chain (Cell.observe → Tissue writes)
  /// drain before the next scenario step runs.
  Future<bool> publishTick() async {
    if (!_hzValid(_hz)) {
      print('[ingress] hz ${_fmtHz(_hz)} rejected by TestCell');
      return false;
    }
    if (!_loadValid(_loadMw)) {
      print('[ingress] load $_loadMw rejected by TestCell');
      return false;
    }
    if (!_socValid(_soc)) {
      print('[ingress] soc $_soc rejected by TestCell');
      return false;
    }

    final t = BayTick(
      area: _area,
      feeder: _feeder,
      hz: _hz,
      loadMw: _loadMw,
      soc: _soc,
    );
    _currentTick = t;
    ticks++;
    tickIn.emit(t);
    await Future.delayed(Duration.zero);
    return true;
  }

  /// Static validator mirroring `_hzRange`.
  static bool _hzValid(double v) => v >= 49.00 && v <= 51.00;

  /// Static validator mirroring `_loadRange`.
  static bool _loadValid(int v) => v >= 0;

  /// Static validator mirroring `_socRange`.
  static bool _socValid(int v) => v >= 0 && v <= 100;

  /// Publishes an ACK onto [ackIn].
  ///
  /// ### Ack payloads
  ///
  /// * A feeder id (`'INT-14'`) — the ACK observer clears the Distinct
  ///   latches and calls [restore] for that feeder.
  /// * `'ALL'` — the ACK observer clears the latches and appends an
  ///   `ACK ALL` row, without a restore.
  ///
  /// ### Async
  ///
  /// Same zero-delay drain as [publishTick].
  Future<bool> ack(String who) async {
    ackIn.emit(who);
    await Future.delayed(Duration.zero);
    return true;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Reserve — TissueValue + TissueMap
  // ───────────────────────────────────────────────────────────────────────────

  /// Attempts to apply a shed.
  ///
  /// ### v1 write protocol
  ///
  /// 1. Pre-check `reserveMw` for under-frequency.
  /// 2. Write `shedMap[feeder]`.
  /// 3. Write `reserveMw` (subtract MW).
  /// 4. Append `SHED` to the event log.
  ///
  /// If step 3 rejects, the prior writes are compensated and the
  /// method returns `false` without leaving a partial state.
  ///
  /// ### Return
  ///
  /// * `true` — the shed was applied; reserveMw decreased by `droppedMw`.
  /// * `false` — the pre-check failed (reserve insufficient) or the
  ///   reserve write was rejected.
  ///
  /// ### Invariant
  ///
  /// After a successful call, `reserveMw + sum(shedMap.values.droppedMw)`
  /// is `initialReserveMw` less any out-of-band force (see §11 in the
  /// walkthrough).
  ///
  /// ### See also
  ///
  /// * [restore] — the inverse.
  /// * [_nonNegativeMw] — the `TestTissue` guarding the reserve.
  bool applyShed(String feeder, int droppedMw) {
    final before = reserveMw.value ?? 0;
    if (before < droppedMw) {
      return false;
    }
    shedMap[feeder] = Shed(feeder: feeder, droppedMw: droppedMw);
    final okReserve = reserveMw.set(before - droppedMw);
    if (!okReserve) {
      shedMap.remove(feeder);
      return false;
    }
    print('[reserveMw] $before → ${before - droppedMw}');

    events.add(GridEvent(
      kind: 'SHED',
      feeder: feeder,
      detail: '${droppedMw}MW',
      at: DateTime.now(),
    ));
    print('[shedMap] $feeder +${droppedMw}MW');
    return true;
  }

  /// Restores an existing shed.
  ///
  /// ### v1 write protocol
  ///
  /// 1. Look up `shedMap[feeder]`.
  /// 2. Remove the map row.
  /// 3. Add back to `reserveMw`.
  /// 4. Append `RESTORE` to the event log.
  ///
  /// ### Return
  ///
  /// * `true` — the shed was found and restored.
  /// * `false` — no open shed for that feeder. `reserveMw` is unchanged.
  ///
  /// ### The “no open shed” case
  ///
  /// A restore with no matching shed is not an error — it is a no-op.
  /// Scenario 13 relies on this: ACK `'ALL'` clears the latches but
  /// does not invent MW.
  bool restore(String feeder) {
    final s = shedMap[feeder];
    if (s == null) return false;
    shedMap.remove(feeder);

    final before = reserveMw.value ?? 0;
    reserveMw.set(before + s.droppedMw);
    print('[reserveMw] $before → ${before + s.droppedMw}');

    events.add(GridEvent(
      kind: 'RESTORE',
      feeder: feeder,
      detail: '${s.droppedMw}MW',
      at: DateTime.now(),
    ));
    print('[events] RESTORE $feeder — ${s.droppedMw}MW');
    return true;
  }

  /// The number of open sheds currently in [shedMap].
  int get openShedsCount => shedMap.length;

  // ───────────────────────────────────────────────────────────────────────────
  // Teardown
  // ───────────────────────────────────────────────────────────────────────────

  /// Stops every observer attached during [install].
  ///
  /// ### When to use
  ///
  /// Call at the end of `main`, after the trailer has printed. The demo
  /// is a one-shot process; on a long-lived host, `dispose` would be
  /// the point at which the harness releases its subscriptions.
  ///
  /// ### What it does not do
  ///
  /// It does not clear the Tissue collections or reset the latches.
  /// Those objects are expected to be garbage-collected with the
  /// harness.
  void dispose() {
    for (final o in _observers) {
      o.stop();
    }
    _observers.clear();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═════════════════════════════════════════════════════════════════════════════

/// Main entry point for the grid demand-response demo.
///
/// ### Execution order is critical
///
/// 1. Build the harness via [GridDemandResponseHarness.install].
/// 2. Seed the sensors with the initial state.
/// 3. Run scenarios 1–13, WARN, and COMPLY in order.
/// 4. Print the trailer and dispose.
///
/// ### Scenario index
///
/// | Banner | Demonstrates |
/// |---|---|
/// | Seed | bus + Filter; initial Tissue is silent |
/// | 1 | Distinct on `hold` |
/// | 2 | TissueSet feeds `actionOf` |
/// | 3 | Distinct `hold`→`shed` |
/// | 4 | Distinct holds |
/// | 5 | Distinct keys on Action, not Hz |
/// | WARN | second Receptor, independent latch |
/// | 6 | ACK clears latches; restore |
/// | 7 | fresh shed after reset |
/// | 8 | TestCell rejects at ingress |
/// | 9 | RTU retry, one new SHED |
/// | 10 | TissueMap, second feeder |
/// | 11 | non-negative TestTissue rejects |
/// | 12 | restore returns MW |
/// | 13 | ACK without open shed invents no MW |
/// | COMPLY | deputy is live, writes blocked |
Future<void> main() async {
  print('========================================================================');
  print(' grid-demand-response(tissue)-Demo.dart');
  print(' Flow owns the shed decision. Tissue owns the feeder books.');
  print('========================================================================');

  final h = GridDemandResponseHarness();
  await h.install();

  // ── Seed ────────────────────────────────────────────────────────────────
  _section('Seed', '50.00 / INT-14 / load 420 / SOC 60');
  h.setArea('NORTH');
  h.setFeeder('INT-14');
  h.setHz(50.00);
  h.setLoad(420);
  h.setSoc(60);
  await h.publishTick();
  print('  events.isEmpty=${h.events.isEmpty}');

  // ── 1 ───────────────────────────────────────────────────────────────────
  _section('1', 'repeat 50.00 / INT-14');
  final s1 = h.shedCount;
  await h.publishTick();
  print('  new sheds: ${h.shedCount - s1}');

  // ── 2 ───────────────────────────────────────────────────────────────────
  _section('2', "protected.add('HOSP-1'), then 49.70 Hz on HOSP-1");
  h.protected.add('HOSP-1');
  print('[protected] +HOSP-1');
  h.setFeeder('HOSP-1');
  h.setHz(49.70);
  h.setLoad(420);
  h.setSoc(60);
  final s2 = h.shedCount;
  await h.publishTick();
  print('  new sheds: ${h.shedCount - s2}');

  // ── 3 ───────────────────────────────────────────────────────────────────
  _section('3', '49.70 Hz on INT-14');
  h.setFeeder('INT-14');
  h.setHz(49.70);
  h.setLoad(420);
  h.setSoc(60);
  final s3 = h.shedCount;
  await h.publishTick();
  print('  new sheds: ${h.shedCount - s3}');
  print('  rtuQ.length=${h.rtuQ.length}');

  // ── 4 ───────────────────────────────────────────────────────────────────
  _section('4', '49.70 again');
  final s4 = h.shedCount;
  await h.publishTick();
  print('  new sheds: ${h.shedCount - s4}');

  // ── 5 ───────────────────────────────────────────────────────────────────
  _section('5', '49.72 (still shed band)');
  h.setHz(49.72);
  final s5 = h.shedCount;
  await h.publishTick();
  print('  new sheds: ${h.shedCount - s5}');

  // ── WARN ────────────────────────────────────────────────────────────────
  _section('WARN', '49.85 / SOC 10 / load 600');
  h.setHz(49.85);
  h.setLoad(600);
  h.setSoc(10);
  final w0 = h.warnCount;
  await h.publishTick();
  print('  new warns: ${h.warnCount - w0}');

  // ── 6 ───────────────────────────────────────────────────────────────────
  _section('6', '50.00 then ACK restore INT-14');
  h.setHz(50.00);
  h.setLoad(420);
  h.setSoc(60);
  await h.publishTick();
  await h.ack('INT-14');
  print('  reserveMw=${h.reserveMw.value} '
      'openSheds=${h.openShedsCount}');

  // ── 7 ───────────────────────────────────────────────────────────────────
  _section('7', '49.70 Hz on INT-14');
  h.setHz(49.70);
  final s7 = h.shedCount;
  await h.publishTick();
  print('  new sheds: ${h.shedCount - s7}');

  // ── 8 ───────────────────────────────────────────────────────────────────
  _section('8', 'Hz 48.0, load -10, SOC 101');
  final e8 = h.events.length;
  final rejectedHz = h.setHz(48.0);
  final rejectedLoad = h.setLoad(-10);
  final rejectedSoc = h.setSoc(101);
  print('  hz 48.0 accepted=$rejectedHz');
  print('  load -10 accepted=$rejectedLoad');
  print('  soc 101 accepted=$rejectedSoc');
  print('  events grew: ${h.events.length - e8}');

  // ── 9 ───────────────────────────────────────────────────────────────────
  _section('9', 'ACK, recover, 49.70, RTU fail-once');
  await h.ack('INT-14');
  h.setHz(50.00);
  await h.publishTick();
  h.setHz(49.70);
  final s9 = h.shedCount;
  h.rtuFailOnce = true;
  await h.publishTick();
  print('  new sheds: ${h.shedCount - s9}');
  print('  rtuAttempts=${h.rtuAttempts}');

  // ── 10 ──────────────────────────────────────────────────────────────────
  _section('10', 'restore, ACK, 49.70 on INT-15');
  await h.ack('INT-14');
  h.setFeeder('INT-15');
  h.setHz(49.70);
  final s10 = h.shedCount;
  await h.publishTick();
  print('  new sheds: ${h.shedCount - s10}');
  print('  openSheds=${h.openShedsCount}');

  // ── 11 ──────────────────────────────────────────────────────────────────
  _section('11', 'force reserve to 30, then SHED 50');
  h.reserveMw.set(30);
  h.setFeeder('INT-16');
  final okShed = h.applyShed('INT-16', 50);
  print('  applyShed ok=$okShed');
  print('  reserveMw=${h.reserveMw.value} '
      'openSheds=${h.openShedsCount}');

  // ── 12 ──────────────────────────────────────────────────────────────────
  _section('12', 'restore INT-15');
  final ok12 = h.restore('INT-15');
  print('  restore ok=$ok12');
  print('  reserveMw=${h.reserveMw.value} '
      'openSheds=${h.openShedsCount}');

  // ── 13 ──────────────────────────────────────────────────────────────────
  _section('13', 'ACK without an open shed');
  final r13 = h.reserveMw.value;
  await h.ack('ALL');
  print('  reserveMw=${h.reserveMw.value} '
      'openSheds=${h.openShedsCount} '
      'unchanged=${h.reserveMw.value == r13}');

  // ── COMPLY ──────────────────────────────────────────────────────────────
  _section('COMPLY',
      'council.add(...) blocked; length == events.length');
  final council = h.events.unmodifiable;
  final eventsBefore = h.events.length;
  var blocked = false;
  try {
    council.add(GridEvent(
      kind: 'HACK',
      feeder: 'X',
      detail: 'attempted by council',
      at: DateTime.now(),
    ));
    blocked = h.events.length == eventsBefore;
  } catch (_) {
    blocked = true;
  }
  print('  council.add blocked=$blocked');
  print('  council.length=${council.length} '
      'events.length=${h.events.length}');

  // ── Trailer ─────────────────────────────────────────────────────────────
  print('');
  print('------------------------------------------------------------------------');
  print('ticks=${h.ticks} sheds=${h.shedCount} warns=${h.warnCount} '
      'events=${h.events.length} rtuAttempts=${h.rtuAttempts}');
  print('reserveMw=${h.reserveMw.value} '
      'openSheds=${h.openShedsCount}');
  print('councilLength=${council.length} (same as events)');
  print('------------------------------------------------------------------------');

  h.dispose();
}