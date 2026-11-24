// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The RESTful transport binding for the somatic boundary.
///
/// In the framework's biological metaphor, **cell_skin_rest** acts as a
/// **Restful Membrane Pore**. It provides the physical infrastructure
/// required to bridge standard HTTP/HTTPS protocols with the internal
/// **Skin Membrane**.
///
/// ### Environmental Constraints
/// This library depends on `dart:io`. Because it binds to physical network
/// sockets, it is separated from the core `cell_skin` barrel. This ensures
/// that web-based cells or Flutter-web somatic entities can compile
/// without inheriting an incompatible `io` dependency.
///
/// ### The RESTful Journey
/// When a request arrives at this pore:
/// 1. **Signal Ingress**: The [RestAdapter] intercepts the HTTP request as
///    a raw **Skin Payload**.
/// 2. **Identity Analysis**: The [SkinAuth] gatekeeper extracts **Environmental
///    Markers** (headers, bearer tokens) to identify the caller.
/// 3. **Pulse Conversion**: The request is translated into a **Nervous Signal**
///    and dispatched into the somatic graph for a **Command Journey**.
/// 4. **Forensic Egress**: The result of the **Somatic State Transition**
///    is sanitized into its **Skin Form** and returned as a standard
///    REST response.
///
/// ### Usage
/// ```dart
/// import 'package:cell_skin/cell_skin.dart';
/// import 'package:cell_skin/cell_skin_rest.dart';
///
/// // Physically bind the membrane to the network
/// final adapter = await RestAdapter.bind(
///   membrane: membrane,
///   auth: const AllowAllSkinAuth(), // Define the identity gatekeeper
/// );
/// ```
///
/// ### Forensic Integrity
/// This adapter ensures that protocol-level failures (e.g., 404s or 401s)
/// are correctly mapped to **Membrane Rejections** ([WireError]), ensuring
/// that the **Forensic Ledger** remains the absolute source of truth for
/// successful state changes.
///
/// ### See also
/// - [RestAdapter]: The physical server implementation.
/// - [SkinMembrane]: The boundary layer this library exposes.
/// - [SkinAuth]: The mechanism used to verify identity at this pore.
///
/// {@category Features}
/// {@category Networking}
library;

export 'src/adapters/rest/rest_adapter.dart';
export 'src/adapters/rest/skin_request_log.dart';
export 'src/security/skin_auth.dart';
export 'src/security/context_bridge.dart';
