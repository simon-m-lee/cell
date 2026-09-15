// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// # Ride-Hail Dispatch — Cell variant: one FlowInstruction, one chain
///
/// **Domain:** ride-hailing / mobility dispatch (match a rider ping to a
/// driver, hold a surge banner, keep a trip ledger the city can audit).
///
/// **Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`.
///
/// **Sibling:** `ride-hail-dispatch(tissue)-Demo.dart` builds the same
/// domain with two ad-hoc gate closures. This file is the **Cell
/// variant**: it demonstrates how to
///
/// 1. extend [FlowInstructionBase] with a single instruction —
///    [MatchDecisionInstruction] — that encapsulates the whole match
///    policy, the distinct-until-changed latch, and the idle filter,
///    exactly the way `AsyncMap` extends [FlowInstructionBase] in
///    `package:cell_flow/src/instruction/async_map.dart`, and
/// 2. put that instruction together with a stock [MapValue] into a
///    `FlowInstructionChain` (via `operator +`) before materialising
///    the chain into a Cell with [FlowInstruction.toHandle].
///
/// The custom instruction exposes a public API —
/// [MatchDecisionInstruction.matchOf],
/// [MatchDecisionInstruction.lastDecision], and
/// [MatchDecisionInstruction.reset] — which the harness uses when
/// turning the instruction into a Cell and when the ACK authority
/// clears the latches.
///
/// ---
///
/// ## The seam
///
/// * The **custom instruction** answers: *“Is this tick a DISPATCH, a
///   SURGE, or an IDLE, and did it change since the last tick?”*
/// * **Tissue** answers: *“What did the books just record, and did
///   drivers move?”*
/// * The **observer** on each gate Cell is the only glue.
///
/// Nothing about the matching policy touches the fleet table. Nothing
/// about the fleet table influences the matching policy.
///
/// ---
///
/// ## The chain
///
/// ```text
/// tickIn ──► MatchDecisionInstruction(MatchTick → MatchDecision)
///                + MapValue(MatchDecision → Match)
///                └──► toHandle ──► dispatchCell / surgeCell
/// ```
///
/// `MatchDecisionInstruction` owns the essential logic (type check,
/// policy, latch, idle suppression). The stock `MapValue` only narrows
/// the payload to the `Match` that is allowed to cross the Flow→Tissue
/// seam. The `+` composes the two Instructions into a
/// `FlowInstructionChain`, and `toHandle` turns that chain into a Cell.
///
/// ---
///
/// ## Documented deviations from the walkthrough
///
/// This file follows the same self-consistent scenario output as
/// `ride-hail-dispatch(tissue)-Demo.dart`:
///
/// * §10 — `accept('D-8')` assigns `D-8 → R-20` because `_riderId` is
///   still `R-20` from §9.
/// * Trailer — `ticks=10 dispatches=5 surges=1 trips=17
///   pushAttempts=7` are the self-consistent counts.
/// * §12 — after `complete('D-7')` the books are `idle=1,
///   assignments=1`.
///
/// ---
///
/// ## Expected console output
///
/// ```text
/// ╔══════════════════════════════════════════════════════════════╗
/// ║  ride-hail-dispatch(Cell)-Demo.dart                          ║
/// ║  One FlowInstruction encapsulates the match.                 ║
/// ║  A FlowInstructionChain assembles the pieces.                ║
/// ╚══════════════════════════════════════════════════════════════╝
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
/// ─────────────────────────────────────────────────────────────────
/// ticks=10 dispatches=5 surges=1 trips=17 pushAttempts=7
/// idle=1 assignments=1
/// dispatchGate.lastDecision=null surgeGate.lastDecision=null
/// auditorLength=17 (same as trips)
/// ─────────────────────────────────────────────────────────────────
/// ```
///
/// ---
///
/// ## Reading order
///
/// 1. `enum Match`, `final class MatchTick`, `final class MatchDecision` —
///    the domain types.
/// 2. `MatchDecisionInstruction` — the custom [FlowInstructionBase]
///    subclass that owns the match logic.
/// 3. `RideHailDispatchHarness.installGates` — where the instruction is
///    chained with a stock [MapValue] and materialised with
///    [FlowInstruction.toHandle].
/// 4. `RideHailDispatchHarness.accept` / `complete` — the Tissue write
///    protocol.
/// 5. `main()` — the seed, 13 scenarios, and COMPLY.
///
/// ---
///
/// ## See also
///
/// * `ride-hail-dispatch(Cell)-WalkThrough.md` — the requirement.
/// * `ride-hail-dispatch(Cell)-ARCHITECTURE.md` — the layering and ownership note.
/// * `ride-hail-dispatch(Cell)-FEATURES.md` — operator catalogue.
/// * `ride-hail-dispatch(tissue)-Demo.dart` — the Tissue-variant sibling.
/// * `package:cell_flow/src/instruction/async_map.dart` — the `AsyncMap`
///   pattern this custom instruction follows.
library;

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_tissue/cell_tissue.dart';

