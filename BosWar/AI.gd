extends "res://Scripts/AI.gd"

var EnemyAISettings = preload("res://BosWar/EnemyAISettings.tres")
const DebugUtils = preload("res://BosWar/DebugUtils.gd")
const TARGET_INFO_DECAY_TIME = 10.0

enum QualityTier {
    VISUAL = 0,
    AUDIO = 1,
    SECOND_HAND = 2
}

func _quality_tier_to_string(quality: QualityTier) -> String:
    match quality:
        QualityTier.VISUAL:
            return "[VISUAL]"
        QualityTier.AUDIO:
            return "[AUDIO]"
        QualityTier.SECOND_HAND:
            return "[SECOND_HAND]"
    return "[UNKNOWN]"

const SECOND_HAND_VALIDITY_TIME = 5.0

var currentAITarget: Node3D
var currentAITargetVisible = false
var currentAITargetDistance = 9999.0
var targetRefreshTimer = 0.0
var targetRefreshCycle = 0.4
var targetRefreshJitter = 0.0
var targetVisibilityTimer = 0.0
var targetVisibilityJitter = 0.0
var aiAudioSenseTimer = 0.0
var aiAudioSenseJitter = 0.0
var broadcastCooldownPlayer = 0.0
var broadcastCooldownAI = 0.0
var targetLabel = "None"
var previousAITargetVisible = false
var lastAISoundTarget: Node3D
var lastAISoundReason = ""
const AI_HEARING_RUN_DISTANCE = 22.0
const AI_HEARING_WALK_DISTANCE = 8.0
const AI_HEARING_GUNSHOT_DISTANCE = 60.0
const TARGET_PRIORITY_DISTANCE = 25.0
const TARGET_SCAN_MAX_DISTANCE = 120.0
const TARGET_SCAN_MIN_DOT = -0.2
const AI_GUNSHOT_MEMORY_TIME = 1.25
const TRACE_TARGETING_COOLDOWN = 4.0
const TRACE_HOSTILITY_COOLDOWN = 6.0
const TRACE_VERBOSE = false
const THREADED_SCORING_PLAYER_ID = 0
const TEAMMATE_BROADCAST_RANGE_SQ = 2500.0
const TEAMMATE_TARGET_VALID_DISTANCE_SQ = 10000.0
const TEAMMATE_DUPLICATE_POSITION_EPSILON_SQ = 2.25
var current_target_type = "none"  # "player", "ai", or "none"
var current_target_score = 0.0
var current_target_quality = QualityTier.SECOND_HAND
var _last_known_location_data = {"position": Vector3.ZERO, "timestamp": 0.0, "quality": QualityTier.SECOND_HAND}
var is_close_visual_target: bool = false
var _shadow_scoring_thread: Thread
var _shadow_scoring_job_in_flight = false
var _shadow_scoring_next_job_id = 1
var _shadow_scoring_active_job_id = 0
var _shadow_scoring_active_submit_frame = -1
var _shadow_scoring_active_submit_time_msec = 0
var _shadow_scoring_last_consumed_submit_frame = -1
var _shadow_scoring_latest_result = {}
var jobs_submitted = 0
var jobs_completed = 0
var jobs_dropped_stale = 0
var _shadow_scoring_registered_global_slot = false
var _last_teammate_decision_time = -9999.0
var _last_teammate_broadcast = {
    "timestamp": 0.0,
    "target_type": "",
    "position": Vector3.ZERO,
    "target_id": -1,
    "quality": QualityTier.SECOND_HAND
}
var _last_debug_status_push_time = -9999.0
var _last_debug_status_event = ""
var _last_debug_status_target = ""

func Activate():
    if boss:
        health = 300.0 * EnemyAISettings.boss_health_multiplier
    else:
        health = 100.0 * EnemyAISettings.ai_health_multiplier

    targetRefreshJitter = randf_range(0.0, 0.12)
    targetRefreshTimer = randf_range(0.0, _current_target_refresh_cycle())
    targetVisibilityJitter = randf_range(0.0, 0.06)
    targetVisibilityTimer = randf_range(0.0, _current_target_visibility_cycle())
    aiAudioSenseJitter = randf_range(0.0, 0.1)
    aiAudioSenseTimer = randf_range(0.0, _current_ai_audio_cycle())
    broadcastCooldownPlayer = 0.0
    broadcastCooldownAI = 0.0
    lastKnownLocation = Vector3.ZERO
    if !is_connected("tree_exited", Callable(self, "_on_tree_exited_shadow_scoring_cleanup")):
        connect("tree_exited", Callable(self, "_on_tree_exited_shadow_scoring_cleanup"))

    super()

func Parameters(delta):
    super(delta)
    _refresh_player_alignment_state()
    _update_hostile_ai_targeting(delta)

func Sensor(delta):
    sensorTimer += delta
    aiAudioSenseTimer -= delta

    if sensorTimer > sensorCycle:
        var player_detected = _sense_player_los()
        var custom_targeting_active = _custom_ai_targeting_active()

        if custom_targeting_active:
            if !player_detected and _has_valid_ai_target() and currentAITargetVisible:
                _last_known_location_data = {"position": _get_ai_target_position(), "timestamp": Time.get_ticks_msec() / 1000.0, "quality": QualityTier.VISUAL}
                lastKnownLocation = _last_known_location_data.position

                if currentState == State.Wander or currentState == State.Guard or currentState == State.Patrol:
                    Decision()
                elif currentState == State.Ambush:
                    ChangeState("Combat")

        if custom_targeting_active and !_has_stable_visible_ai_target() and aiAudioSenseTimer <= 0.0:
            _sense_ai_audio()
            aiAudioSenseTimer = _current_ai_audio_cycle()

        if !playerVisible:
            Hearing()

        sensorTimer = 0.0

func LOSCheck(target: Vector3):
    var sight_multiplier = max(0.1, EnemyAISettings.ai_sight_multiplier)

    if gameData.TOD == 4 and !gameData.flashlight and !boss:
        LOS.target_position = Vector3(0, 0, (25 + extraVisibility) * sight_multiplier)
    elif gameData.fog and !boss:
        LOS.target_position = Vector3(0, 0, (100 + extraVisibility) * sight_multiplier)
    else:
        LOS.target_position = Vector3(0, 0, 200 * sight_multiplier)

    LOS.look_at(target, Vector3.UP, true)
    LOS.force_raycast_update()

    if LOS.is_colliding() and LOS.get_collider().is_in_group("Player"):
        _last_known_location_data = {"position": playerPosition, "timestamp": Time.get_ticks_msec() / 1000.0, "quality": QualityTier.VISUAL}
        lastKnownLocation = playerPosition
        playerVisible = true
        if playerDistance3D < 25:
            is_close_visual_target = true
        else:
            is_close_visual_target = false
    else:
        playerVisible = false
        is_close_visual_target = false

func Hearing():
    if !_can_target_player():
        return

    var hearing_multiplier = max(0.1, EnemyAISettings.ai_hearing_multiplier)
    var run_distance = 20.0 * hearing_multiplier
    var walk_distance = 5.0 * hearing_multiplier

    if (playerDistance3D < run_distance and gameData.isRunning) or (playerDistance3D < walk_distance and gameData.isWalking):
        if currentState != State.Ambush:
            _last_known_location_data = {"position": playerPosition, "timestamp": Time.get_ticks_msec() / 1000.0, "quality": QualityTier.AUDIO}
            var audio_type = "audio_player"
            if gameData.isRunning and playerDistance3D < run_distance:
                audio_type = "audio_player_running"
            elif gameData.isWalking and playerDistance3D < walk_distance:
                audio_type = "audio_player_walking"
            _broadcast_target_to_teammates(playerPosition, audio_type, null, QualityTier.AUDIO)

func FireDetection(delta):
    if !_can_target_player():
        return

    fireDetectionTime = EnemyAISettings.ai_gunshot_alert_duration
    var hearing_multiplier = max(0.1, EnemyAISettings.ai_hearing_multiplier)
    var local_alert_distance = 50.0 * hearing_multiplier

    if gameData.isFiring and !playerVisible:
        if fireVector > 0.95:
            _last_known_location_data = {"position": playerPosition, "timestamp": Time.get_ticks_msec() / 1000.0, "quality": QualityTier.AUDIO}
            lastKnownLocation = playerPosition
            _broadcast_target_to_teammates(playerPosition, "audio_player_gunshot", null, QualityTier.AUDIO)

            fireDetected = true
            extraVisibility = 50.0 * max(0.25, EnemyAISettings.ai_sight_multiplier)
        elif playerDistance3D < local_alert_distance:
            if currentState != State.Ambush:
                _last_known_location_data = {"position": playerPosition, "timestamp": Time.get_ticks_msec() / 1000.0, "quality": QualityTier.AUDIO}
                lastKnownLocation = playerPosition
                _broadcast_target_to_teammates(playerPosition, "audio_player_gunshot", null, QualityTier.AUDIO)

            fireDetected = true
            extraVisibility = 50.0 * max(0.25, EnemyAISettings.ai_sight_multiplier)

    if fireDetected:
        fireDetectionTimer += delta

        if fireDetectionTimer > fireDetectionTime:
            extraVisibility = 0.0
            fireDetectionTimer = 0.0
            fireDetected = false

func Decision():
    if is_close_visual_target:
        ChangeState("Combat")
        return

    var engagement_distance = _get_engagement_distance()
    var engagement_visible = _engagement_visible()
    var can_direct_attack = _can_direct_attack_target()

    if engagement_distance > 20:
        var max_decision = 9
        if _count_teammates_targeting_same() > 0:
            max_decision = 12  # Add 3 more slots for Combat (covering fire)
        var decision = randi_range(1, max_decision)

        if decision == 1:
            ChangeState("Combat")
        elif decision == 2 and !AISpawner.noHiding and _has_hide_point_candidate():
            ChangeState("Hide")
        elif decision == 3 and _has_cover_point_candidate():
            ChangeState("Cover")
        elif decision == 4 and _has_vantage_point_candidate():
            ChangeState("Vantage")
        elif decision == 5:
            ChangeState("Defend")
        elif decision == 6 and engagement_visible and engagement_distance < 100 and can_direct_attack:
            ChangeState("Hunt")
        elif decision == 7 and engagement_visible and engagement_distance < 100 and can_direct_attack:
            ChangeState("Shift")
        elif decision == 8 and engagement_visible and engagement_distance < 100 and can_direct_attack and (weaponData.weaponAction != "Manual"):
            ChangeState("Attack")
        else:
            ChangeState("Combat")
    else:
        var decision_close = randi_range(1, 4)

        if decision_close == 1:
            ChangeState("Combat")
        elif decision_close == 2:
            ChangeState("Defend")
        elif decision_close == 3 and engagement_visible and can_direct_attack:
            ChangeState("Hunt")
        elif decision_close == 4 and engagement_visible and can_direct_attack and (weaponData.weaponAction != "Manual"):
            ChangeState("Attack")
        else:
            ChangeState("Combat")

