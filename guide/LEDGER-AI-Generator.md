# LEDGER-AI-Generator.md



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

**File role:** An AI-executable **generator** script. An AI prompt agent reads this file and produces `<stem>-LEDGER.md` from a BRD, the accepted WalkThrough, the Demo, and the report printed by `<stem>-test.dart`. It does not write `<stem>-Check.dart`. The test file is written with the Demo (`HowTo-Mitose.md` §5).

**Mitosis** is the framework. **Mitose** is what you do with it. *Mitose* is the German word for cell division (*die Mitose*), and this project borrows it as a verb: you have a business requirement, so you **Mitose it**. The spelling is deliberate. Please do not “correct” it to Mitosis; filenames such as `HowTo-Mitose.md` keep it on purpose. *Mitosis is the noun. Mitose is the verb.*

**Status:** Draft proposal. Not yet part of the published `guide/` set. Written to sit beside `WalkThrough-AI-Generator.md`, `ARCHITECTURE-AI-Generator.md` and `FEATURES-AI-Generator.md`.

This file is **process and format only**. It does not teach `Cell.*` factories, Flow operators or Tissue collections. It does not decide which layer answers a requirement.

| Term | Meaning |
| ---- | ------- |
| **Residual error** | The set of BRD requirements without executed evidence that they are met |
| **Ledger** | The per-requirement record of evidence and result. A list with reasons, not a single score |
| **Test file** | `<stem>-test.dart`, written with the Demo. Unit tests plus the `LEDGER` report the ledger reads. `<stem>-Check.dart` is not used. |

Worked example of the finished format: `Card-Auth-Residual-Ledger.md` and `Card-Auth-BRD-Precision-Revision.md`.

---

## 0. Inputs and hard stops

**Two modes.** *Extract-only* runs at the BRD gate (gate B1 of `HowTo-Mitose.md`): it needs only the BRD, runs §2, shows the result, and stops. *Full* runs after the Demo and writes the ledger.

| Input | Required? | If missing |
| ----- | --------- | ---------- |
| Filled `<stem>-BRD.md` | **Yes** (both modes) | Stop. Send the user back to the BRD gate |
| Accepted `<stem>-WalkThrough.md` | **Yes** (full mode) | Stop. The coverage matrix is the starting trace |
| `<stem>-Demo.dart` | **Yes** (full mode) | Stop. Nothing can be run |
| WalkThrough Demo Assessment (§5.12) filled | Yes (full mode) | Ask the user to run the revisit step first. |
| An executed run of the Demo (console output) | No | Ledger is written, but no row can be Verified |

Never overwrite an existing `<stem>-LEDGER.md` or `<stem>-test.dart` without asking. Do not create `<stem>-Check.dart`.

---

## 1. Rules of engagement

1. **Executed evidence only.** A row is Verified only when a recorded run, or a named reviewer's inspection record, supports it. Reading the Dart file never moves a row to Verified.
2. **Say where the run came from.** For every run, record whether the user supplied the output or the agent executed it, with the date and the command.
3. **The BRD is the oracle.** Expected values come from the BRD and the parameter register. They never come from the Demo's own printed output. A check whose expected value was copied from the Demo proves nothing.
4. **Do not invent business numbers.** A threshold, window or limit with no value in the BRD stays `[To be confirmed from BRD]`. The check is not written, and the row is **Blocked**.
5. **Use the existing tags.** A criterion the agent drafted is marked `[AI SUGGESTED]`. Anything missing is marked `[To be confirmed from BRD]`.
6. **A banner is not evidence by itself.** A Demo banner counts only if the Demo compares an actual value with an expected one before printing it. A row whose only evidence is a printed banner stays Unverified, noted `demo-only`.
7. **Judgment is never Verified.** Class J rows are Accepted by a named person or remain residual.
8. **The agent never accepts residual risk.** Acceptance needs a person's name and a review date supplied by the user.
9. **Report the limit.** Residual here means conformance to the BRD as written. The ledger says nothing about whether the BRD is right.
10. **Seam and grep rules still apply.** No Tissue writes in the instruction. Zero `testRule: TestCell` on Tissue constructors. The test file is harness and may read Tissue books. It does not decide policy.

### Opening line

Full mode:

> I have the BRD, the WalkThrough and the Demo. I will build the residual ledger: for every requirement ID, what executed evidence shows. First I will show you the requirement register, the parameter register and the findings, then I will write the file. I will not mark anything Verified from reading code, and I will not accept residual risk for you.

