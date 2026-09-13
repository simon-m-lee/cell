# Walkthrough requirement — NL instruction → TissueSet (Flow + Tissue)

**Demo:** `nl-instruction-tissue-set-Demo.dart` (executable; this file is its requirement)
**Siblings:**
- `ride-hail-dispatch(tissue)-WalkThrough.md` — mobility books
- `card-auth-pipeline(tissue)-WalkThrough.md` — payments books
- `grid-demand-response(tissue)-WalkThrough.md` — energy books
- `ICU-alarm-pipeline(enhanced)-Demo.dart` — clinical PAGE/WARN

**Industry:** natural-language command surface for a reactive set
(the product everyone knows as a chatbot driving an in-memory
collection — the operator writes an English sentence, a model
chooses a verb from a closed list, the framework executes the verb
against a governed `TissueSet<int>`)
**Stack:** `package:cell` + `package:cell_flow` + `package:cell_tissue`

This is the **executable requirement** for a demo that uses
**Flow for the natural-language interpretation** and **Tissue for
the membership set**. Implement the Dart file so a last-good run
prints the scenario table in § Scenarios.

Do not fold Tissue into the interpreter. Do not fold the
interpreter into the dispatch instruction. The point of this file
is the seam.

Why this industry: a natural-language command surface is a
string bus (a sentence from an operator) plus a closed verb list
(a model chooses one verb) plus a governed set (the mutation is
validated and observable). That is the same shape as ride-hail
dispatch, with a sentence instead of a `MatchTick` and a
`TissueSet<int>` instead of a `TissueList<TripEntry>`.

---

## Contents

