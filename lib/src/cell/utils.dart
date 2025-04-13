// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../cell.dart';

/// Class tag to indicate Async version of an object
abstract class Async<C> implements Sync<C> {}

/// Class tag o indicate Sync version of an object
abstract class Sync<C> {

  /// An Async variant of the object
  C get async;

}

/// A marker interface indicating immutable/unmodifiable cell variants.
///
/// This serves as a runtime and compile-time indicator that a cell or collection:
/// - **Blocks mutations**: All mutating operations will throw [UnsupportedError]
/// - **Preserves reactivity**: Maintains existing signal propagation
/// - **Enforces safety**: Guarantees immutable view of data
///
/// ## Key Characteristics:
/// - Implemented by all unmodifiable cell variants (collections, values, etc.)
/// - Checkable via `is Unmodifiable` at runtime
/// - Used by [TestActionRule] to auto-reject mutations
///
/// ## Example Usage:
/// ```dart
/// final baseCell = CollectiveList<int>([1, 2, 3]);
/// final unmodifiable = baseCell.unmodifiable;
///
/// if (unmodifiable is Unmodifiable) {
///   print('This cell is immutable');
///   unmodifiable.add(4); // Throws UnsupportedError
/// }
/// ```
///
/// ## Architecture Notes:
/// - Works with [Cell]'s `modifiable` set to block operations
/// - All mutating methods check this interface first
/// - Collections return unmodifiable views rather than copies
abstract class Unmodifiable {}

/// Generic function type that takes no parameters and returns R.
/// Used in FunctionTypeObject for lazy evaluation.
typedef FunctionType<R> = R Function();

/// Wrapper class for holding typed objects.
/// Provides type safety when working with generic containers.
class TypeObject<T> {

  /// The wrapped object
  final T obj;

  /// Creates a TypeObject wrapping the given object
  const TypeObject(this.obj);

}

/// Lazy-evaluated version of TypeObject that executes a function to get the value.
/// Useful for deferred initialization or expensive object creation.
class FunctionTypeObject<T> implements TypeObject<T> {

  final FunctionType<T> _functionType;

  /// Executes the function and returns the result
  @override
  T get obj => _functionType();

  /// Creates a FunctionTypeObject with a function that provides the value
  const FunctionTypeObject(FunctionType<T> functionType) : _functionType = functionType;
}

/// Simple wrapper for functions or records containing function information.
/// Used to pass function metadata through the system.
class FunctionObject {

  /// The wrapped function data (could be a function or record)
  final dynamic record;

  /// Creates a FunctionObject containing function data
  const FunctionObject(this.record);
}


