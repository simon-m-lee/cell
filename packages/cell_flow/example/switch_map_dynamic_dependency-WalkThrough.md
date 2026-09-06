# Walkthrough — Dynamic Dependency Injection (Flow.switchMap)

**Demo:** `example\switch_map_dynamic_dependency_demo.dart`

One pipeline. Three layers in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **Cell** | ingress + observe | What source is selected; what data is displayed |
| **Flow** | switchMap + map + filter | Switch sources; cancel previous; transform data |
| **Observer** | `Cell.observe` | Display results and status changes |

Flow handles the source switching and cancellation. Cell carries the selection and results. The observer displays the outcome.

---

## 1. Why they have to combine

A user selects a **different source**. The previous source should be **cancelled**. The new source should start **immediately**.

If you put switching logic inside the observer, the observer becomes coupled to source management. If you put cancellation in the source, each source becomes complex. If you put state preservation in the Cell, the Cell becomes specific to one use case.

The demo's rule:

```
Flow answers: which source is active? Should we cancel the previous?
Cell answers: what did the user select? What data arrived?
Observer answers: what should the user see?
```

---

## 2. Design (tagged)

**[Cell]** holds or carries. **[FlowInstruction]** is `(pulse)→pulse|null`.
**[Receptor]** runs the chain under one lock. **[Cell.observe]** is
`(pulse)→side effect`.

```
 user selection
     │
     ▼
[Cell] ingress + TestCell         FLOW intake
     │  emit
     ▼
[Receptor] toHandle(source: cell)  FLOW policy
     │   [Instruction] switchMap   (switch to new source)
     │   [Instruction] map         (transform data)
     │   [Instruction] filter      (filter results)
     │   null = stop; no side effects
     ▼
[Cell] rx.cell                     FLOW output
     │  Cell.observe
     ▼
 side effect (display)             glue (Dart)
```

| You need | You use |
|---|---|
| Switch data sources | **Flow** switchMap |
| Cancel previous source | **Flow** switchMap (automatic) |
| Preserve shared state | External state + switchMap |
| Nested workflows | **Flow** switchMap inside switchMap |
| Error handling | try-catch in project function |
| Source selection UI | **Cell.ingress** |

---

## 3. Step by step — Basic Source Switching (scenario 1)

Read this as Cell then Flow then Observer.

**0. Graph (once)**
`Flow.switchMap` with `toHandle` on **Cell** `selector`.
`Cell.observe` on `switchHandle.cell` → display results.

**1. Pulse (Cell)**
User selects `'source-a'` → `selector.emit('source-a')`.

**2. Policy (Flow)**
switchMap calls `project('source-a')` which returns a Stream:

```
project('source-a') → numericSource('Source A')
  → emits: 'Source A: Starting...'
  → emits: 'Source A: 1'
  → emits: 'Source A: 2'
  → emits: 'Source A: Complete!'
```

**3. Switch (Flow)**
User selects `'source-b'` → previous source is cancelled:

```
project('source-b') → letterSource('Source B')
  → 'Source A' stream is cancelled (no more emissions)
  → 'Source B' starts emitting
```

**4. Observer (glue)**
Observer displays each emission. The switch is seamless.

---

## 4. Step by step — User Profile Switching (scenario 2)

switchMap with Future-based sources:

```
user-123 → project('user-123') → userProfileSource('user-123')
  → emits UserProfile (Alice)
user-456 → project('user-456') → previous Future cancelled
  → emits UserProfile (Bob)
```

Previous profile is automatically cancelled. Only the latest profile is displayed.

---

## 5. Step by step — Dashboard Switching (scenario 3)

switchMap with Stream sources that emit multiple values:

```
'metrics' → dashboardSource('metrics')
  → emits: DashboardView (CPU: 48%, Memory: 63%, Disk: 43%)
  → emits: DashboardView (CPU: 55%, Memory: 78%, Disk: 38%)
'logs' → dashboardSource('logs')
  → 'metrics' stream cancelled
  → emits: DashboardView (logs: 3 entries)
```

Live data switches seamlessly. Previous stream is cleaned up.

---

## 6. Step by step — Feature Flag Switching (scenario 4)

switchMap with conditional logic:

```
'v1' → project('v1') → 'Feature V1: Using algorithm v1.0'
'v2' → project('v2') → previous cancelled → 'Feature V2: Using algorithm v2.0'
```

Feature versions are switched at runtime. Previous implementation is cancelled.

---

## 7. Step by step — API Endpoint Switching (scenario 5)

switchMap with Future-based API connections:

```
'api.example.com/v1' → connectToEndpoint('api.example.com', 'v1')
  → emits ApiEndpoint (connected)
'api.example.com/v2' → previous cancelled → new connection
```

API endpoints are switched dynamically. Previous connections are cleaned up.

---

## 8. Step by step — Stateful Switch (scenario 6)

switchMap with shared state across switches:

```
sharedState = {count: 42}
source-a → statefulSource('source-a', sharedState)
  → emits: 'source-a: Starting with state: 42'
  → emits: 'source-a: Updated state to 43'
  → emits: 'source-a: Updated state to 44'
source-b → statefulSource('source-b', sharedState)
  → source-a cancelled
  → emits: 'source-b: Starting with state: 44'
  → emits: 'source-b: Updated state to 46'
  → emits: 'source-b: Updated state to 47'
```

State is preserved across switches. The new source continues from where the previous left off.

---

## 9. Step by step — Nested Switch (scenario 7)

switchMap inside switchMap for dynamic workflows:

```
'data-pipeline' → _dataPipeline()
  → Step 1: Extracting data...
  → Step 2: Transforming data...
  → Step 3: Loading data...
  → Complete!
'validation' → _validationWorkflow()
  → 'data-pipeline' cancelled
  → Step 1: Schema validation...
  → Step 2: Data quality check...
  → Step 3: Business rules...
  → Complete!
```

Workflows are nested. Switching workflows cancels the previous one.

---

## 10. Step by step — Auth Provider Switching (scenario 8)

switchMap with authentication providers:

```
'google' → project('google') → {provider: 'google', email: 'user@gmail.com'}
'github' → project('github') → previous cancelled → {provider: 'github', email: 'user@github.com'}
'local' → project('local') → previous cancelled → {provider: 'local', email: 'user@local.com'}
```

Authentication providers switch seamlessly. Each provider returns different user data.

---

## 11. Step by step — Error Handling (scenario 9)

switchMap with error handling:

```
'normal' → project('normal') → 'Success: normal'
'error' → project('error') → throws Exception → error pulse emitted
'recovery' → project('recovery') → 'Success: recovery'
```

Errors are caught and emitted as error pulses. The pipeline continues.

---

## 12. Flow.switchMap vs Other Operators

| Operator | Behavior | Use Case |
|---|---|---|
| **switchMap** | Switches to latest source, cancels previous | Dynamic selection, feature flags |
| **concatMap** | Processes sequentially, waits for completion | Ordered operations |
| **mergeMap** | Processes concurrently, no cancellation | Parallel operations |
| **asyncMap** | Maps each value through async function | Per-item async transformation |

---

## 13. Source Types Supported

| Source Type | Example | Use Case |
|---|---|---|
| Stream | `Stream<String>` | Live data, real-time updates |
| Future | `Future<UserProfile>` | One-shot async operations |
| Iterable | `['a', 'b', 'c']` | Static sequences |
| Value | `'hello'` | Constant values |

---

## 14. Parts checklist

| Kind | Instances |
|---|---|
| Cell | `selector`, `userSelector`, `viewSelector`, `featureSelector`, `apiSelector`, `stateSelector`, `workflowSelector`, `authSelector`, `errorSelector` |
| FlowInstruction | switchMap, map, filter |
| FlowHandle | one per pipeline |
| Observer | one per output cell |
| Not Cell | DataSourceFactory, workflow helpers |

---

## 15. Rules for combining them

1. **Flow switches sources. Cell carries selections. Observer displays results.**
2. **Use switchMap for dynamic source selection.**
3. **Previous sources are automatically cancelled.**
4. **Use shared state for context preservation across switches.**
5. **Nested switches enable complex workflows.**
6. **Handle errors with try-catch in project function.**
7. **Supports Stream, Future, Iterable, and value sources.**
8. **Great for: feature flags, A/B testing, user context, multi-tenant.**

---

## 16. Common Use Cases

| Use Case | Pattern |
|---|---|
| Feature flags | Switch between feature implementations |
| A/B testing | Switch between experiment variants |
| User context | Switch between user profiles |
| Multi-tenant | Switch between tenant data sources |
| Dynamic config | Switch between configuration sources |
| Plugin systems | Switch between plugin implementations |
| Module loading | Switch between loaded modules |
| Theme switching | Switch between theme providers |

---

## Still demo-only

All sources are simulated. Real-world switching may involve authentication, permissions, and complex state management. Performance considerations apply to high-frequency switching.

---

## Summary table

| Scenario | Flow does | Cell does | Observer does |
|---|---|---|---|
| 1 Basic | Switches sources, cancels previous | Carries selection/results | Displays emissions |
| 2 User Profiles | Switches profiles, cancels previous | Carries user ID/profile | Displays profile |
| 3 Dashboard | Switches views, cancels previous | Carries view selection/data | Displays view data |
| 4 Feature Flags | Switches features, cancels previous | Carries feature toggle | Displays feature result |
| 5 API Endpoints | Switches endpoints, cancels previous | Carries endpoint selection | Displays connection |
| 6 Stateful | Switches sources, preserves state | Carries source selection | Displays state updates |
| 7 Nested | Nested switch, cancels workflows | Carries workflow selection | Displays workflow steps |
| 8 Auth Providers | Switches providers, cancels previous | Carries provider selection | Displays auth result |
| 9 Error | Handles errors, emits error pulses | Carries selection | Displays success/error |