// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../cell.dart';

/// Base class for all [Cell] types.
typedef CellBase = CellSync;

/// Base class for all [OpenCell] types.
typedef OpenCellBase = OpenCellSync;

/// 'cell:core' is a reactive programming framework centered around the [Cell] class and its extensions,
/// particularly the [Collective] family of classes that implement reactive collections
/// [CollectiveSet], [CollectiveList], [CollectiveQueue] and [CollectiveValue].
/// This framework provides a comprehensive reactive programming solution for Dart, with
/// particular strength in managing complex state and data flow in applications.
///
/// ## Key features include:
///
/// - **Reactive Programming Model**: Automatic propagation of changes through a network of cells
///
/// - **Validation System**: Configurable rules for what operations are allowed
///
/// - **Flexible Signal Processing**: Customizable signal transformation and propagation
///
/// - **Collection Support**: Reactive versions of common collection types (Set, List, Queue, Value)
///
/// - **Modifiable/Unmodifiable Views**: Both mutable and immutable variants of all containers
///
/// - **Asynchronous Support**: Async interfaces for modifiable operations
///
/// ## Core components that work together:
///
/// - [Cell]: The fundamental reactive unit
/// - [Receptor]: Handles signal processing
/// - [Synapses]: Manages inter-cell communication
/// - [Properties]: Contains cell configuration
/// - [TestRule]/[TestObject]: Provides validation
/// - [Signal]: Carries data between cells
/// - [Deputy]: Enables behavior modification
///
/// Cells can be:
/// - Bound to other cells to form relationships
/// - Linked to create observable patterns
/// - Modified through receptors and test objects
///
/// Example:
/// ```dart
///
/// // Create a basic cell
/// final cell = Cell();
/// final boundCell = Cell(bind: cell);
///
/// // Create a listening cell
/// final listener = Cell.listen<String>(
///   bind: baseCell,
///   listen: (signal, _) => print('Received: ${signal.body}'),
/// );
///
/// // Create a transforming cell
/// final transformer = Cell.signaling<String, int>(
///   bind: baseCell,
///   map: (signal, _) => signal.body?.length,
/// );
/// ```
///
/// Example: with [Collective] bounded
/// ```dart
/// // Create source cell
/// final source = CollectiveValue<int>(5);
///
/// // Create transformed cell
/// final squared = Cell.signaling<int,int>(
///  bind: source,
///   transform: (signal, _) => Signal(signal.body * signal.body)
/// );
///
/// // Create logger
/// final logger = Cell.listen<int>(
///   bind: squared,
///   listen: (signal, _) => print('Value squared: ${signal.body}')
/// );
///
/// // Update source - automatically propagates
/// source.value = 10; // Logs "Value squared: 100"
/// ```
abstract interface class Cell {

  Properties get _properties;

  /// Creates a new [Cell] with optional binding and configuration
  ///
  /// Parameters:
  /// - [bind]: Optional [Cell] to bind to (creates observing/chaining)
  /// - [receptor]: How this cell processes incoming signals (default: Receptor.unchanged)
  /// - [test]: TestObject that validates operations (default: TestObject.passed)
  /// - [synapses]: Whether this cell can be linked to others (default: Linkable.enabled)
  factory Cell({
    Cell? bind,
    Receptor receptor,
    TestObject test,
    Synapses synapses
  }) = CellSync;

  /// Constructs a [Cell] from predefined properties.
  ///
  /// Parameters:
  /// - [properties]: The properties to use for this cell
  ///
  /// Returns a new [CellSync] instance
  ///
  /// Example:
  /// ```dart
  /// final properties = Properties(
  ///  receptor: Receptor.unchanged,
  ///  bind: parentCell,
  ///  test: TestObject.passed,
  ///  synapses: Synapses.enabled
  ///  );
  ///
  /// final cell = Cell.fromProperties(properties);
  /// ```
  factory Cell.fromProperties(Properties properties) = CellSync.fromProperties;

