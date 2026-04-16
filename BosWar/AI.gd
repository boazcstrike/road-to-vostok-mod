extends "res://Scripts/AI.gd"

var EnemyAISettings = preload("res://BosWar/EnemyAISettings.tres")
const DebugUtils = preload("res://BosWar/DebugUtils.gd")

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
var targetLabel = "None"
var previousAITargetVisible = false
var lastAISoundTarget: Node3D
var lastAISoundReason = ""
const AI_HEARING_RUN_DISTANCE = 22.0
const AI_HEARING_WALK_DISTANCE = 8.0
const AI_HEARING_GUNSHOT_DISTANCE = 60.0
const AI_GUNSHOT_MEMORY_TIME = 1.25
var current_target_type = "none"  # "player", "ai", or "none"
var current_target_score = 0.0

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

        if _custom_ai_targeting_active():
            _update_target_visibility()

            if !player_detected and _has_valid_ai_target() and currentAITargetVisible:
                lastKnownLocation = _get_ai_target_position()

                if currentState == State.Wander or currentState == State.Guard or currentState == State.Patrol:
                    Decision()
                elif currentState == State.Ambush:
                    ChangeState("Combat")

        if _custom_ai_targeting_active() and !_has_stable_visible_ai_target() and aiAudioSenseTimer <= 0.0:
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
        lastKnownLocation = playerPosition
        playerVisible = true
    else:
        playerVisible = false

func Hearing():
    if !_can_target_player():
        return

    var hearing_multiplier = max(0.1, EnemyAISettings.ai_hearing_multiplier)
    var run_distance = 20.0 * hearing_multiplier
    var walk_distance = 5.0 * hearing_multiplier

    if (playerDistance3D < run_distance and gameData.isRunning) or (playerDistance3D < walk_distance and gameData.isWalking):
        if currentState != State.Ambush:
            lastKnownLocation = playerPosition
            _broadcast_target_to_teammates(playerPosition, "audio_player")

func FireDetection(delta):
    if !_can_target_player():
        return

    fireDetectionTime = EnemyAISettings.ai_gunshot_alert_duration
    var hearing_multiplier = max(0.1, EnemyAISettings.ai_hearing_multiplier)
    var local_alert_distance = 50.0 * hearing_multiplier

    if gameData.isFiring and !playerVisible:
        if fireVector > 0.95:
            lastKnownLocation = playerPosition
            _broadcast_target_to_teammates(playerPosition, "audio_player")

            fireDetected = true
            extraVisibility = 50.0 * max(0.25, EnemyAISettings.ai_sight_multiplier)
        elif playerDistance3D < local_alert_distance:
            if currentState != State.Ambush:
                lastKnownLocation = playerPosition
                _broadcast_target_to_teammates(playerPosition, "audio_player")

            fireDetected = true
            extraVisibility = 50.0 * max(0.25, EnemyAISettings.ai_sight_multiplier)

    if fireDetected:
        fireDetectionTimer += delta

        if fireDetectionTimer > fireDetectionTime:
            extraVisibility = 0.0
            fireDetectionTimer = 0.0
            fireDetected = false

func Decision():
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
        elif decision == 2 and !AISpawner.noHiding:
            ChangeState("Hide")
        elif decision == 3:
            ChangeState("Cover")
        elif decision == 4:
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

