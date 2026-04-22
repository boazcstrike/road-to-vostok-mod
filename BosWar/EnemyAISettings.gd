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

@export var warfare_enabled = true
@export var player_faction_alignment = 0
@export var corpse_cleanup_limit = 20
@export var player_invulnerable = false
@export var show_debug_overlay = false
@export var show_debug_logs = false
@export var teammate_message_duplicate_ttl_seconds = 0.1
@export var teammate_decision_debounce_seconds = 0.05
@export var enable_threaded_scoring_shadow_mode = false
@export var threaded_scoring_min_candidates_for_thread = 8
@export var threaded_scoring_max_global_jobs = 2
@export var threaded_scoring_candidate_cap = 32
# Evaluates shadow scoring for agents where (instance_id % modulo == frame % modulo).
@export var threaded_scoring_cohort_modulo = 4
@export var threaded_scoring_top_k = 3
@export var show_threaded_scoring_stats = false
@export var replenish_spawn_pool = true
@export var loot_enabled = true
@export var max_medical = 1
@export var max_consumables = 2
@export var max_magazines = 1
@export var max_ammo = 10
@export var loot_rolls = 3
@export var rare_chance = 0.25
@export var loot_debug = false

@export var ai_health_multiplier = 1.0
@export var boss_health_multiplier = 1.0
@export var ai_sight_multiplier = 1.0
@export var ai_hearing_multiplier = 1.0
@export var ai_accuracy_multiplier = 1.0
@export var ai_fire_rate_multiplier = 1.0
@export var ai_gunshot_alert_duration = 5.0
@export var ai_tactical_reload_enabled = true
@export var ai_tactical_reload_chance = 0.35
@export var ai_tactical_reload_min_ratio = 0.45
@export var ai_tactical_reload_safe_distance = 22.0

# 0=Passive, 1=Default, 2=Aggressive, 3=Relentless
@export var ai_tactics_preset = 1

# Team spawning settings
# When enabled, enemies spawn in coordinated teams rather than individually
@export var enable_team_spawning = true

# Bandit teams: 3-5 units (larger groups for bandit ambushes)
@export_range(3, 5, 1) var bandit_team_size_min = 3
@export_range(3, 5, 1) var bandit_team_size_max = 5

# Guard teams: 2-4 units (smaller, disciplined formations)
@export_range(2, 4, 1) var guard_team_size_min = 2
@export_range(2, 4, 1) var guard_team_size_max = 4

# Military teams: 2-3 units (tactical fireteams)
@export_range(2, 3, 1) var military_team_size_min = 2
@export_range(2, 3, 1) var military_team_size_max = 3

var mcm_enabled = false
