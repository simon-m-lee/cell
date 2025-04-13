// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../collective.dart';

/// A base class for [CollectiveQueue] that provides common properties and methods.
typedef CollectiveQueueBase<E> = _CollectiveQueue<E>;

/// [CollectiveQueue] is a reactive queue implementation that extends Dart's Queue
/// functionality with cell-based reactivity. It propagates changes through the
/// cell network when modified and supports all standard queue operations with
/// validation capabilities.
///
/// This implementation provides a robust, reactive queue that integrates seamlessly
/// with the cell-based architecture while maintaining the performance characteristics
/// of Dart's native Queue.
///
/// Key features:
///
/// Reactive Operations: All modifications trigger signal propagation
/// Type Safety: Generic E type for queue elements
/// Validation: Integrated with TestCollective system
/// Customizable: Supports user-defined properties and behaviors
/// Unmodifiable Variant – UnmodifiableCollectiveQueue for immutable use
/// Async Operations – async interface for non-blocking mutations
///
/// Best Practices
///
/// - Use the [CollectiveQueue] for reactive data structures that require
/// dynamic updates and notifications.
/// - Use the [UnmodifiableCollectiveQueue] for immutable data structures
/// that should not change after creation.
/// - Use async operations to avoid blocking the main thread.
/// - Use the [TestCollective] for validation to ensure data integrity.
/// - Use the [CollectiveReceptor] for custom signal handling and processing.
/// - Use the [MapObject] for custom mapping and transformation of elements.
/// - Use the [Synapses] for managing relationships between cells.
/// - Use the [CollectiveCellProperties] for customizing the properties of
/// the queue.
///
///
/// Example: Basic usage
/// ```dart
///
/// final queue = CollectiveQueue<int>();
///
/// // Listen to changes
/// final listener = Cell.listen(
///   bind: queue,
///   listen: (CollectivePost post, _) {
///     post.body?.forEach((event, elements) {
///       print('Event: $event, Elements: $elements');
///     });
///   }
/// );
///
/// queue.addAll([1, 2, 3]);
/// // Output: Event: CollectiveEvent._(identifier: #elementAdded), Elements: {1, 2, 3}
///
/// queue.removeFirst();
/// // Output: Event: CollectiveEvent._(identifier: #elementRemoved), Elements: {1}
///  ```
///
/// Example: With Validation
/// ```dart
/// final positiveQueue = CollectiveQueue<int>(
///   test: TestCollective.create(
///     elementDisallow: (n, _) => n <= 0,
///     maxLength: 5
///   )
/// );
///
/// positiveQueue.add(1); // Success
/// positiveQueue.add(0); // Throws/blocked by validation
/// positiveQueue.addAll([2, 3, 4, 5, 6]); // Last item blocked by maxLength
///  ```
///
/// Example: Async Operations
/// ```dart
/// final queue = CollectiveQueue<String>();
///
/// void main() async {
///   await queue.async.add('first');
///   await queue.async.addAll(['second', 'third']);
///
///   final item = await queue.async.removeFirst();
///   print(item); // 'first'
/// }
///
/// ```
/// Example: Complete Example
/// ```dart
/// import 'package:collective/collective.dart';
///
/// void main() async {
///   // Create queue with validation
///   final taskQueue = CollectiveQueue<String>(
///     test: TestCollective.create(
///       elementDisallow: (task, _) => task.isEmpty,
///       maxLength: 10
///     )
///   );
///
///   // Processor cell
///   final processor = Cell.listen(
///     bind: taskQueue,
///     listen: (post, _) {
///       if (post.body?.containsKey(Collective.elementAdded) ?? false) {
///         print('New tasks arrived: ${post.body?[Collective.elementAdded]}');
///       }
///     }
///   );
///
///   // Add tasks
///   taskQueue.addAll(['Task1', 'Task2']);
///
///   // Process items
///   while (taskQueue.isNotEmpty) {
///     final task = taskQueue.removeFirst();
///     print('Processing: $task');
///     await Future.delayed(Duration(seconds: 1));
///   }
///
///   // Async addition
///   await taskQueue.async.add('UrgentTask');
/// }
/// ```
abstract interface class CollectiveQueue<E> implements CollectiveCell<E> {

  @override
  CollectiveQueueProperties<E> get _properties;

  /// Creates an empty growable list by default from elements
  factory CollectiveQueue({
    Cell? bind,
    TestCollective test,
    bool growable
  }) = _CollectiveQueue<E>;

