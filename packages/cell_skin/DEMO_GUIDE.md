# cell_skin Demo Guide — Echo Home

## From a Cell Graph to a Scripted Smart Home Over the Wire

## Table of Contents

- [Introduction](#introduction)
  - [What You'll Learn](#what-youll-learn)
- [Run It](#run-it)
  - [Desktop (full demo, REST included)](#desktop-full-demo-rest-included)
  - [Web (same demo, REST adapter off)](#web-same-demo-rest-adapter-off)
- [The Stage](#the-stage)
- [The Scripted Scenario](#the-scripted-scenario)
- [The Panes](#the-panes)
  - [Home Pane](#home-pane)
  - [Agent Pane](#agent-pane)
  - [Ledger Pane](#ledger-pane)
  - [Graph Pane](#graph-pane)
  - [Replay Overlay](#replay-overlay)
  - [Developer Mode](#developer-mode)
- [Architecture of the Demo](#architecture-of-the-demo)
  - [UI state is cells too](#ui-state-is-cells-too)
  - [cell_flutter bindings](#cell_flutter-bindings)
  - [REST, conditionally](#rest-conditionally)
- [What Each Beat Teaches](#what-each-beat-teaches)
- [Extending the Demo](#extending-the-demo)

## Introduction

Echo Home is a Flutter smart-home app in which a scripted agent drives a
real `cell_skin` membrane over a real `Cell` graph — including a real
`TestCell` gate that denies the agent, a real `Cell.txApply` batch, and
the real `ReplayEngine` replaying the whole session into a fresh graph
with **zero divergences**. Nothing is faked behind a mock transport: the
demo uses the same `SkinClient`, `SkinMembrane`, and wire messages as the
REST server.

### What You'll Learn

1. How a `SkinBindingTable` exposes a graph to the wire — and how the
   `SkinWhitelist` limits that exposure.
2. How the router's `concurrency: 1` serialises commands, how receipts
   stay attributable to the domain cells, and how egress `WireStateChange`
   pulses carry the ledger entry's own receipt.
3. How the domain's `TestCell` gate (the front door) rejects an apply —
   the membrane forwards the real `ApplyRejected`, it does not invent a
   success.
4. How the ledger records every mutation (and *not* denials), streams
   `skin.ledger.entry`, and how `ReplayEngine` verifies the whole
   history.
5. How `cell_flutter` (`CellBuilder`, `CellValueBuilder`, `CellListener`,
   `CellListView` — including the new `reverse` orientation for live
   feeds, and the DevTools registry) binds UI to cells without
   `setState`.

## Run It

### Desktop (full demo, REST included)

```bash
cd packages/cell_skin/example
flutter pub get
flutter run -d windows   # or -d macos / -d linux
```

On desktop the demo also binds the real `RestAdapter` on a loopback port
with `AllowAllSkinAuth`, so the status strip shows
`REST: /skin/manifest` and you can curl it:

```bash
curl http://127.0.0.1:<port>/skin/manifest
curl -X POST http://127.0.0.1:<port>/skin/apply \
  -H 'Content-Type: application/json' \
  -d '{"cellId":"home.living.thermostat","function":"setTarget","positional":[21]}'
```

### Web (same demo, REST adapter off)

```bash
cd packages/cell_skin/example
flutter run -d chrome
```

The REST adapter needs `dart:io`, so the demo uses a conditional-import
facade (`lib/mock/rest_binding.dart` / `rest_stub.dart` / `rest_io.dart`):
desktop binds the real adapter, web gets a `null` facade and the status
strip honestly says `REST: unavailable on web`. The whole membrane demo —
agent, gates, ledger, replay — is identical on both platforms.

## The Stage

| Cell | Role |
| :--- | :--- |
| `home.living.thermostat` | Holds the target temperature; `setTarget` is exposed. |
| `home.front.door` | A real `TestCell` with a lock gate: locked while the agent has no key. Its `lock` binding is exposed — and **denied** by the domain gate. |
| `home.living.light` | `optimize` runs a `Cell.txApply` batch (brightness + energy), producing several state changes from one command. |
| `home.energy` | A mocked price feed (`StreamController` + `Timer`, closable for tests) driving the bill calculation. |

The membrane binds them through a `SkinBindingTable` + `SkinWhitelist`,
opens over a real ledger, and serves the scripted agent through
`SkinClient`.

## The Scripted Scenario

The agent runs four beats with typing pauses, each pulse answering the
membrane for real:

1. **Discover** — fetch `/skin/manifest` through the client and list the
   tools on the transcript.
2. **Accepted apply** — `setTarget(19)` on the thermostat. The router
   serialises it, the target applies, the ledger records the state
   change, and egress emits `skin.egress.home.living.thermostat` with the
   entry's own receipt.
3. **Denied apply** — `lock` on the front door. The domain's `TestCell`
   gate returns `ApplyRejected`; the agent's transcript shows the real
   denial and the ledger writes **no entry** (the ledger records
   mutations, not denials).
4. **Batched apply** — `optimize` on the light runs one wire command
   wrapping a `Cell.txApply` batch, producing several state changes from
   one command.
5. **Replay** — `ReplayEngine.replay` verifies the ledger, rebuilds the
   same graph fresh, and reports **0 divergences** in the overlay.

## The Panes

### Home Pane

Door state, thermostat, energy price, and bill — all bound with
`CellBuilder`/`CellValueBuilder`. The door's open pulse triggers a
`CellListener` one-shot side effect (the "beat"), showing side effects
that never rebuild the widget tree.

### Agent Pane

The transcript is a newest-first list bound with
`CellListView.builder(reverse: true)`; the typing indicator is a
`CellBuilder` on a boolean cell. Every line the agent prints is the
membrane's real reply (outcome kind, receipt, or rejection).

### Ledger Pane

The audit trail, newest-first, keyed by `seq` via
`CellListView.keyed`. Each row is one `WireLedgerEntry`; the header notes
that denials write no entry. Watching rows land while the agent acts is
the demo of ledger-driven egress: each row is the same entry that drives
`skin.egress.<cellId>`.

### Graph Pane

Developer Mode only: a live graph drawn from
`CellFlutterDevTools.registry` (`ListenableBuilder` over the registry),
so you can see the four membrane cells (inbound, router, mux, outbound)
and their pulses while the scenario runs.

### Replay Overlay

Triggered after the scenario: `ReplayEngine.replay` with
`ReplayOptions(failOnDivergence: false)` shows progress and the final
divergence count — `0` when everything is healthy.

### Developer Mode

The status strip toggles Developer Mode; it registers the membrane cells
and domain cells in `CellFlutterDevTools.registry` and enables the
in-app inspector (`CellInspectorOverlay`) and graph pane. It is opt-in so
the standard screen stays clean for recordings.

## Architecture of the Demo

### UI state is cells too

Every piece of UI state — transcript, typing flag, ledger rows, paused,
speed, replay progress — lives in unregistered `Cell.state` handles in
`lib/state/demo_state.dart`. They are deliberately **not** registered in
the domain graph or DevTools registry, so they never appear in the
ledger, the replay, or the domain graph — only domain cells do.

### cell_flutter bindings

No `setState` anywhere: `CellBuilder` for reading cells in the tree,
`CellValueBuilder` for any cell (seeded via a retained pulse),
`CellListener` for side effects, and `CellListView` for cell-backed
lists. The newest-first panes use `CellListView(reverse: true)` (added
in cell_flutter 1.2.0 for live feeds).

### REST, conditionally

`RestAdapter` moved to `package:cell_skin/cell_skin_rest.dart` so the
main barrel stays web-safe; the demo's conditional-import facade mirrors
that split (`rest_binding.dart` → `rest_io.dart` on desktop,
`rest_stub.dart` on web).

## What Each Beat Teaches

| Beat | Mechanism on display |
| :--- | :--- |
| Discover | Binding table → manifest; descriptions and schemas cross the wire. |
| Accepted apply | Router `concurrency: 1`; `target.apply`; receipt attribution; ledger-driven egress with its own receipt. |
| Denied apply | The domain `TestCell` gate is the second gate; `ApplyRejected` travels as the wire outcome; no ledger entry. |
| Batched apply | One wire command → `Cell.txApply` → several state changes, each with its own ledger entry. |
| Replay | The same graph id + ledger → fresh graph → `ReplayEngine` divergence check. |

## Extending the Demo

* **Add a cell** — register it in `MockHome.buildGraph`, add a binding
  in the table, and (optionally) whitelist it. The manifest, egress, and
  ledger streams pick it up at the next run.
* **Add an agent beat** — append a step in
  `lib/mock/mock_agent.dart`; the transcript, ledger, and replay absorb
  it automatically.
* **Add a gate** — attach a `TestCell` to a cell and deny something; the
  ledger correctly records nothing for the denial.
* **Record a GIF** — set the `DEMO_RECORDING` marker to enable the
  15fps/300-frame `DemoTimeline` markers, capture the window, and stitch
  the frames. The full capture/stitch/embed procedure lives in
  [guide/HowTo-Recording.md](guide/HowTo-Recording.md).

See [ARCHITECTURE-Skin.md](../ARCHITECTURE-Skin.md) for the membrane design,
[FEATURES-Skin.md](../FEATURES-Skin.md) for the feature catalog, and
[TEST_VERIFICATION.md](../TEST_VERIFICATION.md) for the generated test
report.
