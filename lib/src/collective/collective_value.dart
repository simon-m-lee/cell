// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../collective.dart';

// ignore_for_file: unused_element
// ignore_for_file: unused_field
// ignore_for_file: prefer_final_fields

/// A base class for [CollectiveValue] that provides common properties and methods.
typedef CollectiveValueBase<V> = _CollectiveValue<V>;

/// `CollectiveValue<V>` is a reactive single-value container that integrates
/// with the cell-based reactivity system. It provides change notifications when
/// its value is modified and supports validation, async operations, and immutable
/// variants.
///
/// Key features:
///
/// - **Reactive**: Automatically notifies listeners when the value changes.
/// - **Validation**: Supports validation rules to ensure the value meets certain criteria.
/// - **Async Operations**: Can perform asynchronous operations on the value.
/// - **Immutable Variants**: Provides immutable versions of the value for safe sharing.
/// - **Customizable**: Allows customization of container behavior and validation rules.
///
///
/// Example: Basic Usage
/// ```dart
/// final counter = CollectiveValue<int>(0);
///
/// // Listen to changes
/// final listener = Cell.listen(
///   bind: counter,
///   listen: (ValueChange<int> change, _) {
///     print('Changed from ${change.before} to ${change.after}');
///   }
/// );
///
/// counter.value = 1; // Output: Changed from 0 to 1
///  ```
///
/// Example: Validation
/// ```dart
/// final age = CollectiveValue<int>(
///   null,
///   test: TestCollective.create(
///     elementDisallow: (age) => age != null && (age < 0 || age > 120)
///   )
/// );
///
/// age.value = 25;  // Allowed
/// age.value = -5;  // Blocked by validation
///  ```
///
/// Example: Async Operations
/// ```dart
/// final config = CollectiveValue<String>('default');
///
/// void main() async {
///   await config.async.setValue('new config');
///   print(config.value); // 'new config'
/// }
///  ```
///
/// Example: Value Change Tracking
/// ```dart
/// // Track value changes
/// final value = CollectiveValue<int>(0);
///
/// value.setValue(1); // Triggers ValueChange with before=0, after=1
///
/// // Listen for changes
/// final listener = Collective.listen<CollectivePost>(
///   bind: value,
///   listen: (post, _) {
///     final changes = post.body?[Collective.elementUpdated] as Iterable<ElementValueChange>;
///     changes.forEach((change) {
///       print('Changed from ${change.before} to ${change.after}');
///     });
///   }
/// );
///  ```
///
/// Example: Immutable Variant
/// ```dart
/// final immutableValue = CollectiveValue.unmodifiable(counter);
///
/// //Attempting to modify immutableValue will throw an error
/// immutableValue.value = 5; // Throws error
/// print(immutableValue.value); // 0
///  ```
///
/// Example: Complete Example
///
/// ```dart
/// import 'package:collective/collective.dart';
///
/// void main() async {
///   // Create validated value
///   final temperature = CollectiveValue<double>(
///     null,
///     test: TestCollective.create(
///       elementDisallow: (temp) => temp != null && (temp < -50 || temp > 100)
///   );
///
///   // Logger cell
///   final logger = Cell.listen(
///     bind: temperature,
///     listen: (ValueChange<double> change, _) {
///       print('Temp changed: ${change.before}°C → ${change.after}°C');
///     }
///   );
///
///   // Simulate sensor updates
///   await temperature.async.setValue(23.5);
///   await Future.delayed(Duration(seconds: 1));
///   await temperature.async.setValue(24.1);
///
///   // Try invalid value
///   temperature.value = -100; // ❌ Blocked by validation
/// }
///  ```
/// /// See also:
/// - [CollectiveValueDeputy] - For reduced operations
/// - [UnmodifiableCollectiveValue] - Immutable version
/// - [TestCollective] - For validation rules
abstract interface class CollectiveValue<V> implements CollectiveCell<V> {

  @override
  CollectiveValueProperties<V> get _properties;

