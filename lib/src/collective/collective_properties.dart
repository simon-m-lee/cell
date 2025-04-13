// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../collective.dart';

/// Type alias for Set-specific Collective properties
typedef CollectiveSetProperties<E> = CollectiveCellProperties<E,Set<E>>;

/// Type alias for List-specific Collective properties
typedef CollectiveListProperties<E> = CollectiveCellProperties<E,List<E>>;

/// Type alias for Queue-specific Collective properties
typedef CollectiveQueueProperties<E> = CollectiveCellProperties<E,Queue<E>>;

/// Interface defining configuration properties for [Collective] instances.
///
/// This interface provides access to the core configuration needed by reactive collections,
/// including container type, receptor handling, and validation rules.
///
/// Type Parameters:
///   - `<E>`: The type of elements in the collection
///
/// See also:
///   - [CollectiveCellProperties] - The concrete implementation
///   - [Collective] - The reactive collection interface
abstract interface class CollectiveProperties<E> implements Properties {

  /// Factory constructor for basic configuration.
  ///
  /// Parameters:
  ///   - bind: Optional parent [Cell] to link with for reactivity
  ///   - container: The [ContainerType] defining collection behavior
  ///   - test: Validation rules of type [TestCollective]
  ///   - map: Optional [MapObject] for element transformations
  factory CollectiveProperties({
    Cell? bind,
    ContainerType container,
    TestCollective test,
    MapObject? mapObject
  }) = CollectiveCellProperties<E, Iterable<E>>;

  /// Creates properties from an existing record.
  ///
  /// Parameters:
  ///   - record: Existing configuration record
  factory CollectiveProperties.fromRecord(Record record) = CollectiveCellProperties<E, Iterable<E>>.fromRecord;

  /// Fully configurable factory for specialized collection types.
  ///
  /// Type Parameters:
  ///   - <I>: The specific iterable type ([List<E>], [Set<E>], etc)
  ///
  /// Parameters:
  ///   - bind: Parent [Cell] for reactivity
  ///   - container: Specific [ContainerType] configuration
  ///   - receptor: Custom [CollectiveReceptor] for signal handling
  ///   - test: Validation rules
  ///   - map: Element transformation mappings
  ///   - synapses: Configuration for cell linking
  static CollectiveProperties<E> create<E, I extends Iterable<E>>({
    Cell? bind,
    ContainerType? container,
    MapObject? mapObject,
    CollectiveReceptor receptor = CollectiveReceptor.unchanged,
    TestCollective test = TestCollective.passed,
    Synapses synapses = Synapses.enabled
  }) => CollectiveCellProperties<E,I>(
      bind: bind,
      container: container,
      receptor: receptor,
      test: test,
      synapses: synapses
    );

  /// The container type defining collection behavior.
  ContainerType get containerType;

  /// The underlying iterable container holding elements.
  ///
  /// This is initialized based on [containerType] and may be:
  /// - List
  /// - Set
  /// - Queue
  /// - Other Iterable types
  get container;

  /// Gets the receptor responsible for handling signals.
  ///
  /// Defaults to [CollectiveReceptor.unchanged] if not specified.
  @override
  CollectiveReceptor get receptor;

  @override
  TestCollective get test;

  /// Creates a delegated properties instance with overrides.
  ///
  /// Used to create modified views without altering original configuration.
  ///
  /// Parameters:
  ///   - bind: Required parent [Cell] for the deputy
  ///   - test: Optional override validation rules
  ///   - map: Optional element transformation overrides
  CollectiveProperties<E> deputy({required Cell bind, covariant TestCollective? test, covariant MapObject? mapObject});

}

class _CollectivePropertiesDeputy<E, I extends Iterable<E>> extends CollectiveCellProperties<E,I> {

  final CollectiveCellProperties<E,I> _properties;

  @override
  final TestCollective test;

  final MapObject? _mapObject;
  final I? _container;
  final Cell _bind;

  _CollectivePropertiesDeputy(CollectiveCellProperties<E,I> properties, {
    required Cell bind,
    TestCollective? test,
    MapObject? mapObject
  }) : _properties = properties,
        _bind = bind,
        test = test != null ? TestCollective(rules: [test, properties.test]) : properties.test,
        _mapObject = mapObject != null ? properties.mapObject != null ? MapObject.fromEntries(mapObject.map.entries, parent: properties.mapObject) : mapObject : mapObject,
        _container = mapObject != null ? properties.container.map<E>((e) => mapObject(e)) as I : null,
        super.fromRecord(properties.record);

  @override
  Cell? get bind => _bind;

  @override
  MapObject? get mapObject => _mapObject ?? _properties.mapObject;

  @override
  I get container => _container ?? _properties.container;

}

/// Concrete implementation of collection properties configuration.
///
/// Manages all aspects of reactive collection behavior including:
/// - Container initialization
/// - Signal propagation
/// - Validation
/// - Element transformations
/// - Cell linking
///
/// Type Parameters:
///   - `<E>`: Type of elements in collection
///   - `<I>`: Specific iterable type ([List<E>], [Set<E>], etc)
class CollectiveCellProperties<E, I extends Iterable<E>> extends Properties implements CollectiveProperties<E> {

