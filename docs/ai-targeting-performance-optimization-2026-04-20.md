# AI Targeting Performance Optimization (2026-04-20)

## Scope
- Audit targeting-related overhead across `BosWar/EnemyAISettings.gd`, `BosWar/EnemyAISettings.tres`, `BosWar/DebugUtils.gd`, and `BosWar/AI.gd` call sites.
- Optimize Bo's War AI targeting hot path to reduce frame spikes during spotting/target lock.
- Keep behavior equivalent and apply only minimal, surgical code changes.

## Reported Runtime Symptom
- In-game lag spikes when AI spots player or another AI.
- Performance target: sustain gameplay closer to 24 active AI (current lag starts around 18).

## Assumptions
- Targeting scan and LOS checks are the dominant script-side hotspot during spotting events.
- Existing lock/refresh cadence can be tuned slightly without changing combat intent.
- Shadow threaded scoring remains disabled by default and should stay non-authoritative.
- MCM runtime config may override `.tres` defaults; disk defaults are not guaranteed runtime truth.

## Verification Plan
1. Reduce target-acquisition loop overhead in `_acquire_best_target()`.
   - Verify: no syntax errors and target acquisition still selects hostile targets.
2. Reduce spotting-time burst synchronization in `_update_hostile_ai_targeting()`.
   - Verify: reacquire/visibility checks stay staggered under many AI.
3. Limit status/log churn during repeated acquire/loss events.
   - Verify: debug status updates are suppressed only for identical, short-interval duplicates.
4. Run static validation (`git diff`, focused scan of changed functions).
   - Verify: diff maps only to targeting performance scope.

## Progress Log
- [done] Audited settings/logging/thread-shadow seams:
  - `EnemyAISettings.gd`/`.tres`: shadow scoring already disabled by default (`enable_threaded_scoring_shadow_mode=false`), stats logging disabled (`show_threaded_scoring_stats=false`), debug logs disabled (`show_debug_logs=false`).
  - `DebugUtils.gd`: logs are already gated behind `show_debug_logs` and rate-limited helper exists.
  - `AI.gd`: spotting hot path still concentrates work in `_acquire_best_target()` LOS checks and reacquire cadence.
- [done] Applied minimal `AI.gd` patches to reduce spotting spikes:
  - Skip `_consume_shadow_scoring_result()` call when shadow scoring is disabled and no job is in flight.
  - Keep reacquire and visibility checks staggered by adding small jitter when resetting timers.
  - Avoid same-tick duplicate visibility LOS refresh after successful reacquire by initializing `targetVisibilityTimer` immediately.
  - Retune lock cadence so stable visible targets refresh less often (`_current_target_refresh_cycle`) and close-range visibility checks are not over-aggressive (`_current_target_visibility_cycle`).
  - Short-circuit candidate LOS checks in `_acquire_best_target()` for candidates already farther than current nearest visible candidate.
  - Replace player-score `acos/cos` path with equivalent `abs(dot)` scoring math.
  - Add cheap sight-range distance rejection in `_can_see_ai_target()` before forcing raycast updates.
  - Gate `_push_debug_status()` duplicate pushes (same event + same target) for 0.25s to avoid overlay churn.
- [done] Preserved gameplay behavior constraints:
  - No hostility-rule changes.
  - No scoring formula contract changes.
  - No threaded scoring authority change (still shadow/off by default).

## Spotting-Time Overhead Findings
- Highest cost remains repeated LOS/raycast work in `_acquire_best_target()` whenever target refresh triggers under crowded scenes.
- LOS/raycast volume now drops once a nearer visible hostile candidate is found in each scan pass.
- Secondary spike source is cadence bunching: many AIs can re-run reacquire/visibility updates near the same frame after timer resets.
- Tertiary overhead is repeated debug status UI updates during rapid target churn; this is lower than LOS cost but still avoidable.

## Runtime Validation Checklist (18 to 24 AI)
1. Use the same map/settings run and compare 18 AI baseline vs 24 AI target.
2. Keep `show_debug_logs=false` and `show_threaded_scoring_stats=false` for performance runs.
3. Watch frame pacing around first-spot events (AI sees player or hostile AI).
4. Confirm combat behavior remains unchanged:
   - AI still acquires nearest visible hostile AI.
   - AI still acquires player when player is the best visible target.
   - Team hostility/warfare behavior unchanged.

## Follow-up Tuning (2026-04-21)
- Symptom: visible target state can flicker rapidly during LOS jitter, causing frequent visual/state churn while spotted.
- Change in `BosWar/AI.gd`:
  - Added target visibility hysteresis:
    - `AI_TARGET_VISIBLE_GAIN_CONFIRM_SECONDS = 0.06`
    - `AI_TARGET_VISIBLE_LOST_GRACE_SECONDS = 0.35`
  - `_update_target_visibility()` now:
    - Requires brief confirm window before switching from unseen -> seen.
    - Applies short grace window before switching from seen -> unseen.
    - Resets hysteresis when target instance changes.
  - `_clear_ai_target()` and activation path now reset hysteresis runtime state.
- Expected effect:
  - Reduces rapid seen/unseen flipping under LOS noise, lowering spotting-time behavior/label churn and perceived stutter.
