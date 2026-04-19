# Task Context: Base AISpawner Spawn Validation Audit

## Goal
Inspect `Road to Vostok/Scripts/AISpawner.gd` and extract spawn-point validation and spawn-positioning assumptions that must be preserved in `BosWar/AISpawner.gd`.

## Scope
- Read-only inspection of base file.
- No edits in `Road to Vostok/` (guardrail respected).
- Focused on spawn validation assumptions: collision, floor checks, navigation constraints.

## Findings (Base Behavior)
- Spawn-point eligibility for wanderers is distance-only:
  - Candidate must satisfy `distance_to(player) > spawnDistance`.
  - No physics raycast, floor normal, collision overlap, or navmesh query in base.
- Guard/hider spawns do not validate distance or floor:
  - Guard picks any patrol point if patrol list is non-empty.
  - Hider picks random hide point without empty-list guard.
- Spawn positioning uses marker transforms:
  - Wanderer/Guard/Hider use `newAgent.global_transform = selected_point.global_transform`.
  - This copies both world position and orientation from map points.
- Minion/Boss spawns trust caller-provided world position:
  - `newAgent.global_position = spawnPosition` only.
  - No grounding/snap-to-floor/nav constraints in spawner.
- Waypoint assignment is decoupled from spawn validation:
  - `currentPoint` set to selected spawn/patrol/hide marker.
  - Minion/Boss set `currentPoint = waypoints.pick_random()` with no route/path precheck.

## Implementation Constraints to Preserve in BosWar
- Keep distance gating semantics intact for wanderer spawn candidates:
  - Preserve strict comparison behavior (`>` equivalent, not `>=` unless intentionally changed).
- Preserve transform-based placement for marker-based spawns where orientation matters.
- Keep spawn point groups (`AI_SP`, `AI_PP`, `AI_HP`, `AI_WP`) as authoritative map-authored anchors.
- Treat spawner as lightweight selector/placer:
  - Avoid introducing heavy nav/path checks in hot spawn loops unless explicitly required.
- If adding floor/collision validation, keep tolerance broad enough to preserve existing authored spawn points and avoid changing spawn distribution unexpectedly.
- Preserve pool-first spawning flow:
  - Must still require available pooled agents before spawn placement/activation.

## Tradeoffs / Risks
- Base has permissive assumptions; stricter validation can reduce effective spawn density if many legacy points are slightly off-floor or near obstacles.
- Random hider spawn assumes hides array is non-empty; hardening this check changes failure mode from runtime error to no-spawn.

## Outcome
Concrete preservation constraints extracted and ready to apply to `BosWar/AISpawner.gd` evolution.

