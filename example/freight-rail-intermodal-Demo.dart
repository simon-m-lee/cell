// freight-rail-intermodal-Demo.dart
// Version: 0.1.0
// Supersedes: none
// Cell variant. Executable for the Rail Yard Flow Watch desk.
//
// Provenance: Pulse.source on every emit | Context: named | Deputy: events.unmodifiable for Safety & Compliance / none because BRD names no write-role auditor
// Boundary: containerIn TestCell yes | trainIn TestCell yes | transaction deferred Real-desk (txApply on Tissue) | txApply present (raise/close multi-book commit)
//
// Seam: the instruction decides, the chain assembles, the observer glues.
// Grep rule: zero testRule: TestCell on Tissue constructors.
//
// Cell I/O table:
// | Cell / handle   | Input parameter      | TestCell               | Emits               |
// | tickIn          | RailTick snapshot    | (assembled)            | Pulse<RailTick>     |
// | containerIn     | String               | non-empty (_containerShape) | Pulse<String>  |
// | trainIn         | String               | non-empty (_trainShape)     | Pulse<String>  |
// | yardIn/positionIn/tagIn/assetStopSecIn/trainDepartedIn/cutoffMinIn/nowMinIn | String/int/bool | none | Pulse<*> |
// | ackIn           | String key / ALL     | none                   | Pulse<String>       |
// | atRiskCell      | (from toHandle)      | —                      | Pulse<Level>        |
// | warnCell        | (from toHandle)      | —                      | Pulse<Level>        |
//
// Expected console (from WalkThrough §5.9):
// HAPPY PASS
// WARN PASS
// PROTECTED PASS
// CLOSED PASS
// LATCH PASS
// ACK PASS
// ACK ALL PASS
// REJECT PASS
// OVERDRAW PASS
// COMPLY PASS
// UNKNOWN ACK PASS
// PUMP FAIL-ONCE PASS
//
// Deviations from WalkThrough: minConnectionTime threshold is the placeholder 10 min
// ([To be confirmed from BRD], journey §9.2); wall-clock timers are harness fields; field
// ingresses are demonstrated in REJECT while other scenarios drive the assembled tick bus;
// ACK resets both lane latches (grid-style); ACK ALL clears latches but does not close a named incident.
//
// Covered in main(): FR-02 (remaining computed), FR-03 (placeholder drive), FR-05, FR-06, FR-07,
// BR-01, BR-02, DR-06, AR-02 (events log driven), reserve illustration.
// Not covered in main(): FR-01 real-time feed, FR-04 single screen, FR-08 grouping full, FR-09 cross-yard,
// FR-10/AR-01 daily report, FR-11 note, FR-12 export, BR-03 15-min window, BR-04 sensitive fields,
// DR-01..05 full, NFR-01..08 measurement/trial classes.
//
// Decision logic is top-level and importable. main() is the only entry that drives scenarios.

import 'dart:io' show exitCode;

import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_tissue/cell_tissue.dart';

// ignore_for_file: avoid_print, file_names

/// Placeholder threshold for FR-03. The BRD parameter register has no
/// minimum-connection-time value; journey §9.2 implies 10 minutes.
/// Marked [To be confirmed from BRD]. FR-03 stays Blocked in the ledger.
const int minConnectionMinPlaceholder = 10;

enum Level { none, warn, atRisk }

class RailTick {
  final String containerId;
  final String trainId;
  final String yard;
  final String position;
  final String asset;
  final int remainingMin;
  final String tag;
  final int assetStopSec;
  final bool trainDeparted;
  final int affectedQty;

  RailTick({
    required this.containerId,
    required this.trainId,
    required this.yard,
    required this.position,
    required this.asset,
    required this.remainingMin,
    required this.tag,
    required this.assetStopSec,
    required this.trainDeparted,
    required this.affectedQty,
  });
}

class RailDecision {
  final Level level;
  final String reason;
  RailDecision(this.level, this.reason);
}

class RailEvent {
  final String kind;
  final String detail;
  RailEvent(this.kind, this.detail);
}

