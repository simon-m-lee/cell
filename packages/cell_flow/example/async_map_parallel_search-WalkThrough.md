# Walkthrough — AsyncMap Parallel Search

**Demo:** `example\async_map_parallel_search_demo.dart`

One source cell. Three asyncMap strategies in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **asyncMap** | `Flow.asyncMap` + queue | Ordered sequential processing |
| **asyncMapConcurrent** | `Flow.asyncMapConcurrent` + parallel | Concurrent fetches, throughput |
| **asyncMapLatest** | `Flow.asyncMapLatest` + cancel | Search-as-you-type, latest only |

`asyncMap` processes in order. `asyncMapConcurrent` runs in parallel. `asyncMapLatest` cancels stale work. The demo shows when to use each.

---

## 1. Why they have to combine

A search is a **query**. An API call is **I/O**. A user types **rapidly**.

If you use `asyncMap` for search, each keystroke waits for the previous one — the user sees lag. If you use `asyncMapConcurrent` for ordered tasks, results arrive out of order — the wrong item updates the UI. If you use `asyncMapLatest` for background jobs, work gets cancelled — a long-running task never completes.

The demo's rule:

```
asyncMap:        order matters → process sequentially
asyncMapConcurrent: throughput matters → run in parallel
asyncMapLatest:   only the latest matters → cancel stale
```

---

## 2. Design (tagged)

**[Cell]** holds the input stream. **[Flow.asyncMap]** transforms each input through an async function. The three variants control **concurrency** and **cancellation**.

```
User input
     │
     ▼
[Cell] ingress<T>                        INPUT
     │  emit
     ▼
┌─────────────────────────────────────────────────────────────┐
│                    FLOW.asyncMap*                         │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ asyncMap       → queue    → one at a time         │  │
│  │ asyncMapConcurrent → parallel → completion order   │  │
│  │ asyncMapLatest  → cancel   → latest only          │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
└─────────────────────────────────────────────────────────────┘
     │
     ▼
[Cell] output cell                                     RESULT
     │  Cell.observe
     ▼
 console / UI
```

| You need | You use |
|---|---|
| API calls in strict order | `asyncMap` |
| Fetch multiple items in parallel | `asyncMapConcurrent` |
| Search-as-you-type | `asyncMapLatest` |
| Cancellation on new input | `asyncMapLatest` |
| Error recovery with fallback | `asyncMapWithFallback` |
| Time-boxed operations | `asyncMapWithTimeout` |
| Index-aware processing | `asyncMapWithIndex` |

---

## 3. Step by step — parallel fetches (scenario 1)

**0. Graph**  
`parallelInput`: ingress cell.  
`Flow.asyncMapConcurrent`: mapper fetches a product with variable delay.  
`Cell.observe`: prints results as they complete.

**1. Pulse (Cell)**  
`parallelInput.emit(1)` → input cell emits.

**2. Parallel (Flow)**  
`asyncMapConcurrent` starts the mapper for product 1.  
`parallelInput.emit(2)` starts product 2 immediately (no queue).  
`parallelInput.emit(3)` starts product 3 immediately.

**3. Results (Flow)**  
Product 3 completes first (100ms) → emits.  
Product 2 completes second (300ms) → emits.  
Product 1 completes last (500ms) → emits.

**4. Output**  
Results printed in completion order. Total time ≈ 508ms vs 900ms sequential.

```
time →
┌─────────────────────────────────────────────────────────────┐
│ Product 1 (500ms)  ──────────────────────────────────────│
│ Product 2 (300ms)  ──────────────────────│
│ Product 3 (100ms)  ──────────│
└─────────────────────────────────────────────────────────────┘
0ms           100ms          300ms          500ms
```

---

## 4. Step by step — search-as-you-type (scenario 2)

**0. Graph**  
`searchInput`: ingress cell.  
`Flow.asyncMapLatest`: mapper searches with variable delay.  
`Cell.observe`: prints only the latest result.

**1. Rapid typing**  
`searchInput.emit('d')` → starts search (id=1).  
`searchInput.emit('da')` → starts search (id=2), id=1 becomes stale.  
`searchInput.emit('dar')` → starts search (id=3), id=2 becomes stale.  
`searchInput.emit('dart')` → starts search (id=4), id=3 becomes stale.

**2. Cancellation**  
`asyncMapLatest` tracks a `generation` counter. Each new query increments it.  
When id=1 completes, `generation == 4` → result dropped.  
When id=2 completes, `generation == 4` → result dropped.  
When id=3 completes, `generation == 4` → result dropped.  
When id=4 completes, `generation == 4` → result emitted.

**3. Output**  
Only the latest query (`'dart'`) is printed.

```
time →
┌─────────────────────────────────────────────────────────────┐
│ 'd'      ────────┐ (stale, dropped)                     │
│ 'da'     ────────┐ (stale, dropped)                     │
│ 'dar'    ────────┐ (stale, dropped)                     │
│ 'dart'   ────────┘ (emitted)                            │
└─────────────────────────────────────────────────────────────┘
0ms        50ms     100ms    150ms    200ms    250ms    300ms
```

---

## 5. Step by step — ordered sequential tasks (scenario 3)

**0. Graph**  
`taskInput`: ingress cell.  
`Flow.asyncMap`: mapper processes tasks with variable delay.  
`Cell.observe`: collects results in emission order.

