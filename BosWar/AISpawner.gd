extends "res://Scripts/AISpawner.gd"


var EnemyAISettings = preload("res://BosWar/EnemyAISettings.tres")
const DebugUtils = preload("res://BosWar/DebugUtils.gd")
var spawnedThisMap = 0
var currentFactionName = "N/A"
var factionPool: Array = []
# Tracks spawn points that are currently occupied by active teams
# Prevents different teams from spawning at the same location
var occupied_spawn_points: Array = []


# Initial rush mode variables for burst spawning
var initial_rush_mode: bool
var initial_burst_duration: float
var initial_burst_limit: int
var game_start_time: float


const SPAWN_AUDIT_RAY_ABOVE = 3.0
const SPAWN_AUDIT_RAY_BELOW = 20.0
const SPAWN_AUDIT_BELOW_FLOOR_THRESHOLD = 2.5
const SPAWN_AUDIT_ABOVE_FLOOR_THRESHOLD = 6.0


func _ready():
    GetPoints()
    HidePoints()

    active = true
    spawnDistance = EnemyAISettings.spawn_distance
    spawnLimit = _get_spawn_limit()
    spawnPool = _get_spawn_pool()
    initialGuard = EnemyAISettings.initial_guard
    initialHider = EnemyAISettings.initial_hider
    noHiding = EnemyAISettings.disable_hiding
    initial_rush_mode = true  # Start in rush mode for fast initial population
    initial_burst_duration = 5.0 * 60.0  # 5 minutes of initial burst
    initial_burst_limit = spawnLimit * 2  # Allow up to 2x spawn limit during burst
    game_start_time = Time.get_ticks_msec() / 1000.0  # Track when game started

    DebugUtils._debug_log("Spawner ready on scene '%s' with zone '%s'" % [get_tree().current_scene.name, _zone_name()])
    DebugUtils._debug_log("Points: spawns=%d, waypoints=%d, patrols=%d, covers=%d, hides=%d" % [spawns.size(), waypoints.size(), patrols.size(), covers.size(), hides.size()])
    _debug_begin_map("Spawner initialized")

    if !active:
        DebugUtils._debug_log("Spawner inactive")
        return

    agent = _select_agent_scene()
    factionPool = _build_faction_pool()
    currentFactionName = _describe_faction_pool()
    DebugUtils._debug_log("Selected faction pool for zone '%s': %s" % [_zone_name(), currentFactionName])

    CreatePools()
    _spawn_initial_population(_get_initial_population())

    if initialGuard:
        spawn_guard()

    if initialHider:
        if randi_range(0, 100) < EnemyAISettings.initial_hider_chance:
            spawn_hider()
        else:
            DebugUtils._debug_log("Initial hider roll failed")

func _physics_process(delta):
    if !active:
        return

    spawnTime -= delta

    if spawnTime <= 0:
        # Check current time and determine effective spawn limit
        var current_time = Time.get_ticks_msec() / 1000.0
        var time_since_start = current_time - game_start_time
        var in_initial_burst = time_since_start < initial_burst_duration
        var effective_limit = initial_burst_limit if in_initial_burst else spawnLimit

        if activeAgents < effective_limit:
            var limit_type = "burst" if in_initial_burst else "normal"
            DebugUtils._debug_log("Spawn attempt: active=%d %s_limit=%d pool_remaining=%d" % [activeAgents, limit_type, effective_limit, APool.get_child_count()])
            SpawnWanderer()

            # Check if we've reached the spawn limit and switch to regular intervals
            if activeAgents >= spawnLimit and initial_rush_mode:
                initial_rush_mode = false
                DebugUtils._debug_log("Switched from initial rush mode to regular spawn intervals")
        else:
            var limit_type = "burst" if in_initial_burst else "normal"
            DebugUtils._debug_log("Spawn skipped because active AI reached %s limit (%d/%d)" % [limit_type, activeAgents, effective_limit])
            _debug_push_status("Active limit reached")

        # Set next spawn timer based on current mode
        var interval_profile
        if initial_rush_mode:
            # Initial rush: 3-5 second intervals
            interval_profile = {"min": 3.0, "max": 5.0}
        else:
            # Regular intervals from preset
            interval_profile = _get_spawn_interval_profile()

        spawnTime = randf_range(interval_profile["min"], interval_profile["max"])
        var mode_name = "rush" if initial_rush_mode else "regular"
        DebugUtils._debug_log("Next spawn timer set to %.2fs (%s mode)" % [spawnTime, mode_name])
        _debug_push_status("Spawn timer reset")

