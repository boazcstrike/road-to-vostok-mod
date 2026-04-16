extends "res://Scripts/AI.gd"

func FireAccuracy() -> Vector3:
    var firePosition = playerPosition + Vector3(0, 1.0, 0)
    var xform = Basis.looking_at(firePosition - fire.global_position)
    var spreadMultiplier = 1.0
    var offset = Vector3(0, 0, 0)

    if fullAuto && !boss:
        spreadMultiplier = 2.0


    if playerDistance3D < 10 || boss:
        offset.x += randf_range(-0.1, 0.1) * spreadMultiplier
        offset.y += randf_range(-0.1, 0.1) * spreadMultiplier

    elif playerDistance3D > 10 && playerDistance3D < 50:
        offset.x += randf_range(-1.0, 1.0) * spreadMultiplier
        offset.y += randf_range(-1.0, 1.0) * spreadMultiplier

    else:
        offset.x += randf_range(-2.0, 2.0) * spreadMultiplier
        offset.y += randf_range(-2.0, 2.0) * spreadMultiplier

    return firePosition + xform * offset
