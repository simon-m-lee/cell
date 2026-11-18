// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> baseJson() => Pulse<int>(42, type: 't').toJson();

  group('Pulse.fromJson — overrides', () {
    test('payload override', () {
      final decoded = Pulse.fromJson(baseJson(), payload: 7);
      expect(decoded.payload, 7);
    });

    test('type override', () {
      final decoded = Pulse.fromJson(baseJson(), type: 'overridden');
      expect(decoded.type, 'overridden');
    });

    test('source override wins over the resolver', () {
      final original = Cell.ingress<int>();
      final override = Cell.ingress<int>();
      final json = Pulse<int>(1, source: original.cell).toJson();
      final decoded = Pulse.fromJson(
        json,
        resolver: (id) => original.cell,
        source: override.cell,
      );
      expect(decoded.source, same(override.cell));
    });

    test('source: pulseNullSource strips the source', () {
      final source = Cell.ingress<int>();
      final json = Pulse<int>(1, source: source.cell).toJson();
      final decoded = Pulse.fromJson(
        json,
        resolver: (id) => source.cell,
        source: pulseNullSource,
      );
      expect(decoded.source, isNull);
    });

    test('step override', () {
      final decoded = Pulse.fromJson(baseJson(), step: 'overridden');
      expect(decoded.trace, contains('overridden'));
    });

    test('priority override', () {
      final decoded = Pulse.fromJson(baseJson(), priority: 99);
      expect(decoded.priority, 99);
    });

    test('context override', () {
      final context = PulseContext.fromEntries([
        Provenance.actor.entry('override-actor'),
      ]);
      final decoded = Pulse.fromJson(baseJson(), context: context);
      expect(decoded.context.actor, 'override-actor');
    });

    test('onComplete override carries the callback; toJson refuses', () {
      var fired = false;
      final decoded = Pulse.fromJson(
        baseJson(),
        onComplete: (pulse) => fired = true,
      );
      expect(
        () => decoded.toJson(),
        throwsA(
          isA<PulseNotSerializable>()
              .having((e) => e.field, 'field', 'onComplete'),
        ),
      );
      expect(fired, isFalse);
    });

    test('onError override carries the callback; toJson refuses', () {
      final decoded = Pulse.fromJson(
        baseJson(),
        onError: (pulse, error, {stackTrace}) {},
      );
      expect(
        () => decoded.toJson(),
        throwsA(
          isA<PulseNotSerializable>()
              .having((e) => e.field, 'field', 'onError'),
        ),
      );
    });

    test('onProgress override carries the callback; toJson refuses', () {
      final decoded = Pulse.fromJson(
        baseJson(),
        onProgress: (pulse, cell, {message}) {},
      );
      expect(
        () => decoded.toJson(),
        throwsA(
          isA<PulseNotSerializable>()
              .having((e) => e.field, 'field', 'onProgress'),
        ),
      );
    });

    test('policy override carries the policy; toJson refuses', () {
      final policy = PulseEphemeralPolicy(
        onEvent: (cell, {required policy}) => (hops: 0),
        onInvalidate: (pulse) => true,
      );
      final decoded = Pulse.fromJson(baseJson(), policy: policy);
      expect(decoded.policy, same(policy));
      expect(
        () => decoded.toJson(),
        throwsA(
          isA<PulseNotSerializable>().having((e) => e.field, 'field', 'policy'),
        ),
      );
    });

    test('payload: pulseNullPayload overrides to null', () {
      final decoded = Pulse.fromJson(baseJson(), payload: pulseNullPayload);
      expect(decoded.payload, isNull);
    });

    test('type: pulseNullType overrides to null', () {
      final decoded = Pulse.fromJson(baseJson(), type: pulseNullType);
      expect(decoded.type, isNull);
    });

    test('step: pulseNullStep overrides to null', () {
      final json = Pulse<int>(1, step: 'original').toJson();
      final decoded = Pulse.fromJson(json, step: pulseNullStep);
      expect(decoded.trace, isEmpty);
    });

    test('payload override on a collective JSON is rejected', () {
      final batchJson =
          Pulse.batch<int>([Pulse<int>(1), Pulse<int>(2)]).toJson();
      expect(
        () => Pulse.fromJson(batchJson, payload: 1),
        throwsA(isA<PulseDecodeError>()),
      );
    });

    test('multiple overrides all apply', () {
      final decoded = Pulse.fromJson(
        baseJson(),
        payload: 9,
        type: 'nine',
        priority: 8,
        step: 's',
      );
      expect(decoded.payload, 9);
      expect(decoded.type, 'nine');
      expect(decoded.priority, 8);
      expect(decoded.trace, contains('s'));
    });

    test('Pulse<int>.fromJson(json, payload: 42) types P as int', () {
      final Pulse<int> decoded = Pulse<int>.fromJson(
        Pulse<int>(1).toJson(),
        payload: 42,
      );
      expect(decoded.payload, 42);
    });

    test('Pulse<dynamic>.fromJson(json) decodes with P as dynamic', () {
      final Pulse<dynamic> decoded = Pulse<dynamic>.fromJson(
        Pulse<int>(1).toJson(),
      );
      expect(decoded.payload, 1);
    });

    test('an override preserves the parent chain', () {
      final root = Pulse<int>(1, step: 'root');
      final leaf = root.evolve(pulse: Pulse<int>(2, step: 'leaf'));
      final decoded = Pulse.fromJson(leaf.toJson(), priority: 70);
      expect(decoded.trace, ['root', 'leaf']);
      expect(decoded.root.payload, 1);
      expect(decoded.priority, 70);
    });
  });
}
