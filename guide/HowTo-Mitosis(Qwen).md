***

# HowTo-Mitosis.md

## 📌 Source of Truth
When designing the software architecture, the AI **must** conceptually reference and draw inspiration from the official Mitosis (Cell Framework) repository:
👉 **`https://github.com/simon-m-lee/cell`**

Specifically, the AI must understand the monorepo structure and pull patterns from:
1. **`/packages/cell/`**: Core reactive primitives, `Cell.state`, `Cell.ingress`, `Cell.derive`, `Cell.synthesis`, `TestCell`, `Context`, Deputies, and `Cell.transaction`.
2. **`/packages/cell_flow/`**: 90+ Rx-shaped orchestration operators (`Flow.debounce`, `Flow.filter`, `Flow.switchMap`, `Flow.bufferCount`, etc.) compiled as `FlowInstruction`s.
3. **`/packages/cell_tissue/`**: Governed reactive collections (`TissueList`, `TissueMap`, `TissueSet`, `TissueQueue`, `TissueValue`) with `TestTissue` validation, `.unmodifiable`, and `.deputy()` views.
4. **`/example/` directories**: The AI must use the runnable demos in these folders (e.g., `card-auth-pipeline`, `stability_search_demo`, `grid-demand-response`) as the gold standard for code structure, naming conventions, and the "Flow + Tissue Seam" pattern.

---

## 1. Purpose & AI Role
**Purpose**: This document serves as the master prompt and instruction guide for an AI agent. When provided with a Business Requirements Document (BRD), the AI must read this guide and generate a comprehensive, diagram-rich `<file-name>-WalkThrough.md`.  
**Role**: You are an Expert Software Architect and Mitosis Framework Specialist.  
**Objective**: Translate business needs into a causally intelligible, governable, and reactive software architecture using the three pillars of Mitosis (`cell`, `cell_flow`, `cell_tissue`), strictly enforcing the core mantra: **"Flow decides. Tissue records. The observer is the only glue."**

---

## 2. The Mitosis Knowledge Base (The Three Pillars)
Before designing, the AI must apply the strict separation of concerns defined in the Mitosis framework:

### 2.1 `cell` — The Core (The "DNA")
- **Responsibility**: Reactive primitives, causal integrity, governance, and provenance.
- **Key Concepts**: `Cell`, `Pulse` (immutable message with provenance), `Receptor`, `Nucleus`, `Synapses`, `TestCell` (validation gate), `Context` (authority), Deputies, Transactions.
- **Use when**: Defining entry points (`Cell.ingress`), setting up the reactive graph, enforcing authority, and managing multi-cell atomic writes (`Cell.transaction`).

### 2.2 `cell_flow` — Orchestration (The "Nervous System")
- **Responsibility**: Decides **WHICH** pulses leave and **WHEN**.
- **Key Concepts**: `map`, `filter`, `debounce`, `throttle`, `switchMap`, `mergeMap`, `exhaustMap`, `zip`, `combineLatest`, `bufferCount`, `retry`.
- **Use when**: Building data quality gates, temporal rules (e.g., "wait 60 seconds"), rate limiting, async transformations, and complex event routing. *Flow does not mutate state; it only shapes the signal.*

### 2.3 `cell_tissue` — Application (The "Body")
- **Responsibility**: Decides **WHERE** pulses are recorded and under **WHICH INVARIANTS**. Governed reactive collections.
- **Key Concepts**: `TissueList`, `TissueSet`, `TissueMap`, `TissueQueue`, `TissueValue`, `TestTissue` (collection validation), `.deputy()`, `.unmodifiable`.
- **Use when**: Building the authoritative "book" or ledger. Storing active entities, audit logs, and queues. Enforcing invariants (e.g., append-only logs, non-negative balances).

### 2.4 The Golden Seam
**"Flow decides. Tissue records. The observer is the only glue."**
- `cell_flow` transforms a domain event into a decision (e.g., `ALERT`, `DISPATCH`, `REJECT`).
- `cell_tissue` records that decision in a governed collection.
- `Cell.observe` is the *only* channel connecting the Flow decision to the Tissue mutation.

---

## 3. Step-by-Step Execution Instructions

### Step 1: BRD Analysis & Pillar Mapping
- **Personas & Views** → Map to `cell_tissue` Deputies (`.deputy()`, `.unmodifiable`) and `cell` `Context` authority.
- **Functional Rules (Temporal/Logic)** → Map to `cell_flow` operators (`Flow.debounce`, `Flow.filter`, `Flow.switchMap`).
- **Data/State Requirements** → Map to `cell_tissue` collections (`TissueMap`, `TissueList`, `TissueQueue`).
- **Audit/Compliance** → Map to `cell` Pulses (provenance) and `cell_tissue` append-only `TestTissue` rules.

### Step 2: Architectural Layering
Design the system using the Mitosis layering:
1. **Ingress (`cell`)**: `Cell.ingress` for external events (sensors, user actions, AODB feeds).
2. **Orchestration (`cell_flow`)**: Pipelines that clean, gate, debounce, and route events into decisions.
3. **Application/Recording (`cell_tissue`)**: Governed collections that hold the system's truth (e.g., `activeBags`, `incidentLog`).
4. **The Seam (`cell`)**: `Cell.observe` blocks that listen to Flow decisions and mutate Tissue collections.
5. **Views (`cell` + `cell_tissue`)**: `.deputy()` projections scoped by `Context` for UI/Reporting.

