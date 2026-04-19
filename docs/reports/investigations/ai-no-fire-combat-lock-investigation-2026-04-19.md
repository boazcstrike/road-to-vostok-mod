# AI no-fire combat lock investigation (2026-04-19)

## Scope
- Investigate why AI acquires hostile AI targets but does not fire or produce deaths.
- Apply a minimal fix in combat-state logic only.

## Findings
- Runtime logs show repeated hostile target acquisition with mostly `score=0.000`.
- In `BosWar/AI.gd`, `Combat(delta)` currently delegates to `super(delta)` and then only applies close-range movement stop behavior.
- Base `super(delta)` combat logic is player-centric (`playerVisible`/`playerDistance3D`), so AI-vs-AI engagements can fail to trigger fire/decision loops reliably.

## Decision
- Keep existing close-range stop behavior.
- Restore explicit combat-state fire/decision loop using BosWar engagement helpers:
  - `_engagement_visible()` for fire gate
  - `Decision()` timing/transition in current state

## Verification plan
1. Patch `Combat(delta)` only.
   - Verify: function calls `Fire(delta)` when `_engagement_visible()`.
2. Verify state loop includes `Decision()` timing gate.
   - Verify: combat transitions remain active.
3. Keep diff surgical.
   - Verify: only `BosWar/AI.gd` and this task file are changed.

## Outcome
- Implemented `Combat(delta)` state-local loop for BosWar targeting:
  - `combatTimer += delta`
  - fire gate uses `_engagement_visible()`
  - transition gate uses `Decision()` on combat cycle / navigation completion
- Preserved existing close-visual stop behavior (`is_close_visual_target` speed/turn zeroing).

## Expected runtime change
- AI should continue firing while in `Combat` with visual hostile AI targets (not only in Hunt/Shift/Attack).
- Logs should begin to include shot-related events and eventually death decrements when line-of-fire succeeds.
