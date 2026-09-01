// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.
import 'dart:collection';

import 'package:synchronized/synchronized.dart';

Map<String, dynamic> mapMerge<K,V>(Map<String, dynamic> map, Map<String, dynamic> other) {
  final m = Map<String, dynamic>.from(map);

  for (var en in other.entries) {
    if (m.containsKey(en.key)) {
      if (en.value is Iterable) {
        if (m[en.key] is Iterable) {
          m.update(en.key, (v) => [...v, ...(en.value as Iterable)],
              ifAbsent: () => []);
        } else {
          m.update(en.key, (v) => [v, ...(en.value as Iterable)],
              ifAbsent: () => []);
        }
      } else {
        if (m[en.key] is Iterable) {
          m.update(en.key, (v) => [...v, en.value], ifAbsent: () => []);
        } else {
          m.update(en.key, (v) => [v, en.value], ifAbsent: () => []);
        }
      }
    } else {
      m[en.key] = en.value;
    }
  }
  return m;
}

/// A thread-safe implementation of a [Set], providing **Synchronized Access**
/// for collection-based state.
///
/// The [SyncSet] serves as a **Concurrency-Safe Container**, ensuring that the
/// membership of a set (such as the collection of active **Synapses** or
/// dependency nodes) remains atomically consistent even when accessed or
/// mutated across different reactive waves or asynchronous execution threads.
///
/// ### When to use
/// - **Dependency Management**: Tracking active listeners or observers that
///   may be added or removed from different asynchronous contexts.
/// - **Shared State**: Managing collections that are accessed by multiple
///   concurrent actors in the reactive fabric.
/// - **Resource Tracking**: Keeping track of active network connections or
///   file handles where structural integrity is paramount.
///
/// ### How it works
/// 1. **Serialization**: Uses a non-recursive [Lock] to serialize all access
///    to the underlying storage.
/// 2. **Asynchronous Interface**: All operations return [Future] handles,
///    aligning with the framework's non-blocking concurrency model.
/// 3. **Snapshot Isolation**: Methods that involve iteration (like [iterator],
///    [toList], or [map]) operate on a **Point-in-Time Snapshot**. This
///    prevents `ConcurrentModificationError` by allowing concurrent mutations
///    while a specific reactive wave processes the current state.
///
/// ### Non‑obvious
/// - **Locking Overhead**: While providing safety, the internal synchronization
///   introduces latency. For high-frequency read-only access within a single
///   thread, consider using [replicate] to get a local, non-synchronized copy.
/// - **Future Completion**: A mutation's [Future] completes once the lock is
///   acquired and the operation is applied, ensuring causal ordering between
///   sequential calls.
/// - **Zero-Blocking**: The use of `synchronized` ensures that the calling
///   thread remains free for other tasks while waiting for the set to become
///   available.
///
/// ### Example
/// ```dart
/// final registry = SyncSet<String>();
///
/// // Thread-safe addition
/// await registry.add('node_alpha');
///
/// // Safe iteration over a snapshot
/// final items = await registry.toList();
/// for (var item in items) {
///   print('Processing $item');
/// }
///
/// // Atomic bulk update
/// await registry.addAll(['node_beta', 'node_gamma']);
/// ```
///
/// ### Type Parameters:
/// * **[E]**: The type of elements contained within the synchronized set.
///
/// ### See Also:
/// * [Lock]: The underlying synchronization mechanism.
/// * [AsyncQueueList]: For a synchronized FIFO/LIFO structure.
class SyncSet<E> {
  /// The synchronization pulse (lock) governing access to the cytoplasm.
  final _lock = Lock();

  /// The internal, non-thread-safe storage container.
  final _set = <E>{};

  Future<bool> add(E value) {
    return _lock.synchronized(() => _set.add(value));
  }

  Future<bool> contains(Object? element) {
    return _lock.synchronized(() => _set.contains(element));
  }

  Future<Iterator<E>> get iterator {
    // To ensure thread safety during iteration, we provide an iterator
    // over a point-in-time snapshot (replication) of the set.
    return _lock.synchronized(() => _set.toList().iterator);
  }

  Future<int> get length {
    return _lock.synchronized(() => _set.length);
  }

  Future<E?> lookup(Object? element) {
    return _lock.synchronized(() => _set.lookup(element));
  }

  Future<bool> remove(Object? value) {
    return _lock.synchronized(() => _set.remove(value));
  }

  Future<Set<E>> toSet() {
    return _lock.synchronized(() => _set.toSet());
  }

  /// Clears all elements from the set within a synchronized pulse.
  Future<void> clear() {
    return _lock.synchronized(() => _set.clear());
  }

  /// Evaluates whether the set contains every element in [other].
  Future<bool> containsAll(Iterable<Object?> other) {
    return _lock.synchronized(() => _set.containsAll(other));
  }

  /// Returns a new set containing the elements of this set that are also in [other].
  Future<Set<E>> intersection(Set<Object?> other) {
    return _lock.synchronized(() => _set.intersection(other));
  }

  /// Returns a new set containing the elements of this set that are not in [other].
  Future<Set<E>> difference(Set<Object?> other) {
    return _lock.synchronized(() => _set.difference(other));
  }

  /// Returns a new set containing all elements of this set and [other].
  Future<Set<E>> union(Set<E> other) {
    return _lock.synchronized(() => _set.union(other));
  }

  /// Removes each element of [elements] from this set.
  Future<void> removeAll(Iterable<Object?> elements) {
    return _lock.synchronized(() => _set.removeAll(elements));
  }

  /// Removes all elements of this set that are not in [elements].
  Future<void> retainAll(Iterable<Object?> elements) {
    return _lock.synchronized(() => _set.retainAll(elements));
  }

  /// Removes all elements of this set that satisfy [test].
  Future<void> removeWhere(bool Function(E element) test) {
    return _lock.synchronized(() => _set.removeWhere(test));
  }

  /// Removes all elements of this set that fail to satisfy [test].
  Future<void> retainWhere(bool Function(E element) test) {
    return _lock.synchronized(() => _set.retainWhere(test));
  }

  /// Adds all elements of [elements] to this set.
  Future<void> addAll(Iterable<E> elements) {
    return _lock.synchronized(() => _set.addAll(elements));
  }

  /// Checks if the set contains no elements.
  Future<bool> get isEmpty => _lock.synchronized(() => _set.isEmpty);

