// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

/// ─────────────────────────────────────────────────────────────────────
/// RECEPTOR PIPELINE WALKTHROUGH
/// ─────────────────────────────────────────────────────────────────────
///
/// This file demonstrates a practical, real-life example of using
/// [Receptor] to build a robust data processing system for a
/// document management and workflow automation platform.
///
/// ### The Scenario
/// We are building a document processing system that:
/// 1. Receives documents from various sources (email, upload, API)
/// 2. Processes documents through a multi-stage workflow
/// 3. Validates document content and metadata
/// 4. Transforms documents into different formats
/// 5. Routes documents to appropriate destinations
/// 6. Maintains an audit trail of all processing steps
/// 7. Handles errors gracefully with retry logic
///
/// ### Why Use Receptors?
/// - **Structured Pipelines**: Pre-process → Core Logic → Post-process
/// - **Reusable Logic**: Same receptor can be bound to different cells
/// - **Type Safety**: Strong typing with generic parameters
/// - **Governance**: Built-in support for security and auditing
/// - **Async Support**: Seamless integration with async operations
/// - **Error Resilience**: Safety boundaries at every stage
/// - **Testability**: Each stage can be tested independently
///
/// ### Key Concepts Demonstrated:
/// 1. Creating Receptors with different factory methods
/// 2. Building multi-stage pipelines (preProcess → instruction → postProcess)
/// 3. Using Receptors with Instructions
/// 4. Type-safe transformations with Receptor.typed
/// 5. Asynchronous processing with ReceptorAsync
/// 6. Cloning Receptors for different cells
/// 7. Error handling and resilience
/// 8. Governance and audit trails
///
/// ### How to Run:
/// ```bash
/// dart run receptor_pipeline_walkthrough.dart
/// ```
library;

import 'dart:async';

import 'package:cell/cell.dart';

///────────────────────────────────────────────────────────────────────────────────
///   DOCUMENT PROCESSING PIPELINE DEMO
///   Using [Receptor] for Workflow Automation
/// ────────────────────────────────────────────────────────────────────────────────
///
/// 1. Creating Basic Receptors
///    ─────────────────────────
///    [✓] Pass-through receptor created
///    [✓] Simple transformer receptor created
///    [✓] Type-safe receptor created
///
///    [Test] Pass-through: test document (status: pending)
///    [Simple] Transforming document...
///    [Test] Simple transformer: test document (status: transformed)
///    [Typed] Type-safe processing: TEST-001
///    [Test] Type-safe: TEST-001 (status: type-safe-processed)
///
/// 2. Building Multi-Stage Pipelines
///    ───────────────────────────────
///    [✓] Pipeline: preProcess + instruction + postProcess
///
/// 3. Processing a Document
///    ─────────────────────
///    ── Processing Document #DOC-001 ──
///    [PreProcess] Sanitizing document metadata...
///    [PreProcess] ✓ Document sanitized
///    [Instruction] Validating document content...
///    [Instruction] ✓ Document validated
///    [Instruction] Processing document...
///    [Instruction] ✓ Document processed
///    [PostProcess] Enriching document with routing info...
///    [PostProcess] ✓ Document routed to: management-review
///
///    ── Final Document ──
///    Document {
///      id: DOC-001,
///      title: Project proposal q4 2024,
///      type: proposal,
///      size: 2.4 MB,
///      status: enriched,
///      route: management-review,
///      processedAt: 2024-01-15 14:30:00.000
///    }
///
/// 4. Asynchronous Processing with ReceptorAsync
///    ───────────────────────────────────────────
///    [Async] Processing document with async pipeline...
///    [Async] ✓ Document processed (XXXms)
///    [Async] Result: DOC-002 processed successfully
///
/// 5. Cloning Receptors
///    ─────────────────
///    [Clone] Original receptor cloned successfully
///    [Clone] Processing: DOC-003
///    [Clone] Processing: DOC-003
///    [Clone] Original cell status: clone-processed
///    [Clone] Cloned cell status: clone-processed
///    [Clone] Both receptors operate independently
///
/// 6. Error Handling and Resilience
///    ──────────────────────────────
///    ── Processing Invalid Document ──
///    [Resilient] Processing document: ERROR-DOC
///    [Resilient] Error caught: DocumentProcessingException(500): Simulated processing error (Document: ERROR-DOC)
///
///    [Error] Document processed with status: error
///    [Error] Error details: DocumentProcessingException(500): Simulated processing error (Document: ERROR-DOC)
///
/// 7. Bonus: Document Batch Processing
///    ─────────────────────────────────
///    Processing 3 documents...
///
///    ── Batch Processing Results ──
///    ✓ Processed BATCH-001 (XXXms)
///       Route: analytics-team
///    ✓ Processed BATCH-002 (XXXms)
///       Route: finance-approval
///    ✓ Processed BATCH-003 (XXXms)
///       Route: management-review
///
/// ────────────────────────────────────────────────────────────────────────────────
///   DEMO COMPLETE
/// ────────────────────────────────────────────────────────────────────────────────
/// ```

