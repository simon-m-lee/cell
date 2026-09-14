// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_tissue_command_domain.dart';

/// Reads a UTF-8 JSON file synchronously.
///
/// IO-only helper backing [AiConfig.fromJsonFile]. Not available on web.
String readJsonFileSync(String path) => File(path).readAsStringSync();

/// The platform environment map (IO implementation).
///
/// IO-only helper backing the demo's '--live' mode. Not available on web.
Map<String, String> get platformEnvironment => Platform.environment;

// ─────────────────────────────────────────────────────────────
// Live HTTP Interpreter
// ─────────────────────────────────────────────────────────────

/// A live interpreter that POSTs the sentence to an
/// OpenAI-compatible chat-completions endpoint and parses the JSON
/// reply.
///
/// ### When to use
///
/// Pass an instance of this to the harness when running with
/// `--live`. Without an API key or endpoint, use [StubInterpreter].
///
/// ### How it works
///
/// 1. Builds the system prompt from [verbs].
/// 2. Logs the prompt via [TrafficLog.systemPrompt].
/// 3. Builds the OpenAI-compatible request body (merging
///    [extraBody] first, so the interpreter's keys win on
///    collision).
/// 4. Logs the request via [TrafficLog.request].
/// 5. Checks [injectTimeoutOnce] — if set, throws before the HTTP
///    call (so scenario 10 stays deterministic).
/// 6. POSTs the body to [endpoint] with the bearer token.
/// 7. Reads the response body.
/// 8. Logs the response via [TrafficLog.response].
/// 9. Parses the body into an [InterpreterReply].
/// 10. Logs the parse via [TrafficLog.parsed] or
///     [TrafficLog.refused].
/// 11. Returns the reply.
///
/// ### No Environment Fallback
///
/// Every value the interpreter uses comes from its constructor
/// arguments. It does not consult `Platform.environment`. If you
/// want to derive the arguments from env vars, do so before
/// constructing the interpreter (see [AiConfig]).
///
/// ### Non-obvious
///
/// - **The interpreter never lets the model influence the set
///   directly.** It only produces a [TissueCommand] whose `verb`
///   must be a key in [verbByName]. The dispatch instruction
///   (downstream) still checks `host.modifiable` and TestTissue
///   still guards the element.
/// - **The HTTP client is injected.** A caller that wants to reuse
///   an existing client can pass one in; the caller is then
///   responsible for closing it. The demo passes none, so the
///   interpreter creates its own and closes it in `dispose`.
/// - **The timeout applies twice.** It is applied to both the
///   connection establishment and the response body read. A slow
///   endpoint that returns headers quickly but body slowly will
///   still hit this timeout.
/// - **`response_format` requests JSON.** The
///   `{'type': 'json_object'}` value tells OpenAI-compatible
///   endpoints to constrain the model to valid JSON. Not all
///   endpoints honour it; the parser handles either case.
///
/// ### Example
///
/// ```dart
/// final interpreter = HttpInterpreter(
///   endpoint: Uri.parse(Platform.environment['AI_ENDPOINT']!),
///   apiKey: Platform.environment['AI_API_KEY']!,
///   model: Platform.environment['AI_MODEL'] ?? 'gpt-4o-mini',
/// );
///
/// final reply = await interpreter.complete(
///   text: 'add 3',
///   verbs: {'add', 'remove', 'clear'},
/// );
///
/// interpreter.close();
/// ```
///
/// ### See Also
///
/// - [StubInterpreter] — the deterministic offline implementation.
/// - [Interpreter] — the port contract.
/// - [AiConfig] — JSON-file configuration for this interpreter.
/// - [systemPrompt] — the prompt builder.
/// - [TrafficLog] — the traffic logger.
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
  ///
  /// Applied to both the connection establishment and the response
  /// body read. A slow endpoint that returns headers quickly but
  /// body slowly will still hit this timeout.
  final Duration timeout;

  /// The traffic logger. Every request and response passes through
  /// it so the reader can see the full exchange.
  final TrafficLog log;

  /// Optional extra fields merged into the request envelope.
  ///
  /// Keys in this map are added to the JSON body sent to the
  /// endpoint. They cannot override the four keys the interpreter
  /// sets (`model`, `messages`, `temperature`, `response_format`)
  /// because the interpreter's keys are written after the merge.
  final Map<String, dynamic> extraBody;

  int _pendingTimeouts = 0;

  /// Creates an [HttpInterpreter].
  ///
  /// ### Parameters
  ///
  /// - [endpoint]: **Required.** The full URL of the OpenAI-compatible
  ///   chat-completions endpoint.
  /// - [apiKey]: **Required.** The bearer token.
  /// - [model]: **Required.** The model identifier.
  /// - [client]: **Optional.** The HTTP client. If omitted, a fresh
  ///   client is created and the caller must call [close] on the
  ///   interpreter.
  /// - [timeout]: **Optional.** Per-request timeout. Defaults to
  ///   30 seconds.
  /// - [log]: **Optional.** The traffic logger. If omitted, a fresh
  ///   non-silent logger is created.
  /// - [extraBody]: **Optional.** Extra fields merged into the
  ///   request envelope. Defaults to `{}`.
  HttpInterpreter({
    required this.endpoint,
    required this.apiKey,
    required this.model,
    HttpClient? client,
    this.timeout = const Duration(seconds: 30),
    TrafficLog? log,
    this.extraBody = const {},
  })  : client = client ?? HttpClient(),
        log = log ?? TrafficLog();

  @override
  String get transport => 'http';

  /// Injects a one-shot timeout: the next `complete` call will
  /// throw a [TimeoutException] **before** the HTTP request is
  /// made. This keeps scenario 10 deterministic in live mode.
  @override
  void injectTimeoutOnce() {
    _pendingTimeouts++;
  }

  @override
  Future<InterpreterReply> complete({
    required String text,
    required Set<String> verbs,
  }) async {
    final prompt = systemPrompt(verbs);

    log.systemPrompt(prompt);

    final body = jsonEncode({
      // extraBody is merged first so the interpreter's keys win if
      // they collide. That is the same policy AiConfig.fromJson
      // documents.
      ...extraBody,
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
    if (_pendingTimeouts > 0) {
      _pendingTimeouts--;
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
  ///
  /// ### Why two envelopes
  ///
  /// The OpenAI shape is the standard. Some self-hosted endpoints
  /// (and some proxies) skip the envelope and return the verb
  /// object directly. Supporting both lets the demo point at
  /// either without a config flag.
  ///
  /// ### Failure modes
  ///
  /// Every failure mode returns a [Reject] rather than throwing.
  /// That keeps the port's contract simple: exceptions are for
  /// transport failures, Rejects are for parse failures.
  ///
  /// ### Parameters
  ///
  /// - [raw]: **The Raw Body.** The full HTTP response body.
  /// - [source]: **The Original Sentence.** Carried into the
  ///   Reject so the caller can reconstruct which sentence failed.
  ///
  /// ### Returns
  ///
  /// An [InterpreterReply] — either a [TissueCommand] or a
  /// [Reject].
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
  ///
  /// Call this when the interpreter is no longer needed. The demo
  /// calls it from `NlTissueHarness.dispose`.
  void close() => client.close(force: true);
}
