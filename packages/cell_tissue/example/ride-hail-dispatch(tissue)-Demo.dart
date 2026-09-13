// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// # Ride-Hail Dispatch — executable demonstration
///
/// **Domain:** ride-hailing / mobility dispatch (match a rider ping to
/// a driver, hold a surge banner, keep a trip ledger the city can
/// audit).
///
/// **Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`.
///
/// **Status:** executable reference implementation of
/// `ride-hail-dispatch(tissue)-WalkThrough.md`.
///
/// ---
///
/// ## The seam — Flow owns the match decision, Tissue owns the fleet books
///
/// This file demonstrates **one architectural property**: the reactive
/// *decision* layer (Flow) and the reactive *ledger* layer (Tissue) are
/// separate, and they are glued together by exactly one thing — a
/// `Cell.observe` on each gate.
///
/// * Flow answers: *“Is this tick a DISPATCH, a SURGE, or an IDLE?”*
/// * Tissue answers: *“What did the books just record, and did drivers
///   move?”*
/// * The observer is the only glue.
///
/// Nothing about the matching policy touches the fleet table. Nothing
/// about the fleet table influences the matching policy. If you find
/// yourself writing `idleDrivers.set(...)` inside `matchOf`, you have
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
/// | **Decision** | Receptor lock on `dispatchCell` / `surgeCell` | `matchOf`, Distinct latch, `Filter` | any Tissue write |
/// | **Books** | Tissue lock on each collection | `trips.add`, `assignments[...]`, `idleDrivers.set`, `pushQ.addLast` | any decision logic |
///
/// A DISPATCH pulse therefore crosses **two** lock boundaries in
/// sequence: the Receptor lock releases, then the observer takes the
/// Tissue lock. That sequencing is what lets you unit-test `matchOf`
/// with a bare `MatchTick` and no Tissue at all.
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
/// `TestCell` is the integrity rule on a **Cell** (shape of an
/// incoming pulse). `TestTissue` is the integrity rule on a **Tissue**
/// (shape of a mutation, a member, a value write). Grep this file for
/// `testRule: TestCell` on any Tissue constructor: you will find zero
/// hits.
///
/// ---
///
/// ## Fleet invariant
///
/// After every successful `accept` / `complete` pair, the following
/// must hold:
///
/// ```
/// idleDrivers.value! + assignments.length == 12
/// ```
///
/// The demo deliberately violates this **once**, in scenario 11, by
/// forcing `idleDrivers` to `0` to prove the non-negative `TestTissue`
/// rejects an over-assignment. Scenario 12 restores the books to a
/// self-consistent state (`1`). The header's expected-output block
/// documents this deviation.
///
/// ---
///
/// ## Documented deviations from the walkthrough
///
/// The walkthrough's prose and its sample console contradict each
/// other at several points. This demo follows the **prose** (the
/// policy) and prints the **self-consistent** numbers. Deviations:
///
/// ### (a) §10 rider context
/// The walkthrough says “accept `D-8` on scenario 7” without naming a
/// rider. Because `_riderId` is still `R-20` from §9 and §10 does not
/// call `setRider`, the accept assigns `D-8 → R-20`. The header
/// matches the actual run.
///
/// ### (b) Trailer — order-of-magnitude numbers
/// The walkthrough's `ticks ≥ 16`, `dispatches 3–5`, and generic
/// `pushAttempts` were order-of-magnitude estimates. The
/// self-consistent run produces:
///
/// ```
/// ticks=10 dispatches=5 surges=1 trips=17 pushAttempts=7
/// idle=1 assignments=1
/// auditorLength=17 (same as trips)
/// ```
///
/// `ticks` is 10 because §8 never publishes (all three `TestCell`s
/// reject). `pushAttempts` is 7 because every DISPATCH and SURGE
/// enqueues one push, plus the §9 retry.
///
/// ### (c) Fleet invariant end state
/// After §12 completes `D-7`, the books are `idle=1, assignments=1`.
/// The walkthrough's "restore to 12" would require completing the
/// outstanding `D-8` assignment, which the demo leaves open for a
/// second run.
///
/// ---
///
/// ## Expected console output (self-consistent)
///
/// ```
/// ╔═══════════════════════════════════════════════════════════════════╗
/// ║  ride-hail-dispatch(tissue)-Demo.dart                              ║
/// ║  Flow owns the match decision. Tissue owns the fleet books.        ║
/// ╚═══════════════════════════════════════════════════════════════════╝
///
/// ── Seed ── DOWNTOWN / 3 nearby / wait 20 / surge 1.0
/// [trips] DISPATCH R-18 — zone=DOWNTOWN nearby=3
/// [pushQ] enqueued PushJob(R-18, dispatch)
/// [trips] PUSH R-18 — dispatch
///   new dispatches: 1
///   trips.isEmpty=false
///
/// ── 1 ── repeat same tick
///   new dispatches: 0
///
/// ── 2 ── noGo.add('STADIUM-CURB'), tick zone STADIUM-CURB
/// [noGo] +STADIUM-CURB
///   new dispatches: 0
///
/// ── 3 ── back to DOWNTOWN
/// [trips] DISPATCH R-18 — zone=DOWNTOWN nearby=3
/// [pushQ] enqueued PushJob(R-18, dispatch)
/// [trips] PUSH R-18 — dispatch
///   new dispatches: 1
///
/// ── 4 ── same downtown again
///   new dispatches: 0
///
/// ── 5 ── wait 400 nearby 3
///   new dispatches: 0
///
/// ── SURGE ── nearby 0 wait 200 surge 2.1 downtown
/// [trips] SURGE R-19 — surge=2.1 wait=200
/// [pushQ] enqueued PushJob(R-19, surge)
/// [trips] PUSH R-19 — surge
///   new surges: 1
///
/// ── 6 ── nearby 3 / surge 1.0 then ACK accept D-7
/// [trips] DISPATCH R-18 — zone=DOWNTOWN nearby=3
/// [pushQ] enqueued PushJob(R-18, dispatch)
/// [trips] PUSH R-18 — dispatch
/// [idleDrivers] 12 → 11
/// [assignments] D-7 → R-18
/// [trips] ACCEPT D-7 — rider=R-18
///   idle=11 assignments=1
///
/// ── 7 ── new rider downtown nearby 3
/// [trips] DISPATCH R-19 — zone=DOWNTOWN nearby=3
/// [pushQ] enqueued PushJob(R-19, dispatch)
/// [trips] PUSH R-19 — dispatch
///   new dispatches: 1
///
/// ── 8 ── lat 91, lng 200, wait -1
///   lat 91 accepted=false
///   lng 200 accepted=false
///   wait -1 accepted=false
///   trips grew: 0
///
/// ── 9 ── ACK cancel, recover, downtown, push fail-once
/// [trips] CANCEL ALL — distinct cleared
/// [trips] DISPATCH R-20 — zone=DOWNTOWN nearby=3
/// [pushQ] enqueued PushJob(R-20, dispatch)
/// [trips] PUSH R-20 — dispatch (retry)
///   new dispatches: 1
///   pushAttempts=7
///
/// ── 10 ── accept D-8 on scenario 7
/// [idleDrivers] 11 → 10
/// [assignments] D-8 → R-20
/// [trips] ACCEPT D-8 — rider=R-20
///   accept ok=true
///   idle=10 assignments=2
///
/// ── 11 ── force idle to 0, then accept D-9
///   accept ok=false
///   idleDrivers=0 assignments=2
///
/// ── 12 ── complete D-7
/// [assignments] D-7 removed
/// [idleDrivers] 0 → 1
/// [trips] COMPLETE D-7 — rider=R-18
///   complete ok=true
///   idle=1 assignments=1
///
/// ── 13 ── unmatched CANCEL
/// [trips] CANCEL ALL — distinct cleared
///   idle=1 assignments=1 unchanged=true
///
/// ── COMPLY ── auditor.add(...) blocked; length == trips.length
///   auditor.add blocked=true
///   auditor.length=17 trips.length=17
///
/// ─────────────────────────────────────────────────────────────────────
/// ticks=10 dispatches=5 surges=1 trips=17 pushAttempts=7
/// idle=1 assignments=1
/// auditorLength=17 (same as trips)
/// ─────────────────────────────────────────────────────────────────────
/// ```
///
/// ---
///
/// ## Reading order
///
/// 1. `enum Match`, `final class MatchTick` — the domain types.
/// 2. `RideHailDispatchHarness` — the whole demo state machine.
/// 3. `RideHailDispatchHarness.matchOf` — the pure policy (start here
///    to understand the matching model).
/// 4. `RideHailDispatchHarness.installGates` — the two Flow pipelines.
/// 5. `RideHailDispatchHarness.accept` / `complete` — the Tissue write
///    protocol.
/// 6. `main()` — the seed, 13 scenarios, and COMPLY.
///
/// ---
///
/// ## See also
///
/// * `ride-hail-dispatch(tissue)-WalkThrough.md` — the requirement.
/// * `ride-hail-dispatch(tissue)-ARCHITECTURE.md` — the layering and ownership note.
/// * `ride-hail-dispatch(tissue)-FEATURES.md` — operator catalogue.
/// * `card-auth-pipeline(tissue)-Demo.dart` — payments sibling.
/// * `grid-demand-response(tissue)-Demo.dart` — energy sibling.
/// * `ICU-alarm-pipeline(enhanced)-Demo.dart` — clinical sibling.
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