// ignore_for_file: avoid_print, unused_local_variable, file_names

// ═════════════════════════════════════════════════════════════════════════════
// DOMAIN
// ═════════════════════════════════════════════════════════════════════════════

/// The three possible outcomes of a ride-hail match decision.
///
/// `Match` is the *only* type that crosses the Flow→Tissue seam. The
/// chain's final [MapValue] projects [MatchDecision] down to `Match`;
/// the Tissue observers consume that `Match` inside a `Pulse`.
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
/// `MatchTick` is the payload of the snapshot bus (`tickIn`). Every
/// sensor change — lat, lng, wait, surge, rider, zone, nearby —
/// republishes the whole tick, so every consumer of the bus sees a
/// consistent rider state.
final class MatchTick {
  /// The rider identifier (e.g. `'R-18'`, `'R-19'`, `'R-20'`).
  final String riderId;

  /// The zone identifier (e.g. `'DOWNTOWN'`, `'STADIUM-CURB'`).
  final String zone;

  /// The rider's latitude (`−90.0 … 90.0`).
  final double lat;

  /// The rider's longitude (`−180.0 … 180.0`).
  final double lng;

  /// The rider's current wait in seconds (`≥ 0`).
  final int waitSec;

  /// The number of drivers inside the match radius.
  final int nearby;

  /// The current surge multiplier (`1.0 … 5.0`).
  final double surgeX;

  /// Creates a [MatchTick] with the given fields.
  ///
  /// The constructor does **not** validate; shape validation belongs to
  /// the `TestCell` rules on the ingress Cells.
  const MatchTick({
    required this.riderId,
    required this.zone,
    required this.lat,
    required this.lng,
    required this.waitSec,
    required this.nearby,
    required this.surgeX,
  });

  @override
  String toString() => 'MatchTick($riderId, $zone, $lat, $lng, ${waitSec}s, '
      'nearby=$nearby, surge=${surgeX}x)';
}

/// The decision produced by [MatchDecisionInstruction].
///
/// `MatchDecision` carries both the computed [Match] and the
/// [MatchTick] it was computed from. The custom instruction emits this
/// richer type; the chain's final [MapValue] then narrows it to the
/// seam type [Match].
final class MatchDecision {
  /// The tick the decision was computed from.
  final MatchTick tick;

  /// The computed match.
  final Match match;

  const MatchDecision({required this.tick, required this.match});

  @override
  String toString() => 'MatchDecision(${match.name}, ${tick.riderId})';
}

/// A single row in the append-only trip ledger.
final class TripEntry {
  /// The semantic tag of the entry (`DISPATCH`, `SURGE`, `PUSH`,
  /// `ACCEPT`, `COMPLETE`, `CANCEL`).
  final String kind;

  /// The rider identifier the entry refers to.
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
final class Assignment {
  /// The driver identifier. Matches the `assignments` map key.
  final String driverId;

  /// The rider identifier.
  final String riderId;

