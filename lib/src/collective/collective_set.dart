// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../collective.dart';

/// A base class for [CollectiveSet] that provides common properties and methods.
typedef CollectiveSetBase<E> = _CollectiveSet<E>;

/// `CollectiveSet<E>` is a reactive Set implementation that integrates with
/// Dart's `Set<E>` while providing cell-based reactivity. It automatically
/// propagates changes to connected cells when modified and supports validation
/// rules.
///
/// Key Features
///
/// - **Reactive Modifications**:
///   All mutating operations (add, remove, etc.) automatically notify listeners
///   Signals include elementAdded and elementRemoved events
///
/// - **Validation**:
///  Operations validate against configured [TestCollective] rules
///  Supports element-level and operation-level validation
///
/// - **Identity Set Support**:
///   Can be configured to use identity comparison (identical) instead of equality
///
/// - **Delegated Views**:
///   deputy() creates modified views without affecting original set
///   unmodifiable provides an immutable view
///
/// - **Type Parameters**:
///   - `<E>`: The type of elements in the set
///
/// Example:
/// ```dart
/// final set = CollectiveSet<int>();
/// final listener = Cell.listen<CollectivePost>(
///   bind: set,
///   listen: (post, _) => print('Change: ${post.body}')
/// );
/// set.add(1); // Triggers elementAdded signal
/// ```
///
/// Example:
/// ```dart
/// // Create set with validation
/// final set = CollectiveSet<String>(
///     identitySet: true,
///     test: TestCollective.create(
///         elementDisallow: (element, _) => element?.length > 10
///     )
/// );
///
/// // Invalid elements won't be added
/// set.add('too-long-string'); // Fails validation
/// set.add('ok'); // Succeeds
/// ```
/// Example: Custom Validation
/// ```dart
/// // Create collection with complex validation
/// final users = CollectiveSet<User>(
///     test: TestCollective.create(
///         elementDisallow: (user, _) => user?.isBanned ?? true,
///         actionDisallow: (coll) => [coll.addAll], // Disable bulk adds
///         maxLength: 1000 // Limit size
///     )
/// );
///
/// // Attempt operations
/// users.add(bannedUser); // Fails validation
/// users.addAll([user1, user2]); // Fails - addAll disabled
/// ```
/// Example: Async Operations
/// ```dart
/// final asyncSet = CollectiveSet<String>();
///
/// void main() async {
///   await asyncSet.async.add('hello');
///   await asyncSet.async.addAll(['world', '!']);
///
///   final removed = await asyncSet.async.remove('hello');
///   print(removed); // true
/// }
/// ```
/// Example: Bidirectional Binding
/// ```dart
/// final sourceSet = CollectiveSet.of([1, 2, 3]);
/// final mirrorSet = CollectiveSet(bind: sourceSet);
///
/// sourceSet.add(4);
/// print(mirrorSet); // {1, 2, 3, 4}
/// ```
///
/// Example: Complete Example
/// ```dart
/// import 'package:collective/collective.dart';
///
/// void main() async {
///
///   // Create a validated set
///   final uniqueIds = CollectiveSet<int>(
///     test: TestCollective.create(
///       elementDisallow: (id) => id > 1000,  // Reject invalid IDs
///     )
///   );
///
///   // Processor cell
///   final logger = Cell.listen(
///     bind: uniqueIds,
///     listen: (post, _) {
///       if (post.body?.containsKey(Collective.elementAdded) ?? false) {
///         print('New IDs: ${post.body?[Collective.elementAdded]}');
///       }
///     }
///   );
///
///   // Add data
///   uniqueIds.addAll([101, 102, 103]);  // Allowed
///   uniqueIds.add(1001);                // Blocked by validation
///
///   // Async batch insert
///   await uniqueIds.async.addAll([104, 105]);
/// }
/// ```
///
///
/// See also:
///   - [Collective] - The base reactive collection interface
///   - [UnmodifiableCollectiveSet] - Immutable version
///   - [CollectiveList] - Reactive list implementation
abstract interface class CollectiveSet<E> implements CollectiveCell<E> {