## Returns spawning configuration parameters based on the current intensity preset
## The intensity preset controls enemy AI population density and spawn frequency
## Returns a dictionary with the following keys:
##   - spawn_limit: Maximum number of active AI agents allowed simultaneously
##   - spawn_pool: Total pool of AI agents available for spawning throughout the session
##   - initial_population: Number of AI agents spawned when the system initializes
##   - spawn_min: Minimum time interval (seconds) between individual spawns
##   - spawn_max: Maximum time interval (seconds) between individual spawns
func _get_preset_profile() -> Dictionary:
    match EnemyAISettings.intensity_preset:
        1:  # Medium intensity - balanced challenge
            return {
                "spawn_limit": 8,        # Max 8 active enemies at once
                "spawn_pool": 24,        # Total of 24 enemies available to spawn
                "initial_population": 2, # Start with 2 enemies
                "spawn_min": 5.0,        # Spawn intervals: 5-28 seconds
                "spawn_max": 28.0
            }
        2:  # Medium High intensity - increased pressure
            return {
                "spawn_limit": 12,       # Max 12 active enemies at once
                "spawn_pool": 36,        # Total of 36 enemies available to spawn
                "initial_population": 4, # Start with 4 enemies
                "spawn_min": 4.0,        # Spawn intervals: 4-20 seconds
                "spawn_max": 20.0
            }
        3:  # High intensity - challenging gameplay
            return {
                "spawn_limit": 16,       # Max 16 active enemies at once
                "spawn_pool": 48,        # Total of 48 enemies available to spawn
                "initial_population": 5, # Start with 5 enemies
                "spawn_min": 3.0,        # Spawn intervals: 3-16 seconds
                "spawn_max": 16.0
            }
        4:  # Very High intensity - intense combat
            return {
                "spawn_limit": 32,       # Max 32 active enemies at once
                "spawn_pool": 96,        # Total of 96 enemies available to spawn
                "initial_population": 10, # Start with 10 enemies
                "spawn_min": 1.5,        # Spawn intervals: 1.5-8 seconds
                "spawn_max": 8.0
            }
        5:  # Insane intensity - maximum difficulty
            return {
                "spawn_limit": 52,       # Max 52 active enemies at once
                "spawn_pool": 156,       # Total of 156 enemies available to spawn
                "initial_population": 16, # Start with 16 enemies
                "spawn_min": 0.9,        # Spawn intervals: 0.9-4.5 seconds
                "spawn_max": 4.5
            }
        _:  # Default/Low intensity - minimal threat
            return {
                "spawn_limit": 16,        # Max 3 active enemies at once
                "spawn_pool": 32,        # Total of 10 enemies available to spawn
                "initial_population": 8, # Start with no enemies
                "spawn_min": 10.0,        # Spawn intervals: 10-45 seconds
                "spawn_max": 45.0
            }

func _get_rate_scale() -> float:
    match EnemyAISettings.spawn_rate_adjustment:
        0:
            return 1.25
        2:
            return 0.75
        _:
            return 1.0

## Returns the maximum number of active AI agents allowed simultaneously
## Combines the preset base value with any configured bonus
func _get_spawn_limit() -> int:
    var profile = _get_preset_profile()
    return max(1, profile["spawn_limit"] + EnemyAISettings.spawn_limit_bonus)

## Returns the total pool of AI agents available for spawning throughout the session
## Combines the preset base value with any configured bonus
func _get_spawn_pool() -> int:
    var profile = _get_preset_profile()
    return max(1, profile["spawn_pool"] + EnemyAISettings.spawn_pool_bonus)

