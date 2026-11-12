class_name YardDog
extends Node3D
## Бездомная собака бродит перед гаражами туда-сюда: идёт, останавливается понюхать землю,
## иногда садится почесаться. Просто декорация — ни с кем не сталкивается.

const SCENE := preload("res://assets/models/courtyard/dog.glb")
const SPEED := 1.3
const MIN_X := -9.0
const MAX_X := 9.0

var _parts: Dictionary = {}
var _target_x := 0.0
var _wait := 0.0
var _sniff := false
var _time := 0.0


func _ready() -> void:
	var model := SCENE.instantiate()
	add_child(model)
	for part in ["DogBody", "DogHead", "DogTail", "LegFL", "LegFR", "LegBL", "LegBR"]:
		_parts[part] = model.find_child(part, true, false)
	_pick_target()


func _process(delta: float) -> void:
	_time += delta
	var walking := false
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_pick_target()
	else:
		var dx := _target_x - position.x
		if absf(dx) < 0.05:
			_wait = randf_range(1.5, 4.0)
			_sniff = randf() < 0.6
		else:
			walking = true
			position.x += signf(dx) * minf(SPEED * delta, absf(dx))
			# Собака смотрит по -Z: вправо (+X) — поворот −90°.
			rotation.y = lerp_angle(rotation.y, -PI / 2 * signf(dx), minf(1.0, delta * 6.0))
	_animate(walking, delta)


func _pick_target() -> void:
	_target_x = randf_range(MIN_X, MAX_X)
	_sniff = false


func _animate(walking: bool, delta: float) -> void:
	var phase := _time * 8.0
	var offsets := {"LegFL": 0.0, "LegFR": PI, "LegBL": PI, "LegBR": 0.0}
	for leg: String in offsets:
		var node := _parts[leg] as Node3D
		var angle := sin(phase + float(offsets[leg])) * 0.55 if walking else 0.0
		node.rotation.x = lerpf(node.rotation.x, angle, minf(1.0, delta * 10.0))
	var head := _parts["DogHead"] as Node3D
	var head_x := -0.6 if _sniff else sin(_time * 1.1) * 0.08 # нюхает землю
	head.rotation.x = lerpf(head.rotation.x, head_x, minf(1.0, delta * 4.0))
	var tail := _parts["DogTail"] as Node3D
	tail.rotation.z = sin(_time * (10.0 if walking else 4.0)) * 0.5