func Shift(delta):
    shiftTimer += delta

    if _engagement_visible():
        Fire(delta)

    if shiftTimer > shiftCycle:
        shiftCount -= 1
        shiftTimer = 0.0

        if !GetShiftWaypoint():
            ChangeState("Combat")

    if shiftCount == 0:
        ChangeState("Combat")

    if _get_engagement_distance() < 10 or agent.is_target_reached() or agent.is_navigation_finished():
        ChangeState("Combat")

func Hunt(delta):
    huntTimer += delta

    if _engagement_visible():
        Fire(delta)

    if huntTimer > huntCycle:
        GetHuntWaypoint()
        huntTimer = 0.0

    if agent.is_target_reached() or agent.is_navigation_finished() or _player_only_combat_blocked():
        ChangeState("Combat")

func Attack(delta):
    attackTimer += delta

    if _engagement_visible():
        Fire(delta)

    if attackTimer > attackCycle:
        GetAttackWaypoint()
        attackTimer = 0.0

    if agent.is_target_reached() or agent.is_navigation_finished() or _player_only_combat_blocked():
        if attackReturn and !_engagement_visible():
            ChangeState("Return")
        else:
            ChangeState("Combat")

func Return():
    if global_transform.origin.distance_to(agent.target_position) < 2.0:
        speed = 1.0
        turnSpeed = 2.0
    elif global_transform.origin.distance_to(agent.target_position) < 4.0:
        speed = 3.0
        turnSpeed = 5.0

    if agent.is_target_reached() or agent.is_navigation_finished():
        ChangeState("Combat")

    if _get_engagement_distance() < 10:
        ChangeState("Combat")

func Combat(delta):
    combatTimer += delta

    if _engagement_visible():
        Fire(delta)

    if combatTimer > combatCycle or agent.is_target_reached() or agent.is_navigation_finished():
        Decision()

    if is_close_visual_target:
        speed = 0.0
        turnSpeed = 0.0
        if is_instance_valid(agent):
            agent.target_position = global_position

func Fire(delta):
    if impact or _player_only_combat_blocked():
        return

    if !_is_last_known_location_valid() or _last_known_location_data.position.distance_to(_get_engagement_position()) > 4.0:
        return

    if weaponData.weaponAction == "Semi-Auto":
        Selector(delta)

    fireTime -= delta

    if fireTime <= 0:
        _mark_ai_gunshot()
        Raycast()
        PlayFire()
        PlayTail()
        MuzzleVFX()

        impulseTime = spineData.impulse / 2
        impulseTimer = 0.0

        recoveryTime = spineData.impulse
        recoveryTimer = 0.0

        if fullAuto:
            var impulseX = spineTarget.x - spineData.recoil * 1.1
            impulseX = clamp(impulseX, -spineData.recoil * 2.2, spineData.recoil * 0.75)
            var impulseY = spineTarget.y
            var impulseZ = spineTarget.z
            impulseTarget = Vector3(impulseX, impulseY, impulseZ)
        else:
            var impulseX2 = spineTarget.x - spineData.recoil
            impulseX2 = clamp(impulseX2, -spineData.recoil * 1.6, spineData.recoil * 0.75)
            var impulseY2 = spineTarget.y
            var impulseZ2 = spineTarget.z
            impulseTarget = Vector3(impulseX2, impulseY2, impulseZ2)

        flash.global_position = muzzle.global_position
        flash.Activate()

        FireFrequency()

        if _should_play_player_bullet_audio() and _get_engagement_distance() > 50:
            await get_tree().create_timer(0.1, false).timeout
            PlayCrack()

func FireFrequency():
    var engagement_distance = _get_engagement_distance()
    var faction = _self_faction()
    var is_bandit_or_guard = faction == "Bandit" or faction == "Guard"

    if weaponData.weaponAction == "Semi-Auto" and fullAuto:
        fireTime = weaponData.fireRate * 1.35
    elif (weaponData.weaponAction == "Semi-Auto" or weaponData.weaponAction == "Semi") and !fullAuto:
        if engagement_distance < 10:
            fireTime = randf_range(0.1, 0.5)
        elif engagement_distance > 10 and engagement_distance < 50:
            fireTime = randf_range(0.1, 1.0)
        else:
            if is_bandit_or_guard:
                fireTime = randf_range(0.08, 1.2)
            else:
                fireTime = randf_range(0.1, 2.0)
    elif weaponData.weaponAction == "Pump" or weaponData.weaponAction == "Bolt":
        if engagement_distance < 10:
            fireTime = randf_range(1.0, 2.0)
        elif engagement_distance > 10 and engagement_distance < 50:
            fireTime = randf_range(1.0, 2.0)
        else:
            fireTime = randf_range(1.0, 4.0)
    else:
        fireTime = randf_range(1.0, 4.0)

    fireTime = max(0.05, fireTime / max(0.1, EnemyAISettings.ai_fire_rate_multiplier))

func FireAccuracy() -> Vector3:
    var fireDirection = _get_fire_target_position()
    var xform = Basis.looking_at(fireDirection - fire.global_position)
    var spreadMultiplier = 1.0
    var accuracy_multiplier = max(0.1, EnemyAISettings.ai_accuracy_multiplier)
    var engagement_distance = _get_engagement_distance()
    var ai_target = _has_valid_ai_target()
    var faction = _self_faction()
    var is_bandit_or_guard = faction == "Bandit" or faction == "Guard"
    var long_range_penalty = 1.0
    var offset = Vector3(0, 0, 0)

    if fullAuto and !boss:
        spreadMultiplier = 3.0

    if engagement_distance > 50.0 and is_bandit_or_guard:
        long_range_penalty = 1.5 if fullAuto else 1.25

    if ai_target:
        var horizontalSpread = 0.0
        var verticalSpread = 0.0

        if engagement_distance < 10 or boss:
            horizontalSpread = 0.05
            verticalSpread = 0.02
        elif engagement_distance > 10 and engagement_distance < 50:
            horizontalSpread = 0.25
            verticalSpread = 0.08
        else:
            horizontalSpread = 0.5
            verticalSpread = 0.15

        horizontalSpread *= long_range_penalty
        verticalSpread *= long_range_penalty
        fireDirection.x += randf_range(-horizontalSpread, horizontalSpread) * spreadMultiplier / accuracy_multiplier
        fireDirection.y += randf_range(-verticalSpread, verticalSpread) * spreadMultiplier / accuracy_multiplier
    elif engagement_distance < 10 or boss:
        fireDirection.x += randf_range(-0.1, 0.1) * spreadMultiplier / accuracy_multiplier
        fireDirection.y += randf_range(-0.1, 0.1) * spreadMultiplier / accuracy_multiplier
    elif engagement_distance > 10 and engagement_distance < 50:
        fireDirection.x += randf_range(-1.0, 1.0) * spreadMultiplier / accuracy_multiplier
        fireDirection.y += randf_range(-1.0, 1.0) * spreadMultiplier / accuracy_multiplier
    else:
        fireDirection.x += randf_range(-2.0 * long_range_penalty, 2.0 * long_range_penalty) * spreadMultiplier / accuracy_multiplier
        fireDirection.y += randf_range(-2.0 * long_range_penalty, 2.0 * long_range_penalty) * spreadMultiplier / accuracy_multiplier

    return fireDirection + xform * offset

func Raycast():
    fire.look_at(FireAccuracy(), Vector3.UP, true)
    fire.force_raycast_update()

    if fire.is_colliding():
        var hitCollider = fire.get_collider()

        if hitCollider is Hitbox:
            _apply_damage_to_hitbox(hitCollider, _shot_damage())
        elif _is_ai_root_hit(hitCollider):
            if !_try_apply_targeted_hitbox_damage(hitCollider):
                var rootDamage = _shot_damage()
                DebugUtils._debug_log("Shot landed via AI root collider=%s treating as torso damage=%.1f target=%s" % [hitCollider.name, rootDamage, targetLabel])
                hitCollider.WeaponDamage("Torso", rootDamage)
                var debug_main = get_node_or_null("/root/EnemyAIMain")
                if debug_main:
                    debug_main.record_hit("Torso", true)
        elif hitCollider.is_in_group("Player"):
            if boss:
                hitCollider.get_child(0).WeaponDamage(weaponData.damage * 2.0, weaponData.penetration)
            else:
                hitCollider.get_child(0).WeaponDamage(weaponData.damage, weaponData.penetration)
        else:
            var hitPoint = fire.get_collision_point()
            var hitNormal = fire.get_collision_normal()
            var hitSurface = hitCollider.get("surface")
            BulletDecal(hitCollider, hitPoint, hitNormal, hitSurface)
    elif _should_play_player_bullet_audio() and _get_engagement_distance() > 50:
        await get_tree().create_timer(0.1, false).timeout
        PlayFlyby()

func GetHidePoint() -> bool:
    var validPoints: Array[Node3D]
    var engagement_position = _get_engagement_position()

    if nearbyPoints.size() != 0:
        for point in nearbyPoints:
            if point.is_in_group("AI_HP"):
                var distanceToAI = global_position.distance_to(point.global_position)
                var distanceToTarget = point.global_position.distance_to(engagement_position)

                if distanceToAI < 40 and distanceToAI < distanceToTarget:
                    if point != currentPoint:
                        validPoints.append(point)

    if validPoints.size() != 0:
        var hidePoint = validPoints.pick_random()
        currentPoint = hidePoint
        MoveToPoint(hidePoint.global_position)
        return true

    return false

func _has_hide_point_candidate() -> bool:
    var engagement_position = _get_engagement_position()

    if nearbyPoints.size() == 0:
        return false

    for point in nearbyPoints:
        if point.is_in_group("AI_HP"):
            var distanceToAI = global_position.distance_to(point.global_position)
            var distanceToTarget = point.global_position.distance_to(engagement_position)
            if distanceToAI < 40 and distanceToAI < distanceToTarget and point != currentPoint:
                return true

    return false

