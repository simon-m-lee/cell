// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert';

/// A deterministic JSON encoder.
///
/// The Dart SDK's `jsonEncode` preserves insertion order for maps and does
/// not normalize numeric representations. That makes it unsuitable for
/// hashing or for "canonical bytes" comparisons, both of which the replay
/// ledger depends on.
///
/// [canonicalJsonEncode] guarantees:
///
/// * **Map keys are sorted lexicographically.** Two maps with the same
///   entries but different insertion orders produce identical output.
/// * **No trailing whitespace.** Output is `{"a":1,"b":2}`, never
///   `{ "a": 1, "b": 2 }`.
/// * **Integers vs. doubles.** `1` (int) and `1.0` (double) both encode as
///   `1` only when the int representation is exact; otherwise `1.0` stays
///   as `1.0`. This mirrors the JSON spec's ambiguity and matches what
///   `jsonDecode` produces on re-read.
/// * **Null omission is opt-in.** By default, `null` values are preserved
///   (`{"a":null}`) because the codec layer needs to distinguish "absent"
///   from "null" for optional pulse fields. Pass `omitNulls: true` when
///   the domain has no such distinction.
///
/// All other values must be JSON-encodable primitives, `List`, or `Map`.
/// `DateTime` values are rejected by default; encode them as epoch
/// milliseconds or ISO-8601 explicitly in the caller, so the wire format
/// is unambiguous.
String canonicalJsonEncode(
  Object? value, {
  bool omitNulls = false,
}) {
  final buf = StringBuffer();
  _write(buf, value, omitNulls);
  return buf.toString();
}

/// Decodes a canonical JSON string into a JSON-encodable object tree.
///
/// This is a thin wrapper over [jsonDecode] that exists so callers have a
/// matched pair of (encode, decode) helpers and don't accidentally mix
/// `jsonEncode` with `canonicalJsonEncode`.
Object? canonicalJsonDecode(String source) => jsonDecode(source);

void _write(StringBuffer buf, Object? value, bool omitNulls) {
  if (value == null) {
    buf.write('null');
  } else if (value is bool) {
    buf.write(value ? 'true' : 'false');
  } else if (value is int) {
    buf.write(value.toString());
  } else if (value is double) {
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError.value(
        value,
        'value',
        'Cannot encode NaN/Infinity to canonical JSON.',
      );
    }
    buf.write(_encodeDouble(value));
  } else if (value is String) {
    buf.write(jsonEncode(value));
  } else if (value is List) {
    buf.write('[');
    var first = true;
    for (final item in value) {
      if (!first) buf.write(',');
      first = false;
      _write(buf, item, omitNulls);
    }
    buf.write(']');
  } else if (value is Map) {
    final keys = value.keys.toList()
      ..sort((a, b) => _compareKeys(a, b));
    buf.write('{');
    var first = true;
    for (final key in keys) {
      if (key is! String) {
        throw ArgumentError.value(
          key,
          'key',
          'Canonical JSON requires String keys, got ${key.runtimeType}.',
        );
      }
      final v = value[key];
      if (omitNulls && v == null) continue;
      if (!first) buf.write(',');
      first = false;
      buf.write(jsonEncode(key));
      buf.write(':');
      _write(buf, v, omitNulls);
    }
    buf.write('}');
  } else {
    throw ArgumentError.value(
      value,
      'value',
      'Canonical JSON cannot encode ${value.runtimeType}. '
      'Convert it to a primitive, List, or Map first.',
    );
  }
}

String _encodeDouble(double d) {
  // `double.toString()` on the Dart VM emits the shortest representation
  // that round-trips. It can emit `1.0` for `1.0` — which canonicalJson
  // deliberately preserves (see the docstring). Only the literal `NaN`/
  // `Infinity` cases are special, and they are rejected above.
  final s = d.toString();
  if (s.contains('e') || s.contains('E')) {
    final reparsed = double.tryParse(s);
    if (reparsed == null || reparsed.isNaN || reparsed.isInfinite) {
      throw ArgumentError.value(d, 'value', 'Unrepresentable double.');
    }
  }
  return s;
}

int _compareKeys(Object? a, Object? b) {
  final sa = a is String ? a : '$a';
  final sb = b is String ? b : '$b';
  return sa.compareTo(sb);
}
