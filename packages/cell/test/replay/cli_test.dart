// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell/replay.dart';
import 'package:cell/replay/cli/cli.dart';
import 'package:test/test.dart';

/// End-to-end tests for the `cell-replay` CLI, run in-process against
/// temporary ledger files. One test spawns the real `bin/cell_replay.dart`
/// entry point to prove the executable wiring.
void main() {
  late Directory dir;
  late String ledgerPath;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('cell_replay_cli_test');
    ledgerPath = '${dir.path}/ledger.jsonl';
    await _writeValidLedger(ledgerPath, updates: [1, 2, 3]);
  });

  tearDownAll(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test('--help exits 0 and prints usage', () async {
    final out = await _capture(() => Cli.run(['--help']));
    expect(out.exitCode, 0);
    expect(out.stdout, contains('cell-replay'));
    expect(out.stdout, contains('verify'));
  });

  test('no args exits 2 (usage)', () async {
    final out = await _capture(() => Cli.run([]));
    expect(out.exitCode, 2);
  });

  test('unknown command exits 2', () async {
    final out = await _capture(() => Cli.run(['frobnicate']));
    expect(out.exitCode, 2);
  });

  test('verify passes on a valid ledger', () async {
    final out =
        await _capture(() => Cli.run(['verify', '--ledger', ledgerPath]));
    expect(out.exitCode, 0);
    expect(out.stdout, contains('OK: ledger is valid (3 entries)'));
  });

  test('verify fails on a tampered ledger', () async {
    final tampered = '${dir.path}/tampered.jsonl';
    await _tamper(ledgerPath, tampered, tamperSeq: 2);
    final out =
        await _capture(() => Cli.run(['verify', '--ledger', tampered]));
    expect(out.exitCode, 1);
    expect(out.stderr, contains('INVALID'));
  });

  test('verify --format json emits canonical JSON', () async {
    final out = await _capture(() =>
        Cli.run(['verify', '--ledger', ledgerPath, '--format', 'json']));
    expect(out.exitCode, 0);
    final json = jsonDecode(out.stdout.trim());
    expect(json['status'], 'ok');
    expect(json['lastSeq'], 2);
  });

  test('verify --graph is rejected until a future CLI revision', () async {
    final out = await _capture(() => Cli.run(
        ['verify', '--ledger', ledgerPath, '--graph', 'snapshot.json']));
    expect(out.exitCode, 2);
    expect(out.stderr, contains('planned CLI work'));
  });

  test('diff reports identical ledgers as exit 0', () async {
    final copy = '${dir.path}/copy.jsonl';
    await File(ledgerPath).copy(copy);
    final out = await _capture(
        () => Cli.run(['diff', '--ledgerA', ledgerPath, '--ledgerB', copy]));
    expect(out.exitCode, 0);
    expect(out.stdout, contains('identical'));
  });

  test('diff reports divergence as exit 1', () async {
    final other = '${dir.path}/other.jsonl';
    await _writeValidLedger(other, updates: [1, 2, 4]);
    final out = await _capture(
        () => Cli.run(['diff', '--ledgerA', ledgerPath, '--ledgerB', other]));
    expect(out.exitCode, 1);
    expect(out.stdout, contains('DIFF'));
    expect(out.stdout, contains('seq 2: hash mismatch'));
  });

  test('fork writes a valid fork ledger whose seq 0 is the ForkRecord',
      () async {
    final forkPath = '${dir.path}/fork.jsonl';
    final out = await _capture(() => Cli.run([
          'fork',
          '--ledger',
          ledgerPath,
          '--at',
          '1',
          '--out',
          forkPath,
          '--format',
          'json',
        ]));
    expect(out.exitCode, 0);
    final json = jsonDecode(out.stdout.trim());
    expect(json['status'], 'ok');
    expect(json['divergedAt'], 1);
    expect(json['out'], forkPath);

    // The fork file's first entry is the synthetic ForkRecord entry.
    final firstLine = await File(forkPath)
        .openRead(0, 1024)
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    final firstEntry = jsonDecode(firstLine) as Map<String, dynamic>;
    expect(firstEntry['seq'], 0);
    expect((firstEntry['receipt'] as Map)['id'], startsWith('fork:'));

    // (review): the fork FILE carries the record itself — the
    // synthetic seq-0 entry's first positional argument is
    // ForkRecord.toJson — and parentHeadHash must be the parent's hash
    // AT --at (ForkVerify compares against hashAtSeq(divergedAt)).
    final args =
        ((firstEntry['receipt'] as Map)['arguments'] as Map)['positional'];
    expect(args, isA<List>());
    final embedded = (args as List).first as Map<String, dynamic>;
    expect(embedded['divergedAt'], 1);
    expect(embedded['forkId'], json['forkId']);
    final parentStore = await FileLedgerStore.open(
      ledgerPath,
      genesisHash: (jsonDecode((await File(ledgerPath)
                  .openRead()
                  .transform(utf8.decoder)
                  .transform(const LineSplitter())
                  .first)) as Map<String, dynamic>)['prevHash'] as String,
    );
    final parentPlaceholder = (CellGraph.builder(
      graphId: 'cli-placeholder-parent',
      strict: false,
    )).build();
    final parentLedger = await Ledger.open(
      graph: parentPlaceholder,
      store: parentStore,
      genesisHash: parentStore.genesisHash,
    );
    final hashAtSeq = await parentLedger.hashAtSeq(1);
    expect(embedded['parentHeadHash'], hashAtSeq,
        reason: 'the CLI fork must bind to the parent hash AT --at');
    await parentLedger.close();

    // And the fork verifies as a chain.
    final verify = await _capture(
        () => Cli.run(['verify', '--ledger', forkPath]));
    expect(verify.exitCode, 0, reason: verify.stderr);
  });

  test('fork rejects --replaceSeq until a future CLI revision', () async {
    final out = await _capture(() => Cli.run([
          'fork',
          '--ledger',
          ledgerPath,
          '--at',
          '1',
          '--out',
          '${dir.path}/nope.jsonl',
          '--replaceSeq',
          '2',
        ]));
    expect(out.exitCode, 2);
    expect(out.stderr, contains('planned CLI work'));
  });

  test('visualise emits mermaid and dot', () async {
    final mermaid = await _capture(() =>
        Cli.run(['visualise', '--ledger', ledgerPath, '--mode', 'deltas']));
    expect(mermaid.exitCode, 0);
    expect(mermaid.stdout, contains('graph LR'));
    expect(mermaid.stdout, contains('seq 0: counter'));

    final dot = await _capture(() => Cli.run([
          'visualise',
          '--ledger',
          ledgerPath,
          '--mode',
          'cells',
          '--format',
          'dot',
        ]));
    expect(dot.exitCode, 0);
    expect(dot.stdout, contains('digraph Ledger'));
    expect(dot.stdout, contains('counter'));
  });

  test('inspect prints the summary in human and json', () async {
    final human =
        await _capture(() => Cli.run(['inspect', '--ledger', ledgerPath]));
    expect(human.exitCode, 0);
    expect(human.stdout, contains('Ledger summary'));
    expect(human.stdout, contains('counter'));

    final json = await _capture(() =>
        Cli.run(['inspect', '--ledger', ledgerPath, '--format', 'json']));
    expect(json.exitCode, 0);
    final decoded = jsonDecode(json.stdout.trim()) as Map<String, dynamic>;
    expect(decoded['entryCount'], 3);
    expect(decoded['cellsTouched'], ['counter']);
  });

  test('missing file exits 2', () async {
    final out = await _capture(
        () => Cli.run(['verify', '--ledger', '${dir.path}/missing.jsonl']));
    expect(out.exitCode, 2);
  });

  test('the bin entry point prints help and exits 0', () async {
    final result = await Process.run(
      'dart',
      ['run', 'bin/cell_replay.dart', '--help'],
      workingDirectory: Directory.current.path,
    );
    expect(result.exitCode, 0);
    expect('${result.stdout}', contains('cell-replay'));
    expect('${result.stdout}', contains('EXIT CODES'));
  });
}

