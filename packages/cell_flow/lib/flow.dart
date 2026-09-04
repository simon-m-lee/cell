// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

// ignore_for_file: unnecessary_library_name


/// A high-performance reactive orchestration layer for the Cell framework (codename **Mitosis**).
///
/// `cell_flow` extends the core atomicity of `package:cell` by providing a
/// sophisticated suite of operators designed for complex data-flow
/// transformations, temporal logic, and asynchronous coordination.
///
/// ### The Mitosis Architecture
/// While the core `Cell` library handles state and synchronous pulse
/// propagation, **Mitosis** (cell_flow) provides the machinery for:
/// * **Transformation**: Reshaping data as it traverses the graph via
///   operators like [map], [scan], and [buffer].
/// * **Temporal Control**: Managing the dimension of time using
///   [debounce], [throttle], [delay], and [interval].
/// * **Asynchronous Bridging**: Safely integrating [Future] and [Stream]
///   workloads into the synchronous graph via [asyncMap] and [switchMap].
/// * **Topological Routing**: Multiplexing and demultiplexing pulses
///   through [groupBy], [partition], and [window].
///
/// ### Core Mechanics
/// 1. **Unified Graph**: Unlike traditional Rx wrappers, `cell_flow`
///    instructions are compiled directly into the underlying Cell graph.
///    There is no "translation" overhead; a [FlowHandle] is a first-class
///    citizen of the reactive topography.
/// 2. **Instruction-Based Composition**: At its heart, the library uses
///    [FlowInstruction] objects. These can be chained using the `+`
///    operator to create reusable "Gate" definitions or "Receptors"
///    independent of specific source cells.
/// 3. **Fluent API**: For rapid development, the library provides
///    comprehensive extensions on [Cell] and [FlowHandle], allowing for
///    a declarative, chainable syntax similar to RxDart.
///
/// ### Usage Paradigms
///
/// **The Fluent Path (Quick Orchestration):**
/// ```dart
/// final results = searchInput.cell
///     .filter((q) => q.length > 2)
///     .debounce(duration: const Duration(milliseconds: 300))
///     .asyncMap((q) => api.fetch(q))
///     .share();
/// ```
///
/// **The Instruction Path (Reusable Gates):**
/// ```dart
/// // Define a reusable logic gate
/// final validationGate = MapValue<String, String>((s) => s.trim()) +
///     Filter<String>((s) => s.isNotEmpty) +
///     Distinct<String>();
///
/// // Apply the gate to any source
/// final handle = validationGate.toHandle(source: myCell);
/// ```
///
/// ### Resource Management
/// Operators in `cell_flow` automatically manage their internal state and
/// subscriptions. When a [FlowHandle] is disposed, the underlying
/// orchestration graph is pruned to prevent memory leaks and
/// unnecessary computations.
///
/// ### Further Reading
/// * `ARCHITECTURE-Flow.md`: Theoretical foundations of the Mitosis layer.
/// * `FEATURES-Flow.md`: Detailed catalog of every available operator.
/// * `HowTo-Fluent_Operator.md`: Best practices for method-chaining.
/// * `HowTo-FlowInstruction-Receptor.md`: Advanced custom gate composition.
library cell_flow;

import 'dart:async';

import 'package:cell/cell.dart';

export 'package:cell/cell.dart';

// ── Create ────────────────────────────────────────────────────
import 'package:cell_flow/src/instruction/of.dart';
import 'package:cell_flow/src/instruction/from_future.dart';
import 'package:cell_flow/src/instruction/from_stream.dart';

// ── Transform ─────────────────────────────────────────────────
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_flow/src/instruction/pluck.dart';
import 'package:cell_flow/src/instruction/scan.dart';
import 'package:cell_flow/src/instruction/reduce.dart';
import 'package:cell_flow/src/instruction/pairwise.dart';

// ── Async transform ───────────────────────────────────────────
import 'package:cell_flow/src/instruction/async_map.dart';
import 'package:cell_flow/src/instruction/async_fold.dart';
import 'package:cell_flow/src/instruction/async_expand.dart';

// ── Filter / take / skip / distinct ───────────────────────────
import 'package:cell_flow/src/instruction/filter.dart' hide Distinct, Debounce, Throttle;
import 'package:cell_flow/src/instruction/distinct.dart';
import 'package:cell_flow/src/instruction/take.dart' hide TakeWhile, Take;
import 'package:cell_flow/src/instruction/skip.dart' hide Skip, SkipWhile;

// ── Flatten ───────────────────────────────────────────────────
import 'package:cell_flow/src/instruction/concat.dart';
import 'package:cell_flow/src/instruction/concat_map.dart' hide ConcatAll;
import 'package:cell_flow/src/instruction/merge_map.dart';
import 'package:cell_flow/src/instruction/switch_map.dart';
import 'package:cell_flow/src/instruction/exhaust_map.dart';

// ── Combine ───────────────────────────────────────────────────
import 'package:cell_flow/src/instruction/merge.dart';
import 'package:cell_flow/src/instruction/zip.dart';
import 'package:cell_flow/src/instruction/combine_latest.dart';
import 'package:cell_flow/src/instruction/race.dart';

// ── Time ──────────────────────────────────────────────────────
import 'package:cell_flow/src/instruction/delay.dart';
import 'package:cell_flow/src/instruction/debounce.dart' hide SampleTime, AuditTime;
import 'package:cell_flow/src/instruction/throttle.dart';
import 'package:cell_flow/src/instruction/sample.dart';
import 'package:cell_flow/src/instruction/interval.dart';
import 'package:cell_flow/src/instruction/timeout.dart';

// ── Collect / route ───────────────────────────────────────────
import 'package:cell_flow/src/instruction/buffer.dart';
import 'package:cell_flow/src/instruction/window.dart';
import 'package:cell_flow/src/instruction/group_by.dart';
import 'package:cell_flow/src/instruction/partition.dart';
import 'package:cell_flow/src/instruction/routing.dart';

// ── Control / multicast / side effect ─────────────────────────
import 'package:cell_flow/src/instruction/start_with.dart';
import 'package:cell_flow/src/instruction/share.dart';
import 'package:cell_flow/src/instruction/retry.dart';
import 'package:cell_flow/src/instruction/tap.dart';

// ── Facade, instruction core, fluent extensions ───────────────
part 'src/flow.dart';
part 'src/flow_core.dart';
part 'src/fluent_operator.dart';
