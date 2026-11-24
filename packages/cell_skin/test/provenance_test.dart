// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Provenance the domain can see.
///
/// A membrane apply runs inside a `SkinCall` zone, so a domain
/// `TestCell.action` reads the authenticated principal before the body
/// runs (and after an await). A pulse-returning binding stamps the
/// recorded pulse with the call's context, so the ledger row stores
/// `actor: skin:<id>` and a principal snapshot, and replay restores it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:cell_skin/cell_skin_rest.dart';
import 'package:test/test.dart';

import 'skin_fixture.dart';

final class _TokenAuth implements SkinAuth {
  final Map<String, SkinPrincipal> users;

  const _TokenAuth(this.users);

  @override
  Future<SkinPrincipal?> authenticate(SkinCredentials credentials) async =>
      users[credentials.token];
}

/// A gate that records the ambient call and lets the test decide.
final class _CallGate extends TestCell<Cell> {
  final List<SkinCall?> seen = [];
  final bool Function(SkinCall? call) allow;
  void Function()? onAction;

  _CallGate(this.allow) : super((object, {host, arguments, user}) => true);

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
    final call = SkinCall.current;
    seen.add(call);
    onAction?.call();
    return allow(call);
  }
}

bool lineageHasActor(Map<String, Object?>? pulseJson, String actor) {
  final context = pulseJson?['context'];
  final lineage = context is Map ? context['lineage'] : null;
  if (lineage is! List) return false;
  return lineage.any((delta) => delta is Map && delta['actor'] == actor);
}

Map<String, Object?>? lineageOthers(Map<String, Object?>? pulseJson) {
  final context = pulseJson?['context'];
  final lineage = context is Map ? context['lineage'] : null;
  if (lineage is! List) return null;
  for (final delta in lineage.reversed) {
    if (delta is Map && delta['__others__'] is Map) {
      return (delta['__others__'] as Map).cast<String, Object?>();
    }
  }
  return null;
}

