# In-Depth: Blend — Virtual Organisms and Relational Projections

In the Cell Framework, a **`Blend`** is a **virtual organism** — a powerful, zero-copy reactive projection that aggregates fields and relations from multiple source entities into a single, unified, addressable identity.

Blends allow you to create **synthetic entities** without data duplication, making them ideal for summaries, dashboards, views, and cross-cutting projections.

---

## Table of Contents

- [Core Concept](#core-concept)
- [Architectural Role](#architectural-role)
- [Key Features](#key-features)
- [Creation Factories](#creation-factories)
- [Practical Examples](#practical-examples)
- [Advanced Patterns](#advanced-patterns)
- [Deputy & Immutability Support](#deputy--immutability-support)
- [Hydration from Persistence](#hydration-from-persistence)
- [Best Practices](#best-practices)
- [Summary](#summary)

---

## Core Concept

A `Blend` is a **live, reactive projection**:
- It does **not** duplicate data.
- It holds **live pointers** to source `Field` cells.
- Mutations through the blend are atomically reflected in the original sources (and vice versa).
- It has its own **virtual identity** (`name`, `id`, timestamps) and can have its own `testRule`, `context`, and `receptor`.

Think of it as a **synthetic organ** assembled from cells borrowed from different organisms — fully reactive and governed by its own `BlendNucleus`.

---

## Architectural Role

- **Somatic Projection** — Create unified views across domain boundaries.
- **Virtual Identity** — Treat aggregates as first-class entities.
- **Homeostatic Guarding** — Apply aggregate-level validation.
- **Secure Lenses** — Use deputies for role-based or redacted views.
- **Mesh Integration** — Fully participates in metabolic waves and cascades.

---

## Key Features

- Zero-copy & live synchronization
- Atomic multi-field mutations
- Hierarchical inheritance via `BlendNucleus.evolve()`
- Full Deputy Pattern support
- Deep JSON/Map hydration with cascade control

---

## Creation Factories

### 1. Basic Blend

```dart
final userSummary = Blend('UserSummary', fields: [
  user.name,
  user.email,
  user.avatar,
  stats.totalOrders,
  address.city,
]);
```

### 2. Custom Mapping

```dart
final accountPreview = Blend.from('AccountPreview', map: {
  #fullName: user.name,
  #email: user.email,
  #location: address.city,
  #memberSince: user.createdAt,
});
```

### 3. Grouped Collections

```dart
final orderDetails = Blend.group('OrderDetails', map: {
  #items: order.lineItems,
  #payments: order.payments,
  #shipping: [shipping.address, shipping.tracking],
}, toValue: (entry) => Many.fromFields(entry.value));
```

---

## Practical Examples

### 1. User Dashboard Blend

```dart
final dashboard = Blend('UserDashboard', fields: [
  user.name,
  user.email,
  user.avatar,
  stats.totalOrders,
  stats.loyaltyPoints,
  address.city,
  address.country,
]);

// Listen to the entire dashboard
Cell.listen<Pulse>(bind: dashboard, onPulse: (s) => updateDashboardUI());
```

### 2. Public Profile (Redacted View)

```dart
final publicProfile = dashboard.deputy(
  context: dashboard.context.redacted(),
  testRule: TestCell.readOnly(),
);

final publicAgent = publicProfile.aiAgent(provider: grok);
```

### 3. Order Summary for Customer Support

```dart
final supportOrderView = Blend('SupportOrderView', fields: [
  order.id,
  order.status,
  order.total,
  customer.name,
  customer.email,
  shipping.trackingNumber,
  payment.lastFour,
]);
```

### 4. Product Catalog Card

```dart
final productCard = Blend('ProductCard', fields: [
  product.name,
  product.price,
  product.imageUrl,
  product.averageRating,
  product.inStock,
]);
```

### Healthcare Domain Example: Patient Summary Blend

```dart
// Source entities from different parts of the system
final patient = PatientRecord();
final medicalHistory = MedicalHistory();
final labResults = LabResults();
final prescriptions = Prescriptions();
final vitalSigns = VitalSigns();
final insurance = InsuranceCoverage();

// Create a unified Patient Summary Blend
final patientSummary = Blend('PatientSummary', fields: [
  patient.fullName,
  patient.dateOfBirth,
  patient.bloodType,
  medicalHistory.currentConditions,
  medicalHistory.allergies,
  labResults.recentBloodWork,
  vitalSigns.latestBloodPressure,
  vitalSigns.heartRate,
  prescriptions.activeMedications,
  insurance.primaryProvider,
]);

// Add critical cross-field validation at blend level
final validatedSummary = patientSummary.deputy(
  testRule: TestCell([
    // Example: Allergy-drug interaction check
    (value, {host}) {
      final allergies = medicalHistory.allergies.value ?? [];
      final meds = prescriptions.activeMedications.value ?? [];
      return !hasAllergyConflict(allergies, meds);
    },
    // Example: Age-appropriate medication check
    AgeAppropriateMedicationRule(),
  ]),
);

// Role-based views using Deputies

// 1. Doctor View (Full Access)
final doctorView = validatedSummary.deputy(
  context: Context.create(role: 'physician'),
  testRule: TestCell.allowAll, // Full access
);

// 2. Nurse View (Limited)
final nurseView = validatedSummary.deputy(
  context: Context.create(role: 'nurse'),
  testRule: nurseAccessRules,
);

// 3. Patient View (Redacted + Read-only)
final patientView = validatedSummary.deputy(
  context: validatedSummary.context.redacted(), // HIPAA-style PII redaction
  testRule: TestCell.readOnly() + patientAccessRules,
);

// 4. Insurance / Admin View
final insuranceView = validatedSummary.deputy(
  context: Context.create(role: 'insurance'),
  testRule: insuranceAccessRules,
);

// Real-time listening
Cell.listen<Pulse>(
  bind: doctorView,
  onPulse: (s) => updateDoctorDashboard(),
);

// Usage in clinical workflow
void onNewLabResult() {
  labResults.refresh();
  // patientSummary automatically reflects the change
}
```

### Advanced Healthcare Patterns

#### Treatment Overview Blend

```dart
final treatmentOverview = Blend('TreatmentOverview', fields: [
  patient.id,
  patient.fullName,
  diagnosis.primaryCondition,
  diagnosis.secondaryConditions,
  treatmentPlan.currentProtocol,
  treatmentPlan.nextAppointment,
  prescriptions.activeMedications,
  labResults.trendingValues,
]);
```

#### Emergency Redacted View

```dart
final emergencyView = patientSummary.deputy(
  context: Context.create(
    role: 'emergency',
    requiresPIIRedaction: true,
  ),
  testRule: TestCell.readOnly() + emergencyAccessRules,
);
```

#### Research De-identified Dataset

```dart
final researchDataset = patientSummary.deputy(
  context: Context.create(role: 'research', deIdentified: true),
  testRule: TestCell.readOnly() + deIdentificationRules,
);
```

### Telemedicine Domain Example: Virtual Consultation Blend

```dart
// Source entities from different subsystems
final patient = PatientRecord();
final doctor = DoctorProfile();
final appointment = Appointment();
final consultation = ConsultationSession();
final vitals = WearableVitals();
final notes = ConsultationNotes();
final prescription = ePrescription();
final chat = ConsultationChat();

// Unified Telemedicine Consultation Blend
final consultSummary = Blend('TelemedicineConsult', fields: [
  patient.fullName,
  patient.dateOfBirth,
  patient.medicalRecordNumber,
  doctor.fullName,
  doctor.specialty,
  appointment.scheduledTime,
  appointment.status,
  consultation.startTime,
  consultation.durationMinutes,
  vitals.latestHeartRate,
  vitals.latestBloodPressure,
  vitals.oxygenSaturation,
  notes.doctorNotes,
  prescription.prescribedMedications,
  chat.lastMessagePreview,
]);

// Cross-field validation at Blend level (critical for telemedicine)
final validatedConsult = consultSummary.deputy(
  testRule: TestCell([
    // Example: Ensure consultation started after appointment time
    ConsultationTimeConsistencyRule(),
    // Example: Required vitals for certain specialties
    VitalSignsRequiredForSpecialtyRule(),
    // Example: Prevent prescribing controlled substances without verification
    ControlledSubstanceCheckRule(),
  ]),
);

// Role-based Deputies for different stakeholders

// 1. Doctor View (Full Access)
final doctorView = validatedConsult.deputy(
  context: Context.create(role: 'physician'),
  testRule: TestCell.allowAll,
);

// 2. Patient View (Redacted + Read-only)
final patientView = validatedConsult.deputy(
  context: validatedConsult.context.redacted(), // HIPAA / privacy redaction
  testRule: TestCell.readOnly() + patientAccessRules,
);

// 3. Nurse / Coordinator View
final nurseView = validatedConsult.deputy(
  context: Context.create(role: 'nurse'),
  testRule: nurseAccessRules,
);

// 4. Admin / Billing View
final billingView = validatedConsult.deputy(
  context: Context.create(role: 'billing'),
  testRule: billingAccessRules,
);

// Real-time listening during live consultation
Cell.listen<Pulse>(
  bind: doctorView,
  onPulse: (s) => updateDoctorConsultationUI(),
);

// Usage in telemedicine workflow
void onConsultationStart() {
  consultation.startSession();
  vitals.startStreaming();           // triggers live updates to the Blend
}
```

### Telemedicine Domain Example: Virtual Consultation Blend

```dart
// Source entities from different subsystems
final patient = PatientRecord();
final doctor = DoctorProfile();
final appointment = Appointment();
final consultation = ConsultationSession();
final vitals = WearableVitals();
final notes = ConsultationNotes();
final prescription = ePrescription();
final chat = ConsultationChat();

// Unified Telemedicine Consultation Blend
final consultSummary = Blend('TelemedicineConsult', fields: [
  patient.fullName,
  patient.dateOfBirth,
  patient.medicalRecordNumber,
  doctor.fullName,
  doctor.specialty,
  appointment.scheduledTime,
  appointment.status,
  consultation.startTime,
  consultation.durationMinutes,
  vitals.latestHeartRate,
  vitals.latestBloodPressure,
  vitals.oxygenSaturation,
  notes.doctorNotes,
  prescription.prescribedMedications,
  chat.lastMessagePreview,
]);

// === TELEMEDICINE COMPLIANCE RULES (Applied at Blend Level) ===
final complianceRules = TestCell([
  // 1. HIPAA / Consent Validation
  ConsentVerificationRule(),                    // Patient must have active consent

  // 2. Data Minimization
  DataMinimizationRule(fields: ['fullName', 'medicalRecordNumber']),

  // 3. Emergency Access Override
  EmergencyAccessRule(allowedRoles: ['emergency', 'on-call']),

  // 4. Audit Logging Requirement
  MandatoryAuditRule(operationTypes: ['view', 'prescribe', 'note']),

  // 5. Secure Transmission Check
  SecureChannelRule(),                          // Ensure encrypted session

  // 6. Age-appropriate consent for minors
  MinorConsentRule(),

  // 7. Controlled substance prescribing guard
  ControlledSubstancePrescribingRule(),
]);

final compliantConsult = consultSummary.deputy(
  testRule: complianceRules,
  context: Context.create(
    domain: 'telemedicine',
    compliance: 'HIPAA',
    requiresAudit: true,
  ),
);
```

### Detailed Compliance Rules (Reusable)

```dart
// Example reusable compliance rules

final ConsentVerificationRule = TestRule((value, {host}) {
  final consent = patient.consentStatus.value;
  return consent?.isValidForTelemedicine == true;
});

final EmergencyAccessRule = TestRule((value, {host, user}) {
  final role = user?.context?.metadata['role'];
  if (role == 'emergency') return true;
  return !isEmergencyContext(host);
});

final SecureChannelRule = TestRule((value, {host}) {
  return consultation.isEncrypted.value == true &&
         consultation.transmissionProtocol.value == 'TLS_1.3';
});

final ControlledSubstancePrescribingRule = TestRule((value, {host}) {
  if (!prescription.containsControlledSubstance) return true;
  return doctor.hasControlledSubstanceLicense.value == true &&
         patient.hasRecentInPersonVisit.value == true;
});
```

### Role-Based Deputies with Compliance

```dart
// 1. Full Doctor View
final doctorView = compliantConsult.deputy(
  context: Context.create(role: 'physician'),
  testRule: TestCell.allowAll,
);

// 2. Patient Portal View (Heavy Redaction)
final patientView = compliantConsult.deputy(
  context: compliantConsult.context.redacted(), // Automatic PII redaction
  testRule: TestCell.readOnly() + patientPortalRules,
);

// 3. Insurance / Billing View
final billingView = compliantConsult.deputy(
  context: Context.create(role: 'billing'),
  testRule: billingComplianceRules,
);
```

### Real-time Compliance-Aware Listening

```dart
Cell.listen<Pulse>(
  bind: doctorView,
  onPulse: (s) {
    if (s.context.requiresAudit) {
      auditLog.logConsultationAccess(
        consultId: appointment.id,
        accessedBy: doctor.id,
        fieldsAccessed: s.metadata['accessedFields'],
      );
    }
    updateDoctorTelemedicineUI();
  },
);
```

---

### Why This Matters in Telemedicine

- **HIPAA / GDPR Compliance** is enforced at the **Blend level** rather than scattered across components.
- **Emergency overrides** are explicitly modeled and auditable.
- **Patient consent** is a first-class invariant.
- **Role-based redaction** is clean and maintainable via deputies.
- **Audit trails** are automatic and contextual.

This pattern scales beautifully for:
- Live video consultations
- Asynchronous messaging
- Remote patient monitoring
- Multi-provider care coordination


---

## Advanced Patterns

### Multi-Source Financial Overview (Real-World Example)

```dart
// Source cells from different accounts
final checking = CheckingAccount();
final savings = SavingsAccount();
final creditCard = CreditCard();
final investments = InvestmentPortfolio();

// Create a unified Financial Overview Blend
final financialOverview = Blend('FinancialOverview', fields: [
  checking.balance,           // Current checking balance
  savings.balance,            // Savings balance
  creditCard.totalDue,        // Credit card debt
  creditCard.availableCredit, // Available credit limit
  investments.totalValue,     // Portfolio value
  investments.ytdReturn,      // Year-to-date return %
  user.preferredCurrency,     // User preference
]);

// Add aggregate validation at blend level
final validatedOverview = financialOverview.deputy(
  testRule: TestCell([
    // Cross-account invariant example
    (value, {host}) {
      final totalNetWorth = 
          (checking.balance.value ?? 0) + 
          (savings.balance.value ?? 0) + 
          (investments.totalValue.value ?? 0) -
          (creditCard.totalDue.value ?? 0);
      
      return totalNetWorth >= -50000; // Allow limited negative net worth
    },
  ]),
);

// Listen to the entire financial picture
Cell.listen<Pulse>(
  bind: validatedOverview,
  onPulse: (pulse) {
    print('Net Worth Updated: \$${calculateNetWorth()}');
    updateFinancialDashboardUI();
    checkForLowBalanceAlerts();
  },
);

// Usage in UI or services
void refreshOverview() {
  // Triggering any source field automatically updates the Blend
  checking.deposit(250.00);
  // financialOverview reflects the change instantly
}
```

### Advanced Variations

#### 1. Role-Based Financial Views

```dart
// Public / Limited View (for reports)
final publicFinancialView = financialOverview.deputy(
  context: financialOverview.context.redacted(),
  testRule: TestCell.readOnly() + publicDisclosureRules,
);

// Full Admin View
final adminFinancialView = financialOverview.deputy(
  context: Context.create(role: 'admin'),
  testRule: TestCell.allowAll, // full access
);
```

#### 2. With Computed Fields (Derived Blend)

```dart
final netWorth = Cell.value<double>(
  value: 0.0,
  bind: financialOverview,
  transform: (host, pulse, {user}) {
    final nw = 
        (checking.balance.value ?? 0) +
        (savings.balance.value ?? 0) +
        (investments.totalValue.value ?? 0) -
        (creditCard.totalDue.value ?? 0);
    return Pulse(nw);
  },
);

final enrichedOverview = Blend('EnrichedFinancialOverview', fields: [
  ...financialOverviewFields,
  netWorth.asField(#netWorth),   // Add computed field
]);
```

#### 3. Throttled Dashboard Update

```dart
final throttledOverview = financialOverview.deputy(
  synapses: Synapses.throttle(Duration(milliseconds: 800)), // smooth UI
);

Cell.listen<Pulse>(
  bind: throttledOverview,
  onPulse: (s) => updateFinancialDashboardUI(),
);
```


### Tenant-Aware Admin Dashboard

```dart
final tenantDashboard = globalStats.deputy(
  context: Context.create(tenantId: currentTenant.id),
  testRule: tenantAccessRules,
);
```

### Temporary Audit View

```dart
final auditView = sensitiveData.deputy(
  testRule: auditRules + sensitiveData.validate,
  context: Context.create(operation: 'compliance_audit'),
);
```

---

## Deputy & Immutability Support

```dart
final readOnlyBlend = blend.unmodifiable;

final restrictedBlend = blend.deputy(
  context: Context.create(role: 'viewer'),
  testRule: viewerRules,
);
```

---

## Hydration from Persistence

```dart
final restored = Blend.fromMap(jsonData, cascade: 1);

final restoredFromJson = Blend.fromJson(jsonString, cascade: 2);
```

---

## Best Practices

1. **Use semantic names** — `UserSummary`, `OrderPreview`, `AdminFinancialView`.
2. **Keep blends focused** — one clear purpose per blend.
3. **Apply validation at blend level** for cross-field invariants.
4. **Use deputies** liberally for security and UI optimization.
5. **Prefer `fromNucleus`** when you need reusable virtual schemas.
6. **Expose `unmodifiable`** blends to UI and external consumers.
7. **Document source fields** clearly in complex blends.

---

## Summary

**Blend** is one of the most elegant and powerful abstractions in the Cell Framework. It lets you:

- Create **virtual organisms** from scattered data
- Maintain **live, zero-copy, atomic** projections
- Build **secure, role-based, and contextual views** effortlessly
- Treat complex aggregates as first-class reactive citizens

Blends turn relational complexity into clean, composable, and maintainable synthetic identities — perfectly aligned with the biological architecture of the framework.

**Part of the Cell Framework Documentation**  
**License:** Dual MIT / Apache 2.0
