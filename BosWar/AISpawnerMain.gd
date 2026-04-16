extends Node3D


var gameData = preload("res://Resources/GameData.tres")
var audioLibrary = preload("res://Resources/AudioLibrary.tres")
var audioInstance2D = preload("res://Resources/AudioInstance2D.tscn")


@export var active = true
var gizmos = false


enum Zone{Area05, BorderZone, Vostok}
@export var zone = Zone.Area05


enum Frequency{Low, Medium, High, Debug}
@export var spawnFrequency = Frequency.Medium
@export var spawnDistance = 100
@export var spawnLimit = 3
@export var spawnPool = 10

@export_group("Map Rules")
@export var initialGuard = false
@export var initialHider = false
@export var noHiding = false


var bandit = preload("res://AI/Bandit/AI_Bandit.tscn")
var guard = preload("res://AI/Guard/AI_Guard.tscn")
var military = preload("res://AI/Military/AI_Military.tscn")
var punisher = preload("res://AI/Punisher/AI_Punisher.tscn")
var activeAgents = 0
var agent


var spawnTime = 1.0
var spawnTimer = 0.0


var spawns: Array
var waypoints: Array
var patrols: Array
var covers: Array
var hides: Array
var vehicle: Array


@onready var APool = $A_Pool
@onready var BPool = $B_Pool
@onready var agents = $Agents

func _ready():

    GetPoints()
    HidePoints()


    if !active:
        return


    if zone == Zone.Area05:
        agent = bandit
    elif zone == Zone.BorderZone:
        agent = guard
    elif zone == Zone.Vostok:
        agent = military


    CreatePools()


    if initialGuard:
        SpawnGuard()


    if initialHider:
        if randi_range(0, 100) < 25:
            SpawnHider()

func _physics_process(delta):

    if !active:
        return

    spawnTime -= delta


    if spawnTime <= 0:

        if activeAgents < spawnLimit:
            SpawnWanderer()


        if spawnFrequency == Frequency.Low:
            spawnTime = randf_range(60, 120)
        elif spawnFrequency == Frequency.Medium:
            spawnTime = randf_range(10, 60)
        elif spawnFrequency == Frequency.High:
            spawnTime = randf_range(1, 10)
        elif spawnFrequency == Frequency.Debug:
            spawnTime = 1

func CreatePools():

    APool.global_position = Vector3(0, 1000, 0)
    BPool.global_position = Vector3(0, 1000, 0)


    for amount in spawnPool:

        var newAgent = agent.instantiate()
        APool.add_child(newAgent, true)


        newAgent.boss = false
        newAgent.AISpawner = self
        newAgent.global_position = APool.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
        newAgent.Pause()


    var newBoss = punisher.instantiate()
    BPool.add_child(newBoss, true)


    newBoss.boss = true
    newBoss.AISpawner = self
    newBoss.global_position = BPool.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
    newBoss.Pause()

    print("AI Spawner: Pools created")

func SpawnWanderer():

    if APool.get_child_count() == 0:
        print("AI Spawner: APool ended (Wanderer)")
        return


    var validPoints: Array[Node3D]


    for point in spawns:

        var distanceToPlayer = point.global_position.distance_to(gameData.playerPosition)

        if distanceToPlayer > spawnDistance:

            validPoints.append(point)


    if validPoints.size() != 0:

        var spawnPoint = validPoints[randi_range(0, validPoints.size() - 1)]


        var newAgent = APool.get_child(0)
        newAgent.reparent(agents)


        newAgent.global_transform = spawnPoint.global_transform
        newAgent.currentPoint = spawnPoint


        newAgent.ActivateWanderer()
        if is_instance_valid(newAgent):
            var before = activeAgents
            activeAgents += 1
            DebugUtils._debug_log("Spawn increment (Wanderer): before=%d after=%d" % [before, activeAgents])
        else:
            DebugUtils._debug_log("Spawn failed (Wanderer): agent invalid after activation")
        print("AI Spawner: Agent active (Wanderer)")
    else:
        print("AI Spawner: No valid spawn points (Wanderer)")

func SpawnGuard():

    if APool.get_child_count() == 0:
        print("AI Spawner: APool ended (Guard)")
        return


    if patrols.size() != 0:

        var patrolPoint = patrols[randi_range(0, patrols.size() - 1)]


        var newAgent = APool.get_child(0)
        newAgent.reparent(agents)


        newAgent.global_transform = patrolPoint.global_transform
        newAgent.currentPoint = patrolPoint


        newAgent.ActivateGuard()
        if is_instance_valid(newAgent):
            var before = activeAgents
            activeAgents += 1
            DebugUtils._debug_log("Spawn increment (Guard): before=%d after=%d" % [before, activeAgents])
        else:
            DebugUtils._debug_log("Spawn failed (Guard): agent invalid after activation")
        print("AI Spawner: Agent active (Guard)")
    else:
        print("AI Spawner: No valid patrol points (Guard)")

