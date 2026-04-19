# Negative target score investigation (2026-04-19)

## Scope
- Investigate why AI target acquisition logs negative `score` values.
- Apply a minimal fix that prevents invalid negative score propagation.

## Assumptions
- Target score is a desirability metric and should be non-negative.
- Existing hysteresis logic (`> 0.0`) indicates non-positive scores are not intended for switching decisions.

## Findings (in progress)
- In `BosWar/AI.gd`, `_acquire_best_target()` computes:
  - AI score: `3.0 * cos(ai_angle) / (1.0 + ai_dist)`
  - Player score: `2.0 * cos(player_angle) / (1.0 + player_dist)`
- `cos(angle)` becomes negative for angles above 90 degrees, so scores can be negative.
- Logs show repeated acquisitions with negative scores, confirming this path is active in runtime.

## Trade-off considered
- Option A: Keep formula and clamp only for logs.
  - Rejected: still propagates negative values into targeting state.
- Option B: Clamp computed score at zero.
  - Chosen: smallest behavioral change that preserves ranking among valid forward-facing candidates and avoids negative state.

## Verification plan
1. Patch AI/player score calculations with non-negative floor.
   - Verify: no raw negative score assignment remains in `_acquire_best_target()`.
2. Search for `current_target_score` interactions.
   - Verify: no logic expects negative score semantics.
3. Sanity-check diff scope.
   - Verify: only `BosWar/AI.gd` and this task context file changed.

## Outcome
- Implemented in `BosWar/AI.gd` with explicit failsafe:
  - if score `< 0.0`, convert to positive (`-score`)
  - if score `== 0.0`, force minimum `0.1`
- Applied to both AI and player score paths in `_acquire_best_target()`.
- Verified score formulas now follow this rule directly.

## Notes
- The repository already contains unrelated local modifications; this task intentionally changed only the two score expressions plus this context file.
- Runtime validation in Godot is still recommended to confirm logs now avoid `0.000` and negative values in acquisition traces.
