// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A specialized asynchronous controller for [ValueCell], providing a
/// thread‑safe and non‑blocking interface for state interaction.
///
/// `ValueCellAsync` acts as the primary architectural bridge between the
/// synchronous reactive graph and Dart's asynchronous execution model. It
/// implements the `ModifiableAsync` contract, allowing external components—
/// such as UI frameworks, background workers, or network layers—to interact
/// with a `ValueCell` without stalling the main execution thread or
/// compromising the cell's atomic integrity.
///
/// ### When to use
/// * You obtain an instance via `cell.async` on any `ValueCell`:
///   ```dart
///   final score = ValueCell<int>(state: 0);
///   final async = score.async;
///   ```
/// * Use this when you need to:
///   - Read the current state from an asynchronous context.
///   - Trigger an update without blocking the caller.
///   - Ensure thread‑safe access to the cell's state.
///   - Await the completion of a state transition.
///
/// ### How it works
/// - Every method in this class delegates to the cell's internal `Lock`,
///   ensuring that reads and writes are serialised and atomic.
/// - Reads return `Future<V?>` and are guaranteed to see a consistent
///   snapshot of the state.
/// - Writes (via `_emit`) are also serialised through the lock.
/// - The controller is lightweight – it holds only a reference to the
///   principal cell.
///
/// ### Example: Reading State Asynchronously
/// ```dart
/// final counter = Cell.state<int>(state: 0);
/// final async = counter.cell.async;
/// final current = await async.state; // waits for any ongoing update
/// print('Current: $current');
/// ```
///
/// ### Example: Triggering an Update
/// ```dart
/// // From the StateHandle returned by Cell.state:
/// final handle = Cell.state<int>(state: 0);
/// await handle.updateAsync(5); // sets state to 5
/// ```
///
/// See also:
/// * [ValueCell] – the synchronous state container.
/// * [StateHandle] – the record returned by [Cell.state].
/// * [ModifiableAsync] – the base contract for asynchronous operations.
class ValueCellAsync<V> extends ModifiableAsync<ValueCell<V>> {
  /// Initializes a new [ValueCellAsync] controller, anchoring an
  /// asynchronous execution layer to a specific [ValueCell] principal.
  ///
  /// ### When to use
  /// You typically obtain this via `cell.async`, not by calling the
  /// constructor directly.
  ///
  /// ### How it works
  /// - The constructor stores a reference to the principal cell.
  /// - It doesn't allocate any additional state – all state is held in the
  ///   cell's nucleus.
  /// - The resulting instance is ready for asynchronous operations.
  ///
  /// ### Parameters:
  /// - [cell]: The principal [ValueCell] to control.
  ValueCellAsync(super.cell);

  /// Asynchronously retrieves the current state of the principal [ValueCell].
  ///
  /// When the cell has a lock, the read is serialized behind any in-flight
  /// mutation, so callers observe a consistent point-in-time snapshot. On
  /// the default lock-free cell the read is a plain, synchronous-isolate
  /// access — there are no OS threads involved.
  ///
  /// ### When to use
  /// Use this when you need to read the cell's state from an async context.
  ///
  /// ### How it works
  /// - The getter wraps the read in the cell's internal `Lock`.
  /// - If a transformation is currently in progress, the Future waits until
  ///   the lock is released.
  /// - The returned value is a point‑in‑time snapshot that is guaranteed
  ///   consistent.
  ///
  /// ### Returns:
  /// A [Future] that resolves to the current state [V?] of the cell once
  /// the synchronization domain is available.
  Future<V?> get state async {
    final lock = _cell._nucleus.lock;
    if (lock != null) {
      return lock.synchronized(() {
        return _cell.value;
      });
    }
    return await _cell._nucleus.state.async.state;
  }

  /// Asynchronously emits a state transition on the principal cell.
  ///
  /// This method is the asynchronous counterpart to the synchronous `update`
  /// on [ValueCell]. It serialises the mutation through the cell's lock,
  /// ensuring atomicity.
  ///
  /// ### When to use
  /// Use this when you need to update the cell's state from an async context.
  /// You typically access this via `updateAsync` on the `StateHandle`.
  ///
  /// ### How it works
  /// - The method acquires the cell's lock (if present).
  /// - Inside the lock, it calls the synchronous `_emit` method.
  /// - Returns a `Future<bool>` indicating success.
  ///
  /// ### Parameters:
  /// - [v]: The new state to set (passed as payload to the pulse).
  ///
  /// ### Returns:
  /// A [Future] that resolves to `true` if the value was successfully
  /// committed; `false` otherwise.
  Future<bool> _emit(V? v) async {
    final lock = _cell._nucleus.lock;
    Future<bool> submit() async {
      // Await the full pipeline: with async validation the synchronous
      // `ValueCell._emit` can only report "accepted" (a Future is non-null
      // before it resolves). Resolving the receptor's Future here reports
      // the committed outcome — an async-rejected mutation must resolve
      // false, not true.
      if (identical(v, _cell.value) || v == _cell.value) return false;
      final receptor = _cell._nucleus.receptor;
      final result = receptor.call(v == null ? Pulse<V>(null) : Pulse<V>(v));
      if (result is Future<Pulse?>) {
        return (await result) != null;
      }
      return result != null;
    }

    return lock != null ? lock.synchronized(submit) : submit();
  }
}
