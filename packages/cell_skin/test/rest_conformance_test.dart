// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('REST adapter shares the same four cells as MCP', () async {
    final f = await SkinFixture.build();
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();

    Future<Map<String, dynamic>> call(
      String method,
      String path, [
      Map<String, Object?>? body,
    ]) async {
      final request = await http.openUrl(
          method, Uri.parse('http://127.0.0.1:${adapter.port}$path'));
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return {
        'status': response.statusCode,
        'body': text.isEmpty
            ? <String, Object?>{}
            : (jsonDecode(text) as Map).cast<String, Object?>(),
      };
    }

    // Health.
    final health = await call('GET', '/health');
    expect(health['status'], HttpStatus.ok);

    // Accepted apply.
    final accepted = await call('POST', '/skin/apply', {
      'cellId': 'home.living.thermostat',
      'function': 'setTarget',
      'positional': {'0': 19},
    });
    expect(accepted['status'], HttpStatus.ok);
    final outcome =
        (accepted['body']!['outcome'] as Map).cast<String, Object?>();
    expect(outcome['kind'], 'accepted');
    expect(f.thermostat.cell.value, 19);

    // Rejected apply — the real domain gate, over HTTP.
    final rejected = await call('POST', '/skin/apply', {
      'cellId': 'home.front.door',
      'function': 'lock',
    });
    expect(rejected['status'], HttpStatus.ok);
    final rejectedOutcome =
        (rejected['body']!['outcome'] as Map).cast<String, Object?>();
    expect(rejectedOutcome['kind'], 'rejected');
    expect(f.door.cell.value, isFalse);

    // Exposure gate miss → 404.
    final unknown = await call('POST', '/skin/apply', {
      'cellId': 'home.front.door',
      'function': 'explode',
    });
    expect(unknown['status'], HttpStatus.notFound);
    expect(
      ((unknown['body']!['error'] as Map).cast<String, Object?>())['code'],
      'unknown_tool',
    );

    // Manifest.
    final manifest = await call('GET', '/skin/manifest');
    expect(manifest['status'], HttpStatus.ok);
    final cells = ((manifest['body']!['manifest'] as Map)
        .cast<String, Object?>())['cells'] as List;
    expect(cells, isNotEmpty);

    // Verify (the membrane has a bound ledger).
    final verify = await call('POST', '/skin/verify');
    expect(verify['status'], HttpStatus.ok);
    expect(verify['body']!['ok'], isTrue);

    await adapter.close();
    http.close();
    await f.membrane.close();
    await f.ledger.close();
  });
}
