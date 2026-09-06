# Walkthrough — pharmacy dispense (enhanced)

**Demo:** `example\domain-cells-txApply(enhanced)-Demo.dart`

One till. Three libraries in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **Cell** | value + pulse + TestCell + transaction | What is on the shelf; who may write |
| **Flow** | Instruction `+` Receptor `toHandle` | Is this scan a pack we may start? |
| **Transaction** | `Cell.transaction` + repeatable-read | Stock, label, wristband all-or-nothing; last pack once |

Flow never decrements stock. Transaction never parses an NDC. The
observer is the only glue.

---

## 1. Why they have to combine

A scan is a **pulse**. A shelf count is **state**. A printer is **I/O**.

If you put `tx.begin` inside `Filter + MapValue`, the gate holds a
transaction while the nurse types. If you decrement stock in
`observe` with two raw `update`s, the last pack goes out twice. If you
open the drawer inside the Instruction, a dropped pulse still moved
hardware.

The demo’s rule:

```
Flow answers: may this pulse become a job?
Transaction answers: may this job move the shelf?
Hardware + restorePack answers: the motor failed after commit.
```

---

## 2. Design (tagged)

**[Cell]** holds or carries. **[Instruction]** is `(pulse)→pulse|null`.
**[Receptor]** runs the chain under one lock. **[Tx]** is
`Cell.transaction` on state Cells only.

```
 technician
     │
     ▼
[Cell] gun  ingress + TestCell(ndcLike)          FLOW intake
     │  emit
     ▼
[Receptor] toHandle(source: gun.cell)            FLOW policy
     │   [Instruction] MapValue trim/upper
     │        + [Instruction] Filter NDC
     │        + [Instruction] Take(1)  (_armed)
     │   null = stop; no Future; no tx.begin
     ▼
[Cell] rx.cell                                   FLOW output
     │  Cell.observe
     ▼
 fullDispense()                                  glue (Dart)

     [Tx] confirmPatient     → [Cell] patient
     [Tx] dispenseMemory     → [Cell] stock + label + patient
            isolation: repeatableRead
            commit = lock; conflict = second last pack
     hardware _robot         → not a Cell
     [Tx] drawer open/close  → [Cell] drawer
     [Tx] restorePack        → stock + label again if print jammed

 armNextPack()  resets Take on the SAME [Receptor]
```

| You need | You use |
|---|---|
| Empty / garbage scan | **Cell** TestCell + **Flow** Filter |
| One job per pack at the gun | **Flow** Take(1) |
| Shelf and label agree | **Tx** on two **Cell**s |
| Two tills, one pack | **Tx** repeatable-read |
| Jam after commit | **Tx** again (`restorePack`), not rollback |

---

## 3. Step by step — one successful pack (scenario 1)

Read this as Cell then Flow then Transaction then I/O.

**0. Graph (once)**  
`installGate()`: **Flow** `toHandle` on **Cell** `gun`.  
`Cell.observe` on `rx.cell` → `fullDispense`.  
State **Cell**s already exist (`stock=5`, …).

**1. Pulse (Cell)**  
`scan('  ndc-12345 ')` → `gun.emit`. TestCell: non-empty → pass.

**2. Policy (Flow)**  
Receptor runs Instructions:

| Stage | In | Out |
|---|---|---|
| MapValue | `'  ndc-12345 '` | `'NDC-12345'` |
| Filter | that | pass (`NDC`) |
| Take(1) | that | pass; `_armed` 1→0 |

`rx.cell` emits. Invalid codes die here. Stock is still 5.

**3. Job (glue)**  
Observer calls `fullDispense('NDC-12345')`.

**4. Wristband (Tx + Cell)**  
`confirmPatient`: `begin([patient])` `update` `commit`.

**5. Shelf (Tx + Cell)**  
`dispenseMemory` with `IsolationLevel.repeatableRead`:

- `begin([stock, label, patient])` — snapshot  
- `read` stock 5, patient set  
- `update` 4 / label true — buffered  
- `commit` — **lock only here** → stock 4  

`onEvent`: Begun → Updated → Committed.

**6. Hardware (not Cell)**  
Open drawer, print, close. Each drawer change is a small **Tx**.

**7. Rearm (Flow)**  
`finally` → `armNextPack()`. Same Receptor, Take is 1 again.

Nothing in steps 4–6 parsed the barcode. Nothing in step 2 touched
stock.

---

## 4. Step by step — last pack (scenarios 7 and 8)

**Flow** will admit two NDCs if you `armNextPack()` twice (scenario 7).
That is deliberate: the gun is not the shelf lock.

Both jobs reach `dispenseMemory`. **Transaction** is the lock:

```
time →
A.begin snapshot stock=1
B.begin snapshot stock=1     (scenario 8 forces this)
A.update 0; A.commit         lock; stock=0
B.commit                     CONFLICT / RolledBack
```

B never opens the drawer. **Flow** already did its job (two valid
NDCs). **Cell** stock ends at 0. **Tx** isolation is what stopped the
second decrement.

If B `begin`s *after* A commits, B reads 0 and throws `out of stock`
instead of CONFLICT. Same shelf result; weaker proof. Scenario 8 is
the proof.

---

## 5. Step by step — jam (scenario 4)

**Flow** admits `NDC-JAM`.  
**Tx** commits stock 4→3. That commit **stands**.  
Printer throws.  
`restorePack` is a **new Tx** (3→4, label false).  

Cell + Flow + Transaction together: the gate is done, the first
transaction is history, compensation is another transaction. Do not
call this rollback of the Receptor.

---

## 6. Parts checklist

| Kind | Instances |
|---|---|
| Cell | `gun`, `stockIn`, `rx.cell`, `patient`, `stock`, `label`, `drawer` |
| Instruction | MapValue, Filter, Take(1) |
| Receptor | one `toHandle` |
| Transaction | patient, shelf, drawer, compensate, scenario 8 pair |
| Not Cell | `_robot`, `ledger` list, `fullDispense` |

---

## 7. Scenarios (what each layer did)

| # | Flow | Transaction | Cell state |
|---|---|---|---|
| 1 Happy | pass + Take | commit 5→4 | stock 4, label true |
| 2 Bad NDC | Filter `null` | never | unchanged |
| 3 Empty | TestCell / no rx | never | unchanged |
| 4 Jam | pass | commit then compensate | stock restored |
| 5 Empty shelf | pass twice | second throws before commit | stock 0 |
| 6 `stockIn(-1)` | n/a | n/a | TestCell on intake |
| 7 Two scans | two pulses | one commit, one CONFLICT | stock 0 |
| 8 Same snapshot | none | A commit, B CONFLICT | stock 0 |

---

## 8. Rules for combining them

1. **Flow stops pulses. Transaction moves state.**  
2. **One Receptor per gun.** Reset Take; do not stack `toHandle`.  
3. **Repeatable-read on the shelf Cells**, not on `gun`.  
4. **Hardware after commit** → new Tx to compensate.  
5. **TestCell on every ingress** that a human or device can emit.  
6. Do not put `tx.begin` in `MapValue + Filter`.

---

## Still demo-only

`tx.update` skips `stockIn`. Harness `stock.update(1)`. Take is
`_armed`. Ledger is a `List`. Scenario 8 is not a scan.
