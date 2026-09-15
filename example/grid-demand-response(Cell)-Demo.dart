// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// # Grid Demand-Response — Cell variant: one FlowInstruction, one chain
///
/// **Domain:** electric power transmission — demand-response dispatch
/// (open interruptible load when system frequency sags, protect
/// hospital/critical feeders, restore after the shift-lead ACK).
///
/// **Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`.
///
/// **Sibling:** `grid-demand-response(tissue)-Demo.dart` builds the same
/// domain with two ad-hoc gate closures. This file is the **Cell
/// variant**: it demonstrates how to
///
/// 1. extend [FlowInstructionBase] with a single instruction —
///    [GridDecisionInstruction] — that encapsulates the whole decision
///    policy, the distinct-until-changed latch, and the hold filter,
///    exactly the way `AsyncMap` extends [FlowInstructionBase] in
///    `package:cell_flow/src/instruction/async_map.dart`, and
/// 2. put that instruction together with a stock [MapValue] into a
///    `FlowInstructionChain` (via `operator +`) before materialising
///    the chain into a Cell with [FlowInstruction.toHandle].
///
/// The custom instruction exposes a public API — [GridDecisionInstruction.policyOf],
/// [GridDecisionInstruction.lastDecision], and [GridDecisionInstruction.reset] —
/// which the harness uses when turning the instruction into a Cell and
/// when the ACK authority clears the latches.
///
/// ---
///
/// ## The seam
///
/// * The **custom instruction** answers: *“Is this tick a SHED, a WARN,
///   or a HOLD, and did it change since the last tick?”*
/// * **Tissue** answers: *“What did the books just record, and did
///   megawatts move?”*
/// * The **observer** on each gate Cell is the only glue.
///
/// Nothing about the decision policy touches the reserve table. Nothing
/// about the reserve table influences the decision policy.
///
/// ---
///
/// ## The chain
///
/// ```text
/// tickIn ──► GridDecisionInstruction(BayTick → GridDecision)
///                + MapValue(GridDecision → Action)
///                └──► toHandle ──► shedCell / warnCell
/// ```
///
/// `GridDecisionInstruction` owns the essential logic (type check,
/// policy, latch, hold suppression). The stock `MapValue` only narrows
/// the payload to the `Action` that is allowed to cross the Flow→Tissue
/// seam. The `+` composes the two Instructions into a
/// `FlowInstructionChain`, and `toHandle` turns that chain into a Cell.
///
/// ---
///
/// ## Documented deviations from the walkthrough
///
/// This file follows the same self-consistent scenario output as
/// `grid-demand-response(tissue)-Demo.dart`:
///
/// * §2 — `HOSP-1` is held (the protected feeder rule fires first).
/// * §11–§12 — reserve is forced to `30`, so `restore('INT-15')`
///   returns to `80`, not `800`.
/// * Trailer — `events=19` and `rtuAttempts=6` are the self-consistent
///   counts.
///
/// ---
///
/// ## Expected console output
///
/// ```text
/// ╔══════════════════════════════════════════════════════════════╗
/// ║  grid-demand-response(Cell)-Demo.dart                        ║
/// ║  One FlowInstruction encapsulates the decision.              ║
/// ║  A FlowInstructionChain assembles the pieces.                ║
/// ╚══════════════════════════════════════════════════════════════╝
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
/// ─────────────────────────────────────────────────────────────────
/// ticks=12 sheds=4 warns=1 events=19 rtuAttempts=6
/// reserveMw=80 openSheds=0
/// shedGate.lastDecision=null warnGate.lastDecision=null
/// councilLength=19 (same as events)
/// ─────────────────────────────────────────────────────────────────
/// ```
///
/// ---
///
/// ## Reading order
///
/// 1. `enum Action`, `final class BayTick`, `final class GridDecision` —
///    the domain types.
/// 2. `GridDecisionInstruction` — the custom [FlowInstructionBase]
///    subclass that owns the decision logic.
/// 3. `GridDemandResponseHarness.installGates` — where the instruction
///    is chained with a stock [MapValue] and materialised with
///    [FlowInstruction.toHandle].
/// 4. `GridDemandResponseHarness.applyShed` / `restore` — the Tissue
///    write protocol.
/// 5. `main()` — the 13 scenarios plus COMPLY.
///
/// ---
///
/// ## See also
///
/// * `grid-demand-response(Cell)-WalkThrough.md` — the requirement.
/// * `grid-demand-response(Cell)-ARCHITECTURE.md` — the layering and ownership note.
/// * `grid-demand-response(Cell)-FEATURES.md` — operator catalogue.
/// * `grid-demand-response(tissue)-Demo.dart` — the Tissue-variant sibling.
/// * `package:cell_flow/src/instruction/async_map.dart` — the [AsyncMap]
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

