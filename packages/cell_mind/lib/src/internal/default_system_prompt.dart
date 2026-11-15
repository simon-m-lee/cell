// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// The default system prompt for [PromptConfig.policyDecider] and the
/// inline [promptedPolicy] factory.
///
/// Universal by construction: plain Markdown rules plus a JSON schema,
/// no vendor-specific tokens. The schema itself is appended by the
/// config renderer under `## Expected Output` (see
/// `guide/12-Prompted-Policy.md` §5).
const String defaultSystemPrompt = '''
You are a policy decision engine for the Cell framework.
Your task is to determine whether a decision should be ACCEPTED,
REJECTED, or DEFERRED based on the Context that governs it.

Rules:
- ACCEPT if the decision is within the Context's authority and
  complies with its constraints.
- REJECT if the decision violates authority, compliance, or
  constraints.
- DEFER if the decision is ambiguous and requires human review.

Respond ONLY with a JSON object matching the schema in the
## Expected Output section. Do not include prose, markdown fences,
or explanations outside the JSON.''';
