// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_flow/flow.dart';

/// Flow instructions that dispatch a pulse down one of several paths
/// (Rx `iif` / `partition` / `groupBy`-style routing).
///
/// These operators route incoming pulses to different transformation paths
/// based on the payload content, type, or a key. They are essential for
/// implementing conditional logic, feature flags, and message routing in
/// reactive streams.
///
/// | Operator | Rx analogue | How the path is chosen |
/// |---|---|---|
/// | [Iif] | `iif` | boolean [predicate] |
/// | [RouteWhen] | first-match `switch` | first true predicate |
/// | [RouteByKey] | `groupBy` + map | [keyOf] → handler table |
/// | [PartitionTag] | `partition` | tag `{matched, value}` |
///
/// All of them emit on **one** downstream cell. They do not fork the
/// graph into two Cells; use two instructions + two handles for that.
///
/// Wire with `.toHandle(source:)` and inject via
/// [IngressHandle.emitAsync]. See `main` at the bottom of this file.

typedef RouteErrorHandler = void Function(Object error, StackTrace? stackTrace);

Pulse? _typedOrError<S>(
    Pulse pulse, {
      RouteErrorHandler? onError,
    }) {
  final payload = pulse.payload;
  if (payload is! S) {
    onError?.call(
      FormatException('Expected payload of type $S, got ${payload.runtimeType}'),
      StackTrace.current,
    );
    return null;
  }
  return pulse;
}

Pulse<T> _out<T>(T value, Pulse trigger, Cell? cell, String step) {
  return Pulse<T>(
    value,
    source: cell ?? trigger.source,
    type: trigger.type,
    priority: trigger.priority,
    step: step,
  );
}

/// A predicate + mapper pair used by [RouteWhen].
class RouteCase<S, T> {
  const RouteCase(this.when, this.then);

  final bool Function(S value) when;
  final T Function(S value) then;
}

