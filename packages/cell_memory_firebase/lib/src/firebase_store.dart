// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert';

import 'package:cell_memory/cell_memory.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: implementation_imports
import 'package:cell_memory/src/store_lifecycle.dart';

/// A [MemoryStore] over Cloud Firestore documents.
///
/// The path is fixed per signed-in user:
///
/// ```text
/// users / {uid} / cell_memory / {id}
/// ```
///
/// The app calls `Firebase.initializeApp` and resolves the signed-in user
/// before constructing this store; the store does neither, and it does not
/// read `FirebaseAuth.instance`. The uid is the Firebase Auth uid the
/// caller already has — rules still require the request token's uid to
/// equal that path segment. One store per session: the uid is fixed at
/// construction, so close the store (and its cells) on sign-out and build
/// a fresh one after the next sign-in.
///
/// Connectivity is load-bearing: reads use [Source.server] by default (no
/// silent stale-cache load; an offline read surfaces as
/// [MemoryIoException]), and writes are `runTransaction` calls that always
/// need the server. Offline edits are not queued — the caller decides what
/// to retry — and a transaction aborts after the configured timeout.
///
/// v1 is request/response only: no snapshot listener (a listener would
/// echo), no `collectionGroup` query, and no offline-persistence toggling.
/// `write` is one `runTransaction` whose read and compare-and-swap happen
/// inside the callback, so a blind `set` can never win a lost race.
///
/// Firestore limits are load-bearing too: documents are capped at 1 MiB
/// (enforced here with a clear error), and one document sustains roughly
/// one write per second — prefer [firestoreWritePolicy] for cells fed by
/// fast pulse streams. [remove] deletes without an expected revision, so
/// the revision history resets: a later write to the same id starts at
/// revision 1 (a stale writer from before the delete can in principle
/// re-win the same revision number — the ABA shape — which is the
/// documented cost of the simple delete protocol).
final class FirebaseMemoryStore implements MemoryStore {
  /// Creates a store for [uid] over [firestore].
  ///
  /// [uid] must be a non-empty Firebase Auth uid without `/`. An empty uid
  /// or one containing `/` throws [ArgumentError] before any request;
  /// other uid grammars are the auth provider's business and surface at
  /// request time.
  ///
  /// [readSource] selects the get source ([Source.server] by default: a
  /// load never silently returns stale cached state; pass [Source.cache] to
  /// opt back into cache reads).
  ///
  /// [transactionTimeout] and [transactionMaxAttempts] tune
  /// `runTransaction` (SDK defaults: 30 s, 5 attempts).
  FirebaseMemoryStore({
    required FirebaseFirestore firestore,
    required String uid,
    Source readSource = Source.server,
    Duration transactionTimeout = const Duration(seconds: 30),
    int transactionMaxAttempts = 5,
  })  : _firestore = firestore,
        _uid = uid,
        _readSource = readSource,
        _transactionTimeout = transactionTimeout,
        _transactionMaxAttempts = transactionMaxAttempts {
    if (uid.isEmpty || uid.contains('/')) {
      throw ArgumentError.value(
        uid,
        'uid',
        'uid must be a non-empty Firebase Auth uid without "/"',
      );
    }
  }

  /// The shared memory id grammar: `^[A-Za-z0-9._-]{1,128}$`, neither `.`
  /// nor `..`. Rejected before a request is sent.
  static final RegExp idPattern = MemoryIdGrammar.pattern;

  /// Firestore's maximum document size.
  static const int maxDocumentBytes = 1024 * 1024;

  final FirebaseFirestore _firestore;

  final String _uid;

  final Source _readSource;

  final Duration _transactionTimeout;

  final int _transactionMaxAttempts;

  final StoreLifecycle _lifecycle =
      StoreLifecycle('FirebaseMemoryStore is closed');

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('cell_memory');

  DocumentReference<Map<String, dynamic>> _doc(String id) {
    MemoryIdGrammar.check(id);
    return _collection.doc(id);
  }

  /// One in-process serialisation chain per id, like the other stores:
  /// server transactions cover write/write and write/remove, and this
  /// chain covers the rest of the `MemoryStore` contract (reads and lists
  /// are ordered against the operations that started before them).
  final Map<String, Future<void>> _chains = {};

