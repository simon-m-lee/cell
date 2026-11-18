// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  group('pulse codec in the replay engine', () {
    test('record, encode, decode, replay produces the same state', () async {
      final source = Cell.ingress<int>();
      final live = <int>[];
      final liveSub = Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) => live.add(pulse.payload as int),
      );

      final recorded = <int>[];
      final recordSub = Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) => recorded.add(pulse.payload as int),
      );
      source.emit(1);
      source.emit(2);
      source.emit(3);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      liveSub.stop();
      recordSub.stop();
      expect(recorded, [1, 2, 3]);

      // Encode every recorded payload and decode it back through the
      // codec — the integration contract is payload/type round-tripping.
      final decodedJson = <Map<String, dynamic>>[
        for (final value in recorded) Pulse<int>(value, type: 'tick').toJson(),
      ];

      // Replay: feed the decoded pulses into a fresh ingress and
      // compare the committed state.
      final replaySource = Cell.ingress<int>();
      final replayed = <int>[];
      final replaySub = Cell.observe(
        source: replaySource.cell,
        effect: (Pulse pulse) => replayed.add(pulse.payload as int),
      );
      for (final json in decodedJson) {
        final decoded = Pulse.fromJson(json);
        replaySource.emit(decoded.payload as int);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      replaySub.stop();

      expect(live, [1, 2, 3]);
      expect(replayed, live);
    });

    test('encode a pulse with a policy throws PulseNotSerializable', () {
      final pulse = Pulse.governed(
        payload: 1,
        policy: PulseEphemeralPolicy(
          onEvent: (cell, {required policy}) => (hops: 0),
          onInvalidate: (pulse) => true,
        ),
      );
      expect(
        () => pulse.toJson(),
        throwsA(
          isA<PulseNotSerializable>().having((e) => e.field, 'field', 'policy'),
        ),
      );
    });

    test('decode with a resolver yields the registered cell', () {
      final registered = Cell.ingress<int>();
      final json = Pulse<int>(1, source: registered.cell).toJson();
      final decoded = Pulse.fromJson(
        json,
        resolver: (id) => id == registered.cell.id ? registered.cell : null,
      );
      expect(decoded.source, same(registered.cell));
    });

    test('decode with an unresolved source continues with source == null', () {
      final missing = Cell.ingress<int>();
      final json = Pulse<int>(1, source: missing.cell).toJson();
      final decoded = Pulse.fromJson(json, resolver: (_) => null);
      expect(decoded.source, isNull);
    });

    test('an overridden payload feeds the replay path', () async {
      final source = Cell.ingress<int>();
      final observed = <int>[];
      final sub = Cell.observe(
        source: source.cell,
        effect: (Pulse pulse) => observed.add(pulse.payload as int),
      );
      final wire = Pulse<int>(1, type: 'tick').toJson();
      final overridden = Pulse.fromJson(wire, payload: 42);
      source.emit(overridden.payload as int);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      sub.stop();
      expect(observed, [42]);
    });
  });
}
