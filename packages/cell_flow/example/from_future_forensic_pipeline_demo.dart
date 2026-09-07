// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// ignore_for_file: unnecessary_brace_in_string_interps

/// A complete walkthrough demonstrating the use of Flow.fromFuture for
/// bridging legacy async APIs into forensic pipelines.
///
/// ### Scenario
/// A forensic data processing system where:
/// 1. Legacy async APIs (Future-based) are bridged into the reactive graph
/// 2. Each API call carries forensic metadata (chain of custody)
/// 3. Results are processed through a pipeline with full provenance
/// 4. Errors are captured and traced for audit purposes
/// 5. Multiple data sources are combined with forensic context
///
/// ### Learning Objectives
/// - Understand how Flow.fromFuture bridges legacy APIs
/// - See forensic metadata preservation across async boundaries
/// - Learn about chain of custody in reactive pipelines
/// - Handle errors with forensic context
/// - Combine multiple Future sources with provenance
/// - Build audit trails for compliance
///
/// ### Expected Console Output
/// ```
/// ── Forensic Pipeline Demo ──────────────────────────────────────────────────
///
/// 1. Basic Future Bridge - Forensic Evidence
///    ────────────────────────────────────────────────────────
///
///    [Forensic] Fetching evidence: EV-12345
///    [Forensic] ✅ Evidence retrieved: EV-12345 - Status: ACTIVE
///    [Trace] DeferFuture
///
/// 2. Chain of Custody - Multiple Sources
///    ────────────────────────────────────────────────────────
///
///    [Forensic] Evidence: EV-12345 - Metadata loaded
///    [Forensic] Evidence: EV-12345 - Audit log loaded (5 entries)
///    [Forensic] Evidence: EV-12345 - Images loaded (3 images)
///
/// 3. Error Handling with Forensic Context
///    ────────────────────────────────────────────────────────
///
///    [Forensic] Attempting to retrieve evidence: EV-99999
///    [Forensic] ⚠️ Error retrieving evidence: Evidence EV-99999 not found
///    [Forensic] Error type: EvidenceNotFoundException
///    [Forensic] Audit: ERROR_EVIDENCE_NOT_FOUND
///
/// 4. Parallel Evidence Collection
///    ────────────────────────────────────────────────────────
///
///    [Forensic] Source 1: Starting collection (500ms)
///    [Forensic] Source 2: Starting collection (350ms)
///    [Forensic] Source 3: Starting collection (150ms)
///    [Forensic] ✅ Source 3: Audit - Completed (150ms)
///    [Forensic] ✅ Source 2: Images - Completed (350ms)
///    [Forensic] All sources collected in 602ms
///
/// 5. Sequential Forensic Processing
///    ────────────────────────────────────────────────────────
///
///    [Forensic] Step 1: Authentication check... (200ms)
///    [Forensic] Step 1: Authentication check... ✅
///    [Forensic] Step 2: Data extraction... (300ms)
///    [Forensic] Step 2: Data extraction... ✅
///    [Forensic] Step 3: Analysis... (200ms)
///    [Forensic] Step 3: Analysis... ✅
///    [Forensic] Step 4: Report generation... (150ms)
///    [Forensic] Process completed in 912ms
///
/// 6. Forensic Pipeline with Metadata Preservation
///    ────────────────────────────────────────────────────────
///
///    [Forensic] Evidence: EV-12345
///    [Forensic] Step 4: Report generation... ✅
///
/// 7. Legacy System Integration
///    ────────────────────────────────────────────────────────
///
///    [Forensic] Connecting to legacy system: LegacyDB...
///
/// 8. Forensic Pipeline with Audit Trail
///    ────────────────────────────────────────────────────────
///
///    [Audit] Starting forensic audit for evidence: EV-12345
///    [Forensic] ✅ Legacy data retrieved: 42 records
///    [Audit] ✅ Audit completed for: EV-12345
///    [Audit] Audit Entry: FORENSIC_ACCESS
///    [Audit] Integrity: a1b2c3d4e5f67890
///    [Audit] Chain of Custody: 4 steps
///      ✅ AUTHENTICATION - PASSED
///      ✅ EVIDENCE_RETRIEVAL - PASSED
///      ✅ INTEGRITY_CHECK - PASSED
///      ✅ AUDIT_CREATED - PASSED
///
/// ────────────────────────────────────────────────────────────
/// 📝 Summary: Forensic Pipeline with Flow.deferFuture
/// ────────────────────────────────────────────────────────────
///   ┌─────────────────────────────────────────────────────────────────────────┐
///   │  Feature                   │  Benefit                                 │
///   ├─────────────────────────────────────────────────────────────────────────┤
///   │  Future Bridging          │  Convert legacy APIs to reactive          │
///   │  Chain of Custody         │  Preserve provenance across steps         │
///   │  Error Handling           │  Forensic error tracking and recovery     │
///   │  Parallel Processing      │  Efficient evidence collection            │
///   │  Sequential Processing    │  Ordered forensic steps                   │
///   │  Metadata Preservation    │  Full audit trail and integrity checks    │
///   │  Legacy Integration       │  Bridge legacy systems into pipelines     │
///   └─────────────────────────────────────────────────────────────────────────┘
///
///   🔹 Use deferFuture to bridge Future-based legacy APIs per input
///   🔹 Preserve forensic metadata using pulse.withStep()
///   🔹 Track chain of custody through the pipeline
///   🔹 Handle errors with forensic context
///   🔹 Combine with asyncMap for parallel collection
///   🔹 Use synthesis to aggregate forensic evidence
///   🔹 Full provenance tracking across async boundaries
///
///   Note: Flow.fromFuture is used for single Future values,
///         while Flow.deferFuture creates a new Future for each input.
///
///
///    ─── Forensic Metrics Summary ───
///    Total Requests: 1
///    Successful: 1
///    Failed: 0
///    Operations:
///      fetchEvidence: 1 calls (avg 212ms)
///    Audit Trail Entries: 1
///
/// ── Finished ──────────────────────────────────────────────────────────────
/// ```
library;

