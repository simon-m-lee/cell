# Echo Home — cell_skin live demo

A polished smart-home app where a scripted AI agent uses the **real**
`cell_skin` membrane, the **real** `TestCell` gates, the **real**
hash-chained ledger, and the **real** `ReplayEngine` to reduce
tomorrow's energy bill. Only the agent's decisions are scripted.

> Full walkthrough: [DEMO_GUIDE.md](../DEMO_GUIDE.md).

```bash
flutter pub get
flutter run -d chrome   # or macos, linux, windows
```

No API keys. No network. Runs offline in ~20 seconds at 4× speed
(change the speed in the app bar to watch it at 1×).

## What you will see

| Beat | What happens | What the framework did |
| :--- | :--- | :--- |
| Discovery | Agent lists 6 tools | `SkinManifest` from the real graph + bindings |
| Accepted | `thermostat.setTarget(19)` | Real `target.apply` through the four cells, ledger #0 carries the apply receipt |
| Rejected | `door.lock()` **refused** | Real `TestCell.action` (occupant home) → `ApplyRejected` — and no ledger entry, because a denial writes nothing |
| Batched | `light.optimize(brightness, hex)` | One wire call wrapping `Cell.txApply` → two ledger entries from one wire call (both or neither) |
| Verified | Verify & Replay | Real `ReplayEngine` into a fresh graph → **0 divergences** |

The door rejection is not scripted. It is the framework's
`TestCell.action` firing on the real graph state — the transcript
label comes straight from the `ApplyRejected` the framework returned.
The ledger's silence about the denial is the framework's too: the
ledger records mutations, not denials.

## Controls

- `🐛` — Developer Mode: the graph, its registered cells, and the four
  wire cells (`Cell.ingress` → `Cell.asyncMap` → `Cell.observe` →
  `Cell.observe`), rendered live from the `cell_flutter` DevTools
  registry (pulse journals per cell).
- `⏸/▶` — pause/resume the scripted timeline (the framework never pauses).
- `↺` — rebuild the whole scenario from scratch.
- `0.5×/1×/2×/4×` — playback speed of the scripted timeline.

## Architecture: full `cell_flutter` adoption

The plan's §2.3 proposed a `ValueNotifier` view-model. The demo
deliberately deviates: **every piece of UI state is a cell**, bound
through the framework's own `cell_flutter` widget layer.

- **Domain values** (thermostat, door, lights, energy) are read
  straight from the registered graph cells — `CellBuilder` for state
  cells, `CellValueBuilder` for pulse cells. No view-model copies.
- **The agent transcript, the ledger rows, and the demo controls**
  (`speed`, `paused`, `devMode`, replay progress, the door's denial
  counter) are cells that are deliberately **not registered in the
  domain graph** — script and UI state can never pollute the ledger or
  the replay.
- **The transcript is `CellListView.builder` with `reverse: true`**
  (the live edge pinned to the bottom — the `reverse` support was
  added to `cell_flutter` for this demo), and **the ledger is
  `CellListView.keyed`** by `seq`.
- **The door's rejection beat is `CellListener`** — a one-shot
  pulse-driven effect (shake + red flash) that never rebuilds its
  subtree.

## Recording mode

The GIF on the package README is produced from this exact app:

```bash
flutter run -d macos --dart-define=DEMO_RECORDING=true --profile
```

Recording mode drives a 15fps frame marker (`Frame N/300 · <beat>`)
in the status strip; `screencapture`/`ffmpeg` capture the screen, and
the post-processing pipeline in `Plan-Cell_Skin-Demo.md` §6 turns it
into a 640px GIF. The drift test (`test/timeline_test.dart`) pins the
300-frame storyboard so a change to the scripted timeline fails CI
until the GIF is re-recorded.

## Tests

```bash
flutter test
```

- `mock_agent_test.dart` — the plan's §8.1 assertions: accepted
  outcome with the apply receipt in the ledger, real rejection with
  no entry, the tx pair from one wire call, and zero-divergence
  replay.
- `timeline_test.dart` — the plan's §8.2 GIF-drift gate.
