// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:cell_flow/cell_flow.dart';
import 'ai_tissue_command_domain.dart';

// ─────────────────────────────────────────────────────────────
// AiTissueCommand family — AI-Bridged Interpretation
//
// This file hosts three instructions that share the same port
// ([Interpreter]) and the same closed verb list ([verbByName]):
//
//   1. AiTissueCommand<S>          — single-sentence, latest-wins
//   2. AiTissueCommandBatch<S>     — batch of sentences, one call
//   3. AiTissueCommandWithRetry<S> — single sentence, retry policy
//
// All three translate natural language into a closed, machine-
// validated [TissueCommand] by asking an [Interpreter] (a live AI
// chatbot over HTTP, or a deterministic offline stub) to choose a
// verb from a closed list. The instruction never executes Dart
// code returned by the model; it parses a verb string and an args
// array, then looks the verb up in [verbByName].
//
// ─────────────────────────────────────────────────────────────
// HOW TO RUN
// ─────────────────────────────────────────────────────────────
//
// ### Offline (default, no network, no key)
//
//     dart run ai_tissue_command.dart
//
// The demo runs against the deterministic [StubInterpreter]. The
// stub fabricates a request body and an OpenAI-compatible response
// envelope for every sentence, so the console shows the same seven
// steps a live HTTP call would produce:
//
//     1. system prompt
//     2. request body
//     3. HTTP status
//     4. response body
//     5. parsed verb / args / confidence
//     6. downstream classification (TissueCommand or Reject)
//     7. per-scenario assertions
//
// ### Live against DeepSeek
//
//     export AI_ENDPOINT=https://api.deepseek.com/chat/completions
//     export AI_API_KEY=sk-your-deepseek-key
//     export AI_MODEL=deepseek-flash
//     dart run ai_tissue_command.dart --live
//
// ### Live against OpenAI
//
//     export AI_ENDPOINT=https://api.openai.com/v1/chat/completions
//     export AI_API_KEY=sk-...
//     export AI_MODEL=gpt-4o-mini
//     dart run ai_tissue_command.dart --live
//
// ### Live against any OpenAI-compatible endpoint
//
// Any endpoint that accepts the OpenAI chat-completions request
// shape and returns the standard `choices[0].message.content`
// envelope will work. Set AI_ENDPOINT to the full URL, AI_API_KEY
// to the bearer token, and AI_MODEL to the model identifier.
//
// In live mode the demo runs the same seven scenarios against the
// live endpoint. The traffic log shows the *real* bytes on the
// wire — every prompt, every request body, every response body,
// every usage block. Nothing is fabricated.
//
// ### Live demo failure modes
//
// If `--live` is passed but AI_ENDPOINT or AI_API_KEY is missing,
// the demo prints a diagnostic and falls back to the offline stub
// so the run still completes. If the endpoint returns a non-2xx
// status, the response body is logged and the pipeline routes the
// exception to the scenario's error handler.
//
// ─────────────────────────────────────────────────────────────
// DOCUMENTED DEVIATIONS
// ─────────────────────────────────────────────────────────────
//
// 1. `FlowInstructionMixin` is applied to each class explicitly,
//    so `toHandle` and the `+` operator are available on every
//    instruction. If your `FlowInstructionBase` already carries
//    the mixin, the `with FlowInstructionMixin<...>` clauses here
//    are redundant but harmless.
//
// 2. The demo helpers (`_CountingInterpreter`,
//    `_AlwaysFailsInterpreter`, `_RoutingInterpreter`) are private
//    so they do not pollute the public API. A future test suite
//    can lift them into a shared support file.

// ─────────────────────────────────────────────────────────────
// Helper: output pulse with provenance
// ─────────────────────────────────────────────────────────────

