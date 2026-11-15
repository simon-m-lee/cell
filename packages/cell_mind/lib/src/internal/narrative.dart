// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// Renders a [DecisionPath] in the requested narrative template.
String _renderNarrative(DecisionPath path, NarrativeTemplate template) {
  switch (template) {
    case NarrativeTemplate.audit:
      return _auditNarrative(path);
    case NarrativeTemplate.ui:
      return _uiNarrative(path);
    case NarrativeTemplate.debug:
      return _debugNarrative(path);
  }
}

String _verdictLabel(Verdict verdict) {
  if (verdict is Accept) return 'ACCEPT';
  if (verdict is Reject) {
    return 'REJECT \'${verdict.reason}\'';
  }
  if (verdict is Defer) {
    return 'DEFER \'${verdict.resolver}\'';
  }
  return verdict.type;
}

String _auditNarrative(DecisionPath path) {
  final buffer = StringBuffer(
    '[${path.at.toUtc().toIso8601String()}] decision ${path.id}: '
    '${_verdictLabel(path.verdict)}',
  );
  final metadata = <String>[];
  if (path.actor != null) metadata.add('actor=${path.actor}');
  if (path.strategy != null) metadata.add('strategy=${path.strategy!.name}');
  if (path.confidence != null) {
    metadata.add('conf=${path.confidence!.toStringAsFixed(2)}');
  }
  if (path.purpose != null) metadata.add('purpose=${path.purpose}');
  metadata.add('ctx-version=${path.contextVersion}');
  final eval = path.evaluationTime;
  if (eval != null) metadata.add('eval=${eval.inMilliseconds}ms');
  if (metadata.isNotEmpty) buffer.write(' (${metadata.join(', ')})');
  return buffer.toString();
}

String _uiNarrative(DecisionPath path) {
  final actor = path.actor ?? 'An actor';
  final verdict = path.verdict;
  final confidence = path.confidence;
  final confidenceSuffix =
      confidence == null ? '' : ' (confidence ${(confidence * 100).round()}%)';
  if (verdict is Accept) {
    return '$actor accepted the request$confidenceSuffix';
  }
  if (verdict is Reject) {
    return '$actor rejected the request: ${verdict.reason}$confidenceSuffix';
  }
  if (verdict is Defer) {
    return '$actor deferred the request to ${verdict.resolver}$confidenceSuffix';
  }
  return '$actor decided: ${verdict.type}$confidenceSuffix';
}

String _debugNarrative(DecisionPath path) {
  final pulse = path.pulse;
  final pulsePart = pulse == null
      ? 'pulse: <none>'
      : 'pulse: Pulse<${pulse.payload.runtimeType}>'
          '(${pulse.payload})';
  final eval = path.evaluationTime;
  final evalPart = eval == null ? '' : ', eval: ${eval.inMilliseconds}ms';
  return 'DecisionPath(id: ${path.id}, verdict: '
      '${_verdictLabel(path.verdict)}, $pulsePart, '
      'context: v${path.contextVersion}$evalPart)';
}