  /// The zone the assignment was created in.
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
final class PushJob {
  /// The rider identifier the job refers to.
  final String riderId;

  /// The match to deliver.
  final Match match;

  const PushJob({required this.riderId, required this.match});

  @override
  String toString() => 'PushJob($riderId, ${match.name})';
}

// ═════════════════════════════════════════════════════════════════════════════
// VISUAL OUTPUT HELPERS
// ═════════════════════════════════════════════════════════════════════════════

/// Prints a scenario section header.
void _section(String label, String drive) {
  print('');
  print('── $label ── $drive');
}

/// Prints a fixed-width banner for the demo header.
void _banner(List<String> lines) {
  const width = 62;
  final bar = List.filled(width, '═').join();
  print('╔$bar╗');
  for (final line in lines) {
    print('║  ${line.padRight(width - 4)}  ║');
  }
  print('╚$bar╝');
}

// ═════════════════════════════════════════════════════════════════════════════
// THE CUSTOM FLOW INSTRUCTION
// ═════════════════════════════════════════════════════════════════════════════

/// Mutable latch state shared between a [MatchDecisionInstruction] and
/// its [MatchDecisionInstruction.reset] API.
class _MatchGateState {
  /// The last [Match] seen by this gate, or `null` after a reset.
  Match? last;
}

/// A single [FlowInstruction] that encapsulates the whole ride-hail
/// match decision for one product lane.
///
/// [MatchDecisionInstruction] extends [FlowInstructionBase] exactly the
/// way `AsyncMap` does in `async_map.dart`: the essential logic lives
/// **inside** the instruction, not in the harness. One instruction
/// performs, in order:
///
/// 1. **Type check** — drop anything that is not a [MatchTick].
/// 2. **Policy** — [matchOf] maps the tick to `idle`, `surge`, or
///    `dispatch` against the live no-go set.
/// 3. **Distinct latch** — drop the pulse when the match equals the
///    previously seen match. A `dispatch → idle → dispatch` sequence
///    therefore fires twice.
/// 4. **Product filter** — drop any match that is not this lane's
///    `pass` match.
/// 5. **Emission** — emit a `Pulse<MatchDecision>` carrying both the
///    tick and the match.
///
/// ### Public API used when turning the instruction into a Cell
///
/// The instruction is a reusable blueprint. The harness:
///
/// * constructs one instance per product lane (`pass: Match.dispatch`
///   and `pass: Match.surge`),
/// * chains it with a stock [MapValue] via `operator +`, which builds
///   a `FlowInstructionChain`,
/// * materialises the chain with `toHandle(source: tickIn.cell)`, and
/// * later calls [reset] from the ACK observer, and reads
///   [lastDecision] for the trailer.
///
/// [matchOf] is the pure match policy and can be unit-tested with a
/// bare [MatchTick] and a plain `Set<String>`.
final class MatchDecisionInstruction
    extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [MatchDecisionInstruction] for one product lane.
  ///
  /// A factory keeps the latch state ([_MatchGateState]) outside the
  /// constructor arguments so the superclass closure can capture it and
  /// the public [reset] API can reach it.
  factory MatchDecisionInstruction({
    required Set<String> noGo,
    required Match pass,
    dynamic user,
  }) {
    final state = _MatchGateState();
    return MatchDecisionInstruction._(noGo, pass, state, user);
  }

  MatchDecisionInstruction._(
    Set<String> noGo,
    Match pass,
    _MatchGateState state,
    dynamic user,
  )   : _noGo = noGo,
        _pass = pass,
        _state = state,
        super(_build(noGo, pass, state), user: user);

  /// The live no-go zone set consulted by [matchOf].
  final Set<String> _noGo;

  /// The single [Match] this lane lets through.
  final Match _pass;

  /// The distinct-until-changed latch.
  final _MatchGateState _state;

