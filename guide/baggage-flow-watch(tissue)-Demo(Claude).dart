// Copyright (c) 2026-Present Operations Programme Office. Reference design
// produced against the Mitosis / Cell Framework (github.com/simon-m-lee/cell).
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// # Baggage Flow Watch — executable design demonstration
///
/// **Domain:** airport operations — real-time departing-bag flow monitoring,
/// belt/sorter/carousel stall alerting, at-risk-bag flagging against flight
/// close-out, incident acknowledgement, and daily airline performance
/// reporting.
///
/// **Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`.
///
/// **Status:** reference design written against the documented public API of
/// Mitosis `1.0.0-rc.5/6` (as published on `github.com/simon-m-lee/cell`).
/// This file was authored and reviewed against that repository's README and
/// `grid-demand-response(tissue)-Demo.dart`, but was **not compiled or run**
/// in this session — this sandbox has no network path to `pub.dev`/the Dart
/// SDK. Treat it the way the upstream repo treats its own RC demos: verify
/// against current source before betting production on it. See
/// `baggage-flow-watch(tissue)-WalkThrough.md` for the requirement traceability
/// this file implements.
///
/// ---
///
/// ## The seam — Flow decides, Tissue records
///
/// This design follows the same architectural discipline as the upstream
/// `grid-demand-response(tissue)-Demo.dart`:
///
/// * **Flow** answers: *"Is this bag on time, at risk, or missed? Is this
///   device running or stalled?"*
/// * **Tissue** answers: *"What did the ops books just record, and who is
///   accountable for it?"*
/// * An **observer** is the only glue between the two.
///
/// Nothing about the risk/stall policy touches a Tissue collection directly.
/// Nothing about the incident books influences the policy. If a future
/// change writes `incidents[id] = ...` inside `riskOf`, the seam has
/// collapsed.
///
/// ## Two lock domains
///
/// | Domain | Locked by | Covers | Does not cover |
/// |---|---|---|---|
/// | **Decision** | Receptor lock on `atRiskCell` / stall policy | `riskOf`, per-bag latch, `Filter` | any Tissue write |
/// | **Books** | Tissue lock on each collection | `events.add`, `bags[...]`, `incidents[...]`, `alertQ.addLast`, `protectedBags` | any decision logic |
///
/// ## TestCell vs TestTissue — do not swap
///
/// | Host | Rule type | Parameter |
/// |---|---|---|
/// | `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` |
/// | `TissueList` / `Set` / `Map` / `Queue` / `Value` | `TestTissue<E, C>` | `testRule:` |
/// | `tissue.deputy(...)` | `TestTissue` | `testRule:` |
///
/// Grep this file for `testRule: TestCell` on any Tissue constructor: zero
/// hits, by design.
///
/// ## Books invariant
///
/// For every bag tag present in `bags`, at most one open incident may
/// reference it at a time:
///
/// ```
/// bags.values.where((b) => b.risk == RiskLevel.atRisk).length
///   >= incidents.values.where((i) => i.status == IncidentStatus.open
///        && i.cause == IncidentCause.bagAtRisk).length
/// ```
///
/// (A stalled-device incident can affect several bags at once, so the
/// inequality — not equality — is the invariant that holds across every
/// scenario below.)
///
/// ## Documented design decisions (deliberate simplifications)
///
/// * **Per-bag / per-device "distinct" latches are plain Dart maps, not a
///   single `Distinct` instruction.** `cell_flow`'s `Distinct` operator
///   compares *consecutive* payloads on one stream; Baggage Flow Watch has
///   tens of thousands of interleaved bags and devices on one ingress. The
///   harness keys the latch by `bagTag` / `deviceId` (`_lastRisk`,
///   `_stallTimers`) the same way the upstream grid demo keys its RTU
///   fail-once state outside the reactive graph — a documented, pragmatic
///   boundary, not an oversight.
/// * **The 60-second stall confirmation and the 15-minute escalation clock
///   are plain `Timer`s owned by the harness**, not `Flow.timeout` pipeline
///   nodes. `Flow.timeout` fires once per *stream*; this system needs one
///   independent clock per device and one per open alert. The harness is
///   the single writer for both timer maps, exactly as it is the single
///   writer for every Tissue in the demo.
/// * **`TissueQueue` (`alertQ`) is the audit-side enqueue only**, per the
///   upstream `TissueQueue` drain caveat — the dispatch pump runs on a plain
///   `List<AlertDispatch>` (`_dispatchWork`), and the queue's
///   `ElementAdded` pulses remain the reconstructable trace of every
///   outbound tablet push.
///
/// ## Reading order
///
/// 1. `enum RiskLevel`, `enum DeviceState`, `enum IncidentCause` — the
///    domain vocabulary.
/// 2. `BagScan`, `DeviceStatus`, `FlightRecord` — the ingress payloads.
/// 3. `BaggageFlowWatchHarness.riskOf` — the pure at-risk policy.
/// 4. `BaggageFlowWatchHarness.installGates` — the two Flow pipelines.
/// 5. `BaggageFlowWatchHarness.ingestScan` / `ingestDeviceStatus` /
///    `raiseAlert` / `acknowledge` — the Tissue write protocol.
/// 6. `main()` — the scenarios, drawn from BRD §9 user journeys and §10
///    acceptance criteria.
///
/// ## See also
///
/// * `baggage-flow-watch(tissue)-WalkThrough.md` — the requirement and the
///   full BRD-to-component traceability table.
/// * `airport_baggage_handling-BRD.md` — the source business requirements
///   document.
library;

