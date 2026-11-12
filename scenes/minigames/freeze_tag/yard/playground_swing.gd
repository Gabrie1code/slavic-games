class_name PlaygroundSwing
extends Node3D
## Качели на два сиденья. Сиденье раскачивается, если в него врезаться на бегу (толкнуть).
## Подойти и нажать «подтвердить» — сесть на случайные 2–10 сек; пока сидишь — водящий
## не заморозит. Потом персонаж сам спрыгивает вперёд.
##
## Рама вдоль локальной X, сиденья качаются вперёд-назад (по Z).

signal sit_finished(character: PlayerCharacter)

const FRAME := preload("res://assets/models/playground/swing_frame.glb")
const SEAT := preload("res://assets/models/playground/swing_seat.glb")
const BEAM_Y := 2.4
const ROPE := 1.9
const SEAT_X: Array[float] = [-0.6, 0.6]
const USE_RADIUS := 1.0
const PUSH_RADIUS := 0.75
const MAX_SWING := 0.9
## Частота маятника: √(g / L).
const OMEGA := 2.27

var _seats: Array[Node3D] = []
var _swing: Array[float] = [0.0, 0.0]
var _phase: Array[float] = [0.0, 1.0]
var _sitters: Array = [null, null] # PlayerCharacter или null
var _sit_left: Array[float] = [0.0, 0.0]


func _ready() -> void:
	add_child(FRAME.instantiate())
	for x in SEAT_X:
		var pivot := Node3D.new()
		pivot.position = Vector3(x, BEAM_Y, 0)
		add_child(pivot)
		pivot.add_child(SEAT.instantiate())
		_seats.append(pivot)
	# Стойки рамы — твёрдые (тонкие коробки по краям).
	for x in [-1.5, 1.5]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.2, 2.4, 1.4)
		shape.shape = box
		shape.position = Vector3(x, 1.2, 0)
		body.add_child(shape)
		add_child(body)
	var badge := ZoneBadge.new().setup("zone_swing", 3.0)
	add_child(badge)


## Толкнуть качели проходящими персонажами и раскачать сиденья.
func update_swing(delta: float, characters: Array[PlayerCharacter]) -> void:
	for i in _seats.size():
		var seat_pos := _seat_point(i)
		if _sitters[i] == null:
			for character in characters:
				var pos := character.global_position
				var speed := Vector2(character.velocity.x, character.velocity.z).length()
				if Vector2(pos.x - seat_pos.x, pos.z - seat_pos.z).length() < PUSH_RADIUS and speed > 1.0:
					_swing[i] = minf(MAX_SWING, _swing[i] + delta * speed * 0.25)
		else:
			_swing[i] = maxf(_swing[i], 0.55) # с сидящим качается сами
		_swing[i] = maxf(0.0, _swing[i] - _swing[i] * 0.12 * delta)
		_phase[i] += OMEGA * delta
		var angle := sin(_phase[i]) * _swing[i]
		_seats[i].rotation.x = angle
		var sitter: PlayerCharacter = _sitters[i]
		if sitter != null:
			if not is_instance_valid(sitter):
				_sitters[i] = null
				continue
			sitter.global_position = _seats[i].to_global(Vector3(0, -ROPE + 0.025 - 0.49, 0.05))
			sitter.rotation.x = -angle
			_sit_left[i] -= delta
			if _sit_left[i] <= 0.0:
				_stand(i)


## Свободное сиденье рядом с персонажем (-1 — нет).
func free_seat_near(character: PlayerCharacter) -> int:
	var pos := character.global_position
	for i in _seats.size():
		var seat_pos := _seat_point(i)
		if _sitters[i] == null and Vector2(pos.x - seat_pos.x, pos.z - seat_pos.z).length() < USE_RADIUS:
			return i
	return -1


## Сесть на сиденье на случайное время 2–10 сек.
func sit(character: PlayerCharacter, seat: int) -> void:
	_sitters[seat] = character
	_sit_left[seat] = randf_range(2.0, 10.0)
	character.input_enabled = false
	character.sit_at(_seat_point(seat), global_rotation.y + PI) # лицом вперёд (+Z качелей)


func _stand(seat: int) -> void:
	var character: PlayerCharacter = _sitters[seat]
	_sitters[seat] = null
	character.rotation.x = 0.0
	character.sitting = false
	character.set_physics_process(true)
	# Спрыгнуть вперёд с разгона.
	character.apply_knockback(global_basis.z * 5.0 + Vector3.UP * 3.0)
	sit_finished.emit(character)


func _seat_point(i: int) -> Vector3:
	var p := to_global(Vector3(SEAT_X[i], 0, 0))
	return Vector3(p.x, global_position.y, p.z)
