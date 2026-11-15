// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

import '../helpers/prompt_fixtures.dart';

void main() {
  ConformanceCase caseWith(Verdict expected) => ConformanceCase(
        context: Context.system,
        decision: Pulse<int>(1, type: 'tx'),
        expected: expected,
      );

  group('conform', () {
    test('all-passing cases produce a clean report', () async {
      final report = await conform(
        config: tinyConfig(),
        prompt: mockPrompt(acceptResponse),
        cases: [
          caseWith(const Accept()),
          caseWith(const Accept()),
        ],
      );
      expect(report.total, 2);
      expect(report.passed, 2);
      expect(report.failures, isEmpty);
      expect(report.passedAll, isTrue);
      expect(report.passRate, 1.0);
      expect(report.configId, startsWith('tiny-'));
      expect(report.configVersion, '1.0.0');
      expect(report.totalLatency, greaterThanOrEqualTo(Duration.zero));
      expect(report.averageLatency, greaterThanOrEqualTo(Duration.zero));
    });

    test('a wrong verdict counts as a failure with the actual verdict',
        () async {
      final report = await conform(
        config: tinyConfig(),
        prompt: mockPrompt(rejectResponse),
        cases: [caseWith(const Accept())],
      );
      expect(report.passed, 0);
      expect(report.failures, hasLength(1));
      expect(report.failures.single.actual, isA<Reject>());
      expect(report.failures.single.testCase.expected, isA<Accept>());
      expect(report.passedAll, isFalse);
      expect(report.passRate, 0.0);
    });

    test('Reject reasons participate in the comparison', () async {
      final report = await conform(
        config: tinyConfig(),
        prompt: mockPrompt('{"verdict":"reject","reason":"other"}'),
        cases: [caseWith(const Reject('expected-reason'))],
      );
      expect(report.passed, 0);
      expect(report.failures.single.reason, contains('expected-reason'));
    });

    test('matching Reject reasons pass', () async {
      final report = await conform(
        config: tinyConfig(),
        prompt: mockPrompt('{"verdict":"reject","reason":"same"}'),
        cases: [caseWith(const Reject('same'))],
      );
      expect(report.passedAll, isTrue);
    });

    test('Defer resolvers participate in the comparison', () async {
      final report = await conform(
        config: tinyConfig(),
        prompt: mockPrompt('{"verdict":"defer","resolver":"approval"}'),
        cases: [caseWith(const Defer('approval'))],
      );
      expect(report.passedAll, isTrue);
      final mismatch = await conform(
        config: tinyConfig(),
        prompt: mockPrompt('{"verdict":"defer","resolver":"other"}'),
        cases: [caseWith(const Defer('approval'))],
      );
      expect(mismatch.passed, 0);
    });

    test('prompt-too-long cases fail closed inside the report', () async {
      var calls = 0;
      final report = await conform(
        config: tinyConfig(),
        prompt: (_) async {
          calls++;
          return acceptResponse;
        },
        cases: [caseWith(const Accept())],
      );
      expect(report.total, 1);
      // tinyConfig renders under 32000 chars, so the call happened.
      expect(calls, 1);
      expect(report.passedAll, isTrue);
    });

    test('an LLM error case records prompt-error in the report', () async {
      final report = await conform(
        config: tinyConfig(),
        prompt: (_) async => throw StateError('down'),
        cases: [caseWith(const Accept())],
      );
      expect(report.failures.single.actual, isA<Reject>());
      expect(
        (report.failures.single.actual as Reject).reason,
        'prompt-error',
      );
    });

    test('an empty case list produces a passing empty report', () async {
      final report = await conform(
        config: tinyConfig(),
        prompt: mockPrompt(acceptResponse),
        cases: const [],
      );
      expect(report.total, 0);
      expect(report.passedAll, isTrue);
      expect(report.passRate, 1.0);
      expect(report.averageLatency, Duration.zero);
    });

    test('invalid configs throw before any LLM call', () async {
      var calls = 0;
      await expectLater(
        conform(
          config: PromptConfig.custom(
            id: 'bad',
            version: '',
            description: 'd',
            systemPrompt: 's',
            userTemplate: '{{context}}',
          ),
          prompt: (_) async {
            calls++;
            return acceptResponse;
          },
          cases: [caseWith(const Accept())],
        ),
        throwsArgumentError,
      );
      expect(calls, 0);
    });

    test('the optional journal captures conformance effects for replay',
        () async {
      final journal = RecordingJournal();
      final report = await conform(
        config: tinyConfig(),
        prompt: mockPrompt(acceptResponse),
        cases: [caseWith(const Accept())],
        journal: journal,
      );
      expect(report.passedAll, isTrue);
      final labels = journal.toJson().whereType<Map<String, Object?>>().where(
            (e) => e['kind'] == 'io' && e['label'] == 'mind.prompt.conformance',
          );
      expect(labels, hasLength(1));
    });
  });
}
