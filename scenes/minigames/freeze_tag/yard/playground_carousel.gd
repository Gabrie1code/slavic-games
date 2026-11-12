class_name PlaygroundCarousel
extends Node3D
## Карусель: сесть нельзя, только раскрутить — бегом вдоль края (кто бежит по касательной,
## тот и крутит). Сама понемногу останавливается.

const BASE := preload("res://assets/models/playground/carousel_base.glb")
const TOP := preload("res://assets/models/playground/carousel_top.glb")
const RADIUS := 1.3
const PUSH_ZONE := 0.7 # насколько дальше края ещё считается «толкает»
const MAX_SPIN := 4.0
const FRICTION := 0.35

var spin := 0.0 # угловая скорость, рад/сек

var _top: AnimatableBody3D


func _ready() -> void:
	add_child(BASE.instantiate())
	_top = AnimatableBody3D.new()
	_top.sync_to_physics = true
	_top.add_child(TOP.instantiate())
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = 1.1
	shape.shape = cylinder
	shape.position.y = 0.6
	_top.add_child(shape)
	add_child(_top)


func update_spin(delta: float, characters: Array[PlayerCharacter]) -> void:
	for character in characters:
		var rel := character.global_position - global_position
		rel.y = 0.0
		var dist := rel.length()
		if dist < RADIUS - 0.1 or dist > RADIUS + PUSH_ZONE or dist < 0.01:
			continue
		# Касательная к краю для вращения против часовой стрелки (вид сверху).
		var tangent := Vector3(rel.z, 0, -rel.x) / dist
		var push := character.velocity.dot(tangent)
		spin = clampf(spin + push * delta * 1.2 / RADIUS, -MAX_SPIN, MAX_SPIN)
	spin = move_toward(spin, 0.0, FRICTION * delta)
	_top.rotation.y += spin * delta
