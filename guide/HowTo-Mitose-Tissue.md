# HowTo-Mitose-Tissue.md

**Audience:** an AI prompt agent writing `<stem>(Cell)-Demo.dart` as part of the five-document Mitosis set.

**Package this file is about:** [`package:cell_tissue`](https://pub.dev/packages/cell_tissue) — the **application / books** layer (Tissue). Product codename **Mitosis**. **Mitose** is the German verb — not a misspelling. This file is the Tissue-layer HowTo you *mitose* a BRD with.

**Job:** know *where the Tissue public API lives*, *which of the five collections a BRD sentence maps to*, *how `TestTissue` and deputies work*, and *what must never migrate into the Flow instruction*.

This file is **self-contained for Tissue-layer choices.** You do **not** need `HowTo-Mitose.md` to pick a collection, TestTissue rule, or deputy. That file is orchestration only. If it is missing, keep working from this file + pub.dev.

This file does **not** replace:

| File | Covers | Required to use this HowTo? |
|---|---|---|
| `HowTo-Mitose.md` | Pipeline order and BRD-start options | **No** |
| `HowTo-Mitose-Cell.md` | Ingress, observe, transaction, txApply | No (read when placing glue) |
| `HowTo-Mitose-Flow.md` | Operators, custom instruction, `toHandle` | No |
| `WalkThrough-AI-Generator.md` | Reserve protocol wording, COMPLY scenario | No |
| pub.dev **cell_tissue** | Live factories | Yes, before inventing a collection |

Tissue **records**. Flow **decides**. `Cell.observe` is the only glue.

---

## 0. Where to look (do this before inventing a collection)

| Look here | For |
|---|---|
| [pub.dev/packages/cell_tissue](https://pub.dev/packages/cell_tissue) | Install, five types, TestTissue, deputies |
| Package README “The Five Collection Types” | When to pick List / Set / Map / Queue / Value |
| README “Validation” / “Read-Only Views” | Append-only pattern, `.unmodifiable`, `.deputy` |
| `packages/cell_tissue` guide / FEATURES (repo) | Events (`ElementAdded`, …), capacity, async mutations |
| Monorepo `example/grid-demand-response(Cell)-Demo.dart` | `events`, `reserveMw`, `shedMap`, `protected`, `rtuQ` |
| Monorepo `example/card-auth-pipeline(Cell)-Demo.dart` | Ledger + hold map + money invariant |

**Import**

```dart
import 'package:cell_tissue/cell_tissue.dart'; // often re-exports cell
```

```bash
dart pub add cell cell_flow cell_tissue
```

Do not import `package:cell_tissue/src/...`. Confirm factories on the resolved version: `TissueList()` is empty; **`TissueList.of(iterable)`** populates. `TissueSet` / `TissueQueue.of` / `TissueValue` take initial data on the main factory.

---

## 1. What Tissue owns in a Demo

| Layer | Owns | Does not own |
|---|---|---|
| Cell | Ingress, observe, TestCell | Collection invariants |
| Flow | `riskOf`, latch, `toHandle` | `events.add`, `bagCount.set` |
| **Tissue** | Five books, TestTissue, deputies, reserve protocol | Policy clauses |

Every Tissue is a Cell under the hood (same graph, own lock). Mutations emit collection pulses (`ElementAdded`, `ElementRemoved`, `ElementUpdated`). Application observers in a Cell-variant Demo still sit on the **gate Cell**, not on the Tissue, unless you are showing a second-order UI.

Grep rule:

> Zero `testRule: TestCell` on Tissue constructors. TestTissue on books and deputies only.

---

## 2. Examine all five collections against the BRD

Do not default everything to a `List`. Walk this table for every audit / reserve / queue / register the BRD names.

| Type | Backing | Use when the BRD needs | Typical Demo name | TestTissue sketch |
|---|---|---|---|---|
| **`TissueList<E>`** | `List<E>` | Ordered history; “record of every alert / action”; indexable log | `events` | Append-only: allow `add` / `addAll`, deny `remove` / `clear` / `[]=` |
| **`TissueSet<E>`** | `Set<E>` | Unique membership; guard / block / protected register | `protectedStreams`, `guardedFlights` | Key shape (flight id, stream id); uniqueness is free |
| **`TissueMap<K,V>`** | `Map<K,V>` | Open incidents / holds keyed by location, belt, stream, feeder | `incidentMap`, `shedMap` | Non-empty key; qty / MW `> 0` |
| **`TissueQueue<E>`** | `Queue<E>` | Outbound jobs, FIFO/LIFO, optional **capacity** / backpressure | `alertQ`, `rtuQ` | Accept-all unless the BRD rate-limits |
| **`TissueValue<V>`** | scalar | One governed number: reserve, available balance, occupancy pool | `trolleyCount`, `bagCount`, `reserveMw` | `value >= 0` |

### 2.1 `TissueList` — the audit book

**BRD triggers:** AR “incident log”, FR “record every alert and action”, retention “24 months” (v1 = append-only list, not a purge job).

```dart
events = TissueList<EdEvent>(testRule: _eventAppendOnly);
events.add(EdEvent(...));
final council = events.unmodifiable; // COMPLY
```

Considering factors:

| Question | Decision |
|---|---|
| Can compliance delete a row? | No → append-only TestTissue |
| Is order the story? | Yes → List, not Set |
| Daily report columns? | List is the source; roll-up is a harness **read**, not a second write path |
| Populate at boot? | `TissueList.of([...])` if you seed; else empty factory |

### 2.2 `TissueSet` — the guard register

**BRD triggers:** BR “diplomatic / hazardous never re-routed”, “resus never counted as spare”.

```dart
protectedStreams = TissueSet<String>(testRule: _streamRule);
protectedStreams.add('resus');
```

The live set is passed **into** the Flow instruction (`riskOf(tick, protected)`). Tissue stores membership; Flow reads it. Do not duplicate the set as a Dart `Set` that drifts.

Considering factors: uniqueness, key shape, who is allowed to `add` (ops vs deputy).

### 2.3 `TissueMap` — open work keyed by location

**BRD triggers:** FR “open incidents across terminals / streams”, “group by belt”.

```dart
incidentMap[key] = Incident(key: key, affectedQty: qty, inbound: inbound);
incidentMap.remove(key); // only from closeIncident
```

Considering factors:

| Question | Decision |
|---|---|
| One open row per belt/stream? | Map key = that id |
| Many bags, one cause? | Payload on `V`, not a new Map per bag (FR-08 often deferred) |
| Qty must stay positive? | TestTissue on `V` |

### 2.4 `TissueQueue` — outbound work

**BRD triggers:** FR “raise an alert to the supervisor”, RTU / issuer / radio jobs.

```dart
alertQ.addLast(job);          // audit enqueue
_alertWork.add(job);          // Dart working list the pump drains
```

WalkThrough convention: TissueQueue is the **audit enqueue**; a Dart list + `_driveAlert` / `_driveRtu` is the retry-once pump. Do not drain the TissueQueue as the only working list if you still need the queue as history.

Considering factors: `capacity` when NFR names backpressure; `addFirst` vs `addLast`; accept-all TestTissue unless the BRD says drop-when-full.

### 2.5 `TissueValue` — the reserve scalar

**BRD triggers:** “45,000 departing bags”, “42 majors spaces”, “800 MW spinning reserve”, ledger cents.

```dart
trolleyCount = TissueValue<int>(initial: 42, testRule: _nonNegative);
trolleyCount.set(before - qty);
```

Considering factors:

| Question | Decision |
|---|---|
| Is there a conservation invariant? | `value + sum(map.values.qty) == baseline` |
| Can it go negative? | TestTissue `>= 0` **and** harness pre-check (document which banner proves which) |
| Is it a setting, not a pool? | Still TissueValue if the WalkThrough named a book; else `Cell.state` (Cell HowTo) |

---

## 3. `TestTissue` — considering factors

```dart
TestTissue<E, C>(
  (value, {host, arguments, user}) { ... },
);
```

| Need | How |
|---|---|
| Allow everything | `TestTissue.allowAll` (default) |
| Freeze a deputy | `TestTissue.readOnly` |
| Append-only log | Inspect `arguments` function `toString()` for `remove` / `clear` / `[]=` |
| Non-negative reserve | `value is int && value >= 0` |
| Incident shape | `value is Incident && qty > 0 && key.isNotEmpty` |
| Compose two rules | `ruleA + ruleB` |

Returning `false` rejects the mutation. The Demo must print that failure (`ok=false`) when the scenario is “overdraw”.

**Do not swap with TestCell.** They are not subtypes.

---

## 4. Deputies and `.unmodifiable`

**BRD triggers:** Safety & Compliance, Caldicott, CAA, reliability council, ICB liaison who must **read** and must **not** delete.

```dart
final council = events.unmodifiable;
council.add(...); // blocked — COMPLY scenario
```

| API | Use |
|---|---|
| `.unmodifiable` | Zero-copy read-only view; COMPLY default |
| `.deputy(testRule: …)` | Narrower write set (ops may add, liaison may not) |

Considering factors:

- Views may be live or snapshot depending on package build — verify the docstring.
- Recursive unmodifiable on Cell elements if the list holds Cells.
- COMPLY must prove `add` blocked and `length` equals the source (or document the blocked heuristic the Demo uses).
- A daily PDF is **not** `.unmodifiable`. Roll-up is a harness method that *reads* Tissue.

---

## 5. Reserve protocol (Value + Map) — harness, not instruction

When the BRD has a countable pool:

```text
trolleyCount.value! + sum(incidentMap.values.affectedQty) == baseline
```

`raiseAlert` / `closeIncident` (domain-renamed) are **harness methods** called from `Cell.observe`:

1. Gate pulse arrives.
2. If no open key: decrement Value, insert Map row, `events.add`, `queue.addLast`.
3. If Value would go negative: `ok=false`, no Map write, do not invent qty.
4. ACK: `instruction.reset()`, remove Map row, add qty back, log CLOSE.
5. ACK of unknown key invents no qty.

Instruction never reads or writes the reserve.

If the BRD has **no** pool, still keep a small Value + Map so raise/close and overdraw can be demonstrated (hall invariant). Mark the baseline as illustration.

---

## 6. BRD sentence → Tissue choice

| BRD phrase | Tissue |
|---|---|
| “record of every alert and action” | `TissueList` + append-only |
| “retain incidents 24 months” | same list; purge is Wave B on a **copy** |
| “protected / diplomatic / resus” | `TissueSet` fed to `riskOf` |
| “open incidents by belt / stream / feeder” | `TissueMap` |
| “group alerts by cause” | Map payload or deferred; not a second List |
| “alert the supervisor / RTU / issuer” | `TissueQueue` + pump list |
| “45,000 bags / 42 trolleys / 800 MW / ledger” | `TissueValue` + invariant |
| “council reads, cannot delete” | `.unmodifiable` + COMPLY |
| “liaison sees roll-up only” | deputy + harness print; not a new collection of PII |
| “export spreadsheet” | out of Demo; Could |

If two BRD needs share one book (log + compliance view), **one** List + a deputy — do not keep two lists.

---

## 7. Types the agent must name

| Type | Role |
|---|---|
| `TissueList<E>` / `Set<E>` / `Map<K,V>` / `Queue<E>` / `Value<V>` | Five books |
| `TestTissue<E, C>` | Mutation rule |
| Collection pulses (`ElementAdded`, …) | Optional second-order observe |
| `.unmodifiable` / `.deputy` | Role surfaces |
| Domain rows: `*Event`, `Incident` / `Hold` / `Shed`, `AlertJob` / `RtuJob` | Payloads — no PII if BR-04 |

---

## 8. Minimum Tissue surface of a Cell-variant industry Demo

```text
TissueList<Event>     events        append-only + unmodifiable
TissueValue<int>      reserve       >= 0
TissueMap<String, V>  open holds    qty > 0
TissueSet<String>     guard keys    shape rule
TissueQueue<Job>      outbound      accept-all / capacity
```

Writes happen only from observers / harness raise-close. `main()` COMPLY uses the deputy. Trailer prints lengths and reserve.

---

## 9. Anti-patterns

- `testRule: TestCell` on a Tissue constructor.
- `events.add` inside `riskOf` or inside the instruction.
- A Dart `List` as the system of record when the WalkThrough named Tissue.
- Draining `TissueQueue` so COMPLY cannot see enqueue history.
- Two lists “for compliance” instead of `.unmodifiable`.
- Negative reserve proved only by a harness `if` while claiming TestTissue was tested.
- Putting passenger name / NHS number on `Event`.
- Closing BRD open questions by inventing a sixth collection type (`TissueGraph`, etc.).
- `Cell.transaction` around a single `add` (Cell HowTo).

---

## 10. Checklist (Tissue layer)

1. All five types were considered; unused ones are named as “not needed because …”.
2. Each constructed Tissue has `TestTissue` (or documented `allowAll`).
3. Append-only log + COMPLY deputy exist if the BRD has an auditor.
4. Reserve invariant is stated when the BRD has a baseline number.
5. Guard set is the same object the instruction reads.
6. Queue vs Dart pump list roles are stated.
7. Grep: no TestCell on Tissue.
8. Trailer counts match the Demo header after the first run.

---

## 11. Reading order for the agent (Tissue only)

1. This file (§2 five types, §3 TestTissue, §5 reserve).
2. [pub.dev/packages/cell_tissue](https://pub.dev/packages/cell_tissue) README factories.
3. Grid or card-auth Cell Demo Tissue block.
4. Then construct books in `install()`; write them only from `Cell.observe`.

---

*End of HowTo-Mitose-Tissue.md.*
