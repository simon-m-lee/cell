// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flow/cell_flow.dart';

// ─────────────────────────────────────────────────────────────
// Core Routing Operators
// ─────────────────────────────────────────────────────────────

/// Error handler callback for routing operators.
///
/// Called when an error occurs during routing, such as errors in
/// predicates, mappers, or key extraction functions.
///
/// ### Example
/// ```dart
/// final errorHandler = RouteErrorHandler((error, stack) {
///   print('Route error: $error');
///   if (stack != null) print(stack);
/// });
/// ```
typedef RouteErrorHandler = void Function(Object error, StackTrace? stackTrace);

// ─────────────────────────────────────────────────────────────
// Helper Functions and Types
// ─────────────────────────────────────────────────────────────

/// Helper for type-safe payload extraction.
///
/// [_typedOrError] checks that the pulse payload matches the expected
/// type [S]. If it does, returns the pulse. If not, calls [onError]
/// and returns `null`.
///
/// ### Parameters:
/// - [pulse]: The incoming pulse to check.
/// - [onError]: Optional error handler for type mismatches.
///
/// ### Returns:
/// The pulse if the payload type matches, otherwise `null`.
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

/// Helper to create an output pulse with proper provenance.
///
/// Creates a new [Pulse] with the given [value], preserving the source,
/// type, and priority from the trigger pulse.
///
/// ### Parameters:
/// - [value]: The payload value for the new pulse.
/// - [trigger]: The source pulse providing provenance metadata.
/// - [cell]: Optional cell to use as the source.
/// - [step]: The trace step to add for provenance.
///
/// ### Returns:
/// A new [Pulse] with preserved provenance.
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
///
/// [RouteCase] defines a single route case with a condition ([when]) and
/// a transformation ([then]). It's used with [RouteWhen] for multi-path
/// routing.
///
/// ### When to use
/// Use [RouteCase] when defining cases for [RouteWhen] routing.
///
/// ### How it works
/// 1. [when] is a predicate that tests the payload.
/// 2. [then] is a transformation applied when [when] returns true.
/// 3. Cases are evaluated in order.
///
/// ### Example
/// ```dart
/// final cases = [
///   RouteCase((n) => n < 10, (n) => 'small'),
///   RouteCase((n) => n < 100, (n) => 'mid'),
/// ];
/// ```
///
/// ### Type Parameters:
/// - [S]: The type of the input payload.
/// - [T]: The type of the output payload.
///
/// ### See Also:
/// - [RouteWhen]: The operator that uses RouteCase.
class RouteCase<S, T> {
  /// Creates a [RouteCase] with the given [when] predicate and [then] mapper.
  ///
  /// ### Parameters:
  /// - [when]: The condition predicate.
  /// - [then]: The transformation to apply when the condition is true.
  const RouteCase(this.when, this.then);

  /// The condition predicate.
  ///
  /// Returns `true` if this route case matches the payload.
  final bool Function(S value) when;

  /// The transformation function.
  ///
  /// Applied when [when] returns `true`.
  final T Function(S value) then;
}

