# FEATURES-AI-Generator.md

**File role:** An AI-executable script. An AI assistant reads this file, then reads the running Demo (and WalkThrough §8 / §15), and produces `<file-name>(Cell)-FEATURES.md`.

**Audience:** An AI assistant (LLM) with file read/write access.

**Inputs:**

| Input | Role |
|---|---|
| `<stem>(Cell)-Demo.dart` | Source of truth — **if a row cannot be grepped here, delete the row** |
| `<stem>(Cell)-WalkThrough.md` | Scenario banners, §15 coverage, Real desk |
| `<stem>(Cell)-ARCHITECTURE.md` | Lock / seam names to cross-link (optional if not yet written — say so) |
| `<stem>-BRD.md` | FR/DR/BR/AC IDs for the “serves” column only |
| `HowTo-Mitose.md` (optional) | Pipeline order. Not required to extract FEATURES. |
| `HowTo-Mitose-Cell.md` | Ingress / observe / transaction / txApply rows |
| `HowTo-Mitose-Flow.md` | Instruction, `+`, `toHandle`, stock operators that exist |
| `HowTo-Mitose-Tissue.md` | Five books + TestTissue + deputy |
| `card-auth-pipeline(Cell)-FEATURES.md` | Catalogue column shape — do not copy card nouns |

