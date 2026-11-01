// freight-rail-intermodal-test.dart
// Version: 0.1.0
// Supersedes: none
// Always written with the Demo. BRD group prints LEDGER lines.
// Expected values from BRD / parameter register, never from Demo output.
// Groups: BRD (moves ledger), public API, documented contract, constraint, provenance, boundary.

import 'dart:io';

import 'package:test/test.dart';

import 'freight-rail-intermodal-Demo.dart' as demo;

// ignore_for_file: file_names

String _demoPath() {
  if (File('freight-rail-intermodal-Demo.dart').existsSync()) {
    return 'freight-rail-intermodal-Demo.dart';
  }
  return 'example/freight-rail-intermodal-Demo.dart';
}

demo.RailTick _tick({
  String containerId = 'MSCU1',
  String trainId = 'T-1',
  String yard = 'Yard 1',
  String position = 'stack block',
  String asset = 'C1',
  int remainingMin = 30,
  String tag = 'normal',
  int assetStopSec = 0,
  bool trainDeparted = false,
  int affectedQty = 1,
}) =>
    demo.RailTick(
      containerId: containerId,
      trainId: trainId,
      yard: yard,
      position: position,
      asset: asset,
      remainingMin: remainingMin,
      tag: tag,
      assetStopSec: assetStopSec,
      trainDeparted: trainDeparted,
      affectedQty: affectedQty,
    );

