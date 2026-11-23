// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Regression tests for the findings of
/// `research/_Pending Plans/Skin/code-review(Grok).md` that were not
/// already covered by the Claude-review pass.
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

  test('a rejected apply never masquerades as an accepted egress', () async {
    final f = await SkinFixture.build();
    final doorChanges = <WireStateChange>[];
    final subscription = f.membrane.responses.listen((pulse) {
      final payload = pulse.payload;
      if (payload is WireStateChange && payload.cellId == 'home.front.door') {
        doorChanges.add(payload);
      }
    });

    final outcome =
        await f.run(() => f.client.apply('home.front.door', 'lock'));
    await f.settle();

    expect(outcome, isA<ApplyRejected<Object?>>());
    expect(doorChanges, isEmpty,
        reason: 'a rejected apply changes no state, so no egress exists — '
            'and even if one did, egress is WireStateChange, never '
            'ApplyAccepted');

    await subscription.cancel();
    await f.membrane.close();
    await f.ledger.close();
  });

  test('concurrent requests with distinct ids never cross-complete', () async {
    final f = await SkinFixture.build();
    final a = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTarget',
        positional: {'0': 19},
        correlationId: 'req-a',
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    final b = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTarget',
        positional: {'0': 20},
        correlationId: 'req-b',
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    final results = await f.run(() => Future.wait([a, b]));
    final responseA = results[0] as WireResponse;
    final responseB = results[1] as WireResponse;
    expect(responseA.correlationId, 'req-a');
    expect(responseB.correlationId, 'req-b');
    expect(responseA.outcome, isA<ApplyAccepted<Object?>>());
    expect(responseB.outcome, isA<ApplyAccepted<Object?>>());

    await f.membrane.close();
    await f.ledger.close();
  });

  test('a WireResponse JSON round-trip preserves the outcome', () {
    final live = WireResponse(
      correlationId: 'c1',
      clientCorrelationId: 'client-1',
      outcome: ApplyAccepted<Object?>(
        42,
        ApplyLedger.receipt(
          cell: Cell.state<int>(initial: 0).cell,
          command: (
            function: () => 42,
            arguments: (
              positionalArguments: null,
              namedArguments: null,
            ),
            compensation: null,
          ),
          vetted: true,
        ),
      ),
    );
    final decoded = WireMessage.fromJson(live.toJson()) as WireResponse;
    expect(decoded.correlationId, 'c1');
    expect(decoded.clientCorrelationId, 'client-1');
    expect(decoded.pendingReceipt, isFalse);
    expect(decoded.outcomeJson, isNotNull);
    expect(decoded.outcomeJson!.kind, 'accepted');
    expect(decoded.outcomeJson!.result, 42);
  });

  test('WireMessage.fromJson throws FormatException on malformed fields', () {
    expect(
      () => WireMessage.fromJson({
        'kind': 'request',
        'cellId': 5, // not a String
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('REST accepts a positional JSON array', () async {
    final f = await SkinFixture.build();
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    final request = await http
        .postUrl(Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({
      'cellId': 'home.living.thermostat',
      'function': 'setTarget',
      'positional': [17],
    }));
    final response = await request.close();
    final body =
        jsonDecode(await response.transform(utf8.decoder).join()) as Map;
    expect(response.statusCode, HttpStatus.ok);
    expect(((body['outcome'] as Map)['kind']), 'accepted');
    expect(f.thermostat.cell.value, 17);

    http.close();
    await adapter.close();
    await f.membrane.close();
    await f.ledger.close();
  });

  test('a timeout surfaces 504 and a same-id retry does not double-apply',
      () async {
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
      requestTimeout: const Duration(milliseconds: 50),
    );
    final http = HttpClient();

    Future<(int, Map<dynamic, dynamic>)> post(String clientId) async {
      final request = await http
          .postUrl(Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'cellId': 'home.living.thermostat',
        'function': 'slowOnce',
        'correlationId': clientId,
      }));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return (response.statusCode, jsonDecode(text) as Map<dynamic, dynamic>);
    }

    // The membrane gives up at 50ms; the command finishes at ~300ms.
    final first = await post('retry-key');
    expect(first.$1, HttpStatus.gatewayTimeout);
    expect((first.$2['error'] as Map)['code'], 'outcome_unknown');

    // Wait for the command to finish and be cached under the client id.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // Retrying the same logical call reuses the stored outcome.
    final second = await post('retry-key');
    expect(second.$1, HttpStatus.ok);
    expect(((second.$2['outcome'] as Map)['kind']), 'accepted');
    expect(calls, 1,
        reason: 'the retry must not execute the command a second time');

    http.close();
    await adapter.close();
    await f.membrane.close();
    await f.ledger.close();
  });

  test('SSE streams a frame and releases the subscription on disconnect',
      () async {
    final f = await SkinFixture.build();
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const AllowAllSkinAuth(),
      keepAliveInterval: const Duration(milliseconds: 50),
    );
    final http = HttpClient();
    final request = await http.getUrl(Uri.parse(
        'http://127.0.0.1:${adapter.port}/skin/observe/home.living.thermostat'));
    final response = await request.close();
    final buffer = StringBuffer();
    final done = Completer<void>();
    response.transform(utf8.decoder).listen(
      (chunk) {
        buffer.write(chunk);
        if (buffer.toString().contains('data:')) {
          if (!done.isCompleted) done.complete();
        }
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      onError: (Object _) {
        // Expected when the client force-closes the socket below.
      },
    );
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [18]));
    await done.future.timeout(const Duration(seconds: 5));
    expect(buffer.toString(),
        contains('event: skin.egress.home.living.thermostat'));
    expect(adapter.activeSubscriptions, 1);

    // Client drops; the next failed ping must release the subscription.
    http.close(force: true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(adapter.activeSubscriptions, 0);

    await adapter.close();
    await f.membrane.close();
    await f.ledger.close();
  });

  test('a request carries its own PulseContext, not system', () async {
    final f = await SkinFixture.build();
    final contexts = <Object?>[];
    final subscription = f.membrane.responses.listen((pulse) {
      if (pulse.payload is WireResponse) {
        contexts.add(pulse.context);
      }
    });
    final context = PulseContext(actor: 'alice', reason: 'provenance test');
    await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTarget',
        positional: {'0': 19},
        correlationId: 'ctx-test',
      ),
      type: SkinPulseTypes.restApplyRequest,
      context: context,
    );
    await f.settle();
    expect(contexts, isNotEmpty);
    final responseContext = contexts.single as PulseContext;
    expect(responseContext, isNot(same(PulseContext.system)));
    expect(responseContext.actor, 'alice');
    expect(responseContext.reason, 'provenance test');

    await subscription.cancel();
    await f.membrane.close();
    await f.ledger.close();
  });

  test('the inbound gate rejects non-wire pulses', () async {
    final gate = WirePulseGate();
    expect(await gate.call(Pulse<dynamic>('not a wire message')), isFalse);
    expect(
      await gate.call(Pulse<WireMessage>(WireRequest(
        cellId: 'x',
        function: 'y',
        correlationId: 'c',
      ))),
      isTrue,
    );
  });

  test('SkinMembrane.request rejects notifications instead of timing out',
      () async {
    final f = await SkinFixture.build();
    expect(
      () => f.membrane.request(
        const WireNotification(method: 'ping'),
        type: SkinPulseTypes.mcpNotificationPrefix,
      ),
      throwsArgumentError,
    );
    await f.membrane.close();
    await f.ledger.close();
  });

  test('a binding whose target is not the registered cell is rejected',
      () async {
    final graph = (CellGraph.builder(graphId: 'mismatch')
          ..register('cell', Cell.state<int>(initial: 0).cell))
        .build();
    final other = Cell.state<int>(initial: 1);
    final bindings = SkinBindingTable()
      ..register(SkinBinding(
        cellId: 'cell',
        functionName: 'set',
        target: other.cell, // not graph['cell']
        function: (int v) => other.update(v),
      ));
    await expectLater(
      SkinMembrane.open(
        graph: graph,
        bindings: bindings,
        journal: RecordingJournal(),
        send: (_) {},
      ),
      throwsA(isA<StateError>()),
    );
  });
}
