# CHANGE-AI-Generator.md



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

**File role:** An AI-executable **generator** script. An AI prompt agent reads this file and produces `<stem>-CHANGE-<nnn>.md` for one change to a solution that was built with the Mitose pipeline. It also updates the BRD change history, the ledger and the decision log.

**Mitosis** is the framework. **Mitose** is what you do with it. *Mitose* is the German word for cell division (*die Mitose*), and this project borrows it as a verb: you have a business requirement, so you **Mitose it**. The spelling is deliberate. Please do not “correct” it to Mitosis; filenames such as `HowTo-Mitose.md` keep it on purpose. *Mitosis is the noun. Mitose is the verb.*

**Status:** Draft proposal. Not yet part of the published `guide/` set. Written to sit beside `LEDGER-AI-Generator.md` and `COMPREHENSION-AI-Generator.md`.

**Why this file exists.** The pipeline describes a first build. Real systems then change: a requirement moves, a framework version bumps, someone edits the Dart by hand, a check fails. Without a defined path, documents drift from the code, the ledger goes stale, and the original intent is lost. This file keeps intent, evidence and code in step during maintenance.

This file is **process and format only**. It does not teach `Cell.*` factories, Flow operators or Tissue collections. It does not decide which layer answers a requirement.

**Entry.** Change mode may be entered in two ways: the user says “Mitose change”, or the user chooses “As a Change” from the enhancement offer in `HowTo-Mitose.md` §6 after Demo Assessment. In both cases the gates below apply.

| Term | Meaning |
| ---- | ------- |
| **Change** | One bounded alteration, identified as `CHG-001`, `CHG-002`, … |
| **Change type** | `requirement`, `upgrade`, `drift`, or `defect` (see §2) |
| **Impact list** | Every BRD item, scenario, check, ledger row, decision and document that a change touches |
| **Drift** | A difference between the code and the BRD or WalkThrough that nobody decided on |
| **Retired** | A requirement that was removed on purpose. It stays in the ledger and is not deleted |

Worked example of the formats this file builds on: `Card-Auth-Residual-Ledger.md` and `Card-Auth-BRD-Precision-Revision.md`.

WalkThrough cites: pulse path is §5.5. Demo Assessment is §5.12. Do not cite those blocks as §8 or §15.

---

## 0. Inputs and hard stops

| Input | Required? | If missing |
| ----- | --------- | ---------- |
| Current `<stem>-BRD.md` | **Yes** | Stop. Send the user to the BRD gate |
| `<stem>-LEDGER.md` | **Yes** | Stop. Offer to build the baseline ledger first (`LEDGER-AI-Generator.md`). Changes without a baseline cannot be measured |
| `<stem>-WalkThrough.md` and `<stem>-Demo.dart` | **Yes** | Stop. Nothing to compare with |
| `<stem>-test.dart` | **Yes** | Stop. The Demo must have its unit test and ledger report. No row can be Verified without it. Do not write a Check file instead |
| `<stem>-COMPREHENSION.md` | No | Create the decision log inside the change file and say so |
| `ARCHITECTURE` / `FEATURES` documents | No | Skip the document step |

Never overwrite an existing change file. Number the next one.

---

## 1. Rules of engagement

