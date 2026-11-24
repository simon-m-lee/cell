// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The ledger scope rule.
///
/// A ledgered membrane records every target apply, including
/// `POST /skin/apply`, by entering `CellGraph.run` only when no scope is
/// already active. Rejected requests append nothing, an existing scope on
/// the same ledger is reused, and an unledgered membrane stays silent.
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
    String path,
    Map<String, Object?> body,
  ) async {
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
    int? lastSeenSeq,
    String? correlationId,
  }) =>
      {
        'cellId': cellId,
        'function': function,
        'positional': {for (var i = 0; i < positional.length; i++) '$i': positional[i]},
        if (lastSeenSeq != null) 'lastSeenSeq': lastSeenSeq,
        if (correlationId != null) 'correlationId': correlationId,
      };

  test('REST apply replays', () async {
    final f = await SkinFixture.build(graphId: 'scope-replay');
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
    final (status, body) = await postJson(http, adapter, '/skin/apply',
        applyBody('home.living.thermostat', 'setTarget', [19]));

    expect(status, HttpStatus.ok, reason: 'guard: apply accepted');
    final outcome = (body['outcome'] as Map).cast<String, Object?>();
    expect(outcome['kind'], 'accepted');
    expect(f.thermostat.cell.value, 19);
    expect(await f.ledger.lastSeq, greaterThan(before),
        reason: 'the HTTP apply appended a ledger row');
    await f.ledger.verify();

    // Replay into a fresh graph with the same id and registrations.
    CellGraphRegistry.forceReset();
    final thermostat2 = Cell.state<int>(
      initial: 22,
      testRule: ValueGate((v) => v is int && v >= 16 && v <= 26),
    );
    final target = (CellGraph.builder(graphId: 'scope-replay')
          ..register('home.living.thermostat', thermostat2.cell))
        .build();
    final result = await ReplayEngine.replay(ledger: f.ledger, target: target);
    expect(result.success, isTrue,
        reason: result.divergences.map((d) => d.toString()).join('; '));
    expect(result.divergences, isEmpty);
    expect(thermostat2.cell.value, 19);
  });

  test('two REST applies append two rows', () async {
    final f = await SkinFixture.build(graphId: 'scope-two');
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    final (firstStatus, _) = await postJson(http, adapter, '/skin/apply',
        applyBody('home.living.thermostat', 'setTarget', [19]));
    final (secondStatus, _) = await postJson(http, adapter, '/skin/apply',
        applyBody('home.living.thermostat', 'setTarget', [21]));

    expect(firstStatus, HttpStatus.ok);
    expect(secondStatus, HttpStatus.ok);
    expect(await f.ledger.lastSeq, 1);

    CellGraphRegistry.forceReset();
    final thermostat2 = Cell.state<int>(
      initial: 22,
      testRule: ValueGate((v) => v is int && v >= 16 && v <= 26),
    );
    final target = (CellGraph.builder(graphId: 'scope-two')
          ..register('home.living.thermostat', thermostat2.cell))
        .build();
    final result = await ReplayEngine.replay(ledger: f.ledger, target: target);
    expect(result.success, isTrue);
    expect(thermostat2.cell.value, 21);
  });

  test('in-process apply still records once', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final before = await f.ledger.lastSeq;
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [19]));
    expect(await f.ledger.lastSeq, before + 1,
        reason: 'one setTarget is one update: a nested scope would add two');
  });

  test('a rejection appends nothing', () async {
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
    final (status, body) = await postJson(http, adapter, '/skin/apply',
        applyBody('home.front.door', 'lock', const []));
    expect(status, HttpStatus.ok);
    final outcome = (body['outcome'] as Map).cast<String, Object?>();
    expect(outcome['kind'], 'rejected');
    expect(f.door.cell.value, isFalse);
    expect(await f.ledger.lastSeq, before,
        reason: 'a refused lock must leave the ledger head unchanged');
  });

  test('a same-body retry appends nothing', () async {
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
    final body =
        applyBody('home.living.thermostat', 'setTarget', [19], correlationId: 'retry-1');
    final (firstStatus, _) = await postJson(http, adapter, '/skin/apply', body);
    final (secondStatus, _) = await postJson(http, adapter, '/skin/apply', body);

    expect(firstStatus, HttpStatus.ok);
    expect(secondStatus, HttpStatus.ok);
    expect(await f.ledger.lastSeq, before + 1,
        reason: 'the cached acceptance must not append a second row');
  });

  test('a strict cursor sees the REST head', () async {
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding.state(
          cellId: 'home.living.thermostat',
          functionName: 'setTargetStrict',
          target: targets.thermostat.cell,
          nextValue: (int target) => target,
          strictCursor: true,
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

    // Empty ledger head is -1 (the first row is seq 0).
    final (firstStatus, firstBody) = await postJson(
      http,
      adapter,
      '/skin/apply',
      applyBody('home.living.thermostat', 'setTargetStrict', [18],
          lastSeenSeq: -1),
    );
    expect(firstStatus, HttpStatus.ok);
    expect((firstBody['outcome'] as Map)['kind'], 'accepted');
    expect(f.thermostat.cell.value, 18);

    // The REST append moved the head: the same cursor now conflicts.
    final (secondStatus, secondBody) = await postJson(
      http,
      adapter,
      '/skin/apply',
      applyBody('home.living.thermostat', 'setTargetStrict', [17],
          lastSeenSeq: -1),
    );
    expect(secondStatus, HttpStatus.conflict);
    expect(
        ((secondBody['error'] as Map).cast<String, Object?>())['code'],
        'conflict');
    expect(f.thermostat.cell.value, 18);

    // A cursor at the new head proceeds.
    final (thirdStatus, _) = await postJson(
      http,
      adapter,
      '/skin/apply',
      applyBody('home.living.thermostat', 'setTargetStrict', [17],
          lastSeenSeq: 0),
    );
    expect(thirdStatus, HttpStatus.ok);
    expect(f.thermostat.cell.value, 17);
  });

  test('an unledgered membrane does not record and egress stays pending',
      () async {
    CellGraphRegistry.forceReset();
    final thermostat = Cell.state<int>(initial: 22);
    final graph = (CellGraph.builder(graphId: 'scope-unledgered')
          ..register('home.living.thermostat', thermostat.cell))
        .build();
    final bindings = SkinBindingTable()
      ..register(SkinBinding(
        cellId: 'home.living.thermostat',
        functionName: 'setTarget',
        target: thermostat.cell,
        function: (int target) => thermostat.update(target),
      ));
    final sent = <Pulse<WireMessage>>[];
    final membrane = await SkinMembrane.open(
      graph: graph,
      bindings: bindings,
      journal: RecordingJournal(),
      send: sent.add,
    );
    addTearDown(membrane.close);

    final outcome = await SkinClient(membrane: membrane)
        .apply('home.living.thermostat', 'setTarget', positional: [19]);
    expect(outcome, isA<ApplyAccepted<Object?>>());
    expect(thermostat.cell.value, 19);

    final changes = sent
        .where((p) => p.payload is WireStateChange)
        .map((p) => p.payload as WireStateChange)
        .toList();
    expect(changes, isNotEmpty);
    expect(changes.last.pendingReceipt, isTrue,
        reason: 'without a ledger there is no receipt to attach');
  });

  test('a mismatched ledger fails at open', () async {
    CellGraphRegistry.forceReset();
    final thermostat = Cell.state<int>(initial: 22);
    final graph = (CellGraph.builder(graphId: 'scope-mismatch')
          ..register('home.living.thermostat', thermostat.cell))
        .build();
    await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    final otherLedger = await Ledger.open(
      graph: graph,
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    addTearDown(otherLedger.close);

    final bindings = SkinBindingTable()
      ..register(SkinBinding(
        cellId: 'home.living.thermostat',
        functionName: 'setTarget',
        target: thermostat.cell,
        function: (int target) => thermostat.update(target),
      ));
    expect(
      () => SkinMembrane.open(
        graph: graph,
        bindings: bindings,
        ledger: otherLedger,
        journal: RecordingJournal(),
        send: (_) {},
      ),
      throwsStateError,
    );
  });
}
