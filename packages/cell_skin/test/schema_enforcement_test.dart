// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Explicit argument schemas are enforced.
///
/// `required`, `enum`, closed objects, and typed `null` reject with
/// `bad_arguments` (HTTP 422) before the function, the domain gate, or
/// the ledger. Positional calls against non-index schemas need
/// `positionalNames`; a wrong arity is `bad_arguments` too.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

/// A pass-through gate that counts how often `action` ran.
final class _CountingGate extends TestCell<Cell> {
  int actionCalls = 0;

  _CountingGate() : super((object, {host, arguments, user}) => true);

  @override
  FutureOr<bool> call(dynamic object, {Cell? host, dynamic arguments}) =>
      true;

  @override
  FutureOr<bool> action(
    Function action, {
    required Cell host,
    Arguments? arguments,
    ApplyCommand? command,
  }) {
    actionCalls++;
    return true;
  }
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  Future<(int, Map<String, Object?>)> postJson(
    HttpClient http,
    RestAdapter adapter,
    Map<String, Object?> body,
  ) async {
    final request = await http.postUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
    request.headers.contentType = ContentType.json;
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

  test('a missing required argument is 422 and appends nothing', () async {
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

    final before = await f.ledger.lastSeq;
    final (status, body) = await postJson(http, adapter, {
      'cellId': 'home.living.thermostat',
      'function': 'setTarget',
    });
    expect(status, HttpStatus.unprocessableEntity);
    final error = (body['error'] as Map).cast<String, Object?>();
    expect(error['code'], 'bad_arguments');
    expect(error['message'], contains(r'$.target: required'));
    expect(f.thermostat.cell.value, 22);
    expect(await f.ledger.lastSeq, before);
  });

  test('a closed object and enum reject unknown and off values', () async {
    CellGraphRegistry.forceReset();
    var calls = 0;
    final thermostat = Cell.state<int>(initial: 22);
    final graph = (CellGraph.builder(graphId: 'schema-enum')
          ..register('home.living.thermostat', thermostat.cell))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    addTearDown(ledger.close);
    final bindings = SkinBindingTable()
      ..register(SkinBinding(
        cellId: 'home.living.thermostat',
        functionName: 'setMode',
        target: thermostat.cell,
        function: ({required String mode}) {
          calls++;
          return true;
        },
        argumentSchema: const JsonSchema(
          type: 'object',
          properties: {
            'mode': JsonSchema(type: 'string', enumValues: ['eco', 'heat']),
          },
          required: ['mode'],
        ),
      ));
    final membrane = await SkinMembrane.open(
      graph: graph,
      bindings: bindings,
      ledger: ledger,
      journal: RecordingJournal(),
      send: (_) {},
    );
    addTearDown(membrane.close);
    final adapter = await RestAdapter.bind(
        membrane: membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
    });

    Map<String, Object?> body(Map<String, Object?> named) => {
          'cellId': 'home.living.thermostat',
          'function': 'setMode',
          'named': named,
        };

    final (extraStatus, _) =
        await postJson(http, adapter, body({'mode': 'eco', 'extra': true}));
    expect(extraStatus, HttpStatus.unprocessableEntity);
    final (offStatus, _) = await postJson(http, adapter, body({'mode': 'off'}));
    expect(offStatus, HttpStatus.unprocessableEntity);
    expect(calls, 0, reason: 'the function never ran');

    final (okStatus, okBody) =
        await postJson(http, adapter, body({'mode': 'eco'}));
    expect(okStatus, HttpStatus.ok);
    expect((okBody['outcome'] as Map)['kind'], 'accepted');
    expect(calls, 1);
  });

  test('a typed null is 422', () async {
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

    final (status, body) = await postJson(http, adapter, {
      'cellId': 'home.living.thermostat',
      'function': 'setTarget',
      'positional': {'0': null},
    });
    expect(status, HttpStatus.unprocessableEntity);
    final error = (body['error'] as Map).cast<String, Object?>();
    expect(error['code'], 'bad_arguments');
    expect(error['message'], contains('null'));
    expect(f.thermostat.cell.value, 22);
  });