  @override
  CollectiveSetProperties<E> get _properties;

  /// Creates a [CollectiveSet] with initial elements.
  ///
  /// Parameters:
  ///   - elements: Initial elements to populate the set
  ///   - bind: Optional parent [Cell] to link with
  ///   - test: Validation rules (defaults to always passing)
  ///   - identitySet: If true, uses identity comparison (default: false)
  factory CollectiveSet(Iterable<E> elements, {
    Cell? bind,
    TestCollective test,
    bool identitySet
  }) = _CollectiveSet<E>;

  /// Creates an empty [CollectiveSet].
  ///
  /// Parameters:
  ///   - bind: Optional parent [Cell] to link with
  ///   - test: Validation rules (defaults to always passing)
  ///   - identitySet: If true, uses identity comparison (default: false)
  factory CollectiveSet.empty({
    Cell? bind,
    TestCollective test,
    bool identitySet
  }) = _CollectiveSet<E>.empty;

  /// Creates a [CollectiveSet] from existing properties.
  ///
  /// Parameters:
  ///   - properties: Configuration properties
  ///   - elements: Optional initial elements
  factory CollectiveSet.fromProperties(CollectiveSetProperties<E> properties, {Iterable<E>? elements}) = _CollectiveSet<E>.fromProperties;

  /// Creates an unmodifiable view of an existing [CollectiveSet].
  ///
  /// Parameters:
  ///   - bind: The set to make unmodifiable
  ///   - unmodifiableElement: If true, makes elements unmodifiable too
  factory CollectiveSet.unmodifiable(CollectiveSet<E> bind, {bool unmodifiableElement = true}) {
    return UnmodifiableCollectiveSet<E>.bind(bind, unmodifiableElement: unmodifiableElement);
  }

  /// Creates a fully configured [CollectiveSet] instance.
  ///
  /// Type Parameters:
  ///   - <I>: The specific set type (typically [Set<E>])
  ///
  /// Parameters:
  ///   - elements: Initial elements
  ///   - bind: Parent [Cell] for reactivity
  ///   - container: [ContainerType] configuration
  ///   - receptor: Custom signal handling
  ///   - test: Validation rules
  ///   - map: Element transformations
  ///   - synapses: Link configuration
  static CollectiveSet<E> create<E, I extends Set<E>>({
    Iterable<E>? elements,
    Cell? bind,
    ContainerType container = ContainerType.set,
    CollectiveReceptor receptor = CollectiveReceptor.unchanged,
    TestCollective test = TestCollective.passed,
    MapObject? mapObject,
    Synapses synapses = Synapses.enabled
  }) {
    return _CollectiveSet<E>.fromProperties(CollectiveCellProperties<E,I>(
        bind: bind,
        container: container,
        receptor: receptor,
        test: test,
        mapObject: mapObject,
        synapses: synapses
    ), elements: elements);
  }

  /// Returns if the [object] in the set, otherwise returns null.
  E? lookup(Object? object);

  /// Whether this set contains all the elements of other.
  bool containsAll(Iterable<Object?> other);

  /// Creates a new set with the elements of this that are not in other.
  Set<E> difference(Set<Object?> other);

  /// Creates a new set with the elements of this that are in other.
  Set<E> intersection(Set<Object?> other);

  /// Creates a new set with the elements of this and other.
  Set<E> union(Set<E> other);

  /// Adds an element to the set
  ///
  /// [Sync] CollectiveSet returns [bool] if the set contains the element
  /// [Async] CollectiveSet returns `Future<bool>` if the set contains the element
  add(E element);

  /// Adds all elements from the iterable to the set
  ///
  /// [Sync] CollectiveSet returns void
  /// [Async] CollectiveSet returns `Future<void>`
  addAll(Iterable<E> elements);

