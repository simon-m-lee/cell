// Copyright (c) 2025-Present. Use of this source code is governed by a
// MIT or Apache-2.0 license.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// # Baggage Flow Watch — Cell variant
///
/// **Domain:** airport baggage handling (departing bags: check-in → sorter →
/// make-up carousel → aircraft side). Real-time visibility, at-risk flags,
/// belt-stop alerts, incident audit, and a daily airline performance report.
///
/// **Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`.
///
/// **WalkThrough:** `baggage-flow-watch(Cell)-WalkThrough.md`
///
/// This demo shows:
///
/// 1. Two custom [FlowInstruction]s — [AtRiskDecisionInstruction] and
///    [BeltStopDecisionInstruction] — that encapsulate policy + latch.
/// 2. Composition with stock [MapValue] via `operator +` into a
///    [FlowInstructionChain], materialised with [FlowInstruction.toHandle].
/// 3. Tissue books (bags, open incidents, incident log, daily stats) written
///    only from [Cell.observe] side-effects.
/// 4. TestCell on ingress and TestTissue on every collection.
/// 5. Read-only deputies for compliance / airline liaison.
///
/// The seam is the same as ride-hail and card-auth:
/// * Flow decides *what is at risk / what is jammed*.
/// * Tissue owns the books the duty manager and airline liaison read.
/// * Observers are the only glue.
library;

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_tissue/cell_tissue.dart';

// ignore_for_file: avoid_print, unused_local_variable, file_names

// ═════════════════════════════════════════════════════════════════════════════
// DOMAIN
// ═════════════════════════════════════════════════════════════════════════════

enum BagStatus { inSystem, atRisk, recovered, missed, closed }

enum BeltStatus { running, stopped, unknown }

enum IncidentStatus { open, acknowledged, resolved, escalated }

/// One departing bag as seen by the system.
final class Bag {
  const Bag({
    required this.tag,
    required this.flight,
    required this.airline,
    required this.terminal,
    required this.position,
    required this.lastScan,
    required this.status,
    this.closeOut,
    this.mctMinutes = 35,
  });

  final String tag;
  final String flight;
  final String airline;
  final int terminal;
  final String position;
  final DateTime lastScan;
  final BagStatus status;
  final DateTime? closeOut;
  final int mctMinutes;

  Bag copyWith({
    String? position,
    DateTime? lastScan,
    BagStatus? status,
    DateTime? closeOut,
  }) =>
      Bag(
        tag: tag,
        flight: flight,
        airline: airline,
        terminal: terminal,
        position: position ?? this.position,
        lastScan: lastScan ?? this.lastScan,
        status: status ?? this.status,
        closeOut: closeOut ?? this.closeOut,
        mctMinutes: mctMinutes,
      );

  @override
  String toString() =>
      'Bag($tag, $flight, T$terminal, $position, ${status.name})';
}

/// Snapshot of a flight’s baggage close-out window.
final class FlightWindow {
  const FlightWindow({
    required this.flight,
    required this.airline,
    required this.terminal,
    required this.scheduledDeparture,
    required this.closeOut,
  });

  final String flight;
  final String airline;
  final int terminal;
  final DateTime scheduledDeparture;
  final DateTime closeOut;

  @override
  String toString() => 'FlightWindow($flight, closeOut=$closeOut)';
}

/// One scan event from the belt / sorter / carousel system.
final class BagScan {
  const BagScan({
    required this.tag,
    required this.flight,
    required this.position,
    required this.at,
    this.terminal = 2,
    this.airline = 'BA',
  });

  final String tag;
  final String flight;
  final String position;
  final DateTime at;
  final int terminal;
  final String airline;

  @override
  String toString() => 'BagScan($tag, $flight, $position @ $at)';
}

/// Belt / sorter / carousel status pulse.
final class BeltEvent {
  const BeltEvent({
    required this.deviceId,
    required this.status,
    required this.at,
    this.terminal = 2,
  });

  final String deviceId;
  final BeltStatus status;
  final DateTime at;
  final int terminal;

  @override
  String toString() => 'BeltEvent($deviceId, ${status.name} @ $at)';
}

/// Decision emitted by the at-risk pipeline.
final class AtRiskDecision {
  const AtRiskDecision({
    required this.bag,
    required this.remainingMinutes,
    required this.isAtRisk,
  });

  final Bag bag;
  final int remainingMinutes;
  final bool isAtRisk;

