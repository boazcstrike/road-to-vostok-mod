# Loot Integration Rollout Progress (2026-04-22)

## Scope
- Implementation + docs update for the current loot integration pass.
- Code scope: `BosWar/AI.gd`, `BosWar/Config.gd`, `BosWar/EnemyAISettings.gd`, `BosWar/EnemyAISettings.tres`.

## Assumptions
- Implementation owners will execute the plan in `docs/plans/loot-integration-rollout-plan-2026-04-22.md`.
- Integration remains native to BosWar (no BetterEnemyLoot `take_over_path` takeover).
- `Road to Vostok/` stays read-only.

## Approved Decisions
- Approach B is confirmed.
- `loot_enabled=true` by default.
- Punisher behavior: apply only loot logic output; if no valid loot is produced, add none.
- v1 uses global/shared loot settings across factions.

## Tradeoffs
- Global/shared settings (v1) reduce config complexity and rollout risk, but remove faction-level tuning for now.
- `loot_enabled=true` improves out-of-box behavior, but raises initial regression risk if integration bugs exist.
- No Punisher fallback loot preserves deterministic loot rules, but may produce empty loot in edge cases.

## Verification Checklist (Implementation Pass)
- `BosWar/AI.gd` uses native `ActivateContainer()` integration without BetterEnemyLoot takeover bootstrap.
- Default config path resolves `loot_enabled` to `true` at runtime and after reload.
- Punisher path never injects forced fallback loot when loot logic returns no valid item.
- Loot settings are shared/global only (no per-faction split in v1).
- Reopening the same corpse does not duplicate/re-roll loot.
- No loot processing added to per-frame AI hot loops.

## Progress
- Plan file updated with locked decisions and removed unresolved review questions.
- Added native `ActivateContainer()` loot integration in `BosWar/AI.gd` using event-driven logic and settings-backed tunables.
- Added BosWar config surface for loot controls with default `loot_enabled=true`.
- Added loot settings defaults in `EnemyAISettings.gd/.tres`.
- Preserved infighting settings/logic after integration pass to avoid out-of-scope behavior regressions.
- Runtime in-engine validation is still pending.

## Optimization Update (Caching)
- Cached: loot pool classification (consumable/medical, common/rare) derived from `LT_Master.items`.
- Cache key/invalidation: key by `(LT_Master instance id, profile tag)` where profile is `all|industrial|civilian`; invalidate by rebuilding when source item count changes. Cache is hard-capped and cleared when oversized.
- Randomness is not cached globally: RNG evaluation must stay per-entity and per-open lifecycle to preserve drop variability and avoid cross-corpse coupling artifacts.
- Pending validation: verify no duplicate loot on repeated open, verify cache refreshes when loot tables change, verify reload/new session starts clean, and verify no unintended memory growth during long fights.
