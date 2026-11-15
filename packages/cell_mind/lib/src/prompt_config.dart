// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// How a prompted policy handles conversation state.
///
/// ### When to use
/// Set on [PromptConfig.sessionMode]. The default [stateless] renders
/// every decision independently; [dedicated] gives a policy its own
/// conversation; [shared] connects several policies to one
/// user-provided [PromptSession].
///
/// ### How it works
/// The mode decides session creation at `promptedPolicyWith` time:
/// - `stateless` — no session object at all.
/// - `dedicated` — a session is auto-created and exposed via
///   [PromptedPolicy.session].
/// - `shared` — the caller's `session:` argument is used directly
///   (required; throws otherwise).
///
/// ### Non-obvious
/// - **Inline mode is always stateless.** Sessions belong to a
///   portable config.
/// - **A `session:` argument is ignored in every mode except
///   `shared`.**
///
/// ### See also
/// - [PromptSession], [PromptedPolicy], `promptedPolicyWith`
///
/// ## AI Agent Guide
/// - Pick `dedicated` for per-policy conversation tracking, `shared`
///   for multi-agent coordination over one window.
///
/// {@category Organ}
/// {@category Prompt}
/// {@category Session}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
enum SessionMode {
  /// No session — each decision rendered independently. Default.
  stateless,

  /// A session auto-created by `promptedPolicyWith`. Accessible via
  /// `PromptedPolicy.session`.
  dedicated,

  /// A session provided by the user via `session:`. Can be shared
  /// across multiple policies.
  shared,
}

