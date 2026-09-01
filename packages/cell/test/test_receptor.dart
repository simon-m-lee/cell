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
// A Receptor is a template until [Receptor.activate] (or Cell construction)
// binds it. [Receptor.call] asserts isActivated. Drive graph-level tests
// with [Cell.ingress] + [Cell.observe]; [ValueCell._emit] is not required.
// ─────────────────────────────────────────────────────────────────────────

class _ThrowingStage implements Instruction<Cell, Pulse, Pulse> {
  @override
  Pulse? call(
    Pulse pulse, {
    Cell? cell,
    void Function({required Pulse? result, required dynamic token})? future,
    dynamic token,
  }) {
    throw StateError('pipeline stage failed');
  }

  @override
  Instruction<Cell, Pulse, Pulse> operator +(covariant Instruction other) {
    return Instruction.chain([this, other]);
  }
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

/// Binds [receptor] to a host cell so [Receptor.call] is legal.
Receptor bindReceptor(Receptor receptor, {Cell? host}) {
  final bound = host ?? Cell();
  expect(receptor.activate(bound), isTrue);
  expect(receptor.isActivated, isTrue);
  return receptor;
}

/// [Receptor.call] is typed [FutureOr]; these tests use the sync path.
Pulse? invoke(Receptor receptor, Pulse pulse) =>
    receptor.call(pulse) as Pulse?;

void main() {
  group('Receptor', () {
    group('passThrough', () {
      test('is a reusable singleton', () {
        expect(identical(Receptor.passThrough, Receptor.passThrough), isTrue);
        expect(Receptor.passThrough, Receptor.passThrough);
      });

      test('forwards the pulse unchanged without activation', () {
        final pulse = Pulse<int>(42);
        final result = Receptor.passThrough.call(pulse);
        expect(identical(result, pulse), isTrue);
        expect(result?.payload, 42);
      });

      test('cannot be activated', () {
        expect(Receptor.passThrough.isActivated, isFalse);
        expect(Receptor.passThrough.activate(Cell()), isFalse);
        expect(Receptor.passThrough.isActivated, isFalse);
      });

      test('clone is the same instance', () {
        expect(identical(Receptor.passThrough.clone, Receptor.passThrough), isTrue);
      });

      test('async is unsupported', () {
        expect(() => Receptor.passThrough.async, throwsUnsupportedError);
      });

      test('cell getter is unsupported', () {
        expect(() => Receptor.passThrough.cell, throwsUnsupportedError);
      });

      test('is never governed', () {
        expect(Receptor.passThrough.isGoverned, isFalse);
      });

      test('passThroughRule is an identity instruction', () {
        final pulse = Pulse<int>(3);
        expect(identical(Receptor.passThroughRule.call(pulse), pulse), isTrue);
      });

      test('passThroughRule + other yields the other instruction', () {
        final doubled = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as int) * 2);
        });
        expect(
          (Receptor.passThroughRule + doubled).call(Pulse<int>(21))?.payload,
          42,
        );
      });

      test('hashCode is stable on the singleton', () {
        expect(Receptor.passThrough.hashCode, Receptor.passThrough.hashCode);
      });

      test('passThrough == a ReceptorBase is true; the reverse is not', () {
        final empty = Receptor.pipeline();
        final transforming = Receptor((cell, pulse, {user}) => pulse);
        // passThrough inspects ReceptorBase._record.$2; named records throw
        // and the catch treats every ReceptorBase as equal.
        expect(Receptor.passThrough == empty, isTrue);
        expect(Receptor.passThrough == transforming, isTrue);
        expect(empty == Receptor.passThrough, isFalse);
        expect(transforming == Receptor.passThrough, isFalse);
      });
    });

    group('Construction', () {
      test('closure receptor transforms payload', () {
        final receptor = bindReceptor(Receptor((cell, pulse, {user}) {
          return Pulse((pulse.payload as int) * 2);
        }));
        expect(invoke(receptor, Pulse<int>(21))?.payload, 42);
      });

      test('closure receptor returning null drops the pulse', () {
        final receptor = bindReceptor(Receptor((cell, pulse, {user}) {
          final value = pulse.payload as int;
          return value > 0 ? pulse : null;
        }));
        expect(invoke(receptor, Pulse<int>(1)), isNotNull);
        expect(invoke(receptor, Pulse<int>(-1)), isNull);
      });

      test('closure receptor exception terminates the pulse', () {
        final receptor = bindReceptor(Receptor((cell, pulse, {user}) {
          throw StateError('boom');
        }));
        expect(invoke(receptor, Pulse<int>(1)), isNull);
      });

      test('Receptor.instruction wraps a reusable instruction', () {
        final doubleIt = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as int) * 2);
        });
        final receptor = bindReceptor(Receptor.instruction(doubleIt));
        expect(invoke(receptor, Pulse<int>(21))?.payload, 42);
      });

      test('Instruction user metadata is available during execution', () {
        dynamic seenUser;
        final instruction = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          seenUser = user;
          return pulse;
        }, user: 'SecurityLog');
        final receptor = bindReceptor(Receptor.instruction(instruction));
        invoke(receptor, Pulse<int>(1));
        expect(seenUser, 'SecurityLog');
      });

      test('Receptor.instruction stores a user factory on the receptor', () {
        final doubleIt = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as int) * 2);
        });
        final receptor = bindReceptor(
          Receptor.instruction(doubleIt, user: () => 'receptor-user'),
        );
        expect(invoke(receptor, Pulse<int>(21))?.payload, 42);
        expect(receptor.hashCode, isA<int>());
      });

      test('Receptor.typed transforms between pulse payload types', () {
        final receptor = bindReceptor(
          Receptor.typed<Cell, Pulse<String>, Pulse<int>>(
            Instruction<Cell, Pulse<String>, Pulse<int>>((pulse, {cell, user}) {
              return Pulse(pulse.payload!.length);
            }),
          ),
        );
        expect(invoke(receptor, Pulse<String>('hello'))?.payload, 5);
      });

      test('empty pipeline is a pass-through', () {
        final receptor = bindReceptor(Receptor.pipeline());
        final pulse = Pulse<int>(7);
        expect(invoke(receptor, pulse)?.payload, 7);
      });
    });

    group('Activation & clone', () {
      test('template is not activated until bound', () {
        final receptor = Receptor((cell, pulse, {user}) => pulse);
        expect(receptor.isActivated, isFalse);
        expect(() => receptor.cell, throwsA(isA<Error>()));
      });

      test('Cell construction activates an unbound template in place', () {
        final template = Receptor((cell, pulse, {user}) => pulse);
        Cell(receptor: template);
        expect(template.isActivated, isTrue);
      });

      test('activate binds the host cell', () {
        final host = Cell();
        final receptor = Receptor((cell, pulse, {user}) => pulse);
        expect(receptor.activate(host), isTrue);
        expect(identical(receptor.cell, host), isTrue);
      });

      test('clone is an independent unactivated copy', () {
        final original = Receptor((cell, pulse, {user}) {
          return Pulse((pulse.payload as int) + 1);
        });
        final clone = original.clone;
        expect(identical(original, clone), isFalse);
        expect(clone.isActivated, isFalse);

        bindReceptor(clone);
        expect(original.isActivated, isFalse);
        expect(invoke(clone, Pulse<int>(41))?.payload, 42);
      });

      test('unactivated call fails the activation assertion', () {
        final receptor = Receptor((cell, pulse, {user}) => pulse);
        expect(
          () => invoke(receptor, Pulse<int>(1)),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('Pipeline', () {
      test('runs preProcess then instruction then postProcess', () {
        final stages = <String>[];
        final receptor = bindReceptor(Receptor.pipeline(
          preProcess: Instruction((p, {cell, user}) {
            stages.add('pre');
            return Pulse((p.payload as String).trim());
          }),
          instruction: Instruction((p, {cell, user}) {
            stages.add('core');
            return Pulse((p.payload as String).toUpperCase());
          }),
          postProcess: Instruction((p, {cell, user}) {
            stages.add('post');
            return p;
          }),
        ));

        final result = invoke(receptor, Pulse<String>('  hello  '));
        expect(stages, ['pre', 'core', 'post']);
        expect(result?.payload, 'HELLO');
      });

      test('a throwing custom instruction in the pipeline returns null', () {
        final receptor = bindReceptor(
          Receptor.pipeline(instruction: _ThrowingStage()),
        );
        expect(invoke(receptor, Pulse<int>(1)), isNull);
      });

      test('null from a stage short-circuits later stages', () {
        final stages = <String>[];
        final receptor = bindReceptor(Receptor.pipeline(
          preProcess: Instruction((p, {cell, user}) {
            stages.add('pre');
            return p;
          }),
          instruction: Instruction((p, {cell, user}) {
            stages.add('core');
            return null;
          }),
          postProcess: Instruction((p, {cell, user}) {
            stages.add('post');
            return p;
          }),
        ));

        expect(invoke(receptor, Pulse<int>(1)), isNull);
        expect(stages, ['pre', 'core']);
      });

      test('postProcess can drop after a successful core stage', () {
        final receptor = bindReceptor(Receptor.pipeline(
          preProcess: Instruction((p, {cell, user}) {
            return Pulse((p.payload as String).trim());
          }),
          instruction: Instruction((p, {cell, user}) {
            return Pulse((p.payload as String).toUpperCase());
          }),
          postProcess: Instruction((p, {cell, user}) {
            return (p.payload as String).length > 5 ? p : null;
          }),
        ));

        expect(invoke(receptor, Pulse<String>('  hi  ')), isNull);
        expect(invoke(receptor, Pulse<String>('  hello!  '))?.payload, 'HELLO!');
      });

      test('omitted stages are skipped', () {
        final receptor = bindReceptor(Receptor.pipeline(
          instruction: Instruction((p, {cell, user}) {
            return Pulse((p.payload as int) * 3);
          }),
        ));
        expect(invoke(receptor, Pulse<int>(4))?.payload, 12);
      });

      test('preProcess and postProcess run without a core instruction', () {
        final stages = <String>[];
        final receptor = bindReceptor(Receptor.pipeline(
          preProcess: Instruction((p, {cell, user}) {
            stages.add('pre');
            return Pulse((p.payload as int) + 1);
          }),
          postProcess: Instruction((p, {cell, user}) {
            stages.add('post');
            return Pulse((p.payload as int) * 2);
          }),
        ));
        expect(invoke(receptor, Pulse<int>(3))?.payload, 8);
        expect(stages, ['pre', 'post']);
      });

      test('instruction exception terminates the pipeline', () {
        final receptor = bindReceptor(Receptor.pipeline(
          preProcess: Instruction((p, {cell, user}) => p),
          instruction: Instruction((p, {cell, user}) {
            throw FormatException('bad');
          }),
          postProcess: Instruction((p, {cell, user}) => Pulse('never')),
        ));
        expect(invoke(receptor, Pulse<int>(1)), isNull);
      });
    });

    group('Instruction composition', () {
      test('+ chains two instructions in order', () {
        final trim = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as String).trim());
        });
        final upper = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as String).toUpperCase());
        });
        final chained = trim + upper;
        expect(chained.call(Pulse<String>('  hi  '))?.payload, 'HI');
      });

      test('Instruction.chain is equivalent to +', () {
        final trim = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as String).trim());
        });
        final upper = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as String).toUpperCase());
        });
        final chained = Instruction.chain([trim, upper]);
        expect(chained.call(Pulse<String>('  hi  '))?.payload, 'HI');
      });

      test('chain short-circuits on null', () {
        var ranSecond = false;
        final drop = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) => null);
        final second = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          ranSecond = true;
          return pulse;
        });
        expect((drop + second).call(Pulse<int>(1)), isNull);
        expect(ranSecond, isFalse);
      });

      test('chains nest', () {
        final addOne = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as int) + 1);
        });
        final timesTen = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse((pulse.payload as int) * 10);
        });
        final nested = (addOne + addOne) + timesTen;
        expect(nested.call(Pulse<int>(3))?.payload, 50);
      });

      test('instruction exception returns null', () {
        final boom = Instruction<Cell, Pulse, Pulse>((pulse, {cell, user}) {
          throw ArgumentError('nope');
        });
        expect(boom.call(Pulse<int>(1)), isNull);
      });
    });

    group('Instruction.future', () {
      test('returns null immediately and resumes via future callback', () async {
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
    });

    group('Receptor.async', () {
      test('hook captures the transformed result', () async {
        final receptor = bindReceptor(Receptor((cell, pulse, {user}) {
          return Pulse((pulse.payload as int) * 2);
        }));

        final done = Completer<Pulse?>();
        await receptor.async.call(
          Pulse<int>(21) as PulseBase,
          hook: ({result, required input}) {
            done.complete(result);
          },
        );
        expect((await done.future)?.payload, 42);
      });

      test('hook sees null when the receptor drops the pulse', () async {
        final receptor = bindReceptor(Receptor((cell, pulse, {user}) => null));
        final done = Completer<Pulse?>();
        await receptor.async.call(
          Pulse<int>(1) as PulseBase,
          hook: ({result, required input}) {
            done.complete(result);
          },
        );
        expect(await done.future, isNull);
      });

      test('serializedCompletion false still processes via the hook', () async {
        final receptor = bindReceptor(Receptor((cell, pulse, {user}) {
          return Pulse((pulse.payload as int) * 2);
        }));
        final done = Completer<Pulse?>();
        final queued = receptor.async.call(
          Pulse<int>(21) as PulseBase,
          serializedCompletion: false,
          hook: ({result, required input}) {
            done.complete(result);
          },
        );
        expect((await done.future)?.payload, 42);
        await queued;
      });
    });

    group('Graph integration', () {
      test('Cell(bind:) delivers transformed pulses to observers', () {
        final source = Cell.ingress<int>();
        final doubled = Cell(
          bind: source.cell,
          receptor: Receptor((cell, pulse, {user}) {
            return Pulse((pulse.payload as int) * 2);
          }),
        );
        final rec = Recorder(doubled);

        source.emit(21);
        expect(rec.payloads, [42]);
      });

      test('testRule on the host can drop pulses before transformation', () {
        final source = Cell.ingress<int>();
        final cell = Cell(
          bind: source.cell,
          testRule: TestCell((object, {host, arguments, user}) {
            if (object is Pulse && object.payload is int) {
              return (object.payload as int).isEven;
            }
            return true;
          }),
          receptor: Receptor((cell, pulse, {user}) {
            return Pulse((pulse.payload as int) * 10);
          }),
        );
        final rec = Recorder(cell);

        source.emit(2);
        source.emit(3);
        expect(rec.payloads, [20]);
      });

      test('null from the bound receptor suppresses observers', () {
        final source = Cell.ingress<int>();
        final cell = Cell(
          bind: source.cell,
          receptor: Receptor((cell, pulse, {user}) {
            final value = pulse.payload as int;
            return value > 0 ? Pulse(value) : null;
          }),
        );
        final rec = Recorder(cell);

        source.emit(5);
        source.emit(-1);
        expect(rec.payloads, [5]);
      });
    });

    group('call contract extras', () {
      test('async testRule Future is awaited before transformation', () async {
        final host = Cell(
          testRule: TestCell((object, {host, arguments, user}) async {
            await Future<void>.delayed(Duration.zero);
            if (object is Pulse && object.payload is int) {
              return (object.payload as int).isEven;
            }
            return true;
          }),
        );
        final receptor = bindReceptor(
          Receptor((cell, pulse, {user}) {
            return Pulse((pulse.payload as int) * 10);
          }),
          host: host,
        );

        expect((await receptor.call(Pulse<int>(2) as PulseBase))?.payload, 20);
        expect(await receptor.call(Pulse<int>(3) as PulseBase), isNull);
      });

      test('a PulseShell is scrutinized instead of run through the pipeline', () {
        final receptor = bindReceptor(Receptor((cell, pulse, {user}) => pulse));
        final kernel = Pulse<int>(7);
        final result = receptor.call(kernel.shell);
        expect(result, isA<Pulse>());
        expect((result as Pulse).payload, 7);
      });

      test('async call scrutinizes a PulseShell', () async {
        final receptor = bindReceptor(Receptor((cell, pulse, {user}) => pulse));
        await receptor.async.call(Pulse<int>(4).shell);
      });

      test('governed pulse on a deputy host records the mandate role', () {
        final receptor = Receptor((cell, pulse, {user}) => pulse);
        Cell.governed(
          context: DeputyContext(
            baseContext: Context.system,
            authority: 'READ',
            role: 'Observer',
          ),
          receptor: receptor,
        );
        final pulse = Pulse<int>.governed(
          payload: 4,
          context: PulseContext(actor: 'auditor'),
        );
        final result = invoke(receptor, pulse);
        expect(result?.trace, contains('Observer'));
      });
    });

    group('Receptor.pipeline mask', () {
      test('stores reaction and isGoverned flyweight combinations', () {
        final identity = Instruction<Cell, Pulse, Pulse>((p, {cell, user}) => p);
        Pulse? react(Pulse p, Cell host, {user}) => p;
        var inits = 0;
        void init() => inits++;
        dynamic user() => 'meta';

        final combos = <Receptor>[
          Receptor.pipeline(reaction: react),
          Receptor.pipeline(instruction: identity, reaction: react),
          Receptor.pipeline(preProcess: identity, reaction: react),
          Receptor.pipeline(
            instruction: identity,
            preProcess: identity,
            reaction: react,
          ),
          Receptor.pipeline(postProcess: identity, reaction: react),
          Receptor.pipeline(
            instruction: identity,
            postProcess: identity,
            reaction: react,
          ),
          Receptor.pipeline(
            preProcess: identity,
            postProcess: identity,
            reaction: react,
          ),
          Receptor.pipeline(
            instruction: identity,
            preProcess: identity,
            postProcess: identity,
            reaction: react,
          ),
          Receptor.pipeline(isGoverned: true),
          Receptor.pipeline(instruction: identity, isGoverned: true),
          Receptor.pipeline(init: init, isGoverned: true),
          Receptor.pipeline(
            instruction: identity,
            init: init,
            isGoverned: true,
          ),
          Receptor.pipeline(user: user, isGoverned: true),
          Receptor.pipeline(
            instruction: identity,
            user: user,
            isGoverned: true,
          ),
          Receptor.pipeline(init: init, user: user, isGoverned: true),
          Receptor.pipeline(
            instruction: identity,
            init: init,
            user: user,
            isGoverned: true,
          ),
        ];
        for (final r in combos) {
          expect(r.activate(Cell()), isTrue);
        }
        expect(combos[8].isGoverned, isTrue);
        expect(inits, greaterThan(0));
      });

      test('a reaction receptor transforms without an instruction chain', () {
        final receptor = bindReceptor(
          Receptor.pipeline(
            reaction: (pulse, host, {user}) {
              return Pulse((pulse.payload as int) * 2);
            },
          ),
        );
        expect(invoke(receptor, Pulse<int>(21))?.payload, 42);
      });

      test('a governed receptor ticks a hosted EphemeralPolicy', () {
        final policy = EphemeralPolicy(
          eventLimit: 1,
          onEvent: (object, {required cell, required policy, arguments, user}) =>
              (events: policy.events + 1),
          onInvalidate: (_) => true,
        );
        final source = Cell.ingress<int>();
        final cell = Cell.governed(
          bind: source.cell,
          ephemeralPolicy: policy,
          receptor: Receptor.pipeline(
            isGoverned: true,
            instruction: Instruction<Cell, Pulse, Pulse>((p, {cell, user}) => p),
          ),
        );
        expect(cell.isGoverned, isTrue);
        source.emit(1);
        expect(policy.isInvalidated, isTrue);
        expect(cell.isInvalidated, isTrue);
        source.emit(2);
      });
    });
  });
}
