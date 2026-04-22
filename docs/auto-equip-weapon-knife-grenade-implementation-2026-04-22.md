# BosWar Auto-Equip Implementation (Weapon/Knife/Grenade)

Date: 2026-04-22
Scope owner: BosWar-side only

## Goal
- Implement BosWar auto-equip when picking up `Weapon`, `Knife`, or `Grenade`.
- Equip into the first valid empty equipment slot.
- If hands are empty, auto-draw the newly equipped item.

## Assumptions
- BosWar code has priority over reference mods.
- `Interface.AutoStack(slotData, inventoryGrid)` is the lowest-blast-radius seam for pickup ingestion.
- Empty hands is represented by all draw flags being false:
  - `gameData.primary`
  - `gameData.secondary`
  - `gameData.knife`
  - `gameData.grenade1`
  - `gameData.grenade2`

## Implementation Notes
- Added `BosWar/Interface.gd` as a narrow override of `Scripts/Interface.gd`.
- Overrode only `AutoStack`.
- Added an early auto-equip branch for pickup-eligible item types and fallback to `super` for all other flows.
- Auto-draw calls the existing `rigManager.Draw*` methods only when hands are empty.
- Registered the override from `BosWar/Main.gd`.

## Tradeoffs
- This seam may also auto-equip in some inventory-to-inventory flows that pass through `AutoStack` with `inventoryGrid`.
- This was accepted to keep the change minimal and avoid broader pickup-system overrides.
- If stricter "world pickup only" behavior is required, that needs a dedicated source-aware seam (likely Pickup-side signal/context).

## Files Changed
- `BosWar/Interface.gd`
- `BosWar/Main.gd`
