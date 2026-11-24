// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The router queue stays serial, and a request that outlives its
/// queue budget never starts.
///
/// `maxQueueWait` stamps a deadline on every request; a request that is
/// still queued when the deadline passes is `queue_timeout` (HTTP 504)
/// and does not run. `Duration.zero` disables the limit. An apply that
/// already started is never cancelled — the handler timeout stays
/// `outcome_unknown`.
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

  Future<SkinFixture> fixtureWith(
    List<SkinBinding> Function(SkinFixtureTargets targets) extra, {
    Duration maxQueueWait = const Duration(seconds: 30),
  }) =>
      SkinFixture.build(
        extraBindings: extra,
        maxQueueWait: maxQueueWait,
      );

  test('a request whose deadline passed does not apply', () async {
    var calls = 0;
    final f = await fixtureWith((targets) => [
          SkinBinding(
            cellId: 'home.living.thermostat',
            functionName: 'countOnce',
            target: targets.thermostat.cell,
            function: () {
              calls++;
              return true;
            },
          ),
        ]);
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final before = await f.ledger.lastSeq;
    final message = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'countOnce',
        correlationId: 'c-past',
      ),
      type: SkinPulseTypes.restApplyRequest,
      deadline: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    expect(message, isA<WireError>());
    expect((message as WireError).code, 'queue_timeout');
    expect(calls, 0);
    expect(await f.ledger.lastSeq, before);
  });

  test('a request whose deadline is in the future applies', () async {
    var calls = 0;
    final f = await fixtureWith((targets) => [
          SkinBinding(
            cellId: 'home.living.thermostat',
            functionName: 'countOnce',
            target: targets.thermostat.cell,
            function: () {
              calls++;
              return true;
            },
          ),
        ]);
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final message = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'countOnce',
        correlationId: 'c-future',
      ),
      type: SkinPulseTypes.restApplyRequest,
      deadline: DateTime.now().add(const Duration(minutes: 1)),
    );
    expect(message, isA<WireResponse>());
    expect(calls, 1);
  });

  test('maxQueueWait zero disables the queue limit', () async {
    var calls = 0;
    final started = Completer<void>();
    final release = Completer<void>();
    final f = await fixtureWith(
      (targets) => [
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
      maxQueueWait: Duration.zero,
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final first = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'c-first',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    await started.future;

    final second = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'c-second',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    release.complete();

    expect(await first, isA<WireResponse>());
    expect(await second, isA<WireResponse>());
    expect(calls, 2);
  });

  test('the waiter behind a slow command is refused and does not run',
      () async {
    var calls = 0;
    final started = Completer<void>();
    final release = Completer<void>();
    final f = await fixtureWith(
      (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'block',
          target: targets.thermostat.cell,
          function: () async {
            calls++;
            started.complete();
            await release.future;
            return true;
          },
        ),
      ],
      maxQueueWait: const Duration(milliseconds: 20),
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final first = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'c-slow',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    await started.future;

    final secondFuture = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'c-waiter',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    // The waiter is queued behind the slow command; release it and let
    // the router refuse the waiter when its budget has expired.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    release.complete();
    expect(await first, isA<WireResponse>());

    final second = await secondFuture;
    expect(second, isA<WireError>());
    expect((second as WireError).code, 'queue_timeout');
    expect(calls, 1, reason: 'the waiter never started');
  });

  test('a stored outcome still replays past its deadline', () async {
    var countCalls = 0;
    var slowCalls = 0;
    final started = Completer<void>();
    final release = Completer<void>();
    final f = await fixtureWith((targets) => [
          SkinBinding(
            cellId: 'home.living.thermostat',
            functionName: 'countOnce',
            target: targets.thermostat.cell,
            function: () {
              countCalls++;
              return true;
            },
          ),
          SkinBinding(
            cellId: 'home.living.thermostat',
            functionName: 'block',
            target: targets.thermostat.cell,
            function: () async {
              slowCalls++;
              started.complete();
              await release.future;
              return true;
            },
          ),
        ]);
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    // Store a completed outcome under the client id.
    await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'countOnce',
        correlationId: 'srv-1',
        clientCorrelationId: 'k',
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect(countCalls, 1);

    // Block the router and enqueue a same-id replay whose deadline is
    // already past: the idempotency hit wins over the deadline.
    final slow = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'srv-slow',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    await started.future;

    final replayFuture = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'countOnce',
        correlationId: 'srv-2',
        clientCorrelationId: 'k',
      ),
      type: SkinPulseTypes.restApplyRequest,
      deadline: DateTime.now().subtract(const Duration(seconds: 1)),
      timeout: const Duration(seconds: 5),
    );

    release.complete();
    await slow;
    final replay = await replayFuture;

    expect(replay, isA<WireResponse>());
    expect((replay as WireResponse).correlationId, 'srv-2');
    expect(countCalls, 1, reason: 'the replay did not run the function');
    expect(slowCalls, 1);
  });

  test('a queue refusal is not sticky', () async {
    var calls = 0;
    final started = Completer<void>();
    final release = Completer<void>();
    final f = await fixtureWith(
      (targets) => [
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
      maxQueueWait: const Duration(milliseconds: 20),
    );
    addTearDown(() async {
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

    final refusedFuture = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'srv-2',
        clientCorrelationId: 'same-key',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );

    // The queued request's 20ms budget expires while it waits.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    release.complete();
    await first;
    final refused = await refusedFuture;
    expect((refused as WireError).code, 'queue_timeout');

    // The refused attempt was aborted, not stored: a later attempt with
    // the same client id runs.
    final later = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'srv-3',
        clientCorrelationId: 'same-key',
      ),
      type: SkinPulseTypes.restApplyRequest,
      deadline: DateTime.now().add(const Duration(minutes: 1)),
      timeout: const Duration(seconds: 5),
    );
    expect(later, isA<WireResponse>());
    expect(calls, 2);
  });

  test('dispatch is serial: routerInFlight never exceeds one', () async {
    var inFlight = 0;
    var maxInFlight = 0;
    final gate = Completer<void>();
    final f = await fixtureWith((targets) => [
          SkinBinding(
            cellId: 'home.living.thermostat',
            functionName: 'block',
            target: targets.thermostat.cell,
            function: () async {
              inFlight++;
              if (inFlight > maxInFlight) maxInFlight = inFlight;
              await gate.future;
              inFlight--;
              return true;
            },
          ),
        ]);
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final a = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'srv-a',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    final b = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'srv-b',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(maxInFlight, 1, reason: 'the router serializes applies');
    gate.complete();
    await a;
    await b;
  });

  test('the two 504s: queue_timeout versus outcome_unknown', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final f = await fixtureWith(
      (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'block',
          target: targets.thermostat.cell,
          function: () async {
            started.complete();
            await release.future;
            return true;
          },
        ),
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'sleepy',
          target: targets.thermostat.cell,
          function: () async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return true;
          },
        ),
      ],
      maxQueueWait: const Duration(milliseconds: 20),
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

    Future<(int, Map<String, Object?>)> post(String function) async {
      final request = await http.postUrl(
          Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(
          {'cellId': 'home.living.thermostat', 'function': function}));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return (
        response.statusCode,
        text.isEmpty
            ? <String, Object?>{}
            : (jsonDecode(text) as Map).cast<String, Object?>(),
      );
    }

    // Hold the router with the first call.
    final firstFuture = post('block');
    await started.future;

    // A second call queued past the 20ms budget is queue_timeout.
    final secondFuture = post('block');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    release.complete();
    await firstFuture;
    final (secondStatus, secondBody) = await secondFuture;

    expect(secondStatus, HttpStatus.gatewayTimeout);
    final secondError = (secondBody['error'] as Map).cast<String, Object?>();
    expect(secondError['code'], 'queue_timeout');
    expect(secondBody.toString(), isNot(contains('outcome_unknown')));

    // A handler timeout while apply is running stays outcome_unknown.
    final sleepy = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const AllowAllSkinAuth(),
      requestTimeout: const Duration(milliseconds: 50),
    );
    addTearDown(sleepy.close);
    final sleepyRequest = await http.postUrl(
        Uri.parse('http://127.0.0.1:${sleepy.port}/skin/apply'));
    sleepyRequest.headers.contentType = ContentType.json;
    sleepyRequest.write(jsonEncode(
        {'cellId': 'home.living.thermostat', 'function': 'sleepy'}));
    final sleepyResponse = await sleepyRequest.close();
    final sleepyText = await sleepyResponse.transform(utf8.decoder).join();
    expect(sleepyResponse.statusCode, HttpStatus.gatewayTimeout);
    expect(sleepyText, contains('outcome_unknown'));
  });

  test('maxQueued: 1 refuses the waiter while the apply finishes', () async {
    var calls = 0;
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
    final before = await f.ledger.lastSeq;

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

    // The cap counts the apply in progress: the second call is refused
    // immediately, without waiting for the blocker.
    final second = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'srv-2',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    expect(second, isA<WireError>());
    expect((second as WireError).code, 'queue_full');
    expect(second.message, 'the router queue is full');
    expect(calls, 1);
    expect(await f.ledger.lastSeq, before, reason: 'lastSeq did not move');

    release.complete();
    expect(await first, isA<WireResponse>());
    expect(calls, 1, reason: 'the in-flight apply still finishes, once');

    // After the blocker finishes, the slot is free again.
    final third = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'srv-3',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    expect(third, isA<WireResponse>());
    expect(calls, 2);
  });

  test('a queue_full refusal never claims the client id', () async {
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
    addTearDown(() async {
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

    final refused = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'srv-2',
        clientCorrelationId: 'not-claimed',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    expect((refused as WireError).code, 'queue_full');

    release.complete();
    await first;

    // The refused id was never claimed: the same body now applies.
    final later = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'block',
        correlationId: 'srv-3',
        clientCorrelationId: 'not-claimed',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );
    expect(later, isA<WireResponse>());
  });

  test('maxQueued: 0 and -1 throw ArgumentError', () async {
    await expectLater(
      SkinFixture.build(maxQueued: 0),
      throwsArgumentError,
    );
    await expectLater(
      SkinFixture.build(maxQueued: -1),
      throwsArgumentError,
    );
    await expectLater(
      SkinFixture.build(maxQueueWait: const Duration(seconds: -1)),
      throwsArgumentError,
    );
  });

  test('a closed membrane answers closed; the pane getters work',
      () async {
    final f = await SkinFixture.build();
    expect(f.membrane.routerQueueDepth, 0);
    expect(f.membrane.routerInFlight, 0);
    await f.membrane.close();
    await f.ledger.close();
    expect(f.membrane.isClosed, isTrue);
    await expectLater(
      f.membrane.request(
        WireRequest(
          cellId: 'home.living.thermostat',
          function: 'setTarget',
          correlationId: 'late',
          positional: {'0': 21},
        ),
        type: SkinPulseTypes.restApplyRequest,
      ),
      throwsA(isA<SkinError>()
          .having((e) => e.code, 'code', 'closed')),
    );
  });

  test('REST: the flooded caller gets 429 while the apply finishes',
      () async {
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
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    Future<(int, String)> post() async {
      final request = await http.postUrl(
          Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(
          {'cellId': 'home.living.thermostat', 'function': 'block'}));
      final response = await request.close();
      return (
        response.statusCode,
        await response.transform(utf8.decoder).join()
      );
    }

    final firstFuture = post();
    await started.future;
    final (secondStatus, secondBody) = await post();
    expect(secondStatus, HttpStatus.tooManyRequests);
    expect(jsonDecode(secondBody), {
      'error': {
        'code': 'queue_full',
        'message': 'the router queue is full',
      },
    });
    expect(secondBody, isNot(contains('outcome_unknown')));

    release.complete();
    final (firstStatus, _) = await firstFuture;
    expect(firstStatus, HttpStatus.ok);
  });
}