1. **State the change first.** Show the change as a diff of the BRD before touching anything else. No code, check or document changes until the user confirms it (gate CH1).
2. **Trace by ID, never by guess.** Impact comes from requirement IDs, check names, coverage-matrix entries and decision IDs. If a link cannot be traced, mark it `Unknown`. **Treat Unknown as affected** until shown otherwise.
3. **Requirement IDs are permanent.** Never reuse or renumber an ID. A removed requirement becomes **Retired**. It stays in the BRD, the ledger and the history.
4. **Amend, do not regenerate.** Edit the smallest set of items that the change requires. Regenerate a document or file from scratch only with a full diff shown to the user and their decision.
5. **A failing check is not the change.** When a check fails, fix the code first. A check or expected value may change only for a reason recorded in the BRD, under gate C2 of `COMPREHENSION-AI-Generator.md`.
6. **No silent alignment.** Never edit the BRD to match the code, and never edit the code to match the BRD, without showing the difference and getting a decision.
7. **Evidence resets with the change.** A row is Verified after a change only if its check passed in this change's run.
8. **Do not invent migrations, versions or history.** Anything the user did not state stays `[To be confirmed from BRD]`.
9. **Approvals belong to named people.** The agent never records an approval it did not receive, and never accepts residual risk for the user.
10. **Update only the changed sections.**
11. **One human decision at each gate.** Do not chain gates.
12. **Seam and grep rules still apply.** Nothing here permits Tissue writes in the instruction.

### Opening line

> I have the BRD, the WalkThrough, the Demo and the ledger. I will handle one change at a time. First I will show the change as a diff of the BRD and wait for your confirmation. Then I will trace what it affects by requirement ID, treating anything I cannot trace as affected. I will not edit the BRD to match the code, or the code to match the BRD, without your decision, and I will not accept residual risk for you.

---

## 2. Choose the change type

Ask which applies. A change may combine types; record each.

| Type | Trigger | Starts with |
| ---- | ------- | ----------- |
| `requirement` | A rule, parameter, scope item or target is added, changed or removed | The BRD diff (§3) |
| `upgrade` | The Mitosis packages or Dart SDK version changes | The version range (§7) |
| `drift` | The Dart was edited by hand, or a document and the code disagree | The drift check (§6) |
| `defect` | A ledger row is Failed, or a bug is reported | A reproducing check (§8) |

---

## 3. State the change (gate CH1)

Show the user, before any edit:

### 3.1 BRD diff

| Field | Content |
| ----- | ------- |
| Change ID | `CHG-nnn` |
| Requested by | A named person, as stated by the user |
| Reason | The user's words |
| Added | New requirement IDs with the full text and, if the BRD template requires, priority, criterion and class |
| Changed | Old text → new text, per ID |
| Retired | IDs and the reason |
| Parameters | Old → new value, owner |

Draft any criterion the agent writes as `[AI SUGGESTED]`. A parameter value the user does not give stays `[To be confirmed from BRD]`.

### 3.2 BRD version

Bump the BRD version and add a row to a **Change history** table in the BRD:

| Version | Date | Change ID | Summary | Approved by |
| ------- | ---- | --------- | ------- | ----------- |

Ask whether the diff is right. Do not continue until the user answers.

---

## 4. Impact analysis (gate CH2)

### 4.1 Trace

From each changed, added or retired ID, follow every link:

| Layer of trace | Look in | Typical link |
| -------------- | ------- | ------------ |
| BRD | Journeys, acceptance criteria, parameters, findings, success measures | The ID appears in the text |
| WalkThrough | Coverage matrix | Scenario → BRD ID → expected print |
| Checks and code | Check names, comments, spec `covers` entries | The ID begins the check name |
| Ledger | Rows | The ID |
| Decisions | Decision log | The ID in context |
| Documents | ARCHITECTURE, FEATURES | Decision IDs cited |

### 4.2 Impact list

| Item | Kind | Why it is affected | Action |
| ---- | ---- | ------------------ | ------ |
| (ID or file) | requirement / scenario / check / row / decision / document / parameter | The link that reached it | `amend`, `re-run`, `retire`, `none (reason)`, or `unknown` |

An item with action `none` needs a reason. `Unknown` items are treated as `amend` or `re-run` until the user says otherwise.

### 4.3 New findings

Run the BRD checks from §2.3 of `LEDGER-AI-Generator.md` again on the changed BRD. A change can introduce a contradiction, a missing precedence or an undefined value. List each new finding and mark it Blocking or Clarify. Rows touched by a Blocking finding become **Blocked**.

### 4.4 Plan

