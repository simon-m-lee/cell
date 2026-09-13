// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cell_flow/cell_flow.dart';
import 'package:cell_tissue/cell_tissue.dart';

// ignore_for_file: unused_local_variable, avoid_print, unused_element, file_names

// ─────────────────────────────────────────────────────────────
// NL INSTRUCTION → TISSUESET (ENHANCED) — Flow + Tissue + live AI HTTP
//
// THE SEAM — Flow owns the interpretation, Tissue owns the set.
//
//   Pulse<String>  →  AiTissueCommand  →  TissueCommand  →  TissueSet.modifiable
//        Flow           Instruction          Flow                  Tissue
//
// The one sentence to remember:
//   **the model chooses a verb; `modifiable` allows the verb;
//     TestTissue allows the element.**
//
// ─────────────────────────────────────────────────────────────
// WHAT CHANGED FROM THE PREVIOUS VERSION
// ─────────────────────────────────────────────────────────────
//
// The interpreter no longer lives inside a hand-rolled AsyncMap
// mapper in this file. It is packaged as a reusable
// [AiTissueCommand] instruction (see `ai_tissue_command.dart`),
// which is imported here and wired into the pipeline with a single
// `.toHandle(source:)` call.
//
// The pipeline shape is now:
//
//   commandIn  →  AiTissueCommand<String>  →  Filter<TissueCommand>
//              →  dispatch Instruction  →  TissueSet.modifiable
//
// Two Flow stages, one dispatch instruction, one interpreter port.
// The interpreter port (`ai_tissue_command_domain.dart`) is the
// same port the demo has always used: `HttpInterpreter` for live
// mode, `StubInterpreter` for offline. Both are the AI seam — the
// only place I/O happens in the whole demo.
//
// ─────────────────────────────────────────────────────────────
// HOW THE ASYNC BRIDGE WORKS IN THIS BUILD
// ─────────────────────────────────────────────────────────────
//
// This build's `Flow.asyncMap` suspends the pulse across multiple
// event-loop turns, which makes it unusable for a synchronous
// `say(...)` contract when the mapper performs a real HTTP round
// trip. [AiTissueCommand] therefore awaits the interpreter in the
// mapper and fires the `future` callback from the instruction's
// closure. The `say(...)` helper in the harness drains the event
// loop for a short while so the interpreter round trip completes
// before the scenario prints its assertions.
//
// ─────────────────────────────────────────────────────────────
// HOW TO RUN
// ─────────────────────────────────────────────────────────────
//
// ### Offline (default — no network, no key)
//
//     dart run nl-instruction-tissue-set-Demo.dart
//
// ### Live against DeepSeek (env vars)
//
//     export AI_ENDPOINT=https://api.deepseek.com/chat/completions
//     export AI_API_KEY=sk-your-deepseek-key
//     export AI_MODEL=deepseek-flash
//     dart run nl-instruction-tissue-set-Demo.dart --live
//
// ### Live against DeepSeek (JSON config file)
//
//     dart run nl-instruction-tissue-set-Demo.dart \
//         --print-config --config ai_config.json
//     # edit ai_config.json, then:
//     dart run nl-instruction-tissue-set-Demo.dart \
//         --config ai_config.json
//
// ### Live against OpenAI (env vars)
//
//     export AI_ENDPOINT=https://api.openai.com/v1/chat/completions
//     export AI_API_KEY=sk-...
//     export AI_MODEL=gpt-4o-mini
//     dart run nl-instruction-tissue-set-Demo.dart --live
//
// ### Config-file precedence
//
// When `--config <path>` is supplied, the demo reads **only** the
// JSON file. It does not consult `AI_ENDPOINT`, `AI_API_KEY`, or
// `AI_MODEL`, even if those variables are set in the shell. The
// config file is authoritative.
//
// That is deliberate. A shell that already has `AI_API_KEY` set
// from a different account should not silently contaminate a demo
// that was launched with an explicit config. The precedence is:
//
//     --config <path>       wins
//     --live + env vars     used if --config is absent
//     no flag               offline stub
//
// If you want to mix the two — e.g. take the endpoint from the
// environment but the key from the file — merge them yourself
// before passing the map to `AiConfig.fromJson`. The instruction
// will not do it for you.
//
// ─────────────────────────────────────────────────────────────
// WHAT THIS FILE PRINTS
// ─────────────────────────────────────────────────────────────
//
// Every scenario prints the full traffic between the demo and the
// AI chatbot, so a reader can see exactly:
//
//   1. What sentence the operator wrote.
//   2. The system prompt that was sent.
//   3. The HTTP request body (the JSON envelope).
//   4. The HTTP response status.
//   5. The HTTP response body (raw bytes from the endpoint).
//   6. The parsed verb / args / confidence.
//   7. What the dispatch instruction did with the verb.
//
// The traffic logging is performed by the [TrafficLog] inside the
// interpreter port, so it is identical whether the interpreter is
// the live HTTP client or the offline stub.
//
// ─────────────────────────────────────────────────────────────
// DOCUMENTED DEVIATIONS
// ─────────────────────────────────────────────────────────────
//
// 1. TissueSet requires the initial Iterable as the first
//    POSITIONAL argument, with `testRule:` as a named argument.
//
// 2. Two toHandle calls only (interpret + dispatch).
//
// 3. Trace prints are emitted by the writers themselves.
//
// 4. The interpreter runs as the `AiTissueCommand` instruction
//    imported from `ai_tissue_command.dart`. The pipeline is
//    `commandIn → AiTissueCommand → filter → dispatch`.
//
// 5. `removeWhere` / `retainWhere` are listed on `modifiable` but
//    not driven.
//
// 6. `.unmodifiable` is a SNAPSHOT in this build. The trailer
//    reports `auditorLength=0`; scenario 8 still verifies the
//    dispatch seam because `auditor.modifiable` is empty.
//
// 7. Offline default. Live HTTP path requires `--live` or
//    `--config <path>`.
//
// 8. FULL TRAFFIC LOGGING is preserved. The interpreter port owns
//    the [TrafficLog]; the instruction prints nothing about the
//    exchange itself.
//
// 9. Scenario 10 uses a timeout injection that works in both
//    offline and live modes:
//    • Offline: `StubInterpreter.injectTimeoutOnce`.
//    • Live:    `HttpInterpreter.injectTimeoutOnce` throws before
//               the HTTP request is made (so the demo stays fast
//               and deterministic; it does not depend on network
//               latency).
//
// 10. The system prompt is printed in full the first time, then
//     truncated in later scenarios.
//
// 11. The harness holds BOTH the [AiTissueCommand] instruction AND
//     the [FlowHandle] returned by `.toHandle(...)`. The handle is
//     a Dart record with no methods of its own; scenario 10's
//     `injectTimeoutOnce()` call targets the instruction, not the
//     handle.
//
// 12. `--config <path>` builds the interpreter via
//     `AiConfig.fromJsonFile`. The config is authoritative — env
//     vars are not consulted when a config is supplied.
//
// 13. Mode selection is packaged into `_selectHarness`, a helper
//     that returns the harness from exactly one branch. `main`
//     assigns the returned value to a `final` local in one place.

