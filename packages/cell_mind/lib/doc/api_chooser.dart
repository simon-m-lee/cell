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
/// 5. **Talk to an LLM or external system?** → the `bridge` module
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
///
/// ## Choose a decision primitive
///
/// | Need | Type |
/// |---|---|
/// | Simple accept/reject | `Policy` |
/// | Accept/reject/defer | `VerdictPolicy` |
/// | Record decisions | `CognitiveHandle` |
///
/// ## Choose a policy
///
/// - **Domain-gated:** `domainPolicy` + `requiresDomainPolicy`
/// - **Authority-gated:** `authorityPolicy` + `exactFunctionsPolicy`
/// - **Compliance-gated:** `compliancePolicy`
/// - **Confidence-gated:** `confidencePolicy`
/// - **Strategy-gated:** `strategyPolicy`
/// - **Full stack:** `contextAware` or `paranoid`
///
/// ## Choose a deferral
///
/// - **Human approval:** `ApprovalQueue` + `approvalResolver`
/// - **Custom resolver:** `onDeferred` callback on `cognitive`
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
/// - HTTP clients → user code or satellite packages
/// - Model serving / inference → out of scope
/// - Training loops / fine-tuning → Python + a custom `Trainer`
/// - Vector databases → out of scope
/// - Prompt templating → out of scope
///
/// {@category Organ}
library;

export 'package:cell_mind/cell_mind.dart';
