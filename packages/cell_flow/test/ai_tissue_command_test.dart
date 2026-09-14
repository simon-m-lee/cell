// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:cell_flow/cell_flow.dart';
import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

import 'package:cell_flow/src/instruction/ai_tissue_command.dart';
import 'package:cell_flow/src/instruction/ai_tissue_command_domain.dart';

// ─────────────────────────────────────────────────────────────
// TEST SUITE — AiTissueCommand family
//
// Comprehensive unit tests for `ai_tissue_command.dart` and
// `ai_tissue_command_domain.dart`. The suite is organised into
// eleven groups:
//
//   1.  TissueVerb / verbByName — the closed vocabulary.
//   2.  TissueCommand / Reject — the reply shapes.
//   3.  systemPrompt — the security contract.
//   4.  AiConfig — JSON round-trip and validation.
//   5.  StubInterpreter — success, refusal, error paths.
//   6.  AiTissueCommand — single sentence, latest-wins.
//   7.  AiTissueCommandBatch — ordered aggregation.
//   8.  AiTissueCommandWithRetry — retry semantics.
//   9.  AiTissueCommand.fromConfig — config path, no env fallback.
//   10. Integration with a TissueSet — the dispatch seam.
//   11. provenance — step tags and source preservation.
//
// Every test is independent. Test-only interpreters are declared
// at the bottom of the file and are private to the suite.
//
// ─────────────────────────────────────────────────────────────
// HOW TO RUN
// ─────────────────────────────────────────────────────────────
//
// From the package root:
//
//     dart test test/ai_tissue_command_test.dart
//
// Or with the `test` runner watching for changes:
//
//     dart test --watch test/ai_tissue_command_test.dart
//
// ─────────────────────────────────────────────────────────────

