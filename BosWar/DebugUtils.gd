extends Node

## Centralized debug logging utility for Bo's War enemy AI system
## Provides timestamped logging with optional debug overlay integration

const AI_AUDIO_LOG_COOLDOWN = 2.0  # seconds
const ENEMY_AI_SETTINGS = preload("res://BosWar/EnemyAISettings.tres")

static var aiAudioLogCooldowns = {}  # Dictionary to store cooldowns per key
static var logCooldowns = {}  # Generic cooldown map for trace logging

static func _debug_log(message: String) -> void:
	if !ENEMY_AI_SETTINGS or !ENEMY_AI_SETTINGS.show_debug_logs:
		return

	# Console spam is disabled by default while investigating runtime lag.
	# var timestamped_message = "[" + Time.get_datetime_string_from_system() + "] " + message
	# print("[boswar]" + timestamped_message)

static func _debug_log_ai_audio(key: String, message: String) -> void:
	var now = float(Time.get_ticks_msec()) / 1000.0
	var next_allowed = 0.0
	if aiAudioLogCooldowns.has(key):
		next_allowed = float(aiAudioLogCooldowns[key])

	if now < next_allowed:
		return

	aiAudioLogCooldowns[key] = now + AI_AUDIO_LOG_COOLDOWN
	_debug_log(message)

static func _debug_log_rate_limited(key: String, message: String, cooldown_seconds: float = 1.5) -> void:
	var now = float(Time.get_ticks_msec()) / 1000.0
	var next_allowed = 0.0
	if logCooldowns.has(key):
		next_allowed = float(logCooldowns[key])

	if now < next_allowed:
		return

	logCooldowns[key] = now + max(0.1, cooldown_seconds)
	_debug_log(message)

static func _find_debug_main():
	# Find the debug main node in the scene tree
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		return tree.root.find_child("EnemyAIMain", true, false)
	return null
