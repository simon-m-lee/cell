# Phase 5 — Day-1 precursor verdict

Recorded: 2026-11-15, against the live workspace substrate
(`cell` 1.1.0, `cell_tissue` 1.0.0).

## 1. `Cell.asyncMap` availability and semantics

Live signature:

```dart
static Cell asyncMap<S, T>(
  Cell source,
  Future<T> Function(S value, {required EffectJournal journal}) mapper, {
  required EffectJournal journal,
  int concurrency = 0,
  bool latestOnly = false,
  bool exhaust = false,
})
```

Findings:

- The mapper receives the **payload value** of the source cell — not
  the pulse. The router therefore sources PULSES as payloads
  (`Cell.ingress<Pulse>`), so the mapper receives the full pulse
  (provenance + payload).
- `exhaust: true` **drops** arrivals while a mapper is in flight —
  it does NOT queue them. `toolRouter` documents drop semantics;
  tests emit sequentially.
- The mapper is re-run on replay (inside `JournalScope.run` with the
  replay journal). Tool invocations must therefore be journaled
  (`journal.io('mind.tool.call.<verb>')`) so replay serves recorded
  outputs and never re-invokes the tool.
- Mapper output becomes the output cell's payload: the router's
  result pulses ride as payloads (consumers unwrap once).

## 2. `Cell.fromStream`

Available with `{required journal, cancelOnError}`. The bridges use
manual `await for` loops over the stream instead — the live
`Cell.fromStream` cannot stamp a governed `PulseContext` onto
emissions, while the bridges must carry actor/reason/confidence
provenance.

## 3. `IngressHandle.emit`

Takes the raw VALUE (`emit(I)`), not a pulse — provenance is not
attachable. The public surface that can emit a full governed pulse is
`OpenCell` (`OpenCell.perform(source, passThrough)`); the bridges emit
through an `OpenCell` pass-through.

## 4. Additional findings discovered during implementation

### B1 — `PulseContext.aiInference` does not exist

Contexts are composed from `Provenance` entries via
`PulseContext.fromEntries(entries, parent: baseContext)`.

### B2 — Replay clocks truncate to milliseconds

`ReplayJournal.clock()` restores `DateTime.fromMillisecondsSinceEpoch`.
Effect `at` fields truncate to milliseconds (`_isoAt`) or re-created
maps would never fingerprint-match the recorded inputs.

### B3 — `Future<Never>.catchError` handlers must return `Never`

A throwing `async` tool infers `Future<Never>`; `catchError` handlers
returning `null` fail at runtime. Fire-and-forget error swallowing
uses `.then<void>(...)` instead.

### B4 — `Pulse.evolve(pulse: X)` replaces the payload with X

The plan's `input.evolve(pulse: Pulse<Object>(map, type: ...))` would
put the PULSE into the payload and lose the type. The router emits
fresh governed pulses (`Pulse<Object>.governed(...)`) with the
source's context.

### B5 — The pinned matcher has no `completes(...)`

`completion(...)` (the matcher) clashes with the bridge's
`completion(...)`; tests hide the matcher import.

## 5. Verdict

PROCEED with the journaled-tool-call router, pulse-as-payload result
contract, and drop-semantics exhaust documented in
`guide/06-Bridges.md` §5.4/§6.2.
