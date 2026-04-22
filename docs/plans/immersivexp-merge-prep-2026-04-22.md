# ImmersiveXP Merge Prep Plan (No Implementation Yet)

<!-- Planning-only context file. No gameplay code changes were made in this task. -->
<!-- Reference source: https://modworkshop.net/mod/50811 -->

## Objective
Plan how to merge selected ImmersiveXP features from `Reference Scripts/ImmersiveXP` into BosWar safely, with explicit risk controls and zero blind full-script replacement.

## Scope and Constraints
- Scope now: analysis and planning only.
- No implementation in this pass.
- Keep `Road to Vostok/` read-only.
- Assume BosWar remains the primary mod behavior authority for enemy AI/spawn logic.

## Assumptions
- The target is selective feature integration, not wholesale ImmersiveXP import.
- BosWar's current faction combat, target-lock, teammate queue, and spawn-ratio behavior must not regress.
- Existing BosWar MCM settings remain user-visible and backward compatible.

## ImmersiveXP Feature Mapping (Where It Lives)

1. Weapons auto-equip + auto-draw when hands empty
- `Reference Scripts/ImmersiveXP/Interface.gd:134-173` (`IXPAutoEquip`, `DrawPrimary/Secondary/Knife/Grenade*`).
- Trigger path: `AutoStack(...)` calls `IXPAutoEquip(...)` at `Interface.gd:8-12`.

2. Immersive interactions (lower weapon + interaction delay)
- `Reference Scripts/ImmersiveXP/Interactor.gd:21-79`.
- Uses `overhaulSettings.interactLowersWeapon` and timed delays (`0.2s/0.3s`) before interact execution.

3. AI vision rework (light/weather/movement/indoor/flashlight)
- Vision cone gate: `Reference Scripts/ImmersiveXP/AI.gd:78-90`.
- Dynamic cone threshold by distance: `AI.gd:83` (`minViewRadius = clamp(remap(...), 0.5, 1.0)`).
- Visibility distance model: `AI.gd:1315-1352` (`IXPGetVisibilityDistance`).

4. AI hearing rework (movement/surface/interactions/weather/indoor)
- `Reference Scripts/ImmersiveXP/AI.gd:1280-1313` (`IXPGetHearingDistance`).
- Includes movement state, surface type, interaction noise floor, weather/wind, flashlight-facing edge case.

5. AI reload system (configurable)
- Ammo state + reload timers: `AI.gd:14-17`, `AI.gd:1354-1391`.
- Fire path decrements ammo when enabled: `AI.gd:820-823`.
- Config knob: `Reference Scripts/ImmersiveXP/Config.gd:133-138`, mapped at `Config.gd:402`.

6. AI suppression system (configurable)
- Suppressive flags and usage: `AI.gd:9`, `AI.gd:111`, `AI.gd:195-201`, `AI.gd:628`, `AI.gd:715`, `AI.gd:731`, `AI.gd:777`.
- Config knob: `Reference Scripts/ImmersiveXP/Config.gd:140-145`, mapped at `Config.gd:403`.

7. AI count/spawn knobs (MCM)
- Runtime use: `Reference Scripts/ImmersiveXP/AISpawner.gd:7-8, 24-26`.
- Defaults/ranges: `Reference Scripts/ImmersiveXP/Config.gd:33-85` (active min/max 4-6; total min/max 12-18).

8. AI combat/behavior tweaks
- React to fire + shift/push decisions tied to `takingFire`: see `AI.gd:180-246`, selector behavior at `AI.gd:862-890`.
- Door-closing behavior: `AI.gd:3-5`, `AI.gd:251-283`.
- Accuracy shaping: `AI.gd:968-1010`.

9. AI sound rework (shot delay + crack/flyby behavior)
- Shot sound delay by distance: `AI.gd:854-859`.
- Crack/flyby logic after ray hit/miss: `AI.gd:927-935`, audio functions `AI.gd:1219-1250`.

10. NVG/ADS/QoL visual and handling systems
- NVG canted-scope restriction: `Reference Scripts/ImmersiveXP/WeaponRig.gd:63-67`.
- ADS zoom (ALT by default in config): `Config.gd:147-152`, consumed in `WeaponRig.gd:53-55`.
- ADS/NVG blur behavior: `Reference Scripts/ImmersiveXP/Camera.gd:11-37`.
- Jump/sprint lowering: `WeaponRig.gd:72`, `Handling.gd` integration.

## BosWar Current Seams (Conflict-Sensitive)
- BosWar overrides scripts from `BosWar/Main.gd:50-53`: `AI.gd`, `AISpawner.gd`, `Character.gd`, `Loader.gd`.
- BosWar AI already has custom:
  - target-priority lock + teammate queue + visibility hysteresis (`BosWar/AI.gd`, many call sites);
  - teammate-driven suppressive fire windows (`BosWar/AI.gd:65-67`, `826-851`);
  - ammo/reload gating (`BosWar/AI.gd:67`, `464-515`);
  - hearing/sight multipliers via settings (`BosWar/AI.gd:196-237`, `2229-2240`).
