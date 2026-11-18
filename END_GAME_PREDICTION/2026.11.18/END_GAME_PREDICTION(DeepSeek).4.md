# Follow-Up Prediction: The Mitosis Framework after Causal Replay and Flutter Bindings

How the 3.0 package set changes the trajectory forecast for github.com/simon-m-lee/cell.

| | |
| --- | --- |
| **Subject** | Mitosis: `mitosis` 3.0.0, `cell` 2.0.0, `cell_flow` 1.1.0, `cell_tissue` 1.1.0, and the new Flutter family (`cell_flutter` 1.0.2, `cell_flutter_persistence` 0.1.x, `cell_flutter_router` 0.1.x, `cell_flutter_lints` 0.1.0) |
| **Prepared** | 18 November 2026 |
| **Trigger** | `mitosis` 3.0.0, "Causal Replay & Flutter Bindings", published on or about 17 November 2026 |
| **Updates** | The original *End-Game Prediction* (September 2026); *Follow-Up Prediction: The Mitosis Framework after the Mitose Pipeline* (30 September); *Follow-Up Prediction: The Mitosis Framework at First Stable Release* (11 November) |
| **Basis** | pub.dev changelogs, version histories and README pages for `mitosis`, `cell`, `cell_flow` and `cell_flutter`; repository pages as far as they could be retrieved (see Basis and limitations) |

## Key findings

- **I misread the roadmap last time.** The 11 November report treated the disappearance of the Phase 1 to Phase 3 roadmap from the umbrella README as the most informative change and lowered the graduation forecast because of it. Within about a week, two of the items I had called "no longer stated" shipped: Flutter bindings and causal replay. The earlier reading overweighted a README edit.
- **The milestone is large and real.** `cell` 2.0.0 adds a hash-chained ledger, a deterministic replay engine, what-if forks, governance replay and a `cell-replay` CLI. Four new Flutter packages add widgets, hooks, a test surface, a router bridge, persistence adapters and lint rules.
- **"Stable" turned over in about a week.** The first stable `cell` (1.1.0) was superseded by a breaking 2.0.0 roughly seven days later, and the version-coupling policy introduced in `mitosis` 2.2.0 was reversed in 3.0.0.
- **The Flutter binding's own changelog discloses unmet 1.0 gates.** A gate evaluation dated 13 November records a failed benchmark gate and a blocked external-usability gate, and the package still shipped as 1.0.0 with an explicit list of what it does not claim.
- **Adoption evidence is still thin.** Downloads rose roughly 13 to 14% in a week to about 1,150 to 1,210 for the three original packages I could check; likes remain 0 to 1; the last GitHub view I could retrieve showed 0 stars and 0 forks.
- **Revised forecast (12-month horizon):** agent-first niche toolkit about 28%, breadth-driven stall about 33%, Flutter-led niche about 17%, production graduation about 15%, methodology spin-out about 7%. These are the author of this assessment's own estimates and are not stated anywhere in the repository.

## 1. What changed since the last assessment

### 1.1 Timeline

Dates are approximate, derived from the relative ages shown on pub.dev and from dates quoted in changelogs.

| Date | Event |
| --- | --- |
| ≈10 Nov | Stable line: `mitosis` 2.2.0/2.2.1, `cell` 1.1.0, `cell_flow` 1.0.0, `cell_tissue` 1.0.0 |
| 13 Nov | `cell_flutter` 1.0 gate evaluation (dated in its changelog): benchmark gate failed, usability gate blocked |
| ≈17 Nov | `mitosis` 3.0.0; `cell` 2.0.0; `cell_flow` 1.1.0; `cell_tissue` 1.1.0; first publishes of the four Flutter packages. `cell_flutter` 1.0.0, 1.0.1 and 1.0.2 were uploaded within about an hour of each other |

### 1.2 The 3.0 package set

