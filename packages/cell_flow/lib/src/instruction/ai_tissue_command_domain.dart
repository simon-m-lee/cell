// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ─────────────────────────────────────────────────────────────
// AI TISSUE COMMAND — DOMAIN
//
// Domain types shared by the AI-assisted tissue-command pipeline.
//
// This file is the *single source of truth* for:
//   • the closed verb list (TissueVerb + verbByName)
//   • the two reply shapes (TissueCommand / Reject)
//   • the interpreter port (Interpreter)
//   • the two interpreters (HttpInterpreter / StubInterpreter)
//   • the traffic logger (TrafficLog)
//   • the system prompt builder (systemPrompt)
//
// The instruction file (`ai_tissue_command.dart`) imports this
// file and does not redefine any of these types.
//
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// CLOSED VERB LIST
// ─────────────────────────────────────────────────────────────

/// The closed list of verbs the interpreter may return.
///
/// Every value maps to a tear-off on `TissueSet.modifiable`. The
/// dispatch instruction consults this enum to look up the tear-off
/// before invoking it.
///
/// ### Why an enum, not a String
/// The interpreter returns a *string* verb name (JSON has no enums).
/// The pipeline immediately converts that string into a `TissueVerb`
/// via [verbByName]. A verb that does not resolve is treated as a
/// Reject, not as an executable command.
enum TissueVerb {
  /// `TissueSet.add(E)` — insert one element.
  add,

  /// `TissueSet.addAll(Iterable<E>)` — insert many elements.
  addAll,

  /// `TissueSet.remove(Object?)` — remove one element.
  remove,

  /// `TissueSet.removeAll(Iterable<Object?>)` — remove many elements.
  removeAll,

  /// `TissueSet.clear()` — remove every element.
  clear,

  /// `TissueSet.retainAll(Iterable<Object?>)` — keep only the named
  /// elements.
  retainAll,

  /// `TissueSet.removeWhere(bool Function(E))` — not driven by this
  /// demo (predicates are not safe to take from a model).
  removeWhere,

  /// `TissueSet.retainWhere(bool Function(E))` — not driven by this
  /// demo.
  retainWhere,
}

/// Lookup table from a verb string to the enum value.
///
/// The HTTP interpreter only returns one of the strings in this
/// map; anything else is treated as a Reject. This is the boundary
/// that prevents "the model invents a verb".
const Map<String, TissueVerb> verbByName = {
  'add': TissueVerb.add,
  'addAll': TissueVerb.addAll,
  'remove': TissueVerb.remove,
  'removeAll': TissueVerb.removeAll,
  'clear': TissueVerb.clear,
  'retainAll': TissueVerb.retainAll,
  'removeWhere': TissueVerb.removeWhere,
  'retainWhere': TissueVerb.retainWhere,
};

// ─────────────────────────────────────────────────────────────
// REPLY SHAPES
// ─────────────────────────────────────────────────────────────

/// A successfully interpreted command.
///
/// The [verb] is one of the closed [TissueVerb] values. The [args]
/// list carries the positional arguments the tear-off will receive.
/// The [confidence] is the interpreter's own reliability estimate
/// (0.0–1.0) and is carried for auditing only — the demo does not
/// gate on it.
final class TissueCommand {
  /// The verb the interpreter believes the sentence names.
  final TissueVerb verb;

  /// The positional arguments for the verb's tear-off.
  final List<Object?> args;

  /// The interpreter's reliability estimate (0.0–1.0).
  final double confidence;

  /// The original sentence, carried for the audit trail.
  final String source;

  const TissueCommand({
    required this.verb,
    required this.args,
    required this.confidence,
    required this.source,
  });

  /// A successful command is always [ok].
  bool get ok => true;

  @override
  String toString() =>
      'TissueCommand(${verb.name}, args=$args, conf=$confidence)';
}

/// An interpreter refusal.
///
/// The interpreter returns a [Reject] when the sentence does not
/// name any verb on the closed list, or when the interpreter itself
/// cannot produce a structured reply. The Filter before dispatch
/// drops `Reject` pulses.
final class Reject {
  /// The original sentence.
  final String source;

  /// A human-readable reason.
  final String reason;

  const Reject({required this.source, required this.reason});

  /// A [Reject] is never [ok].
  bool get ok => false;

  @override
  String toString() => 'Reject("$source", reason=$reason)';
}

/// The reply from the interpreter port.
///
/// A `InterpreterReply` is either a [TissueCommand] (success) or a
/// [Reject] (failure). The port never returns raw Dart, only these
/// two shapes.
typedef InterpreterReply = ({TissueCommand? command, Reject? reject});

