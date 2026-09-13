// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ─────────────────────────────────────────────────────────────
// AI Tissue Command — Domain
// ─────────────────────────────────────────────────────────────

/// Domain types shared by the AI-assisted tissue-command pipeline.
///
/// This file is the **single source of truth** for the vocabulary
/// and the interpreter port used by the AI bridge. It is
/// deliberately portable — it imports only `dart:async`,
/// `dart:convert`, and `dart:io`, and does not depend on `cell`,
/// `cell_flow`, or `cell_tissue`. The instruction file
/// (`ai_tissue_command.dart`) imports this file and does not
/// redefine any of these types.
///
/// ### The four layers of the AI pipeline
///
/// | Layer | Type | Role |
/// |---|---|---|
/// | Vocabulary | [TissueVerb], [verbByName] | the closed verb list |
/// | Reply shapes | [TissueCommand], [Reject], [InterpreterReply] | what the port returns |
/// | Port | [Interpreter], [HttpInterpreter], [StubInterpreter] | the seam between NL and the verb list |
/// | Config | [AiConfig] | JSON-file configuration for the live port |
/// | Observability | [TrafficLog], [systemPrompt] | the "show me the bytes" tool |
///
/// ### How the layers connect
///
/// A natural-language sentence enters the port. The port asks the
/// model to choose a verb from the closed list. The port returns
/// either a [TissueCommand] (verb + args) or a [Reject] (reason).
/// A downstream instruction (in `ai_tissue_command.dart`) materialises
/// that reply as a pulse. A still-further-downstream dispatch
/// instruction (in the demo) consults `TissueSet.modifiable` and
/// invokes the tear-off.
///
/// ### Non-obvious
///
/// - **The verb list is closed.** The model cannot invent a verb.
///   If it returns a string that is not a key in [verbByName], the
///   port synthesises a [Reject] with reason `'unknown-verb'`.
/// - **The port never executes code.** It parses a verb string and
///   an args array; it never evaluates Dart.
/// - **The domain is portable.** It can be reused by a CLI tool, a
///   test harness, or a scripted replay without any reactive
///   framework dependency.
/// - **`AiConfig` is the explicit source of AI settings.** When a
///   config is supplied, the interpreter reads only the config.
///   Environment variables are not consulted.
///
/// ### See Also
///
/// - `ai_tissue_command.dart` — the three instructions that consume
///   this domain.
/// - `nl-instruction-tissue-set-enhanced-Demo.dart` — the full demo.
/// - `async_map.dart` — the sibling instruction module whose docs
///   this file mirrors.
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// Closed Verb List
// ─────────────────────────────────────────────────────────────

/// The closed list of verbs the interpreter may return.
///
/// Every value maps to a tear-off on `TissueSet.modifiable`. The
/// dispatch instruction (in the demo) consults this enum to look
/// up the tear-off before invoking it.
///
/// ### When to use
///
/// Anywhere a natural-language command must be translated into a
/// fixed, machine-validated verb. The enum is the "closed
/// vocabulary" that makes the model's reply auditable and safe.
///
/// ### How it works
///
/// 1. The interpreter port returns a *string* verb name. JSON has
///    no enums.
/// 2. The port immediately converts that string into a
///    [TissueVerb] via [verbByName].
/// 3. A verb string that does not resolve is treated as a [Reject],
///    not as an executable command.
///
/// ### Non-obvious
///
/// - **The string → enum conversion is the boundary.** It is the
///   only place a model's reply becomes a typed verb. That is why
///   it lives in this file: the port cannot return a verb outside
///   the enum.
/// - **Not every verb is driven by the demo.** `removeWhere` and
///   `retainWhere` are listed so the closed vocabulary is complete,
///   but the demo's dispatch instruction rejects them. Predicates
///   are not safe to take from a model — see the individual value
///   docs.
/// - **Extending the list is manual.** Adding a verb to the enum
///   and to [verbByName] are two separate edits. A future build
///   could generate one from the other.
///
/// ### Values
///
/// See the individual value docs for the args shape each verb
/// expects.
///
/// ### See Also
///
/// - [verbByName] — the string → enum lookup.
/// - [TissueCommand] — the reply shape that carries a verb + args.
enum TissueVerb {
  /// `TissueSet.add(E)` — insert one element.
  ///
  /// ### When to use
  ///
  /// The interpreter returns this when the sentence names an
  /// insertion of a single value, e.g. `"add 3"`, `"please insert
  /// 7"`.
  ///
  /// ### Args shape
  ///
  /// `[value]` — a 1-element array, e.g. `[3]`.
  add,

  /// `TissueSet.addAll(Iterable<E>)` — insert many elements.
  ///
  /// ### When to use
  ///
  /// The interpreter returns this when the sentence names an
  /// insertion of several values, e.g. `"addAll 4 5"`.
  ///
  /// ### Args shape
  ///
  /// `[[values...]]` — a 1-element array whose element is a JSON
  /// array of values, e.g. `[[4, 5]]`.
  addAll,

  /// `TissueSet.remove(Object?)` — remove one element.
  ///
  /// ### Args shape
  ///
  /// `[value]` — a 1-element array.
  remove,

  /// `TissueSet.removeAll(Iterable<Object?>)` — remove many
  /// elements.
  ///
  /// ### Args shape
  ///
  /// `[[values...]]` — a 1-element array whose element is a JSON
  /// array of values.
  removeAll,

  /// `TissueSet.clear()` — remove every element.
  ///
  /// ### Args shape
  ///
  /// `[]` — an empty array.
  clear,

  /// `TissueSet.retainAll(Iterable<Object?>)` — keep only the
  /// named elements.
  ///
  /// ### Args shape
  ///
  /// `[[values...]]` — a 1-element array whose element is a JSON
  /// array of values.
  retainAll,

  /// `TissueSet.removeWhere(bool Function(E))` — not driven by
  /// this demo.
  ///
  /// ### Non-obvious
  ///
  /// Predicates are not safe to take from a model: a model that
  /// produced `(x) => x > 5` would be returning code, which the
  /// instruction refuses to execute. The verb is listed so the
  /// closed vocabulary is complete; the dispatch instruction
  /// rejects it if the model ever returns it.
  removeWhere,

