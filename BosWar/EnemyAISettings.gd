extends Resource
class_name EnemyAISettings

# Intensity preset controls enemy AI population density and spawn frequency
# 0 = Default (low intensity), 1 = Medium, 2 = Medium High, 3 = High, 4 = Very High, 5 = Insane
@export var intensity_preset = 0

# Global multiplier for spawn intervals (higher = slower spawning)
@export var spawn_rate_adjustment = 1

# Bonus values added to preset base values for fine-tuning difficulty
@export var spawn_limit_bonus = 0        # Added to max active enemies
@export var spawn_pool_bonus = 0         # Added to total enemy pool
@export var initial_population_bonus = 0 # Added to starting enemy count
@export var spawn_distance = 100
@export var initial_guard = false
@export var initial_hider = false
@export var initial_hider_chance = 25
@export var disable_hiding = false

@export var enemy_type_override_enabled = false
@export var bandit_spawn_mode = 0
@export var guard_spawn_mode = 0
@export var military_spawn_mode = 0

@export var bandit_infighting_enabled = false
@export var guard_infighting_enabled = false
@export var military_infighting_enabled = false
@export var warfare_enabled = false
@export var player_faction_alignment = 0
@export var corpse_cleanup_limit = 20
@export var player_invulnerable = false
@export var show_debug_overlay = true
@export var replenish_spawn_pool = true

@export var ai_health_multiplier = 1.0
@export var boss_health_multiplier = 1.0
@export var ai_sight_multiplier = 1.0
@export var ai_hearing_multiplier = 1.0
@export var ai_accuracy_multiplier = 1.0
@export var ai_fire_rate_multiplier = 1.0
@export var ai_gunshot_alert_duration = 5.0

# 0=Passive, 1=Default, 2=Aggressive, 3=Relentless
@export var ai_tactics_preset = 1

# Team spawning settings
# When enabled, enemies spawn in coordinated teams rather than individually
@export var enable_team_spawning = true

# Bandit teams: 3-8 units (larger groups for bandit ambushes)
@export_range(3, 8, 1) var bandit_team_size_min = 3
@export_range(3, 8, 1) var bandit_team_size_max = 8

# Guard teams: 2-4 units (smaller, disciplined formations)
@export_range(2, 4, 1) var guard_team_size_min = 2
@export_range(2, 4, 1) var guard_team_size_max = 4

# Military teams: 2-4 units (tactical fireteams)
@export_range(2, 4, 1) var military_team_size_min = 2
@export_range(2, 4, 1) var military_team_size_max = 4

var mcm_enabled = false
