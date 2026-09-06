# Walkthrough — Tap for Logging & Analytics (Flow.tap)

**Demo:** `example\tap_logging_analytics_demo.dart`

One pipeline. Three layers in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **Cell** | ingress + observe | What data is flowing; what results arrive |
| **Flow** | tap + tapWithIndex + tapState + tapAll | Inject side effects; collect metrics; preserve data |
| **Observer** | `Cell.observe` | Display results and analytics |

Flow handles the side effects without modifying data. Cell carries the data through the pipeline. The observer displays the outcome.

---

## 1. Why they have to combine

You need to **log** user actions. You need to track **analytics**. You shouldn't **modify** the data.

If you put logging inside the observer, the observer becomes coupled to logging. If you put analytics in the business logic, the logic becomes impure. If you put debugging in the Cell, the Cell becomes specific to one use case.

The demo's rule:

```
Flow answers: what side effects should we inject?
Cell answers: what is the current data?
Observer answers: what should the user see?
```

---

## 2. Design (tagged)

**[Cell]** holds or carries. **[FlowInstruction]** is `(pulse)→pulse|null`.
**[Receptor]** runs the chain under one lock. **[Cell.observe]** is
`(pulse)→side effect`.

```
 data source
     │
     ▼
[Cell] ingress + TestCell         FLOW intake
     │  emit
     ▼
[Receptor] toHandle(source: cell)  FLOW policy
     │   [Instruction] tap         (log the value)
     │   [Instruction] tap         (analytics)
     │   [Instruction] tap         (performance)
     │   [Instruction] tapState    (running totals)
     │   data passes through unchanged
     ▼
[Cell] rx.cell                     FLOW output
     │  Cell.observe
     ▼
 side effect (display)             glue (Dart)
```

| You need | You use |
|---|---|
| Log user actions | **Flow** tap |
| Track session | **Flow** tapWithIndex |
| Separate concerns | Multiple **Flow** taps |
| Running totals | **Flow** tapState |
| Performance timing | **Flow** tap |
| A/B testing | **Flow** tap |
| Debugging | **Flow** tapAll |

---

## 3. Step by step — Basic Tap (scenario 1)

Read this as Cell then Flow then Observer.

**0. Graph (once)**
`Flow.tap` with `toHandle` on **Cell** `actionInput`.
`Cell.observe` on `processed.cell` → display results.

**1. Pulse (Cell)**
User action: `'PRODUCT_VIEW: iPhone 15'` → `actionInput.emit(...)`.

**2. Policy (Flow)**
tap executes the callback:

```
tap: (value) => print('[LOG] PRODUCT_VIEW: iPhone 15')
→ returns the original value unchanged
→ next stage receives the same value
```

**3. Observer (glue)**
Observer receives the unchanged value. The data is identical to the input.

**Why this matters**: The data flows through unchanged. The tap is non-invasive.

---

## 4. Step by step — Tap with Index (scenario 2)

tapWithIndex provides position information:

```
Action #1: Page Load (home)
Action #2: Search (dart)
Action #3: Click (product)
Action #4: Cart (add)
```

Each action is numbered in sequence. The index resets per stream.

---

## 5. Step by step — Analytics Tap (scenario 3)

tap collects analytics events:

```
page_view → added to analyticsEvents list
product_view → added
add_to_cart → added
checkout_start → added
→ 4 events in 2.3s
```

Analytics are collected transparently. The data flows through unchanged.

---

## 6. Step by step — Multiple Taps (scenario 4)

Multiple taps for different concerns:

```
Order Placed: #ORD-1234
  → Tap 1: LOG → 📝 ORDER_PLACED: #ORD-1234
  → Tap 2: ANALYTICS → 📊 order_created
  → Tap 3: PERFORMANCE → ⏱️ Order processing: 145ms
  → Tap 4: AUDIT → 🔍 ORDER_AUDIT: #ORD-1234
  → Observer: User Order Placed: #ORD-1234
```

Each tap handles one concern. The data passes through all taps unchanged.

---

## 7. Step by step — Tap with State (scenario 5)

tapState maintains running totals:

```
View: Product A → {views: 1, products: {A}, last: Product A}
View: Product B → {views: 2, products: {A, B}, last: Product B}
View: Product C → {views: 3, products: {A, B, C}, last: Product C}
```

State is maintained between taps. Each tap updates the state and emits the new state.

---

## 8. Step by step — Performance Monitoring (scenario 6)

