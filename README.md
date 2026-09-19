# Mitosis

> **Formerly the Cell Framework.** One reactive graph. Three layers. Zero broken causal chains.

[![License](https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-blue.svg)](https://github.com/simon-m-lee/cell/blob/master/LICENSE)
[![Dart SDK](https://img.shields.io/badge/dart-%3E%3D3.5.0%20%3C4.0.0-blue.svg)](https://dart.dev)
[![Status](https://img.shields.io/badge/status-1.0.0--rc.6-yellow.svg)](#-project-status--cadence)
[![Melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg)](https://github.com/invertase/melos)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#-contributing)

**Mitosis** is a reactive application framework for Dart that treats state, events, and their **causal history** as one coherent, observable graph. It is an umbrella monorepo built from three layers — **Cell**, **Flow**, and **Tissue** — that scale from a single reactive value to a fully governed application body without ever dropping the forensic trail.

Mitosis is designed for systems where *why something happened* matters as much as *what happened*: financial and transaction-heavy software, security-sensitive services, audit-bound enterprise applications, real-time coordination, and increasingly, autonomous and multi-agent systems.

---

## Table of Contents

- [Why the name "Mitosis"?](#-why-the-name-mitosis)
- [The Three Pillars](#-the-three-pillars)
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
| **Core** | [**cell**](https://github.com/simon-m-lee/cell/tree/master/packages/cell) | `1.0.0-rc.5` | The **cell** | Reactive primitives (`Cell`, `Pulse`, `Receptor`, `Nucleus`, `Synapses`), validation gates (`TestCell`), authority context (`Context`), deputies, transactions, and the causal integrity engine. |
| **Orchestration** | [**cell_flow**](https://github.com/simon-m-lee/cell/tree/master/packages/cell_flow) | `1.0.0-rc.6` | The **nervous system** | 90+ Rx-shaped operators (`map`, `filter`, `debounce`, `throttle`, `switchMap`, `mergeMap`, `zip`, `retry`, `buffer`, …) as `FlowInstruction`s compiled into the *same* Cell graph — no translation layer. |
| **Application** | [**cell_tissue**](https://github.com/simon-m-lee/cell/tree/master/packages/cell_tissue) | `1.0.0-rc.5` | The **body** | Governed reactive collections (`TissueList`, `TissueSet`, `TissueMap`, `TissueQueue`, `TissueValue`) with validation, read-only views, deputies, capacity/backpressure, and async mutations. |

**Key insight:** the graph, locks, validation, and provenance live in **cell**. Flow only decides *which* pulses leave and *when*. Tissue decides *where they are recorded and under which invariants*. The layers compose without duplicating governance.

> 🌱 **Still dividing.** Like the biological process it is named after, Mitosis keeps growing. These three pillars are the foundation — more layers will come online as the ecosystem matures.

---

## 📦 Repository Layout

```text
cell/                          # Umbrella monorepo: "Mitosis"
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
├── DEMO_GUIDE-Mitosis.md      # Mitosis demo guide (decision-side learning path)
├── melos.yaml                 # Monorepo scripts (analyze, test, format, build)
├── pubspec.yaml               # Dart workspace definition (pub workspaces)
├── CHANGELOG.md
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
  mitosis: ^1.0.0-rc.5
```

```dart
import 'package:mitosis/mitosis.dart';
```

Prefer the individual layers when you want fine-grained dependencies:

```yaml
dependencies:
  cell: ^1.0.0-rc.5
  cell_flow: ^1.0.0-rc.6
  cell_tissue: ^1.0.0-rc.5
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
| [CHANGELOG.md](https://github.com/simon-m-lee/cell/blob/master/CHANGELOG.md) | Umbrella release history |

> If a guide and the source disagree, **the source is current**.

---

## 📌 Project Status & Cadence

| Package | Version | Status |
|---|---|---|
| `mitosis` | `1.0.0-rc.6` | Release Candidate — on pub.dev |
| `cell` | `1.0.0-rc.5` | Release Candidate — on pub.dev |
| `cell_flow` | `1.0.0-rc.6` | Release Candidate — on pub.dev |
| `cell_tissue` | `1.0.0-rc.5` | Release Candidate — on pub.dev |

**Mitosis** is the umbrella codename for the release line. It is *not* part of the SemVer string. All three pillars — `cell`, `cell_flow`, and `cell_tissue` — are published on pub.dev under the `1.0.0` RC line; the stable `1.0.0` release is next. Breaking changes remain possible before `1.0.0` stable.

---

## 🔭 Vision & Roadmap

Mitosis is not aiming to be "another state-management library". The ambition is a **layered platform for causally intelligible reactive systems** — where application behavior is composable, traceable, governable, and explainable from the same graph.

### How the platform grows

The three pillars define the roadmap. New capability lands inside the layer that already owns it — Cell stays the reactive core, Flow stays the orchestration layer, Tissue stays the governed body.

| Horizon | Cell | Flow | Tissue |
|---|---|---|---|
| **Now (RC)** | Reactive core: state, pulses, governance | 90+ orchestration operators | Reactive, validated collections |
| **Next (post-1.0)** | Multi-isolate cells | Deeper combinators, backpressure | Causal replay & state snapshots |
| **Later** | Distributed cells | Cross-runtime flows | Digital-twin state fabrics |

### Phase 1 — Stabilize the RC line (toward `1.0.0`)

- **API freeze** across `cell`, `cell_flow`, and `cell_tissue` after the RC cycle.
- **Full test matrix** and coverage reporting for every package.
- **Flutter adapters & recipes** — bind cells, flows, and tissues to widgets with minimal glue.
- **Stable `1.0.0` release** — all three pillars are already on pub.dev under the RC line; the stable release is next.

### Phase 2 — Deepen the platform (post-`1.0.0`)

- **Causal replay & simulation** — reconstruct any historical state by replaying the pulse chain; run "what-if" branches against Tissue state.
- **Multi-isolate & distributed cells** — flows and tissues that cross isolate or network boundaries while preserving provenance.
- **Storage & persistence adapters** — snapshot and restore graph state without leaving the causal model.
- **Developer tooling** — a visual graph debugger, CLI scaffolding, and IDE support that render the causal trail in real time.
- **Performance & memory work** — zero-copy views, lock refinements, and large-graph benchmarks.

### Phase 3 — A runtime for complex, autonomous systems (long term)

- **Multi-agent orchestration** — an agent, its tool calls, and its effects modeled as cells, flows, and tissues; agentic systems become inspectable, governable graphs.
- **Edge / serverless deployment** — migrate cells and tissues across runtime boundaries without losing lineage.
- **Digital twins & complex adaptive simulations** — large networks of governed tissues with emergent behavior from local rules.
- **Compliance-grade audit pipelines** — provenance and context feeding formal audit, attestation, and verification tooling.

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