func Fire(delta):
    if impact or _player_only_combat_blocked():
        return

    if LKL.distance_to(_get_engagement_position()) > 4.0:
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
            var impulseX = spineTarget.x - spineData.recoil / 10.0
            var impulseY = spineTarget.y
            var impulseZ = spineTarget.z
            impulseTarget = Vector3(impulseX, impulseY, impulseZ)
        else:
            var impulseX2 = spineTarget.x - spineData.recoil
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

    if weaponData.weaponAction == "Semi-Auto" and fullAuto:
        fireTime = weaponData.fireRate
    elif (weaponData.weaponAction == "Semi-Auto" or weaponData.weaponAction == "Semi") and !fullAuto:
        if engagement_distance < 10:
            fireTime = randf_range(0.1, 0.5)
        elif engagement_distance > 10 and engagement_distance < 50:
            fireTime = randf_range(0.1, 1.0)
        else:
            fireTime = randf_range(0.1, 4.0)
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
    var offset = Vector3(0, 0, 0)

    if fullAuto and !boss:
        spreadMultiplier = 2.0

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

        fireDirection.x += randf_range(-horizontalSpread, horizontalSpread) * spreadMultiplier / accuracy_multiplier
        fireDirection.y += randf_range(-verticalSpread, verticalSpread) * spreadMultiplier / accuracy_multiplier
    elif engagement_distance < 10 or boss:
        fireDirection.x += randf_range(-0.1, 0.1) * spreadMultiplier / accuracy_multiplier
        fireDirection.y += randf_range(-0.1, 0.1) * spreadMultiplier / accuracy_multiplier
    elif engagement_distance > 10 and engagement_distance < 50:
        fireDirection.x += randf_range(-1.0, 1.0) * spreadMultiplier / accuracy_multiplier
        fireDirection.y += randf_range(-1.0, 1.0) * spreadMultiplier / accuracy_multiplier
    else:
        fireDirection.x += randf_range(-2.0, 2.0) * spreadMultiplier / accuracy_multiplier
        fireDirection.y += randf_range(-2.0, 2.0) * spreadMultiplier / accuracy_multiplier

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
    MoveToPoint(lastKnownLocation)

func GetAttackWaypoint():
    MoveToPoint(lastKnownLocation)

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

func Death(direction, force):
    DebugUtils._debug_log("Death faction=%s target=%s" % [_self_faction(), targetLabel])
    super(direction, force)
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

    return _same_faction_infighting_active() or _faction_warfare_active()

func _same_faction_infighting_active() -> bool:
    return _same_faction_targeting_allowed(_self_faction())

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

    if !_has_valid_ai_target():
        targetLabel = "None"
        current_target_type = "none"
        current_target_score = 0.0

    DebugUtils._debug_log("Player alignment cleared hostility for faction=%s" % _self_faction())



func _self_faction() -> String:
    if has_meta("enemy_ai_faction"):
        return str(get_meta("enemy_ai_faction"))
    return "Unknown"

func _update_hostile_ai_targeting(delta):
    if !_custom_ai_targeting_active():
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

    if (current_target_type == "none" or !_has_valid_ai_target()) or targetRefreshTimer <= 0.0:
        var result = _acquire_best_target()
        targetRefreshTimer = current_refresh_cycle
        targetVisibilityTimer = 0.0

        if result != null:
            if current_target_type == "ai" and is_instance_valid(currentAITarget):
                DebugUtils._debug_log("Hostile target acquired: %s" % targetLabel)
                _push_debug_status("Hostile target acquired")

    if !_has_valid_ai_target():
        _update_target_visibility()
    else:
        currentAITargetDistance = global_position.distance_to(currentAITarget.global_position)
        _set_target_label()

        if targetVisibilityTimer <= 0.0:
            _update_target_visibility()
            targetVisibilityTimer = current_visibility_cycle

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
        return max(0.25, base_cycle * 0.72)
    if !_has_valid_ai_target():
        return base_cycle * 1.25

    return base_cycle

