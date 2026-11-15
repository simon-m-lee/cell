// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered example file names; the numeric
// prefix is intentional (06_llm_bridge → example #6).
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';

/// LLM bridge demo — governed completion + closed-verb tool router.
///
/// Run with:
/// ```bash
/// dart run example/06_llm_bridge.dart
/// ```
Future<void> main() async {
  print('=== LLM bridge demo ===');
  print('');

  final journal = RecordingJournal();

  // ── 1. Single-shot completion ────────────────────────────────
  print('--- 1. Single-shot completion ---');
  final cell = completion(
    future: Future.value('The answer is 4.'),
    actor: 'demo-llm',
    prompt: 'What is 2 + 2?',
    confidence: 0.9,
    journal: journal,
  );
  final sub1 = Cell.observe(
      source: cell,
      effect: (Pulse p) {
        print('  ${p.type}: "${p.payload}" '
            '(actor ${p.context.actor}, conf ${p.context.confidence})');
      });
  await Future<void>.delayed(const Duration(milliseconds: 30));

  // A failing completion is a typed pulse, not an exception.
  print('');
  print('--- Failing completion ---');
  final failing = completion(
    future: Future<String>.error(StateError('model unavailable')),
    actor: 'demo-llm',
    prompt: 'What is the airspeed of an unladen swallow?',
    confidence: 0.9,
    journal: journal,
  );
  final sub2 = Cell.observe(
      source: failing,
      effect: (Pulse p) {
        print('  ${p.type} (payload ${p.payload})');
      });
  await Future<void>.delayed(const Duration(milliseconds: 30));

  // ── 2. Tool router ───────────────────────────────────────────
  print('');
  print('--- 2. Tool router ---');
  final inbound = Cell.ingress<Pulse>();
  final router = toolRouter(
    source: inbound.cell,
    tools: {
      'fetch_user': (args) async =>
          {'id': args['id'], 'name': 'User ${args['id']}'},
      'compute': (args) async => (args['a'] as int) + (args['b'] as int),
    },
    actor: 'demo-llm',
    journal: journal,
    minConfidence: 0.8,
  );
  final sub3 = Cell.observe(
      source: router,
      effect: (Pulse p) {
        // The router emits the result PULSE as the payload — unwrap once.
        final inner = p.payload as Pulse;
        print('  ${inner.type}: ${inner.payload}');
      });

  inbound.emit(toolCall('fetch_user', {'id': 42}, 0.95));
  await Future<void>.delayed(const Duration(milliseconds: 30));
  inbound.emit(toolCall('compute', {'a': 20, 'b': 22}, 0.95));
  await Future<void>.delayed(const Duration(milliseconds: 30));
  inbound.emit(toolCall('delete_database', const {}, 0.9));
  await Future<void>.delayed(const Duration(milliseconds: 30));
  inbound.emit(toolCall('fetch_user', {'id': 1}, 0.3));
  await Future<void>.delayed(const Duration(milliseconds: 30));

  // ── 3. Streaming ─────────────────────────────────────────────
  print('');
  print('--- 3. Streaming completion ---');
  final streaming = streamCompletion(
    tokens: Stream.fromIterable(['Hel', 'lo', '!']),
    actor: 'demo-llm',
    prompt: 'greet',
    journal: journal,
  );
  final sub4 = Cell.observe(
      source: streaming,
      effect: (Pulse p) {
        print('  token: "${p.payload}"');
      });
  await Future<void>.delayed(const Duration(milliseconds: 50));

  print('');
  print('=== Done ===');
  sub1.stop();
  sub2.stop();
  sub3.stop();
  sub4.stop();
}

Pulse toolCall(
  String verb,
  Map<String, dynamic> args,
  double confidence,
) =>
    Pulse<Map<String, dynamic>>.governed(
      payload: {'verb': verb, 'args': args},
      context: PulseContext.fromEntries([
        Provenance.actor.entry('demo-llm'),
        Provenance.reason.entry('tool call $verb'),
        Provenance.confidence.entry(confidence),
      ]),
    );
