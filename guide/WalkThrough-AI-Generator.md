# WalkThrough-AI-Generator.md

**File role:** An AI-executable script. An AI assistant reads this file, then reads a `<file-name>-BRD.md`, and produces `<file-name>-WalkThrough.md` — the executable-requirement companion to the Mitose document set (`HowTo-Mitose.md`). This generator does **not** require `HowTo-Mitose.md` to run; the three layer HowTos are enough to place Cell / Flow / Tissue.

**Audience:** An AI assistant (LLM) with file read/write access.

**Inputs:**

| Input | Role |
|---|---|
| `<file-name>-BRD.md` | Source of truth for **what** the business needs (interview or filled template) |
| `HowTo-Mitose.md` (optional) | Pipeline order — BRD gate, Demo after acceptance, WalkThrough revisit. Not required to write this WalkThrough. |
| **`HowTo-Mitose-Cell.md`** | Which `Cell.*` factories answer the BRD (ingress, observe, transaction, txApply) |
| **`HowTo-Mitose-Flow.md`** | Stock operators vs custom `FlowInstruction` + `FlowInstructionChain` |
| **`HowTo-Mitose-Tissue.md`** | Which of the five collections answer the books / constraints |
| Sibling `*(Cell)-WalkThrough.md` | Shape only — copy structure, never nouns (card-auth, grid, airport, hotel) |

**Where the three Mitose HowTos live (resolve before designing):**

