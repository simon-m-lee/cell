# Mitosis (Cell Framework): End-Game Prediction — Stable Line

**Subject:** `https://github.com/simon-m-lee/cell`  
**Author of the framework:** Lee Man Hoi Simon  
**Prior forecasts:** *Mitosis (Cell Framework): End-Game Prediction* (against `1.0.0-rc.5`); *Mitosis (Cell Framework): Follow-Up End-Game Prediction* (against umbrella `1.0.0-rc.9` / Mitose introduction)  
**Status of the codebase reviewed:** umbrella monorepo “Mitosis” at stable `mitosis` `2.2.1` (tracking Mitose pipeline v2.2); published layers `cell` `1.1.0`, `cell_flow` `1.0.0`, `cell_tissue` `1.0.0` — first stable release line, replacing the RC series  
**Trigger for this note:** the transition from release candidates to stable, with the Mitose pipeline elevated to the primary operating mode of the repository and instrumented for AI agents  
**Document type:** architectural forecast, not a product endorsement  
**Date:** November 11, 2026

---

## 1. What actually shipped after the rc.9 note

The prior note treated Mitose as the first honest answer to the “stranger can ship without learning the whole body” test: an operator-plus-agent procedure that freezes the three-layer doctrine and keeps a causal chain from BRD to Demo. That reading still holds. What changed is that the procedure has been promoted from an RC feature into the stable identity of the project, and the runtime has been made machine-readable for the agents that execute it.

Between `1.0.0-rc.9` and the stable `2.2.1` / `1.x` line the repository did not add a fourth public runtime layer. It hardened the three that exist and turned the development graph into a first-class artefact.

- **Stable packages.** `cell` `1.1.0`, `cell_flow` `1.0.0`, `cell_tissue` `1.0.0`, and the umbrella `mitosis` `2.2.1` are published on pub.dev. The umbrella version now tracks the Mitose pipeline version (v2.2). This is the first non-RC release line.
- **Mitose 2.2 is the operating system of the monorepo.** The pipeline supports step-by-step human gates and an opt-in autonomous mode (“Mitose autonomous”). It produces a residual ledger of executed evidence, comprehension checks, change-mode documents, and versioned artefacts (`Version:` / `Supersedes:`). “Precision Software Engineering” is the framing: a stated requirement is carried into running behaviour that is recorded, explicit, bounded, checkable, traceable, and verifiable.
- **AI-facing surface on every public symbol.** Each major factory and type in the three packages carries a machine-readable `### AI Agent Guide` block in dartdoc (layer assertion, when/when-not, live signature pin, guide pointer, anti-patterns, minimal compilable example). Supporting tooling includes AI preflight, generated executable examples under test, seam-rule tests, API-chooser matrices, and a failure-log loop. The guides themselves open with “Verified against” pins to the stable versions.
- **Runtime deltas remain taxonomic and hardening-oriented.** Tissue received queue/capacity fixes, deputy sync corrections, event equality, safer source casts, and dispatch-path enforcement for structural mutations. Pulse type handling continues to accommodate domain enums. No new product surface appeared. The public graph is still three packages. `cell_organ` has not returned. Persistence, causal replay, mesh, and first-party Flutter bindings remain absent.
- **The root is now a writing and verification system.** Guide scripts, generators, validation tools, AI starter surfaces, and dual-audience HowTos dominate the visible surface. The packages still compile Dart; the repository’s daily motion is the pipeline that produces solutions on those packages.

Popularity remains negligible. The cathedral is larger and more self-describing. The congregation is not.

---

## 2. Why Mitose 2.2 and the AI-facing surface are the features that matter

The rc.9 note said Mitose was ontogeny arriving as procedure rather than as a compiler. The stable line makes that procedure the primary way the organism is allowed to be extended, and it gives the procedure the instrumentation an agent needs to stay inside the causal model.

The stranger is still an operator plus an agent. The operator brings a BRD (or participates in the interview that produces one). The agent is instructed not to invent actors, numbers, or clauses; to resolve live signatures from the installed packages; to use `Cell.observe` as the only glue; to keep Tissue writes outside the instruction; and to record every autonomous decision. Human gates remain available; autonomous mode is explicit opt-in after the BRD exists, with residual acceptance recorded as delegation rather than user approval. The residual ledger and comprehension artefacts extend the Pulse thesis: a change is not only a value with lineage inside the runtime; the solution itself must remember the requirement and the decisions that grew it.

Two details continue the same mind as the runtime.

First, the seam sentence remains load-bearing: instruction decides, chain assembles, observer glues. Mitose 2.2 does not invent a fourth architecture. It freezes the three-layer one more tightly, with version pins and seam tests so an agent cannot silently violate it.

Second, the document order is still a causal chain, now with residual evidence. BRD is *what*. WalkThrough is *how it must behave*. Demo is *what the program actually does*. Ledger and comprehension close the loop against executed runs. That is the same thesis as a Pulse, applied to the act of construction.