void main() {
  // ═════════════════════════════════════════════════════════════
  // 1. TissueVerb / verbByName
  // ═════════════════════════════════════════════════════════════

  group('TissueVerb / verbByName', () {
    test('verbByName resolves every enum value', () {
      for (final verb in TissueVerb.values) {
        expect(
          verbByName[verb.name],
          equals(verb),
          reason: 'verbByName[${verb.name}] must resolve to $verb',
        );
      }
    });

    test('verbByName contains exactly the enum names', () {
      expect(verbByName.length, equals(TissueVerb.values.length));
      expect(
        verbByName.keys.toSet(),
        equals(TissueVerb.values.map((v) => v.name).toSet()),
      );
    });

    test('verbByName returns null for an unknown verb string', () {
      expect(verbByName['bogus'], isNull);
      expect(verbByName[''], isNull);
      expect(verbByName['ADD'], isNull); // case-sensitive
    });

    test('removeWhere / retainWhere are declared but not driven', () {
      expect(verbByName['removeWhere'], equals(TissueVerb.removeWhere));
      expect(verbByName['retainWhere'], equals(TissueVerb.retainWhere));
    });
  });

  // ═════════════════════════════════════════════════════════════
  // 2. TissueCommand / Reject
  // ═════════════════════════════════════════════════════════════

  group('TissueCommand', () {
    test('ok is true', () {
      const cmd = TissueCommand(
        verb: TissueVerb.add,
        args: [3],
        confidence: 0.95,
        source: 'add 3',
      );
      expect(cmd.ok, isTrue);
    });

    test('toString is informative', () {
      const cmd = TissueCommand(
        verb: TissueVerb.add,
        args: [3],
        confidence: 0.95,
        source: 'add 3',
      );
      expect(cmd.toString(), contains('add'));
      expect(cmd.toString(), contains('[3]'));
      expect(cmd.toString(), contains('0.95'));
    });

    test('const constructor is available', () {
      const cmd = TissueCommand(
        verb: TissueVerb.clear,
        args: [],
        confidence: 1.0,
        source: 'clear',
      );
      expect(cmd.verb, equals(TissueVerb.clear));
      expect(cmd.args, isEmpty);
    });
  });

  group('Reject', () {
    test('ok is false', () {
      const rej = Reject(source: 'x', reason: 'no-permitted-verb');
      expect(rej.ok, isFalse);
    });

    test('toString is informative', () {
      const rej = Reject(source: 'hack', reason: 'no-permitted-verb');
      expect(rej.toString(), contains('hack'));
      expect(rej.toString(), contains('no-permitted-verb'));
    });

    test('is const', () {
      const rej = Reject(source: 'x', reason: 'y');
      expect(rej.source, equals('x'));
      expect(rej.reason, equals('y'));
    });
  });

  // ═════════════════════════════════════════════════════════════
  // 3. systemPrompt
  // ═════════════════════════════════════════════════════════════

  group('systemPrompt', () {
    test('lists the given verbs in sorted order', () {
      final prompt = systemPrompt({'remove', 'add', 'clear'});
      final addIdx = prompt.indexOf('  - add');
      final clearIdx = prompt.indexOf('  - clear');
      final removeIdx = prompt.indexOf('  - remove');
      expect(addIdx, greaterThan(-1));
      expect(clearIdx, greaterThan(addIdx));
      expect(removeIdx, greaterThan(clearIdx));
    });

    test('does not leak verbs not in the given set', () {
      final prompt = systemPrompt({'add'});
      expect(prompt, contains('  - add'));
      expect(prompt, isNot(contains('  - clear')));
      expect(prompt, isNot(contains('  - remove')));
    });

    test('contains both reply shapes', () {
      final prompt = systemPrompt({'add'});
      expect(prompt, contains('"verb":"<name>"'));
      expect(prompt, contains('"verb":"reject"'));
    });

    test('is deterministic for the same verb set', () {
      final a = systemPrompt({'add', 'remove', 'clear'});
      final b = systemPrompt({'clear', 'add', 'remove'});
      expect(a, equals(b));
    });
  });

  // ═════════════════════════════════════════════════════════════
  // 4. AiConfig
  // ═════════════════════════════════════════════════════════════

  group('AiConfig', () {
    test('round-trips through toJson / fromJson', () {
      final config = AiConfig(
        endpoint: Uri.parse('https://example.com/v1/chat/completions'),
        apiKey: 'sk-test-key',
        model: 'test-model',
        timeout: const Duration(seconds: 45),
        extraBody: const {'seed': 42},
      );

      final json = config.toJson();
      final round = AiConfig.fromJson(json);

      expect(round.endpoint, equals(config.endpoint));
      expect(round.apiKey, equals(config.apiKey));
      expect(round.model, equals(config.model));
      expect(round.timeout, equals(config.timeout));
      expect(round.extraBody, equals(config.extraBody));
    });

    test('fromJson throws when endpoint is missing', () {
      expect(
        () => AiConfig.fromJson({
          'apiKey': 'sk-x',
          'model': 'm',
        }),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('"endpoint" is required'),
        )),
      );
    });

    test('fromJson throws when apiKey is missing', () {
      expect(
        () => AiConfig.fromJson({
          'endpoint': 'https://example.com',
          'model': 'm',
        }),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('"apiKey" is required'),
        )),
      );
    });

    test('fromJson throws when model is missing', () {
      expect(
        () => AiConfig.fromJson({
          'endpoint': 'https://example.com',
          'apiKey': 'sk-x',
        }),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('"model" is required'),
        )),
      );
    });

    test('fromJson defaults timeoutSeconds to 30', () {
      final config = AiConfig.fromJson({
        'endpoint': 'https://example.com',
        'apiKey': 'sk-x',
        'model': 'm',
      });
      expect(config.timeout, equals(const Duration(seconds: 30)));
    });

    test('fromJson honours a positive timeoutSeconds', () {
      final config = AiConfig.fromJson({
        'endpoint': 'https://example.com',
        'apiKey': 'sk-x',
        'model': 'm',
        'timeoutSeconds': 90,
      });
      expect(config.timeout, equals(const Duration(seconds: 90)));
    });

    test('fromJson ignores a non-positive timeoutSeconds', () {
      final config = AiConfig.fromJson({
        'endpoint': 'https://example.com',
        'apiKey': 'sk-x',
        'model': 'm',
        'timeoutSeconds': -5,
      });
      expect(config.timeout, equals(const Duration(seconds: 30)));
    });

    test('fromJson preserves extraBody', () {
      final config = AiConfig.fromJson({
        'endpoint': 'https://example.com',
        'apiKey': 'sk-x',
        'model': 'm',
        'extraBody': {'seed': 7, 'top_p': 0.9},
      });
      expect(config.extraBody, equals({'seed': 7, 'top_p': 0.9}));
    });

    test('toJson omits extraBody when empty', () {
      final live = AiConfig(
        endpoint: Uri.parse('https://example.com'),
        apiKey: 'sk-x',
        model: 'm',
      );
      expect(live.toJson().containsKey('extraBody'), isFalse);
    });

    test('toInterpreter carries every field through', () {
      final config = AiConfig(
        endpoint: Uri.parse('https://example.com'),
        apiKey: 'sk-key',
        model: 'm',
        timeout: const Duration(seconds: 12),
        extraBody: const {'seed': 1},
      );
      final interpreter = config.toInterpreter();
      expect(interpreter.endpoint, equals(config.endpoint));
      expect(interpreter.apiKey, equals(config.apiKey));
      expect(interpreter.model, equals(config.model));
      expect(interpreter.timeout, equals(config.timeout));
      expect(interpreter.extraBody, equals(config.extraBody));
      interpreter.close();
    });
  });

  // ═════════════════════════════════════════════════════════════
  // 5. StubInterpreter
  // ═════════════════════════════════════════════════════════════

  group('StubInterpreter', () {
    late StubInterpreter stub;

    setUp(() {
      stub = StubInterpreter(
        latency: Duration.zero,
        log: TrafficLog(silent: true),
      );
    });

    test('transport label is "stub"', () {
      expect(stub.transport, equals('stub'));
    });

    test('"add 3" produces add(3)', () async {
      final reply = await stub.complete(
        text: 'add 3',
        verbs: {'add'},
      );
      expect(reply.command, isNotNull);
      expect(reply.command!.verb, equals(TissueVerb.add));
      expect(reply.command!.args, equals([3]));
      expect(reply.reject, isNull);
    });

    test('"please insert 7" produces add(7)', () async {
      final reply = await stub.complete(
        text: 'please insert 7',
        verbs: {'add'},
      );
      expect(reply.command!.verb, equals(TissueVerb.add));
      expect(reply.command!.args, equals([7]));
    });

    test('"add -1" produces add(-1)', () async {
      final reply = await stub.complete(
        text: 'add -1',
        verbs: {'add'},
      );
      expect(reply.command!.verb, equals(TissueVerb.add));
      expect(reply.command!.args, equals([-1]));
    });

    test('"remove 5" produces remove(5)', () async {
      final reply = await stub.complete(
        text: 'remove 5',
        verbs: {'remove'},
      );
      expect(reply.command!.verb, equals(TissueVerb.remove));
      expect(reply.command!.args, equals([5]));
    });

    test('"delete 9" produces remove(9)', () async {
      final reply = await stub.complete(
        text: 'delete 9',
        verbs: {'remove'},
      );
      expect(reply.command!.verb, equals(TissueVerb.remove));
      expect(reply.command!.args, equals([9]));
    });

    test('"clear the set" produces clear()', () async {
      final reply = await stub.complete(
        text: 'clear the set',
        verbs: {'clear'},
      );
      expect(reply.command!.verb, equals(TissueVerb.clear));
      expect(reply.command!.args, isEmpty);
    });

    test('"addAll 4 5" produces addAll([4, 5])', () async {
      final reply = await stub.complete(
        text: 'addAll 4 5',
        verbs: {'addAll'},
      );
      expect(reply.command!.verb, equals(TissueVerb.addAll));
      expect(reply.command!.args, hasLength(1));
      expect(reply.command!.args.first, equals([4, 5]));
    });

    test('unknown sentence produces a Reject', () async {
      final reply = await stub.complete(
        text: 'hack the nucleus',
        verbs: {'add', 'remove', 'clear'},
      );
      expect(reply.command, isNull);
      expect(reply.reject, isNotNull);
      expect(reply.reject!.reason, equals('no-permitted-verb'));
    });

    test('verb not in allow-list produces a Reject', () async {
      final reply = await stub.complete(
        text: 'add 3',
        verbs: {'remove'},
      );
      expect(reply.command, isNull);
      expect(reply.reject!.reason, equals('no-permitted-verb'));
    });

    test('empty text produces a Reject with reason empty-command', () async {
      final reply = await stub.complete(
        text: '',
        verbs: {'add'},
      );
      expect(reply.reject!.reason, equals('empty-command'));
    });

    test('injectTimeoutOnce throws on the next call', () async {
      stub.injectTimeoutOnce();
      expect(
        () => stub.complete(text: 'add 1', verbs: {'add'}),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('injectTimeoutOnce fires exactly once', () async {
      stub.injectTimeoutOnce();
      await expectLater(
        () => stub.complete(text: 'add 1', verbs: {'add'}),
        throwsA(isA<TimeoutException>()),
      );
      final reply = await stub.complete(
        text: 'add 1',
        verbs: {'add'},
      );
      expect(reply.command, isNotNull);
    });

    test('source is preserved in the reply', () async {
      final reply = await stub.complete(
        text: 'add 42',
        verbs: {'add'},
      );
      expect(reply.command!.source, equals('add 42'));
    });

    test('confidence is carried', () async {
      final reply = await stub.complete(
        text: 'add 1',
        verbs: {'add'},
      );
      expect(reply.command!.confidence, greaterThan(0.0));
      expect(reply.command!.confidence, lessThanOrEqualTo(1.0));
    });
  });

  // ═════════════════════════════════════════════════════════════
  // 6. AiTissueCommand
  // ═════════════════════════════════════════════════════════════

  group('AiTissueCommand', () {
    late StubInterpreter stub;
    late IngressHandle<String> commandIn;

    setUp(() {
      stub = StubInterpreter(
        latency: Duration.zero,
        log: TrafficLog(silent: true),
      );
      commandIn = Cell.ingress<String>();
    });

    test('emits a TissueCommand for an accepted sentence', () async {
      final handle = AiTissueCommand<String>(
        interpreter: stub,
        verbs: {'add'},
      ).toHandle(source: commandIn.cell);

      final results = <Object?>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) => results.add(p.payload),
      );

      commandIn.emit('add 1');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(results, hasLength(1));
      expect(results.first, isA<TissueCommand>());
      final cmd = results.first as TissueCommand;
      expect(cmd.verb, equals(TissueVerb.add));
      expect(cmd.args, equals([1]));

      obs.stop();
    });

    test('emits a Reject for an unrecognised sentence', () async {
      final handle = AiTissueCommand<String>(
        interpreter: stub,
        verbs: {'add'},
      ).toHandle(source: commandIn.cell);

      final results = <Object?>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) => results.add(p.payload),
      );

      commandIn.emit('hack the nucleus');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(results, hasLength(1));
      expect(results.first, isA<Reject>());
      expect((results.first as Reject).reason, equals('no-permitted-verb'));

      obs.stop();
    });

    test('latest-wins: a second sentence supersedes the first', () async {
      final router = _RoutingInterpreter([
        (text) async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return (
            command: TissueCommand(
              verb: TissueVerb.add,
              args: [1],
              confidence: 0.9,
              source: text,
            ),
            reject: null,
          );
        },
        (text) async {
          return (
            command: TissueCommand(
              verb: TissueVerb.add,
              args: [9],
              confidence: 0.9,
              source: text,
            ),
            reject: null,
          );
        },
      ]);

      final handle = AiTissueCommand<String>(
        interpreter: router,
        verbs: {'add'},
      ).toHandle(source: commandIn.cell);

      final results = <Object?>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) => results.add(p.payload),
      );

      commandIn.emit('add 1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      commandIn.emit('add 9');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(results, hasLength(1));
      final cmd = results.first as TissueCommand;
      expect(cmd.args, equals([9]), reason: 'the second sentence must win');

      obs.stop();
    });

    test('injectTimeoutOnce is proxied to the interpreter', () async {
      final handle = AiTissueCommand<String>(
        interpreter: stub,
        verbs: {'add'},
      );
      handle.injectTimeoutOnce();

      final errors = <Object>[];
      final withError = AiTissueCommand<String>(
        interpreter: stub,
        verbs: {'add'},
        onError: (e, st) => errors.add(e),
      ).toHandle(source: commandIn.cell);

      final obs = Cell.observe(
        source: withError.cell,
        effect: (_) {},
      );

      commandIn.emit('add 1');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(errors, isNotEmpty);
      obs.stop();
    });
  });

  // ═════════════════════════════════════════════════════════════
  // 7. AiTissueCommandBatch
  // ═════════════════════════════════════════════════════════════

  group('AiTissueCommandBatch', () {
    late StubInterpreter stub;

    setUp(() {
      stub = StubInterpreter(
        latency: Duration.zero,
        log: TrafficLog(silent: true),
      );
    });

    test('emits a list of results preserving order', () async {
      final batchIn = Cell.ingress<List<String>>();
      final handle = AiTissueCommandBatch<String>(
        interpreter: stub,
        verbs: {'add', 'clear'},
      ).toHandle(source: batchIn.cell);

      final results = <Object?>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) => results.add(p.payload),
      );

      batchIn.emit(['add 1', 'add 2', 'clear', 'hack the nucleus']);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(results, hasLength(1));
      final list = results.first as List<Object>;
      expect(list, hasLength(4));
      expect(list[0], isA<TissueCommand>());
      expect((list[0] as TissueCommand).args, equals([1]));
      expect(list[1], isA<TissueCommand>());
      expect((list[1] as TissueCommand).args, equals([2]));
      expect(list[2], isA<TissueCommand>());
      expect((list[2] as TissueCommand).verb, equals(TissueVerb.clear));
      expect(list[3], isA<Reject>());

      obs.stop();
    });

    test('mixed batch with a timeout emits a Reject for the failure', () async {
      final flaky = StubInterpreter(
        latency: Duration.zero,
        log: TrafficLog(silent: true),
      );
      flaky.injectTimeoutOnce();

      final batchIn = Cell.ingress<List<String>>();
      final handle = AiTissueCommandBatch<String>(
        interpreter: flaky,
        verbs: {'add'},
        onError: (_, __) {},
      ).toHandle(source: batchIn.cell);

      final results = <Object?>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) => results.add(p.payload),
      );

      batchIn.emit(['add 7', 'add 8', 'add 9']);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final list = results.first as List<Object>;
      expect(list, hasLength(3));
      expect(list[0], isA<Reject>());
      expect((list[0] as Reject).reason, equals('interpreter-error'));
      expect(list[1], isA<TissueCommand>());
      expect((list[1] as TissueCommand).args, equals([8]));
      expect(list[2], isA<TissueCommand>());
      expect((list[2] as TissueCommand).args, equals([9]));

      obs.stop();
    });

    test('empty batch emits an empty list', () async {
      final batchIn = Cell.ingress<List<String>>();
      final handle = AiTissueCommandBatch<String>(
        interpreter: stub,
        verbs: {'add'},
      ).toHandle(source: batchIn.cell);

      final results = <Object?>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) => results.add(p.payload),
      );

      batchIn.emit(<String>[]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(results, hasLength(1));
      expect(results.first, isEmpty);

      obs.stop();
    });
  });

  // ═════════════════════════════════════════════════════════════
  // 8. AiTissueCommandWithRetry
  // ═════════════════════════════════════════════════════════════

  group('AiTissueCommandWithRetry', () {
    test('first-try success uses exactly one attempt', () async {
      var attempts = 0;
      final counting = _CountingInterpreter(
        StubInterpreter(
          latency: Duration.zero,
          log: TrafficLog(silent: true),
        ),
        onAttempt: () => attempts++,
      );

      final commandIn = Cell.ingress<String>();
      final handle = AiTissueCommandWithRetry<String>(
        interpreter: counting,
        verbs: {'add'},
        count: 3,
      ).toHandle(source: commandIn.cell);

      final results = <Object?>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) => results.add(p.payload),
      );

      commandIn.emit('add 5');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(attempts, equals(1));
      expect(results, hasLength(1));
      expect(results.first, isA<TissueCommand>());
      expect((results.first as TissueCommand).args, equals([5]));

      obs.stop();
    });

    test('success after retries uses count+1 attempts', () async {
      final flaky = StubInterpreter(
        latency: Duration.zero,
        log: TrafficLog(silent: true),
      );
      flaky.injectTimeoutOnce();
      flaky.injectTimeoutOnce();
      flaky.injectTimeoutOnce();

      var attempts = 0;
      final counting = _CountingInterpreter(
        flaky,
        onAttempt: () => attempts++,
      );

      final commandIn = Cell.ingress<String>();
      final handle = AiTissueCommandWithRetry<String>(
        interpreter: counting,
        verbs: {'add'},
        count: 5,
        onError: (_, __) {},
      ).toHandle(source: commandIn.cell);

      final results = <Object?>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) => results.add(p.payload),
      );

      commandIn.emit('add 6');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(attempts, equals(4));
      expect(results, hasLength(1));
      expect((results.first as TissueCommand).args, equals([6]));

      obs.stop();
    });

    test('retries exhausted produces a Reject', () async {
      final alwaysFails = _AlwaysFailsInterpreter();

      var attempts = 0;
      final counting = _CountingInterpreter(
        alwaysFails,
        onAttempt: () => attempts++,
      );

      final commandIn = Cell.ingress<String>();
      final handle = AiTissueCommandWithRetry<String>(
        interpreter: counting,
        verbs: {'add'},
        count: 2, // total attempts = 3
        onError: (_, __) {},
      ).toHandle(source: commandIn.cell);

      final results = <Object?>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) => results.add(p.payload),
      );

      commandIn.emit('add 7');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(attempts, equals(3));
      expect(results, hasLength(1));
      final reject = results.first as Reject;
      expect(reject.reason, startsWith('retries-exhausted:'));

      obs.stop();
    });

    test('model refusal is not retried', () async {
      var attempts = 0;
      final counting = _CountingInterpreter(
        StubInterpreter(
          latency: Duration.zero,
          log: TrafficLog(silent: true),
        ),
        onAttempt: () => attempts++,
      );

      final commandIn = Cell.ingress<String>();
      final handle = AiTissueCommandWithRetry<String>(
        interpreter: counting,
        verbs: {'add'},
        count: 5,
      ).toHandle(source: commandIn.cell);

      final results = <Object?>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) => results.add(p.payload),
      );

      commandIn.emit('hack the nucleus');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(attempts, equals(1),
          reason: 'a model refusal is a definitive answer');
      expect(results, hasLength(1));
      expect(results.first, isA<Reject>());

      obs.stop();
    });
  });

  // ═════════════════════════════════════════════════════════════
  // 9. AiTissueCommand.fromConfig
  // ═════════════════════════════════════════════════════════════

  group('AiTissueCommand.fromConfig', () {
    test('builds a live HttpInterpreter from a config', () {
      final config = AiConfig(
        endpoint: Uri.parse('https://example.invalid/v1/chat/completions'),
        apiKey: 'sk-config-key',
        model: 'config-model',
      );
      final instruction = AiTissueCommand<String>.fromConfig(
        config: config,
        verbs: {'add'},
      );
      expect(instruction.interpreter, isA<HttpInterpreter>());
      final http = instruction.interpreter as HttpInterpreter;
      expect(http.endpoint, equals(config.endpoint));
      expect(http.apiKey, equals(config.apiKey));
      expect(http.model, equals(config.model));
      expect(http.timeout, equals(config.timeout));
      expect(http.extraBody, equals(config.extraBody));
      http.close();
    });

    test('fromConfig for Batch builds a live interpreter', () {
      final config = AiConfig(
        endpoint: Uri.parse('https://example.invalid/v1/chat/completions'),
        apiKey: 'sk-config-key',
        model: 'config-model',
      );
      final instruction = AiTissueCommandBatch<String>.fromConfig(
        config: config,
        verbs: {'add'},
      );
      expect(instruction.interpreter, isA<HttpInterpreter>());
      (instruction.interpreter as HttpInterpreter).close();
    });

    test('fromConfig for Retry builds a live interpreter', () {
      final config = AiConfig(
        endpoint: Uri.parse('https://example.invalid/v1/chat/completions'),
        apiKey: 'sk-config-key',
        model: 'config-model',
      );
      final instruction = AiTissueCommandWithRetry<String>.fromConfig(
        config: config,
        verbs: {'add'},
        count: 5,
      );
      expect(instruction.interpreter, isA<HttpInterpreter>());
      (instruction.interpreter as HttpInterpreter).close();
    });

    test('fromConfig does not consult environment variables', () {
      final config = AiConfig(
        endpoint: Uri.parse('https://example.invalid/v1/chat/completions'),
        apiKey: 'sk-from-config-only',
        model: 'from-config-model',
      );
      final instruction = AiTissueCommand<String>.fromConfig(
        config: config,
        verbs: {'add'},
      );
      final http = instruction.interpreter as HttpInterpreter;
      expect(http.apiKey, equals('sk-from-config-only'));
      expect(http.model, equals('from-config-model'));
      http.close();
    });
  });

  // ═════════════════════════════════════════════════════════════
  // 10. Integration with a TissueSet
  // ═════════════════════════════════════════════════════════════

  group('Integration with TissueSet', () {
    late TissueSet<int> tags;
    late IngressHandle<String> commandIn;
    late StubInterpreter stub;

    setUp(() {
      tags = TissueSet<int>(
        const <int>[],
        testRule: TestTissue<int, TissueSet<int>>(
          (value, {host, arguments, user}) {
            if (value is int) return value >= 0;
            return true;
          },
        ),
      );
      commandIn = Cell.ingress<String>();
      stub = StubInterpreter(
        latency: Duration.zero,
        log: TrafficLog(silent: true),
      );
    });

    test('dispatch only invokes verbs in host.modifiable', () async {
      final handle = AiTissueCommand<String>(
        interpreter: stub,
        verbs: {'add', 'remove', 'clear'},
      ).toHandle(source: commandIn.cell);

      final dispatched = <TissueCommand>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) {
          final v = p.payload;
          if (v is TissueCommand) {
            final tearOff = _tearOffFor(tags, v.verb);
            if (tearOff != null && tags.modifiable.contains(tearOff)) {
              dispatched.add(v);
              switch (v.verb) {
                case TissueVerb.add:
                  tags.add(v.args.single as int);
                case TissueVerb.remove:
                  tags.remove(v.args.single as int);
                case TissueVerb.clear:
                  tags.clear();
                default:
                  break;
              }
            }
          }
        },
      );

      commandIn.emit('add 1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      commandIn.emit('add 2');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      commandIn.emit('remove 1');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(dispatched, hasLength(3));
      expect(tags.toList()..sort(), equals([2]));

      obs.stop();
    });

    test('unmodifiable deputy blocks every verb', () async {
      final auditor = tags.unmodifiable;
      final handle = AiTissueCommand<String>(
        interpreter: stub,
        verbs: {'add'},
      ).toHandle(source: commandIn.cell);

      var blocked = 0;
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) {
          final v = p.payload;
          if (v is TissueCommand) {
            final tearOff = _tearOffFor(auditor, v.verb);
            if (tearOff == null || !auditor.modifiable.contains(tearOff)) {
              blocked++;
            }
          }
        },
      );

      commandIn.emit('add 1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      commandIn.emit('add 2');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(blocked, equals(2));
      expect(auditor.toList(), isEmpty);

      obs.stop();
    });
  });

  // ═════════════════════════════════════════════════════════════
  // 11. provenance — step tags and source preservation
  // ═════════════════════════════════════════════════════════════

  group('provenance', () {
    late StubInterpreter stub;
    late IngressHandle<String> commandIn;

    setUp(() {
      stub = StubInterpreter(
        latency: Duration.zero,
        log: TrafficLog(silent: true),
      );
      commandIn = Cell.ingress<String>();
    });

    test('single sentence carries the AiTissueCommand step', () async {
      final handle = AiTissueCommand<String>(
        interpreter: stub,
        verbs: {'add'},
      ).toHandle(source: commandIn.cell);

      final pulses = <Pulse>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) => pulses.add(p),
      );

      commandIn.emit('add 3');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(pulses, hasLength(1));
      expect(pulses.first.trace, contains('AiTissueCommand'));
      expect(pulses.first.source, same(handle.cell));

      obs.stop();
    });

    test('batch carries the AiTissueCommandBatch step', () async {
      final batchIn = Cell.ingress<List<String>>();
      final handle = AiTissueCommandBatch<String>(
        interpreter: stub,
        verbs: {'add'},
      ).toHandle(source: batchIn.cell);

      final pulses = <Pulse>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) => pulses.add(p),
      );

      batchIn.emit(['add 1']);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(pulses, hasLength(1));
      expect(pulses.first.trace, contains('AiTissueCommandBatch'));
      expect(pulses.first.source, same(handle.cell));

      obs.stop();
    });

    test('retry carries the AiTissueCommandWithRetry step', () async {
      final handle = AiTissueCommandWithRetry<String>(
        interpreter: stub,
        verbs: {'add'},
      ).toHandle(source: commandIn.cell);

      final pulses = <Pulse>[];
      final obs = Cell.observe(
        source: handle.cell,
        effect: (Pulse p) => pulses.add(p),
      );

      commandIn.emit('add 4');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(pulses, hasLength(1));
      expect(pulses.first.trace, contains('AiTissueCommandWithRetry'));
      expect(pulses.first.source, same(handle.cell));

      obs.stop();
    });
  });
}