  /// Creates a listening cell that executes a callback when signals are received
  ///
  /// Parameters:
  /// - [bind]: The cell to bind to.
  /// - [listen]: Callback function when signal of type S is received
  /// - [user]: Optional user-defined data passed to callback
  /// - [synapses]: Whether this cell can be linked to others. (default: Linkable.enabled)
  ///
  /// Returns a new Cell configured for listening
  ///
  /// Example: Listening to a value change
  /// ```dart
  /// // Create a value cell
  /// final value = CollectiveValue<int>(0);
  ///
  /// // Create a cell that listens for value changes
  /// final listener = Cell.listen<Signal<String>>(
  ///   bind: value,
  ///   listen: (signal, user) {
  ///     print('Received: ${signal.body}');
  ///   },
  /// );
  ///
  /// // Trigger a signal in the value cell
  /// value.set(3);
  ///  ```
  static Cell listen<S extends Signal>({
    required Cell bind,
    required void Function(S signal, dynamic user) listen,
    dynamic user,
    Synapses synapses = Synapses.disabled
  }) {
    return CellSync(
      bind: bind,
      receptor: Receptor<Cell,S,Signal>(
          transform: ({required Cell cell, required S signal, dynamic user}) {
            listen(signal, user);
            return signal;
          }, user: user
      ),
      test: TestObject.passed,
      synapses: synapses == Synapses.enabled ? Synapses<S,Cell>() : synapses
    );
  }

  /// Creates a signaling [Cell] that transforms incoming and outgoing signals,
  /// or stop outgoing signals.
  ///
  /// Parameters:
  /// - [bind]: Required [Cell] to bind to
  /// - [transform]: Transformation function for signals
  /// - [user]: Optional user data
  /// - [synapses]: Whether this cell can be linked (default: Linkable.enabled)
  ///
  /// Returns a new Cell configured for signal transformation
  ///
  /// Example: Transforming an [int] signal to [String] signal
  /// ```dart
  /// // Create a value cell
  /// final value = CollectiveValue<int>(0);
  ///
  /// // Create a processor cell
  /// final processor = Cell.signaling<Signal<int>, Signal<String>>(
  ///   bind: value,
  ///   transform: (signal, _) {
  ///
  ///     // Check if the signal is less than 5
  ///     if (signal.body < 5) {
  ///
  ///       // If so, stop the signal
  ///       return null;
  ///     }
  ///
  ///     // Transform the signal to a string
  ///     return Signal<String>('Value is ${signal.body}');
  ///   },
  /// );
  ///
  /// value.set(2); // This will stop the signal
  /// value.set(6); // This will transform the signal to "6" as String
  /// ```
  static Cell signaling<I extends Signal, O extends Signal>({
    required Cell bind,
    required O? Function(I signal, dynamic user) transform,
    dynamic user,
    Synapses synapses = Synapses.enabled
  }) {
    return CellSync(
      bind: bind,
      receptor: Receptor<Cell,I,O>(
          transform: ({required Cell cell, required I signal, dynamic user}) => transform(signal, user),
          user: user
      ),
      synapses: synapses == Synapses.enabled ? Synapses<O,Cell>() : synapses
    );
  }

  /// A factory constructor that creates an [Deputy] cell from an existing [Cell] instance with reduced permissions.
  ///
  /// Parameters:
  /// - [bind]: The cell to bind to
  /// - [test]: Optional test object for validation
  /// - [mapObject]: Optional map object for transformation
  /// (Note: Either [test] or [mapObject] must be provided to create a deputy cell for
  /// specific functions by providing validation rules or apply rules to individual objects)
  ///
  /// Returns a new [CellDeputy] instance
  factory Cell.deputy({required Cell bind, TestObject? test, MapObject? mapObject}) = CellDeputy;

  /// Creates an open [Cell] that supports linking and receptor transformations.
  static OpenCell open<C extends Cell, L extends Cell, I extends Signal, O extends Signal>({
    Cell? bind,
    Receptor<C,I,O>? receptor,
    TestObject test = TestObject.passed,
    Synapses<O,L>? synapses,
  }) {
    return OpenCell<C,L,I,O>(
      bind: bind,
      receptor: receptor ?? Receptor<C,I,O>(),
      synapses: synapses ?? Synapses.enabled
    );
  }

  /// Creates an [Deputy] cell from an existing [Cell] instance with reduced permissions.
  ///
  /// Parameters:
  /// - [test]: Optional test object for validation
  /// - [mapObject]: Optional map object for transformation
  /// (Note: Either [test] or [mapObject] must be provided to create a deputy cell for
  /// specific function by applying validation rules)
  ///
  /// Returns a new [CellDeputy] instance
  Cell deputy({covariant TestObject? test, covariant MapObject? mapObject});