  /// Checks if the set contains at least one element.
  Future<bool> get isNotEmpty => _lock.synchronized(() => _set.isNotEmpty);

  /// Executes [action] on each element of the set.
  Future<void> forEach(void Function(E element) action) {
    return _lock.synchronized(() => _set.forEach(action));
  }

  /// Maps each element to a new form, returning a point-in-time [List].
  Future<List<T>> map<T>(T Function(E e) toElement) {
    return _lock.synchronized(() => _set.map(toElement).toList());
  }

  /// Reduces the set to a single value by iteratively combining elements.
  Future<E> reduce(E Function(E value, E element) combine) {
    return _lock.synchronized(() => _set.reduce(combine));
  }

  /// Returns a point-in-time [List] representation of the set.
  Future<List<E>> toList({bool growable = true}) {
    return _lock.synchronized(() => _set.toList(growable: growable));
  }

  /// Returns a point-in-time [Iterable] of elements that satisfy [test].
  Future<Iterable<E>> where(bool Function(E element) test) {
    return _lock.synchronized(() => _set.where(test).toList());
  }

  /// Returns a fixed-point [Set] snapshot (replication) of the current state.
  Future<Set<E>> replicate() {
    return _lock.synchronized(() => Set<E>.from(_set));
  }
}

class QueueList<E> with IterableMixin<E> implements Queue<E> {
  final ListQueue<E> _list;

  QueueList([int? initialCapacity]) : _list = ListQueue<E>(initialCapacity);

  QueueList.from(Iterable<E> iterable) : _list = ListQueue<E>.from(iterable);

  QueueList.of(Iterable<E> iterable) : _list = ListQueue<E>.of(iterable);

  @override
  Iterator<E> get iterator => _list.iterator;

  @override
  int get length => _list.length;

  @override
  void add(E value) => _list.add(value);

  @override
  void addAll(Iterable<E> iterable) => _list.addAll(iterable);

  @override
  void addFirst(E value) => _list.addFirst(value);

  @override
  void addLast(E value) => _list.addLast(value);

  @override
  void clear() => _list.clear();

  @override
  bool remove(Object? value) => _list.remove(value);

  @override
  E removeFirst() => _list.removeFirst();

  @override
  E removeLast() => _list.removeLast();

  @override
  void removeWhere(bool Function(E element) test) => _list.removeWhere(test);

  @override
  void retainWhere(bool Function(E element) test) => _list.retainWhere(test);

  @override
  Queue<R> cast<R>() => _list.cast<R>();

  AsyncQueueList<E> get async => AsyncQueueList<E>(this);
}

class AsyncQueueList<E> {
  /// The synchronization pulse (lock) governing access to the queue cytoplasm.
  final _lock = Lock();

  final Queue<E> _queue;

  AsyncQueueList(this._queue);

  Future<Iterator<E>> get iterator =>
      _lock.synchronized(() => _queue.toList(growable: false).iterator);

  Future<void> add(E value) => _lock.synchronized(() => _queue.add(value));

  Future<void> addAll(Iterable<E> iterable) =>
      _lock.synchronized(() => _queue.addAll(iterable));

  Future<void> addFirst(E value) =>
      _lock.synchronized(() => _queue.addFirst(value));

  Future<void> addLast(E value) =>
      _lock.synchronized(() => _queue.addLast(value));

  Future<void> clear() => _lock.synchronized(() => _queue.clear());

  Future<void> remove(Object? value) =>
      _lock.synchronized(() => _queue.remove(value));

  Future<E> removeFirst() => _lock.synchronized(() => _queue.removeFirst());

  Future<E> removeLast() => _lock.synchronized(() => _queue.removeLast());

  Future<void> removeWhere(bool Function(E element) test) =>
      _lock.synchronized(() => _queue.removeWhere(test));

  Future<void> retainWhere(bool Function(E element) test) =>
      _lock.synchronized(() => _queue.retainWhere(test));

  Future<Queue<R>> cast<R>() => _lock.synchronized(() => _queue.cast<R>());

  Future<List<E>> toList({bool growable = true}) => _lock.synchronized(() => _queue.toList(growable: growable));

  Future<List<E>> toListAndClear({bool growable = true}) =>
      _lock.synchronized(() {
        final result = _queue.toList(growable: growable);
        _queue.clear();
        return result;
      });

  Future<void> clearAndAdd(E value) => _lock.synchronized(() {
        _queue
          ..clear()
          ..add(value);
      });
}

/// A collection of elements that maintains a **Deterministic Priority Order**,
/// serving as a specialized **Ranked Execution Buffer** for the reactive fabric.
///
/// Unlike standard FIFO queues, the [PriorityQueue] prioritizes **Operational
/// Precedence** over arrival sequence. It ensures that elements with the
/// highest priority (defined by a comparator or [Comparable] implementation)
/// are always positioned for immediate extraction, facilitating efficient
/// handling of weighted signals.
///
/// ### When to use
/// - **Signal Prioritization**: Ensuring administrative pulses or system
///   commands jump the queue ahead of standard state updates.
/// - **Task Scheduling**: Orchestrating reactive waves where "urgency" (e.g.,
///   security validation) outranks "arrival time".
/// - **Resource Management**: Processing high-contention elements first to
///   minimize graph stabilization latency.
///
/// ### How it works
/// 1. **Heap Architecture**: Utilizes a binary heap stored in a flat list
///    to achieve O(log n) efficiency for both [add] and [removeFirst].
/// 2. **Metabolic Ingestion**: The `add` method uses "Bubble Up" logic to
///    move new elements to their correct rank in the hierarchy.
/// 3. **Metabolic Extraction**: The `removeFirst` method extracts the root,
///    replaces it with the last leaf, and "Bubbles Down" to restore order.
/// 4. **Structural Reconstruction**: Methods like [removeWhere] perform a
///    full O(n) **Re-heapification** to maintain integrity after bulk changes.
///
/// ### Non‑obvious
/// - **Traversal Order**: The [iterator] and [forEach] methods traverse the
///   internal heap list, which does **not** guarantee priority order. Use
///   [removeFirst] sequentially if ranked traversal is required.
/// - **Removal Penalty**: Removing arbitrary elements via [remove] or
///   [removeWhere] is significantly more expensive than [removeFirst] due to
///   the required structural repair.
/// - **Comparison Strategy**: If no custom comparator is provided, elements
///   **must** implement [Comparable<E>], or a [TypeError] will occur during
///   insertion.
/// - **Non-Thread Safety**: This class is a "somatic" (synchronous) component.
///   For cross-thread synchronization, wrap it in [AsyncPriorityQueue].
///
/// ### Example
/// ```dart
/// // Create a queue where lower numbers have higher priority
/// final taskBuffer = PriorityQueue<int>((a, b) => a.compareTo(b));
///
/// taskBuffer.addAll([50, 10, 100, 5]);
///
/// // Extraction always yields the highest priority (lowest number)
/// print(taskBuffer.removeFirst()); // Output: 5
/// print(taskBuffer.removeFirst()); // Output: 10
/// ```
///
/// ### Type Parameters:
/// * **[E]**: The type of elements held in the buffer. Must be [Comparable]
///   if no comparator is provided.
///
/// ### See Also:
/// * [AsyncPriorityQueue]: For thread-safe, locked access to this structure.
/// * [QueueList]: For standard FIFO/LIFO arrival-based sequencing.
/// * [Receptor]: The primary consumer of prioritized signal buffers.
class PriorityQueue<E> extends IterableBase<E> {
  /// The underlying cytoplasmic storage (The Binary Heap).
  final _heap = <E>[];

