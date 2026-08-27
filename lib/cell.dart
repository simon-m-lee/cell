// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

/// Cell — reactive state for Dart.
///
/// A **cell** holds a value. A **pulse** is the immutable message that moves a
/// change. Operators (`Cell.state`, `Cell.observe`, …) wire cells together.
///
/// [Receptor], [TestCell], [Context], and [Synapses] are optional. Defaults are
/// pass-through. Nothing is authorized or redacted unless you pass a rule.
///
/// Alpha. Operator lists and guide names have moved; treat this comment as the
/// learning order, not a stability guarantee.
///
/// ## Learning order
///
/// Get data in → hold state → react → shape streams → go async → combine →
/// isolate writes.
///
/// | # | Factory | Use when |
/// |---|---------|----------|
/// | 1 | [Cell.state] | Persistent mutable state |
/// | 2 | [Cell.ingress] | Manual `emit` / `ingest` |
/// | 3 | [Cell.observe] | Side effects; `start` / `stop` |
/// | 4 | [Cell.derive] | Projection of one source |
/// | 5 | [Cell.debounce] | Emit after silence |
/// | 6 | [Cell.merge] | Fan-in |
/// | 7 | [Cell.distinct] | Skip equal consecutive values |
/// | 8 | [Cell.throttle] | Rate limit |
/// | 9 | [Cell.synthesis] | Aggregate several sources |
/// | 10 | [Cell.asyncMap] | Async map (`concurrency`, `latestOnly`) |
/// | 11 | [Cell.hub] | Route by pulse type |
/// | 12 | [Cell.switchMap] | Follow the latest inner cell |
/// | 13 | [Cell.fromFuture] / [Cell.fromStream] | Bridge `dart:async` |
/// | 14 | [Cell.sanitized] | Redact before egress |
/// | 15 | [Cell.open] | Manual topology |
/// | 16 | [Cell.transaction] | Multi-cell buffered writes |
/// | 17 | [Cell.txApply] | Staged `apply` + compensation |
///
/// Each works with zero knowledge of [Receptor], [TestCell], [Context], or
/// [Synapses] — all optional, all defaulted. They represent the
/// **Standard Entry Point**, allowing you to build complex reactive systems
/// by connecting simple building blocks. While you focus on your logic, the
/// framework automatically manages the input (Ingress), logic (Transformation),
/// and notifications (Egress), handling all security checks and verification
/// steps in the background.
///
/// 1–4 are enough for a first app. 16–17 are the unusual part: commit-time
/// locks, isolation, savepoints, compensation. See the Advanced topic in
/// generated docs.
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
/// {@category Getting Started}
/// {@category Core 16 Operators}
// ignore: unnecessary_library_name
library cell;

import 'dart:async';
import 'dart:collection';
import 'dart:core';

import 'package:cell/src/internal/commons.dart';

import 'package:uuid/uuid.dart';

import 'package:synchronized/synchronized.dart';
export 'package:synchronized/synchronized.dart';

import 'src/test_rule.dart';
export 'src/test_rule.dart';

export 'src/internal/commons.dart';

export 'src/test_rule_meta.dart';

part 'src/cell.dart';
part 'src/deputy.dart';
part 'src/pulse.dart';
part 'src/receptor.dart';
part 'src/synapses.dart';
part 'src/nucleus.dart';
part 'src/test_cell.dart';
part 'src/value.dart';
part 'src/context.dart';

//

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

part 'src/internal/operator/operators.dart';
part 'src/internal/operator/operator_async_map.dart';
part 'src/internal/operator/operator_throttle.dart';
part 'src/internal/operator/operator_debounce.dart';
part 'src/internal/operator/operator_transaction.dart';
part 'src/internal/operator/operator_hub.dart';
part 'src/internal/operator/operator_tx_apply.dart';

