// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Idempotency through the router.
///
/// The same client id replays the same attempt and nothing else; a
/// different body is `idempotency_conflict` (409) and does not apply.
/// Domain rejections, cursor conflicts, and other failures are not
/// stored, so a retry after the situation changes is a new apply.
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
    Map<String, Object?> body,
  ) async {
    final request = await http.postUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
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
    int? lastSeenSeq,
  }) =>
      {
        'cellId': cellId,
        'function': function,
        if (positional.isNotEmpty)
          'positional': {
            for (var i = 0; i < positional.length; i++) '$i': positional[i],
          },
        if (correlationId != null) 'correlationId': correlationId,
        if (lastSeenSeq != null) 'lastSeenSeq': lastSeenSeq,
      };

  test('the same body replays with the current server id', () async {
    var calls = 0;
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'countOnce',
          target: targets.thermostat.cell,
          function: () {
            calls++;
            return true;
          },
        ),
      ],
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final before = await f.ledger.lastSeq;

    final first = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'countOnce',
        correlationId: 'srv-1',
        clientCorrelationId: 'k',
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    final second = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'countOnce',
        correlationId: 'srv-2',
        clientCorrelationId: 'k',
      ),
      type: SkinPulseTypes.restApplyRequest,
    );

    expect(first, isA<WireResponse>());
    expect(second, isA<WireResponse>());
    expect(calls, 1);
    expect((second as WireResponse).correlationId, 'srv-2',
        reason: 'the replay carries the retry\'s own server id');
    expect(await f.ledger.lastSeq, before,
        reason: 'a replay never appends a ledger row');
  });

  test('a reused client id with a different body is 409 and does not apply',
      () async {
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

    final (firstStatus, _) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'setTarget', [19],
          correlationId: 'same-key'),
    );
    final (secondStatus, secondBody) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'setTarget', [21],
          correlationId: 'same-key'),
    );

    expect(firstStatus, HttpStatus.ok);
    expect(secondStatus, HttpStatus.conflict);
    expect(
        ((secondBody['error'] as Map).cast<String, Object?>())['code'],
        'idempotency_conflict');
    expect(f.thermostat.cell.value, 19);

    // The original body still replays; the different body conflicts again.
    final (thirdStatus, _) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'setTarget', [19],
          correlationId: 'same-key'),
    );
    expect(thirdStatus, HttpStatus.ok);
    final (fourthStatus, _) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'setTarget', [21],
          correlationId: 'same-key'),
    );
    expect(fourthStatus, HttpStatus.conflict);
    expect(await f.ledger.lastSeq, 0, reason: 'exactly one row was written');
  });

  test('a different cell under the same client id is 409', () async {
    var calls = 0;
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'countOnce',
          target: targets.thermostat.cell,
          function: () {
            calls++;
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

    final (firstStatus, _) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'countOnce', const [],
          correlationId: 'same-key'),
    );
    final (secondStatus, secondBody) = await postJson(
      http,
      adapter,
      applyBody('home.front.door', 'lock', const [],
          correlationId: 'same-key'),
    );

    expect(firstStatus, HttpStatus.ok);
    expect(secondStatus, HttpStatus.conflict);
    expect(
        ((secondBody['error'] as Map).cast<String, Object?>())['code'],
        'idempotency_conflict');
    expect(calls, 1, reason: 'lock never ran — the id collision refused it');
    expect(f.door.cell.value, isFalse);
  });

  test('a domain rejection is not sticky', () async {
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

    final (firstStatus, firstBody) = await postJson(
      http,
      adapter,
      applyBody('home.front.door', 'lock', const [],
          correlationId: 'lock-1'),
    );
    expect(firstStatus, HttpStatus.ok);
    expect((firstBody['outcome'] as Map)['kind'], 'rejected');
    expect(f.door.cell.value, isFalse);

    f.doorGate.occupantHome = false;
    final (secondStatus, secondBody) = await postJson(
      http,
      adapter,
      applyBody('home.front.door', 'lock', const [],
          correlationId: 'lock-1'),
    );
    expect(secondStatus, HttpStatus.ok);
    expect((secondBody['outcome'] as Map)['kind'], 'accepted');
    expect(f.door.cell.value, isTrue,
        reason: 'the rejection was not cached — the retry reached the gate');
  });

  test('a cursor miss is not sticky', () async {
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

    // The first call uses only a server id: it stores a record under
    // that server key, which nothing retries.
    final (firstStatus, _) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'setTargetStrict', [18],
          lastSeenSeq: -1),
    );
    expect(firstStatus, HttpStatus.ok);

    // Same client id, same cursor: the cursor moved (head 0), so this is
    // a plain cursor conflict — and it is not stored.
    final (secondStatus, secondBody) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'setTargetStrict', [18],
          correlationId: 'cursor-1', lastSeenSeq: -1),
    );
    expect(secondStatus, HttpStatus.conflict);
    expect(
        ((secondBody['error'] as Map).cast<String, Object?>())['code'],
        'conflict');

    final (thirdStatus, _) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'setTargetStrict', [17],
          correlationId: 'cursor-1', lastSeenSeq: 0),
    );
    expect(thirdStatus, HttpStatus.ok,
        reason: 'the conflict was not stored — the fresh cursor ran');
    expect(f.thermostat.cell.value, 17);
  });

  test('different actors do not share keys', () async {
    var calls = 0;
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'countOnce',
          target: targets.thermostat.cell,
          function: () {
            calls++;
            return true;
          },
        ),
      ],
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    WireRequest request(String correlationId) => WireRequest(
          cellId: 'home.living.thermostat',
          function: 'countOnce',
          correlationId: correlationId,
          clientCorrelationId: 'k',
        );

    await f.membrane.request(
      request('srv-a'),
      type: SkinPulseTypes.restApplyRequest,
      context: PulseContext(actor: 'skin:alice'),
    );
    await f.membrane.request(
      request('srv-b'),
      type: SkinPulseTypes.restApplyRequest,
      context: PulseContext(actor: 'skin:bob'),
    );
    expect(calls, 2, reason: 'the same client id under two actors runs twice');
  });

  test('an immediate retry waits for the in-flight attempt', () async {
    var calls = 0;
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'slowOnce',
          target: targets.thermostat.cell,
          function: () async {
            calls++;
            await Future<void>.delayed(const Duration(milliseconds: 300));
            return true;
          },
        ),
      ],
    );
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const AllowAllSkinAuth(),
      requestTimeout: const Duration(seconds: 2),
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    final body = applyBody('home.living.thermostat', 'slowOnce', const [],
        correlationId: 'retry-key');
    final firstFuture = postJson(http, adapter, body);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final (firstStatus, _) = await firstFuture;
    final (secondStatus, _) = await postJson(http, adapter, body);

    expect(firstStatus, HttpStatus.ok);
    expect(secondStatus, HttpStatus.ok);
    expect(calls, 1,
        reason: 'the second call waited for the first attempt and replayed it');
  });

  test('a record past its ttl runs again', () async {
    var calls = 0;
    var now = DateTime(2026, 1, 1);
    final store = MemoryIdempotencyStore(
      ttl: const Duration(hours: 1),
      clock: () => now,
    );
    final f = await SkinFixture.build(
      idempotency: store,
      clock: () => now,
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'countOnce',
          target: targets.thermostat.cell,
          function: () {
            calls++;
            return true;
          },
        ),
      ],
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    WireRequest request() => WireRequest(
          cellId: 'home.living.thermostat',
          function: 'countOnce',
          correlationId: 'srv-${calls + 1}',
          clientCorrelationId: 'ttl-key',
        );

    await f.membrane.request(request(),
        type: SkinPulseTypes.restApplyRequest);
    expect(calls, 1);

    now = now.add(const Duration(hours: 2));
    await f.membrane.request(request(),
        type: SkinPulseTypes.restApplyRequest);
    expect(calls, 2, reason: 'the expired record was claimed anew');
  });

  test('the store cap evicts the oldest completed record', () async {
    var calls = 0;
    final store = MemoryIdempotencyStore(maxEntries: 2);
    final f = await SkinFixture.build(
      idempotency: store,
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'countOnce',
          target: targets.thermostat.cell,
          function: () {
            calls++;
            return true;
          },
        ),
      ],
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    Future<void> send(String clientId, String serverId) =>
        f.membrane.request(
          WireRequest(
            cellId: 'home.living.thermostat',
            function: 'countOnce',
            correlationId: serverId,
            clientCorrelationId: clientId,
          ),
          type: SkinPulseTypes.restApplyRequest,
        );

    await send('a', 'srv-a');
    await send('b', 'srv-b');
    await send('c', 'srv-c');
    expect(calls, 3);

    // 'a' was the oldest completed record and has been evicted.
    await send('a', 'srv-a2');
    expect(calls, 4, reason: 'the evicted key runs again');

    // 'c' is still stored and replays.
    await send('c', 'srv-c2');
    expect(calls, 4);
  });
}