/// A portable, LLM-agnostic configuration for prompted policy
/// decisions.
///
/// ### When to use
/// When a prompt is reusable across teams, apps, or deployments — or
/// when you need to version, A/B test, or roll back prompt changes
/// without code deploys. For one-off prompts, [promptedPolicy] is
/// simpler.
///
/// ### How it works
/// 1. `PromptConfig` bundles the system prompt, user template, output
///    schema, few-shot examples, and LLM-agnostic parameters.
/// 2. [promptedPolicyWith] validates the config, then wraps it in the
///    render → call → parse pipeline.
/// 3. The config's `id` and `version` participate in the cache key,
///    so version bumps invalidate cached verdicts.
///
/// ### Non-obvious
/// - **JSON-serializable.** Save it to a file, ship it with the app,
///   load it at startup, register it in [PromptConfigRegistry].
/// - **`version` is mandatory.** Bump it whenever the config changes;
///   the cache key includes it, so a bump forces a cache miss.
/// - **The template has exactly two placeholders.** `{{context}}` and
///   `{{decision}}`. Any other `{{...}}` pattern is literal.
/// - **Presets are plain instances.** Copy one and change any field.
///
/// ### See also
/// - [promptedPolicy], [promptedPolicyWith], [PromptConfigRegistry],
///   `guide/12-Prompted-Policy.md`
///
/// ## AI Agent Guide
/// - Treat a config as a versioned artifact, not inline text: ids are
///   stable, versions change, and the registry is the lookup surface.
///
/// {@category Organ}
/// {@category Policy}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class PromptConfig {
  /// The stable identity of this prompt configuration.
  final String id;

  /// The semantic version (`'1.0.0'`). Bumps invalidate the cache.
  final String version;

  /// Human-readable purpose.
  final String description;

  /// The system prompt — model instructions, rules, and tone.
  final String systemPrompt;

  /// The user-side template with `{{context}}` / `{{decision}}`
  /// placeholders.
  final String userTemplate;

  /// The JSON Schema of the expected model output.
  final Map<String, dynamic> outputSchema;

  /// Structured few-shot examples, rendered in order.
  final List<PromptExample> examples;

  /// LLM-agnostic hints (`temperature`, `json_mode`, `max_tokens`).
  /// Adapters may interpret or ignore them; the framework does not
  /// call the LLM itself and does not enforce these.
  final Map<String, dynamic> parameters;

  /// How long a cached rendered prompt stays valid. Zero disables the
  /// prompt cache.
  final Duration cacheTtl;

  /// How long a cached verdict stays valid. Zero disables verdict
  /// caching (the default [InMemoryVerdictCache] is then not
  /// created).
  final Duration verdictCacheTtl;

  /// The LRU bound of the default verdict cache.
  final int maxVerdictCacheEntries;

  /// How the policy handles conversation state.
  final SessionMode sessionMode;

  /// The session message-count bound (compaction trigger).
  final int maxSessionMessages;

  /// The session total-character bound (compaction trigger).
  final int maxSessionChars;

  /// The maximum rendered prompt length in characters. Longer prompts
  /// fail closed with `Reject('prompt-too-long')`.
  final int maxPromptChars;

  /// The default output schema for `accept` / `reject` / `defer`
  /// verdicts.
  static const Map<String, dynamic> defaultVerdictSchema = {
    'type': 'object',
    'required': ['verdict'],
    'properties': {
      'verdict': {
        'type': 'string',
        'enum': ['accept', 'reject', 'defer']
      },
      'reason': {'type': 'string'},
      'resolver': {'type': 'string'},
      'confidence': {'type': 'number', 'minimum': 0, 'maximum': 1},
      'annotations': {'type': 'object'},
    },
  };

  const PromptConfig({
    required this.id,
    required this.version,
    required this.description,
    required this.systemPrompt,
    required this.userTemplate,
    this.outputSchema = defaultVerdictSchema,
    this.examples = const [],
    this.parameters = const {'temperature': 0.0, 'json_mode': true},
    this.cacheTtl = const Duration(hours: 1),
    this.verdictCacheTtl = const Duration(hours: 1),
    this.maxVerdictCacheEntries = 10000,
    this.sessionMode = SessionMode.stateless,
    this.maxSessionMessages = 40,
    this.maxSessionChars = 20000,
    this.maxPromptChars = 32000,
  });

  /// The default policy-decider config: `accept` / `reject` / `defer`.
  factory PromptConfig.policyDecider({String? systemPrompt}) =>
      _policyDeciderConfig(systemPrompt: systemPrompt);

  /// The classifier config: map a decision to one of [labels].
  factory PromptConfig.classifier({
    required List<String> labels,
    String? systemPrompt,
  }) =>
      _classifierConfig(labels: labels, systemPrompt: systemPrompt);

  /// The extractor config: extract structured fields from the
  /// decision.
  factory PromptConfig.extractor({
    required List<String> fields,
    String? systemPrompt,
  }) =>
      _extractorConfig(fields: fields, systemPrompt: systemPrompt);

  /// A fully custom config with explicit defaults for every optional
  /// field.
  factory PromptConfig.custom({
    required String id,
    required String version,
    required String description,
    required String systemPrompt,
    required String userTemplate,
    Map<String, dynamic>? outputSchema,
    List<PromptExample>? examples,
    Map<String, dynamic>? parameters,
    Duration? cacheTtl,
    Duration? verdictCacheTtl,
    int? maxVerdictCacheEntries,
    SessionMode? sessionMode,
    int? maxSessionMessages,
    int? maxSessionChars,
    int? maxPromptChars,
  }) =>
      PromptConfig(
        id: id,
        version: version,
        description: description,
        systemPrompt: systemPrompt,
        userTemplate: userTemplate,
        outputSchema: outputSchema ?? defaultVerdictSchema,
        examples: examples ?? const [],
        parameters: parameters ?? const {'temperature': 0.0, 'json_mode': true},
        cacheTtl: cacheTtl ?? const Duration(hours: 1),
        verdictCacheTtl: verdictCacheTtl ?? const Duration(hours: 1),
        maxVerdictCacheEntries: maxVerdictCacheEntries ?? 10000,
        sessionMode: sessionMode ?? SessionMode.stateless,
        maxSessionMessages: maxSessionMessages ?? 40,
        maxSessionChars: maxSessionChars ?? 20000,
        maxPromptChars: maxPromptChars ?? 32000,
      );

  /// Validates the config's structure.
  ///
  /// ### Throws
  /// [ArgumentError] on any structural failure.
  void validate() => _validatePromptConfig(this);

  /// Renders the complete prompt for a decision.
  ///
  /// ### Determinism
  /// Rendered prompts are byte-for-byte identical for the same
  /// `(config, context, decision, session)` quadruple.
  String render({
    required Context context,
    required dynamic decision,
    Cell? host,
    PromptSession? session,
  }) =>
      _renderPromptConfig(
        this,
        contextFragment: renderContext(context),
        decisionFragment: renderDecision(decision, host: host),
        session: session,
      );

  /// Serializes this config (JSON-encodable; `cacheTtl` and
  /// `verdictCacheTtl` in milliseconds).
  Map<String, dynamic> toMap() => {
        'id': id,
        'version': version,
        'description': description,
        'systemPrompt': systemPrompt,
        'userTemplate': userTemplate,
        'outputSchema': outputSchema,
        'examples': examples.map((e) => e.toMap()).toList(),
        'parameters': parameters,
        'cacheTtl': cacheTtl.inMilliseconds,
        'verdictCacheTtl': verdictCacheTtl.inMilliseconds,
        'maxVerdictCacheEntries': maxVerdictCacheEntries,
        'sessionMode': sessionMode.name,
        'maxSessionMessages': maxSessionMessages,
        'maxSessionChars': maxSessionChars,
        'maxPromptChars': maxPromptChars,
      };

  /// Reconstructs a config from [PromptConfig.toMap] output.
  static PromptConfig fromMap(Map<String, dynamic> map) => PromptConfig(
        id: map['id'] as String,
        version: map['version'] as String,
        description: map['description'] as String? ?? '',
        systemPrompt: map['systemPrompt'] as String,
        userTemplate: map['userTemplate'] as String,
        outputSchema: (map['outputSchema'] as Map?)?.cast<String, dynamic>() ??
            defaultVerdictSchema,
        examples: (map['examples'] as List?)
                ?.map(
                  (e) =>
                      PromptExample.fromMap((e as Map).cast<String, dynamic>()),
                )
                .toList() ??
            const [],
        parameters: (map['parameters'] as Map?)?.cast<String, dynamic>() ??
            const {'temperature': 0.0, 'json_mode': true},
        cacheTtl: Duration(milliseconds: map['cacheTtl'] as int? ?? 3600000),
        verdictCacheTtl:
            Duration(milliseconds: map['verdictCacheTtl'] as int? ?? 3600000),
        maxVerdictCacheEntries: map['maxVerdictCacheEntries'] as int? ?? 10000,
        sessionMode: SessionMode.values.firstWhere(
          (m) => m.name == map['sessionMode'],
          orElse: () => SessionMode.stateless,
        ),
        maxSessionMessages: map['maxSessionMessages'] as int? ?? 40,
        maxSessionChars: map['maxSessionChars'] as int? ?? 20000,
        maxPromptChars: map['maxPromptChars'] as int? ?? 32000,
      );
}

