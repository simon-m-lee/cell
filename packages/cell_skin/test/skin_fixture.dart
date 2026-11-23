// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Shared fixture: a tiny smart-home graph skinned by the membrane.
library;

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';

/// A value predicate gate that only inspects plain values and pulses;
/// the framework consults the same generic `call` for the link and
/// action channels (link cells and functions), which must pass.
final class ValueGate extends TestCell<Cell> {
  final bool Function(Object? value) predicate;

  ValueGate(this.predicate) : super((object, {host, arguments, user}) => true);

  @override
  FutureOr<bool> call(dynamic object, {Cell? host, dynamic arguments}) {
    if (object is Cell || object is Function) return true;
    if (object is Pulse) return predicate(object.payload);
    return predicate(object);
  }
}

/// The domain gate for the demo's door: `lock` is rejected while an
/// occupant is home. This is the framework's real `TestCell.action`
/// firing — the rejection reason comes from the framework's apply
/// path, not from the skin.
final class DoorGate extends TestCell<Cell> {
  final Function lockFunction;
  bool occupantHome = true;

  DoorGate(this.lockFunction)
      : super((object, {host, arguments, user}) => true);

  @override
  FutureOr<bool> call(dynamic object, {Cell? host, dynamic arguments}) {
    // The pulse channel: the state itself must not lock with someone home.
    if (object is Pulse) {
      if (object.payload == true && occupantHome) return false;
      return true;
    }
    return super.call(object, host: host, arguments: arguments);
  }

  @override
  FutureOr<bool> action(
    Function action, {
    required Cell host,
    Arguments? arguments,
    ApplyCommand? command,
  }) {
    // The domain gate: the lock function is refused while occupied.
    if (identical(action, lockFunction) && occupantHome) return false;
    return super
        .action(action, host: host, arguments: arguments, command: command);
  }
}

/// The live handles a custom binding builder may close over.
final class SkinFixtureTargets {
  final StateHandle<int> thermostat;
  final StateHandle<bool> door;
  final StateHandle<double> light;
  final StateHandle<String> lightColor;

  const SkinFixtureTargets({
    required this.thermostat,
    required this.door,
    required this.light,
    required this.lightColor,
  });
}

/// A ready-to-use membrane over a smart-home graph.
final class SkinFixture {
  final CellGraph graph;
  final Ledger ledger;
  final SkinBindingTable bindings;
  final SkinMembrane membrane;
  final SkinClient client;

  final StateHandle<int> thermostat;
  final StateHandle<bool> door;
  final StateHandle<bool> occupant;
  final StateHandle<double> light;
  final StateHandle<String> lightColor;

  final DoorGate doorGate;

  /// Every pulse the membrane sent to the (in-memory) transport.
  final List<Pulse<WireMessage>> sent = [];
  SkinFixture._({
    required this.graph,
    required this.ledger,
    required this.bindings,
    required this.membrane,
    required this.client,
    required this.thermostat,
    required this.door,
    required this.occupant,
    required this.light,
    required this.lightColor,
    required this.doorGate,
  });

  /// Builds the fixture. The caller owns the graph/ledger lifecycle.
  ///
  /// [extraBindings] builds custom bindings **before** the membrane
  /// opens — a membrane seals its binding table at `open()`.
  static Future<SkinFixture> build({
    String graphId = 'fixture-home',
    SkinWhitelist? whitelist,
    List<SkinBinding> Function(SkinFixtureTargets targets)? extraBindings,
    void Function(String message)? onPolicyWarning,
  }) async {
    CellGraphRegistry.forceReset();

    final thermostat = Cell.state<int>(
      initial: 22,
      testRule: ValueGate((v) => v is int && v >= 16 && v <= 26),
    );
    final occupant = Cell.state<bool>(initial: true);
    final light = Cell.state<double>(initial: 0.8);
    final lightColor = Cell.state<String>(initial: '#FFFFFF');

    late final StateHandle<bool> door;
    late final bool Function() lockDoor;
    final doorGate = DoorGate(lockDoor = () {
      door.update(true);
      return true;
    });
    door = Cell.state<bool>(initial: false, testRule: doorGate);

    final graph = (CellGraph.builder(graphId: graphId)
          ..register('home.living.thermostat', thermostat.cell)
          ..register('home.living.light', light.cell)
          ..register('home.living.light.color', lightColor.cell)
          ..register('home.front.occupant', occupant.cell)
          ..register('home.front.door', door.cell))
        .build();
    final ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );

    final bindings = SkinBindingTable()
      ..register(SkinBinding(
        cellId: 'home.living.thermostat',
        functionName: 'setTarget',
        target: thermostat.cell,
        function: (int target) => thermostat.update(target),
        argumentSchema: const JsonSchema(
          type: 'object',
          properties: {
            'target': JsonSchema(type: 'integer', minimum: 16, maximum: 26),
          },
          required: ['target'],
        ),
      ))
      ..register(SkinBinding(
        cellId: 'home.front.door',
        functionName: 'lock',
        target: door.cell,
        function: lockDoor,
      ))
      ..register(SkinBinding(
        cellId: 'home.front.door',
        functionName: 'unlock',
        target: door.cell,
        function: () {
          door.update(false);
          return true;
        },
      ))
      ..register(SkinBinding(
        cellId: 'home.living.light',
        functionName: 'dim',
        target: light.cell,
        function: (double brightness) =>
            light.update(brightness.clamp(0.0, 1.0)),
        argumentSchema: const JsonSchema(
          type: 'object',
          properties: {
            'brightness': JsonSchema(type: 'number', minimum: 0, maximum: 1),
          },
          required: ['brightness'],
        ),
      ))
      ..register(SkinBinding(
        cellId: 'home.living.light',
        functionName: 'setColor',
        target: light.cell,
        function: (String hex) => lightColor.update(hex),
      ));
    final extra = extraBindings?.call(SkinFixtureTargets(
      thermostat: thermostat,
      door: door,
      light: light,
      lightColor: lightColor,
    ));
    for (final binding in extra ?? const <SkinBinding>[]) {
      bindings.register(binding);
    }

    final sent = <Pulse<WireMessage>>[];
    final membrane = await SkinMembrane.open(
      graph: graph,
      bindings: bindings,
      whitelist: whitelist,
      ledger: ledger,
      journal: RecordingJournal(),
      send: sent.add,
      onPolicyWarning: onPolicyWarning,
    );

    return SkinFixture._(
      graph: graph,
      ledger: ledger,
      bindings: bindings,
      membrane: membrane,
      client: SkinClient(membrane: membrane),
      thermostat: thermostat,
      door: door,
      occupant: occupant,
      light: light,
      lightColor: lightColor,
      doorGate: doorGate,
    );
  }

  /// Runs [body] inside the graph's ledger scope, so applies record.
  Future<T> run<T>(FutureOr<T> Function() body) => graph.run(body);

  /// A settle delay for asyncMap dispatch.
  Future<void> settle([int milliseconds = 20]) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));
}
