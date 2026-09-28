# ARCHITECTURE-AI-Generator.md

**File role:** An AI-executable script. An AI assistant reads this file, then reads the running Demo and its WalkThrough, and produces `<file-name>(Cell)-ARCHITECTURE.md`.

**Audience:** An AI assistant (LLM) with file read/write access.

**Inputs (all required unless noted):**

| Input | Role |
|---|---|
| `<stem>(Cell)-Demo.dart` | Source of truth for **what the program actually does** |
| `<stem>(Cell)-WalkThrough.md` | Contract, seam sentence, Real desk, Wave A |
| `<stem>-BRD.md` | Business names only — do not add new rules |
| `HowTo-Mitose.md` (optional) | Pipeline order. Not required to extract ARCHITECTURE. |
| `HowTo-Mitose-Cell.md` | Why ingress / observe / transaction / txApply are placed as they are |
| `HowTo-Mitose-Flow.md` | Why custom instruction + `+` + `toHandle`, not fluent policy |
| `HowTo-Mitose-Tissue.md` | Why each of the five books exists |
| `card-auth-pipeline(Cell)-ARCHITECTURE.md` | Structural template — do not copy card nouns |

**Where the Mitose HowTos live**

1. User-attached / workspace copies first.
2. Else [`https://github.com/simon-m-lee/cell/tree/master/guide`](https://github.com/simon-m-lee/cell/tree/master/guide). If that folder 404s, stay on workspace copies; package HowTos also live under `packages/*/guide/`.
3. **Mitose** is the German verb, not a typo. Do not rename the files.
4. If a **layer** HowTo or the Demo is missing, **stop**. Never write ARCHITECTURE from the WalkThrough alone. Missing `HowTo-Mitose.md` is not a stop.

**Output:** `<stem>(Cell)-ARCHITECTURE.md` (match the Demo stem). Never overwrite without asking.

---

## 0. Instructions to the AI

You are extracting **rationale**, not inventing a better design. The Demo knows *how*. This file explains *why* a maintainer must not collapse the seam.

### Rules of engagement

1. **Demo is the source of truth for locks, observers, failures, and symbols.** If the WalkThrough asked for `alreadyClosed` and `main()` never drives it, ARCHITECTURE says “clause exists, unproven” — it does not pretend the Demo handles it.
2. **No new business rules.** Thresholds and actors come from the BRD via the WalkThrough. ARCHITECTURE does not invent a third severity.
3. **Do not write FEATURES or rewrite the Demo in this pass.**
4. **Consult the three Mitose HowTos** when naming why a part lives on Cell vs Flow vs Tissue. Cite the HowTo section in the ownership / layering text.
5. **Every lock the Demo takes must be named. Every failure the Demo handles must be named.** A lock the code does not take is an anti-pattern to list, not a section to fabricate.
6. **Header diagram must match the Demo header / install path**, not an ideal hotel/aircraft diagram.
7. Stop when §8 checklist passes.

### Opening line

> I have the Demo and WalkThrough. I will extract `<stem>(Cell)-ARCHITECTURE.md` from the *running* program, using this generator’s section order and HowTo-Mitose-Cell / Flow / Tissue for layer rationale. HowTo-Mitose.md is optional process. First I will show the four-question extract, then I will write the file.

Then run §1.

---

## 1. Four questions (show the user before writing)

Walk the Demo source and answer in a table:

| Question | Answer from *this* Demo (symbols) |
|---|---|
| 1. Where is the seam, and which way does it face? | Instruction → `MapValue` → gate Cell → `Cell.observe` → Tissue. Name the two (or one) `toHandle` products. |
| 2. Who owns each concern, and who owns each lock? | Receptor on gate Cell(s); Tissue lock on each book; latch = Dart field under Receptor; `reset()` does not rebuild. |
| 3. What fails, and what does the Demo do? | TestCell reject, TestTissue / harness overdraw, pump fail-once, deputy add blocked, protected / closed clauses if `main()` drives them. |
| 4. What would a maintainer break by “simplifying”? | Writing the log inside `riskOf`; `toHandle` on ACK; TestCell on Tissue; one chain when two products exist. |

Also list:

| HowTo check | Found in Demo? | Note |
|---|---|---|
| `Cell.ingress` + `Cell.observe` | | HowTo-Mitose-Cell §3 |
| `Cell.transaction` | yes / no / deferred | Do not describe a tx the Demo never opens |
| `Cell.txApply` | yes / no / deferred | Same |
| Custom `FlowInstructionBase` + `MapValue` + `+` | | HowTo-Mitose-Flow §4 |
| Stock Time / Flatten / Combine / Collect | name or none | |
| TissueList / Set / Map / Queue / Value | which exist | HowTo-Mitose-Tissue §2 |
| `.unmodifiable` / deputy | | |

Show this extract. Ask:

> Proceed with this rationale, or correct a symbol first?

Wait, then write the file.

---

## 2. File shape (do not reorder)

Imitate `card-auth-pipeline(Cell)-ARCHITECTURE.md`:

```markdown
# Architecture — <short domain> (Cell variant)

**Demo:** `<stem>(Cell)-Demo.dart`
**Requirement:** `<stem>(Cell)-WalkThrough.md`
**BRD:** `<stem>-BRD.md`
**Layer guides:** HowTo-Mitose-Cell / Flow / Tissue
```

### 2.1 One-paragraph summary

Industry desk + seam sentence + **two lock domains** (Receptor vs Tissue). Plain English first sentence; symbols allowed after.

### 2.2 See-also name plate

BRD, WalkThrough, Demo, FEATURES (even if FEATURES is not written yet), the three Mitose HowTos.

### 2.3 Layering

ASCII path that matches `install()` / `installGates()`:

```text
ingress Cells  →  tickIn
                     │
        NounRiskInstruction + MapValue
                     │ toHandle × N
              gate Cell(s)
                     │ Cell.observe
        events / reserve / map / set / queue
```

State why Flow is not fluent here (HowTo-Flow: one Receptor, one lock, ACK `reset`).
State why books are Tissue not `Cell.state` (HowTo-Tissue).
State why observe is the only glue (HowTo-Cell).

### 2.4 Ownership matrix

| Concern | Owner | Does not own |
|---|---|---|
| Policy / latch / `pass` | custom instruction (Receptor) | Tissue writes |
| Projection | stock `MapValue` | clauses |
| Graph install | `installGates` | ACK path |
| Glue | `Cell.observe` | `riskOf` |
| Books | Tissue + TestTissue | decision |
| Reserve raise/close | harness methods | instruction |
| Device / issuer undo | `Cell.txApply` **only if Demo calls it** | — |

### 2.5 Locking

- Receptor lock covers instruction + latch + MapValue.
- Latch is a **plain Dart field** under that lock; `reset()` does not call `toHandle`.
- Each Tissue has its own lock.
- `Cell.transaction` / `txApply` only if present — describe isolation / compensate from the code, not from the hotel example.

### 2.6 Failure semantics

One subsection per failure **the Demo actually prints or returns `ok=false` for**:

| Failure | Mechanism | Demo banner |
|---|---|---|
| Bad identity / empty stream / qty out of range | TestCell on named ingress | e.g. scenario 8 |
| Overdraw reserve | TestTissue and/or harness pre-check — say which | |
| Pump fail-once | `_drive*` + retry | |
| Deputy write | `.unmodifiable` | COMPLY |
| Protected / closed | `riskOf` first clauses | only if driven |

Do not copy aircraft “cancel push” unless this Demo voids a device.

### 2.7 Extending the demo

Map WalkThrough Wave A rows to **land in**:

| Enhancement | Lands in | Must not land in |
|---|---|---|
| Disposition on close | harness `close` + Event field | `riskOf` |
| Note on ACK | ACK observer | instruction |
| Wall clock | timer ingress or tick field | instruction I/O |
| `alreadyClosed` banner | `main()` | new lock |

Cite HowTo-Mitose-* if the landing layer is the point.

### 2.8 Anti-patterns

Minimum set (delete any the Demo already committed — then it is a documented debt, not an anti-pattern):

- Tissue write inside the instruction / `Tap` on the decision chain
- `riskOf` inside `observe`
- `toHandle` from ACK
- TestCell on Tissue
- Inventing `Cell.gate` / `TissueGraph`
- Fluent Distinct *and* instruction latch unexplained
- Describing `transaction` the Demo does not open

### 2.9 Reading order

Demo header → this file §2.3–2.6 → HowTo-Mitose-Cell / Flow / Tissue → FEATURES.

### 2.10 See also

Repeat the name plate with GitHub `guide/` links for the Mitose HowTos.

---

## 3. What you may and may not invent

**May:** diagrams, ownership wording, names for lock domains, grouping of failures already in the Demo.

**May not:** extra products, extra books, extra locks, “we would use `txApply` here” presented as if it were code, BRD numbers that the Demo does not use.

If WalkThrough §15 listed a hole (`alreadyClosed` untested), ARCHITECTURE §2.6 must **not** list it as a handled failure. Put it under §2.7 or “unproven”.

---

## 4. After writing

> Done. `<stem>(Cell)-ARCHITECTURE.md` is extracted from the Demo.
>
> Locks named: …
> Failures named: …
> transaction / txApply: present / absent
> HowTos: user-provided / GitHub `guide/`
>
> FEATURES is the next document. Say if you want that pass.

---

## 5. Checklist

- [ ] Demo file was read; ARCHITECTURE not written from WalkThrough only
- [ ] Mitose HowTos loaded
- [ ] Four-question table shown and confirmed
- [ ] Section order 2.1–2.10 kept
- [ ] Diagram matches install path
- [ ] Every Demo lock named; no fictional lock
- [ ] Failures match printed banners / `ok=false`
- [ ] No new business rules
- [ ] FEATURES / Demo rewrite not done in this pass
- [ ] Existing ARCHITECTURE not overwritten without asking

---

## 6. Acceptance criteria for *this generator*

The ARCHITECTURE pass is accepted only when all of the following hold. Show Pass / Fail to the user.

| ID | Criterion | Method |
|---|---|---|
| G-AC-01 | `<stem>(Cell)-ARCHITECTURE.md` exists; no overwrite without asking | file inspect |
| G-AC-02 | Demo source was read; file was not written from the WalkThrough alone | chat log |
| G-AC-03 | Four-question extract was shown and confirmed before writing | chat log |
| G-AC-04 | HowTo-Mitose-Cell / Flow / Tissue loaded | chat log |
| G-AC-05 | Section order is summary → name plate → layering → ownership → locking → failure → extend → anti-patterns → reading order → see also | inspect headings |
| G-AC-06 | ASCII path matches `install()` / `installGates()` in the Demo | compare Demo |
| G-AC-07 | Every lock the Demo takes is named; no lock the Demo does not take is described as present | grep Demo |
| G-AC-08 | Failure subsections match printed banners or `ok=false` only | compare Demo header / `main()` |
| G-AC-09 | `Cell.transaction` / `Cell.txApply` described only if the Demo calls them | grep |
| G-AC-10 | No new business rule or third product | compare BRD / WalkThrough |
| G-AC-11 | Unproven WalkThrough clauses are “unproven”, not handled failures | compare §15 / `main()` |
| G-AC-12 | FEATURES / Demo were not rewritten in this pass | files |

Fail any row → do not claim ARCHITECTURE is done.

---

*End of ARCHITECTURE-AI-Generator.md.*
