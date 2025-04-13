import 'package:cell/collective.dart';

Future<void> main() async {
  var set;

  // Combine OpenCell with CollectiveList to update items reactively.
  final numbers = CollectiveList<int>.of([1, 2, 3]);

  final open = Cell.open<Cell, Cell, Signal<int>, Signal<String>>(
    receptor: Receptor(
      transform: ({required cell, required signal, dynamic user}) {
        numbers.add(signal.body ?? 0);
        return Signal('Added ${signal.body}');
      },
    ),
  );
  ///
  open.receptor(Signal<int>(42));
  print(numbers); // [1, 2, 3, 42]

  // Combine OpenCell with CollectiveSet to update items reactively.
  set = CollectiveSet<int>.empty();
  final listener = Cell.listen<CollectivePost>(
    bind: set,
    listen: (post, _) => print('Change: ${post.body}')
  );
  set.add(1); // Triggers elementAdded signal


  // Create set with validation
  set = CollectiveSet<String>.empty(
      identitySet: true,
      test: TestCollective.create(
          elementDisallow: (element, _) => element?.length > 10
      )
  );
  
  // Invalid elements won't be added
  set.add('too-long-string'); // Fails validation
  set.add('ok'); // Succeeds


  // Async Operations
  final asyncSet = CollectiveSet<String>.empty().async;

  await asyncSet.add('hello');
  await asyncSet.addAll(['world', '!']);

  final removed = await asyncSet.remove('hello');
  print(removed); // true

}