// ─────────────────────────────────────────────────────────────
// Iif - Binary Router
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that chooses between two transformation paths
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
/// 6. Success emissions get the step `'Iif.then'`; failures get `'Iif.else'`.
/// 7. The instruction preserves causal provenance.
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
/// - **Step Differentiation**: Different steps distinguish then from else.
///
/// ### Example: Status Code Handling
/// ```dart
/// final status = Cell.ingress<int>();
/// final label = Iif<int, String>(
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
/// final processed = Iif<Request, Processed>(
///   (req) => featureFlags.isEnabled('v2'),
///   thenMap: (req) => processV2(req),
///   elseMap: (req) => processV1(req),
/// ).toHandle(source: requests.cell);
/// ```
///
/// ### Example: Validation
/// ```dart
/// final inputs = Cell.ingress<String>();
/// final validated = Iif<String, Result>(
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
/// A [FlowInstruction] that routes based on a boolean condition.
///
/// ### See Also:
/// - [RouteWhen]: For multi-path routing.
/// - [RouteByKey]: For key-based routing.
/// - [PartitionTag]: For tagging without forking.
class Iif<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Binary Router**—a specialized instruction that
  /// chooses between two transformation paths based on a predicate.
  ///
  /// [Iif] acts as a **Conditional Router**. It evaluates a predicate on the
  /// payload and routes the pulse to either the [thenMap] or [elseMap]
  /// transformation path.
  ///
  /// ### How it works
  /// 1. **Type Check**: The pulse payload is validated against type [S].
  /// 2. **Predicate Evaluation**: The [predicate] is called with the payload.
  /// 3. **Path Selection**: If [predicate] returns `true`, [thenMap] is used;
  ///    otherwise [elseMap] is used.
  /// 4. **Emission**: The result is emitted with the step `'Iif.then'` or
  ///    `'Iif.else'`.
  /// 5. **Error Handling**: If any function throws, [onError] is called
  ///    and the pulse is dropped.
  ///
  /// ### Parameters
  /// - [predicate]: **The Condition.** Returns `true` for the then path.
  /// - [thenMap]: **The Then Transformation.** Applied when true.
  /// - [elseMap]: **The Else Transformation.** Applied when false.
  /// - [onError]: **Integrity Handler.** Called on errors.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: Status Code Router
  /// ```dart
  /// // Routes based on status code
  /// val statusRouter = Iif<int, String>(
  ///   (c) => c < 400,
  ///   thenMap: (c) => 'ok-$c',
  ///   elseMap: (c) => 'err-$c',
  ///   user: 'Status-Router'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [RouteWhen]: For multi-path routing.
  /// - [RouteByKey]: For key-based routing.
  /// - [PartitionTag]: For tagging without forking.
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
// RouteWhen - Multi-Path Router
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that routes to the first matching [RouteCase]
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
/// 8. Success emissions get the step `'RouteWhen.N'` where N is the index.
/// 9. Fallback emissions get the step `'RouteWhen.else'`.
/// 10. The instruction preserves causal provenance.
///
/// ### Non‑obvious
/// - **First Match Wins**: Cases are evaluated in order; the first match wins.
/// - **Fallback**: [orElse] is used when no case matches.
/// - **Drop on Miss**: If no case matches and no fallback, the pulse is dropped.
/// - **Error Handling**: Errors in predicates or mappers are reported via
///   [onError].
/// - **Causal Provenance**: Every emitted result preserves forensic history.
/// - **Synchronous Execution**: The instruction executes synchronously.
/// - **Memory Efficiency**: No state is maintained.
///
/// ### Example: Range-Based Routing
/// ```dart
/// final nums = Cell.ingress<int>();
/// final sized = RouteWhen<int, String>([
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
/// final mixed = Cell.ingress<Object>();
/// final routed = RouteWhen<Object, String>([
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
/// A [FlowInstruction] that routes based on multiple conditions.
///
/// ### See Also:
/// - [Iif]: For binary routing.
/// - [RouteByKey]: For key-based routing.
/// - [PartitionTag]: For tagging without forking.
class RouteWhen<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Multi-Path Router**—a specialized instruction that
  /// routes to the first matching case.
  ///
  /// [RouteWhen] evaluates a list of [RouteCase]s in order and routes the
  /// pulse to the first one whose predicate returns `true`.
  ///
  /// ### How it works
  /// 1. **Type Check**: The pulse payload is validated against type [S].
  /// 2. **Case Evaluation**: Each [RouteCase] is evaluated in order.
  /// 3. **First Match**: The first case whose [when] returns `true` wins.
  /// 4. **Transformation**: The [then] function of the matched case is applied.
  /// 5. **Fallback**: If no case matches, [orElse] is used if provided.
  /// 6. **Drop on Miss**: If no case matches and no fallback, the pulse is dropped.
  /// 7. **Emission**: The result is emitted with the step `'RouteWhen.N'`.
  /// 8. **Error Handling**: If any function throws, [onError] is called.
  ///
  /// ### Parameters
  /// - [cases]: **The Route Cases.** Evaluated in order.
  /// - [orElse]: **The Fallback.** Used when no case matches.
  /// - [onError]: **Integrity Handler.** Called on errors.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: Range-Based Router
  /// ```dart
  /// // Routes based on numeric ranges
  /// val rangeRouter = RouteWhen<int, String>([
  ///   RouteCase((n) => n < 10, (n) => 'small'),
  ///   RouteCase((n) => n < 100, (n) => 'mid'),
  /// ], orElse: (_) => 'big', user: 'Range-Router');
  /// ```
  ///
  /// ### See Also
  /// - [Iif]: For binary routing.
  /// - [RouteByKey]: For key-based routing.
  /// - [PartitionTag]: For tagging without forking.
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
// RouteByKey - Key-Based Router
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that routes based on a key extracted from the
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
/// 8. Success emissions get the step `'RouteByKey.$key'`.
/// 9. Fallback emissions get the step `'RouteByKey.else'`.
/// 10. The instruction preserves causal provenance.
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
/// final routed = RouteByKey<({String method, String path}), String, String>(
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
/// A [FlowInstruction] that routes based on a key.
///
/// ### See Also:
/// - [Iif]: For binary routing.
/// - [RouteWhen]: For multi-path routing.
/// - [PartitionTag]: For tagging without forking.
class RouteByKey<S, K, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Key-Based Router**—a specialized instruction that
  /// routes based on a key extracted from the payload.
  ///
  /// [RouteByKey] extracts a key from the payload using [keyOf] and looks
  /// up the corresponding transformation in a [routes] table.
  ///
  /// ### How it works
  /// 1. **Type Check**: The pulse payload is validated against type [S].
  /// 2. **Key Extraction**: [keyOf] is called to extract a key from the payload.
  /// 3. **Route Lookup**: The key is used to look up a transformation in [routes].
  /// 4. **Transformation**: If found, the transformation is applied.
  /// 5. **Fallback**: If not found, [orElse] is used if provided.
  /// 6. **Drop on Miss**: If not found and no fallback, the pulse is dropped.
  /// 7. **Emission**: The result is emitted with the step `'RouteByKey.$key'`.
  /// 8. **Error Handling**: If any function throws, [onError] is called.
  ///
  /// ### Parameters
  /// - [keyOf]: **The Key Extractor.** Extracts the routing key.
  /// - [routes]: **The Route Table.** Maps keys to transformations.
  /// - [orElse]: **The Fallback.** Used when the key is not found.
  /// - [onError]: **Integrity Handler.** Called on errors.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: HTTP Method Router
  /// ```dart
  /// // Routes based on HTTP method
  /// val methodRouter = RouteByKey<Request, String, Response>(
  ///   (req) => req.method,
  ///   routes: {
  ///     'GET': (req) => handleGet(req),
  ///     'POST': (req) => handlePost(req),
  ///     'PUT': (req) => handlePut(req),
  ///   },
  ///   user: 'Method-Router'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [Iif]: For binary routing.
  /// - [RouteWhen]: For multi-path routing.
  /// - [PartitionTag]: For tagging without forking.
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
// PartitionTag - Tagging Router
// ─────────────────────────────────────────────────────────────

