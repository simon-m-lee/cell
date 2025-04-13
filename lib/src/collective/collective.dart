// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../collective.dart';

// ignore_for_file: unused_element
// ignore_for_file: unused_field

/// A base class for all [Collective] types.
typedef CollectiveBase<E> = CollectiveCell<E>;

/// A reactive collection that combines [Cell] behavior with [Iterable] functionality.
/// Notifies about changes (add/remove/update) and maintains relationships between cells.
///
/// It provides:
/// - Reactive collection types (List, Set, Value) that integrate with Cell system
/// - Comprehensive change notification system
/// - Flexible validation framework
/// - Relationship management between cells
/// - Immutable variants for safe sharing
/// - Customizable container behaviors
///
/// The architecture allows building complex reactive data flows while maintaining type safety
/// and clear separation of concerns. Collections can be composed and chained to create
/// sophisticated data processing pipelines.
///
/// Events:
/// - [elementAdded]: When an element is added
/// - [elementRemoved]: When an element is removed
/// - [elementUpdated]: When an element is updated
///
/// Example:
/// ```dart
///
/// // Create a reactive list
/// final list = Collective<int>([1, 2, 3]);
///
/// // Listen for changes
/// Cell.listen<CollectivePost>(
///   bind: list,
///   listen: (post, _) {
///     if (post.body!.containsKey(Collective.elementAdded)) {
///       print('Added: ${post.body![Collective.elementAdded]}');
///     }
///   }
/// );
///
/// // Modify the list
/// list.add(4); // Will trigger listener
///  ```
///
/// Example:
/// ```dart
/// // Example:
/// final safeList = CollectiveList<int>(
///   [],
///   test: TestCollective.create(
///     elementDisallow: (num, _) => num < 0, // No negatives
///     actionDisallow: (_) => [List.clear], // Don't allow clear
///     maxLength: 100
///   )
/// );
///  ```
abstract interface class Collective<E> implements Cell, Iterable<E> {

  CollectiveProperties<E> get _properties;

