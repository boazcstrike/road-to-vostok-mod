# AI Aim And Spotting Lag Investigation - 2026-04-19

## Scope
- User report 1: after full-auto bursts, AI aims upward unrealistically.
- User report 2: lag spikes when AI spots AI/player interactions, even with only a few AIs.
- Request: investigate root causes, fix what is safely fixable now, then provide insights/recommendations (including heap/throttle angle).

## Assumptions
- The "aiming upward" issue is recoil/impulse accumulation, not intentional spread randomness.
- The lag symptom is CPU-side update pressure in targeting/communication loops, not a persistent memory leak/OOM condition.
- This pass should stay surgical in `BosWar/AI.gd` and avoid broad refactors.

## Multi-Agent Investigation Summary
- Parallel agent A (aim issue):
  - Found recoil accumulation in `Fire()` impulse updates as the likely source of upward climb.
  - Spread in `FireAccuracy()` is symmetric and not the primary upward-bias root cause.
- Parallel agent B (lag issue):
  - Found repeated LOS/raycast work in targeting scans.
  - Found synchronous teammate broadcast/receive churn with immediate decisions/state changes.
  - Found debug status updates in hot paths that can amplify spikes when debug is enabled.

## Verification Plan
1. Patch recoil impulse clamp in full-auto/semiauto.
   - Verify: impulse math is bounded and cannot drift upward indefinitely.
2. Reduce hot-path LOS/visibility churn.
   - Verify: no unconditional extra visibility refresh in `Sensor`; visibility cycle floor is less aggressive.
3. Cut avoidable teammate communication churn.
   - Verify: receiver ignores duplicate/low-value teammate updates.
4. Keep debug status updates out of hot path when debug is off.
   - Verify: `_push_debug_status()` returns early when both overlay/log flags are disabled.

## Changes Applied
- `BosWar/AI.gd`
  - Added scan prefilter constants:
    - `TARGET_SCAN_MAX_DISTANCE = 120.0`
    - `TARGET_SCAN_MIN_DOT = -0.2`
  - `Sensor(delta)`:
    - Removed unconditional `_update_target_visibility()` call from the sensor tick path.
  - `_current_target_visibility_cycle()`:
    - Raised base visibility cycle from `0.08` to `0.14`.
    - Raised close-target minimum from `0.05` to `0.1`.
  - `Fire(delta)` recoil impulse:
    - Full-auto recoil step reduced (`*1.4 -> *1.1`) and clamped.
    - Semi recoil now clamped as well.
  - `_acquire_best_target()`:
    - Added cheap candidate prefilters (distance/FOV) before expensive LOS check.
  - `_receive_teammate_target_info()`:
    - Added early returns for duplicate/low-value teammate updates:
      - already seeing player with same target context,
      - same player target/quality/position,
      - same AI target node with same-or-worse quality.
  - `_push_debug_status()`:
    - Early return if both `show_debug_overlay` and `show_debug_logs` are disabled.
  - `Decision()`:
    - Added tactical-point candidate guards before requesting `Hide`, `Cover`, and `Vantage` states to avoid avoidable fallback transitions.
  - Added helper candidate checks:
    - `_has_hide_point_candidate()`
    - `_has_cover_point_candidate()`
    - `_has_vantage_point_candidate()`

## User Debug Sample Follow-up
- User-reported lines like:
  - `AI: No available cover points -> Combat`
  - `AI: No available hide points`
  - `AI: No available vantage points -> Combat`
  - `AI: Process ended`
- Source mapping:
  - Base reference file `Road to Vostok/Scripts/AI.gd` prints these when state requests fail due to no valid tactical points.
  - `AI: Process ended` is from `Road to Vostok/Scripts/Ragdoll.gd` and is normal cleanup output.
- Since `Road to Vostok/` is read-only in this project, mitigation was applied in BosWar decision logic to reduce how often those no-point state requests are made.

## Insights
- The lag pattern aligns with short CPU spikes from script+physics work (raycasts, state updates, teammate fanout), not with max-heap exhaustion.
- Low aggregate system utilization (e.g. ~20%) does not rule out frame hitches:
  - Godot frame time can stall on main-thread script/physics bursts even when total CPU usage is modest.

## Recommendations
1. Runtime profile first:
   - Use Godot profiler focused on script time and physics frame when 2-6 AIs are actively detecting.
2. Keep debug features off for combat perf checks:
   - Ensure both overlay and debug logs are disabled while measuring.
3. If spikes remain:
   - Add per-AI staggered update buckets for target scans (not all AIs refreshing on similar ticks),
   - Split broadcast reaction from immediate `Decision()` into deferred/queued reaction on next behavior tick.
4. For heap concerns:
   - Track memory over longer sessions; heap issues should show monotonic memory growth or GC pressure pattern, not only instant detection spikes.
