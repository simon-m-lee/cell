# cell_flow

## Install and import

```bash
dart pub add cell cell_flow cell_tissue
```

```dart
import 'package:cell_flow/cell_flow.dart';  // re-exports package:cell
import 'package:cell_tissue/cell_tissue.dart';
```

## AI agents start here

Read this before opening any other page.

`cell_flow` is designed with AI coding agents in mind. Every top public symbol
carries a machine-readable `### AI Agent Guide` block, and the surfaces below
let an agent reliably pick the right operator and generate code that compiles
against the live API.

1. **Version pin:** `cell 1.1.0`, `cell_flow 1.0.0`, `cell_tissue 1.0.0`.
2. **Preflight:** `dart run tool/ai_preflight.dart` — prints the resolved versions and any stale pins.
3. **API chooser:** `lib/doc/api_chooser.dart` (generated from the `### AI Agent Guide` doc blocks).
4. **Layer guides:**
    - `guide/HowTo-Mitose-Flow.md` — Flow operator choices
    - `guide/HowTo-Mitose-Cell.md` — Cell factory choices
    - `guide/HowTo-Mitose-Tissue.md` — Tissue collection choices
5. **The seam sentence:** *The instruction decides, the chain assembles, the observer glues.*

## If you have a BRD sentence that says…

| BRD sentence | First Flow construct | Do NOT |
|---|---|---|
| "flag at-risk when remaining < MCT" | `riskOf` clause in `FlowInstructionBase` | put in `Cell.observe` |
| "do not flood the supervisor" | latch / `Distinct` + ACK `reset()` | stock `Distinct` without reset |
| "latest reservation / flight only" | `Flow.switchMap` | `Flow.mergeMap` |
| "prevent double checkout / ACK" | `Flow.exhaustMap` | hand-roll a busy flag |
| "retry flaky RTU" | `Flow.retry` or harness pump | retry inside `riskOf` |
| "wait for silence" | `Flow.debounce` on the feed | use it as the policy gate |

(The full matrix lives in `lib/doc/api_chooser.dart`; this is the 6-row elevator version.)

---

**Codename: Mitosis** · `1.0.0`

