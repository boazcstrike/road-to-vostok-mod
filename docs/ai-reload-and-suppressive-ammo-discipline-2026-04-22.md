# AI Reload + Suppressive Fire Ammo Discipline (2026-04-22)

## Task Scope
- Enforce AI weapon magazine capacity during firing.
- Add AI reload flow so firing pauses while reloading.
- Ensure spray-and-pray behavior respects ammo capacity and reload state.
- Make suppressive spray fire at last known target location (not live hidden tracking through walls).

## Assumptions
- Requested "gun capacity" means per-magazine shot limit derived from weapon data.
- Reserve ammo stays effectively unlimited for now; behavioral goal is mandatory reload cadence, not total ammo depletion.
- Changes stay in `BosWar/AI.gd` plus this task context file only.
- `Road to Vostok/` remains read-only reference.

## Verification Plan
1. Add magazine + reload runtime state and initialize it safely.
   Verify: AI starts with valid mag capacity/current rounds and can enter reload state.
2. Wire firing path to consume rounds and block shots when empty.
   Verify: every shot decrements ammo; no shot occurs at 0 rounds.
3. Wire reload completion to refill magazine.
   Verify: after reload timer elapses, rounds reset to magazine capacity and firing resumes.
4. Tighten suppressive fire targeting to last known position.
   Verify: when target is not visible, suppressive spray aims at cached last known location, not moving hidden target position.

## Progress Log
- Started task scoping and memory/context scan for existing suppressive-fire behavior in `BosWar/AI.gd`.
- Spawned parallel sub-agents for seam analysis:
  - Agent A: ammo/reload integration seam.
  - Agent B: last-known-position suppressive targeting seam.
- Completed local patch integration in `BosWar/AI.gd` with ammo/reload gating and hidden-target last-known suppressive aiming updates.

## Implemented Changes
- `BosWar/AI.gd`
  - Added ammo/reload runtime state:
    - `AI_RELOAD_SECONDS = 2.2`
    - `_magazine_capacity`, `_magazine_rounds`, `_is_reloading`, `_reload_end_time_seconds`
  - Initialized ammo state in `Activate()` via `_initialize_ammo_state()` from current weapon magazine size (`weaponData.magazineSize`) and slot amount when available.
  - Updated `Fire(delta)` so shots now:
    - require ammo availability (`_can_fire_with_ammo`)
    - consume one round per emitted shot (`_consume_round`)
    - trigger reload pause when magazine reaches zero (`_start_reload`)
    - resume firing only after reload timer completion (`_update_reload_state`)
  - Added hidden-target suppressive spray gating:
    - `_can_hidden_ai_suppressive_fire()` allows non-visible hostile AI suppressive firing only when last-known target info is valid.
    - `_can_fire_engagement()` now includes hidden suppressive eligibility.
    - Hidden suppressive shots are chance-gated (`AI_HIDDEN_SUPPRESSIVE_SPRAY_CHANCE = 0.35`) and forced full-auto when active.
  - Stopped live hidden target tracking for aiming:
    - `_get_engagement_position()` now uses `_last_known_location_data.position` for non-visible AI targets when valid.
    - `_get_fire_target_position()` and `_get_spine_target_position()` only use live AI body positions when `currentAITargetVisible` is true.
    - `_get_preferred_hit_targets()` only adds live AI torso/head/eyes samples when `currentAITargetVisible` is true.

## Verification Results
- Static verification completed by code-path inspection:
  - Shot emission path is now blocked while reloading and when rounds are zero.
  - Every emitted shot decrements `_magazine_rounds` once before damage/audio/VFX execution.
  - Reload completion refills rounds to magazine capacity before firing can continue.
  - Hidden hostile AI engagement now aims via last-known position instead of live target torso/head data.
  - Teammate-player suppressive mode remains intact and now also respects ammo/reload gating through shared `Fire(delta)` path.
- Runtime in-engine combat validation is still required to tune feel values (`AI_RELOAD_SECONDS`, hidden spray chance) and confirm pacing under live encounters.
