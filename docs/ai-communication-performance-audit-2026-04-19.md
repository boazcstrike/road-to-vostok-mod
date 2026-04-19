# AI Communication Performance Audit (2026-04-19)

## Scope
- Investigate communication-update workload in `BosWar/AI.gd`.
- Inspect `BosWar/AISpawner.gd` for system-level opportunities (scheduling/cohorting/cache) that can reduce communication overhead without behavior changes.

## Assumptions
- "Without changing behavior" means no changes to targeting outcomes, hostility gates, combat-state transitions, or communication ranges/cooldowns.
- Recommendations can add data structures/caches/cohort schedulers as long as they preserve current observable gameplay semantics.

## Cross-Call Map (Communication Frequency Relevant)
- `AI.Parameters(delta)` calls `_update_hostile_ai_targeting(delta)` every tick (`BosWar/AI.gd:89-93`).
- `_update_hostile_ai_targeting` drives:
  - target acquisition/refresh timers (`BosWar/AI.gd:827-843`)
  - visibility refresh (`BosWar/AI.gd:868-870`)
  - shadow scoring submission (`BosWar/AI.gd:872`)
- Broadcast sources fan out into teammate scans:
  - player LOS upgrade (`BosWar/AI.gd:746-750`)
  - audio hearing/fire detection (`BosWar/AI.gd:161`, `BosWar/AI.gd:175`, `BosWar/AI.gd:183`)
  - best-target acquisition (`BosWar/AI.gd:1450`, `BosWar/AI.gd:1476`)
  - AI target quality upgrade (`BosWar/AI.gd:1650`)
- Broadcast and teammate-count receivers both iterate full `AISpawner.agents` child lists (`BosWar/AI.gd:1961-1978`, `BosWar/AI.gd:2059-2077`).

## Findings

### [P1] Repeated full-list teammate scans in hot paths
- Evidence:
  - Broadcast loop traverses all agents for each event (`BosWar/AI.gd:1961-1978`).
  - Teammate targeting count traverses all agents during decision pressure (`BosWar/AI.gd:2059-2077`, called from `BosWar/AI.gd:207`).
  - Additional full-list scans also occur in `_find_audible_hostile_target` (`BosWar/AI.gd:1262-1273`) and `_acquire_best_target` (`BosWar/AI.gd:1333-1357`).
- Impact:
  - Cost scales roughly O(N) per AI per event and compounds during combat bursts.
  - `AISpawner.activeAgents` up to high presets makes this a likely frame-time hotspot.
- Behavior-preserving optimization:
  - Add spawner-maintained live cohorts by faction/team (`alive_by_faction`, optional `alive_by_team`) updated on spawn/death.
  - Replace `agents.get_children()` scans in broadcast/count paths with cohort iteration.
  - Keep existing per-child dead/pause checks so semantics remain unchanged.

### [P1] Threaded shadow scoring still rebuilds full candidate snapshots per AI
- Evidence:
  - `_submit_shadow_scoring_job_if_due` can run once per agent according to cohort frame slot (`BosWar/AI.gd:874-901`).
  - `_build_shadow_scoring_payload` still iterates all agents and computes candidate metrics each submission (`BosWar/AI.gd:950-967`).
- Impact:
  - Threading offloads scoring, but main-thread candidate construction remains O(N) per submitter.
  - Many short-lived `Thread.new()` instances increase scheduling churn under load.
- Behavior-preserving optimization:
  - System-level queue at spawner: one shared scoring worker (or bounded pool) consuming batched AI jobs.
  - Cache per-frame hostile candidate snapshots at spawner level keyed by requester faction/team and frame id.
  - Preserve current scoring formula and top-k behavior exactly (`BosWar/AI.gd:980-1059`).

### [P2] Spawn-point validation recomputation increases background pressure
- Evidence:
  - `_find_available_spawn_point` calls `_get_valid_spawn_points` (`BosWar/AISpawner.gd:1006`).
  - `_get_valid_spawn_points` re-runs expensive floor/safe-position checks for each spawn point each time (`BosWar/AISpawner.gd:215-225`, via `_is_spawn_point_valid`).
- Impact:
  - Heavy physics queries compete with AI communication loops, especially during frequent spawn attempts.
- Behavior-preserving optimization:
  - Cache static validity per spawn point (geometry-safe or not), invalidate only if map changes.
  - Keep dynamic filters (player distance, occupied points) evaluated per request to preserve behavior.

### [P2] Team reservation cleanup uses full agent scan on replenish path
- Evidence:
  - `_check_and_release_defeated_team_spawn_points` scans all agents (`BosWar/AISpawner.gd:1052-1061`).
  - It is called from replenish (`BosWar/AISpawner.gd:700-702`) and also when spawn points are exhausted (`BosWar/AISpawner.gd:1009-1012`).
- Impact:
  - Extra O(N) work during deaths/spawn churn adds contention with communication updates.
- Behavior-preserving optimization:
  - Maintain `alive_count_by_team_id` in spawner; update on spawn/death and release reservation when count reaches 0.
  - Keep fallback periodic reconciliation scan for safety/debug parity.

## Recommended Rollout Order (Minimal-Risk)
1. Introduce spawner-side alive cohort caches; wire read-only use first in AI broadcast/count paths.
2. Add optional shared scoring queue/candidate snapshot cache behind feature flag.
3. Add spawn-point static-validity cache and team alive-count bookkeeping.
4. Validate parity with existing debug logs/status events and combat outcomes before enabling by default.

## Outcome
- No code changed in this audit.
- Primary optimization leverage is at spawner/system level via cohort + cache infrastructure, then consumed by existing AI methods without semantic changes.