[![Dart](https://img.shields.io/badge/Dart-3.5%2B-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT%20%2F%20Apache--2.0-blue.svg)](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/LICENSE)
[![Status](https://img.shields.io/badge/Status-RC%20on%20pub.dev-yellow.svg)](#versioning)

**100 Rx-shaped operators for the [Cell](https://github.com/simon-m-lee/cell) framework.** Debounce, switchMap, zip, retry, buffer, and the complete reactive stream vocabulary — implemented as `FlowInstruction`s on the **same graph** as `package:cell`, with forensic pulse provenance on every hop.

> **Mitose pipeline — the umbrella feature.** The root repository ships an AI-executable pipeline that turns a business requirement into a working Cell + Flow + Tissue solution with its BRD, WalkThrough, Demo, ARCHITECTURE, and FEATURES documents. An AI prompt agent follows [`guide/HowTo-Mitose.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose.md); this package supplies the **Flow layer** rules via [`guide/HowTo-Mitose-Flow.md`](https://github.com/simon-m-lee/cell/blob/master/guide/HowTo-Mitose-Flow.md). See the [root README](https://github.com/simon-m-lee/cell#readme).

---

## 🚀 Quick Start

### Installation

Add both packages to your `pubspec.yaml`:

```yaml
dependencies:
  cell: ^1.1.0     # the stable versions on pub.dev
  cell_flow: ^1.0.0
```

> ℹ️ The stable releases (`cell` `1.1.0`, `cell_flow` `1.0.0`) are published on pub.dev (see [CHANGELOG.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/CHANGELOG.md)).

Import once in your Dart file:

```dart
import 'package:cell_flow/cell_flow.dart'; // re-exports package:cell
```

### Your First Pipeline (30 seconds)

```dart
import 'package:cell_flow/cell_flow.dart';

Future<void> main() async {
  final query = Cell.ingress<String>();

  // Build a reactive search pipeline
  final results = query.cell
      .map<String, String>(project: (q) => q.trim().toLowerCase())
      .filter<String>(test: (q) => q.length >= 2)
      .debounce<String>(duration: const Duration(milliseconds: 300))
      .asyncMapLatest<String, List<Hit>>(mapper: (q) => api.search(q));

  // Observe results
  Cell.observe(source: results.cell, effect: (Pulse pulse) {
    print('Found ${(pulse.payload! as List<Hit>).length} hits');
  });

  // Emit user input
  await query.emitAsync('Dart packages');
}
```

> 💡 **New to cell_flow?** Read the **[How to Start Guide](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/guide/HowTo-Start.md)** for a complete 15-minute tutorial with 5 copy-paste examples.

---

## 🎯 What Problem Does Flow Solve?

**cell** already gives you nodes (`Cell`), signals (`Pulse`), integrity (`TestCell`), and gates (`Receptor`). But everyday stream work — debouncing input, cancelling stale requests, batching events — would otherwise require custom `Timer`s and one-off receptors.

**cell_flow** names those policies:

| You want to… | cell_flow provides | Performance |
|---|---|---|
| Debounce user input | `Flow.debounce` or `.debounce()` | Last value after silence |
| Cancel stale HTTP requests | `Flow.switchMap` or `.switchMap()` | Drop previous inner |
| Pair values by index | `Flow.zip` or `.zipWith()` | Index-based pairing |
| Retry failed operations | `Flow.retry` or `.retry()` | Configurable retry count |
| Batch events | `Flow.bufferCount` or `.bufferCount()` | Collect N values |
| Prevent double-taps | `Flow.exhaustMap` or `.exhaustMap()` | Ignore while busy |
| Combine multiple streams | `Flow.combineLatestWith` | Latest from all sources |

**Key insight:** The graph, locks, validation, and provenance stay in **cell**. Flow only decides *which* pulses leave and *when*.

---

## 🏆 Why Flow (what Rx/raw Streams don't give you)

- **Forensic pulses on every hop.** Each operator appends a `step` to the
  pulse trace and re-publishes with provenance; `pulse.root.source` recovers
  the original ingress after any pipeline depth. RxDart and raw streams carry
  bare values — no lineage, no audit trail.
- **Reusable, composable blueprints.** A `FlowInstruction` is a policy you
  can materialize any number of times (`toHandle`), chain with `+` into one
  Receptor under one lock, and unit-test without any graph. Stateful
  operators allocate their state **per activation**, so two handles from one
  blueprint never share timers, queues, or accumulators.
- **Governance on the data path.** Every node is a `Cell`: `TestCell` gates,
  zero-copy deputies, `Context` authority, and the transactional command
  model (`Cell.txApply` / `Cell.transaction`) apply to Flow pipelines as
  much as to state cells — validation is enforced, not remembered.
- **Lifecycle that cleans up after itself.** Notifier observers and periodic
  timers stop when a handle's cell is invalidated; long-lived processes do
  not accumulate dead branches.
- **One graph, three layers.** Operators run on the same topography as
  `cell` state and `cell_tissue` collections — the "Flow decides, Tissue
  records" pattern ships as libraries, not as hand-wired glue.
- **Pinned performance.** A benchmark suite with a checked-in baseline and a
  15% regression gate ([`benchmark/`](benchmark/README.md)) publishes the
  honest, feature-accounted numbers — see the cost ladder there.

---

## 🔧 Three Ways to Build Pipelines

### Way 1: Static Factories (Recommended for beginners)

```dart
final box = Cell.ingress<String>();

final filtered = Flow.filter<String>(
  box.cell, 
  test: (q) => q.length >= 2,
);

final debounced = Flow.debounce<String>(
  filtered.cell,
  duration: const Duration(milliseconds: 300),
);
```

**Best for:** Multi-source operators (`merge`, `zip`, `combineLatestWith`), naming nodes for logs.

---

### Way 2: Fluent Chaining (Most readable)

```dart
final box = Cell.ingress<String>();

final results = box.cell
    .filter<String>(test: (q) => q.length >= 2)
    .debounce<String>(duration: const Duration(milliseconds: 300))
    .asyncMapLatest<String, List<String>>(mapper: api.search);
```

**Best for:** Linear pipelines, readability, quick prototyping.

> ⚠️ **Note:** Each fluent step creates a **new Cell/Receptor**. `filter().map()` = 2 cells.

---

### Way 3: InstructionChain (One Receptor, many ops)

```dart
final box = Cell.ingress<String>();

// Build a reusable policy - runs in ONE Receptor under ONE lock
final gate = FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) {
      final s = (p.payload as String).trim();
      return s.isEmpty ? null : p;
    }) +
    FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) =>
        p.payload.toString().startsWith('x') ? p : null);

final handle = gate.toHandle(source: box.cell);
```

**Best for:** Sync policies (trim, filter, tap), shared locks, unit testing gates.

> 💡 **Key difference:** `+` chains run in **one Receptor** under **one lock**. Fluent chains create multiple cells.

---

## 📊 Operator Catalog (100 operators)

The `Flow` facade exposes **100 operator factories** across these families:

| Family | Highlights |
|---|---|
| Create / bridge | `of`, `fromIterable`, `fromFuture`, `deferFuture`, `fromStream`, `deferStream`, `range`, `repeat` |
| Transform | `map` (index/not-null/when/keys/values variants), `mapTo`, `pluck` (key/all/path), `mapValueOr` |
| Scan / fold | `scan`, `reduce`, `pairwise`, `asyncFold`, `asyncFoldLatest`, `asyncFoldExhaust`, `asyncReduce` |
| Filter / gate | `filter`, `distinct`, `skipRepeated` |
| Take / skip | `take`, `takeWhile`, `takeUntil`, `skip`, `skipWhile`, `skipUntil`, `skipWhen` |
| Flatten (inner sequences) | `concatMap`, `concat`, `concatAll`, `concatLatest`, `mergeMap`, `switchMap`, `exhaustMap`, `merge`, `mergeAll`, async expand family |
| Combine | `mergeWith`, `zipWith`, `zip`, `zipAll`, `combineLatestWith`, `withLatestFrom`, `race`, `sample`, `audit` |
| Time | `delay` (latest/when/selector), `debounce`, `throttle`, `timeout`, `timeoutWithFallback`, `interval`, `sampleTime`, `auditTime` |
| Collect / batch | `bufferCount`, `bufferTime`, `bufferWhen`, `bufferWithPredicate`, `bufferWithTimeAndCount`, `windowCount`, `windowTime` |
| Route / partition | `groupBy`, `groupCollect`, `groupByCount`, `partition`, `partitionMap`, `partitionOnly`, `iif` |
| Utility | `retry`, `share`, `shareReplay`, `startWith`, `tap`, `tapAll`, `tapWithIndex` |

📖 **Full catalog with signatures:** [`FEATURES-Flow.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/FEATURES-Flow.md)

---

## 🎓 Common Patterns

### Pattern 1: Search-as-You-Type

```dart
final query = Cell.ingress<String>();

final results = query.cell
    .map<String, String>(project: (q) => q.trim().toLowerCase())
    .filter<String>(test: (q) => q.length >= 2)
    .distinct<String>()
    .debounce<String>(duration: const Duration(milliseconds: 300))
    .asyncMapLatest<String, List<Hit>>(mapper: api.search);
```

**Why it works:** `asyncMapLatest` cancels stale requests when the user types again.

---

### Pattern 2: Form Validation

```dart
final raw = Cell.ingress<String>();

final email = raw.cell
    .map<String, String>(project: (s) => s.trim().toLowerCase())
    .filter<String>(test: (s) => s.contains('@'))
    .distinct<String>()
    .asyncMap<String, User>(
      mapper: api.lookup,
      onError: (e, _) => log.warn(e),
    );
```

---

### Pattern 3: Prevent Double-Checkout

```dart
final taps = Cell.ingress<void>();

final receipts = taps.cell
    .map<void, void>(project: (v) => v)
    .exhaustMap<void, Receipt>(
      project: (_) => api.checkout(cart),
    );

// While checkout runs, additional taps are ignored
await taps.emitAsync(null);  // Starts checkout
await taps.emitAsync(null);  // Ignored
```

---

### Pattern 4: Batch Telemetry

```dart
final events = Cell.ingress<Metric>();

final batches = Flow.bufferWithTimeAndCount<Metric>(
  events.cell,
  duration: const Duration(seconds: 5),
  count: 50,
).asyncMap<List<Metric>, void>(mapper: (batch) => api.flush(batch));

// Flushes when either 50 events arrive OR 5 seconds pass
```

---

### Pattern 5: Combine Multiple Sources

```dart
final price = Cell.ingress<int>();
final currency = Cell.ingress<String>();

final display = Flow.withLatestFrom<int, String>(
  price.cell,
  others: [currency.cell],
  combine: (p, latest) => '${latest.single} $p',
);

await price.emitAsync(20);       // Waits for currency
await currency.emitAsync('EUR'); // Now both have values
await price.emitAsync(25);       // → 'EUR 25'
```

> ⚠️ **Gotcha:** `withLatestFrom` waits until **every** other Cell has at least one value.

---

## 🧭 Operator Selection Matrix

100 operators ship in the `Flow` facade. Start from the goal, not the name:

| Goal | Operator(s) |
|---|---|
| Transform each value once | `map`, `mapTo`, `mapWithIndex`, `mapNotNull` |
| Skip repeated values | `skipRepeated` (consecutive), `distinct` (global) |
| Cancel previous work | `switchMap`, `asyncMapLatest` |
| Ignore inputs while work is in flight | `exhaustMap` |
| Preserve order with concurrency | `asyncMap` / `mergeMap` (completion-ordered) vs `concatMap` / `asyncExpand` (input-ordered, sequential) |
| Wait for the last event of a burst | `debounce`, `delayWhen` |
| Rate-limit a hot source | `throttle` |
| Take the latest of several sources | `combineLatestWith`, `withLatestFrom` |
| Pair one source with others | `zip`, `zipWith`, `pairwise` |
| Add a timeout | `timeout`, `timeoutWithFallback`, `race` |
| Retry failures | `retry` |
| Gather a window of values | `bufferCount`, `bufferTime`, `bufferWithTimeAndCount` |
| Emit windows progressively | `windowCount`, `windowTime` |
| Route by payload | `partition`, `partitionMap`, `partitionOnly`, `iif` |
| Side effects without mutation | `tap`, `tapAll` |

## ⚠️ Error-Emission Policy

Operators do not agree on what happens after `onError` fires — read this
before porting between families:

| Pattern | Operators |
|---|---|
| `onError` + drop the pulse | `mapValue`, `filter`, `takeWhile`, `skipWhen`, `distinct`, … |
| `onError` + emit fallback | `mapValueOr`, `asyncMapWithFallback`, `timeoutWithFallback` |
| `onError` + optional error pulse | `fromFuture`, `timeout`, `retry` (via `emitErrorPulse`) |
| `onError` + silent drop (no error pulse) | `asyncMap`, `asyncMapWithRetry`, `asyncMapWithTimeout`, `asyncMapConcurrent` |

The `asyncMap*` family has no `emitErrorPulse` parameter; the `fromFuture*`
family does. Porting error handling from one to the other silently changes
error visibility — check the operator's docstring.

## 🔍 Operator Trace Naming

Every operator appends a `step` to the pulse trace. Two conventions exist:

- **Flat names** — the operator name: `'MapValue'`, `'Filter'`.
- **Dotted names** — a sub-branch inside one operator: `'Throttle.leading'`,
  `'DebounceLeading.trailing'`, `'RouteWhen.$i'`, `'RouteByKey.else'`.

The dotted form always means "this operator has multiple emission paths";
read the step to know which edge fired.

## ♻️ Lifecycle & Resources

- **Blueprints are reusable.** A `FlowInstruction` may be stateful, but
  stateful operators allocate their timers/queues/accumulators from a
  per-activation factory: two `toHandle` calls on one blueprint never share
  state, and stateless blueprints are shared safely.
- **Handles self-clean.** Operators that observe notifiers or run periodic
  timers stop them once the materialized handle's cell is invalidated
  (`cell.isInvalidated`). Dispose a pipeline by invalidating its anchor cell.
- **`toHandle` allocates a full cell.** Every activation builds a
  `Receptor` + `Nucleus` + `Cell`. For a single pulse this is pure overhead —
  batch work through one handle, and prefer the `+` chain form
  (one Receptor for many sync operators) when applicable.
- **Backpressure is upstream's job.** `mergeMap(concurrency: 0)` means
  "no limit imposed by this operator" (capped at 1 << 20 in flight); a
  synchronous burst still grows the queue. Throttle at the ingress, not in
  the operator.
- **`FlowHandle` is untyped by design.** Every `Flow` factory returns the
  same untyped `FlowHandle` record; the operator's own type checks enforce
  payload types, not the handle.

## 🔎 Trace & Provenance

- **Traces grow with pipeline depth.** Each operator appends one `step` per
  pass, so `trace.length` is proportional to pipeline depth x passes —
  not to the total number of pulses. Traces are for forensics, not for
  aggregation; use `Cell.synthesis` or a tissue if you need running
  statistics.
- **`pulse.source` is the immediate emitter.** Every operator re-publishes
  with `source:` set to its own cell (the hop that just fired). To find the
  original ingress, read `pulse.root.source` — the trace preserves the
  full journey.
- **Null payloads drop silently.** For a non-nullable payload type `S`, a
  `null` payload is treated as "no value" (the pulse is dropped without
  calling `onError`). If you need to see nulls, use a nullable `S`.
- **`FromFutures` futures are hot.** All futures start before the first
  trigger; a pre-trigger rejection is an unhandled zone error. Use
  `DeferFuture` to defer creation until the trigger.


---

## 🧪 Testing Your Pipelines

### Test a Sync Chain (No Timer)

```dart
import 'package:cell_flow/cell_flow.dart';
import 'package:test/test.dart';

void main() {
  test('sanitize drops blanks', () async {
    final gate = FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) {
          final s = (p.payload as String).trim();
          return s.isEmpty ? null : p;
        }) +
        FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) => p);

    final receptor = Receptor.instruction(gate);

    expect((await receptor.call(Pulse('  x  ')))?.payload, equals('x'));
    expect(await receptor.call(Pulse('   ')), isNull);
  });
}
```

### Test an Async Pipeline (With Timer)

```dart
void main() {
  test('debounce emits last after silence', () async {
    final ingress = Cell.ingress<String>();
    
    final debounced =
        Flow.debounce<String>(ingress.cell, duration: const Duration(milliseconds: 100));
    
    final results = <String>[];
    Cell.observe(source: debounced.cell, effect: (Pulse pulse) {
      results.add(pulse.payload as String);
    });
    
    await ingress.emitAsync('a');
    await ingress.emitAsync('b');
    await ingress.emitAsync('c');
    
    // Wait past debounce duration
    await Future.delayed(const Duration(milliseconds: 150));
    
    expect(results, equals(['c']));
  });
}
```

---

## 📦 Package Layout

```text
package:cell_flow/cell_flow.dart
  part  src/flow.dart               Flow.* facade
  part  src/flow_core.dart          FlowInstruction, toHandle, operator +
  part  src/fluent_operator.dart    Cell / FlowHandle extensions
  import src/instruction/*.dart     operator classes
```

> ✅ **Best practice:** Application code should import **only** `package:cell_flow/cell_flow.dart`.

---

## 📚 Documentation

| Document | Contents |
|---|---|
| 📘 **[How to Start](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/guide/HowTo-Start.md)** | **Quick-start tutorial (15 min)** with 5 examples |
| 🏗️ [ARCHITECTURE-Flow.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/ARCHITECTURE-Flow.md) | Why Flow is shaped this way |
| 📋 [FEATURES-Flow.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/FEATURES-Flow.md) | Complete operator catalog (100 operators) |
| 🎬 [DEMO_GUIDE.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/DEMO_GUIDE.md) | High-fidelity walkthroughs |
| 🔗 [HowTo-Fluent_Operator.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/guide/HowTo-Fluent_Operator.md) | Method chaining deep dive |
| 🎯 [HowTo-FlowInstruction-Receptor.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/guide/HowTo-FlowInstruction-Receptor.md) | Purpose-built Receptors |

---

## 🛠️ Runnable Examples

Explore the `example/` directory for complete, runnable demos:

| File | Scenario |
|---|---|
| `filter_data_quality_demo.dart` | Data quality gates |
| `stability_search_demo.dart` | Search box with debounce |
| `exhaust_map_submit_checkout_demo.dart` | Prevent double-checkout |
| `combine_latest_sync_demo.dart` | Sync multiple sources |
| `buffer_batch_processing_demo.dart` | Batch telemetry |
| `retry_timeout_flaky_network_demo.dart` | Resilient HTTP |
| `ICU-alarm-pipeline-Demo.dart` | Complex event processing |
| `switch_map_dynamic_dependency_demo.dart` | Dynamic dependencies |

Run any example:

```bash
cd packages/cell_flow
dart run example/filter_data_quality_demo.dart
```

---

## ⚙️ Important Rules

1. **A Cell does not complete.** Use `concat` on **inners** (lists/futures/streams), not Cell-then-Cell.
2. **`reduce` / `scan` are running folds**, not terminal values.
3. **Fluent `filter().map()` = 2 cells.** Use `Filter + MapValue` for **one Receptor**.
4. **Use `+` for sync policies.** Keep timers and HTTP on the next node.
5. **Resolve `cell` and `cell_flow` together** — this package's pubspec pins `cell ^1.1.0`; resolve the stable line (`cell ^1.1.0`, `cell_flow ^1.0.0`) on pub.dev.

---

## 📌 Versioning

| Package | Version | Status |
|---|---|---|
| `cell` | `1.1.0` | Stable — on pub.dev |
| `cell_flow` | `1.0.0` | Stable — on pub.dev |

The stable releases — `cell` `1.1.0` and `cell_flow` `1.0.0` — are published on pub.dev (see [CHANGELOG.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/CHANGELOG.md)).

**Mitosis** is the release codename (like an Android Studio animal); it is not part of the SemVer string.

---

## 📄 License

**Dual-licensed:** MIT or Apache-2.0 — see [`LICENSE`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/LICENSE) and file headers.

Copyright (c) 2025-Present Lee Man Hoi Simon. See [`AUTHORS`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/AUTHORS).

> ℹ️ Operator *names* follow ReactiveX vocabulary. Implementations are original Cell Flow; using `switchMap` as a name does not require an RxJS copyright header.

---

## 🔗 Links

- 🏠 **Repo:** [github.com/simon-m-lee/cell](https://github.com/simon-m-lee/cell)
- 📦 **This package:** [packages/cell_flow](https://github.com/simon-m-lee/cell/tree/master/packages/cell_flow)
- 🐛 **Issues:** [github.com/simon-m-lee/cell/issues](https://github.com/simon-m-lee/cell/issues)
- 📖 **Cell framework:** [packages/cell](https://github.com/simon-m-lee/cell/tree/master/packages/cell)

---

**Ready to build reactive pipelines?** Start with the **[How to Start Guide](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flow/guide/HowTo-Start.md)** →
