# Business Requirements Document (BRD) — Standard Template



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

**Template version:** 2.0 (supersedes 1.0)

**Purpose:** This template helps you write a "Day 1" business requirements document. Fill in each section in plain English. Do not describe how the system will be built — only what the business needs the system to do. Leave a section blank if it does not apply, or write "N/A" with a one-line reason.

**What is new in 2.0:** Every requirement now carries a way to check it. That means a priority, an acceptance criterion with a stated tolerance, and a verification class. Every number the requirements rely on is listed once in a parameter register. If several rules can apply to the same case, the BRD says which wins. Before approval, the BRD is checked for contradictions and gaps. A requirement that cannot be checked is not rejected; it is marked as a matter of judgment so that it stays visible.

**How to use it:** Copy this file, rename it `\<your-project\>-BRD.md`, and fill in the blanks. Replace every `[...]` with your answer. Delete the italic guidance under each heading once you have written your answer.

**Pipeline:** `HowTo-Mitose.md` 2.0 gate B1 reads this shape. `LEDGER-AI-Generator.md` extracts the requirement register, the parameter register, and the findings from it. Requirement IDs are permanent: never reuse or renumber one. A removed requirement is marked **Retired**, not deleted.

---

## 1. Document control

| Field | Value |
|---|---|
| Project name | `[short name]` |
| Document title | `[full title]` |
| Version | `[0.1 draft / 1.0 approved]` |
| Date | `[YYYY-MM-DD]` |
| Author | `[name, role]` |
| Reviewer(s) | `[name, role]` |
| Approver(s) | `[name, role]` |
| Status | `[draft / in review / approved / superseded]` |

**Revision history**

*Every change after the first draft gets a row. If the change came through a change request, give its ID. Requirement IDs are never reused or renumbered; a removed requirement is marked **Retired**, not deleted.*

| Version | Date | Change ID | Author | Change summary |
|---|---|---|---|---|
| 0.1 | `[date]` | — | `[name]` | First draft |

---

## 2. Executive summary

*Three to five sentences. What problem are we solving, for whom, and why now? A busy executive should be able to read only this section and understand the point of the project.*

`[Write 3–5 sentences.]`

---

## 3. Business context

### 3.1 Background
*What is the current situation? What is happening today that makes this project necessary?*

`[Write a paragraph.]`

### 3.2 Problem statement
*What is broken, missing, slow, risky, or expensive today? Be specific. Avoid vague words like "inefficient" without an example.*

`[Write a paragraph.]`

### 3.3 Business drivers
*Why now? Regulatory change, cost pressure, customer demand, competitive threat, incident, audit finding, etc.*

- `[Driver 1]`
- `[Driver 2]`

### 3.4 Alignment with strategy
*How does this project support the organisation's stated goals or roadmap?*

`[One or two sentences.]`

---

## 4. Scope

### 4.1 In scope
*What the project will deliver. Be explicit about processes, users, data, and interfaces.*

- `[In-scope item 1]`
- `[In-scope item 2]`

### 4.2 Out of scope
*What the project will **not** deliver, especially things a reader might assume are included. Each line prevents a future argument.*

- `[Out-of-scope item 1]`
- `[Out-of-scope item 2]`

### 4.3 Assumptions
*Things we believe to be true but have not yet confirmed. If any assumption is false, the plan may change.*

- `[Assumption 1]`
- `[Assumption 2]`

### 4.4 Constraints
*Fixed limits we must work within — budget, deadline, regulation, existing systems, headcount, geography.*

- `[Constraint 1]`
- `[Constraint 2]`

### 4.5 Dependencies
*Things outside the project that must be in place for it to succeed — another team's deliverable, a vendor contract, a data feed, a policy decision.*

- `[Dependency 1]`
- `[Dependency 2]`

---

## 5. Stakeholders