/// The three possible outcomes of a ride-hail match decision.
///
/// `Match` is the *only* type that crosses the Flow→Tissue seam. The
/// gate Receptors produce a `Match`; the Tissue observers consume a
/// `Match` (inside a `Pulse`). Nothing else — no `MatchTick`, no
/// coordinate, no rider-id string — travels along the decision path
/// unescorted.
///
/// ### Values
///
/// | Value | Meaning | Downstream effect |
/// |---|---|---|
/// | [idle] | No action: rider in a closed zone, no drivers nearby, or otherwise unactionable | Both gates' `Filter` drop the pulse. No Tissue write. |
/// | [surge] | Show a multiplier; do not dispatch | `surgeCell` fires; the SURGE observer appends a `SURGE` event and enqueues a push job. |
/// | [dispatch] | Assign a nearby driver | `dispatchCell` fires; the DISPATCH observer appends a `DISPATCH` event, enqueues a push job, and (on ACK) calls `accept`. |
///
/// ### Why not a boolean
///
/// A boolean `shouldDispatch` cannot express the surge banner. Surge is
/// a real operator state — “show a multiplier, do not assign a car.”
/// Modelling it as a third `Match` value keeps the two gates
/// structurally identical: each is `MapValue → Distinct → Filter(x)`.
enum Match {
  /// No action — the rider is not dispatched and no surge banner fires.
  idle,

  /// Surge — show a multiplier; do not dispatch.
  surge,

  /// Dispatch — assign a nearby driver.
  dispatch,
}

/// A snapshot of the ride-hail state for a single rider at a single
/// tick.
///
/// `MatchTick` is the payload of the **snapshot bus** (`tickIn`). Every
/// sensor change — lat, lng, wait, surge, rider, zone, nearby —
/// republishes the whole tick, so any observer on the bus always sees
/// a *consistent* rider state. This is the “one tick per snapshot”
/// rule from the walkthrough.
///
/// ### Fields
///
/// | Field | Type | Range | Validated by |
/// |---|---|---|---|
/// | [riderId] | `String` | any | *(no TestCell)* |
/// | [zone] | `String` | any | *(no TestCell)* |
/// | [lat] | `double` | `−90.0 … 90.0` | `_latRange` (TestCell) |
/// | [lng] | `double` | `−180.0 … 180.0` | `_lngRange` (TestCell) |
/// | [waitSec] | `int` | `≥ 0` | `_waitRange` (TestCell) |
/// | [nearby] | `int` | any | *(no TestCell)* |
/// | [surgeX] | `double` | `1.0 … 5.0` | `_surgeRange` (TestCell) |
///
/// ### Immutability
///
/// `MatchTick` is `final class` with all-`final` fields. Once
/// constructed it never changes. Evolutions are expressed by
/// publishing a new `MatchTick` on the bus, not by mutating an
/// existing one.
///
/// ### See also
///
/// * [RideHailDispatchHarness.publishTick] — the factory.
/// * [RideHailDispatchHarness.matchOf] — the pure policy.
final class MatchTick {
  /// The rider identifier (e.g. `'R-18'`, `'R-19'`, `'R-20'`).
  ///
  /// Free-form; not validated by a `TestCell`. Carried for correlation
  /// into the trip ledger and the push queue.
  final String riderId;

  /// The zone identifier (e.g. `'DOWNTOWN'`, `'STADIUM-CURB'`).
  ///
  /// The primary correlation key for closed-stand policy. `matchOf`
  /// reads it to check the `noGo` TissueSet. The DISPATCH / SURGE
  /// observers write it into every `TripEntry` row.
  final String zone;

  /// The rider's latitude (`−90.0 … 90.0`).
  ///
  /// Validated at ingress by `_latRange`.
  final double lat;

  /// The rider's longitude (`−180.0 … 180.0`).
  ///
  /// Validated at ingress by `_lngRange`.
  final double lng;

  /// The rider's current wait in seconds (`≥ 0`).
  ///
  /// Validated at ingress by `_waitRange`. Used by `matchOf` only in
  /// the long-wait surge clause.
  final int waitSec;

  /// The number of drivers inside the match radius.
  ///
  /// Not validated at ingress. Carried for the `matchOf` dispatch
  /// clause (`nearby >= 1`) and the `matchOf` surge clause
  /// (`nearby == 0`). In a production system this would be computed
  /// by a spatial index; the demo caches it.
  final int nearby;

  /// The current surge multiplier (`1.0 … 5.0`).
  ///
  /// Validated at ingress by `_surgeRange`. Used by `matchOf` in the
  /// high-surge clause (`surgeX >= 1.8`).
  final double surgeX;

  /// Creates a [MatchTick] with the given fields.
  ///
  /// All parameters are required. The constructor does **not**
  /// validate — shape validation is the job of the `TestCell` rules on
  /// the ingress Cells (`latIn`, `lngIn`, `waitIn`, `surgeIn`) and the
  /// `_latValid` / `_lngValid` / `_waitValid` / `_surgeValid`
  /// pre-flight guards inside
  /// [RideHailDispatchHarness.publishTick].
  const MatchTick({
    required this.riderId,
    required this.zone,
    required this.lat,
    required this.lng,
    required this.waitSec,
    required this.nearby,
    required this.surgeX,
  });

  /// A human-readable rendering.
  @override
  String toString() =>
      'MatchTick($riderId, $zone, $lat, $lng, ${waitSec}s, '
          'nearby=$nearby, surge=${surgeX}x)';
}

