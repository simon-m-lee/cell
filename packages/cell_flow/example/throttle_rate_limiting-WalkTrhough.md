# Walkthrough — Throttle Rate Limiting (Flow.throttle)

**Demo:** `example\throttle_rate_limiting_demo.dart`

One pipeline. Three layers in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **Cell** | ingress + state + observe | What events occur; what state is tracked |
| **Flow** | throttle + debounce + map + filter | Limit frequency; control emissions; track state |
| **Observer** | `Cell.observe` | Display results and metrics |

Flow handles the rate limiting. Cell carries the events and state. The observer displays the outcome.

---

## 1. Why they have to combine

A user clicks **rapidly**. An API has a **rate limit**. The UI should be **responsive**.

If you put rate limiting in the UI, the UI becomes coupled to throttling logic. If you put throttling in the API call, the API becomes complex. If you put frequency control in the Cell, the Cell becomes specific to one use case.

The demo's rule:

```
Flow answers: when should events be emitted?
Cell answers: what events occurred? What is the current state?
Observer answers: what should the user see?
```

---

## 2. Design (tagged)

**[Cell]** holds or carries. **[FlowInstruction]** is `(pulse)→pulse|null`.
**[Receptor]** runs the chain under one lock. **[Cell.observe]** is
`(pulse)→side effect`.

```
 user events (clicks/scrolls)
     │
     ▼
[Cell] ingress + TestCell         FLOW intake
     │  emit
     ▼
[Receptor] toHandle(source: cell)  FLOW policy
     │   [Instruction] throttle    (limit frequency)
     │   [Instruction] map         (process event)
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
| Limit event frequency | **Flow** throttle |
| Immediate first response | `leading: true` |
| Last event in window | `trailing: true` |
| API rate limiting | Throttle with 50ms window |
| Scroll event handling | Throttle with 50ms window |
| Form submission protection | Throttle with 100ms window |
| Sliding window control | Custom throttle with state |

---

## 3. Step by step — Basic Throttle (scenario 1)

Read this as Cell then Flow then Observer.

**0. Graph (once)**
`Flow.throttle` with `toHandle` on **Cell** `clickInput`.
`Cell.observe` on `throttleHandle.cell` → display results.

**1. Pulse (Cell)**
User clicks → `clickInput.emit('Click #1')`.

**2. Policy (Flow)**
Throttle with 50ms window, `leading: true`, `trailing: false`:

```
0ms: Click #1 → ✅ emitted (leading)
10ms: Click #2 → dropped (in window)
20ms: Click #3 → dropped (in window)
30ms: Click #4 → dropped (in window)
100ms: Click #5 → ✅ emitted (window expired)
```

**3. Observer (glue)**
Observer displays each emitted click. Dropped events are silent.

**Why this matters**: 5 clicks became 2 emissions. The API was protected.

---

## 4. Step by step — Throttle with Trailing (scenario 2)

Throttle with `leading: true`, `trailing: true`:

```
0ms: Event #1 → ✅ emitted (leading)
10ms: Event #2 → buffered
20ms: Event #3 → buffered (replaces #2)
30ms: Event #4 → buffered (replaces #3)
50ms: window expires → ✅ Event #4 emitted (trailing)
```

Both first and last events are emitted. Intermediate events are dropped.

---

## 5. Step by step — API Rate Limiting (scenario 3)

Throttle with `leading: true`, `trailing: false`:

```
Request #1 → ✅ API Called
Request #2 → dropped
Request #3 → dropped
Request #4 → ✅ API Called
→ Successful: 2, Dropped: 2
```

The API receives only 2 calls instead of 4. Rate limit is respected.

---

## 6. Step by step — Throttle vs Debounce (scenario 4)

Comparison of two timing strategies:

```
Emitting: [1, 2, 3, 4, 5] with 20ms intervals

