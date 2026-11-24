// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

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

  test('H1: each egress state change pairs with its own receipt', () async {
    final f = await SkinFixture.build();
    final changes = <WireStateChange>[];
    final subscription = f.membrane.responses.listen((pulse) {
      if (pulse.payload is WireStateChange) {
        changes.add(pulse.payload as WireStateChange);
      }
    });

    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [20]));
    await f.settle();
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [21]));
    await f.settle();

    final thermostatChanges =
        changes.where((c) => c.cellId == 'home.living.thermostat').toList();
    expect(thermostatChanges.length, greaterThanOrEqualTo(2));
    final first = thermostatChanges[thermostatChanges.length - 2];
    final second = thermostatChanges.last;
    expect(first.pendingReceipt, isFalse);
    expect(second.pendingReceipt, isFalse);
    expect(first.receipt, isNotNull);
    expect(second.receipt, isNotNull);
    expect(first.receipt!.id, isNot(second.receipt!.id),
        reason: 'the second change must never borrow the first receipt');
    expect(first.payload, 20);
    expect(second.payload, 21);

    await subscription.cancel();
    await f.membrane.close();
    await f.ledger.close();
  });

  test('H1: egress carries no correlation id', () async {
    final f = await SkinFixture.build();
    final changes = <WireStateChange>[];
    final subscription = f.membrane.responses.listen((pulse) {
      if (pulse.payload is WireStateChange) {
        changes.add(pulse.payload as WireStateChange);
      }
    });
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [20]));
    await f.settle();
    expect(changes, isNotEmpty);
    expect(changes.last.toJson().containsKey('correlationId'), isFalse);
    await subscription.cancel();
    await f.membrane.close();
    await f.ledger.close();
  });

  test('H6: a duplicate server correlation id never re-applies', () async {
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
            ]);

    final first = await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.living.thermostat',
            function: 'countOnce',
            correlationId: 'dup',
          ),
          type: SkinPulseTypes.restApplyRequest,
        ));
    final second = await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.living.thermostat',
            function: 'countOnce',
            correlationId: 'dup',
          ),
          type: SkinPulseTypes.restApplyRequest,
        ));

    expect(first, isA<WireResponse>());
    expect(second, isA<WireResponse>());
    expect(calls, 1,
        reason: 'idempotency: the duplicate correlation id must not '
            'run the command again');

    await f.membrane.close();
    await f.ledger.close();
  });

  test('H6: a non-JSON result is omitted, never a transport 500', () async {
    final f = await SkinFixture.build(
        extraBindings: (targets) => [
              SkinBinding(
                cellId: 'home.living.thermostat',
                functionName: 'opaqueResult',
                target: targets.thermostat.cell,
                function: () => Object(), // jsonEncode cannot encode this
              ),
            ]);
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    final request = await http
        .postUrl(Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({
      'cellId': 'home.living.thermostat',
      'function': 'opaqueResult',
    }));
    final response = await request.close();
    final body =
        jsonDecode(await response.transform(utf8.decoder).join()) as Map;

    expect(response.statusCode, HttpStatus.ok);
    final outcome = (body['outcome'] as Map).cast<String, Object?>();
    expect(outcome['resultOmitted'], isTrue);

    http.close();
    await adapter.close();
    await f.membrane.close();
    await f.ledger.close();
  });

  test(
      'H3/H4: the REST surface enforces exposure, methods, content '
      'type, auth and origin', () async {
    final f = await SkinFixture.build(
      whitelist: SkinWhitelist({
        'home.living.thermostat': {'setTarget'},
      }),
    );
    // A real auth that rejects missing tokens.
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: _RequireTokenAuth(),
    );
    final http = HttpClient();

    Future<HttpClientResponse> send(
      String method,
      String path, {
      String? body,
      String? contentType,
      String? token,
      String? origin,
    }) async {
      final request = await http.openUrl(
          method, Uri.parse('http://127.0.0.1:${adapter.port}$path'));
      if (contentType != null) {
        request.headers.contentType = ContentType.parse(contentType);
      }
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (origin != null) {
        request.headers.set('origin', origin);
      }
      if (body != null) {
        request.write(body);
      }
      return request.close();
    }

    // No auth → 401 (with WWW-Authenticate).
    final unauthorized = await send('GET', '/skin/manifest');
    expect(unauthorized.statusCode, HttpStatus.unauthorized);
    expect(unauthorized.headers.value(HttpHeaders.wwwAuthenticateHeader),
        isNotNull);

    // Method not allowed.
    final wrongMethod = await send('GET', '/skin/apply', token: 't');
    expect(wrongMethod.statusCode, HttpStatus.methodNotAllowed);

    // Content type not allowed.
    final wrongType = await send('POST', '/skin/apply',
        token: 't', contentType: 'text/plain', body: '{}');
    expect(wrongType.statusCode, HttpStatus.unprocessableEntity);

    // Browser cross-origin request → 403.
    final crossOrigin = await send('GET', '/skin/manifest',
        token: 't', origin: 'https://evil.example');
    expect(crossOrigin.statusCode, HttpStatus.forbidden);

    // Bad body → 400.
    final badBody = await send('POST', '/skin/apply',
        token: 't', contentType: 'application/json', body: '{oops');
    expect(badBody.statusCode, HttpStatus.badRequest);

    // A bound-but-not-whitelisted cell has no observe surface.
    final hidden =
        await send('GET', '/skin/observe/home.front.door', token: 't');
    expect(hidden.statusCode, HttpStatus.notFound);

    http.close();
    await adapter.close();
    await f.membrane.close();
    await f.ledger.close();
  });

  test('H9: close() stops observers and fails pending requests', () async {
    final f = await SkinFixture.build();
    final pulses = <Pulse<WireMessage>>[];
    final subscription = f.membrane.responses.listen(pulses.add);

    // A request that can never complete (unknown tool) is in flight.
    final pending = f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'never',
        correlationId: 'closing',
      ),
      type: SkinPulseTypes.restApplyRequest,
      timeout: const Duration(seconds: 5),
    );

    // Attach the expectation before close() so the pending error has
    // a listener.
    final expectation = expectLater(pending, throwsA(isA<SkinError>()));
    await f.membrane.close();
    await expectation;
    final count = pulses.length;
    await f.run(() => f.thermostat.update(30));
    await f.settle();
    expect(pulses.length, count,
        reason: 'closed membrane must not emit further pulses');

    await subscription.cancel();
    await f.ledger.close();
  });

  test('H3: whitelist entries with no binding produce a policy warning',
      () async {
    final warnings = <String>[];
    final f = await SkinFixture.build(
      whitelist: SkinWhitelist({
        'home.living.thermostat': {'setTarget'},
        'home.front.door': {'lock', 'explodeTypo'},
      }),
      onPolicyWarning: warnings.add,
    );
    expect(warnings, isNotEmpty);
    expect(warnings.single, contains('explodeTypo'));
    await f.membrane.close();
    await f.ledger.close();
  });
}

/// An auth that requires the literal token `t`.
final class _RequireTokenAuth implements SkinAuth {
  @override
  Future<SkinPrincipal?> authenticate(SkinCredentials credentials) async =>
      credentials.token == 't' ? const SkinPrincipal(id: 'tester') : null;
}