| Package | Version | Documented content |
| --- | --- | --- |
| `cell` | 2.0.0 | Causal Replay module (`package:cell/replay.dart`): `EffectJournal`, canonical JSON and SHA-256 fingerprints, a hash-chained `Ledger`, a `ReplayEngine` with what-if forks and fork verification, governance replay (version registry, context translators), and the `cell-replay` CLI (`verify`, `diff`, `fork`, `visualise`, `inspect`). Breaking: `Cell.asyncMap`, `fromFuture`, `fromStream`, `debounce` and `throttle` now require a `journal:`. New dependency: `crypto` |
| `cell_flow` | 1.1.0 | Republished only to move the dependency floor to `cell` ^2.0.0; the operator surface is unchanged |
| `cell_tissue` | 1.1.0 | Re-released against the new core; I did not open its changelog |
| `cell_flutter` | 1.0.2 | Widgets (`CellBuilder`, `CellSelector`, `CellValueBuilder`, `CellAsyncBuilder`, `CellListener`, `CellScope`), optional hooks, a widget-test surface, state restoration, forms, `CellErrorBoundary`, virtualized list views, an in-app inspector, migration guides from Provider, Riverpod, Bloc and setState, and a comparison document |
| `cell_flutter_persistence`, `cell_flutter_router`, `cell_flutter_lints` | 0.1.x | `SharedPreferences` and in-memory adapters; a `go_router` bridge; four `custom_lint` rules |
| `mitosis` | 3.0.0 | Umbrella; MAJOR bump through the dependency surface; version no longer tracks the Mitose pipeline |

Two workspace members are not published: `cell_mind` 1.1.0 (described as "cognitive policy") and `cell_organ` (workspace-private).

## 2. What the evidence shows

**1. The earlier roadmap largely arrived, and faster than any forecast assumed.**
*Documented:* the early umbrella README listed Flutter adapters, causal replay with what-if branches, persistence adapters, a CLI and a graph debugger. Status now:

| Earlier roadmap item | Status on 18 November |
| --- | --- |
| Flutter adapters and recipes | Delivered: `cell_flutter` 1.0.2 plus router, persistence and lint packages |
| Causal replay and what-if branches | Delivered at graph level in `cell` 2.0.0. The roadmap framed it against Tissue state; I found no claim of Tissue-level replay |
| Storage and persistence adapters | Partly: Flutter value persistence exists; the ledger stores named are in-memory and file only |
| CLI and developer tooling | Partly: the `cell-replay` CLI (with Mermaid and DOT output), an in-app inspector and lint rules. No IDE plugin or live graph debugger found |
| Full test matrix and coverage | Delivered by the author's own suites: `cell` 1,371 tests (1,174 core and 197 replay), `cell_flow` 1,091, `cell_flutter` 364 with at least 95% line coverage |
| API freeze | Not clean: `cell_flutter` declares a 1.0.x freeze, while the core went from 1.1.0 to 2.0.0 in a week |
| Multi-isolate and distributed cells, Phase 3 items | Not delivered; no mention found |

*Reading:* the author is working through the roadmap roughly in order and then documenting the gaps. The public record cannot show when the work began, because the `cell_flutter` 0.x history was never published.

**2. Replay is substantive, and its stated limits are specific.**
*Documented:* every mutation is recorded as a hash-chained ledger entry (pulse, receipt, effects, state deltas); replay rebuilds recorded state in a fresh graph; undeclared effects fail at the journal boundary; any replay deviation reports the ledger sequence and expected versus actual values. A determinism gate runs the replay suite twice and fails on differing outcomes. Stated limits: `verify` checks the chain only and the `--graph` and `--genesis` options are planned; context translators throw `UnimplementedError` when none is registered and are not yet wired into engine dispatch; the fork engine supports an isolated policy only. The `cell_flutter` changelog adds that the replay round-trip is verified for pure state, debounce, throttle, `fromFuture` and `fromStream`, that concurrent `asyncMap` effect attribution is tracked separately, and that only `Cell.fromFuture` emits error pulses.
*Reading:* replay turns "forensic trail" from a description into a checkable artifact, which is the closest thing the framework has to a differentiating feature for its stated target domains. It is also days old, and `cell_flow`'s changelog does not say whether Flow's time and async operators journal their effects.

