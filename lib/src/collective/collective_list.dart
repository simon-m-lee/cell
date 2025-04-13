// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../collective.dart';

/// A base class for [CollectiveList] that provides common properties and methods.
typedef CollectiveListBase<E> = _CollectiveList<E>;

/// `CollectiveList<E>` is a fully reactive List implementation that extends
/// Dart's `List<E>` with cell-based reactivity. It automatically propagates
/// changes to connected cells and supports validation, async operations, and
/// immutable variants.
///
/// Key features:
///
/// - **Reactivity**: Automatically notifies changes to connected cells.
/// - **Validation**: Supports custom validation rules for elements and actions.
/// - **Async Operations**: Provides async methods for list operations.
/// - **Immutability**: Can create unmodifiable versions of the list.
/// - **Customizability**: Allows user-defined properties and behaviors.
///
/// Example: Basic Usage
/// ```dart
/// final todoList = CollectiveList<String>();
///
/// // Listen to changes
/// final listener = Cell.listen(
///   bind: todoList,
///   listen: (CollectivePost post, _) {
///     post.body?.forEach((event, elements) {
///       print('$event: $elements');
///     });
///   }
/// );
///
/// todoList.addAll(['Buy milk', 'Walk dog']);
/// // Output: CollectiveEvent._(identifier: #elementAdded): [Buy milk, Walk dog]
///
/// todoList.removeAt(0);
/// // Output: CollectiveEvent._(identifier: #elementRemoved): [Buy milk]
/// ```
///
/// Example: Validation
/// ```dart
/// final validList = CollectiveList<int>(
///   test: TestCollective.create(
///     elementDisallow: (n) => n < 0,  // Blocks negatives
///     maxLength: 3                    // Max 3 items
///   )
/// );
///
/// validList.add(1);     // Allowed
/// validList.add(-1);    // Blocked
/// validList.addAll([2, 3, 4]);  // 4th item blocked
/// validList.add(5);    // Blocked
/// ```
///
/// Example: Async Operations
/// ```dart
///   await asyncList.async.add('Hello');
///   await asyncList.async.insertAll(0, ['Welcome', 'Hi']);
///
///   final removed = await asyncList.async.removeLast();
///   print(removed); // 'Hello'
/// ```
///
/// Example: Async Operations
/// ```dart
/// final asyncList = CollectiveList<String>();
///
/// void main() async {
///   await asyncList.async.add('Hello');
///   await asyncList.async.insertAll(0, ['Welcome', 'Hi']);
///
///   final removed = await asyncList.async.removeLast();
///   print(removed); // 'Hello'
/// }
/// ```
///
/// ```dart
///
/// // Create a reactive list
/// final list = CollectiveList<int>(growable: true);
///
/// // Listen to changes
/// final listener = Cell.listen<CollectivePost>(
///    bind: list,
///    listen: (post, _) => print('Change: ${post.body}')
/// );
///
/// list.add(1); // Triggers elementAdded signal
/// list.insert(0, 2); // Triggers elementAdded signal
/// list.removeAt(0); // Triggers elementRemoved signal
///  ```
///  Example: Chained Collectives
/// ```dart
/// // Create source list
/// final source = CollectiveList<int>([1, 2, 3]);
///
/// // Create filtered view
/// final filtered = CollectiveList<int>(
///     bind: source,
///     test: TestCollective.create(
///         elementDisallow: (e, _) => e! < 2
///     )
/// );
///
/// // Changes to source propagate to filtered
/// source.add(0); // Won't appear in filtered
/// source.add(5); // Will appear in filtered
/// ```
abstract interface class CollectiveList<E> implements CollectiveCell<E> {

  @override
  CollectiveListProperties<E> get _properties;

  /// Creates an empty growable list by default from elements
  factory CollectiveList({
    Cell? bind,
    TestCollective test,
    bool growable
  }) = _CollectiveList<E>;

  /// Creates a growable list by default from elements
  factory CollectiveList.of(Iterable<E> elements, {
    Cell? bind,
    TestCollective test,
    bool growable
  }) = _CollectiveList<E>.of;

  /// Creates a [CollectiveList] from properties
  factory CollectiveList.fromProperties(CollectiveListProperties<E> properties, {Iterable<E>? elements}) = _CollectiveList<E>.fromProperties;

  /// Creates an unmodifiable [CollectiveList] from elements
  factory CollectiveList.unmodifiable(CollectiveList<E> bind, {bool unmodifiableElement = true}) {
    return UnmodifiableCollectiveList<E>.bind(bind, unmodifiableElement: unmodifiableElement);
  }

  /// Creates an user defined [CollectiveList]
  static CollectiveList<E> create<E, I extends List<E>>({
    Iterable<E>? elements,
    Cell? bind,
    ContainerType container = ContainerType.growableTrue,
    CollectiveReceptor receptor = CollectiveReceptor.unchanged,
    TestCollective test = TestCollective.passed,
    MapObject? mapObject,
    Synapses synapses = Synapses.enabled
  }) {
    return _CollectiveList<E>.fromProperties(CollectiveCellProperties<E,I>(
        bind: bind,
        container: container,
        receptor: receptor,
        test: test,
        mapObject: mapObject,
        synapses: synapses
    ), elements: elements);
  }

