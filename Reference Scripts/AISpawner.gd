extends "res://Scripts/AISpawner.gd"

var settings = preload("res://DJ_Modpack/Settings.tres")

func _ready():
	spawnLimit = settings.maxActiveAI
	spawnPool = settings.maxTotalSpawns
	super()