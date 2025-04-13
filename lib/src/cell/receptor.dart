// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../cell.dart';

/// Function signature for transforming signals in receptors.
///
/// Parameters:
/// - cell: The cell processing the signal
/// - signal: The incoming signal
/// - user: Optional user context
///
/// Returns a transformed signal or null if processing should stop
typedef SignalTransform<C extends Cell, I extends Signal, O extends Signal> = O? Function(
    {required C cell, required I signal, dynamic user});

/// The signal processing engine of a [Cell], transforming incoming signals into outputs.
///
/// A `Receptor` defines how a cell:
/// 1. Accepts input signals of type [I]
/// 2. Transforms them via custom logic
/// 3. Produces output signals of type [O]
/// 4. Propagates results through synapses
///
/// ## Core Concepts:
/// - **Signal Flow**: Input → Transformation → Output → Propagation
/// - **Type Safety**: Strict input/output signal typing
/// - **Context Awareness**: Cell and user context available
/// - **Error Handling**: Built-in exception protection
///
/// Example:
/// ```dart
/// final doubler = Receptor<Cell, int, int>(
///   transform: ({cell, signal, user}) => signal * 2,
///   user: context
/// );
/// ```
///
/// ## Type Parameters:
/// - `C`: The cell type (must extend [Cell])
/// - `I`: Input signal type (must extend [Signal])
/// - `O`: Output signal type (must extend [Signal])
abstract interface class Receptor<C extends Cell, I extends Signal, O extends Signal> {

  /// The identity receptor that passes signals unchanged
  static const unchanged = ReceptorBase();

  /// Creates a signal receptor with transformation logic.
  ///
  /// Parameters:
  /// - [transform]: The signal processing function
  /// - [user]: Optional context passed to the transformer
  const factory Receptor({SignalTransform<C,I,O>? transform, dynamic user}) = ReceptorBase<C,I,O>;

  /// Processes a signal through the receptor pipeline.
  ///
  /// Execution flow:
  /// 1. Validates signal against cell's [TestObject]
  /// 2. Applies transformation if provided
  /// 3. Propagates output to synapses
  /// 4. Handles errors gracefully
  ///
  /// Parameters:
  /// - [cell]: The processing cell (required)
  /// - [signal]: Input signal (required)
  /// - [notified]: Tracks propagation to prevent loops
  ///
  /// [Sync] Receptor returns a [O?] the output signal or null if processing fails.
  /// [Async] Receptor returns a [Future<O?>] for asynchronous processing.
  call({required covariant C cell, required covariant I signal, Set<Cell>? notified});

  /// Asynchronously processes a signal through this receptor
  Receptor<C,I,O> get async;

}

/// A base implementation of [Receptor] that provides default behavior.
typedef ReceptorBase<C extends Cell, I extends Signal, O extends Signal> = _Receptor<C,I,O>;

class _Receptor<C extends Cell, I extends Signal, O extends Signal> implements Receptor<C,I,O>, Sync {

  final Function? _transform;

  final dynamic _user;

  const _Receptor({SignalTransform<C,I,O>? transform, dynamic user}) : _transform = transform, _user = user;

  @override
  O? call({required covariant C cell, required covariant I signal, Set<Cell>? notified}) {

    cell = cell is Deputy ? cell._properties.bind as C : cell;

    if (identical(cell._properties.receptor, this) && cell.test.signal(signal, cell: cell)) {
      notified ??= Set<Cell>.identity();

      Signal? out;
      try {
        out = _transform != null
            ? _transform(cell: cell, signal: signal, user: _user)
            : signal;
      } catch(_) {
        out = signal;
      }

      if (out is O && cell.test.signal(out, cell: cell)) {
        final synapses = cell._properties.synapses;
        synapses(out);
        return out;
      }

    }
    return null;
  }

  @override
  Receptor<C,I,O> get async => ReceptorAsync<C,I,O,Receptor<C,I,O>>(this);

}

/// An [Async] variant of [Receptor] for handling asynchronous signal processing.
class ReceptorAsync<C extends Cell, I extends Signal, O extends Signal, R extends Receptor<C,I,O>> implements Receptor<C,I,O>, Async {

  final R _receptor;

  /// Creates a new instance of [ReceptorAsync].
  const ReceptorAsync(R receptor) : _receptor = receptor;

  @override
  Future<O?> call({required covariant C cell, required covariant I signal, Set<Cell>? notified}) async {
    return Future<O?>(() => _receptor(cell: cell, signal: signal, notified: notified));
  }

  @override
  Receptor<C, I, O> get async => this;

}