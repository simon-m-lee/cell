// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/widgets.dart';

import 'cell_notifier.dart';

/// A [ValueCell] whose value participates in Flutter's state restoration.
///
/// [RestorableCell] is the **Restorable State Atom**: it behaves exactly
/// like any other [ValueCell] — observers subscribe through the reactive
/// graph, writes flow through the cell's integrity gates — while its value
/// is additionally serialized into a [RestorationBucket] when the cell is
/// registered with a [CellRestorationScope]. On a later restore (process
/// kill, hot restart, backgrounding) the persisted value is written back
/// into the cell **before** the first frame that depends on it is built,
/// so the app renders the restored state instead of `initial`.
///
/// ### How it works
/// 1. Construction stores [initial] and the optional codecs; the cell is
///    otherwise a plain [ValueCell] (`super(initial: initial)`).
/// 2. [CellRestorationScopeState.register] wraps the cell in an internal
///    `RestorableProperty` delegate and registers that with Flutter's
///    `RestorationMixin`. The delegate restores the cell from the bucket
///    (via [fromPrimitives]) when persisted data exists, or initializes it
///    to [initial] otherwise.
/// 3. Every write through [value] notifies the delegate, which pushes the
///    serialized value (via [toPrimitives]) into the bucket.
///
/// ### Serialization contract
/// By default only `bool`, `int`, `double`, `String`, and `null` values
/// can be persisted — the types Flutter's `StandardMessageCodec` supports
/// without ambiguity. Any other `V` **throws [UnsupportedError]** when the
/// delegate first serializes it; pass a [toPrimitives] /
/// [fromPrimitives] pair to persist custom types (see the example).
///
/// ### Lifecycle
/// The cell itself has **no dispose** — like every [ValueCell], its
/// invalidation is the caller's responsibility. The restoration delegate
/// (and its internal observation) is released when the cell is
/// unregistered from its scope or the scope is disposed.
///
/// ### Example
/// ```dart
/// // In a StatefulWidget beneath a CellRestorationScope:
/// late final RestorableCell<int> counter;
///
/// @override
/// void initState() {
///   super.initState();
///   counter = restorableState<int>(
///     restorationId: 'counter',
///     initial: 0,
///   );
///   CellRestorationScope.maybeOf(context)?.register(counter);
/// }
/// ```
///
/// ### See Also:
/// - [restorableState] / [CellRestoration.restorableState] — the factories.
/// - [CellRestorationScope] — the scope that registers and restores this
///   cell.
/// - [ValueCell] — the base class; all observation semantics are inherited.
class RestorableCell<V> extends ValueCell<V> {
  /// Creates a restorable cell with [restorationId] and [initial].
  ///
  /// [restorationId] must be unique within the registering
  /// [CellRestorationScope] — a duplicate throws [StateError] at
  /// registration time.
  ///
  /// [fromPrimitives] / [toPrimitives] default to the primitive codecs
  /// described on the class; pass both (or neither) to persist custom
  /// types.
  RestorableCell({
    required this.restorationId,
    super.initial,
    V? Function(Object? data)? fromPrimitives,
    Object? Function(V? value)? toPrimitives,
  })  : _initial = initial,
        _fromPrimitives = fromPrimitives,
        _toPrimitives = toPrimitives;

  /// The unique restoration id under which the value is persisted.
  ///
  /// Must be unique within the registering [CellRestorationScope].
  final String restorationId;

  /// The value used when no persisted data exists.
  final V? _initial;

  /// Custom deserializer; falls back to the primitive codec when null.
  final V? Function(Object? data)? _fromPrimitives;

  /// Custom serializer; falls back to the primitive codec when null.
  final Object? Function(V? value)? _toPrimitives;

  V? decode(Object? data) =>
      (_fromPrimitives ?? _defaultFromPrimitives<V>)(data);

  Object? encode(V? value) => (_toPrimitives ?? _defaultToPrimitives)(value);

  V? get initial => _initial;
}

/// The primitive-serialization fallback for [RestorableCell.toPrimitives].
///
/// Only the types Flutter's `StandardMessageCodec` can represent without a
/// custom codec pass through: `bool`, `int`, `double`, `String`, `null`.
/// Anything else fails loudly with [UnsupportedError] — a silently
/// un-restorable value is a production bug.
Object? _defaultToPrimitives(Object? value) {
  if (value == null ||
      value is bool ||
      value is int ||
      value is double ||
      value is String) {
    return value;
  }
  throw UnsupportedError(
    'RestorableCell: value of type ${value.runtimeType} is not a primitive. '
    'Pass toPrimitives/fromPrimitives to serialize it.',
  );
}

