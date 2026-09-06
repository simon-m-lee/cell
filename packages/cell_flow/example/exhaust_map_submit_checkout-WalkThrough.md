# Walkthrough — ExhaustMap Submit, Checkout, Refresh

**Demo:** `example\exhaust_map_submit_checkout_demo.dart`

One input source. Nine real-world scenarios in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **exhaustMap** | `Flow.exhaustMap` + project | Ignore new triggers while busy |
| **Cell.state** | Loading + result state | Show visual feedback |
| **Debounce** | `Flow.debounce` | Wait for silence |
| **MergeWith** | `Flow.mergeWith` | Combine exhaustMap and debounce for comparison |

exhaustMap ignores new triggers while an operation is in flight. The first trigger is processed; subsequent triggers are dropped until the current operation completes.

---

## 1. Why exhaustMap matters

Users tap buttons rapidly. Double-taps cause duplicate submissions, duplicate payments, and duplicate API calls. exhaustMap prevents this by ignoring new triggers while busy.

The demo's rule:

```
exhaustMap:        first trigger → process; busy → ignore
```

---

## 2. Design (tagged)

**[Cell]** holds the input stream. **[Flow.exhaustMap]** processes the first trigger and ignores others while busy. **[Cell.state]** tracks loading and result states.

```
┌─────────────────────────────────────────────────────────────┐
│                    USER INPUT                             │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Click #1  Click #2  Click #3  Click #4  Click #5   │  │
│  └─────────────────────────────────────────────────────┘  │
│                          │                               │
│                          ▼                               │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Flow.exhaustMap                       │  │
│  │  ┌─────────────────────────────────────────────┐   │  │
│  │  │ Click #1 → process (busy = true)           │   │  │
│  │  │ Click #2 → ignored (busy = true)           │   │  │
│  │  │ Click #3 → ignored (busy = true)           │   │  │
│  │  │ ... process completes (busy = false)       │   │  │
│  │  │ Click #4 → process (busy = true)           │   │  │
│  │  └─────────────────────────────────────────────┘   │  │
│  └─────────────────────────────────────────────────────┘  │
│                          │                               │
│                          ▼                               │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Output: Click #1 result only (from first click)    │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

| You need | You use |
|---|---|
| Prevent double-submit | `Flow.exhaustMap` |
| Show loading state | `Cell.state<bool>` |
| Show result state | `Cell.state<String>` |
| Payment processing | `exhaustMap` + async |
| Refresh protection | `exhaustMap` + API |
| Retry after failure | `exhaustMap` + error handling |
| Compare with debounce | `exhaustMap` + `debounce` + `mergeWith` |

---

## 3. Step by step — form submit (scenario 1)

**0. Graph**  
`submitInput`: ingress cell for Order.  
`loadingState`: Cell.state<bool> tracks loading.  
`resultState`: Cell.state<String> tracks result.  
`Flow.exhaustMap<Order, String>`: processes order submission.

**1. First click**  
`submitInput.emit(order)` → starts processing.  
`loadingState` = true, `resultState` = "Processing... 🔄".  
System processes order (200ms).

**2. Double-taps**  
During processing, two more clicks arrive.  
`exhaustMap` sees `busy = true` → ignores both.  
"IGNORED - busy" messages printed.

**3. Completion**  
Processing completes → `loadingState` = false.  
`resultState` = "✅ Order ORD-1001 confirmed!".  
Result emitted.

```
┌─────────────────────────────────────────────────────────────┐
│ Time:  0ms    50ms   100ms   150ms   200ms   250ms   300ms │
│        │       │       │       │       │       │       │   │
│ Click: #1      #2      #3                                 │
│        │       │       │                                   │
│ State: busy    busy    busy    complete                    │
│        │       │       │       │                          │
│ Output:         (ignored) (ignored)  ✅ Order submitted    │
└─────────────────────────────────────────────────────────────┘
```

**Key insight:** Only the first click is processed. Double-taps are ignored.

---

## 4. Step by step — checkout payment (scenario 2)

**0. Graph**  
`checkoutInput`: ingress cell for ShoppingCart.  
`Flow.exhaustMap<ShoppingCart, String>`: processes payment.

**1. Checkout click**  
User checks out with cart ($1029.98).  
Processing starts (300ms).  
"Processing payment... 💳" printed.

**2. Rapid clicks**  
During payment processing, two more checkout clicks arrive.  
`exhaustMap` ignores both.

**3. Completion**  
Payment completes → result emitted.  
"✅ Checkout complete: 2 items" printed.

```
┌─────────────────────────────────────────────────────────────┐
│ Time:  0ms    100ms   200ms   300ms   400ms               │
│        │       │       │       │       │                  │
│ Click: #1      #2      #3                                 │
│        │       │       │                                   │
│ State: busy    busy    busy    complete                    │
│        │       │       │       │                          │
│ Output:         (ignored) (ignored)  ✅ Checkout complete  │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Prevents duplicate payment processing. Users can't accidentally charge twice.

---

## 5. Step by step — refresh button (scenario 3)