// ─────────────────────────────────────────────────────────────
// Iif
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that chooses between two transformation paths
/// based on a predicate (Rx `iif`).
///
/// [Iif] acts as a **Conditional Router**. It evaluates a predicate on the
/// payload and routes the pulse to either the [thenMap] or [elseMap]
/// transformation path.
///
/// ### When to use
/// Use [Iif] when you need to branch based on a boolean condition:
///
/// - **Success vs Error**: Different handling for success and error payloads
/// - **Feature Flags**: Different transformations based on feature flags
/// - **Cheap vs Expensive**: Different processing for cheap vs expensive operations
/// - **Validation**: Different handling for valid vs invalid inputs
/// - **Type Checking**: Different handling based on payload type
/// - **State-Dependent Logic**: Different behavior based on application state
/// - **User Roles**: Different transformations for admin vs regular users
/// - **Environment**: Different behavior based on environment (dev vs prod)
///
/// ### Choosing Between Routing Patterns
/// - **Use [Iif]** for **Binary Routing**: When you have exactly two paths.
/// - **Use [RouteWhen]** for **Multi-Path Routing**: When you have multiple
///   conditional paths.
/// - **Use [RouteByKey]** for **Key-Based Routing**: When routing is based on
///   a key extracted from the payload.
/// - **Use [PartitionTag]** for **Tagging**: When you want to tag values
///   without forking the stream.
///
/// ### Comparison with Other Operators
/// | Operator | Number of Paths | Path Selection | Use Case |
/// |----------|-----------------|----------------|----------|
/// | **Iif** | 2 | Predicate | Binary branching |
/// | **RouteWhen** | Many | First match | Multi-path branching |
/// | **RouteByKey** | Many | Key lookup | Key-based routing |
/// | **PartitionTag** | 1 (tagged) | Predicate | Tagging without forking |
/// | **Filter** | 1 | Predicate | Filtering |
///
/// ### How it works
/// 1. Each incoming pulse's payload is extracted and type-checked.
/// 2. The [predicate] is evaluated on the payload.
/// 3. If the predicate returns `true`, the [thenMap] function is called.
/// 4. If the predicate returns `false`, the [elseMap] function is called.
/// 5. The result is emitted as a [Pulse].
/// 6. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Binary Branch**: Only two paths are available: then and else.
/// - **Type Safety**: The instruction is generic over [S] (input) and
///   [T] (output), ensuring compile-time type safety.
/// - **Error Handling**: Errors in the predicate or mappers are reported
///   via [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Synchronous Execution**: The instruction executes synchronously.
/// - **Memory Efficiency**: No state is maintained.
///
/// ### Example: Status Code Handling
/// ```dart
/// final status = Cell.ingress<int>();
/// val label = Iif<int, String>(
///   (code) => code < 400,
///   thenMap: (c) => 'ok-$c',
///   elseMap: (c) => 'err-$c',
/// ).toHandle(source: status.cell);
///
/// status.emit(200); // Emits 'ok-200'
/// status.emit(404); // Emits 'err-404'
/// ```
///
/// ### Example: Feature Flag
/// ```dart
/// final requests = Cell.ingress<Request>();
/// val processed = Iif<Request, Processed>(
///   (req) => featureFlags.isEnabled('v2'),
///   thenMap: (req) => processV2(req),
///   elseMap: (req) => processV1(req),
/// ).toHandle(source: requests.cell);
/// ```
///
/// ### Example: Validation
/// ```dart
/// final inputs = Cell.ingress<String>();
/// val validated = Iif<String, Result>(
///   (s) => s.isNotEmpty,
///   thenMap: (s) => Result.valid(s),
///   elseMap: (s) => Result.invalid('Empty input'),
/// ).toHandle(source: inputs.cell);
/// ```
///
/// ### Parameters:
/// - [predicate]: **The Condition.** Returns `true` for the [thenMap] path.
/// - [thenMap]: **The Then Transformation.** Called when [predicate] is true.
/// - [elseMap]: **The Else Transformation.** Called when [predicate] is false.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload after transformation.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [RouteWhen]: For multi-path routing.
/// - [RouteByKey]: For key-based routing.
/// - [PartitionTag]: For tagging without forking.
class Iif<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates an [Iif] instruction with the specified [predicate], [thenMap],
  /// and [elseMap].
  ///
  /// ### Parameters:
  /// - [predicate]: **The Condition.** Returns `true` for the [thenMap] path.
  /// - [thenMap]: **The Then Transformation.** Called when [predicate] is true.
  /// - [elseMap]: **The Else Transformation.** Called when [predicate] is false.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val iif = Iif<int, String>(
  ///   (n) => n > 0,
  ///   thenMap: (n) => 'positive-$n',
  ///   elseMap: (n) => 'negative-$n',
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  Iif(
      bool Function(S value) predicate, {
        required T Function(S value) thenMap,
        required T Function(S value) elseMap,
        RouteErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      final value = typed.payload as S;
      try {
        final matched = predicate(value);
        final mapped = matched ? thenMap(value) : elseMap(value);
        return _out<T>(
          mapped,
          typed,
          cell,
          matched ? 'Iif.then' : 'Iif.else',
        );
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// RouteWhen
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that routes to the first matching [RouteCase]
/// (multi-path conditional routing).
///
/// [RouteWhen] acts as a **Multi-Path Router**. It evaluates a list of
/// [RouteCase]s in order and routes the pulse to the first one whose
/// [when] predicate returns `true`. If none match and [orElse] is provided,
/// it routes to the [orElse] path.
///
/// ### When to use
/// Use [RouteWhen] when you need to route based on multiple conditions:
///
/// - **Multi-Level Conditions**: Different handling for different value ranges
/// - **Type-Based Routing**: Different handling based on payload type
/// - **State Machine**: Different handling based on state
/// - **Priority-Based Routing**: Different handling based on priority levels
/// - **Category-Based Routing**: Different handling based on category
/// - **Feature Flags**: Different handling based on multiple feature flags
/// - **User Roles**: Different handling based on user role (admin, editor, viewer)
/// - **Environment**: Different handling based on environment
///
/// ### How it works
/// 1. Each incoming pulse's payload is extracted and type-checked.
/// 2. The [cases] are evaluated in order.
/// 3. The first case whose [when] predicate returns `true` is selected.
/// 4. The [then] function of the selected case is called.
/// 5. If no case matches and [orElse] is provided, it is used as a fallback.
/// 6. If no case matches and [orElse] is not provided, the pulse is dropped.
/// 7. The result is emitted as a [Pulse].
/// 8. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **First Match Wins**: Cases are evaluated in order; the first match wins.
/// - **Fallback**: [orElse] is used when no case matches.
/// - **Drop on Miss**: If no case matches and no fallback, the pulse is dropped.
/// - **Error Handling**: Errors in predicates or mappers are reported via
///   [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Synchronous Execution**: The instruction executes synchronously.
///
/// ### Example: Range-Based Routing
/// ```dart
/// val sized = RouteWhen<int, String>([
///   RouteCase((n) => n < 10, (n) => 'small'),
///   RouteCase((n) => n < 100, (n) => 'mid'),
/// ], orElse: (_) => 'big')
/// .toHandle(source: nums.cell);
///
/// nums.emit(3);   // Emits 'small'
/// nums.emit(40);  // Emits 'mid'
/// nums.emit(400); // Emits 'big'
/// ```
///
/// ### Example: Type-Based Routing
/// ```dart
/// val routed = RouteWhen<Object, String>([
///   RouteCase((o) => o is int, (o) => 'int: $o'),
///   RouteCase((o) => o is String, (o) => 'string: $o'),
///   RouteCase((o) => o is bool, (o) => 'bool: $o'),
/// ], orElse: (o) => 'unknown: $o')
/// .toHandle(source: mixed.cell);
/// ```
///
/// ### Parameters:
/// - [cases]: **The Route Cases.** A list of [RouteCase] objects, evaluated
///   in order.
/// - [orElse]: **The Fallback.** Optional. Called when no case matches.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [T]: The type of the output payload after transformation.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [Iif]: For binary routing.
/// - [RouteByKey]: For key-based routing.
/// - [PartitionTag]: For tagging without forking.
class RouteWhen<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [RouteWhen] instruction with the specified [cases] and optional
  /// [orElse] fallback.
  ///
  /// ### Parameters:
  /// - [cases]: **The Route Cases.** A list of [RouteCase] objects, evaluated
  ///   in order.
  /// - [orElse]: **The Fallback.** Optional. Called when no case matches.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val routeWhen = RouteWhen<int, String>([
  ///   RouteCase((n) => n == 0, (n) => 'zero'),
  ///   RouteCase((n) => n > 0, (n) => 'positive'),
  /// ], orElse: (_) => 'negative')
  /// .toHandle(source: numbers.cell);
  /// ```
  RouteWhen(
      List<RouteCase<S, T>> cases, {
        T Function(S value)? orElse,
        RouteErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      final value = typed.payload as S;
      try {
        for (var i = 0; i < cases.length; i++) {
          if (cases[i].when(value)) {
            return _out<T>(
              cases[i].then(value),
              typed,
              cell,
              'RouteWhen.$i',
            );
          }
        }
        if (orElse == null) return null;
        return _out<T>(orElse(value), typed, cell, 'RouteWhen.else');
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// RouteByKey
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that routes based on a key extracted from the
/// payload (key-based routing).
///
/// [RouteByKey] acts as a **Key-Based Router**. It extracts a key from the
/// payload using [keyOf] and looks up the corresponding transformation in a
/// [routes] table. If the key is not found and [orElse] is provided, it uses
/// the fallback.
///
/// ### When to use
/// Use [RouteByKey] when routing should be based on a key:
///
/// - **HTTP Methods**: Routing based on GET, POST, PUT, DELETE
/// - **Event Types**: Routing based on event type strings
/// - **User Roles**: Routing based on role (admin, editor, viewer)
/// - **Message Types**: Routing based on message type
/// - **Action Types**: Routing based on action type
/// - **Status Codes**: Routing based on status code
/// - **Categories**: Routing based on category
/// - **Feature Flags**: Routing based on feature flag keys
///
/// ### How it works
/// 1. Each incoming pulse's payload is extracted and type-checked.
/// 2. The [keyOf] function is called to extract a key from the payload.
/// 3. The key is used to look up a route in the [routes] map.
/// 4. If the key is found, the corresponding transformation is called.
/// 5. If the key is not found and [orElse] is provided, it is used as a fallback.
/// 6. If the key is not found and [orElse] is not provided, the pulse is dropped.
/// 7. The result is emitted as a [Pulse].
/// 8. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Key-Based**: Routing is based on a key extracted from the payload.
/// - **Table Lookup**: The [routes] map is used to look up transformations.
/// - **Fallback**: [orElse] is used when the key is not found.
/// - **Drop on Miss**: If the key is not found and no fallback, the pulse is dropped.
/// - **Error Handling**: Errors in [keyOf] or mappers are reported via
///   [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Synchronous Execution**: The instruction executes synchronously.
///
/// ### Example: HTTP Method Routing
/// ```dart
/// final reqs = Cell.ingress<({String method, String path})>();
/// val routed = RouteByKey<({String method, String path}), String, String>(
///   (r) => r.method,
///   routes: {
///     'GET': (r) => 'GET ${r.path}',
///     'POST': (r) => 'POST ${r.path}',
///   },
/// ).toHandle(source: reqs.cell);
///
/// reqs.emit((method: 'GET', path: '/users')); // Emits 'GET /users'
/// reqs.emit((method: 'POST', path: '/users')); // Emits 'POST /users'
/// ```
///
/// ### Example: Event Type Routing
/// ```dart
/// final events = Cell.ingress<{String type, dynamic data}>();
/// val processed = RouteByKey<{String type, dynamic data}, String, Processed>(
///   (e) => e.type,
///   routes: {
///     'user_login': (e) => handleLogin(e.data),
///     'user_logout': (e) => handleLogout(e.data),
///     'user_update': (e) => handleUpdate(e.data),
///   },
/// ).toHandle(source: events.cell);
/// ```
///
/// ### Parameters:
/// - [keyOf]: **The Key Extractor.** Takes the payload and returns a key.
/// - [routes]: **The Route Table.** A map from keys to transformations.
/// - [orElse]: **The Fallback.** Optional. Called when the key is not found.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
/// - [K]: The type of the key used for routing.
/// - [T]: The type of the output payload after transformation.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [Iif]: For binary routing.
/// - [RouteWhen]: For multi-path routing.
/// - [PartitionTag]: For tagging without forking.
class RouteByKey<S, K, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [RouteByKey] instruction with the specified [keyOf], [routes],
  /// and optional [orElse] fallback.
  ///
  /// ### Parameters:
  /// - [keyOf]: **The Key Extractor.** Takes the payload and returns a key.
  /// - [routes]: **The Route Table.** A map from keys to transformations.
  /// - [orElse]: **The Fallback.** Optional. Called when the key is not found.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val routeByKey = RouteByKey<String, String, String>(
  ///   (s) => s,
  ///   routes: {
  ///     'admin': (s) => 'admin: $s',
  ///     'user': (s) => 'user: $s',
  ///   },
  /// ).toHandle(source: roles.cell);
  /// ```
  RouteByKey(
      K Function(S value) keyOf, {
        required Map<K, T Function(S value)> routes,
        T Function(S value)? orElse,
        RouteErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      final value = typed.payload as S;
      try {
        final key = keyOf(value);
        final route = routes[key];
        if (route != null) {
          return _out<T>(route(value), typed, cell, 'RouteByKey.$key');
        }
        if (orElse == null) return null;
        return _out<T>(orElse(value), typed, cell, 'RouteByKey.else');
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// PartitionTag
// ─────────────────────────────────────────────────────────────

/// A [Receptor] instruction that tags each value with whether it matched a
/// predicate (Rx `partition` without forking the graph).
///
/// [PartitionTag] acts as a **Tagging Router**. It evaluates a predicate on
/// the payload and tags the output with a `matched` boolean, but does not
/// fork the stream into two separate paths.
///
/// ### When to use
/// Use [PartitionTag] when:
/// - You want to tag values without forking the stream
/// - You want downstream to filter on the `matched` tag
/// - You're implementing a partition without creating two cells
/// - You want to keep both branches in a single stream
/// - You're implementing conditional logic with downstream filtering
///
/// ### How it works
/// 1. Each incoming pulse's payload is extracted and type-checked.
/// 2. The [predicate] is evaluated on the payload.
/// 3. The output is tagged with `(matched: bool, value: S)`.
/// 4. The tagged value is emitted as a [Pulse].
/// 5. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **Tagging Only**: The stream is not forked; the matched/unmatched
///   status is tagged on the value.
/// - **Downstream Filtering**: Downstream can use `Filter` to separate
///   matched and unmatched values.
/// - **Error Handling**: Errors in the predicate are reported via
///   [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Synchronous Execution**: The instruction executes synchronously.
/// - **Memory Efficiency**: No state is maintained.
///
/// ### Example: Partition Tagging
/// ```dart
/// final items = Cell.ingress<int>();
/// val tagged = PartitionTag<int>((n) => n.isEven)
///     .toHandle(source: items.cell);
///
/// items.emit(2); // Emits (matched: true, value: 2)
/// items.emit(3); // Emits (matched: false, value: 3)
///
/// // Downstream filtering
/// val evens = Filter<({bool matched, int value})>(
///   (tagged) => tagged.matched
/// ).toHandle(source: tagged.cell);
/// ```
///
/// ### Example: Validation Tagging
/// ```dart
/// final inputs = Cell.ingress<String>();
/// val tagged = PartitionTag<String>((s) => s.isNotEmpty)
///     .toHandle(source: inputs.cell);
///
/// // Downstream process valid and invalid separately
/// val valid = Filter<({bool matched, String value})>(
///   (tagged) => tagged.matched
/// ).toHandle(source: tagged.cell);
///
/// val invalid = Filter<({bool matched, String value})>(
///   (tagged) => !tagged.matched
/// ).toHandle(source: tagged.cell);
/// ```
///
/// ### Parameters:
/// - [predicate]: **The Condition.** Determines the `matched` tag.
/// - [onError]: **Error Handler.** Optional callback for handling errors.
/// - [user]: **User Metadata.** Optional metadata passed to the instruction.
///
/// ### Type Parameters:
/// - [S]: The type of the input payload from the source cell.
///
/// ### Returns:
/// A [FlowInstruction] that can be used in a [Receptor] pipeline.
///
/// ### See Also:
/// - [Iif]: For binary routing.
/// - [RouteWhen]: For multi-path routing.
/// - [RouteByKey]: For key-based routing.
class PartitionTag<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Creates a [PartitionTag] instruction with the specified [predicate].
  ///
  /// ### Parameters:
  /// - [predicate]: **The Condition.** Determines the `matched` tag.
  /// - [onError]: **Error Handler.** Optional callback for handling errors.
  /// - [user]: **User Metadata.** Optional metadata passed to the instruction.
  ///
  /// ### Example
  /// ```dart
  /// val partitionTag = PartitionTag<int>(
  ///   (n) => n.isEven,
  ///   onError: (error, stack) => print('Error: $error'),
  /// );
  /// ```
  PartitionTag(
      bool Function(S value) predicate, {
        RouteErrorHandler? onError,
        dynamic user,
      }) : super(
        (pulse, {cell, user}) {
      final typed = _typedOrError<S>(pulse, onError: onError);
      if (typed == null) return null;
      final value = typed.payload as S;
      try {
        final matched = predicate(value);
        return _out<({bool matched, S value})>(
          (matched: matched, value: value),
          typed,
          cell,
          matched ? 'PartitionTag.then' : 'PartitionTag.else',
        );
      } catch (e, stack) {
        onError?.call(e, stack);
        return null;
      }
    },
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────
// Demo
// ─────────────────────────────────────────────────────────────

/// A demonstration of the [Iif] instruction and related operators
/// showing their behavior in various routing scenarios.
///
/// ### Expected console output:
/// ```text
/// ── Routing Operators Demo ────────────────────────────────────
///
/// 1. Iif - status codes
///    [Iif] ok-200
///    [Iif] err-404
///
/// 2. RouteWhen - first match
///    [RouteWhen] small
///    [RouteWhen] mid
///    [RouteWhen] big
///
/// 3. RouteByKey - method table
///    [RouteByKey] GET /users
///    [RouteByKey] POST /users
///
/// 4. PartitionTag
///    [PartitionTag] (matched: true, value: 2)
///    [PartitionTag] (matched: false, value: 3)
///
/// ── finished ──────────────────────────────────────────────────
/// ```
///
/// ### How to run
/// ```dart
/// void main() => main();
/// ```
///
/// ### What it demonstrates
/// 1. **Iif - status codes**: Shows binary routing. A predicate determines
///    which transformation path to use.
///    `200` → `ok-200`, `404` → `err-404`.
///
/// 2. **RouteWhen - first match**: Shows multi-path routing. Cases are
///    evaluated in order; the first match wins.
///    `3` → `small`, `40` → `mid`, `400` → `big`.
///
/// 3. **RouteByKey - method table**: Shows key-based routing. A key is
///    extracted from the payload and used to look up a transformation.
///    `GET /users` → `GET /users`, `POST /users` → `POST /users`.
///
/// 4. **PartitionTag**: Shows tagging without forking. Each value is
///    tagged with whether it matched the predicate.
///    `2` → `(matched: true, value: 2)`, `3` → `(matched: false, value: 3)`.
///
/// ### Key Takeaways
/// - Iif provides simple binary routing with two paths.
/// - RouteWhen provides multi-path routing with first-match semantics.
/// - RouteByKey provides key-based routing with a table lookup.
/// - PartitionTag tags values without forking the stream.
/// - All routing operators are synchronous and stateless.
/// - All operators preserve causal provenance via EvolvedPulse.
Future<void> main() async {
  print('── Routing Operators Demo ────────────────────────────────────\n');

  print('1. Iif - status codes');
  final codes = Cell.ingress<int>();
  final labels = Iif<int, String>(
        (c) => c < 400,
    thenMap: (c) => 'ok-$c',
    elseMap: (c) => 'err-$c',
  ).toHandle(source: codes.cell);
  final iObs = Cell.observe(
    source: labels.cell,
    effect: (Pulse p) => print('   [Iif] ${p.payload}'),
  );
  await codes.emitAsync(200);
  await codes.emitAsync(404);
  iObs.stop();
  print('');

  print('2. RouteWhen - first match');
  final nums = Cell.ingress<int>();
  final sized = RouteWhen<int, String>([
    RouteCase((n) => n < 10, (n) => 'small'),
    RouteCase((n) => n < 100, (n) => 'mid'),
  ], orElse: (_) => 'big')
      .toHandle(source: nums.cell);
  final wObs = Cell.observe(
    source: sized.cell,
    effect: (Pulse p) => print('   [RouteWhen] ${p.payload}'),
  );
  await nums.emitAsync(3);
  await nums.emitAsync(40);
  await nums.emitAsync(400);
  wObs.stop();
  print('');

  print('3. RouteByKey - method table');
  final reqs = Cell.ingress<({String method, String path})>();
  final routed = RouteByKey<({String method, String path}), String, String>(
        (r) => r.method,
    routes: {
      'GET': (r) => 'GET ${r.path}',
      'POST': (r) => 'POST ${r.path}',
    },
  ).toHandle(source: reqs.cell);
  final rObs = Cell.observe(
    source: routed.cell,
    effect: (Pulse p) => print('   [RouteByKey] ${p.payload}'),
  );
  await reqs.emitAsync((method: 'GET', path: '/users'));
  await reqs.emitAsync((method: 'POST', path: '/users'));
  rObs.stop();
  print('');

  print('4. PartitionTag');
  final items = Cell.ingress<int>();
  final tagged = PartitionTag<int>((n) => n.isEven).toHandle(source: items.cell);
  final tObs = Cell.observe(
    source: tagged.cell,
    effect: (Pulse p) => print('   [PartitionTag] ${p.payload}'),
  );
  await items.emitAsync(2);
  await items.emitAsync(3);
  tObs.stop();
  print('');

  print('\n── finished ──────────────────────────────────────────────────');
}