func GetVantagePoint() -> bool:
    var validPoints: Array[Node3D]
    var engagement_position = _get_engagement_position()

    if nearbyPoints.size() != 0:
        for point in nearbyPoints:
            if point.is_in_group("AI_PP"):
                var distanceToAI = global_position.distance_to(point.global_position)
                var distanceToTarget = point.global_position.distance_to(engagement_position)

                if distanceToAI < 40 and distanceToAI < distanceToTarget:
                    var direction = (engagement_position - point.global_position).normalized()
                    var vector = direction.dot(point.global_transform.basis.z)

                    if vector > 0.9 and point != currentPoint:
                        validPoints.append(point)

    if validPoints.size() != 0:
        var vantage = validPoints.pick_random()
        currentPoint = vantage
        MoveToPoint(vantage.global_position)
        return true

    return false

func _has_vantage_point_candidate() -> bool:
    var engagement_position = _get_engagement_position()

    if nearbyPoints.size() == 0:
        return false

    for point in nearbyPoints:
        if point.is_in_group("AI_PP"):
            var distanceToAI = global_position.distance_to(point.global_position)
            var distanceToTarget = point.global_position.distance_to(engagement_position)
            if distanceToAI < 40 and distanceToAI < distanceToTarget:
                var direction = (engagement_position - point.global_position).normalized()
                var vector = direction.dot(point.global_transform.basis.z)
                if vector > 0.9 and point != currentPoint:
                    return true

    return false

func GetCoverPoint() -> bool:
    var validPoints: Array[Node3D]
    var engagement_position = _get_engagement_position()

    if nearbyPoints.size() != 0:
        for point in nearbyPoints:
            if point.is_in_group("AI_CP"):
                var distanceToAI = global_position.distance_to(point.global_position)
                var distanceToTarget = point.global_position.distance_to(engagement_position)

                if distanceToAI < 40 and distanceToAI < distanceToTarget:
                    var direction = (engagement_position - point.global_position).normalized()
                    var vector = direction.dot(point.global_transform.basis.z)

                    if vector < -0.8 and point != currentPoint:
                        validPoints.append(point)

    if validPoints.size() != 0:
        var cover = validPoints.pick_random()
        currentPoint = cover
        MoveToPoint(cover.global_position)
        return true

    return false

func _has_cover_point_candidate() -> bool:
    var engagement_position = _get_engagement_position()

    if nearbyPoints.size() == 0:
        return false

    for point in nearbyPoints:
        if point.is_in_group("AI_CP"):
            var distanceToAI = global_position.distance_to(point.global_position)
            var distanceToTarget = point.global_position.distance_to(engagement_position)
            if distanceToAI < 40 and distanceToAI < distanceToTarget:
                var direction = (engagement_position - point.global_position).normalized()
                var vector = direction.dot(point.global_transform.basis.z)
                if vector < -0.8 and point != currentPoint:
                    return true

    return false

func GetShiftWaypoint():
    var validPoints: Array[Node3D]
    var engagement_position = _get_engagement_position()

    if nearbyPoints.size() != 0:
        for point in nearbyPoints:
            if point.is_in_group("AI_WP"):
                var distanceToAI = global_position.distance_to(point.global_position)
                var directionToTarget = (engagement_position - global_position).normalized()
                var directionToPoint = (point.global_position - global_position).normalized()

                if directionToPoint.dot(directionToTarget) > 0 and distanceToAI < global_position.distance_to(engagement_position):
                    if point != currentPoint:
                        validPoints.append(point)

    if validPoints.size() != 0:
        var shift = validPoints.pick_random()
        currentPoint = shift
        MoveToPoint(shift.global_position)
        return true

    return false

func GetHuntWaypoint():
    if _is_last_known_location_valid():
        MoveToPoint(_last_known_location_data.position)

func GetAttackWaypoint():
    if _is_last_known_location_valid():
        MoveToPoint(_last_known_location_data.position)

func ChangeState(state):
    super(state)

    var cycle_scale = _get_tactics_cycle_scale()

    if currentState == State.Guard:
        guardCycle *= cycle_scale
    elif currentState == State.Defend:
        defendCycle *= cycle_scale
    elif currentState == State.Combat:
        combatCycle *= cycle_scale
    elif currentState == State.Shift:
        shiftCycle *= cycle_scale
    elif currentState == State.Hunt:
        huntCycle *= cycle_scale
    elif currentState == State.Attack:
        attackCycle *= cycle_scale
    elif currentState == State.Ambush:
        ambushCycle *= cycle_scale

func Spine(delta):
    if currentState == State.Defend or currentState == State.Combat or currentState == State.Hunt or currentState == State.Attack or currentState == State.Shift:
        spineWeight = move_toward(spineWeight, spineData.weight, delta)
    else:
        spineWeight = move_toward(spineWeight, 0.0, delta * 10.0)

    var spinePose: Transform3D = skeleton.get_bone_global_pose_no_override(spineData.bone)
    var aimTarget: Vector3

    var engagement_pos = _get_engagement_position()
    aimTarget = -skeleton.to_local(engagement_pos) + Vector3(0, 1, 0)

    var spineAimPose = spinePose.looking_at(aimTarget, Vector3.UP)
    spineAimPose.basis = spineAimPose.basis.rotated(spineAimPose.basis.x, deg_to_rad(spineTarget.x))
    spineAimPose.basis = spineAimPose.basis.rotated(spineAimPose.basis.y, deg_to_rad(spineTarget.y))
    spineAimPose.basis = spineAimPose.basis.rotated(spineAimPose.basis.z, deg_to_rad(spineTarget.z))

    skeleton.set_bone_global_pose_override(spineData.bone, spineAimPose, spineWeight, true)

func _get_tactics_cycle_scale() -> float:
    match EnemyAISettings.ai_tactics_preset:
        0:
            return 1.5
        2:
            return 0.75
        3:
            return 0.5
        _:
            return 1.0

func _is_last_known_location_valid() -> bool:
    var now = Time.get_ticks_msec() / 1000.0
    var decay_time = TARGET_INFO_DECAY_TIME
    if _last_known_location_data.has("quality") and _last_known_location_data.quality == QualityTier.SECOND_HAND:
        decay_time = SECOND_HAND_VALIDITY_TIME
    return now - _last_known_location_data.timestamp <= decay_time

func Death(direction, force):
    if has_meta("boswar_death_processed"):
        return
    set_meta("boswar_death_processed", true)

    DebugUtils._debug_log("Death faction=%s target=%s" % [_self_faction(), targetLabel])
    var before_active = -1
    if is_instance_valid(AISpawner):
        before_active = int(AISpawner.activeAgents)

    super(direction, force)
    if is_instance_valid(AISpawner) and AISpawner.activeAgents < 0:
        AISpawner.activeAgents = 0

    if is_instance_valid(AISpawner):
        DebugUtils._debug_log("Death decrement: faction=%s, activeAgents before=%d after=%d" % [_self_faction(), before_active, AISpawner.activeAgents])

    if is_instance_valid(AISpawner) and AISpawner.has_method("replenish_regular_pool") and !boss:
        AISpawner.replenish_regular_pool(_self_faction())
    _clear_ai_target()

    var debug_main = get_node_or_null("/root/EnemyAIMain")
    if debug_main:
        debug_main.record_death(AISpawner.activeAgents, {
            "last_event": "AI died",
            "current_target": "None"
        })
        debug_main.register_corpse(self, {
            "label": name,
            "faction": _self_faction()
        })

func _custom_ai_targeting_active() -> bool:
    if boss:
        return false

    return _team_targeting_active() or _same_faction_infighting_active() or _faction_warfare_active()

func _team_targeting_active() -> bool:
    return _self_team_id() >= 0

func _same_faction_infighting_active() -> bool:
    return _same_faction_infighting_enabled(_self_faction())

func _faction_warfare_active() -> bool:
    var faction = _self_faction()
    return EnemyAISettings.warfare_enabled and _is_supported_warfare_faction(faction)

func _sense_player_los() -> bool:
    if !_can_target_player():
        playerVisible = false
        return false

    if playerDistance3D <= 200.0:
        var directionToPlayer = (eyes.global_position - gameData.cameraPosition).normalized()
        var viewDirection = -eyes.global_transform.basis.z.normalized()
        var viewRadius = viewDirection.dot(directionToPlayer)

        if viewRadius > 0.5:
            LOSCheck(gameData.cameraPosition)
            if playerVisible and current_target_type == "player" and current_target_quality > QualityTier.VISUAL:
                current_target_quality = QualityTier.VISUAL
                _set_target_label()
                _broadcast_target_to_teammates(playerPosition, "player", null, QualityTier.VISUAL)
                DebugUtils._debug_log("Upgraded player target quality to VISUAL")
            return playerVisible

    playerVisible = false
    return false



func _can_target_player() -> bool:
    var aligned_faction = _player_aligned_faction()
    return aligned_faction == "" or aligned_faction != _self_faction()

func _player_aligned_faction() -> String:
    match EnemyAISettings.player_faction_alignment:
        1:
            return "Bandit"
        2:
            return "Guard"
        3:
            return "Military"
        _:
            return ""

func _refresh_player_alignment_state():
    if _can_target_player():
        return

    playerVisible = false
    is_close_visual_target = false

    if !_has_valid_ai_target():
        targetLabel = "None"
        current_target_type = "none"
        current_target_score = 0.0

    DebugUtils._debug_log("Player alignment cleared hostility for faction=%s" % _self_faction())



func _self_faction() -> String:
    if has_meta("enemy_ai_faction"):
        return _normalize_faction_name(str(get_meta("enemy_ai_faction")))
    return "Unknown"

func _trace_key(suffix: String) -> String:
    return "ai_trace_%s_%s" % [str(get_instance_id()), suffix]

func _trace_log(suffix: String, message: String, cooldown_seconds: float = TRACE_TARGETING_COOLDOWN):
    if !TRACE_VERBOSE:
        return
    DebugUtils._debug_log_rate_limited(_trace_key(suffix), "[trace] " + message, cooldown_seconds)

func _get_active_agent_candidates() -> Array:
    if !is_instance_valid(AISpawner):
        return []
    if AISpawner.has_method("get_all_active_agents_ref"):
        return AISpawner.get_all_active_agents_ref()
    if AISpawner.has_method("get_all_active_agents"):
        return AISpawner.get_all_active_agents()
    if AISpawner.has_method("get_active_agents_snapshot"):
        var snapshot_payload = AISpawner.get_active_agents_snapshot()
        if typeof(snapshot_payload) == TYPE_DICTIONARY:
            return snapshot_payload.get("all_active_agents", [])
        if typeof(snapshot_payload) == TYPE_ARRAY:
            return snapshot_payload
        return []
    if is_instance_valid(AISpawner.agents):
        return AISpawner.agents.get_children()
    return []

