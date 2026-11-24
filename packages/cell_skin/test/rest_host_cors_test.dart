// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The HTTP front door: host allowlist, CORS, and verify redaction.
///
/// A non-loopback bind without `allowedHosts` is refused at `bind`.
/// Every non-health route requires an allowed `Host`. A listed `Origin`
/// gets a real preflight before auth and is echoed on the actual
/// response — never `*`. A failed verify redacts the exception.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

Future<(String statusLine, Map<String, String> headers, String body)>
    rawRequest(
  int port, {
  String method = 'GET',
  String path = '/',
  String httpVersion = 'HTTP/1.1',
  Map<String, String> headers = const {},
  String? body,
}) async {
  final socket = await Socket.connect('127.0.0.1', port);
  final lines = <String>[
    '$method $path $httpVersion',
    ...headers.entries.map((e) => '${e.key}: ${e.value}'),
    '',
  ];
  final request = '${lines.join('\r\n')}\r\n${body ?? ''}';
  socket.write(request);
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
  // The adapter answers HTTP/1.1 with chunked transfer: decode the
  // chunk framing (each chunk is `<hex>\r\n<bytes>\r\n`, ending with
  // `0\r\n\r\n`). Fail-safe: if the body is not already plain JSON,
  // keep the outermost {...}.
  final chunkPattern = RegExp(r'^([0-9a-fA-F]+)\r\n', multiLine: true);
  final firstChunk = chunkPattern.firstMatch(bodyText);
  if (firstChunk != null && firstChunk.start == 0) {
    final decoded = StringBuffer();
    var cursor = 0;
    while (cursor < bodyText.length) {
      final match = chunkPattern.matchAsPrefix(bodyText, cursor);
      if (match == null) break;
      final size = int.parse(match.group(1)!, radix: 16);
      final payloadStart = match.end;
      final payloadEnd = payloadStart + size;
      if (payloadEnd + 2 > bodyText.length) break;
      decoded.write(bodyText.substring(payloadStart, payloadEnd));
      cursor = payloadEnd + 2; // skip the trailing CRLF
      if (size == 0) break;
    }
    if (decoded.isNotEmpty || cursor > 0) {
      bodyText = decoded.toString();
    }
  }
  return (
    headLines.isEmpty ? '' : headLines.first,
    headersOut,
    bodyText,
  );
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

void main() {
  setUp(CellGraphRegistry.forceReset);

  Future<(int, Map<String, Object?>)> postJson(
    HttpClient http,
    RestAdapter adapter,
    Map<String, Object?> body, {
    String path = '/skin/apply',
    String? origin,
  }) async {
    final request = await http
        .postUrl(Uri.parse('http://127.0.0.1:${adapter.port}$path'));
    request.headers.contentType = ContentType.json;
    if (origin != null) request.headers.set('Origin', origin);
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

  test('a non-loopback bind without allowedHosts is refused', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    expect(
      () => RestAdapter.bind(
        membrane: f.membrane,
        auth: const AllowAllSkinAuth(),
        address: InternetAddress.anyIPv4,
      ),
      throwsArgumentError,
    );
    // The failed bind closed its socket: the same port binds again.
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);
  });

  test('a foreign Host is 403 host_not_allowed', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);

    final (statusLine, _, body) = await rawRequest(
      adapter.port,
      path: '/skin/manifest',
      headers: const {'Host': 'evil.example'},
    );
    expect(statusLine, contains('403'));
    final decoded = jsonDecode(body) as Map;
    expect((decoded['error'] as Map)['code'], 'host_not_allowed');
  });

  test('a missing Host header is 403', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);

    // HTTP/1.1 without Host never reaches the handler (the parser 400s),
    // so speak HTTP/1.0.
    final (statusLine, _, body) = await rawRequest(
      adapter.port,
      path: '/skin/manifest',
      httpVersion: 'HTTP/1.0',
    );
    expect(statusLine, contains('403'));
    final decoded = jsonDecode(body) as Map;
    expect((decoded['error'] as Map)['code'], 'host_not_allowed');
  });

  test('the host comparison is case-insensitive', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);

    final (statusLine, _, _) = await rawRequest(
      adapter.port,
      path: '/skin/manifest',
      headers: {'Host': 'LOCALHOST:${adapter.port}'},
    );
    expect(statusLine, contains('200'));
  });

  test('an explicit allowedHosts replaces the loopback defaults', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const AllowAllSkinAuth(),
      allowedHosts: const {'public.example'},
    );
    addTearDown(adapter.close);

    final (statusLine, _, body) = await rawRequest(
      adapter.port,
      path: '/skin/manifest',
      headers: {'Host': '127.0.0.1:${adapter.port}'},
    );
    expect(statusLine, contains('403'));
    final decoded = jsonDecode(body) as Map;
    expect((decoded['error'] as Map)['code'], 'host_not_allowed');
  });

  test('an unlisted origin is 403 without CORS headers', () async {
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

    final (statusLine, headers, body) = await rawRequest(
      adapter.port,
      path: '/skin/manifest',
      headers: const {'Host': '127.0.0.1', 'Origin': 'http://evil.example'},
    );
    expect(statusLine, contains('403'));
    final decoded = jsonDecode(body) as Map;
    expect((decoded['error'] as Map)['code'], 'origin_not_allowed');
    expect(headers.containsKey('access-control-allow-origin'), isFalse);
    expect(headers['vary'], contains('Origin'));
  });

  test('a listed origin gets a preflight before auth', () async {
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

    final (statusLine, headers, body) = await rawRequest(
      adapter.port,
      method: 'OPTIONS',
      path: '/skin/apply',
      headers: const {
        'Host': '127.0.0.1',
        'Origin': 'http://app.example',
        'Access-Control-Request-Method': 'POST',
      },
    );
    expect(statusLine, contains('204'));
    expect(body, isEmpty);
    expect(headers['access-control-allow-origin'], 'http://app.example');
    expect(headers['vary'], contains('Origin'));
    expect(headers['access-control-allow-methods'], contains('POST'));
    final allowHeaders = headers['access-control-allow-headers'] ?? '';
    expect(allowHeaders, contains('authorization'));
    expect(allowHeaders, contains('content-type'));
    expect(allowHeaders, contains('last-event-id'));
    expect(headers['access-control-max-age'], '600');
  });

  test('a listed origin is echoed on the real response', () async {
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
    final http = HttpClient();
    addTearDown(http.close);

    final (status, _) = await postJson(
      http,
      adapter,
      {
        'cellId': 'home.living.thermostat',
        'function': 'setTarget',
        'positional': {'0': 19},
      },
      origin: 'http://app.example',
    );
    expect(status, HttpStatus.ok);

    final request = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/skin/manifest'));
    request.headers.set('Origin', 'http://app.example');
    final response = await request.close();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.value('Access-Control-Allow-Origin'),
        'http://app.example');
    expect(response.headers.value('Access-Control-Allow-Origin'), isNot('*'));
    expect(response.headers.value('Vary'), contains('Origin'));
  });

  test('a disallowed preflight method is 405 with the real verbs', () async {
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

    final (statusLine, headers, body) = await rawRequest(
      adapter.port,
      method: 'OPTIONS',
      path: '/skin/apply',
      headers: const {
        'Host': '127.0.0.1',
        'Origin': 'http://app.example',
        'Access-Control-Request-Method': 'DELETE',
      },
    );
    expect(statusLine, contains('405'));
    expect((jsonDecode(body) as Map)['error'] is Map, isTrue);
    expect(headers['allow'], 'POST, OPTIONS');
  });

  test('a verify failure is redacted to ok:false + verify_failed', () async {
    final store = _TamperedStore('tampered');
    final f = await SkinFixture.build(graphId: 'tampered', ledgerStore: store);
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    // One real row, then tamper with what the store yields.
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [19]));
    final errors = <Object>[];
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const AllowAllSkinAuth(),
      onServerError: (error, _) => errors.add(error),
    );
    addTearDown(adapter.close);
    final http = HttpClient();
    addTearDown(http.close);

    store.tampered = true;
    final request = await http.postUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/verify'));
    final response = await request.close();
    final body = jsonDecode(await response.transform(utf8.decoder).join())
        as Map;
    expect(response.statusCode, HttpStatus.internalServerError);
    expect(body.keys.toSet(), {'ok', 'code'});
    expect(body['ok'], isFalse);
    expect(body['code'], 'verify_failed');
    expect(body.toString(), isNot(contains('hash mismatch')));
    expect(body.toString(), isNot(contains('LedgerIntegrityException')));
    expect(body.toString(), isNot(contains('pulse')));
    expect(errors, hasLength(1));

    // An untampered ledger still verifies.
    store.tampered = false;
    final okRequest = await http.postUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/verify'));
    final okResponse = await okRequest.close();
    final okBody = jsonDecode(await okResponse.transform(utf8.decoder).join())
        as Map;
    expect(okResponse.statusCode, HttpStatus.ok);
    expect(okBody['ok'], isTrue);
  });
}
