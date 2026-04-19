extends Node

var configSettings = preload("res://BetterEnemyLoot/BetterEnemyLootSettings.tres")
var McmHelpers = load("res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres")

const FILE_PATH = "user://MCM/BetterEnemyLoot"
const MOD_ID = "BetterEnemyLoot"

func _ready():
    var _config = ConfigFile.new()
    
    _config.set_value("Dropdown", "loot_amount", {
        "name" = "Loot Amount",
        "tooltip" = "Controls how well stocked enemies are",
        "default" = 2, # 0-indexed
        "value" = 2, 
        "options" = [
            "Most    (1 roll)",
            "More    (minimum of 2 rolls)",
            "Default (minimum of 3 rolls)",
            "Less    (minimum of 4 rolls)",
            "Least   (Minimum of 5 rolls)"
        ],
        "category" = "Loot Amount"
    })

    _config.set_value("Int", "max_consumables", {
        "name" = "Max Consumable Items",
        "tooltip" = "Maximum food/drink items an AI can carry (0-5)",
        "default" = 2,
        "value" = 2,
        "minRange" = 0,
        "maxRange" = 5,
        "category" = "Loot Amount"
    })

    _config.set_value("Int", "max_medical", {
        "name" = "Max Medical Items",
        "tooltip" = "Maximum medical items an AI can carry (0-5)",
        "default" = 1,
        "value" = 1,
        "minRange" = 0,
        "maxRange" = 5,
        "category" = "Loot Amount"
    })

    _config.set_value("Int", "max_magazines", {
        "name" = "Max Magazines",
        "tooltip" = "Maximum matching magazines an AI can carry (0-3)",
        "default" = 1,
        "value" = 1,
        "minRange" = 0,
        "maxRange" = 3,
        "category" = "Loot Amount"
    })
    
    _config.set_value("Int", "max_ammo", {
        "name" = "Max Ammo",
        "tooltip" = "Maximum matching ammo an AI can carry (0-50)",
        "default" = 10,
        "value" = 10,
        "minRange" = 0,
        "maxRange" = 50,
        "category" = "Loot Amount"
    })
    
    _config.set_value("Float", "rare_chance", {
        "name" = "Rare Chance",
        "tooltip" = "Chance a loot item will be rare instead of common",
        "default" = 0.25,
        "value" = 0.25,
        "minRange" = 0,
        "maxRange" = 1,
        "category" = "Loot Rarity"
    })
    
    _config.set_value("Bool", "debug", {
        "name" = "Debug Logging",
        "tooltip" = "Add verbose debug logging to game log",
        "default" = false,
        "value" = false
    })

    if McmHelpers:
        if !FileAccess.file_exists(FILE_PATH + "/config.ini"):
            DirAccess.open("user://").make_dir(FILE_PATH)
            _config.save(FILE_PATH + "/config.ini")
        else:
            McmHelpers.CheckConfigurationHasUpdated(MOD_ID, _config, FILE_PATH + "/config.ini")
            _config.load(FILE_PATH + "/config.ini")

        McmHelpers.RegisterConfiguration(
            MOD_ID,
            "Better Enemy Loot",
            FILE_PATH,
            "Configures bonus loot dropped by AI enemies",
            UpdateConfigProperties,
            self
        )

        UpdateConfigProperties(_config)

func UpdateConfigProperties(config: ConfigFile):
    configSettings.max_consumables  = config.get_value("Int", "max_consumables")["value"]
    configSettings.max_medical      = config.get_value("Int", "max_medical")["value"]
    configSettings.max_magazines    = config.get_value("Int", "max_magazines")["value"]
    configSettings.max_ammo         = config.get_value("Int", "max_ammo")["value"]
    configSettings.debug            = config.get_value("Bool", "debug")["value"]
    configSettings.loot_rolls       = config.get_value("Dropdown", "loot_amount")["value"] + 1 # 0-indexed but want minimum of 1 roll
    configSettings.rare_chance      = config.get_value("Float", "rare_chance")["value"]