  /// Creates a reactive single value container
  ///
  /// @param value: Initial value
  /// @param bind: Cell to bind to
  /// @param test: Validation rules
  ///
  /// // Example:
  ///   final currentUser = `CollectiveValue<User?>`(
  ///       User(name: 'Alice'),
  ///       test: TestCollective.create(
  ///           elementDisallow: (user, _) => user == null
  ///       )
  ///   );
  ///
  /// // Update reactively
  /// currentUser.value = User(name: 'Bob');
  /// ```
  factory CollectiveValue(V? value, {
    Cell? bind,
    TestCollective test,
    SignalTransform? transform,
  }) = _CollectiveValue<V>;

  /// Creates an empty CollectiveValue without initial value.
  ///
  /// Parameters:
  /// - [bind]: Cell to bind to for reactive updates
  /// - [test]: Validation rules for the value
  factory CollectiveValue.empty({
    Cell? bind,
    TestCollective test,
  }) = _CollectiveValue<V>.empty;

  /// Creates from properties with optional initial value.
  ///
  /// Parameters:
  /// - [properties]: Configuration properties
  /// - [value]: Optional initial value
  factory CollectiveValue.fromProperties(CollectiveValueProperties<V> properties, {V? value}) = _CollectiveValue<V>.fromProperties;

  /// Creates an unmodifiable version of this CollectiveValue.
  ///
  /// Parameters:
  /// - [bind]: The CollectiveValue to make unmodifiable
  /// - [unmodifiableElement]: If true and value is a Cell, makes it unmodifiable
  factory CollectiveValue.unmodifiable(CollectiveValue<V> bind, {bool unmodifiableElement}) = UnmodifiableCollectiveValue<V>.bind;

  /// Factory constructor for full configuration.
  ///
  /// Parameters:
  /// - [value]: Initial value
  /// - [bind]: Cell to bind to
  /// - [container]: Container type (defaults to [ContainerType.value])
  /// - [receptor]: Signal handling configuration
  /// - [test]: Validation rules
  /// - [map]: Value transformations
  /// - [synapses]: Connection configuration
  /// - [setter]: Custom value setter function
  /// - [getter]: Custom value getter function
  static CollectiveValue<V> create<V, I extends Iterable<V>>({
    V? value,
    Cell? bind,
    ContainerType container = ContainerType.growableFalse,
    CollectiveReceptor receptor = CollectiveReceptor.unchanged,
    TestCollective test = TestCollective.passed,
    MapObject? mapObject,
    Synapses synapses = Synapses.enabled,
    bool Function(CollectiveValue<V> value, I container, V? v)? setter,
    V? Function(CollectiveValue<V> value, I container)? getter,
  }) {
    Record record;
    if (test == TestCollective.passed && mapObject == null && synapses == Synapses.enabled) {
      if (bind != null || container != ContainerType.growableFalse || receptor != CollectiveReceptor.unchanged) {
        record = (
          bind: bind,
          container: container != ContainerType.growableFalse ? container : ContainerType.create<V,I>(),
          receptor: receptor
        );
      } else {
        record = ();
      }
    } else {
        record = (bind: bind,
        container: container,
        receptor: receptor == CollectiveReceptor.unchanged ? CollectiveReceptor<V,CollectivePost,CollectivePost>() : receptor,
        test: test,
        mapObject: mapObject,
        synapses: synapses, setter: setter, getter: getter
      );
    }
    return _CollectiveValue<V>.fromProperties(CollectiveValueProperties<V>.fromRecord(record), value: value);
  }

  /// The value of this CollectiveValue
  V? get value;

  /// Sets the value of this CollectiveValue
  set value(V? value);

  /// Sets the value of this CollectiveValue and returns true if successful.
  ///
  /// [Sync] CollectiveValue returns bool, 'true' if value is set, 'false' if not
  /// [Async] CollectiveValue returns `Future<bool>`, 'true' if value is set, 'false' if not
  set(V? value);

  _setValue(V? v, {bool notification = true, Cell? deputy});

