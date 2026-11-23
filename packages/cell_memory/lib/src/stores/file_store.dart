// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert';
import 'dart:io';

import '../envelope.dart';
import '../id.dart';
import '../store.dart';
import '../store_lifecycle.dart';

/// A [MemoryStore] over JSON files. Pure `dart:io`; no Flutter.
///
/// Directory mode (the default for an app):
///
/// ```text
/// <root>/
///   <id>.json          # current envelope
///   <id>.json.tmp      # write in progress
/// ```
///
/// Write protocol: encode pretty JSON, write `<id>.json.tmp`, `flush`
/// through a [RandomAccessFile] (so the bytes reach the OS before the
/// rename), rename over `<id>.json`. `File.rename` replaces an existing
/// target on Windows as well as POSIX, so no delete-then-rename fallback
/// exists: a failed rename leaves the last good record untouched. A failed
/// write leaves the `.tmp` for the next open to clean up.
///
/// On read: `.json` + `.tmp` → delete `.tmp`, read `.json`.
/// `.tmp` only → [MemoryCorrupt]; a partial file is never promoted to a
/// record. On write, a stale lone `.tmp` is discarded — no record was ever
/// committed, and the write would overwrite the tmp anyway.
///
/// The per-id lock is in-process: two isolates or two processes sharing a
/// directory can both pass the read-compare-rename, and the last rename
/// wins. v1 therefore guarantees revision-linearised writes for one writer
/// process per id; cross-process writes to one id need a later file lock
/// (or the Firestore backend, where the transaction is the lock).
final class FileMemoryStore implements MemoryStore {
  /// Opens a directory store: `<root>/<id>.json` per memory id.
  FileMemoryStore.directory(Directory root) : _root = root, _singleFile = null;

  /// Opens a single-file store: one envelope in [file].
  ///
  /// The file holds exactly one record. `write` requires the envelope's id
  /// to match the stored record's id (or the file to be absent); `read(id)`
  /// returns the record only when its id equals [id], and `null` otherwise.
  /// `unload` does not delete the file.
  FileMemoryStore.file(File file) : _root = null, _singleFile = file;

  final Directory? _root;

  final File? _singleFile;

  final Map<String, Future<void>> _chains = {};

  final StoreLifecycle _lifecycle = StoreLifecycle('FileMemoryStore is closed');

  /// Validates a memory id for directory mode: the shared
  /// [MemoryIdGrammar] plus the Windows reserved device names, rejected
  /// with an [ArgumentError] before any IO.
  static void checkId(String id) {
    MemoryIdGrammar.check(id, rejectWindowsReservedNames: true);
  }

  File _fileFor(String id) {
    final root = _root;
    if (root == null) {
      throw StateError(
          'single-file mode does not address records by path id');
    }
    checkId(id);
    return File('${root.path}${Platform.pathSeparator}$id.json');
  }

  File _tmpFor(String id) {
    final root = _root;
    if (root == null) {
      throw StateError(
          'single-file mode does not address records by path id');
    }
    checkId(id);
    return File('${root.path}${Platform.pathSeparator}$id.json.tmp');
  }

  /// The chain key. Lowercased so ids that collide on a case-insensitive
  /// filesystem share one lock; over-serialising on case-sensitive
  /// filesystems is harmless.
  String _chainKey(String id) => id.toLowerCase();

  Future<T> _perId<T>(String id, Future<T> Function() run) {
    final key = _chainKey(id);
    final previous = _chains[key] ?? Future<void>.value();
    final completer = previous.then((_) => run());
    // The chain itself must never reject or later work on the id would be
    // skipped; the returned future carries the error to the caller.
    final chain = completer.then<void>((_) {}, onError: (_) {});
    _chains[key] = chain;
    // Drop the entry once this link is the tail, so long-lived stores do
    // not grow a map entry per id touched.
    chain.whenComplete(() {
      if (identical(_chains[key], chain)) _chains.remove(key);
    });
    return completer;
  }