func SpawnHider():
    if APool.get_child_count() == 0:
        print("Spawn blocked (Hider): APool ended")
        return


    var randomIndex = randi_range(0, hides.size() - 1)
    var hidePoint = hides[randomIndex]


    var newAgent = APool.get_child(0)
    newAgent.reparent(agents)


    newAgent.global_transform = hidePoint.global_transform
    newAgent.currentPoint = hidePoint


    newAgent.ActivateHider()
    if is_instance_valid(newAgent):
        var before = activeAgents
        activeAgents += 1
        DebugUtils._debug_log("Spawn increment (Hider): before=%d after=%d" % [before, activeAgents])
    else:
        DebugUtils._debug_log("Spawn failed (Hider): agent invalid after activation")
    print("Hider spawned")

func SpawnMinion(spawnPosition):
    if APool.get_child_count() == 0:
        print("Spawn blocked (Minion): APool ended")
        return


    var newAgent = APool.get_child(0)
    newAgent.reparent(agents)


    newAgent.global_position = spawnPosition
    newAgent.currentPoint = waypoints.pick_random()
    newAgent.lastKnownLocation = gameData.playerPosition


    newAgent.ActivateMinion()
    if is_instance_valid(newAgent):
        var before = activeAgents
        activeAgents += 1
        DebugUtils._debug_log("Spawn increment (Minion): before=%d after=%d" % [before, activeAgents])
    else:
        DebugUtils._debug_log("Spawn failed (Minion): agent invalid after activation")
    print("AI Spawner: Agent active (Minion)")

func SpawnBoss(spawnPosition):
    if BPool.get_child_count() == 0:
        print("Spawn blocked (Boss): BPool ended")
        return


    var newBoss = BPool.get_child(0)
    newBoss.reparent(agents)


    newBoss.global_position = spawnPosition
    newBoss.currentPoint = waypoints.pick_random()
    newBoss.lastKnownLocation = gameData.playerPosition


    newBoss.ActivateBoss()
    if is_instance_valid(newBoss):
        var before = activeAgents
        activeAgents += 1
        DebugUtils._debug_log("Spawn increment (Boss): before=%d after=%d" % [before, activeAgents])
    else:
        DebugUtils._debug_log("Spawn failed (Boss): agent invalid after activation")
    print("AI Spawner: Agent active (Boss)")

func CreateHotspot(location: Vector3, relay: bool):

    if agents.get_child_count() != 0:

        for child in agents.get_children():
            await get_tree().create_timer(randf_range(0.5, 2.0), false).timeout;
            child.lastKnownLocation = location
            child.attackReturn = true
            child.ChangeState("Attack")

    await get_tree().create_timer(10.0, false).timeout;

    if agents.get_child_count() != 0 && relay:

        for child in agents.get_children():
            await get_tree().create_timer(randf_range(0.5, 2.0), false).timeout;
            child.lastKnownLocation = gameData.playerPosition

func DestroyAllAI():
    activeAgents = 0
    var childCount = agents.get_child_count()

    if childCount != 0:
        for child in agents.get_children():
            remove_child(child)
            child.queue_free()

func GetPoints():
    spawns = get_tree().get_nodes_in_group("AI_SP")
    waypoints = get_tree().get_nodes_in_group("AI_WP")
    patrols = get_tree().get_nodes_in_group("AI_PP")
    covers = get_tree().get_nodes_in_group("AI_CP")
    hides = get_tree().get_nodes_in_group("AI_HP")
    vehicle = get_tree().get_nodes_in_group("AI_VP")

func ShowPoints():
    for point in spawns: point.show()
    for point in waypoints: point.show()
    for point in patrols: point.show()
    for point in covers: point.show()
    for point in hides: point.show()
    for point in vehicle: point.show()

func HidePoints():
    for point in spawns: point.hide()
    for point in waypoints: point.hide()
    for point in patrols: point.hide()
    for point in covers: point.hide()
    for point in hides: point.hide()
    for point in vehicle: point.hide()

func ShowGizmos():
    if agents.get_child_count() != 0:
        for child in agents.get_children():
            child.ShowGizmos()

func HideGizmos():
    if agents.get_child_count() != 0:
        for child in agents.get_children():
            child.HideGizmos()

func ForceState(state):
    var childCount = agents.get_child_count()

    if childCount != 0:
        for child in agents.get_children():
            child.ChangeState(state)

func AIHide():
    var childCount = agents.get_child_count()

    if childCount != 0:
        for child in agents.get_children():
            child.animator.active = false
            child.hide()
            child.pause = true

func AIShow():
    var childCount = agents.get_child_count()

    if childCount != 0:
        for child in agents.get_children():
            child.animator.active = true
            child.show()
            child.pause = false