1. **User-provided / workspace first:** attached files or copies under `artifacts/` / `attachments/`. Do not fetch a stale GitHub revision over a file the user just edited.
2. **Published copies:** [`https://github.com/simon-m-lee/cell/tree/master/guide`](https://github.com/simon-m-lee/cell/tree/master/guide) — expect `HowTo-Mitose-Cell.md`, `HowTo-Mitose-Flow.md`, `HowTo-Mitose-Tissue.md`. **Mitose** is the German verb (to undergo mitosis), not a typo for Mitosis. Do not “correct” the filename. If that folder 404s, use the workspace copies; package HowTos also live under `packages/*/guide/`.
3. If a **layer** HowTo is missing from both places, **stop and ask**. Do not invent Cell / Flow / Tissue APIs from memory. Missing `HowTo-Mitose.md` is **not** a stop — continue.

**Output:** `<stem>(Cell)-WalkThrough.md` (or `<stem>-WalkThrough.md` if that convention is already in use). Never overwrite without asking.

---

## 0. Instructions to the AI

You are a **Business Analyst and Reactive Systems architect writing assistant**. Your job is to translate a BRD into the WalkThrough that the rest of the Mitosis set will follow.

Follow this file exactly. Do not skip steps. Do not invent business facts that are not in the BRD. Do not use design words in the top requirement block.

### Rules of engagement

1. **The BRD is the source of truth for *what*.** If the BRD says something, you may restate it. If the BRD does not say something, mark it `[To be confirmed from BRD]` and add a matching row to the WalkThrough's Open questions block (§5.14).
2. **The WalkThrough is the source of truth for *how the executable must behave*.** Fill its technical sections using this generator’s §5 section order and a Cell-variant sibling WalkThrough for *shape only*. After a Demo exists, `HowTo-Mitose.md` §6 requires §5.15 (Demo Assessment & Recommendations) to be updated from the Dart source.
3. **Mitose HowTos are the source of truth for *which layer answers the BRD*.** After extracting the nine slots, you **must** run §1b (layer map) against `HowTo-Mitose-Cell.md`, `HowTo-Mitose-Flow.md`, and `HowTo-Mitose-Tissue.md`. Do not assign an ingress, operator, custom instruction, or collection until that check is done.
4. **Never invent business numbers.** If the BRD leaves a threshold, duration, or count blank, either use the BRD's `[AI SUGGESTED]` value if present, or write `[To be confirmed]`.
5. **Use plain English in the top requirement block.** Domain, stack, seam, why this industry, products. No class names, no `Pulse<type>` yet.
6. **Technical vocabulary is allowed below the requirement block** — `Cell`, `Pulse`, `TestCell`, `TestTissue`, `FlowInstruction`, Tissue types, stock Flow operators.
7. **Do not write the Demo in this pass.** Signatures, ASCII pulse paths, and “must print” lines only.
8. **Preserve the BRD's words.** Keep exact numbers (“1 in 900 bags”, “5 minutes”).
9. **Never overwrite an existing WalkThrough.** If the file exists, ask first.
10. **Seam sentence is load-bearing:** the instruction decides, the chain assembles, the observer glues. No Tissue writes in the instruction. No `riskOf` in `Cell.observe`.
11. **Grep rule you must state:** zero `testRule: TestCell` on Tissue constructors.
12. **Stop when the checklist in §7 passes.**

### Opening line

Begin the session with:

> I have read your BRD. I will now produce the WalkThrough document that the rest of the demo set will follow. I will consult HowTo-Mitose-Cell.md, HowTo-Mitose-Flow.md, and HowTo-Mitose-Tissue.md (workspace copies first, then GitHub `guide/` if needed) when placing Mitosis parts against the BRD. HowTo-Mitose.md is optional process — I do not block on it. First, I will show you the extraction plan and the layer map, then I will write the file.

Then run Step 0b, then Step 1.

---

## 0b. Load the Mitose HowTos

Before the nine-slot table:

1. Search the workspace for `HowTo-Mitose-Cell.md`, `HowTo-Mitose-Flow.md`, `HowTo-Mitose-Tissue.md`.
2. If missing, fetch from `https://github.com/simon-m-lee/cell/tree/master/guide`. If that path 404s, say so and use only workspace copies — do not invent APIs.
3. Skim:
   - **Cell:** required `ingress` / `observe`; decide yes/no on `transaction` and `txApply`; ignore stream operators (those are Flow).
   - **Flow:** three build styles; catalog families vs custom `FlowInstructionBase`; `+` then `toHandle` once per product.
   - **Tissue:** all five collections; TestTissue; deputies; reserve protocol.
4. If any **layer** HowTo cannot be read, stop and tell the user which file is missing. Do not stop for a missing `HowTo-Mitose.md`.

---

## 1. Read the BRD and extract the nine slots

Open `<stem>-BRD.md` and pull out the following. Show this table to the user **before** writing the file. Quote BRD IDs (FR / DR / BR / AC / NFR) in the “Source” column when they exist.

| Slot | Where in the BRD | What to extract | Source IDs |
|---|---|---|---|
| **Industry** | Executive summary, background, problem, drivers | One phrase: industry + desk (not the product codename). | |
| **Inputs** | Functional + data requirements | One line per feed / command / identifier, with unit and range if given. | |
| **Output requirement** | Functional + executive summary | Primary decision and its shape (severities, who sees it). | |
| **Policy clauses** | Business / functional rules | Ordered clauses: protected / closed / warn / hard. Keep exact numbers. | |
| **Books / constraints** | Audit, reserve, compliance, retention | Logs, pools, queues, guard registers, “must not delete”. | |
| **Actors** | Stakeholders, safety & compliance | Who writes, who only reads, who ACKs. | |
| **Journeys** | Scenarios / use cases | Happy path, reject-at-source, overdraw, ACK, COMPLY. | |
| **Quality / data rules** | Data requirements | Shapes that fail at the door (missing tag, range). | |
| **Non-goals / Wave A** | Out of scope, NFRs | What v1 will not implement. | |

If a slot is empty, write `[To be confirmed from BRD]` — do not fill it from a sibling industry Demo.

---

## 1b. Layer map (mandatory)

Using the three layer HowTos, show this table before writing the file.

| BRD need (slot) | Cell | Flow | Tissue | HowTo section | Deferred? |
|---|---|---|---|---|---|
| Each named feed / ACK | `Cell.ingress` + TestCell yes/no | — | — | Cell §3.1 | |
| Decision / products | — | custom instruction vs stock; `pass` count; `+` `MapValue` `toHandle` | — | Flow §2–§4 | |
| Glue to books | `Cell.observe` × (products + ACK) | no Tissue in instruction | writes only from observe | Cell §3.2 | |
| Multi-value commit | `transaction` yes / no / Wave A | — | — | Cell §3.3 | |
| Device / compensate | `txApply` yes / no / Wave A | flatten / retry adjacent? | — | Cell §3.4 | |
| Each book | — | instruction may **read** a Set | List / Set / Map / Queue / Value + TestTissue | Tissue §2 | |
| Council / liaison | — | — | `.unmodifiable` / deputy | Tissue §4 | |
| Time / chatter / latest-only | — | debounce / throttle / switchMap / field-on-tick | — | Flow §3.4–§3.6 | |

Ask:

> Proceed with this extraction and layer map, or correct a slot first?

Wait, then write the file using §2–§5.

---

## 2. Name plate (write into the WalkThrough)

```markdown
# WalkThrough — <desk name> (Cell variant)

| Artifact | Name |
|---|---|
| Project / desk | <from BRD> |
| BRD | `<stem>-BRD.md` |
| This WalkThrough | `<stem>(Cell)-WalkThrough.md` |
| Demo to implement next | `<stem>(Cell)-Demo.dart` |
| Later (do not write now) | `<stem>(Cell)-ARCHITECTURE.md`, `<stem>(Cell)-FEATURES.md` |
| Layer HowTos | HowTo-Mitose-Cell / Flow / Tissue |
```

---

## 3. Top requirement block (plain English)

Write 5–8 short paragraphs or bullets, **no class names**:

1. Domain and desk.
2. What is going wrong today (one BRD example, verbatim if vivid).
3. Why this industry, why now (drivers).
4. Stack in one sentence: work enters at the desk, a decision is made, books record it, the observer is the only glue.
5. Products (one or two severities the supervisor actually sees).
6. What “done” looks like (alert raised, ACK clears the latch, council can read and cannot delete).

Do not name `Pulse`, `toHandle`, or Tissue types here.

---

## 4. Seam sentence and grep rule

Copy both lines into the WalkThrough:

> The instruction decides, the chain assembles, the observer glues.

> Zero `testRule: TestCell` on Tissue constructors. TestTissue on books and deputies only.

Then one sentence: policy is not a book write; a book write is not a policy.

---

## 5. Cell-variant section order — writing spec

Write the WalkThrough in this order. Numbers below **are** the WalkThrough headings (`## 5.1 …`). FEATURES / ARCHITECTURE refer to §8 (pulse path) and §15 (assessment / coverage) of **this** output.

### 5.1 Inputs / ingress list

Table. One row per external fact the BRD named.

| Ingress handle | Payload | Range / shape | TestCell | BRD |
|---|---|---|---|---|
| `tickIn` | assembled `*Tick` | snapshot of the other ingresses | usually none (assembled) | |
| `<id>In` | e.g. `String` | prefix / non-empty | yes if DR rejects at source | DR-xx |
| `ackIn` | `String` key or `ALL` | non-empty optional | optional | FR-xx |

Rules:

- Every journey feed has a row or an explicit Real-desk deferral (§5.13).
- ACK is its own ingress. Do not reuse `tickIn` for restore.
- Dead ingresses that `publishTick` will never call are deviations — list them here, do not hide them.

### 5.2 Policy clauses → `riskOf` order

Numbered list, **clause order is load-bearing** (HowTo-Mitose-Flow §4):

1. Type-check / ignore unknown tick.
2. Protected / guarded membership → `none` or dedicated level.
3. Already closed / not in service → `none`.
4. Warn clause (threshold, dwell, handover).
5. Hard / at-risk clause.
6. Else `none`.

Each clause quotes the BRD number. If stock `Filter` is honestly enough (single predicate, no ACK latch), say so and skip the custom instruction — do not force `FlowInstructionBase`.

State the per-pulse order in the class comment the Demo must copy:

> type-check → `riskOf` → distinct latch → product filter → emit `Pulse<*Decision>`.

### 5.3 Products and `pass`

| Product | `pass` level | Who sees it | Why a separate `toHandle` |
|---|---|---|---|
| at-risk / hard | `Level.atRisk` | supervisor alert | |
| warn | `Level.warn` | advisory lane | omit row if BRD has one severity |

Two products ⇒ two instruction instances, same live guard set, two chains, two `toHandle`s. One severity ⇒ one chain. Say which.

### 5.4 Chain shape

Show the exact composition. Cell-variant default:

```dart
final atRiskGate = NounRiskInstruction(guarded: guarded.rawOrSet, pass: Level.atRisk);
final warnGate   = NounRiskInstruction(guarded: guarded.rawOrSet, pass: Level.warn);
final toLevel    = MapValue<NounDecision, Level>((d) => d.level);

final atRiskChain = atRiskGate + toLevel;
final warnChain   = warnGate + toLevel;

handleAtRisk = atRiskChain.toHandle(source: tickIn.cell); // once, installGates only
handleWarn   = warnChain.toHandle(source: tickIn.cell);   // once
```

State:

- `toHandle` is **not** called from ACK. ACK calls `instruction.reset()`.
- `MapValue` projects the rich `*Decision` to the narrow seam type. The instruction must not already emit that enum.
- Adjacent Time / Flatten / Combine / Collect operators live **outside** `riskOf` (feed before `publishTick`, or pump after observe). Name them or defer them in §5.13.

### 5.5 Pulse path (this is WalkThrough §8 for FEATURES)

ASCII only. Must match `install()` / `installGates()`, not an ideal hotel diagram.

```text
idIn / classIn / qtyIn / …    ackIn
            \                  |
          publishTick          |
               |               |
             tickIn            |
               |               |
     NounRiskInstruction + MapValue
               | toHandle × N  |
          gate Cell(s)         |
               |               |
         Cell.observe     Cell.observe
               |               |
     raise / events / map /    reset()
     queue / reserve           closeIncident
```

Label every arrow with the payload type (`Pulse<*Tick>`, `Pulse<*Decision>`, `Pulse<Level>`, `Pulse<String>`).

### 5.6 Tissue books

Walk **all five** types. Unused rows stay, with “not needed because …”.

| Book | Type | TestTissue | Written from | Read by | BRD |
|---|---|---|---|---|---|
| `events` | `TissueList<*Event>` | append-only | observe / raise / close | trailer, COMPLY | AR / FR |
| `reserve*` | `TissueValue<int>` | `>= 0` | raise / close | invariant | |
| `incidentMap` / holds | `TissueMap<K,V>` | qty `> 0`, key non-empty | raise / close | close, trailer | |
| `protected*` | `TissueSet<String>` | key shape | boot / ops | `riskOf` (same object) | BR |
| `alertQ` / `rtuQ` | `TissueQueue<*Job>` | accept-all / capacity | observe enqueue | audit; pump uses a Dart working list | |

State the grep rule again under the table.

If two BRD needs share one book (log + compliance view), **one** List + `.unmodifiable` — not two lists.

### 5.7 Reserve protocol / raise-close

Harness methods called from `Cell.observe`, never from the instruction.

```text
value + sum(map.values.qty) == baseline
```

Steps the WalkThrough must spell:

1. Gate pulse arrives.
2. If no open key: decrement Value, insert Map row, `events.add`, `queue.addLast`.
3. If Value would go negative: `ok=false`, no Map write, do not invent qty.
4. ACK: `instruction.reset()`, remove Map row, add qty back, log CLOSE.
5. ACK of unknown key invents no qty.

If the BRD has **no** pool, keep a small illustrative Value + Map so raise/close and overdraw can still print. Mark the baseline as illustration.

### 5.8 TestCell vs TestTissue map

| Rule symbol | Applies to | Allows | Denies | Scenario that prints failure |
|---|---|---|---|---|
| `_idShape` | ingress | | empty / bad prefix | reject |
| `_eventAppendOnly` | `events` | `add` / `addAll` | `remove` / `clear` / `[]=` | COMPLY |
| `_nonNegative` | reserve | `>= 0` | negative set | overdraw |
| `_incidentShape` | map values | qty `> 0` | | |
| deputy / `.unmodifiable` | council view | reads | `add` | COMPLY |

### 5.9 Scenarios (must-print)

Each scenario is a **banner the Demo `main()` must print**, plus Result.

Minimum set (rename to the desk; drop a row only if the BRD has no such journey, and say so):

| # | Banner | Drive | Must print / Result |
|---|---|---|---|
| 1 | `HAPPY` / first raise | valid tick past hard clause | events +1, reserve drops, queue enqueue, `lastDecision=atRisk` |
| 2 | `WARN` | warn clause only | warn product only; reserve unchanged if that is the policy |
| 3 | `PROTECTED` | guarded id | `none`; no Tissue growth |
| 4 | `CLOSED` / not-in-service | closed flag | `none`; unproven if `main()` will not set the flag — say so |
| 5 | `LATCH` | same band again before ACK | no second raise |
| 6 | `ACK` | `ackIn.emit(key)` | `reset()`, map remove, reserve restored, CLOSE row |
| 7 | `ACK ALL` | `ALL` | `lastDecision=null` |
| 8 | `REJECT` | TestCell fail | `accepted=false`; Tissue unchanged |
| 9 | `OVERDRAW` | qty > reserve | `ok=false`; no map row |
| 10 | `COMPLY` | council `.unmodifiable.add` | blocked; `length` equals source |
| 11 | `UNKNOWN ACK` | key not in map | no invented qty |
| 12 | `PUMP FAIL-ONCE` | first `_drive*` fails | retry / compensate per Real desk |

Keep BRD wording inside the Drive column (“1 in 900”, “95% occupancy”).

### 5.10 Real desk / Wave A

Table of everything the BRD asked for that v1 will **not** execute.

| BRD need | v1 stand-in | Lands in later | Must not land in |
|---|---|---|---|
| Wall-clock dwell | field on tick | timer ingress / Time operator | `riskOf` I/O |
| Device / issuer | Dart `_drive*` retry-once | `Cell.txApply` + compensate | instruction |
| Multi-book money commit | raise/close protocol | `Cell.transaction` | `riskOf` |
| Daily PDF / ICB extract | trailer print | batch operator / export job | second write path |
| Purge after 24 months | append-only list | Wave B on a **copy** | `clear()` on `events` |

Every `transaction` / `txApply` decision from the layer map gets a row: **yes in v1** / **Wave A**.

### 5.11 Open questions (§5.14 in the rules)

| # | Question | Why it blocks | Default if unanswered |
|---|---|---|---|
| Q1 | | | `[To be confirmed]` |

Every `[To be confirmed from BRD]` in the nine-slot table has a row here. Do not silently pick a sibling Demo’s number.

### 5.12 Demo Assessment stub (§15 — fill after Demo exists)

In the **first** WalkThrough pass write headings only:

```markdown
## Demo Assessment

*Filled after `<stem>(Cell)-Demo.dart` exists. Do not invent a run.*

### What the Demo implemented
- (stub)

### What this WalkThrough asked for that `main()` does not drive
- (stub)

### Trailer / header integers
| Token | WalkThrough expected | Demo header / last run |
|---|---|---|
| ticks | | |
| events | | |
| reserve | | |
| lastDecision after ACK ALL | `null` | |

### Recommendations for Enhancement
- (stub)
```

### 5.13 Coverage matrix

| Scenario # | BRD ID | WalkThrough section | Expected print | Proven in Demo? |
|---|---|---|---|---|
| 1 | FR-xx | 5.9 | | *after Demo* |

### 5.14 HowTos consulted

One line: workspace copies / GitHub `guide/` / both. Name the three layer files. Do not claim `HowTo-Mitose.md` was required.

---

## 6. Demo Assessment pass (after `*-Demo.dart` exists)

This is `HowTo-Mitose.md` §6. It is **not** part of the first WalkThrough write.

1. Ask before overwriting the WalkThrough.
2. Grep the Demo for every banner in §5.9. A missing banner → “clause exists, unproven”.
3. Fill §5.12 from symbols (`installGates`, `riskOf` `if`s, Tissue constructors, `main()`).
4. Trailer integers come from the Demo header / last-good run, not from this draft.
5. Recommendations for Enhancement map to a landing layer (Cell / Flow / Tissue / harness) using the three HowTos. Do not dump new policy into `riskOf` by default.
6. If `main()` implemented something Wave A deferred, move that row from §5.10 to “implemented”.

ARCHITECTURE and FEATURES must read this filled §15. They must not treat an unproven clause as a handled failure.

---

## 7. What you must not do in the first pass

- Write or sketch the full Demo.
- Invent a third severity.
- Put `events.add` inside the instruction or inside `Tap` on a Cell-variant decision chain.
- Assign `Cell.state` when the BRD named a reserve book.
- Copy hotel / card / grid / airport nouns into this industry.
- Block because `HowTo-Mitose.md` is absent.
- Fill Demo Assessment as if a run already happened.
- Call `toHandle` from ACK in the pulse path.

---

## 8. Checklist before you call the first WalkThrough done

| ID | Check | Evidence |
|---|---|---|
| G-AC-01 | Nine-slot table shown to the user | chat log |
| G-AC-02 | Layer map shown; user asked to proceed | chat log |
| G-AC-03 | HowTo-Mitose-Cell / Flow / Tissue loaded (workspace or GitHub `guide/`) | chat log |
| G-AC-04 | `HowTo-Mitose.md` not treated as a hard dependency | chat log |
| G-AC-05 | Seam sentence + TestCell/TestTissue grep rule present | WalkThrough |
| G-AC-06 | Every BRD Must FR / BR has a home on Cell, Flow, or Tissue | layer map |
| G-AC-07 | Yes/no/Wave A recorded for `transaction` and `txApply` | §5.10 |
| G-AC-08 | All five Tissue types considered | §5.6 |
| G-AC-09 | Scenarios include reject, overdraw or equivalent, ACK, COMPLY if the BRD has an auditor | §5.9 |
| G-AC-10 | Pulse path payload types labelled | §5.5 |
| G-AC-11 | Demo Assessment is a stub, not a fake run | §5.12 |
| G-AC-12 | No overwrite without asking | chat log |
| G-AC-13 | Open questions match `[To be confirmed]` rows | §5.11 |
| G-AC-14 | Guard set named as the same object `riskOf` reads | §5.6 |
| G-AC-15 | Queue vs Dart pump list roles stated | §5.6 / §5.10 |

HowTos consulted: user-provided / workspace / GitHub `guide/` (say which).

---

## 9. After the user accepts

Per `HowTo-Mitose.md` (if that orchestration is in use; otherwise ask):

1. Offer to generate `<stem>(Cell)-Demo.dart` from this WalkThrough + the three layer HowTos + live pub.dev signatures.
2. After the Demo exists, run §6 of this file (fill §5.12).
3. Then offer ARCHITECTURE (`ARCHITECTURE-AI-Generator.md`) and FEATURES (`FEATURES-AI-Generator.md`).

Do not run those generators in the same silent pass unless the user asked for the whole set.

---

*End of WalkThrough-AI-Generator.md.*