## Returns the number of AI agents to spawn when the system initializes
## For initial burst, start with the spawn limit to quickly populate
func _get_initial_population() -> int:
    var profile = _get_preset_profile()
    var base_initial = profile["initial_population"] + EnemyAISettings.initial_population_bonus
    # Start with spawn limit for faster initial population during burst phase
    return max(0, max(base_initial, spawnLimit))

## Returns the spawn interval range (min/max seconds between spawns)
## Applies performance scaling and ensures minimum viable intervals
func _get_spawn_interval_profile() -> Dictionary:
    var profile = _get_preset_profile()
    var rate_scale = _get_rate_scale()
    return {
        "min": max(0.5, profile["spawn_min"] * rate_scale),
        "max": max(1.0, profile["spawn_max"] * rate_scale)
    }

func _select_agent_scene():
    return _get_default_agent_scene()

func _get_default_agent_scene():
    if zone == Zone.Area05:
        return bandit
    elif zone == Zone.BorderZone:
        return guard
    elif zone == Zone.Vostok:
        return military

    return bandit

func _build_faction_pool() -> Array:
    var pool: Array = []

    # Check if any faction has forced mode (1) or excluded mode (2)
    var has_custom_modes = EnemyAISettings.bandit_spawn_mode != 0 || EnemyAISettings.guard_spawn_mode != 0 || EnemyAISettings.military_spawn_mode != 0

    if has_custom_modes:
        # Use the original mode-based logic for custom configurations
        var default_scene = _get_default_agent_scene()
        _append_faction_by_mode(pool, default_scene, bandit, EnemyAISettings.bandit_spawn_mode)
        _append_faction_by_mode(pool, default_scene, guard, EnemyAISettings.guard_spawn_mode)
        _append_faction_by_mode(pool, default_scene, military, EnemyAISettings.military_spawn_mode)
    else:
        # Use 10:2:1 ratio (bandit:guard:military) for default behavior
        # Add bandits (10 parts)
        for i in range(10):
            pool.append(bandit)
        # Add guards (2 parts)
        for i in range(2):
            pool.append(guard)
        # Add military (1 part)
        pool.append(military)

    return _dedupe_faction_pool(pool)

func _has_forced_faction_modes() -> bool:
    return EnemyAISettings.bandit_spawn_mode != 0 || EnemyAISettings.guard_spawn_mode != 0 || EnemyAISettings.military_spawn_mode != 0

func _append_faction_by_mode(pool: Array, default_scene, scene_resource, mode_value: int):
    var mode = int(mode_value)

    if mode == 2:
        return

    if mode == 1:
        pool.append(scene_resource)
        return

    if scene_resource == default_scene:
        pool.append(scene_resource)

func _dedupe_faction_pool(pool: Array) -> Array:
    var unique_pool: Array = []

    for scene_resource in pool:
        if !unique_pool.has(scene_resource):
            unique_pool.append(scene_resource)

    return unique_pool

func _describe_faction_pool() -> String:
    var names: Array[String] = []

    for scene_resource in factionPool:
        names.append(_packed_scene_name(scene_resource))

    if names.is_empty():
        return "None"

    return ", ".join(names)

## Creates the initial pools of AI agents for spawning
## Modified for team-based spawning: creates complete teams instead of individual agents
## Each team gets a unique ID and proper faction metadata
func CreatePools():
    APool.global_position = Vector3(0, 1000, 0)
    BPool.global_position = Vector3(0, 1000, 0)

    var available_factions = factionPool
    if available_factions.is_empty():
        DebugUtils._debug_log("AI Spawner: No regular factions enabled for this zone. Regular AI pool will stay empty.")
    else:
        var team_id = 0
        var remaining_pool = spawnPool

        # Create teams until we fill the spawn pool
        while remaining_pool > 0:
            var next_scene = available_factions.pick_random()
            var faction_name = _packed_scene_name(next_scene)
            var team_size = _get_team_size_for_faction(faction_name)

            # Ensure we don't exceed the remaining pool capacity
            team_size = min(team_size, remaining_pool)

            # Create all members of this team
            for i in team_size:
                var newAgent = next_scene.instantiate()
                APool.add_child(newAgent, true)

                newAgent.boss = false
                newAgent.AISpawner = self
                newAgent.set_meta("enemy_ai_faction", faction_name)
                # Team coordination metadata
                newAgent.set_meta("team_id", team_id)
                newAgent.set_meta("team_member_index", i)
                newAgent.global_position = APool.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
                newAgent.Pause()

            DebugUtils._debug_log("Created team %d with %d %s members" % [team_id, team_size, faction_name])
            team_id += 1
            remaining_pool -= team_size

    # Create boss pool (unchanged - bosses spawn individually)
    var newBoss = punisher.instantiate()
    BPool.add_child(newBoss, true)

    newBoss.boss = true
    newBoss.AISpawner = self
    newBoss.set_meta("enemy_ai_faction", "Punisher")
    newBoss.global_position = BPool.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
    newBoss.Pause()

    DebugUtils._debug_log("AI Spawner: Team-based pools created with factions: %s" % _describe_faction_pool())

