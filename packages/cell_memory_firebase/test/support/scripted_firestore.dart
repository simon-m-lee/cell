// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// A scripted test double for the Firestore surface `FirebaseMemoryStore`
// uses: `collection().doc().collection().doc()`, `get`, `runTransaction`,
// and `set` / `delete` inside the callback.
//
// The double RUNS the transaction handler — a double that skipped it would
// not count. It supports the lost-response shape: `runHandlerTwice` runs
// the callback twice, committing the first attempt's queued writes before
// the second run, exactly like a Firestore retry after a lost commit
// response. It also supports permission-denied and a deterministic
// document store. No network, no Java, no Firebase CLI.
//
// cloud_firestore 5.x seals its snapshot / reference / query classes, so
// the double implements them with `subtype_of_sealed_class` suppressed —
// a test double is exactly the shape a sealed hierarchy wants to keep out,
// and the alternative (a fake that skips the transaction handler) does not
// count as coverage.

import 'package:cloud_firestore/cloud_firestore.dart';

/// The document store, keyed by full document path.
typedef FirestoreDoc = Map<String, dynamic>;

/// A scripted [FirebaseFirestore] implementation. Unscripted members throw
/// through [noSuchMethod], so a store that reaches for an API this double
/// does not model fails the test loudly.
class ScriptedFirestore implements FirebaseFirestore {
  /// Documents keyed by path. A missing key means the document does not
  /// exist.
  final Map<String, FirestoreDoc> docs = {};

  /// The options of the most recent `get`, so tests can pin the read
  /// source without an emulator.
  GetOptions? lastGetOptions;

  /// How many times `Transaction.set` was called, across all attempts.
  int setCalls = 0;

  /// How many times `Transaction.delete` was called, across all attempts.
  int deleteCalls = 0;

  /// How many times the transaction handler was invoked.
  int handlerRuns = 0;

  /// When true, reads throw permission-denied.
  bool permissionDenied = false;

  /// When true, `runTransaction` runs the handler a second time after
  /// committing the first attempt — the lost-response retry shape.
  bool runHandlerTwice = false;

  /// Paths whose document exists but whose data() is null: the snapshot
  /// has an explicit existence bit, so "exists with null data" can be
  /// modelled.
  final Set<String> nullDataPaths = {};

  /// When true, an exception thrown by the transaction handler becomes a
  /// FirebaseException (code 'unknown') before commit, the way platform
  /// channels may wrap callback failures. A returned value is unchanged.
  bool wrapHandlerErrors = false;

  /// Seeds a document at `users/{uid}/cell_memory/{id}`.
  void seed(String uid, String id, FirestoreDoc data) {
    docs['users/$uid/cell_memory/$id'] = data;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(
          'ScriptedFirestore.${invocation.memberName} is not scripted');

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      ScriptedCollection(this, collectionPath);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    T? result;
    for (var attempt = 1;; attempt++) {
      handlerRuns++;
      final transaction = ScriptedTransaction(this);
      try {
        result = await transactionHandler(transaction);
      } catch (error) {
        if (wrapHandlerErrors) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unknown',
            message: '$error',
          );
        }
        rethrow;
      }
      transaction.commit();
      if (!(runHandlerTwice && attempt == 1)) break;
      if (attempt >= maxAttempts) break;
    }
    return result as T;
  }
}

// ignore: subtype_of_sealed_class
/// A collection navigator.
class ScriptedCollection implements CollectionReference<Map<String, dynamic>> {
  ScriptedCollection(this._db, this.path);

  final ScriptedFirestore _db;

  @override
  final String path;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(
          'ScriptedCollection.${invocation.memberName} is not scripted');

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      ScriptedDocumentReference(
          _db, path == null ? this.path : '${this.path}/$path');

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    _db.lastGetOptions = options;
    if (_db.permissionDenied) throwPermissionDenied();
    final matches = _db.docs.entries
        .where((e) => e.key.startsWith('$path/'))
        .map((e) => ScriptedQueryDocument(e.key.split('/').last, e.value))
        .toList();
    return ScriptedQuerySnapshot(matches);
  }
}

// ignore: subtype_of_sealed_class
/// A document reference.
class ScriptedDocumentReference
    implements DocumentReference<Map<String, dynamic>> {
  ScriptedDocumentReference(this._db, this.path);

  final ScriptedFirestore _db;

  @override
  final String path;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(
          'ScriptedDocumentReference.${invocation.memberName} is not scripted');

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      ScriptedCollection(_db, '$path/$collectionPath');

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    _db.lastGetOptions = options;
    if (_db.permissionDenied) throwPermissionDenied();
    return ScriptedDocumentSnapshot(_db.docs[path], _db.nullDataPaths.contains(path));
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _db.docs[path] = materialise(data);
  }

  @override
  Future<void> delete() async {
    _db.docs.remove(path);
  }
}

// ignore: subtype_of_sealed_class
/// A document snapshot.
class ScriptedDocumentSnapshot
    implements DocumentSnapshot<Map<String, dynamic>> {
  ScriptedDocumentSnapshot(this._data, [this._exists = false]);

  final FirestoreDoc? _data;

  /// Explicit existence: a path in nullDataPaths exists with null data;
  /// a missing key is still absent.
  final bool _exists;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(
          'ScriptedDocumentSnapshot.${invocation.memberName} is not scripted');

  @override
  bool get exists => _exists || _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}

// ignore: subtype_of_sealed_class
/// A query snapshot over a collection.
class ScriptedQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  ScriptedQuerySnapshot(this.docs);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(
          'ScriptedQuerySnapshot.${invocation.memberName} is not scripted');

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

// ignore: subtype_of_sealed_class
/// A query document.
class ScriptedQueryDocument
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  ScriptedQueryDocument(this.id, this._data);

  @override
  final String id;

  final FirestoreDoc _data;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(
          'ScriptedQueryDocument.${invocation.memberName} is not scripted');

  @override
  Map<String, dynamic> data() => _data;
}

/// A transaction. Writes are queued and applied at commit — the shape
/// `runTransaction` needs to model a lost commit response.
class ScriptedTransaction implements Transaction {
  ScriptedTransaction(this._db);

  final ScriptedFirestore _db;

  final List<void Function()> _ops = [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(
          'ScriptedTransaction.${invocation.memberName} is not scripted');

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference, [
    GetOptions? options,
  ]) async {
    if (_db.permissionDenied) throwPermissionDenied();
    final path = (documentReference as ScriptedDocumentReference).path;
    return ScriptedDocumentSnapshot(
            _db.docs[path], _db.nullDataPaths.contains(path))
        as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    _db.setCalls++;
    final path = (documentReference as ScriptedDocumentReference).path;
    _ops.add(() => _db.docs[path] = materialise(data as FirestoreDoc));
    return this;
  }

  @override
  Transaction delete(DocumentReference documentReference) {
    _db.deleteCalls++;
    final path = (documentReference as ScriptedDocumentReference).path;
    _ops.add(() => _db.docs.remove(path));
    return this;
  }

  void commit() {
    for (final op in _ops) {
      op();
    }
    _ops.clear();
  }
}

void throwPermissionDenied() {
  throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'permission-denied',
    message: 'PERMISSION_DENIED: Missing or insufficient permissions.',
  );
}

FirestoreDoc materialise(FirestoreDoc data) => {
      for (final entry in data.entries)
        entry.key: entry.value is FieldValue
            ? Timestamp.fromDate(DateTime.now())
            : entry.value,
    };
