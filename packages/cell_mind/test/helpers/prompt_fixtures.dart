// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';

/// A mock LLM adapter with a call log, returning [response].
PromptFunction mockPrompt(
  String response, {
  List<String>? log,
}) {
  return (prompt) async {
    log?.add(prompt);
    return response;
  };
}

/// The accept-shaped response used across the suite.
const acceptResponse = '{"verdict":"accept","reason":"within limits"}';

/// The reject-shaped response used across the suite.
const rejectResponse = '{"verdict":"reject","reason":"policy violation"}';

/// The defer-shaped response used across the suite.
const deferResponse = '{"verdict":"defer","resolver":"approval"}';

/// A prompt-config fixture with a tiny system prompt (short renders).
///
/// Each call gets a fresh id — tests stay isolated from the
/// process-wide content-addressed cache. Use a fixed-id custom config
/// when the test wants to exercise config-mode cache sharing.
PromptConfig tinyConfig({Duration? cacheTtl, SessionMode? sessionMode}) =>
    PromptConfig.custom(
      id: 'tiny-${Identity.next()}',
      version: '1.0.0',
      description: 'Tiny test config',
      systemPrompt: 'Decide.',
      userTemplate: '{{context}}\n\n{{decision}}',
      examples: const [],
      cacheTtl: cacheTtl,
      sessionMode: sessionMode,
    );

/// A context fixture exercising several dimensions.
Context promptContext() => Context(
      domains: 'finance,audit',
      compliances: 'GDPR',
      constraints: {'max_amount': 10000},
    );

/// An [ApplyCommand] over [fn] with optional positional [args].
ApplyCommand commandFor(Function fn, [List<Object?>? args]) => (
      function: fn,
      arguments: (positionalArguments: args, namedArguments: null),
      compensation: null,
    );
