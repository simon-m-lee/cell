// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

/// `cell:collective` library is a powerful Dart framework for building reactive
/// data structures and event-driven systems. It provides a set of abstract and
/// concrete classes that enable developers to create observable collections,
/// manage state changes, and propagate signals throughout an application.
///
///
/// This library is designed to work seamlessly with the `cell:core` library,
/// which provides the fundamental building blocks for reactive programming in Dart.
/// The `cell:collective` library extends the core functionality by introducing
/// reactive collections such as `CollectiveSet`, `CollectiveList`,
/// `CollectiveQueue`, and `CollectiveValue`.
///
/// These collections are designed to be used in conjunction with the `Cell` class
/// from the `cell:core` library, which provides a reactive programming model
/// that allows developers to create and manage reactive data structures.
///
/// ## Features
///
/// 1. **Reactive Collections**: The library provides a set of reactive collections
///   that can be used to manage state changes and propagate signals throughout an
///   application.
///
/// 2. **Event-Driven Architecture**: The library supports an event-driven architecture
///  that allows developers to create and manage events and signals.
///
/// 3. **Signal Propagation**: The library provides a set of classes and methods
///  that allow developers to propagate signals throughout an application.
///
/// 4. **Validation System**: The library provides a validation system that allows
///  developers to define rules for what operations are allowed on a collection.
///
/// 5. **Flexible Signal Processing**: The library provides a set of classes and
///  methods that allow developers to process signals in a flexible and customizable
///  manner.
///
/// 6. **Collection Support**: The library provides a set of classes and methods
///  that allow developers to create and manage collections.
///
/// 7. **Modifiable/Unmodifiable Views**: The library provides both modifiable and
///  unmodifiable views of collections, allowing developers to choose the appropriate
///  level of mutability for their use case.
///
/// 8. **Asynchronous Support**: The library provides asynchronous interfaces for
///  all operations, allowing developers to work with asynchronous data sources.
///
/// 9. **Testable**: The library provides a set of classes and methods that allow
///  developers to create and manage testable collections.
///
/// 10. **Type Safety**: The library provides a set of classes and methods that
///  allow developers to create and manage type-safe collections.
///
/// 11. **Performance**: The library is designed to be performant and efficient,
///  allowing developers to create and manage collections with minimal overhead.
///
/// 12. **Documentation**: The library is well-documented, providing developers with
///  clear and concise information on how to use the library.
///
/// ## Example Usage
///
/// ```dart
/// import 'package:cell/collective.dart';
///
/// void main() {
///  // Create a new CollectiveList
///  final list = CollectiveList<int>();
///
/// // Add elements to the list
///  list.add(1);
///  list.add(2);
///  list.add(3);
///
/// // Listen for changes to the list
///  Cell.listen<CollectivePost>(
///    bind: list,
///    listen: (post, _) {
///    print('List changed: ${post.body}');
///    }
///  );
///
/// // Remove an element from the list
/// list.remove(2); // Output: ElementRemoved: 2
/// }
///
/// // Create a immutable version of the list
/// final unmodifiable = list.unmodifiable;
///
/// unmodifiable.add(4); // Throws UnsupportedError
///
/// // Create an async version of the list
/// final asyncList = list.async;
///
/// await asyncList.add(5); // Async operation
/// ```
/// ## Performance Considerations
///
/// - Use unmodifiable views when mutation isn't needed
///
/// - Consider identitySet for large collections of objects
///
/// - Be mindful of signal propagation in deep cell hierarchies
///
/// - Use asynchronous operations for expensive mutations
///
/// ## Disclaimer
/// It is an A.I. generated document. The content is based on the code
/// provided and may not accurately reflect the intended functionality or usage of the package.
/// Please review and modify as necessary to ensure accuracy and clarity.
///
///
/// {@category Core}
// ignore: unnecessary_library_name
library cell.collection;

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:cell/cell.dart';
export 'package:cell/cell.dart';

import 'package:random_string/random_string.dart';

part 'src/collective/collective.dart';
part 'src/collective/collective_properties.dart';
part 'src/collective/collective_core.dart';
part 'src/collective/collective_set.dart';
part 'src/collective/collective_list.dart';
part 'src/collective/collective_queue.dart';
part 'src/collective/collective_value.dart';
part 'src/collective/collective_test.dart';
part 'src/collective/collective_receptor.dart';