func _current_target_visibility_cycle() -> float:
    var active_count = _active_ai_count()
    var base_cycle = 0.08 + targetVisibilityJitter

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
            return max(0.05, base_cycle * 0.8)

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
    _broadcast_target_to_teammates(_get_ai_target_position(audible_target), "audio_ai", audible_target)
    currentAITargetDistance = global_position.distance_to(audible_target.global_position)
    currentAITargetVisible = false
    lastKnownLocation = _get_ai_target_position(audible_target)

    var reason = _get_audible_target_reason(audible_target)
    if reason == "":
        reason = "AI sound"

    targetLabel = "%s %.1fm" % [_self_or_target_faction_name(audible_target), currentAITargetDistance]

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

    for child in AISpawner.agents.get_children():
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
    var candidates = []

    # Add player if can target and visible
    if _can_target_player() and playerVisible:
        var player_pos = playerPosition
        var player_dist = global_position.distance_to(player_pos)
        candidates.append({"type": "player", "position": player_pos, "distance": player_dist, "visible": true})

    # Add hostile AI if visible
    if is_instance_valid(AISpawner) and is_instance_valid(AISpawner.agents):
        for child in AISpawner.agents.get_children():
            if _is_valid_hostile_ai_target(child) and _can_see_ai_target(child):
                var ai_pos = _get_ai_target_position(child)
                var ai_dist = global_position.distance_to(ai_pos)
                candidates.append({"type": "ai", "node": child, "position": ai_pos, "distance": ai_dist, "visible": true})

    if candidates.size() == 0:
        return null

    # Calculate scores
    var forward = -global_transform.basis.z.normalized()
    var best_candidate = null
    var best_score = -1.0

    for candidate in candidates:
        var dir_to_target = (candidate.position - global_position).normalized()
        var angle = acos(clamp(forward.dot(dir_to_target), -1.0, 1.0))
        var visibility_bonus = 2.0 if candidate.visible else 1.0
        var ai_bonus = 1.0 if candidate.type == "ai" else 0.0
        var score = (visibility_bonus + ai_bonus) * cos(angle) / (1.0 + candidate.distance)

        if score > best_score:
            best_score = score
            best_candidate = candidate

    # Hysteresis: only switch if new score is 20% higher
    if current_target_type != "none" and best_score < current_target_score * 1.2:
        return null

    # Set new target
    current_target_score = best_score

    if best_candidate.type == "player":
        _clear_ai_target()
        current_target_type = "player"
        playerVisible = true
        lastKnownLocation = best_candidate.position
        targetLabel = "Player %.1fm" % best_candidate.distance
        DebugUtils._debug_log("AI %s: Acquired PLAYER target (dist=%.1f score=%.3f)" % [_self_faction(), best_candidate.distance, best_score])
        _broadcast_target_to_teammates(best_candidate.position, best_candidate.type)
        return "player"
    else:
        currentAITarget = best_candidate.node
        current_target_type = "ai"
        _update_target_visibility()
        _set_target_label()
        var ai_faction = best_candidate.node.get_meta("enemy_ai_faction", "Unknown")
        DebugUtils._debug_log("AI %s: Acquired AI %s target (dist=%.1f score=%.3f)" % [_self_faction(), ai_faction, best_candidate.distance, best_score])
        _broadcast_target_to_teammates(best_candidate.position, best_candidate.type, best_candidate.node)
        return best_candidate.node

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

    return _is_hostile_faction(_self_faction(), str(node.get_meta("enemy_ai_faction")))

func _is_hostile_faction(self_faction: String, other_faction: String) -> bool:
    if other_faction == "" or other_faction == "Unknown":
        return false

    if self_faction == other_faction:
        return _same_faction_targeting_allowed(self_faction)

    if !_faction_warfare_active():
        return false

    return _is_supported_warfare_faction(self_faction) and _is_supported_warfare_faction(other_faction)

func _same_faction_targeting_allowed(faction: String) -> bool:
    match faction:
        "Bandit":
            return EnemyAISettings.bandit_infighting_enabled
        "Guard":
            return EnemyAISettings.guard_infighting_enabled
        "Military":
            return EnemyAISettings.military_infighting_enabled
        _:
            return false

func _is_supported_warfare_faction(faction: String) -> bool:
    return faction == "Bandit" or faction == "Guard" or faction == "Military"

func _update_target_visibility():
    if _has_valid_ai_target():
        currentAITargetDistance = global_position.distance_to(currentAITarget.global_position)
        currentAITargetVisible = _can_see_ai_target(currentAITarget)
        _set_target_label()
        previousAITargetVisible = currentAITargetVisible

        if currentAITargetVisible:
            lastKnownLocation = _get_ai_target_position()
    else:
        currentAITargetVisible = false
        currentAITargetDistance = 9999.0
        targetLabel = "None"
        previousAITargetVisible = false

func _can_see_ai_target(target_node: Node3D) -> bool:
    if !is_instance_valid(target_node):
        return false

    var target_position = _get_ai_target_position(target_node)
    var sight_multiplier = max(0.1, EnemyAISettings.ai_sight_multiplier)

    if gameData.TOD == 4 and !gameData.flashlight and !boss:
        LOS.target_position = Vector3(0, 0, (25 + extraVisibility) * sight_multiplier)
    elif gameData.fog and !boss:
        LOS.target_position = Vector3(0, 0, (100 + extraVisibility) * sight_multiplier)
    else:
        LOS.target_position = Vector3(0, 0, 200 * sight_multiplier)

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
        return lastKnownLocation
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

    if push_status:
        _push_debug_status("No active hostile target")