**3. A hash chain is not, by itself, tamper-proof.**
*Documented:* the changelog describes SHA-256 hashing of each entry and a one-pass `Ledger.verify()` that recomputes every hash. It does not describe signatures or external anchoring of the head hash.
*Reading:* I did not review the implementation, so this is a question to ask rather than a finding. If the only copy of a ledger sits in a store the same party controls, that party could rewrite the whole chain and recompute it. For audit use, where the head hash is anchored matters as much as the chain.

**4. Replay was bought with an API break on the most common async operators.**
*Documented:* the five operators listed above now fail to compile without a `journal:`, and `NullJournal` is described as a loud sentinel that fails on the first effect.
*Reading:* this is in tension with the principle that you should not have to learn governance machinery until you need it. The changelog does not say whether a lightweight option exists for users who do not want replay; I did not verify. Recording overhead is also not quantified in the pages I read.

**5. The version choreography is honest, and it means "stable" does not mean slow-moving.**
*Documented:* `cell_flow` and `cell_tissue` were republished only to move a dependency floor, because `cell` 2.0.0 cannot resolve against the old `^1.1.0` constraint. The umbrella changelog justifies the MAJOR bump through SemVer on the re-exported surface and reverses, one week after introducing it, the policy that tied the umbrella version to the Mitose pipeline.
*Reading:* the SemVer reasoning is sound and openly argued. The practical consequence is that a consumer pinned to "stable" should expect breaking majors at weekly cadence until the core settles.

**6. The Flutter binding is carefully built, and its own record shows what is unproven.**
*Documented:* the binding ships with CI, a 15% benchmark regression gate, a golden-test suite and migration guides whose examples are executed against real Provider, Riverpod and Bloc code. The 13 November gate evaluation records these outcomes:

| Gate | Result recorded in the changelog |
| --- | --- |
| Documentation, coverage, migration guides, accessibility, soak, security review, link check | Passed |
| Benchmark | Failed on multi-builder bursts: 10 builders at 2.31 times and 100 builders at 2.93 times the `ValueListenableBuilder` baseline (single builder 1.25 times, which passed). The overhead is attributed to the core's pulse machinery |
| External usability | Blocked: no external developer was available to run the migration test |
| External production adoption | "No external production adopters yet" |

The 1.0.x README then lists what it does not claim, including production readiness for the paths those gates cover. On pub.dev, `cell_flutter` is shown as published by an "unverified uploader", unlike the three original packages, which sit under the verified `opencell.dev` publisher. I did not check the other new packages.
*Reading:* the candor is a credibility point. The label is looser: 1.0.0 shipped with a failed performance gate, an unrun usability test and an API-freeze promise. A reader should take the Status section, not the version number, as the guide to maturity.

**7. The project now pursues two audiences.**
*Documented:* the Flutter package compares itself openly with Provider, Riverpod and Bloc and carries a "should I use this at all?" decision document. The umbrella still lists payments, safety telemetry, energy, mobility, security and agents as target domains, and a Flutter variant of the Mitose pipeline exists as repository tooling excluded from the archive.
*Reading:* this supersedes the September view that the audience was narrowing to regulated backends. The author is now trying to reach Flutter developers, regulated-domain engineers and AI-agent users with one framework. Each path has a plausible first user, and each dilutes the effort available to the others.

**8. Adoption indicators moved a little.**
*Documented:* pub.dev showed about 1.21k (`mitosis`), 1.17k (`cell`) and 1.15k (`cell_flow`) downloads, against 1.06k, 1.03k and 1.02k a week earlier; `cell` has 1 like and the others 0. The new packages show no download counts yet. All checked packages score 160 of 160 pub points. The last GitHub view I could retrieve, which was stale, showed 0 stars, 0 forks, 1 watcher and 1 open pull request.
*Reading:* near-identical counts across packages that depend on each other still point to installs pulled through the dependency chain, CI and mirrors rather than independent users. The week-on-week rise is consistent with release-day installs and says little about adoption.

## 3. Track record of earlier calls