  Future<T> _perId<T>(String id, Future<T> Function() run) {
    final previous = _chains[id] ?? Future<void>.value();
    final completer = previous.then((_) => run());
    final chain = completer.then<void>((_) {}, onError: (_) {});
    _chains[id] = chain;
    chain.whenComplete(() {
      if (identical(_chains[id], chain)) _chains.remove(id);
    });
    return completer;
  }

  @override
  Future<MemoryEnvelope?> read(String id) async {
    return _lifecycle.run(() => _perId(id, () async {
      try {
        final snapshot = await _doc(id).get(GetOptions(source: _readSource));
        if (!snapshot.exists) return null;
        final data = snapshot.data();
        if (data == null) {
          // A document that exists but has no data is corrupt, not absent:
          // treating it as absent would let the next write overwrite it.
          throw MemoryCorrupt('document for "$id" exists with null data');
        }
        return decodeDocument(id, data);
      } on FirebaseException catch (e) {
        throw MemoryIoException(
          'firestore read failed (${e.code}): ${e.message}',
          cause: e,
        );
      }
    }));
  }

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    return _lifecycle.run(() => _perId(envelope.id, () async {
      // Numbering pre-check: the only envelopes a write may carry are the
      // fresh shape (`expected + 1`) and the equal-revision retry shape
      // (`expected`, matching MemoryStoreCas.isIdempotentRetry: the store
      // already holds exactly this row). Anything else is corrupt before
      // any I/O.
      if (envelope.revision != expectedRevision + 1 &&
          envelope.revision != expectedRevision) {
        throw MemoryCorrupt(
          'envelope revision ${envelope.revision} is neither '
          'expectedRevision + 1 ($expectedRevision + 1) nor the '
          'equal-revision retry shape ($expectedRevision)',
        );
      }
      final ref = _doc(envelope.id);
      // Encode exactly once, before any I/O: an unencodable payload (for
      // example a NaN) is a MemoryNotSerializable, never a raw
      // JsonUnsupportedObjectError from inside the transaction callback,
      // and the size guard fails with a clear error instead of a generic
      // invalid-argument from Firestore.
      final document = _encodeGuarded(envelope);
      // Size guard: `FieldValue.serverTimestamp` is not JSON-encodable, so
      // measure with a numeric placeholder — accurate to within the few
      // bytes of a timestamp's digits, which is plenty for a guard whose
      // purpose is a clear error instead of a generic invalid-argument.
      final bytes = utf8.encode(jsonEncode({...document, 'updatedAt': 0})).length;
      if (bytes > maxDocumentBytes) {
        throw MemoryNotSerializable(
          'encoded document for "${envelope.id}" is $bytes bytes; '
          'Firestore caps documents at $maxDocumentBytes bytes (1 MiB)',
        );
      }
      try {
        // The handler reports every outcome as a plain return value —
        // success, MemoryConflict, or MemoryCorrupt — never as a thrown
        // Dart exception: `runTransaction` may run the callback more than
        // once, platform channels may wrap callback failures, and an
        // exception is not a clean "do not retry" signal. Outcomes are
        // translated back outside the transaction, so the failure type
        // survives.
        final outcome = await _firestore.runTransaction<Object?>(
          (transaction) async {
            final snapshot = await transaction.get(ref);
            if (!snapshot.exists) {
              if (envelope.revision != expectedRevision + 1) {
                return MemoryCorrupt(
                  'writing "${envelope.id}": the record is absent but the '
                  'envelope carries the equal-revision retry shape',
                );
              }
              transaction.set(ref, document);
              return null;
            }
            final data = snapshot.data();
            if (data == null) {
              return MemoryCorrupt(
                  'document for "${envelope.id}" exists with null data');
            }
            final MemoryEnvelope stored;
            try {
              stored = decodeDocument(envelope.id, data);
            } on MemoryCorrupt catch (error) {
              return error;
            }

            if (MemoryStoreCas.isIdempotentRetry(
                stored, envelope, expectedRevision)) {
              // The idempotent retry, both shapes: the store already holds
              // this exact row at `expected` (plain retry) or at
              // `expected + 1` (lost commit response). `sameContent`
              // includes the generation, so a retry with a new generation
              // is a conflict. Do not set again — a second write of the
              // same revision would fail the update rule.
              return null;
            }
            if (stored.revision == expectedRevision &&
                stored.generation == envelope.generation &&
                envelope.revision == expectedRevision + 1) {
              // The read that decides the compare-and-swap is inside the
              // callback: Firestore has nothing to conflict on otherwise.
              // A generation mismatch must not fall through here — that is
              // the ABA hole.
              transaction.set(ref, document);
              return null;
            }
            return MemoryConflict(
              expected: expectedRevision,
              actual: stored.revision,
              stored: stored,
            );
          },
          timeout: _transactionTimeout,
          maxAttempts: _transactionMaxAttempts,
        );
        if (outcome != null) {
          // ignore: only_throw_errors
          throw outcome;
        }
      } on FirebaseException catch (e) {
        // permission-denied, unavailable, offline, deadline-exceeded, or
        // attempts exhausted. None of them is a conflict; none is retried
        // here.
        throw MemoryIoException(
          'firestore transaction failed (${e.code}): ${e.message}',
          cause: e,
        );
      }
    }));
  }

  Map<String, dynamic> _encodeGuarded(MemoryEnvelope envelope) {
    try {
      return encodeDocument(envelope);
    } on JsonUnsupportedObjectError catch (e) {
      throw MemoryNotSerializable(
        'payload of ${envelope.payload.runtimeType} is not JSON-encodable: '
        '$e',
      );
    }
  }

  @override
  Future<void> remove(String id) async {
    return _lifecycle.run(() => _perId(id, () async {
      final ref = _doc(id);
      try {
        // The plan specifies remove as a transaction (get, then delete if
        // it exists). `ref.delete()` alone would also be idempotent, but
        // v1 keeps the transaction so the rules' read+delete shape is
        // exercised. Deletion resets the revision history — see the class
        // docs for the ABA note.
        await _firestore.runTransaction<void>((transaction) async {
          final snapshot = await transaction.get(ref);
          if (snapshot.exists) {
            transaction.delete(ref);
          }
        });
      } on FirebaseException catch (e) {
        throw MemoryIoException(
          'firestore transaction failed (${e.code}): ${e.message}',
          cause: e,
        );
      }
    }));
  }

  @override
  Future<List<String>> list() async {
    final prior = _lifecycle.inflight;
    return _lifecycle.run(() async {
      // A settled snapshot: operations that entered before list() finish
      // first, so records are included or excluded as whole writes.
      await Future.wait(prior);
      return _listBody();
    });
  }

  /// Fail-closed list body: one id that fails the memory id grammar fails
  /// the whole call, returns nothing, and deletes nothing. Rules stop a
  /// normal client from creating such an id; they do not stop the Admin
  /// SDK or a document written before the rules were deployed, which is
  /// why list throws instead of filtering.
  Future<List<String>> _listBody() async {
    try {
      // v1 accepts the cost: a collection get downloads every document,
      // payloads included, and bills a read each. Expected cardinality
      // is small (one document per memory id per user); for large
      // catalogs, prefer a separate index collection. Rules are not
      // filters, so the query stays under `users/{uid}/cell_memory` and
      // never becomes a collection group.
      final snapshot =
          await _collection.get(GetOptions(source: _readSource));
      final bad = <String>[
        for (final doc in snapshot.docs)
          if (!MemoryIdGrammar.isValid(doc.id)) doc.id
      ]..sort();
      if (bad.isNotEmpty) {
        throw MemoryCorrupt('bad ids: ${bad.join(', ')}');
      }
      return [for (final doc in snapshot.docs) doc.id];
    } on FirebaseException catch (e) {
      throw MemoryIoException(
        'firestore list failed (${e.code}): ${e.message}',
        cause: e,
      );
    }
  }

  @override
  Future<void> close() async => _lifecycle.close();

  @override
  String toString() => 'FirebaseMemoryStore(accepting: ${_lifecycle.accepting})';
}

