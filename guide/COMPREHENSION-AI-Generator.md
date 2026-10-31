# COMPREHENSION-AI-Generator.md



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

**File role:** An AI-executable **generator** script. An AI prompt agent reads this file and produces `<stem>-COMPREHENSION.md`. It also binds the other generators with four rules: a **comprehension check**, **change control** on tests and expected values, a **decision log**, and **** on generated documents.

**Mitosis** is the framework. **Mitose** is what you do with it. *Mitose* is the German word for cell division (*die Mitose*), and this project borrows it as a verb: you have a business requirement, so you **Mitose it**. The spelling is deliberate. Please do not “correct” it to Mitosis; filenames such as `HowTo-Mitose.md` keep it on purpose. *Mitosis is the noun. Mitose is the verb.*

**Status:** Draft proposal. Not yet part of the published `guide/` set. Written to sit beside `LEDGER-AI-Generator.md` and the other generators.

**Why this file exists.** AI generates code and documents faster than people can read them. The gap between what exists and what a person understands is called comprehension debt. This file does not remove that gap. It shrinks what must be understood, keeps the reasons on record, and stops the agent from quietly changing the checks that would catch its own errors.

This file is **process and format only**. It does not teach `Cell.*` factories, Flow operators or Tissue collections.

| Term | Meaning |
| ---- | ------- |
| **Comprehension check** | Three short prediction questions asked before the user accepts the WalkThrough |
| **Protected item** | An expected value, acceptance criterion, tolerance, parameter value used by a check, the set of checks, a comparison type (exact vs range), or a skip marker |
| **Decision log** | The record of design decisions, the alternatives actually considered, and who decided |
| **Length** | No word limits on generated documents |

---

## 0. Inputs and hard stops

| Input | Required? | If missing |
| ----- | --------- | ---------- |
| Filled `<stem>-BRD.md` | **Yes** | Stop. Send the user back to the BRD gate |
| `<stem>-WalkThrough.md` (draft or accepted) | **Yes** | Stop. Scenarios come from its coverage matrix |
| `<stem>-LEDGER.md` and `<stem>-test.dart` | No | §3 stays dormant until the test file or ledger evidence exists |
| Layer placement guides (Cell, Flow, Tissue) | No | The decision log records only what the user states |

Never overwrite an existing `<stem>-COMPREHENSION.md` without asking.

---

## 1. Rules of engagement

1. **Describe, never grade.** Record what was predicted and what the BRD says. Do not rate the person. Do not produce a comprehension score.
2. **Never claim comprehension.** A match shows that the user predicted one scenario correctly. It proves nothing broader.
3. **Expected answers come from the BRD and the parameter register,** never from the Demo's own output.
4. **A mismatch is a signal about the document first.** The BRD or the WalkThrough may be unclear. Check that before assuming the person misunderstood.
5. **Do not invent history.** Never write a decision, an alternative, a reason or an approval that was not stated. Missing items stay `[To be confirmed from BRD]`.
6. **Approvals belong to named people.** The agent never records an approval it did not receive.
7. **Skipping is allowed.** Record it. Do not block the pipeline or ask again in the same session.
8. **Fewer, shorter documents.** Do not add a document, a section or a paragraph that another document already carries. Link by ID.
9. **One human decision at each gate.** Do not chain gates.
10. **Seam and grep rules still apply.** Nothing in this file permits Tissue writes in the instruction.

### Opening line

> I have the BRD and the WalkThrough. Before you accept the WalkThrough I would like to ask you to predict three scenarios, with the expected results hidden. You can skip any of them. A mismatch tells us first about the document, not about you. I will also keep a short decision log and keep the generated documents short.

---

## 2. Comprehension check (gate C1)

### 2.1 When

After the WalkThrough draft is shown and **before** the user accepts it. Offer the check once. If the user declines, record `declined` and go on.

### 2.2 Choose three scenarios

Pick from the WalkThrough coverage matrix:

| # | Scenario type | Choose |
| - | ------------- | ------ |
| 1 | An ordinary path | The most common journey |
| 2 | A boundary | A case at a parameter's limit, when the value is set |
| 3 | An interaction | Two rules that can fire together, or an invariant under strain |

If no parameter value is set, use a second interaction instead of a boundary. Mark the selection `[AI SUGGESTED]` and let the user swap any scenario.

### 2.3 Ask before showing

Ask all three in one message, in plain words, with the inputs only:

> "Before you read the expected results, what do you expect to happen in each of these? Skip any you like."

Do **not** show the expected result, the Demo's output or the WalkThrough's answer for these scenarios until the user replies.

