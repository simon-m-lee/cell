// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell.dart';

/// A structured container for function arguments that allows for auditing and reversals.
///
/// [ApplyArguments] holds the data needed to call a function. Instead of passing
/// loose lists or maps, this type groups all inputs into a single, reliable record.
/// This structure makes it possible for the framework to log the exact data used
/// for every change, support "undo" logic, and delay execution during transactions.
///
/// ### Why it is used
/// - **Tracking and Auditing**: It creates a permanent record of the specific
///   data used to trigger a change, which is essential for debugging and history.
/// - **Transactions**: It allows the framework to "save" a command and its
///   arguments so they can be executed later as part of a larger group of changes.
/// - **Safety Checks**: It lets the framework's integrity rules (gates) inspect
///   the data before the function actually runs, preventing invalid state changes.
///
/// ### How it works
/// It uses a Dart record with two specific channels to mimic standard function calls:
/// 1. **`positionalArguments`**: A list of values passed in a specific order.
/// 2. **`namedArguments`**: A map of values assigned to specific names (using Symbols).
///
/// ### Technical Details
/// - **Memory Efficient**: It uses a flyweight record to keep memory usage low,
///   even when many commands are being processed at once.
/// - **Flexible**: Both fields are optional. This allows for simple calls that
///   don't require any arguments without adding the overhead of empty lists or maps.
///
/// See also:
/// - [ApplyCommand] – The full package containing the function and its arguments.
/// - [ApplyLedger] – The system that records these arguments for the audit history.
typedef ApplyArguments = ({
  List<Object?>? positionalArguments,
  Map<Symbol, Object?>? namedArguments
});

/// A set of instructions used to undo or "roll back" a change if it fails.
///
/// [ApplyCompensation] is a record that holds the logic needed to reverse
/// a specific action. It serves as a **Forensic Safety Net**, ensuring that
/// every state change that happens can be safely undone if an error occurs
/// or if a transaction is canceled.
///
/// In this framework, we treat state changes as "atomic" operations—meaning
/// the instruction to "do" something and the instruction to "undo" it should
/// always stay together.
///
/// ### Why it is used
/// - **Transactional Integrity**: When multiple changes are grouped in a
///   transaction, the framework uses these instructions to clean up and revert
///   state if the transaction cannot be completed.
/// - **Error Recovery**: If a command passes the safety gates but fails during
///   execution, the framework can automatically trigger the compensation logic.
/// - **Forensic History**: It provides a clear audit trail of not just what
///   changed, but how that change was intended to be corrected.
///
/// ### How it works
/// A compensation includes three parts:
/// 1. **`function`**: The specific action to run to perform the reversal.
/// 2. **`arguments`**: The data payload (positional or named) needed for
///    the reversal function.
/// 3. **[cell]**: The specific cell where the reversal should happen. If this
///    is null, the framework targets the same cell that performed the
///    original action.
///
/// ### Technical Details
/// - **Grouped Logic**: By bundling the function, data, and target together,
///   it prevents "orphaned" undos where the framework knows it needs to
///   revert but doesn't have the data to do so.
/// - **Delayed Execution**: Compensations are usually created at the same
///   time as the command but are only executed by the framework's internal
///   governance layer when a rollback is triggered.
///
/// See also:
/// - [ApplyCommand] — The main request that carries this compensation.
/// - [ApplyArguments] — The structure used to store the reversal data.
/// - [ApplyOutcome] — The result of a command, which may trigger a rollback.
typedef ApplyCompensation = ({
  Function function,
  ApplyArguments arguments,
  Cell? cell
});