  /// Fails closed on two directory files that differ only by case:
  /// on case-insensitive filesystems they are one file with two names,
  /// and the per-id chains (lowercased) would otherwise serialise two
  /// histories onto one record. Neither file is deleted.
  Future<void> _checkCaseCollision(String id) async {
    final root = _root;
    if (root == null || !await root.exists()) return;
    final target = '$id.json';
    try {
      await for (final entry in root.list()) {
        if (entry is! File) continue;
        final name = entry.uri.pathSegments.last;
        if (name == target) continue;
        if (name.endsWith('.json.tmp')) continue;
        if (!name.toLowerCase().endsWith('.json')) continue;
        if (name.toLowerCase() == target.toLowerCase()) {
          throw MemoryCorrupt('id "$id" collides with existing file "$name"');
        }
      }
    } on FileSystemException catch (e) {
      throw MemoryIoException('cannot scan ${root.path}',
          path: root.path, cause: e);
    }
  }

  Future<MemoryEnvelope?> _readFile(File file) async {
    if (!await file.exists()) return null;
    final text = await _readText(file.path);
    return _decode(text, file.path);
  }

  Future<MemoryEnvelope?> _readById(String id) async {
    await _checkCaseCollision(id);
    final file = _fileFor(id);
    final tmp = _tmpFor(id);
    final hasJson = await file.exists();
    final hasTmp = await tmp.exists();
    if (hasJson && hasTmp) {
      // The previous write failed between tmp and rename; the json is the
      // last good record. Delete the tmp and read on.
      await _deleteQuietly(tmp);
    } else if (!hasJson && hasTmp) {
      throw MemoryCorrupt(
          'partial write for "$id": only ${tmp.path} exists');
    } else if (!hasJson) {
      return null;
    }
    final envelope = await _readFile(file);
    if (envelope != null && envelope.id != id) {
      // Fail closed: the file is left in place, including a sibling tmp.
      throw MemoryCorrupt(
          'envelope id "${envelope.id}" does not match file "$id"');
    }
    return envelope;
  }

  Future<String> _readText(String path) async {
    try {
      return await File(path).readAsString();
    } on FileSystemException catch (e) {
      throw MemoryIoException('cannot read $path', path: path, cause: e);
    }
  }

