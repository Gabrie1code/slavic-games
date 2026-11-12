class_name RunEffects
extends Node3D
## Эффекты бега: облачка пыли из-под ног и белые полосы скорости за спиной.
## Каждый кадр вызывать update() со списком бегущих персонажей.

const MIN_SPEED := 3.0
const INTERVAL := 0.11

var _timers: Dictionary = {} # персонаж -> сколько осталось до следующего облачка
var _material: StandardMaterial3D


func _init() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(1.0, 0.98, 0.94, 0.8)


func update(delta: float, characters: Array) -> void:
	for node in characters:
		var character := node as PlayerCharacter
		var v := character.velocity
		if Vector2(v.x, v.z).length() < MIN_SPEED or not character.is_on_floor():
			continue
		var left: float = _timers.get(character, 0.0) - delta
		if left > 0.0:
			_timers[character] = left
			continue
		_timers[character] = INTERVAL
		var back := -Vector3(v.x, 0, v.z).normalized()
		_puff(character.global_position + back * 0.35 + Vector3.UP * 0.1)
		if randf() < 0.5:
			var side := back.cross(Vector3.UP) * randf_range(-0.35, 0.35)
			_streak(character.global_position + back * 0.7 + side
				+ Vector3.UP * randf_range(0.5, 1.4), back)


func _puff(at: Vector3) -> void:
	var puff := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 8
	mesh.rings = 4
	puff.mesh = mesh
	puff.material_override = _material.duplicate()
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puff)
	puff.global_position = at
	puff.scale = Vector3.ONE * 0.4
	var tween := create_tween().set_parallel(true)
	tween.tween_property(puff, "scale", Vector3.ONE * randf_range(1.1, 1.6), 0.45)
	tween.tween_property(puff, "position:y", at.y + 0.25, 0.45)
	tween.tween_property(puff.material_override, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(puff.queue_free)


func _streak(at: Vector3, back: Vector3) -> void:
	var streak := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, 0.6)
	streak.mesh = mesh
	streak.material_override = _material.duplicate()
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(streak)
	streak.global_position = at
	streak.basis = Basis.looking_at(back, Vector3.UP)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(streak, "global_position", at + back * 0.6, 0.25)
	tween.tween_property(streak.material_override, "albedo_color:a", 0.0, 0.25)
	tween.chain().tween_callback(streak.queue_free)