/// The three possible outcomes of a demand-response decision.
///
/// `Action` is the *only* type that crosses the Flow→Tissue seam. The
/// chain's final [MapValue] projects [GridDecision] down to `Action`;
/// the Tissue observers consume that `Action` inside a `Pulse`.
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
/// `BayTick` is the payload of the snapshot bus (`tickIn`). Every
/// sensor change — Hz, load, SOC, feeder — republishes the whole tick,
/// so every consumer of the bus sees a consistent grid state.
final class BayTick {
  /// The area identifier (e.g. `'NORTH'`, `'BAY'`).
  final String area;

  /// The feeder identifier (e.g. `'INT-14'`, `'HOSP-1'`).
  final String feeder;

  /// The system frequency in Hz (`49.00 … 51.00`).
  final double hz;

  /// The area load in MW (`≥ 0`).
  final int loadMw;

  /// The battery state of charge (`0 … 100 %`).
  final int soc;

  /// Creates a [BayTick] with the given fields.
  ///
  /// The constructor does **not** validate; shape validation belongs to
  /// the `TestCell` rules on the ingress Cells.
  const BayTick({
    required this.area,
    required this.feeder,
    required this.hz,
    required this.loadMw,
    required this.soc,
  });

  @override
  String toString() =>
      'BayTick($area, $feeder, ${_fmtHz(hz)}Hz, ${loadMw}MW, SOC=$soc%)';
}

/// The decision produced by [GridDecisionInstruction].
///
/// `GridDecision` carries both the computed [Action] and the [BayTick]
/// it was computed from. The custom instruction emits this richer type;
/// the chain's final [MapValue] then narrows it to the seam type
/// [Action].
final class GridDecision {
  /// The tick the decision was computed from.
  final BayTick tick;

  /// The computed action.
  final Action action;

  const GridDecision({required this.tick, required this.action});

  @override
  String toString() => 'GridDecision(${action.name}, ${tick.feeder})';
}

/// A single row in the append-only event log.
final class GridEvent {
  /// The semantic tag of the entry (`SHED`, `WARN`, `RESTORE`, `RTU`,
  /// `ACK`).
  final String kind;

  /// The feeder identifier the entry refers to.
  final String feeder;

  /// A human-readable summary of the entry.
  final String detail;

  /// When the entry was committed.
  final DateTime at;

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
final class Shed {
  /// The feeder identifier the shed belongs to.
  final String feeder;

  /// The dropped load in MW. Must be `> 0` (enforced by `_shedRule`).
  final int droppedMw;

  const Shed({required this.feeder, required this.droppedMw});

  @override
  String toString() => 'Shed($feeder, ${droppedMw}MW)';
}

/// A single outbound job for the RTU pump.
final class RtuJob {
  /// The feeder identifier the job refers to.
  final String feeder;

  /// The action to deliver to the RTU.
  final Action action;

  const RtuJob({required this.feeder, required this.action});

