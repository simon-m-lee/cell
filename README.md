# Cell Framework

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Dart SDK](https://img.shields.io/badge/dart-%3E%3D3.5.0%20%3C4.0.0-blue.svg)](https://dart.dev)
[![Melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg)](https://github.com/invertase/melos)

A comprehensive reactive programming framework for Dart applications requiring high integrity, traceability, and security.

This repository is an **umbrella project** (monorepo) managed with [Melos](https://melos.invertase.dev/). It serves as the foundation for the Cell Framework ecosystem, facilitating coordinated development, testing, and versioning across multiple packages.

## 📦 Project Structure

The framework is organized into specialized packages located in the `packages/` directory.

| Package | Version | Description |
|---------|---------|-------------|
| [**cell**](packages/cell/) | `1.0.0-rc.1` | **Core Package**: Fundamental reactive primitives, operators, and progressive disclosure architecture. |

## 🚀 Getting Started

### Prerequisites

- **Dart SDK**: `^3.6.0`
- **Melos**: Required for monorepo management. Install it globally via pub:


### Workspace Setup

1. **Clone the repository**:


2. **Bootstrap the workspace**:
   This command installs all dependencies and cross-links the local packages.


## 🏗️ Architecture Philosophy

The Cell Framework follows a **biological metaphor** to describe reactive state management:

- **Cells**: Atomic units holding reactive state.
- **Tissues**: (Planned) Collections of cells working together.
- **Organs**: (Planned) Complex relational structures.

The core `cell` package provides the foundation, featuring:
- **High Integrity**: Built-in validation and security policies.
- **Traceability**: Complete causal traces for every state change.
- **Progressive Disclosure**: API complexity that scales with your needs.

## 🛠️ Development Commands

Use Melos to run commands across the entire monorepo:

| Task | Command |
|------|---------|
| **Analyze** | `melos analyze` |
| **Test** | `melos test` |
| **Format** | `melos format` |
| **Clean** | `melos clean` |
| **Check All** | `melos check` (Run analysis and tests) |

## 🧪 Testing

To run tests for the core package specifically:

cd packages/cell dart test


To run all tests across the monorepo:

melos test



## ⚠️ Status

**Current Version**: `1.0.0-rc.1` (Release Candidate)

The core `cell` package is currently the primary stable entry point. While the API is nearing stability, please refer to the [package-specific documentation](packages/cell/README.md) for detailed implementation guides.

## 🤝 Contributing

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes (`git commit -m 'Add amazing feature'`).
4. Push to the branch (`git push origin feature/amazing-feature`).
5. Open a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [GitHub Repository](https://github.com/simon-m-lee/cell)
- [Issue Tracker](https://github.com/simon-m-lee/cell/issues)
- [Core Package Guide](packages/cell/guide/HowTo-Start.md)

---
*Cell Framework - Building robust, traceable, and secure reactive applications.*

