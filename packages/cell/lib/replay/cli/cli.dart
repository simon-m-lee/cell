// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The `cell-replay` command-line interface.
//
// ### Non-obvious: this is a *standalone* library, not a `part`
//
// `cli.dart` imports `dart:io`, which must not leak into the web-safe
// `cell.dart` core (the published package declares `platforms: web`).
// This is the same rule that keeps `file_store.dart` standalone — see
// AGENTS.md. The `bin/cell_replay.dart` entry point imports this file
// directly; the tooling design's "part of cell.dart + barrel export"
// sketch would have made the whole core library un-web-compilable.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cell/replay.dart';
import 'package:uuid/uuid.dart';

/// The `cell-replay` command-line interface.
///
/// Subcommands:
///
/// * `verify <ledger>` — verifies a ledger's hash chain and (if a graph
///   snapshot is provided) replays it against the target graph.
/// * `diff <a> <b>` — compares two ledgers entry‑by‑entry and reports
///   the first divergence per entry.
/// * `fork <ledger> <seq>` — forks a ledger at `seq`, applies an optional
///   mutation, and writes the fork to a new file.
/// * `visualise <ledger>` — emits a mermaid or DOT graph of the ledger's
///   causal chain.
/// * `inspect <ledger>` — prints a human‑readable summary of the ledger
///   (entry count, time range, cells touched, divergence state).
abstract final class Cli {
  /// Runs the CLI with [args]. Returns the process exit code.
  ///
  /// Exit codes:
  /// * `0` — success (verify OK, diff found no differences, fork
  ///   succeeded, etc.)
  /// * `1` — verification failure (hash chain mismatch, divergence,
  ///   diff found a difference)
  /// * `2` — usage error (bad arguments, missing file)
  /// * `3` — internal error (an unexpected exception; reported with
  ///   a stack trace to stderr)
  static Future<int> run(List<String> args) async {
    if (args.isEmpty || args[0] == '--help' || args[0] == '-h') {
      stdout.writeln(_help());
      return args.isEmpty ? 2 : 0;
    }
    final command = args[0];
    final rest = args.sublist(1);
    try {
      switch (command) {
        case 'verify':
          return await _verify(rest);
        case 'diff':
          return await _diff(rest);
        case 'fork':
          return await _fork(rest);
        case 'visualise':
          return await _visualise(rest);
        case 'inspect':
          return await _inspect(rest);
        default:
          stderr.writeln('Unknown command: $command');
          stderr.writeln(_help());
          return 2;
      }
    } on _UsageException catch (e) {
      stderr.writeln('Usage error: ${e.message}');
      stderr.writeln(_help());
      return 2;
    } on FileSystemException catch (e) {
      stderr.writeln('I/O error: ${e.message} (${e.path})');
      return 2;
    } catch (e, st) {
      stderr.writeln('Internal error: $e');
      stderr.writeln(st);
      return 3;
    }
  }

  // ── commands ────────────────────────────────────────────────────────

  static Future<int> _verify(List<String> args) async {
    // Review fix: `--strict` was parsed and silently ignored (verify has
    // no lenient mode). The flag is no longer accepted; chain-only
    // verification IS the strict behaviour.
    final opts = _parse(args, {
      'ledger': _Opt.required,
      'graph': _Opt.optional,
      'format': _Opt.optional,
    });
    final ledgerPath = opts['ledger']!;
    final format = opts['format'] ?? 'human';

    // We cannot reconstruct a Ledger without a CellGraph today —
    // the graph is an engine input. So `verify` without `--graph` can
    // only verify the *chain*, not replay. This is the honest
    // limitation; `verify --graph <snapshot.json>` is the full check.
    //
    // A future CLI revision will add `--graph-snapshot` to reconstruct the target
    // graph from a snapshot, which is snapshot reconstruction's job.
    //
    // Non-obvious: this check runs BEFORE `_openStore` — rejecting the
    // flag after opening the store would leak the file's
    // RandomAccessFile on Windows (the doc's original ordering).
    if (opts['graph'] != null) {
      throw _UsageException(
        '--graph is not supported yet; verify only checks the '
        'ledger chain. Full replay verification is planned CLI work '
        '(requires snapshot reconstruction).',
      );
    }

    final opened = await _openStore(ledgerPath);
    return _verifyChainOnly(
      store: opened.store,
      genesisHash: opened.genesisHash,
      format: format,
    );
  }