### 2.4 Work out the expected result from the BRD

For each scenario, derive the expected result from the BRD and parameter register. If the BRD cannot decide it (a missing parameter, no precedence, an undefined term), the result is **Undetermined**. Report it as a finding, name the BRD gap, and do not ask the user to guess.

### 2.5 Compare and record

| Outcome | Meaning |
| ------- | ------- |
| **Match** | The prediction equals the BRD-derived result |
| **Mismatch** | They differ |
| **Skipped** | The user chose not to answer |
| **Undetermined** | The BRD cannot decide it; recorded as a finding |

### 2.6 On a mismatch

Show the BRD ID and the sentence it rests on. Then ask one question:

> "Is the BRD unclear, is the WalkThrough unclear, or did you expect something different on purpose?"

| Answer | Action |
| ------ | ------ |
| BRD unclear | Add a finding. Ask the owner |
| WalkThrough unclear | Revise the WalkThrough and show the change |
| Expected differently on purpose | The user may amend the BRD. Record it as a decision (§4) |

A mismatch never stops the pipeline.

### 2.7 Report counts, not scores

Report: asked, matched, mismatched, skipped, undetermined. Do not add them into a single figure.

---

## 3. Change control on protected items (gate C2)

Active once `<stem>-test.dart` or ledger evidence exists.

### 3.1 The default when a check fails

**Assume the code is wrong, not the check.** Fix the code first. A check may change only when the BRD shows its expected value was wrong, and the user confirms.

### 3.2 What needs a decision

Any of these, after the first run, requires a user decision:

- an expected value or acceptance criterion is changed;
- a tolerance is widened, or an exact comparison becomes a range;
- a check is deleted, skipped, commented out or marked pending;
- a parameter value used by a check is changed;
- the test file is regenerated from scratch.

### 3.3 What to show

For each proposed change, show one line per item:

| Field | Content |
| ----- | ------- |
| Requirement ID | e.g. `FR-03` |
| Old → new | The value or rule before and after |
| Reason | The BRD sentence, or `code change` |
| Cause | `BRD changed`, `BRD was wrong`, or `code changed` |
| Ledger effect | The row returns to Unverified until re-run |

### 3.4 Bulk changes

`[AI SUGGESTED]` threshold: more than **5** protected items changed in one revision. Stop. Report them as a single event, give counts by cause, and ask for explicit confirmation of the whole set. Do not proceed on partial approval.

### 3.5 Regeneration

If `<stem>-test.dart` is regenerated, diff it against the previous version and show every protected item that differs.

### 3.6 Record

Every approved change goes in the Change log (§6) with date, approver's name, cause, and `CHG-nnn` if a change file exists (`none` on a first build). A declined change is recorded as declined.

---

## 4. Decision log

### 4.1 What counts as a decision

Record an entry when:

- more than one layer could answer a requirement and one was chosen;
- a BRD finding was resolved (for example a precedence rule was set);
- a residual item was accepted;
- a WalkThrough Recommendations row was adopted or declined;
- the work departs from a layer guide;
- a protected item change was approved (§3).

### 4.2 Entry format

| Field | Rule |
| ----- | ---- |
| ID | `D-01`, `D-02`, … in order |
| Date | The date of the decision |
| Context | BRD requirement IDs, finding IDs, and `CHG-nnn` when the decision belongs to a change. `none` on a first build. |
| Decision | One sentence |
| Alternatives considered | **Only** those the user or the layer guides actually raised, each with the reason it was not chosen. If none were raised, write `none raised` |
| Decided by | A named person. `[To be confirmed from BRD]` if not stated |
| Revisit if | A condition that would reopen it, if the user gave one |

### 4.3 What not to do

- Do not backfill reasons after the fact.
- Do not invent alternatives to make an entry look complete.
- Do not record an agent proposal as a decision until the user accepts it.

### 4.4 Use downstream

ARCHITECTURE and FEATURES must cite decision IDs where a design choice appears. They must not restate the reasoning; they link to the log.

---

## 5. Length (no caps)

Generated documents open with a short summary headed *What a reader must understand* when useful for orientation. There are no word limits and no length caps. State a fact once and link by ID. Prefer tables of IDs to prose retellings. Do not restate the same behavior across documents.

---

## 6. Write `<stem>-COMPREHENSION.md`

Blocks, in this order:

| Block | Must include |
| ----- | ------------ |
| Name plate | BRD / WalkThrough / ledger versions (MAJOR.MINOR.PATCH), date, `Version: M.m.p`, `Supersedes: <prior or none>` |
| Comprehension checks | One table per session: scenario, question, prediction, BRD-derived result, outcome, follow-up |
| Counts | Asked, matched, mismatched, skipped, undetermined |
| Change log | Date, requirement ID, old → new, cause, decided by, status (approved or declined) |
| Decision log | Entries from §4 |

