// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The 1.0 security pass: one test per row that had no test yet.
///
/// Each row asserts the domain function was not called and `lastSeq`
/// did not move. Rows that already have tests stay in their own files:
/// host/origin/preflight/verify in `rest_host_cors_test.dart`, hidden
/// tool in `authorization_test.dart`, retry conflict in
/// `idempotency_test.dart`, queue timeout in `router_queue_test.dart`,
/// and the M3 log token in `request_log_test.dart`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'ready_test.dart' show rawRequest;
import 'skin_fixture.dart';

final class _TokenAuth implements SkinAuth {
  final String token;
  final String id;
  const _TokenAuth({required this.token, required this.id});

  @override
  Future<SkinPrincipal?> authenticate(SkinCredentials credentials) async {
    if (credentials.token == token) return SkinPrincipal(id: id);
    return null;
  }
}

Future<HttpClientResponse> _post(
  HttpClient http,
  RestAdapter adapter, {
  String path = '/skin/apply',
  Map<String, Object?>? body,
  String? contentType = 'application/json',
  String? authorization,
}) async {
  final request = await http.postUrl(
      Uri.parse('http://127.0.0.1:${adapter.port}$path'));
  if (contentType != null) {
    request.headers.contentType = ContentType.parse(contentType);
  }
  if (authorization != null) {
    request.headers.set(HttpHeaders.authorizationHeader, authorization);
  }
  if (body != null) request.write(jsonEncode(body));
  return request.close();
}