  MemoryEnvelope _decode(String text, String path) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw MemoryCorrupt('invalid JSON in $path: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw MemoryCorrupt('envelope in $path is not a JSON object');
    }
    try {
      return MemoryEnvelope.fromJson(decoded);
    } on MemoryCorrupt {
      rethrow;
    } catch (e) {
      throw MemoryCorrupt('cannot decode envelope in $path: $e');
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Leftover tmp files are cleaned on the next open; a failed cleanup
      // must not mask the read result.
    }
  }

  static const JsonEncoder _pretty = JsonEncoder.withIndent('  ');

  /// The shared read-compare-rename commit for both modes.
  ///
  /// [file] is the record and [tmp] its write-in-progress sibling. On
  /// write, a stale lone tmp is discarded before the compare; on read it
  /// remains a [MemoryCorrupt] (see [_readById]).
  Future<void> _commit(
    File file,
    File tmp,
    MemoryEnvelope envelope,
    int expectedRevision, {
    required bool singleFile,
  }) async {
    await file.parent.create(recursive: true);
    if (!singleFile) {
      await _checkCaseCollision(envelope.id);
    }

    MemoryEnvelope? existing;
    final hasJson = await file.exists();
    final hasTmp = await tmp.exists();
    if (hasJson && hasTmp) await _deleteQuietly(tmp);
    if (hasJson) {
      existing = await _readFile(file);
    } else if (hasTmp) {
      // No record was ever committed for this id; the tmp is debris from
      // a crashed first write. The write would overwrite it anyway, so
      // discard it instead of bricking the id forever.
      await _deleteQuietly(tmp);
    }
    if (singleFile && existing != null && existing.id != envelope.id) {
      throw MemoryCorrupt(
          'single-file store already holds "${existing.id}"; cannot '
          'write "${envelope.id}" into the same file');
    }
    final storedRevision = existing?.revision ?? 0;
    if (MemoryStoreCas.isIdempotentRetry(existing, envelope, expectedRevision)) {
      return;
    }
    MemoryStoreCas.checkRevision(storedRevision, expectedRevision,
        stored: existing);
    MemoryStoreCas.checkGeneration(existing, envelope, expectedRevision);
    MemoryStoreCas.checkNumbering(envelope, expectedRevision);
    await _writeJsonFile(tmp, envelope);
    try {
      await tmp.rename(file.path);
    } on FileSystemException catch (e) {
      // No delete-then-rename fallback: File.rename replaces an existing
      // target on Windows as well as POSIX, and deleting the target first
      // could destroy the last good record on a second failure.
      throw MemoryIoException('cannot rename ${tmp.path} over ${file.path}',
          path: file.path, cause: e);
    }
    // POSIX rename consumes the tmp; delete any leftover.
    await _deleteQuietly(tmp);
  }

  Future<void> _writeJsonFile(File file, MemoryEnvelope envelope) async {
    final json = _pretty.convert(envelope.toJson());
    try {
      // `flush` forces the bytes to the OS, so the rename that follows
      // never promotes an unflushed buffer.
      final raf = await file.open(mode: FileMode.write);
      try {
        await raf.writeFrom(utf8.encode(json));
        await raf.flush();
      } finally {
        await raf.close();
      }
    } on FileSystemException catch (e) {
      throw MemoryIoException('cannot write ${file.path}',
          path: file.path, cause: e);
    }
  }

  @override
  Future<MemoryEnvelope?> read(String id) async {
    return _lifecycle.run(() => _perId(id, () {
          final single = _singleFile;
          if (single != null) {
            return _readSingle(id);
          }
          return _readById(id);
        }));
  }

  Future<MemoryEnvelope?> _readSingle(String id) async {
    final envelope = await _readFile(_singleFile!);
    if (envelope == null || envelope.id == id) return envelope;
    // The file holds a different record: it is not the id the caller asked
    // for.
    return null;
  }

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    return _lifecycle.run(() => _perId(envelope.id, () {
          final single = _singleFile;
          if (single != null) {
            return _commit(
              single,
              File('${single.path}.tmp'),
              envelope,
              expectedRevision,
              singleFile: true,
            );
          }
          return _commit(
            _fileFor(envelope.id),
            _tmpFor(envelope.id),
            envelope,
            expectedRevision,
            singleFile: false,
          );
        }));
  }

  @override
  Future<void> remove(String id) async {
    return _lifecycle.run(() => _perId(id, () async {
          final single = _singleFile;
        if (single != null) {
          final envelope = await _readSingle(id);
          if (envelope == null) return;
          try {
            if (await single.exists()) await single.delete();
          } on FileSystemException catch (e) {
            throw MemoryIoException('cannot delete ${single.path}',
                path: single.path, cause: e);
          }
          await _deleteQuietly(File('${single.path}.tmp'));
          return;
        }
        final file = _fileFor(id);
        final tmp = _tmpFor(id);
        try {
          if (await file.exists()) await file.delete();
          if (await tmp.exists()) await tmp.delete();
        } on FileSystemException catch (e) {
          throw MemoryIoException('cannot delete ${file.path}',
              path: file.path, cause: e);
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

  /// Fail-closed list body: one bad id or a case collision fails the whole
  /// call and deletes nothing. `*.json.tmp` is not an id and is ignored;
  /// a file named `.json` is an empty id and fails the call.
  Future<List<String>> _listBody() async {
    final single = _singleFile;
    if (single != null) {
      final envelope = await _readFile(single);
      if (envelope == null) return const [];
      if (!MemoryIdGrammar.isValid(envelope.id)) {
        throw MemoryCorrupt(
            'stored envelope id "${envelope.id}" fails the memory id grammar');
      }
      return [envelope.id];
    }
    final root = _root!;
    if (!await root.exists()) return const [];
    final ids = <String>[];
    final bad = <String>[];
    try {
      await for (final entry in root.list()) {
        if (entry is! File) continue;
        final name = entry.uri.pathSegments.last;
        if (name.endsWith('.json.tmp')) continue;
        if (!name.endsWith('.json')) continue;
        final id = name.substring(0, name.length - '.json'.length);
        if (MemoryIdGrammar.isValid(id)) {
          ids.add(id);
        } else {
          bad.add(name);
        }
      }
    } on FileSystemException catch (e) {
      throw MemoryIoException('cannot list ${root.path}',
          path: root.path, cause: e);
    }
    // One scan collects both: case-distinct names that collapse on a
    // case-insensitive filesystem are reported like a bad id.
    final seen = <String, String>{};
    for (final id in List<String>.of(ids)) {
      final key = id.toLowerCase();
      final prior = seen[key];
      if (prior != null) {
        bad.add('$id.json (collides with $prior.json)');
        ids.remove(id);
      } else {
        seen[key] = id;
      }
    }
    if (bad.isNotEmpty) {
      bad.sort();
      throw MemoryCorrupt('bad ids in ${root.path}: ${bad.join(', ')}');
    }
    return ids;
  }

  @override
  Future<void> close() async => _lifecycle.close();
}