For each impact item, propose the smallest edit. Ask the user to confirm the impact list and the plan together.

---

## 5. Apply the change

### 5.1 Order

1. Update the BRD (the confirmed diff only).
2. Update the WalkThrough scenarios and coverage matrix for affected IDs.
3. Update checks from the BRD criteria. Expected values come from the BRD, not the Demo.
4. Update the Dart and Demo minimally.
5. Run `dart analyze` and `dart test <stem>-test.dart`.
6. Update the ledger (§9).
7. Update only the affected sections of ARCHITECTURE and FEATURES, citing decision IDs.

### 5.2 Protected items

Changes to expected values, tolerances, checks, parameter values used by checks or skip markers are covered by gate C2 in `COMPREHENSION-AI-Generator.md` §3. Record the cause as `BRD changed`. The bulk-change threshold applies to the whole change, not to each step.

### 5.3 Amend or regenerate

Default is amend. If the user asks for regeneration, show a full diff of every protected item and every behavior that differs, and ask before replacing anything. Never regenerate to make a check pass.

### 5.4 Comprehension check

For a change to any Must requirement, offer the check in `COMPREHENSION-AI-Generator.md` §2 on one or two scenarios the change affects. The user may skip.

---

## 6. Drift check (gate CH3)

Use for `drift` changes, and after any hand edit to the Dart.

### 6.1 Compare

Compare the code with the BRD and WalkThrough. List each difference:

| Kind | Meaning |
| ---- | ------- |
| **Extra** | Behavior in the code that no requirement covers |
| **Missing** | A requirement with no corresponding behavior |
| **Different** | Behavior that contradicts the stated requirement |

Trace by check names, coverage-matrix entries and ID comments. Do not guess intent from code style.

### 6.2 Disposition

For each difference, ask the user to choose one:

| Choice | Result |
| ------ | ------ |
| **Adopt** | The BRD changes to match the code. Handle as a `requirement` change |
| **Revert** | The code changes to match the BRD |
| **Accept** | The difference stays as residual, accepted by a named person with a review date |

Never pick a disposition for the user. Never rewrite either side without one.

---

## 7. Upgrade (framework or SDK)

### 7.1 Record the baseline

Add to the ledger name plate: the Dart SDK version and each Mitosis package version in use before and after the change.

### 7.2 Read the range

Read the CHANGELOG for every release between the two versions. List each change that touches a symbol the solution uses: renamed, removed, behavior changed, or new rule. Resolve live signatures from pub.dev. Never invent an API from memory.

### 7.3 One step at a time

`[AI SUGGESTED]` Upgrade one release step per change while the packages are pre-1.0. Combine steps only if the user decides to.

### 7.4 Persisted data

If the solution stores data (for example through `cell_memory` or generated references), list every stored shape the upgrade touches. Do not invent a migration. If none is documented, record `[To be confirmed from BRD]`, mark the affected rows Blocked, and ask the user.

### 7.5 Verify

Run `dart analyze` and `dart test <stem>-test.dart`. Every Verified row from before the upgrade must pass again in this run, or it returns to Unverified.

---

## 8. Defect

1. Identify the BRD requirement the defect violates, by ID.
2. If **no requirement covers it**, it is a missing requirement, not a code fix. Handle it as a `requirement` change.
3. Otherwise, **write or adjust a check from the BRD criterion that fails for this defect** and run it. A defect without a reproducing check is not yet understood.
4. Fix the code. Run `dart test <stem>-test.dart`.
5. Record the check name, the run, and the ID in the change file.

---

## 9. Update the ledger

| Case | Result |
| ---- | ------ |
| Row affected by the change | **Unverified**, noted `CHG-nnn`, until re-run |
| Row unaffected, and its check passed in this run | **Verified**, with the new run date |
| Row unaffected, but not re-run | **Unverified** |
| New requirement | **Unverified**, or **Blocked** if a finding applies |
| Retired requirement | Moves to a **Retired** block with the change ID and reason. Not deleted |
| Accepted row whose context changed | Ask the user to accept again (gate CH4) |