func _spawn_initial_population(count: int):
    for _i in count:
        if activeAgents < spawnLimit:
            SpawnWanderer()

## Spawns a wandering enemy or team
## Uses team spawning if enabled, otherwise falls back to individual spawning
func SpawnWanderer():
    var before_active = activeAgents

    if EnemyAISettings.enable_team_spawning:
        _spawn_team_wanderer()  # Spawn entire team at once
    else:
        super()  # Use base class individual spawning

    _handle_spawn_result("Wanderer", before_active)

# Faction mapping for different spawn types
const SPAWN_FACTIONS = {
    "Guard": "Guard",
    "Hider": "Bandit",
    "Minion": "Bandit",
    "Boss": "Punisher"
}

# Helper function to handle common spawn logic
func _handle_spawn_with_faction(spawn_type: String, spawn_position = null) -> void:
    var before_count = agents.get_child_count()
    var before_active = activeAgents

    # Call appropriate spawn method based on type
    match spawn_type:
        "Wanderer":
            SpawnWanderer()
        "Guard":
            SpawnGuard()
        "Hider":
            SpawnHider()
        "Minion":
            if spawn_position != null:
                SpawnMinion(spawn_position)
        "Boss":
            if spawn_position != null:
                SpawnBoss(spawn_position)

    # Get the newly spawned agent (assuming it's added as the last child)
    var after_count = agents.get_child_count()
    var spawned_agent = agents.get_child(after_count - 1) if after_count > before_count else null

    # Set faction metadata if agent was spawned and doesn't already have it
    if spawned_agent and not spawned_agent.has_meta("enemy_ai_faction"):
        var faction = SPAWN_FACTIONS.get(spawn_type, "Bandit")  # Default to Bandit if not found
        spawned_agent.set_meta("enemy_ai_faction", faction)

    # Handle spawn result
    _handle_spawn_result(spawn_type, before_active)

func spawn_guard() -> void:
    _handle_spawn_with_faction("Guard")

func spawn_hider() -> void:
    _handle_spawn_with_faction("Hider")

func spawn_minion(spawn_position: Vector3) -> void:
    _handle_spawn_with_faction("Minion", spawn_position)

func spawn_boss(spawn_position: Vector3) -> void:
    _handle_spawn_with_faction("Boss", spawn_position)

