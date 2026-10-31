# WhatIS-Mitose-Artifacts.md

**Version:** 0.1.0
## 1. The one-line distinction

Each artifact answers a different question, and blurring them is what Mitose 2.0 exists to prevent:

| Artifact | Answers |
|---|---|
| **BRD** | *What is required?* |
| **WalkThrough** | *How must it behave?* |
| **COMPREHENSION** | *Did a person understand and choose what's being approved?* |
| **Demo** | *What does the program actually do?* |
| **Test** | *What checks were written, and what did the `BRD` group print?* |
| **LEDGER** | *What is proven — per requirement ID?* |
| **ARCHITECTURE** | *How is it built, as it runs?* |
| **FEATURES** | *What can a user do with it?* |
| **CHANGE** | *What changed, by ID, and who decided?* |

## 2. Artifact-by-artifact

### BRD — Business Requirements Document
- **For:** stating *what* must be true, as the source of truth. Requirement register with permanent IDs (FR / DR / BR / AR / NFR), priority, a testable criterion, and a verification class (T = testable, J = judgment); a **parameter register** for every threshold, unit, owner, and status; findings; rule precedence; change history.
- **Not for:** designing the solution, or inventing numbers the business did not state — missing values are `[To be confirmed]`, inferred ones `[AI SUGGESTED]`.
- **Gate:** B1 (readiness check) before the WalkThrough. Unresolved findings do not forbid proceeding; they become **Blocked** rows.
- **Example in this run:** `baggage-flow-BRD.md` v0.1.1 — 14 requirement rows; F-1/F-2/F-3 carried as Blocked; D-B1 (template not supplied).

### WalkThrough
- **For:** the behaviour contract between BRD and code — ingress list, policy/clause order, chain assembly, pulse path, Tissue books, scenarios with must-print banners, a **coverage matrix** (scenario → BRD ID → expected print), Real-desk deferrals, open questions. It places each part in the right layer (Cell / Flow / Tissue), with the seam sentence *the instruction decides, the chain assembles, the observer glues*.
- **Not for:** inventing business numbers; its expected prints come from the BRD.
- **Gate:** C1 (comprehension prediction, offered once) before acceptance; §5.12 Demo Assessment is filled from the Dart file *after* the Demo exists.
- **Example in this run:** `baggage-flow-WalkThrough.md` v0.1.1 — accepted; expected prints `[PLACEHOLDER]` (D-2); layer placements `[AI SUGGESTED — unverified]`.

### COMPREHENSION
- **For:** recording that a person *understood and chose* what they approved — chiefly the **C1 prediction check** (predict three scenarios before reading expected results; a mismatch is a signal about the document first), plus the **decision log** (gate C3) of choices actually raised: layer placements, resolved findings, accepted residual items, adopted/declined Recommendations, departures, approved protected changes.
- **Not for:** grading the person (rule: *describe, never grade*; no comprehension score), or recording approvals the agent did not receive.
- **Gate:** C3 — shown *before* ARCHITECTURE is written. Skipping/declining C1 is allowed and recorded.
- **Example in this run:** C1 offered and **declined** (recorded); decision log drafted from D-2/D-3/D-B1, B1 dispositions F-4 to F-7, L1 confirmation, §6 pending, L4 not accepted.

### Demo
- **For:** what the program *actually does* — importable decision logic (no work at import time), the Cell I/O table, header registers (provenance, boundary), IDs covered / not covered, and `main()` driving the scenarios. After it exists, the Demo is the source of truth for symbols and what runs.
- **Not for:** inventing BRD facts; changing expected values to match behaviour (protected, gate C2).
- **Depends on:** an accepted WalkThrough — never written before acceptance.
- **Example in this run:** `baggage-flow-Demo.dart` v0.1.0 — `RiskInstruction.riskOf`, `Books`, `assembleChain` (identity stub), `installGates` (stub); package wiring commented (D-3).

### Test
- **For:** the checks and the **ledger report**. Always written *with* the Demo. The **`BRD` group** is the only group whose results move a ledger row; it prints `LEDGER <ID> <PASS|FAIL|BLOCKED> expected=… actual=… note=…`. Other groups cover public APIs, documented contracts, and the three **fail-closed gaps**: `constraint` (grep: zero `testRule: TestCell` on Tissue; no Tissue writes in the instruction), `provenance` (header register), `boundary` (ingress / `txApply` present or deferred). A failure in those groups fails the suite.
- **Not for:** class J judgment; a missing parameter stays **BLOCKED**. Expected values come from the BRD, never from Demo output.
- **Run:** `dart test <stem>-test.dart` — explicit path; a bare `dart test` won't find it.
- **Example in this run:** `baggage-flow-test.dart` v0.1.0 — supplied `LEDGER` lines: 13 BLOCKED; fail-closed groups are placeholder assertions (D-3).

