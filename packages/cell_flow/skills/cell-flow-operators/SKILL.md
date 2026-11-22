---
name: cell-flow-operators
description: >-
  Choose the correct cell_flow operator or instruction shape for the Mitosis
  Flow layer and generate code that compiles against the live API. Use when
  a requirement says wait, rate-limit, cancel, parallel, batch, combine, or
  flag-when, or when deciding between Flow operators and a custom
  FlowInstructionBase.
---

# Flow operator chooser — package:cell_flow (Mitosis Flow layer)

## Workflow

1. Map the requirement sentence to a first construct with the table below.
2. Read that row in `references/api_chooser.md` — the **When to use**,
   **When NOT to use**, and **Live signature** columns are generated from
   the `### AI Agent Guide` doc blocks in the package source and cannot
   drift from the code.
3. Copy the example named in the row and adapt it. Compile-check under
   `dart analyze` before finishing.
4. Verify the package version in the consumer's `pubspec.lock` matches the
   pin in the row (cell_flow 1.x). When working inside the cell repository
   itself, run `dart run tool/ai_preflight.dart` from `packages/cell_flow`
   and fix any STALE pins first.

## Hard rules

- The **decision** is a `FlowInstructionBase` subclass composed with `+`
  and published with `toHandle` — one Receptor, one lock. Never put policy
  branches in `Cell.observe`.
- Time operators (`Flow.debounce`, `Flow.throttle`, `Flow.delay`) shape
  feeds. They never decide.
- Stock `Filter` and `Distinct` have no `reset()`. When an ACK must clear
  the latch, write a custom instruction.
- Use `Flow.switchMap` for latest-only sources, `Flow.exhaustMap` to
  prevent double submit / double ACK, `Flow.concatMap` for ordered inner
  sequences, and `Flow.combineLatestWith` for one screen from many feeds.

## BRD sentence → first construct

| BRD sentence | First Flow construct | Do NOT |
|---|---|---|
| "flag at-risk when remaining < MCT" | `riskOf` clause in `FlowInstructionBase` | put in `Cell.observe` |
| "do not flood the supervisor" | latch / `Distinct` + ACK `reset()` | stock `Distinct` without reset |
| "latest reservation / flight only" | `Flow.switchMap` | `Flow.mergeMap` |
| "prevent double checkout / ACK" | `Flow.exhaustMap` | hand-roll a busy flag |
| "retry flaky RTU" | `Flow.retry` or harness pump | retry inside `riskOf` |
| "wait for silence" | `Flow.debounce` | roll your own `Timer` |

## Layer contract

Flow owns `riskOf` / operators / latch / product filter / chain assembly /
`toHandle`. It does **not** own ingress, observe, transactions, or Tissue
writes.

The seam sentence: *The instruction decides, the chain assembles, the
observer glues.*

## Minimal example

```dart
import 'package:cell_flow/cell_flow.dart'; // re-exports package:cell

final searchInput = Cell.ingress<String>();
final searchHandle = Flow.asyncMapLatest<String, String>(
  searchInput.cell,
  mapper: (query) async => 'Results for $query',
);
```

## References

- `references/api_chooser.md` — the full generated decision matrix.