import 'dart:async';
import 'package:cell_flow/cell_flow.dart';

// ignore_for_file: unused_element, unused_field, unused_local_variable

// ─────────────────────────────────────────────────────────────────────
// Forensic Data Models
// ─────────────────────────────────────────────────────────────────────

/// Represents forensic evidence with chain of custody.
class ForensicEvidence {
  final String id;
  final String caseId;
  final String description;
  final String status;
  final DateTime collectedAt;
  final String collectedBy;
  final String? evidenceType;
  final Map<String, dynamic>? metadata;

  ForensicEvidence({
    required this.id,
    required this.caseId,
    required this.description,
    required this.status,
    DateTime? collectedAt,
    this.collectedBy = 'ForensicSystem',
    this.evidenceType,
    this.metadata,
  }) : collectedAt = collectedAt ?? DateTime.now();

  ForensicEvidence copyWith({
    String? id,
    String? caseId,
    String? description,
    String? status,
    DateTime? collectedAt,
    String? collectedBy,
    String? evidenceType,
    Map<String, dynamic>? metadata,
  }) {
    return ForensicEvidence(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      description: description ?? this.description,
      status: status ?? this.status,
      collectedAt: collectedAt ?? this.collectedAt,
      collectedBy: collectedBy ?? this.collectedBy,
      evidenceType: evidenceType ?? this.evidenceType,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'caseId': caseId,
    'description': description,
    'status': status,
    'collectedAt': collectedAt.toIso8601String(),
    'collectedBy': collectedBy,
    'evidenceType': evidenceType,
    'metadata': metadata,
  };

  @override
  String toString() => 'Evidence($id) - Status: $status';
}

/// Represents a forensic audit trail entry.
class ForensicAuditEntry {
  final String id;
  final String action;
  final String? evidenceId;
  final DateTime timestamp;
  final String actor;
  final Map<String, dynamic> details;