  /// Builds the synchronous instruction closure.
  ///
  /// The closure returns `null` to drop a pulse, or an evolved
  /// `Pulse<MatchDecision>` to propagate it downstream.
  static Pulse? Function(Pulse pulse, {Cell? cell, dynamic user}) _build(
    Set<String> noGo,
    Match pass,
    _MatchGateState state,
  ) {
    return (pulse, {cell, user}) {
      final tick = pulse.payload;
      if (tick is! MatchTick) return null;

      final match = matchOf(tick, noGo);

      // Distinct-until-changed: a repeated match is suppressed.
      if (state.last == match) return null;
      state.last = match;

      // This lane's product filter: `idle` (and the other lane's
      // product) never crosses the seam.
      if (match != pass) return null;

      return Pulse<MatchDecision>(
        MatchDecision(tick: tick, match: match),
        source: cell ?? pulse.source,
        type: pulse.type,
        priority: pulse.priority,
        step: 'MatchDecision.${pass.name}',
      );
    };
  }

  /// The pure ride-hail match policy.
  ///
  /// | Condition | Match |
  /// |---|---|
  /// | `t.zone` in `noGo` | `idle` |
  /// | `t.nearby == 0` and `t.waitSec >= 180` | `surge` |
  /// | `t.surgeX >= 1.8` | `surge` |
  /// | `t.nearby >= 1` | `dispatch` |
  /// | else | `idle` |
  ///
  /// The order matters: a closed zone returns `idle` before any nearby
  /// check, so `STADIUM-CURB` with 3 drivers nearby is still `idle`.
  static Match matchOf(MatchTick tick, Set<String> noGo) {
    if (noGo.contains(tick.zone)) return Match.idle;
    if (tick.nearby == 0 && tick.waitSec >= 180) return Match.surge;
    if (tick.surgeX >= 1.8) return Match.surge;
    if (tick.nearby >= 1) return Match.dispatch;
    return Match.idle;
  }

  /// The last [Match] seen by this gate, or `null` after [reset].
  ///
  /// Read by the trailer to prove the ACK authority cleared the latch.
  Match? get lastDecision => _state.last;

  /// The product this lane lets through.
  Match get pass => _pass;

  /// The no-go set this gate consults.
  Set<String> get noGo => _noGo;

