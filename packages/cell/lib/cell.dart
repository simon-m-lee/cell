// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Cell — reactive state for Dart.
///
/// A **cell** holds a value. A **pulse** is the immutable message that moves a
/// change. Operators (`Cell.state`, `Cell.observe`, …) wire cells together.
///
/// [Receptor], [TestCell], [Context], and [Synapses] are optional. Defaults are
/// pass-through. Nothing is authorized or redacted unless you pass a rule.
///
/// ## Learning order
///
/// Get data in → hold state → react → shape streams → go async → combine →
/// isolate writes.
///
/// ### 🟢 Group 1: Essential (Foundation)
/// | Operator | Use when |
/// |---|----------|
/// | [Cell.state] | Persistent mutable state atoms |
/// | [Cell.ingress] | Manual entry points for external events |
/// | [Cell.derive] | Pure transformations and projections |
/// | [Cell.observe] | Side effects and reactive termination |
///
/// ### 🟡 Group 2: Intermediate (Flow Control)
/// | Operator | Use when |
/// |---|----------|
/// | [Cell.debounce] | Emit only after a period of silence |
/// | [Cell.distinct] | Skip equal consecutive values |
/// | [Cell.throttle] | Rate limit signal propagation |
/// | [Cell.synthesis] | Aggregate multiple cells into one |
///
/// ### 🔵 Group 3: Advanced (Async & Composition)
/// | Operator | Use when |
/// |---|----------|
/// | [Cell.asyncMap] | Concurrency-controlled async logic |
/// | [Cell.switchMap] | Reactively follow the latest inner cell |
/// | [Cell.fromFuture] / [Cell.fromStream] | Bridge standard `dart:async` types |
///
/// ### 🔴 Group 4: Expert (Governance & Topology)
/// | Operator | Use when |
/// |---|----------|
/// | [Cell.hub] | Semantic routing based on signal types |
/// | [Cell.sanitized] | PII redaction and security boundaries |
/// | [Cell.open] | Late binding and manual topology control |
///
/// ### 🟣 Atomic Orchestration (Atomic)
/// | Operator | Use when |
/// |---|----------|
/// | [Cell.transaction] | Multi-cell atomic state transitions |
/// | [Cell.txApply] | Staged execution with compensation/rollback |
///
/// Each works with zero knowledge of [Receptor], [TestCell], [Context], or
/// [Synapses] — all optional, all defaulted. They represent the
/// **Standard Entry Point**, allowing you to build complex reactive systems
/// by connecting simple building blocks. While you focus on your logic, the
/// framework automatically manages the input (Ingress), logic (Transformation),
/// and notifications (Egress), handling all security checks and verification
/// steps in the background.
///
/// Groups 1–2 are enough for most applications. Group 4 and the Atomic tier
/// handle complex orchestration: semantic routing, security boundaries, and
/// transactional rollbacks. See the `Advanced` topic in generated docs.
///
/// ## Transactions
///
/// [Cell.transaction] buffers `update`/`read` and applies them together.
/// Locks are taken at **commit**, not for the whole `begin`…`commit` window.
///
/// [Cell.txApply] stages `cell.apply(fn, tx: tx, compensate: undo)`. It is not
/// a second syntax for assigning `value`.
///
/// ## Governance (opt-in)
///
/// [Context], [DeputyContext], [PulseContext], [EphemeralPolicy], and
/// [PulseEphemeralPolicy] record who / why / how and can enforce TTL or
/// clearance **if** a [TestCell] (or deputy) actually denies the operation.
///
/// [Context.describe] stores a description. It is not a legal basis, a
/// retention schedule, or an audit log.
///
/// Guides live in `guide/` (`HowTo-Start.md`, `HowTo-Transaction.md`, …).
///
/// {@category Features}
// ignore: unnecessary_library_name
library cell;

import 'dart:async';
import 'dart:collection';
import 'dart:core';

import 'package:cell/src/internal/commons.dart';

import 'package:uuid/uuid.dart';

import 'package:synchronized/synchronized.dart';
export 'package:synchronized/synchronized.dart';

// --- Public APIs and Utilities ---

/// Standard test rules and base meta-data for governance.
import 'src/test_rule.dart';
export 'src/test_rule.dart';

export 'src/test_rule_meta.dart';

/// Fluent API extensions for [Pulse].
/// These provide .map(), .attach(), and .batch() for a more functional
/// development experience.
export 'src/internal/pulse_extensions.dart';

// --- Internal Implementation Details ---

/// Common internal utilities used across the cell framework.
export 'src/internal/commons.dart';

// --- Part definitions for the core Cell architecture ---

/// Core abstractions and public interfaces.
part 'src/cell.dart';
part 'src/deputy.dart';
part 'src/pulse.dart';
part 'src/receptor.dart';
part 'src/synapses.dart';
part 'src/nucleus.dart';
part 'src/test_cell.dart';
part 'src/value.dart';
part 'src/context.dart';

/// Private implementations and internal management logic.
/// These files contain the logic that powers the public interfaces defined above.
part 'src/internal/cell.dart';
part 'src/internal/cell_policy.dart';
part 'src/internal/deputy.dart';
part 'src/internal/deputy_context.dart';
part 'src/internal/pulse.dart';
part 'src/internal/pulse_policy.dart';
part 'src/internal/pulse_context.dart';
part 'src/internal/receptor.dart';
part 'src/internal/synapses.dart';
part 'src/internal/nucleus.dart';
part 'src/internal/test_cell.dart';
part 'src/internal/value.dart';
part 'src/internal/context.dart';

/// Operator-specific implementations.
/// Each operator encapsulates a specific reactive behavior (e.g., throttling, debouncing).
part 'src/internal/operator/operators.dart';
part 'src/internal/operator/operator_async_map.dart';
part 'src/internal/operator/operator_throttle.dart';
part 'src/internal/operator/operator_debounce.dart';
part 'src/internal/operator/operator_transaction.dart';
part 'src/internal/operator/operator_hub.dart';
part 'src/internal/operator/operator_tx_apply.dart';