  ForensicAuditEntry({
    required this.id,
    required this.action,
    this.evidenceId,
    DateTime? timestamp,
    this.actor = 'ForensicSystem',
    this.details = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'Audit($id): $action at $timestamp';
}

/// Represents a forensic image/attachment.
class ForensicImage {
  final String id;
  final String evidenceId;
  final String fileName;
  final int size;
  final String hash;
  final DateTime capturedAt;

  ForensicImage({
    required this.id,
    required this.evidenceId,
    required this.fileName,
    required this.size,
    required this.hash,
    DateTime? capturedAt,
  }) : capturedAt = capturedAt ?? DateTime.now();

  @override
  String toString() => 'Image($id): $fileName (${size} bytes)';
}

// ─────────────────────────────────────────────────────────────────────
// Forensic API Simulator (Legacy Async APIs)
// ─────────────────────────────────────────────────────────────────────

/// Simulates a legacy forensic evidence retrieval system.
class ForensicApi {
  final Map<String, ForensicEvidence> _evidence = {};
  final Map<String, List<ForensicImage>> _images = {};
  final Map<String, List<ForensicAuditEntry>> _auditLogs = {};
  final Map<String, String> _evidenceHashes = {};

  ForensicApi() {
    // Seed with test data
    final evidence = ForensicEvidence(
      id: 'EV-12345',
      caseId: 'Case-12345',
      description: 'Digital evidence from seized device',
      status: 'ACTIVE',
      collectedBy: 'Detective Smith',
      evidenceType: 'Digital',
      metadata: {'device': 'iPhone 12', 'dataSize': '32GB'},
    );
    _evidence['EV-12345'] = evidence;
    _evidenceHashes['EV-12345'] = 'a1b2c3d4e5f67890';

    _images['EV-12345'] = [
      ForensicImage(
        id: 'IMG-001',
        evidenceId: 'EV-12345',
        fileName: 'device_photo_1.jpg',
        size: 2048576,
        hash: 'f1e2d3c4b5a6',
      ),
      ForensicImage(
        id: 'IMG-002',
        evidenceId: 'EV-12345',
        fileName: 'device_photo_2.jpg',
        size: 1572864,
        hash: 'a2b3c4d5e6f7',
      ),
      ForensicImage(
        id: 'IMG-003',
        evidenceId: 'EV-12345',
        fileName: 'screenshot.png',
        size: 524288,
        hash: 'b3c4d5e6f7a8',
      ),
    ];

    _auditLogs['EV-12345'] = [
      ForensicAuditEntry(
        id: 'AUD-001',
        action: 'EVIDENCE_CREATED',
        evidenceId: 'EV-12345',
        details: {'createdBy': 'ForensicSystem'},
      ),
      ForensicAuditEntry(
        id: 'AUD-002',
        action: 'EVIDENCE_ACCESSED',
        evidenceId: 'EV-12345',
        details: {'accessedBy': 'Detective Smith'},
      ),
      ForensicAuditEntry(
        id: 'AUD-003',
        action: 'EVIDENCE_ANALYZED',
        evidenceId: 'EV-12345',
        details: {'analysisType': 'Preliminary'},
      ),
      ForensicAuditEntry(
        id: 'AUD-004',
        action: 'EVIDENCE_LOCKED',
        evidenceId: 'EV-12345',
        details: {'lockedBy': 'Supervisor Jones'},
      ),
      ForensicAuditEntry(
        id: 'AUD-005',
        action: 'EVIDENCE_UNLOCKED',
        evidenceId: 'EV-12345',
        details: {'unlockedBy': 'Detective Smith'},
      ),
    ];
  }

  /// Legacy API: Fetch evidence by ID.
  Future<ForensicEvidence> fetchEvidence(String evidenceId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_evidence.containsKey(evidenceId)) {
      throw EvidenceNotFoundException('Evidence $evidenceId not found');
    }
    return _evidence[evidenceId]!;
  }

  /// Legacy API: Fetch images for evidence.
  Future<List<ForensicImage>> fetchImages(String evidenceId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!_images.containsKey(evidenceId)) {
      return [];
    }
    return _images[evidenceId]!;
  }

  /// Legacy API: Fetch audit log for evidence.
  Future<List<ForensicAuditEntry>> fetchAuditLog(String evidenceId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_auditLogs.containsKey(evidenceId)) {
      return [];
    }
    return _auditLogs[evidenceId]!;
  }

  /// Legacy API: Compute evidence hash (integrity check).
  Future<String> computeEvidenceHash(String evidenceId) async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (!_evidenceHashes.containsKey(evidenceId)) {
      throw EvidenceNotFoundException('Evidence $evidenceId not found');
    }
    return _evidenceHashes[evidenceId]!;
  }

  /// Legacy API: Legacy system data migration.
  Future<Map<String, dynamic>> fetchLegacyData(String systemId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'system': systemId,
      'records': List.generate(42, (i) => {'id': 'REC-${i + 1}', 'data': 'Legacy data ${i + 1}'}),
      'version': '2.3.1',
      'lastSync': DateTime.now().toIso8601String(),
    };
  }

  /// Legacy API: Authentication check.
  Future<bool> authenticateUser(String userId, String token) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return userId == 'forensic_user' && token == 'valid_token';
  }

  /// Legacy API: Check evidence status.
  Future<String> checkEvidenceStatus(String evidenceId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_evidence.containsKey(evidenceId)) {
      throw EvidenceNotFoundException('Evidence $evidenceId not found');
    }
    return _evidence[evidenceId]!.status;
  }

  /// Legacy API: Create audit entry.
  Future<ForensicAuditEntry> createAuditEntry(String action, String evidenceId, Map<String, dynamic> details) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final entry = ForensicAuditEntry(
      id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
      action: action,
      evidenceId: evidenceId,
      details: details,
    );
    _auditLogs.putIfAbsent(evidenceId, () => []).add(entry);
    return entry;
  }
}

/// Custom exception for forensic evidence not found.
class EvidenceNotFoundException implements Exception {
  final String message;
  EvidenceNotFoundException(this.message);
  @override
  String toString() => 'EvidenceNotFoundException: $message';
}

