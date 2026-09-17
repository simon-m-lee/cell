# HowTo — Mitosis: AI instructions for turning one requirement paragraph into the four-document set

**Where this file lives:** it ships in the `example/` folder of the
`mitosis` package on pub.dev and is visible at
`https://pub.dev/packages/mitosis/example`.

**For the human (start here).** Open the Example tab, look at any
`*-Demo.dart` header comment to see what the finished set looks like,
then copy the **Simple instruction** below into any AI chat. That is
the only step you perform.

**For the AI.** This file is your instruction set. Follow §2 exactly,
produce the four artifacts in the fixed order, and stop only when the
§7 checklist passes.

### Simple instruction (copy this into an AI chat)

```text
Using the published pub.dev packages cell, cell_flow and cell_tissue,
read example/HowTo-Mitosis.md and follow it. Turn the requirement below
into the four-document set.

Inputs:
<the parameters the Cell receives>

Output requirement:
<what the Cell emits as Pulse<type> and the behaviour it must implement>
```

The reactive stack is codenamed **Mitosis** (core `Cell`, orchestration
`Flow`, application `Tissue`). The **Mitosis** workflow is the repeatable
interaction that expands one requirement paragraph into the
**four-document set**:

| # | Document | Question it answers |
|---|---|---|
| 1 | `*-WalkThrough.md` | What must the executable do? (requirement + acceptance) |
| 2 | `*-Demo.dart` | How does it run, with Cell + Flow + Tissue? (executable) |
| 3 | `*-ARCHITECTURE.md` | Why is it shaped this way? (seam, locks, failure) |
| 4 | `*-FEATURES.md` | What does it demonstrate, feature by feature? (catalogue) |

The **template example** the AI imitates is the
`card-auth-pipeline(Cell)-*` set in `example/`. Its Demo header, its
WalkThrough section order, its ARCHITECTURE rationale, and its FEATURES
catalogue are the canonical shape every new domain copies.

---

## 1. The input: one paragraph of requirement

The grid demand-response set began as the block at the top of
`grid-demand-response(tissue)-WalkThrough.md` — nothing more:

> **Industry:** electric power — transmission-desk demand response
> (the thing grid operators actually do when system frequency sags:
> shed interruptible load, protect hospitals, restore after the
> operator ACK). Think ERCOT / National Grid / CAISO control room,
> not a smart-thermostat app.
>
> **Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`
>
> This is the **executable requirement** for an energy-ops demo that
> uses **Flow for the shed decision** and **Tissue for the feeder
> books**. Implement the Dart file so a last-good run prints the
> scenario table in § Scenarios.
>
> Do not fold Tissue into the Receptor. Do not fold Flow into the
> event log. The point of this file is the seam.
>
> Why this industry: frequency, megawatts, and “never drop feeder
> HOSP-1” are a different physics and a different regulator. Two
> products still: **SHED** (open interruptible load) vs **WARN**
> (yellow band). ACK is the shift lead restoring the bay. The
> reliability council reads the log and cannot delete a row.

Every word in that paragraph is load-bearing. The rest of the process
is the act of making each word structural.

---

## 2. Initiating the process at the AI chat prompt

The AI reads this section as its execution order. In the beginning
there is only the requirement — a paragraph pasted into the chat. No
pubspec, no scaffold, no WalkThrough file. The AI pulls the published
packages into a fresh project, creates the executable, and then expands
the `.md` document set around it in a fixed order.

### Template example to follow

Before generating anything, the AI opens the `card-auth-pipeline(Cell)-*`
set in `example/` and uses it as the structural template:

| To generate | Imitate |
|---|---|
| `<file_name>-Demo.dart` | `card-auth-pipeline(Cell)-Demo.dart` |
| `<file_name>-WalkThrough.md` | `card-auth-pipeline(Cell)-WalkThrough.md` |
| `<file_name>-ARCHITECTURE.md` | `card-auth-pipeline(Cell)-ARCHITECTURE.md` |
| `<file_name>-FEATURES.md` | `card-auth-pipeline(Cell)-FEATURES.md` |

The card-auth set demonstrates the full seam (Flow decision, Tissue
books, deputy, money protocol, scenario runner). The grid
demand-response set is only this document's worked example for mining a
paragraph; when in doubt about structure, follow card-auth.

### The packages are already on pub.dev

`cell`, `cell_flow`, and `cell_tissue` are published packages, so the
AI's first action is dependency resolution, not package authoring:

```bash
dart pub add cell cell_flow cell_tissue
```

or, equivalently, the AI writes into `pubspec.yaml`:

```yaml
dependencies:
  cell: ^1.0.0-rc.5
  cell_flow: ^1.0.0-rc.5
  cell_tissue: ^1.0.0-rc.5
