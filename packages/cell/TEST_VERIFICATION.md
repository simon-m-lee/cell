# cell package - Test Verification Report

**Generated:** 2026-11-19
**Package:** cell (v2.0.0)
**Test Files Analyzed:** 75
**Total Tests:** 1426 (0 skipped)

---

## Table of contents

- [Executive Summary](#executive-summary)
  - [Snapshot](#snapshot)
  - [Quick Stats](#quick-stats)
- [Test File Inventory](#test-file-inventory)
- [Source Under Test (`lib/`)](#source-under-test-lib)
- [Detailed Test Coverage](#detailed-test-coverage)
  - [ai_guide_examples_test.dart](#file-1-ai_guide_examples_test.dart-3-tests)
  - [ai_preflight_test.dart](#file-2-ai_preflight_test.dart-1-tests)
  - [api_chooser_up_to_date_test.dart](#file-3-api_chooser_up_to_date_test.dart-1-tests)
  - [apply_command_test.dart](#file-4-apply_command_test.dart-12-tests)
  - [cell_policy_test.dart](#file-5-cell_policy_test.dart-39-tests)
  - [cell_test.dart](#file-6-cell_test.dart-78-tests)
  - [commons_test.dart](#file-7-commons_test.dart-49-tests)
  - [context_test.dart](#file-8-context_test.dart-117-tests)
  - [deputy_test.dart](#file-9-deputy_test.dart-26-tests)
  - [instruction_test.dart](#file-10-instruction_test.dart-23-tests)
  - [nucleus_test.dart](#file-11-nucleus_test.dart-40-tests)
  - [operator_async_map_test.dart](#file-12-operator_async_map_test.dart-2-tests)
  - [operator_from_stream_test.dart](#file-13-operator_from_stream_test.dart-3-tests)
  - [operators_advanced_transactions_test.dart](#file-14-operators_advanced_transactions_test.dart-39-tests)
  - [operators_async_routing_test.dart](#file-15-operators_async_routing_test.dart-63-tests)
  - [operators_flow_control_test.dart](#file-16-operators_flow_control_test.dart-45-tests)
  - [operators_foundation_test.dart](#file-17-operators_foundation_test.dart-65-tests)
  - [propagation_policy_test.dart](#file-18-propagation_policy_test.dart-37-tests)
  - [pulse_test.dart](#file-19-pulse_test.dart-159-tests)
  - [receptor_instruction_future_test.dart](#file-20-receptor_instruction_future_test.dart-2-tests)
  - [receptor_test.dart](#file-21-receptor_test.dart-54-tests)
  - [cli_test.dart](#file-22-cli_test.dart-15-tests)
  - [canonical_json_test.dart](#file-23-canonical_json_test.dart-13-tests)
  - [context_roundtrip_test.dart](#file-24-context_roundtrip_test.dart-8-tests)
  - [fastpulse_rejected_test.dart](#file-25-fastpulse_rejected_test.dart-4-tests)
  - [pulse_codec_test.dart](#file-26-pulse_codec_test.dart-20-tests)
  - [pulse_from_json_overrides_test.dart](#file-27-pulse_from_json_overrides_test.dart-19-tests)
  - [pulse_from_json_test.dart](#file-28-pulse_from_json_test.dart-9-tests)
  - [pulse_roundtrip_test.dart](#file-29-pulse_roundtrip_test.dart-7-tests)
  - [pulse_sentinel_test.dart](#file-30-pulse_sentinel_test.dart-4-tests)
  - [pulse_to_json_test.dart](#file-31-pulse_to_json_test.dart-3-tests)
  - [snapshot_roundtrip_test.dart](#file-32-snapshot_roundtrip_test.dart-9-tests)
  - [cycle_checker_reseeded_test.dart](#file-33-cycle_checker_reseeded_test.dart-1-tests)
  - [divergence_effect_mismatch_test.dart](#file-34-divergence_effect_mismatch_test.dart-2-tests)
  - [divergence_missing_effect_test.dart](#file-35-divergence_missing_effect_test.dart-1-tests)
  - [divergence_pure_receptor_test.dart](#file-36-divergence_pure_receptor_test.dart-2-tests)
  - [pulse_codec_integration_test.dart](#file-37-pulse_codec_integration_test.dart-5-tests)
  - [pulses_500_replay_test.dart](#file-38-pulses_500_replay_test.dart-1-tests)
  - [replay_identical_graph_test.dart](#file-39-replay_identical_graph_test.dart-3-tests)
  - [fork_at_seq_test.dart](#file-40-fork_at_seq_test.dart-2-tests)
  - [fork_isolation_test.dart](#file-41-fork_isolation_test.dart-1-tests)
  - [fork_verify_requires_original_test.dart](#file-42-fork_verify_requires_original_test.dart-3-tests)
  - [whatif_replace_pulse_test.dart](#file-43-whatif_replace_pulse_test.dart-2-tests)
  - [effectful_testcell_replayed_test.dart](#file-44-effectful_testcell_replayed_test.dart-2-tests)
  - [ephemeral_policy_tick_order_test.dart](#file-45-ephemeral_policy_tick_order_test.dart-2-tests)
  - [readonlyexternal_testcell_reexecuted_test.dart](#file-46-readonlyexternal_testcell_reexecuted_test.dart-2-tests)
  - [version_boundary_without_translator_test.dart](#file-47-version_boundary_without_translator_test.dart-4-tests)
  - [version_dispatch_test.dart](#file-48-version_dispatch_test.dart-6-tests)
  - [graph_snapshot_restore_test.dart](#file-49-graph_snapshot_restore_test.dart-4-tests)
  - [id_uniqueness_test.dart](#file-50-id_uniqueness_test.dart-5-tests)
  - [purity_classification_test.dart](#file-51-purity_classification_test.dart-6-tests)
  - [registration_test.dart](#file-52-registration_test.dart-4-tests)
  - [unregistered_bind_rejected_test.dart](#file-53-unregistered_bind_rejected_test.dart-4-tests)
  - [async_map_records_effects_test.dart](#file-54-async_map_records_effects_test.dart-1-tests)
  - [debounce_timer_order_test.dart](#file-55-debounce_timer_order_test.dart-2-tests)
  - [from_stream_ordering_test.dart](#file-56-from_stream_ordering_test.dart-2-tests)
  - [null_journal_rejects_effectful_test.dart](#file-57-null_journal_rejects_effectful_test.dart-5-tests)
  - [pure_receptor_no_journal_test.dart](#file-58-pure_receptor_no_journal_test.dart-3-tests)
  - [reordered_effects_diverge_test.dart](#file-59-reordered_effects_diverge_test.dart-7-tests)
  - [append_and_verify_test.dart](#file-60-append_and_verify_test.dart-2-tests)
  - [append_outside_apply_rejected_test.dart](#file-61-append_outside_apply_rejected_test.dart-6-tests)
  - [file_store_roundtrip_test.dart](#file-62-file_store_roundtrip_test.dart-2-tests)
  - [state_delta_capture_test.dart](#file-63-state_delta_capture_test.dart-5-tests)
  - [tamper_detection_test.dart](#file-64-tamper_detection_test.dart-3-tests)
  - [ledger_store_conformance.dart](#file-65-ledger_store_conformance.dart-6-tests)
  - [replay_contract_test.dart](#file-66-replay_contract_test.dart-0-tests)
  - [review_hardening_test.dart](#file-67-review_hardening_test.dart-35-tests)
  - [seam_test.dart](#file-68-seam_test.dart-2-tests)
  - [synapses_test.dart](#file-69-synapses_test.dart-75-tests)
  - [synthesis_cell_test.dart](#file-70-synthesis_cell_test.dart-37-tests)
  - [test_cell_test.dart](#file-71-test_cell_test.dart-45-tests)
  - [test_chain_test.dart](#file-72-test_chain_test.dart-4-tests)
  - [test_rule_meta_test.dart](#file-73-test_rule_meta_test.dart-49-tests)
  - [transaction_test.dart](#file-74-transaction_test.dart-55-tests)
  - [tx_apply_test.dart](#file-75-tx_apply_test.dart-49-tests)
- [Runtime Verification Status](#runtime-verification-status)
  - [Last `dart test`](#last-dart-test)
  - [Line Coverage (`lib/`)](#line-coverage-lib)
- [Recommendations](#recommendations)
- [Appendix: File Locations](#appendix-file-locations)

---

## Executive Summary

The cell test suite contains **1426 unit tests** across **75 files** in `test/`. Counts are `test(` declarations.

The library under test is **85 source files** in `lib/`: **35** under `lib/src/` (core engine), **46** under `lib/replay/` (Causal Replay module), and **4** top-level barrel(s).

This file is **generated**. Edit the script flags or the stub sections at the bottom; do not hand-count `test(`.

### Snapshot

Last `dart test` is **green**: **1431 passed**, 0 failed (exit 0).

`lib/` line coverage is **93.5%** (3586 / 3836).

No `lib/` file is below 70% in this lcov.

### Quick Stats

| Metric | Value |
|--------|-------|
| **Total Test Files** | 75 |
| **Total Tests** | 1426 |
| **Skipped** | 0 |
| **Last full run** | 1431 passed, 0 failed, 0 skipped (exit 0) |
| **Test Groups** | 276 (`group(` declarations) |
| **Async-ish tests** | ~502 (heuristic) |
| **Line coverage (`lib/`)** | **93.5%** (3586 / 3836) |

---

## Test File Inventory

| # | File | Lines | Tests | Size | Focus |
|---|------|------:|------:|------:|-------|
| 1 | ai_guide_examples_test.dart | 46 | 3 | 1.9 KB | ai guide examples test |
| 2 | ai_preflight_test.dart | 22 | 1 | 0.8 KB | ai preflight test |
| 3 | api_chooser_up_to_date_test.dart | 27 | 1 | 1.0 KB | api chooser up to date test |
| 4 | apply_command_test.dart | 283 | 12 | 8.8 KB | apply command test; groups: Apply command model |
| 5 | cell_policy_test.dart | 646 | 39 | 21.8 KB | cell policy test; groups: EphemeralPolicy, Construction, call / events, eventLimit, TTL, combined TTL and eventLimit… |
| 6 | cell_test.dart | 1,264 | 78 | 45.0 KB | cell test; groups: Cell, Factory Constructors, Identity & Equality, Apply, Modifiable, Terminal & State… |
| 7 | commons_test.dart | 509 | 49 | 15.6 KB | commons test; groups: mapMerge, SyncSet, QueueList, AsyncQueueList, PriorityQueue, AsyncPriorityQueue… |
| 8 | context_test.dart | 1,636 | 117 | 62.4 KB | context test; groups: GovernanceEntry, Ontology, Context, system, describe, primary constructor… |
| 9 | deputy_test.dart | 352 | 26 | 11.9 KB | deputy test; groups: Cell.deputy, identity, testRule layering, apply forwarding, unmodifiable, causal integrity… |
| 10 | instruction_test.dart | 361 | 23 | 12.4 KB | instruction test; groups: Instruction, Construction, Composition, Instruction.future, Custom Instruction, Receptor integration |
| 11 | nucleus_test.dart | 366 | 40 | 12.6 KB | nucleus test; groups: Nucleus, empty / Nucleolus, Construction & defaults, Nucleus.create, Activation, evolve… |
| 12 | operator_async_map_test.dart | 100 | 2 | 2.8 KB | operator async map test; groups: Cell.asyncMap latestOnly with concurrency=1 |
| 13 | operator_from_stream_test.dart | 120 | 3 | 3.4 KB | operator from stream test; groups: Cell.fromStream + EphemeralPolicy |
| 14 | operators_advanced_transactions_test.dart | 800 | 39 | 25.1 KB | operators advanced transactions test; groups: Advanced & Transactions, Cell.sanitized, Cell.open, Combined Operators, Edge Cases & Error Handling, toString |
| 15 | operators_async_routing_test.dart | 1,133 | 63 | 36.2 KB | operators async routing test; groups: Async & Routing Operators, Cell.asyncMap, Cell.hub, Cell.switchMap, Cell.fromFuture, Cell.fromStream… |
| 16 | operators_flow_control_test.dart | 838 | 45 | 25.6 KB | operators flow control test; groups: Flow Control Operators, Cell.debounce, Cell.throttle, Cell.distinct, Cell.synthesis, Combined Operators… |
| 17 | operators_foundation_test.dart | 1,066 | 65 | 37.3 KB | operators foundation test; groups: Cell.state, Basic State, State with evolve, Ingest, Edge Cases, Cell.ingress… |
| 18 | propagation_policy_test.dart | 680 | 37 | 24.9 KB | propagation policy test; groups: PropagationPolicy, Construction & Defaults, Strategy: immediate, Strategy: debounced, Strategy: throttled, Strategy: batched… |
| 19 | pulse_test.dart | 1,908 | 159 | 71.2 KB | pulse test; groups: Pulse, Construction, withStep vs evolve distinction, Evolution, Composition, Shell… |
| 20 | receptor_instruction_future_test.dart | 84 | 2 | 2.5 KB | receptor instruction future test; groups: Receptor.pipeline with Instruction.future + postProcess |
| 21 | receptor_test.dart | 782 | 54 | 28.1 KB | receptor test; groups: Receptor, passThrough, Construction, Activation & clone, Pipeline, Instruction composition… |
| 22 | cli_test.dart | 334 | 15 | 10.8 KB | cli test |
| 23 | canonical_json_test.dart | 144 | 13 | 4.7 KB | canonical json test; groups: canonicalJsonEncode, fingerprint, barrel surface |
| 24 | context_roundtrip_test.dart | 190 | 8 | 6.4 KB | context roundtrip test; groups: PulseContextCodec round-trip, PulseContextCodec failures |
| 25 | fastpulse_rejected_test.dart | 75 | 4 | 2.9 KB | fastpulse rejected test; groups: materialise boundary |
| 26 | pulse_codec_test.dart | 245 | 20 | 7.7 KB | pulse codec test; groups: encodePulse — non-serializable fields, decodePulse — decode failures, encodePulse — round-trips, canonicality |
| 27 | pulse_from_json_overrides_test.dart | 187 | 19 | 5.7 KB | pulse from json overrides test; groups: Pulse.fromJson — overrides |
| 28 | pulse_from_json_test.dart | 130 | 9 | 4.1 KB | pulse from json test; groups: Pulse.fromJson — the factory without overrides |
| 29 | pulse_roundtrip_test.dart | 206 | 7 | 6.6 KB | pulse roundtrip test; groups: PulseCodec round-trip |
| 30 | pulse_sentinel_test.dart | 58 | 4 | 2.0 KB | pulse sentinel test; groups: override sentinels |
| 31 | pulse_to_json_test.dart | 39 | 3 | 1.3 KB | pulse to json test; groups: Pulse.toJson extension |
| 32 | snapshot_roundtrip_test.dart | 126 | 9 | 4.2 KB | snapshot roundtrip test; groups: CellSnapshot, CellGraphSnapshot, Cell.id |
| 33 | cycle_checker_reseeded_test.dart | 76 | 1 | 2.5 KB | cycle checker reseeded test |
| 34 | divergence_effect_mismatch_test.dart | 123 | 2 | 3.5 KB | divergence effect mismatch test |
| 35 | divergence_missing_effect_test.dart | 86 | 1 | 2.5 KB | divergence missing effect test |
| 36 | divergence_pure_receptor_test.dart | 85 | 2 | 2.7 KB | divergence pure receptor test |
| 37 | pulse_codec_integration_test.dart | 106 | 5 | 3.6 KB | pulse codec integration test; groups: pulse codec in the replay engine |
| 38 | pulses_500_replay_test.dart | 61 | 1 | 2.1 KB | pulses 500 replay test |
| 39 | replay_identical_graph_test.dart | 97 | 3 | 3.0 KB | replay identical graph test |
| 40 | fork_at_seq_test.dart | 88 | 2 | 3.1 KB | fork at seq test |
| 41 | fork_isolation_test.dart | 65 | 1 | 2.0 KB | fork isolation test |
| 42 | fork_verify_requires_original_test.dart | 157 | 3 | 4.5 KB | fork verify requires original test |
| 43 | whatif_replace_pulse_test.dart | 113 | 2 | 3.8 KB | whatif replace pulse test |
| 44 | effectful_testcell_replayed_test.dart | 92 | 2 | 3.1 KB | effectful testcell replayed test |
| 45 | ephemeral_policy_tick_order_test.dart | 91 | 2 | 3.1 KB | ephemeral policy tick order test |
| 46 | readonlyexternal_testcell_reexecuted_test.dart | 95 | 2 | 3.0 KB | readonlyexternal testcell reexecuted test |
| 47 | version_boundary_without_translator_test.dart | 195 | 4 | 6.6 KB | version boundary without translator test |
| 48 | version_dispatch_test.dart | 139 | 6 | 4.1 KB | version dispatch test |
| 49 | graph_snapshot_restore_test.dart | 101 | 4 | 3.7 KB | graph snapshot restore test |
| 50 | id_uniqueness_test.dart | 57 | 5 | 1.9 KB | id uniqueness test |
| 51 | purity_classification_test.dart | 82 | 6 | 3.0 KB | purity classification test |
| 52 | registration_test.dart | 40 | 4 | 1.2 KB | registration test |
| 53 | unregistered_bind_rejected_test.dart | 61 | 4 | 2.2 KB | unregistered bind rejected test |
| 54 | async_map_records_effects_test.dart | 94 | 1 | 3.2 KB | async map records effects test |
| 55 | debounce_timer_order_test.dart | 132 | 2 | 4.1 KB | debounce timer order test |
| 56 | from_stream_ordering_test.dart | 66 | 2 | 2.1 KB | from stream ordering test |
| 57 | null_journal_rejects_effectful_test.dart | 96 | 5 | 2.9 KB | null journal rejects effectful test |
| 58 | pure_receptor_no_journal_test.dart | 47 | 3 | 1.5 KB | pure receptor no journal test |
| 59 | reordered_effects_diverge_test.dart | 170 | 7 | 4.9 KB | reordered effects diverge test |
| 60 | append_and_verify_test.dart | 47 | 2 | 1.5 KB | append and verify test |
| 61 | append_outside_apply_rejected_test.dart | 134 | 6 | 4.4 KB | append outside apply rejected test |
| 62 | file_store_roundtrip_test.dart | 88 | 2 | 3.1 KB | file store roundtrip test |
| 63 | state_delta_capture_test.dart | 122 | 5 | 4.1 KB | state delta capture test |
| 64 | tamper_detection_test.dart | 163 | 3 | 4.7 KB | tamper detection test |
| 65 | ledger_store_conformance.dart | 189 | 6 | 5.9 KB | ledger store conformance; groups: $suiteName conformance |
| 66 | replay_contract_test.dart | 50 | 0 | 1.6 KB | replay contract test |
| 67 | review_hardening_test.dart | 1,244 | 35 | 41.4 KB | review hardening test |
| 68 | seam_test.dart | 46 | 2 | 1.7 KB | seam test |
| 69 | synapses_test.dart | 1,136 | 75 | 37.3 KB | synapses test; groups: Synapses, disabled, enabled, Construction & broadcast, link / unlink, FilterRule… |
| 70 | synthesis_cell_test.dart | 627 | 37 | 21.0 KB | synthesis cell test; groups: SynthesisCell, Construction, Aggregation, Source Management, Stop/Start, Edge Cases & Error Handling… |
| 71 | test_cell_test.dart | 665 | 45 | 23.0 KB | cell test; groups: TestCell, allowAll, readOnly, Construction, Composition, Exceptions… |
| 72 | test_chain_test.dart | 84 | 4 | 2.8 KB | chain test; groups: TestCell.chain preserves parent when strategy is null, TestRule.chain preserves user when strategy is set, TestRule.chain preserves parent when strategy is null |
| 73 | test_rule_meta_test.dart | 366 | 49 | 12.2 KB | rule meta test; groups: DefaultValue, MaxLength, direct field limit, hostLength, composite field + container, host-only… |
| 74 | transaction_test.dart | 1,227 | 55 | 36.6 KB | transaction test; groups: Cell.transaction, Basic Transaction, Isolation Levels, Lock Ordering, Validation, Custom Apply… |
| 75 | tx_apply_test.dart | 1,140 | 49 | 35.7 KB | tx apply test; groups: Cell.txApply, Basic Operations, Compensation, Error Handling, Stop On First Failure, Savepoint… |
| **Total** | | **24,700** | **1426** | **829.0 KB** | |

---

## Source Under Test (`lib/`)

Both halves of the package are inventoried: `lib/src/` (the core engine) and `lib/replay/` (the Causal Replay module), plus the top-level barrels.

| Area | Files | Lines | Size |
|------|------:|------:|-----:|
| `lib/src/` — core engine | 35 | 31,269 | 1223.2 KB |
| `lib/replay/` — Causal Replay | 46 | 9,100 | 337.2 KB |
| top-level barrels | 4 | 431 | 28.6 KB |

| File | Lines | Size |
|------|------:|-----:|
| `lib/cell.dart` | 260 | 10.6 KB |
| `lib/doc/ai_anti_patterns.dart` | 73 | 3.4 KB |
| `lib/doc/api_chooser.dart` | 53 | 12.7 KB |
| `lib/replay/cli/cli.dart` | 695 | 22.5 KB |
| `lib/replay/codec/canonical_json.dart` | 140 | 4.8 KB |
| `lib/replay/codec/cell_snapshot.dart` | 89 | 3.4 KB |
| `lib/replay/codec/fingerprint.dart` | 41 | 1.5 KB |
| `lib/replay/codec/graph_snapshot.dart` | 121 | 4.7 KB |
| `lib/replay/codec/pulse_codec.dart` | 820 | 28.8 KB |
| `lib/replay/codec/pulse_context_codec.dart` | 238 | 9.2 KB |
| `lib/replay/engine/divergence.dart` | 80 | 3.0 KB |
| `lib/replay/engine/reconstruct_pulse.dart` | 133 | 5.2 KB |
| `lib/replay/engine/replay_engine.dart` | 543 | 22.5 KB |
| `lib/replay/engine/replay_engine_fork.dart` | 337 | 12.4 KB |
| `lib/replay/engine/replay_options.dart` | 98 | 4.2 KB |
| `lib/replay/engine/replay_result.dart` | 69 | 2.8 KB |
| `lib/replay/fork/cell_graph_fork.dart` | 163 | 6.5 KB |
| `lib/replay/fork/fork.dart` | 64 | 2.4 KB |
| `lib/replay/fork/fork_ledger_store.dart` | 189 | 6.4 KB |
| `lib/replay/fork/fork_policy.dart` | 43 | 1.8 KB |
| `lib/replay/fork/fork_record.dart` | 115 | 4.5 KB |
| `lib/replay/fork/fork_verify.dart` | 166 | 5.7 KB |
| `lib/replay/fork/mutation.dart` | 54 | 2.6 KB |
| `lib/replay/governance/context_translator.dart` | 143 | 5.4 KB |
| `lib/replay/governance/policy_replay.dart` | 79 | 3.3 KB |
| `lib/replay/governance/testcell_replay.dart` | 127 | 4.9 KB |
| `lib/replay/governance/version_registry.dart` | 148 | 5.6 KB |
| `lib/replay/graph/cell_graph.dart` | 353 | 14.2 KB |
| `lib/replay/graph/cell_graph_builder.dart` | 184 | 6.8 KB |
| `lib/replay/graph/cell_graph_registry.dart` | 41 | 1.6 KB |
| `lib/replay/graph/purity.dart` | 60 | 2.6 KB |
| `lib/replay/graph/registered_cell.dart` | 65 | 2.6 KB |
| `lib/replay/graph/registry.dart` | 102 | 4.2 KB |
| `lib/replay/journal/effect_journal.dart` | 329 | 12.6 KB |
| `lib/replay/journal/effect_record.dart` | 398 | 13.4 KB |
| `lib/replay/journal/effectful.dart` | 76 | 3.4 KB |
| `lib/replay/journal/journal_scope.dart` | 133 | 5.4 KB |
| `lib/replay/journal/recording_journal.dart` | 226 | 7.3 KB |
| `lib/replay/journal/replay_journal.dart` | 393 | 14.0 KB |
| `lib/replay/ledger/file_store.dart` | 180 | 6.2 KB |
| `lib/replay/ledger/hash_chain.dart` | 87 | 3.3 KB |
| `lib/replay/ledger/in_memory_store.dart` | 79 | 2.4 KB |
| `lib/replay/ledger/ledger.dart` | 302 | 11.1 KB |
| `lib/replay/ledger/ledger_entry.dart` | 360 | 14.1 KB |
| `lib/replay/ledger/ledger_scope.dart` | 512 | 18.5 KB |
| `lib/replay/ledger/ledger_store.dart` | 76 | 3.2 KB |
| `lib/replay/ledger/state_delta.dart` | 130 | 5.6 KB |
| `lib/replay/replay.dart` | 131 | 4.5 KB |
| `lib/replay/visualise.dart` | 188 | 6.0 KB |
| `lib/replay.dart` | 45 | 2.0 KB |
| `lib/src/apply.dart` | 635 | 28.5 KB |
| `lib/src/cell.dart` | 3,007 | 143.7 KB |
| `lib/src/context.dart` | 1,918 | 75.2 KB |
| `lib/src/deputy.dart` | 175 | 7.4 KB |
| `lib/src/internal/cell.dart` | 1,170 | 46.7 KB |
| `lib/src/internal/cell_policy.dart` | 455 | 17.3 KB |
| `lib/src/internal/commons.dart` | 1,338 | 50.3 KB |
| `lib/src/internal/context.dart` | 461 | 14.1 KB |
| `lib/src/internal/deputy.dart` | 166 | 6.4 KB |
| `lib/src/internal/deputy_context.dart` | 1,696 | 64.3 KB |
| `lib/src/internal/nucleus.dart` | 1,160 | 41.2 KB |
| `lib/src/internal/operator/operator_async_map.dart` | 295 | 12.2 KB |
| `lib/src/internal/operator/operator_debounce.dart` | 158 | 5.5 KB |
| `lib/src/internal/operator/operator_hub.dart` | 479 | 17.4 KB |
| `lib/src/internal/operator/operator_stream_future.dart` | 261 | 10.6 KB |
| `lib/src/internal/operator/operator_throttle.dart` | 165 | 5.5 KB |
| `lib/src/internal/operator/operator_transaction.dart` | 1,032 | 36.8 KB |
| `lib/src/internal/operator/operator_tx_apply.dart` | 907 | 35.2 KB |
| `lib/src/internal/operator/operators.dart` | 494 | 19.3 KB |
| `lib/src/internal/pulse.dart` | 2,694 | 93.8 KB |
| `lib/src/internal/pulse_context.dart` | 1,758 | 67.5 KB |
| `lib/src/internal/pulse_extensions.dart` | 270 | 10.8 KB |
| `lib/src/internal/pulse_policy.dart` | 300 | 10.9 KB |
| `lib/src/internal/receptor.dart` | 1,416 | 55.1 KB |
| `lib/src/internal/synapses.dart` | 1,837 | 63.6 KB |
| `lib/src/internal/test_cell.dart` | 157 | 5.5 KB |
| `lib/src/internal/value.dart` | 171 | 6.7 KB |
| `lib/src/nucleus.dart` | 516 | 23.8 KB |
| `lib/src/pulse.dart` | 1,320 | 53.4 KB |
| `lib/src/receptor.dart` | 1,237 | 52.2 KB |
| `lib/src/synapses.dart` | 420 | 15.7 KB |
| `lib/src/test_cell.dart` | 1,041 | 41.8 KB |
| `lib/src/test_rule.dart` | 602 | 25.3 KB |
| `lib/src/test_rule_meta.dart` | 603 | 20.8 KB |
| `lib/src/value.dart` | 955 | 38.9 KB |

---

## Detailed Test Coverage

Generated from `group(` / `test(` names. Tighten the prose by hand if needed.

### File 1: ai_guide_examples_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |

**Tests**

- generated AI guide example file is up to date
- every minimal example compiles under dart analyze
- every minimal example runs and exits 0

### File 2: ai_preflight_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- all doc-comment and HowTo pins match resolved versions

### File 3: api_chooser_up_to_date_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- lib/doc/api_chooser.dart is generated and up to date

### File 4: apply_command_test.dart (12 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 12 |
| Apply command model | |

**Tests**

- execute accepts a command and returns its typed result
- receipt carries forensic provenance
- gate rejection returns ApplyRejected
- the gate receives the complete command including compensation
- unvetted functions execute but the receipt records it
- tx staging returns ApplyStaged with a sequence and commits
- async gate returns a Future outcome
- builder DSL assembles and runs a command
- builder DSL attaches a compensation blueprint
- deputy execute forwards to the principal
- async execute returns a Future outcome
- ApplyVeto soft-reject is honored at commit

### File 5: cell_policy_test.dart (39 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 39 |
| EphemeralPolicy | |
| Construction | |
| call / events | |
| eventLimit | |
| TTL | |
| combined TTL and eventLimit | |
| mask | |
| cell integration | |

**Tests**

- stores duration and leaves eventLimit unset
- stores eventLimit and leaves duration unset
- stores duration and eventLimit together
- allows a tracking-only policy with no TTL or quota
- stores user metadata for onEvent
- omitted user is null in onEvent
- forwards the interaction object to onEvent
- forwards the host cell to onEvent
- forwards call arguments to onEvent
- updates the events counter from onEvent
- ignores an event when onEvent returns a negative count
- returning zero is a counted event and stores 0
- does not invoke onEvent after the cell is reclaimed
- does not reclaim below the threshold
- reclaims when the counter reaches the limit
- reclaims on the first counted event when eventLimit is 1
- resetting the counter avoids the quota
- failed onInvalidate leaves the cell alive for a later retry
- without an eventLimit the counter never reclaims
- does not start the timer until the first interaction
- reclaims after duration from the first interaction
- does not restart the TTL on later interactions
- dispose cancels a pending TTL
- a declined eventLimit reclamation keeps the TTL timer alive
- TTL is a no-op if the cell was already reclaimed
- event quota can reclaim before the TTL
- TTL can reclaim before the event quota
- bit 0: callbacks only
- bit 1: eventLimit
- bit 2: duration
- bit 3: eventLimit and duration
- bit 4: user
- bit 5: eventLimit and user
- bit 6: duration and user
- bit 7: eventLimit, duration, and user
- an unused hosted policy does not invalidate the cell
- Cell and Nucleus follow a hosted policy after reclamation
- a deputy without its own policy follows the principal
- two policies keep independent event counters

### File 6: cell_test.dart (78 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 78 |
| Cell | |
| Factory Constructors | |
| Identity & Equality | |
| Apply | |
| Modifiable | |
| Terminal & State | |
| Deputy | |
| Async | |
| Unmodifiable | |
| §3 unmodifiable | |
| Validation | |
| Context | |
| Ephemeral Policy | |
| Cell.valve | |
| OpenCell.perform | |
| toString | |

**Tests**

- Cell() creates a basic cell with defaults
- Cell() with custom receptor
- Cell.governed creates a governed cell
- Cell.governed with ephemeral policy
- Cell.fromNucleus creates a cell from a nucleus
- two distinct cells are not equal
- cell is equal to its deputy
- hashCode walks nested deputy principals
- cell identity preserved in sets
- apply executes a whitelisted function
- apply with positional arguments
- apply awaits an async testRule and runs when allowed
- apply awaits an async testRule and returns null when denied
- apply with named arguments
- apply returns function result
- apply with testRule blocks unauthorized actions
- modifiable returns list of whitelisted functions
- read-only cell has modifiable list
- isTerminal returns true for cells with disabled synapses
- isTerminal returns false for cells with enabled synapses
- isInvalidated returns false for active cells
- isGoverned returns true for cells with custom context
- isGoverned returns false for cells with system context
- deputy returns itself when no changes requested
- deputy creates a new instance with custom testRule
- deputy with custom context
- deputy with ephemeral policy
- deputy equality with principal
- deputy of a deputy
- async.apply executes function asynchronously
- async.apply with positional arguments
- async.apply with named arguments
- async.apply returns function result
- async.apply without a lock still completes
- async.apply with lock serialization
- Modifiable is a const marker
- unmodifiable returns a read-only deputy for CustomCell
- unmodifiable for value cell is read-only
- unmodifiable for deputy returns principal unmodifiable
- value setter throws; principal unchanged
- apply() on unmodifiable is rejected
- read-only deputy still accepts observations and produces 
- _CellDeputy no longer bypasses chained testRule
- read-only deputy gates apply and seals direct value writes; 
- unmodifiable projection is wired into the graph
- validate allows all by default
- validate blocks with custom rule
- validate with pulse and custom rule
- validate with link rule
- validate with action rule
- cell with system context
- cell with module context
- cell with core context
- cell with secure enclave context
- cell with public interface context
- cell with custom context evolves
- policy with TTL invalidates after duration
- policy with event limit invalidates after threshold
- policy with both TTL and event limit
- policy events can be reset
- creates a valve bound to the source
- forwards pulses that pass the gate
- drops pulses that fail the gate
- pass and fail can be interleaved
- forwards the original payload unchanged
- dynamic gate can open and close
- gate can inspect pulse type
- disabled synapses is terminal and does not broadcast
- returns an OpenCell bound to the source
- emit runs perform and observers see the result
- perform receives the host OpenCell
- user metadata is forwarded to perform
- returning null drops the pulse
- testRule can reject emit
- bound source emissions also run perform
- can drive a state cell as a command handler
- cell returns string representation
- value cell returns string with value

### File 7: commons_test.dart (49 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 49 |
| mapMerge | |
| SyncSet | |
| QueueList | |
| AsyncQueueList | |
| PriorityQueue | |
| AsyncPriorityQueue | |
| SyncQueue | |
| Box / SyncBox / FinalBox | |
| TypeObject / FunctionObject / get | |
| marker types | |

**Tests**

- copies keys that only exist in other
- concatenates when both values are iterables
- wraps an existing non-iterable when other is iterable
- appends a scalar onto an existing iterable
- wraps both scalars into a list when keys collide
- does not mutate the original maps
- add, contains, length, and lookup
- remove, isEmpty, and isNotEmpty
- addAll, toSet, toList, replicate, and iterator
- containsAll, intersection, union, and difference
- removeAll, retainAll, removeWhere, retainWhere, clear
- map, forEach, and where
- reduce combines elements
- constructors and FIFO operations
- removeWhere, retainWhere, and clear
- cast and async wrapper
- mirrors queue mutations under the lock
- toListAndClear, clearAndAdd, removeWhere, retainWhere, clear
- iterator and cast
- extracts the smallest element first with a comparator
- uses Comparable when no comparator is provided
- addFirst and addLast still rank by priority
- remove, removeWhere, retainWhere, and clear
- remove returns false for an incompatible value type
- empty buffer throws on extract
- removeLast pops a leaf and iterator walks the heap
- removeLast returns the lowest-precedence element
- last peeks the lowest-precedence element
- add, peek, and ranked extract
- addAll, map, toList, toSet, reduce, forEach, replicate
- orders by comparison and reports emptiness
- of constructor seeds the heap
- capacity rejects overflow on add and addAll
- addAll is atomic: no partial additions on capacity overflow
- addFirst, addLast, remove, map, clear
- Box starts null and accepts mutation
- SyncBox serializes get and set
- FinalBox is write-once
- FinalBox.async is a SyncBox
- TypeObject wraps a value
- FunctionTypeObject evaluates lazily
- FunctionObject stores a record
- get returns the primary value
- get uses fallback when the primary is absence-shaped
- get uses orElse when the primary and fallback are absence-shaped
- get propagates non-absence exceptions from the primary
- get propagates wrong-typed record fields (TypeError)
- get rethrows the original error when orElse cannot satisfy T
- Async and Unmodifiable are usable as type checks

### File 8: context_test.dart (117 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 117 |
| GovernanceEntry | |
| Ontology | |
| Context | |
| system | |
| describe | |
| primary constructor | |
| fromEntries | |
| named factories | |
| Context.deputy and Context.pulse | |
| evolve | |
| lineage | |
| equality | |
| Mandate | |
| DeputyContext | |
| system | |
| constructor | |
| named factories | |
| fromEntries | |
| evolve | |
| equality | |
| Clearance | |
| Isolation | |
| Sovereignty | |
| AuditLevel | |
| Provenance | |
| PulseContext | |
| system | |
| constructor | |
| named factories | |
| evolve | |
| lineage and index | |
| equality | |
| Identity | |
| ReasoningStrategy | |
| Sensitivity | |
| PriorityTier | |

**Tests**

- binds a typed value to a governance dimension
- constructor is equivalent to Governance.entry
- toEntry produces a MapEntry with the same key and value
- supports collection and enum value types
- static pillars are not evolvable
- fluid boundaries are evolvable
- isType validates the dimension value type
- compose includes every resolved dimension and omits nulls
- evolve yields only fluid boundaries
- is a reusable singleton with empty ontology
- evolve produces a specialized context without mutating system
- returns a Context whose ontology getters are unset
- evolve materializes ontology from the description context
- stores every named ontological dimension
- omitted dimensions remain null
- index operator returns local dimension values
- builds a context from governance entries
- inherits unset dimensions from an explicit parent
- local values shadow parent values
- core is a system-space infrastructure blueprint
- module is a user-space application blueprint
- secureEnclave is a privileged security environment
- publicInterface is a sanitized ingress boundary
- shieldedCortex isolates high-reasoning logic
- receptor hydrates inbound sensory sources
- integrityGate is a judicial validation barrier
- homeostasis is a metabolic stability loop
- sandbox is a speculative simulation workspace
- auditLog is a forensic compliance ledger
- transientTask is a leased ephemeral worker
- deputy factory returns a DeputyContext
- pulse factory returns a PulseContext
- refines fluid boundaries and preserves the original
- ignores attempts to change static pillars
- can tighten constraints and compliance
- is empty when the dimension was never set
- returns the local value for a root context
- walks the parent chain from root to leaf
- identical instances are equal
- independently constructed contexts are distinct records
- different dimensions are not equal
- an evolved child is not equal to its parent
- system is not equal to an empty constructed context
- role is a static pillar; remaining dimensions are fluid
- isType validates mandate value types
- compose and evolve filter dimensions correctly
- exposes safe mandate defaults
- evolve from system creates a specialized deputy
- requires authority and links ontology from the base context
- defaults isolation, clearance, sovereignty, and auditLevel
- stores standard clearance when it is the default
- observer is a read-oriented monitoring mandate
- delegate is an operational mutating mandate
- sandbox virtualizes mutations
- sandbox default role is Reasoning_Sandbox
- intervention is an emergency sentinel mandate
- janitor is a structural hygiene mandate
- architect is an infrastructure orchestration mandate
- auditor is a read-only compliance witness
- ambassador is a cross-domain negotiator
- shielded is a privileged enclave mandate
- gatekeeper is a policy enforcement mandate
- homeostasis is a background maintenance mandate
- can assemble a mandate from mixed ontology and mandate entries
- refines fluid mandate dimensions and keeps role immutable
- inherits unset mandate fields from the parent deputy
- independently constructed deputies are distinct records
- different authority values are not equal
- levels are ranked from observational to unrestricted
- authorizes is inclusive of the required rank
- virtualization starts at sandboxed
- only restricted is guarded
- supervised requires approval; preemptive can override
- deep reasoning starts at detailed; none is silent
- static pillars are not evolvable
- fluid boundaries are evolvable
- isType validates provenance value types
- compose includes resolved dimensions
- evolve excludes static pillars
- is an empty telemetric fallback
- evolve from system creates a specialized pulse context
- stores every named provenance dimension
- auto-generates a unique traceId when omitted
- does not auto-link parentTraceId from a generic base context
- inherits ontology from a ContextBase parent
- inherits provenance from a PulseContext parent
- stores others even without a parent
- stores others when a parent is also provided
- userAction captures explicit human intent
- userAction defaults purpose, priority, and sensitivity
- aiInference captures probabilistic autonomous intent
- inference matches the aiInference blueprint
- regulated forces forensic compliance markers
- regulated default reason mentions the framework
- homeostasis is a low-priority maintenance signal
- systemInternal uses a fixed system_daemon actor
- complianceAudit is a forensic witness signal
- selfCorrection prefixes the target field in reason
- infrastructureChange uses formal strategy
- securityIntervention is an emergency shield
- telemetry is unaudited background observation
- collaboration records a delegation handoff
- hypothesis is a non-committal simulation
- instruction is a critical manual override
- factories link parentTraceId when baseContext is a PulseContext
- refines fluid provenance and preserves static pillars
- can evolve ontology identity alongside provenance
- others passed to evolve are stored on the child
- index operator walks parent provenance
- lineage traces evolved ontology identity through a pulse parent
- independently constructed pulse contexts are distinct records
- auto-generated traceIds make otherwise identical contexts unequal
- next generates unique UUID-shaped identifiers
- classifies stochastic, mandated, and agentic strategies
- masking and high-risk thresholds follow classification rank
- fromValue maps numeric urgency onto semantic tiers
- urgent tiers start at critical

### File 9: deputy_test.dart (26 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 26 |
| Cell.deputy | |
| identity | |
| testRule layering | |
| apply forwarding | |
| unmodifiable | |
| causal integrity | |
| Attenuation enforcement | |
| OpenCell.deputy | |

**Tests**

- returns this when no attenuation is requested
- creates a distinct proxy when a testRule is supplied
- creates a distinct proxy when a DeputyContext is supplied
- creates a distinct proxy when an ephemeral policy is supplied
- creates a distinct proxy when synapses are overridden
- deputies of the same principal compare equal and share hashCode
- a nested deputy remains equal to the root principal
- unrelated cells are not equal to a deputy
- the deputy rule is additive on top of the principal
- readOnly deputy rejects apply forwarding
- deputy.apply executes on the principal
- deputy.unmodifiable is the principal unmodifiable view
- ValueCell deputy unmodifiable is an UnmodifiableValueCell
- a nested deputy may use DeputyContext.system
- a nested deputy may use an evolved descendant context
- isolation can only tighten
- sovereignty can only tighten
- clearance can only tighten
- auditLevel can only tighten
- a nested deputy rejects an unrelated DeputyContext
- returns this when no attenuation is requested
- rejects a DeputyContext from an unrelated context tree
- creates an OpenCell proxy that can emit
- nested OpenCell deputy with defaults returns this
- OpenCell deputy exposes async handle
- OpenCell deputy can link a downstream observer

### File 10: instruction_test.dart (23 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 23 |
| Instruction | |
| Construction | |
| Composition | |
| Instruction.future | |
| Custom Instruction | |
| Receptor integration | |

**Tests**

- transforms the payload
- returning null drops the pulse
- user metadata is passed to the instruction
- host cell is passed through
- exception terminates with null
- can return the same pulse instance
- + runs left then right
- Instruction.chain matches +
- null short-circuits later stages
- chains nest and stay Instruction
- exception in a stage terminates the chain
- custom strategy replaces sequential execution
- strategy receives chain user metadata
- a throwing strategy terminates the chain with null
- chain.call accepts a future continuation
- returns null immediately and resumes via future
- user metadata is available on a future instruction
- returning a pulse still emits synchronously
- null future callback drops the continuation without printing
- future instruction in a chain resumes through the chain callback
- a Function resume token is walked without matching a stage
- a throwing custom stage in a chain terminates with null
- Receptor.instruction runs the instruction

### File 11: nucleus_test.dart (40 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 40 |
| Nucleus | |
| empty / Nucleolus | |
| Construction & defaults | |
| Nucleus.create | |
| Activation | |
| evolve | |
| clone | |
| Equality | |
| inheritable | |
| Cell hydration | |

**Tests**

- Nucleus.empty is a reusable singleton
- empty nucleus uses framework defaults
- empty nucleus is activation-resistant
- empty nucleus timestamp is a DateTime
- default Nucleus uses system context and allowAll
- default Nucleus allocates a lock
- forceLock: false omits a dedicated lock
- default synapses are an enabled registry, not the flyweight
- Synapses.disabled is stored as a terminal egress
- custom context is stored
- custom receptor is stored
- custom testRule is stored
- bind is stored
- user record is stored
- isGoverned follows the receptor, not a custom context
- timestamp is a DateTime
- create without principal uses defaults
- create with principal inherits from it
- nuclei sharing a root principal agree on == and hashCode
- unactivated cell getter throws
- activate returns false for a cell that does not own this nucleus
- Cell.fromNucleus binds and activates the nucleus
- fromNucleus of an already activated nucleus uses a clone
- fromNucleus with bind links the upstream synapses
- inherits context, receptor, and testRule from principal
- local testRule overrides the principal
- local context overrides the principal
- bind is not inherited
- user is inherited
- local user overrides the principal
- walks a chain of principals
- lock falls back to the principal
- clone is a distinct unactivated blueprint
- clone can hydrate an independent cell
- two distinct root nuclei are not equal
- identity equality holds
- evolved nuclei that share a root principal compare equal
- inheritable handle exposes the resolved pillars
- hydrated cell uses the nucleus testRule
- hydrated cell with disabled synapses is terminal

### File 12: operator_async_map_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |
| Cell.asyncMap latestOnly with concurrency=1 | |

**Tests**

- latest value is emitted despite a superseded in-flight future
- concurrency=0 latestOnly is unaffected by the change

### File 13: operator_from_stream_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |
| Cell.fromStream + EphemeralPolicy | |

**Tests**

- eventLimit trips at the configured count, not half
- no ephemeralPolicy → no invalidation and events stay at 0
- the caller policy hooks run exactly once per event

### File 14: operators_advanced_transactions_test.dart (39 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 39 |
| Advanced & Transactions | |
| Cell.sanitized | |
| Cell.open | |
| Combined Operators | |
| Edge Cases & Error Handling | |
| toString | |

**Tests**

- sanitized redacts sensitive data
- sanitized passes through non-sensitive data
- sanitized with different sensitivity threshold
- sanitized with ingress and observe
- sanitized with state and observe
- sanitized with complex object type
- sanitized with multiple sensitivity levels
- open creates a manually controllable cell
- open with emit sends pulses
- open with ingest and serialized completion
- open with link and unlink observers
- open with observe receives pulses
- open with test rule filters pulses
- open with state receives updates
- open with forceLock serializes emissions
- open with ephemeral policy auto-invalidates
- open with governed context
- async emit and ingest deliver the pulse
- async emit with forceLock still delivers
- modifiable includes emit, ingest, link, and apply
- emit awaits an async testRule
- link awaits an async testRule
- ingress + sanitized + observe
- state + sanitized + observe
- open + state + observe
- ingress + open + observe
- state + transaction + state
- txApply with state and compensation
- sanitized with missing sensitivity redacts (fail closed)
- open with disabled synapses
- transaction with empty participants throws
- txApply with empty participants throws
- transaction with non-existent savepoint throws
- sanitized with null redact result
- sanitized cell toString
- open cell toString
- TransactionValidationException toString
- TransactionConflictException toString
- TxApplyException toString

### File 15: operators_async_routing_test.dart (63 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 63 |
| Async & Routing Operators | |
| Cell.asyncMap | |
| Cell.hub | |
| Cell.switchMap | |
| Cell.fromFuture | |
| Cell.fromStream | |
| Combined Operators | |
| Edge Cases & Error Handling | |
| toString | |

**Tests**

- asyncMap transforms values from a state cell
- asyncMap transforms values from an ingress cell
- asyncMap with concurrency 1 processes sequentially
- asyncMap with latestOnly drops older results
- asyncMap with exhaust ignores while busy
- asyncMap with observe receives results
- asyncMap handles errors gracefully (no emission)
- hub routes pulses to spokes based on type
- hub with prefix routing uses longest prefix match
- hub with pattern routing uses glob matching
- hub with multicast delivers to all matching spokes
- hub multicast with custom match delivers to every interested spoke
- hub with fallback routes unmatched pulses
- hub with priority ordering processes higher priority first
- hub emits async with lock protection
- hub ingest with serialized completion
- hub with governed spokes uses DeputyContext
- hub spoke handler can drive a state cell
- a mapper may link new cells into the source mid-broadcast
- switchMap switches to new cell on source change
- switchMap with observe receives switched values
- switchMap with multiple source changes
- switchMap with null payload does not switch
- switchMap contains a throwing async link gate
- invalidation unlinks the inner cell from the output
- fromFuture emits future result
- fromFuture with observe receives value
- fromFuture with state cell receives value
- fromFuture with derived cell transforms value
- fromFuture with delayed Future
- fromFuture emits an error pulse when the Future fails
- fromFuture with complex type
- fromFuture with null value
- fromStream emits stream values
- fromStream with observe receives values
- fromStream with state cell accumulates values
- fromStream with delayed stream
- fromStream with periodic stream
- fromStream with cancelOnError handles errors
- fromStream with distinct filters duplicates
- fromStream with derived transforms values
- fromStream with complex types
- fromStream with null values
- fromStream with empty stream emits nothing
- fromStream cancels the subscription when the cell is invalidated
- ingress + asyncMap + observe
- fromFuture + derive + state
- fromStream + distinct + observe
- ingress + asyncMap + state
- fromFuture + asyncMap + observe
- fromStream + asyncMap + observe
- hub + state for routing
- asyncMap with empty source emits nothing
- hub with no spokes uses fallback
- fromFuture with already completed future
- fromStream with error after values (no cancelOnError)
- hub with multicast and priority
- switchMap with source emitting multiple values
- asyncMap cell toString
- hub toString
- switchMap cell toString
- fromFuture cell toString
- fromStream cell toString

### File 16: operators_flow_control_test.dart (45 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 45 |
| Flow Control Operators | |
| Cell.debounce | |
| Cell.throttle | |
| Cell.distinct | |
| Cell.synthesis | |
| Combined Operators | |
| Edge Cases & Error Handling | |
| toString | |

**Tests**

- creates a debounce cell with default leading false
- a throwing downstream in the trailing timer is contained
- debounce delays delivery until silence
- debounce resets timer on each pulse
- debounce with leading true emits first immediately
- debounce with zero duration delivers immediately
- debounce cancels a pending timer when the output is invalidated
- debounce with leading true and zero duration emits immediately
- debounce with leading true and burst of three
- creates a throttle cell with defaults
- a throwing downstream in the trailing timer is contained
- throttle with leading true emits first immediately
- throttle suppresses pulses during window
- throttle with trailing true emits last during window
- throttle with leading false only emits trailing
- throttle with zero duration delivers the leading pulse
- throttle with leading false and trailing false emits nothing
- creates a distinct cell with default equality
- distinct filters consecutive duplicates
- distinct allows non-consecutive duplicates
- distinct with custom equals function
- distinct with custom equals on objects
- distinct handles null values
- creates a synthesis cell with sources
- synthesis aggregates values from sources
- synthesis receives the triggering pulse
- synthesis with null suppression
- synthesis with complex object types
- synthesis with multiple source types
- synthesis with empty sources does not throw
- synthesis with single source
- debounce then distinct
- throttle then distinct
- synthesis then observe (debounce of synthesis is source-gated)
- synthesis consecutive equal sums still fire (no distinct)
- synthesis for form validation
- debounce with negative duration throws
- throttle with negative duration throws
- distinct with null values and custom equals
- synthesis with sources that are not ValueCell
- synthesis with aggregator throwing exception
- debounce cell toString
- throttle cell toString
- distinct cell toString
- synthesis cell toString

### File 17: operators_foundation_test.dart (65 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 65 |
| Cell.state | |
| Basic State | |
| State with evolve | |
| Ingest | |
| Edge Cases | |
| Cell.ingress | |
| Basic Ingress | |
| Ingress with Governance | |
| Ingress with Source Binding | |
| Ingest | |
| Edge Cases | |
| Cell.observe | |
| Cell.derive | |
| Basic Derive | |
| Derive with Filtering | |
| Edge Cases | |
| Combined Operators | |

**Tests**

- creates a state cell with initial value
- creates a state cell with null initial value
- creates a state cell with no initial value
- update changes the state value
- update multiple times
- updateAsync changes the state value
- updateAsync resolves false when async validation rejects
- updateAsync with multiple concurrent updates
- cell.async.state reads through the cell lock
- unlocked ValueNucleus still supports async state and updateAsync
- ValueNucleus.from with instruction transforms updates
- ValueNucleus.evolve hydrates a cell from a principal
- ValueNucleus.evolve with instruction transforms updates
- ValueNucleus.evolve with passThrough still commits via postProcess
- ValueNucleus.evolve with a custom receptor commits via postProcess
- ValueNucleus.evolve with override uses the override local record
- ValueCell.terminal holds state without broadcasting
- ValueCell.receptor persists transformed pulses
- unmodifiable projects a nested Cell and is already the view
- evolve modifies incoming pulses
- evolve can filter updates by returning null
- evolve with type conversion
- evolve with complex objects
- evolve with validation
- ingest with pulse
- ingest with serialized completion
- state cell with null update
- creates an ingress cell
- emit sends a pulse through the ingress
- emit with refine transforms the input
- emit with refine can filter input
- emitAsync sends a pulse asynchronously
- emitAsync with multiple concurrent emissions
- ingress with custom context
- ingress with test rule
- ingress with forceLock
- ingress with source bind
- ingest with pulse
- ingest with serialized completion
- ingress with null payload
- ingress with empty string after refine
- ingress with disabled synapses
- creates an observer
- observer receives pulses when started
- observer can be stopped
- observer with initiallyStarted false
- observer with multiple pulses
- observer with String pulses
- observer with complex object pulses
- observer with governed pulse
- observer with null payload
- observer stop called multiple times
- observer start called multiple times
- creates a derived cell
- derive transforms the source value
- derive with type conversion
- derive with multiple transformations
- derive can filter by returning null
- derive filter with complex condition
- derive with null source value
- derive with project that throws
- derive with source changes multiple times
- state + derive + observe
- ingress + derive + observe
- state + derive + state

### File 18: propagation_policy_test.dart (37 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 37 |
| PropagationPolicy | |
| Construction & Defaults | |
| Strategy: immediate | |
| Strategy: debounced | |
| Strategy: throttled | |
| Strategy: batched | |
| Strategy: buffered | |
| Strategy: audit | |
| Strategy: debounceLeading | |
| Policy Composition & Equality | |
| Edge Cases | |
| Integration with Synapses | |
| toString | |

**Tests**

- default constructor uses immediate strategy
- constructor sets strategy
- constructor sets debounceTime
- constructor sets throttleTime
- constructor sets batchSize
- constructor with all parameters
- immediate delivers pulses synchronously
- immediate delivers all pulses in order
- debounced delays delivery until silence
- debounced resets timer on each pulse
- debounced with zero duration delivers immediately
- throttled delivers first pulse immediately
- throttled suppresses subsequent pulses during window
- throttled with zero duration delivers all pulses
- batched accumulates pulses until batchSize
- batched with batchSize 1 delivers immediately
- batched with large batch size buffers until threshold
- buffered accumulates pulses and flushes after throttleTime
- buffered flushes when batchSize is reached
- audit delivers the latest pulse at intervals
- audit with zero throttleTime delivers immediately
- debounceLeading delivers first pulse immediately
- two identical policies are equal
- two different policies are not equal
- policies with different debounce times are not equal
- policies with different throttle times are not equal
- policies with different batch sizes are not equal
- zero duration works
- batchSize of 0 works
- all strategies can be instantiated
- policy with no parameters uses defaults
- policy can be used with synapses
- multiple policies can be used with different synapses
- policy with filter preserves payload
- policy with filter can drop pulses
- policy returns string representation
- policy with immediate strategy toString

### File 19: pulse_test.dart (159 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 159 |
| Pulse | |
| Construction | |
| withStep vs evolve distinction | |
| Evolution | |
| Composition | |
| Shell | |
| Unmodifiable | |
| Comparison | |
| Iterable | |
| Governance | |
| Provenance | |
| Policy | |
| Context Factories | |
| PulseExtension | |
| PulseIterableExtension | |
| Causal Chain Distinction | |
| toString | |
| Callbacks and mask variants | |
| Lineage extras | |
| Unmodifiable collective | |
| Shell extras | |
| Composition extras | |

**Tests**

- creates a simple pulse with payload
- creates a pulse with type
- creates a pulse with priority
- creates a pulse with source
- creates a pulse with step
- creates a governed pulse with context
- creates a governed pulse with policy
- creates a governed pulse with context and callbacks
- Pulse.governed without context or policy is NOT governed
- Pulse.governed with only callbacks is NOT governed
- withStep does NOT create an EvolvedPulse
- evolve with ONLY step does NOT create an EvolvedPulse
- evolve with ONLY context does NOT create an EvolvedPulse
- evolve with pulse creates an EvolvedPulse (causal branch)
- evolve with pulse but no step creates EvolvedPulse
- withStep vs evolve(step) are semantically similar
- withStep lengthens lineage without causal branching
- evolve(step) lengthens lineage without causal branching
- withStep preserves identity, context, and payload
- evolve(step) preserves identity, context, and payload
- evolve with pulse creates parent-child relationship
- withStep adds a trace step
- withStep chains multiple steps
- evolve(step) adds trace step without EvolvedPulse
- evolve(step) chains multiple steps without EvolvedPulse
- evolve with context and step adds trace without EvolvedPulse
- evolve with pulse appends and creates EvolvedPulse
- evolve requires at least one parameter
- lineage tracks payload history with evolve(pulse)
- lineage tracks type history with evolve(pulse)
- lineage tracks priority history with evolve(pulse)
- lineage tracks source history with evolve(pulse)
- withStep does NOT affect lineage history
- evolve(step) does NOT affect lineage history
- evolve with pulse creates causal chain, evolve(step) does not
- + operator creates collective pulse
- + operator with multiple pulses
- Pulse.batch creates collective pulse
- Pulse.batch with governed pulses
- Pulse.batch with callback
- a batch with onComplete completes through empty synapses
- a batch with onComplete completes through async empty synapses
- shell hides payload
- shell scrutinizes receptor
- shell with governed pulse
- unmodifiable locks payload of this specific instance
- unmodifiable prevents mutation of the instance
- unmodifiable does NOT block withStep - creates new modifiable instance
- unmodifiable does NOT block evolve(step) - creates new modifiable instance
- unmodifiable protects the payload cell from mutation
- unmodifiable recursively protects parent chain for EvolvedPulse
- unmodifiable with evolve(step) does NOT create recursive parent chain
- unmodifiable recursively protects root and source
- unmodifiable preserves reactivity of payload cell
- unmodifiable is recursive for nested iterables
- unmodifiable allows reading payload but blocks modifications
- evolve with pulse from unmodifiable preserves protected instance as parent
- withStep from unmodifiable creates new modifiable instance
- unmodifiable does not prevent withStep chain
- unmodifiable blocks modifications but not observations
- compareTo orders by timestamp
- compareTo orders by priority when timestamps equal
- compareTo orders by trace depth when timestamps and priority equal
- equality uses record comparison
- identity equality works
- hashCode is stable
- iterating over single pulse yields itself
- iterating over withStep pulse yields itself (not EvolvedPulse)
- iterating over evolve(step) pulse yields itself (not EvolvedPulse)
- iterating over evolve(pulse) yields EvolvedPulse
- iterating over collective pulse yields itself
- collective payload iteration yields individual pulses
- isGoverned returns true when context provided
- isGoverned returns true when policy provided
- isGoverned returns false when no context or policy
- isGoverned returns false when only callbacks provided
- isGoverned returns true when context is inherited via evolve(step)
- isGoverned returns true when context is inherited via evolve(pulse)
- withStep does NOT inherit governance differently
- isInvalidated returns false initially
- isInvalidated returns true after policy expires
- context stores actor
- context stores reason
- context stores purpose
- context stores strategy
- context stores confidence
- context stores priority
- context stores sensitivity
- context stores auditLevel
- context stores traceId
- context auto-generates traceId
- context stores parentTraceId
- context stores compliance
- policy tracks hops
- policy invalidates on hop limit
- policy invalidates on TTL
- userAction factory creates correct context
- aiInference factory creates correct context
- regulated factory creates correct context
- securityIntervention factory creates correct context
- systemInternal factory creates correct context
- homeostasis factory creates correct context
- telemetry factory creates correct context
- instruction factory creates correct context
- selfCorrection factory creates correct context
- collaboration factory creates correct context
- hypothesis factory creates correct context
- infrastructureChange factory creates correct context
- Iterable.map on a Pulse is not PulseExtension.map
- Iterable.cast on a Pulse is not PulseExtension.cast
- map transforms payload and preserves causality
- map does not mutate the original pulse
- map keeps ancestor withStep entries via parent walk
- map keeps the original context and governance on the evolved child
- chained maps nest EvolvedPulse parents
- same-type map lineage includes parent and child payloads
- mixed-type map lineage skips payloads that fail the cast
- attach adds context metadata
- tap executes side-effect without modifying pulse
- cast re-types payload via evolve(pulse:)
- cast of a typed pulse still creates an EvolvedPulse child
- incompatible PulseExtension.cast throws
- batch creates collective from iterable
- flatten converts nested collective to flat sequence
- withStep adds step to all pulses (not EvolvedPulse)
- attach adds context to all pulses
- mapEach transforms payload of each pulse
- withStep does NOT create parent-child relationship
- evolve(step) does NOT create parent-child relationship
- evolve(pulse) creates parent-child relationship
- withStep is for documentation, evolve(pulse) is for causal branching
- withStep does NOT affect root.trace
- evolve(pulse) affects parent chain but root remains oblivious
- withStep and evolve(pulse) can be combined
- formats a payload-only pulse
- formats a null payload
- includes source, type, and trace when present
- collective toString names CollectivePulse
- evolved pulse toString names EvolvedPulse
- onError-only governed pulse is constructible
- onProgress-only governed pulse is constructible
- onComplete and onProgress together
- all three callbacks plus policy and source
- lineage of policy and context walks the chain
- equality with a non-Pulse is false
- batch.unmodifiable is a composite with unmodifiable members
- unmodifiable compareTo and equality delegate to the source
- unmodifiable wraps a Cell payload
- unmodifiable wraps a Map payload containing a Cell
- shell compareTo follows timestamp then priority
- shell + / evolve / withStep are unsupported
- shell exposes kernel priority and source
- shell compareTo uses priority then trace when timestamps match
- shell scrutinize catch returns null when the kernel rejects
- + of mixed payload types still builds a collective
- a withStep child of a governed pulse stays governed
- CollectivePulse.governed stores type, context, step, and scrutinize
- evolved unmodifiable exposes parent, iterator, and toString
- Pulse.evolve(pulse:) with step, context, and a completing parent

### File 20: receptor_instruction_future_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |
| Receptor.pipeline with Instruction.future + postProcess | |

**Tests**

- postProcess commits ValueCell state on the async path
- postProcess output is propagated to downstream observers

### File 21: receptor_test.dart (54 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 54 |
| Receptor | |
| passThrough | |
| Construction | |
| Activation & clone | |
| Pipeline | |
| Instruction composition | |
| Instruction.future | |
| Receptor.async | |
| Graph integration | |
| call contract extras | |
| Receptor.pipeline mask | |

**Tests**

- is a reusable singleton
- forwards the pulse unchanged without activation
- cannot be activated
- clone is the same instance
- async is unsupported
- cell getter is unsupported
- passThroughRule is an identity instruction
- passThroughRule + other yields the other instruction
- hashCode is stable on the singleton
- passThrough equals only other pass-through receptors
- receptor equality follows the configuration record
- empty pipeline getters do not throw NoSuchMethodError
- closure receptor transforms payload
- closure receptor returning null drops the pulse
- closure receptor exception terminates the pulse
- Receptor.instruction wraps a reusable instruction
- Instruction user metadata is available during execution
- Receptor.instruction stores a user factory on the receptor
- Receptor.typed transforms between pulse payload types
- empty pipeline is a pass-through
- template is not activated until bound
- Cell construction activates an unbound template in place
- activate binds the host cell
- clone is an independent unactivated copy
- unactivated call fails the activation assertion
- runs preProcess then instruction then postProcess
- a throwing custom instruction in the pipeline returns null
- null from a stage short-circuits later stages
- postProcess can drop after a successful core stage
- omitted stages are skipped
- preProcess and postProcess run without a core instruction
- instruction exception terminates the pipeline
- + chains two instructions in order
- Instruction.chain is equivalent to +
- chain short-circuits on null
- chains nest
- instruction exception returns null
- returns null immediately and resumes via future callback
- hook captures the transformed result
- hook sees null when the receptor drops the pulse
- serializedCompletion false still processes via the hook
- fire-and-forget pulses enqueued mid-drain are all delivered
- receptor.async is a stable handle
- receptor.async preserves FIFO under concurrent submits
- Cell(bind:) delivers transformed pulses to observers
- testRule on the host can drop pulses before transformation
- null from the bound receptor suppresses observers
- async testRule Future is awaited before transformation
- a PulseShell is scrutinized instead of run through the pipeline
- async call scrutinizes a PulseShell
- governed pulse on a deputy host records the mandate role
- stores reaction flyweight combinations
- a reaction receptor transforms without an instruction chain
- a hosted EphemeralPolicy is ticked on a governed cell

### File 22: cli_test.dart (15 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 15 |

**Tests**

- --help exits 0 and prints usage
- no args exits 2 (usage)
- unknown command exits 2
- verify passes on a valid ledger
- verify fails on a tampered ledger
- verify --format json emits canonical JSON
- verify --graph is rejected until a future CLI revision
- diff reports identical ledgers as exit 0
- diff reports divergence as exit 1
- fork writes a valid fork ledger whose seq 0 is the ForkRecord
- fork rejects --replaceSeq until a future CLI revision
- visualise emits mermaid and dot
- inspect prints the summary in human and json
- missing file exits 2
- the bin entry point prints help and exits 0

### File 23: canonical_json_test.dart (13 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 13 |
| canonicalJsonEncode | |
| fingerprint | |
| barrel surface | |

**Tests**

- sorts map keys regardless of insertion order
- handles nested maps and lists
- distinguishes int from double
- rejects NaN and Infinity loudly
- rejects non-string map keys
- rejects DateTime and other non-JSON objects
- escapes strings exactly like jsonEncode
- omitNulls drops null values recursively
- canonicalJsonDecode is the matched decoder
- is deterministic and map-order independent
- is a 64-character hex SHA-256
- changes when the value changes
- package:cell/replay.dart alone exposes the the serialisation layer API

### File 24: context_roundtrip_test.dart (8 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 8 |
| PulseContextCodec round-trip | |
| PulseContextCodec failures | |

**Tests**

- the system context round-trips byte-identically
- all provenance dimensions round-trip byte-identically
- a three-generation chain re-resolves inheritance after round-trip
- the __others__ map is preserved verbatim
- ontology dimensions round-trip when a context sets them
- missing lineage is a FormatException
- unknown governance key is a loud FormatException
- a non-map lineage entry is a FormatException

### File 25: fastpulse_rejected_test.dart (4 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 4 |
| materialise boundary | |

**Tests**

- toJson rejects the _FastPulse produced by Cell.ingress
- toJson rejects _StepPulse; materialise preserves payload and trace
- materialise on a plain pulse is identity (no work needed)
- materialise cleans _StepPulse ancestors of an evolved pulse

### File 26: pulse_codec_test.dart (20 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 20 |
| encodePulse — non-serializable fields | |
| decodePulse — decode failures | |
| encodePulse — round-trips | |
| canonicality | |

**Tests**

- onComplete fails loudly
- onError fails loudly
- onProgress fails loudly
- policy fails loudly
- a non-JSON-encodable payload fails loudly
- a callback deep in the parent chain fails loudly
- missing version discriminator
- unsupported version
- malformed context
- plain Pulse<int>
- governed pulse keeps its context
- parent chain round-trips with the full trace
- a 10-level parent chain round-trips
- collective pulse round-trips its children
- a null payload round-trips
- a DateTime payload encodes to millisecond ISO-8601
- List and Map payloads round-trip
- non-String types encode as null
- logically-equal pulses produce identical bytes
- re-encoding a decoded pulse is byte-identical

### File 27: pulse_from_json_overrides_test.dart (19 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 19 |
| Pulse.fromJson — overrides | |

**Tests**

- payload override
- type override
- source override wins over the resolver
- source: pulseNullSource strips the source
- step override
- priority override
- context override
- onComplete override carries the callback; toJson refuses
- onError override carries the callback; toJson refuses
- onProgress override carries the callback; toJson refuses
- policy override carries the policy; toJson refuses
- payload: pulseNullPayload overrides to null
- type: pulseNullType overrides to null
- step: pulseNullStep overrides to null
- payload override on a collective JSON is rejected
- multiple overrides all apply
- Pulse<int>.fromJson(json, payload: 42) types P as int
- Pulse<dynamic>.fromJson(json) decodes with P as dynamic
- an override preserves the parent chain

### File 28: pulse_from_json_test.dart (9 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 9 |
| Pulse.fromJson — the factory without overrides | |

**Tests**

- symmetry: fromJson(toJson(p)) reproduces p at codec precision
- timestamps round-trip at millisecond precision (UTC)
- asymmetry: a non-canonical input re-encodes canonically
- a source with no resolver decodes as null
- a source with a resolver decodes as the resolved cell
- a resolver returning null for an unknown id decodes as null
- missing version discriminator throws PulseDecodeError
- unsupported version throws PulseDecodeError
- malformed payload shape throws PulseDecodeError

### File 29: pulse_roundtrip_test.dart (7 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 7 |
| PulseCodec round-trip | |

**Tests**

- 1000 generated pulses re-encode byte-identically
- parent digest mismatch fails loudly
- parentDigest without a supplied parent fails loudly
- a root pulse rejects a supplied parent
- a non-prefix parent trace fails loudly
- source is encoded by cell id
- unset optional fields are omitted from the wire map

### File 30: pulse_sentinel_test.dart (4 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 4 |
| override sentinels | |

**Tests**

- each sentinel is a const singleton (identical to itself)
- the five sentinels are distinct from each other
- identity is the only way to use a sentinel — lookalikes override
- the sentinels document their slots

### File 31: pulse_to_json_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |
| Pulse.toJson extension | |

**Tests**

- is visible on Pulse<P>
- round-trips through Pulse.fromJson
- throws PulseNotSerializable for a pulse with callbacks

### File 32: snapshot_roundtrip_test.dart (9 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 9 |
| CellSnapshot | |
| CellGraphSnapshot | |
| Cell.id | |

**Tests**

- round-trips all fields
- defaults receptorVersion to empty and extras to empty map
- round-trips a full graph
- defaults lastLedgerSeq to -1 and parentLedgerHash to null
- rejects a schema version newer than the codec
- is a stable, non-empty string for a fresh cell
- is available on state and derived cells
- a deputy shares its principal id (the serialisation layer behaviour)
- id is parallel to hashCode, not a replacement for it

### File 33: cycle_checker_reseeded_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- diamond graph replays without spurious cycle errors

### File 34: divergence_effect_mismatch_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- modified effectful receptor diverges at the first effect
- an extra effect (modified receptor) also diverges

### File 35: divergence_missing_effect_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- receptor that performs fewer effects diverges

### File 36: divergence_pure_receptor_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- modified pure receptor diverges at the correct seq
- lenient replay collects the divergence report

### File 37: pulse_codec_integration_test.dart (5 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 5 |
| pulse codec in the replay engine | |

**Tests**

- record, encode, decode, replay produces the same state
- encode a pulse with a policy throws PulseNotSerializable
- decode with a resolver yields the registered cell
- decode with an unresolved source continues with source == null
- an overridden payload feeds the replay path

### File 38: pulses_500_replay_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- 500 pulses replay deterministically with effects

### File 39: replay_identical_graph_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |

**Tests**

- replay 500 pulses against an identical graph succeeds
- replaying into a ledgered graph is refused
- maxEntries limits the replay to a prefix

### File 40: fork_at_seq_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- fork at seq 99 records divergedAt=99 and seals the parent
- non-isolated policies throw UnimplementedError

### File 41: fork_isolation_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- fork does not mutate the parent graph or ledger

### File 42: fork_verify_requires_original_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |

**Tests**

- fork verify passes when parent and fork are intact
- fork verify fails when the parent is tampered
- forking from a corrupt parent is refused at fork time

### File 43: whatif_replace_pulse_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- replace pulse #150 payload, replay to 200, check alternative state
- dropping a pulse leaves the fork without that entry

### File 44: effectful_testcell_replayed_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- effectful TestCell decision is replayed, not re-called
- a recorded false verdict is served as-is from the journal

### File 45: ephemeral_policy_tick_order_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- policy ticks are journalled and validated in order
- a tick-order mismatch diverges loudly

### File 46: readonlyexternal_testcell_reexecuted_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- readOnlyExternal TestCell is re-executed with its journal
- readOnlyExternal observations replay from the journal

### File 47: version_boundary_without_translator_test.dart (4 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 4 |

**Tests**

- replay across a version boundary without a translator fails loudly
- registering the recorded version makes the historical receptor run
- a registry pair whose rule version differs is refused
- unversioned ledger replays against an unversioned target

### File 48: version_dispatch_test.dart (6 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 6 |

**Tests**

- VersionRegistry resolves the registered version
- VersionRegistry refuses mismatched versions
- VersionRegistry refuses a second, different implementation
- cell graph exposes a version registry per graph
- DeputyContext.version defaults to 1.0.0 and can be set
- ContextTranslatorRegistry translates and fails loudly when absent

### File 49: graph_snapshot_restore_test.dart (4 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 4 |

**Tests**

- snapshot round-trips through JSON with identical ids
- snapshot config fingerprint changes when the rule changes
- snapshot bytes are independent of registration order
- 20-cell graph, snapshot, restore, identical state and ids

### File 50: id_uniqueness_test.dart (5 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 5 |

**Tests**

- two distinct cells cannot share an id
- re-registering the same nucleus with the same name is a no-op
- re-registering with a different name is an error
- CellGraphRegistry.forceReset clears ids
- a deputy resolves the registered name of its principal

### File 51: purity_classification_test.dart (6 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 6 |

**Tests**

- default Cell.state is pure
- default derive is pure
- asyncMap reports effectful (the journal flip)
- debounce and throttle report readOnlyExternal
- a custom receptor and rule can declare their purity
- purityOf on an unregistered name fails loudly

### File 52: registration_test.dart (4 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 4 |

**Tests**

- registers a cell and exposes it under the registered name
- builder is single-use
- rejects empty name
- rejects duplicate name

### File 53: unregistered_bind_rejected_test.dart (4 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 4 |

**Tests**

- strict mode rejects reachability through an unregistered bind
- terminal observers do not trip strict reachability (the graph registry scope)
- registering both ends passes
- unrestricted mode does not check reachability

### File 54: async_map_records_effects_test.dart (1 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 1 |

**Tests**

- asyncMap records exactly N effects and replays identically

### File 55: debounce_timer_order_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- debounce journals its timer and replays the fire
- throttle journals its window and replays the same output

### File 56: from_stream_ordering_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- fromStream emits values in order and journals each
- fromFuture journals its value

### File 57: null_journal_rejects_effectful_test.dart (5 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 5 |

**Tests**

- NullJournal refuses effectful operations loudly
- EffectJournal.current outside a scope is NullJournal
- JournalScope is drained on exit
- JournalScope pops the journal even when the body throws
- an effectful mapper that uses the ambient journal gets the same 

### File 58: pure_receptor_no_journal_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |

**Tests**

- pure receptor replays without any journal
- derive is pure and needs no journal
- the Effectful mixin produces Purity.effectful

### File 59: reordered_effects_diverge_test.dart (7 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 7 |

**Tests**

- ReplayJournal fails loudly on reordered effects
- ReplayJournal is satisfied when fully consumed
- ReplayJournal fails on unreplayed effect at end
- ReplayJournal fails when the receptor consumes extra effects
- ReplayJournal fails on io label and input mismatches
- ReplayJournal fails on timer duration mismatch
- EffectRecord round-trips through its canonical JSON

### File 60: append_and_verify_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- 1000 updates, verify() OK
- the chain hash covers at/effects/deltas: entries differ

### File 61: append_outside_apply_rejected_test.dart (6 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 6 |

**Tests**

- an apply nested inside a receptor does not recurse or double-record
- recordAndAppend does not recurse
- graph.run refuses to run without a bound ledger
- bindLedger refuses a second bind until unbound
- a store built for another graph is rejected at open time
- a hand-crafted appendInternal entry has an empty delta list — 

### File 62: file_store_roundtrip_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- write to disk, reopen, verify
- a tampered file line fails verify on reopen

### File 63: state_delta_capture_test.dart (5 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 5 |

**Tests**

- each apply produces exactly one StateDelta
- a delta is captured for every cell written in one pulse
- no ledger scope means no recording
- non-JSON-encodable state fails loudly under a ledger scope
- an idempotent write still records a delta (before == after)

### File 64: tamper_detection_test.dart (3 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 3 |

**Tests**

- tampering one delta fails verify with the offending seq
- tampering a prevHash breaks the chain at that seq
- a sequence gap fails verify at the offending seq

### File 65: ledger_store_conformance.dart (6 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 6 |
| $suiteName conformance | |

**Tests**

- append and lastSeq
- rejects out-of-order seq
- rejects genesis prevHash mismatch
- entriesSince yields in seq order
- close prevents further append
- survives reopen (durable only)

### File 66: replay_contract_test.dart (0 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 0 |

**Tests**


### File 67: review_hardening_test.dart (35 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 35 |

**Tests**

- asyncMap mapper errors fail the source pulse instead of vanishing
- asyncMap concurrency > 1 under an active ledger fails loudly
- asyncMap latestOnly under an active ledger fails loudly
- asyncMap with serial concurrency still records under a ledger
- filter-suppressed pulses complete their onComplete callback
- throttled drops complete their onComplete callback
- async fan-out survives a rejecting downstream and completes
- fromFuture completion prefers the ambient journal
- equal-metadata pulses compare 0 (the FIFO-stability contract)
- non-encodable transform state is not silently committed
- apply-path effectful verdicts are stored exactly once and replay
- replay verifies the chain before dispatching
- full replays verify the recorded baseline (before) of each delta
- fork replay serves effects from the parent journal, never the world
- fork entries reconstruct the mutated pulse on replay
- fork store materialize is idempotent and verify reads the file
- a legitimate null io result round-trips
- nested timer effects are recorded after the timer record
- the materialised pulse body is in the entry and replays exactly
- a tampered pulse body fails verify with a pulse-digest reason
- fork verifies the embedded ForkRecord in the fork file
- a tampered embedded ForkRecord fails fork verify
- asyncMap default concurrency is refused loudly under a ledger
- io digest mismatch is classified as tampering, not a codec error
- the codec round-trip preserves ungoverned pulses
- fork builds its fresh graph without the caller resetting the registry
- fromFuture constructed inside a ledgered run records its entry
- debounce under a ledger attributes its timer effect
- a single debounce pulse round-trips through replay
- a debounce burst round-trips (the cancelled timer does not fire)
- the file store accepts entries larger than 4096 bytes
- replaying a fork ledger from seq 0 fails loudly
- snapshots encode non-JSON values instead of throwing
- snapshot fromJson rejects corrupt cell entries
- overlapping graph.run appends serialise without racing

### File 68: seam_test.dart (2 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 2 |

**Tests**

- no testRule: TestCell on any Tissue constructor in example/
- no testRule: TestTissue on a Cell factory in example/

### File 69: synapses_test.dart (75 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 75 |
| Synapses | |
| disabled | |
| enabled | |
| Construction & broadcast | |
| link / unlink | |
| FilterRule | |
| relay | |
| PropagationPolicy | |
| async view | |
| remaining strategies | |
| mask combinations and equality | |
| Graph integration | |

**Tests**

- is a reusable singleton
- call is a no-op
- link and unlink return false
- is an empty iterable
- async is unsupported
- Cell with disabled synapses is terminal
- is a reusable singleton flyweight
- link and unlink return false on the flyweight
- is an empty iterable
- async is unsupported on the flyweight
- Cell with default synapses is not terminal
- empty synapses complete a pulse without observers
- constructor registers initial downstreams
- a cell and its deputy are distinct downstream edges
- call delivers to every downstream in order
- call delivers successive pulses in order
- cycle checker skips a downstream already visited by the pulse
- empty synapses still complete a governed pulse with onComplete
- link adds an observer when the synapses belong to the host
- link returns false when the synapses are not the host\
- duplicate link returns false
- unlink removes an observer
- unlink of a missing observer returns false
- a receptor may unlink a downstream cell mid-broadcast
- link is rejected when the host testRule denies the observer
- async testRule Future is awaited on link
- filter transforms the outgoing payload
- filter returning null drops the pulse
- + chains filters sequentially
- FilterRule.chain stops when a stage returns null
- FilterRule.base is an identity
- a throwing filter leaves the original pulse
- FilterRule.user is passed to the rule
- parent runs after the primary rule
- chain parent runs after the collected rules
- chain strategy overrides sequential rules and still calls parent
- fromRecord reconstitutes a callable rule
- equality and hashCode follow the flyweight record
- relay replaces sequential broadcast
- relay is skipped when every downstream already saw the pulse
- default strategy delivers immediately
- async strategy delivers on a later event-loop turn
- persistent replays the last pulse to a newly linked observer
- persistent with an existing observer stores and delivers
- async.call delivers to downstreams
- async.call on empty synapses completes without observers
- async.call on empty synapses completes a governed onComplete pulse
- async.call applies the source filter
- async.call respects a zero-duration debounce policy
- async.call respects a zero-duration throttle policy
- async.call batches until batchSize
- async.call with audit zero throttle delivers immediately
- async.call with debounceLeading zero throttle delivers
- async.call uses a custom relay
- async.call with async strategy delivers
- async.call with non-zero debounce delivers after the window
- async.call with non-zero throttle delivers the leading pulse
- async.call with audit non-zero window delivers the latest
- async.call buffered flushes on batchSize
- async.call buffered flushes after throttleTime
- async.call debounceLeading non-zero throttle delivers the first pulse
- async.call persistent delivers to current observers
- async.call on a revisited pulse does not re-notify
- async relay is skipped when every downstream already saw the pulse
- async debounce completes after observers are unlinked
- collective waits for all branches, including dead-end ones
- a governed pulse with onComplete fires once across two terminals
- fan-out completion fires only after the last terminal
- debounceLeading with zero throttle delivers every pulse
- buffered Duration.zero flushes on the first pulse
- debounced pulse completes after observers are unlinked
- filter plus relay plus policy is a valid synapses
- two synapses instances are not identical
- host synapses broadcast a bound source emission
- filter on the host synapses redacts before observers

### File 70: synthesis_cell_test.dart (37 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 37 |
| SynthesisCell | |
| Construction | |
| Aggregation | |
| Source Management | |
| Stop/Start | |
| Edge Cases & Error Handling | |
| Context & Governance | |
| Real-World Scenarios | |
| toString | |

**Tests**

- creates a synthesis cell with sources
- creates a synthesis cell with custom context
- creates a synthesis cell with custom test rule
- creates a synthesis cell with disabled synapses (terminal)
- creates a synthesis cell with forceLock
- empty sources does not throw
- aggregator combines values from multiple sources
- aggregator receives the emitting pulse
- aggregator can access all source values
- aggregator returning null suppresses emission
- aggregator with complex object types
- does not emit an initial aggregate
- synthesis cell is iterable over sources
- synthesis handle can add sources dynamically
- added source participates in aggregation
- synthesis handle can remove sources dynamically
- synthesis handle can add multiple sources
- synthesis handle can remove multiple sources
- synthesis handle can clear all sources
- synthesis handle reports isEmpty correctly
- synthesis handle toList returns current sources
- stop prevents aggregation from sources
- stop disconnects all sources but keeps membership
- handles null values from sources
- handles sources that are not ValueCell
- handles aggregator throwing exception gracefully
- handles removing non-existent source
- handles adding duplicate source
- synthesis cell does not inherit context from sources
- synthesis cell with custom context overrides
- synthesis cell validation rule applies to incoming pulses
- synthesis for form validation - all fields valid
- synthesis for price calculation with tax and discount
- synthesis for user profile - derived full name
- synthesis for counter - sum of multiple counters
- synthesis cell returns string representation
- synthesis cell shows sources in string representation

### File 71: test_cell_test.dart (45 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 45 |
| TestCell | |
| allowAll | |
| readOnly | |
| Construction | |
| Composition | |
| Exceptions | |
| Async | |
| TestPulseRule | |
| TestLinkRule | |
| TestActionRule | |
| Graph integration | |
| TestRule | |

**Tests**

- is a reusable TestPasses singleton
- allows every object
- allows links, pulses, and actions
- allowAll + customRule behaves like the custom rule
- is a reusable singleton
- allows observation of values and pulses
- blocks apply when the action is on the modifiable whitelist
- call on a Function consults action
- readOnly + customRule delegates to the custom rule
- TestPasses is the allowAll implementation
- readOnly action rejects every function — whitelisted or not
- custom rule allows matching values
- custom rule can inspect a Pulse payload
- user metadata is passed to the rule
- parent is evaluated after this rule passes
- + evaluates left to right and short-circuits
- TestCell.chain is fail-fast like +
- TestCell.chain honors parent without a strategy
- composed generic rules are consulted for action validation
- chains nest
- a throwing rule fails closed when the host is ungoverned
- a throwing rule with no host fails closed
- an async rule is awaited
- an async throwing rule fails cleanly for a governed host
- an async throwing rule fails closed for an ungoverned host
- accepts pulses that match the predicate
- non-pulse objects pass the wrapped call
- TestCell.pulse consults chained TestPulseRules
- TestCell.pulse awaits chained async TestPulseRules
- accepts links that match the predicate
- TestCell.link consults chained TestLinkRules
- TestCell.link awaits chained async TestLinkRules
- accepts actions that match the predicate
- TestCell.action validates positional arguments via call
- TestCell.action validates named arguments via call
- TestCell.action awaits chained async TestActionRules
- cell.validate uses the TestCell rule
- pulse validation on a cell drops odd payloads
- link is rejected when the host TestCell denies the observer
- an async rule still consults parent
- chain awaits an async rule and continues
- chain short-circuits later rules when an async rule fails
- chain rethrows an Exception from a child rule
- equality and hashCode follow the flyweight record
- fromRecord reconstitutes a callable rule

### File 72: test_chain_test.dart (4 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 4 |
| TestCell.chain preserves parent when strategy is null | |
| TestRule.chain preserves user when strategy is set | |
| TestRule.chain preserves parent when strategy is null | |

**Tests**

- parent is evaluated for the chain
- parent + user are both preserved
- strategy receives the configured user metadata
- parent is evaluated

### File 73: test_rule_meta_test.dart (49 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 49 |
| DefaultValue | |
| MaxLength | |
| direct field limit | |
| hostLength | |
| composite field + container | |
| host-only | |
| ValueRange | |
| EntryPattern | |
| Values | |
| EmailPattern | |
| WebsiteUrlPattern | |
| TestRule composition | |

**Tests**

- stores a primitive constant
- stores a string, bool, list, and map
- is a const annotation, not a TestRule
- allows a string at or under the limit
- rejects a string over the limit
- allows an iterable at or under the limit
- rejects an iterable over the limit
- passes non-string, non-iterable objects
- rejects when the host iterable exceeds hostLength
- allows a host iterable at the hostLength
- ignores a non-iterable host and still checks the object
- rejects an over-long element even when the host is in quota
- rejects an over-long host even when the element is in quota
- allows when both the element and the host are in quota
- checks a list object against length when no host is passed
- stores the sentinel direct length and the host limit
- does not limit the annotated object
- rejects an over-long host container
- passes when the host is absent
- stores inclusive bounds
- allows integers on the inclusive bounds
- rejects integers outside the range
- allows doubles on a unit interval
- passes null and non-numeric values
- always fails numbers when min is greater than max
- stores pattern flags with documented defaults
- matches a non-empty string against the pattern
- is case-insensitive by default
- honors caseSensitive: true
- rejects null unless allowNull is true
- rejects empty strings unless allowEmpty is true
- passes non-string objects
- allows members of the whitelist
- rejects values not in the whitelist
- rejects null unless null is listed
- matches numeric option sets by ==
- uses the documented default flags
- accepts typical email addresses
- rejects malformed addresses and empty strings
- allows null by default and can reject it
- accepts a custom corporate pattern
- uses the documented default flags
- accepts typical web addresses
- rejects empty strings and non-urls
- allows null by default and can reject it
- accepts a custom pattern
- MaxLength is a TestRule
- MaxLength + ValueRange short-circuits on the first failure
- TestRule.chain forwards user to a custom strategy

### File 74: transaction_test.dart (55 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 55 |
| Cell.transaction | |
| Basic Transaction | |
| Isolation Levels | |
| Lock Ordering | |
| Validation | |
| Custom Apply | |
| Savepoint | |
| Timeout | |
| Events | |
| Cell Types | |
| Real-World Scenarios | |
| Edge Cases & Error Handling | |
| Exception toString | |

**Tests**

- commits multiple updates atomically
- rollback discards all changes
- commit after rollback works
- cannot begin while transaction is active
- cannot update cell not in transaction
- cannot read cell not in transaction
- transaction with single cell
- empty cells list throws
- readCommitted reads current live values
- repeatableRead reads snapshot from begin
- repeatableRead detects conflict on changed cell
- serializable tracks read set
- serializable ignores unread, unwritten participant changes
- serializable commits globally serialized
- byHashCode orders locks by hash code
- insertion orders locks by insertion order
- explicit uses custom comparator
- explicit without comparator throws
- validation fails on invalid value
- custom validate callback can override
- multiple cells validation
- cell testRule rejects negatives at commit
- commit validates the pulse shape so TestPulseRules apply
- custom apply callback overrides default
- custom apply with side effects
- custom apply with multiple cells
- savepoint captures state for rollback
- multiple savepoint
- rollback to unknown savepoint throws
- savepoint after rollback
- transaction times out
- timeout triggers rollback
- timeout event emitted
- TransactionBegun event emitted
- TransactionUpdated event emitted
- TransactionCommitted event emitted
- TransactionRolledBack event emitted
- TransactionRolledBack with savepoint event emitted
- transaction with ValueCell
- transaction with non-ValueCell (CellBase)
- pending reads see buffered writes
- pending falls back to read
- bank transfer with validation to prevent negative
- bank transfer commits when balances stay non-negative
- multi-step operation with savepoint
- concurrent transactions isolation
- updating same cell multiple times uses last value
- rollback when no transaction active is no-op
- commit when no transaction active throws
- transaction with options and all callbacks
- transaction with null values
- transaction with non-int values
- TransactionValidationException toString
- TransactionConflictException toString
- TransactionTimeoutException toString

### File 75: tx_apply_test.dart (49 tests)

| Category (group) | Tests in file |
|------------------|--------------:|
| *(all groups)* | 49 |
| Cell.txApply | |
| Basic Operations | |
| Compensation | |
| Error Handling | |
| Stop On First Failure | |
| Savepoint | |
| Real-World Scenarios | |
| Events | |
| Edge Cases & Error Handling | |
| Custom Comparator | |
| Exception toString | |

**Tests**

- executes a single apply with txApply
- executes multiple applies with txApply
- txApply with multiple participants
- txApply with custom apply options
- apply without tx runs immediately
- compensation is called when a later apply fails
- compensation with custom cell
- compensation with multiple retries
- rollback before commit skips compensation by default
- compensateIfNotExecuted runs undo on rollback of staged calls
- txApply throws when participant not included
- enqueue accepts functions outside the modifiable manifest
- txApply with compensation error policy
- txApply with failFast compensation policy
- txApply with collectThenThrow compensation policy
- stopOnFirstFailure stops execution on first failure
- stopOnFirstFailure false continues execution
- a rejected command is not compensated when a later command 
- txApply savepoint captures state
- txApply rollback to savepoint
- txApply rollback all
- txApply rollback with unknown savepoint throws
- txApply rollback rejects a savepoint from another scope
- txApply for bank transfer with compensation
- oversized transfer rolls back via compensation
- txApply for multi-step data migration
- txApply for inventory adjustment
- TxApplyBegun event emitted
- TxApplyStaged event emitted
- TxApplyCommitted event emitted
- TxApplyRolledBack event emitted
- TxApplyRejected event emitted on gate rejection
- txApply with empty participants throws
- txApply commit without begin throws
- txApply with null compensation
- txApply with compensation cell different from operation cell
- txApply with compensation named arguments
- begin while already begun throws
- txApply with custom comparator
- TxApplyException toString
- TxApplyCompensationException toString
- enqueue rejects a compensate cell that is not a participant
- enqueue accepts a compensate function outside the manifest
- commit ignores manifest removal; the gate decides
- commit ignores compensate manifest removal; the gate decides
- default compensation backoff retries a transient undo
- compensation ApplyRejected is not retryable by default
- ApplyRejected during commit rethrows failFast compensation
- CompensationFailure toString

---

## Runtime Verification Status

Working directory: `packages/cell` (package-relative; host paths omitted).

If tests are named `test_*.dart` instead of `*_test.dart`, `dart test` with
no path finds nothing. Pass explicit files:

```bash
dart pub get
dart test \
  test/ai_guide_examples_test.dart \
  test/ai_preflight_test.dart \
  test/api_chooser_up_to_date_test.dart \
  test/apply_command_test.dart \
  test/cell_policy_test.dart \
  test/cell_test.dart \
  test/commons_test.dart \
  test/context_test.dart \
  test/deputy_test.dart \
  test/instruction_test.dart \
  test/nucleus_test.dart \
  test/operator_async_map_test.dart \
  test/operator_from_stream_test.dart \
  test/operators_advanced_transactions_test.dart \
  test/operators_async_routing_test.dart \
  test/operators_flow_control_test.dart \
  test/operators_foundation_test.dart \
  test/propagation_policy_test.dart \
  test/pulse_test.dart \
  test/receptor_instruction_future_test.dart \
  test/receptor_test.dart \
  test/cli_test.dart \
  test/canonical_json_test.dart \
  test/context_roundtrip_test.dart \
  test/fastpulse_rejected_test.dart \
  test/pulse_codec_test.dart \
  test/pulse_from_json_overrides_test.dart \
  test/pulse_from_json_test.dart \
  test/pulse_roundtrip_test.dart \
  test/pulse_sentinel_test.dart \
  test/pulse_to_json_test.dart \
  test/snapshot_roundtrip_test.dart \
  test/cycle_checker_reseeded_test.dart \
  test/divergence_effect_mismatch_test.dart \
  test/divergence_missing_effect_test.dart \
  test/divergence_pure_receptor_test.dart \
  test/pulse_codec_integration_test.dart \
  test/pulses_500_replay_test.dart \
  test/replay_identical_graph_test.dart \
  test/fork_at_seq_test.dart \
  test/fork_isolation_test.dart \
  test/fork_verify_requires_original_test.dart \
  test/whatif_replace_pulse_test.dart \
  test/effectful_testcell_replayed_test.dart \
  test/ephemeral_policy_tick_order_test.dart \
  test/readonlyexternal_testcell_reexecuted_test.dart \
  test/version_boundary_without_translator_test.dart \
  test/version_dispatch_test.dart \
  test/graph_snapshot_restore_test.dart \
  test/id_uniqueness_test.dart \
  test/purity_classification_test.dart \
  test/registration_test.dart \
  test/unregistered_bind_rejected_test.dart \
  test/async_map_records_effects_test.dart \
  test/debounce_timer_order_test.dart \
  test/from_stream_ordering_test.dart \
  test/null_journal_rejects_effectful_test.dart \
  test/pure_receptor_no_journal_test.dart \
  test/reordered_effects_diverge_test.dart \
  test/append_and_verify_test.dart \
  test/append_outside_apply_rejected_test.dart \
  test/file_store_roundtrip_test.dart \
  test/state_delta_capture_test.dart \
  test/tamper_detection_test.dart \
  test/ledger_store_conformance.dart \
  test/replay_contract_test.dart \
  test/review_hardening_test.dart \
  test/seam_test.dart \
  test/synapses_test.dart \
  test/synthesis_cell_test.dart \
  test/test_cell_test.dart \
  test/test_chain_test.dart \
  test/test_rule_meta_test.dart \
  test/transaction_test.dart \
  test/tx_apply_test.dart
```

### Last `dart test`

| Passed | Failed | Skipped | Exit |
|-------:|-------:|--------:|-----:|
| 1431 | 0 | 0 | 0 |

Status: **green**.

<details><summary>tail of test log</summary>

```
0:04 +1415: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1416: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1417: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1418: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1419: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1420: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1421: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1422: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1423: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1424: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1425: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1426: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1427: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1428: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1429: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:04 +1430: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:05 +1430: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:06 +1430: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:06 +1431: test/replay/engine/pulses_500_replay_test.dart: 500 pulses replay deterministically with effects                                                                                          
00:06 +1431: All tests passed!
```

</details>

### Line Coverage (`lib/`)

**Overall: 3586 / 3836 lines = 93.5%**

| File | Hit | Found | Line % |
|------|----:|------:|-------:|
| `lib/src/deputy.dart` | 10 | 10 | 100.0 |
| `lib/src/internal/cell.dart` | 125 | 125 | 100.0 |
| `lib/src/internal/operator/operator_debounce.dart` | 35 | 35 | 100.0 |
| `lib/src/internal/pulse_extensions.dart` | 19 | 19 | 100.0 |
| `lib/src/internal/test_cell.dart` | 33 | 33 | 100.0 |
| `lib/src/internal/value.dart` | 12 | 12 | 100.0 |
| `lib/src/nucleus.dart` | 5 | 5 | 100.0 |
| `lib/src/pulse.dart` | 4 | 4 | 100.0 |
| `lib/src/receptor.dart` | 62 | 62 | 100.0 |
| `lib/src/synapses.dart` | 25 | 25 | 100.0 |
| `lib/src/test_rule.dart` | 40 | 40 | 100.0 |
| `lib/src/test_rule_meta.dart` | 30 | 30 | 100.0 |
| `lib/src/value.dart` | 88 | 88 | 100.0 |
| `lib/src/internal/operator/operator_transaction.dart` | 172 | 173 | 99.4 |
| `lib/src/internal/synapses.dart` | 463 | 468 | 98.9 |
| `lib/src/test_cell.dart` | 79 | 80 | 98.8 |
| `lib/src/internal/operator/operator_tx_apply.dart` | 174 | 178 | 97.8 |
| `lib/src/internal/cell_policy.dart` | 43 | 44 | 97.7 |
| `lib/src/internal/operator/operator_async_map.dart` | 41 | 42 | 97.6 |
| `lib/src/internal/commons.dart` | 284 | 291 | 97.6 |
| `lib/src/internal/operator/operators.dart` | 97 | 100 | 97.0 |
| `lib/src/internal/receptor.dart` | 190 | 196 | 96.9 |
| `lib/src/internal/deputy_context.dart` | 133 | 138 | 96.4 |
| `lib/src/internal/operator/operator_hub.dart` | 93 | 99 | 93.9 |
| `lib/src/internal/context.dart` | 112 | 120 | 93.3 |
| `lib/src/cell.dart` | 52 | 56 | 92.9 |
| `lib/src/internal/operator/operator_throttle.dart` | 37 | 40 | 92.5 |
| `lib/src/context.dart` | 150 | 166 | 90.4 |
| `lib/src/internal/pulse_context.dart` | 271 | 308 | 88.0 |
| `lib/src/internal/nucleus.dart` | 203 | 233 | 87.1 |
| `lib/src/internal/pulse_policy.dart` | 33 | 38 | 86.8 |
| `lib/src/internal/pulse.dart` | 449 | 549 | 81.8 |
| `lib/src/internal/deputy.dart` | 22 | 29 | 75.9 |

---

## Recommendations

1. Keep this report generated — do not hand-count `test(`.
2. CI should pass the explicit file list below (or a `dart_test.yaml`) because `cell` uses `test_*.dart` naming.
3. The operator phase files (`test_operators_phase*.dart`) exercise the instruction pipeline; keep them in sync with `lib/src/internal/operator/`.
4. Cross-package dependents (`cell_tissue`, `cell_flow`) rely on these contracts — add integration tests when the core APIs change.
5. Track coverage per public/internal pair (`lib/src/*.dart` vs `lib/src/internal/*.dart`), not just the whole `lib/` average.
6. Keep the Causal Replay suites (`test/replay/`) green — `replay_contract_test.dart` is the conformance harness for every `LedgerStore` implementation, and the engine's determinism gate lives in the replay suite.
7. The report inventories both halves of the package — `lib/src/` and `lib/replay/` (Source Under Test) with `test/` and `test/replay/` (the suites) — so new replay tests and new replay sources should appear together in the next generation.

---

## Appendix: File Locations

```
test/
├── ai_guide_examples_test.dart  (3 tests, 1.9 KB, 46 lines)
├── ai_preflight_test.dart  (1 tests, 0.8 KB, 22 lines)
├── api_chooser_up_to_date_test.dart  (1 tests, 1.0 KB, 27 lines)
├── apply_command_test.dart  (12 tests, 8.8 KB, 283 lines)
├── cell_policy_test.dart  (39 tests, 21.8 KB, 646 lines)
├── cell_test.dart  (78 tests, 45.0 KB, 1,264 lines)
├── commons_test.dart  (49 tests, 15.6 KB, 509 lines)
├── context_test.dart  (117 tests, 62.4 KB, 1,636 lines)
├── deputy_test.dart  (26 tests, 11.9 KB, 352 lines)
├── instruction_test.dart  (23 tests, 12.4 KB, 361 lines)
├── nucleus_test.dart  (40 tests, 12.6 KB, 366 lines)
├── operator_async_map_test.dart  (2 tests, 2.8 KB, 100 lines)
├── operator_from_stream_test.dart  (3 tests, 3.4 KB, 120 lines)
├── operators_advanced_transactions_test.dart  (39 tests, 25.1 KB, 800 lines)
├── operators_async_routing_test.dart  (63 tests, 36.2 KB, 1,133 lines)
├── operators_flow_control_test.dart  (45 tests, 25.6 KB, 838 lines)
├── operators_foundation_test.dart  (65 tests, 37.3 KB, 1,066 lines)
├── propagation_policy_test.dart  (37 tests, 24.9 KB, 680 lines)
├── pulse_test.dart  (159 tests, 71.2 KB, 1,908 lines)
├── receptor_instruction_future_test.dart  (2 tests, 2.5 KB, 84 lines)
├── receptor_test.dart  (54 tests, 28.1 KB, 782 lines)
├── replay/cli_test.dart  (15 tests, 10.8 KB, 334 lines)
├── replay/codec/canonical_json_test.dart  (13 tests, 4.7 KB, 144 lines)
├── replay/codec/context_roundtrip_test.dart  (8 tests, 6.4 KB, 190 lines)
├── replay/codec/fastpulse_rejected_test.dart  (4 tests, 2.9 KB, 75 lines)
├── replay/codec/pulse_codec_test.dart  (20 tests, 7.7 KB, 245 lines)
├── replay/codec/pulse_from_json_overrides_test.dart  (19 tests, 5.7 KB, 187 lines)
├── replay/codec/pulse_from_json_test.dart  (9 tests, 4.1 KB, 130 lines)
├── replay/codec/pulse_roundtrip_test.dart  (7 tests, 6.6 KB, 206 lines)
├── replay/codec/pulse_sentinel_test.dart  (4 tests, 2.0 KB, 58 lines)
├── replay/codec/pulse_to_json_test.dart  (3 tests, 1.3 KB, 39 lines)
├── replay/codec/snapshot_roundtrip_test.dart  (9 tests, 4.2 KB, 126 lines)
├── replay/engine/cycle_checker_reseeded_test.dart  (1 tests, 2.5 KB, 76 lines)
├── replay/engine/divergence_effect_mismatch_test.dart  (2 tests, 3.5 KB, 123 lines)
├── replay/engine/divergence_missing_effect_test.dart  (1 tests, 2.5 KB, 86 lines)
├── replay/engine/divergence_pure_receptor_test.dart  (2 tests, 2.7 KB, 85 lines)
├── replay/engine/pulse_codec_integration_test.dart  (5 tests, 3.6 KB, 106 lines)
├── replay/engine/pulses_500_replay_test.dart  (1 tests, 2.1 KB, 61 lines)
├── replay/engine/replay_identical_graph_test.dart  (3 tests, 3.0 KB, 97 lines)
├── replay/fork/fork_at_seq_test.dart  (2 tests, 3.1 KB, 88 lines)
├── replay/fork/fork_isolation_test.dart  (1 tests, 2.0 KB, 65 lines)
├── replay/fork/fork_verify_requires_original_test.dart  (3 tests, 4.5 KB, 157 lines)
├── replay/fork/whatif_replace_pulse_test.dart  (2 tests, 3.8 KB, 113 lines)
├── replay/governance/effectful_testcell_replayed_test.dart  (2 tests, 3.1 KB, 92 lines)
├── replay/governance/ephemeral_policy_tick_order_test.dart  (2 tests, 3.1 KB, 91 lines)
├── replay/governance/readonlyexternal_testcell_reexecuted_test.dart  (2 tests, 3.0 KB, 95 lines)
├── replay/governance/version_boundary_without_translator_test.dart  (4 tests, 6.6 KB, 195 lines)
├── replay/governance/version_dispatch_test.dart  (6 tests, 4.1 KB, 139 lines)
├── replay/graph/graph_snapshot_restore_test.dart  (4 tests, 3.7 KB, 101 lines)
├── replay/graph/id_uniqueness_test.dart  (5 tests, 1.9 KB, 57 lines)
├── replay/graph/purity_classification_test.dart  (6 tests, 3.0 KB, 82 lines)
├── replay/graph/registration_test.dart  (4 tests, 1.2 KB, 40 lines)
├── replay/graph/unregistered_bind_rejected_test.dart  (4 tests, 2.2 KB, 61 lines)
├── replay/journal/async_map_records_effects_test.dart  (1 tests, 3.2 KB, 94 lines)
├── replay/journal/debounce_timer_order_test.dart  (2 tests, 4.1 KB, 132 lines)
├── replay/journal/from_stream_ordering_test.dart  (2 tests, 2.1 KB, 66 lines)
├── replay/journal/null_journal_rejects_effectful_test.dart  (5 tests, 2.9 KB, 96 lines)
├── replay/journal/pure_receptor_no_journal_test.dart  (3 tests, 1.5 KB, 47 lines)
├── replay/journal/reordered_effects_diverge_test.dart  (7 tests, 4.9 KB, 170 lines)
├── replay/ledger/append_and_verify_test.dart  (2 tests, 1.5 KB, 47 lines)
├── replay/ledger/append_outside_apply_rejected_test.dart  (6 tests, 4.4 KB, 134 lines)
├── replay/ledger/file_store_roundtrip_test.dart  (2 tests, 3.1 KB, 88 lines)
├── replay/ledger/state_delta_capture_test.dart  (5 tests, 4.1 KB, 122 lines)
├── replay/ledger/tamper_detection_test.dart  (3 tests, 4.7 KB, 163 lines)
├── replay/ledger_store_conformance.dart  (6 tests, 5.9 KB, 189 lines)
├── replay/replay_contract_test.dart  (0 tests, 1.6 KB, 50 lines)
├── replay/review_hardening_test.dart  (35 tests, 41.4 KB, 1,244 lines)
├── seam_test.dart  (2 tests, 1.7 KB, 46 lines)
├── synapses_test.dart  (75 tests, 37.3 KB, 1,136 lines)
├── synthesis_cell_test.dart  (37 tests, 21.0 KB, 627 lines)
├── test_cell_test.dart  (45 tests, 23.0 KB, 665 lines)
├── test_chain_test.dart  (4 tests, 2.8 KB, 84 lines)
├── test_rule_meta_test.dart  (49 tests, 12.2 KB, 366 lines)
├── transaction_test.dart  (55 tests, 36.6 KB, 1,227 lines)
├── tx_apply_test.dart  (49 tests, 35.7 KB, 1,140 lines)
```

**Total lines of test code:** 24,700

*Generated 2026-11-19 by generate_test_verification.py*