/// A complete request to perform an action or change state within a cell.
///
/// [ApplyCommand] is a lightweight container (a record) that holds everything
/// needed to execute a task: the function to run, the data to pass to it, and
/// an optional plan to undo the change if needed.
///
/// In this framework, you don't just "call a method." Instead, you create a
/// command and submit it. This allows the framework to check permissions,
/// validate data, and keep a perfect log of every change.
///
/// ### Why it is used
/// - **Predictable Changes**: By grouping the function and its arguments into
///   one object, the framework can inspect the request before it happens.
/// - **Audit Trail**: Every command generates a "receipt," allowing you to
///   see exactly who did what and when.
/// - **Reversibility**: Because the command can carry "compensation" logic,
///   it provides a built-in way to roll back changes if an error occurs.
///
/// ### The Command Journey
/// When a command is submitted via [Cell.apply], it follows a strict path:
/// 1. **Permission Check**: The framework verifies if the function is allowed
///    to run (checking [Cell.modifiable]).
/// 2. **Safety Gate**: The "Integrity Gate" ([TestCell.action]) inspects the
///    command to ensure it won't break any business rules.
/// 3. **Execution**: The function is run, or staged if a transaction is active.
/// 4. **Receipt**: An [ApplyOutcome] is returned, containing a detailed
///    history of the event.
///
/// ### Technical Details
/// - **Lightweight**: As a Dart record, it is very memory-efficient, which is
///   important when processing thousands of signals in a complex graph.
/// - **Atomic**: It ensures the function and its "undo" logic stay together,
///   preventing situations where you change state but forget how to revert it.
///
/// See also:
/// - [Cell.apply] — The gateway used to submit these commands.
/// - [ApplyArguments] — The data payload carried by this command.
/// - [ApplyCompensation] — The instructions for undoing this command.
typedef ApplyCommand = ({
  Function function,
  ApplyArguments arguments,
  ApplyCompensation? compensation
});

/// The permanent, official record of a specific action taken by a cell.
///
/// [ApplyReceipt] is a detailed "proof of execution" created every time
/// a command is submitted. It acts as a **Forensic Marker**, capturing
/// exactly what happened, when it happened, and who was involved.
///
/// In the framework's biological metaphor, this is the "memory" of a
/// nervous signal, stored in the ledger so the system can trace the
/// cause and effect of every state change.
///
/// ### Why it is used
/// - **Causal Traceability**: It allows developers and AI agents to look
///   at any state change and see the exact command and arguments that
///   caused it.
/// - **Transaction Auditing**: It tracks whether an action was part of a
///   larger transaction and where it sits in that sequence.
/// - **Security Verification**: It records whether an action was "vetted"
///   (checked against safety gates) or executed as a trusted internal operation.
///
/// ### How it works
/// A receipt is synthesized by the [ApplyLedger] and contains several
/// identifying pieces of data:
/// 1. **`id`**: A unique string used to correlate requests with outcomes.
/// 2. **`timestamp`**: The exact moment the command was processed.
/// 3. **`vetted`**: A safety flag. If `false`, it means the action bypassed
///    the standard integrity gates (usually because it was a trusted operation).
///
/// ### Technical Details
/// - **Immutable Record**: Like other types in the `apply` system, this
///   is a Dart record. It is read-only and designed to be stored in
///   history logs without high memory overhead.
/// - **Correlation**: The `id` is essential for asynchronous or
///   transactional workflows where you need to match a result back to
///   its original request.
///
/// See also:
/// - [ApplyOutcome] — The result that carries this receipt.
/// - [ApplyLedger] — The utility that generates these receipts.
/// - [ApplyCommand] — The original request captured by this receipt.
typedef ApplyReceipt = ({
  String id,
  Cell cell,
  Function function,
  ApplyArguments arguments,
  DateTime timestamp,
  int? txSequence,
  bool vetted
});