  /// The metabolic criteria used to determine precedence between elements.
  final int Function(E, E)? _comparison;

  /// Creates a [PriorityQueue] with an optional custom [comparison] logic.
  PriorityQueue([int Function(E, E)? comparison]) : _comparison = comparison;

  @override
  int get length => _heap.length;

  @override
  bool get isEmpty => _heap.isEmpty;

  @override
  bool get isNotEmpty => _heap.isNotEmpty;

  /// Ingests a new element into the metabolic hierarchy.
  void add(E element) {
    _heap.add(element);
    _bubbleUp(_heap.length - 1);
  }

  /// Extracts the element with the highest genotypic precedence.
  E removeFirst() {
    if (_heap.isEmpty) throw StateError('Metabolic buffer is empty.');
    if (_heap.length == 1) return _heap.removeLast();

    final result = _heap[0];
    _heap[0] = _heap.removeLast();
    _bubbleDown(0);
    return result;
  }

  /// Retrieves the highest-priority element without removing it.
  @override
  E get first {
    if (_heap.isEmpty) throw StateError('Metabolic buffer is empty.');
    return _heap[0];
  }

  void clear() => _heap.clear();

  /// Internal: Restores heap order by moving a "heavy" element upwards.
  void _bubbleUp(int index) {
    while (index > 0) {
      int parentIndex = (index - 1) ~/ 2;
      if (_compare(_heap[index], _heap[parentIndex]) >= 0) break;
      _swap(index, parentIndex);
      index = parentIndex;
    }
  }

  /// Internal: Restores heap order by moving a "light" element downwards.
  void _bubbleDown(int index) {
    while (true) {
      int leftChild = 2 * index + 1;
      int rightChild = 2 * index + 2;
      int smallest = index;

      if (leftChild < _heap.length &&
          _compare(_heap[leftChild], _heap[smallest]) < 0) {
        smallest = leftChild;
      }
      if (rightChild < _heap.length &&
          _compare(_heap[rightChild], _heap[smallest]) < 0) {
        smallest = rightChild;
      }

      if (smallest == index) break;
      _swap(index, smallest);
      index = smallest;
    }
  }

  /// Internal: Compares two elements using the defined metabolic criteria.
  int _compare(E a, E b) {
    if (_comparison != null) return _comparison(a, b);
    return (a as Comparable).compareTo(b);
  }

  /// Internal: Swaps two elements in the cytoplasmic storage.
  void _swap(int i, int j) {
    final temp = _heap[i];
    _heap[i] = _heap[j];
    _heap[j] = temp;
  }

  // --- Queue Interface Implementation ---

  void addAll(Iterable<E> iterable) => iterable.forEach(add);

  void addFirst(E value) => add(value); // Priority dictates position

  void addLast(E value) => add(value); // Priority dictates position

  E removeLast() {
    // Note: Standard priority queues are optimized for removeFirst.
    // removeLast requires a linear scan of the leaf nodes.
    if (_heap.isEmpty) throw StateError('Metabolic buffer is empty.');
    return _heap.removeLast();
  }

  bool remove(Object? value) {
    final index = _heap.indexOf(value as E);
    if (index == -1) return false;
    if (index == _heap.length - 1) {
      _heap.removeLast();
    } else {
      _heap[index] = _heap.removeLast();
      _bubbleDown(index);
      _bubbleUp(index);
    }
    return true;
  }

  @override
  Iterator<E> get iterator => _heap.iterator;

  @override
  E get last => _heap.last;

  /// Removes all elements from the hierarchy that satisfy the [test] predicate.
  ///
  /// In the reactive framework, this represents a **Structural Buffer Reset**.
  /// Because the [PriorityQueue] relies on a specific binary heap structure
  /// for O(log n) efficiency, removing arbitrary elements requires a full
  /// **Re-heapification** (reconstruction) of the internal storage to ensure
  /// that operational precedence and deterministic priority order are
  /// correctly maintained.
  void removeWhere(bool Function(E element) test) {
    final originalLength = _heap.length;
    _heap.removeWhere(test);

    // If elements were removed, we must re-heapify the entire cytoplasm.
    if (_heap.length != originalLength) {
      _rebuildHeap();
    }
  }

  /// Removes all elements from the hierarchy that fail to satisfy the [test]
  /// predicate.
  void retainWhere(bool Function(E element) test) {
    final originalLength = _heap.length;
    _heap.retainWhere(test);

    // Re-heapify the remaining somatic elements.
    if (_heap.length != originalLength) {
      _rebuildHeap();
    }
  }

  /// Internal: Reconstructs the binary heap structure from scratch (O(n)).
  void _rebuildHeap() {
    if (_heap.isEmpty) return;
    // Start from the last non-leaf node and bubble down.
    for (int i = (_heap.length ~/ 2) - 1; i >= 0; i--) {
      _bubbleDown(i);
    }
  }
}

class AsyncPriorityQueue<E> {
  /// The synchronization pulse (lock) governing access to the queue cytoplasm.
  final _lock = Lock();

  /// The internal, non-thread-safe storage container (The somatic hierarchy).
  final PriorityQueue<E> _queue;

