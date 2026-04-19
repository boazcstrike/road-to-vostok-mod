# AI Target Priority Lock - 2026-04-19

## Scope
- User report: AI lag likely comes from repeated hostile scoring/retargeting loops.
- Requested behavior:
  - Score only the closest visible hostile.
  - Switch targets only for first-priority hostile: closest + seen + heard + around 25m.
  - If a hostile is seen, keep focus and do not keep changing score/target unless first-priority rule is met.

## Assumptions
- "Around 25m" is implemented as `<= 25.0` meters.
- "Seen and heard" for AI hostiles means:
  - visible through `_can_see_ai_target(...)`, and
  - audible through existing `_target_is_audible(...)`.
- Existing player-target behavior should stay unchanged unless no higher-priority AI-hostile lock condition applies.

## Verification Plan
1. Replace per-candidate visual hostile scoring with nearest-visible-hostile selection.
   - Verify: `_acquire_best_target()` no longer computes score for every visible hostile candidate.
2. Add seen-target lock.
   - Verify: when current AI target is visible, switching to another AI target is blocked unless nearest candidate is seen+heard and within 25m.
3. Keep edits surgical.
   - Verify: only `BosWar/AI.gd` and this context file are changed for this task.

## Changes
- `BosWar/AI.gd`
  - Added `TARGET_PRIORITY_DISTANCE = 25.0`.
  - `_acquire_best_target()` now picks nearest visible hostile AI candidate (distance-first), then computes one score for the selected candidate.
  - Added seen-target lock logic:
    - keep current target when nearest visible hostile is the same node,
    - block switching to a different hostile unless that nearest hostile is audible and within `TARGET_PRIORITY_DISTANCE`.
  - Replaced hardcoded visual-close checks with `TARGET_PRIORITY_DISTANCE`.

## Notes
- This patch reduces score churn and retarget churn; LOS checks are still performed for visible-hostile selection and may still require additional performance tuning if needed.
- Runtime validation in Godot is still required to confirm feel and frame-time improvement under high AI counts.
