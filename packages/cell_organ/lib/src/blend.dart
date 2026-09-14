// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell_organ.dart';

class BlendNucleus extends OneNucleusBase<Blend> with RelatableNucleusMixin {
  BlendNucleus(String name,
      {Cell? bind,
      Context context = Context.system,
      RelatableReceptor<Tissue, Blend> receptor = RelatableReceptor.passThrough,
      TestOne<Blend> testRule = TestOne.allowAll,
      Synapses synapses = Synapses.enabled,
      Record? user})
      : super.fromRecord(record: (
          mask: TissueNucleusBase.local(
            bind: bind,
            context: context,
            receptor: receptor,
            testRule: testRule,
            synapses: synapses,
            container: Container.map,
            forceLock: false,
            user: user,
          ),
          relatable: (
            fields: FinalBox<Tissue<Field>>(),
            relations: FinalBox<Tissue<Relation>>(),
            descendants: FinalBox<Tissue<One>>()
          ),
          one: (
            id: FinalBox<String>()..value = PushId.generate(),
            createdAt: FinalBox<DateTime>()..value = DateTime.now(),
            lastModifiedAt: Box<DateTime>(valueDateTime.now()),
          ),
          blend: (name: FinalBox<String>()..value = name,)
        ));

  BlendNucleus.evolve(
      {Cell? bind,
      Context? context,
      RelatableReceptor<Tissue, Blend>? receptor,
      TestOne<Blend>? testRule,
      Synapses? synapses,
      Nucleus? override,
      required BlendNucleus super.principal})
      : super.evolve(
            override: override ??
                Nucleus.create<Blend>(
                    bind: bind,
                    context: context ?? Context.system,
                    receptor: receptor ?? RelatableReceptor.passThrough,
                    testRule: testRule ?? TestOne.allowAll,
                    synapses: synapses ?? Synapses.disabled,
                    forceLock: true));

  String get name {
    return get<String>(() => record.blend.name.value,
        fallback: () => principal?.name);
  }

  @override
  BlendNucleus? get principal => super.principal as BlendNucleus?;

  @override
  BlendNucleus get clone {
    final receptor = get<RelatableReceptor<Tissue, Blend>?>(
        () => record.mask.inheritable.receptor,
        orElse: null);
    final testRule = get<TestOne<Blend>?>(
        () => record.mask.inheritable.testRule,
        orElse: null);
    final context =
        get<Context?>(() => record.mask.inheritable.context, orElse: null);
    return BlendNucleus._fromRecord(record: (
      mask: NucleusBase.mask(
          context: context,
          receptor: receptor,
          testRule: testRule,
          synapses: synapses == Synapses.disabled
              ? Synapses.disabled
              : Synapses.enabled,
          forceLock: false),
      relatable: (
        fields: FinalBox<Tissue<Field>>(),
        relations: FinalBox<Tissue<Relation>>(),
        descendants: FinalBox<Tissue<One>>()
      ),
      one: (
        id: FinalBox<String>()..value = PushId.generate(),
        createdAt: FinalBox<DateTime>()..value = DateTime.now(),
        lastModifiedAt: FinalBox<DateTime>()..value = DateTime.now(),
      ),
      blend: (name: FinalBox<String>(),)
    ));
  }

  BlendNucleus._fromRecord({super.record}) : super.fromRecord();
}

abstract interface class Blend implements One {
  @override
  BlendNucleus get _nucleus;

  String get name;

  factory Blend(
    String name, {
    required Iterable<Field> fields,
    Cell? bind,
    Context context,
    RelatableReceptor<Tissue, Blend> receptor,
    TestOne<Blend> testRule,
    Synapses synapses,
  }) = _BlendFieldTissue;

  factory Blend.from(
    String name, {
    required Map<Symbol, Field> map,
    Cell? bind,
    Context context,
    RelatableReceptor<Tissue, Blend> receptor,
    TestOne<Blend> testRule,
    Synapses synapses,
  }) = _BlendFieldTissue.from;

  factory Blend.group(
    String name, {
    required Map<Symbol, Iterable<Field>> map,
    required MapEntry<Symbol, TissueValue> Function(
            MapEntry<Symbol, Iterable<Field>> entry)
        toValue,
    Cell? bind,
    Context context,
    RelatableReceptor<Tissue, Blend> receptor,
    TestOne<Blend> testRule,
    Synapses synapses,
  }) = _BlendTissueValue;

