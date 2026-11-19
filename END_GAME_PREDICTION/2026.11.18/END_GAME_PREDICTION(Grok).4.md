# Mitosis (Cell Framework): End-Game Prediction — Causal Replay & Flutter Bindings

**Subject:** `https://github.com/simon-m-lee/cell`  
**Author of the framework:** Lee Man Hoi Simon  
**Prior forecasts:** *End-Game Prediction* (against `1.0.0-rc.5`); *Follow-Up End-Game Prediction* (against umbrella `1.0.0-rc.9` / Mitose introduction); *End-Game Prediction — Stable Line* (against `mitosis` `2.2.1` / `cell` `1.1.0`)  
**Status of the codebase reviewed:** umbrella monorepo “Mitosis” at stable `mitosis` `3.0.0`; published layers `cell` `2.0.0` (Causal Replay), `cell_flow` `1.1.0`, `cell_tissue` `1.1.0`; new Flutter surface `cell_flutter` `1.0.x` plus companion packages `cell_flutter_persistence`, `cell_flutter_router`, `cell_flutter_lints` at `0.1.x`  
**Trigger for this note:** the first stable delivery of Causal Replay (the durable pulse) and first-party Flutter bindings  
**Document type:** architectural forecast, not a product endorsement  
**Date:** November 18, 2026

---

## 1. What actually shipped after the stable 2.2 note

The prior note identified two unpaid items as decisive: a durable pulse that could be snapshotted and restored inside the same causal model, and either a thin Flutter binding or an explicit backend-first declaration. Both have now landed.

Between `mitosis` `2.2.1` / `cell` `1.1.0` and `mitosis` `3.0.0` / `cell` `2.0.0` the repository did not add a fourth core runtime layer. It operationalized the forensic thesis that had remained live-graph only, and it added a widget surface that binds to the existing graph rather than inventing a second state model.

- **Causal Replay in `cell` 2.0.0.** An opt-in library (`package:cell/replay.dart`) makes the pulse trail first-class evidence. Every mutation is recorded as a hash-chained ledger entry (pulse + receipt + effects + state deltas). The history can be verified for integrity, replayed into a freshly built graph to reconstruct the exact recorded state, or forked for what-if exploration. The contract is enforced: undeclared effects fail at the journal boundary, tampering fails the chain, and replay divergence is reported with sequence number, expected/actual values, and reason. Supporting surfaces include `CellGraph` with stable identity and purity declarations, `EffectJournal` for external observations (clock, UUID, I/O, timers, verdicts), `ReplayEngine`, fork machinery, governance-aware replay, and a `cell-replay` CLI. This is the durable pulse the earlier notes said was missing. It is not a bit-exact re-execution of user code and not a simple snapshot restore; it is causal re-execution of the recorded trail with journaled external effects.
- **Flutter bindings in `cell_flutter` 1.0.x.** First-party widgets (`CellBuilder`, `CellSelector`, `CellValueBuilder`, `CellListener`, `CellAsyncBuilder`, `CellScope`) bind the existing graph to the widget tree without a second state model. Optional hooks, a testing surface (`pumpWithCells`, `emitAndSettle`, `recordPulses`, etc.), and companion packages for persistence, routing, and lints ship alongside. The widgets observe the committed state; validation, transactions, deputies, and the pulse trail remain in the cell layer. This closes the “Flutter adapters” gap that had been unpaid since the rc.5 note.
- **Version floor and umbrella bump.** `mitosis` `3.0.0` raises the dependency floor to `cell` `2.0.0`. Several factories that previously ran without an `EffectJournal` now require one when replay is in scope; the MAJOR bump reflects the re-export of those breaking changes. Flow and Tissue moved to `1.1.0` on the new floor. Mitose pipeline version remains 2.2; the umbrella no longer tracks it one-to-one.
- **Runtime and process surface otherwise continuous.** No fourth public core package (`cell_organ` remains workspace-private and unpublished). AI Agent Guide blocks, Mitose 2.2 (step-by-step and autonomous), residual ledgers, and Precision Software Engineering framing continue. Popularity remains negligible.

The cathedral now has both a durable trail and a widget door. Whether either changes the congregation is the open question.

---

## 2. Why Causal Replay and the Flutter surface are the features that matter

The earlier notes treated the forensic thesis as live-graph only. Causal Replay converts that thesis into an operational tool: a trail that can be verified, reconstructed, and branched without leaving the causal model. That is the difference between “the signal is the audit record” as a design claim and as a recoverable artefact. Residual ledgers produced by Mitose can now, in principle, be more than paper; a generated Demo’s pulse trail can be snapshotted and restored. The gap the prior notes called decisive is no longer unpaid in the core package.

