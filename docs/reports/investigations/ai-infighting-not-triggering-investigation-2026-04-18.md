# AI Infighting Not Triggering Investigation (2026-04-18)

## Task
Investigate why AI teams are not fighting each other even when infighting is enabled in game settings.

## Scope
- Read-only investigation of:
  - `BosWar/AI.gd`
  - `BosWar/AISpawner.gd`
  - `BosWar/EnemyAISettings.gd`
  - `BosWar/EnemyAISettings.tres`
  - `BosWar/Config.gd`
- No edits in `Road to Vostok/` (read-only reference area per repo guardrail).

## Related Context
- `docs/context/README.md`
- `docs/context/agents/06-ai-architecture.md`
- `docs/domains/ai-decision-and-targeting/system-map.md`
- `docs/domains/configuration-and-settings/system-map.md`

## Assumptions
- User means both same-faction infighting and cross-faction warfare are expected.
- User has already toggled infighting settings in MCM UI during runtime.

## Initial Findings (In Progress)
- `EnemyAISettings.tres` currently contains `bandit_infighting_enabled = false` in the serialized resource.
- `Config.gd` runtime update path sets all infighting booleans and `warfare_enabled` from `user://MCM/BosWar/config.ini`, so runtime state may differ from `.tres` defaults.
- `AI.gd` hostile AI targeting is gated by:
  - `_custom_ai_targeting_active()` -> `_same_faction_infighting_active() or _faction_warfare_active()`
  - `_is_valid_hostile_ai_target()` -> `_is_hostile_faction(_self_faction(), target_faction)`

## Candidate Failure Modes (To Validate)
1. Runtime config not applying (MCM callback/state issue), leaving hostility gates off.
2. Faction composition at runtime is effectively single-faction or non-overlapping in encounters.
3. Target prioritization keeps player selected, suppressing AI-vs-AI engagements in practical scenarios.

## Evidence Log
- `BosWar/EnemyAISettings.tres:21` has `bandit_infighting_enabled = false`.
- Runtime settings are overwritten by MCM config in `BosWar/Config.gd:382-385`:
  - `bandit_infighting_enabled`
  - `guard_infighting_enabled`
  - `military_infighting_enabled`
  - `warfare_enabled`
- Custom AI-vs-AI targeting is enabled only when:
  - same-faction infighting for self faction is on, or
  - warfare is enabled for supported factions.
  - Reference: `BosWar/AI.gd:618-623`.
- If custom AI-vs-AI targeting is not active, AI targets are cleared and AI-vs-AI logic exits:
  - Reference: `BosWar/AI.gd:691-694`.
- Same-faction hostility depends on per-faction infighting toggles:
  - `BosWar/AI.gd:1011-1013`, `BosWar/AI.gd:1019-1028`.
- Cross-faction hostility requires warfare and both factions must be in `{Bandit, Guard, Military}`:
  - `BosWar/AI.gd:1014-1017`, `BosWar/AI.gd:1030-1031`.
- Faction metadata is required on AI nodes (`enemy_ai_faction`), otherwise AI is never considered hostile:
  - `BosWar/AI.gd:991-1005`.
- Team IDs do not participate in hostility checks; hostility is purely faction-based:
  - Team metadata assignment: `BosWar/AISpawner.gd:1098`.
  - No `team_id` usage in `BosWar/AI.gd` hostility functions.

## Verification Plan (Binary Checks)
1. Check runtime-applied config values -> Verify all four flags are true at runtime:
   - `bandit_infighting_enabled`, `guard_infighting_enabled`, `military_infighting_enabled`, `warfare_enabled`.
2. Check spawned faction mix -> Verify active AI includes at least two factions for cross-faction tests.
3. Check hostility acquisition path -> Verify log entries include hostile target acquisition events.
4. Check fallback condition -> Verify no repeated path where `_custom_ai_targeting_active()` is false.

