---
name: cell-core
description: >-
  Choose the correct package:cell factory for the Mitosis Cell layer and
  generate code that compiles against the live API. Use when a requirement
  or BRD sentence mentions capturing, retaining, deriving, transforming,
  committing, or observing state with Cell, or when deciding between
  Cell.ingress, Cell.state, Cell.derive, Cell.observe, Cell.asyncMap,
  Cell.switchMap, and Cell.txApply.
---

# Cell factory chooser — package:cell (Mitosis Cell layer)

## Workflow

1. Map the requirement sentence to a first factory with the table below.
2. Read that row in `references/api_chooser.md` — the **When to use**,
   **When NOT to use**, and **Live signature** columns are generated from
   the `### AI Agent Guide` doc blocks in the package source and cannot
   drift from the code.
3. Copy the example named in the row and adapt it. Compile-check under
   `dart analyze` before finishing.
4. Verify the package version in the consumer's `pubspec.lock` matches the
   pin in the row (cell 2.x). When working inside the cell repository
   itself, run `dart run tool/ai_preflight.dart` from `packages/cell` and
   fix any STALE pins first.

## Hard rules

- Never create a custom `Cell` subclass for policy. The decision belongs
  to a cell_flow instruction.
- Never hold a collection in `Cell.state` — that is a cell_tissue book.
- `Cell.observe` only moves an already-decided pulse into books or side
  effects. It never decides.
- Atomic multi-book commits use `Cell.txApply` with Tissue participants,
  not `Cell.transaction`.
- Redact PII with `Cell.sanitized`; do not write raw PII into books.
- Time operators (`Cell.debounce`, `Cell.throttle`) shape feeds. They
  never decide.

## BRD sentence → first factory

| BRD sentence | First factory | Do NOT |
|---|---|---|
| "capture X" / "record X entering" | `Cell.ingress` | create a custom Cell |
| "retain X" (no book named) | `Cell.state` | hold a collection in it |
| "show X derived from Y" | `Cell.derive` | put policy branches in it |
| "background job per pulse" | `Cell.asyncMap` | use it when the mapper returns a Cell (`Cell.switchMap`) |
| "latest reservation / source only" | `Cell.switchMap` | `Cell.asyncMap` |
| "commit two facts together" | `Cell.txApply` on Tissue | `Cell.transaction` |

## Layer contract

Cell owns graph nodes, ingress/observe, TestCell, transactions, and
deputies. It does **not** own decisions (cell_flow) or books (cell_tissue).

The seam sentence: *The instruction decides, the chain assembles, the
observer glues.*

## Minimal example

```dart
import 'package:cell/cell.dart';

void main() {
  final gate = Cell.ingress<String>();
  Cell.observe(source: gate.cell, effect: (Pulse p) => print(p.payload));
  gate.emit('hello');
}
```

## References

- `references/api_chooser.md` — the full generated decision matrix.