  /// Creates an deputy for this CollectiveValue.
  ///
  /// Parameters:
  /// - [test]: Additional validation rules
  /// - [mapObject]: Value transformations to apply
  @override
  CollectiveValue<V> deputy({covariant TestCollective? test, covariant MapObject? mapObject});

  /// Returns an unmodifiable version of this value.
  @override
  CollectiveValue<V> get unmodifiable;

  /// Creates an async variant for [modifiable] operations
  @override
  CollectiveValueAsync<V> get async;

  /// Comparison operators for numeric values
  bool operator <=(Object other);

  /// Comparison operators for numeric values
  bool operator >(Object other);

  /// Comparison operators for numeric values
  bool operator <(Object other);

}

class _CollectiveValue<V> extends CollectiveCell<V> with IterableMixin<V>, OpenValueMixin<V> implements CollectiveValue<V>, Sync {

  _CollectiveValue(V? value, {
    Cell? bind,
    TestCollective test = TestCollective.passed,
    SignalTransform? transform,
  }) : this.fromProperties(CollectiveValueProperties<V>(
    bind: bind,
    test: test,
    receptor: transform != null ? CollectiveReceptor<V,Signal,Signal>(transform: transform) : CollectiveReceptor.unchanged,
  ), value: value);

  _CollectiveValue.empty({
    Cell? bind,
    TestCollective test = TestCollective.passed,
  }) : this.fromProperties(CollectiveValueProperties<V>(
    bind: bind,
    test: test,
  ));

  _CollectiveValue.fromProperties(CollectiveValueProperties<V> super.properties, {V? value})
      : super(elements: value != null ? [value] : null);

  @override
  CollectiveValue<V> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return CollectiveValueDeputy<V>._(this, test: test, mapObject: mapObject);
  }

  @override
  late final CollectiveValue<V> unmodifiable = CollectiveValue<V>.unmodifiable(this);

  /// Creates an async variant for [modifiable] operations
  @override
  CollectiveValueAsync<V> get async => CollectiveValueAsync<V>(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is CollectiveValue<V>) {
      if (other is Unmodifiable) {
        if (other._properties.bind != null && identical(this, other._properties.bind)) {
          return identical(unmodifiable, this);
        }
      }
    }
    if (other is V && value != null ) {
      return other == value;
    }
    return false;
  }

  @override
  int get hashCode => value?.hashCode ?? _properties.container.hashCode;

}

/// A helper class that provides reduced functionality for [CollectiveValue] objects.
///
/// This class extends [CollectiveValue] while implementing the [Deputy] mixin,
/// allowing it to:
/// - Wrap an existing [CollectiveValue] instance
/// - Apply additional validation rules via [TestCollective]
/// - Transform values using [MapObject]
/// - Maintain the same reactive behavior as the original [CollectiveValue]
///
/// See also:
/// - [CollectiveValue] - The base class this deputy wraps
/// - [Deputy] - The mixin providing core deputy functionality
class CollectiveValueDeputy<V> extends CollectiveValueBase<V> with Deputy<CollectiveValue<V>> {

  CollectiveValueDeputy._(CollectiveValue<V> bind, {TestCollective? test, MapObject? mapObject})
      : super.fromProperties(bind._properties.deputy(bind: bind, test: test, mapObject: mapObject));

  @override
  CollectiveValue<V> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return CollectiveValueDeputy<V>._(_properties.bind as CollectiveValue<V>, test: test, mapObject: mapObject);
  }
}

/// An immutable version of [CollectiveValue] that prevents modifications to the value.
///
/// This class wraps a [CollectiveValue] and:
/// - Disallows all value modification operations
/// - Maintains reactive relationships with other cells
/// - Optionally makes contained elements unmodifiable if they're [Cell] objects
///
/// ## Usage Examples:
///
/// ```dart
/// // Create from existing CollectiveValue
/// final value = CollectiveValue(42);
/// final unmodifiable = UnmodifiableCollectiveValue.bind(value);
///
/// // Create directly with initial value
/// final direct = UnmodifiableCollectiveValue(42);
/// ```
///
/// See also:
/// - [CollectiveValue] - The modifiable version of this class
/// - [Unmodifiable] - The marker interface for unmodifiable objects
class UnmodifiableCollectiveValue<V> extends UnmodifiableCollectiveCell<V> with IterableMixin<V>, OpenValueMixin<V> implements CollectiveValue<V> {