/// A few-shot example for a [PromptConfig].
///
/// ### When to use
/// Add `(context, decision, response)` triples to a config so the
/// model sees concrete demonstrations of the expected output shape.
///
/// ### How it works
/// [render] emits a fixed-format block; [PromptConfig.render] inserts
/// one `### Example N` section per example, in order.
///
/// ### Non-obvious
/// - **Examples store rendered text, not raw `Context` objects.**
///   A config file therefore ships without the source code that
///   produced its examples.
/// - **The `response` must parse against the config's schema** —
///   `validate()` enforces this.
///
/// ### See also
/// - [PromptConfig], [PromptConfig.policyDecider]
///
/// ## AI Agent Guide
/// - Write example responses exactly as the model should answer,
///   including the JSON shape; examples are the strongest steering
///   signal available without vendor-specific tuning.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class PromptExample {
  /// The rendered Context sample.
  final String context;

  /// The rendered Decision sample.
  final String decision;

  /// The expected JSON response.
  final String response;

  const PromptExample({
    required this.context,
    required this.decision,
    required this.response,
  });

  /// Renders this example as a fixed-format block:
  /// `Context:` / `Decision:` / `Response:` sections.
  String render() =>
      'Context:\n$context\n\nDecision:\n$decision\n\nResponse:\n$response';

  /// Serializes this example.
  Map<String, dynamic> toMap() => {
        'context': context,
        'decision': decision,
        'response': response,
      };

  /// Reconstructs an example from [PromptExample.toMap] output.
  static PromptExample fromMap(Map<String, dynamic> map) => PromptExample(
        context: map['context'] as String? ?? '',
        decision: map['decision'] as String? ?? '',
        response: map['response'] as String? ?? '',
      );
}

