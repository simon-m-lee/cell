// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

class _CellDeputy extends CellBase with Deputy<Cell> {

  _CellDeputy({required Cell bind, DeputyContext context = DeputyContext.system, TestCell testRule = TestCell.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled})
      : super.fromNucleus(Nucleus.evolve(
          principal: bind._nucleus,
          ephemeralPolicy: ephemeralPolicy,
          context: identical(context, DeputyContext.system) ? null : context,
          bind: bind,
          testRule: identical(testRule, TestCell.allowAll)
              ? null
              : TestCell<Cell>.chain([
                  bind._nucleus.testRule,
                  testRule,
                ]),
          synapses: synapses,
        ));

  @override
  FutureOr<Cell> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled
  }) {
    // 1. Causal Integrity Assertion
    // Enforces that the security context cannot be escalated or bypassed.
    assert(
    context == DeputyContext.system ||
        this.context == DeputyContext.system ||
        context._parent == this.context,
    'Causal Integrity Violation: The new DeputyContext must be a direct descendant of the current context.',
    );

    // 2. Efficiency Check (Identity Preservation)
    // Avoid creating a "Deputy of a Deputy" if no actual attenuation or
    // context change is requested.
    final bool isAttenuationRequested =
        ephemeralPolicy != null ||
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
      bind: this,
      context: context,
      testRule: testRule,
      ephemeralPolicy: ephemeralPolicy,
      synapses: synapses,
    );
  }

  @override
  dynamic apply(Function function, {List? positionalArguments, Map<Symbol, dynamic>? namedArguments,
    ApplyTransactionScope? tx,
    Function? compensate,
    List? compensatePositional,
    Map<Symbol, dynamic>? compensateNamed,
    Cell? compensateCell,
  }) {
    final cell = _nucleus.bind;
    if (cell != null) {
      return cell.apply(function, positionalArguments: positionalArguments, namedArguments: namedArguments, tx: tx, compensate: compensate, compensatePositional: compensatePositional, compensateNamed: compensateNamed, compensateCell: compensateCell);
    }
  }

}

class _OpenCellDeputy extends _CellDeputy with OpenReceptorMixin, OpenSynapsesMixin implements OpenCell {

  _OpenCellDeputy({required super.bind, super.context, super.testRule, super.ephemeralPolicy, super.synapses}) : super();

  @override
  OpenCell deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled
  }) {
    return (ephemeralPolicy != null ||
            !identical(context, DeputyContext.system) ||
            !identical(testRule, TestCell.allowAll) ||
            !identical(synapses, Synapses.enabled))
        ? _OpenCellDeputy(bind: this, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses)
        : this;
  }

  @override
  OpenCellAsync get async => OpenCellAsync(this);

}