/// A [FlowInstruction] that tags each value with whether it matched a
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
/// - You want to preserve the original value with its classification
///
/// ### Comparison with Other Operators
/// | Operator | Output | Forks | Use Case |
/// |----------|--------|-------|----------|
/// | **PartitionTag** | `(matched, value)` | No | Tagging |
/// | **Partition** | `Split` | No | Tagging (same) |
/// | **Filter** | `value` | No | Filtering |
/// | **Iif** | `T` | No | Binary routing |
///
/// ### How it works
/// 1. Each incoming pulse's payload is extracted and type-checked.
/// 2. The [predicate] is evaluated on the payload.
/// 3. The output is tagged with `(matched: bool, value: S)`.
/// 4. Success emissions get the step `'PartitionTag.then'`; failures get
///    `'PartitionTag.else'`.
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
/// - **Record Payload**: The output is a record with `matched` and `value`.
///
/// ### Example: Partition Tagging
/// ```dart
/// final items = Cell.ingress<int>();
/// final tagged = PartitionTag<int>((n) => n.isEven)
///     .toHandle(source: items.cell);
///
/// items.emit(2); // Emits (matched: true, value: 2)
/// items.emit(3); // Emits (matched: false, value: 3)
///
/// // Downstream filtering
/// final evens = Filter<({bool matched, int value})>(
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
/// ### Example: Classification Tagging
/// ```dart
/// final data = Cell.ingress<Data>();
/// val classified = PartitionTag<Data>((d) => d.isImportant)
///     .toHandle(source: data.cell);
///
/// // Downstream processing with classification context
/// val processed = Map<({bool matched, Data value}), Processed>(
///   (tagged) => Processed(
///     data: tagged.value,
///     isImportant: tagged.matched,
///   )
/// ).toHandle(source: classified.cell);
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
/// A [FlowInstruction] that tags values with a `matched` boolean.
///
/// ### See Also:
/// - [Iif]: For binary routing.
/// - [RouteWhen]: For multi-path routing.
/// - [RouteByKey]: For key-based routing.
/// - [Partition]: The partition operator in the partition file.
class PartitionTag<S> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  /// Synthesizes a **Tagging Router**—a specialized instruction that
  /// tags each value with whether it matched a predicate.
  ///
  /// [PartitionTag] evaluates a predicate on the payload and tags the
  /// output with a `matched` boolean, but does not fork the stream into
  /// two separate paths.
  ///
  /// ### How it works
  /// 1. **Type Check**: The pulse payload is validated against type [S].
  /// 2. **Predicate Evaluation**: [predicate] is called with the payload.
  /// 3. **Tagging**: The output is tagged with `(matched: bool, value: S)`.
  /// 4. **Emission**: The tagged value is emitted with the step
  ///    `'PartitionTag.then'` or `'PartitionTag.else'`.
  /// 5. **Error Handling**: If [predicate] throws, [onError] is called
  ///    and the pulse is dropped.
  ///
  /// ### Parameters
  /// - [predicate]: **The Condition.** Determines the `matched` tag.
  /// - [onError]: **Integrity Handler.** Called on errors.
  /// - [user]: **Flyweight Metadata.** Optional configuration data.
  ///
  /// ### Example: Classification Tagger
  /// ```dart
  /// // Tags values as important or not
  /// val classifier = PartitionTag<Data>(
  ///   (d) => d.isImportant,
  ///   user: 'Classifier'
  /// );
  /// ```
  ///
  /// ### See Also
  /// - [Iif]: For binary routing.
  /// - [RouteWhen]: For multi-path routing.
  /// - [RouteByKey]: For key-based routing.
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

/// A demonstration of the routing instructions showing their behavior
/// in various routing scenarios.
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
/// - Choose the right operator for your use case:
///   - Two paths → Iif
///   - Multiple conditions → RouteWhen
///   - Key-based → RouteByKey
///   - Tagging → PartitionTag
///
/// ### Note on Performance
/// All routing operators are O(1) per pulse with minimal overhead.
/// RouteWhen and RouteByKey have O(n) lookup where n is the number of
/// cases or routes.
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