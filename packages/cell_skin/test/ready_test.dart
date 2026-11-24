// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// `GET /ready` is the authenticated readiness probe beside `/health`.
///
/// Ready means: the membrane is open, the ledger (when bound) verifies,
/// and a configured file idempotency store still has its directory.
/// A failing verify is 503 `not_ready` with exactly `{ok, code}` and
/// no exception text; `/health` stays 200, unauthenticated, and exempt
/// from the host check.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin_io.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

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

final class _BearerAuth implements SkinAuth {
  final String token;
  const _BearerAuth([this.token = 'token-7f3a9c']);

  @override
  Future<SkinPrincipal?> authenticate(SkinCredentials credentials) async {
    if (credentials.token == token) {
      return SkinPrincipal(id: 'alice');
    }
    return null;
  }
}

/// A ledger whose `entriesSince` throws once [broken] is set, so
/// `verify()` throws and `/ready` is 503 not_ready.
final class _ThrowingVerifyStore implements LedgerStore {
  final InMemoryLedgerStore inner;
  bool broken = false;

  _ThrowingVerifyStore(String graphId)
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
    if (broken) {
      throw StateError('verify boom');
    }
    yield* inner.entriesSince(fromSeq);
  }

  @override
  Future<void> close() => inner.close();
}

Future<(String, Map<String, String>, String)> rawRequest(
  int port, {
  String method = 'GET',
  String path = '/',
  String httpVersion = 'HTTP/1.1',
  Map<String, String> headers = const {},
}) async {
  final socket = await Socket.connect('127.0.0.1', port);
  final lines = <String>[
    '$method $path $httpVersion',
    ...headers.entries.map((e) => '${e.key}: ${e.value}'),
    '',
  ];
  socket.write('${lines.join('\r\n')}\r\n');
  final bytes = <int>[];
  await socket.listen(bytes.addAll).asFuture<void>().timeout(
        const Duration(seconds: 5),
        onTimeout: () => socket.destroy(),
      );
  final text = utf8.decode(bytes, allowMalformed: true);
  final headerEnd = text.indexOf('\r\n\r\n');
  final head = headerEnd < 0 ? text : text.substring(0, headerEnd);
  final headLines = head.split('\r\n');
  final headersOut = <String, String>{};
  for (final line in headLines.skip(1)) {
    final colon = line.indexOf(':');
    if (colon > 0) {
      headersOut[line.substring(0, colon).trim().toLowerCase()] =
          line.substring(colon + 1).trim();
    }
  }
  var bodyText = headerEnd < 0 ? '' : text.substring(headerEnd + 4);
  if (bodyText.endsWith('0\r\n\r\n')) {
    bodyText = bodyText.substring(0, bodyText.length - 5);
  }
  return (headLines.isEmpty ? '' : headLines.first, headersOut, bodyText);
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('an open membrane with a healthy ledger is ready', () async {
    final f = await SkinFixture.build();
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

    final request = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/ready'));
    final response = await request.close();
    final body = jsonDecode(await response.transform(utf8.decoder).join())
        as Map;
    expect(response.statusCode, HttpStatus.ok);
    expect(body.keys.toSet(), {'ok'});
    expect(body['ok'], isTrue);
  });

  test('a failing verify is 503 not_ready with exactly {ok, code}',
      () async {
    final store = _TamperedStore('ready-tampered');
    final f = await SkinFixture.build(
        graphId: 'ready-tampered', ledgerStore: store);
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [21]));
    final errors = <Object>[];
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const AllowAllSkinAuth(),
      onServerError: (error, _) => errors.add(error),
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    store.tampered = true;
    final request = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/ready'));
    final response = await request.close();
    final body = jsonDecode(await response.transform(utf8.decoder).join())
        as Map;
    expect(response.statusCode, HttpStatus.serviceUnavailable);
    expect(body.keys.toSet(), {'ok', 'code'});
    expect(body['ok'], isFalse);
    expect(body['code'], 'not_ready');
    expect(body.toString(), isNot(contains('mismatch')));
    expect(errors, hasLength(1));

    // /health is still liveness and still 200.
    final health = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/health'));
    final healthResponse = await health.close();
    expect(healthResponse.statusCode, HttpStatus.ok);

    // An untampered ledger is ready again.
    store.tampered = false;
    final ready = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/ready'));
    final readyResponse = await ready.close();
    expect(readyResponse.statusCode, HttpStatus.ok);
  });

  test('/ready without a token is 401', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const _BearerAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
    });

    final noToken = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/ready'));
    final noTokenResponse = await noToken.close();
    expect(noTokenResponse.statusCode, HttpStatus.unauthorized);

    final withToken = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/ready'));
    withToken.headers.set(HttpHeaders.authorizationHeader,
        'Bearer token-7f3a9c');
    final withTokenResponse = await withToken.close();
    expect(withTokenResponse.statusCode, HttpStatus.ok);
  });

  test('a closed membrane is 503 not_ready', () async {
    final f = await SkinFixture.build();
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.ledger.close();
    });

    await f.membrane.close();
    final request = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/ready'));
    final response = await request.close();
    final body = jsonDecode(await response.transform(utf8.decoder).join())
        as Map;
    expect(response.statusCode, HttpStatus.serviceUnavailable);
    expect(body['code'], 'not_ready');
  });

  test('a foreign Host is 403 on /ready and still 200 on /health', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);

    final (readyStatus, _, readyBody) = await rawRequest(
      adapter.port,
      path: '/ready',
      headers: const {'Host': 'evil.example'},
    );
    expect(readyStatus, contains('403'));
    expect(readyBody, contains('host_not_allowed'));

    final (healthStatus, _, _) = await rawRequest(
      adapter.port,
      path: '/health',
      headers: const {'Host': 'evil.example'},
    );
    expect(healthStatus, contains('200'));
  });

  test('a missing file-store directory is 503 not_ready', () async {
    final dir = await Directory.systemTemp.createTemp('cell-skin-ready-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final store = await FileIdempotencyStore.open(directory: dir.path);
    final f = await SkinFixture.build(idempotency: store);
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

    await dir.delete(recursive: true);
    final request = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/ready'));
    final response = await request.close();
    final body = jsonDecode(await response.transform(utf8.decoder).join())
        as Map;
    expect(response.statusCode, HttpStatus.serviceUnavailable);
    expect(body['code'], 'not_ready');
  });

  test('a verify() that throws is 503 not_ready and logged', () async {
    final store = _ThrowingVerifyStore('ready-throwing');
    final f = await SkinFixture.build(
        graphId: 'ready-throwing', ledgerStore: store);
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final errors = <Object>[];
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const _BearerAuth('ready-token'),
      onServerError: (error, _) => errors.add(error),
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
    });

    store.broken = true;
    final request = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/ready'));
    request.headers.set('Authorization', 'Bearer ready-token');
    final response = await request.close();
    final body = jsonDecode(await response.transform(utf8.decoder).join())
        as Map;
    expect(response.statusCode, HttpStatus.serviceUnavailable);
    expect(body, {'ok': false, 'code': 'not_ready'});
    expect(errors, hasLength(1));
  });

  test('POST /ready is 405 with Allow: GET', () async {
    final f = await SkinFixture.build();
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

    final request = await http
        .postUrl(Uri.parse('http://127.0.0.1:${adapter.port}/ready'));
    final response = await request.close();
    expect(response.statusCode, HttpStatus.methodNotAllowed);
    expect(response.headers.value(HttpHeaders.allowHeader), 'GET');
  });
}