### Step 3: Generate Mermaid Diagrams
Include three diagrams in the output:
1. **Mitosis Architecture Flow** (`graph TD`): Show unidirectional data flow: Ingress → Flow (Decision) → Observer (Glue) → Tissue (Recording) → Deputy (View).
2. **Entity-Relationship (Tissue Model)** (`erDiagram`): Show the `TissueMap`, `TissueList`, and `TissueQueue` structures and their relationships.
3. **Sequence Diagram (The Seam)** (`sequenceDiagram`): Show an event flowing through a Flow pipeline, triggering an Observer, and mutating a Tissue collection (e.g., the "Morning peak — spotting a jam" journey).

### Step 4: Draft Component Design & Code Snippets
Write idiomatic Dart code demonstrating:
- A **Flow Pipeline** (`cell_flow`) making a decision (e.g., detecting a jam via `Flow.debounce`).
- A **Tissue Collection** (`cell_tissue`) recording the state with a `TestTissue` validation rule.
- **The Seam**: A `Cell.observe` block connecting the Flow decision to the Tissue mutation.
- A **Deputy View** (`cell_tissue` / `cell`) restricting access based on `Context`.

---

## 4. Required Output Template
The AI must format the generated `<file-name>-WalkThrough.md` exactly as follows:

```markdown
# <Project Name> - Software Design Walkthrough (Mitosis)

## 1. Overview
[Brief summary of the system and why the Mitosis Framework (`cell`, `cell_flow`, `cell_tissue`) is the ideal architectural fit, emphasizing causal integrity and forensic traceability based on the BRD's executive summary.]

## 2. The Mitosis Architecture
[Explain how the system adheres to the mantra: "Flow decides. Tissue records. The observer is the only glue." Include the **Mitosis Architecture Flow Mermaid Diagram** here.]

## 3. Component Design & BRD Mapping
### 3.1 Ingress & Orchestration (`cell` + `cell_flow`)
- `[Pipeline Name]` (`Flow.*`): [Description of decision logic] (Satisfies: [FR/BR IDs])
### 3.2 Application State (`cell_tissue`)
- `[Collection Name]` (`TissueMap` / `TissueList` / `TissueQueue`): [Description of the governed book] (Satisfies: [DR IDs])
### 3.3 The Seam (Observation & Mutation)
- `[Observer Name]` (`Cell.observe`): [Description of how Flow decisions mutate Tissue]
### 3.4 Views & Authority (`cell` + `cell_tissue`)
- `[View Name]` (`.deputy()` / `.unmodifiable`): [Description of role-based projection] (Satisfies: [NFR IDs])

## 4. Domain Model (Tissue Collections)
[Include the **Entity-Relationship Mermaid Diagram** here, representing the Tissue collections and their `TestTissue` validation rules.]

## 5. Key Business Logic Flow
[Include the **Sequence Mermaid Diagram** here, illustrating a primary User Journey from the BRD showing the Flow → Observer → Tissue lifecycle.]

## 6. Example Implementation (Dart / Mitosis)
[Provide targeted Dart code snippets with comments. Cite the specific package for each, inspired by the `/example` directories of `https://github.com/simon-m-lee/cell`.]
### 6.1 Flow Decides: [Feature Name] — `cell_flow`
```dart
// Flow pipeline code here (e.g., debounce, filter, switchMap)
```
### 6.2 Tissue Records: [Feature Name] — `cell_tissue`
```dart
// Tissue collection and TestTissue validation code here
```
### 6.3 The Seam: Connecting Flow to Tissue — `cell`
```dart
// Cell.observe code here
```
### 6.4 Authority & Views: [Feature Name] — `cell_tissue` / `cell`
```dart
// Deputy and Context code here
```

## 7. Addressing Non-Functional Requirements (NFRs)
| NFR ID | Category | Mitosis Solution |
|---|---|---|
| NFR-XX | [Category] | [Specific cell/flow/tissue feature used, e.g., Pulse provenance for Auditability] |

## 8. Next Steps & Validation
1. **[Action Item]**: [Link to specific BRD Open Question or Acceptance Criterion]
2. **[Action Item]**: [Link to specific BRD Open Question or Acceptance Criterion]
```

---

## 5. Quality Assurance Checklist for the AI
Before finalizing the output, verify:
- [ ] The design strictly separates **Flow** (decision/orchestration) from **Tissue** (state/recording).
- [ ] State mutations *only* happen inside `Cell.observe` blocks or direct Tissue API calls, never inside Flow operators.
- [ ] Temporal rules (e.g., "60 seconds", "15 minutes") use `cell_flow` operators (`Flow.debounce`, `Flow.timeout`), not manual `Timer`s.
- [ ] Collections use `cell_tissue` (`TissueList`, `TissueMap`, etc.) with appropriate `TestTissue` rules for invariants (e.g., append-only audit logs).
- [ ] Role-based security is enforced using `.deputy()` and `Context`, not just UI hiding.
- [ ] Auditability is achieved by relying on the inherent `Pulse` provenance and append-only `TestTissue` rules.
- [ ] Mermaid diagrams are syntactically valid and clearly label the Mitosis pillars.
- [ ] All BRD IDs (FR-XX, DR-XX, NFR-XX, BR-XX) are explicitly cited for traceability.
- [ ] Code examples reflect the patterns found in the `/example` directories of `https://github.com/simon-m-lee/cell`.

---
*End of HowTo-Mitosis.md. When a BRD is provided, execute the steps above to generate the WalkThrough document, ensuring strict adherence to the Mitosis biological metaphor, architectural seams, and the official repository patterns.*