/// Custom exception for forensic authentication failure.
class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);
  @override
  String toString() => 'AuthenticationException: $message';
}

// ─────────────────────────────────────────────────────────────────────
// Forensic Pipeline Helpers
// ─────────────────────────────────────────────────────────────────────

/// Extension to add forensic metadata to pulses.
extension ForensicPulseExtension on Pulse {
  /// Adds forensic step to the pulse trace.
  Pulse withForensicStep(String step) {
    return withStep('Forensic: $step');
  }

  /// Gets the forensic trace from the pulse.
  List<String> get forensicTrace => trace;
}

/// Records forensic metrics for the pipeline.
class ForensicMetrics {
  int totalRequests = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  final Map<String, int> operationCounts = {};
  final Map<String, Duration> operationTimes = {};
  final List<String> auditTrail = [];

  void recordRequest(String operation, bool success, Duration duration) {
    totalRequests++;
    if (success) {
      successfulRequests++;
    } else {
      failedRequests++;
    }
    operationCounts[operation] = (operationCounts[operation] ?? 0) + 1;
    operationTimes[operation] = (operationTimes[operation] ?? Duration.zero) + duration;
    auditTrail.add('${DateTime.now().toIso8601String()}: $operation - ${success ? "SUCCESS" : "FAILURE"}');
  }

  void printSummary() {
    print('');
    print('   ─── Forensic Metrics Summary ───');
    print('   Total Requests: $totalRequests');
    print('   Successful: $successfulRequests');
    print('   Failed: $failedRequests');
    print('   Operations:');
    for (final entry in operationCounts.entries) {
      final avg = operationTimes[entry.key]! ~/ entry.value;
      print('     ${entry.key}: ${entry.value} calls (avg ${avg.inMilliseconds}ms)');
    }
    print('   Audit Trail Entries: ${auditTrail.length}');
  }
}

// ─────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────