  /// Creates an unmodifiable value with the specified initial value.
  ///
  /// Parameters:
  /// - [value]: The initial immutable value
  /// - [unmodifiableElement]: If true and value is a [Cell], makes it unmodifiable
  /// - [properties]: Configuration properties for the collective
  UnmodifiableCollectiveValue(V value, {bool unmodifiableElement = true, CollectiveValueProperties<V>? properties})
      : super(properties ?? CollectiveValueProperties<V>(), unmodifiableElement: unmodifiableElement, elements: [value]);

  /// Creates an unmodifiable wrapper around an existing [CollectiveValue].
  ///
  /// Parameters:
  /// - [bind]: The value to make unmodifiable
  /// - [unmodifiableElement]: If true and value contains [Cell] objects, makes them unmodifiable
  UnmodifiableCollectiveValue.bind(CollectiveValue<V> bind, {bool unmodifiableElement = true})
      : this.fromProperties((bind._properties as _CollectiveValueProperties).copy(bind: bind) as CollectiveValueProperties<V>, unmodifiableElement: unmodifiableElement,
      value: bind.value
  );

  /// Creates from properties with optional initial value.
  ///
  /// Parameters:
  /// - [properties]: Configuration properties
  /// - [unmodifiableElement]: If true and value contains [Cell] objects, makes them unmodifiable
  /// - [value]: Optional initial value
  UnmodifiableCollectiveValue.fromProperties(CollectiveValueProperties<V> super.properties, {super.unmodifiableElement, V? value})
      : super(elements: value != null ? [value] : null);

  /// Factory constructor for creating unmodifiable values with full configuration.
  ///
  /// Parameters:
  /// - [value]: Initial value
  /// - [unmodifiableElement]: If true and value contains [Cell] objects, makes them unmodifiable
  /// - [bind]: Cell to bind to
  /// - [container]: Container type
  /// - [receptor]: Signal receptor
  /// - [test]: Validation rules
  /// - [map]: Value transformations
  /// - [synapses]: Connection configuration
  /// - [setter]: Custom setter function
  /// - [getter]: Custom getter function
  static CollectiveValue<V> create<V, I extends Iterable<V>>({
    V? value,
    bool unmodifiableElement = true,
    Cell? bind,
    ContainerType? container,
    CollectiveReceptor receptor = CollectiveReceptor.unchanged,
    TestCollective test = TestCollective.passed,
    MapObject? mapObject,
    Synapses synapses = Synapses.enabled,
    bool Function(CollectiveValue<V> value, I container, V? v)? setter,
    V? Function(CollectiveValue<V> value, I container)? getter,
  }) {
    return UnmodifiableCollectiveValue<V>.fromProperties(_CollectiveValueProperties<V,I>(
        bind: bind,
        container: container ?? ContainerType.value,
        test: test,
        receptor: receptor,
        synapses: synapses,
        setter: setter,
        getter: getter
    ), unmodifiableElement: unmodifiableElement, value: value);
  }

  /// Creates a new deputy for this unmodifiable value.
  ///
  /// Note: While the deputy can be created, modification operations will still fail.
  ///
  /// Parameters:
  /// - [test]: Additional validation rules
  /// - [map]: Value transformations
  @override
  CollectiveValue<V> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return UnmodifiableCollectiveValue.fromProperties(
        _properties.deputy(bind: this, test: test, mapObject: mapObject),
        unmodifiableElement: _unmodifiableElement
    );
  }

  @override
  CollectiveValue<V> get unmodifiable => this;

  /// Creates an async variant for [modifiable] operations
  @override
  late final CollectiveValueAsync<V> async = UnmodifiableCollectiveValueAsync<V>(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is CollectiveValue<V>) {
      if (other is! Unmodifiable) {
        if (_properties.bind != null && identical(_properties.bind, other)) {
          return identical(other.unmodifiable, this);
        }
      }
      return value != null && other.value == value;
    }
    if (other is V && value != null ) {
      return other == value;
    }
    return false;
  }

  @override
  int get hashCode => _properties.container.hashCode;

}

