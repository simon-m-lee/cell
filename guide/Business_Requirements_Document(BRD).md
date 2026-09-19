# Business Requirements Document (BRD) — Standard Template

**Purpose:** This template helps you write a "Day 1" business requirements document. Fill in each section in plain English. Do not describe how the system will be built — only what the business needs the system to do. Leave a section blank if it does not apply, or write "N/A" with a one-line reason.

**How to use it:** Copy this file, rename it `\<your-project\>-BRD.md`, and fill in the blanks. Replace every `[...]` with your answer. Delete the italic guidance under each heading once you have written your answer.

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

| Version | Date | Author | Change summary |
|---|---|---|---|
| 0.1 | `[date]` | `[name]` | First draft |

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
- If a requirement cannot be tested, rewrite it.

### 7.1 Functional requirements

| ID | Requirement | Priority (Must / Should / Could) | Rationale |
|---|---|---|---|
| FR-01 | The system shall `[action]`. | Must | `[why]` |
| FR-02 | The `[role]` shall be able to `[action]`. | Must | `[why]` |
| FR-03 | The system shall `[action]` when `[condition]`. | Should | `[why]` |

### 7.2 Data requirements

| ID | Requirement | Priority | Rationale |
|---|---|---|---|
| DR-01 | The system shall capture `[data item]` with `[attributes]`. | Must | `[why]` |
| DR-02 | The system shall retain `[data]` for `[period]`. | Must | `[regulatory or business reason]` |
| DR-03 | The system shall prevent `[bad data]` from being recorded. | Must | `[why]` |

### 7.3 Rules and policy

*Business rules that are not negotiable — legal, regulatory, contractual, safety, or long-standing company policy.*

| ID | Rule | Source | Priority |
|---|---|---|---|
| BR-01 | `[Rule statement]` | `[law / policy / contract]` | Must |
| BR-02 | `[Rule statement]` | `[law / policy / contract]` | Must |

### 7.4 Reporting and audit

| ID | Requirement | Audience | Frequency | Retention |
|---|---|---|---|---|
| AR-01 | `[Report name]` shall show `[content]`. | `[role]` | `[daily / on demand]` | `[period]` |

---

## 8. Non-functional requirements

*How well the system must behave. Keep them measurable.*

| ID | Category | Requirement | Target |
|---|---|---|---|
| NFR-01 | Performance | The system shall respond within `[X ms / s]` for `[action]`. | `[number]` |
| NFR-02 | Availability | The system shall be available `[X%]` during `[window]`. | `[number]` |
| NFR-03 | Capacity | The system shall support `[N]` concurrent `[users / records / events]`. | `[number]` |
| NFR-04 | Security | Access to `[data]` shall require `[authorisation rule]`. | `[rule]` |
| NFR-05 | Auditability | Every `[action]` shall be traceable to `[who / when / why]`. | `[rule]` |
| NFR-06 | Usability | A `[role]` shall complete `[task]` in `[N]` steps or fewer. | `[number]` |
| NFR-07 | Compliance | The system shall comply with `[regulation / standard]`. | `[name]` |
| NFR-08 | Recoverability | The system shall recover from failure within `[X]`. | `[number]` |

---

## 9. User journeys

*For each main scenario, describe the flow in plain English: who does what, in what order, and what "done" looks like.*

### 9.1 Journey: `[name]`
- **Trigger:** `[what starts it]`
- **Steps:** `[step 1 → step 2 → step 3]`
- **Outcome:** `[what the user sees when it is finished]`
- **Failure path:** `[what happens if something goes wrong]`

### 9.2 Journey: `[name]`
`[Same shape.]`

---

## 10. Acceptance criteria

*How we will all agree the project is done. Write them so an outsider could check each one without asking questions.*

| ID | Criterion | Method of verification |
|---|---|---|
| AC-01 | `[Observable outcome]` | `[demo / test / inspection / audit]` |
| AC-02 | `[Observable outcome]` | `[demo / test / inspection / audit]` |

---

## 11. Risks and mitigations

| ID | Risk | Likelihood (H/M/L) | Impact (H/M/L) | Mitigation |
|---|---|---|---|---|
| R-01 | `[What could go wrong]` | M | H | `[What we will do about it]` |
| R-02 | `[What could go wrong]` | L | M | `[What we will do about it]` |

---

## 12. Success measures

*How we will know, after go-live, that this project delivered value.*

| Measure | Baseline today | Target | Reviewed when |
|---|---|---|---|
| `[Measure]` | `[current value]` | `[target value]` | `[date / frequency]` |

---

## 13. Glossary

*Every domain term a new reader would not know. One line each.*

| Term | Meaning |
|---|---|
| `[Term]` | `[Plain-English definition]` |
| `[Term]` | `[Plain-English definition]` |

---

## 14. Open questions

*Things we do not yet know. Each question has an owner and a date by which it must be answered.*

| ID | Question | Owner | Due date | Status |
|---|---|---|---|---|
| Q-01 | `[Question]` | `[name]` | `[date]` | Open |
| Q-02 | `[Question]` | `[name]` | `[date]` | Open |

---

## 15. Approvals

| Role | Name | Signature | Date |
|---|---|---|---|
| Business sponsor | `[name]` | | |
| Product owner | `[name]` | | |
| Technical lead | `[name]` | | |
| Compliance / risk | `[name]` | | |

---

*End of template. Delete this line and all guidance text before circulating the filled-in version.*