## Outcome
- Root cause is most likely a runtime settings mismatch combined with faction-specific gating:
  - Bandit infighting is serialized as false in `.tres`, and if MCM runtime override does not persist/apply as expected, bandit-vs-bandit never becomes hostile.
  - Cross-faction combat is controlled by `warfare_enabled`, not infighting toggles alone.
  - Team boundaries are not a hostility concept in current code, only faction boundaries are.

## Implementation Update (2026-04-18)
- Updated serialized defaults in `BosWar/EnemyAISettings.tres`:
  - `bandit_infighting_enabled = true`
  - `guard_infighting_enabled = true`
  - `military_infighting_enabled = true`
  - `warfare_enabled = true` (kept true)
- Updated hostility logic in `BosWar/AI.gd`:
  - Same-faction hostility now uses `team_id` only when infighting for that faction is enabled.
  - If infighting for that faction is disabled, same-faction hostility is disabled and team IDs are ignored.
  - Cross-faction hostility remains faction/warfare-based.

### New Same-Faction Rule
1. Faction infighting toggle off -> do not target same faction.
2. Faction infighting toggle on -> target same faction only when team IDs differ.
3. If team IDs are missing on either side, treat as hostile when infighting is enabled.

## Investigation Update (2026-04-18, follow-up)
- Validated a separate high-impact suppression path in `BosWar/AISpawner.gd`:
  - In custom spawn-mode flow (`_build_faction_pool`), mode `0` ("Map Default") was effectively treated as include-only-if-zone-default-faction.
  - If any faction mode was toggled (`On` or `Off`), this logic could collapse the pool to a single faction and remove cross-faction combat opportunities.
- Implemented a minimal fix:
  - `mode == 0` now includes that faction in the weighted pool (normal map-default behavior).
  - `mode == 1` still force-includes.
  - `mode == 2` still excludes.

## Post-Fix Verification Steps
1. In MCM, keep `Enable Bo's War = On`.
2. Set one faction mode to `Off` and leave the other two at `Map Default`.
3. Confirm debug logs show multiple factions still spawning (not only one faction).
4. Confirm hostile target acquisition logs appear between AI factions/teams, not only player targeting.

## Investigation Update (2026-04-19, team-hostility gate)
- New root cause validated in `BosWar/AI.gd`:
  - `_update_hostile_ai_targeting()` exits early when `_custom_ai_targeting_active()` is false.
  - `_custom_ai_targeting_active()` was based only on faction toggles (`infighting`/`warfare`) and ignored `team_id`.
  - This can suppress AI-vs-AI targeting even when opposing teams exist.
- Additional robustness issue:
  - Faction comparisons were case-sensitive in critical hostility gates, so non-canonical faction casing could silently disable faction-based hostility.

## Implementation Update (2026-04-19)
- Updated `BosWar/AI.gd` with minimal hostility gate changes:
  - `_custom_ai_targeting_active()` now returns true when the AI has a valid `team_id`, so team combat logic stays active.
  - Added unconditional team hostility rule:
    - if both AIs have valid `team_id` and IDs differ, they are hostile regardless of faction or warfare/infighting toggles.
  - Added faction normalization helper used by hostility checks (`Bandit`/`Guard`/`Military` canonicalization).

## Team Combat Rule (Current)
1. Different valid `team_id` values -> hostile (always).
2. If team IDs are unavailable, hostility falls back to existing faction rules.
3. Same-faction and same-team still obey existing non-hostile behavior unless other rules apply.

## Investigation Update (2026-04-19, live debug follow-up)
- Runtime symptom reported after prior fix: AI still focused player and rarely/never switched to hostile AI.
- Additional root cause in `BosWar/AI.gd::_acquire_best_target()`:
  - Player and AI candidates were scored in one pool.
  - Generic hysteresis (`best_score < current_target_score * 1.2`) applied equally across target types.
  - Once player target was established, AI targets often failed to overtake score threshold, producing player lock-in.

