# HowTo-Mitose.md



## Same-directory dependencies

All Mitose scripts in this set live in **one directory** (this file's directory). Resolve a sibling by filename here first. Do not prefer a remote or package copy over a sibling that is present. A missing sibling is a stop only when this file says that sibling is required.

| Sibling | Role |
|---|---|
| `HowTo-Mitose.md` | Orchestration 2.0. Optional for layer HowTos and for ARCHITECTURE / FEATURES extraction. Required to start a full Mitose run. |
| `Business_Requirements_Document(BRD).md` | BRD template 2.0. Shape of `<stem>-BRD.md`. |
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

**Version:** 2.0 (supersedes 1.0; release notes in §14)

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
| Fill a BRD from a template | `Business_Requirements_Document(BRD).md` (v2.0) | No |
| Write the WalkThrough | `WalkThrough-AI-Generator.md` | No (it consults the three layer HowTos) |
| Measure residual error; write the ledger from the test report | `LEDGER-AI-Generator.md` | No |
| Comprehension check, change control, decision log | `COMPREHENSION-AI-Generator.md` | No |
| Change, upgrade, repair, or reconcile an existing solution | `CHANGE-AI-Generator.md` | No |
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
| `Business_Requirements_Document(BRD).md` | Offline template the user fills and returns |
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
7. One human decision at each gate. Do not chain gates, and do not chain Demo + ledger + ARCHITECTURE + FEATURES in one silent pass unless the user asked for the whole set.
8. Stop and ask if a required script or HowTo cannot be read.
9. **IDs are permanent and are how you trace.** Requirement IDs are never reused or renumbered. Impact, coverage, and evidence are traced by ID. A link you cannot trace is `Unknown`, and Unknown is treated as affected.
10. **The ledger is the source of truth for *what has been shown to work*.** The BRD says what is required, the Demo says what the program does, and the ledger says which requirements have executed evidence. Never describe a requirement as handled when the ledger says Blocked, Failed, or Unverified.
11. **Verified needs executed evidence.** Never mark a row Verified from reading code. Record where each run came from (the agent executed it, or the user supplied the output).
12. **Expected values come from the BRD and its parameter register,** never from the Demo's own output.
13. **Protected items change only under gate C2** (expected values, criteria, tolerances, parameter values used by checks, the set of checks, comparison type, skip markers). When a check fails, fix the code first.
14. **Do not invent history.** Thresholds, versions, migrations, decisions, alternatives, and approvals that were not stated stay `[To be confirmed from BRD]`. Approvals belong to named people. The agent never records an approval it did not receive and never accepts residual risk for the user.
15. **State a fact once.** Every generated document opens with a short summary headed *What a reader must understand* when useful. There are no word caps. Link by ID.
16. **Describe, never grade.** Record what a person predicted and what the BRD says. Do not rate the person and do not produce a comprehension score.
17. **Mitosis is the noun. Mitose is the verb.** Do not rename a file, a heading, or a package from Mitose to Mitosis. Mitosis is the framework. Mitose is this pipeline.
18. **Use only the latest generated file.** When more than one version of an artifact exists, read the highest version. Record the filename and version in the name plate of the file you write.

### Opening line

> I have HowTo-Mitose.md 2.0. I will run the Mitose pipeline: BRD gate and readiness check → WalkThrough (with a short prediction check) → Demo (on your OK) → WalkThrough assessment against the Dart file → residual ledger → decision log → offer ARCHITECTURE and FEATURES. For an existing solution I will run change mode instead. Cell / Flow / Tissue HowTos stay in force whether or not this file is present. First I will look for a BRD.

Then run §2.

---

## 2. Start Mitose

A user starts Mitose by:

- attaching or naming this file, **or**
- pointing at the public copy (`HowTo-Mitose.md` under the guide URL above), **or**
- saying “Mitose” / “run Mitose” in chat for a new build, or “Mitose change” for a change to an existing solution.

**Manual-upload fallback.** Some AI prompts cannot access the GitHub repository remotely. In that case the user pulls the files from the local `/guide` directory and uploads them manually (as chat attachments), and the agent runs the pipeline from the uploaded copies. The uploaded copies take precedence over any remote revision. For a full run the user uploads this file, the BRD interview and template, the three layer HowTos, and the generators named in §0.

Read this file. Then search the workspace for the files in §0 and choose a mode:

| User says | Files found | Mode |
|---|---|---|
| “Mitose” | No filled `*-BRD.md` | **New build** → §3 |
| “Mitose” | Filled BRD, no WalkThrough | **New build** → §3.1, then §3.3 |
| “Mitose” | Some pipeline files already exist | **Resume.** Name the files found and the first missing stage; ask: “Continue at *stage*?” |
| “Mitose change” | BRD, WalkThrough, Demo, and ledger | **Change mode** → §9 |
| “Mitose change” | No ledger | Offer to build the baseline ledger first (§7). Do not start the change |

Stage order for Resume: BRD → B1 → WalkThrough → Demo → Demo Assessment → ledger → decision log → ARCHITECTURE / FEATURES.

---

## 3. BRD gate (required before WalkThrough)

### 3.1 BRD already uploaded

If a filled `<stem>-BRD.md` exists, confirm the stem with the user and go to §3.3.

### 3.2 No BRD yet — offer four starts

Give **all four** options. Do not invent a fifth. Do not start WalkThrough until one path produces a BRD file.

1. **Upload a filled BRD.** User attaches `<stem>-BRD.md` that already has the necessary information. Agent stores it under that name and continues.
2. **Template offline.** Give the user `Business_Requirements_Document(BRD).md` to copy, rename to `<stem>-BRD.md`, fill later, and resubmit. Stop until they return.
3. **Online interview.** Run `BRD-AI-Interview.md` exactly (one question at a time, plain English, no design words). Write `<stem>-BRD.md` at the end of that script.
4. **Paste a requirement paragraph.** User pastes a short requirement at the prompt. Agent drafts `<stem>-BRD.md` from the template as best it can, marks every invented or missing field `[To be confirmed]` / `[AI SUGGESTED]`, shows the draft, and waits for correction before §3.3.

If the user picks (2), do not interview them in the same turn. If they pick (3), do not also ask them to fill the template.

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
6. Check the word count against the cap and report it (`COMPREHENSION-AI-Generator.md` §5). If over, cut or ask (gate C4).
7. **Comprehension check (gate C1).** Offer once: the user predicts the outcome of three scenarios (an ordinary path, a boundary or second interaction, and an interaction) before reading the expected results. Follow `COMPREHENSION-AI-Generator.md` §2. A mismatch is a signal about the document first. Skipping or declining is allowed and recorded. Create `<stem>-COMPREHENSION.md` here.
8. Ask whether the user is satisfied with the WalkThrough.

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
7. **Always write `<stem>-test.dart` with the Demo.** It is the unit-test file and the residual-ledger report. Do not write `<stem>-Check.dart`. Groups are aligned to public APIs and documented contracts, not to banner names. One group is the BRD suite. Expected values in that suite come from the BRD and the parameter register, never from the Demo's own output. Class J is not a unit test. A missing parameter stays `BLOCKED`.

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

Record the choice. If the user chooses Change, enter change mode for that enhancement and do not continue the main pipeline until the CHANGE gates are answered. If the user chooses In place, patch the Demo, re-run, and update the existing files in situ; do not write a CHANGE file and do not bump versions. If the user skips, proceed to the ledger offer.

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
3. Open with the 120-word summary and report the word count against the cap (gate C4).
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

Fail any row → do not claim the run is done.

---

## 12. Gate index

| Gate | Where | Question |
|---|---|---|
| B1 | §3.3 | “Is this register, parameter list and findings list right?” |
| C1 | §4 | “Before you accept the WalkThrough, would you like to predict three scenarios?” |
| L1 | §7 | “Is this register, parameter list and findings list right?” (full) |
| L3 | §7 | “Here are the commands. Please run them and send the `LEDGER` lines.” |
| L4 | §7 | “Which of these residual items do you accept, and who is accepting them?” |
| C2 | §1 rule 13 | “These protected items would change. Approve, decline, or revise?” |
| C3 | §8.1 | “Is this decision log right?” |
| C4 | §4, §8.2 | “This is N words against a cap of M. Cut it, or accept it at this length?” |
| CH1–CH5 | §9 | Diff, impact and plan, code vs BRD differences, residual re-acceptance, release |

One human decision at each gate. Do not chain them.

---

## 13. What this file is not

- Not a Cell / Flow / Tissue API manual.
- Not a substitute for the interview script or the generators.
- Not required reading before `HowTo-Mitose-Cell.md`, `HowTo-Mitose-Flow.md`, or `HowTo-Mitose-Tissue.md`.
- Not permission to invent BRD content, collapse the seam, write FEATURES from a WalkThrough wish-list, mark a requirement Verified from reading code, or accept residual risk on the user's behalf.
- Not a proof of correctness. A ledger with no Failed rows shows only that the stated checks passed, and conformance is measured against the BRD as written.
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
| WalkThrough | Accepted by the user | Uses BRD IDs; carries findings; 120-word summary; comprehension check C1 |
| Demo | Behaviour from the WalkThrough | Importable logic; `<stem>-test.dart` always written with it; IDs covered / not covered; comparing banners; ID tags. No Check file. |
| Revisit | §6 | Unchanged; unproven clauses now feed the ledger |
| Residual error | Not measured | New §7: ledger from `<stem>-test.dart` report, orphan scan, residual acceptance (L1, L3, L4). No Check file. |
| Documents | Offered after Revisit | Decision log C3 first; documents read the ledger |
| Change | No path | New §9 (CH1–CH5) |
| Acceptance | Checklist only | Checklist plus §11 acceptance criteria |

### 14.2 Companion changes needed for the full 2.0 set

| File | Change |
|---|---|
| `Business_Requirements_Document(BRD).md` | Replace with v2.0: criteria and verification classes on every requirement, Priority on all tables, parameter register, rule precedence, consistency checks, change history |
| `BRD-AI-Interview.md` | Ask for the number behind each threshold and for priority on reporting and non-functional rows; write IDs and a Change history; run gate B1 after writing |
| `WalkThrough-AI-Generator.md` | Opens with the 120-word summary; coverage matrix uses BRD IDs; Blocking findings go to Open questions (§5.11). Pulse path is §5.5. Demo Assessment is §5.12. Checklist is §8 of that generator. |
| `ARCHITECTURE-AI-Generator.md`, `FEATURES-AI-Generator.md` | Read the ledger; cite decision IDs; add the summary; replace “German verb” wording |
| `HowTo-Mitose-Flow.md` and other layer HowTos | Replace “German verb” wording |
| `LEDGER-AI-Generator.md`, `COMPREHENSION-AI-Generator.md`, `CHANGE-AI-Generator.md` | New scripts. Required by §7, §4 and §8, and §9 |
| `HowTo-Mitose-Organ.md` | Left out for now. Until it is written, §4 defers entity-graph needs. Do not assign `cell_organ` from memory. |

### 14.3 Known limits

1. A runtime that cannot execute Dart cannot produce executed evidence itself. It asks the user to run the commands (L3).
2. Importable Demo logic and comparing banners change how Demos are written. Existing 1.0 Demos need a one-time refactor before their rows can be Verified.
3. Numeric defaults in the generators (the bulk-change threshold) are `[AI SUGGESTED]` starting values. Calibrate them on a real run.

---

*End of HowTo-Mitose.md.*
