// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import '../../cell_flow.dart';

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
// Each of the three instructions has a primary constructor (which
// takes an [Interpreter] directly) and a `.fromConfig(...)` factory
// (which builds the interpreter from an [AiConfig]).
//
// The demo at the bottom (`main`) exercises all three against the
// deterministic offline stub. It does not require network access.
//
// ─────────────────────────────────────────────────────────────
// No Environment Fallback
// ─────────────────────────────────────────────────────────────
//
// When a caller supplies an [AiConfig] via `.fromConfig(...)`, the
// resulting interpreter reads **only** the values in the config.
// It does not consult `Platform.environment` and it does not merge
// with `AI_ENDPOINT`, `AI_API_KEY`, or `AI_MODEL`.
//
// That is deliberate. A caller that supplies a config object has
// declared its intent. Silent env-var substitution would mean the
// same code produced different behaviour on two machines, which is
// exactly the source of misconfiguration the config file is meant
// to eliminate.
//
// If you *do* want env-var fallback, merge the two sources before
// constructing the config:
//
// ```dart
// final merged = {
//   if (Platform.environment['AI_ENDPOINT'] != null)
//     'endpoint': Platform.environment['AI_ENDPOINT'],
//   if (Platform.environment['AI_API_KEY'] != null)
//     'apiKey': Platform.environment['AI_API_KEY'],
//   if (Platform.environment['AI_MODEL'] != null)
//     'model': Platform.environment['AI_MODEL'],
//   ...fileConfig,
// };
// final config = AiConfig.fromJson(merged);
// ```
//
// That way the precedence is under your control, not hidden inside
// the instruction.
// ─────────────────────────────────────────────────────────────

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

/// Safely invokes an error handler.
///
/// [onError] is captured from the enclosing constructor's parameter
/// list. Dart's flow analysis treats a captured nullable parameter
/// as potentially nullable inside the closure, so this helper makes
/// the null check explicit and silences false positives about the
/// null-aware operator.
void _invokeOnError(
  AiTissueCommandErrorHandler? onError,
  Object error,
  StackTrace stack,
) {
  final handler = onError;
  if (handler != null) handler(error, stack);
}

// ═════════════════════════════════════════════════════════════
// 1. AiTissueCommand — Single-Sentence, Latest-Wins
// ═════════════════════════════════════════════════════════════

