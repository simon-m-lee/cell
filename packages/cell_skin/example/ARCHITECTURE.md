# Echo Home — Architecture Guide

The complete design and assembly story of the **Echo Home** live demo:
how every layer is built from the Mitosis (Cell) framework packages, how
the pieces are wired together at boot, and how one causal chain travels
from a scripted agent's call all the way to a state change, a forensic
ledger entry, and a replayable receipt.

**Source:** this package (`packages/cell_skin/example`).
**Walkthrough:** [`../DEMO_GUIDE.md`](../DEMO_GUIDE.md).

```bash
flutter pub get
flutter run -d chrome   # or windows, macos, linux
```

---

## 1. What the demo is

A polished smart-home app where a scripted AI agent uses the **real**
`cell_skin` membrane, the **real** `TestCell` gates, the **real**
hash-chained ledger, and the **real** `ReplayEngine` to reduce
tomorrow's energy bill. Only the agent's decisions, wording, and pacing
are scripted — every outcome on screen is a framework outcome.

The four beats:

1. **Discovery** — the agent reads the real wire catalogue
   (`SkinManifest` from the registered graph + bindings): 6 tools over
   7 cells.
2. **Accepted** — `thermostat.setTarget(19)` travels through the real
   four-cell membrane; ledger entry #0 carries the target's own apply
   receipt.
3. **Rejected** — `door.lock()` is refused by the real
   `DoorGate.action` while an occupant is home. `ApplyRejected` reaches
   the transcript, the door card shakes, and the ledger stays silent:
   it records mutations, not denials.
4. **Batched** — `light.optimize(brightness, hex)` is one wire call
   wrapping `Cell.txApply`; the ledger records two entries from one
   wire call (both or neither).

The finale is **Verify & Replay**: the ledger hash chain is verified and
the framework's own `ReplayEngine` re-applies every entry into a fresh
graph — **zero divergences** is the demo's causal-integrity claim, shown
live in the overlay.

The door rejection is not scripted. It is the framework's
`TestCell.action` firing on the real graph state — the transcript label
comes straight from the `ApplyRejected` the framework returned.

---

## 2. The whole demo in one diagram

```text
                      ┌──────────────────────────────────────────────┐
                      │                 Echo Home UI                │
                      │   cell_flutter: CellBuilder / CellValue-    │
                      │   Builder / CellListView / CellListener —   │
                      │   no setState for domain values             │
                      │   panes: Home · Agent · Ledger (+ Dev Mode) │
                      └──────┬───────────────┬───────────────┬──────┘
              view-model      │               │               │
              cells (state)   │               │               │
                      ┌───────▼────────┐      │        ┌──────▼───────┐
                      │   DemoState    │      │        │ ReplayOverlay│
                      │  unregistered  │      │        │  + replay    │
                      │  Cell.state    │      │        │  cells       │
                      │  (transcript,  │      │        └──────▲───────┘
                      │  ledgerRows,   │      │               │ 0 div.
                      │  speed, …)     │      │        ┌──────┴───────┐
                      └───────┬────────┘      │        │ MockScenario │
                              │ ledger tail   │        │ verifyAnd-   │
                      ┌───────▼────────────────▼───────┤ Replay():    │
                      │         MockHome (domain)      │ Ledger.verify│
                      │  Cell.state + TestCell gates:  │ + ReplayEngine│
                      │  thermostat, door, occupant,   │ into a fresh  │
                      │  light, lightColor, price,     │ twin graph    │
                      │  estimatedBill (synthesis)     └──────────────┘
                      └───────┬───────────────────────────────┬───────┘
                              │ bindings + whitelist          │ pulse tail
                      ┌───────▼───────────────┐      ┌────────▼───────┐
                      │     SkinMembrane      │      │  RestAdapter   │
                      │      cell_skin        │      │ cell_skin_rest │
                      │  inbound → router →   │      │  AllowAllSkin- │
                      │  mux → outbound       │      │  Auth opt-in   │
                      │  + SkinClient         │      │  (dart:io only)│
                      └───────┬───────────────┘      └────────────────┘
                              │ real apply / real reject
                      ┌───────▼───────────────┐
                      │     MockAgent         │
                      │  scripted decisions   │
                      │  via SkinClient only  │
                      └───────────────────────┘
```

---

## 3. Package map — what each Mitosis package contributes

