# AI Suppression Comparison Prep (BosWar vs ImmersiveXP)

Date: 2026-04-22  
Scope: `BosWar` and `Reference Scripts/ImmersiveXP` suppression behavior review + BosWar implementation follow-up.

## Intent
This document compares current BosWar suppression behavior against ImmersiveXP's suppression approach, identifies merge risks, and proposes BosWar-first options.

Initial review was deferred, then implemented in the same date after user confirmation.

## Files Reviewed
- `BosWar/AI.gd`
- `BosWar/EnemyAISettings.gd`
- `BosWar/EnemyAISettings.tres`
- `Reference Scripts/ImmersiveXP/AI.gd`
- `Reference Scripts/ImmersiveXP/OverhaulSettings.gd`
- `Reference Scripts/ImmersiveXP/OverhaulSettings.tres`

## Current BosWar Suppression Behavior (Observed)
1. Suppression is integrated into engagement gating and target model.
- `Fire(delta)` computes suppression modes before firing: `suppressive_player_fire` and `hidden_ai_suppressive` (`BosWar/AI.gd:372-389`).
- Engagement is allowed if visible OR suppression predicates pass (`_can_fire_engagement`, `BosWar/AI.gd:866-867`).

2. Player suppression is teammate-message driven with explicit duration window.
- Start/clear/check helpers:
  - `_start_teammate_player_suppressive_fire` (`BosWar/AI.gd:826-831`)
  - `_clear_teammate_player_suppressive_fire` (`BosWar/AI.gd:833-835`)
  - `_has_active_teammate_player_suppressive_fire` (`BosWar/AI.gd:837-842`)
- Duration constants are long-window by design: `TEAMMATE_PLAYER_SUPPRESSIVE_FIRE_MIN_SECONDS=15`, `MAX_SECONDS=60` (`BosWar/AI.gd:65-66`).

3. Hidden-AI suppression exists for AI-vs-AI when LOS is lost but target memory is valid.
- `_can_hidden_ai_suppressive_fire` requires: target type AI, valid hostile target, non-manual weapon, not currently visible, and valid LKL (`BosWar/AI.gd:851-864`).
- Shot throttling/chance path in `Fire(delta)` uses `AI_HIDDEN_SUPPRESSIVE_SPRAY_CHANCE` (`BosWar/AI.gd:68`, `394-396`).

4. Suppression is tied to current BosWar targeting semantics.
- Engagement position resolves to teammate suppression target or LKL depending on target type (`BosWar/AI.gd:2342-2350`).
- Team comms can promote player target and immediately arm suppressive window (`BosWar/AI.gd:2642-2647`).

## ImmersiveXP Suppression Approach (Observed)
1. Suppression is largely a mode flag (`suppressiveFire`) toggled by visibility/fire-detection events.
- Flag declaration and visibility-driven toggling (`Reference Scripts/ImmersiveXP/AI.gd:9`, `108-124`).
- Surprise-fire path toggles suppression probabilistically and depends on `overhaulSettings.aiSuppresses` (`Reference Scripts/ImmersiveXP/AI.gd:195-201`).

2. Combat state loops keep firing if `suppressiveFire` is true even when not currently visible.
- `Defend/Combat/Shift` call `Fire(delta)` on `elif suppressiveFire` (`Reference Scripts/ImmersiveXP/AI.gd:628-631`, `715-717`, `731-733`).

3. Suppression configuration is simple global toggle.
- `OverhaulSettings.aiSuppresses` resource field (`Reference Scripts/ImmersiveXP/OverhaulSettings.gd:27`).

4. ImmersiveXP suppression is tightly coupled to its own state machine and fire-detection variables.
- Depends on `playerWasSeen`, `playerSeenTimer`, `fireVector`, `gameData.isSuppressed`, `lastKnownLocation` (`Reference Scripts/ImmersiveXP/AI.gd:180-230`).

## Overlap
- Both systems allow firing continuation beyond immediate visibility if memory/context still supports engagement.
- Both bias toward full-auto behavior during suppression windows.
- Both rely on LKL-style constraints (`distance_to(...) > 4.0` guards in fire path).

## Key Differences
1. Trigger model:
- BosWar: comms + typed target model (`player` vs `ai`) + explicit helper predicates.
- ImmersiveXP: local `suppressiveFire` mode flag switched by event heuristics.

2. Scope:
- BosWar: supports player suppressive queue and hidden AI-vs-AI suppressive fire with separate checks.
- ImmersiveXP: player-centric suppression logic; no BosWar-style hostile-faction AI target framework.

3. Lifespan control:
- BosWar: explicit timer window (`15-60s`) with lifecycle clear points.
- ImmersiveXP: indirect lifecycle through visibility timers/state transitions.

4. Integration depth:
- BosWar: suppression is wired into current targeting, comms, and engagement selectors.
- ImmersiveXP: suppression is embedded in a different AI state flow and globals (`gameData`, `currentState`, etc.).