func _get_teammate_candidates(self_faction: String) -> Array:
    if !is_instance_valid(AISpawner):
        return []
    if AISpawner.has_method("get_active_agents_by_faction_ref"):
        return AISpawner.get_active_agents_by_faction_ref(self_faction)
    if AISpawner.has_method("get_active_agents_by_faction"):
        return AISpawner.get_active_agents_by_faction(self_faction)
    return _get_active_agent_candidates()

func _shadow_scoring_global_jobs_in_flight() -> int:
    if !is_instance_valid(AISpawner):
        return 0
    return int(AISpawner.get_meta("boswar_shadow_jobs_in_flight", 0))

func _set_shadow_scoring_global_jobs_in_flight(value: int):
    if !is_instance_valid(AISpawner):
        return
    AISpawner.set_meta("boswar_shadow_jobs_in_flight", max(0, value))

func _increment_shadow_scoring_global_jobs(delta: int):
    _set_shadow_scoring_global_jobs_in_flight(_shadow_scoring_global_jobs_in_flight() + delta)

func _release_shadow_scoring_global_slot_if_needed():
    if !_shadow_scoring_registered_global_slot:
        return
    _increment_shadow_scoring_global_jobs(-1)
    _shadow_scoring_registered_global_slot = false

func _should_skip_duplicate_teammate_broadcast(target_position: Vector3, target_type: String, target_node: Node3D, quality: QualityTier) -> bool:
    var duplicate_ttl = max(0.0, float(EnemyAISettings.teammate_message_duplicate_ttl_seconds))
    if duplicate_ttl <= 0.0:
        return false

    var now_seconds = Time.get_ticks_msec() / 1000.0
    var elapsed = now_seconds - float(_last_teammate_broadcast.get("timestamp", 0.0))
    if elapsed > duplicate_ttl:
        return false

    if str(_last_teammate_broadcast.get("target_type", "")) != target_type:
        return false

    var target_id = int(target_node.get_instance_id()) if is_instance_valid(target_node) else -1
    if int(_last_teammate_broadcast.get("target_id", -1)) != target_id:
        return false

    var previous_quality = int(_last_teammate_broadcast.get("quality", QualityTier.SECOND_HAND))
    if int(quality) < previous_quality:
        return false

    var previous_position: Vector3 = _last_teammate_broadcast.get("position", Vector3.ZERO)
    if previous_position.distance_squared_to(target_position) > TEAMMATE_DUPLICATE_POSITION_EPSILON_SQ:
        return false

    return true

func _record_teammate_broadcast(target_position: Vector3, target_type: String, target_node: Node3D, quality: QualityTier):
    var target_id = int(target_node.get_instance_id()) if is_instance_valid(target_node) else -1
    _last_teammate_broadcast = {
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "target_type": target_type,
        "position": target_position,
        "target_id": target_id,
        "quality": int(quality)
    }

func _update_hostile_ai_targeting(delta):
    if EnemyAISettings.enable_threaded_scoring_shadow_mode or _shadow_scoring_job_in_flight:
        _consume_shadow_scoring_result()

    if bool(get("dead")) or bool(get("pause")):
        _clear_shadow_scoring_runtime_state(false)
        return

    if !_custom_ai_targeting_active():
        _clear_shadow_scoring_runtime_state(false)
        _trace_log(
            "targeting_gate_off",
            "Targeting gate OFF faction=%s team=%d warfare=%s infight(B/G/M)=%s/%s/%s current_target=%s" % [
                _self_faction(),
                _self_team_id(),
                str(EnemyAISettings.warfare_enabled),
                str(EnemyAISettings.bandit_infighting_enabled),
                str(EnemyAISettings.guard_infighting_enabled),
                str(EnemyAISettings.military_infighting_enabled),
                current_target_type
            ],
            TRACE_HOSTILITY_COOLDOWN
        )
        _clear_ai_target(false)
        return

    var current_refresh_cycle = _current_target_refresh_cycle()
    if targetRefreshTimer > current_refresh_cycle:
        targetRefreshTimer = current_refresh_cycle

    var current_visibility_cycle = _current_target_visibility_cycle()
    if targetVisibilityTimer > current_visibility_cycle:
        targetVisibilityTimer = current_visibility_cycle

    targetRefreshTimer -= delta
    targetVisibilityTimer -= delta
    broadcastCooldownPlayer -= delta
    broadcastCooldownAI -= delta

    var has_valid_ai_target = _has_valid_ai_target()
    if (current_target_type == "none" or !has_valid_ai_target) or targetRefreshTimer <= 0.0:
        var result = _acquire_best_target()
        var refresh_stagger = max(0.0, targetRefreshJitter * 0.5)
        targetRefreshTimer = max(0.05, current_refresh_cycle + randf_range(-refresh_stagger, refresh_stagger))
        targetVisibilityTimer = 0.0
        if result != null:
            var visibility_stagger = max(0.0, targetVisibilityJitter * 0.5)
            targetVisibilityTimer = max(0.03, current_visibility_cycle + randf_range(-visibility_stagger, visibility_stagger))
        has_valid_ai_target = _has_valid_ai_target()

        if result != null:
            if current_target_type == "ai" and is_instance_valid(currentAITarget):
                DebugUtils._debug_log_rate_limited("hostile_target_acquired", "Hostile target acquired: %s" % targetLabel, 1.0)
                _push_debug_status("Hostile target acquired")
        elif TRACE_VERBOSE:
            var local_agents = AISpawner.agents.get_child_count() if is_instance_valid(AISpawner) and is_instance_valid(AISpawner.agents) else -1
            _trace_log(
                "acquire_none",
                "No target acquired faction=%s team=%d local_agents=%d player_visible=%s current_target=%s" % [
                    _self_faction(),
                    _self_team_id(),
                    local_agents,
                    str(playerVisible),
                    current_target_type
                ]
            )

    if !has_valid_ai_target:
        _update_target_visibility()
    else:
        currentAITargetDistance = global_position.distance_to(currentAITarget.global_position)
        _set_target_label()

        if targetVisibilityTimer <= 0.0:
            _update_target_visibility()
            var visibility_stagger = max(0.0, targetVisibilityJitter * 0.5)
            targetVisibilityTimer = max(0.03, current_visibility_cycle + randf_range(-visibility_stagger, visibility_stagger))

    _submit_shadow_scoring_job_if_due()

func _submit_shadow_scoring_job_if_due():
    if !EnemyAISettings.enable_threaded_scoring_shadow_mode:
        return
    if _shadow_scoring_job_in_flight:
        return

    var cohort_modulo = max(1, int(EnemyAISettings.threaded_scoring_cohort_modulo))
    if cohort_modulo > 1:
        var frame_mod = int(Engine.get_process_frames()) % cohort_modulo
        var cohort_slot = int(get_instance_id()) % cohort_modulo
        if frame_mod != cohort_slot:
            return

    var payload = _build_shadow_scoring_payload()
    if payload.is_empty():
        return

    var payload_candidates = payload.get("candidates", [])
    var candidate_count = payload_candidates.size() if typeof(payload_candidates) == TYPE_ARRAY else 0
    var min_candidates_for_thread = max(0, int(EnemyAISettings.threaded_scoring_min_candidates_for_thread))
    if candidate_count < min_candidates_for_thread:
        jobs_submitted += 1
        jobs_completed += 1
        _shadow_scoring_next_job_id += 1
        _consume_shadow_scoring_payload_result(_shadow_scoring_worker(payload))
        return

    var max_global_jobs = max(1, int(EnemyAISettings.threaded_scoring_max_global_jobs))
    if _shadow_scoring_global_jobs_in_flight() >= max_global_jobs:
        return

    var worker_thread = Thread.new()
    var start_err = worker_thread.start(Callable(self, "_shadow_scoring_worker").bind(payload))
    if start_err != OK:
        return

    _increment_shadow_scoring_global_jobs(1)
    _shadow_scoring_registered_global_slot = true
    _shadow_scoring_thread = worker_thread
    _shadow_scoring_job_in_flight = true
    _shadow_scoring_active_job_id = int(payload.get("job_id", 0))
    _shadow_scoring_active_submit_frame = int(payload.get("submit_frame", -1))
    _shadow_scoring_active_submit_time_msec = int(payload.get("submit_time_msec", 0))
    _shadow_scoring_next_job_id += 1
    jobs_submitted += 1

func _consume_shadow_scoring_result():
    if !_shadow_scoring_job_in_flight:
        return
    if _shadow_scoring_thread == null:
        _release_shadow_scoring_global_slot_if_needed()
        _shadow_scoring_job_in_flight = false
        return
    if _shadow_scoring_thread.is_alive():
        return

    var result = _shadow_scoring_thread.wait_to_finish()
    _release_shadow_scoring_global_slot_if_needed()
    _shadow_scoring_thread = null
    _shadow_scoring_job_in_flight = false
    jobs_completed += 1

    _consume_shadow_scoring_payload_result(result)

func _consume_shadow_scoring_payload_result(result):
    if typeof(result) != TYPE_DICTIONARY:
        return

    var submit_frame = int(result.get("submit_frame", -1))
    if submit_frame <= _shadow_scoring_last_consumed_submit_frame:
        jobs_dropped_stale += 1
        return

    _shadow_scoring_last_consumed_submit_frame = submit_frame
    _shadow_scoring_latest_result = result
    _compare_shadow_scoring_with_authoritative(result)
    _log_shadow_scoring_stats_if_enabled()

