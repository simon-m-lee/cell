// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'package:test/test.dart';
import 'package:cell/cell.dart';

class UserData {
  final String name;
  final String email;
  final int age;
  UserData(this.name, this.email, this.age);
}

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

class AccountCell extends CellBase {
  int balance;
  late final void Function(int amount) credit;
  late final void Function(int amount) debit;

  AccountCell({this.balance = 0}) {
    credit = _credit;
    debit = _debit;
  }

  void _credit(int amount) => balance += amount;
  void _debit(int amount) {
    if (amount > balance) throw StateError('insufficient funds');
    balance -= amount;
  }

  @override
  Iterable<Function> get modifiable => {credit, debit, apply};
}

Future<void> delay(int milliseconds) =>
    Future.delayed(Duration(milliseconds: milliseconds));

Pulse<T> taggedPulse<T>(
  T payload, {
  required Cell source,
  Sensitivity? sensitivity,
}) {
  if (sensitivity == null) {
    return Pulse<T>(payload, source: source);
  }
  return Pulse<T>.governed(
    payload: payload,
    source: source,
    context: PulseContext(
      sensitivity: sensitivity,
      actor: 'test_user',
    ),
  );
}

void main() {
  group('Phase 4: Advanced & Transactions', () {
    group('Cell.sanitized', () {
      test('sanitized redacts sensitive data', () async {
        final source = Cell.ingress<String>();
        final sanitized = Cell.sanitized(
          source.cell,
          redact: (Pulse pulse) {
            final email = pulse.payload as String;
            final parts = email.split('@');
            if (parts.length == 2) {
              return Pulse('${parts[0].substring(0, 2)}***@${parts[1]}');
            }
            return Pulse('***');
          },
          minSensitivity: Sensitivity.confidential,
        );
        final rec = Recorder(sanitized);

        await source.ingest(
          taggedPulse(
            'sensitive@email.com',
            source: source.cell,
            sensitivity: Sensitivity.confidential,
          ),
        );
        await delay(10);
        expect(rec.payloads, ['se***@email.com']);
      });

      test('sanitized passes through non-sensitive data', () async {
        final source = Cell.ingress<String>();
        final sanitized = Cell.sanitized(
          source.cell,
          redact: (Pulse pulse) {
            final email = pulse.payload as String;
            final parts = email.split('@');
            if (parts.length == 2) {
              return Pulse('${parts[0].substring(0, 2)}***@${parts[1]}');
            }
            return Pulse('***');
          },
          minSensitivity: Sensitivity.confidential,
        );
        final rec = Recorder(sanitized);

        await source.ingest(
          taggedPulse(
            'public@email.com',
            source: source.cell,
            sensitivity: Sensitivity.public,
          ),
        );
        await delay(10);
        expect(rec.payloads, ['public@email.com']);
      });

      test('sanitized with different sensitivity threshold', () async {
        final source = Cell.ingress<String>();
        final sanitized = Cell.sanitized(
          source.cell,
          redact: (Pulse pulse) => Pulse('REDACTED'),
          minSensitivity: Sensitivity.internal,
        );
        final rec = Recorder(sanitized);

        await source.ingest(
          taggedPulse(
            'internal@email.com',
            source: source.cell,
            sensitivity: Sensitivity.internal,
          ),
        );
        await delay(10);
        expect(rec.payloads, ['REDACTED']);
      });

      test('sanitized with ingress and observe', () async {
        final ingress = Cell.ingress<String>();
        final sanitized = Cell.sanitized(
          ingress.cell,
          redact: (Pulse pulse) {
            final value = pulse.payload as String;
            if (value.length > 5) {
              return Pulse('${value.substring(0, 3)}...');
            }
            return Pulse(value);
          },
          minSensitivity: Sensitivity.public,
        );
        var receivedValue = '';
        final observer = Cell.observe(
          source: sanitized,
          effect: (Pulse pulse) {
            receivedValue = pulse.payload as String;
          },
        );

        // emit() has no sensitivity, so redaction does not run.
        ingress.emit('Hello World');
        await delay(10);
        expect(receivedValue, 'Hello World');

        await ingress.ingest(
          taggedPulse(
            'Hello World',
            source: ingress.cell,
            sensitivity: Sensitivity.public,
          ),
        );
        await delay(10);
        expect(receivedValue, 'Hel...');
        observer.stop();
      });

      test('sanitized with state and observe', () async {
        final source = Cell.state<String>(initial: '');
        final sanitized = Cell.sanitized(
          source.cell,
          redact: (Pulse pulse) => Pulse('***'),
          minSensitivity: Sensitivity.confidential,
        );
        var receivedValue = '';
        final observer = Cell.observe(
          source: sanitized,
          effect: (Pulse pulse) {
            receivedValue = pulse.payload as String;
          },
        );

        // state.update has no sensitivity → pass-through.
        source.update('Secret Data');
        await delay(10);
        expect(receivedValue, 'Secret Data');
        observer.stop();
      });

      test('sanitized with complex object type', () async {
        final source = Cell.ingress<UserData>();
        final sanitized = Cell.sanitized(
          source.cell,
          redact: (Pulse pulse) {
            final data = pulse.payload as UserData;
            return Pulse(
              UserData(
                data.name,
                data.email.replaceAll(RegExp(r'.(?=@)'), '*'),
                data.age,
              ),
            );
          },
          minSensitivity: Sensitivity.confidential,
        );
        final rec = Recorder(sanitized);

        await source.ingest(
          taggedPulse(
            UserData('Alice', 'alice@example.com', 30),
            source: source.cell,
            sensitivity: Sensitivity.confidential,
          ),
        );
        await delay(10);

        final result = rec.payloads.first as UserData;
        expect(result.name, 'Alice');
        expect(result.email, isNot('alice@example.com'));
        expect(result.email, contains('@example.com'));
        expect(result.age, 30);
      });

      test('sanitized with multiple sensitivity levels', () async {
        final source = Cell.ingress<String>();
        final sanitized = Cell.sanitized(
          source.cell,
          redact: (Pulse pulse) => Pulse('REDACTED_${pulse.payload}'),
          minSensitivity: Sensitivity.restricted,
        );
        final rec = Recorder(sanitized);

        await source.ingest(
          taggedPulse(
            'test@email.com',
            source: source.cell,
            sensitivity: Sensitivity.public,
          ),
        );
        await delay(10);
        expect(rec.payloads.last, 'test@email.com');

        await source.ingest(
          taggedPulse(
            'test@email.com',
            source: source.cell,
            sensitivity: Sensitivity.confidential,
          ),
        );
        await delay(10);
        expect(rec.payloads.last, 'test@email.com');

        await source.ingest(
          taggedPulse(
            'test@email.com',
            source: source.cell,
            sensitivity: Sensitivity.restricted,
          ),
        );
        await delay(10);
        expect(rec.payloads.last, 'REDACTED_test@email.com');
      });
    });

    group('Cell.open', () {
      test('open creates a manually controllable cell', () {
        final openCell = Cell.open(
          context: Context.module('OpenModule'),
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        expect(openCell, isA<OpenCell>());
        expect(openCell, isA<Cell>());
      });

      test('open with emit sends pulses', () async {
        final openCell = Cell.open(
          context: Context.module('OpenModule'),
          receptor: Receptor((cell, pulse, {user}) {
            return Pulse((pulse.payload as int) * 2);
          }),
        );
        final rec = Recorder(openCell);

        final result = await openCell.emit(Pulse<int>(5));
        expect(result, isNotNull);
        expect((result as Pulse).payload, 10);
        expect(rec.payloads, [10]);
      });

      test('open with ingest and serialized completion', () async {
        final openCell = Cell.open(
          context: Context.module('OpenModule'),
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        final rec = Recorder(openCell);

        await openCell.ingest(Pulse<int>(42), serializedCompletion: true);
        await delay(20);
        expect(rec.payloads, [42]);
      });

      test('open with link and unlink observers', () async {
        final openCell = Cell.open(
          context: Context.module('OpenModule'),
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        final sink = Cell.open(
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        final rec = Recorder(sink);

        final unlink = await openCell.link(sink);
        expect(unlink, isNotNull);

        await openCell.emit(Pulse<int>(42));
        await delay(10);
        expect(rec.payloads, [42]);

        unlink!();
        await openCell.emit(Pulse<int>(100));
        await delay(10);
        expect(rec.payloads, [42]);
      });

      test('open with observe receives pulses', () async {
        final openCell = Cell.open(
          context: Context.module('OpenModule'),
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        var receivedValue = 0;
        final observer = Cell.observe(
          source: openCell,
          effect: (Pulse pulse) {
            receivedValue = pulse.payload as int;
          },
        );

        await openCell.emit(Pulse<int>(42));
        expect(receivedValue, 42);
        observer.stop();
      });

      test('open with test rule filters pulses', () async {
        final testRule = TestCell<Cell>((object, {host, arguments, user}) {
          final payload = object is Pulse ? object.payload : object;
          if (payload is int) return payload > 0;
          return true;
        });
        final openCell = Cell.open(
          context: Context.module('OpenModule'),
          receptor: Receptor((cell, pulse, {user}) => pulse),
          testRule: testRule,
        );

        expect(await openCell.emit(Pulse<int>(5)), isNotNull);
        expect(await openCell.emit(Pulse<int>(-1)), isNull);
        expect(await openCell.emit(Pulse<int>(10)), isNotNull);
      });

      test('open with state receives updates', () async {
        final openCell = Cell.open(
          context: Context.module('OpenModule'),
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        final target = Cell.state<int>(initial: 0);
        final observer = Cell.observe(
          source: openCell,
          effect: (Pulse pulse) {
            target.update(pulse.payload);
          },
        );

        await openCell.emit(Pulse<int>(42));
        expect(target.cell.value, 42);
        observer.stop();
      });

      test('open with forceLock serializes emissions', () async {
        final openCell = Cell.open(
          context: Context.module('OpenModule'),
          forceLock: true,
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        final results = <int>[];
        final observer = Cell.observe(
          source: openCell,
          effect: (Pulse pulse) {
            results.add(pulse.payload as int);
          },
        );

        await openCell.emit(Pulse<int>(1));
        await openCell.emit(Pulse<int>(2));
        await openCell.emit(Pulse<int>(3));
        expect(results, [1, 2, 3]);
        observer.stop();
      });

      test('open with ephemeral policy auto-invalidates', () async {
        final policy = EphemeralPolicy(
          eventLimit: 1,
          duration: Duration(milliseconds: 50),
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: 1),
          onInvalidate: (nucleus) => true,
        );
        final openCell = Cell.open(
          context: Context.module('OpenModule'),
          ephemeralPolicy: policy,
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );

        expect(openCell.isInvalidated, false);
        expect(await openCell.emit(Pulse<int>(42)), isNotNull);
      });

      test('open with governed context', () {
        final context = Context.secureEnclave(
          partOf: 'TestEnclave',
          compliances: 'PCI-DSS',
        );
        final openCell = Cell.open(
          context: context,
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );

        expect(openCell.context, context);
        // isGoverned follows the receptor, not Context.secureEnclave.
        expect(openCell.isGoverned, false);
      });

      test('async emit and ingest deliver the pulse', () async {
        final openCell = Cell.open(
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        expect(openCell.async, isA<OpenCellAsync>());
        final rec = Recorder(openCell);
        expect(await openCell.async.emit(Pulse<int>(4)), isTrue);
        await openCell.async.ingest(
          Pulse<int>(5),
          serializedCompletion: true,
        );
        expect(rec.payloads, [4, 5]);
      });

      test('async emit with forceLock still delivers', () async {
        final openCell = Cell.open(
          forceLock: true,
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        final rec = Recorder(openCell);
        expect(await openCell.async.emit(Pulse<int>(7)), isTrue);
        expect(rec.payloads, [7]);
      });

      test('modifiable includes emit, ingest, link, and apply', () {
        final openCell = Cell.open();
        expect(openCell.modifiable, containsAll([
          openCell.emit,
          openCell.ingest,
          openCell.link,
          openCell.apply,
        ]));
      });

      test('emit awaits an async testRule', () async {
        final openCell = Cell.open(
          receptor: Receptor((cell, pulse, {user}) => pulse),
          testRule: TestCell((object, {host, arguments, user}) async {
            await Future<void>.delayed(Duration.zero);
            if (object is Pulse) return object.payload != 0;
            return true;
          }),
        );
        expect(await openCell.emit(Pulse<int>(1)), isNotNull);
        expect(await openCell.emit(Pulse<int>(0)), isNull);
      });

      test('link awaits an async testRule', () async {
        final openCell = Cell.open(
          testRule: TestCell((object, {host, arguments, user}) async {
            await Future<void>.delayed(Duration.zero);
            return object is! Cell || object.context.type != 'deny';
          }),
        );
        final allowed = await openCell.link(Cell());
        expect(allowed, isNotNull);
        final denied = await openCell.link(
          Cell.governed(context: Context.module('deny')),
        );
        expect(denied, isNull);
      });
    });

    group('Combined Operators', () {
      test('ingress + sanitized + observe', () async {
        final ingress = Cell.ingress<String>();
        final sanitized = Cell.sanitized(
          ingress.cell,
          redact: (Pulse pulse) {
            final value = pulse.payload as String;
            if (value.length > 5) {
              return Pulse('${value.substring(0, 3)}...');
            }
            return Pulse(value);
          },
          minSensitivity: Sensitivity.public,
        );
        var receivedValue = '';
        final observer = Cell.observe(
          source: sanitized,
          effect: (Pulse pulse) {
            receivedValue = pulse.payload as String;
          },
        );

        await ingress.ingest(
          taggedPulse(
            'Hello World',
            source: ingress.cell,
            sensitivity: Sensitivity.public,
          ),
        );
        await delay(10);
        expect(receivedValue, 'Hel...');
        observer.stop();
      });

      test('state + sanitized + observe', () async {
        final source = Cell.state<String>(initial: '');
        final sanitized = Cell.sanitized(
          source.cell,
          redact: (Pulse pulse) => Pulse('***'),
          minSensitivity: Sensitivity.confidential,
        );
        var receivedValue = '';
        final observer = Cell.observe(
          source: sanitized,
          effect: (Pulse pulse) {
            receivedValue = pulse.payload as String;
          },
        );

        source.update('Secret Data');
        await delay(10);
        expect(receivedValue, 'Secret Data');
        observer.stop();
      });

      test('open + state + observe', () async {
        final openCell = Cell.open(
          context: Context.module('OpenModule'),
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        final target = Cell.state<int>(initial: 0);
        final observer = Cell.observe(
          source: openCell,
          effect: (Pulse pulse) {
            target.update(pulse.payload);
          },
        );

        await openCell.emit(Pulse<int>(42));
        expect(target.cell.value, 42);
        observer.stop();
      });

      test('ingress + open + observe', () async {
        final ingress = Cell.ingress<int>();
        final openCell = Cell.open(
          context: Context.module('OpenModule'),
          source: ingress.cell,
          receptor: Receptor((cell, pulse, {user}) {
            return Pulse((pulse.payload as int) * 2);
          }),
        );
        var receivedValue = 0;
        final observer = Cell.observe(
          source: openCell,
          effect: (Pulse pulse) {
            receivedValue = pulse.payload as int;
          },
        );

        ingress.emit(5);
        await delay(10);
        expect(receivedValue, 10);
        observer.stop();
      });

      test('state + transaction + state', () async {
        final source = Cell.state<int>(initial: 10);
        final target = Cell.state<int>(initial: 0);
        final tx = Cell.transaction();

        await tx.begin([source.cell, target.cell]);
        tx.update(source.cell, (tx.read(source.cell) as int) - 5);
        tx.update(target.cell, (tx.read(target.cell) as int) + 5);
        await tx.commit();

        expect(source.cell.value, 5);
        expect(target.cell.value, 5);
      });

      test('txApply with state and compensation', () async {
        final source = AccountCell(balance: 10);
        final target = AccountCell(balance: 0);
        final tx = Cell.txApply();

        await tx.execute(
          participants: [source, target],
          body: (scope) {
            source.apply(
              source.debit,
              positionalArguments: [5],
              tx: scope,
              compensate: source.credit,
              compensatePositional: [5],
            );
            target.apply(
              target.credit,
              positionalArguments: [5],
              tx: scope,
              compensate: target.debit,
              compensatePositional: [5],
            );
          },
        );

        expect(source.balance, 5);
        expect(target.balance, 5);
      });
    });

    group('Edge Cases & Error Handling', () {
      test('sanitized with missing sensitivity passes through', () async {
        final source = Cell.ingress<String>();
        final sanitized = Cell.sanitized(
          source.cell,
          redact: (Pulse pulse) => Pulse('REDACTED'),
          minSensitivity: Sensitivity.confidential,
        );
        final rec = Recorder(sanitized);

        source.emit('test@email.com');
        await delay(10);
        expect(rec.payloads, ['test@email.com']);
      });

      test('open with disabled synapses', () async {
        final openCell = Cell.open(
          context: Context.module('OpenModule'),
          synapses: Synapses.disabled,
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        final sink = Cell.open(
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        final rec = Recorder(sink);

        final unlink = await openCell.link(sink);
        expect(unlink, isNull);

        await openCell.emit(Pulse<int>(42));
        expect(rec.pulses, isEmpty);
      });

      test('transaction with empty participants throws', () async {
        final tx = Cell.transaction();
        await expectLater(tx.begin([]), throwsA(isA<ArgumentError>()));
      });

      test('txApply with empty participants throws', () async {
        final tx = Cell.txApply();
        await expectLater(tx.begin([]), throwsA(isA<ArgumentError>()));
      });

      test('transaction with non-existent savepoint throws', () async {
        final cell = Cell.state<int>(initial: 0);
        final tx = Cell.transaction();
        await tx.begin([cell.cell]);
        tx.update(cell.cell, 10);

        await expectLater(
          tx.rollback(savepoint: 999),
          throwsA(isA<ArgumentError>()),
        );
        await tx.commit();
        expect(cell.cell.value, 10);
      });

      test('sanitized with null redact result', () async {
        final source = Cell.ingress<String>();
        final sanitized = Cell.sanitized(
          source.cell,
          redact: (Pulse pulse) => Pulse('REDACTED'),
          minSensitivity: Sensitivity.confidential,
        );
        final rec = Recorder(sanitized);

        await source.ingest(
          taggedPulse(
            'test',
            source: source.cell,
            sensitivity: Sensitivity.confidential,
          ),
        );
        await delay(10);
        expect(rec.payloads, ['REDACTED']);
      });
    });

    group('toString', () {
      test('sanitized cell toString', () {
        final sanitized = Cell.sanitized(
          Cell.state<int>(initial: 0).cell,
          redact: (Pulse pulse) => Pulse(0),
        );
        expect(sanitized.toString(), contains('Cell'));
      });

      test('open cell toString', () {
        final openCell = Cell.open(
          context: Context.module('OpenModule'),
          receptor: Receptor((cell, pulse, {user}) => pulse),
        );
        expect(openCell.toString(), contains('OpenCell'));
      });

      test('TransactionValidationException toString', () {
        final exception = TransactionValidationException([
          ValidationFailure(
            cell: Cell.state<int>(initial: 0).cell,
            value: -5,
            reason: 'Negative value not allowed',
          ),
        ]);
        expect(exception.toString(), contains('TransactionValidationException'));
        expect(exception.toString(), contains('Negative value not allowed'));
      });

      test('TransactionConflictException toString', () {
        final exception = TransactionConflictException([
          ValidationFailure(
            cell: Cell.state<int>(initial: 0).cell,
            value: 1,
            reason: 'conflict',
          ),
        ]);
        expect(exception.toString(), contains('TransactionConflictException'));
      });

      test('TxApplyException toString', () {
        expect(TxApplyException('boom').toString(), contains('TxApplyException'));
        expect(TxApplyException('boom').toString(), contains('boom'));
      });
    });
  });
}
