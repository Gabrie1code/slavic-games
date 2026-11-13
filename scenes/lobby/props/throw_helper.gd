class_name ThrowHelper
extends RefCounted
## Бросок вещи из руки (губка, баллончик, пульт): летит туда, куда смотрит игрок в момент броска.

const SPEED := 5.0
const LIFT := 1.2
## Сколько секунд брошенная вещь не задевает самого бросившего (вылетает из его руки).
const IGNORE_TIME := 0.4


## dir — куда смотрит камера (или персонаж); Vector3.ZERO — просто уронить под себя.
static func launch(body: RigidBody3D, character: PlayerCharacter, dir: Vector3) -> void:
	body.continuous_cd = true # на скорости не проскакивает сквозь пол и стены
	if dir == Vector3.ZERO:
		body.linear_velocity = -character.global_basis.z * 1.0 + Vector3.UP * 0.8
		return
	var damp := body.linear_damp
	body.linear_damp = 0.2 # в полёте почти не тормозит, после приземления — снова как было
	body.get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.linear_damp = damp)
	body.linear_velocity = dir.normalized() * SPEED + Vector3.UP * LIFT
	body.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	body.add_collision_exception_with(character)
	body.get_tree().create_timer(IGNORE_TIME).timeout.connect(func() -> void:
		if is_instance_valid(body) and is_instance_valid(character):
			body.remove_collision_exception_with(character))
