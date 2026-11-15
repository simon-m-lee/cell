// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/prompt_fixtures.dart';

void main() {
  int read(int x) => x;

  group('trust boundary — structural first', () {
    test('a structural rejection skips the LLM entirely', () async {
      var calls = 0;
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: predicatePolicy((object, {required host}) => false),
        verdictPolicy: promptedPolicyWith(
          config: tinyConfig(),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      final outcome =
          await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(outcome, isA<ApplyRejected<Object?>>());
      expect(calls, 0);
      final verdict = handle.decisions.single.verdict as Reject;
      expect(verdict.reason, 'policy-rejected');
    });

    test('the LLM cannot accept what the structural gate rejected', () async {
      // The composite rule order is principal → policy → verdictPolicy;
      // a policy reject never reaches the verdict slot.
      var calls = 0;
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: predicatePolicy((object, {required host}) => false),
        verdictPolicy: promptedPolicyWith(
          config: tinyConfig(),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(calls, 0);
      expect(handle.decisions.single.verdict, isA<Reject>());
    });

    test('a structural pass lets the LLM decide', () async {
      var calls = 0;
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: predicatePolicy((object, {required host}) => true),
        verdictPolicy: promptedPolicyWith(
          config: tinyConfig(),
          prompt: (_) async {
            calls++;
            return rejectResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(calls, 1);
      final verdict = handle.decisions.single.verdict as Reject;
      expect(verdict.reason, 'policy violation');
    });

    test('the LLM can only veto, never override — reject stays rejected',
        () async {
      // LLM accepts, but the structural gate already rejected: the
      // composite outcome must remain a rejection.
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy: predicatePolicy((object, {required host}) => false),
        verdictPolicy: promptedPolicyWith(
          config: tinyConfig(),
          prompt: mockPrompt(acceptResponse),
          journal: RecordingJournal(),
        ),
      );
      final outcome = await handle.cognitive.apply<int>(commandFor(read, [7]));
      expect(outcome, isA<ApplyRejected<int>>());
    });

    test('a principal-rule rejection also skips the LLM', () async {
      var calls = 0;
      // A cell whose own validate rejects commands but accepts pulses
      // and links (a reject-everything rule would also reject the
      // deputy link and construction would fail).
      final src = Cell.ingress<int>(
        testRule: TestCell(
          (object, {host, arguments, user}) => object is! Function,
        ),
      );
      final handle = cognitive(
        cell: src.cell,
        policy: TestCell.allowAll,
        verdictPolicy: promptedPolicyWith(
          config: tinyConfig(),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      final outcome =
          await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(outcome, isA<ApplyRejected<Object?>>());
      expect(calls, 0);
      // Principal rejections drop upstream: the deputy chain runs the
      // principal's rule first, so the recorder never sees the command
      // and nothing is logged (documented runtime behaviour).
      expect(handle.decisions, isEmpty);
    });

    test('contextAware + promptedPolicyWith compose as the recommended gate',
        () async {
      var calls = 0;
      final src = Cell.ingress<int>(context: Context(domains: 'finance'));
      final handle = cognitive(
        cell: src.cell,
        policy: contextAware(),
        verdictPolicy: promptedPolicyWith(
          config: PromptConfig.policyDecider(),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(calls, 1);
      expect(handle.decisions.single.verdict, isA<Accept>());
    });

    test('async structural policies also gate the LLM', () async {
      var calls = 0;
      final src = Cell.ingress<int>();
      final handle = cognitive(
        cell: src.cell,
        policy:
            TestCell<Cell>((object, {host, arguments, user}) async => false),
        verdictPolicy: promptedPolicyWith(
          config: tinyConfig(),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          journal: RecordingJournal(),
        ),
      );
      final outcome =
          await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(outcome, isA<ApplyRejected<Object?>>());
      expect(calls, 0);
    });

    test('chained verdict policies still respect the structural slot',
        () async {
      var calls = 0;
      final src = Cell.ingress<int>();
      final llm = promptedPolicyWith(
        config: tinyConfig(),
        prompt: (_) async {
          calls++;
          return rejectResponse;
        },
        journal: RecordingJournal(),
      );
      final handle = cognitive(
        cell: src.cell,
        policy: predicatePolicy((object, {required host}) => false),
        verdictPolicy: learnedVerdictPolicy() + llm,
      );
      await handle.cognitive.apply<Object?>(commandFor(read, [7]));
      expect(calls, 0);
      expect(handle.decisions.single.verdict, isA<Reject>());
    });
  });
}
