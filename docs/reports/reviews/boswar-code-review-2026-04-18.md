# BosWar Code Review - 2026-04-18

## Scope
- Reviewed only `BosWar/` scripts, per request.
- Focus areas: performance, architecture/scalability, Godot best practices, and robustness.

## Assumptions
- Runtime target is Godot 4.x (syntax and APIs suggest Godot 4).
- `BosWar/AI.gd` and `BosWar/AISpawner.gd` are active runtime overrides (not dead code).
- Base game scripts in `Road to Vostok/` are read-only and not modified.

## Review Process Notes
- Mapped execution hotspots first: `AI.gd` sensor/targeting loops and `AISpawner.gd` spawn validation logic.
- Checked cross-script coupling in `Main.gd`, `Config.gd`, `Character.gd`, and `DebugUtils.gd`.
- Captured findings with file/line anchors for direct remediation.

## Key Findings (Draft)
1. Potential parse/logic break in `AI.gd` around `Sensor()` indentation near lines 84-90.
2. Team spawn occupancy tracking can release wrong spawn points (`AISpawner.gd`), causing overlap/regression.
3. Target acquisition and teammate broadcasts allocate and iterate aggressively under high AI counts.
4. Debug utility checks an undeclared settings field (`show_debug_logs`) creating silent behavior drift.
5. Main debug/corpse maintenance runs every frame and scales linearly with corpse list size.

## Design/Tradeoff Notes
- Current approach favors quick feature layering via metadata/dictionaries, but this increases runtime overhead and weakens type safety.
- A small state/data refactor (typed target snapshot + signal-based team comms) can preserve behavior while reducing per-agent costs.

## Outcome
- Produced prioritized review findings and a concrete refactor example for critical snippet hardening.

## Final Findings
1. `AI.gd` `Sensor()` has inconsistent indentation around the AI-target branch (lines ~84-90), which risks parse failure or unintended control flow.
2. `AISpawner.gd` spawn-point occupation tracking is not keyed by team, then released by `pop_back()`, so unrelated spawn points can be freed and reused incorrectly.
3. `AI.gd` broadcasts classify only `"audio_player"` as player-audio; more specific values (`audio_player_running`, `audio_player_gunshot`) are misbucketed into AI cooldown flow.
4. `AI.gd` `_receive_teammate_target_info()` writes last known location before validating target payload.
5. `AI.gd` `_acquire_best_target()` and teammate loops create O(N^2) behavior with repeated LOS raycasts and dictionary churn at higher active counts.
6. `DebugUtils.gd` references `show_debug_logs`, but `EnemyAISettings.gd` does not define/export that field.

## Recommended Direction
- Introduce a typed target snapshot (`class_name TargetSnapshot` or lightweight `Resource`) to replace ad-hoc dictionaries in hot paths.
- Replace linear team spawn-point tracking array with explicit `Dictionary<int, Node3D>` mapping (`team_id -> spawn_point`) to ensure deterministic release.
- Move teammate communication to signal-based fanout (or a centralized broker in spawner) to reduce direct cross-agent coupling.
- Add validation-first pattern for all externally received target updates.
