# 1.0 Gate Evaluation

**Date:** 2026-11-13

| Gate | Artifact | Result |
|---|---|---|
| G1 | Documentation accuracy | ✅ PASS |
| G2 | 100% coverage on `lib/src/*` | ✅ PASS (20 files, 100%) |
| G3 | Benchmark within 1.5× of `ValueListenableBuilder` | ❌ FAIL (10 builders 2.31×, 100 builders 2.93× p50; single-builder 1.25× passes) |
| G4 | Both guides complete; snippets compile via extraction | ✅ PASS (15 extracted tests) |
| G5 | Accessibility audit clean | ✅ PASS (11 tests) |
| G6 | Fuzz clean incl. replay probes | ⚠️ PASS on smoke (9 tests); full 30-minute run blocked by this sandbox's OS thread limit — wired into CI |
| G7 | Soak clean incl. debounce-burst + throttle | ✅ PASS (attributable growth +2.7%, timers flat) |
| G8 | Security review sign-off | ✅ PASS (no findings above low) |
| G9 | Link check clean | ✅ PASS (44 local references) |
| G10 | Usability test passed by an external developer | ❌ BLOCKED — no external developer available (cannot be honestly self-tested) |

**Overall: FAIL → no 1.0.0.**

Per the phase plan's decision procedure, a failed gate means
`cell_flutter` stays on `0.5.x` and a **0.6.0 hardening release**
carries the fixes and artifacts. G10 is blocked on a human resource, not
a code defect; G3's fix is a `cell`-core optimization tracked for the
next hardening cycle; G6's full run is scheduled on CI.

**Soft gates:**

| Gate | Artifact | Status |
|---|---|---|
| S1 | External adopter report | ❌ gap documented — no external production usage yet |