void main() {
  group('BRD', () {
    test('FR-02 time remaining computed', () {
      final ok = demo.remainingMinutes(600, 592) == 8;
      print('LEDGER FR-02 ${ok ? "PASS" : "FAIL"} expected=8 actual=${demo.remainingMinutes(600, 592)} note=cutoff-now');
      expect(ok, isTrue);
    });

    test('FR-03 at-risk blocked on missing minimum connection time', () {
      // No BRD parameter value exists; journey §9.2 implies 10. Do not invent.
      print('LEDGER FR-03 BLOCKED expected=[To be confirmed from BRD] '
          'actual=placeholder-${demo.minConnectionMinPlaceholder} note=F-01');
      expect(true, isTrue);
    });

    test('FR-05 asset stop warn boundary', () {
      final d61 = demo.RailRiskInstruction.riskOf(_tick(assetStopSec: 61), <String>{});
      final d60 = demo.RailRiskInstruction.riskOf(_tick(assetStopSec: 60), <String>{});
      final ok = d61?.level == demo.Level.warn && d60?.level != demo.Level.warn;
      print('LEDGER FR-05 ${ok ? "PASS" : "FAIL"} expected=warn-at-61-none-at-60 '
          'actual=${d61?.level}/${d60?.level} note=P-01');
      expect(ok, isTrue);
    });

    test('FR-06 alert shows asset, containers, trains at risk', () {
      final s = demo.alertSummary(_tick(asset: 'C7', affectedQty: 28, trainId: 'T-771'));
      final ok = s.contains('C7') && s.contains('28') && s.contains('T-771');
      print('LEDGER FR-06 ${ok ? "PASS" : "FAIL"} expected=asset-containers-trains actual=$s note=FR-06');
      expect(ok, isTrue);
    });

    test('FR-07 ACK closes and restores', () async {
      demo.installBooks();
      demo.installCommands();
      demo.installIngress();
      demo.installGates();
      demo.installObserve();
      await demo.drive(_tick(containerId: 'MSCU1234567', remainingMin: 8, affectedQty: 2));
      final opened =
          demo.incidentMap.containsKey('MSCU1234567') && demo.reserve.value == 4;
      await demo.ack('MSCU1234567');
      final closed = !demo.incidentMap.containsKey('MSCU1234567') &&
          demo.reserve.value == 6 &&
          demo.atRiskGate.lastDecision == null;
      final ok = opened && closed;
      print('LEDGER FR-07 ${ok ? "PASS" : "FAIL"} expected=closed-restored actual=$opened/$closed note=ack');
      print('LEDGER AR-02 ${demo.events.isNotEmpty ? "PASS" : "FAIL"} expected=log actual=events note=append-only');
      expect(ok, isTrue);
      expect(demo.events.isNotEmpty, isTrue);
      demo.disposeObservers();
    });

    test('BR-01 hazardous protected', () {
      final d = demo.RailRiskInstruction.riskOf(
        _tick(remainingMin: 8, tag: 'hazardous'),
        <String>{'hazardous', 'temperature-controlled'},
      );
      final ok = d?.level == demo.Level.none && d?.reason == 'BR-01';
      print('LEDGER BR-01 ${ok ? "PASS" : "FAIL"} expected=none actual=${d?.level}/${d?.reason} note=BR-01');
      expect(ok, isTrue);
    });

    test('BR-02 departed train no alert', () {
      final d = demo.RailRiskInstruction.riskOf(
        _tick(remainingMin: 8, trainDeparted: true),
        <String>{},
      );
      final ok = d?.level == demo.Level.none && d?.reason == 'BR-02';
      print('LEDGER BR-02 ${ok ? "PASS" : "FAIL"} expected=none actual=${d?.level}/${d?.reason} note=BR-02');
      expect(ok, isTrue);
    });

    test('DR-06 missing container or train ID rejected', () {
      final ok = !demo.containerIdOk('') && !demo.trainIdOk('') &&
          demo.containerIdOk('MSCU1234567') && demo.trainIdOk('T-771');
      print('LEDGER DR-06 ${ok ? "PASS" : "FAIL"} expected=reject-empty actual=shapes note=ingress');
      expect(ok, isTrue);
    });

    test('remaining rows blocked or awaiting drive', () {
      final blocked = <String, String>{
        'FR-01': 'needs-real-feed-drive-Q01',
        'FR-04': 'class-H-needs-trial',
        'FR-08': 'F-06-grouping-key-TBD',
        'FR-09': 'needs-drive',
        'FR-10': 'needs-report-drive-Q02',
        'FR-11': 'needs-drive',
        'FR-12': 'F-09-format-TBD',
        'DR-01': 'needs-drive',
        'DR-02': 'needs-drive',
        'DR-03': 'needs-drive',
        'DR-04': 'retention-wave-B',
        'DR-05': 'retention-wave-B',
        'BR-03': 'Q-03-escalation-policy-open',
        'BR-04': 'F-02-sensitive-fields-TBD',
        'AR-01': 'needs-report-drive',
        'NFR-01': 'class-M-needs-run',
        'NFR-02': 'class-M-needs-run',
        'NFR-03': 'class-M-needs-run',
        'NFR-04': 'deferred-SSO',
        'NFR-05': 'needs-drive',
        'NFR-06': 'class-H-needs-trial',
        'NFR-07': 'class-J-acceptance-only',
        'NFR-08': 'class-M-needs-run',
      };
      blocked.forEach((id, note) {
        print('LEDGER $id BLOCKED expected=from-BRD actual=not-driven note=$note');
      });
      expect(blocked.length, 23);
    });
  });

  group('RailRiskInstruction.riskOf', () {
    test('asset stop 61 warns, 60 does not', () {
      final d61 = demo.RailRiskInstruction.riskOf(_tick(assetStopSec: 61), <String>{});
      final d60 = demo.RailRiskInstruction.riskOf(_tick(assetStopSec: 60), <String>{});
      expect(d61?.level, demo.Level.warn);
      expect(d60?.level, isNot(demo.Level.warn));
    });

    test('protected tag returns none', () {
      final d = demo.RailRiskInstruction.riskOf(
        _tick(remainingMin: 8, tag: 'temperature-controlled'),
        <String>{'hazardous', 'temperature-controlled'},
      );
      expect(d?.level, demo.Level.none);
    });

    test('departed train returns none', () {
      final d = demo.RailRiskInstruction.riskOf(
        _tick(remainingMin: 8, trainDeparted: true),
        <String>{},
      );
      expect(d?.level, demo.Level.none);
    });

    test('below placeholder at risk', () {
      final d = demo.RailRiskInstruction.riskOf(_tick(remainingMin: 8), <String>{});
      expect(d?.level, demo.Level.atRisk);
    });
  });

  group('WalkThrough §5.5', () {
    test('pulse path symbols exist: tickIn → instruction + MapValue → toHandle', () {
      // Documented contract: installGates wires tickIn → RailRiskInstruction + MapValue
      // → toHandle → atRiskCell / warnCell. The Demo exposes those symbols for the test.
      demo.installBooks();
      demo.installCommands();
      demo.installIngress();
      demo.installGates();
      expect(demo.handleAtRisk, isNotNull);
      expect(demo.handleWarn, isNotNull);
      expect(demo.atRiskCell, isNotNull);
      expect(demo.warnCell, isNotNull);
      expect(demo.atRiskGate.pass, demo.Level.atRisk);
      expect(demo.warnGate.pass, demo.Level.warn);
      demo.disposeObservers();
    });
  });

  group('constraint', () {
    test('no TestCell on Tissue constructors; no Tissue write inside the instruction', () {
      final src = File(_demoPath()).readAsStringSync();
      final tissueTestCell = RegExp(r'Tissue\w+\([^)]*testRule:\s*TestCell');
      expect(tissueTestCell.allMatches(src), isEmpty);

      final classStart = src.indexOf('final class RailRiskInstruction');
      final classEnd = src.indexOf('class _GateState');
      final body = (classStart >= 0 && classEnd > classStart)
          ? src.substring(classStart, classEnd)
          : '';
      expect(body, isNotEmpty);
      expect(body.contains('events.add'), isFalse);
      expect(body.contains('incidentMap'), isFalse);
      expect(body.contains('reserve.set'), isFalse);
      expect(body.contains('alertQ.addLast'), isFalse);
    });
  });

  group('provenance', () {
    test('header registers present and pulses carry source', () {
      final src = File(_demoPath()).readAsStringSync();
      expect(src.contains('Provenance: Pulse.source on every emit'), isTrue);
      expect(src.contains('Context: named'), isTrue);
      expect(src.contains('Deputy: events.unmodifiable for Safety & Compliance'), isTrue);
      expect(src.contains('source: cell ?? pulse.source'), isTrue);
    });
  });

  group('boundary', () {
    test('ingress TestCell and txApply recorded', () {
      final src = File(_demoPath()).readAsStringSync();
      expect(src.contains('containerIn TestCell yes'), isTrue);
      expect(src.contains('trainIn TestCell yes'), isTrue);
      expect(src.contains('transaction deferred'), isTrue);
      expect(src.contains('txApply present'), isTrue);
    });
  });
}
