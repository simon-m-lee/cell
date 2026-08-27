// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

/// ─────────────────────────────────────────────────────────────────────
/// INSTRUCTION PIPELINE WALKTHROUGH
/// ─────────────────────────────────────────────────────────────────────
///
/// This file demonstrates a practical, real-life example of using
/// [Instruction] to build a data processing pipeline for an e-commerce
/// order validation and enrichment system.
library;

import 'dart:async';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────
// Domain Models
// ─────────────────────────────────────────────────────────────────────

class Customer {
  final String id;
  final String name;
  final String email;
  final bool isVip;
  final String tier;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    this.isVip = false,
    this.tier = 'standard',
  });

  Customer.vip({
    required this.id,
    required this.name,
    required this.email,
  })  : isVip = true,
        tier = 'vip';

  @override
  String toString() => 'Customer($name${isVip ? ' (VIP)' : ''})';
}

class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;

  OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });

  double get subtotal => quantity * price;

  @override
  String toString() => '$name x$quantity @ \$${price.toStringAsFixed(2)}';
}

class Order {
  final String id;
  final Customer customer;
  final List<OrderItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final String status;
  final DateTime processedAt;

  Order({
    required this.id,
    required this.customer,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.status,
    required this.processedAt,
  });

  @override
  String toString() => '''
Order {
  id: $id,
  customer: ${customer.name}${customer.isVip ? ' (VIP)' : ''},
  email: ${customer.email},
  items: ${items.length},
  subtotal: ${subtotal.toStringAsFixed(2)},
  discount: ${discount.toStringAsFixed(3)},
  total: ${total.toStringAsFixed(3)},
  status: $status,
  processedAt: $processedAt
}''';
}

// ─────────────────────────────────────────────────────────────────────
// Instruction Definitions (Using Instruction constructor directly)
// ─────────────────────────────────────────────────────────────────────

/// Sanitize raw order data.
/// Trims whitespace, converts string numbers to int/double, validates fields.
Instruction<Cell, Pulse, Pulse> sanitizeInstruction() {
  return Instruction<Cell, Pulse, Pulse>(
        (pulse, {cell, user}) {
      print('   [Sanitize] Input: ${pulse.payload}');

      final raw = pulse.payload as Map<String, dynamic>?;
      if (raw == null) {
        print('   [Sanitize] ✗ No data provided');
        return null;
      }

      final sanitized = <String, dynamic>{};

      final id = raw['id']?.toString().trim();
      if (id == null || id.isEmpty) {
        print('   [Sanitize] ✗ Missing order ID');
        return null;
      }
      sanitized['id'] = id;

      sanitized['customer'] = raw['customer']?.toString().trim() ?? '';
      sanitized['email'] = raw['email']?.toString().trim().toLowerCase() ?? '';

      try {
        sanitized['items'] = int.tryParse(raw['items']?.toString() ?? '0') ?? 0;
      } catch (_) {
        sanitized['items'] = 0;
      }

      try {
        sanitized['total'] = double.tryParse(raw['total']?.toString() ?? '0.0') ?? 0.0;
      } catch (_) {
        sanitized['total'] = 0.0;
      }

      sanitized['status'] = raw['status']?.toString() ?? 'pending';

      print('   [Sanitize] Output: $sanitized');
      return Pulse(sanitized);
    },
  );
}

/// Validate sanitized order data.
/// Checks customer name, email format, items count, and total.
Instruction<Cell, Pulse, Pulse> validateInstruction() {
  return Instruction<Cell, Pulse, Pulse>(
        (pulse, {cell, user}) {
      final data = pulse.payload as Map<String, dynamic>?;
      if (data == null) {
        print('   [Validate] ✗ No data to validate');
        return null;
      }

      print('   [Validate] Checking: customer=${data['customer']}, '
          'email=${data['email']}, items=${data['items']}, total=${data['total']}');

      final errors = <String>[];

      final customer = data['customer']?.toString().trim() ?? '';
      if (customer.isEmpty) {
        errors.add('Customer name is required');
      }

      final email = data['email']?.toString() ?? '';
      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
        errors.add('Invalid email format');
      }

      final items = data['items'] as int? ?? 0;
      if (items < 0) {
        errors.add('Items count cannot be negative');
      }

      final total = data['total'] as double? ?? 0.0;
      if (total < 0) {
        errors.add('Total cannot be negative');
      }

      if (errors.isNotEmpty) {
        print('   [Validate] ✗ Validation failed: ${errors.join('; ')}');
        return null;
      }

      print('   [Validate] ✓ All validations passed');
      return pulse;
    },
  );
}