Tap for performance timing:

```
User Login → start timing
  → processing (333ms)
    → complete timing → Total duration: 333ms
```

The tap captures timestamps. Performance metrics are collected without affecting the data.

---

## 9. Step by step — A/B Testing (scenario 7)

Tap for A/B testing:

```
variant_a:checkout_start → A: 1 event
variant_b:checkout_start → B: 1 event
variant_a:conversion → A: 1 conversion
variant_b:checkout_start → B: 2 events
→ Conversion rate: A=50%, B=0%
```

Metrics are collected per variant. The data flows through unchanged.

---

## 10. Step by step — Error Tracking (scenario 8)

Tap with filter for success/error tracking:

```
valid_order → successTap → successCount: 1
error_order → errorTap → errorCount: 1
valid_order → successTap → successCount: 2
→ Success: 2, Error: 1
```

Separate taps for success and error paths. Filters route the data to the correct tap.

---

## 11. Step by step — Real-Time Dashboard (scenario 9)

Tap for dashboard metrics:

```
user_login → activeUsers: 1
product_view → metrics[product_view]: 1
add_to_cart → metrics[add_to_cart]: 1
checkout → metrics[checkout]: 1
conversion → conversions: 1
→ Active: 1, Conversions: 1
```

Dashboard metrics are updated in real-time. The data flows through unchanged.

---

## 12. Step by step — Tap All (scenario 10)

tapAll sees every pulse:

```
Hello, World! → DEBUG: type=null, payload=Hello, World!, priority=20
42 → DEBUG: type=null, payload=42, priority=20
{key: value} → DEBUG: type=null, payload={key: value}, priority=20
```

tapAll receives the full pulse, including type and priority. Perfect for debugging.

---

## 13. Tap Types

| Tap Type | Purpose | When to Use |
|---|---|---|
| **tap** | Simple side effect | Logging, analytics |
| **tapWithIndex** | Position tracking | Session, sequence |
| **tapState** | State maintenance | Running totals, aggregation |
| **tapAll** | Full pulse access | Debugging, monitoring |

---

## 14. Parts checklist

| Kind | Instances |
|---|---|
| Cell | `actionInput`, `sessionInput`, `analyticsInput`, `orderInput`, `shopInput`, `perfInput`, `abInput`, `errorInput`, `dashboardInput`, `debugInput` |
| FlowInstruction | tap, tapWithIndex, tapState, tapAll, map, filter |
| FlowHandle | one per pipeline |
| Observer | one per output cell |

---

## 15. Rules for combining them

1. **Tap injects side effects. Cell carries data. Observer displays results.**
2. **Tap does not modify the data.**
3. **Multiple taps can be chained for different concerns.**
4. **TapState maintains state across taps.**
5. **TapWithIndex provides position information.**
6. **TapAll sees every pulse (including type mismatches).**
7. **Use tap for: logging, analytics, metrics, debugging, A/B testing.**
8. **Non-invasive - zero impact on the actual pipeline.**

---

## 16. Common Use Cases

| Use Case | Tap Pattern |
|---|---|
| User action logging | tap |
| Analytics tracking | tap |
| Performance monitoring | tap (timing) |
| A/B testing | tap (metrics per variant) |
| Error tracking | tap (success/error counts) |
| Dashboard updates | tap (real-time metrics) |
| Debugging | tapAll |
| Session tracking | tapWithIndex |
| Running totals | tapState |

---

## Still demo-only

All taps are synchronous. Real-world taps may write to databases, send network requests, or perform async operations. Performance considerations apply to high-frequency events.

---

## Summary table

| Scenario | Flow does | Cell does | Observer does |
|---|---|---|---|
| 1 Basic | tap logs actions | Carries strings | Displays results |
| 2 Index | tapWithIndex tracks position | Carries strings | Displays session |
| 3 Analytics | tap collects metrics | Carries strings | Displays metrics |
| 4 Multiple | 4 taps for 4 concerns | Carries orders | Displays order |
| 5 State | tapState maintains totals | Carries products | Displays stats |
| 6 Performance | tap for timing | Carries actions | Displays duration |
| 7 A/B | tap tracks variants | Carries variants | Displays conversion |
| 8 Error | tap tracks success/error | Carries orders | Displays counts |
| 9 Dashboard | tap updates metrics | Carries events | Displays dashboard |
| 10 Debug | tapAll sees full pulse | Carries objects | Displays pulse info |