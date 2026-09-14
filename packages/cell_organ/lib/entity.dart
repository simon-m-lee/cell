// Copyright (c) 2025, authors: Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

/// {@category Core}
///
/// The `cell.entity` library provides foundational components for defining
/// structured data entities and their relationships.
///
/// This library serves as an aggregation point for various parts of an entity
/// system, including the definition of base entities, their properties,
/// associated field types, and specialized relation handlers.
///
/// It also re-exports the entirety of the `package:cell_organ/relatable.dart`
/// library, making its comprehensive features for relational data management,
/// reactivity, validation, and serialization directly available to users of
/// `cell.entity`. This suggests that the entity system defined herein either
/// builds upon or is intended to be used in close conjunction with the
/// `cell_organ` framework.
///
/// Core components defined or aggregated by this library likely include:
/// - A base `Entity` class or interface (from `src/entity/entity.dart`).
/// - `EntityNucleus` for managing entity state (from `src/entity/entity_properties.dart`).
/// - Specialized field types for entities (from `src/entity/entity_field.dart`).
/// - Entity-specific handlers for "one" and "many" type relations
///   (from `src/entity/relation/*`).
///
/// Users of this library can define their data structures by extending or
/// implementing the provided entity components, leveraging the underlying
/// relational and reactive capabilities from `cell_organ`.
// ignore: unnecessary_library_name
library cell.entity;

import 'package:cell_organ/relatable.dart';
export 'package:cell_organ/relatable.dart';

// part 'src/entity/entity.dart';
// part 'src/entity/entity_properties.dart';
// part 'src/entity/entity_field.dart';
// part 'src/entity/entity_relation.dart';
