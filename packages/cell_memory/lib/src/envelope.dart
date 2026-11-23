// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:collection' show SplayTreeMap;
import 'dart:convert' show JsonEncoder, JsonUnsupportedObjectError;
import 'dart:math' show Random;

import 'store.dart';

/// The document every [MemoryStore] backend persists.
///
/// Backends do not invent their own schema beyond how they persist this
/// map. The envelope is schema 1: `schema`, `id`, `kind`, `revision`,
/// `generation`, `updatedAt`, `codec`, `sourceCellId`, `payload` — in that
/// key order when serialised, with null optionals omitted.
///
/// [payload] is the JSON-encoded form of the retained value; it is never a
/// Dart object. [revision] is monotonic per [id], starting at 1; `0` is not
/// written — it means "absent" as an `expectedRevision`.
///
/// [generation] is the life of the record: minted once on the create and
/// copied onto every later revision. `remove` ends the life; the next
/// create mints a new one. A writer that carries a stale generation after
/// a delete-and-recreate is a conflict, closing the revision-number ABA
/// hole.
final class MemoryEnvelope {
  /// Creates an envelope.
  ///
  /// [updatedAt] defaults to the current UTC time. [schema] defaults to
  /// [schemaVersion]. [kind] must be `value` (the only accepted kind).
  /// [generation] must be 32 lowercase hex characters, as minted by
  /// [mintGeneration].
  MemoryEnvelope({
    required this.id,
    this.kind = 'value',
    required this.revision,
    required this.generation,
    DateTime? updatedAt,
    this.schema = schemaVersion,
    required this.payload,
    this.codec,
    this.sourceCellId,
  }) : updatedAt = (updatedAt ?? DateTime.now()).toUtc() {
    if (schema != schemaVersion) {
      throw MemoryCorrupt('unsupported envelope schema: $schema');
    }
    if (!kinds.contains(kind)) {
      throw MemoryCorrupt('unknown envelope kind: $kind');
    }
    if (revision < 1) {
      throw MemoryCorrupt('revision must be >= 1, got $revision');
    }
    if (id.isEmpty) {
      throw MemoryCorrupt('envelope id must not be empty');
    }
    if (!generationPattern.hasMatch(generation)) {
      throw MemoryCorrupt('generation must be 32 lowercase hex characters');
    }
  }

  /// The current envelope schema. Unknown schemas are a hard error, not a
  /// best-effort decode.
  static const int schemaVersion = 1;

  /// The envelope kinds accepted by [fromJson]. Only `value` exists;
  /// the pulse / tissue / snapshot kinds were never published and no
  /// longer decode.
  static const Set<String> kinds = {'value'};

  /// A generation is 32 lowercase hex characters: 16 bytes from
  /// [Random.secure].
  static final RegExp generationPattern = RegExp(r'^[0-9a-f]{32}$');

  /// Mints a new record generation: 16 bytes from [Random.secure] rendered
  /// as 32 lowercase hex characters. One value lives for the whole life of
  /// a record.
  static String mintGeneration() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Stable memory id. Not required to equal any `Cell.id`.
  final String id;

  /// `value` — the only accepted kind.
  final String kind;

  /// Monotonic per [id], starting at 1.
  final int revision;

  /// The life of the record. Minted on create, copied on every update,
  /// replaced by a fresh value after `remove`.
  final String generation;

  /// When this envelope was written, in UTC.
  final DateTime updatedAt;

  /// Envelope schema version; currently 1.
  final int schema;

  /// JSON-compatible payload. `null` is a valid value.
  final Object? payload;

  /// The codec's `name`, or `null` when the envelope does not record one.
  final String? codec;

  /// Informational. Never used as an identity key.
  final String? sourceCellId;

  /// Serialises this envelope with a stable key order so file diffs stay
  /// stable: `schema`, `id`, `kind`, `revision`, `generation`, `updatedAt`,
  /// `codec`, `sourceCellId`, `payload`. Null optionals are omitted.
  /// [payload] is stored through [JsonPayloadKey.canonical], so nested map
  /// key order cannot drift between file bytes and Firestore bytes.
  Map<String, Object?> toJson() => {
        'schema': schema,
        'id': id,
        'kind': kind,
        'revision': revision,
        'generation': generation,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (codec != null) 'codec': codec,
        if (sourceCellId != null) 'sourceCellId': sourceCellId,
        'payload': JsonPayloadKey.canonical(payload),
      };