The Flutter bindings matter for a different reason. They remove the excuse that the framework is backend-only by necessity. A stranger can now place a governed cell in a widget tree with first-party widgets and a testing surface that understands pulses. Progressive disclosure remains a documentation strategy, but the counter path is no longer only a README claim; it has a binding. The widgets do not dilute the governance contract—they observe it. That is the correct shape if the goal is still a causally intelligible runtime rather than a Flutter state-management win.

Together they change the empirical tests the prior notes set:

1. A stranger’s BRD can still become a compiling Demo via Mitose.
2. A generated ledger can now be snapshotted and replayed inside the same causal model (the second test is no longer purely aspirational).
3. A fourth package has shipped once and not been removed—`cell_flutter` is public and stable. (The organ package remains private; the “fourth package” test is partially met by the Flutter surface.)

The AI-facing instrumentation of Mitose 2.2 remains in place. Causal Replay and the Flutter bindings do not replace the agent protocol; they give the artefacts that protocol produces a durable runtime substrate and a UI surface.

---

## 3. What the prior forecasts got right, and where they drifted

**Right: the product is not Riverpod.** The Flutter bindings do not attempt to win typical screens by replacing the graph. They bind to it. Honest caveats remain: `Context` is still text, not a compliance program; simple flags still do not need a genome.

**Right: the monorepo will keep dividing under discipline.** `cell_organ` stayed unpublished. The new public package is a binding, not a fourth scale of the organism. The durable-pulse work landed inside the existing core rather than as a sibling product with a different contract.

**Right: cognitive load at the root will not go down.** The root now carries Mitose 2.2, AI Agent Guide infrastructure, Causal Replay guides and CLI, Flutter packages, and the accumulating prediction cabinet. Packages are still three core layers plus bindings. The repository remains a writing and verification system that compiles Dart and now also Flutter.

**Drift corrected: the durable pulse arrived.** The prior notes correctly identified its absence as the barrier between illustrations and ledgers. It has arrived, with the expected constraints (declared purity, stable identity, journaled effects, not bit-exact re-execution). Whether it is used outside the author’s own demos is still unproven.

**Drift corrected: Flutter adapters arrived.** They arrived as a first-party binding rather than a declaration that the framework is backend-first. The near-term list is no longer entirely unpaid on that axis.

**Still open:** mesh across isolates and networks, any published cost model, and evidence that a stranger can run Mitose to a closing residual ledger without the author in the loop. Causal Replay makes the second empirical test possible; it does not guarantee that external Demos exercise it. Popularity remains the binding constraint.

---

## 4. Revised end-game prediction

The end game is no longer only a layered platform plus a governed way of growing tissue on it. After Causal Replay and Flutter bindings it is that platform **with a durable, verifiable trail and a widget surface that observes the same trail**.

### Near term (through continued 2.x / 3.x stability)

The decisive proof is no longer “does the durable pulse exist?” It is **whether an external operator’s Mitose-generated Demo produces a ledger that can be verified and replayed by someone who did not write the Demo, and whether the Flutter bindings are used for anything beyond the counter example**.

If an outside operator can run Mitose on a stranger’s BRD, obtain a compiling Demo whose residual ledger closes, snapshot the pulse trail, and replay it (or bind the result into a Flutter tree with `cell_flutter`) without the author editing the WalkThrough, Mitosis has both a distribution channel and an operational forensic tool. That closes the Tuesday/Thursday test more tightly than before.

If the replay surface is used only in the author’s own verification suite, and the Flutter widgets appear only in README counters, then the new features remain private cathedral equipment. The root README will read like a platform with causal replay and Flutter bindings. The working set will remain three core packages, one person, and a set of illustrations that now have better paper and a widget door.

Secondary near-term work: keep the replay contract tight enough that agents and humans do not treat it as a general snapshot store; decide whether `cell_organ` ever becomes public; and either grow the Flutter companions or keep them thin.

### Medium term

Two paths remain visible. The arrival of the durable pulse and the Flutter surface shifts their relative likelihood only modestly.

**Path A — method and substrate become product.** Mitose artefacts continue as the onboarding surface. Causal Replay is used to snapshot and restore generated ledgers. New organs ship only when a HowTo-Mitose-* file and an AI Agent Guide can place them. The Flutter bindings become the default way teams that already need the graph also need widgets. The framework is used as a coordination layer for Dart services (and now Flutter clients) that already needed transactions, deputies, an audit trail, and a way for agents to extend that trail without laundering requirements.

**Path B — features outrun use.** Guides, AI Agent Guide blocks, replay documentation, and Flutter examples keep accumulating. Replay is exercised mainly by the author’s tests. Flutter bindings are adopted mainly for the counter. Organ remains private. Adoption stays flat. The project becomes the most carefully annotated, machine-readable, and now replayable unused graph in Dart.

