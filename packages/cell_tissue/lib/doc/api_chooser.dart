// GENERATED FILE — do not edit by hand.
// Regenerate with: dart run tool/generate_api_chooser.dart
//
// Documentation only — this library is not imported by
// application code. It renders the AI decision matrix on pub.dev.
/// ## API Chooser — `cell_tissue` operators
///
/// **Layer:** Tissue — the books. Owns: the five collection types,
/// TestTissue, deputies, `.unmodifiable`. Does **not** own: the decision
/// (cell_flow), the glue (Cell.observe).
/// 
/// **Read this file when:** a BRD sentence says "record every Y",
/// "reserve N units", "protected / guarded keys", "open incidents by X",
/// "alert the supervisor", or "council reads, cannot delete".
///
/// The full decision procedure lives in `HowTo-Mitose-Flow.md`; this
/// matrix is generated from the `### AI Agent Guide` blocks and cannot
/// drift.
///
/// | Symbol | When to use | When NOT to use | Live signature | Guide | Example |
/// |---|---|---|---|---|---|
/// | `Iterable` | ** the shared surface of `TissueList` / `TissueSet` / `TissueMap` / `TissueQueue` / `TissueValue` — every book is a Cell under the hood with its own lock and collection pulses. | ** as a book directly — pick one of the five concrete types; a plain Dart `List` is not a book. | ** `abstract interface class Tissue<E> implements Cell, Iterable<E>` — pinned at `cell_tissue: 1.0.0` | ** `HowTo-Mitose-Tissue.md` §2 "Examine all five collections against the BRD" (#tissue-catalog) | ** `example/cell_tissue_example.dart` |
/// | `Pulse` | ** optional second-order observe on a book (e.g. UI shows the audit log live); app observers in a Cell-variant Demo still sit on the **gate Cell**. | ** as the decision signal — Tissue records, Flow decides. | ** `abstract interface class TissuePulse<E> implements Pulse<E>` — pinned at `cell_tissue: 1.0.0` | ** `HowTo-Mitose-Tissue.md` §1 "What Tissue owns in a Demo" (#tissue-owns) | ** `example/cell_tissue_example.dart` |
/// | `TestTissue` | ** `testRule:` on **every** Tissue constructor: append-only log, non-negative reserve, key shape, or documented `allowAll`. | ** {@macro ai-do-not-testcell-on-tissue} | ** `TestTissue<E, C extends Tissue<E>>(FutureOr<bool> Function(dynamic object, {C? host, dynamic arguments, dynamic user}) rule, {TestTissue<E, C>? parent, dynamic user})` — pinned at `cell_tissue: 1.0.0` | ** `HowTo-Mitose-Tissue.md` §3 "TestTissue — considering factors" (#tissue-testtissue) | ** `example/cell_tissue_example.dart` |
/// | `TissueList` | ** "record every alert and action" — ordered history, indexable log, 24-month retention = append-only list (not a purge job). | ** {@macro ai-do-not-testcell-on-tissue} {@macro ai-do-not-dart-list-as-system-of-record} | ** `TissueList<E>({bind, context, receptor, testRule, synapses, growable})` / `TissueList.of(iterable, {...})` / `TissueList.unmodifiable(bind, {...})` — pinned at `cell_tissue: 1.0.0` | ** `HowTo-Mitose-Tissue.md` §2.1 "TissueList — the audit book" (#tissue-list) | ** `example/cell_tissue_example.dart` |
/// | `TissueMap` | ** "open incidents across terminals / streams" — one open row per belt/stream; `incidentMap[key] = ...`, `incidentMap.remove(key)` only from `closeIncident`. | ** {@macro ai-do-not-testcell-on-tissue} A new Map per bag — the payload on `V` carries the many. | ** `TissueMap<K, V>({bind, context, testRule, receptor, synapses, ...})` / `TissueMap.of(entries, {...})` / `TissueMap.unmodifiable(bind, {...})` — pinned at `cell_tissue: 1.0.0` | ** `HowTo-Mitose-Tissue.md` §2.3 "TissueMap — open work keyed by location" (#tissue-map) | ** `example/cell_tissue_example.dart` |
/// | `TissueQueue` | ** "alert the supervisor / RTU / issuer" — audit enqueue (`addLast(job)`) with an optional `capacity` for backpressure; the Dart list + `_driveAlert` is the retry-once pump. | ** {@macro ai-do-not-testcell-on-tissue} {@macro ai-do-not-drain-tissuequeue} | ** `TissueQueue<E>({bind, context, testRule, receptor, synapses, ...})` / `TissueQueue.of(iterable, {...})` / `TissueQueue.unmodifiable(bind, {...})` — pinned at `cell_tissue: 1.0.0` | ** `HowTo-Mitose-Tissue.md` §2.4 "TissueQueue — outbound work" (#tissue-queue) | ** `example/cell_tissue_example.dart` |
/// | `TissueSet` | ** "protected / diplomatic / resus never re-routed" — unique membership fed **into** `riskOf(tick, protected)`; uniqueness is free. | ** {@macro ai-do-not-testcell-on-tissue} {@macro ai-do-not-two-lists-for-compliance} | ** `TissueSet<E>(Iterable<E> elements, {bind, context, testRule, receptor, synapses, ...})` / `TissueSet.unmodifiable(bind, {...})` — pinned at `cell_tissue: 1.0.0` | ** `HowTo-Mitose-Tissue.md` §2.2 "TissueSet — the guard register" (#tissue-set) | ** `example/cell_tissue_example.dart` |
/// | `TissueValue` | ** "45,000 bags / 42 trolleys / 800 MW / ledger cents" — one governed number with an invariant (`TestTissue` `>= 0`) plus a harness pre-check. | ** {@macro ai-do-not-testcell-on-tissue} `Cell.state<int>` when the WalkThrough named a reserve book. | ** `TissueValue<V>(V? value, {bind, context, testRule, receptor, synapses, finalValue})` / `TissueValue.empty({...})` / `TissueValue.unmodifiable(bind)` — pinned at `cell_tissue: 1.0.0` | ** `HowTo-Mitose-Tissue.md` §2.5 "TissueValue — the reserve scalar" (#tissue-value) | ** `example/cell_tissue_example.dart` |
/// | `Unmodifiable` | ** COMPLY / council views — `book.unmodifiable` is a **live** zero-copy view, not a snapshot; use `.deputy(testRule: …)` for a narrowed write set. | ** a daily PDF roll-up (that is a harness **read**, not a view); never keep two books "for compliance". | ** `abstract interface class UnmodifiableTissue<E> implements Tissue<E>, Unmodifiable` — pinned at `cell_tissue: 1.0.0` | ** `HowTo-Mitose-Tissue.md` §4 "Deputies and .unmodifiable" (#tissue-deputies) | ** `example/cell_tissue_example.dart` |
///
/// ## How this matrix stays fresh
///
/// * `dart run tool/generate_api_chooser.dart` — regenerates this file.
/// * `test/api_chooser_up_to_date_test.dart` — fails CI if stale.
/// * `dart run tool/ai_preflight.dart` — fails CI if a pin drifts.
///
// ignore: unnecessary_library_name
library cell_tissue_api_chooser;

