# Walkthrough — Distinct Noise Reduction

**Demo:** `example\distinct_noise_reduction_demo.dart`

One source cell. Seven distinct strategies in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **Distinct** | `Flow.distinct` + consecutive | Remove consecutive duplicates |
| **Filter with state** | `Flow.filter` + custom comparator | Custom equality (sensor tolerance) |
| **Windowed Distinct** | `Flow.filter` + time window | Time-based deduplication |
| **Key Selector** | `Flow.filter` + state | Distinct by specific field |
| **Debounce + Distinct** | `Flow.debounce` + `Flow.distinct` | Silence then deduplicate |

Distinct removes consecutive duplicates. Filter with state implements custom equality. Windowed distinct filters duplicates within a time window.

---

## 1. Why distinct matters

Sensors emit noisy data — repeated values, jitter, fluctuations. Processing every reading is expensive and noisy. Distinct filters out consecutive duplicates, reducing noise and processing load.

The demo's rule:

```
Distinct:        consecutive duplicates → drop
Filter + state:  custom equality → keep only meaningful changes
Windowed:        time-based → drop duplicates within window
Key selector:   by field → keep first occurrence of each key
```

---

## 2. Design (tagged)

**[Cell]** holds the input stream. **[Flow.distinct]** removes consecutive duplicates. **[Flow.filter]** with state implements custom equality.

```
┌─────────────────────────────────────────────────────────────┐
│                    DATA SOURCE                            │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Raw: [1, 1, 2, 2, 2, 3, 1, 1, 1, 4, 4]           │  │
│  └─────────────────────────────────────────────────────┘  │
│                          │                               │
│                          ▼                               │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Flow.distinct                         │  │
│  │  ┌─────────────────────────────────────────────┐   │  │
│  │  │ Compares each value to previous            │   │  │
│  │  │ Drops if same, emits if different          │   │  │
│  │  └─────────────────────────────────────────────┘   │  │
│  └─────────────────────────────────────────────────────┘  │
│                          │                               │
│                          ▼                               │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Filtered: [1, 2, 3, 1, 4]                         │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

| You need | You use |
|---|---|
| Remove consecutive duplicates | `Flow.distinct` |
| Custom equality (tolerance) | `Flow.filter` + state |
| Time-based deduplication | `Flow.filter` + time window |
| Distinct by field | `Flow.filter` + key state |
| Silence then deduplicate | `Flow.debounce` + `Flow.distinct` |

---

## 3. Step by step — basic distinct (scenario 1)

**0. Graph**  
`input`: ingress cell.  
`Flow.distinct<int>`: keeps only values that differ from the previous emission.  
`Cell.observe`: prints filtered results.

**1. Raw data**  
`[1, 1, 2, 2, 2, 3, 1, 1, 1, 4, 4]`

**2. Distinct processing**
```
1 → emits (first)
1 → duplicate → drop
2 → emits (different)
2 → duplicate → drop
2 → duplicate → drop
3 → emits (different)
1 → emits (different — 3 then 1)
1 → duplicate → drop
1 → duplicate → drop
4 → emits (different)
4 → duplicate → drop
```

**3. Output**  
`[1, 2, 3, 1, 4]` — 54.5% noise reduction.

```
Raw:     1  1  2  2  2  3  1  1  1  4  4
        │  │  │  │  │  │  │  │  │  │  │
Distinct:1    2       3  1          4
        └──┘  └──┘    └──┘          └──┘
        54.5% reduction