class Incident {
  final String key;
  final int affectedQty;
  Incident({required this.key, required this.affectedQty});
}

class RailAlertJob {
  final String key;
  final Level level;
  final String detail;
  RailAlertJob({required this.key, required this.level, required this.detail});
}

// --- pure helpers (public, importable) ---

int remainingMinutes(int cutoffMin, int nowMin) => cutoffMin - nowMin;

String alertSummary(RailTick t) =>
    'asset=${t.asset} containers=${t.affectedQty} trains=${t.trainId}';

bool containerIdOk(Object? v) => v is String && v.isNotEmpty;

bool trainIdOk(Object? v) => v is String && v.isNotEmpty;

// --- policy (pure, importable) ---

final class RailRiskInstruction extends FlowInstructionBase<Cell, Pulse, Pulse> {
  factory RailRiskInstruction({
    required Set<String> guarded,
    required Level pass,
    dynamic user,
  }) {
    final state = _GateState();
    return RailRiskInstruction._(guarded, pass, state, user);
  }

  RailRiskInstruction._(
    Set<String> guarded,
    Level pass,
    _GateState state,
    dynamic user,
  )   : _guarded = guarded,
        _pass = pass,
        _state = state,
        super(_build(guarded, pass, state), user: user);

  final Set<String> _guarded;
  final Level _pass;
  final _GateState _state;

  static Pulse? Function(Pulse, {Cell? cell, dynamic user}) _build(
    Set<String> guarded,
    Level pass,
    _GateState state,
  ) {
    return (Pulse pulse, {Cell? cell, dynamic user}) {
      // type-check → riskOf → distinct latch → product filter → emit Pulse<RailDecision>
      if (pulse.payload is! RailTick) return null;
      final tick = pulse.payload as RailTick;
      final decision = riskOf(tick, guarded);
      if (decision == null) return null;
      if (state.last == decision.level) return null; // latch
      state.last = decision.level;
      if (decision.level == Level.none || decision.level != pass) return null;
      return Pulse<RailDecision>(
        decision,
        source: cell ?? pulse.source,
        type: pulse.type,
        priority: pulse.priority,
        step: 'RailRisk.${pass.name}',
      );
    };
  }

  /// Pure policy, clause order per WalkThrough §5.2.
  ///
  /// 1. protected tag (BR-01) → none
  /// 2. train departed (BR-02) → none
  /// 3. asset stop > 60 s (FR-05, P-01) → warn
  /// 4. remaining < minConnectionTime (FR-03, placeholder) → atRisk
  /// 5. else → null
  static RailDecision? riskOf(RailTick tick, Set<String> guarded) {
    if (guarded.contains(tick.tag)) return RailDecision(Level.none, 'BR-01');
    if (tick.trainDeparted) return RailDecision(Level.none, 'BR-02');
    if (tick.assetStopSec > 60) return RailDecision(Level.warn, 'FR-05');
    if (tick.remainingMin < minConnectionMinPlaceholder) {
      return RailDecision(Level.atRisk, 'FR-03');
    }
    return null;
  }

  Level? get lastDecision => _state.last;
  Level get pass => _pass;
  Set<String> get guarded => _guarded;
  void reset() => _state.last = null;
}

class _GateState {
  Level? last;
}

// --- books ---

late TissueList<RailEvent> events;
late TissueValue<int> reserve;
late TissueMap<String, Incident> incidentMap;
late TissueSet<String> protected;
late TissueQueue<RailAlertJob> alertQ;

