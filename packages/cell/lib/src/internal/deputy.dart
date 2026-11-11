// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

class _CellDeputy extends CellBase with Deputy<Cell> {
  _CellDeputy(Cell bind,
      {DeputyContext context = DeputyContext.system,
      TestCell testRule = TestCell.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled})
      : super.fromNucleus(Nucleus.evolve(bind._nucleus,
            ephemeralPolicy: ephemeralPolicy,
            context: identical(context, DeputyContext.system) ? null : context,
            bind: bind,
            testRule: identical(testRule, TestCell.allowAll)
                ? null
                : TestCell<Cell>.chain([
                    bind._nucleus.testRule,
                    testRule,
                  ]),
            synapses: synapses));

  @override
  FutureOr<Cell> deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestCell testRule = TestCell.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    // 1. Causal Integrity Enforcement
    // Enforces that the security context cannot be escalated or bypassed.
    // A runtime check — an `assert` would evaporate in release builds and
    // leave the gate unenforced.
    if (context != DeputyContext.system &&
        this.context != DeputyContext.system &&
        context._parent != this.context) {
      throw StateError(
        'Causal Integrity Violation: The new DeputyContext must be a direct descendant of the current context.',
      );
    }

    // 2. Efficiency Check (Identity Preservation)
    // Avoid creating a "Deputy of a Deputy" if no actual attenuation or
    // context change is requested.
    final bool isAttenuationRequested = ephemeralPolicy != null ||
        !identical(context, DeputyContext.system) ||
        !identical(testRule, TestCell.allowAll) ||
        !identical(synapses, Synapses.enabled);

    if (!isAttenuationRequested) {
      return this;
    }

    // 3. Attenuated Evolution
    // Return a new proxy. The constructor will handle the Reciprocal Handshake
    // and rule aggregation via Nucleus.evolve.
    return _CellDeputy(
      this,
      context: context,
      testRule: testRule,
      ephemeralPolicy: ephemeralPolicy,
      synapses: synapses,
    );
  }

  // No `apply` override: the previous implementation forwarded every command
  // to the principal, bypassing the deputy's own chained `testRule`. The
  // `Deputy` mixin (via `CellBase.apply`) now evaluates `validate.action(...)`
  // on the full chain `chain([principal.testRule, deputy.testRule])`, which is
  // what "additive narrowing" was supposed to guarantee in the first place.

  /// A deputy is a transparent proxy of its principal's capabilities.
  ///
  /// It therefore exposes the principal's whitelist — plus its own `apply`
  /// gateway — so that principal-whitelisted commands are vetted through the
  /// FULL additive chain instead of falling into the trusted unvetted path.
  @override
  Iterable<Function> get modifiable {
    final principal = _nucleus.bind;
    return {
      if (principal != null) ...principal.modifiable,
      apply<dynamic>,
    };
  }
}

class _OpenCellDeputy extends _CellDeputy
    with OpenReceptorMixin, OpenSynapsesMixin
    implements OpenCell {
  _OpenCellDeputy(super.bind,
      {super.context, super.testRule, super.ephemeralPolicy, super.synapses})
      : super();

  @override
  OpenCell deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestCell testRule = TestCell.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    // Causal Integrity: the security context cannot escalate or bypass.
    // Mirrors `_CellDeputy.deputy` — an OpenCell deputy must not be created
    // under an unrelated context tree. Runtime check, not an assert.
    if (context != DeputyContext.system &&
        this.context != DeputyContext.system &&
        context._parent != this.context) {
      throw StateError(
        'Causal Integrity Violation: The new DeputyContext must be a direct descendant of the current context.',
      );
    }

    return (ephemeralPolicy != null ||
            !identical(context, DeputyContext.system) ||
            !identical(testRule, TestCell.allowAll) ||
            !identical(synapses, Synapses.enabled))
        ? _OpenCellDeputy(this,
            context: context,
            testRule: testRule,
            ephemeralPolicy: ephemeralPolicy,
            synapses: synapses)
        : this;
  }

  // `emit`/`ingest` validate through the deputy's own additive chain and then
  // forward to the principal. Pure forwarding silently discarded any stricter
  // pulse rule layered on the deputy; pure mixin routing would emit through
  // the deputy's own egress registry and orphan the principal's observers
  // (deputies are transparent proxies — writes must stay visible to the
  // principal's graph). Note: `TestCell.readOnly.call` returns `true` for
  // non-Function objects, so pulses still propagate through a read-only
  // deputy — every Function action (`apply`) is blocked.

  @override
  FutureOr<Pulse?> emit(Pulse pulse) {
    final principal = _nucleus.bind;
    final validation = validate(pulse, host: this);

    FutureOr<Pulse?> forward() =>
        principal is OpenCell ? principal.emit(pulse) : super.emit(pulse);

    if (validation is Future<bool>) {
      return validation.then((passed) => passed ? forward() : null);
    }
    return validation ? forward() : null;
  }

  @override
  Future<void> ingest(Pulse pulse, {bool serializedCompletion = false}) {
    final principal = _nucleus.bind;
    final validation = validate(pulse, host: this);

    Future<void> forward() => principal is OpenCell
        ? principal.ingest(pulse, serializedCompletion: serializedCompletion)
        : super.ingest(pulse, serializedCompletion: serializedCompletion);

    if (validation is Future<bool>) {
      return validation.then((passed) => passed ? forward() : Future.value());
    }
    return validation ? forward() : Future.value();
  }

  @override
  OpenCellAsync get async => OpenCellAsync(this);
}