**0. Graph**  
`refreshInput`: ingress cell for void.  
`refreshLoading`: Cell.state<bool> tracks loading.  
`Flow.exhaustMap<void, String>`: processes refresh.

**1. Refresh click**  
User clicks refresh.  
`loadingState` = true.  
"Fetching latest data... 🔄" printed.

**2. Rapid clicks**  
During refresh (150ms), two more clicks arrive.  
`exhaustMap` ignores both.

**3. Completion**  
Data refreshed → `loadingState` = false.  
"✅ Data refreshed (12 items)" printed.

```
┌─────────────────────────────────────────────────────────────┐
│ Time:  0ms    50ms   100ms   150ms   200ms                │
│        │       │       │       │       │                  │
│ Click: #1      #2      #3                                 │
│        │       │       │                                   │
│ State: loading loading loading complete                    │
│        │       │       │       │                          │
│ Output:         (ignored) (ignored)  ✅ Data refreshed     │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Prevents multiple simultaneous refresh requests. Saves bandwidth and server load.

---

## 6. Step by step — error handling (scenario 4)

**0. Graph**  
`errorInput`: ingress cell for Order.  
`failureCount`: tracks failures.  
`Flow.exhaustMap<Order, String>`: processes with retry.

**1. First submission**  
User submits "Failed Order".  
Processing starts (200ms).  
`failureCount < 1` → throws exception.  
"❌ Database connection failed" printed.

**2. Double-tap during failure**  
During processing, another click arrives.  
`exhaustMap` ignores it (busy).

**3. Retry after failure**  
Processing completes → `busy = false`.  
User retries → allowed (not busy).  
Second attempt succeeds.

```
┌─────────────────────────────────────────────────────────────┐
│ Time:  0ms    100ms   200ms   300ms   400ms   500ms       │
│        │       │       │       │       │       │          │
│ Click: #1      #2      #3                                 │
│        │       │       │                                   │
│ State: busy    busy    complete    idle    busy    complete│
│        │       │       │           │       │             │
│ Output:         (ignored) ❌ Failed  ✅ Retry successful   │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Users can retry after failure. The busy state doesn't block legitimate retries.

---

## 7. Step by step — sequential processing (scenario 5)

**0. Graph**  
`seqInput`: ingress cell for String.  
`Flow.exhaustMap<String, String>`: processes items sequentially.

**1. Multiple operations**  
User sends Op 1 → starts processing (150ms).  
User sends Op 2 → ignored (busy).  
User sends Op 3 → ignored (busy).  
Op 1 completes → `busy = false`.  
User sends Op 4 → allowed → processes.

```
┌─────────────────────────────────────────────────────────────┐
│ Time:  0ms    100ms   200ms   300ms   400ms   500ms       │
│        │       │       │       │       │       │          │
│ Op:    A       B       C               D                  │
│        │       │       │               │                  │
│ State: busy    busy    busy    complete idle   busy       │
│        │       │       │               │       │          │
│ Output: ✅ A    (ignored) (ignored)     ✅ B              │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Operations are processed one at a time. No overlapping work.

---

## 8. Step by step — shopping cart (scenario 6)

**0. Graph**  
`cartInput`: ingress cell for ShoppingCart.  
`Flow.exhaustMap<ShoppingCart, String>`: processes cart checkout.

**1. Checkout**  
User checks out cart (3 items, $189.97).  
Processing starts (250ms).  
"Processing cart... 🛒" printed.

**2. Double-click**  
During processing, another checkout click arrives.  
`exhaustMap` ignores it.

**3. Completion**  
Cart processed → result emitted.  
"✅ Cart processed successfully! 3 items" printed.

```
┌─────────────────────────────────────────────────────────────┐
│ Time:  0ms    100ms   200ms   300ms   400ms               │
│        │       │       │       │       │                  │
│ Click: #1      #2                                          │
│        │       │                                            │
│ State: busy    busy    complete                            │
│        │       │       │                                   │
│ Output:         (ignored)  ✅ Cart processed                │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Prevents duplicate cart processing. No double-charging.

---

## 9. Step by step — retry with debounce (scenario 7)

**0. Graph**  
`sveInput`: ingress cell for String.  
`Flow.exhaustMap<String, String>`: saves document with retry.

**1. First save**  
User saves Document v1.  
Processing starts (300ms).  
`saveAttempts == 1` → throws conflict error.

**2. Double-tap**  
During processing, another save arrives.  
`exhaustMap` ignores it.

**3. Retry**  
Processing completes → `busy = false`.  
User saves Document v2 → allowed.  
Second attempt succeeds.