  /// `TissueSet.retainWhere(bool Function(E))` — not driven by
  /// this demo.
  ///
  /// Same predicate-safety rationale as [removeWhere].
  retainWhere,
}

/// Lookup table from a verb string to the enum value.
///
/// The interpreters ([HttpInterpreter] and [StubInterpreter]) only
/// return one of the strings in this map. Any other string is
/// treated as a [Reject] with reason `'unknown-verb'`.
///
/// ### When to use
///
/// Anywhere a model's reply must be converted from a JSON string
/// into a typed verb. This map is the only path from a model's
/// reply to an executable verb.
///
/// ### How it works
///
/// The interpreter calls `verbByName[verbString]`. If the result is
/// null, the reply becomes a Reject. If non-null, the reply becomes
/// a [TissueCommand] with that verb.
///
/// ### Non-obvious
///
/// - **Missing key = refused verb.** If the map is missing a key,
///   the model cannot name that verb, even if
///   `TissueSet.modifiable` exposes the tear-off.
/// - **Manual sync with the enum.** Keeping this map and
///   [TissueVerb] in sync is a manual step. A future build could
///   generate one from the other.
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
// Reply Shapes
// ─────────────────────────────────────────────────────────────

/// A successfully interpreted command.
///
/// The [verb] is one of the closed [TissueVerb] values. The [args]
/// list carries the positional arguments the tear-off will receive.
/// The [confidence] is the interpreter's own reliability estimate
/// (0.0–1.0) and is carried for auditing only — the demo does not
/// gate on it.
///
/// ### When to use
///
/// A [TissueCommand] is the "success" arm of an [InterpreterReply].
/// Downstream instructions and dispatch logic consume it whenever
/// the port succeeded.
///
/// ### How it works
///
/// 1. The interpreter builds a [TissueCommand] from the model's
///    JSON reply.
/// 2. The instruction wraps it in a `Pulse<TissueCommand>` and
///    emits it.
/// 3. The dispatch instruction reads the verb and args, looks up
///    the tear-off in its registry, and invokes it.
///
/// ### Args shape
///
/// | Verb | Args shape | Example |
/// |---|---|---|
/// | [TissueVerb.add] | `[value]` | `[3]` |
/// | [TissueVerb.addAll] | `[[values...]]` | `[[4, 5]]` |
/// | [TissueVerb.remove] | `[value]` | `[3]` |
/// | [TissueVerb.removeAll] | `[[values...]]` | `[[4, 5]]` |
/// | [TissueVerb.clear] | `[]` | `[]` |
/// | [TissueVerb.retainAll] | `[[values...]]` | `[[4, 5]]` |
///
/// The dispatch instruction is responsible for casting each arg to
/// the tear-off's expected parameter type. If the cast fails, the
/// dispatch throws and the exception is caught inside
/// `_runDispatch`.
///
/// ### Non-obvious
///
/// - **A [TissueCommand] does not mutate a tissue.** It is a
///   declarative record of a verb and its args. The mutation
///   happens only when a downstream dispatch instruction reads the
///   command and invokes the tear-off. That separation is what
///   makes the command inspectable, loggable, and testable without
///   any collection involvement.
/// - **Confidence is not enforced.** The demo carries it for
///   auditing. A production system could route low-confidence
///   commands to a supervised approval queue.
///
/// ### Example
///
/// ```dart
/// // The interpreter produced this after reading "add 3"
/// final cmd = TissueCommand(
///   verb: TissueVerb.add,
///   args: [3],
///   confidence: 0.95,
///   source: 'add 3',
/// );
///
/// // A downstream filter can check `cmd.ok`:
/// if (cmd.ok) {
///   print('verb=${cmd.verb.name} args=${cmd.args}');
/// }
/// ```
final class TissueCommand {
  /// The verb the interpreter believes the sentence names.
  final TissueVerb verb;

  /// The positional arguments for the verb's tear-off.
  ///
  /// The shape is verb-specific; see the class doc for the table.
  final List<Object?> args;

  /// The interpreter's reliability estimate (0.0–1.0).
  ///
  /// Carried for auditing only. The demo does not gate on this
  /// value. A production system could route low-confidence
  /// commands to a supervised approval queue.
  final double confidence;

  /// The original sentence, carried for the audit trail.
  ///
  /// Useful for reconstructing which operator sentence produced
  /// which command, especially when the interpreter's reply is
  /// ambiguous.
  final String source;

  /// Creates a [TissueCommand].
  ///
  /// All parameters are required. The constructor does not validate
  /// that [args] matches the shape documented for [verb] — that is
  /// the dispatch instruction's job. The constructor is `const` so
  /// commands can be hoisted into compile-time tables when the
  /// model is a fixed lookup.
  const TissueCommand({
    required this.verb,
    required this.args,
    required this.confidence,
    required this.source,
  });

  /// A successful command is always [ok].
  ///
  /// Provided so a downstream filter can write `cmd.ok` rather than
  /// pattern-matching on `TissueCommand` vs [Reject]. This is the
  /// shape the demo's dispatch filter uses:
  ///
  /// ```dart
  /// Flow.filter<Object>(
  ///   interpreted.cell,
  ///   test: (v) => (v as dynamic).ok == true,
  /// );
  /// ```
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
///
/// ### When to use
///
/// A [Reject] is the "failure" arm of an [InterpreterReply].
/// Downstream instructions propagate it as a `Pulse<Reject>` so the
/// filter can drop it and count it.
///
/// ### How it works
///
/// 1. The interpreter builds a [Reject] when the model refused, or
///    when the parser could not resolve the reply into a
///    [TissueCommand].
/// 2. The instruction wraps it in a `Pulse<Reject>` and emits it.
/// 3. The dispatch filter drops the pulse and increments its
///    `rejected` counter.
///
/// ### Common reasons
///
/// | Reason | Meaning |
/// |---|---|
/// | `'no-permitted-verb'` | The sentence names no verb in the closed list. |
/// | `'unknown-verb'` | The model returned a verb string not in [verbByName]. |
/// | `'empty-command'` | The sentence was empty. |
/// | `'interpreter-error'` | The port threw; the instruction wrapped it. |
/// | `'retries-exhausted: ...'` | The retry variant consumed its budget. |
/// | `'empty-reply'` | The port returned neither command nor reject. |
///
/// ### Non-obvious
///
/// A [Reject] is emitted as a *value*, not as a dropped pulse. The
/// downstream filter is what drops it. That means the filter can
/// also count it, which is how the demo's `rejected` counter
/// increments. If the instruction dropped the pulse directly, the
/// counter could never see it.
///
/// ### Example
///
/// ```dart
/// // The interpreter produced this after reading "hack the nucleus"
/// final rejected = Reject(
///   source: 'hack the nucleus',
///   reason: 'no-permitted-verb',
/// );
///
/// // A downstream filter can count rejections:
/// Flow.filter<Object>(
///   interpreted.cell,
///   test: (v) {
///     if (v is Reject) {
///       rejectedCount++;
///       return false;
///     }
///     return v is TissueCommand;
///   },
/// );
/// ```
final class Reject {
  /// The original sentence.
  final String source;