func _set_target_label():
    if current_target_type == "player":
        targetLabel = "Player %.1fm" % playerDistance3D
    elif _has_valid_ai_target():
        targetLabel = "%s %.1fm" % [_self_or_target_faction_name(currentAITarget), currentAITargetDistance]
    else:
        targetLabel = "None"

func _self_or_target_faction_name(target_node: Node3D) -> String:
    if is_instance_valid(target_node) and target_node.has_meta("enemy_ai_faction"):
        return str(target_node.get_meta("enemy_ai_faction"))
    return "Unknown"

func _push_debug_status(event_text: String):
    var debug_main = get_node_or_null("/root/EnemyAIMain")
    if debug_main:
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

    # Bandit-specific full auto logic: increase chance when close (< 30 meters)
    if _self_faction() == "bandit" and _get_engagement_distance() < 30.0:
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

func _broadcast_target_to_teammates(target_position: Vector3, target_type: String, target_node: Node3D = null):
    if !is_instance_valid(AISpawner) or !is_instance_valid(AISpawner.agents):
        return

    var self_faction = _self_faction()

    for child in AISpawner.agents.get_children():
        if child == self:
            continue
        if !child.has_meta("enemy_ai_faction") or str(child.get_meta("enemy_ai_faction")) != self_faction:
            continue

        var distance = global_position.distance_to(child.global_position)
        if distance > 50.0:  # broadcast range
            continue

        # Inform the teammate
        if child.has_method("_receive_teammate_target_info"):
            child._receive_teammate_target_info(target_position, target_type, target_node)

func _receive_teammate_target_info(target_position: Vector3, target_type: String, target_node: Node3D = null):
    # Update lastKnownLocation
    lastKnownLocation = target_position

    # If no current target, try to acquire this one
    if current_target_type == "none":
        if target_type == "player" or target_type == "audio_player":
            current_target_type = "player"
            targetLabel = "Player (teammate info)"
            playerVisible = false  # since it's from teammate
        elif target_type == "ai" and is_instance_valid(target_node):
            currentAITarget = target_node
            current_target_type = "ai"
            _update_target_visibility()
            _set_target_label()
        elif target_type == "audio_ai" and is_instance_valid(target_node):
            currentAITarget = target_node
            current_target_type = "ai"
            currentAITargetVisible = false
            _set_target_label()

        # Maybe trigger decision if in passive state
        if currentState == State.Wander or currentState == State.Guard or currentState == State.Patrol:
            Decision()
    # If has own engagement but it's far (>50m), switch to teammate's target
    elif _get_engagement_distance() > 50.0:
        if target_type == "player" or target_type == "audio_player":
            _clear_ai_target()
            current_target_type = "player"
            targetLabel = "Player (teammate info)"
            playerVisible = false
        elif target_type == "ai" and is_instance_valid(target_node):
            currentAITarget = target_node
            current_target_type = "ai"
            _update_target_visibility()
            _set_target_label()
        elif target_type == "audio_ai" and is_instance_valid(target_node):
            currentAITarget = target_node
            current_target_type = "ai"
            currentAITargetVisible = false
            _set_target_label()

        # Trigger decision if needed
        if currentState == State.Wander or currentState == State.Guard or currentState == State.Patrol:
            Decision()

func _count_teammates_targeting_same() -> int:
    if !is_instance_valid(AISpawner) or !is_instance_valid(AISpawner.agents):
        return 0

    var self_faction = _self_faction()
    var count = 0

    for child in AISpawner.agents.get_children():
        if child == self:
            continue
        if !child.has_meta("enemy_ai_faction") or str(child.get_meta("enemy_ai_faction")) != self_faction:
            continue

        var child_target_type = child.get("current_target_type")
        if child_target_type == current_target_type:
            if current_target_type == "player":
                count += 1
            elif current_target_type == "ai" and child.get("currentAITarget") == currentAITarget:
                count += 1

    return count
