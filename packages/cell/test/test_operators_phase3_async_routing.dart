// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'package:test/test.dart';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// Fixtures
// ─────────────────────────────────────────────────────────────────────────

class Recorder {
  final List<Pulse> pulses = [];

  List<dynamic> get payloads =>
      pulses.map((p) => p.payload).toList(growable: false);

  late final EgressHandle handle;

  Recorder(Cell source) {
    handle = Cell.observe(
      source: source,
      effect: (Pulse p) => pulses.add(p),
    );
  }
}

Future<void> delay(int milliseconds) =>
    Future.delayed(Duration(milliseconds: milliseconds));

SpokeRegistration spoke({
  required String key,
  int priority = 0,
  bool Function(String? type)? match,
  required Pulse? Function(Cell cell, Pulse pulse, {dynamic user}) handler,
}) =>
    (
      key: key,
      priority: priority,
      match: match,
      handler: handler,
      receptor: null,
      context: null,
    );

void main() {
  group('Phase 3: Async & Routing Operators', () {
    group('Cell.asyncMap', () {
      test('asyncMap transforms values from a state cell', () async {
        final source = Cell.state<int>(initial: 0);
        final mapped = Cell.asyncMap<int, int>(
          source.cell,
          (value) async {
            await Future.delayed(Duration(milliseconds: 10));
            return value * 2;
          },
        );
        final rec = Recorder(mapped);

        source.update(5);
        await delay(40);
        expect(rec.payloads, [10]);
      });

      test('asyncMap transforms values from an ingress cell', () async {
        final ingress = Cell.ingress<int>();
        final mapped = Cell.asyncMap<int, int>(
          ingress.cell,
          (value) async {
            await Future.delayed(Duration(milliseconds: 10));
            return value * 2;
          },
        );
        final rec = Recorder(mapped);

        ingress.emit(5);
        await delay(40);
        expect(rec.payloads, [10]);
      });

      test('asyncMap with concurrency 1 processes sequentially', () async {
        final ingress = Cell.ingress<int>();
        final order = <int>[];
        final mapped = Cell.asyncMap<int, int>(
          ingress.cell,
          (value) async {
            await Future.delayed(Duration(milliseconds: 20));
            order.add(value);
            return value * 2;
          },
          concurrency: 1,
        );
        final rec = Recorder(mapped);

        ingress.emit(1);
        ingress.emit(2);
        ingress.emit(3);
        await delay(120);

        expect(order, [1, 2, 3]);
        expect(rec.payloads, [2, 4, 6]);
      });

      test('asyncMap with latestOnly drops older results', () async {
        final ingress = Cell.ingress<int>();
        final mapped = Cell.asyncMap<int, int>(
          ingress.cell,
          (value) async {
            await Future.delayed(
              Duration(milliseconds: value == 1 ? 50 : 10),
            );
            return value * 2;
          },
          latestOnly: true,
        );
        final rec = Recorder(mapped);

        ingress.emit(1);
        await delay(20);
        ingress.emit(2);
        await delay(80);

        expect(rec.payloads, [4]);
      });

      test('asyncMap with exhaust ignores while busy', () async {
        final ingress = Cell.ingress<int>();
        final processed = <int>[];
        final mapped = Cell.asyncMap<int, int>(
          ingress.cell,
          (value) async {
            await Future.delayed(Duration(milliseconds: 50));
            processed.add(value);
            return value * 2;
          },
          exhaust: true,
        );
        final rec = Recorder(mapped);

        ingress.emit(1);
        await delay(10);
        ingress.emit(2);
        await delay(80);

        expect(processed, [1]);
        expect(rec.payloads, [2]);
      });

      test('asyncMap with observe receives results', () async {
        final ingress = Cell.ingress<int>();
        final mapped = Cell.asyncMap<int, int>(
          ingress.cell,
          (value) async {
            await Future.delayed(Duration(milliseconds: 10));
            return value * 2;
          },
        );
        var receivedValue = 0;
        final observer = Cell.observe(
          source: mapped,
          effect: (Pulse pulse) {
            receivedValue = pulse.payload;
          },
        );

        ingress.emit(5);
        await delay(40);
        expect(receivedValue, 10);

        ingress.emit(10);
        await delay(40);
        expect(receivedValue, 20);
        observer.stop();
      });

      test('asyncMap handles errors gracefully (no emission)', () async {
        final ingress = Cell.ingress<int>();
        final mapped = Cell.asyncMap<int, int>(
          ingress.cell,
          (value) async {
            if (value == 2) throw Exception('Test error');
            return value * 2;
          },
        );
        final rec = Recorder(mapped);

        ingress.emit(1);
        await delay(30);
        expect(rec.pulses, hasLength(1));

        ingress.emit(2);
        await delay(30);
        expect(rec.pulses, hasLength(1));

        ingress.emit(3);
        await delay(30);
        expect(rec.payloads, [2, 6]);
      });
    });

    group('Cell.hub', () {
      test('hub routes pulses to spokes based on type', () {
        var incrementOut = 0;
        var doubleOut = 0;
        final hub = Cell.hub(
          spokes: {
            'increment': (cell, pulse, {user}) {
              incrementOut = (pulse.payload as int) + 1;
              return Pulse(incrementOut);
            },
            'double': (cell, pulse, {user}) {
              doubleOut = (pulse.payload as int) * 2;
              return Pulse(doubleOut);
            },
          },
        );

        // emit returns the root pass-through pulse, not the spoke transform.
        final incResult = hub.emit(Pulse<int>(5, type: 'increment'));
        expect(incResult?.payload, 5);
        expect(incrementOut, 6);

        final doubleResult = hub.emit(Pulse<int>(5, type: 'double'));
        expect(doubleResult?.payload, 5);
        expect(doubleOut, 10);
      });

      test('hub with prefix routing uses longest prefix match', () {
        var matchedKey = '';
        final hub = Cell.hub(
          spokes: {
            'user': (cell, pulse, {user}) {
              matchedKey = 'user';
              return pulse;
            },
            'user.profile': (cell, pulse, {user}) {
              matchedKey = 'user.profile';
              return pulse;
            },
          },
          routing: HubRouting.prefix,
        );

        hub.emit(Pulse<String>('data', type: 'user.profile.update'));
        expect(matchedKey, 'user.profile');
      });

      test('hub with pattern routing uses glob matching', () {
        var matchedKey = '';
        final hub = Cell.hub(
          spokes: {
            'user.*': (cell, pulse, {user}) {
              matchedKey = 'user.*';
              return pulse;
            },
            'user.profile': (cell, pulse, {user}) {
              matchedKey = 'user.profile';
              return pulse;
            },
          },
          routing: HubRouting.pattern,
        );

        hub.emit(Pulse<String>('data', type: 'user.settings'));
        expect(matchedKey, 'user.*');
      });

      test('hub with multicast delivers to all matching spokes', () {
        final matchedKeys = <String>[];
        final hub = Cell.hub(
          spokes: {
            'log': (cell, pulse, {user}) {
              matchedKeys.add('log');
              return pulse;
            },
            'audit': (cell, pulse, {user}) {
              matchedKeys.add('audit');
              return pulse;
            },
          },
          routing: HubRouting.multicast,
        );

        hub.emit(Pulse<String>('data', type: 'log'));
        expect(matchedKeys, ['log']);

        hub.emit(Pulse<String>('data', type: 'audit'));
        expect(matchedKeys, ['log', 'audit']);
      });

      test('hub multicast with custom match delivers to every interested spoke',
          () {
        final matchedKeys = <String>[];
        final hub = Cell.hub(
          multicast: true,
          registrations: [
            spoke(
              key: 'log',
              match: (_) => true,
              handler: (cell, pulse, {user}) {
                matchedKeys.add('log');
                return pulse;
              },
            ),
            spoke(
              key: 'audit',
              match: (_) => true,
              handler: (cell, pulse, {user}) {
                matchedKeys.add('audit');
                return pulse;
              },
            ),
          ],
        );

        hub.emit(Pulse<String>('data', type: 'event'));
        expect(matchedKeys, containsAll(['log', 'audit']));
      });

      test('hub with fallback routes unmatched pulses', () {
        var fallbackUsed = false;
        final hub = Cell.hub(
          spokes: {
            'test': (cell, pulse, {user}) {
              fallbackUsed = true;
              return pulse;
            },
          },
          fallback: 'test',
        );

        final result = hub.emit(Pulse<String>('data', type: 'unknown'));
        expect(result, isNotNull);
        expect(fallbackUsed, true);
      });

      test('hub with priority ordering processes higher priority first', () {
        final order = <int>[];
        final hub = Cell.hub(
          multicast: true,
          registrations: [
            spoke(
              key: 'low',
              priority: 10,
              match: (type) => type == 'test',
              handler: (cell, pulse, {user}) {
                order.add(10);
                return pulse;
              },
            ),
            spoke(
              key: 'high',
              priority: 20,
              match: (type) => type == 'test',
              handler: (cell, pulse, {user}) {
                order.add(20);
                return pulse;
              },
            ),
          ],
        );

        hub.emit(Pulse<String>('data', type: 'test'));
        expect(order, [20, 10]);
      });

      test('hub emits async with lock protection', () async {
        final hub = Cell.hub(
          spokes: {
            'test': (cell, pulse, {user}) => pulse,
          },
        );

        final result = await hub.emitAsync(Pulse<String>('data', type: 'test'));
        expect(result, isNotNull);
      });

      test('hub ingest with serialized completion', () async {
        final hub = Cell.hub(
          spokes: {
            'test': (cell, pulse, {user}) => pulse,
          },
        );

        await hub.ingest(
          Pulse<String>('data', type: 'test'),
          serializedCompletion: true,
        );
      });

      test('hub with governed spokes uses DeputyContext', () {
        final context = DeputyContext(
          baseContext: Context.system,
          authority: 'AUDIT',
          role: 'Auditor',
          clearance: Clearance.administrative,
        );

        var handled = false;
        final hub = Cell.hub(
          governedSpokes: {
            context: Receptor((cell, pulse, {user}) {
              handled = true;
              return pulse;
            }),
          },
        );

        hub.emit(Pulse<String>('data', type: context.role ?? 'unknown'));
        expect(handled, true);
      });

      test('hub spoke handler can drive a state cell', () async {
        final target = Cell.state<int>(initial: 0);
        final hub = Cell.hub(
          spokes: {
            'set': (cell, pulse, {user}) {
              target.update(pulse.payload as int);
              return pulse;
            },
          },
        );

        hub.emit(Pulse<int>(42, type: 'set'));
        expect(target.cell.value, 42);
      });
    });

    group('Cell.switchMap', () {
      test('switchMap switches to new cell on source change', () async {
        final source = Cell.ingress<int>();
        final switched = Cell.switchMap<int, String>(
          source.cell,
          (id) => Cell.fromFuture(Future.value('Profile $id')),
        );
        final rec = Recorder(switched);

        source.emit(1);
        await delay(30);
        expect(rec.payloads, ['Profile 1']);

        source.emit(2);
        await delay(30);
        expect(rec.payloads, ['Profile 1', 'Profile 2']);
      });

      test('switchMap with observe receives switched values', () async {
        final source = Cell.ingress<int>();
        final switched = Cell.switchMap<int, String>(
          source.cell,
          (id) => Cell.fromFuture(Future.value('Value from ID $id')),
        );
        var last = '';
        final observer = Cell.observe(
          source: switched,
          effect: (Pulse pulse) {
            last = pulse.payload as String;
          },
        );

        source.emit(2);
        await delay(30);
        expect(last, 'Value from ID 2');
        observer.stop();
      });

      test('switchMap with multiple source changes', () async {
        final source = Cell.ingress<int>();
        final switched = Cell.switchMap<int, String>(
          source.cell,
          (id) => Cell.fromFuture(Future.value('ID $id')),
        );
        final rec = Recorder(switched);

        source.emit(1);
        await delay(20);
        source.emit(2);
        await delay(20);
        source.emit(3);
        await delay(20);

        expect(rec.payloads, ['ID 1', 'ID 2', 'ID 3']);
      });

      test('switchMap with null payload does not switch', () async {
        final source = Cell.ingress<int?>();
        final switched = Cell.switchMap<int?, String>(
          source.cell,
          (id) => Cell.fromFuture(Future.value(id?.toString() ?? 'null')),
        );
        final rec = Recorder(switched);

        source.emit(1);
        await delay(20);
        expect(rec.payloads, ['1']);

        source.emit(null);
        await delay(20);
        expect(rec.payloads, ['1']);
      });
    });

    group('Cell.fromFuture', () {
      test('fromFuture emits future result', () async {
        final cell = Cell.fromFuture(Future.value(42));
        final rec = Recorder(cell);
        await delay(20);
        expect(rec.payloads, [42]);
      });

      test('fromFuture with observe receives value', () async {
        var receivedValue = 0;
        final observer = Cell.observe(
          source: Cell.fromFuture(Future.value(42)),
          effect: (Pulse pulse) {
            receivedValue = pulse.payload;
          },
        );
        await delay(20);
        expect(receivedValue, 42);
        observer.stop();
      });

      test('fromFuture with state cell receives value', () async {
        final target = Cell.state<int>(initial: 0);
        final futureCell = Cell.fromFuture(Future.value(42));
        final observer = Cell.observe(
          source: futureCell,
          effect: (Pulse pulse) {
            target.update(pulse.payload);
          },
        );
        await delay(20);
        expect(target.cell.value, 42);
        observer.stop();
      });

      test('fromFuture with derived cell transforms value', () async {
        final futureCell = Cell.fromFuture(Future.value(42));
        final derived = Cell.derive(
          source: futureCell,
          project: (Pulse pulse) => Pulse('Value: ${pulse.payload}'),
        );
        final rec = Recorder(derived);
        await delay(20);
        expect(rec.payloads, ['Value: 42']);
      });

      test('fromFuture with delayed Future', () async {
        final completer = Completer<int>();
        final rec = Recorder(Cell.fromFuture(completer.future));
        expect(rec.pulses, isEmpty);

        completer.complete(42);
        await delay(20);
        expect(rec.payloads, [42]);
      });

      test('fromFuture emits an error pulse when the Future fails', () async {
        final error = Exception('Test error');
        final rec = Recorder(
          Cell.fromFuture(Future<int>.error(error)),
        );
        await delay(20);
        expect(rec.pulses, hasLength(1));
        expect(rec.pulses.first.type, 'error');
        expect(rec.payloads.first, error);
      });

      test('fromFuture with complex type', () async {
        final rec = Recorder(
          Cell.fromFuture(Future.value({'name': 'Alice', 'age': 30})),
        );
        await delay(20);
        expect(rec.pulses, hasLength(1));
        final result = rec.payloads.first as Map<String, dynamic>;
        expect(result['name'], 'Alice');
        expect(result['age'], 30);
      });

      test('fromFuture with null value', () async {
        final rec = Recorder(Cell.fromFuture(Future<int?>.value(null)));
        await delay(20);
        expect(rec.payloads, [null]);
      });
    });

    group('Cell.fromStream', () {
      test('fromStream emits stream values', () async {
        final rec = Recorder(Cell.fromStream(Stream<int>.fromIterable([1, 2, 3])));
        await delay(20);
        expect(rec.payloads, [1, 2, 3]);
      });

      test('fromStream with observe receives values', () async {
        final receivedValues = <int>[];
        final observer = Cell.observe(
          source: Cell.fromStream(Stream<int>.fromIterable([1, 2, 3])),
          effect: (Pulse pulse) {
            receivedValues.add(pulse.payload);
          },
        );
        await delay(20);
        expect(receivedValues, [1, 2, 3]);
        observer.stop();
      });

      test('fromStream with state cell accumulates values', () async {
        final target = Cell.state<List<int>>(initial: []);
        final streamCell = Cell.fromStream(Stream<int>.fromIterable([1, 2, 3]));
        final observer = Cell.observe(
          source: streamCell,
          effect: (Pulse pulse) {
            final current = target.cell.value ?? [];
            target.update([...current, pulse.payload as int]);
          },
        );
        await delay(20);
        expect(target.cell.value, [1, 2, 3]);
        observer.stop();
      });

      test('fromStream with delayed stream', () async {
        final controller = StreamController<int>();
        final rec = Recorder(Cell.fromStream(controller.stream));

        controller.add(1);
        await delay(10);
        controller.add(2);
        await delay(10);
        controller.add(3);
        await delay(10);

        expect(rec.payloads, [1, 2, 3]);
        await controller.close();
      });

      test('fromStream with periodic stream', () async {
        final rec = Recorder(
          Cell.fromStream(
            Stream.periodic(Duration(milliseconds: 20), (count) => count)
                .take(3),
          ),
        );
        await delay(120);
        expect(rec.payloads, [0, 1, 2]);
      });

      test('fromStream with cancelOnError handles errors', () async {
        final controller = StreamController<int>();
        final rec = Recorder(
          Cell.fromStream(controller.stream, cancelOnError: true),
        );

        controller.add(1);
        await delay(10);
        expect(rec.payloads, [1]);

        controller.addError(Exception('Test error'));
        await delay(10);
        controller.add(2);
        await delay(10);
        expect(rec.payloads, [1]);

        await controller.close();
      });

      test('fromStream with distinct filters duplicates', () async {
        final streamCell =
            Cell.fromStream(Stream<int>.fromIterable([1, 1, 2, 2, 3, 3]));
        final rec = Recorder(Cell.distinct(streamCell));
        await delay(20);
        expect(rec.payloads, [1, 2, 3]);
      });

      test('fromStream with derived transforms values', () async {
        final streamCell =
            Cell.fromStream(Stream<int>.fromIterable([1, 2, 3]));
        final derived = Cell.derive(
          source: streamCell,
          project: (Pulse pulse) => Pulse('Value: ${pulse.payload}'),
        );
        final rec = Recorder(derived);
        await delay(20);
        expect(rec.payloads, ['Value: 1', 'Value: 2', 'Value: 3']);
      });

      test('fromStream with complex types', () async {
        final rec = Recorder(
          Cell.fromStream(
            Stream<Map<String, dynamic>>.fromIterable([
              {'name': 'Alice', 'age': 30},
              {'name': 'Bob', 'age': 25},
            ]),
          ),
        );
        await delay(20);
        expect(rec.pulses, hasLength(2));
        expect((rec.payloads.first as Map)['name'], 'Alice');
        expect((rec.payloads.last as Map)['name'], 'Bob');
      });

      test('fromStream with null values', () async {
        final rec = Recorder(
          Cell.fromStream(Stream<int?>.fromIterable([null, 1, null, 2])),
        );
        await delay(20);
        expect(rec.payloads, [null, 1, null, 2]);
      });

      test('fromStream with empty stream emits nothing', () async {
        final rec = Recorder(Cell.fromStream(Stream<int>.empty()));
        await delay(20);
        expect(rec.pulses, isEmpty);
      });

      test('fromStream cancels the subscription when the cell is invalidated',
          () async {
        var cancelled = false;
        final controller = StreamController<int>(
          onCancel: () {
            cancelled = true;
          },
        );
        final cell = Cell.fromStream(
          controller.stream,
          ephemeralPolicy: EphemeralPolicy(
            eventLimit: 1,
            onEvent: (object,
                    {required cell, required policy, arguments, user}) =>
                (events: policy.events + 1),
            onInvalidate: (nucleus) => true,
          ),
        );
        final rec = Recorder(cell);

        controller.add(1);
        await delay(20);
        expect(rec.payloads, [1]);
        expect(cancelled, isTrue);

        controller.add(2);
        await delay(20);
        expect(rec.payloads, [1]);
        await controller.close();
      });
    });

    group('Combined Operators', () {
      test('ingress + asyncMap + observe', () async {
        final ingress = Cell.ingress<int>();
        final mapped = Cell.asyncMap<int, int>(
          ingress.cell,
          (value) async {
            await Future.delayed(Duration(milliseconds: 10));
            return value * 2;
          },
        );
        var receivedValue = 0;
        final observer = Cell.observe(
          source: mapped,
          effect: (Pulse pulse) {
            receivedValue = pulse.payload;
          },
        );

        ingress.emit(5);
        await delay(40);
        expect(receivedValue, 10);

        ingress.emit(10);
        await delay(40);
        expect(receivedValue, 20);
        observer.stop();
      });

      test('fromFuture + derive + state', () async {
        final futureCell = Cell.fromFuture(Future.value(42));
        final derived = Cell.derive(
          source: futureCell,
          project: (Pulse pulse) => Pulse('Value: ${pulse.payload}'),
        );
        final target = Cell.state<String>(initial: '');
        final observer = Cell.observe(
          source: derived,
          effect: (Pulse pulse) {
            target.update(pulse.payload);
          },
        );
        await delay(20);
        expect(target.cell.value, 'Value: 42');
        observer.stop();
      });

      test('fromStream + distinct + observe', () async {
        final streamCell =
            Cell.fromStream(Stream<int>.fromIterable([1, 1, 2, 2, 3, 3]));
        final receivedValues = <int>[];
        final observer = Cell.observe(
          source: Cell.distinct(streamCell),
          effect: (Pulse pulse) {
            receivedValues.add(pulse.payload);
          },
        );
        await delay(20);
        expect(receivedValues, [1, 2, 3]);
        observer.stop();
      });

      test('ingress + asyncMap + state', () async {
        final ingress = Cell.ingress<int>();
        final mapped = Cell.asyncMap<int, int>(
          ingress.cell,
          (value) async {
            await Future.delayed(Duration(milliseconds: 10));
            return value * 2;
          },
        );
        final target = Cell.state<int>(initial: 0);
        final observer = Cell.observe(
          source: mapped,
          effect: (Pulse pulse) {
            target.update(pulse.payload);
          },
        );

        ingress.emit(5);
        await delay(40);
        expect(target.cell.value, 10);

        ingress.emit(10);
        await delay(40);
        expect(target.cell.value, 20);
        observer.stop();
      });

      test('fromFuture + asyncMap + observe', () async {
        final mapped = Cell.asyncMap<int, int>(
          Cell.fromFuture(Future.value(5)),
          (value) async {
            await Future.delayed(Duration(milliseconds: 10));
            return value * 3;
          },
        );
        var receivedValue = 0;
        final observer = Cell.observe(
          source: mapped,
          effect: (Pulse pulse) {
            receivedValue = pulse.payload;
          },
        );
        await delay(50);
        expect(receivedValue, 15);
        observer.stop();
      });

      test('fromStream + asyncMap + observe', () async {
        final mapped = Cell.asyncMap<int, int>(
          Cell.fromStream(Stream<int>.fromIterable([1, 2, 3])),
          (value) async {
            await Future.delayed(Duration(milliseconds: 10));
            return value * 2;
          },
        );
        final receivedValues = <int>[];
        final observer = Cell.observe(
          source: mapped,
          effect: (Pulse pulse) {
            receivedValues.add(pulse.payload);
          },
        );
        await delay(80);
        expect(receivedValues, [2, 4, 6]);
        observer.stop();
      });

      test('hub + state for routing', () async {
        final target = Cell.state<int>(initial: 0);
        final hub = Cell.hub(
          spokes: {
            'increment': (cell, pulse, {user}) {
              target.update((pulse.payload as int) + 1);
              return pulse;
            },
            'double': (cell, pulse, {user}) {
              target.update((pulse.payload as int) * 2);
              return pulse;
            },
          },
        );

        hub.emit(Pulse<int>(5, type: 'increment'));
        expect(target.cell.value, 6);

        hub.emit(Pulse<int>(5, type: 'double'));
        expect(target.cell.value, 10);
      });
    });

    group('Edge Cases & Error Handling', () {
      test('asyncMap with empty source emits nothing', () async {
        final mapped = Cell.asyncMap<int, int>(
          Cell.state<int>(initial: 0).cell,
          (value) async => value * 2,
        );
        final rec = Recorder(mapped);
        await delay(20);
        expect(rec.pulses, isEmpty);
      });

      test('hub with no spokes uses fallback', () {
        final hub = Cell.hub(
          spokes: {},
          fallback: 'default',
        );
        expect(hub.root, isA<Cell>());
        expect(hub.spokes, isNotEmpty);
      });

      test('fromFuture with already completed future', () async {
        final rec = Recorder(Cell.fromFuture(Future.value(42)));
        await delay(20);
        expect(rec.payloads, [42]);
      });

      test('fromStream with error after values (no cancelOnError)', () async {
        final controller = StreamController<int>();
        final receivedValues = <int>[];
        final observer = Cell.observe(
          source: Cell.fromStream(controller.stream, cancelOnError: false),
          effect: (Pulse pulse) {
            receivedValues.add(pulse.payload);
          },
        );

        controller.add(1);
        controller.add(2);
        controller.addError(Exception('Test error'));
        controller.add(3);
        await delay(20);

        expect(receivedValues, [1, 2, 3]);
        observer.stop();
        await controller.close();
      });

      test('hub with multicast and priority', () {
        final order = <String>[];
        final hub = Cell.hub(
          multicast: true,
          registrations: [
            spoke(
              key: 'low',
              priority: 10,
              match: (type) => type == 'test',
              handler: (cell, pulse, {user}) {
                order.add('low');
                return pulse;
              },
            ),
            spoke(
              key: 'high',
              priority: 20,
              match: (type) => type == 'test',
              handler: (cell, pulse, {user}) {
                order.add('high');
                return pulse;
              },
            ),
          ],
        );

        hub.emit(Pulse<String>('data', type: 'test'));
        expect(order, ['high', 'low']);
      });

      test('switchMap with source emitting multiple values', () async {
        final source = Cell.ingress<int>();
        final rec = Recorder(
          Cell.switchMap<int, String>(
            source.cell,
            (id) => Cell.fromFuture(Future.value('ID $id received')),
          ),
        );

        source.emit(1);
        await delay(20);
        source.emit(2);
        await delay(20);
        source.emit(3);
        await delay(20);

        expect(rec.payloads, [
          'ID 1 received',
          'ID 2 received',
          'ID 3 received',
        ]);
      });
    });

    group('toString', () {
      test('asyncMap cell toString', () {
        final mapped = Cell.asyncMap<int, int>(
          Cell.state<int>(initial: 0).cell,
          (value) async => value * 2,
        );
        expect(mapped.toString(), contains('Cell'));
      });

      test('hub toString', () {
        final hub = Cell.hub(
          spokes: {
            'test': (cell, pulse, {user}) => pulse,
          },
        );
        expect(hub.root.toString(), contains('Cell'));
      });

      test('switchMap cell toString', () {
        final switched = Cell.switchMap<int, int>(
          Cell.ingress<int>().cell,
          (id) => Cell.fromFuture(Future.value(id)),
        );
        expect(switched.toString(), contains('Cell'));
      });

      test('fromFuture cell toString', () {
        expect(Cell.fromFuture(Future.value(42)).toString(), contains('Cell'));
      });

      test('fromStream cell toString', () {
        expect(
          Cell.fromStream(Stream<int>.empty()).toString(),
          contains('Cell'),
        );
      });
    });
  });
}