```

**Key insight:** Distinct only filters consecutive duplicates. `1` appears twice because it's separated by other values.

---

## 4. Step by step — custom equality (scenario 2)

**0. Graph**  
`sensorInput`: ingress cell.  
`Flow.filter<double>`: custom test with tolerance of 0.2.  
`Cell.observe`: prints filtered results.

**1. Raw data**  
`[10.0, 10.05, 10.1, 10.15, 10.2, 50.0, 50.05, 50.1]`

**2. Tolerance processing**
```
10.0 → last=null → emit (10.0)
10.05 → diff=0.05 < 0.2 → drop
10.1 → diff=0.1 < 0.2 → drop
10.15 → diff=0.15 < 0.2 → drop
10.2 → diff=0.2 >= 0.2 → emit (10.2), last=10.2
50.0 → diff=29.8 >= 0.2 → emit (50.0), last=50.0
50.05 → diff=0.05 < 0.2 → drop
50.1 → diff=0.1 < 0.2 → drop
```

**3. Output**  
`[10.0, 10.2, 50.0, 50.1]` — 50% noise reduction.

```
Raw:     10.0  10.05  10.1  10.15  10.2  50.0  50.05  50.1
         │     │     │     │     │     │     │     │
Filtered:10.0                      10.2  50.0        50.1
         └─────────────────────────┘    └─────────────┘
         tolerance=0.2                 tolerance=0.2
```

**Why this matters:** Sensor readings with small jitter are filtered out. Only meaningful changes are kept.

---

## 5. Step by step — GPS tracking (scenario 3)

**0. Graph**  
`gpsInput`: ingress cell with `(double, double)` coordinates.  
`Flow.filter<(double, double)>`: custom test for significant movement (> 0.0005 degrees).  
`Cell.observe`: prints significant position changes.

**1. Raw GPS data**  
Coordinates with jitter:
```
(37.7749, -122.4194) → initial
(37.7749, -122.4194) → same (noise)
(37.7750, -122.4195) → slight movement (< threshold)
(37.7750, -122.4195) → same (noise)
(37.7751, -122.4196) → slight movement (< threshold)
(37.7751, -122.4196) → same (noise)
(37.7752, -122.4198) → significant movement (> threshold)
(37.7752, -122.4198) → same (noise)
(37.7752, -122.4198) → same (noise)
```

**2. GPS filtering**
```
Initial: emit
Same: drop
Slight movement: drop (< 0.0005)
Same: drop
Slight movement: drop (< 0.0005)
Same: drop
Significant movement: emit (> 0.0005)
Same: drop
Same: drop
```

**3. Output**  
`[(37.7749, -122.4194), (37.7752, -122.4198)]` — 2 significant position changes.

```
┌─────────────────────────────────────────────────────────────┐
│ Raw GPS: 9 readings                                       │
│ Filtered GPS: 2 readings                                  │
│ Movement detected: 2 significant position changes         │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** GPS jitter is filtered out. Only actual movement is detected.

---

## 6. Step by step — stock ticker (scenario 4)

**0. Graph**  
`stockInput`: ingress cell with double prices.  
`Flow.distinct<double>`: removes consecutive duplicate prices.  
`Cell.observe`: prints price changes.

**1. Raw data**  
`[100.0, 100.0, 100.0, 100.1, 100.1, 100.1, 100.2]`

**2. Distinct processing**
```
100.0 → emits (first)
100.0 → duplicate → drop
100.0 → duplicate → drop
100.1 → emits (changed)
100.1 → duplicate → drop
100.1 → duplicate → drop
100.2 → emits (changed)
```

**3. Output**  
`[100.0, 100.1, 100.2]` — 3 updates vs 7 raw events, 57.1% bandwidth saved.

```
Raw:     100.0  100.0  100.0  100.1  100.1  100.1  100.2
         │     │     │     │     │     │     │     │
Distinct:100.0              100.1              100.2
         └──────────────────┘    └─────────────┘
         57.1% bandwidth saved
```

**Why this matters:** UI updates only when price actually changes. No redundant re-renders.

---

## 7. Step by step — distinct vs other filters (scenario 5)

**0. Test data**  
`[1, 1, 2, 2, 3, 1, 2, 2, 3, 3]`

**1. Distinct (consecutive only)**  
`[1, 2, 3, 1, 2, 3]` — only back-to-back duplicates dropped.

