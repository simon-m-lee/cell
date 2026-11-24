// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The request log line cannot carry the bearer token.
///
/// `onRequestLog` fires once per finished request with a sample of six
/// fields — route without the query, the server correlation id, the
/// status, the stable error code, the duration, and the apply's
/// `ledgerSeq`. No headers, no body, no principal.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'rest_host_cors_test.dart' show rawRequest;
import 'skin_fixture.dart';

final class _BearerAuth implements SkinAuth {
  const _BearerAuth();

  @override
  Future<SkinPrincipal?> authenticate(SkinCredentials credentials) async {
    if (credentials.token == 'token-7f3a9c') {
      return SkinPrincipal(id: 'alice');
    }
    return null;
  }
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('samples carry the six fields and never the token', () async {
    const token = 'token-7f3a9c';
    final f = await SkinFixture.build();
    final samples = <SkinRequestSample>[];
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const _BearerAuth(),
      onRequestLog: (sample) {
        if ('$sample'.contains(token)) {
          throw StateError('the log line leaked the token: $sample');
        }
        samples.add(sample);
      },
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    // 1. An unauthenticated request is 401 and is logged.
    final noToken = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/ready'));
    final noTokenResponse = await noToken.close();
    expect(noTokenResponse.statusCode, HttpStatus.unauthorized);
    await noTokenResponse.drain<void>();

    // 2. An authenticated apply is logged with the server id, the row's
    // seq, and the bare route.
    final apply = await http.postUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply?token=ignored'));
    apply.headers.contentType = ContentType.json;
    apply.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    apply.write(jsonEncode({
      'cellId': 'home.living.thermostat',
      'function': 'setTarget',
      'positional': {'0': 21},
      'correlationId': 'client-visible-id',
    }));
    final applyResponse = await apply.close();
    expect(applyResponse.statusCode, HttpStatus.ok);
    await applyResponse.drain<void>();

    // 3. A foreign Host is 403 host_not_allowed and is logged.
    await rawRequest(
      adapter.port,
      path: '/ready',
      headers: const {'Host': 'evil.example'},
    );

    // Let the last handler finish before asserting.
    await f.settle();

    final unauthorized = samples
        .where((s) => s.status == HttpStatus.unauthorized)
        .toList();
    expect(unauthorized, hasLength(1));
    expect(unauthorized.single.code, 'unauthorized');

    final hostRefused = samples
        .where((s) => s.status == HttpStatus.forbidden)
        .toList();
    expect(hostRefused, hasLength(1));
    expect(hostRefused.single.code, 'host_not_allowed');

    final applySample = samples
        .where((s) => s.status == HttpStatus.ok && s.route == '/skin/apply')
        .toList();
    expect(applySample, hasLength(1));
    final sample = applySample.single;
    expect(sample.code, isNull);
    expect(sample.route, '/skin/apply',
        reason: 'the route is the path only, never the query');
    expect(sample.correlationId, isNotEmpty);
    expect(sample.correlationId, isNot('client-visible-id'),
        reason: 'the sample carries the server id, not the client id');
    expect(sample.ledgerSeq, 0, reason: 'the row just written');
    expect(sample.duration, greaterThanOrEqualTo(Duration.zero));

    // No sample string contains the token; the callback would have
    // thrown otherwise, and the assertions above read every sample.
    for (final logged in samples) {
      expect('$logged', isNot(contains(token)));
      expect('$logged', isNot(contains('Bearer')));
    }
  });
}
