// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

class _OneNucleus<O extends One> extends OneNucleusBase<O> {
  _OneNucleus({
    super.id,
    super.createdAt,
    super.lastModifiedAt,
    super.fields,
    super.relations,
    super.descendants,
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
    super.identityMap,
    super.forceLock,
    super.user,
  }) : super();

  _OneNucleus.evolve(
      {Cell? bind,
      Context? context,
      RelatableReceptor<Tissue, O>? receptor,
      TestOne<O>? testRule,
      Synapses? synapses,
      bool forceLock = true,
      OneNucleus<O>? override,
      required super.principal})
      : super.evolve(
            override: override ??
                _OneNucleus.fromRecord(
                    record: NucleusBase.mask(
                        bind: bind,
                        context: context,
                        receptor: receptor,
                        testRule: testRule,
                        synapses: synapses,
                        forceLock: forceLock)));

  _OneNucleus.fromRecord({super.record}) : super.fromRecord();

  @override
  OneNucleus<O> get clone {
    final receptor = get<RelatableReceptor<Tissue, O>?>(
        () => record.mask.inheritable.receptor,
        orElse: null);
    final testRule =
        get<TestOne<O>?>(() => record.mask.inheritable.testRule, orElse: null);
    final context =
        get<Context?>(() => record.mask.inheritable.context, orElse: null);
    return _OneNucleus<O>.fromRecord(record: (
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
      )
    ));
  }
}

abstract class OneNucleusBase<O extends One>
    extends RelatableNucleusBase<dynamic, O> implements OneNucleus<O> {
  OneNucleusBase({
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<Tissue, O> receptor = RelatableReceptor.passThrough,
    TestOne<O> testRule = TestOne.allowAll,
    Synapses synapses = Synapses.enabled,
    bool identityMap = false,
    bool forceLock = false,
    Record? user,
    String? id,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    Tissue<Field>? fields,
    Tissue<Relation>? relations,
    Tissue<One>? descendants,
  }) : super.fromRecord(
          record: fields != null
              ? (
                  mask: TissueNucleusBase.local(
                    bind: bind,
                    context: context,
                    receptor: receptor,
                    testRule: testRule,
                    synapses: synapses,
                    container: Container.map,
                    forceLock: forceLock,
                    user: user,
                  ),
                  relatable: (
                    fields: FinalBox<Tissue<Field>>(),
                    relations: FinalBox<Tissue<Relation>>(),
                    descendants: FinalBox<Tissue<One>>()
                  ),
                  one: (
                    id: id != null
                        ? (FinalBox<String>()..value = id)
                        : FinalBox<String>(),
                    createdAt: createdAt != null
                        ? (FinalBox<DateTime>()..value = createdAt)
                        : FinalBox<DateTime>(),
                    lastModifiedAt: lastModifiedAt != null
                        ? Box<DateTime>(lastModifiedAt)
                        : Box<DateTime>(),
                  )
                )
              : (
                  mask: TissueNucleusBase.local(
                    bind: bind,
                    context: context,
                    receptor: receptor,
                    testRule: testRule,
                    synapses: synapses,
                    container: Container.map,
                    forceLock: forceLock,
                    user: user,
                  ),
                ),
        ) {
    if (fields != null) {
      record.relatable.fields.value = fields;
      record.relatable.relations.value =
          relations ??= RelatableNucleusBase.createRelations(fields);
      record.relatable.descendants.value =
          descendants ?? RelatableNucleusBase.createDescendants(relations);
    }
  }

  const OneNucleusBase.fromRecord({super.record}) : super.fromRecord();

  OneNucleusBase.evolve(
      {super.override, required OneNucleus<O> super.principal})
      : super.evolve();

  @override
  String get id {
    return get<String>(() => record.one.id, fallback: () => principal!.id);
  }

  @override
  DateTime get lastModifiedAt {
    return get<DateTime>(() => record.one.lastModifiedAt,
        fallback: () => principal!.lastModifiedAt);
  }

  @override
  DateTime get createdAt {
    return get<DateTime>(() => record.one.createdAt,
        fallback: () => principal!.createdAt);
  }

  @override
  RelatableReceptor<Tissue, O> get receptor {
    return get<RelatableReceptor<Tissue, O>>(() => record.mask.receptor,
        fallback: () => principal!.receptor);
  }

  @override
  TestOne<O> get testRule {
    return get<TestOne<O>>(() => record.mask.testRule,
        fallback: () => principal!.testRule);
  }

  @override
  OneNucleus<O>? get principal => super.principal as OneNucleus<O>?;

  @override
  TissueContainer<Tissue<dynamic>, TissueMap<Symbol, Tissue>> get container {
    return get<TissueContainer<Tissue<dynamic>, TissueMap<Symbol, Tissue>>>(
        () => record.mask.container,
        fallback: () => principal!.record.mask.container);
  }

  @override
  Container get containerType {
    return get<Container>(() => record.mask.containerType,
        fallback: () => principal!.containerType, orElse: Container.map);
  }
}