  AsyncPriorityQueue(this._queue);

  /// Retrieves the current length of the somatic hierarchy.
  Future<int> get length => _lock.synchronized(() => _queue.length);

  /// Ingests an element into the hierarchy within a synchronized pulse.
  ///
  /// Position is determined by priority, not arrival order.
  Future<void> add(E element) {
    return _lock.synchronized(() => _queue.add(element));
  }

  /// Removes all elements from the queue, resetting the somatic sequence.
  Future<void> clear() {
    return _lock.synchronized(() => _queue.clear());
  }

  /// Returns a fixed-point [Queue] snapshot (replication) of the current state.
  ///
  /// This is the preferred method for performing long-running iterations
  /// without holding the genotypic lock.
  Future<Queue<E>> replicate() {
    return _lock.synchronized(() => Queue<E>.from(_queue));
  }

  /// Ingests the element into the somatic hierarchy (Alias for [add]).
  ///
  /// Position is determined by metabolic priority.
  Future<void> addLast(E value) => add(value);

  /// Ingests the element into the somatic hierarchy (Alias for [add]).
  ///
  /// Position is determined by metabolic priority.
  Future<void> addFirst(E value) => add(value);

  /// Removes and returns the element with the highest genotypic precedence.
  Future<E> removeFirst() {
    return _lock.synchronized(() => _queue.removeFirst());
  }

  /// Removes and returns the element with the lowest genotypic precedence.
  Future<E> removeLast() {
    return _lock.synchronized(() => _queue.removeLast());
  }

  /// Retrieves the highest-priority element without removing it.
  Future<E> get first => _lock.synchronized(() => _queue.first);

  /// Retrieves the lowest-priority element without removing it.
  Future<E> get last => _lock.synchronized(() => _queue.last);

  /// Checks if the somatic hierarchy contains no elements.
  Future<bool> get isEmpty => _lock.synchronized(() => _queue.isEmpty);

  /// Checks if the somatic hierarchy contains at least one element.
  Future<bool> get isNotEmpty => _lock.synchronized(() => _queue.isNotEmpty);

  /// Injects all elements from [iterable] into the hierarchy.
  Future<void> addAll(Iterable<E> iterable) {
    return _lock.synchronized(() => _queue.addAll(iterable));
  }

  /// Removes a single instance of [value] from the hierarchy.
  ///
  /// Returns `true` if the element was found and removed.
  Future<bool> remove(Object? value) {
    return _lock.synchronized(() => _queue.remove(value));
  }

  /// Evaluates whether the hierarchy contains the specified [element].
  Future<bool> contains(Object? element) {
    return _lock.synchronized(() => _queue.contains(element));
  }

  /// Reduces the hierarchy to a single value by iteratively combining elements.
  Future<E> reduce(E Function(E value, E element) combine) {
    return _lock.synchronized(() => _queue.reduce(combine));
  }

  /// Executes [action] on each element in the somatic hierarchy.
  Future<void> forEach(void Function(E element) action) {
    return _lock.synchronized(() => _queue.forEach(action));
  }

  /// Returns a point-in-time [List] representation of the hierarchy.
  Future<List<E>> toList({bool growable = true}) {
    return _lock.synchronized(() => _queue.toList(growable: growable));
  }

  /// Returns a point-in-time [Set] representation of the hierarchy.
  Future<Set<E>> toSet() {
    return _lock.synchronized(() => _queue.toSet());
  }

  /// Maps each element to a new form, returning a point-in-time [List].
  Future<List<T>> map<T>(T Function(E e) toElement) {
    return _lock.synchronized(() => _queue.map(toElement).toList());
  }
}

/// A thread-safe implementation of a [PriorityQueue], providing **Synchronized
/// Access** for prioritized collection-based state.
///
/// [SyncQueue] serves as a **Concurrency-Safe Execution Buffer** within the
/// reactive fabric. It ensures that signal processing is governed by
/// **Priority Precedence** rather than simple arrival sequence, while maintaining
/// atomic consistency across asynchronous waves and multi-threaded contexts.
///
/// ### When to use
/// - **Signal Prioritization**: Ensuring administrative pulses or system commands
///   jump the queue ahead of standard state updates.
/// - **Task Scheduling**: Orchestrating reactive waves where urgency (e.g.,
///   security validation) outranks arrival time.
/// - **Resource Management**: Using [capacity] constraints to prevent memory
///   bloat in high-frequency dependency graphs.
/// - **Concurrency Safety**: Protecting the internal binary heap from "State
///   Tearing" during simultaneous async mutations.
///
/// ### How it works
/// 1. **Priority Ordering**: Manages an internal [PriorityQueue] (binary heap)
///    to maintain O(log n) efficiency for ranked operations.
/// 2. **Atomic Synchronization**: Wraps all somatic operations in a non-recursive
///    [Lock], ensuring structural integrity during mutations.
/// 3. **Async Interface**: Exposes a [Future]-based API, aligning with the
///    framework's non-blocking concurrency model.
/// 4. **Metabolic Gating**: Enforces the [capacity] limit during [add] and
///    [addAll] operations, throwing a [StateError] if exceeded.
///
/// ### Non‑obvious
/// - **Snapshot Isolation**: Use [replicate] for long-running iterations or
///   mappings to avoid holding the genotypic lock and blocking other actors.
/// - **Traversal Order**: The internal iterator does not guarantee priority
///   order. Use sequential [removeFirst] calls for ranked extraction.
/// - **Bubble Penalty**: Structural repairs after arbitrary removals are O(n);
///   prefer [removeFirst] (O(log n)) for optimal throughput.
/// - **Zero-Blocking**: The underlying lock ensures the calling thread remains
///   available for other tasks while waiting for queue access.
///
/// ### Example
/// ```dart
/// // Higher number = Higher priority
/// final buffer = SyncQueue<int>(
///   comparison: (a, b) => b.compareTo(a),
///   capacity: 100
/// );
///
/// await buffer.add(10);
/// await buffer.add(50);
///
/// // Highest priority (50) comes out first
/// print(await buffer.removeFirst()); // 50
/// ```
///
/// ### Type Parameters:
/// * **[E]**: The type of elements held in the buffer. Must be [Comparable]
///   if no custom comparison function is provided.
///
/// ### See Also:
/// * [PriorityQueue]: The underlying non-synchronized somatic hierarchy.
/// * [Lock]: The mechanism governing synchronized access.
/// * [AsyncPriorityQueue]: For a simpler async wrapper without capacity limits.
class SyncQueue<E> {
  /// The synchronization pulse (lock) governing access to the queue cytoplasm.
  final _lock = Lock();

