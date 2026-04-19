# Initial Spawn Random Pistol Fallback (2026-04-18)

## Scope
- Ensure the player receives a random pistol loadout only on initial spawn when both gun slots are empty and the inventory is empty.
- Keep changes surgical and isolated to loader/bootstrap override logic.

## Assumptions
- "Only when the gun slots and inventory is empty" means:
  - `Primary` and `Secondary` equipment slots both have no item.
  - Inventory grid has no items.
- Initial-spawn-only is gated by `CharacterSave.initialSpawn == true`.
- A "full mag" means `weapon_slot_data.amount = magazine.maxAmount` and one extra magazine in inventory with `amount = magazine.maxAmount`.

## Implementation
- Added `BosWar/Loader.gd` overriding `LoadCharacter()`:
  - Calls `super.LoadCharacter()`.
  - Applies fallback loadout only if initial spawn and empty-state checks pass.
  - Picks random pistol from:
    - `Makarov`
    - `Colt_1911`
    - `Glock_17`
    - `P320`
  - Equips pistol in `Secondary` slot with full magazine ammo.
  - Adds one extra full magazine to inventory.
  - Forces weapon state to secondary loaded (`gameData.secondary = true`, `gameData.weaponPosition = 2`, `rig_manager.LoadSecondary()`).
- Updated `BosWar/Main.gd` to take over `res://BosWar/Loader.gd`.

## Tradeoffs
- Chose `Secondary` slot for deterministic behavior and to avoid conflicting with any future primary-slot spawn logic.
- Used strict inventory-empty check (not only "no guns in inventory") to match the explicit user wording.

## Verification Plan
1. Script takeover wired in bootstrap.
   - Verify: `BosWar/Main.gd` includes `_override_script("res://BosWar/Loader.gd")`.
2. Fallback runs only on initial spawn + empty state.
   - Verify: `character.initialSpawn` + empty slot/inventory checks gate execution.
3. Loadout correctness.
   - Verify: one random pistol equipped with full ammo, one extra full magazine created in inventory.

## Outcome
- Implemented as specified with no edits to base-game files under `Road to Vostok/`.
