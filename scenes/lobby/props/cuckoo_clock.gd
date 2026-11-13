class_name CuckooClock
extends Node3D
## Часы с кукушкой на стене. Маятник чуть покачивается всегда, а когда рядом проходит
## персонаж (группа "lobby_character"), раскачивается сильнее и потом успокаивается.
## Стрелки (ClockHour / ClockMinute в модели) показывают время компьютера (ShelfClockHands).

const DIR := "res://assets/models/apartment/"
const PENDULUM_POS := Vector3(0, -0.18, 0.075)
const NEAR := 1.8
const IDLE_SWING := 0.06
const MAX_SWING := 0.45
const CALM_SPEED := 0.25 # насколько быстро затихает (в долях за секунду)
const FREQUENCY := 3.2

var _pendulum: Node3D
var _swing := IDLE_SWING
var _time := 0.0


func _ready() -> void:
	add_child(_model("cuckoo_clock"))
	add_child(ShelfClockHands.new())
	_pendulum = _model("cuckoo_pendulum")
	_pendulum.position = PENDULUM_POS
	add_child(_pendulum)


func _process(delta: float) -> void:
	_time += delta
	for node in get_tree().get_nodes_in_group("lobby_character"):
		var body := node as Node3D
		var flat := Vector2(body.global_position.x - global_position.x,
			body.global_position.z - global_position.z)
		if flat.length() < NEAR:
			# Чем ближе и быстрее идёт персонаж — тем сильнее толчок.
			var speed := (body as CharacterBody3D).velocity.length() if body is CharacterBody3D else 0.0
			var push := (1.0 - flat.length() / NEAR) * clampf(speed / 4.0, 0.2, 1.0)
			_swing = minf(MAX_SWING, _swing + push * delta * 1.5)
	_swing = maxf(IDLE_SWING, _swing - _swing * CALM_SPEED * delta)
	_pendulum.rotation.z = sin(_time * FREQUENCY) * _swing


func _model(model_name: String) -> Node3D:
	return (load(DIR + model_name + ".glb") as PackedScene).instantiate() as Node3D