// ─────────────────────────────────────────────────────────────
// INTERPRETER PORT
// ─────────────────────────────────────────────────────────────

/// The interpreter port — the seam between the NL sentence and the
/// closed verb list.
///
/// A live implementation would call OpenAI / DeepSeek / a browser
/// chatbot and parse its JSON reply. The demo ships a stub table
/// that stands in for the live client. The dispatch Instruction
/// never sees either — it only sees the [TissueCommand] the port
/// produces.
abstract interface class Interpreter {
  /// Ask the interpreter what verb (if any) the [text] names.
  ///
  /// [verbs] is the closed allow-list of verb strings derived from
  /// `TissueSet.modifiable`. The interpreter must not return a verb
  /// outside this list.
  Future<InterpreterReply> complete({
    required String text,
    required Set<String> verbs,
  });

  /// A short label describing the transport ("http" or "stub").
  String get transport;

  /// When called, the NEXT `complete` call throws once.
  ///
  /// Implemented by both HTTP and stub interpreters so scenario 10
  /// behaves identically in offline and live modes.
  void injectTimeoutOnce();
}

// ─────────────────────────────────────────────────────────────
// TRAFFIC LOGGER
// ─────────────────────────────────────────────────────────────

/// Prints HTTP request/response traffic in a human-readable form.
///
/// The logger is **not const** because it holds a small mutable flag
/// (`_promptPrintedOnce`). The first call to [systemPrompt] prints
/// the prompt in full; later calls truncate it, so the console
/// remains readable while still showing the entire security
/// contract at least once.
class TrafficLog {
  /// When `true`, the logger suppresses output. Useful when running
  /// tests or when the caller wants only the parsed result.
  final bool silent;

  bool _promptPrintedOnce = false;

  TrafficLog({this.silent = false});

  void _out(String line) {
    if (!silent) print(line);
  }

  /// Prints the system prompt that will be sent.
  ///
  /// The first call prints the prompt in full; later calls truncate
  /// to the first 12 lines and note how many are hidden.
  void systemPrompt(String prompt) {
    _out('    ┌─ SYSTEM PROMPT ────────────────────────────────────────');

    final lines = prompt.split('\n');

    final List<String> show;
    final int hidden;
    if (!_promptPrintedOnce) {
      show = lines;
      hidden = 0;
      _promptPrintedOnce = true;
    } else if (lines.length > 12) {
      show = lines.sublist(0, 12);
      hidden = lines.length - 12;
    } else {
      show = lines;
      hidden = 0;
    }

    for (final l in show) {
      _out('    │ $l');
    }
    if (hidden > 0) {
      _out('    │ ... ($hidden more lines — same prompt as scenario 1)');
    }
    _out('    └────────────────────────────────────────────────────────');
  }

  /// Prints the HTTP request envelope.
  void request({
    required String endpoint,
    required String model,
    required String sentence,
    required String body,
  }) {
    _out('    ┌─ REQUEST ──────────────────────────────────────────────');
    _out('    │ POST $endpoint');
    _out('    │ model: $model');
    _out('    │ user: "$sentence"');
    _out('    │ body:');
    for (final l in const LineSplitter().convert(body)) {
      _out('    │   $l');
    }
    _out('    └────────────────────────────────────────────────────────');
  }

  /// Prints the HTTP response status and body.
  void response({
    required int status,
    required String body,
  }) {
    _out('    ┌─ RESPONSE ─────────────────────────────────────────────');
    _out('    │ HTTP $status');
    _out('    │ body:');
    for (final l in const LineSplitter().convert(body)) {
      _out('    │   $l');
    }
    _out('    └────────────────────────────────────────────────────────');
  }

  /// Prints the parsed verb, args, and confidence.
  void parsed(TissueCommand cmd) {
    _out('    ┌─ PARSED ───────────────────────────────────────────────');
    _out('    │ verb: ${cmd.verb.name}');
    _out('    │ args: ${cmd.args}');
    _out('    │ confidence: ${cmd.confidence}');
    _out('    └────────────────────────────────────────────────────────');
  }

  /// Prints a rejection reason.
  void refused(String reason) {
    _out('    ┌─ REFUSED ──────────────────────────────────────────────');
    _out('    │ reason: $reason');
    _out('    └────────────────────────────────────────────────────────');
  }

  /// Prints an exception from the interpreter or its parser.
  void error(Object e) {
    _out('    ┌─ ERROR ────────────────────────────────────────────────');
    _out('    │ $e');
    _out('    └────────────────────────────────────────────────────────');
  }
}