abstract class OneBase<O extends One>
    extends UnmodifiableTissueMapBase<Symbol, Tissue, O>
    with RelatableMixin
    implements One {
  @override
  final OneNucleus<O> _nucleus;

  OneBase._(
    OneNucleus<O> super.properties, {
    Iterable<MapEntry<Symbol, Field>>? entries,
    super.unmodifiableElement = false,
  })  : _nucleus = properties,
        super(entries: entries) {
    if (entries != null && entries.isNotEmpty) {
      final elements = entries
          .map((en) => en.value.toList(growable: false))
          .reduce((c, n) => [...c, ...n])
          .toSet();

      Tissue<Field> collective = TissueSet<Field>(
        elements.cast(),
        synapses: Synapses(downstreams: [this]),
      );

      _nucleus.record.relatable.fields.value = collective;
      _nucleus.record.relatable.relations.value =
          RelatableNucleusBase.createRelations(collective);
      _nucleus.record.relatable.descendants.value =
          RelatableNucleusBase.createDescendants(
              _nucleus.record.relatable.relations);

      _nucleus.synapses.link(collective, downstreamCell: this);
    }
  }

  OneBase(
    OneNucleus<O> properties, {
    Iterable<Field>? fields,
  }) : this._(properties,
            entries: fields?.map<MapEntry<Symbol, Field>>(
                (f) => MapEntry<Symbol, Field>(f.name, f)));

  OneBase.from(
    OneNucleus<O> properties, {
    required Map<Symbol, Field> map,
  }) : this._(properties, entries: map.entries);

  OneBase.fromGroup(
    OneNucleus<O> super.properties, {
    required Map<Symbol, Tissue<Field>> group,
  })  : _nucleus = properties,
        super(entries: group.entries, unmodifiableElement: false) {
    if (group.isNotEmpty) {
      final fields = group.values
          .map<List<Field>>((c) => c.toList(growable: false))
          .reduce((c, n) => [...c, ...n])
          .toSet();

      Tissue<Field> collective = TissueSet<Field>(
        fields,
        bind: Tissue<Tissue<Field>>(group.values),
        synapses: Synapses(downstreams: [this]),
      );

      _nucleus.record.relatable.fields.value = collective;
      _nucleus.record.relatable.relations.value =
          RelatableNucleusBase.createRelations(collective);
      _nucleus.record.relatable.descendants.value =
          RelatableNucleusBase.createDescendants(
              _nucleus.record.relatable.relations);

      _nucleus.synapses.link(collective, downstreamCell: this);
    }
  }

  @override
  String get id => _nucleus.id;

  @override
  DateTime get lastModifiedAt => _nucleus.lastModifiedAt;

  @override
  DateTime get createdAt => _nucleus.createdAt;

  @override
  One deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestOne<O> testRule = TestOne.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled});

  @override
  TestOne<O> get validate => _nucleus.testRule;

  @override
  String toJson(
      {int cascade = 0, String? Function(Object? nonEncodable)? toEncodable}) {
    // TODO: implement toJson
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> toMap({int cascade = 0}) {
    final uniques = Set<One>.identity();
    return _toMap(cascade: cascade, lookup: uniques);
  }

  Map<String, dynamic> _toMap({int cascade = 0, required Set<One> lookup}) {
    final map = Map<String, dynamic>.from(
        <String, dynamic>{'_\$Type': runtimeType, '_\$id': id});
    final support = <String, dynamic>{'fields': <Map<String, dynamic>>[]};
    // ignore: unused_local_variable
    final fieldsMap = _nucleus.container.store as Map<Symbol, Field>;

    return map..addAll({'_\$Blend': support});
  }

  @override
  Many<One> operator +(Relatable other) {
    if (other is Iterable<One>) {
      return Many<One>([this, ...(other as Iterable<One>)]);
    } else if (other is One) {
      return Many<One>([this, other]);
    }
    if (other is Cascade) {
      if (other.relatable is One) {
        return Many<One>([this, other.relatable as One]);
      } else if (other.relatable is Iterable<One>) {
        return Many<One>([this, ...(other.relatable as Iterable<One>)]);
      }
    }
    return Many<One>([this, ...other.descendants]);
  }
}

