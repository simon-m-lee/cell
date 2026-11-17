# Cell Flutter — Architecture

**Author:** Lee Man Hoi Simon (see [`AUTHORS`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/AUTHORS))

Why `cell_flutter` is shaped this way, for contributors and anyone extending it.
Task-oriented usage lives in `/guide`. Status and the widget table live in
[`README.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/README.md).

This describes **intent plus the mechanisms that exist in source**. Where
implementation lags the story, §7 says so. Do not treat a widget doc comment
as a promise the code delivers — the seed path in `retainedPulseOf` and the
per-source error-pulse prose were previously known to disagree across files;
§7 records how each was resolved.

---

## 1. The core idea

The core `cell` package treats an update as a payload that carries causal
history and optional governance. `cell_flutter` does not add a second
reactive system on top of that. It **binds the existing graph to Flutter's
widget tree**, one-directionally.

Every widget in this package is a thin adapter over a single primitive from
`cell`: `Cell.observe`. A widget does not decide what changed, does not
buffer or re-emit pulses, and does not hold state the cell does not also
hold. It owns exactly one `EgressHandle` per cell it subscribes to, and it
converts the pulses it receives into the shape Flutter can render — a value,
a `ValueListenable`, an `AsyncSnapshot`, or a side effect.

That is the design intent. It carries two consequences the rest of this
document assumes:

1. **The graph decides, the widget renders.** A widget cannot cause a state
   change the cell's `TestCell`, `Receptor`, or transaction ledger would
   not have allowed directly. `CellBuilder` reading `counter.cell` is the
   same view of the same box that `counter.update(5)` writes to; there is
   no widget-layer cache, no widget-layer validation, no widget-layer
   transaction.
2. **Every widget's lifecycle is the egress's lifecycle.** A widget that
   mounts opens an egress; a widget that unmounts closes it. This is why
   the bridges (`asValueCell`, `asStream`) return records with explicit
   `dispose` callbacks — they are used outside a widget, so the widget
   lifecycle cannot close the egress for them.

If a widget-layer feature cannot be expressed as "subscribe to a cell,
convert a pulse, release on dispose," it does not belong in this package.
It belongs upstream, in `cell` or `cell_flow`, where the graph is
governed.

---

## 2. Runtime shape

```
Widgets
      construct
StatefulWidget  +  one EgressHandle per subscribed cell
      via
Cell.observe<Pulse<V>>  or  Cell.observe<Pulse<Object?>>
      converts to
V?  |  ValueListenable<V?>  |  AsyncSnapshot<V>  |  side effect
```

| Primitive | Role |
| --- | --- |
| `CellBuilder<V>` | Display. `ValueCell<V>` → `CellNotifier` → `ValueListenableBuilder`. One `EgressHandle`, no `setState`. |
| `CellSelector<V, S>` | Display. `ValueCell<V>` → `CellNotifier` + `addListener` → `setState` on slice change. Selector runs per pulse; `setState` runs only when the slice moves. |
| `CellValueBuilder<V>` | Display. Any `Cell` → `Cell.observe` → `setState` on value change. Latest payload stored on `State`. |
| `CellAsyncBuilder<V>` | Display. Any `Cell` → `Cell.observe` → `setState` on `AsyncSnapshot` change. Decoder is `snapshotForPulse`. |
| `CellListener<V>` | React. Any `Cell` → `Cell.observe` → handler invoked per pulse. No rebuild. Build-phase pulses queued and flushed post-frame. |
| `CellScope` | Route. `InheritedWidget` over `Map<Symbol, Cell>`. Lookup via `of` / `maybeOf` / `valueOf`. |
| `CellNotifier<V>` | Bridge. `ValueCell<V>` → `ValueNotifier<V?>`. Read-only setter. |
| `asValueCell` | Bridge. Any `Cell` → `MirroredCell<V>`. Opens an egress; caller disposes. |
| `asStream` | Bridge. Any `Cell` → `Stream<V?>`. Lazy: egress opens on `listen`, closes on `cancel`. |
| `snapshotForPulse` / `snapshotForCell` | Pure decoders. Turn a `Pulse` (or a retained pulse) into an `AsyncSnapshot`. |
| `PulseRecorder<T>` | Test. Any `Cell` → in-order pulse list. |

### The mounting cycle

A widget mounts, subscribes, renders once, and stops when the element
unmounts. Same shape whether it is `CellBuilder`, `CellValueBuilder`, or
`CellAsyncBuilder`:

1. `initState` (or the first `build`, for hooks).
2. The widget seeds its initial value: for `CellBuilder`, the notifier's
   `cell.value`; for `CellValueBuilder` / `CellAsyncBuilder`,
   `retainedPulseOf` (`ValueCell`-only) or `initial` / `nothing()`.
3. `Cell.observe<Pulse<…>>` opens one egress. The effect stores or renders
   the pulse.
4. `dispose` (or the effect's cleanup) stops the egress.

Nothing in this cycle is a "pipeline." Each widget is exactly one
subscription with one effect. The four display widgets differ in **what
they store**, not in how many subscriptions they hold.

### The pulse-to-state conversion

Different widgets want different shapes of the same pulse:

| Widget | Data pulse → | Error pulse → | Type mismatch → |
| --- | --- | --- | --- |
| `CellBuilder` | `notifier.value = payload` | dropped | n/a — notifier is typed `Pulse<V>` |
| `CellSelector` | `select(notifier.value)` compared under `equals` | dropped | n/a |
| `CellValueBuilder` | `_value = payload` | reported via `FlutterError` if `emitErrors` | reported via `FlutterError` always |
| `CellAsyncBuilder` | `withData(active, payload)` | `withError(active, payload)` | `withError(active, StateError)` |
| `CellListener` | `onPulse(context, pulse)` | `onPulse(context, pulse)` — type is still `Pulse<V>`, payload is `Object` | n/a — the effect's cast is the caller's |
| `asValueCell` | `mirror.value = payload` | dropped | `Zone.current.handleUncaughtError` |
| `asStream` | `controller.add(payload)` | `controller.addError` if `emitErrors` | `controller.addError` always |
| `PulseRecorder` | recorded | recorded | recorded |

This table is the whole per-widget behavior contract. Any behavior not
listed here is either an artifact of `Cell.observe` (e.g. mid-frame
deferral is per-widget, not per-pulse) or an implementation detail.

---

## 3. Display granularity

Four display widgets. The differences are three independent axes:

| | `CellBuilder` | `CellSelector` | `CellValueBuilder` | `CellAsyncBuilder` |
| --- | --- | --- | --- | --- |
| **Source** | `ValueCell<V>` | `ValueCell<V>` | any `Cell` | any `Cell` |
| **Rebuild trigger** | value changes | selected slice changes | value changes | snapshot changes |
| **Builder receives** | `V?` | `S` | `V?` | `AsyncSnapshot<V>` |
| **Underlying primitive** | `CellNotifier` + `ValueListenableBuilder` | `CellNotifier` + `addListener` + `setState` | `Cell.observe` + `setState` | `Cell.observe` + `setState` |

The decision tree:

- **"I have a `ValueCell` and I want its current value"** → `CellBuilder`.
  This is the cheapest binding and gets `ValueListenableBuilder`'s
  subtree isolation for free.
- **"I have a `ValueCell` and I only read one field"** → `CellSelector`.
  It runs `select` per pulse but only `setState`s on slice change. Worth
  the extra work when `V` is large.
- **"I have a plain `Cell`"** (derived, async, tissue) → `CellValueBuilder`
  for synchronous "latest value" rendering, or `CellAsyncBuilder` if you
  need to branch on loading / data / error.
- **"I have a plain `Cell` and I need `AsyncSnapshot`"** → `CellAsyncBuilder`.

The rule of thumb: **prefer the widget whose source type is the source you
have, then the widget whose rebuild trigger matches what you read.** Do
not use `CellValueBuilder` on a `ValueCell` and call it "cheaper" —
`CellBuilder` is cheaper. Do not use `CellSelector` on a `ValueCell` you
render in full — `CellBuilder` is simpler.

---

## 4. Egress lifecycle

The single invariant every widget in this package must satisfy: **an
egress opened on mount is closed on unmount, and a bridge's egress is
closed by the caller's `dispose`.**

Three patterns exist, and every public API in the package uses exactly one
of them.

### Pattern A — widget-owned egress

`CellBuilder`, `CellSelector`, `CellValueBuilder`, `CellAsyncBuilder`,
`CellListener`, and the five hooks all follow this. The egress is stored
on a `State` field or a hook's `useEffect` closure, and its `stop` runs
in `dispose` / cleanup. If the cell identity changes, the old egress is
stopped before the new one is opened. `didUpdateWidget` in each widget is
explicit about this.

### Pattern B — caller-disposed handle

`asValueCell` and `recordPulses` return a record or class carrying a
`dispose` / `stop` callback. The caller is required to invoke it. The
public docs say so in `### Cleanup` or `### Disposal contract` sections
and reiterate the leak in the widget-facing rationale ("prefer
`CellValueBuilder` inside widgets").

The design reason is identical in both cases: a plain `ValueCell<V>` or a
plain `List<Pulse>` return would hide the `EgressHandle`, and a caller
with no way to stop the observation leaks the source cell for the
isolate's lifetime. The record makes the obligation structural.

### Pattern C — lifecycle-follows-subscription

`asStream` opens its egress in `StreamController.onListen` and closes it
in `onCancel`. The caller's contract is the standard `Stream` contract:
cancel the subscription, and the egress is released. There is no separate
`dispose` because there is no state that outlives the subscription.

`onCancel` deliberately does **not** call `controller.close()` — `close()`
waits on `onCancel`, so calling it from there deadlocks the `done` future.
That is documented on the extension.

### Test helpers

`pumpWithCells`, `pumpCell`, `emitAndSettle`, `emitAndPump`,
`expectCellValue`, and `expectCellGolden` do not open egresses; they drive
a `WidgetTester`. `recordPulses` follows Pattern B (caller-disposed).
`CellTestHarness` owns the recorders it creates and stops them in
`dispose`; it does **not** own the cells it registers.

---

## 5. Build-phase safety

Flutter's `setState` throws if called during `persistentCallbacks` or
`midFrameMicrotasks`. A pulse that arrives in either phase must be routed
out of the phase before it can touch widget state.

Two strategies exist, and the choice between them is the one place where
the widgets are not interchangeable.

### Strategy A — deferral (coalesce to the end of frame)

Used by `CellValueBuilder`, `CellAsyncBuilder`, and `CellListener`. A
pulse arriving during a build phase is appended to a pending list and a
single `addPostFrameCallback` is scheduled. The callback applies the
**most recent** pending pulse (for the display widgets) or delivers **all**
pending pulses in order (for the listener) and clears the list.

Two important details:

- **`CellValueBuilder` and `CellAsyncBuilder` apply only the last pulse.**
  They are "latest value" widgets; intermediate values do not need to
  render.
- **`CellListener` delivers every pulse.** Side effects are one-per-pulse;
  dropping intermediate pulses would drop side effects.

### Strategy B — immediate (surface the bug)

Used by `CellNotifier`. The `_onPulse` handler assigns `super.value`
synchronously, without checking `isCellBuildPhase`. If a pulse arrives
during a build, the `ValueListenableBuilder` inside a sibling
`CellBuilder` is marked dirty during the build, and Flutter raises its
*"setState() or markNeedsBuild() called during build"* error.

This is deliberate. A `CellBuilder` whose cell is updated **from inside
a build** is a caller bug, and the correct response is to surface it, not
to hide it. The alternative — deferral — would silently mask the bug, and
the widget would render the *next* value on the *next* frame instead of
the one the caller asked for.

Two consequences follow and are load-bearing for users:

- **The error is attributed to the `CellBuilder` element, not to the
  emitter.** A pulse emitted from one widget's `build` can throw at an
  entirely unrelated `CellBuilder` (or `CellSelector`'s sibling
  `CellBuilder`) elsewhere in the tree. When debugging that stack, the
  emitter is the bug, not the builder that threw.
- **The burden of correctness falls on every cell that has a
  `CellBuilder` in the tree.** If any cell can be mutated from inside a
  build, every `CellBuilder` bound to it is a latent crash site. This is
  stated per-widget in `CellBuilder`, `CellSelector`, and `CellNotifier`
  docs.

### Why the split?

`CellNotifier` is a `ValueNotifier` adapter. A `ValueNotifier`'s contract
is "I notify synchronously; the listener decides when to rebuild." A
deferring `CellNotifier` would break every consumer of `ValueListenable`
that is not a widget — `ValueListenableBuilder`'s siblings,
`ListenableBuilder`, any user of `addListener` that expects a
same-microtask notification. So the notifier honors its superclass's
contract, and the widgets that wrap it (`CellBuilder`, `CellSelector`)
inherit the immediate-notification semantics.

The other widgets do not wrap a `ValueNotifier`. They are free to defer,
and they do — because their contract is "render the latest value on the
next frame," not "notify synchronously."

`CellSelector` sits on both sides: it wraps `CellNotifier` (immediate
notification) but runs its own listener through `runAfterBuild`
(deferral). The reason is that `select` is user-supplied and may call
`setState` on its own — a `select` that runs during build and calls
`setState` is also a bug, but it is a *harder* bug to surface because the
call is buried in a user callback. Deferring `select` prevents the widget
from being the source of a confusing error. The notifier's own immediate
setter is unchanged — the bug in `CellNotifier`'s path is still
surfaced.

---

## 6. State restoration

`RestorableCell<V>` is a `ValueCell` whose value additionally participates
in Flutter's restoration protocol. The Flutter side of the contract
(`RestorableProperty`, which extends `ChangeNotifier` and owns the
register/unregister bookkeeping) lives in a **delegate**
(`RestorableCellDelegate`) — implementing the interface directly on the
cell would force the cell to duplicate ChangeNotifier and the private
owner-unlink logic.

The flow:

1. `restorableState<V>(...)` creates a plain `RestorableCell` (a
   `ValueCell` with an id, an initial value, and optional codecs). The
   factory lives in `cell_flutter` (as the top-level function and as
   `CellRestoration.restorableState`) because the core `cell` package is
   Flutter-free.
2. `CellRestorationScope` (a `RestorationMixin` state under an
   `UnmanagedRestorationScope` wrapper when a `bucket` is injected)
   claims a child bucket from the nearest `RestorationScope` and exposes
   `register` / `unregister` through the tree.
3. Descendant `State`s register their cells in `initState` /
   `didChangeDependencies` (never in `build` — registration writes the
   restored value into the cell). The delegate observes the cell through
   a `CellNotifier` and re-notifies the mixin so every value write is
   serialized into the bucket (`toPrimitives`).
4. On restore, the mixin replays `initWithValue` with the persisted data
   (or `createDefaultValue`), rewriting the restored value into the cell
   before the first dependent frame.

Default codecs cover `bool` / `int` / `double` / `String` / `null`;
non-primitive values without custom codecs fail loudly
(`UnsupportedError`) instead of silently not restoring. Duplicate
restoration ids throw `StateError`; registration is idempotent per cell
instance; unregistering removes the persisted value. Nested scopes claim
independent child buckets (the claimed bucket is injected for
descendants, mirroring `RestorationScope` itself).

Verified by `test/restoration/restorable_cell_test.dart` (16 tests,
including the `CounterApp` process-kill simulation) and documented in
`guide/HowTo-Restoration.md`.

---

## 7. Forms

The two-way binding problem — a `TextEditingController` writing to a cell
and a cell writing back — is solved once, in `CellEditingController`:

- **Controller → cell**: a controller write commits to the cell unless
  the cell already holds the same text.
- **Cell → controller**: a cell write updates the text unless the
  controller already shows it, preserving the cursor's **offset from the
  end** (a full replacement lands the cursor at the end).
- A `_syncing` flag guards re-entrancy; the convergence property is
  locked in by a 50-iteration alternating-write test.

`CellTextField` composes `CellEditingController` inside a real
`TextFormField`, so `Form.validate()` / `validator` / `autovalidateMode`
need no adapter layer; focus survives cell updates because the controller
is replaced only on cell swap or unmount.

`CellFormField<T>` extends `FormField<T>` and mediates the standard
`FormFieldState.didChange` against the cell in both directions. The cell
swap sync is deferred to a post-frame callback: calling `didChange`
during `didUpdateWidget` would mark the enclosing `Form` dirty while it
is building.

The 25-test suite (including the 4-field `LoginForm` integration test
with hot-restart preservation) lives under `test/forms/`; the walkthrough
is `guide/HowTo-Forms.md`.

---

## 8. Error boundary

Flutter has no subtree-scoped build-error catcher, so
`CellErrorBoundary` uses the standard `FlutterError.onError` interception
with a **strict scope filter**:

- Captures only framework-thrown build errors (`widgets library`,
  `scheduler library`, `rendering library`) — the shape of an
  invalidated-cell `ArgumentError` thrown from a `CellNotifier`
  constructor, or a `setState`-during-build framework error.
- Forwards everything else — including the binding's own report channel
  (`library: 'cell_flutter'`: type mismatches, `emitErrors` reports) and
  the test framework's failure reports — to the previously installed
  handler.
- Captures are consumed by the nearest boundary (an inner boundary never
  forwards a captured error to the outer one); a captured error while the
  fallback is already showing is forwarded rather than swallowed.
- Build-phase captures are deferred to a post-frame `setState`; the
  handler is restored on dispose (compared by a stored tear-off reference,
  because instance-method tear-offs are not `identical` across
  evaluations).

The global-interception caveat is documented on the class: use the
boundary as a root safety net. Verified by the 7 tests in
`test/error_boundary/`.

---

## 9. List virtualization

`CellListView<T>` observes a cell producing `List<T>` through
`CellValueBuilder` and renders a `ListView.builder`:

- **`CellListView.builder`** — the naive variant. Visible items rebuild
  through normal `ListView.builder` reconciliation; per-item
  `CellBuilder` composition is the documented pattern for the
  "each item has its own cell" case.
- **`CellListView.keyed`** — the keyed-diff variant. `itemKey` drives a
  per-key widget cache, so only new keys re-invoke the item builder
  (append/remove/replace cost O(1) rebuilds). Every item is wrapped in
  `KeyedSubtree(ValueKey(itemKey))` and the list supplies
  `findChildIndexCallback`, so reorders **move elements** (and their
  state) instead of replacing them. Duplicate keys throw `StateError`.
  The documented trade-offs: O(n) widget configurations held in the
  cache, O(n) diff per change, and cached widgets keep the index they
  were built with (a reorder does not re-run the builder).

Verified by the 11 tests in `test/list_view/` (rebuild-count assertions,
state-preserving reorder, scroll-position survival, 10,000-item render +
scroll).

---

## 10. Package shape

```
lib/cell_flutter.dart             barrel: re-exports package:cell + widgets
lib/hooks.dart                    barrel: optional flutter_hooks integration
lib/testing.dart                  barrel: test surface (imports flutter_test)
lib/src/cell_builder.dart         CellBuilder + ValueCell.builder extension
lib/src/cell_selector.dart        CellSelector
lib/src/cell_value_builder.dart   CellValueBuilder
lib/src/cell_async_builder.dart   CellAsyncBuilder + snapshotForPulse/Cell
lib/src/cell_listener.dart        CellListener
lib/src/cell_scope.dart           CellScope
lib/src/cell_notifier.dart        CellNotifier
lib/src/cell_stream.dart          CellAsStream extension
lib/src/cell_as_value.dart        CellAsValue extension + MirroredCell
lib/src/pulse_delivery.dart       isCellBuildPhase, runAfterBuild,
                                  retainedPulseOf
lib/src/hooks/                    use_cell.dart, use_cell_notifier.dart,
                                  use_cell_listener.dart, use_cell_async.dart
lib/src/testing/                  the eight test helpers
```

`cell_flutter.dart` re-exports `package:cell/cell.dart`, so application
code that imports it sees the whole core surface. `hooks.dart` and
`testing.dart` do **not** widen that surface — they add their own exports
on top.

The `dartdoc_options.yaml` categorization mirrors the core package: topics
appear only when a type is tagged `{@category …}` with the same string as
the YAML map key. The hooks and test files carry their own categories.

---

## 11. Status and known gaps

Core-hardening release `0.7.0` — **not 1.0**. The 1.0.0 gate was evaluated
honestly and failed: the microbenchmark gate fails for multi-builder
trees (see `guide/Benchmarks.md`), the full 30-minute fuzz gate is
carried by CI, and the external-developer usability gate is still
blocked. Verified in this binding: the replay probes for pure state,
debounce, throttle, `fromFuture`, and `fromStream` (commit `05b4895d`;
full suite 1371 tests, determinism gate 240/240). Concurrent `asyncMap`
effect attribution under `concurrency > 0` is tracked separately
and is **not** claimed by this binding.

Known gaps and resolved historical gaps:

- **Per-source error-pulse behavior: only `fromFuture`.** Only
  `Cell.fromFuture` emits `Pulse<Object>(type: 'error')` on its failure
  path; `Cell.fromStream` errors are cancelled/ignored and
  `Cell.asyncMap` mapper failures are dropped, so neither reaches the
  widget layer. `CellAsyncBuilder` / `useCellAsync` / `CellListener` /
  `asStream` document the consequence (no `hasError` / no error delivery
  for those two sources; bridge them through a custom cell that re-emits
  `'error'` pulses). The behavior is asserted in
  `test/error_pulse_sources_test.dart`, which every error-pulse doc
  comment references as the authoritative statement.
- **`emitAndSettle` does not wait for timers.** `pumpAndSettle` drains
  microtasks but not `Future.delayed` / `Timer` callbacks. A test that
  needs to observe a timer-driven state transition must use
  `emitAndPump` with an explicit `Duration` or `await tester.pump(duration)`
  after settling. Documented in `emit_and_settle.dart`.
- **Font loading for goldens.** `expectCellGolden` captures text without
  loading application fonts. Tests that use it must call
  `loadAppFonts()` (from `package:golden_toolkit`) in `setUpAll`, or the
  captured goldens render text as black boxes. `golden_toolkit` is a
  `dev_dependency` of the test suite, not of `cell_flutter`.
- **Hooks layer mirrors widget semantics, not widget architecture.** The
  hooks are not `flutter_hooks`-specific implementations of the widgets;
  they are thin adapters over `CellNotifier` and `Cell.observe`. One
  cell-swap divergence is documented by design, as a consequence of
  `flutter_hooks` state semantics (see rule 8 §8): `useCellAsync` keeps
  the previous snapshot across a cell swap until the new cell emits (key
  the enclosing `HookWidget` on the cell when reset-on-swap is required).
  `useCell` has **no** stale-frame flash: its recompute effect is keyed on
  `[select, eq, notifier]`, and `flutter_hooks` re-runs a keyed effect's
  body synchronously during the build that registers the changed keys, so
  the first build with the new cell already returns the new cell's slice
  (verified by `use_cell_test.dart`; the decision and its rationale are recorded in the library docs

If a guarantee in this document does not match the code, the code wins.
An issue report is useful.

---

## 12. Design rules

1. **The graph decides, the widget renders.** No widget-layer state, no
   widget-layer validation, no widget-layer transactions. If a feature
   needs any of those, it belongs upstream in `cell` or `cell_flow`.
2. **One egress per subscription.** Every widget opens exactly one
   `Cell.observe` per cell it displays. Every bridge opens exactly one
   observation per call, and returns a handle whose `dispose` is the
   caller's responsibility.
3. **Display granularity matches the source.** `CellBuilder` for a
   `ValueCell` you render whole. `CellSelector` for one field of a
   `ValueCell`. `CellValueBuilder` for a plain `Cell` you want the
   latest value of. `CellAsyncBuilder` for any `Cell` you want as an
   `AsyncSnapshot`. Do not use a heavier widget to work around a
   source that a lighter one already fits.
4. **Build-phase safety is not universal.** The display widgets defer;
   the notifier does not. Deferral is a widget contract, immediate
   notification is a `ValueNotifier` contract. Do not add deferral to
   `CellNotifier` — it would silently break every non-widget consumer.
5. **Bridges return handles, not bare values.** A `ValueCell` return
   from `asValueCell` would hide the egress. A `List<Pulse>` return from
   `recordPulses` would hide the recorder. The handle is the
   contract.
6. **Test surface is opt-in, not ambient.** `testing.dart` imports
   `flutter_test`. Application code never imports it. Production
   dependencies on `cell_flutter` never pull `flutter_test` into the
   build graph. This is the `bloc_test` / `mocktail` pattern and it is
   load-bearing.
7. **Hooks are the same contracts, not a second stack.** A hook and its
   equivalent widget must behave identically for the same pulse; if they
   diverge, that is a bug in one of them, not a design decision. Two
   cell-swap caveats are the known exceptions, both documented in their
   hook docs as `flutter_hooks` state-lifecycle consequences:
   `useCellAsync` keeps the previous snapshot across a cell swap, and
   `useCell` shows the previous cell's slice for one frame after a swap.
   Key the enclosing `HookWidget` on the cell when reset-on-swap is
   required.
8. **Documentation and behavior drift is a release blocker.** The two
   historical drift items — the plain-cell seed gap and the per-source
   error-pulse divergence — are resolved: the seed constraint is
   documented uniformly, and every file states that only
   `Cell.fromFuture` emits error pulses. New divergence of the same kind
   is not acceptable: a future release must either fix the code to match
   the docs, or fix the docs to match the code — but not both, and not
   silently.
---

## 13. Migration paths

`guide/Migrating-From-Provider.md`, `guide/Migrating-From-Riverpod.md`,
`guide/Migrating-From-Bloc.md`, and `guide/Migrating-From-SetState.md`
map each source package's state container, observers, and async story
onto cells and widgets. Each guide's worked examples are backed by
before/after fixture pairs (`test/migration/<source>/before_*.dart` +
`after_*.dart`, written in the *real* source package) whose rendered
text parity is asserted by `test/migration/migration_test.dart`. A
future API change that breaks a guide is therefore a test failure, not
a doc drift.

`doc/comparison.md` is the honest comparison document; its
should-I-use-this section answers the adoption question directly.

---

## 14. In-app inspector

`CellFlutterDevTools.enable()` (opt-in, no-op in release) turns on a
`CellRegistry`; `CellFlutterDevTools.register(symbol, cell)` adds a
cell to it, opening one `Cell.observe` link that journals the newest
ten pulses. `CellInspectorOverlay` renders a floating button + panel
listing registered cells (live values, pulse counts, expandable pulse
journals) and listens to the registry (`ChangeNotifier`).

Registration is **explicit** by design — an automatic registry would
silently miss cells created before `enable()`. The registry never
disposes cells; `unregister`/`clear` only release observation links.
The planned DevTools browser extension (0.10.1) will read this registry
over `ext.cellFlutter.*` service extensions.

---

## 15. Lint rules

`packages/cell_flutter_lints/` ships four `custom_lint` rules:

- `cell_avoid_creation_in_build` — cell factories inside `build`
  methods / `HookBuilder` / `CellBuilder` builder closures.
- `cell_unkeyed_hook_builder` — unkeyed `HookBuilder`s observing a
  swappable widget field through `useCell*` (restricted to the field
  case by design).
- `cell_forgotten_dispose` — `asValueCell` / `recordPulses` results
  assigned to fields with no `dispose` / `stop` in the class's
  `dispose` method (structural; `HookWidget` cleanups out of scope).
- `cell_collection_selector_without_equals` — collection slices in
  `CellSelector` / `useCell` without `equals`.

Rules are verified through `// expect_lint:` fixtures in the package's
`example/` (custom_lint's official test mechanism); the harness test
runs the CLI and fails on unmet expectations. Two analyzer-8.4
adaptations worth knowing: AST nodes no longer carry `staticElement`
(the rules use syntactic field checks), and top-level calls with named
arguments can surface as `MethodInvocation`.

---

## 16. Router bridge (`cell_flutter_router`)

The bridge is deliberately **non-invasive**: it never replaces
`go_router`'s delegate or re-implements route matching. The three
pieces compose around a stock `GoRouter`:

- `CellRouterState` — an immutable (location, queryParams, extra)
  value with JSON codecs for restoration. `extra` is excluded from
  persistence on purpose: extras are live objects.
- `CellRouterStateMirror` — listens to **both** notifiers of the
  router (the `routeInformationProvider` and the
  `routerDelegate`) because they fire at different points of a route
  change (provider first, delegate after), and defers a second read to
  a post-frame callback. The equality guard in the write makes the
  extra pass free.
- `CellRouterScope` + `useCellRouter` — an `InheritedWidget` lookup
  plus a `useCell`-driven controller.

Two go_router realities are pinned by tests rather than papered over:

1. `currentConfiguration` is a `RouteMatchList`, not a
   `GoRouterState`.
2. Imperative navigations (`push` / `replace`) keep the list's base
   uri; the live location is the top match's `matchedLocation` (when
   the top match is an `ImperativeRouteMatch`).

The package pins `go_router: ">=14.0.0 <18.0.0"` — 18.x requires
Dart 3.12, which is newer than this repository's toolchain; the CI
matrix will widen the bound when the toolchain moves.

## 17. Persistence (`cell_flutter_persistence`)

`PersistedCell` composes two orthogonal survival mechanisms instead of
conflating them:

- **Restoration** — the inner `RestorableCell`, registered with a
  `CellRestorationScope` (process kill).
- **Persistence** — an observation link on that cell writing through
  a `CellPersistenceAdapter` per `WriteMode` (explicit quit).

`WriteMode.immediate` writes every change, `debounced` (1s default)
coalesces bursts, and `onAppPause` defers to an explicit
`handleAppPaused()`. `load()` never throws — a failing read returns
`false` and leaves the cell untouched — while `persistNow()` surfaces
adapter errors to the caller. `SharedPreferencesAdapter` uses the
non-deprecated `SharedPreferencesAsync` API with typed getters for the
five primitive shapes and JSON codecs for custom types.

## 18. Benchmarks

`benchmark/` compares cell_flutter against `ValueListenableBuilder`,
flutter_riverpod, and flutter_bloc on identical scenarios
(single/fanout/100-builder/selector), measuring per-update frame time
(p50/p99) in `testWidgets`. `tool/benchmark.dart` parses the `BENCH`
lines, stores `benchmark/baseline.json`, and fails CI when any
baseline scenario regresses more than 15% **and** by more than a
300µs absolute noise floor — a pure 15% gate on sub-millisecond times
bites on OS scheduling noise (a 300µs p99 leaves ~45µs of budget).

The baseline is recorded on the repository toolchain; re-baselining is
a deliberate, reviewed action (`--update`), never an automatic CI
step.

## 19. API stability

1.0.0 freezes the public surface of `cell_flutter.dart` and
`hooks.dart` (plus `testing.dart`'s documented test API). The policy:

- Breaking changes require a major version bump (semver).
- Deprecations require a deprecation warning for at least one minor
  version before removal.
- New features land in minor versions; ecosystem packages
  (`cell_flutter_router`, `cell_flutter_persistence`,
  `cell_flutter_lints`) version independently and may still move
  within 0.x until their own 1.0.0.
- Anything not exported from a public barrel is not covered by the
  guarantee.

## 20. Roadmap

- 1.0.x — browser DevTools extension (deferred from the 1.0.0 scope),
  benchmark-gate refinements (regression budgets per scenario),
  any 1.0 patch fixes.
- 1.1.0 — DevTools screenshots, per-platform golden baseline
  tooling, router bound widening once the toolchain reaches Dart
  3.12.
- Later — `CellListView` diffing optimizations, form-field
  federation (multi-cell forms), an official state-persistence
  encryption adapter.