/// A [MemoryWritePolicy] tuned for Cloud Firestore's per-document write
/// budget (roughly one sustained write per second): debounced at one
/// second, so a fast pulse stream coalesces into one transaction per quiet
/// period instead of contending on the same document.
const MemoryWritePolicy firestoreWritePolicy = MemoryWritePolicy(
  mode: MemoryWriteMode.debounced,
  debounce: Duration(seconds: 1),
);

/// Encodes an envelope into the Firestore document shape.
///
/// `payload` is **always** a JSON string on the wire — including `null`,
/// `[]`, and `{}` — so one rule covers every payload shape and a string
/// payload whose characters are `[1, 2]` cannot be confused with a list.
/// `updatedAt` is [FieldValue.serverTimestamp] on write: the envelope's
/// client-side `updatedAt` is discarded in favour of the server timestamp
/// (the file store keeps the client value; this backend does not). Null
/// `codec` and `sourceCellId` are omitted.
Map<String, dynamic> encodeDocument(MemoryEnvelope envelope) => {
      'schema': envelope.schema,
      'id': envelope.id,
      'kind': envelope.kind,
      'revision': envelope.revision,
      'generation': envelope.generation,
      'updatedAt': FieldValue.serverTimestamp(),
      'payload': jsonEncode(JsonPayloadKey.canonical(envelope.payload)),
      if (envelope.codec != null) 'codec': envelope.codec,
      if (envelope.sourceCellId != null) 'sourceCellId': envelope.sourceCellId,
    };

