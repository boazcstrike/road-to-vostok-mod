# Team Hostility and Combat Rules Report - 2026-04-19

## Purpose
Define the canonical team-hostility behavior and remove duplicated notes about team fighting defaults.

## Current Rules
1. If two AI agents have valid `team_id` values and the IDs differ, they are hostile.
2. If team metadata is not available, hostility falls back to faction rules.
3. Same-faction hostility follows per-faction infighting settings.
4. Cross-faction hostility follows `warfare_enabled` and supported faction checks.

## Implementation References
- `BosWar/AI.gd`
  - `_custom_ai_targeting_active()`
  - `_is_hostile_faction(...)`
  - faction normalization paths used by hostility and teammate checks

## Why This Consolidation Exists
Three prior docs captured overlapping snapshots of the same issue and fix path:
- `enable-team-fighting-default.md`
- `enable-team-infighting.md`
- `reports.md`

This file is the canonical replacement.

## Runtime Verification Checklist
1. Spawn at least two teams with distinct `team_id` values.
2. Confirm hostile AI target acquisition occurs between different teams.
3. Confirm same-faction different-team pairs can engage.
4. Toggle infighting/warfare settings and verify fallback behavior still matches expectations.