Throttle: [1, 3, 5] (rate-limited, emits at 50ms intervals)
Debounce: [5] (only final value after 50ms silence)
```

| Feature | Throttle | Debounce |
|---|---|---|
| **Behavior** | Emits at fixed rate | Waits for silence |
| **Output** | Multiple values | Single final value |
| **Use case** | Scroll, clicks | Search, auto-save |

---

## 7. Step by step — Scrolling with Throttle (scenario 5)

Scroll events throttled with 50ms window:

```
Scroll to 10px → ✅ emitted
Scroll to 25px → dropped
Scroll to 42px → dropped
Scroll to 60px → dropped
Scroll to 80px → dropped
Scroll to 100px → ✅ emitted (window expired)
Scroll to 150px → ✅ emitted (window expired)
Scroll to 200px → ✅ emitted (window expired)
Scroll to 250px → ✅ emitted (window expired)
```

UI updates are limited to 20fps. Scrolling is smooth.

---

## 8. Step by step — API Rate Limiting Simulation (scenario 6)

20 events in a burst with 50ms throttle:

```
Total Events: 20
API Calls Made: 5 (rate limit: 5 per 50ms)
Rate Limit Errors: 0
API Cost Saved: 15
Throttle Efficiency: 75%
```

The throttle prevents rate limit errors and saves API costs.

---

## 9. Step by step — Sliding Window Throttle (scenario 7)

Custom throttle using state:

```
0ms: keypress → ✅ emitted (window starts)
30ms: keypress → dropped (in window)
60ms: keypress → dropped (in window)
100ms: keypress → ✅ emitted (new window)
```

The sliding window tracks the last emission time. Events within 50ms are dropped.

---

## 10. Step by step — Form Submission (scenario 8)

Form submissions throttled with 100ms window:

```
Form #1 (Alice) → ✅ submitted
Form #2 (Bob) → throttled
Form #3 (Charlie) → throttled
Form #4 (Diana) → ✅ submitted (window expired)
Form #5 (Eve) → ✅ submitted (window expired)
```

5 submissions become 3 processed. The backend is protected.

---

## 11. Throttle Configuration Comparison (scenario 9)

Four configurations with 40ms window, 15ms intervals:

| Config | leading | trailing | Result | Use Case |
|---|---|---|---|---|
| Leading Only | true | false | `[1, 4]` | Click prevention |
| Trailing Only | false | true | `[5]` | Final state only |
| Both | true | true | `[1, 5]` | Complete handling |
| None | false | false | `[]` | Testing |

---

## 12. Throttle vs Debounce Decision Guide

| Scenario | Use | Reason |
|---|---|---|
| Button clicks | throttle | Prevent double submission |
| Scroll events | throttle | Smooth UI updates |
| Mouse move | throttle | Performance |
| API calls | throttle | Rate limiting |
| Search input | debounce | Only final query matters |
| Auto-save | debounce | Save after user stops |
| Form validation | debounce | Validate after typing stops |
| Real-time updates | throttle | Regular interval updates |

---

## 13. Parts checklist

| Kind | Instances |
|---|---|
| Cell | `clickInput`, `trailingInput`, `apiInput`, `compareInput`, `scrollInput`, `rateInput`, `slidingInput`, `submitInput`, `configInput` |
| FlowInstruction | throttle, debounce, map, filter |
| FlowHandle | one per pipeline |
| Observer | one per output cell |
| Not Cell | lastEmitTimeHandle (state cell for sliding window) |

---

## 14. Rules for combining them

1. **Flow limits frequency. Cell carries events. Observer displays results.**
2. **Use throttle for rate limiting and frequency control.**
3. **`leading: true` emits the first event immediately.**
4. **`trailing: true` emits the last event after the window.**
5. **Use throttle for: API calls, scroll events, clicks, form submissions.**
6. **Use debounce for: search input, auto-save, form validation.**
7. **Custom throttle with state for sliding window control.**
8. **Throttle saves API costs and prevents rate limit errors.**

---

## 15. Real-World Use Cases

| Use Case | Duration | leading | trailing |
|---|---|---|---|
| Button click | 300ms | true | false |
| Scroll events | 50ms | true | false |
| API calls | 100ms | true | false |
| Mouse move | 16ms | true | false |
| Form submission | 200ms | true | false |
| Real-time updates | 100ms | true | true |

---

## Still demo-only

All events are simulated. Real-world throttling may involve backpressure, network latency, and more complex rate limiting strategies.

---

## Summary table

| Scenario | Flow does | Cell does | Observer does |
|---|---|---|---|
| 1 Basic | Throttle with leading | Carries clicks | Displays emissions |
| 2 Trailing | Throttle with trailing | Carries events | Displays leading + trailing |
| 3 API Rate | Throttle API calls | Carries requests | Displays success/drop |
| 4 Comparison | Throttle vs debounce | Carries numbers | Displays both results |
| 5 Scroll | Throttle scroll events | Carries positions | Displays updates |
| 6 API Sim | Throttle burst | Carries event IDs | Displays metrics |
| 7 Sliding | Custom throttle | Carries keypresses | Displays emissions |
| 8 Form | Throttle submissions | Carries form data | Displays processed |
| 9 Config | 4 configurations | Carries numbers | Displays all results |