**2. Unique (global)**  
`[1, 2, 3]` — all duplicates dropped, regardless of position.

**3. Filter (even only)**  
`[2, 2, 2, 2]` — only even numbers kept.

```
┌─────────────────────────────────────────────────────────────┐
│ Raw:     [1, 1, 2, 2, 3, 1, 2, 2, 3, 3]                 │
│ Distinct: [1, 2, 3, 1, 2, 3]  ← consecutive only        │
│ Unique:   [1, 2, 3]           ← global dedupe            │
│ Filter:   [2, 2, 2, 2]        ← predicate only           │
└─────────────────────────────────────────────────────────────┘
```

**Key insight:** Distinct is for consecutive duplicates. Unique is for all duplicates. Filter is for predicate-based filtering.

---

## 8. Step by step — windowed distinct (scenario 6)

**0. Graph**  
`windowInput`: ingress cell.  
`Flow.filter<int>`: custom sliding window (500ms) for time-based deduplication.  
`Cell.observe`: prints windowed results.

**1. Raw data**  
`[1, 2, 2, 3, 1, 2, 2, 3]` (emitted with 200ms intervals)

**2. Windowed processing (500ms)**
```
1 at 0ms → emit (window: [1])
2 at 200ms → emit (window: [1,2])
2 at 400ms → duplicate in window → drop
3 at 600ms → 1 expired → emit (window: [2,3])
1 at 800ms → 2 expired → emit (window: [3,1])
2 at 1000ms → 3 expired → emit (window: [1,2])
2 at 1200ms → duplicate in window → drop
3 at 1400ms → 1 expired → emit (window: [2,3])
```

**3. Output**  
`[1, 2, 3, 1, 2, 3]` — duplicates only filtered within the 500ms window.

```
┌─────────────────────────────────────────────────────────────┐
│ Time: 0ms  200ms  400ms  600ms  800ms  1000ms  1200ms    │
│ Raw:   1     2     2     3     1     2      2      3     │
│                │     │           │     │      │     │     │
│ Window:1      2     (drop)     3     1     2     (drop) 3 │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Duplicates within a short time window are filtered. The same value can appear again after the window expires.

---

## 9. Step by step — key selector (scenario 7)

**0. Graph**  
`keyInput`: ingress cell with `Map<String, dynamic>`.  
`Flow.filter<Map<String, dynamic>>`: tracks seen IDs.  
`Cell.observe`: prints first occurrence of each ID.

**1. Raw data**
```
{id:1, value:10} → id=1, not seen → emit
{id:1, value:20} → id=1, seen → drop
{id:2, value:30} → id=2, not seen → emit
{id:2, value:40} → id=2, seen → drop
{id:3, value:50} → id=3, not seen → emit
```

**2. Output**  
`[{id:1, value:10}, {id:2, value:30}, {id:3, value:50}]` — only first occurrence of each ID.

```
┌─────────────────────────────────────────────────────────────┐
│ Raw:   {id:1,v:10}  {id:1,v:20}  {id:2,v:30}  {id:2,v:40}  {id:3,v:50} │
│        │             │             │             │             │          │
│ Key:   1             1             2             2             3          │
│        │             │             │             │             │          │
│ Emit:  ✓            ✗             ✓            ✗             ✓          │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Distinct by a specific field (e.g., user ID) ensures each entity is processed only once.

---

## 10. Step by step — user activity (scenario 8)

**0. Graph**  
`activityInput`: ingress cell with activity strings.  
`Flow.distinct<String>`: removes consecutive duplicate activities.  
`Cell.observe`: prints unique activity changes.

**1. Raw data**
```
view → emits
view → duplicate → drop
click → emits (changed)
scroll → emits (changed)
scroll → duplicate → drop
view → emits (changed)
click → emits (changed)
click → duplicate → drop
```