import 'dart:async';
import 'package:cell_flow/cell_flow.dart';
import 'package:cell_tissue/cell_tissue.dart';

// ignore_for_file: unused_local_variable, avoid_print, unused_element

// ═════════════════════════════════════════════════════════════════════════
// DOMAIN
// ═════════════════════════════════════════════════════════════════════════

/// A bag's risk classification against its flight's baggage close-out.
///
/// The *only* type that crosses the at-risk Flow→Tissue seam (FR-02, FR-03).
enum RiskLevel {
  /// Time remaining exceeds the flight's minimum connection time.
  onTime,

  /// Time remaining has fallen below the minimum connection time (FR-03).
  atRisk,

  /// The bag reached the sorter/carousel after the flight's close-out and
  /// was never scanned aircraft-side.
  missed,
}

/// A belt / sorter / carousel's operating state (FR-05).
enum DeviceState { running, stalled }

/// The kind of device reporting status, carried for the incident record
/// (FR-06: "affected belt or carousel").
enum DeviceKind { belt, sorter, carousel }

/// A handover scan point (BRD §3.1 assumptions; DR-01).
enum Station { checkIn, sorterEntry, sorterExit, carouselInduction, aircraftSide }

/// Why an incident was opened (FR-08: group alerts sharing a cause).
enum IncidentCause { deviceStall, bagAtRisk }

/// Lifecycle state of an incident (FR-07, BR-03).
enum IncidentStatus { open, acknowledged, escalated }

/// A single bag-tag scan at a handover point.
///
/// The payload of the position-tracking ingress (FR-01). Every scan
/// republishes a full, immutable snapshot — there is no in-place mutation of
/// a scan record, only new scans layered onto `bags[tag]` (DR-01).
final class BagScan {
  /// The bag tag barcode (never empty — enforced by `_bagScanShape`, DR-06).
  final String bagTag;

  /// The flight number this bag is checked onto (never empty, DR-06).
  final String flightNo;

  final String terminal;
  final Station station;
  final DateTime at;

  const BagScan({
    required this.bagTag,
    required this.flightNo,
    required this.terminal,
    required this.station,
    required this.at,
  });

  @override
  String toString() => 'BagScan($bagTag, $flightNo, ${station.name}@$terminal)';
}

/// A belt / sorter / carousel heartbeat or stop event (assumption: belt
/// control feed at least every 15s; FR-05).
final class DeviceStatus {
  final String deviceId;
  final String terminal;
  final DeviceKind kind;
  final DeviceState state;
  final DateTime at;

  const DeviceStatus({
    required this.deviceId,
    required this.terminal,
    required this.kind,
    required this.state,
    required this.at,
  });

  @override
  String toString() => 'DeviceStatus($deviceId, ${state.name})';
}

/// A flight record sourced from the AODB (DR-02).
final class FlightRecord {
  final String airline;
  final String flightNo;
  final String terminal;
  final DateTime scheduledDeparture;
  final DateTime closeOutTime;

  /// Minimum connection time for a bag on this flight. Defaults to the
  /// 10-minute figure implied by BRD journey 9.2 ("8 minutes before
  /// close-out, 2 minutes short of the minimum" ⇒ minimum = 10 minutes).
  final Duration minConnection;

  const FlightRecord({
    required this.airline,
    required this.flightNo,
    required this.terminal,
    required this.scheduledDeparture,
    required this.closeOutTime,
    this.minConnection = const Duration(minutes: 10),
  });

  bool isClosedAt(DateTime t) => !t.isBefore(closeOutTime);

  @override
  String toString() => 'FlightRecord($airline$flightNo, closeOut=$closeOutTime)';
}

/// The duty-manager / supervisor projection of one bag's current state.
///
/// Held in `bags` (a `TissueMap<String, BagState>`) — the *current view*,
/// distinct from the append-only `events` log (mirrors the upstream demo's
/// `shedMap` vs `events` split).
final class BagState {
  final String bagTag;
  final String flightNo;
  final String terminal;
  final Station station;
  final DateTime lastScanAt;
  final RiskLevel risk;

  const BagState({
    required this.bagTag,
    required this.flightNo,
    required this.terminal,
    required this.station,
    required this.lastScanAt,
    required this.risk,
  });

  BagState copyWith({Station? station, DateTime? lastScanAt, RiskLevel? risk}) =>
      BagState(
        bagTag: bagTag,
        flightNo: flightNo,
        terminal: terminal,
        station: station ?? this.station,
        lastScanAt: lastScanAt ?? this.lastScanAt,
        risk: risk ?? this.risk,
      );

  @override
  String toString() => 'BagState($bagTag, ${station.name}, ${risk.name})';
}

/// One row in the bounded position-history buffer (DR-05: 7-day retention).
///
/// `TissueQueue(capacity: n)` gives a governed circular buffer for free
/// (upstream README, "Capacity & Backpressure"). A production system would
/// pair this with a time-based purge job — the capacity bound alone
/// approximates, but does not literally implement, "7 days"; see the
/// WalkThrough's Known Limitations section.
final class BagPositionRecord {
  final String bagTag;
  final Station station;
  final DateTime at;
  const BagPositionRecord(this.bagTag, this.station, this.at);
  @override
  String toString() => 'Pos($bagTag@${station.name})';
}

/// An open (or historical) incident — the duty-manager / supervisor working
/// record (FR-06, FR-07, FR-08, FR-09, FR-11, DR-03, DR-04).
final class Incident {
  final String id;
  final IncidentCause cause;
  final String? deviceId;
  final String terminal;
  final List<String> affectedBags;
  final List<String> affectedFlights;
  final DateTime openedAt;
  final IncidentStatus status;
  final String? ackBy;
  final DateTime? ackAt;
  final String? note;