**Where the Mitose HowTos live:** user-attached copies first, else [`https://github.com/simon-m-lee/cell/tree/master/guide`](https://github.com/simon-m-lee/cell/tree/master/guide). If that folder 404s, stay on workspace copies. **Mitose** is the German verb, not a typo. If the Demo is missing, **stop**. FEATURES written from a WalkThrough alone is a wish-list. Missing `HowTo-Mitose.md` is not a stop.

**Output:** `<stem>(Cell)-FEATURES.md`. Never overwrite without asking.

---

## 0. Instructions to the AI

FEATURES is the **audit catalogue** of the executable. A reviewer should grep every “Where” cell in the Demo and find it.

### Rules of engagement

1. **Demo symbols only.** `EdRiskInstruction.riskOf`, `_eventAppendOnly`, `installGates`, `_driveAlert` — not “the policy function”.
2. **If it is not in the Demo, it is not a feature row.** Put it in “deliberately does not do” or omit it.
3. **Every Cell-touching row states input parameter(s) and output `Pulse<type>`.**
4. **Trailer integers must match the Demo header**, not the first WalkThrough draft.
5. **Consult Mitose HowTos** so the operator cheat sheet uses real factory names and does not list `asyncMap` as a Cell concern.
6. **Do not invent BRD IDs.** Cite existing FR/DR/BR/AC or write `—`.
7. Do not rewrite Demo / ARCHITECTURE in this pass.
8. Stop when §6 checklist **and** §7 acceptance criteria all pass.

### Opening line

> I have the Demo. I will extract `<stem>(Cell)-FEATURES.md` as an audit catalogue: one greppable row per observable, scenario map, operator cheat sheet, acceptance checks. HowTo-Mitose-Cell / Flow / Tissue name the layers. First I will show the inventory, then I will write the file.

Then run §1.

---

## 1. Inventory the Demo (show before writing)

Walk the file top to bottom. Produce four lists.

### 1.1 Cell surface

| Handle / Cell | Input | TestCell | Emits |
|---|---|---|---|
| `tickIn` | | | `Pulse<*Tick>` |
| `ackIn` | | | `Pulse<String>` |
| … only ingresses that exist | | | |

Add `Cell.transaction` / `Cell.txApply` rows only if those calls exist.

### 1.2 Flow surface

| Symbol | Role | Grep |
|---|---|---|
| `*RiskInstruction` | `riskOf`, `lastDecision`, `reset`, `pass` | class name |
| each `riskOf` clause | condition → level | quote the `if` |
| `MapValue<…>` | Decision → enum | |
| `toHandle` | count must equal product count | `installGates` only |
| stock operators on the chain or feed | `Filter` / `Distinct` / … | HowTo-Flow name |

### 1.3 Tissue surface

| Book | Type | TestTissue | Writes from |
|---|---|---|---|
| `events` | List | append-only? | observe / raise / close |
| reserve | Value | `>= 0`? | raise / close |
| open map | Map | qty > 0? | |
| guard set | Set | | |
| outbound Q | Queue | | |
| deputy | `.unmodifiable` | | COMPLY |

Skip types the Demo never constructs. Say “Set not used”.

### 1.4 Scenarios vs Demo banners

| WalkThrough banner | Printed in `main()`? | Trailer effect |
|---|---|---|
| Seed … COMPLY | yes / no / renamed | |

Trailer line from the **Demo header** (copy verbatim).

Show the four lists. Ask:

> Proceed with this inventory, or drop a row that is not actually in the file?

Wait, then write.

---

## 2. File shape (do not reorder)

Imitate `card-auth-pipeline(Cell)-FEATURES.md`.

```markdown
# Features — <short domain> (Cell variant)

**Demo:** `<stem>(Cell)-Demo.dart`
**Requirement:** `<stem>(Cell)-WalkThrough.md`
**Architecture:** `<stem>(Cell)-ARCHITECTURE.md`
**BRD:** `<stem>-BRD.md`
**Layer guides:** HowTo-Mitose-Cell / Flow / Tissue
```

### 2.1 See-also name plate

Same Mitose document set (`HowTo-Mitose.md` optional) + layer HowTos + GitHub `guide/` URL (workspace copies first).

### 2.2 Feature catalogue

One row per **observable**. Suggested order = Demo source order:

| ID | Feature | Serves (BRD) | Where in Demo | Input → `Pulse<type>` | Notes |
|---|---|---|---|---|---|
| F-01 | Encounter / tag ingress rule | DR-xx | `_encounterShape`, `encounterIn` | `String` → `Pulse<String>` | reject `''` |
| F-02 | Tick bus | FR-xx | `tickIn`, `publishTick` | `*Tick` → `Pulse<*Tick>` | |
| F-03 | `riskOf` empty / closed | BR-xx | `*RiskInstruction.riskOf` | tick → `none` | unproven if `main()` never sets the flag |
| F-04 | `riskOf` protected | BR-xx | clause + `TissueSet` | | |
| F-05 | `riskOf` warn | FR-xx | | | |
| F-06 | `riskOf` hard | FR-xx | | | |
| F-07 | Distinct latch | — | `lastDecision` | | |
| F-08 | Product filter `pass` | — | two instances | `Pulse<*Decision>` | |
| F-09 | `MapValue` | — | `toLevel` | Decision → `Pulse<Level>` | |
| F-10 | `toHandle` × N | — | `installGates` | | |
| F-11 | Observe → log | AR-xx | `Cell.observe` | `Pulse<Level>` → side effect | |
| F-12 | Append-only events | AR-xx | `_eventAppendOnly` | | |
| F-13 | Reserve Value | — | `raise` / `close` | | |
| F-14 | Open Map | FR-xx | | | |
| F-15 | Guard Set | BR-xx | | | |
| F-16 | Outbound Queue + pump | FR-xx | `_drive*`, `_failNext*` | | |
| F-17 | ACK + `reset()` | FR-xx | `ackIn` observe | `Pulse<String>` | no `toHandle` |
| F-18 | Deputy / COMPLY | BR-xx | `.unmodifiable` | | |
| F-19 | Trailer `lastDecision=null` | — | `main()` end | | |

Renumber. **Delete** any F-row whose “Where” is not in the Demo. Mark unproven clauses in Notes, do not drop the clause if the method contains it but `main()` never drives it — say “in `riskOf`, not in `main()`”.

### 2.3 Scenario catalogue

| Banner | WalkThrough §8 | Demo `main()` label | Proves |
|---|---|---|---|
| Seed | … | `── Seed ──` | drop `none` |
| … | | | |

If WalkThrough and Demo banners disagree, Demo column wins; add a Deviations line.

### 2.4 What this demo deliberately does not do

Union of:

- BRD § out of scope  
- WalkThrough Real desk  
- WalkThrough §15 “not in this Demo”  
- HowTo-Cell transaction/txApply you marked absent  

No pretending NFR-99.5% is a feature.

### 2.5 Operator cheat sheet

Split by layer (Mitose HowTos):

| Layer | Call | Do not call here |
|---|---|---|
| Cell | `Cell.ingress`, `Cell.observe`, (`transaction` / `txApply` iff present) | stream operators |
| Flow | `FlowInstructionBase`, `+`, `MapValue`, `toHandle`, named stock ops | Tissue `add` |
| Tissue | `add` / `set` / `[]=` / `addLast`, `.unmodifiable` | `TestCell` |

### 2.6 Acceptance checklist (goes into FEATURES.md)

Grep-able, from WalkThrough §13 + Demo header:

- [ ] `dart analyze <stem>(Cell)-Demo.dart`
- [ ] `dart run` prints the Demo-header console, including trailer integers **copied from the header**
- [ ] custom instruction extends `FlowInstructionBase<Cell, Pulse, Pulse>`
- [ ] `toHandle` count = product count, only in `installGates`
- [ ] zero `testRule: TestCell` on Tissue constructors
- [ ] instruction has no Tissue write; observers have no `riskOf`
- [ ] both gates `lastDecision=null` after ACK ALL (if two products)

### 2.6b BRD acceptance traceability (goes into FEATURES.md)

Copy every AC-xx from the BRD. Do not invent ACs.

| BRD AC | Criterion (verbatim) | In this Demo? | Where | Method |
|---|---|---|---|---|
| AC-01 | … | In demo / Partial / Real desk / Out | symbol or — | run / grep / inspection |

Rules:

- “In demo” only if a scenario banner or grep proves it.
- “Partial” if a stand-in exists (tick field instead of a clock).
- WalkThrough §15 wins over wishful mapping.
- Open BRD questions stay Open; they are not ACs.

### 2.7 See also

Name plate again.

---

## 3. What you may and may not invent

**May:** F-IDs, column wording, grouping.

**May not:** features the Demo does not implement; operators HowTo-Cell told you to leave to Flow listed as Cell features; trailer counts from the pre-Demo WalkThrough.

---

## 4. After writing

> Done. `<stem>(Cell)-FEATURES.md` catalogues the Demo.
>
> Feature rows: *n* (all greppable)
> Scenarios mapped: *k*
> Trailer used: `ticks=…` (Demo header)
> HowTos: user-provided / GitHub `guide/`
>
> Reconcile pass is next if WalkThrough §8 / ARCHITECTURE diagram still disagree with this catalogue.

---

## 5. Relationship to the other generators

| Generator | Produces | FEATURES uses it as |
|---|---|---|
| `BRD-AI-Interview.md` | BRD | ID column only |
| `WalkThrough-AI-Generator.md` | WalkThrough | banners + Real desk |
| Demo (no generator in this folder) | executable | **truth** |
| `ARCHITECTURE-AI-Generator.md` | rationale | see-also, lock names |
| this file | catalogue | audit |

Write FEATURES after Demo. Prefer after ARCHITECTURE so the name plate is real.

---

## 6. Checklist

- [ ] Demo was read; no FEATURES-from-WalkThrough-only
- [ ] Mitose HowTos loaded
- [ ] Inventory shown and confirmed
- [ ] Every feature “Where” greps in the Demo
- [ ] Cell rows have input → `Pulse<type>`
- [ ] Trailer matches Demo header
- [ ] Absent transaction / txApply / Tissue types listed under “does not do”, not as features
- [ ] Unproven `riskOf` clauses noted, not sold as scenario-proven
- [ ] Demo / ARCHITECTURE not rewritten
- [ ] Existing FEATURES not overwritten without asking

---

## 7. Acceptance criteria for *this generator*

The FEATURES pass is accepted only when all of the following hold. Show this table to the user with Pass / Fail.

| ID | Criterion | Method |
|---|---|---|
| G-AC-01 | `<stem>(Cell)-FEATURES.md` exists and was not overwritten without asking | file inspect |
| G-AC-02 | Demo was read; inventory (§1) was shown before the file was written | chat log |
| G-AC-03 | Every feature-catalogue “Where” greps in the Demo | `grep` |
| G-AC-04 | Every Cell-touching row has input parameter(s) and output `Pulse<type>` | inspect table |
| G-AC-05 | Trailer integers in FEATURES equal the Demo header, not a stale WalkThrough | diff |
| G-AC-06 | No feature row for `transaction` / `txApply` / a Tissue type the Demo does not construct | grep Demo |
| G-AC-07 | Operator cheat sheet splits Cell / Flow / Tissue per Mitose HowTos | inspect |
| G-AC-08 | §2.6b lists every BRD AC-xx with In demo / Partial / Real desk / Out | compare BRD § acceptance |
| G-AC-09 | Unproven `riskOf` clauses are noted, not marked scenario-proven | compare `main()` |
| G-AC-10 | Mitose HowTos were loaded (workspace or GitHub `guide/`) | chat log |
| G-AC-11 | Demo / ARCHITECTURE were not rewritten in this pass | git / files |
| G-AC-12 | Name plate lists BRD, WalkThrough, Demo, ARCHITECTURE, Mitose HowTos | inspect |

Fail any row → do not claim FEATURES is done.

---

*End of FEATURES-AI-Generator.md.*
