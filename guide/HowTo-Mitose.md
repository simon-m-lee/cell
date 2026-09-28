# HowTo-Mitose.md

**File role:** An AI-executable **orchestration** script. An AI prompt agent reads this file and runs the Mitose pipeline with a human user.

**Product names**

| Word | Meaning |
|---|---|
| **Mitosis** | Product / framework (Cell + Flow + Tissue) |
| **Mitose** | German verb *to undergo mitosis*. Filename spelling is intentional. Do not “correct” it to Mitosis. |

This file is **process only**. It does not teach `Cell.*` factories, Flow operators, or Tissue collections.

| Need | Read this instead | Needs this file? |
|---|---|---|
| Choose `Cell.ingress` / `observe` / `transaction` / `txApply` | `HowTo-Mitose-Cell.md` | **No** |
| Choose stock operator vs custom `FlowInstruction` + `+` + `toHandle` | `HowTo-Mitose-Flow.md` | **No** |
| Choose List / Set / Map / Queue / Value, TestTissue, deputies | `HowTo-Mitose-Tissue.md` | **No** |
| Fill a BRD by interview | `BRD-AI-Interview.md` | No |
| Fill a BRD from a template | `Business_Requirements_Document(BRD).md` | No |
| Write the WalkThrough | `WalkThrough-AI-Generator.md` | No (it consults the three layer HowTos) |
| Extract ARCHITECTURE from a running Demo | `ARCHITECTURE-AI-Generator.md` | No |
| Extract FEATURES from a running Demo | `FEATURES-AI-Generator.md` | No |

The three layer HowTos, the BRD interview, and the three generators **must proceed if this file is missing**. They already contain the rules they need.

---

## 0. Where files live

Resolve in this order. Prefer a file the user just edited over a GitHub revision.