  @override
  String toString() => 'RtuJob($feeder, ${action.name})';
}

/// Formats a Hz reading to exactly two decimal places.
String _fmtHz(double hz) => hz.toStringAsFixed(2);

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

/// Mutable latch state shared between a [GridDecisionInstruction] and
/// its [GridDecisionInstruction.reset] API.
class _GridGateState {
  /// The last [Action] seen by this gate, or `null` after a reset.
  Action? last;
}

/// A single [FlowInstruction] that encapsulates the whole grid
/// demand-response decision for one product lane.
///
/// [GridDecisionInstruction] extends [FlowInstructionBase] exactly the
/// way `AsyncMap` does in `async_map.dart`: the essential logic lives
/// **inside** the instruction, not in the harness. One instruction
/// performs, in order:
///
/// 1. **Type check** — drop anything that is not a [BayTick].
/// 2. **Policy** — [policyOf] maps the tick to `hold`, `warn`, or
///    `shed` against the live protected set.
/// 3. **Distinct latch** — drop the pulse when the action equals the
///    previously seen action. A `hold → shed → hold → shed` sequence
///    therefore fires twice.
/// 4. **Product filter** — drop any action that is not this lane's
///    `pass` action.
/// 5. **Emission** — emit a `Pulse<GridDecision>` carrying both the
///    tick and the action.
///
/// ### Public API used when turning the instruction into a Cell
///
/// The instruction is a reusable blueprint. The harness:
///
/// * constructs one instance per product lane (`pass: Action.shed` and
///   `pass: Action.warn`),
/// * chains it with a stock [MapValue] via `operator +`, which builds
///   a `FlowInstructionChain`,
/// * materialises the chain with `toHandle(source: tickIn.cell)`, and
/// * later calls [reset] from the ACK observer, and reads
///   [lastDecision] for the trailer.
///
/// [policyOf] is the pure decision policy and can be unit-tested with a
/// bare [BayTick] and a plain `Set<String>`.
///
/// ### Why not three stock instructions?
///
/// The Tissue sibling composes `MapValue + Distinct + Filter` with
/// closures owned by the harness. That works, but the decision logic is
/// scattered across the harness. This variant puts the policy, the
/// latch, and the filter in one named instruction, so the gate reads as
/// a single sentence: `GridDecisionInstruction(protected: …,
/// pass: Action.shed)`.
final class GridDecisionInstruction
    extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [GridDecisionInstruction] for one product lane.
  ///
  /// A factory keeps the latch state ([_GridGateState]) outside the
  /// constructor arguments so the superclass closure can capture it and
  /// the public [reset] API can reach it.
  factory GridDecisionInstruction({
    required Set<String> protected,
    required Action pass,
    dynamic user,
  }) {
    final state = _GridGateState();
    return GridDecisionInstruction._(protected, pass, state, user);
  }

  GridDecisionInstruction._(
    Set<String> protected,
    Action pass,
    _GridGateState state,
    dynamic user,
  )   : _protected = protected,
        _pass = pass,
        _state = state,
        super(_build(protected, pass, state), user: user);

  /// The live protected-feeder set consulted by [policyOf].
  final Set<String> _protected;

  /// The single [Action] this lane lets through.
  final Action _pass;

  /// The distinct-until-changed latch.
  final _GridGateState _state;

  /// Builds the synchronous instruction closure.
  ///
  /// The closure returns `null` to drop a pulse, or an evolved
  /// `Pulse<GridDecision>` to propagate it downstream.
  static Pulse? Function(Pulse pulse, {Cell? cell, dynamic user}) _build(
    Set<String> protected,
    Action pass,
    _GridGateState state,
  ) {
    return (pulse, {cell, user}) {
      final tick = pulse.payload;
      if (tick is! BayTick) return null;

      final action = policyOf(tick, protected);

      // Distinct-until-changed: a repeated action is suppressed.
      if (state.last == action) return null;
      state.last = action;

      // This lane's product filter: `hold` (and the other lane's
      // product) never crosses the seam.
      if (action != pass) return null;

      return Pulse<GridDecision>(
        GridDecision(tick: tick, action: action),
        source: cell ?? pulse.source,
        type: pulse.type,
        priority: pulse.priority,
        step: 'GridDecision.${pass.name}',
      );
    };
  }

  /// The pure demand-response policy.
  ///
  /// | Condition | Action |
  /// |---|---|
  /// | `t.feeder` in `protected` | `hold` |
  /// | `t.hz < 49.80` | `shed` |
  /// | `t.hz < 49.90` | `warn` |
  /// | `t.soc < 15` and `t.loadMw > 500` | `warn` |
  /// | else | `hold` |
  ///
  /// The order matters: a protected feeder returns `hold` before any
  /// frequency check, so `HOSP-1` at 49.70 Hz is held, not shed.
  static Action policyOf(BayTick tick, Set<String> protected) {
    if (protected.contains(tick.feeder)) return Action.hold;
    if (tick.hz < 49.80) return Action.shed;
    if (tick.hz < 49.90) return Action.warn;
    if (tick.soc < 15 && tick.loadMw > 500) return Action.warn;
    return Action.hold;
  }

  /// The last [Action] seen by this gate, or `null` after [reset].
  ///
  /// Read by the trailer to prove the ACK authority cleared the latch.
  Action? get lastDecision => _state.last;

  /// The product this lane lets through.
  Action get pass => _pass;

  /// The protected set this gate consults.
  Set<String> get protected => _protected;

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

/// The grid demand-response harness — the demo's whole state machine.
///
/// One harness owns every Cell and every Tissue the demo touches. Do
/// not reuse a harness across runs; the state Cells and Tissues carry
/// history and the acceptance console assumes a fresh instance.
class GridDemandResponseHarness {
  /// Creates an empty harness. Call [install] before driving scenarios.
  GridDemandResponseHarness();