## Risks If We Merge Naively
1. High conflict risk with BosWar target architecture.
- Importing ImmersiveXP suppression blocks directly would bypass/compete with BosWar functions like `_should_force_suppressive_player_fire` and `_can_hidden_ai_suppressive_fire`.

2. Behavior regression risk in AI-vs-AI warfare.
- ImmersiveXP is not built around BosWar's faction-hostility/typed target plumbing; direct port may reduce current AI-vs-AI suppression fidelity.

3. Stability and tuning drift risk.
- BosWar currently has explicit suppression duration and gating semantics; replacing with event-flag mode can reintroduce retarget/firing churn.

4. MCM/settings model mismatch.
- BosWar settings resource differs from ImmersiveXP `OverhaulSettings`; direct setting import would create config duplication/confusion.

## BosWar-First Merge Options (No Implementation Yet)
1. Option A: Keep BosWar suppression architecture, add MCM toggle + intensity scalar only.
- Add a BosWar-native `ai_suppression_enabled` and `ai_suppression_intensity` setting.
- Wire only constants/probabilities (`AI_HIDDEN_SUPPRESSIVE_SPRAY_CHANCE`, teammate suppression trigger odds), not control flow replacement.
- Lowest conflict, best fit with "BosWar takes priority".

2. Option B: Adopt one ImmersiveXP heuristic as an additive trigger.
- Keep existing BosWar helper predicates.
- Add a narrow "surprise fire" trigger (analog to `FireDetection` surprise path) that only arms existing BosWar suppression window.
- Medium risk; requires careful guardrails to avoid over-triggering.

3. Option C: Hybrid suppression policy layer (mapping, not transplant).
- Define BosWar policy function that selects suppression mode from current context (visible/lost LOS/comms/target type/ammo).
- Reuse select ideas from ImmersiveXP (probabilistic suppress behavior), but output only into BosWar-native helpers and timers.
- Highest design effort, best long-term control.

## Recommendation
- Preferred next step: Option A first (minimal invasive, BosWar-safe).
- Hold Option B/C until you choose whether you want more aggressive or more stable suppression behavior.

## Decision Gates Requiring User Confirmation Before Any Code
1. Should suppression settings be exposed in BosWar MCM now (`enabled`, `intensity`) or only hardcoded defaults first?
2. Do you want any ImmersiveXP-style "surprise fire" behavior at all, or strictly current BosWar comms/LKL suppression only?
3. For suppression aggressiveness, should we favor stability (fewer triggers) or pressure (more full-auto windows)?

## Implementation Follow-Up (Requested)
Cross-reference: `docs/plans/immersivexp-merge-prep-2026-04-22.md`

### Assumptions
1. BosWar faction/team hostility behavior must remain unchanged.
2. No new global suppression setting or MCM toggle should be added.
3. Suppression lifespan should be ammo-driven (`2` magazine budgets), not timer-driven.

### Design Chosen
1. Replaced timer-based suppression helpers with a BosWar-local mode flag state:
- `_suppressive_fire_active`
- `_suppressive_fire_target_type`
- `_suppressive_fire_target_position`
- `_suppressive_fire_rounds_remaining`
2. Suppression is armed by event triggers:
- Player visibility acquisition (`_sense_player_los` transition handling)
- Player gunfire detection (`FireDetection`)
- AI target visibility acquisition (`_update_target_visibility`)
- Teammate player-target intake (`_apply_queued_teammate_target_info`)
3. Suppression consumption/lifecycle:
- Each suppressive shot consumes one round from a dedicated suppression budget.
- Budget starts at `2 x magazineSize` per newly armed suppressive mode.
- Budget reaching `0` clears suppression mode.

### BosWar Integration Constraints Preserved
1. Team hostility and warfare target selection flow were not altered.
2. Existing target typing (`player` vs `ai`) remains authoritative.
3. No ImmersiveXP `OverhaulSettings.aiSuppresses`-style global toggle was imported.

### Outcome
1. Combat loops still use BosWar `_can_fire_engagement()`, now backed by visible OR suppression-mode checks.
2. Suppressive fire can continue briefly after LOS loss through last known position, but lifespan is now bounded by weapon capacity budget instead of a wall-clock timer.
3. Hidden AI suppressive spray chance remains constrained by `AI_HIDDEN_SUPPRESSIVE_SPRAY_CHANCE` to avoid over-firing churn.

### Tuning Pass (Requested)
1. `SUPPRESSIVE_FIRE_MAGAZINES` kept at `2` to preserve the requested "full-auto with two mags" suppression lifespan.
2. `AI_HIDDEN_SUPPRESSIVE_SPRAY_CHANCE` tuned from `0.35` to `0.30` to reduce hidden AI-vs-AI spray churn while keeping suppression pressure active.