/// A single row in the append-only trip ledger.
///
/// `TripEntry` is the atomic unit of the **fleet books**. Every row is
/// written through a `TissueList<TripEntry>` whose `TestTissue` allows
/// `add` / `addAll` and denies `remove` / `clear` / `[]=`. Once
/// written, a row is immutable for the life of the process. The city
/// auditor deputy (`trips.unmodifiable`) can read every row but cannot
/// delete one.
///
/// ### Kinds in this demo
///
/// | `kind` | Written by | Meaning |
/// |---|---|---|
/// | `DISPATCH` | DISPATCH observer | a match was assigned |
/// | `SURGE` | SURGE observer | the surge banner was shown |
/// | `PUSH` | `_drivePush` | a driver-app push was attempted |
/// | `ACCEPT` | `accept` | a driver accepted the rider |
/// | `COMPLETE` | `complete` | the trip finished; driver returned to idle |
/// | `CANCEL` | ACK observer (`"CANCEL"` only) | Distinct latches cleared without a fleet move |
///
/// ### Why append-only
///
/// The trip log is the **audit trail**. A city regulator must be able
/// to reconstruct every dispatch, every surge, and every driver
/// movement. If rows were removable, a bad match could be erased after
/// the fact. The `TestTissue` is the enforcement point.
///
/// ### See also
///
/// * [RideHailDispatchHarness.trips] — the owning `TissueList`.
/// * [RideHailDispatchHarness._tripAppendOnly] — the rule.
final class TripEntry {
  /// The semantic tag of the entry (`DISPATCH`, `SURGE`, `PUSH`,
  /// `ACCEPT`, `COMPLETE`, `CANCEL`).
  final String kind;

  /// The rider identifier the entry refers to.
  ///
  /// For `CANCEL` rows written by the `"CANCEL"` path, this is the
  /// literal `'ALL'`. Every other row carries a real rider id.
  final String riderId;

  /// A human-readable summary of the entry.
  final String detail;

  /// When the entry was committed.
  final DateTime at;

  const TripEntry({
    required this.kind,
    required this.riderId,
    required this.detail,
    required this.at,
  });

  @override
  String toString() => 'TripEntry($kind, $riderId, "$detail")';
}

/// An open driver→rider assignment.
///
/// An `Assignment` reserves one idle driver until the trip is
/// completed. `assignments` keys assignments by `driverId`, so a
/// `complete` finds the row by the same key the ACK observer wrote.
///
/// ### Invariant
///
/// After every successful `accept` / `complete` pair, the following
/// must hold:
///
/// ```
/// idleDrivers.value! + assignments.length == 12
/// ```
///
/// The demo breaks this **once** on purpose (§11) to prove the
/// non-negative `TestTissue` rejects an over-assignment, then restores
/// the books to a self-consistent state in §12.
///
/// ### Validation
///
/// `_assignmentRule` (a
/// `TestTissue<Assignment, TissueMap<String, Assignment>>`) requires
/// `driverId.isNotEmpty` and `riderId.isNotEmpty`. An assignment with
/// an empty driver or rider id is rejected at the `TissueMap` boundary
/// before it can reach the fleet table.
final class Assignment {
  /// The driver identifier. Matches the `assignments` map key.
  final String driverId;

  /// The rider identifier.
  final String riderId;

  /// The zone the assignment was created in.
  ///
  /// Carried for forensic reconstruction; the demo does not currently
  /// key any policy on it.
  final String zone;

  const Assignment({
    required this.driverId,
    required this.riderId,
    required this.zone,
  });

  @override
  String toString() => 'Assignment($driverId → $riderId, $zone)';
}

/// A single outbound job for the driver-app push pump.
///
/// The push channel — FCM, APNs — is slow and flaky. The demo treats
/// it as an I/O endpoint that may throw once and retry, exactly the
/// failure mode a real push gateway exhibits during a storm.
///
/// ### Why a queue
///
/// Outbound messages must be ordered and bounded. `pushQ` is a
/// `TissueQueue<PushJob>` with `capacity: 32`. In this build the
/// tissue queue does not drain via `removeFirst`, so the demo uses a
/// plain Dart `_pushWork` list for the pump while the tissue queue
/// serves as the **audit-side enqueue** (`addLast` →
/// `ElementAdded<PushJob>`). That split is documented in the file
/// header.
///
/// ### Validation
///
/// `_pushJobRule` accepts every job. The demo does not currently
/// reject a push job; the rule exists as a hook for future per-match
/// rate-limiting.
final class PushJob {
  /// The rider identifier the job refers to.
  final String riderId;

  /// The match to deliver.
  ///
  /// Only [Match.dispatch] and [Match.surge] jobs are produced by this
  /// demo. `Match.idle` never reaches the queue because the gates'
  /// `Filter` drops it first.
  final Match match;

  const PushJob({required this.riderId, required this.match});

  @override
  String toString() => 'PushJob($riderId, ${match.name})';
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
/// * [label] — the scenario label (`'Seed'`, `'1'`, `'SURGE'`,
///   `'COMPLY'`).
/// * [drive] — a one-line description of what the scenario drives.
void _section(String label, String drive) {
  print('');
  print('── $label ── $drive');
}

// ═════════════════════════════════════════════════════════════════════════════
// HARNESS
// ═════════════════════════════════════════════════════════════════════════════

/// The ride-hail dispatch harness — the demo's whole state machine.
///
/// One harness owns every Cell and every Tissue the demo touches. Do
/// not reuse a harness across runs; the state Cells and Tissues carry
/// history and the acceptance console assumes a fresh instance.
///
/// ### Lifecycle
///
/// 1. `final h = RideHailDispatchHarness();`
/// 2. `await h.install();`
/// 3. drive scenarios with `setRider` / `setZone` / `setLat` /
///    `setLng` / `setWait` / `setNearby` / `setSurge` / `publishTick`
///    / `ack` / `accept` / `complete`.
/// 4. `h.dispose();`
///
/// `install()` is idempotent-by-contract but not asserted; calling it
/// twice will rebuild the gates and re-attach observers, doubling
/// every downstream effect. Do not call it twice.
///
/// ### Ownership
///
/// The harness is the **sole writer** for every Tissue in the demo. It
/// exposes them as `late final` public fields so `main()` can inspect
/// them (`h.trips.length`, `h.idleDrivers.value`, …) without going
/// through a wrapper.
///
/// ### See also
///
/// * [install] — one-time bootstrap.
/// * [matchOf] — the pure policy.
/// * [installGates] — the two Flow pipelines.
/// * [accept] / [complete] — the Tissue write protocol.
class RideHailDispatchHarness {
  /// Creates an empty harness. Call [install] before driving
  /// scenarios.
  RideHailDispatchHarness();

  // ───────────────────────────────────────────────────────────────────────────
  // Constants
  // ───────────────────────────────────────────────────────────────────────────

  /// The seed idle-driver count.
  ///
  /// The invariant `idleDrivers + assignments.length ==
  /// initialIdleDrivers` is asserted implicitly by the trailer;
  /// scenario 11 deliberately breaks it and scenario 12 restores a
  /// self-consistent value.
  static const int initialIdleDrivers = 12;

  // ───────────────────────────────────────────────────────────────────────────
  // Tissue — the fleet books
  // ───────────────────────────────────────────────────────────────────────────

  /// The append-only trip ledger.
  ///
  /// A `TissueList<TripEntry>` guarded by `_tripAppendOnly`. Every
  /// `add` emits an `ElementAdded<TripEntry>` pulse on the list.
  ///
  /// ### Writers
  ///
  /// * DISPATCH observer, SURGE observer, `_drivePush`, `accept`,
  ///   `complete`, ACK observer.
  ///
  /// ### Readers
  ///
  /// * `main()`'s trailer.
  /// * The COMPLY scenario (`trips.unmodifiable`).
  late final TissueList<TripEntry> trips;

  /// The idle driver count.
  ///
  /// A `TissueValue<int>` guarded by `_nonNegativeInt`. The rule
  /// rejects any write that would make the count negative. This is the
  /// primary over-assignment guard: a dispatcher cannot assign more
  /// drivers than the fleet is holding.
  ///
  /// ### Writers
  ///
  /// * `accept` (subtract).
  /// * `complete` (add).
  /// * Scenario 11 (`set(0)` — a deliberate out-of-band force).
  ///
  /// ### Readers
  ///
  /// * The trailer.
  /// * `accept`'s over-assignment pre-check.
  late final TissueValue<int> idleDrivers;

