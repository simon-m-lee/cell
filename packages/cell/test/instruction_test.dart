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
//
// [Instruction.call] is the public test entry point. Exceptions are caught
// and return null (the pipeline does not crash). [Instruction.chain] / [+]
// run left-to-right and stop on null.
// ─────────────────────────────────────────────────────────────────────────

/// A public [Instruction] whose [call] always throws, including the
/// no-future fallback the chain uses after a `future:` invocation fails.
class _ThrowingInstruction implements Instruction<Cell, Pulse, Pulse> {
  @override
  Pulse? call(
    Pulse pulse, {
    Cell? cell,
    void Function({required Pulse? result, required dynamic token})? future,
    dynamic token,
  }) {
    throw StateError('stage failed');
  }

  @override
  Instruction<Cell, Pulse, Pulse> operator +(covariant Instruction other) {
    return Instruction.chain([this, other]);
  }
}

void main() {
  group('Instruction', () {
    group('Construction', () {
      test('transforms the payload', () {
        final doubleIt = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as int) * 2);
        });
        expect(doubleIt.call(Pulse<int>(21))?.payload, 42);
      });

      test('returning null drops the pulse', () {
        final positive = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          final value = pulse.payload as int;
          return value > 0 ? pulse : null;
        });
        expect(positive.call(Pulse<int>(3)), isNotNull);
        expect(positive.call(Pulse<int>(-1)), isNull);
      });

      test('user metadata is passed to the instruction', () {
        dynamic seenUser;
        final inst = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          seenUser = user;
          final scale = user as int? ?? 1;
          return Pulse((pulse.payload as int) * scale);
        }, user: 3);
        expect(inst.call(Pulse<int>(4))?.payload, 12);
        expect(seenUser, 3);
      });

      test('host cell is passed through', () {
        Cell? seen;
        final host = Cell();
        final inst = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          seen = cell;
          return pulse;
        });
        inst.call(Pulse<int>(1), cell: host);
        expect(identical(seen, host), isTrue);
      });

      test('exception terminates with null', () {
        final boom = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          throw ArgumentError('nope');
        });
        expect(boom.call(Pulse<int>(1)), isNull);
      });

      test('can return the same pulse instance', () {
        final inst = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) => pulse);
        final pulse = Pulse<int>(7);
        expect(identical(inst.call(pulse), pulse), isTrue);
      });
    });

    group('Composition', () {
      test('+ runs left then right', () {
        final trim = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as String).trim());
        });
        final upper = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as String).toUpperCase());
        });
        expect((trim + upper).call(Pulse<String>('  hi  '))?.payload, 'HI');
      });

      test('Instruction.chain matches +', () {
        final trim = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as String).trim());
        });
        final upper = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as String).toUpperCase());
        });
        expect(
          Instruction.chain([trim, upper]).call(Pulse<String>('  hi  '))?.payload,
          'HI',
        );
      });

      test('null short-circuits later stages', () {
        var ranSecond = false;
        final drop = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) => null);
        final second = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          ranSecond = true;
          return pulse;
        });
        expect((drop + second).call(Pulse<int>(1)), isNull);
        expect(ranSecond, isFalse);
      });

      test('chains nest and stay Instruction', () {
        final addOne = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as int) + 1);
        });
        final timesTen = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as int) * 10);
        });
        final nested = (addOne + addOne) + timesTen;
        expect(nested, isA<Instruction>());
        expect(nested, isA<InstructionChain>());
        expect(nested.call(Pulse<int>(3))?.payload, 50);
      });

      test('exception in a stage terminates the chain', () {
        var ranSecond = false;
        final boom = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          throw StateError('bad');
        });
        final second = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          ranSecond = true;
          return pulse;
        });
        expect((boom + second).call(Pulse<int>(1)), isNull);
        expect(ranSecond, isFalse);
      });

      test('custom strategy replaces sequential execution', () {
        final trim = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as String).trim());
        });
        final upper = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as String).toUpperCase());
        });
        Pulse? noFuture(Pulse pulse, {Cell? cell, dynamic user}) {
          return trim.call(pulse, cell: cell);
        }

        final skipUpper = Instruction<Cell, Pulse, Pulse>.chain(
          [trim, upper],
          strategy: noFuture,
        );
        expect(skipUpper.call(Pulse<String>('  hi  '))?.payload, 'hi');
      });

      test('strategy receives chain user metadata', () {
        dynamic seenUser;
        final identity = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return pulse;
        });
        final chained = Instruction<Cell, Pulse, Pulse>.chain(
          [identity],
          user: 'mandate',
          strategy: (pulse, {cell, user}) {
            seenUser = user;
            return pulse;
          },
        );
        chained.call(Pulse<int>(1));
        expect(seenUser, 'mandate');
      });

      test('a throwing strategy terminates the chain with null', () {
        final identity = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return pulse;
        });
        final chained = Instruction<Cell, Pulse, Pulse>.chain(
          [identity],
          strategy: (pulse, {cell, user}) {
            throw StateError('strategy failed');
          },
        );
        expect(chained.call(Pulse<int>(1)), isNull);
      });

      test('chain.call accepts a future continuation', () {
        final addOne = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as int) + 1);
        });
        expect(
          Instruction.chain([addOne]).call(
            Pulse<int>(3),
            future: ({required result, required token}) {},
          )?.payload,
          4,
        );
      });
    });

    group('Instruction.future', () {
      test('returns null immediately and resumes via future', () async {
        final done = Completer<Pulse?>();
        final inst = Instruction<Cell, Pulse, Pulse>.future(
          (pulse, {cell, future, token, user}) {
            scheduleMicrotask(() {
              future?.call(
                result: Pulse('${pulse.payload}-done'),
                token: token,
              );
            });
            return null;
          },
        );

        final immediate = inst.call(
          Pulse<String>('x'),
          future: ({required result, required token}) {
            done.complete(result);
          },
        );
        expect(immediate, isNull);
        expect((await done.future)?.payload, 'x-done');
      });

      test('user metadata is available on a future instruction', () {
        dynamic seenUser;
        final inst = Instruction<Cell, Pulse, Pulse>.future(
          (pulse, {cell, future, token, user}) {
            seenUser = user;
            return null;
          },
          user: 'later',
        );
        inst.call(Pulse<int>(1), future: ({required result, required token}) {});
        expect(seenUser, 'later');
      });

      test('returning a pulse still emits synchronously', () {
        final inst = Instruction<Cell, Pulse, Pulse>.future(
          (pulse, {cell, future, token, user}) {
            return Pulse((pulse.payload as int) + 1);
          },
        );
        expect(inst.call(Pulse<int>(9))?.payload, 10);
      });

      test('null future callback drops the continuation without printing', () {
        final inst = Instruction<Cell, Pulse, Pulse>.future(
          (pulse, {cell, future, token, user}) {
            future?.call(result: Pulse('${pulse.payload}-later'), token: token);
            return null;
          },
        );
        final printed = <String>[];
        final result = runZoned(
          () => inst.call(Pulse<String>('x')),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => printed.add(line),
          ),
        );
        expect(result, isNull);
        expect(printed, isEmpty);
      });

      test('future instruction in a chain resumes through the chain callback',
          () async {
        final done = Completer<Pulse?>();
        final delayed = Instruction<Cell, Pulse, Pulse>.future(
          (pulse, {cell, future, token, user}) {
            scheduleMicrotask(() {
              future?.call(
                result: Pulse((pulse.payload as int) * 2),
                token: token,
              );
            });
            return null;
          },
        );
        final addOne = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as int) + 1);
        });
        (delayed + addOne).call(
          Pulse<int>(3),
          future: ({required result, required token}) {
            done.complete(result);
          },
        );
        expect((await done.future)?.payload, 6);
      });

      test('a Function resume token is walked without matching a stage',
          () async {
        final delayed = Instruction<Cell, Pulse, Pulse>.future(
          (pulse, {cell, future, token, user}) {
            scheduleMicrotask(() {
              future?.call(result: pulse, token: () {});
            });
            return null;
          },
        );
        final identity = Instruction<Cell, Pulse, Pulse>(
          (pulse, {cell, user}) => pulse,
        );
        (delayed + identity).call(
          Pulse<int>(1),
          future: ({required result, required token}) {},
        );
        await Future<void>.delayed(Duration.zero);
      });
    });

    group('Custom Instruction', () {
      test('a throwing custom stage in a chain terminates with null', () {
        final boom = _ThrowingInstruction();
        final second = Instruction<Cell, Pulse, Pulse>(
          (pulse, {cell, user}) => pulse,
        );
        expect(
          Instruction.chain([boom, second]).call(Pulse<int>(1)),
          isNull,
        );
      });
    });

    group('Receptor integration', () {
      test('Receptor.instruction runs the instruction', () {
        final doubleIt = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as int) * 2);
        });
        final host = Cell();
        final receptor = Receptor.instruction(doubleIt);
        expect(receptor.activate(host), isTrue);
        expect(receptor.call(Pulse<int>(21)) as Pulse?, isA<Pulse>());
        expect((receptor.call(Pulse<int>(21)) as Pulse?)?.payload, 42);
      });
    });
  });
}