  /// A human-readable reason.
  ///
  /// See the class doc for the common reason table.
  final String reason;

  /// Creates a [Reject].
  const Reject({required this.source, required this.reason});

  /// A [Reject] is never [ok].
  ///
  /// Provided so a downstream filter can write `reject.ok` without
  /// pattern-matching.
  bool get ok => false;

  @override
  String toString() => 'Reject("$source", reason=$reason)';
}

/// The reply from the interpreter port.
///
/// An [InterpreterReply] is either a [TissueCommand] (success) or a
/// [Reject] (failure). The port never returns raw Dart, only these
/// two shapes.
///
/// ### When to use
///
/// Anywhere an interpreter's reply must be consumed. The instruction
/// (`AiTissueCommand`) pattern-matches on the fields; a custom
/// consumer can inspect them directly.
///
/// ### How it works
///
/// Exactly one of `command` and `reject` is non-null in every
/// well-formed reply. The parsers in [HttpInterpreter._parse] and
/// [StubInterpreter._parseEnvelope] guarantee this; the instruction
/// tolerates the edge case where both are null by synthesising a
/// `Reject(reason: 'empty-reply')`.
///
/// ### Non-obvious
///
/// - **Why a record.** A Dart record `({command, reject})` is
///   immutable, cheap to allocate, and pattern-matchable. A sealed
///   class hierarchy would be slightly more type-safe but heavier
///   at the call site. The demo's filter matches on
///   `v is TissueCommand` and `v is Reject` directly, so the record
///   serves the same purpose with less ceremony.
/// - **Both null is possible.** A misbehaving port may return
///   `(command: null, reject: null)`. The instruction synthesises a
///   Reject so the pipeline stays well-formed.
///
/// ### Example
///
/// ```dart
/// final reply = await interpreter.complete(
///   text: 'add 3',
///   verbs: {'add', 'remove', 'clear'},
/// );
///
/// if (reply.command != null) {
///   print('verb=${reply.command!.verb.name}');
/// } else if (reply.reject != null) {
///   print('rejected: ${reply.reject!.reason}');
/// }
/// ```
typedef InterpreterReply = ({TissueCommand? command, Reject? reject});

// ─────────────────────────────────────────────────────────────
// Interpreter Port
// ─────────────────────────────────────────────────────────────

/// The interpreter port — the seam between the NL sentence and the
/// closed verb list.
///
/// A live implementation would call OpenAI / DeepSeek / a browser
/// chatbot and parse its JSON reply. The demo ships a stub table
/// that stands in for the live client. The dispatch instruction
/// never sees either — it only sees the [TissueCommand] the port
/// produces.
///
/// ### When to use
///
/// Anywhere a natural-language sentence must be translated into a
/// closed, machine-validated command. The port is the boundary
/// where I/O lives, so the rest of the pipeline can stay pure.
///
/// ### How it works
///
/// 1. The caller builds a sentence and a closed verb set.
/// 2. The port sends the sentence to the model (or classifies it
///    locally, in the stub's case).
/// 3. The port parses the reply into an [InterpreterReply].
/// 4. The caller consumes the reply.
///
/// ### Implementation contract
///
/// - Implementations **must** return exactly one of
///   `InterpreterReply.command` or `InterpreterReply.reject`, not
///   both.
/// - Implementations **should** honour the `verbs` set by refusing
///   any verb not in it. A live model may not always comply; the
///   parser must check anyway.
/// - Implementations **may** be slow. The instruction awaits the
///   returned [Future] with no timeout of its own; a live
///   interpreter should implement its own timeout (see
///   [HttpInterpreter.timeout]).
///
/// ### Non-obvious
///
/// - **The port never executes Dart code returned by the model.**
///   It only parses a verb string and an args array, then looks the
///   verb up in [verbByName]. A model that returned
///   `"verb": "(x) => x.clear()"` would be rejected with
///   `reason: 'unknown-verb'`.
/// - **The transport label is advisory.** [transport] is used by
///   the demo to distinguish live from offline in the banner. It is
///   not used by the instruction.
/// - **Timeout injection is one-shot.** [injectTimeoutOnce] fires
///   on the next call and clears itself. To exercise a retry loop
///   that needs `count + 1` consecutive failures, call it
///   `count + 1` times.
///
/// ### See Also
///
/// - [HttpInterpreter] — the live HTTP implementation.
/// - [StubInterpreter] — the deterministic offline implementation.
/// - [TissueCommand] — the success reply shape.
/// - [Reject] — the failure reply shape.
/// - [AiConfig] — JSON-file configuration for [HttpInterpreter].
abstract interface class Interpreter {
  /// Ask the interpreter what verb (if any) the [text] names.
  ///
  /// [verbs] is the closed allow-list of verb strings derived from
  /// `TissueSet.modifiable`. The interpreter must not return a verb
  /// outside this list.
  ///
  /// ### How it works
  ///
  /// 1. The interpreter builds a system prompt from [verbs].
  /// 2. It sends the prompt and [text] to the model (or classifies
  ///    locally, in the stub's case).
  /// 3. It parses the reply into an [InterpreterReply].
  /// 4. It returns the reply.
  ///
  /// ### Parameters
  ///
  /// - [text]: **The Sentence.** The natural-language string to
  ///   interpret.
  /// - [verbs]: **The Closed Verb List.** Names allowed to appear
  ///   in the reply.
  ///
  /// ### Returns
  ///
  /// A [Future] resolving to an [InterpreterReply] — either a
  /// [TissueCommand] or a [Reject].
  ///
  /// ### Throws
  ///
  /// A live implementation may throw on transport failures. The
  /// instruction routes those to its `onError` handler and emits a
  /// `Reject(reason: 'interpreter-error')`.
  Future<InterpreterReply> complete({
    required String text,
    required Set<String> verbs,
  });