  /// The open assignments, keyed by driver id.
  ///
  /// A `TissueMap<String, Assignment>` guarded by `_assignmentRule`.
  /// Keys are driver ids; values are `Assignment` records. The map is
  /// the *source of truth* for “which driver is currently on which
  /// rider.”
  ///
  /// ### Writers
  ///
  /// * `accept` (`assignments[driverId] = ...`).
  /// * `complete` (`assignments.remove(driverId)`).
  ///
  /// ### Readers
  ///
  /// * `assignmentCount`.
  /// * The trailer.
  late final TissueMap<String, Assignment> assignments;

  /// Closed-stand / no-go zones — a runtime-mutable set of zone codes.
  ///
  /// A `TissueSet<String>` guarded by `_noGoRule`, which requires each
  /// member to be an uppercase string of length ≥ 3 (e.g. `DOWNTOWN`,
  /// `STADIUM-CURB`).
  ///
  /// ### Why a set, not a const
  ///
  /// The set is mutated at runtime in scenario 2
  /// (`noGo.add('STADIUM-CURB')`) to demonstrate that ops can close a
  /// stand without redeploying the graph. `matchOf` reads it on every
  /// tick.
  ///
  /// ### Writers
  ///
  /// * Scenario 2 (`add('STADIUM-CURB')`).
  ///
  /// ### Readers
  ///
  /// * `matchOf`.
  late final TissueSet<String> noGo;

  /// The bounded outbound queue for driver-app jobs.
  ///
  /// A `TissueQueue<PushJob>` with `capacity: 32` and `_pushJobRule`.
  ///
  /// ### Dual role
  ///
  /// In this build the tissue queue does **not** drain via
  /// `removeFirst`, so the demo uses it as the **audit-side enqueue**
  /// only (`addLast` → `ElementAdded<PushJob>`). The pump runs on a
  /// plain Dart `_pushWork` list. See the file header for the full
  /// rationale.
  late final TissueQueue<PushJob> pushQ;

  // ───────────────────────────────────────────────────────────────────────────
  // Push pump working list
  // ───────────────────────────────────────────────────────────────────────────

  /// The pump's working list.
  ///
  /// See [pushQ]'s doc for why this list exists alongside the tissue
  /// queue. In this build the tissue queue's `removeFirst` / `remove`
  /// do not drain, so the pump uses a plain `List<PushJob>`.
  final List<PushJob> _pushWork = <PushJob>[];

  // ───────────────────────────────────────────────────────────────────────────
  // Flow — match decision pipeline
  // ───────────────────────────────────────────────────────────────────────────

  /// The latitude ingress (`−90.0 … 90.0`).
  ///
  /// `TestCell` rule: `_latRange`. Accepts any `num`; coerces to
  /// double. `setLat` returns `false` and does not update the cache
  /// when the rule rejects.
  late final IngressHandle<double> latIn;

  /// The longitude ingress (`−180.0 … 180.0`).
  ///
  /// `TestCell` rule: `_lngRange`.
  late final IngressHandle<double> lngIn;

  /// The wait ingress (`≥ 0 seconds`).
  ///
  /// `TestCell` rule: `_waitRange`.
  late final IngressHandle<int> waitIn;

  /// The surge ingress (`1.0 … 5.0`).
  ///
  /// `TestCell` rule: `_surgeRange`.
  late final IngressHandle<double> surgeIn;

  /// The rider-id ingress (cache only — no `TestCell`).
  late final IngressHandle<String> riderIn;

  /// The zone ingress (cache only — no `TestCell`).
  late final IngressHandle<String> zoneIn;

  /// The nearby-count ingress (cache only — no `TestCell`).
  late final IngressHandle<int> nearbyIn;

  /// The snapshot bus ingress — publishes a complete [MatchTick].
  ///
  /// Both gates (`dispatchCell`, `surgeCell`) subscribe via
  /// `toHandle(source: tickIn.cell)`. Every published tick reaches
  /// both gates with the same payload.
  late final IngressHandle<MatchTick> tickIn;

  /// The ACK ingress (driver id, or `"CANCEL"`).
  ///
  /// An ACK resets both Distinct latches. If the id names a driver,
  /// the observer also calls [accept]. Otherwise it appends a `CANCEL
  /// ALL` row. ACK never rebuilds the graph.
  late final IngressHandle<String> ackIn;

  // ───────────────────────────────────────────────────────────────────────────
  // Flow gates
  // ───────────────────────────────────────────────────────────────────────────

  /// The DISPATCH gate handle.
  ///
  /// Kept for symmetry and possible future use; `main()` reads
  /// [dispatchCell] directly.
  FlowHandle<Pulse<dynamic>>? dispatchHandle;

  /// The SURGE gate handle.
  FlowHandle<Pulse<dynamic>>? surgeHandle;

  /// The DISPATCH gate cell — emits only when [matchOf] returns
  /// [Match.dispatch] **and** the Distinct latch has not seen
  /// `dispatch` since the last ACK.
  ///
  /// ### Pipeline
  ///
  /// ```
  /// MapValue<MatchTick, Match>(matchOf)
  ///   + _distinctDispatch()
  ///   + Filter<Match>((m) => m == Match.dispatch)
  /// ```
  late final Cell dispatchCell;

  /// The SURGE gate cell — emits only when [matchOf] returns
  /// [Match.surge] **and** the Distinct latch has not seen `surge`
  /// since the last ACK.
  ///
  /// ### Pipeline
  ///
  /// ```
  /// MapValue<MatchTick, Match>(matchOf)
  ///   + _distinctSurge()
  ///   + Filter<Match>((m) => m == Match.surge)
  /// ```
  late final Cell surgeCell;

  // ───────────────────────────────────────────────────────────────────────────
  // Dart-side ingress cache
  // ───────────────────────────────────────────────────────────────────────────

  String _riderId = 'R-18';
  String _zone = 'DOWNTOWN';
  double _lat = 37.78;
  double _lng = -122.41;
  int _waitSec = 20;
  int _nearby = 3;
  double _surgeX = 1.0;

  // ───────────────────────────────────────────────────────────────────────────
  // Counters for the trailer
  // ───────────────────────────────────────────────────────────────────────────

  /// Number of successful [publishTick] calls (post-ingress).
  ///
  /// Incremented inside `publishTick` **after** all four `TestCell`
  /// guards pass. A rejected tick does not increment this counter.
  int ticks = 0;

  /// Number of DISPATCH pulses that made it past the Distinct latch.
  int dispatchCount = 0;

  /// Number of SURGE pulses that made it past the Distinct latch.
  int surgeCount = 0;

  /// Number of push pump attempts, **including retries**.
  ///
  /// Counts every entry into `_drivePush`'s try block. A fail-once
  /// job therefore contributes two attempts (initial + retry).
  int pushAttempts = 0;

  // ───────────────────────────────────────────────────────────────────────────
  // Push failure injection
  // ───────────────────────────────────────────────────────────────────────────

  /// When `true`, the next push attempt throws once before the retry
  /// succeeds. Reset to `false` after the injected failure fires.
  bool pushFailOnce = false;

  bool _pushHasFailed = false;

  // ───────────────────────────────────────────────────────────────────────────
  // Distinct latches
  // ───────────────────────────────────────────────────────────────────────────

  /// The last [Match] seen by the DISPATCH Distinct latch. `null`
  /// means the latch is reset (fresh after [resetDistinct]).
  Match? _lastDispatch;

  /// The last [Match] seen by the SURGE Distinct latch.
  Match? _lastSurge;

  /// The last tick published — captured so the DISPATCH / SURGE
  /// observers can correlate the decision with the correct rider and
  /// zone.
  MatchTick? _currentTick;

  final List<EgressHandle> _observers = [];

