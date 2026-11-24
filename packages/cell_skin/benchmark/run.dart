// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Benchmark runner for the skin's three regression budgets.
//
// Run from packages/cell_skin (NOT `dart test` — the test runner enables
// debug asserts):
//
//   dart run benchmark/run.dart
//
// Methodology: 5 unmeasured warmups, then the median of 9 runs per key.
// A null ceiling in benchmark/regression-budgets.json means this run
// measures, writes the number, and exits 0. A number means exit 1 when
// the sample is greater than ceiling * allowance. Nobody edits a number
// by hand after that. The allowance is 1.0 — the same scheduler slack
// the cell benchmarks use.
//
// Every measurement uses only the public API surface, exactly what an
// adopter would use.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:cell_skin/cell_skin_rest.dart';

const String budgetsPath = 'benchmark/regression-budgets.json';

Future<void> main() async {
  final file = File(budgetsPath);
  final budgets = file.existsSync()
      ? (jsonDecode(file.readAsStringSync()) as Map)
          .cast<String, Map<String, Object?>>()
      : <String, Map<String, Object?>>{};

  var failed = false;
  for (final entry in {
    'apply_round_trip': measureApplyRoundTrip,
    'schema_rejection': measureSchemaRejection,
    'ledger_sse_32': measureLedgerSse32,
  }.entries) {
    final sampleUs = await medianOf9(entry.value);
    final budget = budgets[entry.key] ??
        <String, Object?>{'ceilingMicros': null, 'allowance': 1.0};
    final ceiling = budget['ceilingMicros'] as int?;
    final allowance = (budget['allowance'] as num?)?.toDouble() ?? 1.0;
    stdout.writeln('${entry.key}: $sampleUs us');
    if (ceiling == null) {
      budget['ceilingMicros'] = sampleUs;
    } else if (sampleUs > (ceiling * allowance).ceil()) {
      stderr.writeln('${entry.key}: $sampleUs us exceeds the budget '
          '$ceiling us * $allowance');
      failed = true;
    }
    budgets[entry.key] = budget;
  }
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(budgets));
  if (failed) exitCode = 1;
}

Future<int> medianOf9(Future<void> Function() benchmark) async {
  for (var i = 0; i < 5; i++) {
    await benchmark();
  }
  final samples = <int>[];
  for (var i = 0; i < 9; i++) {
    final watch = Stopwatch()..start();
    await benchmark();
    watch.stop();
    samples.add(watch.elapsedMicroseconds);
  }
  samples.sort();
  return samples[samples.length ~/ 2];
}

final class _Bench {
  final String cellId;
  final CellGraph graph;
  final Ledger ledger;
  final SkinMembrane membrane;

  _Bench(this.cellId, this.graph, this.ledger, this.membrane);

  static Future<_Bench> open({required String graphId}) async {
    final cellId = 'bench.$graphId.thermostat';
    final thermostat = Cell.state<int>(initial: 22);
    final graph = (CellGraph.builder(graphId: graphId)
          ..register(cellId, thermostat.cell))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graphId),
      ),
    );
    final bindings = SkinBindingTable()
      ..register(SkinBinding.state(
        cellId: cellId,
        functionName: 'setTarget',
        target: thermostat.cell,
        nextValue: (int target) => target,
        argumentSchema: const JsonSchema(
          type: 'object',
          properties: {
            'target': JsonSchema(type: 'integer', minimum: 16, maximum: 26),
          },
          required: ['target'],
        ),
        positionalNames: ['target'],
      ));
    final membrane = await SkinMembrane.open(
      graph: graph,
      bindings: bindings,
      ledger: ledger,
      journal: RecordingJournal(),
      send: (_) {},
    );
    return _Bench(cellId, graph, ledger, membrane);
  }

  Future<void> close() async {
    await membrane.close();
    await ledger.close();
  }
}

/// One in-process `membrane.request` of a state binding. Memory store.
/// Local membrane. Clock starts at `request` and stops at the returned
/// `WireResponse`.
int _applyRun = 0;

Future<void> measureApplyRoundTrip() async {
  final bench = await _Bench.open(graphId: 'bench-apply-${_applyRun++}');
  try {
    for (var i = 0; i < 3; i++) {
      final message = await bench.membrane.request(
        WireRequest(
          cellId: bench.cellId,
          function: 'setTarget',
          correlationId: 'bench-$i',
          positional: {'0': 21},
        ),
        type: SkinPulseTypes.restApplyRequest,
      );
      if (message is! WireResponse) {
        throw StateError('expected WireResponse, got $message');
      }
    }
  } finally {
    await bench.close();
  }
}

/// One `request` that fails the declared schema. Stops at `WireError`
/// `bad_arguments`. The function is not called.
int _schemaRun = 0;

Future<void> measureSchemaRejection() async {
  final bench = await _Bench.open(graphId: 'bench-schema-${_schemaRun++}');
  try {
    for (var i = 0; i < 3; i++) {
      final message = await bench.membrane.request(
        WireRequest(
          cellId: bench.cellId,
          function: 'setTarget',
          correlationId: 'bench-$i',
          positional: {'0': null},
        ),
        type: SkinPulseTypes.restApplyRequest,
      );
      if (message is! WireError || message.code != 'bad_arguments') {
        throw StateError('expected bad_arguments, got $message');
      }
    }
  } finally {
    await bench.close();
  }
}

/// One row is already appended and the adapter is already listening.
/// Then 32 `GET /skin/ledger?since=0` clients. Clock starts when those
/// 32 are issued and stops when all 32 have delivered that row. Bind
/// time is not included.
int _sseRun = 0;

Future<void> measureLedgerSse32() async {
  final bench = await _Bench.open(graphId: 'bench-sse-${_sseRun++}');
  final adapter = await RestAdapter.bind(
      membrane: bench.membrane, auth: const AllowAllSkinAuth());
  final http = HttpClient();
  try {
    final seeded = await bench.membrane.request(
      WireRequest(
        cellId: bench.cellId,
        function: 'setTarget',
        correlationId: 'bench-seed',
        positional: {'0': 21},
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    if (seeded is! WireResponse) {
      throw StateError('expected WireResponse, got $seeded');
    }

    Future<bool> delivered() async {
      final request = await http.getUrl(
          Uri.parse('http://127.0.0.1:${adapter.port}/skin/ledger?since=0'));
      final response = await request.close();
      final text = await response
          .timeout(const Duration(seconds: 10),
              onTimeout: (sink) => sink.close())
          .transform(utf8.decoder)
          .join();
      return text.contains('"seq":0');
    }

    final watch = Stopwatch()..start();
    final results = await Future.wait(
        [for (var i = 0; i < 32; i++) delivered()]);
    watch.stop();
    if (!results.every((r) => r)) {
      throw StateError('a client missed the appended row');
    }
  } finally {
    http.close();
    await adapter.close();
    await bench.close();
  }
}
