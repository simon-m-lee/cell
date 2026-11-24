// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Echo Home: the real graph, the real gates, the real bindings.
///
/// Everything here is framework reality — `Cell.state` with real
/// `TestCell` gates, a registered `CellGraph`, a hash-chained
/// `Ledger`, a `SkinMembrane`, and a live `RestAdapter`. Only the
/// energy price feed is mocked (a `Stream.periodic`), as the plan
/// specifies.
library;

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'rest_binding.dart';

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

/// The door's domain gate: `lock` is refused while an occupant is
/// home. The rejection is the framework's real `TestCell.action`.
final class DoorGate extends TestCell<Cell> {
  final Function lockFunction;
  bool occupantHome = true;

  DoorGate(this.lockFunction)
      : super((object, {host, arguments, user}) => true);

  @override
  FutureOr<bool> call(dynamic object, {Cell? host, dynamic arguments}) {
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
    if (identical(action, lockFunction) && occupantHome) return false;
    return super
        .action(action, host: host, arguments: arguments, command: command);
  }
}

/// The demo's smart home: cells, graph, ledger, membrane, client.
final class MockHome {
  final String graphId;

  static int _instance = 0;

  late final StateHandle<double> thermostat;
  late final StateHandle<bool> door;
  late final StateHandle<bool> occupant;
  late final StateHandle<double> light;
  late final StateHandle<String> lightColor;
  late final DoorGate doorGate;
  late final Cell energyPrice;
  late final Cell estimatedBill;
  late final Pulse<bool> Function() lockDoor;
  final StreamController<double> _priceFeed =
      StreamController<double>.broadcast();
  Timer? _priceTimer;

  late final CellGraph graph;
  late final Ledger ledger;
  late final SkinBindingTable bindings;
  late final SkinWhitelist whitelist;
  late final SkinMembrane membrane;
  late final SkinClient client;
  DemoRest? rest;

  /// A fresh instance gets a unique graph id so restarting the demo
  /// never collides in the global registry; the replay twin passes the
  /// original's id explicitly (after the registry is reset).
  MockHome({String? graphId}) : graphId = graphId ?? 'echo-home-${_instance++}';

  /// Builds the graph, ledger, bindings, and membrane. Call once.
  Future<void> build() async {
    _buildCellsAndGraph();
    _priceFeed.add(0.14);
    _priceTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _priceFeed.add(0.14));

    ledger = await graph.bindLedger(
      store: InMemoryLedgerStore(
        genesisHash: Ledger.genesisHashOf(graph.id),
      ),
    );

    bindings = SkinBindingTable()
      ..register(SkinBinding(
        cellId: 'home.living.thermostat',
        functionName: 'setTarget',
        target: thermostat.cell,
        // Returning the pulse (not a bool) is the framework's
        // "Successful Transmission" contract: the apply routes the
        // pulse through the target's receptor and the ledger records
        // the entry with the real apply receipt.
        function: (double target) => SkinPulses.payload(target),
        argumentSchema: const JsonSchema(
          type: 'object',
          properties: {
            'target': JsonSchema(type: 'number', minimum: 16, maximum: 26),
          },
          required: ['target'],
        ),
        positionalNames: ['target'],
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
        function: () => SkinPulses.payload(false),
      ))
      ..register(SkinBinding(
        cellId: 'home.living.light',
        functionName: 'dim',
        target: light.cell,
        function: (double brightness) => SkinPulses.payload(brightness),
        argumentSchema: const JsonSchema(
          type: 'object',
          properties: {
            'brightness': JsonSchema(type: 'number', minimum: 0, maximum: 1),
          },
          required: ['brightness'],
        ),
        positionalNames: ['brightness'],
      ))
      ..register(SkinBinding(
        cellId: 'home.living.light.color',
        functionName: 'setColor',
        target: lightColor.cell,
        function: (String hex) => SkinPulses.payload(hex),
        argumentSchema: const JsonSchema(
          type: 'object',
          properties: {
            'hex': JsonSchema(type: 'string'),
          },
          required: ['hex'],
        ),
        positionalNames: ['hex'],
      ))
      ..register(SkinBinding.command(
        cellId: 'home.living.light',
        functionName: 'optimize',
        target: light.cell,
        function: () => _optimize(),
      ));

    whitelist = SkinWhitelist({
      'home.living.thermostat': {'setTarget'},
      'home.front.door': {'lock', 'unlock'},
      'home.living.light': {'dim', 'optimize'},
      'home.living.light.color': {'setColor'},
    });