| Package | Role in the demo | Where |
|---|---|---|
| `cell` (core) | `Cell.state` (+ `StateHandle`), `TestCell` (`action` veto, `call` link channel), `Cell.fromStream`, `Cell.synthesis`, `CellGraph.builder`, `bindLedger` + `Ledger` (hash chain, verify, tail, `entriesSince`), `InMemoryLedgerStore`, `RecordingJournal`, `ApplyOutcome`/`ApplyAccepted`/`ApplyRejected`/`ApplyStaged`, `Cell.txApply`, `ReplayEngine` + `ReplayOptions`, `CellGraphRegistry` (the replay twin's reset) | `lib/mock/mock_home.dart`, `lib/mock/mock_scenario.dart` |
| `cell_skin` | `SkinBindingTable` + `SkinBinding` + `SkinBinding.command` + `JsonSchema`, `SkinWhitelist`, `SkinMembrane.open` (the four-cell membrane), `SkinClient`, `SkinPulses`, `SkinPulseTypes`, `SkinManifest` | `lib/mock/mock_home.dart`, `lib/mock/mock_agent.dart` |
| `cell_skin_rest` | `RestAdapter.bind` + `AllowAllSkinAuth` — the real HTTP surface, bound behind a conditional import | `lib/mock/rest_binding.dart`, `lib/mock/rest_io.dart` |
| `cell_flutter` | Reactive UI binding: `CellBuilder`, `CellValueBuilder`, `CellListView` (`.builder` reversed / `.keyed`), `CellListener`, and `CellFlutterDevTools` (Developer Mode renders the live graph) | `lib/widgets/*.dart`, `lib/screens/demo_screen.dart` |

---

## 4. The domain layer — cells and real gates

### 4.1 `MockHome` (`lib/mock/mock_home.dart`) — the smart home

Seven registered cells:

- **`thermostat`** — `Cell.state<double>` (initial 22.4) with a
  `ValueGate`: plain values must be doubles in 16.0…26.0.
- **`door`** — `Cell.state<bool>` (initial false, unlocked) with the
  `DoorGate`; `occupant` — `Cell.state<bool>` (initial true).
- **`light`** — `Cell.state<double>` (initial 0.8) gated to 0.0…1.0;
  **`lightColor`** — `Cell.state<String>` (initial `#FFFFFF`) gated to
  strings starting with `#`.
- **`energyPrice`** — `Cell.fromStream<double>` over a periodic feed
  (the one mocked input, as the demo's story requires).
- **`estimatedBill`** — `Cell.synthesis<Pulse<double>>` over
  thermostat + light + price: the bill model is one expression
  (`4.20 − (22.4 − temp)·0.05 − (0.8 − light)·1.6`), recomputed by the
  framework whenever an input changes.

### 4.2 `ValueGate` and `DoorGate` — the real `TestCell` gates

- **`ValueGate`** inspects plain values and pulses and admits links and
  function objects — the framework consults the same generic `call` for
  the link and action channels, which must pass.
- **`DoorGate`** identity-checks the shared `lockDoor` closure. Its
  **`action` channel is the veto point**: while `occupantHome` is true,
  the identical lock closure returns `false` and the framework produces
  `ApplyRejected` — the binding never runs, the door never moves, and
  the ledger writes nothing. Unlock is a different closure, so the same
  gate admits it.

---

## 5. The Skin layer — bindings, whitelist, membrane, client

Assembled in `MockHome.build()`, in exactly this order:

1. **Cells and graph** — `_buildCellsAndGraph()` creates the seven
   cells and registers them under stable ids (`home.living.thermostat`,
   `home.front.door`, …) with `CellGraph.builder`. Each demo instance
   mints a unique graph id; the replay twin reuses the original id.
2. **Ledger** — `graph.bindLedger(store: InMemoryLedgerStore(genesisHash:
   Ledger.genesisHashOf(graph.id)))`, the hash-chained forensic ledger.
3. **Bindings** — `SkinBindingTable` registers the six tools:
   `setTarget` (number, schema 16…26), `lock`/`unlock`, `dim` (number,
   schema 0…1), `setColor` (string), and `optimize`
   (`SkinBinding.command`). The five single-cell functions return
   `SkinPulses.payload(...)` — the framework's "successful transmission"
   contract, which routes the pulse through the target's receptor so
   the ledger records the real apply receipt.
4. **Whitelist** — `SkinWhitelist` names exactly the six exposed
   functions; nothing else crosses.
5. **Membrane** — `SkinMembrane.open(graph:, bindings:, whitelist:,
   ledger:, journal: RecordingJournal(), send: (_) {})` builds the
   four-cell membrane from primitives: inbound (`Cell.ingress`),
   router (`Cell.asyncMap`, `concurrency: 1`), mux (`Cell.synthesis`),
   outbound (`Cell.observe`). The `send` writer is a no-op here — the
   scripted agent reads outcomes through the client, and the REST
   adapter's SSE streams subscribe to `membrane.responses` directly.
6. **Client** — `SkinClient(membrane:)`.

### 5.1 The REST surface (`lib/mock/rest_binding.dart` + `rest_io.dart` / `rest_stub.dart`)

The demo runs on the web too, so the real `RestAdapter` — which
imports `dart:io` — is bound through a conditional import:
`dart:io` platforms get `RestAdapter.bind(membrane:, auth: const
AllowAllSkinAuth())` (an explicit local opt-in) and the web gets
`null`. The status strip reports what is live:
`REST: /skin/manifest (7 cells, 6 tools)` on `dart:io`, or
`REST: unavailable on web`.

---

## 6. The scripted agent (`lib/mock/mock_agent.dart`)

`MockAgent` owns the decisions, the wording, and the pacing; the
framework owns every outcome.

- **Discovery** — `graph.run(() => client.manifest())`, then one
  `ToolDescriptor` per manifest function with an argument summary
  derived from the declared `JsonSchema`.
- **The script** — set thermostat 19.0; lock the door (refused);
  `light.optimize(brightness: 0.5, hex: #FDB813)`; then the closing
  bill summary.
- **`_call`** switches on the real outcome: `ApplyAccepted` →
  `✓ ACCEPTED`; `ApplyRejected` → `✗ REJECTED · <reason>` (and the
  door beat bumps `doorDenials`); `ApplyStaged` → `⏳ STAGED`; `null`
  (pending receipt) → an honest pending label. Every message is a
  `Cell.state` update on the transcript cell — the Agent pane consumes
  it through the same `cell_flutter` bindings as the domain values.
- **Pacing** — a base 500 ms pause unit divided by the live `speed`
  cell (4× by default), so the timeline's tempo is itself demo state.
- **Batching wait** — after `optimize` the agent polls the ledger-seq
  cell until the committed pair has landed, then reports
  `✓ COMMITTED · 2 ledger entries`.

The demo does not speak to an LLM and makes no network calls. The MCP
seam is still exercised honestly: `test/mock_agent_test.dart`
round-trips the real manifest through `mcpToolSpecs` /
`resolveMcpToolCall`.

---

## 7. The UI layer (`lib/widgets/`, `lib/screens/`, `lib/state/`) — `cell_flutter`

### 7.1 `DemoState` (`lib/state/demo_state.dart`) — every piece of UI state is a cell

Full `cell_flutter` adoption: transcript, typing flag, discovered
tools, ledger rows/seq, door denials, speed, pause, dev mode, replay
progress/divergences/entries, and the recording frame label are all
`Cell.state` handles. They are deliberately **not registered in the
domain graph**, so the scripted transcript and demo controls can never
pollute the ledger or the replay.

### 7.2 The panes

- **Home pane** — domain cards bound with `CellBuilder` /
  `CellValueBuilder`; the door card pairs `CellListener` (the one-shot
  rejection beat: shake + red flash) with `CellBuilder` for the lock
  state. Card values roll through `AnimatedSwitcher` on every change.
- **Agent pane** — the transcript as a reversed `CellListView.builder`
  (newest pinned to the bottom), plus the typing indicator and the
  tools card.
- **Ledger pane** — `CellListView<LedgerEntry>.keyed` by `seq`, with
  the "Verify & Replay" button.
- **Developer Mode** — the same `CellBuilder` swap renders
  `GraphViewPane`, which reads the live `CellFlutterDevTools` registry
  (`MockScenario._registerDevTools` registers the four wire cells and
  the domain cells).
- **Status strip** — `MCP: connected`, the REST summary, `seq: N`, and
  the recording frame marker when `DEMO_RECORDING` is on.

The only `setState` calls in the app belong to widget-local effects
(the door flash timer, typing dots, hover) — never to domain data.

---

## 8. The replay story — `cell` core

- The ledger is the forensic record: every accepted apply lands as a
  hash-chained entry; the **denial writes no entry** — the demo asserts
  this on screen and in the tests.
- `MockScenario.verifyAndReplay()` is the overlay's one-shot:
  1. `ledger.verify()` — walk the hash chain;
  2. `CellGraphRegistry.forceReset()` — the *one* test-only call the
     replay requires (the twin registers the same graph id; the live
     membrane keeps running on its already-materialised cells);
  3. build a fresh `MockHome` with the **same graph id** and
     `buildGraphOnly()` (cells + graph, no ledger, no membrane);
  4. `ReplayEngine.replay(ledger:, target:, options:
     ReplayOptions(failOnDivergence: false))`.
- The overlay renders the progress and the final
  `0 divergences · N/N entries match` from the replay cells.

---

## 9. How it is assembled — the boot sequence (`lib/app.dart`)

```text
main()
 └─ runApp(EchoHomeApp)
     ├─ _start()
     │   ├─ scenario = MockScenario()
     │   ├─ home = MockHome()                unique graph id per restart
     │   ├─ await home.build()
     │   │    ├─ cells + CellGraph.builder   thermostat, door, occupant,
     │   │    │                               light, lightColor, price, bill
     │   │    ├─ bindLedger(InMemory)        hash-chained forensic ledger
     │   │    ├─ SkinBindingTable ×6         setTarget, lock, unlock,
     │   │    │                               dim, setColor, optimize
     │   │    ├─ SkinWhitelist               exactly those six
     │   │    ├─ SkinMembrane.open           the four-cell membrane
     │   │    ├─ SkinClient                  the agent's transport
     │   │    └─ bindDemoRest(membrane)      real adapter on dart:io, null on web
     │   ├─ ledger.tail → ledgerRows/seq     the Ledger pane's live rows
     │   ├─ _registerDevTools()              wire cells + domain cells
     │   ├─ agent = MockAgent(home, state)
     │   └─ unawaited(agent.run())           the self-playing beats
     └─ DemoScreen(scenario)                 panes + status strip + overlay
```

The assembly order matters and is worth reading as the architecture's
spine:

1. **Cells before graph** — the graph registers the cell objects.
2. **Graph before ledger** — `bindLedger` needs the registered graph.
3. **Ledger before membrane** — the router opens ledger scopes around
   every apply.
4. **Bindings + whitelist before membrane** — the membrane seals the
   binding table at `open()`.
5. **Membrane before client/REST** — both wrap the membrane.
6. **Ledger tail listener before the agent runs** — the Ledger pane
   sees every entry from sequence 0.
7. **Agent last** — the scripted beats can only start once every layer
   above is live, which is why the whole stack is exercised.

---

## 10. One causal chain, end to end

### Accepted: `thermostat.setTarget(target: 19)`

```text
MockAgent._call
  → graph.run(() => SkinClient.apply('home.living.thermostat', 'setTarget',
                                      positional: [19.0]))
    → WireRequest → membrane.inbound (Cell.ingress)
      → SkinRouter (Cell.asyncMap, concurrency 1)
        → binding function: SkinPulses.payload(19.0)
          → thermostat.apply
            → ValueGate.call(Pulse(19.0)): double ∧ 16…26  ✔
            → state update 22.4 → 19.0
          → receipt (ApplyAccepted) + ledger entry #0 + WireResponse
            → mux → outbound (Cell.observe) → send: (_) {}
  → agent: ApplyAccepted → transcript '✓ ACCEPTED'
  → ledger tail → Ledger pane row + seq cell
  → estimatedBill synthesis recomputes; Home pane rolls 22.4°C → 19.0°C
```

### Denied: `door.lock()`

```text
  → binding function: lockDoor()  (the shared closure)
    → door.apply
      → DoorGate.action(identical(lockDoor) ∧ occupantHome)  ✗
  → ApplyRejected, binding never runs, door never moves
  → no ledger entry (mutations are recorded; denials are not)
  → agent: '✗ REJECTED · occupant home' + doorDenials bump
  → door card: CellListener shake + red flash + the refusal note
```

### Batched: `light.optimize(brightness: 0.5, hex: #FDB813)`

```text
  → SkinBinding.command('optimize')
    → _optimize(): Cell.txApply().execute(
        participants: [light, lightColor],
        body: light.apply(0.5) + lightColor.apply('#FDB813'))
  → ONE wire call → ONE WireResponse → TWO ledger entries (both or neither)
  → agent waits for the pair, then '✓ COMMITTED · 2 ledger entries'
```

### Verified: the replay

```text
  → ledger.verify()                       hash chain walks clean
  → CellGraphRegistry.forceReset()        the one test-only call
  → MockHome(graphId: same).buildGraphOnly()
  → ReplayEngine.replay(ledger, target, failOnDivergence: false)
  → overlay: '0 divergences · 3/3 entries match'
```

Every one of those steps is a framework primitive — no demo-specific
protocol exists; the demo composes the published seams.

---

## 11. Design decisions and lessons (the honest engineering notes)

1. **`TestCell.action` is the apply veto; `call` is not.** A `call`
   that returns `false` for a routed pulse does not reject the apply in
   this path. `DoorGate` therefore computes the verdict in `action`
   from the identity of the closure plus the live `occupantHome`
   flag — pre-mutation, so a refusal never moves the door.
2. **Returning a pulse is the "successful transmission" contract.**
   Binding functions return `SkinPulses.payload(...)`, not a bare
   value: the router routes the pulse through the target's receptor,
   which is what makes the ledger record the real apply receipt.
3. **View-model cells are unregistered on purpose.** Transcript, demo
   controls, and replay progress are `Cell.state` handles that never
   enter the domain graph — they cannot pollute the ledger and they
   never replay.
4. **One wire call, two ledger entries.** `optimize` wraps two applies
   in `Cell.txApply`; atomicity is the framework's, and the demo shows
   it as-is instead of hiding the two rows.
5. **The replay twin reuses the graph id.** That is why the one
   `CellGraphRegistry.forceReset()` exists; the live membrane is
   unaffected because its cells are already materialised.
6. **`dart:io` stays behind a conditional import.** The REST adapter
   exists only on `dart:io` platforms; the web build compiles the stub
   and the status strip says so. No `dart:io` ever leaks into the app
   shell.
7. **The GIF recorder needs two clocks.** The agent advances on real
   wall-clock timers while UI animations advance on the test clock; the
   capture tool drives both in lockstep (see `tool/gif/capture_gif.dart`
   and `guide/HowTo-Recording.md`), and loads the real fonts so the
   rasterizer's block glyphs never appear in the capture.
8. **The ledger's silence about the denial is a feature, not a gap.**
   The demo's tests assert exactly that: a rejection writes no entry,
   which is why the "Verify & Replay" overlay can claim 3/3 entries for
   four wire calls.

---

## 12. Test map — what pins what

| Test file | Guarantee |
|---|---|
| `test/mock_agent_test.dart` | the full scenario: 3 ledger entries (setTarget + the tx pair), thermostat 19.0, light 0.5 / color `#FDB813`, bill below 4.20; the rejection is the framework's `ApplyRejected` with no entry and no delta; unlock is allowed by the same gate; the zero-divergence replay; the manifest round-trips through `mcpToolSpecs` / `resolveMcpToolCall` |
| `test/timeline_test.dart` | the GIF drift gate: the 300-frame / 15 fps storyboard arithmetic, beat boundaries, and the agent's pause unit |
| `test/widget_test.dart` | the live boot: three panes render, the scripted timeline completes, the real rejection label and the committed batch appear, and the scenario disposes cleanly |
| `tool/gif/capture_gif.dart` | the README GIF recorder: boots the real scenario, captures 640×400 frames, and asserts a zero-divergence replay with exactly one door denial before writing |
| `packages/cell_skin/test/*` | the framework itself — the demo only ever consumes the published 1.0.0 surface |

---

## 13. Run, record, deploy

- **Run:** `flutter pub get` then `flutter run -d chrome` (or
  `windows` / `macos` / `linux`). No API keys, no network.
- **Recording mode:** the README GIF is produced headlessly —
  `flutter test tool/gif/capture_gif.dart --dart-define=DEMO_RECORDING=true`
  — which writes `../doc/demo/echo_home.gif`, the file the package
  README embeds. Full procedure: [`guide/HowTo-Recording.md`](../guide/HowTo-Recording.md).
- **Web build:** `flutter build web` compiles the stub branch
  (no `dart:io`); the REST status strip reports the platform honestly.