  /// Decodes an envelope strictly.
  ///
  /// Unknown keys, a missing required key, an unknown [schema], an unknown
  /// [kind], a non-positive [revision], a malformed [generation], or a
  /// malformed [updatedAt] throw [MemoryCorrupt]. There is no best-effort
  /// decode, and a 0.1.0 document without `generation` does not decode.
  static MemoryEnvelope fromJson(Map<String, Object?> json) {
    const required = {
      'schema',
      'id',
      'kind',
      'revision',
      'generation',
      'updatedAt',
    };
    const optional = {'codec', 'sourceCellId'};
    const all = {...required, ...optional, 'payload'};
    final unknown = json.keys.where((k) => !all.contains(k)).toList()..sort();
    if (unknown.isNotEmpty) {
      throw MemoryCorrupt('unknown envelope keys: ${unknown.join(', ')}');
    }
    for (final key in required) {
      if (!json.containsKey(key)) {
        throw MemoryCorrupt('missing required envelope key: $key');
      }
    }
    if (!json.containsKey('payload')) {
      throw MemoryCorrupt('missing required envelope key: payload');
    }

    final schema = json['schema'];
    if (schema is! int || schema != schemaVersion) {
      throw MemoryCorrupt('unsupported envelope schema: $schema');
    }
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw MemoryCorrupt('envelope id must be a non-empty string');
    }
    final kind = json['kind'];
    if (kind is! String || !kinds.contains(kind)) {
      throw MemoryCorrupt('unknown envelope kind: $kind');
    }
    final revision = json['revision'];
    if (revision is! int || revision < 1) {
      throw MemoryCorrupt('revision must be an int >= 1, got $revision');
    }
    final generation = json['generation'];
    if (generation is! String || !generationPattern.hasMatch(generation)) {
      throw MemoryCorrupt('generation must be 32 lowercase hex characters');
    }
    final updatedAtRaw = json['updatedAt'];
    if (updatedAtRaw is! String) {
      throw MemoryCorrupt('updatedAt must be an ISO-8601 string');
    }
    final DateTime updatedAt;
    try {
      updatedAt = DateTime.parse(updatedAtRaw).toUtc();
    } on FormatException {
      throw MemoryCorrupt('malformed updatedAt: $updatedAtRaw');
    }
    final codec = json['codec'];
    if (codec != null && codec is! String) {
      throw MemoryCorrupt('codec must be a string when present');
    }
    final sourceCellId = json['sourceCellId'];
    if (sourceCellId != null && sourceCellId is! String) {
      throw MemoryCorrupt('sourceCellId must be a string when present');
    }

    return MemoryEnvelope(
      id: id,
      kind: kind,
      revision: revision,
      generation: generation,
      updatedAt: updatedAt,
      schema: schema,
      payload: json['payload'],
      codec: codec as String?,
      sourceCellId: sourceCellId as String?,
    );
  }

  /// Whether [other] carries the same
  /// `(id, kind, revision, generation, codec, payload)`.
  ///
  /// `updatedAt` and `sourceCellId` are intentionally not compared; this is
  /// the idempotent-retry comparison. A retry with the same payload but a
  /// different generation is a conflict, not a no-op.
  bool sameContent(MemoryEnvelope other) =>
      other.id == id &&
      other.kind == kind &&
      other.revision == revision &&
      other.generation == generation &&
      other.codec == codec &&
      _payloadKey(other.payload) == _payloadKey(payload);

  static String _payloadKey(Object? payload) =>
      const JsonPayloadKey().keyOf(payload);

  @override
  String toString() =>
      'MemoryEnvelope(id: $id, kind: $kind, revision: $revision, '
      'generation: $generation, schema: $schema)';
}

/// Stable payload comparison for the store's no-op rule and the cell's
/// dirty detection.
///
/// Two payloads are equal when their canonical JSON encodings are equal,
/// not when their Dart `==` says so. Map keys are sorted recursively, so
/// key order cannot cause a spurious mismatch.
final class JsonPayloadKey {
  /// Creates a payload-key computer.
  const JsonPayloadKey();

  /// Returns a canonical JSON string for [payload].
  String keyOf(Object? payload) {
    try {
      return const JsonEncoder().convert(canonical(payload));
    } on JsonUnsupportedObjectError catch (e) {
      throw MemoryCorrupt('payload is not JSON-encodable: $e');
    }
  }

  /// Returns the canonical JSON structure for [payload]: `Map` keys sorted
  /// recursively, `List`s walked element by element.
  ///
  /// A `Set` is returned unchanged — `toJson` must not silently start
  /// encoding sets, and serialising one fails with
  /// [JsonUnsupportedObjectError] as before.
  static Object? canonical(Object? value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        sorted[entry.key.toString()] = canonical(entry.value);
      }
      return sorted;
    }
    if (value is List) {
      return [for (final element in value) canonical(element)];
    }
    return value;
  }
}
