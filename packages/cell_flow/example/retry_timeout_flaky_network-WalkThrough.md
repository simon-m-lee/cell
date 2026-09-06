# Walkthrough — Retry + Timeout for Flaky Networks

**Demo:** `example\retry_timeout_flaky_network_demo.dart`

One pipeline. Three layers in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **Cell** | ingress + observe | What requests are made; what responses arrive |
| **Flow** | Retry + Timeout + AsyncMap + MergeWith | Handle failures; enforce deadlines; combine results |
| **Observer** | `Cell.observe` | Display results and user feedback |

Flow handles the retry logic and timeout enforcement. Cell carries the request and response. The observer displays the outcome.

---

## 1. Why they have to combine

A network request can **fail**. A user shouldn't see an **infinite spinner**. A server shouldn't be **overwhelmed** with retries.

If you put retry logic inside the observer, the observer becomes coupled to network semantics. If you put timeout logic inside the API call, the API becomes impure. If you put backoff logic in the Cell, the Cell becomes specific to one use case.

The demo's rule:

```
Flow answers: should we retry? Has the deadline passed?
Cell answers: what is the current request/response?
Observer answers: what should the user see?
```

---

## 2. Design (tagged)

**[Cell]** holds or carries. **[FlowInstruction]** is `(pulse)→pulse|null`.
**[Receptor]** runs the chain under one lock. **[Cell.observe]** is
`(pulse)→side effect`.

```
 user action
     │
     ▼
[Cell] ingress + TestCell         FLOW intake
     │  emit
     ▼
[Receptor] toHandle(source: cell)  FLOW policy
     │   [Instruction] AsyncMap    (async operation)
     │   [Instruction] Retry       (bounded retries)
     │   [Instruction] Timeout     (deadline enforcement)
     │   null = error; no side effects
     ▼
[Cell] rx.cell                     FLOW output
     │  Cell.observe
     ▼
 side effect (UI/logging)          glue (Dart)
```

| You need | You use |
|---|---|
| Async operation per input | **Flow** AsyncMap |
| Bounded retries | **Flow** Retry |
| Deadline enforcement | **Flow** Timeout |
| Graceful degradation | **Flow** MergeWith + cache |
| User feedback | **Cell.observe** with loading states |

---

## 3. Step by step — Simple Retry (scenario 1)

Read this as Cell then Flow then Observer.

**0. Graph (once)**
`Retry` with `toHandle` on **Cell** `retryInput`.
`Cell.observe` on `retryHandle.cell` → collect results.

**1. Pulse (Cell)**
`retryInput.emit('user')` → Cell ingress.

**2. Policy (Flow)**
Retry executes the task with bounded attempts:

```
Attempt 1: fetchUser() → Exception (HTTP 500)
  → wait, retry
Attempt 2: fetchUser() → Exception (HTTP 500)
  → wait, retry
Attempt 3: fetchUser() → UserProfile (success!)
  → emit result
```

**3. Observer (glue)**
Observer sees the success result. Each attempt is printed.

**Why this matters**: The user never sees the failures. They only see the final success (or error after all retries fail).

---

## 4. Step by step — Timeout (scenario 2)

AsyncMap with a slow response. Timeout enforces a deadline:

```
Request: fetch large dataset (2500ms)
Timeout: 2000ms deadline
  → 2000ms passes → TimeoutException emitted
  → "Request timed out" message
```

The slow response completes at 2500ms but is ignored (the timeout already fired).

**Flow** enforces the deadline. **Cell** carries the error. The observer shows the user-friendly message.

---

## 5. Step by step — Retry + Timeout (scenario 3)

Combined retry and timeout:

```
Attempt 1: placeOrder() → TimeoutException (500ms)
  → retry
Attempt 2: placeOrder() → Exception (HTTP 500)
  → retry
Attempt 3: placeOrder() → Order (success!)
  → emit result
```

**Flow** handles both retry logic and timeout enforcement. The user sees only the final success.

---

## 6. Step by step — Exponential Backoff (scenario 4)

Simulated exponential backoff with increasing failUntil:

```
Attempt 1: failUntil=3 → fail (503)
Attempt 2: failUntil=3 → fail (503)
Attempt 3: failUntil=3 → fail (503)
Attempt 4: failUntil=3 → success! (payment approved)
```

Each failure adds delay (simulated by network delay). The server gets breathing room between attempts.

---

## 7. Step by step — Deadline Exceeded (scenario 5)

Retry with a global deadline:

```
Request: critical API call
  → Attempt 1: fail (500)
  → Attempt 2: fail (500)
  → Attempt 3: fail (500)
  → Deadline exceeded (1000ms)
  → TimeoutException emitted
```