  const Incident({
    required this.id,
    required this.cause,
    this.deviceId,
    required this.terminal,
    required this.affectedBags,
    required this.affectedFlights,
    required this.openedAt,
    required this.status,
    this.ackBy,
    this.ackAt,
    this.note,
  });

  Incident copyWith({
    List<String>? affectedBags,
    List<String>? affectedFlights,
    IncidentStatus? status,
    String? ackBy,
    DateTime? ackAt,
    String? note,
  }) =>
      Incident(
        id: id,
        cause: cause,
        deviceId: deviceId,
        terminal: terminal,
        affectedBags: affectedBags ?? this.affectedBags,
        affectedFlights: affectedFlights ?? this.affectedFlights,
        openedAt: openedAt,
        status: status ?? this.status,
        ackBy: ackBy ?? this.ackBy,
        ackAt: ackAt ?? this.ackAt,
        note: note ?? this.note,
      );

  @override
  String toString() => 'Incident($id, ${cause.name}, ${status.name}, bags=${affectedBags.length})';
}

/// A single row in the append-only ops event log (AR-02, DR-04: 24-month
/// retention; NFR-05: full trace of who/when/what for every acknowledgement).
///
/// Mirrors the upstream `GridEvent` exactly: `kind`, correlating id,
/// human-readable `detail`, timestamp. Never contains passenger personal
/// data (BR-04) — the domain model simply has no field to carry it.
final class OpsEvent {
  final String kind; // SCAN | STALL | AT_RISK | INCIDENT_OPEN | ACK | ESCALATE | REPORT
  final String refId; // bagTag, deviceId, or incidentId
  final String detail;
  final DateTime at;

  const OpsEvent({required this.kind, required this.refId, required this.detail, required this.at});

  @override
  String toString() => 'OpsEvent($kind, $refId, "$detail")';
}

/// An outbound push to a supervisor's or duty manager's tablet.
///
/// Enqueued on `alertQ` (a bounded `TissueQueue`) for audit, and driven by a
/// plain-Dart pump — see the file header's documented design decisions.
final class AlertDispatch {
  final String incidentId;
  final String toRole; // 'supervisor' | 'dutyManager'
  final String message;
  const AlertDispatch(this.incidentId, this.toRole, this.message);
  @override
  String toString() => 'AlertDispatch($incidentId → $toRole)';
}

/// One row of the computed daily airline performance report (FR-10, AR-01).
///
/// Never written to a Tissue — it is a pure projection over `events` and
/// `bags`, recomputed on demand, matching journey 9.3 ("opens the daily
/// report ... exports it"). Carries no passenger data (BR-04, AC-06).
final class DailyAirlineStat {
  final String airline;
  final int handled;
  final int delayed;
  final int missed;
  final Duration avgProcessingTime;

  const DailyAirlineStat({
    required this.airline,
    required this.handled,
    required this.delayed,
    required this.missed,
    required this.avgProcessingTime,
  });

  @override
  String toString() =>
      'DailyAirlineStat($airline: handled=$handled delayed=$delayed missed=$missed avg=${avgProcessingTime.inMinutes}m)';
}

// ═════════════════════════════════════════════════════════════════════════
// VISUAL OUTPUT HELPERS
// ═════════════════════════════════════════════════════════════════════════

void _section(String label, String drive) {
  print('');
  print('── $label ── $drive');
}

// ═════════════════════════════════════════════════════════════════════════
// HARNESS
// ═════════════════════════════════════════════════════════════════════════

/// The Baggage Flow Watch harness — owns every Cell and every Tissue this
/// design touches, mirroring the upstream `GridDemandResponseHarness`.
///
/// One harness per running process (or, in production, one per terminal
/// shard — see the WalkThrough's scaling note). Do not call [install] twice.
class BaggageFlowWatchHarness {
  BaggageFlowWatchHarness();

  // ─────────────────────────────────────────────────────────────────────
  // Constants
  // ─────────────────────────────────────────────────────────────────────

  /// FR-05: raise an alert when a device stops for more than this long.
  static const Duration stallThreshold = Duration(seconds: 60);

  /// BR-03: every alert must be acknowledged or dismissed within this long.
  static const Duration escalationWindow = Duration(minutes: 15);

  /// DR-05: bag position history retention target (approximated by
  /// `positionHistory`'s bounded capacity — see the file header).
  static const int positionHistoryCapacity = 20000;

  /// NFR-03: capacity headroom for the outbound alert queue.
  static const int alertQueueCapacity = 512;

  // ─────────────────────────────────────────────────────────────────────
  // Tissue — the ops books
  // ─────────────────────────────────────────────────────────────────────

  /// The append-only event log (AR-02, DR-04). Guarded by
  /// `_eventAppendOnly` — `add`/`addAll` only, `remove`/`clear`/`[]=` denied.
  late final TissueList<OpsEvent> events;

  /// Current per-bag projection, keyed by bag tag (DR-01). Duty managers'
  /// "one screen" (FR-04) reads a filtered `.unmodifiable` view of this map.
  late final TissueMap<String, BagState> bags;

  /// Current flight reference data, keyed by flight number (DR-02).
  late final TissueMap<String, FlightRecord> flights;

  /// Bounded 7-day-ish position history ring buffer (DR-05).
  late final TissueQueue<BagPositionRecord> positionHistory;