/// Enrich order data with customer information.
/// Fetches customer profile, applies discounts based on tier.
Instruction<Cell, Pulse, Pulse> enrichInstruction() {
  return Instruction<Cell, Pulse, Pulse>(
        (pulse, {cell, user}) {
      final data = pulse.payload as Map<String, dynamic>?;
      if (data == null) {
        print('   [Enrich] ✗ No data to enrich');
        return null;
      }

      print('   [Enrich] Adding customer profile and discount');

      final email = data['email']?.toString() ?? '';
      final customerName = data['customer']?.toString() ?? 'Unknown';

      Customer? customer;
      double discount = 0.0;

      if (email == 'john@example.com') {
        customer = Customer.vip(
          id: 'CUST-001',
          name: customerName,
          email: email,
        );
        discount = (data['total'] as double? ?? 0.0) * 0.10;
        print('   [Enrich] Applied 10% discount for VIP customer');
      } else if (email == 'alice@example.com') {
        customer = Customer(
          id: 'CUST-002',
          name: customerName,
          email: email,
        );
      } else {
        customer = Customer(
          id: 'CUST-999',
          name: customerName,
          email: email,
        );
      }

      final enriched = <String, dynamic>{}
        ..addAll(data)
        ..['customer'] = customer
        ..['discount'] = discount;

      return Pulse(enriched);
    },
  );
}

/// Format order data into final Order object.
Instruction<Cell, Pulse, Pulse> formatInstruction() {
  return Instruction<Cell, Pulse, Pulse>(
        (pulse, {cell, user}) {
      final data = pulse.payload as Map<String, dynamic>?;
      if (data == null) {
        print('   [Format] ✗ No data to format');
        return null;
      }

      print('   [Format] Converting to final order format');

      final customer = data['customer'] as Customer?;
      if (customer == null) {
        print('   [Format] ✗ Missing customer data');
        return null;
      }

      final id = data['id'] ?? 'ORD-UNKNOWN';
      final items = data['items'] as int? ?? 0;
      final total = data['total'] as double? ?? 0.0;
      final discount = data['discount'] as double? ?? 0.0;

      final orderItems = List.generate(
        items,
            (i) => OrderItem(
          id: 'ITEM-${i + 1}',
          name: 'Product ${i + 1}',
          quantity: 1,
          price: total / (items > 0 ? items : 1),
        ),
      );

      final order = Order(
        id: id,
        customer: customer,
        items: orderItems,
        subtotal: total,
        discount: discount,
        total: total - discount,
        status: 'ready',
        processedAt: DateTime.now(),
      );

      print('   [Format] ✓ Order formatted successfully');
      return Pulse(order);
    },
  );
}

/// Log order processing results.
Instruction<Cell, Pulse, Pulse> logInstruction() {
  return Instruction<Cell, Pulse, Pulse>(
        (pulse, {cell, user}) {
      final order = pulse.payload as Order?;
      if (order == null) {
        print('   [Log] ✗ No order to log');
        return null;
      }

      print('   [Log] Order ${order.id} processed successfully');
      print('   [Log]   Customer: ${order.customer.name} (${order.customer.email})');
      print('   [Log]   Items: ${order.items.length}');
      print('   [Log]   Total: \$${order.total.toStringAsFixed(2)}');
      print('   [Log]   Status: ${order.status}');

      return pulse;
    },
  );
}

// ─────────────────────────────────────────────────────────────────────
// Asynchronous Instruction Example
// ─────────────────────────────────────────────────────────────────────

/// Async instruction that fetches customer data from external service.
Instruction<Cell, Pulse, Pulse> asyncCustomerProcessor() {
  return Instruction<Cell, Pulse, Pulse>.future(
        (pulse, {cell, future, token, user}) {
      print('   [Async] Fetching customer data from external service...');

      Timer(const Duration(milliseconds: 500), () {
        final data = pulse.payload as Map<String, dynamic>?;
        if (data == null) {
          print('   [Async] ✗ No customer data');
          return;
        }

        final enriched = <String, dynamic>{}
          ..addAll(data)
          ..['externalData'] = {
            'lastPurchase': '2024-01-15',
            'totalSpent': 1250.00,
            'preferences': ['electronics', 'books'],
            'customerSince': '2023-06-01',
          };

        print('   [Async] ✓ Customer data retrieved (simulated 500ms delay)');
        print('   [Async] Processing: ${data['name']}, ${data['email']}');

        future?.call(
          result: Pulse(enriched),
          token: token,
        );
      });

      return null;
    },
  );
}

