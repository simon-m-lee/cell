# The "Core 16" Essential Cell Operators

## A Practical Guide for First-Time Developers

---

## Table of Contents

1. [Introduction](#introduction)
2. [Learning Path](#learning-path)
3. [Phase 1: Get Data In](#phase-1-get-data-in)
4. [Phase 2: Hold State](#phase-2-hold-state)
5. [Phase 3: React in UI](#phase-3-react-in-ui)
6. [Phase 4: Shape Streams](#phase-4-shape-streams)
7. [Phase 5: Go Async](#phase-5-go-async)
8. [Phase 6: Combine Sources](#phase-6-combine-sources)
9. [Quick Reference Card](#quick-reference-card)
10. [Common Patterns](#common-patterns)
11. [Next Steps](#next-steps)

---

## Introduction

The Cell Framework provides **16 essential operators** that cover most of your daily reactive programming needs. They are carefully ordered to guide you through a natural learning path:

```
get data in → hold state → react in the UI → shape streams → go async → combine sources
```

Each operator works with zero knowledge of the underlying framework mechanics (Receptor, TestCell, Context, Synapses) — all optional, all defaulted. They represent the **Standard Entry Point** for building reactive systems.

---

## Learning Path

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           CORE 16 OPERATORS                                        │
│                         Ordered for Learning Path                                  │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                │
│  │   GET DATA IN   │    │   HOLD STATE    │    │  REACT IN UI    │                │
│  │                 │    │                 │    │                 │                │
│  │ 1. state        │───▶│ 2. ingress      │───▶│ 3. observe      │                │
│  │ 4. open         │    │                 │    │                 │                │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                │
│         │                       │                       │                         │
│         ▼                       ▼                       ▼                         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                │
│  │  SHAPE STREAMS  │    │   GO ASYNC      │    │ COMBINE SOURCES│                │
│  │                 │    │                 │    │                 │                │
│  │ 7. debounce     │    │ 9. asyncMap     │    │ 12. synthesis   │                │
│  │ 8. distinct     │    │ 10. fromFuture  │    │ 15. switchMap   │                │
│  │                 │    │ 11. fromStream  │    │ 16. transaction │                │
│  │                 │    │                 │    │                 │                │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Get Data In

### 1. `Cell.ingress` — How intent/events enter the graph

**Purpose:** Create a manual entry point for external events (UI clicks, network messages, hardware sensors).

**When to use:**
- User interactions (button clicks, form submissions)
- External events (WebSocket messages, sensor readings)
- Testing and simulation

**How it works:**
1. Creates a cell that accepts raw data
2. Wraps data in a Pulse automatically
3. Broadcasts to all observers

**Basic Usage:**
```dart
// Create an ingress for string events
final events = Cell.ingress<String>();

// Emit events
events.emit('click');
events.emit('submit');

// Observe events
Cell.observe(
  source: events.cell,
  effect: (pulse) => print('Event: ${pulse.payload}'),
);
```

**With Refinement:**
```dart
final events = Cell.ingress<String>(
  refine: (host, input) {
    // Transform or filter incoming events
    if (input.payload.isEmpty) return null;
    return Pulse(input.payload.toUpperCase());
  },
);

events.emit('hello');  // Observers receive "HELLO"
events.emit('');       // Filtered out (null)
```

**Advanced Usage:**
```dart
final events = Cell.ingress<Map<String, dynamic>>(
  refine: (host, input) {
    final data = input.payload;
    if (!data.containsKey('type')) return null;
    return Pulse(data, type: data['type'] as String?);
  },
  context: Context.module('event-processor'),
  testRule: TestCell.allowAll,
);

// Emit with type
events.emit({'type': 'user.login', 'user': 'alice'});
// Observers receive a Pulse with type 'user.login'
```

---

### 2. `Cell.state` — Retained app state you read and update

**Purpose:** Create a persistent, mutable state atom that maintains its value across reactive cycles.

**When to use:**
- Application state (counter, settings, user profile)
- UI state (form inputs, toggle states)
- Domain models (entities from database)

**How it works:**
1. Initialized with a starting value
2. Updates are processed through `evolve` function
3. Changes are validated and committed atomically
4. Observers are notified

**Basic Usage:**
```dart
final counter = Cell.state<int>(
  initial: 0,
  evolve: (host, input) {
    final delta = input.payload as int? ?? 1;
    return Pulse(host.value + delta);
  },
);

// Update
counter.update(1);   // value becomes 1
counter.update(5);   // value becomes 6

// Read
print(counter.cell.value); // 6
```

**With Validation:**
```dart
final isPositive = TestCell<int>((value, {host, ...}) => value > 0);

final counter = Cell.state<int>(
  initial: 0,
  evolve: (host, input) {
    final delta = input.payload as int? ?? 1;
    return Pulse(host.value + delta);
  },
  testRule: isPositive,
);

counter.update(5);   // ✓ Allowed
counter.update(-1);  // ✗ Blocked (value stays 5)
```

**Complex State:**
```dart
class User {
  final String name;
  final int age;
  User(this.name, this.age);
}

final user = Cell.state<User>(
  initial: User('Alice', 25),
  evolve: (host, input) {
    final updates = input.payload as Map<String, dynamic>?;
    if (updates == null) return null;
    
    final current = host.value;
    final newUser = User(
      updates['name'] as String? ?? current.name,
      updates['age'] as int? ?? current.age,
    );
    return Pulse(newUser);
  },
);

user.update({'name': 'Bob'});     // Name changes to Bob
user.update({'age': 30});         // Age changes to 30
user.update({'name': 'Charlie', 'age': 35}); // Both change
```

---

## Phase 2: Hold State

### 4. `Cell.derive` — Pure view-models / projections from state

**Purpose:** Create a derived value that transforms one source into another.

**When to use:**
- View models from state
- Data transformations
- Formatting and sanitization

**How it works:**
1. Listens to a source cell
2. Applies a pure transformation
3. Emits the transformed result
4. Preserves causal provenance

**Basic Usage:**
```dart
final counter = Cell.state<int>(
  initial: 0,
  evolve: (host, input) {
    final delta = input.payload as int? ?? 1;
    return Pulse(host.value + delta);
  },
);

// Derive a display string
final display = Cell.derive<int, String>(
  source: counter.cell,
  project: (pulse) => Pulse('Count: ${pulse.payload}'),
);

print(display.value); // "Count: 0"
```

**With Type Conversion:**
```dart
// Convert User object to display name
final user = Cell.state<User>(
  initial: User('Alice', 25),
  evolve: (host, input) => Pulse(input.payload as User),
);

final displayName = Cell.derive<User, String>(
  source: user.cell,
  project: (pulse) => Pulse('${pulse.payload.name} (${pulse.payload.age})'),
);
```

**Filtering with Derive:**
```dart
// Only emit when the value is positive
final positiveOnly = Cell.derive<int, int>(
  source: source.cell,
  project: (pulse) {
    final value = pulse.payload;
    return value > 0 ? Pulse(value) : null;  // Filter out non-positive
  },
);
```

---

### 13. `Cell.sanitized` — Data sanitization / validation

**Purpose:** Automatically modify Pulse payloads based on sensitivity and compliance rules.

**When to use:**
- PII masking (email, phone, SSN)
- Credential stripping (API keys, tokens)
- Compliance enforcement (GDPR, HIPAA)

**How it works:**
1. Inspects sensitivity level of incoming pulses
2. Applies redaction logic when threshold is met
3. Propagates cleansed pulses downstream

**Basic Usage:**
```dart
final safeView = Cell.sanitized<UserPulse>(
  source: internalStore.cell,
  redact: (pulse) => Pulse(
    pulse.payload.copyWith(
      email: maskEmail(pulse.payload.email),
      phone: maskPhone(pulse.payload.phone),
    ),
  ),
  minSensitivity: Sensitivity.confidential,
);
```

**Email Masking Example:**
```dart
String maskEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2) return email;
  final local = parts[0];
  final domain = parts[1];
  if (local.length <= 2) return '***@$domain';
  return '${local[0]}***${local[local.length - 1]}@$domain';
}

final userView = Cell.sanitized<UserPulse>(
  source: internalUserStore,
  redact: (pulse) => Pulse(
    pulse.payload.copyWith(email: maskEmail(pulse.payload.email)),
  ),
  minSensitivity: Sensitivity.confidential,
);
```

---

## Phase 3: React in UI

### 3. `Cell.observe` — Side effects: UI, logging, wiring widgets

**Purpose:** Create a terminal observer that reacts to changes with side effects.

**When to use:**
- UI updates (setState, rebuild)
- Logging and monitoring
- Persistence (saving to database)
- External API calls

**How it works:**
1. Establishes a persistent link to a source
2. Executes `effect` callback on each valid pulse
3. Terminal node (no downstream propagation)
4. Start/stop lifecycle control

**Basic Usage:**
```dart
final observer = Cell.observe<int>(
  source: counter.cell,
  effect: (pulse) {
    print('Counter changed to: ${pulse.payload}');
    setState(() {});
  },
);

// Control lifecycle
observer.stop();   // Pause
observer.start();  // Resume
```

**With Filtering:**
```dart
// Only observe positive changes
final observer = Cell.observe<int>(
  source: counter.cell,
  effect: (pulse) {
    if (pulse.payload > 0) {
      updateUI(pulse.payload);
    }
  },
  testRule: TestCell((value, {host, ...}) => value > 0),
);
```

**UI Integration Example:**
```dart
class CounterWidget extends StatefulWidget {
  @override
  _CounterWidgetState createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<CounterWidget> {
  late ValueCell<int> counter;
  late EgressHandle observer;

  @override
  void initState() {
    super.initState();
    
    final state = Cell.state<int>(
      initial: 0,
      evolve: (host, input) {
        final delta = input.payload as int? ?? 1;
        return Pulse(host.value + delta);
      },
    );
    
    counter = state.cell;
    
    observer = Cell.observe<int>(
      source: counter,
      effect: (pulse) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text('Count: ${counter.value}');
  }

  @override
  void dispose() {
    observer.stop();
    super.dispose();
  }
}
```

---

## Phase 4: Shape Streams

### 7. `Cell.debounce` — Everyday input: search, validation, autosave

**Purpose:** Wait for a period of stability before emitting the latest value.

**When to use:**
- Search-as-you-type
- Form validation
- Autosave
- Window resize

**How it works:**
1. Each new pulse resets a timer
2. Only emits when silence period passes
3. Leading edge option for immediate first response

**Basic Usage:**
```dart
final searchInput = Cell.ingress<String>();

final debouncedSearch = Cell.debounce(
  searchInput.cell,
  Duration(milliseconds: 300),
);

// Only emits after user stops typing for 300ms
Cell.observe(
  source: debouncedSearch,
  effect: (pulse) => performSearch(pulse.payload),
);
```

**With Leading Edge:**
```dart
final debouncedSearch = Cell.debounce(
  searchInput.cell,
  Duration(milliseconds: 300),
  leading: true,  // First pulse emits immediately
);

// Emits: first character immediately, then after silence
```

**Real-World Example:**
```dart
class SearchWidget extends StatefulWidget {
  @override
  _SearchWidgetState createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final searchInput = Cell.ingress<String>();
  late Cell debounced;
  late EgressHandle observer;

  @override
  void initState() {
    super.initState();
    
    debounced = Cell.debounce(
      searchInput.cell,
      Duration(milliseconds: 300),
    );
    
    observer = Cell.observe(
      source: debounced,
      effect: (pulse) => performSearch(pulse.payload),
    );
  }

  void onSearchChanged(String query) {
    searchInput.emit(query);
  }
}
```

---

### 8. `Cell.throttle` — Frequency-based rate limiting

**Purpose:** Limit the frequency of updates to a predictable, constant rate.

**When to use:**
- UI performance (scroll, mouse-move)
- API rate limiting
- Sensor data sampling

**How it works:**
1. Leading edge: first pulse emits immediately
2. Silent window: subsequent pulses are suppressed
3. Trailing edge: last pulse emits when window ends

**Basic Usage:**
```dart
final throttled = Cell.throttle(
  source.cell,
  Duration(milliseconds: 100),  // At most one per 100ms
  leading: true,   // First pulse immediate
  trailing: false, // No trailing emission
);

// Use case: scroll events
final scroll = Cell.ingress<int>();
final throttledScroll = Cell.throttle(
  scroll.cell,
  Duration(milliseconds: 16),  // ~60fps
);
```

**With Trailing:**
```dart
final throttled = Cell.throttle(
  source.cell,
  Duration(milliseconds: 200),
  leading: true,   // First immediate
  trailing: true,  // Last at end of window
);
// Pattern: First → (silence) → Last
```

**Throttle vs Debounce:**
```dart
// Throttle: "At most one per N ms"
final throttled = Cell.throttle(source, Duration(milliseconds: 300));

// Debounce: "Wait for N ms of silence"
final debounced = Cell.debounce(source, Duration(milliseconds: 300));

// Throttle is better for: scroll events, mouse movement
// Debounce is better for: search input, form validation
```

---

### 9. `Cell.distinct` — Skip redundant updates and rebuilds

**Purpose:** Suppress consecutive duplicate payloads.

**When to use:**
- Prevent unnecessary UI rebuilds
- Reduce network requests
- Filter sensor noise

**How it works:**
1. Compares current payload with previous
2. Skips if equal (using `==` or custom comparator)
3. First emission always passes

**Basic Usage:**
```dart
final unique = Cell.distinct(
  source: source.cell,
  equals: (a, b) => a == b,  // Optional custom equality
);

// Sequence: 1, 1, 2, 2, 3, 1
// Emits:    1,    2,    3, 1
```

**Custom Equality:**
```dart
final unique = Cell.distinct(
  source: source.cell,
  equals: (a, b) {
    // Case-insensitive comparison
    if (a is String && b is String) {
      return a.toLowerCase() == b.toLowerCase();
    }
    return a == b;
  },
);
```

---

## Phase 5: Go Async

### 9. `Cell.asyncMap` — HTTP/DB work (latestOnly / exhaust)

**Purpose:** Run background tasks for each input, with configurable concurrency control.

**When to use:**
- API requests
- Database queries
- Heavy computations
- Data enrichment

**How it works:**
1. Maps each input to an async task
2. Controls concurrency (parallel, sequential, throttled)
3. Emits results as they complete

**Concurrency Modes:**
```dart
// Parallel (default) - unlimited concurrency
final parallel = Cell.asyncMap<int, User>(
  source,
  (id) => api.fetchUser(id),
  concurrency: 0,  // Unlimited
);

// Sequential - one at a time
final sequential = Cell.asyncMap<int, User>(
  source,
  (id) => api.fetchUser(id),
  concurrency: 1,  // One at a time
);

// Limited - at most 3 concurrent
final limited = Cell.asyncMap<int, User>(
  source,
  (id) => api.fetchUser(id),
  concurrency: 3,
);
```

**SwitchMap (latest only):**
```dart
// Only care about the most recent result
final latest = Cell.asyncMap<int, User>(
  source,
  (id) => api.fetchUser(id),
  latestOnly: true,
);
// If new request starts before old completes, old result is dropped
```

**ExhaustMap (ignore while busy):**
```dart
// Ignore new inputs while processing
final exhaust = Cell.asyncMap<int, User>(
  source,
  (id) => api.fetchUser(id),
  exhaust: true,
);
// If busy, new inputs are ignored
```

**Real-World Example:**
```dart
final userId = Cell.ingress<int>();

// Only care about the most recently selected user
final userProfile = Cell.asyncMap<int, UserProfile>(
  userId.cell,
  (id) => api.fetchProfile(id),
  latestOnly: true,
);

Cell.observe(
  source: userProfile,
  effect: (pulse) => displayUser(pulse.payload),
);

userId.emit(1);  // Fetches user 1
userId.emit(2);  // Cancels user 1, fetches user 2
```

---

### 10. `Cell.fromFuture` — Bridge Futures and Streams into Cell

**Purpose:** Bridge a single asynchronous result into the reactive graph.

**When to use:**
- Loading initial configuration
- One-time data fetch
- Initialization tasks

**Basic Usage:**
```dart
final config = Cell.fromFuture(loadConfig());

Cell.observe(
  source: config,
  effect: (pulse) => applyConfig(pulse.payload),
);
```

**With Error Handling:**
```dart
Future<String> loadData() async {
  try {
    final response = await http.get(url);
    return response.body;
  } catch (e) {
    return 'Error: $e';
  }
}

final data = Cell.fromFuture(loadData());
```

---

### 11. `Cell.fromStream` — Bridge continuous streams

**Purpose:** Bridge a continuous Stream into the reactive graph.

**When to use:**
- WebSockets
- File watchers
- Timers and periodic events
- Hardware sensors

**Basic Usage:**
```dart
final ticks = Cell.fromStream(
  Stream.periodic(Duration(seconds: 1), (i) => i),
);

Cell.observe(
  source: ticks,
  effect: (pulse) => print('Tick: ${pulse.payload}'),
);
```

**With WebSocket:**
```dart
final ws = WebSocket.connect('wss://example.com');
final messages = Cell.fromStream(ws.asBroadcastStream());

Cell.observe(
  source: messages,
  effect: (pulse) => handleMessage(pulse.payload),
);
```

---

## Phase 6: Combine Sources

### 12. `Cell.synthesis` — Forms & dashboards: latest of several fields

**Purpose:** Merge multiple source cells into one, reacting when any source changes.

**When to use:**
- Form validation (combining multiple fields)
- Dashboards (multiple data sources)
- Calculations (price + tax + shipping)

**How it works:**
1. Links to all source cells
2. Reacts when any source changes
3. Aggregator receives all sources and the triggering pulse
4. Emits a new aggregated result

**Basic Usage:**
```dart
final total = Cell.synthesis<double>(
  [price.cell, tax.cell, shipping.cell],
  aggregator: (sources, pulse) {
    final p = sources.elementAt(0).value as double? ?? 0;
    final t = sources.elementAt(1).value as double? ?? 0;
    final s = sources.elementAt(2).value as double? ?? 0;
    return Pulse(p + t + s);
  },
);
```

**Form Validation Example:**
```dart
final email = Cell.state<String>(
  initial: '',
  evolve: (host, input) => Pulse(input.payload as String? ?? ''),
);

final password = Cell.state<String>(
  initial: '',
  evolve: (host, input) => Pulse(input.payload as String? ?? ''),
);

final formValid = Cell.synthesis<bool>(
  [email.cell, password.cell],
  aggregator: (sources, pulse) {
    final email = sources.elementAt(0).value as String? ?? '';
    final password = sources.elementAt(1).value as String? ?? '';
    final valid = email.contains('@') && password.length >= 8;
    return Pulse(valid);
  },
);

Cell.observe(
  source: formValid,
  effect: (pulse) {
    submitButton.enabled = pulse.payload;
  },
);
```

---

### 15. `Cell.switchMap` — Dynamic source switching

**Purpose:** Switch to a new reactive source dynamically based on a selection.

**When to use:**
- Tab switching
- User selection
- Language/locale changes
- Module activation

**How it works:**
1. Listens to a source cell (the selector)
2. Each new value triggers a mapper that returns a new cell
3. Automatically unlinks old source, links new one
4. Forwards pulses from the active source

**Basic Usage:**
```dart
final profile = Cell.switchMap<int, Profile>(
  selectedId.cell,
  (id) => getProfileCellFor(id),
);
// When selectedId changes, profile switches to a new source
```

**Real-World Example:**
```dart
// Tab navigation
final selectedTab = Cell.state<String>(
  initial: 'home',
  evolve: (host, input) => Pulse(input.payload as String? ?? 'home'),
);

final tabContent = Cell.switchMap<String, Widget>(
  selectedTab.cell,
  (tab) {
    switch (tab) {
      case 'home': return homeTab.cell;
      case 'settings': return settingsTab.cell;
      case 'profile': return profileTab.cell;
      default: return emptyTab.cell;
    }
  },
);
```

---

### 16. `Cell.transaction` — Multi-cell atomic updates

**Purpose:** Group multiple cell updates into a single atomic unit.

**When to use:**
- Financial transfers
- Inventory adjustments
- Complex form submissions
- Any operation with invariants across cells

**How it works:**
1. Begin: Register participants
2. Update: Buffer writes (not applied yet)
3. Read: Observe values according to isolation level
4. Commit: Acquire locks, validate, apply atomically
5. Rollback: Discard buffered changes

**Basic Usage:**
```dart
final tx = Cell.transaction();
await tx.begin([accountA, accountB]);

final fromBalance = tx.read(accountA) as int;
final toBalance = tx.read(accountB) as int;

tx.update(accountA, fromBalance - 50);
tx.update(accountB, toBalance + 50);

await tx.commit();  // All or nothing
```

**With Savepoints:**
```dart
final tx = Cell.transaction();
await tx.begin([cell1, cell2, cell3]);

tx.update(cell1, 10);
tx.update(cell2, 20);

// Create a checkpoint
final sp = tx.savepoint();

// Speculative updates
tx.update(cell2, 30);
tx.update(cell3, 40);

// Something went wrong - rollback to checkpoint
await tx.rollback(savepoint: sp);

// cell1 = 10, cell2 = 20, cell3 unchanged
await tx.commit();
```

**With Isolation Levels:**
```dart
final tx = Cell.transaction(TransactionOptions(
  isolation: IsolationLevel.repeatableRead,
  timeout: Duration(seconds: 5),
  onEvent: (e) => print(e),
));

await tx.begin([accountA, accountB]);
// Reads return snapshot from begin
final a = tx.read(accountA) as int;
tx.update(accountA, a + 100);
await tx.commit();
```

---

### 17. `Cell.txApply` — Batch multiple apply() into a single commit

**Purpose:** Batch multiple apply() calls into a single atomic commit.

**When to use:**
- Multiple function calls that must be atomic
- Complex state mutations
- Performance optimization (reduce downstream churn)

**Basic Usage:**
```dart
final tx = Cell.txApply();

await tx.execute(
  participants: [cell1, cell2],
  body: (tx) {
    cell1.apply(updateFunction1);
    cell2.apply(updateFunction2);
  },
);
```

**With Compensation:**
```dart
final tx = Cell.txApply(TxApplyOptions(
  compensationErrorPolicy: CompensationErrorPolicy.bestEffort,
  compensationMaxAttempts: 3,
));

await tx.execute(
  participants: [cell1, cell2],
  body: (tx) {
    cell1.apply(
      updateFunction,
      compensate: rollbackFunction,
    );
  },
);
```

---

## Quick Reference Card

### Essential Operators Summary

| # | Operator | Category | Purpose |
|---|----------|----------|---------|
| 1 | `state` | Entry Point | Retained app state |
| 2 | `ingress` | Entry Point | Event entry |
| 3 | `open` | Entry Point | Manual control |
| 4 | `derive` | Transformation | Projections |
| 5 | `synthesis` | Transformation | Multi-source aggregation |
| 6 | `sanitized` | Transformation | Data redaction |
| 7 | `asyncMap` | Transformation | Background tasks |
| 8 | `switchMap` | Transformation | Dynamic source selection |
| 9 | `debounce` | Flow Control | Stability-based |
| 10 | `distinct` | Flow Control | Deduplication |
| 11 | `observe` | Observation | Side effects |
| 12 | `hub` | Routing | Signal routing |
| 13 | `fromFuture` | Bridge | One-time async |
| 14 | `fromStream` | Bridge | Continuous async |
| 15 | `transaction` | Orchestration | Atomic updates |
| 16 | `txApply` | Orchestration | Batch apply() |

---

## Common Patterns

### 1. Counter with UI

```dart
final counter = Cell.state<int>(
  initial: 0,
  evolve: (host, input) {
    final delta = input.payload as int? ?? 1;
    return Pulse(host.value + delta);
  },
);

final display = Cell.derive<int, String>(
  source: counter.cell,
  project: (pulse) => Pulse('Count: ${pulse.payload}'),
);
```

### 2. Search with Debounce

```dart
final search = Cell.ingress<String>();
final debounced = Cell.debounce(search.cell, Duration(milliseconds: 300));
final results = Cell.asyncMap<String, List<Result>>(
  debounced,
  (query) => api.search(query),
  latestOnly: true,
);
```

### 3. Form Validation

```dart
final email = Cell.state<String>(...);
final password = Cell.state<String>(...);
final isValid = Cell.synthesis<bool>([email.cell, password.cell], ...);
```

### 4. Event Router

```dart
final hub = Cell.hub(
  routing: HubRouting.pattern,
  registrations: [
    (key: 'user.*', priority: 10, handler: userHandler),
    (key: 'admin.*', priority: 20, handler: adminHandler),
  ],
  fallback: 'unknown',
);
```

### 5. Atomic Transfer

```dart
final tx = Cell.transaction();
await tx.begin([accountA, accountB]);
final a = tx.read(accountA) as int;
final b = tx.read(accountB) as int;
tx.update(accountA, a - 50);
tx.update(accountB, b + 50);
await tx.commit();
```

### 6. Async Data Loading

```dart
final userId = Cell.ingress<int>();
final userProfile = Cell.asyncMap<int, UserProfile>(
  userId.cell,
  (id) => api.fetchProfile(id),
  latestOnly: true,
);
```

### 7. Multi-Source Synthesis

```dart
final summary = Cell.synthesis([a.cell, b.cell, c.cell], aggregator: ...);
```

---

## Next Steps

### Continue Learning

| Resource | Description |
|----------|-------------|
| [HowTo_Instruction.md](./HowTo_Instruction.md) | Deep dive into Instructions |
| [HowTo_Receptor.md](./HowTo_Receptor.md) | Building transformation pipelines |
| [HowTo_TestCell.md](./HowTo_TestCell.md) | Validation and security |
| [HowTo_Start.md](./HowTo_Start.md) | Getting started guide |

### Run the Examples

```bash
# Instruction pipeline
dart run examples/instruction_pipeline_walkthrough.dart

# Hub demo
dart run examples/hub_demo.dart

# Throttle demo
dart run examples/throttle_demo.dart
```

### Build Your First App

```dart
import 'package:cell/cell.dart';

void main() {
  // State
  final counter = Cell.state<int>(...);
  
  // Derive
  final display = Cell.derive<int, String>(...);
  
  // Observe
  final observer = Cell.observe<int>(
    source: counter.cell,
    effect: (pulse) => print(pulse.payload),
  );
  
  // Use
  counter.update(1);
}
```

---

## Summary

### Key Takeaways

1. **16 operators** cover most daily reactive needs
2. **Learning path** guides you from simple to complex
3. **Each operator** has a specific purpose
4. **Composition** creates powerful systems
5. **Zero boilerplate** - default settings work

### Quick Start Checklist

* Understand the learning path
* Start with `state`, `ingress`, `observe`
* Add `derive` for projections
* Use `debounce` for user input
* Use `asyncMap` for network calls
* Use `synthesis` for multi-source
* Use `transaction` for atomic updates
* Use `hub` for routing

---

**Happy coding with the Cell Framework!** 🚀