## Implementation Update (2026-04-19, target selection)
- Updated `BosWar/AI.gd::_acquire_best_target()`:
  - Evaluate visible hostile AI candidates first and prefer AI when any valid AI candidate exists.
  - Keep player targeting as fallback when no visible hostile AI candidate is available.
  - Bypass hysteresis when switching from `player -> ai` target class to prevent player lock-in.

## Verification Focus (Next Runtime Pass)
1. Confirm logs show `Acquired AI ... target` while player is nearby/visible.
2. Confirm different teams within same faction exchange fire.
3. Confirm AI still targets player when no hostile AI candidate is visible/audible.

## Debug Trail Update (2026-04-19, runtime capture instrumentation)
- Added rate-limited tracing in `BosWar/AI.gd` using `DebugUtils._debug_log_rate_limited(...)`.
- Trace lines are prefixed with: `[trace]`.

### New Trace Events
- `targeting_gate_off`: hostile AI loop disabled for this AI (shows faction/team/toggles).
- `hysteresis_block`: target switch blocked by hysteresis guard.
- `choose_ai`: hostile AI selected as target with self/target faction+team context.
- `hostility_unknown_faction`: candidate rejected due to missing/unknown faction metadata.
- `hostility_same_faction_block`: same-team candidate rejected (explicitly same team).
- `hostility_warfare_off`: cross-faction candidate rejected due to warfare gate.

### Trace Volume Tuning (2026-04-19)
- Reduced trace frequency to lower runtime noise.
- Set `TRACE_VERBOSE = false` in `BosWar/AI.gd`:
  - suppresses repetitive `acquire_none`, `acquire_empty`, same-team rejection, and unknown-faction traces.
  - keeps high-signal traces (`choose_ai`, `hysteresis_block`, `targeting_gate_off`, `hostility_warfare_off`).
- Removed high-volume `hostility_team_allow` trace logging after behavior was validated.

### What To Send Back After Your Run
1. Any log lines containing `[trace]`.
2. Any lines containing `Hostile target acquired`.
3. Any lines containing `Acquired AI` and `Acquired PLAYER`.
4. Keep ~30 lines before and after the first time combat starts failing.

## Investigation Update (2026-04-19, hysteresis score-sign bug)
- Runtime evidence showed:
  - `Acquired AI ...`
  - followed by `Hysteresis blocked ... old_score=0.0000 new_score=-...`
  - followed by `No target acquired`.
- Root cause:
  - Hysteresis was applied to signed target scores.
  - Negative candidate scores (valid by formula due to angle) were blocked against `old_score=0`, causing target reacquisition stalls.
- Fix:
  - Apply hysteresis only when both `current_target_score` and `best_score` are positive.
  - Keep existing player->AI hysteresis bypass.

## Implementation Update (2026-04-19, long-range single-fire tuning)
- Runtime request: increase long-range shot output while keeping behavior in single-fire mode.
- Updated `BosWar/AI.gd`:
  - `Selector(delta)` now forces `fullAuto = false` when engagement distance is `>= 50m`.
  - Bandit close-range full-auto bias remains for `< 30m`.
  - `FireFrequency()` long-range semi/single cadence tightened from `randf_range(0.1, 4.0)` to `randf_range(0.1, 2.0)`.
- Result intent:
  - More frequent shots at distance.
  - Predominantly single-fire behavior at long range.

## Implementation Update (2026-04-19, full-auto penalties increased)
- Runtime request: make full-auto less effective.
- Updated `BosWar/AI.gd` full-auto-only behavior:
  - Recoil impulse penalty increased:
    - `impulseX = spineTarget.x - spineData.recoil * 1.4`
  - Full-auto spread penalty increased:
    - `spreadMultiplier` from `2.0` -> `3.0` when `fullAuto && !boss`
  - Full-auto cadence penalty increased:
    - `fireTime = weaponData.fireRate * 1.35` (semi-auto weapon in full-auto mode)
- Single-fire paths were not changed by this update.