/// A [FlowInstruction] that turns a natural-language sentence into
/// a [TissueCommand] by asking an [Interpreter] (a live AI chatbot
/// over HTTP, or a deterministic offline stub) to choose a verb
/// from a closed list.
///
/// [AiTissueCommand] is the **only** operator in the demo that
/// performs I/O. Everything downstream — the `modifiable` check,
/// the dispatch tear-off, and TestTissue — is pure.
///
/// ### When to use
/// Use [AiTissueCommand] whenever a signal carries natural language
/// that must be translated into a closed, machine-validated command
/// before it can mutate a reactive collection.
///
/// - **Chat-ops**: An operator types "add 3" and the graph mutates
///   a set.
/// - **Voice commands**: A speech-to-text result is interpreted as
///   a verb on a tissue.
/// - **LLM tool calls**: The model chooses a tool from a schema,
///   and the instruction materializes that choice as a reactive
///   signal.
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
class AiTissueCommand<S> extends FlowInstructionBase<Cell, Pulse, Pulse>
    with FlowInstructionMixin<Cell, Pulse, Pulse> {
  /// The wrapped interpreter.
  final Interpreter interpreter;

  /// Synthesizes an **AI-Bridged Interpretation Gate**.
  ///
  /// ### Parameters
  ///
  /// - [interpreter]: **Required.** The interpreter the gate uses
  ///   for every `complete` call. Env vars are not consulted; the
  ///   interpreter must be fully configured before being passed
  ///   here.
  /// - [verbs]: **Required.** The closed verb list passed to the
  ///   interpreter's `complete` method.
  /// - [onError]: **Optional.** The error handler.
  /// - [user]: **Optional.** Flyweight metadata.
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
                _invokeOnError(
                  onError,
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
                  _invokeOnError(onError, e, stack);
                }
              }

              run();
              return null;
            };
          })(),
          user: user,
        );

  /// Builds an [AiTissueCommand] from an [AiConfig].
  ///
  /// ### No Environment Fallback
  ///
  /// This factory builds the wrapped [Interpreter] exclusively from
  /// [config]. It does **not** read `AI_ENDPOINT`, `AI_API_KEY`, or
  /// `AI_MODEL` from the environment, and it does not merge the two
  /// sources. If you want env-var fallback, construct the config
  /// with those values yourself before calling this method.
  ///
  /// That is deliberate. A caller that goes to the trouble of
  /// supplying a config object has declared its intent. Silently
  /// consulting the environment on top of that would make the
  /// instruction's behaviour depend on a state the caller did not
  /// pass in.
  ///
  /// ### Parameters
  ///
  /// - [config]: **Required.** The AI configuration. Every value
  ///   the interpreter uses comes from here.
  /// - [verbs]: **Required.** The closed verb list passed to the
  ///   interpreter's `complete` method.
  /// - [onError]: **Optional.** The error handler.
  /// - [user]: **Optional.** Flyweight metadata.
  ///
  /// ### Returns
  ///
  /// A fully configured [AiTissueCommand] whose wrapped interpreter
  /// reads only [config].
  ///
  /// ### See Also
  ///
  /// - [AiConfig.toInterpreter] — the interpreter builder.
  /// - [AiTissueCommand] — the primary constructor.
  factory AiTissueCommand.fromConfig({
    required AiConfig config,
    required Set<String> verbs,
    AiTissueCommandErrorHandler? onError,
    dynamic user,
  }) =>
      AiTissueCommand<S>(
        interpreter: config.toInterpreter(),
        verbs: verbs,
        onError: onError,
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
class AiTissueCommandBatch<S> extends FlowInstructionBase<Cell, Pulse, Pulse>
    with FlowInstructionMixin<Cell, Pulse, Pulse> {
  /// The wrapped interpreter.
  final Interpreter interpreter;

  /// Synthesizes a **Batch AI-Bridged Interpretation Gate**.
  ///
  /// ### Parameters
  ///
  /// - [interpreter]: **Required.** The interpreter the gate uses
  ///   for every sentence in the batch. Env vars are not consulted.
  /// - [verbs]: **Required.** The closed verb list.
  /// - [onError]: **Optional.** The error handler.
  /// - [user]: **Optional.** Flyweight metadata.
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
                _invokeOnError(
                  onError,
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
                    _invokeOnError(onError, e, stack);
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

  /// Builds an [AiTissueCommandBatch] from an [AiConfig].
  ///
  /// ### No Environment Fallback
  ///
  /// Same contract as [AiTissueCommand.fromConfig]: the interpreter
  /// reads only [config].
  ///
  /// ### Parameters
  ///
  /// - [config]: **Required.** The AI configuration.
  /// - [verbs]: **Required.** The closed verb list.
  /// - [onError]: **Optional.** The error handler.
  /// - [user]: **Optional.** Flyweight metadata.
  ///
  /// ### Returns
  ///
  /// A fully configured [AiTissueCommandBatch].
  factory AiTissueCommandBatch.fromConfig({
    required AiConfig config,
    required Set<String> verbs,
    AiTissueCommandErrorHandler? onError,
    dynamic user,
  }) =>
      AiTissueCommandBatch<S>(
        interpreter: config.toInterpreter(),
        verbs: verbs,
        onError: onError,
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
  ///
  /// ### Parameters
  ///
  /// - [interpreter]: **Required.** The interpreter the gate uses
  ///   for every attempt. Env vars are not consulted.
  /// - [verbs]: **Required.** The closed verb list.
  /// - [count]: **Optional.** Max retry attempts. Defaults to 3.
  /// - [onError]: **Optional.** The error handler.
  /// - [user]: **Optional.** Flyweight metadata.
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
                _invokeOnError(
                  onError,
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
                    _invokeOnError(onError, e, stack);
                    if (attempt >= count) break;
                    attempt++;
                  }
                }

                if (id != generation) return;

                final frame = lastStack.toString().split('\n').firstWhere(
                      (l) => l.trim().isNotEmpty,
                      orElse: () => '',
                    );
                final frameSuffix = frame.isNotEmpty ? ' @ $frame' : '';

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

  /// Builds an [AiTissueCommandWithRetry] from an [AiConfig].
  ///
  /// ### No Environment Fallback
  ///
  /// Same contract as [AiTissueCommand.fromConfig]: the interpreter
  /// reads only [config].
  ///
  /// ### Parameters
  ///
  /// - [config]: **Required.** The AI configuration.
  /// - [verbs]: **Required.** The closed verb list.
  /// - [count]: **Optional.** Max retry attempts. Defaults to 3.
  /// - [onError]: **Optional.** The error handler.
  /// - [user]: **Optional.** Flyweight metadata.
  ///
  /// ### Returns
  ///
  /// A fully configured [AiTissueCommandWithRetry].
  factory AiTissueCommandWithRetry.fromConfig({
    required AiConfig config,
    required Set<String> verbs,
    int count = 3,
    AiTissueCommandErrorHandler? onError,
    dynamic user,
  }) =>
      AiTissueCommandWithRetry<S>(
        interpreter: config.toInterpreter(),
        verbs: verbs,
        count: count,
        onError: onError,
        user: user,
      );

  /// Injects a one-shot timeout into the wrapped interpreter.
  void injectTimeoutOnce() {
    interpreter.injectTimeoutOnce();
  }
}

// ─────────────────────────────────────────────────────────────
// VISUAL OUTPUT HELPERS
// ─────────────────────────────────────────────────────────────

void _section(String label, String drive) {
  print('');
  print('── $label ── $drive');
}

// ═════════════════════════════════════════════════════════════
// DEMO — AiTissueCommand family self-tests
// ═════════════════════════════════════════════════════════════

/// A demonstration of the three AI-bridged interpretation
/// instructions against the deterministic offline stub.
///
/// ### Expected console output
///
/// ```text
/// ── AiTissueCommand Operators Demo ──────────────────────────────
///
/// ── 1 ── AiTissueCommand — single sentence
///    [cmd] TissueCommand(add, args=[1])
///    [cmd] TissueCommand(remove, args=[1])
///    [cmd] Reject(reason=no-permitted-verb)
///
/// ── 2 ── AiTissueCommand — latest-wins
///    [cmd] TissueCommand(add, args=[9])
///
/// ── 3 ── AiTissueCommandBatch — 4 sentences in one batch
///    [batch] size=4
///    [batch] 0: TissueCommand(add, args=[1])
///    [batch] 1: TissueCommand(add, args=[2])
///    [batch] 2: TissueCommand(clear, args=[])
///    [batch] 3: Reject(reason=no-permitted-verb)
///
/// ── 4 ── AiTissueCommandBatch — mixed with a timeout
///    [batch] size=3
///    [batch] 0: Reject(reason=interpreter-error)
///    [batch] 1: TissueCommand(add, args=[8])
///    [batch] 2: TissueCommand(add, args=[9])
///
/// ── 5 ── AiTissueCommandWithRetry — success on first try
///    [retry] TissueCommand(add, args=[5])
///    attempts=1
///
/// ── 6 ── AiTissueCommandWithRetry — success after retries
///    [retry] TissueCommand(add, args=[6])
///    attempts=4
///
/// ── 7 ── AiTissueCommandWithRetry — retries exhausted
///    [retry] Reject(reason=retries-exhausted: Bad state: permanent failure...)
///    attempts=3
///
/// ── 8 ── AiTissueCommand.fromConfig
///    instruction=AiTissueCommand<String> transport=http
///    (no HTTP call — placeholder endpoint)
///
/// ── finished ────────────────────────────────────────────────────
/// ```
///
/// ### How to run
///
/// Offline (default):
///
///     dart run ai_tissue_command.dart
///
/// The demo runs entirely against the deterministic stub. To see
/// the live HTTP path, use the full demo at
/// `nl-instruction-tissue-set-enhanced-Demo.dart --live` or
/// `--config ai_config.json`.
///
/// ### What it demonstrates
///
/// 1. **AiTissueCommand** — a single sentence produces a
///    [TissueCommand] or a [Reject].
/// 2. **AiTissueCommand** — latest-wins: the second sentence
///    supersedes the first.
/// 3. **AiTissueCommandBatch** — a batch of four sentences
///    produces a four-element list preserving order.
/// 4. **AiTissueCommandBatch** — a timeout inside a batch becomes
///    an `interpreter-error` Reject; the batch continues.
/// 5. **AiTissueCommandWithRetry** — first-try success.
/// 6. **AiTissueCommandWithRetry** — success after retries.
/// 7. **AiTissueCommandWithRetry** — retries exhausted produces a
///    `retries-exhausted` Reject.
/// 8. **AiTissueCommand.fromConfig** — the config path produces an
///    instruction identical in behaviour to the primary
///    constructor.
///
/// ### Key takeaways
///
/// - All three instructions share the same [Interpreter] port.
/// - All three have `.fromConfig(...)` factories that build the
///   interpreter from an [AiConfig] with no env-var fallback.
/// - The retry variant distinguishes transport failures from model
///   refusals.
Future<void> main() async {
  print('── AiTissueCommand Operators Demo ──────────────────────────────');

  // ─────────────────────────────────────────────────────────────
  // 1. AiTissueCommand — single sentence
  // ─────────────────────────────────────────────────────────────
  _section('1', 'AiTissueCommand — single sentence');

  final stub = StubInterpreter(latency: Duration.zero);
  final commandIn = Cell.ingress<String>();

  final single = AiTissueCommand<String>(
    interpreter: stub,
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
  await Future<void>.delayed(const Duration(milliseconds: 30));
  singleObs.stop();

  // ─────────────────────────────────────────────────────────────
  // 2. AiTissueCommand — latest-wins
  // ─────────────────────────────────────────────────────────────
  _section('2', 'AiTissueCommand — latest-wins');

  final latestIn = Cell.ingress<String>();
  final latest = AiTissueCommand<String>(
    interpreter: stub,
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
  await Future<void>.delayed(const Duration(milliseconds: 20));
  latestObs.stop();

  // ─────────────────────────────────────────────────────────────
  // 3. AiTissueCommandBatch — 4 sentences in one batch
  // ─────────────────────────────────────────────────────────────
  _section('3', 'AiTissueCommandBatch — 4 sentences in one batch');

  final batchIn = Cell.ingress<List<String>>();
  final batch = AiTissueCommandBatch<String>(
    interpreter: stub,
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

  await batchIn.emitAsync(['add 1', 'add 2', 'clear', 'hack the nucleus']);
  await Future<void>.delayed(const Duration(milliseconds: 30));
  batchObs.stop();

  // ─────────────────────────────────────────────────────────────
  // 4. AiTissueCommandBatch — mixed with a timeout
  // ─────────────────────────────────────────────────────────────
  _section('4', 'AiTissueCommandBatch — mixed with a timeout');

  final flakyStub = StubInterpreter(latency: Duration.zero);
  final mixedIn = Cell.ingress<List<String>>();
  final mixed = AiTissueCommandBatch<String>(
    interpreter: flakyStub,
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

  // The stub's `injectTimeoutOnce` fires on the NEXT complete
  // call. Because the batch processes sentences sequentially,
  // this targets the FIRST sentence.
  flakyStub.injectTimeoutOnce();
  await mixedIn.emitAsync(['add 7', 'add 8', 'add 9']);
  await Future<void>.delayed(const Duration(milliseconds: 30));
  mixedObs.stop();

  // ─────────────────────────────────────────────────────────────
  // 5. AiTissueCommandWithRetry — success on first try
  // ─────────────────────────────────────────────────────────────
  _section('5', 'AiTissueCommandWithRetry — success on first try');

  final retryStub = StubInterpreter(latency: Duration.zero);
  final retryIn = Cell.ingress<String>();

  var attempts5 = 0;
  final retry5 = AiTissueCommandWithRetry<String>(
    interpreter: _CountingInterpreter(
      retryStub,
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
  await Future<void>.delayed(const Duration(milliseconds: 20));
  print('   attempts=$attempts5');
  retry5Obs.stop();

  // ─────────────────────────────────────────────────────────────
  // 6. AiTissueCommandWithRetry — success after retries
  // ─────────────────────────────────────────────────────────────
  _section('6', 'AiTissueCommandWithRetry — success after retries');

  final flaky = StubInterpreter(latency: Duration.zero);
  final retry6In = Cell.ingress<String>();

  var attempts6 = 0;
  final retry6 = AiTissueCommandWithRetry<String>(
    interpreter: _CountingInterpreter(
      flaky,
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

  // Three timeouts in a row; the fourth attempt succeeds because
  // injectTimeoutOnce only fires once per call.
  flaky.injectTimeoutOnce();
  flaky.injectTimeoutOnce();
  flaky.injectTimeoutOnce();

  await retry6In.emitAsync('add 6');
  await Future<void>.delayed(const Duration(milliseconds: 30));
  print('   attempts=$attempts6');
  retry6Obs.stop();

  // ─────────────────────────────────────────────────────────────
  // 7. AiTissueCommandWithRetry — retries exhausted
  // ─────────────────────────────────────────────────────────────
  _section('7', 'AiTissueCommandWithRetry — retries exhausted');

  final alwaysFails = _AlwaysFailsInterpreter();
  final retry7In = Cell.ingress<String>();

  var attempts7 = 0;
  final retry7 = AiTissueCommandWithRetry<String>(
    interpreter: _CountingInterpreter(
      alwaysFails,
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
        final short =
            v.reason.length > 60 ? '${v.reason.substring(0, 60)}...' : v.reason;
        print('   [retry] Reject(reason=$short)');
      } else if (v is TissueCommand) {
        print('   [retry] TissueCommand(${v.verb.name}, args=${v.args})');
      }
    },
  );

  await retry7In.emitAsync('add 7');
  await Future<void>.delayed(const Duration(milliseconds: 30));
  print('   attempts=$attempts7');
  retry7Obs.stop();

  // ─────────────────────────────────────────────────────────────
  // 8. AiTissueCommand.fromConfig — builds an interpreter from a
  //    config (no env-var fallback)
  // ─────────────────────────────────────────────────────────────
  _section('8', 'AiTissueCommand.fromConfig');

  // We use a placeholder config here so the demo does not attempt
  // a live HTTP call. The factory itself is what is being
  // demonstrated; the interpreter it builds is a real
  // HttpInterpreter that would contact the endpoint named by the
  // config if it were ever invoked.
  final placeholderConfig = AiConfig(
    endpoint: Uri.parse('https://example.invalid/v1/chat/completions'),
    apiKey: 'not-a-real-key',
    model: 'placeholder-model',
  );
  final fromConfig = AiTissueCommand<String>.fromConfig(
    config: placeholderConfig,
    verbs: <String>{...verbByName.keys},
  );
  print('   instruction=${fromConfig.runtimeType} '
      'transport=${fromConfig.interpreter.transport}');
  print('   (no HTTP call — placeholder endpoint)');

  print('');
  print('── finished ────────────────────────────────────────────────────');
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

/// Error handler callback for the AI-bridged interpretation gates.
typedef AiTissueCommandErrorHandler = void Function(
    Object error, StackTrace? stackTrace);