```

The AI should let `dart pub add` resolve the current compatible
versions rather than hard-coding a stale one.

### What the user pastes

The user does not paste any generation order. The only prompt is the
Simple instruction from the top of this file:

```text
Using the published pub.dev packages cell, cell_flow and cell_tissue,
read example/HowTo-Mitosis.md and follow it. Turn the requirement below
into the four-document set.

Inputs:
<the parameters the Cell receives>

Output requirement:
<what the Cell emits as Pulse<type> and the behaviour it must implement>
```

### The generation order the AI follows (never pasted by the user)

After reading this file, the AI executes the following order. The user
never sees it:

```text
0. Open the template set `card-auth-pipeline(Cell)-*` in `example/`.
1. Resolve the published packages with
   `dart pub add cell cell_flow cell_tissue`.
2. Create <file_name>-Demo.dart, following
   `card-auth-pipeline(Cell)-Demo.dart`. Run `dart analyze` and
   `dart run` until the output matches the scenarios in the requirement.
3. Create <file_name>-WalkThrough.md, following
   `card-auth-pipeline(Cell)-WalkThrough.md`. Write the requirement
   section at the very top, then fill the content below the table of
   contents: TestCell vs TestTissue, Why Flow + Tissue, Design, Domain,
   Parts, reserve/money, Implementation map, Scenarios, Executable
   steps, Pulse path, Who owns the lock, Acceptance.
4. Generate <file_name>-ARCHITECTURE.md, following
   `card-auth-pipeline(Cell)-ARCHITECTURE.md`: one-paragraph summary,
   layering, ownership matrix, locking, failure semantics, extending
   the demo, anti-patterns, reading order, see also.
5. Generate <file_name>-FEATURES.md, following
   `card-auth-pipeline(Cell)-FEATURES.md`: feature catalogue, scenario
   catalogue, what the demo deliberately does not do, operator cheat
   sheet, acceptance checklist, see also.