/// A versioned registry of [PromptConfig]s.
///
/// ### When to use
/// Production systems that need A/B testing (v1 for 90%, v2 for 10%),
/// feature flags, or runtime rollback. Apps register at startup;
/// [promptedPolicyWith] resolves `configId:` through the registry.
///
/// ### How it works
/// Process-wide static storage keyed by `(id, version)`.
/// [lookup] without a version resolves the **highest** semantic
/// version; with a version it resolves exactly.
///
/// ### Non-obvious
/// - **Registering an existing `(id, version)` replaces it** — the
///   registry is a configuration surface, not an append-only ledger.
/// - **Version resolution is semantic** (`1.10.0` > `1.9.0`), falling
///   back to lexicographic comparison for non-numeric segments.
/// - **The registry is process-local.** Cross-process A/B testing
///   needs the same registrations at every process start.
///
/// ### See also
/// - [promptedPolicyWith], [conform]
///
/// ## AI Agent Guide
/// - Register at startup, look up by id, unregister before replacing;
///   keep registry ids stable across deployments.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
class PromptConfigRegistry {
  static final Map<String, Map<String, PromptConfig>> _byId = {};

  /// Registers [config] under `(config.id, config.version)`.
  static void register(PromptConfig config) {
    _byId.putIfAbsent(config.id, () => {})[config.version] = config;
  }

  /// Looks up the config with [id] — exactly [version] when given,
  /// otherwise the highest registered version. Returns `null` when
  /// nothing is registered under the id.
  static PromptConfig? lookup(String id, {String? version}) {
    final versions = _byId[id];
    if (versions == null || versions.isEmpty) return null;
    if (version != null) return versions[version];
    var best = versions.values.first;
    for (final candidate in versions.values.skip(1)) {
      if (_compareVersions(candidate.version, best.version) > 0) {
        best = candidate;
      }
    }
    return best;
  }

  /// Lists registered configs — all of [id]'s versions when given,
  /// otherwise every registered config.
  static List<PromptConfig> list({String? id}) {
    final result = <PromptConfig>[];
    if (id != null) {
      final versions = _byId[id];
      if (versions != null) result.addAll(versions.values);
    } else {
      for (final versions in _byId.values) {
        result.addAll(versions.values);
      }
    }
    return List.unmodifiable(result);
  }

  /// Removes the config with [id] — exactly [version] when given,
  /// otherwise all versions of that id.
  static void unregister(String id, {String? version}) {
    final versions = _byId[id];
    if (versions == null) return;
    if (version != null) {
      versions.remove(version);
      if (versions.isEmpty) _byId.remove(id);
    } else {
      _byId.remove(id);
    }
  }

  /// Semantic-version comparison: positive when [a] > [b].
  static int _compareVersions(String a, String b) {
    final pa = _versionParts(a);
    final pb = _versionParts(b);
    for (var i = 0; i < pa.length || i < pb.length; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      final cmp = va.compareTo(vb);
      if (cmp != 0) return cmp;
    }
    return a.compareTo(b);
  }

  static List<int> _versionParts(String version) {
    final parts = version.split('.');
    final numeric = <int>[];
    for (final part in parts) {
      numeric.add(int.tryParse(part) ?? 0);
    }
    return numeric;
  }
}

/// A single conformance case.
///
/// ### When to use
/// Build a case list for [conform]: the decision contexts and inputs
/// your config must handle, each with the verdict you expect the
/// specific LLM to produce.
///
/// ### How it works
/// An immutable `(context, decision, expected)` triple. [conform]
/// renders each case, calls the real LLM, parses the response, and
/// compares against [expected].
///
/// ### Non-obvious
/// - **Expectations are verdict-shaped.** `Accept`/`Reject` compare by
///   type and reason/resolver; `Defer` by resolver; annotations are
///   compared as canonical JSON.
///
/// ### See also
/// - [conform], [PromptConformanceReport]
///
/// ## AI Agent Guide
/// - Curate cases that cover the config's failure modes, not just the
///   happy path; conformance runs cost real LLM calls.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class ConformanceCase {
  /// The governance context of this case.
  final Context context;

  /// The decision under test.
  final dynamic decision;

  /// The verdict the LLM must produce.
  final Verdict expected;

  const ConformanceCase({
    required this.context,
    required this.decision,
    required this.expected,
  });
}