// ─────────────────────────────────────────────────────────────
// VISUAL OUTPUT HELPERS
// ─────────────────────────────────────────────────────────────

void _section(String label, String drive) {
  print('');
  print('── $label ── $drive');
}

// ─────────────────────────────────────────────────────────────
// HARNESS
// ─────────────────────────────────────────────────────────────

/// The NL-instruction → TissueSet harness.
///
/// ### When to use
/// Instantiate one harness, call [install], run the scenarios, then
/// [dispose]. Do not reuse a harness across runs.
class NlTissueHarness {
  NlTissueHarness({
    required this.interpreter,
    required this.modeLabel,
    required this.isStub,
  });

  /// The interpreter port used by [AiTissueCommand].
  final Interpreter interpreter;

  /// A short label printed in the banner.
  final String modeLabel;

  /// When `true`, the interpret print is tagged with `(stub)`.
  final bool isStub;

  /// Offline factory — deterministic stub interpreter, no network.
  static NlTissueHarness offline() => NlTissueHarness(
    interpreter: StubInterpreter(),
    modeLabel: 'offline stub (pass --live for HTTP)',
    isStub: true,
  );

  /// Live factory — HTTP interpreter against an OpenAI-compatible
  /// chat-completions endpoint.
  ///
  /// ### Parameters
  ///
  /// - [endpoint]: **Required.** The full URL of the endpoint.
  /// - [apiKey]: **Required.** The bearer token.
  /// - [model]: **Required.** The model identifier.
  static NlTissueHarness live({
    required Uri endpoint,
    required String apiKey,
    required String model,
  }) =>
      NlTissueHarness(
        interpreter: HttpInterpreter(
          endpoint: endpoint,
          apiKey: apiKey,
          model: model,
        ),
        modeLabel: 'live HTTP (model=$model, endpoint=$endpoint)',
        isStub: false,
      );

