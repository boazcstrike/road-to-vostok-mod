extends "res://Scripts/Loader.gd"

const STARTER_PISTOLS = [
    "Makarov",
    "Colt_1911",
    "Glock_17",
    "P320"
]

func LoadCharacter():
    await super.LoadCharacter()
    _ensure_initial_spawn_pistol_loadout()

func _ensure_initial_spawn_pistol_loadout():
    if !FileAccess.file_exists("user://Character.tres"):
        return

    var character: CharacterSave = load("user://Character.tres") as CharacterSave
    if character == null or !character.initialSpawn:
        return

    var interface = get_tree().current_scene.get_node_or_null("/root/Map/Core/UI/Interface")
    var rig_manager = get_tree().current_scene.get_node_or_null("/root/Map/Core/Camera/Manager")
    if !is_instance_valid(interface) or !is_instance_valid(rig_manager):
        return

    if !_are_gun_slots_empty(interface):
        return
    if !_is_inventory_empty(interface):
        return

    var selected_pistol_file = STARTER_PISTOLS.pick_random()
    var pistol_item_data = Database.get(selected_pistol_file)
    var pistol_magazine_data = Database.get(selected_pistol_file + "_Magazine")
    if pistol_item_data == null or pistol_magazine_data == null:
        return

    var weapon_slot_data = SlotData.new()
    weapon_slot_data.itemData = pistol_item_data
    weapon_slot_data.condition = 100
    weapon_slot_data.amount = int(pistol_magazine_data.maxAmount)
    weapon_slot_data.chamber = false
    weapon_slot_data.casing = false
    weapon_slot_data.nested = [pistol_magazine_data]

    interface.LoadSlotItem(weapon_slot_data, "Secondary")

    var spare_magazine_slot_data = SlotData.new()
    spare_magazine_slot_data.itemData = pistol_magazine_data
    spare_magazine_slot_data.amount = int(pistol_magazine_data.maxAmount)
    interface.Create(spare_magazine_slot_data, interface.inventoryGrid, false)

    rig_manager.ClearRig()
    gameData.primary = false
    gameData.secondary = true
    gameData.knife = false
    gameData.grenade1 = false
    gameData.grenade2 = false
    gameData.weaponPosition = 2
    rig_manager.LoadSecondary()

func _are_gun_slots_empty(interface) -> bool:
    if !is_instance_valid(interface.equipmentGrid):
        return false
    if interface.equipmentGrid.get_child_count() < 2:
        return false

    var primary_slot = interface.equipmentGrid.get_child(0)
    var secondary_slot = interface.equipmentGrid.get_child(1)
    return primary_slot.get_child_count() == 0 and secondary_slot.get_child_count() == 0

func _is_inventory_empty(interface) -> bool:
    if !is_instance_valid(interface.inventoryGrid):
        return false
    return interface.inventoryGrid.get_child_count() == 0