  test('a non-index schema demands positionalNames', () async {
    Future<(int, Map<String, Object?>)> call(bool withNames) async {
      CellGraphRegistry.forceReset();
      final thermostat2 = Cell.state<int>(initial: 22);
      final graph2 = (CellGraph.builder(graphId: 'schema-names-$withNames')
            ..register('home.living.thermostat', thermostat2.cell))
          .build();
      final ledger2 = await graph2.bindLedger(
        store: InMemoryLedgerStore(
          genesisHash: Ledger.genesisHashOf(graph2.id),
        ),
      );
      addTearDown(ledger2.close);
      final bindings = SkinBindingTable()
        ..register(SkinBinding.state(
          cellId: 'home.living.thermostat',
          functionName: 'setTarget',
          target: thermostat2.cell,
          nextValue: (int target) => target,
          argumentSchema: const JsonSchema(
            type: 'object',
            properties: {'target': JsonSchema(type: 'integer')},
            required: ['target'],
          ),
          positionalNames: withNames ? ['target'] : null,
        ));
      final membrane = await SkinMembrane.open(
        graph: graph2,
        bindings: bindings,
        ledger: ledger2,
        journal: RecordingJournal(),
        send: (_) {},
      );
      addTearDown(membrane.close);
      final adapter = await RestAdapter.bind(
          membrane: membrane, auth: const AllowAllSkinAuth());
      final http = HttpClient();
      addTearDown(() async {
        http.close();
        await adapter.close();
      });
      final result = await postJson(http, adapter, {
        'cellId': 'home.living.thermostat',
        'function': 'setTarget',
        'positional': {'0': 19},
      });
      return result;
    }

    final (noNamesStatus, noNamesBody) = await call(false);
    expect(noNamesStatus, HttpStatus.unprocessableEntity);
    expect(
        ((noNamesBody['error'] as Map).cast<String, Object?>())['message'],
        contains('positionalNames'));

    final (namesStatus, _) = await call(true);
    expect(namesStatus, HttpStatus.ok);
  });

