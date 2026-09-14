// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// # Synaptic Architecture & Model Ecosystem (Organismal Connectivity)
///
/// The `cell.model` library provides the **Advanced Synaptic Architecture**
/// required to establish high-fidelity, bidirectional connections between
/// [Model] organisms within the **Conactive Model**.
///
/// While the lower-level `cell_tissue` provides generic relational storage,
/// this library specializes that infrastructure into a **Synaptic Topology**
/// optimized for complex organismal life. It enforces strict **Biological
/// Compatibility**, ensuring that every node within a specific
/// **Metabolic Pathway** is a fully governed [Model] instance.
///
/// ## Key Physiological Concepts
///
/// ### 1. Synaptic Topology & Somatic Genesis
/// This library defines the physical manifestation of an organism's
/// relationships through specialized **Somatic Units** such as
/// [ModelHasOne], [ModelHasMany], [ModelManyToMany], and [ModelBelongsTo].
/// These are not mere data pointers; they are active junctions that
/// orchestrate the transition from a **Genomic Blueprint** (Instructional DNA)
/// to a live, reactive synaptic bridge during **Somatic Genesis**.
///
/// ### 2. Mirror Synchronization (The Double Handshake)
/// A cornerstone of this library is the implementation of the
/// **Double Handshake** protocol. This mechanism facilitates **Mirror
/// Synchronization**, where reciprocal relations (e.g., a child's
/// `BelongsTo` and a principal's `HasMany`) automatically locate and
/// synchronize with one another upon ingestion into the mesh. This
/// ensures that the **Synaptic Topology** remains coherent and
/// bidirectionally integrated without manual wiring.
///
/// ### 3. Nervous Center & Pulse Transduction
/// Every relationship in this library acts as a **Nervous Center** for
/// the host organism. It performs **Relational Transduction**,
/// intercepting population shifts or state changes in related entities
/// and transforming them into high-fidelity [RelatablePost] **Metabolic Waves**.
/// This allows an organism to perceive its environment—the neighboring
/// models—as direct extensions of its own reactive state.
///
/// ### 4. Homeostatic Guarding (The Immune System)
/// Connectivity is gated by a rigorous **Immune System** implemented
/// via [TestRelation]. These rules guard the organism's boundaries,
/// ensuring that any metabolic action (adding or removing an entity
/// from a collection) satisfies referential invariants, cardinality
/// constraints, and domain logic before the transaction is committed
/// to the somatic reservoir.
///
/// ## Architectural Roles
///
/// *   **Standardization of Life:** Ensures that all nodes in the graph
///     inherit the same metabolic capabilities, allowing for recursive
///     traversals, deep-validation, and automated serialization.
/// *   **Transactional Continuity:** Binds all relational mutations to
///     the host organism's synchronization [Lock], ensuring that
///     complex graph re-wiring occurs as an **Atomic Unit of Work**.
/// *   **Autonomous Navigation:** By enforcing a strictly-typed model
///     graph, the library provides a semantic roadmap for AI-native
///     agents and autonomous processes to traverse and manipulate the
///     organismal mesh with absolute ontological certainty.
///
/// {@category Core}
// ignore: unnecessary_library_name
library cell.model;

import 'dart:convert';

import 'cell_organ.dart';
import 'relatable.dart';
export 'relatable.dart';

part 'src/model/model.dart';
part 'src/model/mode_field.dart';
part 'src/model/model_relation.dart';
part 'src/model/relatable_reference.dart';

part 'src/internal/model/model.dart';