// ─────────────────────────────────────────────────────────────
// AI PROMPT
// ─────────────────────────────────────────────────────────────

/// Builds the system prompt sent to the live AI chatbot.
///
/// The prompt establishes the closed verb list and the JSON reply
/// shape. The instruction does not trust the model beyond parsing
/// this shape; an unrecognized verb is discarded.
String systemPrompt(Set<String> verbs) {
  final sorted = verbs.toList()..sort();
  return '''
You are a verb interpreter for a reactive set container.

The operator will write a natural-language sentence. Your job is to
choose exactly one verb from the closed list below and produce the
positional arguments for that verb.

Closed verb list:
${sorted.map((v) => '  - $v').join('\n')}

Reply ONLY with a JSON object matching one of these two shapes:

  {"verb":"<name>","args":[...],"confidence":<0.0..1.0>}
  {"verb":"reject","reason":"<short reason>"}

Rules:
- "verb" MUST be one of the closed list, or the literal "reject".
- "args" MUST be a JSON array (may be empty).
- For single-element verbs (add, remove), "args" is a 1-element array.
- For multi-element verbs (addAll, removeAll, retainAll), "args" is a
  1-element array whose element is a JSON array of values.
- For zero-arg verbs (clear), "args" is [].
- Never invent a verb, never return code, never return prose.
- If you cannot choose a verb, return {"verb":"reject","reason":"..."}.
''';
}

// ─────────────────────────────────────────────────────────────
// LIVE HTTP INTERPRETER
// ─────────────────────────────────────────────────────────────

/// A live interpreter that POSTs the sentence to an
/// OpenAI-compatible chat-completions endpoint and parses the JSON
/// reply.
///
/// ### When to use
/// Pass an instance of this to the harness when running with
/// `--live`. Without an API key or endpoint, use [StubInterpreter].
///
/// ### Non-obvious
/// The interpreter never lets the model influence the set directly.
/// It only produces a [TissueCommand] whose `verb` must be a key in
/// [verbByName]. The dispatch Instruction (downstream) still checks
/// `host.modifiable` and TestTissue still guards the element.
class HttpInterpreter implements Interpreter {
  /// The chat-completions endpoint.
  final Uri endpoint;

  /// The bearer token.
  final String apiKey;

  /// The model identifier.
  final String model;

  /// The HTTP client (injected so the caller can close it).
  final HttpClient client;

  /// Per-request timeout.
  final Duration timeout;

  /// The traffic logger. Every request and response passes through
  /// it so the reader can see the full exchange.
  final TrafficLog log;

  bool _forceTimeoutOnce = false;

  HttpInterpreter({
    required this.endpoint,
    required this.apiKey,
    required this.model,
    HttpClient? client,
    this.timeout = const Duration(seconds: 30),
    TrafficLog? log,
  })  : client = client ?? HttpClient(),
        log = log ?? TrafficLog();

  @override
  String get transport => 'http';

  /// Injects a one-shot timeout: the next `complete` call will
  /// throw a [TimeoutException] **before** the HTTP request is
  /// made. This keeps scenario 10 deterministic in live mode.
  @override
  void injectTimeoutOnce() {
    _forceTimeoutOnce = true;
  }

