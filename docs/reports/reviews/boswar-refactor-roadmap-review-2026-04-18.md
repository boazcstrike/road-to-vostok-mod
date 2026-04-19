# boswar-refactor-roadmap-review-2026-04-18

## Task
Review `BosWar/` for code pattern standardization, complexity reduction, idiomatic GDScript improvements, and performance/concurrency scalability opportunities.

## Date
2026-04-18

## Scope
- Read-only review of `.gd` scripts in `BosWar/`.
- No gameplay/code modifications.
- Produce phased practical refactor roadmap.

## Cross-References
- `docs/reports/reviews/codebase-architecture-review-2026-04-18.md`
- `AGENTS.md` (repo operational contract)

## Inventory Snapshot
- `AI.gd`: 1453 lines, 81 funcs
- `AISpawner.gd`: 943 lines, 47 funcs
- `Config.gd`: 544 lines, 7 funcs (`_ready` is 347 lines)
- `Main.gd`: 346 lines, 17 funcs

## Key Findings
1. **Naming/style drift is broad**: many camelCase names and PascalCase method names remain in mod layer.
2. **Complexity hotspots**:
   - `AI.gd::_acquire_best_target` (69 lines)
   - `AI.gd::_receive_teammate_target_info` (57 lines)
   - `AI.gd::Decision` (47 lines)
   - `AISpawner.gd::_handle_spawn_result` (49 lines)
   - `Config.gd::_ready` (347 lines)
3. **Likely correctness issues**:
   - `AI.gd` line ~84 appears to contain a mis-indented block under `Sensor`.
   - `AI.gd::Selector` checks `_self_faction() == "bandit"` while other code uses `"Bandit"`.
   - `AISpawner.gd::_build_faction_pool` applies 10:3:1 weighting then `_dedupe_faction_pool`, likely collapsing weight.
   - `DebugUtils.gd` reads `show_debug_logs`, but `EnemyAISettings.gd` does not declare/export it.
4. **Scalability bottlenecks**:
   - AI-to-AI target scanning and LOS checks are effectively O(N²) under load.
   - frequent `get_children()` scans and repeated dictionary allocations in hot paths.
   - coroutine/timer bursts (`await create_timer`) in fire/audio/spawn audit paths.
5. **Observability overhead**:
   - heavy `DebugUtils._debug_log` use in spawn paths; currently always printing timestamped logs.

## Roadmap Skeleton
- **Quick wins**: correctness fixes + lightweight style/perf cleanups in hot paths.
- **Medium**: split monolithic functions into tactical modules and centralize constants/types.
- **Long-term**: AI perception/query architecture shift (spatial partition + scheduled batches + event bus).

## Notes
- Recommendations should preserve behavior unless a bug is explicitly fixed.
- Keep changes surgical and measurable with per-phase acceptance checks.
