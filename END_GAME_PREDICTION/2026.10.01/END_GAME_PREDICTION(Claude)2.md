# Follow-Up Prediction: The Mitosis Framework after the Mitose Pipeline

How the addition of an AI-executable, requirements-to-solution pipeline changes the trajectory forecast for github.com/simon-m-lee/cell.

Subject

github.com/simon-m-lee/cell (Mitosis: `cell`, `cell_flow`, `cell_tissue`)

Prepared

30 September 2026

Updates

End-Game Prediction: The Cell Framework (Mitosis), September 2026

Basis

Public repository CHANGELOG (through 1.0.0-rc.9) and `guide/HowTo-Mitose.md`

## Key findings

- The newest release adds a pipeline that lets an AI agent turn a plain-English business requirement into a Cell + Flow + Tissue solution and its project documents.
- This is the author's first direct answer to the learning-cost problem identified in the earlier prediction: the framework is being shaped to be written by AI as much as by people.
- The earlier "library to platform" forecast holds only in part. The platform features (replay, distributed cells) have not shipped, while onboarding and process work has.
- The most likely outcome is now a spec-driven niche toolkit (about 45%), with a stall (about 30%) and production graduation (about 25%) as the alternatives.

## 1. What Changed

The changelog records four umbrella releases since the previous assessment, from 1.0.0-rc.6 to 1.0.0-rc.9. The last of these carries the substantive change: the Mitose pipeline, released alongside `cell` 1.0.0-rc.6 (a widened `Pulse.type`), `cell_flow` 1.0.0-rc.7 (pipeline documentation) and `cell_tissue` 1.0.0-rc.7 (a unified `TissueEvent` classification).

### The pipeline

An agent reads an orchestration script and runs it with a person. The sequence is a requirements document (BRD) gate, a WalkThrough, a Demo, a check of the WalkThrough against the Demo code, and optional ARCHITECTURE and FEATURES documents. The person makes one decision at each gate, and the script forbids writing the Demo before the WalkThrough is accepted.

### Supporting materials

- Layer placement guides for Cell, Flow and Tissue that tell the agent which layer answers each requirement.
- A guided BRD interview and an offline BRD template.
- Sample BRDs for airport baggage handling, assembly-line downtime, freight rail intermodal and hospital ED capacity and flow.
- An `AGENTS.md` file so that agentic tools discover the Mitose trigger automatically.
- A new `(Cell)` demo set and a Mitosis demo guide.

## 2. What the Evidence Shows

1. **Rules a machine can check.** The orchestration script states its rules in checkable form: the "seam sentence" (the instruction decides, the chain assembles, the observer glues), a grep rule of zero `testRule: TestCell` on Tissue constructors, and no Tissue writes inside an instruction. These are conventions an agent can enforce on its own output.
2. **The agent is told not to trust its own memory.** The script directs the agent to resolve live signatures from pub.dev and never to invent an API from memory. That is an acknowledgment that language models do not know this framework.
3. **The guides are distributed through the repository, not the package.** The `guide/` directory is tracked in the repository but excluded from the pub.dev archive. The changelog also shows the guides removed as internal in rc.8 and restored as a public product in rc.9.
4. **Adoption indicators are unchanged.** The repository still shows one author, zero stars and zero forks, and one open pull request.

## 3. Revisions to the Earlier Prediction

| Earlier claim | Revised view |
| --- | --- |
| The vocabulary imposes a learning cost before developers have a problem that motivates it. | The author moves that cost to an agent. A person writes a plain-English BRD and the agent handles `Nucleus`, `TestCell` and layer choice. |
| The project is moving from library to platform. | Only partly. Replay and distributed cells have not shipped. Agent-facing developer experience will likely arrive before any agent-orchestration runtime. |
| The audience narrows toward fintech and compliance. | The sample BRDs are operational-flow domains: logistics, manufacturing and hospital capacity. The audience looks wider and closer to decision support. |
| A single maintainer is the main bottleneck. | Partly mitigated, because the pipeline generates documents and demos. But rc.6 to rc.9 were mostly documentation and demos, so leverage has not yet reached the core. |
| Agent orchestration is a long-term destination (Phase 3). | The order is inverted. Agents will use Mitosis to build systems before Mitosis is used to orchestrate agents. |

## 4. Updated End-Game Forecast

The probabilities below are the author of this assessment's own estimates. They are not stated anywhere in the repository.

45%30%25%

### 45%: a spec-driven niche toolkit

A small number of practitioners use the pipeline to generate governed reactive prototypes. The project gains modest attention as an example of designing a framework for AI code generation, and its conventions influence other tooling.

### 30%: a stall after the pipeline and first stable release

The documentation is extensive, but no ecosystem forms. Stable 1.0.0 arrives late or not at all, and the interesting architectural work is treated as finished.

### 25%: graduation to production use

Generated output is compiled and tested in CI, demos become production scaffolds, and outside contributors appear. This is the only path that reaches the Phase 2 and Phase 3 ambitions.

## 5. Risks Specific to the New Feature

- **Cold start.** The scripts must carry all framework knowledge because models do not have it. While APIs can still change before 1.0, the pipeline is exposed to drift between the guides and the source.
- **Demo versus production.** The pipeline ends at a runnable `Demo.dart` and documents, not a deployable service. The distance from demo to production is unaddressed.
- **Unproven adherence.** The repository gives no evidence that agents follow the orchestration script faithfully across models, or that outputs are validated automatically.
- **Documentation-led momentum.** If releases continue to be mostly guides and demos, the core may not mature at the pace the roadmap implies.

## 6. Intention of the Author

The earlier assessment read the author's intent as building a long-horizon, opinionated runtime for systems where causality and auditability are non-negotiable. The Mitose pipeline adds a second, more practical intent: to make that framework usable by people who will never learn its vocabulary. Publishing the guides after briefly withdrawing them suggests the author now treats onboarding as a product in its own right. The choice of operational-flow samples, and of an agent-discovery file, points to a bet that AI-assisted development is the fastest route to adoption for a project with no existing community.

## 7. Signals to Watch

- Whether stable 1.0.0 ships and the API freezes. The freeze has slipped since rc.5.
- Whether generated demos are compiled and tested in CI.
- Whether anyone other than the author files an issue or sends a pull request.
- Whether the Flutter adapters listed in Phase 1 arrive.
- Whether the pipeline is used on a real BRD outside the four samples, and what comes of it.

## 8. Conclusion

The Mitose pipeline is a change of strategy rather than a new capability. It does not move the framework closer to distributed or replayable state, but it addresses the adoption barrier that the earlier assessment considered most serious. The forecast therefore shifts toward a niche but purposeful outcome: a governed-reactive toolkit designed for AI-assisted development. Whether it becomes more than that depends on execution capacity, and the clearest test will be evidence that generated solutions survive contact with automated tests and real users.

**Basis and limitations.** The README snapshot available when this was written was stale and still showed rc.5, so the CHANGELOG was used as the source for rc.6 to rc.9. Statements about pipeline behavior come from `HowTo-Mitose.md` only; the other guides and the sample outputs were not reviewed.

