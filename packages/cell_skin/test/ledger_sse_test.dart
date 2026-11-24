// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// `/skin/ledger` and `/skin/observe` are resumable SSE streams.
///
/// The live listener is attached before the store is read, so a row
/// committed during the snapshot is delivered once. `?since=N` is
/// inclusive, `Last-Event-ID: N` is exclusive and only used when the
/// query is absent, and frames after `detachSocket` are real HTTP
/// chunks. One bad payload cannot cancel the subscription.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

final class SseFrame {
  final String? id;
  final String? event;
  final String data;

  const SseFrame(this.id, this.event, this.data);

  @override
  String toString() => 'Frame($id, $event, $data)';
}

Future<List<SseFrame>> readSse(
  HttpClientResponse response, {
  Duration idle = const Duration(milliseconds: 250),
}) async {
  final frames = <SseFrame>[];
  final buffer = StringBuffer();
  String? id;
  String? event;
  String data = '';

  void pushFrame() {
    final text = data.trimRight();
    if (text.isNotEmpty) {
      frames.add(SseFrame(id, event, text));
    }
    id = null;
    event = null;
    data = '';
  }

  await for (final chunk in response
      .timeout(idle, onTimeout: (sink) => sink.close())
      .transform(utf8.decoder)) {
    buffer.write(chunk);
    var text = buffer.toString();
    buffer.clear();
    while (true) {
      final newline = text.indexOf('\n');
      if (newline < 0) {
        buffer.write(text);
        break;
      }
      final line = text.substring(0, newline).replaceAll('\r', '');
      text = text.substring(newline + 1);
      if (line.isEmpty) {
        pushFrame();
      } else if (line.startsWith('id:')) {
        id = line.substring(3).trim();
      } else if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data = data.isEmpty
            ? line.substring(5).trimLeft()
            : '$data\n${line.substring(5).trimLeft()}';
      }
    }
  }
  return frames;
}

Future<(String, List<int>)> rawRequest(
  int port, {
  String method = 'GET',
  String path = '/',
  Map<String, String> headers = const {},
}) async {
  final socket = await Socket.connect('127.0.0.1', port);
  final lines = <String>[
    '$method $path HTTP/1.1',
    'Host: 127.0.0.1:$port',
    ...headers.entries.map((e) => '${e.key}: ${e.value}'),
    'Connection: close',
    '',
    '',
  ];
  socket.write(lines.join('\r\n'));
  final bytes = <int>[];
  await socket.listen(bytes.addAll).asFuture<void>().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          socket.destroy();
        },
      );
  final text = utf8.decode(bytes, allowMalformed: true);
  return (text, bytes);
}

/// A store that gates `entriesSince` behind a completer, so a test can
/// commit a row while the snapshot is in flight.
final class _GatedStore implements LedgerStore {
  final InMemoryLedgerStore inner;
  Completer<void>? gate;
  int gatesRemaining = 1;

  _GatedStore(String graphId)
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
  Stream<LedgerEntry> entriesSince(int fromSeq) {
    final pending = gate;
    if (pending == null || gatesRemaining <= 0) {
      return inner.entriesSince(fromSeq);
    }
    // Block only the next call - the handler's snapshot - so the
    // membrane's own reads (the router's post-apply range) pass through.
    gatesRemaining--;
    return Stream.fromFuture(pending.future)
        .asyncExpand((_) => inner.entriesSince(fromSeq));
  }

