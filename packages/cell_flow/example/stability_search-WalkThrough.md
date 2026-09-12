# Walkthrough — Search with Debounce (Flow.debounce)

**Demo:** `example\stability_search_demo.dart`

One pipeline. Three layers in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **Cell** | ingress + state + observe | What the user types; what results arrive |
| **Flow** | debounce + asyncMapLatest + filter + tap + throttle | Stabilize input; cancel stale requests; validate |
| **Observer** | `Cell.observe` | Display results and loading states |

Flow handles the timing and request management. Cell carries the input and results. The observer displays the outcome.

---

## Contents

1. [Why they have to combine](#1-why-they-have-to-combine)
2. [Design (tagged)](#2-design-tagged)
3. [Step by step — Basic Search (scenario 1)](#3-step-by-step--basic-search-scenario-1)
4. [Step by step — Rapid Typing (scenario 2)](#4-step-by-step--rapid-typing-scenario-2)
5. [Step by step — Cancellation (scenario 3)](#5-step-by-step--cancellation-scenario-3)
6. [Step by step — Error Handling (scenario 4)](#6-step-by-step--error-handling-scenario-4)
7. [Step by step — Loading State (scenario 5)](#7-step-by-step--loading-state-scenario-5)
8. [Step by step — Validation (scenario 6)](#8-step-by-step--validation-scenario-6)
9. [Step by step — Enhanced Loading (scenario 7)](#9-step-by-step--enhanced-loading-scenario-7)
10. [Step by step — Debounce vs Throttle (scenario 8)](#10-step-by-step--debounce-vs-throttle-scenario-8)
11. [Search Pipeline Stages](#11-search-pipeline-stages)
12. [Parts checklist](#12-parts-checklist)
13. [Rules for combining them](#13-rules-for-combining-them)
14. [Debounce vs Throttle Decision Guide](#14-debounce-vs-throttle-decision-guide)
15. [Still demo-only](#still-demo-only)
16. [Summary table](#summary-table)

---

## 1. Why they have to combine

A user types **quickly**. An API call is **expensive**. A previous request should be **cancelled**.

If you put debounce logic inside the observer, the observer becomes coupled to timing. If you put request cancellation in the API call, the API becomes complex. If you put validation in the Cell, the Cell becomes specific to one use case.

The demo's rule:

```
Flow answers: when should we search? Which request is current?
Cell answers: what did the user type? What did the API return?
Observer answers: what should the user see?
```

---

## 2. Design (tagged)

**[Cell]** holds or carries. **[FlowInstruction]** is `(pulse)→pulse|null`.
**[Receptor]** runs the chain under one lock. **[Cell.observe]** is
`(pulse)→side effect`.

```
 user typing
     │
     ▼
[Cell] ingress + TestCell         FLOW intake
     │  emit
     ▼
[Receptor] toHandle(source: cell)  FLOW policy
     │   [Instruction] debounce    (wait for silence)
     │   [Instruction] filter      (minimum length)
     │   [Instruction] tap         (log/loading state)
     │   [Instruction] asyncMapLatest (cancel stale)
     │   [Instruction] map         (transform result)
     │   null = stop; no side effects
     ▼
[Cell] rx.cell                     FLOW output
     │  Cell.observe
     ▼
 side effect (display)             glue (Dart)
```

| You need | You use |
|---|---|
| Wait for typing pause | **Flow** debounce |
| Cancel stale requests | **Flow** asyncMapLatest |
| Minimum query length | **Flow** filter |
| Loading state | **Flow** tap + Cell.state |
| Error handling | **Flow** asyncMapWithFallback |
| Rate limiting | **Flow** throttle |

---

## 3. Step by step — Basic Search (scenario 1)

Read this as Cell then Flow then Observer.

**0. Graph (once)**
`Flow.debounce` + `Flow.asyncMapLatest` with `toHandle` on **Cell** `searchInput`.
`Cell.observe` on `apiHandle.cell` → display results.

**1. Pulse (Cell)**
User types 'd' → `searchInput.emit('d')`.

**2. Policy (Flow)**
Debounce waits 300ms. Each new character resets the timer:

```
'd' → timer starts (300ms)
'da' → timer resets
'dar' → timer resets
'dart' → timer resets
→ 300ms passes → 'dart' emitted to next stage
```

**3. API Call (Flow)**
asyncMapLatest executes the API call. If a new query arrives, the previous request is cancelled.

```
'dart' → API call (200ms) → 'Found: dart programming language'
```

**4. Observer (glue)**
Observer displays the result. The user sees only the final search result.

**Why this matters**: The user typed 4 characters but only 1 API call was made.

---

## 4. Step by step — Rapid Typing (scenario 2)

Rapid typing with short delays (50ms between keystrokes):

```
f → timer reset
fl → timer reset
flu → timer reset
flut → timer reset
flutt → timer reset
flutter → timer reset
→ 300ms passes → 'flutter' emitted
→ API call (500ms) → 'Found: Flutter framework'
```

All intermediate queries are dropped. Only the final query is processed.

---

## 5. Step by step — Cancellation (scenario 3)

asyncMapLatest with different API delays:

```
a → API starts (800ms)
ab → API starts (400ms) → 'a' request cancelled
abc → API starts (200ms) → 'ab' request cancelled
→ 'abc' completes → 'ABC' emitted
```

**Flow** handles cancellation automatically. Only the latest request emits a result.

---

## 6. Step by step — Error Handling (scenario 4)

asyncMapWithFallback provides graceful error handling:

```
'error' → debounce (200ms) → API call (300ms) → throws Exception
→ fallback: 'Error occurred during search' emitted
```

The user sees a friendly error message instead of a crash.

---

## 7. Step by step — Loading State (scenario 5)

Tap sets loading state before API call:

```
'loading demo' → debounce (200ms) → tap → loadingState.update(true)
→ asyncMapLatest (400ms) → result → tap → loadingState.update(false)
```

The observer displays "Loading..." while the API is in flight.

---

## 8. Step by step — Validation (scenario 6)

Filter enforces minimum query length:

```
'a' → debounce (150ms) → filter (length >= 3) → false → dropped
'ab' → debounce (150ms) → filter (length >= 3) → false → dropped
'abc' → debounce (150ms) → filter (length >= 3) → true → API call
```

Short queries are dropped silently. Only valid queries reach the API.

---

## 9. Step by step — Enhanced Loading (scenario 7)

Debounce with request counting and error handling:

```
'hello' → debounce (250ms) → tap (requestCount=1) → API (300ms) → result
'hello world' → debounce (250ms) → tap (requestCount=2) → API (300ms) → result
'fail test' → debounce (250ms) → tap (requestCount=3) → API (300ms) → throws
→ fallback: '⚠️ Search failed, please try again'
```

Each request is tracked. Errors are handled gracefully with clear user feedback.

---

## 10. Step by step — Debounce vs Throttle (scenario 8)

Comparison of two timing strategies:

```
Rapid emissions: A, B, C, D, E (20ms apart)

Debounce: waits 100ms of silence → only 'E' emitted
Throttle: emits first immediately → 'A' then waits 100ms → 'E' emitted
```

| Feature | Debounce | Throttle |
|---|---|---|
| **Behavior** | Waits for silence | Emits at fixed rate |
| **Output** | Only final value | First value, then periodic |
| **Use case** | Search, auto-save | Scroll, mouse events |

---

## 11. Search Pipeline Stages

| Stage | Operator | Purpose |
|---|---|---|
| 1 | debounce | Wait for user to stop typing |
| 2 | filter | Minimum query length |
| 3 | tap | Set loading state |
| 4 | asyncMapLatest | API call with cancellation |
| 5 | tap | Clear loading state |
| 6 | map | Transform result |
| 7 | asyncMapWithFallback | Error handling |

---

## 12. Parts checklist

| Kind | Instances |
|---|---|
| Cell | `searchInput`, `rapidInput`, `cancelInput`, `errorInput`, `loadingInput`, `loadingState`, `validInput`, `enhancedInput`, `compareInput` |
| FlowInstruction | debounce, asyncMapLatest, asyncMapWithFallback, tap, filter, map, throttle |
| FlowHandle | one per pipeline |
| Observer | one per output cell |

---

## 13. Rules for combining them

1. **Flow handles timing. Cell carries input. Observer displays results.**
2. **Use debounce for search-as-you-type.**
3. **Use asyncMapLatest to cancel stale requests.**
4. **Use filter for validation before API calls.**
5. **Use tap for loading state management.**
6. **Use asyncMapWithFallback for error handling.**
7. **Always provide user feedback (loading states, errors).**
8. **Debounce waits for silence; throttle limits rate.**

---

## 14. Debounce vs Throttle Decision Guide

| Scenario | Use | Reason |
|---|---|---|
| Search box | debounce | Only final query matters |
| Auto-save | debounce | Save after user stops editing |
| Scroll events | throttle | Need regular updates |
| Mouse move | throttle | Need smooth tracking |
| Form validation | debounce | Validate after user stops typing |
| API polling | throttle | Regular intervals |

---

## Still demo-only

All APIs are simulated. Real-world search may have pagination, caching, and more complex error handling. Performance considerations apply to high-frequency typing.

---

## Summary table

| Scenario | Flow does | Cell does | Observer does |
|---|---|---|---|
| 1 Basic | Debounce + asyncMapLatest | Carries queries/results | Displays result |
| 2 Rapid | Debounce drops intermediate | Carries final query | Displays result |
| 3 Cancellation | asyncMapLatest cancels | Carries latest query | Displays only latest |
| 4 Error | Fallback on error | Carries error message | Displays fallback |
| 5 Loading | Tap sets/clears loading | Carries loading state | Displays loading |
| 6 Validation | Filter drops short queries | Carries valid queries | Displays valid results |
| 7 Enhanced | Tap + asyncMapWithFallback | Carries results/errors | Displays with icons |
| 8 Comparison | Debounce vs throttle | Carries input | Shows both strategies |