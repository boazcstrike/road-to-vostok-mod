# Threaded Scoring Shadow Mode (Phase 1) - Task Context

## Assumptions
- Phase 1 should wire a shadow-only threaded scoring path in `AI.gd` without changing target commit authority.
- Existing target selection behavior (`_acquire_best_target`) must remain authoritative.
- Small defaults should minimize runtime impact when enabled.

## Scope (This Phase)
- Add shadow threading scaffolding in `BosWar/AI.gd`:
  - per-AI single in-flight job
  - immutable snapshot payload for worker scoring
  - stale-result dropping by frame stamp
  - compare-only path against authoritative target result
  - debug counters for submitted/completed/stale
- Add four settings in `BosWar/EnemyAISettings.gd`:
  - `enable_threaded_scoring_shadow_mode`
  - `threaded_scoring_cohort_modulo`
  - `threaded_scoring_top_k`
  - `show_threaded_scoring_stats`
- Add matching defaults in `BosWar/EnemyAISettings.tres`.
- Document intent and verification in this context file.

## Decisions / Tradeoffs
- Keep authoritative state writes on main thread:
  - Worker output is compare-only in Phase 1.
  - Tradeoff: no direct gameplay/perf win yet from commit path changes.
- Add explicit shadow-runtime cleanup:
  - Drain/clear shadow thread state when AI is dead/paused.
  - Clear shadow buffers when targeting gate is off.
  - Tradeoff: clearing `last_consumed_submit_frame` resets stale history after gate-off/death, which is acceptable for Phase 1 diagnostics.
- `enable_threaded_scoring_shadow_mode = false` by default:
  - Keeps current gameplay behavior unchanged.
- `threaded_scoring_cohort_modulo = 4`:
  - Reasonable small cohort gate for phased/partial shadow evaluation.
  - Tradeoff: lower modulo would increase coverage and cost.
- `threaded_scoring_top_k = 3`:
  - Small shortlist for initial shadow scoring signals.
  - Tradeoff: larger `top_k` gives more data but higher compute.
- `show_threaded_scoring_stats = false`:
  - Avoid extra log/overlay noise until actively debugging rollout.

## Verification Checklist (Binary)
- [x] `AI.gd` includes a shadow-only threaded scoring job path.
- [x] Shadow path does not commit gameplay state changes from worker thread.
- [x] Shadow worker results are consumed before any early return in hostile-target update flow.
- [x] Dead/pause path clears and drains shadow runtime state.
- [x] Targeting gate-off path clears shadow buffers to avoid dirty state carryover.
- [x] `EnemyAISettings.gd` contains all four new export vars.
- [x] `EnemyAISettings.gd` keeps naming/style consistent with current file.
- [x] `EnemyAISettings.tres` contains all four new keys with defaults.
- [x] Thread lifecycle has explicit cleanup path.

## Next Steps
- Run live log validation for thread lifecycle and stale-drop counters under combat load.
- Compare shadow top choice vs authoritative target over multiple scenarios.
- Phase 2: use worker shortlist for top-N main-thread LOS validation and controlled commit.
