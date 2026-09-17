# Baggage Flow Watch - Software Design Walkthrough

## 1. Overview
This document outlines the software architecture for the **Baggage Flow Watch** system, designed using the **Cell Framework** (Mitosis). The Cell Framework provides a reactive, causal, and highly testable foundation ideal for real-time operational systems requiring strict data integrity, role-based views (Deputy pattern), and complex event aggregation.

## 2. Architectural Layers
The system is divided into five logical layers aligned with Cell Framework principles:
1. **Ingress Layer**: External event entry points (bag scans, AODB feeds, belt sensors, user actions).
2. **State Layer (Nucleus)**: Authoritative, persistent reactive state holding the current system truth.
3. **Derivation & Synthesis Layer**: Pure business logic calculating risk, grouping incidents, and detecting jams.
4. **Action Layer**: User commands (acknowledgements, notes) flowing back into the state via validated transactions.
5. **View Layer (Deputy)**: Restricted, role-specific projections for UI dashboards and reporting.

## 3. Component Design & BRD Mapping

### 3.1 Ingress Components (Data Entry)
- **`bagScanIngress`** (`Cell.ingress<BagScanEvent>`): Captures bag tag, position, and timestamp (DR-01, FR-01).
- **`flightDataIngress`** (`Cell.ingress<FlightUpdateEvent>`): Captures AODB updates for scheduled departure and baggage close-out times (DR-02).
- **`beltStatusIngress`** (`Cell.ingress<BeltStatusEvent>`): Captures belt/sorter/carousel operational status (running/stopped) (FR-05).
- **`actionIngress`** (`Cell.ingress<SupervisorAction>`): Captures alert acknowledgements, free-text notes, and resolutions (FR-07, FR-11).

### 3.2 State Components (Nucleus)
- **`activeBagsCell`** (`Cell.state<Map<String, BagState>>`): Holds the real-time state of all departing bags, keyed by tag number.
- **`flightsCell`** (`Cell.state<Map<String, FlightState>>`): Holds flight schedules, airline codes, and close-out deadlines.
- **`incidentsCell`** (`Cell.state<Map<String, IncidentState>>`): Tracks grouped incidents, their status (open, acknowledged, resolved), and audit trails (DR-03, DR-04).

### 3.3 Processing Components (Business Logic)
- **`bagRiskEvaluator`** (`Cell.synthesis`): Combines `activeBagsCell` and `flightsCell`. Calculates time remaining and flags bags as "at risk" if time < minimum connection time (FR-02, FR-03). Enforces BR-02 (no alerts for closed flights).
- **`jamDetector`** (`Cell.debounce` + `Cell.observe`): Monitors `beltStatusIngress`. If a belt remains "stopped" for >60 seconds, it emits a `JamAlert` pulse (FR-05, FR-06).
- **`incidentAggregator`** (`Cell.synthesis`): Groups individual `BagRisk` and `JamAlert` pulses into a single `Incident` based on shared cause, belt, or carousel (FR-08).

### 3.4 View Components (Deputy Pattern)
- **`dutyManagerView`** (`Cell.derive`): Projects a filtered, terminal-specific view of open incidents and at-risk bags. Returned as a `deputy` to ensure read-only access for the UI, enforcing role-based security (NFR-04, FR-04).
- **`dailyReportView`** (`Cell.derive`): Aggregates resolved incidents and bag metrics by airline code for the Airline Liaison Officer (Chen), ensuring no passenger personal data is included (BR-04, FR-10, AR-01).

## 4. Example Implementation (Dart / Cell Framework)

Below are illustrative code snippets demonstrating how the Cell Framework addresses key BRD requirements.

### 4.1 Real-time Bag Risk Evaluation (FR-02, FR-03, BR-02)
```dart
// Synthesis of bag state and flight state to determine risk
final bagRiskEvaluator = Cell.synthesis2<Map<String, BagState>, Map<String, FlightState>, Map<String, BagRiskStatus>>(
  cell1: activeBagsCell,
  cell2: flightsCell,
  combine: (bags, flights) {
    final risks = <String, BagRiskStatus>{};
    for (final bag in bags.values) {
      final flight = flights[bag.flightNumber];
      if (flight != null) {
        // BR-02: No alert may be raised for a bag on a flight that has already closed.
        if (DateTime.now().isBefore(flight.baggageCloseOutTime)) {
          final timeRemaining = flight.baggageCloseOutTime.difference(bag.lastScanTime);
          if (timeRemaining.inMinutes < flight.minimumConnectionTime) {
            risks[bag.tagNumber] = BagRiskStatus(
              tag: bag.tagNumber,
              flight: bag.flightNumber,
              terminal: bag.terminal,
              timeRemaining: timeRemaining,
              isAtRisk: true,
            );
          }
        }
      }
    }
    return risks;
  },
);