func _build_shadow_scoring_payload() -> Dictionary:
    var candidates = []
    var candidate_cap = max(1, int(EnemyAISettings.threaded_scoring_candidate_cap))
    var now_msec = int(Time.get_ticks_msec())
    var submit_frame = int(Engine.get_process_frames())
    var self_pos = global_position
    var forward = -global_transform.basis.z.normalized()

    if _can_target_player() and playerVisible:
        var player_pos = playerPosition
        var player_dist = self_pos.distance_to(player_pos)
        var player_dir = (player_pos - self_pos).normalized()
        candidates.append({
            "candidate_id": THREADED_SCORING_PLAYER_ID,
            "candidate_type": "player",
            "distance": player_dist,
            "forward_dot": forward.dot(player_dir),
            "is_visible": true
        })

    if candidates.size() < candidate_cap:
        for child in _get_active_agent_candidates():
            if !_is_valid_hostile_ai_target(child):
                continue

            var ai_pos = _get_ai_target_position(child)
            var ai_dist = self_pos.distance_to(ai_pos)
            var ai_dir = (ai_pos - self_pos).normalized()
            candidates.append({
                "candidate_id": int(child.get_instance_id()),
                "candidate_type": "ai",
                "distance": ai_dist,
                "forward_dot": forward.dot(ai_dir),
                "is_hostile": true,
                "is_visible": true,
                "audible": _target_is_audible(child, ai_dist),
                "shot_recent": _target_fired_recently(child)
            })
            if candidates.size() >= candidate_cap:
                break

    return {
        "job_id": _shadow_scoring_next_job_id,
        "submit_frame": submit_frame,
        "submit_time_msec": now_msec,
        "self_instance_id": int(get_instance_id()),
        "target_scan_max_distance": TARGET_SCAN_MAX_DISTANCE,
        "target_scan_min_dot": TARGET_SCAN_MIN_DOT,
        "top_k": max(1, int(EnemyAISettings.threaded_scoring_top_k)),
        "candidates": candidates
    }

func _shadow_scoring_worker(payload: Dictionary) -> Dictionary:
    var ranked = []
    var top_k = max(1, int(payload.get("top_k", 3)))
    var processed = 0
    var rejected_distance = 0
    var rejected_fov = 0
    var rejected_visibility = 0
    var rejected_type_gate = 0
    var max_distance = float(payload.get("target_scan_max_distance", TARGET_SCAN_MAX_DISTANCE))
    var min_dot = float(payload.get("target_scan_min_dot", TARGET_SCAN_MIN_DOT))

    for candidate in payload.get("candidates", []):
        processed += 1

        var candidate_type = str(candidate.get("candidate_type", "none"))
        var candidate_id = int(candidate.get("candidate_id", -1))
        var distance = float(candidate.get("distance", INF))
        var forward_dot = float(candidate.get("forward_dot", -1.0))
        var flags = []

        if distance > max_distance:
            rejected_distance += 1
            continue
        if forward_dot < min_dot:
            rejected_fov += 1
            continue

        var score = -1.0
        if candidate_type == "ai":
            if !bool(candidate.get("is_hostile", false)):
                rejected_type_gate += 1
                continue
            if !bool(candidate.get("is_visible", false)):
                rejected_visibility += 1
                continue
            score = 3.0 / (1.0 + distance)
            flags.append("hostile")
            flags.append("visible")
            if bool(candidate.get("audible", false)):
                flags.append("audible")
            if bool(candidate.get("shot_recent", false)):
                flags.append("shot_recent")
        elif candidate_type == "player":
            if !bool(candidate.get("is_visible", false)):
                rejected_visibility += 1
                continue
            score = 2.0 * absf(forward_dot) / (1.0 + distance)
            if score == 0.0:
                score = 0.1
            flags.append("player_visible")
        else:
            rejected_type_gate += 1
            continue

        ranked.append({
            "candidate_id": candidate_id,
            "candidate_type": candidate_type,
            "score": score,
            "distance": distance,
            "forward_dot": forward_dot,
            "reason_flags": flags
        })

    ranked.sort_custom(func(a, b): return float(a.get("score", -INF)) > float(b.get("score", -INF)))
    if ranked.size() > top_k:
        ranked = ranked.slice(0, top_k)

    return {
        "job_id": int(payload.get("job_id", -1)),
        "submit_frame": int(payload.get("submit_frame", -1)),
        "submit_time_msec": int(payload.get("submit_time_msec", 0)),
        "processed": processed,
        "ranked": ranked,
        "summary_flags": {
            "rejected_distance": rejected_distance,
            "rejected_fov": rejected_fov,
            "rejected_visibility": rejected_visibility,
            "rejected_type_gate": rejected_type_gate
        }
}

func _compare_shadow_scoring_with_authoritative(result: Dictionary):
    var ranked = result.get("ranked", [])
    if ranked.is_empty():
        return

    var top = ranked[0]
    var shadow_type = str(top.get("candidate_type", "none"))
    var shadow_id = int(top.get("candidate_id", -1))

    var authoritative_type = current_target_type
    var authoritative_id = -1
    if authoritative_type == "ai" and is_instance_valid(currentAITarget):
        authoritative_id = int(currentAITarget.get_instance_id())
    elif authoritative_type == "player":
        authoritative_id = THREADED_SCORING_PLAYER_ID

    if shadow_type != authoritative_type or shadow_id != authoritative_id:
        _trace_log(
            "shadow_target_mismatch",
            "Shadow mismatch self=%d job=%d frame=%d shadow=%s:%d authoritative=%s:%d" % [
                int(get_instance_id()),
                int(result.get("job_id", -1)),
                int(result.get("submit_frame", -1)),
                shadow_type,
                shadow_id,
                authoritative_type,
                authoritative_id
            ],
            TRACE_HOSTILITY_COOLDOWN
        )

func _log_shadow_scoring_stats_if_enabled():
    if !EnemyAISettings.show_threaded_scoring_stats:
        return
    DebugUtils._debug_log_rate_limited(
        "shadow_scoring_stats_%s" % str(get_instance_id()),
        "Shadow scoring stats submitted=%d completed=%d stale=%d in_flight=%s active_job=%d frame=%d submitted_at=%d" % [
            jobs_submitted,
            jobs_completed,
            jobs_dropped_stale,
            str(_shadow_scoring_job_in_flight),
            _shadow_scoring_active_job_id,
            _shadow_scoring_active_submit_frame,
            _shadow_scoring_active_submit_time_msec
        ],
        2.0
    )

func _clear_shadow_scoring_runtime_state(wait_for_in_flight_job: bool):
    if _shadow_scoring_thread != null and _shadow_scoring_job_in_flight:
        if wait_for_in_flight_job:
            _shadow_scoring_thread.wait_to_finish()
            _release_shadow_scoring_global_slot_if_needed()
            _shadow_scoring_thread = null
            _shadow_scoring_job_in_flight = false
        else:
            _shadow_scoring_latest_result = {}
            return
    else:
        _release_shadow_scoring_global_slot_if_needed()
        _shadow_scoring_thread = null
        _shadow_scoring_job_in_flight = false

    _shadow_scoring_active_job_id = 0
    _shadow_scoring_active_submit_frame = -1
    _shadow_scoring_active_submit_time_msec = 0
    _shadow_scoring_last_consumed_submit_frame = -1
    _shadow_scoring_latest_result = {}

func _on_tree_exited_shadow_scoring_cleanup():
    _clear_shadow_scoring_runtime_state(true)

func _current_target_refresh_cycle() -> float:
    var active_count = _active_ai_count()
    var base_cycle = targetRefreshCycle + targetRefreshJitter

    if active_count >= 64:
        base_cycle = 1.45 + targetRefreshJitter
    elif active_count >= 60:
        base_cycle = 1.36 + targetRefreshJitter
    elif active_count >= 56:
        base_cycle = 1.3 + targetRefreshJitter
    elif active_count >= 52:
        base_cycle = 1.22 + targetRefreshJitter
    elif active_count >= 48:
        base_cycle = 1.15 + targetRefreshJitter
    elif active_count >= 45:
        base_cycle = 1.08 + targetRefreshJitter
    elif active_count >= 40:
        base_cycle = 1.0 + targetRefreshJitter
    elif active_count >= 32:
        base_cycle = 0.82 + targetRefreshJitter
    elif active_count >= 24:
        base_cycle = 0.58 + targetRefreshJitter

    if _has_stable_visible_ai_target():
        return max(0.52, base_cycle * 1.55)
    if !_has_valid_ai_target():
        return base_cycle * 1.25

    return base_cycle

func _current_target_visibility_cycle() -> float:
    var active_count = _active_ai_count()
    var base_cycle = 0.14 + targetVisibilityJitter

    if active_count >= 64:
        base_cycle = 0.42 + targetVisibilityJitter
    elif active_count >= 60:
        base_cycle = 0.38 + targetVisibilityJitter
    elif active_count >= 56:
        base_cycle = 0.35 + targetVisibilityJitter
    elif active_count >= 52:
        base_cycle = 0.32 + targetVisibilityJitter
    elif active_count >= 48:
        base_cycle = 0.29 + targetVisibilityJitter
    elif active_count >= 45:
        base_cycle = 0.265 + targetVisibilityJitter
    elif active_count >= 40:
        base_cycle = 0.24 + targetVisibilityJitter
    elif active_count >= 32:
        base_cycle = 0.18 + targetVisibilityJitter
    elif active_count >= 24:
        base_cycle = 0.12 + targetVisibilityJitter

    if _has_valid_ai_target():
        if currentAITargetDistance > 90.0:
            return base_cycle * 1.6
        if currentAITargetDistance > 50.0:
            return base_cycle * 1.35
        if currentAITargetDistance < 20.0:
            return max(0.16, base_cycle * 1.05)

    return base_cycle

func _current_ai_audio_cycle() -> float:
    var active_count = _active_ai_count()

    if active_count >= 64:
        return 1.35 + aiAudioSenseJitter
    if active_count >= 60:
        return 1.25 + aiAudioSenseJitter
    if active_count >= 56:
        return 1.15 + aiAudioSenseJitter
    if active_count >= 52:
        return 1.05 + aiAudioSenseJitter
    if active_count >= 48:
        return 0.95 + aiAudioSenseJitter
    if active_count >= 45:
        return 0.9 + aiAudioSenseJitter
    if active_count >= 40:
        return 0.85 + aiAudioSenseJitter
    if active_count >= 32:
        return 0.65 + aiAudioSenseJitter
    if active_count >= 24:
        return 0.45 + aiAudioSenseJitter

    return 0.25 + aiAudioSenseJitter

func _active_ai_count() -> int:
    if is_instance_valid(AISpawner):
        return int(AISpawner.activeAgents)
    return 0