/// Configuration properties for a [CollectiveValue] instance.
///
/// This class encapsulates all configurable aspects of a [CollectiveValue],
/// including:
/// - Value storage and retrieval behavior
/// - Validation rules
/// - Reactive bindings
/// - Value transformation pipelines
abstract interface class CollectiveValueProperties<V> implements CollectiveProperties<V> {

  /// Creates basic properties for a [CollectiveValue].
  ///
  /// Parameters:
  /// - [bind]: Cell to bind to for reactive updates
  /// - [test]: Validation rules for the value
  factory CollectiveValueProperties({
    Cell? bind,
    TestCollective test,
    CollectiveReceptor receptor,
  }) = _CollectiveValueProperties<V,List<V>>;

  /// Creates properties from a record of values.
  ///
  /// Allows compatibility with various property storage formats.
  factory CollectiveValueProperties.fromRecord(record) => _CollectiveValueProperties<V,List<V>>.fromRecord(record);

  /// Factory constructor for full property configuration.
  ///
  /// Parameters:
  /// - [bind]: Reactive cell to bind to
  /// - [container]: How to store the value (defaults to [ContainerType.value])
  /// - [receptor]: Custom signal handling logic
  /// - [test]: Validation rules
  /// - [mapObject]: Value transformation pipeline
  /// - [synapses]: Connection management configuration
  /// - [setter]: Custom value storage logic
  /// - [getter]: Custom value retrieval logic
  static CollectiveValueProperties<V> create<V, I extends Iterable<V>>({
    Cell? bind,
    ContainerType? container,
    CollectiveReceptor? receptor,
    TestCollective test = TestCollective.passed,
    Synapses synapses = Synapses.enabled,
    MapObject? mapObject,
    bool Function(CollectiveValue<V> value, I container, V? v)? setter,
    V? Function(CollectiveValue<V> value, I container)? getter,
  }) {
    Record record;
    if (test == TestCollective.passed && mapObject == null && synapses == Synapses.enabled && setter == null && getter == null) {
      if (bind != null || container != ContainerType.growableFalse || receptor != CollectiveReceptor.unchanged) {
        record = (
        bind: bind,
        container: container != ContainerType.growableFalse ? container : ContainerType.create<V,I>(),
        receptor: receptor
        );
      } else {
        record = ();
      }
    } else {
      record = (bind: bind,
      container: container ?? ContainerType.create<V,I>(),
      receptor: receptor == CollectiveReceptor.unchanged ? CollectiveReceptor<V,CollectivePost,CollectivePost>() : receptor,
      test: test,
      mapObject: mapObject,
      synapses: synapses, setter: setter, getter: getter
      );
    }
    return _CollectiveValueProperties<V,I>.fromRecord(record);
  }

  /// Custom logic for storing values.
  ///
  /// Signature:
  /// `bool Function(CollectiveValue<V> value, I container, V? v)`
  ///
  /// Default behavior:
  /// - Clears container when setting null
  /// - Stores non-null values at container start
  Function get setter;

  /// Custom logic for retrieving values.
  ///
  /// Signature:
  /// `V? Function(CollectiveValue<V> value, I container)`
  ///
  /// Default behavior:
  /// - Returns last element in container or null if empty
  Function get getter;

  /// Creates an deputy version of these properties.
  ///
  /// Parameters:
  /// - [bind]: Cell to associate with the deputy
  /// - [test]: Additional validation rules
  /// - [mapObject]: Additional transformations to apply
  ///
  /// Returns new properties combining original and deputy configurations
  @override
  CollectiveValueProperties<V> deputy({required Cell bind, covariant TestCollective? test, covariant MapObject? mapObject});

}