6. Reconcile all four files so names, counts and the trailer agree.
```

### What the AI does at each step

| Order | Artifact | AI action |
|---|---|---|
| 0 | `card-auth-pipeline(Cell)-*` | Read the four template files and imitate their structure. |
| 1 | `pubspec.yaml` | Resolve `cell`, `cell_flow`, `cell_tissue` from pub.dev. |
| 2 | `<file_name>-Demo.dart` | Create the executable, following `card-auth-pipeline(Cell)-Demo.dart`; iterate with `dart analyze` / `dart run` until the scenario output is stable. |
| 3 | `<file_name>-WalkThrough.md` | Create the file with the requirement block at the top; expand every section below the table of contents from the running demo, following `card-auth-pipeline(Cell)-WalkThrough.md`. |
| 4 | `<file_name>-ARCHITECTURE.md` | Generate the rationale, following `card-auth-pipeline(Cell)-ARCHITECTURE.md`: seam, layering, ownership, locks, failure, extension, anti-patterns. |
| 5 | `<file_name>-FEATURES.md` | Generate the audit, following `card-auth-pipeline(Cell)-FEATURES.md`: feature catalogue, cheat sheet, acceptance checklist. |

### Why the Demo comes first in a chat session

In the document set, the WalkThrough is the contract and the Demo is the
implementation. But in a live chat, generating the Demo first is more
reliable: the AI makes the program run, and then creates the WalkThrough
with the requirement at the top and expands the sections below it, so the
documented scenarios are real rather than aspirational. The four files
must still end up agreeing — the reconciliation step is what guarantees
the WalkThrough reads as the contract after the fact.

### What the user must supply

1. The requirement: the **inputs** (the parameters the Cell receives)
   and the **output requirement** (what the Cell emits as `Pulse<type>`
   and the behaviour it must implement). Each requirement is different,
   so nothing else is prescribed.
2. Optionally, the file stem, e.g. `grid-demand-response(tissue)`. If
   omitted, the AI derives it from the requirement's industry.

Nothing else. The Flow parts, the Tissue books, and the composition are
decided by the AI for that specific requirement — exactly the mining
table shown in §4.

---

## 3. The output: the four documents and their roles

The four artifacts are not four copies of the same information. They
are four **views** of one system, each with a different reader and a
different failure mode if it lies.

| Document | Reader | Job | Lying looks like |
|---|---|---|---|
| `WalkThrough.md` | implementer / reviewer | The contract. Domain, parts, scenarios, acceptance. | A scenario the executable cannot reproduce. |
| `Demo.dart` | the machine | The executable reference. Only this file runs. | Output that diverges from the WalkThrough table. |
| `ARCHITECTURE.md` | engineer extending the demo | The rationale. Seam, ownership, locks, failure, anti-patterns. | Explaining a lock the code does not actually take. |
| `FEATURES.md` | operator / auditor | The catalogue. Every feature, its location, its behaviour, its acceptance. | Listing a feature the code does not have. |

The four files must cross-reference each other by name and must agree
on every shared fact (names, counts, invariants). When they disagree,
the Demo header is where the disagreement is recorded — see the grid
demo's “Documented deviations from the walkthrough” block.

---

## 4. The process, step by step

### Step 1 — Mine the paragraph for nouns and verbs

Read the requirement and extract four things:

- **Inputs** → the parameters each Cell receives (with their types).
- **Output requirement** → the `Pulse<type>` the Cell emits and the
  behaviour it must implement.
- **Decision parts** → the Flow instructions that get from input to
  output.
- **Books** → the Tissue collections the outputs and side effects touch.

The grid paragraph yields (as a worked example, not a template):

| List | From the paragraph | Extraction |
|---|---|---|
| Inputs | Hz, load, SOC, feeder | `hzIn`, `loadIn`, `socIn`, `feederIn`, `tickIn`, `ackIn` |
| Output requirement | decide SHED / WARN / hold from the tick | `shedCell`, `warnCell` emit `Pulse<Action>` |
| Nouns | frequency, megawatts, feeder, bay, hospital | `BayTick`, `Shed`, `GridEvent`, `RtuJob` |
| Decisions | shed, warn, hold | `enum Action { hold, warn, shed }` |
| Books | feeder books, the log, reliability council | `events`, `reserveMw`, `shedMap`, `protected`, `rtuQ` |
| Seam sentence | “Do not fold Tissue into the Receptor” | Flow gate + observer + Tissue write |
| Products | SHED vs WARN | two gates, two distinct latches |
| Authority | ACK = shift lead restore | `ackIn` + `resetDistinct` |
| Constraint | council reads, cannot delete | append-only `TestTissue` + `.unmodifiable` |

### The Cell contract users actually read

Users typically care about only one surface: **what goes into each Cell
(parameters) and what comes out (`Pulse<type>`)**. Keep that surface
visible in three places:

- **WalkThrough `Parts`** — one row per Cell: name, ingress
  parameter(s) with their `TestCell` rule, and the emitted
  `Pulse<type>`.
- **Demo header comments** — the same table in the Dart comments,
  because pub.dev users land on the Example tab and read those first.
- **FEATURES catalogue** — each feature row states the input parameter
  and the output `Pulse<type>` it concerns.

The card-auth template shows the shape: `amountIn` is an ingress
`<int>` with a `TestCell` rule, `attemptIn` is an ingress
`<AuthAttempt>`, and `authCell` is the `toHandle` output cell emitting
`Pulse<Decision>`.

### Step 2 — Expand the paragraph into the WalkThrough

The WalkThrough is the paragraph, decompressed. Its table of contents is
the expansion recipe (use `card-auth-pipeline(Cell)-WalkThrough.md` as
the section-order template):

1. **TestCell vs TestTissue** — turn the seam sentence into a typing rule.
2. **Why Flow + Tissue** — justify the stack against the domain.
3. **Design** — one ASCII diagram of cells → gates → observers → tissues.
4. **Domain** — the Dart types from Step 1, plus `actionOf`.
5. **Parts** — the Flow cells, Tissue collections, deputies, gates;
   include the Cell I/O table (input parameters → emitted `Pulse<type>`).
6. **Money / reserve** — the invariant and the v1 write protocol.
7. **Implementation map** — which block of the demo realises which part.
8. **Scenarios** — a table of drive → result → demonstrates.
9. **Executable steps** — exact `main()` steps with “must print” blocks.
10. **Pulse path** — one scenario traced through the graph.
11. **Who owns the lock** — the two-lock discipline.
12. **Acceptance** — the done-when checklist.

The scenarios are the contract's spine: every later document is checked
against the WalkThrough's scenario table.

### Step 3 — Implement the executable from the WalkThrough

Write the `*-Demo.dart` so each WalkThrough section becomes a code
block. Use `card-auth-pipeline(Cell)-Demo.dart` as the structural
template for the header comments (including the Cell I/O table), the
seam statement, the gates, and the scenario runner:

| WalkThrough section | Demo realisation (grid example) |
|---|---|
| Flow Cells | `hzIn` / `loadIn` / `socIn` / `areaIn` / `feederIn` / `tickIn` / `ackIn` ingresses with `TestCell` rules |
| Decision policy | `actionOf(BayTick, protectedSet)` — pure, static, clause-ordered |
| Gates | two `MapValue + Distinct + Filter` gates → `shedCell`, `warnCell` |
| Seam | `Cell.observe` on each gate writes the Tissue books |
| Tissue collections | `events`, `reserveMw`, `shedMap`, `protected`, `rtuQ` with `TestTissue` rules |
| Reserve protocol | `applyShed` / `restore` with pre-check + compensation |
| RTU pump | `_driveRtu` retry-once over `_rtuWork`; `rtuQ` as audit enqueue |
| Scenarios | `_section(...)` + `main()` steps 1–13 + trailer |
| Compliance | `events.unmodifiable` used by the COMPLY scenario |

### Flow assembly: parts → one Cell

For the Flow layer the AI decides which instruction parts to use, puts
them together, and ends up with **a Cell at last**:

1. Pick the parts (`MapValue`, `DistinctUntilChanged`, `Filter`, `Tap`,
   ...) that express the decision policy.
2. Compose them into one `FlowInstructionChain` with `operator +`.
3. Materialise once with `toHandle(source: ...)`. The result is the
   output Cell that emits `Pulse<Decision>` (or `Pulse<Action>`).

The card-auth template shows this exactly: `cardAuth = snapshot +
dedupe + actionable + writeBooks + emitDecision;` and then
`cardAuth.toHandle(source: attemptIn.cell)` once in `installGate()`. Do
not call `toHandle` again for the ACK or reset paths.

The demo header must restate the seam, the invariant, the TestCell vs
TestTissue rule, the Cell I/O table (inputs → `Pulse<type>`), and any
deviations from the WalkThrough.

### Step 4 — Extract the ARCHITECTURE document

The Demo knows *how*; the ARCHITECTURE explains *why*. It is extracted
by asking the demo four questions:

1. Where is the seam, and which direction does it face?
2. Who owns each concern, and who owns each lock?
3. What fails, and what does the demo do about it?
4. What would a maintainer break if they “simplified” it?

The grid ARCHITECTURE answers with the two-layer diagram, the ownership
matrix, the two-lock domains, the sequential pulse path, the
compensation ladder, and the anti-patterns table. Anything in the Demo
that surprised its author becomes a “failure semantics” subsection.

### Step 5 — Extract the FEATURES document

FEATURES is the audit view of the Demo. Walk the executable and write
one row per observable feature, in the order of the code:

- Sensor ingress → `_hzRange`, `_loadRange`, `_socRange`.
- Decision policy → each `actionOf` clause and its ordering.
- Distinct latches → `_lastShed` / `_lastWarn` and ACK reset.
- Books → each Tissue and its `TestTissue`.
- Reserve protocol → `applyShed` / `restore` writes in order.
- RTU pump → retry, fail-once, audit enqueue, working list.
- Compliance → `.unmodifiable` behaviour.

Every feature row states the Cell surface it concerns: the input
parameter(s) and the output `Pulse<type>`, when the feature touches a
Cell.

Then add the operator cheat sheet (what to call, what to read) and the
acceptance checklist (the WalkThrough acceptance, re-expressed as
greppable checks).

### Step 6 — Cross-link and reconcile

The four documents are finished only when they agree:

- The Demo's expected console output matches the WalkThrough's
  “must print” blocks and trailer.
- The Demo's header diagram matches the ARCHITECTURE diagram.
- FEATURES' “where” column names real symbols in the Demo.
- Grep confirms the typing rule: zero `testRule: TestCell` on Tissue
  constructors.
- Any deviation is recorded in the Demo header, not silently fixed.

For grid demand-response the reconciliation produced three recorded
deviations (HOSP-1 held, the forced-reserve arithmetic, and the
self-consistent trailer counts), each documented in the Demo header and
visible in the ARCHITECTURE failure semantics.

---

## 5. How the four documents interact

```
             requirement paragraph (the input)
                          │
                          ▼
        ┌─────────────────────────────────────┐
        │  1. WalkThrough.md  (the contract)  │
        │  domain · design · scenarios ·      │
        │  executable steps · acceptance      │
        └───────────────┬─────────────────────┘
                        │  implement
                        ▼
        ┌─────────────────────────────────────┐
        │  2. Demo.dart  (the executable)     │
        │  Cell + Flow + Tissue, runs the     │
        │  scenario table                     │
        └───────┬──────────────────┬──────────┘
                │ extract          │ extract
                ▼                  ▼
   ┌────────────────────┐  ┌────────────────────┐
   │ 3. ARCHITECTURE.md │  │ 4. FEATURES.md     │
   │ why: seam, locks,  │  │ what: catalogue,   │
   │ failure, anti-     │  │ cheat sheet,       │
   │ patterns           │  │ acceptance         │
   └─────────┬──────────┘  └─────────┬──────────┘
             │      cross-check     │
             └──────────┬───────────┘
                        ▼
              reconciled four-document set
