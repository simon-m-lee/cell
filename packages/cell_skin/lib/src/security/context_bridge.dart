// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Remote identity → framework provenance.
///
/// The skin does not invent an authorization model: it translates the
/// authenticated [SkinPrincipal] into the framework's own [Context]
/// and stamps inbound pulses with it, so every receipt, ledger entry
/// and replayed pulse carries the remote actor's provenance through
/// the framework's existing machinery.
/// {@category Features}
library;

import 'package:cell/cell.dart';

import 'skin_auth.dart';

/// Translates a [SkinPrincipal] into a framework [Context].
///
/// ### When to use
/// * Wiring remote identity into the graph's provenance: the adapter
///   stamps `PulseContext(baseContext: bridge.resolve(principal))` on
///   every inbound request.
///
/// ### How it works
/// [resolve] maps a principal to the least-privilege context your
/// policy demands; the membrane's default inbound context is
/// `skin:untrusted`, never `Context.system`.
///
/// ### Non-obvious
/// `Context.system` is only reachable through the explicit
/// `SystemContextBridge` opt-in — there is no silent system authority.
///
/// ### See also
/// [SkinAuth], [SkinPrincipal], `ARCHITECTURE-Skin.md` §5.
/// {@category Auth & Provenance}
abstract interface class ContextBridge {
  /// The context for [principal].
  Context resolve(SkinPrincipal principal);
}

/// The default bridge: least privilege, provenance recorded in the
/// description.
final class DescribeContextBridge implements ContextBridge {
  const DescribeContextBridge();

  @override
  Context resolve(SkinPrincipal principal) => Context.describe(
        'skin:${principal.id}'
        '${principal.roles.isEmpty ? '' : ' roles=${principal.roles.join(',')}'}',
      );
}

/// A bridge that always returns [Context.system].
final class SystemContextBridge implements ContextBridge {
  const SystemContextBridge();

  @override
  Context resolve(SkinPrincipal principal) => Context.system;
}
