// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Regression tests for the external code-review findings: correlation
/// ids must be unique across clients, a post-commit strict-receipt
/// violation must never apply twice, `named: {}` must behave like
/// omitted, the authorizer stays command-only, close gates the router,
/// and the idempotency store sweeps expired rows.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('correlation ids are unique across many mints', () {
    final ids = <String>{};
    for (var i = 0; i < 10000; i++) {
      ids.add(nextCorrelationId('skin'));
    }
    expect(ids, hasLength(10000));
  });

  test('two clients in the same microsecond keep their own results',
      () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final clientA = SkinClient(membrane: f.membrane);
    final clientB = SkinClient(membrane: f.membrane);

    final results = await Future.wait([
      clientA.apply('home.living.thermostat', 'setTarget',
          positional: [21]),
      clientB.apply('home.living.light', 'dim', positional: [0.5]),
    ]);
    final target = results[0]! as ApplyAccepted<Object?>;
    expect(target.result, isA<Pulse<Object?>>());
    expect(f.thermostat.cell.value, 21);
    expect(f.light.cell.value, 0.5);
  });

  test('an empty correlation id is replaced and never shared', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    Future<WireResponse> call(int target) async {
      final message = await f.membrane.request(
        WireRequest(
          cellId: 'home.living.thermostat',
          function: 'setTarget',
          correlationId: '',
          positional: {'0': target},
        ),
        type: SkinPulseTypes.restApplyRequest,
      );
      return message as WireResponse;
    }

    final first = await call(21);
    final second = await call(20);
    expect(first.correlationId, isNotEmpty);
    expect(second.correlationId, isNotEmpty);
    expect(first.correlationId, isNot(second.correlationId));
    expect(f.thermostat.cell.value, 20, reason: 'both calls applied');
  });

  test('a post-commit strict-receipt violation never applies twice',
      () async {
    var calls = 0;
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding.state(
          cellId: 'home.living.thermostat',
          functionName: 'doubleWrite',
          target: targets.thermostat.cell,
          nextValue: (int v) {
            calls++;
            // A synthetic row: the contract break the strict check finds
            // after the row was committed.
            targets.thermostat.update(v - 1);
            return v;
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
          function: 'doubleWrite',
          correlationId: 'srv-x',
          clientCorrelationId: 'stable-key',
          positional: {'0': 21},
        );

    final first = await f.membrane.request(
      request(),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect(first, isA<WireError>());
    final firstError = first as WireError;
    expect(firstError.code, 'transport_error');
    expect(calls, 1);
    final valueAfterFirst = f.thermostat.cell.value;

    final second = await f.membrane.request(
      request(),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect(second, isA<WireError>());
    final secondError = second as WireError;
    expect(secondError.code, 'transport_error');
    expect(secondError.message, firstError.message,
        reason: 'the stored failure replays verbatim');
    expect(calls, 1, reason: 'the retry must not run the binding again');
    expect(f.thermostat.cell.value, valueAfterFirst);
  });

  test('named: {} behaves like omitted named on a state binding', () async {
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

    Future<(int, Map<String, Object?>)> post(Map<String, Object?> body) async {
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

    final (status, body) = await post({
      'cellId': 'home.living.thermostat',
      'function': 'setTarget',
      'positional': {'0': 21},
      'named': <String, Object?>{},
    });
    expect(status, HttpStatus.ok, reason: '$body');
    expect((body['outcome'] as Map)['kind'], 'accepted');
    expect(f.thermostat.cell.value, 21);
  });

  test('non-empty named on a state binding is bad_arguments', () async {
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

    final request = await http.postUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({
      'cellId': 'home.living.thermostat',
      'function': 'setTarget',
      'named': {'target': 21},
    }));
    final response = await request.close();
    final body = (jsonDecode(await response.transform(utf8.decoder).join())
        as Map);
    expect(response.statusCode, HttpStatus.unprocessableEntity);
    expect((body['error'] as Map)['code'], 'bad_arguments');
    expect(f.thermostat.cell.value, 22, reason: 'the function never ran');
  });

  test('the authorizer stays command-only: reads are auth-gated', () async {
    final f = await SkinFixture.build(
      authorizer: (principal, binding) async => false,
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

    final manifest = await http.getUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/manifest'));
    final manifestResponse = await manifest.close();
    expect(manifestResponse.statusCode, HttpStatus.ok,
        reason: 'manifest is a read; the hook decides applies only');
  });

  test('close gates the router: a queued request never applies', () async {
    var calls = 0;
    final started = Completer<void>();
    final release = Completer<void>();
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'block',
          target: targets.thermostat.cell,
          function: () async {
            calls++;
            if (!started.isCompleted) started.complete();
            await release.future;
            return true;
          },
        ),
      ],
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final first = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'srv-first',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    await started.future;

    final second = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'srv-second',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );

    // Attach the expectations before close() fails the waiters, so the
    // errors are observed, not unhandled.
    final firstFailed = expectLater(first, throwsA(isA<SkinError>()));
    final secondFailed = expectLater(second, throwsA(isA<SkinError>()));

    // Close while the second request is queued: both waiters fail, the
    // router is gated, and the queued request must not start.
    await f.membrane.close();
    release.complete();
    await firstFailed;
    await secondFailed;
    expect(calls, 1, reason: 'only the in-flight apply ran');
  });

  test('expired idempotency records are swept, not only on touch', () async {
    var now = DateTime(2026, 1, 1);
    final store = MemoryIdempotencyStore(
      maxEntries: 2,
      ttl: const Duration(hours: 1),
      clock: () => now,
    );

    IdempotencyRecord record() => IdempotencyRecord(
          fingerprint: 'f',
          responseType: SkinPulseTypes.restApplyResponsePrefix,
          outcomeJson: const {},
          storedAt: now,
        );

    await store.claim('k1');
    await store.complete('k1', record());

    // k1 expires; completing k2 sweeps every expired record, not just
    // the key being written.
    now = now.add(const Duration(hours: 2));
    await store.claim('k2');
    await store.complete('k2', record());

    // Move the clock back below k1's expiry: k1 was swept away, so it
    // is gone for good — a touch-only expiry would still find it and
    // replay.
    now = now.subtract(const Duration(hours: 1, minutes: 30));
    expect(await store.claim('k1'), isA<IdempotencyOwned>(),
        reason: 'the sweep removed k1 while it was expired');
    expect(await store.claim('k2'), isA<IdempotencyReplay>());
  });

  test('a 405 carries the Allow header', () async {
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

    final request = await http.postUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/manifest'));
    final response = await request.close();
    expect(response.statusCode, HttpStatus.methodNotAllowed);
    expect(response.headers.value('Allow'), 'GET, OPTIONS');
  });

  test('a durable-store replay with only outcomeJson is an honest error',
      () {
    expect(
      () => SkinClient.outcomeOf(const WireResponse(
        correlationId: 'c',
        outcomeJson: WireOutcome(kind: 'accepted', receipt: {}),
      )),
      throwsA(isA<SkinError>().having(
        (e) => e.code,
        'code',
        'outcome_json_only',
      )),
    );
    expect(
      SkinClient.outcomeOf(const WireResponse(
        correlationId: 'c',
        pendingReceipt: true,
      )),
      isNull,
    );
  });

  test('a principal snapshot with non-string claim keys does not throw', () {
    final context = PulseContext(
      actor: 'skin:alice',
      others: {
        'skin.principal': {
          'id': 'alice',
          'roles': ['operator'],
          'claims': {
            1: 'dropped',
            'ok': true,
          },
        },
      },
    );
    final principal = principalFrom(context);
    expect(principal, isNotNull);
    expect(principal!.id, 'alice');
    expect(principal.claims, {'ok': true});
  });
}