  /// Creates a growable list by default from elements
  factory CollectiveQueue.of(Iterable<E> elements, {
    Cell? bind,
    TestCollective test,
    bool growable
  }) = _CollectiveQueue<E>.of;

  /// Creates a [CollectiveQueue] from properties
  factory CollectiveQueue.fromProperties(CollectiveQueueProperties<E> properties, {Iterable<E>? elements}) = _CollectiveQueue<E>.fromProperties;

  /// Creates an unmodifiable [CollectiveQueue] from elements
  factory CollectiveQueue.unmodifiable(CollectiveQueue<E> bind, {bool unmodifiableElement = true}) {
    return UnmodifiableCollectiveQueue<E>.bind(bind, unmodifiableElement: unmodifiableElement);
  }

  /// Creates an user defined [CollectiveQueue]
  static CollectiveQueue<E> create<E, I extends Queue<E>>({
    Iterable<E>? elements,
    Cell? bind,
    ContainerType container = ContainerType.growableTrue,
    CollectiveReceptor receptor = CollectiveReceptor.unchanged,
    TestCollective test = TestCollective.passed,
    MapObject? mapObject,
    Synapses synapses = Synapses.enabled
  }) {
    return _CollectiveQueue<E>.fromProperties(CollectiveCellProperties<E,I>(
        bind: bind,
        container: container,
        receptor: receptor,
        test: test,
        mapObject: mapObject,
        synapses: synapses
    ), elements: elements);
  }


  /// Adds value at the end of the queue.
  ///
  /// [Sync] CollectiveQueue returns void
  /// [Async] CollectiveQueue returns `Future<void>`
  add(E value);

  /// Adds all values [iterable] at the end of the queue.
  ///
  /// [Sync] CollectiveQueue returns void
  /// [Async] CollectiveQueue returns `Future<void>`
  addAll(Iterable<E> iterable);

  /// Adds value at the beginning of the queue.
  ///
  /// [Sync] CollectiveQueue returns void
  /// [Async] CollectiveQueue returns `Future<void>`
  addFirst(E value);

  /// Adds value at the end of the queue.
  ///
  /// [Sync] CollectiveQueue returns void
  /// [Async] CollectiveQueue returns `Future<void>`
  addLast(E value);

  /// Clears the queue.
  ///
  /// [Sync] CollectiveQueue returns void
  /// [Async] CollectiveQueue returns `Future<void>`
  clear();

  /// Removes the first occurrence of [value] from the queue.
  ///
  /// [Sync] CollectiveQueue returns void
  /// [Async] CollectiveQueue returns `Future<void>`
  remove(Object? value);

  /// Removes the first element from the queue.
  ///
  /// [Sync] CollectiveQueue returns the removed element
  /// [Async] CollectiveQueue returns `Future<E>`
  removeFirst();

  /// Removes the last element from the queue.
  ///
  /// [Sync] CollectiveQueue returns the removed element
  /// [Async] CollectiveQueue returns `Future<E>`
  removeLast();

  /// Removes all elements that satisfy the [test] condition.
  ///
  /// [Sync] CollectiveQueue returns void
  /// [Async] CollectiveQueue returns `Future<void>`
  removeWhere(bool Function(E element) test);

  /// Retains all elements that satisfy the [test] condition.
  ///
  /// [Sync] CollectiveQueue returns void
  /// [Async] CollectiveQueue returns `Future<void>`
  retainWhere(bool Function(E element) test);

  /// Creates an [Deputy] from this [CollectiveQueue] with either [test] or [map] or both properties.
  /// The new [CollectiveQueue]
  @override
  CollectiveQueue<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject});

  @override
  CollectiveQueue<E> get unmodifiable;

  /// Creates an async variant for [modifiable] operations
  @override
  CollectiveQueueAsync<E> get async;

  /// Provides a view of this queue as a queue of R instances, if necessary.
  @override
  Queue<R> cast<R>();
}

class _CollectiveQueue<E> extends CollectiveCell<E> with IterableMixin<E>, OpenQueueMixin<E> implements CollectiveQueue<E> {

  _CollectiveQueue({
    Cell? bind,
    TestCollective test = TestCollective.passed,
    bool growable = true
  }) : super(CollectiveQueueProperties<E>(
    bind: bind,
    container: growable ? ContainerType.growableTrue : ContainerType.growableFalse,
    test: test,
  ));