| Earlier call | Outcome |
| --- | --- |
| September: new capabilities would likely arrive as their own packages | Half right: the Flutter family arrived as new packages; replay landed inside `cell` |
| September: Flutter bindings, persistence and codegen were forthcoming | Flutter and persistence arrived; no codegen seen |
| September: a solo maintainer makes a stall after 1.0 likely | Not borne out in the short run; the next milestone came in a week |
| 30 September: agent-facing developer experience would arrive before any agent runtime | Held: the AI-facing surface shipped in 2.2, and `cell_mind` is still unpublished |
| 30 September: documentation-led momentum might leave the core behind | Refuted by the stable and 3.0 releases |
| 11 November: the roadmap commitments were deferred or dropped | Wrong within a week |

## 4. Scorecard against the 11 November signals

| Signal to watch | Status on 18 November |
| --- | --- |
| First issue, pull request, discussion or public dependent from a non-author | No evidence; now measured across eight published packages |
| Independent run of the pipeline on a third-party BRD | No evidence |
| Independent review of `txApply` and compensation, or reproduced benchmarks | No evidence; the new gates are author-run |
| Another structural rewrite of the guides within 90 days | No guide rewrite noted in 3.0.0, but a versioning policy was reversed within a week |
| A written position on Flutter bindings and on replay and distributed cells | Flutter and replay delivered; distributed cells unaddressed |
| A fourth layer appearing before outside users exist | Not published, but `cell_mind` and `cell_organ` exist as workspace members |

## 5. Updated end-game forecast (12-month horizon)

| Scenario | Now | 11 Nov |
| --- | --- | --- |
| Agent-first niche toolkit | 28% | 40% (before the Flutter path was split out) |
| Flutter-led niche | 17% | not separate |
| Breadth-driven stall | 33% | 35% |
| Production graduation | 15% | 15% |
| Methodology spin-out | 7% | 10% |

Treat each figure as plus or minus ten points. A sole-maintainer project with about a thousand downloads and no visible outside users usually does not reach broad adoption; I have not quantified that base rate, and it is why the stall scenario stays the largest.

### 28%: agent-first niche toolkit

A small group uses the Mitose pipeline and the AI-facing API surface to generate governed prototypes and services, with replay as an audit feature. The framework stays Dart-first and is known for its approach to AI-assisted development more than for state management.

### 17%: Flutter-led niche

A small number of Flutter developers adopt `cell_flutter` for its testing surface, restoration and replay, probably migrating from Provider or Riverpod through the guides. The bar is low (a handful of real users), but the Flutter state-management segment is crowded, the binding is slower than `ValueListenableBuilder` under multi-builder bursts, and its usability test has not been run by an outsider.

### 33%: breadth-driven stall

The project now has eight published packages and two workspace members, each with a compatibility promise, and one maintainer. Releases thin out, known gaps remain (error pulses, concurrent `asyncMap` attribution, Tissue-level replay), and no outside user appears. This is lower in the short run than it looked a week ago, because the author just delivered two roadmap items in days. It remains the largest scenario because breadth raises maintenance load without raising adoption.

### 15%: production graduation

An independent team uses the ledger and replay in an audited domain, the integrity engine receives outside review, and contributors appear. The ceiling is higher than before because replay is the feature those domains ask for. The floor is not: replay is days old, its stores are in-memory and file-based, and no independent review of the engine has appeared.

### 7%: methodology spin-out

The pipeline's method (requirements gate, executed-evidence ledger, numbered change files) is adopted or imitated outside Dart. It is portable Markdown with a coined name, but I found no external reference to it, which keeps this low.

## 6. Risks specific to this milestone

- **Breadth against capacity.** Eight published packages plus unpublished members, a declared 1.0.x freeze on the Flutter surface, and one maintainer. The patch releases uploaded within an hour of the first stable uploads (`cell_flutter` 1.0.1 and 1.0.2, and earlier `mitosis` 2.2.1) show release checks catching scoring and hygiene items after publication.
- **A young, unaudited integrity layer.** Replay sits on the same engine whose transaction and compensation internals earlier notes described as not independently reviewed, and 2.0 changed it again. Anchoring of the ledger head is an open question (section 2, item 3).
- **Determinism has edges.** Replay depends on effects being declared; concurrent `asyncMap` attribution and error-pulse coverage for `fromStream` and `asyncMap` are documented gaps; Flow and Tissue coverage is not stated.
- **Unquantified cost.** I found no recording overhead figures, and the Flutter binding is 2.3 to 2.9 times slower than the baseline under multi-builder bursts. For the real-time domains in the target list, this is the number that matters.
- **Positioning split.** The umbrella says it is not "another state-management library", while the Flutter package competes in exactly that segment and `pub.dev` topics still say `state-management`.
- **Journal friction.** Common async operators now demand a replay primitive, which strains progressive disclosure.
- **Provenance of the packages themselves.** For a framework sold on provenance, publisher verification should be uniform across the family; I checked only one new package.

