// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../cell.dart';

/// Deputy is a pattern that allows a [Cell] that delegates actions to.
///
/// An deputy to a human person is someone who provides assistance, support, or services to help
/// that individual with their tasks, duties, or daily life. The responsibilities of an deputy
/// depend on the specific role and the needs of the person they are assisting.
/// to modify behavior without subclassing.
///
/// Likewise, a cell can have "deputies"  like a body-doubles for cells, they act on behalf of
/// the cell, carrying out tasks with limited authority while ensuring the cell functions
/// smoothly. Just like a general manager signs contracts on behalf of a CEO, these cellular
/// deputies perform tasks without replacing the cell itself but ensuring it operates efficiently.
///
/// The `CellDeputy` pattern enables:
/// - **Behavior Composition**: Adds validation/mapping without subclassing
/// - **Safe Modification**: Preserves original cell's immutability
/// - **Aspect Layering**: Stacks functionality through multiple deputies
/// - **Dynamic Behavior**: Alters behavior at runtime
/// - **Testability**: Facilitates unit testing by isolating behavior
/// - **Separation of Concerns**: Isolates different aspects of behavior
/// - **Security**: Provides controlled access to cell behavior
class CellDeputy extends CellBase with Deputy<Cell> {

  /// Creates a behavior-augmented view of a cell.
  ///
  /// Parameters:
  /// - [bind]: The cell to delegate to (required)
  /// - [test]: Additional validation rules (optional)
  /// - [mapObject]: Transformation rules (optional)
  /// (Note: Either [test] or [mapObject] must be provided to
  ///
  /// The deputy will:
  /// 1. Apply its own validation first
  /// 2. Delegate to the bound cell
  /// 3. Apply any mappings to results
  CellDeputy({required Cell bind, TestObject? test, MapObject? mapObject})
      : super.fromProperties(Properties.fromRecord((
      receptor: bind._properties.receptor,
      bind: bind,
      test: test != null ? TestObject.fromRules(rules: [test, bind.test]) : bind.test,
      mapObject: _mapObject(bind, mapObject)
    ))
  );

  static MapObject? _mapObject(Cell bind, MapObject? mapObject) {
    if (mapObject != null) {
      try {
        final mObj = bind._properties.record.mapObject;
        if (mObj != null) {
          return MapObject.from(mapObject, parent: mObj);
        }
      } catch(_) {}
    }
    return mapObject;
  }

  /// Creates a new deputy layered on top of this one.
  ///
  /// Parameters match main constructor - each call creates a new wrapper layer.
  ///
  /// Returns a new [CellDeputy] with combined:
  /// - Validation rules
  /// - Mapping transformations
  /// - Deputy capabilities
  ///
  /// The new deputy will:
  /// 1. Apply its own validation first
  /// 2. Delegate to the bound cell
  /// 3. Apply any mappings to results
  /// 4. Preserve all deputy functionality
  ///
  /// Note: This method does not modify the original cell.
  ///
  /// Example:
  /// ```dart
  /// final cell = Cell();
  /// final deputy = cell.deputy(test: TestObject(...));
  /// final newDeputy = deputy.deputy(test: TestObject(...));
  /// ```
  @override
  Cell deputy({covariant TestObject<Cell>? test, covariant MapObject? mapObject}) {
    return CellDeputy(bind: _properties.bind!, test: test, mapObject: mapObject);
  }

  @override
  dynamic apply(Function function, List? positionalArguments, [Map<Symbol, dynamic>? namedArguments]) {
    final cell = _properties.bind;
    if (cell != null) {
      return cell.apply(function, positionalArguments, namedArguments);
    }
  }

}

/// A specialized [CellDeputy] that maintains open receptor and linking capabilities
/// while adding layered behavior to an [OpenCell].
///
/// Combines the functionality of:
/// - [CellDeputy]'s behavior composition
/// - [OpenCell]'s direct signal processing
/// - [OpenSynapsesMixin]'s explicit connection management
///
/// ## Key Features:
/// - Preserves all open cell capabilities (reception/linking)
/// - Applies stacked validation/mapping rules
/// - Provides type-safe signal transformation
/// - Maintains unmodifiable views when requested
///
/// ## Example Usage:
/// ```dart
/// final openCell = OpenCell<MyCell, MyLink, InputSig, OutputSig>(...);
///
/// // Create validated deputy
/// final validated = OpenCellDeputy<MyCell, MyLink, InputSig, OutputSig>(
///   bind: openCell,
///   test: TestObject(...)
/// );
///
/// // Still maintains open capabilities:
/// final result = processed.receptor(input);
/// processed.link(otherCell);
/// ```
class OpenCellDeputy<C extends Cell, L extends Cell, I extends Signal, O extends Signal>
    extends CellDeputy with OpenReceptorMixin<C,I,O>, OpenSynapsesMixin<L> implements OpenCell<C,L,I,O> {

  /// Creates an deputy for an [OpenCell] with additional behavior layers or reduced
  /// accesses to [bind] cell.
  ///
  /// Parameters:
  /// - [bind]: The open cell to wrap (required)
  /// - [test]: Additional validation rules (optional)
  /// - [mapObject]: Value transformations (optional)
  ///
  /// The deputy will:
  /// 1. Apply its own validation/mapping first
  /// 2. Delegate to the bound open cell
  /// 3. Preserve all open cell functionality
  OpenCellDeputy({required super.bind, super.test, super.mapObject}) : super();

  /// Creates a new deputy layer while preserving open cell typing.
  ///
  /// Returns a new [OpenCellDeputy] with combined:
  /// - Validation rules
  /// - Mapping transformations
  /// - Open capabilities
  @override
  OpenCell<C,L,I,O> deputy({covariant TestObject<Cell>? test, covariant MapObject? mapObject}) {
    return OpenCellDeputy<C,L,I,O>(bind: _properties.bind!, test: test, mapObject: mapObject);
  }

  /// Provides asynchronous access while maintaining open capabilities.
  ///
  /// The returned async callable preserves:
  /// - Type-safe signal reception
  /// - All validation layers
  /// - Link management capabilities
  @override
  OpenCellAsync<C,L,I,O> get async => OpenCellAsync(this);
}

/// A mixin that provides the ability to create [Deputy] for a cell.
mixin Deputy<C extends Cell> on Cell {

  @override
  C deputy({covariant TestObject? test, covariant MapObject? mapObject});

  @override
  C get unmodifiable => (_properties.bind as C).unmodifiable as C;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is Deputy) {
      return identical(_properties.bind, other._properties.bind);
    }
    if (other is Cell) {
      return identical(other._properties.bind, other);
    }
    return false;
  }

}