  // ───────────────────────────────────────────────────────────────────────────
  // TestTissue rules — ONLY used on Tissue constructors
  // ───────────────────────────────────────────────────────────────────────────

  /// Append-only rule for [trips].
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
  static final TestTissue<TripEntry, TissueList<TripEntry>>
  _tripAppendOnly =
  TestTissue<TripEntry, TissueList<TripEntry>>(
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

  /// Non-negative integer rule for [idleDrivers].
  ///
  /// Rejects any write that would make the count negative. This is the
  /// over-assignment guard: a dispatcher cannot assign more drivers
  /// than the fleet is holding.
  static final TestTissue<int, TissueValue<int>> _nonNegativeInt =
  TestTissue<int, TissueValue<int>>(
        (value, {host, arguments, user}) {
      if (value is int) return value >= 0;
      return true;
    },
  );

  /// Assignment shape rule for [assignments].
  ///
  /// Requires `driverId.isNotEmpty` and `riderId.isNotEmpty`.
  static final TestTissue<Assignment, TissueMap<String, Assignment>>
  _assignmentRule =
  TestTissue<Assignment, TissueMap<String, Assignment>>(
        (value, {host, arguments, user}) {
      if (value is Assignment) {
        return value.driverId.isNotEmpty && value.riderId.isNotEmpty;
      }
      return true;
    },
  );

  /// No-go zone rule for [noGo].
  ///
  /// Requires an uppercase string of length ≥ 3.
  static final TestTissue<String, TissueSet<String>> _noGoRule =
  TestTissue<String, TissueSet<String>>(
        (value, {host, arguments, user}) {
      if (value is String) {
        return value.length >= 3 && value == value.toUpperCase();
      }
      return true;
    },
  );

  /// Push job rule for [pushQ]. Accepts every job.
  static final TestTissue<PushJob, TissueQueue<PushJob>> _pushJobRule =
  TestTissue<PushJob, TissueQueue<PushJob>>(
        (value, {host, arguments, user}) => true,
  );

  // ───────────────────────────────────────────────────────────────────────────
  // TestCell rules — ONLY used on Cell.ingress
  // ───────────────────────────────────────────────────────────────────────────

  /// Latitude shape: `−90.0 … 90.0` inclusive.
  ///
  /// ### Pulse unwrapping
  ///
  /// The ingress wraps the input in a `Pulse` before calling the rule,
  /// so the rule unwraps `Pulse.payload` before applying the range
  /// check. Without this the rule sees a `Pulse<double>` and rejects
  /// every emission.
  static final TestCell<Cell> _latRange = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = value is Pulse ? value.payload : value;
      if (v is! num) return false;
      final d = v.toDouble();
      return d >= -90.0 && d <= 90.0;
    },
  );

