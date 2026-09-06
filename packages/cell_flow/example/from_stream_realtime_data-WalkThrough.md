# Walkthrough — Real-Time Data Pipeline (Flow.fromStream)

**Demo:** `example\from_stream_realtime_data_demo.dart`

One pipeline. Three layers in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **Cell** | value + pulse + observe + synthesis | What data is flowing; how streams are combined |
| **Flow** | fromStream + filter + map + synthesis | Bridge external streams; process in real-time |
| **Observer** | `Cell.observe` | Log results and update dashboards |

Flow never stores data. Cell never knows about stream sources. The observer is the only glue.

---

## 1. Why they have to combine

A WebSocket message is a **stream event**. A sensor reading is **real-time data**. A dashboard is **UI state**.

If you put stream bridging inside the observer, the observer becomes coupled to network protocols. If you put dashboard logic inside the stream, the stream becomes impure. If you put data quality checks in the Cell, the Cell becomes specific to one use case.

The demo's rule:

```
Flow answers: may this stream event enter the graph?
Cell answers: what is the current state of the data?
Observer answers: what should we display or log?
```

---

## 2. Design (tagged)

**[Cell]** holds or carries. **[FlowInstruction]** is `(pulse)→pulse|null`.
**[Receptor]** runs the chain under one lock. **[Cell.observe]** is
`(pulse)→side effect`.

```
 external stream (WebSocket/Sensor/SSE)
     │
     ▼
[Cell] ingress + TestCell         FLOW intake
     │  emit (trigger)
     ▼
[Receptor] toHandle(source: cell)  FLOW policy
     │   [Instruction] fromStream   (bridge stream events)
     │   [Instruction] filter       (data quality)
     │   [Instruction] map          (transform/enrich)
     │   null = stop; no side effects
     ▼
[Cell] rx.cell                     FLOW output
     │  Cell.observe
     ▼
 side effect (logging/dashboard)   glue (Dart)
```

| You need | You use |
|---|---|
| Bridge external Stream | **Flow** fromStream |
| Real-time data quality | **Flow** filter |
| Data transformation | **Flow** map |
| Data enrichment | **Flow** map (calculated fields) |
| Multiple stream aggregation | **Cell** synthesis |
| Anomaly detection | **Flow** filter + map |
| Dashboard updates | **Flow** map (state aggregation) |
| Alert aggregation | **Cell** synthesis |

---

## 3. Step by step — Basic Stream Bridge (scenario 1)

Read this as Cell then Flow then Observer.

**0. Graph (once)**
`Flow.fromStream` with `toHandle` on **Cell** `wsInput`.
`Cell.observe` on `wsProcessed.cell` → print results.

**1. Pulse (Cell)**
`wsInput.emit(null)` → arms the stream bridge.

**2. Policy (Flow)**
fromStream subscribes to the WebSocket stream:

| Stage | In | Out |
|---|---|---|
| fromStream | stream event | `Map<String, dynamic>` |
| map | `Map` | `'WebSocket data #1 processed'` |

Each stream event becomes a pulse. The observer prints each result.

**3. Observer (glue)**
Observer prints the transformed message and the pulse trace.

---

## 4. Step by step — Real-Time Sensor Processing (scenario 2)

fromStream bridges a sensor stream. filter removes anomalies. map detects anomalies:

```
Sensor stream
  → fromStream → SensorReading
    → filter (isAnomaly) → valid readings only
    → map (isAnomaly) → '✅ Valid' or '⚠️ Anomaly'
```

**Flow** handles the filtering. **Cell** carries the readings. The observer prints the results.

---

## 5. Step by step — Real-Time Dashboard (scenario 3)

fromStream bridges web metrics. map aggregates state:

```
WebMetric stream
  → fromStream → WebMetric
    → map → DashboardState
      (aggregates: activeUsers, requestsPerSecond, avgResponseMs, errorRate)
```

The state is updated on every metric. The observer prints the latest dashboard.

**Why this matters**: The dashboard updates in real-time. The state is pure (computed from the stream). No mutable state outside the map.

---

## 6. Step by step — Multiple Stream Aggregation (scenario 4)

Two sensor streams merged via synthesis:

```
Sensor-002 stream → fromStream → map → (sensorId, temp, timestamp)
Sensor-003 stream → fromStream → map → (sensorId, temp, timestamp)
  → synthesis → Map {sensors: {002: temp, 003: temp}, avg_temp, timestamp}
```