  _CollectiveQueue.of(Iterable<E> elements, {
    Cell? bind,
    TestCollective test = TestCollective.passed,
    bool growable = true
  }) : super(CollectiveQueueProperties<E>(
    bind: bind,
    container: growable ? ContainerType.growableTrue : ContainerType.growableFalse,
    test: test,
  ), elements: elements);

  _CollectiveQueue.fromProperties(CollectiveQueueProperties<E> super.properties, {super.elements});

  @override
  Queue<R> cast<R>() {
    return _properties.container.cast<R>();
  }

  @override
  CollectiveQueue<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return CollectiveQueueDeputy<E>._(this, test: test, mapObject: mapObject);
  }

  @override
  late final CollectiveQueue<E> unmodifiable = UnmodifiableCollectiveQueue<E>.bind(this, unmodifiableElement: true);

  /// Creates an async variant for [modifiable] operations
  @override
  CollectiveQueueAsync<E> get async => CollectiveQueueAsync<E>(this);


}

/// A helper class that provides an deputy interface for [CollectiveQueue].
///
/// This class extends [CollectiveQueue] and mixes in [Deputy] functionality to:
/// - Apply additional validation rules
/// - Transform values via mapping
/// - Maintain the original queue's behavior
///
/// The deputy delegates all operations to the original queue while applying
/// its additional constraints/transformations.
///
/// Example:
/// ```dart
/// final queue = CollectiveQueue<int>();
/// final deputy = queue.deputy(
///   test: customTestRules,
///   map: valueTransform
/// );
/// ```
class CollectiveQueueDeputy<E> extends CollectiveQueueBase<E> with Deputy<CollectiveQueue<E>> {

  CollectiveQueueDeputy._(CollectiveQueue<E> bind, {TestCollective? test, MapObject? mapObject})
      : super.fromProperties(bind._properties.deputy(bind: bind, test: test, mapObject: mapObject));

  @override
  CollectiveQueue<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return CollectiveQueueDeputy<E>._(_properties.bind as CollectiveQueue<E>, test: test, mapObject: mapObject);
  }
}

/// An unmodifiable version of a [CollectiveQueue] that implements the [Queue] interface.
///
/// This class wraps a [CollectiveQueue] and prevents all modification operations,
/// throwing [UnsupportedError] when modification methods are called. It maintains
/// all the read-only functionality of a queue while preventing changes to its contents.
///
/// The queue can be created as unmodifiable from the start, or can be created by
/// wrapping an existing [CollectiveQueue] using the [bind] constructor.
///
/// Example:
/// ```dart
/// final queue = CollectiveQueue.of([1, 2, 3]);
/// final unmodifiableQueue = UnmodifiableCollectiveQueue.bind(queue);
/// ```
///
/// Type parameters:
/// - [E]: The type of elements in the queue
class UnmodifiableCollectiveQueue<E> extends UnmodifiableCollectiveCell<E> with IterableMixin<E>, OpenQueueMixin<E> implements CollectiveQueue<E> {

  /// Creates an unmodifiable queue containing the given [elements].
  ///
  /// Parameters:
  /// - [elements]: Initial elements for the queue
  /// - [unmodifiableElement]: If true, elements that are cells will be converted to their unmodifiable versions
  /// - [properties]: Optional properties to configure the queue
  UnmodifiableCollectiveQueue(Iterable<E> elements, {bool unmodifiableElement = true, CollectiveQueueProperties<E>? properties})
      : super(properties ?? CollectiveQueueProperties<E>(), unmodifiableElement: unmodifiableElement, elements: elements);

  /// Creates an unmodifiable queue by binding to an existing [Collective].
  ///
  /// Parameters:
  /// - [bind]: The queue to make unmodifiable
  /// - [unmodifiableElement]: If true, elements that are cells will be converted to their unmodifiable versions
  /// - [properties]: Optional properties to configure the queue
  /// - [elements]: Optional elements to use instead of the bound queue's elements
  UnmodifiableCollectiveQueue.bind(Collective bind, {bool unmodifiableElement = true, CollectiveQueueProperties<E>? properties, Iterable<E>? elements})
      : super(properties ?? CollectiveQueueProperties<E>(), unmodifiableElement: unmodifiableElement,
      elements: elements ?? (unmodifiableElement ? bind.whereType<E>() : bind.whereType<E>().map<E>((e) => e is Cell ? e.unmodifiable as E : e))
  );

