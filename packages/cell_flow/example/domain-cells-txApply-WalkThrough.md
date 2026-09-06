# Walkthrough — pharmacy dispense

**Demo:** `example\domain-cells-txApply-Demo.dart`

How **Instruction**, **Receptor**, and **Cells** split a real till: validate
a scan, move stock and a print flag together, move a drawer, undo after a
jam, and keep a last pack from going out twice.

---

## 1. Design requirement

A technician scans an NDC. The system must:

1. Reject anything that is not an NDC **before** stock moves.
2. Decrement the shelf and mark “label printed” **together** or not at all.
3. Open a physical drawer; if the motor or printer fails **after** memory
   committed, put the pack back and close the drawer.
4. Not give the last pack to two scans that arrive in the same instant.
5. Refuse a negative shelf count at the **intake** of stock writes.

That is four different machines. Mixing them in one `async` method hides
which failure is which.

| Requirement | Owner in this demo |
|---|---|
| Is this an NDC? | Instruction chain + Receptor |
| Stock + label agree | `Cell.transaction` on two state Cells |
| Drawer / printer | `_robot` + try/catch + `restorePack` |
| Last pack | commit-time lock (demo: overlapping observers) |
| Negative stock | `TestCell` on `stockIn` ingress |

---

## 2. The three parts (in depth)

### 2.1 Instruction

An `Instruction` is `(pulse) → pulse | null`. No Cell, no lock, no I/O.

```dart
final normalize = FlowInstruction<Cell, Pulse<String>, Pulse<String>>(
  (pulse, {cell, user}) {
    final normalized = (pulse.payload ?? '').trim().toUpperCase();
    return Pulse<String>(normalized);
  },
);

final filterNdc = FlowInstruction<Cell, Pulse<String>, Pulse<String>>(
  (pulse, {cell, user}) {
    final value = pulse.payload ?? '';
    if (!value.startsWith('NDC')) return null; // drop
    return pulse;
  },
);

final gate = normalize + filterNdc; // InstructionChain, stop on null
```

| Trait | Why it matters here |
|---|---|
| Pure | You can unit-test with a `Pulse` and no graph |
| `null` means stop | Invalid NDC never becomes a dispense |
| `+` is one policy | One Receptor, one lock, one identity |
| No `Future` | Do not open the drawer inside `+` |

`MapValue + Filter` from `package:cell_flow` is the same chain with
names. The demo inlines `FlowInstruction` so the two steps are visible.

### 2.2 Receptor

`toHandle` wraps that chain as the cell’s gate:

```dart
_rx = gate.toHandle(
  source: _gun.cell,
  testRule: TestCell.allowAll,
);
```

That is `Receptor.instruction(gate)` + `Nucleus` + output Cell.

| Pulse in | Receptor | Pulse out |
|---|---|---|
| `'  ndc-12345 '` | normalize → `NDC-12345` → filter pass | `NDC-12345` on `rxCell` |
| `'invalid-code'` | normalize → `INVALID-CODE` → filter `null` | **nothing** |
| `''` | normalize → `''` → filter `null` | **nothing** |

`TestCell.allowAll` on the handle means “this Receptor does not add a
second integrity policy.” The NDC rule **is** the Instruction. Stock
integrity lives on a **different** ingress (`stockIn`).

Drive the gun, not the handle:

```dart
_gun.emit('NDC-12345');   // ingress
// _rx.cell is what observers see
```

### 2.3 Cells

| Cell | Kind | Holds | Who writes |
|---|---|---|---|
| `_gun.cell` | ingress | raw scan | `ConfirmGate.scan` |
| `_rx.cell` | Flow output | valid NDC | Receptor |
| `patient` | `Cell.state<String>` | wristband | harness / future tx |
| `stock` | `Cell.state<int>` | packs | `tx.update` in dispense/restore |
| `stockIn` | ingress + `TestCell` | proposed pack count | scenario 6 only in this demo |
| `drawer` | `Cell.state<String?>` | open bin | drawer txs |
| `label` | `Cell.state<bool>` | printed | stock/label txs |

