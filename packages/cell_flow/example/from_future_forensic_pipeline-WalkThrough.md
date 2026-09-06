# Walkthrough — Forensic Pipeline (Flow.fromFuture / deferFuture)

**Demo:** `example\from_future_forensic_pipeline_demo.dart`

One pipeline. Three layers in one job:

| Layer | Package idea | Job on this station |
|---|---|---|
| **Cell** | value + pulse + observe | What data is flowing; who may see it |
| **Flow** | deferFuture + asyncMap + synthesis | Bridge legacy APIs; preserve chain of custody |
| **Observer** | `Cell.observe` | Log results and collect metrics |

Flow never modifies the source data. Cell never knows about legacy APIs. The observer is the only glue.

---

## 1. Why they have to combine

A legacy API call is a **Future**. Forensic metadata is **provenance**. Audit trails are **I/O**.

If you put API calls inside the observer, the observer becomes coupled to network latency. If you put audit logic inside the Future, the Future becomes impure. If you put forensic metadata in the Cell, the Cell becomes specific to one use case.

The demo's rule:

```
Flow answers: may this Future be bridged into the graph?
Cell answers: what is the current state of the evidence?
Observer answers: what should we record about the result?
```

---

## 2. Design (tagged)

**[Cell]** holds or carries. **[FlowInstruction]** is `(pulse)→pulse|null`.
**[Receptor]** runs the chain under one lock. **[Cell.observe]** is
`(pulse)→side effect`.

```
 legacy API (Future-based)
     │
     ▼
[Cell] ingress + TestCell         FLOW intake
     │  emit
     ▼
[Receptor] toHandle(source: cell)  FLOW policy
     │   [Instruction] deferFuture  (await Future, emit result)
     │   [Instruction] map          (transform if needed)
     │   null = stop; no side effects
     ▼
[Cell] rx.cell                     FLOW output
     │  Cell.observe
     ▼
 side effect (logging/collecting)  glue (Dart)
```

| You need | You use |
|---|---|
| One-shot Future bridge | **Flow** fromFuture |
| Per-input Future bridge | **Flow** deferFuture |
| Multiple parallel Futures | **Flow** asyncMapConcurrent |
| Ordered Future steps | **Flow** deferFuture chain |
| Combine multiple sources | **Flow** synthesis |
| Error tracking | **Flow** onError callback |
| Provenance preservation | `pulse.withStep()` |

---

## 3. Step by step — Basic Future Bridge (scenario 1)

Read this as Cell then Flow then Observer.

**0. Graph (once)**
`Flow.deferFuture` with `toHandle` on **Cell** `evidenceInput`.
`Cell.observe` on `evidenceHandle.cell` → print results.

**1. Pulse (Cell)**
`evidenceInput.emit('EV-12345')` → Cell ingress.

**2. Policy (Flow)**
deferFuture creates a new Future for each pulse:

| Stage | In | Out |
|---|---|---|
| deferFuture | `'EV-12345'` | `Future<ForensicEvidence>` |
| Future completes | — | `ForensicEvidence` emitted |

**3. Observer (glue)**
Observer prints evidence details and trace.

---

## 4. Step by step — Chain of Custody (scenario 2)

Three sequential Future steps, then synthesis:

```
Input: 'EV-12345'
  → deferFuture (fetchEvidence) → ForensicEvidence
    → deferFuture (fetchImages) → List<ForensicImage>
    → deferFuture (fetchAuditLog) → List<ForensicAuditEntry>
      → synthesis → Map {evidence, images, audit}
```

Each step preserves provenance via `withStep`. Synthesis combines all three into one report.

**Why this matters**: The chain of custody is automatically preserved. Each API call adds a step to the pulse trace.

---

## 5. Step by step — Error Handling (scenario 3)

deferFuture with `onError` callback:

```
Input: 'EV-99999'
  → deferFuture (fetchEvidence)
    → EvidenceNotFoundException thrown
      → onError callback: prints error details
      → No output to observer
```

The error is captured with forensic context. The pipeline continues (no crash).

---

## 6. Step by step — Parallel Collection (scenario 4)

asyncMapConcurrent starts all three Futures at once:

```
Input: 1, 2, 3
  → asyncMapConcurrent
    → Source 1: fetchEvidence (500ms)
    → Source 2: fetchImages (350ms)
    → Source 3: fetchAuditLog (150ms)
  → Results emitted as they complete
```