  /// A short label describing the transport ("http" or "stub").
  ///
  /// Used by the demo to distinguish live mode from offline mode
  /// in the banner. Not used by the instruction itself.
  String get transport;

  /// When called, the NEXT `complete` call throws once.
  ///
  /// Implemented by both HTTP and stub interpreters so scenario 10
  /// behaves identically in offline and live modes.
  ///
  /// ### Non-obvious
  ///
  /// The injection is **one-shot**: it fires once and clears
  /// itself. To exercise a retry loop that needs `count + 1`
  /// consecutive failures, call this method `count + 1` times
  /// before the next `complete`. The demo's
  /// `AiTissueCommandWithRetry` demo does exactly that.
  void injectTimeoutOnce();
}

// ─────────────────────────────────────────────────────────────
// Traffic Logger
// ─────────────────────────────────────────────────────────────

/// Prints HTTP request/response traffic in a human-readable form.
///
/// The logger is **not const** because it holds a small mutable flag
/// (`_promptPrintedOnce`). The first call to [systemPrompt] prints
/// the prompt in full; later calls truncate it, so the console
/// remains readable while still showing the entire security
/// contract at least once.
///
/// ### When to use
///
/// Anywhere a reader needs to audit the interaction between the
/// demo and the AI. The logger is the "show me the bytes on the
/// wire" tool: every prompt, every request body, every response
/// body, every usage block.
///
/// ### How it works
///
/// The interpreters call the logger's methods in this order for
/// each `complete`:
///
/// 1. [systemPrompt] — the system prompt that will be sent.
/// 2. [request] — the HTTP envelope (endpoint, model, sentence,
///    body).
/// 3. [response] — the HTTP status and raw body.
/// 4. [parsed] **or** [refused] — the classified reply.
///
/// If the port throws, [error] is called instead of steps 3–4.
///
/// ### Non-obvious
///
/// - **The logger writes to `stdout` directly.** It has no buffer,
///   no flush, no file target. For a demo, that is what we want.
///   For a production system, replace `_out` with a structured
///   logger call.
/// - **The prompt is printed in full the first time, then
///   truncated.** The first call prints all lines. Every
///   subsequent call prints the first 12 lines and appends
///   `... (N more lines — same prompt as scenario 1)`. That keeps
///   the console readable while guaranteeing the reader sees the
///   full security contract at least once.
/// - **`silent: true` suppresses all output.** Useful for tests.
///   The logger still runs its truncation logic so the first
///   non-silent call behaves correctly.
///
/// ### Example
///
/// ```dart
/// final log = TrafficLog();
/// log.systemPrompt(systemPrompt({'add', 'remove', 'clear'}));
/// log.request(
///   endpoint: 'https://api.deepseek.com/chat/completions',
///   model: 'deepseek-flash',
///   sentence: 'add 3',
///   body: '{"model":"deepseek-flash",...}',
/// );
/// ```
class TrafficLog {
  /// When `true`, the logger suppresses output. Useful when
  /// running tests or when the caller wants only the parsed
  /// result.
  final bool silent;

  bool _promptPrintedOnce = false;

  /// Creates a [TrafficLog].
  ///
  /// ### Parameters
  ///
  /// - [silent]: **Suppress Output.** When `true`, no line is
  ///   printed. Defaults to `false`.
  TrafficLog({this.silent = false});

  void _out(String line) {
    if (!silent) print(line);
  }

  /// Prints the system prompt that will be sent.
  ///
  /// The first call prints the prompt in full; later calls
  /// truncate to the first 12 lines and note how many are hidden.
  /// See the class doc for the truncation policy.
  ///
  /// ### Parameters
  ///
  /// - [prompt]: **The Prompt.** The string the interpreter will
  ///   send as the `system` message.
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
  ///
  /// ### Parameters
  ///
  /// - [endpoint]: **The Endpoint URL.** The full URL the request
  ///   was POSTed to.
  /// - [model]: **The Model ID.** The value the caller set in
  ///   `AI_MODEL`.
  /// - [sentence]: **The Operator Sentence.** The natural-language
  ///   input.
  /// - [body]: **The JSON Body.** The full request body. Printed
  ///   line by line via [LineSplitter] so a single-line JSON
  ///   envelope wraps neatly in the box drawing.
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
  ///
  /// ### Parameters
  ///
  /// - [status]: **The HTTP Status.** e.g. `200`, `429`, `500`.
  /// - [body]: **The Raw Response Body.** Printed line by line via
  ///   [LineSplitter], same as [request].
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
  ///
  /// Called by the interpreter after a successful parse so the
  /// reader sees what the instruction will act on, separate from
  /// the raw HTTP body.
  ///
  /// ### Parameters
  ///
  /// - [cmd]: **The Parsed Command.** The [TissueCommand] the
  ///   parser produced.
  void parsed(TissueCommand cmd) {
    _out('    ┌─ PARSED ───────────────────────────────────────────────');
    _out('    │ verb: ${cmd.verb.name}');
    _out('    │ args: ${cmd.args}');
    _out('    │ confidence: ${cmd.confidence}');
    _out('    └────────────────────────────────────────────────────────');
  }

  /// Prints a rejection reason.
  ///
  /// Called by the interpreter when the model returned a structured
  /// `{"verb":"reject","reason":"..."}` reply, or when the parser
  /// could not resolve the reply into a [TissueCommand].
  ///
  /// ### Parameters
  ///
  /// - [reason]: **The Refusal Reason.** A short human-readable
  ///   string. See [Reject] for common values.
  void refused(String reason) {
    _out('    ┌─ REFUSED ──────────────────────────────────────────────');
    _out('    │ reason: $reason');
    _out('    └────────────────────────────────────────────────────────');
  }

