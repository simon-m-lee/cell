// Copyright (c) 2025, authors: Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

/// `cell:core` is a reactive programming framework centered around the [Cell] class and its extensions,
/// particularly the [Collective] family of classes that implement reactive collections
/// [CollectiveSet], [CollectiveList], [CollectiveQueue] and [CollectiveValue].
/// This framework provides a comprehensive reactive programming solution for Dart, with
/// particular strength in managing complex state and data flow in applications.
///
/// ## Features
///
/// 1. **Reactive Programming Model**: Automatic propagation of changes through a network of cells
///
/// 2. **Validation System**: Configurable rules for what operations are allowed
///
/// 3. **Flexible Signal Processing**: Customizable signal transformation and propagation
///
/// 4. **Collection Support**: Reactive versions of common collection types
///
/// 5. **Modifiable/Unmodifiable Views**: Both mutable and immutable variants of all containers
///
/// 6. **Asynchronous Support**: Async interfaces for all operations
///
///
/// ## Core Components and Their Relationships
///
/// 1. [Cell] - The Fundamental Reactive Unit
///
///    `Purpose`: Acts as the basic building block of reactivity
///
///    `Key Relationships`:
///    - Contains Properties that define its behavior
///    - Uses Receptor for signal processing
///    - Manages Synapses for communication with other cells
///    - Can be wrapped by Deputy for delegation
///    - Uses TestObject/TestRule for validation
///
/// 2. [Receptor] - Signal Processing
///
///    `Purpose`: Handles signal transformation and propagation
///
///    Key Relationships:
///    - Attached to a Cell via Properties
///    - Processes incoming Signal objects
///    - Can trigger Synapses to propagate signals
///    - Has both synchronous (_Receptor) and asynchronous (ReceptorAsync) implementations
///
/// 3. [Synapses] - Inter-Cell Communication
///
///    `Purpose`: Manages connections between cells
///
///    `Key Relationships`:
///    - Maintained in Properties
///    - Used by Cell to propagate signals to linked cells
///    - Can be enabled or disabled
///    - Has implementations for sync (_Synapses) and no-op (_SynapsesNever) behavior
///
/// 4. [Properties] - Cell Configuration
///
///    `Purpose`: Contains all configurable aspects of a cell
///
///    `Key Relationships`:
///    - Owned by Cell
///    - Contains Receptor, Synapses, and TestObject
///    - Manages cell binding relationships
///    - Can be extended (e.g., CollectiveProperties for collections)
///
/// 5. [TestRule]/[TestObject] - Validation System
///
///    `Purpose`: Provides validation rules for cell operations
///
///    `Key Relationships`:
///    - Stored in Properties
///    - Used by Cell to validate signals and actions
///    - Can be combined using operator +
///    - Specialized versions exist (e.g., TestCollective for collections)
///
/// 6. [Signal] - Data Carrier
///
///    `Purpose`: Carries data between cells
///
///    `Key Relationships`:
///    - Processed by Receptor
///    - Propagated through Synapses
///    - Validated by TestObject
///    - Specialized versions exist (e.g., Post for collections)
///
/// 7. [Deputy] - Delegation Pattern
///
///    `Purpose`: Wraps cells to modify behavior
///
///    `Key Relationships`:
///    - Implements same interface as wrapped Cell
///    - Delegates to original cell while adding functionality
///    - Can modify TestObject behavior
///    - Used via deputy() factory method
///
/// ## Key Architectural Patterns
///
/// **Reactive Flow**:
/// - Signals enter through [Receptor]
/// - [TestObject] validates the signal
/// - If valid, processed by [Receptor].`transform`
/// - Output signal propagated via [Synapses]
///
/// **Decorator Pattern**:
/// - [Deputy] wraps cells to modify behavior
/// - [CellAsync] adds asynchronous capabilities
///
/// **Composite Pattern**:
/// - [TestObject] can contain multiple [TestRule] instances
/// - [Collective] types manage collections of cells
///
/// **Strategy Pattern**:
/// - Different [Receptor] implementations handle signal processing
/// - [Synapses] implementations vary propagation behavior
///
/// ## Detailed Component Interactions
///
/// **Signal Processing Flow**:
/// - A [Signal] arrives at a [Cell]
/// - The [Cell]'s [Properties].`receptor` processes it
/// - The [Receptor] checks with [TestObject] for [validation]
/// - If valid, applies transformation (if any)
/// - Resulting signal is sent through [Synapses] to linked cells
///
/// **Cell Initialization**:
/// - [Cell] created with or without [Properties]
/// - If no Properties, defaults are used:
///   - [Receptor.unchanged]
///   - [Synapses.enabled]
///   - [TestObject.passed]
/// - If binding to another cell, synapses are linked
///
/// **[Deputy] Functionality**:
/// - Wraps an existing Cell
/// - Can modify:
///   - Test behavior by combining with new [TestObject]
///   - Mapping behavior via MapObject
/// - Maintains reference to original cell
///
/// **Test System Operation**:
/// - [TestObject] contains one or more [TestRules]
/// - Rules can test:
///   - `Signals` ([TestSignalRule])
///   - `Actions` ([TestActionRule])
///   - `Links` ([TestLinkRule])
/// - Rules can be combined for complex validation
///
/// ## Disclaimer
/// It is an A.I. generated document. The content is based on the code
/// provided and may not accurately reflect the intended functionality or usage of the package.
/// Please review and modify as necessary to ensure accuracy and clarity.
///
/// {@category Core}
// ignore: unnecessary_library_name
library cell.core;

import 'dart:collection';
import 'dart:core';

part 'src/cell/cell.dart';
part 'src/cell/deputy.dart';
part 'src/cell/receptor.dart';
part 'src/cell/synapses.dart';
part 'src/cell/properties.dart';
part 'src/cell/map_object.dart';
part 'src/cell/utils.dart';
part 'src/cell/test_object.dart';
part 'src/cell/test_rule.dart';