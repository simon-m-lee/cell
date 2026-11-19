# Rubric — `flutter-pipeline/v1`

This document specifies the pipeline's **five-category verification
rubric**. Phase D implements it; the CLI runs it before writing an app
and refuses to write when any applicable category fails. The rubric is
the pipeline's answer to "how do you know the generated app is
correct?" — it asserts requirement-by-requirement, not just
compilation.

## Semantics

- A **sub-check** has one of three outcomes: `PASS`, `FAIL`, or
  `NOT_APPLICABLE`.
- A **category** is `PASS` if all its applicable sub-checks pass,
  `FAIL` if any fails, `NOT_APPLICABLE` if none applies.
- The **overall assessment** is `VERIFIED` if all applicable
  categories pass, `NOT_VERIFIED` otherwise. A single `FAIL` anywhere
  makes the app `NOT_VERIFIED`, and the pipeline exits 1 without
  writing.

The five categories are deliberately **orthogonal**: a deliberate
defect must fail exactly one category. If a defect ever fails two, the
rubric is wrong (Phase D validates this with five deliberate-defect
tests).

---

## 1. Coverage

**Definition:** every requirement has at least one widget in the
design and at least one test in the test file.

| Sub-check id | Assertion |
|---|---|
| `coverage.every-requirement-has-widget` | Every `REQ-###` appears in the design (via the walkthrough's steps). |
| `coverage.every-requirement-has-test` | Every `REQ-###` has a `testWidgets` in the test file. |
| `coverage.every-widget-has-requirement` | Every widget in the design is referenced by at least one requirement (no orphans). |
| `coverage.every-test-has-requirement` | Every `testWidgets` corresponds to a requirement (no orphans). |

**Defect example:** a BRD with `REQ-003` but no widget satisfying it
→ fails `coverage.every-requirement-has-widget`, **and only
Coverage**.

---

## 2. Placement correctness

**Definition:** every widget matches the widget choice the placement
rules produce for its requirement.

| Sub-check id | Assertion |
|---|---|
| `placement.widget-type-matches` | The widget's type equals `place(requirement).widget`. |
| `placement.cell-binding-matches` | The widget's cell binding equals the pattern's expected cell. |
| `placement.builder-shape-matches` | The widget's builder closure matches the pattern's expected shape. |

**Defect example:** `REQ-002` (a form field) placed as a
`CellBuilder` instead of a `CellTextField` → fails
`placement.widget-type-matches`, **and only Placement correctness**.

---

## 3. Anti-pattern compliance

**Definition:** no widget violates a do-NOT rule from
`rules/anti_patterns.dart`.

| Sub-check id | Assertion |
|---|---|
| `anti-pattern.no-cell-in-build` | No `Cell` is created inside a `build` method. |
| `anti-pattern.no-writable-cell-to-child` | No writable `ValueCell` is passed to a child widget. |
| `anti-pattern.no-raw-observe-in-widget` | No raw `Cell.observe` inside a widget. |
| `anti-pattern.no-set-state-on-cell` | No `setState` updating a cell-held value. |
| `anti-pattern.no-unkeyed-hook-builder` | No unkeyed `HookBuilder` used for a cell swap. |

**Defect example:** a generated screen that creates `Cell.state` in
`build` → fails `anti-pattern.no-cell-in-build`, **and only
Anti-pattern compliance**.

---

## 4. Verification completeness

**Definition:** every requirement has a LEDGER line of the right kind
for its `Type`.

| Sub-check id | Assertion |
|---|---|
| `verification.display-has-render` | Every `display` requirement has a `RENDER` LEDGER line. |
| `verification.interaction-has-interact` | Every `interaction` requirement has an `INTERACT` LEDGER line. |
| `verification.recovery-has-recover` | Every `recovery` requirement has a `RECOVER` LEDGER line. |
| `verification.atomic-has-interact` | Every `atomic` requirement has an `INTERACT` line that triggers a `Cell.txApply`. |
| `verification.all-ledger-lines-present` | Every requirement's LEDGER line is present in the test file. |

LEDGER kinds: `RENDER` (rendered via …), `INTERACT` (interacted via
…), `RECOVER` (recovered via …). The description prefix decides the
kind.

**Defect example:** an `interaction` requirement whose LEDGER line
was changed to `RENDER` → fails
`verification.interaction-has-interact`, **and only Verification
completeness**.

---

## 5. Structural invariants

**Definition:** the generated app has the correct top-level structure.

| Sub-check id | Assertion |
|---|---|
| `structural.main-exists` | `lib/main.dart` exists. |
| `structural.cell-scope-at-root` | `lib/main.dart` contains a `CellScope` at the root (not inside a screen). |
| `structural.error-boundary-at-root` | `lib/main.dart` contains a `CellErrorBoundary` wrapping the app. |
| `structural.restoration-scope` | Every `Cell.restorableState` is inside a `CellRestorationScope`. |
| `structural.app-level-cells-registered` | Every `AppLevel: yes` state row is registered in the `CellScope`. |
| `structural.output-tree-matches` | The file set matches `docs/output-tree.md` (`flutter-pipeline/v1`). |

**Defect example:** `CellErrorBoundary` moved inside a screen instead
of at the root → fails `structural.error-boundary-at-root`, **and only
Structural invariants**.

---

## What the rubric does **not** check

- Rendering fidelity beyond the assertions in the generated tests
  (pixel-perfect goldens are out of scope).
- Accessibility (contrast, semantics, screen-reader labels).
- Performance (the widget layer is benchmarked separately).
- Localization (messages are English in v0.1).
- Security of the generated app's business logic (the BRD's
  transactions are the app author's domain).

These are deliberate exclusions, documented so that `VERIFIED` means
exactly what it says: the five categories above, nothing more.

## Relationship to the CLI

- `assess` runs the rubric alone; exit 0 = `VERIFIED`, 1 =
  `NOT_VERIFIED`.
- `generate` runs the rubric before writing; a failed assessment means
  no files are written, regardless of `--no-gates`.
- `verify` runs the rubric first; a failed assessment exits 1 before
  the reference comparison.