  /// Prints an exception from the interpreter or its parser.
  ///
  /// Called by the harness's `onError` handler when the port
  /// throws. The exception's `toString` is printed; a full stack
  /// trace is not, because the demo's console budget does not
  /// warrant it.
  ///
  /// ### Parameters
  ///
  /// - [e]: **The Exception.** Any object; its `toString` is
  ///   printed.
  void error(Object e) {
    _out('    ┌─ ERROR ────────────────────────────────────────────────');
    _out('    │ $e');
    _out('    └────────────────────────────────────────────────────────');
  }
}

// ─────────────────────────────────────────────────────────────
// AI Prompt
// ─────────────────────────────────────────────────────────────

/// Builds the system prompt sent to the live AI chatbot.
///
/// The prompt establishes the closed verb list and the JSON reply
/// shape. The instruction does not trust the model beyond parsing
/// this shape; an unrecognized verb is discarded.
///
/// ### When to use
///
/// Called by [HttpInterpreter.complete] and
/// [StubInterpreter.complete] to produce the `system` message. A
/// custom interpreter may reuse it to keep the same contract.
///
/// ### How it works
///
/// The prompt has four sections, in this order:
///
/// 1. **Role definition** (4 lines) — tells the model what it is
///    doing and why.
/// 2. **Closed verb list** (N lines) — tells the model what verbs
///    are available. The list comes from the [verbs] parameter;
///    the prompt does not hardcode a second copy.
/// 3. **Reply shape** (2 lines × 2 shapes) — tells the model what
///    JSON to produce. Both the success shape and the refusal
///    shape are shown.
/// 4. **Rules** (7 lines) — enumerates edge cases the model would
///    otherwise guess wrong: single-element verbs use a 1-element
///    array, multi-element verbs use a nested array, zero-arg
///    verbs use `[]`, never invent a verb, never return code.
///
/// ### Non-obvious
///
/// - **The prompt is the security contract.** Trimming it would
///   weaken the guarantee that the model's reply can be parsed by
///   the strict shape the instruction enforces.
/// - **Verbs are listed in sorted order.** Sorting makes the
///   prompt deterministic for a given verb set, which is useful
///   for caching and diffing. It does not affect the model's
///   choice.
/// - **The prompt is bounded by the caller's verb set.** A caller
///   that passes `{'add'}` gets a prompt listing only `add`. The
///   prompt does not leak verbs the caller did not authorise.
///
/// ### Example
///
/// ```dart
/// final prompt = systemPrompt({'add', 'remove', 'clear'});
/// // Prompt lists only these three verbs, in sorted order:
/// //   - add
/// //   - clear
/// //   - remove
/// ```
///
/// ### Parameters
///
/// - [verbs]: **The Closed Verb List.** Names the model is allowed
///   to return.
///
/// ### Returns
///
/// The complete system prompt as a `String`.
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
// AI Config
// ─────────────────────────────────────────────────────────────

/// A JSON-shaped configuration for an [HttpInterpreter].
///
/// [AiConfig] bundles the three settings every OpenAI-compatible
/// endpoint needs — the URL, the bearer token, and the model ID —
/// plus an optional per-request timeout and an optional
/// `extraBody` map merged into the request envelope.
///
/// ### When to use
///
/// Use this when the demo (or any host process) wants to read its
/// AI settings from a JSON file instead of environment variables.
/// The two sources are interchangeable: [AiConfig.fromJson] produces
/// the same values `Platform.environment` would, and either can
/// build an [HttpInterpreter].
///
/// ### How it works
///
/// 1. [fromJson] validates the three required keys and returns an
///    [AiConfig].
/// 2. [fromJsonFile] reads the file and delegates to [fromJson].
/// 3. [toInterpreter] builds an [HttpInterpreter] from the config.
/// 4. [toJson] round-trips the config back to a JSON-shaped map.
///
/// ### JSON shape
///
/// ```json
/// {
///   "endpoint": "https://api.deepseek.com/chat/completions",
///   "apiKey": "sk-your-deepseek-key",
///   "model": "deepseek-flash",
///   "timeoutSeconds": 30,
///   "extraBody": { "seed": 42 }
/// }
/// ```
///
/// ### Non-obvious
///
/// - **`extraBody` is merged into the request envelope.** It can
///   add `seed`, `top_p`, `max_tokens`, or any provider-specific
///   field. It cannot override `model`, `messages`,
///   `temperature`, or `response_format` — those are set by the
///   interpreter after the merge.
/// - **`apiKey` is required.** There is no "anonymous" mode in
///   this build. A caller that wants to run without a key should
///   use [StubInterpreter] directly.
/// - **`timeoutSeconds` is optional.** Omitting it uses the
///   interpreter's own default of 30 seconds.
///
/// ### No Environment Fallback
///
/// When a config is supplied, the resulting interpreter reads
/// **only** the values in this config. It does not consult
/// `Platform.environment` and it does not merge with
/// `AI_ENDPOINT`, `AI_API_KEY`, or `AI_MODEL`. That is deliberate:
/// a host that supplies a config file is declaring its intent
/// explicitly, and silent env-var substitution would mean the same
/// file produced different behaviour on two machines.
///
/// If you want env-var fallback, do it before constructing the
/// config:
///
/// ```dart
/// final merged = {
///   if (Platform.environment['AI_ENDPOINT'] != null)
///     'endpoint': Platform.environment['AI_ENDPOINT'],
///   if (Platform.environment['AI_API_KEY'] != null)
///     'apiKey': Platform.environment['AI_API_KEY'],
///   if (Platform.environment['AI_MODEL'] != null)
///     'model': Platform.environment['AI_MODEL'],
///   ...fileConfig,
/// };
/// final config = AiConfig.fromJson(merged);
/// ```
///
/// That way the precedence is under your control, not hidden
/// inside the instruction.
///
/// ### See Also
///
/// - [HttpInterpreter] — the interpreter this config builds.
/// - [StubInterpreter] — the offline alternative.
final class AiConfig {
  /// The chat-completions endpoint URL.
  final Uri endpoint;

  /// The bearer token.
  final String apiKey;

  /// The model identifier.
  final String model;