  // ───────────────────────────────────────────────────────────────────────────
  // Constants
  // ───────────────────────────────────────────────────────────────────────────

  /// The seed reserve in MW.
  static const int initialReserveMw = 800;

  /// The fixed MW dropped per shed in this demo.
  static const int shedMw = 50;

  // ───────────────────────────────────────────────────────────────────────────
  // Tissue — the feeder books
  // ───────────────────────────────────────────────────────────────────────────

  /// The append-only event log.
  late final TissueList<GridEvent> events;

  /// The spinning reserve in MW.
  late final TissueValue<int> reserveMw;

  /// The open demand-response sheds, keyed by `feeder`.
  late final TissueMap<String, Shed> shedMap;

  /// Protected feeders — a runtime-mutable set of feeder ids.
  late final TissueSet<String> protected;

  /// The bounded outbound queue for RTU I/O jobs.
  late final TissueQueue<RtuJob> rtuQ;

  // ───────────────────────────────────────────────────────────────────────────
  // RTU pump working list
  // ───────────────────────────────────────────────────────────────────────────

  final List<RtuJob> _rtuWork = <RtuJob>[];

  // ───────────────────────────────────────────────────────────────────────────
  // Flow — shed decision pipeline
  // ───────────────────────────────────────────────────────────────────────────

  /// The Hz ingress (`49.00 … 51.00`).
  late final IngressHandle<double> hzIn;

  /// The load ingress (`≥ 0 MW`).
  late final IngressHandle<int> loadIn;

  /// The SOC ingress (`0 … 100 %`).
  late final IngressHandle<int> socIn;

  /// The area ingress (cache only — no `TestCell`).
  late final IngressHandle<String> areaIn;

  /// The feeder ingress (cache only — no `TestCell`).
  late final IngressHandle<String> feederIn;

  /// The snapshot bus ingress — publishes a complete [BayTick].
  late final IngressHandle<BayTick> tickIn;

  /// The ACK ingress (shift-lead id, or `"ALL"`).
  late final IngressHandle<String> ackIn;

  // ───────────────────────────────────────────────────────────────────────────
  // Flow gates — the custom instructions and their chains
  // ───────────────────────────────────────────────────────────────────────────

  /// The SHED lane instruction.
  ///
  /// One [GridDecisionInstruction] instance encapsulates the policy, the
  /// distinct latch, and the hold filter for the SHED product. The ACK
  /// observer calls [GridDecisionInstruction.reset] on it; the trailer
  /// reads [GridDecisionInstruction.lastDecision].
  late final GridDecisionInstruction shedGate;

  /// The WARN lane instruction — same contract as [shedGate] with its
  /// own independent latch.
  late final GridDecisionInstruction warnGate;

  /// The SHED gate handle.
  FlowHandle<Pulse<dynamic>>? shedHandle;

  /// The WARN gate handle.
  FlowHandle<Pulse<dynamic>>? warnHandle;

  /// The SHED gate cell — emits `Pulse<Action>` when the SHED chain
  /// lets a shed through.
  late final Cell shedCell;

  /// The WARN gate cell — emits `Pulse<Action>` when the WARN chain
  /// lets a warn through.
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
  int ticks = 0;

  /// Number of SHED pulses that made it past the latch.
  int shedCount = 0;

  /// Number of WARN pulses that made it past the latch.
  int warnCount = 0;

  /// Number of RTU pump attempts, **including retries**.
  int rtuAttempts = 0;

  // ───────────────────────────────────────────────────────────────────────────
  // RTU failure injection
  // ───────────────────────────────────────────────────────────────────────────

  /// When `true`, the next RTU attempt throws once before the retry
  /// succeeds.
  bool rtuFailOnce = false;

  bool _rtuHasFailed = false;

  /// The last tick published — captured so the observers can correlate
  /// the decision with the correct feeder and Hz.
  BayTick? _currentTick;

  final List<EgressHandle> _observers = [];

  // ───────────────────────────────────────────────────────────────────────────
  // TestTissue rules — ONLY used on Tissue constructors
  // ───────────────────────────────────────────────────────────────────────────