  /// Gets the test object associated with the cell.
  ///
  /// This object is used to validate operations and signals.
  ///
  /// Returns a [TestObject] instance
  TestObject get test;

  /// Applies a function with controlled validation.
  ///
  /// Parameters:
  /// - [function]: The operation to perform
  /// - [positionalArguments]: Positional args
  /// - [namedArguments]: Named args
  ///
  /// Returns:
  /// [Sync] The result of the operation if validation passes
  /// [Async] A `Future` that resolves to the result of the operation
  dynamic apply(Function function, List? positionalArguments, [Map<Symbol, dynamic>? namedArguments]);

  /// Returns an iterable containing modifiable functions.
  Iterable<Function> get modifiable;

  /// Creates an unmodifiable view of this cell.
  ///
  /// Returns a cell that:
  /// - Shares the same internal state
  /// - Blocks all mutating operations
  /// - Maintains all existing synapses
  Cell get unmodifiable;

  /// Creates an async variant for modifiable operations
  CellAsync<Cell> get async;

}

/// A specialized [Cell] that provides a default implementation for the [Cell] interface.
///
/// This class serves as a base for creating reactive cells with customizable properties.
/// It includes:
///
/// - Default implementations for [apply], [deputy], and [unmodifiable]
/// - Support for linking and synapses
/// - A test object for validation
/// - A receptor for signal processing
///
class CellSync implements Cell, Sync {

  @override
  final Properties _properties;

  /// Creates a new [CellSync] with optional binding and configuration
  ///
  /// Parameters:
  /// - [bind]: Optional [Cell] to bind to (creates observing/chaining)
  /// - [receptor]: How this cell processes incoming signals (default: Receptor.unchanged)
  /// - [test]: TestObject that validates operations (default: TestObject.passed)
  /// - [synapses]: Whether this cell can be linked to others (default: Linkable.enabled)
  ///
  /// Returns a new [CellSync] instance
  ///
  /// Example:
  /// ```dart
  /// final cell = CellSync(
  ///  receptor: Receptor.unchanged,
  ///  bind: parentCell,
  ///  test: TestObject.passed,
  ///  synapses: Synapses.enabled
  /// );
  ///  ```
  /// ## Note:
  /// This class is not intended for direct instantiation.
  /// Instead, use the factory constructor [Cell] to create instances.
  ///
  /// ## Architecture Notes:
  /// - Implements [Cell] interface for core functionality
  /// - Uses [Properties] for configuration
  /// - Supports [TestObject] for validation
  /// - Integrates with [Synapses] for linking
  /// - Provides [Receptor] for signal processing
  ///
  /// ## Example:
  /// ```dart
  /// final cell = CellSync(
  /// receptor: Receptor.unchanged,
  /// bind: parentCell,
  /// test: TestObject.passed,
  /// synapses: Synapses.enabled
  /// );
  /// // Create a deputy cell
  /// final deputy = cell.deputy(
  /// test: TestObject.passed,
  /// mapObject: MapObject.from(cell)
  /// );
  /// // Apply a function
  /// final result = cell.apply(someFunction, [arg1, arg2]);
  /// ```
  CellSync({
    Cell? bind,
    Receptor receptor = Receptor.unchanged,
    TestObject test = TestObject.passed,
    Synapses synapses = Synapses.enabled
  }) : this.fromProperties(Properties(
    receptor: receptor, bind: bind, test: test,
    synapses: synapses == Synapses.enabled ? Synapses() : synapses,
  ));

  /// Creates a new [CellSync] from existing properties.
  ///
  /// Parameters:
  /// - [properties]: The properties to use for this cell
  ///
  /// Returns a new [CellSync] instance
  ///
  /// Example:
  /// ```dart
  /// final properties = Properties(
  ///  receptor: Receptor.unchanged,
  ///  bind: parentCell,
  ///  test: TestObject.passed,
  ///  synapses: Synapses.enabled
  ///  );
  /// final cell = CellSync.fromProperties(properties);
  /// ```
  CellSync.fromProperties(Properties properties) : _properties = properties {
    try {
      if (properties.bind != null) {
        properties.bind!._properties.synapses.link(this, host: properties.bind!);
      }
    } catch(_) {}
  }

  @override
  Cell deputy({covariant TestObject? test, covariant MapObject? mapObject}) {
    return CellDeputy(bind: this, test: test, mapObject: mapObject);
  }