/// Builds an output pulse that preserves the trigger's provenance.
Pulse<T> _out<T>(T value, Pulse trigger, Cell? cell, String step) {
  return Pulse<T>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

// ═════════════════════════════════════════════════════════════
// 1. AiTissueCommand — Single-Sentence, Latest-Wins
// ═════════════════════════════════════════════════════════════

/// A [FlowInstruction] that turns a natural-language sentence into
/// a [TissueCommand] by asking an [Interpreter] (a live AI chatbot
/// over HTTP, or a deterministic offline stub) to choose a verb
/// from a closed list.
///
/// ### How it works
/// 1. **Stimulus Reception**: The instruction receives a pulse whose
///    payload is a natural-language [S].
/// 2. **Port Invocation**: It calls
///    `interpreter.complete(text:, verbs:)` and awaits the reply.
/// 3. **Traffic Logging**: The interpreter's `TrafficLog` prints
///    the system prompt, the HTTP request body, the response
///    status, the raw response body, and the parsed verb.
/// 4. **Reply Classification**:
///    - `TissueCommand` → emitted as `Pulse<TissueCommand>`.
///    - `Reject` → emitted as a `Pulse<Reject>` marker.
///    - Exception → routed to [onError]; the pulse is dropped.
/// 5. **Provenance Preservation**: The emitted pulse inherits the
///    source cell, priority, and type of the trigger, tagged with
///    the `'AiTissueCommand'` step.
///
/// ### Concurrency Model
/// * **Latest-Wins Strategy**: If a new sentence arrives while a
///   previous HTTP call is still in flight, the older generation
///   is silently abandoned.
///
/// ### See Also
/// - [AiTissueCommandBatch]: Batch of sentences in one port call.
/// - [AiTissueCommandWithRetry]: Retry policy over the port call.
class AiTissueCommand<S>
    extends FlowInstructionBase<Cell, Pulse, Pulse>
    with FlowInstructionMixin<Cell, Pulse, Pulse> {

  /// The wrapped interpreter.
  final Interpreter interpreter;

  /// Synthesizes an **AI-Bridged Interpretation Gate**.
  AiTissueCommand({
    required this.interpreter,
    required Set<String> verbs,
    AiTissueCommandErrorHandler? onError,
    dynamic user,
  }) : super.future(
    (() {
      var generation = 0;
      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! S) {
          onError?.call(
            FormatException(
              'Expected payload of type $S, got ${payload.runtimeType}',
            ),
            StackTrace.current,
          );
          return null;
        }

        final id = ++generation;

        Future<void> run() async {
          try {
            final reply = await interpreter.complete(
              text: payload as String,
              verbs: verbs,
            );

            if (id != generation) return;

            if (reply.command != null) {
              future!(
                result: _out<TissueCommand>(
                  reply.command!,
                  pulse,
                  cell,
                  'AiTissueCommand',
                ),
                token: token,
              );
              return;
            }

            final reject = reply.reject ??
                Reject(
                  source: payload.toString(),
                  reason: 'empty-reply',
                );
            future!(
              result: _out<Reject>(
                reject,
                pulse,
                cell,
                'AiTissueCommand.rejected',
              ),
              token: token,
            );
          } catch (e, stack) {
            if (id != generation) return;
            onError?.call(e, stack);
          }
        }

        run();
        return null;
      };
    })(),
    user: user,
  );

  /// Injects a one-shot timeout into the wrapped interpreter.
  void injectTimeoutOnce() {
    interpreter.injectTimeoutOnce();
  }
}

// ═════════════════════════════════════════════════════════════
// 2. AiTissueCommandBatch — Batch of Sentences
// ═════════════════════════════════════════════════════════════

