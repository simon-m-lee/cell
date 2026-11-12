// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Canonical serialiser for [Pulse].
///
/// Encodes the payload, type, priority, timestamp, source (by cell id),
/// trace, `PulseContext` lineage, and a **parent digest**. The parent is
/// not recursively serialised — only the digest of its own canonical form —
/// because deep chains would balloon the wire format, and because identical
/// parent pulses should collapse to identical hashes (that is what makes
/// replay reconstructable from the ledger).
///
/// ### The materialise boundary
///
/// The hot path produces `_FastPulse`/`_StepPulse` flyweights. Those carry
/// their state in plain fields instead of the canonical record, so [toJson]
/// rejects them by default and [materialise] is the *explicit* boundary
/// that replaces them with equivalent plain `_Pulse` nodes. Always encode
/// `PulseCodec.toJson(PulseCodec.materialise(pulse))`.
class PulseCodec {
  const PulseCodec._();

  /// Encodes [pulse] into a canonical JSON map.
  ///
  /// Throws [ArgumentError] if `pulse` is a `_FastPulse` or `_StepPulse`.
  /// Callers that receive pulses from a hot path must call
  /// [materialise] first.
  static Map<String, Object?> toJson(Pulse pulse) {
    if (pulse is _FastPulse) {
      throw ArgumentError.value(
        pulse,
        'pulse',
        'PulseCodec cannot encode _FastPulse. '
        'Call `PulseCodec.materialise()` first.',
      );
    }
    if (pulse is _StepPulse) {
      throw ArgumentError.value(
        pulse,
        'pulse',
        'PulseCodec cannot encode _StepPulse directly. '
        'Call `PulseCodec.materialise()` first.',
      );
    }

    final base = pulse as PulseBase<dynamic>;
    final parent = base._parent;
    final parentDigest = parent == null
        ? null
        : fingerprint(toJson(materialise(parent as Pulse<dynamic>)));

    // A locally-null payload (an evolved pulse whose appended pulse has a
    // null payload) overrides a non-null parent payload at runtime. The
    // wire must preserve that distinction: the key is kept with a null
    // value even though every other null is stripped.
    final resolvedPayload = base.payload;
    final payloadIsNullOverride =
        resolvedPayload == null && parent != null && parent.payload != null;

    final out = <String, Object?>{
      'payload': _encodePayload(resolvedPayload),
      'type': _encodeDynamic(base.type),
      'priority': base.priority,
      'timestamp': base.timestamp.toUtc().toIso8601String(),
      'source': _sourceId(base.source),
      'trace': base.trace,
      'parentDigest': parentDigest,
      'context': PulseContextCodec.toJson(base.context),
    };
    // Strip nulls so the canonical bytes don't include a stable-position
    // `null` for every unset optional field — that would defeat the point
    // of the canonical encoder. The one exception is the null-override
    // marker above.
    out.removeWhere((_, v) => v == null);
    if (payloadIsNullOverride) out['payload'] = null;
    return out;
  }

  /// Reconstructs a `Pulse<dynamic>` from [toJson]'s output.
  ///
  /// Returns a plain `_Pulse` (the shape the codec accepts on the way
  /// out). Callers that need a typed pulse for a typed receptor cast the
  /// payload before constructing the receiving cell; the codec has no
  /// way to know the receiving type statically.
  ///
  /// [parent] must be supplied by the caller if `parentDigest` is present:
  /// the digest is verified against the supplied parent, and the parent's
  /// trace must be a prefix of the wire `trace` (the remainder becomes the
  /// leaf's local step). Reconstruct chains bottom-up — root first — so
  /// every level round-trips byte-for-byte.
  static Pulse<dynamic> fromJson(
    Map<String, Object?> json, {
    Pulse<dynamic>? parent,
  }) {
    final rawPayload = json['payload'];
    final type = _decodeDynamic(json['type']);
    final priority = (json['priority'] as int?) ?? Pulse.defaultPriority;

    final timestampRaw = json['timestamp'];
    if (timestampRaw is! String) {
      throw FormatException('Pulse codec: missing or malformed timestamp');
    }
    final timestamp = DateTime.parse(timestampRaw).toLocal();

    final source = _sourceFromId(json['source'] as String?);
    final trace = (json['trace'] as List?)?.cast<String>() ?? const <String>[];

    final ctxJson = json['context'];
    if (ctxJson is! Map) {
      throw FormatException('Pulse codec: missing or malformed context');
    }
    final context = PulseContextCodec.fromJson(
      Map<String, Object?>.from(ctxJson),
    );

    final parentDigest = json['parentDigest'];
    PulseBase<dynamic>? parentBase;
    if (parentDigest != null) {
      if (parent == null) {
        throw ArgumentError(
          'PulseCodec.fromJson: parentDigest present but no parent '
          'provided. Supply the reconstructed parent, or use the ledger '
          'API (Phase 5) which resolves parents by digest.',
        );
      }
      final actual = fingerprint(toJson(parent));
      if (actual != parentDigest) {
        throw FormatException(
          'PulseCodec.fromJson: parentDigest mismatch — the record expects '
          '$parentDigest but the supplied parent hashes to $actual.',
        );
      }
      parentBase = parent as PulseBase<dynamic>;
    } else if (parent != null) {
      throw ArgumentError(
        'PulseCodec.fromJson: a parent was supplied for a root pulse '
        '(no parentDigest in the record).',
      );
    }

    // The wire `trace` is the merged trace of the whole chain. The supplied
    // parent contributes its own prefix; whatever remains is the leaf's
    // local step (a plain _Pulse carries at most one).
    final parentTrace = parentBase?.trace ?? const <String>[];
    final localSteps = _leafSteps(trace, parentTrace);

    // The `payload` key is present iff the node defines its payload
    // locally — including the null-override marker (see `toJson`).
    final hasLocalPayload = json.containsKey('payload');
    return _plainPulse(
      payload: _decodePayload(rawPayload),
      localPayload: hasLocalPayload,
      type: type,
      priority: priority,
      timestamp: timestamp,
      source: source,
      context: context,
      step: localSteps.isEmpty ? null : localSteps.single,
      parent: parentBase,
    );
  }