/// The official, auditable result of submitting an [ApplyCommand].
///
/// Every time you ask a cell to perform an action (by submitting a command),
/// the framework returns an [ApplyOutcome]. This acts as a **Forensic Receipt**,
/// telling you exactly what happened to your request.
///
/// Because this is a `sealed` class, the result will always be one of three
/// specific types:
/// * [ApplyAccepted] — The command was successful and returned a result.
/// * [ApplyRejected] — The safety rules (Integrity Gate) denied the request.
/// * [ApplyStaged] — The command is waiting to run inside a transaction.
///
/// ### Why it is used
/// - **Causal Tracking**: It ensures that every action in the system has a
///   matching record, making it easy to trace the history of any state change.
/// - **Type Safety**: By using a sealed class, the compiler forces you to
///   handle all possible results (success, failure, or staged), preventing
///   unhandled errors in your logic.
/// - **Transaction Support**: It allows the framework to signal that a change
///   hasn't happened yet but is safely queued in the ledger.
///
/// ### How it works
/// When you call [Cell.apply], the framework processes the command and
/// packages the result into this object. Along with the result, it attaches
/// an [ApplyReceipt], which contains "meta" information like a unique ID,
/// the exact time of the change, and the specific cell that was involved.
///
/// ### Technical Details
/// - **Generic Result `R`**: The outcome preserves the type of the value
///   returned by the function, so you maintain full type-safety for the
///   resulting data.
/// - **Immutable**: Outcomes are read-only records of what occurred; they
///   cannot be changed after they are created.
///
/// See also:
/// - [ApplyReceipt] — The detailed "receipt" attached to every outcome.
/// - [Cell.apply] — The method that produces these outcomes.
/// - [ApplyCommand] — The request that generated this outcome.
sealed class ApplyOutcome<R> {
  /// Creates an outcome. The concrete subclasses are the only constructors.
  const ApplyOutcome();

  /// The forensic receipt of this submission.
  ApplyReceipt get receipt;
}

/// The command was authorized, safety-checked, and successfully executed.
///
/// [ApplyAccepted] is the successful "receipt" returned by the framework when
/// an action has been completed. It contains the data returned by your
/// function and a detailed forensic record of the event.
///
/// In the framework's biological metaphor, this represents a **Successfully
/// Transmitted Signal** that has updated the state of the reactive graph.
///
/// ### Why it is used
/// - **Successful Completion**: It confirms that the command passed through
///   the "Integrity Gate" and was executed by the cell's governance layer.
/// - **Result Delivery**: It carries the actual value returned by the
///   function, allowing you to use that data immediately in your UI or logic.
/// - **Forensic Confirmation**: It provides the [receipt], which allows you
///   to track the exact ID and timestamp of this success in the ledger.
///
/// ### How it works
/// When a command is successful, the framework wraps the return value `R`
/// into this object. Because [ApplyOutcome] is sealed, you can use a
/// `switch` statement or pattern matching to safely extract the `result`
/// only when the state is "Accepted."
///
/// ### Technical Details
/// - **Type-Safe Result**: The result `R` matches the return type of the
///   function you invoked, ensuring no data is lost or incorrectly cast.
/// - **Immediate State**: Unlike [ApplyStaged], an accepted outcome means
///    the reactive graph has already been notified of the change.
///
/// See also:
/// - [ApplyOutcome] — The base type for all command results.
/// - [ApplyReceipt] — The forensic data attached to this success.
/// - [ApplyRejected] — The outcome returned when a command is denied.
final class ApplyAccepted<R> extends ApplyOutcome<R> {
  /// The value returned by the executed function.
  final R result;

  @override
  final ApplyReceipt receipt;

  /// Creates an accepted outcome for [result] under [receipt].
  const ApplyAccepted(this.result, this.receipt);
}

/// The command was denied by the framework's safety rules (the Integrity Gate).
///
/// [ApplyRejected] is the "denial receipt" returned when an action is not
/// allowed to proceed. It signifies that the request was intercepted
/// before it could change any state, keeping the reactive graph safe.
///
/// In the framework's biological metaphor, this represents a **Blocked Signal**
/// where the cell's "Integrity Gate" determined the mutation was
/// incompatible with the current DNA.
///
/// ### Why it is used
/// - **Safety Enforcement**: It confirms that the [TestCell.action] rules
///   successfully prevented an invalid or unauthorized change.
/// - **Feedback**: It provides a [reason] explaining why the rejection
///   happened, allowing the UI or the calling logic to react appropriately.
/// - **Forensic Logging**: Even though the action failed, the [receipt]
///   captures the attempt, providing an audit trail of "Who tried to do what"
///   that was denied.
///
/// ### How it works
/// If a command fails the vetting process, the framework stops execution
/// immediately and returns this object. Because [ApplyOutcome] is sealed,
/// you can use pattern matching to safely handle the rejection and
/// display the [reason] to the user.
///
/// ### Technical Details
/// - **Result Type `R`**: The class still carries the type `R` to remain
///   compatible with the expected success type, but it contains no actual
///   result data.
/// - **Optional Reason**: The [reason] can be any object—a simple string,
///   an error code, or a complex validation object—depending on what the
///   Integrity Gate provided.
///
/// See also:
/// - [ApplyOutcome] — The base type for all command results.
/// - [ApplyAccepted] — The outcome returned when a command succeeds.
/// - [ApplyReceipt] — The forensic record of the denied attempt.
final class ApplyRejected<R> extends ApplyOutcome<R> {
  @override
  final ApplyReceipt receipt;

