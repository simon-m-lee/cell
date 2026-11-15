// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// The adapter interface for the LLM call.
///
/// ### When to use
/// Wrap your LLM SDK in a function that takes a prompt and returns a
/// completion. The adapter is responsible for transport, retries,
/// rate limiting, and API key management.
///
/// ### How it works
/// The prompted policy calls the adapter on every cache miss. The
/// framework governs, journals, and parses; the adapter transports.
///
/// ### Non-obvious
/// - **The adapter is called only on cache miss.** Replays of a
///   recorded session do not invoke the adapter.
/// - **Errors from the adapter are caught.** They produce
///   `Reject('prompt-error')` (or `Reject('prompt-timeout')` for a
///   [TimeoutException]), not exceptions.
///
/// ### See also
/// - [promptedPolicy], [promptedPolicyWith]
///
/// ## AI Agent Guide
/// - Keep adapters ~10 lines: read the prompt string, return the
///   completion string. Never parse verdicts inside an adapter.
///
/// {@category Organ}
/// {@category Policy}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
typedef PromptFunction = Future<String> Function(String prompt);

/// Renders a [Context] into a prompt fragment.
///
/// ### When to use
/// The `contextRenderer:` parameter of [promptedPolicy] /
/// [promptedPolicyWith]. Defaults to [renderContext].
///
/// ### How it works
/// A pure function from the typed governance dimensions to text.
///
/// ### Non-obvious
/// - **Determinism is your responsibility.** A custom renderer that
///   iterates maps in insertion order breaks the cache and replay.
///
/// ### See also
/// - [renderContext], [DecisionRenderer]
///
/// ## AI Agent Guide
/// - Compose, don't replace: wrap [renderContext] and append your own
///   lines rather than re-implementing the dimension walk.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
typedef ContextRenderer = String Function(Context context);

/// Renders a decision (pulse or command) into a prompt fragment.
///
/// ### When to use
/// The `decisionRenderer:` parameter of [promptedPolicy] /
/// [promptedPolicyWith]. Defaults to [renderDecision].
///
/// ### How it works
/// A pure function from the decision object to text.
///
/// ### Non-obvious
/// - **Determinism is your responsibility.** See [ContextRenderer].
///
/// ### See also
/// - [renderDecision], [ContextRenderer]
///
/// ## AI Agent Guide
/// - Compose, don't replace: wrap [renderDecision] and append your own
///   lines rather than re-implementing the pulse walk.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
typedef DecisionRenderer = String Function(
  dynamic object, {
  Cell? host,
  dynamic arguments,
});

/// Parses an LLM's raw response into a [Verdict]. Implementations must
/// be fail-closed.
///
/// ### When to use
/// The `verdictParser:` parameter of [promptedPolicy] /
/// [promptedPolicyWith]. Defaults to [parseVerdict].
///
/// ### How it works
/// A pure function from the raw response string to a verdict.
///
/// ### Non-obvious
/// - **Never throw.** A custom parser that throws bypasses the
///   fail-closed contract; return `Reject(...)` instead.
///
/// ### See also
/// - [parseVerdict]
///
/// ## AI Agent Guide
/// - Only replace the parser when the model outputs a non-JSON
///   verdict shape; keep the same fail-closed reason vocabulary.
///
/// {@category Organ}
/// {@category Policy}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
typedef VerdictParser = Verdict Function(String rawResponse);

