# Seam probe transcript

Copied unchanged from the Phase 0 probes (cell 2.1.0, 2026-11-23). The decision and the seam tables live in the README; this file keeps the raw probe output and the NoSuchMethodError record so pub.dev readers meet install, usage, durability, and non-goals first.

### Probe output (copied unchanged)

```text
SEAM|ApplyCommand|record|(function, arguments: (positionalArguments, namedArguments), compensation)
SEAM|apply-tx-outside|tx-null|direct apply passes no ApplyTransactionScope
SEAM|apply-direct-state|ApplyAccepted|apply runs the command function and returns its result; value is unchanged — apply is not the value mutation path
SEAM|transaction-rollback|pass|neither ValueCell changed
SEAM|implements-Cell|pass|StubCell implements the 11 public members the analyzer demanded
SEAM|implements-Pulse|pass|StubPulse implements the 50 members the analyzer demanded
SEAM|extends-CellBase|pass|CellBase is public, has a public constructor, and is what the framework test fixtures extend
SEAM|transaction-commit|pass|both ValueCells changed
SEAM|Cell.id|framework-assigned|a=nucleus:2972c920 b=nucleus:27d9d888; memory id stays an explicit open argument
SEAM|Cell.state-id-parameter|absent|the caller cannot pass id
SEAM|transaction-foreign-commit|observed|NoSuchMethodError: NoSuchMethodError: Class 'StubCell' has no instance getter '_nucleus'.
SEAM|transaction-foreign-apply-calls|observed|0 (Cell.apply is not the commit path)
SEAM|deputy-read-only|pass|deputy apply rejected, principal update accepted
SEAM|deputy-shared-state|pass|one state, not a copy
SEAM|link-into-implementer|link-result|true
SEAM|deputy-wrong-base|observed|StateError: Bad state: Causal Integrity Violation: The new DeputyContext must be a direct descendant of the current context.
SEAM|deputy-identity|pass|no narrowing returns the principal instance
SEAM|Pulse-members|50|Iterable (30) + Comparable (1) + Pulse own (19); full list in README
SEAM|link-into-implementer|stop|delivery throws NoSuchMethodError on private _nucleus
SEAM|open-cell-link|link-result|unlink=true
SEAM|open-cell-link|stop|emit throws NoSuchMethodError on private _nucleus
SEAM|link-from-implementer|observed|NoSuchMethodError expected: private _nucleus is un-implementable
SEAM|bind-from-implementer|observed|construction ok; first use throws NoSuchMethodError: bind reads private _nucleus
SEAM|replay-entry|ReplayEngine.replay({ledger, target, ...})|exists
SEAM|Pulse-types|payload:P? source:Cell?|payload null on a null-valued pulse
SEAM|link-into-CellBase|pass|delivery works only for CellBase subclasses; payload 7 has runtime type int
SEAM|replay-flag|none|callers must pass MemoryWritePolicy.replay; the package must not sniff a flag
SEAM|Pulse-source-narrowing|legal|MemoryPulse may override source as MemoryCell<T>?
SEAM|open-cell-into-CellBase|pass|OpenCell emit delivers into a CellBase subclass
SEAM|write-policy-equivalent|none|cell_memory owns the policy type
SEAM|observe-ingress|pass|Cell.observe(source: stateCell) delivers payloads; stop() detaches
SEAM|bind-CellBase-upstream|pass|Cell(bind: CellBaseSubclass) constructs and first use does not throw
SEAM|link-from-CellBase|pass|a CellBase subclass with an explicit Synapses links downstream and re-emits
SEAM|payload-shape|retained value|payload is int, not a wrapper envelope
SEAM|transaction-CellBase|pass|commit delivers the staged value into the CellBase receptor (payload 42)
SEAM|link-rejection|disabled|returns false, does not throw
SEAM|link-rejection|testRule|returns false, does not throw
SEAM|link-duplicate|returns-false|one delivery path, length 1
SEAM|detach|Synapses.unlink(cell, downstreamCell:)|second update does not arrive
SEAM|encodeTissue|Map<String, dynamic> encodeTissue(Tissue<dynamic>, {bool lenient = false, TestTissue lenientFallbackTestRule})|present
SEAM|decodeTissue|returns a new TissueBase, does not fill an existing tissue|present
SEAM|TissueList-replace|clear + addAll public (List<E> interface)|restore via List API
```

The observed stop, now asserted as a record:

```text
NoSuchMethodError: Class 'StubCell' has no instance getter '_nucleus'.
Receiver: Instance of 'StubCell'
Tried calling: _nucleus
  package:cell/src/internal/synapses.dart 869:32  SynapsesBase._broadcast
```