mixin FieldTissueMixin<O extends One> on OneBase<O>
    implements UnmodifiableTissueMap<Symbol, Tissue> {
  @override
  O deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestOne<O> testRule = TestOne.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled});

  @override
  Iterator<Field> get iterator {
    return fields.iterator;
  }

  @override
  Iterable<Field> get values {
    return fields;
  }

  @override
  Iterable<MapEntry<Symbol, Field>> get entries {
    return super.entries.cast();
  }

  @override
  Iterable<Field> followedBy(Iterable<Field> other) {
    return fields.followedBy(other).cast();
  }

  @override
  Field reduce(Field Function(Tissue value, Tissue element) combine) {
    return fields.reduce(combine);
  }

  @override
  Field firstWhere(bool Function(Field element) test,
      {Field Function()? orElse}) {
    return fields.firstWhere((element) => test(element), orElse: orElse);
  }

  @override
  Field lastWhere(bool Function(Field element) test,
      {covariant Field Function()? orElse}) {
    return fields.lastWhere((element) => test(element), orElse: orElse);
  }

  @override
  Field singleWhere(bool Function(Field element) test,
      {covariant Field Function()? orElse}) {
    return fields.singleWhere((element) => test(element), orElse: orElse);
  }

  @override
  Iterable<Field> where(bool Function(Field element) test) {
    return fields.where((element) => test(element)).cast();
  }

  @override
  Iterable<Field> skip(int count) {
    return fields.skip(count).cast();
  }

  @override
  Iterable<Field> take(int count) {
    return fields.take(count).cast();
  }

  @override
  Iterable<Field> skipWhile(bool Function(Field element) test) {
    return fields.skipWhile((element) => test(element)).cast();
  }

  @override
  Iterable<Field> takeWhile(bool Function(Field element) test) {
    return fields.takeWhile((element) => test(element)).cast();
  }

  @override
  Iterable<T> expand<T>(Iterable<T> Function(Field element) toElements) {
    return fields.expand((element) => toElements(element)).cast();
  }

  @override
  T fold<T>(
      T initialValue, T Function(T previousValue, Field element) combine) {
    return fields.fold(initialValue,
        (previousValue, element) => combine(previousValue, element));
  }

  @override
  bool every(bool Function(Field<One, dynamic> element) test) {
    return fields.every((element) => test(element));
  }

  @override
  bool any(bool Function(Field<One, dynamic> element) test) {
    return fields.any((element) => test(element));
  }

  @override
  void forEach(void Function(Field element) action) {
    for (var element in fields) {
      action(element);
    }
  }

  @override
  Iterable<T> map<T>(T Function(Field e) toElement) {
    return fields.map((element) => toElement(element)).cast();
  }

  @override
  List<Field> toList({bool growable = true}) {
    return fields.toList(growable: growable).cast();
  }

  @override
  Set<Field> toSet() {
    return fields.toSet().cast();
  }

  // --- Static Tissue Overrides ---

  @override
  bool add(Symbol key, Field value) => false;

  @override
  void addAll(Map<Symbol, Field> other) {}

  @override
  void addEntries(Iterable<MapEntry<Symbol, Field>> newEntries) {}

  @override
  Field? remove(Object? key) => null;

  @override
  void removeWhere(bool Function(Symbol key, Field value) predicate) {}

  @override
  Field putIfAbsent(Symbol key, Field Function() ifAbsent) {
    throw UnsupportedError(
        'Unmodifiable Tissue: Cannot insert into organism structure.');
  }

  @override
  Field update(Symbol key, Field Function(Tissue value) update,
      {Field Function()? ifAbsent}) {
    throw UnsupportedError(
        'Unmodifiable Tissue: Cannot update organism structural units.');
  }

  @override
  void updateAll(Field Function(Symbol key, Tissue value) update) {
    throw UnsupportedError(
        'Unmodifiable Tissue: Cannot update organism structural units.');
  }
}

