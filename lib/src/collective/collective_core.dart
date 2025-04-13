// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../collective.dart';

// ignore_for_file: non_constant_identifier_names

int? _$RANDOM_PRIME;
int get _RANDOM_PRIME => _$RANDOM_PRIME ??= <int>[2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97][randomBetween(0,24)];

/// A specialized [Tag] class that represents events that can occur within a [Collective].
///
/// CollectiveEvents are used to signal different types of changes to a Collective's elements:
/// - When elements are added [Collective.elementAdded]
/// - When elements are removed [Collective.elementRemoved]
/// - When elements are updated [Collective.elementUpdated]
///
/// These events are typically used in conjunction with [CollectivePost] to propagate
/// notifications about changes to linked cells.
class CollectiveEvent extends Tag {

  const CollectiveEvent._({
    required super.identifier,
  }) : super();

}

/// Represents a change in value, tracking both the previous and current states.
///
/// This is commonly used in reactive programming to notify about value changes,
/// particularly in [CollectiveValue] implementations. It provides immutable
/// access to both the before and after states of a value change.
///
/// Example:
/// ```dart
/// final change = ValueChange(before: 'old', after: 'new');
/// print(change.before); // 'old'
/// print(change.after);  // 'new'
/// ```
///
/// The class supports creating unmodifiable versions of value changes through
/// [ValueChange.unmodifiable], which is useful when dealing with [Cell] values
/// that should not be modified after creation.
abstract interface class ValueChange<V> {

  /// The value before the change occurred.
  ///
  /// This will be null if the value was previously unset.
  V? get before;

  /// The value after the change occurred.
  ///
  /// This will be null if the value was unset by the change.
  V? get after;

  /// Creates a [ValueChange] with the given before and after values.
  ///
  /// Both [before] and [after] can be null to represent unset states.
  factory ValueChange({required V? after, required V? before}) = _ValueChange<V>;

  /// Creates an unmodifiable version of an existing [ValueChange].
  ///
  /// If the source contains [Cell] values, they will be converted to their
  /// unmodifiable versions as well.
  ///
  /// This is useful when you need to ensure value changes can't be modified
  /// after creation, particularly when propagating changes through a reactive
  /// system.
  factory ValueChange.unmodifiable(ValueChange<V> source) {
    return _UnmodifiableValueChange._(source);
  }

  /// Returns an unmodifiable version of this value change.
  ///
  /// If this is already an unmodifiable value change, returns itself.
  ValueChange<V> get unmodifiable;

}

class _ValueChange<V> implements ValueChange<V> {

  @override
  final V? before;

  @override
  final V? after;

  _ValueChange({required this.after, required this.before});

  @override
  late final ValueChange<V> unmodifiable = (before == null || before is Cell) && (after == null || after is Cell) ? _UnmodifiableValueChange._(this) : this;

  @override
  int get hashCode {
    var hash = _RANDOM_PRIME;
    if (before == null && after == null) {
      return super.hashCode;
    }
    if (before != null) {
      hash = 31 * hash + before.hashCode;
    }
    if (after != null) {
      hash = 31 * hash + after.hashCode;
    }
    return hash;
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) {
      return true;
    }
    if (other is ValueChange<V>) {
      if (other is Unmodifiable) {
        return other == this;
      }
      if (before != null && after != null && other.before == before && other.after == after) {
        return true;
      }
    }
    return false;
  }

  @override
  String toString() => '[before: $before, after: $after]';

  @override
  ValueChange<V>? get body => throw UnimplementedError();
}

class _UnmodifiableValueChange<V> implements ValueChange<V>, Unmodifiable {
  final ValueChange<V> _source;

  const _UnmodifiableValueChange._(this._source);

  @override
  V? get after => _source.after is Cell ? (_source.after as Cell).unmodifiable as V? : _source.after;

  @override
  V? get before => _source.before is Cell ? (_source.before as Cell).unmodifiable as V? : _source.before;

  @override
  ValueChange<V> get unmodifiable => this;

  @override
  int get hashCode {
    return _source.hashCode;
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) {
      return true;
    }
    if (other is _UnmodifiableValueChange<V>) {
      return other._source == _source;
    }
    if (other is ValueChange<V>) {
      return other == _source;
    }
    return false;
  }

  @override
  String toString() => '[before: $before, after: $after]';

}

/// Represents a value change for a specific element within a collection.
///
/// This specialized [ValueChange] associates a value change with a particular
/// element, making it useful for tracking changes to individual items in
/// [Collective] collections like [CollectiveList], [CollectiveSet], or
/// [CollectiveQueue].
///
/// Example:
/// ```dart
/// final element = MyElement();
/// final change = ElementValueChange(
///   element: element,
///   before: 'old value',
///   after: 'new value'
/// );
/// ```
///
/// The class provides an unmodifiable variant through [ElementValueChange.unmodifiable],
/// which is particularly useful when propagating change notifications through
/// a reactive system.
class ElementValueChange<E,V> implements ValueChange<V> {

  /// The value before the change occurred.
  ///
  /// Will be null if the element had no previous value.
  @override
  final V? before;

  /// The value after the change occurred.
  ///
  /// Will be null if the element was unset by this change.
  @override
  final V? after;

  /// The element that was changed.
  ///
  /// This is typically an item within a [Collective] collection.
  final E element;

  /// Creates an [ElementValueChange] recording a change to a specific element.
  ///
  /// Parameters:
  /// - [element]: The element that was changed
  /// - [after]: The new value after the change
  /// - [before]: The previous value before the change (optional)
  ElementValueChange({required this.element, required this.after, this.before});

  /// Creates an unmodifiable version of an [ElementValueChange].
  ///
  /// If the source contains [Cell] values, they will be converted to their
  /// unmodifiable versions. The element itself will also be made unmodifiable
  /// if it is a [Cell].
  ///
  /// Returns:
  /// An immutable version of the value change that safely propagates through
  /// the reactive system.
  factory ElementValueChange.unmodifiable(ElementValueChange<E,V> source) {
    return _UnmodifiableElementValueChange._(source);
  }

  @override
  late final ElementValueChange<E,V> unmodifiable = _UnmodifiableElementValueChange<E,V>._(this);

  @override
  int get hashCode {
    var hash = super.hashCode;
    hash = 31 * hash + element.hashCode;
    return hash;
  }

  @override
  String toString() => '[element: $element, before: $before, after: $after]';

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) {
      return true;
    }
    if (other is ElementValueChange<E,V>) {
      if (other is _UnmodifiableElementValueChange<E,V>) {
        return other._source == this;
      }
      if (super==(other)) {
        return other.element == element;
      }
    }
    return false;
  }
}

class _UnmodifiableElementValueChange<E,V> extends _UnmodifiableValueChange<V> implements ElementValueChange<E,V>, Unmodifiable {

  const _UnmodifiableElementValueChange._(ElementValueChange<E,V> super.source) : super._();

  @override
  E get element {
    final source = super._source as ElementValueChange;
    return source.element is Cell ? (source.element as Cell).unmodifiable : source.element;
  }

  @override
  ElementValueChange<E,V> get unmodifiable => this;

  @override
  // ignore: hash_and_equals
  bool operator ==(Object other) {
    if (identical(other, this)) {
      return true;
    }
    if (other is _UnmodifiableElementValueChange<E,V>) {
      return other._source == _source;
    }
    if (other is ElementValueChange<E,V>) {
      return other == _source;
    }
    return false;
  }

  @override
  String toString() => '[element: $element, before: $before, after: $after]';


}

