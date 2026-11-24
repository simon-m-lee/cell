// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The one authorization hook.
///
/// `SkinAuthorizer` runs after the binding was found and the whitelist
/// allows it, and before the domain gate and `apply`. `false` is
/// `forbidden` (HTTP 403) and never cached; `true` still runs the
/// domain gate. Roles stay data — the hook reads the principal; the
/// skin never does.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

final class FixedAuth implements SkinAuth {
  final SkinPrincipal principal;
  const FixedAuth(this.principal);

  @override
  Future<SkinPrincipal?> authenticate(SkinCredentials credentials) async =>
      principal;
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('a hook that refuses does not apply and does not move the ledger',
      () async {
    final f = await SkinFixture.build(
      authorizer: (principal, binding) async => principal.id != 'guest',
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final before = await f.ledger.lastSeq;
    final outcome = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTarget',
        correlationId: 'srv-guest',
        positional: {'0': 21},
      ),
      type: SkinPulseTypes.restApplyRequest,
      principal: SkinPrincipal(id: 'guest'),
    );
    expect(outcome, isA<WireError>());
    expect((outcome as WireError).code, 'forbidden');
    expect(await f.ledger.lastSeq, before);
    expect(f.thermostat.cell.value, 22);
  });

  test('a hook that allows still runs the domain gate', () async {
    var hookCalls = 0;
    final f = await SkinFixture.build(
      authorizer: (principal, binding) async {
        hookCalls++;
        return true;
      },
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    // The door gate refuses lock while an occupant is home — the
    // authorizer said yes, so the domain gate's denial is the outcome.
    f.doorGate.occupantHome = true;
    final outcome = await f.client.apply(
      'home.front.door',
      'lock',
      principal: SkinPrincipal(id: 'alice'),
    );
    expect(outcome, isA<ApplyRejected<Object?>>());
    expect(hookCalls, 1);
    expect(f.door.cell.value, isFalse);
  });

  test('a hidden tool stays unknown_tool and skips the hook', () async {
    final hookCalls = <String>[];
    final f = await SkinFixture.build(
      authorizer: (principal, binding) async {
        hookCalls.add('${binding.cellId}.${binding.functionName}');
        return true;
      },
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final outcome = await f.membrane.request(
      WireRequest(
        cellId: 'home.front.door',
        function: 'explode',
        correlationId: 'srv-explode',
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect(outcome, isA<WireError>());
    expect((outcome as WireError).code, 'unknown_tool');
    expect(hookCalls, isEmpty);
  });

  test('REST sees the token principal and refuses without echoing it',
      () async {
    final f = await SkinFixture.build(
      authorizer: (principal, binding) async =>
          principal.roles.contains('operator'),
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final http = HttpClient();
    addTearDown(http.close);

    Future<(int, Map<String, Object?>)> post(RestAdapter adapter) async {
      final request = await http.postUrl(
          Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'cellId': 'home.living.thermostat',
        'function': 'setTarget',
        'positional': {'0': 21},
      }));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return (
        response.statusCode,
        text.isEmpty
            ? <String, Object?>{}
            : (jsonDecode(text) as Map).cast<String, Object?>(),
      );
    }

    final allowed = await RestAdapter.bind(
      membrane: f.membrane,
      auth: FixedAuth(SkinPrincipal(id: 'alice', roles: ['operator'])),
    );
    addTearDown(allowed.close);
    final (allowedStatus, _) = await post(allowed);
    expect(allowedStatus, HttpStatus.ok);
    expect(f.thermostat.cell.value, 21);

    final refused = await RestAdapter.bind(
      membrane: f.membrane,
      auth: FixedAuth(SkinPrincipal(id: 'guest')),
    );
    addTearDown(refused.close);
    final (refusedStatus, refusedBody) = await post(refused);
    expect(refusedStatus, HttpStatus.forbidden);
    expect((refusedBody['error'] as Map)['code'], 'forbidden');
    expect(refusedBody.toString(), isNot(contains('guest')));
    // The refused apply never reached the value cell.
    expect(f.thermostat.cell.value, 21);
  });

  test('a hook throw is transport_error with the runtime type only',
      () async {
    final f = await SkinFixture.build(
      authorizer: (principal, binding) async =>
          throw StateError('secret detail'),
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final before = await f.ledger.lastSeq;
    final outcome = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTarget',
        correlationId: 'srv-throw',
        positional: {'0': 21},
      ),
      type: SkinPulseTypes.restApplyRequest,
    );
    expect(outcome, isA<WireError>());
    expect((outcome as WireError).code, 'transport_error');
    expect(outcome.message, isNot(contains('secret')));
    expect(await f.ledger.lastSeq, before);
  });

  test('a denial is not sticky: the same client id can be allowed later',
      () async {
    final f = await SkinFixture.build(
      authorizer: (principal, binding) async => principal.id != 'guest',
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });

    final denied = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTarget',
        correlationId: 'srv-1',
        clientCorrelationId: 'same-key',
        positional: {'0': 21},
      ),
      type: SkinPulseTypes.restApplyRequest,
      principal: SkinPrincipal(id: 'guest'),
    );
    expect((denied as WireError).code, 'forbidden');

    final allowed = await f.membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTarget',
        correlationId: 'srv-2',
        clientCorrelationId: 'same-key',
        positional: {'0': 20},
      ),
      type: SkinPulseTypes.restApplyRequest,
      principal: SkinPrincipal(id: 'alice'),
    );
    expect(allowed, isA<WireResponse>());
    expect(f.thermostat.cell.value, 20);
  });
}