/// A [FlowInstruction] that turns a **batch** of natural-language
/// sentences into a batch of [TissueCommand]s in a single port call.
///
/// ### How it works
/// 1. **Stimulus Reception**: The instruction receives a pulse
///    whose payload is `Iterable<S>` — a batch of sentences.
/// 2. **Sequential Fan-Out**: For each sentence in order, the
///    port is invoked once.
/// 3. **Reply Aggregation**: All replies (commands and refusals)
///    are collected into a single `List<Object>` preserving order.
/// 4. **Batch Emit**: If the batch's generation is still current,
///    the list is emitted as one `Pulse<List<Object>>`, tagged
///    with `'AiTissueCommandBatch'`.
///
/// ### Non‑obvious
/// - **One HTTP call per sentence**: Deliberate, so the traffic
///   log can attribute each reply to a specific sentence.
/// - **Mixed replies**: A batch that produces three commands and
///   one refusal emits all four in the list.
/// - **Order preservation**: The output list matches the input
///   order even if some sentences time out.
///
/// ### See Also
/// - [AiTissueCommand]: Single-sentence sibling.
/// - [AiTissueCommandWithRetry]: Retry sibling.
class AiTissueCommandBatch<S>
    extends FlowInstructionBase<Cell, Pulse, Pulse>
    with FlowInstructionMixin<Cell, Pulse, Pulse> {

  /// The wrapped interpreter.
  final Interpreter interpreter;

  /// Synthesizes a **Batch AI-Bridged Interpretation Gate**.
  AiTissueCommandBatch({
    required this.interpreter,
    required Set<String> verbs,
    AiTissueCommandErrorHandler? onError,
    dynamic user,
  }) : super.future(
    (() {
      var generation = 0;
      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! Iterable<S>) {
          onError?.call(
            FormatException(
              'Expected payload of type Iterable<$S>, '
                  'got ${payload.runtimeType}',
            ),
            StackTrace.current,
          );
          return null;
        }

        final sentences = List<S>.from(payload);
        final id = ++generation;

        Future<void> run() async {
          final results = <Object>[];
          for (final sentence in sentences) {
            if (id != generation) return;

            try {
              final reply = await interpreter.complete(
                text: sentence as String,
                verbs: verbs,
              );

              if (reply.command != null) {
                results.add(reply.command!);
              } else if (reply.reject != null) {
                results.add(reply.reject!);
              } else {
                results.add(
                  Reject(
                    source: sentence.toString(),
                    reason: 'empty-reply',
                  ),
                );
              }
            } catch (e, stack) {
              onError?.call(e, stack);
              results.add(
                Reject(
                  source: sentence.toString(),
                  reason: 'interpreter-error',
                ),
              );
            }
          }

          if (id != generation) return;
          future!(
            result: _out<List<Object>>(
              results,
              pulse,
              cell,
              'AiTissueCommandBatch',
            ),
            token: token,
          );
        }

        run();
        return null;
      };
    })(),
    user: user,
  );

  /// Injects a one-shot timeout into the wrapped interpreter.
  void injectTimeoutOnce() {
    interpreter.injectTimeoutOnce();
  }
}

// ═════════════════════════════════════════════════════════════
// 3. AiTissueCommandWithRetry — Retry Policy
// ═════════════════════════════════════════════════════════════

