// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

Reject rejectOf(Verdict verdict) => verdict as Reject;

void main() {
  group('verdict parser — happy paths', () {
    test('parses a bare accept', () {
      final verdict = parseVerdict('{"verdict":"accept"}');
      expect(verdict, isA<Accept>());
    });

    test('parses a reject with its reason', () {
      final verdict = parseVerdict(
        '{"verdict":"reject","reason":"amount exceeds limit"}',
      );
      expect(verdict, isA<Reject>());
      expect((verdict as Reject).reason, 'amount exceeds limit');
    });

    test('parses a defer with its resolver', () {
      final verdict = parseVerdict(
        '{"verdict":"defer","resolver":"approval"}',
      );
      expect(verdict, isA<Defer>());
      expect((verdict as Defer).resolver, 'approval');
    });

    test('tolerates prose around the JSON object', () {
      final verdict = parseVerdict(
        'Here is my assessment:\n\n{"verdict":"accept","reason":"ok"}\n\nDone.',
      );
      expect(verdict, isA<Accept>());
    });

    test('unwraps markdown fences', () {
      final verdict = parseVerdict(
        '```json\n{"verdict":"accept"}\n```',
      );
      expect(verdict, isA<Accept>());
    });

    test('takes the first balanced JSON object when several exist', () {
      final verdict = parseVerdict(
        '{"verdict":"reject","reason":"no"} and later {"verdict":"accept"}',
      );
      expect(verdict, isA<Reject>());
    });

    test('carries reason, confidence, and custom annotations', () {
      final verdict = parseVerdict(
        '{"verdict":"accept","reason":"fine","confidence":0.9,'
        '"annotations":{"model":"gpt"}}',
      ) as Accept;
      expect(verdict.annotations['reason'], 'fine');
      expect(verdict.annotations['confidence'], 0.9);
      expect(verdict.annotations['model'], 'gpt');
    });

    test('case-insensitive verdict values', () {
      expect(parseVerdict('{"verdict":"ACCEPT"}'), isA<Accept>());
      expect(parseVerdict('{"verdict":"Reject","reason":"x"}'), isA<Reject>());
      expect(
        parseVerdict('{"verdict":"Defer","resolver":"a"}'),
        isA<Defer>(),
      );
    });
  });

  group('verdict parser — fail-closed matrix', () {
    test('malformed JSON → parse-error-invalid-json', () {
      expect(
        rejectOf(parseVerdict('{"verdict": "accept"')).reason,
        'parse-error-invalid-json',
      );
      expect(
        rejectOf(parseVerdict('not json at all {')).reason,
        'parse-error-invalid-json',
      );
    });

    test('no JSON found → parse-error-no-json', () {
      expect(
        rejectOf(parseVerdict('The model refused to answer.')).reason,
        'parse-error-no-json',
      );
    });

    test('missing verdict field → missing-verdict', () {
      expect(
        rejectOf(parseVerdict('{"reason":"no verdict"}')).reason,
        'missing-verdict',
      );
      expect(
        rejectOf(parseVerdict('{"verdict": 42}')).reason,
        'missing-verdict',
      );
    });

    test('unknown verdict value → unknown-verdict:<value>', () {
      expect(
        rejectOf(parseVerdict('{"verdict":"maybe"}')).reason,
        'unknown-verdict:maybe',
      );
    });

    test('reject without reason → missing-reason', () {
      expect(
        rejectOf(parseVerdict('{"verdict":"reject"}')).reason,
        'missing-reason',
      );
      expect(
        rejectOf(parseVerdict('{"verdict":"reject","reason":"  "}')).reason,
        'missing-reason',
      );
    });

    test('defer without resolver → defer-missing-resolver', () {
      expect(
        rejectOf(parseVerdict('{"verdict":"defer"}')).reason,
        'defer-missing-resolver',
      );
      expect(
        rejectOf(parseVerdict('{"verdict":"defer","resolver":""}')).reason,
        'defer-missing-resolver',
      );
    });

    test('a JSON object nested inside a JSON array is extracted', () {
      // The extractor takes the first balanced object anywhere in the
      // response — including inside an array.
      expect(parseVerdict('[{"verdict":"accept"}]'), isA<Accept>());
    });

    test('empty response → parse-error-no-json', () {
      expect(rejectOf(parseVerdict('')).reason, 'parse-error-no-json');
      expect(
        rejectOf(parseVerdict('   \n  ')).reason,
        'parse-error-no-json',
      );
    });

    test('never throws for any input', () {
      for (final raw in [
        '',
        'no',
        '{',
        'null',
        '[]',
        '{"verdict":null}',
        '{"verdict":"reject","reason":123}',
        'x' * 1000,
      ]) {
        final verdict = parseVerdict(raw);
        expect(verdict, isA<Reject>(), reason: 'input: $raw');
      }
    });

    test('strings with braces inside JSON survive extraction', () {
      final verdict = parseVerdict(
        '{"verdict":"reject","reason":"uses {braces} and \\"quotes\\""}',
      ) as Reject;
      expect(verdict.reason, 'uses {braces} and "quotes"');
    });
  });
}
