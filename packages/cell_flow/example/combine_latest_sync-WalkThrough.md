# Walkthrough — CombineLatest Real-Time Data Sync

**Demo:** `example\combine_latest_sync_demo.dart`

One reactive engine. Eight real-time scenarios in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **CombineLatestWith** | `Flow.combineLatestWith` + combine | Combine multiple sources, emit on any change |
| **Filter** | `Flow.filter` | Filter stock symbols |
| **FromStream** | `Flow.fromStream` | Bridge stock simulator stream |
| **Map** | `Flow.map` | Transform chat messages to metrics |

CombineLatest emits when ANY source changes. All sources must have at least one value before the first emission.

---

## Contents

1. [Why combineLatest matters](#1-why-combinelatest-matters)
2. [Design (tagged)](#2-design-tagged)
3. [Step by step — basic combine (scenario 1)](#3-step-by-step--basic-combine-scenario-1)
4. [Step by step — dashboard metrics (scenario 2)](#4-step-by-step--dashboard-metrics-scenario-2)
5. [Step by step — form validation (scenario 3)](#5-step-by-step--form-validation-scenario-3)
6. [Step by step — portfolio aggregation (scenario 4)](#6-step-by-step--portfolio-aggregation-scenario-4)
7. [Step by step — health monitor (scenario 5)](#7-step-by-step--health-monitor-scenario-5)
8. [Step by step — search with filters (scenario 6)](#8-step-by-step--search-with-filters-scenario-6)
9. [Step by step — user preferences (scenario 7)](#9-step-by-step--user-preferences-scenario-7)
10. [Step by step — chat aggregation (scenario 8)](#10-step-by-step--chat-aggregation-scenario-8)
11. [combineLatest vs other combine operators](#11-combinelatest-vs-other-combine-operators)
12. [Rules for using combineLatest](#12-rules-for-using-combinelatest)
13. [Still demo-only](#still-demo-only)
14. [Production shape](#production-shape)

---

## 1. Why combineLatest matters

Multiple data sources update independently. You need the latest values from all sources combined into a single state. CombineLatest waits for all sources to have a value, then emits whenever any source updates.

The demo's rule:

```
CombineLatest:        all sources have value → emit on ANY change
```

---

## 2. Design (tagged)

**[Cell]** holds each data source. **[Flow.combineLatestWith]** combines the latest values. Each scenario demonstrates a different real-time use case.

```
┌─────────────────────────────────────────────────────────────┐
│                    DATA SOURCES                            │
│                                                           │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐     │
│  │ Source A│  │ Source B│  │ Source C│  │ Source D│     │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘     │
│       │            │            │            │           │
│       └────────────┼────────────┼────────────┘           │
│                    ▼            ▼                         │
│              ┌─────────────────────────┐                  │
│              │  combineLatestWith      │                  │
│              │  (combine function)     │                  │
│              └───────────┬─────────────┘                  │
│                          ▼                               │
│              ┌─────────────────────────┐                  │
│              │     Output Cell         │                  │
│              └─────────────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
              ┌─────────────────────────┐
              │      Cell.observe       │
              └─────────────────────────┘
```

| You need | You use |
|---|---|
| Combine multiple metrics | `combineLatestWith` |
| Filter stock symbols | `Filter` |
| Bridge external streams | `FromStream` |
| Transform messages | `Map` |
| State aggregation | `Cell.state` |

---

## 3. Step by step — basic combine (scenario 1)

**0. Graph**  
`sourceA`: ingress cell (int).  
`sourceB`: ingress cell (String).  
`combineLatestWith`: combines A and B into a string.

**1. Arming**  
`sourceA.emit(10)` → sourceA has value, sourceB has none → no emission.  
`sourceB.emit('hello')` → both have values → emission: `A: 10, B: hello`.

**2. Updates**  
`sourceA.emit(20)` → sourceA changes → emission: `A: 20, B: hello`.  
`sourceB.emit('world')` → sourceB changes → emission: `A: 20, B: world`.

```
time →
┌─────────────────────────────────────────────────────────────┐
│ A: 10    │    A: 20    │    A: 30                        │
│ B: ────  │    B: hello │    B: world                    │
│          │             │                                 │
│ No emit  │  A:10,B:hello│  A:20,B:hello  A:20,B:world   │
└─────────────────────────────────────────────────────────────┘
```

**Key insight:** The first emission only happens when ALL sources have a value.

---

## 4. Step by step — dashboard metrics (scenario 2)

**0. Graph**  
Four metric sources: users, requests, response, errors.  
`combineLatestWith`: combines all four into a dashboard state map.

**1. Sources update independently**  
`usersMetric.emit(1234)` → no emission (others missing).  
`requestsMetric.emit(45.6)` → no emission (others missing).  
`responseMetric.emit(23)` → no emission (others missing).  
`errorsMetric.emit(1.2)` → all sources have values → emission!

**2. Any update triggers**  
`usersMetric.emit(1235)` → users changes → dashboard updates.

```
┌─────────────────────────────────────────────────────────────┐
│ 📊 Dashboard State:                                       │
│ - Users: 1,234                                            │
│ - Requests: 45.6/s                                        │
│ - Response: 23ms                                          │
│ - Errors: 1.2%                                            │
│ [Update] Dashboard refreshed                              │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Real-time dashboards update automatically when any metric changes.

---

## 5. Step by step — form validation (scenario 3)

**0. Graph**  
Three form fields: email, password, confirm.  
`combineLatestWith`: validates all fields and emits form state.

**1. Field updates**  
`emailInput.emit('test@example.com')` → valid email.  
`passwordInput.emit('pass123')` → valid password (length >= 6).  
`confirmInput.emit('pass123')` → passwords match.  
All fields valid → form is VALID.

**2. Partial updates**  
`emailInput.emit('invalid')` → email invalid → form INVALID.  
`emailInput.emit('test@example.com')` → email valid → form VALID.

```
┌─────────────────────────────────────────────────────────────┐
│ [Form] Email: 'test@example.com' ✅ Valid                 │
│ [Form] Password: '*******' ✅ Valid                       │
│ [Form] Confirm: '*******' ✅ Valid                        │
│ [Form] Form is VALID and ready to submit                  │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Form validation reacts to any field change, providing immediate feedback.

---

## 6. Step by step — portfolio aggregation (scenario 4)

**0. Graph**  
Stock simulator → filtered streams for AAPL, GOOGL, TSLA.  
`combineLatestWith`: combines latest prices into portfolio value.

**1. Stock updates**  
Each stock updates independently every 2 seconds.  
When ANY stock changes, the portfolio recomputes.

**2. Calculation**  
Total value = sum of all stock prices.  
Average change = mean of individual changes.

```
┌─────────────────────────────────────────────────────────────┐
│ 📈 Portfolio Value: $1,234.56                             │
│ - AAPL: $150.25 (2.3% ↗)                                 │
│ - GOOGL: $2,800.50 (1.2% ↗)                              │
│ - TSLA: $700.75 (0.5% ↘)                                 │
│ Portfolio updated at 12:34:56                            │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Portfolios update in real-time as stock prices change.

---

## 7. Step by step — health monitor (scenario 5)

**0. Graph**  
Four health metrics: CPU, Memory, Disk, Network.  
`combineLatestWith`: combines into system health status with alerts.

**1. Metric updates**  
Each component has status: healthy, warning, or critical.  
When ANY component changes, health status recomputes.

**2. Alert generation**  
Warning thresholds trigger alerts.  
Critical thresholds trigger emergency alerts.

```
┌─────────────────────────────────────────────────────────────┐
│ 🏥 System Health: ⚠️ WARNING                              │
│ - CPU: 45.2% ✅                                           │
│ - Memory: 62.8% ✅                                        │
│ - Disk: 78.5% ⚠️                                          │
│ - Network: 234 Mbps ✅                                    │
│ [Alert] Disk usage approaching limit                      │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** System monitoring reacts to any component change, alerting immediately.

---

## 8. Step by step — search with filters (scenario 6)

**0. Graph**  
Three search parameters: text, type, sort.  
`combineLatestWith`: combines into search query with results.

**1. Parameter updates**  
`searchText.emit('dart')` → query updated.  
`searchType.emit('book')` → type updated.  
`searchSort.emit('relevance')` → sort updated.  
Each update triggers a new search result emission.

```
┌─────────────────────────────────────────────────────────────┐
│ 🔍 Search: "dart"                                         │
│ Filters: [type: book, sort: relevance]                    │
│ Results: 42 items found                                   │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Search results update reactively as any filter changes.

---

## 9. Step by step — user preferences (scenario 7)

**0. Graph**  
Four preference sources: email, theme, language, notifications.  
`combineLatestWith`: combines into user preferences state.

**1. Preference updates**  
`userEmail.emit('alice@example.com')` → email set.  
`userTheme.emit('dark')` → theme set.  
`userLanguage.emit('en-US')` → language set.  
`userNotifications.emit(true)` → notifications on.  
All sources have values → preferences sync.

```
┌─────────────────────────────────────────────────────────────┐
│ User: alice@example.com                                   │
│ Theme: dark                                               │
│ Language: en-US                                           │
│ Notifications: on                                         │
│ Preferences saved at 12:34:56                            │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** User settings sync across devices in real-time.

---

## 10. Step by step — chat aggregation (scenario 8)

**0. Graph**  
Chat stream → Map transforms messages to metrics.  
`Cell.state` cells track: message count, active users, unread count, last message.

**1. Chat messages arrive**  
Each new message updates all metrics.  
Active users set tracks unique users.  
Unread count increments for unread messages.

**2. Aggregated output**  
All metrics combined into a chat summary.

```
┌─────────────────────────────────────────────────────────────┐
│ 💬 Chat Summary:                                          │
│ - Total Messages: 1,234                                  │
│ - Active Users: 56                                        │
│ - Unread: 12                                              │
│ - Last Message: "Hello everyone!"                        │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Chat metrics update in real-time as messages arrive.

---

## 11. combineLatest vs other combine operators

| Operator | Emits When | Use Case |
|----------|------------|----------|
| `combineLatestWith` | ANY source changes | Real-time dashboards |
| `withLatestFrom` | Source changes only | Commands with latest state |
| `zipWith` | ALL sources have next value | Paired data, request/response |
| `mergeWith` | ANY source emits | Event interleaving |
| `race` | First source emits | Fastest response |

**Key difference:** combineLatest emits the latest values from all sources. zip pairs values by index. merge interleaves events.

---

## 12. Rules for using combineLatest

1. **All sources must have a value.** No emission until every source has at least one value.
2. **Any source update triggers emission.** The combine function runs on every change.
3. **Keep combine functions pure.** No side effects — transformations only.
4. **Use type-safe combine functions.** Generic parameters ensure compile-time safety.
5. **Combine independent sources.** combineLatest is for sources that update independently.
6. **Use withLatestFrom for source-driven updates.** When you only want to emit on source changes.
7. **Use zip for index-based pairing.** When you need to pair values by position.
8. **Monitor source count.** More sources = more emissions = more computation.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Operator                    │  When to use                          │
├─────────────────────────────────────────────────────────────────────────┤
│  combineLatestWith          │  Real-time dashboards, form validation │
│  withLatestFrom             │  Commands with state, user actions     │
│  zipWith                    │  Paired data, request/response         │
│  mergeWith                  │  Event interleaving                    │
│  race                       │  Fastest response, redundancy          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Still demo-only

Stock simulator uses random data — not real market data.  
Chat simulator generates random messages — no real users.  
Health metrics are simulated — not actual system metrics.  
No persistence — all data is in-memory only.  
No error handling — all sources are assumed to emit values.

---

## Production shape

| Piece | Demo | Production |
|---|---|---|
| Source | `Cell.ingress` / `FromStream` | WebSocket / SSE / API polling |
| Combine | `combineLatestWith` | Real-time aggregation |
| Validation | `combineLatestWith` + regex | Server-side validation |
| Portfolio | `combineLatestWith` + calculation | Real-time market data |
| Health | `combineLatestWith` + thresholds | Monitoring + alerting |
| Search | `combineLatestWith` + debounce | Search API with filters |
| Preferences | `combineLatestWith` + state | Sync + persistence |
| Chat | `combineLatestWith` + metrics | Real-time analytics |