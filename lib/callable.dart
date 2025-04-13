// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'cell.dart';
import 'collective.dart';

// ignore_for_file: prefer_constructors_over_static_methods

/// A callable class that returns the [Async] object.
final class AsyncCallable {

  /// Creates an instance of [AsyncCallable].
  const AsyncCallable();

  /// Returns the [Async] of the [Sync] object.
  C call<C extends Sync>(C sync) => sync.async;

}

/// A callable class that returns the [Unmodifiable] object.
final class UnmodifiableCallable {

  /// Creates an instance of [UnmodifiableCallable].
  const UnmodifiableCallable();

  /// Returns the [Unmodifiable] of the [Sync] object.
  call<C extends Cell>(C cell) => cell.unmodifiable;

}