    membrane = await SkinMembrane.open(
      graph: graph,
      bindings: bindings,
      whitelist: whitelist,
      ledger: ledger,
      journal: RecordingJournal(),
      send: (_) {}, // The REST adapter's SSE streams subscribe directly.
    );
    client = SkinClient(membrane: membrane);
    // `null` on the web — the REST transport needs dart:io.
    rest = await bindDemoRest(membrane: membrane);
  }

  /// Builds only the cells and the registered graph — the shape a
  /// replay target needs (no ledger, no membrane).
  Future<void> buildGraphOnly() async {
    _buildCellsAndGraph();
  }

  void _buildCellsAndGraph() {
    thermostat = Cell.state<double>(
      initial: 22.4,
      testRule: ValueGate((v) => v is double && v >= 16.0 && v <= 26.0),
    );
    occupant = Cell.state<bool>(initial: true);
    light = Cell.state<double>(
      initial: 0.8,
      testRule: ValueGate((v) => v is double && v >= 0.0 && v <= 1.0),
    );
    lightColor = Cell.state<String>(
      initial: '#FFFFFF',
      testRule: ValueGate((v) => v is String && v.startsWith('#')),
    );

    // The one function the door gate identity-checks: the binding and
    // the gate share this exact closure, and it returns the pulse so
    // the ledger records the apply receipt.
    lockDoor = () => SkinPulses.payload(true);
    doorGate = DoorGate(lockDoor);
    door = Cell.state<bool>(initial: false, testRule: doorGate);

    energyPrice = Cell.fromStream<double>(
      _priceFeed.stream,
      journal: RecordingJournal(),
    );
    estimatedBill = Cell.synthesis<Pulse<double>>(
      [thermostat.cell, light.cell, energyPrice],
      aggregator: (cells, emit) {
        final t = _cellValue<double>(cells.elementAt(0)) ?? 22.4;
        final l = _cellValue<double>(cells.elementAt(1)) ?? 0.8;
        return Pulse<double>(_bill(t, l));
      },
    );

    graph = (CellGraph.builder(graphId: graphId)
          ..register('home.living.thermostat', thermostat.cell)
          ..register('home.living.light', light.cell)
          ..register('home.living.light.color', lightColor.cell)
          ..register('home.front.occupant', occupant.cell)
          ..register('home.front.door', door.cell)
          ..register('home.energy.price', energyPrice)
          ..register('home.energy.bill', estimatedBill))
        .build();
  }

  /// The single batched call the plan prefers: two mutations in one
  /// `Cell.txApply` — the wire sees one accepted outcome; the ledger
  /// records two entries from one wire call (atomicity: both or
  /// neither).
  Future<bool> _optimize() async {
    await Cell.txApply().execute(
      participants: [light.cell, lightColor.cell],
      body: (tx) {
        light.cell.apply<Object?>(
          (
            function: () => SkinPulses.payload(0.5),
            arguments: (positionalArguments: null, namedArguments: null),
            compensation: null,
          ),
          tx: tx,
        );
        lightColor.cell.apply<Object?>(
          (
            function: () => SkinPulses.payload('#FDB813'),
            arguments: (positionalArguments: null, namedArguments: null),
            compensation: null,
          ),
          tx: tx,
        );
      },
    );
    return true;
  }

  /// The realistic bill model: every °C and every 10% of light costs
  /// money. 22.4°C / 80% → \$4.20; 19°C / 50% → \$3.55.
  static double _bill(double temp, double light) => double.parse(
      (4.20 - (22.4 - temp) * 0.05 - (0.8 - light) * 1.6).toStringAsFixed(2));

  /// The bill recomputed from the live state cells. The Home pane's
  /// displayed number comes from the real synthesis cell
  /// [estimatedBill]; this getter lets the scripted agent read the
  /// same live values for its closing summary.
  double get currentBill =>
      _bill(thermostat.cell.value ?? 22.4, light.cell.value ?? 0.8);

  static T? _cellValue<T>(Cell cell) =>
      cell is ValueCell<T> ? cell.value : null;

  /// Closes only the graph-only resources of a replay twin (the price
  /// feed controller). The twin has no ledger or membrane.
  Future<void> closeGraphOnly() async {
    await _priceFeed.close();
  }

  /// Shuts down the REST adapter, the membrane, and the price feed.
  /// The graph and ledger belong to the caller.
  Future<void> close() async {
    await rest?.close();
    await membrane.close();
    _priceTimer?.cancel();
    _priceTimer = null;
    await _priceFeed.close();
    await ledger.close();
  }
}
