// =============================================================================
// Practical executable walkthrough – Cell.sanitized
// Automated PII redaction · Audit trails
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

Map<String, dynamic> user({
  required String name,
  required String email,
  required String phone,
  String? ssn,
}) =>
    {
      'name': name,
      'email': email,
      'phone': phone,
      if (ssn != null) 'ssn': ssn,
    };

String maskEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2 || parts[0].isEmpty) return '***';
  return '${parts[0][0]}***@${parts[1]}';
}

String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return '***';
  return '***-***-${digits.substring(digits.length - 4)}';
}

Pulse<Map<String, dynamic>> sensitivePulse(
    Map<String, dynamic> payload, {
      required String type,
      required Sensitivity sensitivity,
      required String actor,
      required String reason,
      String? compliance,
      Cell? source,
    }) {
  return Pulse<Map<String, dynamic>>.governed(
    payload: payload,
    type: type,
    source: source,
    context: PulseContext(
      sensitivity: sensitivity,
      actor: actor,
      reason: reason,
      compliance: compliance,
    ),
  );
}

/// ### Expected console output:
/// ```text
/// ── Cell.sanitized – PII Redaction & Audit Trails ─────────────
///
/// 1. Public pulse (below threshold → no redaction)
///    [UI]     safe payload = {name: Ada, email: ada@example.com, phone: 555-0100}
///             type=user.profile
///    [Audit]  [2026-…] type=user.profile sensitivity=Sensitivity.public actor=signup-form reason=public profile preview payload={name: Ada, email: ada@example.com, phone: 555-0100}
///
/// 2. Confidential pulse (at threshold → redacted)
///    [UI]     safe payload = {name: Grace Hopper, email: g***@navy.mil, phone: ***-***-0199, ssn: ***-**-****}
///             type=privacy.redacted
///    [Audit]  [2026-…] type=privacy.redacted sensitivity=Sensitivity.internal actor=privacy-guard reason=PII redaction for downstream consumers payload={name: Grace Hopper, email: g***@navy.mil, phone: ***-***-0199, ssn: ***-**-****}
///
/// 3. Restricted pulse (above threshold → redacted)
///    [UI]     safe payload = {name: Alan Turing, email: a***@bletchley.uk, phone: ***-***-0958, ssn: ***-**-****}
///             type=privacy.redacted
///    [Audit]  [2026-…] type=privacy.redacted sensitivity=Sensitivity.internal actor=privacy-guard reason=PII redaction for downstream consumers payload={name: Alan Turing, email: a***@bletchley.uk, phone: ***-***-0958, ssn: ***-**-****}
///
/// 4. Secret pulse (highest tier → redacted)
///    [UI]     safe payload = {name: Agent X, email: x***@secure.enclave, phone: ***-***-0000, ssn: ***-**-****}
///             type=privacy.redacted
///    [Audit]  [2026-…] type=privacy.redacted sensitivity=Sensitivity.internal actor=privacy-guard reason=PII redaction for downstream consumers payload={name: Agent X, email: x***@secure.enclave, phone: ***-***-0000, ssn: ***-**-****}
///
/// 5. Audit trail summary (4 entries)
///    • [2026-…] type=user.profile sensitivity=Sensitivity.public …
///    • [2026-…] type=privacy.redacted sensitivity=Sensitivity.internal …
///    • [2026-…] type=privacy.redacted sensitivity=Sensitivity.internal …
///    • [2026-…] type=privacy.redacted sensitivity=Sensitivity.internal …
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.sanitized – PII Redaction & Audit Trails ─────────────\n');

  final rawIngress = Cell.ingress<Map<String, dynamic>>();

  final safeView = Cell.sanitized<Pulse>(
    rawIngress.cell,
    minSensitivity: Sensitivity.confidential,
    redact: (Pulse pulse) {
      final raw = Map<String, dynamic>.from(
        pulse.payload as Map<String, dynamic>? ?? {},
      );

      if (raw['email'] is String) {
        raw['email'] = maskEmail(raw['email'] as String);
      }
      if (raw['phone'] is String) {
        raw['phone'] = maskPhone(raw['phone'] as String);
      }
      if (raw.containsKey('ssn')) {
        raw['ssn'] = '***-**-****';
      }

      return Pulse<Map<String, dynamic>>.governed(
        payload: raw,
        type: 'privacy.redacted',
        context: PulseContext(
          sensitivity: Sensitivity.internal,
          actor: 'privacy-guard',
          reason: 'PII redaction for downstream consumers',
          compliance: 'GDPR/CCPA',
        ),
      );
    },
  );

  final uiObserver = Cell.observe(
    source: safeView,
    effect: (Pulse pulse) {
      print('   [UI]     safe payload = ${pulse.payload}');
      print('            type=${pulse.type}');
    },
  );

  final auditLog = <String>[];

  final auditObserver = Cell.observe(
    source: safeView,
    effect: (Pulse pulse) {
      final line =
          '[${DateTime.now().toIso8601String()}] '
          'type=${pulse.type} sensitivity=${pulse.context.sensitivity} '
          'actor=${pulse.context.actor} reason=${pulse.context.reason} '
          'payload=${pulse.payload}';
      auditLog.add(line);
      print('   [Audit]  $line');
    },
  );

  print('1. Public pulse (below threshold → no redaction)');
  await rawIngress.ingest(
    sensitivePulse(
      user(name: 'Ada', email: 'ada@example.com', phone: '555-0100'),
      type: 'user.profile',
      sensitivity: Sensitivity.public,
      actor: 'signup-form',
      reason: 'public profile preview',
      source: rawIngress.cell,
    ),
  );
  await Future.delayed(const Duration(milliseconds: 40));

  print('\n2. Confidential pulse (at threshold → redacted)');
  await rawIngress.ingest(
    sensitivePulse(
      user(
        name: 'Grace Hopper',
        email: 'grace.hopper@navy.mil',
        phone: '202-555-0199',
        ssn: '078-05-1120',
      ),
      type: 'user.profile',
      sensitivity: Sensitivity.confidential,
      actor: 'hr-service',
      reason: 'employee record sync',
      compliance: 'GDPR',
      source: rawIngress.cell,
    ),
  );
  await Future.delayed(const Duration(milliseconds: 40));

  print('\n3. Restricted pulse (above threshold → redacted)');
  await rawIngress.ingest(
    sensitivePulse(
      user(
        name: 'Alan Turing',
        email: 'alan.turing@bletchley.uk',
        phone: '+44-20-7946-0958',
        ssn: '123-45-6789',
      ),
      type: 'user.profile',
      sensitivity: Sensitivity.restricted,
      actor: 'identity-service',
      reason: 'KYC verification',
      compliance: 'GDPR,PCI',
      source: rawIngress.cell,
    ),
  );
  await Future.delayed(const Duration(milliseconds: 40));

  print('\n4. Secret pulse (highest tier → redacted)');
  await rawIngress.ingest(
    sensitivePulse(
      user(
        name: 'Agent X',
        email: 'x@secure.enclave',
        phone: '000-000-0000',
        ssn: '999-99-9999',
      ),
      type: 'user.classified',
      sensitivity: Sensitivity.secret,
      actor: 'secure-enclave',
      reason: 'classified identity transfer',
      source: rawIngress.cell,
    ),
  );
  await Future.delayed(const Duration(milliseconds: 40));

  print('\n5. Audit trail summary (${auditLog.length} entries)');
  for (final e in auditLog) {
    print('   • $e');
  }

  uiObserver.stop();
  auditObserver.stop();

  print('\n── finished ──────────────────────────────────────────────────');
}