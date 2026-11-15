// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

// Shared `{@template}` blocks. Referenced from every public type in
// `cell_mind`. See `guide/10-Design-Notes.md` for the full rationale.

/// **Do not create a policy that reads from a network or clock
/// without a journal.**
///
/// {@template ai-do-not-policy-without-journal}
/// **Do not create a policy that reads from a network or clock without
/// a journal.** Policies are `TestCell`s — stateless and deterministic
/// by contract. If the decision requires external state (time, network,
/// database), the observation must be journaled. Otherwise the decision
/// is not replayable, which breaks the framework's audit guarantees.
/// {@endtemplate}

/// **Do not store learned policy outside `Ontology.constraints`.**
///
/// {@template ai-do-not-store-learned-policy-elsewhere}
/// **Do not store learned policy outside `Ontology.constraints`.**
/// The learned block belongs at `Ontology.constraints['cell_mind.policy']`
/// so it participates in the framework's attenuation contract, diffable
/// audit trail, and replay machinery. Custom stores (TissueMap,
/// side files) lose all three.
/// {@endtemplate}

/// **Do not train online.**
///
/// {@template ai-do-not-train-online}
/// **Do not train online.** Learning is offline and batch-only. The
/// decision log feeds the trainer; the trainer produces an evolved
/// Context; the runtime deploys the new Context. No in-band gradient
/// descent, no online updates. Determinism preserved.
/// {@endtemplate}

/// **Do not confuse `Context` with a policy.**
///
/// {@template ai-do-not-confuse-context-with-policy}
/// **Do not confuse `Context` with a policy.** A `Context` is the
/// *state* a cell carries. A `Policy` is the *function* that reads the
/// Context and returns a verdict. `cell_mind` composes them via
/// `TestCell` — the Context is data, the policy is code.
/// {@endtemplate}

/// **Do not make a policy permissive by default.**
///
/// {@template ai-do-not-default-permissive}
/// **Do not make a policy permissive by default.** Missing metadata
/// rejects (P4 — fail closed). Every opt-out is an explicit named flag
/// (`allowMissing`, `allowUntagged`) that the caller must choose. A
/// policy that silently accepts anonymous pulses is not a gate, it is a
/// comment.
/// {@endtemplate}

/// **Do not check object types inside a composed policy incorrectly.**
///
/// {@template ai-do-not-forget-object-dispatch}
/// **Do not forget the object-type dispatch contract.** A `Policy`
/// receives a [Pulse] for pulse reception, a [Function] for action
/// invocation, and a [Cell] for link establishment. Every factory must
/// return `true` for the object types it does not govern, or the policy
/// will silently reject unrelated operations when composed with `+`.
/// {@endtemplate}

/// **Do not read the clock inside a policy without a journal.**
///
/// {@template ai-do-not-read-clock-without-journal}
/// **Do not read the clock inside a policy without a journal.**
/// Time-reading policies (`notOlderThan`) take a required injected
/// `clock` and declare `Purity.readOnlyExternal`. In a replayable graph,
/// feed `journal.clock` — a policy that calls `DateTime.now()` directly
/// breaks replay determinism.
/// {@endtemplate}

/// **Do not route traffic through the principal when recording matters.**
///
/// {@template ai-do-not-bypass-cognitive-view}
/// **Do not route traffic through the principal when recording matters.**
/// `cognitive(cell:, policy:)` returns a handle; only
/// `handle.cognitive` applies the policy and records decisions.
/// `handle.cell` is the untouched principal — emissions and applies on
/// it bypass the cognitive layer entirely.
/// {@endtemplate}

/// **Do not mutate the decision log from user code.**
///
/// {@template ai-do-not-mutate-decision-log}
/// **Do not mutate the decision log from user code.** The
/// `TissueList<Decision>` is written by the recording rule only.
/// User code reads and observes it; appending invented decisions breaks
/// the audit trail and the trainer's join (Phase 3).
/// {@endtemplate}
