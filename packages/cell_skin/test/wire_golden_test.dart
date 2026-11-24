// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The wire contract: `test/goldens/wire/` is what a 1.x server may
/// send and what a 1.x peer must accept.
///
/// Every message golden carries `wire: "1"`. A golden that gains a key
/// (or loses one) fails here; changing a golden is a breaking change
/// and must come with a migration-guide edit. The error directory and
/// `skinErrorStatus` name the same codes and the same statuses.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

void main() {
  final messages = Directory('test/goldens/wire/messages')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  test('every message golden round-trips byte-for-byte (canonical)', () {
    expect(messages, isNotEmpty);
    for (final file in messages) {
      final golden = jsonDecode(file.readAsStringSync()) as Map;
      final decoded = WireMessage.fromJson(
          (jsonDecode(file.readAsStringSync()) as Map)
              .cast<String, Object?>());
      final reEncoded = canonicalJsonEncode(decoded.toJson());
      final goldenCanonical = canonicalJsonEncode(golden);
      expect(reEncoded, goldenCanonical, reason: file.path);
      expect((golden['wire']), '1', reason: '${file.path} carries wire');
    }
  });

  test('the error directory and skinErrorStatus are the same table', () {
    final dir = Directory('test/goldens/wire/errors')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    expect(dir, isNotEmpty);

    final fromDir = <String, int>{};
    for (final file in dir) {
      final json = jsonDecode(file.readAsStringSync()) as Map;
      final code = json['code'] as String;
      expect(json['http'], isA<int>(), reason: file.path);
      expect(json['receipt'], isFalse, reason: file.path);
      fromDir[code] = json['http'] as int;
    }
    expect(fromDir.keys.toSet(), skinErrorStatus.keys.toSet(),
        reason: 'the golden directory and the map must name the same codes');
    for (final entry in fromDir.entries) {
      expect(skinErrorStatus[entry.key], entry.value,
          reason: 'status for ${entry.key}');
    }
  });

  test('version behavior: absent and "1" decode, everything else throws',
      () {
    const body = {
      'kind': 'notification',
      'method': 'notify',
      'params': <String, Object?>{},
    };
    expect(WireMessage.fromJson(body), isA<WireNotification>());
    expect(WireMessage.fromJson({'wire': '1', ...body}),
        isA<WireNotification>());

    for (final bad in ['2', 2, '', null]) {
      expect(
        () => WireMessage.fromJson({'wire': bad, ...body}),
        throwsA(isA<FormatException>().having((e) => e.message,
            'message', 'unsupported wire version')),
        reason: 'wire: $bad',
      );
    }

    // Unknown kind is its own text, not the version text.
    expect(
      () => WireMessage.fromJson(const {'kind': 'nope'}),
      throwsA(isA<FormatException>().having((e) => e.message,
          'message', isNot('unsupported wire version'))),
    );
  });

  test('manifest correlation ids are optional and omitted when null', () {
    const noCorrelation = {'kind': 'manifestRequest'};
    expect(WireMessage.fromJson(noCorrelation), isA<WireManifestRequest>());
    final request =
        WireMessage.fromJson(noCorrelation) as WireManifestRequest;
    expect(request.correlationId, isNull);
    expect(request.toJson(), containsPair('wire', '1'));
    expect(request.toJson().containsKey('correlationId'), isFalse);

    final response = WireMessage.fromJson({
      'kind': 'manifestResponse',
      'manifest': <String, Object?>{
        'cells': <Object?>[],
      },
    }) as WireManifestResponse;
    expect(response.correlationId, isNull);
    expect(response.toJson().containsKey('correlationId'), isFalse);

    // With an id, the key is in the contract and round-trips.
    final withId = WireMessage.fromJson(const {
      'wire': '1',
      'kind': 'manifestRequest',
      'correlationId': 'm-1',
    }) as WireManifestRequest;
    expect(withId.correlationId, 'm-1');
  });

  test('a deadline is queue metadata and stays off the wire', () {
    final request = WireRequest(
      cellId: 'a',
      function: 'f',
      correlationId: 'c',
      deadline: DateTime(2026, 1, 1),
    );
    final json = request.toJson();
    expect(json['wire'], '1');
    expect(json.containsKey('deadline'), isFalse);
  });

  test('the fingerprint is unchanged after a round-trip that added wire',
      () {
    final request = WireRequest(
      cellId: 'a',
      function: 'f',
      positional: {'0': 1},
      correlationId: 'c',
      lastSeenSeq: 2,
    );
    final before = idempotencyFingerprint(request);
    final roundTripped = WireMessage.fromJson(
        (jsonDecode(jsonEncode(request.toJson())) as Map)
            .cast<String, Object?>()) as WireRequest;
    expect(idempotencyFingerprint(roundTripped), before);
  });

  test('REST: wire "2" is 400 bad_json with no exception text', () async {
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

    Future<(int, String)> post(Map<String, Object?> body) async {
      final request = await http.postUrl(
          Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      return (response.statusCode, await response.transform(utf8.decoder).join());
    }

    final valid = {
      'cellId': 'home.living.thermostat',
      'function': 'setTarget',
      'positional': {'0': 21},
    };
    final (badStatus, badBody) = await post({'wire': '2', ...valid});
    expect(badStatus, HttpStatus.badRequest);
    expect(jsonDecode(badBody), {
      'error': {'code': 'bad_json'},
    });
    expect(badBody, isNot(contains('FormatException')));
    expect(badBody, isNot(contains('unsupported')));

    final (explicitStatus, _) = await post({'wire': '1', ...valid});
    expect(explicitStatus, HttpStatus.ok);

    final (omittedStatus, _) = await post(valid);
    expect(omittedStatus, HttpStatus.ok);

    // A REST body with no kind is a projection, not an unknown message
    // kind: it fails as missing fields, not as a kind error.
    final (noKindStatus, noKindBody) = await post({'wire': '1'});
    expect(noKindStatus, HttpStatus.badRequest);
    expect(noKindBody, isNot(contains('unknown wire message kind')));
  });

  test('the ledger-entry codecs round-trip through LedgerEntry', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [21]));
    final entry = await f.ledger.entriesSince(0).first;
    final json = wireLedgerEntryJson(entry);
    final decoded = wireLedgerEntryFromJson(json);
    expect(decoded.seq, entry.seq);
    expect(decoded.receipt.id, entry.receipt.id);
    expect(wireLedgerEntryCellId(entry), 'home.living.thermostat');
  });
}
