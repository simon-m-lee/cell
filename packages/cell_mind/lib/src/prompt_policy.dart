// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

// Dispositions returned by the journal-driven decision dispatcher
// (`label: 'mind.prompt.disposition'`). Recording computes them from
// the live caches; replay serves the recorded disposition, which makes
// both sides take the same branch without re-running cache lookups.
const _dispositionVerdictHit = 'verdict-cache-hit';
const _dispositionPromptHit = 'prompt-cache-hit';
const _dispositionLlm = 'llm';
const _dispositionTooLong = 'prompt-too-long';

/// The adapter interface for the LLM call.
///
/// ### When to use
/// Wrap your LLM SDK in a function that takes a prompt and returns a
/// completion. The adapter is responsible for transport, retries,
/// rate limiting, and API key management.
///
/// ### How it works
/// The prompted policy calls the adapter on cache miss. The framework
/// governs, journals, and parses; the adapter transports.
///
/// ### Non-obvious
/// - **The adapter is called only when both caches miss.** Verdict
///   cache hits skip rendering; prompt cache hits skip the call;
///   replays never invoke the adapter.
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
///   iterates maps in insertion order breaks both caches and replay.
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
/// [Verdict]. Inline mode.
///
/// ### When to use
/// The **inline mode** — a one-off prompt for quick integration. For
/// reusable, versionable, portable prompts, use [PromptConfig] with
/// [promptedPolicyWith].
///
/// ### How it works
/// 1. Constructs a `PromptConfig` with a per-instance id
///    (`_inline_${uuid}`) and `SessionMode.stateless` from the
///    provided parameters.
/// 2. Delegates to [promptedPolicyWith].
/// 3. Shares the same renderer, parser, caches, and journal effect
///    infrastructure as config mode.
///
/// ### Non-obvious
/// - **Per-instance caches.** Two calls with identical parameters
///   have separate caches. For shared caching, pass a shared
///   [VerdictCache] and/or use config mode.
/// - **Inline mode is stateless.** Sessions belong to a portable
///   config; use config mode for conversations.
/// - **Every failure fails closed.** Malformed responses, timeouts,
///   and errors produce `Reject`, never an exception.
///
/// ### See also
/// - [promptedPolicyWith], [PromptConfig], [VerdictCache]
///
/// ## AI Agent Guide
/// - Reach for inline mode in scripts and prototypes; move to config
///   mode the moment the prompt needs versioning, sessions, or reuse.
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
  VerdictCache? verdictCache,
  int maxPromptChars = 32000,
}) {
  final config = PromptConfig.custom(
    id: '_inline_${Identity.next()}',
    version: '1.0.0',
    description: 'Inline prompted policy',
    systemPrompt: systemPrompt ?? defaultSystemPrompt,
    userTemplate: _defaultUserTemplate,
    cacheTtl: cacheTtl ?? const Duration(hours: 1),
    sessionMode: SessionMode.stateless,
    maxPromptChars: maxPromptChars,
  );
  return promptedPolicyWith(
    config: config,
    prompt: prompt,
    journal: journal,
    verdictCache: verdictCache,
    contextRenderer: contextRenderer,
    decisionRenderer: decisionRenderer,
    verdictParser: verdictParser,
  );
}