  /// Per-request timeout. Defaults to 30 seconds.
  final Duration timeout;

  /// Optional extra fields merged into the request envelope.
  ///
  /// Keys in this map are added to the JSON body sent to the
  /// endpoint. They cannot override the four keys the interpreter
  /// sets (`model`, `messages`, `temperature`, `response_format`).
  final Map<String, dynamic> extraBody;

  /// Creates an [AiConfig].
  const AiConfig({
    required this.endpoint,
    required this.apiKey,
    required this.model,
    this.timeout = const Duration(seconds: 30),
    this.extraBody = const {},
  });

  /// Builds an [AiConfig] from a decoded JSON map.
  ///
  /// ### Required keys
  ///
  /// | Key | Type | Notes |
  /// |---|---|---|
  /// | `endpoint` | `String` | Parsed via [Uri.parse]. Must be non-empty. |
  /// | `apiKey` | `String` | Must be non-empty. No env-var fallback. |
  /// | `model` | `String` | Must be non-empty. No env-var fallback. |
  ///
  /// ### Optional keys
  ///
  /// | Key | Type | Notes |
  /// |---|---|---|
  /// | `timeoutSeconds` | `int` | Defaults to 30. |
  /// | `extraBody` | `Map<String, dynamic>` | Defaults to `{}`. |
  ///
  /// ### Throws
  ///
  /// A [FormatException] if any required key is missing or has the
  /// wrong type.
  ///
  /// ### No Environment Fallback
  ///
  /// When this method is called via [fromJsonFile] or
  /// `AiTissueCommand.fromConfig(...)`, the resulting interpreter
  /// reads **only** the values in this JSON. It does not consult
  /// `Platform.environment` and it does not merge with
  /// `AI_ENDPOINT`, `AI_API_KEY`, or `AI_MODEL`.
  factory AiConfig.fromJson(Map<String, dynamic> json) {
    final endpoint = json['endpoint'];
    if (endpoint is! String || endpoint.isEmpty) {
      throw const FormatException(
        'AiConfig: "endpoint" is required and must be a non-empty '
            'String. No env-var fallback is performed when a config is '
            'supplied.',
      );
    }

    final apiKey = json['apiKey'];
    if (apiKey is! String || apiKey.isEmpty) {
      throw const FormatException(
        'AiConfig: "apiKey" is required and must be a non-empty '
            'String. No env-var fallback is performed when a config is '
            'supplied.',
      );
    }

    final model = json['model'];
    if (model is! String || model.isEmpty) {
      throw const FormatException(
        'AiConfig: "model" is required and must be a non-empty '
            'String. No env-var fallback is performed when a config is '
            'supplied.',
      );
    }

    final timeoutSeconds = json['timeoutSeconds'];
    final timeout = timeoutSeconds is int && timeoutSeconds > 0
        ? Duration(seconds: timeoutSeconds)
        : const Duration(seconds: 30);

    final extraBodyRaw = json['extraBody'];
    final extraBody = extraBodyRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(extraBodyRaw)
        : const <String, dynamic>{};

    return AiConfig(
      endpoint: Uri.parse(endpoint),
      apiKey: apiKey,
      model: model,
      timeout: timeout,
      extraBody: extraBody,
    );
  }

  /// Reads a JSON file and builds an [AiConfig] from its contents.
  ///
  /// ### Parameters
  ///
  /// - [path]: **The File Path.** Relative to the current working
  ///   directory or absolute. The file must be UTF-8 encoded JSON
  ///   whose top-level value is an object.
  ///
  /// ### Throws
  ///
  /// - [FileSystemException] if the file cannot be read.
  /// - [FormatException] if the JSON is malformed or missing
  ///   required keys.
  static AiConfig fromJsonFile(String path) {
    final file = File(path);
    final raw = file.readAsStringSync();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'AiConfig: file must contain a top-level JSON object',
      );
    }
    return AiConfig.fromJson(decoded);
  }

  /// Builds an [HttpInterpreter] from this config.
  ///
  /// ### No Environment Fallback
  ///
  /// The returned interpreter reads **only** the fields on this
  /// config. It does not consult `Platform.environment` at runtime
  /// and it does not merge with `AI_ENDPOINT`, `AI_API_KEY`, or
  /// `AI_MODEL`. Every value the interpreter uses comes from
  /// [endpoint], [apiKey], [model], [timeout], and [extraBody].
  ///
  /// ### Parameters
  ///
  /// - [client]: Optional HTTP client. If omitted, the interpreter
  ///   creates its own and the caller must close it via
  ///   [HttpInterpreter.close].
  /// - [log]: Optional traffic logger. If omitted, a fresh
  ///   non-silent logger is created.
  ///
  /// ### Returns
  ///
  /// A fully configured [HttpInterpreter].
  HttpInterpreter toInterpreter({
    HttpClient? client,
    TrafficLog? log,
  }) =>
      HttpInterpreter(
        endpoint: endpoint,
        apiKey: apiKey,
        model: model,
        timeout: timeout,
        client: client,
        log: log,
        extraBody: extraBody,
      );

  /// Converts this config back to a JSON-shaped map.
  ///
  /// Useful for writing a template config file or for logging the
  /// active configuration with the API key redacted by the caller.
  Map<String, dynamic> toJson() => {
    'endpoint': endpoint.toString(),
    'apiKey': apiKey,
    'model': model,
    'timeoutSeconds': timeout.inSeconds,
    if (extraBody.isNotEmpty) 'extraBody': extraBody,
  };

  @override
  String toString() =>
      'AiConfig(endpoint: $endpoint, model: $model, '
          'timeout: ${timeout.inSeconds}s, '
          'extraBodyKeys: ${extraBody.keys.toList()})';
}

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

// ─────────────────────────────────────────────────────────────
// Offline Stub Interpreter
// ─────────────────────────────────────────────────────────────

