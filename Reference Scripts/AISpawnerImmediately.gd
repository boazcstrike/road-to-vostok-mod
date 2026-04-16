extends "res://Scripts/AISpawner.gd"

func _physics_process(_delta):

    if !active:
        return

    if activeAgents < spawnPool:
        SpawnWanderer()