/// Decodes a Firestore document back into a [MemoryEnvelope].
///
/// Strict, like the file envelope: unknown keys, a `schema` other than 1,
/// an `id` that does not match the path segment, a missing or non-string
/// `payload`, a non-integer or non-positive `revision`, or an invalid
/// `updatedAt` throw [MemoryCorrupt] and does not delete the document. A
/// server [Timestamp] is converted to UTC; a [DateTime] is accepted so
/// test doubles may store one directly. `revision` accepts only `int`
/// (integral doubles are rejected) to match the file envelope exactly.
MemoryEnvelope decodeDocument(String id, Map<String, dynamic> data) {
  const allowedKeys = {
    'schema',
    'id',
    'kind',
    'revision',
    'generation',
    'updatedAt',
    'payload',
    'codec',
    'sourceCellId',
  };
  final unknown = data.keys.where((key) => !allowedKeys.contains(key)).toList()
    ..sort();
  if (unknown.isNotEmpty) {
    throw MemoryCorrupt(
        'document for "$id" has unknown keys: ${unknown.join(', ')}');
  }
  final schema = data['schema'];
  if (schema is! int || schema != MemoryEnvelope.schemaVersion) {
    throw MemoryCorrupt('document for "$id" has unsupported schema: $schema');
  }
  final docId = data['id'];
  if (docId != id) {
    throw MemoryCorrupt('document id "$docId" does not match path "$id"');
  }
  final kind = data['kind'];
  if (kind is! String || !MemoryEnvelope.kinds.contains(kind)) {
    throw MemoryCorrupt('document for "$id" has unknown kind: $kind');
  }
  final revision = data['revision'];
  if (revision is! int || revision < 1) {
    throw MemoryCorrupt('document for "$id" has invalid revision: $revision');
  }
  final generation = data['generation'];
  if (generation is! String ||
      !MemoryEnvelope.generationPattern.hasMatch(generation)) {
    throw MemoryCorrupt(
        'document for "$id" generation must be 32 lowercase hex characters');
  }
  final payload = data['payload'];
  if (payload is! String) {
    throw MemoryCorrupt('document for "$id" payload must be a JSON string');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(payload);
  } on FormatException catch (e) {
    throw MemoryCorrupt('document for "$id" payload is not JSON: $e');
  }
  final updatedAtRaw = data['updatedAt'];
  final DateTime updatedAt;
  if (updatedAtRaw is Timestamp) {
    updatedAt = updatedAtRaw.toDate().toUtc();
  } else if (updatedAtRaw is DateTime) {
    updatedAt = updatedAtRaw.toUtc();
  } else {
    throw MemoryCorrupt(
        'document for "$id" updatedAt must be a server timestamp, got '
        '${updatedAtRaw.runtimeType}');
  }
  final codec = data['codec'];
  if (codec != null && codec is! String) {
    throw MemoryCorrupt('document for "$id" codec must be a string');
  }
  final sourceCellId = data['sourceCellId'];
  if (sourceCellId != null && sourceCellId is! String) {
    throw MemoryCorrupt('document for "$id" sourceCellId must be a string');
  }

  return MemoryEnvelope(
    id: id,
    kind: kind,
    revision: revision,
    generation: generation,
    updatedAt: updatedAt,
    schema: schema,
    payload: decoded,
    codec: codec as String?,
    sourceCellId: sourceCellId as String?,
  );
}
