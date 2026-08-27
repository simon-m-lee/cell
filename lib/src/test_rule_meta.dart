// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'test_rule.dart';

/// [DefaultValue] is a metadata annotation primarily used by the code generation
/// framework (such as `build_model`) to define a fallback or initial value for
/// fields in a model class.
///
/// This annotation acts as a declarative instruction for the code generator,
/// allowing it to automatically initialize properties in the generated
/// implementation classes. This ensures that models always start in a
/// well-defined state, even when created without explicit values for certain fields.
///
/// ### When to use
/// Use this on a field when you want a default value to be used if the field
/// is not explicitly provided during construction. Common for optional fields.
///
/// ### How it works
/// The code generator reads this annotation and inserts the specified value
/// into the constructor and/or field initializer of the generated class.
/// The value must be a compile-time constant.
///
/// ### Non‑obvious
/// - The annotation itself does not enforce validation; it's purely for
///   code generation. The generated code handles the initialization.
/// - The value must be a constant expression; otherwise, the generator will
///   throw an error.
/// - The type of [value] must match the annotated field's type, otherwise
///   you'll get a compile‑time error in the generated code.
///
/// ### Examples
///
/// #### Primitives and Strings
/// ```dart
/// @DefaultValue(42)
/// final int id;
///
/// @DefaultValue('Unnamed')
/// final String name;
///
/// @DefaultValue(true)
/// final bool isEnabled;
/// ```
///
/// #### Enumerations
/// ```dart
/// @DefaultValue(UserRole.guest)
/// final UserRole role;
/// ```
///
/// #### Collections (Constants)
/// ```dart
/// @DefaultValue(['standard'])
/// final List<String> permissions;
///
/// @DefaultValue({'theme': 'light'})
/// final Map<String, dynamic> config;
/// ```
///
/// ### Parameters
/// - [value]: The literal value to be used as the default. Must be a
///   compile-time constant.
class DefaultValue {
  /// The literal value to be used as the default.
  ///
  /// This property holds the value provided to the annotation. During
  /// code generation, the string representation of this value is parsed
  /// and placed into the constructor or initializer of the generated class.
  final dynamic value;

  /// Creates a [DefaultValue] metadata annotation.
  ///
  /// The [value] must be a constant expression.
  ///
  /// Example:
  /// ```dart
  /// @DefaultValue(100)
  /// final int score;
  /// ```
  const DefaultValue(this.value);
}

/// [MaxLength] is a specialized [TestRule] metadata annotation used primarily by
/// the code generation framework (such as `build_model`) to enforce structural
/// and data-integrity constraints on model fields.
///
/// It provides a declarative way to specify length limits for strings and
/// collections, allowing the code generator to automatically inject validation
/// logic, database schema constraints, or UI form-field limits based on these
/// annotations.
///
/// ### When to use
/// Use this on `String` or `Iterable` fields to restrict their length.
/// Common examples: usernames, descriptions, tags, or any list that must have
/// a maximum number of elements.
///
/// ### How it works
/// The code generator creates validation code that checks the length of the
/// field (or its host container) against the specified limits. The validation
/// runs at runtime when setting the field.
///
/// ### Non‑obvious
/// - The rule supports **host‑aware validation** via the optional [hostLength]
///   parameter. This allows you to restrict the length of a container (like a
///   list) from an annotation on its elements.
/// - For `String` fields, it checks `object.length`. For `Iterable` fields,
///   it checks `object.length` (element count).
/// - The `.host()` constructor disables direct length checking and only
///   validates the host container – useful for annotations on child elements.
/// - Non‑string/iterable objects pass validation (the rule does not apply).
///
/// ### Examples
///
/// #### 1. Direct Field Limit
/// ```dart
/// @MaxLength(50)
/// final String username; // Username cannot exceed 50 characters.
///
/// @MaxLength(10)
/// final List<String> tags; // The list itself cannot have more than 10 tags.
/// ```
///
/// #### 2. Composite Validation (Field + Container)
/// ```dart
/// @MaxLength(20, hostLength: 5)
/// final List<String> categories;
/// // Each category string <= 20 chars AND the List itself <= 5 items.
/// ```
///
/// #### 3. Host-Only Limit (using `.host()`)
/// ```dart
/// @MaxLength.host(100)
/// final String comment;
/// // Does not limit the comment length, but signals to the generator that
/// // the principal container (e.g., a MessageList) should not exceed 100 items.
/// ```
///
/// ### Parameters
/// - [length]: The maximum allowed length for the annotated object.
///   Applied to [String.length] or [Iterable.length].
/// - [hostLength]: Optional. Enforces a limit on the length of the principal
///   container ([host]) during validation cycles.
class MaxLength extends TestRule<Never> {
  /// The maximum allowed length for the validated [object].
  ///
  /// Applied to [String.length] or [Iterable.length].
  final int length;