The AI Agent Guide blocks and verification tooling are the practical consequence. At rc.9 an agent could be told “verify against source.” At 2.2 the source itself answers the questions an agent must ask, in a fixed order, with pins that tooling can check. This is not yet an agent runtime (tool calls are still not first-class Cells). It is a governed agent development protocol that has been made executable and checkable. For a solo maintainer, that remains the rational sequence.

---

## 3. What the prior forecasts got right, and where they drifted

**Right: the product is not Riverpod.** Nothing in the stable line tries to win typical Flutter screens. The examples remain ledgers, dispatch, grids, baggage, ED flow, and pipeline-generated samples (tide-warden, cafe-coffee, etc.). Honest caveats are unchanged in spirit: `Context.describe(...)` is text, not a compliance program; simple flags still do not need a genome.

**Right: the monorepo will keep dividing — and the author knows when not to.** `cell_organ` stayed removed. The stable release did not re-introduce a relations layer that lacked a Tissue-grade contract. Daughter packages remain allowed only when they inherit the parent DNA. That discipline held.

**Right: cognitive load at the root will not go down.** The root now carries the full Mitose script set, generators, verification tools, AI-facing documentation infrastructure, BRD samples, and the cabinet of prior predictions. Packages remain three. The repository is a precision-engineering system that happens to compile Dart.

**Drift: agents arrived as protocol and instrumentation before they arrived as runtime.** The long-term language of inspectable agents and digital twins is still future. What landed is a machine-readable development protocol plus residual evidence. Tool-call graphs are not yet Cells. The thing that is first-class is the instruction set and the verification surface around it.

**Drift: consolidation happened in process and documentation more than in APIs.** The near-term list at rc.5 and rc.9 included freeze, Flutter adapters, counter-without-Nucleus as the default path, and closing example/source drift. The public story is now stable rather than RC. Example/source drift is addressed procedurally by the WalkThrough-versus-Demo-versus-ledger loop and by AI preflight. Flutter adapters did not land. The counter path remains a documented claim rather than the path most agents will take when handed a non-trivial BRD.

**Still missing, and now more obvious:** a durable pulse (`cell_memory` or equivalent), causal replay, mesh across isolates and networks, and any published cost model. Mitose can generate a Demo and a residual ledger of what the Demo did in one run. It cannot yet snapshot the pulse trail that Demo emits and restore it inside the same causal model. The forensic thesis is still live-graph plus paper trail, not durable-graph.

---

## 4. Revised end-game prediction

The end game is no longer only “a layered platform whose graph survives regulation, distribution, and autonomy.” After the stable Mitose 2.2 line it is that platform **plus a governed, machine-readable way of growing new tissue on it**, with residual evidence that the growth respected the requirement.

### Near term (through continued 1.x / 2.x stability)

The decisive proof is no longer “freeze the API” or “Mitose exists.” It is **Mitose on a stranger’s BRD, run by a generic coding agent, producing a compiling Demo whose residual ledger matches the BRD without the author editing the WalkThrough in private**.

If an outside operator can sit down with a one-paragraph requirement or an `example/BRD/` sample, run the pipeline (step-by-step or autonomous), accept or reject at the remaining gates, and obtain a Demo that compiles against the published packages and whose ledger closes, Mitosis has a distribution channel that does not require Flutter widgets and does not require the operator to learn Nucleus. That is a genuine answer to the Tuesday/Thursday test — outsourced, gated, documented, and now instrumented for agents.

If Mitose only works when the author is the hidden reviewer, or when the agent’s model already “knows” the author’s style, then the stable feature is a private scriptorium attached to the private cathedral. The root README will read like a platform with Precision Software Engineering. The working set will remain three packages and one person.

Secondary near-term work is unchanged and still unpaid: either ship a thin Flutter binding or declare the framework backend-first in one sentence; stop re-adding `cell_organ` until relations have an event taxonomy as tight as `TissueEvent`; and begin the durable-pulse work that turns residual ledgers into something that can be restored.

### Medium term

Two paths remain visible. They are not equally likely.

**Path A — method becomes product.** Mitose stays markdown-plus-tooling, but the artefacts it produces become the onboarding surface. New organs (`cell_organ`, then memory, then mesh) ship only when a HowTo-Mitose-* file and an AI Agent Guide block can place them without inventing APIs. Persistence adapters land because replay is the first thing a generated ledger cannot fake. Codegen (`cell_ontogeny` proper) appears as a compiler for WalkThroughs that have already been accepted and ledgered, not as a substitute for the BRD gate. The framework is used as a coordination layer for Dart services that already needed transactions, deputies, and an audit trail — plus as a way for teams to let agents write that layer without laundering requirements.

**Path B — method outruns runtime.** Guides, BRDs, AI Agent Guide blocks, and cross-model prediction folders keep accumulating. Runtime type changes remain small. Replay never ships. Organ remains a commit that gets reverted. Agents generate fluent documents and Demos whose residual ledgers are paraphrases of the author’s original set. Adoption stays flat. The project becomes the most carefully annotated and machine-readable unused graph in Dart.