`Cell.observe(source: gate.rxCell)` starts `fullDispense`. That observer
is the **wiring**, not a fourth policy.

`Cell.transaction`:

```dart
final tx = Cell.transaction();
await tx.begin([stock.cell, label.cell]);
final onHand = tx.read(stock.cell) as int;
if (onHand < 1) throw StateError('Out of stock');
tx.update(stock.cell, onHand - 1);
tx.update(label.cell, true);
await tx.commit();
```

Locks are taken at **commit**. A throw before `commit` leaves both cells
as they were. That is requirement 2.

Hardware is **not** a Cell. `_robot.open` / `printLabel` run after
commit. If they throw, `restorePack` is a **new** transaction (stock +1,
label false). That is requirement 3 — compensate, not rollback of the
first tx (that tx already committed).

---

## 3. Pulse path (one successful scan)

```
1.  scan('NDC-12345')
2.  gun ingress Pulse
3.  Receptor: normalize, filter — pass
4.  rx Cell emits 'NDC-12345'
5.  observe → fullDispense
6.  dispenseMemory
      begin(stock, label)
      read 5 / false
      update 4 / true
      commit
7.  openDrawer
      robot.open
      begin(drawer) update 'NDC-12345' commit
8.  printLabel
9.  closeDrawer
      robot.close
      begin(drawer) update null commit
```

If step 8 throws, step 6 is already history. Step 10 is `restorePack`
(stock 4→5, label false) and close.

---

## 4. Scenarios, step by step

### Scenario 1 — happy path

**Setup:** stock 5, label false, drawer closed.  
**Input:** `gate.scan('NDC-12345')`.

| Step | Part | Result |
|---|---|---|
| Ingress | Cell | raw string |
| Instruction | Receptor | `NDC-12345` |
| observe | Cell | `fullDispense` |
| transaction | Cells | stock 4, label true |
| motor | `_robot` | drawer open then closed |

**Demonstrates:** the three layers in order. If you only remember one
run, remember this one.

### Scenario 2 — invalid NDC

**Input:** `invalid-code`.

| Step | Part | Result |
|---|---|---|
| normalize | Instruction | `INVALID-CODE` |
| filter | Instruction | `null` |
| rx Cell | Cell | no pulse |
| transaction | — | never starts |

**Demonstrates:** the Receptor is the security gate for *scans*. Stock
does not move because nothing reached `observe`.

### Scenario 3 — out of stock

**Setup:** `resetSystem(packs: 2)`.  
**Inputs:** `NDC-100`, `NDC-101`, then `NDC-999`.

| Scan | Stock after | Notes |
|---|---|---|
| 100 | 2 → 1 | same path as scenario 1 |
| 101 | 1 → 0 | label now true |
| 999 | stays 0 | `onHand < 1` throw **before** commit |

**Demonstrates:** a business rule **inside** the transaction. Failed tx
does not decrement. Label stays `true` from scan 101 — this is not a
rewind of history.

### Scenario 4 — printer jam + compensate

**Setup:** stock 3, `_robot.jamNextPrint = true`.  
**Input:** `NDC-JAM`.

| Step | Outcome |
|---|---|
| transaction | stock 3→2, label true, **committed** |
| drawer | opens |
| printLabel | throws |
| `memoryCommitted == true` | `restorePack` → stock 3, label false |
| closeDrawer | closed |

**Demonstrates:** I/O after commit needs a **second** tx. Calling this
“rollback” is wrong; the first commit stood. Compensate is the design.

### Scenario 5 — last pack, two scans

**Setup:** stock 1.  
**Input:** `scan('NDC-RACE-A'); scan('NDC-RACE-B');` with no delay.

Both pulses can pass the Receptor (both are NDCs). Two `fullDispense`
futures overlap. At commit, only one should see `onHand == 1`.

**Demonstrates (weakly):** overlapping work on one pack. It does **not**
instrument the lock. A passing log is “stock 0, one success.” That can
also happen if the second `begin` simply runs after the first `commit`.

### Scenario 6 — TestCell on ingress

**Input:** `stockIn.emit(-1)`.

`stockIntegrity` returns `false` for `n < 0`. `emit` should not accept
the pulse. `stock.cell.value` stays 0.

