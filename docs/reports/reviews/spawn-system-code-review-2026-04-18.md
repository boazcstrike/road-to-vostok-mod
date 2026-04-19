# spawn-system-code-review-2026-04-18

## Task
Review spawn system code path until an AI agent is spawned and fix concrete errors.

## Date
2026-04-18

## Scope
- `BosWar/AISpawner.gd` path from `_ready()` through initial and runtime spawning.
- Review and patch only issues that directly affect spawn correctness or traceability.

## Assumptions
- Spawn flow is centered in `AISpawner.gd`, with base behavior inherited from `res://Scripts/AISpawner.gd`.
- No changes should be made outside requested spawn-path logic.

## Spawn Path Reviewed
1. `_ready()`
2. `CreatePools()`
3. `_spawn_initial_population()`
4. `SpawnWanderer()`
5. `_spawn_team_wanderer()`
6. `_find_available_spawn_point()`
7. `_spawn_team_at_location()`
8. `_handle_spawn_result()`

## Findings
1. **Weighted faction spawn ratio bug**  
   `_build_faction_pool()` built a weighted default pool (10:3:1) then always deduped it, collapsing selection to effectively 1:1:1.
2. **Spawn-point validation ordering issue**  
   `_ready()` measured valid spawn points before loading `spawnDistance` from settings, so initial spawn-point audit/logging could be based on stale/default distance.

## Changes Made
- In `_build_faction_pool()`:
  - Keep dedupe only for custom mode branch.
  - Preserve weighted pool for default branch.
- In `_ready()`:
  - Move valid spawn-point count logging to run after `spawnDistance` is assigned from `EnemyAISettings`.

## Tradeoffs
- Did not refactor team-occupancy bookkeeping in this task because it is broader than direct "spawn until agent creation" correctness.

## Outcome
- Default faction mix now honors intended weighted random distribution.
- Initial spawn-point validity logging now reflects active configuration values.

## Follow-up Audit (Ratio/Cap Incident)
### Incident
- Reported runtime symptom: military spawned 12 while bandit spawned 0, despite intended ratio `10:3:1` and intended caps `bandit<=8`, `guard<=4`, `military<=3`.

### Scope
- `BosWar/AISpawner.gd`
- Immediate settings path: `BosWar/EnemyAISettings.gd`, `BosWar/EnemyAISettings.tres`, `BosWar/Config.gd`
- Immediate caller path affecting pool composition after deaths: `BosWar/AI.gd::Death() -> replenish_regular_pool()`

### Findings
1. Ratio logic is bypassed whenever any spawn mode is non-zero (`_build_faction_pool()` custom-mode branch).  
   In that branch, weighted `10:3:1` is not used at all; only deduped presence/absence is used.
2. Current MCM defaults seed all three spawn modes to `On` (`1`) instead of `Map Default` (`0`), so the ratio path is skipped by default for new configs.
3. No per-faction live caps are enforced anywhere in the team-spawn path; only global `spawnLimit` is enforced.
4. Team-size settings currently allow larger teams than the reported intended caps (`bandit max 10`, `guard max 5`, `military max 5`), and team spawning is enabled by default.

### Likely Root Cause Path for 12/0
1. Config sets `bandit_spawn_mode/guard_spawn_mode/military_spawn_mode` to `1` by default.
2. `_build_faction_pool()` enters custom-mode path and drops weighted ratio logic.
3. `CreatePools()` and `_spawn_team_wanderer()` select from non-weighted faction availability.
4. `_spawn_team_at_location()` enforces only global slot availability (`spawnLimit - activeAgents`), not faction caps.
5. Result: composition can skew heavily (including military-heavy and bandit-starved runs), bounded only by global cap and pool randomness.