mixin ValueTissueMixin<O extends One, V, C extends Tissue<V>> on OneBase<O>
    implements UnmodifiableTissueMap<Symbol, Tissue> {
  @override
  O deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestOne<O> testRule = TestOne.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled});

  @override
  Iterator<C> get iterator {
    return values.iterator;
  }

  @override
  Iterable<C> get values {
    return (_nucleus.container.store as Map<Symbol, C>).values;
  }

  @override
  Iterable<MapEntry<Symbol, C>> get entries {
    return (_nucleus.container.store as Map<Symbol, C>).entries;
  }

  @override
  Iterable<C> followedBy(Iterable<C> other) {
    return values.followedBy(other).cast();
  }

  @override
  C reduce(C Function(Tissue value, Tissue element) combine) {
    return values.reduce(combine);
  }

  @override
  C firstWhere(bool Function(C element) test, {C Function()? orElse}) {
    return values.firstWhere((element) => test(element), orElse: orElse);
  }

  @override
  C lastWhere(bool Function(C element) test, {covariant C Function()? orElse}) {
    return values.lastWhere((element) => test(element), orElse: orElse);
  }

  @override
  C singleWhere(bool Function(C element) test,
      {covariant C Function()? orElse}) {
    return values.singleWhere((element) => test(element), orElse: orElse);
  }

  @override
  Iterable<C> where(bool Function(C element) test) {
    return values.where((element) => test(element)).cast();
  }

  @override
  Iterable<C> skip(int count) {
    return values.skip(count).cast();
  }

  @override
  Iterable<C> take(int count) {
    return values.take(count).cast();
  }

  @override
  Iterable<C> skipWhile(bool Function(C element) test) {
    return values.skipWhile((element) => test(element)).cast();
  }

  @override
  Iterable<C> takeWhile(bool Function(C element) test) {
    return values.takeWhile((element) => test(element)).cast();
  }

  @override
  Iterable<T> expand<T>(Iterable<T> Function(C element) toElements) {
    return values.expand((element) => toElements(element)).cast();
  }

  @override
  T fold<T>(T initialValue, T Function(T previousValue, C element) combine) {
    return values.fold(initialValue,
        (previousValue, element) => combine(previousValue, element));
  }

  @override
  bool every(bool Function(C element) test) {
    return values.every((element) => test(element));
  }

  @override
  bool any(bool Function(C element) test) {
    return values.any((element) => test(element));
  }

  @override
  void forEach(void Function(C element) action) {
    for (var element in values) {
      action(element);
    }
  }

  @override
  Iterable<T> map<T>(T Function(C e) toElement) {
    return values.map((element) => toElement(element)).cast();
  }

  @override
  List<C> toList({bool growable = true}) {
    return values.toList(growable: growable).cast();
  }

  @override
  Set<C> toSet() {
    return values.toSet().cast();
  }

  // --- Static Tissue Overrides ---

  @override
  bool add(Symbol key, C value) => false;

  @override
  void addAll(Map<Symbol, C> other) {}

  @override
  void addEntries(Iterable<MapEntry<Symbol, C>> newEntries) {}

  @override
  C? remove(Object? key) => null;

  @override
  void removeWhere(bool Function(Symbol key, C value) predicate) {}

  @override
  C putIfAbsent(Symbol key, C Function() ifAbsent) {
    throw UnsupportedError(
        'Unmodifiable Tissue: Organisms have fixed structural markers.');
  }

  @override
  C update(Symbol key, C Function(Tissue value) update,
      {C Function()? ifAbsent}) {
    throw UnsupportedError('Unmodifiable Tissue: Organism tissues are fixed.');
  }

  @override
  void updateAll(C Function(Symbol key, Tissue value) update) {
    throw UnsupportedError('Unmodifiable Tissue: Organism tissues are fixed.');
  }
}

