# Walkthrough requirement — hotel front-desk check-in (Cell core only)

**Suggested demo:** `hotel-front-desk-checkin-Demo.dart`  
**Stack:** `package:cell` **only**  
**Forbidden:** `package:cell_flow`, `package:cell_tissue`, `Flow.*`,
`FlowInstruction`, `MapValue`, `Filter` as a Flow class, `TissueList`,
`TissueValue`, `TestTissue`, `toHandle` from Flow.

**Industry:** hotel property management / front-desk check-in  
(the desk everyone has stood at: look up a reservation, refuse a dirty
or occupied room, encode a key, post a folio, and undo the key if the
encoder jams). Not a pharmacy robot, not a card switch, not a cab
match, not a grid shed.

Siblings that this file is **not**:

| File | Why it is a different lesson |
|---|---|
| `WalkThrough-pharmacy-dispense-transaction.md` | till + robot drawer; this file is rooms + PII + hub |
| `card-auth-pipeline(tissue)-WalkThrough.md` | Tissue books + Flow gates |
| `ride-hail-dispatch(tissue)-WalkThrough.md` | mobility |
| `grid-demand-response(tissue)-WalkThrough.md` | Hz / MW |
| `ICU-alarm-pipeline(enhanced)-WalkThrough.md` | Flow PAGE/WARN |

This is the **executable requirement** for a Cell-core hospitality
demo. Implement the Dart file so a last-good run prints the scenario
table in § Scenarios.

The lesson: Groups 1–4 plus Atomic from `package:cell` are enough for
a real desk. Do not reach for Flow because you miss `Filter`. Use
`Cell.derive` + `TestCell` + `Cell.distinct`. Do not reach for Tissue
because you miss a list. Use `Cell.state<List<…>>` only as a local
harness printer, or print from `Cell.observe` — the system of record
in this demo is **named state Cells**, not a collection type.

---

## Contents

