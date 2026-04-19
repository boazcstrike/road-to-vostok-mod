# AI Long-Range Fire Tuning - 2026-04-19

## Scope
- User request:
  - Make Bandit and Guard AI spray full auto more often for more than 50m.
  - Also make single-shot intervals happen more often at that range.
  - Add more accuracy penalties for that behavior.

## Assumptions
- "For more than 50m" means `engagement_distance > 50` with existing `>= 50` Selector threshold behavior preserved for mode selection.
- "Spray full auto more often or fire single shot intervals more" means:
  - long-range Bandit/Guard should sometimes stay in full-auto mode,
  - and when in semi mode, use faster interval range than before.
- Requested changes are limited to firing behavior in `BosWar/AI.gd`.

## Verification Plan
1. Update long-range full-auto selection for Bandit/Guard in `Selector`.
   - Verify: Bandit/Guard no longer force fullAuto=false at `>=50m`.
2. Update long-range semi-shot cadence for Bandit/Guard in `FireFrequency`.
   - Verify: Bandit/Guard `>50m` semi range uses tighter/faster interval than previous baseline.
3. Add long-range accuracy penalty in `FireAccuracy`.
   - Verify: additional spread multiplier applies to Bandit/Guard when `>50m`.

## Changes
- `BosWar/AI.gd`
  - `Selector(delta)`:
    - For Bandit/Guard at `>=50m`, set `fullAuto` with a 45% chance (`randf() < 0.45`).
    - Keep non-Bandit/Guard behavior unchanged (`fullAuto = false` at `>=50m`).
  - `FireFrequency()`:
    - For Bandit/Guard semi fire at long range (`>=50` branch), changed interval from `0.1..2.0` to `0.08..1.2`.
  - `FireAccuracy()`:
    - Added long-range penalty multiplier for Bandit/Guard:
      - `1.5` when full-auto,
      - `1.25` when not full-auto.
    - Applies to AI-target spread and fallback spread for long-range shots.

## Notes
- This is a behavior tuning pass only; no spawn, targeting, or state-machine structure changes.
- Runtime balancing in Godot is still required to tune exact percentages and spread multipliers.