  @override
  TestObject get test => _properties.test;

  @override
  int get hashCode => identityHashCode(_properties.bind ?? this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) {
      return true;
    }
    return false;
  }

  @override
  dynamic apply(Function function, List? positionalArguments, [Map<Symbol, dynamic>? namedArguments]) {

    if (modifiable.contains(function)) {
      if (!test.action(function, this, arguments: (positionalArguments: positionalArguments, namedArguments: namedArguments))) {
        return;
      }
    }
    return Function.apply(function, positionalArguments, namedArguments);
  }

  @override
  Iterable<Function> get modifiable => <Function>{apply};

  @override
  Cell get unmodifiable => this;

  @override
  CellAsync<Cell> get async => CellAsync<Cell>(this);

}

/// An extended [Cell] with open receptor and linking capabilities for enhanced reactivity.
///
/// This specialized cell type provides:
/// - Direct access to signal reception through [receptor]
/// - Explicit link management via [link]/[unlink]
/// - Additional mutability points for framework extensions
///
/// ## Key Differences from Base [Cell]:
/// - **Open Reception**: Public `receptor` method for direct signal processing
/// - **Explicit Linking**: Managed link operations appear in [modifiable] set
/// - **Framework Use**: Designed for internal framework extensions
///
/// ## Example Usage:
/// ```dart
/// final openCell = OpenCell<MyCell, MyLink, InputSig, OutputSig>(
///   receptor: Receptor(({cell, signal}) => transform(signal)),
///   bind: parentCell,
///   synapses: Synapses([existingLinks])
/// );
///
/// // Direct signal processing:
/// final result = openCell.receptor(inputSignal);
///
/// // Managed linking:
/// openCell.link(otherCell);
/// ```
///
/// ## Type Parameters:
/// - `C`: The concrete cell type
/// - `L`: The type of linkable cells
/// - `I`: Input signal type
/// - `O`: Output signal type
abstract interface class OpenCell<C extends Cell, L extends Cell, I extends Signal, O extends Signal> implements Cell {

  /// Creates an open cell with configurable reception and linking.
  ///
  /// Parameters:
  /// - [receptor]: Signal transformation logic
  /// - [bind]: Optional parent cell to connect with
  /// - [synapses]: Link management configuration
  factory OpenCell({
    Receptor<C,I,O> receptor,
    Cell? bind,
    Synapses synapses,
  }) = OpenCellSync<C,L,I,O>;

  /// Processes an incoming signal
  ///
  /// Parameters:
  /// - [signal]: The incoming signal to process
  ///
  /// Returns:
  /// - [Sync] The processed output signal or null if rejected
  /// - [Async] A `Future` that resolves to the processed output signal or null if rejected
  receptor(I signal);

  /// Links another cell to this one
  ///
  /// Parameters:
  /// - [cell]: The cell to link
  ///
  /// Returns true if linking succeeded (passed test rules)
  bool link(L cell);

  /// Unlinks a previously linked cell
  ///
  /// Parameters:
  /// - [link]: The cell to unlink
  ///
  /// Returns true if unlinking succeeded
  bool unlink(L cell);

  /// Creates an deputy (view) of this open cell with modified validation.
  ///
  /// Parameters:
  /// - [test]: Optional additional validation rules
  /// - [mapObject]: Optional transformation rules
  ///
  /// Returns a new cell that delegates to this cell with enhanced validation.
  @override
  OpenCell<C,L,I,O> deputy({covariant TestObject? test, covariant MapObject? mapObject});

  /// Provides asynchronous access to this cell's operations.
  ///
  /// Enables:
  /// - Async signal reception
  /// - Thread-safe operation application
  @override
  OpenCellAsync<C,L,I,O> get async;
}