func _sense_ai_audio():
    var audible_target = _find_audible_hostile_target()
    if !is_instance_valid(audible_target):
        return

    currentAITarget = audible_target
    current_target_type = "ai"
    current_target_quality = QualityTier.AUDIO
    var reason = _get_audible_target_reason(audible_target)
    var audio_type = "audio_ai_unknown" if reason == "" else "audio_ai_" + reason.to_lower()
    _broadcast_target_to_teammates(_get_ai_target_position(audible_target), audio_type, audible_target, QualityTier.AUDIO)
    currentAITargetDistance = global_position.distance_to(audible_target.global_position)
    currentAITargetVisible = false
    _last_known_location_data = {"position": _get_ai_target_position(audible_target), "timestamp": Time.get_ticks_msec() / 1000.0, "quality": QualityTier.AUDIO}
    lastKnownLocation = _last_known_location_data.position

    if reason == "":
        reason = "AI sound"

    targetLabel = "%s %.1fm %s" % [_self_or_target_faction_name(audible_target), currentAITargetDistance, _quality_tier_to_string(QualityTier.AUDIO)]

    if currentState == State.Wander or currentState == State.Guard or currentState == State.Patrol:
        Decision()
    elif currentState == State.Ambush or currentState == State.Return:
        ChangeState("Combat")

    if lastAISoundTarget != audible_target or lastAISoundReason != reason:
        DebugUtils._debug_log_ai_audio("ai_audio_%s" % reason.to_lower().replace(" ", "_"), "AI audio tracked target=%s reason=%s distance=%.1f" % [targetLabel, reason, currentAITargetDistance])

    lastAISoundTarget = audible_target
    lastAISoundReason = reason

func _find_audible_hostile_target() -> Node3D:
    if !is_instance_valid(AISpawner) or !is_instance_valid(AISpawner.agents):
        return null

    var nearest_target: Node3D = null
    var nearest_distance = 9999.0

    for child in _get_active_agent_candidates():
        if !_is_valid_hostile_ai_target(child):
            continue

        var distance_to_target = global_position.distance_to(child.global_position)
        if !_target_is_audible(child, distance_to_target):
            continue

        if distance_to_target < nearest_distance:
            nearest_distance = distance_to_target
            nearest_target = child

    return nearest_target

func _target_is_audible(target_node: Node3D, distance_to_target: float) -> bool:
    var hearing_multiplier = max(0.1, EnemyAISettings.ai_hearing_multiplier)
    var movement_speed = float(target_node.get("movementSpeed"))
    var running_distance = AI_HEARING_RUN_DISTANCE * hearing_multiplier
    var walking_distance = AI_HEARING_WALK_DISTANCE * hearing_multiplier
    var gunshot_distance = AI_HEARING_GUNSHOT_DISTANCE * hearing_multiplier

    if _target_fired_recently(target_node) and distance_to_target <= gunshot_distance:
        return true

    if movement_speed >= 2.0 and distance_to_target <= running_distance:
        return true

    if movement_speed > 0.15 and distance_to_target <= walking_distance:
        return true

    return false

func _get_audible_target_reason(target_node: Node3D) -> String:
    if _target_fired_recently(target_node):
        return "Gunshot"

    var movement_speed = float(target_node.get("movementSpeed"))
    if movement_speed >= 2.0:
        return "Running"
    if movement_speed > 0.15:
        return "Walking"

    return ""

func _target_fired_recently(target_node: Node3D) -> bool:
    if !is_instance_valid(target_node):
        return false
    if !target_node.has_meta("enemy_ai_last_shot_time"):
        return false

    var shot_time = float(target_node.get_meta("enemy_ai_last_shot_time"))
    var now = float(Time.get_ticks_msec()) / 1000.0
    return now - shot_time <= AI_GUNSHOT_MEMORY_TIME

func _mark_ai_gunshot():
    set_meta("enemy_ai_last_shot_time", float(Time.get_ticks_msec()) / 1000.0)

func _acquire_best_target():
    var self_pos = global_position
    var forward = -global_transform.basis.z.normalized()
    var max_distance_sq = TARGET_SCAN_MAX_DISTANCE * TARGET_SCAN_MAX_DISTANCE
    var best_ai_node: Node3D = null
    var best_ai_position = Vector3.ZERO
    var best_ai_distance_sq = INF
    var best_ai_distance = INF
    var scanned_ai = 0
    var hostile_candidates = 0
    var los_blocked_candidates = 0
    var visible_hostile_candidates = 0
    var local_agents = -1

    if is_instance_valid(AISpawner) and is_instance_valid(AISpawner.agents):
        local_agents = AISpawner.agents.get_child_count()
        for child in _get_active_agent_candidates():
            scanned_ai += 1
            if !_is_valid_hostile_ai_target(child):
                continue
            hostile_candidates += 1

            var ai_pos = _get_ai_target_position(child)
            var to_ai = ai_pos - self_pos
            var ai_dist_sq = to_ai.length_squared()
            if ai_dist_sq > max_distance_sq:
                continue
            if ai_dist_sq >= best_ai_distance_sq:
                continue

            var ai_dist = sqrt(ai_dist_sq)
            var ai_dir = to_ai / max(ai_dist, 0.001)
            if forward.dot(ai_dir) < TARGET_SCAN_MIN_DOT:
                continue

            if !_can_see_ai_target(child):
                los_blocked_candidates += 1
                continue

            visible_hostile_candidates += 1
            if ai_dist < best_ai_distance:
                best_ai_distance_sq = ai_dist_sq
                best_ai_position = ai_pos
                best_ai_distance = ai_dist
                best_ai_node = child

    var best_type = ""
    var best_position = Vector3.ZERO
    var best_distance = 0.0
    var best_node: Node3D = null
    var best_score = -1.0

    if is_instance_valid(best_ai_node):
        best_type = "ai"
        best_position = best_ai_position
        best_distance = best_ai_distance
        best_node = best_ai_node
        best_score = 3.0 / (1.0 + best_ai_distance)
    elif _can_target_player() and playerVisible:
        var player_pos = playerPosition
        var player_dist = self_pos.distance_to(player_pos)
        var player_dir = (player_pos - self_pos).normalized()
        var player_score = 2.0 * absf(forward.dot(player_dir)) / (1.0 + player_dist)
        if player_score == 0.0:
            player_score = 0.1
        best_score = player_score
        best_type = "player"
        best_position = player_pos
        best_distance = player_dist

    if best_type == "":
        if TRACE_VERBOSE:
            _trace_log(
                "acquire_empty",
                "Acquire empty faction=%s team=%d local_agents=%d scanned=%d hostile=%d los_blocked=%d visible_hostile=%d player_visible=%s" % [
                    _self_faction(),
                    _self_team_id(),
                    local_agents,
                    scanned_ai,
                    hostile_candidates,
                    los_blocked_candidates,
                    visible_hostile_candidates,
                    str(playerVisible)
                ],
                8.0
            )
        return null

    if current_target_type == "ai" and _has_valid_ai_target() and currentAITargetVisible and best_type == "ai":
        var is_same_visible_target = best_node == currentAITarget
        var is_closest_visual_audio_priority = best_distance <= TARGET_PRIORITY_DISTANCE and _target_is_audible(best_node, best_distance)
        if is_same_visible_target:
            _trace_log(
                "lock_seen_target_same",
                "Seen target lock kept target=%s dist=%.1f local_agents=%d visible_hostile=%d" % [
                    targetLabel,
                    currentAITargetDistance,
                    local_agents,
                    visible_hostile_candidates
                ]
            )
            return null
        if !is_closest_visual_audio_priority:
            _trace_log(
                "lock_seen_target_priority",
                "Seen target lock blocked switch old_type=%s new_type=%s old_score=%.4f new_score=%.4f nearest_dist=%.1f local_agents=%d visible_hostile=%d" % [
                    current_target_type,
                    best_type,
                    current_target_score,
                    best_score,
                    best_distance,
                    local_agents,
                    visible_hostile_candidates
                ]
            )
            return null

    current_target_score = best_score

    if best_type == "player":
        var was_player_target = current_target_type == "player"
        _clear_ai_target()
        current_target_type = "player"
        current_target_quality = QualityTier.VISUAL
        playerVisible = true
        _last_known_location_data = {"position": best_position, "timestamp": Time.get_ticks_msec() / 1000.0, "quality": QualityTier.VISUAL}
        lastKnownLocation = best_position
        targetLabel = "Player %.1fm %s" % [best_distance, _quality_tier_to_string(QualityTier.VISUAL)]
        if !was_player_target:
            DebugUtils._debug_log_rate_limited(
                "player_target_acquired_%s" % str(get_instance_id()),
                "AI %s: Acquired PLAYER target (dist=%.1f score=%.3f)" % [_self_faction(), best_distance, best_score],
                1.5
            )
            _broadcast_target_to_teammates(best_position, "player", null, QualityTier.VISUAL)
        if best_distance < TARGET_PRIORITY_DISTANCE:
            is_close_visual_target = true
        return "player"
    else:
        var other_team_id = _target_team_id(best_node)
        _trace_log(
            "choose_ai",
            "Choose AI self=%s(team=%d) target=%s(team=%d) score=%.4f dist=%.1f local_agents=%d visible_hostile=%d" % [
                _self_faction(),
                _self_team_id(),
                _self_or_target_faction_name(best_node),
                other_team_id,
                best_score,
                best_distance,
                local_agents,
                visible_hostile_candidates
            ]
        )
        currentAITarget = best_node
        current_target_type = "ai"
        current_target_quality = QualityTier.VISUAL
        _update_target_visibility()
        _set_target_label()
        var ai_faction = best_node.get_meta("enemy_ai_faction", "Unknown")
        DebugUtils._debug_log_rate_limited("ai_target_acquired", "AI %s: Acquired AI %s target (dist=%.1f score=%.3f)" % [_self_faction(), ai_faction, best_distance, best_score], 1.0)
        _broadcast_target_to_teammates(best_position, "ai", best_node, QualityTier.VISUAL)
        if best_distance < TARGET_PRIORITY_DISTANCE:
            is_close_visual_target = true
        return best_node

func _is_valid_hostile_ai_target(node) -> bool:
    if !is_instance_valid(node):
        return false
    if node == self:
        return false
    if !node.has_method("WeaponDamage"):
        return false
    if bool(node.get("dead")):
        return false
    if bool(node.get("pause")):
        return false
    if !node.has_meta("enemy_ai_faction"):
        return false

    return _is_hostile_faction(_self_faction(), str(node.get_meta("enemy_ai_faction")), node)