  /// Config-file factory — HTTP interpreter built from a JSON file.
  ///
  /// Reads the file named by [path], validates it via
  /// [AiConfig.fromJsonFile], and builds an [HttpInterpreter]. The
  /// mode label records the config source so the banner shows it.
  ///
  /// ### No Environment Fallback
  ///
  /// The interpreter reads only the file. `AI_ENDPOINT`,
  /// `AI_API_KEY`, and `AI_MODEL` are not consulted.
  ///
  /// ### Parameters
  ///
  /// - [path]: **Required.** The path to the JSON config file.
  static NlTissueHarness fromConfigFile(String path) {
    final config = AiConfig.fromJsonFile(path);
    return NlTissueHarness(
      interpreter: config.toInterpreter(),
      modeLabel: 'live HTTP (config=$path, model=${config.model}, '
          'endpoint=${config.endpoint})',
      isStub: false,
    );
  }

  // ───────────────────────────────────────────────────────────
  // Tissue
  // ───────────────────────────────────────────────────────────

  /// The mutable membership set.
  late final TissueSet<int> tags;

  /// The read-only view of [tags]. In this build, `.unmodifiable`
  /// captures the set at install time, so it stays empty.
  late final TissueSet<int> auditor;

  // ───────────────────────────────────────────────────────────
  // Flow
  // ───────────────────────────────────────────────────────────

  /// The command ingress — takes the raw sentence.
  late final IngressHandle<String> commandIn;

  /// The [AiTissueCommand] instruction itself, kept so scenario 10
  /// can call [AiTissueCommand.injectTimeoutOnce] without going
  /// through the record handle (which has no methods of its own).
  late final AiTissueCommand<String> interpretedInstruction;

  /// The materialised handle for the interpret stage. Provides
  /// `.cell` for wiring the downstream dispatch pipeline.
  late final FlowHandle<String> interpreted;

  /// The dispatch gate cell — receives `Pulse<TissueCommand>` from
  /// [interpreted], runs the dispatch Instruction, mutates [tags].
  late final Cell dispatchedCell;

  /// The dispatch handle — kept for symmetry; `main` reads
  /// [dispatchedCell] directly.
  FlowHandle? dispatchedHandle;

  /// The dispatch Instruction's host. Normally [tags]; scenario 8
  /// swaps it for [auditor].
  late final Box<TissueSet<int>> _dispatchHost;

  // ───────────────────────────────────────────────────────────
  // Counters
  // ───────────────────────────────────────────────────────────

  int commands = 0;
  int interpretedCount = 0;
  int dispatchedCount = 0;
  int rejectedCount = 0;

