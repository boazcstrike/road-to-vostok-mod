extends Node
func _ready():
	overrideScript("res://AllAISpawnsImmediately/AISpawner.gd")
	queue_free()

func overrideScript(overrideScriptPath : String):
	var script : Script = load(overrideScriptPath)
	script.reload()
	var parentScript = script.get_base_script();
	script.take_over_path(parentScript.resource_path)