Add to the ledger name plate: `Last change: CHG-nnn`, the ledger version, the build or commit, the date and the package versions.

Regenerate the summary block. Show before and after counts side by side.

---

## 10. Residual re-acceptance (gate CH4)

For each row that is not Verified after the change, and for each Accepted row the change touched, ask whether the user accepts it.

| Column | Rule |
| ------ | ---- |
| Accepted by | A named person the user supplies. Never the agent |
| Date | The date the user gives |
| Review by | A date the user gives. Class J rows require one |
| Reason | The user's words |

An old acceptance does not carry over when the requirement it covered changed.

---

## 11. Decision log

Add an entry for each design decision the change required, using the format in `COMPREHENSION-AI-Generator.md` §4, and cite the change ID in its context. Record only alternatives that were actually raised. A disposition chosen in §6 and an acceptance in §10 are decisions.

---

## 12. Write `<stem>-CHANGE-<nnn>.md`

Blocks, in this order:

| Block | Must include |
| ----- | ------------ |
| Name plate | Change ID, type(s), date, requested by, BRD version before and after, package and SDK versions before and after |
| Request | The confirmed BRD diff (§3.1) |
| Impact list | §4.2, with the action taken for each item |
| New findings | §4.3 |
| Drift | §6 differences and dispositions, if any |
| Upgrade notes | §7 list and data notes, if any |
| Ledger diff | Before and after summary; rows reset, re-verified, new, retired |
| Protected changes | Items changed under gate C2, with cause and approver |
| Decisions added | Decision IDs |
| Residual acceptance | §10 |
| Run log | Date, command, who produced the output |
| Release check | §14 |

### 12.1 Example rows (format only, not results)

| Item | Kind | Why it is affected | Action |
| ---- | ---- | ------------------ | ------ |
| P-03 | parameter | Value set for the first time | amend |
| FR-04 | requirement | Uses P-03 | re-run |
| `FR-04 step up at threshold` | check | Boundary values come from P-03 | amend |
| ARCHITECTURE §3 | document | Cites decision D-04 | none (decision unchanged) |

---

## 13. Summary block (regenerate each change)

| Measure | Definition |
| ------- | ---------- |
| Impact items | Count by kind and by action |
| Unknown items | Count (should reach zero before close) |
| Rows reset to Unverified | Count |
| Rows re-Verified | Count |
| New / Retired rows | Counts |
| New findings | Counts by Blocking and Clarify |
| Drift items | Counts by disposition (adopt, revert, accept) |
| Protected items changed | Count, with number approved |
| Release gap before / after | Must rows not Verified or Accepted |
| Residual acceptances renewed | Count |

Never collapse this into one score.

---

## 14. Release check (gate CH5)

A change may be released only when:

1. Every Must row is **Verified** or **Accepted** by a named person.
2. No row is **Blocked** because of this change.
3. No impact item is `Unknown`.
4. Every drift difference has a disposition.
5. Every protected-item change has a recorded approval.
6. The BRD change history, ledger name plate and decision log are updated.
7. Changed documents are within their , or accepted at length.

If any condition fails, report it and ask. Do not release for the user.

---

## 15. Gates

One human decision at each gate. Do not chain them.

| Gate | Question |
| ---- | -------- |
| CH1 | "Is this BRD diff right?" |
| CH2 | "Are this impact list and plan right?" |
| CH3 | "For each difference between code and BRD: adopt, revert, or accept?" |
| CH4 | "Which of these residual items do you accept, and who is accepting them?" |
| CH5 | "These release conditions are met or not met. Do you release this change?" |

---

## 16. Edits to other files

Applied in this set. Do not apply them again.