Extract-only mode (gate B1):

> I have the BRD. Before the WalkThrough I will show you its requirement register, its parameter register and the findings I can see. I will not fix any finding on my own.

---

## 2. Extract (show this before writing any file)

From the BRD, build and show the user:

### 2.1 Requirement register

One row per requirement ID in every requirements table of the BRD (functional, data, rules, reporting, non-functional, or whatever the BRD names). For each row:

| Column | Source |
| ------ | ------ |
| ID, Priority | BRD. If a table has no Priority column, write `none`. Do not guess |
| Criterion | BRD acceptance criteria if one cites this ID. Otherwise draft one and mark it `[AI SUGGESTED]` |
| Class | One of the classes in §3 |
| Planned evidence | The kind of evidence the row will need |

### 2.2 Parameter register

Every threshold, window, limit and list that a requirement refers to: value, unit, owner, status. Value missing → `[To be confirmed from BRD]`. Link each open BRD question to the parameter it affects.

### 2.3 Findings

Check the BRD for these defects and list each with the IDs involved. Do not fix them. Ask the user.

| Check | Looks for |
| ----- | --------- |
| Contradiction | Two requirements that cannot both hold |
| Precedence | Several rules that can fire on one input, with no stated winner |
| Missing value | A rule that depends on a parameter with no value |
| Missing behavior | An invariant with no stated action when it would be violated |
| Orphan rule | A rule no functional requirement enforces |
| Journey mismatch | A journey step that conflicts with a requirement or names a different actor |
| Target mismatch | The same measure with two different targets in two sections |
| Measure basis | A target with no percentile, window, sample size or start and end point |

Mark each finding **Blocking** (no check can be written) or **Clarify** (a check can be written but may test the wrong thing). Rows touched by a Blocking finding are **Blocked**.

Ask whether the register is right. Do not write the ledger until the user answers.

---

## 3. Verification classes

| Class | Meaning | Verified when |
| ----- | ------- | ------------- |
| **T** | Check with a fixed expected result (truth table, boundary) | The check ran and passed; the run is recorded |
| **P** | Property or invariant over generated inputs | The property held over the stated number of cases |
| **M** | Measured against a target (load, availability, recovery) | Measured under stated conditions and met the target |
| **I** | Inspection of code, design or configuration | The inspection result is recorded (see §7) |
| **H** | Human trial or walkthrough | The trial ran with the stated participants and met the target |
| **J** | Judgment | Never Verified. Accepted only |

Boundary cases come from the parameter register: the value just below, at and just above the limit.

---

## 4. Write `<stem>-LEDGER.md`

Write these blocks, in this order:

| Block | Must include |
| ----- | ------------ |
| Name plate | BRD / WalkThrough / Demo / test file / ledger version (MAJOR.MINOR.PATCH) / build or commit / last run / `Last change: CHG-nnn` or `none` / Dart SDK version / Mitosis package versions / `Version: M.m.p` / `Supersedes: <prior or none>` |
| Result values | Verified, Failed, Unverified, Blocked, Accepted, Retired, with the rules in §1 and §4.1 |
| Parameter register | From §2.2 |
| Findings | From §2.3, with the question for the owner |
| Ledger | One table per BRD requirement group. Columns, in this fixed order: `ID, Pri, Class, Planned evidence, Result, Run, Residual note and owner` |
| Summary block | The measures in §6 |
| Blocked-row mitigation | One short recommendation per currently Blocked ID, plus a sequenced mitigation plan (step, IDs, action, evidence that moves the row, owner, depends on, target) |
| Orphan behavior register | Empty at first; filled by §8 |
| Residual acceptance | Empty at first; filled by §9 |
| Run log | One line per run: date, command, who produced the output |

The first version has no Verified rows. Every row is Unverified or Blocked. `Last change` is `none`.

### 4.1 Retired

A requirement removed on purpose moves to a **Retired** block. It is not deleted and its ID is not reused. Columns: ID, change ID, reason, date. The first ledger has an empty Retired block.

Never leave a row out because it is hard to test. A row that cannot be checked is Blocked or class J, and stays visible.

---

## 5. The test file is the evidence (do not write a Check file)

`<stem>-test.dart` is written with the Demo, not here. This generator reads it and its printed report. If it is missing, stop and send the agent back to `HowTo-Mitose.md` §5. Do not invent `<stem>-Check.dart` as a substitute.