## Handles the result of a spawn attempt and updates tracking/logging
## Differentiates between team spawning and individual agent spawning for proper logging
func _handle_spawn_result(spawn_type: String, before_active: int):
    var spawned_count = activeAgents - before_active
    if spawned_count > 0:
        spawnedThisMap += spawned_count

        if EnemyAISettings.enable_team_spawning and spawn_type == "Wanderer":
            # Team spawning: log team information and audit all members
            var last_spawned_agent = agents.get_child(agents.get_child_count() - 1)
            var spawned_faction = "Unknown"
            var team_id = -1
            if last_spawned_agent and last_spawned_agent.has_meta("enemy_ai_faction"):
                spawned_faction = str(last_spawned_agent.get_meta("enemy_ai_faction"))
                team_id = last_spawned_agent.get_meta("team_id") if last_spawned_agent.has_meta("team_id") else -1

            DebugUtils._debug_log("Team spawned successfully: %d %s members (team %d). spawned_this_map=%d active=%d" % [spawned_count, spawned_faction, team_id, spawnedThisMap, activeAgents])
            _debug_record_spawn("Team spawned (%d %s)" % [spawned_count, spawned_faction], spawn_type, spawned_faction)

            # Perform spawn validation checks and print unit info for all team members
            for i in range(agents.get_child_count() - spawned_count, agents.get_child_count()):
                var agent = agents.get_child(i)
                _debug_print_unit_info(agent, spawn_type)
                _audit_spawned_agent(agent, spawn_type, "spawn")
                _schedule_spawn_audit(agent, spawn_type)
        else:
            # Individual agent spawning (legacy behavior or non-wanderer spawns)
            var spawned_agent = agents.get_child(agents.get_child_count() - 1)
            var spawned_faction = "Unknown"
            if spawned_agent and spawned_agent.has_meta("enemy_ai_faction"):
                spawned_faction = str(spawned_agent.get_meta("enemy_ai_faction"))
            DebugUtils._debug_log("%s spawned successfully as %s. spawned_this_map=%d active=%d" % [spawn_type, spawned_faction, spawnedThisMap, activeAgents])
            _debug_record_spawn("%s spawned (%s)" % [spawn_type, spawned_faction], spawn_type, spawned_faction)
            _debug_print_unit_info(spawned_agent, spawn_type)
            _audit_spawned_agent(spawned_agent, spawn_type, "spawn")
            _schedule_spawn_audit(spawned_agent, spawn_type)
    else:
        DebugUtils._debug_log("%s spawn failed. active=%d pool_remaining=%d" % [spawn_type, activeAgents, APool.get_child_count()])
        _debug_push_status("%s spawn failed" % spawn_type)

## Replenishes the spawn pool when an agent dies
## Called automatically when agents are defeated to maintain population
## Also checks for defeated teams to release occupied spawn points
func replenish_regular_pool(faction_name: String):
    if !EnemyAISettings.replenish_spawn_pool:
        return

    var scene_resource = _scene_for_faction_name(faction_name)
    if scene_resource == null:
        DebugUtils._debug_log("Pool replenish skipped: no scene found for faction=%s" % faction_name)
        return

    var newAgent = scene_resource.instantiate()
    APool.add_child(newAgent, true)

    newAgent.boss = false
    newAgent.AISpawner = self
    newAgent.set_meta("enemy_ai_faction", faction_name)
    newAgent.global_position = APool.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
    newAgent.Pause()

    DebugUtils._debug_log("Pool replenished for faction=%s reserve=%d" % [faction_name, APool.get_child_count()])

    # Check if any teams are completely defeated and release their spawn points
    # This allows new teams to spawn at previously occupied locations
    _check_and_release_defeated_team_spawn_points()

func _scene_for_faction_name(faction_name: String):
    match faction_name:
        "Bandit":
            return bandit
        "Guard":
            return guard
        "Military":
            return military
        _:
            return null

func _debug_main():
    return get_node_or_null("/root/EnemyAIMain")

func _debug_begin_map(event_text: String):
    var debug_main = _debug_main()
    if debug_main:
        debug_main.begin_map(get_tree().current_scene.name, _zone_name(), {
            "spawn_limit": spawnLimit,
            "spawn_pool": spawnPool,
            "spawn_distance": spawnDistance,
            "preset_name": _preset_name(),
            "rate_name": _rate_name(),
            "current_faction": currentFactionName,
            "last_event": event_text
        })

func _debug_record_spawn(event_text: String, role_name: String, faction_name: String):
    var debug_main = _debug_main()
    if debug_main:
        debug_main.record_spawn(event_text, activeAgents, {
            "spawn_limit": spawnLimit,
            "spawn_pool": spawnPool,
            "spawn_distance": spawnDistance,
            "preset_name": _preset_name(),
            "rate_name": _rate_name(),
            "current_faction": currentFactionName,
            "spawn_faction": faction_name,
            "spawn_role": role_name
        })