func _is_hostile_faction(self_faction: String, other_faction: String, other_node: Node3D = null) -> bool:
    self_faction = _normalize_faction_name(self_faction)
    other_faction = _normalize_faction_name(other_faction)
    var self_team_id = _self_team_id()
    var other_team_id = _target_team_id(other_node)

    if other_faction == "" or other_faction == "Unknown":
        if TRACE_VERBOSE:
            _trace_log(
                "hostility_unknown_faction",
                "Reject hostile target: unknown other faction self=%s(team=%d) other_team=%d" % [
                    self_faction,
                    self_team_id,
                    other_team_id
                ],
                TRACE_HOSTILITY_COOLDOWN
            )
        return false

    if _is_hostile_team_target(other_node):
        return true

    if self_faction == other_faction:
        var same_faction_allowed = _same_faction_targeting_allowed(self_faction, other_node)
        if !same_faction_allowed and TRACE_VERBOSE:
            _trace_log(
                "hostility_same_faction_block",
                "Reject same-team target faction=%s self_team=%d other_team=%d infight(B/G/M)=%s/%s/%s" % [
                    self_faction,
                    self_team_id,
                    other_team_id,
                    str(EnemyAISettings.bandit_infighting_enabled),
                    str(EnemyAISettings.guard_infighting_enabled),
                    str(EnemyAISettings.military_infighting_enabled)
                ],
                TRACE_HOSTILITY_COOLDOWN
            )
        return same_faction_allowed

    if !_faction_warfare_active():
        _trace_log(
            "hostility_warfare_off",
            "Reject cross-faction target self=%s(team=%d) other=%s(team=%d) warfare=%s" % [
                self_faction,
                self_team_id,
                other_faction,
                other_team_id,
                str(EnemyAISettings.warfare_enabled)
            ],
            TRACE_HOSTILITY_COOLDOWN
        )
        return false

    return _is_supported_warfare_faction(self_faction) and _is_supported_warfare_faction(other_faction)

func _same_faction_targeting_allowed(faction: String, other_node: Node3D = null) -> bool:
    if !_same_faction_infighting_enabled(faction):
        return false
    return _is_hostile_team_for_infighting(other_node)

func _same_faction_infighting_enabled(faction: String) -> bool:
    match faction:
        "Bandit":
            return EnemyAISettings.bandit_infighting_enabled
        "Guard":
            return EnemyAISettings.guard_infighting_enabled
        "Military":
            return EnemyAISettings.military_infighting_enabled
        _:
            return false

func _is_hostile_team_for_infighting(other_node: Node3D = null) -> bool:
    if !is_instance_valid(other_node):
        return true

    var self_team_id = _self_team_id()
    var other_team_id = _target_team_id(other_node)

    if self_team_id < 0 or other_team_id < 0:
        return true

    return self_team_id != other_team_id

func _is_hostile_team_target(other_node: Node3D = null) -> bool:
    if !is_instance_valid(other_node):
        return false

    var self_team_id = _self_team_id()
    var other_team_id = _target_team_id(other_node)
    if self_team_id < 0 or other_team_id < 0:
        return false

    return self_team_id != other_team_id

func _self_team_id() -> int:
    if has_meta("team_id"):
        return int(get_meta("team_id"))
    return -1

func _target_team_id(target_node: Node3D) -> int:
    if !is_instance_valid(target_node):
        return -1
    if !target_node.has_meta("team_id"):
        return -1
    return int(target_node.get_meta("team_id"))

func _is_supported_warfare_faction(faction: String) -> bool:
    faction = _normalize_faction_name(faction)
    return faction == "Bandit" or faction == "Guard" or faction == "Military"

func _normalize_faction_name(faction: String) -> String:
    match faction.to_lower():
        "bandit":
            return "Bandit"
        "guard":
            return "Guard"
        "military":
            return "Military"
        "punisher":
            return "Punisher"
        _:
            return faction

func _is_valid_teammate_target(target_position: Vector3, target_type: String, target_node: Node3D = null) -> bool:
    var distance_sq = global_position.distance_squared_to(target_position)

    if target_type == "ai" or target_type in ["audio_ai_gunshot", "audio_ai_running", "audio_ai_walking", "audio_ai_unknown"]:
        if target_node == null:
            return false
        if !_is_valid_hostile_ai_target(target_node):
            return false
        return distance_sq <= TEAMMATE_TARGET_VALID_DISTANCE_SQ
    elif target_type == "player" or target_type in ["audio_player_running", "audio_player_walking", "audio_player_gunshot"]:
        if gameData.isDead:
            return false
        if !_can_target_player():
            return false
        return distance_sq <= TEAMMATE_TARGET_VALID_DISTANCE_SQ
    else:
        return false

func _update_target_visibility():
    if _has_valid_ai_target():
        currentAITargetDistance = global_position.distance_to(currentAITarget.global_position)
        currentAITargetVisible = _can_see_ai_target(currentAITarget)
        _set_target_label()
        previousAITargetVisible = currentAITargetVisible

        if currentAITargetVisible:
            _last_known_location_data = {"position": _get_ai_target_position(), "timestamp": Time.get_ticks_msec() / 1000.0, "quality": QualityTier.VISUAL}
            if current_target_quality > QualityTier.VISUAL:
                current_target_quality = QualityTier.VISUAL
                _set_target_label()
                _broadcast_target_to_teammates(_get_ai_target_position(), "ai", currentAITarget, QualityTier.VISUAL)
                DebugUtils._debug_log("Upgraded AI target quality to VISUAL for %s" % targetLabel)
            if currentAITargetDistance < 25:
                is_close_visual_target = true
            else:
                is_close_visual_target = false
        else:
            is_close_visual_target = false
    else:
        currentAITargetVisible = false
        currentAITargetDistance = 9999.0
        targetLabel = "None"
        previousAITargetVisible = false
        is_close_visual_target = false

func _can_see_ai_target(target_node: Node3D) -> bool:
    if !is_instance_valid(target_node):
        return false

    var target_position = _get_ai_target_position(target_node)
    var sight_multiplier = max(0.1, EnemyAISettings.ai_sight_multiplier)
    var sight_range = 200.0 * sight_multiplier

    if gameData.TOD == 4 and !gameData.flashlight and !boss:
        sight_range = (25 + extraVisibility) * sight_multiplier
    elif gameData.fog and !boss:
        sight_range = (100 + extraVisibility) * sight_multiplier

    if LOS.global_position.distance_squared_to(target_position) > sight_range * sight_range:
        return false

    LOS.target_position = Vector3(0, 0, sight_range)

    LOS.look_at(target_position, Vector3.UP, true)
    LOS.force_raycast_update()

    if !LOS.is_colliding():
        return false

    var collider = LOS.get_collider()
    if collider == target_node:
        return true
    if collider is Hitbox and collider.owner == target_node:
        return true

    return false

func _has_valid_ai_target() -> bool:
    return _is_valid_hostile_ai_target(currentAITarget)

func _has_stable_visible_ai_target() -> bool:
    return _has_valid_ai_target() and currentAITargetVisible

func _get_ai_target_position(target_node = null) -> Vector3:
    if target_node == null:
        target_node = currentAITarget

    if !is_instance_valid(target_node):
        return playerPosition

    var torsoPosition = _get_ai_torso_position(target_node)
    if torsoPosition != Vector3.ZERO:
        return torsoPosition

    var targetHead = target_node.get("head")
    if targetHead is Node3D:
        return targetHead.global_position + Vector3(0, -0.35, 0)

    var targetEyes = target_node.get("eyes")
    if targetEyes is Node3D:
        return targetEyes.global_position + Vector3(0, -0.6, 0)

    return target_node.global_position + Vector3(0, 0.8, 0)

func _get_fire_target_position() -> Vector3:
    if current_target_type == "ai" and _has_valid_ai_target():
        var torsoPosition = _get_ai_torso_position()
        if torsoPosition != Vector3.ZERO:
            return torsoPosition

    return _get_engagement_position() + Vector3(0, 1.0, 0)

func _get_spine_target_position() -> Vector3:
    if current_target_type == "ai" and _has_valid_ai_target():
        var spineTorsoPosition = _get_ai_spine_torso_position()
        if spineTorsoPosition != Vector3.ZERO:
            return spineTorsoPosition

        return currentAITarget.global_position + Vector3(0, 1.0, 0)

    return _get_engagement_position()

func _get_ai_torso_position(target_node = null) -> Vector3:
    if target_node == null:
        target_node = currentAITarget

    if !is_instance_valid(target_node):
        return Vector3.ZERO

    var targetChest = target_node.get("chest")
    if targetChest is Node3D:
        return targetChest.global_position + Vector3(0, -0.25, 0)

    return Vector3.ZERO

func _get_ai_spine_torso_position(target_node = null) -> Vector3:
    if target_node == null:
        target_node = currentAITarget

    if !is_instance_valid(target_node):
        return Vector3.ZERO

    var targetChest = target_node.get("chest")
    if targetChest is Node3D:
        return targetChest.global_position

    var targetHead = target_node.get("head")
    if targetHead is Node3D:
        return targetHead.global_position + Vector3(0, -0.6, 0)

    return target_node.global_position + Vector3(0, 1.0, 0)

func _is_ai_root_hit(hitCollider) -> bool:
    if !is_instance_valid(hitCollider):
        return false
    if hitCollider == self:
        return false
    if !hitCollider.has_method("WeaponDamage"):
        return false
    if !hitCollider.has_meta("enemy_ai_faction"):
        return false
    return _is_valid_hostile_ai_target(hitCollider)

func _get_engagement_position() -> Vector3:
    if current_target_type == "player":
        return _last_known_location_data.position if _is_last_known_location_valid() else playerPosition
    elif _has_valid_ai_target():
        return _get_ai_target_position()
    return playerPosition

func _get_engagement_distance() -> float:
    if current_target_type == "player":
        return playerDistance3D
    elif _has_valid_ai_target():
        return currentAITargetDistance
    return playerDistance3D

func _engagement_visible() -> bool:
    if current_target_type == "player":
        return playerVisible
    elif _has_valid_ai_target():
        return currentAITargetVisible
    return playerVisible

func _can_direct_attack_target() -> bool:
    if current_target_type == "ai" and _has_valid_ai_target():
        return true
    return !gameData.isTrading

func _player_only_combat_blocked() -> bool:
    if current_target_type == "ai" and _has_valid_ai_target():
        return false
    return gameData.isTrading

func _should_play_player_bullet_audio() -> bool:
    return current_target_type == "player" or _can_target_player()

func _clear_ai_target(push_status: bool = true):
    currentAITarget = null
    currentAITargetVisible = false
    currentAITargetDistance = 9999.0
    targetLabel = "None"
    previousAITargetVisible = false
    current_target_type = "none"
    current_target_score = 0.0
    current_target_quality = QualityTier.SECOND_HAND
    is_close_visual_target = false

    if push_status:
        _push_debug_status("No active hostile target")

