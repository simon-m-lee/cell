// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// ignore_for_file: prefer_mixin
// ignore_for_file: unnecessary_lambdas
// ignore_for_file: hash_and_equals
// ignore_for_file: unused_element, unused_field

part of '../../cell_organ.dart';

class _Many<E extends Relatable, C extends Many<E>> extends ManyBase<E, C> {
  _Many(Iterable<E> relatables,
      {Relatable? bind,
      Context context = Context.system,
      TestRelatable<E, C> testRule = TestRelatable.allowAll,
      RelatableReceptor<E, C> receptor = RelatableReceptor.passThrough,
      Synapses synapses = Synapses.enabled,
      bool identitySet = false})
      : this.fromNucleus(
            _ManyNucleus<E, C>(
              bind: bind,
              context: context,
              testRule: testRule,
              receptor: receptor,
              synapses: synapses,
            ),
            relatables: relatables);

  _Many.empty(
      {Relatable? bind,
      Context context = Context.system,
      TestRelatable<E, C> testRule = TestRelatable.allowAll,
      RelatableReceptor<E, C> receptor = RelatableReceptor.passThrough,
      Synapses synapses = Synapses.enabled,
      bool identitySet = false})
      : this.fromNucleus(_ManyNucleus<E, C>(
            bind: bind,
            context: context,
            testRule: testRule,
            receptor: receptor,
            synapses: synapses));

  _Many.fromNucleus(ManyNucleus<E> properties, {super.relatables})
      : super(properties as ManyNucleusBase<E, C>);

  @override
  Many<E> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelatable<E, C> testRule = TestRelatable.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) {
    return _ManyDeputy<E, C>._(this,
        context: context, testRule: testRule, filter: filter);
  }

  @override
  TestRelatable<E, C> get validate => _nucleus.testRule;

  @override
  late final Many<E> unmodifiable = _UnmodifiableMany<E, C>.bind(this);
}

class _ManyDeputy<E extends Relatable, C extends Many<E>> extends _Many<E, C>
    with Deputy<Many<E>> {
  _ManyDeputy._(_Many<E, C> bind,
      {required Context context,
      required TestRelatable<E, C> testRule,
      FilterRule? filter})
      : super.fromNucleus(_ManyNucleus<E, C>.evolve(
            bind: bind,
            context: context,
            testRule: testRule,
            synapses: bind._nucleus.synapses != Synapses.disabled
                ? filter != null
                    ? Synapses(filter: filter)
                    : Synapses.enabled
                : Synapses.disabled,
            principal: bind._nucleus));

  @override
  Many<E> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelatable<E, C> testRule = TestRelatable.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) {
    return _ManyDeputy<E, C>._(_nucleus.bind as _Many<E, C>,
        context: context, testRule: testRule, filter: filter);
  }
}

abstract class ManyBase<E extends Relatable, C extends Many<E>>
    extends TissueSetBase<E, C> with RelatableMixin, ManyMixin<E> {
  @override
  final ManyNucleusBase<E, C> _nucleus;

  ManyBase(ManyNucleusBase<E, C> super.properties, {Iterable<E>? relatables})
      : _nucleus = properties,
        super() {
    // Access the field container from the relatable record.
    final finalBox = _nucleus.record.relatable.fields;

    // Initialize the fields collection as a signaling cell.
    // This aggregates all fields from all elements in the set into one observable collection.
    finalBox.value = TissueSet<Field>(
      _nucleus.container.store
          .map<List<Field>>((r) => r.fields.toList(growable: false))
          .reduce((c, n) => c + n),
      bind: Cell(
          bind: relations,
          receptor: Receptor.from(rule:
              PulseRule<Cell, RelatablePost, RelatablePost>((cell, pulse,
                  {user}) {
            final body = <RelatablePulse, Iterable>{};

            for (var en in pulse.payload!.entries) {
              switch (en.key) {
                // If a new Relatable is added to the Many collection...
                case Relatable.oneAdded || OneAddedEvent():
                  // Extract all field references from the added Relatable and
                  // pulse them as added fields to the Many container.
                  body[Relatable.fieldAdded] = en.value
                      .map<List<Field>>(
                          (m) => m.fieldReferences.toList(growable: false))
                      .reduce((c, n) => c + n)
                      .toSet();
                  break;
                // If a Relatable is removed from the Many collection...
                case Relatable.oneRemoved || OneRemovedEvent():
                  // Pulse the removal of the corresponding fields.
                  body[Relatable.fieldRemoved] = en.value
                      .map<List<Field>>(
                          (m) => m.fieldReferences.toList(growable: false))
                      .reduce((c, n) => c + n)
                      .toSet();
                  break;
                default:
                  // Pass through other events (like updates) as-is.
                  body[en.key] = en.value;
              }
            }

            return RelatablePost._(from: pulse.from, body: body);
          }))),
    );
  }

  @override
  TestRelatable<E, C> get validate => _nucleus.testRule;

  @override
  ModifiableSetAsync<E> get async => ModifiableSetAsync<E>(this);
}