  /// Primary constructor for collection configuration.
  ///
  /// Parameters:
  ///   - bind: Parent [Cell] for reactivity chaining
  ///   - container: Defines collection behavior via [ContainerType]
  ///   - receptor: Custom signal handling (default: pass-through)
  ///   - test: Validation rules (default: always pass)
  ///   - synapses: Cell linking behavior (default: enabled)
  ///   - map: Element transformation mappings
  CollectiveCellProperties({
    Cell? bind,
    ContainerType? container,
    CollectiveReceptor receptor = CollectiveReceptor.unchanged,
    TestCollective test = TestCollective.passed,
    MapObject? mapObject,
    Synapses synapses = Synapses.enabled
  }) : super.fromRecord((
        bind: bind,
        container: container ?? ContainerType.create<E,I>(),
        receptor: receptor == CollectiveReceptor.unchanged ? CollectiveReceptor<E,CollectivePost,CollectivePost>() : receptor,
        test: test,
        mapObject: mapObject,
        synapses: synapses == Synapses.enabled ? Synapses() : synapses
  ));

  /// Creates properties from an existing configuration record.
  CollectiveCellProperties.fromRecord(super.record) : super.fromRecord();

  // Initializes the underlying container with optional elements.
  //
  // Handles:
  // 1. Container creation based on [containerType]
  // 2. Element insertion
  // 3. Automatic cell linking for reactive elements
  //
  // Parameters:
  //   - collective: The [Collective] being initialized
  //   - elements: Optional initial elements
  void _initContainer(Collective collective, [Iterable<E>? elements]) {
    if (elements != null) {
      container = containerType.init<E>(elements);
      for (var e in container) {
        if (e is CollectiveCell) {
          e._properties.synapses.link(collective, host: e);
        } else if (e is Cell) {
          Cell(bind: e, synapses: Synapses([collective]));
        }
      }
    } else {
      container = containerType.init<E>();
    }
  }

  /// The configured container type for this collection.
  @override
  ContainerType get containerType {
    try {
      return record.container;
    } catch(_) {
      return ContainerType.create<E,I>();
    }
  }

  /// A collection of objects used to represent in [Collective]
  @override
  late final I container;

  /// Optional element transformation mappings.
  ///
  /// When present, applies transformations to elements during operations.
  MapObject? get mapObject {
    try {
      return record.mapObject;
    } catch(_) {}
    return null;
  }

  /// The signal receptor for this collection.
  ///
  /// Defaults to type-appropriate receptor if not specified.
  @override
  CollectiveReceptor get receptor {
    try {
      return record.receptor;
    } catch(_) {}
    return E == dynamic ? CollectiveReceptor.unchanged : CollectiveReceptor<E,CollectivePost,CollectivePost>();
  }

  /// The validation rules for collection operations.
  ///
  /// Defaults to always passing if not specified.
  @override
  TestCollective get test {
    try {
      return record.test;
    } catch(_) {}
    return TestCollective.passed;
  }

  /// Creates a delegated properties instance with overrides.
  ///
  /// Parameters:
  ///   - bind: Required parent [Cell] for binding
  ///   - test: Optional validation rule overrides
  ///   - map: Optional element transformation overrides
  @override
  CollectiveCellProperties<E,I> deputy({required Cell bind, covariant TestCollective? test, covariant MapObject? mapObject}) {
    return _CollectivePropertiesDeputy<E,I>(this, bind: bind, test: test, mapObject: mapObject);
  }

  /// Creates a copy of these properties with optional modifications.
  ///
  /// Parameters:
  ///   - bind: Optional different parent [Cell]
  ///   - container: Optional different [ContainerType]
  ///   - receptor: Optional different [CollectiveReceptor]
  ///   - test: Optional different [TestCollective] rules
  ///   - map: Optional different [MapObject] transformations
  ///   - synapses: Optional different [Synapses] configuration
  CollectiveCellProperties<E,I> copy({
    Cell? bind,
    ContainerType? container,
    CollectiveReceptor? receptor,
    TestCollective? test,
    MapObject? mapObject,
    Synapses? synapses
  }) {

    try {
      synapses ??= record.synapses;
    } catch(_) {
      synapses = Synapses.enabled;
    }

    return CollectiveCellProperties<E,I>(
      bind: bind ?? this.bind,
      container: container ?? this.containerType,
      receptor: receptor ?? this.receptor,
      test: test ?? this.test,
      mapObject: mapObject ?? this.mapObject,
      synapses: synapses!
    );
  }

}

/// Defines behavior for different collection container types
class ContainerType {

  /// Standard [Iterable] behavior
  static const iterable = ContainerType._(init: _iterableCreate, add: _iterableAdd, remove: _iterableRemove);

  /// Standard [Set] behavior
  static const set = ContainerType._(init: _setCreate, add: _setAdd, remove: _setRemove);

  /// Standard [LinkedHashSet] behavior that uses identity as equality relation.
  static const identitySet = ContainerType._(init: _identitySetCreate, add: _setAdd, remove: _setRemove);