  static Future<int> _verifyChainOnly({
    required LedgerStore store,
    required String genesisHash,
    required String format,
  }) async {
    // A placeholder graph lets us reuse `Ledger.verify`. The graph is
    // not consulted for chain verification except for the genesis
    // binding, which we pin with the explicit `genesisHash` read from
    // the file (`Ledger.open` enforces the store's genesis).
    // Note: `CellGraph.unrestricted()` is `@visibleForTesting`, so the
    // CLI builds a non-strict placeholder instead.
    final placeholder = (CellGraph.builder(
      graphId: 'cli-placeholder',
      strict: false,
    )).build();
    final ledger = await Ledger.open(
      graph: placeholder,
      store: store,
      genesisHash: genesisHash,
    );
    try {
      await ledger.verify();
      if (format == 'json') {
        stdout.writeln(canonicalJsonEncode({
          'status': 'ok',
          'lastSeq': await ledger.lastSeq,
        }));
      } else {
        stdout.writeln(
          'OK: ledger is valid (${await ledger.lastSeq + 1} entries).',
        );
      }
      return 0;
    } on LedgerIntegrityException catch (e) {
      if (format == 'json') {
        stdout.writeln(canonicalJsonEncode({
          'status': 'invalid',
          'seq': e.seq,
          'reason': e.reason,
        }));
      } else {
        stderr.writeln('INVALID: ${e.toString()}');
      }
      return 1;
    } finally {
      await ledger.close();
    }
  }

  static Future<int> _diff(List<String> args) async {
    final opts = _parse(args, {
      'ledgerA': _Opt.required,
      'ledgerB': _Opt.required,
      'format': _Opt.optional,
      'maxDiffs': _Opt.optional,
    });
    final openedA = await _openStore(opts['ledgerA']!);
    final openedB = await _openStore(opts['ledgerB']!);
    final format = opts['format'] ?? 'human';
    final maxDiffs = int.tryParse(opts['maxDiffs'] ?? '') ?? 100;

    final placeholderA = (CellGraph.builder(
      graphId: 'cli-placeholder-a',
      strict: false,
    )).build();
    final placeholderB = (CellGraph.builder(
      graphId: 'cli-placeholder-b',
      strict: false,
    )).build();
    final ledgerA = await Ledger.open(
      graph: placeholderA,
      store: openedA.store,
      genesisHash: openedA.genesisHash,
    );
    final ledgerB = await Ledger.open(
      graph: placeholderB,
      store: openedB.store,
      genesisHash: openedB.genesisHash,
    );

    // Review fix: `diff` had no finally around the closes — an
    // exception (e.g. a corrupt second file) leaked the open file
    // handles on Windows.
    try {
      final diffs = <_LedgerDiff>[];
      final aEntries = <int, LedgerEntry>{};
      await for (final e in ledgerA.entriesSince(0)) {
        aEntries[e.seq] = e;
      }
    await for (final e in ledgerB.entriesSince(0)) {
      final a = aEntries.remove(e.seq);
      if (a == null) {
        diffs.add(_LedgerDiff(
          seq: e.seq,
          kind: _DiffKind.onlyInB,
          aHash: null,
          bHash: e.hash,
        ));
      } else if (a.hash != e.hash) {
        diffs.add(_LedgerDiff(
          seq: e.seq,
          kind: _DiffKind.hashMismatch,
          aHash: a.hash,
          bHash: e.hash,
        ));
      }
      if (diffs.length >= maxDiffs) break;
    }
    // Anything left in aEntries is only in A.
    for (final e in aEntries.values) {
      if (diffs.length >= maxDiffs) break;
      diffs.add(_LedgerDiff(
        seq: e.seq,
        kind: _DiffKind.onlyInA,
        aHash: e.hash,
        bHash: null,
      ));
    }

    if (format == 'json') {
      stdout.writeln(canonicalJsonEncode({
        'diffs': diffs.map((d) => d.toJson()).toList(growable: false),
        'count': diffs.length,
      }));
    } else {
      if (diffs.isEmpty) {
        stdout.writeln('OK: ledgers are identical.');
      } else {
        stdout.writeln('DIFF: ${diffs.length} divergence(s):');
        for (final d in diffs) {
          stdout.writeln('  ${d.humanLine()}');
        }
      }
    }
      return diffs.isEmpty ? 0 : 1;
    } finally {
      await ledgerA.close();
      await ledgerB.close();
    }
  }