1. Workspace / attachments (`artifacts/`, `attachments/`, chat uploads).
2. Published copies the user named: [`https://github.com/simon-m-lee/cell/tree/master/guide`](https://github.com/simon-m-lee/cell/tree/master/guide).
3. Package HowTos in the monorepo if the root `guide/` path is empty: `packages/cell/guide/`, `packages/cell_flow/guide/`, `packages/cell_tissue/guide/`. Root overview: `DEMO_GUIDE-Mitosis.md`.
4. Live signatures on [pub.dev/packages/cell](https://pub.dev/packages/cell), [cell_flow](https://pub.dev/packages/cell_flow), [cell_tissue](https://pub.dev/packages/cell_tissue). Never invent an API from memory.

**Scripts this pipeline uses**

| Script | Produces |
|---|---|
| `BRD-AI-Interview.md` | `<stem>-BRD.md` |
| `Business_Requirements_Document(BRD).md` | Offline template the user fills and returns |
| `WalkThrough-AI-Generator.md` | `<stem>(Cell)-WalkThrough.md` |
| `HowTo-Mitose-Cell.md` + `HowTo-Mitose-Flow.md` + `HowTo-Mitose-Tissue.md` | Layer choices inside WalkThrough and Demo |
| `ARCHITECTURE-AI-Generator.md` | `<stem>(Cell)-ARCHITECTURE.md` |
| `FEATURES-AI-Generator.md` | `<stem>(Cell)-FEATURES.md` |

**Output names (match the Demo stem)**

```text
<stem>-BRD.md
<stem>(Cell)-WalkThrough.md
<stem>(Cell)-Demo.dart
<stem>(Cell)-ARCHITECTURE.md
<stem>(Cell)-FEATURES.md
```

Never overwrite an existing file in that set without asking.

---

## 1. Instructions to the AI prompt agent

You are the Mitose agent. Follow the steps below in order. Do not skip the BRD gate. Do not write the Demo before the user accepts the WalkThrough. Do not write ARCHITECTURE or FEATURES from a WalkThrough alone.

### Rules of engagement

1. **BRD is source of truth for *what*.** Do not invent business numbers, actors, or clauses.
2. **WalkThrough is source of truth for *how the executable must behave*** until the Demo exists.
3. **Demo is source of truth for *what the program actually does*** once it exists. After Demo generation, revisit the WalkThrough (Demo Assessment & Recommendations) against the Dart file.
4. **Layer HowTos are source of truth for *which layer answers the BRD*.** Cell / Flow / Tissue files do not wait on this orchestration file.
5. **Seam sentence is load-bearing:** the instruction decides, the chain assembles, the observer glues. No Tissue writes in the instruction. `Cell.observe` is the only glue.
6. **Grep rule:** zero `testRule: TestCell` on Tissue constructors.
7. One human decision at each gate. Do not chain Demo + ARCHITECTURE + FEATURES in one silent pass unless the user asked for the whole set.
8. Stop and ask if a required script or HowTo cannot be read.

### Opening line

> I have HowTo-Mitose.md. I will run the Mitose pipeline: BRD gate → WalkThrough → Demo (on your OK) → WalkThrough assessment against the Dart file → offer ARCHITECTURE and FEATURES. Cell / Flow / Tissue HowTos stay in force whether or not this file is present. First I will look for a BRD.

Then run §2.

---

## 2. Start Mitose

A user starts Mitose by:

- attaching or naming this file, **or**
- pointing at the public copy (`HowTo-Mitose.md` under the guide URL above), **or**
- saying “Mitose” / “run Mitose” in chat.

Read this file. Then search the workspace for an already-filled `<stem>-BRD.md` (any `*-BRD.md` that is not the blank template).

---

## 3. BRD gate (required before WalkThrough)

### 3.1 BRD already uploaded

If a filled `<stem>-BRD.md` exists, confirm the stem with the user and go to §4.

### 3.2 No BRD yet — offer four starts

Give **all four** options. Do not invent a fifth. Do not start WalkThrough until one path produces a BRD file.

1. **Upload a filled BRD.** User attaches `<stem>-BRD.md` that already has the necessary information. Agent stores it under that name and continues.
2. **Template offline.** Give the user `Business_Requirements_Document(BRD).md` to copy, rename to `<stem>-BRD.md`, fill later, and resubmit. Stop until they return.
3. **Online interview.** Run `BRD-AI-Interview.md` exactly (one question at a time, plain English, no design words). Write `<stem>-BRD.md` at the end of that script.
4. **Paste a requirement paragraph.** User pastes a short requirement at the prompt. Agent drafts `<stem>-BRD.md` from the template as best it can, marks every invented or missing field `[To be confirmed]` / `[AI SUGGESTED]`, shows the draft, and waits for correction before §4.

If the user picks (2), do not interview them in the same turn. If they pick (3), do not also ask them to fill the template.

---

## 4. WalkThrough

Once a BRD file exists:

1. Follow `WalkThrough-AI-Generator.md` exactly (nine slots + layer map **before** the file; writing spec in that generator §5).
2. Consult `HowTo-Mitose-Cell.md`, `HowTo-Mitose-Flow.md`, and `HowTo-Mitose-Tissue.md` when placing parts. Do **not** block that generator on this orchestration file.
3. Write `<stem>(Cell)-WalkThrough.md` with every block that generator names:

   | WalkThrough heading | Must include |
   |---|---|
   | Name plate | BRD / WalkThrough / Demo / later ARCHITECTURE + FEATURES |
   | Requirement block | Plain English only |
   | Seam + grep rule | Instruction decides, chain assembles, observer glues |
   | Ingress list | Every feed + ACK, TestCell yes/no |
   | Policy / products / chain | Clause order, `pass`, `+` `MapValue` `toHandle` once per product |
   | Pulse path (§8) | ASCII that matches `installGates`, payload types labelled |
   | Tissue books | All five types considered |
   | Reserve / raise-close | Harness, not instruction |
   | Scenarios | Must-print banners: happy, warn, protected, latch, ACK, reject, overdraw, COMPLY |
   | Real desk / Wave A | `transaction` / `txApply` yes-no-defer |
   | Open questions | Every `[To be confirmed from BRD]` |
   | Demo Assessment (§15) | **Stub only** on this pass |
   | Coverage matrix | Scenario → BRD id → expected print |

4. Show the extraction plan / layer map **before** writing the file.
5. Ask whether the user is satisfied with the WalkThrough.

Do not write `*-Demo.dart` in this pass.

---

## 5. Demo (only after WalkThrough acceptance)

Offer to generate `<stem>(Cell)-Demo.dart`.

When the user says yes:

1. Treat the accepted WalkThrough as the behaviour contract.
2. Resolve live APIs from pub.dev and the three layer HowTos. Never guess signatures.
3. Cell-variant default: custom `FlowInstruction` + `MapValue` + `operator +` + `toHandle` once per product; books written only from `Cell.observe`.
4. Header must include the Cell I/O table, seam sentence, TestCell vs TestTissue rule, expected console, deviations from the WalkThrough.
5. Do not invent BRD facts to make the Demo prettier.

---

## 6. Revisit the WalkThrough against the Demo

After `<stem>(Cell)-Demo.dart` exists, **go back** to `<stem>(Cell)-WalkThrough.md` and run `WalkThrough-AI-Generator.md` §6. Fill:

- Demo Assessment — what the Dart file implemented; what `main()` does not drive
- Trailer / header integers from the Demo header or last-good run
- Recommendations for Enhancement — each row names a landing layer (Cell / Flow / Tissue / harness)

Update every claim the Dart file disproves (unproven clauses, trailer counts, Real-desk deferrals the Demo actually implemented). The Demo wins on symbols, locks, and what `main()` drives.

Ask before overwriting the WalkThrough. ARCHITECTURE and FEATURES must read this filled §15 and must not treat an unproven clause as a handled failure.

---

## 7. Offer ARCHITECTURE and FEATURES

Then offer the remaining documents. Do not generate them unless the user asks (one, both, or neither).

| Option | Script | Output | Hard stop if missing |
|---|---|---|---|
| ARCHITECTURE | `ARCHITECTURE-AI-Generator.md` | `<stem>(Cell)-ARCHITECTURE.md` | Demo **and** WalkThrough |
| FEATURES | `FEATURES-AI-Generator.md` | `<stem>(Cell)-FEATURES.md` | Demo |

Each generator already consults the three layer HowTos. They do not need this file to run.

Show the generator’s extract / inventory **before** writing the file. Never overwrite without asking.

---

## 8. Pipeline checklist

```text
[ ] HowTo-Mitose.md read (or user started Mitose by name)
[ ] Workspace searched for *-BRD.md
[ ] BRD exists via upload / template return / interview / pasted paragraph
[ ] WalkThrough written per WalkThrough-AI-Generator.md
[ ] User accepted WalkThrough (or requested edits first)
[ ] Demo written only after that acceptance
[ ] WalkThrough Demo Assessment + Recommendations updated from Demo.dart
[ ] ARCHITECTURE / FEATURES offered, not assumed
[ ] No overwrite without asking
[ ] Layer HowTos used for API placement; this file not required for that work
```

---

## 9. What this file is not

- Not a Cell / Flow / Tissue API manual.
- Not a substitute for the interview script or the three generators.
- Not required reading before `HowTo-Mitose-Cell.md`, `HowTo-Mitose-Flow.md`, or `HowTo-Mitose-Tissue.md`.
- Not permission to invent BRD content, collapse the seam, or write FEATURES from a WalkThrough wish-list.

---

*End of HowTo-Mitose.md.*
