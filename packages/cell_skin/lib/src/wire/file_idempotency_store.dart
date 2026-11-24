// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The durable [IdempotencyStore]: one process survives a restart.
///
/// One log file, one record per line, canonical JSON, in a directory
/// the application passes — the skin never picks one. Every mutation
/// holds two locks: an in-process `Future` chain, so two `claim`s in
/// one isolate cannot both see an empty key, and `RandomAccessFile.lock`
/// on `directory/lock`, so another process cannot. The rewrite is
/// `log.tmp` then rename over `log`, still inside the lock: a crash
/// leaves either the old log or a temp file readers ignore.
///
/// A crash after the domain commit and before `complete` can still
/// double-apply; `complete` is what makes the retry safe.
/// {@category Idempotency}
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';

import 'idempotency_store.dart';

/// One parsed log line. Unknown keys are ignored on read; a line that
/// does not parse is skipped and dropped on the next rewrite.
final class _Line {
  final String key;
  final String fingerprint;
  final String state;
  final DateTime? leaseUntil;
  final String? responseType;
  final Map<String, Object?>? outcomeJson;
  final DateTime? storedAt;
  final String? errorCode;
  final String? errorMessage;

  const _Line({
    required this.key,
    required this.fingerprint,
    required this.state,
    this.leaseUntil,
    this.responseType,
    this.outcomeJson,
    this.storedAt,
    this.errorCode,
    this.errorMessage,
  });