  /// Creates an unmodifiable queue from existing properties.
  UnmodifiableCollectiveQueue.fromProperties(super.properties, {super.unmodifiableElement, super.elements}) : super();

  /// Factory constructor to create an unmodifiable queue with configuration options.
  ///
  /// Parameters:
  /// - [elements]: Initial elements for the queue
  /// - [unmodifiableElement]: If true, elements that are cells will be converted to their unmodifiable versions
  /// - [bind]: Optional cell to bind to
  /// - [container]: Container type configuration
  /// - [receptor]: Signal receptor configuration
  /// - [test]: Test rules for the queue
  /// - [map]: Mapping configuration
  /// - [synapses]: Synapses configuration for cell linking
  static CollectiveQueue<E> create<E, I extends Queue<E>>({
    Iterable<E>? elements,
    bool unmodifiableElement = true,
    Cell? bind,
    ContainerType? container,
    CollectiveReceptor receptor = CollectiveReceptor.unchanged,
    TestCollective test = TestCollective.passed,
    MapObject? mapObject,
    Synapses synapses = Synapses.enabled
  }) {
    return UnmodifiableCollectiveQueue<E>.fromProperties(
        CollectiveCellProperties<E,I>(bind: bind, container: container, test: test, receptor: receptor, synapses: synapses),
        unmodifiableElement: unmodifiableElement,
        elements: elements
    );
  }

  /// Creates an deputy (helper) for this unmodifiable queue with optional test and map configurations.
  ///
  /// Returns a new [UnmodifiableCollectiveQueue] that acts as a view of this queue with
  /// the additional test/map configurations applied.
  @override
  CollectiveQueue<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return UnmodifiableCollectiveQueue.fromProperties(_properties.deputy(bind: this, test: test, mapObject: mapObject),
        unmodifiableElement: _unmodifiableElement,
        elements: this
    );
  }

  @override
  CollectiveQueue<E> get unmodifiable => this;

  /// Creates an async variant for [modifiable] operations
  @override
  CollectiveQueueAsync<E> get async => UnmodifiableCollectiveQueueAsync<E>(this);

  @override
  Queue<R> cast<R>() {
    return _properties.container.cast<R>();
  }
}

