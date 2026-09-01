# Cell Framework Mitosis

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Dart SDK](https://img.shields.io/badge/dart-%3E%3D3.5.0%20%3C4.0.0-blue.svg)](https://dart.dev)
[![Melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg)](https://github.com/invertase/melos)

A comprehensive reactive programming framework for Dart applications requiring high integrity, traceability, and security. This monorepo contains the complete Cell Framework ecosystem.

## 📦 Packages

| Package | Version    | Description |
|---------|------------|-------------|
| [**cell**](packages/cell/) | 1.0.0-rc.1 | Core reactive state management with progressive disclosure architecture |

## 🚀 Quick Start

### Prerequisites

- Dart SDK >= 3.6.0
- [Melos](https://melos.invertase.dev/) for monorepo management

### Installation

```bash
# Clone the repository
git clone https://github.com/simon-m-lee/Cell-Framework-Mitosis.git
cd Cell-Framework-Mitosis

# Install Melos globally (if not already installed)
dart pub global activate melos

# Bootstrap all packages
melos bootstrap

# Run static analysis on all packages
melos analyze

# Run all tests
melos test

# Format the entire codebase
melos format
```

### Using the Core Package

Add to your `pubspec.yaml`:

```yaml
dependencies:
  cell: ^1.0.0
```

Basic usage example:

```dart
import 'package:cell/cell.dart';

void main() {
  // Create a simple cell
  final count = Cell<int>(0);
  
  // Observe changes
  count.observe((value) => print('Count: $value'));
  
  // Update value
  count.value = 1;  // Prints: Count: 1
  
  // Derived cells
  final doubled = count.derive((c) => c * 2);
  print(doubled.value);  // Prints: 2
}
```

## 🏗️ Architecture

The Cell Framework follows a **progressive disclosure architecture** with four tiers:

1. **Core (cell)** - Fundamental reactive primitives and operators
2. **Collections (cell_tissue)** - Reactive data structures
3. **Relations (cell_organ)** - Object-relational modeling
4. **Persistence (cell_memory)** - Storage and serialization

### Key Features

- **16+ Core Operators**: derive, distinct, throttle, debounce, map, filter, etc.
- **Transaction Support**: Atomic multi-update operations with rollback
- **Governance Model**: Security policies, validation rules, and access control
- **Thread Safety**: Designed for concurrent access patterns
- **Forensic Traceability**: Complete audit trail of state changes
- **Test Framework**: Built-in TestCell validation utilities

## 📚 Documentation

### Core Package Guides

- [Getting Started](packages/cell/guide/HowTo-Start.md)
- [16 Essential Operators](packages/cell/guide/HowTo-16_Essential_Operators.md)
- [Transactions](packages/cell/guide/HowTo-Transaction.md)
- [Validation & Security](packages/cell/guide/HowTo-TestCell.md)
- [Advanced Patterns](packages/cell/guide/HowTo-Advanced.md)

### Examples

The core package includes 18 executable examples:

```bash
cd packages/cell

# State management demo
dart example/state_demo.dart

# Transaction demo
dart example/transaction_demo.dart

# Validation demo
dart example/validation_demo.dart

# And 15 more...
```

### API Reference

Generate local documentation:

```bash
melos exec -- dart doc
```

Or view online: [API Documentation](https://pub.dev/documentation/cell/latest/)

## 🛠️ Development Commands

This monorepo uses [Melos](https://melos.invertase.dev/) for task automation:

```bash
# Analyze all packages
melos analyze

# Run all tests
melos test

# Format code
melos format

# Regenerate code (ontogeny, etc.)
melos build

# Test only Cell Mesh packages
melos mesh:test

# Build Cell Mesh packages
melos mesh:build

# Run analysis and tests
melos check

# Clean all packages
melos clean
```

## 🧪 Testing

Run the complete test suite:

```bash
# All packages
melos test

# Specific package
cd packages/cell && dart test

# With coverage
dart test --coverage=coverage
```

## 📖 Philosophy

The Cell Framework is inspired by biological systems:

- **Cells** - Atomic reactive units that hold state
- **Tissues** - Collections of cells working together
- **Organs** - Complex relational structures
- **Organisms** - Complete applications

This biomimetic approach provides:

- Natural composition patterns
- Clear separation of concerns
- Self-healing capabilities through validation
- Evolutionary extensibility

## 🎯 Use Cases

The Cell Framework excels in:

- **Complex State Management** - Applications with intricate state dependencies
- **Data Integrity Critical Systems** - Financial, healthcare, or legal applications
- **Audit-Required Applications** - Systems needing complete change tracking
- **Concurrent Environments** - Multi-threaded or distributed systems
- **Large-Scale Applications** - Enterprise software with complex data flows

## ⚠️ Status

**Current Version**: 1.0.0 (Alpha)

This framework is in active development. While the core functionality is stable, some advanced features may undergo changes. Not recommended for production use without thorough testing.

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Authors

Lee Man Hoi Simon. See [AUTHORS](AUTHORS) for copyright holders.

## 🔗 Links

- [GitHub Repository](https://github.com/simon-m-lee/Cell-Framework-Mitosis)
- [Pub.dev Package](https://pub.dev/packages/cell)
- [Issue Tracker](https://github.com/simon-m-lee/cell/issues)
- [Documentation](https://pub.dev/documentation/cell/latest/)

---

*Cell Framework Mitosis - Building robust, traceable, and secure reactive applications.*