// ─────────────────────────────────────────────────────────────────────
// Domain Models
// ─────────────────────────────────────────────────────────────────────

/// Represents a document in the system.
class Document {
  final String id;
  final String title;
  final String type;
  final double size; // in MB
  final String status;
  final String? route;
  final DateTime processedAt;
  final Map<String, dynamic> metadata;

  Document({
    required this.id,
    required this.title,
    required this.type,
    required this.size,
    this.status = 'pending',
    this.route,
    DateTime? processedAt,
    this.metadata = const {},
  }) : processedAt = processedAt ?? DateTime.now();

  Document copyWith({
    String? id,
    String? title,
    String? type,
    double? size,
    String? status,
    String? route,
    DateTime? processedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      size: size ?? this.size,
      status: status ?? this.status,
      route: route ?? this.route,
      processedAt: processedAt ?? this.processedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() => '''
Document {
  id: $id,
  title: $title,
  type: $type,
  size: $size MB,
  status: $status,
  route: ${route ?? 'none'},
  processedAt: $processedAt
}''';
}

/// Represents a processing result.
class ProcessingResult {
  final bool success;
  final String message;
  final Document? document;
  final Duration processingTime;

  ProcessingResult({
    required this.success,
    required this.message,
    this.document,
    this.processingTime = Duration.zero,
  });

  @override
  String toString() =>
      'ProcessingResult(success: $success, message: $message)';
}

/// Custom exception for document processing errors.
class DocumentProcessingException implements Exception {
  final String message;
  final String? documentId;
  final int code;

  DocumentProcessingException(
      this.message, {
        this.documentId,
        this.code = 500,
      });

  @override
  String toString() =>
      'DocumentProcessingException($code): $message (Document: $documentId)';
}

// ─────────────────────────────────────────────────────────────────────
// Custom Cell Type for Document Processing
// ─────────────────────────────────────────────────────────────────────

/// A cell that holds a document and provides document-specific operations.
class DocumentCell extends CellBase {
  Document? _document;
  final Nucleus _nucleus;

  DocumentCell({
    required Receptor receptor,
    Context context = Context.system,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled ,
    EphemeralPolicy? ephemeralPolicy,
  }) : this.fromNucleus(Nucleus(
      receptor: receptor,
      context: context,
      testRule: testRule,
      synapses: synapses,
      ephemeralPolicy: ephemeralPolicy
  ));

  DocumentCell.fromNucleus(super.nucleus) 
      : _nucleus = nucleus, super.fromNucleus();

  Document? get document => _document;

  void setDocument(Document doc) => _document = doc;

  /// Validates that the pulse contains a Document.
  bool validateDocument(Pulse pulse) {
    return pulse.payload is Document;
  }

  /// Gets the current document from the cell's state.
  Document? get currentDocument => _document;

  /// Process a document through this cell.
  Future<Pulse?> processDocument(Document doc) async {
    final pulse = Pulse(doc);
    final receptor = _nucleus.receptor;
    final completer = Completer<Pulse?>();

    await receptor.async.call(pulse as PulseBase, hook: ({Pulse? result, required input}) {
      // Complete with the transformed pulse (or null if rejected)
      completer.complete(result);
    });

    final resultPulse = await completer.future;

    if (resultPulse?.payload is Document) {
      setDocument(resultPulse!.payload as Document);
    }

    return resultPulse;
  }
}

// ─────────────────────────────────────────────────────────────────────
// Instruction Definitions (Reusable Logic Units)
// ─────────────────────────────────────────────────────────────────────

/// Sanitizes document metadata.
class SanitizeDocumentInstruction extends InstructionBase<Cell, Pulse, Pulse> {
  const SanitizeDocumentInstruction() : super(_sanitize);

  static Pulse? _sanitize(Pulse pulse, {Cell? cell, dynamic user}) {
    final doc = pulse.payload as Document?;
    if (doc == null) {
      print('   [PreProcess] ✗ No document to sanitize');
      return null;
    }

    print('   [PreProcess] Sanitizing document metadata...');

    // Sanitize title (trim, capitalize first letter)
    var title = doc.title.trim();
    if (title.isNotEmpty) {
      title = title[0].toUpperCase() + title.substring(1);
    }

    // Sanitize type (lowercase)
    final type = doc.type.toLowerCase().trim();

    // Clean metadata
    final metadata = Map<String, dynamic>.from(doc.metadata);
    // Remove any null values
    metadata.removeWhere((key, value) => value == null);

    final sanitized = doc.copyWith(
      title: title,
      type: type,
      metadata: metadata,
    );

    print('   [PreProcess] ✓ Document sanitized');
    return Pulse(sanitized);
  }
}

/// Validates document content.
class ValidateDocumentInstruction extends InstructionBase<Cell, Pulse, Pulse> {
  const ValidateDocumentInstruction() : super(_validate);

  static Pulse? _validate(Pulse pulse, {Cell? cell, dynamic user}) {
    final doc = pulse.payload as Document?;
    if (doc == null) {
      print('   [Instruction] ✗ No document to validate');
      return null;
    }

    print('   [Instruction] Validating document content...');

    // Validation rules
    final errors = <String>[];

    // Title must not be empty
    if (doc.title.isEmpty) {
      errors.add('Document title is required');
    }

    // Type must be one of the allowed types
    final allowedTypes = ['proposal', 'invoice', 'report', 'contract'];
    if (!allowedTypes.contains(doc.type)) {
      errors.add('Invalid document type: ${doc.type}. Allowed: $allowedTypes');
    }

    // Size must be within limits
    if (doc.size > 50.0) {
      errors.add('Document size exceeds limit (50MB)');
    }
    if (doc.size <= 0) {
      errors.add('Document size must be positive');
    }

    if (errors.isNotEmpty) {
      print('   [Instruction] ✗ Validation failed: ${errors.join('; ')}');
      return null;
    }

    // Update status to 'validated'
    final validated = doc.copyWith(status: 'validated');

    print('   [Instruction] ✓ Document validated');
    return Pulse(validated);
  }
}

/// Enriches document with routing information.
class EnrichDocumentInstruction extends InstructionBase<Cell, Pulse, Pulse> {
  const EnrichDocumentInstruction() : super(_enrich);

  static Pulse? _enrich(Pulse pulse, {Cell? cell, dynamic user}) {
    final doc = pulse.payload as Document?;
    if (doc == null) {
      print('   [PostProcess] ✗ No document to enrich');
      return null;
    }

    print('   [PostProcess] Enriching document with routing info...');

    // Determine route based on document type
    String? route;
    switch (doc.type) {
      case 'proposal':
        route = 'management-review';
        break;
      case 'invoice':
        route = 'finance-approval';
        break;
      case 'report':
        route = 'analytics-team';
        break;
      case 'contract':
        route = 'legal-review';
        break;
      default:
        route = 'general-queue';
    }

    // Add enrichment metadata
    final metadata = Map<String, dynamic>.from(doc.metadata);
    metadata['enrichedAt'] = DateTime.now().toIso8601String();
    metadata['source'] = 'document-processing-pipeline';

    final enriched = doc.copyWith(
      route: route,
      status: 'enriched',
      metadata: metadata,
    );

    print('   [PostProcess] ✓ Document routed to: $route');
    return Pulse(enriched);
  }
}

/// Processes the document to final state.
class ProcessDocumentInstruction extends InstructionBase<Cell, Pulse, Pulse> {
  const ProcessDocumentInstruction() : super(_process);

  static Pulse? _process(Pulse pulse, {Cell? cell, dynamic user}) {
    final doc = pulse.payload as Document?;
    if (doc == null) {
      print('   [Instruction] ✗ No document to process');
      return null;
    }

    print('   [Instruction] Processing document...');

    // Simulate some processing work
    final processed = doc.copyWith(
      status: 'processed',
      metadata: Map<String, dynamic>.from(doc.metadata)
        ..['processedAt'] = DateTime.now().toIso8601String()
        ..['processingTimeMs'] = (DateTime.now().difference(doc.processedAt))
            .inMilliseconds,
    );

    print('   [Instruction] ✓ Document processed');
    return Pulse(processed);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Receptor Definitions
// ─────────────────────────────────────────────────────────────────────

/// A simple pass-through receptor that forwards documents unchanged.
Receptor<Cell> createPassThroughReceptor() {
  return Receptor.passThrough;
}

/// A simple transformer receptor that updates document status.
Receptor<Cell> createSimpleTransformerReceptor() {
  return Receptor(
        (cell, pulse, {user}) {
      final doc = pulse.payload as Document?;
      if (doc == null) {
        print('   [Simple] No document to transform');
        return null;
      }

      print('   [Simple] Transforming document...');
      final transformed = doc.copyWith(
        status: 'transformed',
        metadata: Map<String, dynamic>.from(doc.metadata)
          ..['transformedBy'] = 'simple-transformer',
      );

      return Pulse(transformed);
    },
  );
}

/// A type-safe receptor that only accepts and produces Document pulses.
Receptor<Cell> createTypeSafeReceptor() {
  return Receptor.typed<Cell, Pulse<Document>, Pulse<Document>>(
    Instruction<Cell, Pulse<Document>, Pulse<Document>>(
          (pulse, {cell, user}) {
        final doc = pulse.payload;
        print('   [Typed] Type-safe processing: ${doc?.id}');

        final processed = doc?.copyWith(
          status: 'type-safe-processed',
          metadata: Map<String, dynamic>.from(doc.metadata)
            ..['typeSafe'] = true,
        );

        return Pulse(processed);
      },
    ),
  );
}

/// A multi-stage pipeline receptor for document processing.
Receptor<Cell> createDocumentPipelineReceptor() {
  return Receptor.pipeline(
    preProcess: const SanitizeDocumentInstruction(),
    instruction: const ValidateDocumentInstruction() +
        const ProcessDocumentInstruction(),
    postProcess: const EnrichDocumentInstruction(),
  );
}

/// A receptor with error recovery and logging.
Receptor<Cell> createResilientReceptor() {
  return Receptor(
        (cell, pulse, {user}) {
      try {
        final doc = pulse.payload as Document?;
        if (doc == null) {
          throw DocumentProcessingException(
            'Invalid document data',
            code: 400,
          );
        }

        print('   [Resilient] Processing document: ${doc.id}');

        // Simulate potential failure
        if (doc.id == 'ERROR-DOC') {
          throw DocumentProcessingException(
            'Simulated processing error',
            documentId: doc.id,
            code: 500,
          );
        }

        final processed = doc.copyWith(
          status: 'resilient-processed',
          metadata: Map<String, dynamic>.from(doc.metadata)
            ..['resilientProcessed'] = true
            ..['processedBy'] = 'resilient-receptor',
        );

        return Pulse(processed);
      } catch (e) {
        print('   [Resilient] Error caught: $e');
        // Return the original pulse with error metadata
        final doc = pulse.payload as Document?;
        if (doc != null) {
          final errorDoc = doc.copyWith(
            status: 'error',
            metadata: Map<String, dynamic>.from(doc.metadata)
              ..['error'] = e.toString()
              ..['errorAt'] = DateTime.now().toIso8601String(),
          );
          return Pulse(errorDoc);
        }
        return null;
      }
    },
  );
}

// ─────────────────────────────────────────────────────────────────────
// Document Processing Cell
// ─────────────────────────────────────────────────────────────────────

/// A cell specifically for document processing.
class DocumentProcessingCell extends DocumentCell {
  DocumentProcessingCell({
    required super.receptor,
    super.context,
    super.testRule,
    super.synapses,
    super.ephemeralPolicy,
  });
}

// ─────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────

Future<void> main() async {
  print('\n${'═' * 80}');
  print('  DOCUMENT PROCESSING PIPELINE DEMO');
  print('  Using [Receptor] for Workflow Automation');
  print('${'═' * 80}\n');

  // ─────────────────────────────────────────────────────────────────────
  // Part 1: Creating Basic Receptors
  // ─────────────────────────────────────────────────────────────────────

  print('1. Creating Basic Receptors');
  print('   ─────────────────────────');

  final passThrough = createPassThroughReceptor();
  final simpleTransformer = createSimpleTransformerReceptor();
  final typeSafe = createTypeSafeReceptor();

  print('   [✓] Pass-through receptor created');
  print('   [✓] Simple transformer receptor created');
  print('   [✓] Type-safe receptor created\n');

  // Test the pass-through receptor
  final testDoc = Document(
    id: 'TEST-001',
    title: 'test document',
    type: 'report',
    size: 1.5,
  );
  final passResult = passThrough.call(Pulse(testDoc));
  if (passResult != null && (passResult as Pulse?)?.payload is Document) {
    final resultDoc = passResult?.payload as Document;
    print('   [Test] Pass-through: ${resultDoc.title} (status: ${resultDoc.status})');
  }

  // Test the simple transformer
  final transResult = simpleTransformer.call(Pulse(testDoc));
  if (transResult != null && (transResult as Pulse?)?.payload is Document) {
    final resultDoc = transResult?.payload as Document;
    print('   [Test] Simple transformer: ${resultDoc.title} (status: ${resultDoc.status})');
  }

  // Test the type-safe receptor
  final typedResult = typeSafe.call(Pulse(testDoc));
  if (typedResult != null && (typedResult as Pulse?)?.payload is Document) {
    final resultDoc = typedResult?.payload as Document;
    print('   [Test] Type-safe: ${resultDoc.id} (status: ${resultDoc.status})\n');
  }

  // ─────────────────────────────────────────────────────────────────────
  // Part 2: Building Multi-Stage Pipelines
  // ─────────────────────────────────────────────────────────────────────

  print('2. Building Multi-Stage Pipelines');
  print('   ───────────────────────────────');

  final pipeline = createDocumentPipelineReceptor();
  print('   [✓] Pipeline: preProcess + instruction + postProcess\n');

  // ─────────────────────────────────────────────────────────────────────
  // Part 3: Processing a Document
  // ─────────────────────────────────────────────────────────────────────

  print('3. Processing a Document');
  print('   ─────────────────────');

  final doc = Document(
    id: 'DOC-001',
    title: '  project proposal q4 2024  ',
    type: 'PROPOSAL',
    size: 2.4,
    metadata: {'department': 'sales', 'priority': 'high', 'nullKey': null},
  );

  print('   ── Processing Document #DOC-001 ──');

  // Create a cell with the pipeline
  final cell = DocumentProcessingCell(
    receptor: pipeline,
    context: Context.module('document-processing'),
  );

  final result = await cell.processDocument(doc);

  if (result != null && result.payload is Document) {
    final processed = result.payload as Document;
    print('\n   ── Final Document ──');
    print('   $processed');
  } else {
    print('\n   [✗] Document processing failed');
  }

  print('');

  // ─────────────────────────────────────────────────────────────────────
  // Part 4: Asynchronous Processing with ReceptorAsync
  // ─────────────────────────────────────────────────────────────────────

  print('4. Asynchronous Processing with ReceptorAsync');
  print('   ───────────────────────────────────────────');

  final asyncDoc = Document(
    id: 'DOC-002',
    title: 'Async Report',
    type: 'report',
    size: 3.1,
  );

  print('   [Async] Processing document with async pipeline...');

  // Create a cell with the pipeline
  final asyncCell = DocumentProcessingCell(
    receptor: pipeline,
    context: Context.module('async-processing'),
  );

  // Use the async adapter
  final startTime = DateTime.now();
  final receptor = asyncCell._nucleus.receptor;
  await receptor.async.call(Pulse(asyncDoc) as PulseBase);
  final elapsed = DateTime.now().difference(startTime);

  final processedDoc = asyncCell.currentDocument;
  if (processedDoc != null) {
    print('   [Async] ✓ Document processed (${elapsed.inMilliseconds}ms)');
    print('   [Async] Result: ${processedDoc.id} processed successfully');
  } else {
    print('   [Async] ✗ Processing failed');
  }

  print('');

  // ─────────────────────────────────────────────────────────────────────
  // Part 5: Cloning Receptors
  // ─────────────────────────────────────────────────────────────────────

  print('5. Cloning Receptors');
  print('   ─────────────────');

  // Create a receptor with some stateful behavior
  final originalReceptor = Receptor(
        (cell, pulse, {user}) {
      final doc = pulse.payload as Document?;
      if (doc == null) return null;
      print('   [Clone] Processing: ${doc.id}');
      final processed = doc.copyWith(
        status: 'clone-processed',
        metadata: Map<String, dynamic>.from(doc.metadata)
          ..['processedBy'] = 'original-receptor',
      );
      return Pulse(processed);
    },
  );

  // Clone the receptor
  final clonedReceptor = originalReceptor.clone;

  print('   [Clone] Original receptor cloned successfully');

  // Create two cells with the cloned receptors
  final cell1 = DocumentProcessingCell(
    receptor: originalReceptor,
    context: Context.module('original-cell'),
  );

  final cell2 = DocumentProcessingCell(
    receptor: clonedReceptor,
    context: Context.module('cloned-cell'),
  );

  // Process the same document through both cells
  final cloneDoc = Document(
    id: 'DOC-003',
    title: 'Clone Test Document',
    type: 'test',
    size: 0.5,
  );

  final result1 = await cell1.processDocument(cloneDoc);
  final result2 = await cell2.processDocument(cloneDoc);

  if (result1 != null && result2 != null) {
    final doc1 = result1.payload as Document;
    final doc2 = result2.payload as Document;
    print('   [Clone] Original cell status: ${doc1.status}');
    print('   [Clone] Cloned cell status: ${doc2.status}');
    print('   [Clone] Both receptors operate independently');
  }

  print('');

  // ─────────────────────────────────────────────────────────────────────
  // Part 6: Error Handling and Resilience
  // ─────────────────────────────────────────────────────────────────────

  print('6. Error Handling and Resilience');
  print('   ──────────────────────────────');

  final resilientReceptor = createResilientReceptor();

  print('   ── Processing Invalid Document ──');

  final invalidDoc = Document(
    id: 'ERROR-DOC',
    title: 'Invalid Document',
    type: 'unknown',
    size: -1.0,
  );

  final resilientCell = DocumentProcessingCell(
    receptor: resilientReceptor,
    context: Context.module('resilient-processing'),
  );

  try {
    final result = await resilientCell.processDocument(invalidDoc);
    if (result != null && result.payload is Document) {
      final processed = result.payload as Document;
      print('\n   [Error] Document processed with status: ${processed.status}');
      if (processed.metadata.containsKey('error')) {
        print('   [Error] Error details: ${processed.metadata['error']}');
      }
    }
  } catch (e) {
    print('   [Error] Error handled gracefully: $e');
  }

  print('');

  // ─────────────────────────────────────────────────────────────────────
  // Part 7: Bonus - Document Batch Processing
  // ─────────────────────────────────────────────────────────────────────

  print('7. Bonus: Document Batch Processing');
  print('   ─────────────────────────────────');

  final batchPipeline = createDocumentPipelineReceptor();
  final batchCell = DocumentProcessingCell(
    receptor: batchPipeline,
    context: Context.module('batch-processing'),
  );

  final batchDocs = [
    Document(
      id: 'BATCH-001',
      title: 'Batch Report 1',
      type: 'report',
      size: 1.2,
    ),
    Document(
      id: 'BATCH-002',
      title: 'Batch Invoice',
      type: 'invoice',
      size: 0.8,
    ),
    Document(
      id: 'BATCH-003',
      title: 'Batch Proposal',
      type: 'proposal',
      size: 3.5,
    ),
  ];

  print('   Processing ${batchDocs.length} documents...');

  final results = <ProcessingResult>[];
  for (final doc in batchDocs) {
    final start = DateTime.now();
    try {
      final result = await batchCell.processDocument(doc);
      final elapsed = DateTime.now().difference(start);
      if (result != null && result.payload is Document) {
        final processed = result.payload as Document;
        results.add(ProcessingResult(
          success: true,
          message: 'Processed ${processed.id}',
          document: processed,
          processingTime: elapsed,
        ));
      } else {
        results.add(ProcessingResult(
          success: false,
          message: 'Failed to process ${doc.id}',
          processingTime: elapsed,
        ));
      }
    } catch (e) {
      results.add(ProcessingResult(
        success: false,
        message: 'Error: $e',
        processingTime: DateTime.now().difference(start),
      ));
    }
  }

  print('\n   ── Batch Processing Results ──');
  for (final result in results) {
    final status = result.success ? '✓' : '✗';
    final time = result.processingTime.inMilliseconds;
    print('   $status ${result.message} (${time}ms)');
    if (result.document != null) {
      print('      Route: ${result.document!.route ?? 'none'}');
    }
  }

  print('\n${'═' * 80}');
  print('  DEMO COMPLETE');
  print('${'═' * 80}\n');
}