  /// Replaces an un-materialised pulse (i.e. `_FastPulse`/`_StepPulse`) —
  /// and any un-materialised nodes in its parent chain — with equivalent
  /// plain `_Pulse` nodes that the codec accepts.
  ///
  /// This is a cold path (called once per pulse before persistence). The
  /// result preserves resolved payload, type, priority, timestamp, source,
  /// context, policy, and the full trace; the flyweight structure itself is
  /// deliberately flattened into the canonical chain shape.
  static Pulse<dynamic> materialise(Pulse<dynamic> pulse) {
    if (pulse is _FastPulse) {
      final trace = pulse.trace;
      return _Pulse<dynamic>(
        payload: pulse.payload,
        type: pulse.type,
        priority: pulse.priority,
        timestamp: pulse.timestamp,
        source: pulse.source,
        step: trace.isEmpty ? null : trace.first,
      );
    }

    final base = pulse as PulseBase<dynamic>;

    if (pulse is _StepPulse) {
      final parent = base._parent;
      final step = (pulse as dynamic)._stepValue as String;
      if (parent == null) {
        // Degenerate: a step marker with no parent. Rebuild as a plain
        // root carrying the step.
        return _Pulse<dynamic>(step: step);
      }
      final cleanParent =
          materialise(parent as Pulse<dynamic>) as PulseBase<dynamic>;
      return _Pulse<dynamic>(step: step, parent: cleanParent);
    }

    // Plain node: make sure its parent chain is clean.
    final parent = base._parent;
    if (parent == null) return pulse;
    final cleanParent = materialise(parent as Pulse<dynamic>);
    if (identical(cleanParent, parent)) return pulse;
    return _rebuildNode(base, cleanParent as PulseBase<dynamic>);
  }

  // ── private ───────────────────────────────────────────────────────────

  /// Rebuilds a plain pulse node whose parent was replaced, capturing its
  /// *locally defined* fields so inheritance re-resolves identically.
  static Pulse<dynamic> _rebuildNode(
    PulseBase<dynamic> base,
    PulseBase<dynamic> newParent,
  ) {
    final shape = base._shape;
    final record = base._record;
    // Payload/type resolve through an appended `_pulse` (evolved nodes) as
    // well as through the local record; capture the resolved value so the
    // rebuilt node keeps it without the composite structure.
    final hasAppendedPulse = base._pulse != null;
    return _plainPulse(
      payload: base.payload,
      localPayload:
          (shape & PulseBase._kPayload) != 0 || hasAppendedPulse,
      type: (shape & PulseBase._kType) != 0 || hasAppendedPulse
          ? base.type
          : null,
      priority: (shape & PulseBase._kPriority) != 0 ? base.priority : null,
      timestamp: (shape & PulseBase._kTimestamp) != 0 ? base.timestamp : null,
      source: (shape & PulseBase._kSource) != 0 ? base.source : null,
      context: (shape & PulseBase._kContext) != 0 ? base.context : null,
      policy: (shape & PulseBase._kPolicy) != 0 ? base.policy : null,
      step: (shape & PulseBase._kStep) != 0
          ? record.root.secondary.step as String
          : null,
      parent: newParent,
    );
  }