- **`HowTo-Mitose.md`.** Change mode is §9. The checklist includes the five change lines.
- **`LEDGER-AI-Generator.md`.** Result value **Retired** (kept, not deleted). Name plate includes `Last change: CHG-nnn` or `none`, the Dart SDK version, and the Mitosis package versions.
- **`COMPREHENSION-AI-Generator.md`.** Decision-log and protected-change entries cite `CHG-nnn`, or `none` on a first build.
- **ARCHITECTURE and FEATURES generators.** Amend mode changes only the sections a change touches and notes the BRD version they now describe.
- **BRD template.** Change history table is present.
- **WalkThrough cites.** Pulse path is §5.5. Demo Assessment is §5.12. Open questions are §5.11.

---

## 17. What this file is not

- Not version control. Keep the code and documents in a repository as usual.
- Not a data migration tool. It records what must be migrated and who decides.
- Not a guarantee about edits made outside the pipeline. Drift is found only when someone runs the drift check.
- Not support for several framework versions at once.
- Not permission to invent versions, migrations, reasons, alternatives or approvals.

---

## 18. After writing

> Done. `<stem>-CHANGE-<nnn>.md` is written.
>
> Type(s): …  ·  BRD version: *from* → *to*
> Impact items: *n* (Unknown: *u*)
> Ledger: *r* rows reset · *v* re-Verified · *w* new · *x* retired
> Drift items: *d* (adopt / revert / accept)
> Release check: met / not met (list)

---

## 19. Checklist

- [ ] BRD, WalkThrough, Demo and ledger were read
- [ ] The change was shown as a BRD diff and confirmed before any edit (gate CH1)
- [ ] BRD version bumped and Change history updated; no ID reused or renumbered
- [ ] Impact traced by ID; Unknown items treated as affected; none left at close (gate CH2)
- [ ] The BRD checks were re-run for new findings
- [ ] Amended, not regenerated (or a full diff was shown and the user decided)
- [ ] Protected-item changes went through gate C2 with a cause
- [ ] Every drift difference has a user disposition (gate CH3)
- [ ] Upgrade: versions recorded; CHANGELOG range read; no invented migration
- [ ] Defect: a check reproduced it before the fix; a missing requirement was handled as a requirement change
- [ ] Affected ledger rows reset; Verified only after a passing run; retired rows kept
- [ ] Acceptances renewed by a named person with a review date (gate CH4)
- [ ] Release check reported; the agent did not release for the user (gate CH5)
- [ ] Changed documents within , or accepted at length

---

## 20. Acceptance criteria for *this generator*

The change pass is accepted only when all of the following hold. Show Pass / Fail to the user.

| ID | Criterion | Method |
|---|---|---|
| G-AC-01 | `<stem>-CHANGE-<nnn>.md` exists, is numbered, and no earlier change file was overwritten | file inspect |
| G-AC-02 | The BRD diff was confirmed before any edit | chat log |
| G-AC-03 | The BRD version and Change history were updated; no requirement ID was reused or renumbered | compare BRD |
| G-AC-04 | Impact was traced by ID; every item has an action; no Unknown remains | inspect impact list |
| G-AC-05 | New findings from the BRD checks are listed | inspect |
| G-AC-06 | No regeneration without a full diff and a user decision | chat log |
| G-AC-07 | Every protected-item change has a cause, a decision, and a named approver | change log |
| G-AC-08 | Every drift difference has a user-chosen disposition | inspect drift block |
| G-AC-09 | For an upgrade, versions before and after, the CHANGELOG range read, and the persisted-data note are recorded | inspect |
| G-AC-10 | For a defect, a reproducing test from a BRD criterion exists in `<stem>-test.dart` before the fix | inspect test file |
| G-AC-11 | Affected rows were reset; every Verified row has a passing run in this change | inspect ledger |
| G-AC-12 | The release check lists each condition as met or not met | inspect |

Fail any row → do not claim the change is done.

---

*End of CHANGE-AI-Generator.md.*
