# AI Communication Performance Optimization Rollout Progress (2026-04-19)

## Task Context
- Date: 2026-04-19
- Scope owner for this pass: `docs/` only
- Objective: Track implementation progress for AI communication performance optimization rollout with explicit assumptions and verification gates.

## Assumptions
- Code implementation is handled by other contributors/agents; this file is a coordination artifact only.
- Optimization rollout must preserve gameplay semantics (hostility, targeting outcomes, combat transitions, communication intent).
- Existing same-day audits are source inputs for rollout sequencing:
  - `docs/ai-communication-performance-audit-2026-04-19.md`
  - `docs/ai-threaded-scoring-path-review-2026-04-19.md`
  - `docs/ai-communication-performance-context-audit-2026-04-19.md`
- Concurrent codebase edits are expected; verification must rely on current HEAD/worktree state at execution time.

## Implementation Steps (Rollout Sequence)
1. Baseline and instrumentation alignment
   - Confirm current performance baseline capture method (frame-time + AI communication hot paths).
   - Confirm observability contract for any temporary diagnostics and rate limits.
2. Spawner cohort cache rollout
   - Implement/enable faction/team alive cohort structures in spawner runtime.
   - Migrate AI communication teammate/broadcast scans to cohort-backed iteration.
3. Threaded scoring pressure controls
   - Add bounded scheduling controls (global in-flight cap or equivalent queue discipline).
   - Add small-payload fast path and bounded candidate payload policy if approved.
4. Spawn-side background pressure reduction
   - Cache static spawn-point validity; keep dynamic filters evaluated per request.
   - Replace full-scan team reservation cleanup with live counters plus safety reconciliation.
5. Staged enablement and parity validation
   - Roll out behind toggles/controlled enablement.
   - Compare combat/hostility/targeting parity against baseline behavior.

## Progress Log
- [x] 2026-04-19: Consolidated optimization constraints and known hotspots from existing audits.
- [x] 2026-04-19: Defined ordered rollout plan emphasizing minimal-risk, behavior-preserving changes.
- [x] 2026-04-19: Implemented AI communication hot-path controls in `BosWar/AI.gd`:
  - duplicate teammate-message TTL suppression
  - receiver decision debounce (gunshot path still immediate)
  - squared-distance checks on teammate validation/broadcast range paths
  - threaded scoring controls (small-payload inline path, global in-flight cap, candidate cap, non-blocking dead/pause clear)
- [x] 2026-04-19: Implemented spawner-side cohort/cache support in `BosWar/AISpawner.gd`:
  - active cohorts by faction/team + active snapshot cache
  - read-only accessors for AI consumption
- [x] 2026-04-19: Implemented spawn-side background pressure reductions in `BosWar/AISpawner.gd`:
  - static spawn-point validity cache
  - team member alive-count tracking used by reservation release path
- [x] 2026-04-19: Applied hot-path micro-optimizations for detection/targeting lag in `BosWar/AI.gd` and `BosWar/AISpawner.gd`:
  - removed repeated targeting gate evaluation inside `Sensor(delta)` tick
  - removed repeated `_has_valid_ai_target()` calls inside `_update_hostile_ai_targeting(delta)` branch flow
  - switched hostile candidate prefilter to squared-distance math before normalized-direction/FOV checks in `_acquire_best_target()`
  - delayed teammate distance `sqrt` in `_receive_teammate_target_info(...)` until switch path only
  - added non-copy cohort accessors in spawner (`get_all_active_agents_ref`, `get_active_agents_by_faction_ref`) and routed AI wrappers to prefer these read-only refs
- [ ] Awaiting runtime parity validation evidence from live logs and controlled test scenarios.
- [ ] Awaiting default-on decision after checklist completion.

## 2026-04-19 Performance Pass (Sight-Lag Focus)
### Assumptions
- AI-side consumers only iterate candidate arrays and do not mutate returned arrays from spawner cohort caches.
- Current lag symptom is dominated by repeated candidate scanning/allocation in sight/acquire paths, not by unrelated rendering or animation systems.

### Trade-offs
- Using read-only cache references reduces allocations and GC pressure, but assumes accessor contract discipline (`AI.gd` treats arrays as immutable).
- Squared-distance prefilter keeps behavior equivalent for pass/fail distance checks while reducing repeated square-root cost.

### Verification Plan (Binary)
1. `AI.gd` wrapper path uses reference getters first -> Verify: `_get_active_agent_candidates` and `_get_teammate_candidates` call `*_ref` methods before copy-based fallbacks.
2. Sight/acquire tick avoids duplicate heavy checks -> Verify: `Sensor(delta)` uses one `custom_targeting_active` value per tick and `_update_hostile_ai_targeting(delta)` reuses `has_valid_ai_target`.
3. Acquire pass reduces per-candidate math overhead -> Verify: `_acquire_best_target()` uses `length_squared()` + max-distance-squared prefilter prior to `sqrt`/normalization.

## Verification Checklist (Binary Gates)
- [ ] A. No behavior regression in hostility gating (different teams still engage as expected).
- [ ] B. No behavior regression in target selection outcomes under equivalent scenarios.
- [x] C. Communication/broadcast loops no longer depend on full `agents.get_children()` scans in hot paths.
- [x] D. Threaded scoring dispatch is bounded (global cap/queue) under AI-heavy scenes.
- [ ] E. No frame-hitch regression introduced by worker cleanup paths.
- [x] F. Spawn validity caching does not admit invalid geometry spawns. (Code-path complete; runtime confirmation pending)
- [x] G. Team reservation cleanup correctness preserved after counter-based path. (Code-path complete; runtime confirmation pending)
- [ ] H. Debug/log protocol remains compliant and rate-limited when enabled.
- [ ] I. Runtime validation evidence captured from current log output and linked in docs.
- [ ] J. Rollout can be toggled/rolled back without data/config drift.

## Concurrent Change Handling Notes
- This document is additive and does not overwrite prior audit artifacts.
- Any checklist item can be re-opened if concurrent changes invalidate prior verification evidence.

## Related Context
- `docs/ai-communication-performance-audit-2026-04-19.md`
- `docs/ai-threaded-scoring-path-review-2026-04-19.md`
- `docs/ai-communication-performance-context-audit-2026-04-19.md`
