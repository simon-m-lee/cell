// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// One receipt: the receipt on the wire is the receipt in the ledger.
///
/// A `SkinBinding.state` apply writes exactly one row whose receipt id is
/// the apply receipt's id, and the wire outcome carries that row's
/// `ledgerSeq`/`pulseDigest` under the binding's wire name. A command
/// binding reports its inner rows as `ledgerSeqs`; a raw binding that
/// still calls `update()` is a strict-receipts contract break.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  Future<(int, Map<String, Object?>)> postJson(
    HttpClient http,
    RestAdapter adapter,
    Map<String, Object?> body, {
    String path = '/skin/apply',
  }) async {
    final request = await http.postUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}$path'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    return (
      response.statusCode,
      text.isEmpty
          ? <String, Object?>{}
          : (jsonDecode(text) as Map).cast<String, Object?>(),
    );
  }

  Map<String, Object?> applyBody(
    String cellId,
    String function,
    List<Object?> positional, {
    String? correlationId,
  }) =>
      {
        'cellId': cellId,
        'function': function,
        'positional': {
          for (var i = 0; i < positional.length; i++) '$i': positional[i],
        },
        if (correlationId != null) 'correlationId': correlationId,
      };

  test('state id and seq: the wire receipt is the ledger row', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final before = await f.ledger.lastSeq;
    final message = await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.living.thermostat',
            function: 'setTarget',
            positional: {'0': 19},
            correlationId: 'c-state',
          ),
          type: SkinPulseTypes.restApplyRequest,
        ));
    final response = message as WireResponse;
    final outcome = response.outcome!;

    final entries = await f.ledger.entriesSince(before + 1).toList();
    expect(entries, hasLength(1));
    final entry = entries.single;
    expect(entry.receipt.id, outcome.receipt.id);
    // The live receipt stays untouched; the store's copy carries the
    // back-filled seq.
    expect(outcome.receipt.ledgerSeq, isNull);
    expect(response.outcomeJson, isNotNull);
    expect(response.outcomeJson!.receipt['ledgerSeq'], entry.seq);
    expect(response.outcomeJson!.receipt['pulseDigest'], entry.pulseDigest);
    expect(response.outcomeJson!.receipt['function'], 'setTarget');
    expect(response.outcomeJson!.receipt['function'].toString(),
        isNot(contains('Closure')));

    // The same call over HTTP, on an empty ledger: the result is the
    // pulse payload, not a Pulse, and the wire receipt carries seq 0.
    CellGraphRegistry.forceReset();
    final f2 = await SkinFixture.build(graphId: 'receipt-http');
    final adapter = await RestAdapter.bind(
        membrane: f2.membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f2.membrane.close();
      await f2.ledger.close();
    });
    final (status, body) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'setTarget', [19]),
    );
    expect(status, HttpStatus.ok);
    final outcomeJson = (body['outcome'] as Map).cast<String, Object?>();
    expect(outcomeJson['result'], 19);
    expect(outcomeJson.containsKey('resultOmitted'), isFalse);
    final receiptJson =
        (outcomeJson['receipt'] as Map).cast<String, Object?>();
    expect(receiptJson['ledgerSeq'], 0,
        reason: 'this is the first row of the ledger');
  });

  test('egress carries the same receipt with the binding name', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final changes = <WireStateChange>[];
    final subscription = f.membrane.responses.listen((pulse) {
      if (pulse.payload is WireStateChange) {
        changes.add(pulse.payload as WireStateChange);
      }
    });

    final message = await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.living.thermostat',
            function: 'setTarget',
            positional: {'0': 19},
            correlationId: 'c-egress',
          ),
          type: SkinPulseTypes.restApplyRequest,
        ));
    final response = message as WireResponse;
    await f.settle();

    final change = changes.lastWhere(
        (c) => c.cellId == 'home.living.thermostat');
    expect(change.receipt, isNotNull);
    expect(change.receipt!.id, response.outcome!.receipt.id);
    expect(change.receipt!.ledgerSeq, response.outcomeJson!.receipt['ledgerSeq']);
    expect(change.receipt!.functionLabel, 'setTarget');

    await subscription.cancel();
  });

  test('a retry replays the same receipt id and seq', () async {
    final f = await SkinFixture.build();
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    final body =
        applyBody('home.living.thermostat', 'setTarget', [19], correlationId: 'k');
    final (firstStatus, first) = await postJson(http, adapter, body);
    final (secondStatus, second) = await postJson(http, adapter, body);
    expect(firstStatus, HttpStatus.ok);
    expect(secondStatus, HttpStatus.ok);
    expect(await f.ledger.lastSeq, 0);

    final firstReceipt = ((first['outcome'] as Map)['receipt'] as Map)
        .cast<String, Object?>();
    final secondReceipt = ((second['outcome'] as Map)['receipt'] as Map)
        .cast<String, Object?>();
    expect(secondReceipt['id'], firstReceipt['id']);
    expect(secondReceipt['ledgerSeq'], firstReceipt['ledgerSeq']);
  });

  test('setColor writes the color cell', () async {
    final f = await SkinFixture.build();
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    final (status, body) = await postJson(
        http, adapter, applyBody('home.living.light.color', 'setColor', ['#112233']));
    expect(status, HttpStatus.ok);
    expect(f.light.cell.value, 0.8, reason: 'brightness is untouched');
    expect(f.lightColor.cell.value, '#112233');
    final outcomeJson = (body['outcome'] as Map).cast<String, Object?>();
    expect(
        ((outcomeJson['receipt'] as Map).cast<String, Object?>())['cell'],
        'home.living.light.color');
    expect(
        ((outcomeJson['receipt'] as Map).cast<String, Object?>())['function'],
        'setColor');
    final entries = await f.ledger.entriesSince(0).toList();
    expect(entries.single.receiptCellId, 'home.living.light.color');
  });

  test('a command binding reports its inner rows as ledgerSeqs', () async {
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding.command(
          cellId: 'home.living.light',
          functionName: 'optimize',
          target: targets.light.cell,
          function: () async {
            await Cell.txApply().execute(
              participants: [targets.light.cell, targets.lightColor.cell],
              body: (tx) {
                targets.light.cell.apply<Object?>(
                  (
                    function: () => Pulse<double>(0.5),
                    arguments: (positionalArguments: null, namedArguments: null),
                    compensation: null,
                  ),
                  tx: tx,
                );
                targets.lightColor.cell.apply<Object?>(
                  (
                    function: () => Pulse<String>('#FDB813'),
                    arguments: (positionalArguments: null, namedArguments: null),
                    compensation: null,
                  ),
                  tx: tx,
                );
              },
            );
            return true;
          },
        ),
      ],
    );
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    final (status, body) = await postJson(
        http, adapter, applyBody('home.living.light', 'optimize', const []));
    expect(status, HttpStatus.ok);
    expect(body['ledgerSeqs'], [0, 1]);
    final outcomeJson = (body['outcome'] as Map).cast<String, Object?>();
    expect(outcomeJson['result'], true);
    expect(
        ((outcomeJson['receipt'] as Map).cast<String, Object?>())
            .containsKey('ledgerSeq'),
        isFalse,
        reason: 'the outer receipt is not a row');

    final entries = await f.ledger.entriesSince(0).toList();
    expect(entries, hasLength(2));
    final outerReceiptId =
        ((outcomeJson['receipt'] as Map).cast<String, Object?>())['id'];
    expect(entries.every((e) => e.receipt.id != outerReceiptId), isTrue);
  });

  test('a raw update() binding is refused under strict receipts', () async {
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'legacySet',
          target: targets.thermostat.cell,
          function: (int target) => targets.thermostat.update(target),
        ),
      ],
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final message = await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.living.thermostat',
            function: 'legacySet',
            positional: {'0': 18},
            correlationId: 'c-legacy',
          ),
          type: SkinPulseTypes.restApplyRequest,
        ));
    expect(message, isA<WireError>());
    final error = message as WireError;
    expect(error.code, 'transport_error');
    expect(error.message, isNot(contains('Closure')));
    // The write already happened; the contract break is reported after.
    expect(f.thermostat.cell.value, 18);

    // The same shape with strict receipts off keeps the split: the live
    // outcome is accepted but its receipt id is not the row's id.
    CellGraphRegistry.forceReset();
    final thermostat2 = Cell.state<int>(initial: 22);
    final graph2 = (CellGraph.builder(graphId: 'strict-off')
          ..register('home.living.thermostat', thermostat2.cell))
        .build();
    final ledger2 = await graph2.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph2.id),
      ),
    );
    addTearDown(ledger2.close);
    final bindings2 = SkinBindingTable()
      ..register(SkinBinding(
        cellId: 'home.living.thermostat',
        functionName: 'legacySet',
        target: thermostat2.cell,
        function: (int target) => thermostat2.update(target),
      ));
    final membrane2 = await SkinMembrane.open(
      graph: graph2,
      bindings: bindings2,
      ledger: ledger2,
      journal: RecordingJournal(),
      send: (_) {},
      strictReceipts: false,
    );
    addTearDown(membrane2.close);
    final message2 = await membrane2.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'legacySet',
        positional: {'0': 18},
        correlationId: 'c-legacy-2',
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect(message2, isA<WireResponse>());
    final outcome2 = (message2 as WireResponse).outcome!;
    final entries2 = await ledger2.entriesSince(0).toList();
    expect(entries2, hasLength(1));
    expect(entries2.single.receipt.id, isNot(outcome2.receipt.id));
  });

  test('a rejection carries no ledgerSeqs and appends nothing', () async {
    final f = await SkinFixture.build();
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    final before = await f.ledger.lastSeq;
    final (status, body) = await postJson(
        http, adapter, applyBody('home.front.door', 'lock', const []));
    expect(status, HttpStatus.ok);
    final outcomeJson = (body['outcome'] as Map).cast<String, Object?>();
    expect(outcomeJson['kind'], 'rejected');
    expect(
        ((outcomeJson['receipt'] as Map).cast<String, Object?>())['function'],
        'lock');
    expect(body.containsKey('ledgerSeqs'), isFalse);
    expect(await f.ledger.lastSeq, before);
  });
}