  @override
  Future<void> close() => inner.close();
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  test('Last-Event-ID resumes exclusively, without a query', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [19]));
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [21]));

    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);
    final http = HttpClient();
    addTearDown(http.close);

    final request = await http.getUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/ledger'));
    request.headers.set('Last-Event-ID', '0');
    final response = await request.close();
    expect(response.statusCode, HttpStatus.ok);
    final frames = await readSse(response);

    final ids = frames.map((frame) => frame.id).whereType<String>().toList();
    expect(ids, ['1'], reason: 'seq 0 was already seen; seq 1 resumes');
    expect(ids.where((id) => id == '0'), isEmpty);
  });

  test('?since=0 stays inclusive', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [19]));
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [21]));

    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);
    final http = HttpClient();
    addTearDown(http.close);

    final request = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/skin/ledger?since=0'));
    final response = await request.close();
    final frames = await readSse(response);
    final ids = frames.map((frame) => frame.id).whereType<String>().toList();
    expect(ids, containsAllInOrder(['0', '1']));
  });

  test('no cursor is live-only', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    // A row written before the connection must not be replayed.
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [19]));

    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);
    final http = HttpClient();
    addTearDown(http.close);

    final request = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/skin/ledger'));
    final response = await request.close();
    final framesFuture = readSse(response);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [21]));

    final frames = await framesFuture;
    final ids = frames.map((frame) => frame.id).whereType<String>().toList();
    expect(ids, ['1'], reason: 'only the live row, not the earlier one');
  });

  test('a row committed during the snapshot is delivered exactly once',
      () async {
    final store = _GatedStore('sse-gap');
    final f = await SkinFixture.build(graphId: 'sse-gap', ledgerStore: store);
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [19]));
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [21]));
    // Arm the gate only now: the next entriesSince — the handler's
    // snapshot — blocks until the test releases it.
    store.gate = Completer<void>();

    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);
    final http = HttpClient();
    addTearDown(http.close);

    final request = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/skin/ledger?since=0'));
    final response = await request.close();
    final framesFuture = readSse(response);

    // The handler is now blocked inside entriesSince. Commit one more row.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [23]));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    store.gate!.complete();

    final frames = await framesFuture;
    final ids = frames.map((frame) => frame.id).whereType<String>().toList();
    expect(ids, ['0', '1', '2'],
        reason: 'backlog 0-1 and the gated row 2, each exactly once');
  });

  test('a bad since query is 400; a bad Last-Event-ID is ignored', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);
    final http = HttpClient();
    addTearDown(http.close);

    final badQuery = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/skin/ledger?since=nope'));
    final badQueryResponse = await badQuery.close();
    expect(badQueryResponse.statusCode, HttpStatus.badRequest);
    final body = jsonDecode(
        await badQueryResponse.transform(utf8.decoder).join()) as Map;
    expect(((body['error'] as Map))['code'], 'invalid_since');

    // A garbage header does not 400: with no query it is live-only.
    final badHeader = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/skin/ledger'));
    badHeader.headers.set('Last-Event-ID', 'garbage');
    final badHeaderResponse = await badHeader.close();
    expect(badHeaderResponse.statusCode, HttpStatus.ok);
    final frames = await readSse(badHeaderResponse);
    expect(frames.any((frame) => frame.id != null), isFalse);
  });

  test('frames after detach are real HTTP chunks', () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);

    final (text, _) =
        await rawRequest(adapter.port, path: '/skin/ledger');
    expect(text.toLowerCase(), contains('transfer-encoding: chunked'));
    expect(text.toLowerCase(), isNot(contains('content-length')));
    final headerEnd = text.indexOf('\r\n\r\n');
    final body = text.substring(headerEnd + 4);
    final firstLine = body.split('\r\n').first;
    expect(int.tryParse(firstLine, radix: 16), isNotNull,
        reason: 'the body starts with a hex chunk size');
    expect(body, contains('retry: 1000'));
  });

  test('observe frames carry the ledger id and resume with Last-Event-ID',
      () async {
    final f = await SkinFixture.build();
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);
    final http = HttpClient();
    addTearDown(http.close);

    // Live observe, then apply: the frame carries id: 0.
    final request = await http.getUrl(Uri.parse(
        'http://127.0.0.1:${adapter.port}/skin/observe/home.living.thermostat'));
    final response = await request.close();
    final framesFuture = readSse(response);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await f.run(() => f.client
        .apply('home.living.thermostat', 'setTarget', positional: [19]));
    final frames = await framesFuture;
    final change = frames.firstWhere(
        (frame) => frame.event == 'skin.egress.home.living.thermostat');
    expect(change.id, '0');

    // Reconnect with Last-Event-ID: 0; no new apply → no data frames.
    final resume = await http.getUrl(Uri.parse(
        'http://127.0.0.1:${adapter.port}/skin/observe/home.living.thermostat'));
    resume.headers.set('Last-Event-ID', '0');
    final resumeResponse = await resume.close();
    final resumeFrames =
        await readSse(resumeResponse, idle: const Duration(milliseconds: 150));
    expect(resumeFrames.any((frame) => frame.data.isNotEmpty), isFalse);
  });

  test('a poison payload emits an error frame and keeps the subscription',
      () async {
    CellGraphRegistry.forceReset();
    final poison = Cell.state<double>(initial: 0.0);
    final graph = (CellGraph.builder(graphId: 'sse-poison')
          ..register('home.living.thermostat', poison.cell))
        .build();
    final bindings = SkinBindingTable()
      ..register(SkinBinding(
        cellId: 'home.living.thermostat',
        functionName: 'setTarget',
        target: poison.cell,
        function: (double value) => poison.update(value),
      ));
    final membrane = await SkinMembrane.open(
      graph: graph,
      bindings: bindings,
      journal: RecordingJournal(),
      send: (_) {},
    );
    addTearDown(membrane.close);
    final errors = <Object>[];
    final adapter = await RestAdapter.bind(
      membrane: membrane,
      auth: const AllowAllSkinAuth(),
      onServerError: (error, _) => errors.add(error),
    );
    addTearDown(adapter.close);
    final http = HttpClient();
    addTearDown(http.close);

    final request = await http.getUrl(Uri.parse(
        'http://127.0.0.1:${adapter.port}/skin/observe/home.living.thermostat'));
    final response = await request.close();
    final framesFuture = readSse(response);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    poison.update(double.nan); // jsonEncode throws
    await Future<void>.delayed(const Duration(milliseconds: 50));
    poison.update(1.0);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final frames = await framesFuture;
    final text = frames.map((frame) => '${frame.event} ${frame.data}').join('\n');
    expect(text, contains('skin.error.transport'));
    expect(text, contains('frame_failed'));
    expect(text, contains('1.0'), reason: 'the next good event still arrived');
    expect(errors, isNotEmpty);
    expect(adapter.activeSubscriptions, 1);
  });

  test('a hidden cell stays out of the ledger stream', () async {
    final f = await SkinFixture.build(
      whitelist: SkinWhitelist({
        'home.front.door': {'lock'},
      }),
    );
    addTearDown(() async {
      await f.membrane.close();
      await f.ledger.close();
    });
    final adapter = await RestAdapter.bind(
        membrane: f.membrane, auth: const AllowAllSkinAuth());
    addTearDown(adapter.close);
    final http = HttpClient();
    addTearDown(http.close);

    // Write a row on the hidden thermostat directly: `update` writes a
    // synthetic receipt row without needing exposure.
    await f.run(() => f.thermostat.update(19));

    final request = await http
        .getUrl(Uri.parse('http://127.0.0.1:${adapter.port}/skin/ledger?since=0'));
    final response = await request.close();
    final frames = await readSse(response);
    expect(frames.any((frame) => frame.event == 'skin.ledger.entry'), isFalse);
  });
}
