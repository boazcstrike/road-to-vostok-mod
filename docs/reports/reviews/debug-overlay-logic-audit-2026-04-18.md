# Debug Overlay Logic Audit (2026-04-18)

## Scope
- Audit in-game debug overlay variable formatting and equation correctness.
- Files in scope:
  - `BosWar/Main.gd` (overlay render + counters)
  - `BosWar/AISpawner.gd` (spawn metric producers)
  - `BosWar/AI.gd` (combat/target metric producers; read-only unless required)

## Assumptions
- "Properly solved with the right equations" means displayed counters must reflect actual entity counts, including team spawns where one spawn event can create multiple agents.
- Keep existing overlay layout and style unless a label is mathematically misleading.

## Investigation Notes
- Root cause identified: `Main.gd::record_spawn()` increments counters by `1` per spawn event, but `AISpawner.gd::_handle_spawn_result()` can spawn multiple agents in one event (team spawning).
- Impacted overlay fields:
  - `Spawned This Map`
  - `Faction Totals`
  - `Role Totals`

## Decision
- Pass explicit `spawn_count` from `AISpawner.gd` to `Main.gd`.
- Default `spawn_count` to `1` when absent for backward compatibility.
- Do not change unrelated spawn systems, AI behavior, or overlay structure.

## Verification Plan
1. Update spawn event payload to include `spawn_count`.
   - Verify: payload contains `spawn_count` for both team and single-unit spawns.
2. Update overlay aggregation to apply `spawn_count` for all affected totals.
   - Verify: totals increase by team size for team spawns.
3. Sanity-check formatting/labels after changes.
   - Verify: overlay text remains valid and readable with no missing keys.

## Outcome (In Progress)
- Investigation complete; implementation underway.

## Outcome (Completed)
- Implemented `spawn_count` propagation from `AISpawner.gd` debug producer to `Main.gd` overlay aggregator.
- Corrected equations:
  - `Spawned This Map = Σ(spawn_count per spawn event)`
  - `Faction Totals[faction] = Σ(spawn_count where spawn_faction == faction)`
  - `Role Totals[role] = Σ(spawn_count where spawn_role == role)`
- Combat summary formatting updated to include `Other` hits so all tracked hit categories are represented in overlay text.
- Clarified overlay labels to match underlying math:
  - `Suspicious Spawn Events` (event count, not unique-agent count)
  - `Distance: <value>m` (explicit unit)

## Verification Notes
- Confirmed `_debug_record_spawn(...)` now carries `spawn_count`.
- Confirmed team spawn and single spawn call sites both pass `spawned_count`.
- Confirmed `record_spawn(...)` now scales all affected totals by `spawn_count` with guard `min=1`.
- No edits made to `Road to Vostok/` (read-only guardrail respected).
