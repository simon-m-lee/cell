// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../cell.dart';

/// A function signature for value transformations within a [MapObject] pipeline.
///
/// This typedef defines the contract for all mapping functions used by [MapObject]:
/// - Transforms an input value of type [E] to output of the same type
/// - Operates within an optional [Cell] context
/// - Accepts additional user context
///
/// ## Signature Details:
/// ```dart
/// E Function<E>(E object, {Cell? cell, dynamic user})
/// ```
///
/// ## Key Characteristics:
/// - **Type Preservation**: Input/output types must match
/// - **Context Awareness**: Optional cell and user context
/// - **Null Safety**: Should handle null inputs appropriately
/// - **Pure Function**: Should avoid side effects
///
typedef MapFunction = E Function<E>(E object, {Cell? cell, dynamic user});

/// A configurable mapping system that can transform objects based on their type.
/// Supports chaining through parent mappings and type-specific transformations.
///
/// This class is designed to be immutable, meaning once created, the mapping rules cannot be changed.
/// It allows for a flexible and extensible way to handle different types of objects in a consistent manner.
///
/// ## Key Features:
/// - **Type-Specific Mapping**: Define how different types should be transformed.
/// - **Parent Mapping**: Chain mappings together for more complex transformations.
/// - **Immutability**: Once created, the mapping rules cannot be modified.
/// - **Null Safety**: Handles null inputs gracefully.
/// - **Type Preservation**: Input and output types are preserved.
class MapObject {

  /// Immutable mapping rules by type
  final Map<Type,MapFunction> map;

  /// Optional parent mapper for chaining
  final MapObject? parent;

  /// A configurable value transformer that applies type-specific mapping rules to objects.
  ///
  /// This implements a chainable transformation pipeline that:
  /// 1. Processes values through parent mappings first (if any)
  /// 2. Applies type-specific transformations
  /// 3. Preserves unmapped types unchanged
  ///
  /// ## Core Features:
  /// - **Type-Specific Handling**: Different transformations per type
  /// - **Chained Execution**: Parent-child mapping composition
  /// - **Null Safety**: Handles null inputs gracefully
  /// - **Immutability**: All mappings are final after creation
  ///
  /// ## Example Usage:
  /// ```dart
  /// // Create mapper for specific types
  /// final mapper = MapObject(
  ///   type: String,
  ///   function: (s) => s.toUpperCase(),
  ///   parent: anotherMapper
  /// );
  ///
  /// // Apply transformations
  /// mapper(123); // Returns 123 (unchanged)
  /// mapper('text'); // Returns 'TEXT'
  /// ```
  MapObject({required Type type, required MapFunction function, MapObject? parent})
      : map = Map.unmodifiable(<Type,MapFunction>{type: function}), parent = parent is MapObject ? parent : null;

  /// Creates a MapObject from a map, preserving parent chain if provided
  MapObject.from(MapObject map, {MapObject? parent})
      : map = Map.unmodifiable(map.map), parent = parent is MapObject ? parent : null;

  /// Creates a MapObject from multiple mapping entries
  MapObject.fromEntries(Iterable<MapEntry<Type, MapFunction>> entries, {MapObject? parent})
      : map = Map.unmodifiable(Map<Type,MapFunction>.fromEntries(entries)), parent = parent is MapObject ? parent : null;

  /// Applies the mapping to an object, walking up the parent chain if needed
  T call<T>(T object, {Cell? cell, dynamic user}) {
    T obj = parent != null ? parent!(object) : object;
    final type = T != dynamic ? T : obj.runtimeType;
    return map.containsKey(type) ? map[type]!<T>(obj) : obj;
  }

  /// Gets the mapping function for a specific type
  MapFunction? operator [](Type type) {
    return map[type];
  }

}

