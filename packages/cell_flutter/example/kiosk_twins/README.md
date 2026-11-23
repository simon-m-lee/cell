# Kiosk Twins — the cell_memory live demo (mirrored under `cell_flutter/example`)

A two-kiosk coffee counter where `cell_flutter` binds the UI of the whole
Mitosis stack, and `cell_memory` / `cell_memory_firebase` is the boundary
layer: **Cell** state, **Flow** pipelines, **Tissue** governance, and —
from Phase E — a **Skin** membrane over a Mock MCP transport.

> This directory mirrors `packages/cell_memory_live_demo` so the demo
> ships in the `cell_flutter` package's example tree on GitHub. Both
> copies build the same sources against the monorepo via
> `pubspec_overrides.yaml`.

**Current phase: D — network boundary (Firebase) + the two-kiosk race.**
The books (stock, cash, orders) are governed domain cells; a
`MemoryBoundary` attaches one `remember()` per book over either a
`FileMemoryStore` (default) or a `FirebaseMemoryStore`.

---

## Runbook (for a fresh GitHub clone — human or AI agent)

### Prerequisites

- Flutter (stable, ≥ 3.24) — desktop builds need Visual Studio on
  Windows (and **Developer Mode** enabled for plugin symlinks).
- For the Firestore half: Node.js + Java 21+ and
  `npm install -g firebase-tools`.

### Quick start (file store, no network)

```bash
git clone https://github.com/simon-m-lee/cell.git
cd cell/packages/cell_flutter/example/kiosk_twins
flutter pub get
flutter run -d windows          # or -d chrome (web = in-memory store)
```

The app restores its books from `kiosk_state/` on boot and writes the
latest value of each book on shutdown.

### Beat 1 — the restart drill (process boundary #1)

1. Launch the app; **Brew Flat White** (stock 24 → 23, cash $2.50,
   orders 1; the Flow pipeline feed shows `validated → reserved →
   settled → receipted`). Quit.
2. Relaunch from the same directory: the kiosk shows stock 23, cash
   $2.50, orders 1 — restored from `kiosk_state/`.
3. `rm -rf kiosk_state` for a fresh cold boot.

### Beat 2 — governance (Tissue)

Press **Drain −99 (governance)**: the `TissueValue` rule rejects the
below-zero value and the banner reports the denial; the book never
moves.

### Beat 3 — the network boundary: two kiosks race the last cup (Firestore)

Both windows sign in as the same fixed user (`kiosk@example.com` on the
emulator). The shipped `firestore.rules` are the boundary; the Dart CAS
(revision + generation) closes the ABA hole between the two processes.

```bash
# Terminal 1 — emulators (firestore 127.0.0.1:8088, auth 9099)
cd cell/packages/cell_memory_firebase
firebase emulators:start --only firestore,auth --project demo-cell-memory

# Terminal 2 — kiosk A
cd cell/packages/cell_flutter/example/kiosk_twins
flutter run -d windows --dart-define=STORE=firebase --dart-define=KIOSK=A

# Terminal 3 — kiosk B (the twin)
cd cell/packages/cell_flutter/example/kiosk_twins
flutter run -d windows --dart-define=STORE=firebase --dart-define=KIOSK=B
```

The drill: A brews a flat white and presses **Sync books (save)**; B
launches (loads A's row), presses **Sync books (save)** to settle, then
removes its stock record (a debug button lands with Phase F; until then
the automated test below exercises the remove) and brews the last cup.
When A brews and syncs again, its stale generation is a
`MemoryConflict`: the banner reports the winner's revision and
generation, and A adopts the winner. Both kiosks then agree on the same
row — generation G2, never the reused G1.

### Beat 4 — the automated race gate (device, optional)

```bash
# Windows desktop (Developer Mode required for plugin symlinks)
flutter test integration_test/race_test.dart -d windows

# Chrome: needs a chromedriver matching your Chrome version on port 4444
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/race_test.dart -d chrome
```

The test skips itself when `FIRESTORE_EMULATOR_HOST` is unset; CI must
fail on that skip.

### Recording the animated GIF

```bash
# 1. Launch the demo in a titled window ("Kiosk Twins") on Windows.
# 2. Capture the run:
cd tool/gif
DURATION=60 OUT=demo_capture.mp4 ./record.sh   # ffmpeg gdigrab by title
# 3. Convert to a 960 px, 12 fps animated GIF (two-pass palette):
./make_gif.sh demo_capture.mp4
# 4. Ship it: copy live-demo.gif (plus a static live-demo.png frame)
#    into packages/cell_memory/doc/ and embed it in the cell_memory
#    README with alt text and a link to this demo.
```

## Tests

```bash
flutter test
```

`test/widget_test.dart` covers the UI beats (brew, pipeline feed, drain
denial) with the memory boundary attached; `test/restart_test.dart` runs
the file-store persistence assertions in a real async zone (widget tests
run in a FakeAsync zone where real IO futures never complete). The
Firebase race lives in `integration_test/race_test.dart` because the
Firebase plugins need a real device runner — the VM `flutter test`
harness has no platform channels for them.

## Roadmap

- **Phase E**: `SkinMembrane` + Mock MCP adapter + forensic receipts;
  the replay overlay lands here with the apply/receipt path.
- **Phase F**: deterministic `DEMO_MODE` so the scripted beats play
  themselves for the recording, plus the remove button for the manual
  race drill.
