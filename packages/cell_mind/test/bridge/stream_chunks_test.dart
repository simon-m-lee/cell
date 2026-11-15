// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('streamChunks bridge', () {
    test('buffer zero emits one pulse per chunk', () async {
      final journal = RecordingJournal();
      final cell = streamChunks(
        chunks: Stream.fromIterable(['a', 'b']),
        actor: 'llm',
        journal: journal,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observed.map((p) => p.payload), ['a', 'b']);
      expect(observed.first.type, 'mind.stream.chunk');
      sub.stop();
    });

    test('a positive buffer joins chunks arriving within the window', () async {
      final journal = RecordingJournal();
      final cell = streamChunks(
        chunks: Stream.fromIterable(['He', 'll', 'o']),
        actor: 'llm',
        journal: journal,
        buffer: const Duration(milliseconds: 10),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observed, hasLength(1), reason: 'The chunks coalesced.');
      expect(observed.single.payload, 'Hello');
      sub.stop();
    });

    test('the pending buffer flushes on stream close', () async {
      final journal = RecordingJournal();
      final cell = streamChunks(
        chunks: Stream.fromIterable(['tail']),
        actor: 'llm',
        journal: journal,
        buffer: const Duration(minutes: 5),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observed.single.payload, 'tail',
          reason: 'The final batch flushes on done.');
      sub.stop();
    });

    test('an empty stream emits nothing', () async {
      final journal = RecordingJournal();
      final cell = streamChunks(
        chunks: const Stream.empty(),
        actor: 'llm',
        journal: journal,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observed, isEmpty);
      sub.stop();
    });

    test('a stream error emits a typed error pulse', () async {
      final journal = RecordingJournal();
      final cell = streamChunks(
        chunks: Stream<String>.error(StateError('boom')),
        actor: 'llm',
        journal: journal,
        buffer: const Duration(milliseconds: 5),
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observed.single.type, 'mind.stream.error');
      sub.stop();
    });
  });
}