  /// Builds a plain pulse node.
  ///
  /// [localPayload] means "this node defines its own payload". When that
  /// definition is null and the parent carries a non-null payload, the
  /// runtime semantics are a *null override* — a state `_Pulse` cannot
  /// express (its record drops null payloads, so the getter would inherit).
  /// [_NullPayloadPulse] pins the getter for exactly that case.
  static Pulse<dynamic> _plainPulse({
    Object? payload,
    required bool localPayload,
    dynamic type,
    int? priority,
    DateTime? timestamp,
    Cell? source,
    PulseContext? context,
    PulseEphemeralPolicy? policy,
    String? step,
    PulseBase<dynamic>? parent,
  }) {
    if (localPayload &&
        payload == null &&
        parent != null &&
        parent.payload != null) {
      return _NullPayloadPulse(
        context: context,
        type: type,
        timestamp: timestamp,
        source: source,
        priority: priority,
        step: step,
        parent: parent,
      );
    }
    return _Pulse<dynamic>(
      payload: localPayload ? payload : null,
      type: type,
      priority: priority,
      timestamp: timestamp,
      source: source,
      context: context,
      policy: policy,
      step: step,
      parent: parent,
    );
  }

  /// The leaf-local steps implied by a merged wire trace and the supplied
  /// parent's trace. Loud failure when the parent is not a true prefix.
  static List<String> _leafSteps(List<String> trace, List<String> parentTrace) {
    if (parentTrace.length > trace.length) {
      throw FormatException(
        'Pulse codec: supplied parent trace (${parentTrace.length} steps) '
        'is longer than the wire trace (${trace.length} steps).',
      );
    }
    for (var i = 0; i < parentTrace.length; i++) {
      if (trace[i] != parentTrace[i]) {
        throw FormatException(
          'Pulse codec: supplied parent trace is not a prefix of the wire '
          'trace at step $i (parent: "${parentTrace[i]}", wire: "${trace[i]}").',
        );
      }
    }
    final local = trace.sublist(parentTrace.length);
    if (local.length > 1) {
      throw FormatException(
        'Pulse codec: a plain pulse carries at most one local step, got '
        '$local.',
      );
    }
    return local;
  }

  static Object? _encodePayload(Object? payload) {
    if (payload == null) return null;
    if (payload is String || payload is num || payload is bool) return payload;
    if (payload is List) return payload.map(_encodePayload).toList();
    if (payload is Map) {
      return payload.map((k, v) => MapEntry('$k', _encodePayload(v)));
    }
    if (payload is DateTime) return payload.toUtc().toIso8601String();
    throw ArgumentError.value(
      payload,
      'payload',
      'PulseCodec cannot encode ${payload.runtimeType}. '
      'Provide a payload that is JSON-encodable, or register a custom '
      'payload codec for your domain type.',
    );
  }

  static Object? _decodePayload(Object? v) {
    if (v is Map) return Map<String, Object?>.from(v);
    if (v is List) return v;
    return v;
  }

  static Object? _encodeDynamic(Object? v) => v == null ? null : '$v';

  static Object? _decodeDynamic(Object? v) => v;

  static String? _sourceId(Cell? source) => source?.id;

  static Cell? _sourceFromId(String? id) {
    if (id == null) return null;
    return _ReplayCellRegistry.lookup(id);
  }
}

/// A decoded plain pulse whose wire record declares a locally-null payload
/// while its parent carries a non-null payload.
///
/// `_Pulse` cannot express this state: its record drops null payloads, so
/// the payload getter would fall through to the parent. The runtime's own
/// semantics do have this state (`EvolvedPulseBase.payload` reads the
/// appended pulse directly, null included), so the codec needs a shape
/// that pins the getter. Everything else behaves like a plain `_Pulse`.
class _NullPayloadPulse extends _SinglePulseBase<dynamic> {
  _NullPayloadPulse({
    super.context,
    super.type,
    super.timestamp,
    super.source,
    super.priority,
    super.step,
    super.parent,
  });

  @override
  dynamic get payload => null;
}

/// A minimal, in-process registry used by [PulseCodec] to resolve a source
/// cell id back to a `Cell` handle. Populated by `CellGraph.register`
/// (Phase 2). Empty in a pure Phase 1 build, in which case `_sourceFromId`
/// returns `null` and the reconstructed pulse has no source — which is
/// fine, because Phase 1 tests do not depend on source identity.
///
/// Kept deliberately private so the public Phase 2 registry can replace
/// this implementation without breaking any code that imports the codec.
class _ReplayCellRegistry {
  static final Map<String, Cell> _cells = {};

  // ignore: unused_element — Phase 2 `CellGraph.register` hooks here.
  static void register(String id, Cell cell) {
    _cells[id] = cell;
  }

  // ignore: unused_element — Phase 2 teardown hook.
  static void unregister(String id) {
    _cells.remove(id);
  }

  static Cell? lookup(String id) => _cells[id];
}