class _CollectiveValuePropertiesDeputy<V, I extends Iterable<V>> extends _CollectiveValueProperties<V,I> {

  final CollectiveCellProperties<V,I> _properties;

  @override
  final TestCollective test;

  final MapObject? _mapObject;
  final I? _container;

  _CollectiveValuePropertiesDeputy(CollectiveCellProperties<V,I> properties, {
    required Cell bind,
    TestCollective? test,
    MapObject? mapObject
  }) : _properties = properties,
        test = test != null ? TestCollective(rules: [test, properties.test]) : properties.test,
        _mapObject = mapObject != null ? properties.mapObject != null ? MapObject.fromEntries(mapObject.map.entries, parent: properties.mapObject) : mapObject : mapObject,
        _container = mapObject != null ? properties.container.map<V>((e) => mapObject(e)) as I : null,
        super.fromRecord(properties.record);

  @override
  MapObject? get mapObject => _mapObject ?? _properties.mapObject;

  @override
  I get container => _container ?? _properties.container;

}

class _CollectiveValueProperties<V, I extends Iterable<V>> extends CollectiveCellProperties<V,I> implements CollectiveValueProperties<V> {

  _CollectiveValueProperties({
    Cell? bind,
    ContainerType container = ContainerType.value,
    CollectiveReceptor receptor = CollectiveReceptor.unchanged,
    TestCollective test = TestCollective.passed,
    Synapses synapses = Synapses.enabled,
    MapObject? mapObject,
    Function? setter,
    Function? getter,
  }) : this.fromRecord(
      // container == ContainerType.value &&
      //     receptor == CollectiveReceptor.unchanged &&
      //     test == TestCollective.passed && synapses == Linkable.enabled &&
      //     map == null && setter == null && getter == null
      //     ? bind != null ? ((bind: bind, container: ContainerType.value)) : (container: ContainerType.value) :
      (
      bind: bind,
      container: container,
      receptor: receptor == CollectiveReceptor.unchanged ? CollectiveReceptor<V,CollectivePost,CollectivePost>() : receptor,
      test: test,
      synapses: synapses == Synapses.enabled ? Synapses() : synapses,
      setter: setter,
      getter: getter
      ));

  _CollectiveValueProperties.fromRecord(super.record) : super.fromRecord();

  @override
  Function get setter {
    try {
      return record.setter ?? _setter;
    } catch(_) {}
    return _setter;
  }

  @override
  Function get getter {
    try {
      return record.getter ?? _getter;
    } catch(_) {}
    return _getter;
  }

  static bool _setter(CollectiveValue collective, List container, Object? value) {
    try {
      if (container.isEmpty || container.last != value) {
        if (value != null) {
          container..clear()..insert(0, value);
        } else {
          container.clear();
        }
        return true;
      }
    } catch (_) {}

    return false;
  }

  static Object? _getter(CollectiveValue collective, Iterable container) {
    return container.isNotEmpty ? container.last : null;
  }

  @override
  _CollectiveValuePropertiesDeputy<V,I> deputy({required Cell bind, covariant TestCollective? test, covariant MapObject? mapObject}) {
    return _CollectiveValuePropertiesDeputy<V,I>(this, bind: bind, test: test, mapObject: mapObject);
  }

  @override
  _CollectiveValueProperties<V,I> copy({
    Cell? bind,
    ContainerType? container,
    CollectiveReceptor? receptor,
    TestCollective? test,
    MapObject? mapObject,
    Synapses? synapses,
    Function? setter,
    Function? getter,
  }) {

    try {
      synapses ??= record.synapses;
    } catch(_) {
      synapses = Synapses.enabled;
    }

    return _CollectiveValueProperties<V,I>(
        bind: bind ?? this.bind,
        container: container ?? containerType,
        receptor: receptor ?? this.receptor,
        test: test ?? this.test,
        mapObject: mapObject ?? this.mapObject,
        synapses: synapses!,
        setter: setter ?? this.setter,
        getter: getter ?? this.getter,
    );
  }

}

