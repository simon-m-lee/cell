// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// Renders a decision (pulse, action, or link) into the `## Decision`
/// prompt fragment.
///
/// ### When to use
/// The default [DecisionRenderer] for [promptedPolicy] and
/// [promptedPolicyWith]. Pass it (or a wrapper around it) as the
/// `decisionRenderer:` parameter when you need the standard rendering
/// plus custom additions.
///
/// ### How it works
/// - **Pulses** render their type, payload (deterministic JSON when
///   encodable), source identity, timestamp, and every [Provenance]
///   dimension in declaration order.
/// - **Actions** (`Function` objects) render their name and the
///   dispatch arguments.
/// - **Links** (`Cell` objects) render the target's identity.
/// - Unknown objects degrade to `type` + `value` lines.
///
/// ### Non-obvious
/// - **Empty provenance dimensions are omitted**, exactly like the
///   context renderer.
/// - **Non-encodable payloads degrade to `toString()`** — lossy, but
///   deterministic (the same object always renders the same way).
/// - **Named argument keys are Symbols** and render as their plain
///   names.
///
/// ### See also
/// - [renderContext], [PromptConfig.render], `promptedPolicyWith`
///
/// ## AI Agent Guide
/// - Prefer this renderer over hand-rolled prompt fragments; it pins
///   determinism guarantees that the cache and replay rely on.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
String renderDecision(dynamic object, {Cell? host, dynamic arguments}) {
  final lines = <String>[];
  if (object is Pulse) {
    lines.add('- type: ${object.type ?? 'unknown'}');
    lines.add('- payload: ${_jsonOrText(object.payload)}');
    final source = object.source;
    lines.add(
      '- source: ${source?.context.identity ?? '(unknown)'}',
    );
    // The pulse timestamp is deliberately NOT rendered: it changes on
    // every emission and would break prompt determinism (the cache and
    // replay compare prompts byte-for-byte).
    for (final dimension in Provenance.values) {
      final value = object.context[dimension];
      if (_isEmptyDimension(value)) continue;
      lines.add('- ${dimension.name}: ${_dimensionText(value)}');
    }
  } else if (object is Function) {
    lines.add('- type: action');
    lines.add('- function: $object');
    lines.add(
      '- arguments: ${_jsonEncodeDeterministic(_describeArguments(arguments))}',
    );
  } else if (object is Cell) {
    lines.add('- type: link');
    lines.add('- target: ${object.context.identity ?? '(anonymous)'}');
  } else {
    lines.add('- type: ${object.runtimeType}');
    lines.add('- value: ${_jsonOrText(object)}');
  }
  return '## Decision\n\n${lines.join('\n')}';
}

/// Encodes [value] as deterministic JSON when it is encodable,
/// otherwise its `toString()` (documented lossy degradation).
String _jsonOrText(Object? value) {
  try {
    return _jsonEncodeDeterministic(value);
  } on JsonUnsupportedObjectError {
    return value.toString();
  }
}

/// The encodable description of a dispatch's arguments record.
Map<String, dynamic> _describeArguments(dynamic arguments) {
  if (arguments is Arguments) {
    return {
      'positional': arguments.positionalArguments?.map(_canonicalize).toList(),
      'named': {
        for (final entry in (arguments.namedArguments ?? const {}).entries)
          _symbolName(entry.key): _canonicalize(entry.value),
      },
    };
  }
  if (arguments is ApplyArguments) {
    return {
      'positional': arguments.positionalArguments?.map(_canonicalize).toList(),
      'named': {
        for (final entry in (arguments.namedArguments ?? const {}).entries)
          _symbolName(entry.key): _canonicalize(entry.value),
      },
    };
  }
  return {'raw': _canonicalize(arguments)};
}
