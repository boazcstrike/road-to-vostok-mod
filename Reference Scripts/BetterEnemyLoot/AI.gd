extends "res://Scripts/AI.gd"

var cfg = preload("res://BetterEnemyLoot/BetterEnemyLootSettings.tres")

func _ready():
    super()
    _logBEL(["AI ready"])

func ActivateContainer():
    super()
    _logBEL(["ActivateContainer called"])
    
    var created_food = 0
    var created_meds = 0
    var created_mag = 0
    var created_ammo = 0
        
    _logBEL(["max_consumables: ", cfg.max_consumables])
    _logBEL(["max_medical: ", cfg.max_medical])
    _logBEL(["max_magazines: ", cfg.max_magazines])
    _logBEL(["max_ammo: ", cfg.max_ammo])
    
    var all_items = container.LT_Master.items

    var valid_items: Array
    if container.military:
        valid_items = all_items
    elif container.industrial:
        valid_items = all_items.filter(func(i): return i.civilian or i.industrial)
    else:
        valid_items = all_items.filter(func(i): return i.civilian)

    var consumable_common    = valid_items.filter(func(i): return i.type == "Consumables" and i.rarity == i.Rarity.Common)
    var consumable_rare      = valid_items.filter(func(i): return i.type == "Consumables" and i.rarity == i.Rarity.Rare)

    var medical_common    = valid_items.filter(func(i): return i.type == "Medical" and i.rarity == i.Rarity.Common)
    var medical_rare      = valid_items.filter(func(i): return i.type == "Medical" and i.rarity == i.Rarity.Rare)

    for _pick in _weighted_count_BEL(cfg.max_consumables):
        created_food += 1
        container.CreateLoot(_pick_item_BEL(consumable_common, consumable_rare))

    for _pick in _weighted_count_BEL(cfg.max_medical):
        created_meds += 1
        container.CreateLoot(_pick_item_BEL(medical_common, medical_rare))

    if weaponData && weaponData.compatible.size() > 0:
        var mag = weaponData.compatible[0]
        if mag.subtype == "Magazine":
            _logBEL(["magazine: ", mag.name])
            for _pick in _weighted_count_BEL(cfg.max_magazines):
                created_mag += 1
                container.CreateLoot(mag)
    
    if weaponData:
        var ammo = weaponData.ammo
        if ammo:
            _logBEL(["ammo: ", ammo.name])
            created_ammo = _weighted_count_BEL(cfg.max_ammo)
            if created_ammo > 0:
                _add_ammo_BEL(container, ammo, created_ammo)
    
    container.SpawnItems()
    _logBEL(["container loot amount: ", container.loot.size()])
    _logBEL(["created food: ", created_food])
    _logBEL(["created meds: ", created_meds])
    _logBEL(["created mag: ", created_mag])
    _logBEL(["created ammo: ", created_ammo])


func _weighted_count_BEL(max: int) -> int:
    var result = randi_range(0, max)
    for i in cfg.loot_rolls - 1:
        result = min(result, randi_range(0, max))
    return result
    
func _logBEL(parts: Array) -> void:
    if cfg.debug:
        print("[BetterEnemyLoot] ", " ".join(parts.map(func(p): return str(p))))

func _add_ammo_BEL(container: LootContainer, ammo: ItemData, amount: int):
    var newSlotData = SlotData.new()
    newSlotData.itemData = ammo
    newSlotData.amount = max(1, amount)
    container.loot.append(newSlotData)

func _pick_item_BEL(common: Array, rare: Array) -> ItemData:
    _logBEL(["_pick_item pool sizes — common:", common.size(), " | rare:", rare.size()])
    var roll = randf()
    _logBEL(["_pick_item roll:", roll, " | rare chance:", cfg.rare_chance])
    if roll < cfg.rare_chance and rare.size() > 0:
        var item = rare.pick_random()
        _logBEL(["_pick_item: rare ->", item.name])
        return item
    var item = common.pick_random()
    _logBEL(["_pick_item: common ->", item.name])
    return item