  /// Optional maximum length for the [host] container.
  ///
  /// If provided and [host] is an [Iterable], enforces `host.length <= hostLength`.
  final int? hostLength;

  /// Internal sentinel value representing "no limit" for direct object.
  ///
  /// Used by the `.host()` constructor to disable direct length checks.
  static const int _maxInt = 9007199254740991; // 2^53 - 1

  /// Creates a [MaxLength] rule that limits the **input object**.
  ///
  /// Use when annotating a field to restrict its own length:
  ///
  /// ```dart
  /// @MaxLength(30)
  /// String username;
  /// ```
  ///
  /// Optionally provide [hostLength] to also constrain the principal container:
  ///
  /// ```dart
  /// @MaxLength(10, hostLength: 5)
  /// List<String> usernames; // username.length <= 10, and usernames.length <= 5
  /// ```
  const MaxLength(this.length, {this.hostLength}) : super.base();

  /// Creates a [MaxLength] rule that **only validates the host container**.
  ///
  /// The input [object] is ignored — only the [host]'s length is checked.
  ///
  /// Useful for annotations on child elements to enforce collection limits:
  ///
  /// ```dart
  /// class Item {
  ///   @MaxLength.host(20)
  ///   final String name;
  /// }
  ///
  /// List<Item> items = [...];
  /// // Each item validates: items.length <= 20
  /// ```
  const MaxLength.host(int length) : hostLength = length, length = _maxInt, super.base();

  /// Executes length validation on [object] and optionally [host].
  ///
  /// Validation flow:
  /// 1. **Host check** (if [hostLength] is set):
  ///    - If [host] is [Iterable] and `host.length > hostLength` → `false`
  /// 2. **Object check** (if [length] is not `_maxInt`):
  ///    - If [object] is [String] → `object.length <= length`
  ///    - If [object] is [Iterable] → `object.length <= length`
  /// 3. Non-string/iterable objects → `true` (rule does not apply)
  ///
  /// Returns `true` only if all applicable checks pass.
  ///
  /// The [arguments] parameter is ignored.
  @override
  FutureOr<bool> call(object, {dynamic host, arguments}) {
    bool result = true;

    // Host length constraint
    if (hostLength != null && host is Iterable) {
      if (host.length > hostLength!) {
        result = false;
      }
    }

    // Direct object length constraint
    else if (object is Iterable) {
      result = object.length <= length;
    }

    else if (object is String) {
      result = object.length <= length;
    }

    // If the object is not a String or Iterable, the rule does not apply.
    else {
      result = true;
    }

    return result;
  }
}

/// [ValueRange] is a specialized [TestRule] metadata annotation designed to
/// validate whether a numeric input falls within a specific inclusive boundary.
///
/// It provides a declarative mechanism for **Numeric Domain Constraint**,
/// allowing the `cell.core` framework and auxiliary tools (like `build_model`)
/// to enforce business invariants directly at the field level.
///
/// ### When to use
/// Use this on numeric fields (e.g., `int`, `double`) to restrict their
/// values to a specific inclusive range. Common examples: age (1-120),
/// percentage (0.0-1.0), temperature, coordinates.
///
/// ### How it works
/// The generated validation code checks that the value is within `min` and
/// `max` inclusive. Non‑numeric values (like `null` or strings) pass
/// validation to allow flexible annotation usage on optional fields.
///
/// ### Non‑obvious
/// - The range is inclusive: `min <= value <= max`.
/// - `null` and non‑numeric values are allowed (return `true`). This is
///   intentional – use `@DefaultValue` to provide a default if needed.
/// - If the field is nullable and you want to disallow `null`, you can
///   combine with a separate `TestRule` or handle it in code.
///
/// ### Examples
///
/// #### 1. Percentage / Ratio Constraints
/// ```dart
/// @ValueRange(min: 0.0, max: 1.0)
/// final double opacity;
/// ```
///
/// #### 2. Physical / Logical Limits
/// ```dart
/// @ValueRange(min: 1, max: 120)
/// final int age; // Human age logic constraint
///
/// @ValueRange(min: -180, max: 180)
/// final double longitude;
/// ```
///
/// ### Parameters
/// - [min]: The inclusive lower bound. Any value `< min` will fail validation.
/// - [max]: The inclusive upper bound. Any value `> max` will fail validation.
///
/// > **Validation Logic**:
/// > - If the object is a [num], it checks `min <= value <= max`.
/// > - Non-numeric objects are considered "Pass" (true) by default,
/// >   allowing the annotation to be used flexibly on optional or dynamic fields.
class ValueRange extends TestRule<Never> {
  /// The inclusive lower bound of the valid range.
  ///
  /// The input value must be `>= min`.
  final num min;