### Minimal Fix Locations (No Code Applied In This Audit)
- `BosWar/Config.gd`: dropdown default/value for spawn modes should align with `Map Default` if ratio behavior is desired as baseline.
- `BosWar/AISpawner.gd::_build_faction_pool()`: preserve weighted behavior when all modes are effectively default, or explicitly weight custom "On" modes.
- `BosWar/AISpawner.gd::_spawn_team_at_location()` and/or caller gate before spawn: enforce per-faction live caps (`8/4/3`) against current active composition.
- `BosWar/EnemyAISettings.gd` (+ optional `.tres` serialization): align exported team-size maxima with intended caps to prevent oversized single-faction team bursts.

## Cross-References
- `docs/context/README.md`
- `docs/domains/spawn-orchestration-and-population/README.md`

---

## Follow-Up (2026-04-18): Military Overspawn / Bandit Starvation

### Reported Symptom
- Military spawned up to 12 in one startup sequence while bandit spawned none.
- Expected behavior: ratio `10:3:1` (bandit:guard:military) with team max caps `bandit<=8`, `guard<=4`, `military<=3`.

### Assumptions
- Ratio requirement applies to weighted faction selection in regular/team wanderer spawning.
- Team max caps are hard constraints even if config/resource data drifts.
- Keep edits scoped to spawn composition and team-size enforcement; no broad spawn-loop redesign in this pass.

### Root Causes Confirmed
1. Spawn-mode defaults were set to `On` (`1`) in `Config.gd`, which forced the custom-mode path.
2. Custom-mode faction pool path collapsed to unweighted availability via dedupe, bypassing weighted behavior.
3. Team-size exports and runtime selection still allowed larger teams (`10/5/5`) than requested caps.

### Changes Made
- `BosWar/AISpawner.gd`
  - Preserved weighted pool entries for custom spawn-mode paths using ratio weights (`10/3/1`) instead of deduping to equal-probability entries.
  - Added hard runtime clamp for team sizes via `_roll_team_size(...)`:
    - Bandit max `8`
    - Guard max `4`
    - Military max `3`
- `BosWar/Config.gd`
  - Changed `bandit_spawn_mode`, `guard_spawn_mode`, `military_spawn_mode` defaults and initial values from `1` (`On`) to `0` (`Map Default`).
- `BosWar/EnemyAISettings.gd`
  - Aligned exported team-size ranges with requested caps (`3-8`, `2-4`, `2-3`).

### Verification Plan
1. Validate ratio branch behavior.
   - Verify: custom-mode path no longer dedupes weighted entries.
2. Validate team-size hard caps.
   - Verify: all faction team-size rolls are clamped to `8/4/3`.
3. Validate config defaults.
   - Verify: spawn-mode dropdown defaults/values are `0` (`Map Default`).

### Verification Outcome
- Code-level verification passed for all three checks via targeted line inspection.
- Runtime playtest in Godot is still required to confirm distribution behavior over time.

## Follow-Up (2026-04-18): Initial Spawn Count Accuracy

### Reported Concern
- Initial spawns must be counted accurately; startup burst behavior was still potentially inflating faction counts.

### Root Cause Confirmed
- `_spawn_initial_population(count)` iterated by attempts (`for attempt in count`) while each team-mode attempt could spawn multiple agents.
- Result: startup could exceed intended initial agent target even when count looked small.

### Changes Made
- `BosWar/AISpawner.gd`
  - Added `initial_spawn_remaining` runtime budget tracking.
  - Reworked `_spawn_initial_population(count)` to target actual spawned agents:
    - Computes `target_spawn_count` by available slots.
    - Loops until spawned agent count reaches target or spawning fails.
    - Tracks per-attempt spawned delta (`activeAgents - before`).
  - In `_spawn_team_at_location(...)`, clamps team size by `initial_spawn_remaining` when initial population phase is active.

### Verification Plan
1. Initial loop semantics
   - Verify: loop condition is based on spawned-agent total, not attempt count.
2. Team-size clamp during initial phase
   - Verify: team size is reduced by remaining initial budget.
3. Safety reset
   - Verify: initial budget variable resets after initial phase.

### Verification Outcome
- Code-level verification passed for the above three checks.
- Engine runtime validation is still required to confirm startup composition behavior across multiple maps.