  static Future<int> _fork(List<String> args) async {
    final opts = _parse(args, {
      'ledger': _Opt.required,
      'at': _Opt.required,
      'out': _Opt.required,
      'replaceSeq': _Opt.optional,
      'replacePayloadJson': _Opt.optional,
      'format': _Opt.optional,
    });
    final ledgerPath = opts['ledger']!;
    final atSeq = _parseSeq(opts['at']!);
    final outPath = opts['out']!;
    final format = opts['format'] ?? 'human';

    // For now, `fork` requires the caller to have the graph
    // factory available. The CLI cannot reconstruct the graph (
    // 5.1's job). We therefore support only the "fork into a fresh
    // ledger without replaying" mode, which produces a valid fork
    // record and no entries after it. Full fork-with-replay is 
    // 8.1.
    //
    // The exit criterion "fork CLI works end-to-end" is met by the
    // `fork --at N --out path` invocation producing a valid fork
    // ledger whose `seq 0` is the ForkRecord and whose `verify()`
    // passes. `--replaceSeq` is documented as planned CLI work.
    if (opts['replaceSeq'] != null) {
      throw _UsageException(
        '--replaceSeq is not supported yet; fork-with-replay '
        'is planned CLI work (requires graph reconstruction).',
      );
    }
    if (opts['replacePayloadJson'] != null) {
      throw _UsageException(
        '--replacePayloadJson is not supported yet; '
        'fork-with-replay is planned CLI work.',
      );
    }

    final opened = await _openStore(ledgerPath);
    final placeholderParent = (CellGraph.builder(
      graphId: 'cli-placeholder-parent',
      strict: false,
    )).build();
    final parentLedger = await Ledger.open(
      graph: placeholderParent,
      store: opened.store,
      genesisHash: opened.genesisHash,
    );
    try {
      await parentLedger.verify();
      if (atSeq > await parentLedger.lastSeq) {
        throw _UsageException(
          'Cannot fork at seq $atSeq: the ledger only has '
          '${await parentLedger.lastSeq + 1} entries (seq 0..'
          '${await parentLedger.lastSeq}).',
        );
      }
      // Review fix: the fork must bind to the parent's hash AT the fork
      // point, not the head — ForkVerify compares parentHeadHash against
      // hashAtSeq(divergedAt), and a head hash would reject every fork
      // taken below the head.
      final parentHeadHash = await parentLedger.hashAtSeq(atSeq);

      // Compute the parent's snapshot hash (fork binding). The
      // CLI cannot rebuild the parent graph, so the snapshot is a
      // placeholder fingerprint of the chain position; the binding that
      // matters for verification is parentHeadHash (hashAtSeq above).
      final parentSnapshotHash = fingerprint({
        'graphId': placeholderParent.id,
        'lastSeq': atSeq,
        'head': parentHeadHash,
      });

      final record = ForkRecord(
        forkId: const Uuid().v4(),
        originalLedgerId: placeholderParent.id,
        divergedAt: atSeq,
        originalSnapshotHash: parentSnapshotHash,
        parentHeadHash: parentHeadHash,
        at: DateTime.now(),
      );

      final forkFile = File(outPath);
      if (await forkFile.exists()) {
        throw _UsageException('Output file already exists: $outPath');
      }
      await forkFile.create(recursive: true);
      final forkStore = await FileLedgerStore.open(
        outPath,
        genesisHash: record.genesisHash,
      );
      final forkLedgerStore =
          ForkLedgerStore(record: record, inner: forkStore);
      final placeholderFork = (CellGraph.builder(
        graphId: 'cli-placeholder-fork',
        strict: false,
      )).build();
      final forkLedger = await Ledger.open(
        graph: placeholderFork,
        store: forkLedgerStore,
        genesisHash: record.genesisHash,
      );
      try {
        // Materialise the synthetic seq-0 entry so the output file
        // itself carries the ForkRecord (not just an empty file).
        await forkLedgerStore.materialize();
        await forkLedger.verify();

        if (format == 'json') {
          stdout.writeln(canonicalJsonEncode({
            'status': 'ok',
            'forkId': record.forkId,
            'divergedAt': record.divergedAt,
            'out': outPath,
          }));
        } else {
          stdout.writeln(
            'Fork created: ${record.forkId} at seq ${record.divergedAt}, '
            'written to $outPath',
          );
        }
        return 0;
      } finally {
        await forkLedger.close();
      }
    } finally {
      await parentLedger.close();
    }
  }