/// The primitive-deserialization fallback for
/// [RestorableCell.fromPrimitives].
V? _defaultFromPrimitives<V>(Object? data) {
  if (data == null) return null;
  if (data is V) return data as V;
  throw UnsupportedError(
    'RestorableCell: cannot restore ${data.runtimeType} as $V. '
    'Pass a fromPrimitives function.',
  );
}

/// Static factory access for [RestorableCell].
///
/// The core `cell` package is Flutter-free, so the Flutter-dependent
/// `RestorableCell` type cannot live on `Cell` itself; this extension
/// provides the canonical spelling next to the core factories:
///
/// ```dart
/// final counter = CellRestoration.restorableState<int>(
///   restorationId: 'counter',
///   initial: 0,
/// );
/// // Or, with the unqualified top-level alias:
/// final theme = restorableState<String>(restorationId: 'theme');
/// ```
extension CellRestoration on Cell {
  /// Creates a [RestorableCell] with the given [restorationId] and
  /// [initial].
  ///
  /// ### Parameters:
  /// * [restorationId]: **Unique Persistence Key.** Must be unique within
  ///   the registering [CellRestorationScope].
  /// * [initial]: **Fresh-Install Value.** Used when no persisted data
  ///   exists.
  /// * [fromPrimitives] / [toPrimitives]: **Optional Codecs.** Required
  ///   for non-primitive `V`; defaults to the primitive codec described on
  ///   [RestorableCell].
  ///
  /// ### Returns:
  /// A [RestorableCell] that behaves exactly like [Cell.state]'s result
  /// until it is registered with a [CellRestorationScope].
  static RestorableCell<V> restorableState<V>({
    required String restorationId,
    V? initial,
    V? Function(Object? data)? fromPrimitives,
    Object? Function(V? value)? toPrimitives,
  }) =>
      RestorableCell<V>(
        restorationId: restorationId,
        initial: initial,
        fromPrimitives: fromPrimitives,
        toPrimitives: toPrimitives,
      );
}

/// The unqualified alias for [CellRestoration.restorableState].
///
/// ```dart
/// final counter = restorableState<int>(restorationId: 'counter', initial: 0);
/// ```
RestorableCell<V> restorableState<V>({
  required String restorationId,
  V? initial,
  V? Function(Object? data)? fromPrimitives,
  Object? Function(V? value)? toPrimitives,
}) =>
    CellRestoration.restorableState<V>(
      restorationId: restorationId,
      initial: initial,
      fromPrimitives: fromPrimitives,
      toPrimitives: toPrimitives,
    );

/// The internal `RestorableProperty` that bridges a [RestorableCell] to
/// Flutter's restoration protocol.
///
/// The delegate exists because [RestorableProperty] extends
/// [ChangeNotifier] and owns the registration/unregistration protocol
/// (`_owner?._unregister` on dispose) — implementing that interface
/// directly on the cell would force the cell to duplicate Flutter's
/// bookkeeping. The delegate instead:
///
/// 1. Observes the cell through a [CellNotifier] and re-notifies Flutter's
///    `RestorationMixin` whenever the cell's value changes.
/// 2. Implements `createDefaultValue` / `fromPrimitives` / `toPrimitives`
///    / `initWithValue` by delegating to the cell's codecs and [value].
/// 3. Releases its observation on [dispose] before handing off to
///    `RestorableProperty.dispose`, which unregisters from the owner.
class RestorableCellDelegate<V> extends RestorableProperty<V?> {
  /// Wraps [cell] for registration with a `RestorationMixin`.
  RestorableCellDelegate(RestorableCell<V> cell) : _cell = cell {
    _notifier = CellNotifier<V>(cell)..addListener(_onCellChanged);
    _lastValue = _notifier!.value;
  }

  final RestorableCell<V> _cell;

  CellNotifier<V>? _notifier;

  /// The last value observed through the notifier; read by [toPrimitives]
  /// so serialization reflects the cell's current state even when the
  /// last change did not re-enter this delegate.
  V? _lastValue;

  void _onCellChanged() {
    _lastValue = _notifier!.value;
    notifyListeners();
  }

  /// The cell this delegate persists.
  RestorableCell<V> get cell => _cell;

  @override
  V? createDefaultValue() => _cell.initial;

  @override
  V? fromPrimitives(Object? data) => _cell.decode(data);

  @override
  Object? toPrimitives() => _cell.encode(_lastValue);

  @override
  void initWithValue(V? value) {
    if (_cell.value == value) {
      _lastValue = value;
      return; // No change: nothing to emit, nothing to re-serialize.
    }
    _cell.value = value;
    _lastValue = value;
    notifyListeners();
  }

  @override
  void dispose() {
    final notifier = _notifier;
    _notifier = null;
    if (notifier != null) {
      notifier.removeListener(_onCellChanged);
      notifier.dispose();
    }
    super.dispose();
  }
}
