# HowTo-Mitose-Flow.md



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

**Audience:** an AI prompt agent writing `<stem>-Demo.dart` as part of the five-document Mitosis set.

**Package this file is about:** [`package:cell_flow`](https://pub.dev/packages/cell_flow) — the **orchestration** layer (Flow). Product codename **Mitosis**. **Mitose** is the German verb — not a misspelling. This file is the Flow-layer HowTo you *mitose* a BRD with.

**Job:** know *where the Flow public API lives*, *when a stock operator is enough*, *when the BRD forces a custom `FlowInstruction`*, and *how to assemble a `FlowInstructionChain` that `toHandle` turns into a Cell*.

This file is **self-contained for Flow-layer choices.** You do **not** need `HowTo-Mitose.md` to pick an operator or a custom instruction. That file is orchestration only. If it is missing, keep working from this file + pub.dev + `FEATURES-Flow.md`.

This file does **not** replace:

| File | Covers | Required to use this HowTo? |
|---|---|---|
| `HowTo-Mitose.md` | Pipeline order and BRD-start options | **No** |
| `HowTo-Mitose-Cell.md` | `Cell.ingress` / `observe` / `transaction` / `txApply` | No (read when placing glue) |
| `HowTo-Mitose-Tissue.md` | Books | No |
| `WalkThrough-AI-Generator.md` | Scenario spine, two products | No |
| pub.dev **cell_flow** / repo `FEATURES-Flow.md` | Live catalog | Yes, before inventing an operator name |

Flow **decides which pulses leave and when**. It does not write Tissue. It does not replace `Cell.ingress`.

---

## 0. Where to look (this directory first)

Sibling scripts live in this file's directory. Read `HowTo-Mitose-Cell.md`, `HowTo-Mitose-Flow.md`, and `HowTo-Mitose-Tissue.md` from here before pub.dev or GitHub. Demo and document names have no `(Cell)` suffix: `<stem>-Demo.dart`, `<stem>-WalkThrough.md`, `<stem>-ARCHITECTURE.md`, `<stem>-FEATURES.md`. Live signatures still come from pub.dev. Never invent one.

## 0. Where to look (do this before inventing an operator name)

| Look here | For |
|---|---|
| [pub.dev/packages/cell_flow](https://pub.dev/packages/cell_flow) | Install, README catalog (~79+ operators) |
| `packages/cell_flow/FEATURES-Flow.md` | Full catalog by family |
| `packages/cell_flow/ARCHITECTURE-Flow.md` | Why `+` is one Receptor / one lock |
| `packages/cell_flow/guide/HowTo-Start.md` | 15-minute tutorial |
| `packages/cell_flow/guide/HowTo-Fluent_Operator.md` | Fluent vs `+` |
| `packages/cell_flow/guide/HowTo-FlowInstruction-Receptor.md` | `toHandle`, `Receptor.instruction` |
| `packages/cell_flow/lib/src/instruction/` | One file per stock instruction (`map.dart`, `filter.dart`, `distinct.dart`, `async_map.dart`, …) |
| `packages/cell_flow/lib/src/instruction/async_map.dart` | **Template** for a custom `FlowInstructionBase` |
| Monorepo `example/grid-demand-response-Demo.dart` | Custom instruction + `MapValue` + two `toHandle` |
| Monorepo `example/card-auth-pipeline-Demo.dart` | Stock chain `MapValue + Distinct + Filter + Tap + MapValue` |

**Import**

```dart
import 'package:cell_flow/cell_flow.dart'; // re-exports package:cell
import 'package:cell_flow/src/instruction/map.dart'; // MapValue class, if not exported
```

Application code should prefer `package:cell_flow/cell_flow.dart`. Confirm whether `MapValue` / `Filter` / `Distinct` are exported or need the `src/instruction/` import on the version you resolved.

```bash
dart pub add cell cell_flow cell_tissue
```

---

## 1. What Flow owns in a Demo

| Layer | Owns | Does not own |
|---|---|---|
| Cell | Ingress, observe, TestCell, transaction | Policy clauses |
| **Flow** | `riskOf` / stock operators, latch, product filter, chain, `toHandle` | `events.add`, reserve `set` |
| Tissue | Books | Decision |

Seam sentence:

> The instruction decides, the chain assembles, the observer glues.

`toHandle(source: tickIn.cell)` is called **once per product**, only in `installGates()`. ACK calls `instruction.reset()`, never `toHandle`.

---

## 2. Three ways to build a pipeline — pick on purpose

| Way | Shape | Cells / locks | Use in industry Demo |
|---|---|---|---|
| 1. `Flow.*` static factories | `Flow.filter(cell, test: …)` | New Cell per step | Multi-source (`zip`, `combineLatest`, `merge`) |
| 2. Fluent | `cell.filter().debounce().asyncMapLatest()` | New Cell per step | Linear feed adapters, search boxes |
| 3. **`operator +` + `toHandle`** | `instrA + instrB` → `FlowInstructionChain` | **One Receptor, one lock** | **Default for Cell-variant policy gates** |

Cell-variant WalkThroughs require way 3 for the **decision**. Ways 1–2 are legal for *adjacent* feed shaping (debounce the belt tick *before* `publishTick`), not a substitute for the custom instruction when the BRD has a named policy.

Key difference from the README: **`+` shares one lock**. Fluent `filter().map()` is two cells. Do not mix “I thought Distinct lived inside the instruction” with a fluent `.distinct()` on the same product unless the WalkThrough says so.

---

## 3. Examine the catalog against the BRD

Before writing a custom instruction, walk the families. Use a stock operator when the BRD sentence is *exactly* that operator. Write a custom instruction when several clauses + a resettable latch + a product filter must share one Receptor.

### 3.1 Create

`of`, `fromIterable`, `fromFuture`, `fromStream`, `range`

| BRD / journey | Operator |
|---|---|
| Replay a fixture list of ticks | `fromIterable` / `of` |
| One AODB lookup | `fromFuture` |
| Belt PLC is already a Dart `Stream` | `fromStream` |

v1 industry Demos usually **`tickIn.emit`** from the harness instead of Create operators.

### 3.2 Transform

`map` / `MapValue`, `mapTo`, `pluck`, `scan`, `pairwise`

| BRD | Operator |
|---|---|
| Project `Decision` → seam enum | **`MapValue<Decision, Level>`** — required on the Cell-variant chain |
| Running total | `scan` |
| “previous vs this occupancy” | `pairwise` |

`MapValue` is the stock projection that must **not** live inside the custom instruction. The instruction emits the rich `*Decision`; `MapValue` narrows it.

### 3.3 Filter / take / skip

`filter` / `Filter`, `distinct` / `Distinct` / `DistinctUntilChanged`, `take`, `skip`

| BRD | Operator |
|---|---|
| Drop `none` / keep only `atRisk` | `Filter` **or** the custom instruction’s `pass` |
| Do not flood the log on a 15 s feed | `Distinct` **or** the custom instruction latch + `reset()` |
| First N alerts only | `take` — rare; usually a book concern |

If the BRD needs **ACK to clear the latch**, stock `Distinct` is the wrong tool (no `reset()`). That is the usual reason for `FlowInstructionBase`.

### 3.4 Flatten (inner sequences)

| Operator | Policy | BRD trigger |
|---|---|---|
| `concatMap` | Queue inners | Order of issuer calls matters |
| `mergeMap` | Overlap | Parallel CAD lookups OK |
| `switchMap` / `asyncMapLatest` | Cancel previous | Latest search / latest flight on stand |
| `exhaustMap` | Ignore while busy | ACK / checkout double-tap |

Do not put flatten *inside* `riskOf`. Flatten wraps I/O after or beside the decision.

### 3.5 Combine

`mergeWith`, `zipWith`, `combineLatestWith`, `withLatestFrom`, `race`

| BRD | Operator |
|---|---|
| “one screen from occupancy + inbound + boarded” | `combineLatest` **or** assemble `*Tick` in the harness |
| Price tick uses latest currency | `withLatestFrom` (waits until every other cell has a value) |
| First feed that answers | `race` |

Cell-variant Demos often assemble the Tick in Dart. Say so in Real desk if you skip Combine operators.

### 3.6 Time

`delay`, `debounce`, `throttle`, `sample` / `sampleTime`, `timeout`

| BRD | Operator |
|---|---|
| Belt chatter / 15 s snapshots | `debounce` |
| Supervisor mash on ACK | `throttle` / `exhaustMap` |
| “raise if stopped > 60 s” | **field on the tick** in v1, or `timeout` / a timer ingress in Wave A |
| “ACK within 15 minutes” | not a v1 operator — Real desk / clock |

Do not fake a wall clock with `minRemaining` and then claim Time operators.

### 3.7 Collect / control

`bufferCount`, `bufferTime`, `bufferWithTimeAndCount`, `groupBy`, `startWith`, `retry`, `tap` / `Tap`

| BRD | Operator |
|---|---|
| Flush 50 events or 5 s | `bufferWithTimeAndCount` |
| Group bag alerts by belt (FR-08) | `groupBy` **or** TissueMap key (WalkThrough often chooses the map) |
| Flaky RTU / issuer | `retry` **or** harness `_driveAlert` retry-once |
| Book write inside the chain | `Tap` — **Tissue-sibling / card-auth stock chain only**. Cell-variant WalkThrough forbids Tissue writes in the instruction; keep Tap off the decision chain.

---

## 4. When the BRD requires a custom `FlowInstruction`

Write `class <Noun>RiskInstruction extends FlowInstructionBase<Cell, Pulse, Pulse>` when **all** of these are true:

1. Policy is **clause-ordered** (protected / closed / warn / hard) — not a single predicate.
2. Two (or more) **products** share the same policy but different `pass`.
3. The desk **ACK must clear a latch** (`reset()`), which stock Distinct cannot do.
4. The instruction must emit a **rich** `*Decision` (tick + level), not the narrow enum.

Imitate `AsyncMap` in `async_map.dart` and `GridDecisionInstruction` in the grid Cell Demo.

**Per-pulse order (copy into the WalkThrough and the class comment):**

> type-check → `riskOf` → distinct latch → product filter → emit `Pulse<Decision>`.

**Public API the Demo must expose**

| Member | Role |
|---|---|
| `static Level riskOf(Tick, Set<String>)` | Pure policy; unit-testable |
| `Level? lastDecision` | Latch for the trailer |
| `Level get pass` | Product this instance lets through |
| `Set<String> get guarded…` | Live set the policy reads |
| `void reset()` | ACK observer only |

Constructor takes the live guard set + `required pass`. It does **not** take TestCell or TestTissue.

**Chain (mandatory Cell-variant shape)**

```dart
final atRiskGate = NounRiskInstruction(guarded: guarded.rawOrSet, pass: Level.atRisk);
final warnGate   = NounRiskInstruction(guarded: guarded.rawOrSet, pass: Level.warn);
final toLevel    = MapValue<NounDecision, Level>((d) => d.level);

final atRiskChain = atRiskGate + toLevel;
final warnChain   = warnGate + toLevel;

handleAtRisk = atRiskChain.toHandle(source: tickIn.cell); // once
handleWarn   = warnChain.toHandle(source: tickIn.cell);   // once
```

If the BRD has **one** severity, one chain. Say so.

---

## 5. Mix-and-match rules

| Allowed | Forbidden |
|---|---|
| Custom instruction `+` stock `MapValue` | Custom instruction that already emits the narrow enum |
| Stock `MapValue + Distinct + Filter` when ACK need not reset (card-auth style) | `Tap` that writes Tissue on a Cell-variant decision chain |
| Fluent debounce on the **feed** before `publishTick` | Fluent `.distinct()` *and* an instruction latch on the same product without saying why |
| `retry` / `exhaustMap` on the **outbound pump Cell** | `retry` inside `riskOf` |
| Two instruction instances, two chains | Second `toHandle` on ACK |

Decision procedure:

1. Mine BRD Must FRs + BRs for policy clauses → `riskOf` or stock `Filter`.
2. If ACK must reopen the same band → custom latch + `reset`.
3. If two severities → two `pass` instances.
4. Walk Time / Flatten / Combine / Collect families for *adjacent* journeys (jam clock, double-ACK, batch report). Place those **outside** `riskOf`.
5. Materialise with `toHandle` once per product.

---

## 6. Types the agent must name

| Type | Package | Role |
|---|---|---|
| `FlowInstruction` / `FlowInstructionBase<Cell, Pulse, Pulse>` | cell_flow | Blueprint |
| `FlowInstructionChain` | cell_flow | Result of `+` |
| `FlowHandle` | cell_flow | Result of `toHandle`; `.cell` is the gate |
| `MapValue<I, O>` | cell_flow | Projection |
| `Filter`, `Distinct` / `DistinctUntilChanged`, `Tap` | cell_flow | Stock sync ops |
| `Receptor.instruction` | cell | What `toHandle` wraps; tests can call it without a graph |

Confirm class names on the resolved version (`Distinct` vs `DistinctUntilChanged`).

---

## 7. BRD sentence → Flow choice (cheat sheet)

| BRD phrase | Flow construct |
|---|---|
| “flag at-risk when remaining < MCT / occ ≥ 95%” | `riskOf` hard clause |
| “diplomatic / resus never …” | first clause + live `TissueSet` |
| “no alert after close” | `alreadyClosed` → `none` |
| “warn if stopped > 60 s / handover > 15 min” | warn clause **or** Time operator + field |
| “do not flood the supervisor” | latch / Distinct + ACK `reset` |
| “group alerts by cause” | `groupBy` or TissueMap key |
| “latest reservation / flight only” | `switchMap` |
| “prevent double checkout / double ACK” | `exhaustMap` |
| “retry flaky RTU” | `retry` or harness pump |
| “batch the ICB extract” | `bufferTime` / `bufferCount` |
| “combine occupancy and inbound on one screen” | `combineLatest` or harness Tick |

---

## 8. Anti-patterns

- Designing from memory without opening `FEATURES-Flow.md`.
- Folding `events.add` into the instruction or into `Tap` on a Cell-variant gate.
- Putting `riskOf` in `Cell.observe`.
- Fluent chain for the policy when the WalkThrough demanded one custom instruction + `+`.
- Stock Distinct when the journey needs `reset()`.
- One `toHandle` for two severities (or two when the BRD has one — unless stated).
- Calling `toHandle` from ACK.
- Using Time operators and then also claiming the tick field *is* the clock.
- Copying `AsyncMap`’s async guts into a sync policy instruction.

---

## 9. Checklist (Flow layer)

1. Catalog families were walked against Must FRs / BRs / journeys.
2. Custom instruction exists **iff** policy + latch + `reset` + product filter belong together.
3. `+` then `toHandle` once per product, only in `installGates`.
4. `MapValue` projects rich Decision → narrow seam type.
5. No Tissue write in the instruction.
6. Adjacent Time / Flatten / Combine / Collect needs are either in the graph **or** deferred in Real desk.
7. Trailer can read `lastDecision` after ACK ALL (`null`).

---

## 10. Reading order for the agent (Flow only)

1. This file (§2 ways, §3 families, §4 custom instruction).
2. `FEATURES-Flow.md` for the operator you are about to type.
3. `async_map.dart` + grid Cell Demo if you need `FlowInstructionBase`.
4. `HowTo-FlowInstruction-Receptor.md` for `toHandle`.
5. Then write `installGates()`; keep books in observers (`HowTo-Mitose-Cell.md` + Tissue HowTo).

---

*End of HowTo-Mitose-Flow.md.*