func _set_target_label():
    if current_target_type == "player":
        targetLabel = "Player %.1fm %s" % [playerDistance3D, _quality_tier_to_string(current_target_quality)]
    elif _has_valid_ai_target():
        targetLabel = "%s %.1fm %s" % [_self_or_target_faction_name(currentAITarget), currentAITargetDistance, _quality_tier_to_string(current_target_quality)]
    else:
        targetLabel = "None"

func _self_or_target_faction_name(target_node: Node3D) -> String:
    if is_instance_valid(target_node) and target_node.has_meta("enemy_ai_faction"):
        return str(target_node.get_meta("enemy_ai_faction"))
    return "Unknown"

func _push_debug_status(event_text: String):
    if !EnemyAISettings.show_debug_overlay and !EnemyAISettings.show_debug_logs:
        return
    var now_seconds = Time.get_ticks_msec() / 1000.0
    var same_event = event_text == _last_debug_status_event
    var same_target = targetLabel == _last_debug_status_target
    if same_event and same_target and now_seconds - _last_debug_status_push_time < 0.25:
        return

    var debug_main = get_node_or_null("/root/EnemyAIMain")
    if debug_main:
        _last_debug_status_push_time = now_seconds
        _last_debug_status_event = event_text
        _last_debug_status_target = targetLabel
        debug_main.update_status(AISpawner.activeAgents, {
            "last_event": event_text,
            "current_target": targetLabel
        })

func _shot_damage() -> float:
    var damage = weaponData.damage
    if boss:
        damage *= 2.0
    return damage

func _apply_damage_to_hitbox(hitbox: Hitbox, damage: float):
    var hitOwner = hitbox.owner
    var ownerLabel = "Unknown"
    if is_instance_valid(hitOwner):
        if hitOwner.has_meta("enemy_ai_faction"):
            ownerLabel = str(hitOwner.get_meta("enemy_ai_faction"))
        else:
            ownerLabel = hitOwner.name
    DebugUtils._debug_log("Shot landed on Hitbox type=%s owner=%s damage=%.1f target=%s" % [str(hitbox.type), ownerLabel, damage, targetLabel])
    hitbox.ApplyDamage(damage)
    var debug_main = get_node_or_null("/root/EnemyAIMain")
    if debug_main:
        debug_main.record_hit(str(hitbox.type), false)

func _try_apply_targeted_hitbox_damage(hitCollider) -> bool:
    var space_state = get_world_3d().direct_space_state
    var shot_origin = muzzle.global_position
    var preferred_targets = _get_preferred_hit_targets(hitCollider)
    var fallbackHitbox: Hitbox = null

    for preferred_target in preferred_targets:
        var query = PhysicsRayQueryParameters3D.create(shot_origin, preferred_target)
        query.exclude = [self, hitCollider]
        var result = space_state.intersect_ray(query)

        if result.is_empty():
            continue

        var secondaryCollider = result["collider"]
        if secondaryCollider is Hitbox:
            if str(secondaryCollider.type) == "Torso":
                _apply_damage_to_hitbox(secondaryCollider, _shot_damage())
                return true
            if fallbackHitbox == null:
                fallbackHitbox = secondaryCollider

    if fallbackHitbox != null:
        _apply_damage_to_hitbox(fallbackHitbox, _shot_damage())
        return true

    return false

func Selector(delta):
    # Call base Selector logic first
    super(delta)
    var engagement_distance = _get_engagement_distance()
    var faction = _self_faction()
    var is_bandit_or_guard = faction == "Bandit" or faction == "Guard"

    if engagement_distance >= 50.0 and is_bandit_or_guard:
        if randf() < 0.45:
            fullAuto = true
        else:
            fullAuto = false
    elif engagement_distance >= 50.0:
        fullAuto = false
    # Bandit-specific full auto logic: increase chance when close (< 30 meters)
    elif faction == "Bandit" and engagement_distance < 30.0:
        # Higher chance of full auto for bandits in close range
        # Base chance is probably random, so we override with higher probability
        if randf() < 0.8:  # 80% chance of full auto when < 30m
            fullAuto = true
        else:
            fullAuto = false

func _get_preferred_hit_targets(hitCollider) -> Array:
    var targets: Array = []

    if is_instance_valid(hitCollider) and hitCollider == currentAITarget:
        var directTorso = _get_ai_torso_position(hitCollider)
        if directTorso != Vector3.ZERO:
            targets.append(directTorso)
        else:
            targets.append(_get_ai_target_position(hitCollider))

    if is_instance_valid(currentAITarget):
        var torso = _get_ai_torso_position(currentAITarget)
        if torso != Vector3.ZERO:
            targets.append(torso)

        var head = currentAITarget.get("head")
        if head is Node3D:
            targets.append(head.global_position + Vector3(0, -0.4, 0))

        var eyesNode = currentAITarget.get("eyes")
        if eyesNode is Node3D:
            targets.append(eyesNode.global_position + Vector3(0, -0.8, 0))

    targets.append(_get_fire_target_position())
    return targets

func _broadcast_target_to_teammates(target_position: Vector3, target_type: String, target_node: Node3D = null, quality: QualityTier = QualityTier.AUDIO):
    var is_player_target = target_type == "player" or target_type.begins_with("audio_player")
    var cooldown_timer = broadcastCooldownPlayer if is_player_target else broadcastCooldownAI
    if cooldown_timer > 0:
        return
    if _should_skip_duplicate_teammate_broadcast(target_position, target_type, target_node, quality):
        return
    if !is_instance_valid(AISpawner) or !is_instance_valid(AISpawner.agents):
        return

    var self_faction = _self_faction()

    if AISpawner.agents.get_child_count() > 64:
        return

    var teammates = _get_teammate_candidates(self_faction)
    for child in teammates:
        if child == self:
            continue
        if bool(child.get("dead")):
            continue
        if bool(child.get("pause")):
            continue
        if !child.has_meta("enemy_ai_faction") or _normalize_faction_name(str(child.get_meta("enemy_ai_faction"))) != self_faction:
            continue

        var distance_sq = global_position.distance_squared_to(child.global_position)
        if distance_sq > TEAMMATE_BROADCAST_RANGE_SQ:  # broadcast range
            continue

        # Inform the teammate
        if child.has_method("_receive_teammate_target_info"):
            child._receive_teammate_target_info(target_position, target_type, target_node, quality)

    if is_player_target:
        broadcastCooldownPlayer = 2.0
    else:
        broadcastCooldownAI = 2.0
    _record_teammate_broadcast(target_position, target_type, target_node, quality)

func _receive_teammate_target_info(target_position: Vector3, target_type: String, target_node: Node3D = null, quality: QualityTier = QualityTier.AUDIO):
    # Validate target before adopting
    if not _is_valid_teammate_target(target_position, target_type, target_node):
        return

    var is_gunshot = target_type in ["audio_player_gunshot", "audio_ai_gunshot"]
    var is_audio = target_type.begins_with("audio_")
    var is_player_target = target_type == "player" or target_type.begins_with("audio_player")
    var is_ai_target = target_type == "ai" or target_type.begins_with("audio_ai")
    var distance_sq = global_position.distance_squared_to(target_position)

    if is_player_target and playerVisible and current_target_type == "player":
        return
    if is_player_target and current_target_type == "player" and current_target_quality <= quality and _is_last_known_location_valid():
        if _last_known_location_data.position.distance_squared_to(target_position) < TEAMMATE_DUPLICATE_POSITION_EPSILON_SQ:
            return
    if is_ai_target and current_target_type == "ai" and current_target_quality <= quality and is_instance_valid(target_node):
        if currentAITarget == target_node:
            return

    _last_known_location_data = {"position": target_position, "timestamp": Time.get_ticks_msec() / 1000.0, "quality": quality}
    lastKnownLocation = target_position

    var should_switch = false
    if quality < current_target_quality:  # Higher quality (lower number) always accepted
        should_switch = true
    elif quality == current_target_quality:  # Same quality: use existing logic
        if is_gunshot:
            # High priority: switch even if engaged
            should_switch = true
        elif current_target_type == "none":
            # No current target
            should_switch = true
        elif _get_engagement_distance() > 50.0:
            # Own target far
            should_switch = true

    if should_switch:
        var distance = sqrt(distance_sq)
        if is_player_target:
            _clear_ai_target()
            current_target_type = "player"
            current_target_quality = quality
            if is_audio:
                targetLabel = "Player %.1fm (%s Q%d)" % [distance, target_type, quality]
            else:
                targetLabel = "Player (teammate info Q%d)" % quality
            playerVisible = false
        elif is_ai_target and is_instance_valid(target_node):
            currentAITarget = target_node
            current_target_type = "ai"
            current_target_quality = quality
            currentAITargetVisible = false
            currentAITargetDistance = distance
            if is_audio:
                targetLabel = "%s %.1fm (%s Q%d)" % [_self_or_target_faction_name(target_node), distance, target_type, quality]
            else:
                _set_target_label()

        # Trigger decision if needed
        if currentState == State.Wander or currentState == State.Guard or currentState == State.Patrol or (is_gunshot and (currentState == State.Ambush or currentState == State.Return)):
            if is_gunshot:
                ChangeState("Combat")
            else:
                var now_seconds = Time.get_ticks_msec() / 1000.0
                var decision_debounce = max(0.0, float(EnemyAISettings.teammate_decision_debounce_seconds))
                if now_seconds - _last_teammate_decision_time >= decision_debounce:
                    _last_teammate_decision_time = now_seconds
                    Decision()

func _count_teammates_targeting_same() -> int:
    if !is_instance_valid(AISpawner) or !is_instance_valid(AISpawner.agents):
        return 0
    if current_target_type == "none":
        return 0

    var self_faction = _self_faction()
    var count = 0

    var teammates = _get_teammate_candidates(self_faction)
    for child in teammates:
        if child == self:
            continue
        if bool(child.get("dead")):
            continue
        if bool(child.get("pause")):
            continue
        if !child.has_meta("enemy_ai_faction") or _normalize_faction_name(str(child.get_meta("enemy_ai_faction"))) != self_faction:
            continue

        var child_target_type = child.get("current_target_type")
        if child_target_type == current_target_type:
            if current_target_type == "player":
                count += 1
            elif current_target_type == "ai" and child.get("currentAITarget") == currentAITarget:
                count += 1

    return count