/// Bridges a Cell's Context to an LLM and turns the response into a
/// [Verdict].
///
/// ### When to use
/// The **inline mode** — a one-off prompt for quick integration. For
/// reusable, versionable, portable prompts, use [PromptConfig] with
/// [promptedPolicyWith].
///
/// ### How it works
/// 1. Constructs a `PromptConfig` with a per-instance id
///    (`_inline_${uuid}`) from the provided parameters.
/// 2. Delegates to [promptedPolicyWith].
/// 3. Shares the same renderer, parser, and cache infrastructure as
///    config mode.
///
/// ### Non-obvious
/// - **Per-instance cache.** Two calls with identical parameters have
///   separate caches. For shared caching, use `PromptConfig` +
///   registry.
/// - **Every failure fails closed.** Malformed responses, timeouts,
///   and errors produce `Reject`, never an exception.
///
/// ### See also
/// - [promptedPolicyWith], [PromptConfig], `guide/12-Prompted-Policy.md`
///
/// ## AI Agent Guide
/// - Reach for inline mode in scripts and prototypes; move to config
///   mode the moment the prompt needs versioning or reuse.
///
/// {@category Organ}
/// {@category Policy}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
VerdictPolicy promptedPolicy({
  required PromptFunction prompt,
  required EffectJournal journal,
  String? systemPrompt,
  ContextRenderer? contextRenderer,
  DecisionRenderer? decisionRenderer,
  VerdictParser? verdictParser,
  Duration? cacheTtl,
  int maxPromptChars = 32000,
}) {
  final config = PromptConfig.custom(
    id: '_inline_${Identity.next()}',
    version: '1.0.0',
    description: 'Inline prompted policy',
    systemPrompt: systemPrompt ?? defaultSystemPrompt,
    userTemplate: _defaultUserTemplate,
    cacheTtl: cacheTtl ?? const Duration(hours: 1),
    maxPromptChars: maxPromptChars,
  );
  return promptedPolicyWith(
    config: config,
    prompt: prompt,
    journal: journal,
    contextRenderer: contextRenderer,
    decisionRenderer: decisionRenderer,
    verdictParser: verdictParser,
  );
}

/// Like [promptedPolicy], but driven by a [PromptConfig].
///
/// ### When to use
/// The **config mode** — the primary API for reusable prompts.
/// Composes with `cognitive()` via the `verdictPolicy:` slot.
///
/// ### How it works
/// 1. Resolves [config] directly, or [configId] through
///    [PromptConfigRegistry] (optionally pinned to [configVersion]).
/// 2. Validates the config on the first decision.
/// 3. For each decision, renders the prompt from the config +
///    `(context, decision)`, checks the content-addressed cache,
///    invokes [prompt] through the [EffectJournal] on miss, and
///    parses the response.
/// 4. Journals one `PromptEffect` (`label: 'mind.prompt'`) per
///    decision.
///
/// ### Non-obvious
/// - **Config version in cache key.** Version bumps invalidate cached
///   verdicts.
/// - **`config.validate()` runs on first decision**, not at factory
///   time.
/// - **`labelToVerdict` is required for `PromptConfig.classifier`**;
///   `extractionToVerdict` is required for `PromptConfig.extractor`.
///   Missing converters fail closed with `Reject(...)`.
/// - **Replay does not re-invoke the LLM.** The journal serves the
///   recorded response; the adapter is skipped.
///
/// ### See also
/// - [promptedPolicy], [PromptConfig], [PromptConfigRegistry], [conform]
///
/// ## AI Agent Guide
/// - Prefer this factory in production; pass `configId:` so prompts
///   roll back/forward through the registry without code deploys.
///
/// {@category Organ}
/// {@category Policy}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
VerdictPolicy promptedPolicyWith({
  PromptConfig? config,
  String? configId,
  String? configVersion,
  required PromptFunction prompt,
  required EffectJournal journal,
  Verdict Function(String label)? labelToVerdict,
  Verdict Function(Map<String, dynamic> extracted)? extractionToVerdict,
  ContextRenderer? contextRenderer,
  DecisionRenderer? decisionRenderer,
  VerdictParser? verdictParser,
}) {
  if (config != null && configId != null) {
    throw ArgumentError(
      'promptedPolicyWith: provide either config: or configId:, not both.',
    );
  }
  final PromptConfig resolved;
  if (config != null) {
    resolved = config;
  } else if (configId != null) {
    final lookedUp =
        PromptConfigRegistry.lookup(configId, version: configVersion);
    if (lookedUp == null) {
      throw ArgumentError(
        'promptedPolicyWith: no PromptConfig registered under id '
        '"$configId"${configVersion == null ? '' : ' (version $configVersion)'}.',
      );
    }
    resolved = lookedUp;
  } else {
    throw ArgumentError(
      'promptedPolicyWith: provide either config: or configId:.',
    );
  }
  return _PromptedVerdictPolicy(
    config: resolved,
    prompt: prompt,
    journal: journal,
    labelToVerdict: labelToVerdict,
    extractionToVerdict: extractionToVerdict,
    contextRenderer: contextRenderer ?? renderContext,
    decisionRenderer: decisionRenderer ?? renderDecision,
    verdictParser: verdictParser,
  );
}

