// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert';

import 'store.dart';

/// The value the codec refused to serialise.
///
/// Closures, receptors, and live cell instances are not payloads. The codec
/// throws this before the store is called, so nothing is written.
final class MemoryNotSerializable implements Exception {
  /// Creates a serialisation refusal.
  const MemoryNotSerializable(this.message);

  /// Why the value cannot be serialised.
  final String message;

  @override
  String toString() => 'MemoryNotSerializable: $message';
}

/// Converts a retained value to and from the JSON-compatible form stored
/// inside a [MemoryEnvelope].
abstract interface class MemoryCodec<T> {
  /// The codec name recorded on the envelope (for example `json`).
  String get name;

  /// Encodes [value] to a JSON-compatible form.
  ///
  /// Must throw [MemoryNotSerializable] rather than writing
  /// `"Instance of '…'"` for a non-serialisable value.
  Object? encode(T value);

  /// Decodes a stored payload back to [T].
  ///
  /// A payload that is not a valid [T] throws [MemoryCorrupt].
  T decode(Object? payload);
}

/// A codec for values that are already JSON.
///
/// Use [JsonMemoryCodec.identity] when [T] is `null`, `bool`, `num`,
/// `String`, `List`, or `Map<String, Object?>`, and
/// [JsonMemoryCodec.mapped] when a `toJson` / `fromJson` pair stands in.
final class JsonMemoryCodec<T> implements MemoryCodec<T> {
  JsonMemoryCodec._(this._toJson, this._fromJson);

  /// A codec whose [T] is already a JSON value.
  ///
  /// [encode] returns a JSON-decoded deep copy of the value, never the
  /// value itself: mutations of the retained object cannot alias what was
  /// stored, and every backend sees the same plain-JSON shape.
  /// [decode] casts it and throws [MemoryCorrupt] when the cast fails.
  /// Because `jsonDecode` produces `List<dynamic>` /
  /// `Map<String, dynamic>`, the `is` check runs first so a decoded
  /// `List<dynamic>` decodes as `List<int>` (Dart's `as` would reject it
  /// where `is` accepts it).
  factory JsonMemoryCodec.identity() => JsonMemoryCodec<T>._(
        (value) => value,
        (payload) {
          if (payload is T) return payload;
          // Cross-platform number semantics: the web encodes 1.0 as 1, so a
          // VM decoding a web-written double sees an int. A num fallback
          // lets `double` cells load both shapes; non-double Ts fall
          // through to the strict cast.
          if (payload is num) {
            try {
              return payload.toDouble() as T;
            } catch (_) {
              // Not a double cell; fall through to the strict error.
            }
          }
          try {
            return payload as T;
          } catch (e) {
            throw MemoryCorrupt(
              'payload ${payload.runtimeType} cannot be decoded as $T',
            );
          }
        },
      );

  /// A codec using a caller-supplied mapping pair.
  ///
  /// [toJson] produces the JSON form; [fromJson] rebuilds [T] and may throw
  /// [MemoryCorrupt] for an invalid payload. [encode] verifies the result of
  /// [toJson] is JSON-encodable.
  factory JsonMemoryCodec.mapped({
    required Object? Function(T value) toJson,
    required T Function(Object? payload) fromJson,
  }) =>
      JsonMemoryCodec<T>._(
        toJson,
        (payload) {
          try {
            return fromJson(payload);
          } on MemoryCorrupt {
            rethrow;
          } catch (e) {
            throw MemoryCorrupt(
              'payload ${payload.runtimeType} cannot be decoded as $T: $e',
            );
          }
        },
      );

  final Object? Function(T value) _toJson;

  final T Function(Object? payload) _fromJson;

  @override
  String get name => 'json';

  @override
  Object? encode(T value) {
    final mapped = _toJson(value);
    try {
      // Validates, deep-copies, and normalises to plain JSON in one step:
      // the returned value never aliases [value], and every backend sees
      // the same JSON-decoded shape instead of a `toJson()` object.
      return jsonDecode(jsonEncode(mapped));
    } on JsonUnsupportedObjectError catch (e) {
      throw MemoryNotSerializable(
        'value of type ${value.runtimeType} mapped to a payload that is '
        'not JSON-encodable: $e',
      );
    }
  }

  @override
  T decode(Object? payload) => _fromJson(payload);
}
