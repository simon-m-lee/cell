// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:test/test.dart';

void main() {
  group('Pulse.fromJson — the factory without overrides', () {
    test('symmetry: fromJson(toJson(p)) reproduces p at codec precision', () {
      final context = PulseContext.fromEntries([
        Provenance.actor.entry('agent'),
        Provenance.confidence.entry(0.9),
      ]);
      final source = Cell.ingress<int>();
      final pulse = Pulse.governed(
        payload: {
          'a': 1,
          'b': [true, null]
        },
        type: 'record',
        source: source.cell,
        priority: 30,
        context: context,
        step: 'signed',
      );
      final decoded = Pulse.fromJson(
        pulse.toJson(),
        resolver: (id) => id == source.cell.id ? source.cell : null,
      );
      expect(decoded.payload, pulse.payload);
      expect(decoded.type, 'record');
      expect(decoded.priority, 30);
      expect(decoded.context.actor, 'agent');
      expect(decoded.source, same(source.cell));
      expect(decoded.trace, pulse.trace);
    });

    test('timestamps round-trip at millisecond precision (UTC)', () {
      final pulse = Pulse<int>(1);
      final decoded = Pulse.fromJson(pulse.toJson());
      expect(
        decoded.timestamp.toUtc().millisecondsSinceEpoch,
        pulse.timestamp.toUtc().millisecondsSinceEpoch,
      );
      expect(decoded.timestamp.toUtc().microsecond, 0);
    });

    test('asymmetry: a non-canonical input re-encodes canonically', () {
      final handWritten = <String, dynamic>{
        '__pulse__': '1.0.0',
        'payload': 1,
        'type': 't',
        'timestamp': '2026-11-17T09:14:32.000Z',
        'source': null,
        'priority': 20,
        'context': PulseContextCodec.toJson(PulseContext.system),
        'step': null,
        'user': null,
        'parent': null,
        'isComposite': false,
        'children': null,
      };
      final decoded = Pulse.fromJson(handWritten);
      final reencoded = canonicalJsonEncode(decoded.toJson());
      expect(
        reencoded,
        canonicalJsonEncode(
          Pulse.fromJson(decoded.toJson()).toJson(),
        ),
      );
      // The wire map is canonical: every field present, keys sorted by
      // the canonical encoder.
      expect(reencoded, isNot(contains('z')));
    });

    test('a source with no resolver decodes as null', () {
      final source = Cell.ingress<int>();
      final pulse = Pulse<int>(1, source: source.cell);
      final decoded = Pulse.fromJson(pulse.toJson());
      expect(decoded.source, isNull);
    });

    test('a source with a resolver decodes as the resolved cell', () {
      final source = Cell.ingress<int>();
      final pulse = Pulse<int>(1, source: source.cell);
      final decoded = Pulse.fromJson(
        pulse.toJson(),
        resolver: (id) => id == source.cell.id ? source.cell : null,
      );
      expect(decoded.source, same(source.cell));
    });

    test('a resolver returning null for an unknown id decodes as null', () {
      final source = Cell.ingress<int>();
      final pulse = Pulse<int>(1, source: source.cell);
      final decoded = Pulse.fromJson(
        pulse.toJson(),
        resolver: (_) => null,
      );
      expect(decoded.source, isNull);
    });

    test('missing version discriminator throws PulseDecodeError', () {
      expect(
        () => Pulse.fromJson({'payload': 1}),
        throwsA(isA<PulseDecodeError>()),
      );
    });

    test('unsupported version throws PulseDecodeError', () {
      expect(
        () => Pulse.fromJson({'__pulse__': '2.0.0'}),
        throwsA(isA<PulseDecodeError>()),
      );
    });

    test('malformed payload shape throws PulseDecodeError', () {
      expect(
        () => Pulse.fromJson({
          '__pulse__': '1.0.0',
          'timestamp': 'not-a-timestamp',
        }),
        throwsA(isA<PulseDecodeError>()),
      );
    });
  });
}
