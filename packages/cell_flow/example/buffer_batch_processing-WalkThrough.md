# Walkthrough — Buffer Batch Processing

**Demo:** `example\buffer_batch_processing_demo.dart`

One event firehose. Five buffer strategies in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **BufferCount** | `Flow.bufferCount` + size | Batch by fixed count |
| **BufferTime** | `Flow.bufferTime` + duration | Batch by time window |
| **BufferWithTimeAndCount** | `Flow.bufferWithTimeAndCount` | Batch by size OR time |
| **BufferWithPredicate** | `Flow.bufferWithPredicate` + test | Batch when condition met |
| **BufferWhen** | `Flow.bufferWhen` + closer | Batch on external trigger |

Buffer collects events into lists. The five strategies control **when** and **how** the buffer is flushed.

---

## Contents

1. [Why buffer matters](#1-why-buffer-matters)
2. [Design (tagged)](#2-design-tagged)
3. [Step by step — count-based batching (scenario 1)](#3-step-by-step--count-based-batching-scenario-1)
4. [Step by step — time-based batching (scenario 2)](#4-step-by-step--time-based-batching-scenario-2)
5. [Step by step — time or count (scenario 3)](#5-step-by-step--time-or-count-scenario-3)
6. [Step by step — conditional batching (scenario 4)](#6-step-by-step--conditional-batching-scenario-4)
7. [Step by step — external trigger (scenario 5)](#7-step-by-step--external-trigger-scenario-5)
8. [Real-world: log batching (scenario 6)](#8-real-world-log-batching-scenario-6)
9. [Real-world: sensor data batching (scenario 7)](#9-real-world-sensor-data-batching-scenario-7)
10. [Performance: firehose to batches (scenario 9)](#10-performance-firehose-to-batches-scenario-9)
11. [Buffer strategy comparison](#11-buffer-strategy-comparison)
12. [Rules for combining them](#12-rules-for-combining-them)
13. [Still demo-only](#still-demo-only)
14. [Production shape](#production-shape)

---

## 1. Why buffer matters

Events arrive as individual pulses. Processing each event separately is expensive. Batching groups events into lists for processing once per batch.

The demo's rule:

```
BufferCount:        fixed size → flush when full
BufferTime:         fixed time → flush on schedule
BufferWithTimeAndCount: size OR time → flush on first trigger
BufferWithPredicate: condition → flush when condition met
BufferWhen:         external trigger → flush on signal
```

---

## 2. Design (tagged)

**[Cell]** holds the input stream. **[Flow.buffer]** collects events into lists. Each variant controls the flush trigger.

```
Event stream (firehose)
     │
     ▼
[Cell] ingress<T>                        INPUT
     │  emit (thousands of events)
     ▼
┌─────────────────────────────────────────────────────────────┐
│                    FLOW.buffer*                           │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ BufferCount        → size    → flush when full    │  │
│  │ BufferTime         → time    → flush on schedule  │  │
│  │ BufferWithTimeAndCount → both → first wins        │  │
│  │ BufferWithPredicate → test   → flush on condition │  │
│  │ BufferWhen         → trigger → flush on signal    │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
└─────────────────────────────────────────────────────────────┘
     │
     ▼
[Cell] output cell                                     BATCH
     │  Cell.observe
     ▼
 processor / UI
```

| You need | You use |
|---|---|
| Fixed-size batches | `BufferCount` |
| Time-based batches | `BufferTime` |
| Either size or time | `BufferWithTimeAndCount` |
| Conditional batching | `BufferWithPredicate` |
| Manual / external trigger | `BufferWhen` |
| Real-time logs | `BufferCount` + processor |
| Sensor data | `BufferCount` + aggregation |

---

## 3. Step by step — count-based batching (scenario 1)

**0. Graph**  
`countInput`: ingress cell.  
`BufferCount(3)`: collects events until buffer has 3 items.  
`Cell.observe`: prints each batch.

**1. Pulse (Cell)**  
`countInput.emit(1)` → buffer = [1] (size 1/3).  
`countInput.emit(2)` → buffer = [1, 2] (size 2/3).  
`countInput.emit(3)` → buffer = [1, 2, 3] (size 3/3) → flush!

**2. Buffer (Flow)**  
Buffer is emitted as a list: `[1, 2, 3]`.  
Buffer is cleared.  
Next event starts a new buffer.

**3. Output**  
Batches of exactly 3 items: `[1,2,3]`, `[4,5,6]`.

```
time →
┌─────────────────────────────────────────────────────────────┐
│ Event 1  Event 2  Event 3  Event 4  Event 5  Event 6      │
│   │        │        │        │        │        │          │
│   └────────┴────────┘        └────────┴────────┘          │
│        Batch [1,2,3]             Batch [4,5,6]            │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Step by step — time-based batching (scenario 2)

**0. Graph**  
`timeInput`: ingress cell.  
`BufferTime(500ms)`: collects events into time windows.  
`Cell.observe`: prints each batch with timestamp.

**1. Timer starts**  
`timeInput.emit('A')` at 0ms → buffer starts, timer begins.  
`timeInput.emit('B')` at 100ms → added to buffer.  
`timeInput.emit('C')` at 200ms → added to buffer.

**2. Timer fires**  
At 500ms, timer fires → flush buffer = `[A, B, C]`.  
Buffer cleared. Timer resets.

**3. Next window**  
`timeInput.emit('D')` at 600ms → new buffer starts.  
`timeInput.emit('E')` at 700ms → added to buffer.  
At 1000ms, timer fires → flush buffer = `[D, E]`.

```
time →
0ms    100ms   200ms   300ms   400ms   500ms   600ms   700ms   800ms   900ms   1000ms
│       │       │       │       │       │       │       │       │       │       │
A       B       C                               D       E
└───────┴───────┘                               └───────┘
     Batch [A,B,C]                                  Batch [D,E]
```

---

## 5. Step by step — time or count (scenario 3)

**0. Graph**  
`comboInput`: ingress cell.  
`BufferWithTimeAndCount(duration: 500ms, count: 3)`: flushes when either condition is met.

**1. Count wins**  
`comboInput.emit(1)` at 0ms → buffer = [1].  
`comboInput.emit(2)` at 100ms → buffer = [1, 2].  
`comboInput.emit(3)` at 200ms → buffer = [1, 2, 3] (count=3) → flush!  
Count triggered before time window.

**2. Time wins**  
`comboInput.emit(4)` at 300ms → buffer = [4].  
Timer continues. At 500ms, time window expires → flush `[4]`.  
Time triggered (count not reached).

```
time →
0ms    100ms   200ms   300ms   400ms   500ms
│       │       │       │       │       │
1       2       3       4
└───────┴───────┘       └───────┘
  count wins (3)          time wins (500ms)
```

---

## 6. Step by step — conditional batching (scenario 4)

**0. Graph**  
`predInput`: ingress cell.  
`BufferWithPredicate((value) => value.isEven)`: flushes when an even number arrives.

**1. Buffering**  
`predInput.emit(1)` → buffer = [1] (odd, no flush).  
`predInput.emit(2)` → buffer = [1, 2] (even → flush!).  
Buffer emits `[1, 2]` and clears.

**2. Next flush**  
`predInput.emit(3)` → buffer = [3].  
`predInput.emit(4)` → buffer = [3, 4] (even → flush!).  
Buffer emits `[3, 4]`.

```
┌─────────────────────────────────────────────────────────────┐
│ Event:  1      2      3      4                           │
│         │      │      │      │                           │
│ Buffer: [1]    [1,2]  [3]    [3,4]                      │
│                │             │                           │
│ Flush:         [1,2]         [3,4]                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Step by step — external trigger (scenario 5)

**0. Graph**  
`whenInput`: ingress cell for events.  
`triggerInput`: ingress cell for flush signal.  
`BufferWhen(triggerInput.cell)`: flushes when trigger pulses.

**1. Buffering**  
`whenInput.emit('a')` → buffer = ['a'].  
`whenInput.emit('b')` → buffer = ['a', 'b'].

**2. Trigger**  
`triggerInput.emit(null)` at 300ms → flush! Buffer emits `['a', 'b']` and clears.

**3. Continue**  
`whenInput.emit('c')` → buffer = ['c'].  
`whenInput.emit('d')` → buffer = ['c', 'd'].  
`triggerInput.emit(null)` at 600ms → flush! Buffer emits `['c', 'd']`.

```
time →
0ms    100ms   200ms   300ms   400ms   500ms   600ms
│       │       │       │       │       │       │
a       b               trigger c       d       trigger
└───────┴───────┘       └───────┴───────┘
  flush [a,b]              flush [c,d]
```

---

## 8. Real-world: log batching (scenario 6)

Logs arrive as individual events. Batching reduces I/O overhead.

**Without batching:** 6 log entries = 6 database writes.  
**With batching (size=3):** 6 log entries = 2 database writes.

```
App logs:
  User login (INFO)
  API request (INFO)     → Batch 1: 2 INFO, 1 WARN, 1 ERROR
  Database query (WARN)
  File upload (ERROR)    → Batch 1 flushed
  Cache hit (INFO)
  Cache miss (INFO)      → Batch 2: 2 INFO
```

**Speedup:** Processing once per batch instead of per event.

---

## 9. Real-world: sensor data batching (scenario 7)

Sensor readings arrive as individual readings. Batching allows aggregation.

```
Sensor readings:
  Sensor-1: 23.5°C
  Sensor-2: 45.2%       → Batch of 5
  Sensor-3: 1013.2hPa   → Aggregated: Avg 23.2°C, 45.0%, 1013.2hPa
  Sensor-4: 22.8°C
  Sensor-5: 44.7%
```

**Why this matters:** One batch processing computes averages once instead of per-reading.

---

## 10. Performance: firehose to batches (scenario 9)

1000 events. Batch size = 100.

| Metric | Without Batching | With Batching |
|--------|------------------|---------------|
| Processing calls | 1000 | 10 |
| Time | ~1234ms | ~45ms |
| Speedup | 1.0x | 27.4x |

**Why batching is faster:** Processing overhead is per-batch, not per-event. Batch size controls the trade-off between latency (smaller batches) and throughput (larger batches).

---

## 11. Buffer strategy comparison

| Strategy | Trigger | Memory | Latency | Use Case |
|----------|---------|--------|---------|----------|
| `BufferCount` | Size | Fixed | Low (full) | Fixed-size batches |
| `BufferTime` | Time | Variable | High (window) | Time-based batches |
| `BufferWithTimeAndCount` | Size OR time | Fixed | Low | Either condition |
| `BufferWithPredicate` | Condition | Variable | Low (condition) | Conditional batching |
| `BufferWhen` | External | Variable | Manual | Manual batching |

---

## 12. Rules for combining them

1. **Use `BufferCount` when you need fixed-size batches.** Predictable memory usage.
2. **Use `BufferTime` when you need timely processing.** Guarantees flush within time window.
3. **Use `BufferWithTimeAndCount` when you need both.** Whichever comes first.
4. **Use `BufferWithPredicate` for business rules.** Flush on condition.
5. **Use `BufferWhen` for manual control.** Flush on external signal.
6. **Monitor batch size.** Too large → memory pressure. Too small → overhead.
7. **Choose based on latency vs throughput.** Smaller batches = lower latency. Larger batches = higher throughput.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Strategy                    │  When to use                          │
├─────────────────────────────────────────────────────────────────────────┤
│  BufferCount                │  Fixed-size batches, logs, metrics     │
│  BufferTime                 │  Time-based, real-time dashboards      │
│  BufferWithTimeAndCount     │  Both constraints, maximum flexibility │
│  BufferWithPredicate        │  Business rules, validation            │
│  BufferWhen                 │  Manual control, user-triggered        │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Still demo-only

Events are simulated with `Future.delayed`. No real network I/O.  
Performance measurements are approximate (host scheduling affects timing).  
No backpressure handling — the firehose is pre-generated.  
No persistence — batches are in-memory only.

---

## Production shape

| Piece | Demo | Production |
|---|---|---|
| Input | `Cell.ingress` | Event stream / Kafka / WebSocket |
| Count | `BufferCount(3)` | Configurable batch size (e.g., 1000) |
| Time | `BufferTime(500ms)` | Configurable time window (e.g., 5s) |
| Condition | `BufferWithPredicate` | Business rules (e.g., flush on error) |
| Trigger | `BufferWhen` | User action / system event |
| Processor | `MapValue` | Database write / API call / Analytics |
| Metrics | `BatchMetrics` | Monitoring / Alerting |