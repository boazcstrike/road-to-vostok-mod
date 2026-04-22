# Infighting Removal and Team-Hostility Enforcement (2026-04-22)

## Task Scope
- Remove all infighting code paths from active mod runtime/config/documentation surfaces.
- Keep team-vs-team hostility behavior active for different valid `team_id` values.
- Remove infighting settings from MCM/config resources and runtime application.
- Produce an auditable change record for this task.

## Assumptions
- "Everywhere in our mod" applies to active gameplay code, runtime settings, serialized settings, and active docs surfaces.
- Historical investigation/report artifacts under `docs/reports/*` are retained as historical evidence unless explicitly requested for rewrite.

## Verification Plan
1. Remove infighting logic from AI hostility path.
- Verify: no infighting helpers/branches/settings references remain in `BosWar/AI.gd`.
2. Remove infighting settings from config/resource surfaces.
- Verify: no infighting options or runtime assignments in `BosWar/Config.gd`, `BosWar/EnemyAISettings.gd`, `BosWar/EnemyAISettings.tres`.
3. Remove active docs references.
- Verify: no infighting feature/config claims remain in `readme.md`, `agents.md`, `docs/context/agents/06-ai-architecture.md`.
4. Global sweep.
- Verify: no `infight` references remain outside historical docs/session state directories.

## Progress Notes
- Task initialized.
- Worker delegation completed across AI logic, config/resources, and active docs in parallel.

## Outcome
- Completed.

## Changes Implemented
- `BosWar/AI.gd`
- Removed infighting activation and helpers:
- `_same_faction_infighting_active()`
- `_same_faction_targeting_allowed(...)`
- `_same_faction_infighting_enabled(...)`
- `_is_hostile_team_for_infighting(...)`
- Updated hostile targeting gate:
- `_custom_ai_targeting_active()` now uses `team_targeting OR warfare`.
- Updated hostility rule in `_is_hostile_faction(...)`:
- Unknown/invalid other faction -> reject.
- Different valid `team_id` -> hostile.
- Same faction without hostile team mismatch -> not hostile.
- Cross-faction fallback remains warfare-gated.
- Removed infighting fields from hostility/targeting trace payloads.

- `BosWar/Config.gd`
- Removed MCM settings:
- `bandit_infighting_enabled`
- `guard_infighting_enabled`
- `military_infighting_enabled`
- Removed `_on_config_updated` assignments for all infighting keys.
- Kept `warfare_enabled` behavior intact.

- `BosWar/EnemyAISettings.gd`
- Removed exported fields:
- `bandit_infighting_enabled`
- `guard_infighting_enabled`
- `military_infighting_enabled`

- `BosWar/EnemyAISettings.tres`
- Removed serialized fields:
- `bandit_infighting_enabled`
- `guard_infighting_enabled`
- `military_infighting_enabled`

- Active docs updated to reflect new behavior:
- `readme.md`
- `agents.md`
- `docs/context/agents/06-ai-architecture.md`

## Verification Results
1. Runtime/config surfaces
- Verified no `infight*` references remain in `BosWar/`.

2. Active documentation surfaces
- Verified no `infight*` references remain in:
- `agents.md`
- `readme.md`
- `docs/context/**`

3. Residual references intentionally retained
- Historical docs still contain infighting references under `docs/reports/**`, `docs/plans/**`, and archived session state (`.omx/**`).
- These were intentionally not rewritten to preserve historical investigation context.