/// The prompted verdict policy: render → cache → call → parse.
final class _PromptedVerdictPolicy implements VerdictPolicy {
  final PromptConfig _config;
  final PromptFunction _prompt;
  final EffectJournal _journal;
  final ContextRenderer _contextRenderer;
  final DecisionRenderer _decisionRenderer;

  /// `null` → the default parser with verdict/label/fields shape
  /// dispatch; non-null → the custom parser owns every response.
  final VerdictParser? _verdictParser;
  final Verdict Function(String label)? _labelToVerdict;
  final Verdict Function(Map<String, dynamic> extracted)? _extractionToVerdict;

  /// The process-wide content-addressed cache. Inline policies get
  /// per-instance ids (`_inline_<uuid>`), so their keys never collide;
  /// config-mode policies with the same `(id, version)` share verdicts
  /// — the A/B-testing and cross-session property of D2.
  static final _PromptCache _sharedCache = _PromptCache();
  bool _validated = false;

  _PromptedVerdictPolicy({
    required PromptConfig config,
    required PromptFunction prompt,
    required EffectJournal journal,
    required ContextRenderer contextRenderer,
    required DecisionRenderer decisionRenderer,
    VerdictParser? verdictParser,
    Verdict Function(String label)? labelToVerdict,
    Verdict Function(Map<String, dynamic> extracted)? extractionToVerdict,
  })  : _config = config,
        _prompt = prompt,
        _journal = journal,
        _contextRenderer = contextRenderer,
        _decisionRenderer = decisionRenderer,
        _verdictParser = verdictParser,
        _labelToVerdict = labelToVerdict,
        _extractionToVerdict = extractionToVerdict;

  void _ensureValidated() {
    if (_validated) return;
    _config.validate();
    _validated = true;
  }

  @override
  Future<Verdict> call(
    dynamic object, {
    required Cell host,
    dynamic arguments,
  }) async {
    _ensureValidated();
    // Argument-level rule evaluations are enforcement-only (the
    // substrate validates each command argument through the rule).
    // The LLM decides about the command WITH its arguments at the
    // command decision; querying it again per raw argument would
    // double every cost and ask it about values, not decisions.
    if (arguments is Function) return const Accept();
    final contextFragment = _contextRenderer(host.context);
    final decisionFragment =
        _decisionRenderer(object, host: host, arguments: arguments);
    final fullPrompt = _renderPromptConfig(
      _config,
      contextFragment: contextFragment,
      decisionFragment: decisionFragment,
    );
    if (fullPrompt.length > _config.maxPromptChars) {
      return const Reject('prompt-too-long');
    }

    final contextHash = _sha256Hex(contextFragment);
    final decisionHash = _sha256Hex(decisionFragment);
    final systemPromptHash = _sha256Hex(_config.systemPrompt);
    final key = _sharedCache.keyFor(
      configId: _config.id,
      configVersion: _config.version,
      contextHash: contextHash,
      decisionHash: decisionHash,
      systemPromptHash: systemPromptHash,
    );
    final cached = _sharedCache.get(key, ttl: _config.cacheTtl);

    // One journaled effect per decision — cache hit or miss. On
    // replay the journal serves the recorded map and the adapter is
    // never invoked (even the cache-hit wrapper).
    final served = await _journaledPromptCall(
      prompt: cached == null ? _prompt : (_) async => cached.response,
      journal: _journal,
      label: 'mind.prompt',
      fullPrompt: fullPrompt,
      metadata: {
        'configId': _config.id,
        'configVersion': _config.version,
        'contextHash': contextHash,
        'decisionHash': decisionHash,
        'prompt': fullPrompt,
      },
    );

    final verdict = _verdictFromServedResponse(
      served,
      labelToVerdict: _labelToVerdict,
      extractionToVerdict: _extractionToVerdict,
      verdictParser: _verdictParser,
    );
    if (cached == null && served['error'] == null) {
      final response = served['response'];
      if (response is String) _sharedCache.put(key, response);
    }
    return verdict;
  }