/// Builds a valid three-entry ledger for the CLI tests.
Future<void> _writeValidLedger(
  String path, {
  required List<int> updates,
}) async {
  CellGraphRegistry.forceReset();
  final counter = Cell.state<int>(initial: 0);
  final graph = (CellGraph.builder(graphId: 'cli-test-graph')
        ..registerState('counter', counter))
      .build();
  final ledger = await graph.bindLedger(
    store: await FileLedgerStore.open(
      path,
      genesisHash: Ledger.genesisHashOf(graph.id),
    ),
  );
  await graph.run(() async {
    for (final v in updates) {
      counter.update(v);
    }
  });
  await ledger.close();
}

/// Rewrites the ledger with one entry's `hash` corrupted.
Future<void> _tamper(
  String source,
  String target, {
  required int tamperSeq,
}) async {
  final lines = await File(source).readAsLines();
  final out = <String>[];
  for (final line in lines) {
    final entry = jsonDecode(line) as Map<String, dynamic>;
    if (entry['seq'] == tamperSeq) {
      entry['hash'] = '0' * 64;
    }
    out.add(jsonEncode(entry));
  }
  await File(target).writeAsString('${out.join('\n')}\n');
}

Future<_CliOut> _capture(Future<int> Function() run) async {
  final stdoutCapture = _StreamCapture();
  final stderrCapture = _StreamCapture();
  final exitCode = await IOOverrides.runZoned(
    run,
    stdout: () => stdoutCapture,
    stderr: () => stderrCapture,
  );
  return _CliOut(
    exitCode: exitCode,
    stdout: stdoutCapture.text,
    stderr: stderrCapture.text,
  );
}

class _CliOut {
  final int exitCode;
  final String stdout;
  final String stderr;
  _CliOut({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}

/// Minimal `Stdout`/`IOSink` stand-in that records what the CLI writes.
/// The unused members fall through to [noSuchMethod] — only `write*` is
/// exercised by the CLI.
class _StreamCapture implements Stdout {
  final StringBuffer buffer = StringBuffer();

  String get text => buffer.toString();

  @override
  void add(List<int> data) => buffer.write(utf8.decode(data));

  @override
  void write(Object? object) => buffer.write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      buffer.writeAll(objects, separator);

  @override
  void writeln([Object? object = '']) => buffer.writeln(object);

  @override
  void writeCharCode(int charCode) => buffer.writeCharCode(charCode);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
