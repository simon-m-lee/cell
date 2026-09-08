// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

/// # cell_tissue – Reactive Collections for the Cell Framework
///
/// The `cell_tissue` library brings the full power of reactive governance to
/// Dart collections. It provides lists, sets, maps, queues, and single‑value
/// containers that are **observable**, **validated**, **thread‑safe**, and
/// **deputisable** – just like the core [Cell]s they’re built on.
///
/// ### Where to start
/// Most of the time, you’ll reach for one of these concrete collection types:
/// * [TissueList] – an ordered, indexable list.
/// * [TissueSet] – a unique‑element set.
/// * [TissueMap] – a key‑value store.
/// * [TissueQueue] – a double‑ended FIFO/LIFO buffer.
/// * [TissueValue] – a single, reactive scalar value.
///
/// Each of these behaves like its standard Dart counterpart – you can `add`,
/// `remove`, iterate, and use familiar collection methods – but every mutation
/// is automatically validated, emits a reactive event, and is synchronised
/// through a thread‑safe lock.
///
/// ### When to use
/// Use a `Tissue` collection whenever you need:
/// - **Observability**: UI components or other cells that need to react to
///   changes in the collection.
/// - **Validation**: Business rules that must be enforced on every mutation
///   (e.g., positive numbers, non‑empty strings, max size).
/// - **Security**: Sharing a collection with read‑only views ([Tissue.unmodifiable])
///   or restricted proxies ([Tissue.deputy]) without copying data.
/// - **Concurrency**: Thread‑safe updates from multiple isolates or event
///   handlers.
/// - **Auditability**: A complete causal trace of every change, with
///   provenance metadata.
///
/// ### How it works
/// Under the hood, every `Tissue` is a [Cell] that holds a physical container
/// (e.g., a `List`, `Set`, `Map`, or `Queue`) and a [TissueNucleus] – an
/// immutable blueprint that defines the collection’s validation rules,
/// transformation logic, and propagation behaviour.
///
/// When you mutate a tissue (e.g., `list.add(42)`), the operation:
/// 1. Passes through the [TestTissue] validation gate.
/// 2. Is applied atomically to the physical storage.
/// 3. Emits a [TissueEvent] (e.g., `ElementAddedEvent`).
/// 4. Propagates the event through the collection’s [Synapses] to all
///    downstream observers.
///
/// This is the same reactive pipeline you know from [Cell], extended to
/// collections.
///
/// ### Non‑obvious
/// - **Deputies are zero‑copy**: Calling `.deputy()` or `.unmodifiable` on a
///   tissue creates a new view that shares the **same** physical storage.
///   No data is duplicated – changes to the source are immediately visible
///   through the view.
/// - **Unmodifiable is live**: Unlike `List.unmodifiable()` in Dart, the view
///   returned by `.unmodifiable` is **not a snapshot**. It stays in sync with
///   the source indefinitely.
/// - **Deep immutability**: If you set `unmodifiableElement: true` (the
///   default), any child [Cell] elements are automatically projected as their
///   `.unmodifiable` deputies, preventing “side‑door” mutations.
/// - **Validation per element**: When you add multiple elements (e.g., via
///   `addAll`), each element is validated individually. Invalid elements are
///   silently skipped – they do **not** cause the entire operation to fail.
/// - **Initial population is silent**: When you create a tissue with initial
///   elements (e.g., `TissueList([1, 2, 3])`), no [TissueEvent] is emitted.
///   Observers only see events for mutations that happen *after* creation.
/// - **Bounded queues**: For [TissueQueue], setting a `capacity` creates a
///   circular buffer – when the queue is full, adding a new element drops the
///   oldest one silently.
///
/// ### Example: A validated task list
/// ```dart
/// final tasks = TissueList<Task>(
///   testRule: TestTissue<Task, TissueList<Task>>(
///     (task, {host, action, user}) => task.title.isNotEmpty,
///   ),
/// );
///
/// // Observe additions
/// tasks.listen((event) {
///   if (event is ElementAddedEvent<Task>) {
///     print('Added: ${event.payload.title}');
///   }
/// });
///
/// tasks.add(Task('Buy milk')); // passes validation → event fires
/// tasks.add(Task(''));          // rejected by validation → no event
/// ```
///
/// ### Example: A read‑only view for UI
/// ```dart
/// final source = TissueList<String>(['A', 'B', 'C']);
/// final readOnly = source.unmodifiable;
///
/// // Pass readOnly to a widget – it's safe to read, but cannot be mutated.
/// source.add('D');
/// print(readOnly.length); // 4 – the view is live!
/// ```
///
/// ### Next steps
/// - For a deep dive into a specific collection type, see [TissueList],
///   [TissueSet], [TissueMap], [TissueQueue], or [TissueValue].
/// - To understand how validation works, read [TestTissue].
/// - To customise mutation processing, explore [TissueReceptor].
/// - For propagation control (debounce, throttle, batching), see [Synapses].
///
/// {@category Core}
// ignore: unnecessary_library_name
library cell_tissue;

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:cell/cell.dart';
export 'package:cell/cell.dart';

part 'src/tissue.dart';
part 'src/tissue_nucleus.dart';
part 'src/tissue_container.dart';
part 'src/tissue_event.dart';
part 'src/tissue_receptor.dart';
part 'src/tissue_set.dart';
part 'src/tissue_list.dart';
part 'src/tissue_queue.dart';
part 'src/tissue_value.dart';
part 'src/tissue_map.dart';
part 'src/test_tissue.dart';

part 'src/internal/tissue.dart';
part 'src/internal/tissue_nucleus.dart';
part 'src/internal/tissue_container.dart';
part 'src/internal/tissue_event.dart';
part 'src/internal/tissue_receptor.dart';
part 'src/internal/tissue_set.dart';
part 'src/internal/tissue_list.dart';
part 'src/internal/tissue_queue.dart';
part 'src/internal/tissue_value.dart';
part 'src/internal/tissue_map.dart';
part 'src/internal/test_tissue.dart';