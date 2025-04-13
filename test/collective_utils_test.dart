import 'package:cell/collective.dart';


// ignore_for_file: prefer_typing_uninitialized_variables
// ignore_for_file: avoid_function_literals_in_foreach_calls
// ignore_for_file: unused_local_variable
// ignore_for_file: iterable_contains_unrelated_type
// ignore_for_file: avoid_print

var eventNum = 0;

void nextEvent([int? i]) => eventNum = i ?? eventNum++;

CollectivePost? onPost(CollectivePost signal, [Cell? collective]) {

    print('Event: $eventNum');
    print('Post: ${signal.runtimeType} ${identityHashCode(signal)}');
    print('From: ${signal.from.runtimeType} ${identityHashCode(signal.from)}');
    print('To: ${collective.runtimeType}');
    for (var en in signal.body!.entries) {
      if (en.key == Collective.elementAdded) {
        en.value.forEach((e) => print('elementAdded: ${e.runtimeType} value: ${e.toString()}'));
      }
      else if (en.key == Collective.elementRemoved) {
        en.value.forEach((e) => print('elementRemoved: ${e.runtimeType} value: ${e.e.toString()}'));
      }
      else if (en.key == Collective.elementUpdated) {
        en.value.forEach((e) => print('elementUpdated: ${e.runtimeType} before: ${e.before}, after: ${e.after}'));
      }
    }

    print('\n');

  return signal;
}

// class TestCollectiveTest<E, C extends Collective<E>> implements TestObject<Object,C> {
//   final bool Function(Object? object) _func;
//   TestCollectiveTest(bool Function(Object? object) test_object) : _func = test_object;
//
//   @override
//   bool call(Object? object, {Collective? on, Function? action, dynamic others}) {
//     return _func(object);
//   }
//
//   @override
//   bool action(Function action, Collective on, {ArgsRecord? args, dynamic others}) {
//     // TODO: implement action
//     throw UnimplementedError();
//   }
//
//   @override
//   TestObject<C> operator +(Object other) {
//     // TODO: implement +
//     throw UnimplementedError();
//   }
//
// }

// class TestOnPost extends OnPost<Collective> {
//   final void Function(Collective on, Post post) _func;
//   TestOnPost(Function(Collective on, Post post) func) : _func = func;
//
//   Post? call(Collective on, Post post) {
//     _func(on,post);
//     return post;
//   }
// }