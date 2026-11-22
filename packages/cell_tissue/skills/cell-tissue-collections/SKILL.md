---
name: cell-tissue-collections
description: >-
  Choose the correct cell_tissue collection book (TissueList, TissueSet,
  TissueMap, TissueQueue, TissueValue) for the Mitosis Tissue layer and
  generate code that compiles against the live API. Use when a requirement
  says record every, reserve N units, protected keys, open incidents by, or
  alert the supervisor, or when picking between the five books.
---

# Tissue collection chooser — package:cell_tissue (Mitosis Tissue layer)

## Workflow

1. Map the requirement sentence to a first book with the table below.
2. Read that row in `references/api_chooser.md` — the **When to use**,
   **When NOT to use**, and **Live signature** columns are generated from
   the `### AI Agent Guide` doc blocks in the package source and cannot
   drift from the code.
3. Copy the example named in the row and adapt it. Compile-check under
   `dart analyze` before finishing.
4. Verify the package version in the consumer's `pubspec.lock` matches the
   pin in the row (cell_tissue 1.x). When working inside the cell
   repository itself, run `dart run tool/ai_preflight.dart` from
   `packages/cell_tissue` and fix any STALE pins first.

## Hard rules

- Every book constructor gets `testRule: TestTissue(...)` — or a
  documented `allowAll`. A plain Dart collection is not a book.
- `TissueList` is the ordered audit log; `TissueSet` is the guarded
  membership register; `TissueMap` is keyed open work; `TissueQueue` is
  outbound alerts; `TissueValue` is the governed scalar with an
  invariant.
- Never keep two books "for compliance" — hand out `.unmodifiable`, a
  live zero-copy view.
- Tissue records; Flow decides; `Cell.observe` glues the two together.

## BRD sentence → first book

| BRD sentence | First book | Do NOT |
|---|---|---|
| "record of every alert and action" | `TissueList` + append-only | plain Dart `List` |
| "protected / diplomatic / resus" | `TissueSet` fed to `riskOf` | duplicate Dart `Set` |
| "open incidents by belt / stream" | `TissueMap` | new Map per bag |
| "alert the supervisor / RTU" | `TissueQueue` + pump list | drain the audit queue |
| "45,000 bags / 42 trolleys / 800 MW" | `TissueValue` + invariant | `Cell.state<int>` |

## Layer contract

Tissue owns the five collection types, TestTissue, deputies, and
`.unmodifiable`. It does **not** own the decision (cell_flow) or the glue
(`Cell.observe`).

The seam sentence: *The instruction decides, the chain assembles, the
observer glues.*

## Minimal example

```dart
import 'package:cell_tissue/cell_tissue.dart';

final auditLog = TissueList<String>(
  testRule: TestTissue<String, TissueList<String>>(
    (value, {host, arguments, user}) => value is String,
  ),
);
auditLog.add('ALERT');
```

## References

- `references/api_chooser.md` — the full generated decision matrix.