```

The interaction is a **one-way build, two-way audit**:

- Build direction: paragraph → WalkThrough → Demo → (ARCHITECTURE,
  FEATURES).
- Audit direction: FEATURES and ARCHITECTURE point back into the Demo;
  the Demo's expected output points back at the WalkThrough scenario
  table; the WalkThrough acceptance points forward at everything.

This is why each file begins with a companion/sibling block: the links
are part of the contract, not decoration.

---

## 6. Worked example — grid demand-response

The exact mapping from paragraph phrase to running construct:

| Requirement phrase | Structural decision | Landed in |
|---|---|---|
| “when system frequency sags” | `hzIn` with `TestCell` 49.00–51.00 | Demo ingress, FEATURES 1.1 |
| “shed interruptible load” | `Action.shed`; shed band `Hz < 49.80` | `actionOf`, WalkThrough domain |
| “protect hospitals” | `protected` TissueSet, checked before frequency | `actionOf` first clause |
| “two products: SHED vs WARN” | two gates (`shedCell`, `warnCell`), two latches | `installGates` |
| “yellow band” | `49.80 ≤ Hz < 49.90` → `warn`; also SOC/load warn | `actionOf` clauses 3–4 |
| “Flow for the shed decision” | `actionOf` pure + `MapValue + Distinct + Filter` gates | Demo, ARCHITECTURE §2 |
| “Tissue for the feeder books” | `events`, `reserveMw`, `shedMap`, `protected`, `rtuQ` | Demo Tissue block |
| “restore after the operator ACK” | `ackIn` observer → `resetDistinct()`; `restore(feeder)` | Demo, FEATURES 1.5 |
| “megawatts” | `reserveMw` `TissueValue<int>`, invariant `reserve + dropped == 800` | `applyShed` / `restore` |
| “reliability council reads the log and cannot delete a row” | `events` append-only `TestTissue`; `events.unmodifiable` | COMPLY scenario |

One pulse, end to end: `publishTick` → `tickIn` → both gates run
`actionOf` → the SHED gate's `Distinct` and `Filter` decide → the SHED
observer appends `events`, enqueues `rtuQ`, then `_driveRtu` runs and
`applyShed` moves reserve MW into `shedMap`. Flow decided; Tissue
recorded; the seam was the observer.

---

## 7. Checklist — the demo set is done when

1. Four files exist with matching basenames and cross-links.
2. `dart analyze <Demo>.dart` reports no issues.
3. `dart run <Demo>.dart` prints exactly the WalkThrough scenario table.
4. The Demo header restates the seam, invariant, typing rule, Cell I/O
   table, deviations.
5. ARCHITECTURE explains every lock the Demo takes and every failure it
   handles.
6. FEATURES names real symbols from the Demo for every feature row.
7. Grep shows zero `testRule: TestCell` on Tissue constructors.
8. The trailer numbers in Demo, WalkThrough, and FEATURES agree.
9. The generated files mirror the `card-auth-pipeline(Cell)-*` template
   structure: Demo header blocks, WalkThrough section order,
   ARCHITECTURE rationale sections, FEATURES catalogue columns.
10. Each Cell's inputs (parameters) and outputs (`Pulse<type>`) are
    stated in the WalkThrough Parts table, the Demo header, and the
    FEATURES rows that touch that Cell.

For the worked example, the set is:

| Artifact | File |
|---|---|
| Requirement | `grid-demand-response(tissue)-WalkThrough.md` |
| Executable | `grid-demand-response(tissue)-Demo.dart` |
| Architecture | `grid-demand-response(tissue)-ARCHITECTURE.md` |
| Features | `grid-demand-response(tissue)-FEATURES.md` |
| This process | `HowTo-Mitosis.md` |

---

## 8. Reusing the process for a new domain

1. Specify the **inputs** (the parameters the Cell receives) and the
   **output requirement** (the `Pulse<type>` and behaviour). Each
   requirement is different; the AI decides the necessary parts and
   assembles a Cell specifically for that one.
2. Copy the Simple instruction from the top of this file, paste in the
   paragraph (and optionally the file stem), and send it to the AI chat.
3. The AI follows §2: template `card-auth-pipeline(Cell)-*` → packages
   → Demo → WalkThrough → ARCHITECTURE → FEATURES → reconcile.
4. Confirm the §7 checklist passes; record any deviations in the Demo
   header.

The card-auth, ride-hail-dispatch, and ICU-alarm sets in `example/` are
all instances of the same Mitosis workflow with different paragraphs.
