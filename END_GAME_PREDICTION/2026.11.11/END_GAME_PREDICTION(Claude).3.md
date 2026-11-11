# Follow-Up Prediction: The Mitosis Framework at First Stable Release

How the 2.2 stable line changes the trajectory forecast for github.com/simon-m-lee/cell.

| | |
| --- | --- |
| **Subject** | Mitosis: `mitosis` 2.2.1, `cell` 1.1.0, `cell_flow` 1.0.0, `cell_tissue` 1.0.0 (github.com/simon-m-lee/cell) |
| **Prepared** | 11 November 2026 |
| **Trigger** | First stable release of all four packages, published on or about 10 November 2026 (pub.dev showed "published 17 hours ago") |
| **Updates** | *Follow-Up Prediction: The Mitosis Framework after the Mitose Pipeline* (30 September 2026) and the earlier *End-Game Prediction* it revised |
| **Basis** | pub.dev changelogs, version histories, scores and README for the four packages; repository pages as far as they could be retrieved (see Basis and limitations) |

## Key findings

- **Stable shipped.** The 30 September report listed the stable release as a signal to watch and noted that the freeze had slipped since rc.5. Stable arrived about six weeks later, and it is substantive: a new command model in the core, six performance phases with a benchmark gate, and a long list of correctness fixes.
- **The API moved at the finish line.** Several breaking changes landed in the stable cycle, so "stable" marks a labeling and hygiene milestone more than an API freeze.
- **The project's identity has consolidated around the Mitose pipeline and agent-facing API discovery.** The Phase 1 to Phase 3 roadmap that earlier assessments relied on (Flutter adapters, causal replay, distributed cells, multi-agent orchestration) no longer appears in the umbrella README as rendered on pub.dev.
- **Adoption evidence has barely moved.** Each package shows roughly 1,000 downloads and 0 to 1 likes. The last observed GitHub counts were 0 stars and 0 forks. Engineering maturity is now well ahead of adoption evidence.
- **Revised forecast (12-month horizon):** agent-first niche toolkit about 40%, post-stable stall about 35%, production graduation about 15%, methodology spin-out about 10%. These are the author of this assessment's own estimates and are not stated anywhere in the repository.

## 1. What changed since the last assessment

### 1.1 Release timeline

Dates are approximate, derived from the relative ages shown on pub.dev.

| Umbrella version | Approx. date | Headline |
| --- | --- | --- |
| 1.0.0-rc.9 | 30 Sep | Mitose pipeline 1.0: BRD gate, WalkThrough, Demo (the subject of the last report) |
| 1.0.0-rc.10 | 18 Oct | Mitose 2.0: residual ledger, comprehension checks, change mode, an always-written test file, the term "Precision Software Engineering" |
| 1.0.0-rc.11 | 2 Nov | Autonomous mode ("Mitose autonomous"); a master document generator |
| 1.0.0-rc.12 to rc.14 | 4 Nov | cafe-coffee worked sample; master generator extended with density and small-instruction rules; guide-validation script |
| 2.2.0 and 2.2.1 | 10 Nov | Stable line; master generator removed; AI-facing API discovery across all packages; patch removes private research notes from the archive |

Twelve umbrella versions appeared in about 57 days (rc.5 to 2.2.1), seven of them since rc.9.

### 1.2 The stable line

| Package | Version | Documented content |
| --- | --- | --- |
| `cell` | 1.1.0 | Forensic command model (`ApplyCommand`, sealed `ApplyOutcome`); the loosely typed `Cell.apply` retired in favour of `apply<R>(ApplyCommand)`; four non-functional propagation strategies removed; six optimization phases; benchmark suite with a 15% regression gate |
| `cell_flow` | 1.0.0 | Per-activation operator state; race fixes in `ExhaustMapLatest` and `MergeScan`; `Flow` no longer a `CellBase`; 100 public factories; benchmark suite |
| `cell_tissue` | 1.0.0 | Command bridge `TissueBase.apply<R>`; live zero-copy unmodifiable views; positional `principal` in `evolve` factories; 30-result benchmark baseline |
| `mitosis` | 2.2.1 | Umbrella; version now tracks the Mitose pipeline version (2.2); README restructured around Precision Software Engineering and the pipeline |

## 2. What the evidence shows

