# Default AI Ceiling Verification - 2026-04-22

## Request
- Lower the default alive AI ceiling to `9`.

## Assumptions
- "Default" means `intensity_preset = 0`.
- The effective alive cap is sourced from `BosWar/AISpawner.gd` preset profile `spawn_limit`.

## Verification Plan
1. Check default preset profile mapping in `BosWar/AISpawner.gd` -> Verify `spawn_limit` for `_` branch is `9`.
2. Check default preset selection wiring in `BosWar/Config.gd` -> Verify `intensity_preset` default/value are `0`.

## Findings
- `BosWar/AISpawner.gd` default (`_`) preset currently has `"spawn_limit": 9`.
- `BosWar/Config.gd` keeps `intensity_preset` default and value at `0`.

## Outcome
- Request is already satisfied in current codebase.
- No code mutation was required.