```
┌─────────────────────────────────────────────────────────────┐
│ Time:  0ms    100ms   200ms   300ms   400ms   500ms   600ms│
│        │       │       │       │       │       │       │   │
│ Click: v1      v1      v2                                │
│        │       │       │                                   │
│ State: busy    busy    complete   idle   busy   complete   │
│        │       │       │           │      │      │         │
│ Output:         (ignored) ❌ Conflict  ✅ v2 saved         │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Users can retry after conflict. The busy state prevents duplicate saves.

---

## 10. Step by step — API with loading state (scenario 8)

**0. Graph**  
`apiInput`: ingress cell for String userId.  
`apiLoading`: Cell.state<bool> tracks loading.  
`apiResult`: Cell.state<String> tracks result.  
`Flow.exhaustMap<String, String>`: fetches user profile.

**1. API request**  
User requests profile for "user_123".  
`apiLoading` = true.  
"🔄 Loading..." printed.  
"Fetching profile... (200ms)" printed.

**2. Duplicate request**  
During loading, another request arrives.  
`exhaustMap` ignores it.

**3. Completion**  
Profile fetched → `apiLoading` = false.  
`apiResult` = "✅ Loaded: Alice (alice@example.com)".

```
┌─────────────────────────────────────────────────────────────┐
│ Time:  0ms    100ms   200ms   300ms                       │
│        │       │       │       │                          │
│ Click: #1      #2                                          │
│        │       │                                            │
│ State: loading loading complete                            │
│        │       │       │                                   │
│ Output:         (ignored)  ✅ Loaded: Alice                │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Prevents duplicate API calls. Saves bandwidth and server load.

---

## 11. Step by step — exhaustMap vs debounce (scenario 9)

**0. Graph**  
`compareInput`: ingress cell for String.  
`exhaustMap`: processes first item, ignores rest.  
`debounce`: waits for silence, processes last item.  
`mergeWith`: combines both for comparison.

**1. Rapid input**  
User sends A, B, C, D, E with 20ms intervals.

**2. exhaustMap**  
A starts processing → busy.  
B, C, D, E ignored while busy.  
Only A is processed.

**3. debounce**  
Each input resets the timer.  
After 150ms silence, E is processed.  
Only E is processed.

```
┌─────────────────────────────────────────────────────────────┐
│ Time:  0ms    20ms   40ms   60ms   80ms   100ms   150ms   │
│        │       │       │       │       │       │       │   │
│ Input: A       B       C       D       E                  │
│        │       │       │       │       │                  │
│ exhaust: A      (ignored)                ✅ A             │
│ debounce:                                      ✅ E       │
└─────────────────────────────────────────────────────────────┘
```

**Key insight:** exhaustMap preserves the first. debounce preserves the last. Choose based on use case.

---

## 12. exhaustMap vs other operators

| Operator | Behavior | Use Case |
|----------|----------|----------|
| `exhaustMap` | First wins, ignore rest | Submit, checkout, refresh |
| `debounce` | Last wins after silence | Search, user input |
| `throttle` | First wins, then rate-limit | Scroll, resize |
| `switchMap` | Latest wins, cancel previous | Search-as-you-type |
| `concatMap` | Queue all, process sequentially | Ordered processing |
| `mergeMap` | Process all concurrently | Parallel processing |

**Key difference:** exhaustMap drops new triggers while busy. switchMap cancels previous and processes latest. concatMap queues all. mergeMap processes all concurrently.

---

## 13. Rules for using exhaustMap

1. **Use exhaustMap for button clicks.** Form submit, checkout, refresh.
2. **Use exhaustMap for payment processing.** Prevent duplicate charges.
3. **Use exhaustMap for API calls.** Prevent duplicate requests.
4. **Use exhaustMap for file uploads.** Prevent overlapping uploads.
5. **Use exhaustMap for database operations.** Prevent overlapping writes.
6. **Use with loading state for feedback.** Show users when busy.
7. **Use with error handling for retries.** Allow retry after failure.
8. **Don't use exhaustMap when order matters.** Use concatMap or mergeMap.
9. **Don't use exhaustMap when latest matters.** Use switchMap or debounce.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Strategy                    │  When to use                          │
├─────────────────────────────────────────────────────────────────────────┤
│  exhaustMap                 │  Submit, checkout, refresh             │
│  debounce                   │  Search, user input                    │
│  throttle                   │  Scroll, resize                        │
│  switchMap                  │  Search-as-you-type                    │
│  concatMap                  │  Ordered processing                   │
│  mergeMap                   │  Parallel processing                   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Still demo-only

API calls are simulated with `Future.delayed`. No real network I/O.  
Payment processing is simulated — no real payment gateway.  
Error handling prints to console. No logging to persistent storage.  
Performance measurements are approximate (host scheduling affects timing).  
No cancellation of in-flight operations — exhaustMap simply ignores new triggers.

---

## Production shape

| Piece | Demo | Production |
|---|---|---|
| Input | `Cell.ingress` | UI button events |
| Exhaust | `Flow.exhaustMap` | Idempotent operations |
| Loading | `Cell.state<bool>` | Disabled button / spinner |
| Result | `Cell.state<String>` | Toast / notification |
| Payment | Simulated | Payment gateway API |
| Refresh | Simulated | API call with cache |
| Retry | Error handling | Circuit breaker + backoff |
| Comparison | `exhaustMap` vs `debounce` | Choose based on UX |