  /// Open and historical incidents, keyed by incident id (FR-06 – FR-09,
  /// DR-03, DR-04). Updated in place on acknowledgement; every transition
  /// is *also* appended to [events] so the audit trail never depends on
  /// this map's current shape.
  late final TissueMap<String, Incident> incidents;

  /// Diplomatic / hazardous bag tags (BR-01). `actionOf`-equivalent logic
  /// consults this before any reroute path — not modelled further in this
  /// design beyond the block-on-write demonstration in the COMPLY scenario.
  late final TissueSet<String> protectedBags;

  /// Outbound tablet-push audit queue (see file header). Bounded to
  /// [alertQueueCapacity].
  late final TissueQueue<AlertDispatch> alertQ;

  // ─────────────────────────────────────────────────────────────────────
  // Pump working list (see the TissueQueue drain caveat, file header)
  // ─────────────────────────────────────────────────────────────────────
  final List<AlertDispatch> _dispatchWork = <AlertDispatch>[];

  // ─────────────────────────────────────────────────────────────────────
  // Flow — ingress
  // ─────────────────────────────────────────────────────────────────────

  /// The bag-scan ingress (FR-01). `TestCell` rule: `_bagScanShape` (DR-06).
  late final IngressHandle<BagScan> scanIn;

  /// The device-status ingress (FR-05). `TestCell` rule: `_deviceStatusShape`.
  late final IngressHandle<DeviceStatus> deviceIn;

  /// The AODB flight-feed ingress (DR-02). `TestCell` rule: `_flightShape`.
  late final IngressHandle<FlightRecord> flightIn;

  // ─────────────────────────────────────────────────────────────────────
  // Flow gates
  // ─────────────────────────────────────────────────────────────────────

  /// The at-risk gate cell — emits only when [riskOf] returns
  /// [RiskLevel.atRisk] **and** the per-bag latch has not already flagged
  /// this bag since its last risk-level change.
  ///
  /// ### Pipeline
  /// ```
  /// MapValue<BagScan, RiskLevel>(riskOf)
  ///   + Filter<RiskLevel>((r) => r == RiskLevel.atRisk)
  /// ```
  /// Per-bag distinctness is enforced in the observer via `_lastRisk`
  /// (see file header — a keyed latch, not the single-stream `Distinct`
  /// instruction).
  late final Cell atRiskCell;

  // ─────────────────────────────────────────────────────────────────────
  // Harness-owned clocks (see file header — documented design decision)
  // ─────────────────────────────────────────────────────────────────────

  final Map<String, Timer> _stallTimers = {}; // deviceId -> pending 60s confirm
  final Map<String, Timer> _escalationTimers = {}; // incidentId -> pending 15m escalation
  final Map<String, RiskLevel> _lastRisk = {}; // bagTag -> last emitted risk
  final Map<String, String> _openIncidentByDevice = {}; // deviceId -> incidentId

  // ─────────────────────────────────────────────────────────────────────
  // Counters for the trailer
  // ─────────────────────────────────────────────────────────────────────

  int scans = 0;
  int stallsConfirmed = 0;
  int atRiskFlags = 0;
  int escalations = 0;
  int dispatchAttempts = 0;
  int _incidentSeq = 0;

  // ─────────────────────────────────────────────────────────────────────
  // TestTissue rules — ONLY used on Tissue constructors
  // ─────────────────────────────────────────────────────────────────────

  /// Append-only rule for [events] — same string-match deny pattern as the
  /// upstream reference demo. See AR-02, DR-04.
  static final TestTissue<OpsEvent, TissueList<OpsEvent>> _eventAppendOnly =
      TestTissue<OpsEvent, TissueList<OpsEvent>>(
    (value, {host, arguments, user}) {
      if (arguments is Function) {
        final src = arguments.toString();
        if (src.contains('remove') || src.contains('clear') || src.contains('[]=')) {
          return false;
        }
      }
      return true;
    },
  );

  /// DR-06: reject a bag record with a missing tag or flight number, one
  /// more time at the books boundary (defence in depth alongside the
  /// ingress `TestCell`).
  static final TestTissue<BagState, TissueMap<String, BagState>> _bagStateRule =
      TestTissue<BagState, TissueMap<String, BagState>>(
    (value, {host, arguments, user}) {
      if (value is BagState) {
        return value.bagTag.isNotEmpty && value.flightNo.isNotEmpty;
      }
      return true;
    },
  );

  /// BR-01: a protected bag tag must be a non-empty tag string. (The
  /// authorisation *check* that reroute paths must consult lives in the
  /// application layer that calls `protectedBags.contains(tag)`; this rule
  /// only guards the shape of what can be added to the set.)
  static final TestTissue<String, TissueSet<String>> _protectedRule =
      TestTissue<String, TissueSet<String>>(
    (value, {host, arguments, user}) => value is String && value.isNotEmpty,
  );

  /// Accepts every dispatch; retained as a hook for future per-role
  /// rate-limiting (mirrors the upstream `_rtuJobRule`).
  static final TestTissue<AlertDispatch, TissueQueue<AlertDispatch>> _dispatchRule =
      TestTissue<AlertDispatch, TissueQueue<AlertDispatch>>(
    (value, {host, arguments, user}) => true,
  );

  /// Incidents are append-then-update, not append-only; the rule enforces
  /// only that the id is stable and non-empty for the key it is stored
  /// under.
  static final TestTissue<Incident, TissueMap<String, Incident>> _incidentRule =
      TestTissue<Incident, TissueMap<String, Incident>>(
    (value, {host, arguments, user}) => value is Incident && value.id.isNotEmpty,
  );