1. [TestCell vs TestTissue (do not swap)](#testcell-vs-testtissue-do-not-swap)
2. [Why Flow + Tissue (not a hand-rolled parser)](#why-flow--tissue-not-a-hand-rolled-parser)
3. [Design](#design)
4. [Domain](#domain)
5. [Parts](#parts)
  - [Flow Cells](#flow-cells)
  - [Tissue collections](#tissue-collections)
  - [Deputies](#deputies)
  - [Instruction](#instruction)
  - [Receptor](#receptor)
  - [Operators the demo must actually call](#operators-the-demo-must-actually-call)
6. [Dispatch — pure instruction, not a Tissue mutation](#dispatch--pure-instruction-not-a-tissue-mutation)
7. [Implementation map](#implementation-map)
8. [Scenarios](#scenarios)
9. [Executable steps](#executable-steps)
10. [Pulse path (scenario 6 then 7)](#pulse-path-scenario-6-then-7)
11. [Who owns the lock](#who-owns-the-lock)
12. [Real product vs this file](#real-product-vs-this-file)
13. [Acceptance](#acceptance)
14. [Documented deviations (summary)](#documented-deviations-summary)
15. [Name plate](#name-plate)

---

## TestCell vs TestTissue (do not swap)

Collection classes in `package:cell_tissue` take **`TestTissue`**,
never `TestCell`. `TestCell` is the integrity rule on a **Cell**
(ingress / handle). `TestTissue` is the integrity rule on a
**Tissue** (`add`, `remove`, `[]=`, value write). They are not
subtypes you can pass across that seam.

| Host | Rule type | Parameter | Typical use in this demo |
|---|---|---|---|
| `Cell.ingress` / `toHandle` | `TestCell` | `testRule:` | sentence shape: non-empty, ≤ 200 chars |
| `TissueSet<int>` | `TestTissue<int, TissueSet<int>>` | `testRule:` | element shape: `>= 0` |
| `tissue.deputy(...)` | `TestTissue` | `testRule:` | `TestTissue.readOnly` for the auditor view |
| `TestTissue.allowAll` | `TestTissue` | default | only when the collection has no extra rule |

Illegal (will not type-check, do not write it):

```dart
TissueSet<int>(testRule: TestCell.allowAll);   // wrong type
TissueSet<int>(const <int>[], _commandShape);  // _commandShape is TestCell
auditor = tags.deputy(testRule: TestCell.readOnly);  // deputy wants TestTissue
```

Required shape:

```dart
final elementRule = TestTissue<int, TissueSet<int>>(
  (v, {host, arguments, user}) => v is int && v >= 0,
);

final tags = TissueSet<int>(const <int>[], testRule: elementRule);

final auditor = tags.unmodifiable;
```

`Cell.ingress<String>(testRule: _commandShape)` stays
**`TestCell`**. That rule never becomes the `testRule` on `tags`.

Compose Tissue rules with `+` (`TestTissue.allowAll + custom`),
not by wrapping a `TestCell`.

---

## Why Flow + Tissue (not a hand-rolled parser)

A natural-language command surface has four machines a hand-rolled
`switch` on `String.contains(...)` will not name:

1. A malformed sentence must die at the **ingress**, not inside the
   verb dispatcher.
2. The model is a **non-deterministic** producer; its reply must be
   parsed into a **closed** verb list before anything is executed.
3. A verb that mutates `tags` must go through `TissueSet.modifiable`
   and the collection's `TestTissue`, not around them.
4. The regulator may watch the set and must not `add` a row.

| Fake if you only use Dart objects | Owner in this demo |
|---|---|
| `final tags = <int>{}` | `TissueSet<int>` — observable, validated |
| `switch (sentence) { case 'add ...': ... }` | `AiTissueCommand` interpreter + `TissueCommand` |
| `tags.add(n)` directly in the parser | `_runDispatch` checks `modifiable` first |
| “export the set for the auditor” | `tags.unmodifiable` |

Tissue is a **Cell that is a collection**. Every `add` / `remove` /
`clear` goes through `TestTissue`, takes the tissue lock, and emits
a `TissuePulse`. Flow never stores the set. The interpreter never
mutates the set.

---

## Design

```
commandIn   TestCell non-empty ≤ 200  ─┐
   │                                   │
   ▼                                   │
AiTissueCommand<String>                │   Flow
   │  interpreter.complete(text:)      │   (I/O only here)
   ▼                                   │
Pulse<TissueCommand> | Pulse<Reject>   │
   │                                   │
   ▼                                   │
Filter<Object>                         │
   │  drops Reject; counts both        │
   ▼                                   │
MapValue<Object, TissueCommand>        │
   │  _runDispatch(cmd)                │
   ▼                                   │
TissueSet<int>.modifiable              │   Tissue
   │  + TestTissue elementRule         │
   ▼                                   │
ElementAdded<int> | ElementRemoved<int>┘
```

| Requirement | Owner |
|---|---|
| Malformed sentence | `TestCell` on `commandIn` |
| Closed verb list | `verbByName` in `ai_tissue_command_domain.dart` |
| Model I/O | `HttpInterpreter` / `StubInterpreter` |
| Reply → `TissueCommand` | `AiTissueCommand` |
| Drop `Reject` | `Filter<Object>` |
| Execute verb against the set | `_runDispatch` |
| Allow / deny a verb | `TissueSet.modifiable.contains(tearOff)` |
| Allow / deny an element | `TestTissue<int, TissueSet<int>>` on `tags` |
| Read-only auditor view | `tags.unmodifiable` |

Do **not** `tags.add` inside the interpreter. The interpreter
returns a `TissueCommand`. `_runDispatch` writes Tissue. If you
mutate Tissue inside the interpreter, you hide the lock and you
cannot test the interpreter against a fixed table.

Do **not** replace `modifiable` with a hand-rolled verb whitelist.
The whitelist is the collection's public contract. The interpreter
must not bypass it.

---

## Domain

```dart
enum TissueVerb { add, addAll, remove, removeAll, clear,
                  retainAll, removeWhere, retainWhere }

final class TissueCommand {
  const TissueCommand({
    required this.verb,
    required this.args,
    required this.confidence,
    required this.source,
  });
  final TissueVerb verb;
  final List<Object?> args;
  final double confidence;
  final String source;
  bool get ok => true;
}

final class Reject {
  const Reject({required this.source, required this.reason});
  final String source;
  final String reason;
  bool get ok => false;
}

typedef InterpreterReply = ({TissueCommand? command, Reject? reject});
```

Suggested verb → arg shape (the dispatch instruction relies on
this):

| Verb | Args shape | Example |
|---|---|---|
| `add` | `[int]` | `[3]` |
| `addAll` | `[[int, ...]]` | `[[4, 5]]` |
| `remove` | `[int]` | `[3]` |
| `removeAll` | `[[int, ...]]` | `[[4, 5]]` |
| `clear` | `[]` | `[]` |
| `retainAll` | `[[int, ...]]` | `[[4, 5]]` |
| `removeWhere` | *(predicate — not driven)* | — |
| `retainWhere` | *(predicate — not driven)* | — |

`removeWhere` / `retainWhere` are listed on `modifiable` but the
demo does not drive them from the model, because the model cannot
safely produce a predicate. The dispatch instruction rejects them
if the model ever returns one.

---

## Parts

### Flow Cells

| Cell | Kind | Role |
|---|---|---|
| `commandIn` | ingress + TestCell | reject empty / > 200 chars |
| `interpreted.cell` | `AiTissueCommand.toHandle` | sentence → `TissueCommand` or `Reject` |
| `dispatchedCell` | `MapValue` over the filter | `TissueCommand` → tissue mutation |

The interpreter runs as a single `AiTissueCommand<String>`
instruction. The `.toHandle(source: commandIn.cell)` call is the
only place the instruction is materialised.

### Tissue collections

| Tissue | Type | `TestTissue` | Who writes | Who reads |
|---|---|---|---|---|
| `tags` | `TissueSet<int>` | element shape: `>= 0` | `_runDispatch` | `main` trailer |
| `auditor` | `TissueSet<int>.unmodifiable` | `TestTissue.readOnly` | — | scenario 8 |

Seed: `tags` empty. Initial population is silent — observers only
see **post-create** mutations.

### Deputies

```dart
final auditor = tags.unmodifiable;
```

Scenario 8 swaps the dispatch host to `auditor` before `say('add 3')`.
`_runDispatch` then calls `auditor.modifiable.contains(add)` which
is `false`, so the mutation is denied **before** the tissue lock is
taken. The trip log is untouched.

In this build `.unmodifiable` captures the set at install time, so
`auditorLength=0` in the trailer. Scenario 8 still verifies the
seam because `auditor.modifiable` is empty regardless of the
captured snapshot.

Do **not** pass the writable `tags` to the auditor view.

### Instruction (Flow)

| Stage | Type |
|---|---|
| `AiTissueCommand<String>` | the interpreter instruction (imported) |
| `Filter<Object>` | drop `Reject`; count both classifications |
| `MapValue<Object, TissueCommand>` | call `_runDispatch(cmd)`; return `cmd` |

Order is mandatory: `AiTissueCommand → Filter → MapValue`.

Do not put a `Distinct` before `Filter`. The user may legitimately
say `add 1` twice in a row. The set deduplicates on the Tissue
side.

### Receptor

`AiTissueCommand<String>(...).toHandle(source: commandIn.cell)`
once at `install()`. That is one `toHandle` call. The dispatch
stage's `MapValue` materialises its own handle internally; the
demo keeps `dispatchedCell` for symmetry but does not call
`toHandle` on it again.

Tissue has its **own** lock on `tags`. Do not assume the Receptor
lock covers `tags.add`.

### Operators the demo must actually call

Flow: `Cell.ingress(testRule:)` with **`TestCell`**,
`AiTissueCommand.toHandle`, `Filter<Object>`, `MapValue<Object,
TissueCommand>`.

Tissue: `TissueSet`, `TestTissue(...)`, `.unmodifiable`,
`.modifiable`, `Box<TissueSet<int>>` for the swappable host.

```dart
final host = _dispatchHost.value;
if (!host.modifiable.contains(tearOff)) {
  print('[dispatch] ${cmd.verb.name} denied (not in modifiable)');
  return;
}
```

---

## Dispatch — pure instruction, not a Tissue mutation

The dispatch stage runs as a `MapValue` over the filter's output:

```dart
dispatchedHandle = Flow.map<Object, TissueCommand>(
  filtered.cell,
  project: (v) {
    final cmd = v as TissueCommand;
    _runDispatch(cmd);
    return cmd;
  },
);
```

`_runDispatch` does **three** things and nothing else:

1. Look up the tear-off in the registry.
2. Check `host.modifiable.contains(tearOff)`.
3. Call the tear-off.

No Tissue lock is taken by the dispatch stage. The lock is taken
by the tear-off itself, inside `TissueSet.add` (etc.).

The host is a `Box<TissueSet<int>>`, so scenario 8 can swap it to
`auditor` before `say(...)` and back after. That is the only
mechanism the demo uses to point the dispatch at a different set.

Never call `tags.add` in the interpreter. The interpreter is Flow.
The dispatch instruction is Flow. Only `_runDispatch` writes
Tissue, and only after the `modifiable` gate passes.

---

## Implementation map

| Block in the dart file | What |
|---|---|
| Header comment | talk track |
| `NlTissueHarness` | mode selection, install, say, host swap |
| `_selectHarness` | `--config` / `--live` / offline precedence |
| `_runDispatch` | the pure dispatch switch |
| `_registry` | verb → tear-off map |
| `_elementRule` / `_commandShape` | the two rule kinds |
| `main` | seed + scenarios 1–12 + trailer |
| `ai_tissue_command.dart` | `AiTissueCommand`, `TissueCommand`, `Reject` |
| `ai_tissue_command_domain.dart` | `Interpreter`, `HttpInterpreter`, `StubInterpreter`, `TrafficLog`, `AiConfig` |

The traffic logging is owned by the interpreter port. The demo
prints nothing about the exchange itself; the header's § What This
File Prints lists the log's output shape.

`install()` runs **once**. `say(...)` is a thin wrapper over
`commandIn.emit(...)` with a five-turn event-loop drain so the
interpreter round trip completes before the scenario's assertions
print.

---

## Scenarios

Seed: `tags` empty, `auditor` empty, interpreter ready.

| # | Drive | Result | Demonstrates |
|---|---|---|---|
| Seed | *(no sentence)* | `tags.isEmpty=true` | bus armed |
| 1 | `add 1 to the tissue` | `contains(1)=true length=1` | interpreter + dispatch + Tissue |
| 2 | `please insert 1` | `contains(1)=true grew=false` | duplicate suppressed by Tissue |
| 3 | `add 2 to the tissue` | `tags={1, 2}` | second add |
| 4 | `remove 1` | `tags={2}` | remove |
| 5 | `clear the set` | `tags={}` | clear |
| 6 | `hack the nucleus` | `dispatched=false tags={}` | model rejects; nothing crosses the seam |
| 7 | `add -1` | `tags={}` | TestTissue rejects `-1` at the tissue boundary |
| 8 | `add 3` (auditor host) | `tags={}` | `.modifiable` empty → dispatch denied |
| 9 | `addAll 4 5` | `tags={4, 5}` | multi-arg verb |
| 10 | `add 6` (timeout injected) | `dispatched=false tags={4, 5}` | interpreter timeout propagates as a `Reject` |
| 11 | `""` then `"x" * 201` | `empty accepted=false oversized accepted=false interpret ran=false` | `TestCell` rejects at ingress |
| 12 | *(optional stub swap)* | skipped | extension hook |
| Trailer | — | `commands=8 interpreted=6 dispatched=5 rejected=2` (see below) | counters |

Good-run counters from the executable trailer:

```text
commands=8 interpreted=6 dispatched=5 rejected=2
```

`commands=8` because scenarios 1–10 each call `say(...)` once,
scenario 11 calls `say(...)` twice, and scenario 8's `say(...)` is
still counted even though its dispatch is denied. Offline, the
stub classifies `hack the nucleus` as a `Reject`, contributing 1
to `rejected`; the timeout in scenario 10 contributes the second
`Reject`.

`interpreted=6` and `dispatched=5` differ because scenario 8's
`TissueCommand` reaches the interpreter but its dispatch is denied
at the `modifiable` gate. The counter increments in the filter,
not in the dispatch.

The trailer also prints:

```text
tags={4, 5} auditorLength=0 (snapshot at install; not live)
```

`auditorLength=0` because `.unmodifiable` is a snapshot in this
build. The COMPLY-style scenario is scenario 8, which checks the
dispatch seam via `auditor.modifiable`, not via `auditor.length`.

---

## Executable steps

These are the steps `nl-instruction-tissue-set-Demo.dart` actually
runs. Numbers match the `── N ──` banners in the console.

**Seam reminder at every step.** Flow answers “which verb did the
sentence name?” Tissue answers “did the set accept the mutation?”
The `Filter` and `MapValue` are the only glue. `_runDispatch`
never takes a Tissue lock; the tear-off does.

**Documented deviations the executable takes** (header of the
demo):

- Tissue constructors: `TissueSet` takes the initial `Iterable` as
  the **first positional** argument, with `testRule:` as a named
  argument.
- Two `toHandle` calls only: one for `interpreted`, one inside
  `MapValue` for `dispatchedCell`.
- Trace prints come from the writers themselves.
- `removeWhere` / `retainWhere` are listed on `modifiable` but not
  driven.
- `.unmodifiable` is a snapshot in this build.
- Offline default; live HTTP requires `--live` or `--config`.
- Full traffic logging is preserved.
- Scenario 10 uses `injectTimeoutOnce` in both offline and live
  modes.
- The system prompt is printed in full the first time, then
  truncated.
- The harness holds both the `AiTissueCommand` instruction and the
  handle returned by `.toHandle(...)`.
- `--config` builds the interpreter via `AiConfig.fromJsonFile`;
  env vars are not consulted when a config is supplied.
- Mode selection is packaged in `_selectHarness`, so `main`
  assigns to `h` exactly once.

---

### Seed — empty TissueSet; interpret + dispatch armed

**Lesson:** the bus is wired, the interpreter port is live, and
nothing has mutated yet.

**Drive**

```dart
await h.install();
```

**What fires**

- `tags = TissueSet<int>(const <int>[], testRule: _elementRule)`.
- `auditor = tags.unmodifiable`.
- `_dispatchHost = Box<TissueSet<int>>(tags)`.
- `commandIn = Cell.ingress<String>(testRule: _commandShape)`.
- `interpretedInstruction = AiTissueCommand<String>(...)`.
- `interpreted = interpretedInstruction.toHandle(source:
  commandIn.cell)`.
- `filtered = Flow.filter<Object>(interpreted.cell, test: ...)`.
- `dispatchedHandle = Flow.map<Object, TissueCommand>(filtered.cell,
  project: ...)`.

**Must print**

```text
── Seed ── empty TissueSet; interpret + dispatch armed
  tags.isEmpty=true
```

**Must not happen**

- No `[dispatch]` lines.
- No `[tags]` lines.

---

### Step 1 — add 1 to the tissue

**Lesson:** sentence → verb → Tissue mutation. The full pipeline
runs end to end.

**Drive**

```dart
await h.say('add 1 to the tissue');
```

**What fires**

1. `commandIn.emit('add 1 to the tissue')` — `_commandShape`
   accepts (non-empty, ≤ 200).
2. `AiTissueCommand` calls `interpreter.complete(text: ...)`.
3. The stub classifies the sentence as `add 1`. The instruction
   fires `future!(Pulse<TissueCommand>(...))`.
4. The filter sees a `TissueCommand`. `interpretedCount++`. The
   pulse passes.
5. `MapValue` calls `_runDispatch(cmd)`. The tear-off is looked up,
   `tags.modifiable.contains(add)` is `true`, `tags.add(1)` runs.
6. `TissueSet.add` takes the Tissue lock, runs `_elementRule`,
   writes the container, emits `ElementAdded<int>`.
7. `dispatchedCount++`.

**Must print**

```text
── 1 ── add 1 to the tissue
[dispatch] add(1) allowed
[tags] +1
  contains(1)=true length=1
```

Plus the interpreter's traffic log for the `complete(...)` call
(prompt, request, response, parsed).

**Must not happen**

- No `[trips]` line — this demo has no trip log.
- No `TestTissue` rejection — `1 >= 0`.

---

### Step 2 — please insert 1

**Lesson:** the set deduplicates. A second `add 1` reaches
`TissueSet.add`, the container rejects the duplicate, and no new
`ElementAdded<int>` is emitted.

**Drive**

```dart
final len2 = h.tags.length;
await h.say('please insert 1');
```

**What fires**

- Same path as step 1.
- `TissueSet.add(1)` runs `_elementRule` (passes) but the
  underlying `Set<int>` already contains `1`, so no `ElementAdded`
  is emitted.

**Must print**

```text
── 2 ── please insert 1
[dispatch] add(1) allowed
  contains(1)=true grew=false
```

`grew=false` is the key assertion: the tear-off ran, the rule
passed, and the set still rejected the duplicate.

---

### Step 3 — add 2 to the tissue

**Lesson:** second distinct element.

**Drive**

```dart
await h.say('add 2 to the tissue');
```

**Must print**

```text
── 3 ── add 2 to the tissue
[dispatch] add(2) allowed
[tags] +2
  tags={1, 2}
```

---

### Step 4 — remove 1

**Lesson:** the remove tear-off runs through the same gates.

**Drive**

```dart
await h.say('remove 1');
```

**What fires**

- `_runDispatch` looks up `tags.remove`, checks `modifiable`,
  calls `tags.remove(1)`.
- `TissueSet.remove` takes the Tissue lock, emits
  `ElementRemoved<int>`.

**Must print**

```text
── 4 ── remove 1
[dispatch] remove(1) allowed
[tags] -1
  tags={2}
```

---

### Step 5 — clear the set

**Lesson:** zero-arg verb. The stub’s classifier produces
`args: []`; `_runDispatch` calls `tags.clear()`.

**Drive**

```dart
await h.say('clear the set');
```

**Must print**

```text
── 5 ── clear the set
[dispatch] clear() allowed
[tags] cleared
  tags={}
```

---

### Step 6 — hack the nucleus

**Lesson:** the model refuses. Nothing crosses the seam.

**Drive**

```dart
await h.say('hack the nucleus');
```

**What fires**

- `commandIn.emit('hack the nucleus')` — accepted by `_commandShape`.
- `AiTissueCommand` calls the stub. The stub returns
  `Reject(source: 'hack the nucleus', reason: 'no-permitted-verb')`.
- The instruction fires `future!(Pulse<Reject>(...))`.
- The filter sees a `Reject`. `rejectedCount++`. Returns `false`.
- The pulse is dropped. No `[dispatch]` line. No `[tags]` line.

**Must print**

```text
── 6 ── hack the nucleus
  dispatched=false tags={}
```

Plus the interpreter's traffic log for the `complete(...)` call,
which includes a `REFUSED` block with the reason.

**Must not happen**

- No `[dispatch]` line.
- No `[tags]` line.

---

### Step 7 — add -1

**Lesson:** the sentence is valid; the model returns a valid
`TissueCommand`; the dispatch runs; the **Tissue rule** rejects the
element.

**Drive**

```dart
await h.say('add -1');
```

**What fires**

1. `AiTissueCommand` returns `TissueCommand(add, args: [-1])`.
2. The filter passes. `interpretedCount++`.
3. `_runDispatch` calls `tags.add(-1)`.
4. `_elementRule` returns `false` for `-1`. The `TissueSet`
   rejects the write. No `ElementAdded<int>` is emitted. The
   container is unchanged.

**Must print**

```text
── 7 ── add -1
[dispatch] add(-1) allowed
[tags] reject -1
  tags={}
```

The `[dispatch] add(-1) allowed` line is printed by
`_runDispatch` because the `modifiable` gate passed. The
`[tags] reject -1` line is printed by the writer after the rule
returned `false`.

**Must not happen**

- No `[tags] +(-1)` line — the rule rejected.

---

### Step 8 — add 3 via auditor

**Lesson:** the deputy’s `modifiable` is empty. The dispatch is
denied **before** the tissue lock is taken.

**Drive**

```dart
h.useAuditorHost();
await h.say('add 3');
h.useMutableHost();
```

**What fires**

1. `_dispatchHost.value = auditor`.
2. `AiTissueCommand` returns `TissueCommand(add, args: [3])`.
3. The filter passes. `interpretedCount++`.
4. `_runDispatch` looks up the tear-off, checks
   `auditor.modifiable.contains(add)` — `false` — and prints the
   denied line.
5. **No** `tags.add(3)`. `dispatchedCount` does **not** increment.
6. `_dispatchHost.value = tags`.

**Must print**

```text
── 8 ── add 3 via auditor
[dispatch] add(3) denied (not in modifiable)
  tags={}
```

**Must not happen**

- No `[tags] +3` line.
- `dispatchedCount` is unchanged.

---

### Step 9 — addAll 4 5

**Lesson:** multi-arg verb. The stub returns `args: [[4, 5]]`;
`_runDispatch` unwraps once and calls `tags.addAll([4, 5])`.

**Drive**

```dart
await h.say('addAll 4 5');
```

**What fires**

- `_runDispatch` calls `tags.addAll([4, 5])`.
- `TissueSet.addAll` runs `_elementRule` per element, writes both,
  emits a batch `ElementAdded<int>` (or two — implementation
  dependent; the console prints both `[tags] +4` and `[tags] +5`).

**Must print**

```text
── 9 ── addAll 4 5
[dispatch] addAll([4, 5]) allowed
[tags] +4
[tags] +5
  tags={4, 5}
```

---

### Step 10 — interpreter timeout

**Lesson:** a transport failure is a `Reject`. The dispatch stage
never runs.

**Drive**

```dart
final before10 = h.dispatchedCount;
h.interpretedInstruction.injectTimeoutOnce();
await h.say('add 6');
```

**What fires**

1. `injectTimeoutOnce` marks the interpreter for a one-shot throw.
2. `say('add 6')` emits the sentence. The interpreter's
   `complete(...)` throws.
3. `AiTissueCommand` catches the throw, invokes its `onError`
   handler (which routes to the interpreter's `TrafficLog`), and
   emits no pulse.
4. The filter sees no pulse. `dispatchedCount` unchanged.

**Must print**

```text
── 10 ── interpreter timeout
  dispatched=false tags={4, 5}
```

Plus the interpreter's traffic log, which includes an `ERROR`
block.

**Must not happen**

- No `[dispatch] add(6) allowed` line.
- No `[tags] +6` line.

---

### Step 11 — empty and oversized

**Lesson:** `TestCell` on the ingress. A malformed sentence dies at
the edge. The interpreter never runs.

**Drive**

```dart
final before11 = h.tags.length;
final emptyOk = await h.say('');
final oversizedOk = await h.say('x' * 201);
```

**What fires**

- `commandIn.emit('')` — `_commandShape` rejects (empty). `say`
  returns `false` without incrementing `commands`.
- `commandIn.emit('x' * 201)` — `_commandShape` rejects (> 200).
  `say` returns `false`.

**Must print**

```text
── 11 ── empty and oversized
  empty accepted=false
  oversized accepted=false
  interpret ran=false
```

**Must not happen**

- No traffic log for either sentence.
- No `[dispatch]` line.

---

### Step 12 — (optional) swap the stub

**Lesson:** extension hook.

**Drive**

```dart
// skipped — no live interpreter
```

**Must print**

```text
── 12 ── (optional) swap the stub
  skipped (no live interpreter)
```

---

### Trailer

**Must print**

```text
-------------------------------------------------------------
commands=8 interpreted=6 dispatched=5 rejected=2
tags={4, 5} auditorLength=0 (snapshot at install; not live)
-------------------------------------------------------------
```

Then `h.dispose()` closes the HTTP client (if live) and stops
anything the harness opened. In offline mode `dispose()` is a
no-op.

---

## Pulse path (scenario 6 then 7)

```
say('hack the nucleus')
  commandIn.emit
    _commandShape: pass
    AiTissueCommand.complete: stub returns Reject
    future!(Pulse<Reject>)
  Filter<Object>: Reject → rejectedCount++ → drop
  tags unchanged

say('add -1')
  commandIn.emit
    _commandShape: pass
    AiTissueCommand.complete: stub returns TissueCommand(add, [-1])
    future!(Pulse<TissueCommand>)
  Filter<Object>: TissueCommand → interpretedCount++ → pass
  MapValue: _runDispatch → tags.add(-1)
    TissueSet.modifiable.contains(add): pass
    TissueSet.add(-1)
      _elementRule: fail
      container unchanged
      no ElementAdded
  tags unchanged
```

Scenario 11 stops at `commandIn.emit`. The interpreter is idle.
Tissue is idle.

Scenario 10 stops between `commandIn.emit` and
`AiTissueCommand.complete`. The `onError` handler runs; no pulse
crosses the seam.

---

## Who owns the lock

| Event | Lock |
|---|---|
| `commandIn.emit` | ingress Cell lock |
| `AiTissueCommand.complete` | instruction's own execution; no Tissue lock |
| `_runDispatch` | none — pure switch on `modifiable` |
| `tags.add` / `tags.remove` / `tags.clear` | TissueSet lock |
| `auditor.modifiable.contains(...)` | none — read-only |

Do not “fix” a race by putting `tags.add` inside the interpreter.
Teach the two locks.

---

## Real product vs this file

| Still missing | Suggested next piece |
|---|---|
| Real LLM streaming | `HttpInterpreter` with `stream: true` |
| Multi-turn conversation | A second `Cell.ingress` for the reply, and a `Synthesis` to keep context |
| Argument type coercion | A `TestTissue` on `TissueCommand` before the dispatch |
| Approval queue for high-risk verbs | A `TissueQueue<TissueCommand>` and a second consumer |
| Persistent audit of commands | A `TissueList<TissueCommand>` alongside `tags` |
| Rate limiting per operator | A `TestTissue` on `tags` keyed on a sliding window |
| Verb composition (`add 3 then remove 1`) | A `Synthesis` over the interpreter output |
| Multi-model fallback | A `Synthesis` over two interpreters |
| Sandboxed execution | A `TissueSet<int>.unmodifiable` host (see scenario 8) |

Flow stays on “which verb did the sentence name?”
TestCell stays on the **sentence ingress**.
TestTissue stays on **collection mutations**.
`modifiable` stays the **dispatch whitelist**.
Tissue stays the **membership set**.
Deputy stays the **auditor view**.

---

## Acceptance

1. `dart run nl-instruction-tissue-set-Demo.dart` prints every row
   in the scenario table with the **Result** column matched.
2. Grep shows exactly **one** explicit `toHandle(` call on
   `AiTissueCommand`, inside `install()`; the dispatch stage's
   `MapValue` does not need a hand-written `toHandle`.
3. `_runDispatch` contains no `await`, no `tags.add` before the
   `modifiable` gate, and no direct write to `tags` other than the
   tear-off call.
4. Scenario 6 prints `dispatched=false` and does not touch `tags`.
5. Scenario 7 prints `[dispatch] add(-1) allowed` **and**
   `[tags] reject -1`, and `tags` is unchanged.
6. Scenario 8 prints `[dispatch] add(3) denied (not in modifiable)`
   and `tags` is unchanged.
7. Scenario 10 prints `dispatched=false` and does not touch
   `tags`.
8. Scenario 11 prints `empty accepted=false`,
   `oversized accepted=false`, and `interpret ran=false`.
9. Every `TissueSet` / `.unmodifiable` call passes
   **`TestTissue`** (or omits the argument and takes
   `TestTissue.allowAll`). Grep must show **zero**
   `testRule: TestCell` on those calls.
10. The trailer's counters match
    `commands=8 interpreted=6 dispatched=5 rejected=2`.
11. `auditorLength=0` in the trailer, with the deviation note
    printed.
12. `--live` without `AI_ENDPOINT` / `AI_API_KEY` falls back to
    offline and prints a diagnostic.
13. `--config <path>` reads only the file; env vars are not
    consulted.
14. Full traffic logging is preserved offline and live.
15. `dispose()` is called in a `finally` block.

---

## Documented deviations (summary)

1. **Seed behaviour.** No sentence is published on seed. The Seed
   banner only reports `tags.isEmpty=true`.
2. **`auditorLength=0`.** `.unmodifiable` is a snapshot in this
   build. Scenario 8 still verifies the dispatch seam via
   `auditor.modifiable`.
3. **Trailer counters.** `commands=8 interpreted=6 dispatched=5
   rejected=2`. The gap between `interpreted` and `dispatched`
   is scenario 8's denial at the `modifiable` gate.
4. **`removeWhere` / `retainWhere`.** Listed on `modifiable` but
   not driven. The dispatch instruction rejects them if the model
   returns one.
5. **Timeout injection.** Uses `injectTimeoutOnce` in both offline
   and live modes so scenario 10 stays deterministic.
6. **Config precedence.** `--config` wins over `--live`; env vars
   are not consulted when a config is supplied.

The **policy** is unchanged by these deviations. Only the sample
numbers are.

---

## Name plate

| Artifact | Name |
|---|---|
| This requirement / walkthrough | `nl-instruction-tissue-set-WalkThrough.md` |
| Demo | `nl-instruction-tissue-set-Demo.dart` |
| Instruction module | `ai_tissue_command.dart` |
| Domain module | `ai_tissue_command_domain.dart` |
| Mobility sibling | `ride-hail-dispatch(tissue)-WalkThrough.md` |
| Payments sibling | `card-auth-pipeline(tissue)-WalkThrough.md` |
| Energy sibling | `grid-demand-response(tissue)-WalkThrough.md` |
| Clinical sibling | `ICU-alarm-pipeline(enhanced)-WalkThrough.md` |

NL-instruction → TissueSet is the command-surface lesson. The
seam is the same as every sibling: Flow decides, Tissue records,
one `observe` glues the two, and `modifiable` is the collection's
public contract.