func _debug_push_status(event_text: String):
    var debug_main = _debug_main()
    if debug_main:
        debug_main.update_status(activeAgents, {
            "spawn_limit": spawnLimit,
            "spawn_pool": spawnPool,
            "spawn_distance": spawnDistance,
            "preset_name": _preset_name(),
            "rate_name": _rate_name(),
            "current_faction": currentFactionName,
            "last_event": event_text
        })

## Prints comprehensive debug information about a spawned unit
## Includes all relevant metadata, position, and state information
func _debug_print_unit_info(agent, spawn_type: String):
    if !is_instance_valid(agent):
        DebugUtils._debug_log("UNIT INFO: Invalid agent instance")
        return

    var faction = agent.get_meta("enemy_ai_faction", "Unknown")
    var team_id = agent.get_meta("team_id", -1)
    var team_member_index = agent.get_meta("team_member_index", -1)
    var is_boss = agent.get("boss", false)
    var position = agent.global_position
    var health = agent.get("health", "N/A")
    var weapon_damage = agent.get("weapon_damage", "N/A")
    var current_state = agent.get("current_state", "N/A")
    var target = agent.get("current_target", "None")

    var info = "UNIT INFO [%s]: faction=%s, boss=%s, position=(%.2f,%.2f,%.2f), health=%s, weapon_damage=%s, state=%s, target=%s" % [
        spawn_type, faction, is_boss, position.x, position.y, position.z, health, weapon_damage, current_state, target
    ]

    if team_id >= 0:
        info += ", team_id=%d, team_member=%d" % [team_id, team_member_index]

    DebugUtils._debug_log(info)

func _schedule_spawn_audit(spawned_agent, spawn_type: String):
    await get_tree().create_timer(1.25, false).timeout
    _audit_spawned_agent(spawned_agent, spawn_type, "delayed")

func _audit_spawned_agent(spawned_agent, spawn_type: String, phase: String):
    if !is_instance_valid(spawned_agent):
        return

    var audit = _sample_floor_audit(spawned_agent)
    if !bool(audit.get("suspicious", false)):
        return

    var reason = str(audit.get("reason", "unknown"))
    var floor_y = float(audit.get("floor_y", spawned_agent.global_position.y))
    var delta_y = float(audit.get("delta_y", 0.0))
    var source_name = "Unknown"
    if spawned_agent.get("currentPoint") is Node3D:
        source_name = spawned_agent.currentPoint.name

    var event_text = "Suspicious %s spawn (%s): %s dy=%.2f floor=%.2f agent=%.2f point=%s" % [
        spawn_type,
        phase,
        reason,
        delta_y,
        floor_y,
        spawned_agent.global_position.y,
        source_name
    ]
    DebugUtils._debug_log(event_text)

    var debug_main = _debug_main()
    if debug_main:
        debug_main.record_suspicious_spawn(event_text, activeAgents, {
            "spawn_limit": spawnLimit,
            "spawn_pool": spawnPool,
            "spawn_distance": spawnDistance,
            "preset_name": _preset_name(),
            "rate_name": _rate_name(),
            "current_faction": currentFactionName,
            "last_event": event_text
        })

func _sample_floor_audit(spawned_agent) -> Dictionary:
    var origin = spawned_agent.global_position + Vector3(0, SPAWN_AUDIT_RAY_ABOVE, 0)
    var destination = spawned_agent.global_position + Vector3(0, -SPAWN_AUDIT_RAY_BELOW, 0)
    var query = PhysicsRayQueryParameters3D.create(origin, destination)
    query.exclude = [spawned_agent]

    var result = get_world_3d().direct_space_state.intersect_ray(query)
    if result.is_empty():
        return {
            "suspicious": true,
            "reason": "no_floor_hit"
        }

    var floor_y = float(result.position.y)
    var delta_y = floor_y - spawned_agent.global_position.y

    if delta_y > SPAWN_AUDIT_BELOW_FLOOR_THRESHOLD:
        return {
            "suspicious": true,
            "reason": "below_floor_surface",
            "floor_y": floor_y,
            "delta_y": delta_y
        }

    if delta_y < -SPAWN_AUDIT_ABOVE_FLOOR_THRESHOLD:
        return {
            "suspicious": true,
            "reason": "floating_above_floor",
            "floor_y": floor_y,
            "delta_y": delta_y
        }

    return {
        "suspicious": false,
        "floor_y": floor_y,
        "delta_y": delta_y
    }

