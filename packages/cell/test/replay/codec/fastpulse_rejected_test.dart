// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// the serialisation layer, exit item 5: `PulseCodec.toJson` rejects the un-materialised
// flyweight pulses. The types themselves are private to the `cell` library,
// but the public API produces them — `Cell.ingress` emits `_FastPulse` and
// `Pulse.withStep` returns `_StepPulse` — so the reject path is testable
// from an external test package without naming the private types.

import 'package:cell/cell.dart';

import 'package:test/test.dart';

void main() {
  group('materialise boundary', () {
    test('toJson rejects the _FastPulse produced by Cell.ingress', () {
      final gate = Cell.ingress<int>();
      Pulse? captured;
      final observer = Cell.observe(
        source: gate.cell,
        effect: (Pulse p) => captured = p,
      );
      gate.emit(42);
      observer.stop();

      expect(captured, isNotNull);
      expect(() => PulseCodec.toJson(captured!), throwsArgumentError);

      final materialised = PulseCodec.materialise(captured!);
      final json = PulseCodec.toJson(materialised);
      expect(json['payload'], 42);
      expect(json['source'], gate.cell.id);
    });

    test('toJson rejects _StepPulse; materialise preserves payload and trace',
        () {
      final stepped = Pulse<int>(7).withStep('a').withStep('b');
      expect(() => PulseCodec.toJson(stepped), throwsArgumentError);

      final materialised = PulseCodec.materialise(stepped);
      final json = PulseCodec.toJson(materialised);
      expect(json['payload'], 7);
      expect(json['trace'], ['a', 'b']);
      expect(json['parentDigest'], isNotNull);
    });

    test('materialise on a plain pulse is identity (no work needed)', () {
      final plain = Pulse<int>(1, step: 'x');
      expect(identical(PulseCodec.materialise(plain), plain), isTrue);

      final json = PulseCodec.toJson(plain);
      expect(json['trace'], ['x']);
      expect(json['parentDigest'], isNull);
    });

    test('materialise cleans _StepPulse ancestors of an evolved pulse', () {
      // root.withStep(...) makes the parent a _StepPulse; the evolved leaf
      // itself is plain, so toJson would reach the dirty parent chain.
      // materialise must rebuild it.
      final root = Pulse<int>(3);
      final stepped = root.withStep('ingress');
      final leaf = stepped.evolve(pulse: Pulse<int>(4), step: 'derived');

      expect(() => PulseCodec.toJson(leaf), isNotNull); // leaf itself is fine
      final materialised = PulseCodec.materialise(leaf);
      final json = PulseCodec.toJson(materialised);
      expect(json['payload'], 4);
      expect(json['trace'], ['ingress', 'derived']);
      expect(json['parentDigest'], isNotNull);
    });
  });
}