/// A mixin that provides queue operations for [CollectiveCell] implementations.
///
/// This mixin implements the [Queue] interface and adds reactive capabilities to standard
/// queue operations. All modifications to the queue are validated through the collective's
/// test rules before being applied, and changes are propagated through the receptor system.
///
/// The mixin provides both synchronous and asynchronous versions of queue operations,
/// with automatic signal propagation when elements are added or removed.
///
/// Example usage:
/// ```dart
/// class MyCollectiveQueue<E> extends CollectiveCell<E> with OpenQueue<E> {
///   // Implementation...
/// }
/// ```
///
/// Type parameters:
/// - [E]: The type of elements in the queue
mixin OpenQueueMixin<E> on CollectiveCell<E> implements Queue<E>, Collective<E> {

  @override
  CollectiveCellProperties<E, Queue<E>> get _properties => super._properties as CollectiveCellProperties<E, Queue<E>>;

  @override
  Iterable<Function> get modifiable => <Function>{add, addAll, clear, remove, removeWhere,
    retainWhere, removeLast, ...super.modifiable};

  //

  @override
  int get length => _properties.container.length;

  //

  @override
  void add(E value) => apply(add, [value]);

  @override
  void addAll(Iterable<E> iterable) => apply(addAll, [iterable]);

  @override
  void addFirst(E value) => apply(addFirst, [value]);

  @override
  void addLast(E value) => apply(addLast, [value]);

  @override
  void clear() => apply(clear, null);

  @override
  bool remove(Object? object) => apply(remove, [object]).isNotEmpty;

  @override
  E removeFirst() => apply(removeFirst, null).values.first.first;

  @override
  E removeLast() => apply(removeLast, null).values.first.first;

  @override
  void removeWhere(bool Function(E element) test) => apply(removeWhere, [test]);

  @override
  void retainWhere(bool Function(E element) test) => apply(retainWhere, [test]);

  //

  Map<CollectiveEvent, Iterable<E>> _add(E value, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Iterable<E>>{};

    if (this is! Unmodifiable && modifiable.contains(add)) {
      if (test.action(add, this, arguments: (positionalArguments: [value], namedArguments: null))) {
        if (test.element(value, this, action: add) && _containerAdd(value)) {
          map[Collective.elementAdded] = <E>[value];
          if (notification) {
            final post = CollectivePost._(from: deputy ?? this, body: map);
            _properties.receptor(cell: this, signal: post);
          }
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _addFirst(E value, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Iterable<E>>{};

    if (this is! Unmodifiable && modifiable.contains(addFirst)) {
      if (test.action(addFirst, this, arguments: (positionalArguments: [value], namedArguments: null))) {
        if (test.element(value, this, action: addFirst)) {
          _properties.container.addFirst(value);

          if (value is CollectiveCell && !_properties.container.contains(value)) {
            value._properties.synapses.link(this, host: value);
          }

          map[Collective.elementAdded] = <E>[value];
          if (notification) {
            final post = CollectivePost._(from: deputy ?? this, body: map);
            _properties.receptor(cell: this, signal: post);
          }
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _addLast(E value, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Iterable<E>>{};

    if (this is! Unmodifiable && modifiable.contains(addLast)) {
      if (test.action(addLast, this, arguments: (positionalArguments: [value], namedArguments: null))) {
        if (test.element(value, this, action: addLast)) {
          _properties.container.addLast(value);

          if (value is CollectiveCell && !_properties.container.contains(value)) {
            value._properties.synapses.link(this, host: value);
          }

          map[Collective.elementAdded] = <E>[value];
          if (notification) {
            final post = CollectivePost._(from: deputy ?? this, body: map);
            _properties.receptor(cell: this, signal: post);
          }
        }
      }
    }


    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _addAll(Iterable<E> elements, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Iterable<E>>{};

    if (this is! Unmodifiable && modifiable.contains(addAll)) {
      if (test.action(addAll, this, arguments: (positionalArguments: [elements], namedArguments: null))) {
        final adds = elements.where((e) => test.element(e, deputy is Collective ? deputy : this, action: add));
        final added = adds.where(_containerAdd);
        if (added.isNotEmpty) {
          map[Collective.elementAdded] = added.toList(growable: false);
          if (notification) {
            final post = CollectivePost._(from: deputy ?? this, body: map);
            _properties.receptor(cell: this, signal: post);
          }
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _clear({bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Iterable<E>>{};

    if (this is! Unmodifiable && modifiable.contains(clear)) {
      if (test.action(clear, this)) {
        final removes = _properties.container.where((e) => test.element(e, deputy is Collective ? deputy : this, action: remove));
        final removed = removes.where(_containerRemove);
        if (removed.isNotEmpty) {
          map[Collective.elementRemoved] = removed.toList(growable: false);
          if (notification) {
            final post = CollectivePost._(from: deputy ?? this, body: map);
            _properties.receptor(cell: this, signal: post);
          }
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _remove(Object? object, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, List<E>>{};

    if (this is! Unmodifiable && modifiable.contains(remove)) {
      if (object != null && test.action(remove, this, arguments: (positionalArguments: [object], namedArguments: null))) {
        final e = firstWhere((e) => e == object);
        if (e != null && test.element(e, deputy is Collective ? deputy : this, action: remove) && _containerRemove(e)) {
          map[Collective.elementRemoved] = <E>[e];
          if (notification) {
            final post = CollectivePost._(from: deputy ?? this, body: map);
            _properties.receptor(cell: this, signal: post);
          }
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _removeFirst({bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, List<E>>{};

    if (this is! Unmodifiable && modifiable.contains(removeLast)) {
      if (test.action(removeFirst, this)) {
        final e = _properties.container.last;
        if (test.element(e, deputy is Collective ? deputy : this, action: removeFirst) && _properties.container.removeFirst() == e) {
          if (e is CollectiveCell && !_properties.container.contains(e)) {
            e._properties.synapses.unlink(this);
          }
          map[Collective.elementRemoved] = <E>[e];
          if (notification) {
            final post = CollectivePost._(from: deputy ?? this, body: map);
            _properties.receptor(cell: this, signal: post);
          }
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _removeLast({bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, List<E>>{};

    if (this is! Unmodifiable && modifiable.contains(removeLast)) {
      if (test.action(removeLast, this)) {
        final e = _properties.container.last;
        if (test.element(e, deputy is Collective ? deputy : this, action: removeLast) && _properties.container.removeLast() == e) {
          if (e is CollectiveCell && !_properties.container.contains(e)) {
            e._properties.synapses.unlink(this);
          }
          map[Collective.elementRemoved] = <E>[e];
          if (notification) {
            final post = CollectivePost._(from: deputy ?? this, body: map);
            _properties.receptor(cell: this, signal: post);
          }
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _removeWhere(bool Function(E element) test, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Iterable<E>>{};

    if (this is! Unmodifiable && modifiable.contains(removeWhere)) {
      if (this.test.action(removeWhere, this, arguments: (positionalArguments: [test], namedArguments: null))) {
        final removes = _properties.container.where((e) => test(e) && this.test.element(e, deputy is Collective ? deputy : this, action: remove));
        final removed = removes.where(_containerRemove);
        if (removed.isNotEmpty) {
          map[Collective.elementRemoved] = removed.toList(growable: false);
          if (notification) {
            final post = CollectivePost._(from: deputy ?? this, body: map);
            _properties.receptor(cell: this, signal: post);
          }
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _retainWhere(bool Function(E element) test, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Iterable<E>>{};

    if (this is! Unmodifiable && modifiable.contains(retainWhere)) {
      if (this.test.action(retainWhere, this, arguments: (positionalArguments: [test], namedArguments: null))) {
        final removes = _properties.container.where((e) => !test(e) && this.test.element(e, deputy is Collective ? deputy : this, action: remove));
        final removed = removes.where(_containerRemove);
        if (removed.isNotEmpty) {
          map[Collective.elementRemoved] = removed.toList(growable: false);
          if (notification) {
            final post = CollectivePost._(from: deputy ?? this, body: map);
            _properties.receptor(cell: this, signal: post);
          }
        }
      }
    }

    return map;
  }


  @override
  dynamic apply(Function function, List? positionalArguments, [Map<Symbol, dynamic>? namedArguments]) {

    if (test.action(function, this, arguments: (positionalArguments: positionalArguments, namedArguments: namedArguments))) {

      final notification = namedArguments?[#$notification] ?? true;

      if (function == add) {
        return Function.apply(_add, positionalArguments, {#notification: notification});
      }
      else if (function == addFirst) {
        return Function.apply(_addFirst, positionalArguments, {#notification: notification});
      }
      else if (function == addLast) {
        return Function.apply(_addLast, positionalArguments, {#notification: notification});
      }
      else if (function == addAll) {
        return Function.apply(_addAll, positionalArguments, {#notification: notification});
      }
      else if (function == clear) {
        return Function.apply(_clear, null, {#notification: notification});
      }
      else if (function == remove) {
        return Function.apply(_remove, positionalArguments, {#notification: notification});
      }
      else if (function == removeFirst) {
        return Function.apply(_removeFirst, positionalArguments, {#notification: notification});
      }
      else if (function == removeLast) {
        return Function.apply(_removeLast, positionalArguments, {#notification: notification});
      }
      else if (function == removeWhere) {
        return Function.apply(_removeWhere, positionalArguments, {#notification: notification});
      }
      else if (function == retainWhere) {
        return Function.apply(_retainWhere, positionalArguments, {#notification: notification});
      }
      return Function.apply(function, positionalArguments, namedArguments);
    }
  }

  bool _containerAdd(E e) {
    _properties.container.add(e);
    if (!_properties.container.contains(e)) {
      if (e is CollectiveCell) {
        e._properties.synapses.link(e, host: this);
      }
    }
    return true;
  }

  bool _containerRemove(E e) {
    if (_properties.container.remove(e)) {
      if (e is CollectiveCell && !_properties.container.contains(e)) {
        e._properties.synapses.unlink(this);
      }
      return true;
    }
    return false;
  }
}

/// An asynchronous interface for performing operations on a [CollectiveQueue].
///
/// This class provides Future-based versions of all [CollectiveQueue] operations,
/// allowing queue modifications to be used in async/await contexts while maintaining:
///
/// - Full reactive behavior and cell linkages
/// - All validation rules from the original queue
/// - Automatic change notifications
/// - Transactional safety
///
/// All operations return Futures that complete when:
/// 1. The operation has been validated
/// 2. The queue has been modified
/// 3. All change notifications have been processed
///
/// Example Usage:
/// ```dart
/// final queue = CollectiveQueue<int>().async;
///
/// Future<void> fillQueue() async {
///   await queue.add(1);
///   await queue.addFirst(0);  // Add to front
///   await queue.addAll([2, 3]);
/// }
/// ```
class CollectiveQueueAsync<E> extends CollectiveAsync<E,CollectiveQueue<E>> implements CollectiveQueue<E> {

  /// Creates an async variant of [CollectiveQueue] for [modifiable] methods.
  ///
  /// Typically accessed via the [CollectiveQueue.async] getter rather than
  /// constructed directly.
  const CollectiveQueueAsync(super.collective);

  /// Async adds [value] to the queue.
  @override
  Future<void> add(E value) async {
    return Future<void>(() => _collective.add(value));
  }

  /// Async adds all [iterable] to the queue.
  @override
  Future<void> addAll(Iterable<E> iterable) async {
    return Future<void>(() => _collective.addAll(iterable));
  }

  /// Async add the [element] to the first in the queue.
  @override
  Future<void> addFirst(E value) {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  /// Async add the [element] to the last in the queue.
  @override
  Future<void> addLast(E value) {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  /// Async removes all elements from the queue.
  @override
  Future<void> clear() async {
    return Future<void>(() => _collective.clear());
  }

  /// Async removes a single instance of value from the queue
  @override
  Future<bool> remove(Object? value) async {
    return Future<bool>(() => _collective.remove(value));
  }

  /// Async removes the first element from the queue.
  @override
  Future<E> removeFirst() {
    return Future<E>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  /// Async removes the last element from the queue.
  @override
  Future<E> removeLast() {
    return Future<E>(() => _collective.removeLast());
  }

  /// Async removes elements from the queue that satisfy the [test].
  @override
  Future<void> removeWhere(bool Function(E element) test) async {
    return Future<void>(() => _collective.removeWhere(test));
  }

  /// Async removes elements from the queue that doesn't satisfy the [test].
  @override
  Future<void> retainWhere(bool Function(E element) test) async {
    return Future<void>(() => _collective.retainWhere(test));
  }

  @override
  Queue<R> cast<R>() {
    return _collective.cast<R>();
  }

  //

  /// Gets an unmodifiable view of this queue.
  @override
  CollectiveQueue<E> get unmodifiable => _collective.unmodifiable;

  /// Creates a [Async] [CollectiveQueue] for async [modifiable] operations
  @override
  CollectiveQueueAsync<E> get async => this;

  /// Creates a delegated view with modified behavior.
  ///
  /// Parameters:
  ///   - test: Optional override validation rules
  ///   - map: Optional element transformations
  @override
  CollectiveQueue<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return _collective.deputy(test: test, mapObject: mapObject);
  }

  @override
  TestCollective get test => _collective.test;

  @override
  CollectiveQueueProperties<E> get _properties => _collective._properties;
}

/// An asynchronous interface for an unmodifiable [CollectiveQueue] that prevents all modifications.
///
/// This class provides Future-based versions of queue operations that enforce immutability by:
/// - Throwing [UnsupportedError] for all mutating operations
/// - Maintaining the same method signatures as the mutable version for API consistency
/// - Preserving the ability to read queue contents asynchronously
///
/// All mutating operations (add/remove/clear etc.) will immediately complete the Future
/// with an error rather than modifying the queue.
///
/// Example usage:
/// ```dart
/// final unmodifiableQueue = CollectiveQueue<int>().unmodifiable.async;
///
/// Future<void> tryModify() async {
///   await unmodifiableQueue.add(1); // Throws UnsupportedError
///   await unmodifiableQueue.removeFirst(); // Throws UnsupportedError
/// }
/// ```
class UnmodifiableCollectiveQueueAsync<E> extends CollectiveQueueAsync<E> implements Unmodifiable {

  @override
  Iterable<Function> get modifiable => const <Function>{};

  /// Creates an async interface for an unmodifiable queue.
  ///
  /// Typically accessed via [UnmodifiableCollectiveQueue.async] rather than
  /// constructed directly.
  const UnmodifiableCollectiveQueueAsync(super.collective) : super();

  @override
  Future<void> add(E value) {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> addAll(Iterable<E> iterable) {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> addFirst(E value) {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> addLast(E value) {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> clear() {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<bool> remove(Object? value) {
    return Future<bool>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<E> removeFirst() {
    return Future<E>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<E> removeLast() {
    return Future<E>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> removeWhere(bool Function(E element) test) {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> retainWhere(bool Function(E element) test) {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  CollectiveQueue<E> get unmodifiable => this;

}
