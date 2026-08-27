# How to Use TestCell in the Cell Framework

## Table of Contents

1. [Introduction](#introduction)
2. [What is TestCell?](#what-is-testcell)
3. [Core Concepts](#core-concepts)
4. [Creating Validation Rules](#creating-validation-rules)
5. [Built-in TestRule Annotations](#built-in-testrule-annotations)
6. [Composing Rules](#composing-rules)
7. [Specialized Rules](#specialized-rules)
8. [Using TestCell with Cells](#using-testcell-with-cells)
9. [Testing TestCell](#testing-testcell)
10. [Best Practices](#best-practices)
11. [Complete Example](#complete-example)

---

## Introduction

**TestCell** is the validation gate of the Cell Framework. Every reactive node has a `TestCell` that governs what operations are allowed. It acts as the **security policy**, **business rule engine**, and **data validator** for your reactive graph.

### When to Use TestCell

- **Data Validation** - Ensure data meets business requirements
- **Security** - Control who can modify state
- **Access Control** - Restrict operations based on context
- **Business Rules** - Enforce domain invariants
- **Input Sanitization** - Filter invalid data
- **Authorization** - Check permissions before actions

---

## What is TestCell?

A `TestCell` is a validation gate that decides what's allowed. It governs four kinds of actions:

| Action | Description | Validation Method |
|--------|-------------|-------------------|
| **State Changes** | Modifying a cell's value | `call()` |
| **Function Execution** | Executing a function via `apply()` | `action()` |
| **Linking** | Establishing connections between cells | `link()` |
| **Pulse Processing** | Processing incoming signals | `pulse()` |

### Default Policies

```dart
// Allow everything (default)
final allowAll = TestCell.allowAll;

// Block mutations (read-only)
final readOnly = TestCell.readOnly;
```

---

## Core Concepts

### 1. TestCell is Composable

Rules can be combined using the `+` operator:

```dart
final policy = isPositive + isAuthorized + isInRange;
```

### 2. TestCell Supports Async

Rules can return `Future<bool>` for async validation:

```dart
final asyncRule = TestCell<Cell>((object, {host, arguments, user}) async {
  final result = await database.checkAuthorization(object);
  return result;
});
```

### 3. TestCell is Stateless

Rules are flyweights - they can be shared across many cells:

```dart
// Single instance shared by all cells
final sharedRule = TestCell<int>((value, {host, ...}) => value > 0);
final cell1 = Cell(testRule: sharedRule);
final cell2 = Cell(testRule: sharedRule);
```

### 4. TestCell Supports Deputies

Deputies layer rules on top of principals:

```dart
// Principal rule
final principalRule = TestCell<int>((value, ...) => value >= 0);

// Deputy adds additional restriction
final deputyRule = TestCell<int>((value, ...) => value <= 100);
final combined = principalRule + deputyRule;
```

---

## Creating Validation Rules

### Method 1: Simple Rule

```dart
// Rule that validates positive numbers
final isPositive = TestCell<int>((value, {host, arguments, user}) {
  return value > 0;
});

// Rule that validates non-empty strings
final isNotEmpty = TestCell<String>((value, {host, arguments, user}) {
  return value.isNotEmpty;
});
```

### Method 2: Context-Aware Rule

```dart
// Rule that checks the host cell's context
final isAuthorized = TestCell<Cell>((object, {host, arguments, user}) {
  final ctx = host?.context;
  return ctx?.domains?.contains('Admin') ?? false;
});
```

### Method 3: Rule with User Data

```dart
// Rule with configurable threshold
final thresholdRule = TestCell<int>(
  (value, {host, arguments, user}) {
    final limit = user as int? ?? 100;
    return value <= limit;
  },
  user: 50,  // Default limit
);
```

### Method 4: Async Rule

```dart
// Async rule checking external service
final asyncAuthRule = TestCell<Cell>((object, {host, arguments, user}) async {
  final user = host?.context.identity;
  if (user == null) return false;
  
  // Check external authorization service
  final authorized = await authService.isAuthorized(user);
  return authorized;
});
```

---

## Built-in TestRule Annotations

The Cell Framework provides several ready-to-use `TestRule` annotations for common validation scenarios. These can be used immediately in code or as metadata annotations for code generation.

### 1. MaxLength - String/Collection Length Validation

```dart
// Direct field limit - username cannot exceed 50 characters
@MaxLength(50)
final String username;

// List cannot have more than 10 elements
@MaxLength(10)
final List<String> tags;

// Composite validation - each string <= 20 AND list <= 5 items
@MaxLength(20, hostLength: 5)
final List<String> categories;

// Host-only validation - only validates the container
@MaxLength.host(100)
final String comment;  // Does not limit comment length, but container (e.g., List<Comment>) <= 100
```

**Usage in Code:**

```dart
// Direct usage
final maxLengthRule = MaxLength(50);
expect(await maxLengthRule.call('short text'), true);
expect(await maxLengthRule.call('x' * 60), false);

// With host validation
final hostRule = MaxLength(10, hostLength: 5);
final list = ['one', 'two', 'three', 'four', 'five', 'six']; // 6 elements
expect(await hostRule.call('item', host: list), false); // hostLength exceeded
```

### 2. ValueRange - Numeric Range Validation

```dart
// Age validation (1-120)
@ValueRange(min: 1, max: 120)
final int age;

// Percentage validation (0.0-1.0)
@ValueRange(min: 0.0, max: 1.0)
final double opacity;

// Coordinate validation
@ValueRange(min: -180, max: 180)
final double longitude;
```

**Usage in Code:**

```dart
final rangeRule = ValueRange(min: 0, max: 100);
expect(await rangeRule.call(50), true);
expect(await rangeRule.call(-1), false);
expect(await rangeRule.call(101), false);
expect(await rangeRule.call('not a number'), true); // Non-numeric passes
```

### 3. EntryPattern - Pattern/Regex Validation

```dart
// Basic pattern validation
@EntryPattern(pattern: r'^\d{3}-\d{2}-\d{4}$')
final String ssn;

// Case-insensitive with null support
@EntryPattern(
  pattern: r'^[a-z]+$',
  caseSensitive: false,
  allowNull: true,
)
final String? username;
```

**Usage in Code:**

```dart
final patternRule = EntryPattern(pattern: r'^[A-Z][a-z]+$');
expect(await patternRule.call('Hello'), true);
expect(await patternRule.call('hello'), false); // Case-sensitive by default
expect(await patternRule.call(''), false); // Empty not allowed
expect(await patternRule.call(null), false); // Null not allowed
```

### 4. EmailPattern - Email Format Validation

```dart
// Standard email validation (case-insensitive, null allowed)
@EmailPattern()
final String workEmail;

// Custom pattern with strict domain
@EmailPattern(
  pattern: r'^[a-z.]+@corporate\.com$',
  allowNull: true,
)
final String? corporateEmail;
```

**Usage in Code:**

```dart
final emailRule = EmailPattern();
expect(await emailRule.call('user@example.com'), true);
expect(await emailRule.call('user@example'), false);
expect(await emailRule.call('invalid'), false);
expect(await emailRule.call(null), true); // Null allowed by default
expect(await emailRule.call(''), false); // Empty not allowed
```

### 5. WebsiteUrlPattern - URL Validation

```dart
// Standard URL validation (null allowed)
@WebsiteUrlPattern()
final String portfolioUrl;

// Strict HTTPS URL validation
@WebsiteUrlPattern(
  pattern: r'^https:\/\/corporate\.com\/[a-z]+$',
  allowNull: true,
)
final String? officialPage;
```

**Usage in Code:**

```dart
final urlRule = WebsiteUrlPattern();
expect(await urlRule.call('https://example.com'), true);
expect(await urlRule.call('http://example.com'), true);
expect(await urlRule.call('example.com'), true); // Optional protocol
expect(await urlRule.call('not a url'), false);
expect(await urlRule.call(null), true); // Null allowed by default
```

### 6. Values - Whitelist Validation

```dart
// Status validation
@Values(['pending', 'approved', 'rejected'])
final String status;

// User role validation
@Values(['admin', 'editor', 'viewer'])
final String userRole;

// Numeric options (Fibonacci estimation)
@Values([1, 2, 3, 5, 8])
final int storyPoints;

// Nullable options
@Values([null, 'small', 'medium', 'large'])
final String? size;
```

**Usage in Code:**

```dart
final valuesRule = Values(['pending', 'approved', 'rejected']);
expect(await valuesRule.call('pending'), true);
expect(await valuesRule.call('approved'), true);
expect(await valuesRule.call('unknown'), false);
expect(await valuesRule.call(null), false); // Null not in list
```

### 7. DefaultValue - Code Generation Annotation

```dart
// Default values for code generation
@DefaultValue(42)
final int id;

@DefaultValue('Unnamed')
final String name;

@DefaultValue(true)
final bool isEnabled;

@DefaultValue(UserRole.guest)
final UserRole role;

@DefaultValue(['standard'])
final List<String> permissions;

@DefaultValue({'theme': 'light'})
final Map<String, dynamic> config;
```

---

## Composing Rules

### Using the `+` Operator

```dart
final isPositive = TestCell<int>((value, {host, ...}) => value > 0);
final isEven = TestCell<int>((value, {host, ...}) => value % 2 == 0);
final isInRange = TestCell<int>((value, {host, ...}) => value <= 100);

// All rules must pass
final policy = isPositive + isEven + isInRange;
```

### Using Built-in Rules with Custom Rules

```dart
// Combine built-in rules with custom logic
final maxLength = MaxLength(50);
final isNotEmpty = TestCell<String>((value, {host, ...}) => value.isNotEmpty);
final emailPattern = EmailPattern();

final userPolicy = isNotEmpty + maxLength + emailPattern;
```

### Using Chain Factory

```dart
final policy = TestCell.chain([
  isPositive,
  isEven,
  isInRange,
]);
```

### Custom Chain Strategy

```dart
final policy = TestCell.chain(
  [rule1, rule2, rule3],
  strategy: (object, {host, arguments, user}) {
    // Custom logic: rule2 only runs if object is not null
    if (object == null) {
      return rule3.call(object, host: host);
    }
    return rule1.call(object, host: host)
        .then((r) => r ? rule2.call(object, host: host) : false)
        .then((r) => r ? rule3.call(object, host: host) : false);
  },
);
```

---

## Specialized Rules

### TestActionRule - Function Execution Validation

```dart
// Only allow read operations
final readOnlyAction = TestActionRule<Cell>(
  (action, {host, arguments, user}) {
    final actionName = action.toString();
    return actionName.contains('read') || actionName.contains('get');
  },
);

// Validate function arguments
final argValidation = TestActionRule<Cell>(
  (action, {host, arguments, user}) {
    final args = arguments?.positionalArguments;
    if (args != null && args.isNotEmpty) {
      return args.first is int && (args.first as int) > 0;
    }
    return true;
  },
);
```

### TestLinkRule - Graph Topology Validation

```dart
// Only allow links between cells in the same domain
final sameDomain = TestLinkRule<Cell>(
  (link, {host, user}) {
    return link.context.domains == host.context.domains;
  },
);

// Block links to ValueCells
final noValueCells = TestLinkRule<Cell>(
  (link, {host, user}) {
    return link is! ValueCell;
  },
);
```

### TestPulseRule - Signal Validation

```dart
// Only accept high-priority pulses
final highPriorityOnly = TestPulseRule<Cell>(
  (pulse, {host, user}) {
    return pulse.priority >= 50;
  },
);

// Only accept pulses from admin actors
final adminOnly = TestPulseRule<Cell>(
  (pulse, {host, user}) {
    return pulse.context.actor == 'admin';
  },
);
```

---

## Using TestCell with Cells

### Basic Cell with Validation

```dart
// Using a built-in rule
final maxLength = MaxLength(50);

final cell = Cell(
  testRule: maxLength,
  receptor: Receptor((cell, pulse, {user}) {
    final text = pulse.payload as String?;
    if (text == null) return null;
    return Pulse(text);
  }),
);

// Valid update
cell._nucleus.receptor.call(Pulse('short text'));  // Passes

// Invalid update (blocked)
cell._nucleus.receptor.call(Pulse('x' * 60));  // Blocked by MaxLength
```

### ValueCell with Validation

```dart
// Combine multiple built-in rules
final emailPolicy = EmailPattern() + MaxLength(100);

final handle = Cell.state<String>(
  initial: 'user@example.com',
  evolve: (host, input) {
    return Pulse(input.payload as String? ?? '');
  },
  testRule: emailPolicy,
);

handle.update('valid@email.com');  // Passes
handle.update('invalid');          // Fails (email pattern)
handle.update('x' * 200 + '@test.com');  // Fails (max length)
```

### Model Class with Annotation Validation

```dart
class UserProfile {
  @MaxLength(50)
  final String username;
  
  @EmailPattern()
  final String email;
  
  @ValueRange(min: 1, max: 120)
  final int age;
  
  @Values(['admin', 'editor', 'viewer'])
  final String role;
  
  @WebsiteUrlPattern()
  final String? website;
  
  UserProfile({
    required this.username,
    required this.email,
    required this.age,
    required this.role,
    this.website,
  });
  
  // Code generation would add validation methods
  Future<bool> validate() async {
    final usernameValid = await MaxLength(50).call(username);
    final emailValid = await EmailPattern().call(email);
    final ageValid = await ValueRange(min: 1, max: 120).call(age);
    final roleValid = await Values(['admin', 'editor', 'viewer']).call(role);
    final websiteValid = website == null || await WebsiteUrlPattern().call(website);
    return usernameValid && emailValid && ageValid && roleValid && websiteValid;
  }
}
```

### Composite Validation Policy

```dart
// Build a comprehensive validation policy
final userPolicy = TestCell.chain([
  MaxLength(50),
  EmailPattern(),
  ValueRange(min: 1, max: 120),
  Values(['admin', 'editor', 'viewer']),
]);

// Use in a cell
final userCell = Cell(
  testRule: userPolicy,
  context: Context.module('user-management'),
);
```

---

## Testing TestCell

### Testing Built-in Rules

```dart
import 'package:test/test.dart';
import 'package:cell/cell.dart';

void main() {
  test('MaxLength validates string length', () {
    final rule = MaxLength(10);
    expect(rule.call('short'), true);
    expect(rule.call('exactly ten'), true);
    expect(rule.call('too long'), false);
  });
  
  test('MaxLength validates iterable length', () {
    final rule = MaxLength(3);
    final list = [1, 2, 3];
    expect(rule.call(list), true);
    list.add(4);
    expect(rule.call(list), false);
  });
  
  test('MaxLength with host validation', () {
    final rule = MaxLength(10, hostLength: 3);
    final host = ['a', 'b', 'c', 'd']; // 4 elements > 3
    expect(rule.call('item', host: host), false);
    
    final validHost = ['a', 'b', 'c']; // 3 elements <= 3
    expect(rule.call('item', host: validHost), true);
  });
  
  test('ValueRange validates numeric range', () {
    final rule = ValueRange(min: 0, max: 100);
    expect(rule.call(50), true);
    expect(rule.call(-1), false);
    expect(rule.call(101), false);
    expect(rule.call('not a number'), true);
  });
  
  test('EmailPattern validates email format', () {
    final rule = EmailPattern();
    expect(rule.call('user@example.com'), true);
    expect(rule.call('user@example'), false);
    expect(rule.call('invalid'), false);
    expect(rule.call(null), true);
    expect(rule.call(''), false);
  });
  
  test('Values validates whitelist', () {
    final rule = Values(['pending', 'approved', 'rejected']);
    expect(rule.call('pending'), true);
    expect(rule.call('approved'), true);
    expect(rule.call('unknown'), false);
    expect(rule.call(null), false);
  });
}
```

### Testing Combined Policies

```dart
test('Combined user policy validates correctly', () {
  final policy = MaxLength(50) + EmailPattern() + ValueRange(min: 1, max: 120);
  
  final validUser = {
    'username': 'john_doe',
    'email': 'john@example.com',
    'age': 25,
  };
  expect(policy.call(validUser), true);
  
  final invalidUser = {
    'username': 'x' * 60,
    'email': 'invalid',
    'age': 150,
  };
  expect(policy.call(invalidUser), false);
});
```

### Testing with Mock Host

```dart
class MockCell extends CellBase {
  MockCell() : super();
}

test('Rule uses host context', () {
  final rule = TestCell<Cell>((object, {host, arguments, user}) {
    return host?.context.domains?.contains('Admin') ?? false;
  });
  
  final adminHost = Cell(context: Context.module('Admin', domains: 'Admin'));
  final userHost = Cell(context: Context.module('User', domains: 'User'));
  
  expect(rule.call('anything', host: adminHost), true);
  expect(rule.call('anything', host: userHost), false);
});
```

---

## Best Practices

### 1. Use Built-in Rules When Possible

```dart
// ✅ GOOD - Use built-in rules
final emailRule = EmailPattern();
final rangeRule = ValueRange(min: 0, max: 100);
final valuesRule = Values(['pending', 'approved']);

// ❌ BAD - Re-implement built-in logic
final emailRule = TestCell<String>((email, {host, ...}) {
  return email.contains('@') && email.contains('.');
});
```

### 2. Compose Rules for Complex Validation

```dart
// ✅ GOOD - Compose simple rules
final userPolicy = MaxLength(50) + EmailPattern() + ValueRange(min: 1, max: 120);

// ❌ BAD - Single complex rule
final userPolicy = TestCell<Map>((data, {host, ...}) {
  final username = data['username'] as String?;
  if (username == null || username.length > 50) return false;
  final email = data['email'] as String?;
  if (email == null || !email.contains('@')) return false;
  // ... more validation
  return true;
});
```

### 3. Use Annotations for Model Classes

```dart
// ✅ GOOD - Declarative validation
class User {
  @MaxLength(50)
  final String name;
  
  @EmailPattern()
  final String email;
  
  @ValueRange(min: 0, max: 120)
  final int age;
}

// ❌ BAD - Imperative validation scattered everywhere
class User {
  final String name;
  final String email;
  final int age;
  
  bool validate() {
    return name.length <= 50 && email.contains('@') && age >= 0 && age <= 120;
  }
}
```

### 4. Handle Null Values Gracefully

```dart
// ✅ GOOD - Explicit null handling
final emailRule = EmailPattern(allowNull: true);
final nonNullEmailRule = EmailPattern(allowNull: false);

// ❌ BAD - Implicit null handling
final emailRule = TestCell<String>((value, {host, ...}) {
  return value != null && value.contains('@');
});
```

### 5. Document Your Rules

```dart
/// Validates user profile data.
///
/// Rules:
/// - Username: max 50 characters
/// - Email: valid email format
/// - Age: 1-120
/// - Role: one of [admin, editor, viewer]
final userProfilePolicy = MaxLength(50) + EmailPattern() + 
    ValueRange(min: 1, max: 120) + Values(['admin', 'editor', 'viewer']);
```

### 6. Use Host-Aware Validation

```dart
// ✅ GOOD - Host-aware validation
final containerRule = MaxLength(10, hostLength: 5);
final items = ['a', 'b', 'c', 'd', 'e', 'f']; // 6 items > 5
expect(containerRule.call('item', host: items), false);

// ✅ GOOD - Context-aware validation
final contextRule = TestCell<Cell>((_, {host, ...}) {
  return host?.context.isAdmin ?? false;
});
```

---

## Complete Example

Here's a complete user registration system using all the built-in TestRules:

```dart
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────
// 1. Define Model with Annotations
// ─────────────────────────────────────────────────────────────

class UserRegistration {
  @MaxLength(50)
  final String username;
  
  @EmailPattern()
  final String email;
  
  @ValueRange(min: 1, max: 120)
  final int age;
  
  @WebsiteUrlPattern(allowNull: true)
  final String? website;
  
  @Values(['free', 'premium', 'enterprise'])
  final String plan;
  
  @DefaultValue('active')
  final String status;
  
  UserRegistration({
    required this.username,
    required this.email,
    required this.age,
    this.website,
    required this.plan,
    this.status = 'active',
  });
  
  // Generated validation method
  Future<bool> validate() async {
    final usernameValid = await MaxLength(50).call(username);
    final emailValid = await EmailPattern().call(email);
    final ageValid = await ValueRange(min: 1, max: 120).call(age);
    final websiteValid = website == null || await WebsiteUrlPattern().call(website);
    final planValid = await Values(['free', 'premium', 'enterprise']).call(plan);
    return usernameValid && emailValid && ageValid && websiteValid && planValid;
  }
}

// ─────────────────────────────────────────────────────────────
// 2. Define Validation Policies
// ─────────────────────────────────────────────────────────────

// Simple validation policy
final simpleRegistrationPolicy = 
    MaxLength(50) + EmailPattern() + ValueRange(min: 1, max: 120);

// Advanced policy with all rules
final advancedRegistrationPolicy = TestCell.chain([
  MaxLength(50),
  EmailPattern(),
  ValueRange(min: 1, max: 120),
  WebsiteUrlPattern(allowNull: true),
  Values(['free', 'premium', 'enterprise']),
]);

// ─────────────────────────────────────────────────────────────
// 3. Create Cell with Policy
// ─────────────────────────────────────────────────────────────

final registrationCell = Cell(
  testRule: advancedRegistrationPolicy,
  context: Context.module('user-registration'),
);

// ─────────────────────────────────────────────────────────────
// 4. Test the System
// ─────────────────────────────────────────────────────────────

void main() async {
  print('═══════════════════════════════════════════════════════════════');
  print('  TESTCELL WITH BUILT-IN RULES DEMO');
  print('═══════════════════════════════════════════════════════════════\n');
  
  // Test valid user
  final validUser = UserRegistration(
    username: 'john_doe',
    email: 'john@example.com',
    age: 25,
    website: 'https://john.dev',
    plan: 'premium',
  );
  
  print('1. Testing Valid User:');
  print('   Username: ${validUser.username}');
  print('   Email: ${validUser.email}');
  print('   Age: ${validUser.age}');
  print('   Website: ${validUser.website}');
  print('   Plan: ${validUser.plan}');
  print('   Valid? ${await validUser.validate()}\n');
  
  // Test invalid user
  final invalidUser = UserRegistration(
    username: 'x' * 60,  // Too long
    email: 'invalid',     // Invalid email
    age: 150,             // Too old
    website: 'not a url', // Invalid URL
    plan: 'unknown',      // Invalid plan
  );
  
  print('2. Testing Invalid User:');
  print('   Username: ${invalidUser.username} (length: ${invalidUser.username.length})');
  print('   Email: ${invalidUser.email}');
  print('   Age: ${invalidUser.age}');
  print('   Website: ${invalidUser.website}');
  print('   Plan: ${invalidUser.plan}');
  print('   Valid? ${await invalidUser.validate()}\n');
  
  // Test individual rules
  print('3. Testing Individual Rules:');
  
  final maxLength = MaxLength(50);
  print('   MaxLength("short"): ${await maxLength.call('short')}');
  print('   MaxLength("x" * 60): ${await maxLength.call('x' * 60)}');
  
  final emailRule = EmailPattern();
  print('   EmailPattern("test@example.com"): ${await emailRule.call('test@example.com')}');
  print('   EmailPattern("invalid"): ${await emailRule.call('invalid')}');
  
  final rangeRule = ValueRange(min: 1, max: 120);
  print('   ValueRange(25): ${await rangeRule.call(25)}');
  print('   ValueRange(150): ${await rangeRule.call(150)}');
  
  final urlRule = WebsiteUrlPattern();
  print('   WebsiteUrlPattern("https://example.com"): ${await urlRule.call('https://example.com')}');
  print('   WebsiteUrlPattern("not a url"): ${await urlRule.call('not a url')}');
  
  final valuesRule = Values(['free', 'premium', 'enterprise']);
  print('   Values("premium"): ${await valuesRule.call('premium')}');
  print('   Values("unknown"): ${await valuesRule.call('unknown')}');
  
  // Test combined policy
  print('\n4. Testing Combined Policy:');
  
  final testData = {
    'username': 'john_doe',
    'email': 'john@example.com',
    'age': 25,
    'website': 'https://john.dev',
    'plan': 'premium',
  };
  print('   Valid data passes: ${await advancedRegistrationPolicy.call(testData)}');
  
  final invalidData = {
    'username': 'x' * 60,
    'email': 'invalid',
    'age': 150,
    'website': 'not a url',
    'plan': 'unknown',
  };
  print('   Invalid data passes: ${await advancedRegistrationPolicy.call(invalidData)}');
  
  print('\n═══════════════════════════════════════════════════════════════');
  print('  DEMO COMPLETE');
  print('═══════════════════════════════════════════════════════════════');
}
```

---

## Summary

| Concept | Description |
|---------|-------------|
| **TestCell** | Validation gate for cells |
| **MaxLength** | Validates string/collection length |
| **ValueRange** | Validates numeric range |
| **EntryPattern** | Validates string patterns |
| **EmailPattern** | Validates email format |
| **WebsiteUrlPattern** | Validates URL format |
| **Values** | Validates whitelist membership |
| **DefaultValue** | Code generation default |

### Built-in Rules Quick Reference

| Rule | Purpose | Example |
|------|---------|---------|
| `MaxLength` | String/collection length | `@MaxLength(50)` |
| `ValueRange` | Numeric range | `@ValueRange(min: 0, max: 100)` |
| `EmailPattern` | Email format | `@EmailPattern()` |
| `WebsiteUrlPattern` | URL format | `@WebsiteUrlPattern()` |
| `EntryPattern` | Custom regex | `@EntryPattern(pattern: r'^\d+$')` |
| `Values` | Whitelist | `@Values(['a', 'b', 'c'])` |
| `DefaultValue` | Code generation | `@DefaultValue(42)` |

### Key Rules

1. **Use built-in rules** - They handle common validation needs
2. **Compose rules** - Combine simple rules for complex validation
3. **Use annotations** - Declarative validation for model classes
4. **Handle null values** - Use `allowNull` parameters
5. **Test in isolation** - Unit test each rule
6. **Document your rules** - Explain what they validate