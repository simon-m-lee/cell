// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

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
///   final score = ValueCell<int>(value: 0);
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
/// ### Non‑obvious
/// - The `value` getter uses the cell's lock, so it waits for any ongoing
///   transformation to complete before returning.
/// - The `update` method is private; you use `emitAsync` from the
///   `StateHandle` returned by `Cell.state`.
/// - All operations are scheduled on the Dart event loop; they never block
///   the calling thread.
/// - The controller does not create its own lock – it reuses the cell's.
/// - If the cell is invalidated, operations may return stale data or fail
///   silently; check `cell.isInvalidated` before using.
///
/// ### Example: Reading State Asynchronously
/// ```dart
/// final counter = Cell.state<int>(value: 0);
/// final async = counter.cell.async;
/// final current = await async.value; // waits for any ongoing update
/// print('Current: $current');
/// ```
///
/// ### Example: Triggering an Update
/// ```dart
/// // From the StateHandle returned by Cell.state:
/// final handle = Cell.state<int>(value: 0);
/// await handle.updateAsync(5); // increments by 5
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
  /// ### Non‑obvious
  /// - The controller is **cheap** – it's just a wrapper.
  /// - It shares the cell's lock, so it's fully thread‑safe.
  ///
  /// ### Parameters:
  /// - [cell]: The principal [ValueCell] to control.
  ValueCellAsync(super.cell);

  /// Asynchronously retrieves the current state of the principal [ValueCell]
  /// with a guarantee of **Atomic Memory Consistency**.
  ///
  /// This getter is the primary mechanism for performing a **Thread‑Safe Read**
  /// from the asynchronous execution layer. It facilitates the framework's
  /// **Conactive** model by ensuring that the value retrieved is never
  /// "torn" or partial, even in high‑concurrency environments.
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
  /// ### Non‑obvious
  /// - This getter is **not** cached – each access reads the current value.
  /// - It returns `null` if the cell's state is `null`.
  /// - If the cell is invalidated, it may still return the last valid value
  ///   or `null`; check `cell.isInvalidated` to avoid stale reads.
  ///
  /// ### Returns:
  /// A [Future] that resolves to the current state [V?] of the cell once
  /// the synchronization domain is available.
  Future<V?> get value async {
    final lock = _cell._nucleus.lock;
    if (lock != null) {
      return lock.synchronized(() {
        return _cell.value;
      });
    }
    return await _cell._nucleus.value.async.value;
  }

  /// Asynchronously emits a state transition on the principal cell.
  ///
  /// This method is the asynchronous counterpart to the synchronous `emit`
  /// on [ValueCell]. It serialises the mutation through the cell's lock,
  /// ensuring atomicity.
  ///
  /// ### When to use
  /// Use this when you need to update the cell's state from an async context.
  /// You typically access this via `emitAsync` on the `StateHandle`.
  ///
  /// ### How it works
  /// - The method acquires the cell's lock (if present).
  /// - Inside the lock, it calls the synchronous `_emit` method.
  /// - Returns a `Future<bool>` indicating success.
  ///
  /// ### Non‑obvious
  /// - This method is private; use `emitAsync` from the `StateHandle`.
  /// - The mutation is subject to the same validation rules as synchronous
  ///   emits – the `TestCell` is enforced.
  /// - If the cell is invalidated, the emit will fail silently.
  ///
  /// ### Parameters:
  /// - [v]: The new value to set (passed as payload to the pulse).
  ///
  /// ### Returns:
  /// A [Future] that resolves to `true` if the value was successfully
  /// committed; `false` otherwise.
  Future<bool> _emit(V? v) async {
    final lock = _cell._nucleus.lock;
    return lock != null
        ? lock.synchronized(() {
          return _cell._emit(v);
        }).then((value) {
          return value;
        })
        : Future<bool>(() => _cell._emit(v)).then((value) => value);
  }

}