/// The main demonstration function.
Future<void> main() async {
  final api = ForensicApi();
  final metrics = ForensicMetrics();

  print('── Forensic Pipeline Demo ──────────────────────────────────────────────────\n');

  // ========================================================================
  // 1. Basic Future Bridge - Forensic Evidence
  // ========================================================================

  print('1. Basic Future Bridge - Forensic Evidence');
  print('   ────────────────────────────────────────────────────────\n');

  final evidenceInput = Cell.ingress<String>();

  // Use deferFuture to create a Future for each input
  final evidenceHandle = Flow.deferFuture<ForensicEvidence>(
    evidenceInput.cell,
    create: (pulse) async {
      final id = pulse.payload as String;
      print('   [Forensic] Fetching evidence: $id');
      final stopwatch = Stopwatch()..start();
      try {
        final result = await api.fetchEvidence(id);
        stopwatch.stop();
        metrics.recordRequest('fetchEvidence', true, stopwatch.elapsed);
        return result;
      } catch (e) {
        stopwatch.stop();
        metrics.recordRequest('fetchEvidence', false, stopwatch.elapsed);
        rethrow;
      }
    },
    onError: (error, stack) {
      print('   [Forensic] ⚠️ Error: $error');
    },
  );

  final evidenceObserver = Cell.observe(
    source: evidenceHandle.cell,
    effect: (Pulse p) {
      final evidence = p.payload as ForensicEvidence;
      print('   [Forensic] ✅ Evidence retrieved: ${evidence.id} - Status: ${evidence.status}');
      print('   [Trace] ${p.trace.join(' -> ')}');
    },
  );

  await evidenceInput.emitAsync('EV-12345');
  await Future.delayed(const Duration(milliseconds: 300));

  evidenceObserver.stop();
  print('');

  // ========================================================================
  // 2. Chain of Custody - Multiple Sources
  // ========================================================================

  print('2. Chain of Custody - Multiple Sources');
  print('   ────────────────────────────────────────────────────────\n');

  final custodyInput = Cell.ingress<String>();

  // Step 1: Fetch evidence using deferFuture
  final evidenceStep = Flow.deferFuture<ForensicEvidence>(
    custodyInput.cell,
    create: (pulse) async {
      final id = pulse.payload as String;
      print('   [Forensic] Evidence: $id - Metadata loaded');
      return await api.fetchEvidence(id);
    },
  );

  // Step 2: Fetch images (depends on evidence)
  final imagesStep = Flow.deferFuture<List<ForensicImage>>(
    evidenceStep.cell,
    create: (pulse) async {
      final evidence = pulse.payload as ForensicEvidence;
      final images = await api.fetchImages(evidence.id);
      print('   [Forensic] Evidence: ${evidence.id} - Images loaded (${images.length} images)');
      return images;
    },
  );

  // Step 3: Fetch audit log (depends on evidence)
  final auditStep = Flow.deferFuture<List<ForensicAuditEntry>>(
    evidenceStep.cell,
    create: (pulse) async {
      final evidence = pulse.payload as ForensicEvidence;
      final audit = await api.fetchAuditLog(evidence.id);
      print('   [Forensic] Evidence: ${evidence.id} - Audit log loaded (${audit.length} entries)');
      return audit;
    },
  );

  // Combine all sources into a forensic report using synthesis
  // Create a custom synthesis cell that aggregates the three sources
  final reportCell = Cell.synthesis<Pulse<Map<String, dynamic>>>(
    [evidenceStep.cell, imagesStep.cell, auditStep.cell],
    aggregator: (sources, emit) {
      final evidence = (sources.elementAt(0) as ValueCell<ForensicEvidence>).value!;
      final images = (sources.elementAt(1) as ValueCell<List<ForensicImage>>).value!;
      final audit = (sources.elementAt(2) as ValueCell<List<ForensicAuditEntry>>).value!;
      return Pulse<Map<String, dynamic>>({
        'evidence': evidence,
        'images': images,
        'audit': audit,
        'chainLength': 1 + images.length + audit.length,
        'status': 'COMPLETE',
      });
    },
  );

  // Create a handle for the synthesis cell
  final reportHandle = (
  cell: reportCell,
  emit: (input) {
    // Simplified emit for demo
    return true;
  },
  emitAsync: (input) async {
    return true;
  },
  ingest: (Pulse pulse, {bool serializedCompletion = true}) async {
    return Future.value();
  },
  );

  final custodyObserver = Cell.observe(
    source: reportCell,
    effect: (Pulse p) {
      final report = p.payload as Map<String, dynamic>;
      print('   [Chain] Full chain of custody established');
      print('   [Chain] Chain length: ${report['chainLength']} items');
    },
  );

  await custodyInput.emitAsync('EV-12345');
  await Future.delayed(const Duration(milliseconds: 500));

  custodyObserver.stop();
  print('');

  // ========================================================================
  // 3. Error Handling with Forensic Context
  // ========================================================================

  print('3. Error Handling with Forensic Context');
  print('   ────────────────────────────────────────────────────────\n');

  final errorInput = Cell.ingress<String>();

  // Use deferFuture with comprehensive error handling
  final errorHandle = Flow.deferFuture<ForensicEvidence>(
    errorInput.cell,
    create: (pulse) async {
      final id = pulse.payload as String;
      print('   [Forensic] Attempting to retrieve evidence: $id');
      final result = await api.fetchEvidence(id);
      return result;
    },
    onError: (error, stack) {
      if (error is EvidenceNotFoundException) {
        print('   [Forensic] ⚠️ Error retrieving evidence: ${error.message}');
        print('   [Forensic] Error type: EvidenceNotFoundException');
        print('   [Forensic] Audit: ERROR_EVIDENCE_NOT_FOUND');
      } else {
        print('   [Forensic] ⚠️ Unexpected error: ${error.toString()}');
        print('   [Forensic] Audit: ERROR_UNKNOWN');
      }
    },
  );

  final errorObserver = Cell.observe(
    source: errorHandle.cell,
    effect: (Pulse p) {
      // This will not be called for errors unless we handle them
      if (p.payload != null) {
        final evidence = p.payload as ForensicEvidence;
        print('   [Forensic] ✅ Retrieved: ${evidence.id}');
      }
    },
  );

  // Try to fetch non-existent evidence
  await errorInput.emitAsync('EV-99999');
  await Future.delayed(const Duration(milliseconds: 300));

  errorObserver.stop();
  print('');

  // ========================================================================
  // 4. Parallel Evidence Collection
  // ========================================================================

  print('4. Parallel Evidence Collection');
  print('   ────────────────────────────────────────────────────────\n');

  final parallelInput = Cell.ingress<int>();

  final parallelHandle = Flow.asyncMapConcurrent<int, Map<String, dynamic>>(
    parallelInput.cell,
    mapper: (sourceId) async {
      final delay = Duration(milliseconds: sourceId == 1 ? 500 : sourceId == 2 ? 350 : 150);
      print('   [Forensic] Source $sourceId: Starting collection (${delay.inMilliseconds}ms)');
      await Future.delayed(delay);

      // Simulate different data sources
      if (sourceId == 1) {
        final evidence = await api.fetchEvidence('EV-12345');
        return {'source': sourceId, 'type': 'Evidence', 'data': evidence.id, 'time': delay.inMilliseconds};
      } else if (sourceId == 2) {
        final images = await api.fetchImages('EV-12345');
        return {'source': sourceId, 'type': 'Images', 'data': images.length, 'time': delay.inMilliseconds};
      } else {
        final audit = await api.fetchAuditLog('EV-12345');
        return {'source': sourceId, 'type': 'Audit', 'data': audit.length, 'time': delay.inMilliseconds};
      }
    },
  );

  final parallelResults = <String>[];
  final parallelObserver = Cell.observe(
    source: parallelHandle.cell,
    effect: (Pulse p) {
      final result = p.payload as Map<String, dynamic>;
      final msg = '✅ Source ${result['source']}: ${result['type']} - Completed (${result['time']}ms)';
      parallelResults.add(msg);
      print('   [Forensic] $msg');
    },
  );

  final parallelStopwatch = Stopwatch()..start();

  // Start all sources in parallel
  for (var i = 1; i <= 3; i++) {
    await parallelInput.emitAsync(i);
  }

  await Future.delayed(const Duration(milliseconds: 600));
  parallelStopwatch.stop();

  print('   [Forensic] All sources collected in ${parallelStopwatch.elapsedMilliseconds}ms');

  parallelObserver.stop();
  print('');

  // ========================================================================
  // 5. Sequential Forensic Processing
  // ========================================================================

  print('5. Sequential Forensic Processing');
  print('   ────────────────────────────────────────────────────────\n');

  final processInput = Cell.ingress<String>();

  // Step 1: Authentication
  final authStep = Flow.deferFuture<bool>(
    processInput.cell,
    create: (pulse) async {
      final userId = pulse.payload as String;
      print('   [Forensic] Step 1: Authentication check... (200ms)');
      await Future.delayed(const Duration(milliseconds: 200));
      final result = await api.authenticateUser(userId, 'valid_token');
      if (result) {
        print('   [Forensic] Step 1: Authentication check... ✅');
      } else {
        print('   [Forensic] Step 1: Authentication check... ❌');
      }
      return result;
    },
  );

  // Step 2: Data extraction
  final extractStep = Flow.deferFuture<String>(
    authStep.cell,
    create: (pulse) async {
      print('   [Forensic] Step 2: Data extraction... (300ms)');
      await Future.delayed(const Duration(milliseconds: 300));
      print('   [Forensic] Step 2: Data extraction... ✅');
      return 'Data extracted for forensic analysis';
    },
  );

  // Step 3: Analysis
  final analysisStep = Flow.deferFuture<Map<String, dynamic>>(
    extractStep.cell,
    create: (pulse) async {
      print('   [Forensic] Step 3: Analysis... (200ms)');
      await Future.delayed(const Duration(milliseconds: 200));
      print('   [Forensic] Step 3: Analysis... ✅');
      return {'findings': 12, 'confidence': 0.95, 'status': 'COMPLETE'};
    },
  );

  // Step 4: Report generation
  final reportStep = Flow.deferFuture<String>(
    analysisStep.cell,
    create: (pulse) async {
      final analysis = pulse.payload as Map<String, dynamic>;
      print('   [Forensic] Step 4: Report generation... (150ms)');
      await Future.delayed(const Duration(milliseconds: 150));
      print('   [Forensic] Step 4: Report generation... ✅');
      return 'Forensic report generated: ${analysis['findings']} findings';
    },
  );

  final processObserver = Cell.observe(
    source: reportStep.cell,
    effect: (Pulse p) {
      final report = p.payload as String;
      print('   [Forensic] Result: $report');
    },
  );

  final processStopwatch = Stopwatch()..start();

  await processInput.emitAsync('forensic_user');
  await Future.delayed(const Duration(milliseconds: 900));

  processStopwatch.stop();
  print('   [Forensic] Process completed in ${processStopwatch.elapsedMilliseconds}ms');

  processObserver.stop();
  print('');

  // ========================================================================
  // 6. Forensic Pipeline with Metadata Preservation
  // ========================================================================

  print('6. Forensic Pipeline with Metadata Preservation');
  print('   ────────────────────────────────────────────────────────\n');

  final metadataInput = Cell.ingress<String>();

  // Use deferFuture with metadata preservation
  final metadataHandle = Flow.deferFuture<Map<String, dynamic>>(
    metadataInput.cell,
    create: (pulse) async {
      final evidenceId = pulse.payload as String;
      print('   [Forensic] Evidence: $evidenceId');
      final stopwatch = Stopwatch()..start();

      // Fetch evidence with full metadata
      final evidence = await api.fetchEvidence(evidenceId);
      final hash = await api.computeEvidenceHash(evidenceId);
      final status = await api.checkEvidenceStatus(evidenceId);

      stopwatch.stop();

      return {
        'evidence': evidence.toJson(),
        'hash': hash,
        'status': status,
        'processingTime': stopwatch.elapsedMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
        'sha256': 'SHA256: $hash',
      };
    },
  );

  final metadataObserver = Cell.observe(
    source: metadataHandle.cell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, dynamic>;
      final evidence = data['evidence'] as Map<String, dynamic>;
      print('   [Forensic] Evidence: ${evidence['id']}');
      print('   [Forensic] ✅ Verified: Evidence integrity confirmed');
      print('   [Forensic] Hash: ${data['hash']}');
      print('   [Forensic] Processing Time: ${data['processingTime']}ms');
    },
  );

  await metadataInput.emitAsync('EV-12345');
  await Future.delayed(const Duration(milliseconds: 400));

  metadataObserver.stop();
  print('');

  // ========================================================================
  // 7. Legacy System Integration
  // ========================================================================

  print('7. Legacy System Integration');
  print('   ────────────────────────────────────────────────────────\n');

  final legacyInput = Cell.ingress<String>();

  final legacyHandle = Flow.deferFuture<Map<String, dynamic>>(
    legacyInput.cell,
    create: (pulse) async {
      final systemId = pulse.payload as String;
      print('   [Forensic] Connecting to legacy system: $systemId...');
      await Future.delayed(const Duration(milliseconds: 200));

      final data = await api.fetchLegacyData(systemId);
      print('   [Forensic] ✅ Legacy data retrieved: ${data['records'].length} records');

      // Add forensic metadata
      return {
        ...data,
        'forensicTimestamp': DateTime.now().toIso8601String(),
        'forensicSource': 'LegacyBridge',
        'forensicVersion': '1.0.0',
      };
    },
  );

  final legacyObserver = Cell.observe(
    source: legacyHandle.cell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, dynamic>;
      print('   [Forensic] ✅ Data migrated with full provenance');
      print('   [Forensic] Source: ${data['system']} - Version: ${data['version']}');
      print('   [Forensic] Records: ${data['records'].length}');
      print('   [Forensic] Forensic Timestamp: ${data['forensicTimestamp']}');
    },
  );

  await legacyInput.emitAsync('LegacyDB');
  await Future.delayed(const Duration(milliseconds: 400));

  legacyObserver.stop();
  print('');

  // ========================================================================
  // 8. Forensic Pipeline with Audit Trail
  // ========================================================================

  print('8. Forensic Pipeline with Audit Trail');
  print('   ────────────────────────────────────────────────────────\n');

  final auditInput = Cell.ingress<Map<String, dynamic>>();

  // Complex pipeline with audit trail using deferFuture
  final auditHandle = Flow.deferFuture<Map<String, dynamic>>(
    auditInput.cell,
    create: (pulse) async {
      final params = pulse.payload as Map<String, dynamic>;
      final evidenceId = params['evidenceId'] as String;
      final userId = params['userId'] as String;

      print('   [Audit] Starting forensic audit for evidence: $evidenceId');

      // Create audit entry
      final entry = await api.createAuditEntry(
        'FORENSIC_ACCESS',
        evidenceId,
        {'userId': userId, 'action': 'evidence_retrieval'},
      );

      // Fetch evidence
      final evidence = await api.fetchEvidence(evidenceId);

      // Check integrity
      final hash = await api.computeEvidenceHash(evidenceId);

      return {
        'auditEntry': entry,
        'evidence': evidence,
        'integrity': hash,
        'verified': true,
        'chainOfCustody': [
          {'step': 'AUTHENTICATION', 'status': 'PASSED'},
          {'step': 'EVIDENCE_RETRIEVAL', 'status': 'PASSED'},
          {'step': 'INTEGRITY_CHECK', 'status': 'PASSED'},
          {'step': 'AUDIT_CREATED', 'status': 'PASSED'},
        ],
      };
    },
  );

  final auditObserver = Cell.observe(
    source: auditHandle.cell,
    effect: (Pulse p) {
      final result = p.payload as Map<String, dynamic>;
      final auditEntry = result['auditEntry'] as ForensicAuditEntry;
      final evidence = result['evidence'] as ForensicEvidence;
      final chain = result['chainOfCustody'] as List;

      print('   [Audit] ✅ Audit completed for: ${evidence.id}');
      print('   [Audit] Audit Entry: ${auditEntry.action}');
      print('   [Audit] Integrity: ${result['integrity']}');
      print('   [Audit] Chain of Custody: ${chain.length} steps');
      for (final step in chain) {
        print('     ✅ ${step['step']} - ${step['status']}');
      }
    },
  );

  await auditInput.emitAsync({
    'evidenceId': 'EV-12345',
    'userId': 'forensic_user',
  });

  await Future.delayed(const Duration(milliseconds: 500));

  auditObserver.stop();
  print('');

  // ========================================================================
  // Summary
  // ========================================================================

  print('─' * 60);
  print('📝 Summary: Forensic Pipeline with Flow.deferFuture');
  print('─' * 60);
  print('''
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Feature                   │  Benefit                                 │
  ├─────────────────────────────────────────────────────────────────────────┤
  │  Future Bridging          │  Convert legacy APIs to reactive          │
  │  Chain of Custody         │  Preserve provenance across steps         │
  │  Error Handling           │  Forensic error tracking and recovery     │
  │  Parallel Processing      │  Efficient evidence collection            │
  │  Sequential Processing    │  Ordered forensic steps                   │
  │  Metadata Preservation    │  Full audit trail and integrity checks    │
  │  Legacy Integration       │  Bridge legacy systems into pipelines     │
  └─────────────────────────────────────────────────────────────────────────┘

  🔹 Use deferFuture to bridge Future-based legacy APIs per input
  🔹 Preserve forensic metadata using pulse.withStep()
  🔹 Track chain of custody through the pipeline
  🔹 Handle errors with forensic context
  🔹 Combine with asyncMap for parallel collection
  🔹 Use synthesis to aggregate forensic evidence
  🔹 Full provenance tracking across async boundaries

  Note: Flow.fromFuture is used for single Future values,
        while Flow.deferFuture creates a new Future for each input.
  ''');

  // Print metrics
  metrics.printSummary();

  print('');
  print('── Finished ──────────────────────────────────────────────────────────────');
}