/// A deterministic offline interpreter that simulates the HTTP
/// traffic a live chatbot would produce.
///
/// ### When to use
///
/// Use this when the demo runs without a key, in tests, or in
/// contexts where network access is not available. It produces the
/// same reply shape a live chatbot would produce, so the rest of
/// the pipeline is unchanged.
///
/// ### How it works
///
/// The stub runs a small set of regular expressions over the
/// sentence:
///
/// - `^addall(?: (.*))?$` → [TissueVerb.addAll]
/// - `^(?:please )?(?:add|insert) (-?\d+)(?: .*)?$` →
///   [TissueVerb.add]
/// - `^(?:please )?(?:remove|delete) (-?\d+)(?: .*)?$` →
///   [TissueVerb.remove]
/// - `^(?:please )?(?:clear|delete everything|empty)(?: .*)?$` →
///   [TissueVerb.clear]
/// - anything else → [Reject] with reason `'no-permitted-verb'`
///
/// The patterns are intentionally narrow. The point of the demo
/// is not to build a robust NLU; it is to show the seam between
/// interpretation and dispatch. A live model would be far more
/// forgiving with phrasing; the stub is deliberately not, so the
/// demo's console output is deterministic.
///
/// ### Non-obvious
///
/// - **The stub honours the verb set.** If the caller excludes a
///   verb, the stub will not return it, and the sentence falls
///   through to the `reject` case. That is how the demo proves
///   the closed-vocabulary contract works even in offline mode.
/// - **The stub prints synthetic traffic.** Every `complete` call
///   logs a system prompt, a synthetic request body, and a
///   synthetic OpenAI-shaped response body, so the console output
///   is identical in structure whether the demo is running
///   offline or live.
/// - **`latency` is configurable.** The default is 1ms so the
///   async pipeline is exercised. Set to [Duration.zero] in the
///   production-shaped demo so the console output is
///   deterministic.
///
/// ### Example
///
/// ```dart
/// final stub = StubInterpreter(latency: Duration.zero);
///
/// final reply = await stub.complete(
///   text: 'add 3',
///   verbs: {'add', 'remove', 'clear'},
/// );
///
/// print(reply.command!.verb.name);  // 'add'
/// print(reply.command!.args);       // [3]
/// ```
///
/// ### See Also
///
/// - [HttpInterpreter] — the live HTTP implementation.
/// - [Interpreter] — the port contract.
class StubInterpreter implements Interpreter {
  int _pendingTimeouts = 0;

  /// Artificial latency (per call).
  ///
  /// Used by the demo's `AiTissueCommand` self-tests to exercise
  /// the async pipeline. Set to [Duration.zero] in the
  /// production-shaped demo
  /// (`nl-instruction-tissue-set-enhanced-Demo.dart`) so the
  /// console output is deterministic.
  Duration latency;

  /// The traffic logger.
  final TrafficLog log;

  /// A fake endpoint label shown in the synthetic request line.
  final String syntheticEndpoint;

  /// A fake model name shown in the synthetic request body.
  final String syntheticModel;