| Role | Name / Group | Interest | Influence (H/M/L) | Engagement approach |
|---|---|---|---|---|
| Sponsor | `[name]` | `[what they care about]` | H | `[weekly update]` |
| Primary user | `[name]` | `[what they care about]` | H | `[workshops]` |
| Reviewer | `[name]` | `[what they care about]` | M | `[review sessions]` |
| Auditor / regulator | `[name]` | `[what they care about]` | M | `[sign-off]` |

---

## 6. Users and personas

*Who will actually use the system day to day? Describe each user type as a short persona. One paragraph each.*

### 6.1 `[Persona name]`
- **Role:** `[job title]`
- **Context:** `[where and when they work]`
- **Goal:** `[what they are trying to achieve]`
- **Pain today:** `[what is hard or broken]`
- **Success looks like:** `[the outcome they want]`

### 6.2 `[Persona name]`
`[Same shape.]`

---

## 7. Business requirements

*This is the heart of the document. Each requirement is a single, testable statement of **what** the business needs, not **how** it will be done.*

**Rules for writing requirements**
- One requirement per line.
- Start with "The system shall…" or "The \<role\> shall be able to…".
- No design words ("database", "API", "screen", "microservice", "queue").
- No solution words ("we will use X").
- Every requirement has an acceptance criterion written as **Given / When / Then**, with the number or tolerance that makes it checkable (see section 10.1 for the class).
- If a number is needed but not yet known, write `TBD` in the parameter register (7.5) and name its owner. Never guess a number.
- If a requirement truly cannot be tested, give it class **J** (judgment) and name who will accept it. Do not delete it.
- Requirement IDs are permanent. Never reuse or renumber an ID. A removed requirement stays in the table as **Retired**.

### 7.1 Functional requirements

| ID | Requirement | Priority (Must / Should / Could) | Acceptance criterion (Given / When / Then, with tolerance) | Class | Rationale |
|---|---|---|---|---|---|
| FR-01 | The system shall `[action]`. | Must | **Given** `[situation]`, **when** `[event]`, **then** `[observable result within tolerance]`. | `[T/P/M/I/H/J]` | `[why]` |
| FR-02 | The `[role]` shall be able to `[action]`. | Must | `[Given / When / Then]` | `[class]` | `[why]` |
| FR-03 | The system shall `[action]` when `[condition]`. | Should | `[Given / When / Then]` | `[class]` | `[why]` |

### 7.2 Data requirements

| ID | Requirement | Priority | Acceptance criterion | Class | Rationale |
|---|---|---|---|---|---|
| DR-01 | The system shall capture `[data item]` with `[attributes]`. | Must | `[Given / When / Then]` | `[class]` | `[why]` |
| DR-02 | The system shall retain `[data]` for `[period]`. | Must | `[Given / When / Then]` | `[class]` | `[regulatory or business reason]` |
| DR-03 | The system shall prevent `[bad data]` from being recorded. | Must | `[Given / When / Then, including the boundary value]` | `[class]` | `[why]` |

### 7.3 Rules and policy

*Business rules that are not negotiable — legal, regulatory, contractual, safety, or long-standing company policy. A rule must not contradict a functional requirement. If it appears to, resolve it here (see 7.6 and 14.1) before approval.*

| ID | Rule | Source | Priority | Acceptance criterion | Class |
|---|---|---|---|---|---|
| BR-01 | `[Rule statement]` | `[law / policy / contract]` | Must | `[Given / When / Then]` | `[class]` |
| BR-02 | `[Rule statement]` | `[law / policy / contract]` | Must | `[Given / When / Then]` | `[class]` |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention | Priority | Acceptance criterion | Class |
|---|---|---|---|---|---|---|---|
| AR-01 | `[Report name]` shall show `[content]`. | `[role]` | `[daily / on demand]` | `[period]` | `[priority]` | `[Given / When / Then]` | `[class]` |

### 7.5 Parameter register

*Every threshold, window, limit, and list that a requirement refers to appears here once. A requirement says "at or above the step-up threshold"; this table says what that number is. A missing value is `TBD`, with an owner and a date. Do not invent a value to fill a row.*

