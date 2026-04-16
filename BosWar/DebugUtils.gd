extends Node

## Centralized debug logging utility for Bo's War enemy AI system
## Provides timestamped logging with optional debug overlay integration

const AI_AUDIO_LOG_COOLDOWN = 2.0  # seconds

static var aiAudioLogCooldowns = {}  # Dictionary to store cooldowns per key

static func _debug_log(message: String) -> void:
	var timestamped_message = "[" + Time.get_datetime_string_from_system() + "] " + message
	print("[boswar]" + timestamped_message)

	# Check if debug overlay is enabled
	var enemyAISettings = load("res://BosWar/EnemyAISettings.tres")
	if enemyAISettings and enemyAISettings.show_debug_logs:
		var debug_main = _find_debug_main()
		if debug_main and debug_main.has_method("log_debug"):
			debug_main.log_debug(timestamped_message)

static func _debug_log_ai_audio(key: String, message: String) -> void:
	var now = float(Time.get_ticks_msec()) / 1000.0
	var next_allowed = 0.0
	if aiAudioLogCooldowns.has(key):
		next_allowed = float(aiAudioLogCooldowns[key])

	if now < next_allowed:
		return

	aiAudioLogCooldowns[key] = now + AI_AUDIO_LOG_COOLDOWN
	_debug_log(message)

static func _find_debug_main():
	# Find the debug main node in the scene tree
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		return tree.root.find_child("EnemyAIMain", true, false)
	return null