  /// The internal, non-thread-safe storage container (The somatic hierarchy).
  final PriorityQueue<E> _queue;

  /// The maximum size of the somatic hierarchy. A value of -1 indicates
  /// unlimited metabolic capacity.
  final int capacity;

  /// Creates a [SyncQueue], optionally seeded with a metabolic [capacity].
  ///
  /// The [comparison] function defines the genotypic precedence criteria.
  SyncQueue({int Function(E, E)? comparison, int? capacity})
      : _queue = PriorityQueue(comparison),
        capacity = capacity ?? -1;

  /// Creates a [SyncQueue] by replicating an existing set of [elements].
  SyncQueue.of(Iterable<E> elements,
      {int Function(E, E)? comparison, int? capacity})
      : _queue = PriorityQueue(comparison)..addAll(elements),
        capacity = capacity ?? -1;

  /// Retrieves the current length of the somatic hierarchy.
  Future<int> get length => _lock.synchronized(() => _queue.length);

  /// Ingests an element into the hierarchy within a synchronized pulse.
  ///
  /// Position is determined by priority, not arrival order.
  Future<void> add(E element) {
    return _lock.synchronized(() {
      if (capacity != -1 && _queue.length >= capacity) {
        throw StateError('Metabolic buffer capacity exceeded');
      }
      _queue.add(element);
    });
  }

  /// Removes all elements from the queue, resetting the somatic sequence.
  Future<void> clear() {
    return _lock.synchronized(() => _queue.clear());
  }

  /// Returns a fixed-point [Queue] snapshot (replication) of the current state.
  ///
  /// This is the preferred method for performing long-running iterations
  /// without holding the genotypic lock.
  Future<Queue<E>> replicate() {
    return _lock.synchronized(() => Queue<E>.from(_queue));
  }

  /// Ingests the element into the somatic hierarchy (Alias for [add]).
  ///
  /// Position is determined by metabolic priority.
  Future<void> addLast(E value) => add(value);

  /// Ingests the element into the somatic hierarchy (Alias for [add]).
  ///
  /// Position is determined by metabolic priority.
  Future<void> addFirst(E value) => add(value);

  /// Removes and returns the element with the highest genotypic precedence.
  Future<E> removeFirst() {
    return _lock.synchronized(() => _queue.removeFirst());
  }

  /// Removes and returns the element with the lowest genotypic precedence.
  Future<E> removeLast() {
    return _lock.synchronized(() => _queue.removeLast());
  }

  /// Retrieves the highest-priority element without removing it.
  Future<E> get first => _lock.synchronized(() => _queue.first);

  /// Retrieves the lowest-priority element without removing it.
  Future<E> get last => _lock.synchronized(() => _queue.last);

  /// Checks if the somatic hierarchy contains no elements.
  Future<bool> get isEmpty => _lock.synchronized(() => _queue.isEmpty);

  /// Checks if the somatic hierarchy contains at least one element.
  Future<bool> get isNotEmpty => _lock.synchronized(() => _queue.isNotEmpty);

  /// Injects all elements from [iterable] into the hierarchy.
  Future<void> addAll(Iterable<E> iterable) {
    return _lock.synchronized(() {
      for (final element in iterable) {
        if (capacity != -1 && _queue.length >= capacity) {
          throw StateError('Metabolic buffer capacity exceeded during addAll');
        }
        _queue.add(element);
      }
    });
  }

  /// Removes a single instance of [value] from the hierarchy.
  ///
  /// Returns `true` if the element was found and removed.
  Future<bool> remove(Object? value) {
    return _lock.synchronized(() => _queue.remove(value));
  }

  /// Evaluates whether the hierarchy contains the specified [element].
  Future<bool> contains(Object? element) {
    return _lock.synchronized(() => _queue.contains(element));
  }

  /// Reduces the hierarchy to a single value by iteratively combining elements.
  Future<E> reduce(E Function(E value, E element) combine) {
    return _lock.synchronized(() => _queue.reduce(combine));
  }

  /// Executes [action] on each element in the somatic hierarchy.
  Future<void> forEach(void Function(E element) action) {
    return _lock.synchronized(() => _queue.forEach(action));
  }

  /// Returns a point-in-time [List] representation of the hierarchy.
  Future<List<E>> toList({bool growable = true}) {
    return _lock.synchronized(() => _queue.toList(growable: growable));
  }

  /// Returns a point-in-time [Set] representation of the hierarchy.
  Future<Set<E>> toSet() {
    return _lock.synchronized(() => _queue.toSet());
  }

  /// Maps each element to a new form, returning a point-in-time [List].
  Future<List<T>> map<T>(T Function(E e) toElement) {
    return _lock.synchronized(() => _queue.map(toElement).toList());
  }
}