  static _Line? tryParse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final json = decoded.cast<String, Object?>();
    final key = json['key'];
    final state = json['state'];
    if (key is! String || state is! String) return null;
    DateTime? parseTime(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;
    final outcomeRaw = json['outcomeJson'];
    return _Line(
      key: key,
      fingerprint: json['fingerprint'] as String? ?? '',
      state: state,
      leaseUntil: parseTime(json['leaseUntil']),
      responseType: json['responseType'] as String?,
      outcomeJson: outcomeRaw is Map ? outcomeRaw.cast<String, Object?>() : null,
      storedAt: parseTime(json['storedAt']),
      errorCode: json['errorCode'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
        'key': key,
        if (state == 'complete') 'fingerprint': fingerprint,
        'state': state,
        if (state == 'in_flight' && leaseUntil != null)
          'leaseUntil': leaseUntil!.toUtc().toIso8601String(),
        if (state == 'complete') ...{
          'responseType': responseType,
          'outcomeJson': outcomeJson ?? const {},
          'storedAt': storedAt!.toUtc().toIso8601String(),
          if (errorCode != null) 'errorCode': errorCode,
          if (errorMessage != null) 'errorMessage': errorMessage,
        },
      };
}

/// The durable sibling of [MemoryIdempotencyStore].
///
/// Implements the same [IdempotencyStore] interface; the file-only
/// details (the log, the lock file, the lease) live here. A second
/// [FileIdempotencyStore] opened on the same directory sees a completed
/// record and `claim` returns [IdempotencyReplay]; across processes the
/// next `claim` after `leaseUntil` returns [IdempotencyOwned].
///
/// TTL and the cap match the memory store: expired completed lines and
/// completed lines past [maxEntries] are dropped when the log is
/// rewritten under the lock — never by a timer — and an in-flight line
/// is never the eviction victim. A crash after the domain commit and
/// before `complete` can still double-apply; `complete` is what makes
/// the retry safe.
///
/// ### AI Agent Guide
/// **Layer:** Skin — the restart implementation of [IdempotencyStore].
/// **When to use:** retries that must survive a restart; `/ready` checks
/// this store's directory.
/// **When NOT to use:** in a browser — `dart:io`; import it from
/// `package:cell_skin/cell_skin_io.dart`, never the main barrel.
/// **Live signature:** `static Future<FileIdempotencyStore> open({required String directory, int maxEntries = 1024, Duration ttl = Duration(hours: 24), Duration lease = Duration(minutes: 2), DateTime Function() clock = DateTime.now})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
final class FileIdempotencyStore implements IdempotencyStore {
  final String directory;
  final int maxEntries;
  final Duration ttl;
  final Duration lease;
  final DateTime Function() clock;

  final File _logFile;
  final File _lockFile;
  Future<void> _chain = Future<void>.value();
  bool _isOpen = false;
  final Map<String, Completer<IdempotencyRecord?>> _inflight = {};

  FileIdempotencyStore._({
    required this.directory,
    required this.maxEntries,
    required this.ttl,
    required this.lease,
    required this.clock,
    required File logFile,
    required File lockFile,
  })  : _logFile = logFile,
        _lockFile = lockFile;

  /// Opens (or creates) the store at [directory].
  ///
  /// Creates the directory and `directory/lock`, and sets `isOpen` only
  /// after both succeed; a failure throws. `maxEntries < 1`, a negative
  /// [ttl], or a negative [lease] throws [ArgumentError].
  static Future<FileIdempotencyStore> open({
    required String directory,
    int maxEntries = 1024,
    Duration ttl = const Duration(hours: 24),
    Duration lease = const Duration(minutes: 2),
    DateTime Function() clock = DateTime.now,
  }) async {
    if (maxEntries < 1) {
      throw ArgumentError.value(
          maxEntries, 'maxEntries', 'must be at least 1');
    }
    if (ttl.isNegative) {
      throw ArgumentError.value(ttl, 'ttl', 'must be zero or positive');
    }
    if (lease.isNegative) {
      throw ArgumentError.value(lease, 'lease', 'must be zero or positive');
    }
    await Directory(directory).create(recursive: true);
    final lockFile = File('$directory${Platform.pathSeparator}lock');
    if (!await lockFile.exists()) {
      await lockFile.create();
    }
    return FileIdempotencyStore._(
      directory: directory,
      maxEntries: maxEntries,
      ttl: ttl,
      lease: lease,
      clock: clock,
      logFile: File('$directory${Platform.pathSeparator}log'),
      lockFile: lockFile,
    ).._isOpen = true;
  }

  /// Whether the directory and the lock file still exist. Catches I/O
  /// errors and returns `false` — it never throws into the HTTP
  /// handler.
  Future<bool> checkReady() async {
    try {
      if (!_isOpen) return false;
      if (!await Directory(directory).exists()) return false;
      if (!await File('$directory${Platform.pathSeparator}lock').exists()) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<IdempotencyClaim> claim(String key) => _serialized(() async {
        while (true) {
          _ClaimOutcome? outcome;
          await _mutate<_ClaimOutcome>((lines, now) async {
            final line = lines[key];
            if (line == null) {
              final leaseLine = _newLeaseLine(key, now);
              lines[key] = leaseLine;
              outcome = _ClaimOutcome.owned();
              return outcome;
            }
            if (line.state == 'complete') {
              if (_expired(line, now)) {
                final leaseLine = _newLeaseLine(key, now);
                lines[key] = leaseLine;
                outcome = _ClaimOutcome.owned();
              } else {
                outcome = _ClaimOutcome.replay(_recordOf(line));
              }
              return outcome;
            }
            // in_flight.
            final leaseUntil = line.leaseUntil;
            final local = _inflight[key];
            if (leaseUntil != null && now.isBefore(leaseUntil)) {
              if (local != null) {
                outcome = _ClaimOutcome.wait(local.future);
              } else {
                outcome =
                    _ClaimOutcome.foreign(leaseUntil.difference(now));
              }
              return outcome;
            }
            // Lease expired: take the key. Release the old local
            // waiters, if any, like an abort would.
            if (local != null && !local.isCompleted) local.complete(null);
            final leaseLine = _newLeaseLine(key, now);
            lines[key] = leaseLine;
            outcome = _ClaimOutcome.owned();
            return outcome;
          });
          switch (outcome!) {
            case _ClaimOwned():
              return const IdempotencyOwned();
            case _ClaimReplay(:final record):
              return IdempotencyReplay(record);
            case _ClaimWait(:final settled):
              return IdempotencyWait(settled);
            case _ClaimForeign(:final waitFor):
              // A live lease owned by another process: both locks are
              // already dropped, so re-read after 200 ms or the lease
              // end, whichever is sooner. This stalls the serial router
              // exactly like an in-process IdempotencyWait does.
              await Future<void>.delayed(
                waitFor > const Duration(milliseconds: 200)
                    ? const Duration(milliseconds: 200)
                    : waitFor,
              );
              continue;
          }
        }
      });

  @override
  Future<void> complete(String key, IdempotencyRecord record) =>
      _serialized(() async {
        final now = clock();
        await _mutate<bool>((lines, _) async {
          lines[key] = _Line(
            key: key,
            fingerprint: record.fingerprint,
            state: 'complete',
            responseType: record.responseType,
            outcomeJson: record.outcomeJson,
            storedAt: now,
            errorCode: record.failureCode,
            errorMessage: record.failureMessage,
          );
          return true;
        });
        final pending = _inflight.remove(key);
        if (pending != null && !pending.isCompleted) {
          pending.complete(record);
        }
      });

  @override
  Future<void> abort(String key) => _serialized(() async {
        await _mutate<bool>((lines, _) async {
          lines.remove(key);
          return true;
        });
        final pending = _inflight.remove(key);
        if (pending != null && !pending.isCompleted) {
          pending.complete(null);
        }
      });

  _Line _newLeaseLine(String key, DateTime now) {
    _inflight[key] = Completer<IdempotencyRecord?>();
    return _Line(
      key: key,
      fingerprint: '',
      state: 'in_flight',
      leaseUntil: now.add(lease),
    );
  }

  bool _expired(_Line line, DateTime now) {
    final storedAt = line.storedAt;
    if (storedAt == null) return false;
    return !now.isBefore(storedAt.add(ttl));
  }

  IdempotencyRecord _recordOf(_Line line) => IdempotencyRecord(
        fingerprint: line.fingerprint,
        responseType: line.responseType ?? '',
        outcomeJson: line.outcomeJson ?? const {},
        storedAt: line.storedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        failureCode: line.errorCode,
        failureMessage: line.errorMessage,
      );

  /// Runs [mutate] under the file lock after reading the log, and
  /// rewrites the log only when it returns a non-null result. The lock
  /// handle is opened and closed per mutation, so no handle pins the
  /// directory between calls. The rewrite drops expired completed lines
  /// and completed lines past [maxEntries]; in-flight lines are never
  /// evicted.
  Future<T?> _mutate<T>(
    Future<T?> Function(Map<String, _Line> lines, DateTime now) mutate,
  ) async {
    final lockRaf = await _lockFile.open(mode: FileMode.append);
    try {
      await lockRaf.lock(FileLock.exclusive);
      try {
        final now = clock();
        final lines = await _readLines();
        final result = await mutate(lines, now);
        if (result == null) return null;
        await _rewrite(lines, now);
        return result;
      } finally {
        await lockRaf.unlock();
      }
    } finally {
      await lockRaf.close();
    }
  }

  Future<T> _serialized<T>(Future<T> Function() body) {
    final result = _chain.then((_) => body());
    _chain = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Map<String, _Line>> _readLines() async {
    final lines = <String, _Line>{};
    if (!await _logFile.exists()) return lines;
    final stream = _logFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final text in stream) {
      final line = _Line.tryParse(text);
      if (line != null) lines[line.key] = line;
    }
    return lines;
  }

  Future<void> _rewrite(Map<String, _Line> lines, DateTime now) async {
    final kept = <_Line>[
      for (final line in lines.values)
        if (line.state != 'complete' || !_expired(line, now)) line,
    ];
    // The cap counts completed lines only; drop the oldest past it.
    final completed = kept.where((l) => l.state == 'complete').toList()
      ..sort((a, b) => a.storedAt!.compareTo(b.storedAt!));
    final doomed = completed.length > maxEntries
        ? completed.take(completed.length - maxEntries).toSet()
        : <_Line>{};
    final survivors = [
      for (final line in kept)
        if (line.state != 'complete' || !doomed.contains(line)) line,
    ];
    final tmp = File('${_logFile.path}.tmp');
    final buffer = StringBuffer();
    for (final line in survivors) {
      buffer.writeln(canonicalJsonEncode(line.toJson()));
    }
    await tmp.writeAsString(buffer.toString(), flush: true);
    await tmp.rename(_logFile.path);
  }
}

sealed class _ClaimOutcome {
  const _ClaimOutcome();
  static _ClaimOutcome owned() => const _ClaimOwned();
  static _ClaimOutcome replay(IdempotencyRecord record) =>
      _ClaimReplay(record);
  static _ClaimOutcome wait(Future<IdempotencyRecord?> settled) =>
      _ClaimWait(settled);
  static _ClaimOutcome foreign(Duration waitFor) => _ClaimForeign(waitFor);
}

final class _ClaimOwned extends _ClaimOutcome {
  const _ClaimOwned();
}

final class _ClaimReplay extends _ClaimOutcome {
  final IdempotencyRecord record;
  const _ClaimReplay(this.record);
}

final class _ClaimWait extends _ClaimOutcome {
  final Future<IdempotencyRecord?> settled;
  const _ClaimWait(this.settled);
}

final class _ClaimForeign extends _ClaimOutcome {
  final Duration waitFor;
  const _ClaimForeign(this.waitFor);
}