class _UnmodifiableMany<E extends Relatable, C extends Many<E>>
    extends UnmodifiableManyBase<E, C> {
  _UnmodifiableMany(Iterable<E> relatables,
      {bool unmodifiableElement = true, ManyNucleus<E>? properties})
      : this.fromNucleus(properties ?? ManyNucleus<E>(),
            unmodifiableElement: unmodifiableElement, relatables: relatables);

  _UnmodifiableMany.bind(Many<E> bind, {bool unmodifiableElement = true})
      : this.fromNucleus(
            ManyNucleus<E>.evolve(bind: bind, principal: bind._nucleus),
            unmodifiableElement: unmodifiableElement);

  _UnmodifiableMany.fromNucleus(ManyNucleus<E> properties,
      {super.unmodifiableElement, super.relatables})
      : super(properties as ManyNucleusBase<E, C>);

  @override
  Many<E> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelatable<E, C> testRule = TestRelatable.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) {
    return _UnmodifiableMany<E, C>.fromNucleus(
        _ManyNucleus<E, C>.evolve(
            bind: _nucleus.bind,
            testRule: _nucleus.testRule + testRule,
            synapses: (_nucleus.bind as Relatable)._nucleus.synapses !=
                    Synapses.disabled
                ? filter != null
                    ? Synapses(filter: filter)
                    : Synapses.enabled
                : Synapses.disabled,
            principal: _nucleus),
        relatables: this);
  }

  @override
  UnmodifiableMany<E> get unmodifiable => this;

  @override
  TestRelatable<E, C> get validate => _nucleus.testRule;

  @override
  Many<Relatable> operator +(Object other) {
    // TODO: implement +
    throw UnimplementedError();
  }

  @override
  String toJson(
      {int cascade = 0, String? Function(Object? nonEncodable)? toEncodable}) {
    // TODO: implement toJson
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> toMap({int cascade = 0}) {
    // TODO: implement toMap
    throw UnimplementedError();
  }
}

abstract class UnmodifiableManyBase<E extends Relatable, C extends Many<E>>
    extends UnmodifiableTissueSetBase<E, C> implements UnmodifiableMany<E> {
  @override
  final ManyNucleusBase<E, C> _nucleus;

  UnmodifiableManyBase(ManyNucleusBase<E, C> super.properties,
      {super.unmodifiableElement, Iterable<E>? relatables})
      : _nucleus = properties,
        super(elements: relatables);

  @override
  Many<E> get unmodifiable;

  @override
  Many<E> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelatable<E, C> testRule = TestRelatable.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  @override
  Tissue<One> get descendants => _nucleus.descendants.unmodifiable;

  @override
  Tissue<Field> get fields => _nucleus.fields.unmodifiable;

  @override
  Tissue<Relation> get relations => _nucleus.relations.unmodifiable;

  @override
  TestRelatable<E, C> get validate => _nucleus.testRule;
}

mixin ManyMixin<E extends Relatable> implements Many<E> {
  @override
  Map<String, dynamic> toMap({int cascade = 0}) {
    final uniques = Set<Relatable>.identity();

    Map<String, dynamic> cascade0(Relatable relatable, int cascade) {
      final map = Map<String, dynamic>.from(
          <String, dynamic>{'_\$Type': relatable.runtimeType});

      // ignore: prefer_typing_uninitialized_variables
      String n;
      var v;
      for (var f in relatable._nucleus.fields) {
        n = symbolAsString(f.name);
        v = f.value;
        if (f is RelationField) {
          if (cascade > 0) {
            if (v is RelationMany) {
              map[n] = v.map<Map<String, dynamic>>((e) {
                // Only recurse if we haven't seen this instance in the current tree branch
                return uniques.add(e) ? cascade0(e, cascade - 1) : e.toMap();
              }).toList(growable: false);
            } else if (v is HasOne && v.isNotEmpty) {
              final e = v.one as One;
              map[n] = uniques.add(e) ? cascade0(e, cascade - 1) : e.toMap();
            } else if (v is BelongsTo && v.isNotEmpty) {
              // BelongsTo is treated as a reference to prevent massive upward crawls
              map[n] = <String, dynamic>{
                '_\$Type': v.elementType,
                'id': v.one!.id
              };
            }
          }
        } else if (v != null) {
          // Skip empty iterables to keep the output concise
          if (v is Iterable && v.isEmpty) {
            continue;
          }
          map[n] = v;
        }
      }
      return map;
    }

    final maps = cast<Relatable>()
        .map<Map<String, dynamic>>((e) => cascade0(e, cascade))
        .toList(growable: false);
    return Map<String, dynamic>.from(
        <String, dynamic>{'_\$Type': Many, 'Many': maps});
  }

  @override
  String toJson(
      {int cascade = 0, String? Function(Object? nonEncodable)? toEncodable}) {
    // ignore: prefer_typing_uninitialized_variables
    var vv;
    final map = toMap(cascade: cascade);
    return jsonEncode(map, toEncodable: (v) {
      if (toEncodable != null) {
        vv = toEncodable(v);
        if (vv != null) {
          return vv;
        }
      }
      // Fallback to the Field-level string conversion logic
      return Field.valueAs<String>(v);
    });
  }

  @override
  Many<Relatable> operator +(Object other) {
    // final relatables = toList(growable: false);
    // if (!_isRelationType(E)) {
    //   if (other is One) {
    //     if (other is E) {
    //       return Many<One>([...cast(), other]);
    //     }
    //     if (other.one != null) {
    //       return Many<Model>([...cast(), other.one as Model]);
    //     } else {
    //       return Many<One>([...relatables.cast(), other]);
    //     }
    //   } else if (other is Many) {
    //     return other.elementType == E
    //         ? Many<One>([...cast(), ...other.cast<One>()])
    //         : Many<Model>([...cast<Model>(), ...other.cast<Model>()]);
    //   }
    // } else {
    //   if (other is Relatable) {
    //     return Many<Model>([..._extractTopLevelModels(this), ..._extractTopLevelModels(other)]);
    //   } else if (other is Iterable<Relatable>) {
    //     final models = other.map<List<Model>>((e) => _extractTopLevelModels(e).toList(growable: false)).reduce((c, n) => c + n);
    //     return Many(<Model>[..._extractTopLevelModels(this), ...models]);
    //   }
    // }

    throw ArgumentError.value(other, 'other', 'Not Relatable type');
  }
}
