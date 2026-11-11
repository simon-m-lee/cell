# HowTo-Mitose.md



## Same-directory dependencies

All Mitose scripts in this set live in **one directory** (this file's directory). Resolve a sibling by filename here first. Do not prefer a remote or package copy over a sibling that is present. A missing sibling is a stop only when this file says that sibling is required.

| Sibling | Role |
|---|---|
| `HowTo-Mitose.md` | Orchestration 2.0. Optional for layer HowTos and for ARCHITECTURE / FEATURES extraction. Required to start a full Mitose run. |
| `Business_Requirements_Document.md` | BRD template 2.0. Shape of `<stem>-BRD.md`. |
| `BRD-AI-Interview.md` | Interview that writes `<stem>-BRD.md` in that template shape. |
| `WalkThrough-AI-Generator.md` | Writes `<stem>-WalkThrough.md`. |
| `HowTo-Mitose-Cell.md` | Cell factory choices. |
| `HowTo-Mitose-Flow.md` | Flow operator and custom-instruction choices. |
| `HowTo-Mitose-Tissue.md` | Tissue collection choices. |
| `LEDGER-AI-Generator.md` | Gate B1 extract; writes `<stem>-LEDGER.md` from the `<stem>-test.dart` report. Does not write a Check file. |
| `COMPREHENSION-AI-Generator.md` | Gates C1–C3, decision log. Writes `<stem>-COMPREHENSION.md`. |
| `ARCHITECTURE-AI-Generator.md` | Writes `<stem>-ARCHITECTURE.md` from the running Demo. |
| `FEATURES-AI-Generator.md` | Writes `<stem>-FEATURES.md` from the running Demo. |
| `CHANGE-AI-Generator.md` | Writes `<stem>-CHANGE-<nnn>.md`. |

**Output names (no `(Cell)` in the filename).** The executable is still the Cell variant (Cell + Flow + Tissue). Dropping `(Cell)` from the name does not drop the variant.

```text
<stem>-BRD.md
<stem>-WalkThrough.md
<stem>-Demo.dart
<stem>-LEDGER.md
<stem>-test.dart             (always with the Demo; BRD group prints the ledger report; other groups align to public APIs and documented contracts)
<stem>-COMPREHENSION.md
<stem>-ARCHITECTURE.md
<stem>-FEATURES.md
<stem>-CHANGE-<nnn>.md       (change mode only)
```

Never overwrite an existing file in that set without asking. Number a new change file; never replace an old one.

**Version:** 2.2 (supersedes 2.1; release notes in §14)

**File role:** An AI-executable **orchestration** script. An AI prompt agent reads this file and runs the Mitose pipeline with a human user: either a **new build** (requirement → WalkThrough → Demo → residual ledger → documents) or a later **change** to a solution built that way.

**Why 2.0.** Version 1.0 ended with documents. It did not record which BRD requirements had executed evidence, left the structure of the BRD free, had no path for later change, and could not tell whether a person understood what they approved. Version 2.0 adds those four things under **Precision Software Engineering**. It does **not** promise bug-free software. It measures conformance to the BRD *as written*.

**Precision Software Engineering** is to software what precision engineering is to a part: a stated design requirement is carried into running behavior, and every step of that carrying is recorded, explicit, bounded, checkable, traceable, and verifiable. A later change, expansion, or update follows the same path, so the development cycle stays predictable. The gap between what was asked and what runs is small, measurable, and attributable. It does **not** promise bug-free software. It measures conformance to the BRD *as written*. It has six components. Do not add a seventh. Do not drop one.

| # | Component | What it binds | Where this pipeline enforces it |
|---|---|---|---|
| 1 | Intent is a first-class artifact | The BRD, not a chat paragraph, is the source of truth for *what* | BRD gate and readiness check B1. No WalkThrough before `<stem>-BRD.md` |
| 2 | Placement follows rules, not taste | Layer HowTos choose the part. The seam sentence is load-bearing: the instruction decides, the chain assembles, the observer glues | WalkThrough layer map; Cell / Flow / Tissue HowTos |
| 3 | Constraints are mechanically checkable | A rule that cannot be grepped or executed is not yet a constraint | Grep: zero `testRule: TestCell` on Tissue constructors. No Tissue writes in an instruction. `<stem>-test.dart` public-API groups |
| 4 | Every change carries provenance | A pulse, a context, and a deputy say who acted and what may be written. A requirement change says who decided | `Pulse`, `Context`, deputies. Change mode records `CHG-nnn` and decision IDs. The agent never invents an approval |
| 5 | Validation sits at the boundary | Bad input is rejected where it enters. Multi-value commits are atomic | `TestCell` on ingress. `Cell.txApply` on Tissue when two retained facts, or a command and its undo, must commit together. `Cell.transaction` is not used. TestTissue on the books |
| 6 | Residual error is measured | Conformance to the BRD as written, per requirement ID, from executed evidence | `<stem>-test.dart` `BRD` group prints `LEDGER` lines. `<stem>-LEDGER.md` records them. Reading code is not Verified |

A run that skips a component is not a Precision Software Engineering run. Say which component was skipped. The three gaps fail the run; they are not notes.

**Fail closed (the three gaps).** `<stem>-test.dart` must contain these groups. A missing group, a silent boundary, or a missing provenance row fails `dart test <stem>-test.dart`. Do not record them as a class I inspection that a person can pass by reading.

| Gap | Fails when | Group |
|---|---|---|
| 1. Constraint not executed | The Demo has `testRule: TestCell` on a Tissue constructor, or a Tissue write (`add` / `set` / `[]=` / `addLast`) inside the instruction class | `group('constraint')` greps the Demo source and `expect`s zero hits |
| 2. Provenance missing | The header has no provenance table, a pulse is emitted with no source, or a role the BRD says must not write has no `.unmodifiable` or `.deputy` | `group('provenance')` |
| 3. Boundary silent | An ingress, `Cell.transaction`, or `Cell.txApply` is neither present nor a Real-desk row that says `deferred` | `group('boundary')` reads the header register |

Header registers the Demo must print, and the tests must read:

```text
Provenance: Pulse.source on every emit | Context: named / none | Deputy: <book>.unmodifiable for <role> / none because BRD names no auditor
Boundary: <ingress> TestCell yes|no | transaction present|deferred <Real-desk row> | txApply present|deferred <Real-desk row>
```

`none` is allowed only with the reason. A blank cell fails.

**Product names**

**Mitosis** is the framework. **Mitose** is what you do with it. *Mitose* is the German word for cell division (*die Mitose*), and this project borrows it as a verb: you have a business requirement, so you **Mitose it**. The spelling is deliberate. Please do not “correct” it to Mitosis; filenames such as `HowTo-Mitose.md` keep it on purpose. *Mitosis is the noun. Mitose is the verb.*

| Word | Meaning |
|---|---|
| **Mitosis** | The framework (Cell + Flow + Tissue). The noun. |
| **Mitose** | The verb. Run this pipeline on a business requirement. Not a typo for Mitosis. |

This file is **process only**. It does not teach `Cell.*` factories, Flow operators, or Tissue collections.

| Need | Read this instead | Needs this file? |
|---|---|---|
| Choose `Cell.ingress` / `observe` / `transaction` / `txApply` | `HowTo-Mitose-Cell.md` | **No** |
| Choose stock operator vs custom `FlowInstruction` + `+` + `toHandle` | `HowTo-Mitose-Flow.md` | **No** |
| Choose List / Set / Map / Queue / Value, TestTissue, deputies | `HowTo-Mitose-Tissue.md` | **No** |
| Fill a BRD by interview | `BRD-AI-Interview.md` | No |
| Fill a BRD from a template | `Business_Requirements_Document.md` (v2.0) | No |
| Write the WalkThrough | `WalkThrough-AI-Generator.md` | No (it consults the three layer HowTos) |
| Measure residual error; write the ledger from the test report | `LEDGER-AI-Generator.md` | No |
| Comprehension check, change control, decision log | `COMPREHENSION-AI-Generator.md` | No |
| Change, upgrade, repair, or reconcile an existing solution | `CHANGE-AI-Generator.md` | No |
| Run the rest of the pipeline unattended once the BRD exists (autonomous mode) | `HowTo-Mitose.md` §15 | **Yes** |
| Extract ARCHITECTURE from a running Demo | `ARCHITECTURE-AI-Generator.md` | No |
| Extract FEATURES from a running Demo | `FEATURES-AI-Generator.md` | No |

The three layer HowTos, the BRD interview, and every generator **must proceed if this file is missing**. They already contain the rules they need.

---

## 0. Where files live

Resolve in this order. Prefer a sibling in this directory over a remote revision.

1. **This directory** — the folder that holds `HowTo-Mitose.md` and the other scripts named in the same-directory table above. A sibling present here wins.
2. Workspace / attachments (`artifacts/`, `attachments/`, chat uploads) if this directory does not already contain the file.
3. Published copies the user named: [`https://github.com/simon-m-lee/cell/tree/master/guide`](https://github.com/simon-m-lee/cell/tree/master/guide).
4. Package HowTos in the monorepo if the root `guide/` path is empty: `packages/cell/guide/`, `packages/cell_flow/guide/`, `packages/cell_tissue/guide/`. Root overview: `DEMO_GUIDE-Mitosis.md`.
5. Live signatures on [pub.dev/packages/cell](https://pub.dev/packages/cell), [cell_flow](https://pub.dev/packages/cell_flow), [cell_tissue](https://pub.dev/packages/cell_tissue). Never invent an API from memory.

**Scripts this pipeline uses**

| Script | Produces |
|---|---|
| `BRD-AI-Interview.md` | `<stem>-BRD.md` |
| `Business_Requirements_Document.md` | Offline template the user fills and returns |
| `WalkThrough-AI-Generator.md` | `<stem>-WalkThrough.md` |
| `HowTo-Mitose-Cell.md` + `HowTo-Mitose-Flow.md` + `HowTo-Mitose-Tissue.md` | Layer choices inside WalkThrough and Demo |
| `LEDGER-AI-Generator.md` | `<stem>-LEDGER.md` from the `<stem>-test.dart` report |
| `COMPREHENSION-AI-Generator.md` | `<stem>-COMPREHENSION.md` |
| `ARCHITECTURE-AI-Generator.md` | `<stem>-ARCHITECTURE.md` |
| `FEATURES-AI-Generator.md` | `<stem>-FEATURES.md` |
| `CHANGE-AI-Generator.md` | `<stem>-CHANGE-<nnn>.md` |

**Output names (match the Demo stem)**

```text
<stem>-BRD.md
<stem>-WalkThrough.md
<stem>-Demo.dart
<stem>-LEDGER.md
<stem>-test.dart             (always with the Demo; BRD group prints the ledger report; other groups align to public APIs and documented contracts)
<stem>-COMPREHENSION.md
<stem>-ARCHITECTURE.md
<stem>-FEATURES.md
<stem>-CHANGE-<nnn>.md       (change mode only)
```

Never overwrite an existing file in that set without asking. Number a new change file; never replace an old one.

### Versioning of generated files (SemVer)

Every generated file uses **MAJOR.MINOR.PATCH**. The name plate always contains `Version: M.m.p` and `Supersedes: <prior filename or none>`. When more than one version exists, the filename carries the version: `<stem>-<artifact>-vM.m.p.<ext>` (example: `tide-warden-WalkThrough-v0.2.0.md`). The first write of an artifact is `0.1.0` and uses the unversioned filename.

Later steps resolve the highest version of each required artifact and record the exact filename and version they read. They do not read an older version unless the user names it.

#### Bump rules by artifact

| Artifact | PATCH | MINOR | MAJOR |
|---|---|---|---|
| **BRD** | Typo, clarification, or wording that does not change any ID, parameter, or criterion | New requirement ID, new parameter, or additive scope that does not contradict existing Must rules | Any Must rule, parameter value used by a check, or acceptance criterion is changed or retired; IDs are never reused |
| **WalkThrough** | Typo, re-ordering that does not change a clause, or a filled Demo Assessment that does not alter expected prints | New scenario, new ingress, or additional layer placement that does not contradict a prior clause | A coverage-matrix expected print changes, a product is added or removed, or the seam/grep rule is altered |
| **Demo / test** | Comment, formatting, or a banner that still compares the same BRD-expected value | New driven scenario or new BRD-group check that does not change an existing expected value | An expected value, comparison type, or protected item changes (requires gate C2); a previously Verified check is removed |
| **LEDGER** | Re-run that does not change any Result column | New Verified or Failed rows from a recorded run; mitigation plan updated | A Result moves from Verified back to another state, or residual acceptance is recorded |
| **COMPREHENSION** | Typo or additional skipped row | New check session or new decision-log entry | A previously recorded decision is reversed |
| **ARCHITECTURE / FEATURES** | Typo or diagram that matches the same Demo symbols | New section that reflects a Demo change already present | Describes a lock, failure, or feature the current Demo does not contain (not allowed — rewrite instead) |
| **CHANGE** | — | — | Sequential `nnn` only; never overwritten. Each change file is immutable |

A change that touches a protected item is at least MINOR and requires the C2 decision gate before the new version is written. Never reuse a version number.

Scripts that consume a generated file must state the exact filename and version they read.

---

## 1. Instructions to the AI prompt agent

You are the Mitose agent. Follow the steps below in order. Do not skip the BRD gate. Do not write the Demo before the user accepts the WalkThrough. Do not write ARCHITECTURE or FEATURES from a WalkThrough alone. Do not describe a requirement as handled without evidence.

### Rules of engagement

1. **BRD is source of truth for *what*.** Do not invent business numbers, actors, or clauses.
2. **WalkThrough is source of truth for *how the executable must behave*** until the Demo exists.
3. **Demo is source of truth for *what the program actually does*** once it exists. After Demo generation, revisit the WalkThrough (Demo Assessment & Recommendations) against the Dart file.
4. **Layer HowTos are source of truth for *which layer answers the BRD*.** Cell / Flow / Tissue files do not wait on this orchestration file.
5. **Seam sentence is load-bearing:** the instruction decides, the chain assembles, the observer glues. No Tissue writes in the instruction. `Cell.observe` is the only glue.
6. **Grep rule:** zero `testRule: TestCell` on Tissue constructors.
7. One human decision at each gate. Do not chain gates, and do not chain Demo + ledger + ARCHITECTURE + FEATURES in one silent pass unless the user asked for the whole set. Autonomous mode (§15) is the one exception: the user opts in once at gate A1, and every later gate becomes a recorded automatic decision.
8. Stop and ask if a required script or HowTo cannot be read. In autonomous mode, stop and report instead of asking (§15.8).
9. **IDs are permanent and are how you trace.** Requirement IDs are never reused or renumbered. Impact, coverage, and evidence are traced by ID. A link you cannot trace is `Unknown`, and Unknown is treated as affected.
10. **The ledger is the source of truth for *what has been shown to work*.** The BRD says what is required, the Demo says what the program does, and the ledger says which requirements have executed evidence. Never describe a requirement as handled when the ledger says Blocked, Failed, or Unverified.
11. **Verified needs executed evidence.** Never mark a row Verified from reading code. Record where each run came from (the agent executed it, or the user supplied the output).
12. **Expected values come from the BRD and its parameter register,** never from the Demo's own output.
13. **Protected items change only under gate C2** (expected values, criteria, tolerances, parameter values used by checks, the set of checks, comparison type, skip markers). When a check fails, fix the code first.
14. **Do not invent history.** Thresholds, versions, migrations, decisions, alternatives, and approvals that were not stated stay `[To be confirmed from BRD]`. Approvals belong to named people. The agent never records an approval it did not receive and never accepts residual risk for the user. Autonomous mode (§15) relaxes only two things, and only because the user delegated them at gate A1: the agent may decide thresholds, rule precedence, and open questions itself, tagged `[AI DECIDED — autonomous]` (§15.4); and it may record residual acceptance as a delegation, never as the user's own approval (§15.6).
15. **State a fact once.** Every generated document opens with a short summary headed *What a reader must understand* when useful. There are no word caps. Link by ID.
16. **Describe, never grade.** Record what a person predicted and what the BRD says. Do not rate the person and do not produce a comprehension score.
17. **Mitosis is the noun. Mitose is the verb.** Do not rename a file, a heading, or a package from Mitose to Mitosis. Mitosis is the framework. Mitose is this pipeline.
18. **Use only the latest generated file.** When more than one version of an artifact exists, read the highest version. Record the filename and version in the name plate of the file you write.
19. **Autonomous mode is opt-in, offered once, and starts only after a BRD exists.** The user chooses it at gate A1 (§3.2A). It never applies to change mode. It never marks a row Verified without an executed run, never overwrites a file, never records an approval by a person who did not give it, and never loosens a protected item to make a check pass (§15.2). Every decision it makes is tagged and listed in the final report (§15.9).

20. **In autonomous mode the agent first ensures a Dart runtime and implements the WalkThrough with the Mitosis packages.** Before generating or executing a Demo the agent autonomously installs a Dart SDK if needed, adds `package:cell`, `package:cell_flow` and `package:cell_tissue`, and writes a Demo that follows the WalkThrough (instruction decides, chain assembles, observer glues, Tissue books). The first Demo and its test file must be written to meet **all** requirement IDs stated in the BRD (every FR / DR / BR / AR / NFR that has a testable criterion). No user confirmation is required for these steps (§15.7).

21. **After the BRD is complete and autonomous mode is chosen, the pipeline runs to the end without interruption.** No further user input is requested. The comprehension check is not offered. Every undecided or open question is decided by the agent to the best of its knowledge, tagged `[AI DECIDED — autonomous]`, and accepted. The agent then:

- writes the WalkThrough by following `WalkThrough-AI-Generator.md` exactly,
- implements and tests the Demo and Test (covering all BRD requirements),
- **updates the WalkThrough §5.12 Demo Assessment from the executed Demo and test results**, filling every subsection required by `WalkThrough-AI-Generator.md` §6 with the same detail as in manual step-by-step mode (what the Dart file implemented, what `main()` does not drive, trailer/header integers, Recommendations for Enhancement),
- writes the ledger by following `LEDGER-AI-Generator.md` exactly, using the executed test report,
- writes ARCHITECTURE by following `ARCHITECTURE-AI-Generator.md` exactly,
- writes FEATURES by following `FEATURES-AI-Generator.md` exactly,
- produces the final report.

The only stop conditions are those listed in §15.8.

22. **All document generations MUST use their corresponding generator script.**  
The agent must follow the generator exactly and must not write the document ad-hoc:

| Document | Generator script that MUST be followed |
|---|---|
| `<stem>-WalkThrough.md` | `WalkThrough-AI-Generator.md` |
| `<stem>-LEDGER.md` | `LEDGER-AI-Generator.md` |
| `<stem>-ARCHITECTURE.md` | `ARCHITECTURE-AI-Generator.md` |
| `<stem>-FEATURES.md` | `FEATURES-AI-Generator.md` |
| `<stem>-COMPREHENSION.md` | `COMPREHENSION-AI-Generator.md` |
| `<stem>-CHANGE-<nnn>.md` | `CHANGE-AI-Generator.md` |

This rule applies in both step-by-step and autonomous mode. Autonomous mode does not relax it. A document written without following its generator is invalid and must be regenerated.

23. **Every BRD test must compare actual results against expected values before confirming the test.**  
In both step-by-step and autonomous mode, each test in the `BRD` group of `<stem>-test.dart` must:
- Capture the actual result produced by the Demo.
- Compare it with an expected value taken from the BRD (or the WalkThrough coverage matrix).
- Call `expect()` (or an equivalent assertion) so the test fails if they do not match.
- Print the `LEDGER` line only after the comparison, showing both `expected=` and `actual=`.

A `LEDGER PASS` line printed without a preceding assertion that compared actual against expected is invalid. This rule applies in both modes.

24. **All documents must be generated in full.**  
In both step-by-step and autonomous mode, every document listed below must be produced by following its generator script completely. A stub, placeholder, or empty document is invalid and must be regenerated:

| Document | Generator | Required content |
|---|---|---|
| `<stem>-WalkThrough.md` | `WalkThrough-AI-Generator.md` | **Full document.** All subsections 5.1–5.14 with the same depth as a manual-mode generation: detailed ingress table, policy clauses with load-bearing order, products and `pass`, chain shape (code), pulse path, Tissue books table, reserve protocol, TestCell/TestTissue map, must-print scenarios, Real desk / Wave A, open questions, filled §5.12 Demo Assessment (what implemented, what `main()` does not drive, trailer/header integers, Recommendations), coverage matrix, HowTos consulted. A summary or slim WalkThrough is invalid. |
| `<stem>-LEDGER.md` | `LEDGER-AI-Generator.md` | All blocks in §4 (name plate, registers, per-group tables, summary, run log, LEDGER lines) |
| `<stem>-ARCHITECTURE.md` | `ARCHITECTURE-AI-Generator.md` | Full layer placement, diagrams, and sections required by the generator |
| `<stem>-FEATURES.md` | `FEATURES-AI-Generator.md` | Full feature inventory and sections required by the generator |
| `<stem>-COMPREHENSION.md` | `COMPREHENSION-AI-Generator.md` | Full record (or explicit declined block in autonomous mode) |

A document that contains only a title and a one-line summary is a stub and does not satisfy this rule.  
A WalkThrough that omits detailed tables, chain shape, scenarios, or a fully filled §5.12 is a slim document and is invalid. The agent must follow `WalkThrough-AI-Generator.md` §5 and §6 completely, producing a document comparable in structure and depth to a manual-mode generation.

25. **The Demo must implement the WalkThrough in full, adapting to live signatures.**  
In both step-by-step and autonomous mode, `<stem>-Demo.dart` must contain:
- Domain types matching the WalkThrough — use the BRD's own shapes (for example, a payment desk's tick, decision, order, payment, outcome), never a fixed list.
- A custom `FlowInstructionBase` subclass with an importable `riskOf` (or equivalent pure decision method) where the resolved package APIs permit it.
- Chain assembly (`+`, `MapValue`, `toHandle` once per product) where the resolved package APIs permit it.
- `Cell.observe` as the **only** glue that writes Tissue books.
- Tissue books for every collection the WalkThrough named.
- Behaviour that satisfies every FR / DR / BR / AR / NFR criterion that can be expressed as a check.

**Live signatures rule:** Resolve constructors, method signatures, and exports from the installed packages (pub.dev / local sources). Never invent an API from memory. If a live signature prevents the idealized shape (custom instruction constructor, staged `Cell.txApply` with compensate, separate ingresses, etc.), adapt to the working form, record the deviation in the Demo header and in WalkThrough §5.12, and list the intended shape as a Recommendation. A slim pure-function Demo that ignores the WalkThrough is invalid; an adapted Demo that still meets the seam (instruction decides, observer glues) and produces executed evidence is valid when the deviation is recorded.

26. **Post-Demo reconciliation is mandatory.**  
After `<stem>-Demo.dart` exists and has been executed, the agent must update the WalkThrough so that §5.2–§5.5, §5.7, §5.10 and the coverage matrix describe either (a) what the executed Demo actually does, with the intended full shape recorded as Recommendations / Real-desk rows, or (b) clearly mark “intended vs executed” at the top of §5.12 and in the affected sections. Leaving the contract sections describing a shape the Demo does not implement, while §5.12 describes a different implementation, is invalid. ARCHITECTURE and FEATURES must not be offered until this reconciliation is done.
- Chain assembly: the products named by the WalkThrough (for a two-product desk, `proceed` / `reject`), `MapValue`, and `toHandle` once each.
- `Cell.observe` as the only glue that writes Tissue books.
- `Cell.txApply` (or the equivalent multi-value commit) for the all-or-nothing paths.
- `installGates()` that wires everything and does no work at import time.
- Header provenance and boundary registers.
- A `main()` that drives the must-print scenarios.

A Demo that uses only a pure function and a synchronous `process` method, without the instruction / chain / observe / txApply structure, is a slim Demo and is invalid. The agent must implement the WalkThrough as written.

### Opening line

> I have HowTo-Mitose.md 2.2. I will run the Mitose pipeline: BRD gate → once the BRD exists, I will offer you a choice between step by step and autonomous mode → readiness check → WalkThrough (with a short prediction check, unless you choose autonomous) → Demo (on your OK; in autonomous mode, after the BRD, I run the rest of the pipeline without interruption or further input: decide all open items, skip the comprehension check, install a Dart SDK if needed, add package:cell / cell_flow / cell_tissue, implement the WalkThrough in full (all subsections 5.1–5.14 with detailed tables, chain shape, scenarios and filled §5.12) covering all BRD requirement IDs, write and test the Demo implementing the WalkThrough in full (instruction decides, chain assembles, observer glues, adapting to live package signatures and recording deviations — a slim pure-function Demo that ignores the WalkThrough is invalid; each BRD test compares actual vs expected and calls expect() before printing LEDGER PASS), update the WalkThrough §5.12 Demo Assessment and reconcile contract sections from the results using WalkThrough-AI-Generator.md §6 with the same detail as manual mode, write the ledger using LEDGER-AI-Generator.md, ARCHITECTURE using ARCHITECTURE-AI-Generator.md and FEATURES using FEATURES-AI-Generator.md (all documents MUST be produced in full by following their corresponding generator script exactly — ad-hoc writing and stubs are invalid), and produce the remaining documents until the end) → WalkThrough assessment against the Dart file → residual ledger → decision log → ARCHITECTURE and FEATURES. For an existing solution I will run change mode instead. Cell / Flow / Tissue HowTos stay in force whether or not this file is present. First I will look for a BRD.

Then run §2.

---

## 2. Start Mitose

A user starts Mitose by:

- attaching or naming this file, **or**
- pointing at the public copy (`HowTo-Mitose.md` under the guide URL above), **or**
- saying “Mitose” / “run Mitose” in chat for a new build, or “Mitose change” for a change to an existing solution, **or**
- saying “Mitose autonomous”. This pre-answers gate A1 (§3.2A) with *autonomous*. The BRD stage is still interactive, because only the user can supply the business need. Autonomy starts once a filled BRD exists.

**Manual-upload fallback.** Some AI prompts cannot access the GitHub repository remotely. In that case the user pulls the files from the local `/guide` directory and uploads them manually (as chat attachments), and the agent runs the pipeline from the uploaded copies. The uploaded copies take precedence over any remote revision. For a full run the user uploads this file, the BRD interview and template, the three layer HowTos, and the generators named in §0.

Read this file. Then search the workspace for the files in §0 and choose a mode:

| User says | Files found | Mode |
|---|---|---|
| “Mitose” | No filled `*-BRD.md` | **New build** → §3 |
| “Mitose” | Filled BRD, no WalkThrough | **New build** → §3.1, then §3.3 |
| “Mitose” | Some pipeline files already exist | **Resume.** Name the files found and the first missing stage; ask: “Continue at *stage*?” |
| “Mitose change” | BRD, WalkThrough, Demo, and ledger | **Change mode** → §9 |
| “Mitose change” | No ledger | Offer to build the baseline ledger first (§7). Do not start the change |
| “Mitose autonomous” | No filled `*-BRD.md` | **New build.** Run the BRD gate (§3) interactively; autonomous mode begins when the BRD exists (§3.2A, §15) |
| “Mitose autonomous” | Filled BRD | **New build / Resume**, autonomous from gate B1 onward (§3.2A, §15) |
| “Mitose autonomous change” | Any | Autonomous mode does not apply to change mode (§15.1). Run change mode interactively and say so |

Stage order for Resume: BRD → A1 (autonomous offer, §3.2A) → B1 → WalkThrough → Demo → Demo Assessment → ledger → decision log → ARCHITECTURE / FEATURES. If the BRD exists and no later stage has run, gate A1 has not been answered, so ask it.

---

## 3. BRD gate (required before WalkThrough)

### 3.1 BRD already uploaded

If a filled `<stem>-BRD.md` exists, confirm the stem with the user and go to §3.2A, then §3.3.

### 3.2 No BRD yet — offer four starts

Give **all four** options. Do not invent a fifth. Do not start WalkThrough until one path produces a BRD file.

1. **Upload a filled BRD.** User attaches `<stem>-BRD.md` that already has the necessary information. Agent stores it under that name and continues.
2. **Template offline.** Give the user `Business_Requirements_Document.md` to copy, rename to `<stem>-BRD.md`, fill later, and resubmit. Stop until they return.
3. **Online interview.** Run `BRD-AI-Interview.md` exactly (one question at a time, plain English, no design words). Write `<stem>-BRD.md` at the end of that script.
4. **Paste a requirement paragraph.** User pastes a short requirement at the prompt. Agent drafts `<stem>-BRD.md` from the template as best it can, marks every invented or missing field `[To be confirmed]` / `[AI SUGGESTED]`, shows the draft, and waits for correction before §3.3.

If the user picks (2), do not interview them in the same turn. If they pick (3), do not also ask them to fill the template.

When any of the four paths has produced a filled `<stem>-BRD.md`, go to §3.2A.

### 3.2A Autonomous mode offer (gate A1)

Ask this **once**, as soon as a filled `<stem>-BRD.md` exists and the mode is *new build* or *resume*. Ask it before gate B1. If the user already said “Mitose autonomous”, treat that as the answer: print the one-line confirmation below and continue. Do not ask a second time in the same session.

> The BRD is in place. How do you want to run the rest of the pipeline?
>
> **1. Step by step (default).** I stop at every gate and wait for your answer, as described in this file.
>
> **2. Autonomous.** I run everything after the BRD in one go, with no questions: readiness check, WalkThrough, Demo and test file, Demo Assessment, residual ledger, decision log, ARCHITECTURE and FEATURES. I do not offer the comprehension check. Every open question, missing value, finding, and residual item I decide to the best of my knowledge and accept as decided. Each decision is tagged `[AI DECIDED — autonomous]` and listed in a final report, and you can reopen any of them later as a Change.
>
> What stays the same in autonomous mode: nothing is marked Verified without an executed run, I never overwrite an existing file, I never fill in an approval or signature for a person, and I never loosen a check to make it pass.
>
> What you give up: you will not have read or approved anything before it is generated. Please read the final report and the BRD tags before relying on the result.
>
> Which one?

Rules:

1. One question, two options. An unclear answer means step by step.
2. Record the choice and the **delegating person**: the name the user gives in the reply, else the BRD author or sponsor named in BRD §1, else `the requester`. Never invent a name.
3. If the user chooses autonomous, follow §15 for every remaining stage. If the user chooses step by step, nothing in §15 applies.
4. A user message sent mid-run is an instruction. If it says stop, stop (§15.8).

### 3.3 BRD readiness check (gate B1)

Before the WalkThrough, run `LEDGER-AI-Generator.md` §2 in **extract-only mode** on the BRD. Show the user:

| Block | Content |
|---|---|
| Requirement register | One row per requirement ID: priority, criterion present or `[AI SUGGESTED]`, verification class |
| Parameter register | Every threshold, window, limit, and list a requirement relies on: value, unit, owner, status. A missing value is `[To be confirmed from BRD]` |
| Findings | Contradictions, missing rule precedence, missing values, missing behavior, orphan rules, journey mismatches, target mismatches, measure basis (percentile, window, sample size) |

Rules:

1. If the BRD has **no requirement IDs**, assign FR / DR / BR / AR / NFR IDs as in the template, mark them `[AI SUGGESTED]`, show them, and wait.
2. A requirement with no testable criterion gets a drafted criterion marked `[AI SUGGESTED]`, or the class `J` (judgment) if it cannot be tested.
3. **Report findings; do not fix them.** Mark each **Blocking** (no check can be written) or **Clarify**. Ask the owner or the user.
4. If the user resolves a finding now, update the BRD, bump its version, add a row to its Change history, and note the decision for the decision log (§8). If they do not, carry it forward as an open question and a Blocked row.

Ask (gate B1):

> Is this register, parameter list and findings list right? Which Blocking findings do you want to resolve before the WalkThrough, and which do we carry forward?

Do not start the WalkThrough until the user answers. Unresolved findings do **not** forbid proceeding; they will appear as Blocked rows.

In autonomous mode this check is shown in the run log but not awaited. The agent resolves each finding under §15.4 and continues.

---

## 4. WalkThrough

Once a BRD file exists and gate B1 is answered:

1. Follow `WalkThrough-AI-Generator.md` exactly (nine slots + layer map **before** the file; writing spec in that generator §5).
2. Consult `HowTo-Mitose-Cell.md`, `HowTo-Mitose-Flow.md`, and `HowTo-Mitose-Tissue.md` when placing parts. Do **not** block that generator on this orchestration file.
3. If the BRD needs identity-bearing, connected entities (users with posts, orders with lines) and a `HowTo-Mitose-Organ.md` is present, consult it. If it is absent, say so in the layer map and defer the need in Real desk. Do not assign `cell_organ` from memory.
4. Write `<stem>-WalkThrough.md` with every block that generator names:

   | WalkThrough heading | Must include |
   |---|---|
   | Summary | Short summary headed *What a reader must understand* |
   | Name plate | BRD / WalkThrough / Demo / later LEDGER, ARCHITECTURE + FEATURES |
   | Requirement block | Plain English only |
   | Seam + grep rule | Instruction decides, chain assembles, observer glues |
   | Ingress list | Every feed + ACK, TestCell yes/no |
   | Policy / products / chain | Clause order, `pass`, `+` `MapValue` `toHandle` once per product |
   | Pulse path (§5.5) | ASCII that matches `installGates`, payload types labelled |
   | Tissue books | All five types considered |
   | Reserve / raise-close | Harness, not instruction |
   | Scenarios | Must-print banners: happy, warn, protected, latch, ACK, reject, overdraw, COMPLY |
   | Real desk / Wave A | `transaction` / `txApply` yes-no-defer |
   | Open questions | Every `[To be confirmed from BRD]`, every parameter still undefined, and every Blocking finding carried from gate B1 |
   | Demo Assessment (§5.12) | **Stub only** on this pass |
   | Coverage matrix | Scenario → **BRD id** → expected print (use the BRD's own IDs) |

5. Show the extraction plan / layer map **before** writing the file.
6. **Comprehension check (gate C1).** Offer once: the user predicts the outcome of three scenarios (an ordinary path, a boundary or second interaction, and an interaction) before reading the expected results. Follow `COMPREHENSION-AI-Generator.md` §2. A mismatch is a signal about the document first. Skipping or declining is allowed and recorded. Create `<stem>-COMPREHENSION.md` here.
7. Ask whether the user is satisfied with the WalkThrough.

Do not write `*-Demo.dart` in this pass.

---

## 5. Demo (only after WalkThrough acceptance)

Offer to generate `<stem>-Demo.dart`.

When the user says yes:

1. Treat the accepted WalkThrough as the behaviour contract.
2. Resolve live APIs from pub.dev and the three layer HowTos. Never guess signatures.
3. Cell-variant default: custom `FlowInstruction` + `MapValue` + `operator +` + `toHandle` once per product; books written only from `Cell.observe`.
4. Header must include the Cell I/O table, seam sentence, TestCell vs TestTissue rule, expected console, deviations from the WalkThrough, the requirement IDs covered and not covered, and the provenance and boundary registers from the fail-closed rule above. A blank provenance or boundary cell fails the test.
5. Do not invent BRD facts to make the Demo prettier.
6. **Keep decision logic importable.** Put the policy instruction, chain assembly, and `installGates()` in top-level declarations, with no work done at import time. `<stem>-test.dart` must import the Demo without running `main()`. If something cannot be exposed, say so in the header.
7. **Always write `<stem>-test.dart` with the Demo.** It is the unit-test file and the residual-ledger report. Do not write `<stem>-Check.dart`. Groups are aligned to public APIs and documented contracts, not to banner names. One group is the BRD suite. Expected values in that suite come from the BRD and the parameter register, never from the Demo's own output. **Each BRD test must capture the actual result, compare it with the expected value, call `expect()` (or equivalent) so the test fails on mismatch, and only then print the `LEDGER` line showing both `expected=` and `actual=`.** A PASS line printed without that comparison is invalid. Class J is not a unit test. A missing parameter stays `BLOCKED`.

   ```dart
   void main() {
     group('BRD', () {
       group('FR-03', () {
         test('velocity at threshold declines', () {});
       });
       // after this group, one line per requirement ID
     });
     group('NounRiskInstruction.riskOf', () {}); // public API
     group('WalkThrough §5.5', () {});           // documented contract
     group('constraint', () {});                 // gap 1: grep fails the suite
     group('provenance', () {});                 // gap 2: header register
     group('boundary', () {});                   // gap 3: present or deferred
   }
   ```

   The `BRD` group owns the ledger report. Only its results move a ledger row. The `constraint`, `provenance`, and `boundary` groups do not move a BRD row, but any failure fails the suite. Print one line per requirement ID:

   ```text
   LEDGER <ID> <PASS|FAIL|BLOCKED> expected=<from BRD> actual=<observed> note=<short>
   ```

   Other groups name a public symbol the Demo exports, or a documented contract (seam sentence, grep rule, Demo header Cell I/O table, WalkThrough §5.5). They do not invent business numbers, and a failure there does not by itself mark a BRD row Failed.
8. **Outcome banners that state a result should compare the actual value with the expected value** taken from the WalkThrough coverage matrix, print `PASS` or `FAIL`, and exit non-zero on any `FAIL`. A banner that only prints text is not evidence (§7). The test report is the evidence; a banner is not a substitute for it.
9. **Never change a test expected value or a banner expected value to match behaviour.** That is a protected change (gate C2).
10. Tag code with requirement IDs where a rule is implemented (comment `// FR-03`) so impact can be traced later.

---

## 6. Revisit the WalkThrough against the Demo

After `<stem>-Demo.dart` exists, **go back** to `<stem>-WalkThrough.md` and run `WalkThrough-AI-Generator.md` §6. Fill:

- Demo Assessment — what the Dart file implemented; what `main()` does not drive
- Trailer / header integers from the Demo header or last-good run
- Recommendations for Enhancement — each row names a landing layer (Cell / Flow / Tissue / harness)

Update every claim the Dart file disproves (unproven clauses, trailer counts, Real-desk deferrals the Demo actually implemented). The Demo wins on symbols, locks, and what `main()` drives.

Ask before overwriting the WalkThrough. ARCHITECTURE and FEATURES must read this filled §5.12 and must not treat an unproven clause as a handled failure. Unproven clauses and behaviours `main()` does not drive carry into the ledger as rows with a note.

### Offer for recommended enhancements

After the filled §5.12 is shown, and before offering the ledger, ask once:

> The WalkThrough lists Recommendations for Enhancement. Do you want to apply any of them?  
> 1. As a Change — follow the CHANGE path (`CHANGE-AI-Generator.md`): state the change, show impact, write `<stem>-CHANGE-<nnn>.md`, bump versions, and keep the prior files.  
> 2. In place — add the enhancement to the Demo and update the existing documents (WalkThrough assessment, test, ledger notes) without bumping a version or writing a CHANGE file.  
> 3. Skip — leave the recommendations for later.

Record the choice. If the user chooses Change, enter change mode for that enhancement and do not continue the main pipeline until the CHANGE gates are answered. If the user chooses In place, patch the Demo, re-run, and update the existing files in situ; do not write a CHANGE file and do not bump versions. If the user skips, proceed to the ledger offer. In autonomous mode the choice is always Skip (§15.3).

---

## 7. Residual ledger

After §6 is accepted, offer the ledger. Do not generate it unless the user agrees. If the user declines, say once that no requirement has executed evidence yet, record the decision, and go to §8.

When the user says yes, follow `LEDGER-AI-Generator.md` exactly. Do **not** block that generator on this orchestration file.

1. **Extract (gate L1).** Show the requirement register, parameter register, and findings again, now with the WalkThrough coverage matrix and the Demo's IDs-covered header. Ask whether it is right. Do not write the ledger until the user answers.
2. **Write `<stem>-LEDGER.md`.** The first version has no Verified rows. Evidence comes from `<stem>-test.dart`, which was written with the Demo. Do not write `<stem>-Check.dart`. If the test file is missing, stop and write it under §5 before any row can be Verified. Include the Blocked-row mitigation section (one recommendation per currently Blocked ID).
3. **Evidence (gate L3).** If the runtime can execute Dart, run `dart analyze`, the Demo, and the test file, and record the output. If it cannot, give the user the exact commands and wait for the output:

   ```text
   dart pub add --dev test
   dart analyze <stem>-Demo.dart <stem>-test.dart
   dart run <stem>-Demo.dart
   dart test <stem>-test.dart
   ```

   Pass the test path explicitly. A bare `dart test` discovers `*_test.dart` (underscore) under `test/`, not `<stem>-test.dart`. Confirm the commands on the resolved SDK. The ledger report is the `LEDGER` lines the test prints.
4. **Update the ledger only from that output.** `PASS` → Verified; `FAIL` → Failed; `BLOCKED` stays Blocked; record the source of each run. Mechanical class **I** checks (analyzer clean; zero `testRule: TestCell` on Tissue constructors; no Tissue write in the instruction) are recorded pass or fail with the command used.
5. **Orphan scan.** List behaviour in the Demo and the test file that serves no requirement. The user chooses: add a requirement, remove it, or accept it.
6. **Residual acceptance (gate L4).** For each row that is not Verified, ask whether the user accepts it, who is accepting it, and a review date. Never fill these in for them.
7. **Show the summary block.** Do not collapse it into one score.

After the first run, protected items are under gate C2. Ask before overwriting the ledger. Repeat steps 4–8 each time the user supplies new output.

**The ledger measures conformance to the BRD as written.** It does not say whether the BRD itself is right.

---

## 8. Decision log, then offer ARCHITECTURE and FEATURES

### 8.1 Decision log (gate C3)

Before ARCHITECTURE is written, show the decision log from `COMPREHENSION-AI-Generator.md` §4: layer placements where more than one layer could answer, resolved findings, accepted residual items, adopted or declined Recommendations, departures from a layer HowTo, and approved protected changes. Record only alternatives that were actually raised. Ask:

> Is this decision log right?

### 8.2 Offer the documents

Then offer the remaining documents. Do not generate them unless the user asks (one, both, or neither).

| Option | Script | Output | Hard stop if missing |
|---|---|---|---|
| ARCHITECTURE | `ARCHITECTURE-AI-Generator.md` | `<stem>-ARCHITECTURE.md` | Demo **and** WalkThrough |
| FEATURES | `FEATURES-AI-Generator.md` | `<stem>-FEATURES.md` | Demo |

Each generator already consults the three layer HowTos. They do not need this file to run.

Added rules for both documents:

1. If `<stem>-LEDGER.md` exists, read it. Never describe a requirement as handled when the ledger marks it Blocked, Failed, or Unverified. List Accepted residual items in the limitations.
2. Cite decision IDs where a design choice appears. Link to the log; do not restate the reasoning.
3. Open with a short summary headed *What a reader must understand* when useful. There are no word limits.
4. If no ledger exists, say so once and continue.

Show the generator's extract / inventory **before** writing the file. Never overwrite without asking.

---

## 9. Change mode

Use for a solution that already has a BRD, WalkThrough, Demo, and ledger. Follow `CHANGE-AI-Generator.md` exactly. Do **not** block that generator on this orchestration file.

Ask for the change type; a change may combine types:

| Type | Trigger |
|---|---|
| `requirement` | A rule, parameter, scope item, or target is added, changed, or retired |
| `upgrade` | The Mitosis packages or Dart SDK version changes |
| `drift` | The Dart was edited by hand, or a document and the code disagree |
| `defect` | A ledger row is Failed, or a bug is reported |

Flow:

1. **State the change (gate CH1).** Show it as a BRD diff. Bump the BRD version and add a row to its Change history. No edits until the user confirms.
2. **Impact (gate CH2).** Trace by ID through the BRD, coverage matrix, checks, ledger, decision log, and documents. Unknown items are treated as affected. Confirm the impact list and the plan together.
3. **Apply.** Amend, do not regenerate. Update BRD, WalkThrough scenarios, tests (from the BRD criteria), Dart, and Demo minimally. Run analysis and `dart test <stem>-test.dart`.
4. **Drift (gate CH3).** For each difference between code and BRD: adopt (change the BRD), revert (change the code), or accept (residual, named person, review date). Never pick for the user. Never edit one side to match the other without a decision.
5. **Ledger.** Affected rows reset to Unverified. A row is Verified after the change only if its check passed in this change's run. Retired requirements move to a Retired block; they are not deleted.
6. **Residual re-acceptance (gate CH4).** An old acceptance does not carry over when the requirement it covered changed.
7. **Release check (gate CH5).** Every Must row Verified or Accepted by a named person; no row Blocked by this change; no Unknown impact item; every drift item has a disposition; every protected change has an approval; BRD history, ledger name plate, and decision log updated. If any condition fails, report it and ask. Do not release for the user.

For an `upgrade`, record the Dart SDK and package versions before and after in the ledger name plate, read the CHANGELOG range, resolve live signatures from pub.dev, upgrade one release step at a time while the packages are pre-1.0 unless the user decides otherwise, and never invent a data migration.

---

## 10. Pipeline checklist

```text
[ ] HowTo-Mitose.md read (or user started Mitose by name); mode chosen (new / resume / change)
[ ] Workspace searched for *-BRD.md and the files in §0
[ ] BRD exists via upload / template return / interview / pasted paragraph
[ ] Gate B1: requirement register, parameter register, findings shown and answered
[ ] WalkThrough written per WalkThrough-AI-Generator.md; coverage matrix uses BRD IDs
[ ] Comprehension check offered (taken, skipped, or declined) before WalkThrough acceptance
[ ] User accepted WalkThrough (or requested edits first)
[ ] Demo written only after that acceptance; decision logic importable; header lists IDs covered and not covered
[ ] WalkThrough Demo Assessment + Recommendations updated from Demo.dart
[ ] Residual ledger offered (accepted or declined by the user)
[ ] No row marked Verified without executed evidence; source of each run recorded
[ ] Expected values taken from the BRD, not from the Demo
[ ] No protected item changed without a recorded decision
[ ] Orphan behaviours listed; each has a user decision
[ ] Residual items accepted only by a named person with a review date
[ ] Decision log shown before ARCHITECTURE
[ ] ARCHITECTURE / FEATURES offered, not assumed; both read the ledger if one exists
[ ] Decision log shown before ARCHITECTURE was written
[ ] No overwrite without asking
[ ] Layer HowTos used for API placement; this file not required for that work
[ ] Change diff confirmed before any edit
[ ] Impact list traced by ID; Unknown items treated as affected
[ ] Affected ledger rows reset; Verified only after a passing run
[ ] Drift items each have a user disposition
[ ] Release check met, or the failing condition reported
[ ] Autonomous mode offered once, after the BRD existed, at gate A1; the choice and the delegating person recorded
[ ] In autonomous mode: no gate waited; no comprehension check offered; every AI decision tagged and listed in the final report
[ ] In autonomous mode: no file overwritten (new SemVer file written instead); no Verified row without an executed run; no protected item loosened
[ ] In autonomous mode: Failed rows not accepted; acceptance never used to cover a missing run
[ ] In autonomous mode: Dart SDK installed if missing; package:cell, package:cell_flow, package:cell_tissue added; WalkThrough implemented (instruction, chain, observe glue, books) and first Demo + Test cover all BRD requirement IDs without asking
[ ] In autonomous mode: after BRD completion the pipeline runs to the end with no further user input, no comprehension check, and all open items decided by the agent
[ ] In autonomous mode: WalkThrough §5.12 Demo Assessment is filled from the executed Demo and test results using WalkThrough-AI-Generator.md §6 with the same detail as manual mode
[ ] In autonomous mode: LEDGER, ARCHITECTURE and FEATURES are generated by following their respective AI-Generator scripts exactly
[ ] All document generations (both modes) use their corresponding generator script; ad-hoc writing is invalid (Rule 22)
[ ] All document generations follow their corresponding generator script exactly (Rule 22). Ad-hoc writing is invalid.
[ ] Every BRD test compares actual vs expected and calls expect() before printing LEDGER PASS (Rule 24)
[ ] All documents (WalkThrough, LEDGER, ARCHITECTURE, FEATURES, COMPREHENSION) are generated in full by following their generators; stubs are invalid (Rule 25)
[ ] Demo implements the WalkThrough in full (instruction, chain, observe, txApply); slim pure-function Demo is invalid (Rule 26)
```

---

## 11. Acceptance criteria for a Mitose run

A run is accepted only when all rows that apply hold. Show Pass / Fail to the user.

| ID | Criterion | Method |
|---|---|---|
| P-AC-01 | A filled BRD existed before the WalkThrough was written; no file was overwritten without asking | chat log, files |
| P-AC-02 | Gate B1 was shown and answered before the WalkThrough; unresolved findings were carried as open questions | chat log |
| P-AC-03 | The WalkThrough coverage matrix uses the BRD's own requirement IDs | compare BRD |
| P-AC-04 | The comprehension check was offered before WalkThrough acceptance, and its outcome (taken, skipped, declined) is recorded | COMPREHENSION record |
| P-AC-05 | The Demo was written only after WalkThrough acceptance; decision logic is importable; IDs covered / not covered are in the header | inspect Demo |
| P-AC-06 | The Demo Assessment was filled from the Dart file; unproven clauses are not claimed as handled | compare `main()` |
| P-AC-07 | If a ledger exists, no row is Verified without a recorded run, and each run names its source | inspect ledger |
| P-AC-08 | Every expected value traces to a BRD ID or parameter, not to Demo output | inspect `<stem>-test.dart` |
| P-AC-09 | Every change to a protected item has a recorded decision with a named approver | change log |
| P-AC-10 | The decision log was shown (gate C3) before ARCHITECTURE was written | chat log |
| P-AC-11 | ARCHITECTURE and FEATURES do not describe a Blocked, Failed, or Unverified requirement as handled | compare ledger |
| P-AC-12 | Residual items were accepted only by a named person, each with a review date | ledger |
| P-AC-13 | (removed — no length caps) | — |
| P-AC-14 | Seam and grep rules were checked mechanically, with the command and result recorded | run log |
| P-AC-15 | In change mode: impact was traced by ID, Unknown items were treated as affected, and the release check was reported | change file |
| P-AC-16 | Autonomous mode was offered once, after a BRD existed, before gate B1, and only chosen by the user; the delegating person is recorded | chat log |
| P-AC-17 | In an autonomous run, no gate waited for the user, no comprehension check was offered, and `<stem>-COMPREHENSION.md` records `declined — autonomous mode` | chat log, COMPREHENSION record |
| P-AC-18 | Every AI decision is tagged `[AI DECIDED — autonomous]` where it appears, has a decision-log entry with `Decided by: AI (autonomous mode), delegated by <name>`, and appears in the final report | inspect BRD, log, report |
| P-AC-19 | In an autonomous run, no file was overwritten, no row is Verified without an executed run, no protected item was changed after the first run, and no Failed row was accepted | files, ledger, run log |
| P-AC-20 | The final report lists every AI decision, every item the agent could not decide, every Failed or Unverified row, every delegated acceptance with its review-by date, and the commands to run if Dart was not executed | inspect report |

Fail any row → do not claim the run is done.

---

## 12. Gate index

| Gate | Where | Question |
|---|---|---|
| A1 | §3.2A | “How do you want to run the rest of the pipeline: step by step, or autonomous?” |
| B1 | §3.3 | “Is this register, parameter list and findings list right?” |
| C1 | §4 | “Before you accept the WalkThrough, would you like to predict three scenarios?” |
| L1 | §7 | “Is this register, parameter list and findings list right?” (full) |
| L3 | §7 | “Here are the commands. Please run them and send the `LEDGER` lines.” |
| L4 | §7 | “Which of these residual items do you accept, and who is accepting them?” |
| C2 | §1 rule 13 | “These protected items would change. Approve, decline, or revise?” |
| C3 | §8.1 | “Is this decision log right?” |
| CH1–CH5 | §9 | Diff, impact and plan, code vs BRD differences, residual re-acceptance, release |

One human decision at each gate. Do not chain them. In autonomous mode only A1 is asked; every later gate follows the table in §15.3.

---

## 13. What this file is not

- Not a Cell / Flow / Tissue API manual.
- Not a substitute for the interview script or the generators.
- Not required reading before `HowTo-Mitose-Cell.md`, `HowTo-Mitose-Flow.md`, or `HowTo-Mitose-Tissue.md`.
- Not permission to invent BRD content, collapse the seam, write FEATURES from a WalkThrough wish-list, mark a requirement Verified from reading code, or accept residual risk on the user's behalf.
- Not a proof of correctness. A ledger with no Failed rows shows only that the stated checks passed, and conformance is measured against the BRD as written.
- Not a way to obtain approvals. Autonomous mode lets the agent decide and proceed. It does not make an AI decision into a person's approval, and it does not make an AI-decided BRD value a business fact.
- Not a measure of anyone's skill, and not a replacement for reading the code that ships.

---

## 14. Release notes

### 14.1 What changed from 1.0 to 2.0

| Area | 1.0 | 2.0 |
|---|---|---|
| Naming | “Mitose” described loosely | Mitosis is the noun (the framework). Mitose is the verb. |
| Rules | 8 rules | 16: adds ID discipline, ledger as source of truth, executed evidence, BRD-sourced expected values, protected items, no invented history, describe-never-grade |
| Modes | New build only | New build, resume, and change |
| BRD gate | Four starts | Four starts plus readiness check B1 |
| WalkThrough | Accepted by the user | Uses BRD IDs; carries findings; opens with a short summary; comprehension check C1 |
| Demo | Behaviour from the WalkThrough | Importable logic; `<stem>-test.dart` always written with it; IDs covered / not covered; comparing banners; ID tags. No Check file. |
| Revisit | §6 | Unchanged; unproven clauses now feed the ledger |
| Residual error | Not measured | New §7: ledger from `<stem>-test.dart` report, orphan scan, residual acceptance (L1, L3, L4). No Check file. |
| Documents | Offered after Revisit | Decision log C3 first; documents read the ledger |
| Change | No path | New §9 (CH1–CH5) |
| Acceptance | Checklist only | Checklist plus §11 acceptance criteria |

### 14.2 Companion changes needed for the full 2.0 set

| File | Change |
|---|---|
| `Business_Requirements_Document.md` | Replace with v2.0: criteria and verification classes on every requirement, Priority on all tables, parameter register, rule precedence, consistency checks, change history |
| `BRD-AI-Interview.md` | Ask for the number behind each threshold and for priority on reporting and non-functional rows; write IDs and a Change history; run gate B1 after writing |
| `WalkThrough-AI-Generator.md` | Opens with a short summary headed *What a reader must understand*; coverage matrix uses BRD IDs; Blocking findings go to Open questions (§5.11). Pulse path is §5.5. Demo Assessment is §5.12. Checklist is §8 of that generator. |
| `ARCHITECTURE-AI-Generator.md`, `FEATURES-AI-Generator.md` | Read the ledger; cite decision IDs; add the summary; replace “German verb” wording |
| `HowTo-Mitose-Flow.md` and other layer HowTos | Replace “German verb” wording |
| `LEDGER-AI-Generator.md`, `COMPREHENSION-AI-Generator.md`, `CHANGE-AI-Generator.md` | New scripts. Required by §7, §4 and §8, and §9 |
| `HowTo-Mitose-Organ.md` | Left out for now. Until it is written, §4 defers entity-graph needs. Do not assign `cell_organ` from memory. |

### 14.3 Known limits

1. A runtime that cannot execute Dart cannot produce executed evidence itself. It asks the user to run the commands (L3).
2. Importable Demo logic and comparing banners change how Demos are written. Existing 1.0 Demos need a one-time refactor before their rows can be Verified.
3. Numeric defaults in the generators (the bulk-change threshold) are `[AI SUGGESTED]` starting values. Calibrate them on a real run.

### 14.5 What changed from 2.1 to 2.2

| Area | 2.1 | 2.2 |
|---|---|---|
| Dart environment | Agent asks user to run commands if Dart is missing | In autonomous mode the agent first installs a Dart SDK, adds `cell` / `cell_flow` / `cell_tissue`, and implements the WalkThrough (instruction, chain, observe glue, books) without asking |
| Demo generation | Offered after WalkThrough acceptance | In autonomous mode generated automatically with the three packages, covering all BRD requirement IDs on the first write |
| Rules of engagement | 19 | 21 (Dart setup + uninterrupted full-pipeline run after BRD) |
| Pipeline continuity | Gates may pause | After A1 the pipeline runs to the end with no further user input; open items decided by AI; comprehension skipped |
| WalkThrough §5.12 | Filled only after user accepts Demo Assessment | In autonomous mode filled automatically from the executed Demo and test results, using WalkThrough-AI-Generator.md §6 with the same detail as manual mode |
| Document generators | Used in step-by-step mode | MUST be used in both modes. Autonomous mode does not permit ad-hoc writing. A document not produced by its generator is invalid (Rule 22). |
| Master generator | Consulted before generators | Removed. Individual generators are named directly by HowTo-Mitose. |
| Live signatures | Idealized patterns assumed | Resolve from installed packages. Record deviations when live APIs prevent the idealized shape (Rule 25). |
| Post-Demo reconciliation | §5.12 filled | Contract sections (§5.2–§5.5, §5.7, §5.10, coverage) must match executed Demo or clearly mark intended vs executed before ARCHITECTURE/FEATURES/LEDGER (Rule 26). |
| Test assertions | LEDGER lines printed | Every BRD test must compare actual vs expected and call expect() before printing LEDGER PASS (Rule 24). Applies in both modes. |
| Document completeness | Stubs accepted | All documents must be generated in full by following their generators completely. Stubs and slim WalkThroughs are invalid (Rule 25). Applies in both modes. |
| Demo completeness | Simplified stand-in accepted | Demo must implement the WalkThrough in full (instruction, chain, observe, txApply). A slim pure-function Demo is invalid (Rule 26). Applies in both modes. |

### 14.4 What changed from 2.0 to 2.1

| Area | 2.0 | 2.1 |
|---|---|---|
| Modes | New build, resume, change | Adds an opt-in **autonomous** run for new build and resume. Change mode stays interactive |
| Gates | A human answers B1, C1, L1, L3, L4, C3 and every “proceed” | New gate A1 (§3.2A). After A1 = autonomous, every later gate is an automatic, recorded decision (§15.3) |
| Open items | Carried as Blocked rows until a person answers | Decided by the agent from the BRD, the HowTos, and conservative industry norms; tagged `[AI DECIDED — autonomous]` (§15.4) |
| Comprehension check | Offered once at C1 | Not offered; recorded as `declined — autonomous mode` |
| Residual acceptance | Named person only | May be delegated at A1 for Blocked and class J rows; never for Failed rows, never to cover a missing run (§15.6) |
| Overwrite questions | Ask the user | Never overwrite; write a new SemVer file (§15.2) |
| Evidence | Agent runs Dart or asks the user to (L3) | Agent runs Dart if it can; otherwise the ledger stays Unverified and the commands go in the final report (§15.7) |
| Rules of engagement | 18 | 19 |

Companion edit recommended for the other generators, one sentence each (`WalkThrough`, `LEDGER`, `COMPREHENSION`, `ARCHITECTURE`, `FEATURES`): *In autonomous mode (`HowTo-Mitose.md` §15) every “wait” or “ask” in this file becomes a recorded automatic decision, every overwrite question becomes a new SemVer file, and an acceptance row whose method is “chat log” for a user answer is read as “run log”.* Until that edit is made, §15.3 of this file governs.

---

## 15. Autonomous mode

**Added in 2.1, strengthened in 2.2.** Autonomous mode runs the pipeline after the BRD without asking the user anything further and without interruption. It is opt-in, offered once at gate A1 (§3.2A), and it starts only after a filled `<stem>-BRD.md` exists. Once chosen, the agent decides every open item, skips the comprehension check, generates the WalkThrough, writes and executes a full-coverage Demo and Test, writes the ledger and remaining documents, and ends with the final report. The only stops are those in §15.8.

### 15.1 Scope

| Runs autonomously | Does not |
|---|---|
| Gate B1 → WalkThrough → Demo and `<stem>-test.dart` → Demo Assessment (§6) → residual ledger (§7) → decision log (§8.1) → ARCHITECTURE and FEATURES (§8.2) | BRD authoring (§3.1–§3.2), because only the user can state the business need |
| New build and resume | Change mode (§9). A change to an existing solution involves drift and release decisions, so it stays interactive |

The agent never sets a BRD's Status to `approved` and never fills BRD §15 Approvals.

### 15.2 What does not change

Autonomous mode removes questions. It does not remove rules. These still hold, and a run that breaks one has failed:

1. **Seam and grep rules.** The instruction decides, the chain assembles, the observer glues. Zero `testRule: TestCell` on Tissue constructors. No Tissue write in the instruction. The `constraint`, `provenance`, and `boundary` groups still fail the suite.
2. **Executed evidence only.** No row is Verified from reading code, and none without a recorded run that names its source (§1 rules 10–11).
3. **Expected values come from the BRD and the parameter register,** never from the Demo's output. A value the agent decided under §15.4 counts as a BRD value only after it has been written into the BRD with its tag.
4. **No overwrite.** The agent never asks, so it never replaces a file. If an artifact already exists, write the next version under the SemVer rules in §0 (`<stem>-<artifact>-vM.m.p.<ext>`) and record `Supersedes`. A change file is never replaced.
5. **No invented people, approvals, or sources.** The agent does not invent names of people, companies, systems, or regulations, and does not record a signature or approval for anyone.
6. **No loosening to pass.** Protected items are not changed to make a check pass (§15.5). Class J is never Verified.
7. **Layer HowTos remain the source of placement.** The agent does not assign a part from memory, and does not assign `cell_organ` (§4).
8. **Mitose is the verb, Mitosis the noun.** Do not rename files.

All six Precision Software Engineering components stay in force. A decision made by the agent is provenance in component 4: it says *who decided*, and the answer is `AI (autonomous mode), delegated by <name>`.

### 15.3 Gate table

“Continue” always means: write what the gate would have shown into the run log, then go on without waiting.

| Gate or question | Step by step | Autonomous |
|---|---|---|
| A1 | Ask | The only question. Asked once, before B1 |
| B1 readiness check (§3.3) | Show, ask, wait | Show in the run log. Resolve every finding and open item under §15.4. Bump the BRD version and add one Change history row for the batch. Continue |
| Nine-slot table and layer map (WalkThrough generator) | Show, ask “proceed?” | Show in the run log. Continue |
| WalkThrough open questions (§5.11) | Carry as open | Resolved under §15.4. Each decided row says `AI DECIDED`; rows that §15.4 forbids the agent to decide stay open |
| C1 comprehension check | Offer once | **Not offered.** `<stem>-COMPREHENSION.md` is still written, with the comprehension block `declined — autonomous mode` and counts asked 0 · matched 0 · mismatched 0 · skipped 0 · undetermined 0 |
| WalkThrough acceptance | Ask | Accepted automatically. Recorded in the decision log as `AI-accepted under delegation`, not as the user's acceptance |
| Demo offer (§5) | Ask | Generate `<stem>-Demo.dart` and `<stem>-test.dart` together |
| §6 enhancement offer | Three choices | Always **Skip**. Applying a recommendation would add behavior no requirement asked for. Recommendations stay in WalkThrough §5.12 and in the final report |
| Overwrite questions | Ask | Never overwrite. Write the next SemVer file (§15.2 rule 4) |
| Ledger offer (§7) | Ask | Generate |
| L1 extract | Ask | Show in the run log. Continue |
| L3 commands | User runs them | Agent runs them if it can (§15.7). If not, rows stay Unverified and the commands go in the final report |
| Orphan scan | User chooses add / remove / accept | Agent chooses. **Remove** a code branch with no requirement. **Accept** harness scaffolding the WalkThrough itself requires. **Add a requirement:** never, because that would change the business intent. Each disposition is logged |
| L4 residual acceptance | Named person | Delegated acceptance under §15.6 |
| C2 protected change | Approve, decline, or revise | No protected item changes after the first run (§15.5). Before the first run, see §15.5 |
| C3 decision log | Ask | Show in the run log. Continue |
| ARCHITECTURE / FEATURES inventory and offer | Ask | Generate both. Each shows its inventory or extract in the run log and continues |
| CH1–CH5 | Change mode | Not applicable |

Acceptance rows in a generator that name “chat log” as the method for a user answer (for example `WalkThrough` G-AC-02, `ARCHITECTURE` G-AC-03, `FEATURES` G-AC-02, `LEDGER` G-AC-02) are read as “run log” in autonomous mode. Rows that require executed evidence or inspection are not relaxed.

### 15.4 Deciding open items

An *open item* is anything the interactive pipeline would carry forward for a person to answer: a `[To be confirmed]` value, a `TBD` parameter, a missing precedence rule, a Blocking or Clarify finding, a WalkThrough open question, an `[AI SUGGESTED]` item.

Decide each one from these sources, in order:

1. The BRD's own text, including its journeys, glossary, and risks.
2. The three layer HowTos and the generator rules.
3. Widely accepted norms for the industry the BRD names.
4. The most conservative reading: the smaller scope, the stricter limit, the safer failure.

Rules:

1. **Keep the user's numbers exactly.** Never change a value the user stated.
2. **Write the decision into the BRD,** not only into the WalkThrough. Mark it `[AI DECIDED — autonomous]` where it appears. In the parameter register set Status to `AI-decided` and Owner to `AI (autonomous mode), delegated by <name>`. In §7.6 add the precedence rule. Then run the tests from the BRD, so the expected value still comes from the BRD.
3. **Version the BRD once per run.** One MINOR bump and one Change history row: Change ID `—`, summary `Autonomous resolution of open items (see decision log D-nn to D-mm)`.
4. **`[AI SUGGESTED]` items** left in the BRD by the interview are accepted by choosing autonomous at A1. They keep their tag so the provenance stays visible. The decision log gets one entry that lists their IDs.
5. **Consistency checks (BRD §14.1):** tick a box only if the agent actually checked it. Otherwise write the finding.
6. **Do not decide what a person must supply.** The agent leaves these as `[To be confirmed from BRD]`, lists each in the final report under *Not decidable by the agent*, and does not let them stop the run:
   - names of approvers, sponsors, owners, and reviewers, and every signature and approval date;
   - a regulation, standard, contract clause, or system the BRD does not name;
   - a fact about the real organization (budget, headcount, an existing system's interface).

   If a check depends on such an item, its row is Blocked and says why. If the BRD needs such an item to proceed at all (for example, a rule that cites a regulation the BRD never names), decide the smaller stand-in, mark it an illustration, and defer the real thing to Real desk / Wave A.
7. **Decision-log entries** use the format in `COMPREHENSION-AI-Generator.md` §4. `Decided by` is `AI (autonomous mode), delegated by <name>`. `Alternatives considered` lists the options the agent actually weighed in this run, each with the reason it was not chosen, or `none raised`. Do not invent alternatives to pad an entry.

### 15.5 Failing checks and protected items

Protected items (§1 rule 13) are expected values, criteria, tolerances, parameter values used by a check, the set of checks, comparison types, and skip markers.

1. **Before the first recorded run of `<stem>-test.dart`,** the agent may amend a value it decided itself in this run, once, if building the test shows that the value contradicts another BRD requirement. Record the amendment in the decision log.
2. **After the first recorded run, protected items are fixed.** When a check fails, fix the code. `[AI SUGGESTED]` limit: three fix attempts per failing check. After that the row stays **Failed**, and the final report lists it first.
3. The agent never deletes, skips, comments out, or marks pending a check to reach green, and never widens a tolerance or turns an exact comparison into a range.
4. A value the user stated is never amended by the agent.

### 15.6 Residual acceptance under delegation

Choosing autonomous at A1 is the user's delegation. It lets the agent record acceptance for some rows. It is not the user's own approval and the ledger says so.

| Row state | Autonomous handling |
|---|---|
| **Failed** | **Never accepted.** Stays Failed and heads the final report |
| Unverified **only because no run happened** (Dart not executed, §15.7) | **Not accepted.** Acceptance cannot cover a missing run. The row stays Unverified and the release gap shows it |
| Blocked by an item the agent was not allowed to decide (§15.4 rule 6) | Accepted by delegation |
| Class J | Accepted by delegation |
| Class M or H that needs an environment or people the agent does not have | Accepted by delegation |
| Orphan behavior | Dispositioned under §15.3 |

For an accepted row, write: `Accepted by: <name> (delegated to AI, autonomous mode)`; `Date`: the run date; `Review by`: `[AI SUGGESTED]` 30 days after the run date; `Reason`: the cause from the table above. Show the count of delegated acceptances in the ledger summary block next to the count of rows whose expected value depends on an `AI-decided` parameter. Never fold either into a single score.

### 15.7 Running Dart (and autonomous environment setup)

In autonomous mode the agent **always** attempts the following before treating Dart as unavailable, without asking the user:

1. **Install a Dart SDK** if `dart` is not on the PATH. Prefer a direct binary download of the stable SDK (e.g. from `storage.googleapis.com/dart-archive`) into a writable location such as `/tmp/dart-sdk` and prepend its `bin` directory to `PATH`. Record the version obtained.
2. **Create or reuse a project** (`pubspec.yaml`) and run `dart pub add cell cell_flow cell_tissue` plus `dart pub add --dev test`. Resolve live signatures from the installed packages; never invent APIs.
3. **Implement the WalkThrough in `<stem>-Demo.dart`** using the three packages so that the first write meets **all** requirement IDs in the BRD:
   - custom instruction (or pure decision function that stands in for `FlowInstruction`) that decides,
   - chain assembly (`+`, `MapValue`, `toHandle` once per product) where the API permits,
   - `Cell.observe` as the **only** glue that writes Tissue books,
   - Tissue books for every collection the WalkThrough named (List / Map / Value / Set / Queue as appropriate),
   - behaviour that satisfies every FR / DR / BR / AR / NFR criterion that can be expressed as a check.
   No confirmation is required; this is the default autonomous behaviour. Do not leave requirement IDs for a later pass if they can be covered now.
4. Write `<stem>-test.dart` that imports the Demo without running `main()`, contains a `BRD` group with one test (and a `LEDGER` line) for **every** requirement ID in the BRD, and the `constraint` / `provenance` / `boundary` groups. Expected values come from the BRD.
5. Run `dart analyze`, `dart run <stem>-Demo.dart`, and `dart test <stem>-test.dart`. Record the output with source `agent executed`.
6. **Update documents using their generators.**  
   - Update the WalkThrough using `WalkThrough-AI-Generator.md` §6. Fill §5.12 Demo Assessment from the Dart file and the test results with the same detail required in manual mode. Do not leave the stub.  
   - Write the ledger by following `LEDGER-AI-Generator.md` exactly (all required blocks in §4, updated from evidence per §7).  
   - Write ARCHITECTURE by following `ARCHITECTURE-AI-Generator.md` exactly.  
   - Write FEATURES by following `FEATURES-AI-Generator.md` exactly.  
   Autonomous mode does not replace any of these generators with ad-hoc writing. A document that was not produced by following its generator is invalid.

If after the install attempt Dart is still unavailable, or `dart analyze` still fails after three fix attempts, fall back to the previous rule: write the files, leave rows Unverified, and put the exact commands in the final report.

The agent never asks the user for permission to install the SDK or to add the three packages when running autonomously.

### 15.8 Stop conditions

The agent stops, writes what it has, and reports. It does not guess its way past these:

1. A layer HowTo (`HowTo-Mitose-Cell.md`, `-Flow.md`, `-Tissue.md`) cannot be read.
2. The BRD has no usable requirement content.
3. `dart analyze` still fails after three fix attempts (§15.7).
4. The user sends a message that says to stop, or changes the instruction.

Stopping is not failing. The report lists the files written, the stage reached, and how to resume.

### 15.9 Final report

At the end of the run, show one report in chat. It is built from the files, so nothing in it is new information. It lists:

| Block | Content |
|---|---|
| Run | Delegating person, date, BRD version before and after, whether Dart was executed |
| Files | Each file written, with name and version, including any `-vM.m.p` files written instead of overwriting |
| AI decisions | Every `[AI DECIDED — autonomous]` item: ID, what was decided, where it is tagged, decision-log ID |
| Not decidable by the agent | Every item left `[To be confirmed from BRD]` under §15.4 rule 6 |
| Ledger summary block | The §6 measures from `LEDGER-AI-Generator.md`, plus delegated acceptances and rows depending on `AI-decided` parameters |
| Failed rows | Listed first, with the failing `LEDGER` line |
| Unverified rows | With the reason, and the commands to run if Dart was not executed |
| Delegated acceptances | Row, reason, review-by date |
| Unproven clauses | Clauses in `riskOf` that `main()` does not drive (WalkThrough §5.12) |
| Skipped | Recommendations for Enhancement not applied; the comprehension check not offered |
| How to reopen | Any AI decision can be reopened as a `requirement` change in change mode (§9) |

### 15.10 What this mode costs

Autonomous mode trades review for speed. The documents exist, but no person has read them, and the BRD now contains values nobody in the business set. The ledger can show that the Demo conforms to the BRD **as the agent completed it**. It cannot show that the completed BRD is right. The final report says this plainly. Read the BRD tags first.

---

*End of HowTo-Mitose.md v2.2.*
