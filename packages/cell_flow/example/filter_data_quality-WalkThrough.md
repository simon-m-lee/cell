# Walkthrough — Data Quality Filtering (Flow.filter)

**Demo:** `example\filter_data_quality_demo.dart`

One pipeline. Three layers in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **Cell** | value + pulse + TestCell + observe | What data is flowing; who may see it |
| **Flow** | Filter `+` Map `+` toHandle | Is this value valid? Should it pass? |
| **Observer** | `Cell.observe` | Log results and collect statistics |

Flow never modifies the original data source. Cell never validates business rules. The observer is the only glue.

---

## Contents

1. [Why they have to combine](#1-why-they-have-to-combine)
2. [Design (tagged)](#2-design-tagged)
3. [Step by step — Basic Numeric Filtering (scenario 1)](#3-step-by-step--basic-numeric-filtering-scenario-1)
4. [Step by step — String Validation (scenario 2)](#4-step-by-step--string-validation-scenario-2)
5. [Step by step — Complex Object Filter (scenario 3)](#5-step-by-step--complex-object-filter-scenario-3)
6. [Step by step — Real-Time Sensor Filtering (scenario 4)](#6-step-by-step--real-time-sensor-filtering-scenario-4)
7. [Step by step — Multi-Condition Filter Pipeline (scenario 5)](#7-step-by-step--multi-condition-filter-pipeline-scenario-5)
8. [Step by step — Real-Time Log Filtering (scenario 6)](#8-step-by-step--real-time-log-filtering-scenario-6)
9. [Step by step — Conditional Filter with Complex Logic (scenario 8)](#9-step-by-step--conditional-filter-with-complex-logic-scenario-8)
10. [Step by step — Combined Filter Pipeline (scenario 10)](#10-step-by-step--combined-filter-pipeline-scenario-10)
11. [Filter types in this demo](#11-filter-types-in-this-demo)
12. [Parts checklist](#12-parts-checklist)
13. [Rules for combining them](#13-rules-for-combining-them)
14. [Still demo-only](#still-demo-only)
15. [Summary table](#summary-table)

---

## 1. Why they have to combine

A sensor reading is a **pulse**. A filter condition is **logic**. Logging is **I/O**.

If you put validation logic inside the observer, the observer becomes coupled to business rules. If you put logging inside the filter, the filter becomes impure. If you put filter logic inside the Cell, the Cell becomes specific to one use case.

The demo's rule:

```
Flow answers: may this value pass the quality gate?
Cell answers: what is the current state of the stream?
Observer answers: what should we record about the result?
```

---

## 2. Design (tagged)

**[Cell]** holds or carries. **[FlowInstruction]** is `(pulse)→pulse|null`.
**[Receptor]** runs the chain under one lock. **[Cell.observe]** is
`(pulse)→side effect`.

```
 data source (simulator)
     │
     ▼
[Cell] ingress + TestCell         FLOW intake
     │  emit
     ▼
[Receptor] toHandle(source: cell)  FLOW policy
     │   [Instruction] Filter       (is value valid?)
     │   [Instruction] Map          (transform if needed)
     │   null = stop; no side effects
     ▼
[Cell] rx.cell                     FLOW output
     │  Cell.observe
     ▼
 side effect (logging/collecting)  glue (Dart)
```

| You need | You use |
|---|---|
| Remove negative numbers | **Flow** Filter |
| Remove empty strings | **Flow** Filter |
| Validate complex objects | **Flow** Filter |
| Real-time sensor quality | **Flow** Filter + **Flow** fromStream |
| Multi-condition pipeline | **Flow** Filter chain |
| Log filtering | **Flow** Filter + **Cell.observe** |
| Combined filter-transform | **Flow** Filter + **Flow** Map |

---

## 3. Step by step — Basic Numeric Filtering (scenario 1)

Read this as Cell then Flow then Observer.

**0. Graph (once)**
`installGate()`: **Flow** `toHandle` on **Cell** `numInput`.
`Cell.observe` on `positiveFilter.cell` → collect valid numbers.
No state Cells needed — this is pure transformation.

**1. Pulse (Cell)**
`numInput.emit(10)` → Cell ingress. No TestCell on this ingress (demo simplicity).

**2. Policy (Flow)**
Receptor runs Filter Instruction:

| Stage | In | Out |
|---|---|---|
| Filter | `10` | pass (`10 > 0`) |
| Filter | `-5` | `null` (drop) |

Valid numbers go to `rx.cell`. Invalid numbers are collected in `invalidNumbers` list.

**3. Observer (glue)**
Observer appends valid numbers to `filteredNumbers` list. Invalid numbers were collected during filter evaluation.

---

## 4. Step by step — String Validation (scenario 2)

**Flow** Filter removes empty and whitespace-only strings.

| Stage | In | Out |
|---|---|---|
| Filter | `'hello'` | pass |
| Filter | `'   '` | `null` (drop) |
| Filter | `''` | `null` (drop) |

Empty strings are collected in `emptyStrings` list for reporting.

---

## 5. Step by step — Complex Object Filter (scenario 3)

**Flow** Filter evaluates `User.isAdult` property.

| Stage | In | Out |
|---|---|---|
| Filter | `Alice(25, admin)` | pass |
| Filter | `Bob(17, user)` | `null` (drop) |

Underage users are collected in `underageUsers` list. Adult users go to observer.

**Why this matters**: The filter encapsulates the business rule (age >= 18). The Cell just carries the data. The observer just logs.

---

## 6. Step by step — Real-Time Sensor Filtering (scenario 4)

**Flow** fromStream bridges a Dart Stream into the Cell graph.

**Flow** Filter validates sensor readings:

```
Raw: [17.7°C, 21.2°C, 33.7°C, 67.0°C, 33.4°C, 24.7°C, 19.6°C, 24.5°C, 53.7°C]
Filter: isValid (temperature -10..50, humidity 0..100)
Valid:   [17.7°C, 21.2°C, 33.7°C, 33.4°C, 24.7°C, 19.6°C, 24.5°C]
Invalid: [67.0°C (high), 53.7°C (high)]
```

**Flow** never handles the sensor directly. **Cell** never knows about temperature ranges. The observer prints the results.

---

## 7. Step by step — Multi-Condition Filter Pipeline (scenario 5)

Three filters in sequence:

```
Raw Events (15)
  → typeFilter (error|warning)  → 5 events
    → priorityFilter (priority >= 5) → 4 events
      → timeFilter (timestamp < 5s ago) → 3 events
```

Each filter is a separate **Flow** instruction. Each has one responsibility.

**Why this matters**: You can add, remove, or reorder filters independently. The pipeline is composable.

---

## 8. Step by step — Real-Time Log Filtering (scenario 6)

Four parallel filters on the same source:

```
Raw Logs
  → errorFilter  → ERROR logs
  → warningFilter → WARNING logs  
  → infoFilter   → INFO logs
  → criticalFilter → ERROR + critical metadata
```

Each filter observes the same source cell. Each counts independently.

**Flow** shares the source cell. **Cell** broadcasts to all observers.

---

## 9. Step by step — Conditional Filter with Complex Logic (scenario 8)

Filter with multiple conditions:

```
Filter: age 18-65 AND score >= 0.7 AND status in ['active', 'pending']

Alice:  age=30, score=0.85, status=active  → pass
Bob:    age=16, score=0.95, status=active  → fail (age)
Charlie: age=40, score=0.65, status=pending → fail (score)
Diana:  age=25, score=0.90, status=inactive → fail (status)
Eve:    age=50, score=0.92, status=active  → pass
```

The filter encapsulates complex business logic. The Cell just carries maps.

---

## 10. Step by step — Combined Filter Pipeline (scenario 10)

Filter → Map → Filter pipeline:

```
Input: {id:1, value:30}, {id:2, value:60}, {id:5, value:120}
  → Filter (id > 0, value > 0) → all pass
    → Map (value * 2) → {value:60}, {value:120}, {value:240}
      → Filter (value > 100) → {value:120}, {value:240}
```

Three instructions, one pipeline. Each has one responsibility. The pipeline is reusable.

---

## 11. Filter types in this demo

| Filter Type | Use Case | Demo Scenario |
|---|---|---|
| Numeric | Range validation, sign checks | 1, 7 |
| String | Non-empty, whitespace removal | 2 |
| Complex Object | Business rules, domain validation | 3, 8 |
| Sensor | Quality control, anomaly detection | 4 |
| Multi-condition | Combined criteria, pipelines | 5, 10 |
| Log | Level-based filtering, error detection | 6 |
| Alert | Critical event detection | 9 |

---

## 12. Parts checklist

| Kind | Instances |
|---|---|
| Cell | `numInput`, `strInput`, `userInput`, `sensorInput`, `eventInput`, `logInput`, `perfInput`, `complexInput`, `alertInput`, `pipelineInput` |
| FlowInstruction | Filter, Map, fromStream |
| FlowHandle | one per filter pipeline |
| Observer | one per output cell |
| Not Cell | Simulators (SensorSimulator, LogSimulator, EventSimulator) |

---

## 13. Rules for combining them

1. **Flow filters pulses. Cell carries state. Observer logs.**
2. **One Filter per condition.** Compose with `+` or chain cells.
3. **Filter is pure.** It does not modify the source.
4. **Map after Filter for transform pipelines.**
5. **Real-time streams use fromStream to bridge.**
6. **Multiple observers on the same source for different views.**
7. **Do not put filter logic in the observer.**

---

## Still demo-only

All simulators are deterministic. Performance test is synthetic. Real-world filters may be async or use external validation services.

---

## Summary table

| Scenario | Flow does | Cell does | Observer does |
|---|---|---|---|
| 1 Numeric | Filters positives | Carries ints | Collects results |
| 2 String | Filters non-empty | Carries strings | Collects results |
| 3 User | Filters adults | Carries Users | Collects results |
| 4 Sensor | Filters valid readings | Carries readings | Prints status |
| 5 Multi-condition | Chains filters | Carries Events | Counts pipeline stages |
| 6 Log | Filters by level | Carries LogEntry | Counts by level |
| 7 Performance | Filters range | Carries ints | Measures throughput |
| 8 Complex | Multi-condition filter | Carries maps | Collects results |
| 9 Alert | Filters critical alerts | Carries maps | Prints critical alerts |
| 10 Combined | Filter→Map→Filter | Carries maps | Collects results |