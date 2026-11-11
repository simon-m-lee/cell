// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// This file is documentation only: it is not imported by application code.
// It exists solely for dartdoc `{@template}` / `{@macro}` expansion used by
// the `### AI Agent Guide` blocks in public doc comments.
//
// Convention: CONTRIBUTING-AI-DOC.md. Do not import this library.

/// Doc-only library holding the shared `{@template}` dartdoc definitions
/// expanded by the `{@macro}` references in the `### AI Agent Guide` blocks
/// of `package:cell`.
///
/// This library is not imported by application code.
// ignore: unnecessary_library_name
library cell_ai_anti_patterns;

/// Shared **anti-pattern templates** for the `### AI Agent Guide` blocks.
///
/// This class exists only to give dartdoc a public anchor for the
/// `{@template}` / `{@macro}` definitions below; it has no runtime behavior.
///
/// {@template ai-do-not-create-cell-as-policy}
/// **DON'T** create a custom Cell type to encode business policy.
/// Policy belongs in a `FlowInstructionBase` subclass in `cell_flow`,
/// not in a Cell receptor.
/// See `HowTo-Mitose-Flow.md` §4 "When the BRD requires a custom FlowInstruction".
/// {@endtemplate}
///
/// {@template ai-do-not-create-cell-to-hold-a-collection}
/// **DON'T** use `Cell.state<List<E>>` as a system of record.
/// Use `TissueList<E>` from `cell_tissue`.
/// See `HowTo-Mitose-Tissue.md` §2.1 "TissueList — the audit book".
/// {@endtemplate}
///
/// {@template ai-do-not-observe-to-decide}
/// **DON'T** put business logic in `Cell.observe`'s `effect`.
/// `effect` may write Tissue books, call `reset()`, enqueue pumps, print.
/// It may **not** call `riskOf`, change `pass`, or call `toHandle`.
/// See `HowTo-Mitose-Cell.md` §3.2 "Cell.observe — the only Flow → Tissue glue".
/// {@endtemplate}
///
/// {@template ai-do-not-testcell-on-tissue}
/// **DON'T** put `testRule: TestCell` on any `TissueList` / `TissueMap` /
/// `TissueSet` / `TissueQueue` / `TissueValue` constructor. Use `TestTissue`.
/// This is grep-checked by the `constraint` group in `<stem>-test.dart`.
/// {@endtemplate}
///
/// {@template ai-do-not-write-tissue-from-instruction}
/// **DON'T** write a Tissue book inside a `FlowInstructionBase` subclass.
/// The instruction decides; the chain assembles; the observer glues.
/// See `HowTo-Mitose-Flow.md` §5 "Mix-and-match rules".
/// {@endtemplate}
///
/// {@template ai-do-not-invent-cell-factories}
/// `Cell.gate`, `Cell.book`, `Cell.policy`, `Cell.pipeline` **do not exist**.
/// The full public factory list is in `HowTo-Mitose-Cell.md` §2.
/// {@endtemplate}
///
/// {@template ai-do-not-treat-ack-as-decision}
/// **DON'T** call `toHandle` from an ACK observer. ACK calls `instruction.reset()`.
/// See `HowTo-Mitose-Flow.md` §4 "Public API the Demo must expose".
/// {@endtemplate}
///
/// {@template ai-do-not-use-cell-transaction-for-tissue}
/// **DON'T** wrap a Tissue write in `Cell.transaction`. Mitose commits with
/// `Cell.txApply` on Tissue books. `Cell.transaction` coordinates `ValueCell`.
/// See `HowTo-Mitose-Cell.md` §3.3 "Cell.transaction — not the Mitose commit".
/// {@endtemplate}
class AiAntiPatterns {}
