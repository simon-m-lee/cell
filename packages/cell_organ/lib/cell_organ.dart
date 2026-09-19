// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// {@category Core}
/// # Cell Organ (The Conactive Model)
///
/// A high-performance, architecturally dense, and reactive data-modeling framework
/// for Dart that conceptualizes state as a **Biological Organism**.
///
/// `cell_organ` is the structural layer of the `cell` ecosystem, built upon the
/// `cell_tissue` reactive foundation. It provides the **Somatic Infrastructure**
/// required to manage complex entity relationships, metabolic state transitions,
/// and hierarchical property inheritance through a bio-inspired lens.
///
/// ## 🧬 The Conactive Philosophy
///
/// The framework operates on the principle that data is not static; it is a
/// **Living Synaptic Mesh**. Entities are treated as [Model] organisms, properties
/// as [Field] somatic units, and transactions as [Metabolic Waves].
///
/// ### 1. Genomic Blueprints (The Nucleus)
/// Every organism ([Model]) and property ([Field]) is governed by a [Nucleus].
/// This acts as the **Instructional DNA**, housing the structural metadata,
/// validation rules (Immune System), and pulse transduction logic (Nervous Center)
/// that defines how the entity behaves before it is ever materialized into state.
///
/// ### 2. Somatic Units & Metabolism
/// When a [Model] is instantiated, it materializes its **Somatic Tissue**.
/// State changes are treated as **Metabolic Waves**—signals that travel through
/// a [Receptor] (Nervous Center), are gated by a [TestRule] (Immune System),
/// and finally committed to the somatic reservoir. This ensures that every
/// mutation is governed, atomic, and reactive.
///
/// ### 3. The Deputy Pattern (Epigenetic Specialization)
/// A core innovation of the framework is the **Deputy Pattern**. Using the
/// `.evolve()` or `.deputy()` mechanisms, an existing organism or relationship
/// can project a "Deputy"—a specialized lens that shares the same physical
/// source of truth but operates under a different **Context** or **Immune System**.
/// This allows for restricted views (e.g., read-only, filtered, or high-priority)
/// without duplicating the underlying state.
///
/// ### 4. Synaptic Topology & Mirror Synchronization
/// Relationships are modeled as **Synaptic Bridges** ([Relation]). The framework
/// implements a **Double Handshake** protocol (Mirror Synchronization) that
/// automatically establishes bidirectional integrity. When an entity "Belongs To"
/// a principal, the principal's collection automatically reflects the new child,
/// maintaining a coherent mesh without manual wiring.
///
/// ## Core Physiological Components
///
/// *   **[Model] & [One]:** The primary interfaces for identifiable organisms.
///     They manage the somatic assembly of fields and coordinate systemic
///     metabolism.
/// *   **[Field]:** The basic unit of somatic state.
///     *   [ValueField]: Manages scalar property state (The "Cytoplasm").
///     *   [RelationField]: Manages the anchor points for synaptic links.
/// *   **[Relation]:** Specialized containers for the synaptic mesh.
///     *   [RelationOne] ([HasOne], [BelongsTo]): Singular junctions.
///     *   [RelationMany] ([HasMany], [ManyToMany]): Plural populations.
/// *   **[RelatableReceptor]:** The **Nervous Center** that intercepts
///     metabolic signals, performing transduction and routing before state commitment.
/// *   **[TestRelatable]:** The **Immune System**—a composable validation
///     architecture that protects the organism's homeostasis by gating
///     invalid metabolic waves.
/// *   **[Cascade]:** A **Synaptic Crawler** that flattens complex relational
///     graphs into observable populations for mass-metabolism or validation.
///
/// ## Usage in Ontogeny (Code Generation)
///
/// In a typical `cell` project, the `cell_ontogeny` package scans these
/// definitions to generate **Taxonomic Blueprints**. This allows for
/// type-safe re-hydration of entire entity meshes from persistent storage
/// (JSON/Maps) via the [Reference] registry.
///
/// ```dart
/// // Example of a Somatic Organism
/// class User extends Model {
///   // A scalar property (Somatic Field)
///   ValueField<User, String> get name => field(#name);
///
///   // A synaptic bridge (One-to-Many)
///   HasMany<User, Post> get posts => relation(#posts);
///
///   @override
///   ModelNucleus<User> get initNucleus => ModelNucleus(
///     fields: [#name, #posts],
///     // Systemic Immune Guarding
///     testRule: TestModel(rules: [IsNotEmpty(#name)]),
///   );
/// }
/// ```
///
/// ## Library Topology
///
/// The library is partitioned into functional layers:
/// - **Somatic Core:** Entity ([Model], [One]) and Host ([RelatableMixin]) logic.
/// - **Genomic Layer:** Metadata ([Nucleus]) and DNA definitions.
/// - **Field System:** Containers for scalar and relational state.
/// - **Synaptic System:** Logic for singular and plural mesh connectivity.
/// - **Immune System:** Validation ([TestRule]) and homeostasis guarding.
/// - **Nervous System:** Pulse transduction ([Receptor]) and propagation ([Synapses]).
/// - **Metabolic Tools:** Graph traversal ([Cascade]) and re-hydration ([Reference]).
// ignore: unnecessary_library_name
library cell_organ;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:core';
import 'dart:math' as math;

// import 'package:collection/entity-src/iterable_extensions.dart';

import 'package:collection/collection.dart';

import 'package:cell_tissue/cell_tissue.dart';
export 'package:cell_tissue/cell_tissue.dart';

part 'src/relatable.dart';
part 'src/relatable_pulse.dart';
part 'src/relatable_receptor.dart';
part 'src/relatable_nucleus.dart';

part 'src/one.dart';
part 'src/blend.dart';
part 'src/many.dart';
part 'src/many_nucleus.dart';
part 'src/cascade.dart';
part 'src/test_relatable.dart';

part 'src/field/field.dart';
part 'src/field/field_nucleus.dart';
part 'src/field/field_value.dart';
part 'src/field/field_relation.dart';

part 'src/relation/relation.dart';
part 'src/relation/relation_many.dart';
part 'src/relation/relation_one.dart';
part 'src/relation/relation_nucleus.dart';

part 'src/internal/relatable.dart';
part 'src/internal/relatable_pulse.dart';
part 'src/internal/relatable_receptor.dart';
part 'src/internal/relatable_nucleus.dart';

part 'src/internal/one.dart';
part 'src/internal/blend.dart';
part 'src/internal/many.dart';
part 'src/internal/many_nucleus.dart';
part 'src/internal/cascade.dart';
part 'src/internal/test_relatable.dart';
part 'src/internal/commons.dart';

part 'src/internal/field/field.dart';
part 'src/internal/field/field_nucleus.dart';
part 'src/internal/field/field_value.dart';
part 'src/internal/field/field_relation.dart';
part 'src/internal/field/field_core.dart';
part 'src/internal/field/field_reference.dart';

part 'src/internal/relation/relation_one.dart';
part 'src/internal/relation/relation_many.dart';
part 'src/internal/relation/relation_nucleus.dart';

// part 'entity-src/procedures/associate_base.dart';
// part 'entity-src/procedures/deassociate_base.dart';
// part 'entity-src/procedures/move_base.dart';
// part 'entity-src/procedures/procedure_base.dart';
// part 'entity-src/procedures/select_base.dart';