Keep prose focused. The tables carry the record.

### 6.1 Example rows (format only, not results)

| Scenario | Prediction | BRD-derived result | Outcome |
| -------- | ---------- | ------------------ | ------- |
| Card-not-present request, MCC on the blocked list | Declined | Declined (FR-02) | Match |
| Request matching two rules | "Step up" | Undetermined: no precedence rule (finding F-02) | Undetermined |

| Date | ID | Old → new | Cause | Decided by | Status |
| ---- | -- | --------- | ----- | ---------- | ------ |
| (date) | FR-11 | Expect one retry → expect two | BRD was wrong | (name) | Approved |

---

## 7. Gates

One human decision at each gate. Do not chain them.

| Gate | Question |
| ---- | -------- |
| C1 | "Before you accept the WalkThrough, would you like to predict three scenarios?" |
| C2 | "These protected items would change. Approve, decline, or revise?" |
| C3 | "Is this decision log right?" (before ARCHITECTURE is written) |

---

## 8. Edits to other files

Small additions to keep the rules connected:

- **`LEDGER-AI-Generator.md`.** In §1, add: *Protected items change only under gate C2 of `COMPREHENSION-AI-Generator.md`.* In §6, add to the summary block: *comprehension checks (asked, matched, skipped), protected changes (approved, pending).*
- **`HowTo-Mitose.md`.** Add gate C1 before WalkThrough acceptance, and these checklist lines:

```
[ ] Comprehension check offered (taken, skipped or declined)
[ ] No protected item changed without a recorded decision
[ ] Decision log shown before ARCHITECTURE was written
```

- **ARCHITECTURE and FEATURES generators.** Read the decision log and cite decision IDs. Open with a short summary headed *What a reader must understand* when useful.

---

## 9. What this file is not

- Not a measure of anyone's skill, and not a score.
- Not proof that a person understands the system.
- Not a replacement for reading the code that ships.
- Not permission to invent reasons, alternatives or approvals.
- Not a fix for the limits of specs and tests. It narrows them; it does not remove them.

---

## 10. After writing

> Done. `<stem>-COMPREHENSION.md` is written.
>
> Comprehension checks: asked *a*, matched *m*, mismatched *x*, skipped *s*, undetermined *u*
> Protected changes: approved *p*, declined *d*
> Decisions logged: *n*

---

## 11. Checklist

- [ ] BRD and WalkThrough were read; no file was overwritten without asking
- [ ] The comprehension check was offered once; its outcome is recorded (taken, skipped, declined)
- [ ] Scenarios came from the coverage matrix: one ordinary, one boundary or second interaction, one interaction
- [ ] Expected results came from the BRD and parameters, and were shown only after the prediction
- [ ] A case the BRD cannot decide is recorded as a finding (Undetermined), not as a mismatch
- [ ] No score and no grading language
- [ ] Every protected change has a decision and a named approver; bulk changes were one event
- [ ] A failing check was fixed in the code first
- [ ] Decision-log alternatives are only those actually raised; no invented reasons
- [ ] Every generated document opens with a short summary headed *What a reader must understand* when useful; no word limit or length gate was applied

---

## 12. Acceptance criteria for *this generator*

The pass is accepted only when all of the following hold. Show Pass / Fail to the user.

| ID | Criterion | Method |
|---|---|---|
| G-AC-01 | `<stem>-COMPREHENSION.md` exists; no overwrite without asking | file inspect |
| G-AC-02 | The check was offered before WalkThrough acceptance, once | chat log |
| G-AC-03 | The three scenarios match the types in §2.2 | inspect |
| G-AC-04 | Expected results were derived from the BRD, not the Demo, and withheld until after the prediction | chat log |
| G-AC-05 | Undetermined cases are findings, not mismatches | inspect |
| G-AC-06 | No comprehension score or grading language appears | inspect |
| G-AC-07 | Each protected change has cause, decision, and named approver | change log |
| G-AC-08 | More than 5 changes in one revision were treated as one event | change log |
| G-AC-09 | Decision-log entries list only alternatives actually raised, with a named decider | decision log |
| G-AC-10 | Each document opens with a short summary headed *What a reader must understand* when useful; no word limit or length gate was applied | inspect |
| G-AC-11 | Gates C1 to C3 were asked one at a time | chat log |

Fail any row → do not claim the pass is done.

---

*End of COMPREHENSION-AI-Generator.md.*