void main() {
  setUp(CellGraphRegistry.forceReset);

  Future<(int, Map<String, Object?>)> postJson(
    HttpClient http,
    RestAdapter adapter,
    Map<String, Object?> body, {
    String? token,
  }) async {
    final request = await http.postUrl(
        Uri.parse('http://127.0.0.1:${adapter.port}/skin/apply'));
    request.headers.contentType = ContentType.json;
    if (token != null) request.headers.set('Authorization', 'Bearer $token');
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

  Map<String, Object?> applyBody(String cellId, String function,
          List<Object?> positional, {String? correlationId}) =>
      {
        'cellId': cellId,
        'function': function,
        'positional': {
          for (var i = 0; i < positional.length; i++) '$i': positional[i],
        },
        if (correlationId != null) 'correlationId': correlationId,
      };

  test('a REST apply stores actor skin:alice on the ledger pulse', () async {
    final f = await SkinFixture.build(graphId: 'provenance-rest');
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const _TokenAuth({
        'alice-token': SkinPrincipal(id: 'alice', roles: ['operator']),
      }),
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    final (status, body) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'setTarget', [20]),
      token: 'alice-token',
    );
    expect(status, HttpStatus.ok);
    expect((body['outcome'] as Map)['kind'], 'accepted');

    final entries = await f.ledger.entriesSince(0).toList();
    expect(entries, hasLength(1));
    expect(entries.single.receiptCellId, 'home.living.thermostat');
    expect(lineageHasActor(entries.single.pulseJson, 'skin:alice'), isTrue);
    final snapshot = lineageOthers(entries.single.pulseJson);
    expect((snapshot?['skin.principal'] as Map?)?['id'], 'alice');
    await f.ledger.verify();

    CellGraphRegistry.forceReset();
    final thermostat2 = Cell.state<int>(
      initial: 22,
      testRule: ValueGate((v) => v is int && v >= 16 && v <= 26),
    );
    final target = (CellGraph.builder(graphId: 'provenance-rest')
          ..register('home.living.thermostat', thermostat2.cell))
        .build();
    final result = await ReplayEngine.replay(ledger: f.ledger, target: target);
    expect(result.success, isTrue,
        reason: result.divergences.map((d) => d.toString()).join('; '));
    expect(thermostat2.cell.value, 20);
  });

  test('the domain gate sees the principal before the body', () async {
    CellGraphRegistry.forceReset();
    final gate = _CallGate((call) => call?.principal?.id != 'guest');
    final thermostat = Cell.state<int>(initial: 22, testRule: gate);
    final graph = (CellGraph.builder(graphId: 'provenance-gate')
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
      membrane: membrane,
      auth: const _TokenAuth({
        'alice-token': SkinPrincipal(id: 'alice', roles: ['operator']),
        'guest-token': SkinPrincipal(id: 'guest'),
      }),
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
    });

    final (aliceStatus, aliceBody) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'setTarget', [20]),
      token: 'alice-token',
    );
    expect(aliceStatus, HttpStatus.ok);
    expect((aliceBody['outcome'] as Map)['kind'], 'accepted');
    expect(thermostat.cell.value, 20);
    expect(gate.seen.last?.principal?.id, 'alice');
    expect(gate.seen.last?.principal?.roles, ['operator']);

    final before = await ledger.lastSeq;
    final (guestStatus, guestBody) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'setTarget', [17]),
      token: 'guest-token',
    );
    expect(guestStatus, HttpStatus.ok);
    expect((guestBody['outcome'] as Map)['kind'], 'rejected');
    expect(thermostat.cell.value, 20);
    expect(await ledger.lastSeq, before);
  });

  test('the SkinCall zone survives an await inside the binding', () async {
    CellGraphRegistry.forceReset();
    final thermostat = Cell.state<int>(initial: 22);
    var seenAfterAwait = '';
    final graph = (CellGraph.builder(graphId: 'provenance-await')
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
        functionName: 'snooze',
        target: thermostat.cell,
        function: (int target) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          seenAfterAwait = SkinCall.current?.principal?.id ?? 'none';
          return true;
        },
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
      membrane: membrane,
      auth: const _TokenAuth({
        'alice-token': SkinPrincipal(id: 'alice'),
      }),
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
    });

    final (status, _) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'snooze', [1]),
      token: 'alice-token',
    );
    expect(status, HttpStatus.ok);
    expect(seenAfterAwait, 'alice');
  });

  test('an in-process context carries the actor but no principal', () async {
    CellGraphRegistry.forceReset();
    String? gateActor;
    SkinPrincipal? gatePrincipal;
    final gate = _CallGate((call) {
      gateActor = call?.pulseContext.actor;
      gatePrincipal = call?.principal;
      return true;
    });
    final thermostat = Cell.state<int>(initial: 22, testRule: gate);
    final graph = (CellGraph.builder(graphId: 'provenance-context')
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
      ));
    final membrane = await SkinMembrane.open(
      graph: graph,
      bindings: bindings,
      ledger: ledger,
      journal: RecordingJournal(),
      send: (_) {},
    );
    addTearDown(membrane.close);

    final message = await membrane.request(
      WireRequest(
        cellId: 'home.living.thermostat',
        function: 'setTarget',
        positional: {'0': 19},
        correlationId: 'c-context',
      ),
      type: SkinPulseTypes.restApplyRequest,
      context: PulseContext(actor: 'alice', reason: 'evening setback'),
    );
    expect(message, isA<WireResponse>());
    expect(gateActor, 'alice');
    expect(gatePrincipal, isNull);

    final entries = await ledger.entriesSince(0).toList();
    expect(entries, hasLength(1));
    expect(lineageHasActor(entries.single.pulseJson, 'alice'), isTrue);
  });

  test('anonymous callers store skin:anonymous', () async {
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

    final (status, _) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'setTarget', [20]),
    );
    expect(status, HttpStatus.ok);
    final entries = await f.ledger.entriesSince(0).toList();
    expect(entries, hasLength(1));
    expect(lineageHasActor(entries.single.pulseJson, 'skin:anonymous'), isTrue);
    final snapshot = lineageOthers(entries.single.pulseJson);
    expect((snapshot?['skin.principal'] as Map?)?['id'], 'anonymous');
  });

  test('the system context bridge does not bypass the domain gate', () async {
    CellGraphRegistry.forceReset();
    final gate = _CallGate((call) => call?.principal?.id != 'guest');
    final thermostat = Cell.state<int>(initial: 22, testRule: gate);
    final graph = (CellGraph.builder(graphId: 'provenance-bridge')
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
      membrane: membrane,
      auth: const _TokenAuth({'guest-token': SkinPrincipal(id: 'guest')}),
      contextBridge: const SystemContextBridge(),
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
    });

    final before = await ledger.lastSeq;
    final (status, body) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'setTarget', [20]),
      token: 'guest-token',
    );
    expect(status, HttpStatus.ok);
    expect((body['outcome'] as Map)['kind'], 'rejected');
    expect(thermostat.cell.value, 22);
    expect(await ledger.lastSeq, before);
  });

  test('a cached retry does not re-enter the gate', () async {
    CellGraphRegistry.forceReset();
    var gateCalls = 0;
    final gate = _CallGate((call) {
      gateCalls++;
      return true;
    });
    final thermostat = Cell.state<int>(initial: 22, testRule: gate);
    final graph = (CellGraph.builder(graphId: 'provenance-retry')
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
      membrane: membrane,
      auth: const _TokenAuth({'alice-token': SkinPrincipal(id: 'alice')}),
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
    });

    final body = applyBody('home.living.thermostat', 'setTarget', [20],
        correlationId: 'retry-1');
    await postJson(http, adapter, body, token: 'alice-token');
    await postJson(http, adapter, body, token: 'alice-token');
    expect(gateCalls, 1);
    expect(await ledger.lastSeq, 0);
  });

  test('inner command rows carry the caller', () async {
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding.command(
          cellId: 'home.living.light',
          functionName: 'optimize',
          target: targets.light.cell,
          function: () async {
            await Cell.txApply().execute(
              participants: [targets.light.cell, targets.lightColor.cell],
              body: (tx) {
                targets.light.cell.apply<Object?>(
                  (
                    function: () => SkinPulses.payload(0.5),
                    arguments:
                        (positionalArguments: null, namedArguments: null),
                    compensation: null,
                  ),
                  tx: tx,
                );
                targets.lightColor.cell.apply<Object?>(
                  (
                    function: () => SkinPulses.payload('#FDB813'),
                    arguments:
                        (positionalArguments: null, namedArguments: null),
                    compensation: null,
                  ),
                  tx: tx,
                );
              },
            );
            return true;
          },
        ),
      ],
    );
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const _TokenAuth({'alice-token': SkinPrincipal(id: 'alice')}),
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    final (status, _) = await postJson(
      http,
      adapter,
      applyBody('home.living.light', 'optimize', const []),
      token: 'alice-token',
    );
    expect(status, HttpStatus.ok);
    final entries = await f.ledger.entriesSince(0).toList();
    expect(entries, hasLength(2));
    for (final entry in entries) {
      expect(lineageHasActor(entry.pulseJson, 'skin:alice'), isTrue,
          reason: 'row ${entry.seq} should carry the caller');
    }
  });

  test('a raw bare pulse is not stamped and the door gate still refuses',
      () async {
    final f = await SkinFixture.build(
      extraBindings: (targets) => [
        SkinBinding(
          cellId: 'home.living.thermostat',
          functionName: 'rawSet',
          target: targets.thermostat.cell,
          function: (int target) => Pulse<int>(target),
        ),
      ],
    );
    final adapter = await RestAdapter.bind(
      membrane: f.membrane,
      auth: const _TokenAuth({'alice-token': SkinPrincipal(id: 'alice')}),
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close();
      await adapter.close();
      await f.membrane.close();
      await f.ledger.close();
    });

    final (status, _) = await postJson(
      http,
      adapter,
      applyBody('home.living.thermostat', 'rawSet', [19]),
      token: 'alice-token',
    );
    expect(status, HttpStatus.ok);
    final entries = await f.ledger.entriesSince(0).toList();
    expect(entries, hasLength(1));
    expect(lineageHasActor(entries.single.pulseJson, 'skin:alice'), isFalse);

    // The raw lock closure is still the one the door gate identity-checks.
    final (lockStatus, lockBody) = await postJson(
      http,
      adapter,
      applyBody('home.front.door', 'lock', const []),
      token: 'alice-token',
    );
    expect(lockStatus, HttpStatus.ok);
    expect((lockBody['outcome'] as Map)['kind'], 'rejected');
    expect(f.door.cell.value, isFalse);
  });

  test('an unledgered membrane still exposes the caller to the gate',
      () async {
    CellGraphRegistry.forceReset();
    final gate = _CallGate((call) => call?.principal?.id == 'alice');
    final thermostat = Cell.state<int>(initial: 22, testRule: gate);
    final graph = (CellGraph.builder(graphId: 'provenance-unledgered')
          ..register('home.living.thermostat', thermostat.cell))
        .build();
    final bindings = SkinBindingTable()
      ..register(SkinBinding.state(
        cellId: 'home.living.thermostat',
        functionName: 'setTarget',
        target: thermostat.cell,
        nextValue: (int target) => target,
      ));
    final membrane = await SkinMembrane.open(
      graph: graph,
      bindings: bindings,
      journal: RecordingJournal(),
      send: (_) {},
    );
    addTearDown(membrane.close);

    final outcome = await SkinClient(membrane: membrane).apply(
      'home.living.thermostat',
      'setTarget',
      positional: [20],
      principal: const SkinPrincipal(id: 'alice'),
    );
    expect(outcome, isA<ApplyAccepted<Object?>>());
    expect(thermostat.cell.value, 20);
    expect(gate.seen.last?.principal?.id, 'alice');
  });
}
