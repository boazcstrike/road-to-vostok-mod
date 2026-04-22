# AI Lag + Spawn Cap Tuning (2026-04-21)

## Task Scope
- Lower default live AI ceiling for BosWar.
- Keep faction spawn ratio unchanged.
- Apply requested team-size maxima.
- Inspect AI-vs-AI spotting/combat path for lag contributors and capture recommendations.

## Assumptions
- "Ratio should be the same" means keep the existing `10:3:1` weighted faction pool logic unchanged.
- Requested team maxima are intended as effective runtime caps (not only UI text), so spawner hard caps must enforce them.
- Only BosWar mod files will be changed; `Road to Vostok/` remains read-only reference.

## Verification Plan
1. Update default preset ceiling and team-size caps.
   Verify: default preset profile returns `spawn_limit = 9`; bandit/guard/military team hard caps resolve to `5/4/3`.
2. Confirm ratio logic is unchanged.
   Verify: weighted pool logic still uses `10:3:1`.
3. Identify lag hot path.
   Verify: line-level hotspots documented with concrete mitigation options and trade-offs.

## Progress Log
- Started code/path inspection for `BosWar/AISpawner.gd`, `BosWar/EnemyAISettings.*`, and `BosWar/AI.gd`.
- Spawned parallel agents for (a) cap-default edits and (b) lag-root-cause evidence pass.
- Applied requested cap tuning in BosWar runtime defaults.
- Applied follow-up tuning request:
  - reduced target priority distance from `25m` to `15m`
  - added teammate-triggered suppressive player fire mode (`15s..60s`, full auto at last seen player position)

## Implemented Changes
- `BosWar/AISpawner.gd`
  - Default preset (`intensity_preset = 0`) spawn ceiling changed from `16` to `9`.
  - Bandit team hard cap changed from `8` to `5` inside `_get_team_size_for_faction(...)`.
  - Guard and Military hard caps remain `4` and `3`.
- `BosWar/EnemyAISettings.gd`
  - Bandit team-size export range changed from `3..8` to `3..5`.
  - Bandit default max changed from `8` to `5`.
- `BosWar/AI.gd`
  - Added budgeted hostile candidate scan in `_acquire_best_target()` with rolling cursor to reduce LOS burst load.
  - Added motion-gated visibility LOS sampling with forced periodic recheck in `_update_target_visibility()`.
  - Converted teammate intake to queued processing with per-frame budget (`_receive_teammate_target_info` enqueue + `_process_pending_teammate_target_info` consume).
  - Limited targeted hitbox correction rays to first shot in burst or close-range engagements.

## Verification Results
- Verified ratio logic remains unchanged at `10:3:1` in `_build_faction_pool()`.
- Verified only requested behavior surfaces changed for caps/defaults.
- No edits made in `Road to Vostok/` (read-only reference preserved).
- Verified invariants remain in code after optimization pass:
  - `TARGET_PRIORITY_DISTANCE = 25.0` lock rule path still present.
  - Hostility gate and hostility function path unchanged (`_custom_ai_targeting_active`, `_is_hostile_faction`).
  - Trading block semantics unchanged (`_player_only_combat_blocked` still returns `gameData.isTrading` unless AI target is valid).

## Lag Hotspot Findings (AI sees AI)
1. Reacquisition loop in `BosWar/AI.gd` scans active hostiles and performs LOS checks (`_acquire_best_target` + `_can_see_ai_target`), creating N-by-N pressure as active agents rise.
2. Visibility maintenance repeatedly raycasts current target (`_update_target_visibility`), causing recurrent LOS cost even without meaningful target motion.
3. Teammate broadcast fanout and receiver-side `Decision()` triggers create burst cascades when many agents spot/relay at once.
4. Per-shot multi-ray correction in combat adds extra traces under heavy firefights.
5. Audio fallback scans all active hostile candidates when visual lock is not stable.

## Recommended High-Impact Improvements
1. Budget LOS work per frame (incremental candidate scan cursor) instead of full candidate pass in one refresh tick.
2. Add movement/delta gating before visibility LOS refresh to skip re-checks on near-static target geometry.
3. Convert teammate intel fanout to queued processing with per-frame budget (instead of immediate direct fanout).
4. Restrict secondary fire correction rays to first shot in burst or close range only.
5. Add spatial shortlist (nearby cohort/sector bucket) before audio hostile scan.

## Implemented This Pass
1. Budgeted LOS candidate scanning.
2. Motion-gated visibility LOS refresh with periodic forced recheck.
3. Queued teammate intake with bounded per-frame processing.
4. First-shot-or-close-range gating for targeted hitbox correction rays.
5. Priority-distance threshold reduced to `15m` wherever target-priority checks use `TARGET_PRIORITY_DISTANCE`.
6. Added teammate player suppressive-fire mode:
   - Triggered from teammate player-target intake path.
   - Fires at last-seen shared position for random `15..60s`.
   - Allows firing even without direct LOS while suppressive mode is active.

## Outcome
- Requested cap and team-size changes are in place with minimal diff.
- Analysis indicates the main lag source is bursty LOS/scan + fanout cascades during mass mutual spotting, not a single isolated function.