  /// Sets the value at the given [index] in the list to [value].
  ///
  /// [Sync] CollectiveList returns void
  /// [Async] CollectiveList returns `Future<void>`
  setValueAt(int index, E value);


  /// Sets the first element of the list
  ///
  /// [Sync] CollectiveList returns void
  /// [Async] CollectiveList returns `Future<void>`
  setFirst(E value);

  // List operations

  /// Sets the value at the given [index] in the list to [value].
  void operator []=(int index, E value);

  /// Sets the first element of the list
  set first(E value);

  /// Adds an element to the set
  ///
  /// [Sync] CollectiveList returns void
  /// [Async] CollectiveList returns `Future<void>`
  add(E value);

  /// Adds all elements from the iterable to the set
  ///
  /// [Sync] CollectiveList returns void
  /// [Async] CollectiveList returns `Future<void>`
  addAll(Iterable<E> iterable);

  /// Clears the set, removing all elements
  ///
  /// [Sync] CollectiveList returns void
  /// [Async] CollectiveList returns `Future<void>`
  clear();

  /// Fills the range of elements with the specified value
  ///
  /// [Sync] CollectiveList returns void
  /// [Async] CollectiveList returns `Future<void>`
  fillRange(int start, int end, [E? fillValue]);

  /// Inserts an [element] at the specified [index]
  ///
  /// [Sync] CollectiveList returns void
  /// [Async] CollectiveList returns `Future<void>`
  insert(int index, E element);

  /// Inserts all elements from the [iterable] at the specified [index]
  ///
  /// [Sync] CollectiveList returns void
  /// [Async] CollectiveList returns `Future<void>`
  insertAll(int index, Iterable<E> iterable);

  /// Removes the specified element from the set
  ///
  /// [Sync] CollectiveList returns [bool] if the element was removed
  /// [Async] CollectiveList returns `Future<bool>` if the element was removed
  remove(Object? value);

  /// Removes the element at the specified [index]
  ///
  /// [Sync] CollectiveList returns the removed element
  /// [Async] CollectiveList returns `Future<E>` if the element was removed
  removeAt(int index);

  /// Removes the last element from the set
  ///
  /// [Sync] CollectiveList returns the removed element
  /// [Async] CollectiveList returns `Future<E>` if the element was removed
  removeLast();

  /// Removes a range of elements from the set
  ///
  /// [Sync] CollectiveList returns void
  /// [Async] CollectiveList returns `Future<void>`
  removeRange(int start, int end);

  /// Removes all elements in the iterable from the set
  ///
  /// [Sync] CollectiveSet returns void
  /// [Async] CollectiveSet returns `Future<void>`
  removeWhere(bool Function(E element) test);

  /// Replaces the range of elements with the specified [replacements]
  ///
  /// [Sync] CollectiveList returns void
  /// [Async] CollectiveList returns `Future<void>`
  replaceRange(int start, int end, Iterable<E> replacements);

  /// Retains only the elements that satisfy the test
  ///
  /// [Sync] CollectiveSet returns void
  /// [Async] CollectiveSet returns `Future<void>`
  retainWhere(bool Function(E element) test);

  /// Sets the elements in the range to the specified [iterable]
  ///
  /// [Sync] CollectiveList returns void
  /// [Async] CollectiveList returns `Future<void>`
  setAll(int index, Iterable<E> iterable);

  /// Sets the elements in the range to the specified [iterable]
  ///
  /// [Sync] CollectiveList returns void
  /// [Async] CollectiveList returns `Future<void>`
  setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]);

  //

  /// Creates a new [CollectiveList] by concatenating this list with another.
  List<E> operator +(List<E> other);

  /// The object at the given index in the list.
  E operator [](int index);

  /// An unmodifiable Map view of this list.
  Map<int, E> asMap();

  /// Creates an Iterable that iterates over a range of elements.
  Iterable<E> getRange(int start, int end);

  /// The first index of [element] in this list.
  int indexOf(E element, [int start = 0]);

  /// The first index in the list that satisfies the provided [test].
  int indexWhere(bool Function(E element) test, [int start = 0]);

  /// The last index of [element] in this list.
  int lastIndexOf(E element, [int? start]);

  /// The last index in the list that satisfies the provided [test].
  int lastIndexWhere(bool Function(E element) test, [int? start]);

  /// Setting the length changes the number of elements in the list.
  set length(int newLength);

  /// An Iterable of the objects in this list in reverse order.
  Iterable<E> get reversed;

  /// Shuffles the elements of this list randomly.
  void shuffle([Random? random]);

  /// Sorts this list according to the order specified by the [compare] function.
  void sort([int Function(E a, E b)? compare]);

  /// The sublist of this list from [start] to [end].
  List<E> sublist(int start, [int? end]);

  /// Creates an [Deputy] from this [CollectiveList] with either [test] or [map] or both properties.
  /// The new [CollectiveList]
  @override
  CollectiveList<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject});

  @override
  CollectiveList<E> get unmodifiable;

  /// Creates a [Async] [CollectiveListAsync] for async [modifiable] operations
  @override
  CollectiveListAsync<E> get async;

}

class _CollectiveList<E> extends CollectiveCell<E> with ListMixin<E>, OpenListMixin<E> implements CollectiveList<E>, Sync {