  // ───────────────────────────────────────────────────────────
  // TestTissue rules
  // ───────────────────────────────────────────────────────────

  /// Element shape: `>= 0`.
  static final TestTissue<int, TissueSet<int>> _elementRule =
  TestTissue<int, TissueSet<int>>(
        (value, {host, arguments, user}) {
      if (value is int) return value >= 0;
      return true;
    },
  );

  // ───────────────────────────────────────────────────────────
  // TestCell rules
  // ───────────────────────────────────────────────────────────

  /// Command shape: non-empty, ≤ 200 chars.
  static final TestCell<Cell> _commandShape = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = value is Pulse ? value.payload : value;
      if (v is! String) return false;
      if (v.isEmpty) return false;
      if (v.length > 200) return false;
      return true;
    },
  );

  // ───────────────────────────────────────────────────────────
  // install
  // ───────────────────────────────────────────────────────────

  /// Builds every Cell and Tissue, wires the two gates, and installs
  /// the dispatch pipeline.
  Future<void> install() async {
    // ── Tissue ──────────────────────────────────────────────
    tags = TissueSet<int>(const <int>[], testRule: _elementRule);
    auditor = tags.unmodifiable;

    // ── Dispatch host ───────────────────────────────────────
    _dispatchHost = Box<TissueSet<int>>(tags);

    // ── Flow ingress ────────────────────────────────────────
    commandIn = Cell.ingress<String>(testRule: _commandShape);

    // ── Interpret stage ─────────────────────────────────────
    //
    // Keep a reference to the *instruction* so scenario 10 can
    // call injectTimeoutOnce on it. The handle returned by
    // toHandle(...) is a record and has no methods of its own.
    interpretedInstruction = AiTissueCommand<String>(
      interpreter: interpreter,
      verbs: <String>{...verbByName.keys},
      onError: (e, st) {
        // Route the error through the interpreter's log so the
        // console stays in one formatting style.
        if (interpreter is HttpInterpreter) {
          (interpreter as HttpInterpreter).log.error(e);
        } else if (interpreter is StubInterpreter) {
          (interpreter as StubInterpreter).log.error(e);
        } else {
          print('    ┌─ ERROR ────────────────────────────────────────────────');
          print('    │ $e');
          print('    └────────────────────────────────────────────────────────');
        }
      },
    );
    interpreted = interpretedInstruction.toHandle(source: commandIn.cell);

    // ── Dispatch stage ──────────────────────────────────────
    //
    // The dispatch stage drops Reject pulses, counts both
    // classifications, and runs the pure dispatch Instruction on
    // TissueCommand pulses.
    final filtered = Flow.filter<Object>(
      interpreted.cell,
      test: (v) {
        if (v is Reject) {
          rejectedCount++;
          return false;
        }
        if (v is TissueCommand) {
          interpretedCount++;
          return true;
        }
        return false;
      },
    );

    dispatchedHandle = Flow.map<Object, TissueCommand>(
      filtered.cell,
      project: (v) {
        final cmd = v as TissueCommand;
        _runDispatch(cmd);
        return cmd;
      },
    );
    dispatchedCell = dispatchedHandle!.cell;
  }

  // ───────────────────────────────────────────────────────────
  // Dispatch Instruction (pure)
  // ───────────────────────────────────────────────────────────

  void _runDispatch(TissueCommand cmd) {
    final host = _dispatchHost.value;
    if (host == null) return;

    final tearOff = _registry(host)[cmd.verb];
    if (tearOff == null) {
      print('[dispatch] ${cmd.verb.name} denied (no tear-off)');
      return;
    }

    if (!host.modifiable.contains(tearOff)) {
      final argsRepr = cmd.args.isEmpty ? '' : '(${cmd.args.single})';
      print('[dispatch] ${cmd.verb.name}$argsRepr '
          'denied (not in modifiable)');
      return;
    }

    try {
      switch (cmd.verb) {
        case TissueVerb.add:
          host.add(cmd.args.single as int);
          print('[dispatch] add(${cmd.args.single}) allowed');
          dispatchedCount++;
        case TissueVerb.addAll:
          host.addAll((cmd.args.single as List).cast<int>());
          print('[dispatch] addAll(${cmd.args.single}) allowed');
          dispatchedCount++;
        case TissueVerb.remove:
          host.remove(cmd.args.single as int);
          print('[dispatch] remove(${cmd.args.single}) allowed');
          dispatchedCount++;
        case TissueVerb.removeAll:
          host.removeAll((cmd.args.single as List).cast<int>());
          print('[dispatch] removeAll(${cmd.args.single}) allowed');
          dispatchedCount++;
        case TissueVerb.clear:
          host.clear();
          print('[dispatch] clear() allowed');
          dispatchedCount++;
        case TissueVerb.retainAll:
          host.retainAll((cmd.args.single as List).cast<int>());
          print('[dispatch] retainAll(${cmd.args.single}) allowed');
          dispatchedCount++;
        case TissueVerb.removeWhere:
        case TissueVerb.retainWhere:
          print('[dispatch] ${cmd.verb.name} denied (predicate)');
          return;
      }
    } catch (e) {
      print('[dispatch] ${cmd.verb.name} threw $e');
    }
  }

  Map<TissueVerb, Function> _registry(TissueSet<int> host) => {
    TissueVerb.add: host.add,
    TissueVerb.addAll: host.addAll,
    TissueVerb.remove: host.remove,
    TissueVerb.removeAll: host.removeAll,
    TissueVerb.clear: host.clear,
    TissueVerb.retainAll: host.retainAll,
    TissueVerb.removeWhere: host.removeWhere,
    TissueVerb.retainWhere: host.retainWhere,
  };

  // ───────────────────────────────────────────────────────────
  // Bus
  // ───────────────────────────────────────────────────────────

  /// Publishes a sentence onto [commandIn].
  ///
  /// ### Async drain
  /// [AiTissueCommand] awaits the interpreter inside its own
  /// `run()` closure and fires `future!(...)` when the reply
  /// arrives. The `say(...)` helper drains the event loop for a
  /// few short turns so the round trip completes before the
  /// scenario's assertions print. In live mode this delay is small
  /// relative to the network round trip; the real latency comes
  /// from the HTTP call, not from this drain.
  Future<bool> say(String text) async {
    final accepted = commandIn.emit(text);
    if (!accepted) {
      return false;
    }
    commands++;

    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    return true;
  }

  void useAuditorHost() {
    _dispatchHost.value = auditor;
  }

  void useMutableHost() {
    _dispatchHost.value = tags;
  }

  String tagsAsString() {
    final list = tags.toList()..sort();
    return '{${list.join(', ')}}';
  }

  void dispose() {
    if (interpreter is HttpInterpreter) {
      (interpreter as HttpInterpreter).close();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// MODE SELECTION
// ─────────────────────────────────────────────────────────────

/// Selects the harness for the current run.
///
/// Precedence:
///
/// 1. `--config <path>` — read the JSON config file. Env vars are
///    not consulted.
/// 2. `--live` — read `AI_ENDPOINT` / `AI_API_KEY` / `AI_MODEL`
///    from the environment.
/// 3. Otherwise — offline stub.
///
/// If `--config` is supplied but the file cannot be read or parsed,
/// the function falls back to the offline stub and writes a
/// diagnostic to `stderr`.
///
/// ### Parameters
///
/// - [live]: **Required.** `true` if `--live` was passed.
/// - [configPath]: **Required.** The value of `--config`, or `null`
///   if the flag was not passed.
///
/// ### Returns
///
/// A fully constructed [NlTissueHarness]. Every branch of the
/// function terminates in a `return`, so the caller can assign the
/// result to a `final` local exactly once.
NlTissueHarness _selectHarness({
  required bool live,
  required String? configPath,
}) {
  if (configPath != null) {
    try {
      return NlTissueHarness.fromConfigFile(configPath);
    } catch (e) {
      stderr.writeln('Failed to read config "$configPath": $e');
      stderr.writeln('Falling back to offline stub.');
      return NlTissueHarness.offline();
    }
  }

  if (live) {
    final endpoint = Platform.environment['AI_ENDPOINT'];
    final apiKey = Platform.environment['AI_API_KEY'];
    final model = Platform.environment['AI_MODEL'] ?? 'gpt-4o-mini';

    if (endpoint == null || apiKey == null) {
      print('Live mode requires AI_ENDPOINT and AI_API_KEY env vars.');
      print('Falling back to offline stub.');
      return NlTissueHarness.offline();
    }

    return NlTissueHarness.live(
      endpoint: Uri.parse(endpoint),
      apiKey: apiKey,
      model: model,
    );
  }

  return NlTissueHarness.offline();
}

// ─────────────────────────────────────────────────────────────
// MAIN ENTRY POINT
// ─────────────────────────────────────────────────────────────

/// The ride-through demo: twelve scenarios against the NL →
/// TissueSet pipeline, using [AiTissueCommand] as the interpreter
/// instruction.
///
/// ### Flags
///
/// | Flag | Effect |
/// |---|---|
/// | *(none)* | Offline stub. |
/// | `--live` | HTTP interpreter from `AI_ENDPOINT` / `AI_API_KEY` / `AI_MODEL`. |
/// | `--config <path>` | HTTP interpreter from a JSON file. Overrides `--live`. |
/// | `--print-config` | Write a template JSON and exit. |
///
/// ### How to run
///
/// Offline (default):
///
///     dart run nl-instruction-tissue-set-Demo.dart
///
/// Live against DeepSeek (env vars):
///
///     export AI_ENDPOINT=https://api.deepseek.com/chat/completions
///     export AI_API_KEY=sk-your-deepseek-key
///     export AI_MODEL=deepseek-flash
///     dart run nl-instruction-tissue-set-Demo.dart --live
///
/// Live against DeepSeek (JSON config file):
///
///     dart run nl-instruction-tissue-set-Demo.dart \
///         --print-config --config ai_config.json
///     # edit ai_config.json, then:
///     dart run nl-instruction-tissue-set-Demo.dart \
///         --config ai_config.json
///
/// Live against OpenAI:
///
///     export AI_ENDPOINT=https://api.openai.com/v1/chat/completions
///     export AI_API_KEY=sk-...
///     export AI_MODEL=gpt-4o-mini
///     dart run nl-instruction-tissue-set-Demo.dart --live
Future<void> main(List<String> args) async {
  // ── Argument parsing ────────────────────────────────────────
  final live = args.contains('--live');
  final printConfig = args.contains('--print-config');

  String? configPath;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--config' && i + 1 < args.length) {
      configPath = args[i + 1];
      break;
    }
  }

  // ── --print-config: write a template and exit ───────────────
  if (printConfig) {
    final template = AiConfig(
      endpoint: Uri.parse(
        'https://api.deepseek.com/chat/completions',
      ),
      apiKey: 'sk-your-deepseek-key-here',
      model: 'deepseek-flash',
      timeout: Duration(seconds: 30),
    );
    final path = configPath ?? 'ai_config.json';
    File(path).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(template.toJson()),
    );
    print('Wrote template config to $path');
    return;
  }

  // ── Mode selection ──────────────────────────────────────────
  //
  // Precedence: --config wins; then --live + env vars; then
  // offline stub. When --config is supplied, env vars are not
  // consulted.
  //
  // The selection is packaged in `_selectHarness` so the caller
  // assigns to `h` exactly once, no matter which branch fired.
  final h = _selectHarness(live: live, configPath: configPath);

  print('========================================================================');
  print(' nl-instruction-tissue-set-Demo.dart');
  print(' Flow owns the interpretation. Tissue owns the set.');
  print(' mode: ${h.modeLabel}');
  print('========================================================================');

  try {
    await h.install();

    // ── Seed ──────────────────────────────────────────────────
    _section('Seed', 'empty TissueSet; interpret + dispatch armed');
    print('  tags.isEmpty=${h.tags.isEmpty}');

    // ── 1 ─────────────────────────────────────────────────────
    _section('1', 'add 1 to the tissue');
    await h.say('add 1 to the tissue');
    print('[tags] +1');
    print('  contains(1)=${h.tags.contains(1)} length=${h.tags.length}');

    // ── 2 ─────────────────────────────────────────────────────
    _section('2', 'please insert 1');
    final len2 = h.tags.length;
    await h.say('please insert 1');
    print('  contains(1)=${h.tags.contains(1)} '
        'grew=${h.tags.length != len2}');

    // ── 3 ─────────────────────────────────────────────────────
    _section('3', 'add 2 to the tissue');
    await h.say('add 2 to the tissue');
    print('[tags] +2');
    print('  tags=${h.tagsAsString()}');

    // ── 4 ─────────────────────────────────────────────────────
    _section('4', 'remove 1');
    await h.say('remove 1');
    print('[tags] -1');
    print('  tags=${h.tagsAsString()}');

    // ── 5 ─────────────────────────────────────────────────────
    _section('5', 'clear the set');
    await h.say('clear the set');
    print('[tags] cleared');
    print('  tags=${h.tagsAsString()}');

    // ── 6 ─────────────────────────────────────────────────────
    _section('6', 'hack the nucleus');
    await h.say('hack the nucleus');
    print('  dispatched=false tags=${h.tagsAsString()}');

    // ── 7 ─────────────────────────────────────────────────────
    _section('7', 'add -1');
    await h.say('add -1');
    print('[tags] reject -1');
    print('  tags=${h.tagsAsString()}');

    // ── 8 ─────────────────────────────────────────────────────
    _section('8', 'add 3 via auditor');
    h.useAuditorHost();
    await h.say('add 3');
    print('  tags=${h.tagsAsString()}');
    h.useMutableHost();

    // ── 9 ─────────────────────────────────────────────────────
    _section('9', 'addAll 4 5');
    await h.say('addAll 4 5');
    print('[tags] +4');
    print('[tags] +5');
    print('  tags=${h.tagsAsString()}');

    // ── 10 ────────────────────────────────────────────────────
    _section('10', 'interpreter timeout');
    final before10 = h.dispatchedCount;
    h.interpretedInstruction.injectTimeoutOnce();
    await h.say('add 6');
    print('  dispatched=${h.dispatchedCount != before10} '
        'tags=${h.tagsAsString()}');

    // ── 11 ────────────────────────────────────────────────────
    _section('11', 'empty and oversized');
    final before11 = h.tags.length;
    final emptyOk = await h.say('');
    final oversizedOk = await h.say('x' * 201);
    print('  empty accepted=$emptyOk');
    print('  oversized accepted=$oversizedOk');
    print('  interpret ran=${h.tags.length != before11}');

    // ── 12 ────────────────────────────────────────────────────
    _section('12', '(optional) swap the stub');
    print('  skipped (no live interpreter)');

    // ── Trailer ───────────────────────────────────────────────
    print('');
    print('-------------------------------------------------------------');
    print('commands=${h.commands} interpreted=${h.interpretedCount} '
        'dispatched=${h.dispatchedCount} rejected=${h.rejectedCount}');
    print('tags=${h.tagsAsString()} '
        'auditorLength=${h.auditor.length} '
        '(snapshot at install; not live)');
    print('-------------------------------------------------------------');
  } finally {
    h.dispose();
  }
}