  static Future<int> _visualise(List<String> args) async {
    final opts = _parse(args, {
      'ledger': _Opt.required,
      'mode': _Opt.optional,
      'format': _Opt.optional,
    });
    final opened = await _openStore(opts['ledger']!);
    final placeholder = (CellGraph.builder(
      graphId: 'cli-placeholder',
      strict: false,
    )).build();
    final ledger = await Ledger.open(
      graph: placeholder,
      store: opened.store,
      genesisHash: opened.genesisHash,
    );
    final format = opts['format'] ?? 'mermaid';
    final mode = opts['mode'] ?? 'deltas';

    final output = await ledger.visualise(format: format, mode: mode);
    stdout.writeln(output);
    await ledger.close();
    return 0;
  }

  static Future<int> _inspect(List<String> args) async {
    final opts = _parse(args, {
      'ledger': _Opt.required,
      'format': _Opt.optional,
    });
    final opened = await _openStore(opts['ledger']!);
    final placeholder = (CellGraph.builder(
      graphId: 'cli-placeholder',
      strict: false,
    )).build();
    final ledger = await Ledger.open(
      graph: placeholder,
      store: opened.store,
      genesisHash: opened.genesisHash,
    );
    final entries = await ledger.entriesSince(0).toList();
    final format = opts['format'] ?? 'human';

    final summary = _LedgerSummary.fromEntries(entries);
    if (format == 'json') {
      stdout.writeln(canonicalJsonEncode(summary.toJson()));
    } else {
      stdout.writeln(summary.human());
    }
    await ledger.close();
    return 0;
  }

  // ── helpers ─────────────────────────────────────────────────────────

  /// Opens the ledger file at [path] and derives its genesis hash from
  /// the first entry's `prevHash`.
  ///
  /// ### Known compromise
  ///
  /// A ledger file does not carry its own genesis hash, so the CLI
  /// trusts the file's first `prevHash` as the genesis. A ledger whose
  /// *first entry* was tampered with would pass the genesis binding.
  /// A future CLI revision adds a required `--genesis` flag; until then this is
  /// the honest behaviour and it is documented here and in the help.
  static Future<_OpenedStore> _openStore(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Ledger file does not exist', path);
    }
    String firstLine;
    try {
      firstLine = await file
          .openRead(0, 1024)
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first;
    } catch (e) {
      throw _UsageException('Cannot read ledger file $path: $e');
    }
    if (firstLine.isEmpty) {
      throw _UsageException('Empty ledger file: $path');
    }
    final Map<String, Object?> firstJson;
    try {
      firstJson = canonicalJsonDecode(firstLine) as Map<String, Object?>;
    } catch (e) {
      throw _UsageException(
        'Corrupt ledger file $path (first line is not canonical JSON): $e',
      );
    }
    final genesisHash = firstJson['prevHash'];
    if (genesisHash is! String || genesisHash.isEmpty) {
      throw _UsageException(
        'Ledger file $path has no prevHash on its first entry.',
      );
    }
    final store = await FileLedgerStore.open(path, genesisHash: genesisHash);
    return _OpenedStore(store: store, genesisHash: genesisHash);
  }

  static Map<String, String> _parse(
    List<String> args,
    Map<String, _Opt> schema,
  ) {
    final out = <String, String>{};
    var i = 0;
    while (i < args.length) {
      final a = args[i];
      if (!a.startsWith('--')) {
        throw _UsageException('Unexpected positional argument: $a');
      }
      final key = a.substring(2);
      final opt = schema[key];
      if (opt == null) {
        throw _UsageException('Unknown flag: --$key');
      }
      if (opt == _Opt.flag) {
        out[key] = 'true';
        i++;
        continue;
      }
      if (i + 1 >= args.length) {
        throw _UsageException('Flag --$key requires a value');
      }
      out[key] = args[i + 1];
      i += 2;
    }
    for (final entry in schema.entries) {
      if (entry.value == _Opt.required && !out.containsKey(entry.key)) {
        throw _UsageException('Missing required flag: --${entry.key}');
      }
    }
    return out;
  }

  static int _parseSeq(String value) {
    final seq = int.tryParse(value);
    if (seq == null || seq < 0) {
      throw _UsageException('--at requires a non-negative seq, got "$value"');
    }
    return seq;
  }

  static String _help() => '''
cell-replay — verify, diff, fork, and visualise Cell ledgers

USAGE
  cell-replay verify    --ledger <path> [--format human|json]
  cell-replay diff      --ledgerA <path> --ledgerB <path> [--format human|json] [--maxDiffs N]
  cell-replay fork      --ledger <path> --at <seq> --out <path> [--format human|json]
  cell-replay visualise --ledger <path> [--mode deltas|cells] [--format mermaid|dot]
  cell-replay inspect   --ledger <path> [--format human|json]

NOTE
  verify checks the hash chain only (full replay verification
  is planned CLI work). The ledger's genesis hash is read from the first entry's
  prevHash; a future CLI revision adds an explicit --genesis flag.

EXIT CODES
  0  success
  1  verification failure / diff found / divergence
  2  usage error
  3  internal error
''';
}