**Cell** synthesis combines the two streams. Each sensor update triggers a new combined output.

---

## 7. Step by step — Anomaly Detection (scenario 5)

fromStream bridges system metrics. map detects anomalies. filter separates them:

```
SystemMetric stream
  → fromStream → SystemMetric
    → map → '✅ Normal' or '⚠️ Anomaly'
      → filter (contains 'anomaly') → alerts only
```

Two observers: one for all metrics (normal + anomaly), one for alerts only.

**Flow** handles the filtering. The alert observer only sees anomalies.

---

## 8. Step by step — Data Quality Pipeline (scenario 6)

fromStream bridges sensor data. map computes quality metrics:

```
Sensor stream
  → fromStream → SensorReading
    → map → {
        totalReadings, validReadings, invalidReadings,
        completenessScore, isValid, reading
      }
      → filter (isValid) → only valid readings
```

The quality metrics are computed on every reading. The observer prints the completeness score.

---

## 9. Step by step — Data Enrichment (scenario 7)

fromStream bridges sensor data. map adds calculated fields:

```
Sensor stream
  → fromStream → SensorReading
    → map → {
        sensorId, temperature, humidity, pressure,
        heatIndex, dewPoint, riskLevel, location
      }
```

The enriched data includes calculated fields (heat index, dew point) and contextual data (risk level, location).

**Flow** handles the enrichment. **Cell** carries the enriched data.

---

## 10. Step by step — Alert Aggregation (scenario 8)

Two sensor streams, filtered for anomalies, then synthesized:

```
Sensor-ALERT-1 stream → fromStream → filter (isAnomaly)
Sensor-ALERT-2 stream → fromStream → filter (isAnomaly)
  → synthesis → Map {alerts: {sensorId: temp}, count, severity}
```

Only anomalies reach the synthesis. The synthesis aggregates all alerts into one output.

---

## 11. Supported Stream Sources

| Source Type | Use Case |
|---|---|
| WebSocket | Real-time bidirectional communication |
| Server-Sent Events (SSE) | Server-to-client streaming |
| Hardware sensors | IoT, environmental monitoring |
| File watchers | File system changes |
| Database change streams | Real-time data synchronization |
| Network sockets | Low-level network communication |
| Third-party SDKs | External service integration |

---

## 12. Parts checklist

| Kind | Instances |
|---|---|
| Cell | `wsInput`, `sensorInput`, `metricsInput`, `aggInput1/2/3`, `anomalyInput`, `qualityInput`, `enrichInput`, `alertInput1/2` |
| FlowInstruction | fromStream, filter, map, synthesis |
| FlowHandle | one per pipeline |
| Observer | one per output cell |
| Not Cell | Simulators (WebSocket, Sensor, WebMetric, SystemMetric) |

---

## 13. Rules for combining them

1. **Flow bridges streams. Cell carries data. Observer logs/updates.**
2. **Use fromStream to bridge any Dart Stream.**
3. **Use filter for data quality and anomaly detection.**
4. **Use map for transformation and enrichment.**
5. **Use synthesis to combine multiple streams.**
6. **Use map with state aggregation for dashboards.**
7. **Stream errors are handled via onError callback.**
8. **The stream subscription starts on the first pulse.**

---

## Still demo-only

All streams are simulated. Real-world streams may have backpressure, reconnection logic, and authentication. Performance considerations apply to high-frequency streams.

---

## Summary table

| Scenario | Flow does | Cell does | Observer does |
|---|---|---|---|
| 1 WebSocket | Bridges WebSocket stream | Carries map data | Prints transformed messages |
| 2 Sensor | Bridges sensor, filters anomalies | Carries readings | Prints valid/anomaly status |
| 3 Dashboard | Bridges metrics, aggregates state | Carries dashboard state | Prints dashboard updates |
| 4 Multi-stream | Bridges 2 sensors, synthesis | Carries combined data | Prints aggregated metrics |
| 5 Anomaly | Bridges metrics, detects anomalies | Carries anomaly status | Prints alerts |
| 6 Quality | Bridges sensor, computes quality | Carries quality metrics | Prints completeness score |
| 7 Enrich | Bridges sensor, enriches data | Carries enriched data | Prints enriched fields |
| 8 Alert | Bridges 2 sensors, aggregates alerts | Carries alert data | Prints aggregated alerts |