  /// Standard [List] behavior
  static const list = ContainerType._(init: _listCreate, add: _listAdd, remove: _listRemove);

  /// Standard growable [List] behavior
  static const growableTrue = ContainerType._(init: _growableTrueCreate, add: _listAdd, remove: _listRemove);

  /// Standard fixed length [List] behavior
  static const growableFalse = ContainerType._(init: _growableFalseCreate, add: _listAdd, remove: _listRemove);

  /// Standard [Queue] behavior
  static const queue = ContainerType._(init: _queueCreate, add: _queueAdd, remove: _queueRemove);

  /// Standard [List] behavior for [CollectiveValue] containers
  static const value = ContainerType._(init: _growableTrueCreate, add: _valueAdd, remove: _valueRemove);

  /// Creates a container
  final Function init;

  /// Adds an element to the container
  final Function add;

  /// Removes an element from the container
  final Function remove;

  const ContainerType._({required this.init, required this.add, required this.remove});

  /// Creates a ContainerType with custom behavior
  static ContainerType create<E, I extends Iterable<E>>({
    I Function<E>([Iterable<E>? iterable])? init,
    bool Function<E>(Collective<E> collective, I container, E e)? add,
    bool Function<E>(Collective<E> collective, I container, E e)? remove,
    growable = true,
    bool identitySet = false
  }) {

    if (I == Set<E>) {
      return [init,add,remove].every((a) => a == null)
          ? (identitySet ? ContainerType.identitySet : ContainerType.set)
          : ContainerType._(init: init ?? (identitySet ? _identitySetCreate : _setCreate) , add: add ?? _setAdd, remove: remove ?? _setRemove);
    }
    if (I == Iterable<E>) {
      return [init,add,remove].every((a) => a == null)
          ? ContainerType.iterable
          : ContainerType._(init: init ?? _iterableCreate, add: add ?? _iterableAdd, remove: remove ?? _iterableRemove);
    }
    if (I == List<E>) {
      return [init,add,remove].every((a) => a == null)
          ? (growable ? ContainerType.growableTrue : ContainerType.growableFalse)
          : ContainerType._(init: init ?? (growable ? _growableTrueCreate : _growableFalseCreate), add: add ?? _setAdd, remove: remove ?? _setRemove);
    }
    if (I == Queue<E>) {
      return [init,add,remove].every((a) => a == null)
          ? ContainerType.queue
          : ContainerType._(init: init ?? _queueCreate, add: add ?? _queueAdd, remove: remove ?? _queueRemove);
    }

    return ContainerType._(init: init ?? _iterableCreate, add: add ?? _iterableAdd, remove: remove ?? _iterableRemove);
  }

  // Iterable
  static _iterableCreate <E>([Iterable? elements]) {
    return elements != null
        ? Iterable<E>.generate(elements.length, (i) => elements.elementAt(i))
        : Iterable<E>.empty();
  }
  static _iterableAdd <E>(Collective<E> collective, Iterable<E> container, E e) => false;
  static _iterableRemove <E>(Collective<E> collective, Iterable<E> container, E e) => false;

  // Set
  static _setCreate <E>([Iterable<E>? i]) => i != null ? Set<E>.of(i) : <E>{};
  static _identitySetCreate <E>([Iterable<E>? i]) => i != null ? (Set<E>.identity()..addAll(i)) : Set<E>.identity();
  static _setAdd <E>(Collective<E> collective, Set<E> container, E e) => container.add(e);
  static _setRemove <E>(Collective<E> collective, Set<E> container, E e) => container.remove(e);

  // List
  static _listCreate <E>([Iterable<E>? i]) => i != null ? List<E>.of(i) : <E>[];
  static _growableTrueCreate <E>([Iterable<E>? i]) => i != null ? List<E>.from(i, growable: true) : List<E>.empty(growable: true);
  static _growableFalseCreate <E>([Iterable<E>? i]) => i != null ? List<E>.from(i, growable: false) : List<E>.empty(growable: false);
  static _listAdd<E>(Collective <E> collective, List<E> container, E e) {
    container.add(e);
    return true;
  }
  static _listRemove <E>(Collective<E> collective, List<E> container, E e) => container.remove(e);

  // Queue
  static _queueCreate <E>([Iterable<E>? i]) => i != null ? Queue<E>.of(i) : Queue<E>();
  static _queueAdd <E>(Collective<E> base, Queue<E> container, E e) {
    container.add(e);
    return true;
  }
  static _queueRemove <E>(Collective<E> base, Queue<E> container, E e) => container.remove(e);

  // Value
  static _valueAdd <V>(Collective<V> collective, List<V> container, V? e) {

    if (collective is CollectiveValue<V>) {
      if (container.isEmpty || container.last != e) {
        if (e != null) {
          container.insert(0, e);
        } else {
          container.clear();
        }
        return true;
      }
    }
    return false;
  }

  static _valueRemove <V>(Collective<V> collective, List<V> container, V e) {
    return collective is CollectiveValue<V> && container.remove(e);
  }



}
