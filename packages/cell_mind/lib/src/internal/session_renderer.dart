// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// Renders the conversation history block of a [PromptSession].
///
/// Each message becomes a `### <Role>` heading followed by the raw
/// message content, in insertion order:
///
/// ```text
/// ## Conversation History
///
/// ### User
/// <content>
///
/// ### Assistant
/// <content>
/// ```
///
/// Empty sessions render nothing (the caller omits the history block
/// entirely — empty sessions share the stateless prompt layout, and
/// therefore the stateless cache keys).
String _renderSessionHistory(PromptSession session) {
  final buffer = StringBuffer();
  for (final message in session.messages) {
    buffer
      ..write('### ')
      ..write(_roleHeading(message.role))
      ..write('\n')
      ..write(message.content)
      ..write('\n\n');
  }
  final text = buffer.toString();
  if (text.trim().isEmpty) return '';
  return '## Conversation History\n\n$text';
}

/// The Markdown heading for a [ChatRole].
String _roleHeading(ChatRole role) => switch (role) {
      ChatRole.system => 'System',
      ChatRole.user => 'User',
      ChatRole.assistant => 'Assistant',
    };