  /// Append-only rule for [events].
  static final TestTissue<GridEvent, TissueList<GridEvent>> _eventAppendOnly =
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
  static final TestTissue<int, TissueValue<int>> _nonNegativeMw =
      TestTissue<int, TissueValue<int>>(
    (value, {host, arguments, user}) {
      if (value is int) return value >= 0;
      return true;
    },
  );

  /// Shed rule for [shedMap].
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
  /// observers. Runs once.
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
    // Fires on every ackIn emission:
    //   1. clears both instruction latches via their public reset() API;
    //   2. restores a named feeder, or appends an ACK ALL row.
    //
    // ACK never calls toHandle again — the chains stay as they are.
    _observers.add(Cell.observe(
      source: ackIn.cell,
      effect: (Pulse pulse) {
        final who = pulse.payload;
        shedGate.reset();
        warnGate.reset();
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

  /// Builds the two decision chains.
  ///
  /// Each chain is one custom [GridDecisionInstruction] plus one stock
  /// [MapValue]:
  ///
  /// ```text
  /// GridDecisionInstruction(BayTick → GridDecision)
  ///   + MapValue(GridDecision → Action)
  /// ```
  ///
  /// The `+` composes the two Instructions into a
  /// `FlowInstructionChain`; [FlowInstruction.toHandle] then
  /// materialises that chain into a Cell. The two custom instruction
  /// instances keep independent latches: a WARN does not clear the SHED
  /// latch and vice versa.
  void installGates() {
    shedGate = GridDecisionInstruction(
      protected: protected,
      pass: Action.shed,
      user: 'grid-SHED-lane',
    );
    warnGate = GridDecisionInstruction(
      protected: protected,
      pass: Action.warn,
      user: 'grid-WARN-lane',
    );

    // One stock instruction, reused by both chains. Instructions are
    // stateless blueprints.
    final toAction = MapValue<GridDecision, Action>((d) => d.action);

    // SHED: custom instruction + stock MapValue → one chain → one Cell.
    final shedChain = shedGate + toAction;
    shedHandle = shedChain.toHandle(source: tickIn.cell);
    shedCell = shedHandle!.cell;

    // WARN: same shape, independent latch.
    final warnChain = warnGate + toAction;
    warnHandle = warnChain.toHandle(source: tickIn.cell);
    warnCell = warnHandle!.cell;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // RTU pump
  // ───────────────────────────────────────────────────────────────────────────

  /// Drains the pump's working list with a single-shot retry.
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
  // Bus — setters and publishTick
  // ───────────────────────────────────────────────────────────────────────────

  /// Sets the Hz cache.
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
  bool setFeeder(String feeder) {
    _feeder = feeder;
    return true;
  }

  /// Publishes a complete [BayTick] onto the snapshot bus.
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
    await Future<void>.delayed(Duration.zero);
    return true;
  }

  /// Static validator mirroring `_hzRange`.
  static bool _hzValid(double v) => v >= 49.00 && v <= 51.00;

  /// Static validator mirroring `_loadRange`.
  static bool _loadValid(int v) => v >= 0;

  /// Static validator mirroring `_socRange`.
  static bool _socValid(int v) => v >= 0 && v <= 100;

  /// Publishes an ACK onto [ackIn].
  Future<bool> ack(String who) async {
    ackIn.emit(who);
    await Future<void>.delayed(Duration.zero);
    return true;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Reserve — TissueValue + TissueMap
  // ───────────────────────────────────────────────────────────────────────────

  /// Attempts to apply a shed.
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

/// Main entry point for the grid demand-response (Cell) demo.
///
/// Same 13 scenarios as the Tissue sibling, driven through the custom
/// instruction chains instead of ad-hoc gate closures.
Future<void> main() async {
  _banner([
    'grid-demand-response(Cell)-Demo.dart',
    'One FlowInstruction encapsulates the decision.',
    'A FlowInstructionChain assembles the pieces.',
  ]);

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
  _section('COMPLY', 'council.add(...) blocked; length == events.length');
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
  print(
      '─────────────────────────────────────────────────────────────────');
  print('ticks=${h.ticks} sheds=${h.shedCount} warns=${h.warnCount} '
      'events=${h.events.length} rtuAttempts=${h.rtuAttempts}');
  print('reserveMw=${h.reserveMw.value} '
      'openSheds=${h.openShedsCount}');
  print('shedGate.lastDecision=${h.shedGate.lastDecision} '
      'warnGate.lastDecision=${h.warnGate.lastDecision}');
  print('councilLength=${council.length} (same as events)');
  print(
      '─────────────────────────────────────────────────────────────────');

  h.dispose();
}
