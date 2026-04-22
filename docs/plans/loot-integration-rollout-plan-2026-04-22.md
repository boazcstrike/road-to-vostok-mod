# BetterEnemyLoot -> BosWar Integration Plan

Date: 2026-04-22  
Status: Approved for implementation (scope locked)  
Scope: Port only the enemy loot mechanism from `Reference Scripts/BetterEnemyLoot` into `BosWar` without changing unrelated combat/spawn behavior.

## 1) Assumptions

1. We are merging behavior into BosWar code, not running BetterEnemyLoot as a separate mod takeover.
2. `Road to Vostok/` remains read-only reference.
3. Success means:
   - Enemy loot behavior from BetterEnemyLoot is available in BosWar.
   - No regression in AI combat/targeting/spawn cadence.
   - No additional per-frame loot workload in hot paths.
4. Missing or unstable external dependency (`ModConfigurationMenu/.../MCM_Helpers.tres`) must not block runtime loot logic.

## 2) What We Need To Port

From `Reference Scripts/BetterEnemyLoot`:
- `AI.gd`: `ActivateContainer()` logic plus helpers:
  - `_weighted_count_BEL(max)`
  - `_pick_item_BEL(common, rare)`
  - `_add_ammo_BEL(container, ammo, amount)`
- `BetterEnemyLootSettings.gd` + `BetterEnemyLootSettings.tres` tunables.
- `ModConfig.gd` configuration behavior, adapted into BosWar's existing config flow.

From BosWar seams:
- Primary merge target: `BosWar/AI.gd` (currently no local `ActivateContainer()` override).
- Config truth path: `BosWar/Config.gd` -> `BosWar/EnemyAISettings.gd` / `.tres`.
- Existing death/corpse lifecycle: `BosWar/AI.gd` `Death(...)`, `BosWar/Main.gd` corpse tracking and cleanup.

## 3) Merge Approaches

### Approach A: Reuse BetterEnemyLoot script takeover as-is
- Summary: Run its `Main.gd` and `take_over_path("res://Scripts/AI.gd")`.
- Pros: Fastest short-term.
- Cons: High conflict risk with BosWar's own `take_over_path` chain; poor control of integration boundaries.
- Decision: Not recommended.

### Approach B: Native BosWar merge inside `BosWar/AI.gd` (Recommended)
- Summary: Implement BetterEnemyLoot loot generation by adding a BosWar-owned `ActivateContainer()` override and helpers.
- Pros: Stable with existing BosWar override model, single ownership, easy to gate and profile.
- Cons: Requires careful merge to avoid duplicated loot spawning and to preserve idempotency.
- Decision: Confirmed (user-approved on 2026-04-22).

### Approach C: Spawn-time pre-seeding in `AISpawner.gd`
- Summary: Build loot payload at spawn time instead of death activation.
- Pros: Reduces death-frame work spikes.
- Cons: Larger architecture shift, higher risk, more test surface.
- Decision: Defer; optional later optimization only if needed.

## 4) Recommended Plan (Phased)

### Phase 0 - Baseline Contract
1. Document current loot/death flow and known invariants.
2. Define non-regression rules (no duplicate rolls, no active-agent accounting drift, no extra per-frame loot loops).
Verify:
- Baseline checklist exists in this plan and is acknowledged before code changes.

### Phase 1 - Shadow Integration Hooks (No User-Visible Behavior Change)
1. Add a loot feature flag in BosWar settings (`loot_enabled`) defaulting to `true`.
2. Add placeholder hooks in `BosWar/AI.gd` for `ActivateContainer()` extension path while keeping effective behavior unchanged.
Verify:
- Before Phase 2 logic lands, runtime behavior is identical to baseline in kill/loot interaction.

### Phase 2 - Loot Logic Merge (Core)
1. Port BetterEnemyLoot helper methods into `BosWar/AI.gd` under BosWar naming/style.
2. Implement `ActivateContainer()` override:
   - call `super()`
   - apply bonus loot logic using container flags and weapon data
   - Punisher behavior: apply only what loot logic yields; if no valid loot is produced, add none
   - avoid duplicate materialization behavior
3. Keep all logic event-driven at container activation/death path only.
Verify:
- Single kill produces expected additional loot entries.
- Reopening same corpse does not reroll/duplicate.

### Phase 3 - Config Surface Merge
1. Add loot settings into `BosWar/EnemyAISettings.gd` and `.tres` defaults.
2. Add matching entries to `BosWar/Config.gd` (BosWar MCM path), including:
   - loot amount / rolls
   - max consumables
   - max medical
   - max magazines
   - max ammo
   - rare chance
   - loot debug (if retained)
3. Keep v1 settings global/shared across factions (no faction-specific loot setting split).
4. Ensure config sync functions keep defaults and persisted values aligned.
Verify:
- Settings changes persist across reload and affect loot output as expected.

### Phase 4 - Runtime Validation and Perf Guardrails
1. Faction parity checks: kill Bandit/Guard/Military and inspect loot composition.
2. Stress run: many deaths, confirm no active-agent underflow and no corpse cleanup breakage.
3. Perf check: ensure no added work in AI hot loops (`Sensor`, targeting scans, spawner `_physics_process`).
Verify:
- All checks pass with no new errors and no obvious frame hitch regression during kill bursts.

### Phase 5 - Rollout Default and Cleanup
1. Keep `loot_enabled=true` as the runtime/config default.
2. Remove temporary high-volume traces; keep protocol-compliant debug toggles only.
3. Finalize docs and rollback notes.
Verify:
- Final settings defaults are explicit and documented.
- Rollback path is one toggle or one revert set.

## 5) Multi-Agent Execution Blueprint (For Implementation Session)

1. Worker A (AI merge owner): `BosWar/AI.gd`
   - Owns `ActivateContainer()` and helper merge.
2. Worker B (config owner): `BosWar/Config.gd`, `BosWar/EnemyAISettings.gd`, `BosWar/EnemyAISettings.tres`
   - Owns settings surface and persistence wiring.
3. Worker C (validation/docs owner): `docs/reports/...` + runtime checklist artifact
   - Owns validation evidence and rollback checklist.

Integration rule:
- Workers must not revert each other's edits and must adapt to concurrent changes.

## 6) Binary Success Criteria

1. `BosWar` contains native loot integration without relying on BetterEnemyLoot `take_over_path` bootstrap.
2. Loot appears via BosWar AI death/container path for all target factions.
3. No duplicate loot rolls on same corpse interaction.
4. Existing BosWar spawn/combat counters and corpse cleanup still behave correctly.
5. Config values persist and influence loot behavior deterministically.
6. Perf-sensitive loops remain free of new loot-related per-frame processing.

## 7) Known Risks and Mitigations

1. Container API mismatch (`CreateLoot`/`SpawnItems` semantics).
   - Mitigation: validate exact container lifecycle before finalizing `ActivateContainer()`.
2. Override chain conflicts with external mods.
   - Mitigation: keep integration inside BosWar override path only.
3. Missing MCM helper dependency in some environments.
   - Mitigation: do not block runtime loot logic on optional config UI helpers.
4. Allocation spikes from repeated filters during mass deaths.
   - Mitigation: keep work bounded and event-triggered; profile kill bursts.

## 8) Locked Decisions (2026-04-22)

1. Approach B is confirmed for implementation.
2. `loot_enabled` default is `true`.
3. Punisher behavior uses only loot logic output; if no valid loot, add none.
4. v1 uses global/shared loot settings across factions.
