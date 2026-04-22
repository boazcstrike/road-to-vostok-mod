# BosWar AI Reload + Supersonic Crack Implementation (2026-04-22)

## Scope
- Implemented only in `BosWar/AI.gd` and `BosWar/EnemyAISettings.gd`.
- Kept BosWar AI suppression system unchanged.
- Did not import or replace ImmersiveXP scripts directly.

## Assumptions
- `EnemyAISettings.gd` exported fields are surfaced by MCM.
- Existing BosWar magazine/reload flow remains the primary ammo system.
- Audio timing changes must remain conservative and not rewrite base fire loops.

## Decisions
- Added tactical reload as an additive behavior:
  - only when target is not currently visible,
  - not during forced/hidden suppressive paths,
  - only when mag is partially depleted under a configurable ratio,
  - only beyond a configurable safe-distance threshold,
  - chance-driven and configurable through `EnemyAISettings`.
- Added ammo-aware decision gating:
  - AI avoids aggressive push states (`Hunt`, `Shift`, `Attack`) while actively reloading or empty.
  - Empty-mag state now proactively starts reload during `Decision()`.
- Reworked supersonic crack trigger:
  - crack now requires a geometric flyby condition relative to player position.
  - when flyby is true, crack plays before the shot audio.
  - shot-audio delay is distance-based (sound travel approximation) and capped conservatively.

## Tradeoffs
- The crack flyby check is an approximation using the shot ray and nearest-point distance to player; this avoids intrusive projectile-system rewrites.
- Decision gating is intentionally narrow to reduce behavior churn in BosWar state logic.

## Explicit Non-Goals
- No suppression overhaul.
- No weapon auto-equip implementation in this task.
- No base-game (`Road to Vostok/`) edits.

## Verification Notes
- Static/syntax sanity check performed on touched GDScript files after patching.
- Runtime tuning still needs in-engine validation for:
  - tactical reload frequency at different AI tactics presets,
  - perceived crack-vs-shot ordering across distances.