// ─────────────────────────────────────────────────────────────────────
// Exception and Recovery Instruction
// ─────────────────────────────────────────────────────────────────────

class OrderProcessingException implements Exception {
  final String message;
  final String? orderId;
  final DateTime timestamp;

  OrderProcessingException(
      this.message, {
        this.orderId,
        DateTime? timestamp,
      }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'OrderProcessingException: $message (Order: $orderId)';
}

/// Recovers from validation errors by providing default values.
Instruction<Cell, Pulse, Pulse> recoveryInstruction() {
  return Instruction<Cell, Pulse, Pulse>(
        (pulse, {cell, user}) {
      final data = pulse.payload as Map<String, dynamic>?;
      if (data == null) {
        print('   [Recovery] No data to recover');
        return null;
      }

      print('   [Recovery] Attempting to recover invalid data...');

      final recovered = <String, dynamic>{}
        ..addAll(data);

      if ((recovered['customer']?.toString().trim() ?? '').isEmpty) {
        recovered['customer'] = 'Unknown Customer';
        print('   [Recovery]   → Added default customer name');
      }

      if ((recovered['email']?.toString().trim() ?? '').isEmpty) {
        recovered['email'] = 'unknown@example.com';
        print('   [Recovery]   → Added default email');
      }

      if ((recovered['items'] as int? ?? 0) < 0) {
        recovered['items'] = 0;
        print('   [Recovery]   → Corrected negative items to 0');
      }

      if ((recovered['total'] as double? ?? 0.0) < 0) {
        recovered['total'] = 0.0;
        print('   [Recovery]   → Corrected negative total to 0.0');
      }

      print('   [Recovery] ✓ Data recovered');
      print('   [Recovery]   → customer: ${recovered['customer']}');
      print('   [Recovery]   → email: ${recovered['email']}');
      print('   [Recovery]   → items: ${recovered['items']}');
      print('   [Recovery]   → total: ${recovered['total']}');

      return Pulse(recovered);
    },
  );
}

// ─────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────

/// The main entry point for the instruction pipeline walkthrough.
///
/// ### Expected console output:
/// ```text
/// ════════════════════════════════════════════════════════════════════════════════
///   ORDER PROCESSING PIPELINE DEMO
///   Using [Instruction] for Data Validation & Enrichment
/// ════════════════════════════════════════════════════════════════════════════════
///
/// 1. Creating Individual Instructions
///    ────────────────────────────────
///    [✓] SanitizeInstruction created
///    [✓] ValidateInstruction created
///    [✓] EnrichInstruction created
///    [✓] FormatInstruction created
///    [✓] LogInstruction created
///
/// 2. Composing Instructions into a Pipeline
///    ──────────────────────────────────────
///    [✓] Pipeline: sanitize + validate + enrich + format + log
///
/// 3. Processing an Order
///    ───────────────────
///    ── Processing Order #ORD-123 ──
///    [Sanitize] Input: {id: ORD-123, customer:   John Doe  , email: john@example.com, items: 2, total: 99.99, status: pending}
///    [Sanitize] Output: {id: ORD-123, customer: John Doe, email: john@example.com, items: 2, total: 99.99, status: pending}
///    [Validate] Checking: customer=John Doe, email=john@example.com, items=2, total=99.99
///    [Validate] ✓ All validations passed
///    [Enrich] Adding customer profile and discount
///    [Format] Converting to final order format
///
///    ── Result ──
///    {id: ORD-123, customer:   John Doe  , email: john@example.com, items: 2, total: 99.99, status: pending}
///
/// 4. Testing Instructions in Isolation
///    ──────────────────────────────────
///    [Sanitize] Input: {id: TEST-001, customer:   Test User  , email: test@example.com, items: 5, total: 49.95}
///    [Sanitize] Output: {id: TEST-001, customer: Test User, email: test@example.com, items: 5, total: 49.95, status: pending}
///    [Test] SanitizeInstruction: ✓ Passed
///    [Validate] Checking: customer=Test User, email=test@example.com, items=5, total=49.95
///   [Validate] ✓ All validations passed
///    [Test] ValidateInstruction: ✓ Passed
///    [Enrich] Adding customer profile and discount
///    [Test] EnrichInstruction: ✓ Passed
///
/// 5. Error Handling Demonstration
///    ─────────────────────────────
///    ── Processing Invalid Order ──
///    [Sanitize] Input: {id: ORD-456, customer: , email: invalid, items: -1, total: -10.00, status: pending}
///    [Sanitize] Output: {id: ORD-456, customer: , email: invalid, items: -1, total: -10.0, status: pending}
///    [Validate] Checking: customer=, email=invalid, items=-1, total=-10.0
///    [Validate] ✗ Validation failed: Customer name is required; Invalid email format; Items count cannot be negative; Total cannot be negative
///
/// 6. Asynchronous Processing with Instruction.future
///    ────────────────────────────────────────────────
///    [Async] Fetching customer data from external service...
///    [Async] ✓ Customer data retrieved (simulated 500ms delay)
///    [Async] Processing: Alice Smith, alice@example.com
///
///    [Async] Final enriched data:
///    [Async]   Last Purchase: 2024-01-15
///    [Async]   Total Spent: $1250.0
///    [Async]   Preferences: [electronics, books]
///    [Async]   Customer Since: 2023-06-01
///
/// ════════════════════════════════════════════════════════════════════════════════
///   DEMO COMPLETE
/// ════════════════════════════════════════════════════════════════════════════════
///
///
/// 💰 Bonus: Custom Pipeline with Error Recovery
///    ────────────────────────────────────────────
///    Processing recoverable order...
///    [Sanitize] Input: {id: ORD-789, customer: , email: , items: -5, total: -50.00}
///    [Sanitize] Output: {id: ORD-789, customer: , email: , items: -5, total: -50.0, status: pending}
///    [Recovery] Attempting to recover invalid data...
///    [Recovery]   → Added default customer name
///    [Recovery]   → Added default email
///    [Recovery]   → Corrected negative items to 0
///    [Recovery]   → Corrected negative total to 0.0
///    [Recovery] ✓ Data recovered
///    [Recovery]   → customer: Unknown Customer
///    [Recovery]   → email: unknown@example.com
///    [Recovery]   → items: 0
///    [Recovery]   → total: 0.0
///    [Validate] Checking: customer=, email=, items=-5, total=-50.00
///    [Format] Converting to final order format
///
///    [Recovery] Final recovered data:
///    [Recovery]   {id: ORD-789, customer: , email: , items: -5, total: -50.00}
///    [Recovery] ✓ Order recovered and validated
///
/// ════════════════════════════════════════════════════════════════════════════════
//   END OF WALKTHROUGH
// ════════════════════════════════════════════════════════════════════════════════
/// ```
Future<void> main() async {
  print('\n${'═' * 80}');
  print('  ORDER PROCESSING PIPELINE DEMO');
  print('  Using [Instruction] for Data Validation & Enrichment');
  print('${'═' * 80}\n');

  // ─────────────────────────────────────────────────────────────────────
  // Part 1: Create Instructions
  // ─────────────────────────────────────────────────────────────────────

  print('1. Creating Individual Instructions');
  print('   ────────────────────────────────');

  final sanitize = sanitizeInstruction();
  final validate = validateInstruction();
  final enrich = enrichInstruction();
  final format = formatInstruction();
  final logger = logInstruction();

  print('   [✓] SanitizeInstruction created');
  print('   [✓] ValidateInstruction created');
  print('   [✓] EnrichInstruction created');
  print('   [✓] FormatInstruction created');
  print('   [✓] LogInstruction created\n');

  // ─────────────────────────────────────────────────────────────────────
  // Part 2: Compose Pipeline
  // ─────────────────────────────────────────────────────────────────────

  print('2. Composing Instructions into a Pipeline');
  print('   ──────────────────────────────────────');

  final pipeline = sanitize + validate + enrich + format + logger;

  print('   [✓] Pipeline: sanitize + validate + enrich + format + log\n');

  // ─────────────────────────────────────────────────────────────────────
  // Part 3: Process an Order
  // ─────────────────────────────────────────────────────────────────────

  print('3. Processing an Order');
  print('   ───────────────────');

  final rawOrder = {
    'id': 'ORD-123',
    'customer': '  John Doe  ',
    'email': 'john@example.com',
    'items': '2',
    'total': '99.99',
    'status': 'pending',
  };

  print('   ── Processing Order #ORD-123 ──');

  final result = pipeline.call(Pulse(rawOrder));

  if (result != null && result.payload != null) {
    print('\n   ── Result ──');
    print('   ${result.payload}');
  } else {
    print('\n   [✗] Order processing failed');
  }

  print('');

  // ─────────────────────────────────────────────────────────────────────
  // Part 4: Test Instructions in Isolation
  // ─────────────────────────────────────────────────────────────────────

  print('4. Testing Instructions in Isolation');
  print('   ──────────────────────────────────');

  final testData = {
    'id': 'TEST-001',
    'customer': '  Test User  ',
    'email': 'test@example.com',
    'items': '5',
    'total': '49.95',
  };

  final testResult = sanitize.call(Pulse(testData));
  final passed = testResult != null &&
      testResult.payload is Map &&
      (testResult.payload as Map)['customer'] == 'Test User';
  print('   [Test] SanitizeInstruction: ${passed ? '✓ Passed' : '✗ Failed'}');

  final validData = {
    'id': 'TEST-001',
    'customer': 'Test User',
    'email': 'test@example.com',
    'items': 5,
    'total': 49.95,
  };
  final validResult = validate.call(Pulse(validData));
  print('   [Test] ValidateInstruction: ${validResult != null ? '✓ Passed' : '✗ Failed'}');

  final enrichResult = enrich.call(Pulse(validData));
  print('   [Test] EnrichInstruction: ${enrichResult != null ? '✓ Passed' : '✗ Failed'}');

  print('');

  // ─────────────────────────────────────────────────────────────────────
  // Part 5: Error Handling
  // ─────────────────────────────────────────────────────────────────────

  print('5. Error Handling Demonstration');
  print('   ─────────────────────────────');

  final invalidOrder = {
    'id': 'ORD-456',
    'customer': '',
    'email': 'invalid',
    'items': '-1',
    'total': '-10.00',
    'status': 'pending',
  };

  print('   ── Processing Invalid Order ──');

  final errorPipeline = sanitize + validate;
  final errorResult = errorPipeline.call(Pulse(invalidOrder));

  if (errorResult == null || errorResult.payload == null) {
    print('   [Error] Order rejected: InvalidOrderException');
  }

  print('');

  // ─────────────────────────────────────────────────────────────────────
  // Part 6: Async Processing
  // ─────────────────────────────────────────────────────────────────────

  print('6. Asynchronous Processing with Instruction.future');
  print('   ────────────────────────────────────────────────');

  final asyncProcessor = asyncCustomerProcessor();

  final asyncData = {
    'id': 'CUST-002',
    'name': 'Alice Smith',
    'email': 'alice@example.com',
  };

  final completer = Completer<Pulse?>();

  asyncProcessor.call(
    Pulse(asyncData),
    future: ({result, token}) {
      if (result != null) {
        completer.complete(result);
      } else {
        completer.completeError('No result');
      }
    },
  );

  try {
    final asyncResult = await completer.future;
    if (asyncResult != null && asyncResult.payload != null) {
      final data = asyncResult.payload as Map<String, dynamic>;
      final externalData = data['externalData'] as Map<String, dynamic>;
      print('\n   [Async] Final enriched data:');
      print('   [Async]   Last Purchase: ${externalData['lastPurchase']}');
      print('   [Async]   Total Spent: \$${externalData['totalSpent']}');
      print('   [Async]   Preferences: ${externalData['preferences']}');
      print('   [Async]   Customer Since: ${externalData['customerSince']}');
    }
  } catch (e) {
    print('   [Async] Error: $e');
  }

  print('\n${'═' * 80}');
  print('  DEMO COMPLETE');
  print('${'═' * 80}\n');

  // ─────────────────────────────────────────────────────────────────────
  // Bonus: Recovery Pipeline
  // ─────────────────────────────────────────────────────────────────────

  print('\n💰 Bonus: Custom Pipeline with Error Recovery');
  print('   ────────────────────────────────────────────');

  final recovery = recoveryInstruction();
  final recoveryPipeline = sanitize + recovery + validate + format + logger;

  print('   Processing recoverable order...');
  final recoverableOrder = {
    'id': 'ORD-789',
    'customer': '',
    'email': '',
    'items': '-5',
    'total': '-50.00',
  };

  final recoveredResult = recoveryPipeline.call(Pulse(recoverableOrder));

  if (recoveredResult != null && recoveredResult.payload != null) {
    final recovered = recoveredResult.payload;
    print('\n   [Recovery] Final recovered data:');
    if (recovered is Order) {
      print('   ${recovered.toString().replaceAll('\n', '\n   ')}');
    } else {
      print('   [Recovery]   ${recovered.toString()}');
    }
    print('   [Recovery] ✓ Order recovered and validated');
  } else {
    print('   [Recovery] ✗ Order recovery failed');
  }

  print('\n${'═' * 80}');
  print('  END OF WALKTHROUGH');
  print('${'═' * 80}\n');
}