// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The durable idempotency store: one process survives a restart.
///
/// A completed line replays after a second store opens on the same
/// directory; an in-flight lease owns the key until it expires; the
/// TTL boundary is the memory store's `!isBefore`; and a strict-receipt
/// failure persists its `errorCode` so the replay is the same
/// `transport_error`, never a fake success.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell/replay.dart' show FileLedgerStore;
import 'package:cell_skin/cell_skin.dart';
import 'package:cell_skin/cell_skin_io.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'ledger_sse_test.dart' show readSse;
import 'skin_fixture.dart';

final class _FixedAuth implements SkinAuth {
  final SkinPrincipal principal;
  const _FixedAuth(this.principal);

  @override
  Future<SkinPrincipal?> authenticate(SkinCredentials credentials) async =>
      principal;
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  late Directory dir;
  var now = DateTime(2026, 1, 1);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cell-skin-idem-');
    now = DateTime(2026, 1, 1);
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
  });

  DateTime clock() => now;

  Future<FileIdempotencyStore> openStore() =>
      FileIdempotencyStore.open(directory: dir.path, clock: clock);

  test('a completed record replays after a second store opens', () async {
    final store1 = await openStore();
    final record = IdempotencyRecord(
      fingerprint: 'f',
      responseType: SkinPulseTypes.restApplyResponsePrefix,
      outcomeJson: const {'kind': 'accepted', 'receipt': <String, Object?>{}},
      storedAt: now,
    );
    await store1.claim('k');
    await store1.complete('k', record);

    final store2 = await openStore();
    final claim = await store2.claim('k');
    expect(claim, isA<IdempotencyReplay>());
    final replay = (claim as IdempotencyReplay).record;
    expect(replay.fingerprint, 'f');
  });

  test('a replayed record does not call the function or move the ledger',
      () async {
    // First membrane: one real apply completes a file line.
    final f1 = await SkinFixture.build(
      graphId: 'replay-home',
      idempotency: await openStore(),
    );
    WireRequest body() => WireRequest(
          cellId: 'home.living.thermostat',
          function: 'setTarget',
          correlationId: 'srv-1',
          clientCorrelationId: 'stable-key',
          positional: {'0': 21},
        );
    final first = await f1.membrane.request(body(),
        type: SkinPulseTypes.restApplyRequest);
    expect(first, isA<WireResponse>());
    await f1.membrane.close();
    await f1.ledger.close();

    // Restart shape: a fresh graph and membrane, the same directory.
    final f2 = await SkinFixture.build(
      graphId: 'replay-home',
      idempotency: await openStore(),
    );
    addTearDown(() async {
      await f2.membrane.close();
      await f2.ledger.close();
    });
    final second = await f2.membrane.request(
      body(),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect(second, isA<WireResponse>());
    expect((second as WireResponse).outcome, isNull,
        reason: 'the file store has no liveOutcome');
    expect(f2.thermostat.cell.value, 22, reason: 'the function did not run');
    expect(await f2.ledger.lastSeq, -1, reason: 'lastSeq did not move');
  });

  test('the same key with a different body is a conflict, log unchanged',
      () async {
    final f1 = await SkinFixture.build(
      graphId: 'conflict-home',
      idempotency: await openStore(),
    );
    WireRequest request(int target) => WireRequest(
          cellId: 'home.living.thermostat',
          function: 'setTarget',
          correlationId: 'srv-1',
          clientCorrelationId: 'stable-key',
          positional: {'0': target},
        );
    await f1.membrane.request(request(21),
        type: SkinPulseTypes.restApplyRequest);
    await f1.membrane.close();
    await f1.ledger.close();
    final logBefore =
        await File('${dir.path}${Platform.pathSeparator}log').readAsString();

    final f2 = await SkinFixture.build(
      graphId: 'conflict-home',
      idempotency: await openStore(),
    );
    addTearDown(() async {
      await f2.membrane.close();
      await f2.ledger.close();
    });
    final second = await f2.membrane.request(request(20),
        type: SkinPulseTypes.restApplyRequest);
    expect(second, isA<WireError>());
    expect((second as WireError).code, 'idempotency_conflict');
    expect(f2.thermostat.cell.value, 22);
    expect(await f2.ledger.lastSeq, -1);

    final logAfter =
        await File('${dir.path}${Platform.pathSeparator}log').readAsString();
    expect(logAfter, logBefore, reason: 'the conflict never rewrites the log');
  });

  test('an expired in-flight lease is taken by the next store', () async {
    final store1 = await openStore();
    expect(await store1.claim('k'), isA<IdempotencyOwned>());

    now = now.add(const Duration(minutes: 2, seconds: 1));
    final store2 = await openStore();
    expect(await store2.claim('k'), isA<IdempotencyOwned>());
  });

  test('a live in-flight lease waits within one store', () async {
    final store = await openStore();
    expect(await store.claim('k'), isA<IdempotencyOwned>());
    final waiting = await store.claim('k');
    expect(waiting, isA<IdempotencyWait>());
    await store.abort('k');
    expect(await (waiting as IdempotencyWait).settled, isNull);
  });

  test('the TTL boundary is the memory rule: 59 minutes replays, 60 gone',
      () async {
    final store1 = await openStore();
    await store1.claim('k');
    await store1.complete(
      'k',
      IdempotencyRecord(
        fingerprint: 'f',
        responseType: SkinPulseTypes.restApplyResponsePrefix,
        outcomeJson: const <String, Object?>{},
        storedAt: now,
      ),
    );

    now = now.add(const Duration(minutes: 59));
    final at59 = await FileIdempotencyStore.open(
        directory: dir.path, clock: clock, ttl: const Duration(hours: 1));
    expect(await at59.claim('k'), isA<IdempotencyReplay>());

    now = now.add(const Duration(minutes: 1));
    final at60 = await FileIdempotencyStore.open(
        directory: dir.path, clock: clock, ttl: const Duration(hours: 1));
    expect(await at60.claim('k'), isA<IdempotencyOwned>(),
        reason: '!isBefore is the expiry boundary');
  });

  test('a strict-receipt failure persists its errorCode across a restart',
      () async {
    var calls = 0;
    final f1 = await SkinFixture.build(
      graphId: 'strict-home',
      idempotency: await openStore(),
      extraBindings: (targets) => [
        SkinBinding.state(
          cellId: 'home.living.thermostat',
          functionName: 'doubleWrite',
          target: targets.thermostat.cell,
          nextValue: (int v) {
            calls++;
            targets.thermostat.update(v - 1);
            return v;
          },
        ),
      ],
    );
    WireRequest request() => WireRequest(
          cellId: 'home.living.thermostat',
          function: 'doubleWrite',
          correlationId: 'srv-1',
          clientCorrelationId: 'strict-key',
          positional: {'0': 21},
        );
    final first = await f1.membrane.request(request(),
        type: SkinPulseTypes.restApplyRequest);
    expect(first, isA<WireError>());
    expect((first as WireError).code, 'transport_error');
    expect(calls, 1);
    await f1.membrane.close();
    await f1.ledger.close();

    final log =
        await File('${dir.path}${Platform.pathSeparator}log').readAsString();
    expect(log, contains('errorCode'));
    expect(log, contains('transport_error'));

    final f2 = await SkinFixture.build(
      graphId: 'strict-home',
      idempotency: await openStore(),
      extraBindings: (targets) => [
        SkinBinding.state(
          cellId: 'home.living.thermostat',
          functionName: 'doubleWrite',
          target: targets.thermostat.cell,
          nextValue: (int v) {
            calls++;
            targets.thermostat.update(v - 1);
            return v;
          },
        ),
      ],
    );
    addTearDown(() async {
      await f2.membrane.close();
      await f2.ledger.close();
    });
    final second = await f2.membrane.request(request(),
        type: SkinPulseTypes.restApplyRequest);
    expect(second, isA<WireError>());
    expect((second as WireError).code, 'transport_error');
    expect(second.message, first.message,
        reason: 'the stored failure replays verbatim');
    expect(calls, 1, reason: 'the retry never runs the binding');
  });

  test('a restart against the same ledger file replays the stored seq',
      () async {
    const graphId = 'restart-ledger';
    final ledgerPath = '${dir.path}${Platform.pathSeparator}ledger.jsonl';
    final f1 = await SkinFixture.build(
      graphId: graphId,
      ledgerStore: await FileLedgerStore.open(ledgerPath,
          genesisHash: Ledger.genesisHashOf(graphId)),
      idempotency: await openStore(),
    );
    WireRequest request(String serverId) => WireRequest(
          cellId: 'home.living.thermostat',
          function: 'setTarget',
          correlationId: serverId,
          clientCorrelationId: 'stable-key',
          positional: {'0': 21},
        );
    final first = await f1.membrane.request(
      request('srv-1'),
      type: SkinPulseTypes.restApplyRequest,
      principal: SkinPrincipal(id: 'untrusted'),
    );
    expect(first, isA<WireResponse>());
    expect(await f1.ledger.lastSeq, 0);
    await f1.membrane.close();
    await f1.ledger.close();

    // The restart: a new graph on the same ledger file and a new file
    // store on the same directory.
    final f2 = await SkinFixture.build(
      graphId: graphId,
      ledgerStore: await FileLedgerStore.open(ledgerPath,
          genesisHash: Ledger.genesisHashOf(graphId)),
      idempotency: await openStore(),
    );
    addTearDown(() async {
      await f2.membrane.close();
      await f2.ledger.close();
    });
    final second = await f2.membrane.request(
      request('srv-2'),
      type: SkinPulseTypes.restApplyRequest,
      principal: SkinPrincipal(id: 'untrusted'),
    );
    expect(second, isA<WireResponse>());
    final response = second as WireResponse;
    expect(response.outcome, isNull);
    expect(
      (response.outcomeJson!.receipt)['ledgerSeq'],
      0,
      reason: 'the seq the first apply wrote',
    );
    expect(await f2.ledger.lastSeq, 0, reason: 'the retry did not append');

    // One HTTP POST of the same retry also returns the stored seq. The
    // store key is actor-scoped: the in-process applies ran under
    // `skin:untrusted`, so the auth returns a principal with that id.
    final adapter = await RestAdapter.bind(
      membrane: f2.membrane,
      auth: const _FixedAuth(SkinPrincipal(id: 'untrusted')),
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
    });
    final post = await http.postUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
    post.headers.contentType = ContentType.json;
    post.write(jsonEncode({
      'cellId': 'home.living.thermostat',
      'function': 'setTarget',
      'positional': {'0': 21},
      'correlationId': 'stable-key',
    }));
    final postResponse = await post.close();
    final postBody = (jsonDecode(await postResponse.transform(utf8.decoder).join())
        as Map)
        .cast<String, Object?>();
    expect(postResponse.statusCode, HttpStatus.ok);
    final outcome = (postBody['outcome'] as Map).cast<String, Object?>();
    expect(((outcome['receipt'] as Map).cast<String, Object?>())['ledgerSeq'], 0);
  });

  test('the ledger SSE reopens from a file and honors Last-Event-ID', () async {
    const graphId = 'restart-sse';
    final ledgerPath = '${dir.path}${Platform.pathSeparator}ledger.jsonl';
    final f1 = await SkinFixture.build(
      graphId: graphId,
      ledgerStore: await FileLedgerStore.open(ledgerPath,
          genesisHash: Ledger.genesisHashOf(graphId)),
    );
    await f1.run(() => f1.client
        .apply('home.living.thermostat', 'setTarget', positional: [21]));
    await f1.run(() => f1.client
        .apply('home.living.thermostat', 'setTarget', positional: [20]));
    expect(await f1.ledger.lastSeq, 1);
    await f1.membrane.close();
    await f1.ledger.close();

    final f2 = await SkinFixture.build(
      graphId: graphId,
      ledgerStore: await FileLedgerStore.open(ledgerPath,
          genesisHash: Ledger.genesisHashOf(graphId)),
    );
    addTearDown(() async {
      await f2.membrane.close();
      await f2.ledger.close();
    });
    final adapter = await RestAdapter.bind(
        membrane: f2.membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
    });

    final request = await http.getUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/ledger'));
    request.headers.set('Last-Event-ID', '0');
    final response = await request.close();
    final frames = await readSse(response);
    expect(frames.map((f) => f.id), contains('1'));
    
    expect(frames.map((f) => f.id), isNot(contains('0')),
        reason: 'the header is exclusive');
  });
}