  /// Clears the distinct latch.
  ///
  /// Called by the ACK observer. After a reset, the next decision fires
  /// regardless of its value — even if it equals the previous one.
  void reset() {
    _state.last = null;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HARNESS
// ═════════════════════════════════════════════════════════════════════════════

/// The ride-hail dispatch harness — the demo's whole state machine.
///
/// One harness owns every Cell and every Tissue the demo touches. Do
/// not reuse a harness across runs; the state Cells and Tissues carry
/// history and the acceptance console assumes a fresh instance.
class RideHailDispatchHarness {
  /// Creates an empty harness. Call [install] before driving scenarios.
  RideHailDispatchHarness();

  // ───────────────────────────────────────────────────────────────────────────
  // Constants
  // ───────────────────────────────────────────────────────────────────────────

  /// The seed idle-driver count.
  static const int initialIdleDrivers = 12;

  // ───────────────────────────────────────────────────────────────────────────
  // Tissue — the fleet books
  // ───────────────────────────────────────────────────────────────────────────

  /// The append-only trip ledger.
  late final TissueList<TripEntry> trips;

  /// The idle driver count.
  late final TissueValue<int> idleDrivers;

  /// The open assignments, keyed by driver id.
  late final TissueMap<String, Assignment> assignments;

  /// Closed-stand / no-go zones — a runtime-mutable set of zone codes.
  late final TissueSet<String> noGo;

  /// The bounded outbound queue for driver-app jobs.
  late final TissueQueue<PushJob> pushQ;

  // ───────────────────────────────────────────────────────────────────────────
  // Push pump working list
  // ───────────────────────────────────────────────────────────────────────────

  final List<PushJob> _pushWork = <PushJob>[];

  // ───────────────────────────────────────────────────────────────────────────
  // Flow — match decision pipeline
  // ───────────────────────────────────────────────────────────────────────────

  /// The latitude ingress (`−90.0 … 90.0`).
  late final IngressHandle<double> latIn;

  /// The longitude ingress (`−180.0 … 180.0`).
  late final IngressHandle<double> lngIn;

  /// The wait ingress (`≥ 0 seconds`).
  late final IngressHandle<int> waitIn;

  /// The surge ingress (`1.0 … 5.0`).
  late final IngressHandle<double> surgeIn;

  /// The rider-id ingress (cache only — no `TestCell`).
  late final IngressHandle<String> riderIn;

  /// The zone ingress (cache only — no `TestCell`).
  late final IngressHandle<String> zoneIn;

  /// The nearby-count ingress (cache only — no `TestCell`).
  late final IngressHandle<int> nearbyIn;

  /// The snapshot bus ingress — publishes a complete [MatchTick].
  late final IngressHandle<MatchTick> tickIn;

  /// The ACK ingress (driver id, or `"CANCEL"`).
  late final IngressHandle<String> ackIn;

  // ───────────────────────────────────────────────────────────────────────────
  // Flow gates — the custom instructions and their chains
  // ───────────────────────────────────────────────────────────────────────────

  /// The DISPATCH lane instruction.
  ///
  /// One [MatchDecisionInstruction] instance encapsulates the policy,
  /// the distinct latch, and the idle filter for the DISPATCH product.
  /// The ACK observer calls [MatchDecisionInstruction.reset] on it; the
  /// trailer reads [MatchDecisionInstruction.lastDecision].
  late final MatchDecisionInstruction dispatchGate;

  /// The SURGE lane instruction — same contract as [dispatchGate] with
  /// its own independent latch.
  late final MatchDecisionInstruction surgeGate;

  /// The DISPATCH gate handle.
  FlowHandle<Pulse<dynamic>>? dispatchHandle;

  /// The SURGE gate handle.
  FlowHandle<Pulse<dynamic>>? surgeHandle;

  /// The DISPATCH gate cell — emits `Pulse<Match>` when the DISPATCH
  /// chain lets a dispatch through.
  late final Cell dispatchCell;

  /// The SURGE gate cell — emits `Pulse<Match>` when the SURGE chain
  /// lets a surge through.
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
  int ticks = 0;

  /// Number of DISPATCH pulses that made it past the latch.
  int dispatchCount = 0;

  /// Number of SURGE pulses that made it past the latch.
  int surgeCount = 0;

  /// Number of push pump attempts, **including retries**.
  int pushAttempts = 0;

  // ───────────────────────────────────────────────────────────────────────────
  // Push failure injection
  // ───────────────────────────────────────────────────────────────────────────

  /// When `true`, the next push attempt throws once before the retry
  /// succeeds.
  bool pushFailOnce = false;

  bool _pushHasFailed = false;

  /// The last tick published — captured so the observers can correlate
  /// the decision with the correct rider and zone.
  MatchTick? _currentTick;

  final List<EgressHandle> _observers = [];

  // ───────────────────────────────────────────────────────────────────────────
  // TestTissue rules — ONLY used on Tissue constructors
  // ───────────────────────────────────────────────────────────────────────────

  /// Append-only rule for [trips].
  static final TestTissue<TripEntry, TissueList<TripEntry>> _tripAppendOnly =
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
  static final TestTissue<int, TissueValue<int>> _nonNegativeInt =
      TestTissue<int, TissueValue<int>>(
    (value, {host, arguments, user}) {
      if (value is int) return value >= 0;
      return true;
    },
  );

  /// Assignment shape rule for [assignments].
  static final TestTissue<Assignment, TissueMap<String, Assignment>>
      _assignmentRule = TestTissue<Assignment, TissueMap<String, Assignment>>(
    (value, {host, arguments, user}) {
      if (value is Assignment) {
        return value.driverId.isNotEmpty && value.riderId.isNotEmpty;
      }
      return true;
    },
  );

  /// No-go zone rule for [noGo].
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
  /// observers. Runs once.
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

            final job = PushJob(riderId: t.riderId, match: Match.dispatch);
            pushQ.addLast(job);
            print('[pushQ] enqueued $job');

            _pushWork.add(job);
            _drivePush();
          }
        }
      },
    ));

    // ── SURGE observer ────────────────────────────────────────────────────
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
    // Fires on every ackIn emission:
    //   1. clears both instruction latches via their public reset() API;
    //   2. accepts a named driver, or appends a CANCEL ALL row.
    //
    // ACK never calls toHandle again — the chains stay as they are.
    _observers.add(Cell.observe(
      source: ackIn.cell,
      effect: (Pulse pulse) {
        final who = pulse.payload;
        dispatchGate.reset();
        surgeGate.reset();
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

  /// Builds the two decision chains.
  ///
  /// Each chain is one custom [MatchDecisionInstruction] plus one stock
  /// [MapValue]:
  ///
  /// ```text
  /// MatchDecisionInstruction(MatchTick → MatchDecision)
  ///   + MapValue(MatchDecision → Match)
  /// ```
  ///
  /// The `+` composes the two Instructions into a
  /// `FlowInstructionChain`; [FlowInstruction.toHandle] then
  /// materialises that chain into a Cell. The two custom instruction
  /// instances keep independent latches: a SURGE does not clear the
  /// DISPATCH latch and vice versa.
  void installGates() {
    dispatchGate = MatchDecisionInstruction(
      noGo: noGo,
      pass: Match.dispatch,
      user: 'ride-DISPATCH-lane',
    );
    surgeGate = MatchDecisionInstruction(
      noGo: noGo,
      pass: Match.surge,
      user: 'ride-SURGE-lane',
    );

    // One stock instruction, reused by both chains. Instructions are
    // stateless blueprints.
    final toMatch = MapValue<MatchDecision, Match>((d) => d.match);

    // DISPATCH: custom instruction + stock MapValue → one chain → one Cell.
    final dispatchChain = dispatchGate + toMatch;
    dispatchHandle = dispatchChain.toHandle(source: tickIn.cell);
    dispatchCell = dispatchHandle!.cell;

    // SURGE: same shape, independent latch.
    final surgeChain = surgeGate + toMatch;
    surgeHandle = surgeChain.toHandle(source: tickIn.cell);
    surgeCell = surgeHandle!.cell;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Push pump
  // ───────────────────────────────────────────────────────────────────────────

  /// Drains the pump's working list with a single-shot retry.
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
  // Bus — setters and publishTick
  // ───────────────────────────────────────────────────────────────────────────

  /// Sets the latitude cache.
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
    await Future<void>.delayed(Duration.zero);
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
  Future<bool> ack(String who) async {
    ackIn.emit(who);
    await Future<void>.delayed(Duration.zero);
    return true;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Fleet — TissueValue + TissueMap
  // ───────────────────────────────────────────────────────────────────────────

  /// Attempts to accept a driver for the current rider.
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

/// Main entry point for the ride-hail dispatch (Cell) demo.
///
/// Same seed, 13 scenarios, SURGE, and COMPLY as the Tissue sibling,
/// driven through the custom instruction chains instead of ad-hoc gate
/// closures.
Future<void> main() async {
  _banner([
    'ride-hail-dispatch(Cell)-Demo.dart',
    'One FlowInstruction encapsulates the match.',
    'A FlowInstructionChain assembles the pieces.',
  ]);

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
  print(
      '─────────────────────────────────────────────────────────────────');
  print('ticks=${h.ticks} dispatches=${h.dispatchCount} '
      'surges=${h.surgeCount} trips=${h.trips.length} '
      'pushAttempts=${h.pushAttempts}');
  print('idle=${h.idleDrivers.value} '
      'assignments=${h.assignmentCount}');
  print('dispatchGate.lastDecision=${h.dispatchGate.lastDecision} '
      'surgeGate.lastDecision=${h.surgeGate.lastDecision}');
  print('auditorLength=${auditor.length} (same as trips)');
  print(
      '─────────────────────────────────────────────────────────────────');

  h.dispose();
}
