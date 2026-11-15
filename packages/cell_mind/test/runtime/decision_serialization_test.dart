// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  group('Decision serialization', () {
    Decision sampleDecision(Verdict verdict) => Decision(
          id: 'd-1',
          at: DateTime.utc(2026, 11, 15, 12),
          context: ctxWithVersion('1.2.3'),
          contextVersion: '1.2.3',
          verdict: verdict,
          pulse: governedPulse(payload: 42, domains: 'finance'),
          command: trivialCommand(),
          policyVersion: '1.0.0',
          evaluationTime: Duration(microseconds: 1200),
        );

    test('Accept verdict round-trips exactly', () {
      final map = sampleDecision(const Accept({'rule': 'domain'})).toMap();
      final restored = Decision.fromMap(map);
      expect(restored.id, 'd-1');
      expect(restored.at, DateTime.utc(2026, 11, 15, 12));
      expect(restored.contextVersion, '1.2.3');
      expect(restored.verdict, isA<Accept>());
      expect((restored.verdict as Accept).annotations, {'rule': 'domain'});
      expect(restored.policyVersion, '1.0.0');
      expect(restored.evaluationTime, Duration(microseconds: 1200));
    });

    test('Reject verdict round-trips with its reason', () {
      final map = sampleDecision(const Reject('policy-rejected')).toMap();
      final restored = Decision.fromMap(map);
      expect(restored.verdict, isA<Reject>());
      expect((restored.verdict as Reject).reason, 'policy-rejected');
    });

    test('Defer verdict round-trips with its resolver name', () {
      final map = sampleDecision(const Defer('approval')).toMap();
      final restored = Decision.fromMap(map);
      expect(restored.verdict, isA<Defer>());
      expect((restored.verdict as Defer).resolver, 'approval');
    });

    test('pulse audit shape is preserved in the map', () {
      final map = sampleDecision(const Accept()).toMap();
      final pulseMap = map['pulse'] as Map<String, dynamic>;
      expect(pulseMap['payload'], '42');
      expect(pulseMap['domains'], 'finance');
      expect(pulseMap['actor'], 'test-actor');
      expect(pulseMap['traceId'], isNotEmpty);
    });

    test('command audit shape is preserved in the map', () {
      final map = sampleDecision(const Accept()).toMap();
      final commandMap = map['command'] as Map<String, dynamic>;
      expect(commandMap['function'], isNotEmpty);
      expect(commandMap['positional'], isNull);
      expect(commandMap['compensation'], isNull);
    });

    test('live objects are not reconstructible (documented lossiness)', () {
      final map = sampleDecision(const Accept()).toMap();
      final restored = Decision.fromMap(map);
      expect(restored.context, same(Context.system));
      expect(restored.pulse, isNull);
      expect(restored.command, isNull);
    });

    test('null evaluation time round-trips as null', () {
      final decision = Decision(
        id: 'x',
        at: DateTime.utc(2026),
        context: Context.system,
        contextVersion: '0.0.0',
        verdict: const Accept(),
      );
      final restored = Decision.fromMap(decision.toMap());
      expect(restored.evaluationTime, isNull);
      expect(restored.policyVersion, isNull);
    });

    test('toString is compact and identifies the verdict', () {
      final decision = Decision(
        id: 'd-9',
        at: DateTime.utc(2026),
        context: Context.system,
        contextVersion: '1.0.0',
        verdict: const Reject('policy-rejected'),
      );
      expect(decision.toString(), contains('d-9'));
      expect(decision.toString(), contains('Reject'));
      expect(decision.toString(), contains('1.0.0'));
    });
  });
}
