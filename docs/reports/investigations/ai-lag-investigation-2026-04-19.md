# AI Lag Investigation - 2026-04-19

## Scope
- User report: default settings with ~16+ average alive AI causes noticeable lag.
- Requested first action: remove/comment stacktrace-like output, then investigate likely lag causes.

## Assumptions
- The reported "stacktrace" overhead refers to high-frequency debug output, not explicit `print_stack()` calls.
- Runtime AI logic is currently more impactful to frame time than one-time startup setup.

## Verification Plan
1. Disable stacktrace-like debug output paths by default -> Verify: no default debug log console spam path remains active in Bo's War settings.
2. Inspect AI hot paths for O(N) / O(N^2)-style scans under active combat -> Verify: identify concrete functions and call cadence likely to spike with ~16+ AI.
3. Provide targeted next-step perf changes with minimal blast radius -> Verify: each recommendation maps to a specific function and reason.

## Changes Made
- `BosWar/DebugUtils.gd`
  - Replaced repeated `load("res://BosWar/EnemyAISettings.tres")` with cached preload constant.
  - Commented out console print line in `_debug_log` to remove per-log console overhead while profiling lag.
- `BosWar/EnemyAISettings.gd`
  - Set defaults: `show_debug_overlay = false`, `show_debug_logs = false`.
- `BosWar/EnemyAISettings.tres`
  - Set defaults: `show_debug_overlay = false`, `show_debug_logs = false`.
- `BosWar/Config.gd`
  - Set MCM default/value for `show_debug_logs` to `false`.

## Investigation Findings (Likely Lag Sources)

### 1) Repeated all-agent scans in per-agent sensor/targeting code
- `BosWar/AI.gd` runs repeated loops over `AISpawner.agents.get_children()` in:
  - `_find_audible_hostile_target()`
  - `_acquire_best_target()`
  - `_broadcast_target_to_teammates()`
  - `_count_teammates_targeting_same()`
- At ~16+ AI, each agent scanning all agents every refresh interval creates multiplicative cost.

### 2) Frequent LOS/raycast checks during target refresh
- `BosWar/AI.gd` `_acquire_best_target()` calls `_can_see_ai_target(child)` per hostile candidate.
- `BosWar/AI.gd` `_try_apply_targeted_hitbox_damage()` can issue multiple raycasts per shot via preferred targets.
- Physics queries are expensive under many simultaneous agents.

### 3) Spawn validation physics probes can spike during spawn bursts
- `BosWar/AISpawner.gd` uses `intersect_shape` and `intersect_ray` for safe spawn probing.
- Not constant per frame, but can cause stutters near spawn events.

## Trade-offs Noted
- Commenting out debug print removes immediate visibility in console logs; this is intentional for perf triage.
- No gameplay behavior logic was changed in this pass.

## Next Minimal Perf Pass Candidate
- Add lightweight per-agent target scan staggering (jitter + reduced scan cadence based on active AI count) inside `AI.gd` target acquisition path.
- Goal: keep behavior same while lowering concurrent scan/raycast pressure.

## Log Sample Analysis Update (2026-04-19)
- User-provided runtime logs confirm that lag is not only from volume of AI; it is amplified by repeated logging and stale agent iteration.

### High-confidence signals from logs
- `AI Guard: Acquired PLAYER target ...` appears in dense bursts, indicating repeated reacquire logging/broadcast while target did not materially change.
- `[trace]` lines are highly frequent during combat (`Choose AI`, `Hysteresis blocked`) and add avoidable log overhead.
- `local_agents` rises to 20/22/27/30 while `activeAgents` drops to low values; this implies dead/paused entries remain in `agents` iteration paths.
- Frequent `WARNING: Faction total mismatch! Counted=... activeAgents=...` confirms counting includes non-active entries.
- `All valid spawn points occupied` can be made worse when defeated-team cleanup still sees dead members in active-team scans.

### Additional patch applied
- `BosWar/AI.gd`
  - `_trace_log()` now exits unless `TRACE_VERBOSE` is enabled.
  - Player acquisition logs/broadcast now run only when switching into player target (not every refresh while already tracking player).
  - Teammate broadcast/count loops now skip dead/paused agents.
- `BosWar/AISpawner.gd`
  - `_check_and_release_defeated_team_spawn_points()` now ignores dead/paused agents when building active team ids.
  - `_log_faction_breakdown()` now counts only live, non-paused agents.

### Remaining non-BosWar noise observed
- Repeated resource load errors for missing weapon resources (`res://Items/Weapons/...`) and other mods (`CatHungerSlow`) are external to BosWar scripts and can still cause frame hitches due repeated failing loads/logging.

## ActiveAI Negative Count Root Cause (2026-04-19)
- Root cause identified: `Road to Vostok/Scripts/AI.gd` base `Death()` already does `AISpawner.activeAgents -= 1`.
- BosWar `AI.gd` `Death()` called `super(direction, force)` and then decremented `activeAgents` again, causing double-decrement and eventual negative counts.

### Fix applied
- `BosWar/AI.gd`
  - Added one-time death processing guard via `boswar_death_processed` metadata to prevent duplicate death accounting.
  - Removed BosWar-side extra decrement after `super()`; now uses base decrement only.
  - Added clamp to zero if `activeAgents` ever goes negative from legacy state.

### Additional log-throttle tweak
- `BosWar/AI.gd`
  - `Acquired PLAYER target` logging is now rate-limited per AI instance (`1.5s`) when switching into player target.
