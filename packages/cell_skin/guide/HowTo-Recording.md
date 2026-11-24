# Recording the Echo Home GIF

The animated GIF on the package README (`doc/demo/echo_home.gif`) is a
capture of the **real** demo — the real membrane, gates, ledger, and
replay — not a mockup. No screen recorder is involved.

## Capture

From `packages/cell_skin/example`:

```bash
flutter test tool/gif/capture_gif.dart --dart-define=DEMO_RECORDING=true
```

The tool (`example/tool/gif/capture_gif.dart`) boots `MockScenario`
inside the flutter_test rasterizer, then loops:

1. sleeps 125 ms of **real** wall-clock time (the scripted agent
   advances on real timers),
2. pumps the UI with a 125 ms **test-clock** step so the demo's own
   animations (`AnimatedSwitcher` card rolls, the door's shake and red
   flash) complete instead of freezing mid-transition,
3. captures the rendered `RepaintBoundary` at 1280×800 and keeps a
   640×400 copy,
4. once the timeline finishes, runs the real `verifyAndReplay()`
   overlay and keeps capturing until its "0 divergences" state is on
   screen for ~1.2 s,
5. encodes every frame as `../doc/demo/echo_home.gif` (looping) with
   `package:image`.

The capture loads the real UI font (Segoe UI on Windows) and the
Material icon font, so text in the GIF is legible — the test rasterizer
would otherwise render every glyph as a solid block.

The tool asserts, before writing, that the captured run really
happened: a zero-divergence replay and exactly one door denial.

## Frame rate and size

Wall-clock capture runs at ~8 fps (125 ms per tick). The GIF is
640×400, loops forever, and is typically a few megabytes. The embedded
README image is a single file with no external tooling.

## Recording mode marker

`--dart-define=DEMO_RECORDING=true` switches on the demo's 15fps
storyboard marker (`Frame N/300 · <beat>`) in the status strip, driven
from the `DemoTimeline` storyboard in
`example/lib/state/demo_state.dart`.

## Drift gate

`example/test/timeline_test.dart` pins the storyboard arithmetic: 300
frames at 15fps, beat boundaries, and the agent's pause unit. If the
scripted timeline changes, that test fails until the GIF is
re-recorded and the storyboard is updated in the same change.

## Where the GIF lives

- `packages/cell_skin/doc/demo/echo_home.gif` — the asset the README
  embeds via `![Echo Home — the live demo](doc/demo/echo_home.gif)`.
- `packages/cell_skin/example/tool/gif/capture_gif.dart` — the
  recorder; it is a maintainer tool, not part of the demo's unit
  suite, so `flutter test` does not re-record the GIF on every run.