/// A specialized [Cell] that provides open receptor and synapse binding
///
/// This class extends [CellSync] to provide:
/// - Open receptor for signal processing
/// - Synapse management for linking
/// - Deputy creation for modified validation
///
/// ## Example Usage:
/// ```dart
/// final openCell = OpenCellSync(
///  receptor: Receptor.unchanged,
///  bind: parentCell,
///  synapses: Synapses.enabled
///  );
/// // Create a deputy cell
/// final deputy = openCell.deputy(
/// test: TestObject.passed,
/// mapObject: MapObject.from(openCell)
/// );
/// // Apply a function
/// final result = openCell.apply(someFunction, [arg1, arg2]);
/// ```
class OpenCellSync<C extends Cell, L extends Cell, I extends Signal, O extends Signal>
    extends CellBase
    with OpenReceptorMixin<C,I,O>, OpenSynapsesMixin<L>
    implements OpenCell<C,L,I,O>, Sync {

  /// Creates a new [OpenCellSync] with open receptor and synapse binding
  ///
  /// Parameters:
  ///
  OpenCellSync({
    Receptor<C,I,O>? receptor,
    Cell? bind,
    Synapses synapses = Synapses.enabled,
  }) : super.fromProperties(Properties(
    receptor: receptor ?? Receptor<C,I,O>(),
    bind: bind,
    synapses: synapses == Synapses.enabled ? Synapses<O,L>() : synapses,
  ));

  @override
  OpenCell<C,L,I,O> deputy({covariant TestObject? test, covariant MapObject? mapObject}) {
    return OpenCellDeputy<C,L,I,O>(bind: this, test: test, mapObject: mapObject);
  }

  @override
  OpenCellAsync<C,L,I,O> get async => OpenCellAsync(this);
}

/// Provides asynchronous execution of operations on a [Cell].
///
/// This wrapper enables:
/// - Thread-safe operation execution via Dart's `Future` mechanism
/// - Non-blocking cell interactions
/// - Integration with async/await patterns
///
/// ## Core Capabilities:
/// - Wraps synchronous [Cell]] modifiable operations (i.e. add, remove) in futures
/// - Maintains all validation rules during async execution
/// - Preserves the cell's reactive behavior
///
/// ## Example Usage:
/// ```dart
/// final cell = Cell();
/// final asyncCell = cell.async;
///
/// // Async operation execution:
/// asyncCell.apply(someFunction, args).then((result) {
///   // Handle result
/// });
///
/// // With async/await:
/// final result = await asyncCell.apply(processData, [input]);
/// ```
class CellAsync<C extends Cell> implements Cell, Async {

  final C _cell;

  /// Creates an async interface for the given cell
  const CellAsync(C cell) : _cell = cell;

  /// Asynchronously applies a function through the cell's validation system.
  ///
  /// Parameters:
  /// - [function]: The operation to execute
  /// - [positionalArguments]: List of positional arguments
  /// - [namedArguments]: Map of named arguments
  ///
  /// Returns a [Future] that completes with:
  /// - The function result if validation passes
  /// - null if validation fails
  ///
  /// Execution flow:
  /// 1. Validates the operation using cell's rules
  /// 2. Queues the operation via `Future(() => ...)`
  /// 3. Preserves all reactive connections
  @override
  Future apply(Function function, List? positionalArguments, [Map<Symbol, dynamic>? namedArguments]) async {
    return Future(() => _cell.apply(function, positionalArguments, namedArguments));
  }

  @override
  Properties get _properties => _cell._properties;

  @override
  Cell deputy({covariant TestObject<Cell>? test, covariant MapObject? mapObject}) {
    return _cell.deputy(test: test, mapObject: mapObject);
  }

  @override
  CellAsync<Cell> get async => this;

  @override
  Iterable<Function> get modifiable => <Function>{apply};

  @override
  TestObject<Cell> get test => _cell.test;

  @override
  Cell get unmodifiable => _cell.unmodifiable;

  @override
  int get hashCode => _cell.hashCode;

  @override
  bool operator ==(Object other) => _cell == other;

  @override
  String toString() => _cell.toString();

}