  /// Creates an empty growable list by default from elements
  _CollectiveList({
    Cell? bind,
    TestCollective test = TestCollective.passed,
    bool growable = true
  }) : super(CollectiveListProperties<E>(
    bind: bind,
    container: growable ? ContainerType.growableTrue : ContainerType.growableFalse,
    test: test,
  ));

  /// Creates a growable list by default from elements
  _CollectiveList.of(Iterable<E> elements, {
    Cell? bind,
    TestCollective test = TestCollective.passed,
    bool growable = true
  }) : super(CollectiveListProperties<E>(
    bind: bind,
    container: growable ? ContainerType.growableTrue : ContainerType.growableFalse,
    test: test,
  ), elements: elements);

  /// Creates a [CollectiveList] from properties
  _CollectiveList.fromProperties(CollectiveListProperties<E> super.properties, {super.elements});

  /// Creates an [Deputy] from this [CollectiveList] with either [test] or [map] or both properties.
  /// The new [CollectiveList]
  @override
  CollectiveList<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return CollectiveListDeputy<E>._(this, test: test, mapObject: mapObject);
  }

  @override
  late final CollectiveList<E> unmodifiable = CollectiveList.unmodifiable(this);

  /// Creates an async variant for [modifiable] operations
  @override
  CollectiveListAsync<E> get async => CollectiveListAsync<E>(this);

}

/// A helper class that provides an "deputy" (deputy) interface for [CollectiveList].
///
/// This class extends [CollectiveList] and mixes in [Deputy] functionality to create
/// a wrapper that can modify behavior while delegating operations to the original list.
/// It's particularly useful for adding temporary modifications like additional
/// validation rules or value transformations.
///
/// The deputy maintains a reference to the original list and can apply:
/// - Additional test rules (validation)
/// - Value mapping transformations
/// - Other behavior modifications
///
/// Example:
/// ```dart
/// final originalList = CollectiveList<int>();
/// final deputy = originalList.deputy(
///   test: customTestRules,
///   map: valueMapper
/// );
/// ```
class CollectiveListDeputy<E> extends CollectiveListBase<E> with Deputy<CollectiveList<E>> {

  CollectiveListDeputy._(CollectiveList<E> bind, {TestCollective? test, MapObject? mapObject})
      : super.fromProperties(bind._properties.deputy(bind: bind, test: test, mapObject: mapObject));

  @override
  CollectiveList<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return CollectiveListDeputy<E>._(_properties.bind as CollectiveList<E>, test: test, mapObject: mapObject);
  }
}

/// An unmodifiable version of [CollectiveList] that prevents all mutating operations.
///
/// This class wraps a [CollectiveList] and throws [UnsupportedError] for any operation
/// that would modify the list contents. It implements the [Unmodifiable] marker interface
/// and provides all read-only list operations.
///
/// The unmodifiable list can optionally make its elements unmodifiable as well when
/// [unmodifiableElement] is true. For cell elements, this means wrapping them in
/// their unmodifiable versions.
///
/// Example:
/// ```dart
/// final original = CollectiveList<int>([1, 2, 3]);
/// final unmodifiable = original.unmodifiable;
///
/// unmodifiable[0]; // Allowed - reading works
/// unmodifiable.add(4); // Throws UnsupportedError
/// ```
class UnmodifiableCollectiveList<E> extends UnmodifiableCollectiveCell<E> with ListMixin<E>, OpenListMixin<E> implements CollectiveList<E> {

  /// Creates an unmodifiable list from the given elements.
  ///
  /// Parameters:
  ///   - elements: The elements to include in the unmodifiable list
  ///   - unmodifiableElement: Whether to also make elements unmodifiable (default true)
  ///   - properties: Optional custom properties for the list
  UnmodifiableCollectiveList(Iterable<E> elements, {bool unmodifiableElement = true, CollectiveListProperties<E>? properties})
      : super(properties ?? CollectiveListProperties<E>(), unmodifiableElement: unmodifiableElement, elements: elements);

  /// Creates an unmodifiable list bound to an existing [Collective].
  ///
  /// Parameters:
  ///   - bind: The collective to make unmodifiable
  ///   - unmodifiableElement: Whether to make elements unmodifiable (default true)
  ///   - properties: Optional custom properties
  ///   - elements: Optional elements to use instead of bind's elements
  UnmodifiableCollectiveList.bind(Collective bind, {bool unmodifiableElement = true, CollectiveListProperties<E>? properties, Iterable<E>? elements})
      : super(properties ?? CollectiveListProperties<E>(), unmodifiableElement: unmodifiableElement,
      elements: elements ?? (unmodifiableElement ? bind.whereType<E>() : bind.whereType<E>().map<E>((e) => e is Cell ? e.unmodifiable as E : e))
  );

  /// Creates from properties with optional elements and unmodifiability setting.
  UnmodifiableCollectiveList.fromProperties(super.properties, {super.unmodifiableElement, super.elements}) : super();

