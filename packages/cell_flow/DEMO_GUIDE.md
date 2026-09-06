# DEMO_GUIDE.md

# (Cell + Flow) Demo Guide

## From Simple Operators to Real-World Applications

A comprehensive guide to understanding the Cell Framework through practical examples, organized from fundamental concepts to complex real-world applications.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Core Concepts](#core-concepts)
3. [Demo Learning Path](#demo-learning-path)
4. [Level 1: Foundation Operators](#level-1-foundation-operators)
5. [Level 2: Flow Control](#level-2-flow-control)
6. [Level 3: Async & Composition](#level-3-async--composition)
7. [Level 4: Complex Orchestration](#level-4-complex-orchestration)
8. [Level 5: Real-World Applications](#level-5-real-world-applications)
9. [Operator Reference](#operator-reference)
10. [Combining Patterns](#combining-patterns)
11. [Common Pitfalls](#common-pitfalls)
12. [Next Steps](#next-steps)

---

## Introduction

The Cell Framework provides a reactive programming model where **Cells** hold state, **Pulses** carry signals, and **Flow** operators transform data streams. This guide walks you through the demo examples from simple operators to complex real-world applications.

### What You'll Learn

- How to use each operator correctly
- When to choose one operator over another
- How to combine operators into pipelines
- How to build production-ready applications
- Common patterns and anti-patterns

### The Three-Layer Architecture

Every demo follows the same architectural pattern:

| Layer | Responsibility | Examples |
|-------|----------------|----------|
| **Cell** | Holds state, carries data | `Cell.ingress`, `Cell.state`, `Cell.observe` |
| **Flow** | Transforms, filters, controls timing | `Flow.map`, `Flow.filter`, `Flow.debounce` |
| **Observer** | Side effects, UI updates, logging | `Cell.observe` |

**The Golden Rule:** Flow transforms data. Cell holds state. Observer handles side effects. Never mix these responsibilities.

---

## Core Concepts

### What is a Cell?

A Cell is a reactive node that:
- Holds state (`Cell.state`)
- Accepts external input (`Cell.ingress`)
- Broadcasts changes to observers
- Validates incoming data (`TestCell`)

```dart
// A simple state cell
final counter = Cell.state<int>(
  initial: 0,
  evolve: (host, pulse) => Pulse(host.value + 1),
);

// Read the value
print(counter.cell.value); // 0

// Update the value
await counter.updateAsync(5);
```

### What is a Pulse?

A Pulse is an immutable message that carries:
- **Payload**: The actual data
- **Type**: Semantic category for routing
- **Priority**: Execution urgency (0-100)
- **Context**: Provenance metadata
- **Trace**: Transformation history

```dart
final pulse = Pulse.governed<String>(
  payload: 'Hello, World!',
  type: 'message',
  priority: 60,
  context: PulseContext.userAction(
    actor: 'user_123',
    reason: 'Sending message',
  ),
);
```

### What is Flow?

Flow provides operators that transform pulses:
- **Map**: Transform each value
- **Filter**: Remove unwanted values
- **Debounce**: Wait for silence
- **Throttle**: Limit frequency
- **AsyncMap**: Handle async operations

```dart
final result = searchInput.cell
    .debounce(duration: Duration(milliseconds: 300))
    .asyncMap((query) => api.search(query))
    .filter((results) => results.isNotEmpty);
```

---

## Demo Learning Path

```
Level 1: Foundation Operators (Start Here)
├── Cell.state - State Management
├── Cell.ingress - Input Gateway
├── Cell.observe - Side Effects
├── Flow.map - Transformation
└── Flow.filter - Validation

Level 2: Flow Control
├── Flow.debounce - Search-as-you-type
├── Flow.throttle - Rate Limiting
├── Flow.distinct - Noise Reduction
└── Flow.tap - Logging & Analytics

Level 3: Async & Composition
├── Flow.fromFuture - Legacy API Bridge
├── Flow.fromStream - Real-time Data
├── Flow.asyncMap - Parallel Processing
├── Flow.switchMap - Dynamic Sources
└── Flow.mergeWith - Stream Merging

Level 4: Complex Orchestration
├── Flow.buffer - Batch Processing
├── Flow.retry - Fault Tolerance
├── Flow.timeout - Deadlines
├── Flow.combineLatest - Real-time Sync
└── Flow.exhaustMap - Submit Protection

Level 5: Real-World Applications
├── Pharmacy Dispense - Transactions
├── ICU Alarm - Medical Monitoring
├── Forensic Pipeline - Audit & Compliance
└── Data Quality - Monitoring & Validation
```

---

## Level 1: Foundation Operators

### 1. Cell.state — State Management

**File:** Built into the Cell Framework core

**What it does:** Creates a persistent state atom that can be read and updated.

**When to use:** Any time you need to store and manage mutable state.

```dart
final counter = Cell.state<int>(
  initial: 0,
  evolve: (host, pulse) => Pulse(host.value + 1),
);

// Read
print(counter.cell.value); // 0

// Update (synchronous)
counter.update(5);

// Update (asynchronous)
await counter.updateAsync(10);

// Observe changes
Cell.observe(
  source: counter.cell,
  effect: (pulse) => print('Counter: ${pulse.payload}'),
);
```

**Key Insight:** The `evolve` function defines how the state changes. It receives the current value and the incoming pulse, and returns the new value.

---

### 2. Cell.ingress — Input Gateway

**File:** Built into the Cell Framework core

**What it does:** Creates an entry point for external events to enter the reactive graph.

**When to use:** UI events, network callbacks, hardware interrupts.

```dart
final searchInput = Cell.ingress<String>();

// Emit from UI
searchInput.emit('dart');

// Or with async safety
await searchInput.emitAsync('flutter');

// Observe the input
Cell.observe(
  source: searchInput.cell,
  effect: (pulse) => print('Search: ${pulse.payload}'),
);
```

**Key Insight:** Ingress cells are stateless — they only relay events. For persistent state, use `Cell.state`.

---

### 3. Cell.observe — Side Effects

**File:** Built into the Cell Framework core

**What it does:** Creates a terminal observer that executes side effects when a pulse arrives.

**When to use:** UI updates, logging, database writes, network requests.

```dart
final observer = Cell.observe(
  source: counter.cell,
  effect: (pulse) {
    // This runs on every state change
    print('Counter changed to: ${pulse.payload}');
    updateUI(pulse.payload);
  },
);

// Stop observing
observer.stop();

// Start again
observer.start();
```

**Key Insight:** Observers are terminal — they don't propagate pulses. They're for side effects only.

---

### 4. Flow.map — Transformation

**File:** `filter_data_quality_demo.dart`

**What it does:** Transforms each value through a synchronous function.

**When to use:** Data formatting, type conversion, calculations.

```dart
final input = Cell.ingress<int>();

final doubled = Flow.map<int, int>(
  input.cell,
  project: (n) => n * 2,
);

Cell.observe(
  source: doubled.cell,
  effect: (pulse) => print('Doubled: ${pulse.payload}'),
);

input.emit(5); // Prints: Doubled: 10
```

**Key Insight:** Map is pure — it doesn't modify the original data, it creates new data.

---

### 5. Flow.filter — Validation

**File:** `filter_data_quality_demo.dart`

**What it does:** Removes values that don't satisfy a predicate.

**When to use:** Validation, data cleaning, quality control.

```dart
final input = Cell.ingress<int>();

final positiveOnly = Flow.filter<int>(
  input.cell,
  test: (n) => n > 0,
);

Cell.observe(
  source: positiveOnly.cell,
  effect: (pulse) => print('Positive: ${pulse.payload}'),
);

input.emit(5);  // Prints: Positive: 5
input.emit(-3); // Nothing (filtered out)
input.emit(0);  // Nothing (filtered out)
```

**Key Insight:** Filter returns `null` to drop values. The observer never sees dropped values.

---

## Level 2: Flow Control

### 6. Flow.debounce — Search-as-you-type

**File:** `stability_search_demo.dart`

**What it does:** Waits for a period of silence before emitting the latest value.

**When to use:** Search boxes, auto-save, form validation.

```dart
final searchInput = Cell.ingress<String>();

final debounced = Flow.debounce<String>(
  searchInput.cell,
  duration: Duration(milliseconds: 300),
);

final searchResults = Flow.asyncMapLatest<String, List<String>>(
  debounced.cell,
  mapper: (query) async => await api.search(query),
);

// User types: 'd', 'da', 'dar', 'dart'
// Only 'dart' triggers the API call
```

**Why this matters:** Without debounce, every keystroke triggers an API call. With debounce, only the final query is processed.

```dart
// ❌ Bad: 4 API calls
searchInput.emit('d');
searchInput.emit('da');
searchInput.emit('dar');
searchInput.emit('dart');

// ✅ Good: 1 API call (after 300ms silence)
searchInput.emit('d');
searchInput.emit('da');
searchInput.emit('dar');
searchInput.emit('dart');
// Wait 300ms...
// Only 'dart' is sent to the API
```

---

### 7. Flow.throttle — Rate Limiting

**File:** `throttle_rate_limiting_demo.dart`

**What it does:** Limits the frequency of emissions to a maximum rate.

**When to use:** Scroll events, API rate limiting, click prevention.

```dart
final clicks = Cell.ingress<void>();

final throttled = Flow.throttle<void>(
  clicks.cell,
  duration: Duration(milliseconds: 300),
  leading: true,   // Emit first click immediately
  trailing: false, // Don't emit last click
);

// User clicks 5 times in 100ms
// Only the first and last clicks are emitted
```

**Throttle Modes:**

| leading | trailing | Behavior | Use Case |
|---------|----------|----------|----------|
| true | false | First only, then silent | Click prevention |
| false | true | Last only, after window | Final state only |
| true | true | First + last | Complete handling |
| false | false | Nothing | Testing |

```dart
// Debounce vs Throttle
// Debounce: waits for silence → only final value
// Throttle: limits rate → first value, then periodic

// Search: use debounce (only final query matters)
// Scroll: use throttle (need regular updates)
```

---

### 8. Flow.distinct — Noise Reduction

**File:** `distinct_noise_reduction_demo.dart`

**What it does:** Removes consecutive duplicate values.

**When to use:** Sensor noise reduction, stock tickers, user activity.

```dart
final sensor = Cell.ingress<double>();

final cleanReadings = Flow.distinct<double>(
  sensor.cell,
  equals: (prev, next) => (next - prev).abs() < 0.2, // Custom tolerance
);

// Raw: [10.0, 10.05, 10.1, 10.15, 10.2, 50.0, 50.05, 50.1]
// Output: [10.0, 10.2, 50.0, 50.1]
// (Noise within 0.2 is filtered out)
```

**Distinct vs Other Filters:**

| Operator | Removes | Memory | Use Case |
|----------|---------|--------|----------|
| Distinct | Consecutive duplicates | O(1) | Sensor noise |
| DistinctAll | Any duplicate | O(n) | Unique IDs |
| Filter | By predicate | O(1) | Validation |
| Debounce | By time | O(1) | Search |

---

### 9. Flow.tap — Logging & Analytics

**File:** `tap_logging_analytics_demo.dart`

**What it does:** Injects side effects without modifying the data flow.

**When to use:** Logging, analytics, performance monitoring, debugging.

```dart
final actions = Cell.ingress<String>();

// Tap for logging
final logged = Flow.tap<String>(
  actions.cell,
  onValue: (value) => print('[LOG] $value'),
);

// Tap for analytics
final tracked = Flow.tap<String>(
  logged.cell,
  onValue: (value) => analytics.track(value),
);

// Tap for performance
final timed = Flow.tap<String>(
  tracked.cell,
  onValue: (value) => metrics.record(value),
);

// The original data flows through unchanged
// All three side effects run, but the data is identical
```

**Tap Types:**

| Tap Type | Purpose | Example |
|----------|---------|---------|
| tap | Simple side effect | Logging |
| tapWithIndex | Position tracking | Session tracking |
| tapState | State maintenance | Running totals |
| tapAll | Full pulse access | Debugging |

---

## Level 3: Async & Composition

### 10. Flow.fromFuture — Legacy API Bridge

**File:** `from_future_forensic_pipeline_demo.dart`

**What it does:** Bridges a single Future into the reactive graph.

**When to use:** Loading configuration, user profile, initial data.

```dart
final loadButton = Cell.ingress<void>();

final profile = Flow.fromFuture<UserProfile>(
  loadButton.cell,
  future: api.fetchUserProfile('user_123'),
);

Cell.observe(
  source: profile.cell,
  effect: (pulse) => print('Profile: ${pulse.payload.name}'),
);

loadButton.emit(null); // Triggers the Future
```

**fromFuture vs deferFuture:**

| Feature | fromFuture | deferFuture |
|---------|------------|-------------|
| Trigger | First pulse only | Every pulse |
| Reusability | One-time | Reusable |
| Use Case | Initialization | Per-request |

---

### 11. Flow.fromStream — Real-time Data

**File:** `from_stream_realtime_data_demo.dart`

**What it does:** Bridges a Dart Stream into the reactive graph.

**When to use:** WebSockets, SSE, sensors, file watchers.

```dart
final connect = Cell.ingress<void>();

final wsData = Flow.fromStream<Map<String, dynamic>>(
  connect.cell,
  stream: webSocket.stream,
);

final processed = Flow.map<Map<String, dynamic>, String>(
  wsData.cell,
  project: (data) => data['message'] as String,
);

Cell.observe(
  source: processed.cell,
  effect: (pulse) => print('Message: ${pulse.payload}'),
);

connect.emit(null); // Starts listening
```

**Supported Stream Sources:**
- WebSocket
- Server-Sent Events (SSE)
- Hardware sensors
- File watchers
- Database change streams
- Network sockets

---

### 12. Flow.asyncMap — Parallel Processing

**File:** `async_map_parallel_search_demo.dart`

**What it does:** Maps each value through an async function with configurable concurrency.

**When to use:** API calls, database queries, file I/O.

**Three Strategies:**

```dart
// 1. Sequential (asyncMap) - order matters
final sequential = Flow.asyncMap<int, User>(
  ids.cell,
  mapper: (id) async => await api.getUser(id),
);
// Output: [User1, User2, User3] (in order, one at a time)

// 2. Parallel (asyncMapConcurrent) - throughput matters
final parallel = Flow.asyncMapConcurrent<int, User>(
  ids.cell,
  mapper: (id) async => await api.getUser(id),
);
// Output: [User3, User2, User1] (completion order, all start at once)

// 3. Latest (asyncMapLatest) - only latest matters
final latest = Flow.asyncMapLatest<int, User>(
  ids.cell,
  mapper: (id) async => await api.getUser(id),
);
// Output: [User3] only (previous requests cancelled)
```

**Choosing the Right Strategy:**

| Strategy | Concurrency | Cancels | Order | Use Case |
|----------|-------------|---------|-------|----------|
| asyncMap | 1 (queue) | No | Input | Ordered tasks |
| asyncMapConcurrent | Unlimited | No | Completion | Parallel fetches |
| asyncMapLatest | 1 (latest) | Yes (stale) | Latest | Search-as-you-type |

---

### 13. Flow.switchMap — Dynamic Sources

**File:** `switch_map_dynamic_dependency_demo.dart`

**What it does:** Switches to a new data source on each pulse, cancelling the previous one.

**When to use:** Feature flags, user selection, A/B testing, multi-tenant.

```dart
final selector = Cell.ingress<String>();

final data = Flow.switchMap<String, String>(
  selector.cell,
  project: (source) {
    switch (source) {
      case 'api-v1': return apiV1.stream();
      case 'api-v2': return apiV2.stream();
      default: return fallback.stream();
    }
  },
);

// Select v1 → starts streaming from v1
selector.emit('api-v1');

// Select v2 → v1 is automatically cancelled, v2 starts
selector.emit('api-v2');
```

**Use Cases:**

| Use Case | Pattern |
|----------|---------|
| Feature flags | Switch between implementations |
| User context | Switch between user profiles |
| A/B testing | Switch between experiment variants |
| Multi-tenant | Switch between tenant data sources |
| Theme switching | Switch between theme providers |

---

### 14. Flow.mergeWith — Stream Merging

**File:** `merge_stream_aggregation_demo.dart`

**What it does:** Merges multiple streams into one, interleaving events.

**When to use:** Combining events from multiple sources.

**Two Approaches:**

```dart
// 1. Flow.mergeWith (built-in)
final merged = Flow.mergeWith<String>(
  sourceA.cell,
  others: [sourceB.cell, sourceC.cell],
);

// 2. Fan-in Pattern (more control)
final bus = Cell.ingress<String>();
_fanIn<String>([sourceA.cell, sourceB.cell, sourceC.cell], bus);
```

**Fan-in vs mergeWith:**

| Feature | mergeWith | Fan-in |
|---------|-----------|--------|
| Event delivery | May drop | Reliable |
| Source tracking | Loses | Preserves |
| Flexibility | Fixed | Customizable |

---

## Level 4: Complex Orchestration

### 15. Flow.buffer — Batch Processing

**File:** `buffer_batch_processing_demo.dart`

**What it does:** Collects events into batches and emits them as lists.

**When to use:** Log batching, database bulk operations, analytics aggregation.

```dart
final events = Cell.ingress<LogEntry>();

// 1. Buffer by count
final countBatch = Flow.bufferCount<LogEntry>(
  events.cell,
  size: 100, // Emit when 100 logs collected
);

// 2. Buffer by time
final timeBatch = Flow.bufferTime<LogEntry>(
  events.cell,
  duration: Duration(seconds: 5), // Emit every 5 seconds
);

// 3. Buffer by count OR time
final comboBatch = Flow.bufferWithTimeAndCount<LogEntry>(
  events.cell,
  duration: Duration(seconds: 5),
  count: 100, // Whichever comes first
);

// 4. Buffer when condition met
final predBatch = Flow.bufferWithPredicate<LogEntry>(
  events.cell,
  test: (log) => log.level == 'ERROR', // Flush on error
);

// 5. Buffer on external trigger
final trigger = Cell.ingress<void>();
final whenBatch = Flow.bufferWhen<LogEntry>(
  events.cell,
  closer: trigger.cell, // Flush when trigger emits
);
```

**Buffer Strategy Comparison:**

| Strategy | Trigger | Memory | Latency | Use Case |
|----------|---------|--------|---------|----------|
| BufferCount | Size | Fixed | Low | Fixed-size batches |
| BufferTime | Time | Variable | High | Time-based batches |
| BufferWithTimeAndCount | Size OR time | Fixed | Low | Either condition |
| BufferWithPredicate | Condition | Variable | Low | Conditional batching |
| BufferWhen | External | Variable | Manual | Manual batching |

---

### 16. Flow.retry — Fault Tolerance

**File:** `retry_timeout_flaky_network_demo.dart`

**What it does:** Retries failed operations with bounded attempts.

**When to use:** Network calls, database operations, external APIs.

```dart
final request = Cell.ingress<String>();

final result = Flow.retry<String, UserProfile>(
  request.cell,
  task: (id) async => await api.getUser(id),
  count: 3, // Retry up to 3 times
  onError: (error, stack) => print('Error: $error'),
);

// If the first attempt fails, it retries automatically
// If all 3 attempts fail, an error pulse is emitted
```

**Retry Patterns:**

```dart
// 1. Simple retry
Retry(task, count: 3)

// 2. Retry with fallback
AsyncMapWithFallback(mapper, fallback: defaultValue)

// 3. Retry with timeout
Timeout(duration) + Retry(task, count: 3)

// 4. Exponential backoff (custom)
Retry(task, count: 3) + custom delay logic
```

---

### 17. Flow.timeout — Deadlines

**File:** `retry_timeout_flaky_network_demo.dart`

**What it does:** Enforces a deadline on async operations.

**When to use:** Time-sensitive operations, user experience, SLA enforcement.

```dart
final request = Cell.ingress<String>();

// Operation with timeout
final slowOp = AsyncMap<String, String>(
  (id) async {
    await Future.delayed(Duration(seconds: 5));
    return 'Result';
  },
).toHandle(source: request.cell);

// Enforce 2 second deadline
final timedOut = Timeout<String>(
  Duration(seconds: 2),
  onError: (error, stack) => print('Operation timed out!'),
  emitErrorPulse: true,
).toHandle(source: slowOp.cell);

// Users see "Operation timed out" after 2 seconds
```

**Timeout Strategies:**

| Strategy | Behavior | Use Case |
|----------|----------|----------|
| Timeout | Throw on timeout | Critical operations |
| TimeoutWithFallback | Use fallback on timeout | Graceful degradation |
| Timeout with Retry | Retry then timeout | Network calls |
| Deadline with Loading | Show progress then timeout | User feedback |

---

### 18. Flow.combineLatest — Real-time Sync

**File:** `combine_latest_sync_demo.dart`

**What it does:** Combines the latest values from multiple sources, emitting on any change.

**When to use:** Dashboards, form validation, portfolio aggregation.

```dart
final users = Cell.ingress<int>();
final requests = Cell.ingress<double>();
final errors = Cell.ingress<double>();

final dashboard = Flow.combineLatestWith<int, Map<String, dynamic>>(
  users.cell,
  others: [requests.cell, errors.cell],
  combine: (userCount, latest) => {
    'users': userCount,
    'requests': latest[0] as double,
    'errors': latest[1] as double,
    'timestamp': DateTime.now(),
  },
);

// All sources must have at least one value before first emission
// After that, any source change triggers a new emission
```

**combineLatest vs Other Operators:**

| Operator | Emits When | Use Case |
|----------|------------|----------|
| combineLatestWith | ANY source changes | Real-time dashboards |
| withLatestFrom | Source changes only | Commands with state |
| zipWith | ALL sources have next value | Paired data |
| mergeWith | ANY source emits | Event interleaving |

---

### 19. Flow.exhaustMap — Submit Protection

**File:** `exhaust_map_submit_checkout_demo.dart`

**What it does:** Ignores new triggers while an operation is in flight.

**When to use:** Submit buttons, checkout, refresh, file uploads.

```dart
final submit = Cell.ingress<Order>();

final orderResult = Flow.exhaustMap<Order, String>(
  submit.cell,
  project: (order) async {
    await processOrder(order);
    return 'Order ${order.id} confirmed!';
  },
);

// User clicks submit 5 times rapidly
// Only the first click is processed
// Clicks 2-5 are ignored while busy
```

**exhaustMap vs Other Operators:**

| Operator | Behavior | Use Case |
|----------|----------|----------|
| exhaustMap | First wins, ignore rest | Submit, checkout |
| debounce | Last wins after silence | Search |
| throttle | First wins, then rate-limit | Scroll |
| switchMap | Latest wins, cancel previous | Search-as-you-type |
| concatMap | Queue all, process sequentially | Ordered processing |

---

## Level 5: Real-World Applications

### 20. Pharmacy Dispense — Transactions

**File:** `domain-cells-txApply(enhanced)-Demo.dart`

**What it demonstrates:** How Cell, Flow, and Transactions combine for a real pharmacy system.

**Key Components:**

1. **Ingress Layer** - TestCell validation on NDC codes
2. **Flow Layer** - MapValue + Filter + Take(1) gate
3. **Transaction Layer** - Repeatable-read isolation on stock
4. **Compensation** - Restore pack on hardware failure

**Architecture:**

```
Technician Scan
      │
      ▼
[Cell] gun.ingress + TestCell(ndcLike)
      │
      ▼
[Flow] MapValue(trim/upper) + Filter(NDC) + Take(1)
      │
      ▼
[Cell] rx.cell
      │  Cell.observe
      ▼
fullDispense()
      │
      ├─ [Tx] confirmPatient → patient cell
      ├─ [Tx] dispenseMemory → stock + label (repeatable-read)
      ├─ [Hardware] openDrawer → drawer cell
      ├─ [Hardware] printLabel → I/O
      └─ [Tx] restorePack → compensation on failure
```

**Key Lessons:**

1. Flow stops pulses. Transaction moves state.
2. One Receptor per gun. Reset Take; do not stack `toHandle`.
3. Repeatable-read on shelf Cells, not on gun.
4. Hardware after commit → new Tx to compensate.
5. TestCell on every ingress that a human or device can emit.
6. Do not put `tx.begin` in `MapValue + Filter`.

---

### 21. ICU Alarm — Medical Monitoring

**File:** `ICU-alarm-pipeline(enhanced)-Demo.dart`

**What it demonstrates:** Real-time medical monitoring with alarm fatigue prevention.

**Key Components:**

1. **Sensors** - HR, SpO2, Motion with TestCell ranges
2. **Clinical Logic** - Severity mapping (page/warn/none)
3. **Duplicate Prevention** - Distinct with ACK reset
4. **Paging** - AsyncMapWithRetry for nurse notification

**Architecture:**

```
hrIn (TestCell 20-250) ─┐
spo2In (TestCell 0-100) ─┼─ publishVitals → Reading
motionIn ─────────────────┘
                              │
                              ▼
                         vitalsIn
                    ┌─────────┴─────────┐
                    ▼                   ▼
              page gate            warn gate
         MapValue + Distinct     MapValue + Distinct
         + Filter(page)          + Filter(warn)
                    │                   │
                    ▼                   ▼
              pageHandle            warnHandle
                    │
                    ├─ observe → ledger PAGE
                    └─ AsyncMapWithRetry → pager
ackIn ─────────────────────────────────► resetDistinct()
```

**Key Lessons:**

1. TestCell on sensor ingress, not on state
2. Distinct before Filter (otherwise `none` never arrives)
3. ACK resets Distinct on the same Receptor (not a new handle)
4. AsyncMapWithRetry for I/O (not inside the policy chain)
5. Motion → none (artifact wins)

---

### 22. Forensic Pipeline — Audit & Compliance

**File:** `from_future_forensic_pipeline_demo.dart`

**What it demonstrates:** Bridging legacy async APIs with full provenance tracking.

**Key Components:**

1. **Legacy API Bridge** - deferFuture for per-request async
2. **Chain of Custody** - Sequential Future steps
3. **Provenance** - pulse.withStep() for forensic trace
4. **Error Handling** - Forensic error tracking
5. **Audit Trail** - Complete chain of custody

**Architecture:**

```
Legacy API (Future-based)
      │
      ▼
deferFuture → fetchEvidence()
      │
      ▼
deferFuture → fetchImages()
      │
      ▼
deferFuture → fetchAuditLog()
      │
      ▼
synthesis → Combined Report
      │
      ▼
Observer → Audit Trail
```

**Key Lessons:**

1. Use deferFuture for per-input async operations.
2. Use fromFuture for one-shot async operations.
3. Use asyncMapConcurrent for parallel operations.
4. Chain deferFuture for sequential operations.
5. Use synthesis to combine multiple sources.
6. Handle errors in onError callback with forensic context.
7. Preserve provenance with pulse.withStep().

---

### 23. Data Quality — Monitoring & Validation

**File:** `filter_data_quality_demo.dart`

**What it demonstrates:** Real-time data quality monitoring and filtering.

**Key Components:**

1. **Numeric Filtering** - Range validation
2. **String Validation** - Non-empty, pattern matching
3. **Complex Objects** - User validation, business rules
4. **Sensor Data** - Quality control, anomaly detection
5. **Multi-Condition** - Pipeline filtering
6. **Log Filtering** - Level-based filtering

**Architecture:**

```
Data Sources
      │
      ▼
Flow.filter (Basic Validation)
      │
      ▼
Flow.filter (Business Rules)
      │
      ▼
Flow.map (Transformation)
      │
      ▼
Flow.filter (Post-Validation)
      │
      ▼
Observer → Results
```

**Key Lessons:**

1. Use filter to remove invalid data from streams.
2. Chain multiple filters for complex validation.
3. Combine with map for filter-transform pipelines.
4. Real-time filtering with fromStream.
5. Great for: Data quality, monitoring, validation.

---

## Operator Reference

### Creation Operators

| Operator | Purpose | Use Case |
|----------|---------|----------|
| `Cell.state` | Create state cell | Persistent state |
| `Cell.ingress` | Create input gateway | External events |
| `Flow.of` | Emit fixed sequence | Initial values |
| `Flow.fromIterable` | Emit from iterable | Static sequences |
| `Flow.range` | Emit numeric range | Counters, IDs |
| `Flow.repeat` | Emit repeated value | Heartbeats, signals |
| `Flow.fromFuture` | Bridge single Future | One-time loads |
| `Flow.deferFuture` | Bridge Future per input | Per-request loads |
| `Flow.fromStream` | Bridge Stream | Real-time data |
| `Flow.deferStream` | Bridge Stream per input | Dynamic streams |

### Transformation Operators

| Operator | Purpose | Use Case |
|----------|---------|----------|
| `Flow.map` | Transform each value | Data formatting |
| `Flow.mapTo` | Map to constant value | Signal conversion |
| `Flow.mapWithIndex` | Indexed transformation | Position tracking |
| `Flow.mapNotNull` | Drop null results | Optional values |
| `Flow.mapWhen` | Conditional mapping | Filter + transform |
| `Flow.mapValues` | Transform map values | Map transformation |
| `Flow.mapKeys` | Transform map keys | Key transformation |
| `Flow.pluck` | Extract field | Data extraction |
| `Flow.pluckOr` | Extract with default | Optional fields |
| `Flow.pluckAll` | Extract multiple fields | Data projection |
| `Flow.pluckPath` | Extract nested field | Deep navigation |

### Async Operators

| Operator | Purpose | Use Case |
|----------|---------|----------|
| `Flow.asyncMap` | Sequential async | Ordered tasks |
| `Flow.asyncMapConcurrent` | Parallel async | Throughput |
| `Flow.asyncMapLatest` | Latest only | Search-as-you-type |
| `Flow.asyncMapWithIndex` | Indexed async | Position tracking |
| `Flow.asyncMapWithRetry` | Retry on failure | Transient failures |
| `Flow.asyncMapWithTimeout` | Time-bound async | Deadlines |
| `Flow.asyncMapWithFallback` | Fallback on error | Graceful degradation |
| `Flow.asyncExpand` | Sequential flatten | Ordered sequences |
| `Flow.asyncExpandConcurrent` | Parallel flatten | Throughput |
| `Flow.asyncExpandLatest` | Latest flatten | Search |
| `Flow.asyncExpandExhaust` | Exhaust flatten | Submit protection |
| `Flow.asyncFold` | Seeded accumulation | Running totals |
| `Flow.asyncReduce` | Seedless accumulation | First value as seed |

### Filter Operators

| Operator | Purpose | Use Case |
|----------|---------|----------|
| `Flow.filter` | Remove by predicate | Validation |
| `Flow.take` | Take first N values | Sampling |
| `Flow.takeWhile` | Take while condition true | Conditional sampling |
| `Flow.takeUntil` | Take until event | Event-based stopping |
| `Flow.skip` | Skip first N values | Headers, warm-up |
| `Flow.skipWhile` | Skip while condition true | Conditional skipping |
| `Flow.skipUntil` | Skip until event | Event-based starting |
| `Flow.skipRepeated` | Skip consecutive duplicates | Noise reduction |
| `Flow.distinct` | Global deduplication | Unique items |

### Flatten Operators

| Operator | Purpose | Use Case |
|----------|---------|----------|
| `Flow.concatMap` | Sequential flatten | Ordered sequences |
| `Flow.concat` | Concatenate fixed inners | Static sequences |
| `Flow.concatAll` | Concatenate dynamic inners | Stream of streams |
| `Flow.mergeMap` | Concurrent flatten | Parallel processing |
| `Flow.switchMap` | Latest flatten | Dynamic sources |
| `Flow.exhaustMap` | Exhaust flatten | Submit protection |

### Combine Operators

| Operator | Purpose | Use Case |
|----------|---------|----------|
| `Flow.mergeWith` | Merge multiple sources | Event interleaving |
| `Flow.merge` | Merge with arming | Triggered merging |
| `Flow.mergeAll` | Flatten inner sequences | Stream of streams |
| `Flow.zipWith` | Pair by index | Synchronization |
| `Flow.zip` | Zip with arming | Triggered zipping |
| `Flow.zipAll` | Batch by count | Chunking |
| `Flow.combineLatestWith` | Latest from all sources | Real-time dashboards |
| `Flow.withLatestFrom` | Source-driven combination | Commands with state |
| `Flow.race` | First wins | Fastest response |

### Time Operators

| Operator | Purpose | Use Case |
|----------|---------|----------|
| `Flow.delay` | Fixed delay | Timing control |
| `Flow.delayWithSelector` | Payload-dependent delay | Adaptive timing |
| `Flow.delayWhen` | Notifier-based delay | External timing |
| `Flow.delayLatest` | Trailing delay | Latest after silence |
| `Flow.debounce` | Silence-based emission | Search, auto-save |
| `Flow.throttle` | Rate limiting | Scroll, clicks |
| `Flow.sample` | Sample on notifier | Event sampling |
| `Flow.sampleTime` | Time-based sampling | Periodic sampling |
| `Flow.audit` | Audit on notifier | Confirmation |
| `Flow.auditTime` | Time-based audit | Stabilization |
| `Flow.timeout` | Idle timeout | Inactivity detection |
| `Flow.timeoutWithFallback` | Timeout with