- BosWar spawn presets include low-density preset with cap 9 (`BosWar/AISpawner.gd:414-418`) and faction-spawn behavior linked to BosWar settings.
- BosWar already has startup loadout logic in `BosWar/Loader.gd:12-60`.

## High-Risk Conflicts

1. Script ownership collision
- ImmersiveXP globally overrides many core scripts in `Reference Scripts/ImmersiveXP/Main.gd:7-27` and takes over `Database.gd` (`Main.gd:32-33`).
- If merged naively, one mod's `take_over_path` can silently replace the other at runtime.

2. AI behavior regression risk
- ImmersiveXP AI is a broad replacement (`Reference Scripts/ImmersiveXP/AI.gd`) and can override BosWar's existing faction/teammate/target-lock architecture.
- High chance of losing BosWar-specific behaviors (priority-distance lock, queue budgets, hysteresis tuning, teammate suppressive behavior).

3. Spawn-policy conflict
- ImmersiveXP active/total random range model (`AISpawner.gd:7-8`) does not match BosWar's preset/cap/ratio model.
- Direct adoption can break current BosWar balance expectations and map pacing.

4. Player-system blast radius
- Auto-equip, interactor delays, NVG/ADS/weapon rig, and camera changes require overriding player/UI scripts BosWar currently does not own.
- This significantly increases compatibility risk with other mods and future base game updates.

5. Settings namespace drift
- Separate MCM domains (`user://MCM/ImmersiveXP` vs `user://MCM/BosWar`) are fine for coexistence, but partial merge needs a unified BosWar config contract to avoid split controls.

## Recommended Merge Strategy (Phased)

1. Phase 0: Stabilize ownership map
- Build an explicit script-ownership matrix: base script -> BosWar override -> ImmersiveXP override -> intended owner.
- Success condition: every target script has one clear owner and documented merge seam.

2. Phase 1: AI-only selective port (lowest blast radius first)
- Port formulas/logic chunks into BosWar AI instead of replacing `BosWar/AI.gd` wholesale.
- Candidate imports:
  - dynamic vision cone thresholding;
  - context-aware hearing distance factors;
  - optional shot-crack ordering refinement.
- Success condition: BosWar AI custom systems still present and behaviorally unchanged unless explicitly targeted.

3. Phase 2: Spawn tuning parity as optional profile
- Recreate Immersive-like count ranges under BosWar settings as a new optional preset, not default replacement.
- Success condition: current BosWar defaults remain intact; new preset opt-in only.

4. Phase 3: Player interaction/QoL features behind explicit toggles
- Auto-equip, interaction delays, NVG/ADS/visual tweaks only after explicit user sign-off per sub-feature.
- Success condition: each feature can be enabled/disabled independently and does not require importing ImmersiveXP wholesale.

## Verification Plan (Binary)
1. Ownership check -> Verify: no script has ambiguous runtime ownership after merge step.
2. AI behavior check -> Verify: BosWar target lock, teammate communication, and faction hostility still operate.
3. Spawn check -> Verify: BosWar current preset behavior remains unchanged unless new preset is selected.
4. UX/QoL check -> Verify: each imported interaction feature is toggleable and reversible via MCM.
5. Regression check -> Verify: no edits under `Road to Vostok/` and no unintended script takeovers.

## Notes and Insights
- The ImmersiveXP feature set is valuable, but architecturally it is a "full-overhaul" mod, while BosWar is currently "targeted enemy AI + systems".
- The safest path is logic transplantation, not file replacement.
- AI Reload/Suppression are already conceptually present in BosWar; most value is in parameter/model refinement rather than new subsystem creation.
- Auto-equip and immersive interaction are likely high-value, but they are in high-conflict UI/player seams and should be delayed until AI/spawn integration is stable.

## Potential Conflicts to Watch Closely in BosWar
- `BosWar/AI.gd`: preserving target hysteresis and teammate queue budget while importing new vision/hearing formulas.
- `BosWar/AISpawner.gd`: preserving preset ratio/caps and initial population counting when introducing any ImmersiveXP-style count randomness.
- `BosWar/Loader.gd`: potential overlap with auto-draw/auto-equip expectations from ImmersiveXP `Interface.gd`.
- `BosWar/Config.gd`: avoid duplicate/conflicting settings labels and defaults when exposing new toggles.

## Decision Request for Next Step
For implementation, choose one low-risk starting slice:
- Option A: AI hearing + vision model port only.
- Option B: AI reload/suppression behavior parity tuning only.
- Option C: interaction/auto-equip prototype only.