The test file must already do all of the following:

1. **Groups align to public APIs and documented contracts.** A `group` name is an exported symbol (`NounRiskInstruction.riskOf`, `installGates`) or a documented contract (BRD, WalkThrough §5.5, seam sentence, grep rule, Demo header Cell I/O table). Do not group by banner names alone.
2. **One group is the BRD suite,** named `BRD`. Its children are requirement IDs (`FR-03`, and a test such as `velocity at threshold declines`). One test may carry several IDs. Expected values in this group come from the BRD, the parameter register, and the WalkThrough coverage matrix. They were not copied from the Demo's printed output.
3. **Only the BRD group prints `LEDGER` lines and only those lines move a ledger row.** A failure in a public-API or contract group does not by itself mark a BRD row Failed.
4. **It imports decision logic from the Demo's library symbols** (instruction, chain, products). It does not copy that logic, and it does not call `main()`.
5. **If the Demo exposes only `main()`,** do not work around it. Mark the affected rows `Unverified (not importable)` and add a Recommendations row to the WalkThrough: *extract the decision logic so the test can import it* (landing layer: harness).
6. **Boundaries use only the parameter register.** An open parameter is a `BLOCKED` report line, not a guessed expected value.
7. **One test in the BRD group per class T row at minimum,** plus the cases the criterion names. Invariants (class P) run over generated sequences. Class J is not a unit test.
8. **Gates are exercised** in the public-API group for that ingress. A bad `TestCell` input is rejected in a test. Having the gate is not evidence.
9. **Three groups fail the suite without moving a BRD row.** `constraint` greps the Demo and fails on `testRule: TestCell` on a Tissue constructor or a Tissue write inside the instruction. `provenance` fails if the header provenance register is missing, a pulse has no source, or a no-write role has no deputy. `boundary` fails if an ingress, `Cell.transaction`, or `Cell.txApply` is neither present nor `deferred` on a named Real-desk row. A blank cell is a failure. `none` requires a reason. Mitose 2.0 defers `Cell.transaction` and uses `Cell.txApply` on Tissue for every all-or-nothing commit.
10. **The BRD group prints the report after its tests,** one line per requirement ID:

   ```text
   LEDGER <ID> <PASS|FAIL|BLOCKED> expected=<from BRD> actual=<observed> note=<short>
   ```

Run it with `dart test <stem>-test.dart`. Pass the path. A bare `dart test` discovers `*_test.dart` under `test/`, not this filename.

---

## 6. Summary block (regenerate on every run)

| Measure | Definition |
| ------- | ---------- |
| Requirements | Count of all rows |
| By priority | Counts of Must, Should, Could, none |
| Verified / Failed / Blocked / Unverified / Accepted | Count by Result |
| **Evidence coverage** | (Verified + Failed) ÷ total rows |
| **Pass rate among covered** | Verified ÷ (Verified + Failed). Write "not defined" when the denominator is 0 |
| **Release gap** | Must rows that are neither Verified nor Accepted |
| Open Blocking findings | Count |
| Class J rows awaiting acceptance | Count |
| Orphan behaviors without a disposition | Count |

Never collapse this into one score. Always show the rows that make up each count.

---

## 7. Update the ledger from evidence

Run this each time the user supplies output or a reviewer records an inspection.

1. Match each `LEDGER` line from the `BRD` group to its requirement ID. Ignore other groups for Verified / Failed.
2. `PASS` → **Verified**. `FAIL` → **Failed**, with the failing line in the residual note. `BLOCKED` stays Blocked.
3. Update `Run` with the date and the source of the output (user or agent).
4. **Mechanical class I checks,** each recorded as pass or fail with the command used:
   - `dart analyze` is clean.
   - Zero `testRule: TestCell` on Tissue constructors.
   - No Tissue write inside the instruction.
   - For a requirement that says "no redeploy" or "no copy": the inspection note names the file and the finding.
5. Classes M and H need their own recorded run. Do not fill them from the unit run.
6. Never change a row from Failed to Verified without a new run.
7. Rows that depend on an open parameter or finding stay Blocked until the user resolves it.

Optional: give a second agent only the BRD and `<stem>-test.dart`, and ask it to list criteria the tests do not exercise. Record each as a finding.

---

## 8. Orphan scan

After the Demo and test file exist, list behavior that serves no requirement:

- a scenario or banner with no BRD id in the coverage matrix;
- an instruction branch with no BRD id;
- a constant or threshold in code with no parameter in the register.

For each, ask the user to choose: add a requirement, remove it, or accept it. Record who decided.

---

## 9. Residual acceptance

For each row that is not Verified, ask whether the user accepts it.

| Column | Rule |
| ------ | ---- |
| Accepted by | A named person the user supplies. Never the agent |
| Date | The date the user gives |
| Review by | A date the user gives. Class J rows require one |
| Reason | The user's words |

An accepted row stays in the ledger and in the summary count. It is not deleted.

---

## 10. Gates

One human decision at each gate. Do not chain them.

| Gate | Question |
| ---- | -------- |
| L1 (also gate B1 in extract-only mode) | "Is this register, parameter list and findings list right?" |
| L3 | "Here are the commands. Please run them and send the output." |
| L4 | "Which of these residual items do you accept, and who is accepting them?" |

There is no L2. The test file is not optional and is not written by this generator.

---

## 11. What this file is not

- Not a proof that the software is correct.
- Not a replacement for the BRD interview or the WalkThrough generator.
- Not permission to invent thresholds, to mark a row Verified from reading code, or to accept risk on the user's behalf.
- Not a test framework manual. It names the evidence and the report lines. `<stem>-test.dart` uses the standard Dart test package. `<stem>-Check.dart` is not part of this pipeline.

---

## 12. After writing

> Done. `<stem>-LEDGER.md` is written from the BRD, WalkThrough and Demo.
>
> Rows: *n* (Must *a*, Should *b*, Could *c*, none *d*)
> Verified: *v* · Failed: *f* · Unverified: *u* · Blocked: *k* · Accepted: *x*
> Open Blocking findings: *m*
> Test file: `<stem>-test.dart` (written with the Demo; Check file not used)
>
> Next: run `dart test <stem>-test.dart` and send the `LEDGER` lines (gate L3).

---

## 13. Checklist

- [ ] BRD, WalkThrough and Demo were read (full mode), or the BRD was read (extract-only mode)
- [ ] Register, parameters and findings were shown and confirmed before the file was written (gate L1 / B1)
- [ ] Every BRD requirement ID has exactly one row, or is in the Retired block
- [ ] Unknown parameter values stay `[To be confirmed from BRD]` and their rows are Blocked
- [ ] No row is Verified without a recorded run; each run names its source
- [ ] Expected values trace to the BRD or parameter register, not to Demo output
- [ ] Class J rows are never Verified
- [ ] A Demo banner that only prints text did not move a row to Verified
- [ ] `<stem>-test.dart` exists and prints `LEDGER` lines; `<stem>-Check.dart` was not written
- [ ] Orphan scan done; each item has a user decision
- [ ] Every acceptance has a named person and a review date
- [ ] Summary block regenerated; no single score
- [ ] Existing ledger and test file were not overwritten without asking

---

## 14. Acceptance criteria for *this generator*

The ledger pass is accepted only when all of the following hold. Show Pass / Fail to the user.

| ID | Criterion | Method |
|---|---|---|
| G-AC-01 | `<stem>-LEDGER.md` exists; no overwrite without asking | file inspect |
| G-AC-02 | The register, parameters and findings were shown and confirmed before writing | chat log |
| G-AC-03 | Every BRD requirement ID has exactly one row or appears as Retired | compare BRD |
| G-AC-04 | No invented threshold: each unknown value is `[To be confirmed from BRD]` and its row is Blocked | compare BRD |
| G-AC-05 | No Verified row lacks a recorded run, and each run names its source | inspect run log |
| G-AC-06 | Every expected value in `<stem>-test.dart` traces to a BRD ID or parameter | inspect test file |
| G-AC-07 | No class J row is Verified | inspect ledger |
| G-AC-08 | Test names begin with a requirement ID, and the report uses `LEDGER` lines | inspect test file |
| G-AC-09 | Orphan scan lists behaviour with no requirement; each has a user decision | inspect register |
| G-AC-10 | Every Accepted row has a named person and a review date given by the user | inspect ledger |
| G-AC-11 | Summary block matches the rows; no single score | recount |
| G-AC-12 | Demo / ARCHITECTURE / FEATURES were not rewritten in this pass | files |

Fail any row → do not claim the ledger is done.

---

*End of LEDGER-AI-Generator.md.*