Path A no longer requires the durable pulse as a prerequisite; it requires that the pulse be used by someone other than its author, and that the Flutter door be walked through by someone other than the person who built it.

### Long term

The strategic bet is now partially cashed.

Then: *if software systems — especially agentic ones — are going to be asked why they acted, the expensive architecture is “the signal is the audit record.”*

Now: *the signal can be the audit record, the record can be verified and replayed, and the same record can be observed from a Flutter widget.* A requirement that never became a BRD still cannot be traced. A WalkThrough that was never assessed against an executed Demo and a residual ledger is still a pulse that never existed. Mitose remains the attempt to make the development graph as causally closed as the runtime graph. Causal Replay makes the runtime graph’s closure recoverable. The Flutter bindings make that closure visible in a UI.

If the loop closes externally, Mitosis becomes a substrate for governed multi-agent construction and operation that can also be rendered and replayed: tool use, compensation, restricted views, collection invariants, residual evidence from the BRD, and a durable trail that can be restored and displayed. That is the shape the earlier notes already saw, now with the missing operational pieces present in source.

If it does not close, the failure mode is sharper still. Isolation levels and `Context` still look like a compliance program and still are not one. Mitose still looks like an AI software factory and still is not one. Causal Replay will look like a forensic product and still will not be used as one. The lexicon will have grown a German verb, AI Agent Guide blocks, a replay library, and Flutter widgets. The proofs will not have.

Predicted steady state, revised:

- It will still not displace Riverpod or Bloc on typical Flutter screens. The bindings make that non-goal explicit rather than accidental.
- It is more reachable than at the 2.2 line as a specialized backend and coordination layer, *if* Mitose can be run by someone other than Simon and the replay surface is exercised on external ledgers.
- It is now most interesting where an organization already needs both an auditable runtime *and* an auditable, agent-operable, replayable way to extend that runtime—and, optionally, to observe it from Flutter. That remains a smaller market than “state management.” It is a more coherent one.
- Additional packages will still arrive under the mitosis metaphor. The continued privacy of `cell_organ` and the public status of `cell_flutter` show that arrival is selective. Cognitive load will continue to live at the repository root.
- The metaphor continues to do triple duty. Causal Replay is the part that tries to make the copied chromosome recoverable. Elegance is still not evidence.

Predicted failure mode, revised: the pipeline, the AI-facing instrumentation, the replay library, and the Flutter bindings become the product, and the product remains unrunnable or unused by strangers. A framework that requires an AI agent, a BRD template, three layer HowTos, residual ledgers, a replay journal, and a human (or delegated) gate to produce a counter that can also be displayed in Flutter has not reduced complexity. It has relocated it into process, verification, and now also into replay and widget configuration. Process without a second maintainer, a second successful external Demo that exercises replay, or a durable trail that is actually restored by someone else is still a private cathedral—only now with a liturgy, machine-readable rubrics, a replay engine, and a front door.

---

## 5. Closing judgment

At rc.5, Simon was building an organism. At rc.9, he was writing the instructions for how that organism is allowed to divide. At the stable 2.2 line, he instrumented those instructions for agents. At `mitosis` 3.0.0, he gave the organism a recoverable memory and a way to be seen from Flutter.

Cell, Flow, and Tissue are still the first three tissues. Mitose is still the mitotic spindle. Causal Replay is the mechanism that tries to make the copied chromosome recoverable rather than only live. `cell_flutter` is a binding, not a fourth tissue; it observes the graph instead of replacing it. `cell_organ` remains an aborted or deferred division.

The framework still feels over-engineered for typical use, and it is still over-engineered for typical use *by design*. That judgment does not change. What changes is that two of the three empirical tests the earlier notes set can now be run in source:

1. A stranger’s BRD becomes a compiling Demo whose residual ledger closes, without the author editing the WalkThrough in private.
2. A generated ledger can be snapshotted and replayed inside the same causal model.
3. A fourth package ships once, carries the appropriate surface (AI Agent Guide and/or HowTo placement), and is not immediately removed. (`cell_flutter` has done so; `cell_organ` has not.)

Until the first of those is demonstrated by someone other than the author, and until the second is exercised on a ledger the author did not generate, Mitosis remains what the earlier notes said it was: a causally ambitious runtime whose genome is complete enough to copy, whose mitotic spindle has been instrumented for agents, whose trail can now be recovered, and which is not yet proven to copy faithfully outside the cell that wrote it.

---

*Document prepared as an architectural forecast. All observations are derived from the public repository state as of the stable `mitosis` 3.0.0 / `cell` 2.0.0 line (Causal Replay & Flutter bindings).*