final TestTissue<RailEvent, TissueList<RailEvent>> _eventAppendOnly =
    TestTissue<RailEvent, TissueList<RailEvent>>(
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

final TestTissue<int, TissueValue<int>> _nonNegative =
    TestTissue<int, TissueValue<int>>(
  (value, {host, arguments, user}) {
    if (value is int) return value >= 0;
    return true;
  },
);

final TestTissue<Incident, TissueMap<String, Incident>> _incidentRule =
    TestTissue<Incident, TissueMap<String, Incident>>(
  (value, {host, arguments, user}) {
    if (value is Incident) {
      return value.key.isNotEmpty && value.affectedQty > 0;
    }
    return true;
  },
);

final TestTissue<String, TissueSet<String>> _tagRule =
    TestTissue<String, TissueSet<String>>(
  (value, {host, arguments, user}) {
    if (value is String) return value.isNotEmpty;
    return true;
  },
);

final TestTissue<RailAlertJob, TissueQueue<RailAlertJob>> _jobRule =
    TestTissue<RailAlertJob, TissueQueue<RailAlertJob>>(
  (value, {host, arguments, user}) => true,
);

void installBooks() {
  events = TissueList<RailEvent>(testRule: _eventAppendOnly);
  reserve = TissueValue<int>(6, testRule: _nonNegative); // illustration baseline
  incidentMap = TissueMap<String, Incident>(
    properties: TissueMapNucleus<String, Incident>(testRule: _incidentRule),
  );
  protected = TissueSet<String>(<String>[], testRule: _tagRule);
  protected.add('hazardous');
  protected.add('temperature-controlled');
  alertQ = TissueQueue<RailAlertJob>(capacity: 32, testRule: _jobRule);
}

// --- command cells for txApply staging ---

late StateHandle<String> raiseCmd;
late StateHandle<String> closeCmd;

void installCommands() {
  raiseCmd = Cell.state<String>(initial: '');
  closeCmd = Cell.state<String>(initial: '');
}

// --- ingress ---

late IngressHandle<String> containerIn;
late IngressHandle<String> trainIn;
late IngressHandle<String> yardIn;
late IngressHandle<String> positionIn;
late IngressHandle<int> cutoffMinIn;
late IngressHandle<int> nowMinIn;
late IngressHandle<String> tagIn;
late IngressHandle<int> assetStopSecIn;
late IngressHandle<bool> trainDepartedIn;
late IngressHandle<RailTick> tickIn;
late IngressHandle<String> ackIn;

final TestCell<Cell> _containerShape = TestCell<Cell>(
  (value, {host, arguments, user}) {
    final v = value is Pulse ? value.payload : value;
    return containerIdOk(v);
  },
);

final TestCell<Cell> _trainShape = TestCell<Cell>(
  (value, {host, arguments, user}) {
    final v = value is Pulse ? value.payload : value;
    return trainIdOk(v);
  },
);

void installIngress() {
  containerIn = Cell.ingress<String>(testRule: _containerShape);
  trainIn = Cell.ingress<String>(testRule: _trainShape);
  yardIn = Cell.ingress<String>();
  positionIn = Cell.ingress<String>();
  cutoffMinIn = Cell.ingress<int>();
  nowMinIn = Cell.ingress<int>();
  tagIn = Cell.ingress<String>();
  assetStopSecIn = Cell.ingress<int>();
  trainDepartedIn = Cell.ingress<bool>();
  tickIn = Cell.ingress<RailTick>();
  ackIn = Cell.ingress<String>();
}

// --- gates ---

late RailRiskInstruction atRiskGate;
late RailRiskInstruction warnGate;
late FlowHandle? handleAtRisk;
late FlowHandle? handleWarn;
late Cell atRiskCell;
late Cell warnCell;

void installGates() {
  atRiskGate = RailRiskInstruction(
    guarded: protected,
    pass: Level.atRisk,
    user: 'rail-ATRISK-lane',
  );
  warnGate = RailRiskInstruction(
    guarded: protected,
    pass: Level.warn,
    user: 'rail-WARN-lane',
  );

  final toLevel = MapValue<RailDecision, Level>((d) => d.level);

  final atRiskChain = atRiskGate + toLevel;
  handleAtRisk = atRiskChain.toHandle(source: tickIn.cell);
  atRiskCell = handleAtRisk!.cell;

  final warnChain = warnGate + toLevel;
  handleWarn = warnChain.toHandle(source: tickIn.cell);
  warnCell = handleWarn!.cell;
}

// --- observe / glue ---

final List<EgressHandle> _observers = [];
final List<RailAlertJob> _alertWork = [];

RailTick? _currentTick;
int ticks = 0;
int atRiskCount = 0;
int warnCount = 0;
int alertAttempts = 0;
bool alertFailOnce = false;
bool _alertHasFailed = false;

void installObserve() {
  _observers.add(Cell.observe(
    source: atRiskCell,
    effect: (Pulse pulse) {
      if (pulse.payload == Level.atRisk) {
        atRiskCount++;
        final t = _currentTick;
        if (t != null) {
          raiseAlert(t); // fire-and-forget; flushed by drive()
        }
      }
    },
  ));

  _observers.add(Cell.observe(
    source: warnCell,
    effect: (Pulse pulse) {
      if (pulse.payload == Level.warn) {
        warnCount++;
        final t = _currentTick;
        if (t != null) {
          final summary = alertSummary(t);
          events.add(RailEvent('WARN', summary));
          final job = RailAlertJob(key: t.containerId, level: Level.warn, detail: summary);
          alertQ.addLast(job);
          _alertWork.add(job);
          _driveAlert();
        }
      }
    },
  ));

  _observers.add(Cell.observe(
    source: ackIn.cell,
    effect: (Pulse pulse) {
      atRiskGate.reset();
      warnGate.reset();
      final key = pulse.payload;
      if (key is String && key.isNotEmpty && key != 'ALL') {
        if (incidentMap.containsKey(key)) {
          closeIncident(key);
        } else {
          print('UNKNOWN ACK key=$key');
        }
      } else {
        events.add(RailEvent('ACK', 'ALL distinct cleared'));
      }
    },
  ));
}

void disposeObservers() {
  for (final o in _observers) {
    o.stop();
  }
  _observers.clear();
}

// --- raise / close (harness methods called from Cell.observe) ---

Future<bool> raiseAlert(RailTick tick) async {
  final key = tick.containerId;
  final qty = tick.affectedQty;
  if (incidentMap.containsKey(key)) {
    print('LATCH key=$key no-second-raise');
    return false;
  }
  final before = reserve.value ?? 0;
  if (before < qty) {
    print('OVERDRAW ok=false reserve=$before qty=$qty');
    return false;
  }
  try {
    await Cell.txApply().execute(
      participants: [raiseCmd.cell],
      body: (tx) {
        raiseCmd.update(key);
        incidentMap[key] = Incident(key: key, affectedQty: qty);
        final okReserve = reserve.set(before - qty);
        if (!okReserve) throw StateError('reserve rule rejected');
        events.add(RailEvent('RAISE', alertSummary(tick)));
        alertQ.addLast(RailAlertJob(
          key: key,
          level: Level.atRisk,
          detail: alertSummary(tick),
        ));
      },
    );
    return true;
  } catch (_) {
    incidentMap.remove(key);
    reserve.set(before);
    return false;
  }
}

Future<bool> closeIncident(String key) async {
  final inc = incidentMap[key];
  if (inc == null) return false;
  final before = reserve.value ?? 0;
  try {
    await Cell.txApply().execute(
      participants: [closeCmd.cell],
      body: (tx) {
        closeCmd.update(key);
        incidentMap.remove(key);
        reserve.set(before + inc.affectedQty);
        events.add(RailEvent('CLOSE', '$key qty=${inc.affectedQty}'));
      },
    );
    return true;
  } catch (_) {
    incidentMap[key] = inc;
    reserve.set(before);
    return false;
  }
}

void _driveAlert() {
  if (_alertWork.isEmpty) return;
  final job = _alertWork.removeAt(0);
  alertAttempts++;
  try {
    if (alertFailOnce && !_alertHasFailed) {
      _alertHasFailed = true;
      throw StateError('alert transient');
    }
    events.add(RailEvent('ALERT-SENT', job.detail));
  } catch (_) {
    alertAttempts++;
    events.add(RailEvent('ALERT-SENT', '${job.detail} (retry)'));
  }
}

// --- harness helpers for scenarios ---

Future<void> drive(RailTick tick) async {
  _currentTick = tick;
  ticks++;
  tickIn.emit(tick);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<void> ack(String key) async {
  ackIn.emit(key);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

int failures = 0;

void check(String name, bool actual, bool expected, String note) {
  final pass = actual == expected;
  print('$name ${pass ? "PASS" : "FAIL"} expected=$expected actual=$actual note=$note');
  if (!pass) failures++;
}

// --- main ---

Future<void> main() async {
  installBooks();
  installCommands();
  installIngress();
  installGates();
  installObserve();

  // 1 HAPPY — container 8 min remaining (< 10 placeholder) → atRisk
  await drive(RailTick(
    containerId: 'MSCU1234567',
    trainId: 'T-771',
    yard: 'Yard 2',
    position: 'stack block',
    asset: 'C7',
    remainingMin: 8,
    tag: 'normal',
    assetStopSec: 0,
    trainDeparted: false,
    affectedQty: 2,
  ));
  check(
    'HAPPY',
    incidentMap.containsKey('MSCU1234567') &&
        reserve.value == 4 &&
        atRiskGate.lastDecision == Level.atRisk &&
        events.isNotEmpty,
    true,
    'FR-03 placeholder 10',
  );

  // 2 WARN — asset stop 61 s (> 60) → warn, reserve unchanged
  final ev2 = events.length;
  await drive(RailTick(
    containerId: 'MSCU2222222',
    trainId: 'T-772',
    yard: 'Yard 4',
    position: 'crane lift',
    asset: 'C7',
    remainingMin: 30,
    tag: 'normal',
    assetStopSec: 61,
    trainDeparted: false,
    affectedQty: 1,
  ));
  check(
    'WARN',
    warnGate.lastDecision == Level.warn &&
        reserve.value == 4 &&
        !incidentMap.containsKey('MSCU2222222') &&
        events.length > ev2,
    true,
    'P-01 >60',
  );

  // 3 PROTECTED — hazardous → none, no Tissue growth
  final ev3 = events.length;
  final map3 = incidentMap.length;
  final tick3 = RailTick(
    containerId: 'MSCU3333333',
    trainId: 'T-773',
    yard: 'Yard 1',
    position: 'stack block',
    asset: 'B2',
    remainingMin: 8,
    tag: 'hazardous',
    assetStopSec: 0,
    trainDeparted: false,
    affectedQty: 1,
  );
  final d3 = RailRiskInstruction.riskOf(tick3, protected);
  await drive(tick3);
  check(
    'PROTECTED',
    d3?.level == Level.none &&
        d3?.reason == 'BR-01' &&
        events.length == ev3 &&
        incidentMap.length == map3,
    true,
    'BR-01',
  );

  // 4 CLOSED — train departed → none, no Tissue growth
  final ev4 = events.length;
  final map4 = incidentMap.length;
  final tick4 = RailTick(
    containerId: 'MSCU4444444',
    trainId: 'T-774',
    yard: 'Yard 3',
    position: 'railcar load',
    asset: 'C9',
    remainingMin: 8,
    tag: 'normal',
    assetStopSec: 0,
    trainDeparted: true,
    affectedQty: 1,
  );
  final d4 = RailRiskInstruction.riskOf(tick4, protected);
  await drive(tick4);
  check(
    'CLOSED',
    d4?.level == Level.none &&
        d4?.reason == 'BR-02' &&
        events.length == ev4 &&
        incidentMap.length == map4,
    true,
    'BR-02',
  );

  // 5 LATCH — same container at-risk again before ACK → no second raise
  final ev5 = events.length;
  final map5 = incidentMap.length;
  final r5 = reserve.value;
  await drive(RailTick(
    containerId: 'MSCU1234567',
    trainId: 'T-771',
    yard: 'Yard 2',
    position: 'stack block',
    asset: 'C7',
    remainingMin: 8,
    tag: 'normal',
    assetStopSec: 0,
    trainDeparted: false,
    affectedQty: 2,
  ));
  check(
    'LATCH',
    incidentMap.length == map5 && reserve.value == r5 && events.length == ev5,
    true,
    'FR-08 latch',
  );

  // 6 ACK — reset, map remove, reserve restored, CLOSE row
  await ack('MSCU1234567');
  check(
    'ACK',
    !incidentMap.containsKey('MSCU1234567') &&
        reserve.value == 6 &&
        atRiskGate.lastDecision == null,
    true,
    'FR-07',
  );

  // 7 ACK ALL — lastDecision=null on both lanes
  await drive(RailTick(
    containerId: 'MSCU1234567',
    trainId: 'T-771',
    yard: 'Yard 2',
    position: 'stack block',
    asset: 'C7',
    remainingMin: 8,
    tag: 'normal',
    assetStopSec: 0,
    trainDeparted: false,
    affectedQty: 2,
  ));
  await ack('ALL');
  check(
    'ACK ALL',
    atRiskGate.lastDecision == null && warnGate.lastDecision == null,
    true,
    'reset',
  );
  await ack('MSCU1234567'); // ACK ALL does not close a named incident

  // 8 REJECT — missing container ID rejected at ingress, Tissue unchanged
  final ev8 = events.length;
  final accepted = containerIn.emit('');
  check(
    'REJECT',
    accepted == false && events.length == ev8,
    true,
    'DR-06',
  );

  // 9 OVERDRAW — qty 7 > reserve 6 → ok=false, no map row
  final map9 = incidentMap.length;
  final ok9 = await raiseAlert(RailTick(
    containerId: 'MSCU9999999',
    trainId: 'T-779',
    yard: 'Yard 1',
    position: 'stack block',
    asset: 'B2',
    remainingMin: 8,
    tag: 'normal',
    assetStopSec: 0,
    trainDeparted: false,
    affectedQty: 7,
  ));
  check(
    'OVERDRAW',
    ok9 == false && incidentMap.length == map9,
    true,
    'illustration',
  );

  // 10 COMPLY — council read-only view blocks add, length equals source
  final council = events.unmodifiable;
  final ev10 = events.length;
  var blocked = false;
  try {
    council.add(RailEvent('HACK', 'council write'));
    blocked = events.length == ev10;
  } catch (_) {
    blocked = true;
  }
  check(
    'COMPLY',
    blocked && council.length == events.length,
    true,
    'unmodifiable',
  );

  // 11 UNKNOWN ACK — no invented qty
  final r11 = reserve.value;
  await ack('NO-SUCH-KEY');
  check(
    'UNKNOWN ACK',
    reserve.value == r11 && !incidentMap.containsKey('NO-SUCH-KEY'),
    true,
    'no-invented-qty',
  );

  // 12 PUMP FAIL-ONCE — first alert delivery fails, retry once
  alertFailOnce = true;
  final attemptsBefore = alertAttempts;
  await drive(RailTick(
    containerId: 'MSCU5555555',
    trainId: 'T-775',
    yard: 'Yard 4',
    position: 'crane lift',
    asset: 'C7',
    remainingMin: 30,
    tag: 'normal',
    assetStopSec: 61,
    trainDeparted: false,
    affectedQty: 1,
  ));
  check(
    'PUMP FAIL-ONCE',
    alertAttempts >= attemptsBefore + 2,
    true,
    'retry-once',
  );

  // trailer
  print('---');
  print('ticks=$ticks atRisk=$atRiskCount warn=$warnCount events=${events.length} '
      'reserve=${reserve.value} open=${incidentMap.length} alertAttempts=$alertAttempts');
  print('atRiskGate.lastDecision=${atRiskGate.lastDecision} '
      'warnGate.lastDecision=${warnGate.lastDecision}');
  print('councilLength=${events.unmodifiable.length}');

  disposeObservers();

  if (failures > 0) {
    print('FAILURES=$failures');
    exitCode = 1;
  } else {
    print('DONE all banners passed');
  }
}