**1. The stable release is a real engineering step.**
*Documented:* the `cell` changelog reports single-hop emit falling from about 170 µs to about 5 to 6 µs, `Cell.distinct` from about 1.7 ms to about 8 µs, and chain depth 50 from about 8.3 s (described as exponential) to about 12.7 ms (linear). It also reports 1,000 `TissueList.add` calls falling from about 3.2 s to about 56 ms. All four packages score 160 of 160 pub points.
*Reading:* these are the author's own measurements, not independently reproduced. The same changelog states that the remaining overhead against a bare stream is roughly 120 times per hop and publishes a cost ladder explaining it. That candor is a credibility point.

**2. The changelog is candid about latent defects, and that cuts both ways.**
*Documented:* the stable cycle fixed, among others, a branch-completion counter that could fire `onComplete` once per terminal or never; Flow operators whose handles shared timers and accumulators; "unmodifiable" views that were copies rather than live views; and four propagation strategies described as silently non-functional.
*Reading:* this is evidence of rigor in disclosure. It is also evidence that earlier release candidates, which reported about 1,100 tests and above 93% line coverage, still carried defects in exactly the areas the framework is pitched on (integrity, atomicity, lifecycle). Coverage did not equal correctness. The same discipline the pipeline demands of generated code, evidence from executed runs, applies to the framework itself.

**3. Breaking changes landed at the stable boundary.**
*Documented:* `Cell.apply` and `Tissue.apply` were removed; `evolve` factories changed `principal` from named to positional; `PropagationStrategy.exhaust`, `.sample`, `.resilient` and `.retry` were removed; `FlowHandle` lost its generic parameter. `cell` has no 1.0.0 stable release; its first stable version is 1.1.0.
*Reading:* no stable consumer could be broken, because no stable existed. But the earlier roadmap promised an API freeze after the release-candidate cycle, and the final candidate cycle ended with the API still moving.

**4. The agent-facing surface is now machine-checked.**
*Documented:* every top public symbol carries an `### AI Agent Guide` doc block with a pinned `Live signature:`; each package ships a generated API chooser (BRD sentence to factory), a preflight tool that fails on signature drift, doc-comment examples that are compiled and executed in tests, a `seam_test.dart` that enforces the Mitose placement rules inside the package's own suite, and a structured AI failure log (`ai_failure_log.jsonl`) with a stated quarterly review.
*Reading:* this directly answers two risks in the 30 September report (guide-to-source drift and the cold-start problem for agents). It moves the framework's AI strategy from guides that tell an agent what to do toward an API that checks the agent's work.

**5. The process layer is volatile.**
*Documented:* the master document generator appeared in rc.11, was extended in rc.14 and was removed in 2.2.0, roughly a week of life. The README now says every generator is followed individually and that a document produced without following its named generator is invalid. Earlier, the guides were withdrawn in rc.8 and restored in rc.9.
*Reading:* AI-executable scripts are the product's surface, and their structure is still being reshaped release to release. Users of the pipeline cannot yet assume that a guide set stays stable between versions.

**6. The roadmap has been replaced by the pipeline.**
*Documented:* the stable README's Vision section now describes the Mitose pipeline as "the first agentic workflow shipped with the project" and the way the repository is meant to be operated day to day. The Now/Next/Later table and the three phases are absent. The target-domain list is unchanged, and the Honest Caveats now name `cell_organ` as a possible future layer.
*Reading:* I cannot tell whether the roadmap moved to another document. As rendered on pub.dev, the commitments I previously tracked (Flutter adapters, replay, distributed cells) are no longer stated, and their absence is the most informative change for the long-run forecast.

**7. The umbrella version is now a pipeline version.**
*Documented:* `mitosis` 2.2.x tracks `guide/HowTo-Mitose.md` v2.2, while the API packages are 1.x. The `guide/` directory was excluded from the pub.dev archive in rc.9, and no later changelog entry reverses that.
*Reading:* the umbrella's version number now describes content that is not in the package archive. That is workable but easy to misread.

**8. Adoption indicators remain thin.**
*Documented:* pub.dev shows about 1,060 (`mitosis`), 1,030 (`cell`), 1,020 (`cell_flow`) and 970 (`cell_tissue`) downloads, with 0 likes on three packages and 1 on `cell`. Snapshots in October showed roughly 430 to 440. GitHub views, last observed, showed 0 stars, 0 forks, 1 watcher and 1 open pull request.
*Reading:* near-identical counts across four packages that depend on each other are consistent with installs pulled through the dependency chain, CI and mirrors, rather than independent users choosing individual layers. The doubling since October is real but small in absolute terms.