| ID | Parameter | Used by (requirement IDs) | Value | Unit | Owner | Status (set / TBD) | Open question |
|---|---|---|---|---|---|---|---|
| P-01 | `[e.g. velocity threshold]` | `[FR-xx]` | `[value or TBD]` | `[unit]` | `[name]` | `[set / TBD]` | `[Q-xx]` |
| P-02 | `[e.g. blocked list contents]` | `[FR-xx]` | `[value or TBD]` | `[unit]` | `[name]` | `[set / TBD]` | `[Q-xx]` |

### 7.6 Decision precedence

*Skip this section only if no input can match more than one rule. Otherwise say which rule wins when several apply to the same case, and whether every matching reason is recorded.*

| Order | Rule (requirement ID) | Wins over | All matching reasons recorded? |
|---|---|---|---|
| 1 | `[ID]` | `[IDs]` | `[yes / no]` |
| 2 | `[ID]` | `[IDs]` | `[yes / no]` |

---

## 8. Non-functional requirements

*How well the system must behave. Keep them measurable. For every target, say how it is measured: the percentile, the time window, the sample size, and the start and end points. Every row has a priority.*

| ID | Category | Requirement | Target | Priority | How measured (percentile / window / sample / start and end) | Class |
|---|---|---|---|---|---|---|
| NFR-01 | Performance | The system shall respond within `[X ms / s]` for `[action]`. | `[number]` | `[priority]` | `[e.g. 99th percentile, from receipt to decision recorded, at peak load]` | `[M]` |
| NFR-02 | Availability | The system shall be available `[X%]` during `[window]`. | `[number]` | `[priority]` | `[window and period over which it is measured]` | `[M]` |
| NFR-03 | Capacity | The system shall support `[N]` concurrent `[users / records / events]`. | `[number]` | `[priority]` | `[peak rate and how long it is held]` | `[M]` |
| NFR-04 | Security | Access to `[data]` shall require `[authorisation rule]`. | `[rule]` | `[priority]` | `[role allowed, role refused]` | `[T]` |
| NFR-05 | Auditability | Every `[action]` shall be traceable to `[who / when / why]`. | `[rule]` | `[priority]` | `[fields recorded]` | `[T]` |
| NFR-06 | Usability | A `[role]` shall complete `[task]` in `[N]` steps or fewer. | `[number]` | `[priority]` | `[number of participants, task, time limit]` | `[H]` |
| NFR-07 | Compliance | The system shall comply with `[regulation / standard]`. | `[name]` | `[priority]` | `[who signs off]` | `[J]` |
| NFR-08 | Recoverability | The system shall recover from failure within `[X]`. | `[number]` | `[priority]` | `[how a failure is simulated; what must not be lost]` | `[M]` |

---

## 9. User journeys

*For each main scenario, describe the flow in plain English: who does what, in what order, and what "done" looks like. Name the requirement IDs each journey exercises, and check that no step conflicts with a requirement or names a different actor from it.*

### 9.1 Journey: `[name]`
- **Trigger:** `[what starts it]`
- **Steps:** `[step 1 → step 2 → step 3]`
- **Outcome:** `[what the user sees when it is finished]`
- **Failure path:** `[what happens if something goes wrong]`
- **Requirement IDs exercised:** `[FR-xx, BR-xx, …]`

### 9.2 Journey: `[name]`
`[Same shape.]`

---

## 10. Acceptance criteria

*How we will all agree the project is done. Write them so an outsider could check each one without asking questions. Each one covers named requirement IDs, and every Must requirement is covered by at least one.*

| ID | Criterion (Given / When / Then, with tolerance) | Covers (requirement IDs) | Method of verification (class) |
|---|---|---|---|
| AC-01 | `[Observable outcome]` | `[IDs]` | `[demo / test / inspection / audit]` `[class]` |
| AC-02 | `[Observable outcome]` | `[IDs]` | `[demo / test / inspection / audit]` `[class]` |