/// A mixin that provides additional functionality for [CollectiveValue] objects.
mixin OpenValueMixin<V> on CollectiveCell<V> implements Iterable<V>, CollectiveValue<V> {

  @override
  CollectiveValueProperties<V> get _properties => super._properties as CollectiveValueProperties<V>;

  /// Creates an deputy for this CollectiveValue.
  ///
  /// Parameters:
  /// - [test]: Additional validation rules
  /// - [mapObject]: Value transformations to apply
  @override
  CollectiveValue<V> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return CollectiveValueDeputy<V>._(this, test: test, mapObject: mapObject);
  }

  @override
  Iterable<Function> get modifiable => <Function>{set, ...super.modifiable};

  /// The value of this CollectiveValue
  @override
  V? get value => _properties.getter(this, _properties.container);

  /// Sets the value of this CollectiveValue
  @override
  set value(V? value) {
    if (this is! Unmodifiable) {
      set(value);
    }
  }

  /// Sets the value of this CollectiveValue and returns true if successful.
  @override
  bool set(V? value) {
    if (this is! Unmodifiable) {
      return _setValue(value).isNotEmpty;
    }
    return false;
  }

  Map<CollectiveEvent, Iterable<ElementValueChange>> _setValue(V? v, {bool notification = true, Cell? deputy}) {
    final map = <CollectiveEvent, Iterable<ElementValueChange<CollectiveValue<V>, V?>>>{};

    if (test.action(set, this, arguments: (positionalArguments: [v], namedArguments: null))) {
      if (test.element(v, this, action: set)) {
        final before = value;
        if (_properties.setter(this, _properties.container, v)) {

          if (before is CollectiveCell) {
            before._properties.synapses.unlink(this);
          }
          if (v is CollectiveCell) {
            v._properties.synapses.link(v, host: this);
          }

          map[Collective.elementUpdated] = {ElementValueChange<CollectiveValue<V>, V?>(element: this as CollectiveValue<V>, after: v, before: before)};
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

          if (function == set) {
            return Function.apply(_setValue, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          return;
        }} catch (_) {}
    }
    return Function.apply(function, positionalArguments, namedArguments);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is V) {
      return other == value;
    }
    if (other is CollectiveValue<V>) {
      return other.value == value;
    }
    return false;
  }

  /// Comparison operators for numeric values
  @override
  bool operator <=(Object other) {

    bool compare(V v) {
      if (v is num) {
        return (value as num) <= v;
      }
      return false;
    }

    if (value != null) {
      if (other is CollectiveValue<V> && other.value != null) {
        return compare(other.value as V);
      } else if (V == dynamic || other is V) {
        return compare(other as V);
      }
    }

    return false;
  }

  /// Comparison operators for numeric values
  @override
  bool operator >(Object other) {

    bool compare(V v) {
      if (v is num) {
        return (value as num) > v;
      }
      return false;
    }

    if (value != null) {
      if (other is CollectiveValue<V> && other.value != null) {
        return compare(other.value as V);
      } else if (V == dynamic || other is V) {
        return compare(other as V);
      }
    }

    return false;
  }

  /// Comparison operators for numeric values
  @override
  bool operator <(Object other) {

    bool compare(V v) {
      if (v is num) {
        return (value as num) < v;
      }
      return false;
    }

    if (value != null) {
      if (other is CollectiveValue<V> && other.value != null) {
        return compare(other.value as V);
      } else if (V == dynamic || other is V) {
        return compare(other as V);
      }
    }

    return false;
  }

  @override
  int get hashCode => identityHashCode(this);

  @override
  String toString() => value.toString();

}

/// An asynchronous wrapper for [CollectiveValue] operations that provides Future-based APIs.
///
/// This class enables non-blocking access to a reactive value container while maintaining
/// all the reactive properties of the underlying [CollectiveValue]. All mutating operations
/// return [Future] objects, making them safe to use in asynchronous contexts.
///
/// ## Usage Example
/// ```dart
/// final temperature = CollectiveValue<double>(72.5);
/// final asyncTemp = temperature.async; // Get async wrapper
///
/// // Asynchronous value update
/// await asyncTemp.setValue(75.0);
/// ```
///
/// ## Key Features
/// - Thread-safe value updates via Futures
/// - Maintains reactive binding to parent cells
/// - Preserves all validation rules from the source [CollectiveValue]
/// - Seamless integration with async/await patterns
class CollectiveValueAsync<V> extends CollectiveAsync<V,CollectiveValue<V>> implements CollectiveValue<V> {

