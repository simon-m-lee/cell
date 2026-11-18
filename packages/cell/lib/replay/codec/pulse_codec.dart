// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Canonical serialiser for [Pulse].
///
/// ### How it works
/// [toJson] encodes the payload, type, priority, timestamp, source (by
/// cell id), trace, [PulseContext] lineage, and a **parent digest**. The
/// parent is not recursively serialised — only the digest of its own
/// canonical form — because deep chains would balloon the wire format, and
/// because identical parent pulses should collapse to identical hashes
/// (that is what makes replay reconstructable from the ledger). [fromJson]
/// is the inverse: it verifies the parent digest and rebuilds the chain
/// bottom-up, root first.
///
/// ### Non-obvious: the materialise boundary
///
/// The hot path produces `_FastPulse`/`_StepPulse` flyweights. Those carry
/// their state in plain fields instead of the canonical record, so [toJson]
/// rejects them by default and [materialise] is the *explicit* boundary
/// that replaces them with equivalent plain `_Pulse` nodes. Always encode
/// `PulseCodec.toJson(PulseCodec.materialise(pulse))`.
///
/// See also:
/// * [PulseContextCodec] — the context codec this serialiser delegates to.
/// * [fingerprint] — the hashing primitive the parent digests use.
/// {@category Replay}
class PulseCodec {
  const PulseCodec._();

  /// Encodes [pulse] into a canonical JSON map.
  ///
  /// Throws [ArgumentError] if [pulse] is a `_FastPulse` or `_StepPulse` —
  /// callers that receive pulses from a hot path must call [materialise]
  /// first.
  ///
  /// ### Parameters:
  /// - [pulse]: The pulse to encode, already materialised.
  ///
  /// ### Returns:
  /// The canonical JSON map. Unset optional fields are stripped so the
  /// canonical bytes stay compact; the one exception is a locally-null
  /// payload that overrides a non-null parent payload, which is kept as an
  /// explicit `null` marker.
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
  /// ### Parameters:
  /// - [json]: The canonical map produced by [toJson].
  /// - [parent]: The already-reconstructed parent pulse, required when the
  ///   wire record carries a `parentDigest`. The digest is verified against
  ///   the supplied parent, and the parent's trace must be a prefix of the
  ///   wire `trace` (the remainder becomes the leaf's local step).
  ///   Reconstruct chains bottom-up — root first — so every level
  ///   round-trips byte-for-byte.
  ///
  /// ### Returns:
  /// A plain `_Pulse` (the shape the codec accepts on the way out).
  /// Callers that need a typed pulse for a typed receptor cast the payload
  /// before constructing the receiving cell; the codec has no way to know
  /// the receiving type statically.
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
    // Fidelity fix (review): the runtime's default/system context is
    // stored as `null` inside `_Pulse` (the getter surfaces
    // `PulseContext.system`), and `isGoverned` is decided from the
    // STORED value. Decoding always produced a materialised PulseContext,
    // so a recorded ungoverned pulse came back governed — the value-cell
    // pipeline then took the governed `evolve` path and failed typed
    // `root` casts downstream. Encode the decoded context back and
    // compare with the system context's encoding (the codec guarantees
    // encode(decode(x)) == encode(x)): a system context round-trips to
    // `null` storage and the pulse stays ungoverned.
    final effectiveContext = canonicalJsonEncode(
              PulseContextCodec.toJson(context),
            ) ==
            canonicalJsonEncode(PulseContextCodec.toJson(PulseContext.system))
        ? null
        : context;

