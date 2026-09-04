// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';

/// Flow instructions that prefix a stream (Rx `startWith` family).
///
/// A Cell has no subscribe hook, so the prefix is emitted on the
/// **first typed source pulse**, then the source continues.
///
/// | Operator | Rx analogue | Prefix |
/// |---|---|---|
/// | [StartWith] | `startWith` | one [seed] |
/// | [StartWithValue] | `startWith` | alias of [StartWith] |
/// | [StartWithMany] | `startWith` of several | [seeds] in order |
/// | [StartWithFactory] | lazy `startWith` | [seedOf] on first pulse |
///
/// [replaceFirst] drops the first source payload after the prefix.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef StartWithErrorHandler = void Function(Object error, StackTrace? stackTrace);

Pulse? _typedOrError<S>(
  Pulse pulse, {
  StartWithErrorHandler? onError,
}) {
  final payload = pulse.payload;
  if (payload is! S) {
    onError?.call(
      FormatException('Expected payload of type $S, got ${payload.runtimeType}'),
      StackTrace.current,
    );
    return null;
  }
  return pulse;
}

Pulse<S> _out<S>(S value, Pulse trigger, Cell? cell, String step) {
  return Pulse<S>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

void _emitAll<S>(
  Iterable<S> values,
  Pulse trigger,
  Cell? cell,
  String step,
  void Function({required Pulse? result, required dynamic token})? future,
  dynamic token,
) {
  for (final value in values) {
    future?.call(
      result: _out<S>(value, trigger, cell, step),
      token: token,
    );
  }
}

/// Emit [seed] on the first typed pulse, then forward the source
/// (Rx `startWith`).
class StartWith<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  StartWith(
    S seed, {
    bool replaceFirst = false,
    StartWithErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            var first = true;
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;
              if (first) {
                first = false;
                future!(
                  result: _out<S>(seed, typed, cell, 'StartWith.seed'),
                  token: token,
                );
                if (replaceFirst) return null;
              }
              return typed.withStep('StartWith');
            };
          })(),
          user: user,
        );
}

/// Alias of [StartWith].
class StartWithValue<S> extends StartWith<S> {
  StartWithValue(
    super.value, {
    super.replaceFirst,
    super.onError,
    super.user,
  });
}

/// Emit [seeds] in order on the first typed pulse, then forward.
class StartWithMany<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  StartWithMany(
    Iterable<S> seeds, {
    bool replaceFirst = false,
    StartWithErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            var first = true;
            final prefix = List<S>.from(seeds);
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;
              if (first) {
                first = false;
                _emitAll(prefix, typed, cell, 'StartWithMany.seed', future, token);
                if (replaceFirst) return null;
              }
              return typed.withStep('StartWithMany');
            };
          })(),
          user: user,
        );
}

/// Compute the prefix from the first payload via [seedOf].
class StartWithFactory<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  StartWithFactory(
    Iterable<S> Function(S first) seedOf, {
    bool replaceFirst = false,
    StartWithErrorHandler? onError,
    dynamic user,
  }) : super.future(
          (() {
            var first = true;
            return (pulse, {cell, user, future, token}) {
              final typed = _typedOrError<S>(pulse, onError: onError);
              if (typed == null) return null;
              if (first) {
                first = false;
                try {
                  final prefix = seedOf(typed.payload as S);
                  _emitAll(
                    prefix,
                    typed,
                    cell,
                    'StartWithFactory.seed',
                    future,
                    token,
                  );
                } catch (e, stack) {
                  onError?.call(e, stack);
                  return null;
                }
                if (replaceFirst) return null;
              }
              return typed.withStep('StartWithFactory');
            };
          })(),
          user: user,
        );
}

/// Demonstration of the startWith family.
///
/// ### Expected console output:
/// ```text
/// ── StartWith Operators Demo ──────────────────────────────────
///
/// 1. StartWith
///    [StartWith] seed
///    [StartWith] a
///    [StartWith] b
///
/// 2. StartWithValue
///    [StartWithValue] 0
///    [StartWithValue] 1
///
/// 3. StartWithMany
///    [StartWithMany] x
///    [StartWithMany] y
///    [StartWithMany] z
///
/// 4. StartWithFactory
///    [StartWithFactory] pre-hi
///    [StartWithFactory] hi
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── StartWith Operators Demo ──────────────────────────────────\n');

  print('1. StartWith');
  final letters = Cell.ingress<String>();
  final started = StartWith<String>('seed').toHandle(source: letters.cell);
  final sObs = Cell.observe(
    source: started.cell,
    effect: (Pulse p) => print('   [StartWith] ${p.payload}'),
  );
  await letters.emitAsync('a');
  await letters.emitAsync('b');
  sObs.stop();
  print('');

  print('2. StartWithValue');
  final nums = Cell.ingress<int>();
  final valued = StartWithValue<int>(0).toHandle(source: nums.cell);
  final vObs = Cell.observe(
    source: valued.cell,
    effect: (Pulse p) => print('   [StartWithValue] ${p.payload}'),
  );
  await nums.emitAsync(1);
  vObs.stop();
  print('');

  print('3. StartWithMany');
  final rest = Cell.ingress<String>();
  final many = StartWithMany<String>(['x', 'y']).toHandle(source: rest.cell);
  final mObs = Cell.observe(
    source: many.cell,
    effect: (Pulse p) => print('   [StartWithMany] ${p.payload}'),
  );
  await rest.emitAsync('z');
  mObs.stop();
  print('');

  print('4. StartWithFactory');
  final words = Cell.ingress<String>();
  final factory = StartWithFactory<String>((first) => ['pre-$first'])
      .toHandle(source: words.cell);
  final fObs = Cell.observe(
    source: factory.cell,
    effect: (Pulse p) => print('   [StartWithFactory] ${p.payload}'),
  );
  await words.emitAsync('hi');
  fObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}
