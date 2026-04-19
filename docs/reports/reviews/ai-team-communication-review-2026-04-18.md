# AI Team Communication Code Review - 2026-04-18

## Task
Review the AI team communication system for correctness and optimization opportunities.

## Scope
- `BosWar/AI.gd`
- `BosWar/AISpawner.gd`
- `BosWar/EnemyAISettings.gd`
- `BosWar/Config.gd`

## Assumptions
- This is an investigation-only task (no gameplay behavior changes implemented in this pass).
- Canonical faction names are `Bandit`, `Guard`, and `Military`.
- AI update methods (`Parameters`, `Sensor`) run frequently and scale concerns matter at 32+ active agents.

## Findings (Severity-Ordered)
1. High: `audio_player` emits from sender but is rejected by receiver validation.
   - `AI.gd`: 139, 144, 1038, 1382
2. High: Broadcast cooldowns can stop decrementing when custom AI targeting is inactive due to early return.
   - `AI.gd`: 693-695, 707-708
3. High: `Sensor()` branch around teammate-target reaction has inconsistent indentation and duplicate assignment, risking broken state handoff.
   - `AI.gd`: 84-90
4. Medium: Player-audio types are misclassified into AI cooldown bucket for most message variants.
   - `AI.gd`: 1345-1346, 141, 143, 158, 166
5. Medium: Invalid teammate messages still overwrite last-known-location memory before validation.
   - `AI.gd`: 1377-1383
6. Medium: Faction case mismatch (`Bandit` vs `bandit`) can disable intended bandit-specific fire behavior.
   - `AI.gd`: 1016-1022, 1310
7. Medium: O(N^2) scaling in target acquisition and team broadcast loops, with frequent LOS/raycast checks.
   - `AI.gd`: 710, 918-933, 1344-1369
8. Medium: Audio sensing scans all agents per listener.
   - `AI.gd`: 822, 854-873
9. Medium: Team/faction config surface is partially unsurfaced in MCM config flow.
   - `EnemyAISettings.gd`: 49-61
   - `Config.gd`: 357-389
10. Low: Team release/occupancy cleanup does full scans and temporary collection builds during replenish.
    - `AISpawner.gd`: 1031-1047

## Tradeoffs
- Fixing correctness issues first prevents optimization from preserving flawed behavior.
- Structural optimization (registries/spatial buckets) adds complexity but is necessary for high-population firefights.
- Keeping communication faction-wide is simple but expensive; moving toward team-scoped + nearby subset reduces cost with small tactical behavior changes.

## Recommendations
1. Stabilization pass (first):
   - Unify message type taxonomy (`player`, `audio_player_*`, `ai`, `audio_ai_*`) with helper predicates.
   - Move teammate-target validation ahead of memory mutation.
   - Decouple cooldown ticking from custom-targeting early returns.
   - Correct `Sensor()` block structure around AI-target reaction.
2. Performance pass (second):
   - Add `AISpawner` registries: `agents_by_faction` and coarse spatial buckets.
   - Query shortlist first; raycast only top-K target candidates.
   - Broadcast only to nearby same-faction/team subset and dedupe repeated events in short windows.
3. Config/architecture pass (third):
   - Either expose team-spawn tuning fields in `Config.gd` + MCM, or deprecate/remove hidden knobs.
   - Normalize faction string handling at boundaries.

## Outcome
- Review completed with concrete correctness defects and optimization roadmap.
- No runtime code changes applied in this pass.

## Cross-References
- Related review context: `docs/reports/reviews/boswar-code-review-2026-04-18.md`
- Agent guidance: `agents.md`, `docs/context/agents/06-ai-architecture.md`