  /// Creates an async wrapper around an existing [CollectiveValue].
  ///
  /// Typically accessed via the [CollectiveValue.async] getter rather than
  /// constructed directly.
  ///
  /// ```dart
  /// final asyncValue = myValue.async; // Preferred access
  /// ```
  const CollectiveValueAsync(super.collective);

  /// Asynchronously sets the contained value with reactive propagation.
  ///
  /// This operation:
  /// 1. Validates the new value against all test rules
  /// 2. Updates the value if validation passes
  /// 3. Propagates changes to all linked cells
  /// 4. Returns a Future that completes when all notifications are processed
  ///
  /// [value]: The new value to set
  ///
  /// Returns a `Future<bool>` that completes with:
  /// - `true` if the value was successfully updated
  /// - `false` if validation failed or the collective is unmodifiable
  ///
  /// Example:
  /// ```dart
  /// final success = await asyncTemp.setValue(75.0);
  /// if (success) print('Update succeeded');
  /// ```
  @override
  Future<bool> set(V? value) async {
    return Future<bool>(() {
      if (this is! Unmodifiable) {
        return _collective._setValue(value).isNotEmpty;
      }
      return false;
    });
  }

  /// Gets an unmodifiable view of this value.
  @override
  CollectiveValue<V> get unmodifiable => _collective.unmodifiable;

  /// Creates a [Async] [CollectiveValue] for async [modifiable] operations
  @override
  CollectiveValueAsync<V> get async => this;

  /// Creates a delegated view with modified behavior.
  ///
  /// Parameters:
  ///   - test: Optional override validation rules
  ///   - map: Optional element transformations
  @override
  CollectiveValue<V> deputy({covariant TestCollective? test, covariant MapObject? mapObject}) {
    return _collective.deputy(test: test, mapObject: mapObject);
  }

  @override
  TestCollective get test => _collective.test;

  @override
  CollectiveValueProperties<V> get _properties => _collective._properties;

  @override
  V? get value => _collective.value;

  @override
  Future<Map<CollectiveEvent, Iterable<ElementValueChange>>>_setValue(V? v, {bool notification = true, Cell? deputy}) {
    return Future<Map<CollectiveEvent, Iterable<ElementValueChange>>>(
      () => _collective._setValue(v, notification: notification, deputy: deputy)
    );
  }

  @override
  bool operator ==(Object other) {
    return _collective == other;
  }

  /// Comparison operators for numeric values
  @override
  bool operator <=(Object other) {
    return _collective <= other;
  }

  /// Comparison operators for numeric values
  @override
  bool operator >(Object other) {
    return _collective > other;
  }

  /// Comparison operators for numeric values
  @override
  bool operator <(Object other) {
    return _collective < other;
  }

  @override
  int get hashCode => identityHashCode(this);

  @override
  String toString() => value.toString();

  @override
  set value(V? value) {
    _collective.value = value;
  }

}

/// Specialized unmodifiable version of [CollectiveValueAsync].
///
/// All mutating operations will complete with `false` or throw [UnsupportedError].
/// This preserves the immutability guarantee while maintaining the async interface.
class UnmodifiableCollectiveValueAsync<V> extends CollectiveValueAsync<V> implements Unmodifiable {

  @override
  Iterable<Function> get modifiable => const <Function>{};

  /// Creates an async wrapper around an unmodifiable [CollectiveValue].
  const UnmodifiableCollectiveValueAsync(super.collective) : super();

  @override
  Future<bool> set(V? value) {
    return Future<bool>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  @override
  CollectiveValue<V> get unmodifiable => this;

}