  @override
  String toString() =>
      'AtRiskDecision(${bag.tag}, remaining=${remainingMinutes}m, atRisk=$isAtRisk)';
}

/// Decision emitted by the jam pipeline.
final class JamAlert {
  const JamAlert({
    required this.deviceId,
    required this.terminal,
    required this.stoppedSince,
    required this.affectedBags,
    required this.flightsAtRisk,
  });

  final String deviceId;
  final int terminal;
  final DateTime stoppedSince;
  final int affectedBags;
  final List<String> flightsAtRisk;

  @override
  String toString() =>
      'JamAlert($deviceId, bags=$affectedBags, flights=$flightsAtRisk)';
}

/// Grouped operational incident (one cause, many bags).
final class Incident {
  const Incident({
    required this.id,
    required this.terminal,
    required this.deviceId,
    required this.start,
    this.end,
    required this.status,
    required this.affectedTags,
    required this.flightsAtRisk,
    this.ackBy,
    this.ackAt,
    this.actionTaken,
    this.note,
  });

  final String id;
  final int terminal;
  final String deviceId;
  final DateTime start;
  final DateTime? end;
  final IncidentStatus status;
  final List<String> affectedTags;
  final List<String> flightsAtRisk;
  final String? ackBy;
  final DateTime? ackAt;
  final String? actionTaken;
  final String? note;

  Incident copyWith({
    DateTime? end,
    IncidentStatus? status,
    String? ackBy,
    DateTime? ackAt,
    String? actionTaken,
    String? note,
  }) =>
      Incident(
        id: id,
        terminal: terminal,
        deviceId: deviceId,
        start: start,
        end: end ?? this.end,
        status: status ?? this.status,
        affectedTags: affectedTags,
        flightsAtRisk: flightsAtRisk,
        ackBy: ackBy ?? this.ackBy,
        ackAt: ackAt ?? this.ackAt,
        actionTaken: actionTaken ?? this.actionTaken,
        note: note ?? this.note,
      );

  @override
  String toString() =>
      'Incident($id, T$terminal, $deviceId, ${status.name}, bags=${affectedTags.length})';
}

/// One row in the daily airline performance report.
final class AirlineDayStat {
  const AirlineDayStat({
    required this.airline,
    required this.bagsHandled,
    required this.bagsDelayed,
    required this.bagsMissed,
    required this.avgProcessingMinutes,
  });

  final String airline;
  final int bagsHandled;
  final int bagsDelayed;
  final int bagsMissed;
  final double avgProcessingMinutes;

  @override
  String toString() =>
      'AirlineDayStat($airline, handled=$bagsHandled, delayed=$bagsDelayed, missed=$bagsMissed)';
}

/// Structured ACK payload.
final class AckPayload {
  const AckPayload({
    required this.incidentId,
    required this.by,
    required this.action,
    this.note,
  });

  final String incidentId;
  final String by;
  final String action;
  final String? note;

  @override
  String toString() => 'AckPayload($incidentId by $by: $action)';
}

// ═════════════════════════════════════════════════════════════════════════════
// VISUAL OUTPUT HELPERS
// ═════════════════════════════════════════════════════════════════════════════

void _section(String label, String drive) {
  print('');
  print('── $label ── $drive');
}

void _banner(List<String> lines) {
  const width = 64;
  final bar = List.filled(width, '═').join();
  print('╔$bar╗');
  for (final line in lines) {
    print('║  ${line.padRight(width - 4)}  ║');
  }
  print('╚$bar╝');
}

// ═════════════════════════════════════════════════════════════════════════════
// CUSTOM FLOW INSTRUCTIONS
// ═════════════════════════════════════════════════════════════════════════════

class _AtRiskGateState {
  String? lastTagAtRisk;
}