  /// Clears the set, removing all elements
  ///
  /// [Sync] CollectiveSet returns void
  /// [Async] CollectiveSet returns `Future<void>`
  clear();

  /// Removes the specified element from the set
  ///
  /// [Sync] CollectiveSet returns [bool] if the element was removed
  /// [Async] CollectiveSet returns `Future<bool>` if the element was removed
  remove(Object? object);

  /// Removes all elements in the iterable from the set
  ///
  /// [Sync] CollectiveSet returns void
  /// [Async] CollectiveSet returns `Future<void>`
  removeWhere(bool Function(E element) test);

  /// Retains only the elements that satisfy the test
  ///
  /// [Sync] CollectiveSet returns void
  /// [Async] CollectiveSet returns `Future<void>`
  retainWhere(bool Function(E element) test);

  /// Removes all elements in the iterable from the set
  ///
  /// [Sync] CollectiveSet returns void
  /// [Async] CollectiveSet returns `Future<void>`
  removeAll(Iterable<Object?> elements);

  /// Retains only the elements in the iterable
  ///
  /// [Sync] CollectiveSet returns void
  /// [Async] CollectiveSet returns `Future<void>`
  retainAll(Iterable<Object?> elements);

  /// Creates a delegated view with modified behavior.
  ///
  /// Parameters:
  ///   - test: Optional override validation rules
  ///   - map: Optional element transformations
  @override
  CollectiveSet<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject});

  /// Gets an unmodifiable view of this set.
  @override
  CollectiveSet<E> get unmodifiable;

  /// Creates a [Async] [CollectiveSet] for async [modifiable] operations
  @override
  CollectiveSetAsync<E> get async;
}

class _CollectiveSet<E> extends CollectiveCell<E> with SetMixin<E>, OpenSetMixin<E> implements CollectiveSet<E> {

  _CollectiveSet(Iterable<E> elements, {
    Cell? bind,
    TestCollective test = TestCollective.passed,
    bool identitySet = false
  }) : super(CollectiveSetProperties<E>(
    bind: bind,
    container: identitySet ? ContainerType.identitySet : ContainerType.set,
    test: test,
  ), elements: elements);

  _CollectiveSet.empty({
    Cell? bind,
    TestCollective test = TestCollective.passed,
    bool identitySet = false
  }) : super(CollectiveSetProperties<E>(
    bind: bind,
    container: identitySet ? ContainerType.identitySet : ContainerType.set,
    test: test,
  ));

  _CollectiveSet.fromProperties(CollectiveSetProperties<E> super.properties, {super.elements}) : super();

  @override
  CollectiveSet<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return CollectiveSetDeputy<E>._(this, test: test, mapObject: mapObject);
  }

  @override
  late final CollectiveSet<E> unmodifiable = CollectiveSet.unmodifiable(this);

  /// Creates an async version of this set for [modifiable] operations.
  @override
  CollectiveSetAsync<E> get async => CollectiveSetAsync<E>(this);
}

/// A [CollectiveSetDeputy] is a delegated view of a [CollectiveSet] with modified behavior.
class CollectiveSetDeputy<E> extends CollectiveSetBase<E> with Deputy<CollectiveSet<E>> {

  CollectiveSetDeputy._(CollectiveSet<E> bind, {TestCollective? test, MapObject? mapObject})
      : super.fromProperties(bind._properties.deputy(bind: bind, test: test, mapObject: mapObject));

  @override
  CollectiveSet<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return CollectiveSetDeputy<E>._(_properties.bind as CollectiveSet<E>, test: test, mapObject: mapObject);
  }
}