/// An asynchronous executor for [OpenCell] with enhanced signal processing capabilities.
///
/// Extends [CellAsync] to provide:
/// - Type-safe asynchronous signal reception
/// - Full access to open cell functionality
/// - Thread-safe operation with reactive preservation
///
/// ## Key Features:
/// - `receptor()`: Asynchronously processes signals with output type safety
/// - Maintains all [OpenCell] capabilities in async context
/// - Composes with other async operations via [Future] API
///
/// ## Example Usage:
/// ```dart
/// final openCell = OpenCell<MyCell, MyLink, InputSig, OutputSig>(...);
/// final asyncCell = openCell.async;
///
/// // Async signal processing:
/// final output = await asyncCell.receptor(inputSignal);
///
/// // Chained operations:
/// asyncCell.receptor(input)
///   .then((out) => asyncCell.apply(process, [out]))
///   .catchError(...);
/// ```
class OpenCellAsync<C extends Cell, L extends Cell, I extends Signal, O extends Signal>
    extends CellAsync<OpenCell<C,L,I,O>>
    implements OpenCell<C,L,I,O> {

  /// Creates an async executor for an [OpenCell]
  const OpenCellAsync(super.cell) : super();

  /// Asynchronously processes a signal through the cell's receptor.
  ///
  /// Parameters:
  /// - [signal]: The input signal to process
  ///
  /// Returns a `Future<O?>` that completes with:
  /// - The transformed output signal if reception succeeds
  /// - null if reception fails validation
  ///
  /// Execution Flow:
  /// 1. Validates signal against cell's [TestObject] rules
  /// 2. Processes via cell's [Receptor] on Dart event loop
  /// 3. Propagates through synapses if successful
  @override
  Future<O?> receptor(I signal) async {
    return _cell._properties.receptor.async(cell: _cell, signal: signal);
  }

  @override
  bool link(L cell) {
    return _cell.link(cell);
  }

  @override
  bool unlink(L cell) {
    return _cell.unlink(cell);
  }

  @override
  OpenCell<C,L,I,O> deputy({covariant TestObject? test, covariant MapObject? mapObject}) {
    return _cell.deputy(test: test, mapObject: mapObject);
  }

  @override
  OpenCellAsync<C,L,I,O> get async => this;
}

/// Mixin that adds signal reception capabilities to a Cell.
///
/// When mixed into a Cell, allows it to process incoming signals
/// according to its test rules and receptor configuration.
mixin OpenReceptorMixin<C extends Cell, I extends Signal, O extends Signal> on Cell {

  /// Processes an incoming signal
  ///
  /// Parameters:
  /// - [signal]: The incoming signal to process
  ///
  /// Returns the processed output signal or null if rejected
  O? receptor(I signal)  {

    if (test(signal)) {
      try {
        final out = _properties.receptor(cell: this, signal: signal);
        if (out is O?) {
          return out;
        }
      } catch(_) {}
    }

    return null;
  }

  @override
  Iterable<Function> get modifiable => <Function>{receptor, ...super.modifiable};

}

/// Mixin that adds cell linking capabilities.
///
/// Allows cells to form observable relationships where changes
/// in one cell can propagate to linked cells.
mixin OpenSynapsesMixin<L extends Cell> on Cell {

  /// Links another cell to this one
  ///
  /// Parameters:
  /// - [cell]: The cell to link
  ///
  /// Returns true if linking succeeded (passed test rules)
  bool link(L cell) => _properties.synapses.link(cell, host: this);

  /// Unlinks a previously linked cell
  ///
  /// Parameters:
  /// - [link]: The cell to unlink
  ///
  /// Returns true if unlinking succeeded
  bool unlink(L link) => _properties.synapses.unlink(link);

  @override
  Iterable<Function> get modifiable => <Function>{link, unlink, ...super.modifiable};

}

/// A simple identifier class using Symbols for tagging/labeling purposes.
/// Useful for categorizing or marking cells without modifying their behavior.
class Tag {

  /// Creates a [Tag] with the specified identifier.
  const Tag({required this.identifier});

  /// The Symbol used to identify this tag
  final Symbol identifier;

  @override
  bool operator ==(other) {
    return other is Tag && (identical(this, other) || identifier == other.identifier);
  }

  @override
  int get hashCode => identifier.hashCode;

}

/// A typed signal that can be transmitted through cells.
///
/// Signals carry optional payload data and can be compared for equality.
/// Used as the primary communication mechanism between cells.
///
/// Example:
/// ```dart
/// // Example:
/// final numberSignal = Signal<int>(42);
/// final eventSignal = Signal<Map<String,dynamic>>({
///   'type': 'click',
///   'position': [100, 200]
/// });
/// ```
class Signal<T> {

  /// The payload data carried by this signal
  final T? body;

  /// Creates a signal with optional body payload
  const Signal([this.body]);

  @override
  bool operator ==(other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is Signal<T>) {
      return other.body == body;
    }
    if (other is T) {
      return other == body;
    }
    return false;
  }

  @override
  int get hashCode => body?.hashCode ?? super.hashCode;

}
