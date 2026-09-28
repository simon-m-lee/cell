# Mitosis

> **Formerly the Cell Framework.** One reactive graph. Three layers. Zero broken causal chains.

[![License](https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-blue.svg)](https://github.com/simon-m-lee/cell/blob/master/LICENSE)
[![Dart SDK](https://img.shields.io/badge/dart-%3E%3D3.5.0%20%3C4.0.0-blue.svg)](https://dart.dev)
[![Status](https://img.shields.io/badge/status-1.0.0--rc.9-yellow.svg)](#-project-status--cadence)
[![Melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg)](https://github.com/invertase/melos)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#-contributing)

**Mitosis** is a reactive application framework for Dart that treats state, events, and their **causal history** as one coherent, observable graph. It is an umbrella monorepo built from three layers — **Cell**, **Flow**, and **Tissue** — that scale from a single reactive value to a fully governed application body without ever dropping the forensic trail.

Mitosis is designed for systems where *why something happened* matters as much as *what happened*: financial and transaction-heavy software, security-sensitive services, audit-bound enterprise applications, real-time coordination, and increasingly, autonomous and multi-agent systems.

> **New — the Mitose pipeline.** The [`guide/`](guide/HowTo-Mitose.md) directory ships an AI-executable orchestration script: give an AI prompt agent a business requirement, and it follows `HowTo-Mitose.md` to produce a working **Cell + Flow + Tissue** solution together with its BRD, WalkThrough, Demo, ARCHITECTURE, and FEATURES documents. See [The Mitose Pipeline](#-the-mitose-pipeline).

---

## Table of Contents

- [Why the name "Mitosis"?](#-why-the-name-mitosis)
- [The Three Pillars](#-the-three-pillars)
- [The Mitose Pipeline](#-the-mitose-pipeline)
- [Repository Layout](#-repository-layout)
- [Architecture Philosophy](#-architecture-philosophy)
- [Design Principles](#-design-principles)
- [Quick Start](#-quick-start)
- [Development Commands](#-development-commands)
- [Documentation Map](#-documentation-map)
- [Project Status & Cadence](#-project-status--cadence)
- [Vision & Roadmap](#-vision--roadmap)
- [Honest Caveats](#-honest-caveats)
- [Contributing](#-contributing)
- [License](#-license)
- [Authors](#-authors)
- [Links](#-links)

---

## 🧬 Why the name "Mitosis"?

In biology, **mitosis** is the process by which a cell divides into two daughter cells, each carrying a **complete, faithful copy of the parent's DNA**. Nothing is lost; every new state inherits a lineage.

That is exactly the contract this framework enforces for software state:

- every change is a **Pulse** — an immutable message carrying value, provenance, and context;
- every propagation **preserves the causal chain** — you can always ask *who*, *why*, *under which authority*, and *what happened downstream*;
- every layer built on top — Flow, Tissue, and beyond — **inherits the same DNA** (validation, governance, traceability) rather than re-inventing it.

The project was previously known as the **Cell Framework**. The rename to **Mitosis** reflects the move from "a reactive state library" to a broader ambition: a **causally intelligible runtime** for composing complex reactive systems.

The name is also a promise about the project itself: **mitosis keeps dividing**. The ecosystem is still growing — three layers today, and more will come online as the framework matures.

---

## 🧱 The Three Pillars

Mitosis is organized into three specialized layers. Each layer is a separate package with a single, well-scoped responsibility — and each depends on the layer below it.

| Layer | Package | Version | Biological Analogue | Responsibility |
|---|---|---|---|---|
| **Core** | [**cell**](https://github.com/simon-m-lee/cell/tree/master/packages/cell) | `1.0.0-rc.6` | The **cell** | Reactive primitives (`Cell`, `Pulse`, `Receptor`, `Nucleus`, `Synapses`), validation gates (`TestCell`), authority context (`Context`), deputies, transactions, and the causal integrity engine. |
| **Orchestration** | [**cell_flow**](https://github.com/simon-m-lee/cell/tree/master/packages/cell_flow) | `1.0.0-rc.7` | The **nervous system** | 90+ Rx-shaped operators (`map`, `filter`, `debounce`, `throttle`, `switchMap`, `mergeMap`, `zip`, `retry`, `buffer`, …) as `FlowInstruction`s compiled into the *same* Cell graph — no translation layer. |
| **Application** | [**cell_tissue**](https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue) | `1.0.0-rc.7` | The **body** | Governed reactive collections (`TissueList`, `TissueSet`, `TissueMap`, `TissueQueue`, `TissueValue`) with validation, read-only views, deputies, capacity/backpressure, and async mutations. |

**Key insight:** the graph, locks, validation, and provenance live in **cell**. Flow only decides *which* pulses leave and *when*. Tissue decides *where they are recorded and under which invariants*. The layers compose without duplicating governance.

> 🌱 **Still dividing.** Like the biological process it is named after, Mitosis keeps growing. These three pillars are the foundation — more layers will come online as the ecosystem matures.

---

## 🧫 The Mitose Pipeline

**From a business requirement to a Mitosis solution, with an AI prompt agent as the operator.**

The umbrella repository ships the **Mitose pipeline** in [`guide/`](guide/HowTo-Mitose.md): a set of AI-executable scripts. A user provides a business requirement, and an AI prompt agent follows [`guide/HowTo-Mitose.md`](guide/HowTo-Mitose.md) to build a solution on the three pillars — **Cell** (core), **Flow** (orchestration), and **Tissue** (application) — and to write the project documents that go with it.

### How it runs

The agent follows the pipeline in order, with one human decision at each gate:

1. **BRD gate** — a Business Requirements Document must exist before anything else. The user can:
   - upload a filled `<stem>-BRD.md`,
   - fill [`Business_Requirements_Document(BRD).md`](guide/Business_Requirements_Document(BRD).md) offline,
   - take the guided interview in [`BRD-AI-Interview.md`](guide/BRD-AI-Interview.md), or
   - paste a short requirement paragraph for the agent to draft a BRD from.
2. **WalkThrough** — the agent follows [`WalkThrough-AI-Generator.md`](guide/WalkThrough-AI-Generator.md), consulting the layer HowTos to place every part, and writes `<stem>(Cell)-WalkThrough.md`. The user reviews and accepts it.
3. **Demo** — only after acceptance, the agent generates `<stem>(Cell)-Demo.dart`, treating the accepted WalkThrough as the behaviour contract and resolving live APIs from pub.dev.
4. **Assessment** — the agent revisits the WalkThrough against the actual Dart file and fills in the Demo Assessment and Recommendations.
5. **ARCHITECTURE & FEATURES** — offered last and generated only on request, from the running Demo (and the WalkThrough where required).

### What the pipeline produces

```text
<stem>-BRD.md
<stem>(Cell)-WalkThrough.md
<stem>(Cell)-Demo.dart
<stem>(Cell)-ARCHITECTURE.md
<stem>(Cell)-FEATURES.md
```

### The guide scripts

| Script | Role |
|---|---|
| [`HowTo-Mitose.md`](guide/HowTo-Mitose.md) | The orchestration script — runs the whole pipeline. |
| [`HowTo-Mitose-Cell.md`](guide/HowTo-Mitose-Cell.md) | Where a requirement lands in the **Cell** layer. |
| [`HowTo-Mitose-Flow.md`](guide/HowTo-Mitose-Flow.md) | Where a requirement lands in the **Flow** layer. |
| [`HowTo-Mitose-Tissue.md`](guide/HowTo-Mitose-Tissue.md) | Where a requirement lands in the **Tissue** layer. |
| [`BRD-AI-Interview.md`](guide/BRD-AI-Interview.md) | Guided interview that writes `<stem>-BRD.md`. |
| [`Business_Requirements_Document(BRD).md`](guide/Business_Requirements_Document(BRD).md) | Offline BRD template. |
| [`WalkThrough-AI-Generator.md`](guide/WalkThrough-AI-Generator.md) | Generates `<stem>(Cell)-WalkThrough.md`. |
| [`ARCHITECTURE-AI-Generator.md`](guide/ARCHITECTURE-AI-Generator.md) | Generates `<stem>(Cell)-ARCHITECTURE.md`. |
| [`FEATURES-AI-Generator.md`](guide/FEATURES-AI-Generator.md) | Generates `<stem>(Cell)-FEATURES.md`. |

Start the pipeline by opening [`guide/HowTo-Mitose.md`](guide/HowTo-Mitose.md) with an AI prompt agent, or by saying “Mitose” / “run Mitose” in chat.

### Start in one paste

If your AI chat tool does not auto-load the repository, paste this and replace the last line:

```text
Read guide/HowTo-Mitose.md and run the Mitose pipeline.
The repository is the cell workspace.
My business requirement is: <paste your requirement here>
```

In an agentic IDE (Copilot, Codex, Cursor, …), just open the repository and say “Mitose” — [`AGENTS.md`](AGENTS.md) tells the agent what to do.

### Try a sample BRD

[`example/BRD/`](example/BRD) ships ready-made BRDs from different industries — airport baggage handling, assembly-line downtime & defect monitoring, freight rail intermodal, and hospital emergency-department capacity/flow. Read them to get familiar with the BRD format, or hand one to the agent to run the whole pipeline right away:

```text
Read guide/HowTo-Mitose.md and run the Mitose pipeline.
Use example/BRD/airport_baggage_handling-BRD.md as the BRD.
```

---

## 📦 Repository Layout

```text
cell/                          # Umbrella monorepo: "Mitosis"
├── guide/                     # Mitose pipeline — AI-executable orchestration scripts
│   ├── HowTo-Mitose.md        #   Pipeline orchestration: BRD → WalkThrough → Demo → ARCHITECTURE/FEATURES
│   ├── HowTo-Mitose-Cell.md   #   Cell layer placement rules
│   ├── HowTo-Mitose-Flow.md   #   Flow layer placement rules
│   ├── HowTo-Mitose-Tissue.md #   Tissue layer placement rules
│   ├── BRD-AI-Interview.md    #   Guided BRD interview
│   ├── Business_Requirements_Document(BRD).md
│   ├── WalkThrough-AI-Generator.md
│   ├── ARCHITECTURE-AI-Generator.md
│   └── FEATURES-AI-Generator.md
├── packages/
│   ├── cell/                  # Core layer — reactive primitives & causal integrity
│   │   ├── lib/               #   cell.dart, pulse, receptor, nucleus, synapses…
│   │   ├── example/           #   Runnable demos (state, asyncMap, transaction…)
│   │   ├── guide/             #   HowTo-*.md learning path
│   │   └── test/
│   ├── cell_flow/             # Orchestration layer — 90+ Flow operators
│   │   ├── lib/               #   flow.dart, flow_core, fluent_operator, instruction/
│   │   ├── example/           #   Search, checkout, ICU alarm, batching demos…
│   │   ├── guide/
│   │   └── test/
│   └── cell_tissue/           # Application layer — reactive collections
│       ├── lib/               #   tissue_list, tissue_map, tissue_queue, …
│       ├── example/           #   Flow + Tissue seam demos (payments, dispatch, grid)
│       ├── guide/
│       └── test/
├── example/                   # Umbrella demos — (Cell) instruction-side editions
│   ├── card-auth-pipeline(Cell)-*   #   stock-operator FlowInstructionChain
│   ├── grid-demand-response(Cell)-* #   custom GridDecisionInstruction
│   ├── ride-hail-dispatch(Cell)-*   #   custom MatchDecisionInstruction
│   ├── *-BRD.md               #   BRD companions for the (Cell) demos
│   └── BRD/                   #   Sample BRDs by industry — learn the format, or run Mitose right away
├── DEMO_GUIDE-Mitosis.md      # Mitosis demo guide (decision-side learning path)
├── melos.yaml                 # Monorepo scripts (analyze, test, format, build)
├── pubspec.yaml               # Dart workspace definition (pub workspaces)
├── CHANGELOG.md
├── AGENTS.md                  # AI-agent instructions — the "Mitose" trigger
├── AUTHORS
└── LICENSE
```

The repository is managed with **[Melos](https://melos.invertase.dev/)** on top of Dart's native **pub workspaces**.

---

## 🏗️ Architecture Philosophy

Mitosis uses a biological metaphor to separate concerns while keeping a strict forensic trail:

```text
┌──────────────────────────────────────────────────────────────────────┐
│  APPLICATION LAYER  (Tissue)      The "Body"                         │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                  │
│  │ TissueList   │ │ TissueSet    │ │ TissueMap    │                  │
│  │ (Ordered)    │ │ (Unique)     │ │ (Key-Value)  │                  │
│  └──────────────┘ └──────────────┘ └──────────────┘                  │
│  ┌──────────────┐ ┌──────────────┐                                   │
│  │ TissueQueue  │ │ TissueValue  │   Governed collections:           │
│  │ (FIFO/bound) │ │ (Scalar)     │   observable · validated ·        │
│  └──────────────┘ └──────────────┘   deputy-able · thread-safe       │
├──────────────────────────────────────────────────────────────────────┤
│  ORCHESTRATION LAYER  (Flow)       The "Nervous System"              │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  90+ operators: map, filter, debounce, throttle, asyncMap,     │  │
│  │  switchMap, mergeMap, concatMap, exhaustMap, zip, combineLatest│  │
│  │  groupBy, bufferCount, retry, timeout, sample, scan, …         │  │
│  └────────────────────────────────────────────────────────────────┘  │
│  Decides WHICH pulses leave and WHEN — nothing more.                 │
├──────────────────────────────────────────────────────────────────────┤
│  CORE LAYER  (Cell)                The "Cell / DNA"                  │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  Cell, Pulse, Receptor, Synapses, Nucleus, TestCell, Context,  │  │
│  │  Deputy, Modifiable, transactions, causal integrity engine     │  │
│  └────────────────────────────────────────────────────────────────┘  │
│  Owns the graph, the locks, the validation, and the provenance.      │
└──────────────────────────────────────────────────────────────────────┘
        ▲                                                              ▲
        └────────────  one graph · one causal trail · one DNA  ────────┘
```

**One DNA across all three layers.** The same graph, locks, validation, and provenance are shared by Cell, Flow, and Tissue — every layer you build on top inherits the same causal guarantees instead of re-inventing them.

---

## 🧭 Design Principles

These are the non-negotiables that shape every package in the monorepo:

1. **Progressive disclosure.** A counter app needs only `Cell.state`. You should not have to learn `Nucleus`, `TestCell`, or `Synapses` until you need them. Defaults are pass-through and allow-all.
2. **Causal integrity.** Every state transition travels as an immutable `Pulse` that carries what changed, what caused it, and the context/authority under which it occurred. The trail is a property of the graph, not a logging afterthought.
3. **Governance as a gate, not a callback.** Validation (`TestCell`, `TestTissue`) is enforced by the graph before a mutation commits — it cannot be forgotten.
4. **Deputies narrow authority.** Share restricted, read-only, or ephemeral views of the same data (`deputy`, `unmodifiable`) without copying it. A deputy can only *narrow* what the principal allows — never widen it.
5. **Forensic traceability.** Pulses, provenance, and context make systems auditable and reconstructable — a chain of computation you can inspect, not just a final value.
6. **Biological scaling.** Each layer is a *scale of composition*, not a feature silo. Higher layers inherit the DNA of lower layers instead of replacing it.

---

## 🚀 Quick Start

### Prerequisites

- **Dart SDK**: `>=3.6.0 <4.0.0` for the workspace root (individual packages allow `>=3.5.0`).
- **Melos**: install globally to manage the monorepo:

```bash
dart pub global activate melos
```

### Using from pub.dev

The umbrella package re-exports all three layers in one import:

```yaml
dependencies:
  mitosis: ^1.0.0-rc.9
```

```dart
import 'package:mitosis/mitosis.dart';
```

Prefer the individual layers when you want fine-grained dependencies:

```yaml
dependencies:
  cell: ^1.0.0-rc.6
  cell_flow: ^1.0.0-rc.7
  cell_tissue: ^1.0.0-rc.7
```

The workspace setup below is only needed for contributors working on the framework itself.

### Workspace Setup

```bash
# 1. Clone the repository
git clone https://github.com/simon-m-lee/cell.git
cd cell

# 2. Bootstrap the workspace (install dependencies + cross-link local packages)
melos bootstrap

# 3. Verify everything is healthy
melos analyze
melos test
```

### Hello Mitosis — all three layers in one flow

The canonical pattern: **Flow decides. Tissue records. The observer is the only glue.**

```dart
import 'package:cell_flow/cell_flow.dart';     // Cell + Flow operators
import 'package:cell_tissue/cell_tissue.dart'; // Tissue collections

Future<void> main() async {
  // 1. CELL — events enter the graph through an ingress
  final commands = Cell.ingress<String>();

  // 2. FLOW — orchestration: normalize, gate, deduplicate, debounce
  final accepted = commands.cell
      .map<String, String>(project: (c) => c.trim())
      .filter<String>(test: (c) => c.isNotEmpty)
      .distinct<String>()
      .debounce<String>(duration: const Duration(milliseconds: 150));

  // 3. TISSUE — application state: a governed, observable collection
  final ledger = TissueList.of(<String>[]);

  Cell.observe(
    source: accepted.cell,
    effect: (pulse) => ledger.add('ACCEPTED: ${pulse.payload}'),
  );

  await commands.emitAsync('  deploy mitosis  ');
  await commands.emitAsync('  deploy mitosis  '); // distinct + debounce

  await Future<void>.delayed(const Duration(milliseconds: 200));
  print(ledger); // [ACCEPTED: deploy mitosis]
}
```

Each package's README has deeper walkthroughs:

- [`packages/cell/guide/HowTo-Start.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell/guide/HowTo-Start.md) — core concepts
- [`packages/cell_flow/guide/HowTo-Start.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/guide/HowTo-Start.md) — 15-minute pipeline tutorial
- [`packages/cell_tissue/README.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/README.md) — collections, deputies, and the Flow + Tissue seam

---

## 🛠️ Development Commands

Melos scripts run across every package in the workspace:

| Task | Command | Description |
|---|---|---|
| **Analyze** | `melos analyze` | Static analysis on all packages |
| **Test** | `melos test` | Run all package test suites |
| **Format** | `melos format` | Format the entire codebase |
| **Build** | `melos build` | Regenerate generated code (build_runner) |
| **Lint** | `melos lint` | Alias for `melos analyze` |
| **Check all** | `melos check` | Run analysis **and** tests |
| **Clean** | `melos clean` | Clean all packages |

Single-package workflows are also supported, e.g.:

```bash
cd packages/cell_flow
dart test
dart run example/stability_search_demo.dart
```

---

## 📚 Documentation Map

| Document | What it is |
|---|---|
| [packages/cell/README.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell/README.md) | Core layer: operators, governance, deputies, transactions |
| [packages/cell_flow/README.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/README.md) | Orchestration layer: full operator catalog, patterns, testing |
| [packages/cell_tissue/README.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/README.md) | Application layer: collections, validation, Flow + Tissue seam |
| [DEMO_GUIDE-Mitosis.md](https://github.com/simon-m-lee/cell/blob/master/DEMO_GUIDE-Mitosis.md) | Mitosis demo guide — the `(Cell)` instruction-side learning path |
| [guide/HowTo-Mitose.md](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose.md) | Mitose pipeline orchestration — AI-executable script: BRD → WalkThrough → Demo → ARCHITECTURE/FEATURES |
| [guide/HowTo-Mitose-Cell.md](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Cell.md) · [Flow](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Flow.md) · [Tissue](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Tissue.md) | Layer placement guides the Mitose pipeline consults |
| [guide/BRD-AI-Interview.md](https://github.com/simon-m-lee/cell/blob/master/guide/BRD-AI-Interview.md) · [BRD template](https://github.com/simon-m-lee/cell/blob/master/guide/Business_Requirements_Document(BRD).md) | BRD interview script and offline template |
| [guide/WalkThrough-AI-Generator.md](https://github.com/simon-m-lee/cell/blob/master/guide/WalkThrough-AI-Generator.md) · [ARCHITECTURE](https://github.com/simon-m-lee/cell/blob/master/guide/ARCHITECTURE-AI-Generator.md) · [FEATURES](https://github.com/simon-m-lee/cell/blob/master/guide/FEATURES-AI-Generator.md) | Document generators: WalkThrough, ARCHITECTURE, FEATURES |
| [example/BRD/](https://github.com/simon-m-lee/cell/tree/master/example/BRD) | Sample BRDs by industry — learn the BRD format, or run the Mitose pipeline right away |
| [CHANGELOG.md](https://github.com/simon-m-lee/cell/blob/master/CHANGELOG.md) | Umbrella release history |

> If a guide and the source disagree, **the source is current**.

---

## 📌 Project Status & Cadence

| Package | Version | Status |
|---|---|---|
| `mitosis` | `1.0.0-rc.9` | Release Candidate — on pub.dev |
| `cell` | `1.0.0-rc.6` | Release Candidate — on pub.dev |
| `cell_flow` | `1.0.0-rc.7` | Release Candidate — on pub.dev |
| `cell_tissue` | `1.0.0-rc.7` | Release Candidate — on pub.dev |

**Mitosis** is the umbrella codename for the release line. It is *not* part of the SemVer string. All three pillars — `cell`, `cell_flow`, and `cell_tissue` — are published on pub.dev under the `1.0.0` RC line; the stable `1.0.0` release is next. Breaking changes remain possible before `1.0.0` stable.

---

## 🔭 Vision & Roadmap

Mitosis is not aiming to be "another state-management library". The ambition is a **layered platform for causally intelligible reactive systems** — where application behavior is composable, traceable, governable, and explainable from the same graph.

The **Mitose pipeline** in [`guide/`](guide/HowTo-Mitose.md) is the first agentic workflow shipped with the project — an AI prompt agent turns a business requirement into a Cell + Flow + Tissue solution and its full document set. It is how this umbrella repository is meant to be operated day to day.

### Target domains

Mitosis pays for itself first in systems where the causal trail is a requirement, not a nicety:

- 💳 **Payments & fintech** — holds, captures, invariants (`available + held + captured == constant`)
- 🏥 **Safety-critical telemetry** — alarm pipelines, sensor fusion, escalation logic
- ⚡ **Energy & real-time grids** — demand response, shed/restore decisions, audit logs
- 🚗 **Mobility & dispatch** — matching, surge control, trip logs
- 🔐 **Security-sensitive services** — authority tiers, redaction, restricted deputies
- 🤖 **Agents & automation** — tool-call graphs with traceable intent and effect

---

## 🧾 Honest Caveats

Mitosis is an RC. Some things to know before you bet production on it:

- **APIs may still change** before `1.0.0` stable.
- **`Context` metadata is not a compliance certification.** `Context.describe(...)` stores classification, actor, and purpose text; it does not implement or certify GDPR, HIPAA, PCI-DSS, or any other regulation.
- **Some Tissue behaviors are build-dependent** (observer delivery on tissue cells, `.unmodifiable` liveliness, queue draining). Verify against current source and demo headers before relying on them — see the [cell_tissue README](https://github.com/simon-m-lee/cell/blob/master/packages/cell_tissue/README.md).
- **The framework is deliberately layered.** For a couple of flags or a single form, plain Dart or a lightweight notifier may be the better tool. Mitosis earns its complexity at scale.

---

## 🤝 Contributing

Contributions are welcome across all layers:

1. Fork the repository and create a topic branch.
2. Run `melos analyze` and `melos test` locally.
3. Add tests for new behavior.
4. Submit a pull request with a clear description.

See the individual package READMEs for package-specific conventions.

---

## 📄 License

Dual-licensed under either of:

- **MIT License**
- **Apache License, Version 2.0**

See the [LICENSE](https://github.com/simon-m-lee/cell/blob/master/LICENSE) file for full text. Operator *names* follow ReactiveX vocabulary; implementations are original.

---

## 👤 Authors

Lee Man Hoi Simon — see [AUTHORS](https://github.com/simon-m-lee/cell/blob/master/AUTHORS) for copyright holders.

---

## 🔗 Links

- 🏠 **Repository:** [github.com/simon-m-lee/cell](https://github.com/simon-m-lee/cell)
- 🐛 **Issues:** [github.com/simon-m-lee/cell/issues](https://github.com/simon-m-lee/cell/issues)
- 📦 **pub.dev:** [cell](https://pub.dev/packages/cell) · [cell_flow](https://pub.dev/packages/cell_flow) · [cell_tissue](https://pub.dev/packages/cell_tissue)
- 📖 **Core layer:** [packages/cell](https://github.com/simon-m-lee/cell/tree/master/packages/cell)
- 🔀 **Orchestration layer:** [packages/cell_flow](https://github.com/simon-m-lee/cell/tree/master/packages/cell_flow)
- 🧩 **Application layer:** [packages/cell_tissue](https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue)

---

*Mitosis — reactive state that remembers how it got there.*
