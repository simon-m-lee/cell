// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// One test per golden error file: every frozen code has a producer.
///
/// This file is the index that fails when a golden code loses its only
/// producer. Existing tests stay; this file re-produces each code once.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'rest_host_cors_test.dart' show rawRequest;
import 'skin_fixture.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('unknown_tool: applying a function that is not bound', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final message = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'notBound',
        correlationId: 'srv-1',
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect((message as WireError).code, 'unknown_tool');
  });

  test('bad_arguments: breaking the declared schema', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final message = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTarget',
        correlationId: 'srv-1',
        positional: {'0': null},
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect((message as WireError).code, 'bad_arguments');
  });

  test('cursor_required: a strictCursor binding without lastSeenSeq',
      () async {
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
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final message = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTargetStrict',
        correlationId: 'srv-1',
        positional: {'0': 20},
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect((message as WireError).code, 'cursor_required');
  });

  test('conflict: strictCursor with lastSeenSeq behind the head', () async {
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
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    // Advance the ledger to head 0.
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [20]));
    expect(await f.ledger.lastSeq, 0);
    // Stale cursor: behind the head.
    final message = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTargetStrict',
        correlationId: 'srv-2',
        positional: {'0': 21},
        lastSeenSeq: -1,
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect((message as WireError).code, 'conflict');
  });

  test('idempotency_conflict: same client id, different body', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final first = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTarget',
        correlationId: 'srv-1',
        clientCorrelationId: 'stable-key',
        positional: {'0': 21},
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect(first, isA<WireResponse>());
    final message = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTarget',
        correlationId: 'srv-2',
        clientCorrelationId: 'stable-key',
        positional: {'0': 22},
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect((message as WireError).code, 'idempotency_conflict');
  });

  test('forbidden: the authorizer returns false', () async {
    var calls = 0;
    final f = await SkinFixture.build(
      authorizer: (principal, binding) async {
        calls++;
        return principal.id != 'mallory';
      },
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final message = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTarget',
        correlationId: 'srv-1',
        positional: {'0': 21},
      ),
      type: SkinPulseTypes.restApplyRequest,
      principal: SkinPrincipal(id: 'mallory'),
    );
    expect((message as WireError).code, 'forbidden');
    expect(calls, 1);
  });

  test('queue_timeout: maxQueueWait passed while the router is held',
      () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var now = DateTime.utc(2026, 11, 24, 12);
    final f = await SkinFixture.build(
      clock: () => now,
      maxQueueWait: const Duration(seconds: 1),
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'block',
          target: targets.thermostat.cell,
          function: () async {
            if (!started.isCompleted) started.complete();
            await release.future;
            return true;
          },
        ),
      ],
    );
    addTearDown(() async {
      if (!release.isCompleted) release.complete();
      await f.membrane.close();
      await f.ledger.close();
    });

    final first = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'srv-1',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    await started.future;

    // Stamp the second request while the clock still reads t0, then
    // advance past its queue deadline before the router can dequeue it
    // (the release happens first, the deadline check happens second).
    final secondFuture = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'srv-2',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    now = now.add(const Duration(seconds: 2));
    release.complete();
    final second = await secondFuture;
    expect((second as WireError).code, 'queue_timeout');
    expect(second.message, isNot(contains('outcome_unknown')));

    expect(await first, isA<WireResponse>());
  });

  test('outcome_unknown: REST requestTimeout shorter than the apply',
      () async {
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'sleepy',
          target: targets.thermostat.cell,
          function: () async {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            return true;
          },
        ),
      ],
    );
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const AllowAllSkinAuth(),
      requestTimeout: const Duration(milliseconds: 50),
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });
    final request = await http.postUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(
        {'cellId': 'home.living.thermostat', 'function': 'sleepy'}));
    final response = await request.close();
    final body = jsonDecode(await response.transform(utf8.decoder).join())
        as Map;
    expect(response.statusCode, HttpStatus.gatewayTimeout);
    expect(((body['error'] as Map)['code']), 'outcome_unknown');
  });

  test('queue_full: maxQueued 1 while one apply is blocked', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final f = await SkinFixture.build(
      maxQueued: 1,
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'block',
          target: targets.thermostat.cell,
          function: () async {
            if (!started.isCompleted) started.complete();
            await release.future;
            return true;
          },
        ),
      ],
    );
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      if (!release.isCompleted) release.complete();
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    Future<HttpClientResponse> post() async {
      final request = await http.postUrl(
          Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(
          {'cellId': 'home.living.thermostat', 'function': 'block'}));
      return request.close();
    }

    final first = post();
    await started.future;
    final second = await post();
    final body = jsonDecode(await second.transform(utf8.decoder).join())
        as Map;
    expect(second.statusCode, HttpStatus.tooManyRequests);
    expect(((body['error'] as Map)['code']), 'queue_full');

    release.complete();
    expect((await first).statusCode, HttpStatus.ok);
  });

  test('verify_failed: the tampered-store shape; status stays 500',
      () async {
    final store = _TamperedStore('tampered-table');
    final f =
        await SkinFixture.build(graphId: 'tampered-table', ledgerStore: store);
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
    });

    // One real row, then tamper with what the store yields.
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [19]));
    store.tampered = true;
    final request = await http.postUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/verify'));
    final response = await request.close();
    final body = jsonDecode(await response.transform(utf8.decoder).join())
        as Map;
    expect(response.statusCode, HttpStatus.internalServerError);
    expect(body['ok'], false);
    expect(body['code'], 'verify_failed');
  });

  test('host_not_allowed: a foreign Host', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);
    final result = await rawRequest(
      adapter.port,
      path: '/ready',
      headers: const {'Host': 'evil.example'},
    );
    final (status, _, body) = result;
    expect(status, contains("403 Forbidden"));
    expect(jsonDecode(body), {
      'error': {'code': 'host_not_allowed'}
    });
  });

  test('origin_not_allowed: an Origin not in the allow list', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const AllowAllSkinAuth(),
      allowedOrigins: const {'http://app.example'},
    );
    addTearDown(adapter.close);
    final result = await rawRequest(
      adapter.port,
      path: '/ready',
      headers: const {'Host': '127.0.0.1', 'Origin': 'http://evil.example'},
    );
    final (status, _, body) = result;
    expect(status, contains("403 Forbidden"));
    expect(jsonDecode(body), {
      'error': {'code': 'origin_not_allowed'}
    });
  });

  test('transport_error: a binding that throws', () async {
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'explodes',
          target: targets.thermostat.cell,
          function: () async => throw StateError('boom'),
        ),
      ],
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final message = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'explodes',
        correlationId: 'srv-1',
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect((message as WireError).code, 'transport_error');
  });
}

/// A store whose `entriesSince` yields a corrupted row, so verify fails.
final class _TamperedStore implements LedgerStore {
  final InMemoryLedgerStore inner;
  bool tampered = false;

  _TamperedStore(String graphId)
      : inner = InMemoryLedgerStore(genesisHash: Ledger.genesisHashOf(graphId));

  @override
  String get genesisHash => inner.genesisHash;

  @override
  Future<void> append(LedgerEntry entry) => inner.append(entry);

  @override
  Future<int> get lastSeq => inner.lastSeq;

  @override
  Future<String?> get lastHash => inner.lastHash;

  @override
  Stream<LedgerEntry> entriesSince(int fromSeq) async* {
    await for (final entry in inner.entriesSince(fromSeq)) {
      if (tampered) {
        yield LedgerEntry.fromJson({
          ...entry.toJson(),
          'hash': '0' * 64,
        });
      } else {
        yield entry;
      }
    }
  }

  @override
  Future<void> close() => inner.close();
}