  /// Longitude shape: `−180.0 … 180.0` inclusive.
  static final TestCell<Cell> _lngRange = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = value is Pulse ? value.payload : value;
      if (v is! num) return false;
      final d = v.toDouble();
      return d >= -180.0 && d <= 180.0;
    },
  );

  /// Wait shape: `≥ 0 seconds`.
  static final TestCell<Cell> _waitRange = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = value is Pulse ? value.payload : value;
      if (v is! int) return false;
      return v >= 0;
    },
  );

  /// Surge shape: `1.0 … 5.0` inclusive.
  static final TestCell<Cell> _surgeRange = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = value is Pulse ? value.payload : value;
      if (v is! num) return false;
      final d = v.toDouble();
      return d >= 1.0 && d <= 5.0;
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
  /// This must run **once**, before any scenario drives ingress.
  /// Calling it twice rebuilds the gates and re-attaches observers;
  /// every DISPATCH / SURGE pulse would then fire twice.
  ///
  /// ### Steps
  ///
  /// 1. Build the five Tissue collections with their `TestTissue`
  ///    rules.
  /// 2. Build the ten Flow ingress handles with their `TestCell`
  ///    rules.
  /// 3. Call [installGates] to wire the two decision pipelines.
  /// 4. Attach the DISPATCH, SURGE, and ACK observers.
  ///
  /// ### Trace prints
  ///
  /// The console output is emitted by the writers themselves — the
  /// observers, `_drivePush`, `accept`, `complete`, and the scenario
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
    trips = TissueList<TripEntry>(testRule: _tripAppendOnly);

    idleDrivers = TissueValue<int>(
      initialIdleDrivers,
      testRule: _nonNegativeInt,
    );

    assignments = TissueMap<String, Assignment>(
      properties:
      TissueMapNucleus<String, Assignment>(testRule: _assignmentRule),
    );

    noGo = TissueSet<String>(<String>[], testRule: _noGoRule);

    pushQ = TissueQueue<PushJob>(
      capacity: 32,
      testRule: _pushJobRule,
    );

    // ── Flow ingress ──────────────────────────────────────────────────────
    latIn = Cell.ingress<double>(testRule: _latRange);
    lngIn = Cell.ingress<double>(testRule: _lngRange);
    waitIn = Cell.ingress<int>(testRule: _waitRange);
    surgeIn = Cell.ingress<double>(testRule: _surgeRange);

    riderIn = Cell.ingress<String>();
    zoneIn = Cell.ingress<String>();
    nearbyIn = Cell.ingress<int>();

    tickIn = Cell.ingress<MatchTick>();
    ackIn = Cell.ingress<String>();

    // ── Gates ─────────────────────────────────────────────────────────────
    installGates();

    // ── DISPATCH observer ─────────────────────────────────────────────────
    //
    // Fires when `dispatchCell` emits `Match.dispatch` (post-Distinct,
    // post-Filter). Sequence:
    //   1. dispatchCount++
    //   2. trips.add(DISPATCH …)
    //   3. pushQ.addLast(PushJob(dispatch)) + _pushWork.add + _drivePush()
    _observers.add(Cell.observe(
      source: dispatchCell,
      effect: (Pulse pulse) {
        if (pulse.payload == Match.dispatch) {
          dispatchCount++;
          final t = _currentTick;
          if (t != null) {
            trips.add(TripEntry(
              kind: 'DISPATCH',
              riderId: t.riderId,
              detail: 'zone=${t.zone} nearby=${t.nearby}',
              at: DateTime.now(),
            ));
            print('[trips] DISPATCH ${t.riderId} — '
                'zone=${t.zone} nearby=${t.nearby}');

            final job =
            PushJob(riderId: t.riderId, match: Match.dispatch);
            pushQ.addLast(job);
            print('[pushQ] enqueued $job');

            _pushWork.add(job);
            _drivePush();
          }
        }
      },
    ));

    // ── SURGE observer ────────────────────────────────────────────────────
    //
    // Fires when `surgeCell` emits `Match.surge` (post-Distinct,
    // post-Filter). Does NOT touch idleDrivers or assignments — a
    // surge is a decision, not a fleet move. Only writes the trip log
    // and enqueues a push job.
    _observers.add(Cell.observe(
      source: surgeCell,
      effect: (Pulse pulse) {
        if (pulse.payload == Match.surge) {
          surgeCount++;
          final t = _currentTick;
          if (t != null) {
            trips.add(TripEntry(
              kind: 'SURGE',
              riderId: t.riderId,
              detail: 'surge=${t.surgeX} wait=${t.waitSec}',
              at: DateTime.now(),
            ));
            print('[trips] SURGE ${t.riderId} — '
                'surge=${t.surgeX} wait=${t.waitSec}');

            final job = PushJob(riderId: t.riderId, match: Match.surge);
            pushQ.addLast(job);
            print('[pushQ] enqueued $job');

            _pushWork.add(job);
            _drivePush();
          }
        }
      },
    ));

    // ── ACK observer ──────────────────────────────────────────────────────
    //
    // Fires on every ackIn emission.
    //   1. resetDistinct() — clears both latches.
    //   2. If the payload names a driver, call accept.
    //      Otherwise append a CANCEL ALL row.
    //
    // ACK never calls toHandle. The gates stay as they are.
    _observers.add(Cell.observe(
      source: ackIn.cell,
      effect: (Pulse pulse) {
        final who = pulse.payload;
        resetDistinct();
        if (who is String && who.isNotEmpty && who != 'CANCEL') {
          accept(who);
        } else {
          trips.add(TripEntry(
            kind: 'CANCEL',
            riderId: 'ALL',
            detail: 'distinct cleared',
            at: DateTime.now(),
          ));
          print('[trips] CANCEL ALL — distinct cleared');
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
  /// MapValue<MatchTick, Match>(matchOf)
  ///   + Distinct (custom FlowInstruction)
  ///   + Filter<Match>(x)
  /// ```
  ///
  /// The Distinct instruction is per-gate so a fresh DISPATCH (after an
  /// ACK) can fire even if the previous match had the same value. The
  /// two latches are independent: a SURGE does not clear the DISPATCH
  /// latch and vice versa.
  ///
  /// ### Why Distinct comes before Filter
  ///
  /// Distinct records the decision the pipeline *made* — including
  /// `idle`. If Filter ran first, a sequence `idle → dispatch` would
  /// still work, but `dispatch → idle → dispatch` would not: the
  /// second `dispatch` would be suppressed because the latch still
  /// held `dispatch` from the first tick. Running Distinct first means
  /// `dispatch → idle → dispatch` fires twice.
  void installGates() {
    // DISPATCH: MapValue → Distinct → Filter(dispatch)
    final dispatchFlow = MapValue<MatchTick, Match>(
          (t) => matchOf(t, noGo),
    ) +
        _distinctDispatch() +
        Filter<Match>((m) => m == Match.dispatch);

    dispatchHandle = dispatchFlow.toHandle(source: tickIn.cell);
    dispatchCell = dispatchHandle!.cell;

    // SURGE: MapValue → Distinct → Filter(surge)
    final surgeFlow = MapValue<MatchTick, Match>(
          (t) => matchOf(t, noGo),
    ) +
        _distinctSurge() +
        Filter<Match>((m) => m == Match.surge);

    surgeHandle = surgeFlow.toHandle(source: tickIn.cell);
    surgeCell = surgeHandle!.cell;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Push pump
  // ───────────────────────────────────────────────────────────────────────────

  /// Drains the pump's working list with a single-shot retry.
  ///
  /// ### Why the tissue queue is not used directly
  ///
  /// In this build `TissueQueue.removeFirst` / `remove` do not drain
  /// the container. The tissue queue stays as the audit-side enqueue
  /// (`addLast` → `ElementAdded<PushJob>`) and the pump runs on the
  /// plain Dart `_pushWork` list.
  ///
  /// ### Failure semantics
  ///
  /// If [pushFailOnce] is set and this is the first attempt, the mock
  /// throws. The pump catches it and retries once. [pushAttempts]
  /// increments for both attempts, exposing the retry to the trailer.
  Future<void> _drivePush() async {
    if (_pushWork.isEmpty) return;
    final job = _pushWork.removeAt(0);

    try {
      pushAttempts++;
      if (pushFailOnce && !_pushHasFailed) {
        _pushHasFailed = true;
        throw StateError('push transient');
      }
      trips.add(TripEntry(
        kind: 'PUSH',
        riderId: job.riderId,
        detail: job.match.name,
        at: DateTime.now(),
      ));
      print('[trips] PUSH ${job.riderId} — ${job.match.name}');
    } catch (_) {
      try {
        pushAttempts++;
        trips.add(TripEntry(
          kind: 'PUSH',
          riderId: job.riderId,
          detail: '${job.match.name} (retry)',
          at: DateTime.now(),
        ));
        print('[trips] PUSH ${job.riderId} — '
            '${job.match.name} (retry)');
      } catch (_) {
        // give up
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Flow instructions (Distinct)
  // ───────────────────────────────────────────────────────────────────────────

  /// Builds the DISPATCH Distinct instruction.
  ///
  /// Returns `null` (signal terminated) if the incoming match matches
  /// [_lastDispatch]. Otherwise updates the latch and passes the pulse
  /// on.
  ///
  /// The latch is a plain `Match?` field, not a `Box` or a `Cell`,
  /// because the instruction closure captures `this`. That's what lets
  /// [resetDistinct] clear the latch without rebuilding the graph.
  FlowInstruction _distinctDispatch() {
    return FlowInstruction((pulse, {cell, user}) {
      final m = pulse.payload;
      if (_lastDispatch == m) return null;
      _lastDispatch = m;
      return pulse;
    });
  }

  /// Builds the SURGE Distinct instruction. Same contract as
  /// [_distinctDispatch] but with its own latch.
  FlowInstruction _distinctSurge() {
    return FlowInstruction((pulse, {cell, user}) {
      final m = pulse.payload;
      if (_lastSurge == m) return null;
      _lastSurge = m;
      return pulse;
    });
  }

  /// Clears both Distinct latches.
  ///
  /// Called by the ACK observer and by scenario 13 (`ack('CANCEL')`).
  /// After a reset, the next DISPATCH or SURGE decision fires
  /// regardless of its value — even if it equals the previous one.
  ///
  /// ### Why both latches
  ///
  /// A driver accepting a job (or a rider cancelling) resets the
  /// whole dispatch state. Two separate ACK paths would let a stale
  /// SURGE linger after a DISPATCH was accepted, which is a real
  /// operational bug.
  void resetDistinct() {
    _lastDispatch = null;
    _lastSurge = null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // matchOf — pure policy
  // ───────────────────────────────────────────────────────────────────────────

  /// Evaluates the match for a [MatchTick] against the [noGoSet].
  ///
  /// ### Rules
  ///
  /// | Condition | Match |
  /// |---|---|
  /// | `t.zone` in `noGoSet` | `idle` |
  /// | `t.nearby == 0` and `t.waitSec >= 180` | `surge` |
  /// | `t.surgeX >= 1.8` | `surge` |
  /// | `t.nearby >= 1` | `dispatch` |
  /// | else | `idle` |
  ///
  /// The order matters. A closed zone returns `idle` before any
  /// nearby check, so `STADIUM-CURB` with 3 drivers nearby is still
  /// `idle`.
  ///
  /// ### Purity
  ///
  /// This function is `static`, has no `await`, does no I/O, and
  /// touches no fleet state. It reads [noGoSet] and nothing else. It
  /// is the *entire* match policy of the demo, and it can be unit
  /// tested with a bare `MatchTick` and an empty `TissueSet`.
  ///
  /// ### Why static
  ///
  /// Purity is enforced by the type system: a `static` method cannot
  /// reach `this`, so it cannot accidentally call `idleDrivers.set` or
  /// `trips.add`. If the policy ever needs instance state, promote it
  /// to an instance method and accept the reduced testability.
  ///
  /// ### See also
  ///
  /// * [installGates] — where this policy is wired into both gates.
  /// * [noGo] — the TissueSet the policy reads.
  static Match matchOf(MatchTick t, TissueSet<String> noGoSet) {
    if (noGoSet.contains(t.zone)) return Match.idle;
    if (t.nearby == 0 && t.waitSec >= 180) return Match.surge;
    if (t.surgeX >= 1.8) return Match.surge;
    if (t.nearby >= 1) return Match.dispatch;
    return Match.idle;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Bus — setters and publishTick
  // ───────────────────────────────────────────────────────────────────────────

  /// Sets the latitude cache.
  ///
  /// Returns `true` if the ingress `TestCell` accepted the value, in
  /// which case [_lat] is updated. Returns `false` and does **not**
  /// update the cache when the rule rejects.
  bool setLat(double lat) {
    final accepted = latIn.emit(lat);
    if (accepted) _lat = lat;
    return accepted;
  }

  /// Sets the longitude cache. Same contract as [setLat].
  bool setLng(double lng) {
    final accepted = lngIn.emit(lng);
    if (accepted) _lng = lng;
    return accepted;
  }

  /// Sets the wait cache. Same contract as [setLat].
  bool setWait(int sec) {
    final accepted = waitIn.emit(sec);
    if (accepted) _waitSec = sec;
    return accepted;
  }

  /// Sets the surge cache. Same contract as [setLat].
  bool setSurge(double x) {
    final accepted = surgeIn.emit(x);
    if (accepted) _surgeX = x;
    return accepted;
  }

  /// Sets the rider cache. No `TestCell` — always returns `true`.
  bool setRider(String riderId) {
    _riderId = riderId;
    return true;
  }

  /// Sets the zone cache. No `TestCell` — always returns `true`.
  ///
  /// The zone is checked by `matchOf` against [noGo], not at ingress.
  /// An unknown zone is not a shape error; it is a policy input.
  bool setZone(String zone) {
    _zone = zone;
    return true;
  }

  /// Sets the nearby-count cache. No `TestCell` — always returns
  /// `true`.
  bool setNearby(int n) {
    _nearby = n;
    return true;
  }

  /// Publishes a complete [MatchTick] onto the snapshot bus.
  ///
  /// ### Pre-flight guards
  ///
  /// Before emitting, the method re-checks `_latValid`,
  /// `_lngValid`, `_waitValid`, and `_surgeValid`. These mirror the
  /// `TestCell` rules exactly. They exist because scenario 8 needs to
  /// *report* a rejection without publishing (calling `latIn.emit`
  /// directly would also fail, but the double-check makes the intent
  /// explicit and lets `publishTick` return `false` cleanly).
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
    if (!_latValid(_lat)) {
      print('[ingress] lat $_lat rejected by TestCell');
      return false;
    }
    if (!_lngValid(_lng)) {
      print('[ingress] lng $_lng rejected by TestCell');
      return false;
    }
    if (!_waitValid(_waitSec)) {
      print('[ingress] wait $_waitSec rejected by TestCell');
      return false;
    }
    if (!_surgeValid(_surgeX)) {
      print('[ingress] surge $_surgeX rejected by TestCell');
      return false;
    }

    final t = MatchTick(
      riderId: _riderId,
      zone: _zone,
      lat: _lat,
      lng: _lng,
      waitSec: _waitSec,
      nearby: _nearby,
      surgeX: _surgeX,
    );
    _currentTick = t;
    ticks++;
    tickIn.emit(t);
    await Future.delayed(Duration.zero);
    return true;
  }

  /// Static validator mirroring `_latRange`.
  static bool _latValid(double v) => v >= -90.0 && v <= 90.0;

  /// Static validator mirroring `_lngRange`.
  static bool _lngValid(double v) => v >= -180.0 && v <= 180.0;

  /// Static validator mirroring `_waitRange`.
  static bool _waitValid(int v) => v >= 0;

  /// Static validator mirroring `_surgeRange`.
  static bool _surgeValid(double v) => v >= 1.0 && v <= 5.0;

  /// Publishes an ACK onto [ackIn].
  ///
  /// ### Ack payloads
  ///
  /// * A driver id (`'D-7'`) — the ACK observer clears the Distinct
  ///   latches and calls [accept] for that driver.
  /// * `'CANCEL'` — the ACK observer clears the latches and appends a
  ///   `CANCEL ALL` row, without an accept.
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
  // Fleet — TissueValue + TissueMap
  // ───────────────────────────────────────────────────────────────────────────

  /// Attempts to accept a driver for the current rider.
  ///
  /// ### v1 write protocol
  ///
  /// 1. Pre-check `idleDrivers` for over-assignment.
  /// 2. Write `assignments[driverId]`.
  /// 3. Write `idleDrivers` (subtract 1).
  /// 4. Append `ACCEPT` to the trip log.
  ///
  /// If step 3 rejects, the prior writes are compensated and the
  /// method returns `false` without leaving a partial state.
  ///
  /// ### Return
  ///
  /// * `true` — the assignment was applied; `idleDrivers` decreased
  ///   by 1.
  /// * `false` — the pre-check failed (no idle drivers) or the idle
  ///   write was rejected.
  ///
  /// ### Invariant
  ///
  /// After a successful call, `idleDrivers.value! + assignments.length`
  /// is `initialIdleDrivers` less any out-of-band force (see §11 in
  /// the walkthrough).
  ///
  /// ### See also
  ///
  /// * [complete] — the inverse.
  /// * [_nonNegativeInt] — the `TestTissue` guarding the count.
  bool accept(String driverId) {
    final before = idleDrivers.value ?? 0;
    if (before <= 0) {
      return false;
    }
    final riderId = _riderId;
    assignments[driverId] = Assignment(
      driverId: driverId,
      riderId: riderId,
      zone: _zone,
    );
    final okIdle = idleDrivers.set(before - 1);
    if (!okIdle) {
      assignments.remove(driverId);
      return false;
    }
    print('[idleDrivers] $before → ${before - 1}');
    print('[assignments] $driverId → $riderId');

    trips.add(TripEntry(
      kind: 'ACCEPT',
      riderId: riderId,
      detail: 'driver=$driverId',
      at: DateTime.now(),
    ));
    print('[trips] ACCEPT $driverId — rider=$riderId');
    return true;
  }

  /// Completes an assignment, returning the driver to idle.
  ///
  /// ### v1 write protocol
  ///
  /// 1. Look up `assignments[driverId]`.
  /// 2. Remove the map row.
  /// 3. Add back to `idleDrivers`.
  /// 4. Append `COMPLETE` to the trip log.
  ///
  /// ### Return
  ///
  /// * `true` — the assignment was found and completed.
  /// * `false` — no open assignment for that driver. `idleDrivers` is
  ///   unchanged.
  ///
  /// ### The “no open assignment” case
  ///
  /// A complete with no matching assignment is not an error — it is a
  /// no-op.
  bool complete(String driverId) {
    final a = assignments[driverId];
    if (a == null) return false;
    assignments.remove(driverId);
    print('[assignments] $driverId removed');

    final before = idleDrivers.value ?? 0;
    idleDrivers.set(before + 1);
    print('[idleDrivers] $before → ${before + 1}');

    trips.add(TripEntry(
      kind: 'COMPLETE',
      riderId: a.riderId,
      detail: 'driver=$driverId',
      at: DateTime.now(),
    ));
    print('[trips] COMPLETE $driverId — rider=${a.riderId}');
    return true;
  }

  /// The number of open assignments currently in [assignments].
  int get assignmentCount => assignments.length;

  // ───────────────────────────────────────────────────────────────────────────
  // Teardown
  // ───────────────────────────────────────────────────────────────────────────

  /// Stops every observer attached during [install].
  ///
  /// ### When to use
  ///
  /// Call at the end of `main`, after the trailer has printed. The
  /// demo is a one-shot process; on a long-lived host, `dispose` would
  /// be the point at which the harness releases its subscriptions.
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

/// Main entry point for the ride-hail dispatch demo.
///
/// ### Execution order is critical
///
/// 1. Build the harness via [RideHailDispatchHarness.install].
/// 2. Seed the sensors with the initial state.
/// 3. Run scenarios 1–13, SURGE, and COMPLY in order.
/// 4. Print the trailer and dispose.
///
/// ### Scenario index
///
/// | Banner | Demonstrates |
/// |---|---|
/// | Seed | bus + Filter; first DISPATCH on seed (explicit choice) |
/// | 1 | Distinct on `dispatch` |
/// | 2 | TissueSet feeds `matchOf` (closed zone → idle) |
/// | 3 | Distinct `idle`→`dispatch` |
/// | 4 | Distinct holds |
/// | 5 | Distinct keys on Match, not wait |
/// | SURGE | second Receptor, independent latch |
/// | 6 | ACK clears latches + accept |
/// | 7 | fresh dispatch after reset |
/// | 8 | TestCell rejects at ingress |
/// | 9 | push retry, one new DISPATCH |
/// | 10 | TissueMap, second driver |
/// | 11 | non-negative TestTissue rejects |
/// | 12 | complete returns driver to idle |
/// | 13 | CANCEL without open assignment invents nothing |
/// | COMPLY | deputy is live, writes blocked |
Future<void> main() async {
  print('========================================================================');
  print(' ride-hail-dispatch(tissue)-Demo.dart');
  print(' Flow owns the match decision. Tissue owns the fleet books.');
  print('========================================================================');

  final h = RideHailDispatchHarness();
  await h.install();

  // ── Seed ────────────────────────────────────────────────────────────────
  _section('Seed', 'DOWNTOWN / 3 nearby / wait 20 / surge 1.0');
  h.setRider('R-18');
  h.setZone('DOWNTOWN');
  h.setLat(37.78);
  h.setLng(-122.41);
  h.setWait(20);
  h.setNearby(3);
  h.setSurge(1.0);
  final s0 = h.dispatchCount;
  await h.publishTick();
  print('  new dispatches: ${h.dispatchCount - s0}');
  print('  trips.isEmpty=${h.trips.isEmpty}');

  // ── 1 ───────────────────────────────────────────────────────────────────
  _section('1', 'repeat same tick');
  final s1 = h.dispatchCount;
  await h.publishTick();
  print('  new dispatches: ${h.dispatchCount - s1}');

  // ── 2 ───────────────────────────────────────────────────────────────────
  _section('2', "noGo.add('STADIUM-CURB'), tick zone STADIUM-CURB");
  h.noGo.add('STADIUM-CURB');
  print('[noGo] +STADIUM-CURB');
  h.setZone('STADIUM-CURB');
  h.setNearby(3);
  final s2 = h.dispatchCount;
  await h.publishTick();
  print('  new dispatches: ${h.dispatchCount - s2}');

  // ── 3 ───────────────────────────────────────────────────────────────────
  _section('3', 'back to DOWNTOWN');
  h.setZone('DOWNTOWN');
  h.setNearby(3);
  final s3 = h.dispatchCount;
  await h.publishTick();
  print('  new dispatches: ${h.dispatchCount - s3}');

  // ── 4 ───────────────────────────────────────────────────────────────────
  _section('4', 'same downtown again');
  final s4 = h.dispatchCount;
  await h.publishTick();
  print('  new dispatches: ${h.dispatchCount - s4}');

  // ── 5 ───────────────────────────────────────────────────────────────────
  _section('5', 'wait 400 nearby 3');
  h.setWait(400);
  h.setNearby(3);
  final s5 = h.dispatchCount;
  await h.publishTick();
  print('  new dispatches: ${h.dispatchCount - s5}');

  // ── SURGE ───────────────────────────────────────────────────────────────
  _section('SURGE', 'nearby 0 wait 200 surge 2.1 downtown');
  h.setRider('R-19');
  h.setZone('DOWNTOWN');
  h.setNearby(0);
  h.setWait(200);
  h.setSurge(2.1);
  final w0 = h.surgeCount;
  await h.publishTick();
  print('  new surges: ${h.surgeCount - w0}');

  // ── 6 ───────────────────────────────────────────────────────────────────
  _section('6', 'nearby 3 / surge 1.0 then ACK accept D-7');
  h.setRider('R-18');
  h.setZone('DOWNTOWN');
  h.setNearby(3);
  h.setWait(20);
  h.setSurge(1.0);
  await h.publishTick();
  await h.ack('D-7');
  print('  idle=${h.idleDrivers.value} '
      'assignments=${h.assignmentCount}');

  // ── 7 ───────────────────────────────────────────────────────────────────
  _section('7', 'new rider downtown nearby 3');
  h.setRider('R-19');
  h.setZone('DOWNTOWN');
  h.setNearby(3);
  final s7 = h.dispatchCount;
  await h.publishTick();
  print('  new dispatches: ${h.dispatchCount - s7}');

  // ── 8 ───────────────────────────────────────────────────────────────────
  _section('8', 'lat 91, lng 200, wait -1');
  final t8 = h.trips.length;
  final rejectedLat = h.setLat(91.0);
  final rejectedLng = h.setLng(200.0);
  final rejectedWait = h.setWait(-1);
  print('  lat 91 accepted=$rejectedLat');
  print('  lng 200 accepted=$rejectedLng');
  print('  wait -1 accepted=$rejectedWait');
  print('  trips grew: ${h.trips.length - t8}');

  // ── 9 ───────────────────────────────────────────────────────────────────
  _section('9', 'ACK cancel, recover, downtown, push fail-once');
  await h.ack('CANCEL');
  h.setRider('R-20');
  h.setZone('DOWNTOWN');
  h.setNearby(3);
  h.setWait(20);
  h.setSurge(1.0);
  final s9 = h.dispatchCount;
  h.pushFailOnce = true;
  await h.publishTick();
  print('  new dispatches: ${h.dispatchCount - s9}');
  print('  pushAttempts=${h.pushAttempts}');

  // ── 10 ──────────────────────────────────────────────────────────────────
  _section('10', 'accept D-8 on scenario 7');
  final ok10 = h.accept('D-8');
  print('  accept ok=$ok10');
  print('  idle=${h.idleDrivers.value} '
      'assignments=${h.assignmentCount}');

  // ── 11 ──────────────────────────────────────────────────────────────────
  _section('11', 'force idle to 0, then accept D-9');
  h.idleDrivers.set(0);
  final ok11 = h.accept('D-9');
  print('  accept ok=$ok11');
  print('  idleDrivers=${h.idleDrivers.value} '
      'assignments=${h.assignmentCount}');

  // ── 12 ──────────────────────────────────────────────────────────────────
  _section('12', 'complete D-7');
  final ok12 = h.complete('D-7');
  print('  complete ok=$ok12');
  print('  idle=${h.idleDrivers.value} '
      'assignments=${h.assignmentCount}');

  // ── 13 ──────────────────────────────────────────────────────────────────
  _section('13', 'unmatched CANCEL');
  final i13 = h.idleDrivers.value;
  final a13 = h.assignmentCount;
  await h.ack('CANCEL');
  print('  idle=${h.idleDrivers.value} '
      'assignments=${h.assignmentCount} '
      'unchanged=${h.idleDrivers.value == i13 && h.assignmentCount == a13}');

  // ── COMPLY ──────────────────────────────────────────────────────────────
  _section('COMPLY', 'auditor.add(...) blocked; length == trips.length');
  final auditor = h.trips.unmodifiable;
  final tripsBefore = h.trips.length;
  var blocked = false;
  try {
    auditor.add(TripEntry(
      kind: 'HACK',
      riderId: 'X',
      detail: 'attempted by auditor',
      at: DateTime.now(),
    ));
    blocked = h.trips.length == tripsBefore;
  } catch (_) {
    blocked = true;
  }
  print('  auditor.add blocked=$blocked');
  print('  auditor.length=${auditor.length} '
      'trips.length=${h.trips.length}');

  // ── Trailer ─────────────────────────────────────────────────────────────
  print('');
  print('------------------------------------------------------------------------');
  print('ticks=${h.ticks} dispatches=${h.dispatchCount} '
      'surges=${h.surgeCount} trips=${h.trips.length} '
      'pushAttempts=${h.pushAttempts}');
  print('idle=${h.idleDrivers.value} '
      'assignments=${h.assignmentCount}');
  print('auditorLength=${auditor.length} (same as trips)');
  print('------------------------------------------------------------------------');

  h.dispose();
}