## 3. Scorecard against the 30 September signals

| Signal to watch | Status on 11 November |
| --- | --- |
| Stable 1.0.0 ships and the API freezes | Stable shipped; the freeze was not clean (section 2, item 3) |
| Generated demos are compiled and tested | Partly: the pipeline now always writes a test file and a ledger from executed runs. Whether anyone other than the author runs generated output in CI is not shown |
| Anyone other than the author files an issue or pull request | No evidence; unchanged |
| Flutter adapters from Phase 1 arrive | Not delivered; the phase list no longer appears in the README |
| Pipeline used on a real BRD outside the samples | Samples grew (cafe-coffee, pantry-bridge, saltline-scramble, tide-warden); no outside use evidenced. I did not open the sample outputs |

## 4. Revisions to earlier claims

| Earlier claim | Revised view |
| --- | --- |
| Documentation-led momentum: rc.6 to rc.9 were mostly guides and demos, so the core might not mature at the pace implied | **Superseded.** The stable cycle contained large core changes. The pattern is bursts: a documentation-heavy stretch followed by a large batch of core work |
| Cold start: the pipeline must carry all framework knowledge and may drift from the source | **Partly mitigated** by signature pins, preflight and compiled examples. Adherence of agents across models is still unmeasured |
| The project is moving from library to platform, but only partly | **Stronger form.** The platform commitments are no longer stated; the pipeline is the stated centre of the project |
| A single maintainer is the main bottleneck | **Unchanged.** Throughput is clearly high, but it arrives in bursts, and one person owns the framework, the guides and the release process |
| Agents will use Mitosis to build systems before it orchestrates agents | **Reinforced.** Agent orchestration remains only a target-domain bullet |

## 5. Updated end-game forecast (12-month horizon)

| Scenario | Now | 30 Sep |
| --- | --- | --- |
| Agent-first niche toolkit | 40% | 45% |
| Post-stable stall | 35% | 30% |
| Production graduation | 15% | 25% |
| Methodology spin-out | 10% | (inside the niche scenario) |

Treat each figure as plus or minus ten points. Projects with a single maintainer, zero stars and about a thousand downloads rarely reach broad adoption; I have not quantified that base rate, but it is the reason the stall scenario is not lower.

### 40%: agent-first niche toolkit

A small group uses the pipeline to generate governed reactive prototypes and small services. The framework remains Dart-only, stays maintained at a reduced cadence, and is known mainly for its approach to AI-assisted development rather than for state management. By November 2027 there are a handful of outside users and perhaps a few external issues.

### 35%: post-stable stall

The stable release is the natural completion point of a self-set milestone. After it, releases thin out and the repository goes quiet. The documentation stays extensive and the work is treated as finished. Several things raise this above the 30 September figure: the burst cadence is hard to sustain, about ten weeks of public releases have produced no visible outside engagement, and the removal of the roadmap removes forward commitments that would have kept the project moving.

### 15%: production graduation

Outside teams ship systems on it, contributors appear, and the integrity engine gets independent review. This falls from 25% because the roadmap items that would have carried it (replay, distributed cells, Flutter bindings) are no longer stated, the transaction and compensation engine was rewritten in the final release without independent audit, and no outside users are visible. It does not fall further because the technical floor rose materially: benchmarks with regression gates, a 160/160 pub score and stable version labels.

### 10%: methodology spin-out

The pipeline's method (a requirements gate, an executed-evidence ledger, numbered change files) is adopted or imitated beyond Dart, while Mitosis itself stays obscure. The method is written as portable Markdown scripts and has a coined name, so it is separable from the framework. I found no external reference to it, which keeps this low.

## 6. Risks specific to this milestone