abstract class UnmodifiableOneBase<O extends One>
    extends UnmodifiableTissueMapBase<Symbol, Tissue, O>
    with UnmodifiableRelatableMixin
    implements UnmodifiableOne {
  @override
  final OneNucleus<O> _nucleus;

  UnmodifiableOneBase._(OneNucleus<O> super.properties,
      {Iterable<MapEntry<Symbol, Field>>? super.entries,
      super.unmodifiableElement = false})
      : _nucleus = properties;

  UnmodifiableOneBase(OneBase<O> bind) : this._(bind._nucleus);

  @override
  One deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestOne<O> testRule = TestOne.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled});

  @override
  TestOne<O> get validate => _nucleus.testRule;
}

final class PushId {
  static const String _kPushChars =
      '-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz';

  static String Function() generate = () {
    var lastPushTime = 0;
    final randomSuffix = <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    final random = math.Random.secure();

    return () {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      var id = _toPushIdBase64(now, 8);

      if (now != lastPushTime) {
        for (var i = 0; i < 12; i += 1) {
          randomSuffix[i] = random.nextInt(64);
        }
      } else {
        int i;
        for (i = 11; i >= 0 && randomSuffix[i] == 63; i--) {
          randomSuffix[i] = 0;
        }
        randomSuffix[i] += 1;
      }
      final suffixStr = randomSuffix.map((i) => _kPushChars[i]).join();
      lastPushTime = now;

      return '$id$suffixStr';
    };
  }();

  static String _toPushIdBase64(int value, int numChars) {
    final buf = StringBuffer();
    for (var i = numChars - 1; i >= 0; i -= 1) {
      buf.write(_kPushChars[value % 64]);
      value = (value / 64).floor();
    }
    assert(value == 0);
    return buf.toString();
  }
}

class _TestOneNever extends TestOne<Never> implements TestPasses {
  const _TestOneNever() : super(const {});

  @override
  TestOne<Never> operator +(covariant TestRule other) {
    return this;
  }

  @override
  bool action(Function action, {required Cell host, Arguments? arguments}) {
    return true;
  }

  @override
  bool call(object, {covariant Cell? host, arguments}) {
    return true;
  }

  @override
  bool element(covariant Never? element,
      {required Cell host, Function? action}) {
    return true;
  }

  @override
  bool link(covariant Cell link, {required Cell host}) {
    return false;
  }

  @override
  bool pulse(covariant Pulse<dynamic> pulse, {required Cell host}) {
    return true;
  }
}
