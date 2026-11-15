// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// # cell_mind — Cognitive policy for the Cell framework
///
/// `cell_mind` turns `cell`'s typed governance metadata — `Context`,
/// `Mandate`, `Provenance`, `Ontology` — into autonomous runtime
/// decisions, and closes the loop by allowing decisions to accumulate
/// back into `Context` via offline learning.
///
/// ## What `cell_mind` provides
///
/// - **Context-aware policies** — `TestCell` factories that read the
///   cell's Context to decide what pulses and commands it accepts.
/// - **Decision log** — every accept/reject/defer is recorded with the
///   Context version active at decision time. Replayable, auditable.
/// - **Context accumulation** — offline trainers produce evolved
///   Contexts whose `Ontology.constraints['cell_mind.policy']` carries
///   learned rules.
///
/// ## Status
///
/// `0.1.0-dev` — Phase 0 (Foundations). No public API yet.
///
/// ## Layer contract
///
/// **The Context decides, the policy enforces, the log records.**
/// `cell_mind` is the layer that turns a cell's `Context` into runtime
/// behaviour, records every decision, and learns from outcomes. It does
/// not own the reactive pipeline (that is `cell`), the relational mesh
/// (that is `cell_organ`), or the decision logic (that is `cell_flow`).
///
/// {@category Core}
/// {@category Policy}
// ignore: unnecessary_library_name
library cell_mind;

import 'dart:async';
import 'dart:collection';

import 'package:cell_tissue/cell_tissue.dart';

export 'package:cell/cell.dart';
export 'package:cell_tissue/cell_tissue.dart';

part 'src/internal/macros.dart';
part 'src/internal/verdicts.dart';
part 'src/internal/policy_helpers.dart';
part 'src/policy.dart';
part 'src/internal/decisions.dart';
part 'src/internal/recording_test_cell.dart';
part 'src/runtime.dart';
part 'src/outcomes.dart';
part 'src/learning.dart';
part 'src/approval.dart';
part 'src/bridge.dart';
part 'src/xai.dart';
part 'src/agent.dart';
part 'src/internal/context_vector.dart';
part 'src/internal/policy_block.dart';
part 'src/internal/bandit.dart';
part 'src/internal/bridge_effects.dart';
part 'src/internal/buffered_chunks.dart';
part 'src/internal/narrative.dart';
part 'src/internal/debate_effects.dart';
