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
/// of `package:cell_flow`.
///
/// This library is not imported by application code.
// ignore: unnecessary_library_name
library cell_flow_ai_anti_patterns;

/// Shared **anti-pattern templates** for the `### AI Agent Guide` blocks.
///
/// This class exists only to give dartdoc a public anchor for the
/// `{@template}` / `{@macro}` definitions below; it has no runtime behavior.
///
/// {@template ai-do-not-put-time-op-as-policy}
/// **DON'T** use a Time operator (`Debounce`, `Throttle`, `Delay`) as the
/// policy gate. Time operators shape feeds (belt chatter, search boxes);
/// the decision belongs in a `FlowInstructionBase` subclass.
/// See `HowTo-Mitose-Flow.md` §3.6 "Time".
/// {@endtemplate}
///
/// {@template ai-do-not-write-tissue-from-instruction}
/// **DON'T** write a Tissue book inside a `FlowInstructionBase` subclass.
/// The instruction decides; the chain assembles; the observer glues.
/// See `HowTo-Mitose-Flow.md` §5 "Mix-and-match rules".
/// {@endtemplate}
///
/// {@template ai-do-not-put-flatten-in-risko}
/// **DON'T** put flatten operators (`concatMap`, `mergeMap`, `switchMap`,
/// `exhaustMap`) *inside* `riskOf`. Flatten wraps I/O after or beside the
/// decision.
/// See `HowTo-Mitose-Flow.md` §3.4 "Flatten (inner sequences)".
/// {@endtemplate}
///
/// {@template ai-do-not-tap-tissue-on-decision-chain}
/// **DON'T** use `Tap` to write Tissue on a Cell-variant decision chain.
/// Tissue writes happen in `Cell.observe` (or a harness method it calls).
/// Tap is legal on Tissue-sibling / card-auth stock chains only.
/// See `HowTo-Mitose-Flow.md` §3.7 "Collect / control".
/// {@endtemplate}
///
/// {@template ai-do-not-stock-distinct-when-reset-needed}
/// **DON'T** use stock `Distinct` when an ACK must clear the latch —
/// stock Distinct has no `reset()`. That is the usual reason for a
/// custom `FlowInstructionBase`.
/// See `HowTo-Mitose-Flow.md` §3.3 "Filter / take / skip".
/// {@endtemplate}
///
/// {@template ai-do-not-tohandle-twice-per-product}
/// **DON'T** call `toHandle` more than once per product, and never from an
/// ACK observer. One `toHandle(source: tickIn.cell)` per product, only in
/// `installGates()`. ACK calls `instruction.reset()`.
/// See `HowTo-Mitose-Flow.md` §1 and §4.
/// {@endtemplate}
///
/// {@template ai-do-not-invent-flow-operators}
/// `Flow.blocking`, `Flow.complete`, `Flow.dispose` **do not exist**.
/// The full public catalog is in `FEATURES-Flow.md` and
/// `HowTo-Mitose-Flow.md` §3.
/// {@endtemplate}
class AiAntiPatterns {}