/// An immutable version of [CollectiveSet] that prevents all modification operations.
///
/// This class:
/// - Wraps an existing [CollectiveSet] to make it immutable
/// - Optionally makes elements unmodifiable if they're [Cell] objects
/// - Maintains all reactive relationships
/// - Throws [UnsupportedError] on modification attempts
///
/// ## Usage Examples:
///
/// ```dart
/// // Create from existing set
/// final mutableSet = CollectiveSet({1, 2, 3});
/// final immutableSet = UnmodifiableCollectiveSet.bind(mutableSet);
///
/// // Create directly
/// final direct = UnmodifiableCollectiveSet({4, 5, 6});
/// ```
///
/// See also:
/// - [CollectiveSet] - The mutable version
/// - [Unmodifiable] - The marker interface
class UnmodifiableCollectiveSet<E> extends UnmodifiableCollectiveCell<E> with SetMixin<E>, OpenSetMixin<E> implements CollectiveSet<E> {

  /// Creates an unmodifiable set with initial elements.
  ///
  /// Parameters:
  /// - [elements]: Initial elements
  /// - [unmodifiableElement]: If true, makes elements unmodifiable when they're Cells
  /// - [properties]: Configuration properties
  UnmodifiableCollectiveSet(Iterable<E> elements, {bool unmodifiableElement = true, CollectiveSetProperties<E>? properties})
      : super(properties ?? CollectiveSetProperties<E>(), unmodifiableElement: unmodifiableElement, elements: elements);

  /// Creates an unmodifiable wrapper around an existing [CollectiveSet].
  ///
  /// Parameters:
  /// - [bind]: The set to make unmodifiable
  /// - [unmodifiableElement]: If true, makes elements unmodifiable when they're Cells
  /// - [properties]: Optional custom properties
  /// - [elements]: Optional override elements
  UnmodifiableCollectiveSet.bind(Collective bind, {bool unmodifiableElement = true, CollectiveSetProperties<E>? properties, Iterable<E>? elements})
      : super(properties ?? CollectiveSetProperties<E>(), unmodifiableElement: unmodifiableElement,
      elements: elements ?? (unmodifiableElement ? bind.whereType<E>() : bind.whereType<E>().map<E>((e) => e is Cell ? e.unmodifiable as E : e))
  );

  /// Creates from properties with optional elements.
  UnmodifiableCollectiveSet.fromProperties(super.properties, {super.unmodifiableElement, super.elements}) : super();

  /// Factory constructor for full configuration.
  ///
  /// Parameters match [CollectiveSet.create] with unmodifiable flag
  static CollectiveSet<E> create<E, I extends Set<E>>({
    Iterable<E>? elements,
    bool unmodifiableElement = true,
    Cell? bind,
    ContainerType? container,
    CollectiveReceptor receptor = CollectiveReceptor.unchanged,
    TestCollective test = TestCollective.passed,
    MapObject? mapObject,
    Synapses synapses = Synapses.enabled
  }) {
    return UnmodifiableCollectiveSet<E>.fromProperties(
        CollectiveCellProperties<E,I>(bind: bind, container: container, test: test, receptor: receptor, synapses: synapses),
        unmodifiableElement: unmodifiableElement,
        elements: elements
    );
  }

  /// Creates an unmodifiable deputy for this set.
  ///
  /// Note: While the deputy can be created, modification operations will still throw.
  @override
  CollectiveSet<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return UnmodifiableCollectiveSet.fromProperties(_properties.deputy(bind: this, test: test, mapObject: mapObject),
        unmodifiableElement: _unmodifiableElement,
        elements: this
    );
  }

  /// Returns this unmodifiable instance (no-op).
  ///
  /// Since the set is already unmodifiable, returns itself.
  @override
  CollectiveSet<E> get unmodifiable => this;

  /// Creates an async version of this unmodifiable set.
  @override
  CollectiveSetAsync<E> get async => UnmodifiableCollectiveSetAsync<E>(this);

}