// ─────────────────────────────────────────────────────────────
// Test-only interpreters and helpers
// ─────────────────────────────────────────────────────────────

/// A routing interpreter that dispatches the n-th `complete` call to
/// the n-th handler. Used to exercise the latest-wins generation guard.
class _RoutingInterpreter implements Interpreter {
  final List<Future<InterpreterReply> Function(String text)> _handlers;
  var _calls = 0;

  _RoutingInterpreter(this._handlers);

  @override
  String get transport => 'routing';

  @override
  void injectTimeoutOnce() {}

  @override
  Future<InterpreterReply> complete({
    required String text,
    required Set<String> verbs,
  }) {
    final index = _calls < _handlers.length ? _calls : _handlers.length - 1;
    _calls++;
    return _handlers[index](text);
  }
}

/// Wraps an interpreter so each `complete` call increments a counter.
class _CountingInterpreter implements Interpreter {
  final Interpreter _inner;
  final void Function() onAttempt;

  _CountingInterpreter(this._inner, {required this.onAttempt});

  @override
  String get transport => _inner.transport;

  @override
  void injectTimeoutOnce() => _inner.injectTimeoutOnce();

  @override
  Future<InterpreterReply> complete({
    required String text,
    required Set<String> verbs,
  }) {
    onAttempt();
    return _inner.complete(text: text, verbs: verbs);
  }
}

/// An interpreter that throws on every call. Used to exercise the
/// retries-exhausted path.
class _AlwaysFailsInterpreter implements Interpreter {
  @override
  String get transport => 'stub';

  @override
  void injectTimeoutOnce() {}

  @override
  Future<InterpreterReply> complete({
    required String text,
    required Set<String> verbs,
  }) {
    return Future<InterpreterReply>.error(StateError('permanent failure'));
  }
}

/// Maps a [TissueVerb] to the matching tear-off on a [TissueSet].
Function? _tearOffFor(TissueSet<int> set, TissueVerb verb) {
  switch (verb) {
    case TissueVerb.add:
      return set.add;
    case TissueVerb.addAll:
      return set.addAll;
    case TissueVerb.remove:
      return set.remove;
    case TissueVerb.removeAll:
      return set.removeAll;
    case TissueVerb.clear:
      return set.clear;
    case TissueVerb.retainAll:
      return set.retainAll;
    case TissueVerb.removeWhere:
      return set.removeWhere;
    case TissueVerb.retainWhere:
      return set.retainWhere;
  }
}