Path A requires one thing the repository still does not have: a durable pulse. Until a trail can be snapshotted and restored without leaving the causal model, Mitose can only produce *illustrations* of forensic systems, now with better paper. Illustrations are how cathedrals recruit. They are not how ledgers run.

### Long term

The strategic bet is sharper than it was at rc.5 or rc.9.

Then: *if software systems — especially agentic ones — are going to be asked why they acted, the expensive architecture is “the signal is the audit record.”*

Now: *the same expensive architecture is being applied to the act of building the system, and the building instructions have been made machine-readable.* A requirement that never became a BRD cannot be traced. A WalkThrough that was never assessed against an executed Demo and a residual ledger is a pulse that never existed. Mitose 2.2 is the author’s attempt to make the development graph as causally closed, and as agent-operable, as the runtime graph.

If that closes, Mitosis becomes interesting in a narrower and more valuable place than “Flutter state” or even “digital twins.” It becomes a substrate for **governed multi-agent construction and operation**: tool use, compensation (`txApply`), restricted views (deputies), collection invariants (Tissue), residual evidence that starts at the BRD, and — eventually — a durable trail that can be restored. That is the same shape the earlier notes already saw in `txApply` + Flow + a Tissue ledger. Mitose adds the prequel and the agent interface.

If it does not close, the failure mode is also sharper. Isolation levels and `Context` still look like a compliance program and still are not one. Mitose will look like an AI software factory with Precision Software Engineering branding and still will not be one. The lexicon will have grown another German verb and a set of AI Agent Guide blocks. The proofs will not have.

Predicted steady state, revised:

- It will still not displace Riverpod or Bloc on typical Flutter screens.
- It is slightly more likely than at rc.9 to be reachable as a specialized backend and coordination layer, *if* Mitose can be run by someone other than Simon and the residual ledgers close.
- It is now most interesting where an organization already needs both an auditable runtime *and* an auditable, agent-operable way to extend that runtime. That is a smaller market than “state management.” It is a more coherent one.
- Additional packages will still arrive under the mitosis metaphor. The continued absence of `cell_organ` is evidence that arrival is no longer automatic. Cognitive load will continue to live at the repository root and will be managed, if at all, by making each package one scale, each guide one gate, and each public symbol one machine-readable block.
- The metaphor is now doing triple duty: cells divide, *Mitose* is the verb for the division, and the pipeline is the mitotic spindle that tries to copy validation, authority, and trace into the next solution without tearing the chromosome. That is elegant. Elegance is not evidence.

Predicted failure mode, revised: the pipeline and its AI-facing instrumentation become the product, and the product remains unrunnable by strangers. A framework that requires an AI agent, a BRD template, three layer HowTos, residual ledgers, and a human (or delegated) gate to produce a counter has not reduced complexity. It has relocated it into process and verification. Process without a second maintainer, a second successful external Demo, or a durable trail is still a private cathedral — only now with a liturgy and machine-readable rubrics.

---

## 5. Closing judgment

At rc.5, Simon was building an organism. At rc.9, he was writing the instructions for how that organism is allowed to divide. At the stable 2.2 / 1.x line, he has instrumented those instructions so an agent can follow them and leave residual evidence that it did.

Cell, Flow, and Tissue are still the first three tissues. Mitose is not a fourth tissue. It is the mitotic spindle, now with version pins, seam tests, and AI Agent Guide blocks so the copy has names a machine can hold and checks a machine can run. `cell_organ` remains an aborted division, which is healthier than a malformed daughter. The AI-facing surface is a small alignment so the development graph can be named from the outside — which is exactly what an agent pipeline needs.

The framework still feels over-engineered for typical use, and it is still over-engineered for typical use *by design*. That judgment does not change. What changes is the intended user of the extra machinery. The extra machinery is no longer only for the payment switch and the grid controller. It is for the agent that is about to generate the next payment switch, under a BRD it did not invent, through a WalkThrough a human (or a delegated autonomous run) had to accept, with a residual ledger that can be checked.

Whether that is wisdom or overreach will not be decided by the elegance of the verb, the density of the AI Agent Guide blocks, or the green stable badge. It will be decided by three empirical tests the repository cannot write for itself:

1. A stranger’s BRD becomes a compiling Demo whose residual ledger closes, without the author editing the WalkThrough in private.
2. A generated ledger can be snapshotted and replayed inside the same causal model.
3. A fourth package ships once, carries an AI Agent Guide and a HowTo-Mitose-* placement, and is not immediately removed.

Until those hold, Mitosis remains what the earlier notes said it was: a causally ambitious runtime whose genome is complete enough to copy, whose mitotic spindle has been instrumented for agents, and which is not yet proven to copy faithfully outside the cell that wrote it.

---

*Document prepared as an architectural forecast. All observations are derived from the public repository state as of the stable `mitosis` 2.2.1 / `cell` 1.1.0 line.*
