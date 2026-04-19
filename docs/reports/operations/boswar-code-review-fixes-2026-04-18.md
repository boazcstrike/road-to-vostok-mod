# BosWar Code Review Fixes - 2026-04-18

## Task
Implement actionable fixes from `docs/reports/reviews/boswar-code-review-2026-04-18.md` in `BosWar/` scripts.

## Scope
- `BosWar/AI.gd`
- `BosWar/AISpawner.gd`
- Settings/debug verification in `BosWar/EnemyAISettings.gd` and related resource

## Assumptions
- Godot 4.x runtime.
- Existing in-progress repo edits are intentional and must not be reverted.
- `Road to Vostok/` remains read-only reference only.

## Success Criteria
1. `AI.gd` Sensor branch parses and executes correctly with no indentation/control-flow break.
2. Teammate broadcast cooldown correctly treats all player-audio variants as player-target cooldown.
3. Teammate target intake validates payload before mutating last-known-location state.
4. Team spawn occupancy no longer releases arbitrary points; release is keyed to defeated/failed team id.
5. Spawn occupancy checks prevent overlapping team spawn-point reuse deterministically.
6. Any already-fixed findings are documented as verified-no-change.

## Verification Plan
1. Apply AI fixes -> Verify: target functions contain corrected conditions/order.
2. Apply spawner occupancy fixes -> Verify: reservation/release path keyed by team id.
3. Validate debug setting field presence -> Verify: `show_debug_logs` exists in settings script/resource.
4. Run lightweight syntax/smoke checks -> Verify: no obvious parse errors in touched files.

## Notes
- Multi-agent orchestration used: one worker for `AI.gd`, one worker for `AISpawner.gd`.
- Keep edits surgical and mapped directly to review findings.

## Implementation Log
- Applied `AI.gd` fixes for Sensor parse/control-flow, player-audio cooldown classification, and validation-first teammate updates.
- Applied `AISpawner.gd` fix to make spawn occupancy deterministic by team id reservation mapping.
- Verified `show_debug_logs` already exists in both `BosWar/EnemyAISettings.gd` and `BosWar/EnemyAISettings.tres`; no code change required for that finding.

## Decisions and Tradeoffs
- Did not introduce `TargetSnapshot`/Resource refactor yet because it is a larger architecture change than requested; implemented minimal hot-path churn reduction in-place.
- Kept teammate communication mechanism as direct calls (no signal broker refactor) to stay surgical and avoid broad behavior changes.
- Team spawn occupancy fallback now retries after targeted stale-team cleanup only, avoiding non-deterministic full clears.

## Verification Results
- `AI.gd` `Sensor()` block now has valid indentation and single location update assignment.
- `_broadcast_target_to_teammates()` now treats `audio_player_*` as player cooldown traffic.
- `_receive_teammate_target_info()` now validates payload before writing last-known-location.
- `_acquire_best_target()` no longer allocates candidate dictionaries/array before scoring.
- `AISpawner.gd` occupancy is keyed as `occupied_spawn_points_by_team[team_id] = spawn_point` and stale team reservations are released by team id.

## Residual Notes
- Runtime/gameplay validation in Godot editor/play mode is still needed to measure perf and behavior under high agent counts.