**2. Output**  
`[view, click, scroll, view, click]` — 5 unique activity changes vs 8 raw events.

```
Raw:     view  view  click  scroll  scroll  view  click  click
         │    │     │      │       │       │     │      │
Distinct:view       click  scroll          view  click
         └──┘       └───┘  └────┘        └───┘  └────┘
         5 changes vs 8 events
```

**Why this matters:** UI updates only when user activity actually changes. No redundant updates.

---

## 11. Step by step — debounce + distinct (scenario 9)

**0. Graph**  
`combinedInput`: ingress cell.  
`Flow.debounce(30ms)` → wait for silence.  
`Flow.distinct<String>` → remove consecutive duplicates.  
`Cell.observe`: prints final results.

**1. Raw data**
```
a, a, b, b, b, a, a, c, c (20ms intervals)
```

**2. Debounce (30ms)**  
Each burst is collapsed to the final value.

**3. Distinct**  
Consecutive duplicates from debounced output are removed.

**4. Output**  
`[a, b, a, c]`

```
┌─────────────────────────────────────────────────────────────┐
│ Raw:      a  a  b  b  b  a  a  c  c                     │
│           │  │  │  │  │  │  │  │  │                     │
│ Debounce: a     b        a     c                        │
│           │     │        │     │                        │
│ Distinct: a     b        a     c                        │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** Debounce first stabilizes the stream, then distinct removes any remaining duplicates.

---

## 12. Distinct vs other operators

| Operator | Removes | Memory | Use Case |
|----------|---------|--------|----------|
| `Distinct` | Consecutive duplicates | O(1) | Sensor noise, tickers |
| `DistinctAll` | Any duplicate | O(n) | Unique IDs, global dedupe |
| `Filter` | By predicate | O(1) | Validation, range checks |
| `Debounce` | By time | O(1) | Search, user input |
| `Throttle` | By frequency | O(1) | Rate limiting, scroll |
| `DistinctKey` | By key (global) | O(n) | First occurrence by ID |

---

## 13. Rules for using distinct

1. **Use `Distinct` for consecutive duplicates.** Sensor noise, stock tickers, user activity.
2. **Use `DistinctAll` for global deduplication.** Unique IDs, first occurrence.
3. **Use custom equality with `Filter` + state.** Tolerance bands, complex types.
4. **Use windowed distinct for time-based filtering.** GPS, sliding windows.
5. **Use key selector for field-based distinct.** First occurrence by ID.
6. **Combine with `Debounce` for user input.** Silence then deduplicate.
7. **Monitor memory for global distinct.** O(n) memory for `DistinctAll` and key selector.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Strategy                    │  When to use                          │
├─────────────────────────────────────────────────────────────────────────┤
│  Distinct                   │  Consecutive duplicates                │
│  DistinctAll                │  Global duplicates                     │
│  Custom equality (Filter)   │  Tolerance bands, complex types        │
│  Windowed distinct          │  Time-based deduplication              │
│  Key selector               │  Distinct by specific field            │
│  Debounce + Distinct        │  User input, search                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Still demo-only

Data is hardcoded — not real sensor data.  
GPS coordinates are simulated — not actual GPS.  
Stock prices are fixed — not real market data.  
Windowed distinct uses `DateTime.now()` — not actual timers.  
Performance metrics are approximate (host scheduling affects timing).

---

## Production shape

| Piece | Demo | Production |
|---|---|---|
| Sensor | Hardcoded array | Real sensor stream |
| GPS | Simulated coordinates | Actual GPS receiver |
| Stock | Fixed prices | Market data feed |
| Distinct | `Flow.distinct` | Configurable dedupe |
| Custom | `Flow.filter` + state | Tolerance from config |
| Windowed | `Flow.filter` + `DateTime.now()` | Event timestamps |
| Key | `Flow.filter` + Set | Cache with TTL |
| Performance | Synthetic | Real-world metrics |