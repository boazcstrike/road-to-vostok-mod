extends "res://Scripts/Interface.gd"

const _BOSWAR_AUTO_EQUIP_TYPES = ["Weapon", "Knife", "Grenade"]

func AutoStack(slotData, targetGrid):
    if _boswar_auto_equip_pickup(slotData, targetGrid):
        return true
    return super(slotData, targetGrid)

func _boswar_auto_equip_pickup(slotData, targetGrid):
    if targetGrid != inventoryGrid:
        return false
    if slotData == null || slotData.itemData == null:
        return false
    if slotData.itemData.type not in _BOSWAR_AUTO_EQUIP_TYPES:
        return false

    var target_slot = null
    var target_index = -1
    for index in range(equipment.get_child_count()):
        var slot = equipment.get_child(index)
        if slotData.itemData.slots.has(slot.name) && slot.get_child_count() == 0:
            target_slot = slot
            target_index = index
            break

    if target_slot == null:
        return false

    var new_item = item.instantiate()
    new_item.slotData.Update(slotData)
    add_child(new_item)
    new_item.Initialize(self, slotData)

    Equip(new_item, target_slot)
    Reset()
    PlayEquip()

    if _boswar_hands_empty():
        _boswar_draw_equipped_slot(target_index, slotData)

    return true

func _boswar_hands_empty():
    return !gameData.primary && !gameData.secondary && !gameData.knife && !gameData.grenade1 && !gameData.grenade2

func _boswar_draw_equipped_slot(target_index: int, slotData):
    match target_index:
        1:
            rigManager.DrawPrimary(slotData)
        2:
            rigManager.DrawSecondary(slotData)
        3:
            rigManager.DrawKnife(slotData)
        4:
            rigManager.DrawGrenade1(slotData)
        5:
            rigManager.DrawGrenade2(slotData)