All retries failed AND the deadline passed. The user sees a clear error message.

**Why this matters**: No infinite retries. The user always gets a response within the deadline.

---

## 8. Step by step — Success on Last Attempt (scenario 6)

Retry succeeds on the final attempt:

```
Attempt 1: syncData() → fail (500)
Attempt 2: syncData() → fail (500)
Attempt 3: syncData() → success! (42 records)
```

Total attempts: 3. Success: ✅

---

## 9. Step by step — Cache Fallback (scenario 7)

Timeout with cache fallback:

```
Request: user_123
  → Timeout: 500ms deadline
    → onTimeout → check cache
      → cache hit → return cached data
```

The user sees cached data with a note: "Showing cached data (may be stale)".

**Flow** handles the timeout. The observer handles the fallback logic.

---

## 10. Step by step — Retry with Backoff (scenario 8)

Database connection with retry and simulated backoff:

```
Attempt 1: connectDB() → fail (503, 200ms)
Attempt 2: connectDB() → fail (503, 200ms)
Attempt 3: connectDB() → success! (103ms)
```

Total time: ~911ms (including delays).

---

## 11. Step by step — Deadline with Loading State (scenario 9)

Order processing with loading state and timeout:

```
User: Submit Order #1234
  → Loading: 🔄 Processing order...
  → Loading: 🔄 Processing order (100ms)
  → Loading: 🔄 Processing order (200ms)
  → Timeout: ⏱️ Deadline exceeded (500ms)
  → Loading: ❌ Order processing timed out
  → Result: ❌ Order failed
```

The user sees progress updates and then a clear timeout message.

---

## 12. Flow.Retry vs Custom Retry

| Feature | Flow.Retry | Custom Retry |
|---|---|---|
| **Attempts** | `count` parameter | Manual counter |
| **Backoff** | Configurable via `RetryTask` | Manual implementation |
| **Error handling** | `onError` callback | Try-catch |
| **Provenance** | Preserved via `withStep` | Manual |
| **Composition** | Works with other operators | Manual |

---

## 13. Failure Patterns Demonstrated

| Pattern | Scenario | Behavior |
|---|---|---|
| Transient failure | 1 | Succeeds after retries |
| Slow response | 2 | Times out |
| Network failure | 3 | Retry + timeout combined |
| Server overload | 4 | Exponential backoff |
| All retries fail | 5 | Deadline exceeded |
| Success on last attempt | 6 | Exact retry count |
| Cache fallback | 7 | Graceful degradation |
| Database connection | 8 | Retry with backoff |
| Loading state | 9 | User feedback during timeout |

---

## 14. Parts checklist

| Kind | Instances |
|---|---|
| Cell | `retryInput`, `timeoutInput`, `comboInput`, `backoffInput`, `deadlineInput`, `syncInput`, `cacheInput`, `dbInput`, `loadingInput` |
| FlowInstruction | AsyncMap, Retry, Timeout, MergeWith |
| FlowHandle | one per pipeline |
| Observer | one per output cell |
| Not Cell | FlakyNetwork (simulator), Cache (fallback) |

---

## 15. Rules for combining them

1. **Flow handles retries. Cell carries requests. Observer displays results.**
2. **Use Retry for bounded retry attempts.**
3. **Use Timeout for deadline enforcement.**
4. **Combine Retry + Timeout for robust network calls.**
5. **Use exponential backoff to reduce server load.**
6. **Provide cache fallback for graceful degradation.**
7. **Show loading states to keep users informed.**
8. **Never show infinite spinners — always return a result or error.**

---

## Still demo-only

All failures are simulated. Real-world networks may have authentication, rate limiting, and partial failures. Retry strategies should consider idempotency and business rules.

---

## Summary table

| Scenario | Flow does | Cell does | Observer does |
|---|---|---|---|
| 1 Simple Retry | Retries 3 times | Carries user ID | Displays success |
| 2 Timeout | Enforces 2s deadline | Carries request | Displays timeout error |
| 3 Retry+Timeout | Retries + deadline | Carries order | Displays success |
| 4 Backoff | Simulated backoff | Carries payment | Displays success |
| 5 Deadline | Deadline exceeded | Carries request | Displays deadline error |
| 6 Last Attempt | Retry succeeds on 3rd | Carries sync data | Displays success |
| 7 Cache Fallback | Timeout → cache | Carries cache key | Displays cached data |
| 8 DB Connection | Retry with delay | Carries DB request | Displays connection |
| 9 Loading State | Timeout with progress | Carries order | Displays loading → timeout |