  /// Factory method to create an unmodifiable list with full configuration.
  ///
  /// Parameters:
  ///   - elements: Initial elements
  ///   - unmodifiableElement: Make elements unmodifiable (default true)
  ///   - bind: Cell to bind to
  ///   - container: Container type configuration
  ///   - receptor: Signal receptor configuration
  ///   - test: Test configuration
  ///   - map: Mapping configuration
  ///   - synapses: Synapses configuration
  static CollectiveList<E> create<E, I extends List<E>>({
    Iterable<E>? elements,
    bool unmodifiableElement = true,
    Cell? bind,
    ContainerType? container,
    CollectiveReceptor receptor = CollectiveReceptor.unchanged,
    TestCollective test = TestCollective.passed,
    MapObject? mapObject,
    Synapses synapses = Synapses.enabled
  }) {
    return UnmodifiableCollectiveList<E>.fromProperties(
        CollectiveCellProperties<E,I>(bind: bind, container: container, test: test, receptor: receptor, synapses: synapses),
        unmodifiableElement: unmodifiableElement,
        elements: elements
    );
  }

  /// Creates an deputy for this unmodifiable list.
  ///
  /// Note: The deputy will still enforce unmodifiability of the underlying list.
  ///
  /// Parameters:
  ///   - test: Additional test rules
  ///   - map: Value mapping configuration
  @override
  CollectiveList<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return UnmodifiableCollectiveList.fromProperties(_properties.deputy(bind: this, test: test, mapObject: mapObject),
        unmodifiableElement: _unmodifiableElement,
        elements: this
    );
  }

  @override
  CollectiveList<E> get unmodifiable => this;

  /// Creates an async variant for [modifiable] operations
  @override
  CollectiveListAsync<E> get async => UnmodifiableCollectiveListAsync<E>(this);
  
}