  /// Event identifier for when an element is added to a Collective.
  ///
  /// This event should be used when:
  /// - New elements are inserted into a list
  /// - Elements are added to a set
  /// - Values are pushed onto a queue
  static const elementAdded = CollectiveEvent._(identifier: #elementAdded);

  /// Event identifier for when an element is removed from a Collective.
  ///
  /// This event should be used when:
  /// - Elements are deleted from a list
  /// - Elements are removed from a set
  /// - Values are popped from a queue
  static const elementRemoved = CollectiveEvent._(identifier: #elementRemoved);

  /// Event identifier for when an element's value is updated in a Collective.
  ///
  /// This is primarily used with [CollectiveValue] to indicate when the stored
  /// value has changed (including being set to null).
  static const elementUpdated = CollectiveEvent._(identifier: #elementUpdated);

  /// Creates a collective from elements
  factory Collective(Iterable<E> elements, {
    Cell? bind,
    TestCollective test = TestCollective.passed,
  }) {
    return _Collective<E>(CollectiveCellProperties<E,Iterable<E>>(
        bind: bind,
        container: ContainerType.iterable,
        test: test,
    ), elements: elements);
  }

  /// Creates an empty collective
  factory Collective.empty({
    Cell? bind,
    TestCollective test = TestCollective.passed,
  }) {
    return _Collective<E>(CollectiveCellProperties<E,Iterable<E>>(
      bind: bind,
      container: ContainerType.iterable,
      test: test,
    ));
  }

  /// Creates a collective from properties
  factory Collective.fromProperties(CollectiveProperties<E> properties, {Iterable<E>? elements}) = _Collective<E>;

  /// Creates an unmodifiable view
  factory Collective.unmodifiable(Collective<E> bind, {bool unmodifiableElement = true}) {
    return UnmodifiableCollective<E>.bind(bind, unmodifiableElement: unmodifiableElement);
  }

  /// Creates a collective with properties
  static Collective<E> create<E, I extends Iterable<E>>({
    Iterable<E>? elements,
    Cell? bind,
    ContainerType? container,
    CollectiveReceptor receptor = CollectiveReceptor.unchanged,
    TestCollective test = TestCollective.passed,
    MapObject? mapObject,
    Synapses synapses = Synapses.enabled
  }) {
    return _Collective<E>(CollectiveCellProperties<E,I>(
      bind: bind,
      container: container,
      receptor: receptor,
      test: test,
      mapObject: mapObject,
      synapses: synapses
    ), elements: elements);
  }

  @override
  TestCollective get test;

  /// Creates an async variant for [modifiable] operations
  @override
  CollectiveAsync<E,Collective<E>> get async;

}

class _Collective<E> extends CollectiveCell<E> with IterableMixin<E> implements Unmodifiable, Sync {

  _Collective(super.properties, {super.elements}) ;

  /// Creates a [Callable] for async [modifiable] operations
  @override
  CollectiveAsync<E,Collective<E>> get async => CollectiveAsync<E,Collective<E>>(this);

}

/// An implementation of [Collective] that is unmodifiable.
abstract class CollectiveCell<E> extends CellBase implements Collective<E> {

  final CollectiveProperties<E> _properties;

  /// Creates a [CollectiveCell] from properties
  CollectiveCell(CollectiveProperties<E> super.properties, {Iterable<E>? elements})
      : _properties = properties, super.fromProperties() {
    (_properties as CollectiveCellProperties)._initContainer(this, elements);
  }

  @override
  Iterator<E> get iterator => _properties.container.iterator;

  @override
  TestCollective get test => _properties.test;

  @override
  bool operator ==( Object other ) {
    if (identical(this, other)) {
      return true;
    }
    if (other is CollectiveCell<E>) {
      if (other is Unmodifiable) {
        if (other._properties.bind != null && identical(this, other._properties.bind)) {
          return identical(unmodifiable, this);
        }
      }
    }
    if (other is Iterable<E>) {
      return _properties.container == other;
    }
    return false;
  }

  @override
  int get hashCode => _properties.container.hashCode;

  @override
  String toString() {
    return _properties.container.toString();
  }

}

/// An interface for an unmodifiable [Collective].
abstract interface class UnmodifiableCollective<E> implements CollectiveCell<E>, Unmodifiable {

  factory UnmodifiableCollective(Iterable<E> elements, {bool unmodifiableElement = true, CollectiveProperties<E>? properties}) {
    return _UnmodifiableCollective<E>(
        properties: properties ?? CollectiveProperties<E>(),
        unmodifiableElement: unmodifiableElement,
        elements: elements
    );
  }

  factory UnmodifiableCollective.bind(Collective<E> bind, {bool unmodifiableElement = true}) {
    return _UnmodifiableCollective<E>(
        properties: ((bind as CollectiveCell)._properties as CollectiveCellProperties).copy(bind: bind) as CollectiveProperties<E>,
        unmodifiableElement: unmodifiableElement,
        elements: unmodifiableElement ? bind.map<E>((e) => e is Cell ? e.unmodifiable as E : e) : bind
    );
  }

  /// Creates an unmodifiable collective with properties
  static Collective<E> create<E, I extends Iterable<E>>({
    Iterable<E>? elements,
    bool unmodifiableElement = true,
    Cell? bind,
    ContainerType? container,
    CollectiveReceptor receptor = CollectiveReceptor.unchanged,
    TestCollective test = TestCollective.passed,
    MapObject? mapObject,
    Synapses synapses = Synapses.enabled
  }) {
    return _UnmodifiableCollective<E>(
        properties: CollectiveCellProperties<E,I>(bind: bind, container: container, test: test, receptor: receptor, synapses: synapses),
        unmodifiableElement: unmodifiableElement,
        elements: elements
    );
  }

  factory UnmodifiableCollective.fromProperties(CollectiveProperties<E> properties, {bool unmodifiableElement = true, Iterable<E>? elements}) {
    return _UnmodifiableCollective(properties: properties, unmodifiableElement: unmodifiableElement, elements: elements);
  }

}

class _UnmodifiableCollective<E> extends UnmodifiableCollectiveCell<E> with IterableMixin<E> implements Unmodifiable {

  _UnmodifiableCollective({CollectiveProperties<E>? properties, super.unmodifiableElement, super.elements})
      : super(properties ?? CollectiveProperties<E>());

  @override
  Collective<E> get unmodifiable => this;

  /// Creates a [Callable] for async [modifiable] operations
  @override
  CollectiveAsync<E,Collective<E>> get async => CollectiveAsync<E,Collective<E>>(this);
}

/// An implementation of [UnmodifiableCollective] that is unmodifiable.
abstract class UnmodifiableCollectiveCell<E> extends CollectiveCell<E> implements UnmodifiableCollective<E> {

  @override
  Iterable<Function> get modifiable => const Iterable<Function>.empty();

  final bool _unmodifiableElement;

  /// Creates an [UnmodifiableCollectiveCell] from properties
  UnmodifiableCollectiveCell(super.properties, {bool unmodifiableElement = true, super.elements})
      : _unmodifiableElement = unmodifiableElement, super();

  @override
  bool operator ==( Object other ) {
    if (identical(this, other)) {
      return true;
    }
    if (other is CollectiveCell<E>) {
      if (other is! Unmodifiable) {
        if (_properties.bind != null && identical(_properties.bind, other)) {
          return identical(other.unmodifiable, this);
        }
      }
    }
    if (other is Iterable<E>) {
      return _properties.container == other;
    }
    return false;
  }

  @override
  int get hashCode => _properties.container.hashCode;

}

/// An asynchronous wrapper for [Collective] operations that provides Future-based APIs.
///
/// This class implements both [Collective] and [Iterable] interfaces while
/// converting all mutating operations into asynchronous operations that return
/// [Future] objects. This enables non-blocking usage of collective operations.
///
/// ## Usage
/// ```dart
/// final list = CollectiveList<int>.of([1, 2, 3]);
/// final asyncList = list.async; // Get async wrapper
///
/// await asyncList.add(4); // Asynchronous add
/// await asyncList.remove(2); // Asynchronous remove
/// ```
///
/// ## Features
/// - All mutating operations return `Future<void>` or `Future<bool>`
/// - Maintains same interface as synchronous [Collective]
/// - Preserves reactive behavior of the underlying collective
/// - Thread-safe operations through Future-based API
class CollectiveAsync<E, C extends Collective<E>> extends CellAsync<C> with IterableMixin<E> implements CollectiveBase<E> {

  final C _collective;

  /// Creates an async wrapper around an existing [Collective].
  ///
  /// Typically accessed via the [Collective.async] getter rather than
  /// constructed directly.
  ///
  /// ```dart
  /// final asyncList = myList.async; // Preferred access
  /// ```
  const CollectiveAsync(super.collective)
      : _collective = collective;

  @override
  Iterator<E> get iterator => _collective.iterator;

  @override
  TestCollective get test => _collective.test;

  /// An asynchronous version of the [Collective] interface which is essentially itself
  @override
  CollectiveAsync<E,C> get async => this;

  @override
  CollectiveProperties<E> get _properties => _collective._properties;

}