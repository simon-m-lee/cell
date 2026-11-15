// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The phase plan mandates numbered cookbook test names.
// ignore_for_file: file_names

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart' hide completion;

void main() {
  test('recipe 5: LLM confidence gating', () async {
    final model = completion(
      future: Future<String>.value('answer'),
      actor: 'model',
      prompt: 'prompt',
      confidence: 0.98,
      journal: RecordingJournal(),
    );
    final gate = Cell.ingress<Pulse>();
    final handle = cognitive(
      cell: gate.cell,
      policy: confidencePolicy(min: 0.9),
    );
    await gate.ingest(Pulse<Pulse>.governed(
      payload: Pulse<String>.governed(
        payload: 'prompt',
        context: PulseContext.fromEntries([
          Provenance.confidence.entry(0.98),
          Provenance.actor.entry('user'),
        ]),
      ),
      context: PulseContext.fromEntries([Provenance.confidence.entry(0.98)]),
    ));
    await gate.ingest(Pulse<Pulse>.governed(
      payload: Pulse<String>.governed(payload: 'prompt'),
      context: PulseContext.fromEntries([Provenance.confidence.entry(0.2)]),
    ));
    await Future<void>.delayed(Duration.zero);
    final verdicts = handle.decisions
        .where((d) => d.pulse != null)
        .map((d) => d.verdict)
        .toList();
    expect(verdicts[0], isA<Accept>());
    expect(verdicts[1], isA<Reject>());
    expect(model, isA<Cell>());
  });
}