/// A mixin that provides reactive list operations for [CollectiveCell].
///
/// This mixin implements the [ListMixin] interface and adds cell-based reactivity
/// to standard list operations. It handles:
/// - Automatic change notifications
/// - Validation through test rules
/// - Cell linking/unlinking for reactive elements
/// - Transactional modifications with rollback on failure
///
/// All mutating operations are wrapped in validation checks and will:
/// 1. Verify the operation is allowed by test rules
/// 2. Apply the change if valid
/// 3. Notify linked cells if successful
/// 4. Maintain proper cell linkages for reactive elements
///
/// Example:
/// ```dart
/// final list = CollectiveList<int>()..add(1); // Valid operation
/// list.unmodifiable.add(2); // Throws UnsupportedError
/// ```
mixin OpenListMixin<E> on CollectiveCell<E> implements List<E>, Collective<E> {

  @override
  CollectiveCellProperties<E, List<E>> get _properties => super._properties as CollectiveCellProperties<E, List<E>>;

  /// The set of modifiable list operations that can be validated.
  ///
  /// Includes all standard list mutation methods:
  /// - add/addAll
  /// - insert/insertAll
  /// - remove/removeAt/removeLast/removeRange
  /// - clear/fillRange/replaceRange
  /// - setAll/setRange
  @override
  Iterable<Function> get modifiable => <Function>{add, addAll, clear, remove, removeWhere,
    retainWhere, fillRange, insert, insertAll, removeAt, removeLast, removeRange, replaceRange,
    setAll, setRange, sort, shuffle, ...super.modifiable};

  //

  @override
  E operator [](int index) => _properties.container.elementAt(index);

  @override
  set length(int newLength) {
    if (this is! Unmodifiable) {
      _properties.container.length = newLength;
    }
  }

  @override
  int get length => _properties.container.length;

  /// Sets the value at the given [index] in the list to [value].
  void setValueAt(int index, E value) => apply(setValueAt, [index, value]);

  /// Sets the first element of the list
  void setFirst(E value) => apply(setFirst, [value]);

  @override
  void operator []=(int index, E value) => apply(setValueAt, [index, value]);

  /// Adds an element to the list after validation.
  ///
  /// Validates:
  /// 1. List is modifiable
  /// 2. Operation is allowed by test rules
  /// 3. Element passes element-level validation
  @override
  void add(E element) => apply(add, [element]);

  /// Adds all elements after validation.
  @override
  void addAll(Iterable<E> iterable) => apply(addAll, [iterable]);

  /// Clears the list after validation.
  @override
  void clear() => apply(clear, null);

  /// Removes an element after validation.
  @override
  bool remove(Object? object) => apply(remove, [object]).isNotEmpty;

  /// Removes elements matching test after validation.
  @override
  void removeWhere(bool Function(E element) test) => apply(removeWhere, [test]);

  /// Retains elements matching test after validation.
  @override
  void retainWhere(bool Function(E element) test) => apply(retainWhere, [test]);

  //

  @override
  void fillRange(int start, int end, [E? fillValue]) => apply(fillRange, [start, end, fillValue]);

  @override
  void insert(int index, E element) => apply(insert, [index, element]);

  @override
  void insertAll(int index, Iterable<E> iterable) => apply(insert, [index, iterable]);

  @override
  E removeAt(int index) => apply(removeAt, [index]).values.first.first;

  @override
  E removeLast() => apply(removeLast, null).values.first.first;

  @override
  void removeRange(int start, int end) => apply(removeRange, [start, end]);

  @override
  void replaceRange(int start, int end, Iterable<E> newContents) => apply(removeRange, [start, end, newContents]);

  @override
  void setAll(int index, Iterable<E> iterable) => apply(setAll, [index, iterable]);

  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    apply(setRange, [start, end, iterable, skipCount]);
  }

  @override
  void shuffle([Random? random]) => apply(shuffle, [random]);

  /// Sorts this list according to the order specified by the [compare] function.
  @override
  void sort([int Function(E a, E b)? compare]) => apply(sort, [compare]);



  Map<CollectiveEvent, Iterable<E>> _setValueAt(int index, E value, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Iterable<E>>{};

    if (this is! Unmodifiable && modifiable.contains(setValueAt)) {
      if (test.action(setValueAt, this, arguments: (positionalArguments: [index, value], namedArguments: null))) {

        if (test.element(e, this, action: setValueAt)) {
          _properties.container[index] = value;

          if (value is CollectiveCell && !_properties.container.contains(value)) {
            value._properties.synapses.unlink(this);
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

  Map<CollectiveEvent, Iterable<E>> _setFirst(E value, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Iterable<E>>{};

    if (this is! Unmodifiable && modifiable.contains(setFirst)) {
      if (test.action(setFirst, this, arguments: (positionalArguments: [value], namedArguments: null))) {
        if (test.element(e, this, action: setValueAt)) {
          _properties.container.first = value;

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

  Map<CollectiveEvent, Iterable<E>> _add(E element, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Iterable<E>>{};

    if (this is! Unmodifiable && modifiable.contains(add)) {
      if (test.action(add, this, arguments: (positionalArguments: [element], namedArguments: null))) {
        if (test.element(element, this, action: add) && _containerAdd(element)) {
          map[Collective.elementAdded] = <E>[element];
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

  Map<CollectiveEvent, Iterable<E>> _fillRange(int start, int end, {E? fillValue, bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, List<E>>{};

    if (this is! Unmodifiable && modifiable.contains(fillRange)) {
      if (test.action(fillRange, this, arguments: (positionalArguments: [start, end], namedArguments: {#fillValue: fillValue}))) {
        final removes = getRange(start, end);
        if (removes.every((e) => test.element(e, deputy is Collective ? deputy : this, action: remove))) {
          if (test.element(fillValue, this, action: add)) {
            _properties.container.fillRange(start, end, fillValue);
            if (fillValue is CollectiveCell) {
              fillValue._properties.synapses.link(fillValue, host: this);
            }

            for (var e in removes) {
              if (!contains(e)) {
                if (e is CollectiveCell) {
                  e._properties.synapses.unlink(this);
                }
              }
            }

            map[Collective.elementRemoved] = removes.toList(growable: false);
            if (fillValue != null) {
              map[Collective.elementAdded] = [fillValue];
            }
            if (notification) {
              final post = CollectivePost._(from: deputy ?? this, body: map);
              _properties.receptor(cell: this, signal: post);
            }
          }
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _insert(int index, E element, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, List<E>>{};

    if (this is! Unmodifiable && modifiable.contains(insert)) {
      if (test.action(insert, this, arguments: (positionalArguments: [index, element], namedArguments: null))) {
        if (test.element(element, this, action: add) && _containerAdd(element)) {
          _properties.container.insert(index, element);
          map[Collective.elementAdded] = [element];
          if (element is CollectiveCell) {
            element._properties.synapses.link(element, host: this);
          }
        }
        if (notification) {
          final post = CollectivePost._(from: deputy ?? this, body: map);
          _properties.receptor(cell: this, signal: post);
        }
      }
    }

    return map;
  }


  Map<CollectiveEvent, Iterable<E>> _insertAll(int index, Iterable<E> iterable, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, List<E>>{};

    if (this is! Unmodifiable && modifiable.contains(insertAll)) {
      if (test.action(insertAll, this, arguments: (positionalArguments: [index, iterable], namedArguments: null))) {
        final adds = iterable.where((e) => test.element(e, deputy is Collective ? deputy : this, action: add));
        _properties.container.insertAll(index, adds);
        for (var e in iterable) {
          if (e is CollectiveCell) {
            e._properties.synapses.link(e, host: this);
          }
        }
        map[Collective.elementAdded] = iterable.toList(growable: false);
        if (notification) {
          final post = CollectivePost._(from: deputy ?? this, body: map);
          _properties.receptor(cell: this, signal: post);
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

  Map<CollectiveEvent, Iterable<E>> _removeAt(int index, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, List<E>>{};

    if (this is! Unmodifiable && modifiable.contains(removeAt)) {
      if (test.action(removeAt, this, arguments: (positionalArguments: [index], namedArguments: null))) {
        final e = elementAt(index);
        if (test.element(e, deputy is Collective ? deputy : this, action: remove) && _properties.container.removeAt(index) != null) {
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
        if (test.element(e, deputy is Collective ? deputy : this, action: remove) && _properties.container.removeLast() == e) {
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

  Map<CollectiveEvent, Iterable<E>> _removeRange(int start, int end, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, List<E>>{};

    if (this is! Unmodifiable && modifiable.contains(removeRange)) {
      if (test.action(_removeRange, this, arguments: (positionalArguments: [start, end], namedArguments: null))) {
        final removes = getRange(start, end);
        if (removes.isNotEmpty && removes.every((e) => test.element(e, deputy is Collective ? deputy : this, action: remove))) {
          _properties.container.removeRange(start, end);

          for (var e in removes) {
            if (!contains(e)) {
              if (e is CollectiveCell) {
                e._properties.synapses.unlink(this);
              }
            }
          }

          map[Collective.elementRemoved] = removes.toList(growable: false);
          if (notification) {
            final post = CollectivePost._(from: deputy ?? this, body: map);
            _properties.receptor(cell: this, signal: post);
          }

        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _replaceRange(int start, int end, Iterable<E> newContents, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, List<E>>{};

    if (this is! Unmodifiable && modifiable.contains(replaceRange)) {
      if (test.action(replaceRange, this, arguments: (positionalArguments: [start, end, newContents], namedArguments: null))) {
        final originals = _properties.container.toList(growable: false);
        final removes = getRange(start, end);

        if (removes.every((e) => test.element(e, deputy is Collective ? deputy : this, action: remove))) {
          if (newContents.every((e) => test.element(e, deputy is Collective ? deputy : this, action: add))) {
            _properties.container.replaceRange(start, end, newContents);

            for (var e in newContents) {
              if (!originals.contains(e)) {
                if (e is CollectiveCell) {
                  e._properties.synapses.link(e, host: this);
                }
              }
            }

            for (var e in removes) {
              if (!_properties.container.contains(e)) {
                if (e is CollectiveCell) {
                  e._properties.synapses.unlink(this);
                }
              }
            }

            map[Collective.elementRemoved] = removes.toList(growable: false);
            map[Collective.elementAdded] = newContents.toList(growable: false);

            if (notification) {
              final post = CollectivePost._(from: deputy ?? this, body: map);
              _properties.receptor(cell: this, signal: post);
            }
          }
        }
      }
    }

    return map;
  }


  Map<CollectiveEvent, Iterable<E>> _removeWhere(bool Function(E element) test, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, List<E>>{};

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
    final map = <CollectiveEvent, List<E>>{};

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

  Map<CollectiveEvent, Iterable<E>> _setAll(int index, Iterable<E> iterable, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, List<E>>{};

    if (this is! Unmodifiable && modifiable.contains(setAll)) {
      if (test.action(setAll, this, arguments: (positionalArguments: [index, iterable], namedArguments: null))) {
        final removes = getRange(index, index + iterable.length);
        if (removes.every((e) => test.element(e, deputy is Collective ? deputy : this, action: remove))) {
          if (iterable.every((e) => test.element(e, deputy is Collective ? deputy : this, action: add))) {
            setAll(index, iterable);

            for (var e in removes) {
              if (e is CollectiveCell && !contains(e)) {
                e._properties.synapses.unlink(this);
              }
            }
            map[Collective.elementRemoved] = removes.toList(growable: false);

            for (var e in iterable) {
              if (e is CollectiveCell) {
                e._properties.synapses.link(e, host: this);
              }
            }
            map[Collective.elementAdded] = iterable.toList(growable: false);
            if (notification) {
              final post = CollectivePost._(from: deputy ?? this, body: map);
              _properties.receptor(cell: this, signal: post);
            }
          }
        }
      }
    }

    return map;
  }

  Map<CollectiveEvent, Iterable<E>> _setRange(int start, int end, Iterable<E> iterable, {int skipCount = 0, bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, List<E>>{};

    if (this is! Unmodifiable && modifiable.contains(setRange)) {
      if (test.action(setAll, this, arguments: (positionalArguments: [start, end, iterable], namedArguments: null))) {
        final removes = getRange(start, end);
        if (removes.every((e) => test.element(e, deputy is Collective ? deputy : this, action: remove))) {
          final adds = skipCount != 0 ? iterable.toList(growable: false).sublist(skipCount) : iterable;
          if (adds.every((e) => test.element(e, deputy is Collective ? deputy : this, action: add))) {
            setRange(start, end, iterable, skipCount);

            for (var e in removes) {
              if (e is CollectiveCell && !contains(e)) {
                e._properties.synapses.unlink(this);
              }
            }
            map[Collective.elementRemoved] = removes.toList(growable: false);

            for (var e in adds) {
              if (e is CollectiveCell) {
                e._properties.synapses.link(e, host: this);
              }
            }

            map[Collective.elementAdded] = adds.toList(growable: false);
            if (notification) {
              final post = CollectivePost._(from: deputy ?? this, body: map);
              _properties.receptor(cell: this, signal: post);
            } }
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
      else if (function == addAll) {
        return Function.apply(_addAll, positionalArguments, {#notification: notification});
      }
      else if (function == clear) {
        return Function.apply(_clear, null, {#notification: notification});
      }
      else if (function == fillRange) {
        return Function.apply(_fillRange, positionalArguments, {#fillValue: namedArguments![#fillValue], #notification: notification});
      }
      else if (function == insert) {
        return Function.apply(_insert, positionalArguments, {#notification: notification});
      }
      else if (function == insertAll) {
        return Function.apply(_insertAll, positionalArguments, {#notification: notification});
      }
      else if (function == remove) {
        return Function.apply(_remove, positionalArguments, {#notification: notification});
      }
      else if (function == removeAt) {
        return Function.apply(_removeAt, positionalArguments, {#notification: notification});
      }
      else if (function == removeLast) {
        return Function.apply(_removeLast, positionalArguments, {#notification: notification});
      }
      else if (function == removeRange) {
        return Function.apply(_removeRange, positionalArguments, {#notification: notification});
      }
      else if (function == replaceRange) {
        return Function.apply(_replaceRange, positionalArguments, {#notification: notification});
      }
      else if (function == removeWhere) {
        return Function.apply(_removeWhere, positionalArguments, {#notification: notification});
      }
      else if (function == retainWhere) {
        return Function.apply(_retainWhere, positionalArguments, {#notification: notification});
      }
      else if (function == setAll) {
        return Function.apply(_setAll, positionalArguments, {#notification: notification});
      }
      else if (function == setRange) {
        return Function.apply(_setRange, positionalArguments, {#skipCount: namedArguments![#skipCount], #notification: notification});
      }
      else if (function == setFirst) {
        return Function.apply(_setFirst, positionalArguments, {#skipCount: namedArguments![#skipCount], #notification: notification});
      }
      else if (function == setValueAt) {
        return Function.apply(_setValueAt, positionalArguments, {#skipCount: namedArguments![#skipCount], #notification: notification});
      }
      else if (function == sort) {
        if (test.action(sort, this, arguments: (positionalArguments: positionalArguments, namedArguments: namedArguments))) {
          _properties.container.sort(positionalArguments!.first as int Function(E a, E b));
        }
      }
      else if (function == shuffle) {
        if (test.action(shuffle, this, arguments: (positionalArguments: positionalArguments, namedArguments: namedArguments))) {
          _properties.container.shuffle(positionalArguments!.first as Random);
        }
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

/// Provides asynchronous versions of [CollectiveList] operations.
///
/// This class wraps a [CollectiveList] and exposes all mutating operations
/// as Futures, allowing them to be used in async contexts. Each operation:
///
/// 1. Wraps the synchronous operation in a Future
/// 2. Maintains all the same validation rules as the synchronous version
/// 3. Preserves the reactive behavior and cell linkages
///
/// Example usage:
/// ```dart
/// final list = CollectiveList<int>().async;
/// await list.add(1); // Async version of add
/// await list.insertAll(0, [2, 3]); // Async batch operation
/// ```
class CollectiveListAsync<E> extends CollectiveAsync<E,CollectiveList<E>> implements CollectiveList<E> {

  /// Creates an async callable wrapper for a [CollectiveList].
  ///
  /// Typically accessed via the [CollectiveList.async] getter rather than
  /// constructed directly.
  const CollectiveListAsync(super.collective);

  /// Async sets the value at the given [index] in the list to [value].
  @override
  Future<void> setValueAt(int index, E value) async {
    return Future<void>(() => _collective.setValueAt(index, value));
  }

  /// Async sets the first element of the list
  @override
  Future<void> setFirst(E value) async {
    return Future<void>(() => _collective.setFirst(value));
  }

  /// Async adds [element] to the list.
  @override
  Future<void> add(E element) async {
    return Future<void>(() => _collective.add(element));
  }

  /// Async adds all [elements] to the list.
  @override
  Future<void> addAll(Iterable<E> elements) async {
    return Future<void>(() => _collective.addAll(elements));
  }

  /// Async removes all elements from the list.
  @override
  Future<void> clear() async {
    return Future<void>(() => _collective.clear());
  }

  /// Async removes [element] from the list.
  @override
  Future<bool> remove(Object? element) async {
    return Future<bool>(() => _collective.remove(element));
  }

  /// Async removes elements from the list that satisfy the [test].
  @override
  Future<void> removeWhere(bool Function(E element) test) async {
    return Future<void>(() => _collective.removeWhere(test));
  }

  /// Async removes elements from the list that doesn't satisfy the [test].
  @override
  Future<void> retainWhere(bool Function(E element) test) async {
    return Future<void>(() => _collective.retainWhere(test));
  }

  /// Async fills a range of elements with [fillValue].
  @override
  Future<void> fillRange(int start, int end, [E? fillValue]) async {
    return Future<void>(() => _collective.fillRange(start, end, fillValue));
  }

  /// Async inserts [element] at [index].
  @override
  Future<void> insert(int index, E element) async {
    return Future<void>(() => _collective.insert(index, element));
  }

  /// Async inserts all [elements] at [index].
  @override
  Future<void> insertAll(int index, Iterable<E> elements) async {
    return Future<void>(() => _collective.insertAll(index, elements));
  }

  /// Async removes the element at [index].
  @override
  Future<void> removeAt(int index) async {
    return Future<void>(() => _collective.removeAt(index));
  }

  /// Async removes the last element.
  @override
  Future<void> removeLast() async {
    return Future<void>(() => _collective.removeLast());
  }

  /// Removes a range of elements from the list.
  ///
  /// Removes the elements with positions greater than or equal to start and less than end,
  /// from the list. This reduces the list's length by end - start.
  @override
  Future<void> removeRange(int start, int end) async {
    return Future<void>(() => _collective.removeRange(start, end));
  }

  /// Replaces a range of elements with the elements of replacements.
  ///
  /// Removes the objects in the range from start to end, then inserts the elements of replacements at start.
  @override
  Future<void> replaceRange(int start, int end, Iterable<E> newContents) async {
    return Future<void>(() => _collective.replaceRange(start, end, newContents));
  }

  /// The elements of iterable are written into this list, starting at position index.
  /// This operation does not increase the length of the list.
  ///
  /// The index must be non-negative and no greater than length.
  ///
  /// The iterable must not have more elements than what can fit from index to length.
  ///
  /// If iterable is based on this list, its values may change during the setAll operation.
  @override
  Future<void> setAll(int index, Iterable<E> elements) async {
    return Future<void>(() => _collective.setAll(index, elements));
  }

  /// Writes some elements of iterable into a range of this list.
  ///
  /// Copies the objects of iterable, skipping skipCount objects first, into the range from start,
  /// inclusive, to end, exclusive, of this list.
  @override
  Future<void> setRange(int start, int end, Iterable<E> newContents, [int skipCount = 0]) async {
    return Future<void>(() => _collective.setRange(start, end, newContents, skipCount));
  }

  /// The object at the given index in the list
  @override
  E operator [](int index) {
    return _collective[index];
  }

  /// Sets the value at the given index in the list to value.
  @override
  void operator []=(int index, E value) {
    _collective[index] = value;
  }

  /// Setting the length changes the number of elements in the list.
  @override
  set length(int newLength) {
    _collective.length = newLength;
  }

  //

  /// Gets an unmodifiable view of this list.
  @override
  CollectiveList<E> get unmodifiable => UnmodifiableCollectiveListAsync<E>(_collective);

  /// Creates a [Async] [CollectiveList] for async [modifiable] operations
  @override
  CollectiveListAsync<E> get async => this;

  /// Creates a delegated view with modified behavior.
  ///
  /// Parameters:
  ///   - test: Optional override validation rules
  ///   - map: Optional element transformations
  @override
  CollectiveList<E> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return _collective.deputy(test: test, mapObject: mapObject);
  }

  @override
  TestCollective get test => _collective.test;

  @override
  CollectiveListProperties<E> get _properties => _collective._properties;

  @override
  List<E> operator +(List<E> other) {
    return _collective + other;
  }

  @override
  Map<int, E> asMap() {
    return _collective.asMap();
  }

  @override
  set first(E value) {
    _collective.setFirst(value);
  }

  @override
  Iterable<E> getRange(int start, int end) {
    return _collective.getRange(start, end);
  }

  @override
  int indexOf(E element, [int start = 0]) {
    return _collective.indexOf(element, start);
  }

  @override
  int indexWhere(bool Function(E element) test, [int start = 0]) {
    return _collective.indexWhere(test, start);
  }

  @override
  int lastIndexOf(E element, [int? start]) {
    return _collective.lastIndexOf(element, start);
  }

  @override
  int lastIndexWhere(bool Function(E element) test, [int? start]) {
    return _collective.lastIndexWhere(test, start);
  }

  @override
  Iterable<E> get reversed => _collective.reversed;

  @override
  void shuffle([Random? random]) {
    return _collective.shuffle(random);
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    _collective.sort(compare);
  }

  @override
  List<E> sublist(int start, [int? end]) {
    return _collective.sublist(start, end);
  }

}

/// An async callable interface for [UnmodifiableCollectiveList] that prevents modifications.
///
/// This class provides async versions of list operations that all throw
/// [UnsupportedError] since the underlying list is unmodifiable. It implements
/// the same interface as [CollectiveListAsync] but with enforced immutability.
///
/// Key characteristics:
/// - All mutating operations throw UnsupportedError
/// - Read operations work normally
/// - Maintains consistency with synchronous unmodifiable behavior
/// - Provides clear error messages for attempted modifications
///
/// Example:
/// ```dart
/// final unmodifiable = CollectiveList<int>([1, 2, 3]).unmodifiable.async;
/// await unmodifiable.add(4); // Throws UnsupportedError
/// ```
class UnmodifiableCollectiveListAsync<E> extends CollectiveListAsync<E> implements Unmodifiable {

  @override
  Iterable<Function> get modifiable => const <Function>{};

  /// Creates an async callable for an unmodifiable list.
  ///
  /// Typically accessed via [UnmodifiableCollectiveList.async] rather than
  /// constructed directly.
  const UnmodifiableCollectiveListAsync(super.collective) : super();

  /// Async sets the value at the given [index] in the list to [value].
  @override
  Future<void> setValueAt(int index, E value) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  /// Async sets the first element of the list
  @override
  Future<void> setFirst(E value) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> add(E element) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> addAll(Iterable<E> elements) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> clear() async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<bool> remove(Object? element) async {
    return Future<bool>.value(false);
  }

  @override
  Future<void> removeWhere(bool Function(E element) test) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> retainWhere(bool Function(E element) test) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> fillRange(int start, int end, [dynamic fillValue]) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> insert(int index, element) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> insertAll(int index, Iterable elements) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> removeAt(int index) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> removeLast() async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> removeRange(int start, int end) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> replaceRange(int start, int end, Iterable newContents) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> setAll(int index, Iterable elements) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> setRange(int start, int end, Iterable newContents, [int skipCount = 0]) async {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  void shuffle([Random? random]) {
    throw UnsupportedError('Unmodifiable operation');
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    throw UnsupportedError('Unmodifiable operation');
  }

  @override
  CollectiveList<E> get unmodifiable => this;

}