  /// An optional rejection reason supplied by the policy layer.
  final Object? reason;

  /// Creates a rejected outcome for [receipt].
  const ApplyRejected(this.receipt, {this.reason});
}

/// The command was accepted and placed into a transaction to be run later.
///
/// [ApplyStaged] is the "holding receipt" returned when an action is submitted
/// inside an active [ApplyTransactionScope]. It signifies that the command has
/// passed initial checks but its final result won't be known until the
/// transaction is committed.
///
/// In the framework's biological metaphor, this represents a **Stored Signal**—
/// a nervous impulse that has been captured and is waiting for a "go" signal
/// from the system to finally trigger a mutation.
///
/// ### Why it is used
/// - **Atomic Updates**: It allows the framework to group many different
///   changes together so they all happen at the exact same moment.
/// - **Conflict Prevention**: By staging commands first, the framework can
///   ensure that complex, multi-step changes don't leave the reactive graph
///   in a half-finished, "broken" state if an error occurs.
/// - **Transaction Tracking**: It provides a [receipt] immediately, allowing
///   you to track the command's place in the ledger even before it executes.
///
/// ### How it works
/// When [Cell.apply] is called with a transaction scope (`tx`), the framework
/// does not run the function immediately. Instead, it creates this staged
/// outcome and adds the command to the transaction's queue. The [receipt]
/// will include a `txSequence` number to show where this command sits in
/// the transaction.
///
/// ### Technical Details
/// - **Result Type [Never]**: Because the command hasn't run yet, there is
///   no return value. [ApplyStaged] extends `ApplyOutcome<Never>` to
///   signal that the `result` field (available in [ApplyAccepted]) does
///   not exist here.
/// - **Validation**: Even though execution is delayed, the command is
///   usually still "vetted" against safety gates before being staged.
///
/// See also:
/// - [ApplyOutcome] — The base type for all command results.
/// - [ApplyAccepted] — The outcome returned when a command actually succeeds.
/// - [ApplyTransactionScope] — The container that manages these staged commands.
final class ApplyStaged extends ApplyOutcome<Never> {
  @override
  final ApplyReceipt receipt;

  /// Creates a staged outcome for [receipt].
  const ApplyStaged(this.receipt);
}

/// A special signal used by a function to cancel its own operation.
///
/// [ApplyVeto] is a "soft-reject" convention. Sometimes, a function is
/// allowed to run by the safety rules (the Integrity Gate), but once it
/// starts, it discovers a reason why it shouldn't finish. By returning
/// [ApplyVeto.instance], the function tells the framework to stop and
/// treat the action as a rejection.
///
/// In the framework's biological metaphor, this is a **Self-Regulating Signal**
/// where a cell decides to suppress its own mutation after receiving
/// an impulse.
///
/// ### Why it is used
/// - **Internal Decisions**: Use this when the logic to reject a change
///   can only be determined *inside* the function body, rather than
///   by an external safety gate.
/// - **Clear Intent**: It is better than returning `null` or `false`,
///   because it explicitly tells the framework: "I am choosing to cancel
///   this specific action."
/// - **Transaction Safety**: When a function returns a veto, the
///   framework treats it as a failure, ensuring that any related
///   changes in a transaction are handled correctly.
///
/// ### How it works
/// You do not create new versions of this class. Instead, you return the
/// shared [ApplyVeto.instance]. The framework's execution layer checks
/// for this specific object; if found, it converts the result into an
/// [ApplyRejected] outcome.
///
/// ### Best Practices
/// - **Prefer Gates**: If you know a command should be rejected before
///   it runs, use an Integrity Gate ([TestCell.action]) instead.
/// - **Avoid Exceptions**: Use a veto when a rejection is a normal part
///   of your business logic. Use `throw` only for unexpected system errors.
///
/// See also:
/// - [ApplyRejected] — The outcome produced when a function returns a veto.
/// - [Cell.modifiable] — Where functions that might return a veto are registered.
class ApplyVeto {
  /// The shared sentinel instance returned by vetoing functions.
  static const instance = ApplyVeto._();