/// A foundational marker interface and architectural contract representing
/// an **Asynchronous Proxy** or **Controller** for a core component [C].
///
/// In the reactive fabric, [Async] serves as the primary **Concurrency Bridge**,
/// providing a thread-safe, [Future]-based gateway between the synchronous
/// reactive domain and the asynchronous environment (such as the Dart Event Loop
/// or background execution tiers).
///
/// ### When to use
/// - **Contextual Transition**: When you need to interact with synchronous nodes
///   (like [Cell] or [Box]) from within `async` functions or external event handlers.
/// - **Concurrency Safety**: To ensure that state inspection or mutation does not
///   interfere with a "Reactive Wave" currently in progress.
/// - **External Drivers**: When updating reactive state from non-reactive sources,
///   such as network sockets, timers, or user input events.
///
/// ### How it works
/// 1. **Temporal Serialization**: Implementations typically wrap the principal
///    component [C] using a synchronization [Lock]. This ensures that "Out-of-Band"
///    asynchronous requests are queued until the synchronous graph stabilizes.
/// 2. **Logical Linking**: Establishes a strict 1:1 coupling with a synchronous
///    principal. For every `Async<C>`, there is exactly one underlying instance
///     of type [C] that holds the actual state and logic.
/// 3. **Non-Blocking Orchestration**: Unlike the synchronous principal which
///    requires immediate availability, the [Async] handle utilizes [Future]
///    semantics to `await` authority, providing a resilient developer experience
///    under high contention.
///
/// ### Non‑obvious
/// - **Principal Dominance**: The synchronous component [C] remains the "Source
///   of Truth." The [Async] handle is purely an **Access Coordinator**.
/// - **Event Loop Integration**: By returning [Future]s, it allows the Dart VM
///   to perform other tasks while the reactive graph processes a wave, preventing
///   UI jank or thread blocking.
/// - **Locking Latency**: While providing safety, using the [Async] proxy
///   introduces the minor overhead of lock acquisition and asynchronous
///   scheduling compared to direct synchronous access.
///
/// ### Example
/// ```dart
/// // A synchronous ValueCell (The Principal)
/// final count = ValueCell<int>(state: 0);
///
/// // Its asynchronous handle (The Proxy)
/// final Async<ValueCell<int>> controller = count.async;
///
/// void performSafeUpdate() async {
///   // The async handle ensures we wait for graph stability before reading
///   final current = await (controller as ValueCellAsync<int>).state;
///   print('Atomic state: $current');
/// }
/// ```
///
/// ### Type Parameters:
/// * **[C]**: **The Principal Identity.** The type of the core framework
///   component (usually a subtype of [Cell] or [Box]) being managed by
///   this proxy.
///
/// ### See Also:
/// * [Lock]: The underlying primitive used to serialize access.
/// * [Cell.async]: The standard entry point for obtaining an async handle.
/// * [Unmodifiable]: For a different type of proxy focused on read-only access.
abstract class Async<C> {}

/// A specialized **Marker Interface** and architectural anchor used to identify
/// reactive nodes and data structures that have been restricted to **Read-Only**
/// access.
///
/// In the framework's **Deputy Pattern**, [Unmodifiable] serves as the primary
/// indicator that an object is a restricted view of a mutable **Principal**.
/// It enforces data integrity by providing a formal boundary that blocks
/// imperative state changes while preserving reactive continuity.
///
/// ### When to use
/// - **Data Exposure**: When exposing a [ValueCell] or collection to downstream
///   observers (like a UI layer or third-party module) that should not have
///   the authority to trigger updates.
/// - **Ecosystem Consistency**: Used in `cell_tissue` to mark read-only
///   projections of lists, maps, and sets where structural modification is
///   prohibited.
/// - **Security Boundaries**: Defining clear "Principal vs. Deputy" roles
///   within a complex domain model to prevent accidental side-effects.
/// - **Defensive Programming**: Ensuring that specific reactive paths are
///   mathematically guaranteed to be immutable from the perspective of their
///   consumers.
///
/// ### How it works
/// 1. **Capability Gating**: Mutation-heavy methods (such as [Cell.apply] or
///    collection modifiers) are designed to inspect the instance's type. If the
///    instance implements [Unmodifiable], the operation is categorically
///    rejected by the framework's security policy.
/// 2. **Reactive Continuity**: An unmodifiable node remains a fully functional
///    member of the **Directed Acyclic Graph (DAG)**. It will still receive
///    pulses, update its internal state, and notify its own observers when its
///    underlying principal changes.
/// 3. **Proxy Logic**: It acts as a **Behavioral Filter**. The deputy
///    delegates "Read" and "Observe" capabilities to the principal but
///    intercepts and neutralizes "Write" requests.
///
/// ### Non‑obvious
/// - **Identity Transparency (Zero-Copy)**: Most unmodifiable deputies share
///    the exact same physical storage and synchronization [Lock] as their
///    principal. This provides **Zero-Cost Projection** without the memory
///    overhead of data duplication.
/// - **Stateless Marker**: As an abstract marker interface, it adds no
///    runtime object overhead or heap pressure; it serves purely as a
///    type-system hint for the validation and security engines.
/// - **Causal Lineage**: A deputy maintains a transparent link to its
///    principal, ensuring that forensic traces correctly attribute state
///    changes to the original source of authority.
/// - **Not "Deep" Immutability**: Marking a container as [Unmodifiable]
///    restricts the container's own structure but does not necessarily
///    make the objects *inside* the container unmodifiable.
///
/// ### Example
/// ```dart
/// // 1. Create a mutable principal
/// final settings = ValueCell<String>(value: "Active");
///
/// // 2. Project a read-only deputy
/// final publicView = settings.unmodifiable; // Implements Unmodifiable
///
/// // 3. Inspect the gate
/// void process(Cell<String> cell) {
///   if (cell is Unmodifiable) {
///     print("Read-only access: ${cell.state}");
///     // cell.apply(updateCmd); // This would be blocked by the policy engine.
///   }
/// }
/// ```
///
/// ### See Also:
/// * [ValueCell.unmodifiable]: The primary method for creating read-only views.
/// * [Cell.apply]: The mutation gateway that is gated by this interface.
/// * [Async]: For the counterpart interface dealing with concurrency.
abstract class Unmodifiable {}

