# Kiosk Twins — the cell_memory live demo

A two-kiosk coffee counter where `cell_memory` (and `cell_memory_firebase`)
is the boundary layer for the Mitosis stack: **Cell** state, **Flow**
pipelines, **Tissue** governance, and — from Phase E — a **Skin** membrane
over a Mock MCP transport.

Current phase: **D — network boundary (Firebase) + the two-kiosk race**.
The books (stock, cash, orders) are governed domain cells; a
`MemoryBoundary` attaches one `remember()` per book over either a
`FileMemoryStore` (default) or a `FirebaseMemoryStore`.

## Run it

```bash
cd packages/cell_memory_live_demo
flutter run -d windows          # local file store, kiosk_state/
flutter run -d chrome           # in-memory store (no dart:io on web)
```

All dependencies resolve from the monorepo via `pubspec_overrides.yaml`.

## The restart drill (file store)

1. From the package directory, launch the app on desktop.
2. Brew a flat white (stock 24 → 23, cash $2.50, orders 1). Quit.
3. Relaunch from the same directory: the kiosk shows stock 23, cash
   $2.50, orders 1 — restored from `kiosk_state/`.
4. `rm -rf kiosk_state` (or delete the directory) for a fresh cold boot.

The CI-shape version of the drill is `test/restart_test.dart`: it boots
a first "process", brews twice, settles and closes the owned store, then
boots a second "process" against the same directory and asserts every
book — including the governed Tissue books — restored its latest value,
that the restored value was not echoed back as a fresh write, and that a
stored value violating the governance rule fails the open instead of
being adopted.

## The network boundary: two kiosks race the last cup (Firestore)

Both windows sign in as the **same fixed user** (`kiosk@example.com` on
the emulator) — two anonymous sign-ins would be two different accounts
and two Firestore paths. The shipped `firestore.rules` are the boundary;
the Dart CAS (revision + generation) closes the ABA hole between the two
processes.

```bash
# Terminal 1 — start the emulators (firestore 127.0.0.1:8088, auth 9099)
cd packages/cell_memory_firebase
firebase emulators:start --only firestore,auth --project demo-cell-memory

# Terminal 2 — kiosk A
cd packages/cell_memory_live_demo
flutter run -d windows --dart-define=STORE=firebase --dart-define=KIOSK=A

# Terminal 3 — kiosk B (the twin)
cd packages/cell_memory_live_demo
flutter run -d windows --dart-define=STORE=firebase --dart-define=KIOSK=B
```

The drill: A brews a flat white and presses **Sync books (save)**; B
launches (it loads A's row), presses **Sync books (save)** to settle, then
**removes** its stock record (call `stockMemory.remove()` — a debug
button lands with Phase F; until then the acceptance test below exercises
the remove) and brews the last cup. When A brews and syncs again, its
stale generation is a `MemoryConflict`: the banner reports the winner's
revision and generation, and A adopts the winner. Both kiosks then agree
on the same row — generation G2, never the reused G1.

The rules smoke test (a wrong-uid store gets `MemoryIoException`) and the
full remove-and-recreate race run automatically in
`integration_test/race_test.dart`, on a device:

```bash
# Windows desktop (Developer Mode required for plugin symlinks)
flutter test integration_test/race_test.dart -d windows

# Chrome: needs a chromedriver matching your Chrome version on port 4444
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/race_test.dart -d chrome
```

The test skips itself when `FIRESTORE_EMULATOR_HOST` is unset; CI must
fail on that skip.

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

## Recording the animated GIF

`tool/gif/record.sh` captures the running window (ffmpeg `gdigrab`,
title "Kiosk Twins") into an MP4; `tool/gif/make_gif.sh` converts it to
a 960 px, 12 fps animated GIF with a two-pass palette. The GIF ships in
`packages/cell_memory/doc/live-demo.gif` and is embedded in the
`cell_memory` README with a static `live-demo.png` fallback.

## Roadmap

- **Phase E**: `SkinMembrane` + Mock MCP adapter + forensic receipts;
  the replay overlay lands here with the apply/receipt path.
- **Phase F**: deterministic `DEMO_MODE` so the scripted beats play
  themselves for the recording, plus the remove button for the manual
  race drill.