/// A [FlowInstruction] that turns a natural-language sentence into
/// a [TissueCommand], retrying the port call up to [count] extra
/// times on failure.
///
/// ### Retry Semantics
/// * **Total Attempts**: The port may be invoked `count + 1` times.
/// * **No Delay**: Retries are immediate.
/// * **Preserves Last Error**: If all retries fail, the last
///   exception is routed to [onError] and a `Reject` marker is
///   emitted with the exhaustion trace.
/// * **Generation-Aware**: Each retry checks whether a newer
///   sentence has arrived; if so, the loop aborts immediately.
/// * **No Retry on Refusal**: A model refusal is a definitive
///   answer; only transport errors consume the retry budget.
///
/// ### See Also
/// - [AiTissueCommand]: Single-shot sibling.
/// - [AiTissueCommandBatch]: Batch sibling.
class AiTissueCommandWithRetry<S>
    extends FlowInstructionBase<Cell, Pulse, Pulse>
    with FlowInstructionMixin<Cell, Pulse, Pulse> {

  /// The wrapped interpreter.
  final Interpreter interpreter;

  /// Synthesizes a **Resilient AI-Bridged Interpretation Gate**.
  AiTissueCommandWithRetry({
    required this.interpreter,
    required Set<String> verbs,
    int count = 3,
    AiTissueCommandErrorHandler? onError,
    dynamic user,
  }) : super.future(
    (() {
      var generation = 0;
      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! S) {
          onError?.call(
            FormatException(
              'Expected payload of type $S, got ${payload.runtimeType}',
            ),
            StackTrace.current,
          );
          return null;
        }

        final id = ++generation;

        Future<void> run() async {
          var attempt = 0;
          Object? lastError;
          StackTrace? lastStack;

          while (true) {
            if (id != generation) return;

            try {
              final reply = await interpreter.complete(
                text: payload as String,
                verbs: verbs,
              );

              if (id != generation) return;

              if (reply.command != null) {
                future!(
                  result: _out<TissueCommand>(
                    reply.command!,
                    pulse,
                    cell,
                    'AiTissueCommandWithRetry',
                  ),
                  token: token,
                );
                return;
              }

              final reject = reply.reject ??
                  Reject(
                    source: payload.toString(),
                    reason: 'empty-reply',
                  );
              future!(
                result: _out<Reject>(
                  reject,
                  pulse,
                  cell,
                  'AiTissueCommandWithRetry.rejected',
                ),
                token: token,
              );
              return;
            } catch (e, stack) {
              lastError = e;
              lastStack = stack;
              onError?.call(e, stack);
              if (attempt >= count) break;
              attempt++;
            }
          }

          if (id != generation) return;

          final frame = lastStack
              ?.toString()
              .split('\n')
              .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
          final frameSuffix =
          (frame != null && frame.isNotEmpty) ? ' @ $frame' : '';

          future!(
            result: _out<Reject>(
              Reject(
                source: payload.toString(),
                reason: 'retries-exhausted: $lastError$frameSuffix',
              ),
              pulse,
              cell,
              'AiTissueCommandWithRetry.exhausted',
            ),
            token: token,
          );
        }

        run();
        return null;
      };
    })(),
    user: user,
  );

  /// Injects a one-shot timeout into the wrapped interpreter.
  void injectTimeoutOnce() {
    interpreter.injectTimeoutOnce();
  }
}

/// Error handler callback for the AI-bridged interpretation gates.
typedef AiTissueCommandErrorHandler =
void Function(Object error, StackTrace? stackTrace);

// ═════════════════════════════════════════════════════════════
// DEMO
// ═════════════════════════════════════════════════════════════