  /// The inclusive upper bound of the valid range.
  ///
  /// The input value must be `<= max`.
  final num max;

  /// Creates a new [ValueRange] rule for numeric range validation.
  ///
  /// Use as a metadata annotation on numeric fields:
  ///
  /// ```dart
  /// @ValueRange(min: -10, max: 10)
  /// double temperature;
  /// ```
  ///
  /// - [min]: Required minimum value (inclusive).
  /// - [max]: Required maximum value (inclusive).
  ///
  /// > Ensure `min <= max`, otherwise validation will always fail for numbers.
  const ValueRange({required this.min, required this.max}) : super.base();

  /// Executes validation by checking if [object] is a [num] within [min]..[max].
  ///
  /// - If [object] is a [num]: returns `true` if `min <= object <= max`.
  /// - If [object] is `null` or non-numeric: returns `true` (non-numeric types
  ///   are accepted to allow flexible annotation usage).
  ///
  /// The [host] and [arguments] parameters are ignored due to `Never` context.
  @override
  FutureOr<bool> call(object, {covariant Never? host, arguments}) {
    return object is num ? object >= min && object <= max : true;
  }
}

/// [EntryPattern] is a specialized [TestRule] metadata annotation that validates
/// whether a string input matches a specific Regular Expression ([RegExp]).
///
/// It provides a declarative mechanism for **Format Enforcement**, allowing the
/// `cell.core` framework and code generation tools (like `build_model`) to
/// ensure that data—such as emails, phone numbers, or custom IDs—adheres to
/// strict structural requirements before being accepted into the reactive graph.
///
/// ### When to use
/// Use this on `String` fields to enforce a specific format – e.g., email,
/// phone number, postal code, or custom ID patterns.
///
/// ### How it works
/// The generated validation code matches the field's value against the [pattern]
/// using Dart's [RegExp]. You can control case sensitivity, allow empty strings,
/// and allow null values.
///
/// ### Non‑obvious
/// - `null` values are validated based on [allowNull] – if `false`, they fail.
/// - Empty strings are validated based on [allowEmpty] – if `false`, they fail.
/// - Non‑string objects always pass (useful for optional or dynamic fields).
/// - The pattern must be a valid Dart regex string.
///
/// ### Examples
///
/// #### 1. Standard Format Validation
/// ```dart
/// @EntryPattern(pattern: r'^\d{3}-\d{2}-\d{4}$')
/// final String ssn;
/// ```
///
/// #### 2. Configuration Options (Case Sensitivity & Nullability)
/// ```dart
/// @EntryPattern(
///   pattern: r'^[a-z]+$',
///   caseSensitive: false,
///   allowNull: true
/// )
/// final String? username;
/// ```
///
/// ### Parameters
/// - [pattern]: The raw [RegExp] string used for matching.
/// - [caseSensitive]: If `false` (default), the regex engine ignores casing.
/// - [allowEmpty]: If `true`, an empty string (`''`) bypasses the regex check
///   and returns `true`.
/// - [allowNull]: If `true`, a `null` value returns `true`.
///
/// > **Validation Logic**:
/// > - If the object is `null`, returns [allowNull].
/// > - If the object is an empty [String], returns [allowEmpty].
/// > - If the object is a non-empty [String], returns `true` if it matches
/// >   the [pattern].
/// > - Non-string objects are considered "Pass" (true) by default.
class EntryPattern extends TestRule<Never> {
  /// The regular expression pattern used to validate the input string.
  ///
  /// Must be a valid Dart [RegExp] pattern string.
  final String pattern;

  /// Whether the pattern matching should be case-sensitive.
  ///
  /// Defaults to `false` (case-insensitive).
  final bool caseSensitive;

  /// If `true`, empty strings (`''`) are considered valid.
  ///
  /// Defaults to `false`.
  final bool allowEmpty;

