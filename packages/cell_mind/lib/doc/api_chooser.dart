// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// # Cell Mind — API Chooser
///
/// The five questions. What do you need to do?
///
/// 1. **Decide whether to accept a pulse or command?** → `Policy`
/// 2. **Record and audit those decisions?** → `CognitiveHandle`
/// 3. **Learn from outcomes?** → `trainOffline` + `learnedPolicy`
/// 4. **Defer a decision to a human?** → `VerdictPolicy` +
///    `ApprovalQueue`
/// 5. **Query an AI for the verdict?** → `promptedPolicy` /
///    `promptedPolicyWith` + `PromptConfig`
///
/// **Stability:** Stable since `cell_mind 1.0.0`; prompt module added in
/// `cell_mind 1.1.0`.
///
/// ## Choose a decision primitive
///
/// | Need | Type |
/// |---|---|
/// | Simple accept/reject | `Policy` |
/// | Accept/reject/defer | `VerdictPolicy` |
/// | Record decisions | `CognitiveHandle` |
/// | LLM-decided accept/reject/defer | `promptedPolicyWith` |
///
/// ## Choose a policy
///
/// - **Domain-gated:** `domainPolicy` + `requiresDomainPolicy`
/// - **Authority-gated:** `authorityPolicy` + `exactFunctionsPolicy`
/// - **Compliance-gated:** `compliancePolicy`
/// - **Confidence-gated:** `confidencePolicy`
/// - **Strategy-gated:** `strategyPolicy`
/// - **Full stack:** `contextAware` or `paranoid`
/// - **LLM nuance on top of structure:** `promptedPolicyWith` in the
///   `verdictPolicy:` slot of `cognitive`
///
/// ## Choose a deferral
///
/// - **Human approval:** `ApprovalQueue` + `approvalResolver`
/// - **Custom resolver:** `onDeferred` callback on `cognitive`
///
/// ## Choose a prompt mode
///
/// - **One-off prompt:** `promptedPolicy(...)` — inline, per-instance
///   caches, always stateless
/// - **Reusable/versionable prompt:** `promptedPolicyWith(config:)` —
///   shared, content-addressed caches keyed by config id + version
/// - **Registry lookup:** `promptedPolicyWith(configId:)` +
///   `PromptConfigRegistry` for A/B testing and rollback
/// - **Conversation window:** `SessionMode.dedicated` (per-policy
///   `PromptedPolicy.session`) or `SessionMode.shared` (one
///   `PromptSession` across policies)
///
/// ## Choose a cache
///
/// - **Default memoization:** `InMemoryVerdictCache` (TTL + LRU),
///   configured via `PromptConfig.verdictCacheTtl` /
///   `maxVerdictCacheEntries`
/// - **Cross-policy sharing:** pass one `VerdictCache` to several
///   `promptedPolicyWith` calls
/// - **Distributed backend:** implement `VerdictCache` (sync front
///   layer + async warming)
/// - **Second tier:** the rendered-prompt cache under
///   `PromptConfig.cacheTtl`
/// - **Manual diagnostics:** `cellContextFingerprint` /
///   `pulseContextFingerprint` / `decisionFingerprint` +
///   `VerdictCacheKey.composite` / `InMemoryVerdictCache.keys` —
///   ask "would this request hit?" before calling
///
/// ## Choose a session
///
/// - **Messages:** `ChatMessage` + `ChatRole`
/// - **History object:** `PromptSession` (bounds, compaction,
///   content-only fingerprints)
/// - **Mode:** `SessionMode.stateless` / `dedicated` / `shared`
/// - **Reset:** `PromptedPolicy.clearSession()` (journaled)
///
/// ## Choose a prompt config
///
/// - **Accept / reject / defer:** `PromptConfig.policyDecider()`
/// - **Label classification:** `PromptConfig.classifier(labels:)` +
///   `labelToVerdict`
/// - **Structured extraction:** `PromptConfig.extractor(fields:)` +
///   `extractionToVerdict`
/// - **Anything else:** `PromptConfig.custom(...)`
///
/// ## Verify a config against a real LLM
///
/// - **Pre-deploy gate:** `conform` → `PromptConformanceReport`
/// - **Case definition:** `ConformanceCase(context:, decision:,
///   expected:)`
///
/// ## Customize the prompt pipeline
///
/// - **Context rendering:** `renderContext` / `ContextRenderer`
/// - **Decision rendering:** `renderDecision` / `DecisionRenderer`
/// - **Response parsing:** `parseVerdict` / `VerdictParser`
/// - **Adapter:** `PromptFunction` — wrap your SDK in ~10 lines
///
/// ## Choose a bridge
///
/// - **Single LLM call:** `completion`
/// - **Streaming tokens:** `streamCompletion` / `streamChunks`
/// - **Tool calling:** `toolRouter`
///
/// ## Choose an explanation
///
/// - **Full narrative:** `DecisionPath.toNarrative(template: audit)`
/// - **UI-friendly:** `DecisionPath.toNarrative(template: ui)`
/// - **OTel spans:** `otelSpans`
///
/// ## Choose an agent
///
/// - **Single agent:** `spawn` with `AgentSpec`
/// - **Multi-agent vote:** `debate`
///
/// ## Choose a learning loop
///
/// - **Capture outcomes:** `recordOutcomes`
/// - **Train offline:** `trainOffline`
/// - **Deploy:** `TrainedPolicy.applyTo` + `learnedPolicy`
///
/// ## Do NOT use `cell_mind` for
///
/// - HTTP clients / LLM SDK adapters → user code or satellite packages
///   (wrap them in a `PromptFunction`)
/// - Model serving / inference → out of scope
/// - Training loops / fine-tuning → Python + a custom `Trainer`
/// - Vector databases → out of scope
/// - Retry logic / rate limiting on LLM calls → user code inside the
///   adapter
///
/// {@category Organ}
library;

export 'package:cell_mind/cell_mind.dart';