  /// Private constructor — only [instance] may exist.
  const ApplyVeto._();
}

/// The framework's internal **Record Keeper** and receipt generator.
///
/// [ApplyLedger] is responsible for creating unique IDs and official
/// [ApplyReceipt] records for every command submitted to a cell. It acts
/// as the "Forensic Mint," ensuring that every action in the reactive
/// graph has a traceable, timestamped identity.
///
/// In the framework's biological metaphor, this is the system that
/// captures a nervous impulse and encodes it into the **Nervous System's
/// Memory**, allowing the framework to maintain a perfect history of
/// cause and effect.
///
/// ### Why it is used
/// - **Uniqueness**: It ensures that no two actions share the same ID,
///   even if they happen at the exact same millisecond.
/// - **Standardization**: It provides a consistent way to package a
///   command and its metadata into an official record.
/// - **Cross-Package Synchronization**: It allows other parts of the
///   system (like the `cell_tissue` package) to generate receipts that
///   look and act exactly like core cell receipts.
///
/// ### How it works
/// 1. **ID Generation**: It combines a universally unique ID (UUID)
///    with a simple counter to create a "Correlation ID."
/// 2. **Receipt Synthesis**: It takes a submitted [ApplyCommand] and
///    wraps it with metadata, including a timestamp and the target cell.
/// 3. **Vetting Status**: It records whether the command was checked by
///    safety rules (vetted) or if it was a trusted internal update.
///
/// ### Technical Details
/// - **Static Utility**: This is a utility class with static methods;
///   you do not need to create an instance of it.
/// - **Automatic Handling**: Application developers rarely need to call
///   this directly. The framework handles receipt generation
///   automatically whenever you call [Cell.apply].
///
/// See also:
/// - [ApplyReceipt] — The record created by this ledger.
/// - [ApplyOutcome] — The result that carries the ledger's receipt.
/// - [Cell.apply] — The primary user of this ledger.
final class ApplyLedger {
  static int _sequence = 0;
  static final _uuid = Uuid();

  /// Mints a unique correlation id for a submission.
  static String nextId() => '${_uuid.v4()}-${_sequence++}';

  /// Synthesizes the forensic receipt for a submission of [command].
  static ApplyReceipt receipt({
    required Cell cell,
    required ApplyCommand command,
    int? txSequence,
    bool vetted = true,
  }) =>
      (
        id: nextId(),
        cell: cell,
        function: command.function,
        arguments: command.arguments,
        timestamp: DateTime.now(),
        txSequence: txSequence,
        vetted: vetted,
      );
}

/// A "fluent" shortcut that makes it easier to create and run commands on a cell.
///
/// [ApplyCommandDSL] provides a readable way to assemble a command. Instead of
/// manually building a complex data record, you can use this extension to
/// write code that reads like a sentence:
/// `cell.command(update).args([123]).run()`.
///
/// In the framework's biological metaphor, this is the **Ergonomic Gateway**
/// for triggering a nervous signal. It simplifies the process of creating
/// a high-integrity request without sacrificing the forensic details needed
/// for the ledger.
///
/// ### Why it is used
/// - **Readability**: It turns technical data structures into a "Fluent API,"
///   making it much easier for developers to see the intent of a state change.
/// - **Developer Experience**: It provides auto-complete support for
///   adding arguments, named parameters, and "undo" logic in a specific order.
/// - **Safety**: By using the builder, the framework ensures that the
///   resulting [ApplyCommand] is shaped correctly before it is submitted.
///
/// ### How it works
/// This extension adds the [command] method to every [Cell]. When called,
/// it returns an [ApplyCommandRunner], which is a temporary helper object
/// that "remembers" your choices (arguments, compensation, etc.) until
/// you are ready to [ApplyCommandRunner.run].
///
/// ### Technical Details
/// - **Optional Sugar**: This extension is "syntax sugar." The core API
///   of the framework still relies on the raw [ApplyCommand] record.
///   You can always bypass this extension and submit records directly.
/// - **Zero Overhead**: Because it is an extension, it does not add
///   extra memory weight to the [Cell] instances themselves.
///
/// See also:
/// - [ApplyCommandRunner] — The builder object that handles the assembly.
/// - [ApplyCommand] — The actual record produced by this extension.
extension ApplyCommandDSL on Cell {
  /// Begins assembling a command that invokes [function] on this cell.
  ApplyCommandRunner command(Function function) =>
      ApplyCommandRunner(this, function);
}

