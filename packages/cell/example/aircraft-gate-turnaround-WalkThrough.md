# Walkthrough requirement — aircraft gate turnaround (Cell core only)

**Suggested demo:** `aircraft-gate-turnaround-Demo.dart`  
**Stack:** `package:cell` **only**  
**Forbidden:** `package:cell_flow`, `package:cell_tissue`, `Flow.*`,
`FlowInstruction`, `MapValue`, `Filter` as a Flow class, `TissueList`,
`TissueValue`, `TestTissue`, `toHandle` from Flow.

**Industry:** airline ramp / gate turnaround  
(the twenty-five minutes between "last bag off" and "pushback
cleared": fuel the wing, dock the jetbridge, close the doors,
pull the chocks, call for push). Not a hotel desk, not a
pharmacy drawer, not a card switch, not a cab match, not a
grid shed, not an ICU pager.

Siblings that this file is **not**:

| File | Why it is a different lesson |
|---|---|
| `hotel-front-desk-checkin-WalkThrough.md` | rooms + folio + key encoder; this file is a stand + fuel + pushback |
| `WalkThrough-pharmacy-dispense-transaction.md` | till + robot drawer |
| `card-auth-pipeline(tissue)-WalkThrough.md` | Tissue books + Flow gates |
| `ride-hail-dispatch(tissue)-WalkThrough.md` | mobility |
| `grid-demand-response(tissue)-WalkThrough.md` | Hz / MW |
| `ICU-alarm-pipeline(enhanced)-WalkThrough.md` | Flow PAGE/WARN |

This is the **executable requirement** for a Cell-core airside
demo. Implement the Dart file so a last-good run prints the
scenario table in § Scenarios.

The lesson: Groups 1–4 plus Atomic from `package:cell` are
enough for a real turn. Do not reach for Flow because you miss
`Filter`. Use `Cell.derive` + `TestCell` + `Cell.distinct`. Do
not reach for Tissue because you miss a list. Use
`Cell.state<List<…>>` only as a local harness printer, or print
from `Cell.observe` — the system of record in this demo is
**named state Cells**, not a collection type.

The hotel walkthrough already taught "one picture + hub +
sanitize + occupy-and-post." This file teaches a different
atomic pair: **doors closed + chocks off + status = pushing**.
You cannot push an aircraft with a door open. You cannot leave
the chocks on after a cleared push. Fuel kg and FIDS text are
side channels, not the lock.

---

## Contents