/// A mixin for [OpenSetMixin] that provides additional functionality for [CollectiveCell].
mixin OpenSetMixin<E> on CollectiveCell<E> implements Set<E>, Collective<E> {

  @override
  CollectiveCellProperties<E, Set<E>> get _properties => super._properties as CollectiveCellProperties<E, Set<E>>;

  @override
  Iterable<Function> get modifiable => <Function>{add, addAll, clear, remove, removeAll, removeWhere, ...super.modifiable};

  //

  @override
  bool contains(Object? element) => _properties.container.contains(element);

  @override
  int get length => _properties.container.length;

  @override
  E? lookup(Object? element) {
    for (var e in _properties.container) {
      if (e == element) {
        return e;
      }
    }
    return null;
  }

  @override
  bool containsAll(Iterable<Object?> other) {
    return other.every((e) => _properties.container.any((ee) => ee == e));
  }

  @override
  Set<E> toSet() => _properties.container.toSet();

  //

  @override
  bool add(E element) => apply(add, [element]).isNotEmpty;

  @override
  void addAll(Iterable<E> elements) => apply(addAll, [elements]);

  @override
  void clear() => apply(clear, null);

  @override
  bool remove(Object? object) => apply(remove, [object]).isNotEmpty;

  @override
  void removeWhere(bool Function(E element) test) => apply(removeWhere, [test]);

  @override
  void retainWhere(bool Function(E element) test) => apply(retainWhere, [test]);

  @override
  void removeAll(Iterable<Object?> elements) => apply(removeAll, [elements]);

  @override
  void retainAll(Iterable<Object?> elements) => apply(retainAll, [elements]);

  //

  Map<CollectiveEvent, Iterable<E>> _add(E element, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Set<E>>{};

    if (this is! Unmodifiable && modifiable.contains(add)) {
      if (test.element(element, deputy is Collective ? deputy : this, action: add) && _containerAdd(element)) {
        map[Collective.elementAdded] = <E>{element};
        if (notification) {
          final post = CollectivePost._(from: deputy ?? this, body: map);
          _properties.receptor(cell: this, signal: post);
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _addAll(Iterable<E> elements, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Set<E>>{};

    if (this is! Unmodifiable && modifiable.contains(addAll)) {
      final adds = elements.where((e) => test.element(e, deputy is Collective ? deputy : this, action: add));
      final added = adds.where(_containerAdd);
      if (added.isNotEmpty) {
        map[Collective.elementAdded] = added.toSet();
        if (notification) {
          final post = CollectivePost._(from: deputy ?? this, body: map);
          _properties.receptor(cell: this, signal: post);
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _clear({bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Set<E>>{};

    if (this is! Unmodifiable && modifiable.contains(clear)) {
      final removes = _properties.container.where((e) => test.element(e, deputy is Collective ? deputy : this, action: remove));
      final removed = removes.where(_containerRemove);
      if (removed.isNotEmpty) {
        map[Collective.elementRemoved] = removed.toSet();
        if (notification) {
          final post = CollectivePost._(from: deputy ?? this, body: map);
          _properties.receptor(cell: this, signal: post);
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _remove(Object? object, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Set<E>>{};

    if (this is! Unmodifiable && modifiable.contains(remove)) {
      final e = lookup(object);
      if (e != null && test.element(e, deputy is Collective ? deputy : this, action: remove) && _containerRemove(e)) {
        map[Collective.elementRemoved] = <E>{e};
        if (notification) {
          final post = CollectivePost._(from: deputy ?? this, body: map);
          _properties.receptor(cell: this, signal: post);
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _removeAll(Iterable<Object?> objects, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Set<E>>{};

    if (this is! Unmodifiable && modifiable.contains(removeAll)) {
      if (_properties.container.isNotEmpty) {
        final removes = objects.map((o) => lookup(o)).where((e) => e != null && test.element(e, deputy is Collective ? deputy : this, action: remove));
        final removed = removes.where((e) => _containerRemove(e as E));
        if (removed.isNotEmpty) {
          map[Collective.elementRemoved] = removed.toSet().cast();
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
    final map = <CollectiveEvent, Set<E>>{};

    if (this is! Unmodifiable && modifiable.contains(removeWhere)) {
      if (_properties.container.isNotEmpty) {
        final removes = _properties.container.where((e) => test(e) && this.test.element(e, deputy is Collective ? deputy : this, action: remove));
        final removed = removes.where(_containerRemove);
        if (removed.isNotEmpty) {
          map[Collective.elementRemoved] = removed.toSet();
          if (notification) {
            final post = CollectivePost._(from: deputy ?? this, body: map);
            _properties.receptor(cell: this, signal: post);
          }
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _retainAll(Iterable<Object?> objects, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Set<E>>{};

    if (this is! Unmodifiable && modifiable.contains(retainAll)) {
      if (_properties.container.isNotEmpty) {
        final retains = objects.map((o) => lookup(o)).where((e) => e != null).cast<E>();
        final removes = _properties.container.where((e) => !retains.contains(e) && test.element(e, deputy is Collective ? deputy : this, action: remove));
        final removed = removes.where(_containerRemove);
        if (removed.isNotEmpty) {
          map[Collective.elementRemoved] = removed.toSet();
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
    final map = <CollectiveEvent, Set<E>>{};

    if (this is! Unmodifiable && modifiable.contains(retainWhere)) {
      if (_properties.container.isNotEmpty) {
        final removes = _properties.container.where((e) => !test(e) && this.test.element(e, deputy is Collective ? deputy : this, action: remove));
        final removed = removes.where(_containerRemove);
        if (removed.isNotEmpty) {
          map[Collective.elementRemoved] = removed.toSet();
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

    if (modifiable.contains(function)) {
      try {
        if (test.action(function, this, arguments: (positionalArguments: positionalArguments, namedArguments: namedArguments))) {
          final notification = namedArguments?[#$notification] ?? true;
          final deputy = namedArguments?[#deputy];

          if (function == add) {
            return Function.apply(_add, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          else if (function == addAll) {
            return Function.apply(_addAll, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          else if (function == clear) {
            return Function.apply(_clear, null, {#notification: notification, #deputy: deputy});
          }
          else if (function == remove) {
            return Function.apply(_remove, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          else if (function == removeAll) {
            return Function.apply(_removeAll, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          else if (function == removeWhere) {
            return Function.apply(_removeWhere, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          else if (function == retainAll) {
            return Function.apply(_retainAll, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          else if (function == retainWhere) {
            return Function.apply(_retainWhere, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          return;
        }} catch (_) {}
    }
    return Function.apply(function, positionalArguments, namedArguments);
  }

  bool _containerAdd(E e) {
    if (_properties.container.add(e)) {
      if (e is CollectiveCell) {
        e._properties.synapses.link(e, host: this);
      }
      return true;
    }
    return false;
  }

  bool _containerRemove(E e) {
    if (_properties.container.remove(e)) {
      if (e is CollectiveCell) {
        e._properties.synapses.unlink(this);
      }
      return true;
    }
    return false;
  }

}

/// Provides asynchronous versions of [CollectiveSet] operations.
///
/// All operations return [Future] instances and execute in separate micro tasks.
///
/// ## Usage Example:
/// ```dart
/// final asyncSet = CollectiveSet({1, 2, 3}).async;
/// await asyncSet.add(4); // Non-blocking
/// ```
class CollectiveSetAsync<E> extends CollectiveAsync<E,CollectiveSet<E>> implements CollectiveSet<E> {

  @override
  Iterable<Function> get modifiable => const <Function>{};

  /// Creates an async wrapper for [CollectiveSet] modifiable interfaces.
  const CollectiveSetAsync(super.collective);

  /// Asynchronously adds an [element].
  ///
  /// Returns `true` if [element] was added.
  @override
  Future<bool> add(E element) async {
    return Future<bool>(() => _collective.add(element));
  }

  /// Asynchronously adds multiple [elements].
  @override
  Future<void> addAll(Iterable<E> elements) async {
    return Future<void>(() => _collective.addAll(elements));
  }

  /// Asynchronously removes an [element].
  ///
  /// Returns `true` if [element] was present and removed.
  @override
  Future<bool> remove(Object? element) async {
    return Future<bool>(() => _collective.remove(element));
  }

  /// Async removes all [elements] from the set.
  @override
  Future<void> removeAll(Iterable<Object?> elements) async {
    return Future<void>(() => _collective.removeAll(elements));
  }

  /// Asynchronously removes all elements.
  @override
  Future<void> clear() async {
    return Future<void>(() => _collective.clear());
  }

  /// Async removes all elements from the set that is not in [elements].
  @override
  Future<void> retainAll(Iterable<Object?> elements) async {
    return Future<void>(() => _collective.retainAll(elements));
  }

  /// Async removes all elements from the set that doesn't satisfy the [test].
  @override
  Future<void> retainWhere(bool Function(E element) test) async {
    return Future<void>(() => _collective.retainWhere(test));
  }

  /// Async removes all elements from the set that satisfy the [test].
  @override
  Future<void> removeWhere(bool Function(E element) test) async {
    return Future<void>(() => _collective.removeWhere(test));
  }

  /// `Set<E>` Checks if the set contains an [element].
  @override
  E? lookup(Object? element) {
    return _collective.lookup(element);
  }

  @override
  bool containsAll(Iterable<Object?> other) {
    return _collective.containsAll(other);
  }

  @override
  Set<E> difference(Set<Object?> other) {
    return _collective.difference(other);
  }

  @override
  Set<E> intersection(Set<Object?> other) {
    return _collective.intersection(other);
  }

  @override
  Set<E> union(Set<E> other) {
    return _collective.union(other);
  }

  //

  /// Gets an unmodifiable view of this set.
  @override
  CollectiveSet<E> get unmodifiable => UnmodifiableCollectiveSetAsync<E>(_collective);

  /// Creates a [Async] [CollectiveSet] for async [modifiable] operations
  @override
  CollectiveSetAsync<E> get async => this;

  /// Creates a delegated view with modified behavior.
  ///
  /// Parameters:
  ///   - test: Optional override validation rules
  ///   - map: Optional element transformations
  @override
  CollectiveSet<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return _collective.deputy(test: test, mapObject: mapObject);
  }

  @override
  TestCollective get test => _collective.test;

  @override
  CollectiveSetProperties<E> get _properties => _collective._properties;

}

/// Async operations for an [UnmodifiableCollectiveSet].
///
/// All modification attempts throw [UnsupportedError].
/// Read operations remain async-compatible.
///
/// ## Usage Example:
/// ```dart
/// final immutable = CollectiveSet({1, 2}).unmodifiable;
/// try {
///   await immutable.async.add(3); // Throws
/// } on UnsupportedError catch (_) {
///   // Handle immutable access
/// }
/// ```
class UnmodifiableCollectiveSetAsync<E> extends CollectiveSetAsync<E> implements Unmodifiable {

  /// Creates an async wrapper for an unmodifiable set.
  const UnmodifiableCollectiveSetAsync(super.collective) : super();

  @override
  Future<bool> add(E element) async {
    return Future<bool>.value(false);
  }

  @override
  Future<void> addAll(Iterable<E> elements) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<bool> remove(Object? element) async {
    return Future<bool>.value(false);
  }

  @override
  Future<void> removeAll(Iterable<Object?> elements) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> clear() async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> retainAll(Iterable<Object?> elements) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> retainWhere(bool Function(E element) test) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> removeWhere(bool Function(E element) test) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  CollectiveSet<E> get unmodifiable => this;

}