/// A helper class used to set up and execute an action on a cell.
///
/// [ApplyCommandRunner] is a "builder" that gathers all the pieces needed for
/// a command—the function, the arguments, and the "undo" logic—before
/// sending it to the framework for execution.
///
/// In the framework's biological metaphor, this is the **Signal Assembly**
/// phase. It prepares a nervous impulse with the correct intensity (data)
/// and reflex (undo logic) before it is transmitted through the reactive graph.
///
/// ### Why it is used
/// - **Readability**: It allows you to chain methods together in a way that
///   reads like a sentence: `cell.command(setAge).arg(25).run()`.
/// - **Step-by-Step Setup**: It makes it easy to add complex parameters,
///   like named arguments or "undo" logic, without dealing with
///   messy nested records.
/// - **Immediate Execution**: It links the command directly to a [cell],
///   allowing you to [run] the action as soon as you finish building it.
///
/// ### How it works
/// 1. **Initialization**: You start with a cell and a function (via the DSL).
/// 2. **Configuration**: You call methods like [args] or [undo] to add details.
///    These details are stored temporarily inside the runner.
/// 3. **Execution**: You call [run] to submit the command to the [cell],
///    or [build] if you just want the raw record to use later.
///
/// ### Technical Details
/// - **Stateful Builder**: Unlike the final command record, this class
///   is mutable while it is being built. It is designed to be short-lived.
/// - **Type Preservation**: The [run] method uses a generic type `R`
///   to ensure that the result you get back matches the type returned
///   by your function.
///
/// See also:
/// - [ApplyCommandDSL] — The extension that creates this runner.
/// - [ApplyCommand] — The final record produced by this builder.
/// - [Cell.apply] — The method called when you trigger [run].
final class ApplyCommandRunner {
  /// The cell the command will be submitted to by [run].
  final Cell cell;

  /// The function the command will invoke.
  final Function function;

  List<Object?>? _positional;
  Map<Symbol, Object?>? _named;
  ApplyCompensation? _compensation;

  /// Creates a builder for invoking [function] on [cell].
  ApplyCommandRunner(this.cell, this.function);

  /// Sets the positional argument list of the command.
  ApplyCommandRunner args(List<Object?> arguments) {
    _positional = arguments;
    return this;
  }

  /// Sets a single positional argument of the command.
  ApplyCommandRunner arg(Object? argument) {
    _positional = [argument];
    return this;
  }

  /// Sets the named argument map of the command.
  ApplyCommandRunner named(Map<Symbol, Object?> arguments) {
    _named = arguments;
    return this;
  }

  /// Attaches a **Reversal Blueprint** to the command.
  ///
  /// [cell] defaults to the host cell at execution time when omitted.
  ApplyCommandRunner undo(
    Function compensation, {
    List<Object?>? args,
    Map<Symbol, Object?>? named,
    Cell? cell,
  }) {
    _compensation = (
      function: compensation,
      arguments: (positionalArguments: args, namedArguments: named),
      cell: cell,
    );
    return this;
  }

  /// Materializes the assembled command record.
  ApplyCommand build() => (
        function: function,
        arguments: (
          positionalArguments: _positional,
          namedArguments: _named
        ),
        compensation: _compensation,
      );

  /// Submits the assembled command to the bound [cell] and returns its
  /// auditable [ApplyOutcome].
  FutureOr<ApplyOutcome<R>> run<R>({ApplyTransactionScope? tx}) =>
      cell.apply<R>(build(), tx: tx);
}