  @override
  Future<InterpreterReply> complete({
    required String text,
    required Set<String> verbs,
  }) async {
    final prompt = systemPrompt(verbs);

    log.systemPrompt(prompt);

    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': prompt},
        {'role': 'user', 'content': text},
      ],
      'temperature': 0,
      'response_format': {'type': 'json_object'},
    });

    log.request(
      endpoint: endpoint.toString(),
      model: model,
      sentence: text,
      body: body,
    );

    // Simulated transport failure for scenario 10.
    if (_forceTimeoutOnce) {
      _forceTimeoutOnce = false;
      throw TimeoutException(
        'injected timeout (scenario 10)',
        Duration.zero,
      );
    }

    final request = await client.postUrl(endpoint);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
      ..set(HttpHeaders.contentTypeHeader, 'application/json')
      ..set(HttpHeaders.acceptHeader, 'application/json');
    request.add(utf8.encode(body));

    final response = await request.close().timeout(timeout);
    final replyBody =
    await response.transform(utf8.decoder).join().timeout(timeout);

    log.response(status: response.statusCode, body: replyBody);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'AI endpoint returned ${response.statusCode}: $replyBody',
      );
    }

    final reply = _parse(replyBody, source: text);
    if (reply.command != null) {
      log.parsed(reply.command!);
    } else if (reply.reject != null) {
      log.refused(reply.reject!.reason);
    }
    return reply;
  }

  /// Parses the raw HTTP reply into an [InterpreterReply].
  ///
  /// Accepts the OpenAI-compatible envelope
  /// `{"choices":[{"message":{"content":"..."}}]}` where `content`
  /// is itself a JSON string carrying the verb object. Also
  /// accepts a bare `{"verb": ...}` object for simpler endpoints.
  InterpreterReply _parse(String raw, {required String source}) {
    try {
      final outer = jsonDecode(raw);
      String? contentString;

      if (outer is Map && outer['choices'] is List) {
        final choices = outer['choices'] as List;
        if (choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map && first['message'] is Map) {
            final msg = first['message'] as Map;
            final c = msg['content'];
            if (c is String) contentString = c;
          }
        }
      } else if (outer is Map && outer['verb'] is String) {
        contentString = raw;
      }

      if (contentString == null) {
        return (
        command: null,
        reject: Reject(source: source, reason: 'unexpected-envelope'),
        );
      }

      final inner = jsonDecode(contentString);
      if (inner is! Map) {
        return (
        command: null,
        reject: Reject(source: source, reason: 'content-not-object'),
        );
      }

      final verbString = inner['verb'];
      if (verbString is! String) {
        return (
        command: null,
        reject: Reject(source: source, reason: 'missing-verb'),
        );
      }

      if (verbString == 'reject') {
        final reason = inner['reason'];
        return (
        command: null,
        reject: Reject(
          source: source,
          reason: reason is String ? reason : 'rejected-by-model',
        ),
        );
      }

      final verb = verbByName[verbString];
      if (verb == null) {
        return (
        command: null,
        reject: Reject(source: source, reason: 'unknown-verb'),
        );
      }

      final argsRaw = inner['args'];
      final args = argsRaw is List ? argsRaw : const <Object?>[];

      final confRaw = inner['confidence'];
      final confidence = confRaw is num ? confRaw.toDouble() : 0.5;

      return (
      command: TissueCommand(
        verb: verb,
        args: args,
        confidence: confidence,
        source: source,
      ),
      reject: null,
      );
    } catch (e) {
      return (
      command: null,
      reject: Reject(source: source, reason: 'parse-error:$e'),
      );
    }
  }

  /// Closes the underlying HTTP client.
  void close() => client.close(force: true);
}

// ─────────────────────────────────────────────────────────────
// OFFLINE STUB INTERPRETER
// ─────────────────────────────────────────────────────────────

/// A deterministic offline interpreter that simulates the HTTP
/// traffic a live chatbot would produce.
///
/// ### Why it prints traffic
/// The offline path exists so the demo runs without a key. But the
/// reader still needs to see what a live interaction would look
/// like. This stub prints a synthetic request body and a synthetic
/// response body in the same shape the HTTP interpreter would
/// produce, so the console output is identical in structure
/// whether the demo is running offline or live.
class StubInterpreter implements Interpreter {
  bool _failOnce = false;
  bool _hasFailed = false;

  /// Artificial latency (per call).
  Duration latency;

  /// The traffic logger.
  final TrafficLog log;

  /// A fake endpoint label shown in the synthetic request line.
  final String syntheticEndpoint;

  /// A fake model name shown in the synthetic request body.
  final String syntheticModel;

  StubInterpreter({
    this.latency = const Duration(milliseconds: 1),
    TrafficLog? log,
    this.syntheticEndpoint = 'stub://offline/chat/completions',
    this.syntheticModel = 'stub-model',
  }) : log = log ?? TrafficLog();

  @override
  String get transport => 'stub';

  @override
  void injectTimeoutOnce() {
    _failOnce = true;
  }

