# spawn-point-accuracy-hardening-2026-04-18

## Task
Improve spawn-point accuracy so AI avoids bad spawns caused by walls, floor mismatch, and prop collisions.

## Date
2026-04-18

## Scope
- Harden `BosWar/AISpawner.gd` spawn-point validation and final placement.
- Focus on correctness up to AI activation (`ActivateWanderer()`).
- Keep `Road to Vostok/` read-only.

## Assumptions
- Base game spawn system only validates distance and trusts map markers.
- AI collision envelope is approximately capsule radius `0.25`, height `1.4`, center Y offset `1.2` in base unit scenes.
- Additional physics checks are acceptable because they run per spawn attempt, not every frame for every AI.

## Multi-Agent Inputs
1. Base spawner behavior review:
   - Confirmed vanilla has no floor/collision/nav checks for spawn placement.
2. Spawn hardening recommendation review:
   - Suggested safe-position resolver and replacing blind random offsets for team members.

## Changes Made
1. Added strict floor sampling helper:
   - `_sample_floor_at_position(...)` validates floor hit, slope normal, and vertical delta.
2. Added collision/obstacle checks:
   - `_find_spawn_overlap(...)` uses capsule overlap query and short wall/prop ray probes.
3. Added safe-position resolver:
   - `_resolve_safe_spawn_position(...)` tests center, inner ring, and outer ring offsets.
4. Replaced non-team fallback:
   - `SpawnWanderer()` no longer calls `super()` for non-team mode.
   - Added `_spawn_single_wanderer()` to use the same safe placement pipeline.
5. Hardened team placement:
   - `_spawn_team_at_location(...)` now resolves a safe pose per member and enforces spacing between spawned teammates.
6. Improved spawn audit classification:
   - `_sample_floor_audit(...)` now reports overlap-related issues (e.g., geometry overlap / wall or prop proximity).
   - `_audit_spawned_agent(...)` now logs collider name for suspicious spawns.

## Tradeoffs
- Spawn accuracy checks increase physics query count per spawn attempt.
- In tight areas, team spawns may partially spawn rather than forcing overlap.

## Outcome
- AI placement now validates floor quality and collision clearance before activation.
- Team and non-team wanderer spawns use the same safe placement rules.
- Debug output provides concrete reasons for suspicious spawns to speed map tuning.

## Cross-References
- `docs/reports/reviews/spawn-system-code-review-2026-04-18.md`
- `docs/domains/spawn-orchestration-and-population/README.md`
