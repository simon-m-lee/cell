// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  group('streamCompletion bridge', () {
    test('emits one governed pulse per token', () async {
      final journal = RecordingJournal();
      final cell = streamCompletion(
        tokens: Stream.fromIterable(['He', 'll', 'o']),
        actor: 'llm',
        prompt: 'greet',
        journal: journal,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observed.map((p) => p.payload), ['He', 'll', 'o']);
      expect(
        observed.every((p) => p.type == 'mind.stream.token'),
        isTrue,
      );
      expect(observed.first.context.actor, 'llm');
      expect(observed.first.context.purpose, 'STREAM_COMPLETION');
      sub.stop();
    });

    test('an empty stream emits nothing', () async {
      final journal = RecordingJournal();
      final cell = streamCompletion(
        tokens: const Stream.empty(),
        actor: 'llm',
        prompt: 'p',
        journal: journal,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(observed, isEmpty);
      sub.stop();
    });

    test('a stream error emits a typed error pulse and journals it', () async {
      final journal = RecordingJournal();
      final cell = streamCompletion(
        tokens: Stream<String>.error(StateError('socket closed')),
        actor: 'llm',
        prompt: 'p',
        journal: journal,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observed.single.type, 'mind.stream.error');
      final json = journal.toJson();
      expect(
        json.any(
          (e) => e['kind'] == 'io' && e['label'] == 'mind.completion.error',
        ),
        isTrue,
      );
      sub.stop();
    });

    test('journals one chunk effect per token', () async {
      final journal = RecordingJournal();
      final cell = streamCompletion(
        tokens: Stream.fromIterable(['a', 'b']),
        actor: 'llm',
        prompt: 'p',
        journal: journal,
      );
      final sub = Cell.observe(source: cell, effect: (Pulse p) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final json = journal.toJson();
      expect(
        json.where(
          (e) => e['kind'] == 'io' && e['label'] == 'mind.stream.chunk',
        ),
        hasLength(2),
      );
      sub.stop();
    });

    test('merges a baseContext into each token pulse', () async {
      final base = PulseContext.fromEntries([
        Provenance.traceId.entry('stream-1'),
      ]);
      final journal = RecordingJournal();
      final cell = streamCompletion(
        tokens: Stream.fromIterable(['x']),
        actor: 'llm',
        prompt: 'p',
        baseContext: base,
        journal: journal,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observed.single.context.traceId, 'stream-1');
      sub.stop();
    });

    test('default stream confidence is 0.5', () async {
      final journal = RecordingJournal();
      final cell = streamCompletion(
        tokens: Stream.fromIterable(['x']),
        actor: 'llm',
        prompt: 'p',
        journal: journal,
      );
      final observed = <Pulse>[];
      final sub = Cell.observe(
          source: cell,
          effect: (Pulse p) {
            observed.add(p);
          });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observed.single.context.confidence, 0.5);
      sub.stop();
    });
  });
}