  @override
  Future<InterpreterReply> complete({
    required String text,
    required Set<String> verbs,
  }) async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }

    if (_failOnce && !_hasFailed) {
      _hasFailed = true;
      final prompt = systemPrompt(verbs);
      log.systemPrompt(prompt);
      final body = jsonEncode({
        'model': syntheticModel,
        'messages': [
          {'role': 'system', 'content': prompt},
          {'role': 'user', 'content': text},
        ],
        'temperature': 0,
        'response_format': {'type': 'json_object'},
      });
      log.request(
        endpoint: syntheticEndpoint,
        model: syntheticModel,
        sentence: text,
        body: body,
      );
      throw TimeoutException(
        'injected timeout (scenario 10)',
        Duration.zero,
      );
    }

    final prompt = systemPrompt(verbs);
    log.systemPrompt(prompt);

    final body = jsonEncode({
      'model': syntheticModel,
      'messages': [
        {'role': 'system', 'content': prompt},
        {'role': 'user', 'content': text},
      ],
      'temperature': 0,
      'response_format': {'type': 'json_object'},
    });

    log.request(
      endpoint: syntheticEndpoint,
      model: syntheticModel,
      sentence: text,
      body: body,
    );

    final reply = _classify(text, verbs);

    final responseBody = jsonEncode({
      'id': 'stub-chatcmpl-${DateTime.now().microsecondsSinceEpoch}',
      'object': 'chat.completion',
      'model': syntheticModel,
      'choices': [
        {
          'index': 0,
          'message': {
            'role': 'assistant',
            'content': reply,
          },
          'finish_reason': 'stop',
        }
      ],
      'usage': {
        'prompt_tokens': prompt.length ~/ 4,
        'completion_tokens': reply.length ~/ 4,
        'total_tokens': (prompt.length + reply.length) ~/ 4,
      },
    });

    log.response(status: 200, body: responseBody);

    final parsed = _parseEnvelope(responseBody, source: text);
    if (parsed.command != null) {
      log.parsed(parsed.command!);
    } else if (parsed.reject != null) {
      log.refused(parsed.reject!.reason);
    }
    return parsed;
  }

  /// Classifies the sentence into a JSON reply string. Mirrors the
  /// shape a live chatbot would return.
  String _classify(String text, Set<String> verbs) {
    final n = text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

    if (n.isEmpty) {
      return jsonEncode({'verb': 'reject', 'reason': 'empty-command'});
    }

    final addAllMatch = RegExp(r'^addall(?: (.*))?$').firstMatch(n);
    if (addAllMatch != null && verbs.contains('addAll')) {
      final rest = addAllMatch.group(1) ?? '';
      final nums = rest
          .split(' ')
          .where((s) => s.isNotEmpty)
          .map(int.tryParse)
          .whereType<int>()
          .toList();
      if (nums.isNotEmpty) {
        return jsonEncode({
          'verb': 'addAll',
          'args': [nums],
          'confidence': 0.9,
        });
      }
    }

    final addMatch =
    RegExp(r'^(?:please )?(?:add|insert) (-?\d+)(?: .*)?$').firstMatch(n);
    if (addMatch != null && verbs.contains('add')) {
      return jsonEncode({
        'verb': 'add',
        'args': [int.parse(addMatch.group(1)!)],
        'confidence': 0.92,
      });
    }

    final removeMatch =
    RegExp(r'^(?:please )?(?:remove|delete) (-?\d+)(?: .*)?$')
        .firstMatch(n);
    if (removeMatch != null && verbs.contains('remove')) {
      return jsonEncode({
        'verb': 'remove',
        'args': [int.parse(removeMatch.group(1)!)],
        'confidence': 0.92,
      });
    }

    if (RegExp(r'^(?:please )?(?:clear|delete everything|empty)(?: .*)?$')
        .hasMatch(n) &&
        verbs.contains('clear')) {
      return jsonEncode({
        'verb': 'clear',
        'args': [],
        'confidence': 0.95,
      });
    }

    return jsonEncode({
      'verb': 'reject',
      'reason': 'no-permitted-verb',
    });
  }

  /// Parses the OpenAI-shaped envelope the stub produces.
  InterpreterReply _parseEnvelope(String raw, {required String source}) {
    try {
      final outer = jsonDecode(raw) as Map;
      final choices = outer['choices'] as List;
      final content =
      (choices.first as Map)['message']['content'] as String;
      final inner = jsonDecode(content) as Map;
      final verbString = inner['verb'] as String;

      if (verbString == 'reject') {
        return (
        command: null,
        reject: Reject(
          source: source,
          reason: inner['reason'] as String? ?? 'rejected-by-model',
        ),
        );
      }

      final verb = verbByName[verbString];
      if (verb == null) {
        return (
        command: null,
        reject: Reject(source: source, reason: 'unknown-verb'),
        );
      }

      final args = (inner['args'] as List?) ?? const <Object?>[];
      final confidence =
          (inner['confidence'] as num?)?.toDouble() ?? 0.5;

      return (
      command: TissueCommand(
        verb: verb,
        args: args,
        confidence: confidence,
        source: source,
      ),
      reject: null,
      );
    } catch (e) {
      return (
      command: null,
      reject: Reject(source: source, reason: 'parse-error:$e'),
      );
    }
  }
}