  /// Creates a [StubInterpreter].
  ///
  /// ### Parameters
  ///
  /// - [latency]: **Optional.** Artificial per-call latency.
  ///   Defaults to 1 millisecond.
  /// - [log]: **Optional.** The traffic logger. If omitted, a fresh
  ///   non-silent logger is created.
  /// - [syntheticEndpoint]: **Optional.** The endpoint label
  ///   printed in the synthetic request line. Defaults to
  ///   `'stub://offline/chat/completions'`.
  /// - [syntheticModel]: **Optional.** The model label printed in
  ///   the synthetic request body. Defaults to `'stub-model'`.
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
    _pendingTimeouts++;
  }

  @override
  Future<InterpreterReply> complete({
    required String text,
    required Set<String> verbs,
  }) async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }

    if (_pendingTimeouts > 0) {
      _pendingTimeouts--;
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
  ///
  /// ### Parameters
  ///
  /// - [text]: **The Sentence.** The natural-language input.
  /// - [verbs]: **The Closed Verb List.** The stub will not return a
  ///   verb outside this set.
  ///
  /// ### Returns
  ///
  /// A JSON string in the reply shape the model would produce.
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
  ///
  /// ### Parameters
  ///
  /// - [raw]: **The Raw Body.** The JSON response body.
  /// - [source]: **The Original Sentence.** Carried into the
  ///   Reject so the caller can reconstruct which sentence failed.
  ///
  /// ### Returns
  ///
  /// An [InterpreterReply] — either a [TissueCommand] or a
  /// [Reject].
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

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Interpreter] port, the two reply shapes,
/// the traffic logger, and the [AiConfig] JSON loader, showing
/// their behaviour in isolation.
///
/// ### Expected console output
///
/// ```text
/// ── AI Tissue Command Domain Demo ───────────────────────────────
///
/// 1. Closed verb list
///    verbByName['add'] = TissueVerb.add
///    verbByName['bogus'] = null
///
/// 2. TissueCommand reply shape
///    ok=true verb=add args=[3] conf=0.95
///
/// 3. Reject reply shape
///    ok=false reason=no-permitted-verb
///
/// 4. StubInterpreter — one sentence
///    command=add args=[3]
///
/// 5. StubInterpreter — with a refusal
///    reject=no-permitted-verb
///
/// 6. StubInterpreter — with a timeout injection
///    error=TimeoutException: injected timeout (scenario 10)
///
/// 7. AiConfig round-trip
///    fromJson: AiConfig(endpoint: https://..., model: ..., ...)
///    toJson: {"endpoint":"...","apiKey":"...","model":"...","timeoutSeconds":30}
///
/// 8. AiConfig — missing required key
///    FormatException: AiConfig: "apiKey" is required ...
///
/// 9. Live HTTP interpreter
///    (skipped — pass --live with AI_ENDPOINT/AI_API_KEY to run)
///
/// ── finished ────────────────────────────────────────────────────
/// ```
///
/// ### How to run
///
/// Offline (default):
///
///     dart run ai_tissue_command_domain.dart
///
/// Live (same three env vars the full demo uses):
///
///     export AI_ENDPOINT=https://api.deepseek.com/chat/completions
///     export AI_API_KEY=sk-your-deepseek-key
///     export AI_MODEL=deepseek-flash
///     dart run ai_tissue_command_domain.dart --live
///
/// ### What it demonstrates
///
/// 1. **Closed verb list** — [verbByName] resolves known verbs to
///    [TissueVerb] values and returns `null` for unknown strings.
/// 2. **TissueCommand reply shape** — [TissueCommand.ok] is `true`.
/// 3. **Reject reply shape** — [Reject.ok] is `false`.
/// 4. **StubInterpreter success path** — a sentence produces a
///    [TissueCommand].
/// 5. **StubInterpreter refusal path** — an unrecognised sentence
///    produces a [Reject].
/// 6. **StubInterpreter timeout injection** — [injectTimeoutOnce]
///    causes the next call to throw.
/// 7. **AiConfig round-trip** — a JSON map becomes an [AiConfig]
///    and back.
/// 8. **AiConfig validation** — a missing required key throws a
///    [FormatException].
/// 9. **Live HTTP interpreter** — when `--live` is passed, the
///    demo sends one sentence to the endpoint and prints the reply.
///
/// ### Key takeaways
///
/// - The domain is portable. It has no dependency on `cell`,
///   `cell_flow`, or `cell_tissue`.
/// - The verb list is closed. The interpreter cannot return a verb
///   outside [verbByName].
/// - The traffic logger is the same in both offline and live modes,
///   so the console output is identical in structure.
/// - When a config is supplied, no environment variable is
///   consulted.
Future<void> main(List<String> args) async {
  final live = args.contains('--live');

  print('── AI Tissue Command Domain Demo ──────────────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────
  // 1. Closed verb list
  // ─────────────────────────────────────────────────────────────────────
  print('1. Closed verb list');

  print('   verbByName[\'add\'] = ${verbByName['add']}');
  print('   verbByName[\'bogus\'] = ${verbByName['bogus']}');
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 2. TissueCommand reply shape
  // ─────────────────────────────────────────────────────────────────────
  print('2. TissueCommand reply shape');

  const cmd = TissueCommand(
    verb: TissueVerb.add,
    args: [3],
    confidence: 0.95,
    source: 'add 3',
  );
  print('   ok=${cmd.ok} verb=${cmd.verb.name} '
      'args=${cmd.args} conf=${cmd.confidence}');
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 3. Reject reply shape
  // ─────────────────────────────────────────────────────────────────────
  print('3. Reject reply shape');

  const reject = Reject(
    source: 'hack the nucleus',
    reason: 'no-permitted-verb',
  );
  print('   ok=${reject.ok} reason=${reject.reason}');
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 4. StubInterpreter — one sentence
  // ─────────────────────────────────────────────────────────────────────
  print('4. StubInterpreter — one sentence');

  final stub = StubInterpreter(
    latency: Duration.zero,
    log: TrafficLog(silent: true),
  );
  final r4 = await stub.complete(
    text: 'add 3',
    verbs: <String>{...verbByName.keys},
  );
  if (r4.command != null) {
    print('   command=${r4.command!.verb.name} '
        'args=${r4.command!.args}');
  } else {
    print('   reject=${r4.reject!.reason}');
  }
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 5. StubInterpreter — with a refusal
  // ─────────────────────────────────────────────────────────────────────
  print('5. StubInterpreter — with a refusal');

  final stub2 = StubInterpreter(
    latency: Duration.zero,
    log: TrafficLog(silent: true),
  );
  final r5 = await stub2.complete(
    text: 'hack the nucleus',
    verbs: <String>{...verbByName.keys},
  );
  if (r5.command != null) {
    print('   command=${r5.command!.verb.name}');
  } else {
    print('   reject=${r5.reject!.reason}');
  }
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 6. StubInterpreter — with a timeout injection
  // ─────────────────────────────────────────────────────────────────────
  print('6. StubInterpreter — with a timeout injection');

  final stub3 = StubInterpreter(
    latency: Duration.zero,
    log: TrafficLog(silent: true),
  );
  stub3.injectTimeoutOnce();
  try {
    await stub3.complete(
      text: 'add 5',
      verbs: <String>{...verbByName.keys},
    );
    print('   (no error — unexpected)');
  } catch (e) {
    print('   error=$e');
  }
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 7. AiConfig round-trip
  // ─────────────────────────────────────────────────────────────────────
  print('7. AiConfig round-trip');

  final config = AiConfig(
    endpoint: Uri.parse('https://api.deepseek.com/chat/completions'),
    apiKey: 'sk-demo-key',
    model: 'deepseek-flash',
    timeout: Duration(seconds: 30),
    extraBody: {'seed': 42},
  );
  final json = config.toJson();
  final round = AiConfig.fromJson(json);
  print('   fromJson: $round');
  print('   toJson: $json');
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 8. AiConfig — missing required key
  // ─────────────────────────────────────────────────────────────────────
  print('8. AiConfig — missing required key');

  try {
    AiConfig.fromJson({
      'endpoint': 'https://api.deepseek.com/chat/completions',
      // apiKey omitted
      'model': 'deepseek-flash',
    });
    print('   (no error — unexpected)');
  } catch (e) {
    print('   ${e.runtimeType}: '
        '${e.toString().split('\n').first}');
  }
  print('');

  // ─────────────────────────────────────────────────────────────────────
  // 9. Live HTTP interpreter
  // ─────────────────────────────────────────────────────────────────────
  print('9. Live HTTP interpreter');

  if (!live) {
    print('   (skipped — pass --live with AI_ENDPOINT/AI_API_KEY '
        'to run)');
  } else {
    final endpoint = Platform.environment['AI_ENDPOINT'];
    final apiKey = Platform.environment['AI_API_KEY'];
    final model = Platform.environment['AI_MODEL'] ?? 'gpt-4o-mini';

    if (endpoint == null || apiKey == null) {
      print('   (live mode requested but AI_ENDPOINT/AI_API_KEY '
          'missing — skipped)');
    } else {
      final http = HttpInterpreter(
        endpoint: Uri.parse(endpoint),
        apiKey: apiKey,
        model: model,
      );
      try {
        final r9 = await http.complete(
          text: 'add 7',
          verbs: <String>{...verbByName.keys},
        );
        if (r9.command != null) {
          print('   command=${r9.command!.verb.name} '
              'args=${r9.command!.args} '
              'conf=${r9.command!.confidence}');
        } else {
          print('   reject=${r9.reject!.reason}');
        }
      } finally {
        http.close();
      }
    }
  }
  print('');

  print('── finished ────────────────────────────────────────────────────');
}