**1. Sequential queue**  
`taskInput.emit(1)` → starts Task 1 (300ms).  
`taskInput.emit(2)` → queued (Task 1 busy).  
`taskInput.emit(3)` → queued (Task 1 busy).

**2. Processing**  
Task 1 completes (300ms) → emits.  
Task 2 starts (200ms).  
Task 2 completes (500ms total) → emits.  
Task 3 starts (400ms).  
Task 3 completes (900ms total) → emits.

**3. Output**  
Results in input order: `[Task 1, Task 2, Task 3]`.

```
time →
┌─────────────────────────────────────────────────────────────┐
│ Task 1 (300ms)  ──────────────────│                       │
│ Task 2 (200ms)                    ────────────│           │
│ Task 3 (400ms)                                ────────────│
└─────────────────────────────────────────────────────────────┘
0ms        300ms          500ms          900ms
```

---

## 6. Performance comparison (scenario 6)

The demo benchmarks three strategies with 5 items:

| Strategy | Time | Speedup |
|----------|------|---------|
| Sequential (`asyncMap`) | ~1508ms | 1.0x |
| Parallel (`asyncMapConcurrent`) | ~312ms | 4.8x |
| Latest (`asyncMapLatest`) | ~350ms (1 emission) | N/A |

**Why parallel is faster:** 5 items × 300ms sequential = 1500ms.  
Parallel runs all 5 concurrently = 300ms (the slowest single item).

**Why latest emits only 1:** The rapid input (50ms gaps) means each new query cancels the previous in-flight work. Only the final emission survives.

---

## 7. Real-world: product search with auto-suggest (scenario 7)

Combines **debounce** + **asyncMapLatest**:

```
User types "p" → debounce timer starts
User types "pr" → debounce resets
User types "pro" → debounce resets
User types "prod" → debounce resets
User types "product" → debounce resets
          ↓ (200ms silence)
Debounce emits "product"
asyncMapLatest searches → only "product" result appears
```

**Why this matters:** Without debounce, every keystroke would trigger a search. With debounce + latest, only the final query is processed.

```
┌─────────────────────────────────────────────────────────────┐
│ Keystrokes:  p    pr   pro   prod   product               │
│              │    │    │     │      │                      │
│ Debounce:    └────┴────┴─────┴──────┘                     │
│              ←─── 200ms silence ───→                      │
│                        ↓                                   │
│ asyncMapLatest:        search("product")                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. Error handling with fallback (scenario 8)

`asyncMapWithFallback` catches errors and emits a fallback value:

```
normal query → Success: normal query
error test   → [Error] Simulated failure → ⚠️ Fallback result
another query → Success: another query
```

**Why this matters:** A single API failure doesn't break the flow. The UI always gets a value.

---

## 9. Operator comparison

| Operator | Concurrency | Cancels | Order | Use Case |
|---|---|---|---|---|
| `asyncMap` | 1 (queue) | No | Input order | Ordered sequential tasks |
| `asyncMapConcurrent` | Unlimited | No | Completion order | Parallel fetches |
| `asyncMapLatest` | 1 (latest) | Yes (stale) | Latest only | Search-as-you-type |
| `asyncMapWithFallback` | 1 (queue) | No | Input order | Error recovery |
| `asyncMapWithTimeout` | 1 (queue) | Yes (timeout) | Input order | Time-bound ops |
| `asyncMapWithIndex` | 1 (queue) | No | Input order | Index-aware processing |
| `asyncMapWithRetry` | 1 (queue) | No | Input order | Transient failures |

---

## 10. Rules for combining them

1. **Use `asyncMap` when order matters.** Processing must complete in input order.
2. **Use `asyncMapConcurrent` when throughput matters.** Results can be unordered.
3. **Use `asyncMapLatest` when only the latest matters.** Stale work should be cancelled.
4. **Combine with `debounce` for user input.** Prevents unnecessary work.
5. **Use `withFallback` for error recovery.** Always emit a value.
6. **Use `withTimeout` for time-bound operations.** Don't wait forever.
7. **Use `withRetry` for transient failures.** Retry before giving up.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Strategy                    │  When to use                          │
├─────────────────────────────────────────────────────────────────────────┤
│  asyncMap                   │  Sequential tasks, order matters      │
│  asyncMapConcurrent         │  Parallel tasks, throughput matters   │
│  asyncMapLatest             │  Search, only latest matters          │
│  asyncMapWithFallback       │  Graceful error handling              │
│  asyncMapWithTimeout        │  Time-bound operations                │
│  asyncMapWithIndex          │  Index-aware processing               │
│  asyncMapWithRetry          │  Transient failure recovery           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Still demo-only

API calls are simulated with `Future.delayed`. No real network I/O.  
Error handling prints to console. No logging to persistent storage.  
Performance measurements are approximate (host scheduling affects timing).  
No cancellation of actual HTTP requests — the `latest` strategy simply drops the result.

---

## Production shape

| Piece | Demo | Production |
|---|---|---|
| Input | `Cell.ingress` | UI event stream / API gateway |
| Parallel | `asyncMapConcurrent` | `Future.wait` with concurrency limit |
| Search | `debounce + asyncMapLatest` | AbortController / cancellation tokens |
| Error | `asyncMapWithFallback` | Logging + retry with backoff |
| Order | `asyncMap` | Job queue with persistent storage |
| Timeout | `asyncMapWithTimeout` | Circuit breaker pattern |
| Index | `asyncMapWithIndex` | Batch progress tracking |