Total time: ~350ms (not 500+350+150 = 1000ms).

**Flow** handles concurrency. **Cell** just carries the results.

---

## 7. Step by step — Sequential Processing (scenario 5)

Four deferFuture steps in sequence:

```
Input: 'forensic_user'
  → deferFuture (authenticate) → bool (200ms)
    → deferFuture (extract) → String (300ms)
      → deferFuture (analyze) → Map (200ms)
        → deferFuture (report) → String (150ms)
```

Total time: ~850ms. Each step waits for the previous to complete.

**Flow** handles ordering. Each step preserves provenance.

---

## 8. Step by step — Metadata Preservation (scenario 6)

deferFuture fetches multiple pieces of evidence:

```
Input: 'EV-12345'
  → fetchEvidence → ForensicEvidence
  → computeEvidenceHash → String
  → checkEvidenceStatus → String
  → Return: {evidence, hash, status, processingTime, sha256}
```

All metadata is preserved in the output. The pulse trace shows all steps.

---

## 9. Step by step — Legacy Integration (scenario 7)

deferFuture bridges a legacy system:

```
Input: 'LegacyDB'
  → fetchLegacyData → {system, records, version, lastSync}
  → Add forensic metadata
  → Return: {..., forensicTimestamp, forensicSource, forensicVersion}
```

Legacy data enters the reactive graph with full provenance.

---

## 10. Step by step — Audit Trail (scenario 8)

Complex pipeline with audit trail:

```
Input: {evidenceId: 'EV-12345', userId: 'forensic_user'}
  → createAuditEntry → ForensicAuditEntry
  → fetchEvidence → ForensicEvidence
  → computeEvidenceHash → String
  → Return: {
      auditEntry, evidence, integrity, verified,
      chainOfCustody: [
        {step: 'AUTHENTICATION', status: 'PASSED'},
        {step: 'EVIDENCE_RETRIEVAL', status: 'PASSED'},
        {step: 'INTEGRITY_CHECK', status: 'PASSED'},
        {step: 'AUDIT_CREATED', status: 'PASSED'},
      ]
    }
```

Full audit trail with integrity verification. Chain of custody is explicit.

---

## 11. Flow.fromFuture vs Flow.deferFuture

| Feature | fromFuture | deferFuture |
|---|---|---|
| **When to use** | Single, one-shot Future | New Future per input |
| **Trigger** | First pulse only | Every pulse |
| **Reusability** | One-time | Reusable |
| **Use case** | Initialization, one-time load | Per-request, per-item |

**fromFuture**: Good for loading app config, user profile, initial data.
**deferFuture**: Good for search queries, per-item loading, request-response.

---

## 12. Parts checklist

| Kind | Instances |
|---|---|
| Cell | `evidenceInput`, `custodyInput`, `errorInput`, `parallelInput`, `processInput`, `metadataInput`, `legacyInput`, `auditInput` |
| FlowInstruction | deferFuture, asyncMapConcurrent, synthesis |
| FlowHandle | one per pipeline |
| Observer | one per output cell |
| Not Cell | ForensicApi (legacy simulator), ForensicMetrics |

---

## 13. Rules for combining them

1. **Flow bridges Futures. Cell carries state. Observer logs.**
2. **Use deferFuture for per-input async operations.**
3. **Use fromFuture for one-shot async operations.**
4. **Use asyncMapConcurrent for parallel operations.**
5. **Chain deferFuture for sequential operations.**
6. **Use synthesis to combine multiple sources.**
7. **Handle errors in onError callback with forensic context.**
8. **Preserve provenance with pulse.withStep().**

---

## Still demo-only

All APIs are simulated. Real-world APIs may have network latency, retries, and authentication. Forensic integrity checks are simplified.

---

## Summary table

| Scenario | Flow does | Cell does | Observer does |
|---|---|---|---|
| 1 Basic | Bridges Future | Carries evidence | Prints result |
| 2 Chain | Chains 3 Futures + synthesis | Carries combined report | Prints chain length |
| 3 Error | Catches exception | No output | Prints error |
| 4 Parallel | Concurrent Futures | Carries results | Prints completion order |
| 5 Sequential | Sequential Futures | Carries report | Prints final report |
| 6 Metadata | Fetches multiple sources | Carries metadata | Prints integrity |
| 7 Legacy | Bridges legacy system | Carries migrated data | Prints provenance |
| 8 Audit | Full audit pipeline | Carries audit result | Prints chain of custody |