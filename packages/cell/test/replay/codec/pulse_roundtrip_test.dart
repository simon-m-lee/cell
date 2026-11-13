// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:math';

import 'package:cell/cell.dart';

import 'package:test/test.dart';

void main() {
  group('PulseCodec round-trip', () {
    test('1000 generated pulses re-encode byte-identically', () {
      final rng = Random(42);
      for (var i = 0; i < 1000; i++) {
        final pulse = _generatePulse(rng, i);
        _expectByteRoundTrip(pulse, reason: 'generated pulse #$i: $pulse');
      }
    });

    test('parent digest mismatch fails loudly', () {
      final root = Pulse<int>(1);
      final leaf = root.evolve(pulse: Pulse<int>(2, step: 'derived'));
      final leafJson = PulseCodec.toJson(leaf);

      final wrongParent =
          PulseCodec.fromJson(PulseCodec.toJson(Pulse<int>(999)));
      expect(
        () => PulseCodec.fromJson(leafJson, parent: wrongParent),
        throwsFormatException,
      );
    });

    test('parentDigest without a supplied parent fails loudly', () {
      final leaf = Pulse<int>(1).evolve(pulse: Pulse<int>(2));
      expect(
        () => PulseCodec.fromJson(PulseCodec.toJson(leaf)),
        throwsArgumentError,
      );
    });

    test('a root pulse rejects a supplied parent', () {
      final rootJson = PulseCodec.toJson(Pulse<int>(1));
      final parent = PulseCodec.fromJson(rootJson);
      expect(
        () => PulseCodec.fromJson(rootJson, parent: parent),
        throwsArgumentError,
      );
    });

    test('a non-prefix parent trace fails loudly', () {
      final root = Pulse<int>(1, step: 'original');
      final leaf = root.evolve(pulse: Pulse<int>(2));
      final leafJson = PulseCodec.toJson(leaf);

      final wrongChain =
          PulseCodec.fromJson(PulseCodec.toJson(Pulse<int>(1, step: 'other')));
      expect(
        () => PulseCodec.fromJson(leafJson, parent: wrongChain),
        throwsFormatException,
      );
    });

    test('source is encoded by cell id', () {
      final cell = Cell.ingress<int>().cell;
      final pulse = Pulse<int>(1, source: cell);
      final json = PulseCodec.toJson(pulse);
      expect(json['source'], cell.id);
      expect(cell.id, startsWith('nucleus:'));
    });

    test('unset optional fields are omitted from the wire map', () {
      final json = PulseCodec.toJson(Pulse<int>(1));
      expect(json, {
        'payload': 1,
        'priority': Pulse.defaultPriority,
        'timestamp': json['timestamp'], // present, non-null
        'trace': <String>[],
        'context': {
          'lineage': [
            <String, Object?>{},
          ],
        },
      });
      expect(json.containsKey('type'), isFalse);
      expect(json.containsKey('source'), isFalse);
      expect(json.containsKey('parentDigest'), isFalse);
    });
  });
}

/// Encodes every node of `pulse`'s public parent chain (root first), decodes
/// them back top-down (each node receiving its rebuilt parent), and asserts
/// that every level re-encodes to the identical canonical bytes.
void _expectByteRoundTrip(Pulse pulse, {required String reason}) {
  final chain = <Pulse>[];
  Pulse? cursor = pulse;
  while (cursor != null) {
    chain.insert(0, cursor);
    cursor = cursor is EvolvedPulse ? cursor.parent : null;
  }

  final encoded =
      chain.map(PulseCodec.toJson).toList(growable: false);
  Pulse? parent;
  final rebuilt = <Pulse>[];
  for (final json in encoded) {
    parent = PulseCodec.fromJson(json, parent: parent);
    rebuilt.add(parent);
  }

  for (var i = 0; i < encoded.length; i++) {
    final expected = canonicalJsonEncode(encoded[i]);
    final actual = canonicalJsonEncode(PulseCodec.toJson(rebuilt[i]));
    expect(actual, expected, reason: '$reason — chain level $i of ${chain.length}');
  }
}

Pulse _generatePulse(Random rng, int i) {
  Pulse pulse = Pulse.governed(
    context: _generateContext(rng, i),
    payload: _generatePayload(rng, i),
    type: rng.nextBool() ? 'type.${rng.nextInt(5)}' : null,
    priority: rng.nextBool() ? rng.nextInt(101) : null,
    step: rng.nextBool() ? 'step.$i' : null,
  );

  final links = rng.nextInt(4);
  for (var l = 0; l < links; l++) {
    final inner = Pulse<dynamic>(
      _generatePayload(rng, i * 100 + l),
      type: rng.nextBool() ? 'inner.$l' : null,
      step: rng.nextBool() ? 'inner-step.$i.$l' : null,
    );
    pulse = pulse.evolve(
      pulse: inner,
      step: rng.nextBool() ? 'link.$i.$l' : null,
    );
  }
  return pulse;
}

Object? _generatePayload(Random rng, int i) {
  switch (rng.nextInt(8)) {
    case 0:
      return null;
    case 1:
      return i;
    case 2:
      return -i - 1;
    case 3:
      return i + 0.25;
    case 4:
      return i.isEven;
    case 5:
      return 'value $i — 中文 "quoted" \n tab\t';
    case 6:
      return [i, 's', null, i.isEven, i + 0.5];
    default:
      return {
        'id': i,
        'nested': {'flag': i.isEven, 'nothing': null},
        'tags': ['a', 'b'],
      };
  }
}

PulseContext _generateContext(Random rng, int i) {
  final levels = rng.nextInt(3);
  PulseContext? context;
  for (var l = 0; l < levels; l++) {
    final entries = <GovernanceEntry>[
      if (rng.nextBool()) Provenance.actor.entry('actor.$i.$l'),
      if (rng.nextBool()) Provenance.reason.entry('reason.$i.$l'),
      if (rng.nextBool()) Provenance.purpose.entry('purpose.$l'),
      if (rng.nextBool())
        Provenance.strategy.entry(
          ReasoningStrategy.values[rng.nextInt(ReasoningStrategy.values.length)],
        ),
      if (rng.nextBool()) Provenance.confidence.entry(rng.nextDouble()),
      if (rng.nextBool()) Provenance.priority.entry(rng.nextInt(101)),
      if (rng.nextBool()) Provenance.compliance.entry('COMPLY.$l'),
      if (rng.nextBool())
        Provenance.sensitivity.entry(
          Sensitivity.values[rng.nextInt(Sensitivity.values.length)],
        ),
      if (rng.nextBool())
        Provenance.auditLevel.entry(
          AuditLevel.values[rng.nextInt(AuditLevel.values.length)],
        ),
      if (rng.nextBool()) Provenance.traceId.entry('trace.$i.$l'),
      if (rng.nextBool()) Provenance.parentTraceId.entry('ptrace.$i.$l'),
      if (rng.nextBool()) Provenance.integrity.entry('integrity.$l'),
    ];
    context = PulseContext.fromEntries(
      entries,
      others: rng.nextBool()
          ? {'k$l': 'v$l', 'nested': {'n': l}}
          : null,
      parent: context,
    );
  }
  return context ?? PulseContext.system;
}