**Demonstrates:** TestRule belongs on the **upstream** cell. It does
**not** wrap `tx.update` in this demo. `resetSystem` / `dispenseMemory`
still write `stock` directly.

---

## 5. What this is not (yet) for real life

| Gap | Risk |
|---|---|
| `tx.update` bypasses `stockIn` | TestCell is a side door, not the till |
| No `TestCell` on the gun beyond allowAll | Anyone can emit on `_gun` |
| No identity / `Context` on the technician | No “who scanned” |
| `restorePack` can race a second dispense | Compensate + new scan both `+1`/`-1` without a saga id |
| Printer jam is a bool flag | Real printer has partial-print and paper state |
| Patient cell is unused | Wristband not bound to the pack |
| Race scenario is not asserted | Banner always prints success |
| `observe` effect is fire-and-forget | Overlap is accidental, not a job queue |
| No durable log | Can’t reconstruct a night’s dispenses |
| No `TestCell` on drawer | Software can mark open when motor didn’t |
| `resetSystem` uses raw `update` | Fine for a demo, fatal if copied into prod |

---

## 6. Proposed production shape (Cell + Flow)

Keep the demo’s **split**. Tighten who is allowed to write, and give
compensate a name.

```
                    Context (tech id, shift, station)
                              │
gun ingress ── TestPulseRule (rate, station)
        │
        ▼
ConfirmGate  MapValue trim/upper + Filter NDC + Distinct + Take(1)
        │    Receptor.instruction — one lock per “next pack”
        ▼
rx Cell
        │
        ▼
DispenseJob Cell.state<Job?>     // queued work, not the shelf
        │
        ▼
Cell.txApply / Cell.transaction on domain cells:

  Stock   CellBase  dispense / restock     TestCell n>=0
  Label   CellBase  markPrinted / void
  Drawer  CellBase  open / close           compensate: robot.close
  Patient CellBase  confirm wristband

  tx.begin([stock.stateCell, label.stateCell, drawer.stateCell])
  or Cell.txApply with whitelisted tear-offs on modifiable

        │
        ▼
Ledger Cell  append-only Pulse of DispenseRecord (never update)
```

| Piece | Demo | Production |
|---|---|---|
| NDC policy | two raw Instructions | `MapValue + Filter + Distinct + Take(1)`; **new handle** per pack |
| Stock write | `tx.update` | only `Stock.dispense` / `restock` on `modifiable`, or only through `stockIn` |
| TestCell | ingress side demo | on gun **and** on stock intake **and** `n >= 0` in the tx body |
| Compensate | `restorePack` ad hoc | `txApply` compensate **or** named `DispenseSaga` with job id |
| Last pack | two scans | one `Take(1)` gate + tx on stock; assert with two isolates / two techs |
| Patient | unused state | `confirm(wristband)` in the same tx as stock |
| Audit | print | ledger Cell + `Context.describe` |
| Hardware | `_robot` static | ports behind Drawer/Label cells so tests fake the motor |
| Next pack | reuse same gate | new `ConfirmGate` / reset `Take` (same as checkout gun) |

Suggested sequence for a real station:

1. Wristband tap → `patient.confirm` (own small tx).  
2. Scan → Receptor `Take(1)` emits one NDC.  
3. `Cell.transaction` (or `txApply`): stock.dispense + label.mark + patient still bound.  
4. Drawer.open (compensate close).  
5. Printer; on fail compensate stock+label and close.  
6. Ledger append.  
7. New Receptor for the next pack.

Flow stays on the scan. Cell transactions stay on the shelf. TestCell
stays on every **ingress** that can accept a human or device pulse.
Do not put `tx.begin` inside `Filter + MapValue`.

---

## 7. How to read the demo file

| You want | Look at |
|---|---|
| Instruction + Receptor | `ConfirmGate` |
| Transaction | `dispenseMemory` / `restorePack` |
| Hardware undo | `openDrawer`, `fullDispense` catch |
| TestCell | `stockIntegrity` + scenario 6 |
| Overlap | scenario 5 + `inFlight` |
| What to build next | section 6 above |