  factory Blend.fromNucleus(BlendNucleus properties,
      {required Iterable<Field> fields}) {
    return _BlendFieldTissue._(properties,
        map: Map<Symbol, Field>.fromEntries(fields.map<MapEntry<Symbol, Field>>(
            (f) => MapEntry<Symbol, Field>(f.name, f))));
  }

  static Blend fromMap(Map<String, dynamic> map,
      {int cascade = 0, Set<One>? lookup}) {
    if (map['_\$id'] is String && map['_\$Blend'] is Map) {
      final blend = map['_\$Blend'] as Map<String, dynamic>;
      if (blend.containsKey('fields') && blend['fields'] is Iterable) {
        final fieldsPart = blend['fields'] as Iterable;
        if (blend.containsKey('Many') && blend['Many'] is Iterable) {
          final uniques = lookup ?? <One>{};
          final models = Many.fromMap<One>(Map.from({'Many': blend['Many']}),
              cascade: cascade, lookup: uniques);

          // ignore: prefer_typing_uninitialized_variables
          var m, id, type, names, f;
          final fields = Set<Field>.identity();
          for (var mm in fieldsPart) {
            id = mm['id'];
            type = mm['_\$Type'];
            names = mm['names'];
            if (id != null && type != null && names != null) {
              m = models.firstWhereOrNull(
                  (e) => e.id == id && e.runtimeType.toString() == type);
              if (m != null) {
                if (names is Iterable) {
                  bool unmodifiable;
                  for (var n in names) {
                    if (n is String) {
                      unmodifiable = n.startsWith('^');
                      if (unmodifiable) {
                        n = n.substring(1);
                      }
                      f = m.fieldReferences
                          .firstWhereOrNull((f) => symbolAsString(f.name) == n);
                      if (f != null) {
                        fields
                            .add((unmodifiable ? f.unmodifiable : f) as Field);
                      }
                    }
                  }
                } else if (names is String) {
                  f = m.fieldReferences
                      .firstWhereOrNull((f) => symbolAsString(f.name) == names);
                  if (f != null) {
                    fields.add(f as Field);
                  }
                }
              }
            }
          }

          final properties = BlendNucleus(map['name'], bind: map['bind']);
          properties.record.one.createdAt.value = map['createdAt'];
          properties.record.one.lastModifiedAt.value = map['lastModifiedAt'];
          return Blend.fromNucleus(properties, fields: fields);
        }
      }
    }

    throw ArgumentError.value('map', 'map does not contains Blend.');
  }

  static Blend fromJson(String json, {int cascade = 0, Set<One>? lookup}) {
    return Blend.fromMap(jsonDecode(json) as Map<String, dynamic>,
        cascade: cascade, lookup: lookup);
  }

  @override
  Blend get unmodifiable;
}

///     its virtual schema as an `Unmodifiable` shadow, ensuring the
///     entire reachable sub-graph remains immutable.
/// 4.  **Transactional Consistency**: Maintains a link to the principal's
///     synchronization [Lock]. This ensures that read operations across
///     the aggregated fields are consistent with the most recent
///     **Atomic Transaction** performed on the source data.
///
/// ### Design Patterns & Mechanics:
/// *   **The Deputy Pattern**: Typically materialized via `Blend.unmodifiable`
///     or a specialized `BlendNucleus.evolve` call, this interface wraps
///     the virtual DNA with a restrictive [TestOne] validator.
/// *   **Ontological Continuity**: Shares the same [name] and [id] as the
///     mutable principal, allowing it to be used interchangeably in
///     read-only architectural layers (e.g., UI Components or Auditors).
/// *   **Zero-Copy Proxying**: Leverages the same high-performance
///     transduction logic as a standard [Blend], but restricts the
///     protocol to observation and pulse monitoring.
///
/// ### See also:
/// - [Blend]: The base virtual entity interface.
/// - [Unmodifiable]: The framework-wide marker for read-only shadows.
/// - [BlendNucleus]: The underlying genomic record governing this shadow.
abstract interface class UnmodifiableBlend implements Blend, Unmodifiable {}