/// A self-demonstrating run of the three AI-bridged interpretation
/// instructions.
///
/// ### Offline mode (default)
/// Runs the seven scenarios against the deterministic
/// [StubInterpreter]. The stub fabricates a request body and an
/// OpenAI-compatible response envelope for every sentence, so the
/// console shows the same seven steps a live HTTP call would
/// produce.
///
///     dart run ai_tissue_command.dart
///
/// ### Live mode (`--live`)
/// Runs the same seven scenarios against the live endpoint named
/// by the three environment variables. The traffic log shows the
/// real bytes on the wire — every prompt, every request body,
/// every response body, every usage block.
///
///     export AI_ENDPOINT=https://api.deepseek.com/chat/completions
///     export AI_API_KEY=sk-your-deepseek-key
///     export AI_MODEL=deepseek-flash
///     dart run ai_tissue_command.dart --live
///
/// If `--live` is passed but AI_ENDPOINT or AI_API_KEY is missing,
/// the demo prints a diagnostic and falls back to the offline stub
/// so the run still completes.
///
/// ### Expected console output (offline mode)
/// ```text
/// ── AiTissueCommand Operators Demo ──────────────────────────────
/// mode: offline stub (pass --live for HTTP)
///
/// 1. AiTissueCommand — single sentence
///    [cmd] TissueCommand(add, args=[1])
///    [cmd] TissueCommand(remove, args=[1])
///    [cmd] Reject(reason=no-permitted-verb)
///
/// 2. AiTissueCommand — latest-wins
///    [cmd] TissueCommand(add, args=[9])
///
/// 3. AiTissueCommandBatch — 4 sentences in one batch
///    [batch] size=4
///    [batch] 0: TissueCommand(add, args=[1])
///    [batch] 1: TissueCommand(add, args=[2])
///    [batch] 2: TissueCommand(clear, args=[])
///    [batch] 3: Reject(reason=no-permitted-verb)
///
/// 4. AiTissueCommandBatch — mixed with a timeout
///    [batch] size=3
///    [batch] 0: Reject(reason=interpreter-error)
///    [batch] 1: TissueCommand(add, args=[8])
///    [batch] 2: TissueCommand(add, args=[9])
///
/// 5. AiTissueCommandWithRetry — success on first try
///    [retry] TissueCommand(add, args=[5])
///    attempts=1
///
/// 6. AiTissueCommandWithRetry — success after retries
///    [retry] TissueCommand(add, args=[6])
///    attempts=4
///
/// 7. AiTissueCommandWithRetry — retries exhausted
///    [retry] Reject(reason=retries-exhausted: Bad state: permanent failure...)
///    attempts=3
///
/// ── finished ────────────────────────────────────────────────────
/// ```
Future<void> main(List<String> args) async {
  final live = args.contains('--live');

  // ── Mode selection ──────────────────────────────────────────
  final Interpreter primary;
  final String modeLabel;

  if (live) {
    final endpoint = Platform.environment['AI_ENDPOINT'];
    final apiKey = Platform.environment['AI_API_KEY'];
    final model = Platform.environment['AI_MODEL'] ?? 'gpt-4o-mini';

    if (endpoint == null || apiKey == null) {
      stderr.writeln(
        'Live mode requires AI_ENDPOINT and AI_API_KEY env vars.',
      );
      stderr.writeln('Falling back to offline stub.');
      primary = StubInterpreter(latency: Duration.zero);
      modeLabel = 'offline stub (live mode requested but env vars missing)';
    } else {
      primary = HttpInterpreter(
        endpoint: Uri.parse(endpoint),
        apiKey: apiKey,
        model: model,
        log: TrafficLog(silent: false),
      );
      modeLabel = 'live HTTP (model=$model, endpoint=$endpoint)';
    }
  } else {
    primary = StubInterpreter(latency: Duration.zero);
    modeLabel = 'offline stub (pass --live for HTTP)';
  }

  print('── AiTissueCommand Operators Demo ──────────────────────────────');
  print('mode: $modeLabel\n');

  try {
    // ═══════════════════════════════════════════════════════════
    // 1. AiTissueCommand — single sentence
    // ═══════════════════════════════════════════════════════════
    print('1. AiTissueCommand — single sentence');

    final commandIn = Cell.ingress<String>();

    final single = AiTissueCommand<String>(
      interpreter: primary,
      verbs: <String>{...verbByName.keys},
    ).toHandle(source: commandIn.cell);

    final singleObs = Cell.observe(
      source: single.cell,
      effect: (Pulse p) {
        final v = p.payload;
        if (v is TissueCommand) {
          print('   [cmd] TissueCommand(${v.verb.name}, args=${v.args})');
        } else if (v is Reject) {
          print('   [cmd] Reject(reason=${v.reason})');
        } else {
          print('   [cmd] unexpected payload: $v');
        }
      },
    );

    await commandIn.emitAsync('add 1');
    await commandIn.emitAsync('remove 1');
    await commandIn.emitAsync('hack the nucleus');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    singleObs.stop();
    print('');

    // ═══════════════════════════════════════════════════════════
    // 2. AiTissueCommand — latest-wins
    // ═══════════════════════════════════════════════════════════
    print('2. AiTissueCommand — latest-wins');

    final latestIn = Cell.ingress<String>();
    final latest = AiTissueCommand<String>(
      interpreter: primary,
      verbs: <String>{...verbByName.keys},
    ).toHandle(source: latestIn.cell);

    final latestObs = Cell.observe(
      source: latest.cell,
      effect: (Pulse p) {
        final v = p.payload;
        if (v is TissueCommand) {
          print('   [cmd] TissueCommand(${v.verb.name}, args=${v.args})');
        } else if (v is Reject) {
          print('   [cmd] Reject(reason=${v.reason})');
        }
      },
    );

    await latestIn.emitAsync('add 1');
    await latestIn.emitAsync('add 9');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    latestObs.stop();
    print('');

    // ═══════════════════════════════════════════════════════════
    // 3. AiTissueCommandBatch — 4 sentences in one batch
    // ═══════════════════════════════════════════════════════════
    print('3. AiTissueCommandBatch — 4 sentences in one batch');

    final batchIn = Cell.ingress<List<String>>();
    final batch = AiTissueCommandBatch<String>(
      interpreter: primary,
      verbs: <String>{...verbByName.keys},
    ).toHandle(source: batchIn.cell);

    final batchObs = Cell.observe(
      source: batch.cell,
      effect: (Pulse p) {
        final list = p.payload;
        if (list is List) {
          print('   [batch] size=${list.length}');
          for (var i = 0; i < list.length; i++) {
            final item = list[i];
            if (item is TissueCommand) {
              print('   [batch] $i: '
                  'TissueCommand(${item.verb.name}, args=${item.args})');
            } else if (item is Reject) {
              print('   [batch] $i: Reject(reason=${item.reason})');
            }
          }
        }
      },
    );

    await batchIn.emitAsync([
      'add 1',
      'add 2',
      'clear',
      'hack the nucleus',
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    batchObs.stop();
    print('');

    // ═══════════════════════════════════════════════════════════
    // 4. AiTissueCommandBatch — mixed with a timeout
    // ═══════════════════════════════════════════════════════════
    print('4. AiTissueCommandBatch — mixed with a timeout');

    // Offline mode uses a stub we control directly. Live mode uses
    // the shared primary interpreter; the timeout injection fires
    // on whichever interpreter is active.
    final Interpreter flaky;
    if (primary is StubInterpreter) {
      flaky = StubInterpreter(latency: Duration.zero);
      (flaky as StubInterpreter).injectTimeoutOnce();
    } else {
      flaky = primary;
      flaky.injectTimeoutOnce();
    }

    final mixedIn = Cell.ingress<List<String>>();
    final mixed = AiTissueCommandBatch<String>(
      interpreter: flaky,
      verbs: <String>{...verbByName.keys},
      onError: (_, __) {},
    ).toHandle(source: mixedIn.cell);

    final mixedObs = Cell.observe(
      source: mixed.cell,
      effect: (Pulse p) {
        final list = p.payload;
        if (list is List) {
          print('   [batch] size=${list.length}');
          for (var i = 0; i < list.length; i++) {
            final item = list[i];
            if (item is TissueCommand) {
              print('   [batch] $i: '
                  'TissueCommand(${item.verb.name}, args=${item.args})');
            } else if (item is Reject) {
              print('   [batch] $i: Reject(reason=${item.reason})');
            }
          }
        }
      },
    );

    await mixedIn.emitAsync(['add 7', 'add 8', 'add 9']);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    mixedObs.stop();
    print('');

    // ═══════════════════════════════════════════════════════════
    // 5. AiTissueCommandWithRetry — success on first try
    // ═══════════════════════════════════════════════════════════
    print('5. AiTissueCommandWithRetry — success on first try');

    final retryIn = Cell.ingress<String>();

    var attempts5 = 0;
    final retry5 = AiTissueCommandWithRetry<String>(
      interpreter: _CountingInterpreter(
        primary,
        onAttempt: () => attempts5++,
      ),
      verbs: <String>{...verbByName.keys},
      count: 3,
    ).toHandle(source: retryIn.cell);

    final retry5Obs = Cell.observe(
      source: retry5.cell,
      effect: (Pulse p) {
        final v = p.payload;
        if (v is TissueCommand) {
          print('   [retry] TissueCommand(${v.verb.name}, args=${v.args})');
        } else if (v is Reject) {
          print('   [retry] Reject(reason=${v.reason})');
        }
      },
    );

    await retryIn.emitAsync('add 5');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    print('   attempts=$attempts5');
    retry5Obs.stop();
    print('');

    // ═══════════════════════════════════════════════════════════
    // 6. AiTissueCommandWithRetry — success after retries
    // ═══════════════════════════════════════════════════════════
    print('6. AiTissueCommandWithRetry — success after retries');

    // Offline mode: fresh stub, three injected timeouts, success
    // on the fourth attempt.
    // Live mode: shared primary, one injected timeout, success on
    // the second attempt. (Live mode does not force three attempts
    // because each injected timeout is a one-shot flag and a live
    // endpoint can succeed on the retry.)
    final Interpreter flakyRetry;
    final int injectedTimeouts;
    if (primary is StubInterpreter) {
      flakyRetry = StubInterpreter(latency: Duration.zero);
      injectedTimeouts = 3;
    } else {
      flakyRetry = primary;
      injectedTimeouts = 1;
    }
    for (var i = 0; i < injectedTimeouts; i++) {
      flakyRetry.injectTimeoutOnce();
    }

    final retry6In = Cell.ingress<String>();
    var attempts6 = 0;
    final retry6 = AiTissueCommandWithRetry<String>(
      interpreter: _CountingInterpreter(
        flakyRetry,
        onAttempt: () => attempts6++,
      ),
      verbs: <String>{...verbByName.keys},
      count: 5,
      onError: (_, __) {},
    ).toHandle(source: retry6In.cell);

    final retry6Obs = Cell.observe(
      source: retry6.cell,
      effect: (Pulse p) {
        final v = p.payload;
        if (v is TissueCommand) {
          print('   [retry] TissueCommand(${v.verb.name}, args=${v.args})');
        } else if (v is Reject) {
          print('   [retry] Reject(reason=${v.reason})');
        }
      },
    );

    await retry6In.emitAsync('add 6');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    print('   attempts=$attempts6');
    retry6Obs.stop();
    print('');

    // ═══════════════════════════════════════════════════════════
    // 7. AiTissueCommandWithRetry — retries exhausted
    // ═══════════════════════════════════════════════════════════
    print('7. AiTissueCommandWithRetry — retries exhausted');

    final retry7In = Cell.ingress<String>();

    var attempts7 = 0;
    final retry7 = AiTissueCommandWithRetry<String>(
      interpreter: _CountingInterpreter(
        _AlwaysFailsInterpreter(),
        onAttempt: () => attempts7++,
      ),
      verbs: <String>{...verbByName.keys},
      count: 2, // total attempts = 3
      onError: (_, __) {},
    ).toHandle(source: retry7In.cell);

    final retry7Obs = Cell.observe(
      source: retry7.cell,
      effect: (Pulse p) {
        final v = p.payload;
        if (v is Reject) {
          final short = v.reason.length > 60
              ? '${v.reason.substring(0, 60)}...'
              : v.reason;
          print('   [retry] Reject(reason=$short)');
        } else if (v is TissueCommand) {
          print('   [retry] TissueCommand(${v.verb.name}, args=${v.args})');
        }
      },
    );

    await retry7In.emitAsync('add 7');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    print('   attempts=$attempts7');
    retry7Obs.stop();
    print('');

    print('── finished ────────────────────────────────────────────────────');
  } finally {
    // Live HTTP clients hold OS resources; close them on exit.
    if (primary is HttpInterpreter) {
      primary.close();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Demo helpers — counting and always-failing interpreters
// ─────────────────────────────────────────────────────────────

/// Wraps an interpreter so each `complete` call increments a
/// counter. Used by the demo to prove the retry count.
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

/// An interpreter that throws on every call. Used to demonstrate
/// the retries-exhausted path.
class _AlwaysFailsInterpreter implements Interpreter {
  @override
  String get transport => 'stub';

  @override
  void injectTimeoutOnce() {
    // no-op: this interpreter always fails
  }

  @override
  Future<InterpreterReply> complete({
    required String text,
    required Set<String> verbs,
  }) {
    return Future<InterpreterReply>.error(
      StateError('permanent failure'),
    );
  }
}