/// A raw HTTP/1.1 POST that sends the entire body before reading, so an
/// oversized body cannot race the adapter's early 413.
Future<(String, String)> _rawPost(
  int port, {
  required String body,
  String contentType = 'application/json',
  String authorization = 'Bearer t',
}) async {
  final socket = await Socket.connect('127.0.0.1', port);
  socket.write(
      'POST /skin/apply HTTP/1.1\r\n'
      'Host: 127.0.0.1\r\n'
      'Content-Type: $contentType\r\n'
      'Authorization: $authorization\r\n'
      'Content-Length: ${utf8.encode(body).length}\r\n'
      '\r\n'
      '$body');
  final bytes = <int>[];
  await socket.listen(bytes.addAll).asFuture<void>().timeout(
        const Duration(seconds: 10),
        onTimeout: () => socket.destroy(),
      );
  final text = utf8.decode(bytes, allowMalformed: true);
  final headerEnd = text.indexOf('\r\n\r\n');
  final head = headerEnd < 0 ? text : text.substring(0, headerEnd);
  final bodyText = headerEnd < 0 ? '' : text.substring(headerEnd + 4);
  return (head.split('\r\n').first, bodyText);
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('no Authorization is 401 and never echoes the auth throw',
      () async {
    var calls = 0;
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'guarded',
          target: targets.thermostat.cell,
          function: () async {
            calls++;
            return true;
          },
        ),
      ],
    );
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const _TokenAuth(token: 't', id: 'alice'));
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });
    final before = await f.ledger.lastSeq;

    final response = await _post(http, adapter,
        body: {'cellId': 'home.living.thermostat', 'function': 'guarded'});
    final body = jsonDecode(await response.transform(utf8.decoder).join())
        as Map;
    expect(response.statusCode, HttpStatus.unauthorized);
    expect(body, {
      'error': {'code': 'unauthorized', 'message': 'missing or invalid credentials'}
    });
    expect('$body', isNot(contains('token-7f3a9c')));
    expect(calls, 0);
    expect(await f.ledger.lastSeq, before);
  });

  test('a forged principal in the JSON body cannot replace the auth id',
      () async {
    SkinPrincipal? seen;
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding.state(
          cellId: 'home.living.thermostat',
          functionName: 'whoami',
          target: targets.thermostat.cell,
          nextValue: (int target) {
            seen = SkinCall.current?.principal;
            return target;
          },
        ),
      ],
    );
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const _TokenAuth(token: 't', id: 'alice'));
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    final response = await _post(
      http,
      adapter,
      body: {
        'cellId': 'home.living.thermostat',
        'function': 'whoami',
        'positional': {'0': 21},
        'principal': 'root',
        'actor': 'root',
        'skin.principal': 'root',
      },
      authorization: 'Bearer t',
    );
    expect(response.statusCode, HttpStatus.ok);
    await response.drain<void>();

    expect(seen?.id, 'alice', reason: 'SkinAuth wins over the JSON body');
    final entry = await f.ledger.entriesSince(0).first;
    final pulseJson = (entry.toJson()['pulseJson'] as Map).cast<String, Object?>();
    final context = (pulseJson['context'] as Map).cast<String, Object?>();
    final lineage = (context['lineage'] as List).cast<Map>();
    expect((lineage.first.cast<String, Object?>()['actor']), 'skin:alice');
  });

  test('oversized, broken, and untyped bodies are adapter rejections',
      () async {
    var calls = 0;
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'guarded',
          target: targets.thermostat.cell,
          function: () async {
            calls++;
            return true;
          },
        ),
      ],
    );
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const _TokenAuth(token: 't', id: 'alice'));
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });
    final before = await f.ledger.lastSeq;

    final tooBig = await _rawPost(
      adapter.port,
      body: '{"padding":"${'x' * (kDefaultMaxBodyBytes + 1)}"}',
    );
    expect(tooBig.$1, contains('413'));
    expect(tooBig.$2, contains('body_too_large'));

    // A body that is not a JSON object, written raw.
    final brokenRequest = await http.postUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
    brokenRequest.headers.contentType = ContentType.json;
    brokenRequest.headers.set(HttpHeaders.authorizationHeader, 'Bearer t');
    brokenRequest.write('{');
    final brokenResponse = await brokenRequest.close();
    expect(brokenResponse.statusCode, HttpStatus.badRequest);
    expect(await brokenResponse.transform(utf8.decoder).join(),
        contains('bad_json'));

    final noType = await _post(http, adapter,
        body: {'cellId': 'home.living.thermostat', 'function': 'guarded'},
        contentType: null,
        authorization: 'Bearer t');
    expect(noType.statusCode, HttpStatus.unprocessableEntity);
    expect(await noType.transform(utf8.decoder).join(),
        contains('content_type_required'));

    expect(calls, 0);
    expect(await f.ledger.lastSeq, before);
  });

  test('a listed-origin preflight needs no Authorization', () async {
    final f = await SkinFixture.build();
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const _TokenAuth(token: 't', id: 'alice'),
      allowedOrigins: const {'http://app.example'},
    );
    addTearDown(() async {
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    final result = await rawRequest(
      adapter.port,
      method: 'OPTIONS',
      path: '/skin/apply',
      headers: const {
        'Host': '127.0.0.1',
        'Origin': 'http://app.example',
        'Access-Control-Request-Method': 'POST',
      },
    );
    final (status, headers, _) = result;
    expect(status, contains('204'));
    expect(headers['access-control-allow-origin'], 'http://app.example');
    expect(headers['access-control-allow-origin'], isNot('*'));
  });

  test('a non-null authorizer filters manifest, observe, and ledger',
      () async {
    final deniedReads = <String>[];
    final f = await SkinFixture.build(
      authorizer: (principal, binding) async {
        if (principal.id == 'mallory') {
          deniedReads.add(binding.cellId);
          return false;
        }
        return true;
      },
    );
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const _TokenAuth(token: 'm', id: 'mallory'));
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    // Seed one thermostat row as an allowed principal (in-process).
    await f.run(() => f.membrane.request(
          WireRequest(
            cellId: 'home.living.thermostat',
            function: 'setTarget',
            correlationId: 'seed',
            positional: {'0': 21},
          ),
          type: SkinPulseTypes.restApplyRequest,
          principal: SkinPrincipal(id: 'alice'),
        ));

    // Manifest: the denied cell is omitted.
    final manifestResponse = await http.getUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/manifest'));
    manifestResponse.headers.set(HttpHeaders.authorizationHeader, 'Bearer m');
    final manifestBody = (jsonDecode(
            await (await manifestResponse.close()).transform(utf8.decoder).join())
        as Map);
    final cells = ((manifestBody['manifest'] as Map)['cells'] as List)
        .cast<Map>()
        .map((c) => c['cellId'])
        .toList();
    expect(cells, isNot(contains('home.living.thermostat')));

    // Observe: exposed but denied is 403 forbidden, not unknown_tool.
    deniedReads.clear();
    final observeRequest = await http.getUrl(Uri.parse(
        'http://127.0.0.1:${adapter.port}/skin/observe/home.living.thermostat'));
    observeRequest.headers.set(HttpHeaders.authorizationHeader, 'Bearer m');
    final observeResponse = await observeRequest.close();
    expect(observeResponse.statusCode, HttpStatus.forbidden);
    expect(await observeResponse.transform(utf8.decoder).join(),
        contains('forbidden'));
    expect(deniedReads, contains('home.living.thermostat'),
        reason: 'the hook is what denied the read');

    // Unexposed cell: still 404 unknown_tool, and the hook is not
    // called for that cell.
    deniedReads.clear();
    final hiddenRequest = await http.getUrl(Uri.parse(
        'http://127.0.0.1:${adapter.port}/skin/observe/not.bound'));
    hiddenRequest.headers.set(HttpHeaders.authorizationHeader, 'Bearer m');
    final hiddenResponse = await hiddenRequest.close();
    expect(hiddenResponse.statusCode, HttpStatus.notFound);
    expect(await hiddenResponse.transform(utf8.decoder).join(),
        contains('unknown_tool'));
    expect(deniedReads, isEmpty);

    // Ledger: the denied cell's rows are not framed.
    final ledgerRequest = await http.getUrl(Uri.parse(
        'http://127.0.0.1:${adapter.port}/skin/ledger?since=0'));
    ledgerRequest.headers.set(HttpHeaders.authorizationHeader, 'Bearer m');
    final ledgerResponse = await ledgerRequest.close();
    final ledgerBody = await ledgerResponse
        .timeout(const Duration(seconds: 10), onTimeout: (sink) => sink.close())
        .transform(utf8.decoder)
        .join();
    expect(ledgerBody, isNot(contains('home.living.thermostat')));
  });
}
