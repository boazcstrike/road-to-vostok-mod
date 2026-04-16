extends "res://Scripts/Character.gd"

var EnemyAISettings = preload("res://BosWar/EnemyAISettings.tres")

func _physics_process(delta):
    super(delta)

    if _player_invulnerable():
        _maintain_invulnerable_stats()

func Health(delta):
    if _player_invulnerable():
        gameData.health = 100.0
        gameData.damage = false
        return

    super(delta)

func Oxygen(delta):
    if _player_invulnerable():
        gameData.oxygen = 100.0
        return

    super(delta)

func WeaponDamage(damage: int, penetration: int):
    if _player_invulnerable():
        return

    super(damage, penetration)

func ExplosionDamage():
    if _player_invulnerable():
        return

    super()

func BurnDamage(delta):
    if _player_invulnerable():
        gameData.isBurning = false
        gameData.burn = false
        gameData.damage = false
        return

    super(delta)

func FallDamage(distance: float):
    if _player_invulnerable():
        return

    super(distance)

func Death():
    if _player_invulnerable():
        _maintain_invulnerable_stats()
        return

    super()

func _player_invulnerable() -> bool:
    return EnemyAISettings.player_invulnerable

func _maintain_invulnerable_stats():
    gameData.health = 100.0
    gameData.oxygen = 100.0
    gameData.damage = false
    gameData.impact = false
    gameData.isDead = false