### LEDGER
- **For:** the record of which BRD requirements have **executed evidence** of conformance, per ID — **Verified / Failed / Blocked** — with the run's provenance, mechanical class I checks (analyzer, greps), an **orphan scan**, per-Blocked-row **mitigation**, and **residual acceptance** (named person + review date only).
- **Not for:** proving correctness, grading skill, or accepting risk on the user's behalf. *Reading code is never Verified.* A ledger with no Failed rows says only that the stated checks passed against the BRD *as written*.
- **Gate:** L1 (extract confirmed), L3 (run the commands / supply output), L4 (residual acceptance).
- **Example in this run:** `baggage-flow-LEDGER.md` v0.1.0 — **13 rows, 0 Verified, 0 Failed, 13 Blocked, 0 Accepted**; reasons and mitigations recorded; no acceptor.

### ARCHITECTURE
- **For:** how the running Demo is built — its real symbols, the seam in practice, ingress and deputies, transaction/txApply present or deferred — citing decision IDs rather than re-arguing, and **reading the ledger** so nothing Blocked/Failed/Unverified is described as handled; accepted residual items go under limitations.
- **Not for:** design fiction, or describing a lock/feature the current Demo does not contain (rewrite instead). Hard stop: Demo + WalkThrough.
- **Gate:** offered, not assumed; C3 decision log must be shown first.
- **Example in this run:** not written; would honestly be thin (no real package wiring, placeholder greps, all rows Blocked).

### FEATURES
- **For:** the user-facing capability inventory, written **from the Demo**, each capability tied to the BRD ID it serves, with limitations from the ledger. Not written from a WalkThrough wish-list.
- **Not for:** marketing overstatement; Blocked stays Blocked. Hard stop: Demo.
- **Gate:** offered, not assumed; reads the ledger if one exists.
- **Example in this run:** not written; would list S1–S8 capabilities as "structure present; not Verified — see ledger."

### CHANGE
- **For:** later change to a solution that already has BRD + WalkThrough + Demo + ledger. States the change as a **BRD diff** (requirement / upgrade / drift / defect), traces impact **by ID** (Unknown = affected), applies by amending rather than regenerating, records **drift dispositions** (adopt / revert / accept), resets affected ledger rows to Unverified, requires **re-acceptance** when a covered requirement changed, and runs a **release check**. Each file is numbered `<stem>-CHANGE-<nnn>.md` and is **immutable**.
- **Not for:** editing one side (code vs BRD) to match the other without a decision; reusing a change number; accepting risk for the user.
- **Gates:** CH1 (diff), CH2 (impact + plan), CH3 (drift), CH4 (residual re-acceptance), CH5 (release).
- **Example in this run:** none yet; the open §6 offer (Change / In place / Skip for R1–R5) is the entry point if you choose Change.

## 3. Pipeline order and gates

```
BRD (B1) ─▶ WalkThrough (C1, C4, accept) ─▶ COMPREHENSION (C1 record)
   ─▶ Demo ─▶ Test (BRD + constraint + provenance + boundary groups)
   ─▶ WalkThrough §5.12 revisit (§6 offer) ─▶ LEDGER (L1, L3, L4)
   ─▶ decision log (C3) ─▶ ARCHITECTURE / FEATURES (offered)
   ─▶ CHANGE (CH1–CH5) for later change
```

One human decision at each gate; gates are not chained. The three fail-closed gaps (constraint, provenance, boundary) fail the suite; they are not notes.

## 4. Status in this run (baggage-flow)

| Artifact | File | Version | State |
|---|---|---|---|
| BRD | baggage-flow-BRD.md | 0.1.1 | B1 passed |
| WalkThrough | baggage-flow-WalkThrough.md | 0.1.1 | Accepted; placeholders (D-2) |
| COMPREHENSION | baggage-flow-COMPREHENSION.md | — | C1 declined; decision log pending C3 |
| Demo | baggage-flow-Demo.dart | 0.1.0 | structure present; no package wiring (D-3) |
| Test | baggage-flow-test.dart | 0.1.0 | 13 BLOCKED; fail-closed groups placeholder |
| LEDGER | baggage-flow-LEDGER.md | 0.1.0 | 0 Verified / 13 Blocked / 0 Accepted |
| ARCHITECTURE | — | — | not offered yet (needs C3) |
| FEATURES | — | — | not offered yet (needs C3) |
| CHANGE | — | — | none; §6 choice pending |

**Conformance statement:** conformance to the BRD as written is **not demonstrated** for any requirement. This summary records that state; it does not change it.

## 5. What this document is not

- Not a pipeline artifact; it carries no IDs that the ledger must track.
- Not evidence; it cannot make a row Verified.
- Not an approval; approvals belong to named people at named gates.
- Not a replacement for any of the nine documents it summarizes.
- Not a proof of correctness — a ledger with no Failed rows shows only that the stated checks passed against the BRD as written.