1. [Allowed Cell surface (and nothing else)](#allowed-cell-surface-and-nothing-else)
2. [Problem](#problem)
3. [Design](#design)
4. [Domain](#domain)
5. [Cells](#cells)
6. [Synthesis, hub, sanitize](#synthesis-hub-sanitize-what-this-file-adds-on-top-of-hotel)
   - [`Cell.synthesis`](#cellsynthesis)
   - [`Cell.hub`](#cellhub)
   - [`Cell.sanitized`](#cellsanitized)
   - [`Cell.open`](#cellopen)
7. [`Cell.transaction` — doors + chocks + status together](#celltransaction--doors--chocks--status-together)
8. [txApply semantics — headset clearance with compensate](#txapply-semantics--headset-clearance-with-compensate)
9. [Implementation map](#implementation-map)
10. [Scenarios](#scenarios)
11. [Executable steps (Seed + 1–14)](#executable-steps-seed--114)
    - [Seed](#seed--bind-the-graph-stand-a12-chocks-on-doors-open)
    - [Step 1 — bumper chatter](#step-1--bumper-chatter--one-quiet-pulse)
    - [Step 2 — PUSH mash](#step-2--push-mash--one-routed-tap-refused-doors-open)
    - [Step 3 — bad stand](#step-3--bad-stand-rejected-at-ingress)
    - [Step 4 — doors open, refused](#step-4--on-block-doors-open-push-refused)
    - [Step 5 — commit + clearance](#step-5--doors-closed-push-ba482-commits--clearance)
    - [Step 6 — second PUSH](#step-6--second-push--one-occupant-on-the-tug)
    - [Step 7 — radio dead](#step-7--radio-dead-after-the-transaction-commits)
    - [Step 8 — radio lives](#step-8--radio-lives--real-clearance-id)
    - [Step 9 — ramp log](#step-9--ramp-log-hides-the-surname)
    - [Step 10 — switchMap](#step-10--switchmap-follows-the-latest-flight)
    - [Step 11 — slot quote](#step-11--fromfuture-slot-quote)
    - [Step 12 — GPU open](#step-12--gpu-open-slot-binds-after-boot)
    - [Step 13 — HOLD isolation](#step-13--hold-goes-to-the-board-only)
    - [Step 14 — negative fuel](#step-14--negative-fuel-rejected-at-ingress)
    - [Trailer](#trailer-after-step-14)
12. [Pulse path (scenario 5)](#pulse-path-scenario-5)
13. [Real ramp vs this file](#real-ramp-vs-this-file)
14. [Acceptance](#acceptance)
15. [Name plate](#name-plate)

---

## Allowed Cell surface (and nothing else)

| Group | Operator | Role in this demo |
|---|---|---|
| 1 Essential | `Cell.state` | stand status, doors, chocks, fuel kg, clearance id |
| 1 | `Cell.ingress` | flight on-block, stand id, bumper contact, fuel truck |
| 1 | `Cell.derive` | "is this stand ready to push?" |
| 1 | `Cell.observe` | print, request push, post FIDS |
| 2 Flow control | `Cell.debounce` | jetbridge bumper chatter |
| 2 | `Cell.distinct` | do not re-paint the same stand status |
| 2 | `Cell.throttle` | tug PUSH button mash |
| 2 | `Cell.synthesis` | flight + stand + fuel + bridge + chocks + doors → `TurnView` |
| 3 Async | `Cell.asyncMap` | FIDS / ACARS mock |
| 3 | `Cell.switchMap` | follow the **latest** flight on this stand only |
| 3 | `Cell.fromFuture` | one-shot slot-time quote |
| 4 Governance | `Cell.hub` | route `FUEL` / `BRIDGE` / `CATER` / `PUSH` / `HOLD` |
| 4 | `Cell.sanitized` | PNR surnames never hit the ramp log Cell |
| 4 | `Cell.open` | late-bind the GPU (ground power) after the stand boots |
| Atomic | `Cell.transaction` | doorsClosed + chocksOff + status=pushing together |
| Atomic | `Cell.txApply` | tower / headset clearance; compensate by cancelling push |
| Governance | `TestCell` | flight `^[A-Z][A-Z0-9][0-9]{1,4}$` (BA482 **and** U2871), stand `A12`/`A12R`, fuel kg ≥ 0 |

`Receptor` may appear only as whatever `Cell.ingress` /
`Cell.derive` already install. Do **not** build an
`InstructionChain`.

API notes the hotel demo already paid for — do not rediscover
them:

- `TestCell` is `TestCell<Cell>`. Unwrap `Pulse.payload`. Wrong
  runtime type returns `true` so the wrapper is not rejected.
- `Cell.observe` takes `source:`, not `bind:`. Effect is
  `(Pulse pulse)`.
- `Cell.hub` returns a **record**
  `({emit, emitAsync, ingest, root, spokes})`. Observe
  `hub.root`. Inject with `hub.emit`. There is no `hub.cell`.
- `Cell.synthesis` is `Cell.synthesis<Pulse<TurnView>>`. The
  aggregator reads `.value` on **mirror State Cells**, not raw
  ingresses.
- `StateHandle` writes with `.update`, ingress with `.emit`.
- Throttle: set `leading: true`, `trailing: false` or the first
  PUSH tap is swallowed.
- `Cell.sanitized` only redacts when sensitivity meets the
  threshold. Derive the mask first, then wrap.

---

## Problem

An aircraft is on stand A12. The ramp must:

1. Reject a garbage flight number or stand id at **ingress**
   (`TestCell`), not after FIDS has already painted "boarding."
2. See **one** turn picture: flight + stand + fuel + bridge +
   chocks + doors (`Cell.synthesis`). Bridge bumpers chatter —
   `Cell.debounce` them.
3. Route five pulse *kinds* without five ad-hoc if-ladders
   (`Cell.hub`: `FUEL`, `BRIDGE`, `CATER`, `PUSH`, `HOLD`).
4. Never write a passenger surname to the ramp log Cell
   (`Cell.sanitized`). The gate agent screen may still read
   the raw PNR list.
5. Close the doors and pull the chocks **together**
   (`Cell.transaction`) and flip status to `pushing`. A crash
   must not leave "doors closed, chocks still on, status
   ready."
6. Call tower / headset for push clearance; if the radio
   dies after memory committed, cancel the push
   (`txApply` semantics + `compensate`). The aircraft is
   still doors-closed on the stand — you do not reopen the
   cabin from a radio fault.
7. Two overlapping PUSH requests must not both take the
   tug. Locks run at **commit**.
8. A late-arriving GPU module must still bind (`Cell.open`).
9. If a new flight number arrives on the same stand before
   the previous ACARS post returns, follow the **latest**
   (`Cell.switchMap`).

That is not a Flow PAGE/WARN gate. That is synthesis, hub,
sanitize, commit, compensate — on a stand, not a front desk.

---

## Design

```
flightIn   ingress<FlightOnBlock>  ── TestCell (flight shape)
standIn    ingress<String>         ── TestCell (stand A12 / A12R)
bumperIn   ingress<bool>           ── debounce 40 ms
fuelIn     ingress<int>            ── TestCell kg ≥ 0
doorsIn    ingress<bool>
chocksIn   ingress<bool>
hubIn      ingress<Object>

                │
                ▼
         mirrors (State Cells) — synthesis can read .value
                │
                ▼
         Cell.synthesis → turnView : TurnView
                │
                ├─ Cell.distinct(status)
                │
                ▼
         Cell.hub
            ├─ type FUEL    → ramp board + fuel kg mirror
            ├─ type BRIDGE  → ramp board only
            ├─ type CATER   → ramp board only
            ├─ type HOLD    → ramp board only (never the push tx)
            └─ type PUSH    → throttle → push path

push path
  Cell.switchMap → latest flight on this stand
  Cell.observe → Cell.transaction(doorsClosed, chocksOff, status)
                 encode/clearance mock + compensate cancelPush
                 Cell.asyncMap  ACARS / FIDS

pnrRaw ── Cell.derive (mask surnames)
             │
             ▼
       Cell.sanitized → rampLog

gpuSlot ── Cell.open     bound after boot
```

| Requirement | Owner |
|---|---|
| Bad flight / stand / negative fuel | `TestCell` on **ingress** |
| Bridge bumper chatter | `Cell.debounce` |
| PUSH button mash | `Cell.throttle` |
| One turn picture | `Cell.synthesis` |
| Skip same status | `Cell.distinct` |
| Latest flight wins | `Cell.switchMap` |
| Kinded events | `Cell.hub` |
| PNR off the ramp log | `Cell.sanitized` + derive |
| Doors + chocks + status together | `Cell.transaction` |
| Headset clearance + undo | `txApply` semantics |
| Late GPU | `Cell.open` |
| FIDS / ACARS I/O | `Cell.asyncMap` / `Cell.fromFuture` |
| Side effects | `Cell.observe` only |

Do **not** put `headset.requestPush()` inside `Cell.derive`.
Derive is pure. I/O lives in `observe` / `asyncMap` / compensate.

Do **not** sanitize by `replaceAll` inside `observe`. The ramp
log is a **sanitized** node so a future observer cannot
"forget."

`HOLD` and `CATER` pulses never enter the push transaction.
That is the isolation the hub exists for.

---

## Domain

```dart
enum StandStatus { empty, onBlock, servicing, ready, pushing, departed }

enum BridgeState { retracted, docking, docked, jammed }

final class FlightOnBlock {
  const FlightOnBlock({
    required this.flight,     // 'BA482' | 'U2871'
    required this.dest,       // 'LHR'
    required this.seats,      // 180
    required this.pnrLead,    // 'Ada Lovelace' — gate screen only
  });
  final String flight;
  final String dest;
  final int seats;
  final String pnrLead;
}

final class TurnView {
  const TurnView({
    required this.flight,
    required this.stand,
    required this.fuelKg,
    required this.bridgeDocked,
    required this.chocksOn,
    required this.doorsClosed,
    required this.status,
  });
  final String? flight;
  final String stand;
  final int fuelKg;
  final bool bridgeDocked;
  final bool chocksOn;
  final bool doorsClosed;
  final StandStatus status;
}
```

Pulse **types** the hub keys on (`Pulse.type`,
`HubRouting.exact`):

| Type | Payload | Goes to |
|---|---|---|
| `FUEL` | `int` kg | fuel mirror + board |
| `BRIDGE` | `BridgeState` | board only |
| `CATER` | `String` cart id | board only |
| `HOLD` | `String` reason | board only — never the push tx |
| `PUSH` | `FlightOnBlock` or flight id | throttle → push path |

Flight shape for TestCell (after unwrapping payload):

```text
^[A-Z][A-Z0-9][0-9]{1,4}$     BA482 (ICAO) and U2871 (IATA numeric)
```

The first draft used `^[A-Z]{2}[0-9]{1,4}$`, which silently
rejects `U2871` and breaks scenario 10. The executable uses
the one-letter-plus-alnum pattern above. Do not "fix" it back.

Stand shape:

```text
^[A-Z][0-9]{1,2}[LRC]?$   A12  A12R  B3
```

Fuel: integer kg ≥ 0. `emit(-1)` is rejected.

---

## Cells

| Cell | Kind | Holds |
|---|---|---|
| `flightIn` | ingress + TestCell | raw `FlightOnBlock` (push path) |
| `acarsIn` | ingress + TestCell | same shape; **switchMap / ACARS only** |
| `standIn` | ingress + TestCell | `'A12'` / `'A12R'` |
| `bumperIn` | ingress | jetbridge bumper reed |
| `fuelIn` | ingress + TestCell | kg |
| `doorsIn` | ingress | cabin door closed flag |
| `chocksIn` | ingress | chocks in / out |
| `hubIn` | ingress | typed pulses for the hub |
| `bumperQuiet` | `Cell.debounce(bumperIn)` | stable docked / free |
| `turnView` | `Cell.synthesis` | `TurnView` |
| `status` | `Cell.state<StandStatus>` | empty…departed |
| `doorsClosed` | `Cell.state<bool>` | cabin |
| `chocksOn` | `Cell.state<bool>` | yellow chocks |
| `fuelKg` | `Cell.state<int>` | last accepted fuel |
| `clearance` | `Cell.state<String?>` | headset / tower id |
| `pnrRaw` | `Cell.state<String>` | lead passenger (gate only) |
| `rampLog` | derive + `Cell.sanitized` | redacted |
| `acars` | `Cell.asyncMap` off latest flight | last FIDS/ACARS ack |
| `slotQuote` | `Cell.fromFuture` | one slot-time check |
| `gpuSlot` | `Cell.open` | bound GPU after boot |
| mirrors | `Cell.state` | `flightView`, `standView`, `bridgeView`, `bumperView` |

Seed: stand `A12`, no flight, `fuelKg=0`, bridge retracted,
chocks on, doors open (`doorsClosed=false`),
`status=empty`, GPU unbound until scenario 12.

There is **no** `TestTissue` in this file.

---

## Synthesis, hub, sanitize (what this file adds on top of hotel)

### `Cell.synthesis`

Hotel synthesized a desk. This file synthesizes a **turn**:

```dart
turnView = Cell.synthesis<Pulse<TurnView>>(
  [flightView.cell, standView.cell, fuelKg.cell,
   bridgeView.cell, chocksOn.cell, doorsClosed.cell, status.cell],
  aggregator: (cells, emit) { /* peek .value; return Pulse<TurnView> */ },
);
```

A push observe reads **`turnView`** (or the same mirrors the
aggregator reads), not five raw ingresses. If doors are still
open, the transaction must not run.

### `Cell.hub`

`HOLD` and `CATER` are the isolation test. A catering cart id
on the board must not pull the chocks. A weather HOLD must not
increment the PUSH routed counter.

### `Cell.sanitized`

```dart
final masked = Cell.derive<Pulse, Pulse>(
  source: pnrRaw.cell,
  project: (input) {
    final raw = '${input.payload ?? ''}';
    final first = raw.trim().split(' ').first;
    return Pulse<String>('$first ***', type: 'RAMP_LOG');
  },
);
rampLog = Cell.sanitized<Pulse>(
  masked,
  redact: (p) => p,
  minSensitivity: Sensitivity.public,
);
```

Scenario 9: `pnrRaw.update('Ada Lovelace')` — ramp log payload
must not contain `Lovelace`. Gate screen may still read
`pnrRaw`.

### `Cell.open`

Boot creates `gpuSlot` empty. Scenario 12 binds the GPU state
Cell. A clearance call that went *through the slot* before bind
must fail closed — no ghost GPU.

---

## `Cell.transaction` — doors + chocks + status together

```dart
final tx = Cell.transaction();
await tx.begin([doorsClosed.cell, chocksOn.cell, status.cell]);

final already = tx.read(status.cell);
if (already == StandStatus.pushing || already == StandStatus.departed) {
  await tx.rollback();
  throw StateError('pushing');
}
if (tx.read(doorsClosed.cell) != true) {
  await tx.rollback();
  throw StateError('doors-open');
}

tx.update(chocksOn.cell, false);
tx.update(status.cell, StandStatus.pushing);
await tx.commit();
```

Doors must already be closed **before** the tx (set by
`doorsIn` / a prior servicing step). The transaction does not
silently close doors — it refuses. That is the airside rule:
the agent closes doors; the tug does not.

Locks are taken at **commit**. Two overlapping PUSH taps: only
one commit sees `status != pushing`.

Do not `chocksOn.update(false)` outside this transaction on
the happy path.

---

## txApply semantics — headset clearance with compensate

Hotel encoded a key and voided it. This file requests a push
clearance and **cancels** it.

```dart
String? issued;
try {
  issued = await requestPush(flight.flight); // mock headset
  lastClearanceId = issued;
  clearance.update(issued);
  print('[tug] clearance $issued');
} catch (e) {
  if (issued != null) await cancelPush(issued);
  lastClearanceWasCancelled = true;
  print('[tug] radio failed ($e); cancelled=$lastClearanceWasCancelled');
}
```

If the mock radio throws after doors+chocks already committed,
compensate cancels the clearance id. Memory status stays
`pushing` (the aircraft is physically doors-closed, chocks
off). Do not invent a second transaction that secretly re-opens
the cabin — that is a different product (return-to-stand).

The executable may call the radio directly inside try/catch.
That preserves the contract without depending on a particular
`ApplyTransactionScope` begin API. Mention `Cell.txApply` in
the header so grep-acceptance still finds the name, or call
`Cell.txApply()` for the scope object and ignore it — do not
lie in the talk track: the **semantics** are compensate-on-
failure.

---

## Implementation map

| Block in the dart file | What |
|---|---|
| Header / expected output | talk track; list forbidden imports |
| Domain types | `FlightOnBlock` / `TurnView` / enums |
| flight / stand / fuel TestCell | `TestCell<Cell>` |
| ingress + debounce + throttle | Group 1–2 |
| mirrors + synthesis + distinct | one picture |
| hub wiring | FUEL / BRIDGE / CATER / HOLD / PUSH |
| sanitized ramp log | PNR |
| `open` GPU slot | late bind |
| observe → transaction + radio | Atomic |
| asyncMap / fromFuture | ACARS + slot quote |
| `main` | seed + scenarios 1–14 |

---

## Scenarios

Seed stand `A12`, fuel `0`, chocks on, doors open, status
`empty`, no flight.

| # | Drive | Result | Demonstrates |
|---|---|---|---|
| Seed | bind; stand A12; chocks on; doors open | turnView A12 empty | synthesis |
| 1 | bumper dock/undock 5× in 100 ms | **one** quiet bumper pulse | `debounce` |
| 2 | PUSH tap three times in 50 ms | **one** PUSH routed (and then refused: doors open) | `throttle` + `hub` |
| 3 | `standIn.emit('12')` | TestCell reject; no synthesis bump | ingress boundary |
| 4 | flight on-block, doors still open, PUSH | refuse `doors-open`; status stays empty/onBlock | guard |
| 5 | close doors, PUSH `BA482` | chocks off, status pushing, clearance id | `transaction` |
| 6 | second overlapping PUSH | one `StateError('pushing')` | commit-time lock |
| 7 | radio dead on first request | clearance cancelled; status still pushing | compensate |
| 8 | radio lives | `clearance` holds an id | apply |
| 9 | `pnrRaw` Ada Lovelace | rampLog has no `Lovelace` | `sanitized` |
| 10 | flight `BA482` then immediately `U2871` | ACARS follows **U2871** | `switchMap` |
| 11 | `fromFuture` slot quote | one quote print | `fromFuture` |
| 12 | GPU `Cell.open` after boot | bind works only after link | `open` |
| 13 | HOLD pulse `wx-hold` | board print; chocks/status unchanged | hub isolation |
| 14 | fuel tap `-1` | TestCell reject | kg rule |

Trailer the talk track can read:

```text
status=pushing chocksOn=false doorsClosed=true
auditContainsLovelace=false
clearance=CLR-U2871-1   (or last happy id from step 8)
acarsLast=U2871
```

Exact clearance id format is the mock's choice
(`CLR-<flight>-<n>`). Acceptance cares that it is non-null
after step 8 and that step 7 printed `cancelled=true`.

---

## Executable steps (Seed + 1–14)

This section is the talk-track for `main()` in
`aircraft-gate-turnaround-Demo.dart` after the corrections
in that file's header. Do not reorder. Later steps assume
doors / status / clearance from earlier ones, except 7 and
8 which reset the stand on purpose.

Two push drives exist and must not be collapsed:

| Helper | Path | Used by |
|---|---|---|
| `tapPush(f)` | `pushTap` → `Cell.throttle(50 ms, leading: true, trailing: false)` → `hub.emit(type: PUSH)` → spoke increments `pushRoutedCount` | **scenario 2 only** |
| `drivePushDirect(f)` | `_tryPush(f)` on this turn, no throttle | scenarios **4–8** |

ACARS is a **separate** ingress (`acarsIn`), not `flightIn`.
`Cell.switchMap` + `Cell.asyncMap(latestOnly)` sit on `acarsIn`.
The harness sets `acarsLast` from the `acarsIn` observer.
Scenario 10 must emit on `acarsIn`.

`StateHandle` has no `.value`. Read doors / chocks / status
through `_boolVal(handle.cell)` / `_statusName(handle.cell)`.

---

### Seed — bind the graph, stand A12, chocks on, doors open

**Drive**

```dart
turn.standIn.emit('A12');
turn.chocksIn.emit(true);
turn.doorsIn.emit(false); // cabin open
```

**What fires**

- Stand TestCell accepts `A12`. Mirror `standView`.
- Chocks observer: `chocksOn = true`, print `[chocks] on`.
- Doors observer: `doorsClosed = false`, print `[doors] open`.
- Synthesis emits `TurnView(flight=null, stand=A12, fuel=0,
  chocks=true, doors=false, status=empty)`.
- `Cell.fromFuture` slot quote may print `[slot] 18` during
  seed (constructed in `install`, not in step 11).

**Must print**

```text
── Seed ── bind observers; stand A12; chocks on; doors open
[turnView] stand=A12 flight=null fuel=0 chocks=true doors=false status=empty
[chocks] on
[doors] open
  status=empty
```

**Must not happen:** transaction, clearance, ACARS.

---

### Step 1 — bumper chatter → one quiet pulse

**Lesson:** `Cell.debounce(bumperIn, 40 ms)`.

**Drive:** five dock/undock pairs, 5 ms apart, then wait 100 ms.

**Must print**

```text
── 1 ── bumper dock/undock 5× in 100 ms
[bumper] quiet → false (pulse #1)
  bumperQuiet pulses: 1
```

Accept count in `{1, 2}`. Fail if ≥ 5 (debounce not wired).
Chocks / status must not change.

---

### Step 2 — PUSH mash → one routed tap, refused (doors open)

**Lesson:** `Cell.throttle` + hub type `PUSH`.

**Drive**

```dart
turn.tapPush(seedFlight); // BA482 ×3, 5 ms apart
await Future.delayed(const Duration(milliseconds: 120));
```

Throttle window in the executable is **50 ms**, `leading: true`,
`trailing: false`. First tap through; the rest of the burst
drops. Hub spoke increments `pushRoutedCount` once. Doors are
still open, so `_tryPush` prints `refuse push: doors-open`.
Status stays `empty` or `onBlock`, never `pushing`.

**Must print**

```text
── 2 ── PUSH tap three times in 50 ms
[tug] refuse push: doors-open
  PUSH routed: 1
```

**Must not happen:** three routed PUSHes; chocks pulled.

---

### Step 3 — bad stand rejected at ingress

**Lesson:** `TestCell` on `standIn`. Pattern
`^[A-Z][0-9]{1,2}[LRC]?$`. `'12'` has no letter.

**Drive:** `final accepted = turn.standIn.emit('12');`

**Must print**

```text
── 3 ── standIn.emit('12') — TestCell reject
  ingress accepted=false  synthBumps delta=0
```

No `[turnView]` with `stand=12`.

---

### Step 4 — on-block, doors open, PUSH refused

**Lesson:** the agent closes doors; the tug does not.

**Drive**

```dart
await turn.drivePushDirect(seedFlight); // BA482, doors still open
```

`drivePushDirect` calls `_tryPush` on this turn. Guard reads
`_boolVal(doorsClosed.cell)` — not `doorsClosed.value`
(`StateHandle` has no such getter).

Flight observer may set `status=onBlock` if not already
pushing. Transaction does **not** run.

**Must print**

```text
── 4 ── flight on-block, doors still open, PUSH refused
[tug] refuse push: doors-open
  status=onBlock (not pushing)
```

**Must not happen:** `[tug] committed`; chocks off.

---

### Step 5 — doors closed, PUSH BA482 commits + clearance

**Lesson:** `Cell.transaction` moves `chocksOn=false` and
`status=pushing` together; radio runs only after commit.

**Drive**

```dart
turn.doorsIn.emit(true);
await _tick();
await turn.drivePushDirect(seedFlight);
```

1. `[doors] closed`, `doorsClosed` state is true.
2. Guard passes.
3. `tx.begin([chocksOn, status])`; status is not pushing;
   update chocks false + status pushing; `commit`.
4. `requestPush('BA482')` → `CLR-BA482-1`.
5. `clearance.update(issued)`.

**Must print**

```text
── 5 ── doors closed, PUSH BA482 — transaction commits
[doors] closed
[tug] committed pushing chocks=false doors=true
[tug] clearance CLR-BA482-1
  status=pushing chocksOn=false
```

**Must not happen:** pushing with chocks still on. Fuel is
not written here.

---

### Step 6 — second PUSH → one occupant on the tug

**Lesson:** commit-time lock.

**Drive:** `await turn.drivePushDirect(seedFlight);`

`tx.read(status)` is `pushing` → rollback →
`StateError('pushing')`.

**Must print**

```text
── 6 ── second PUSH — expect pushing refusal
[tug] refuse push: pushing
  status=pushing (still pushing, one commit)
```

No second clearance id, no second chocks flip.

---

### Step 7 — radio dead after the transaction commits

**Lesson:** txApply **semantics**. Status stays `pushing`;
clearance is cancelled.

**Drive**

```dart
turn.radioDead = true;
turn.radioAttempts = 0;
turn.lastClearanceWasCancelled = false;
turn.status.update(StandStatus.onBlock);
turn.chocksOn.update(true);
turn.doorsClosed.update(true);
await turn.drivePushDirect(seedFlight);
```

Transaction commits again. `requestPush` throws
`StateError('headset timeout')` on attempt 1.
`lastClearanceWasCancelled = true`.

**Must print**

```text
── 7 ── radio dead on first request
[tug] committed pushing chocks=false doors=true
[tug] radio failed (Bad state: headset timeout); cancelled=true
  status=pushing cancelled=true
```

**Must not happen:** `status=onBlock` after the jam (that
would be return-to-stand). No clearance id for this attempt.

---

### Step 8 — radio lives → real clearance id

**Drive:** same reset as 7, `radioDead = false`, then
`drivePushDirect(U2871)`.

**Must print**

```text
── 8 ── radio lives
[tug] committed pushing chocks=false doors=true
[tug] clearance CLR-U2871-1
  status=pushing clearance=CLR-U2871-1
```

`U2871` must pass `^[A-Z][A-Z0-9][0-9]{1,4}$`. The
two-letter-only pattern rejects it and breaks this step
and step 10.

---

### Step 9 — ramp log hides the surname

**Lesson:** `Cell.derive` masks; `Cell.sanitized` is the node
observers bind.

**Drive:** `turn.pnrRaw.update('Ada Lovelace');`

Gate screen may still read `pnrRaw`. `rampLog` must not
contain `Lovelace`. Derive-first so this step does not
depend on `Pulse.sensitivity`.

**Must print**

```text
── 9 ── pnrRaw = Ada Lovelace; rampLog hides surname
[log] Ada ***
  auditContainsLovelace=false
```

---

### Step 10 — switchMap follows the latest flight

**Lesson:** `acarsIn` → `Cell.switchMap` →
`Cell.asyncMap(..., latestOnly: true)`.

**Drive** (no delay between emits)

```dart
turn.acarsIn.emit(FlightOnBlock(flight: 'BA482', ...));
turn.acarsIn.emit(FlightOnBlock(flight: 'U2871', ...));
```

Do **not** emit these on `flightIn`. That path is the tug.
`acarsLast` is written by the `acarsIn` observer.

A `ACARS-ACK BA482` line before U2871 is acceptable if the
first future already started. The **last** value must be
`U2871`.

**Must print**

```text
── 10 ── flight BA482 then immediately U2871
[acars] ACARS-ACK U2871
  acarsLast=U2871
```

---

### Step 11 — fromFuture slot quote

Created in `install()`. The `[slot] 18` line usually printed
during Seed. This step only points at it.

```text
── 11 ── fromFuture slot quote
  slot quote observed above (see [slot])
```

Do not construct a second `fromFuture` here.

---

### Step 12 — GPU open slot binds after boot

**Lesson:** `Cell.open`.

**Drive**

```dart
final unlinker = (turn.gpuSlot as dynamic).link(turn.clearance.cell);
```

**Must print**

```text
── 12 ── GPU open slot after boot
  gpu open bound=true
```

A clearance call *through the slot* before this step must
fail closed. Steps 5–8 call the headset mock on the harness
directly, so they stay valid.

---

### Step 13 — HOLD goes to the board only

**Lesson:** hub isolation.

**Drive**

```dart
final boardBefore13 = turn.hubBoard.length;
turn.hub.emit(Pulse<Object>('wx-hold', type: 'HOLD'));
final newEntries = turn.hubBoard.skip(boardBefore13);
```

Emit **on `hub`**, and score the **new** tail via
`skip(boardBefore13)` so earlier PUSH lines do not
masquerade as the HOLD.

Spoke returns `null`. Chocks and status stay at step-8
values. `pushRoutedCount` does not move.

**Must print**

```text
── 13 ── HOLD wx-hold — board only, chocks/status unchanged
  boardAdded=HOLD wx-hold chocksUnchanged=true statusUnchanged=true
```

---

### Step 14 — negative fuel rejected at ingress

**Lesson:** same TestCell family as step 3, different payload.

**Drive:** `turn.fuelIn.emit(-1);`

Fuel rule `v >= 0` fails. `fuelKg` stays non-negative.
Hub FUEL spoke does not run.

**Must print**

```text
── 14 ── fuel tap -1 — TestCell reject
  fuel rejected delta=0 fuelKg=0 (was 0)
```

---

### Trailer (after step 14)

```text
status=pushing chocksOn=false doorsClosed=true
auditContainsLovelace=false
clearance=CLR-U2871-1
acarsLast=U2871
```

| Field | Why |
|---|---|
| `status=pushing` | last successful push (step 8) |
| `chocksOn=false` | committed with that push; HOLD did not touch it |
| `doorsClosed=true` | closed in step 5, never re-opened |
| `auditContainsLovelace=false` | step 9 still holds |
| `clearance=CLR-U2871-1` | last happy radio, not the jammed attempt |
| `acarsLast=U2871` | switchMap latest-only on `acarsIn` |

Then `turn.dispose()` stops every `EgressHandle`.

---

## Pulse path (scenario 5)

```
doorsIn.emit(true)
flightIn.emit(BA482)
  TestCell pass
  switchMap latest
  observe
    synthesis turnView  A12 fuel=0 bridge=… chocks=on doors=closed
    PUSH (throttled)
      transaction
        status.read not pushing
        doorsClosed.read true
        chocksOn.update false
        status.update pushing
        commit
      requestPush BA482  → CLR-BA482-1
      acars asyncMap     → ACARS-ACK BA482
```

Scenario 3 stops at `standIn.emit`. Scenario 7 runs compensate
on the clearance only.

---

## Real ramp vs this file

| Still missing | Stay on Cell core |
|---|---|
| Multi-stand terminal | more `state` Cells + one tx per stand |
| Load sheet / LIR | `fromStream` of DCS messages |
| De-icing pad | another `ingress` + `hub` type `DEICE` |
| Passenger PII vault | `sanitized` is display redaction, not a vault |
| Durable ACARS | same `state` Cells in front of a store |

No Flow gate. No Tissue ledger. Ramp log is a **sanitized
Cell**, not an append-only collection type.

---

## Acceptance

1. `dart run aircraft-gate-turnaround-Demo.dart` matches the
   **Result** column.
2. `pubspec` / imports: `package:cell/cell.dart` only (plus
   `dart:async`). Grep the demo for `cell_flow`, `cell_tissue`,
   `FlowInstruction`, `TissueList`, `TestTissue` — **zero** hits.
3. Grep shows `Cell.synthesis`, `Cell.hub`, `Cell.sanitized`,
   `Cell.transaction`, `Cell.txApply` (name in header or call),
   `Cell.debounce`, `Cell.distinct`, `Cell.throttle`,
   `Cell.switchMap`, `Cell.asyncMap` (or `Cell.fromFuture`),
   `Cell.open`.
4. Scenario 3 and 14 print TestCell rejection.
5. Scenario 4 refuses with doors open; no chocks-off.
6. Scenario 6 only one pushing commit.
7. Scenario 7 cancels clearance and leaves `status==pushing`.
8. Scenario 9: ramp-log payload does not contain `Lovelace`.
9. Scenario 10 last ACARS id is `U2871`.
10. Scenario 13 HOLD does not change chocks or status.
11. Header lists the forbidden packages.
12. Industry is airside turnaround, not a hotel desk clone
    (no `Reservation`, no `folio`, no `HkStatus`).

---

## Name plate

| Artifact | Name |
|---|---|
| This requirement / walkthrough | `aircraft-gate-turnaround-WalkThrough.md` |
| Demo to implement next | `aircraft-gate-turnaround-Demo.dart` |

Airside + **Cell core only**. Do not rename the hotel, pharmacy,
or Flow/Tissue industry files. The hotel walkthrough remains
the hospitality lesson; this file is a stand, a tug, and a
headset.