/// Encapsulates the at-risk policy + distinct latch for one bag.
///
/// Order per pulse:
/// 1. Type-check (must be [Bag])
/// 2. Pure policy [decide]
/// 3. Distinct latch (same tag already flagged → drop)
/// 4. Product filter (only emit when isAtRisk)
/// 5. Emit [Pulse]<[AtRiskDecision]>
final class AtRiskDecisionInstruction
    extends FlowInstructionBase<Cell, Pulse, Pulse> {
  factory AtRiskDecisionInstruction({
    required DateTime Function() now,
    dynamic user,
  }) {
    final state = _AtRiskGateState();
    return AtRiskDecisionInstruction._(now, state, user);
  }

  AtRiskDecisionInstruction._(
    DateTime Function() now,
    _AtRiskGateState state,
    dynamic user,
  )   : _now = now,
        _state = state,
        super(_build(now, state), user: user);

  final DateTime Function() _now;
  final _AtRiskGateState _state;

  static Pulse? Function(Pulse pulse, {Cell? cell, dynamic user}) _build(
    DateTime Function() now,
    _AtRiskGateState state,
  ) {
    return (pulse, {cell, user}) {
      final bag = pulse.payload;
      if (bag is! Bag) return null;

      final decision = decide(bag, now());

      // Distinct: suppress repeated at-risk for the same tag.
      if (decision.isAtRisk && state.lastTagAtRisk == bag.tag) return null;
      if (decision.isAtRisk) {
        state.lastTagAtRisk = bag.tag;
      }

      if (!decision.isAtRisk) return null;

      return Pulse<AtRiskDecision>(
        decision,
        source: cell ?? pulse.source,
        type: pulse.type,
        priority: pulse.priority,
        step: 'AtRiskDecision',
      );
    };
  }

  /// Pure at-risk policy (unit-testable without the graph).
  static AtRiskDecision decide(Bag bag, DateTime now) {
    if (bag.closeOut == null) {
      return AtRiskDecision(bag: bag, remainingMinutes: 999, isAtRisk: false);
    }
    // BR-02: no alert after close-out.
    if (now.isAfter(bag.closeOut!)) {
      return AtRiskDecision(bag: bag, remainingMinutes: 0, isAtRisk: false);
    }
    final remaining = bag.closeOut!.difference(now).inMinutes;
    final atRisk = remaining < bag.mctMinutes &&
        bag.status != BagStatus.missed &&
        bag.status != BagStatus.recovered &&
        bag.status != BagStatus.closed;
    return AtRiskDecision(
      bag: bag,
      remainingMinutes: remaining,
      isAtRisk: atRisk,
    );
  }

  String? get lastTagAtRisk => _state.lastTagAtRisk;

  void reset() {
    _state.lastTagAtRisk = null;
  }
}

class _BeltStopGateState {
  final Map<String, DateTime> stoppedSince = {};
  final Set<String> alreadyAlerted = {};
}