## 7. Intention of the author

The September reading was a long-horizon runtime for systems where causality and auditability are non-negotiable. The 30 September and 11 November readings added agent-first onboarding and a pipeline-centred identity. This milestone shows a third behaviour: the author executes the written roadmap, then publishes the gaps and failed gates in the changelog. The Flutter binding reads as an adoption on-ramp, replay as the differentiator, and the pipeline as the process story. The likeliest strategy is to keep several routes open and see which finds a first user. That is an inference; the repository does not say it. It raises the number of ways to get a first user, and it spreads one maintainer's effort across them.

## 8. Signals to watch

| Signal | Effect on the forecast |
| --- | --- |
| First non-author issue, pull request, discussion or public dependent on any of the eight packages (check reverse dependencies on pub.dev, especially for `cell_flutter`) | Moves roughly 5 to 10 points from stall to the niche scenarios |
| An outsider completes the Flutter migration usability test, or the multi-builder benchmark ratio falls toward the single-builder figure | Raises the Flutter-led niche |
| A third-party `LedgerStore` passing the published conformance suite, or an independent review of the ledger (signatures, head anchoring, an external store) | Raises graduation |
| No further breaking major in `cell` for about 90 days | Reduces breadth-driven stall risk; a second major in that window raises it |
| Replay extended to Flow and Tissue, concurrent `asyncMap` attribution closed, error pulses added for `fromStream` and `asyncMap` | Raises graduation and agent-first niche |
| Publication of `cell_mind` or `cell_organ` before outside users exist | Signals scope outrunning adoption |
| Download growth that persists between release days | The first evidence of real use |
| A stated position on multi-isolate and distributed cells | Restores or retires the last undelivered Phase 2 item |

## 9. Conclusion

The milestone converts most of the original roadmap into published artifacts, and it corrects my last report: the framework is moving faster, and more deliberately, than the README edit suggested. Technically it is the widest and most mature the project has been, with a replay ledger that gives the audit pitch something concrete to stand on and a Flutter binding that opens a mainstream route in. Adoption evidence has not moved in step. The decisive tests over the next six months are the first independent user of any package, an outside review of the ledger and the engine beneath it, and whether the core holds still long enough for anyone to depend on it.

## Basis and limitations

- **Primary sources:** pub.dev changelogs and pages for `mitosis` 3.0.0, `cell` 2.0.0, `cell_flow` 1.1.0 and `cell_flutter` 1.0.2 (README, changelog, versions). The `cell_tissue` 1.1.0 changelog and the pages for `cell_flutter_persistence`, `cell_flutter_router` and `cell_flutter_lints` were not opened; their details come from the umbrella changelog and the `cell_flutter` README.
- **Stale views:** the umbrella README retrievable during this assessment was an October snapshot, and the GitHub pages were cached (README at rc.5). I could not read the 3.0.0 README, so I cannot say whether a roadmap section has returned. Commit history and tags were not retrievable. Stars and forks are last-observed values and may be out of date. The early roadmap table in section 2 comes from that older README.
- **Not reviewed:** source code, the replay implementation, the Flutter pipeline tooling and guides, and sample outputs. Test counts, benchmark ratios and gate results are quoted from changelogs as reported and were not reproduced.
- **Approximations:** dates derive from relative ages on pub.dev ("published 7 hours ago") and may be off by a day. Download counts include CI, mirrors and the author's own installs, and the counting window is not stated.
- **Estimates:** every probability is my own judgment and should be updated as the signals above resolve.