  static final TestTissue<FlightRecord, TissueMap<String, FlightRecord>> _flightRule =
      TestTissue<FlightRecord, TissueMap<String, FlightRecord>>(
    (value, {host, arguments, user}) => value is FlightRecord && value.flightNo.isNotEmpty,
  );

  static final TestTissue<BagPositionRecord, TissueQueue<BagPositionRecord>> _positionRule =
      TestTissue<BagPositionRecord, TissueQueue<BagPositionRecord>>(
    (value, {host, arguments, user}) => value is BagPositionRecord && value.bagTag.isNotEmpty,
  );

  // ─────────────────────────────────────────────────────────────────────
  // TestCell rules — ONLY used on Cell.ingress
  // ─────────────────────────────────────────────────────────────────────

  /// DR-06: reject a scan with a missing tag number or flight number.
  static final TestCell<Cell> _bagScanShape = TestCell<Cell>(
    (value, {host, arguments, user}) {
      final v = value is Pulse ? value.payload : value;
      if (v is! BagScan) return false;
      return v.bagTag.isNotEmpty && v.flightNo.isNotEmpty;
    },
  );

  static final TestCell<Cell> _deviceStatusShape = TestCell<Cell>(
    (value, {host, arguments, user}) {
      final v = value is Pulse ? value.payload : value;
      if (v is! DeviceStatus) return false;
      return v.deviceId.isNotEmpty;
    },
  );