  @override
  VerdictPolicy operator +(VerdictPolicy other) =>
      _CompositeVerdictPolicy(this, other);
}

/// One journaled prompt call: the adapter runs on the recording side;
/// the replay side serves the recorded map without touching the
/// adapter. Adapter failures are captured inside the map — they must
/// be recorded so replay reproduces them.
Future<Map<String, dynamic>> _journaledPromptCall({
  required PromptFunction prompt,
  required EffectJournal journal,
  required String label,
  required String fullPrompt,
  required Map<String, dynamic> metadata,
}) {
  return journal.io<Map<String, dynamic>>(
    label: label,
    input: fullPrompt,
    run: () async {
      final start = DateTime.now();
      Future<Map<String, dynamic>> capture(Future<String> call) async {
        try {
          final response = await call;
          return {
            ...metadata,
            'response': response,
            'at': _isoAt(DateTime.now()),
            'latencyMillis': DateTime.now().difference(start).inMilliseconds,
          };
        } on TimeoutException {
          return {
            ...metadata,
            'error': 'prompt-timeout',
            'at': _isoAt(DateTime.now()),
            'latencyMillis': DateTime.now().difference(start).inMilliseconds,
          };
        } catch (_) {
          return {
            ...metadata,
            'error': 'prompt-error',
            'at': _isoAt(DateTime.now()),
            'latencyMillis': DateTime.now().difference(start).inMilliseconds,
          };
        }
      }

      return capture(prompt(fullPrompt));
    },
  );
}

/// Converts a served prompt-call map into a verdict, failing closed.
Verdict _verdictFromServedResponse(
  Map<String, dynamic> served, {
  Verdict Function(String label)? labelToVerdict,
  Verdict Function(Map<String, dynamic> extracted)? extractionToVerdict,
  VerdictParser? verdictParser,
}) {
  final error = served['error'];
  if (error is String) return Reject(error);
  final response = served['response'];
  if (response is! String) return const Reject('prompt-error');
  return _parseResponse(
    response,
    labelToVerdict: labelToVerdict,
    extractionToVerdict: extractionToVerdict,
    verdictParser: verdictParser,
  );
}

/// Shape dispatch for a raw model response: a custom parser owns the
/// response when supplied; otherwise `verdict`, `label`, or `fields`
/// shapes are recognized, with the fail-closed default parser as the
/// fallback.
Verdict _parseResponse(
  String raw, {
  Verdict Function(String label)? labelToVerdict,
  Verdict Function(Map<String, dynamic> extracted)? extractionToVerdict,
  VerdictParser? verdictParser,
}) {
  if (verdictParser != null) return verdictParser(raw);
  final decoded = _decodeJsonObject(raw);
  if (decoded != null &&
      decoded.containsKey('label') &&
      !decoded.containsKey('verdict')) {
    final label = decoded['label'];
    if (label is! String) return const Reject('missing-label');
    if (labelToVerdict == null) {
      return const Reject('missing-label-to-verdict');
    }
    try {
      return labelToVerdict(label);
    } catch (_) {
      return const Reject('label-to-verdict-failed');
    }
  }
  if (decoded != null &&
      decoded.containsKey('fields') &&
      !decoded.containsKey('verdict')) {
    final fields = decoded['fields'];
    if (fields is! Map) return const Reject('missing-fields');
    if (extractionToVerdict == null) {
      return const Reject('missing-extraction-to-verdict');
    }
    try {
      return extractionToVerdict(fields.cast<String, dynamic>());
    } catch (_) {
      return const Reject('extraction-to-verdict-failed');
    }
  }
  return parseVerdict(raw);
}