  test('an index-keyed schema validates positionals without names', () async {
    CellGraphRegistry.forceReset();
    final thermostat = Cell.state<int>(initial: 22);
    final graph = (CellGraph.builder(graphId: 'schema-index')
          ..register('home.living.thermostat', thermostat.cell))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    addTearDown(ledger.close);
    final bindings = SkinBindingTable()
      ..register(SkinBinding.state(
        cellId: 'home.living.thermostat',
        functionName: 'setIndex',
        target: thermostat.cell,
        nextValue: (int target) => target,
        argumentSchema: const JsonSchema(
          type: 'object',
          properties: {'0': JsonSchema(type: 'integer')},
          required: ['0'],
        ),
      ));
    final membrane = await SkinMembrane.open(
      graph: graph,
      bindings: bindings,
      ledger: ledger,
      journal: RecordingJournal(),
      send: (_) {},
    );
    addTearDown(membrane.close);
    final adapter = await RestAdapter.bind(
        membrane: membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
    });

    Map<String, Object?> body(Object? value) => {
          'cellId': 'home.living.thermostat',
          'function': 'setIndex',
          'positional': {'0': value},
        };

    final (okStatus, _) = await postJson(http, adapter, body(19));
    expect(okStatus, HttpStatus.ok);
    expect(thermostat.cell.value, 19);

    final (badStatus, _) = await postJson(http, adapter, body(true));
    expect(badStatus, HttpStatus.unprocessableEntity);
  });

  test('an out-of-range value stops at the schema, before the gate',
      () async {
    CellGraphRegistry.forceReset();
    final gate = _CountingGate();
    final thermostat = Cell.state<int>(initial: 22, testRule: gate);
    final graph = (CellGraph.builder(graphId: 'schema-range')
          ..register('home.living.thermostat', thermostat.cell))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    addTearDown(ledger.close);
    final bindings = SkinBindingTable()
      ..register(SkinBinding.state(
        cellId: 'home.living.thermostat',
        functionName: 'setTarget',
        target: thermostat.cell,
        nextValue: (int target) => target,
        argumentSchema: const JsonSchema(
          type: 'object',
          properties: {
            'target': JsonSchema(type: 'integer', minimum: 16, maximum: 26),
          },
          required: ['target'],
        ),
        positionalNames: ['target'],
      ));
    final membrane = await SkinMembrane.open(
      graph: graph,
      bindings: bindings,
      ledger: ledger,
      journal: RecordingJournal(),
      send: (_) {},
    );
    addTearDown(membrane.close);
    final adapter = await RestAdapter.bind(
        membrane: membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
    });

    final (status, body) = await postJson(http, adapter, {
      'cellId': 'home.living.thermostat',
      'function': 'setTarget',
      'positional': {'0': 15},
    });
    expect(status, HttpStatus.unprocessableEntity);
    expect(((body['error'] as Map).cast<String, Object?>())['code'],
        'bad_arguments');
    expect(thermostat.cell.value, 22);
    expect(gate.actionCalls, 0,
        reason: 'a schema miss never reaches the domain gate');
  });

  test('a wrong arity is bad_arguments; a body throw stays transport_error',
      () async {
    CellGraphRegistry.forceReset();
    final thermostat = Cell.state<int>(initial: 22);
    final graph = (CellGraph.builder(graphId: 'schema-arity')
          ..register('home.living.thermostat', thermostat.cell))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );
    addTearDown(ledger.close);
    final bindings = SkinBindingTable()
      ..register(SkinBinding(
        cellId: 'home.living.thermostat',
        functionName: 'noArgs',
        target: thermostat.cell,
        function: () => true,
      ))
      ..register(SkinBinding(
        cellId: 'home.living.thermostat',
        functionName: 'boom',
        target: thermostat.cell,
        function: () => throw StateError('boom'),
      ));
    final membrane = await SkinMembrane.open(
      graph: graph,
      bindings: bindings,
      ledger: ledger,
      journal: RecordingJournal(),
      send: (_) {},
    );
    addTearDown(membrane.close);
    final adapter = await RestAdapter.bind(
        membrane: membrane, auth: const AllowAllSkinAuth());
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
    });

    Map<String, Object?> body(String function, {List<Object?>? positional}) =>
        {
          'cellId': 'home.living.thermostat',
          'function': function,
          if (positional != null)
            'positional': {
              for (var i = 0; i < positional.length; i++) '$i': positional[i],
            },
        };

    final (arityStatus, arityBody) =
        await postJson(http, adapter, body('noArgs', positional: [1]));
    expect(arityStatus, HttpStatus.unprocessableEntity);
    final arityError = (arityBody['error'] as Map).cast<String, Object?>();
    expect(arityError['code'], 'bad_arguments');
    expect(arityError['message'], isNot(contains('NoSuchMethodError')));
    expect(arityError['message'], isNot(contains('Closure')));

    final (boomStatus, boomBody) = await postJson(http, adapter, body('boom'));
    expect(boomStatus, HttpStatus.internalServerError);
    final boomError = (boomBody['error'] as Map).cast<String, Object?>();
    expect(boomError['code'], 'transport_error');
    expect(boomError['message'], isNot(contains('boom')));
  });

  test('an open failure: a positional name outside the closed schema', () {
    CellGraphRegistry.forceReset();
    final thermostat = Cell.state<int>(initial: 22);
    final graph = (CellGraph.builder(graphId: 'schema-open')
          ..register('home.living.thermostat', thermostat.cell))
        .build();
    final bindings = SkinBindingTable()
      ..register(SkinBinding.state(
        cellId: 'home.living.thermostat',
        functionName: 'setTarget',
        target: thermostat.cell,
        nextValue: (int target) => target,
        argumentSchema: const JsonSchema(
          type: 'object',
          properties: {'target': JsonSchema(type: 'integer')},
          required: ['target'],
        ),
        positionalNames: ['nope'],
      ));
    expect(
      () => SkinMembrane.open(
        graph: graph,
        bindings: bindings,
        journal: RecordingJournal(),
        send: (_) {},
      ),
      throwsStateError,
    );
  });
}
