// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// The role of a message in a chat session.
///
/// ### When to use
/// Tag every [ChatMessage] you append to a [PromptSession]. The
/// prompted policy produces `user` messages (the rendered
/// `(Context, Decision)` block) and `assistant` messages (the raw
/// verdict JSON); `system` is for initial instructions.
///
/// ### How it works
/// A three-value enum serialized by [name] in [ChatMessage.toMap].
///
/// ### Non-obvious
/// - **Roles are structural, not semantic gates.** The renderer uses
///   the role only to choose the `### User` / `### Assistant` /
///   `### System` heading.
///
/// ### See also
/// - [ChatMessage], [PromptSession]
///
/// ## AI Agent Guide
/// - Never invent new roles; extend the renderer instead if a custom
///   heading shape is required.
///
/// {@category Organ}
/// {@category Prompt}
/// {@category Session}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
enum ChatRole {
  /// A system-level instruction prepended to the conversation.
  system,

  /// A user message — either the human's question or, in `cell_mind`, a
  /// rendered `(Context, Decision)` block.
  user,

  /// An assistant message — the LLM's response, typically the raw
  /// verdict JSON.
  assistant,
}

/// A single message in a [PromptSession].
///
/// ### When to use
/// Construct `user` / `assistant` pairs per decision, or `system`
/// instructions when the session is created.
///
/// ### How it works
/// An immutable `(role, content)` value object with
/// `toMap` / `fromMap` and value equality.
///
/// ### Non-obvious
/// - **Content is opaque text.** For `user` messages produced by
///   `cell_mind`, the content is the rendered `(Context, Decision)`
///   block. For `assistant` messages, it's the raw JSON response.
/// - **No timestamps.** Messages are ordered by insertion, not by
///   time. This makes session fingerprints deterministic.
///
/// ### See also
/// - [PromptSession], [ChatRole]
///
/// ## AI Agent Guide
/// - Treat messages as immutable data; reconstruct via
///   [ChatMessage.fromMap] rather than hand-building maps.
///
/// {@category Organ}
/// {@category Prompt}
/// {@category Session}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class ChatMessage {
  /// The speaker role.
  final ChatRole role;

  /// The opaque message text.
  final String content;

  const ChatMessage({required this.role, required this.content});

  /// Serializes this message (role name + content).
  Map<String, dynamic> toMap() => {
        'role': role.name,
        'content': content,
      };

  /// Reconstructs a message from [ChatMessage.toMap] output.
  static ChatMessage fromMap(Map<String, dynamic> map) => ChatMessage(
        role: ChatRole.values.firstWhere(
          (r) => r.name == map['role'],
          orElse: () => ChatRole.system,
        ),
        content: map['content'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is ChatMessage && other.role == role && other.content == content;

  @override
  int get hashCode => Object.hash(role, content);

  @override
  String toString() => 'ChatMessage(${role.name}, ${content.length} chars)';
}

/// A bounded, ordered conversation history for prompted policy.
///
/// ### When to use
/// When a `PromptConfig` uses [SessionMode.dedicated] or
/// [SessionMode.shared]. The session is passed to `promptedPolicyWith`
/// (for `shared`) or created automatically (for `dedicated`).
///
/// ### How it works
/// 1. The session holds an ordered list of [ChatMessage]s.
/// 2. On each decision, the session is rendered into the prompt.
/// 3. After the LLM responds, the `(user, assistant)` pair is
///    appended.
/// 4. When `maxMessages` or `maxChars` is exceeded, oldest non-system
///    pairs are dropped (never partial — always pairs).
/// 5. `fingerprint()` returns a stable hash of the message content,
///    used for the verdict cache key.
///
/// ### Non-obvious
/// - **Append-only between clears.** No editing, no deleting
///   individual messages. `clear()` resets entirely.
/// - **Compaction is deterministic.** The same message sequence with
///   the same thresholds produces the same compacted state.
/// - **Fingerprint excludes timestamps.** Two sessions with identical
///   content produce identical fingerprints — even if created at
///   different times.
/// - **Empty sessions fingerprint to `''`** — so stateless and
///   empty-session decisions share verdict cache keys.
///
/// ### See also
/// - [ChatMessage], [SessionMode], `promptedPolicyWith`
///
/// ## AI Agent Guide
/// - Prefer [appendExchange] over two [append] calls; pairs stay
///   consistent during compaction.
///
/// {@category Organ}
/// {@category Prompt}
/// {@category Session}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class PromptSession {
  /// The stable session identity.
  final String id;

  /// The message-count bound (compaction trigger).
  final int maxMessages;

  /// The total-character bound (compaction trigger).
  final int maxChars;

  final List<ChatMessage> _messages;

  PromptSession({
    String? id,
    this.maxMessages = 40,
    this.maxChars = 20000,
  })  : id = id ?? Identity.next(),
        _messages = [];

  /// The current messages in the session (unmodifiable view).
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// The number of messages.
  int get length => _messages.length;

  /// The total character count across all messages.
  int get totalChars => _messages.fold(0, (sum, m) => sum + m.content.length);

  /// Whether the session is empty.
  bool get isEmpty => _messages.isEmpty;

  /// Appends a single message. Triggers compaction if needed.
  ///
  /// ### Non-obvious
  /// Compaction drops complete `(user, assistant)` pairs first —
  /// single appends of an unpaired message may be compacted away
  /// later. Use [appendExchange] for decision exchanges.
  void append(ChatMessage message) {
    _messages.add(message);
    _appendInternal(message);
  }

  /// Appends a `(user, assistant)` pair atomically. Preferred over
  /// calling [append] twice — keeps pairs consistent during
  /// compaction.
  void appendExchange(ChatMessage user, ChatMessage assistant) {
    _appendExchangeCounted(user, assistant);
  }

  // Internal: append a pair and return the dropped-pair count. The
  // prompted policy journals `SessionCompactedEffect` per drop.
  int _appendExchangeCounted(ChatMessage user, ChatMessage assistant) {
    _messages.add(user);
    _messages.add(assistant);
    return _compact();
  }

  // Shared append tail: compaction after insertion.
  int _appendInternal(ChatMessage _) => _compact();

  /// Removes all messages.
  void clear() => _messages.clear();

  /// Returns a stable fingerprint for cache keying.
  ///
  /// ### Non-obvious
  /// - Excludes timestamps. Two sessions with identical content
  ///   produce identical fingerprints.
  /// - Empty sessions fingerprint to `''` (empty string), so
  ///   stateless and empty-session cases share cache keys.
  String fingerprint() {
    if (_messages.isEmpty) return '';
    final buffer = StringBuffer();
    for (final message in _messages) {
      buffer
        ..write(message.role.name)
        ..write(':')
        ..write(message.content)
        ..write('\n');
    }
    return _sha256Hex(buffer.toString());
  }

  /// Serializes the session (id, thresholds, messages).
  Map<String, dynamic> toMap() => {
        'id': id,
        'maxMessages': maxMessages,
        'maxChars': maxChars,
        'messages': _messages.map((m) => m.toMap()).toList(),
      };

  /// Reconstructs a session from [PromptSession.toMap] output.
  static PromptSession fromMap(Map<String, dynamic> map) => PromptSession(
        id: map['id'] as String,
        maxMessages: map['maxMessages'] as int? ?? 40,
        maxChars: map['maxChars'] as int? ?? 20000,
      ).._messages.addAll(
          (map['messages'] as List? ?? const [])
              .map((m) =>
                  ChatMessage.fromMap((m as Map).cast<String, dynamic>()))
              .toList(),
        );

  /// The deterministic compaction pass. Returns the dropped-pair count.
  ///
  /// Rules (guide 12 §9):
  /// 1. Drop the oldest complete non-system `(user, assistant)` pairs
  ///    while over `maxMessages` or `maxChars`.
  /// 2. Never drop system messages while any pair is droppable.
  /// 3. Fallback: drop the oldest system message that is not the
  ///    session's first message.
  /// 4. A single remaining message is kept regardless.
  int _compact() {
    var droppedPairs = 0;
    while (_messages.length > maxMessages || totalChars > maxChars) {
      if (_dropOldestPair()) {
        droppedPairs++;
        continue;
      }
      if (_messages.length <= 1) break;
      if (_dropOldestNonInitialSystem()) continue;
      break;
    }
    return droppedPairs;
  }

  /// Finds the oldest `user` message directly followed by an
  /// `assistant` message and removes both. Returns whether one was
  /// dropped.
  bool _dropOldestPair() {
    for (var i = 0; i < _messages.length - 1; i++) {
      if (_messages[i].role == ChatRole.user &&
          _messages[i + 1].role == ChatRole.assistant) {
        _messages.removeAt(i + 1);
        _messages.removeAt(i);
        return true;
      }
    }
    return false;
  }

  /// Drops the oldest system message that is not the session's first
  /// message. Returns whether one was dropped.
  bool _dropOldestNonInitialSystem() {
    for (var i = _messages.isEmpty ? 0 : 1; i < _messages.length; i++) {
      if (_messages[i].role == ChatRole.system) {
        _messages.removeAt(i);
        return true;
      }
    }
    return false;
  }
}
