# HowTo-Mitose-Cell.md

**Audience:** an AI prompt agent writing `<stem>(Cell)-Demo.dart` as part of the five-document Mitosis set.

**Package this file is about:** [`package:cell`](https://pub.dev/packages/cell) — the **core** layer of Mitosis (Cell / Flow / Tissue). Product codename **Mitosis**. **Mitose** is the German verb (to undergo mitosis) — not a misspelling. This file is the Cell-layer HowTo you *mitose* a BRD with.

**Job:** know *where the public API lives*, *which `Cell.*` factories a Demo must call*, and *which concerns must stay in `package:cell` rather than being folded into Flow or Tissue*.

This file is **self-contained for Cell-layer choices.** You do **not** need `HowTo-Mitose.md` to pick a factory. That file is orchestration only (BRD gate → WalkThrough → Demo → assessment → offer ARCHITECTURE / FEATURES). If it is missing, keep working from this file + pub.dev.

This file does **not** replace:

| File | Covers | Required to use this HowTo? |
|---|---|---|
| `HowTo-Mitose.md` | Pipeline order and BRD-start options | **No** |
| `WalkThrough-AI-Generator.md` | How to write the WalkThrough contract | No |
| `HowTo-Mitose-Flow.md` | Decision operators, `+`, `toHandle` | No (read when the decision is in play) |
| `HowTo-Mitose-Tissue.md` | Governed collections | No (read when books are in play) |
| pub.dev **cell** / **cell_flow** / **cell_tissue** | Live signatures | Yes, before inventing a signature |

Read **this** file when your hand is on `*-Demo.dart` or a WalkThrough layer map and you must choose a `Cell.*` factory.

---

## 0. Where to look (do this before inventing a signature)

Never guess a `Cell.*` signature. Resolve it from the published package.

| Look here | For |
|---|---|
| [pub.dev/packages/cell](https://pub.dev/packages/cell) | Install line, current version |
| [Cell class](https://pub.dev/documentation/cell/latest/cell/Cell-class.html) | Live signatures for `ingress`, `observe`, `state`, `transaction`, `txApply` |
| [Features topic](https://pub.dev/documentation/cell/latest/topics/Features-topic.html) | TestCell, transaction vs txApply |
| [Advanced topic](https://pub.dev/documentation/cell/latest/topics/Advanced-topic.html) | Context, Nucleus, Receptor, Synapses — **opt-in** |
| `packages/cell/guide/HowTo-Transaction.md` | `Cell.transaction` |
| `packages/cell/guide/HowTo-TransactionOnApply.md` | `Cell.txApply` |
| `packages/cell/guide/HowTo-TestCell.md` | Ingress / state validation |
| `packages/cell/guide/HowTo-Pulse.md` | `Pulse<T>` |
| `packages/cell/example/` | Small single-operator demos |
| Monorepo `example/*(Cell)-Demo.dart` | Full seam demos (card-auth, grid, ride-hail) |

**Import for a Cell-only sketch**

```dart
import 'package:cell/cell.dart';
```

**Import for a Cell-variant industry Demo** (this is the usual Demo file):

```dart
import 'package:cell_flow/cell_flow.dart';     // re-exports package:cell
import 'package:cell_flow/src/instruction/map.dart'; // MapValue when chaining
import 'package:cell_tissue/cell_tissue.dart';
```

Do **not** import `package:cell/src/...` internals. If `cell_flow` re-exports `Cell`, `Pulse`, `TestCell`, `IngressHandle`, use that.

Resolve versions with `dart pub add cell cell_flow cell_tissue` rather than pinning a stale rc from memory.

---

## 1. What `package:cell` owns in a Demo

Mitosis three-layer split (do not collapse it):

| Layer | Package | In the Demo it owns |
|---|---|---|
| **Cell** | `package:cell` | Graph nodes, `Pulse`, ingress, observe, TestCell on Cells, transactions, deputies at Cell level |
| **Flow** | `package:cell_flow` | `FlowInstruction` / `FlowInstructionBase`, `MapValue`, `operator +`, `toHandle` — the **decision** |
| **Tissue** | `package:cell_tissue` | `TissueList` / `Map` / `Set` / `Queue` / `Value`, TestTissue, `.unmodifiable` — the **books** |

The Cell-variant WalkThrough seam still holds:

> The instruction decides, the chain assembles, the observer glues.

`package:cell` is how work *enters* and how work *escapes* to a side effect. It is not where `riskOf` lives (that is the custom Flow instruction). It is not where `events.add` lives as a collection invariant (that is Tissue). `Cell.observe` is the **only** legal glue.

---

## 2. `Cell.*` factories this HowTo covers

Stream-shaped operators (`asyncMap`, `switchMap`, `debounce`, `distinct`, `fromFuture`, `fromStream`, and the rest of the Rx vocabulary) belong to **`package:cell_flow`**. Do not design a Demo from the Cell Core-16 list. Design it from ingress / observe / transaction / txApply, then compose the decision in Flow.

| Factory | Returns (typical) | Use in `*-Demo.dart`? | BRD trigger |
|---|---|---|---|
| **`Cell.ingress<I>`** | `IngressHandle<I>` | **Required.** Every external fact the BRD names (tag, stream, Hz, ACK). | “system shall capture…”, journeys, feeds |
| **`Cell.observe`** | `EgressHandle` | **Required.** Gate Cell → Tissue write. ACK ingress → `reset()` + close. | Alerts, ACK, audit, UI print |
| **`Cell.transaction`** | `TransactionScope` | When two retained **values** must commit together. | Money, occupancy+folio, multi-book commit |
| **`Cell.txApply`** | `ApplyTransactionScope` | When a **command** needs compensate / undo. | Devices, radio, issuer, PLC |
| `Cell.state<V>` | `StateHandle<V>` | Optional. Prefer `TissueValue` for a governed reserve. | Retained setting only if WalkThrough named no Tissue |
| `Cell.derive` | `Cell` | Pure projection. No policy branches if a custom instruction exists. | “show X derived from Y” |
| `Cell.synthesis` | `Cell` | Fan-in. Cell-variant Demos often assemble `*Tick` in Dart and emit `tickIn` instead. | “one screen from many feeds” |
| `Cell.sanitized` | `Cell` | Redact PII before a log Cell; also omit PII from Tissue rows. | GDPR, airline / ICB extract |
| `Cell.hub` | `HubHandle` | Route by `Pulse.type`. v1 usually uses two product lanes instead. | Many pulse types, one bus |
| `Cell.open` | `OpenCell` | Rare in v1. Late-bind a device after boot. | Hardware encoder after desk boots |

`Cell.governed` / `Cell.fromNucleus` are infrastructure. Use only when the WalkThrough names them.

---

## 3. Four factories the agent must not skip thinking about

Even if a given Demo does not call all four, you must **decide** each one against the BRD.

### 3.1 `Cell.ingress` — how the desk enters the graph

```dart
static IngressHandle<I> ingress<I>({
  TestCell testRule = TestCell.allowAll,
  // refine, ephemeralPolicy, source, context, receptor, synapses, forceLock
});
```

**When:** every identity / class / quantity / location / ACK the WalkThrough listed as an ingress.

**Considering factors**

| Question | Decision |
|---|---|
| Does the BRD reject bad records at source? (DR “reject missing tag / encounter”) | `testRule: TestCell<...>(...)` on **that** ingress |
| Is this a snapshot bus? | One `tickIn = Cell.ingress<DomainTick>()` plus `publishTick()` |
| Is this a human restore? | `ackIn = Cell.ingress<String>()` — observer calls `instruction.reset()`, never `toHandle` |
| Do I need TestCell on every field? | No. Only on fields the Demo will `emit` and that the BRD quality rule names. Dead ingresses that `publishTick` never calls are a documented deviation. |

**Typical Cell-variant harness**

```dart
encounterIn = Cell.ingress<String>(testRule: _encounterShape);
streamIn    = Cell.ingress<String>(testRule: _streamShape);
occupiedIn  = Cell.ingress<int>(testRule: _occupiedRange);
tickIn      = Cell.ingress<EdTick>();
ackIn       = Cell.ingress<String>();
```

Emit with `handle.emit(value)` (or the current IngressHandle API — confirm on pub.dev). `TestCell` returning `false` means the Demo must print `accepted=false` and **must not** grow Tissue.

**Do not** put `testRule: TestCell` on a Tissue constructor. That is the grep rule.

### 3.2 `Cell.observe` — the only Flow → Tissue glue

Docs show both `source:` and older `bind:` names. **Confirm the live signature** on the Cell class page. Industry Demos in the monorepo use:

```dart
Cell.observe(
  source: atRiskCell,          // a Cell, often handle.cell
  effect: (Pulse pulse) { ... },
);
```

**When:** a pulse has already been *decided* and a book must move.

**Considering factors**

| Question | Decision |
|---|---|
| What Cell do I subscribe to? | Gate Cell from `toHandle` (`atRiskCell`, `warnCell`) or `ackIn.cell` |
| What may the `effect` do? | Tissue writes, `raiseAlert` / `closeIncident`, enqueue pump, `instruction.reset()`, `print` |
| What must the `effect` **not** do? | Call `riskOf`, change `pass`, call `toHandle`, invent policy |
| Lifecycle? | Store the `EgressHandle`, call `stop()` / `dispose()` at the end of `main()` |

One observer per product lane plus one ACK observer is the Cell-variant default. Do not observe `tickIn` to make the decision — that bypasses the instruction.

### 3.3 `Cell.transaction` — atomic *value* writes

```dart
final tx = Cell.transaction(/* TransactionOptions? */);
await tx.begin([cellA, cellB]);
final a = tx.read(cellA);
tx.update(cellA, a - 50);
tx.update(cellB, tx.read(cellB) + 50);
await tx.commit();
// or rollback()
```

Some demos use the callback form:

```dart
await Cell.transaction((tx) async {
  occupied.update(true, tx: tx);
  folio.update(rateCents, tx: tx);
});
```

**When the BRD says two retained facts must move together or not at all** (hotel occupancy + folio; stand doors + chocks + status; two ledger legs).

**Considering factors**

| Question | Decision |
|---|---|
| Are the participants Cells with values? | `transaction` |
| Are they Tissue collections? | Prefer Tissue protocol (`raise` / `close` with compensation) unless the WalkThrough names a Cell.transaction across Cell-backed books |
| Can an observer see a half-write? | No — observers should see commit, not mid-tx |
| Isolation / timeout? | Only if the BRD or NFR names contention; otherwise defaults |

**Do not** wrap `riskOf` in a transaction. Policy is pure.

### 3.4 `Cell.txApply` — staged *commands* with compensate

```dart
final tx = Cell.txApply(/* TxApplyOptions? */);
await tx.begin([cell1]);
cell1.apply(
  (current) async { /* side effect; return new value */ },
  tx: tx,
  compensate: (issued) async { /* undo */; return null; },
);
await tx.commit();
```

**When the BRD names an external act that can fail after a local write** (key encode / void; push clearance / cancel; RTU shed / restore; issuer decline after hold).

**Considering factors**

| Question | Decision |
|---|---|
| Is the step a function with an undo, not a number? | `txApply` |
| v1 industry Demo already has `_driveAlert` retry-once? | That Dart list is a **stand-in**. Promote to `txApply` when the WalkThrough Wave A says the pump is a real device |
| Failure in the middle? | `compensate` on issued work; `stopOnFirstFailure` if options exist |

**Rule of thumb (from the Features topic):**  
`transaction` = coordinate **state**.  
`txApply` = coordinate **side-effecting functions** that need undo.

A Demo that only prints and mutates Tissue can defer both. A Demo whose BRD journey includes “encoder issued a key then the folio write failed” cannot.

---

## 4. Types the agent must name correctly

Look these up on pub.dev; do not invent parallel types.

| Type | Lives in | Demo use |
|---|---|---|
| `Cell` | cell | Node in the graph; `handle.cell` after `toHandle` |
| `Pulse<T>` | cell | Immutable signal; `pulse.payload`, `pulse.source`, `pulse.type` |
| `TestCell` | cell | `testRule:` on **ingress / state / toHandle** |
| `IngressHandle<I>` | cell | `.cell`, `.emit` |
| `EgressHandle` | cell | `.stop()` |
| `StateHandle<V>` | cell | `.cell`, `.update`, `.value` |
| `Context` / `DeputyContext` | cell | Opt-in; role deputies |
| `Receptor` / `Nucleus` / `Synapses` | cell | Flow’s `toHandle` builds a Receptor; application code should not hand-roll one |
| `FlowInstructionBase` | cell_flow | Custom instruction extends this |
| `MapValue` | cell_flow | Projection Decision → seam enum |
| `TissueList` / `Map` / `Set` / `Queue` / `Value` | cell_tissue | Books |
| `TestTissue` | cell_tissue | `testRule:` on Tissue **only** |

`TestCell` vs `TestTissue` is a typing rule, not a style choice. Swapping them is a failed acceptance grep.

---

## 5. From BRD sentence → `Cell.*` choice

| BRD phrase | First Cell factory | Then |
|---|---|---|
| “capture bag tag / encounter / Hz / stream” | `Cell.ingress` + TestCell | assemble `*Tick`, `tickIn.emit` |
| “reject missing id” | TestCell on that ingress | scenario 8 prints `accepted=false` |
| “show derived occupancy %” | field on Tick **or** `Cell.derive` | not a Tissue write |
| “flag at-risk when …” | **not** a Cell factory | custom `FlowInstruction` + `toHandle` |
| “record every alert” | `Cell.observe` on gate | `events.add` |
| “acknowledge and record action” | `Cell.ingress` ACK + `Cell.observe` | `reset()` + `closeIncident` |
| “room and folio together” | `Cell.transaction` | two `update`s, one `commit` |
| “encode key / request push / RTU” | `Cell.txApply` | `apply` + `compensate` |
| “no name on the airline extract” | omit field, and/or `Cell.sanitized` | deputy / unmodifiable Tissue |
| “120k events / day” | not a Cell factory | peak loop in `main()`, or a Flow operator if the WalkThrough says so |

If the WalkThrough already named the factory, obey the WalkThrough. If it did not, pick from this table and record the choice in the Demo header Cell I/O table.

---

## 6. Minimum Cell surface of a Cell-variant industry Demo

A Demo that follows `hospital_ed_capacity(Cell)-Demo.dart` / `grid-demand-response(Cell)-Demo.dart` **must** use:

```text
Cell.ingress     × N   (identity, class, quantity, tick bus, ack)
TestCell         on the quality-ruled ingresses
toHandle         (Flow) produces gate Cells
Cell.observe     × (products + ACK)
EgressHandle.stop / dispose
```

It **should** consider, and use when the BRD has the matching journey:

```text
Cell.transaction    multi-cell value commit
Cell.txApply        device / issuer / radio with compensate
Cell.sanitized      PII path
```

Feed adapters, chatter windows, and “latest only” are Flow concerns. Do not reach for Cell copies of those operators here.

It **must not** use Cell factories to hide Tissue:

- No `Cell.state` standing in for `TissueValue` when the WalkThrough named a reserve book.
- No observing an ingress to write the log “because observe is easier than a chain”.

---

## 7. Header contract the Demo must restate

Pub.dev readers land on the Example tab. The `*-Demo.dart` header must include a **Cell I/O table**:

```text
| Cell / handle     | Input parameter     | TestCell              | Emits              |
| tickIn            | EdTick snapshot     | (assembled)           | Pulse<EdTick>      |
| encounterIn       | String              | ED- prefix            | Pulse<String>      |
| ackIn             | String key / ALL    | non-empty optional    | Pulse<String>      |
| atRiskCell        | (from toHandle)     | —                     | Pulse<RiskLevel>   |
| observe(atRisk)   | Pulse<RiskLevel>    | —                     | side effect only   |
```

Plus: seam sentence, reserve invariant, TestCell vs TestTissue rule, expected console, deviations from the WalkThrough.

---

## 8. Anti-patterns specific to `package:cell`

- Inventing `Cell.gate`, `Cell.book`, `Cell.policy` — they do not exist.
- Putting `riskOf` in `Cell.observe` or in `evolve` of `Cell.state`.
- `Cell.transaction` around a single Tissue `add`.
- `Cell.txApply` with no `compensate` when the BRD journey has a failure path.
- `TestCell` on Tissue; `TestTissue` on ingress.
- Calling `toHandle` from an observer or from `reset()`.
- Leaving `Cell.observe` running after `main()` without `stop()`.
- Using `Cell.synthesis` *and* a custom instruction on the same tick without saying which one decides.
- Reading `tx.read` after `commit` and treating it as a live feed.
- Copying hotel `txApply` key-encoder code into a domain that has no encoder.

---

## 9. Checklist before you call the Demo done (Cell layer)

1. Every BRD feed / identity / ACK has an `Cell.ingress` **or** an explicit Real-desk deferral.
2. Quality DRs have `TestCell` on the ingress that `emit`s that field.
3. Every book write is reached only from `Cell.observe` (or from a harness method that observe called).
4. You decided **yes/no** on `transaction` and `txApply` against the BRD journeys, in the Demo header or WalkThrough Real desk.
5. `dart analyze` sees only public `package:cell` / `cell_flow` / `cell_tissue` imports.
6. Grep: zero `testRule: TestCell` on Tissue constructors.
7. Observers stopped at shutdown.

---

## 10. Reading order for the agent (Cell only)

1. This file (§2 table, §3 four factories, §5 BRD map).
2. [Cell class](https://pub.dev/documentation/cell/latest/cell/Cell-class.html) for the live signature you are about to type.
3. `HowTo-TestCell.md` / `HowTo-Transaction.md` / `HowTo-TransactionOnApply.md` if those factories are in play.
4. A sibling `*(Cell)-Demo.dart` in `example/` — copy structure, not nouns.
5. Then write `install()` ingresses and observers; leave `riskOf` in the Flow instruction.

---

*End of HowTo-Mitose-Cell.md.*