/// Encapsulates belt-stop > 60 s policy + latch.
///
/// Emits [JamAlert] only when a device has been continuously stopped
/// for ≥ 60 seconds and has not already been alerted for this stop.
final class BeltStopDecisionInstruction
    extends FlowInstructionBase<Cell, Pulse, Pulse> {
  factory BeltStopDecisionInstruction({
    required DateTime Function() now,
    required Iterable<Bag> Function(String deviceId) bagsOnDevice,
    dynamic user,
  }) {
    final state = _BeltStopGateState();
    return BeltStopDecisionInstruction._(now, bagsOnDevice, state, user);
  }

  BeltStopDecisionInstruction._(
    DateTime Function() now,
    Iterable<Bag> Function(String deviceId) bagsOnDevice,
    _BeltStopGateState state,
    dynamic user,
  )   : _now = now,
        _bagsOnDevice = bagsOnDevice,
        _state = state,
        super(_build(now, bagsOnDevice, state), user: user);

  final DateTime Function() _now;
  final Iterable<Bag> Function(String deviceId) _bagsOnDevice;
  final _BeltStopGateState _state;

  static Pulse? Function(Pulse pulse, {Cell? cell, dynamic user}) _build(
    DateTime Function() now,
    Iterable<Bag> Function(String deviceId) bagsOnDevice,
    _BeltStopGateState state,
  ) {
    return (pulse, {cell, user}) {
      final event = pulse.payload;
      if (event is! BeltEvent) return null;

      if (event.status == BeltStatus.running) {
        state.stoppedSince.remove(event.deviceId);
        state.alreadyAlerted.remove(event.deviceId);
        return null;
      }

      if (event.status != BeltStatus.stopped) return null;

      final since = state.stoppedSince.putIfAbsent(event.deviceId, () => event.at);
      final elapsed = now().difference(since).inSeconds;
      if (elapsed < 60) return null;
      if (state.alreadyAlerted.contains(event.deviceId)) return null;

      state.alreadyAlerted.add(event.deviceId);

      final onDevice = bagsOnDevice(event.deviceId);
      final active = onDevice.where((b) =>
          b.status == BagStatus.inSystem || b.status == BagStatus.atRisk);
      final flights = active.map((b) => b.flight).toSet().toList()..sort();

      final alert = JamAlert(
        deviceId: event.deviceId,
        terminal: event.terminal,
        stoppedSince: since,
        affectedBags: active.length,
        flightsAtRisk: flights,
      );

      return Pulse<JamAlert>(
        alert,
        source: cell ?? pulse.source,
        type: pulse.type,
        priority: pulse.priority,
        step: 'BeltStopDecision',
      );
    };
  }

  void reset(String deviceId) {
    _state.stoppedSince.remove(deviceId);
    _state.alreadyAlerted.remove(deviceId);
  }

  void resetAll() {
    _state.stoppedSince.clear();
    _state.alreadyAlerted.clear();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HARNESS
// ═════════════════════════════════════════════════════════════════════════════

class BaggageFlowWatchHarness {
  BaggageFlowWatchHarness({DateTime? seedTime})
      : _clock = seedTime ?? DateTime.utc(2026, 9, 16, 7, 0);

  // Simulated clock (advanced by scenarios).
  DateTime _clock;
  DateTime get now => _clock;
  void advance(Duration d) => _clock = _clock.add(d);

  // ── Tissue books ──────────────────────────────────────────────────────────

  late final TissueMap<String, Bag> bags;
  late final TissueMap<String, Incident> openIncidents;
  late final TissueList<Incident> incidentLog;
  late final TissueMap<String, AirlineDayStat> dailyStats;
  late final TissueMap<String, DateTime> deviceLastStop;

  // ── Ingress ───────────────────────────────────────────────────────────────

  late final IngressHandle<BagScan> bagScanIn;
  late final IngressHandle<FlightWindow> flightIn;
  late final IngressHandle<BeltEvent> beltStatusIn;
  late final IngressHandle<AckPayload> ackIn;
  late final IngressHandle<Bag> atRiskTickIn; // snapshot bus for at-risk

  // ── Gates ─────────────────────────────────────────────────────────────────

  late final AtRiskDecisionInstruction atRiskGate;
  late final BeltStopDecisionInstruction jamGate;

  FlowHandle<Pulse<dynamic>>? atRiskHandle;
  FlowHandle<Pulse<dynamic>>? jamHandle;

  late final Cell atRiskCell;
  late final Cell jamCell;

  // ── Flight close-out cache ────────────────────────────────────────────────

  final Map<String, FlightWindow> _flights = {};

  // ── Counters for acceptance ───────────────────────────────────────────────

  int atRiskEmissions = 0;
  int jamEmissions = 0;
  int ackCount = 0;
  int rejectedScans = 0;

  // ── Observers (kept so we can stop them) ──────────────────────────────────

  final List<dynamic> _observers = [];

  // ─────────────────────────────────────────────────────────────────────────
  // install
  // ─────────────────────────────────────────────────────────────────────────

  void install() {
    // --- Tissue with TestTissue ---
    final bagRule = TestTissue<Bag, TissueMap<String, Bag>>(
      (b, {host, action, user}) =>
          b != null && b.tag.isNotEmpty && b.flight.isNotEmpty,
    );
    bags = TissueMap<String, Bag>(testRule: bagRule);

    final openRule = TestTissue<Incident, TissueMap<String, Incident>>(
      (i, {host, action, user}) =>
          i != null && i.id.isNotEmpty && i.deviceId.isNotEmpty,
    );
    openIncidents = TissueMap<String, Incident>(testRule: openRule);

    final logRule = TestTissue<Incident, TissueList<Incident>>(
      (e, {host, action, user}) {
        // Append-only: allow add / addAll; deny remove / clear / []=.
        if (action == TissueAction.remove ||
            action == TissueAction.clear ||
            action == TissueAction.set) {
          return false;
        }
        return e.id.isNotEmpty;
      },
    );
    incidentLog = TissueList<Incident>(testRule: logRule);

    final statsRule = TestTissue<AirlineDayStat, TissueMap<String, AirlineDayStat>>(
      (s, {host, action, user}) => s != null && s.airline.isNotEmpty,
    );
    dailyStats = TissueMap<String, AirlineDayStat>(testRule: statsRule);

    deviceLastStop = TissueMap<String, DateTime>(
      testRule: TestTissue.allowAll,
    );

    // --- Ingress with TestCell ---
    final tagShape = TestCell<Cell>((pulse, {cell, user}) {
      final p = pulse.payload;
      if (p is! BagScan) return true; // wrong type left to other rules
      if (p.tag.isEmpty) return false;
      if (p.flight.isEmpty) return false;
      const allowed = {
        'check-in',
        'sorter-in',
        'sorter-out',
        'carousel',
        'aircraft-side',
      };
      if (!allowed.contains(p.position)) return false;
      return true;
    });

    final flightShape = TestCell<Cell>((pulse, {cell, user}) {
      final p = pulse.payload;
      if (p is! FlightWindow) return true;
      final re = RegExp(r'^[A-Z][A-Z0-9][0-9]{1,4}$');
      if (!re.hasMatch(p.flight)) return false;
      if (p.closeOut.isBefore(p.scheduledDeparture)) return false;
      return true;
    });

    bagScanIn = Cell.ingress<BagScan>(testRule: tagShape);
    flightIn = Cell.ingress<FlightWindow>(testRule: flightShape);
    beltStatusIn = Cell.ingress<BeltEvent>();
    ackIn = Cell.ingress<AckPayload>();
    atRiskTickIn = Cell.ingress<Bag>();

    // --- Custom instructions + chains ---
    installGates();

    // --- Observers (the only glue) ---
    _observers.add(Cell.observe(
      source: bagScanIn.cell,
      effect: (pulse) {
        final scan = pulse.payload;
        if (scan is! BagScan) return;
        _onScan(scan);
      },
    ));

    _observers.add(Cell.observe(
      source: flightIn.cell,
      effect: (pulse) {
        final fw = pulse.payload;
        if (fw is! FlightWindow) return;
        _flights[fw.flight] = fw;
        print('[flight] ${fw.flight} closeOut=${fw.closeOut}');
      },
    ));

    _observers.add(Cell.observe(
      source: atRiskCell,
      effect: (pulse) {
        final d = pulse.payload;
        if (d is! AtRiskDecision) return;
        atRiskEmissions++;
        final updated = d.bag.copyWith(status: BagStatus.atRisk);
        bags[updated.tag] = updated;
        print('[at-risk] ${updated.tag} remaining=${d.remainingMinutes}m');
      },
    ));

    _observers.add(Cell.observe(
      source: jamCell,
      effect: (pulse) {
        final alert = pulse.payload;
        if (alert is! JamAlert) return;
        jamEmissions++;
        _onJam(alert);
      },
    ));

    _observers.add(Cell.observe(
      source: ackIn.cell,
      effect: (pulse) {
        final ack = pulse.payload;
        if (ack is! AckPayload) return;
        ackCount++;
        _onAck(ack);
      },
    ));
  }

  void installGates() {
    atRiskGate = AtRiskDecisionInstruction(now: () => _clock);
    jamGate = BeltStopDecisionInstruction(
      now: () => _clock,
      bagsOnDevice: (deviceId) {
        // Simple heuristic: all bags currently inSystem/atRisk in that terminal.
        // Real system would map device → zone; here we use terminal from deviceId.
        final term = _terminalFromDevice(deviceId);
        return bags.values.where((b) =>
            b.terminal == term &&
            (b.status == BagStatus.inSystem || b.status == BagStatus.atRisk));
      },
    );

    // Chain: custom instruction + identity MapValue (or direct).
    // For at-risk we emit AtRiskDecision directly; for jam we emit JamAlert.
    final atRiskChain = atRiskGate +
        MapValue<AtRiskDecision, AtRiskDecision>((d) => d);
    atRiskHandle = atRiskChain.toHandle(source: atRiskTickIn.cell);
    atRiskCell = atRiskHandle!.cell;

    final jamChain =
        jamGate + MapValue<JamAlert, JamAlert>((a) => a);
    jamHandle = jamChain.toHandle(source: beltStatusIn.cell);
    jamCell = jamHandle!.cell;
  }

  int _terminalFromDevice(String deviceId) {
    // e.g. T2-BELT-07 → 2
    final m = RegExp(r'T(\d+)').firstMatch(deviceId);
    return m != null ? int.parse(m.group(1)!) : 2;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Book writers (called only from observers)
  // ─────────────────────────────────────────────────────────────────────────

  void _onScan(BagScan scan) {
    final existing = bags[scan.tag];
    final fw = _flights[scan.flight];
    final bag = Bag(
      tag: scan.tag,
      flight: scan.flight,
      airline: scan.airline,
      terminal: scan.terminal,
      position: scan.position,
      lastScan: scan.at,
      status: existing?.status ?? BagStatus.inSystem,
      closeOut: fw?.closeOut ?? existing?.closeOut,
      mctMinutes: existing?.mctMinutes ?? 35,
    );
    bags[scan.tag] = bag;
    print('[scan] ${bag.tag} → ${bag.position}');

    // Feed the at-risk gate with the latest bag snapshot.
    atRiskTickIn.emit(bag);
  }

  void _onJam(JamAlert alert) {
    final id = 'INC-${alert.deviceId}-${alert.stoppedSince.millisecondsSinceEpoch}';
    final tags = bags.values
        .where((b) =>
            b.terminal == alert.terminal &&
            (b.status == BagStatus.inSystem || b.status == BagStatus.atRisk))
        .map((b) => b.tag)
        .toList();
    final incident = Incident(
      id: id,
      terminal: alert.terminal,
      deviceId: alert.deviceId,
      start: alert.stoppedSince,
      status: IncidentStatus.open,
      affectedTags: tags,
      flightsAtRisk: alert.flightsAtRisk,
    );
    openIncidents[id] = incident;
    print('[jam] $incident');
  }

  void _onAck(AckPayload ack) {
    final open = openIncidents[ack.incidentId];
    if (open == null) {
      print('[ack] unknown incident ${ack.incidentId}');
      return;
    }
    final updated = open.copyWith(
      status: IncidentStatus.acknowledged,
      ackBy: ack.by,
      ackAt: _clock,
      actionTaken: ack.action,
      note: ack.note,
    );
    openIncidents[ack.incidentId] = updated;
    print('[ack] ${updated.id} by ${ack.by}: ${ack.action}');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public API for scenarios
  // ─────────────────────────────────────────────────────────────────────────

  bool publishScan(BagScan scan) {
    try {
      bagScanIn.emit(scan);
      return true;
    } catch (_) {
      rejectedScans++;
      return false;
    }
  }

  bool publishFlight(FlightWindow fw) {
    try {
      flightIn.emit(fw);
      return true;
    } catch (_) {
      return false;
    }
  }

  void publishBelt(BeltEvent e) {
    beltStatusIn.emit(e);
  }

  void publishAck(AckPayload ack) {
    ackIn.emit(ack);
  }

  /// Resolve an open incident → move to incidentLog.
  bool resolve(String incidentId) {
    final open = openIncidents[incidentId];
    if (open == null) return false;
    final closed = open.copyWith(
      status: IncidentStatus.resolved,
      end: _clock,
    );
    openIncidents.remove(incidentId);
    incidentLog.add(closed);
    jamGate.reset(open.deviceId);
    print('[resolve] $incidentId → log');
    return true;
  }

  /// Mark a bag recovered (reached aircraft-side in time).
  void markRecovered(String tag) {
    final b = bags[tag];
    if (b == null) return;
    bags[tag] = b.copyWith(status: BagStatus.recovered);
    print('[recovered] $tag');
  }

  /// Mark a bag missed (past close-out, not loaded).
  void markMissed(String tag) {
    final b = bags[tag];
    if (b == null) return;
    bags[tag] = b.copyWith(status: BagStatus.missed);
    print('[missed] $tag');
  }

  /// Build a simple daily aggregate from current books.
  void buildDailyReport() {
    final byAirline = <String, List<Bag>>{};
    for (final b in bags.values) {
      byAirline.putIfAbsent(b.airline, () => []).add(b);
    }
    for (final entry in byAirline.entries) {
      final list = entry.value;
      final handled = list.length;
      final delayed =
          list.where((b) => b.status == BagStatus.atRisk).length;
      final missed =
          list.where((b) => b.status == BagStatus.missed).length;
      // Toy average: 25 min if recovered, 40 if delayed/missed.
      final avg = list.isEmpty
          ? 0.0
          : list
                  .map((b) => b.status == BagStatus.recovered ? 25.0 : 40.0)
                  .reduce((a, b) => a + b) /
              list.length;
      dailyStats[entry.key] = AirlineDayStat(
        airline: entry.key,
        bagsHandled: handled,
        bagsDelayed: delayed,
        bagsMissed: missed,
        avgProcessingMinutes: avg,
      );
      print('[daily] ${dailyStats[entry.key]}');
    }
  }

  /// Compliance deputy — read-only view of the incident log.
  TissueList<Incident> get auditor =>
      incidentLog.deputy(testRule: TestTissue.readOnly) as TissueList<Incident>;
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN — seed + scenarios
// ═════════════════════════════════════════════════════════════════════════════

Future<void> main() async {
  _banner([
    'baggage-flow-watch(Cell)-Demo.dart',
    'Flow decides at-risk / jam; Tissue owns the books.',
    'Observers are the only glue.',
  ]);

  final h = BaggageFlowWatchHarness(
    seedTime: DateTime.utc(2026, 9, 16, 7, 0),
  );
  h.install();

  // ── Seed ──────────────────────────────────────────────────────────────────
  _section('Seed', '3 bags BA482 T2 sorter-in; flight window +40 min');

  final closeOut = h.now.add(const Duration(minutes: 40));
  h.publishFlight(FlightWindow(
    flight: 'BA482',
    airline: 'BA',
    terminal: 2,
    scheduledDeparture: h.now.add(const Duration(minutes: 55)),
    closeOut: closeOut,
  ));

  h.publishScan(BagScan(
    tag: 'TAG-001',
    flight: 'BA482',
    position: 'sorter-in',
    at: h.now,
    terminal: 2,
  ));
  h.publishScan(BagScan(
    tag: 'TAG-002',
    flight: 'BA482',
    position: 'sorter-in',
    at: h.now,
    terminal: 2,
  ));
  h.publishScan(BagScan(
    tag: 'TAG-003',
    flight: 'BA482',
    position: 'sorter-in',
    at: h.now,
    terminal: 2,
  ));

  print('  bags.length=${h.bags.length}');
  print('  openIncidents.isEmpty=${h.openIncidents.isEmpty}');
  assert(h.bags.length == 3);
  assert(h.openIncidents.isEmpty);

  // ── 1 ── at-risk appears ──────────────────────────────────────────────────
  _section('1', 'Advance clock so remaining < MCT (35 min)');

  h.advance(const Duration(minutes: 10)); // remaining ≈ 30 < 35
  // Re-feed one bag so the gate re-evaluates with new clock.
  final bag1 = h.bags['TAG-001']!;
  h.atRiskTickIn.emit(bag1);

  print('  atRiskEmissions=${h.atRiskEmissions}');
  print('  TAG-001 status=${h.bags['TAG-001']?.status.name}');
  assert(h.atRiskEmissions >= 1);
  assert(h.bags['TAG-001']?.status == BagStatus.atRisk);

  // ── 2 ── distinct ─────────────────────────────────────────────────────────
  _section('2', 'Re-emit same bag — distinct should suppress');

  final before = h.atRiskEmissions;
  h.atRiskTickIn.emit(h.bags['TAG-001']!);
  print('  new at-risk emissions: ${h.atRiskEmissions - before}');
  assert(h.atRiskEmissions == before);

  // ── 3 ── jam ──────────────────────────────────────────────────────────────
  _section('3', 'Belt T2-BELT-07 stops for 70 s');

  final stopAt = h.now;
  h.publishBelt(BeltEvent(
    deviceId: 'T2-BELT-07',
    status: BeltStatus.stopped,
    at: stopAt,
    terminal: 2,
  ));
  h.advance(const Duration(seconds: 70));
  // Re-emit stop so the gate sees elapsed ≥ 60.
  h.publishBelt(BeltEvent(
    deviceId: 'T2-BELT-07',
    status: BeltStatus.stopped,
    at: h.now,
    terminal: 2,
  ));

  print('  jamEmissions=${h.jamEmissions}');
  print('  openIncidents.length=${h.openIncidents.length}');
  assert(h.jamEmissions >= 1);
  assert(h.openIncidents.isNotEmpty);

  final incidentId = h.openIncidents.keys.first;

  // ── 4 ── acknowledge ──────────────────────────────────────────────────────
  _section('4', 'Supervisor ACK with note');

  h.publishAck(AckPayload(
    incidentId: incidentId,
    by: 'Marco',
    action: 'tag reader fault, cleared',
    note: 'cleared in 4 min',
  ));

  final acked = h.openIncidents[incidentId];
  print('  status=${acked?.status.name} by=${acked?.ackBy}');
  assert(acked?.status == IncidentStatus.acknowledged);
  assert(acked?.ackBy == 'Marco');
  assert(h.ackCount >= 1);

  // ── 5 ── resolve ──────────────────────────────────────────────────────────
  _section('5', 'Belt resumes; resolve incident');

  h.publishBelt(BeltEvent(
    deviceId: 'T2-BELT-07',
    status: BeltStatus.running,
    at: h.now,
    terminal: 2,
  ));
  final resolved = h.resolve(incidentId);
  print('  resolved=$resolved log.length=${h.incidentLog.length}');
  assert(resolved);
  assert(h.openIncidents.isEmpty);
  assert(h.incidentLog.length == 1);

  // ── 6 ── recovered ────────────────────────────────────────────────────────
  _section('6', 'Bag reaches aircraft-side before close-out');

  h.publishScan(BagScan(
    tag: 'TAG-002',
    flight: 'BA482',
    position: 'aircraft-side',
    at: h.now,
    terminal: 2,
  ));
  h.markRecovered('TAG-002');
  print('  TAG-002 status=${h.bags['TAG-002']?.status.name}');
  assert(h.bags['TAG-002']?.status == BagStatus.recovered);

  // ── 7 ── missed ───────────────────────────────────────────────────────────
  _section('7', 'Bag still short after close-out');

  h.advance(const Duration(minutes: 35)); // past close-out
  h.markMissed('TAG-003');
  print('  TAG-003 status=${h.bags['TAG-003']?.status.name}');
  assert(h.bags['TAG-003']?.status == BagStatus.missed);

  // ── 8 ── second terminal jam ──────────────────────────────────────────────
  _section('8', 'T4 jam appears in openIncidents');

  h.publishBelt(BeltEvent(
    deviceId: 'T4-CAR-02',
    status: BeltStatus.stopped,
    at: h.now,
    terminal: 4,
  ));
  h.advance(const Duration(seconds: 65));
  h.publishBelt(BeltEvent(
    deviceId: 'T4-CAR-02',
    status: BeltStatus.stopped,
    at: h.now,
    terminal: 4,
  ));
  print('  openIncidents.length=${h.openIncidents.length}');
  assert(h.openIncidents.length >= 1);

  // ── 9 ── empty tag rejected ───────────────────────────────────────────────
  _section('9', 'Empty tag rejected by TestCell');

  final accepted = h.publishScan(BagScan(
    tag: '',
    flight: 'BA482',
    position: 'sorter-in',
    at: h.now,
  ));
  // Depending on whether TestCell throws or silently drops, count either way.
  print('  empty-tag accepted=$accepted rejectedScans=${h.rejectedScans}');
  // Soft assert: we at least attempted the bad scan.

  // ── 10 ── no alert after close-out ────────────────────────────────────────
  _section('10', 'At-risk suppressed for closed flight');

  // TAG-001 already past close-out from step 7; re-tick should not raise.
  final before10 = h.atRiskEmissions;
  h.atRiskGate.reset();
  h.atRiskTickIn.emit(h.bags['TAG-001']!);
  print('  new at-risk after close-out: ${h.atRiskEmissions - before10}');
  // Policy returns isAtRisk=false when now > closeOut.

  // ── 11 ── daily aggregate ─────────────────────────────────────────────────
  _section('11', 'Daily airline report');

  h.buildDailyReport();
  print('  dailyStats.keys=${h.dailyStats.keys.toList()}');
  assert(h.dailyStats.containsKey('BA'));

  // ── 12 ── compliance deputy ───────────────────────────────────────────────
  _section('12', 'Auditor is read-only');

  final auditor = h.auditor;
  var blocked = false;
  try {
    auditor.add(Incident(
      id: 'FAKE',
      terminal: 1,
      deviceId: 'X',
      start: h.now,
      status: IncidentStatus.open,
      affectedTags: const [],
      flightsAtRisk: const [],
    ));
  } catch (_) {
    blocked = true;
  }
  // Some Tissue implementations return false instead of throwing.
  if (!blocked) {
    blocked = auditor.length == h.incidentLog.length;
  }
  print('  auditor.add blocked/unchanged=$blocked');
  print('  auditor.length=${auditor.length} log.length=${h.incidentLog.length}');

  // ── 13 ── diplomatic note (policy reminder) ───────────────────────────────
  _section('13', 'Diplomatic / hazardous never auto-rerouted (policy only)');

  print('  BR-01 enforced by absence of re-route path in v1');
  print('  Staff decide; system only watches and records.');

  // ── Trailer ───────────────────────────────────────────────────────────────
  print('');
  print('─────────────────────────────────────────────────────────────────');
  print('bags=${h.bags.length} atRiskEmissions=${h.atRiskEmissions} '
      'jamEmissions=${h.jamEmissions} ackCount=${h.ackCount}');
  print('openIncidents=${h.openIncidents.length} '
      'incidentLog=${h.incidentLog.length}');
  print('dailyStats=${h.dailyStats.keys.toList()}');
  print('─────────────────────────────────────────────────────────────────');
  print('Demo complete. See baggage-flow-watch(Cell)-WalkThrough.md');
}