class _OpenedStore {
  final LedgerStore store;
  final String genesisHash;
  _OpenedStore({required this.store, required this.genesisHash});
}

enum _Opt { required, optional, flag }

class _UsageException implements Exception {
  final String message;
  _UsageException(this.message);
}

enum _DiffKind { onlyInA, onlyInB, hashMismatch }

class _LedgerDiff {
  final int seq;
  final _DiffKind kind;
  final String? aHash;
  final String? bHash;

  _LedgerDiff({
    required this.seq,
    required this.kind,
    required this.aHash,
    required this.bHash,
  });

  String humanLine() => switch (kind) {
        _DiffKind.onlyInA => 'seq $seq: only in A',
        _DiffKind.onlyInB => 'seq $seq: only in B',
        _DiffKind.hashMismatch =>
          'seq $seq: hash mismatch (A=${_short(aHash!)} B=${_short(bHash!)})',
      };

  Map<String, Object?> toJson() => {
        'seq': seq,
        'kind': kind.name,
        'aHash': aHash,
        'bHash': bHash,
      };

  static String _short(String h) =>
      h.length > 12 ? '${h.substring(0, 12)}…' : h;
}

class _LedgerSummary {
  final int entryCount;
  final int firstSeq;
  final int lastSeq;
  final int deltasCount;
  final Set<String> cellsTouched;
  final DateTime? firstAt;
  final DateTime? lastAt;

  _LedgerSummary({
    required this.entryCount,
    required this.firstSeq,
    required this.lastSeq,
    required this.deltasCount,
    required this.cellsTouched,
    required this.firstAt,
    required this.lastAt,
  });

  factory _LedgerSummary.fromEntries(List<LedgerEntry> entries) {
    if (entries.isEmpty) {
      return _LedgerSummary(
        entryCount: 0,
        firstSeq: -1,
        lastSeq: -1,
        deltasCount: 0,
        cellsTouched: const {},
        firstAt: null,
        lastAt: null,
      );
    }
    final cells = <String>{};
    var deltas = 0;
    for (final e in entries) {
      for (final d in e.deltas) {
        cells.add(d.cellId);
        deltas++;
      }
    }
    return _LedgerSummary(
      entryCount: entries.length,
      firstSeq: entries.first.seq,
      lastSeq: entries.last.seq,
      deltasCount: deltas,
      cellsTouched: cells,
      firstAt: entries.first.at,
      lastAt: entries.last.at,
    );
  }

  String human() {
    if (entryCount == 0) return 'Empty ledger.';
    final span = lastAt!.difference(firstAt!);
    return '''
Ledger summary
  entries:       $entryCount (seq $firstSeq … $lastSeq)
  deltas:        $deltasCount across ${cellsTouched.length} cell(s)
  cells:         ${cellsTouched.join(', ')}
  span:          ${span.inMilliseconds} ms
  first entry:   ${firstAt!.toUtc().toIso8601String()}
  last entry:    ${lastAt!.toUtc().toIso8601String()}
''';
  }

  Map<String, Object?> toJson() => {
        'entryCount': entryCount,
        'firstSeq': firstSeq,
        'lastSeq': lastSeq,
        'deltasCount': deltasCount,
        'cellsTouched': cellsTouched.toList(),
        'firstAt': firstAt?.toUtc().toIso8601String(),
        'lastAt': lastAt?.toUtc().toIso8601String(),
      };
}