    final parentDigest = json['parentDigest'];
    PulseBase<dynamic>? parentBase;
    if (parentDigest != null) {
      if (parent == null) {
        throw ArgumentError(
          'PulseCodec.fromJson: parentDigest present but no parent '
          'provided. Supply the reconstructed parent, or use the ledger '
          'ledger API which resolves parents by digest.',
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
      context: effectiveContext,
      step: localSteps.isEmpty ? null : localSteps.single,
      parent: parentBase,
    );
  }

  /// Replaces an un-materialised pulse (i.e. `_FastPulse`/`_StepPulse`) —
  /// and any un-materialised nodes in its parent chain — with equivalent
  /// plain `_Pulse` nodes that the codec accepts.
  ///
  /// ### How it works
  /// This is a cold path (called once per pulse before persistence). The
  /// result preserves resolved payload, type, priority, timestamp, source,
  /// context, policy, and the full trace; the flyweight structure itself is
  /// deliberately flattened into the canonical chain shape.
  ///
  /// ### Returns:
  /// The materialised pulse.
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
      localPayload: (shape & PulseBase._kPayload) != 0 || hasAppendedPulse,
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
/// ### How it works
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
/// (graph registration). Empty in a serialisation-only build, in which case `_sourceFromId`
/// returns `null` and the reconstructed pulse has no source — which is
/// fine, because serialisation tests do not depend on source identity.
///
/// Kept deliberately private so the public graph registry can replace
/// this implementation without breaking any code that imports the codec.
class _ReplayCellRegistry {
  static final Map<String, Cell> _cells = {};

  // ignore: unused_element — `CellGraph.register` hooks here.
  static void register(String id, Cell cell) {
    _cells[id] = cell;
  }

  // ignore: unused_element — graph teardown hook.
  static void unregister(String id) {
    _cells.remove(id);
  }

  static Cell? lookup(String id) => _cells[id];

  /// Clears the registry (tests only; paired with
  /// `CellGraphRegistry.forceReset`).
  static void forceReset() {
    _cells.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public pulse JSON codec — `encodePulse` / `decodePulse` (Pulse-Serialization
// plan). Distinct from [PulseCodec]: this codec serialises the full recursive
// pulse (payload, type, timestamp, source id, priority, context, step, user,
// parent chain, collective children) under a `__pulse__` version
// discriminator, and refuses non-serialisable fields with a typed error.
// ─────────────────────────────────────────────────────────────────────────────

/// A pulse cannot be serialised because it carries a field that has no
/// honest wire representation.
///
/// ### When to use
/// Catch it around [Pulse.toJson] / [encodePulse] and either strip the
/// offending field or log the rejection — never silently drop it.
///
/// ### How it works
/// [field] names the offending field: `'policy'`, `'onComplete'`,
/// `'onError'`, `'onProgress'`, `'scrutinize'`, `'source'` (empty
/// [Cell.id]), `'payload'`, `'context'`, or `'user'` (non-JSON-encodable
/// value). [pulse] is the pulse whose field failed — for a parent chain
/// failure it is the node that carried the field.
///
/// ### Non-obvious
/// - **Fail loudly, don't fake it.** A dropped callback would silently
///   change replay semantics; the error is the honest answer.
/// - **Callbacks and policies are not serialisable by construction.**
///
/// {@category Replay}
class PulseNotSerializable implements Exception {
  /// The offending field.
  final String field;

  /// The pulse whose field was non-serialisable.
  final PulseBase pulse;

  const PulseNotSerializable(this.field, this.pulse);

  @override
  String toString() => 'PulseNotSerializable: pulse carries $field. '
      'Pulses with $field cannot be serialized.';
}

/// A pulse JSON record cannot be decoded.
///
/// ### When to use
/// Catch it around [Pulse.fromJson] / [decodePulse]; the message names
/// the decode problem and [cause] carries the underlying error when one
/// exists.
///
/// {@category Replay}
class PulseDecodeError implements Exception {
  final String message;
  final Object? cause;
  const PulseDecodeError(this.message, [this.cause]);

  @override
  String toString() => 'PulseDecodeError: $message';
}

/// Encodes [pulse] to its canonical JSON wire form.
///
/// Throws [PulseNotSerializable] if the pulse (or any pulse in its
/// `parent` chain) carries a non-serialisable field: `policy`,
/// `onComplete`, `onError`, `onProgress`, `scrutinize`, a `source` whose
/// [Cell.id] is empty, or a `payload` / `context` / `user` value that is
/// not JSON-encodable.
///
/// The encoded form is canonical: two pulses with the same logical
/// content produce the same byte string (see [canonicalJsonEncode]).
///
/// {@category Replay}
Map<String, dynamic> encodePulse(PulseBase pulse) {
  // 1. Non-serialisable field check over the WHOLE causal chain — the
  //    honest boundary. The chain includes both the parent lineage and
  //    the appended-pulse lineage (evolved nodes carry the appended
  //    pulse in `_pulse`, not `_parent`).
  _assertSerialisable(pulse);

  // 2. Normalise the chain shape for the wire. `_FastPulse` /
  //    `_StepPulse` flyweights and evolved chains read through the
  //    public getters; the wire format never preserves the internal
  //    representation, only the semantic chain (steps, payloads,
  //    parents). The original pulse keeps its public surface (payload,
  //    user, collective children) via the getters below.
  final isComposite = pulse is CollectivePulse;
  final payload = isComposite
      ? null
      : _tryJsonEncode(
          pulse.payload,
          field: 'payload',
          pulse: pulse,
        );
  final user = _tryJsonEncode(
    pulse._user,
    field: 'user',
    pulse: pulse,
  );
  final Map<String, Object?> contextJson;
  try {
    contextJson = PulseContextCodec.toJson(pulse.context);
  } catch (_) {
    throw PulseNotSerializable('context', pulse);
  }

  final parent = pulse._parent;
  final source = pulse.source;
  final timestamp = pulse.timestamp.toUtc();
  final canonicalTimestamp = DateTime.utc(
          timestamp.year,
          timestamp.month,
          timestamp.day,
          timestamp.hour,
          timestamp.minute,
          timestamp.second,
          timestamp.millisecond)
      .toIso8601String();

  return {
    '__pulse__': '1.0.0',
    'payload': payload,
    'type': pulse.type is String ? pulse.type : null,
    'timestamp': canonicalTimestamp,
    'source': source?.id,
    'priority': pulse.priority,
    'context': contextJson,
    'step': _localStepOf(pulse),
    'user': user,
    'parent': parent != null ? encodePulse(parent) : null,
    'isComposite': isComposite,
    'children': isComposite
        ? [
            for (final child in (pulse as CollectivePulse).payload)
              encodePulse(child as PulseBase),
          ]
        : null,
  };
}

/// Decodes a pulse from the canonical JSON produced by [encodePulse].
///
/// [resolver] is called when the encoded pulse carries a `source`; it
/// returns the live [Cell] with that id, or `null` if the cell is not in
/// the current graph. A `null` resolution is not an error — the decoded
/// pulse simply has `source == null`.
///
/// Throws [PulseDecodeError] if the input is not well-formed canonical
/// JSON or if the version discriminator is unsupported.
///
/// {@category Replay}
PulseBase decodePulse(
  Map<String, dynamic> json, {
  Cell? Function(String id)? resolver,
}) {
  // 1. Version discriminator.
  final version = json['__pulse__'];
  if (version == null) {
    throw PulseDecodeError('missing __pulse__ version discriminator');
  }
  if (version is! String || !version.startsWith('1.')) {
    throw PulseDecodeError('unsupported pulse version: $version');
  }

  // 2. Parent chain (recursive).
  final parentJson = json['parent'];
  PulseBase? parent;
  if (parentJson != null) {
    if (parentJson is! Map) {
      throw PulseDecodeError('malformed parent: expected a pulse object');
    }
    parent = decodePulse(
      Map<String, dynamic>.from(parentJson),
      resolver: resolver,
    );
  }

  // 3. Source resolution.
  final sourceId = json['source'];
  if (sourceId != null && sourceId is! String) {
    throw PulseDecodeError('malformed source: expected a cell id string');
  }
  final source = sourceId is String ? resolver?.call(sourceId) : null;

  // 4. Context. Mirror the ledger codec's fidelity fix: a system context
  //    round-trips to null storage so ungoverned pulses stay ungoverned.
  final contextJson = json['context'];
  if (contextJson is! Map) {
    throw PulseDecodeError('missing or malformed context');
  }
  final PulseContext context;
  try {
    context = PulseContextCodec.fromJson(
      Map<String, Object?>.from(contextJson),
    );
  } catch (e) {
    throw PulseDecodeError('malformed context', e);
  }
  final storedContext =
      canonicalJsonEncode(PulseContextCodec.toJson(context)) ==
              canonicalJsonEncode(
                PulseContextCodec.toJson(PulseContext.system),
              )
          ? null
          : context;

  // 5. Envelope fields.
  final timestampRaw = json['timestamp'];
  if (timestampRaw is! String) {
    throw PulseDecodeError('missing or malformed timestamp');
  }
  final DateTime timestamp;
  try {
    timestamp = DateTime.parse(timestampRaw);
  } catch (e) {
    throw PulseDecodeError('malformed timestamp', e);
  }

  final priority = json['priority'];
  if (priority != null && priority is! int) {
    throw PulseDecodeError('malformed priority');
  }
  final type = json['type'];
  if (type != null && type is! String) {
    throw PulseDecodeError('malformed type');
  }
  final step = json['step'];
  if (step != null && step is! String) {
    throw PulseDecodeError('malformed step');
  }
  final isComposite = json['isComposite'] as bool? ?? false;

  // 6. Payload and children.
  if (isComposite) {
    final childrenJson = json['children'];
    if (childrenJson is! List) {
      throw PulseDecodeError('composite pulse missing children');
    }
    final children = <Pulse<dynamic>>[
      for (final child in childrenJson)
        if (child is Map)
          decodePulse(
            Map<String, dynamic>.from(child),
            resolver: resolver,
          ) as Pulse<dynamic>
        else
          throw PulseDecodeError('malformed child: expected a pulse object'),
    ];
    return _CollectivePulse<dynamic>(
      children,
      type: type,
      timestamp: timestamp,
      source: source,
      priority: priority,
      context: storedContext,
      parent: parent,
    );
  }

  final payload = _jsonDecodeValue(json['payload']);
  // A locally-null payload over a non-null parent payload is a distinct
  // runtime state (_NullPayloadPulse pins the getter); plain _Pulse
  // records cannot express it.
  if (payload == null && parent != null && parent.payload != null) {
    return _NullPayloadPulse(
      context: storedContext,
      type: type,
      timestamp: timestamp,
      source: source,
      priority: priority,
      step: step,
      parent: parent,
    );
  }
  return _Pulse<dynamic>(
    payload: payload,
    type: type,
    timestamp: timestamp,
    source: source,
    priority: priority,
    context: storedContext,
    step: step,
    parent: parent,
  );
}

/// The leaf-local step of [pulse] — the one breadcrumb the node itself
/// added, as opposed to the merged [Pulse.trace].
///
/// Evolved nodes carry their new pulse in `_pulse` (the appended-pulse
/// lineage), so an evolved node's local step is the appended pulse's
/// step; `_FastPulse` / `_StepPulse` flyweights keep it in plain fields.
String? _localStepOf(PulseBase pulse) {
  if (pulse is _FastPulse) return (pulse as dynamic)._step as String?;
  if (pulse is _StepPulse) return (pulse as dynamic)._stepValue as String?;
  final appended = pulse._pulse;
  if (appended != null) {
    final step = _localStepOf(appended);
    if (step != null) return step;
  }
  if ((pulse._shape & PulseBase._kStep) != 0) {
    return pulse._record.root.secondary.step as String?;
  }
  return null;
}

/// Fails loudly on the first non-serialisable field found anywhere in
/// [pulse]'s causal chain — the parent lineage and, for evolved nodes,
/// the appended-pulse lineage (`_pulse`).
void _assertSerialisable(PulseBase pulse) {
  if (pulse._onComplete != null) {
    throw PulseNotSerializable('onComplete', pulse);
  }
  if (pulse._onError != null) throw PulseNotSerializable('onError', pulse);
  if (pulse._onProgress != null) {
    throw PulseNotSerializable('onProgress', pulse);
  }
  if (pulse._scrutinize != null) {
    throw PulseNotSerializable('scrutinize', pulse);
  }
  if (pulse.policy != null) throw PulseNotSerializable('policy', pulse);
  final source = pulse.source;
  if (source != null && source.id.isEmpty) {
    throw PulseNotSerializable('source', pulse);
  }
  final parent = pulse._parent;
  if (parent != null) _assertSerialisable(parent);
  final appended = pulse._pulse;
  if (appended != null) _assertSerialisable(appended);
}

Object? _tryJsonEncode(
  Object? value, {
  required String field,
  required PulseBase pulse,
}) {
  try {
    return _jsonEncodeValue(value);
  } catch (_) {
    throw PulseNotSerializable(field, pulse);
  }
}

Object? _jsonEncodeValue(Object? value) {
  if (value == null) return null;
  if (value is String || value is num || value is bool) return value;
  if (value is List) {
    return [for (final item in value) _jsonEncodeValue(item)];
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        '${entry.key}': _jsonEncodeValue(entry.value),
    };
  }
  if (value is DateTime) {
    final utc = value.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute,
            utc.second, utc.millisecond)
        .toIso8601String();
  }
  throw StateError('not JSON-encodable: ${value.runtimeType}');
}

Object? _jsonDecodeValue(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        '${entry.key}': _jsonDecodeValue(entry.value),
    };
  }
  if (value is List) {
    return [for (final item in value) _jsonDecodeValue(item)];
  }
  return value;
}