- **An unaudited integrity engine, changed at the last moment.** Earlier release-candidate notes stated that no independent correctness or security review had occurred and that transaction and compensation internals had not been independently reviewed end to end. I found no evidence of a review since, yet the command model and `txApply` behavior changed in 1.1.0. The README is careful to say `Context` metadata is not a compliance certification, but the target domains (payments, safety telemetry, energy) are exactly where such review matters.
- **Self-reported evidence.** Benchmarks, test counts and the pipeline-versus-vibe-coding comparison table are all authored and run by the maintainer.
- **Process-layer churn.** See section 2, item 5. There is no published pass rate for the pipeline across models; the README itself describes it as "agentic tooling, not a validated code-generation service".
- **Distribution channel.** The pipeline lives in the GitHub repository, not in the package archive. During this assessment automated retrieval of some GitHub pages (commit history, tags and the guide directory) was refused, although individual file pages loaded. The pipeline's lookup order checks the workspace first, so the effect may be small, but agents without workspace copies could meet friction.
- **Release hygiene.** The 2.2.1 patch removed a private `research/` notes directory that the 2.2.0 archive had shipped. Both are listed as stable versions.
- **Positioning mismatch.** pub.dev topics still list `state-management`, while the README states the project is not "another state-management library". Discoverability and positioning point in different directions.
- **Roadmap vacuum.** Without stated future commitments, neither users nor assessors can tell what the project is heading toward beyond the pipeline.

## 7. Intention of the author

The September assessment described a long-horizon, opinionated runtime for systems where causality and auditability are non-negotiable, plus a practical second intent: making that framework usable by people who will not learn its vocabulary. The stable release adds a third, clearer signal. Doc comments written for machines, pinned signatures, executable examples and a failure log all treat an AI coding agent as the primary reader of the API. The coined term Precision Software Engineering and the explicit contrast with vibe coding place the project in the AI-assisted development conversation rather than the Flutter state-management one. The most likely reading is that the framework is now the substrate and the pipeline is the product, with the older platform ambitions deferred rather than abandoned. That reading is an inference; the repository does not say it.

## 8. Signals to watch

| Signal | Effect on the forecast |
| --- | --- |
| First issue, pull request, discussion or public dependent from anyone other than the author | Moves roughly 5 to 10 points from stall to niche |
| An independent run of the pipeline on a third-party BRD, with the ledger published | Moves niche up and starts to make graduation plausible |
| An independent review of `txApply` and compensation, or independent reproduction of the benchmark baselines | Raises graduation |
| Another structural rewrite of the guides within 90 days (as with the master generator) | Raises stall; signals the method is not yet settled |
| A published evaluation of the pipeline across models, with pass rates on the sample BRDs | Raises niche and spin-out |
| Whether the first quarterly review of `ai_failure_log.jsonl` happens (due around early 2027) and whether entries exist | Tests whether the feedback loop is a practice or a promise |
| A written position on Flutter bindings and on replay and distributed cells | Restores or retires the commitments that were dropped |
| A fourth layer (`cell_organ` or another) appearing before outside users exist | Would indicate scope outrunning adoption |

## 9. Conclusion

The stable release closes the gap the earlier reports identified in engineering maturity: a hardened core, pinned and executable documentation, benchmark gates and stable labels. It does not close the gap in adoption evidence, which is the one that decides the end game. The forecast shifts from a possible platform toward a narrower and better-defined outcome: a governed-reactive toolkit built to be operated by AI agents, with the pipeline as its main claim. The clearest test over the next six months is not another release but a first independent user, and an independent check on the integrity engine that the framework's own pitch depends on.

## Basis and limitations

- **Primary sources:** pub.dev changelogs, version lists, scores and READMEs for `mitosis`, `cell`, `cell_flow` and `cell_tissue`. Statements about the 2.2 pipeline come from the umbrella README and changelog on pub.dev, not from the guide files themselves.
- **Stale or partial GitHub views:** the repository pages retrieved for this assessment were cached or partial. The README showed rc.5, the CHANGELOG showed rc.9 as newest, and `HowTo-Mitose.md` appeared in its 1.0 form. Commit history, tags and the guide directory could not be retrieved. Stars, forks and watchers are last-observed values and may be out of date.
- **Not reviewed:** the guide files for the 2.x pipeline, the sample outputs, the source code, and the benchmark runs. Benchmark and test figures are quoted from changelogs as reported, not reproduced.
- **Approximations:** release dates are derived from relative ages on pub.dev. Download counts include CI, mirrors and the author's own installs, and the counting window is not stated on the pages.
- **Estimates:** every probability in this document is my own judgment and should be updated as the signals above resolve.