/// A specialized, lightweight container used to provide a mutable state
/// anchor within the framework's immutable [Record] architecture.
///
/// In the reactive ecosystem, the [Box] is the primary vehicle for
/// **Identity-Preserving State Updates**. While the [Nucleus] and its
/// underlying records are strictly `final` to ensure architectural
/// stability, the [Box] allows the framework to update a cell's
/// internal data without reallocating the entire configuration tree.
///
/// ### When to use
/// - **Flyweight State Management**: Storing volatile state within immutable
///   [Nucleus] records to minimize heap pressure.
/// - **Identity-Preserving Updates**: When you need to evolve a cell's value
///   without changing its structural identity or memory address in the graph.
/// - **Internal Buffer**: Storing intermediate results or transformation
///   context inside a [Receptor].
///
/// ### How it works
/// 1. **Flyweight Segment**: Acts as the minimal "Variable Segment" of a
///    node's footprint. Most of the node's metadata is shared, while the
///    [Box] holds the unique, changing state.
/// 2. **Pointer Stability**: Because the [Box] instance itself is `final`
///    within its containing record, the reactive blueprint remains
///    structurally immutable even as the *content* of the box evolves.
/// 3. **Transformation Bridge**: During a reactive wave, the [Receptor]
///    extracts the current value, applies logic, and writes the result back
///    to the box.
/// 4. **Conactive Gateway**: Provides a [SyncBox] via the [async] property,
///    allowing the same state to be managed safely across asynchronous
///    execution boundaries.
///
/// ### Non‑obvious
/// - **Nullable Flexibility**: A box is designed to hold `null` by default,
///   representing an uninitialized, reset, or transitional state.
/// - **Thread Safety Boundary**: The base [Box] is optimized for
///   high-performance, synchronous execution within a single reactive wave.
///   It is **not** thread-safe; use the [async] property for cross-context
///   mutations.
/// - **Identity Transparency**: Replacing the *value* inside a box does not
///   trigger observer notifications directly—that responsibility lies with
///   the [Cell] or [Nucleus] orchestrating the change.
///
/// ### Example
/// ```dart
/// // 1. Define a state box within an immutable record
/// final metadata = (id: 'counter_01', state: Box<int>(0));
///
/// // 2. Perform identity-preserving mutation
/// void increment(Box<int> box) {
///   box.state = (box.state ?? 0) + 1;
/// }
///
/// // 3. Accessing synchronized proxy for async updates
/// await metadata.state.async.set(100);
/// ```
///
/// ### Parameters:
/// * [value]: **The Initial State.** The starting payload for the container.
///   Defaults to `null`.
///
/// ### See Also:
/// * [FinalBox]: For write-once, late-bound constants.
/// * [SyncBox]: The synchronized proxy for cross-thread access.
/// * [Nucleus]: The blueprint that typically holds these containers.
class Box<T> {
  /// The current state value held by this container.
  T? value;

  /// Creates a [Box] wrapping the provided [value].
  Box([this.value]);

  /// A **Synchronized Proxy** of this box, providing thread-safe,
  /// asynchronous access to the underlying state.
  late final SyncBox<T> async = SyncBox(this);
}

/// A synchronized variant of [Box] providing **Thread-Safe Access** and
/// facilitating **Atomic State Transitions** across concurrent execution boundaries.
///
/// [SyncBox] implements the **Synchronized State Anchor** pattern. While a
/// standard [Box] is optimized for zero-latency, single-threaded propagation
/// within a reactive wave, [SyncBox] is designed for **Conactive Integrity**—ensuring
/// that state remains consistent even when accessed or mutated by multiple
/// asynchronous actors (such as isolates, event loop tasks, or network callbacks).
///
/// ### When to use
/// - **Shared Resources**: Protecting state that is updated from external
///   asynchronous drivers like hardware sensors, sockets, or Bluetooth streams.
/// - **Cross-Context Signals**: Acting as a stable memory bridge when [Pulse]
///   signals originate from background workers or different execution tiers.
/// - **Concurrent Orchestration**: Managing shared configuration in complex
///   system hierarchies where multiple independent agents may read or write
///   simultaneously.
/// - **State Tearing Prevention**: Ensuring that complex payloads are not read
///   while a mutation is partially complete.
///
/// ### How it works
/// 1. **Serialization**: Access to the underlying [Box] is gated by a non-recursive
///    [Lock]. This ensures that only one actor can perform a read or write
///    operation at any given moment.
/// 2. **Visibility Guarantees**: It ensures that once a value is committed, it
///    is immediately visible to all subsequent readers across different execution
///    contexts, maintaining a **Linearizable** state history.
/// 3. **Asynchronous Interface**: All operations return [Future] handles,
///    aligning with the framework's non-blocking concurrency model and signaling
///    a synchronization barrier.
/// 4. **Conactive Bridge**: It serves as the primary gateway for [Async] proxies
///    to interact with a cell's internal cytoplasm safely.
///
/// ### Non‑obvious
/// - **Locking Latency**: While providing safety, the synchronization barrier
///   introduces a minor scheduling delay compared to direct [Box] access. Use
///   the standard [Box] for pure intra-wave reactive transformations.
/// - **Point-in-Time Consistency**: The [state] getter returns the state at
///   the exact moment the lock was acquired, preventing the "Lost Update"
///   problem during high-contention cycles.
/// - **Zero-Blocking**: Because it uses the framework's internal [Lock], the
///   calling thread remains free to handle other event loop tasks while waiting
///   for access, preventing UI jank.
/// - **Principal Coupling**: A [SyncBox] is strictly a proxy; it does not own
///   the state itself but merely coordinates access to its principal [Box].
///
/// ### Example
/// ```dart
/// final sharedBox = Box<int>(0).async; // Returns a SyncBox
///
/// void updateFromNetwork(int newValue) async {
///   // Thread-safe update
///   await sharedBox.set(newValue);
///
///   // Thread-safe read
///   final current = await sharedBox.state;
///   print('Atomic state: $current');
/// }
/// ```
///
/// ### Parameters:
/// * **[T]**: The type of data stored in the box.
///
/// ### See Also:
/// * [Box]: The high-performance, non-synchronized somatic variant.
/// * [FinalBox]: For write-once, late-bound immutable anchors.
/// * [Lock]: The underlying primitive used to serialize access.
class SyncBox<T> {
  final Box<T> _box;

  final Lock _lock = Lock();

  /// Creates a [SyncBox] that acts as a synchronized proxy for the given [_box].
  SyncBox(this._box);

  /// Retrieves the current state asynchronously, ensuring the read is
  /// serialized behind the internal [Lock].
  ///
  /// This ensures that the retrieved state is consistent and not
  /// mid-mutation by a concurrent process.
  Future<T?> get state => _lock.synchronized(() => _box.value);

  /// Sets the current state asynchronously, ensuring the write is
  /// performed within a thread-safe **State Commitment Phase**.
  ///
  /// This method serializes the mutation, preventing race conditions
  /// when multiple asynchronous sources attempt to update the same cell.
  Future<void> set(T? state) async =>
      _lock.synchronized(() => _box.value = state);
}

