

/*
// Associate
class Associate<R extends Relatable> extends AssociateBase<R, Associate, Model> {

  Associate._(Relatable source, {Iterable<Model>? models, bool Function(R relatable)? test})
      : super(<R extends Relatable, O extends Model>(source, {many, bool Function(R relatable)? test}) => Associate<R>._(source, models: many as Iterable<Model>?, testRule: testRule),
      source, many: models, testRule: testRule);

  Associate(Relatable source, {bool Function(R relatable)? test})
      : super(<R extends Relatable, O extends Model>(source, {many, bool Function(R relatable)? test}) => Associate<R>._(source, models: many as Iterable<Model>?, testRule: testRule),
      source, testRule: testRule);

}

// DeAssociate
class DeAssociate<R extends Relatable> extends DeAssociateBase<R, DeAssociate, Model> {

  DeAssociate._(Relatable source, {Iterable<Model>? models, bool Function(R relatable)? test})
      : super(<R extends Relatable, O extends Model>(source, {many, bool Function(R relatable)? test}) => DeAssociate<R>._(source, models: many as Iterable<Model>?, testRule: testRule),
      source, many: models, testRule: testRule);

  DeAssociate(Relatable source, {bool Function(R relatable)? test})
      : super(<R extends Relatable, O extends Model>(source, {many, bool Function(R relatable)? test}) => DeAssociate<R>._(source, models: many as Iterable<Model>?, testRule: testRule),
      source, testRule: testRule);

}

// Move
class Move<R extends Relatable> extends MoveBase<R, Move, Model> {

  Move._(Relatable source, {Iterable<Model>? models, bool Function(R relatable)? test})
      : super(<R extends Relatable, O extends Model>(source, {many, bool Function(R relatable)? test}) => Move<R>._(source, models: many as Iterable<Model>?, testRule: testRule),
      source, many: models, testRule: testRule);

  Move(Relatable source, {bool Function(R relatable)? test})
      : super(<R extends Relatable, O extends Model>(source, {many, bool Function(R relatable)? test}) => Move<R>._(source, models: many as Iterable<Model>?, testRule: testRule),
      source, testRule: testRule);

}

// Select
class Select<R extends Relatable> extends SelectBase<R, Select, Model> {
  Select._(Relatable source, {Iterable<Model>? models, bool Function(R relatable)? test})
      : super(<R extends Relatable, O extends Model>(source, {many, bool Function(R relatable)? test}) => Select<R>._(source, models: many as Iterable<Model>?, testRule: testRule),
      source, many: models, testRule: testRule);

  Select(Relatable source, {bool Function(R relatable)? test})
      : super(<R extends Relatable, O extends Model>(source, {many, bool Function(R relatable)? test}) => Select<R>._(source, models: many as Iterable<Model>?, testRule: testRule),
      source, testRule: testRule);
}

class UpdateCallable {
  const UpdateCallable();

  Future<void> call<H extends Model, V>(Relatable source, V? Function(Field<H,V?> field) newValue, {bool Function(Field<H,V> field)? test, bool Function(dynamic object)? metadata}) {
    return Future<Select>.sync(() => Select(source)).then((select) => select.update<H,V>((f) => newValue(f), testRule: testRule, metadata: metadata));
  }
  // Future<void> call<R extends Relatable, V>(Relatable source, V? Function(Field<Model, V?> field) newValue, {bool Function(R relatable)? test, Symbol? fieldName, Metadata? metadata, Expression? expr}) {
  //   return Future<Select>.sync(() => Select<R>(source, testRule: testRule)).then((select) => select.update<Model,V>((field) => newValue(field), fieldName: fieldName, metadata: metadata, expr: expr));
  // }
}

class ClearCallable {
  const ClearCallable();
  Future<void> call<R extends Relatable, V>(Relatable source, {bool Function(R relatable)? test}) {
    return Future<Select>.sync(() => Select<R>(source, testRule: testRule)).then((select) => select.clear());
  }
}

*/