func _zone_name() -> String:
    match zone:
        Zone.Area05:
            return "Area05"
        Zone.BorderZone:
            return "BorderZone"
        Zone.Vostok:
            return "Vostok"
        _:
            return "Unknown"

## Returns a human-readable name for the current intensity preset
## Used for debugging, logging, and UI display purposes
func _preset_name() -> String:
    match EnemyAISettings.intensity_preset:
        1:
            return "Medium"      # Balanced difficulty with moderate enemy presence
        2:
            return "Medium High" # Increased enemy density and spawn frequency
        3:
            return "High"        # Challenging with high enemy populations
        4:
            return "Very High"   # Intense combat with rapid spawning
        5:
            return "Insane"      # Maximum difficulty with overwhelming enemy numbers
        _:
            return "Default"     # Low intensity fallback setting

func _rate_name() -> String:
    match EnemyAISettings.spawn_rate_adjustment:
        0:
            return "Lower"
        2:
            return "Higher"
        _:
            return "Vanilla"

func _packed_scene_name(scene_resource) -> String:
    if scene_resource == bandit:
        return "Bandit"
    elif scene_resource == guard:
        return "Guard"
    elif scene_resource == military:
        return "Military"
    elif scene_resource == punisher:
        return "Punisher"
    return "Unknown"

# Team spawning methods

## Determines the size of a team based on faction type
## Returns 1 if team spawning is disabled
## Different factions have different team size ranges for tactical variety
func _get_team_size_for_faction(faction_name: String) -> int:
    if !EnemyAISettings.enable_team_spawning:
        return 1

    match faction_name:
        "Bandit":
            # Bandits spawn in larger groups (3-8) for ambush tactics
            return randi_range(EnemyAISettings.bandit_team_size_min, EnemyAISettings.bandit_team_size_max)
        "Guard":
            # Guards spawn in disciplined pairs/quads (2-4)
            return randi_range(EnemyAISettings.guard_team_size_min, EnemyAISettings.guard_team_size_max)
        "Military":
            # Military uses fireteam formations (2-4)
            return randi_range(EnemyAISettings.military_team_size_min, EnemyAISettings.military_team_size_max)
        _:
            # Default to single unit for unknown factions
            return 1

## Spawns an entire team of enemies at once
## Finds an available spawn point, determines faction from pool, and creates a coordinated team
## Teams spawn together and are removed from the pool as active agents
func _spawn_team_wanderer():
    if APool.get_child_count() == 0:
        DebugUtils._debug_log("No agents available in pool for team spawning")
        return

    # Find a suitable spawn point (ensures teams don't spawn on occupied locations)
    var spawn_point = _find_available_spawn_point()
    if spawn_point == null:
        DebugUtils._debug_log("No available spawn point found for team")
        return

    # Get a random agent from pool to determine which faction to spawn
    var pool_agent = APool.get_child(randi() % APool.get_child_count())
    var faction_name = pool_agent.get_meta("enemy_ai_faction")
    var scene_resource = _scene_for_faction_name(faction_name)

    if scene_resource == null:
        DebugUtils._debug_log("No scene resource found for faction %s" % faction_name)
        return

    # Generate unique team ID for tracking and coordination
    var team_id = _generate_unique_team_id()

    # Spawn the entire team at the chosen location
    var spawned_team = _spawn_team_at_location(scene_resource, spawn_point, team_id)

    # Remove the spawned agents from pool (they're now active in the world)
    for agent in spawned_team:
        if agent.get_parent() == APool:
            APool.remove_child(agent)

    DebugUtils._debug_log("Team %d spawned with %d %s members at %s" % [team_id, spawned_team.size(), faction_name, str(spawn_point.global_position)])