/// Like [promptedPolicy], but driven by a [PromptConfig].
///
/// ### When to use
/// The **config mode** — the primary API for reusable prompts,
/// dedicated sessions, or shared sessions across multiple policies.
/// Composes with `cognitive()` via the `verdictPolicy:` slot.
///
/// ### How it works
/// 1. Resolves [config] directly, or [configId] through
///    [PromptConfigRegistry] (optionally pinned to [configVersion]).
/// 2. Validates the config on the first decision.
/// 3. For each decision: computes fingerprints, consults the verdict
///    cache (skip render + LLM on hit), renders with the session,
///    consults the prompt cache, and calls [prompt] through the
///    [EffectJournal] only when both caches miss.
/// 4. Journals one disposition effect per decision plus the
///    branch-specific effects (`PromptEffect`,
///    `VerdictCacheHitEffect`, session effects).
///
/// ### Non-obvious
/// - **Config version in every cache key.** Version bumps invalidate
///   cached verdicts and prompts.
/// - **`config.validate()` runs on first decision**, not at factory
///   time.
/// - **`labelToVerdict` is required for `PromptConfig.classifier`**;
///   `extractionToVerdict` is required for `PromptConfig.extractor`.
///   Missing converters fail closed with `Reject(...)`.
/// - **`session:` is required for `SessionMode.shared`** and ignored
///   otherwise; [SessionMode.dedicated] auto-creates a session
///   exposed via [PromptedPolicy.session].
/// - **Replay does not re-invoke the LLM and does not re-consult
///   caches.** The journal-driven disposition reproduces the recorded
///   branch.
///
/// ### See also
/// - [promptedPolicy], [PromptConfig], [PromptConfigRegistry],
///   [PromptSession], [VerdictCache], [conform]
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
PromptedPolicy promptedPolicyWith({
  PromptConfig? config,
  String? configId,
  String? configVersion,
  required PromptFunction prompt,
  required EffectJournal journal,
  VerdictCache? verdictCache,
  PromptSession? session,
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

  final PromptSession? effectiveSession = switch (resolved.sessionMode) {
    SessionMode.stateless => null,
    SessionMode.dedicated => PromptSession(
        id: 'dedicated-${Identity.next()}',
        maxMessages: resolved.maxSessionMessages,
        maxChars: resolved.maxSessionChars,
      ),
    SessionMode.shared => session ??
        (throw ArgumentError(
          'promptedPolicyWith: SessionMode.shared requires a session:.',
        )),
  };

  final VerdictCache? effectiveCache = verdictCache ??
      (resolved.verdictCacheTtl == Duration.zero
          ? null
          : InMemoryVerdictCache(
              ttl: resolved.verdictCacheTtl,
              maxEntries: resolved.maxVerdictCacheEntries,
            ));

  return PromptedPolicy._(
    config: resolved,
    session: effectiveSession,
    prompt: prompt,
    journal: journal,
    verdictCache: effectiveCache,
    labelToVerdict: labelToVerdict,
    extractionToVerdict: extractionToVerdict,
    contextRenderer: contextRenderer ?? renderContext,
    decisionRenderer: decisionRenderer ?? renderDecision,
    verdictParser: verdictParser,
  );
}

/// The `VerdictPolicy` returned by [promptedPolicy] and
/// [promptedPolicyWith].
///
/// ### When to use
/// Compose in the `verdictPolicy:` slot of `cognitive(...)` — it is a
/// plain [VerdictPolicy] with session access on top.
///
/// ### How it works
/// A value-like handle over the render → cache → call → parse
/// pipeline. Its [session] is the live [PromptSession] (see
/// [SessionMode]).
///
/// ### Non-obvious
/// - **Exposes the session.** When `SessionMode.dedicated`, [session]
///   returns the auto-created session. When `SessionMode.shared`, it
///   returns the user-provided one. When `SessionMode.stateless`, it's
///   `null`.
/// - **Two dedicated policies have distinct sessions.** Two shared
///   policies constructed with the same `session:` share it.
/// - **Verdict cache hits do not append to the session** — a repeated
///   decision is not a new conversation turn.
/// - **[clearSession] journals a `SessionClearedEffect`**; calling
///   `session.clear()` directly does not.
///
/// ### See also
/// - [promptedPolicyWith], [PromptSession], [VerdictCache]
///
/// ## AI Agent Guide
/// - Read [session] for conversation state; use [clearSession] to
///   reset it journaledly.
///
/// {@category Organ}
/// {@category Policy}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class PromptedPolicy implements VerdictPolicy {
  /// The config driving this policy.
  final PromptConfig config;

  /// The live session, or `null` when [SessionMode.stateless].
  final PromptSession? session;

  /// The transport adapter.
  final PromptFunction prompt;

  /// The effect journal.
  final EffectJournal journal;

  /// The verdict cache, or `null` when verdict caching is disabled.
  final VerdictCache? verdictCache;

  final ContextRenderer _contextRenderer;
  final DecisionRenderer _decisionRenderer;

  /// `null` → the default parser with verdict/label/fields shape
  /// dispatch; non-null → the custom parser owns every response.
  final VerdictParser? _verdictParser;
  final Verdict Function(String label)? _labelToVerdict;
  final Verdict Function(Map<String, dynamic> extracted)? _extractionToVerdict;

  /// The process-wide prompt cache (second tier). Inline policies get
  /// per-instance ids, so their keys never collide; config-mode
  /// policies with the same `(id, version)` share rendered-prompt
  /// entries.
  static final _PromptCache _sharedPromptCache = _PromptCache();

  bool _validated = false;
  bool _sessionInitRecorded = false;

  PromptedPolicy._({
    required this.config,
    required this.session,
    required this.prompt,
    required this.journal,
    required this.verdictCache,
    required ContextRenderer contextRenderer,
    required DecisionRenderer decisionRenderer,
    VerdictParser? verdictParser,
    Verdict Function(String label)? labelToVerdict,
    Verdict Function(Map<String, dynamic> extracted)? extractionToVerdict,
  })  : _contextRenderer = contextRenderer,
        _decisionRenderer = decisionRenderer,
        _verdictParser = verdictParser,
        _labelToVerdict = labelToVerdict,
        _extractionToVerdict = extractionToVerdict;

  void _ensureValidated() {
    if (_validated) return;
    config.validate();
    _validated = true;
  }

  /// The verdict cache key for one decision.
  VerdictCacheKey _keyFor(
    dynamic object, {
    required Context context,
    required dynamic arguments,
  }) {
    final session = this.session;
    return VerdictCacheKey(
      configId: config.id,
      configVersion: config.version,
      cellContextFingerprint: cellContextFingerprint(context),
      pulseContextFingerprint:
          object is Pulse ? pulseContextFingerprint(object) : '',
      decisionFingerprint: decisionFingerprint(object, arguments: arguments),
      sessionFingerprint: _sessionFingerprintOf(session),
    );
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

    final session = this.session;
    if (session != null && !_sessionInitRecorded) {
      await _journalSessionInit(session);
      _sessionInitRecorded = true;
    }

    final key = _keyFor(object, context: host.context, arguments: arguments);

    // 1. Disposition: the journal-driven dispatcher. Recording
    // consults the verdict cache, renders, and consults the prompt
    // cache inside the run closure; replay serves the recorded
    // disposition — so both sides take the same branch.
    final disposition = await journal.io<Map<String, dynamic>>(
      label: 'mind.prompt.disposition',
      input: '${key.fingerprint}|${config.maxPromptChars}',
      run: () async {
        final cache = verdictCache;
        if (cache != null) {
          final entry = cache.lookup(key);
          if (entry != null) {
            return {
              'kind': _dispositionVerdictHit,
              'verdict': entry.verdict.toMap(),
              'configId': config.id,
              'configVersion': config.version,
              'cacheKey': key.fingerprint,
            };
          }
        }
        final fullPrompt = _render(config, host, object, arguments);
        if (fullPrompt.length > config.maxPromptChars) {
          return {
            'kind': _dispositionTooLong,
            'configId': config.id,
            'configVersion': config.version,
          };
        }
        final promptKey = _sharedPromptCache.keyFor(
          configId: config.id,
          configVersion: config.version,
          renderedPrompt: fullPrompt,
        );
        final promptEntry =
            _sharedPromptCache.get(promptKey, ttl: config.cacheTtl);
        if (promptEntry != null) {
          return {
            'kind': _dispositionPromptHit,
            'verdict': promptEntry.verdict.toMap(),
            'response': promptEntry.response,
            'configId': config.id,
            'configVersion': config.version,
            'cacheKey': key.fingerprint,
          };
        }
        return {
          'kind': _dispositionLlm,
          'configId': config.id,
          'configVersion': config.version,
        };
      },
    );

    switch (disposition['kind']) {
      case _dispositionVerdictHit:
        // Repeat decision: serve the verdict; no session mutation
        // (D14), no render, no LLM.
        final hitStart = DateTime.now();
        final hit = await journal.io<Map<String, dynamic>>(
          label: 'mind.prompt.cache.hit',
          input: key.fingerprint,
          run: () async => {
            'type': 'mind.verdict_cache_hit',
            'version': VerdictCacheHitEffect.schemaVersion,
            'configId': config.id,
            'configVersion': config.version,
            'cacheKey': key.fingerprint,
            'verdict': disposition['verdict'],
            'at': _isoAt(DateTime.now()),
            'lookupLatencyMillis':
                DateTime.now().difference(hitStart).inMilliseconds,
          },
        );
        return verdictFromMap(
          (hit['verdict'] as Map).cast<String, dynamic>(),
        );

      case _dispositionPromptHit:
        // Second tier: render happened, LLM skipped. Append the
        // exchange (from the served maps — replay reconstructs the
        // session identically) and record the effective cache hit.
        final hitStart = DateTime.now();
        await journal.io<Map<String, dynamic>>(
          label: 'mind.prompt.cache.hit',
          input: key.fingerprint,
          run: () async => {
            'type': 'mind.verdict_cache_hit',
            'version': VerdictCacheHitEffect.schemaVersion,
            'configId': config.id,
            'configVersion': config.version,
            'cacheKey': key.fingerprint,
            'verdict': disposition['verdict'],
            'at': _isoAt(DateTime.now()),
            'lookupLatencyMillis':
                DateTime.now().difference(hitStart).inMilliseconds,
          },
        );
        final verdict = verdictFromMap(
          (disposition['verdict'] as Map).cast<String, dynamic>(),
        );
        final response = disposition['response'] as String? ?? '';
        await _appendSessionExchange(object, host, arguments, response);
        // D14 population order: append to the session FIRST, then store
        // under the POST-append key — a repeat of the same decision
        // with the evolved session state hits the entry.
        final storedKey =
            _keyFor(object, context: host.context, arguments: arguments);
        verdictCache?.store(
          storedKey,
          VerdictCacheEntry(
            verdict: verdict,
            storedAt: DateTime.now(),
            fromPromptCache: true,
          ),
        );
        return verdict;

      case _dispositionTooLong:
        return const Reject('prompt-too-long');

      case _dispositionLlm:
      default:
        return _callLlm(object, host, arguments, key);
    }
  }

  /// The LLM path: render (needed for the journal input digest on
  /// both sides), journal the `PromptEffect`, parse, then append to
  /// the session and populate both caches on success.
  Future<Verdict> _callLlm(
    dynamic object,
    Cell host,
    dynamic arguments,
    VerdictCacheKey key,
  ) async {
    final contextFragment = _contextRenderer(host.context);
    final decisionFragment =
        _decisionRenderer(object, host: host, arguments: arguments);
    final session = this.session;
    final fullPrompt = _renderPromptConfig(
      config,
      contextFragment: contextFragment,
      decisionFragment: decisionFragment,
      session: session,
    );
    if (fullPrompt.length > config.maxPromptChars) {
      return const Reject('prompt-too-long');
    }

    final served = await _journaledPromptCall(
      prompt: prompt,
      journal: journal,
      label: 'mind.prompt',
      fullPrompt: fullPrompt,
      metadata: {
        'configId': config.id,
        'configVersion': config.version,
        'cacheKey': key.fingerprint,
        'contextHash': _sha256Hex(contextFragment),
        'decisionHash': _sha256Hex(decisionFragment),
        'sessionFingerprint':
            session == null ? null : _sessionFingerprintOf(session),
        'sessionId': session?.id,
        'prompt': fullPrompt,
      },
    );

    final verdict = _verdictFromServedResponse(
      served,
      labelToVerdict: _labelToVerdict,
      extractionToVerdict: _extractionToVerdict,
      verdictParser: _verdictParser,
    );

    // Failed calls and parse failures neither append to the session
    // nor populate the caches (D17). Business rejections (including
    // classifier rejects) are legitimate decisions and are cached.
    if (served['error'] != null || _isTransportFailure(verdict)) {
      return verdict;
    }

    final response = served['response'];
    if (response is String) {
      await _appendSessionExchange(object, host, arguments, response);
      final promptKey = _sharedPromptCache.keyFor(
        configId: config.id,
        configVersion: config.version,
        renderedPrompt: fullPrompt,
      );
      _sharedPromptCache.put(
        promptKey,
        response: response,
        verdict: verdict,
      );
    }
    // D14 population order: store under the POST-append session state.
    final storedKey =
        _keyFor(object, context: host.context, arguments: arguments);
    verdictCache?.store(
      storedKey,
      VerdictCacheEntry(
        verdict: verdict,
        storedAt: DateTime.now(),
        originalLatency: Duration(
          milliseconds: served['latencyMillis'] as int? ?? 0,
        ),
        fromPromptCache: false,
      ),
    );
    return verdict;
  }

  /// Renders the full prompt (recording-side disposition path).
  String _render(
    PromptConfig config,
    Cell host,
    dynamic object,
    dynamic arguments,
  ) {
    final session = this.session;
    return _renderPromptConfig(
      config,
      contextFragment: _contextRenderer(host.context),
      decisionFragment: _decisionRenderer(
        object,
        host: host,
        arguments: arguments,
      ),
      session: session,
    );
  }

  /// Journals the session initialization (first decision only).
  Future<void> _journalSessionInit(PromptSession session) async {
    await journal.io<Map<String, dynamic>>(
      label: 'mind.session.init',
      input: session.fingerprint(),
      run: () async => {
        'type': 'mind.session.init',
        'version': SessionInitializedEffect.schemaVersion,
        'sessionId': session.id,
        'initialMessages':
            session.messages.map((m) => m.toMap()).toList(growable: false),
        'at': _isoAt(DateTime.now()),
      },
    );
  }

  /// Appends the decision exchange to the session with journaled
  /// replay semantics: the journal serves the recorded messages and
  /// both sides apply the served maps, so replay reconstructs the
  /// exact conversation state. Compaction is journaled per drop.
  Future<void> _appendSessionExchange(
    dynamic object,
    Cell host,
    dynamic arguments,
    String response,
  ) async {
    final session = this.session;
    if (session == null) return;
    final userContent = _userMessageFor(host.context, object, arguments);
    final user = ChatMessage(role: ChatRole.user, content: userContent);
    final assistant = ChatMessage(role: ChatRole.assistant, content: response);
    final before = session.fingerprint();
    final served = await journal.io<Map<String, dynamic>>(
      label: 'mind.session.append',
      input: '$before|${user.role.name}|${assistant.role.name}',
      run: () async => {
        'type': 'mind.session.append',
        'version': SessionAppendedEffect.schemaVersion,
        'sessionId': session.id,
        'userMessage': user.toMap(),
        'assistantMessage': assistant.toMap(),
        'at': _isoAt(DateTime.now()),
      },
    );
    final servedUser = ChatMessage.fromMap(
      (served['userMessage'] as Map).cast<String, dynamic>(),
    );
    final servedAssistant = ChatMessage.fromMap(
      (served['assistantMessage'] as Map).cast<String, dynamic>(),
    );
    final dropped = session._appendExchangeCounted(servedUser, servedAssistant);
    if (dropped > 0) {
      final after = session.fingerprint();
      await journal.io<Map<String, dynamic>>(
        label: 'mind.session.compact',
        input: '$after|$dropped',
        run: () async => {
          'type': 'mind.session.compact',
          'version': SessionCompactedEffect.schemaVersion,
          'sessionId': session.id,
          'droppedPairs': dropped,
          'at': _isoAt(DateTime.now()),
        },
      );
    }
  }

  /// The user-message content for a decision: the template-substituted
  /// current request (context + decision blocks for the default
  /// template).
  String _userMessageFor(
    Context context,
    dynamic object,
    dynamic arguments,
  ) {
    final contextFragment = _contextRenderer(context);
    final decisionFragment =
        _decisionRenderer(object, host: null, arguments: arguments);
    return config.userTemplate
        .replaceAll('{{context}}', contextFragment)
        .replaceAll('{{decision}}', decisionFragment);
  }

  /// Clears the session. No-op when stateless.
  ///
  /// ### Non-obvious
  /// Journals a `SessionClearedEffect` (fire-and-forget, in journal
  /// invocation order). Prefer this over `session.clear()` so the
  /// reset is replayable.
  void clearSession() {
    final session = this.session;
    if (session == null) return;
    final before = session.fingerprint();
    session.clear();
    unawaited(
      journal.io<Map<String, dynamic>>(
        label: 'mind.session.clear',
        input: before,
        run: () async => {
          'type': 'mind.session.clear',
          'version': SessionClearedEffect.schemaVersion,
          'sessionId': session.id,
          'at': _isoAt(DateTime.now()),
        },
      ),
    );
  }

  @override
  VerdictPolicy operator +(VerdictPolicy other) =>
      _CompositeVerdictPolicy(this, other);
}

/// Whether a verdict is a transport/parse failure — excluded from the
/// caches and from session appends (D17). Business rejections from
/// the model (including classifier labels) are NOT failures.
bool _isTransportFailure(Verdict verdict) {
  if (verdict is! Reject) return false;
  final reason = verdict.reason;
  return reason == 'prompt-error' ||
      reason == 'prompt-timeout' ||
      reason == 'missing-label-to-verdict' ||
      reason == 'missing-extraction-to-verdict' ||
      reason == 'label-to-verdict-failed' ||
      reason == 'extraction-to-verdict-failed' ||
      reason.startsWith('parse-error') ||
      reason == 'missing-verdict' ||
      reason.startsWith('unknown-verdict:') ||
      reason == 'missing-reason' ||
      reason == 'defer-missing-resolver' ||
      reason == 'missing-label' ||
      reason == 'missing-fields';
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
