// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// Assembles the complete prompt for one decision from a
/// [PromptConfig], the pre-rendered context/decision fragments, and an
/// optional [PromptSession].
///
/// Stateless layout (also used for empty sessions — byte-for-byte):
///
/// ```text
/// <systemPrompt>
///
/// ### Example 1
///
/// <example.render()>
/// ... (one section per example)
///
/// <userTemplate with {{context}} / {{decision}} substituted>
///
/// ## Expected Output
///
/// <outputSchema as JSON>
/// ```
///
/// Session-aware layout (non-empty session):
///
/// ```text
/// <systemPrompt>
///
/// ### Example 1
/// ... (examples, unchanged)
///
/// ## Conversation History
///
/// ### User
/// <turn 1 user content>
///
/// ### Assistant
/// <turn 1 verdict JSON>
/// ...
///
/// ## Current Request
///
/// <userTemplate with the CURRENT fragments substituted>
///
/// ## Expected Output
///
/// <outputSchema as JSON>
/// ```
///
/// Only `{{context}}` and `{{decision}}` are substituted; any other
/// `{{...}}` pattern is literal. Missing placeholders are allowed.
String _renderPromptConfig(
  PromptConfig config, {
  required String contextFragment,
  required String decisionFragment,
  PromptSession? session,
}) {
  final user = config.userTemplate
      .replaceAll('{{context}}', contextFragment)
      .replaceAll('{{decision}}', decisionFragment);
  final history = (session == null || session.isEmpty)
      ? ''
      : _renderSessionHistory(session);
  final buffer = StringBuffer()..write(config.systemPrompt);
  for (var i = 0; i < config.examples.length; i++) {
    buffer
      ..write('\n\n### Example ${i + 1}\n\n')
      ..write(config.examples[i].render());
  }
  buffer.write('\n\n');
  if (history.isNotEmpty) {
    buffer
      ..write(history)
      ..write('## Current Request\n\n');
  }
  buffer
    ..write(user)
    ..write('\n\n## Expected Output\n\n')
    ..write(jsonEncode(config.outputSchema))
    ..write('\n');
  return buffer.toString();
}