## Finds an available spawn point that isn't currently occupied by another team
## Returns null if no spawn points are available
## Uses occupation tracking to prevent teams from spawning at the same location
## Also ensures spawn point is far enough from player (matching base class behavior)
func _find_available_spawn_point() -> Node3D:
    if spawns.is_empty():
        return null

    # Filter spawn points by distance to player (must be > spawnDistance)
    var valid_spawns = spawns.filter(func(spawn_point):
        var distance_to_player = spawn_point.global_position.distance_to(gameData.playerPosition)
        return distance_to_player > spawnDistance
    )

    if valid_spawns.is_empty():
        DebugUtils._debug_log("No spawn points far enough from player")
        return null

    # Filter out spawn points that are currently occupied by active teams
    var available_spawns = valid_spawns.filter(func(spawn_point):
        return !occupied_spawn_points.has(spawn_point)
    )

    if available_spawns.is_empty():
        # If all valid spawn points are occupied, clear the occupation list as fallback
        # This allows reuse of spawn points when teams move or are defeated
        DebugUtils._debug_log("All valid spawn points occupied, clearing occupation tracking")
        occupied_spawn_points.clear()
        available_spawns = valid_spawns

    # Select a random available spawn point and mark it as occupied
    var selected_spawn = available_spawns.pick_random()
    occupied_spawn_points.append(selected_spawn)

    return selected_spawn

## Generates a unique ID for each team
## Uses a simple incrementing counter stored as metadata
## Team IDs help track team membership and coordination
func _generate_unique_team_id() -> int:
    # Simple counter for team IDs stored as node metadata
    if !has_meta("next_team_id"):
        set_meta("next_team_id", 0)
    var team_id = get_meta("next_team_id")
    set_meta("next_team_id", team_id + 1)
    return team_id

## Checks for defeated teams and releases their occupied spawn points
## Called when agents die to allow spawn point reuse
## Simple implementation that releases excess occupied points when team count decreases
func _check_and_release_defeated_team_spawn_points():
    if !EnemyAISettings.enable_team_spawning:
        return

    # Count currently active teams by scanning all agents
    var active_teams = {}
    for agent in agents.get_children():
        if agent.has_meta("team_id"):
            var team_id = agent.get_meta("team_id")
            if !active_teams.has(team_id):
                active_teams[team_id] = []
            active_teams[team_id].append(agent)

    # Simple spawn point management: release excess occupied points
    # This allows defeated teams' spawn points to be reused by new teams
    var expected_occupied = active_teams.size()
    if occupied_spawn_points.size() > expected_occupied:
        var to_release = occupied_spawn_points.size() - expected_occupied
        for i in range(to_release):
            if occupied_spawn_points.size() > 0:
                occupied_spawn_points.pop_back()
        DebugUtils._debug_log("Released %d occupied spawn points (active teams: %d)" % [to_release, expected_occupied])

## Creates and spawns a complete team at the specified spawn point
## Returns array of spawned agent nodes
## Each team member gets metadata for faction, team ID, and member index
## Agents are activated as wanderers to match base class behavior
func _spawn_team_at_location(scene_resource, spawn_point: Node3D, team_id: int) -> Array:
    var faction_name = _packed_scene_name(scene_resource)
    var team_size = _get_team_size_for_faction(faction_name)
    var spawned_agents = []

    # Spawn each member of the team
    for i in team_size:
        var new_agent = scene_resource.instantiate()
        agents.add_child(new_agent, true)

        new_agent.boss = false
        new_agent.AISpawner = self
        # Set faction for targeting and behavior
        new_agent.set_meta("enemy_ai_faction", faction_name)
        # Set team coordination metadata
        new_agent.set_meta("team_id", team_id)
        new_agent.set_meta("team_member_index", i)

        # Set spawn point for navigation (matching base class)
        new_agent.currentPoint = spawn_point

        # Add slight random offset so team members don't occupy exact same position
        var offset = Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
        new_agent.global_position = spawn_point.global_position + offset

        # Activate the agent as a wanderer (matching base class behavior)
        new_agent.ActivateWanderer()

        spawned_agents.append(new_agent)
        activeAgents += 1

        DebugUtils._debug_log("Team member %d/%d spawned for team %d (%s) at %s" % [i+1, team_size, team_id, faction_name, str(spawn_point.global_position)])

    return spawned_agents
