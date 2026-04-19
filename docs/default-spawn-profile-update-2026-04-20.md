# Default Spawn Profile Update (2026-04-20)

## Scope
- Apply requested default spawn settings only:
  - Max alive AI: `16`
  - Reinforcement interval: `15` to `75` seconds
- Keep all other spawn-system behavior unchanged.

## Target
- `BosWar/AISpawner.gd`
  - `_get_preset_profile()` default (`_`) branch for `intensity_preset = 0`.
- `BosWar/Config.gd`
  - Default metadata/value for `Dropdown.intensity_preset` to ensure runtime default selects preset `0`.

## Assumptions
- User request refers to default/low preset currently selected by `EnemyAISettings.intensity_preset = 0`.
- No change requested for spawn pool size, initial population, or higher intensity presets.

## Verification
1. Confirm default branch values:
   - `spawn_limit == 16`
   - `spawn_min == 15.0`
   - `spawn_max == 75.0`
2. Confirm config default points to preset `0`:
   - `Dropdown.intensity_preset.default == 0`
   - `Dropdown.intensity_preset.value == 0`
   - `_sync_dropdown_default(..., "intensity_preset", 0)`
3. Confirm no unrelated files changed.
