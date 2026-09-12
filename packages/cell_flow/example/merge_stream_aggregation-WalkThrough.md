# Walkthrough — Stream Merging (Fan-In Pattern)

**Demo:** `example\merge_stream_aggregation_demo.dart`

One pipeline. Three layers in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **Cell** | ingress + observe + synthesis | What events are flowing; how they're aggregated |
| **Flow** | (used implicitly via observers) | Forward events from sources to shared bus |
| **Observer** | `Cell.observe` | Collect, aggregate, and display merged events |

Flow is minimal here — the fan-in pattern uses observers as the glue. Cell provides the ingress points and shared bus. The observer does the aggregation.

---

## Contents

1. [Why they have to combine](#1-why-they-have-to-combine)
2. [Design (tagged)](#2-design-tagged)
3. [Step by step — Fan-In Pattern (scenario 1)](#3-step-by-step--fan-in-pattern-scenario-1)
4. [Step by step — Real-Time Event Aggregation (scenario 2)](#4-step-by-step--real-time-event-aggregation-scenario-2)
5. [Step by step — Multi-Source Log Aggregation (scenario 3)](#5-step-by-step--multi-source-log-aggregation-scenario-3)
6. [Step by step — IoT Sensor Data Merge (scenario 4)](#6-step-by-step--iot-sensor-data-merge-scenario-4)
7. [Step by step — Financial Data Streams (scenario 5)](#7-step-by-step--financial-data-streams-scenario-5)
8. [Step by step — User Activity Streams (scenario 6)](#8-step-by-step--user-activity-streams-scenario-6)
9. [Step by step — Type-Aware Transformation (scenario 7)](#9-step-by-step--type-aware-transformation-scenario-7)
10. [Step by step — Real-Time Dashboard (scenario 8)](#10-step-by-step--real-time-dashboard-scenario-8)
11. [The Fan-In Pattern — Why Not Flow.mergeWith?](#11-the-fan-in-pattern--why-not-flowmergewith)
12. [Parts checklist](#12-parts-checklist)
13. [Rules for combining them](#13-rules-for-combining-them)
14. [Still demo-only](#still-demo-only)
15. [Summary table](#summary-table)

---

## 1. Why they have to combine

A user click is an **event**. A system metric is a **different event**. A dashboard needs **all events** in one stream.

If you create separate observers for each source, the dashboard has to subscribe to multiple cells. If you use `Flow.mergeWith`, events can be dropped if the sink isn't ready. If you put aggregation logic in the source, each source becomes coupled to the dashboard.

The demo's rule:

```
Cell answers: what events are available?
Observer answers: how should we forward and aggregate?
Dashboard answers: what should we display?
```

---

## 2. Design (tagged)

**[Cell]** holds or carries. **[Cell.ingress]** is the entry point.
**[Cell.observe]** forwards events. **[Fan-In Pattern]** merges sources.

```
 source A ────┐
              │
 source B ────┼───► observer ────► shared bus ────► dashboard
              │
 source C ────┘
```

| You need | You use |
|---|---|
| Multiple independent sources | **Cell.ingress** per source |
| Shared event stream | **Cell.ingress** as bus |
| Forward events to bus | **Cell.observe** with fan-in |
| Preserve source identity | Event carries `source` field |
| Type-aware aggregation | Type checking in observer |
| Dashboard updates | Observer with state aggregation |

---

## 3. Step by step — Fan-In Pattern (scenario 1)

Read this as Cell then Observer then Bus.

**0. Graph (once)**
Create two source cells (`sourceA`, `sourceB`) and a shared bus (`bus1`).
Attach observers to each source that forward matching events to the bus.
Attach dashboard observer to the bus.

**1. Pulse (Cell)**
`sourceA.emit('A-1')` → source A emits a pulse.

**2. Forwarding (Observer)**
Observer on source A checks: `payload is String` → `bus1.emit(payload)`.

**3. Bus (Cell)**
Bus receives the forwarded event and broadcasts to its observers.

**4. Dashboard (Observer)**
Observer on bus prints the merged event.

**Why this matters**: Events from source A and source B appear in the same stream. No events are dropped.

---

## 4. Step by step — Real-Time Event Aggregation (scenario 2)

Three sources with different event types:

```
users.cell ────┐
               │
system.cell ───┼───► fan-in ────► bus2 ────► observer
               │
business.cell ─┘
```

The observer tracks `eventCount` and prints aggregated metrics.

**Source events**:
- `UserActivity` (user_001 click on home)
- `SystemMetricEvent` (CPU 45.2%)
- `BusinessEvent` (order_created)

**Aggregated output**: Total events: 1 → 2 → 3

---

## 5. Step by step — Multi-Source Log Aggregation (scenario 3)

Three log sources forwarded to a shared bus:

```
log1.cell ────┐
              │
log2.cell ────┼───► fan-in ────► bus3 ────► observer
              │
log3.cell ────┘
```

The observer filters by log level:

- `ERROR` → prints with `[Error Log]` prefix
- Other levels → prints with `[Aggregated Logs]` prefix

---

## 6. Step by step — IoT Sensor Data Merge (scenario 4)

Three sensor sources with specialized event types:

```
s1.cell (Temperature) ────┐
                          │
s2.cell (Humidity) ───────┼───► fan-in ────► bus4 ────► observer
                          │
s3.cell (Pressure) ───────┘
```

The observer prints each sensor reading with its sensor ID.

---

## 7. Step by step — Financial Data Streams (scenario 5)

Two sources with different types:

```
market.cell (MarketEvent) ────┐
                              │
news.cell (String) ───────────┼───► fan-in ────► bus5 ────► observer
                              │
```

The observer uses type checking:

- `MarketEvent` → prints stock symbol, price, and change indicator
- `String` → prints as news headline

---

## 8. Step by step — User Activity Streams (scenario 6)

Single source direct observation (no fan-in needed):

```
activity.cell ────► observer
```

The observer prints user actions with user ID and target.

---

## 9. Step by step — Type-Aware Transformation (scenario 7)

Three sources with different types forwarded to a shared bus:

```
ni.cell (int) ────┐
                  │
si.cell (String) ─┼───► fan-in ────► bus7 ────► observer
                  │
di.cell (double) ─┘
```

The observer transforms each type differently:
- `int` → double it
- `String` → uppercase it
- `double` → multiply by 1.5

---

## 10. Step by step — Real-Time Dashboard (scenario 8)

Three sources forwarded to a shared bus with aggregation:

```
du.cell (UserActivity) ────┐
                           │
ds.cell (SystemMetricEvent) ┼───► fan-in ────► bus8 ────► observer
                           │
db.cell (BusinessEvent) ───┘
```

The observer tracks:

- `total` → total events
- `uc` → user events count
- `sc` → system events count
- `bc` → business events count

Each event triggers a dashboard update with all metrics.

---

## 11. The Fan-In Pattern — Why Not Flow.mergeWith?

| Feature | Flow.mergeWith | Fan-In Pattern |
|---|---|---|
| **Event delivery** | Can drop events if sink not ready | Reliable, no drops |
| **Implementation** | Built-in operator | Custom observers |
| **Type safety** | Generic over type | Generic over type |
| **Source tracking** | Loses source identity | Preserves via event field |
| **Flexibility** | Fixed pattern | Customizable |
| **Complexity** | Simple | Moderate |

**When to use fan-in**:
- Multiple independent sources
- Events must not be dropped
- Need source identity preservation
- Custom forwarding logic needed

**When to use Flow.mergeWith**:
- Simple merging of cells
- Sink is always ready
- Source identity not important

---

## 12. Parts checklist

| Kind | Instances |
|---|---|
| Cell | `sourceA`, `sourceB`, `bus1`, `users`, `system`, `business`, `bus2`, `log1/2/3`, `bus3`, `s1/2/3`, `bus4`, `market`, `news`, `bus5`, `activity`, `bus6`, `ni/si/di`, `bus7`, `du/ds/db`, `bus8` |
| Observer | one per source (fan-in), one per bus (dashboard) |
| Not Cell | Event class hierarchy (UserActivity, SystemMetricEvent, BusinessEvent, SensorReadingEvent, MarketEvent) |

---

## 13. Rules for combining them

1. **Cell holds events. Observer forwards them. Bus aggregates them.**
2. **Fan-in pattern: one observer per source, forwarding to a shared bus.**
3. **Type checking in observer: forward only matching types.**
4. **Event carries source identity for downstream filtering.**
5. **Dashboard: state aggregation in observer, printed on each event.**
6. **Multiple bus observers for different views (filtering, transformation).**
7. **No Flow.mergeWith needed — observers are more reliable.**

---

## Still demo-only

All events are simulated. Real-world merges may involve streams with backpressure, reconnection logic, and authentication. Performance considerations apply to high-frequency event streams.

---

## Summary table

| Scenario | Pattern | Cell does | Observer does |
|---|---|---|---|
| 1 Basic | Fan-in 2 sources | Holds strings | Forwards to bus, prints merged |
| 2 Event Aggregation | Fan-in 3 event types | Holds Events | Counts and aggregates |
| 3 Log Aggregation | Fan-in 3 log sources | Holds strings | Filters by ERROR level |
| 4 IoT Sensors | Fan-in 3 sensor types | Holds SensorReadingEvent | Prints with sensor ID |
| 5 Financial | Fan-in 2 types | Holds Object | Type-aware rendering |
| 6 User Activity | Single source | Holds UserActivity | Prints user actions |
| 7 Transformation | Fan-in 3 types | Holds Object | Type-aware transformation |
| 8 Dashboard | Fan-in 3 event types | Holds Events | Dashboard metrics aggregation |