1. [Allowed Cell surface (and nothing else)](#allowed-cell-surface-and-nothing-else)
2. [Problem](#problem)
3. [Design](#design)
4. [Domain](#domain)
5. [Cells](#cells)
6. [Synthesis, hub, sanitize](#synthesis-hub-sanitize-the-parts-pharmacy-did-not-show)
   - [`Cell.synthesis`](#cellsynthesis)
   - [`Cell.hub`](#cellhub)
   - [`Cell.sanitized`](#cellsanitized)
   - [`Cell.open`](#cellopen)
7. [`Cell.transaction` — room + folio together](#celltransaction--room--folio-together)
8. [`Cell.txApply` — key encoder with compensate](#celltxapply--key-encoder-with-compensate)
9. [Implementation map](#implementation-map)
10. [Scenarios](#scenarios)
11. [Executable steps (Seed + 1–14)](#executable-steps-seed--114)
    - [Seed](#seed--bind-the-graph-room-412-hk-clean-door-closed)
    - [Step 1 — door chatter](#step-1--door-chatter-collapses-to-one-quiet-pulse)
    - [Step 2 — folio tap-spam](#step-2--folio-tap-spam--one-folio-routed)
    - [Step 3 — bad room code](#step-3--bad-room-code-rejected-at-ingress)
    - [Step 4 — HK dirty, no transaction](#step-4--hk-dirty-then-reserve--no-transaction)
    - [Step 5 — atomic commit + key](#step-5--hk-clean--reserve-c-9182--atomic-commit--key)
    - [Step 6 — second RESERVE](#step-6--second-overlapping-reserve--one-occupant)
    - [Step 7 — encoder jam](#step-7--encoder-jam-after-occupancy-commits)
    - [Step 8 — encoder succeeds](#step-8--encoder-succeeds)
    - [Step 9 — night audit](#step-9--night-audit-hides-the-surname)
    - [Step 10 — switchMap](#step-10--switchmap-follows-the-latest-reservation)
    - [Step 11 — rate quote](#step-11--fromfuture-rate-quote)
    - [Step 12 — encoder open](#step-12--open-encoder-slot-binds-after-boot)
    - [Step 13 — HOUSEKEEP isolation](#step-13--housekeep-goes-to-the-board-only)
    - [Step 14 — negative folio](#step-14--negative-folio-tap-rejected-at-ingress)
    - [Trailer](#trailer-after-step-14)
12. [Pulse path (scenario 5)](#pulse-path-scenario-5)
13. [Real PMS vs this file](#real-pms-vs-this-file)
14. [Acceptance](#acceptance)
15. [Name plate](#name-plate)

---

## Allowed Cell surface (and nothing else)

From the library doc attached to this request:

| Group | Operator | Role in this demo |
|---|---|---|
| 1 Essential | `Cell.state` | room vacant/occupied, folio cents, encoder target |
| 1 | `Cell.ingress` | reservation swipe, room number, encoder ACK |
| 1 | `Cell.derive` | “is this room vacant and clean?” |
| 1 | `Cell.observe` | print, enqueue key-encode, post folio |
| 2 Flow control | `Cell.debounce` | door-contact chatter on the room sensor |
| 2 | `Cell.distinct` | do not re-assign the same room status |
| 2 | `Cell.throttle` | folio tap-spam on the POS glass |
| 2 | `Cell.synthesis` | reservation + HK status + occupancy → `DeskView` |
| 3 Async | `Cell.asyncMap` | PMS write / key-encode HTTP mock |
| 3 | `Cell.switchMap` | follow the **latest** reservation only |
| 3 | `Cell.fromFuture` | one-shot rate quote |
| 4 Governance | `Cell.hub` | route `RESERVE` / `HOUSEKEEP` / `FOLIO` pulse types |
| 4 | `Cell.sanitized` | guest name / card last-four never hit the log Cell |
| 4 | `Cell.open` | late-bind the encoder Cell after the desk boots |
| Atomic | `Cell.transaction` | occupancy + folio commit together |
| Atomic | `Cell.txApply` | encode key; compensate by voiding the key |
| Governance | `TestCell` | room id `NNN` / `NNN-N`, folio cents ≥ 0 |

`Receptor` may appear only as whatever `Cell.ingress` / `Cell.derive`
already install. Do **not** build an `InstructionChain`.

---

## Problem

A guest arrives. The desk must:

1. Reject a garbage room code at **ingress** (`TestCell`), not after
   the folio moves.
2. See **one** desk picture: reservation + housekeeping + occupancy
   (`Cell.synthesis`). Door contacts chatter — `Cell.debounce` them.
3. Route three pulse *kinds* without three ad-hoc if-ladders
   (`Cell.hub`: `RESERVE`, `HOUSEKEEP`, `FOLIO`).
4. Never write the guest’s full name or PAN to the night-audit Cell
   (`Cell.sanitized`).
5. Mark the room occupied and post the night rate **together**
   (`Cell.transaction`). A crash must not leave “occupied, folio 0”
   or the reverse.
6. Encode a door key; if the encoder jams after memory committed,
   void the key (`Cell.txApply` + `compensate`).
7. Two overlapping check-ins must not take the last vacant king.
   Locks run at **commit**.
8. A late-arriving encoder module must still bind (`Cell.open`).

That is not a Flow PAGE/WARN gate. That is synthesis, hub, sanitize,
commit, compensate.

---

## Design

```
resIn     ingress<Reservation>  ── TestCell (conf # non-empty)
roomIn    ingress<String>       ── TestCell (room shape)
doorIn    ingress<bool>         ── debounce 400 ms
hkIn      ingress<HkStatus>
folioTap  ingress<int>          ── throttle 300 ms, TestCell cents ≥ 0

                │
                ▼
         Cell.synthesis → deskView : DeskView
                │
                ├─ Cell.distinct(status)
                │
                ▼
         Cell.hub
            ├─ type RESERVE   → assign path
            ├─ type HOUSEKEEP → hk board only
            └─ type FOLIO     → folio path

assign path
  Cell.switchMap → latest reservation only
  Cell.observe → Cell.transaction(occupied, folio)
                 Cell.txApply(encoder, compensate: voidKey)
                 Cell.asyncMap  PMS post

guestRaw ── Cell.sanitized → nightAudit  (name redacted)

encoderSlot ── Cell.open     bound after boot
```

| Requirement | Owner |
|---|---|
| Bad room code / negative folio | `TestCell` on **ingress** |
| Door chatter | `Cell.debounce` |
| Folio double-tap | `Cell.throttle` |
| One desk picture | `Cell.synthesis` |
| Skip same status | `Cell.distinct` |
| Latest reservation wins | `Cell.switchMap` |
| Kinded events | `Cell.hub` |
| PII off the audit Cell | `Cell.sanitized` |
| Occupied + folio together | `Cell.transaction` |
| Key encoder + undo | `Cell.txApply` |
| Late encoder | `Cell.open` |
| PMS I/O | `Cell.asyncMap` / `Cell.fromFuture` |
| Side effects | `Cell.observe` only |

Do **not** put `encoder.encode()` inside `Cell.derive`. Derive is
pure. I/O lives in `observe` / `asyncMap` / `txApply`.

Do **not** sanitize by `replaceAll` inside `observe`. The audit Cell
is a **sanitized** node so a future observer cannot “forget.”

---

## Domain

```dart
enum HkStatus { dirty, clean, inspect }

enum RoomStatus { vacant, assigned, occupied, ooo }

final class Reservation {
  const Reservation({
    required this.conf,
    required this.guestName,
    required this.rateCents,
    required this.roomType, // 'KING' | 'TWIN'
  });
  final String conf;
  final String guestName;
  final int rateCents;
  final String roomType;
}

final class DeskView {
  const DeskView({
    required this.conf,
    required this.room,
    required this.hk,
    required this.occupied,
    required this.doorOpen,
  });
  final String? conf;
  final String room;
  final HkStatus hk;
  final bool occupied;
  final bool doorOpen;
}
```

Pulse **types** the hub keys on (use whatever `Pulse.type` / routing
field `Cell.hub` expects in this cell build — match the operator
demo in-tree, do not invent a second hub API):

| Type | Payload | Goes to |
|---|---|---|
| `RESERVE` | `Reservation` | assign / transaction |
| `HOUSEKEEP` | `HkStatus` | board printer only |
| `FOLIO` | `int` cents | folio tap path |

---

## Cells

| Cell | Kind | Holds |
|---|---|---|
| `resIn` | ingress + TestCell | raw reservation |
| `roomIn` | ingress + TestCell | `'412'` / `'412-A'` |
| `doorIn` | ingress | reed switch |
| `hkIn` | ingress | HK status |
| `folioTap` | ingress + TestCell | cents |
| `doorQuiet` | `Cell.debounce(doorIn)` | stable open/closed |
| `deskView` | `Cell.synthesis` | `DeskView` |
| `status` | `Cell.state<RoomStatus>` | vacant…ooo |
| `occupied` | `Cell.state<bool>` | in-house flag |
| `folio` | `Cell.state<int>` | posted cents |
| `encoder` | `Cell.state<String?>` | encoded key id |
| `guestRaw` | `Cell.state<String>` | full name (front desk only) |
| `nightAudit` | `Cell.sanitized(guestRaw)` | redacted |
| `pms` | `Cell.asyncMap` off assign | last PMS ack |
| `quote` | `Cell.fromFuture` | one rate check |
| `encoderSlot` | `Cell.open` | bound encoder after boot |

Seed: room `412`, `HkStatus.clean`, `occupied=false`, `folio=0`,
`status=vacant`, encoder unbound until scenario “OPEN”.

`TestCell` examples (adapt to the exact `TestCell` constructor in
this cell build):

```dart
final roomShape = TestCell<String>(
  (v, {cell, user}) =>
      RegExp(r'^\d{3}(-[A-Z])?$').hasMatch(v ?? ''),
);

final centsNonNeg = TestCell<int>(
  (v, {cell, user}) => (v ?? -1) >= 0,
);
```

There is **no** `TestTissue` in this file.

---

## Synthesis, hub, sanitize (the parts pharmacy did not show)

### `Cell.synthesis`

```dart
final deskView = Cell.synthesis<DeskView>(
  [resIn.cell, roomIn.cell, hkIn.cell, occupied.cell, doorQuiet],
  (values) => DeskView(/* project the five payloads */),
);
```

Use the real `Cell.synthesis` signature from this tree (named
`sources` vs list — match source, do not guess a Flow zip).

A check-in observe reads **`deskView`**, not the five raw ingresses.
If HK is still `dirty`, the transaction must not run.

### `Cell.hub`

One ingress of mixed pulses is acceptable if that is how hub is
demoed in-tree; otherwise three typed ingresses that `hub` merges.
The requirement is: HOUSEKEEP pulses never enter the folio
transaction.

### `Cell.sanitized`

```dart
final nightAudit = Cell.sanitized<String>(
  guestRaw,
  // redaction policy from this cell build
);
```

Scenario SANITIZE: set `guestRaw` to `'Ada Lovelace'`, observe
`nightAudit` — payload must not contain `Lovelace`. Front-desk
screen may still read `guestRaw`. Night audit must not.

### `Cell.open`

Boot creates `encoderSlot` empty. Scenario OPEN binds the encoder
state Cell. A `txApply` before bind must no-op or fail closed,
never encode a ghost key.

---

## `Cell.transaction` — room + folio together

```dart
await Cell.transaction((tx) async {
  final taken = occupied.read(tx: tx) as bool;
  final hk = /* from latest DeskView, not a stale local */;
  if (taken) throw StateError('occupied');
  if (hk != HkStatus.clean) throw StateError('dirty');
  occupied.update(true, tx: tx);
  folio.update(rateCents, tx: tx);
  status.update(RoomStatus.occupied, tx: tx);
});
```

Locks are taken at **commit**, not for the whole `begin`…`commit`
window. Two overlapping check-ins: only one commit sees
`taken == false`.

Do not `folio.update` outside this transaction on the happy path.

---

## `Cell.txApply` — key encoder with compensate

```dart
await Cell.txApply((tx) async {
  await encoder.apply(
    (current) async {
      final id = await keyMachine.encode(room);
      return id;
    },
    tx: tx,
    compensate: (issued) async {
      if (issued != null) await keyMachine.voidKey(issued);
      return null;
    },
  );
});
```

If the mock encoder throws after `occupied` already committed,
`compensate` voids the key. Memory occupancy stays (the guest is
in-house); the **credential** is what rolls back. Do not invent a
second transaction that secretly un-checks-in — that is a different
product (early departure).

`txApply` is **not** a second way to assign `encoder.value`.

---

## Implementation map

| Block in the dart file | What |
|---|---|
| Header / expected output | talk track; list forbidden imports |
| Domain types | `Reservation` / `DeskView` / enums |
| `roomShape` / `centsNonNeg` | TestCell |
| ingress + debounce + throttle | Group 1–2 |
| `deskView` synthesis + distinct | one picture |
| hub wiring | RESERVE / HOUSEKEEP / FOLIO |
| sanitized night audit | PII |
| `open` encoder slot | late bind |
| observe → transaction + txApply | Atomic |
| asyncMap / fromFuture | PMS + quote |
| `main` | seed + scenarios |

---

## Scenarios

Seed reservation `C-9182`, guest `Ada Lovelace`, rate `18900`, type
`KING`, room `412`, HK `clean`, door closed, folio `0`.

| # | Drive | Result | Demonstrates |
|---|---|---|---|
| Seed | bind observers | deskView prints 412 / clean / vacant | synthesis |
| 1 | door open/close 5× in 100 ms | **one** quiet door pulse | `debounce` |
| 2 | folio tap 18900 three times in 50 ms | **one** FOLIO routed | `throttle` + `hub` |
| 3 | `roomIn.emit('41')` | TestCell reject; no synthesis bump | ingress boundary |
| 4 | HK `dirty`, then RESERVE | no transaction; occupied stays false | derive/synthesis guard |
| 5 | HK `clean`, RESERVE `C-9182` | occupied true, folio 18900 | `transaction` |
| 6 | second overlapping RESERVE | one `StateError('occupied')` | commit-time lock |
| 7 | encoder jam on first encode | key voided; occupied still true | `txApply` compensate |
| 8 | encoder succeeds | `encoder` holds a key id | apply |
| 9 | `guestRaw` Ada Lovelace | nightAudit has no `Lovelace` | `sanitized` |
| 10 | new conf `C-9200` then immediately `C-9201` | PMS / switchMap follows **9201** | `switchMap` |
| 11 | `fromFuture` rate quote | one quote print | `fromFuture` |
| 12 | encoder `Cell.open` after boot | encode works only after bind | `open` |
| 13 | HOUSEKEEP pulse `inspect` | board print; folio unchanged | hub isolation |
| 14 | folio tap `-1` | TestCell reject | cents rule |

Trailer the talk track can read:

```text
occupied=true folio=18900 status=occupied
auditContainsLovelace=false
encoder=… (id or voided-then-id)
pmsLast=C-9201
```

The next section is the talk-track for `main()` in
`hotel-front-desk-checkin-Demo.dart`. Each step names the drive,
the operators that fire, what must print, and what must **not**
happen. Implement `main` in this order. Do not reorder: later
steps assume occupancy / folio / last key from earlier ones,
except 7 and 8 which reset occupancy on purpose.

---

## Executable steps (Seed + 1–14)

These are the steps the demo actually runs. Numbers match the
`── N ──` banners in the console. Seed is unnumbered but required:
without the mirrors (`roomView` / `hkView` / `doorView`) the
synthesis picture in later steps is empty.

`TestCell` on this build is **`TestCell<Cell>`**. The predicate
unwraps `Pulse.payload` when the stimulus is a pulse. Returning
`true` for a non-matching runtime type lets the wrapper pass; only
the **payload** is rejected. Ingress still uses
`Cell.ingress<Reservation>` / `ingress<String>` / `ingress<int>`.

`Cell.hub` returns a **record**
`({emit, emitAsync, ingest, root, spokes})`. Observe
`hub.root`. Inject with `hub.emit`. There is no `hub.cell`.

`Cell.synthesis` is `Cell.synthesis<Pulse<DeskView>>`. The
aggregator reads `.value` on **mirror State Cells**, not raw
ingresses (ingress cells have no synchronous `.value`).

Throttle in the demo is `Cell.throttle(..., 300 ms, leading: true,
trailing: false)` so the first folio tap is not swallowed.
Debounce on the door is **40 ms** in the executable (the 400 ms
figure above is the product-scale default; the harness shortens it
so the run stays under a second).

Encoder compensate in the executable is a direct `try` / `catch`
around `encodeKey` + `voidKey`. That is the **txApply contract**
(credential rolls back, occupancy stays) without depending on a
particular `ApplyTransactionScope` begin API.

### Seed — bind the graph, room 412, HK clean, door closed

**Drive**

```dart
desk.roomIn.emit('412');
desk.hkIn.emit(HkStatus.clean);
desk.doorIn.emit(false);
```

**What fires**

- `roomIn` TestCell accepts `412` (`NNN`). Observer writes
  `roomView`.
- `hkIn` observer sets `_lastHk = clean` and `hkView`.
- `doorIn` → `Cell.debounce` (40 ms) → `doorView = false`.
- `Cell.synthesis` emits `DeskView(conf=null, room=412, hk=clean,
  occupied=false, doorOpen=false)`.
- `Cell.fromFuture` rate quote may print `[quote] 18900` during
  seed (it is created at `install`, not in step 11).
- `status` remains `vacant`.

**Must print**

```text
── Seed ── bind observers; door closed; HK clean; room 412
[deskView] room=412 hk=clean occ=false door=false conf=null
[hk] clean
  status=vacant
```

`[quote] 18900` may appear here or shortly after; step 11 only
points at that earlier line.

**Must not happen**

- No check-in transaction (no reservation yet).
- No folio write.
- No encoder call.

---

### Step 1 — door chatter collapses to one quiet pulse

**Lesson:** `Cell.debounce` on a reed switch.

**Drive**

Five open/close pairs in ~100 ms, 5 ms apart, then wait 100 ms
for the debounce window:

```dart
for (var i = 0; i < 5; i++) {
  desk.doorIn.emit(true);
  await Future.delayed(const Duration(milliseconds: 5));
  desk.doorIn.emit(false);
  await Future.delayed(const Duration(milliseconds: 5));
}
await Future.delayed(const Duration(milliseconds: 100));
```

**What fires**

- Raw `doorIn` chatters 10 times.
- `Cell.debounce(doorIn, 40 ms)` holds until silence.
- One quiet pulse reaches the door observer; `doorQuietCount`
  increments once (or a small number far below 10).
- Synthesis may bump if `doorView` changes; the talk-track
  cares about **quiet pulse count**, not bump count.

**Must print**

```text
── 1 ── door open/close 5× in 100 ms
[door] quiet → false (pulse #1)
  doorQuiet pulses: 1
```

Accept `doorQuiet pulses` in `{1, 2}` if the last edge equals
the seeded closed state and debounce still emits a trailing
settled value. Fail the run if the count is ≥ 5 (debounce not
wired).

**Must not happen**

- Ten `[door]` lines.
- Occupancy or folio changes.

---

### Step 2 — folio tap-spam → one FOLIO routed

**Lesson:** `Cell.throttle` + `Cell.hub` type `FOLIO`.

**Drive**

```dart
desk.folioTap.emit(18900); // ×3, 5 ms apart
await Future.delayed(const Duration(milliseconds: 350));
```

**What fires**

- `folioTap` TestCell accepts `18900` (≥ 0).
- `Cell.throttle(300 ms, leading: true, trailing: false)` lets
  the **first** tap through and drops the rest of the burst.
- Observer wraps the cents as `Pulse<Object>(18900, type: 'FOLIO')`
  on `hubIn`.
- Hub spoke `FOLIO` increments `folioRoutedCount` and calls
  `_postFolio`. It does **not** write the folio State Cell
  (that write is reserved for the check-in transaction).

**Must print**

```text
── 2 ── folio tap 18900 three times in 50 ms
[folio] routed 18900¢
  FOLIO routed: 1
```

**Must not happen**

- Three routed FOLIO lines.
- `folio` State Cell jumping to 18900 (still 0 until step 5).
- First tap swallowed (`leading: false` would fail this step).

---

### Step 3 — bad room code rejected at ingress

**Lesson:** `TestCell` on `roomIn`, before synthesis.

**Drive**

```dart
final accepted = desk.roomIn.emit('41');
```

**What fires**

- Room rule: `^\d{3}(-[A-Z])?$`. `'41'` is two digits.
- Ingress returns a falsy accepted flag.
- `roomView` is **not** updated. Synthesis bump delta is 0.

**Must print**

```text
── 3 ── roomIn.emit('41') — TestCell reject
  ingress accepted=false  synthBumps delta=0
```

**Must not happen**

- `[deskView]` with `room=41`.
- Any transaction.

---

### Step 4 — HK dirty, then RESERVE — no transaction

**Lesson:** check-in guard reads live HK (`_lastHk` / `hkView`),
not a stale local. PMS I/O still runs (`asyncMap` is not the
transaction).

**Drive**

```dart
desk.hkIn.emit(HkStatus.dirty);
desk.resIn.emit(Reservation(conf: 'C-9182', guestName: 'Ada Lovelace',
    rateCents: 18900, roomType: 'KING'));
```

**What fires**

- HK observer: `_lastHk = dirty`, print `[hk] dirty`.
- `resIn` TestCell accepts non-empty conf.
- `Cell.switchMap` builds an inner cell for `C-9182`.
- Check-in observer calls `_tryCheckIn` → refuse, no
  `Cell.transaction`.
- `Cell.asyncMap` on `latestRes` still posts `PMS-ACK C-9182`.
- `occupied` stays `false`. Folio stays `0`.

**Must print**

```text
── 4 ── HK dirty, then RESERVE — no transaction
[hk] dirty
[desk] refuse check-in: hk=dirty
[pms] PMS-ACK C-9182
  occupied=false
```

**Must not happen**

- `[desk] committed`.
- `[desk] key issued`.
- `occupied=true`.

---

### Step 5 — HK clean + RESERVE C-9182 — atomic commit + key

**Lesson:** `Cell.transaction` moves `occupied` + `folio` +
`status` together; encoder runs only after commit.

**Drive**

```dart
desk.hkIn.emit(HkStatus.clean);
desk.resIn.emit(Reservation(conf: 'C-9182', ...)); // same guest
```

**What fires**

1. `_lastHk = clean`.
2. `switchMap` follows `C-9182` again.
3. `_tryCheckIn`:
   - `tx.begin([occupied, folio, status])`.
   - `tx.read(occupied)` is false.
   - `tx.update` occupied `true`, folio `18900`, status
     `occupied`.
   - `tx.commit()`.
4. `encodeKey('C-9182')` succeeds → `KEY-C-9182-1` (or
   `KEY-C-9182-<n>` if earlier attempts incremented the mock).
5. `encoder.update(issued)`.
6. PMS ack `C-9182`.

**Must print**

```text
── 5 ── HK clean, RESERVE C-9182 — transaction
[hk] clean
[desk] committed occupied=true folio=18900
[desk] key issued: KEY-C-9182-1
[pms] PMS-ACK C-9182
  occupied=true folio=18900
```

**Must not happen**

- Occupied true with folio still 0 (partial commit).
- Encoder running **inside** `Cell.derive`.

---

### Step 6 — second overlapping RESERVE — one occupant

**Lesson:** commit-time occupancy guard. Locks are taken at
commit, not for the whole begin…commit window.

**Drive**

```dart
desk.resIn.emit(Reservation(conf: 'C-9183', guestName: 'Grace Hopper', ...));
```

**What fires**

- `switchMap` switches to `C-9183`.
- Transaction begins, `tx.read(occupied)` is true, `rollback`,
  `StateError('occupied')`.
- No second folio post. Status stays `occupied`.
- PMS still acks `C-9183` (I/O is not the lock).

**Must print**

```text
── 6 ── second RESERVE — expect occupied refusal
[desk] refuse check-in: occupied
[pms] PMS-ACK C-9183
  occupied=true (still true, one commit)
```

**Must not happen**

- A second `[desk] committed`.
- Folio changing to a second rate.
- Two key ids issued for two in-house guests on one room.

---

### Step 7 — encoder jam after occupancy commits

**Lesson:** txApply **semantics**. Occupancy stays; credential
is compensated.

**Drive** (reset the room first so the guard does not refuse)

```dart
desk.encoderJammed = true;
desk.encodeAttempts = 0;
desk.lastEncoderWasVoided = false;
desk.occupied.update(false);
desk.folio.update(0);
desk.status.update(RoomStatus.vacant);

desk.resIn.emit(Reservation(conf: 'C-9184', guestName: 'Alan Turing', ...));
```

**What fires**

1. Transaction commits again: occupied true, folio 18900.
2. `encodeKey` throws `StateError('encoder jammed')` on attempt 1.
3. `issued` is still null (throw before return) → no
   `voidKey(id)`, but `lastEncoderWasVoided = true` so the
   harness records the compensate path.
4. Occupancy is **not** rolled back. The guest is in-house;
   only the key is missing.

**Must print**

```text
── 7 ── encoder jam on first encode
[desk] committed occupied=true folio=18900
[desk] key encoder failed (...encoder jammed...); key voided=true
[pms] PMS-ACK C-9184
  occupied=true keyVoided=true
```

**Must not happen**

- `occupied=false` after the jam (that would be an early
  departure product, not compensate).
- A printed key id for C-9184.

---

### Step 8 — encoder succeeds

**Lesson:** happy-path encode after a jam; persist id on the
encoder State Cell.

**Drive**

```dart
desk.encoderJammed = false;
desk.encodeAttempts = 0;
desk.lastEncoderWasVoided = false;
desk.occupied.update(false);
desk.folio.update(0);
desk.status.update(RoomStatus.vacant);

desk.resIn.emit(Reservation(conf: 'C-9185',
    guestName: 'Katherine Johnson', ...));
```

**What fires**

- Same transaction as step 5.
- `encodeKey('C-9185')` returns `KEY-C-9185-1`.
- `lastKeyId` and `encoder` State Cell hold that id.

**Must print**

```text
── 8 ── encoder succeeds
[desk] committed occupied=true folio=18900
[desk] key issued: KEY-C-9185-1
[pms] PMS-ACK C-9185
  occupied=true lastKeyId=KEY-C-9185-1
```

**Must not happen**

- `lastKeyId` still null (encode never ran).
- `keyVoided=true` on this step.

---

### Step 9 — night audit hides the surname

**Lesson:** `Cell.derive` masks; `Cell.sanitized` is the node
observers bind so a future logger cannot “forget.”

**Drive**

```dart
desk.guestRaw.update('Ada Lovelace');
```

Front desk may still read `guestRaw` (`Ada Lovelace`).
`nightAudit` must not contain `Lovelace`.

`Cell.sanitized` on this build only redacts when
`Pulse.sensitivity` meets `minSensitivity`. `Cell.state` often
emits public pulses with no sensitivity, which would skip
redact. The executable therefore **derives** `Ada ***` first,
then wraps that cell in `Cell.sanitized<Pulse>`. Scenario 9
passes even when sensitivity metadata is absent.

**Must print**

```text
── 9 ── guestRaw = Ada Lovelace; nightAudit hides surname
[audit] Ada ***
  auditContainsLovelace=false
```

**Must not happen**

- `[audit] Ada Lovelace`.
- Redaction implemented only as `replaceAll` inside `observe`.

---

### Step 10 — switchMap follows the latest reservation

**Lesson:** `Cell.switchMap` + `asyncMap(..., latestOnly: true)`.

**Drive** (no delay between the two emits)

```dart
desk.resIn.emit(Reservation(conf: 'C-9200', ...));
desk.resIn.emit(Reservation(conf: 'C-9201', ...));
```

**What fires**

- First inner cell for C-9200 is detached when C-9201 arrives.
- Check-in observer may refuse both (room already occupied
  from step 8) — that is fine. This step scores **PMS**, not
  occupancy.
- `pmsLast` must be `C-9201`. A last ack of `C-9200` means
  switchMap / latestOnly is not wired.

**Must print**

```text
── 10 ── new conf C-9200 then immediately C-9201
[pms] PMS-ACK C-9201
  pmsLast=C-9201
```

A `PMS-ACK C-9200` line **before** C-9201 is acceptable if
the first future already started. The **last** value must be
C-9201.

---

### Step 11 — fromFuture rate quote

**Lesson:** `Cell.fromFuture` is a one-shot bridge. It is
created in `install()`, so the `[quote] 18900` line usually
already printed during Seed.

**Drive**

None. The step only points at the earlier emission.

**Must print**

```text
── 11 ── fromFuture rate quote
  quote emission observed above (see [quote])
```

**Must not happen**

- Building the quote Future inside `Cell.derive`.
- A second quote factory in this step (it would double-print).

---

### Step 12 — open encoder slot binds after boot

**Lesson:** `Cell.open` is a late-bound port. The desk boots
with `encoderSlot = Cell.open()` and no encoder module.

**Drive**

```dart
final unlinker = encoderSlot.link(desk.encoder.cell);
```

`link` is the in-tree name on `OpenCell`. If this cell build
uses a different binder, the scenario still requires: a
downstream connection exists **only after** this call, and the
print shows `encoder open bound=true`.

**Must print**

```text
── 12 ── encoder open slot after boot
  encoder open bound=true
```

**Must not happen**

- Encoding a ghost key before bind (steps 5–8 call the mock
  directly on the harness, not through the open slot, so they
  stay valid). A `txApply` that went through the slot **before**
  this step must fail closed.

---

### Step 13 — HOUSEKEEP goes to the board only

**Lesson:** `Cell.hub` isolation. Pulse type `HOUSEKEEP` must
not enter the folio path.

**Drive**

```dart
desk.hubIn.emit(Pulse<Object>(HkStatus.inspect, type: 'HOUSEKEEP'));
```

Wait ≥ 60 ms so `hub.emit` and the spoke finish before reading
`hubBoard.last`.

**What fires**

- Hub spoke `HOUSEKEEP` appends `'HOUSEKEEP HkStatus.inspect'`
  (or equivalent `toString`) to `hubBoard`.
- Spoke returns `null` — no folio spoke, no `_postFolio`.
- Folio State Cell unchanged from step 8 (`18900`).

**Must print**

```text
── 13 ── HOUSEKEEP inspect — board only, folio unchanged
  boardTail=HOUSEKEEP HkStatus.inspect folioUnchanged=true
```

**Must not happen**

- `folioRoutedCount` increment.
- Folio State Cell change.
- An if-ladder in `observe` that routes by payload type
  instead of `Cell.hub`.

---

### Step 14 — negative folio tap rejected at ingress

**Lesson:** same TestCell family as step 3, different payload.

**Drive**

```dart
desk.folioTap.emit(-1);
```

**What fires**

- Cents rule: `v >= 0` fails.
- Throttle never sees a value. Hub FOLIO spoke does not run.
- `folioRoutedCount` delta is 0.

**Must print**

```text
── 14 ── folio tap -1 — TestCell reject
  FOLIO routed delta=0
```

**Must not happen**

- `[folio] routed -1¢`.
- Folio State Cell going negative.

---

### Trailer (after step 14)

After dispose-ready prints:

```text
occupied=true folio=18900 status=occupied
auditContainsLovelace=false
encoder=KEY-C-9185-1
pmsLast=C-9201
```

| Field | Why |
|---|---|
| `occupied=true` | last successful check-in (step 8) still in-house |
| `folio=18900` | posted with that commit; HOUSEKEEP did not touch it |
| `status=occupied` | `Cell.state<RoomStatus>` matches the flag |
| `auditContainsLovelace=false` | step 9 still holds |
| `encoder=KEY-C-9185-1` | last happy encode, not the jammed C-9184 |
| `pmsLast=C-9201` | switchMap latest-only |

Then `desk.dispose()` stops every `EgressHandle`.

---

## Pulse path (scenario 5)

```
resIn.emit(C-9182)
  TestCell pass
  hub RESERVE
  switchMap latest
  observe
    synthesis deskView  412 clean vacant doorClosed
    transaction
      occupied.read false
      occupied.update true
      folio.update 18900
      status.update occupied
      commit
    txApply encoder.encode 412
```

Scenario 3 stops at `roomIn.emit`. Scenario 7 runs compensate on
the encoder Cell only.

---

## Real PMS vs this file

| Still missing | Stay on Cell core |
|---|---|
| Multi-room group block | more `state` Cells + one transaction |
| Channel manager | `fromStream` of OTA notifications |
| Housekeeping app | another `ingress` + `hub` type |
| PCI vault | `sanitized` is display redaction, not a vault |
| Durable folio | same `state` Cells in front of a store |

No Flow gate. No Tissue ledger. Night audit is a **sanitized Cell**,
not an append-only collection type.

---

## Acceptance

1. `dart run hotel-front-desk-checkin-Demo.dart` matches the
   **Result** column.
2. `pubspec` / imports: `package:cell/cell.dart` only (plus
   `dart:async`). Grep the demo for `cell_flow`, `cell_tissue`,
   `FlowInstruction`, `TissueList`, `TestTissue` — **zero** hits.
3. Grep shows `Cell.synthesis`, `Cell.hub`, `Cell.sanitized`,
   `Cell.transaction`, `Cell.txApply`, `Cell.debounce`,
   `Cell.distinct`, `Cell.throttle`, `Cell.switchMap`,
   `Cell.asyncMap` (or `Cell.fromFuture`), `Cell.open`.
4. Scenario 3 and 14 print TestCell rejection.
5. Scenario 6 only one occupant commit.
6. Scenario 7 voids the key and leaves `occupied==true`.
7. Scenario 9: night-audit payload does not contain `Lovelace`.
8. Scenario 10 last PMS id is `C-9201`.
9. Header lists the forbidden packages.

---

## Name plate

| Artifact | Name |
|---|---|
| This requirement / walkthrough | `hotel-front-desk-checkin-WalkThrough.md` |
| Demo to implement next | `hotel-front-desk-checkin-Demo.dart` |

Hospitality + **Cell core only**. Do not rename the Flow/Tissue
industry files. The pharmacy walkthrough remains the first
transaction lesson; this file adds hub, sanitize, synthesis, open,
debounce, and throttle on a front desk.