### 10.1 Verification classes

| Class | Meaning | Counts as verified when |
|---|---|---|
| **T** | Check with a fixed expected result (a truth table, a boundary case) | The check ran and passed; the run is recorded |
| **P** | Property or invariant over many generated inputs | The property held over the stated number of cases |
| **M** | Measured against a target (load, availability, recovery) | Measured under stated conditions and met the target |
| **I** | Inspection of design, configuration, or code | A named reviewer recorded the result |
| **H** | Human trial or walkthrough | The trial ran with the stated participants and met the target |
| **J** | Judgment; cannot be reduced to a check | Never "verified". A named person accepts it, with a review date |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood (H/M/L) | Impact (H/M/L) | Mitigation |
|---|---|---|---|---|
| R-01 | `[What could go wrong]` | M | H | `[What we will do about it]` |
| R-02 | `[What could go wrong]` | L | M | `[What we will do about it]` |

---

## 12. Success measures

*How we will know, after go-live, that this project delivered value. A success target that measures the same thing as a requirement in section 8 must agree with it.*

| Measure | Baseline today | Target | Matching requirement (ID) | Reviewed when |
|---|---|---|---|---|
| `[Measure]` | `[current value]` | `[target value]` | `[ID or —]` | `[date / frequency]` |

---

## 13. Glossary

*Every domain term a new reader would not know. One line each.*

| Term | Meaning |
|---|---|
| `[Term]` | `[Plain-English definition]` |
| `[Term]` | `[Plain-English definition]` |

---

## 14. Open questions

*Things we do not yet know. Each question has an owner, a date by which it must be answered, and the requirement or parameter IDs it blocks.*

| ID | Question | Owner | Due date | Blocks (IDs) | Status |
|---|---|---|---|---|---|
| Q-01 | `[Question]` | `[name]` | `[date]` | `[IDs]` | Open |
| Q-02 | `[Question]` | `[name]` | `[date]` | `[IDs]` | Open |

### 14.1 Consistency checks (complete before approval)

*Tick each, or write the finding and the question it raises. A finding that no one can test around is **Blocking**; one that can be tested but might test the wrong thing is **Clarify**.*

- [ ] No two requirements or rules contradict each other.
- [ ] Where several rules can apply to one case, section 7.6 says which wins.
- [ ] Every number a requirement relies on is in the parameter register (7.5), with a value or an owner.
- [ ] Every rule that must hold has a stated behavior for when it would be broken.
- [ ] Every rule in 7.3 is enforced by at least one requirement in 7.1.
- [ ] Every journey step agrees with the requirements it exercises, including who acts.
- [ ] The same measure does not have two different targets in two sections.
- [ ] Every target in section 8 says how it is measured.
- [ ] Every requirement table has a priority, an acceptance criterion, and a class on every row.

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor | `[name]` | | |
| Product owner | `[name]` | | |
| Technical lead | `[name]` | | |
| Compliance / risk | `[name]` | | |

### 15.1 Residual acceptance (completed after the build)

*Any requirement that is not shown to work after the build is listed here. A named person accepts each one, with a date and a review-by date. Class J requirements always appear. An acceptance is not carried over if the requirement it covered changes.*

| Requirement ID | Why it remains | Accepted by | Date | Review by |
|---|---|---|---|---|
| | | | | |

---

## Appendix A. Residual ledger

*Link to `<stem>-LEDGER.md`, written after the build. It records, for each requirement ID, whether there is executed evidence that it is met.*

`[link or file name]`

## Appendix B. Orphan behavior register

*Behavior in the finished system that serves no requirement. Completed after the build. For each item, record whether it is added as a requirement, removed, or accepted, and who decided.*

| Behavior | Where | Serves requirement? | Disposition (add / remove / accept) | Decided by |
|---|---|---|---|---|
| | | | | |

---

*End of template. Delete this line and all guidance text before circulating the filled-in version.*
