class_name VomitFx
extends RefCounted
## Рвота (перепил из бутылки): персонаж сгибается вперёд, голова вниз, изо рта бьёт жёлто-зелёная
## струя (частицы), на полу остаётся лужа, которая через PUDDLE_TIME сек тает. Видно всем, и
## самому от первого лица (камера наклоняется вместе с корпусом — local_lobby._view_wobble).

const TIME := 2.2
const PUDDLE_TIME := 10.0
const COLOR := Color(0.62, 0.66, 0.2)


static func play(character: PlayerCharacter, world: Node3D) -> void:
	var bend := character.create_tween()
	bend.tween_property(character, "lean", 0.75, 0.3).set_trans(Tween.TRANS_BACK)
	bend.parallel().tween_property(character, "head_tilt", -0.35, 0.3)
	bend.tween_interval(TIME)
	bend.tween_property(character, "lean", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	bend.parallel().tween_property(character, "head_tilt", 0.0, 0.5)
	var stream := _stream()
	character.attach_to_part("Head", stream)
	stream.layers = 1 # видно всем, в том числе самому от первого лица
	stream.position = Vector3(0, 0.1, -0.2) # у рта
	character.get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if is_instance_valid(stream):
			stream.emitting = true)
	character.get_tree().create_timer(0.3 + TIME).timeout.connect(func() -> void:
		if is_instance_valid(stream):
			stream.emitting = false
			stream.get_tree().create_timer(1.0).timeout.connect(stream.queue_free))
	character.get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if is_instance_valid(character) and is_instance_valid(world):
			_puddle(world, character.global_position - character.global_basis.z * 0.55))


static func _stream() -> CPUParticles3D:
	var stream := CPUParticles3D.new()
	stream.emitting = false
	stream.amount = 70
	stream.lifetime = 0.7
	stream.local_coords = false # капли летят в мире, а не вместе с головой
	stream.direction = Vector3(0, -0.6, -1)
	stream.spread = 14.0
	stream.initial_velocity_min = 1.4
	stream.initial_velocity_max = 2.4
	stream.gravity = Vector3(0, -9.8, 0)
	stream.scale_amount_min = 0.6
	stream.scale_amount_max = 1.3
	var mesh := SphereMesh.new()
	mesh.radius = 0.018
	mesh.height = 0.03
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.roughness = 0.2
	mesh.material = mat
	stream.mesh = mesh
	var colors := Gradient.new()
	colors.set_color(0, COLOR.lightened(0.15))
	colors.set_color(1, COLOR.darkened(0.25))
	stream.color_initial_ramp = colors
	return stream


## Лужа на полу: растекается, потом тает.
static func _puddle(world: Node3D, at: Vector3) -> void:
	var puddle := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.25
	mesh.bottom_radius = 0.25
	mesh.height = 0.006
	mesh.radial_segments = 16
	puddle.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR.darkened(0.1)
	mat.roughness = 0.1
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puddle.material_override = mat
	puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(puddle)
	puddle.global_position = Vector3(at.x, 0.012, at.z)
	puddle.scale = Vector3(0.2, 1.0, 0.2)
	var tween := puddle.create_tween()
	tween.tween_property(puddle, "scale", Vector3(1.0, 1.0, 0.8), 1.5).set_ease(Tween.EASE_OUT)
	tween.tween_interval(PUDDLE_TIME)
	tween.tween_property(mat, "albedo_color:a", 0.0, 1.5)
	tween.tween_callback(puddle.queue_free)