/// The result of a conformance test run.
///
/// ### When to use
/// Read the report returned by [conform] before deploying a config
/// against a new LLM.
///
/// ### How it works
/// Counts passed/failed cases, accumulates latency, and exposes
/// [passedAll] / [passRate] for gates.
///
/// ### Non-obvious
/// - **`conform` calls the real LLM** — users pay per run. Use the
///   optional `journal:` so the run replays for free.
///
/// ### See also
/// - [conform], [ConformanceCase], [ConformanceFailure]
///
/// ## AI Agent Guide
/// - Treat `passedAll == false` as a deploy blocker for that
///   model/config pairing.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class PromptConformanceReport {
  /// The number of cases run.
  final int total;

  /// The number of cases whose verdicts matched.
  final int passed;

  /// The failing cases with their actual verdicts.
  final List<ConformanceFailure> failures;

  /// Wall-clock time of the whole run.
  final Duration totalLatency;

  /// Average per-case latency (`totalLatency / total`, zero for an
  /// empty case list).
  final Duration averageLatency;

  /// The id of the config under test.
  final String configId;

  /// The version of the config under test.
  final String configVersion;

  const PromptConformanceReport({
    required this.total,
    required this.passed,
    required this.failures,
    required this.totalLatency,
    required this.averageLatency,
    required this.configId,
    required this.configVersion,
  });

  /// Whether every case passed.
  bool get passedAll => passed == total;

  /// The pass fraction in `0.0..1.0` (1.0 for an empty run).
  double get passRate => total == 0 ? 1.0 : passed / total;
}

/// One failing conformance case.
///
/// ### When to use
/// Read from [PromptConformanceReport.failures] to diagnose which
/// cases a config/model pairing got wrong.
///
/// ### How it works
/// Carries the [testCase], the [actual] verdict the model produced,
/// and an optional human-readable [reason].
///
/// ### Non-obvious
/// - **Failure reasons are best-effort diagnostics**, not stable API
///   strings.
///
/// ### See also
/// - [conform], [PromptConformanceReport]
///
/// ## AI Agent Guide
/// - Report failures with their cases verbatim — the rendered prompt
///   and the model response are the debugging inputs.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class ConformanceFailure {
  /// The case that failed.
  final ConformanceCase testCase;

  /// The verdict the model actually produced.
  final Verdict actual;

  /// Optional diagnostic detail.
  final String? reason;

  const ConformanceFailure({
    required this.testCase,
    required this.actual,
    this.reason,
  });
}

/// Runs [config] against [cases], calling [prompt] for each.
///
/// ### When to use
/// Verify a config against a specific LLM **before production** — the
/// deploy gate for prompt changes.
///
/// ### How it works
/// 1. Validates the config.
/// 2. For each case: renders the prompt, calls the LLM (through the
///    optional [journal] so a recorded run replays without model
///    calls), parses the response, compares against the expected
///    verdict.
/// 3. Returns a [PromptConformanceReport].
///
/// ### Non-obvious
/// - **Calls the real LLM.** Opt-in and billable; `cell_mind`'s own
///   tests use mocks with journals.
/// - **Verdict comparison:** same runtime type; `Reject` also compares
///   `reason`; `Defer` also compares `resolver`; annotations compare
///   as canonical JSON.
///
/// ### See also
/// - [PromptConformanceReport], [ConformanceCase], [PromptConfig]
///
/// ## AI Agent Guide
/// - Run conformance per model deployment; keep the case list in the
///   repo next to the config.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
Future<PromptConformanceReport> conform({
  required PromptConfig config,
  required PromptFunction prompt,
  required List<ConformanceCase> cases,
  EffectJournal? journal,
}) async {
  config.validate();
  final failures = <ConformanceFailure>[];
  final stopwatch = Stopwatch()..start();
  for (final testCase in cases) {
    final rendered = config.render(
      context: testCase.context,
      decision: testCase.decision,
    );
    final Verdict actual;
    if (rendered.length > config.maxPromptChars) {
      actual = const Reject('prompt-too-long');
    } else {
      final served = await _journaledPromptCall(
        prompt: prompt,
        journal: journal ?? RecordingJournal(),
        label: 'mind.prompt.conformance',
        fullPrompt: rendered,
        metadata: {
          'configId': config.id,
          'configVersion': config.version,
          'prompt': rendered,
        },
      );
      actual = _verdictFromServedResponse(served);
    }
    final mismatch = _verdictMismatch(actual, testCase.expected);
    if (mismatch != null) {
      failures.add(
        ConformanceFailure(
          testCase: testCase,
          actual: actual,
          reason: mismatch,
        ),
      );
    }
  }
  stopwatch.stop();
  final total = cases.length;
  return PromptConformanceReport(
    total: total,
    passed: total - failures.length,
    failures: List.unmodifiable(failures),
    totalLatency: stopwatch.elapsed,
    averageLatency: total == 0
        ? Duration.zero
        : Duration(microseconds: stopwatch.elapsedMicroseconds ~/ total),
    configId: config.id,
    configVersion: config.version,
  );
}