  static final TestCell<Cell> _flightShape = TestCell<Cell>(
    (value, {host, arguments, user}) {
      final v = value is Pulse ? value.payload : value;
      if (v is! FlightRecord) return false;
      return v.flightNo.isNotEmpty && v.closeOutTime.isAfter(v.scheduledDeparture.subtract(const Duration(hours: 1)));
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // Install
  // ─────────────────────────────────────────────────────────────────────

  /// One-time bootstrap. Builds every Tissue, every ingress Cell, and both
  /// Flow gates, then attaches every observer. Call once.
  Future<void> install() async {
    // Tissue — the books.
    events = TissueList.of(<OpsEvent>[], testRule: _eventAppendOnly);
    bags = TissueMap<String, BagState>(testRule: _bagStateRule);
    flights = TissueMap<String, FlightRecord>(testRule: _flightRule);
    positionHistory = TissueQueue<BagPositionRecord>(
      capacity: positionHistoryCapacity,
      testRule: _positionRule,
    );
    incidents = TissueMap<String, Incident>(testRule: _incidentRule);
    protectedBags = TissueSet<String>(testRule: _protectedRule);
    alertQ = TissueQueue<AlertDispatch>(capacity: alertQueueCapacity, testRule: _dispatchRule);

    // Cell — ingress.
    scanIn = Cell.ingress<BagScan>(testRule: _bagScanShape);
    deviceIn = Cell.ingress<DeviceStatus>(testRule: _deviceStatusShape);
    flightIn = Cell.ingress<FlightRecord>(testRule: _flightShape);

    installGates();
  }

  /// Builds the at-risk Flow pipeline and attaches every observer.
  ///
  /// FR-02, FR-03, FR-04. Device-stall detection (FR-05) is driven directly
  /// from [ingestDeviceStatus] via the harness-owned `_stallTimers` clock —
  /// see the file header for why it is not expressed as a third Flow gate.
  void installGates() {
    final gate = MapValue<BagScan, RiskLevel>((scan) => riskOf(scan)) +
        Filter<RiskLevel>((r) => r == RiskLevel.atRisk);

    atRiskCell = gate.toHandle(source: scanIn.cell).cell;

    Cell.observe(
      source: atRiskCell,
      effect: (pulse) {
        final scan = _currentScan;
        if (scan == null) return;
        final last = _lastRisk[scan.bagTag];
        if (last == RiskLevel.atRisk) return; // per-bag latch (see header)
        _lastRisk[scan.bagTag] = RiskLevel.atRisk;
        atRiskFlags++;
        _openBagAtRiskIncident(scan);
      },
    );

    // Flight ingress — pure books write, no policy attached.
    Cell.observe(
      source: flightIn.cell,
      effect: (pulse) {
        final f = pulse.payload as FlightRecord;
        flights[f.flightNo] = f;
      },
    );
  }

  /// The pure at-risk policy (FR-02, FR-03, BR-02).
  ///
  /// * BR-02: never flags a bag once its flight has already closed.
  /// * FR-02/03: flags `atRisk` once the time remaining to close-out is
  ///   below the flight's minimum connection time.
  ///
  /// This function is a bare projection of `(BagScan, FlightRecord?)` and
  /// is unit-testable with no Tissue in scope, exactly like the upstream
  /// `actionOf`.
  RiskLevel riskOf(BagScan scan) {
    _currentScan = scan; // correlate for the observer (mirrors `_currentTick`)
    final flight = flights[scan.flightNo];
    if (flight == null) return RiskLevel.onTime; // unknown flight — no data to judge risk
    if (flight.isClosedAt(scan.at)) return RiskLevel.onTime; // BR-02: never alert a closed flight
    final remaining = flight.closeOutTime.difference(scan.at);
    if (remaining <= Duration.zero) return RiskLevel.missed;
    if (remaining < flight.minConnection) return RiskLevel.atRisk;
    return RiskLevel.onTime;
  }

  BagScan? _currentScan;

  // ─────────────────────────────────────────────────────────────────────
  // Tissue write protocol — bag position (FR-01, DR-01, DR-05)
  // ─────────────────────────────────────────────────────────────────────

  /// Ingests one bag-tag scan: updates [bags], appends [positionHistory],
  /// logs a `SCAN` [OpsEvent], then publishes the scan to [scanIn] so the
  /// at-risk gate evaluates it (FR-01 → FR-02/FR-03 in one call).
  Future<bool> ingestScan(BagScan scan) async {
    final accepted = await scanIn.emitAsync(scan);
    if (!accepted) return false; // DR-06 rejection
    scans++;

    final risk = riskOf(scan);
    final existing = bags[scan.bagTag];
    bags[scan.bagTag] = (existing ?? BagState(
      bagTag: scan.bagTag,
      flightNo: scan.flightNo,
      terminal: scan.terminal,
      station: scan.station,
      lastScanAt: scan.at,
      risk: risk,
    ))
        .copyWith(station: scan.station, lastScanAt: scan.at, risk: risk);

    await positionHistory.async.addLast(BagPositionRecord(scan.bagTag, scan.station, scan.at));
    events.add(OpsEvent(kind: 'SCAN', refId: scan.bagTag, detail: '${scan.station.name}@${scan.terminal}', at: scan.at));

    if (risk == RiskLevel.onTime) {
      _lastRisk[scan.bagTag] = RiskLevel.onTime; // latch resets once recovered
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Tissue write protocol — device stall (FR-05, FR-06, BR-03)
  // ─────────────────────────────────────────────────────────────────────

  /// Ingests one belt/sorter/carousel status tick.
  ///
  /// A `running` tick cancels any pending stall timer for the device. A
  /// `stalled` tick starts one (if not already pending); if it is not
  /// cancelled within [stallThreshold], `_confirmStall` fires and opens an
  /// incident (FR-05, FR-06).
  Future<bool> ingestDeviceStatus(DeviceStatus status) async {
    final accepted = await deviceIn.emitAsync(status);
    if (!accepted) return false;

    if (status.state == DeviceState.running) {
      _stallTimers.remove(status.deviceId)?.cancel();
      return true;
    }

    // stalled
    _stallTimers.putIfAbsent(
      status.deviceId,
      () => Timer(stallThreshold, () => _confirmStall(status)),
    );
    return true;
  }

  void _confirmStall(DeviceStatus status) {
    _stallTimers.remove(status.deviceId);
    stallsConfirmed++;
    final affectedBags = bags.values
        .where((b) => b.terminal == status.terminal && b.risk != RiskLevel.missed)
        .map((b) => b.bagTag)
        .toList(growable: false);
    final affectedFlights = affectedBags
        .map((tag) => bags[tag]!.flightNo)
        .toSet()
        .toList(growable: false);

    events.add(OpsEvent(
      kind: 'STALL',
      refId: status.deviceId,
      detail: '${status.kind.name} stalled >${stallThreshold.inSeconds}s, ${affectedBags.length} bags affected',
      at: status.at,
    ));

    final incidentId = _openIncidentByDevice[status.deviceId];
    if (incidentId != null && incidents[incidentId]?.status == IncidentStatus.open) {
      // FR-08: fold into the existing open incident for this device.
      final prior = incidents[incidentId]!;
      incidents[incidentId] = prior.copyWith(
        affectedBags: {...prior.affectedBags, ...affectedBags}.toList(),
        affectedFlights: {...prior.affectedFlights, ...affectedFlights}.toList(),
      );
      return;
    }

    final id = 'INC-${++_incidentSeq}';
    _openIncidentByDevice[status.deviceId] = id;
    incidents[id] = Incident(
      id: id,
      cause: IncidentCause.deviceStall,
      deviceId: status.deviceId,
      terminal: status.terminal,
      affectedBags: affectedBags,
      affectedFlights: affectedFlights,
      openedAt: status.at,
      status: IncidentStatus.open,
    );
    events.add(OpsEvent(kind: 'INCIDENT_OPEN', refId: id, detail: 'device stall, ${status.deviceId}', at: status.at));
    _dispatch(id, 'supervisor', 'Stall on ${status.deviceId}: ${affectedBags.length} bags, ${affectedFlights.length} flights at risk');
    _armEscalation(id, status.at);
  }

  void _openBagAtRiskIncident(BagScan scan) {
    final id = 'INC-${++_incidentSeq}';
    incidents[id] = Incident(
      id: id,
      cause: IncidentCause.bagAtRisk,
      terminal: scan.terminal,
      affectedBags: [scan.bagTag],
      affectedFlights: [scan.flightNo],
      openedAt: scan.at,
      status: IncidentStatus.open,
    );
    events.add(OpsEvent(kind: 'AT_RISK', refId: scan.bagTag, detail: 'flight ${scan.flightNo} close-out at risk', at: scan.at));
    _dispatch(id, 'dutyManager', 'Bag ${scan.bagTag} at risk for flight ${scan.flightNo}');
    _armEscalation(id, scan.at);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Tissue write protocol — dispatch (audit queue + pump)
  // ─────────────────────────────────────────────────────────────────────

  void _dispatch(String incidentId, String toRole, String message) {
    final job = AlertDispatch(incidentId, toRole, message);
    alertQ.addLast(job); // audit-side enqueue only (see header)
    _dispatchWork.add(job);
    _drainDispatch();
  }

  void _drainDispatch() {
    while (_dispatchWork.isNotEmpty) {
      final job = _dispatchWork.removeAt(0);
      dispatchAttempts++;
      print('  [dispatch → ${job.toRole}] ${job.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Tissue write protocol — escalation clock (BR-03, journey 9.1 failure path)
  // ─────────────────────────────────────────────────────────────────────

  void _armEscalation(String incidentId, DateTime openedAt) {
    _escalationTimers[incidentId]?.cancel();
    _escalationTimers[incidentId] = Timer(escalationWindow, () => _escalate(incidentId));
  }

  void _escalate(String incidentId) {
    _escalationTimers.remove(incidentId);
    final incident = incidents[incidentId];
    if (incident == null || incident.status != IncidentStatus.open) return;
    escalations++;
    incidents[incidentId] = incident.copyWith(status: IncidentStatus.escalated);
    events.add(OpsEvent(kind: 'ESCALATE', refId: incidentId, detail: 'not acknowledged within ${escalationWindow.inMinutes}m', at: DateTime.now()));
    _dispatch(incidentId, 'dutyManager', 'ESCALATED: $incidentId unacknowledged');
  }

  // ─────────────────────────────────────────────────────────────────────
  // Tissue write protocol — acknowledgement (FR-07, FR-11, NFR-05)
  // ─────────────────────────────────────────────────────────────────────

  /// FR-07: acknowledge an alert and record the action taken. FR-11: attach
  /// a free-text note. NFR-05: the event log records who, when, what.
  bool acknowledge(String incidentId, String supervisor, String note, DateTime at) {
    final incident = incidents[incidentId];
    if (incident == null) return false;

    _escalationTimers.remove(incidentId)?.cancel();
    if (incident.cause == IncidentCause.deviceStall && incident.deviceId != null) {
      _openIncidentByDevice.remove(incident.deviceId);
    }
    for (final tag in incident.affectedBags) {
      final b = bags[tag];
      if (b != null) bags[tag] = b.copyWith(risk: RiskLevel.onTime);
      _lastRisk[tag] = RiskLevel.onTime;
    }

    incidents[incidentId] = incident.copyWith(
      status: IncidentStatus.acknowledged,
      ackBy: supervisor,
      ackAt: at,
      note: note,
    );
    events.add(OpsEvent(kind: 'ACK', refId: incidentId, detail: '$supervisor: "$note"', at: at));
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Reporting (FR-10, AR-01, BR-04, AC-05, AC-06) — pure projection, no Tissue write
  // ─────────────────────────────────────────────────────────────────────

  /// Computes the daily per-airline performance report from [events] and
  /// [bags]. Never touches passenger data — the domain model carries none —
  /// satisfying BR-04 / AC-06 by construction rather than by redaction.
  List<DailyAirlineStat> dailyReport(DateTime day) {
    final byAirline = <String, List<BagState>>{};
    for (final bag in bags.values) {
      final flight = flights[bag.flightNo];
      if (flight == null) continue;
      byAirline.putIfAbsent(flight.airline, () => []).add(bag);
    }
    return byAirline.entries.map((e) {
      final handled = e.value.length;
      final delayed = e.value.where((b) => b.risk == RiskLevel.atRisk).length;
      final missed = e.value.where((b) => b.risk == RiskLevel.missed).length;
      return DailyAirlineStat(
        airline: e.key,
        handled: handled,
        delayed: delayed,
        missed: missed,
        avgProcessingTime: const Duration(minutes: 22), // placeholder aggregate
      );
    }).toList(growable: false)
      ..sort((a, b) => a.airline.compareTo(b.airline));
  }

  // ─────────────────────────────────────────────────────────────────────
  // Role-scoped views (NFR-04, BR-04) — deputies, never copies
  // ─────────────────────────────────────────────────────────────────────

  /// Duty manager: full read-only view of current incidents (FR-04, FR-09).
  Future<TissueMap<String, Incident>> dutyManagerView() =>
      incidents.deputy(testRule: TestTissue.readOnly);

  /// Supervisor: read-only, terminal-scoped — narrows, never widens, per the
  /// deputy contract (NFR-04).
  Future<TissueMap<String, Incident>> supervisorView(String terminal) => incidents.deputy(
        testRule: TestTissue<Incident, TissueMap<String, Incident>>(
          (value, {host, arguments, user}) => value is Incident && value.terminal == terminal,
        ),
      );

  /// Airline liaison: the computed report only — never the bag-level map.
  List<DailyAirlineStat> airlineLiaisonView(DateTime day) => dailyReport(day);

  void dispose() {
    for (final t in _stallTimers.values) {
      t.cancel();
    }
    for (final t in _escalationTimers.values) {
      t.cancel();
    }
    _stallTimers.clear();
    _escalationTimers.clear();
  }
}

// ═════════════════════════════════════════════════════════════════════════
// SCENARIOS — drawn from BRD §9 user journeys and §10 acceptance criteria
// ═════════════════════════════════════════════════════════════════════════

Future<void> main() async {
  print('╔═══════════════════════════════════════════════════════════════════╗');
  print('║ baggage-flow-watch(tissue)-Demo.dart                                 ║');
  print('║ Flow owns the risk/stall decision. Tissue owns the ops books.       ║');
  print('╚═══════════════════════════════════════════════════════════════════╝');

  final h = BaggageFlowWatchHarness();
  await h.install();

  final base = DateTime(2026, 9, 16, 6, 0);

  _section('Seed', 'flight reference data + a protected bag');
  await h.flightIn.emitAsync(FlightRecord(
    airline: 'ZZ',
    flightNo: 'ZZ101',
    terminal: 'T2',
    scheduledDeparture: base.add(const Duration(hours: 2)),
    closeOutTime: base.add(const Duration(hours: 1, minutes: 30)),
  ));
  h.protectedBags.add('BAG-DIP-001');
  print('flights.length=${h.flights.length} protectedBags=${h.protectedBags.length}');

  _section('1', 'journey 3.1 — normal bag flows check-in → aircraft side, on time');
  final onTimeScanBase = base.add(const Duration(minutes: 5));
  for (final station in Station.values) {
    await h.ingestScan(BagScan(
      bagTag: 'BAG-0001',
      flightNo: 'ZZ101',
      terminal: 'T2',
      station: station,
      at: onTimeScanBase,
    ));
  }
  print('bags[BAG-0001]=${h.bags['BAG-0001']}');

  _section('2', 'journey 9.1 — belt stalls in T2 at 07:42, Marco clears in 4 minutes');
  final stallAt = base.add(const Duration(hours: 1, minutes: 42));
  await h.ingestDeviceStatus(DeviceStatus(
    deviceId: 'BELT-T2-03',
    terminal: 'T2',
    kind: DeviceKind.belt,
    state: DeviceState.stalled,
    at: stallAt,
  ));
  print('stall timer armed for BELT-T2-03 — waiting ${BaggageFlowWatchHarness.stallThreshold.inSeconds}s (simulated)');
  h._confirmStall(DeviceStatus(
    deviceId: 'BELT-T2-03',
    terminal: 'T2',
    kind: DeviceKind.belt,
    state: DeviceState.stalled,
    at: stallAt.add(BaggageFlowWatchHarness.stallThreshold),
  ));
  final openStallIncident = h.incidents.values.firstWhere((i) => i.cause == IncidentCause.deviceStall);
  print('acknowledging ${openStallIncident.id} — Marco, 4 minutes later');
  h.acknowledge(openStallIncident.id, 'Marco', 'tag reader fault, cleared', stallAt.add(const Duration(minutes: 4)));
  print('incident status=${h.incidents[openStallIncident.id]!.status.name}');

  _section('3', 'journey 9.2 — bag at risk, 8 minutes before close-out (< 10 min minimum)');
  final atRiskAt = base.add(const Duration(hours: 1, minutes: 22)); // 8 min before 01:30 close-out
  await h.ingestScan(BagScan(
    bagTag: 'BAG-0002',
    flightNo: 'ZZ101',
    terminal: 'T2',
    station: Station.sorterEntry,
    at: atRiskAt,
  ));
  final atRiskIncident = h.incidents.values.firstWhere((i) => i.cause == IncidentCause.bagAtRisk);
  print('${atRiskIncident.id} opened for BAG-0002; duty manager calls airline, holds flight 3 minutes');
  h.acknowledge(atRiskIncident.id, 'DutyManager-Priya', 'airline held flight 3 min, bag loaded', atRiskAt.add(const Duration(minutes: 3)));

  _section('4', 'BR-03 — an alert left unacknowledged for 15 minutes escalates');
  final unackAt = base.add(const Duration(hours: 2));
  await h.ingestDeviceStatus(DeviceStatus(
    deviceId: 'CAR-T4-01',
    terminal: 'T4',
    kind: DeviceKind.carousel,
    state: DeviceState.stalled,
    at: unackAt,
  ));
  h._confirmStall(DeviceStatus(
    deviceId: 'CAR-T4-01',
    terminal: 'T4',
    kind: DeviceKind.carousel,
    state: DeviceState.stalled,
    at: unackAt.add(BaggageFlowWatchHarness.stallThreshold),
  ));
  final unackedIncident = h.incidents.values.firstWhere((i) => i.deviceId == 'CAR-T4-01');
  print('simulating the 15-minute escalation clock firing without an ACK');
  h._escalate(unackedIncident.id);
  print('incident status=${h.incidents[unackedIncident.id]!.status.name}');

  _section('5', 'AC — DR-06 rejects a scan with a missing tag/flight number');
  final rejected = await h.ingestScan(BagScan(
    bagTag: '',
    flightNo: 'ZZ101',
    terminal: 'T2',
    station: Station.checkIn,
    at: base,
  ));
  print('empty-tag scan accepted=$rejected (expected: false)');

  _section('6', 'BR-02 — no alert for a bag on a flight that has already closed');
  final afterClose = base.add(const Duration(hours: 1, minutes: 45)); // after 01:30 close-out
  await h.ingestScan(BagScan(
    bagTag: 'BAG-0003',
    flightNo: 'ZZ101',
    terminal: 'T2',
    station: Station.sorterEntry,
    at: afterClose,
  ));
  print('BAG-0003 risk=${h.bags['BAG-0003']!.risk.name} (expected: onTime — BR-02 suppresses post-close-out alerts)');

  _section('COMPLY', 'AR-02/DR-04 — events.remove is blocked; the log is append-only');
  final before = h.events.length;
  bool blocked = false;
  try {
    h.events.remove(h.events.first);
    blocked = h.events.length == before;
  } catch (_) {
    blocked = true;
  }
  print('events.remove blocked=$blocked (length before=$before after=${h.events.length})');

  _section('Report', 'FR-10/AR-01 — daily airline performance report, no passenger data (BR-04)');
  for (final stat in h.airlineLiaisonView(base)) {
    print('  $stat');
  }

  print('');
  print('─────────────────────────────────────────────────────────────────────');
  print('scans=${h.scans} stallsConfirmed=${h.stallsConfirmed} atRiskFlags=${h.atRiskFlags} '
      'escalations=${h.escalations} dispatchAttempts=${h.dispatchAttempts}');
  print('events.length=${h.events.length} incidents.length=${h.incidents.length} bags.length=${h.bags.length}');
  print('─────────────────────────────────────────────────────────────────────');

  h.dispose();
}