  /// If `true`, `null` values are considered valid.
  ///
  /// Defaults to `false`.
  final bool allowNull;

  /// Creates a new [EntryPattern] rule for annotation-based validation.
  ///
  /// Use this via metadata annotation on fields:
  ///
  /// ```dart
  /// @EntryPattern(pattern: r'^\d{4}-\d{2}-\d{2}$')
  /// DateString birthday;
  /// ```
  const EntryPattern({
    required this.pattern,
    this.caseSensitive = false,
    this.allowEmpty = false,
    this.allowNull = false,
  }) : super.base();

  /// Executes the validation against the provided [object].
  ///
  /// - `null` returns [allowNull]
  /// - Empty string returns `true` only if [allowEmpty] is `true`
  /// - Non-empty string matched against [pattern] with [caseSensitive] flag
  /// - Non-string objects accepted (useful for flexible annotation targets)
  ///
  /// The [host] and [arguments] parameters are unused.
  @override
  FutureOr<bool> call(object, {covariant Never? host, arguments}) {
    bool result = true;

    if (object == null) {
      result = allowNull;
    }
    else if (object is String) {
      if (allowEmpty && object.isEmpty) {
        result =  true;
      }
      else if (object.isEmpty) {
        result = false;
      }
      else {
        final regex = caseSensitive
            ? RegExp(pattern)
            : RegExp(pattern, caseSensitive: false);
        result = regex.hasMatch(object);
      }
    }
    return result;
  }
}

/// [Values] is a specialized [TestRule] that validates whether a given input
/// is present within a predefined collection of allowed values.
///
/// It is the primary mechanism for **Annotation-Based Whitelist Validation**,
/// serving as a declarative way to represent enumerations, fixed option sets,
/// or "Choice" constraints without requiring a formal Dart `enum`.
///
/// ### When to use
/// Use this on fields that should be restricted to a specific set of values –
/// e.g., status fields, user roles, priority levels. It's a lightweight
/// alternative to creating a full Dart enum.
///
/// ### How it works
/// The generated validation code checks if the field's value is in the
/// provided [values] list. It uses `Iterable.contains`, so equality is based
/// on `==` and `hashCode`.
///
/// ### Non‑obvious
/// - You can include `null` in the list to allow `null` values.
/// - Equality is based on `==`, so for custom objects you may need to override
///   `==` and `hashCode`.
/// - Non‑matching values (including `null` if not in the list) fail validation.
///
/// ### Examples
///
/// #### 1. Status and Role Whitelisting
/// ```dart
/// @Values(['pending', 'approved', 'rejected'])
/// final String status;
///
/// @Values(['admin', 'editor', 'viewer'])
/// final String userRole;
/// ```
///
/// #### 2. Numeric Option Sets
/// ```dart
/// @Values([1, 2, 3, 5, 8])
/// final int storyPoints; // Fibonacci-based estimation
/// ```
///
/// #### 3. Nullable Options
/// ```dart
/// @Values([null, 'small', 'medium', 'large'])
/// final String? size; // Allows an explicit null (unselected) state.
/// ```
///
/// ### Parameters
/// - [values]: An [Iterable] of any type representing the allowed set.
///   Validation uses `Iterable.contains`, so membership is determined by
///   the object's `==` operator and `hashCode`.
///
/// > **Validation Logic**:
/// > - Returns `true` if the [object] is found within the [values] collection.
/// > - Returns `false` for any value (including `null`) not explicitly
/// >   present in the whitelist.
class Values extends TestRule<Never> {
  /// The collection of allowed values that the input must exactly match.
  ///
  /// Validation uses `Iterable.contains`, so equality depends on `==` and
  /// `hashCode` for custom objects.
  ///
  /// Can include `null` if explicitly allowed:
  ///
  /// ```dart
  /// @Values([null, 'optional'])
  /// String? optionalField;
  /// ```
  final Iterable<dynamic> values;

  /// Creates a new [Values] rule for annotation-based whitelist validation.
  ///
  /// Annotate fields to restrict them to a fixed set:
  ///
  /// ```dart
  /// @Values(['low', 'medium', 'high'])
  /// String priority;
  /// ```
  const Values(this.values) : super.base();

  /// Returns `true` if [object] is contained in [values].
  ///
  /// - Uses `values.contains(object)` for exact match.
  /// - Returns `false` for `null` unless `null` is in [values].
  ///
  /// The [host] and [arguments] parameters are ignored.
  @override
  FutureOr<bool> call(object, {covariant Never? host, arguments}) {
    return values.contains(object);
  }
}