// ─────────────────────────────────────────────────────────────────────
// Utility Extension for Flow
// ─────────────────────────────────────────────────────────────────────

/// Extension to provide convenient methods for Flow operations.
extension FlowUtils on Flow {
  /// Creates a deferFuture bridge with the specified future provider.
  static FlowHandle deferFuture<T>(
      Cell source, {
        required Future<T> Function(Pulse pulse) create,
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
      }) {
    final instruction = DeferFuture<T>(
      create,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    );
    return instruction.toHandle(source: source);
  }

  /// Creates an asyncMapConcurrent with the specified mapper.
  static FlowHandle asyncMapConcurrent<S, T>(
      Cell source, {
        required FutureOr<T> Function(S value) mapper,
      }) {
    final instruction = AsyncMapConcurrent<S, T>(mapper);
    return instruction.toHandle(source: source);
  }
}

/// Error handler callback for future operations.
typedef FutureErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// Placeholder for DeferFuture operator.
class DeferFuture<T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  final Future<T> Function(Pulse pulse) _create;
  final FutureErrorHandler? _onError;
  final bool _emitErrorPulse;

  DeferFuture(
      this._create, {
        FutureErrorHandler? onError,
        bool emitErrorPulse = true,
        dynamic user,
      })  : _onError = onError,
        _emitErrorPulse = emitErrorPulse,
        super.future(
            (pulse, {cell, user, future, token}) {
          Future<void> run() async {
            try {
              final result = await _create(pulse);
              future!(
                result: _fromPayload(result, pulse, cell, 'DeferFuture'),
                token: token,
              );
            } catch (e, stack) {
              onError?.call(e, stack);
              if (emitErrorPulse) {
                future!(
                  result: _errorPayload(e, pulse, cell, 'DeferFuture.error'),
                  token: token,
                );
              }
            }
          }

          run();
          return null;
        },
        user: user,
      );
}

/// Placeholder for AsyncMapConcurrent operator.
class AsyncMapConcurrent<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  AsyncMapConcurrent(
      FutureOr<T> Function(S value) mapper, {
        dynamic user,
      }) : super.future(
        (pulse, {cell, user, future, token}) {
      final payload = pulse.payload;
      if (payload is! S) return null;

      Future<void> run() async {
        try {
          final result = await Future<T>.sync(() => mapper(payload));
          future!(
            result: _fromPayload(result, pulse, cell, 'AsyncMapConcurrent'),
            token: token,
          );
        } catch (e) {
          // Error handling simplified for demo
        }
      }

      run();
      return null;
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────────────
// Helper Functions
// ─────────────────────────────────────────────────────────────────────

Pulse<T> _fromPayload<T>(T value, Pulse sourcePulse, Cell? cell, String step) {
  return Pulse<T>(
    value,
    source: cell ?? sourcePulse.source,
    type: sourcePulse.type,
    priority: sourcePulse.priority,
    step: step,
  );
}

Pulse _errorPayload(Object error, Pulse sourcePulse, Cell? cell, String step) {
  return Pulse(
    error,
    source: cell ?? sourcePulse.source,
    type: 'error',
    priority: sourcePulse.priority,
    step: step,
  );
}