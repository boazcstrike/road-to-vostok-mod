extends Node

func _ready():
    print("[BetterEnemyLoot] Mod Ready")
    overrideScript("res://BetterEnemyLoot/AI.gd")
    queue_free()

func overrideScript(overrideScriptPath : String):
    var script : Script = load(overrideScriptPath)
    script.reload()
    var parentScript = script.get_base_script();
    script.take_over_path(parentScript.resource_path)
    print("[BetterEnemyLoot] Taking over path: ", parentScript.resource_path)