/// A specialized, write-once container providing a thread-safe, immutable
/// anchor for state that is initialized after construction.
///
/// [FinalBox] implements the **Late-Binding Immutability** pattern, allowing
/// the system to define properties within a [Nucleus] or static configuration
/// as "pending." It ensures that once the value is eventually committed,
/// it remains strictly constant for the remainder of the node's lifecycle.
///
/// ### When to use
/// - **Late-Bound Constants**: When a property within an immutable [Nucleus]
///   or record cannot be determined at instantiation (e.g., unique identifiers,
///   specialized receptor logic).
/// - **Dependency Injection**: Storing upstream [Cell] references that are
///   resolved during the node's activation or **Ingress Gateway** sequence.
/// - **Identity Anchoring**: Holding a unique system-wide identifier or
///   cryptographic hash generated during the first [Pulse] ingestion.
/// - **One-Time Computations**: Wrapping the result of expensive architectural
///   setups that must remain constant for the node's lifecycle.
///
/// ### How it works
/// 1. **Placeholder Integrity**: Provides a stable pointer within an immutable
///    structure while the actual data is pending.
/// 2. **Late-Binding Immutability**: Utilizes Dart's `late final` semantics to
///    allow a single assignment after construction.
/// 3. **State Crystallization**: Once assigned, the value becomes strictly
///    immutable, enforcing a write-once contract.
/// 4. **Hydration Sequence**: Typically initialized during the framework's
///    activation phase, bridging the gap between a stateless blueprint and
///    a crystallized instance.
///
/// ### Non‑obvious
/// - **Flyweight Strategy**: As a final object within a [Nucleus] record, it
///   supports memory-efficient sharing of structural metadata while allowing
///   per-instance constant initialization.
/// - **Runtime Enforcement**: Attempting to re-initialize the box or evolve
///   its value after the first assignment triggers a runtime error, acting
///   as an internal **Integrity Gate**.
/// - **Synchronized Access**: Like a standard box, it provides a [SyncBox]
///   proxy via the [async] property for thread-safe initialization from
///   background tasks.
/// - **Nullable Support**: The internal [value] is nullable by design,
///   allowing the "crystallized" state to be a null constant if required.
///
/// ### Example
/// ```dart
/// // Defined within an immutable nucleus record
/// final config = (id: FinalBox<String>(), category: 'Secure');
///
/// // Initialization (allowed exactly once)
/// config.id.state = 'NODE_7741';
///
/// // Subsequent attempts to modify will throw a LateInitializationError
/// // config.id.state = 'NODE_8888';
/// ```
///
/// ### Parameters
/// (None)
///
/// ### Returns
/// A [FinalBox] instance representing a **Write-Once State Anchor**.
///
/// ### See Also:
/// * [Box]: The standard mutable variant for evolving state.
/// * [SyncBox]: The synchronized proxy for asynchronous initialization.
/// * [Nucleus]: The structural container that typically utilizes boxes for
///   state storage.
class FinalBox<T> implements Box<T> {
  /// The immutable state value held by this container, initialized late.
  @override
  late final T? value;

  /// Creates a [FinalBox] without an initial state. The [value] must be set exactly
  /// once before it is read.
  FinalBox();

  /// A **Synchronized Proxy** of this box, providing thread-safe,
  /// asynchronous access to the underlying state.
  @override
  late final SyncBox<T> async = SyncBox(this);
}

/// Generic function type that takes no parameters and returns RNA.
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
  const FunctionTypeObject(FunctionType<T> functionType)
      : _functionType = functionType;
}

/// Simple wrapper for functions or records containing function information.
/// Used to pass function metadata through the system.
class FunctionObject {
  /// The wrapped function data (could be a function or record)
  final dynamic record;

  /// Creates a FunctionObject containing function data
  const FunctionObject(this.record);
}


/// A robust functional utility for safely executing operations of type [T]
/// with multi-stage recovery logic and hierarchical fallbacks.
///
/// The `get<T>` function implements a **Defensive Execution Pattern**, commonly
/// used in reactive state hydration, configuration parsing, or data
/// transformation within the `cell.core` framework. It provides a structured
/// alternative to deeply nested `try-catch` blocks, ensuring that the system
/// remains resilient even when facing malformed inputs or unexpected
/// imperative side-effects.
///
/// ### Execution Pipeline:
/// This utility follows a strictly prioritized "Primary-Secondary-Static"
/// resolution sequence:
///
/// 1.  **Stage 1: Primary Execution ([fn])**:
///     The function attempts to execute the primary [fn] and cast its result
///     to the expected type [T].
/// 2.  **Stage 2: Secondary Recovery ([fallback])**:
///     If Stage 1 fails (due to a runtime exception or a type-cast error),
///     the utility attempts to execute the [fallback] function. This is
///     ideal for emitting alternative lookup logic or logging the failure.
/// 3.  **Stage 3: Static Default ([orElse])**:
///     If both functional attempts fail (or if the [fallback] throws), the
///     utility attempts to return the provided [orElse] constant.
/// 4.  **Terminal Failure**:
///     If all stages fail and [orElse] is either null or incompatible with
///     type [T], the original exception from Stage 1 is rethrown to ensure
///     visibility of the root cause.
///
/// ### Architectural Use Cases:
/// - **State Hydration**: Attempting to parse a saved JSON value into a
///   cell's internal [Box], with a default "Guest" state if parsing fails.
/// - **Contextual Lookups**: Searching for a value in a local [Context],
///   falling back to a global `Context.system` lookup.
/// - **Dynamic Typing**: Safely casting `dynamic` records into specific
///   reactive descriptors.
///
/// ### Parameters:
/// - [fn]: The primary [Function] to execute. It should return a value
///   compatible with type [T].
/// - [fallback]: An optional recovery [Function] emitted only if [fn]
///   encounters an error.
/// - [orElse]: A static value of type [T] to return as the ultimate
///   safety net if all functional calls fail.
///
/// ### Example: Safe Configuration Parsing
/// ```dart
/// final timeout = get<int>(
///   () => int.parse(remoteConfig['timeout']),
///   fallback: () => localSettings.defaultTimeout,
///   orElse: 3000,
/// );
/// ```
///
/// ### Type Parameters:
/// * [T]: The expected return type of the operation.
T get<T>(Function fn, {Function? fallback, T? orElse}) {
  try {
    return fn() as T;
  } catch (e) {
    try {
      if (fallback != null) return fallback() as T;
    } catch (_) {}
    try {
      return orElse as T;
    } catch (_) {
      throw e;
    }
  }
}

/*
/// A JSON converter for [Symbol] objects.
class SymbolConverter implements JsonConverter<Symbol, String> {

  /// Creates a [SymbolConverter] instance.
  const SymbolConverter();

  /// Deserializes a [Symbol] from its JSON string representation.
  @override
  Symbol fromJson(String json) => Symbol(json);

  @override
  String toJson(Symbol symbol) => symbol.toString().replaceFirst('Symbol("', '').replaceFirst('")', '');

}
*/