/// [EmailPattern] is a specialized [EntryPattern] metadata annotation designed
/// to validate whether a string conforms to a standard email address format.
///
/// It provides a declarative mechanism for **Electronic Mail Validation**,
/// allowing the `cell.core` framework and code generation tools (like
/// `build_model`) to ensure that user-provided contact information adheres
/// to structural internet standards before being accepted into the
/// reactive graph.
///
/// ### When to use
/// Use this on `String` fields that store email addresses to ensure they
/// follow a valid format before processing (e.g., sending emails).
///
/// ### How it works
/// By default, it uses a robust regex that checks for user@domain.tld.
/// You can customise the pattern if needed.
///
/// ### Non‑obvious
/// - The default pattern is case‑insensitive and allows typical email formats.
/// - `null` is allowed by default (use `allowNull: false` to reject null).
/// - For strict RFC compliance, consider providing a custom [pattern].
///
/// ### Examples
///
/// #### 1. Standard Profile Validation
/// ```dart
/// @EmailPattern()
/// final String workEmail;
/// ```
///
/// #### 2. Custom Pattern or Nullability
/// ```dart
/// @EmailPattern(
///   pattern: r'^[a-z.]+@corporate\.com$',
///   allowNull: true
/// )
/// final String? corporateEmail;
/// ```
///
/// ### Parameters
/// - [pattern]: The regular expression string. Defaults to a robust, common
///   email validation pattern: `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`.
/// - [caseSensitive]: Defaults to `false`, as email addresses are generally
///   treated as case-insensitive during validation.
/// - [allowEmpty]: Defaults to `false`.
/// - [allowNull]: Defaults to `true`, facilitating optional contact fields.
///
/// > **Note**: While the default regex handles the vast majority of valid
/// > email formats, email validation is notoriously complex. For strict
/// > RFC compliance, consider a custom [pattern].
class EmailPattern extends EntryPattern {
  /// Creates a [EmailPattern].
  const EmailPattern({super.pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', super.caseSensitive = false, super.allowEmpty = false, super.allowNull = true});
}

/// [WebsiteUrlPattern] is a specialized [EntryPattern] metadata annotation
/// designed to validate whether a string conforms to a standard web URL format.
///
/// It provides a declarative mechanism for **Universal Resource Locator
/// Validation**, allowing the `cell.core` framework and code generation tools
/// (like `build_model`) to ensure that user-provided links and web endpoints
/// adhere to structural internet standards before being accepted into the
/// reactive graph.
///
/// ### When to use
/// Use this on `String` fields that store URLs to ensure they are valid
/// web addresses before processing (e.g., opening in a browser, fetching data).
///
/// ### How it works
/// By default, it uses a regex that checks for http:// or https://, domain,
/// and optional path. You can customise the pattern if needed.
///
/// ### Non‑obvious
/// - The default pattern allows optional protocol (http/https), domain, TLD,
///   and optional path.
/// - `null` is allowed by default (use `allowNull: false` to reject null).
/// - For strict URL validation (e.g., requiring certain subdomains), provide
///   a custom [pattern].
///
/// ### Examples
///
/// #### 1. Standard Link Validation
/// ```dart
/// @WebsiteUrlPattern()
/// final String portfolioUrl;
/// ```
///
/// #### 2. Custom Pattern or Nullability
/// ```dart
/// @WebsiteUrlPattern(
///   pattern: r'^https:\/\/corporate\.com\/[a-z]+$',
///   allowNull: true
/// )
/// final String? officialPage;
/// ```
///
/// ### Parameters
/// - [pattern]: The regular expression string. Defaults to a robust, common
///   URL validation pattern: `^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$`.
/// - [caseSensitive]: Defaults to `false`, as URLs are generally treated
///   as case-insensitive for validation purposes.
/// - [allowEmpty]: Defaults to `false`.
/// - [allowNull]: Defaults to `true`, facilitating optional URL fields.
///
/// > **Note**: The default regex is designed for general-purpose web
/// > addresses. For strict adherence to specific RFCs or to require
/// > mandatory subdomains/paths, consider a custom [pattern].
class WebsiteUrlPattern extends EntryPattern {
  /// Creates a [WebsiteUrlPattern] rule.
  const WebsiteUrlPattern({super.pattern = r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$', super.caseSensitive = false, super.allowEmpty = false, super.allowNull = true});
}