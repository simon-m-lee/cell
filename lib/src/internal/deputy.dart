// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell.dart';

class _CellDeputy extends CellBase with Deputy<Cell> {

  _CellDeputy({required Cell bind, DeputyContext context = DeputyContext.system, TestCell testRule = TestCell.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled})
      : super.fromNucleus(Nucleus.evolve(override: Nucleus(
      ephemeralPolicy: ephemeralPolicy,
      context: context,
      bind: bind,
      testRule: bind._nucleus.testRule + testRule,
      synapses: synapses,
  ), principal: bind._nucleus)
  );

  @override
  FutureOr<Cell> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled
  }) {
    return (ephemeralPolicy != null || context != DeputyContext.system || testRule != TestCell.allowAll || synapses != Synapses.enabled)
        ? _CellDeputy(bind: this, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses)
        : this;
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
    return (ephemeralPolicy != null || context != DeputyContext.system || testRule != TestCell.allowAll || synapses != Synapses.enabled)
        ? _OpenCellDeputy(bind: this, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses)
        : this;
  }

  @override
  OpenCellAsync get async => OpenCellAsync(this);

}

