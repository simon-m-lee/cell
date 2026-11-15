// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

// Content fingerprints for the verdict cache (D3).
//
// Every fingerprint is the sha256 of the canonical JSON of exactly the
// dimensions the renderer emits — sorted maps, declaration-order
// walks, empty dimensions omitted. Two inputs that render identically
// therefore fingerprint identically.

/// SHA-256 of the cell's `Ontology` + `Mandate` dimensions.
String _cellContextFingerprint(Context context) {
  final map = <String, Object?>{};
  for (final dimension in Ontology.values) {
    final value = context[dimension];
    if (!_isEmptyDimension(value)) map[dimension.name] = _canonicalize(value);
  }
  for (final dimension in Mandate.values) {
    final value = context[dimension];
    if (!_isEmptyDimension(value)) map[dimension.name] = _canonicalize(value);
  }
  return _sha256Hex(_jsonEncodeDeterministic(map));
}

/// SHA-256 of the pulse's `Provenance` dimensions (exactly what the
/// decision renderer emits, including `traceId`).
String _pulseContextFingerprint(Pulse pulse) {
  final map = <String, Object?>{};
  for (final dimension in Provenance.values) {
    final value = pulse.context[dimension];
    if (!_isEmptyDimension(value)) map[dimension.name] = _canonicalize(value);
  }
  return _sha256Hex(_jsonEncodeDeterministic(map));
}

/// SHA-256 of the decision shape: pulse payload + type + source, or a
/// command's function + arguments, or a link target.
String _decisionFingerprint(dynamic object, {dynamic arguments}) {
  final map = <String, Object?>{};
  if (object is Pulse) {
    map['type'] = _canonicalize(object.type);
    map['payload'] = _canonicalize(object.payload);
    map['source'] = object.source?.context.identity;
  } else if (object is Function) {
    map['function'] = '$object';
    map['arguments'] = _describeArguments(arguments);
  } else if (object is Cell) {
    map['target'] = object.context.identity;
  } else {
    map['value'] = '$object';
  }
  return _sha256Hex(_jsonEncodeDeterministic(map));
}

/// SHA-256 of the session message history (`''` when null/empty).
String _sessionFingerprintOf(PromptSession? session) {
  if (session == null || session.isEmpty) return '';
  final buffer = StringBuffer();
  for (final message in session.messages) {
    buffer
      ..write(message.role.name)
      ..write(':')
      ..write(message.content)
      ..write('\n');
  }
  return _sha256Hex(buffer.toString());
}
