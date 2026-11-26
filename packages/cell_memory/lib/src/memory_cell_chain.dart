// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of 'memory_cell.dart';

/// The durability actions a [MemoryCell] routes through its receptor chain.
///
/// One instruction per action. `apply` is the synchronous adopt; the other
/// seven are `Instruction.future` bodies that serialize on the runtime's
/// turn chain and resume the receptor continuation exactly once.
enum MemoryAction {
  /// Adopt the pulse payload as the retained value.
  apply,

  /// Read the store and hydrate the cell.
  load,

  /// Write the current value with one compare-and-swap attempt.
  save,

  /// Flush, detach, drop the in-memory value, and stop emitting.
  unload,

  /// Wire an upstream cell through `Cell.observe`.
  attach,

  /// Stop the upstream wiring created by `attach`.
  detach,

  /// Flush once and release the store.
  close,

  /// Delete the durable record and clear memory.
  remove;

  /// The action an incoming pulse selects.
  ///
  /// `ReceptorBase._proceed` wraps every non-composite pulse in a step
  /// wrapper before the chain runs, so `pulse is MemoryCommand` is false
  /// inside the dispatcher. The wrapper delegates [Pulse.type], and a
  /// [MemoryCommand] reports itself as its own type tag — that is the
  /// classification seam. A governed pulse (the `Cell.transaction` commit
  /// path) and everything else, including a domain [MemoryPulse], select
  /// [apply]; the adopt body already drops removed/unloaded memory events
  /// and echoes.
  static MemoryAction of(Pulse pulse) {
    final tag = pulse.type;
    if (tag is MemoryCommand) return tag.action;
    return MemoryAction.apply;
  }
}

/// The command pulse a public method's tear-off builds.
///
/// A [Pulse] subclass, not a [MemoryPulse]: observers must never see the
/// `Completer`. The command carries its [action], the public method's
/// [reply] channel, and the `attach` arguments. The dispatcher reaches the
/// command through [Pulse.type] — the framework hands instructions a step
/// wrapper whose runtime type is not this class, but whose `type` getter
/// delegates to the wrapped pulse.
final class MemoryCommand<T> extends PulseBase<T?> {
  /// Builds the command for [action]. The [reply] completer is the public
  /// method's return channel; [source] and [project] are the `attach`
  /// arguments; [detach] is the `remove({bool detach})` flag.
  MemoryCommand(
    this.action, {
    this.reply,
    this.source,
    this.project,
    this.detach = true,
  }) : super(payload: null);

  /// The durability action this command runs.
  final MemoryAction action;

  /// The public method's reply channel. Completed by the action body with
  /// the method's return value, or with `MemoryCorrupt` / `MemoryConflict` /
  /// `StateError` on failure.
  final Completer<Object?>? reply;

  /// The upstream cell for [MemoryAction.attach].
  @override
  final Cell? source;

  /// The projector for [MemoryAction.attach].
  final T? Function(Pulse pulse)? project;

  /// Whether [MemoryAction.remove] detaches the upstream wiring.
  final bool detach;

  /// Reports itself as its own type tag so [MemoryAction.of] can classify
  /// it through the step wrapper.
  @override
  dynamic get type => this;

  @override
  Iterator<PulseBase> get iterator => [this].iterator;
}

/// The one-stage dispatcher chain a [MemoryCell] stores as its receptor.
///
/// Fork Dispatcher, as measured by the Phase 1 spike: a single
/// `Instruction.future` stage — no `strategy`, because a strategy never sees
/// the receptor continuation. The dispatcher selects exactly one action
/// from the catalog and forwards the continuation it was given; it always
/// returns `null` so `_proceed` never broadcasts a second time. A
/// synchronous action's non-null result is forwarded through the same
/// continuation; an asynchronous action calls it once when its turn
/// finishes. A drop calls it never.
///
/// When the host is a deputy, the resumed pulse is mirrored to the root
/// cell's registry first — the continuation then delivers it to the
/// deputy's own registry. Principal observers therefore hear actions
/// performed through a context-only deputy, and each registry still
/// receives exactly one callback.
Instruction<MemoryCell<T>, Pulse, Pulse> _memoryDispatcherChain<T>(
  Map<MemoryAction, Instruction<MemoryCell<T>, Pulse, Pulse>> catalog,
) {
  final dispatcher = Instruction<MemoryCell<T>, Pulse, Pulse>.future(
    (pulse, {cell, user, future, token}) {
      final host = cell!;
      final chosen = catalog[MemoryAction.of(pulse)]!;
      void resume({required Pulse? result, required dynamic token}) {
        if (result != null) {
          final root = host._rootCell;
          if (!identical(host, root)) {
            // The continuation owns the deputy's broadcast; the mirror
            // owns the principal's. Not the S5 double delivery.
            root.synapses.call(result);
          }
          future?.call(result: result, token: token);
        }
      }

      final out = chosen.call(pulse, cell: host, future: resume, token: token);
      if (out != null) {
        // The continuation owns the single broadcast.
        resume(result: out, token: token);
      }
      return null;
    },
  );
  return Instruction<MemoryCell<T>, Pulse, Pulse>.chain([dispatcher]);
}

/// The eight library-private action instructions of a [MemoryCell].
///
/// The bodies are the cell's instance action methods, moved from the old
/// public method bodies. Every instruction resolves its host through the
/// framework's `cell` argument — nothing is captured — so a deputy or clone
/// runs the action on its own nucleus.
Map<MemoryAction, Instruction<MemoryCell<T>, Pulse, Pulse>> _memoryCatalog<T>() =>
    {
      MemoryAction.apply: Instruction<MemoryCell<T>, Pulse, Pulse>(
        (pulse, {cell, user}) => cell!._applyAction(pulse),
      ),
      MemoryAction.load: Instruction<MemoryCell<T>, Pulse, Pulse>.future(
        (pulse, {cell, user, future, token}) {
          cell!._loadAction(pulse, future, token);
          return null;
        },
      ),
      MemoryAction.save: Instruction<MemoryCell<T>, Pulse, Pulse>.future(
        (pulse, {cell, user, future, token}) {
          cell!._saveAction(pulse, future, token);
          return null;
        },
      ),
      MemoryAction.unload: Instruction<MemoryCell<T>, Pulse, Pulse>.future(
        (pulse, {cell, user, future, token}) {
          cell!._unloadAction(pulse, future, token);
          return null;
        },
      ),
      MemoryAction.attach: Instruction<MemoryCell<T>, Pulse, Pulse>.future(
        (pulse, {cell, user, future, token}) {
          cell!._attachAction(pulse, future, token);
          return null;
        },
      ),
      MemoryAction.detach: Instruction<MemoryCell<T>, Pulse, Pulse>.future(
        (pulse, {cell, user, future, token}) {
          cell!._detachAction(pulse, future, token);
          return null;
        },
      ),
      MemoryAction.close: Instruction<MemoryCell<T>, Pulse, Pulse>.future(
        (pulse, {cell, user, future, token}) {
          cell!._closeAction(pulse, future, token);
          return null;
        },
      ),
      MemoryAction.remove: Instruction<MemoryCell<T>, Pulse, Pulse>.future(
        (pulse, {cell, user, future, token}) {
          cell!._removeAction(pulse, future, token);
          return null;
        },
      ),
    };
